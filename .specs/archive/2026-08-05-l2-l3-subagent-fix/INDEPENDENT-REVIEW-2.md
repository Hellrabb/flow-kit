# 独立审查 · 阶段 2

## L2 盲审

**审查阶段**: 2-design · **Change**: l2-l3-subagent-fix · **工件**: DESIGN.md（参考 CHANGE.md / REQUIREMENT.md / CONTEXT.md / ARCHITECTURE.md / ADR-020）

**结论先行**: DESIGN 是一份合格的调查型设计——0.5.1 触碰清单的行号引用经逐项 grep 复核全部准确（l2_dispatch_agent@L128 / fk_resolve_model@L239-270 / l3-api.sh L20-21 / gate-checks-basic.sh L53-90 / 29-independent-review.sh L161 / prompts 1/2/3/5/6/7 subagent_type 映射与架构图一致），D1-D6 决策均有备选 + 理由 + 取舍，禁动清单边界正确。核心缺陷是**调查范围的两个盲点**：① opencode 子 agent 模型绑定层（harness/category 层，ADR-020 已锁定的知识）未纳入调查计划；② claude code 侧 agent 定义（`~/.claude/agents/`）未入调查范围——本机实测 qa-expert 双平台已分歧（opencode `model: sonnet` vs claude code `model: inherit`），恰是 D5 候选 ② 的现成对照证据，计划却未安排对比动作。两处均🟡，建议在 TASK 拆解前修 DESIGN。Verdict: **pass**（无 Critical），2 🟡 入 fix loop，3 🟢 入 MINOR-DEFERRED。

---

### 🟡 R1 · 调查范围盲点：opencode 子 agent 模型绑定层（harness/category）未纳入四环节，撞 ADR-020 已锁知识
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN.md §2 双平台差异焦点（L121-123）+ §0.5.1 触碰模块（L43）把 opencode 侧模型解析锚定在 `~/.config/opencode/agents/*.md` 的 `model:` 字段；而 ADR-020（2026-08-03 已接受，本仓库内）L18-25 实测记录：opencode 模型选择发生在三层——Harness 配置层（按 agent type 绑定 model）/ Category 路由层（category→模型 tier）/ 子 agent 覆盖层，task() 参数仅 `subagent_type` + `category` 两个路由维度。调查计划未安排任何验证"子 agent 实际模型由哪一层决定"的步骤，D5 候选 ② 的假设空间仅覆盖 agent 定义文件一层。
**Source（源头）**：ADR-020 §验证过程 L18-25 + §Consequences；阶段 2 checklist「是否撞既有架构 / 已锁决策（对照 CONTEXT.md / ARCHITECTURE.md）」；DESIGN 0₋ 自述"ADR-020 可能受根因影响"，但只把 ADR-020 当 v2 更新对象，未吸收其正面结论（subagent_type 受支持、模型绑定在 harness 层）。
**Consequence（后果）**：若 qa-expert 拉不起来的断点位于 harness/category 绑定（agent type 未绑定或绑到不可解析模型），按现有计划实测会复现失败但根因链归因错误层 → D5 候选 ②（改用户 agent 定义 `model:` 字段）是无效修复 → AC-4 opencode 实测拉起失败 → 返工重调查。风险表 R1-R5 亦无此条目（关键风险遗漏）。
**Remedy（修补）**：环节③/④ 增加「opencode 子 agent 模型绑定层验证」子步骤：确认本环境 harness/category 对 qa-expert / architect-reviewer / code-reviewer 的模型绑定（task() 路由实际落到的模型 ID），ROOT-CAUSE.md 差异矩阵显式回答"子 agent 模型由哪一层决定"；§5 风险表补一条（根因错层归因，概率低-中）。

### 🟡 R2 · 双平台 agent 定义对比缺失：`~/.claude/agents/` 未入调查范围，本机已存在 qa-expert 分歧（sonnet vs inherit）
**Severity**：🟡 Important
**Symptom（症状）**：DESIGN.md §0.5.1 L43 运行时 agent 定义调查对象仅列 `~/.config/opencode/agents/{qa-expert,architect-reviewer,code-reviewer}.md`（opencode 侧）；未列 claude code 侧 `~/.claude/agents/` 同名定义。盲审实测（grep 本机两目录）：`~/.config/opencode/agents/qa-expert.md:4` → `model: sonnet`；`~/.claude/agents/qa-expert.md:5` → `model: inherit`；其余两个 agent 双平台均为 inherit。两平台 qa-expert 定义**已经分歧**。
**Source（源头）**：AC-2「每条根因有 opencode 与 claude code 各至少一次实测 + 双平台差异矩阵」；L-031 跨文件一致性锚点扫描——同 agent（qa-expert）双平台定义是差异矩阵的天然对比锚点，DESIGN 触碰清单漏列一侧即"DESIGN 漏列"类。
**Consequence（后果）**：差异矩阵建立在缺一侧证据上；qa-expert 恰是分歧点（opencode=sonnet / claude=inherit），按现有计划调查会把它归为"opencode 单平台问题"，而非"双平台差异问题"——而 D5 候选 ② 的修复理由"sonnet 在 opencode 不可解析"正是这份分歧的直接推论，现成的双平台对照证据被浪费；若根因实为分歧（而非单侧解析失败），修复只改 opencode 侧、claude 侧维持 inherit，对照维度缺失导致报告归因不完整。
**Remedy（修补）**：§0.5.1 触碰模块补入 `~/.claude/agents/{qa-expert,architect-reviewer,code-reviewer}.md`（纯读操作，不触碰禁动清单）；ROOT-CAUSE.md 差异矩阵增加「agent 定义对比」行（双平台 model 字段逐 agent diff），并作为 D5 候选 ② 的第一个验证动作。

### 🟢 R3 · 触碰清单漏列 gate-checks-review.sh（L-031 锚点扫描）
**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN.md §0.5.1 环节② 触碰模块列出 independent-review-gate.sh / gate-helpers.sh / gate-helpers-types.sh / gate-checks-basic.sh，未列 gate-checks-review.sh；实测 `gate-checks-review.sh:24` 调 `fk_extract_l2_verdict`（L2 verdict 提取）、`:65` 调 `_gate_check_l2`——是环节② 的 L2 verdict 消费方，而 fk_extract_l2_verdict 已列在触碰清单（l2-detect.sh 环节①），同函数在 gate 侧的调用点却未列。
**Source（源头）**：L-031 跨文件一致性扫描（同符号全仓命中清单 vs DESIGN 清单比对）；DESIGN 0.5.1 自称"grep 验证"。
**Consequence（后果）**：调查顺藤摸瓜到 fk_extract_l2_verdict 时可能漏查 gate 侧 verdict 消费路径。对"拉不起来"主线影响低（该路径是审查结果读取，非派发），但清单不完整与 0.5.1 承诺不符。
**Remedy（修补）**：触碰清单补一行：`gate-checks-review.sh（环节② · L24 fk_extract_l2_verdict / L65 _gate_check_l2）`。

### 🟢 R4 · §9.2 决策表与 §4「v1 无新增 ADR」张力：agent model 声明规范无 ADR 载体
**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN.md §9.2 以决策表形式给出「opencode agent model 声明规范」（取值/影响范围/推翻代价），但 §4 声明"v1 无新增 ADR"；若 D5 候选 ② 经用户确认实施，该跨 opencode 子 agent 派发的约束将无正式决策记录。
**Source（源头）**：项目已锁决策均应入 ADR 的机制；ADR-019 写作原则；§9.2 自身标注"建议（随报告，非本次实施）"与决策表格式冲突。
**Consequence（后果）**：「agent model 字段须用本环境可解析值，禁止 sonnet 等别名」成为口头决策，后续 change 重新踩坑或用户确认修复时无决策留痕。
**Remedy（修补）**：若 D5 ② 确认实施，随修复补一条简短 ADR（或 CONTEXT.md 已锁决策条目）；§9.2 表述改为"候选决策（待根因确认后升格）"。

### 🟢 R5 · D2/D3 中「R2 修复」「R3 修复」编号歧义
**Severity**：🟢 Minor
**Symptom（症状）**：DESIGN.md L84「实测输出必含凭证值（R2 修复）」、L85「（R3 修复 + l2-l3-test-defect BUG-G 假绿教训）」——R2/R3 与 §5 风险表编号重合（R2=凭证泄露 / R3=假绿），读作外部根因编号造成歧义。
**Source（源头）**：文档清晰性原则；§5 风险表编号是全文唯一 R 编号空间。
**Consequence（后果）**：读者把"缓解风险 R2"误读为"根因 R2 的修复"，ROOT-CAUSE.md 阶段的 R 编号（R2 凭证 / R3 假绿已作为修复对象被引用）与 DESIGN 风险表冲突。
**Remedy（修补）**：改为「（缓解风险 R2）」「（缓解风险 R3）」。

---

**复核确认（无发现项）**：0.5.1 触碰模块全部文件存在且行号准确；fk_resolve_model 三级链与 §2 架构图一致（L2: ANTHROPIC_L2_MODEL > FLOW_KIT_L2_MODEL > .goal.l2_model）；prompts 六文件 subagent_type 映射（qa-expert 1/5 · architect-reviewer 2/3/7 · code-reviewer 6）与 l2-detect.sh 的 agent_type case 及架构图三方一致；claude CLI 2.1.71 实测确认；STATE.md 归档基线 662/662（test-failures-fixup-2026-08 · 2026-08-03）与当前 710 @test 实测确认；L2-blind-review.md 存在；qa-expert model: sonnet 前提（D5 ②）实测成立。

**Verdict**: pass
