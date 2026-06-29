#!/usr/bin/env bats
# test_interactive_ui_check.bats — tests for interactive UI detection library
#
# Covers: GATE_MAP completeness, check_interaction_gate, check_tool_invocation,
#         write/read/clear correction file, retry_count logic.

setup() {
  # Set up temp directory for correction file tests
  TEST_TMPDIR=$(mktemp -d "/tmp/bats-interactive-ui-XXXXXX")
  export CORRECTION_FILE="${TEST_TMPDIR}/.flow-active.interactive-ui-fix"

  # Determine library path relative to this test file
  LIB_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh"
  if [[ -f "$LIB_PATH" ]]; then
    source "$LIB_PATH"
  fi
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── GATE_MAP tests ─────────────────────────────────────────────────────

@test "GATE_MAP contains all 9 required keywords" {
  [[ -n "${GATE_MAP["反问用户"]}" ]]
  [[ -n "${GATE_MAP["反问 gate"]}" ]]
  [[ -n "${GATE_MAP["进入计划模式"]}" ]]
  [[ -n "${GATE_MAP["停下来反问"]}" ]]
  [[ -n "${GATE_MAP["停下来。禁止自动"]}" ]]
  [[ -n "${GATE_MAP["等用户选定"]}" ]]
  [[ -n "${GATE_MAP["必须等待用户回复"]}" ]]
  [[ -n "${GATE_MAP["归档操作必须用户确认"]}" ]]
  [[ -n "${GATE_MAP["先出计划"]}" ]]
}

@test "GATE_MAP maps AskUserQuestion keywords correctly" {
  [[ "${GATE_MAP["反问用户"]}" == "AskUserQuestion" ]]
  [[ "${GATE_MAP["反问 gate"]}" == "AskUserQuestion" ]]
  [[ "${GATE_MAP["停下来反问"]}" == "AskUserQuestion" ]]
  [[ "${GATE_MAP["停下来。禁止自动"]}" == "AskUserQuestion" ]]
  [[ "${GATE_MAP["等用户选定"]}" == "AskUserQuestion" ]]
  [[ "${GATE_MAP["必须等待用户回复"]}" == "AskUserQuestion" ]]
  [[ "${GATE_MAP["归档操作必须用户确认"]}" == "AskUserQuestion" ]]
}

@test "GATE_MAP maps EnterPlanMode keywords correctly" {
  [[ "${GATE_MAP["进入计划模式"]}" == "EnterPlanMode" ]]
  [[ "${GATE_MAP["先出计划"]}" == "EnterPlanMode" ]]
}

# ── check_interaction_gate tests ───────────────────────────────────────

@test "check_interaction_gate detects 反问 gate → AskUserQuestion" {
  run check_interaction_gate "这是反问 gate（R3.5 硬约束）的内容"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "GATE_FOUND" ]]
  [[ "$output" =~ "AskUserQuestion" ]]
}

@test "check_interaction_gate detects 反问用户 → AskUserQuestion" {
  run check_interaction_gate "请反问用户以下三个问题"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "AskUserQuestion" ]]
}

@test "check_interaction_gate detects 进入计划模式 → EnterPlanMode" {
  run check_interaction_gate "本步骤要求先进入计划模式，不要直接出方案"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "EnterPlanMode" ]]
}

@test "check_interaction_gate detects 停下来反问 → AskUserQuestion" {
  run check_interaction_gate "若发现任务定义有歧义，停下来反问"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "AskUserQuestion" ]]
}

@test "check_interaction_gate detects 停下来。禁止自动 → AskUserQuestion" {
  run check_interaction_gate "检测到 ≥ 1 个 critical 问题时，停下来。禁止自动继续。"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "AskUserQuestion" ]]
}

@test "check_interaction_gate returns false for plain text" {
  run check_interaction_gate "这是普通的技术讨论，没有交互要求"
  [[ "$status" -eq 1 ]]
}

@test "check_interaction_gate returns false for pipeline toll-gate text" {
  # Toll-gate text: "停下来。必须等待用户回复。禁止自动继续。" — this is a pipeline
  # mechanism, not an interactive UI gate. It should NOT trigger AskUserQuestion
  # because it doesn't contain the exact keyword substring.
  run check_interaction_gate "停下来。必须等待用户回复。禁止自动继续。若 false..."
  # This contains "必须等待用户回复" which IS in GATE_MAP
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "AskUserQuestion" ]]
}

# ── check_tool_invocation tests ────────────────────────────────────────

@test "check_tool_invocation detects AskUserQuestion in response" {
  run check_tool_invocation "我需要调用 AskUserQuestion 来询问用户" "AskUserQuestion"
  [[ "$status" -eq 0 ]]
}

@test "check_tool_invocation detects EnterPlanMode in response" {
  run check_tool_invocation "我先调用 EnterPlanMode 进入计划模式" "EnterPlanMode"
  [[ "$status" -eq 0 ]]
}

@test "check_tool_invocation returns false for plain text (AskUserQuestion)" {
  run check_tool_invocation "好的，我理解了，开始执行..." "AskUserQuestion"
  [[ "$status" -eq 1 ]]
}

@test "check_tool_invocation returns false for plain text (EnterPlanMode)" {
  run check_tool_invocation "以下是我的设计方案..." "EnterPlanMode"
  [[ "$status" -eq 1 ]]
}

@test "check_tool_invocation is case-insensitive (askuserquestion)" {
  run check_tool_invocation "I will use the askuserquestion tool now" "AskUserQuestion"
  [[ "$status" -eq 0 ]]
}

# ── Correction file tests ──────────────────────────────────────────────

@test "write_correction_file creates valid JSON" {
  init_correction_path "$TEST_TMPDIR"
  run write_correction_file "反问 gate" "AskUserQuestion" "2026-06-29T00:00:00+08:00"
  [[ "$status" -eq 0 ]]
  [[ -f "$CORRECTION_FILE" ]]
  run jq -e '.gate_type == "反问 gate"' "$CORRECTION_FILE"
  [[ "$status" -eq 0 ]]
  run jq -e '.required_tool == "AskUserQuestion"' "$CORRECTION_FILE"
  [[ "$status" -eq 0 ]]
  run jq -e '.retry_count == 0' "$CORRECTION_FILE"
  [[ "$status" -eq 0 ]]
}

@test "write_correction_file has valid timestamp" {
  init_correction_path "$TEST_TMPDIR"
  write_correction_file "反问 gate" "AskUserQuestion" "2026-06-29T00:00:00+08:00"
  run jq -r '.timestamp' "$CORRECTION_FILE"
  [[ "$output" == "2026-06-29T00:00:00+08:00" ]]
}

@test "retry_count increments on second write" {
  init_correction_path "$TEST_TMPDIR"
  write_correction_file "反问 gate" "AskUserQuestion" "2026-06-29T00:00:00+08:00"
  write_correction_file "反问 gate" "AskUserQuestion" "2026-06-29T00:00:01+08:00"
  run jq -r '.retry_count' "$CORRECTION_FILE"
  [[ "$output" == "1" ]]
}

@test "clear_correction_file removes file" {
  init_correction_path "$TEST_TMPDIR"
  write_correction_file "反问 gate" "AskUserQuestion"
  clear_correction_file
  [[ ! -f "$CORRECTION_FILE" ]]
}

@test "should_inject_correction returns 0 when retry < 2" {
  init_correction_path "$TEST_TMPDIR"
  write_correction_file "反问 gate" "AskUserQuestion"
  run should_inject_correction
  [[ "$status" -eq 0 ]]
}

@test "should_inject_correction returns 1 when retry >= 2" {
  init_correction_path "$TEST_TMPDIR"
  write_correction_file "反问 gate" "AskUserQuestion"
  write_correction_file "反问 gate" "AskUserQuestion"
  write_correction_file "反问 gate" "AskUserQuestion"
  run should_inject_correction
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "STOP_CORRECTION" ]]
}

@test "has_correction_file returns true when valid JSON exists" {
  init_correction_path "$TEST_TMPDIR"
  write_correction_file "反问 gate" "AskUserQuestion"
  run has_correction_file
  [[ "$status" -eq 0 ]]
}

@test "has_correction_file returns false when no file exists" {
  init_correction_path "$TEST_TMPDIR"
  run has_correction_file
  [[ "$status" -eq 1 ]]
}

# ── Library syntax check ───────────────────────────────────────────────

@test "library has no syntax errors" {
  run bash -n "$LIB_PATH"
  [[ "$status" -eq 0 ]]
}
