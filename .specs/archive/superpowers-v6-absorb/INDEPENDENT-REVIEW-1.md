# 独立审查 · 阶段 1

---

## L2 盲审

### 🔴 R1 · AC-E3 自指涉反模式：AC 在 REQUIREMENT 阶段声明"本 AC 在 DESIGN 阶段细化"
**Symptom（症状）**：`REQUIREMENT.md:120` — AC-E3 末尾写有 `验证方式: DESIGN § 6 验证后明确；本 AC 在 DESIGN 阶段细化`
**Source（源头）**：flow-kit REQUIREMENT 阶段定义契约——AC 是 TEST 阶段派生用例的唯一来源（REQUIREMENT.md:274 "AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC"）。若 AC 自身声明"将在下一阶段细化"，则 AC 在进入 DESIGN 前尚未完整定义，无法作为 DESIGN 的输入约束，亦无法作为 TEST 的用例来源。
**Consequence（后果）**：DESIGN 阶段无法基于 AC-E3 做设计决策（因为 AC 自己说"我还没定"）；TEST 阶段无法为 model-tier 生效路径生成确定性的 bats 测试。若 OpenCode 实际不支持 task-level model switching，dispatch prompt hint 的具体格式和行为无法在 REQUIREMENT 阶段获得 AC 约束，导致 DESIGN/TEST 各自猜测。
**Remedy（修补）**：将 AC-E3 拆为两条独立 AC：
  - AC-E3a：`Given` OpenCode 支持 task-level model switching → `When` task 调度 → `Then` model-tier 属性直接生效（具体生效方式留 DESIGN，但 AC 断言"生效"即可）
  - AC-E3b：`Given` OpenCode **不**支持 task-level model switching → `When` task 调度 → `Then` dispatch prompt 含 `model-tier` hint 文本，格式为 `<具体格式定义——此时必须填入，不可留到 DESIGN>` 
  删除"本 AC 在 DESIGN 阶段细化"自指涉语句。两条 AC 各自独立可测。

### 🔴 R2 · US-1 "token 成本下降 ≥25%" 无硬性 AC 支撑——用户故事退化为宣言
**Symptom（症状）**：`REQUIREMENT.md:10` — US-1 声明"总 token 成本下降 25%+ 而质量不退"。但所有 token 相关 AC（AC-J1 `Pipeline token 削减参考测量` / AC-J2 `Review phase token 削减参考测量`）均标注"参考性指标（非硬门槛）"且 `验证方式: 在 7-integration 阶段记录两轮数据`。AC-J1 和 AC-J2 明确声明"不卡 toll-gate"。
**Source（源头）**：flow-kit requirement 工程原则——用户故事必须有至少一条硬性 AC（非参考性/非 deferrable）支撑，否则故事不可验收。`范围决策` 框中虽然论证了"端到端 token 测量误差大不适合做硬门槛"，但未提供替代性的硬门槛（如结构性 token 指标：review 轮数、per-task prompt 大小）。
**Consequence（后果）**：7-integration 完成时无法判定 US-1 是否达成。如果实际 token 削减仅 10%，pipeline 仍可通过（因为 AC-J1/J2 不卡 toll-gate）。US-1 从"目标"退化为"希望"，丧失用户故事的验收功能。
**Remedy（修补）**：为 US-1 补充至少一条结构性硬 AC。例如：
  - 将 AC-J1 拆为"结构性指标"（硬门槛：review 轮数 4→2，4-dev per-task prompt ≤15KB，GO.md ≤350 行——这些已在其他 AC 中覆盖，但缺乏 US-1 的统一 traceability）和"参考性指标"（端到端 token 测量）
  - 或在 US-1 末尾标注"本故事由以下结构性 AC 共同支撑：AC-B1 / AC-B3 / AC-H1 / AC-J1（结构性部分）"，建立 traceability

### 🟡 R3 · AC-F3 字段映射延后到 DESIGN——与 AC-E3 同类模式但严重度较低
**Symptom（症状）**：`REQUIREMENT.md:139-141` — AC-F3 的 `验证方式: DESIGN § 7 划定字段映射`
**Source（源头）**：同上 R1 的契约——AC 应作为 DESIGN 输入而非输出。AC-F3 虽然定义了职责划分（task_progress 机器读 / SUMMARY 人读），但字段级别的契约（task_progress 具体有哪些字段、SUMMARY 段命名约定）留到 DESIGN，这意味着 DESIGN 可以自由增删字段而无法在 REQUIREMENT 阶段评估其正确性。
**Consequence（后果）**：若 DESIGN 给 task_progress 加了 AC 未定义的额外字段（如 retry_count、estimated_tokens），TEST 无法判定这是 feature 还是 scope creep。中等影响，因为核心职责划分已在 AC 中明确。
**Remedy（修补）**：在 REQUIREMENT 中明确 task_progress 的 schema 字段清单（已部分在 AC-F2 中隐含：`id, commit_sha, fix_rounds, deferred[], completed_at`），并在 AC-F3 中将"验证方式"改为 `与 AC-F2 字段清单对照，无额外字段`，而非委托给 DESIGN。

### 🟡 R4 · AC-D2 deferred 文件位置二义性
**Symptom（症状）**：`REQUIREMENT.md:91` — AC-D2 写 `写入 .specs/<id>/MINOR-DEFERRED.md（或 T<N>-SUMMARY.md 的 deferred 段）`
**Source（源头）**：单一 AC 内给同一行为定义了两个不等价的产出路径——`MINOR-DEFERRED.md` 是独立文件，`T<N>-SUMMARY.md 的 deferred 段` 是嵌入段。两者对 hook 层（future check）和 TEST 阶段的影响不同。
**Consequence（后果）**：4-dev/6-review prompt 实现者需要二选一，而不同阶段可能选不同路径，导致 Minor findings 散落在不同文件中。TEST 需覆盖两条路径。更严重的是——如果 hook 层将来需要自动化 deferred finding 的 triage，它需要知道去哪儿读。
**Remedy（修补）**：选择单一路径并删除另一个。建议选 `MINOR-DEFERRED.md`（独立文件，hook 层可 grep 存在性检查），在 AC-D2 中删除"（或…）"的备选表述。

### 🟡 R5 · 4-dev.md ≤15KB 负载目标无对应 AC
**Symptom（症状）**：`REQUIREMENT.md:246` — 非功能性需求 § 性能 声明 `4-dev.md 加载后实际有效内容（task-brief 提取后）≤ 15KB`。这是 CHANGE.md 中明确列出的核心 token 削减手段之一（"4-dev 每个 task prompt 加载量减半"），但在 AC 列表中无对应条目。
**Source（源头）**：NFR 段条目应至少有 1 条 AC 支撑，否则 NFR 变成 wishlist。`范围决策` 将"结构性 AC 是硬门槛"列为原则——15KB 是一个结构性指标，理应有一条硬 AC。
**Consequence（后果）**：可测试性缺口——TEST 阶段无法通过 bats 验证 4-dev.md 的有效负载大小（因为 task-brief 提取后的内容大小取决于 TASK.md 中 task 块的大小，而非静态文件大小）。更危险的是：如果 4-dev.md 改造后实际负载 20KB（因新增 terse contract 段或 narration constraint 段），没有 AC 能阻止。
**Remedy（修补）**：在类别 B 或类别 E 中新增一条 AC（如 AC-B4）：`Given` 一份含 ≤5 个 task 的典型 TASK.md → `When` 执行 `scripts/task-brief TASK.md T<n> /tmp/out` → `Then` `/tmp/out` 大小 ≤ 15KB。或至少建立一个测量协议并标记为结构性 AC（硬门槛）。

### 🟡 R6 · AC-A1 错误场景未定义——非 git 目录行为真空
**Symptom（症状）**：`REQUIREMENT.md:31` — AC-A1 的 `When` 为 `执行 ... 在任意 git 仓库`，验证方式为 bats。但未定义**非 git 仓库**下的行为（AC-A1 是否需要 graceful error？exit code？stderr message？）。
**Source（源头）**：脚本的契约完整性——生产脚本必须定义 happy path **与** error path。AC-A1 仅覆盖 happy path。
**Consequence（后果）**：review-package 在非 git 目录下可能崩溃（`git log` 返回非零 exit → `set -euo pipefail` 下脚本直接终止）或无提示返回空输出——两种行为都可能被误读为"没有变更"。若 CI 环境 git 仓库初始化失败，review-package 的错误信息将不可控。
**Remedy（修补）**：AC-A1 追加 error path：`Given` 非 git 目录 → `When` 执行 review-package → `Then` exit code ≠0 + stderr 含可识别错误信息（如"not a git repository"）。bats 测试覆盖此路径。

### 🟢 R7 · AC-A3 "macOS（如可用）"弱化跨平台验证
**Symptom（症状）**：`REQUIREMENT.md:43` — AC-A3 的 `When` 写 `在 Linux 与 macOS（如可用）跑脚本`
**Source（源头）**：条件式 AC——"如可用"使得 AC 在 macOS 不可用时自动退化为 Linux-only，此时 AC 的"跨平台"语义失效。违反 Given/When/Then 的确定性原则。
**Consequence（后果）**：轻微——flow-kit 明确是 Linux-first 工具（无 macOS CI），此 AC 更像"意愿声明"。但若 CI 某天加了 macOS runner，此 AC 不会提醒"macOS 测试已可用、请更新 AC 去掉'如可用'"。
**Remedy（修补）**：将 AC-A3 拆为两条：AC-A3a（Linux 必须通过）为硬 AC，AC-A3b（macOS 期望通过）标记为"期望但非硬门槛（CI 无 macOS 时自动 skip）"。

### 🟢 R8 · 多条 AC 验证方式含"人工"——非阻塞但降低自动化置信度
**Symptom（症状）**：AC-B1 ("人工 + grep")、AC-B2 ("人工 + hook 日志")、AC-D2 ("人工 + 文件存在性检查")、AC-F2 ("bats 测试 + 人工")、AC-G1 ("3-task.md 末段含子步骤 + 实际产物")、AC-G2 ("人工")
**Source（源头）**：flow-kit 自身标准——AC-I1/I2 要求"新脚本 100% bats 覆盖"和"现有测试不退化"，但对 prompt 行为 AC 的验证仍依赖人工判断。
**Consequence（后果）**：回归测试无法自动捕获 prompt 行为退化——如 AC-B1 "不再出现 Round 1/2/3" 目前靠人工 grep，若未来有人在 REVIEW.md 草稿中写了 "Round 1: TODO" 而被误判。
**Remedy（修补）**：对 AC-B1 的 grep 部分独立为 bats 测试（`! grep -q "Round [123]" REVIEW.md`）；对 AC-D2 的文件存在性检查独立为 bats。纯人工部分（如"综合评估为 pass"的判断质量）保留人工，但机械验证部分尽量自动化。

### 🟢 R9 · 范围决策框嵌入 REQUIREMENT——模糊 REQUIREMENT/DESIGN 边界
**Symptom（症状）**：`REQUIREMENT.md:21-24` — `范围决策` 框内写有"Token 测量协议：结构性 + 参考性双轨…"、"Cross-model spot-check '加强'语义…"、"task_progress vs T<N>-SUMMARY.md：并存…"——这些是设计决策（DESIGN 产出），却以"写 REQUIREMENT 时由我判断"的形式嵌入 REQUIREMENT 文档。
**Source（源头）**：flow-kit 阶段模型——REQUIREMENT 定义"做什么"（what），DESIGN 定义"怎么做"（how）。范围决策框内的"双轨测量协议"、"加强语义"、"并存策略"属于 how 层级。
**Consequence（后果）**：轻微——DESIGN 作者可能因"REQUIREMENT 已经决定了"而跳过对这些设计的独立评估；但这些决策标注了"可在 1→2 toll-gate 推翻"，提供了纠正机制。
**Remedy（修补）**：将范围决策从 REQUIREMENT.md 正文移到 CHANGE.md 的"验收线"段或独立 `DESIGN-NOTES.md`（作为 1→2 过渡产物）。REQUIREMENT.md 仅保留 AC 和用户故事。

---

**Verdict**: fail

---

## 主 agent 响应（superpowers-v6-absorb Phase 1 修复）

> 按 L2-blind-review.md §「与主 agent 的关系」协议：主 agent 无权修改 L2 原文判断；反驳另起段标注。Phase 1 是 REQUIREMENT 文档型产物，修代码优先协议（仅 5/6/7 阶段触发）不适用，REQUIREMENT.md 编辑即对应修复。

### 🔴 Critical（必须修复 · 已修复）

- **R1 → Fixed in: `.specs/superpowers-v6-absorb/REQUIREMENT.md` AC-E3 (lines 114-130)**：拆分为 AC-E3a（OpenCode 支持时的生效断言，验证靠 mock dispatcher 断言派发参数）+ AC-E3b（不支持时的 hint 格式契约，hint 文本格式固定为 `[MODEL-TIER hint]: 建议本 task 使用 <tier>-tier 模型（<reason>）`，可 grep）。删除"本 AC 在 DESIGN 阶段细化"自指涉语句。DESIGN § 6 仅负责"实现哪一条 + 如何实现"，AC 本身已完整可验证。
- **R2 → Fixed in: `.specs/superpowers-v6-absorb/REQUIREMENT.md` US-1 (line 10)**：US-1 末追加 Traceability 段，显式列出 5 条结构性 AC（AC-B1/B2/B3/B4/H1）+ 2 条约束 AC（AC-C1/C2）作为硬支撑。"结构性 AC 全过 = US-1 达成"作为验收规则；参考性 AC-J1/J2 作证但不卡 toll-gate（依据 §范围决策框已论证端到端 token 测量误差大）。

### 🟡 Major（建议修复 · 已修复）

- **R3 → Fixed in: REQUIREMENT.md AC-F3 (lines 136-141)**：task_progress 字段集**锁**为 5 字段（`id, commit_sha, fix_rounds, deferred[], completed_at`），明确禁止新增字段（如 retry_count / estimated_tokens 需新 ADR）。验证方式从"DESIGN § 7 划定字段映射"改为"bats 测试断言 jq keys 完全等于锁集"。DESIGN § 7 仅描述写入时机（task 完成时 vs 4-dev 完成时），不再涉字段定义。
- **R4 → Fixed in: REQUIREMENT.md AC-D2 (lines 91-93)**：删除"（或 T<N>-SUMMARY.md 的 deferred 段）"等价路径，单一固定路径为 `.specs/<id>/MINOR-DEFERRED.md`（独立文件，hook 层可 grep 存在性）。验证方式从"人工 + 文件存在性检查"升级为"bats 测试 test -f + grep finding 编号"。
- **R5 → Fixed in: REQUIREMENT.md 新增 AC-B4 (lines 64-67)**：新增 AC-B4 "task-brief 提取后 4-dev 有效负载 ≤ 15KB"，Given/When/Then 完整：Given 典型 TASK.md（5 task × ~500-800 字节）→ When 跑 task-brief 并 cat 4-dev.md + 输出 → Then 合并 ≤15360 字节。验证方式：`bash test/test_task_brief.bats` 含 size-budget 用例（`wc -c` 断言）。
- **R6 → Fixed in: REQUIREMENT.md 新增 AC-A1-ERR (lines 32-36)**：新增 error path AC：Given 非 git 目录 → When 跑 review-package → Then exit ≠0 + stderr 含 `"review-package: not a git repository"` 或 `"fatal: not a git repository"`，不产生 outfile。验证方式：bats error-path 用例覆盖 `set -euo pipefail` 下 `git log` 返回非零的处理。

### 🟢 Minor（可选改进 · 显式延后）

> 本次 change 正在构建 severity gating 机制（G6），此处按其契约把 Minor findings 延后到 `.specs/superpowers-v6-absorb/MINOR-DEFERRED.md`（phase 6 创建）。延后不是放弃——MINOR-DEFERRED.md 在 phase 7-integration 阶段会被 triage。

- **R7 → Tech-debt: deferred to MINOR-DEFERRED.md**：AC-A3 "macOS（如可用）"弱化。Rationale：flow-kit 是 Linux-first 工具，无 macOS CI；如未来加 macOS runner 再拆为 AC-A3a（Linux 硬）+ AC-A3b（macOS 期望）。**不阻塞当前 change**。
- **R8 → Tech-debt: deferred to MINOR-DEFERRED.md**：6 条 AC 验证含"人工"。Rationale：B1/B2/D2/F2/G1/G2 的 grep 部分（如 `! grep -q "Round [123]"`）在 phase 5-test 时独立为 bats；纯人工判断部分（"综合评估 pass 的判断质量"）保留人工是合理的，因为判断质量本身就是非机械的。**不阻塞当前 change**。
- **R9 → Tech-debt: deferred to MINOR-DEFERRED.md**：范围决策框嵌入 REQUIREMENT。Rationale：框内的设计决策（双轨测量 / Critical 触发 / 并存策略）已在 CONTEXT.md 已锁决策段正式登记（5 条新决策），双层登记提供了纠正机制；框内已显式标注"可在 1→2 toll-gate 推翻"。**不阻塞当前 change**。

### 修复后自评

- Verdict 升级：fail → 预期 pass（待 L3 外部模型独立审查确认）
- 所有 🔴 已拆解为可独立 bats 验证的硬 AC（含 mock / size budget / error path / grep 等机械验证）
- 所有 🟡 已写入 REQUIREMENT.md 正本，不再是 wishlist
- 所有 🟢 已按本次 change 自身的 severity gating 契约延后，附 rationale（非敷衍）
- 不修改 L2 原文（包括 L2 的"Verdict: fail"行保留作历史记录）
