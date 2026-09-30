#!/usr/bin/env bats
# test_pre_push_gate.bats — pre-push flock 并发闸行为级判别（AC-17①/② · T09）
# M11 承接（MINOR-DEFERRED R11 → T09）：裸仓并发双 dry-run 夹具落点。
#
# 判别式（防闸被静默移除/回退）：
#   - 静态腿：bash -n + flock 字面在 pre-push.sh 内（与 T09 verify 锚同源）。
#   - 并发腿（AC-17②）：mktemp -d 建裸仓 + worktree 夹具；Makefile check 目标
#     写 start/end 标记（sleep 1 拉开观测窗）⇒ 两并发 git push --dry-run 的
#     hook 实例未串行化时标记必交错 start/start/end/end；flock 闸生效则严格
#     start/end/start/end 成对嵌套（两推程谁先抢到锁不定，但两种次序的标记
#     序列同形，断言与次序无关）。
#   - 超时腿：外部占锁 + FLOW_KIT_PRE_PUSH_LOCK_WAIT=1 ⇒ fail-closed rc≠0
#     且报文指名锁路径（默认 600s 不可测，env 覆盖为可测小值）。
# 夹具纪律（F6 范式）：mktemp -d/-p 唯一路径 + 用完 rm -rf；不占常设文件、
# 并发双跑不互踩。污染断言只查夹具 worktree——真仓有并行任务在途，
# 全树断言会假红（同 test_check_gate_sync.bats T03 AC-2 纪律）。
# 隐私扫描腿不在本文件：夹具无随包 reference/ ⇒ hook 走「未找到可用的路径
# 隐私检查器：跳过内容扫描」兼容路径（rc 不变）。本文件只辖并发闸；
# 扫描行为由 test_pre_push_behavior.bats / test_path_privacy_gate.bats 辖。

bats_require_minimum_version 1.5.0

setup() {
  # 向上找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  FK_ROOT="$d"
  HOOK_SRC="$FK_ROOT/flow-kit-bundle/hooks/pre-push/pre-push.sh"
  # 固定桩 git 身份（夹具仓内 commit 用）
  export GIT_AUTHOR_NAME="fixture"
  export GIT_AUTHOR_EMAIL="fixture@example.invalid"
  export GIT_COMMITTER_NAME="fixture"
  export GIT_COMMITTER_EMAIL="fixture@example.invalid"
}

# ── 夹具构造：裸仓 + worktree（薄壳换装，与真仓 .git/hooks/pre-push 同形态）──
# $1 = 观测窗日志路径（Makefile check 目标写 start/end 标记；空 ⇒ check 空操作）
t09_make_fixture() {
  T09_SBX="$(mktemp -d "${TMPDIR:-/tmp}/t09pp-XXXXXX")"
  git init --bare -q "$T09_SBX/remote.git"
  git clone -q "$T09_SBX/remote.git" "$T09_SBX/wt" 2>/dev/null
  git -C "$T09_SBX/wt" config user.name "fixture"
  git -C "$T09_SBX/wt" config user.email "fixture@example.invalid"
  git -C "$T09_SBX/wt" config commit.gpgsign false
  printf '# t09 pre-push gate fixture\n' >"$T09_SBX/wt/README.md"
  if [ -n "${1:-}" ]; then
    # 观测窗：check 开始/结束各写一行标记，sleep 1 保证未串行化时必交错
    printf 'check:\n\t@printf "start\\n" >> %s\n\t@sleep 1\n\t@printf "end\\n" >> %s\n' \
      "$1" "$1" >"$T09_SBX/wt/Makefile"
  else
    printf 'check:\n\t@true\n' >"$T09_SBX/wt/Makefile"
  fi
  git -C "$T09_SBX/wt" add README.md Makefile
  git -C "$T09_SBX/wt" commit -qm "t09 fixture commit"
  # 薄壳换装：与真仓 .git/hooks/pre-push 同款形态（exec 真实 bundle 脚本）
  printf '#!/bin/bash\nexec bash "%s"\n' "$HOOK_SRC" >"$T09_SBX/wt/.git/hooks/pre-push"
  chmod +x "$T09_SBX/wt/.git/hooks/pre-push"
}

@test "AC-17①: pre-push.sh 语法有效且内置 flock 并发闸" {
  run bash -n "$HOOK_SRC"
  [ "$status" -eq 0 ]
  [ "$(grep -c flock "$HOOK_SRC")" -ge 1 ]
}

@test "AC-17②: 裸仓并发双 dry-run → 两推程串行化、双 rc=0、夹具树零改动" {
  local mlog
  mlog="$(mktemp "${TMPDIR:-/tmp}/t09mk.XXXXXX")"
  t09_make_fixture "$mlog"
  cd "$T09_SBX/wt"
  # 两并发 dry-run push（同一 worktree ⇒ 同一把 .git 锁；推不同 ref 避让 ref 级争用）
  ( git push --dry-run -q origin HEAD:refs/heads/p1 >"$T09_SBX/p1.out" 2>&1; echo $? >"$T09_SBX/p1.rc" ) &
  ( git push --dry-run -q origin HEAD:refs/heads/p2 >"$T09_SBX/p2.out" 2>&1; echo $? >"$T09_SBX/p2.rc" ) &
  wait
  # ① 两次 dry-run 各自 rc=0（AC-17 Then）
  [ "$(cat "$T09_SBX/p1.rc")" = "0" ]
  [ "$(cat "$T09_SBX/p2.rc")" = "0" ]
  # ② 串行化判读：4 行标记必须严格 start/end 成对嵌套
  #    （闸被移除 ⇒ 两 check 窗口交错 start/start/end/end ⇒ 本腿红）
  [ "$(cat "$mlog")" = "$(printf 'start\nend\nstart\nend')" ]
  # ③ 闸落痕：确定性锁文件在夹具 git-dir 内（每仓一把；内容恒空、残留无害）
  [ -f "$T09_SBX/wt/.git/flow-kit-pre-push.lock" ]
  # ④ C1 污染断言：夹具 worktree 零改动（tracked 干净 + 无未跟踪残留）
  run git status --porcelain
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  cd "$FK_ROOT"
  rm -rf "$T09_SBX" "$mlog"
}

@test "AC-17①: 锁被外部持有 + 等待超时 ⇒ fail-closed rc≠0 且指名锁路径" {
  t09_make_fixture ""
  cd "$T09_SBX/wt"
  local lock="$T09_SBX/wt/.git/flow-kit-pre-push.lock"
  # 外部持有者：占锁 5s，就绪后落 marker（确定性等持锁，不竞速时间片）
  ( exec 9>>"$lock"; flock -x 9 && : >"$T09_SBX/holder-ready"; sleep 5 ) &
  local holder=$!
  local i
  for i in {1..50}; do [ -f "$T09_SBX/holder-ready" ] && break; sleep 0.1; done
  [ -f "$T09_SBX/holder-ready" ]   # 前置自检：持有者确实已占锁（否则本腿空转）
  run env FLOW_KIT_PRE_PUSH_LOCK_WAIT=1 git push --dry-run origin HEAD:refs/heads/t1
  [ "$status" -ne 0 ]                                # fail-closed：闸超时必须拒绝
  [[ "$output" == *"并发闸超时"* ]]
  [[ "$output" == *"flow-kit-pre-push.lock"* ]]       # 报文指名锁路径
  kill "$holder" 2>/dev/null || true
  wait "$holder" 2>/dev/null || true
  cd "$FK_ROOT"
  rm -rf "$T09_SBX"
}
