# 独立审查 · 阶段 2

## L2 盲审

> 审查日期：2026-07-07 | 审查对象：`.specs/l3-comprehensive-fix/DESIGN.md` | 参考：REQUIREMENT.md、CHANGE.md、CONTEXT.md

---

### 🟡 R1 · D1/R1 header grep 策略前后矛盾：决策表与风险缓解的 grep 范围不一致

**Symptom（症状）**：DESIGN.md:81 D1 决策理由写"只改 `flow-kit-resume.sh:138` 一处 grep"；但 DESIGN.md:196 R1 缓解措施写"`flow-kit-resume.sh` 同时 grep 新旧两种 header（`## L3 盲审` OR `## L3 外部模型审查`）"。一处说单 grep、一处说双 grep，实施者读到会困惑到底该改什么。

**Source（源头）**：D1 决策仅考虑了"向前统一到新 header"的改动量，没有在同一决策中纳入向后兼容的代价。R1 作为风险缓解追加了兼容逻辑，但 D1 决策理由未更新。

**Consequence（后果）**：实施者可能仅改 grep 字符串为 `## L3 盲审`（按 D1），忽略 R1 的双 grep 要求，导致历史 `INDEPENDENT-REVIEW-*.md` 文件（含旧 header `## L3 外部模型审查`）在 SessionStart 仍不可见——AC-1 对历史文件失效。

**Remedy（修补）**：D1 决策理由应更新为"改动面最小（`flow-kit-resume.sh:138` 一处 grep 改为主匹配 `## L3 盲审`，同时以 `||` 追加旧 header `## L3 外部模型审查` 作为兼容回退）"，使 D1 和 R1 的表述一致。

---

### 🟡 R2 · AC-2 验证依赖外部 API 却无测试替代策略——截断正确性无法离线验证

**Symptom（症状）**：REQUIREMENT.md:32-33 AC-2 验证方式要求"使用 `test/fixtures/l3-truncation-30k.md`（预置 30KB REVIEW.md，含 3 个故意植入的缺陷），3 轮 L3 调用的 critical 均值 ≤ 4"。该验证依赖 L3 API 真实调用（外网 + 鉴权），不可离线、不可重复、结果非确定性。DESIGN.md 未提供任何离线可验证的截断正确性测试策略。

**Source（源头）**：AC-2 的验证方式将智能截断算法的正确性与外部模型的审查质量耦合在一起。截断算法本身（awk 状态机是否完整保留了所有标题行和 AC 行）是确定性的、可单元测试的；但当前验证方式将其与 L3 模型的审查结果混为一谈。

**Consequence（后果）**：① 离线环境（无 API key、无网络）无法验证截断算法是否正确实现。② L3 模型升级/切换后，同样的截断算法可能因模型审查风格变化而产生不同的 critical 计数，导致 AC-2 假失败。③ 回归测试无法自动化——每次改截断逻辑都必须调 L3 API 做 3 轮验证，耗时且不可靠。

**Remedy（修补）**：将 AC-2 验证拆为两层——(a) 确定性单元测试：对 test fixture 运行 awk 截断，断言输出包含全部 `##`/`###` 标题行和 Given/When/Then AC 行，且输出大小 ≤ 设定上限；(b) 集成验证（保留现有 AC 但标注为 manual-only）：3 轮 L3 调用验证假阳性控制。DESIGN.md 应补充 (a) 的测试策略。

---

### 🟡 R3 · `fk_resolve_phase()` 被降级为"架构沉淀建议"而非 v1 交付物——R4 风险因此成为自证预言

**Symptom（症状）**：DESIGN.md:217-222 将 `lib/common.sh::fk_resolve_phase()` 列为"9.1 新增的可复用抽象"和"9.2 新增的项目级技术决策"，但标题为"架构沉淀**建议**"（非强制）。与此同时 DESIGN.md:199 R4 明确警告："若未来新增第 4 处 phase 读取点，可能忘记应用同样逻辑"，并将概率评为"中"。设计文档一方面承认 3 处散落修改必然导致未来回归，另一方面又不把统一函数列为 v1 必做。

**Source（源头）**：REQUIREMENT.md AC-7 仅约束 Stop hook 的 phase 检测行为，未要求抽取共享函数。但设计文档的职责是预判并防范可预见的回归——CONTEXT.md:193 已锁决策明确 phase 检测统一入口应是项目级技术决策。

**Consequence（后果）**：v1 实施时 3 处 phase 检测各自内联 pipeline-aware 逻辑（Stop hook:29 / SessionStart:resume / PreToolUse gate: 已有），代码重复、未来第 4 处 hook 必然漏改。R4 从"可预防的风险"变成"已知必然发生的技术债"。

**Remedy（修补）**：将 `fk_resolve_phase()` 从"建议"提升为 v1 交付物，在 DESIGN.md 0.5.2 的"沿用/新增"表中列为"新增"，在 9.2 中标注为"本次实施"而非"建议"。3 处 hook 改为调用 `fk_resolve_phase()` 而非各自内联，并追加 bats 测试（输入 pipeline scope + current_phase=5, .phase=6 → 期望输出 5）。

---

### 🟡 R4 · AC-5 选项 ② 和 ③ 设计不完整——用户交互契约未定义

**Symptom（症状）**：REQUIREMENT.md:52-53 AC-5 要求 PreToolUse gate 输出 3 个选项：① 派 L2（一键命令）② 跳过 L2（需显式确认风险）③ 回退等待。DESIGN.md D5 仅设计了选项 ① 的命令模板，2.1 数据流中提及了 3 个选项但未定义 ② 如何"显式确认风险"（是用户输入 `yes` 还是设置环境变量？）、③ "回退等待"在 hook 上下文中如何实现（hook 不交互，只能 deny + 输出提示后 exit）。

**Source（源头）**：PreToolUse hook 是无状态拦截器——只能 deny（阻止 tool call）或 allow（放行）。选项 ② 和 ③ 需要某种形式的用户意图传递机制（如写标记文件供下次 gate 检查），但设计未指定。

**Consequence（后果）**：实施者面对 AC-5 的 ②③ 选项时无设计指导，可能实现为：(a) 仅打印提示但不真正支持跳过/回退（选项形同虚设）；或 (b) 自行发明一套状态传递机制但与其他 hook 模块不一致。

**Remedy（修补）**：在 DESIGN.md 补充 AC-5 选项 ②③ 的交互设计：②"跳过 L2"→ gate 写 `.skip-L2-<phase>` 标记文件，下次 gate 检查时若标记存在 + 用户已确认风险（如设置 `FLOW_KIT_SKIP_L2=1` 环境变量），则放行；③"回退等待"→ gate deny 当前 transition，用户需先完成 L2 再重试切阶段（这是当前 gate 的默认行为，只需在提示中说明"完成 L2 后重新执行 transition 即可"）。

---

### 🟡 R5 · 缺少测试策略——Bash hook 变更无自动化回归防护

**Symptom（症状）**：DESIGN.md 全文无测试策略章节。变更涉及 11 个既有模块（含 hook 脚本和 prompt 文件）+ 2 个新增模块，修改逻辑覆盖 phase 检测、header 匹配、截断算法、done 文件生命周期。无一处说明这些变更如何被自动化测试覆盖。

**Source（源头）**：CHANGE.md:48 验收线要求"通过 `npx bats test/` 全部测试"，CONTEXT.md:200 记录了项目测试策略（bats-core，94 tests）。但 DESIGN.md 未继承此要求——未说明哪些变更需要新 bats 测试、现有测试是否需要修改。

**Consequence（后果）**：① 实施者可能不写新测试，仅依赖现有 94 个 tests 的通过率（现有 tests 不覆盖本次变更的逻辑）。② 回归风险高——D2 的 awk 截断、D3 的 phase 检测、D4 的 L2 检测均无自动化防护。③ 后续 change 可能无意中破坏本次修复。

**Remedy（修补）**：在 DESIGN.md 新增"7. 测试策略"章节，至少覆盖：(a) `l3-review.sh` 截断函数单元测试（输入 30KB fixture，断言标题/AC 保留）；(b) phase 检测逻辑测试（pipeline/单阶段两种模式的 phase 解析）；(c) L2 检测 lib 的 done 文件状态判定测试；(d) 现有 bats 回归验证（确保不改坏已有行为）。

---

### 🟡 R6 · 智能截断算法未定义——awk 状态机的行为规范缺失

**Symptom（症状）**：DESIGN.md:82 D2 将截断策略描述为"awk 状态机保留标题+AC"，但未给出：(a) 状态机的状态定义和转移条件；(b) "保留标题+AC"的具体规则——是保留标题行本身，还是保留标题行及其下所有内容直到下一个标题？(c) 当单条 AC 的 Given/When/Then 超长（>2000 chars）时如何处理？(d) 截断后如何告知模型上下文（截去了哪些章节、原始大小 vs 截断大小）？

**Source（源头）**：REQUIREMENT.md:28-31 AC-2 有两个硬约束（所有标题行必须保留、AC 行必须完整保留）和一个软约束（告知模型截断上下文）。DESIGN.md D2 仅以自然语言描述了目标，未给出足以让实施者无歧义实现的规范。

**Consequence（后果）**：实施者自行理解"保留标题+AC"可能产生不同实现：A 理解为"保留标题行 + 标题下的 AC 段落 + 截断其余"（较完整但可能超限）；B 理解为"仅保留标题行和 Given/When/Then 行，其余全截"（过度精简）。两种实现对 L3 审查质量的影响截然不同，AC-2 的验证结果不可复现。

**Remedy（修补）**：补充截断算法伪代码或自然语言规范：(1) 第一遍扫描：收集所有 `##`/`###` 标题行号和文本；(2) 第二遍：按标题分段，每段保留标题行 + 该段内所有 Given/When/Then 行（完整句子，非截断）；(3) 按标题优先级（层级深者优先保留完整段）填充至字符上限；(4) 截断标记行注明原始字符数/截断后字符数/被移除的章节标题列表。

---

### 🟢 R7 · 章节编号跳跃：从 §6 直接跳到 §9

**Symptom（症状）**：DESIGN.md 目录结构：§5 风险 → §6 不在范围 → §9 架构沉淀建议。缺少 §7 和 §8。

**Source（源头）**：可能是模板预留的"实施计划"和"迁移策略"章节未填充但编号未调整。

**Consequence（后果）**：无功能影响，但暗示设计文档不完整或有遗漏章节。

**Remedy（修补）**：若 §7/§8 无内容则删除编号或标注"（预留）"；若有内容（如测试策略、迁移步骤）则补齐。

---

### 🟢 R8 · 决策-AC 追溯缺失

**Symptom（症状）**：DESIGN.md §1 的 6 个决策（D1-D6）未标注各自对应哪条 AC。审阅者需手动推断：D1→AC-1、D2→AC-2、D3→AC-3+AC-7、D4→AC-4、D5→AC-5。D6（L3 API 降级）无直接对应的 AC，属于 NFR 韧性设计。

**Source（源头）**：REQUIREMENT.md 有 7 条 AC，DESIGN.md 有 6 条决策——缺少显式追溯矩阵。

**Consequence（后果）**：无法快速判断是否所有 AC 都有设计决策覆盖，或是否有决策未对应任何 AC（过度设计）。

**Remedy（修补）**：在决策表增加"覆盖 AC"列，或在 §1 末尾追加决策-AC 追溯矩阵。

---

### 🟢 R9 · BEFORE/AFTER 对比图对截断根因的归因过于简化

**Symptom（症状）**：DESIGN.md:130 修复前描述为"L3 prompt → head -c 20000 硬截断 → 不完整内容 → 假阳性"，将假阳性完全归因于 flow-kit 侧的 `head -c` 截断。CHANGE.md:55 原始问题描述中提到"L3 长度限制可能是 Anthropic API 层面的 token 限制，不一定能在 flow-kit 侧彻底解决"——但 DESIGN.md 未讨论 API 侧截断与 flow-kit 侧截断的叠加效应。

**Source（源头）**：CHANGE.md 的风险分析到位，但 DESIGN.md 未继承此 nuance。

**Consequence（后果）**：即使 flow-kit 侧做了完美的智能截断，若 API 端也按 token 数截断 prompt，假阳性问题可能未被完全消除——设计和验收标准会给出过于乐观的预期。

**Remedy（修补）**：在 D2 的风险/取舍栏或 §5 风险表中追加一条："L3 API 可能按自身 token 限制二次截断已智能截断的 prompt，截断叠加效应可能仍导致部分假阳性。缓解：告知模型截断上下文后，模型会意识到信息不完整，降低武断标记 critical 的概率。"

---

**Verdict**: pass

---

## 主 agent 回应

| Ref | 判定 | 行动 |
|-----|------|------|
| R1 | ✅ 采纳 | D1 已更新为"主匹配 `## L3 盲审` + `\|\|` 兼容旧 header `## L3 外部模型审查`"，与 R1 缓解措施一致 |
| R2 | ✅ 采纳 | AC-2 验证拆为两层：(a) bats 单元测试（确定性 awk 正确性验证，见 §7.2 `test/l3-truncation.bats`）；(b) 集成验证保留现有 L3 API 调用但标注 manual-only |
| R3 | ✅ 采纳 | D7 新增：`fk_resolve_phase()` 提升为 v1 必做交付物，3 处 hook 均改为调用此函数。bats 测试覆盖 pipeline/单阶段模式（`test/phase-resolution.bats`） |
| R4 | ✅ 采纳 | §2.2 新增：AC-5 选项②③完整交互设计——②跳过 L2 写 `.skip-L2-<phase>` 标记 + `FLOW_KIT_SKIP_L2=1` 确认风险；③回退等待即为当前 gate deny 默认行为 |
| R5 | ✅ 采纳 | §7 新增"测试策略"章节：5 个测试文件 ~10 单元 + ~6 集成 + 回归安全 + CI 集成 |
| R6 | ✅ 采纳 | §2.3 新增：awk 截断算法完整伪代码规范（两遍扫描 + 截断标记 + 降级规则） |
| R7 | ✅ 采纳 | 章节编号已修正：§2.2 AC-5 交互设计 + §2.3 截断算法 + §7 测试策略 |
| R8 | ✅ 采纳 | 决策表新增"覆盖 AC"列，D1-D7 逐条标注对应 AC |
| R9 | ✅ 采纳 | AFTER 对比图追加 API 端二次截断备注；风险表新增 R6（截断叠加效应） |

**L2 Verdict**: pass（无 🔴 Critical）
**主 agent 确认**: 全部 9 条发现已修复入 DESIGN.md。
