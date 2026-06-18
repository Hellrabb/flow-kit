# TASK: Goal 从单阶段自循环扩展到跨阶段 Pipeline

- **Change ID**: pipeline-goal
- **关联**: `@.specs/pipeline-goal/REQUIREMENT.md`、`@.specs/pipeline-goal/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P]    ← 基础层：CLI + GO.md 路由
Wave 2 (parallel): T03[P], T04[P], T05[P], T06[P]  ← 4 个 prompt 同步改造
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
> Wave 1 产出 schema 展示格式 + CLI 接口，Wave 2 的 4 个 prompt 都引用同一套协议（DESIGN § 2.1），可并行改造。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done">
  <name>/flow goal CLI 扩展：--pipeline + --gate-config + pipeline 展示</name>
  <read_files>
    .specs/pipeline-goal/DESIGN.md
    .specs/pipeline-goal/REQUIREMENT.md
    .specs/CONTEXT.md
    flow-kit-bundle/skills/flow/SKILL.md
  </read_files>
  <write_files>
    flow-kit-bundle/skills/flow/SKILL.md
  </write_files>
  <action>
    扩展 /flow goal 子命令（SKILL.md）：

    1. `/flow goal <条件> --pipeline`：新增 --pipeline flag。
       设定 goal 时写入完整 pipeline schema：
       - scope: "pipeline"
       - current_phase: "4"
       - phases_done: []
       - gates: {"4→5":"pending", "5→6":"pending", "6→7":"pending"}
       - gate_config: {}（默认空，所有检查用内置默认级别）
       - auto_advance: false
       - phase_sub_goals: {}（AC-12 自动提取后填入）

    2. `/flow goal <条件> --pipeline --gate-config '<JSON>'`：
       解析用户提供的 JSON，写入 gate_config。
       验证 JSON 格式（jq 解析成功才算有效）。

    3. `/flow goal`（无参数）展示扩展：
       - 若 goal.scope="pipeline"：展示 pipeline 进度条
         🎯 [pipeline] Goal: &lt;condition&gt;
            进度: 4 ✅ → 5 ⏳ → 6 ⏸ → 7 ⏸
            门禁: 4→5 pending | 5→6 pending | 6→7 pending
            auto_advance: false
            状态: active | 已执行 N turns | 模式: native/fallback
       - 若 goal.scope="phase" 或无 scope：保持现有展示不变（AC-6 向后兼容）

    4. `/flow goal clear`：行为不变（goal=null），pipeline 字段随之清除。

    5. jq 操作沿用既有的 `.tmp + mv` 原子写入模式。
  </action>
  <verify>
    # 验证 --pipeline flag 写入正确 schema
    jq -r '.goal.scope' .flow-active  # 期望: "pipeline"
    jq -r '.goal.current_phase' .flow-active  # 期望: "4"
    jq -r '.goal.phases_done | length' .flow-active  # 期望: 0
    jq -r '.goal.gates["4→5"]' .flow-active  # 期望: "pending"
    jq -r '.goal.auto_advance' .flow-active  # 期望: "false"

    # 验证 --gate-config 写入
    jq -r '.goal.gate_config["6-review"].perf-regression' .flow-active  # 期望: "critical"

    # 验证向后兼容（无 scope 的旧 goal）
    jq -r '.goal.scope // "phase"' .flow-active  # 期望: "phase"

    # 验证 goal clear 清除 pipeline 字段
    jq -r '.goal' .flow-active  # 期望: null
  </verify>
  <done>AC-1（设定 Pipeline Goal）、AC-6（向后兼容）、AC-9（动态门禁配置）的写入端完成</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>GO.md 路由改造：pipeline goal 注入 + 路由声明展示</name>
  <read_files>
    .specs/pipeline-goal/DESIGN.md
    .specs/pipeline-goal/REQUIREMENT.md
    flow-kit-bundle/flow-kit/GO.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/GO.md
  </write_files>
  <action>
    改造 GO.md 第四步「Goal 注入」(line 254)：

    1. 扩展 Goal 注入逻辑（line 254 jq 命令）：
       不仅读 condition，还读 scope / current_phase / phases_done / auto_advance / gates
       若 scope="pipeline" → 注入额外上下文到当前阶段的 prompt 加载

    2. 路由声明（第五步）的 ✅ Goal 行扩展：
       单阶段（scope="phase" 或无）：保持 "✅ Goal：&lt;condition&gt; (active, N turns)"
       Pipeline（scope="pipeline"）：
         ✅ Goal：[pipeline] &lt;condition&gt;
            进度: 4✅ → 5⏳ → 6⏸ → 7⏸ | auto_advance: false
            gates: 4→5 pending | 5→6 pending | 6→7 pending

    3. 新增 "Pipeline Goal 恢复" 路由：
       在第二步路由表中加入：若 .flow-active.goal.scope="pipeline" 且 status="active"
       → 路由声明标注当前 phase，加载对应 prompt

    4. 不改变现有单阶段 goal 的行为（向后兼容）。
    5. 不与 0-3 阶段的 prompt 产生交集（pipeline goal 只在 phase ≥ 4 时生效）。
  </action>
  <verify>
    # 验证 pipeline goal 展示格式（模拟 .flow-active 含 pipeline goal）
    # 人工验收：进入 4-dev 时观察路由声明是否含 pipeline 进度条
    echo "人工验收：检查 GO.md 路由声明中 Goal 行格式"
  </verify>
  <done>AC-1（Pipeline Goal 路由展示）、AC-7（Pipeline 状态恢复路由）的路由端完成</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>4-dev.md 改造：pipeline goal 检测 + phase transition 4→5 + auto_advance 入口</name>
  <read_files>
    .specs/pipeline-goal/DESIGN.md
    .specs/pipeline-goal/REQUIREMENT.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    在 4-dev.md 的「入场 Goal 检测」段（line 7-30）之后新增「Pipeline Goal 模式」段：

    1. 入场检测扩展（在现有 goal 检测之后）：
       读 .flow-active.goal.scope
       若 scope="pipeline" 且 current_phase="4"：
       - 展示 pipeline 横幅（进度条 + 当前阶段高亮）
       - 进入 pipeline 模式（与单阶段 goal 迭代模式共存）

    2. Phase Transition 4→5（在所有 task done 之后）：
       完成最后一个 task 后，检测是否为 pipeline goal
       若是 → 触发 TOLL-GATE 4→5：
         🚦 Toll-gate 4→5：所有 dev task 已完成。
         ✅ verify 全部通过
         是否进入测试阶段（5-test）？
           1. 继续 → 进入 5-test
           2. 暂停 → 保留当前状态，稍后恢复
           3. 跳过测试 → 直接进入 6-review（不推荐）
           4. 全自动推进 → auto_advance=true，后续 toll-gate 不再暂停

       用户选 1/3 → jq update:
         .goal.current_phase = "5" (或 "6" 若跳过)
         .goal.phases_done += ["4"]
         .goal.gates["4→5"] = "passed" (或 "skipped")
       用户选 2 → 保留状态，不更新 phase
       用户选 4 → jq update:
         .goal.auto_advance = true
         然后同选 1 执行 transition

    3. Toll-gate 措辞必须强硬：
       "停下来。必须等待用户回复，禁止自动继续。"

    4. AC-12 sub-goal 联动：
       若 phase_sub_goals["4"] 存在 → 在所有 task 完成后对照 sub-goal 自检
       若未满足 sub-goal → 提示用户

    5. 保持现有单阶段 goal 行为不变（scope="phase" 或无 scope）。
  </action>
  <verify>
    # 人工验收场景：
    # 1. 设 pipeline goal → 进入 4-dev → 确认横幅展示 pipeline 进度
    # 2. 完成所有 task → 确认 toll-gate 4→5 暂停并等待用户输入
    # 3. 选"全自动推进" → 确认 auto_advance=true 写入 .flow-active
    # 4. 选"继续" → 确认 current_phase="5", phases_done=["4"]
    echo "人工验收：4-dev toll-gate + phase transition"
  </verify>
  <done>AC-2（4→5 Toll-gate）、AC-11（Toll-gate 批量确认入口）、AC-12（sub-goal 自检联动）的 4-dev 端完成</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="pending">
  <name>5-test.md 改造：pipeline goal 检测 + toll-gate 5→6 + auto_advance 判定</name>
  <read_files>
    .specs/pipeline-goal/DESIGN.md
    .specs/pipeline-goal/REQUIREMENT.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/5-test.md
  </write_files>
  <action>
    在 5-test.md 入场处新增「Pipeline Goal 入场检测」段：

    1. 入场检测：
       读 .flow-active.goal.scope
       若 scope="pipeline" 且 current_phase="5"：
       - 展示 pipeline 横幅（进度条：4✅ → 5🔄 → 6⏸ → 7⏸）
       - 标注 "当前阶段：5-test"
       - 加载 REQUIREMENT.md + DESIGN.md + TASK.md + 各 *-SUMMARY.md（按既有 5-test 流程）

    2. 测试完成后的 toll-gate：
       5-test 所有轮次完成，TEST.md 已生成
       检查 auto_advance：
         若 auto_advance=true → 跳过 toll-gate，自动 transition 到 6
         若 auto_advance=false → 触发 TOLL-GATE 5→6：
           🚦 Toll-gate 5→6：测试已完成。
           ✅ TEST.md 已生成，覆盖率报告已出
           是否进入审查阶段（6-review）？
             1. 继续 → 进入 6-review
             2. 暂停 → 保留状态，稍后恢复
             3. 回退 → 回到 4-dev 修复测试发现的问题

       用户选 1 → jq update:
         .goal.current_phase = "6"
         .goal.phases_done += ["5"]
         .goal.gates["5→6"] = "passed"
       用户选 3 → AC-10 rollback: current_phase="4", phases_done 移除 "5"

    3. Toll-gate 措辞强硬："停下来。禁止自动继续。"

    4. AC-12 sub-goal 联动：
       若 phase_sub_goals["5"] 存在 → 测试完成后对照 sub-goal 自检
  </action>
  <verify>
    # 人工验收场景：
    # 1. pipeline goal + current_phase=5 → 进入 5-test → 确认横幅展示
    # 2. auto_advance=true → 测试完成 → 确认自动 transition 到 6
    # 3. auto_advance=false → 测试完成 → 确认 toll-gate 5→6 暂停
    # 4. 选"回退" → 确认 current_phase="4", phases_done 不含 "5"
    echo "人工验收：5-test toll-gate + auto_advance + rollback"
  </verify>
  <done>AC-3（5→6 Toll-gate）、AC-10（Phase 回退入口）、AC-11（auto_advance 判定）、AC-12（sub-goal 自检）的 5-test 端完成</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="pending">
  <name>6-review.md 改造：pipeline goal 检测 + 动态门禁 + gate 失败暂停 + phase 回退 + toll-gate 6→7</name>
  <read_files>
    .specs/pipeline-goal/DESIGN.md
    .specs/pipeline-goal/REQUIREMENT.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/6-review.md
  </write_files>
  <action>
    在 6-review.md 入场处新增「Pipeline Goal 入场检测 + 门禁」段：

    1. 入场检测：
       读 .flow-active.goal.scope
       若 scope="pipeline" 且 current_phase="6"：
       - 展示 pipeline 横幅（4✅ → 5✅ → 6🔄 → 7⏸）
       - 加载 gate_config["6-review"]（若存在）

    2. 动态门禁判定（AC-9）：
       6-review 执行后（双轮 review + brooks-review），对照 gate_config 判定：
         对每个检查项，查 gate_config["6-review"][check]：
           "critical" 或默认 → 🔴 不通过则 PIPELINE PAUSE
           "warn" → 🟡 记录 SUMMARY，不阻塞
           "ignore" → ⚪ 跳过
       默认门禁级别（无 gate_config 时）：
         brooks-review Critical → critical（hard stop）
         brooks-review Major → warn
         spec 合规失败 → critical

    3. Gate 失败暂停（AC-5）：
       检测到 Critical 问题时：
         ⛔ Pipeline 暂停：6-review 检测到 N 个 Critical 问题
           - [Critical] &lt;文件&gt; — &lt;问题描述&gt;
         请选择：
           1. 修复后继续 → 回 4-dev（触发 AC-10 rollback）
           2. 接受风险继续 → Critical 降级为 Known，继续 6→7
           3. 放弃本次 pipeline → goal.status = "aborted"
       用户选 1 → AC-10:
         .goal.current_phase = "4"
         .goal.phases_done 移除 "5" 和 "6"

    4. 审查通过后的 toll-gate：
       无 Critical 问题（或用户接受风险后）
       检查 auto_advance：
         若 true → 自动 transition 到 7
         若 false → TOLL-GATE 6→7：
           🚦 Toll-gate 6→7：审查通过。
           是否归档上线（7-integration）？
             1. 继续 → 进入 7-integration
             2. 暂停 → 保留状态
             3. 回退 → 回到 4-dev 修复

       用户选 1 → jq update:
         .goal.current_phase = "7"
         .goal.phases_done += ["6"]
         .goal.gates["6→7"] = "passed"

    5. Toll-gate 措辞强硬 + 门禁失败措辞醒目。
  </action>
  <verify>
    # 人工验收场景：
    # 1. pipeline goal + current_phase=6 → 进入 6-review → 确认横幅 + gate_config 加载
    # 2. brooks-review 发现 Critical + gate_config 默认 → 确认 ⛔ PIPELINE PAUSE
    # 3. 用户选"修复后继续" → 确认 current_phase="4", phases_done 不含 "5","6"
    # 4. 用户选"接受风险" → 确认继续 6→7 transition
    # 5. gate_config 设 "brooks-review" = "warn" → 确认 Critical 不阻塞
    echo "人工验收：6-review gate check + rollback + toll-gate"
  </verify>
  <done>AC-4（6→7 Toll-gate）、AC-5（关键门禁失败）、AC-9（动态门禁配置执行端）、AC-10（Phase 回退执行端）的 6-review 端完成</done>
  <depends_on></depends_on>
</task>

<task id="T06" parallel="true" status="pending">
  <name>7-integration.md 改造：pipeline goal 检测 + pipeline 完成 + completion summary</name>
  <read_files>
    .specs/pipeline-goal/DESIGN.md
    .specs/pipeline-goal/REQUIREMENT.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/7-integration.md
  </write_files>
  <action>
    在 7-integration.md 入场处新增「Pipeline Goal 入场检测 + 完成」段：

    1. 入场检测：
       读 .flow-active.goal.scope
       若 scope="pipeline" 且 current_phase="7"：
       - 展示 pipeline 横幅（4✅ → 5✅ → 6✅ → 7🔄）
       - 标注 "最终阶段：7-integration"

    2. 顶层 goal 条件自检：
       Pipeline 完成前，AI 自检 goal.condition 是否满足：
         "顶层 Goal 条件：&lt;goal.condition&gt;"
         逐项对照：
           ✅ &lt;条件 1&gt; — 已验证（来源：&lt;证据&gt;）
           ✅ &lt;条件 2&gt; — 已验证（来源：&lt;证据&gt;）
         全部满足 → 进入 pipeline 完成流程

    3. Pipeline 完成（AC-8）：
       7-integration 完成后：
         🎯 Pipeline Goal 完成：&lt;goal.condition&gt;
            经过阶段：4 → 5 → 6 → 7
            总 turns：&lt;N&gt;
            设定于：&lt;active_since&gt;
         jq update:
           .goal.status = "done"
           .goal.phases_done += ["7"]

    4. AC-12 sub-goal 汇总：
       若 phase_sub_goals 非空 → 汇总展示各阶段 sub-goal 达成情况
         4-dev: ✅ &lt;sub-goal 4&gt;
         5-test: ✅ &lt;sub-goal 5&gt;
         6-review: ✅ &lt;sub-goal 6&gt;
         7-integration: ✅ &lt;sub-goal 7&gt;

    5. 完成后建议用户运行 /flow goal clear 清除 pipeline 状态。
  </action>
  <verify>
    # 人工验收场景：
    # 1. pipeline goal + current_phase=7 → 进入 7-integration → 确认横幅展示
    # 2. 7-integration 完成 → 确认 🎯 Pipeline Goal 完成 输出
    # 3. 确认 goal.status = "done"
    jq -r '.goal.status' .flow-active  # 期望: "done"
    jq -r '.goal.phases_done | length' .flow-active  # 期望: 4
  </verify>
  <done>AC-8（Pipeline 完成）的 7-integration 端完成</done>
  <depends_on></depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
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
