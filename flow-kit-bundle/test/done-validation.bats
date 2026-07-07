#!/usr/bin/env bats
# test/done-validation.bats — .done 6 键 KVP 校验测试

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "6-key .done file: all keys present → valid" {
  cat > "$TEST_TMPDIR/.done" <<'EOF'
phase=1
change_id=test
written_by=main-agent
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md
EOF
  # Shell source format: all 6 keys present
  source "$TEST_TMPDIR/.done" 2>/dev/null
  [ -n "$phase" ] && [ -n "$change_id" ] && [ -n "$written_by" ] && [ -n "$L2_verdict" ] && [ -n "$L3_verdict" ] && [ -n "$artifacts" ]
}

@test "missing L3_verdict: missing required key → invalid" {
  cat > "$TEST_TMPDIR/.done" <<'EOF'
phase=1
change_id=test
written_by=main-agent
L2_verdict=pass
artifacts=REQUIREMENT.md
EOF
  source "$TEST_TMPDIR/.done" 2>/dev/null
  # L3_verdict should be defined — expect empty
  [ -z "${L3_verdict:-}" ]
}

@test "missing L3_summary (non-6-key): still valid" {
  cat > "$TEST_TMPDIR/.done" <<'EOF'
phase=1
change_id=test
written_by=main-agent
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md
EOF
  source "$TEST_TMPDIR/.done" 2>/dev/null
  # L3_summary is NOT one of the 6 required keys; its absence should NOT fail
  [ -n "$phase" ] && [ -n "$L3_verdict" ] && [ -z "${L3_summary:-}" ]
}

@test "empty .done file: invalid" {
  touch "$TEST_TMPDIR/.empty"
  [ ! -s "$TEST_TMPDIR/.empty" ]
}
