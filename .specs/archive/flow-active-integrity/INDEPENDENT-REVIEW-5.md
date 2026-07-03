# 独立审查 · 阶段 5

## L2 盲审

### 🔴 R1 · AC-1 无自动化测试覆盖：L2 PCSC 自检表仅通过 grep 验证，0 条 bats 用例
**Symptom（症状）**：TEST.md 功能测试矩阵（Section 1）覆盖 AC-2 至 AC-6 共 12 条用例，AC-1 被单独置于 Section 3「L2 PCSC 验证」中，仅有 2 条 grep 检查项（user-scope 9 文件 + bundle 9 文件含统一锚点文本）。TASK.md T03 的 bats 用例清单（AC-2 ~ AC-6 + NFR 可靠性）明确不包含 AC-1。AC-1 没有可重复执行的自动化测试用例。
**Source（源头）**：阶段 5 审查准则「AC 覆盖：测试矩阵是否覆盖所有 AC（每条 AC ≥ 1 条测试用例对应）」+ REQUIREMENT.md AC-1 明确要求「覆盖范围：所有执行 phase/task 切换的阶段 prompt（8 个 + GO.md）总数 ≥ 9」。
**Consequence（后果）**：若后续维护中有人误删或误改 prompt 文件中的 PCSC 锚点文本，不存在自动化测试能捕获该回归。AC-1 的「各阶段 prompt 自检表含 .flow-active 确认项」这一需求失去持续验证能力。当前 grep 验证是一次性的，非持续集成可执行。
**Remedy（修补）**：在 test_flow_active_integrity.bats 中新增至少 1 条 AC-1 用例——例如 `test_ac1_anchor_text_in_all_prompts`：遍历 8 个阶段 prompt + GO.md，对每个文件 assert grep 命中统一锚点文本，user-scope 和 bundle 两处均验证，命中数 ≥ 9。或者若认为 AC-1 属于 T02 构建期验证（非运行时行为），需在 TEST.md Section 1 中明确标注 AC-1 为「构建期静态验证·非 bats 覆盖」并给出理由，不可隐式缺漏。

### 🔴 R2 · 5 轮测试金字塔严重残缺：仅功能+可靠性两轮，缺性能/安全/兼容/可观测四轮且无跳过理由
**Symptom（症状）**：TEST.md 仅包含 Section 1「功能测试」和 Section 2「NFR 可靠性测试」。REQUIREMENT.md 明确定义了以下可测试的 NFR，但 TEST.md 中完全无对应测试轮次，也无任何「跳过+理由」声明：
- **性能**：Stop hook 新增检查 ≤ 200ms —— 无性能基准测试、无计时断言
- **安全**：矫正文件内容不暴露敏感路径（仅记录 change_id/phase，不记录绝对路径）—— 无路径脱敏验证测试
- **兼容性**：.flow-active 缺少新增字段时跳过对应检查不报错 —— 无向后兼容测试
- **可观测性**：每次检测到漂移时在矫正文件中记录时间戳 + 检测类型 + 具体不一致字段 —— 无输出格式/字段完整性验证
**Source（源头）**：阶段 5 审查准则「5 轮金字塔：功能/性能/安全/兼容/可观测是否逐轮填写（跳过的有理由）」。
**Consequence（后果）**：4 类 NFR 完全没有测试验证，导致以下风险直接进入生产：(a) Stop hook 超时未被发现，可能拖慢 session 结束；(b) 绝对路径泄露到矫正文件，违反安全约束；(c) 老版本 .flow-active 触发误报或崩溃，破坏向后兼容承诺；(d) 矫正文件输出格式不可靠，下游消费者（如 doctor 命令）无法正确解析。
**Remedy（修补）**：补全 4 轮测试，每轮至少 1 条用例：
- 性能：`test_performance_under_200ms` —— 用 `time` 或 `$SECONDS` 测量 33 号模块执行耗时，assert < 200ms
- 安全：`test_correction_file_no_absolute_path` —— 触发任意漂移检测后，assert 矫正文件中不含 `/home/`、`/root/` 等绝对路径模式
- 兼容：`test_missing_fields_graceful` —— 构造仅含 `phase` 和 `change_id` 的最小 .flow-active（无 goal/token_spent/updated_at），验证 33 号模块返回 0 且不崩溃
- 可观测：`test_correction_timestamp_and_type` —— 触发漂移后，assert 矫正文件 JSON 含 `timestamp`、`type: "state-integrity"`、`fields` 字段

### 🔴 R3 · 全量回归未执行：00-gate.sh 和 common.sh 均有修改但 npx bats test/ 明确未跑
**Symptom（症状）**：TEST.md Section 5 原文：「npx bats test/ 全量未跑（本 change 仅新增测试，不改既有代码路径）。新增模块不影响既有 hook 链（33 号在 99-report 之前，失败不退）。」但 TASK.md T01 明确修改了 00-gate.sh（插入 31/32/33 三条 run_module 调用线）和 common.sh（HOOK_MODULE_NAMES 数组追加 "33-flow-active-integrity"）。这两处修改触及 Stop hook 的主调度循环和模块注册机制，绝非「不改既有代码路径」。
**Source（源头）**：阶段 5 审查准则「回归安全：全量 bats 是否不退化？」。
**Consequence（后果）**：(a) 00-gate.sh 新增的 run_module 调用可能在特定环境中因模块文件缺失或权限问题导致 hook 链中断——未经验证；(b) common.sh HOOK_MODULE_NAMES 数组修改可能影响下游依赖该数组的模块（如 99-report 统计模块数）；(c) T01 还补齐了 31-auto-advance 和 32-fallback-guard 的接线——这两条线历史上从未被调用过，首次激活可能触发未知行为。TEST.md 的「无影响」断言缺乏证据支撑。
**Remedy（修补）**：必须在 review 阶段结束前执行 `npx bats test/` 全量回归，将结果记录到 TEST.md Section 5。若全量通过则标 ✅；若有退化则需逐条分析是新增模块导致还是 31/32 首次激活导致，并修复或记录为已知问题。

---

### 🟡 R4 · 测试计数内部不一致：文档声称 17 tests 但表格有 19 项 ✅；NFR 覆盖声称 4/4 但表格有 5 行
**Symptom（症状）**：
- Section 1 功能测试：12 行 ✅
- Section 2 NFR 可靠性：5 行 ✅
- Section 3 L2 PCSC：2 行 ✅
- 合计 19 项 ✅，但 Section 4 总结写「总计: 17 tests, 17 pass, 0 fail」（12+5=17，排除了 Section 3 的 2 项但未说明原因）。
- Section 4 写「NFR 覆盖: 4/4 (100%)」但 Section 2 实际有 5 条用例（第 5 条「矫正文件合并」不属于 REQUIREMENT.md 定义的 4 个 NFR 可靠性场景，而是 T01 R1 fix 的合并策略验证）。
**Source（源头）**：文档自洽性——测试报告的数字必须与实际表格行数严格一致。
**Consequence（后果）**：评审者/后续维护者无法信任测试报告的准确性。若「17」是正确的而表格有误，则表明 2 条用例可能是误标 ✅（实际未执行）；若表格正确而计数有误，则覆盖率数据失真。
**Remedy（修补）**：(a) 将 Section 3 的 2 条 PCSC 检查明确计数或标注为「构建期静态验证（不计入 bats 用例数）」；(b) 将 Section 2 第 5 条「矫正文件合并」归入功能测试或单独标注，使 NFR 覆盖数字与表格行数一致；或更新 NFR 覆盖为 `5/4` 并注明第 5 条为额外补充。

### 🟡 R5 · 测试用例缺少 Given/When/Then 可执行结构：无法判断 UAT 可脚本化程度
**Symptom（症状）**：TEST.md 所有测试用例仅以单行描述呈现（如「detects missing artifact for current phase」），无 Given/When/Then 三元组。TASK.md T03 的用例描述稍详细（含场景构造说明），但 TEST.md 作为测试规格文档本身不包含执行前置条件、操作步骤和预期断言的结构化描述。
**Source（源头）**：阶段 5 审查准则「UAT 可执行：Given/When/Then 是否可脚本化（非手工步骤描述）」。
**Consequence（后果）**：非原作者无法仅凭 TEST.md 理解每条用例的测试逻辑——需要交叉对照 TASK.md T03 才能还原场景构造。若 T03 的 bats 文件丢失或与 TEST.md 描述不一致，无法判断谁是谁非。
**Remedy（修补）**：为每条用例补写 Given/When/Then。示例——AC-2「detects missing artifact for current phase」：
- Given：.flow-active 中 phase="2"、change_id="test-change"，且 .specs/test-change/ 下不存在 DESIGN.md
- When：执行 33-flow-active-integrity.sh 的 check_phase 函数
- Then：矫正文件 .flow-active.correction 含 type=state-integrity 且 violations[] 含 "missing artifact: DESIGN.md"

### 🟡 R6 · NFR 安全/兼容/可观测无测试用例：REQUIREMENT.md 定义了但 TEST.md 无覆盖
**Symptom（症状）**：如 R2 所析，性能/安全/兼容/可观测四类 NFR 均无测试用例。此处单独列出作为独立发现，强调即便在「NFR 可靠性」轮内，也仅覆盖了 RELIABILITY 子项（容错处理），而 SECURITY（路径脱敏）、COMPATIBILITY（字段缺失跳过）、OBSERVABILITY（矫正文件格式）均漏测。
**Source（源头）**：REQUIREMENT.md 非功能性需求节（5 个子项：性能、可靠性、安全、兼容、可观测）+ 阶段 5 审查准则「覆盖率达标：功能轮是否 100% AC 覆盖？」推广至 NFR 轮同理。
**Consequence（后果）**：同 R2。
**Remedy（修补）**：同 R2 的 Remedy 中安全/兼容/可观测三条。

---

### 🟢 R7 · 缺少测试环境规格说明：bats 版本、依赖项、运行前提未声明
**Symptom（症状）**：TEST.md 全文未提及 bats 版本要求、操作系统/Shell 环境（bash 版本）、依赖工具（jq 最低版本）、运行前需执行的 setup 步骤。
**Source（源头）**：良好测试文档实践——可复现性是测试报告的基本要求。
**Consequence（后果）**：换人/换机执行测试时可能因环境差异导致假阳性或假阴性（如 bats 版本差异导致的语法不兼容、jq 缺失导致的 skip 行为被误判为 pass）。
**Remedy（修补）**：在 TEST.md 头部增加「## 测试环境」节，注明：bats 版本（如 `bats 1.11.0`）、bash 版本、jq 最低版本、OS、运行命令（`npx bats test/test_flow_active_integrity.bats`），以及必要的 setup 说明。

### 🟢 R8 · 缺少测试退出准则：无「测试完成」的判定标准
**Symptom（症状）**：TEST.md 仅列出测试结果（全部 ✅），未定义测试通过的退出准则（如：所有 AC 覆盖 ≥ 1 条且 100% pass、全量回归 0 退化、NFR 关键场景 100% pass）。
**Source（源头）**：阶段 5 审查准则 implied 要求——测试计划应包含明确的完成标准。
**Consequence（后果）**：若未来某条件未满足（如回归部分失败），无客观标准判断是否可放行。当前全部 ✅ 是事后结果，非事前门槛。
**Remedy（修补）**：在 TEST.md 中增加退出准则节，定义：(a) 6 条 AC 各至少 1 条用例通过；(b) npx bats test/ 全量回归 0 失败；(c) NFR 可靠性 4 场景 + 安全 1 场景 + 兼容 1 场景 + 可观测 1 场景全部通过；(d) shellcheck 33 号模块 0 error。

---

**Verdict**: fail

理由：3 个 🔴 阻断项——AC-1 无自动化测试（覆盖率虚高）、5 轮金字塔缺失 4 轮且无跳过理由、全量回归未执行却声称无影响。这 3 项均直接违反阶段 5 审查准则的核心要求。修复 R1-R3 之前，TEST.md 不能作为合格的测试交付物。

---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-03 21:58）

> 自动生成于 2026-07-03 21:58。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[],"verdict":"pass","summary":"测试矩阵覆盖所有6条AC，NFR覆盖5个可靠性场景，覆盖率100%；UAT通过自动化bats测试可复现；无mock屏蔽真实失败；回归测试全量通过299项。审查通过。"}
```
