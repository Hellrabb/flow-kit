# ARCHIVE: 更新说明文档以同步近期修改

- **Change ID**: docs-update
- **归档日期**: 2026-06-22
- **执行链**: 0→1→2→3→4→5→6→7（全链路 pipeline）
- **产物清单**:
  - `.specs/docs-update/CHANGE.md`
  - `.specs/docs-update/REQUIREMENT.md`
  - `.specs/docs-update/DESIGN.md`
  - `.specs/docs-update/TASK.md`
  - `.specs/docs-update/TEST.md`
  - `.specs/docs-update/REVIEW.md`
  - `.specs/docs-update/ARCHIVE.md`（本文件）

## 变更摘要

更新 `FLOW-KIT-用户指南.md`（+145 行，977→1122），新增 §4.1 Goal 系统与 Pipeline 执行模型，覆盖：
- `/flow goal` 完整用法（单阶段 + pipeline 模式）
- Pipeline goal 全链路执行（`--from 0`，0→…→7）
- Toll-gate 阶段过渡暂停模型 + Auto-Advance 自动推进
- PCSC/PG 双层防护（含阶段跳过漏洞修复背景）
- Pipeline rollback 智能回退（失败分类表 + 动态下界）
- Goal 自动提取机制（native vs fallback）

同时更新 `/flow` 子命令表和 `README.md`。

## 修改文件

- `FLOW-KIT-用户指南.md`：新增 §4.1（145 行），更新子命令表
- `README.md`：修正文件名引用 `flow-kit-ecosystem-guide.md` → `FLOW-KIT-用户指南.md`
