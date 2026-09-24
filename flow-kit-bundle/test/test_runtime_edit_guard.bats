#!/usr/bin/env bats
# test_runtime_edit_guard.bats — runtime-edit-guard.sh 常设回归网（TD-053 收敛 · AC-1）
#
# 为什么存在（TD-053）：AC-1 的守卫修复（路径解析 fail-closed、`~user`/空串拒绝、
#   维护源存在才 deny 的 fail-open 边界）此前只有 change 期判据覆盖。归档后若有人
#   把这几个态改坏（例如把相对路径重新放行、或把「维护源缺失 ⇒ 放行」去掉，
#   让非 flow-kit 的 user-level 配置被误拦），`make check` 仍可能全绿。
#   本文件把六个态固化为常设双态判据。
#
# 活性（为什么不是假绿）：setup 在**运行时**把仓内真实 hook 复制进夹具再驱动
#   ⇒ hook 被改坏、或被打成恒绿桩（exit 0）时，本文件的 exit 2 断言会转红。
#
# 夹具隔离：夹具建在 ${TMPDIR:-/tmp} 下（mktemp -d），teardown 清理；
#   不触碰工作树。**夹具自带 HOME**（`HOME=$TEST_TMPDIR/home`）⇒ 用例只引用
#   夹具内的 ~/.claude 路径，绝不读写真实家目录。维护源目录（hooks/stop、
#   skills/flow）默认**不预建**，「维护源在位」态的用例自己落地。
#
# 脱敏（L-129）：本文件不含真实账号路径形态；家目录一律以 $HOME 变量拼接。
#
# 断言约定（沿用 test_l3_review_defects_2026_09.bats 的 L3 04:42 教训：`run` 默认把
#   stderr 合进 $output 会造成假绿）：全文件统一 `run --separate-stderr`。
#   hook 的 deny 报文按契约走 stderr（exit 2 + 报文），故报文断言显式用 $stderr；
#   放行态断言两个流都不含 deny 报文。该 flag 需要 bats ≥ 1.5，故下一行声明最低版本。
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-reg.XXXXXX")"
  FIXTURE="$TEST_TMPDIR/proj"
  HOME_DIR="$TEST_TMPDIR/home"
  SUT_REL="flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh"
  SRC_REL="flow-kit-bundle/hooks/stop/x.sh"
  SKILL_SRC_REL="flow-kit-bundle/skills/flow/x"

  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容 test/ 与 bundle 内镜像）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  SUT_SRC="$d/$SUT_REL"

  # 夹具项目根（含 flow-kit-bundle/ ⇒ hook 的 project_root 解析落在此）+ 夹具 HOME
  mkdir -p "$FIXTURE/$(dirname "$SUT_REL")"
  mkdir -p "$HOME_DIR/.claude/hooks/stop" "$HOME_DIR/.claude/skills/flow"
  # 运行时复制真实 hook（活性关键：恒绿桩会在此被吃到）
  cp -- "$SUT_SRC" "$FIXTURE/$SUT_REL"
  # 被编辑的运行时副本（hook 只读路径字符串，不读写它；此处仅为形态真实）
  printf '#!/bin/bash\n' > "$HOME_DIR/.claude/hooks/stop/x.sh"

  json() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
  guard() { printf '%s' "$1" | ( cd "$FIXTURE" && HOME="$HOME_DIR" bash "$SUT_REL" ); }
  mkfile() { mkdir -p "$FIXTURE/$(dirname "$1")"; printf '%b' "$2" > "$FIXTURE/$1"; }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "Write + 相对路径 ⇒ exit 2 且报文含「无法解析为绝对路径」" {
  run --separate-stderr guard "$(json Write "hooks/stop/x.sh")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"无法解析为绝对路径"* ]]
}

@test "Write + ~user 形态 ⇒ exit 2（fail-closed，不做 passwd 查询）" {
  run --separate-stderr guard "$(json Write "~someone/x.sh")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"无法解析为绝对路径"* ]]
}

@test "Write + 空 file_path ⇒ exit 2" {
  run --separate-stderr guard "$(json Write "")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"为空串"* ]]
}

@test "非写工具 Bash ⇒ exit 0（不触发）" {
  run --separate-stderr guard "$(json Bash "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "非写工具 Read（路径命中运行时副本）⇒ exit 0" {
  run --separate-stderr guard "$(json Read "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "绝对路径命中 ~/.claude/hooks + 维护源在位 ⇒ exit 2 且报文含维护源路径" {
  mkfile "$SRC_REL" "#!/bin/bash\n"
  run --separate-stderr guard "$(json Write "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"维护源在"* ]]
  [[ "$stderr" == *"$FIXTURE/$SRC_REL"* ]]
}

@test "~/ 展开分支命中 ~/.claude/skills + 维护源在位 ⇒ exit 2" {
  mkfile "$SKILL_SRC_REL" "fixture skill\n"
  run --separate-stderr guard "$(json Write "~/.claude/skills/flow/x")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"维护源在"* ]]
  [[ "$stderr" == *"$FIXTURE/$SKILL_SRC_REL"* ]]
}

@test "同一路径但维护源缺失 ⇒ exit 0（fail-open 边界：非 flow-kit 的 user-level 配置）" {
  run --separate-stderr guard "$(json Write "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "~/.claude 之外的合法绝对路径 ⇒ exit 0（绝对值校验不误拒）" {
  run --separate-stderr guard "$(json Write "$FIXTURE/other/notes.md")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}
