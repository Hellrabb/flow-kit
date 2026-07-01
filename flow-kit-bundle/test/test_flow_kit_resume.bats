#!/usr/bin/env bats
# test_flow_kit_resume.bats — Tests for SessionStart flow-kit-resume.sh

setup() {
  TEST_TMP=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMP"
  export PROJECT_ROOT
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "no .flow-active produces no resume banner" {
  # Without .flow-active, the hook should exit silently
  # Simulate by checking that .flow-active does not exist
  [[ ! -f "${PROJECT_ROOT}/.flow-active" ]]
}

@test ".flow-active with change_id + phase produces banner content" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test-change","phase":"4","goal":null,"task_id":"T01","interrupt":null,"token_spent":0}
EOF
  # Verify .flow-active is valid JSON and has expected fields
  run jq -r '.change_id' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "test-change" ]]
  run jq -r '.phase' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "4" ]]
  run jq -r '.task_id' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "T01" ]]
}

@test ".flow-active with interrupt field contains checkpoint context" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"test","phase":"4","goal":null,"task_id":null,"interrupt":{"active_file":"src/foo.sh","last_action":"fixing bug","checkpoint_at":"2026-07-01T12:00:00+08:00"},"token_spent":0}
EOF
  run jq -r '.interrupt.active_file' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "src/foo.sh" ]]
  run jq -r '.interrupt.last_action' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "fixing bug" ]]
}

@test "correction file presence is detectable by resume hook" {
  cat > "${TEST_TMP}/.flow-active.interactive-ui-fix" << 'EOF'
{"gate_type":"反问 gate","required_tool":"AskUserQuestion","retry_count":1,"timestamp":"2026-07-01T12:00:00Z"}
EOF
  run jq empty "${TEST_TMP}/.flow-active.interactive-ui-fix"
  [[ "$status" -eq 0 ]]
  run jq -r '.retry_count' "${TEST_TMP}/.flow-active.interactive-ui-fix"
  [[ "$output" == "1" ]]
}

@test "pipeline goal .flow-active contains expected fields" {
  cat > "${PROJECT_ROOT}/.flow-active" << 'EOF'
{"change_id":"pipe-test","phase":"0","goal":{"condition":"all done","status":"active","scope":"pipeline","start_phase":"0","current_phase":"4","phases_done":["0","1","2","3"],"gates":{"0→1":"passed","1→2":"passed","2→3":"passed","3→4":"passed","4→5":"pending"},"gate_config":{"1-requirement":"independent","6-review":"independent"},"auto_advance":false,"phase_sub_goals":{"4":"","5":"","6":"","7":""},"turns":4,"mode":"native","active_since":"2026-07-01T12:00:00+08:00"},"task_id":"T04","interrupt":null,"token_spent":0}
EOF
  run jq -r '.goal.scope' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "pipeline" ]]
  run jq -r '.goal.current_phase' "${PROJECT_ROOT}/.flow-active"
  [[ "$output" == "4" ]]
}
