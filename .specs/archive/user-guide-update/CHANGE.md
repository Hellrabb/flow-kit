# CHANGE: 用户指南全量更新 + interrupt/checkpoint 自动写入

- **Change ID**: user-guide-update
- **创建日期**: 2026-07-06
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

近期 flow-kit 经历了 4 个重大 change（l2-l3-granular-gate、pipeline-fallback-fix、gate-integrity、independent-review-gap），累计新增概念 30+ 条、hook 模块 4 个（27/28/31/32）、gate_config 值体系重构。但 FLOW-KIT-用户指南.md、README.md、flow-kit-ecosystem-guide.md 三份用户文档均停留在 2026-06-22 的 docs-sync，与当前功能严重脱节。

用户反馈痛点：interrupt/checkpoint 的用法不清晰，且 checkpoint 目前全靠手动 `/flow checkpoint` 调用，AI 不会在关键操作时自动写入——一旦会话中断，恢复时缺上下文，只能靠人脑回忆"上次做到哪了"。

## What（做什么）

1. **文档同步**：更新三份文档，覆盖 l2-l3-granular-gate / pipeline-fallback-fix / gate-integrity / independent-review-gap 四个 change 的全部用户可见功能
2. **interrupt/checkpoint 专项**：在用户指南中详细写明 checkpoint 的触发时机、手动用法、中断恢复流程、字段含义
3. **auto-checkpoint 改造**：让 flow-kit 在关键操作（编辑文件、测试失败、阶段切换、toll-gate 暂停等）时自动调用 `/flow checkpoint`，不再依赖 AI 自觉

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增 auto-checkpoint 需求）
- [x] 影响 `DESIGN.md`（auto-checkpoint 触发时机 + 实现设计）
- [ ] 影响现有 AC（无——这是新增功能，不改现有行为）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不新增 hook 模块（auto-checkpoint 在现有 prompt/hook 架构内用 jq 实现）
- 不改动 flow-kit 核心阶段逻辑（0-change ~ 7-integration 的阶段流转保持不变）
- CONTEXT.md 仅追加 auto-checkpoint 相关术语，不触发完整 evolve 流程
- 不碰 brooks-lint 文档

## 验收线（粗粒度，不是 AC）

- 三份文档覆盖以下全部功能且内容一致：gate_config L2/L3/both 开关、gate-config preset/shorthand、pipeline goal 0→7 完整用法、toll-gate + 门禁条件、auto_advance + fallback 兜底、独立审查四层架构、interrupt/checkpoint 完整说明
- 用户看完 interrupt 章节后能自主执行 `/flow checkpoint` → 中断 → `/flow-go 继续` 全流程
- AI 在编辑文件、测试失败、阶段切换等关键操作后自动写入 checkpoint，无需用户手动提醒

## 风险与未知

- auto-checkpoint 的触发频率需设计合理（太密 = 噪音，太疏 = 漏关键上下文）
- 三份文档的长期一致性靠本次 change 一次性对齐，后续 change 归档时仍依赖 docs-sync 策略（人工执行）
- auto-checkpoint 实现边界在 DESIGN 阶段需明确：是 prompt 层指令（依赖 AI 执行）还是 hook 层兜底（系统级保证）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
