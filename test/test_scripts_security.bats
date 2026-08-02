#!/usr/bin/env bats
# test_scripts_security.bats — L-064 安全注入回归 (superpowers-absorb-followup-1)
# 覆盖 REQUIREMENT AC-A1~A6

# 项目根（基于 test/ 目录位置推断）
PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/flow-kit-bundle/flow-kit/scripts"
FIXTURE_TASK="$BATS_TEST_DIRNAME/fixtures/security/TASK_sec.md"

# SEC 共享 fixture：临时 git 仓库（仅 commit msg 注入需要）
_setup_sec_repo() {
  local repo="$BATS_TMPDIR/flow-kit-sec-repo-$$"
  mkdir -p "$repo"
  cd "$repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name "test"
  echo "init" >README.md
  git add README.md
  git commit -q -m "init" >/dev/null 2>&1
  echo "second" >>README.md
  git add README.md
  echo "$repo"  # caller captures via $()
}

setup() {
  # 清理上轮残留
  rm -f /tmp/flow-kit-sec-test* 2>/dev/null || true
  rm -f /tmp/flow-kit-hijacked* 2>/dev/null || true
}

teardown() {
  rm -f /tmp/flow-kit-sec-test* 2>/dev/null || true
  rm -f /tmp/flow-kit-hijacked* 2>/dev/null || true
  # 清理本轮临时 repo
  if [ -n "${SEC_REPO:-}" ] && [ -d "$SEC_REPO" ]; then
    rm -rf "$SEC_REPO" 2>/dev/null || true
  fi
}

# ── AC-A1: shell 注入（commit msg）──
@test "SEC-1 commit msg 含 ';rm -rf /tmp/flow-kit-sec-test' 不被执行" {
  skip_if_no_review_package
  SEC_REPO="$(_setup_sec_repo)"
  cd "$SEC_REPO"
  # 构造恶意 commit msg
  git commit -q --allow-empty -m "feat;rm -rf /tmp/flow-kit-sec-test" >/dev/null 2>&1
  # 预置标记文件，看 review-package 跑完后是否被删
  touch /tmp/flow-kit-sec-test
  run bash "$SCRIPTS_DIR/review-package" HEAD~1 HEAD
  [ $status -eq 0 ]
  # 标记文件应仍存在（rm 未被执行）
  [ -f /tmp/flow-kit-sec-test ]
  # 输出中应包含恶意字符串的字面量（commit msg 字面回显）
  echo "$output" | grep -q "rm -rf /tmp/flow-kit-sec-test"
}

# ── AC-A2: subshell 展开（task-brief TASK.md name）──
@test "SEC-2 task-brief 不展开 '\$(touch /tmp/flow-kit-sec-test-2)'" {
  skip_if_no_task_brief
  run bash -c "awk -f '$SCRIPTS_DIR/task-brief' '$FIXTURE_TASK' T_sec > /tmp/sec-t2.out 2>&1; echo exit=\$?"
  # 标记文件不应被创建
  [ ! -f /tmp/flow-kit-sec-test-2 ]
  # task-brief 应输出 T_sec block（包含恶意字面量）
  grep -q 'T_sec' /tmp/sec-t2.out
  grep -q 'touch /tmp/flow-kit-sec-test-2' /tmp/sec-t2.out
}

# ── AC-A3: backtick + $IFS 展开（commit msg）──
@test "SEC-3 commit msg 含 backtick 不被执行" {
  skip_if_no_review_package
  SEC_REPO="$(_setup_sec_repo)"
  cd "$SEC_REPO"
  # backtick 在 shell 内会展开；git commit -m 已是单引号保护
  git commit -q --allow-empty -m 'feat `echo hijacked` ${IFS}' >/dev/null 2>&1
  run bash "$SCRIPTS_DIR/review-package" HEAD~1 HEAD
  [ $status -eq 0 ]
  # 输出应包含字面量（review-package 不应执行 backtick）
  echo "$output" | grep -q 'echo hijacked'
  # R2 fix (phase 6 L2): 显式 negative assertion — backtick 未展开（无独立 hijacked 行）
  ! echo "$output" | grep -qE '^hijacked$'
}

# ── AC-A4: flag 注入（task-brief name 含换行+--output）──
@test "SEC-4 task-brief name 含 newline + --output 不被解析为 flag" {
  skip_if_no_task_brief
  run bash -c "awk -f '$SCRIPTS_DIR/task-brief' '$FIXTURE_TASK' T_flag > /tmp/sec-t4.out 2>&1; echo exit=\$?"
  # task-brief 应输出 T_flag block（包含字面量 --output）
  grep -q 'T_flag' /tmp/sec-t4.out
  grep -q -- '--output=/tmp/flow-kit-hijacked' /tmp/sec-t4.out
  # /tmp/flow-kit-hijacked 不应被创建（flag 未生效）
  [ ! -f /tmp/flow-kit-hijacked ]
  # R3 fix (phase 6 L2): 输出只含 T_flag block — 不渗入 T_sec/T_ok
  ! grep -q 'T_sec' /tmp/sec-t4.out
  ! grep -q 'T_ok' /tmp/sec-t4.out
}

# ── AC-A5a: path traversal — 输出不含 passwd 内容（已实现）──
@test "SEC-5a review-package '../../etc/passwd' base 不输出 passwd 内容" {
  skip_if_no_review_package
  SEC_REPO="$(_setup_sec_repo)"
  cd "$SEC_REPO"
  run bash "$SCRIPTS_DIR/review-package" "../../etc/passwd" HEAD
  # 关键安全断言：输出中不包含 /etc/passwd 的内容（'root:' 行）
  ! echo "$output" | grep -q '^root:'
  ! echo "$output" | grep -q '/bin/bash'
}

# ── AC-A5b: path traversal — 错误路径断言（L-071 fixed）──
@test "SEC-5b review-package '../../etc/passwd' base exit ≠0 + stderr err msg" {
  skip_if_no_review_package
  SEC_REPO="$(_setup_sec_repo)"
  cd "$SEC_REPO"
  run bash "$SCRIPTS_DIR/review-package" "../../etc/passwd" HEAD
  [ $status -ne 0 ]
  echo "$output" | grep -qE '(error|fatal|invalid|bad revision)'
}

# ── AC-A6: 非 ASCII 字节保留（commit msg + task-brief）──
@test "SEC-6 中文 + emoji 字节在输出中保留 (UTF-8)" {
  skip_if_no_review_package
  skip_if_no_task_brief
  SEC_REPO="$(_setup_sec_repo)"
  cd "$SEC_REPO"
  git commit -q --allow-empty -m "feat 中文测试 🚀" >/dev/null 2>&1
  run bash "$SCRIPTS_DIR/review-package" HEAD~1 HEAD
  [ $status -eq 0 ]
  echo "$output" | grep -q '中文测试'
  echo "$output" | grep -q '🚀'

  # task-brief 也保留非 ASCII
  run bash -c "awk -f '$SCRIPTS_DIR/task-brief' '$FIXTURE_TASK' T_ok"
  [ $status -eq 0 ]
  echo "$output" | grep -q '正常 task 名'
  echo "$output" | grep -q '🚀'
}

# ── helpers ──
skip_if_no_review_package() {
  if [ ! -f "$SCRIPTS_DIR/review-package" ]; then
    skip "review-package script 不存在 (precondition)"
  fi
}

skip_if_no_task_brief() {
  if [ ! -f "$SCRIPTS_DIR/task-brief" ]; then
    skip "task-brief script 不存在 (precondition)"
  fi
}
