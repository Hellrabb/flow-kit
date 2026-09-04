# shellcheck shell=bash
# l3-prompt.sh — L3 审查 prompt 构造 + 格式化（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 函数:
#   _l3_format_result   — L3 反馈统一格式化
#   _l3_inject_context  — Step 0: 前次审查上下文注入
#   _l3_build_prompt    — Step 1: 按阶段收集工件 + 构造审查 prompt

# ── _l3_format_result() · L3 反馈统一格式化 ──
# 用法: _l3_format_result <verdict> <summary> <report_relative_path>
# 输出: 单行 L3_RESULT: 格式，供 F1(PreToolUse stdout) 和 F2(SessionStart banner) 共用
_l3_format_result() {
  local verdict="$1" summary="$2" report="$3"
  # 值域校验：仅允许已知 verdict 值，非法值降级为 unknown
  case "$verdict" in pass|fail|timeout|error) ;; *) verdict="unknown" ;; esac
  echo "L3_RESULT: verdict=${verdict} summary=${summary} report=${report}"
}

# ── _l3_utf8_head_bytes() · D7 字节 cap + UTF-8 边界回退（文件形 · l3-prompt-loop-fix）──
# 用法: _l3_utf8_head_bytes <max_bytes> <file>
# 输出: 文件前 max_bytes 字节内、末尾不落在 UTF-8 多字节序列中间的内容
#       文件不存在/空 → 静默（空输出，exit 0）
_l3_utf8_head_bytes() {
  local max_bytes="$1" file="$2"
  [ -f "$file" ] || return 0
  head -c "$max_bytes" "$file" | _l3_utf8_head_stream "$max_bytes"
}

# ── _l3_utf8_head_stream() · D7 字节 cap + UTF-8 边界回退（stdin 流形 · l3-prompt-loop-fix）──
# 用法: <stream> | _l3_utf8_head_stream <max_bytes>
# 尾部落在多字节序列中间时回退 ≤5 字节至上一完整字符边界（od 字节级检查续字节 0x80-0xBF）
_l3_utf8_head_stream() {
  local max_bytes="$1"
  local LC_ALL=C
  local data len i back=0 b lead expect
  data=$(head -c "$max_bytes" 2>/dev/null; echo _U8S_)
  data=${data%_U8S_}
  len=${#data}
  [ "$len" -gt 0 ] || return 0
  # 扫描尾部连续续字节（10xxxxxx = 0x80-0xBF，窗口 ≤5）
  for ((i = len - 1; i >= 0 && i >= len - 5; i--)); do
    b=$(printf '%s' "${data:i:1}" | od -An -tu1 | tr -d ' \n')
    [ "$b" -ge 128 ] && [ "$b" -le 191 ] || break
    back=$((back + 1))
  done
  # back=0 且尾字节本身是 lead（194-244）→ 其续字节被截，必不完整 → 回退 1
  if [ "$back" -eq 0 ]; then
    b=$(printf '%s' "${data:len-1:1}" | od -An -tu1 | tr -d ' \n')
    if [ "$b" -ge 194 ] && [ "$b" -le 244 ]; then
      data="${data:0:len-1}"
      printf '%s' "$data"
      return 0
    fi
    printf '%s' "$data"
    return 0
  fi
  # 续字节序列前一字节判定 lead 字节与期望序列长度
  i=$((len - back - 1))
  if [ "$i" -ge 0 ]; then
    lead=$(printf '%s' "${data:i:1}" | od -An -tu1 | tr -d ' \n')
    expect=0
    [ "$lead" -ge 194 ] && [ "$lead" -le 223 ] && expect=2
    [ "$lead" -ge 224 ] && [ "$lead" -le 239 ] && expect=3
    [ "$lead" -ge 240 ] && [ "$lead" -le 244 ] && expect=4
    if [ "$expect" -gt 0 ]; then
      if [ "$back" -lt "$((expect - 1))" ]; then
        back=$((back + 1))     # lead 本身被截 → 连 lead 一起回退
      else
        back=0                 # 序列完整（back == expect-1）→ 无需回退
      fi
    fi
    # expect=0：孤立续字节（lead 非法/ASCII）→ 维持 back 丢弃孤立续字节
  fi
  if [ "$back" -gt 0 ]; then
    [ "$back" -le "$len" ] && data="${data:0:len-back}"
  fi
  printf '%s' "$data"
}

# ── _l3_extract_prior_findings() · D2/D3 前轮发现提取（l3-prompt-loop-fix）──
# 用法: _l3_extract_prior_findings <review_md>
# 输出: severity|file|摘要 单行集（critical > major；同 severity L3 先于 L2；
#       每行 ≤200B 超长截断加 …；摘要内 | 替换为 /）
#       文件不存在 / 两类提取源皆空 → 空输出 exit 0；minor 不提取
_l3_extract_prior_findings() {
  local review_md="$1"
  local LC_ALL=C
  [ -f "$review_md" ] || return 0
  local nl=$'\n'
  local section="" line sev summ file
  local out_l3="" out_l2=""
  local in_json=0 json_buf=""
  local red_e moon_e
  red_e=$(printf '\xf0\x9f\x94\xb4')   # 🔴 lead bytes
  moon_e=$(printf '\xf0\x9f\x9f\xa1')  # 🟡 lead bytes
  local pend_sev="" pend_summ=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '## L2'*) section="L2" ;;
      '## L3'*) section="L3" ;;
      '## '*) section="other" ;;
    esac
    if [ "$section" = "L3" ]; then
      case "$line" in
        '```'*)
          if [ "$in_json" -eq 1 ]; then
            in_json=0
            out_l3+=$(printf '%s' "$json_buf" | jq -r '
              (.critical[]? | "critical|\(.file // "?" | gsub("\\|"; "/"))|\((.issue // "") | split("。")[0] | gsub("\\|"; "/"))"),
              (.major[]?   | "major|\(.file // "?" | gsub("\\|"; "/"))|\((.issue // "") | split("。")[0] | gsub("\\|"; "/"))")
            ' 2>/dev/null)"$nl"
            json_buf=""
          else
            in_json=1
          fi
          ;;
        *) [ "$in_json" -eq 1 ] && json_buf+="$line"$'\n' ;;
      esac
      continue
    fi
    if [ "$section" = "L2" ]; then
      case "$line" in
        "### ${red_e}"*)
          pend_sev="critical"
          pend_summ=${line#"### ${red_e}"}
          pend_summ=${pend_summ#*：}
          pend_summ=${pend_summ//'|'/'/'}
          ;;
        "### ${moon_e}"*)
          pend_sev="major"
          pend_summ=${line#"### ${moon_e}"}
          pend_summ=${pend_summ#*：}
          pend_summ=${pend_summ//'|'/'/'}
          ;;
        '**Symptom（症状）**：'*)
          if [ -n "$pend_sev" ]; then
            file=${line#'**Symptom（症状）**：'}
            file=${file%%[[:space:]]*}
            file=${file//'|'/'/'}
            out_l2+="${pend_sev}|${file}|${pend_summ}"$'\n'
            pend_sev=""
          fi
          ;;
      esac
    fi
  done < "$review_md"
  local l trimmed final=""
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    if [ "${#l}" -gt 200 ]; then
      trimmed="${l:0:197}…"
    else
      trimmed="$l"
    fi
    final+="${trimmed}"$'\n'
  done <<EOF
$(printf '%s' "$out_l3" | grep '^critical|' 2>/dev/null)
$(printf '%s' "$out_l2" | grep '^critical|' 2>/dev/null)
$(printf '%s' "$out_l3" | grep '^major|' 2>/dev/null)
$(printf '%s' "$out_l2" | grep '^major|' 2>/dev/null)
EOF
  printf '%s' "$final"
}
# 用法: _l3_inject_context <phase> <artifacts_dir>
# 输出: context_preamble 到 stdout（四象限注入矩阵 · l3-prompt-loop-fix D2/D3/D4）
#   findings+响应 → verdict + 摘要(≤600B) + 响应要点(≤200B)
#   findings+未响应 → verdict + 摘要 + 未响应标注
#   无 findings+响应 → verdict + 响应要点
#   仅 verdict 可解析 → verdict 行
#   文件缺失/空 或 三者皆无 → 静默
_l3_inject_context() {
  local phase="$1" artifacts_dir="$2"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  [ -s "$review_md" ] || return 0
  local LC_ALL=C

  local l2_verdict l3_verdict
  l2_verdict=$(grep -m1 '^\*\*Verdict\*\*: ' "$review_md" 2>/dev/null || true)
  l3_verdict=$(grep -A1 '"verdict"' "$review_md" 2>/dev/null | grep -o '"verdict":"[^"]*"' | tail -1 | tr -d '"' || true)

  # D4 三锚响应检测：段头 / 反驳段 / 行内分类标记（不锚行首——实测 `- **R1** — Fixed in:`）
  local has_response=0
  if grep -q '^## 主 agent 响应' "$review_md" 2>/dev/null \
    || grep -q '主 agent 反驳：' "$review_md" 2>/dev/null \
    || grep -qE '(Fixed in|Tech-debt|Not-applicable):' "$review_md" 2>/dev/null; then
    has_response=1
  fi

  # D2/D3 前轮发现单行摘要（600B 配额 + (+k more) 折叠）
  local findings quota_out="" total=0 included=0 section_bytes=0 line lb
  findings=$(_l3_extract_prior_findings "$review_md")
  if [ -n "$findings" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && total=$((total + 1))
    done <<EOF
$findings
EOF
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      lb=$(printf '%s' "$line" | wc -c)
      [ $((section_bytes + lb)) -gt 600 ] && break
      quota_out+="${line}"$'\n'
      section_bytes=$((section_bytes + lb))
      included=$((included + 1))
    done <<EOF
$findings
EOF
  fi

  # 响应要点（行内分类标记行，≤200B，"；" 连接）
  local resp="" resp_bytes=0 rl rlb
  while IFS= read -r rl; do
    [ -z "$rl" ] && continue
    rlb=$(printf '%s' "$rl" | wc -c)
    [ $((resp_bytes + rlb + 3)) -gt 200 ] && break
    [ -n "$resp" ] && resp+='；'
    resp+="$rl"
    resp_bytes=$((resp_bytes + rlb))
  done < <(grep -E '(Fixed in|Tech-debt|Not-applicable):' "$review_md" 2>/dev/null | head -8)

  # 三者皆无 → 无可注入
  [ -z "$l2_verdict$l3_verdict$quota_out$resp" ] && return 0

  local nl=$'\n'
  local out=""
  out+="[前次审查上下文 · 最近一次]"$nl
  [ -n "$l2_verdict" ] && out+="- ${l2_verdict}"$nl
  [ -n "$l3_verdict" ] && out+="- L3 ${l3_verdict}"$nl
  if [ -n "$quota_out" ]; then
    out+="前轮发现摘要："$nl
    out+="$quota_out"
    [ "$included" -lt "$total" ] && out+="(+$((total - included)) more)"$nl
  fi
  if [ -n "$resp" ]; then
    out+="主 agent 响应要点：${resp}"$nl
  elif [ -n "$quota_out" ] && [ "$has_response" -eq 0 ]; then
    out+="主 agent 未响应前次发现（本次请独立复核是否仍成立）"$nl
  fi
  out+="[注意：以上为历史审查上下文，本次审查仍应基于工件本身独立判断]"$nl
  printf '%s' "$out"
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
      local adr_dir
      adr_dir="$(dirname "$artifacts_dir")/adr"
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
      local project_root
      project_root="$(dirname "$(dirname "$artifacts_dir")")"
      # source common.sh for fk_estimate_tokens (fail-open)
      local _common_lib="${HOOK_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/common.sh"
      [ -f "$_common_lib" ] && source "$_common_lib" 2>/dev/null || true
      local _new_limit=$((max_chars / 4))
      artifact=$(cd "$project_root" && {
        # 并集策略: git diff HEAD (工作区 vs HEAD) + git diff --cached (index vs HEAD)
        # 用 awk 按文件路径去重（同名文件取首次出现的更完整的 diff）
        { git diff HEAD 2>/dev/null; echo ""; git diff --cached 2>/dev/null; } | awk '
          /^diff --git/ { f=$3; if (seen[f]++) next }
          { print }
        '
        git ls-files --others --exclude-standard 2>/dev/null | grep -E '\.(sh|bats)$' | while read -r f; do
          echo ""; echo "=== NEW FILE: $f ==="
          head -c "$_new_limit" "$project_root/$f" 2>/dev/null || true
        done
      } | {
        if declare -f fk_estimate_tokens >/dev/null 2>&1; then
          local _raw && _raw=$(cat) && local _est && _est=$(fk_estimate_tokens "$_raw" 2>/dev/null || echo "0")
          local _max_tokens=$(( ${FK_CONTEXT_WINDOW:-100000} * 60 / 100 ))
          if [ "${_est:-0}" -le "${_max_tokens:-60000}" ] 2>/dev/null; then
            echo "$_raw"
          else
            echo "$_raw" | head -c "$max_chars"
          fi
        else
          head -c "$max_chars"
        fi
      } || true)
      if [ -f "${artifacts_dir}/REVIEW.md" ]; then
        artifact="${artifact}"$'\n\n=== 主 agent REVIEW.md ===\n'"$(head -c 8000 "${artifacts_dir}/REVIEW.md" 2>/dev/null || echo "")"
      fi
      checklist="spec 合规（每条 AC 是否被代码覆盖）？代码质量（6 维衰退风险：认知过载/变更传播/知识重复/偶然复杂/依赖混乱/领域扭曲）？是否有 critical？"
      ;;
    7)
      local project_root
      project_root="$(dirname "$(dirname "$artifacts_dir")")"
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
