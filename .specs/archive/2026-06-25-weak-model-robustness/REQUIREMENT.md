# REQUIREMENT: 提升 flow-kit 在弱模型（幻觉多）下的鲁棒性

- **Change ID**: weak-model-robustness
- **关联**: `@.specs/weak-model-robustness/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 使用者（在弱模型下），我希望 flow-kit **强制模型先反问澄清、先复述 read/write 边界再动手**，以便不会跳过需求理解直接写代码、不会把"本次不做"当成要做。
- **US-2**：作为 flow-kit 使用者（在弱模型下），我希望模型**提到的每个文件/API/字段都被强制验证存在**，以便不会被幻觉误导写出不存在的引用。
- **US-3**：作为 flow-kit 使用者（在弱模型下），我希望流程**强制 checkpoint、每阶段重申 goal**，以便模型不会跳 checkpoint、不会中途漂移忘记目标。
- **US-4**：作为 flow-kit 维护者，我希望弱模型护栏有 **bats 结构测试 + regression-demo 反例**双验收，以便加固不退化、且不破坏强模型路径。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 禁跳反问（L1 规则 + L2 prompt）

- **Given** `RULES.md` 含"禁跳反问直接出方案"硬约束，且每个需反问的阶段 prompt（0-change / 1-requirement / 2-design）含显式「反问 gate」段
- **When** 跑 bats 结构测试校验上述约束段存在
- **Then** 测试通过：`RULES.md` 命中禁跳反问约束，3 个 prompt 各命中反问 gate 标记
- **验证方式**: `npx bats test/weak-model-robustness/no-skip-clarify.bats`

### AC-2 · 禁幻觉/凭空假设（L3 证据链）

- **Given** `4-dev.md` / `2-design.md` 等 prompt 含"提到任何文件/API/字段前必须先 `grep`/`read` 验证存在"指令
- **When** 跑 regression-demo（诱导幻觉场景：prompt 要求引用一个不存在的模块）
- **Then** demo 的 `check.sh` 验证护栏生效（引用前存在 `grep`/`read` 动作，或模型明确报告"未找到，拒绝引用"）
- **验证方式**: `bash flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh`

### AC-3 · 关键节点强制 checkpoint（L1 + L2 · 非每操作）

- **Given** `4-dev.md` 等执行类 prompt 在**关键节点**（开始编辑文件前 / 遇测试或验证失败时 / 切换 task 时）强制 `/flow checkpoint`——**非每操作**（避免强模型啰嗦）
- **When** bats 校验各执行类 prompt 命中 checkpoint 段，且触发点限定为关键节点（grep 不到"每步/每次操作"类无条件措辞）
- **Then** 通过
- **验证方式**: `npx bats test/weak-model-robustness/checkpoint-keynodes.bats`

### AC-4 · 范围漂移防护（L2 复述边界）

- **Given** `4-dev.md` 含"动手前先复述当前 task 的 read_files/write_files 边界 + CHANGE 的范围排除"指令
- **When** regression-demo（诱导越界：prompt 试图编辑 write_files 外的文件）
- **Then** `check.sh` 验证模型复述了边界且拒绝越界写
- **验证方式**: `bash flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh`

### AC-5 · goal/中途漂移防护（pipeline 阶段入场锚定 · 非每步）

- **Given** pipeline goal 流程在**阶段入场**含一次"重申顶层 goal condition + 当前阶段如何服务于它"——仅入场锚定，**非每步唠叨**（避免强模型啰嗦）
- **When** bats 校验 GO.md / 各阶段 prompt 含 goal 锚点段
- **Then** 通过
- **验证方式**: `npx bats test/weak-model-robustness/goal-anchored.bats`

### AC-6 · 不破坏强模型路径（回归基线）

- **Given** 加固前现有 regression-demos / 94 个 bats 测试在强模型下全绿
- **When** 加固后重跑现有 bats 全套 + 现有 regression-demos
- **Then** 仍全绿（加固为叠加，非替换）
- **验证方式**: `npx bats test/**/*.bats`（现有全套）+ 现有 demos

### AC-7 · 强模型不过度啰嗦（防加固反噬）

- **Given** L1-L3 加固只含"结构刚性"护栏（填空模板 / gate / 证据链 / 关键节点 checkpoint / 阶段入场锚定），不含"重复唠叨"（每步复述 goal / 每操作 checkpoint / 冗余自检）
- **When** 强模型跑一个**基准任务**（既有 regression-demo 或固定样例），对比加固前后快照
- **Then** 啰嗦度不显著上升：**输出 token 增量 < 20% · 平均 turn 数增量 < 20%**（粗粒度；DESIGN 定基准任务与精确度量法）
- **验证方式**: `bash flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh`（对比加固前后输出快照）

---

## 范围切分

### v1（本次必做）

- **设计原则**：L1-L3 只加"结构刚性"护栏（强模型也受益、不啰嗦），**不加"重复唠叨"**（每步复述 goal / 每操作 checkpoint / 冗余自检）——由 AC-7 强制约束
- L1：`RULES.md` / `SYSTEM.md` 加硬护栏（禁跳反问 / 禁凭空假设 / 关键节点 checkpoint / 动手前复述边界）
- L2：各阶段 prompt 加结构化强化（反问 gate / 自检 gate / 填空式产出模板）
- L3：易幻觉操作改强制证据链（`grep`/`read` 验证）+ 关键决策交叉校验
- 验收：6 条 AC 对应的 bats 结构测试 + 5 个失败模式各 1 个 regression-demo（含 `check.sh`）

### v2（下一轮考虑，不本次）

- **L4 伪双轨**：`STATE.md` 加 `model_tier` 字段 + prompt 分级标记（`🟡弱模型必读`/`🔵强模型可跳过`）+ strong opt-out 降级
- **自动化的弱模型 CI**：本次 regression-demo 用脚本模拟（`check.sh` 验行为特征），真接弱模型 API 跑 demo 留 v2

### out（永远不做）

- 运行时模型能力自动探测（弱模型会幻觉自己很强，已论证不可靠）
- 针对某一款具体模型（minimax/qwen/deepseek）做专用补丁
- 改 flow-kit 阶段划分（0→7 流程不变）

---

## 非功能性需求

- **性能/啰嗦度**: L1-L3 加固须避免强模型过度啰嗦——基准任务下**输出 token 增量 < 20% · turn 数增量 < 20%**（见 AC-7）。L3 证据链的 `grep`/`read` 仅在"引用前验证"触发点执行，不做无差别全局强制（DESIGN 定触发清单与豁免）
- **可访问性**: 无
- **安全**: 无（不改 hooks / 执行机制 / 状态机结构）
- **兼容性**: 向后兼容——加固为叠加非替换；现有 94 个 bats 测试不破坏；强模型路径行为不变（仅多几条约束）
- **可观测性**: 每个 regression-demo 含 `check.sh` + 预期输出，可独立追溯

## 依赖与假设

- **假设**：「弱模型」= 能稳定遵循结构化指令、但易幻觉/易跳步骤的模型（精确基线模型由 DESIGN 阶段定）
- **依赖**：现有 bats-core 1.13.0（npx）、`flow-kit-bundle/flow-kit/regression-demos/` 目录
- **未知（转 DESIGN/TEST）**：regression-demo 如何"用弱模型跑"——本次采用**脚本模拟**（`check.sh` 验行为特征，不真跑模型），真接 API 留 v2。**✅ 已确认采纳**
- **风险**：加固过度会让强模型变啰嗦，而**啰嗦本身可能增加幻觉**（长上下文 / 注意力分散 / 指令淹没）——故 L1-L3 只加"结构刚性"护栏、不加"重复唠叨"，并由 AC-7 强制约束。此风险提升了 L4 opt-out 的价值，但本次靠"非啰嗦设计 + AC-7"先行覆盖，L4 仍留 v2

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
