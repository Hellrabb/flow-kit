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
#     返回: 0=pass, 1=fail, 2=timeout, 3=API error
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

# ── l3_review_run() · 主函数 ──
l3_review_run() {
  local phase="$1"
  local change_id="$2"
  local artifacts_dir="$3"
  local l2_verdict="$4"
  local max_chars="${L3_MAX_ARTIFACT_CHARS:-20000}"

  # 参数校验
  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l3-review] invalid phase: $phase" >&2; return 3; }
  [ -n "$change_id" ] || { echo "[l3-review] missing change_id" >&2; return 3; }
  [ -d "$artifacts_dir" ] || { echo "[l3-review] artifacts_dir not found: $artifacts_dir" >&2; return 3; }
  [[ "$l2_verdict" =~ ^(pass|fail)$ ]] || { echo "[l3-review] invalid L2_verdict: $l2_verdict" >&2; return 3; }

  # ── 模型选择 (env var > hardcoded default) ──
  local model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}"
  [ -n "$model" ] || model="deepseek-v4-flash"

  # ── 按阶段收集工件 + checklist ──
  local artifact=""
  local checklist=""
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
      # ADR files
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
      # Phase 6: read git diff from project root
      local project_root="$(dirname "$(dirname "$artifacts_dir")")"
      artifact=$(cd "$project_root" && git diff HEAD 2>/dev/null | head -c "$max_chars" || true)
      if [ -f "${artifacts_dir}/REVIEW.md" ]; then
        artifact="${artifact}"$'\n\n=== 主 agent REVIEW.md ===\n'"$(head -c 8000 "${artifacts_dir}/REVIEW.md" 2>/dev/null || echo "")"
      fi
      checklist="spec 合规（每条 AC 是否被代码覆盖）？代码质量（6 维衰退风险：认知过载/变更传播/知识重复/偶然复杂/依赖混乱/领域扭曲）？是否有 critical？"
      ;;
    7)
      if [ -f "${artifacts_dir}/REVIEW.md" ]; then
        artifact=$(head -c "$max_chars" "${artifacts_dir}/REVIEW.md" 2>/dev/null || echo "")
      fi
      local changelog="${project_root:-.}/CHANGELOG.md"
      if [ -f "$changelog" ]; then
        artifact="${artifact}"$'\n\n=== CHANGELOG.md ===\n'"$(head -c 4000 "$changelog" 2>/dev/null || echo "")"
      fi
      checklist="归档产物是否齐全（CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY/TEST/REVIEW）？CHANGELOG 是否更新且 Conventional Commits 语义正确？archive 是否完整？"
      ;;
  esac
  [ -n "$artifact" ] || { echo "[l3-review] no artifact for phase $phase" >&2; return 3; }

  # ── 构造 prompt (jq --arg 避免工件中反引号/$ 被 shell 解释) ──
  local prompt_text
  prompt_text=$(jq -nr \
    --arg checklist "$checklist" \
    --arg phase "$phase" \
    --arg artifact "$artifact" \
    '"你是独立审查员，对以下 flow-kit 工件做盲审。独立性要求：禁止假设作者意图，只看工件本身；不接受也不引用任何「作者认为/主 agent 结论」类外部陈述。\n\n审查重点：" + $checklist + "\n\n工件（阶段 " + $phase + "）：\n" + $artifact + "\n\n请严格按 JSON 回复，不要 markdown 代码块包裹：\n{\"critical\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"major\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"minor\":[...],\"verdict\":\"pass 或 fail\",\"summary\":\"一句话总评\"}\ncritical/major/minor 每项含 file/issue/why/fix 四要素。无问题给空数组。verdict=fail 当且仅当存在 critical。"')

  # ── 调外部模型 API (env-var-first 直连) ──
  local ai_response=""
  local base_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
  local auth_token="${ANTHROPIC_AUTH_TOKEN:-}"

  if [ -n "$auth_token" ]; then
    ai_response=$(curl -s --max-time 25 "${base_url}/v1/messages" \
      -H "Authorization: Bearer ${auth_token}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg m "$model" --arg p "$prompt_text" \
        '{model:$m, max_tokens:2000, messages:[{role:"user", content:$p}]}')" 2>/dev/null || true)
  fi

  # Path 2: Legacy ANTHROPIC_API_KEY (向后兼容)
  if [ -z "$ai_response" ] && [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    ai_response=$(curl -s --max-time 25 https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg m "$model" --arg p "$prompt_text" \
        '{model:$m, max_tokens:2000, messages:[{role:"user", content:$p}]}')" 2>/dev/null || true)
  fi

  # ── 解析响应 ──
  local content=""
  if [ -n "$ai_response" ]; then
    content=$(echo "$ai_response" | jq -r '.content[0].text // empty' 2>/dev/null || echo "")
  fi

  # ── API 调用失败 ──
  if [ -z "$content" ]; then
    echo "[l3-review] L3 API call failed (no content in response)" >&2
    return 3
  fi

  # ── 追加 L3 段到 review 文件 (追加非覆盖，保留 L2 段) ──
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")
  local written_by="pre-tool-use-gate"

  mkdir -p "$artifacts_dir"
  {
    echo ""
    echo "---"
    echo ""
    echo "## L3 盲审（${model} 外部模型 · ${ts}）"
    echo ""
    echo "> 自动生成于 ${ts}。由 l3-review.sh 写入。"
    echo ""
    echo "### 审查结论"
    echo ""
    echo '```json'
    echo "$content"
    echo '```'
  } >> "$review_md"

  # ── 提取 verdict ──
  local extracted
  extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
  [ -n "$extracted" ] || extracted="$content"
  local l3_verdict
  l3_verdict=$(echo "$extracted" | jq -r '.verdict // "unknown"' 2>/dev/null || echo "unknown")

  # Verdict 值域校验 (非法值降级)
  case "$l3_verdict" in pass|fail) ;; *)
    echo "[l3-review] invalid L3 verdict: $l3_verdict, defaulting to fail" >&2
    l3_verdict="fail"
    ;;
  esac

  # ── 写入完整 6 键 .done 文件 (原子写入: tmp → mv) ──
  local done_marker="${artifacts_dir}/.independent-review-${phase}.done"
  local done_tmp="${done_marker}.tmp"

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

  cat > "$done_tmp" <<DONE_EOF
phase=${phase}
change_id=${change_id}
written_by=${written_by}
L2_verdict=${l2_verdict}
L3_verdict=${l3_verdict}
artifacts=${artifacts_list}
DONE_EOF

  mv "$done_tmp" "$done_marker" 2>/dev/null || {
    echo "[l3-review] failed to write .done marker" >&2
    return 3
  }

  echo "[l3-review] L3 complete (phase ${phase}, verdict=${l3_verdict}, L2_verdict=${l2_verdict}) → ${done_marker}" >&2

  # 返回 verdict 对应的 exit code
  case "$l3_verdict" in
    pass) return 0 ;;
    fail) return 1 ;;
    *) return 3 ;;
  esac
}

# ── l3_review_with_timeout() · 超时降级 wrapper ──
l3_review_with_timeout() {
  local phase="$1"
  local change_id="$2"
  local artifacts_dir="$3"
  local l2_verdict="$4"
  local timeout_secs="${5:-30}"

  echo "[l3-review] L3 review starting (phase=${phase}, timeout=${timeout_secs}s)..." >&2

  # 尝试同步调用
  local ret=0
  timeout "${timeout_secs}s" bash -c "
    source '${BASH_SOURCE[0]}'
    l3_review_run '${phase}' '${change_id}' '${artifacts_dir}' '${l2_verdict}'
  " 2>/dev/null || ret=$?

  if [ $ret -eq 124 ] || [ $ret -eq 137 ]; then
    # timeout 命令返回 124 (GNU timeout) 或进程被 kill (137=128+9)
    echo "[l3-review] L3 timed out after ${timeout_secs}s — writing timeout .done" >&2
    l3_write_timeout_done "$phase" "$change_id" "$artifacts_dir" "$l2_verdict"
    return 2
  fi

  return $ret
}

# ── l3_write_timeout_done() · 超时降级: 写 L3_verdict=timeout 的 .done ──
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
    echo "> 后续 session 可通过 Stop hook 29 号模块补跑 L3。"
  } >> "$review_md"

  # 写入 timeout .done (6 键)
  local done_marker="${artifacts_dir}/.independent-review-${phase}.done"
  local done_tmp="${done_marker}.tmp"
  local artifacts_list="REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md"

  cat > "$done_tmp" <<DONE_EOF
phase=${phase}
change_id=${change_id}
written_by=pre-tool-use-gate
L2_verdict=${l2_verdict}
L3_verdict=timeout
artifacts=${artifacts_list}
DONE_EOF

  mv "$done_tmp" "$done_marker" 2>/dev/null || true
  echo "[l3-review] timeout .done written: ${done_marker}" >&2
}
