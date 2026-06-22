# SUMMARY: docs-sync T01-T06

- **Change ID**: docs-sync
- **完成日期**: 2026-06-22
- **执行模式**: Pipeline 全自动 (--from 0)

---

## T01 · brooks-tools 子节

✅ 在 FLOW-KIT-用户指南.md §8 新增 `### 8.1 brooks-tools 离线打包`
- 内容：4 工具表格 + 离线打包原因 + 安装行为 + shim 机制 + 当前限制
- verify: grep "brooks-tools" → 6 ≥ 3 ✅

## T02 · Pipeline 执行链描述

✅ 已有内容完整（含 --from 0、执行链 0→7、toll-gate 表格、auto_advance）
- verify: grep "--from 0|start_phase|0→1→2" → 5 ≥ 3 ✅

## T03 · README.md 更新

✅ 项目结构树更新（+ lib/、test/、完整 .specs/ 子树）+ 快速开始命令修正
- verify: 所有目录项均存在于磁盘 ✅

## T04 · flow-kit-ecosystem-guide.md 更新

✅ 层 1 新增"核心机制"表（Pipeline Goal / PCSC/PG / Rollback）
✅ 层 5 新增"brooks-tools 离线工具包"子节
- verify: grep "PCSC|PCG|rollback|brooks-tools" → 4 ≥ 4 ✅

## T05 · 全局清理

✅ 版本号：20260615 → 20260622
✅ README 快速开始命令修正（tar xzf + cd + install.sh）
✅ §11 文件结构索引修正（lessons/ → LESSONS.md、evolve/ → CHANGELOG.md、+ brooks-tools 目录）
- verify: 无过时版本号、无过时 pipeline 描述、无误导命令 ✅

## T06 · 三文档一致性终检

✅ AC-1 ~ AC-6 全 PASS
- AC-1: brooks-tools 6 mentions ✅
- AC-2: pipeline --from 0 5 mentions ✅
- AC-3: README structure matches disk ✅
- AC-4: ecosystem-guide 4 mentions ✅
- AC-5: no bad commands ✅
- AC-6: no outdated content ✅
