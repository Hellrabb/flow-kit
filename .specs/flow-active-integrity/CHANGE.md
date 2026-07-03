# CHANGE: 将 .flow-active 状态完整性纳入 L2/L3 检查

- **Change ID**: flow-active-integrity
- **创建日期**: 2026-07-03
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

`.flow-active` 是 flow-kit 的运行时状态文件，跨 session 持久化 phase / task_id / change_id / goal 进度 / token_spent。当前 L2（prompt 自检表）和 L3（hook 证据链）均未覆盖 `.flow-active` 的完整性验证，导致以下四类漂移：

1. **phase/task 切换漏写**：AI 执行 `/flow phase N` 或 `/flow task T<N>` 后忘记 jq 更新 `.flow-active`，下次 session 恢复时读到过期状态
2. **pipeline goal 字段漂移**：`current_phase`、`phases_done`、`gates`、`turns` 等子字段与实际执行进度不同步——例如 toll-gate transition jq 执行了但 `phases_done` 未追加
3. **change_id 不一致**：`.flow-active.change_id` 与实际 `.specs/<id>/` 目录不对齐（如 change 已归档但 change_id 残留、或 change_id 为 null 但已有活跃产物目录）
4. **token_spent 未维护**：字段定义后从未被更新，形同虚设
5. **updated_at 过期**：`.flow-active.updated_at` 长时间未刷新（如跨天 session），表明最近一次操作后状态文件未 touch，可能是漏更新的信号

这些漂移在弱模型场景下更严重（模型易跳步骤），且当前无任何自动化检测手段。

## What（做什么）

在 L2（prompt 自检表）和 L3（hook 证据链）两层各加一套 `.flow-active` 完整性检查：

- **L2**：在各阶段 prompt 的自检表中加一项——确认 `.flow-active` 关键字段（phase / task_id / change_id）与实际操作一致，已通过 jq 写入
- **L3**：Stop hook 新增模块（或扩展现有 `28-weak-model-compliance.sh`），事后验证 `.flow-active` 字段与磁盘产物的交叉一致性（如 change_id 对应目录存在、phase 与产物对齐、updated_at 在合理时间窗口内）

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改变 `.flow-active` 的 JSON schema（只加检查，不改结构）
- 不重构现有 hook 模块架构（在现有框架内扩展）
- 不做实时文件监控（inotify/daemon）——只在 session 边界（Stop hook）和 prompt 自检点检查
- 不自动修复检测到的漂移——只报告 + 矫正提示，修复由人工或 `/flow doctor` 完成

## 验收线（粗粒度，不是 AC）

- bats 测试覆盖全部四种漏更新场景的 L3 检测逻辑
- 端到端验证：跑一次完整 pipeline（0→7），确认 `.flow-active` 字段在每阶段结束后与实际产物一致，不一致时 hook 产出矫正报告

## 风险与未知

- L2 自检表加项可能增加 prompt 长度（需控制在每阶段 ≤3 行，遵循 flow-kit RULES.md AC-7 反啰嗦约束）
- L3 `.flow-active` 交叉验证的"合理时间窗口"阈值需要设计（太严误报、太松漏报）
- `token_spent` 的更新机制需要确定——是 AI 手动 jq 更新还是 hook 自动统计（后者更可靠但实现复杂）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
