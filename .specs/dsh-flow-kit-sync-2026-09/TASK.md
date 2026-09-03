# TASK — dsh-flow-kit-sync-2026-09（回顾拆解）

| Task | 内容 | Verify |
|---|---|---|
| T1 | 盘点 flow-kit 增量（9a81098/47c68ef/76261dc/2999024）与 dist 差距 | git log + diff -rq dist |
| T2 | lib/flow-state.js doctor + model 五级链 + 版本 0.2.0 | node --test 20/20 |
| T3 | 单测断言（doctor/五级链/回显新值 R1） | 断言在 flow-state.test.mjs |
| T4 | 文档 DESIGN §8 / README / VERIFY round 5 | grep 抽查 |
| T5 | package-dsh-plugin.sh 重打包 + vendor diff | 脚本 exit 0 + diff 空 |
| T6 | 两 profile pnpm install 重装 + dump-config 挂载 | inode=dist、inject 三件套 |
| T7 | L2 盲审子代理 + L3 外部模型（凭证配置后） | INDEPENDENT-REVIEW-7.md |
| T8 | 归档产物补齐（REQUIREMENT/DESIGN/TASK/TEST/REVIEW/INTEGRATION） | L3 重审 pass |

完成顺序即上表；全部完成（done @ phase 7）。
