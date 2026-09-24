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
