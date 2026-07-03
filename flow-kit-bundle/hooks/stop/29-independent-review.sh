#!/bin/bash
# 29-independent-review.sh — 独立 review L3（外部模型强制审查）
#
# 当某 change 在阶段 1/2/3/5/6/7 开启了独立 review（gate_config 或 stop-hook.json），
# 用外部模型（默认 deepseek-v4-flash）对该阶段产物做盲审，产出
# .specs/<id>/INDEPENDENT-REVIEW-<phase>.md，并写 .flow-active.independent-review
# 握手文件供 SessionStart 注入 + 主 agent 判 done。
#
# 与 30-ai-analyze.sh 的区别：
#   - 不走频率门控（独立质量门不能被随机跳过），用幂等（本阶段已成功跑过则跳过）防重复。
#   - 工件是代码/设计文档，含反引号/$，必须用 jq --arg 构造 prompt（不能用 heredoc 插值）。
# 任何路径都 exit 0，不断 Stop 链。

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"
[ -f "${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh" ] && source "${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh"

# ── Gate 1: 模块启用 ──
module_enabled "independent_review" || exit 0

# ── Gate 2: flow-kit 活跃且合法 ──
flow_file="${PROJECT_ROOT}/.flow-active"
[ -f "$flow_file" ] || exit 0
jq empty "$flow_file" 2>/dev/null || exit 0

phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
{ [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0

# ── Gate 3: 阶段 ∈ {1,2,3,5,6,7} 且独立 review gate 开启 ──
[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || exit 0
fk_independent_review_gate_active "$phase" || exit 0

# ── 数值配置 sanitize（防 set -u/-e 下非数字炸）──
max_chars=$(config_get '.independent_review.max_artifact_chars' "20000")
[[ "$max_chars" =~ ^[0-9]+$ ]] || max_chars=20000
max_fail=$(config_get '.independent_review.max_failures_before_bypass' "3")
[[ "$max_fail" =~ ^[0-9]+$ ]] || max_fail=3
# Model: env var (ANTHROPIC_DEFAULT_HAIKU_MODEL) > config > hardcoded default
default_model=$(config_get '.ai.model' "deepseek-v4-flash")
configured_model=$(config_get '.independent_review.model' "$default_model")
model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$configured_model}"
[ -n "$model" ] || model="deepseek-v4-flash"

# ── Gate 4: 幂等——本阶段 L3 已成功就跳过 ──
state_file="${PROJECT_ROOT}/.flow-active.independent-review"
if [ -f "$state_file" ]; then
  prev_status=$(jq -r --arg p "$phase" '.[$p].status // ""' "$state_file" 2>/dev/null || echo "")
  if [[ "$prev_status" == "done" ]]; then
    exit 0
  fi
fi

spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

# ── Gate 5: done 标志已写（主 agent 收齐了）→ 清理握手文件 ──
done_marker="${spec_dir}/.independent-review-${phase}.done"
if [ -f "$done_marker" ]; then
  rm -f "$state_file"
  exit 0
fi

# ── 防线 2：pipeline 模式强制 auto_advance=false ──
if jq -e '.goal.scope // "" | . == "pipeline"' "$flow_file" >/dev/null 2>&1; then
  tmp_flow="${flow_file}.tmp"
  if jq '.goal.auto_advance = false | .updated_at = now' "$flow_file" > "$tmp_flow" 2>/dev/null; then
    mv "$tmp_flow" "$flow_file" 2>/dev/null || true
  fi
fi

# ── 收集工件 + 提取 L2_verdict ──
spec_dir="${PROJECT_ROOT}/.specs/${change_id}"
review_md="${spec_dir}/INDEPENDENT-REVIEW-${phase}.md"
l2_verdict="fail"  # 默认 fail（保守）
if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
  l2v_extracted=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
  [ -n "$l2v_extracted" ] && l2_verdict="$l2v_extracted"
fi

# ── 调用共享 lib l3-review.sh 执行 L3（P0-1/F1 修复）──
l3_lib="${HOOK_BASE_DIR}/lib/l3-review.sh"
if [ -f "$l3_lib" ]; then
  source "$l3_lib" 2>/dev/null || true
  if type l3_review_run >/dev/null 2>&1; then
    l3_review_run "$phase" "$change_id" "$spec_dir" "$l2_verdict" 2>/dev/null && rc=0 || rc=$?
    # l3_review_run 内部完成: L3 API 调用 → 写 L3 段 → 写 6 键 .done
    case $rc in
      0) module_output "info" "IR" "L3 独立 review 完成（阶段 ${phase}, verdict=pass, L2_verdict=${l2_verdict}）→ INDEPENDENT-REVIEW-${phase}.md + .done";;
      1) module_output "info" "IR" "L3 独立 review 完成（阶段 ${phase}, verdict=fail, L2_verdict=${l2_verdict}）→ INDEPENDENT-REVIEW-${phase}.md + .done";;
      *) module_output "warning" "IR" "L3 独立 review 调用失败（阶段 ${phase}, rc=${rc}），需人工检查";;
    esac
    # 清理旧握手文件（若存在，不再需要——l3_review_run 直接写 .done）
    state_file="${PROJECT_ROOT}/.flow-active.independent-review"
    rm -f "$state_file" 2>/dev/null || true
    exit 0
  fi
fi

# ── l3-review.sh 不可用时的旧版回退（兼容过渡期）──
module_output "warning" "IR" "l3-review.sh 共享 lib 未找到，L3 审查跳过（需安装 pipeline-fallback-fix）"
