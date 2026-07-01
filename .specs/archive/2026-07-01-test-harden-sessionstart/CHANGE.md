# CHANGE: SessionStart 测试从骨架升级为真实 hook 执行测试

- **Change ID**: test-harden-sessionstart
- **创建日期**: 2026-07-01
- **路径建议**: 最短（TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

2026-07-01 Post-Sweep 健康检查（91/100）发现 `test_flow_kit_resume.bats` 和 `test_stop_report_reminder.bats` 仅验证 JSON 数据形状（`jq -r '.change_id'`），未验证 hook 脚本的**实际执行行为**（source 脚本 + 喂 stdin → 验证 stdout 输出）。虽然 bash -n 兜底了语法错误，但 hook 的逻辑回归（如 banner 构建错误、correction injection 失效）无法被当前测试捕获。

## What（做什么）

将两个测试文件从"静态 JSON 字段验证"升级为"mock hook 环境 + 真实 source 执行 + 输出断言"：
- 构造最小 mock 环境（HOOK_EVENT / SESSION_ID / PROJECT_ROOT / TRANSCRIPT_PATH）
- 真实 source hook 脚本
- 验证 stdout 输出内容（banner 格式 / 关键字段 / correction 提示）

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修改现有测试文件，无行为变更

## 范围排除（这次不做）

- 不修改 hook 脚本本身（仅改测试）
- 不新增测试文件（仅升级已有的 2 个）
- 不引入 mock 框架（纯 bats + bash 内建）

## 验收线

- `bats test/test_flow_kit_resume.bats test/test_stop_report_reminder.bats` 全部通过
- 每个测试用例包含真实 `source` hook 脚本 + stdin mock
- `bash -n` 全量通过，无回归
