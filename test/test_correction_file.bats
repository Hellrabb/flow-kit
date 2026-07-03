#!/usr/bin/env bats
# test_correction_file.bats — Unit tests for lib/correction-file.sh

setup() {
  TEST_TMP=$(mktemp -d)
  CORRECTION_FILE="${TEST_TMP}/test-correction.json"
  # Source the lib
  HOOK_BASE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../flow-kit-bundle/hooks/stop" && pwd)"
  source "${HOOK_BASE_DIR}/lib/correction-file.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "correction_file_exists returns 1 for missing file" {
  run correction_file_exists "${TEST_TMP}/nonexistent.json"
  [[ "$status" -eq 1 ]]
}

@test "correction_file_exists returns 0 for valid JSON file" {
  echo '{"key":"val"}' > "$CORRECTION_FILE"
  run correction_file_exists "$CORRECTION_FILE"
  [[ "$status" -eq 0 ]]
}

@test "correction_file_exists returns 1 for invalid JSON" {
  echo 'not json' > "$CORRECTION_FILE"
  # jq empty on invalid JSON exits non-zero
  run jq empty "$CORRECTION_FILE"
  [[ "$status" -ne 0 ]]
  # Our function should also return non-zero
  run correction_file_exists "$CORRECTION_FILE"
  [[ "$status" -ne 0 ]]
}

@test "correction_file_read returns {} for missing file" {
  run correction_file_read "${TEST_TMP}/nonexistent.json"
  [[ "$output" == "{}" ]]
}

@test "correction_file_read returns file content for existing file" {
  echo '{"a":1}' > "$CORRECTION_FILE"
  run correction_file_read "$CORRECTION_FILE"
  [[ "$output" == '{"a":1}' ]]
}

@test "correction_file_write with overwrite strategy writes file" {
  local data='{"gate_type":"test","required_tool":"AskUserQuestion"}'
  run correction_file_write "$CORRECTION_FILE" "$data" "overwrite"
  [[ "$status" -eq 0 ]]
  [[ -f "$CORRECTION_FILE" ]]
}

@test "correction_file_write overwrite replaces previous content" {
  echo '{"old":"data"}' > "$CORRECTION_FILE"
  local data='{"new":"data"}'
  correction_file_write "$CORRECTION_FILE" "$data" "overwrite"
  # Compare JSON values, not string formatting
  run jq -r '.new' "$CORRECTION_FILE"
  [[ "$output" == "data" ]]
  run jq -r '.old' "$CORRECTION_FILE"
  [[ "$output" == "null" ]]
}

@test "correction_file_write with merge strategy deduplicates by fields" {
  local data1='[{"rule":"R1","location":"a.txt","fix":"x"}]'
  local data2='[{"rule":"R1","location":"a.txt","fix":"y"}]' # same rule+location
  correction_file_write "$CORRECTION_FILE" "$data1" "rule,location"
  correction_file_write "$CORRECTION_FILE" "$data2" "rule,location"
  # Should have only 1 entry (dedup by rule+location)
  run jq 'length' "$CORRECTION_FILE"
  [[ "$output" == "1" ]]
}

@test "correction_file_clear removes file" {
  echo '{"x":1}' > "$CORRECTION_FILE"
  correction_file_clear "$CORRECTION_FILE"
  [[ ! -f "$CORRECTION_FILE" ]]
}

@test "round-trip: write → read → clear → exists" {
  local data='{"test":"roundtrip"}'
  correction_file_write "$CORRECTION_FILE" "$data" "overwrite"
  run jq -r '.test' "$CORRECTION_FILE"
  [[ "$output" == "roundtrip" ]]
  run correction_file_exists "$CORRECTION_FILE"
  [[ "$status" -eq 0 ]]
  correction_file_clear "$CORRECTION_FILE"
  run correction_file_exists "$CORRECTION_FILE"
  [[ "$status" -eq 1 ]]
}
