#!/usr/bin/env bats
# test_flow_artifacts.bats — flow-kit-artifacts.sh 核心函数测试
# 覆盖 TD-002：hooks 系统从 0 测试覆盖到 smoke test 基线
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  ARTIFACTS_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh"

  # fk_flow_field / fk_validate_flow 依赖 PROJECT_ROOT
  export PROJECT_ROOT="$TEST_TMPDIR"

  # artifacts.sh 是库（无 set -euo pipefail），可安全 source
  # shellcheck disable=SC1090
  source "$ARTIFACTS_SH" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

skip_if_no_jq() {
  if ! command -v jq &>/dev/null; then
    skip "jq 未安装，无法运行 artifacts 测试"
  fi
}

# ── fk_flow_field ───────────────────────────────────────────────────────

@test "fk_flow_field: returns existing top-level field value" {
  skip_if_no_jq
  jq -n '{change_id: "test-change", phase: "2"}' > "$PROJECT_ROOT/.flow-active"

  result=$(fk_flow_field "change_id")
  [[ "$result" == "test-change" ]]
}

@test "fk_flow_field: returns nested field value via jq path" {
  skip_if_no_jq
  jq -n '{goal: {status: "active", turns: 3}}' > "$PROJECT_ROOT/.flow-active"

  result=$(fk_flow_field "goal.status")
  [[ "$result" == "active" ]]
}

@test "fk_flow_field: returns default when field missing" {
  skip_if_no_jq
  jq -n '{change_id: "x"}' > "$PROJECT_ROOT/.flow-active"

  result=$(fk_flow_field "goal.status" "inactive")
  [[ "$result" == "inactive" ]]
}

@test "fk_flow_field: returns default when .flow-active file absent" {
  skip_if_no_jq
  # 不创建 .flow-active
  result=$(fk_flow_field "change_id" "fallback")
  [[ "$result" == "fallback" ]]
}

@test "fk_flow_field: returns default on invalid JSON" {
  skip_if_no_jq
  echo "not valid json {{{" > "$PROJECT_ROOT/.flow-active"

  result=$(fk_flow_field "change_id" "safe-default")
  [[ "$result" == "safe-default" ]]
}

# ── fk_file_nonempty ────────────────────────────────────────────────────

@test "fk_file_nonempty: returns 0 (true) for file with > MIN_MEANINGFUL_LINES" {
  # 10 行 > MIN_MEANINGFUL_LINES(3)
  printf 'line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10\n' \
    > "$TEST_TMPDIR/big.md"
  fk_file_nonempty "$TEST_TMPDIR/big.md"
}

@test "fk_file_nonempty: returns 1 (false) for file with <= MIN_MEANINGFUL_LINES" {
  # 1 行 ≤ 3
  printf 'only title\n' > "$TEST_TMPDIR/small.md"
  ! fk_file_nonempty "$TEST_TMPDIR/small.md"
}

@test "fk_file_nonempty: returns 1 (false) for exactly threshold (3 lines)" {
  # 恰好 3 行 = MIN_MEANINGFUL_LINES，不满足 > 3
  printf 'a\nb\nc\n' > "$TEST_TMPDIR/threshold.md"
  ! fk_file_nonempty "$TEST_TMPDIR/threshold.md"
}

@test "fk_file_nonempty: returns 1 (false) for missing file" {
  ! fk_file_nonempty "$TEST_TMPDIR/nonexistent.md"
}

# ── fk_validate_flow ────────────────────────────────────────────────────

@test "fk_validate_flow: returns 0 for valid JSON .flow-active" {
  skip_if_no_jq
  jq -n '{change_id: "x", phase: "4"}' > "$PROJECT_ROOT/.flow-active"
  fk_validate_flow
}

@test "fk_validate_flow: returns 1 for missing .flow-active" {
  # 不创建文件
  ! fk_validate_flow
}

@test "fk_validate_flow: returns 1 for invalid JSON .flow-active" {
  skip_if_no_jq
  echo "{{{ broken json" > "$PROJECT_ROOT/.flow-active"
  ! fk_validate_flow
}
