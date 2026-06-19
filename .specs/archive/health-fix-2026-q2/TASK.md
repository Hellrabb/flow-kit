# TASK: 修复 M-health 2026-06-20 的 2 项 🟡 技术债

- **Change ID**: health-fix-2026-q2
- **关联**: `@.specs/health-fix-2026-q2/REQUIREMENT.md`、`@.specs/health-fix-2026-q2/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2:            T03      (depends on T01, T02)
```

> Wave 1 两个任务触碰文件互不重叠：T01 改 3 个 prompt 的 jq，T02 新建测试文件。可完全并行。
> Wave 2 跑全量回归验证（依赖前两个都完成）。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>TD-003: 5/6/7 prompt 入场 jq 补 start_phase</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/GO.md
    .specs/health-fix-2026-q2/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    将三个 prompt 的入场 jq 命令从：
      jq -r '.goal | "\(.scope // "phase")|\(.current_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)"' .flow-active
    改为（与 4-dev.md:81 + GO.md:257 完全一致）：
      jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)"' .flow-active

    三个文件各自只改这一行 jq（入场 Goal 检测段），其余内容不动。
    参考 DESIGN.md D1（双重 fallback）。
  </action>
  <verify>
    <![CDATA[
# 验证三个文件都引用了 start_phase
for f in 5-test.md 6-review.md 7-integration.md; do
  N=$(grep -c 'start_phase' /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/$f)
  if [ "$N" -ge 1 ]; then echo "✅ $f: start_phase ($N)"; else echo "❌ $f: start_phase MISSING"; fi
done

# 验证三个文件都含双重 fallback 表达式
for f in 5-test.md 6-review.md 7-integration.md; do
  grep -q 'current_phase // .start_phase // "4"' /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/$f \
    && echo "✅ $f: 双重 fallback OK" \
    || echo "❌ $f: 双重 fallback MISSING"
done
    ]]>
  </verify>
  <done>AC-1: 5/6/7 三个 prompt 入场 jq 与 4-dev/GO.md 一致（含 start_phase 双重 fallback）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>TD-002: 新增 test_flow_artifacts.bats + 补 common.sh 边界</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    test/test_common.bats
    test/test_flow_goal.bats
    .specs/health-fix-2026-q2/DESIGN.md
  </read_files>
  <write_files>
    test/test_flow_artifacts.bats
    test/test_common.bats
  </write_files>
  <action>
    **A. 新建 test/test_flow_artifacts.bats（AC-2）**：

    沿用 test_common.bats 的 setup pattern（mktemp + source lib + skip_if_no_jq）。
    新增 export PROJECT_ROOT="$TEST_TMPDIR"（因为 fk_flow_field 依赖它）。

    覆盖 3 个纯函数：
    1. fk_flow_field:
       - 构造 $TEST_TMPDIR/.flow-active 含 {change_id:"test",goal:{...}}
       - 调 fk_flow_field "change_id" → 断言 == "test"
       - 调 fk_flow_field "goal.status" "default" → 断言 == "active"
       - 删 .flow-active → 调 fk_flow_field "x" "fallback" → 断言 == "fallback"（文件缺失走 default）
    2. fk_file_nonempty:
       - 写 10 行文件 → 断言 fk_file_nonempty 返回 0
       - 写 1 行文件（≤ MIN_MEANINGFUL_LINES=3）→ 断言返回 1
       - 不存在的文件 → 断言返回 1
    3. fk_validate_flow（基础路径）:
       - 先读函数体确认是否纯读（无 exit/写副作用）才测
       - 若纯读：构造合法 .flow-active → 断言返回 0
       - 若有副作用：改为测 fk_artifact_check 的 phase 1 分支（构造 spec_dir/CHANGE.md 缺失场景 → 断言输出 "warning|G1|..."）

    **B. 补 test_common.bats 边界用例（AC-3，新增 2+ 条）**：

    1. config_get 对缺失 CONFIG_FILE 文件的处理（当前测试未覆盖文件不存在的 default 路径）
       - 删 CONFIG_FILE → 调 config_get ".foo" "def" → 断言 == "def"
    2. check_enabled 对 module.enabled=false 的判断（确认已有 "returns false for disabled module"，但补一个 "checks 数组指定但 module disabled → false" 的边界）

    参考 DESIGN.md D2（测纯函数）/ D3（fixture 构造）/ D4（边界补全）。
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit

# 新增文件存在
test -f test/test_flow_artifacts.bats && echo "✅ test_flow_artifacts.bats created" || echo "❌ MISSING"

# 新增测试文件能跑通
npx bats test/test_flow_artifacts.bats --formatter tap 2>&1 | tail -8

# common.bats 测试数增加（原 17 → 应 ≥ 19）
COUNT=$(npx bats test/test_common.bats --formatter tap 2>&1 | grep -c '^ok ')
echo "test_common.bats: $COUNT tests (原 17, 应 ≥ 19)"
    ]]>
  </verify>
  <done>AC-2: test_flow_artifacts.bats 新增 ≥3 测试全 ok; AC-3: test_common.bats ≥19 tests</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="false" status="done">
  <name>全量回归 + 同步运行时副本</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    test/test_flow_artifacts.bats
    test/test_common.bats
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    1. 运行全量测试 npx bats test/，确认 0 fail 0 skip（除 skip_if_no_jq 合理跳过）
    2. 将 3 个改动的 prompt 同步到 ~/.claude/flow-kit/prompts/ 运行时副本
    3. 对照 AC-1 到 AC-4 逐条确认
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit

echo "=== AC-4: 全量回归 ==="
RESULT=$(npx bats test/ --formatter tap 2>&1)
echo "$RESULT" | tail -3
TOTAL=$(echo "$RESULT" | grep -cE '^ok ')
FAIL=$(echo "$RESULT" | grep -cE '^not ok')
SKIP=$(echo "$RESULT" | grep -cE '^# skip')
echo "总计: $TOTAL ok | $FAIL fail | $SKIP skip"

echo ""
echo "=== AC-1: 运行时副本同步 ==="
for f in 5-test.md 6-review.md 7-integration.md; do
  if diff -q flow-kit-bundle/flow-kit/prompts/$f ~/.claude/flow-kit/prompts/$f >/dev/null 2>&1; then
    echo "✅ sync: $f"
  else
    echo "⚠️  sync: $f differs"
  fi
done

# 最终判定
if [ "$FAIL" -eq 0 ]; then echo "✅ AC-4 PASS: 0 fail"; else echo "❌ AC-4 FAIL: $FAIL failures"; fi
    ]]>
  </verify>
  <done>AC-1~4 全部通过, 运行时副本已同步</done>
  <depends_on>T01, T02</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

```xml
<!-- 占位 -->
```
