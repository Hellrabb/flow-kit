#!/usr/bin/env bats
# test/l3-truncation.bats — L3 智能截断算法测试

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"
  source "${BATS_TEST_DIRNAME}/../hooks/stop/lib/l3-review.sh" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

make_big_text() {
  local n="${1:-50}"
  local result=""
  for i in $(seq 1 "$n"); do
    printf -v section '## Section %d\nSome filler content for testing truncation scenarios.\n**Given** precondition_%d\n**When** action_%d\n**Then** result_%d\nMore filler text here padding the content.\n\n' "$i" "$i" "$i" "$i"
    result+="$section"
  done
  echo "$result"
}

@test "small input: no truncation needed" {
  result=$(smart_truncate "## Test\n\n**Given** small\n**When** run\n**Then** pass" 500)
  echo "$result" | grep -q "未超限"
}

@test "large input: truncation applied" {
  big=$(make_big_text 80)
  result=$(smart_truncate "$big" 3000)
  echo "$result" | grep -q "截断"
}

@test "all headers preserved after truncation" {
  big=$(make_big_text 80)
  result=$(smart_truncate "$big" 5000)
  # First 10 headers should all appear (they fit in 5000 chars)
  for i in $(seq 1 10); do
    echo "$result" | grep -q "## Section $i"
  done
}

@test "Given/When/Then lines preserved in output" {
  big=$(make_big_text 70)
  result=$(smart_truncate "$big" 5000)
  echo "$result" | grep -q "precondition_1"
  echo "$result" | grep -q "action_1"
  echo "$result" | grep -q "result_1"
}

@test "truncation meta includes sizes" {
  big=$(make_big_text 80)
  result=$(smart_truncate "$big" 3000)
  echo "$result" | grep -q "原始:"
  echo "$result" | grep -q "截断后:"
}

@test "30KB fixture test: 3 defects present in fixture" {
  fixture="${BATS_TEST_DIRNAME}/fixtures/l3-truncation-30k.md"
  [ -f "$fixture" ] || skip "Fixture not found"
  grep -q "DEFECT-1" "$fixture"
  grep -q "DEFECT-2" "$fixture"
  grep -q "DEFECT-3" "$fixture"
}
