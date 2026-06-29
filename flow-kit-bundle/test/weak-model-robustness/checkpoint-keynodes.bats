#!/usr/bin/env bats
# checkpoint-keynodes.bats — AC-3 · 4-dev 关键节点 checkpoint（非每操作 · 防啰嗦 AC-7）
# 验 4-dev 含关键节点 checkpoint，且明确限定为关键节点（非每操作）

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  DEV="$ROOT/flow-kit-bundle/flow-kit/prompts/4-dev.md"
}

@test "4-dev 含关键节点 checkpoint" {
  run grep -qE "关键节点.*checkpoint|checkpoint.*关键节点" "$DEV"
  [ "$status" -eq 0 ]
}

@test "4-dev checkpoint 限定为关键节点（含「非每操作」声明）" {
  run grep -q "非每操作" "$DEV"
  [ "$status" -eq 0 ]
}

@test "4-dev 含动手前复述边界（R7.4）" {
  run grep -qE "复述.*边界|复述.*read_files" "$DEV"
  [ "$status" -eq 0 ]
}
