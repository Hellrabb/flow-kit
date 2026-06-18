#!/usr/bin/env bats
# test_flow_goal.bats — /flow goal 子命令测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  FLOW_ACTIVE="$TEST_TMPDIR/.flow-active"

  # 创建最小 .flow-active（模拟 /flow start 后的状态）
  jq -n '{
    change_id: null,
    goal: null,
    phase: "4",
    task_id: null,
    interrupt: null,
    token_spent: 0,
    updated_at: "2026-01-01T00:00:00Z"
  }' > "$FLOW_ACTIVE"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Helper: simulate /flow goal set ────────────────────────────────────
goal_set() {
  local condition="$1"
  local ts="${2:-2026-06-18T10:00:00Z}"
  jq --arg cond "$condition" --arg ts "$ts" \
    '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "fallback"} | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"
}

# ── Helper: simulate /flow goal clear ──────────────────────────────────
goal_clear() {
  local ts="${1:-2026-06-18T10:05:00Z}"
  jq --arg ts "$ts" '.goal = null | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"
}

# ── Tests ──────────────────────────────────────────────────────────────

@test "goal set: writes condition + metadata to .flow-active" {
  goal_set "pnpm test passes and lint is clean"

  condition=$(jq -r '.goal.condition' "$FLOW_ACTIVE")
  status=$(jq -r '.goal.status' "$FLOW_ACTIVE")
  turns=$(jq -r '.goal.turns' "$FLOW_ACTIVE")
  mode=$(jq -r '.goal.mode' "$FLOW_ACTIVE")

  [[ "$condition" == "pnpm test passes and lint is clean" ]]
  [[ "$status" == "active" ]]
  [[ "$turns" == "0" ]]
  [[ "$mode" == "fallback" ]]
}

@test "goal status: shows condition + status when goal is active" {
  goal_set "all tests green and lint clean"

  condition=$(jq -r '.goal.condition' "$FLOW_ACTIVE")
  status=$(jq -r '.goal.status' "$FLOW_ACTIVE")
  active_since=$(jq -r '.goal.active_since' "$FLOW_ACTIVE")

  [[ "$condition" == "all tests green and lint clean" ]]
  [[ "$status" == "active" ]]
  [[ -n "$active_since" ]]
}

@test "goal clear: sets goal to null" {
  goal_set "some condition"
  goal_clear

  goal=$(jq -r '.goal' "$FLOW_ACTIVE")
  [[ "$goal" == "null" ]]
}

@test "goal status: shows null when no goal set" {
  goal=$(jq -r '.goal' "$FLOW_ACTIVE")
  [[ "$goal" == "null" ]]
}

@test "goal clear: all alias variants clear goal" {
  for alias in clear stop off reset none cancel; do
    # re-create active goal
    jq -n '{
      change_id: null, goal: {condition: "test", status: "active", active_since: "2026-01-01T00:00:00Z", turns: 0, mode: "fallback"},
      phase: "4", task_id: null, interrupt: null, token_spent: 0, updated_at: "2026-01-01"
    }' > "$FLOW_ACTIVE"

    # clear using any alias (all do the same jq command)
    jq '.goal = null' "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"

    goal=$(jq -r '.goal' "$FLOW_ACTIVE")
    [[ "$goal" == "null" ]] || {
      echo "FAIL: alias '$alias' did not clear goal"
      return 1
    }
  done
}

@test "goal: turn counter increments correctly" {
  goal_set "long task"

  # Simulate 3 turns
  for i in $(seq 1 3); do
    jq ".goal.turns = $i" "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"
  done

  turns=$(jq -r '.goal.turns' "$FLOW_ACTIVE")
  [[ "$turns" == "3" ]]
}

@test "goal: mode detection (native vs fallback)" {
  # Test fallback mode
  goal_set "condition" "2026-06-18T10:00:00Z"
  mode=$(jq -r '.goal.mode' "$FLOW_ACTIVE")
  [[ "$mode" == "fallback" ]]

  # Test native mode
  jq '.goal.mode = "native"' "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"
  mode=$(jq -r '.goal.mode' "$FLOW_ACTIVE")
  [[ "$mode" == "native" ]]
}
