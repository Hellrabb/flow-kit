# CHANGE: Pipeline Goal 扩展到 Phase 0 起始

- **Change ID**: goal-pipeline-phase0
- **创建日期**: 2026-06-20
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

当前 pipeline goal 硬编码从 phase 4 起步（4→5→6→7），但实际使用中存在从更早阶段开始的诉求：

- **场景 1**：用户提了一个新想法，想用 pipeline goal "一句话驱动全流程"，从 0-change 自动推进到 7-integration，中间 toll-gate 暂停确认
- **场景 2**：用户已完成 0-2（CHANGE + REQUIREMENT + DESIGN），想从 phase 3（拆任务）启动 pipeline 覆盖 3→4→5→6→7
- **场景 3**：用户只想 pipeline 覆盖 2→3→4（设计→拆任务→开发），测试和 review 另外做

当前设计把起始阶段写死为 "4"，无法满足上述场景。需要让 pipeline goal 的起始阶段可配置，同时保持默认行为不变（向后兼容）。

## What（做什么）

1. **`/flow goal --from <n>` 参数**：允许指定 pipeline goal 起始阶段（0-7），默认 `--from 4` 保持向后兼容
2. **0-3 阶段 pipeline 适配**：当 pipeline 从 0/1/2/3 起始时，对应阶段 prompt 在每阶段完成后输出 toll-gate 提示，等待用户确认后自动推进到下一阶段
3. **condition 语法扩展**：支持跨阶段复合条件（如 `"phase 0 CHANGE confirmed AND phase 3 tasks ready AND all tests pass"`），替代当前仅覆盖 4-7 的单层 condition
4. **`.flow-active` schema 更新**：goal 对象新增 `start_phase` 字段，`current_phase` 不再硬编码为 "4"

## 影响面

- [x] 影响 `REQUIREMENT.md` — condition 语法扩展需要规格化
- [x] 影响 `DESIGN.md` / 引入新 ADR — pipeline 架构从「固定 4-7 链」改为「可配置起点链」
- [ ] 影响现有 AC — 无已有 AC 受影响（pipeline goal 是 2026-06-18 新增 feature，本次是其首次扩展）
- [ ] 影响数据模型 / 迁移 — `.flow-active.goal` 新增 `start_phase`，旧 pipeline goal 回读时需兼容（缺失时默认 "4"）
- [ ] 影响外部 API 兼容性 — `/flow goal` CLI 新增可选 `--from` flag，不传时行为不变
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不改变** CC 原生 `/goal` 集成方式（native vs fallback 判定逻辑不变）
- **不改变** 单阶段 goal（`scope: "phase"` 或无 scope 字段）的任何行为
- **不改变** toll-gate / gate_config 机制本身（gates 键名从 `4→5` 改为动态，但暂停-确认模型不变）
- **不改变** 4-7 阶段 prompt 的 pipeline 行为（仅 start_phase / current_phase 从硬编码变为读 `.flow-active` 字段）
- **不引入**「全自动无暂停」模式（0-3 阶段人工决策密集，必须保留 toll-gate）
- **不改变** goal auto-extraction 逻辑（仍从 REQUIREMENT AC 提取，仅当 pipeline 起始 ≤1 时触发）

## 验收线（粗粒度，不是 AC）

1. 用户执行 `/flow goal "完成整个 change 从提案到归档" --pipeline --from 0`，pipeline 从 phase 0 起步，每个阶段（0→1→2→3→4→5→6→7）完成后暂停等确认，确认后自动加载下一阶段 prompt
2. 用户执行 `/flow goal "所有测试通过且 review 无 critical" --pipeline`（无 `--from`），行为与当前完全一致（默认从 4 起步）
3. 跨阶段复合 condition（如 `"CHANGE.md exists AND all tests pass"`）能被正确解析和评估

## 风险与未知

- **风险**：0-3 阶段交互密集（反问用户、确认需求 AC、选定技术栈），pipeline 自动化推进可能打断用户决策节奏 → 缓解：0-3 每阶段默认有 toll-gate 暂停，不自动跳过
- **风险**：condition 语法扩展增加复杂度 → 缓解：DESIGN 阶段明确语法边界，避免过度设计
- **未知**：pipeline 从 phase 0 起步时，condition 评估器需要在没有 REQUIREMENT.md 等文件时也能判断"phase 0 完成"→ 需在 REQUIREMENT 阶段明确各阶段的完成判定标准

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
