# UAT: 补齐 PCSC 表两个缺失检查项

- **Change ID**: fix-pcsc-gaps
- **UAT 日期**: 2026-06-22

## UAT-1: 7-integration PCSC 含 T-FIX 关闭检查

**步骤**：打开 `flow-kit-bundle/flow-kit/prompts/7-integration.md`，确认 PCSC 表第 7 行为 T-FIX 关闭检查。

**结果**: ✅ 通过 — row 7 已加入，验证方式为 `grep -c 'T-FIX.*status="pending"' ... 输出 0`

## UAT-2: 6-review PCSC 含 CONTEXT 技术债写入检查

**步骤**：打开 `flow-kit-bundle/flow-kit/prompts/6-review.md`，确认 PCSC 表第 7 行为技术债同步检查。

**结果**: ✅ 通过 — row 7 已加入，含 N/A 分支（4.1 未触发时可跳过）
