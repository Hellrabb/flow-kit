# REVIEW: 更新说明文档以同步近期修改

- **Change ID**: docs-update
- **审查日期**: 2026-06-22
- **审查类型**: 文档审查（自审）

---

## 第一轮：Spec 合规

| AC | 要求 | 实际 | 判定 |
|----|------|------|------|
| AC-1 | pipeline 文档 ≥5 匹配 | 7 | ✅ |
| AC-2 | PCSC/PG 文档 ≥5 匹配 | 9 | ✅ |
| AC-3 | rollback 文档 ≥3 匹配 | 11 | ✅ |
| AC-4 | goal 自动提取 ≥3 匹配 | 5 | ✅ |
| AC-5 | 术语一致性 | toll-gate/PCSC/PCG/pipeline goal/auto_advance 与 CONTEXT.md 一致 | ✅ |
| AC-6 | 无过时内容 | 文档行数 1122（≤1300），无误导性旧行为描述 | ✅ |

## 第二轮：内容质量

- **准确性**：§4.1 Pipeline Goal / PCSC/PG / Rollback 内容与 `.specs/archive/` 下对应 CHANGE 的 DESIGN.md 一致
- **结构**：新增 §4.1 作为 §4 的子节，自然衔接"两大命令"概念。层级清晰（4.1.1~4.1.4）
- **语气**：与既有文档风格一致（中文技术文档 + 代码块 + ASCII 框图）
- **完整性**：覆盖 pipeline goal / toll-gate / auto_advance / PCSC / PCG / rollback / goal 自动提取 7 个功能

## 结论

✅ 通过。全部 6 条 AC 满足，内容质量合格，可进入集成归档。
