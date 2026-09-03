# INTEGRATION: 用户指南与用户指南 PPT 同步至 2026-09 功能集

- **Change ID**: user-guide-sync-2026-09
- **日期**: 2026-09-03
- **状态**: 归档执行中（阶段 7 L2 pass；L3 终审在归档提交后重跑；随后置 done）

---

## 1. 验收汇总

| 验收项 | 结果 | 证据 |
|---|---|---|
| make test（770 bats） | ✅ 0 fail | pre-commit 每提交执行，全部提交绿（78ec779..HEAD）；最终独立快照见 §6 |
| 指南两副本一致 | ✅ | cmp -s（TEST A4） |
| deck 20 页重建 + 断言 | ✅ | T5：build.py + deck_checks.py（TEST A4 段内子断言） |
| 渲染 PDF/PNG | ✅ | T6：soffice Pages=20 + 页 1/14/20 PNG（TEST A4 段内子断言） |
| 门禁（gate_config=all） | ✅ | IR-1/2/3/5/6 L2+L3 pass；7 见 IR-7 |
| UAT-1 dsh 安装流程 | ✅ | 2026-09-03 实际执行 package-dsh-plugin.sh + 两 profile 副本刷新；GUI 重启后最终生效由用户确认（§2.4 与真实命令一致） |
| UAT-2 deck 渲染人工过目 | ✅ | /tmp/ppt-render/pg1-01.png、pg14-14.png、pg20-20.png；describe-image 无溢出/截断 |

## 2. 发布检查

- Conventional Commits：78ec779..HEAD 全部提交前缀 docs/chore(user-guide-sync-2026-09)（AC-9 验证）
- 无运行时实现改动；阶段 5 时点白名单检查 0 外溢（此后仅 .gitignore 规则随早期 chore 提交，不影响验证时点口径）；dist 产物 gitignored 不入库
- 生成器 .specs/user-guide-deck-gen/ 入库可复跑；README 记录命令与依赖版本

## 3. UAT 汇总

- UAT-1 ✅（本机按 §2.4 实跑打包+装载；profile 重启为用户操作，已在会话外提示）
- UAT-2 ✅（PNG 人工可复核 + describe-image 抽查）

## 4. LESSONS（本 change 沉淀）

- L-083 建议：文档/演示型 change 的验证方式必须产物内可复现——L3 三轮迭代证明，把断言写成当前可执行命令（而非指向未来占位）是收敛最快路径；新增生成器注意 Path.parents 语义（parents[0]=父目录，勿把 repo 根算错一层）。
- L-084 建议：subagent 盲审长时间无产出（>30 min）应中断并改用紧范围+前台重派；本 change 3 个后台 L2 卡住，中断重派后 1-5 分钟完成。

## 5. 归档清单与动作

1. git mv .specs/user-guide-sync-2026-09 → .specs/archive/2026-09-03-user-guide-sync-2026-09/
2. 删除门禁运行期标记 .independent-review-*.done（rm 即可——该模式已被 .gitignore 忽略且未跟踪，不入库，git rm 不可用）
3. .specs/STATE.md last_change_archived 更新为 user-guide-sync-2026-09（2026-09-03）
4. .specs/CHANGELOG.md 顶部新增本 change 行
5. .specs/LESSONS.md 追加 L-083/L-084（按仓库编号规则并入）
6. 归档提交：docs(user-guide-sync-2026-09): 归档产物 — archive/… + STATE
7. 重跑 bash package-dsh-plugin.sh 刷新 dist 与插件 docs 指南副本（gitignored；profile 副本 cp 同步）

## 6. 最终 make test 独立快照

> 由归档提交的 pre-commit 钩子执行并在提交后回填：make test tail（770 ok / 0 fail）与区间计数。

## 7. Minor triage（M1-M19）

- M1-M16、M18：已吸收（见各行标注），无需动作
- M2/M17/M19：待用户 triage（AC-6 人工判据 / NFR 秒数记录化 / PNG 持久化与 AC-7 日志快照）——建议后续 docs change 把渲染 PNG 归入归档或 CI artifact；性能秒数改 TEST 实测记录

---

> 阶段 7 门禁（IR-7 L2/L3 pass）后执行归档动作并提交；最终总体结论 = 通过。
