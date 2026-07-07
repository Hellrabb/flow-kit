# CHANGE: L3 独立审查全面修复

- **Change ID**: l3-comprehensive-fix
- **创建日期**: 2026-07-07
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

flow-kit 的 L2/L3 双层独立审查机制（independent review）在 daily use 中暴露出 4 个问题，影响开发体验和审查可靠性：

1. **L3 结果注入 gap**：L3（外部模型审查）的结果不能像 L2（子 agent 审查）那样自动注入 session context，用户每次都得手动触发才能看到 L3 说了什么
2. **L3 长度限制导致假阳性**：L3 输出似乎被截断，审查结果不完整，导致偏高假阳性（标记了实际不存在的问题）
3. **`.done` 重复触发**：已写入 `.independent-review-<phase>.done` 后，某些场景下 Stop hook 仍会重复触发 L3（例如 phase 7 后与 agent 讨论时），造成不必要的 delay 和 token 消耗
4. **Phase 5/6/7 L2 自动拉起断裂**：Phase 4 不触发 L2/L3 是设计预期，但 Phase 5/6/7 的 L2 自动拉起链条因此断裂——gate_config 已正确配置，L3 正常工作，但 L2（子 agent 独立审查）经常无法自动触发，需手动拉起

这些问题叠加导致用户对独立审查机制的信任度下降，且每次 session 都要额外手动操作，违背了"自动门禁"的设计初衷。

## What（做什么）

全面审计 flow-kit L2/L3 独立审查的完整实现链路（hooks → prompts → SessionStart 注入 → .done 协议 → phase transition 触发），定位 4 个问题的根因，制定修复方案并全部实施。修复后确保：

- L3 结果自动注入 session（与 L2 行为一致）
- L3 输出完整、假阳性可控
- `.done` 文件可靠阻止重复触发
- Phase 5/6/7 L2 自动拉起正常工作

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增需求规格）
- [x] 影响 `DESIGN.md` / 引入新 ADR（独立审查协议修订）
- [ ] 影响现有 AC（不涉及已有 change 的 AC）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不新增 L2/L3 审查维度（如安全性、性能等），只修现有机制的 bug
- 不改变 L2/L3 的审查内容/标准，只修执行机制的可靠性
- 不引入 Phase 4 的 L2/L3 触发（保持 Phase 4 不触发这一设计决策）
- 不重构 Stop hook 整体架构（只修 29-independent-review.sh 及相关）

## 验收线（粗粒度，不是 AC）

- 4 个问题全部有 fix，且通过 `npx bats test/` 全部测试
- 手动验证：模拟 Phase 5/6/7 场景，L2 + L3 均自动触发且结果可见
- 手动验证：`.done` 写入后 Stop hook 不再重复触发 L3

## 风险与未知

- L2 在 Phase 5/6/7 的自动拉起断裂根因可能不在 hook 层面，而在 phase transition 的 gate 判断逻辑中——需要审计完整链路才能定位
- L3 长度限制可能是 Anthropic API 层面的 token 限制，不一定能在 flow-kit 侧彻底解决
- 修复 `.done` 重复触发需要理解 Stop hook 的触发条件（CC 每次 stop 都跑全部 hook 链，还是仅特定条件），可能需要调整 hook 配置

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
