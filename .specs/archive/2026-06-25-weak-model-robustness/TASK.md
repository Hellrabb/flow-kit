# TASK: 提升 flow-kit 在弱模型（幻觉多）下的鲁棒性

- **Change ID**: weak-model-robustness
- **关联**: `@.specs/weak-model-robustness/REQUIREMENT.md`（7 AC）· `@.specs/weak-model-robustness/DESIGN.md`（D1-D6 · §0.5 触碰清单）· `@.specs/CONTEXT.md`

> 拆解依据：DESIGN §0.5.1 触碰/新增/禁动清单。所有 `write_files` 严格在触碰+新增范围，**不含禁动**（hooks/ skills/ .flow-active/ install.sh/ 阶段划分）。
> 验证方式细化（3-task 发现）：AC-7 的 check.sh 因本次 demo 脚本模拟（D4）无法真跑模型，改为**静态检查**加固内容；定量 token/turn 阈值留 v2。

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P]                         — L1 规则层 + GO goal 锚定
Wave 2 (parallel): T04[P], T05[P], T06[P]   (depends on Wave 1)   — L2 prompt gate + L3 证据链
Wave 3 (parallel): T07[P], T08[P], T09[P]   (depends on Wave 1+2) — 验收（bats 结构 + demo check.sh）
```

- 同波次 = 不同文件，无写冲突，可并行
- Wave 2 依赖 Wave 1（prompt 强化以 RULES 新约束为依据）
- Wave 3 依赖 Wave 1+2（验收对象是改完的 RULES/prompt）
- 无环依赖

---

## Wave 1 · L1 规则层 + GO 锚定（并行）

<task id="T01" parallel="true" status="done">
  <name>增强 RULES.md（R3 禁跳反问 + R6 禁凭空假设 + R7 复述边界）</name>
  <read_files>
    flow-kit-bundle/flow-kit/RULES.md
    .specs/weak-model-robustness/DESIGN.md
    .specs/weak-model-robustness/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/RULES.md
  </write_files>
  <action>
    在既有 R3·角色红线段加"禁跳反问直接出方案"硬约束（反问 gate 未过不许进实现）；
    在既有 R6·反幻觉段加"禁凭空假设文件/API/字段——引用前必须 grep/read 验证（→ 触发证据链 L3）"；
    在既有 R7·范围控制段加"动手前必须复述当前 task 的 read_files/write_files 边界 + CHANGE 范围排除"。
    保持 RULES 八段结构（D1），每段净增 < 20 行，冗长示例不内联。
  </action>
  <verify>grep -cE "禁跳反问|凭空假设|复述.*(read_files|write_files|边界)" flow-kit-bundle/flow-kit/RULES.md | grep -qv ^0</verify>
  <done>RULES.md R3/R6/R7 三段含弱模型硬护栏措辞（对应 AC-1/AC-2/AC-4 的规则侧）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done">
  <name>SYSTEM.md 加"弱模型鲁棒性原则"节</name>
  <read_files>
    flow-kit-bundle/flow-kit/SYSTEM.md
    .specs/weak-model-robustness/DESIGN.md
    .specs/adr/001-protect-the-weakest.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/SYSTEM.md
  </write_files>
  <action>
    在 SYSTEM.md 加一节"弱模型鲁棒性原则"：声明 protect-the-weakest 哲学（默认全含加严 + 仅结构刚性 + 降级 opt-out 留 L4）+ 否决运行时自动探测。引用 ADR-001。不展开实现（指向 RULES.md）。
  </action>
  <verify>grep -q "弱模型鲁棒性" flow-kit-bundle/flow-kit/SYSTEM.md && grep -q "protect.the.weakest\|ADR-001" flow-kit-bundle/flow-kit/SYSTEM.md</verify>
  <done>SYSTEM.md 含弱模型原则节并指向 ADR-001（哲学层落地）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done">
  <name>GO.md 加 pipeline 阶段入场 goal 锚定</name>
  <read_files>
    flow-kit-bundle/flow-kit/GO.md
    .specs/weak-model-robustness/DESIGN.md
    .specs/weak-model-robustness/REQUIREMENT.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/GO.md
  </write_files>
  <action>
    在 GO.md 路由声明模板（第五步）加"阶段入场 goal 锚定"：进入每个阶段时显式重申顶层 goal condition + 本阶段如何服务于它。**仅入场锚定一次，非每步唠叨**（AC-5/AC-7）。不改路由逻辑、不改状态机。
  </action>
  <verify>grep -qE "goal.*(锚定|重申)|重申.*goal" flow-kit-bundle/flow-kit/GO.md</verify>
  <done>GO.md 含阶段入场 goal 锚定步骤（对应 AC-5）</done>
  <depends_on></depends_on>
</task>

---

## Wave 2 · L2 prompt gate + L3 证据链（并行 · depends Wave 1）

<task id="T04" parallel="true" status="done">
  <name>0-change.md + 1-requirement.md 反问 gate 强化为填空式</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/RULES.md
    .specs/weak-model-robustness/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
  </write_files>
  <action>
    把 0-change / 1-requirement 的反问环节强化为"反问 gate"：反问未完成不许进下一步。
    关键产出（CHANGE.md / REQUIREMENT.md）改为**填空模板式**（D3）——弱模型必须填空才能产出，无法跳过。
    反问清单保持 ≤ 3 个/轮（避免啰嗦，AC-7）。
  </action>
  <verify>for f in 0-change 1-requirement; do grep -qE "反问 gate|填空" flow-kit-bundle/flow-kit/prompts/$f.md || exit 1; done</verify>
  <done>两 prompt 含填空式反问 gate（对应 AC-1 的 prompt 侧）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T05" parallel="true" status="done">
  <name>2-design.md 加证据链（引用前 grep/read 验证）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/RULES.md
    .specs/weak-model-robustness/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/2-design.md
  </write_files>
  <action>
    在 2-design §0.5（既有架构对齐）强化为证据链触发点：列出"触碰模块"时必须来自实际 grep/ls（已有），并在引用任何文件/API/抽象前必须 grep/read 验证存在（L3）。未验证的引用必须显式标注"未找到"或拒绝引用。
  </action>
  <verify>grep -qE "grep|read.*验证|证据链|未找到.*拒绝" flow-kit-bundle/flow-kit/prompts/2-design.md</verify>
  <done>2-design prompt 含引用前验证指令（对应 AC-2 的设计阶段侧）</done>
  <depends_on>T01</depends_on>
</task>

<task id="T06" parallel="true" status="done">
  <name>4-dev.md 加证据链 + 关键节点 checkpoint + 动手前复述边界</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/RULES.md
    .specs/weak-model-robustness/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
  </write_files>
  <action>
    在 4-dev 入场加"动手前复述当前 task 的 read_files/write_files 边界 + 范围排除"（AC-4）；
    加"关键节点 checkpoint"：开始编辑文件前 / 遇测试或验证失败时 / 切换 task 时 → 强制 `/flow checkpoint`（非每操作，AC-3/AC-7）；
    加证据链：编辑/引用任何文件/API/字段前必须 grep/read 验证存在（L3，AC-2）。
  </action>
  <verify>grep -cE "证据链|checkpoint|复述.*(边界|read_files|write_files)" flow-kit-bundle/flow-kit/prompts/4-dev.md | grep -qv ^0</verify>
  <done>4-dev prompt 含证据链 + 关键节点 checkpoint + 复述边界（对应 AC-2/AC-3/AC-4 的 dev 侧）</done>
  <depends_on>T01</depends_on>
</task>

---

## Wave 3 · 验收（并行 · depends Wave 1+2）

<task id="T07" parallel="true" status="done">
  <name>bats 结构测试（no-skip-clarify + checkpoint-keynodes + goal-anchored）</name>
  <read_files>
    flow-kit-bundle/flow-kit/RULES.md
    flow-kit-bundle/flow-kit/GO.md
    flow-kit-bundle/flow-kit/prompts/0-change.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    .specs/weak-model-robustness/REQUIREMENT.md
    test/**/*.bats
  </read_files>
  <write_files>
    test/weak-model-robustness/no-skip-clarify.bats
    test/weak-model-robustness/checkpoint-keynodes.bats
    test/weak-model-robustness/goal-anchored.bats
  </write_files>
  <action>
    写 3 个 bats 结构测试：① no-skip-clarify 验 RULES R3 + 0-change/1-requirement 含反问 gate；② checkpoint-keynodes 验 4-dev 含关键节点 checkpoint 且无非条件"每操作"措辞；③ goal-anchored 验 GO.md + 各阶段含 goal 锚定点。沿用既有 bats 风格（参考 test/**/*.bats）。每个测试 grep 目标文件断言。
  </action>
  <verify>npx bats test/weak-model-robustness/no-skip-clarify.bats test/weak-model-robustness/checkpoint-keynodes.bats test/weak-model-robustness/goal-anchored.bats</verify>
  <done>3 个 bats 测试通过（对应 AC-1/AC-3/AC-5 验收）</done>
  <depends_on>T01, T03, T04, T06</depends_on>
</task>

<task id="T08" parallel="true" status="done">
  <name>regression-demo check.sh（hallucination-guard + scope-drift-guard）</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/RULES.md
    .specs/weak-model-robustness/REQUIREMENT.md
    flow-kit-bundle/flow-kit/regression-demos/brooks-lint-paths.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh
    flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/scenario.md
    flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh
    flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/scenario.md
  </write_files>
  <action>
    建 2 个 demo：① hallucination-guard 含诱导幻觉场景（scenario.md 要求引用不存在的模块）+ check.sh 验护栏措辞存在（4-dev/2-design 含"引用前验证"指令 + RULES R6 禁凭空假设）；② scope-drift-guard 含诱导越界场景 + check.sh 验 4-dev 含复述边界指令 + RULES R7。check.sh 为静态行为特征检查（D4 脚本模拟），不真跑模型。
  </action>
  <verify>bash flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh && bash flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh</verify>
  <done>2 个 demo 的 check.sh 通过（对应 AC-2/AC-4 验收）</done>
  <depends_on>T01, T05, T06</depends_on>
</task>

<task id="T09" parallel="true" status="done">
  <name>regression-demo strong-model-verbosity/check.sh（AC-7 静态啰嗦度检查）</name>
  <read_files>
    flow-kit-bundle/flow-kit/RULES.md
    flow-kit-bundle/flow-kit/prompts/4-dev.md
    flow-kit-bundle/flow-kit/GO.md
    .specs/weak-model-robustness/REQUIREMENT.md
    .specs/weak-model-robustness/DESIGN.md
  </read_files>
  <write_files>
    flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh
    flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/scenario.md
  </write_files>
  <action>
    建 verbosity demo：check.sh 静态检查加固内容**不含重复唠叨模式**——grep 断言加固段无"每步""每次操作"等无条件强制词，且 gate 段是填空式（非冗长自由清单）。scenario.md 说明：定量 token/turn < 20% 阈值需 v2 自动化（真跑强模型），本次靠静态检查 + 人工定性。
  </action>
  <verify>bash flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh</verify>
  <done>verbosity check.sh 通过（对应 AC-7 验收 · 静态检查版，定量阈值 v2）</done>
  <depends_on>T01, T03, T04, T06</depends_on>
</task>
