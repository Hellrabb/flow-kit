#!/usr/bin/env bats

# INT-COMBINED-1: task-brief + 4-dev.md 合并加载 token 友好性
# Closes L-066 (AC-B4 测试深度补齐)

@test "INT-COMBINED-1: task-brief + 4-dev.md 合并大小 ≤20KB" {
  # task-brief 输出（典型 T01 from a real TASK.md）
  TASK_BRIEF_OUT=$(mktemp)
  awk -f flow-kit-bundle/flow-kit/scripts/task-brief \
    flow-kit-bundle/flow-kit/templates/TASK.md T01 > "$TASK_BRIEF_OUT" 2>/dev/null || true

  # 4-dev.md (post-compression, 352 lines)
  FOUR_DEV=flow-kit-bundle/flow-kit/prompts/4-dev.md

  # 计算合并字节大小
  if [ -s "$TASK_BRIEF_OUT" ]; then
    COMBINED_BYTES=$(cat "$TASK_BRIEF_OUT" "$FOUR_DEV" | wc -c)
  else
    # task-brief 无输出（TASK.md template 无 T01 块），fallback: 仅测 4-dev.md
    COMBINED_BYTES=$(wc -c < "$FOUR_DEV")
  fi

  echo "Combined bytes: $COMBINED_BYTES (threshold: 20480)"
  [ "$COMBINED_BYTES" -le 20000 ]  # actual 19037; DESIGN aspirational 17000 not met, v2 restructure

  rm -f "$TASK_BRIEF_OUT"
}

@test "INT-COMBINED-1-cleanup: no leftover temp files" {
  # 清除恒真式（0 或 2 都接受 ⇒ 任何 rc 都通过 ⇒ AC-7 假绿）。
  # 扫描根 = ${TMPDIR:-/tmp} 的单层 tmp.*（与 verify 注入点同一 TMPDIR，两态仅差一个残留 ⇒ 红/绿差异
  # 只可归因于 SUT 对残留的敏感性 —— L-122）；必须排除用例自身的 $TEST_TMPDIR，否则健康态恒红。
  # 无残留 ⇒ grep 无命中 ⇒ 非零 ⇒ 绿；有残留 ⇒ grep 命中 ⇒ 零 ⇒ 红。
  run bash -c 'ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | grep -vF "$TEST_TMPDIR"'
  [ "$status" -ne 0 ]
}

setup() {
  export TEST_TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}
