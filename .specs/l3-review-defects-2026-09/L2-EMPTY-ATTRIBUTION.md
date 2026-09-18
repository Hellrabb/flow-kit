# L2 空值归因清单（AC-2 交付物）

> 由 `fk_extract_l2_verdict`（当前实现，限定 L2 层）对仓库全部 `INDEPENDENT-REVIEW-*.md` 复算
> 后，列出**提取为空**的工件及其在旧实现下的取值来源。生成于 2026-09-18。

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

**归因结论**：8/8 条目的 L2 段内锚定 verdict 行数均为 0（其中 3 条连 `## L2` 段都不存在）。
即「空」是诚实结果 —— 旧实现的取值来自 L3 段或主 agent 自审段，正是本 change 要消除的冒充。
