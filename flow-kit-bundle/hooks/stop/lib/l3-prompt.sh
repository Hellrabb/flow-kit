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

# ── _l3_inject_context() · Step 0: 前次审查上下文注入（l3-pipeline-fix-2026-07 D4）──
# 用法: _l3_inject_context <phase> <artifacts_dir>
# 输出: context_preamble 到 stdout（若 INDEPENDENT-REVIEW-{phase}.md 不存在则输出空）
_l3_inject_context() {
  local phase="$1" artifacts_dir="$2"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  [ -f "$review_md" ] || return 0

  local l2_verdict l3_verdict agent_response
  l2_verdict=$(grep -m1 '^\*\*Verdict\*\*: ' "$review_md" 2>/dev/null | head -1 || echo "")
  l3_verdict=$(grep -A1 '"verdict"' "$review_md" 2>/dev/null | grep -o '"verdict":"[^"]*"' | tail -1 | tr -d '"' || echo "")
  agent_response=$(sed -n '/## 主 agent 响应/,/^## /p' "$review_md" 2>/dev/null | head -30 || echo "")

  if [ -z "$l2_verdict" ] && [ -z "$l3_verdict" ]; then
    return 0  # 无审查上下文可注入
  fi

  cat <<CTX_EOF

[前次审查上下文 · 最近一次]
- ${l2_verdict:-L2 Verdict: (无)}
- L3 Verdict: ${l3_verdict:-verdict:(无)}
- 主 agent 已响应前次发现（详见 INDEPENDENT-REVIEW-${phase}.md）
[注意：以上为历史审查上下文，本次审查仍应基于工件本身独立判断]

CTX_EOF
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
