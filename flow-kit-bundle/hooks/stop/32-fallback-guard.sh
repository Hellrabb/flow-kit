#!/bin/bash
# 32-fallback-guard.sh — Fallback 模式终点 hook 兜底
#
# 检测 mode=fallback + pipeline scope + current_phase=7 + PCSC 全✅
# → 自动更新 goal.status = "done"
#
# 覆盖边界 (REQUIREMENT US-4 声明):
#   v1 仅覆盖 pipeline 终点 (phase 7 → done 标记)。
#   phase 4→5→6→7 的 fallback 推进仍依赖 GO.md prompt 路由 (P1-3)。
#   若弱模型在中间阶段卡住，用户需手动 intervention。

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# ── Gate 1: 模块启用 ──
module_enabled "fallback_guard" && true  # 默认启用 (无独立开关时 fallback 兜底始终生效)
# fallback_guard 模块默认不配独立开关——它只在 mode=fallback 时触发，无额外开销

# ── Gate 2: flow-kit 活跃 ──
flow_file="${PROJECT_ROOT}/.flow-active"
[ -f "$flow_file" ] || exit 0
jq empty "$flow_file" 2>/dev/null || exit 0

# ── Gate 3: mode == "fallback" ──
mode=$(jq -r '.goal.mode // ""' "$flow_file" 2>/dev/null || echo "")
[[ "$mode" == "fallback" ]] || exit 0

# ── Gate 4: scope == "pipeline" ──
scope=$(jq -r '.goal.scope // ""' "$flow_file" 2>/dev/null || echo "")
[[ "$scope" == "pipeline" ]] || exit 0

# ── Gate 5: current_phase == "7" (仅终点触发) ──
current_phase=$(jq -r '.goal.current_phase // ""' "$flow_file" 2>/dev/null || echo "")
[[ "$current_phase" == "7" ]] || exit 0

# ── Gate 6: goal.status 尚为 active ──
status=$(jq -r '.goal.status // ""' "$flow_file" 2>/dev/null || echo "")
[[ "$status" == "active" ]] || exit 0

# ── Gate 7: phase 7 PCSC 全✅ (硬编码产物清单, v1) ──
# 此清单需与以下 prompt 的 PCSC 段保持同步:
#   flow-kit-bundle/flow-kit/prompts/7-integration.md § "阶段完成自检" 表
change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
{ [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0
spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

pcsc_ok=true
for f in "CHANGE.md" "REQUIREMENT.md" "DESIGN.md" "TASK.md" "TEST.md" "REVIEW.md"; do
  if [ ! -f "${spec_dir}/${f}" ]; then
    pcsc_ok=false
    break
  fi
done
# .independent-review-7.done (若 gate_config 对 phase 7 开启 L3/both/independent)
if jq -e '.goal.gate_config["7-integration"] // "" | test("^(both|L3|independent|true)$")' "$flow_file" >/dev/null 2>&1; then
  [ -f "${spec_dir}/.independent-review-7.done" ] || pcsc_ok=false
fi

if [ "$pcsc_ok" = false ]; then
  echo "[32-fallback-guard] PCSC 不全, 不标记 done" >&2
  exit 0
fi

# ── 标记 goal.status = "done" ──
tmp_flow="${flow_file}.tmp"
if jq '.goal.status = "done" | .updated_at = now' "$flow_file" > "$tmp_flow" 2>/dev/null; then
  mv "$tmp_flow" "$flow_file" 2>/dev/null || { echo "[32-fallback-guard] failed to update goal.status" >&2; exit 0; }
  echo "[32-fallback-guard] fallback pipeline complete → goal.status=done" >&2
fi

exit 0
