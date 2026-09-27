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

# ── T-FIX-10 R3-18/R3-19/R3-20 判别式 ──
# 复制真实生产件进 mktemp -d 夹具（3 对 PCSC + gate-config 两侧），构造三类坏态：
#   R3-18 双向：仅 prompt/skill 侧加一行 ⇒ 必须逐侧具名（不得张冠李戴）
#   R3-19：两侧预设集合同时清空 ⇒ 不得静默中止（须有汇总行或具名 🔴）
#   R3-20：PATH 影子 diff（恒 rc=2）⇒ 机械故障不得折算为「一致」（rc≠0 + 具名 🔴）
# 好态（完整夹具）仍 rc=0（T02 F6 好态已覆盖，此处不重复）。
FXB10() {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix10-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills" "$SBX/fk/flow-kit-bundle/test"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp flow-kit-bundle/flow-kit/prompts/A-evolve.md flow-kit-bundle/flow-kit/prompts/I-intel-scan.md flow-kit-bundle/flow-kit/prompts/L-restyle.md "$SBX/fk/flow-kit-bundle/flow-kit/prompts/"
  for sk in flow-evolve flow-intel flow-restyle flow; do
    mkdir -p "$SBX/fk/flow-kit-bundle/skills/$sk"
    cp "flow-kit-bundle/skills/$sk/SKILL.md" "$SBX/fk/flow-kit-bundle/skills/$sk/"
  done
  cp flow-kit-bundle/test/test_gate_config_presets.bats "$SBX/fk/flow-kit-bundle/test/"
}

@test "T-FIX-10 R3-18A: 仅 skill 侧加一行 → 具名 skill 侧，不误报 prompt 侧" {
  FXB10
  printf '\nX-DRIFT-SKILL-ONLY\n' >> "$SBX/fk/flow-kit-bundle/skills/flow-evolve/SKILL.md"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"skill 侧内容不一致"* ]]
  [[ "$output" != *"prompt 侧内容不一致"* ]]
  rm -rf "$SBX"
}

@test "T-FIX-10 R3-18B: 仅 prompt 侧加一行 → 具名 prompt 侧，不误报 skill 侧" {
  FXB10
  printf '\nX-DRIFT-PROMPT-ONLY\n' >> "$SBX/fk/flow-kit-bundle/flow-kit/prompts/A-evolve.md"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"prompt 侧内容不一致"* ]]
  [[ "$output" != *"skill 侧内容不一致"* ]]
  rm -rf "$SBX"
}

@test "T-FIX-10 R3-19: 两侧预设集合同时清空 → 不静默中止（有汇总行或具名 🔴）" {
  FXB10
  printf 'name: flow\n' > "$SBX/fk/flow-kit-bundle/skills/flow/SKILL.md"
  : > "$SBX/fk/flow-kit-bundle/test/test_gate_config_presets.bats"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"── 校验汇总 ──"* || "$output" == *"🔴"* ]]
  [[ "$output" != *"✅ 预设名集合一致"* ]]
  rm -rf "$SBX"
}

@test "T-FIX-10 R3-20: PATH 影子 diff（恒 rc=2）→ rc≠0 + 具名 🔴（不折算为一致）" {
  FXB10
  mkdir -p "$SBX/fk/bin"
  printf '#!/bin/sh\nexit 2\n' > "$SBX/fk/bin/diff"
  chmod +x "$SBX/fk/bin/diff"
  run bash -c "cd '$SBX/fk' && PATH='$SBX/fk/bin:$PATH' bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴"* ]]
  rm -rf "$SBX"
}

# ── T-FIX-18 R5-14/R5-10 判别式 ──
# 复制真实生产件进 mktemp -d 夹具（3 对 PCSC + gate-config 两侧），构造缺件态：
#   R5-14：缺 test_gate_config_presets.bats 或缺 skills/flow/SKILL.md ⇒ 必须 rc≠0 + 🔴 MISSING + 具名路径
#          （修复前为 ⚠️ WARNING + 裸 return + rc=0 + ✅ 一致 = 缺件仍报绿）
#   R5-10：判别形态（仅改内容、行数不变）⇒ 必须判红（check_pair 已是内容比对，本腿钉住该形态不退化）
#   反向控制：完整树 ⇒ rc=0 + ✅（证明判据有牙，非恒红）
# 每例都断言 $status（R5-13 同族弱点：不得只 grep 报文）。
# 去标识化（L-137）：夹具用 mktemp，断言用 BUNDLE_ROOT 相对后缀串，不得出现真实家目录整串字面。
FXB18() {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix18-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills" "$SBX/fk/flow-kit-bundle/test"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp flow-kit-bundle/flow-kit/prompts/A-evolve.md flow-kit-bundle/flow-kit/prompts/I-intel-scan.md flow-kit-bundle/flow-kit/prompts/L-restyle.md "$SBX/fk/flow-kit-bundle/flow-kit/prompts/"
  for sk in flow-evolve flow-intel flow-restyle flow; do
    mkdir -p "$SBX/fk/flow-kit-bundle/skills/$sk"
    cp "flow-kit-bundle/skills/$sk/SKILL.md" "$SBX/fk/flow-kit-bundle/skills/$sk/"
  done
  cp flow-kit-bundle/test/test_gate_config_presets.bats "$SBX/fk/flow-kit-bundle/test/"
}

@test "T-FIX-18 R5-14 ①: 缺 test_gate_config_presets.bats → rc≠0 + 🔴 MISSING + 具名路径（非 ✅ 一致）" {
  FXB18
  # 前提状态断言：被删文件在副本中确实不存在
  rm -f "$SBX/fk/flow-kit-bundle/test/test_gate_config_presets.bats"
  [ ! -f "$SBX/fk/flow-kit-bundle/test/test_gate_config_presets.bats" ]
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]                                    # 缺件必须非 0（R5-14 fail-closed）
  [[ "$output" == *"🔴 MISSING"* ]]                      # 必须具名 🔴 MISSING（非 ⚠️ WARNING）
  [[ "$output" == *"test/test_gate_config_presets.bats"* ]]  # 具名路径（不得只含泛化措辞）
  [[ "$output" != *"✅ 校验对"*"一致"* ]]               # 缺件不得打印「✅ … 一致」
  rm -rf "$SBX"
}

@test "T-FIX-18 R5-14 ②: 缺 skills/flow/SKILL.md → rc≠0 + 🔴 MISSING + 具名路径（非 ✅ 一致）" {
  FXB18
  rm -f "$SBX/fk/flow-kit-bundle/skills/flow/SKILL.md"
  [ ! -f "$SBX/fk/flow-kit-bundle/skills/flow/SKILL.md" ]
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 MISSING"* ]]
  [[ "$output" == *"skills/flow/SKILL.md"* ]]            # 具名路径
  [[ "$output" != *"✅ 校验对"*"一致"* ]]
  rm -rf "$SBX"
}

@test "T-FIX-18 R5-10 ③: 仅改一行内容（行数不变）→ 判红（内容比对，非行数短路）" {
  FXB18
  # 两侧行数相同、内容不同：把 SKILL.md 末行改一个字符（不增不减行）
  # 钉住 check_pair 的判定必须是内容比对，不得退化为行数计数
  local f="$SBX/fk/flow-kit-bundle/skills/flow-evolve/SKILL.md"
  local nlines
  nlines=$(wc -l < "$f")
  sed '${s/.*/X-CONTENT-DRIFT-SAME-LINE-COUNT/}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  # 前提断言：行数不变但内容已改
  [ "$(wc -l < "$f")" -eq "$nlines" ]
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]                                    # 行数相同但内容不同 ⇒ 必须判红
  [[ "$output" == *"漂移"* ]]
  rm -rf "$SBX"
}

@test "T-FIX-18 R5-14 ④ 反向控制: 完整树 → rc=0 + ✅（判据有牙，非恒红）" {
  FXB18
  # 前提断言：gate-config 两侧文件均存在
  [ -f "$SBX/fk/flow-kit-bundle/skills/flow/SKILL.md" ]
  [ -f "$SBX/fk/flow-kit-bundle/test/test_gate_config_presets.bats" ]
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -eq 0 ]                                    # 完整树必须 rc=0
  [[ "$output" == *"✅"* ]]
  [[ "$output" != *"🔴 MISSING"* ]]
  rm -rf "$SBX"
}
