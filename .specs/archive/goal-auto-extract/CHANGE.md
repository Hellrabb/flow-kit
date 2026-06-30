# CHANGE: Goal 自动提取修复 — 单阶段 + Pipeline 双模式

- **Change ID**: goal-auto-extract
- **创建日期**: 2026-06-18
- **路径建议**: 最短（直接改 2 个文件）
- **状态**: archived

## Why

pipeline-goal 实现了 goal 的 pipeline 机制，但 goal 自动提取（AC-5 单阶段 + AC-12 pipeline sub-goal）有缺口：

1. **单阶段**：4-dev 会建议 goal，但用户仍需手动输入 `/flow goal ...` 确认
2. **Pipeline**：`/flow goal --pipeline` 写入空 `phase_sub_goals: {}`，AC-12 的自动提取从未触发

## What

修复 4-dev.md 入场 Goal 检测 + SKILL.md 写入逻辑，使两种模式都能自动提取建议并一键确认。

## 影响面

- [x] 修改 4-dev.md「入场 Goal 检测」段
- [x] 修改 SKILL.md `/flow goal` 写入逻辑

## 范围排除

- 不改 GO.md / 5-test / 6-review / 7-integration（这些只是 sub-goal 消费者，上游数据源修好即可）

## 验收线

- 进入 4-dev 无 goal → AI 展示单阶段 + pipeline 双选项 → 用户说"pipeline" → goal 自动设定含 phase_sub_goals
- 用户说"单阶段"或直接确认 → 单阶段 goal 自动设定
