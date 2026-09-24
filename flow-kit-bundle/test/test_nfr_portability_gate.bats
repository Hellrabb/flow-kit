#!/usr/bin/env bats
# test_nfr_portability_gate.bats — check-nfr-portability（Makefile 目标）常设回归网
#                                   （TD-053 收敛 · AC-8 · NFR 兼容性判据）
#
# 为什么存在（TD-053）：NFR 兼容性判据是三态判据，rc=3 的语义是「未验证 ≠ 通过」。
#   此前只有 change 期判据覆盖它；归档后若有人把「空变更集 ⇒ rc=3」退化成 rc=0、
#   把包装层的 3 泄漏成非零、把合规惯用法（stat -c … || stat -f …）判红、或把
#   注释行也纳入受检面，`make check` 仍会全绿（门禁只在变更集上跑）。
#   本文件把这些语义固化为常设判据（三态 + 包装映射）。
#
# 活性（为什么不是假绿）：夹具在**运行时**复制仓内真实 Makefile ⇒ 目标语义被改坏时
#   本文件的断言会转红（含「包装层必须保留 SKIP 且不得打印 ✅」这类反向断言）。
#
# 夹具隔离：夹具是 ${TMPDIR:-/tmp} 下 mktemp -d + git init 的独立仓，teardown 清理；
#   不触碰工作树（受检面 git diff / git ls-files 全在夹具仓内）。
#
# 三态观测口径：make 会把 recipe 内的退出码掩盖（recipe 各分支一律 exit 0），
#   故真实 rc 由该目标的**契约通道** $NFR_RC_FILE 回传（见 Makefile
#   check-nfr-portability-internals 的 _write_rc），本文件据此断言 rc ∈ {0,1,3}。
#
# 脱敏（L-129）：本文件不含真实账号路径形态；一切路径以 $FIXTURE 变量拼接。
#
# 断言约定（沿用 test_l3_review_defects_2026_09.bats 的 L3 04:42 教训：`run` 默认把
#   stderr 合进 $output 会造成假绿）：全文件统一 `run --separate-stderr`，
#   并**分通道**断言——SKIP/✅ 的判定结论走 stdout，违规归因走 stderr。
#   该 flag 需要 bats ≥ 1.5，故下一行声明最低版本。
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-nfr-gate.XXXXXX")"
  FIXTURE="$TEST_TMPDIR/repo"
  RC_FILE="$TEST_TMPDIR/nfr.rc"

  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容 test/ 与 bundle 内镜像）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  MAKEFILE_SRC="$d/Makefile"

  mkdir -p "$FIXTURE"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email "fixture@example.invalid"
  git -C "$FIXTURE" config user.name "fixture"
  # 运行时复制真实 Makefile（活性关键）
  cp -- "$MAKEFILE_SRC" "$FIXTURE/Makefile"
  printf '#!/bin/bash\nt=$(mktemp)\n' > "$FIXTURE/seed.sh"
  git -C "$FIXTURE" add -- Makefile seed.sh
  git -C "$FIXTURE" commit -q -m base
  BASE_SHA="$(git -C "$FIXTURE" rev-parse HEAD)"

  seed_append() { printf '%s\n' "$1" >> "$FIXTURE/seed.sh"; }
  run_internals() {
    rm -f "$RC_FILE"
    env NFR_RC_FILE="$RC_FILE" make --no-print-directory -C "$FIXTURE" \
      check-nfr-portability-internals FLOW_KIT_CHANGE_BASE="$BASE_SHA"
  }
  run_wrapper() {
    make --no-print-directory -C "$FIXTURE" \
      check-nfr-portability FLOW_KIT_CHANGE_BASE="$BASE_SHA"
  }
  internals_rc() { cat "$RC_FILE" 2>/dev/null || printf 'MISSING'; }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "空变更集（base=HEAD，无 .sh 改动/新增）⇒ 内部 rc=3 且 stdout 含 SKIP:（未验证 ≠ 通过）" {
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "3" ]
  [[ "$output" == *"SKIP:"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "新增行含 sed -i ⇒ 内部 rc=1 且 stderr 归因到 file:line" {
  seed_append "sed -i 's/a/b/' \"\$t\""
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" =~ seed\.sh:3: ]]
  [[ "$stderr" == *"sed -i"* ]]
}

@test "合规惯用法 stat -c … || stat -f … ⇒ 不误报（内部 rc=0）" {
  seed_append 't=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)'
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"✅ NFR 兼容性判据通过"* ]]
}

@test "整行注释里的 sed -i ⇒ 不误报（内部 rc=0）" {
  seed_append "# 说明：不要写 sed -i（注释行不计入受检面）"
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "0" ]
  [[ "$output" == *"✅ NFR 兼容性判据通过"* ]]
}

@test "未跟踪新增 .sh 含 GNU-only 构造 ⇒ 内部 rc=1（NEWF 面）" {
  mkdir -p "$FIXTURE/extra"
  printf '#!/bin/bash\nmapfile -t xs < <(printf "a\\n")\n' > "$FIXTURE/extra/new.sh"
  run --separate-stderr run_internals
  [ "$status" -eq 0 ]
  [ "$(internals_rc)" = "1" ]
  [[ "$stderr" =~ extra/new\.sh:2: ]]
  [[ "$stderr" == *"mapfile"* ]]
}

@test "包装层把内部 rc=3 映射为 exit 0 且 stdout 保留 SKIP:（SKIP ≠ PASS）" {
  run --separate-stderr run_wrapper
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP:"* ]]
  [[ "$output" != *"✅"* ]]
}

@test "违规变更集上包装层不放过：make 非零退出且 stderr 保留 file:line 归因" {
  seed_append "sed -i 's/a/b/' \"\$t\""
  run --separate-stderr run_wrapper
  # 两层语义都锁住：包装层 recipe 自己 exit 1（make 记为「Error 1 / 错误 1」），
  # make 再把 recipe 失败包装成自己的 exit 2 ⇒ 外部观测量是 2，绝不为 0。
  # 若有人把 rc=1 也映射成 exit 0（与 rc=3 的 SKIP 通道混同），本用例转红。
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"Error 1"* || "$stderr" == *"错误 1"* ]]
  [[ "$stderr" =~ seed\.sh:3: ]]
}
