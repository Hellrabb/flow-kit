#!/usr/bin/env bats
# test_path_privacy_gate.bats — check-path-privacy.sh 常设回归网（TD-053 收敛 · AC-6）
#
# 为什么存在（TD-053）：本 change 新增的路径隐私门禁，其判定力此前只活在 change 期
#   判据（T21/T22/T23）里。归档后若有人把「缺清单 ⇒ rc=1」「空清单不是错误、但也
#   不得静默跳过扫描」「清单内命中只暴露不阻塞」「常设 > change 副本」这类语义改坏，
#   `make check` 仍可能全绿（门禁在变更集上跑，天然不覆盖自身语义）。
#   本文件把这些语义固化成常设双态判据（每态一正一反）。
#
# 活性（为什么不是假绿）：setup 在**运行时**把仓内真实脚本复制进夹具再驱动
#   ⇒ 脚本被改坏、或被打成恒绿桩（exit 0）时，本文件的 rc=1 断言会转红。
#
# 夹具隔离：所有夹具建在 ${TMPDIR:-/tmp} 下（mktemp -d），teardown 清理；
#   不触碰工作树。SUT 只扫夹具内 git 仓库（git ls-files）⇒ 夹具必须自建 git init，
#   且被扫文件必须入索引（未跟踪文件不在扫描面内）。
#
# 脱敏（L-129）：本文件不含真实账号路径形态；真名探针以字符串拼接构造，
#   占位形态用 /home/<user>/ 与 /home/user/。
#
# 断言约定（沿用 test_l3_review_defects_2026_09.bats 的 L3 04:42 教训：`run` 默认把
#   stderr 合进 $output 会造成假绿）：全文件统一 `run --separate-stderr`，
#   内容断言只看 stdout（$output）——该脚本的自证报告本就该走 stdout。
#   该 flag 需要 bats ≥ 1.5，故下一行声明最低版本。
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-pp-gate.XXXXXX")"
  FIXTURE="$TEST_TMPDIR/repo"
  SUT_REL="flow-kit-bundle/flow-kit/reference/check-path-privacy.sh"
  ALLOW_REL="flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt"
  ALLOW_CHANGE_REL=".specs/health-fix-2026-09b/path-privacy-allowlist.txt"
  # 拼接构造的真名探针（与既有占位符不同形）；本文件里不出现其字面。
  # T04（health-fix-2026-09c）：探针改**裸形态**（自身不带尾斜杠）——待测形态
  # 由各用例显式拼接：既有用例 `${PROBE}/…` 保持原被测字符串（尾斜杠形态）；
  # T04 新用例直接用 `${PROBE}` 钉裸形态。探针不再把「必须尾斜杠」这一旧 PAT
  # 假设烧进夹具（原 `:33` 自带尾斜杠问题的修正）。
  PROBE="/home/""zz-path-pr""obe"

  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容 test/ 与 bundle 内镜像）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  SUT_SRC="$d/$SUT_REL"

  mkdir -p "$FIXTURE"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email "fixture@example.invalid"
  git -C "$FIXTURE" config user.name "fixture"

  # 运行时复制真实脚本（活性关键：恒绿桩会在此被吃到）
  mkdir -p "$FIXTURE/$(dirname "$SUT_REL")" "$FIXTURE/$(dirname "$ALLOW_CHANGE_REL")"
  cp -- "$SUT_SRC" "$FIXTURE/$SUT_REL"

  mkfile() { mkdir -p "$FIXTURE/$(dirname "$1")"; printf '%b' "$2" > "$FIXTURE/$1"; }
  stage() { git -C "$FIXTURE" add -- "$@"; }
  run_sut() { ( cd "$FIXTURE" && bash "$SUT_REL" ); }
  # 按需注入环境变量（如坏 TMPDIR）驱动故障态双态用例
  run_sut_env() { ( cd "$FIXTURE" && env "$@" bash "$SUT_REL" ); }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "干净态：常设清单在位 + 无探针 ⇒ rc=0 且自报「清单外命中 0 条」" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n\ndocs/notes.md:1 # 夹具条目\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单 1 条"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
  [[ "$output" == *"✅"* ]]
}

@test "真名探针（拼接构造）⇒ rc=1 且归因到 file:line" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"清单外命中 1 条"* ]]
  [[ "$output" == *"probe.txt:1"* ]]
  [[ "$output" != *"✅ 清单外命中 0 条"* ]]
}

@test "常设与 change 副本皆缺 ⇒ rc=1 且指名两个缺失路径（不得当空清单放行）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  stage "docs/notes.md"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"允许清单缺失"* ]]
  [[ "$output" == *"$ALLOW_REL"* ]]
  [[ "$output" == *"$ALLOW_CHANGE_REL"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "空清单（0 条有效条目）⇒ rc=0 且自报「允许清单 0 条」（空清单不是错误）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "# 空基线：仅注释与空行\n\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单 0 条"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

@test "空清单 + 真名探针 ⇒ rc=1（空清单不得静默跳过扫描 · 反假绿）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 空基线：仅注释\n\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"允许清单 0 条"* ]]
  [[ "$output" == *"清单外命中 1 条"* ]]
  [[ "$output" == *"probe.txt:1"* ]]
}

@test "命中落在允许清单内 ⇒ rc=0（只暴露不阻塞）" {
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "probe.txt:1 # 夹具登记\n"
  stage "probe.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"命中合计 1 条"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

@test "占位形态（<user> 与 user）⇒ 不命中 ⇒ rc=0" {
  mkfile "docs/notes.md" "占位: /home/<user>/proj\n占位: /home/user/proj\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"命中合计 0 条"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

@test "常设缺、change 副本在 ⇒ 读 change 副本（读序回退）" {
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_CHANGE_REL" "probe.txt:1 # 夹具登记\n"
  stage "probe.txt" "$ALLOW_CHANGE_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单来源: $ALLOW_CHANGE_REL"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

@test "常设与 change 副本皆在 ⇒ 常设优先（读序不回退）" {
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "probe.txt:1 # 常设登记\n"
  mkfile "$ALLOW_CHANGE_REL" "# 空基线（若被误读 ⇒ rc=1）\n"
  stage "probe.txt" "$ALLOW_REL" "$ALLOW_CHANGE_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单来源: $ALLOW_REL"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

# ============================================================================
# T-FIX-03 双态判据（F1~F5 收敛 · 阶段 6 REVIEW §B）
# 沿用既有范式：运行时复制真实生产件进夹具 + 拼接构造探针。
# 每条发现一正一反双态；夹具隔离（teardown 清理）。
# 脱敏（L-129）：探针用字符串拼接构造，本文件不出现真实账号路径形态。
# ============================================================================

# ---- F1（🔴 机械故障 ⇒ 必须非 0）双态 ----

@test "F1 坏态：TMPDIR 不可用 + 真泄漏 ⇒ rc≠0 且不得打印「清单外命中 0 条」" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  BAD_TMPDIR="${TEST_TMPDIR}/no-such-dir-probe"
  run --separate-stderr run_sut_env TMPDIR="$BAD_TMPDIR"
  [ "$status" -ne 0 ]
  [[ "$output" != *"清单外命中 0 条 ✅"* ]]
  [[ "$output" != *"✅ 清单外命中 0 条"* ]]
}

@test "F1 好态：TMPDIR 可用 + 真泄漏 ⇒ 正常归因（rc=1 + leak file:line），故障态未旁路正常流程" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"清单外命中 1 条"* ]]
  [[ "$output" == *"probe.txt:1"* ]]
}

# ---- F2（🔴 0 候选 ≠ 干净）双态 · 两型 ----

@test "F2 坏态①：非 git 目录 + 真泄漏 ⇒ rc≠0（0 候选面与干净不得同形）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"
  # 拆掉夹具的 .git ⇒ 非 git 目录（候选枚举失败 ⇒ 0 候选面）
  rm -rf "$FIXTURE/.git"

  run --separate-stderr run_sut
  [ "$status" -ne 0 ]
}

@test "F2 坏态②：git 仓但 index 为空（未 add）+ 真泄漏 ⇒ rc≠0" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  # 注意：此处不 stage ⇒ git ls-files rc=0 但输出 0 行（空 index 变体）
  # （setup 已 git init；未 add ⇒ index 为空）

  run --separate-stderr run_sut
  [ "$status" -ne 0 ]
}

@test "F2 好态：候选文件数落进自证行且与 git ls-files 一致" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"候选文件"* ]]
  local reported real
  reported=$(printf '%s\n' "$output" | grep -oE '候选文件[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  real=$(git -C "$FIXTURE" ls-files | wc -l | tr -d ' ')
  [ "${reported:-x}" = "$real" ]
  # F18（阶段 6 深审 · 用户裁决 option ② 仅措辞）：扫描面措辞精确化，
  # 标注拦截面对象 = git index（已 add / 已提交），untracked 不在面内。
  # 旧措辞「工作树」误导读者以为未 add 的未忽略文件也在面内（态 G2 假绿是措辞问题，非链断）。
  [[ "$output" == *"扫描面: 工作树（git index：已 add / 已提交）"* ]]
}

# ---- F3（🟡 二进制策略单点）双态 ----

@test "F3 坏态：tracked 二进制含探针 ⇒ 工作树模式必须非 0 且归因可解析（line 为数字）" {
  mkfile "docs/notes.md" "clean\n"
  printf 'BIN\x00%s/\x00\n' "${PROBE}" > "$FIXTURE/bin.dat"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "bin.dat" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -ne 0 ]
  printf '%s\n' "$output" | grep -qE 'bin\.dat:[0-9]+:'
}

@test "F3 好态：干净仓 + 无探针 ⇒ rc=0（二进制策略未引入假红）" {
  mkfile "docs/notes.md" "clean\n"
  printf 'BIN\x00no-probe-here\x00\n' > "$FIXTURE/bin.dat"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "bin.dat" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
}

# ---- F4（🟡 注释口径单点）双态 ----

@test "F4 坏态：清单仅含 HTML 注释 ⇒ 自证须报「允许清单 0 条」（不得计为有效条目）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "<!-- only html comment -->\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [[ "$output" == *"允许清单 0 条"* ]]
}

@test "F4 好态：清单含有效 file:line + # 注释 ⇒ 计数正确（口径一致）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\nprobe.txt:1 # 夹具登记\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单 1 条"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

# ---- F5（🟡 临时文件单点）双态 ----

@test "F5 静态：全脚本只剩一个 EXIT trap（单一事实源）" {
  local trap_count
  trap_count=$(grep -cE '^[[:space:]]*trap .*EXIT' "$SUT_SRC")
  [ "$trap_count" -eq 1 ]
}

@test "F5 好态：正常扫描 + 正常退出 ⇒ 临时文件被清理（唯一 trap 覆盖全部 TMP）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "$ALLOW_REL"

  local before tmp_count after
  before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l | tr -d ' ')
  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  # 清理后不得残留本门禁的临时文件（按 mktemp 前缀 tmp. 计数前后相等）
  after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l | tr -d ' ')
  [ "$after" -le "$before" ]
}

# ---- F19（🟡 0 实际扫描 ≠ 干净 · 自排除后空面 fail-closed）双态 ----
# 阶段 6 深审 F-19：候选枚举（自排除前）计数 N，扫描循环 is_self_exclude 跳过 ⇒
# 若 tracked 全部命中 SELF_EXCLUDE，scan_file 实际调用 0 次却仍报「清单外命中 0 条」+ ✅ + rc=0。
# fix：新增 SCANNED_COUNT（实际 scan_file 次数），自证含「实际扫描 M 个」，
# M=0 && N>0 ⇒ fail-closed rc=1 且不打印「清单外命中 0 条」/「✅」。

@test "F19 坏态：tracked 全部命中 SELF_EXCLUDE ⇒ rc≠0 且自证含「实际扫描 0 个」且不打印清单外命中 0 条/✅（0 扫描 ≠ 干净）" {
  # 夹具仓 tracked 全为 SELF_EXCLUDE 成员：SUT（#1）+ 常设允许清单（#2）。
  # 两者必然含 PAT 字面（脚本自引用 / 允许清单格式说明），必须从扫描面排除。
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "$SUT_REL" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -ne 0 ]
  [[ "$output" == *"实际扫描 0 个"* ]]
  [[ "$output" != *"清单外命中 0 条"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "F19 好态：候选面含至少 1 个非自排除文件 ⇒ rc=0 且自证含「实际扫描 M 个」（M ≥ 1）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"实际扫描"* ]]
  local scanned reported real
  scanned=$(printf '%s\n' "$output" | grep -oE '实际扫描[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  reported=$(printf '%s\n' "$output" | grep -oE '候选文件[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  real=$(git -C "$FIXTURE" ls-files | wc -l | tr -d ' ')
  # 实际扫描数 ≥ 1（docs/notes.md 未被自排除），且 ≤ 候选数（自排除只减不增）
  [ "${scanned:-0}" -ge 1 ]
  [ "${scanned:-0}" -le "${reported:-0}" ]
  # 候选文件数仍与 git ls-files 一致（F2 #14 不变量不变）
  [ "${reported:-x}" = "$real" ]
}

# ---- F20（🟡 mktemp 失败必须立即终止 · 无冗余报文）双态 ----
# 阶段 6 深审 F-20：mktemp_checked() 内 exit 1 位于命令替换中 ⇒ 只退子 shell，
# 脚本继续（变量退化为空串，产生 3 条冗余 🔴 mktemp 失败）。
# fix：函数改 return 1 + 4 处调用点（含汇总段 TMP_ALLOWLIST_KEYS）|| exit 1 ⇒ 坏 TMPDIR 下恰 1 条 mktemp 报文且立即 exit 1。

@test "F20 坏态：TMPDIR 不可用 ⇒ rc≠0 且「mktemp 失败」报文恰 1 次（立即终止、无冗余）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  BAD_TMPDIR="${TEST_TMPDIR}/no-such-dir-f20"
  run --separate-stderr run_sut_env TMPDIR="$BAD_TMPDIR"
  [ "$status" -ne 0 ]
  local cnt
  cnt=$(printf '%s\n' "$stderr" | grep -c 'mktemp 失败' || true)
  [ "$cnt" -eq 1 ]
}

@test "F20 好态：正常 TMPDIR ⇒ 无 mktemp 失败报文且 rc=0（正常路径未被误伤）" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" != *"mktemp 失败"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

# ============================================================================
# T-FIX-08 允许清单来源覆盖旋钮 FLOW_KIT_PRIVACY_ALLOWLIST（R3-14 (c)①）
# 覆盖生效 / 覆盖路径不可读 ⇒ fail-closed 且指名 / 未设置时读序逐字不变。
# 双态镜像：test/ 与 flow-kit-bundle/test/ 同步（make test-sync）。
# ============================================================================

# 覆盖路径（夹具内绝对路径，与常设/change 副本不同源）。
run_sut_override() {
  local override="$1"
  ( cd "$FIXTURE" && FLOW_KIT_PRIVACY_ALLOWLIST="$override" bash "$SUT_REL" )
}

@test "T-FIX-08 覆盖生效：FLOW_KIT_PRIVACY_ALLOWLIST 指向自定义清单 ⇒ 读覆盖清单（不回退常设/change）" {
  # 常设清单登记 probe（若被误读 ⇒ rc=0 假绿）；覆盖清单为空（若被读 ⇒ rc=1 真红）。
  # 预期：覆盖生效 ⇒ 读空清单 ⇒ 真泄漏 rc=1（覆盖优先级高于常设）。
  mkfile "docs/notes.md" "纯文本\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "probe.txt:1 # 常设登记（若被读 ⇒ rc=0 假绿）\n"
  mkfile "$ALLOW_CHANGE_REL" "probe.txt:1 # change 登记\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL" "$ALLOW_CHANGE_REL"

  local override="$FIXTURE/custom-allowlist.txt"
  printf '# 覆盖清单（空）\n\n' > "$override"

  run --separate-stderr run_sut_override "$override"
  [ "$status" -eq 1 ]
  [[ "$output" == *"允许清单来源: $override"* ]]
  [[ "$output" == *"允许清单 0 条"* ]]
  [[ "$output" == *"清单外命中 1 条"* ]]
  # 不得读到常设或 change 来源（覆盖优先级最高）
  [[ "$output" != *"允许清单来源: $ALLOW_REL"* ]]
  [[ "$output" != *"允许清单来源: $ALLOW_CHANGE_REL"* ]]
}

@test "T-FIX-08 覆盖 fail-closed：FLOW_KIT_PRIVACY_ALLOWLIST 指向不存在路径 ⇒ rc=1 且指名该路径" {
  mkfile "docs/notes.md" "纯文本\n"
  mkfile "$ALLOW_REL" "# 常设在位（但覆盖优先级更高，不应被读）\n"
  stage "docs/notes.md" "$ALLOW_REL"

  local override="$FIXTURE/no-such-allowlist.txt"
  # 不创建该文件 ⇒ 覆盖路径不存在

  run --separate-stderr run_sut_override "$override"
  [ "$status" -eq 1 ]
  [[ "$output" == *"允许清单缺失"* ]]
  [[ "$output" == *"fail-closed"* ]]
  [[ "$output" == *"$override"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "T-FIX-08 未设置读序不变：FLOW_KIT_PRIVACY_ALLOWLIST 未设 ⇒ 读序逐字不变（常设 > change > 缺失）" {
  # 未设置覆盖旋钮 ⇒ 现有读序逐字不变：常设在位 ⇒ 读常设（即使 change 也在位）。
  mkfile "probe.txt" "泄漏点: ${PROBE}/host\n"
  mkfile "$ALLOW_REL" "probe.txt:1 # 常设登记\n"
  mkfile "$ALLOW_CHANGE_REL" "# 空基线（若被误读 ⇒ rc=1）\n"
  stage "probe.txt" "$ALLOW_REL" "$ALLOW_CHANGE_REL"

  # 显式 unset（确保未设置，而非继承空）
  run --separate-stderr run_sut_env -u FLOW_KIT_PRIVACY_ALLOWLIST
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单来源: $ALLOW_REL"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
  [[ "$output" != *"允许清单来源: $ALLOW_CHANGE_REL"* ]]
}

# T-FIX-11（R4-1）：已跟踪文件「未 staged 删除」被误判「不可读候选」⇒ 过严红。
# 口径对齐「候选面 = index、内容面 = index ∪ 工作树」—— 磁盘缺失但 index 侧仍是 blob
# ⇒ 不得递增 UNREADABLE_COUNT；index 侧 git grep --cached 逐字不变。
# 三例夹具一律 mktemp 隔离、探针拼接构造（L-137）、覆盖旋钮指向空清单（避免 CWD 读序依赖）。
@test "T-FIX-11①：已跟踪未 staged 删除且内容干净 ⇒ rc=0 且「不可读候选 0 个」（R4-1 过严红修复）" {
  mkfile "sub/clean.sh" "echo clean\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单（空）\n"
  stage "sub/clean.sh" "$ALLOW_REL"
  # 提交进 index（建立 blob），再从磁盘删（不 git rm ⇒ 删除态未 staged）
  git -C "$FIXTURE" commit -qm base
  rm -f "$FIXTURE/sub/clean.sh"

  local override="$FIXTURE/empty-allowlist.txt"
  printf '# 空覆盖清单\n' > "$override"

  run --separate-stderr run_sut_override "$override"
  [ "$status" -eq 0 ]
  [[ "$output" == *"不可读候选 0 个"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
  # 磁盘缺失但 index 侧可读的提示行（实现选择打印则断言；若静默兜底也接受）
  [[ "$output" == *"磁盘缺失但 index 侧可读"* ]]
}

@test "T-FIX-11②：同删除态但 index 版本含泄漏 ⇒ rc≠0 且「清单外命中 [1-9]」（内容面未被跳过）" {
  mkfile "sub/leak.sh" "echo ${PROBE}/leak.txt\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单（空，泄漏须判红）\n"
  stage "sub/leak.sh" "$ALLOW_REL"
  git -C "$FIXTURE" commit -qm base
  rm -f "$FIXTURE/sub/leak.sh"

  local override="$FIXTURE/empty-allowlist.txt"
  printf '# 空覆盖清单\n' > "$override"

  run --separate-stderr run_sut_override "$override"
  [ "$status" -ne 0 ]
  # 内容面必须仍被 index 侧 git grep --cached 扫描并打印非零命中
  [[ "$output" =~ 清单外命中\ [1-9] ]]
}

@test "T-FIX-11③：gitlink 候选（mode 160000 无 blob）⇒ rc≠0（真正不可读仍 fail-closed）" {
  mkfile "base.sh" "echo base\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单（空）\n"
  stage "base.sh" "$ALLOW_REL"
  git -C "$FIXTURE" commit -qm base
  local sha
  sha="$(git -C "$FIXTURE" rev-parse HEAD)"
  # 加入 gitlink 候选（git cat-file -t :submod => commit，非 blob）
  git -C "$FIXTURE" update-index --add --cacheinfo 160000,"$sha",submod

  local override="$FIXTURE/empty-allowlist.txt"
  printf '# 空覆盖清单\n' > "$override"

  run --separate-stderr run_sut_override "$override"
  [ "$status" -ne 0 ]
}

# ============================================================================
# T-FIX-17（R5-15 🟡 · R5-16 🟡）：磁盘侧检索隔离候选路径 + rev 面批量化
# 候选名形似 grep 选项（-q / -v）必须真扫不塌缩；扫描面计数自证；rev 计时；
# 反向控制（摘掉 -e/-- 保护 ⇒ 腿① 转红）。
# 探针拼接构造（L-137）；夹具 mktemp 隔离。
# ============================================================================

# 前提断言辅助（TD-088 同族教训：只 grep 报文不算，必须断言 $status + 前提状态）。
# 在夹具仓内 `git add -- ./-q`（文件名以 - 开头），git ls-files -z 仍会输出它。

@test "T-FIX-17①：候选名 -q 且 index + 工作树各一处泄漏 ⇒ rc=1 且两处均被归因（fail-open 修复）" {
  # 前提：候选含名为 -q 的文件，且其内容含真泄漏探针（index 与工作树同内容）。
  mkfile "$ALLOW_REL" "# 夹具允许清单（空）\n"
  printf '泄漏点: %s/secret.txt\n' "$PROBE" > "$FIXTURE/-q"
  mkfile "zz_control.txt" "泄漏点: ${PROBE}/secret.txt\n"
  # git add -- ./-q：文件名以 - 开头时必须用 -- 终止
  git -C "$FIXTURE" add -- "./-q" "./zz_control.txt" "$ALLOW_REL"

  # 前提断言：候选含 -q 且其内容含探针
  git -C "$FIXTURE" ls-files -z | grep -qzxFe '-q'
  [ "$(git -C "$FIXTURE" show :'-q')" = "泄漏点: ${PROBE}/secret.txt" ]

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  # -q 的泄漏必须被归因（fail-open 修复：旧实现静默放行 -q）
  [[ "$output" == *"-q:1"* ]]
  # zz_control 的泄漏也必须被归因（扫描面不塌缩）
  [[ "$output" == *"zz_control.txt:1"* ]]
  # 扫描面未塌缩：实际扫描 ≥ 2（-q + zz_control，自排除 SUT/allowlist 不计）
  local scanned
  scanned=$(printf '%s\n' "$output" | grep -oE '实际扫描[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  [ "${scanned:-0}" -ge 2 ]
}

@test "T-FIX-17②：候选名 -q 干净 + 其他候选含磁盘侧泄漏 ⇒ 泄漏仍被检出（扫描面不塌缩）+ 自证 实际扫描 == 候选 - 不可读" {
  # 关键：-q 内容干净（无泄漏），zz_control 含泄漏且只在磁盘（index 干净）。
  # 旧实现：-q 被当 grep 选项吞 stdin ⇒ zz_control 从未被读 ⇒ 扫描面塌缩 + rc=0 假绿。
  mkfile "$ALLOW_REL" "# 夹具允许清单（空）\n"
  printf 'clean line no probe\n' > "$FIXTURE/-q"
  mkfile "zz_control.txt" "clean control\n"
  git -C "$FIXTURE" add -- "./-q" "./zz_control.txt" "$ALLOW_REL"
  git -C "$FIXTURE" commit -qm base
  # 磁盘侧改 zz_control 加泄漏（不 add ⇒ index 仍干净，只有磁盘侧有泄漏）
  printf '泄漏点: %s/secret.txt\n' "$PROBE" > "$FIXTURE/zz_control.txt"

  # 前提断言：候选含 -q（干净）；zz_control 磁盘含探针但 index 不含
  git -C "$FIXTURE" ls-files -z | grep -qzxFe '-q'
  [ "$(git -C "$FIXTURE" show :'-q')" = "clean line no probe" ]
  [ "$(git -C "$FIXTURE" show :'zz_control.txt')" = "clean control" ]
  grep -qFe "${PROBE}/" "$FIXTURE/zz_control.txt"

  local override="$FIXTURE/empty-allowlist.txt"
  printf '# 空覆盖清单\n' > "$override"

  run --separate-stderr run_sut_override "$override"
  [ "$status" -eq 1 ]
  # zz_control 磁盘侧泄漏必须被检出（扫描面不塌缩）
  [[ "$output" == *"zz_control.txt:1"* ]]
  # 自证一致性：实际扫描 == 候选 - 自排除（不可读应为 0）
  local scanned cand skipped unread
  scanned=$(printf '%s\n' "$output" | grep -oE '实际扫描[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  cand=$(printf '%s\n' "$output" | grep -oE '候选文件[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  skipped=$(printf '%s\n' "$output" | grep -oE '自排除[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  unread=$(printf '%s\n' "$output" | grep -oE '不可读候选[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1)
  [ "${unread:-0}" -eq 0 ]
  [ "$((scanned + skipped))" -eq "${cand}" ]
}

@test "T-FIX-17③：rev 形态计时 5 次 CHECK_REV=HEAD 实测均 ≤5 s（R5-16 批量化回到预算内）" {
  # 最小夹具仓：3 个候选（SUT + allowlist + 一个含探针的 blob），避免受本仓规模影响。
  mkfile "$ALLOW_REL" "# 夹具允许清单（空）\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}/secret.txt\n"
  stage "$ALLOW_REL" "probe.txt"
  git -C "$FIXTURE" commit -qm base
  local head
  head="$(git -C "$FIXTURE" rev-parse HEAD)"

  # warm-up 1 次（不在计时内）
  ( cd "$FIXTURE" && CHECK_REV="$head" bash "$SUT_REL" >/dev/null 2>&1 ) || true

  local t max=0 sum=0 i
  for i in 1 2 3 4 5; do
    # bash builtin time 输出 `real\t0m0.0123s`（含 m 前缀与 s 后缀）；awk 取第 2 字段
    # 并剥 `m`/`s` 后转秒。兼容 BSD time 与 GNU time。
    t=$( { time ( cd "$FIXTURE" && CHECK_REV="$head" bash "$SUT_REL" >/dev/null 2>&1 ) ; } 2>&1 \
        | awk '/^real/ {v=$2; sub(/^0m/,"",v); sub(/m.*/,"",v); sub(/s$/,"",v); print v}' )
    [ -n "$t" ] || t=99
    sum=$(awk "BEGIN{print $sum + $t}")
    max=$(awk "BEGIN{print ($t > $max) ? $t : $max}")
    # 每次必须 ≤ 5.000 s（判据 ③）
    awk "BEGIN{exit !($t <= 5.000)}"
    [ $? -eq 0 ] || { echo "# iter $i: ${t}s > 5.000s (FAIL)" >&3; return 1; }
  done
  local mean pct
  mean=$(awk "BEGIN{print $sum / 5}")
  pct=$(awk "BEGIN{printf \"%.1f\", $max / 5.0 * 100}")
  echo "# T-FIX-17③ rev 计时: max=${max}s mean=${mean}s 预算5.000s max=${pct}% (5/5 ≤ 5.000s ✅)" >&3
}

@test "T-FIX-17④：反向控制——摘掉磁盘侧 -e/-- 保护 + 还原候选循环共用 stdin ⇒ 腿①必须转红（还原后转回 ok）" {
  # 本例验证「-e/-- 保护 + 独立 FD」是 fail-closed 的必要条件：临时同时摘掉两道防线
  # ⇒ 扫描面塌缩重现（-q 被 grep 吞 stdin ⇒ zz_control 漏报 ⇒ rc=0 假绿）。
  # 与 T-FIX-17② 同夹具（-q 干净 + zz_control 磁盘侧泄漏），SUT 被临时篡改。
  mkfile "$ALLOW_REL" "# 夹具允许清单（空）\n"
  printf 'clean line no probe\n' > "$FIXTURE/-q"
  mkfile "zz_control.txt" "clean control\n"
  git -C "$FIXTURE" add -- "./-q" "./zz_control.txt" "$ALLOW_REL"
  git -C "$FIXTURE" commit -qm base
  # 磁盘侧改 zz_control 加泄漏（不 add ⇒ index 仍干净，只有磁盘侧有泄漏）
  printf '泄漏点: %s/secret.txt\n' "$PROBE" > "$FIXTURE/zz_control.txt"

  # 前提断言：候选含 -q（干净）；zz_control 磁盘含探针但 index 不含
  git -C "$FIXTURE" ls-files -z | grep -qzxFe '-q'
  [ "$(git -C "$FIXTURE" show :'-q')" = "clean line no probe" ]
  [ "$(git -C "$FIXTURE" show :'zz_control.txt')" = "clean control" ]
  grep -qFe "${PROBE}/" "$FIXTURE/zz_control.txt"

  local override="$FIXTURE/empty-allowlist.txt"
  printf '# 空覆盖清单\n' > "$override"

  # —— 还原前基线：受保护 SUT 应判红（zz_control 磁盘侧泄漏被检出）——
  run --separate-stderr run_sut_override "$override"
  [ "$status" -eq 1 ]
  [[ "$output" == *"zz_control.txt:1"* ]]

  # —— 篡改：① 磁盘侧 grep 去掉 -e/-- 保护；② 候选循环还原共用 stdin（done < $TMP，去掉 <&3/3<）——
  local sut_tampered="$FIXTURE/sut-tampered.sh"
  sed -e 's/grep -naE -e "\$PAT" -- "\$file"/grep -naE "$PAT" "$file"/' \
      -e 's/while IFS= read -r -d '"'"''"'"''"'"' f <&3; do/while IFS= read -r -d '"'"''"'"''"'"' f; do/' \
      -e 's/done 3< "\$TMP_CANDIDATES"/done < "\$TMP_CANDIDATES"/' \
      "$SUT_SRC" > "$sut_tampered"

  # 跑篡改版
  run --separate-stderr bash -c "cd '$FIXTURE' && FLOW_KIT_PRIVACY_ALLOWLIST='$override' bash '$sut_tampered'"
  # 反向控制：摘掉两道防线后，-q 被 grep 吞 stdin ⇒ zz_control 从未被读 ⇒ 漏报。
  # 判据：篡改版不再归因 zz_control.txt（扫描面塌缩的证据），且实际扫描 < 候选数。
  [[ "$output" != *"zz_control.txt:1"* ]]
  echo "# T-FIX-17④ 反向控制：摘掉 -e/-- + 独立 FD ⇒ zz_control 磁盘泄漏漏报（扫描面塌缩 ✅ 证据）" >&3
}

# ============================================================================
# T-FIX-24（R5-5 处置订正 · 豁免面冻结常设腿 · 判别力优先）
# SELF_EXCLUDE 成员集合精确等于冻结 6 条（= 本脚本 + 两份允许清单 +
# INDEPENDENT-REVIEW-1/2/3.md）；此后新增的审查档一律不豁免 —— 它们是脱敏
# 泄漏的第一现场，必须由本门禁就地判红并 de-shape（L-149 / TD-054 / T13 / T17）。
# 判别力：在 SUT 副本上注入伪条目（形似新增审查档）⇒ 集合膨胀 ⇒ not ok；
# 去行 ⇒ 复绿。两态同例内完成（注入态断言膨胀、去行态断言复原）。
# ============================================================================

@test "T-FIX-24：SELF_EXCLUDE 成员集合精确等于冻结 6 条；副本注入伪条目（新增审查档）⇒ 膨胀 not ok，去行复绿（豁免面冻结 · L-149/TD-054）" {
  # 冻结集（顺序无关，按排序后比对）。
  local frozen
  frozen="$(printf '%s\n' \
    'flow-kit-bundle/flow-kit/reference/check-path-privacy.sh' \
    'flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt' \
    '.specs/health-fix-2026-09b/path-privacy-allowlist.txt' \
    '.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md' \
    '.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md' \
    '.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-3.md' \
    | sort)"

  # 从 SUT 源码提取 SELF_EXCLUDE 块成员（剥首尾引号行、去空白、排序）。
  extract_self_exclude() {
    sed -n '/^SELF_EXCLUDE=/,/^'"'"'$/p' "$1" \
      | sed '1d;$d' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
      | grep -v '^$' \
      | sort
  }

  # 基线态：原 SUT 的 SELF_EXCLUDE 集合 = 冻结集（精确等于 6 条）。
  local actual_base
  actual_base="$(extract_self_exclude "$SUT_SRC")"
  [ "$actual_base" = "$frozen" ]
  # 成员数精确为 6（防膨胀/收窄的标量断言）。
  local n_base
  n_base="$(printf '%s\n' "$actual_base" | wc -l | tr -d ' ')"
  [ "$n_base" -eq 6 ]

  # —— 判别力实证（在副本上注入伪条目 · L-137 拼接构造，不含可运行整串）——
  local sut_copy="$FIXTURE/sut-copy.sh"
  cp -- "$SUT_SRC" "$sut_copy"

  # 伪条目形似新增审查档路径（用变量拼接，仓库文件内不出现可运行整串）。
  local ir_base=".specs/health-fix-2026-09b/INDEPENDENT-REVIEW"
  local fake_entry="${ir_base}-4.md"

  # 注入伪条目：在 SELF_EXCLUDE 块的结束引号行前插入。
  local tmp_inject
  tmp_inject="$(mktemp "${TMPDIR:-/tmp}/fk-inject.XXXXXX")"
  awk -v fake="$fake_entry" '
    /^SELF_EXCLUDE=/ { in_block=1 }
    in_block && /^'"'"'$/ { print fake; in_block=0 }
    { print }
  ' "$sut_copy" > "$tmp_inject"
  mv -- "$tmp_inject" "$sut_copy"

  # 前提断言：注入成功（副本含伪条目；原 SUT 不含）。
  grep -qF "$fake_entry" "$sut_copy"
  ! grep -qF "$fake_entry" "$SUT_SRC"

  # 注入态：副本 SELF_EXCLUDE 集合 ≠ 冻结集 ⇒ not ok（判别力：膨胀即红）。
  local actual_injected n_injected
  actual_injected="$(extract_self_exclude "$sut_copy")"
  n_injected="$(printf '%s\n' "$actual_injected" | wc -l | tr -d ' ')"
  [ "$n_injected" -eq 7 ]
  [ "$actual_injected" != "$frozen" ]

  # —— 复原证据：从副本移除伪条目后，集合重新等于冻结集 ⇒ 复绿 ——
  local tmp_restored
  tmp_restored="$(mktemp "${TMPDIR:-/tmp}/fk-restore.XXXXXX")"
  grep -vF "$fake_entry" "$sut_copy" > "$tmp_restored"
  mv -- "$tmp_restored" "$sut_copy"

  # 前提断言：伪条目已移除。
  ! grep -qF "$fake_entry" "$sut_copy"

  local actual_restored n_restored
  actual_restored="$(extract_self_exclude "$sut_copy")"
  n_restored="$(printf '%s\n' "$actual_restored" | wc -l | tr -d ' ')"
  [ "$n_restored" -eq 6 ]
  [ "$actual_restored" = "$frozen" ]
}

# ============================================================================
# T04（health-fix-2026-09c · AC-3）：PAT 路径段边界放宽回归
# PAT 由「必须尾斜杠」放宽为路径段边界形态 —— 裸 /home/<name>（无尾斜杠）在
# 名后为非路径段字符（行尾/引号/空白/斜杠等）时必须命中；占位名（含裸形态）
# 不得误报。PROBE 自本节起为裸形态（见 setup :33 修正说明）——既有用例已改为
# `${PROBE}/…` 显式拼尾斜杠，保持原被测字符串不变。
# 用例名统一带 `T04:` 前缀（verify 计数锚：`grep -c '@test .*T04:'` 今日 0→≥1）。
# ============================================================================

@test "T04: 裸 /home/<realname>（无尾斜杠 · 行尾）⇒ 命中 rc=1 且归因 file:line" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe_bare.txt" "泄漏点: ${PROBE}\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe_bare.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"清单外命中 1 条"* ]]
  [[ "$output" == *"probe_bare.txt:1"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "T04: 裸 /home/<realname> 双引号/反引号包裹（非行尾边界）⇒ 同样命中 rc=1" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  printf 'doc "%s" and `%s` two forms\n' "$PROBE" "$PROBE" > "$FIXTURE/probe_quote.txt"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe_quote.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  # 同行两个命中按 file:line 记 1 条（行粒度归因）
  [[ "$output" == *"清单外命中 1 条"* ]]
  [[ "$output" == *"probe_quote.txt:1"* ]]
}

@test "T04: 裸占位名不误报（user/me/username/your-user 行尾 + <user> 尖括号形态）⇒ rc=0" {
  mkfile "docs/notes.md" "copy to /home/user\n占位: /home/<user>/proj\nhome 目录: /home/me\n教程写法 /home/username 与 /home/your-user\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"命中合计 0 条"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

@test "T04: 路径段边界形态：同前缀长段名（-doc）整段消费、点号后缀截断边界 ⇒ 均命中 rc=1" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe_edge.txt" "长段名: ${PROBE}-doc 旁\n点号边界: ${PROBE}.txt 尾\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe_edge.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"清单外命中 2 条"* ]]
  [[ "$output" == *"probe_edge.txt:1"* ]]
  [[ "$output" == *"probe_edge.txt:2"* ]]
}
