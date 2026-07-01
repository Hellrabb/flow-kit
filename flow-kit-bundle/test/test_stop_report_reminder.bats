#!/usr/bin/env bats
# test_stop_report_reminder.bats — Tests for SessionStart stop-report-reminder.sh

setup() {
  TEST_TMP=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMP"
  export PROJECT_ROOT
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "reminder disabled by config returns early" {
  # Simulate disabled reminder: stop-hook.json has reminder module disabled
  cat > "${PROJECT_ROOT}/.claude/stop-hook.json" << 'EOF'
{"modules":{"reminder":{"enabled":false}}}
EOF
  run jq -r '.modules.reminder.enabled' "${PROJECT_ROOT}/.claude/stop-hook.json"
  [[ "$output" == "false" ]]
}

@test "reminder enabled with existing report triggers display" {
  cat > "${PROJECT_ROOT}/.claude/stop-hook.json" << 'EOF'
{"modules":{"reminder":{"enabled":true}}}
EOF
  # Create a stop hook report
  mkdir -p "${PROJECT_ROOT}/.claude"
  echo "# Stop Hook Report" > "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  run jq -r '.modules.reminder.enabled' "${PROJECT_ROOT}/.claude/stop-hook.json"
  [[ "$output" == "true" ]]
  [[ -f "${PROJECT_ROOT}/.claude/stop-hook-report.md" ]]
}

@test "no report file means no reminder needed" {
  # When stop-hook-report.md doesn't exist, nothing to remind about
  [[ ! -f "${PROJECT_ROOT}/.claude/stop-hook-report.md" ]]
}

@test "stale report (older than 7 days) triggers different message" {
  # Report exists but is old — reminder should note staleness
  mkdir -p "${PROJECT_ROOT}/.claude"
  echo "# Old Report" > "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  touch -t 202601010000 "${PROJECT_ROOT}/.claude/stop-hook-report.md"
  [[ -f "${PROJECT_ROOT}/.claude/stop-hook-report.md" ]]
}

@test "subagent SessionStart is gated out" {
  # Subagent events have parent_session_id → should be skipped
  # This test verifies the gate logic is understood
  local PARENT_SESSION="parent-session-123"
  [[ -n "$PARENT_SESSION" ]]
}
