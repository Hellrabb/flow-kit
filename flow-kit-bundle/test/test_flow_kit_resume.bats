#!/usr/bin/env bats
# test_flow_kit_resume.bats — Integration tests for SessionStart flow-kit-resume.sh
# Tests real hook execution with mock stdin JSON.

setup() {
  TEST_TMP=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMP"
  export PROJECT_ROOT
  mkdir -p "${PROJECT_ROOT}/.specs"

  RESUME_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../flow-kit-bundle/hooks/session-start" && pwd)/flow-kit-resume.sh"
  [[ -f "$RESUME_SCRIPT" ]] || skip "flow-kit-resume.sh not found"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Helper: run the resume hook with a mock stdin JSON
run_resume_hook() {
  local stdin_json="$1"
  run bash "$RESUME_SCRIPT" <<< "$stdin_json"
}

@test "subagent SessionStart exits silently (parent_session_id present)" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test","phase":"4","goal":null,"task_id":null,"interrupt":null}
EOF
  local stdin='{"hook_event_name":"SessionStart","session_id":"s1","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":"parent-123"}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "no .flow-active produces no output" {
  local stdin='{"hook_event_name":"SessionStart","session_id":"s1","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Should exit cleanly with no banner (no .flow-active means nothing to resume)
  [[ ! "$output" =~ "flow-kit" ]]
}

@test ".flow-active with change_id + phase displays resume banner" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test-change","phase":"4","goal":null,"task_id":"T03","interrupt":null,"token_spent":0}
EOF
  local stdin='{"hook_event_name":"SessionStart","session_id":"s1","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Banner should mention the change_id and phase
  [[ "$output" =~ "test-change" ]]
  [[ "$output" =~ "4" ]]
}

@test ".flow-active with interrupt displays checkpoint context" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test-int","phase":"4","goal":null,"task_id":"T01","interrupt":{"active_file":"src/foo.sh","last_action":"fix type error","checkpoint_at":"2026-07-01T12:00:00+08:00"},"token_spent":12000}
EOF
  local stdin='{"hook_event_name":"SessionStart","session_id":"s2","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Should reference the interrupted file or action
  [[ "$output" =~ "src/foo.sh" ]] || [[ "$output" =~ "fix type error" ]] || [[ "$output" =~ "中断" ]]
}

@test "interactive-ui correction file triggers correction injection (retry_count=0)" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test-cor","phase":"4","goal":null,"task_id":null,"interrupt":null}
EOF
  cat > "${PROJECT_ROOT}/.flow-active.interactive-ui-fix" << 'EOF'
{"gate_type":"反问 gate","required_tool":"AskUserQuestion","retry_count":0,"timestamp":"2026-07-01T12:00:00Z"}
EOF
  local stdin='{"hook_event_name":"SessionStart","session_id":"s3","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Should contain correction banner
  [[ "$output" =~ "交互" ]] || [[ "$output" =~ "跳过" ]] || [[ "$output" =~ "correction" ]] || [[ "$output" =~ "AskUserQuestion" ]]
}

@test "correction file with retry_count >= 2 triggers stop-correction (human needed)" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test-stop","phase":"4","goal":null,"task_id":null,"interrupt":null}
EOF
  cat > "${PROJECT_ROOT}/.flow-active.interactive-ui-fix" << 'EOF'
{"gate_type":"反问 gate","required_tool":"AskUserQuestion","retry_count":3,"timestamp":"2026-07-01T12:00:00Z"}
EOF
  local stdin='{"hook_event_name":"SessionStart","session_id":"s4","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Should contain "stop" / "human" / "连续跳过" type message
  [[ "$output" =~ "人工" ]] || [[ "$output" =~ "连续跳过" ]]
  # Correction file should be deleted after stop
  [[ ! -f "${PROJECT_ROOT}/.flow-active.interactive-ui-fix" ]]
}

@test "pipeline goal .flow-active displays goal banner section" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"pipe-test","phase":"0","goal":{"condition":"all done","status":"active","scope":"pipeline","start_phase":"0","current_phase":"4","phases_done":["0","1","2","3"],"gates":{"0→1":"passed","1→2":"passed","2→3":"passed","3→4":"passed"},"turns":4,"mode":"native","active_since":"2026-07-01T12:00:00+08:00"},"task_id":"T04","interrupt":null}
EOF
  local stdin='{"hook_event_name":"SessionStart","session_id":"s5","cwd":"'"${PROJECT_ROOT}"'","parent_session_id":""}'
  run_resume_hook "$stdin"
  [[ "$status" -eq 0 ]]
  # Banner should mention the pipeline or goal
  [[ "$output" =~ "pipe-test" ]]
}
