# TEST: 更新说明文档以同步近期修改

- **Change ID**: docs-update
- **测试日期**: 2026-06-22
- **测试类型**: 文档验证（grep 命令 + 人工通读）

---

## 测试矩阵

| AC | 验证方式 | 结果 | 详情 |
|----|---------|------|------|
| AC-1 | `grep -c "pipeline" FLOW-KIT-用户指南.md` | ✅ 7 matches (≥5) | 含 pipeline goal / --from / toll-gate / auto_advance / pipeline rollback |
| AC-2 | `grep -c "PCSC\|PCG\|双层防护\|Phase Completion" FLOW-KIT-用户指南.md` | ✅ 9 matches (≥5) | 含 PCSC/PG 定义、双层防护工作原理、阶段跳过漏洞修复 |
| AC-3 | `grep -c "rollback\|回退" FLOW-KIT-用户指南.md` | ✅ 11 matches (≥3) | 含失败分类表、动态下界、jq 通用化方案 |
| AC-4 | `grep -ci "goal.*自动\|自动.*提取\|auto.*extract" FLOW-KIT-用户指南.md` | ✅ 5 matches (≥3) | 含 goal 自动提取机制、native vs fallback 模式 |
| AC-5 | 术语一致性抽查（5 个核心术语） | ✅ 通过 | toll-gate(5) / PCSC(6) / PCG(4) / pipeline goal(7) / auto_advance(1) — 与 CONTEXT.md 一致 |
| AC-6 | 无过时内容 + 文档行数 | ✅ 通过 | 1122 行 (≤1300)，无已将旧行为描述为当前行为的内容 |

## 既有测试套件

```
npx bats test/ --tap → 72 tests (all pass)
```

文档变更不影响 bats 测试（纯 markdown 修改，无 Shell 代码变更）。

## 总结

全部 6 条 AC 通过。文档更新完成，无回归。
