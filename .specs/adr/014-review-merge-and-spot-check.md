# ADR-014: Review Phase 三轮合并 + Critical 触发 Cross-Model Spot-Check

**Status**: Proposed (superpowers-v6-absorb Phase 2)
**Date**: 2026-08-02
**Supersedes**: 无（首次定义 review 编排）
**Superseded by**: 无

## Context

flow-kit 当前 6-review.md 实际跑 4 轮审查：

1. 第一轮 Spec 合规审查
2. 第二轮 代码质量审查（书本驱动 6 维衰退风险）
3. 第三轮 UI 视觉审查（仅前端项目）
4. 第四轮 补充审查（可选 · 按触发条件跳）

每轮独立 dispatch，diff bytes 多次进 controller context，~40K tokens / change 用在 review 阶段。

superpowers v6.0（2026-06-16 发布）的实证经验：
- 把 spec-reviewer 和 code-quality-reviewer 合并为单 task-reviewer → -15% tokens（blog）
- 用 review-package 脚本预烤 diff 到文件 → -10% tokens
- cross-model spot-check 仅在 Critical finding 触发，不每次跑 → -10-15K tokens / change

flow-kit 的 review 阶段成本在 pipeline 中排第二（dev 阶段第一）。本 change 借鉴 superpowers 模式合并 + Critical 触发。

## Decision

**单轮合并审查 + Critical-finding 触发 cross-model spot-check**：

1. 6-review.md 重构为单轮结构化审查，单一 REVIEW.md 产物含三视角段：
   - Spec 合规 verdict
   - 代码质量 verdict（6 维衰退风险）
   - UI 视觉 verdict（仅前端）
   - 综合评估（pass / fail + Critical 列表）

2. 综合评估含 ≥1 Critical finding 时，自动触发 cross-model spot-check（独立 subagent，外部模型盲审）。无 Critical 时跳过。

3. Minor finding 不入 fix loop，写入 `.specs/<id>/MINOR-DEFERRED.md`，phase 7-integration 阶段 triage。

4. 删除原"第四轮 补充审查"段（spot-check 替代）。

## Consequences

**正面**：
- review 阶段 token 削减 ~40%（4 轮 dispatch → 1 轮 + 可选 spot-check）
- Critical 风险仍被独立视角兜底（spot-check 触发）
- Minor finding 不卡 fix loop，提速 task 完成

**负面**：
- 失去"每条 Critical/Important finding 都被 2 个模型审视"的强保证（spot-check 仅 Critical 触发，Important 单轮判定）
- 综合评估的"Critical 判定"质量依赖 reviewer prompt 的严格执行（弱模型风险）
- spot-check 触发条件靠 AI 判断，可能漏判 Critical

**Neutral**：
- REVIEW.md 产物结构变化，既有解析器（如有）需更新——但 flow-kit 无既有 REVIEW.md 自动解析器

**缓解**：
- AC-B1 grep `## Round 1/2/3/4` 不再出现，强制单轮
- AC-B2/B3 spot-check 触发逻辑由 hook 层（未来）+ prompt 层（本 change）双保证
- ADR-001 protect-the-weakest：reviewer prompt 加结构化自检 gate 防 Critical 漏判
- 后续 change 可考虑 hook 层自动判定 Critical（基于 REVIEW.md grep）

## 触发条件

- 本 change 实施时（phase 4）：6-review.md 重构
- 本 change 验收时（phase 5）：bats 测试覆盖
- 本 change 集成时（phase 7）：更新 FLOW-KIT-用户指南.md review 阶段描述
