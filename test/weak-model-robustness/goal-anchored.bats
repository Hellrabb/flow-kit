#!/usr/bin/env bats
# goal-anchored.bats — AC-5 · GO.md 阶段入场 goal 锚定（防中途漂移 · 非每步）
# 验 GO.md 含 goal 锚定，且声明仅入场一次（非每步唠叨）

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  GO="$ROOT/flow-kit-bundle/flow-kit/GO.md"
}

@test "GO.md 含阶段入场 goal 锚定" {
  run grep -qE "goal.*锚定|本阶段锚定" "$GO"
  [ "$status" -eq 0 ]
}

@test "GO.md goal 锚定声明仅入场一次（非每步）" {
  run grep -q "仅入场" "$GO"
  [ "$status" -eq 0 ]
}
