#!/usr/bin/env bats
# test/l2-detect.bats — l2-detect.sh 单元测试

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"
  mkdir -p "$TEST_TMPDIR/.specs/test-change"
  source "${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks/stop/lib/l2-detect.sh" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "L2 missing: no review file → returns 1" {
  run l2_detect_missing 1 "test-change" "$TEST_TMPDIR/.specs/test-change"
  [ "$status" -eq 1 ]
}

@test "L2 complete: review file with L2 section → returns 0" {
  cat > "$TEST_TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-1.md" <<'EOF'
## L2 盲审
verdict: pass
EOF
  run l2_detect_missing 1 "test-change" "$TEST_TMPDIR/.specs/test-change"
  [ "$status" -eq 0 ]
}

@test "L2 dispatch prompt: generates valid output" {
  run l2_dispatch_prompt 6 "test-change" "$TEST_TMPDIR/.specs/test-change"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "L2 dispatch prompt: includes L2 warning" {
  run l2_dispatch_prompt 6 "test-change" "$TEST_TMPDIR/.specs/test-change"
  echo "$output" | grep -q "L2 盲审未完成"
}

@test "Invalid phase: returns 2" {
  run l2_detect_missing 8 "test-change" "$TEST_TMPDIR/.specs/test-change"
  [ "$status" -eq 2 ]
}
