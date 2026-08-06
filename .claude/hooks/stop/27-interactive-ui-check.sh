#!/bin/bash
# Module I — Interactive UI Check
# Checks: I1 (detect skipped AskUserQuestion/EnterPlanMode gates)
#
# Runs at every Stop event. Greps the transcript for interaction gates
# in the prompt and tool calls in the response. If a gate was present
# but the model didn't invoke the required tool, writes a correction
# file for SessionStart to inject.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "27" || true
source "${HOOK_BASE_DIR}/lib/interactive-ui-check.sh"

module_enabled "interactive_ui_check" || exit 0

# ── Main check ─────────────────────────────────────────────────────────
check_i1() {
  # Gate this check behind the module — no per-check granularity for now
  # since interactive_ui_check has a single purpose

  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 0

  # Only check when flow-kit is active
  local change_id
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  [[ "$change_id" != "none" && "$change_id" != "?" ]] || return 0

  # Initialize correction file path
  init_correction_path "$PROJECT_ROOT"

  # Check if transcript is available
  if [[ -z "${TRANSCRIPT_PATH:-}" || ! -f "$TRANSCRIPT_PATH" ]]; then
    # Transcript not available — skip check gracefully
    return 0
  fi

  # ── Run detection ──────────────────────────────────────────────────
  local skip_result
  skip_result=$(detect_interaction_skip "$TRANSCRIPT_PATH" 2>&1) || true

  if echo "$skip_result" | grep -q "^SKIP_DETECTED"; then
    local gate_keyword tool_name
    gate_keyword=$(echo "$skip_result" | cut -d'|' -f2)
    tool_name=$(echo "$skip_result" | cut -d'|' -f3)

    # Check retry limit
    local inject_check
    inject_check=$(should_inject_correction 2>&1) || true

    if echo "$inject_check" | grep -q "^STOP_CORRECTION"; then
      # Exceeded retry limit — notify user, don't write another correction
      module_output "warning" "I1" "交互 gate 连续跳过 ≥3 次（gate=${gate_keyword} tool=${tool_name}）。已停止自动矫正，请人工介入检查弱模型是否不适合当前任务。"
      return 0
    fi

    # Write correction file
    if write_correction_file "$gate_keyword" "$tool_name" "$(date -Iseconds)" 2>/dev/null; then
      local retry
      retry=$(get_retry_count)
      module_output "warning" "I1" "检测到弱模型跳过交互 gate: ${gate_keyword} → 应调用 ${tool_name} 但未调用。已写入矫正文件（retry=${retry}），下次 SessionStart 将注入矫正指令。"
    else
      module_output "error" "I1" "矫正文件写入失败: ${CORRECTION_FILE}"
    fi
  else
    # No skip detected — ensure correction file is cleaned up
    # (Model may have corrected itself after a previous skip)
    if has_correction_file 2>/dev/null; then
      clear_correction_file
      module_output "info" "I1" "交互 gate 已恢复正常（模型正确调用了 ${skip_result##*|} 或 gate 不再适用）。已清除矫正文件。"
    fi
  fi
}

# ── Run check (wrap in subshell to protect hook chain) ────────────────
(
  check_i1
) || true

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "27" || true
