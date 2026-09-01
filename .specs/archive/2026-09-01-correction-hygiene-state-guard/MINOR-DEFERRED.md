# MINOR-DEFERRED · correction-hygiene-state-guard

> 🟢 Minor 登记（不入 fix loop）。状态：deferred / resolved(直接修) / triaged。

| # | 阶段 | 来源 | 内容 | 处置 |
|---|---|---|---|---|
| M1 | gate 0→1 | 盲审 M-1 | `_fai_append_violation` 行号 L249-263 不精确（函数体实为 L249-288，追加在 L276） | **resolved(直接修)**：Why 已改 L249-288 并注明追加语句位置 |
| M2 | gate 0→1 | 盲审 M-2 | 「12 天」与实测跨度不符（2026-08-14→08-31 = 17 天） | **resolved(直接修)**：Why 已统一为 17 天口径 |
| M3 | gate 0→1 | 盲审 M-3 | chisel-skill 文档 SKILL.md:142 声明 .flow-active 为 JSON，与运行时实测 YAML 矛盾——写入源未定 | **deferred → 2-design 必查项**：核实 YAML 实际写入者（auto-checkpoint.sh / chisel-skill 运行时 / 外部流程）；「外来让位」策略在写入源切回 JSON 时天然安全 |
| M4 | gate 0→1 | 盲审 M-4 | correction-file.sh「如需共享去重 helper」条件性表述不可判定 | **resolved(定案)**：影响面已改为确定项——新增共享去重 helper 函数，不改既有 4 函数签名 |
| M5 | phase 1 | 盲审 R4 | AC-9 Given 第 50 条 violation 类型悬空（43+6+1 的「+1」） | **resolved(直接修)**：AC-9 已补「1 条 l2-missing」+ Then 终态（l2-missing 保留 + 恰 1 条 foreign-state note） |
| M6 | phase 1 | 盲审 R5 | 「ADR-013 compliance-priority」引述不精确（ADR-013 实为文件级 type 覆盖，无数组级保留条款） | **resolved(直接修)**：AC-10/CHANGE.md 风险段改为「沿 ADR-013 的 compliance 优先精神」+ 注明数组级保留为新决策（2-design 独立论证） |
| M7 | phase 1 | 盲审 R6 | 性能 NFR「<50ms（不设硬门槛）」自相矛盾 | **resolved(直接修)**：去数值，改纯软目标「延续既有性能基线，零新网络/子进程开销」 |
| M8 | phase 1 | 盲审复核 R8 | AC-6「恰好新增 1 条 foreign-state note」在 外来→JSON→外来 再接管边角与 AC-5 去重冲突（再接管时 note 已存在，去重后不新增——「恰好新增」字面不成立） | **triaged(措辞澄清)**：AC-9 已写「首轮收敛」限定首次接管；再接管场景由 AC-5 去重保证 note 不重复（同 check 只写一次），「零新增」语义覆盖。2-design 按 AC-9 首轮 + AC-5 去重实现即可 |
| M9 | phase 2 | 盲审 R5 | 工作区无关杂改（README.md 含 test change 标记 + staged dsh-scm-test-untracked.txt），非本 change 产物 | **triaged(提醒)**：不在本 change 范围内动；7-integration 归档前提醒用户处置（保留或单独提交），避免混入本 change 的 commit |

## M10 · 29 号 M0 内联 strip 切换共享 strip_type（Phase 4 L2 R1 🟢）
- 现状：29:97-99 内联 jq 剥 l2-missing 段；correction_file_strip_type 已有退化守卫（全剥空 → rc0 不变），内联版会把 "l2-missing+l2-missing" 剥成空 type
- 未修原因：29 号 source correction-file.sh 在 L122（M0 之后），切换需前置 source，属行为面变更；无生产者生成重复段标签
- 触发条件：下次触碰 29 号 independent-review 生命周期的 change（triaged: Scheduled）

## M11 · T03-SUMMARY:24 措辞更正（Phase 4 L2 R2 🟢）
- "按指令只在本文件注释中引用" → 实为运行时时序约束（source 在 M0 后）下的偏离，已在 INDEPENDENT-REVIEW-4.md 响应段更正（triaged: 文档更正已就地完成，SUMMARY 措辞留档不改）
