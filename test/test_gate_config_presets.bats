#!/usr/bin/env bats
# test_gate_config_presets.bats — gate-config 预设名 + 数字简写测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  FLOW_ACTIVE="$TEST_TMPDIR/.flow-active"

  # 创建最小 .flow-active
  jq -n '{
    change_id: "test-preset",
    goal: null,
    phase: "0",
    task_id: null,
    interrupt: null,
    token_spent: 0,
    updated_at: "2026-01-01T00:00:00Z"
  }' > "$FLOW_ACTIVE"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Helper: resolve gate_config value ──────────────────────────────────

# Simulates the resolve_gate_config() logic from /flow skill
resolve_gate_config() {
  local value="$1"

  # a. Valid JSON object → use directly (backward compat)
  #    Must be an object ({...}), not a bare number/string to avoid
  #    clashing with numeric shorthand (e.g., "6" is valid JSON number)
  if echo "$value" | jq empty 2>/dev/null && echo "$value" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "$value" | jq -c '.'
    return 0
  fi

  # b. Preset name → lookup
  case "$value" in
    full)
      echo '{"1-requirement":"independent","2-design":"independent","6-review":"independent"}'
      ;;
    all)
      echo '{"1-requirement":"independent","2-design":"independent","3-task":"independent","5-test":"independent","6-review":"independent","7-integration":"independent"}'
      ;;
    code-only|review)
      echo '{"6-review":"independent"}'
      ;;
    design)
      echo '{"2-design":"independent"}'
      ;;
    requirement)
      echo '{"1-requirement":"independent"}'
      ;;
    plan)
      echo '{"1-requirement":"independent","2-design":"independent"}'
      ;;
    design-review)
      echo '{"2-design":"independent","6-review":"independent"}'
      ;;
    requirement-review)
      echo '{"1-requirement":"independent","6-review":"independent"}'
      ;;
    task)
      echo '{"3-task":"independent"}'
      ;;
    test)
      echo '{"5-test":"independent"}'
      ;;
    integration)
      echo '{"7-integration":"independent"}'
      ;;
    task-review)
      echo '{"3-task":"independent","6-review":"independent"}'
      ;;
    test-review)
      echo '{"5-test":"independent","6-review":"independent"}'
      ;;
    task-test)
      echo '{"3-task":"independent","5-test":"independent"}'
      ;;
    task-test-review)
      echo '{"3-task":"independent","5-test":"independent","6-review":"independent"}'
      ;;
    spec-test)
      echo '{"1-requirement":"independent","2-design":"independent","5-test":"independent"}'
      ;;
    *)
      # c. Numeric shorthand (comma-separated digits)
      if echo "$value" | grep -qE '^[0-9](,[0-9])*$'; then
        local result="{}"
        IFS=',' read -ra NUMS <<< "$value"
        for num in "${NUMS[@]}"; do
          case "$num" in
            1) result=$(echo "$result" | jq -c '. + {"1-requirement":"independent"}') ;;
            2) result=$(echo "$result" | jq -c '. + {"2-design":"independent"}') ;;
            3) result=$(echo "$result" | jq -c '. + {"3-task":"independent"}') ;;
            5) result=$(echo "$result" | jq -c '. + {"5-test":"independent"}') ;;
            6) result=$(echo "$result" | jq -c '. + {"6-review":"independent"}') ;;
            7) result=$(echo "$result" | jq -c '. + {"7-integration":"independent"}') ;;
            *) echo "ERROR: invalid phase number: $num" >&2; return 1 ;;
          esac
        done
        echo "$result"
      else
        echo "ERROR: invalid gate-config value: $value" >&2
        return 1
      fi
      ;;
  esac
}

# ── AC-6: 预设名识别 ──────────────────────────────────────────────────

@test "AC-6: preset 'full' → 3 keys all independent" {
  run resolve_gate_config "full"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 3 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-6: preset 'code-only' → only 6-review" {
  run resolve_gate_config "code-only"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-6: preset 'review' (alias of code-only) → only 6-review" {
  run resolve_gate_config "review"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-6: preset 'design' → only 2-design" {
  run resolve_gate_config "design"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
}

@test "AC-6: preset 'requirement' → only 1-requirement" {
  run resolve_gate_config "requirement"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
}

@test "AC-6: preset 'plan' → 1+2" {
  run resolve_gate_config "plan"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
}

@test "AC-6: preset 'design-review' → 2+6" {
  run resolve_gate_config "design-review"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-6: preset 'requirement-review' → 1+6" {
  run resolve_gate_config "requirement-review"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-4: preset 'all' → 6 keys, includes 3/5/7" {
  run resolve_gate_config "all"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 6 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["7-integration"]')" = "independent" ]
}

@test "AC-4: 'full' excludes 3/5/7 (default off)" {
  run resolve_gate_config "full"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" -eq 3 ]
  [ "$(echo "$output" | jq 'has("3-task")')" = "false" ]
  [ "$(echo "$output" | jq 'has("5-test")')" = "false" ]
  [ "$(echo "$output" | jq 'has("7-integration")')" = "false" ]
}

@test "AC-6: all 9 presets produce valid JSON" {
  for preset in full all code-only review design requirement plan design-review requirement-review; do
    run resolve_gate_config "$preset"
    [ "$status" -eq 0 ] || { echo "FAILED preset: $preset"; false; }
    echo "$output" | jq empty || { echo "INVALID JSON for preset: $preset"; false; }
  done
}

# ── AC-7: 数字简写 ────────────────────────────────────────────────────

@test "AC-7: numeric '6' → only 6-review" {
  run resolve_gate_config "6"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-7: numeric '1' → only 1-requirement" {
  run resolve_gate_config "1"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
}

@test "AC-7: numeric '2' → only 2-design" {
  run resolve_gate_config "2"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
}

@test "AC-7: numeric '1,2' → 1+2" {
  run resolve_gate_config "1,2"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
}

@test "AC-7: numeric '1,6' → 1+6" {
  run resolve_gate_config "1,6"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-7: numeric '2,6' → 2+6" {
  run resolve_gate_config "2,6"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-7: numeric '1,2,6' → 3 keys (same as full)" {
  run resolve_gate_config "1,2,6"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 3 ]
}

@test "AC-4: numeric '3' → only 3-task" {
  run resolve_gate_config "3"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
}

@test "AC-4: numeric '5' → only 5-test" {
  run resolve_gate_config "5"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
}

@test "AC-4: numeric '7' → only 7-integration" {
  run resolve_gate_config "7"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["7-integration"]')" = "independent" ]
}

@test "AC-4: numeric '1,2,3,5,6,7' → 6 keys (= all preset)" {
  run resolve_gate_config "1,2,3,5,6,7"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 6 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["7-integration"]')" = "independent" ]
}

# ── AC-8: 兼容完整 JSON ──────────────────────────────────────────────

@test "AC-8: valid JSON passthrough unchanged" {
  input='{"1-requirement":"independent","6-review":"independent"}'
  run resolve_gate_config "$input"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "AC-8: valid JSON with all three keys" {
  input='{"1-requirement":"independent","2-design":"independent","6-review":"independent"}'
  run resolve_gate_config "$input"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 3 ]
}

# ── 新增预设 (independent-review-gap) ──────────────────────────────────

@test "preset 'task' → only 3-task" {
  run resolve_gate_config "task"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
}

@test "preset 'test' → only 5-test" {
  run resolve_gate_config "test"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
}

@test "preset 'integration' → only 7-integration" {
  run resolve_gate_config "integration"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 1 ]
  [ "$(echo "$output" | jq -r '.["7-integration"]')" = "independent" ]
}

@test "preset 'task-review' → 3+6" {
  run resolve_gate_config "task-review"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "preset 'test-review' → 5+6" {
  run resolve_gate_config "test-review"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "preset 'task-test' → 3+5" {
  run resolve_gate_config "task-test"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 2 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
}

@test "preset 'task-test-review' → 3+5+6" {
  run resolve_gate_config "task-test-review"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 3 ]
  [ "$(echo "$output" | jq -r '.["3-task"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["6-review"]')" = "independent" ]
}

@test "preset 'spec-test' → 1+2+5" {
  run resolve_gate_config "spec-test"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq 'length')
  [ "$count" -eq 3 ]
  [ "$(echo "$output" | jq -r '.["1-requirement"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["2-design"]')" = "independent" ]
  [ "$(echo "$output" | jq -r '.["5-test"]')" = "independent" ]
}

# ── 无效输入报错 ──────────────────────────────────────────────────────

@test "invalid gate-config value returns error" {
  run resolve_gate_config "invalid_value_xyz"
  [ "$status" -ne 0 ]
}

@test "invalid numeric (4) returns error — 4-dev excluded (no independent review)" {
  run resolve_gate_config "4"
  [ "$status" -ne 0 ]
}
