#!/bin/bash
# l3-review.sh — L3 外部模型独立审查共享 lib
#
# 提供 l3_review_run() 和 l3_review_with_timeout()，供:
#   - independent-review-gate.sh (PreToolUse hook · transition 时同步触发)
#   - 29-independent-review.sh (Stop hook · session 异常终止时兜底)
# 两处复用，消除 L3 API 调用代码重复。
#
# 函数签名:
#   l3_review_run <phase> <change_id> <artifacts_dir> <L2_verdict>
#     参数:
#       $1 = phase number (1-7)
#       $2 = change_id
#       $3 = artifacts_dir (.specs/<id>/)
#       $4 = L2_verdict (pass|fail, 从 INDEPENDENT-REVIEW-<N>.md L2 段解析)
#     行为:
#       1. 读取阶段产物，构造审查 prompt
#       2. 调用外部模型 API 执行 L3 审查
#       3. L3 结果追加写入 INDEPENDENT-REVIEW-<N>.md 的 L3 段
#       4. 写入完整 6 键 .independent-review-<N>.done 文件
#     返回: 0=pass 或 skip(工件未变更跳过重审), 1=fail/timeout, 3=API error
#
#   l3_review_with_timeout <phase> <change_id> <artifacts_dir> <L2_verdict> [timeout_secs]
#     timeout 降级 wrapper，默认 30s 超时
#     返回: 同 l3_review_run，超时时降级为 timeout(2)
#
# 环境变量依赖 (沿用 CONTEXT.md 已锁决策):
#   ANTHROPIC_BASE_URL   — API endpoint (默认 https://api.anthropic.com)
#   ANTHROPIC_AUTH_TOKEN — 鉴权 token (env-var-first, 优先)
#   ANTHROPIC_API_KEY    — 鉴权 key (向后兼容)
#   ANTHROPIC_DEFAULT_HAIKU_MODEL — L3 审查模型 (默认 deepseek-v4-flash)

set -euo pipefail

# ── _l3_format_result() · L3 反馈统一格式化 ──
# 用法: _l3_format_result <verdict> <summary> <report_relative_path>
# 输出: 单行 L3_RESULT: 格式，供 F1(PreToolUse stdout) 和 F2(SessionStart banner) 共用
_l3_format_result() {
  local verdict="$1" summary="$2" report="$3"
  # 值域校验：仅允许已知 verdict 值，非法值降级为 unknown
  case "$verdict" in pass|fail|timeout|error) ;; *) verdict="unknown" ;; esac
  echo "L3_RESULT: verdict=${verdict} summary=${summary} report=${report}"
}

# ── smart_truncate() · 智能截断（保留标题 + AC）──
# 用法: smart_truncate <text> <max_chars>
# 输出: truncated_text + truncation_meta 到 stdout
# 硬约束: (a) 所有 ##/### 标题行保留; (b) 所有 Given/When/Then AC 行完整保留
# 算法: 两遍扫描——① 索引收集标题+AC位置; ② 按标题段填充至上限
smart_truncate() {
  local text="$1"
  local max_chars="${2:-20000}"
  local original_size=${#text}

  # 不需要截断
  if [ "$original_size" -le "$max_chars" ]; then
    echo "$text"
    echo ""
    echo "[截断] 原始: ${original_size} chars，未超限（上限 ${max_chars} chars），完整保留"
    return 0
  fi

  # 第 1 遍: 索引收集 (header_line_numbers + AC line_numbers)
  local header_nums=""   # 仅行号，换行分隔
  local ac_nums=""       # 仅行号，换行分隔

  local lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    # 捕获 ##/### 标题行 → 仅存行号
    if [[ "$line" =~ ^###?\  ]]; then
      header_nums="${header_nums}${lineno}"$'\n'
    fi
    # 捕获 Given/When/Then AC 行 → 仅存行号
    if [[ "$line" =~ ^\*\*Given\*\*|^\*\*When\*\*|^\*\*Then\*\* ]]; then
      ac_nums="${ac_nums}${lineno}"$'\n'
    fi
  done <<< "$text"

  # 构建强制保留行号集合（仅数字键）
  declare -A keep_line
  while IFS= read -r num; do
    [ -n "$num" ] && keep_line["$num"]=1
  done <<< "$header_nums"
  while IFS= read -r num; do
    [ -n "$num" ] && keep_line["$num"]=1
  done <<< "$ac_nums"

  # 第 2 遍: 按标题段填充
  local output=""
  local remaining=$max_chars
  local removed_sections=""
  local current_section=""
  local in_section=0

  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    local is_header=0
    local line_len=${#line}

    if [[ "$line" =~ ^###?\  ]]; then
      is_header=1
      # R2 fix: always output header line even if remaining exhausted
      # (AC-2 hard constraint (a): all headers must be preserved)
      if [ "$in_section" -eq 1 ] && [ -n "$current_section" ] && [ "$remaining" -le 0 ]; then
        removed_sections="${removed_sections}${current_section}, "
      fi
      current_section=$(echo "$line" | sed 's/^#\+ //' | cut -c1-60)
      in_section=1
    fi

    # R2 fix: headers always output regardless of remaining budget
    if [ "$is_header" -eq 1 ]; then
      output="${output}${line}"$'\n'
      remaining=$((remaining - line_len - 1))
      continue
    fi

    if [ "$remaining" -le 0 ]; then
      continue
    fi

    # 强制保留: AC 行 (R3 fix: keep_line key is now numeric, matching $lineno)
    if [ "${keep_line[$lineno]:-0}" -eq 1 ]; then
      if [ "$line_len" -le "$remaining" ]; then
        output="${output}${line}"$'\n'
        remaining=$((remaining - line_len - 1))
      else
        output="${output}${line:0:$remaining}"$'\n'
        remaining=0
      fi
    elif [ "$in_section" -eq 1 ]; then
      # 标题段内的普通行，按剩余空间填充
      if [ "$line_len" -le "$remaining" ]; then
        output="${output}${line}"$'\n'
        remaining=$((remaining - line_len - 1))
      fi
    fi
  done <<< "$text"

  # 构造截断元信息
  local truncated_size=${#output}
  local meta="[截断] 原始: ${original_size} chars → 截断后: ${truncated_size} chars（上限 ${max_chars}）"
  if [ -n "$removed_sections" ]; then
    removed_sections="${removed_sections%, }"
    meta="${meta} | 被截去的章节: ${removed_sections}"
  else
    meta="${meta} | 所有章节已保留（内容被压缩）"
  fi
  meta="${meta}"$'\n'"[提示] 以上为截断摘要，信息不完整。请优先标记确定性问题，减少不确定环境下的武断 critical。"

  echo "$output"
  echo ""
  echo "$meta"
  return 0
}

# ── _l3_build_prompt() · Step 1: 按阶段收集工件 + 构造审查 prompt ──
# 用法: _l3_build_prompt <phase> <artifacts_dir> <max_chars>
# 输出: prompt_text 到 stdout；无工件时返回 3
_l3_build_prompt() {
  local phase="$1" artifacts_dir="$2" max_chars="$3"

  local artifact="" checklist=""
  case "$phase" in
    1)
      if [ -f "${artifacts_dir}/REQUIREMENT.md" ]; then
        artifact=$(head -c "$max_chars" "${artifacts_dir}/REQUIREMENT.md" 2>/dev/null || echo "")
      fi
      checklist="AC 是否每条 Given/When/Then 可验证且无歧义？v1/v2/out 范围切分是否合理？是否有范围蔓延或遗漏的非功能性需求？"
      ;;
    2)
      if [ -f "${artifacts_dir}/DESIGN.md" ]; then
        artifact=$(head -c "$max_chars" "${artifacts_dir}/DESIGN.md" 2>/dev/null || echo "")
      fi
      local adr_dir="$(dirname "$artifacts_dir")/adr"
      if [ -d "$adr_dir" ]; then
        while IFS= read -r f; do
          [ -n "$f" ] || continue
          artifact="${artifact}"$'\n\n--- '"${f}"$' ---\n'"$(head -c 2000 "$f" 2>/dev/null || echo "")"
        done < <(find "$adr_dir" -type f -name '*.md' 2>/dev/null | head -3 || true)
      fi
      checklist="ADR 决策是否合理且有充分理由？是否撞既有架构/跨模块契约？抽象层次是否得当（深模块 vs 浅模块）？风险段是否遗漏关键风险？"
      ;;
    3)
      if [ -f "${artifacts_dir}/TASK.md" ]; then
        artifact=$(head -c "$max_chars" "${artifacts_dir}/TASK.md" 2>/dev/null || echo "")
      fi
      checklist="任务拆解是否覆盖 REQUIREMENT 全 AC？depends_on 依赖是否无环？每个 task 的 verify 是否可执行且能证伪？write_files 边界是否清晰不越界？"
      ;;
    5)
      if [ -f "${artifacts_dir}/TEST.md" ]; then
        artifact=$(head -c "$max_chars" "${artifacts_dir}/TEST.md" 2>/dev/null || echo "")
      fi
      checklist="测试矩阵是否覆盖全 AC？覆盖率是否达标？UAT 是否可复现？是否有 mock 屏蔽真实失败？回归测试是否含？"
      ;;
    6)
      local project_root="$(dirname "$(dirname "$artifacts_dir")")"
      artifact=$(cd "$project_root" && {
        git diff HEAD 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null | grep -E '\.(sh|bats)$' | while read -r f; do
          echo ""; echo "=== NEW FILE: $f ==="
          head -c 5000 "$project_root/$f" 2>/dev/null || true
        done
      } | head -c "$max_chars" || true)
      if [ -f "${artifacts_dir}/REVIEW.md" ]; then
        artifact="${artifact}"$'\n\n=== 主 agent REVIEW.md ===\n'"$(head -c 8000 "${artifacts_dir}/REVIEW.md" 2>/dev/null || echo "")"
      fi
      checklist="spec 合规（每条 AC 是否被代码覆盖）？代码质量（6 维衰退风险：认知过载/变更传播/知识重复/偶然复杂/依赖混乱/领域扭曲）？是否有 critical？"
      ;;
    7)
      local project_root="$(dirname "$(dirname "$artifacts_dir")")"
      artifact="=== 产物目录 ===\n$(ls -la "$artifacts_dir" 2>/dev/null | head -30)\n"
      for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md INTEGRATION.md; do
        if [ -f "${artifacts_dir}/$f" ]; then
          artifact="${artifact}\n\n=== $f ===\n$(head -c 3000 "${artifacts_dir}/$f" 2>/dev/null || echo "")"
        else
          artifact="${artifact}\n\n=== $f === MISSING"
        fi
      done
      local changelog="${project_root:-.}/.specs/CHANGELOG.md"
      if [ -f "$changelog" ]; then
        artifact="${artifact}\n\n=== CHANGELOG.md ===\n$(head -c 3000 "$changelog" 2>/dev/null || echo "")"
      fi
      local lessons="${project_root:-.}/.specs/LESSONS.md"
      if [ -f "$lessons" ]; then
        artifact="${artifact}\n\n=== LESSONS.md ===\n$(head -c 2000 "$lessons" 2>/dev/null || echo "")"
      fi
      artifact=$(echo -e "$artifact" | head -c "$max_chars")
      checklist="归档产物是否齐全（CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY/TEST/REVIEW）？CHANGELOG 是否更新且 Conventional Commits 语义正确？archive 是否完整？"
      ;;
  esac
  [ -n "$artifact" ] || { echo "[l3-review] no artifact for phase $phase" >&2; return 3; }

  # 构造 prompt (jq --arg 避免工件中反引号/$ 被 shell 解释)
  jq -nr \
    --arg checklist "$checklist" \
    --arg phase "$phase" \
    --arg artifact "$artifact" \
    '"你是独立审查员，对以下 flow-kit 工件做盲审。独立性要求：禁止假设作者意图，只看工件本身；不接受也不引用任何「作者认为/主 agent 结论」类外部陈述。\n\n审查重点：" + $checklist + "\n\n工件（阶段 " + $phase + "）：\n" + $artifact + "\n\n请严格按 JSON 回复，不要 markdown 代码块包裹：\n{\"critical\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"major\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"minor\":[...],\"verdict\":\"pass 或 fail\",\"summary\":\"一句话总评\"}\ncritical/major/minor 每项含 file/issue/why/fix 四要素。无问题给空数组。verdict=fail 当且仅当存在 critical。"'
}

# ── _l3_call_api() · Step 2: 调用外部模型 API + 解析响应 ──
# 用法: _l3_call_api <prompt_text> <model>
# 输出: content 到 stdout；失败时返回 3
_l3_call_api() {
  local prompt_text="$1" model="$2"
  local ai_response="" base_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
  local auth_token="${ANTHROPIC_AUTH_TOKEN:-}"

  # Path 1: ANTHROPIC_AUTH_TOKEN (env-var-first 直连)
  if [ -n "$auth_token" ]; then
    ai_response=$(curl -s --max-time 90 "${base_url}/v1/messages" \
      -H "Authorization: Bearer ${auth_token}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg m "$model" --arg p "$prompt_text" \
        '{model:$m, max_tokens:8000, messages:[{role:"user", content:$p}]}')" 2>/dev/null || true)
  fi

  # Path 2: Legacy ANTHROPIC_API_KEY (向后兼容)
  if [ -z "$ai_response" ] && [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    ai_response=$(curl -s --max-time 90 https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg m "$model" --arg p "$prompt_text" \
        '{model:$m, max_tokens:8000, messages:[{role:"user", content:$p}]}')" 2>/dev/null || true)
  fi

  local content=""
  if [ -n "$ai_response" ]; then
    content=$(echo "$ai_response" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty' 2>/dev/null || echo "")
  fi

  if [ -z "$content" ]; then
    echo "[l3-review] L3 API call failed (no content in response)" >&2
    return 3
  fi
  echo "$content"
}

# ── _l3_check_rerun() · 重审检测：比较工件 mtime 与 review mtime ──
# 用法: _l3_check_rerun <phase> <artifacts_dir>
# 返回: 0=需重审(工件更新或首次), 2=跳过(工件未变)
_l3_check_rerun() {
  local phase="$1" artifacts_dir="$2"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  [ -f "$review_md" ] || return 0  # 无现有审查 → 首次运行

  local review_mtime=0
  review_mtime=$(stat -c %Y "$review_md" 2>/dev/null || stat -f %m "$review_md" 2>/dev/null || date -r "$review_md" +%s 2>/dev/null || echo "0")
  local artifact_mtime=0
  case "$phase" in
    1) artifact_mtime=$(stat -c %Y "${artifacts_dir}/REQUIREMENT.md" 2>/dev/null || stat -f %m "${artifacts_dir}/REQUIREMENT.md" 2>/dev/null || date -r "${artifacts_dir}/REQUIREMENT.md" +%s 2>/dev/null || echo "0") ;;
    2) artifact_mtime=$(stat -c %Y "${artifacts_dir}/DESIGN.md" 2>/dev/null || stat -f %m "${artifacts_dir}/DESIGN.md" 2>/dev/null || date -r "${artifacts_dir}/DESIGN.md" +%s 2>/dev/null || echo "0") ;;
    3) artifact_mtime=$(stat -c %Y "${artifacts_dir}/TASK.md" 2>/dev/null || stat -f %m "${artifacts_dir}/TASK.md" 2>/dev/null || date -r "${artifacts_dir}/TASK.md" +%s 2>/dev/null || echo "0") ;;
    5) artifact_mtime=$(stat -c %Y "${artifacts_dir}/TEST.md" 2>/dev/null || stat -f %m "${artifacts_dir}/TEST.md" 2>/dev/null || date -r "${artifacts_dir}/TEST.md" +%s 2>/dev/null || echo "0") ;;
    6|7)
      if [ -f "${artifacts_dir}/REVIEW.md" ]; then
        artifact_mtime=$(stat -c %Y "${artifacts_dir}/REVIEW.md" 2>/dev/null || stat -f %m "${artifacts_dir}/REVIEW.md" 2>/dev/null || date -r "${artifacts_dir}/REVIEW.md" +%s 2>/dev/null || echo "0")
      fi ;;
  esac
  if [ "$artifact_mtime" -gt "$review_mtime" ] 2>/dev/null; then
    echo "[l3-review] re-review triggered for phase ${phase} (artifact mtime=${artifact_mtime} > review mtime=${review_mtime})" >&2
    return 0
  else
    echo "[l3-review] skipping L3 for phase ${phase} (artifact unchanged since last review, mtime=${review_mtime})" >&2
    return 2
  fi
}

# ── _l3_parse_result() · Step 3: 追加 L3 段 + verdict/summary 三层提取 ──
# 用法: _l3_parse_result <content> <phase> <artifacts_dir> <model>
# 输出: VERDICT=<v> 和 SUMMARY=<s> 到 stdout
_l3_parse_result() {
  local content="$1" phase="$2" artifacts_dir="$3" model="$4"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"

  # 重审检测（委托 _l3_check_rerun）
  _l3_check_rerun "$phase" "$artifacts_dir" || return 2

  # ── 追加写入 L3 段 ──
  local ts
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")
  # 追加前大小预警（>50KB warn）
  if [ -f "$review_md" ]; then
    local review_size
    review_size=$(stat -c %s "$review_md" 2>/dev/null || stat -f %z "$review_md" 2>/dev/null || echo "0")
    if [ "$review_size" -gt 51200 ] 2>/dev/null; then
      echo "[l3-review] WARNING: review file exceeds 50KB (${review_size} bytes), consider manual cleanup" >&2
    fi
  fi
  mkdir -p "$artifacts_dir"
  local section_title="## L3 盲审（${model} 外部模型 · ${ts}）"
  {
    echo ""; echo "---"; echo ""; echo "$section_title"; echo ""
    echo "> 自动生成于 ${ts}。由 l3-review.sh 写入。"
    echo ""; echo "### 审查结论"; echo ""; echo '```json'
    echo "$content"; echo '```'
  } >> "$review_md"

  # ── 提取 verdict（三层提取：代码块 → 纯 JSON → grep 正则）──
  local extracted
  extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
  local l3_verdict=""
  if [ -n "$extracted" ]; then
    l3_verdict=$(echo "$extracted" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_verdict" ]; then
    l3_verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_verdict" ]; then
    l3_verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1 || echo "")
  fi
  [ -n "$l3_verdict" ] || l3_verdict="unknown"

  # ── 提取 summary（三层提取）──
  local l3_summary=""
  if [ -n "$extracted" ]; then
    l3_summary=$(echo "$extracted" | jq -r '.summary // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_summary" ]; then
    l3_summary=$(echo "$content" | jq -r '.summary // ""' 2>/dev/null || echo "")
  fi
  if [ -z "$l3_summary" ]; then
    l3_summary=$(echo "$content" | grep -oP '"summary"\s*:\s*"\K[^"]+' 2>/dev/null | tail -1 || echo "")
  fi
  [ -n "$l3_summary" ] || l3_summary=""

  # ── 第四层故障降级 ──
  if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
    l3_verdict="error"
    l3_summary="L3 结果解析失败（verdict 不可用）"
  fi
  # Verdict 值域校验
  case "$l3_verdict" in pass|fail|error) ;; *)
    echo "[l3-review] invalid L3 verdict: $l3_verdict, defaulting to fail" >&2
    l3_verdict="fail"
    ;;
  esac

  echo "VERDICT=${l3_verdict}"
  echo "SUMMARY=${l3_summary}"
  return 0
}

# ── _l3_write_done() · Step 4: .done 文件写入（含 D3 both 检查 · 遵守 ARCHITECTURE.md §4.1 6键KVP）──
# 用法: _l3_write_done <phase> <change_id> <verdict> <summary> <l2_verdict> <artifacts_dir> <gate_config_value>
# 返回: 0=done 已写, 1=verdict 非 pass 不写, 3=写入失败
_l3_write_done() {
  local phase="$1" change_id="$2" verdict="$3" summary="$4"
  local l2_verdict="$5" artifacts_dir="$6" gate_config_value="$7"

  # D3: gate_config="both" 且 L2 段不存在 → 跳过 .done 写入
  if [[ "$gate_config_value" == "both" ]]; then
    local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
    if [ ! -f "$review_md" ] || ! grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
      echo "[l3-review] L3 content appended but .done deferred (L2 not yet complete, gate_config=both)" >&2
      return 0
    fi
  fi

  # .done 仅 pass 时写入 (fix-l3-gate AC-2/AC-3)
  if [ "$verdict" != "pass" ]; then
    echo "[l3-review] L3 verdict=${verdict} — .done NOT written (phase ${phase})" >&2
    return 1
  fi

  local done_marker="${artifacts_dir}/.independent-review-${phase}.done"
  local done_tmp="${done_marker}.tmp"
  local written_by="pre-tool-use-gate"

  # 构造 artifacts 字段 (阶段产物文件列表)
  local artifacts_list=""
  case "$phase" in
    1) artifacts_list="REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    2) artifacts_list="DESIGN.md,REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    3) artifacts_list="TASK.md,DESIGN.md,REQUIREMENT.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    5) artifacts_list="TEST.md,TASK.md,REQUIREMENT.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    6) artifacts_list="REVIEW.md,TASK.md,TEST.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    7) artifacts_list="REVIEW.md,TEST.md,TASK.md,DESIGN.md,REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md" ;;
  esac

  # 6 键 KVP 格式（遵守 ARCHITECTURE.md §4.1 跨模块契约）
  cat > "$done_tmp" <<DONE_EOF
phase=${phase}
change_id=${change_id}
written_by=${written_by}
L2_verdict=${l2_verdict}
L3_verdict=${verdict}
L3_summary=${summary}
artifacts=${artifacts_list}
DONE_EOF

  mv "$done_tmp" "$done_marker" 2>/dev/null || {
    echo "[l3-review] failed to write .done marker" >&2
    return 3
  }
  echo "[l3-review] L3 pass — .done written (phase ${phase}, verdict=${verdict})" >&2
  return 0
}

# ── l3_review_run() · 编排器（调用 4 子函数，≤50 行）──
l3_review_run() {
  local phase="$1" change_id="$2" artifacts_dir="$3" l2_verdict="$4"
  local gate_config_value="${5:-both}"
  local max_chars="${L3_MAX_ARTIFACT_CHARS:-20000}"

  # 参数校验
  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l3-review] invalid phase: $phase" >&2; return 3; }
  [ -n "$change_id" ] || { echo "[l3-review] missing change_id" >&2; return 3; }
  [ -d "$artifacts_dir" ] || { echo "[l3-review] artifacts_dir not found: $artifacts_dir" >&2; return 3; }
  [[ "$l2_verdict" =~ ^(pass|fail|skipped)$ ]] || { echo "[l3-review] invalid L2_verdict: $l2_verdict" >&2; return 3; }

  # 模型选择
  local model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}"
  [ -n "$model" ] || model="deepseek-v4-flash"

  # Step 1: 构造 prompt
  local prompt_text
  prompt_text=$(_l3_build_prompt "$phase" "$artifacts_dir" "$max_chars") || return 3

  # Step 2: 调用 API
  local content
  content=$(_l3_call_api "$prompt_text" "$model") || return 3

  # Step 3: 解析结果（含重审检测 + L3 段追加 + verdict/summary 提取）
  local l3_output l3_verdict l3_summary
  l3_output=$(_l3_parse_result "$content" "$phase" "$artifacts_dir" "$model") || {
    local rc=$?; [ $rc -eq 2 ] && return 0; return $rc
  }
  l3_verdict=$(echo "$l3_output" | grep "^VERDICT=" | cut -d= -f2-)
  l3_summary=$(echo "$l3_output" | grep "^SUMMARY=" | cut -d= -f2-)

  # Step 4: 写入 .done（含 D3 both 检查）
  _l3_write_done "$phase" "$change_id" "$l3_verdict" "$l3_summary" \
    "$l2_verdict" "$artifacts_dir" "$gate_config_value" || true

  # 返回 verdict 对应的 exit code
  case "$l3_verdict" in
    pass) return 0 ;;
    fail) return 1 ;;
    *)    return 3 ;;
  esac
}

# ── l3_review_with_timeout() · 超时降级 wrapper ──
l3_review_with_timeout() {
  local phase="$1"
  local change_id="$2"
  local artifacts_dir="$3"
  local l2_verdict="$4"
  local timeout_secs="${5:-30}"
  local gate_config_value="${6:-both}"

  # Phase 值域已在上游校验（${phase} ∈ {1..7}, ${l2_verdict} ∈ {pass,fail,skipped}），
  # 仍通过环境变量传参避免 shell 插值注入风险

  echo "[l3-review] L3 review starting (phase=${phase}, timeout=${timeout_secs}s)..." >&2

  # 尝试同步调用
  local ret=0
  timeout "${timeout_secs}s" bash -c '
    source "$0"
    l3_review_run "$1" "$2" "$3" "$4" "${5:-both}"
  ' "${BASH_SOURCE[0]}" "${phase}" "${change_id}" "${artifacts_dir}" "${l2_verdict}" "${gate_config_value:-both}" 2>/dev/null || ret=$?

  if [ $ret -eq 124 ] || [ $ret -eq 137 ]; then
    # timeout 命令返回 124 (GNU timeout) 或进程被 kill (137=128+9)
    echo "[l3-review] L3 timed out after ${timeout_secs}s — .done NOT written (verdict=timeout, phase ${phase})" >&2
    # fix-l3-gate AC-2: timeout 不写 .done；保留审计痕迹（l3_write_timeout_done 仅追加 notice 不写 .done）
    l3_write_timeout_done "$phase" "$change_id" "$artifacts_dir" "$l2_verdict"
    return 1
  fi

  return $ret
}

# ── l3_write_timeout_done() · 超时降级: 追加 timeout 段到 review 文件（不写 .done · fix-l3-gate AC-2）──
l3_write_timeout_done() {
  local phase="$1"
  local change_id="$2"
  local artifacts_dir="$3"
  local l2_verdict="$4"

  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")

  mkdir -p "$artifacts_dir"
  {
    echo ""
    echo "---"
    echo ""
    echo "## L3 盲审（timeout · ${ts}）"
    echo ""
    echo "> L3 审查超时（30s），降级为 timeout。"
    echo "> 不写 .done——pipeline 暂停等待人工处理或重试。"
    echo "> 后续 session 可通过 Stop hook 29 号模块补跑 L3。"
  } >> "$review_md"

  echo "[l3-review] timeout notice appended (phase ${phase}) — .done NOT written" >&2
}

# ── l3_dispatch_prompt() · L3 异步派发提示（对标 l2_dispatch_prompt）──
# 用法: l3_dispatch_prompt <phase> <change_id> [specs_dir] [gate_val]
# 输出: 一键 Agent 派发模板到 stdout（调用方重定向到 >&2）
# 返回: 0
l3_dispatch_prompt() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"
  local gate_val="${4:-both}"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l3-dispatch] invalid phase: $phase" >&2; return 2; }
  [ -n "$change_id" ] || { echo "[l3-dispatch] missing change_id" >&2; return 2; }

  # 确定 L2_verdict（用于 l3_review_run 参数）
  local l2v="skipped"
  if [[ "$gate_val" == "both" ]]; then
    local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"
    if [ -f "$review_md" ]; then
      l2v=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
      [ -n "$l2v" ] || l2v="fail"
    else
      l2v="fail"
    fi
  fi

  # 按阶段描述工件（与 l3_review_run case 一致）
  local artifact_desc=""
  case "$phase" in
    1) artifact_desc="REQUIREMENT.md（+ CHANGE.md）" ;;
    2) artifact_desc="DESIGN.md（+ REQUIREMENT.md + ADR）" ;;
    3) artifact_desc="TASK.md（+ REQUIREMENT.md + DESIGN.md）" ;;
    5) artifact_desc="TEST.md（+ REQUIREMENT.md + TASK.md + 各 SUMMARY）" ;;
    6) artifact_desc="REVIEW.md + git diff（+ REQUIREMENT + TASK + TEST）" ;;
    7) artifact_desc=".specs/${change_id}/ 全量产物（含 REVIEW/TEST/TASK/DESIGN/REQUIREMENT/CHANGE）" ;;
  esac

  # 生成派发提示
  cat <<DISPATCH_EOF
╔══════════════════════════════════════════════════════════════╗
║  ⚠️ L3 外部模型审查未完成（阶段 ${phase} · gate_config=${gate_val}） ║
║                                                              ║
║  L3 不走同步超时（30s 不够外部模型响应）。                     ║
║  请异步派发 L3 审查：                                          ║
║                                                              ║
║  方式 1 — 子 agent（推荐，非阻塞）：                            ║
║    Agent({                                                    ║
║      subagent_type: "general-purpose",                        ║
║      description: "L3 external review phase ${phase}",                 ║
║      prompt: "运行 L3 独立审查:                                 ║
║        source flow-kit-bundle/hooks/stop/lib/l3-review.sh      ║
║        l3_review_run ${phase} ${change_id} ${specs_dir} ${l2v} ${gate_val}   ║
║        返回 verdict 和 summary"                                ║
║    })                                                         ║
║                                                              ║
║  方式 2 — 直接 bash（阻塞但可控）：                              ║
║    source flow-kit-bundle/hooks/stop/lib/l3-review.sh && \     ║
║    l3_review_run ${phase} ${change_id} ${specs_dir} ${l2v} ${gate_val}        ║
║                                                              ║
║  参数说明:                                                     ║
║    phase=${phase}  change_id=${change_id}                          ║
║    specs_dir=${specs_dir}             ║
║    L2_verdict=${l2v}  gate_config=${gate_val}                            ║
║    artifacts: ${artifact_desc}        ║
║                                                              ║
║  完成后写入:                                                   ║
║    .specs/${change_id}/.independent-review-${phase}.done             ║
║    .specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md (追加 L3 段)   ║
║                                                              ║
║  重试: L3 完成后重新执行 phase transition 即可放行。            ║
╚══════════════════════════════════════════════════════════════╝
DISPATCH_EOF

  return 0
}
