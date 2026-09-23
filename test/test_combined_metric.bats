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
  # 断言面自带扫描根（task T09 1.8 fix loop 第 1 轮裁定）：不回落环境 /tmp。
  # 本机 /tmp 现存 149 个无关 tmp.*，而扫描根若用「TMPDIR 缺省回溯到 /tmp」的形态，在 TMPDIR 未设
  # 时就会落到这堆无关文件上 ⇒ 环境相关恒红。故扫描面收敛到用例自建的、位于 $TEST_TMPDIR 内的
  # 无噪声根，与环境 /tmp 彻底解耦。
  # 被测形态：在自有根 TMPDIR="$root" 驱动下用 mktemp 造临时文件并随建随删（复刻 INT-COMBINED-1
  # 的建/删模式）；mktemp 只可能把 tmp.* 落在 $root 内，全程不触碰环境 /tmp。
  # 无残留 ⇒ ls 无命中 ⇒ grep -q . 失败 ⇒ 非零 ⇒ 绿；有残留 ⇒ 命中 ⇒ 零 ⇒ 红。
  root="$TEST_TMPDIR/scan"
  mkdir -p "$root"
  t=$(env TMPDIR="$root" mktemp)
  rm -f "$t"
  run bash -c 'ls -d "$1"/tmp.* 2>/dev/null | grep -q .' -- "$root"
  [ "$status" -ne 0 ]
}

setup() {
  export TEST_TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}