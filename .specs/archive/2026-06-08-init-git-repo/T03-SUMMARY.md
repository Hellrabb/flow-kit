# T03-SUMMARY: 建立技术债基线

- **Change ID**: `init-git-repo`
- **Task ID**: `T03`
- **状态**: ✅ done

---

## 做了什么

1. 尝试调用 brooks-lint:brooks-debt 技能扫描 Bash 项目（如 DESIGN.md R2 预期，Bash 项目产出有限，skill 未返回详细结果）
2. 按 T03 回退策略，手动建立 `.specs/LESSONS.md` 基线，5 条技术债：

| # | 严重程度 | 问题 |
|---|---|---|
| L-001 | 🟡 | 打包与安装逻辑耦合在同一文件 |
| L-002 | 🟡 | HOOK_SRC 硬编码开发机路径 |
| L-003 | 🔴 | 590 行零测试覆盖 |
| L-004 | 🟢 | 内联辅助函数未抽取为工具库 |
| L-005 | 🟡 | STAGING 变量无预检 |

每条含：位置 / 建议 / 状态 / 来源。

## 改动文件

- `.specs/LESSONS.md`（新建 · 首次创建）

## verify 输出

```
$ grep -c "🔴\|🟡\|🟢" .specs/LESSONS.md
5
```
→ 5 ≥ 1 ✅

## 6 维自查（R6.4）

纯文档任务，无生产代码改动。跳过 TDD + 6 维 self-review。

## 越界检查（R6.5）

- TASK write_files：`.specs/LESSONS.md`
- 实际 diff：`.specs/LESSONS.md`（新建）
- 越界：0 ✅
