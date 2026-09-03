# Minor Findings Deferred to Phase 7 Triage

> 来自 user-guide-sync-2026-09 各阶段 L2/L3 审查的 Minor 项。按 ADR-017 单一路径登记，phase 7 由用户 triage。

| # | 阶段 | Finding ID | Description | Deferred reason | Date |
|---|------|------------|-------------|-----------------|------|
| M1 | 1 | R4 | AC-2「如原存在」条件化与「不宣称独占」缺独立断言 | 已在 R3 同文件修复中顺带吸收（禁词表加 `仅为/只为 Claude Code`），此处备查 | 2026-09-03 |
| M2 | 1 | R5 | AC-1 Given 未命名具体文件；AC-6「无异常页」含人工判据 | Minor · 机器判定成本高于收益：AC-1 验证命令已含文件名、AC-6 人工抽查标注为辅助手段即可 | 2026-09-03 |
| M3 | 1 | R6（重审）| AC-3e「上述两个模块」指代悬空 | 已吸收：AC-3e 点名 33=flow_active_integrity / 34=archive_commit_check | 2026-09-03 |
| M4 | 1 | R7（重审）| AC-3e 验证只锚集合差集、子句无断言落点 | 已吸收：AC-3 验证方式补子句 grep 清单并与 T01/T03 对账 | 2026-09-03 |
| M5 | 1 | R8（重审）| AC-1 来源行断言未限定文件头 5 行 | 已吸收：验证改为 head -5 域内 grep | 2026-09-03 |
| M6 | 1 | R9（重审）| CHANGE 引述串与实文/页数口径漂移 | 已吸收：引号改实文 + 19→20 页时态标注 | 2026-09-03 |
| M7 | 2 | F3 | deck-gen 清单与实物出入（未跟踪/缺 slides.json、deck_checks.py） | 已吸收：0.5.1 措辞改「DEV 创建后 tracked」并显式列出待建文件 | 2026-09-03 |
| M8 | 2 | F4 | CONTEXT 残留「三级链」与五级锁决策矛盾 | 已吸收：CONTEXT 3 处词条改五级链口径（已锁决策 2026-09-03 同源） | 2026-09-03 |

| M9 | 3 | R7 | DESIGN/TASK 对 deck-gen 文件状态描述矛盾 | 已吸收：T06 action 注明「骨架已先行建好，本任务收尾核验+入库」 | 2026-09-03 |
| M10 | 3 | R10 | AC-5「无空 slide」无机器断言 | 已吸收：T08 deck_checks.py 增加逐 slide 文本非空断言 | 2026-09-03 |
| M11 | 3 | R11 | TASK 未注明 AC-8 承接位 | 已吸收：波次说明加 AC-8 承接注记 | 2026-09-03 |
| M12 | 3 | R9 | T01 verify 未覆盖来源行 URL | 已吸收：T01 verify 追加 develop URL grep | 2026-09-03 |

| M13 | 3 | F2（重审）| 「T07 与 T04 并行（不同文件）」措辞歧义（两者都触及指南读取） | 已吸收：波次说明补「写入对象不同；T07 只依赖 T03，T04 清理由 T08 终校兜底」 | 2026-09-03 |

| M14 | 1 | L3-m1 | AC-3 grep 未指定路径/正则边界 | 已吸收：AC-2 定义统一检索范围，AC-3 验证方式注明两份 MD+slides.json、固定串语义 | 2026-09-03 |
| M15 | 1 | L3-m2 | AC-4 未说明两副本更新顺序 | 已吸收：AC-4 验证方式补「先根后 bundle、cmp 失败即未同步」 | 2026-09-03 |
| M16 | 1 | L3-m3 | AC-9 未列归档完整文件清单 | 已吸收：AC-9 列出 CHANGE..INTEGRATION + INDEPENDENT-REVIEW-{1,2,3,5,6,7} + MINOR-DEFERRED | 2026-09-03 |
| M17 | 1 | L3-m4 | NFR 性能秒数/依赖版本无校验步骤 | 待 phase 7 triage：TEST 阶段改为记录实测耗时（固定 runner），版本校验并入 build.py 自检（已有） | 2026-09-03 |
| M18 | 1 | L3-m5 | AC-3f 引用 CONTEXT 决策但无验证方式 | 已吸收：AC-3f 补「决策条目存在可 grep」 | 2026-09-03 |

| M19 | 5 | L3-5 建议 | PDF/PNG 仅存 /tmp 无持久化 artifact 路径；AC-7 原始 make test 日志未落工件 | 待 phase 7 triage：建议把 pg1/14/20 PNG 或 PDF 复制进归档目录或增加像素断言；最终 make test 快照落 INTEGRATION.md | 2026-09-03 |

