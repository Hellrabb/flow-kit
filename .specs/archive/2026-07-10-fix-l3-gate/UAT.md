# UAT: fix-l3-gate · 用户验收测试

- **Change ID**: fix-l3-gate
- **执行日期**: 2026-07-10
- **状态**: 无需手动 UAT

---

## UAT 覆盖说明

本 change 为 Bash hook 脚本修复（L3 gate 机制三连异常），5 条 AC 全部由 bats 自动化测试覆盖（22 tests），无需手动 UAT 步骤。

| AC | 自动化覆盖 | UAT 需求 |
|---|---|---|
| AC-1 L3 重审触发 | bats #1-2, #12, #14 | 无（文件系统 mtime 行为可自动验证） |
| AC-2 .done fail 不写 | bats #3-4, #13, #16 | 无（KVP 格式 + 文件存在性可自动验证） |
| AC-3 .done pass 写 | bats #5-6 | 无 |
| AC-4 phase 四字段同步 | bats #7-9, #15, #17-22 | 无（jq 输出可自动验证） |
| AC-4 补充（4-dev.md + pipeline-gates.md） | L2 审查发现后已修复 | 无 |
| AC-5 回退放行 | bats #10-11 | 无 |

**全量回归**: 441 tests / 0 fail / exit 0 ✅
