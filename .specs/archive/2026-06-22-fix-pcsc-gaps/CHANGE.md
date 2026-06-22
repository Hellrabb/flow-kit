# CHANGE: 补齐 PCSC 表两个缺失检查项

- **Change ID**: fix-pcsc-gaps
- **创建日期**: 2026-06-22
- **路径建议**: 最短（仅改 2 个 prompt 文件各 1 行，无需求/设计/测试增量）
- **状态**: draft

---

## Why（为什么做）

PCSC（Phase Completion Self-Check）是 pipeline goal 各阶段的强制产物自检表，在 toll-gate 之前执行。当前 6-review 和 7-integration 的 PCSC 表各缺一个关键检查项：

- **Gap 1**：7-integration 归档前不检查 T-FIX 是否全部关闭。T-FIX 有两个来源（6-review 审查发现 + 7-integration 失败诊断），都回流到 4-dev 执行。若归档时不验证 T-FIX 状态，可能带着未修复的 Critical 问题归档。
- **Gap 2**：6-review 4.1 节（技术债评估）要求将 🟡 Scheduled 项"记入 `.specs/CONTEXT.md` 的「技术债」段"，但 PCSC 不验证是否真的写入了。这导致 review 发现的技术债可能从未沉淀到项目级文档。

两个 gap 都是"流程说了要做，但没有检查是否真的做了"——这是 PCSC 存在的核心意义。

## What（做什么）

1. **7-integration PCSC**：新增一行检查项，验证 `TASK.md` 中所有 `T-FIX-XX` 任务状态为 `done`，归档前必须全部关闭
2. **6-review PCSC**：新增一行检查项，验证若 4.1 节触发且有 🟡 Scheduled 产出，已写入 `.specs/CONTEXT.md` 技术债段

改动范围：仅修改 `flow-kit-bundle/flow-kit/prompts/7-integration.md` 和 `flow-kit-bundle/flow-kit/prompts/6-review.md` 的 PCSC 表，各加 1 行。同步到运行时 `~/.claude/flow-kit/prompts/`。

## 影响面

- [x] 影响 `REQUIREMENT.md`（增量很小，仅记录 AC）
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（无现有 AC 受影响）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改其他 6 个 prompt 的 PCSC 表（已完整）
- 不改 GO.md preflight gate（已通用覆盖）
- 不改 RULES.md（R2.6 已覆盖）
- 不新增模板文件
- 不验证 CONTEXT.md 技术债条目格式/编号一致性（那是 M-health 的职责）

## 验收线（粗粒度，不是 AC）

- 7-integration PCSC 表新增 T-FIX 关闭检查行，归档前若 T-FIX 未全 done → ❌ 阻断归档
- 6-review PCSC 表新增 CONTEXT 技术债写入检查行，4.1 触发且有产出但未写入 → ❌ 阻断 toll-gate

## 风险与未知

- 无。改动最小（2 行），不涉及逻辑变更，不影响现有流程。

---
