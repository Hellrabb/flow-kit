#!/usr/bin/env bats
# no-skip-clarify.bats — AC-1 · 反问 gate 防跳反问（弱模型鲁棒性）
# 验 RULES R3.5 + 0-change / 1-requirement prompt 含反问 gate

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  RULES="$ROOT/flow-kit-bundle/flow-kit/RULES.md"
  PROMPTS="$ROOT/flow-kit-bundle/flow-kit/prompts"
}

@test "RULES.md 含 R3.5 禁跳反问硬约束" {
  run grep -q "R3.5.*禁跳反问" "$RULES"
  [ "$status" -eq 0 ]
}

@test "0-change prompt 含反问 gate" {
  run grep -q "反问 gate" "$PROMPTS/0-change.md"
  [ "$status" -eq 0 ]
}

@test "1-requirement prompt 含反问 gate" {
  run grep -q "反问 gate" "$PROMPTS/1-requirement.md"
  [ "$status" -eq 0 ]
}
