#!/bin/bash
# check.sh — regression demo for weak-model-interactive-ui
# Verifies the interactive UI detection library correctly identifies
# skipped AskUserQuestion / EnterPlanMode gates.
#
# Usage: bash check.sh
# Output: TAP-compatible format

# Use set -uo pipefail but NOT -e — the library functions use grep -qF in
# for-loops, which interacts badly with errexit when sourced.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_PATH="${SCRIPT_DIR}/../../../hooks/stop/lib/interactive-ui-check.sh"
PASS=0
FAIL=0
TOTAL=0

# ── Source library at TOP LEVEL (not inside a function) ────────────────
# CRITICAL: bash 5.x treats `declare` inside a sourced-called-from-function
# as LOCAL scope. GATE_MAP must be global for check_interaction_gate to work.
if [[ ! -f "$LIB_PATH" ]]; then
  echo "Bail out! Library not found: $LIB_PATH"
  exit 1
fi
source "$LIB_PATH"

# ── Helpers ───────────────────────────────────────────────────────────
tap_ok() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); echo "ok ${TOTAL} - $1"; }
tap_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); echo "not ok ${TOTAL} - $1"; }
tap_plan() { echo "1..$1"; }

# ── Setup ─────────────────────────────────────────────────────────────
setup() {
  TMPDIR=$(mktemp -d "/tmp/interactive-ui-check-demo-XXXXXX")
  CORRECTION_FILE="${TMPDIR}/.flow-active.interactive-ui-fix"
  export CORRECTION_FILE
}

teardown() {
  rm -rf "$TMPDIR"
}

# ── Estimate test count ───────────────────────────────────────────────
# We'll count after running, so plan ahead
tap_plan 8

setup

# ── Test 1: check_interaction_gate detects "反问 gate" ─────────────────
# NOTE: avoid $(...) subshell because bash doesn't export associative arrays
if check_interaction_gate "这是反问 gate（R3.5 硬约束）的内容" >/dev/null 2>&1; then
  tap_ok "check_interaction_gate detects 反问 gate → AskUserQuestion"
else
  tap_fail "check_interaction_gate detects 反问 gate → AskUserQuestion"
fi

# ── Test 2: check_interaction_gate detects "进入计划模式" ──────────────
if check_interaction_gate "本步骤要求先进入计划模式" >/dev/null 2>&1; then
  tap_ok "check_interaction_gate detects 进入计划模式 → EnterPlanMode"
else
  tap_fail "check_interaction_gate detects 进入计划模式 → EnterPlanMode"
fi

# ── Test 3: check_interaction_gate returns 1 for no-gate text ─────────
if ! check_interaction_gate "这是普通的技术讨论，没有交互 gate" 2>/dev/null; then
  tap_ok "check_interaction_gate returns false for no-gate text"
else
  tap_fail "check_interaction_gate returns false for no-gate text"
fi

# ── Test 4: check_tool_invocation detects AskUserQuestion ──────────────
if check_tool_invocation "我来调用 AskUserQuestion 工具询问用户的选择。AskUserQuestion({ questions: [...] })" "AskUserQuestion" 2>/dev/null; then
  tap_ok "check_tool_invocation detects AskUserQuestion in response"
else
  tap_fail "check_tool_invocation detects AskUserQuestion in response"
fi

# ── Test 5: check_tool_invocation returns false for plain text ────────
if ! check_tool_invocation "好的，我理解了。让我直接开始..." "AskUserQuestion" 2>/dev/null; then
  tap_ok "check_tool_invocation returns false for plain text (no AskUserQuestion)"
else
  tap_fail "check_tool_invocation returns false for plain text (no AskUserQuestion)"
fi

# ── Test 6: write_correction_file creates valid JSON ──────────────────
init_correction_path "$TMPDIR"
write_correction_file "反问 gate" "AskUserQuestion" "2026-06-29T00:00:00+08:00" 2>/dev/null
if [[ -f "$CORRECTION_FILE" ]]; then
  if jq -e '.gate_type == "反问 gate" and .required_tool == "AskUserQuestion" and .retry_count == 0' "$CORRECTION_FILE" >/dev/null 2>&1; then
    tap_ok "write_correction_file creates valid JSON with correct fields"
  else
    tap_fail "write_correction_file creates valid JSON with correct fields"
  fi
else
  tap_fail "write_correction_file creates file"
fi

# ── Test 7: retry_count increments on second write ────────────────────
write_correction_file "反问 gate" "AskUserQuestion" "2026-06-29T00:00:01+08:00" 2>/dev/null
RETRY=$(jq -r '.retry_count' "$CORRECTION_FILE" 2>/dev/null)
if [[ "$RETRY" == "1" ]]; then
  tap_ok "retry_count increments from 0 to 1 on second write"
else
  tap_fail "retry_count increments from 0 to 1 on second write (got: $RETRY)"
fi

# ── Test 8: clear_correction_file removes file ────────────────────────
clear_correction_file 2>/dev/null
if [[ ! -f "$CORRECTION_FILE" ]]; then
  tap_ok "clear_correction_file removes the correction file"
else
  tap_fail "clear_correction_file removes the correction file"
fi

teardown

# ── Summary ───────────────────────────────────────────────────────────
echo ""
echo "# pass: $PASS"
echo "# fail: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
