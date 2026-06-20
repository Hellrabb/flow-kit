#!/usr/bin/env bats
# test_pipeline_rollback.bats — pipeline 回退协议测试（方案 C 智能回退）
# 覆盖：动态回退目标列表生成 + 通用回退 jq（$TARGET 参数化）+ 向后兼容
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  FLOW_ACTIVE="$TEST_TMPDIR/.flow-active"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

skip_if_no_jq() {
  if ! command -v jq &>/dev/null; then
    skip "jq 未安装，无法运行 rollback 测试"
  fi
}

# Helper: create a pipeline goal fixture with given start_phase + phases_done
make_goal() {
  local start="$1"
  local phases_done_json="$2"  # e.g. '["4","5"]'
  local current="$3"
  local ts="${4:-2026-06-20T10:00:00Z}"

  # Dynamically generate gates from start_phase
  local gates
  gates=$(jq -n --arg from "$start" \
    '[range($from|tonumber; 7) | "\(.)→\(.+1)"] | reduce .[] as $k ({}; .[$k] = "passed")')

  jq -n --arg start "$start" --arg current "$current" --arg ts "$ts" \
    --argjson phases_done "$phases_done_json" --argjson gates "$gates" \
    '{
      change_id: "test",
      goal: {
        condition: "test pipeline",
        status: "active",
        active_since: $ts,
        turns: 0,
        mode: "pending",
        scope: "pipeline",
        start_phase: $start,
        current_phase: $current,
        phases_done: $phases_done,
        gates: $gates,
        gate_config: {},
        auto_advance: false,
        phase_sub_goals: {}
      },
      phase: $current,
      task_id: null,
      interrupt: null,
      token_spent: 0,
      updated_at: $ts
    }' > "$FLOW_ACTIVE"
}

# Helper: compute rollback_targets list = [start_phase .. current-1]
rollback_targets() {
  local start="$1" current="$2"
  seq "$start" $((current - 1)) | tr '\n' ',' | sed 's/,$//'
}

# Helper: the generic rollback jq (returns new phases_done after rollback)
apply_rollback() {
  local target="$1"
  local phases_done
  phases_done=$(jq -c '.goal.phases_done // []' "$FLOW_ACTIVE")
  local remove
  remove=$(jq -n --arg target "$target" --argjson done "$phases_done" \
    '[$done[] | select((. | tonumber) > ($target | tonumber))]')
  jq --arg target "$target" --argjson remove "$remove" --arg ts "2026-06-20T11:00:00Z" \
    '.goal.current_phase = $target | .goal.phases_done -= $remove | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "$FLOW_ACTIVE.tmp" && mv "$FLOW_ACTIVE.tmp" "$FLOW_ACTIVE"
}

# ── AC-2: 动态回退目标列表生成 ────────────────────────────────────────

@test "rollback_targets: --from 4, current=5 → only [4]" {
  targets=$(rollback_targets 4 5)
  [[ "$targets" == "4" ]]
}

@test "rollback_targets: --from 0, current=6 → [0,1,2,3,4,5]" {
  targets=$(rollback_targets 0 6)
  [[ "$targets" == "0,1,2,3,4,5" ]]
}

@test "rollback_targets: --from 0, current=7 → [0,1,2,3,4,5,6]" {
  targets=$(rollback_targets 0 7)
  [[ "$targets" == "0,1,2,3,4,5,6" ]]
}

@test "rollback_targets: --from 4, current=7 → [4,5,6]" {
  targets=$(rollback_targets 4 7)
  [[ "$targets" == "4,5,6" ]]
}

# ── AC-3: 通用回退 jq ($TARGET 参数化) ───────────────────────────────

@test "rollback jq: target=4, phases_done=[4,5] → removes [5], current=4 (backward compat)" {
  skip_if_no_jq
  make_goal "4" '["4","5"]' "5"
  apply_rollback "4"
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "4" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["4"]' ]]
}

@test "rollback jq: target=4, phases_done=[4,5,6,7] → removes [5,6,7], current=4" {
  skip_if_no_jq
  make_goal "4" '["4","5","6","7"]' "7"
  apply_rollback "4"
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "4" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["4"]' ]]
}

# ── 回退到规划阶段（start_phase=0）────────────────────────────────────

@test "rollback jq: --from 0, target=2, phases_done=[0..5] → removes [3,4,5], current=2" {
  skip_if_no_jq
  make_goal "0" '["0","1","2","3","4","5"]' "6"
  apply_rollback "2"
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "2" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["0","1","2"]' ]]
}

@test "rollback jq: --from 0, target=1, phases_done=[0..6] → removes [2..6], current=1" {
  skip_if_no_jq
  make_goal "0" '["0","1","2","3","4","5","6"]' "7"
  apply_rollback "1"
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "1" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["0","1"]' ]]
}

@test "rollback jq: --from 0, target=0, phases_done=[0..6] → removes [1..6], current=0" {
  skip_if_no_jq
  make_goal "0" '["0","1","2","3","4","5","6"]' "7"
  apply_rollback "0"
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "0" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["0"]' ]]
}

# ── AC-4: 向后兼容 (--from 4 默认回退行为) ───────────────────────────

@test "backward compat: --from 4 rollback target=4 removes exactly [5] for 5-test failure" {
  skip_if_no_jq
  make_goal "4" '["4","5"]' "5"
  apply_rollback "4"
  # 结果应与改造前 current_phase="4" | phases_done-=["5"] 一致
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "4" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["4"]' ]]
}

@test "backward compat: --from 4, target=4 for 6-review failure removes [5,6]" {
  skip_if_no_jq
  make_goal "4" '["4","5","6"]' "6"
  apply_rollback "4"
  [[ "$(jq -r '.goal.current_phase' "$FLOW_ACTIVE")" == "4" ]]
  [[ "$(jq -c '.goal.phases_done' "$FLOW_ACTIVE")" == '["4"]' ]]
}

# ── 边界：回退目标不能低于 start_phase ────────────────────────────────

@test "boundary: --from 4, target cannot be 0/1/2/3 (out of rollback_targets)" {
  targets=$(rollback_targets 4 6)
  # rollback_targets 应仅含 4,5；不含 0/1/2/3
  [[ "$targets" == "4,5" ]]
  [[ "$targets" != *"0"* ]]
  [[ "$targets" != *"3"* ]]
}

@test "start_phase fallback: missing start_phase defaults to 4 (rollback boundary)" {
  skip_if_no_jq
  # 旧数据无 start_phase
  echo '{"goal":{"scope":"pipeline","current_phase":"6","phases_done":["4","5"],"status":"active","condition":"old"}}' > "$FLOW_ACTIVE"
  start=$(jq -r '.goal.start_phase // "4"' "$FLOW_ACTIVE")
  [[ "$start" == "4" ]]
}
