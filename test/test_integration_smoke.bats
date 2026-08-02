#!/usr/bin/env bats
# test_integration_smoke.bats — L-065 集成 smoke (superpowers-absorb-followup-1)
# 覆盖 REQUIREMENT AC-B1~B5

PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/flow-kit-bundle/flow-kit/scripts"
BUNDLE_DIR="$PROJECT_ROOT/flow-kit-bundle/flow-kit"
FIXTURE_TASK="$BATS_TEST_DIRNAME/fixtures/security/TASK_sec.md"

# INT-1/2 与 SEC 共享 fixture（复用 fixtures/security/TASK_sec.md）
# INT-3/4/5 读真实 flow-kit-bundle/ 文件

setup() {
  # INT-1/2 需要一个真实 git repo（用 flow-kit 本身）
  cd "$PROJECT_ROOT"
}

# ── AC-B1: review-package 端到端（真实 git repo）──
@test "INT-1 review-package 输出含 ## Commits / Files changed / Diff 三段" {
  if [ ! -f "$SCRIPTS_DIR/review-package" ]; then
    skip "review-package 不存在 (precondition)"
  fi
  # flow-kit 仓库至少有 2 个 commit（git init + 后续）
  run bash "$SCRIPTS_DIR/review-package" HEAD~1 HEAD
  # status 0=success（仓库有多 commit）或非 0（无 HEAD~1）—— 任一可接受，关键是输出结构
  if [ $status -ne 0 ]; then
    # 无 HEAD~1（极简 repo）→ 用 HEAD vs empty tree
    run bash "$SCRIPTS_DIR/review-package" "4b825dc642cb6eb9a060e54bf8d69288fbee4904" HEAD
  fi
  # 三段 header 必须都在
  echo "$output" | grep -q '^## Commits'
  echo "$output" | grep -q '^## Files changed'
  echo "$output" | grep -q '^## Diff'
}

# ── AC-B2: task-brief 端到端 ──
@test "INT-2 task-brief 提取 T02 块，输出只含 T02 内容" {
  if [ ! -f "$SCRIPTS_DIR/task-brief" ]; then
    skip "task-brief 不存在 (precondition)"
  fi
  # 构造临时 TASK.md（避免依赖 superpowers-absorb-followup-1 的 TASK.md）
  local tmp_task="$BATS_TMPDIR/int-task-$$.md"
  cat >"$tmp_task" <<'EOF'
<TASK>
<task id="T01">
<name>first task</name>
</task>
<task id="T02">
<name>second task</name>
<action>T02 body</action>
</task>
<task id="T03">
<name>third task</name>
</task>
</TASK>
EOF
  run bash -c "awk -f '$SCRIPTS_DIR/task-brief' '$tmp_task' T02"
  [ $status -eq 0 ]
  # 输出含 T02
  echo "$output" | grep -q 'T02'
  echo "$output" | grep -q 'second task'
  # R4 fix (phase 6 L2): 输出含 action 字段
  echo "$output" | grep -q 'T02 body'
  # 输出不含 T01/T03
  ! echo "$output" | grep -q 'T01'
  ! echo "$output" | grep -q 'T03'
  rm -f "$tmp_task"
}

# ── AC-B3: GO.md routing（10 phase prompts） ──
@test "INT-3 GO.md 含 ≥10 处 prompts/[0-9] 引用" {
  local go_md="$BUNDLE_DIR/GO.md"
  if [ ! -f "$go_md" ]; then
    skip "GO.md 不存在 (precondition)"
  fi
  local count
  count=$(grep -cE 'prompts/[0-9]' "$go_md")
  # 至少 10 处 phase prompt 引用
  [ "$count" -ge 10 ]
}

# ── AC-B4: 6-review.md 不含 Round 1/2/3 ──
@test "INT-4 prompts/6-review.md 不含 'Round [123]' 标识" {
  local review_md="$BUNDLE_DIR/prompts/6-review.md"
  if [ ! -f "$review_md" ]; then
    skip "6-review.md 不存在 (precondition)"
  fi
  # 反向断言：grep 找不到 Round 1/2/3
  ! grep -qE 'Round [123]' "$review_md"
}

# ── AC-B5: 4-dev.md 含三段（task-brief / model-tier / task_progress） ──
@test "INT-5 prompts/4-dev.md 含 task-brief + model-tier + task_progress 三段" {
  local dev_md="$BUNDLE_DIR/prompts/4-dev.md"
  if [ ! -f "$dev_md" ]; then
    skip "4-dev.md 不存在 (precondition)"
  fi
  # 每段至少 1 处提及
  grep -q 'task-brief' "$dev_md"
  grep -q 'model-tier' "$dev_md"
  grep -q 'task_progress' "$dev_md"
}
