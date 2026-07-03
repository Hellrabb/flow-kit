#!/usr/bin/env bats
# test_stop_report_reminder.bats — Integration tests for SessionStart stop-report-reminder.sh
# Tests real hook execution with mock stdin JSON and file fixtures.

setup() {
  TEST_TMP=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMP"
  export PROJECT_ROOT
  mkdir -p "${PROJECT_ROOT}/.claude"

  REMINDER_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../hooks/session-start" && pwd)/stop-report-reminder.sh"
  [[ -f "$REMINDER_SCRIPT" ]] || skip "stop-report-reminder.sh not found"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Helper: run the reminder hook with mock stdin JSON
run_reminder_hook() {
  local stdin_json="$1"
  run bash "$REMINDER_SCRIPT" <<< "$stdin_json"
}

setup_minimal_config() {
  # Create stop-hook.json for config_get to work
  cat > "${PROJECT_ROOT}/.claude/stop-hook.json" << 'EOF'
{
  "session_start": {
    "remind_unreviewed": true
  },
  "output": {
    "report_file": ".claude/stop-hook-report.md",
    "suggestions_file": ".claude/stop-hook-suggestions.md"
  },
  "thresholds": {
    "report_max_age_days": 3
  }
}
EOF
  # Create state file for reminder count tracking
  cat > "${PROJECT_ROOT}/.claude/stop-hook-state.json" << 'EOF'
{}
EOF
}

@test "subagent SessionStart exits silently (parent_session_id present)" {
  setup_minimal_config
  echo "# Report" > "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  local stdin='{"hook_event_name":"SessionStart","session_id":"s1","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":"parent-123"}'
  run_reminder_hook "$stdin"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "no report file produces no output" {
  setup_minimal_config
  local stdin='{"hook_event_name":"SessionStart","session_id":"s2","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_reminder_hook "$stdin"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "fresh report file triggers reminder banner" {
  setup_minimal_config
  echo "# Stop Hook Report - Findings" > "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  local stdin='{"hook_event_name":"SessionStart","session_id":"s3","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_reminder_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Should contain reminder banner about report
  [[ "$output" =~ "Report" ]] || [[ "$output" =~ "报告" ]] || [[ "$output" =~ "待 Review" ]]
}

@test "reminder disabled by config produces no output" {
  # jq // operator treats boolean false as falsy → returns default.
  # Use the string "false" to actually disable: config_get returns "false", [[ "false" == "true" ]] → exit 0
  cat > "${PROJECT_ROOT}/.claude/stop-hook.json" << 'EOF'
{"session_start":{"remind_unreviewed":"false"}}
EOF
  echo "# Report" > "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  local stdin='{"hook_event_name":"SessionStart","session_id":"s4","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_reminder_hook "$stdin"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "reminder with suggestions file also triggers banner" {
  setup_minimal_config
  # Both report AND suggestions needed — hook only displays banner when report exists
  echo "# Report" > "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  echo "# Suggestions" > "${PROJECT_ROOT}/.claude/stop-hook-suggestions.md"
  local stdin='{"hook_event_name":"SessionStart","session_id":"s5","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_reminder_hook "$stdin"
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}
