# 独立审查 · 阶段 2

## L2 盲审

> 审查对象：`.specs/dsh-flow-kit-sync-2026-09/DESIGN.md`（补档设计文档）
> 参照：`CHANGE.md`、`dsh-flow-kit/DESIGN.md` §8、`dsh-flow-kit/lib/flow-state.js`、
> `dsh-flow-kit/test/flow-state.test.mjs`、`flow-kit-bundle/hooks/stop/lib/common.sh`、
> `flow-kit-bundle/hooks/stop/lib/correction-file.sh`、
> `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh`、
> `flow-kit-bundle/skills/flow/SKILL.md`。
> 独立结论：全部结论来自对上述工件的直接核读（git diff 2999024..HEAD = 868f362/0981bd7），
> 未引用主 agent 自评/草稿/概述/辩护。

### 🔴 Critical

无。

### 🟡 R1 · doctor correction 摘要只读 `check`，与 compliance 类 `rule` 字段契约冲突：安全类纠正被渲染成「?」
**Severity**：🟡 Important
**Symptom（症状）**：`dsh-flow-kit/lib/flow-state.js:399` 用 `violations.map((v) => v?.check ?? "?")` 去重生成摘要；`.specs/dsh-flow-kit-sync-2026-09/DESIGN.md:13,29` 把该摘要描述为「violations[].check 白名单 / 去重后的 check 逗号列表」。但 `.flow-active.correction` 的 violations 是异质 schema：compliance 类（28 号 hook → `weak-model-compliance.sh:166-189`）写 `{rule, location, fix, layer}`，**没有 `check` 字段**；只有 state-integrity 类（33 号 hook → `33-flow-active-integrity.sh:399`）才写 `check` + `field` + `message`。合并类型（如 `compliance+state-integrity`，`33-flow-active-integrity.sh:409`）更会让两类条目同现于一个 violations 数组。
**Source（源头）**：`correction-file.sh` 与 `weak-model-compliance.sh` 定义的两类 violation 对象字段不同（check vs rule）；ADR-013/024 明确 compliance 类条目「preserved byte-identical / 永不参与去重」。新 doctor 特性只复制了 state-integrity 类的 `check` 知识（R3 知识重复 + R6 领域扭曲），把 `check` 当作全 schema 通用字段。
**Consequence（后果）**：type=compliance（ADR-013 专门保护的「非 CC 用户安全信息」）时，doctor 输出 `type=compliance, violations=N (?)`，把可定位的 `rule`（如「L1: 触碰禁动文件」）显示成无意义的「?」；合并类型下则是 `(?, stale_updated_at, corrupt_json)` 混排。现有测试（`flow-state.test.mjs` 新增用例）只覆盖带 `check` 的 state-integrity 与无 violations 的 model-missing，**未覆盖 compliance 类**，故 20/20 全绿仍漏此缺陷。
**Remedy（修补）**：摘要字段做 `check` → `rule` 回退，并对 compliance 类给出语义化标签。例如：
```js
// before
const checks = [...new Set(violations.map((v) => v?.check ?? "?").filter(Boolean))].join(", ");
// after
const checks = [...new Set(violations.map((v) => v?.check ?? v?.rule ?? "?").filter(Boolean))].join(", ");
```
并在 `flow-state.test.mjs` 补一条 compliance 形状用例：
```js
await writeFile(join(root, ".flow-active.correction"), JSON.stringify({
  type: "compliance",
  violations: [{ rule: "L1: 触碰禁动文件", location: "src/x", fix: "撤销", layer: "L1" }],
}), "utf8");
result = await runFlowCommand("doctor", undefined);
assert.match(result.text, /L1: 触碰禁动文件/);
```

### 🟢 R2 · DESIGN.md 声称优先级链文案与 shell 注释「逐字一致」，实际既非逐字、也非引自 shell 注释
**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/dsh-flow-kit-sync-2026-09/DESIGN.md:24` 写「展示优先级链文案与 shell fk_resolve_model 注释逐字一致」。实际 `flow-state.js:354` 是通配缩写（`ANTHROPIC_* env > FLOW_KIT_*_MODEL env > .goal.l*_model…`），其真正对齐源是 `SKILL.md:258`（`.flow-active.goal.l*_model` / 「env var」），而 shell 注释（`common.sh:242-245`）是分 L2/L3 两行、带完整字段名与「/flow model l3-default=」注解的全文。
**Source（源头）**：可追溯性要求——设计文档对「实现与哪一契约源对齐」的声明必须准确；此处引用了错误的源（shell 注释）且用「逐字」过度承诺。
**Consequence（后果）**：后续维护者按 DESIGN.md 去 shell 注释核对时找不到对应文案，误判为漏改；纯文档可追溯性缺陷，不影响运行。
**Remedy（修补）**：把 DESIGN.md:24 改为「展示优先级链文案与 SKILL.md L258 优先级链语义一致（通配缩写：`.flow-active.goal.l*_model` → `.goal.l*_model`）」，或让 `flow-state.js:354` 与 SKILL.md 原文逐字一致。

### 🟢 R3 · 上游 common.sh 注释头仍写「3-tier priority chain」，与本次「五级链」同步自相矛盾
**Severity**：🟢 Minor
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/common.sh:238` 注释头仍为「fk_resolve_model() · L2/L3 model resolution (3-tier priority chain)」，而函数体（common.sh:256-268）已实现 5 级链（含 tier-4/5 `FLOW_KIT_L{2,3}_DEFAULT_MODEL` + `.goal.l{2,3}_default_model`）。该文件由内容层自动拷贝进 dist，陈旧注释随之带出。
**Source（源头）**：本 change 标榜「L2/L3 站点默认模型五级链」；源注释与其标榜的层级数矛盾，属上游内容层残留（非 dsh JS 契约错误，本 change diff 未触碰该文件）。
**Consequence（后果）**：读者按注释头会误以为仍为 3 级解析；不影响函数实际行为（5 级正确），纯文档误导。
**Remedy（修补）**：上游修正 `common.sh:238` 头为「(5-tier priority chain)」后重跑 `package-dsh-plugin.sh` 重拷贝；或在 MINOR-DEFERRED.md 登记为上游跟进项。

### 🟢 R4 · 「四层同步义务」表只枚举契约层，版本层/验证层未落表
**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/dsh-flow-kit-sync-2026-09/DESIGN.md:6` 标题为「四层同步义务（内容/契约/版本/验证）」，但第 8-9 行只覆盖内容层（prose）与契约层，第 11-15 行表格三行全部是契约层；版本层（`package.json` 0.1.0→0.2.0，已核实）与验证层（插件单测 20/20、vendor 逐字节 diff、root bats 770）均未落表。
**Source（源头）**：本 change 自身宣称的四层同步契约（`dsh-flow-kit/DESIGN.md` §8 的四层义务）；补档表未逐层对应，标题承诺与内容不对齐。
**Consequence（后果）**：归档读者无法从「四层义务表」逐层核销版本/验证义务，可追溯性打折；纯文档完整性问题。
**Remedy（修补）**：在表中补两行「版本层 | package.json | 0.1.0 → 0.2.0（minor）」「验证层 | package-dsh-plugin.sh + vendor diff + bats | 20/20 + 770 ok」；或将标题收窄为「内容/契约两层义务」。

### 交叉一致性核对（L-031）

- `l2_model` / `l3_model` / `l2_default_model` / `l3_default_model`：shell `fk_resolve_model`（common.sh:259-267）读 `.goal.l{2,3}_model` 与 `.goal.l{2,3}_default_model`；JS `fieldOf`（flow-state.js:363）写同名四键；SKILL.md:237/259 文档与测试断言（flow-state.test.mjs:156-172）同字段——四处一致，无漏改。✅
- `/flow model` 五级顺序：JS 回显（flow-state.js:349-354）与 shell 解析顺序（common.sh:256-268）、SKILL.md:258 语义一致（L3 首级 `ANTHROPIC_DEFAULT_HAIKU_MODEL`、L2 首级 `ANTHROPIC_L2_MODEL`、tier-4/5 默认级）。✅
- `--clear <l2|l3|l2-default|l3-default>`：JS（flow-state.js:369-372）与 SKILL.md:254 一致；`nextGoal = {...goal}` 仅改 4 键，测试断言 `gate_config` 不变。✅
- correction 类型标签：doctor（flow-state.js:396-400）对 `l2-missing+state-integrity`、`l3-model-missing`、`compliance` 均按 `type` 原样输出，与 shell 写类型一致；但 `violations[].check` 只覆盖 state-integrity 类，compliance 类 `rule` 字段漏读（见 R1）。❌
- 版本层：`package.json` version=0.2.0，`files` 含 `vendor/skills/flow-kit/hooks/brooks-lint/docs`（AC-4 满足）。✅
- 测试计数：插件单测 8+6+4+2=20（「19→20」自洽）；root bats 770 与 CHANGE/TEST/VERIFY 一致（本阶段未重跑全量 bats，计数以归档记录为准）。✅
- PRESET_MAP / gate_config：本 change 未改（git diff 确认），既有 `independent|true→both` 归一语义不变。✅

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-03 16:14）

> 自动生成于 2026-09-03 16:14。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN — dsh-flow-kit-sync-2026-09（阶段 7 补审归档）",
      "issue": "ADR-011 的决策「G1 pipeline 模式不调 fk_auto_phase」与 DESIGN.md §8 同步契约/既有 toll-gate 三道防线的关系未在工件中给出可验证的交叉引用；工件只声明「本 ADR 破例记录 · ARCHITECTURE §2.2」，但未说明 fk_auto_phase 的 gate_active 保护为何不足以覆盖 pipeline goal（flow-kit-artifacts.sh:111 与 26-workflow.sh:90 的调用链中 gate 检查的精确语义缺失）。",
      "why": "ADR-011 是禁动清单破例，其合理性完全依赖「pipeline goal + review 未开阶段仍 advance」这一缺陷的机制解释；若 gate_active 保护本应在 fk_auto_phase 内部阻止该 advance，则真正的 bug 在 fk_auto_phase 而非调用方，决策「只改调用方、不改函数」可能掩盖根因。工件未给出 flow-kit-artifacts.sh:111 的具体 gate 检查条件，无法判断该破例是否撞既有架构的 gate 防线。",
      "fix": "在 ADR-011 中补充 flow-kit-artifacts.sh:111 gate_active 的检查条件（读取哪些状态、为何 pipeline goal + review 未开阶段时该条件为真），并显式论证为何不能/不应在 fk_auto_phase 内增加 pipeline scope 守卫；若 gate_active 本就该拦截，则改为修复 fk_auto_phase 而非调用方破例。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN — dsh-flow-kit-sync-2026-09（阶段 7 补审归档）",
      "issue": "四层同步义务表中「契约层：PRESET_MAP / gate_config — 无变化 — 只读核对」与「版本层 package.json 0.1.0 → 0.2.0（minor）」之间缺少版本提升依据的说明：minor bump 是否因契约层有行为变化而本应 major，或内容层/版本层变更是否应走 minor，未给出理由。",
      "why": "同步契约的版本层决策会直接影响下游消费方（读取 .flow-active 或 PRESET_MAP 的工具）的兼容性判断；若本次 JS 侧改动改变了 doctor 摘要语义或模型字段写/清行为，而版本号仅 minor，可能低估破坏性。工件只列了动作，未记录 ADR 级别的版本策略决策。",
      "fix": "在关键决策记录中补一条：0.1.0 → 0.2.0 的 minor bump 依据（例如契约字段新增不破坏旧读取方、或按上游 semver 惯例），或改为 major 并说明理由。"
    },
    {
      "file": "DESIGN — dsh-flow-kit-sync-2026-09（阶段 7 补审归档）",
      "issue": "doctor correction 报告「check → rule 回退（state-integrity 类写 check，compliance 类写 rule——异质 schema，phase 2 R1）」未说明回退逻辑的判定边界：当 violations 数据中某个 type 同时存在 state-integrity 与 compliance 的混合语义时，摘要字段应取哪一个；且「仍缺失才用 ?」的缺失判定没有定义（是字段不存在、值为空字符串、还是 null）。",
      "why": "异质 schema 回退是 doctor 报告正确性的关键路径；边界未定义会导致同一输入在不同实现下产生不同摘要，违反 ADR-019 的确定性断言原则，且该风险未在风险段列出。",
      "fix": "在 DESIGN 中补充 type→字段映射表（state-integrity→check、compliance→rule、其他→??），并明确定义「缺失」的判定条件；若混合 type 存在，规定优先级或拒绝策略。"
    },
    {
      "file": "DESIGN — dsh-flow-kit-sync-2026-09（阶段 7 补审归档）",
      "issue": "风险段缺失「降挡提交期间 gate off 带来的验证漏洞」风险：表内验证层列出 20/20 + 770 ok + 逐字节 diff 空，但关键决策记录同时声明「降挡提交（gate off）只作为过渡」，两者未交叉说明 gate off 是否影响 TEST.md 所列验证的执行（例如某些测试依赖 gate 开启才能暴露 AC-K 类问题）。",
      "why": "gate off 是本次 change 的临时状态，若验证层测试未在 gate on 条件下完整执行，则「20/20 + 770 ok」不能证明合规；工件未说明这些测试是否在 gate_config=all 下运行，属验证完整性风险遗漏。",
      "fix": "在验证层或关键决策记录中补充：所列测试结果是否在 gate_config=all 下取得；若否，说明 gate off 对测试覆盖的具体影响及补审计划。"
    }
  ],
  "verdict": "pass",
  "summary": "ADR-011 破例缺少 fk_auto_phase gate_active 机制细节，无法完全排除根因误判，但无致命缺陷，整体设计可接受。"
}
```

L3_artifact_hash: 3e74bdddfab0d37a897edb4ca48e777e314e94d199ed80f02df270dd677fed34
