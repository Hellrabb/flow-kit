# CHANGE: 整合 CC /goal 到 flow-kit

- **Change ID**: integrate-goal-command
- **创建日期**: 2026-06-18
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

flow-kit 有 change 级目标（CHANGE.md Why + REQUIREMENT.md AC），但缺失 **session 级自主迭代**能力。Claude Code v2.1.139+ 内置了 `/goal` slash command，支持"设定完成条件 → Claude 自主跨 turn 循环直到条件达成"的模式。

当前痛点：
1. `4-dev` 阶段执行 task 时，用户需要逐 turn 手动提示"继续"，无法让 AI 自主工作到验收条件满足
2. REQUIREMENT.md 的 Given/When/Then AC 写好后就躺在文件里，没有在 4-dev 被执行层利用
3. `.flow-active` 只追踪 change/phase/task，不追踪"本次会话目标是什么"——compaction 后 AI 容易丢失方向感

整合 `/goal` 后，flow-kit 获得 session 级自主迭代能力，同时兼容不支持原生 `/goal` 的旧版 CC。

## What（做什么）

1. **`.flow-active` 扩展**：新增 `goal` 字段（condition + active_since + turns + status），持久化当前会话目标
2. **`flow` skill 新增 `/flow goal` 子命令**：set（委托 CC `/goal`）/ status（查看 CC goal 状态 + .flow-active 元数据）/ clear / fallback（内置回退模式）
3. **内置回退**：当 CC 版本 < v2.1.139 时，用 prompt 驱动的条件检查循环替代原生 `/goal`（每 turn 结束后检查条件是否满足）
4. **GO.md 路由声明展示 goal 状态**：每个阶段首轮可见当前 goal
5. **`4-dev.md` 入场自动提取 goal**：从 REQUIREMENT.md 的 Given/When/Then 验收准则自动生成 goal 建议
6. **`flow-kit-resume.sh` 恢复时输出 goal**：SessionStart 提示当前目标

## 视觉调性

非前端项目，跳过。

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增 goal 推导段，4-dev 入场读取 AC 生成 goal）
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（不修改已有 AC）
- [ ] 影响数据模型 / 迁移（`.flow-active` JSON schema 向后兼容——goal 为可选字段）
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不做**：独立的 evaluator 模型（内置回退用 prompt 文本检查，不调 Haiku API）
- **不做**：goal 在 4-dev 以外阶段的自主迭代（其他阶段 goal 仅展示，不驱动循环）
- **不做**：goal 模板库/预设（首次实现仅支持自由文本条件）
- **不做**：多 goal 并行（一个 session 只有一个 goal）
- **不做**：goal 执行历史持久化（仅 .flow-active 记录当前 goal 元数据，不保存历史 goal 列表）

## 验收线（粗粒度，不是 AC）

1. 用户在 4-dev 阶段可通过 `/flow goal` 设定完成条件，Claude 自主迭代直到条件满足或用户中断
2. CC 版本不满足要求时自动回退到内置迭代模式，体验一致
3. `4-dev` 入场时自动从 REQUIREMENT.md 提取 AC 建议 goal，用户一键确认或修改
4. 所有阶段的路由声明可见当前 goal 状态，compaction/恢复后 goal 不丢失

## 风险与未知

- **CC /goal API 稳定性**：原生 `/goal` 是 v2.1.139+ 的新功能，hook 接口可能在未来版本变化。内置回退提供了降级路径，风险可控
- **条件检查准确性**：内置回退用 prompt 文本匹配判断条件是否满足，对大模型输出质量有依赖。复杂条件（"所有测试通过且 lint 干净"）可能误判，需在 prompt 中明确"用工具验证"
- **自动提取质量**：从 REQUIREMENT.md AC 提取 goal 条件依赖 AI 理解能力，前端/后端/CLI 项目 AC 风格不同。首次实现用简单的文本提取规则，后续可升级

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
