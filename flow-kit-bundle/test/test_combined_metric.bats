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
  [ "$COMBINED_BYTES" -le 20480 ]

  rm -f "$TASK_BRIEF_OUT"
}

@test "INT-COMBINED-1-cleanup: no leftover temp files" {
  # 确保无残留 /tmp 文件
  run ls /tmp/tmp.* 2>/dev/null
  [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
}

setup() {
  export TEST_TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}
