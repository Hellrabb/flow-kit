# L2 空值归因清单（AC-2 交付物）

> **机械再生**：`bash corpus-count.sh --attribution`（不是手抄快照 —— 语料是活的：
> 本 change 自己的审查文件会不断新增，对活语料的不变量是**每份空值都在本清单中**）。
> 生成时间：2026-09-18T20:16:18+08:00

| # | 工件（.specs/ 相对路径） | 旧实现取值 | 旧值来源段 | L2 段内锚定 verdict 行数 |
|---|---|---|---|---|
| 1 | `archive/2026-07-11-health-fix-l3-2026-07/INDEPENDENT-REVIEW-3.md` | `pass` | `## L3 重审（deepseek-v4-flash[1m]` | 0 |
| 2 | `archive/2026-07-11-health-fix-l3-2026-07/INDEPENDENT-REVIEW-5.md` | `fail` | `## L3 重审（deepseek-v4-flash[1m]` | 0 |
| 3 | `archive/2026-07-11-health-fix-l3-2026-07/INDEPENDENT-REVIEW-6.md` | `fail` | `## L3 重审（deepseek-v4-flash[1m]` | 0 |
| 4 | `archive/2026-07-21-gate-review-fix/INDEPENDENT-REVIEW-6.md` | `pass` | `## L3 重审（deepseek-v4-flash[1m]` | 0 |
| 5 | `archive/final-debt-cleanup-2026-08/INDEPENDENT-REVIEW-6.md` | `pass` | `## 主 agent 自审（L2 unavailable ·` | 0 |
| 6 | `archive/gate-integrity/INDEPENDENT-REVIEW-1.md` | `fail` | `## 主 agent 最终回应（2026-07-01）` | 0 |
| 7 | `archive/test-failures-fixup-2026-08/INDEPENDENT-REVIEW-2.md` | `pass` | `## 主 agent 自审（L2 unavailable ·` | 0 |
| 8 | `archive/user-guide-update/INDEPENDENT-REVIEW-7.md` | `fail` | `## L3 盲审（deepseek-v4-flash[1m]` | 0 |
| 9 | `l3-review-defects-2026-09/INDEPENDENT-REVIEW-5.md` | `—` | 本期新增工件（L2 段尚无结论行） | 0 |
| 10 | `l3-review-defects-2026-09/INDEPENDENT-REVIEW-6.md` | `—` | 本期新增工件（L2 段尚无结论行） | 0 |
| 11 | `l3-review-defects-2026-09/INDEPENDENT-REVIEW-7.md` | `—` | 本期新增工件（L2 段尚无结论行） | 0 |

**归因结论**：本清单覆盖全部空值（行数 = `corpus-count.sh` 的 `empty` 字段），
每行四字段均来自现场复算；非枚举恒为 0（第 6 个字段）。
