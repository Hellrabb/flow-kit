#!/usr/bin/env bats
# test_check_gate_sync.bats — check-gate-sync.sh gate-config 预设同步段
# T02 (gate-integrity): 语义 set-diff 校验 SKILL.md PRESET_MAP ↔ bats 镜像
# 对应 G4 ADR · AC-4
#
# 注：check-gate-sync.sh 同时跑 toll-gate 校验（4-dev↔flow-dev）+ gate-config 校验。
# toll-gate 段基线有 pre-existing PCSC 漂移（prompt=9 vs skill=8，非本测试引入），
# 故测试聚焦 gate-config 段的输出文本断言（"预设名集合一致" / "gate-config 预设名集合不一致"），
# 不依赖整脚本 exit 码（被 toll-gate 段污染）。

SCRIPT="flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
SKILL="flow-kit-bundle/skills/flow/SKILL.md"

setup() {
  # 漂移测试会改 SKILL.md，备份保证还原（避免污染其他测试套 + L-015 源完整性）
  cp "$SKILL" "$SKILL.t02-bak"
}

teardown() {
  [[ -f "$SKILL.t02-bak" ]] && mv -f "$SKILL.t02-bak" "$SKILL" || true
}

@test "T02: check-gate-sync.sh 存在且可执行" {
  run test -x "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（9 预设）" {
  run bash "$SCRIPT"
  [ "$status" -ne 2 ]                                  # 非脚本错误（exit 2）
  [[ "$output" == *"预设名集合一致 (17 个预设)"* ]]     # gate-config 段 MATCH
  [[ "$output" != *"gate-config 预设名集合不一致"* ]]  # 无 gate-config 漂移
}

@test "T02: SKILL.md 注入假预设（有 →）→ gate-config 段报漂移 + 列出 fake-preset" {
  sed -i '/# review[[:space:]]*→/a\     # fake-preset         → {"6-review":"independent"}' "$SKILL"
  run bash "$SCRIPT"
  [[ "$output" == *"gate-config 预设名集合不一致"* ]]
  [[ "$output" == *"fake-preset"* ]]
}

@test "T02: SKILL.md 删除真预设 design → gate-config 段报漂移" {
  sed -i '/# design[[:space:]]*→.*2-design/d' "$SKILL"
  run bash "$SCRIPT"
  [[ "$output" == *"gate-config 预设名集合不一致"* ]]
}

@test "T02: 不依赖文本段 marker — 注入英文注释（无 →）不误报漂移" {
  sed -i '/预设名映射表（PRESET_MAP）/a\     # note: explanatory comment without arrow' "$SKILL"
  run bash "$SCRIPT"
  [[ "$output" == *"预设名集合一致"* ]]
  [[ "$output" != *"gate-config 预设名集合不一致"* ]]
}
