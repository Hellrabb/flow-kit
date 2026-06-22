# CHANGE: 更新说明文档以同步近期修改

- **Change ID**: docs-update
- **创建日期**: 2026-06-22
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

近一个月 flow-kit 经历了大量功能迭代（PCSC/PG 双层防护、pipeline rollback 智能回退、`--from 0` 全链路 pipeline、goal 自动提取、阶段跳过漏洞修复等），但 `FLOW-KIT-用户指南.md`（977 行）未同步更新。用户看到的文档与实际功能严重脱节：

- 新增的 pipeline goal `--from 0`、PCSC/PG 双层防护、rollback 机制等完全未提及
- CONTEXT.md 术语表已积累了大量新术语（toll-gate / PCSC / PCG / artifact verification / cross-phase condition 等），但用户指南未引用
- 部分旧内容描述的是已被替换的机制（如旧版 single-phase goal 的某些行为）

## What（做什么）

1. **新增内容**：在用户指南中补充以下主题：
   - Pipeline goal 全链路模式（`--from 0`，0→…→7）
   - PCSC（Phase Completion Self-Check）+ PCG（Phase Completion Gate）双层防护
   - Pipeline rollback 智能回退机制
   - Goal 自动提取（auto-extraction）与条件评估
   - Toll-gate 阶段过渡暂停模型
   - `/flow goal` 命令完整用法（pipeline / gate-config / sub-goal）
2. **删除过时内容**：移除已被替换的旧机制描述，修正不准确的引用
3. **同步术语**：与 CONTEXT.md 术语表对齐，确保概念一致
4. **README.md**（72 行）：如有必要，更新概要描述

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不修改 flow-kit 核心引擎 prompts/templates/reference（这些是"代码"，不是"说明文档"）
- 不修改 `.specs/CONTEXT.md`（已于 2026-06-17 更新，5 天内）
- 不引入新的文档格式或工具链
- 不翻译为非中文（当前用户指南仅中文）

## 验收线（粗粒度，不是 AC）

- `FLOW-KIT-用户指南.md` 包含 pipeline goal / PCSC/PG / rollback / goal 自动提取等新功能的准确描述
- 用户指南中无已废弃机制的误导性描述
- 术语使用与 CONTEXT.md 术语表一致

## 风险与未知

- 用户指南 977 行，需逐段审查，工作量大
- 部分近期 change 的 DESIGN.md § 9 架构沉淀尚未同步到 ARCHITECTURE.md，可能影响文档准确性
- 无（如发现新风险在 DESIGN 阶段补充）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
