#!/usr/bin/env bats
# test/phase-resolution.bats — fk_resolve_phase() 单元测试

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"
  cp "${BATS_TEST_DIRNAME}/../.flow-active" "$TEST_TMPDIR/.flow-active" 2>/dev/null || true
  # 位置无关：向上查找 flow-kit-bundle 根（双源 test/ 与 flow-kit-bundle/test/ 同源 · L-025）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  source "$d/flow-kit-bundle/hooks/stop/lib/common.sh" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "pipeline mode: returns current_phase when valid (phase 4)" {
  cat > "$TEST_TMPDIR/.flow-active" <<'EOF'
{"goal":{"scope":"pipeline","current_phase":"4"},"phase":"0"}
EOF
  run fk_resolve_phase
  [ "$output" = "4" ]
}

@test "pipeline mode: returns current_phase when valid (phase 5)" {
  cat > "$TEST_TMPDIR/.flow-active" <<'EOF'
{"goal":{"scope":"pipeline","current_phase":"5"},"phase":"0"}
EOF
  run fk_resolve_phase
  [ "$output" = "5" ]
}

@test "single-phase mode: returns .phase" {
  cat > "$TEST_TMPDIR/.flow-active" <<'EOF'
{"goal":{"scope":""},"phase":"1"}
EOF
  run fk_resolve_phase
  [ "$output" = "1" ]
}

@test "pipeline mode: stale .phase=6 does NOT override current_phase=5" {
  cat > "$TEST_TMPDIR/.flow-active" <<'EOF'
{"goal":{"scope":"pipeline","current_phase":"5"},"phase":"6"}
EOF
  run fk_resolve_phase
  [ "$output" = "5" ]
}
