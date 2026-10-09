#!/usr/bin/env bats
# test_hookspath_guard.bats — R1-④ · core.hookspath 架空守卫
#（health-fix-2026-09c 阶段 6 L2 R1 根因 / sync-hooks.sh --hookspath-guard）
#
# 背景（2026-10-09 事故）：.git/config 出现 `core.hookspath=`（空字符串）——git 静默
# 不执行本仓任何 hooks，pre-push 隐私门禁对 36fc664 带毒推送零拦截；镜像逐字节一致
# （sync-hooks.sh 既有判据全绿）但 git 根本不会调用它们。守卫补「一致 ≠ 生效」缺口：
# 配置存在（含空串）即红；unset = 默认 .git/hooks（= install_hooks.sh 安装位）。
#
# 沙箱：临时 git init 仓 + sync-hooks.sh 单文件拷贝（守卫自检出口置于源目录检查前，
# 不依赖 flow-kit-bundle/hooks 树——见 sync-hooks.sh 守卫块注释）。
# 镜像：flow-kit-bundle/test/test_hookspath_guard.bats 内容逐字节相同（手动双写）。

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  local d="$TEST_ROOT"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  REAL_ROOT="$d"
  SYNC_HOOKS="$REAL_ROOT/sync-hooks.sh"
  TMP_DIR="$BATS_TMPDIR/hsp-guard-$$"
  mkdir -p "$TMP_DIR"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# _mk_repo — 临时 git 仓 + sync-hooks.sh 拷贝；echo 仓路径。
_mk_repo() {
  local repo="$TMP_DIR/repo-$1"
  git init -q "$repo"
  cp "$SYNC_HOOKS" "$repo/"
  echo "$repo"
}

@test "hookspath 守卫: unset → exit 0 + ✅ 报文" {
  repo="$(_mk_repo unset)"
  run bash "$repo/sync-hooks.sh" --hookspath-guard
  [ "$status" -eq 0 ]
  grep -q '✅ core.hookspath 未设置' <<<"$output"
}

@test "hookspath 守卫: 空串（2026-10-09 事故形态）→ exit 1 + ❌ + 修复指引" {
  repo="$(_mk_repo empty)"
  git -C "$repo" config core.hookspath ""
  run bash "$repo/sync-hooks.sh" --hookspath-guard
  [ "$status" -eq 1 ]
  grep -q "core.hookspath=''" <<<"$output"
  grep -q '架空' <<<"$output"
  grep -q 'git config --unset core.hookspath' <<<"$output"
}

@test "hookspath 守卫: 外部目录 → exit 1（合法值形态同样架空本仓 hooks）" {
  repo="$(_mk_repo foreign)"
  git -C "$repo" config core.hookspath /foreign/hooks-dir
  run bash "$repo/sync-hooks.sh" --hookspath-guard
  [ "$status" -eq 1 ]
  grep -q '/foreign/hooks-dir' <<<"$output"
}

@test "hookspath 守卫: 真仓回归锁 → exit 0（事故形态不得在本仓复发）" {
  run bash "$SYNC_HOOKS" --hookspath-guard
  [ "$status" -eq 0 ]
  grep -q '✅' <<<"$output"
}
