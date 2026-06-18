# CHANGE: Goal 从单阶段自循环扩展到跨阶段 Pipeline

- **Change ID**: pipeline-goal
- **创建日期**: 2026-06-18
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

当前 goal 机制仅作用于 phase 4（dev），用户设定 `pnpm test passes` 后 AI 在单个 task 内自主迭代直到条件满足。但用户的实际意图往往是跨阶段的——「帮我把这个 feature 从实现到上线做完」意味着 4-dev → 5-test → 6-review → 7-integration 一整条执行链都应该被 goal 驱动，而非每阶段手动触发一次。

这导致：用户设了 goal 后还要在 4/5/6/7 之间手动推进，goal 的"自主到底"承诺只兑现了 1/4。

## What（做什么）

新增 **Pipeline Goal 模式**：一个 goal 跨越执行链 4→5→6→7，AI 在每个阶段完成后自动推进到下一阶段。

核心设计决策（已与用户确认）：

| 决策点 | 决定 |
|---|---|
| Pipeline 范围 | **仅执行链 4→5→6→7**（跳过 0-3 人工决策密集阶段） |
| 人工决策处理 | **Toll-gate 暂停**：AI 做建议，人确认后继续 |
| 终止条件模型 | **混合**：顶层总目标 + 关键阶段门禁条件 |

### 关键行为

1. **用户设定 pipeline goal**：`/flow goal "feature X shipped"`，系统检测到 CC 原生 `/goal` 可用时走原生模式，不可用时走回退循环
2. **阶段自动推进**：4-dev 全部 task 完成 → 自动进入 5-test → 6-review → 7-integration
3. **Toll-gate 暂停点**：
   - 4→5 过渡：所有 task SUMMARY 就绪，询问"是否进入测试阶段？"
   - 5→6 过渡：测试报告就绪，询问"是否进入审查？"
   - 6→7 过渡：审查通过，询问"是否归档上线？"
4. **关键门禁（不通过则停）**：
   - 4-dev：每个 task 的 verify 必须通过
   - 6-review：brooks-review 无 🔴 Critical
5. **顶层条件**：用户设定的一句话目标（如 "feature X shipped to production"），pipeline 结束时自检是否满足

### 与现有单阶段 goal 的关系

- 现有 phase-4 goal 保持不变（向后兼容）
- Pipeline goal 是新增的 `scope: "pipeline"` 模式
- 用户可以选择设单阶段 goal 或 pipeline goal

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR（可能）
- [ ] 影响现有 AC（无现有 AC 涉及 goal）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不覆盖 0-3 阶段**（0-change / 1-requirement / 2-design / 2a-ui-design / 3-task）：这些阶段人工决策密集，不适合自动化 pipeline
- **不替代现有单阶段 goal**：phase-4 单 task goal 保持独立可用
- **不做「全自动模式」**（AI 替人做所有决策）：toll-gate 机制保证人在关键节点有否决权
- **不改变 CC 原生 `/goal` 的行为**：pipeline goal 是 flow-kit 层的编排，原生 `/goal` 仍只负责单阶段迭代

## 验收线（粗粒度，不是 AC）

- 用户执行 `/flow goal "feature X shipped"` 后，AI 自动完成 4→5→6→7，仅在 toll-gate 点暂停等待确认
- 关键门禁失败时 pipeline 暂停，AI 报告原因并等待用户决定（重试/跳过/放弃）
- 现有 phase-4 单阶段 goal 不受影响，`/flow goal` 无参数时行为不变

## 风险与未知

- **Toll-gate 疲劳**：如果 3 个暂停点让用户觉得"还是要我一直点"，体验可能不如预期。缓解：toll-gate 可以批量确认（"4→5→6→7 全自动，只在 6-review 有 Critical 时才停"）
- **中断恢复**：pipeline 中途 compaction/断线后，恢复时需正确读取 `phases_done` 和 `current_phase`，从断点继续而非重头开始
- **阶段失败回退**：如果 6-review 发现需要回 4-dev 修 bug，pipeline 需要支持回退到之前阶段（而非只能前进）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
