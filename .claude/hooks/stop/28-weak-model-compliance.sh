#!/bin/bash
# Module 28 — Weak Model Compliance Check
# Checks: W1 (L1 rule compliance), W2 (L2 self-check), W3 (L3 evidence chain)
#
# Runs at every Stop event. Scans the transcript for weak model
# compliance violations across three layers and writes a unified
# correction file (.flow-active.correction) for SessionStart to inject.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"
source "${HOOK_BASE_DIR}/lib/weak-model-compliance.sh"

module_enabled "weak_model_compliance" || exit 0

# ── Main check ─────────────────────────────────────────────────────────
check_compliance() {
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 0

  # Only check when flow-kit is active
  local change_id
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  [[ "$change_id" != "none" && "$change_id" != "?" ]] || return 0

  # Initialize correction file path
  init_compliance_correction_path "$PROJECT_ROOT"

  # Check if transcript is available
  if [[ -z "${TRANSCRIPT_PATH:-}" || ! -f "$TRANSCRIPT_PATH" ]]; then
    return 0
  fi

  # Ensure transcript-parser has run (produces intermediate files in HOOK_TMP_DIR)
  # transcript-parser.sh is sourced by earlier modules (01-transcript-parse.sh);
  # if it hasn't run, we skip gracefully.
  if [[ ! -f "${HOOK_TMP_DIR}/messages.txt" ]]; then
    return 0
  fi

  local context_file="${PROJECT_ROOT}/.specs/CONTEXT.md"
  local total_violations=0

  # ── L1: Rule compliance ────────────────────────────────────────────
  local l1_json
  l1_json=$(scan_l1_rules "$HOOK_TMP_DIR" "$context_file" 2>/dev/null) || true
  local l1_count
  l1_count=$(echo "$l1_json" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$l1_count" -gt 0 ]]; then
    write_compliance_correction "L1" "$l1_json" "$(date -Iseconds)" 2>/dev/null || true
    total_violations=$((total_violations + l1_count))
    module_output "warning" "W1" "L1 规则合规检测到 ${l1_count} 项违规（禁动文件触碰/通用规则违反）"
  fi

  # ── L2: Self-check completeness ─────────────────────────────────────
  local l2_json
  l2_json=$(scan_l2_selfcheck "$HOOK_TMP_DIR" 2>/dev/null) || true
  local l2_count
  l2_count=$(echo "$l2_json" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$l2_count" -gt 0 ]]; then
    write_compliance_correction "L2" "$l2_json" "$(date -Iseconds)" 2>/dev/null || true
    total_violations=$((total_violations + l2_count))
    module_output "warning" "W2" "L2 自检完整性检测到 ${l2_count} 项违规（自检表未填/跳过）"
  fi

  # ── L3: Evidence chain ──────────────────────────────────────────────
  local l3_json
  l3_json=$(scan_l3_evidence "$HOOK_TMP_DIR" 2>/dev/null) || true
  local l3_count
  l3_count=$(echo "$l3_json" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$l3_count" -gt 0 ]]; then
    write_compliance_correction "L3" "$l3_json" "$(date -Iseconds)" 2>/dev/null || true
    total_violations=$((total_violations + l3_count))
    module_output "warning" "W3" "L3 证据链检测到 ${l3_count} 项违规（引用路径未经验证）"
  fi

  # ── No violations → clear stale correction file ─────────────────────
  if [[ "$total_violations" -eq 0 ]]; then
    if has_compliance_correction 2>/dev/null; then
      clear_compliance_correction
      module_output "info" "W0" "合规检测通过（0 违规），已清除矫正文件"
    fi
  else
    module_output "info" "W0" "合规检测完成：共 ${total_violations} 项违规 → .flow-active.correction"
  fi
}

# ── Run check (wrap in subshell to protect hook chain) ────────────────
(
  check_compliance
) || true
