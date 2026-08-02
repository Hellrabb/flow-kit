# CHANGE: 吸收 superpowers v6.0 token/性能优化经验到 flow-kit

- **Change ID**: superpowers-v6-absorb
- **创建日期**: 2026-08-02
- **路径建议**: 完整（pipeline goal 已锁定 0→7）
- **状态**: draft

---

## Why（为什么做）

- **外部信号**：superpowers v6.0（2026-06-16 发布，作者 Jesse Vincent）声称 Claude Code / Codex 上"2x 速度 + 50% token 削减"。独立 benchmark（Medium, UdaykiranEstari）复现 ~14% token / ~9% cost 削减——数字有 gap 但**方向可证**：源码里能直接看到机制（合并 reviewer / 文件 handoff / terse contract）。
- **flow-kit 当前痛点**：
  - `prompts/6-review.md` 跑 **3-4 轮**独立审查（spec compliance + code quality + UI visual + cross-model spot-check）——比 superpowers v5 还重，正是 v6 砍掉的模式
  - `prompts/4-dev.md` 721 行/34KB，每个 task fresh reload，占 pipeline 总成本 **40%**
  - 任意 finding 都可能触发 fix loop，没有 severity gating
  - 调度不声明 model，silently 继承 session 最贵 tier
- **TOLL-GATE**：不吸收的话每次跑中型 change（5 task）都付约 380K tokens 的代价；以季度 10 个 change 计，累积浪费 1M+ tokens。差距随时间放大。

## What（做什么）

将 superpowers v6.0 的 **10 项可移植经验（G1-G10）** 落地到 flow-kit bundle，分三类改动：

**新增脚本（B2/B3 类比）**：
- `flow-kit-bundle/flow-kit/scripts/review-package`（46 行 bash，预烤 git diff/metadata 到文件）
- `flow-kit-bundle/flow-kit/scripts/task-brief`（41 行 awk，从 TASK.md 提取当前 task 到文件）

**Prompt 改造（B1/B4/B5/B6/B7/B9）**：
- `6-review.md` 合并 spec + code-quality + UI 三轮为单次结构化审查（保留并加强 cross-model spot-check 作为独立第 2 轮）
- 所有 review 类 prompt 加 terse contract（"no preamble, no summary, verdict-first"硬约束）
- 所有 phase prompts 顶部加 narration constraint（"between tool calls, narrate at most one short line"）
- TASK.md XML 加 `model-tier` 属性（cheap/standard/top）
- review prompt 加 severity gating（Critical/Important 入 loop / Minor 入 ledger 延后）
- dispatch prompts 禁带累积历史（B9）

**架构扩展（C3/C4/B8）**：
- `.flow-active.goal.task_progress[]`：per-task commit SHA + fix 轮数 + deferred findings
- phase 3→4 之间加 plan-conflict-scan 子步骤
- GO.md 审计压缩（参照 superpowers v6.1 121→62 行经验）

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增多条 AC 围绕 token 削减目标、新脚本行为、severity gating 行为）
- [x] 影响 `DESIGN.md` / 引入新 ADR（review 架构变更、`.flow-active` schema 扩展、TASK.md XML schema 扩展、新 `scripts/` 模块、severity 维度）
- [ ] 影响现有 AC（无既有 AC 受影响——这是新功能/优化）
- [ ] 影响数据模型 / 迁移（不适用——是 markdown/bash 工具包）
- [ ] 影响外部 API 兼容性（无外部 API）
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不替换 flow-kit 的 hook-driven enforcement 哲学**——superpowers 是 prompt-driven，flow-kit 保留 hook 系统作为弱模型鲁棒性的核心机制（ADR-001）
- **不引入 superpowers 的周边设施**——bootstrap companion、sandboxed file server、per-session auth key 等不在 flow-kit 哲学范围内
- **不引入 harness 适配**（Codex/Kimi/Pi 等）——flow-kit 已是 vendor-neutral markdown
- **不重写既有 13 个 ADR**——只新增 ADR 不修订旧的（除非直接冲突，DESIGN 阶段判断）
- **不复制 superpowers 的 evals/ 子模块系统**——flow-kit 用 bats 测试，不引入 LLM-judged drill
- **不修改 brooks-lint 集成**——保持现状，不在本次 change 范围

## 验收线（粗粒度）

1. **pipeline 单 change 总 token 在 baseline 上减少 ≥25%**
   - baseline：5 task 中型 change ≈ 380K tokens（per flow-kit token 表）
   - target：≤285K tokens
   - 验证方式：跑一次 baseline + 一次 post-change 对比（同等复杂度的样例 change）
2. **review phase token 减少 ≥40%**
   - baseline：25-50K（4 轮）
   - target：≤15-30K（合并 + 加强 spot-check）
3. **所有新 prompt 段落 + 脚本有 bats 测试覆盖**
4. **向后兼容（旧 TASK.md 仍能跑）**：
   - 旧 TASK.md（无 `model-tier` 属性）→ fallback 到 standard tier
   - 旧 `.flow-active`（无 `task_progress` 字段）→ 视为空数组
   - 旧 review 输出（无 severity 标签）→ 视为 Important

## 风险与未知

- **token 削减数字的复现性**：superpowers 自报 50%，独立 benchmark 只复现 14-30%。flow-kit 实际收益不确定——DESIGN 阶段需定义 baseline 测量协议（同等 change 跑 pre/post 两遍）
- **OpenCode 是否支持 task-level model tier**：本环境是 OpenCode（GLM 5.2 / Sisyphus），不是 Claude Code。如果不支持，`model-tier` 只能作为 hint 写到 dispatch prompt 文本里，效果打折。**未决**：DESIGN § 6 需验证 OpenCode 的 task 调度 API
- **review phase 合并后 cross-model spot-check 的位置**：spot-check 物理上是独立 subagent 调用，无法合并到单轮。用户选"保留并加强"——DESIGN 需定义 spot-check 触发时机（每个 change 都跑？仅 Critical finding 触发？用户可选？）
- **TD-004（22% prompt 冗余）会被加重还是缓解**：合并 review prompts 可能减少冗余，但新增 terse contract 段又可能跨 prompt 重复。DESIGN § 9 需评估是否要把 terse contract 抽到 SYSTEM.md / RULES.md
- **`.flow-active.goal.task_progress` 与 T<N>-SUMMARY.md 的职责重叠**：两者都记 task 完成信息。DESIGN 需划定边界（task_progress = 实时机器读 / SUMMARY = 事后人读？还是合并？）
- **GO.md 压缩会不会破坏 routing 准确性**：superpowers 砍 per-platform walkthrough 是因为他们的 harness 适配已经稳定；flow-kit 的 GO.md 473 行包含了路由表 + token 预算表 + 工件 preflight gate，砍哪些段落需要谨慎评估

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
