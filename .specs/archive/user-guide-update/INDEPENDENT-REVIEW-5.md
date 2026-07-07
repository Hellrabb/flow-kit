# 独立审查 · 阶段 5

## L2 盲审

### 🔴 R1 · AC 覆盖缺陷：AC-7 在 REQUIREMENT.md 中不存在，测试矩阵引用了未定义的验收准则
**Symptom**：TEST.md L25 已知问题段引用 `AC-7 (test/ vs flow-kit-bundle/test/ 一致性)`，但 REQUIREMENT.md 仅定义了 AC-1 至 AC-6，AC-7 不存在。
**Source**：REQUIREMENT.md L117 明确规定 "AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC"。
**Consequence**：一个未定义的验收准则被当作已知问题记录，但既无对应需求条目也无验收标准。若 bundle 同步问题实为功能缺陷，则该缺陷无需求追溯，无法判断 severity/priority。违反 AC 派生唯一来源规则。
**Remedy**：若 bundle 同步确属质量要求，需回退到 REQUIREMENT.md 补充 AC-7（含 Given/When/Then）；若仅为工艺性差异，应从测试矩阵移除 AC-7 编号，改为普通已知问题记录，并标注是否需要修复及修复计划。

---

### 🔴 R2 · AC-3 测试验证严重不足：仅校验单字段存在性，未覆盖全部 4 种触发场景及字段级正确性
**Symptom**：TEST.md L12 对 AC-3 的测试用例仅为 `jq -e '.interrupt.checkpoint_at' .flow-active` 非空。AC-3（REQUIREMENT.md L37-46）明确要求 4 种触发场景（Write/Edit 工具调用、测试非零退出、阶段切换、toll-gate 暂停），每种均需验证 4 个字段：`active_file`（相对路径格式）、`last_action`（≤200 字符）、`checkpoint_at`（ISO8601 格式）、`updated_at`（同步刷新）。当前测试只验证了一个字段的非空性，且未区分场景。
**Source**：REQUIREMENT.md AC-3（L37-46）的 Then 子句完整列举了 4 字段 × 4 场景的验证要求。
**Consequence**：即使 4 种触发中仅 1 种生效，且字段值格式错误（如绝对路径、超长 last_action、非 ISO8601 时间戳），当前测试仍会报告通过。false-positive 风险极高。若 auto-checkpoint 写入格式不符规格，中断恢复流程将失败（AC-5 依赖正确的 interrupt 字段结构）。
**Remedy**：为 AC-3 设计至少 4 条测试用例，每条对应一个触发场景，各自验证 4 个字段的格式正确性（jq 提取 + regex 校验路径格式、长度、ISO8601）。结果列不可仅为 "手动验证"，必须对应可复现的自动化验证步骤。

---

### 🔴 R3 · AC-5 测试覆盖不全：缺少阶段 prompt 恢复段注入验证
**Symptom**：TEST.md L14 对 AC-5 的验证仅覆盖 `GO.md 路由表 "继续" 含 interrupt 字段引用`（5 matching lines），但 AC-5（REQUIREMENT.md L55-60）明确要求两个确定性产物：① GO.md 路由声明中断上下文（已覆盖），② **对应阶段 prompt 文件的恢复段包含 interrupt 上下文注入逻辑**（未覆盖）。
**Source**：REQUIREMENT.md AC-5 Then 子句（L59-60）。
**Consequence**：GO.md 路由声明含 interrupt 引用但阶段 prompt 恢复段未正确注入上下文时，执行 `/flow-go 继续` 后 AI 收到的 prompt 中缺少中断信息，导致恢复失败（AI 不了解中断前的上下文）。当前测试无法发现此类故障。
**Remedy**：为 AC-5 增加第 2 条测试用例：模拟中断 → `/flow-go 继续` → 检查被路由到的阶段 prompt 文件（如 4-dev.md 等 15 个 prompt 中的目标）是否包含 `interrupt` / `active_file` / `last_action` 字段的注入逻辑（`grep -q`）。两条测试用例分别对应 AC-5 的两个确定性产物。

---

### 🟡 R4 · AC-1 测试仅覆盖 3/14 功能关键词，11 个功能点无验证
**Symptom**：TEST.md L10 对 AC-1 的 grep 验证仅检查 `L2|L3|both` 三个关键词。AC-1（REQUIREMENT.md L18-23）When 子句列出了 14 个需覆盖的功能点（gate_config preset、数字简写、pipeline goal 0→7、toll-gate 条件、auto_advance、fallback、四层架构、.done 真实性校验、三种威胁模型、gate_config 快照同步、L3 前置、transition 方向检测、31/32 hook）。仅 grep 三个关键词无法验证其余 11 个功能点的文档覆盖。
**Source**：REQUIREMENT.md AC-1 When 子句（L19-21）的完整功能清单。
**Consequence**：文档可能缺失对多数必要功能的覆盖，但 AC-1 测试仍通过。用户打开指南后找不到这些功能的说明，违反 US-1。
**Remedy**：扩充 AC-1 测试用例，为 When 子句中的每个功能点至少增加一个 grep 关键词对（如 `grep -c "pipeline goal"`、`grep -c "toll-gate"`、`grep -c "四层"`、`grep -c ".done"`、`grep -c "威胁模型"`、`grep -c "front-load"`、`grep -c "transition.*方向"` 等），在三份文档中逐一验证。

---

### 🟡 R5 · 非功能性需求零测试覆盖：可靠性要求无验证
**Symptom**：TEST.md 测试矩阵仅覆盖 AC-1 至 AC-6，缺少对 REQUIREMENT.md L95-102 非功能性需求中可靠性要求的任何测试：
- "写入失败时 MUST 保留旧值不变（mv-atomic 策略）" — 无测试
- "写入后 MUST 校验 JSON 合法性（jq empty）" — 无测试
- "若校验失败则回滚到写入前状态" — 无测试
- "写入失败时 SHOULD 输出 stderr 警告" — 无测试
- "静默失败为禁止行为" — 无测试
**Source**：REQUIREMENT.md 非功能性需求段（L95-102），使用 MUST/SHOULD 等级约束词。
**Consequence**：checkpoint 写入过程中的静默失败（如 JSON 损坏、写入不完整）不会被测试捕获，中断恢复时可能读到无效数据导致流程中断。MUST 级需求未测试，属合规缺口。
**Remedy**：在测试矩阵中增加 AC-NFR-1 到 AC-NFR-5，对应 5 条可靠性要求，设计故障注入测试（如写入只读目录、写入非法 JSON、模拟中途崩溃），验证原子性和回滚行为。这些测试应与 T09（checkpoint-lib 单元测试）对齐。

---

### 🟡 R6 · TEST.md 与 TASK.md 无追溯映射
**Symptom**：TASK.md 定义了 11 个任务（T01-T11），每个任务均含 `<verify>` 验证步骤，但 TEST.md 的测试矩阵未建立任何到 TASK 级别的追溯。例如 T11 的 verify 步骤包含 AC-1~AC-6 全部验证，但 TEST.md 未引用 TASK.md 中的验证规范，造成两个文档独立运行、互不核对的风险。
**Source**：REQUIREMENT.md L117 "AC 是 TEST 阶段派生用例的唯一来源" + TASK.md 各任务定义的 verify 步骤。
**Consequence**：T11 声称全部 AC 验证通过，但 TEST.md 的测试矩阵可能遗漏 T11 中的某些验证步骤（如全量 bats 回归）。两套验证规范不一致时，无法判断以哪个为准。
**Remedy**：在 TEST.md 测试矩阵中为每条测试用例标注对应的 TASK 追溯（如 AC-1 → T11-1、AC-3 → T11-3 + T09），确保 TEST.md 的测试覆盖了 TASK.md 中所有 `<verify>` 步骤。

---

### 🟢 R7 · AC-4 验证结果引用不透明
**Symptom**：TEST.md L13 对 AC-4 的验证结果标注为 `✅ 11/11 bats pass`，但未说明是哪些 bats 测试文件、测试用例 ID 或测试场景。AC-4 的具体验证要求（"自动 checkpoint → 手动 `/flow checkpoint` → jq 读 `.flow-active.interrupt` 确认为手动值"）需要专门的测试场景，而非通用 bats 回归结果。
**Source**：REQUIREMENT.md AC-4（L49-53）的 When/Then 子句定义了明确的验证流程。
**Consequence**：无法判断 "11/11 bats pass" 中是否真的包含了 AC-4 的专用测试用例（覆盖 → 验证 → 确认三步流程）。可能只是全量回归通过，但 AC-4 本身未经专门验证。
**Remedy**：明确标注验证 AC-4 的具体测试用例（如 `test/test_checkpoint.bats: "manual checkpoint overrides auto value"`），将 `11/11 bats pass` 替换为有针对性的测试用例引用。

---

### 🟢 R8 · AC-3 测试结果列标记与实际方法矛盾
**Symptom**：TEST.md L12 AC-3 测试用例的验证方式列为 `jq -e '.interrupt.checkpoint_at' .flow-active` 非空（自动化命令），但结果列却写 `✅ 手动验证`。自动化测试方法被标记为手动验证，标注自相矛盾。
**Source**：TEST.md L12 自身（验证方式 vs 结果 的 self-contradiction）。
**Consequence**：其他审查者无法判断 AC-3 到底是通过自动化还是手动验证的。若实际只是手动验证，则 jq 命令仅为装饰性引用，测试可复现性存疑。
**Remedy**：将结果列改为自动化测试的实际输出或引用具体 bats 测试文件及用例 ID。若确实进行了手动验证，则在验证方式中也应标注 "手动验证"，保持两者一致。

---

**Verdict**: fail
