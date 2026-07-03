#!/bin/bash
# 31-auto-advance.sh — auto_advance hook 兜底（P1-1/F4 修复）
#
# 检测 auto_advance=true + current_phase ∈ {4,5,6,7} + PCSC 全✅ + gate 合规
# → 自动执行 transition jq 推进到下一阶段
#
# 依赖: 29 (L3 fallback) 在 31 之前执行 (编号 29 < 31)
#       29 补写 .done 后 31 的 gate 合规检查才能通过

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"
[ -f "${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh" ] && source "${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh"

# ── Gate 1: 模块启用 ──
module_enabled "auto_advance" && true

# ── Gate 2: flow-kit 活跃 ──
flow_file="${PROJECT_ROOT}/.flow-active"
[ -f "$flow_file" ] || exit 0
jq empty "$flow_file" 2>/dev/null || exit 0

# ── Gate 3: auto_advance == true ──
auto_advance=$(jq -r '.goal.auto_advance // false' "$flow_file" 2>/dev/null || echo "false")
[[ "$auto_advance" == "true" ]] || exit 0

# ── Gate 4: current_phase ∈ {4,5,6,7} ──
current_phase=$(jq -r '.goal.current_phase // ""' "$flow_file" 2>/dev/null || echo "")
[[ "$current_phase" =~ ^(4|5|6|7)$ ]] || exit 0

change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
{ [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0
spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

# ── Gate 5: PCSC 全✅ (硬编码产物清单, v1) ──
# 此清单需与以下 prompt 的 PCSC 段保持同步:
#   flow-kit-bundle/flow-kit/prompts/4-dev.md     § "阶段完成自检" 表
#   flow-kit-bundle/flow-kit/prompts/5-test.md     § "阶段完成自检" 表
#   flow-kit-bundle/flow-kit/prompts/6-review.md   § "阶段完成自检" 表
#   flow-kit-bundle/flow-kit/prompts/7-integration.md § "阶段完成自检" 表
pcsc_ok=true
case "$current_phase" in
  4)  # Phase 4: 至少 1 个 SUMMARY.md + TASK.md 中当前 task done
      # v1 简化: 检查 SUMMARY 文件存在 + TASK.md 存在
      [ -f "${spec_dir}/TASK.md" ] || pcsc_ok=false
      # 至少 1 个 SUMMARY (检查最可能的命名)
      ls "${spec_dir}/"SUMMARY*.md 2>/dev/null | head -1 | grep -q "SUMMARY" || pcsc_ok=false
      ;;
  5)  # Phase 5: TEST.md
      [ -f "${spec_dir}/TEST.md" ] || pcsc_ok=false
      ;;
  6)  # Phase 6: REVIEW.md
      [ -f "${spec_dir}/REVIEW.md" ] || pcsc_ok=false
      ;;
  7)  # Phase 7: 全部产物 + .independent-review-7.done (若 gate 开启)
      for f in "CHANGE.md" "REQUIREMENT.md" "DESIGN.md" "TASK.md" "TEST.md" "REVIEW.md"; do
        [ -f "${spec_dir}/${f}" ] || { pcsc_ok=false; break; }
      done
      ;;
esac

if [ "$pcsc_ok" = false ]; then
  echo "[31-auto-advance] PCSC 不全 (phase ${current_phase})，不自动推进" >&2
  exit 0
fi

# ── Gate 6 (新增 · gate 意识 · DESIGN R2修复): 独立审查 gate 合规 ──
# 若当前阶段 gate_config 开启独立审查，必须检查 .done 存在且有效
if type fk_independent_review_gate_active >/dev/null 2>&1; then
  if fk_independent_review_gate_active "$current_phase" 2>/dev/null; then
    done_marker="${spec_dir}/.independent-review-${current_phase}.done"
    if type fk_validate_done_marker >/dev/null 2>&1; then
      if ! fk_validate_done_marker "$done_marker" "$current_phase" "$change_id" "transition" 2>/dev/null; then
        echo "[31-auto-advance] gate 开启但 .done 无效 (phase ${current_phase})，不自动推进" >&2
        exit 0
      fi
    else
      # fk_validate_done_marker 不可用 → 降级: 至少检查文件存在
      [ -f "$done_marker" ] || { echo "[31-auto-advance] gate 开启但 .done 缺失 (phase ${current_phase})" >&2; exit 0; }
    fi
  fi
fi

# ── 执行 transition jq ──
next_phase=$((current_phase + 1))
gate_key="${current_phase}→${next_phase}"
tmp_flow="${flow_file}.tmp"

echo "[31-auto-advance] auto-advancing phase ${current_phase} → ${next_phase}" >&2

if jq --arg next "$next_phase" --arg gk "$gate_key" \
  '.goal.current_phase = $next | .goal.phases_done += [($next|tonumber - 1|tostring)] | .goal.gates[$gk] = "passed" | .updated_at = now' \
  "$flow_file" > "$tmp_flow" 2>/dev/null; then
  mv "$tmp_flow" "$flow_file" 2>/dev/null || true
fi

exit 0
