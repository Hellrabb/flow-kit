#!/usr/bin/env bats
# test_check_gate_sync.bats — check-gate-sync.sh gate-config 预设同步段
# T02 (gate-integrity): 语义 set-diff 校验 SKILL.md PRESET_MAP ↔ bats 镜像
# 对应 G4 ADR · AC-4
#
# 注：check-gate-sync.sh 同时跑 PCSC 校验对（3/PAIRS_TOTAL）+ gate-config 校验。
# 实测健康态（T15/AC-4 修复后）：整脚本 rc=0，汇总行「✅ 校验对 3/PAIRS_TOTAL 一致」，
# gate-config 段「✅ 预设名集合一致 (17 个预设)」⇒ 本用例在健康态断言 exit 0
# （旧注释声称 toll-gate 段有 pre-existing 漂移、故只断言 -ne 2，已失真）。
# 断言收紧为 -eq 0 后：任何内容漂移（含 gate-config 预设名漂移）都会让门禁非 0 ⇒ 本用例必红。
# T-FIX-04（F6 收敛）：新增缺对双态判据 —— 复制真实生产件进 mktemp -d 夹具，
# 隐藏一对 skill 文件 ⇒ rc≠0 且汇总不打印「✅ … 一致」；完整夹具仍 rc=0。

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

@test "T02: 基线 SKILL↔bats 预设名一致 → gate-config 段报告一致（17 预设）" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]                                  # 健康态必须 exit 0（AC-4 收紧）
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

# ── T-FIX-04 F6 双态判据：缺对不得报全绿 ──
# 判别式：复制真实生产件进 mktemp -d 夹具（禁止抄正文进 bats），隐藏一对 skill 文件
# ⇒ 坏态 rc≠0 且汇总不打印「✅ … 一致」；好态（完整夹具）仍 rc=0。
# 修复前（裸 return + ERRORS 不增 + 静态分母）：坏态 rc=0 且打印「✅ 校验对 3/14 一致」⇒ 本双态转红。
@test "T02 F6: 完整夹具（所有对文件齐全）→ rc=0 + 汇总打印一致" {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix04-ok-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp -r flow-kit-bundle/flow-kit/prompts/. "$SBX/fk/flow-kit-bundle/flow-kit/prompts/"
  cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/"
  # 真实仓也有 test/ 镜像里的 gate-config bats —— 一并复制，保证 gate-config 段可比
  mkdir -p "$SBX/fk/flow-kit-bundle/test"
  cp flow-kit-bundle/test/test_gate_config_presets.bats "$SBX/fk/flow-kit-bundle/test/" 2>/dev/null || true
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"校验对"*"一致"* ]]   # 好态：汇总打印 ✅ 一致
  rm -rf "$SBX"
}

@test "T02 F6: 缺一对 skill 文件 → rc≠0 + 汇总不打印「✅ … 一致」" {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix04-miss-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp -r flow-kit-bundle/flow-kit/prompts/. "$SBX/fk/flow-kit-bundle/flow-kit/prompts/"
  cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/"
  mkdir -p "$SBX/fk/flow-kit-bundle/test"
  cp flow-kit-bundle/test/test_gate_config_presets.bats "$SBX/fk/flow-kit-bundle/test/" 2>/dev/null || true
  # 坏态：隐藏一对中的 skill 文件（flow-evolve/SKILL.md）
  mv "$SBX/fk/flow-kit-bundle/skills/flow-evolve/SKILL.md" "$SBX/fk/flow-kit-bundle/skills/flow-evolve/SKILL.md.hidden"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]                                    # 坏态必须非 0（F6 收敛）
  [[ "$output" != *"✅ 校验对"*"一致"* ]]               # 坏态：汇总不得打印「✅ … 一致」
  [[ "$output" == *"MISSING"* ]]                        # 坏态：必须指名缺失文件
  rm -rf "$SBX"
}
