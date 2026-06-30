# CHANGE: Pipeline rollback 缺口修复

- **Change ID**: fix-pipeline-rollback
- **创建日期**: 2026-06-18
- **路径建议**: 最短（直接改 2 个文件）
- **状态**: archived

## Why

5-test 测试失败 + 7-integration 失败时，缺少显式的 pipeline rollback 选项（回退到 4-dev + 更新 phases_done）。

## What

- 5-test.md: 测试执行失败时，新增 pipeline rollback 提示
- 7-integration.md: 失败诊断段新增 pipeline rollback 选项（含 phases_done 更新）
