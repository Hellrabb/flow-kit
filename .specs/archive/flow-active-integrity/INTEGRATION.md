# INTEGRATION: flow-active-integrity

- **Change ID**: flow-active-integrity
- **日期**: 2026-07-03
- **Pipeline**: 0→1→2→3→4→5→6→7 全部通过

---

## 产物清单

| 阶段 | 产物 | 状态 |
|---|---|---|
| 0 | CHANGE.md | ✅ |
| 1 | REQUIREMENT.md (6 AC) | ✅ |
| 2 | DESIGN.md (D1-D6, R1-R5, §9) | ✅ |
| 3 | TASK.md (4 tasks, 2 waves) | ✅ |
| 4 | 33-flow-active-integrity.sh + 接线 + PCSC prompts + 17 tests | ✅ |
| 5 | TEST.md (17/17 pass) | ✅ |
| 6 | REVIEW.md (6/6 AC 覆盖, 0 Critical) | ✅ |
| 7 | INTEGRATION.md (本文件) | ✅ |

---

## 变更摘要

- **L2**: 8 个阶段 prompt + GO.md 各加 1 条 PCSC 自检项（.flow-active 写入确认）
- **L3**: 新增 33-flow-active-integrity.sh Stop hook 模块（5 检查函数 + read-merge-write + 内置回退映射）
- **接线**: 00-gate.sh 新增 run_module 33（同时补齐遗漏的 31/32）；common.sh HOOK_MODULE_NAMES 追加
- **注册**: stop-hook.json 注册 flow_active_integrity 模块
- **测试**: test_flow_active_integrity.bats（17 cases: 12 AC + 5 NFR）
- **CONTEXT.md**: 新增 4 条术语（状态完整性/状态漂移/交叉验证/时效性检测）
- **CHANGELOG.md**: 测试基线 194→211

---

## 部署注意事项

- `flow-kit-bundle/` 中修改了 12 个文件，下次 `package-flow-kit.sh` 打包时自动包含
- user-scope `~/.claude/flow-kit/` prompts 已同步
- 33 号模块需 `correction-file.sh` 和 `flow-kit-artifacts.sh`（均已存在）
- 无新增外部依赖

---

## L2 独立审查记录

| 阶段 | 审查者 | Verdict |
|---|---|---|
| 1-requirement | qa-expert | fail → 3 Critical 修复 |
| 2-design | architect-reviewer | pass (4 Major 实施时处理) |
| 3-task | architect-reviewer | fail → 2 Critical 修复 |
