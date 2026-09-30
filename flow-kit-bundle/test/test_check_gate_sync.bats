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
# T03（health-fix-2026-09c · C1 · AC-1/AC-2）：漂移腿沙箱化 —— 三个 T02 漂移用例不再
# 直写 tracked SKILL.md（sed 注入落到 F6 mktemp 夹具内副本，见 LESSONS 2026-09-29 🔴
# 并发固化破坏事故）；setup/teardown 备份改 mktemp 唯一路径（防并发双跑互踩）、还原去
# || true（失败必须报警）；新增 AC-2 kill 注入腿（L2 r2 R10 修订 2026-09-29）：夹具
# 运行中注入 SIGTERM/SIGKILL ⇒ rc≠0 且 tracked skills/ 零改动（防「沙箱化被回退」回归）。

SCRIPT="flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
SKILL_REL="flow-kit-bundle/skills/flow/SKILL.md"   # 相对路径常量：沙箱内拼 $SBX/fk/$SKILL_REL

setup() {
  # T03 后漂移用例已沙箱化、不再直写 tracked SKILL.md；此备份降级为回归安全网：
  # 若未来某腿重新直写 tracked 文件，teardown 仍能还原。
  # 备份路径 mktemp 唯一：旧版固定后缀 .t02-bak 在并发双跑下互踩
  # （p1 改写 SKILL.md 后 p2 才 setup ⇒ p2 备份并还原的是漂移内容 ⇒ 破坏被固化）。
  T02_BAK=$(mktemp "${TMPDIR:-/tmp}/t02-skill-bak.XXXXXX")
  cp "$SKILL_REL" "$T02_BAK"
}

teardown() {
  # T03：去掉 || true —— 备份存在则必须成功还原，还原失败 = teardown 判红报警（不静默吞；
  # 旧版 || true 正是并发事故里「破坏固化后静默跳过还原」的帮凶）。备份不存在说明 setup
  # 未建立（如该测试被过滤跳过），正常返回。
  if [[ -f "$T02_BAK" ]]; then
    mv -f "$T02_BAK" "$SKILL_REL"
  fi
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

# ── T03（C1 · AC-1）T02 漂移腿沙箱化：sed 注入从 tracked SKILL.md 改落到 F6 夹具副本 ──
# 旧形态（sed -i 直写 tracked 文件 + setup/teardown 还原）两宗罪：
#   ① 并发双跑互踩：共享 .t02-bak 备份 + 同时 sed 同一 tracked 文件 ⇒ 破坏被「正式固化」
#     （LESSONS 2026-09-29 🔴：3 个并发 make check 后 tracked SKILL.md 实际丢行）；
#   ② kill 中断（CI 超时 / 手动 ^C / OOM）跳过 teardown ⇒ tracked 文件留脏。
# 新形态照搬同文件 T-FIX-04 F6 双态腿的现成写法（mktemp -d 唯一夹具 + cd 夹具运行 +
# rm -rf 收尾），不新造沙箱框架。
FXC1() {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tc1-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills" "$SBX/fk/flow-kit-bundle/test"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp -r flow-kit-bundle/flow-kit/prompts/. "$SBX/fk/flow-kit-bundle/flow-kit/prompts/"
  cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/"
  cp flow-kit-bundle/test/test_gate_config_presets.bats "$SBX/fk/flow-kit-bundle/test/"
  echo "[fixture] $SBX/fk (pid $$)"   # 夹具路径留痕（--show-output-of-passing-tests 可见）
}

@test "T02: SKILL.md 注入假预设（有 →）→ gate-config 段报漂移 + 列出 fake-preset" {
  FXC1
  sed -i '/# review[[:space:]]*→/a\     # fake-preset         → {"6-review":"independent"}' "$SBX/fk/$SKILL_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [[ "$output" == *"gate-config 预设名集合不一致"* ]]
  [[ "$output" == *"fake-preset"* ]]
  rm -rf "$SBX"
}

@test "T02: SKILL.md 删除真预设 design → gate-config 段报漂移" {
  FXC1
  sed -i '/# design[[:space:]]*→.*2-design/d' "$SBX/fk/$SKILL_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [[ "$output" == *"gate-config 预设名集合不一致"* ]]
  rm -rf "$SBX"
}

@test "T02: 不依赖文本段 marker — 注入英文注释（无 →）不误报漂移" {
  FXC1
  sed -i '/预设名映射表（PRESET_MAP）/a\     # note: explanatory comment without arrow' "$SBX/fk/$SKILL_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [[ "$output" == *"预设名集合一致"* ]]
  [[ "$output" != *"gate-config 预设名集合不一致"* ]]
  rm -rf "$SBX"
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

# ── T-FIX-25 TD-104 行为级判别力（常设网） ──
# 收口 L3 第 20/21 轮 major②：T-FIX-10 的静态 grep 判据对「缺陷形态（diff_out=$(diff … || true) 吞 rc）」
# 与「修复形态（显式 diff_rc=$? 捕获 + rc≥2 机械故障分支）」无判别力。本腿把判别力从
# change 期静态 grep 升级为常设网里的**行为级用例**：真造一次 diff 机械故障（rc≥2），断言生产件
# 判红并具名 🔴 MECHANICAL（不是泛化 🔴），且不打印任何 ✅ 一致 放行行。
# 反向控制（变异腿，先红留档于 /tmp/tfix25/）：把 SUT 副本两处 diff_rc=$? 还原为 || true 形态 ⇒
#   缺陷形态下既不打印 🔴 MECHANICAL 也不打印 ✅ 一致（set -u 下 diff_rc 未绑定即崩）⇒ 本腿 not ok。
# 独立夹具生成器（与 FXB10 同款构造，避免与既有腿耦合）。
FXB25() {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix25-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" "$SBX/fk/flow-kit-bundle/flow-kit/prompts" "$SBX/fk/flow-kit-bundle/skills" "$SBX/fk/flow-kit-bundle/test"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp flow-kit-bundle/flow-kit/prompts/A-evolve.md flow-kit-bundle/flow-kit/prompts/I-intel-scan.md flow-kit-bundle/flow-kit/prompts/L-restyle.md "$SBX/fk/flow-kit-bundle/flow-kit/prompts/"
  for sk in flow-evolve flow-intel flow-restyle flow; do
    mkdir -p "$SBX/fk/flow-kit-bundle/skills/$sk"
    cp "flow-kit-bundle/skills/$sk/SKILL.md" "$SBX/fk/flow-kit-bundle/skills/$sk/"
  done
  cp flow-kit-bundle/test/test_gate_config_presets.bats "$SBX/fk/flow-kit-bundle/test/"
}

@test "T-FIX-25 TD-104: PATH 影子 diff（恒 rc=2）→ rc≠0 + 具名 🔴 MECHANICAL + 不打印 ✅ 一致" {
  FXB25
  # 影子命令：$FIXTURE/shadows/diff（#!/bin/sh + exit 2）
  mkdir -p "$SBX/fk/shadows"
  printf '#!/bin/sh\nexit 2\n' > "$SBX/fk/shadows/diff"
  chmod +x "$SBX/fk/shadows/diff"
  # 前置自检：影子 diff 在该 PATH 下确实 rc=2（前置不成立 ⇒ not ok，不静默空转）
  # bats test body 在 run 之外 set -e 生效 ⇒ 用 { … ; } || true 包裹取 rc，不触发中止
  printf 'a\n' > "$SBX/fk/p_a"
  printf 'b\n' > "$SBX/fk/p_b"
  shadow_rc=0
  { PATH="$SBX/fk/shadows:$PATH" command diff "$SBX/fk/p_a" "$SBX/fk/p_b" >/dev/null 2>&1; } || shadow_rc=$?
  [ "$shadow_rc" -eq 2 ]   # 确切值（L-173）：前置自检必须 rc=2，否则本腿 not ok
  # SUT 在影子 diff 下运行：机械故障不得被折算为「一致」
  run bash -c "cd '$SBX/fk' && PATH='$SBX/fk/shadows:$PATH' bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]                                    # ① rc ≠ 0（机械故障必须判红）
  [[ "$output" == *"🔴 MECHANICAL"* ]]                  # ② 具名 🔴 MECHANICAL（非泛化 🔴）
  [[ "$output" != *"✅"*"一致"* ]]                      # ③ 不得打印 ✅ … 一致 放行行
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

# ── T03（C1 · AC-2）kill 注入腿（L2 r2 R10 修订 2026-09-29）──
# 防回退回归：若沙箱化被回退（用例重新直写 tracked SKILL.md），夹具运行中被 kill 会跳过
# 还原逻辑 ⇒ tracked 文件留脏。本腿在夹具运行中注入 SIGTERM/SIGKILL ⇒ 断言 rc≠0 且
# 沙箱外 tracked skills/ 未被改动。断言用 `git diff --stat -- flow-kit-bundle/skills/`
# （只查 skills/ —— 同波次有其他并行任务的未提交改动，全树断言会假红；全树留给编排者波末跑）。
# 运行窗口确定性：影子 diff 先 sleep 3 再放行真 diff（沿用 R3-20/T-FIX-25 的 PATH 影子手法），
# 保证注入时 SUT 必在运行中（非竞速抢时间片）。
@test "T03 AC-2: 夹具运行中注入 SIGTERM/SIGKILL → rc≠0 + tracked skills/ 零改动（沙箱防回退）" {
  FXC1
  mkdir -p "$SBX/fk/shadows"
  REAL_DIFF=$(command -v diff)
  printf '#!/bin/sh\nsleep 3\nexec "%s" "$@"\n' "$REAL_DIFF" > "$SBX/fk/shadows/diff"
  chmod +x "$SBX/fk/shadows/diff"
  for sig in TERM KILL; do
    echo "[kill-inject] sig=$sig fixture=$SBX/fk"
    ( cd "$SBX/fk" && PATH="$SBX/fk/shadows:$PATH" bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh ) >"$SBX/out.$sig" 2>&1 &
    sut=$!
    sleep 1                                       # 影子 diff sleep 3 ⇒ 此时 SUT 必在运行
    pkill -"$sig" -P "$sut" -f check-gate-sync 2>/dev/null || true   # 先杀内层 SUT（父未死时 -P 才找得到子）
    kill -"$sig" "$sut" 2>/dev/null || true                          # 再杀外层包装（尽力而为，rc 断言兜底）
    sut_rc=0
    wait "$sut" || sut_rc=$?
    [ "$sut_rc" -ne 0 ]                           # ① kill 注入必须 rc≠0（TERM=143 / KILL=137）
    run git diff --stat -- flow-kit-bundle/skills/
    [ "$status" -eq 0 ]                           # ② git 本身不出错
    [ -z "$output" ]                              # ③ tracked skills/ 零改动（空输出）
  done
  rm -rf "$SBX"
}
