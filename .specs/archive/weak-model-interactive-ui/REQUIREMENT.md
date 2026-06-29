# REQUIREMENT: 弱模型交互式 UI 触发强化

- **Change ID**: `weak-model-interactive-ui`
- **关联**: `@.specs/weak-model-interactive-ui/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为弱模型（deepseek-v4-pro / minimax-m2.7 / qwen3.6-35b-a3b 等），在执行 flow-kit 各阶段 prompt 时，当 prompt 要求"反问用户"，我必须实际调用 `AskUserQuestion` 工具弹出对话框，而不是幻觉用户回答或跳过。
- **US-2**：作为弱模型，当 prompt 要求"进入计划模式"或"先出计划再编码"，我必须实际调用 `EnterPlanMode` 工具进入计划模式，而不是在聊天里直接出方案。
- **US-3**：作为 flow-kit 维护者，我需要一份全链路扫描清单，标明 flow-kit 所有 prompt 中"应触发交互式 UI"的精确位置，以便逐点加固、逐点验证。

## 验收准则（AC）

### AC-1 · 全链路交互式 UI 点位扫描

- **Given** flow-kit 完整 prompt 链（GO.md + 0-change 至 7-integration + reference 共享片段）
- **When** 执行扫描
- **Then** 输出完整清单，每条包含：文件路径、行号、交互类型（`AskUserQuestion` / `EnterPlanMode`）、触发上下文（引用的 prompt 原文）、当前护栏状态（有/无/不足）
- **验证方式**: `grep -n "反问\|AskUserQuestion\|EnterPlanMode\|计划模式\|进入计划\|停下来\|等用户\|等待用户\|必须等待\|禁止自动" flow-kit/prompts/*.md flow-kit/GO.md flow-kit/reference/*.md` → 人工逐条确认

### AC-2 · AskUserQuestion 触发护栏

- **Given** 任一 flow-kit prompt 中包含"反问用户"/"等待用户回复"/"禁止自动继续"等交互 gate
- **When** 弱模型执行到该点位
- **Then** prompt 包含以下三层护栏中的至少两层：
  1. **结构化自检句**（如"❌ 如果你还没调用 `AskUserQuestion`，你现在就停下来调用它"）
  2. **工具调用模板**（明确写出参数骨架：`AskUserQuestion({ questions: [...] })`）
  3. **L3 证据链**（"确认：你上一条消息是否包含工具调用？如果没有，你跳过了交互 gate，请回退重做"）
- **验证方式**: 对 AC-1 扫描出的每个 `AskUserQuestion` 点位，人工确认 prompt 原文含 ≥2 层护栏

### AC-3 · EnterPlanMode 触发护栏

- **Given** 任一 flow-kit prompt 中包含"进入计划模式"/"先出计划"/"EnterPlanMode"等指令
- **When** 弱模型执行到该点位
- **Then** prompt 包含以下三层护栏中的至少两层：
  1. **结构化自检句**（如"⚠️ 本步骤要求先进入计划模式。调用 `EnterPlanMode` 工具，不要直接在聊天里出方案"）
  2. **前置条件 gate**（如"在进入计划模式之前，不要开始写代码"）
  3. **L3 证据链**（"确认：你是否已调用 EnterPlanMode？如果没有，现在调用"）
- **验证方式**: 对 AC-1 扫描出的每个 `EnterPlanMode` 点位，人工确认 prompt 原文含 ≥2 层护栏

### AC-4 · 回归演示（regression demo）

- **Given** 27-interactive-ui-check.sh hook 已安装，交互 gate 清单（GATE_MAP）已填充
- **When** 运行 regression demo（模拟弱模型跳过 UI 的 transcript：`prompt.txt` 含交互 gate + `response.txt` 不含工具调用）
- **Then** `check.sh` 验证 hook 脚本**正确检测到跳过**（exit 0）并**写入矫正文件**（`.flow-active.interactive-ui-fix` 存在且字段完整）
- **验证方式**: `flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/check.sh` 全绿

### AC-5 · 强模型行为不变

- **Given** 强模型（Claude 级）执行加固后的 prompt
- **When** 到达交互 gate
- **Then** 行为与加固前一致：正常触发交互式 UI，不出现重复弹出、不出现额外啰嗦自检文本（护栏对强模型透明）
- **验证方式**: 人工用 Claude 走一遍 0-change 完整流程，确认没有"你怎么老问我同一个问题"或多余的自检啰嗦

### AC-6 · 现有测试全量通过

- **Given** 本次 change 修改了 flow-kit prompt 文件
- **When** 运行 `npx bats test/`
- **Then** 全部 102 tests 通过（0 failures）
- **验证方式**: `npx bats test/` 输出 `102 tests, 0 failures`

---

## 范围切分

### v1（本次必做）

- 全链路扫描：GO.md + 0-change 至 7-integration + 所有 reference 共享片段
- `AskUserQuestion` 触发点加固（≥2 层护栏/点）
- `EnterPlanMode` 触发点加固（≥2 层护栏/点）
- 新增 `flow-kit/reference/interactive-ui-guard.md`（共享护栏模板片段，供各 prompt 引用）
- 至少 2 个 regression demo（一个 `AskUserQuestion` 场景 + 一个 `EnterPlanMode` 场景）
- CONTEXT.md 术语追加

### v2（下一轮考虑，不本次）

- 自动化 lint 规则：检测 prompt 中"反问"关键词出现但缺少对应护栏模板时告警
- 量化指标：弱模型在加固前后的交互式 UI 触发成功率对比（需跨模型测试基础设施）
- 扩展到 brooks-lint 插件中的交互点
- 扩展到 gateflow 插件中的交互点

### out（永远不做）

- 修改 Claude Code 原生工具（`AskUserQuestion` / `EnterPlanMode`）的行为或实现
- 引入新的外部依赖或工具
- 改变 flow-kit 交互流程的逻辑（该反问还是反问，该进 Plan 还是进 Plan）
- 处理权限提示弹窗（Permission Prompt）——用户反馈正常触发，不在 scope

---

## 非功能性需求

- **性能**: 无（仅 prompt 文本变更，不影响运行时性能）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: CC v2.1.139+（依赖原生 `/goal` 和 `AskUserQuestion`/`EnterPlanMode` 工具）
- **可观测性**: Regression demo `check.sh` 输出 TAP 兼容格式，可集成到 `make check`

## 依赖与假设

- **依赖**: Claude Code 内置工具 `AskUserQuestion`、`EnterPlanMode`（已存在于 CC v2.1.139+）
- **依赖**: `protect the weakest` 设计哲学（已确立于 `weak-model-robustness` change）
- **依赖**: L1/L2/L3 分层防御框架（已建立）
- **假设**: 弱模型能遵循结构化指令但不能自觉触发交互式 UI——护栏加在 prompt 层而非工具层
- **假设**: 强模型能识别护栏中的"对强模型透明"标记并跳过冗余自检
