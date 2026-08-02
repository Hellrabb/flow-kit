#!/usr/bin/env bats
# test_task_brief.bats — task-brief awk 脚本测试
# bats_require_minimum_version 1.10.0

setup() {
    TEST_TMPDIR=$(mktemp -d)
    # 位置无关：向上查找含 flow-kit-bundle 的目录（兼容 test/ 与 flow-kit-bundle/test/ 双源）
    local d
    d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/flow-kit/scripts" ]; do
        d="$(dirname "$d")"
    done
    TASK_BRIEF="$d/flow-kit-bundle/flow-kit/scripts/task-brief"
    TASK_FILE="$TEST_TMPDIR/TASK.md"

    # 构造含 3 个 task 块的测试 TASK.md（按 flow-kit/templates/TASK.md 结构）
    cat > "$TASK_FILE" << 'TASKEOF'
# TASK: task-brief 测试
- **Change ID**: tb-test
- **关联**: `@.specs/tb-test/REQUIREMENT.md`、`@.specs/tb-test/DESIGN.md`

---

## 任务清单

```xml
<task id="T01" parallel="true" status="pending" model-tier="standard">
  <name>准备文档模板</name>
  <read_files>
    flow-kit-bundle/flow-kit/templates/TASK.md
    flow-kit-bundle/flow-kit/templates/REQUIREMENT.md
  </read_files>
  <write_files>
    .specs/tb-test/REQUIREMENT.md
    .specs/tb-test/CONTEXT.md
  </write_files>
  <action>
    基于模板生成 REQUIREMENT.md 和 CONTEXT.md。
    沿用既有 CONTEXT.md 术语表格式。
  </action>
  <verify>
    test -f .specs/tb-test/REQUIREMENT.md
  </verify>
  <done>
    AC-1 文档模板准备完毕
  </done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="pending" model-tier="cheap">
  <name>新增 scripts/task-brief.awk + bats 测试</name>
  <read_files>
    flow-kit-bundle/flow-kit/templates/TASK.md
    .specs/superpowers-v6-absorb/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/scripts/task-brief
    test/test_task_brief.bats
  </write_files>
  <action>
    实现 task-brief awk 脚本：从 TASK.md 提取单个 task XML block。
    状态机：匹配 <task id="T02" 起始标签 → 打印行至 </task>。
    错误路径：task id 未找到 → exit ≠0 + stderr "task <id> not found"。
  </action>
  <verify>
    npx bats test/test_task_brief.bats
  </verify>
  <done>
    task-brief 脚本 + bats 测试全部通过
  </done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="false" status="pending" model-tier="standard">
  <name>集成 task-brief 到 4-dev prompt</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/scripts/task-brief
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    改造 4-dev.md 入场段：从"读整个 TASK.md"变为"读 task-brief 输出"。
    4-dev 开工时先跑 task-brief 提取当前 task，裁掉无关 task 块。
    目标：4-dev reload 成本 -40%。
  </action>
  <verify>
    grep 'task-brief' flow-kit-bundle/flow-kit/prompts/4-dev.md
  </verify>
  <done>
    4-dev prompt 已集成 task-brief
  </done>
  <depends_on>T02</depends_on>
</task>
```

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成
- `status="blocked"` — 阻塞
TASKEOF
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ═══════════════════════════════════════════════════════════════
# Test 1 — happy path: extract T02
# ═══════════════════════════════════════════════════════════════

@test "task-brief: extracts T02 block with correct content" {
    run awk -f "$TASK_BRIEF" "$TASK_FILE" "T02"
    [ "$status" -eq 0 ]
    # 输出含开标签
    [[ "$output" =~ \<task\ id=\"T02\" ]]
    # 输出含闭标签（最后一行 · 用 $lines 数组避免 echo 吞尾随换行）
    last_idx=$((${#lines[@]} - 1))
    [ "${lines[$last_idx]}" = "</task>" ]
}

# ═══════════════════════════════════════════════════════════════
# Test 2 — error path: task id not found
# ═══════════════════════════════════════════════════════════════

@test "task-brief: exits non-zero and reports error for missing task" {
    run awk -f "$TASK_BRIEF" "$TASK_FILE" "T99"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "task T99 not found" ]]
}

# ═══════════════════════════════════════════════════════════════
# Test 3 — multiple tasks: only T03, no T01/T02
# ═══════════════════════════════════════════════════════════════

@test "task-brief: extracts T03 only, excludes T01 and T02" {
    run awk -f "$TASK_BRIEF" "$TASK_FILE" "T03"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \<task\ id=\"T03\" ]]
    # 确保不包含其他 task 的 XML 块
    ! [[ "$output" =~ \<task\ id=\"T01\" ]]
    ! [[ "$output" =~ \<task\ id=\"T02\" ]]
}

# ═══════════════════════════════════════════════════════════════
# Test 4 — XML integrity: output boundaries
# ═══════════════════════════════════════════════════════════════

@test "task-brief: output starts with <task id= and ends with </task>" {
    run awk -f "$TASK_BRIEF" "$TASK_FILE" "T02"
    [ "$status" -eq 0 ]
    # 首行以 <task id= 开头（无前导垃圾 · 用 $lines 避免 echo 吞尾随换行）
    [[ "${lines[0]}" =~ ^\<task\ id= ]]
    # 末行恰好是 </task>（无尾随垃圾）
    last_idx=$((${#lines[@]} - 1))
    [ "${lines[$last_idx]}" = "</task>" ]
}
