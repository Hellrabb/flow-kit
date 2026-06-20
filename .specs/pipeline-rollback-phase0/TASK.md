# TASK: Pipeline 回退协议扩展到 0-3 规划阶段（智能回退方案 C）

- **Change ID**: pipeline-rollback-phase0
- **关联**: `@.specs/pipeline-rollback-phase0/REQUIREMENT.md`、`@.specs/pipeline-rollback-phase0/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]
Wave 2:            T04      (depends on T01, T02, T03)
```

> Wave 1 三个任务触碰文件互不重叠：T01 改 5-test，T02 改 6-review，T03 改 7-integration + 新增测试文件。可完全并行。
> Wave 2 全量回归 + 同步运行时副本。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>5-test.md 智能回退改造（失败分类表 + 动态目标 + jq 通用化）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    .specs/pipeline-rollback-phase0/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
  </write_files>
  <action>
    改造 5-test.md 的两处回退（toll-gate 回退选项 line ~47 + 执行失败回退 line ~66-81）：

    1. 在 pipeline rollback 段顶部新增「失败分类表」：
       | 失败现象 | 建议回退目标 |
       | 测试断言失败/代码 bug | 4-dev |
       | AC 未覆盖/无法满足 | 1-requirement（仅 start_phase ≤ 1 时可选）|
       | 测试用例设计缺陷（漏边界）| 3-task（仅 start_phase ≤ 3 时可选）|
       | 其他/不确定 | 4-dev（默认）|
       注：架构相关失败（回 2）在 5-test 较少见，仍列入兜底说明。

    2. 把硬编码「回退到 4-dev」改为「动态回退目标列表」：
       rollback_targets = [start_phase .. current_phase-1]
       展示给用户可选目标，AI 根据失败分类给默认建议。

    3. 回退 jq 通用化：
       原：'.goal.current_phase = "4" | .goal.phases_done -= ["5"]'
       改为 $TARGET 参数化：
       先算 phases_to_remove（TARGET 之后到当前的所有已完成阶段），再
       jq --arg target "$TARGET" --argjson remove "$REMOVE" \
         '.goal.current_phase = $target | .goal.phases_done -= $remove | .updated_at = now'

    向后兼容：start_phase=4 时，rollback_targets=[4]，默认建议回 4，行为不变。

    参考 DESIGN.md D1-D7 + 2.1/2.2。
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit
F=flow-kit-bundle/flow-kit/prompts/5-test.md
# 失败分类表存在
grep -qE '失败.*分类|失败现象.*建议|测试断言.*4-dev' "$F" && echo "✅ 5-test: 失败分类表" || echo "❌ MISSING"
# 不再硬编码 current_phase = "4" 作为唯一回退（应出现 $TARGET 或 target 参数化）
grep -qE 'TARGET|\$target|参数化|动态回退' "$F" && echo "✅ 5-test: 通用化 jq" || echo "❌ MISSING"
# 向后兼容说明存在
grep -qE 'start_phase.*4|默认.*4' "$F" && echo "✅ 5-test: 向后兼容说明" || echo "❌ MISSING"
    ]]>
  </verify>
  <done>5-test.md 回退段含失败分类表 + 动态目标 + $TARGET jq，--from 4 向后兼容</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>6-review.md 智能回退改造</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
    .specs/pipeline-rollback-phase0/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
  </write_files>
  <action>
    改造 6-review.md 的两处回退（Gate 失败 line ~46-65 + toll-gate 6→7 回退 line ~84）：

    1. 新增失败分类表（6-review 重点是代码质量/spec 合规）：
       | 失败现象 | 建议回退目标 |
       | brooks-review 🔴 Critical（代码 bug）| 4-dev |
       | spec 合规失败（AC 未覆盖/无法满足）| 1-requirement |
       | 架构决策缺陷（撞 ADR）| 2-design |
       | 跨模块契约违反 | 2-design |
       | 其他/不确定 | 4-dev（默认）|

    2. Gate 失败的「修复后继续 → 回到 4-dev」改为动态目标 + 智能建议。
       rollback_targets = [start_phase .. 5]（6-review 时已完成到 5）

    3. 回退 jq 通用化（与 T01 同模板）：
       原：'.goal.current_phase = "4" | .goal.phases_done -= ["5", "6"]'
       改为 $TARGET 参数化（移除 TARGET 之后的所有已完成阶段）。

    向后兼容：start_phase=4 时，rollback_targets=[4]，默认回 4。
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit
F=flow-kit-bundle/flow-kit/prompts/6-review.md
grep -qE '失败.*分类|失败现象.*建议|spec 合规.*1-requirement' "$F" && echo "✅ 6-review: 失败分类表" || echo "❌ MISSING"
grep -qE 'TARGET|\$target|参数化|动态回退' "$F" && echo "✅ 6-review: 通用化 jq" || echo "❌ MISSING"
grep -qE '架构.*2-design|spec.*1-requirement' "$F" && echo "✅ 6-review: 规划层回退建议" || echo "❌ MISSING"
    ]]>
  </verify>
  <done>6-review.md Gate 失败 + toll-gate 回退均含分类表 + 动态目标 + $TARGET jq</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>7-integration.md 智能回退改造 + 新增 test_pipeline_rollback.bats</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    test/test_flow_goal.bats
    .specs/pipeline-rollback-phase0/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    test/test_pipeline_rollback.bats
  </write_files>
  <action>
    **A. 7-integration.md 失败诊断回退改造（line ~89-99）**：

    1. 新增失败分类表（7-integration 重点是集成/UAT）：
       | 失败现象 | 建议回退目标 |
       | 集成测试失败/代码 bug | 4-dev |
       | UAT 揭示 AC 错误 | 1-requirement |
       | 集成时发现架构缺陷 | 2-design |
       | 部署/环境配置问题 | 4-dev（重新执行）|
       | 其他/不确定 | 4-dev（默认）|

    2. 「⬅️ 回退到 4-dev」改为动态目标 + 智能建议。
       rollback_targets = [start_phase .. 6]

    3. 回退 jq 通用化：
       原：'.goal.current_phase = "4" | .goal.phases_done -= ["5","6","7"]'
       改为 $TARGET 参数化。

    **B. 新建 test/test_pipeline_rollback.bats（AC-5）**：

    沿用 test_flow_goal.bats 的 setup（mktemp + .flow-active fixture）。
    测试 4 类场景：
    1. 动态回退目标列表生成：
       - start_phase=4, current=5 → rollback_targets=[4]
       - start_phase=0, current=6 → rollback_targets=[0,1,2,3,4,5]
    2. 通用回退 jq（$TARGET 参数化）：
       - 构造 phases_done=[4,5,6], 回退 TARGET=2 → phases_done 应移除 [3,4,5,6]? 不对，phases_done 是已完成的，回退到 2 移除 >2 的 → 移除已完成的 >2 的
       - 实测：phases_done=["4","5"], TARGET="2" → 移除 >2 的 → 移除 ["4","5"]，current_phase="2"
       - phases_done=["4","5","6"], TARGET="4" → 移除 >4 的 → 移除 ["5","6"]，current_phase="4"（向后兼容）
    3. 回退到规划阶段（start_phase=0）：
       - phases_done=["0","1","2","3","4","5"], TARGET="2" → 移除 >2 → ["3","4","5"]，current_phase="2"
    4. 向后兼容（start_phase=4）：
       - 回退下界 = start_phase，不能退到 < 4

    参考 DESIGN.md 2.1/2.2 的 jq 模板。
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit

# 7-integration 改造
F=flow-kit-bundle/flow-kit/prompts/7-integration.md
grep -qE '失败.*分类|失败现象.*建议' "$F" && echo "✅ 7-integration: 失败分类表" || echo "❌ MISSING"
grep -qE 'TARGET|\$target|动态回退' "$F" && echo "✅ 7-integration: 通用化" || echo "❌ MISSING"

# 新增测试文件
test -f test/test_pipeline_rollback.bats && echo "✅ test_pipeline_rollback.bats created" || echo "❌ MISSING"
npx bats test/test_pipeline_rollback.bats --formatter tap 2>&1 | tail -5
    ]]>
  </verify>
  <done>7-integration 回退改造完成 + test_pipeline_rollback.bats 新增 ≥4 测试全 ok</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="false" status="done">
  <name>全量回归 + 同步运行时副本</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    test/test_pipeline_rollback.bats
  </read_files>
  <write_files>
    ~/.claude/flow-kit/prompts/5-test.md
    ~/.claude/flow-kit/prompts/6-review.md
    ~/.claude/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    1. 运行全量测试 npx bats test/，确认 0 fail 0 skip
    2. 将 3 个改动的 prompt 同步到 ~/.claude/flow-kit/prompts/
    3. 对照 AC-1 到 AC-6 逐条确认
    4. 验证 3 个 prompt 的失败分类表内容一致（D2 一致性）
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit
echo "=== AC-6: 全量回归 ==="
RESULT=$(npx bats test/ --formatter tap 2>&1)
TOTAL=$(echo "$RESULT" | grep -cE '^ok ')
FAIL=$(echo "$RESULT" | grep -cE '^not ok')
echo "总计: $TOTAL ok | $FAIL fail"
echo "$RESULT" | tail -3

echo ""
echo "=== AC-1/2/3: 三 prompt 一致性 ==="
for f in 5-test.md 6-review.md 7-integration.md; do
  HAS_TABLE=$(grep -cE '失败.*分类|失败现象' flow-kit-bundle/flow-kit/prompts/$f)
  HAS_DYNAMIC=$(grep -cE 'TARGET|\$target|动态回退' flow-kit-bundle/flow-kit/prompts/$f)
  echo "$f: 分类表 $HAS_TABLE 处 | 通用化 $HAS_DYNAMIC 处"
done

echo ""
echo "=== AC-4: 运行时副本同步 ==="
for f in 5-test.md 6-review.md 7-integration.md; do
  diff -q flow-kit-bundle/flow-kit/prompts/$f ~/.claude/flow-kit/prompts/$f >/dev/null 2>&1 \
    && echo "✅ sync: $f" || echo "⚠️  sync: $f differs"
done

[ "$FAIL" -eq 0 ] && echo "✅ AC-6 PASS" || echo "❌ AC-6 FAIL"
    ]]>
  </verify>
  <done>AC-1~6 全部通过, 运行时副本已同步</done>
  <depends_on>T01, T02, T03</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中
- `status="done"` — 已完成（verify 通过）

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
