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
  # 拼接构造的真名探针（与既有占位符不同形）；本文件里不出现其字面
  PROBE="/home/""zz-path-pr""obe/"

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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
  mkfile "$ALLOW_REL" "# 空基线：仅注释\n\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 1 ]
  [[ "$output" == *"允许清单 0 条"* ]]
  [[ "$output" == *"清单外命中 1 条"* ]]
  [[ "$output" == *"probe.txt:1"* ]]
}

@test "命中落在允许清单内 ⇒ rc=0（只暴露不阻塞）" {
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
  mkfile "$ALLOW_CHANGE_REL" "probe.txt:1 # 夹具登记\n"
  stage "probe.txt" "$ALLOW_CHANGE_REL"

  run --separate-stderr run_sut
  [ "$status" -eq 0 ]
  [[ "$output" == *"允许清单来源: $ALLOW_CHANGE_REL"* ]]
  [[ "$output" == *"清单外命中 0 条"* ]]
}

@test "常设与 change 副本皆在 ⇒ 常设优先（读序不回退）" {
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
  mkfile "$ALLOW_REL" "# 夹具允许清单\n"
  stage "docs/notes.md" "probe.txt" "$ALLOW_REL"
  # 拆掉夹具的 .git ⇒ 非 git 目录（候选枚举失败 ⇒ 0 候选面）
  rm -rf "$FIXTURE/.git"

  run --separate-stderr run_sut
  [ "$status" -ne 0 ]
}

@test "F2 坏态②：git 仓但 index 为空（未 add）+ 真泄漏 ⇒ rc≠0" {
  mkfile "docs/notes.md" "纯文本，无本机路径\n"
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  printf 'BIN\x00%s\x00\n' "${PROBE}" > "$FIXTURE/bin.dat"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
  mkfile "probe.txt" "泄漏点: ${PROBE}host\n"
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
