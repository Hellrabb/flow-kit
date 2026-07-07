# CHANGE: L3 审查结果反馈可见性修复

- **Change ID**: `l3-feedback-visibility`
- **创建日期**: 2026-07-07
- **路径建议**: 完整（需定位 → 需求 → 设计 → 实施 → 测试 → 审查 → 集成）
- **状态**: draft

---

## Why（为什么做）

L3（外部模型独立审查）在两条执行路径上都是静默运行的——agent 不知道 L3 跑了、不知道结论是什么。

**Path 1（PreToolUse 前置）**：`l3_review_with_timeout ... 2>/dev/null` 把 L3 API 输出的 stderr 全部丢弃；`cat >&2 "⏳ L3 独立审查中..."` 写入 hook 日志而非 agent 上下文。Agent 执行 transition jq → hook 静默跑 L3 → `.done` 出现在磁盘 → transition 放行。Agent 全程不知道 L3 发生了什么。

**Path 2（Stop hook 兜底）**：`flow-kit-resume.sh:143` 的 L3 报告注入 banner 触发条件是 `ir_status=="done" && ! -f "$ir_done"`，但 `pipeline-fallback-fix` 后 `l3_review_run()` 直接写 `.done`（不再只写握手文件），29 号 hook 还清理了握手文件。所以新路径下 banner 永远不会触发。L3 结果以静默文件形式存在磁盘上。

结果：L2 审查结果在对话中可见（子 agent 直接返回），L3 审查变成了"静默盖章"——它在跑，但 agent 从未被强制告知结果。

## What（做什么）

1. **F1（PreToolUse 路径）**：移除 `2>/dev/null`，将 L3 API 的关键输出（verdict + summary）路由到 agent 可见的渠道
2. **F2（Stop hook 路径）**：修复 `flow-kit-resume.sh` 的 L3 报告注入逻辑——检测 `.done` 存在 + `INDEPENDENT-REVIEW-<N>.md` 含 L3 段时，直接解析并展示 verdict 摘要

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改动 L3 审查的内容生成逻辑
- 不改动 L3 API 调用的超时/重试策略
- 不改动 `.done` 文件的格式或值域
- 不新增 hook 模块

## 验收线（粗粒度，不是 AC）

- 切阶段时（PreToolUse 路径），agent 能在对话中看到 L3 的 verdict + 一句话 summary
- 新 session 启动时（Stop hook 路径），如果上一轮 L3 已完成，agent 能看到 L3 的 verdict + 报告路径
- 两种路径的 L3 反馈格式一致

## 风险与未知

- PreToolUse hook 的 stderr 能否被 agent 感知？需确认 hook 输出到 agent 上下文的机制
- SessionStart banner 格式变更是否影响现有 resume 逻辑

---
> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
