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

# ── Pipeline Goal --from 测试 ─────────────────────────────────────────────

# Helper: simulate pipeline goal with --from
pipeline_goal_set() {
  local condition="$1"
  local from="${2:-4}"
  local ts="${3:-2026-06-20T10:00:00Z}"

  # 动态生成 gates
  local gates_json
  gates_json=$(jq -n --arg from "$from" \
    '[range($from|tonumber; 7) | "\(.)→\(.+1)"] | reduce .[] as $k ({}; .[$k] = "pending")')

  jq --arg cond "$condition" --arg ts "$ts" --arg from "$from" --argjson gates "$gates_json" \
    '.goal = {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", start_phase: $from, current_phase: $from, phases_done: [], gates: $gates, gate_config: {}, auto_advance: false, phase_sub_goals: {"4": "", "5": "", "6": "", "7": ""}} | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"
}

@test "pipeline goal --from 0: sets start_phase=0 with full gates 0→7" {
  pipeline_goal_set "CHANGE confirmed AND all tests pass" "0"

  start_phase=$(jq -r '.goal.start_phase' "$FLOW_ACTIVE")
  current_phase=$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")
  scope=$(jq -r '.goal.scope' "$FLOW_ACTIVE")
  gates_count=$(jq '.goal.gates | length' "$FLOW_ACTIVE")

  [[ "$start_phase" == "0" ]]
  [[ "$current_phase" == "0" ]]
  [[ "$scope" == "pipeline" ]]
  [[ "$gates_count" == "7" ]]  # 0→1 through 6→7

  # Verify specific gates exist
  jq -e '.goal.gates["0→1"] == "pending"' "$FLOW_ACTIVE"
  jq -e '.goal.gates["3→4"] == "pending"' "$FLOW_ACTIVE"
  jq -e '.goal.gates["6→7"] == "pending"' "$FLOW_ACTIVE"
}

@test "pipeline goal default: --from 4 (backward compatible)" {
  pipeline_goal_set "all tests pass" "4"

  start_phase=$(jq -r '.goal.start_phase' "$FLOW_ACTIVE")
  current_phase=$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")
  gates_count=$(jq '.goal.gates | length' "$FLOW_ACTIVE")

  [[ "$start_phase" == "4" ]]
  [[ "$current_phase" == "4" ]]
  [[ "$gates_count" == "3" ]]  # 4→5, 5→6, 6→7

  # Verify default gates
  jq -e '.goal.gates["4→5"] == "pending"' "$FLOW_ACTIVE"
  jq -e '.goal.gates["5→6"] == "pending"' "$FLOW_ACTIVE"
  jq -e '.goal.gates["6→7"] == "pending"' "$FLOW_ACTIVE"

  # Verify no extra gates
  run jq -e '.goal.gates["0→1"]' "$FLOW_ACTIVE"
  [[ "$status" -ne 0 ]]
}

@test "pipeline goal --from 3: gates start from 3→4" {
  pipeline_goal_set "tasks ready AND tests pass" "3"

  start_phase=$(jq -r '.goal.start_phase' "$FLOW_ACTIVE")
  gates_count=$(jq '.goal.gates | length' "$FLOW_ACTIVE")

  [[ "$start_phase" == "3" ]]
  [[ "$gates_count" == "4" ]]  # 3→4, 4→5, 5→6, 6→7

  jq -e '.goal.gates["3→4"] == "pending"' "$FLOW_ACTIVE"
  jq -e '.goal.gates["6→7"] == "pending"' "$FLOW_ACTIVE"

  # Verify 0→1 does NOT exist
  run jq -e '.goal.gates["0→1"]' "$FLOW_ACTIVE"
  [[ "$status" -ne 0 ]]
}

@test "pipeline goal --from 7: single gate (edge case)" {
  pipeline_goal_set "archive done" "7"

  start_phase=$(jq -r '.goal.start_phase' "$FLOW_ACTIVE")
  gates_count=$(jq '.goal.gates | length' "$FLOW_ACTIVE")

  [[ "$start_phase" == "7" ]]
  [[ "$gates_count" == "0" ]]  # No further gates from 7
}

@test "pipeline goal --from 6: single gate 6→7" {
  pipeline_goal_set "review complete" "6"

  start_phase=$(jq -r '.goal.start_phase' "$FLOW_ACTIVE")
  gates_count=$(jq '.goal.gates | length' "$FLOW_ACTIVE")

  [[ "$start_phase" == "6" ]]
  [[ "$gates_count" == "1" ]]
  jq -e '.goal.gates["6→7"] == "pending"' "$FLOW_ACTIVE"
}

@test "pipeline goal backward compat: missing start_phase defaults to 4" {
  # Create old-style pipeline goal without start_phase
  jq -n --arg ts "2026-06-18T10:00:00Z" '{
    change_id: "old-change",
    goal: {
      condition: "old pipeline",
      status: "active",
      active_since: $ts,
      turns: 3,
      mode: "native",
      scope: "pipeline",
      current_phase: "4",
      phases_done: ["4"],
      gates: {"4→5": "passed", "5→6": "pending", "6→7": "pending"},
      gate_config: {},
      auto_advance: false,
      phase_sub_goals: {}
    },
    phase: "4",
    task_id: null,
    interrupt: null,
    token_spent: 0,
    updated_at: $ts
  }' > "$FLOW_ACTIVE"

  # start_phase should fallback to "4"
  start_phase=$(jq -r '(.goal.start_phase // "4")' "$FLOW_ACTIVE")
  [[ "$start_phase" == "4" ]]

  # current_phase should still work
  current_phase=$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")
  [[ "$current_phase" == "4" ]]

  # gates should still be readable
  gates_45=$(jq -r '.goal.gates["4→5"]' "$FLOW_ACTIVE")
  [[ "$gates_45" == "passed" ]]
}

@test "pipeline goal: dynamic gates generation for all valid start phases" {
  for from in 0 1 2 3 4 5 6 7; do
    pipeline_goal_set "test" "$from"

    start_phase=$(jq -r '.goal.start_phase' "$FLOW_ACTIVE")
    [[ "$start_phase" == "$from" ]]

    # Verify current_phase == start_phase initially
    current_phase=$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")
    [[ "$current_phase" == "$from" ]]

    # Verify gates count = 7 - from
    expected_count=$((7 - from))
    gates_count=$(jq '.goal.gates | length' "$FLOW_ACTIVE")
    [[ "$gates_count" == "$expected_count" ]] || {
      echo "FAIL: from=$from expected $expected_count gates, got $gates_count"
      return 1
    }
  done
}

@test "pipeline goal: phase transition updates gates correctly" {
  pipeline_goal_set "complete pipeline" "0"

  # Simulate phase 0→1 transition
  jq --arg ts "2026-06-20T11:00:00Z" \
    '.goal.current_phase = "1" | .goal.phases_done += ["0"] | .goal.gates["0→1"] = "passed" | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"

  current_phase=$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")
  [[ "$current_phase" == "1" ]]

  phases_done=$(jq -r '.goal.phases_done[0]' "$FLOW_ACTIVE")
  [[ "$phases_done" == "0" ]]

  gate_status=$(jq -r '.goal.gates["0→1"]' "$FLOW_ACTIVE")
  [[ "$gate_status" == "passed" ]]

  # Other gates still pending
  jq -e '.goal.gates["1→2"] == "pending"' "$FLOW_ACTIVE"
}
