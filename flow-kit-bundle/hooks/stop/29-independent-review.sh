#!/bin/bash
# 29-independent-review.sh — 独立 review L3（外部模型强制审查）
#
# 当 gate_config[phase] ∈ {L3, both} 时，用外部模型盲审阶段产物。
# 若仅开启 L2（gate_config = "L2"），本 hook 跳过不跑。
# 产出 .specs/<id>/INDEPENDENT-REVIEW-<phase>.md 的 L3 段 + 握手文件。
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

# D3 fix: pipeline-aware phase resolution (was: jq -r '.phase')
phase=$(fk_resolve_phase 2>/dev/null || jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
{ [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0

# ── Gate 3: 阶段 ∈ {1,2,3,5,6,7} 且 L3 独立 review 开启 ──
[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || exit 0
if ! fk_independent_review_gate_active "$phase" "L3"; then
  echo "[independent-review] L3 skipped (gate_config L3 not active for phase $phase)" >&2
  exit 0
fi

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

# perf timing (l3-pipeline-fix-2026-07 D5)
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "29" || true

# L3 async mode: opt-in via L3_BACKGROUND=1 (default sync to ensure .done written)
# --background 在 l3-review.sh 中实现，子进程写入 .l3-bg-{phase}.json 供 SessionStart 收割
L3_BG_FLAG=""
[ "${L3_BACKGROUND:-0}" = "1" ] && L3_BG_FLAG="--background"

# ── _l3_scan_backlog() · 积压扫描（l3-pipeline-fix-2026-07 D3）──
_l3_scan_backlog() {
  local flow_file="$1" spec_dir="$2" l3_lib="$3"
  local phases_done gate_config backlog=()

  phases_done=$(jq -r '.goal.phases_done // [] | .[]' "$flow_file" 2>/dev/null || echo "")
  [ -n "$phases_done" ] || return 0

  while IFS= read -r pn; do
    [ -n "$pn" ] || continue
    local phase_name="${PHASE_GATE_KEY_MAP[$pn]:-}"
    [ -n "$phase_name" ] || continue
    local gv
    gv=$(jq -r --arg pn "$phase_name" '.goal.gate_config[$pn] // ""' "$flow_file" 2>/dev/null || echo "")
    case "$gv" in independent|true) gv="both" ;; L3|both) ;; *) continue ;; esac
    local dm="${spec_dir}/.independent-review-${pn}.done"
    [ -f "$dm" ] && continue
    backlog+=("$pn")
  done <<< "$phases_done"

  local count=0
  for pn in "${backlog[@]}"; do
    [ "$count" -ge 3 ] && { echo "[backlog] ${#backlog[@]} phases total, $(( ${#backlog[@]} - 3 )) deferred to next Stop hook" >&2; break; }
    echo "[backlog] running L3 for phase ${pn} (backlog scan)" >&2
    if [ -f "$l3_lib" ] && type l3_review_run >/dev/null 2>&1; then
      l3_review_run "$pn" "$change_id" "$spec_dir" "skipped" "both" $L3_BG_FLAG || true
      local bl_rc=$?
      if [ "$bl_rc" != "0" ]; then
        module_output "warning" "IR" "backlog L3 failed for phase ${pn} (rc=${bl_rc})——see hooks.log"
      fi
    fi
    count=$((count + 1))
  done
}

# ── Gate 5: done 标志已写（主 agent 收齐了）→ 清理握手文件 ──
done_marker="${spec_dir}/.independent-review-${phase}.done"
if [ -f "$done_marker" ]; then
  module_output "info" "IR" "skipped: ${done_marker} — L3 already completed for phase ${phase}"
  rm -f "$state_file"
  declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "29" || true
  exit 0
fi

# ── 积压扫描：在审查当前 phase 前补齐历史缺失的 L3 ──
l3_lib="${HOOK_BASE_DIR}/lib/l3-review.sh"
[ -f "$l3_lib" ] && source "$l3_lib" 2>/dev/null || true
_l3_scan_backlog "$flow_file" "$spec_dir" "$l3_lib"

# ── D4 fix: L2 检测 — both 模式 L2 未完成时输出派发提示 ──
	phase_name="${PHASE_GATE_KEY_MAP[$phase]:-}"
gate_val=$(jq -r --arg pn "$phase_name" \
  '.goal.gate_config[$pn] // ""' "$flow_file" 2>/dev/null || echo "")
case "$gate_val" in
  independent|true) gate_val="both" ;;
  L2|L3|both) ;;
  *) gate_val="" ;;
esac

if [[ "$gate_val" == "both" ]]; then
  l2_lib="${HOOK_BASE_DIR}/lib/l2-detect.sh"
  if [ -f "$l2_lib" ]; then
    source "$l2_lib" 2>/dev/null || true
    if type l2_detect_missing >/dev/null 2>&1; then
      if l2_detect_missing "$phase" "$change_id" "$spec_dir" 2>/dev/null; then
        : # L2 已完成，继续 L3
      else
        l2_dispatch_prompt "$phase" "$change_id" "$spec_dir" 2>/dev/null || true
        module_output "warning" "IR" "L3 跳过（L2 not yet complete, gate_config=both）——等待主 agent 派 L2 子 agent"
        exit 0
      fi
    fi
  fi
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

# 读 gate_config 当前阶段值（用于 D1 L2-wait + D2 L3-only skipped）
	phase_name="${PHASE_GATE_KEY_MAP[$phase]:-}"
gate_val=$(jq -r --arg pn "$phase_name" \
  '.goal.gate_config[$pn] // ""' "$flow_file" 2>/dev/null || echo "")
# 值标准化映射（与 done-validation.sh 保持一致）
case "$gate_val" in
  independent|true) gate_val="both" ;;
  L2|L3|both) ;;  # 合法值保持
  *) gate_val="" ;;  # 未知值视为未开启
esac

l2_verdict="fail"  # 默认 fail（保守，both 模式 L2 未完成时）
if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
  l2v_extracted=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1) || true
  [ -n "$l2v_extracted" ] && l2_verdict="$l2v_extracted"
elif [[ "$gate_val" == "L3" ]]; then
  l2_verdict="skipped"  # L3-only: L2 是刻意不跑，非失败
fi

# ── D1: gate_config="both" 时 L2 未完成 → 跳过 L3，不写 .done ──
if [[ "$gate_val" == "both" ]] && { [ ! -f "$review_md" ] || ! grep -q "^## L2 盲审" "$review_md" 2>/dev/null; }; then
  module_output "warning" "IR" "L3 跳过（L2 not yet complete, gate_config=both）——等待主 agent 派 L2 子 agent"
  exit 0
fi

# ── 调用共享 lib l3-review.sh 执行 L3（P0-1/F1 修复）──
# l3-review.sh 已在积压扫描段 source，此处仅检查可用性
if [ -f "${HOOK_BASE_DIR}/lib/l3-review.sh" ]; then
  if type l3_review_run >/dev/null 2>&1; then
    l3_review_run "$phase" "$change_id" "$spec_dir" "$l2_verdict" "${gate_val:-both}" $L3_BG_FLAG && rc=0 || rc=$?
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
