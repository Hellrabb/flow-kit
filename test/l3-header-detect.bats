#!/usr/bin/env bats
# test/l3-header-detect.bats — L3 header 匹配测试

setup() {
  TEST_TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "new header ## L3 盲审 → matched" {
  echo "## L3 盲审（deepseek-v4-flash 外部模型 · 2026-07-07）" > "$TEST_TMPDIR/review.md"
  grep -q "## L3 盲审" "$TEST_TMPDIR/review.md"
}

@test "old header ## L3 外部模型审查 → matched (backward compat)" {
  echo "## L3 外部模型审查" > "$TEST_TMPDIR/review.md"
  grep -q "## L3 外部模型审查" "$TEST_TMPDIR/review.md"
}

@test "no L3 header → skip" {
  echo "## L2 盲审" > "$TEST_TMPDIR/review.md"
  ! grep -q "## L3 盲审" "$TEST_TMPDIR/review.md"
  ! grep -q "## L3 外部模型审查" "$TEST_TMPDIR/review.md"
}
