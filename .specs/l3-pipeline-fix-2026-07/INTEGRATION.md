# INTEGRATION: L3 审查管线 + Stop Hook 性能修复

- **Change ID**: `l3-pipeline-fix-2026-07`
- **归档日期**: 2026-07-11
- **Pipeline**: 0→1→2→3→4→5→6→7 ✅

---

## 产物清单

| 文件 | 大小 | 状态 |
|---|---|---|
| CHANGE.md | 3.9K | ✅ |
| REQUIREMENT.md | 8.5K | ✅ 8 AC |
| DESIGN.md | 19.0K | ✅ 6 决策 + §9 沉淀 |
| TASK.md | 16.6K | ✅ 10 tasks, 5 waves |
| TEST.md | 4.7K | ✅ 5 轮金字塔 |
| REVIEW.md | 3.3K | ✅ 8 AC 对照 |
| BASELINE.md | 5.5K | ✅ 性能基线 + 优化记录 |
| INDEPENDENT-REVIEW-1.md | 10.2K | ✅ L2 pass |
| INDEPENDENT-REVIEW-2.md | 20.4K | ✅ L2 pass（修后） |
| INDEPENDENT-REVIEW-3.md | 14.3K | ✅ L2 pass（修后） |
| INDEPENDENT-REVIEW-5.md | 13.3K | ✅ L2 pass（修后） |
| INDEPENDENT-REVIEW-6.md | 11.5K | ✅ L2 pass（修后） |

## 代码变更

- **33 files, +582/-115 lines**
- 核心文件: `common.sh` (+52), `l3-review.sh` (+157), `29-independent-review.sh` (+69), `auto-checkpoint.sh` (+9)
- 15 hook 模块各 +2~5 行（perf timing 探针）
- 测试: `test_common.bats` (+44), `test_l3_pipeline_fix.bats` (new, 8 tests)

## 验收

| AC | 状态 |
|---|---|
| AC-1 · git diff 上限 | ✅ 并集策略 + token 估算 |
| AC-2 · 新文件可见 | ✅ 动态 _new_limit |
| AC-3 · 智能截断 | ✅ 三遍扫描 + 尾部锚点 + fallback |
| AC-4 · 积压扫描 | ✅ _l3_scan_backlog + ≤3 限流 |
| AC-5 · 上下文注入 | ✅ _l3_inject_context + 免责声明 |
| AC-6 · 性能提升 | ⚠️ 异步化已实现（L3_BACKGROUND=1 opt-in），预估降幅89%，待实机验证 |
| AC-7 · 零回归 | ✅ 482 bats 0 fail + bash -n 全过 |
| AC-8 · L3 降级 | ✅ HTTP 状态码捕获 + error 处理 |

## 已知遗留

1. AC-6 待实机验证（Stop hook 生产环境测量）
2. SessionStart `flow-kit-resume.sh` 未添加 `.l3-bg-{phase}.json` 收割逻辑（v2）
3. `L3_BACKGROUND=1` opt-in 后性能收益待实测

## 经验教训（提取到 LESSONS.md）

- L-041: auto-checkpoint 自引用竞态
- L-042: `--background` 默认 sync 安全原则
