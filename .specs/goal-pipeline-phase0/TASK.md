# TASK: Pipeline Goal 扩展到 Phase 0 起始

- **Change ID**: goal-pipeline-phase0
- **关联**: `@.specs/goal-pipeline-phase0/REQUIREMENT.md`、`@.specs/goal-pipeline-phase0/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]
Wave 2:            T04      (depends on T01, T02, T03)
```

> Wave 1 三个任务触碰的文件互不重叠：T01 只改 SKILL.md，T02 改 4 个 phase prompt，T03 改 GO.md + 4-dev.md。可完全并行。
> Wave 2 在所有源文件就绪后，同步到运行时副本并做集成验证。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>/flow goal --from 核心实现（SKILL.md）</name>
  <read_files>
    flow-kit-bundle/skills/flow/SKILL.md
    .specs/goal-pipeline-phase0/DESIGN.md
    .specs/goal-pipeline-phase0/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </write_files>
  <action>
    在 flow-kit-bundle/skills/flow/SKILL.md 中实现以下 5 项改动：

    1. **子命令解析**：在 `/flow goal <条件文本>` 段新增 `--from <n>` flag 解析。
       提取方式：从 args 中匹配 `--from\s+([0-7])`，未匹配则默认 "4"。
       校验：值不在 0-7 范围 → 输出错误并 exit 1。

    2. **动态 gates 生成**：将硬编码的 gates `{"4→5":"pending","5→6":"pending","6→7":"pending"}`
       替换为根据 start_phase 动态生成。生成逻辑：
       for i in start_phase .. 6: gates["{i}→{i+1}"] = "pending"
       实现为 `jq` 表达式中的动态 key 构建。

    3. **start_phase 字段写入**：在 pipeline goal 的 jq 写入命令中新增
       `start_phase: $start_phase` 字段（`--arg start_phase "$FROM_VAL"` 传入）。
       同时 `current_phase` 初始值改为 `$start_phase`（而非硬编码 "4"）。

    4. **`/flow goal` 无参数输出适配**：
       - 展示 start_phase（如 "起始: 0"）
       - 进度图标链根据 start_phase 动态生成（不硬编码从 4 开始）
       - gates 显示也动态化

    5. **向后兼容读**：所有读 `goal.start_phase` 处加 `// "4"` fallback。
       `/flow goal` 无参数 + `/flow doctor` 中均需覆盖。

    详见 DESIGN.md D1-D7 决策。
  </action>
  <verify>
    <![CDATA[
# 模拟 --from 0 的 goal 写入（不依赖 /flow 命令，直接测 jq 表达式）
cd /home/hellrabbit/unisoc/flow-kit
START=0
COND="test condition"
TS=$(date -Iseconds)
jq -n --arg cond "$COND" --arg ts "$TS" --arg start "$START" \
  '{change_id: "test", goal: {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", start_phase: $start, current_phase: $start, phases_done: [], gates: {}, gate_config: {}, auto_advance: false, phase_sub_goals: {}}, phase: "0", task_id: null, interrupt: null, token_spent: 0, updated_at: $ts}' \
  | jq -e '.goal.start_phase == "0" and .goal.current_phase == "0"' \
  && echo "✅ PASS: start_phase=0" || echo "❌ FAIL"

# 模拟缺失 start_phase 的回读（fallback "4"）
echo '{"goal":{"scope":"pipeline","current_phase":"4"}}' \
  | jq -e '(.goal.start_phase // "4") == "4"' \
  && echo "✅ PASS: fallback to 4" || echo "❌ FAIL"
    ]]>
  </verify>
  <done>AC-1（默认 4）、AC-2（--from 0）、AC-4（无效值拒绝）、AC-7（回读兼容）全部通过</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>0-3 阶段 prompt 追加 pipeline toll-gate 段</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    .specs/goal-pipeline-phase0/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
  </write_files>
  <action>
    在 4 个 phase prompt 的「触发下一步」段之后，追加 pipeline toll-gate 段。

    参考 4-dev.md 的 toll-gate 格式（4-dev.md 步骤 6 的 toll-gate 输出模板），
    为 0-3 每个阶段添加条件 toll-gate 段。

    关键约束（DESIGN.md R2）：
    - toll-gate 段必须用条件包裹：仅当 `.flow-active.goal.scope = "pipeline"`
      且 `current_phase` 匹配当前阶段时才展示
    - 模板统一（与 4-7 一致）："🛑 Toll-gate: Phase N → Phase N+1"
    - 列出本阶段产物 + 子条件评估状态
    - 给出选项：1. 继续 → 下一阶段  2. 暂停  3. 跳过（如有合理跳过理由）

    0-change.md 追加位置：在「## 触发下一步」之后，追加
      「## Pipeline Toll-gate（仅 pipeline goal 模式）」

    1-requirement.md / 2-design.md / 3-task.md 同理，在各自的「触发下一步」段后追加。

    预估每文件追加 ~15-20 行。
  </action>
  <verify>
    <![CDATA[
# 验证 4 个 prompt 文件都包含 Pipeline Toll-gate 段
for f in 0-change.md 1-requirement.md 2-design.md 3-task.md; do
  grep -q "Pipeline Toll-gate\|pipeline.*toll-gate\|🛑 Toll-gate" \
    /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/$f \
    && echo "✅ $f: toll-gate found" \
    || echo "❌ $f: toll-gate MISSING"
done
    ]]>
  </verify>
  <done>4 个 prompt 文件均含 pipeline toll-gate 段，AC-5（0-3 阶段 toll-gate 暂停）结构就绪</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>GO.md 路由 + 4-dev.md start_phase 动态化</name>
  <read_files>
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    .specs/goal-pipeline-phase0/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    **GO.md 改动（~5 处）：**

    1. pipeline goal 注入时机段（约 line 255-260）：
       将硬编码的 `current_phase // "4"` 改为读 `start_phase // "4"` 作为 pipeline 初始阶段。
       新增读取 `start_phase` 字段的 jq 命令。

    2. pipeline 横幅展示（约 line 307-308）：
       进度条从固定 "4🔄 → 5⏸ → 6⏸ → 7⏸" 改为根据 start_phase 动态生成。
       若 start_phase=0，展示 "0🔄 → 1⏸ → 2⏸ → 3⏸ → 4⏸ → 5⏸ → 6⏸ → 7⏸"。

    3. 路由匹配逻辑：
       当 goal.scope="pipeline" 时，从 goal.start_phase（fallback "4"）读取起始阶段，
       而非硬编码从 phase 4 开始路由。

    **4-dev.md 改动（~3 处）：**

    4. 入场 Goal 检测步骤 6（约 line 77-85）：
       `current_phase="4"` 判断改为读 `start_phase` 字段。
       Pipeline 横幅根据 start_phase 动态展示。

    5. toll-gate 协议（约 line 99-108）：
       阶段完成后 `current_phase` 更新逻辑不变（已正确），
       但需确认 phase 4 作为 pipeline 入场时，`current_phase` 初始值来自 `start_phase`。

    6. phase_sub_goals 展示：4-dev 入场时若 `start_phase != 4` 且 current_phase="4"，
       仍正常展示 sub-goal（逻辑不受影响）。

    详见 DESIGN.md D5（fallback）、D6（范围 0-7）。
  </action>
  <verify>
    <![CDATA[
# 验证 GO.md 不再硬编码 "4" 作为唯一 pipeline 起始
if grep -n 'current_phase.*//.*"4"' /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/flow-kit/GO.md; then
  echo "⚠️  GO.md: still has fallback '4' — OK if it's fallback, check context"
fi

# 验证 GO.md 引用了 start_phase
grep -q 'start_phase' /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/flow-kit/GO.md \
  && echo "✅ GO.md: start_phase referenced" \
  || echo "❌ GO.md: start_phase MISSING"

# 验证 4-dev.md 不再硬编码 current_phase="4" 为唯一入口
grep -q 'start_phase' /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/flow-kit/prompts/4-dev.md \
  && echo "✅ 4-dev.md: start_phase referenced" \
  || echo "❌ 4-dev.md: start_phase MISSING"
    ]]>
  </verify>
  <done>GO.md 路由 + 4-dev.md 均支持动态 start_phase，AC-2（--from 0）和 AC-3（--from 3）路由正确</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="false" status="done">
  <name>同步运行时副本 + 集成验证</name>
  <read_files>
    flow-kit-bundle/skills/flow/SKILL.md
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </read_files>
  <write_files>
    ~/.claude/skills/flow/SKILL.md
    ~/.claude/flow-kit/GO.md
    ~/.claude/flow-kit/prompts/0-change.md
    ~/.claude/flow-kit/prompts/1-requirement.md
    ~/.claude/flow-kit/prompts/2-design.md
    ~/.claude/flow-kit/prompts/3-task.md
    ~/.claude/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    1. 将 Wave 1 修改的 7 个 bundle 源文件同步到对应的运行时副本：
       - flow-kit-bundle/skills/flow/SKILL.md → ~/.claude/skills/flow/SKILL.md
       - flow-kit-bundle/flow-kit/GO.md → ~/.claude/flow-kit/GO.md
       - flow-kit-bundle/flow-kit/prompts/{0,1,2,3,4}-*.md → ~/.claude/flow-kit/prompts/

    2. 集成验证（模拟端到端）：
       a. 创建一个临时 .flow-active
       b. 模拟 `/flow goal "test condition" --pipeline --from 0` 的 jq 写入
       c. 验证 .flow-active.goal.start_phase = "0"
       d. 验证 gates 包含 "0→1" 到 "6→7"
       e. 模拟缺失 start_phase 的回读（fallback "4"）
       f. 清理临时文件

    3. 对照 AC-1 到 AC-7 逐条确认
  </action>
  <verify>
    <![CDATA[
cd /home/hellrabbit/unisoc/flow-kit

# 端到端模拟：--from 0 pipeline goal
START=0; COND="CHANGE confirmed AND all tests pass"; TS=$(date -Iseconds)
jq -n --arg cond "$COND" --arg ts "$TS" --arg start "$START" \
  '{change_id: "test-pipeline", goal: {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", start_phase: $start, current_phase: $start, phases_done: [], gates: {}, gate_config: {}, auto_advance: false, phase_sub_goals: {}}, phase: "0", task_id: null, interrupt: null, token_spent: 0, updated_at: $ts}' \
  > /tmp/.flow-active-test

# AC-2: start_phase = 0
jq -e '.goal.start_phase == "0"' /tmp/.flow-active-test && echo "✅ AC-2: start_phase=0" || echo "❌ AC-2 FAIL"

# AC-1: 默认 from 4
START=4
jq -n --arg cond "$COND" --arg ts "$TS" --arg start "$START" \
  '{change_id: "test", goal: {condition: $cond, status: "active", active_since: $ts, turns: 0, mode: "pending", scope: "pipeline", start_phase: $start, current_phase: $start, phases_done: [], gates: {}, gate_config: {}, auto_advance: false, phase_sub_goals: {}}, phase: "0", task_id: null, interrupt: null, token_spent: 0, updated_at: $ts}' \
  | jq -e '.goal.start_phase == "4"' && echo "✅ AC-1: default start_phase=4" || echo "❌ AC-1 FAIL"

# AC-7: 旧数据回读（无 start_phase）
echo '{"goal":{"scope":"pipeline","current_phase":"4","condition":"old","status":"active","active_since":"2026-06-18","turns":3,"mode":"native","phases_done":["4"],"gates":{"4→5":"passed"},"gate_config":{},"auto_advance":false,"phase_sub_goals":{}}}' \
  | jq -e '(.goal.start_phase // "4") == "4"' && echo "✅ AC-7: old data fallback" || echo "❌ AC-7 FAIL"

# 文件同步验证
for f in SKILL.md GO.md; do
  diff -q /home/hellrabbit/unisoc/flow-kit/flow-kit-bundle/skills/flow/$f /home/hellrabbit/.claude/skills/flow/$f 2>/dev/null \
    && echo "✅ sync: $f" || echo "⚠️  sync: $f differs (may need manual sync)"
done

rm -f /tmp/.flow-active-test
echo "✅ T04 integration check complete"
    ]]>
  </verify>
  <done>7 个文件同步到运行时副本，AC-1 到 AC-7 全部通过端到端模拟验证</done>
  <depends_on>T01, T02, T03</depends_on>
</task>
```

---

## 状态字段说明

- `status="done"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
