# MINOR-DEFERRED: pre-commit-user-scope

| # | 来源 | 发现 | 处置 |
|---|---|---|---|
| P5-#2 | L2 phase5 🟢 | AC-1 冲突检测分支（FLOW_KIT_YES=1 skip / read -p）无行为测试 | 保留依赖：冲突块逐字保留 + 全量 bats 回归兜底。冲突分支可测试（temp repo + 既有 non-symlink pre-commit + FLOW_KIT_YES=1），4-dev 前可补 |
| P5-#3 | L2 phase5 🟢 | 新测试断言失败路径不清理 tmp 目录（bats 无 set -e，rm 在断言后）| 极小影响（/tmp 泄漏）。可在测试加 `trap 'rm -rf "$tmp_home" EXIT` 或移到 teardown |
| P6-#1 | L2 phase6 🟢 | deploy_pre_commit `ln -sf` 无 DRY_RUN guard（既有缺陷·DRY_RUN 模式下仍创建 symlink）| 既有缺陷非本次引入，scope 外。可在 DRY_RUN 统一治理 change 处理 |
| P6-#2 | L2 phase6 🟢 | REVIEW 未披露 DRY_RUN 副作用收敛（旧代码 DRY_RUN 创建目录→新代码不创建）| 行为更正确，无测试依赖。可选 REVIEW 补注 |
