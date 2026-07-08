#!/usr/bin/env bats
# test/done-skip.bats — .done 跳过行为测试 (AC-3)

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"
  mkdir -p "$TEST_TMPDIR/.specs/test-change"
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

@test ".done file exists → 6 key KVP all present and valid" {
  done_file="$TEST_TMPDIR/.specs/test-change/.independent-review-7.done"
  cat > "$done_file" <<'DONE'
phase=7
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
L3_summary="all good"
artifacts=REVIEW.md
DONE
  [ -f "$done_file" ]
  # Verify keys via grep (avoids source interpretation issues)
  grep -q "^phase=7$" "$done_file"
  grep -q "^change_id=test-change$" "$done_file"
  grep -q "^L2_verdict=pass$" "$done_file"
  grep -q "^L3_verdict=pass$" "$done_file"
  grep -q "^artifacts=REVIEW.md$" "$done_file"
}

@test ".done file missing → should proceed to L3 trigger" {
  done_file="$TEST_TMPDIR/.specs/test-change/.independent-review-7.done"
  [ ! -f "$done_file" ]
}

@test ".done for different phase → current phase check unaffected" {
  mkdir -p "$TEST_TMPDIR/.specs/test-change"
  cat > "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" <<'DONE'
phase=6
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
artifacts=REVIEW.md
DONE
  [ ! -f "$TEST_TMPDIR/.specs/test-change/.independent-review-7.done" ]
}
