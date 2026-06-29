# CHANGE — 弱模型交互式 UI 触发强化

> change-id: `weak-model-interactive-ui`
> 创建: 2026-06-29
> 状态: proposed

## Why

**场景**：弱模型（deepseek-v4-pro / minimax-m2.7 / qwen3.6-35b-a3b 等）在执行 flow-kit 各阶段 prompt 时，即使 prompt 明确要求"反问用户"、"进入计划模式"、"弹出对话框"，弱模型也常常**直接跳过**交互式 UI 工具（`AskUserQuestion`、`EnterPlanMode`），表现为：

- 不问用户就直接假设答案继续执行
- 该进 Plan 模式时跳过，直接在聊天里出方案
- 幻觉出用户的选择，而不是真正调用工具弹出对话框

**痛点**：flow-kit 大量依赖交互式 UI 作为决策 gate（0-change 反问、2-design 技术栈选择、流程图中的确认点），弱模型一旦跳过这些 gate，后续阶段在错误假设上展开，产出不合预期。

**protect the weakest 原则**：按现有设计哲学，prompt 应确保"最弱模型也能触发交互式 UI"，强模型不受影响。

## What

对 flow-kit 全链路（GO.md + 0-change 至 7-integration + 关键 reference）进行系统性扫描，找出**所有要求触发交互式 UI 但弱模型容易跳过**的点，在每个点加"弱模型护栏"——结构化自检 + 工具调用模板 + L3 证据链验证，确保弱模型**真正调用了工具**而不是幻觉已调用。

**核心目标**：prompt 里写了"反问用户"→ 弱模型必须实际调用 `AskUserQuestion`；写了"进入计划模式"→ 弱模型必须实际调用 `EnterPlanMode`。

## 影响面

- [x] flow-kit prompts（0-change 至 7-integration）
- [x] flow-kit GO.md（路由层交互点）
- [x] flow-kit reference（toll-gate 协议等共享片段）
- [x] 可能需要新增 reference 共享片段（交互式 UI 触发护栏模板）
- [ ] 不影响 CC 原生工具实现（`AskUserQuestion` / `EnterPlanMode` 是 CC 内置，不改）
- [ ] 不影响 `flow-kit-bundle/` 打包逻辑
- [ ] 不影响 `.claude/hooks/` 钩子系统

## 范围排除

- ❌ **不改 CC 原生工具行为**（`AskUserQuestion` / `EnterPlanMode` / Permission Prompt 是 Claude Code 内置，flow-kit 只能强化 prompt 引导）
- ❌ **不处理权限提示弹窗**（用户反馈权限提示正常触发，本次不碰）
- ❌ **不改变交互流程逻辑**（该反问还是要反问，该进 Plan 还是要进 Plan，只修"弱模型跳过了"的问题）
- ❌ **不引入新工具/新依赖**
- ❌ **不修改 brooks-lint 插件**（那是另一个独立插件）

## 验收线

1. 全链路扫描完成，输出所有"交互式 UI 应触发点"清单
2. 每个点位加护栏后，至少 1 个 regression demo 验证弱模型确实调用了工具（不可跳过）
3. 现有强模型行为不变（护栏不引入额外啰嗦或重复弹出）
4. 全量 bats 测试通过（已有的 102 tests 不能挂）
