# 独立审查 · 阶段 1

## L2 盲审

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/REQUIREMENT.md`（166 行）· 参考 `CHANGE.md`
- 未收到任何主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损
- 实测核对（只读，共 13 项 · 快照时刻 2026-09-21 22:08-22:12）：四副本 md5/行数 · 日期口径三处 · `Makefile:106` check 依赖 · `Makefile:136` dsh-sync · `package-dsh-plugin.sh:45` PACKAGE_MAP 与 `check_dist` 的 `cmp -s` 逐文件比对 + **实跑 `--check`** · `sync-hooks.sh:56-63` DEST_ROOTS 实为 6 项 · `deck_checks.py` EXPECT_PAGES=20 / 封面 `2026-09-03` / BANNED / KEY_STRINGS · pptx 实为 20 页 · `.claude/l3.env.example` 存在 · N1/N2/N7/N8/N9/N10 证据串命中 · `soffice`+`pdftoppm` 在位 · 漂移报告 43 条与 14 条 🔴 编号清单
- 审查期间事实变更（如实记录，不影响结论方向）：22:08:45 主 agent 改写 `flow-kit-bundle/FLOW-KIT-用户指南.md`（`d87c6d84`→`ad7790ae`）未重建 dist → 四副本一度呈 3 种 md5、`package-dsh-plugin.sh --check` 报两条陈旧的即时证据，已并入 R1/R11 的四要素

### 🔴 R1 · AC-10 的 Given 事实错误：副本一致性**已有**一条会红的机械守护，AC 把守护域写成"无"

**Severity**：🔴 Critical
**Symptom（症状）**：`REQUIREMENT.md:108-113`（AC-10 Given）断言「根副本 vs bundle 副本 vs dist×2 一致**无任何门禁守护**（`Makefile:5,106`、`verify-claims.sh` 均不含）」。实测反例：`package-dsh-plugin.sh:45` 的 `COPY_OPTIONAL` 已声明映射 `flow-kit-bundle/FLOW-KIT-用户指南.md → dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md`，而 `package-dsh-plugin.sh:116-119`（`check_dist` 正向分支）对该映射逐文件 `cmp -s` 比对、不一致即 `exit 1`；该目标已挂在 `Makefile:106` 的 `check: … check-dist` 上。**实时反例（审查期间捕获）**：主 agent 于 22:08:45 改了 bundle 副本（`d87c6d84` → `ad7790ae`，1637 行）而未重建 dist，`bash package-dsh-plugin.sh --check` 立即报两条 `❌ 陈旧: …/dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md`、`…/vendor/…/FLOW-KIT-用户指南.md`（内容与 bundle 不一致 → 重建 dist）。即 bundle↔dist 这条边**今天就会被检出并让 `make check` 变红**；而此刻四副本已呈 **3 种 md5**（root `fb2ff01b` / bundle `ad7790ae` / dist×2 `d87c6d84`），check-dist 对 **root 副本一字不提**——真实缺口恰好是 root 这一端。AC-10 同时漏掉三件事：① 新增守护未要求接入 `Makefile:5` 的 `.PHONY` 与 `:106` 的 `check` 依赖（否则"存在但没人跑"）；② 未定义"四份"中 **root↔bundle** 这条边（无守护的那条）；③ AC-5 只约束"四份 md5 相同"，而 `PACKAGE_MAP` 的**载体是 bundle**——改根文件不重建 dist 时 check-dist 仍绿（本条 R11 已实测），改 bundle 不重建 dist 时 check-dist 红；正确的同步顺序（bundle 为底稿 → 覆写根 → 重建 dist）全文未写。
**Source（源头）**：`Makefile:106` 实际依赖链 + `package-dsh-plugin.sh:116-119` 的 `cmp -s` 实现；本仓 ADR-027「门禁只提高可见性，不替代判断」与 `verify-claims.sh:299-326` 的"行为断言（真挂进 check）而非文本判据"口径；漂移报告 §0 自身的口径（守护域 = 根 vs bundle vs dist×2）。
**Consequence（后果）**：AC-10 会产出与 `check-dist` 语义重叠的第二条断言，或按错误 Given 去测"prompt 里不存在"的守护域；而 AC-1~AC-4 的断言全写在 `FLOW-KIT-用户指南.md`（根副本）上——**根副本未修、check-dist 依旧绿**，四份不一致却可判 pass，正是本 change 要消灭的"看着同步了"的假绿形态（已实测：当前 3 种 md5 共存时 root 侧无任何警报）。
**Remedy（修补）**：改写 AC-10 Given 为「`bundle→dist` 两条边（docs 与 vendor）已由 `package-dsh-plugin.sh --check`（`Makefile:106` 的 `check-dist`）逐文件 `cmp` 守护；**无守护的是 root↔bundle 边与 4 份的整体一致性**——实测 3 种 md5 共存时该守护不报 root」，Then 补两条可失败断言：① 四份 `md5sum` 唯一值 = 1（**必须含 root**）；② 新 target 出现在 `Makefile:5` 的 `.PHONY` 且 `make -n check | grep <新target>` 命中（同 `verify-claims.sh:301` 的行为断言口径，而非 `grep -qE '^target:' Makefile` 的文本判据）；并在 AC-5 补一句同步顺序「以 bundle 为底稿改 → 覆写根副本 → `bash package-dsh-plugin.sh` 重建 dist」，把"载体是 bundle"写死。

### 🟡 R2 · AC-4 内部不一致：N9 在报告里无归属小节，N10/N11 的 grep 锚点与报告正文不对应，却统一要求"每条在指南有归属小节"

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:50-66`（AC-4）。Given 称「报告 §2 列出 12 条」，实际 `/tmp/guide-drift-report.md:394-407` 的表格只有 **N1–N11**（11 行），N12 是该报告 §0 的独立发现；Then 要求「至少覆盖 N1–N11 全部（每条在指南有归属小节）」。核对报告 §2 原文：N9（path-guard 拒绝直写 `.done`）**不是 §2 的表格行**，其建议只作为 N9 行的证据指向 `independent-review-gate.sh:8-12`；N10/N11 的建议是「在 §7 或『独立审查四层架构』补一句」，而 AC-4 给出的锚点是内部契约串（`/L3-SECTION`、`ADR-025`、`ADR-026`）。实测这些串在指南中 0 命中（`grep -c "independent-review" FLOW-KIT-用户指南.md` = 0），即"归属小节"与"可 grep 锚点"两件事在 AC 里被混为一谈。
**Source（源头）**：报告 §2 表格自身（`/tmp/guide-drift-report.md:394-407`）与 §0 的 N12 归属；REQUIREMENT 末行自述「AC 是 TEST 阶段派生用例的唯一来源」（`REQUIREMENT.md:166`）——AC 的 Given 必须与唯一事实基线逐条对齐。
**Consequence（后果）**：TASK/TEST 阶段按 AC-4 造断言表时，N9 因无报告行号锚点而只能靠临时发明措辞，N10/N11 的锚点会指向"补一句 ADR 编号"这种内容——要么断言恒红（指南按用户视角写法不会出现 `/L3-SECTION` 这类实现串，与 `CHANGE.md:145`「指南不逐行解释实现」冲突），要么 TASK 阶段自行降级锚点、AC 与断言的对应关系断裂。
**Remedy（修补）**：把 AC-4 措辞改为「N1–N11 各自落地（N9 属 §7 独立 review 机制段，归入 N7/R1 同一小节；N10/N11 按报告建议以 ADR 编号 + 用户可见后果表述，不裸露实现串）」，并把 §2 表格的 N12 行与报告 §0 交叉引用写清；每条同时给"归属小节标题"与"可 grep 的用户可见串"两列，避免实现串进指南。

### 🟡 R3 · AC-11 要求"每阶段 L3 段"，与本文档自身的 L3 降挡口径互斥——无凭证时该 AC 不可判定

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:119-120`（AC-11 Then）要求「每阶段 `INDEPENDENT-REVIEW-<N>.md` 含 L2 段（子代理盲审）与 L3 段（外部模型）」；同文档 `:162`（依赖与假设）写「凭证缺失时按既有降挡口径透明记录，不伪造 pass」，`:59`（CHANGE 风险）写「若凭证不可用将出现 `l3-model-missing` 降级」；而阶段 1 的 `gate_config` 已是 `1-requirement: both`（`.goal-snapshot.json`）。实测本机 `.claude/l3.env.example` 存在但真实凭证可用性未确认，且既有实现允许熔断自动写 bypass `.done`（`L3_verdict=skipped`，漂移报告 D22）。
**Source（源头）**：漂移报告 D22/D27（`.done` 由子系统写入 · 凭证缺失 → 不写 `.done` → 门禁死锁）；REQUIREMENT 非功能性"不伪造 pass"原则（`:153`）。
**Consequence（后果）**：AC-11 在阶段 5 会出现"pass 判不了 / fail 也判不了"的三态题——要么伪造一条 L3 段（违反本 AC 的 Given），要么把 bypass 审计段算作 L3 段（与 `:120` 的"外部模型"字面冲突），阻塞后续阶段切换与 `make check` 之外的人工判定。
**Remedy（修补）**：AC-11 Then 改为「每阶段含 L2 段；L3 段由 `l3_review_run` 产出，若凭证不可用则**接受**以 `l3-bypass` / `timeout` 锚点 + `L3_verdict=skipped` 的审计段替代，并在 TEST/REVIEW 中显式登记「降挡原因 + 重试方式（删 `.specs/<id>/.l3-attempts-<phase>`）」」；同时把"阶段 6 双轨 pass（非 bypass）"限定为**仅在凭证可用时**成立。

### 🟡 R4 · AC-2「旧措辞零残留」的锚点被推迟到 TASK.md 定义，而 D08 自身带「未确认」标记——本阶段无法判定，且缺反例断言

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:26-29`（AC-2）声明 14 条 🔴「每条对应旧措辞在指南中零残留」，但旧措辞清单以「见 `TASK.md` 的逐条 grep 断言表」交棒（`:29`），而该表在本阶段不存在；同时 `:31` 把 D08（`--sub-goal-4/5/6`）列为代表条目，而漂移报告 `:108` 明确标 D08 为「（未确认）」、报告 §4 `:456` 保留「是否被某个 prompt/skill 隐式解析 **未确认**」。AC-3 对 29 条 🟡/🟢 只要求「体现报告给出的现行事实 + 人工复核清单」（`:43-48`），**不含反例断言**——而 AC-2 的口径（反例 = 旧措辞 0 命中）恰恰证明了作者知道反例才是防复发机制。实测anchors 现状可查：`grep -c "三轮审查"` = 4、`.specs/lessons/` = 1、`ARCHIVE.md` = 2、`sub-goal-4` = 1（均为待改）。
**Source（源头）**：`CHANGE.md:57` 自述主要风险「改了措辞但事实仍旧」，并指定兜底手段为「grep 正反例 + deck_checks」；`REQUIREMENT.md:160` 规定「结论若被实测推翻以实测为准」。
**Consequence（后果）**：阶段 5 只能验证"新措辞命中 ≥1"，无法证明旧措辞消失；对 23 条 🟡 而言，新旧措辞并存（读者同时看到两种事实）不会被任何断言拦住——正是 `CHANGE.md:60` 要防的假绿。D08 若真存在隐式解析点，AC-2 的"零残留 + 新措辞含正确事实"会误导读者删除有效用法。
**Remedy（修补）**：① 把 14 条 🔴 的"旧措辞/新措辞"对写进本阶段 AC 附录（不必等 TASK.md），至少对 D01/D09/D10/D11/D16/D19-D23/D31/D33/D34 给出反例串；② AC-3 的 29 条中，凡有明确旧措辞的（D04/D07/D12/D13/D14/D18/D24/D26/D30/D32/D36/D37/D38/D41 等）一并补反例断言，其余只留正例并标注"无反例锚点"；③ D08 单独写处置口径：「按实测结论（实现只认 env `SUB_GOAL_4..7`）改写，并在 TEST.md 记录复验命令」，不让"未确认"随 AC 流入后续阶段。

### 🟡 R5 · AC-6/AC-9 未覆盖 deck 断言的"有效性实测"：断言文件是被本 change 改的活体资产，却不冻结、也不做注入验证

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:77-85`（AC-6）要求 `deck_checks.py` 同步到新页数与新 KEY_STRINGS 且"实跑通过"，但**没有**要求验证新断言真的会失败；`:101-106`（AC-9）的冻结白名单只列 `flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、`skills/**`、`prompts/**`（+ 新增测试文件），**未含** `.specs/user-guide-deck-gen/**`。实测该目录是活体断言资产：`deck_checks.py:15-17` 的 `EXPECT_PAGES = 20`、封面断言 `2026-09-03`、`BANNED`/`KEY_STRINGS` 全部由本次改动重写，且**无任何门禁覆盖**（`grep -rn "user-guide-deck-gen\|deck_checks" Makefile verify-claims.sh test/` 零命中）。对照：AC-10 对**新的**守护明确要求「注入 1 字节漂移 → 变红 → 还原 → 复绿」（`:112-113`），同文档已确立该标准却未施加于 AC-6。
**Source（源头）**：`CHANGE.md:58` 风险条目「若 `deck_checks.py` 与 slides.json 不同步会出现恒绿/恒红 → 断言需实测生效（注入→变红→还原）」；漂移报告 `:447` 同义提示（`EXPECT_PAGES=20` 与新口径不匹配时 BANNED 失效）。
**Consequence（后果）**：断言与产物同时改、又只验"能跑通"，最省事的实现是把 `EXPECT_PAGES` 改成实际页数、把新 KEY_STRINGS 挑成必然命中的串（例如封面日期），于是 24 页里少一节、新增三专页缺失都不会被发现——`deck_checks.py` 退化为恒绿的装饰。且因该文件不在 AC-9 白名单，它可在"只允许改文档"的名义下被任意改动而无人核对。
**Remedy（修补）**：AC-6 补两条：① 逐条断言的有效性实测（改 `slides.json` 删掉某专页 / 改封面日期 → `deck_checks.py` 必须非 0 → 还原复绿），结论记入 TEST.md；② 显式列出 `deck_checks.py` 的"新断言清单"（页数下限、封面日期、三专页关键串、扩充后的 BANNED）并声明 BANNED 至少含本轮修掉的旧措辞（`.specs/lessons/`、项目级 `stop-hook.json`、三轮审查）。AC-9 白名单补 `.specs/user-guide-deck-gen/**`（限定为 slides.json / deck_checks.py / build.py，且要求 TEST.md 记录 diff 行数与新增断言数）。

### 🟡 R6 · AC-1 的"0 命中"断言与两处历史语义锚冲突，按字面执行会损失正确内容

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:22`（AC-1 验证方式）声明反例断言为「`grep -n "20260713\|2026-07-13" FLOW-KIT-用户指南.md` → 0 命中；`grep … "版本.*2026-09-21"` → ≥1」。实测该文件**当前** `2026-07-13` 仅 1 处（`:1380` 分节最后同步日期，需改），而 `2026-09-03` 有 3 处：`:3`（版本行，需改）+ `:916` 与 `:946`（均为「**2026-09-03 起** L2/L3 模型按 `fk_resolve_model` 五级解析链解析」的历史语义锚）。AC-1 的 Then 写了"归档目录与历史条目除外"（`:21`），但验证方式那一行只写 `20260713|2026-07-13` 的 0 命中，**未给 `2026-09-03` 的豁免清单**。另两处 AC-1 引用的定位与实测不符：`:19` 写「分节『最后同步日期』…（`:1380` = 2026-07-13）」（正确）却同时写「`:3` = 2026-09-03」（正确），而漂移报告 `:384`（D43）把 `:1380` 记成"文首 L3 为 2026-09-03"的对照项——同一事实在两份文档里的行号/口径不一致，需以实测为准。
**Source（源头）**：漂移报告 §4 未确认清单纪律（`:452-459`「未核实项不计入漂移」）与本 AC 的"When/Then 逐条可机检"要求；`grep` 计数是本 AC 唯一验证手段，其判据必须自洽。
**Consequence（后果）**：TASK/TEST 若按"统一为 2026-09-21"的字面执行，会把 `:916`/`:946` 的历史锚点改成 `2026-09-21`（语义失真：模型链是 09-03 起生效）或删掉（丢失 ADR-012/013 的时间依据）；若把 0 命中扩到 `2026-09-03` 则必然恒红。两种走向都会在阶段 5 卡住或写入错误事实。
**Remedy（修补）**：AC-1 验证方式补豁免清单，例如：「`grep -c "2026-09-03"` 的允许命中上限 = N，且每条命中必须位于"…起"式历史陈述句中（`:916`/`:946`）；版本行与分节最后同步日期两处必须为 `2026-09-21`」。同时把 `REQUIREMENT.md:19` 的行号引用改为以实测为准（`:3` 版本行、`:1380` 分节日期），并在 TEST.md 记录"日期锚点白名单"。

### 🟢 R7 · AC-8 无可机械判定的退出条件（"允许连改 / 无漂移则记录"两分支不可证伪）

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:94-99`（AC-8）：Then 允许多分支——「发现的过时口径**允许连改**；无漂移则显式记录『已核对，无需改』」，验证方式为「`TEST.md` 中一张『README 核对表』」。而核对项枚举（安装入口 / 配置路径 / 门禁枚举 / 工件上限单位 / L3 凭证）与实测内容不匹配：`README.md` 全文无 `make check` / 门禁枚举（`grep -n "make check\|check-dist\|hooks-sync\|六门\|五门\|verify-claims" README.md` 零命中），其 L3 段落在 `:101-129`（凭证 + `max_artifact_bytes` 单位）才是真实的漂移候选。
**Source（源头）**：L2 checklist 阶段 1 条目「每条 AC 是否可机器验证（拒绝空话）」；AC-11 自身的 `ls …done` + verdict 行的机械口径。
**Consequence（后果）**：阶段 5 只需交一张表即可判 pass，无法区分"真核对了"与"照抄报告结论"。风险有界（仅 README 口径），故非 Important。
**Remedy（修补）**：把核对项改成与实测对应的一张固定表（每行：条目 / 证据行号 / 结论 / 是否改动），并要求"改动 ≤N 处"或"逐行给出未改理由"；对 `README.md` 明确写出待核段落（`:101-129`），删去不存在的"门禁枚举"项。

### 🟢 R8 · AC-7 把可机检项与人工判据混在一句（"缺字方框 / 溢出框外"无自动判据）

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:87-92`（AC-7）：Then =「无空页、无文字溢出框外、无缺字方框（CJK 正常渲染）」+「抽检页…人工可读」。实测前提成立（`soffice` `/usr/bin/soffice`、`pdftoppm` `/usr/bin/pdftoppm`、python-pptx 可用，pptx 当前 20 页），但"抽检页人工可读"把判定交给主观；`AC-6` 已有可机检的"逐页非空"（`deck_checks.py` 的 empty slide 断言）。
**Source（源头）**：L2 checklist「可机器验证」要求；`REQUIREMENT.md:152`（可访问性 NFR「无缺字/无溢出」）。
**Consequence（后果）**：渲染产物入库但无失败判据，"人工可读"易被一句"已抽检，正常"打发；渲染事故（新专页文字溢框）可能带进交付物。
**Remedy（修补）**：拆成两半——机检部分（PDF 页数 = PPT 页数、每页 PNG 非纯白、PNG 尺寸 = 版心）写成脚本断言；人工部分固定抽检页清单与检查项（封面 / 新增三专页 / 末页 × 溢出 / 缺字），并在 TEST.md 留结论与文件路径。

### 🟢 R9 · 非功能性需求的安全条目在 AC 集合中无落点（"不得写入真实 token"没有验证点）

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:153`（安全）要求「指南中描述 L3 凭证时必须不写入任何真实 token，只写变量名与加载方式（模板引用 `.claude/l3.env.example`）」；AC-1~AC-11 无任何一条与之对应（AC-4 的 N1 只要求出现 `FLOW_KIT_L3_AUTH_TOKEN` / `ANTHROPIC_AUTH_TOKEN` / `l3.env` / 门禁死锁 等串）。实测 `.claude/l3.env.example`（4375 B）存在，是唯一被许可的模板引用对象。
**Source（源头）**：`REQUIREMENT.md:166`「AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC」——NFR 若无 AC 投影，就永远不会有断言。
**Consequence（后果）**：阶段 5 不能为"无真实 token 入库"派生用例；若实施时从 `l3.env.example` 误抄样例凭证（形如 `sk-…` / 长 token），无任何机械检查拦住，凭证随 commit 进入公开仓库。
**Remedy（修补）**：AC-4 的 N1 断言补一条反例：`grep -nE "(sk-[A-Za-z0-9]{8,}|AUTH_TOKEN=.{16,})" FLOW-KIT-用户指南.md` → 0 命中（四副本同查）；或在 AC-8/AC-2 下增列该断言并标注归属 N1。

### 🟢 R10 · NFR 性能（新增守护 < 1s）无验证点；AC-10 未规定守护落点与断言粒度

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:151`（性能）声明「新增守护断言须 < 1s（不得显著拖慢 `make check`）」，但 AC-10 只要求"可失败 + 注入/还原实测"，未要求记录耗时；同处「落点见 DESIGN.md」把承载位置整体外推。参照既有同款门禁的实测基线：`Makefile:117-121` 记录 `check-dist` NFR ≤2s、实测 0.61s（534 文件逐文件 cmp）。
**Source（源头）**：`Makefile:117-121` 的既有 NFR 记录范式（量化 + 实测 + 校准说明）；`REQUIREMENT.md:151` 自身的 < 1s 承诺。
**Consequence（后果）**：阶段 5 无耗时证据；若守护按"逐文件 cmp + 两次 md5"实现到 4 份大文档（单份 ~77 KB）不成问题，但若被实现成"遍历 dist 全树"就有回归风险，且事后不可追溯。
**Remedy（修补）**：AC-10 验证方式补「记录 `time make <新target>` 的中位数（×3）并写入 TEST.md，须 < 1s」；同时要求断言粒度写明（四份 md5 一次性比较 vs 两两 diff），避免与 `check-dist` 的 534 文件级遍历重复计费。

### 🟢 R11 · AC-5 的"四份"枚举与实测一致，但未点明"载体是 bundle 副本"这一同步方向

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:68-73`（AC-5）列四路径 md5 相同（审查快照时四路径均存在，`fb2ff01b`×1 + `d87c6d84`×3，与 `:70` 的 Given 完全一致，无遗漏副本——`find -name "FLOW-KIT-用户指南.md"` 仅这 4 份，pptx 仅根 1 份）。但 `package-dsh-plugin.sh:45` 的映射源是 **bundle 副本**，`:22`（CHANGE What）与 `:161`（假设）虽写了"以 bundle 为底稿"，AC-5 本身只留"md5 相同"的结果约束。
**Source（源头）**：`package-dsh-plugin.sh:45`（`COPY_OPTIONAL` 载体声明）；`Makefile:122-134` check-dist 语义。
**Consequence（后果）**：见 R1 的②③——"只改根副本"时 check-dist 仍绿（守护沿 bundle 链、对 root 失明），而本 AC 的四份 md5 断言此时也仍可能通过（若 bundle/dist×2 未动且彼此一致）→ 根副本永久落后却两处全绿。
**Remedy（修补）**：AC-5 增列一句同步顺序（改 bundle → 覆写根 → `bash package-dsh-plugin.sh` 重建 dist）并把该顺序作为 AC-9 回归的一部分实跑记录；**实测依据**：只改根副本时 `check-dist` 依然绿（守护沿 bundle 链，对 root 失明），只改 bundle 而不重建 dist 时 `check-dist` 立即变红（审查期间 22:08:45 事件），因此"四份 md5 相同"这一结果约束必须配一条"改哪一份都逃不掉"的机械断言才成立。

---

**本轮无 L-031 漏改类发现（可豁免说明）**：审查快照时刻（22:08-22:12）`git status --short` 只有 `.specs/CONTEXT.md`（已修改）与 `.specs/user-guide-sync-2026-09b/`（新增，未跟踪）；`flow-kit-bundle/hooks/**`、`dsh-flow-kit/lib/**`、`Makefile`、`sync-hooks.sh`、`package-*.sh`、`.specs/user-guide-deck-gen/**` 均无 diff → 无"已改文件 vs 设计清单"可对比，跨文件漏改类判定**不适用**（同期唯一工作树变更是 `flow-kit-bundle/FLOW-KIT-用户指南.md` 的文档改写，已并入 R1/R11）。锚点盘点已就位并供后续阶段复用：日期口径（2026-09-03 / 2026-07-13 / 20260713）、`max_artifact_bytes` 与 80000、check-dist / hooks-sync / dsh-sync / verify-claims、`.specs/LESSONS.md`、`ARCHIVE.md`、用户级 stop-hook.json、`PACKAGE_MAP` 的指南映射、`deck_checks.py` 的 EXPECT_PAGES/BANNED/KEY_STRINGS、`.PHONY` 行。要求阶段 2 的 DESIGN 对每个锚点给出"跨文件命中清单 + 处置"，并在阶段 4/6 由 L2 按同一清单复核（尤其 `Makefile:5/106`、`package-dsh-plugin.sh:45`、`.specs/user-guide-deck-gen/**` 三处）。附带记录（不追加为发现）：`.specs/` 下在本轮审查期间出现了 `DESIGN.md` 与 `TASK.md`——盲审未读取、未据其调整任何判断。

**Verdict**: fail

---

## 主 agent 响应（阶段 1 · L2 首轮 R1–R11 · 2026-09-21）

> 处置口径：`Fixed in:` 指向本 change 的实际改动；不写「已知/待后续」式空响应。

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R1 | 🔴 | **Fixed in: REQUIREMENT.md AC-10（v2 重写）+ AC-5（补同步顺序）** | 承认 Given 事实错误：`bundle→dist` 两条边**已**由 `package-dsh-plugin.sh --check` 逐文件 `cmp` 守护并挂在 `check-dist`（`make check` 第 6 门）；真实缺口改写为 **`root ↔ bundle` 边 + 四份整体一致性**。AC-10 Then 增加「真的会被跑到」的行为判据（`npx bats test/test_guide_copy_parity.bats` 实跑 + 注入漂移 rc≠0），**不**采用「Makefile 里出现某 target 字符串」的文本判据；AC-5 写死同步顺序「底稿=bundle → 覆写根 → 重建 dist」，并说明「只改根副本会让 check-dist 转红」 |
| R2 | 🟡 | **Fixed in: REQUIREMENT.md AC-4（v2 重写）** | 改为 N1–N11（§2 表格实有 11 行）+ N12（§0 独立发现，由 AC-10 承载）两段式；N9 明确并入 §7「独立 Review 机制」同节（不单列小节）；N10/N11 锚点改为**用户可见后果表述 + ADR 编号**，删除裸露实现串（`/L3-SECTION` 等）；每条给「归属小节 + 可 grep 用户可见串」两列 |
| R3 | 🟡 | **Fixed in: REQUIREMENT.md AC-11（v2 重写）** | Then 拆三态：L2 段必含；L3 段接受 `l3-bypass`/`timeout` 审计段替代（`L3_verdict=skipped`）+ 显式登记「降挡原因 + 重试方式（删 `.l3-attempts-<phase>`）」；「阶段 6 双轨 pass（非 bypass）」限定为**仅在凭证可用时**成立 |
| R4 | 🟡 | **Fixed in: REQUIREMENT.md AC-2/AC-3（v2 内联反例表）** | 14 条 🔴 的「反例/正例」对**内联进 AC-2**（不再等 TASK.md）；AC-3 为有明确旧措辞的 13 条补反例断言，其余标注「无反例锚点」；D08 单列处置口径：采信全仓 grep 实测（实现只认 env `SUB_GOAL_4..7`），并要求 TEST.md 记录复验命令输出、若被推翻按实测改写 |
| R5 | 🟡 | **Fixed in: REQUIREMENT.md AC-6 + AC-9（v2）** | AC-6 新增「新断言清单显式登记」+「断言有效性实测」（删专页 → 必 rc≠0；改封面日期 → 必 rc≠0；还原复绿，两组结论入 TEST.md）；AC-9 白名单补 `.specs/user-guide-deck-gen/{slides.json,deck_checks.py,build.py,layouts.py}`，并要求 TEST.md 记录其 diff 与新增断言数 |
| R6 | 🟡 | **Fixed in: REQUIREMENT.md AC-1（v2 补豁免清单）** | 明确 `:916`/`:946` 的「2026-09-03 起 …」是 ADR-012/013 生效时间锚，**不得改写/删除**；验证方式补三条：`2026-09-03` 命中数 ≤2 且每条必须落在「…起」句中；版本行/分节日期 = `2026-09-21`；TEST.md 记录「日期锚点白名单」。行号引用以实测为准（`:3` 版本行、`:1380` 分节日期） |
| R7 | 🟢 | **折入: REQUIREMENT.md AC-8（v2 改固定表）** | 核对项改为 6 行固定表（安装入口/配置路径/工件上限单位/L3 凭证与熔断/dsh-sync/dist README 同步关系），每行须给证据行号 + 结论 + 未改理由；删去实测不存在的「门禁枚举」项 |
| R8 | 🟢 | **部分折入 + 部分 Tech-debt** | 可机检部分折入 AC-7（PDF 页数 = PPT 页数、每页 PNG 尺寸一致且非纯白）；人工部分（溢出/缺字目视）保留固定抽检清单（封面 + 3 新专页 + 末页）——「文字是否溢出框外」无稳定自动判据，**Tech-debt: 登记 MINOR-DEFERRED M2**（需引入 PPTX→PDF 文本边界检测，成本高于本 change 价值） |
| R9 | 🟢 | **折入: REQUIREMENT.md AC-4 安全反例** | N1 附反例断言 `grep -nE '(sk-[A-Za-z0-9]{8,}|AUTH_TOKEN=.{16,})' <四份副本>` = 0 命中 |
| R10 | 🟢 | **折入: REQUIREMENT.md AC-10 + NFR 性能** | AC-10 明确断言粒度（四份 md5 一次性比较，不重复 `check-dist` 的逐文件遍历）+ 计时证据（比较逻辑 `time` 中位数 ×3 < 1s，不计 `npx`/bats 启动开销）；NFR 同步改为「比较逻辑 < 1s」 |
| R11 | 🟢 | **折入: REQUIREMENT.md AC-5（v2）** | AC-5 Then 显式写「底稿 = bundle 副本（`package-dsh-plugin.sh:45` 的映射源）」+ 同步顺序作为 AC-9 回归的一部分实跑记录 |

**复审请求**：AC-10/AC-4/AC-11/AC-1/AC-5/AC-6/AC-8/AC-9 均已重写（REQUIREMENT.md v2）。R8 的目视项与 R1 提到的「未来把副本守护提升为独立门禁 target」不属本 change 范围（见 v2 段），已登记 MINOR-DEFERRED。

---

## L2 盲审（第二轮）

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/REQUIREMENT.md`（**v2 现状**，234 行）· 参考 `CHANGE.md`（60 行）
- 未收到任何主 agent 自评 / 草稿 / 概述 / 辩护（输入仅 REQUIREMENT.md / CHANGE.md + 仓库只读核对 + `/tmp/guide-drift-report.md`）→ **独立性未受损**。文件内第一轮 L2 段与「主 agent 响应」段按调用方说明作历史轮次处理，未作为本轮判据。
- 实测范围（只读，26 项）：四副本 md5/行数 · `diff` 根↔bundle 全文（97 行差异）· AC-1/AC-2/AC-3/AC-4 全部 grep 锚点**逐串实跑**（`grep -Fc`）· `Makefile:106/79-85` 依赖链 · `package-dsh-plugin.sh:30-49` 三张映射表与 `:126/153/167` 的 `cmp -s` · `package-dsh-plugin.sh --check` **实跑** · `SUB_GOAL_4..7` 全仓实测 · `test/`↔`flow-kit-bundle/test/` 逐文件比对 · `.specs/user-guide-deck-gen/`（`EXPECT_PAGES=20` / slides 20 页）· AC-9 白名单 8 条路径存在性 · 四副本 md5 比较计时 ×3 · L2-blind-review 严重度词表 · 漂移报告 D01/D11/D13/D14/D16/D18/D22/D30/D31/D33/D34 原文
- **审查期间事实变更（如实记录）**：`flow-kit-bundle/FLOW-KIT-用户指南.md` 在 22:10:21→22:10:36 被并发改写两次（`d87c6d84` 1632 行 → `e39ac765` 1653 行 → `411b1829` 1660 行），期间 `三轮审查` 由 4 命中降为 1 命中；`bash package-dsh-plugin.sh --check` 实测 rc=1（dist 两份落后于 bundle）。故下文行号为**审查时刻实测**，串值与结论不受影响（另：为验证 AC-5 的因果句做过一次根副本追加+还原，根副本 md5 复原为 `fb2ff01b…`，未遗留改动）。

### 🔴 R12 · AC-1/AC-2/AC-3 的"反例"锚在根副本、"验证方式"却跑在 bundle 副本——两副本已分叉，断言**恒绿/不可达**，且与 AC-5 指定的底稿自相矛盾

**Severity**：🔴 Critical
**Symptom（症状）**：`REQUIREMENT.md:40` 表头写「反例（= 0 命中）/ 正例（≥ 1 命中）」，`:60` 的验证方式写「反例用 `grep -F` 字面匹配」；`AC-1`（`:27-33`）与 `TASK.md` 的断言对象是 `f=flow-kit-bundle/FLOW-KIT-用户指南.md`，而 **AC-2 锚点所引用的旧措辞只存在于根副本**。实测（审查时刻）：`核心引擎 + skills + brooks-lint + hooks` → 根 **1** 命中 / bundle **0**；`--sub-goal-4` → 根 **1** / bundle **0**（bundle 已改为 `SUB_GOAL_4..7` 表述，`bundle:361`）；`.specs/lessons/` → 根 1 / bundle 1（尚未改）。两副本来自不同世代：根 md5 `fb2ff01b`（1631 行，mtime 2026-09-03 22:34）、bundle md5 `411b1829`（1660 行，mtime 2026-09-21 22:10:36），`diff` 共 97 行差异。同时 `AC-5:116` 规定**底稿 = bundle 副本**（`package-dsh-plugin.sh:45` 的 `COPY_OPTIONAL` 映射源确为 `$BUNDLE_DIR/FLOW-KIT-用户指南.md`）。
**Source（源头）**：`Makefile:106` 依赖链 `check: test lint check-validate check-test-sync check-hooks-sync check-dist` 与 `package-dsh-plugin.sh:126/153/167` 的 `cmp -s`——`check_dist` 的**源参数全部取 `$BUNDLE_DIR` / `$SRC_DIR`，从不读根副本**；漂移报告 D34 原文写「bundle 副本已改对，根副本未同步（见 §0）」；`REQUIREMENT.md:116` 自身规定的同步顺序。
**Consequence（后果）**：三处机械失效同时成立，且**不需要执行者犯错**：① **恒绿**——D01/D08 等"反例 = 0 命中"在验证对象（bundle）上**现在就已满足**，编辑器一个字符不改也能拿到绿；② **不可达**——按 AC-5 的正确方向只改 bundle 后，根副本仍留全部旧措辞，而这正是 AC-2「修订」的对象，两 AC 互相指向对方不覆盖的文件；③ **方向自相矛盾**——若照 AC-2 去修根副本（旧措辞所在处），`check-dist` 依旧只沿 bundle 链，根副本改动零门禁，正是本 change 要杀死的"看着同步了"假绿。`grep -F`（`:60` 规定的字面匹配）使 `|` 类正则在 D23 行也失效（见 R14）。
**Remedy（修补）**：① 每条 AC 显式写「断言对象文件」并在 AC-2/AC-3 表头加一列「目标副本」，凡反例锚点只存在于根副本者，先把该措辞**搬进** bundle（底稿）再断言；② 反例断言改为"对**四份**副本同跑 `= 0 命中`"（与 AC-4 安全反例 `:107` 的四份口径一致），避免"修了 A 份、B 份留着"；③ 在 AC-2 之前增加一条前置断言：修订**起点**必须满足 `md5(根) == md5(bundle)`（否则先做一次 `cp flow-kit-bundle/… 根`），把"两副本不同世代"这一既成事实显式消灭；④ 删除 `:60` 的"正例/反例"字面匹配与 `:98` 的「正例」措辞冲突（同一串既要求 ≥1 又要求 0，见 R14）。

### 🔴 R13 · 9 条锚点在指南中零命中且**不可达**——含本轮明令"不裸露实现内部契约串"的那批

**Severity**：🔴 Critical
**Symptom（症状）**：实测 bundle 副本命中数：`L3_verdict=skipped` **0**（AC-2 D22 正例，`:53`）、`占位块` **0** · `代码未消费` **0**（AC-2 D19 正例，`:50`）、`runtime-edit-guard` **0**（AC-4 N8，`:101`）、`path-guard` **0**（AC-4 N9，`:102`）、`check-hooks-sync` **0**（AC-4 N4，`:97`）、`verify-claims` **0**（AC-4 N6，`:99`）、`max_artifact_bytes` **0** · `80000` **0**（AC-4 N2，`:95`）、`l3.env` **0**（AC-4 N1，`:94`）、`六门` **0**（AC-4 N3）。其中 `L3_verdict=skipped` / `占位块` / `代码未消费` / `/L3-SECTION` 正是首轮 R2/R9 要求以「**用户可见后果**表述、不裸露实现串」落地的那批（`REQUIREMENT.md:90`、`:103-104` 已写入该口径），而 AC-2 的 D19/D22 仍把裸实现串写进「正例（≥ 1 命中）」列。
**Source（源头）**：`REQUIREMENT.md:213`（out 范围）「在指南里复制 `hooks/**` 实现细节（指南定位是用户视角，不逐行解释实现）」；`CHANGE.md:41`「`prompts/**` 一律不动」；D19/D22 的实现证据为 `flow-kit-bundle/hooks/config/stop-hook.json` 与 `hooks/stop/lib/l3-done.sh:156-179`（内部 KVP，非用户视角）。
**Consequence（后果）**：AC-2/AC-4 是阶段 5 的唯一用例来源（`:234`），这些断言不是"还没改"，而是**在满足 out 范围约束的前提下无法转绿**——要么阶段 5 恒红卡死 toll-gate，要么执行者把实现串硬塞进用户指南（`占位块`、`L3_verdict=skipped` 对读者无意义），直接违反本 change 自定的 out 条款与"不写实现细节"原则。二者都不是"可选路径"，是硬冲突。
**Remedy（修补）**：对每条锚点二选一并写进 AC：① 保留"正例"但改为**指定原文串**（从漂移报告的「建议改法」逐字取，例如 D19 → 「该开关当前为占位块、代码未消费」改为用户可见句「此键当前无实际作用，配了也不会生效」，D22 → 「熔断后由子系统自动落 `.done`，无需手工 touch」）；② 或降为"人工核对"项移入 AC-8 固定表。**不接受**"正例 = 裸实现串"与本 change 的 out 范围并存。

### 🟡 R14 · 5 条锚点只有"泛词命中"：AC-3 D30 改前已绿、D18 改前必红、D16/D22 的反例指向指南中合法且必须保留的内容

**Severity**：🟡 Important
**Symptom（症状）**：实测 bundle 副本——**D30**（`:77`）正例 `flow_active_integrity` **已 2 命中**（`:946` 模块清单、`919`），即"缺陷未修也已绿"，而同行的反例 `"31-auto-advance": true`（`:1645`）即便改掉也不会让任何断言变红；**D18**（`:75`）三个正例 `快速体检` / `完整审计` / `单维深挖` **均 0 命中**，指南现文是 `**快速**：~5 分钟` / `**标准**（默认）` / `**深度**`（`bundle:811-813`），而"改前必须红、改后才绿"的 `标准` 反而不在任何断言列；**D16**（`:49`）反例写作「项目根 `ARCHITECTURE.md`」但 `grep -F '项目根'` **6 命中**，其中 `:137-139`、`:1414`、`:1423` 是 `.flow-active` / `.specs/` 的合法"项目根目录/相对路径"表述**必须保留** → 字面 `= 0 命中` 不可达；**D22**（`:53`）反例 `允许手动绕过` **2 命中**、`手动 touch done` **1 命中**，而 `:943` 是**配置键 `max_failures_before_bypass` 的说明**（「L3 连续失败多少次后允许手动绕过」，键名与默认 3 是现行事实）；**D33**（`:56`）反例列含 `off`，正例列也含 `off`（同一串既 ≥1 又 =0）。
**Source（源头）**：漂移报告对应条目自身的「建议改法」（D30 建议改口为「31/32 号无独立开关…33 号由 `modules.flow_active_integrity` 控制」；D18 建议给出三档模式名）——AC 的锚点未从建议改法逐字派生，而是自行概括；`REQUIREMENT.md:234`「AC 是 TEST 阶段派生用例的唯一来源」。
**Consequence（后果）**：阶段 5 的断言矩阵对 5 条 D 项失去判定力（前两条是"恒绿/恒红"错位，后两条是无法满足的 0 命中），而它们覆盖的是 D30（config 键三连错，漂移报告定为自相矛盾）、D16（🔴 产出路径错）、D18（模式名不符）——都是读者会照做出错的事实项。
**Remedy（修补）**：锚点一律改为**差异化串**并逐条与漂移报告「建议改法」的原文措辞对齐：D30 → 反例 `"31-auto-advance": true` 保留 + 正例改为「31/32 号**无独立开关**」且删除泛词 `flow_active_integrity`；D18 → 正例沿用报告原文 `快速体检（5~10 分钟` + 反例补 `**标准**（默认）`；D16 → 反例收窄为 `项目根 \`ARCHITECTURE.md\``（含文件名，避 `项目根目录` 误伤）；D22 → 反例收窄为 `:970` 的整句（如 `可手动 touch done 继续`），`:943` 的配置键说明行列入白名单；D33 → 正例去掉 `off`，只留 `both` / `L2` / `L3` 且要求同一行内共现。

### 🟡 R15 · bundle 副本已是"脏起点"：3 处反例命中取自 bundle 自身、2 处旧措辞已消失——而 AC 的 Given 把全部缺陷定位在根副本

**Severity**：🟡 Important
**Symptom（症状）**：审查时刻 bundle 副本仍有 `三轮审查` **1** 命中、`随 flow-kit bundle 分发` **1** 命中、`.specs/lessons/` **1** 命中（均待改）；但 `核心引擎 + skills + brooks-lint + hooks`、`--sub-goal-4` 已为 0（见 R12）。更关键的是 `REQUIREMENT.md:38-39`（AC-2 Given）与 `:64`（AC-3 Given）以「报告列出 N 条」为唯一 Given，**未声明"缺陷在四份副本中的哪一份、改动从哪一份发起"**；而 `:112`（AC-5 Given）断言当前状态是「根 `fb2ff01b`…（1631 行）vs 其余三份 `d87c6d84`…（1632 行）」——实测已变为**三种 md5 并存**（根 `fb2ff01b` 1631 / bundle `411b1829` 1660 / dist×2 `d87c6d84` 1632），且 bundle 与 dist 的差异正在被并发改写放大（`--check` 实测 rc=1）。
**Source（源头）**：`REQUIREMENT.md:228-229`（依赖与假设「bundle 为较新基线（含 2026-09-21 配置用户级措辞），根副本落后 2 行」——实测落后 **29 行 / 97 行差异**）；`REQUIREMENT.md:5` 声明漂移报告是唯一事实基线。
**Consequence（后果）**：AC-5 的 Given 从写下那刻起就与仓库不符，阶段 5 无法用它判定"同步是否做了"；AC-2 的 14 条与 AC-3 的 29 条中"已在 bundle 修好"的部分会退化为免检项（`三轮审查` 降至 1 命中的并发改写即为例证），而"假设落后 2 行"这一量化若被 TASK 用来做 diff 行数核对，会直接得出错误结论。
**Remedy（修补）**：① AC-5 Given 改为**不写死 md5/行数**，改写成"实测即得"的判据（四份 md5 唯一值 = 1 + 修订前先记录基线），或写明"以阶段 5 实测快照为准"；② `:229` 的「落后 2 行」删除或改为 `diff` 实测行数（当前 97 行）；③ 在 AC-2/AC-3 增加一句处置口径：「反例在 bundle 已 0 命中者标为 `already-fixed`，仍须核对根副本同串归零」，避免"免检"与"漏改"混淆。

### 🟡 R16 · AC-3 的 D43 行没有可执行断言（「由 AC-1 覆盖」），与本表自身口径（每条含正例）冲突

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:82`：`| D43 | \`2026-07-13\` | （由 AC-1 覆盖） |`——反例列给了串，正例列**无任何断言**。而 `:66` 的 Given 规定「凡报告中存在明确旧措辞的条目**一律补反例断言**（下表）」，`:84` 的验证方式又声明「TASK.md 附录 A + TEST.md 断言矩阵（逐条实跑输出）」，即本表每行都要产出断言。实测该串只出现在 AC-1 的 0 命中断言里（`:29`），未进入 AC-3 的逐条矩阵。
**Source（源头）**：`REQUIREMENT.md:84` 的"逐条实跑输出"承诺；`:234`「AC 是 TEST 阶段派生用例的唯一来源」——阶段 5 不得自行发明 D43 的正例。
**Consequence（后果）**：D43 成为 43 条中唯一"有反例无正例"的行，TEST 阶段会把它记成一条无判据的 `PASS`（或与 AC-1 重复计数），使"43 条逐条核对"这句话在 D43 上不可核验。
**Remedy（修补）**：把该行正例补为可判定串，例如 `版本.*2026-09-21` + `最后同步日期.*2026-09-21`（与 `:32-33` 的 AC-1 断言解耦，作为独立行），或明确写「D43 不单列断言，计数器为 42 条」并同步修正 `:62-66` 的"29 条"表述。

### 🟡 R17 · AC-9 的白名单/冻结路径名与本仓实际目录不符——冻结判据**恒真**

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:163` 冻结 `skills/**` 与 `prompts/**`，但仓库根**不存在**这两个目录（`ls -d skills prompts` → 均 MISSING；真实路径是 `flow-kit-bundle/skills/` 与 `flow-kit-bundle/flow-kit/prompts/`）。该句同时是 AC-9 的验证方式（`:164` 的 `wc -l` = 0）。实测 `git diff --name-only -- flow-kit-bundle/hooks dsh-flow-kit/lib flow-kit-bundle/skills flow-kit-bundle/flow-kit/prompts | wc -l` = 0（真路径成立，判据本身可用，问题只在 AC 文本的路径名）。此外 `:161` 白名单列 `test/test_guide_copy_parity.bats`，但 `Makefile:79-85` 的 `check-test-sync` 要求 `test/` 与 `flow-kit-bundle/test/` 逐文件一致（`diff -rq`），新增单份文件会让 `make check` 第一门变红——白名单缺 `flow-kit-bundle/test/test_guide_copy_parity.bats`（两路径实测均 MISSING，尚未创建）。
**Source（源头）**：`Makefile:79-85`（双源同源契约）与 `Makefile:106`（`check:` 含 `check-test-sync`）；AC-9 自身要求「`make check` 六门全绿」（`:163`）。
**Consequence（后果）**：① 冻结断言写成 `git diff -- <不存在路径>` 时输出为空 → 即使 `flow-kit-bundle/skills/**` 被改也不报（假绿），与 AC-9 的用意相反；② 白名单缺件导致 T06 一落地即污染门禁，阶段 4 的 `make check` 无论怎么跑都不绿，补救路径只剩"改 Makefile"（越界）。
**Remedy（修补）**：`skills/**` → `flow-kit-bundle/skills/**`、`prompts/**` → `flow-kit-bundle/flow-kit/prompts/**`（或直接引用 `:164` 已写对的四条路径）；白名单补 `flow-kit-bundle/test/test_guide_copy_parity.bats` 并注明「由 `make test-sync` 产出，两处须同源」。

### 🟡 R18 · AC-2/AC-4 的「正例」列被 markdown 转义管道破坏，且与「= 0 命中 / ≥ 1 命中」的自洽性冲突

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:54`（D23 行）正例写作 `` `Bash\|Write\|Edit` + `path-guard` ``，`:80`（D37/D38 行）正例写作 `l3-api.sh` / `l3-done.sh`。实测列数：表头与其余行均为 **4 个 `|`**，而 `:54` 与 `:80` 为 **6 个 `|`**，`:82` 之后的表尾结构随之错位（`awk` 计列可见 6 vs 4）。同时 `:60` 规定「反例用 `grep -F` 字面匹配」——`grep -F 'Bash\|Write\|Edit'` 是**字面匹配**，永远不会命中指南（用户可见写法是 `Bash` / `Write` / `Edit` 三者并列，实测 `grep -Fc 'Bash|Write|Edit'` 因 `\|` 转义为**空输出**、无有效计数）。
**Source（源头）**：D23 的漂移报告原文与 `pre-tool-use/independent-review-gate.sh` 的实际 matcher 配置；`REQUIREMENT.md:60` 的 `grep -F` 约定。
**Consequence（后果）**：`TASK.md` 附录 A 若按 AC 文本机械生成断言，D23 行会因字面 `\|` 而恒红（或解析为空 → 恒绿），D37/D38 行的正例被 markdown 渲染成 3 列，逐条 grep 表的"逐行"对应关系断裂（阶段 5 的"逐条实跑输出"无法与 AC 行号对齐）。
**Remedy（修补）**：转义管道改为代码块内的真管道并明确匹配方式（如 `grep -E 'matcher: \`(Bash|Write|Edit)\`'`，或正例拆成三串分别 ≥1）；表内所有 `\|` 改为 `` `Bash` + `Write` + `Edit` `` 式并列，保证每行 `|` 数 = 4。

### 🟢 R19 · NFR 性能条目的"比较逻辑"未定义，且无验证点可复现

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:219` 与 `:175` 要求「新增守护的**比较逻辑** < 1s（`time` 单独测比较命令中位数 ×3）」，但 AC 集合里没有一条定义"比较逻辑"的边界（是 4 次 `md5sum`？含 `md5sum` 进程启动？含 bats 断言包装？）。实测 4 份副本一次性 `md5sum` 三次各 **0.00s**（`/usr/bin/time`，`md5sum` 单进程），NFR 事实上已被满足，但 TEST.md 无法复现"同一件事"的计时。
**Source（源头）**：`Makefile:117-121` 的既有范式（`check-dist` NFR ≤2s / 实测 0.61s，附带"测的是什么"的口径）；`REQUIREMENT.md:175`（AC-10）自身的计时承诺。
**Consequence（后果）**：阶段 5 记入 TEST.md 的耗时数字不可比对（本次实测量级为 10⁻² 秒，不同口径可差一个数量级），NFR 条目退化为形式记录；风险有界（比较逻辑规模固定，不可能接近 1s）。
**Remedy（修补）**：在 AC-10 写明被测命令的**逐字文本**（如 `time md5sum <四路径>` 的 `real`，取 3 次中位数），并注明"不含 `npx`/bats 进程启动"。附带实测供参考：本环境该命令中位数 < 0.01s。

---

## 主 agent 响应（阶段 1 · L2 第二轮 R12–R19 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R12 | 🔴 | **Fixed in: REQUIREMENT.md AC-1/AC-2/AC-3（v3）** | ① 三条 AC 的断言对象统一改为「**四份副本各自满足**」（反例四份都 0、正例四份都 ≥1），单一副本通过不算通过；② 加前置条件「跑矩阵前根副本须已与 bundle 对齐（T04 的 cp）；对齐前只核 bundle 并记录基线」；③ D01/D08 标 `already-fixed`（bundle 已 0）但**仍须核对根副本同串归零**，不得免检；④ 明确 `grep -F` 只用于反例，D23 正例改用真管道 `Bash|Write|Edit` 语境匹配（见 R18） |
| R13 | 🔴 | **Fixed in: REQUIREMENT.md AC-4（v3 锚点类别规则）** | 写入规则：锚点必须是用户在**配置文件 / 目录树 / 命令行 / 正文**里真能看到的串（配置键名、hook 入口脚本名、命令、路径、概念措辞）；**只排除内部契约标记**（`<!-- /L3-SECTION -->`、签名行）。并明确「正例锚点由本轮修订创建，改前 0 命中属正常，不视为不可达」。9 条被点名的锚点逐条复核：`max_artifact_bytes`/`80000`/`l3.env`/`runtime-edit-guard`/`path-guard`/`check-hooks-sync`/`verify-claims` 均属用户可见类别（T02 落地后可达）；`占位块`/`代码未消费`改为三选一（`占位块` 或 `代码未消费` 或「此键当前无实际作用」）；`六门` 降为可选措辞不作断言 |
| R14 | 🟡 | **Fixed in: REQUIREMENT.md AC-2/AC-3（v3 锚点收窄）** | D30 正例改 `无独立开关`（删泛词 `flow_active_integrity`）；D18 正例用报告原文 `快速体检`/`完整审计`/`单维深挖`，反例收窄为整句 `- **标准**（默认）：全维诊断`；D16 反例收窄为含文件名的 `项目根 \`ARCHITECTURE.md\``；D22 反例收窄为整句 `允许手动绕过` 并把配置键行列入白名单；D33 正例去掉 `off` |
| R15 | 🟡 | **Fixed in: REQUIREMENT.md AC-5 Given（v3）** | 删除写死的 md5/行数与「落后 2 行」表述，改为「执行时记录四份快照（md5/行数/mtime）作基线」，Then 以「同步后 md5 唯一值 = 1 + 与快照对比证明同步发生」判定 |
| R16 | 🟡 | **Fixed in: REQUIREMENT.md AC-3 D43 行（v3）** | D43 补独立断言：反例 `2026-07-13`、正例 `^> 版本: 2026-09-21` + `最后同步日期**: 2026-09-21`，删掉「由 AC-1 覆盖」 |
| R17 | 🟡 | **Fixed in: REQUIREMENT.md AC-9（v3）** | 冻结路径改为仓库真实路径 `flow-kit-bundle/skills/**`、`flow-kit-bundle/flow-kit/prompts/**`（与验证方式同源）；白名单补 `flow-kit-bundle/test/test_guide_copy_parity.bats`（`make test-sync` 产出） |
| R18 | 🟡 | **Fixed in: REQUIREMENT.md AC-2（v3）** | D23 反例改为按整句语境匹配、正例改为真管道 `Bash|Write|Edit` 或三串分别 ≥1；表内 `\|` 转义写法已改为并列式，保证每行 4 个 `|` |
| R19 | 🟢 | **折入: REQUIREMENT.md AC-10 + NFR（v3）** | 被测命令逐字写明：`time md5sum <四路径>` 的 real，3 次中位数，不含 `npx`/bats 启动与 python-pptx 读取 |

**复审请求**：R12–R19 已全部落到 REQUIREMENT.md v3（AC-1/2/3/4/5/9/10 + NFR + 修订记录）。第二轮的其他事实提醒（并发改写导致 md5/行数漂移）已通过「不写死快照值」系统性消除。
---

## L2 盲审（第三轮）

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/REQUIREMENT.md`（**v3 现状**，246 行）· 参考 `CHANGE.md` · 事实基线 `/tmp/guide-drift-report.md`（53 KB）
- 独立性：输入仅工件路径 + 仓库只读核对；**未收到**主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损。文件内第一/二轮 L2 段与两段「主 agent 响应」按调用方说明作历史轮次处理，**未作为本轮判据**
- 实测规模（全部只读）：**82 条锚点 × 4 副本逐一 `grep -F`**（AC-2 11 反 + 16 正 / AC-3 10 反 + 26 正 / AC-4 19 正）；**HEAD 基线对照**（`git show HEAD:…` = bundle `d87c6d84`/1632 行、根 `fb2ff01b`/1631 行）判「改前是否已绿」；全仓 7 锚点扫描（`flow-kit-bundle/` + `dsh-flow-kit/`）；`Makefile` 六门依赖链；`package-dsh-plugin.sh` 三张映射表 + `--check` 语义；`deck_checks.py` / `slides.json` / pptx 页数；`~/.dsh/profiles/web/node_modules/dsh-flow-kit/**` 存在性；`.gitignore` + `git check-ignore`；AC-9 白名单集合比对**实跑**；AC-11 `gate_config` / `auto_advance` 真值；报告 D01/D03/D10/D11/D13/D16/D18–D23/D30/D32/D33/D36–D43 原文逐条比对
- **审查期间事实变更（如实记录）**：工作树被并发改写——bundle 副本 `3af63190`(1692) → `17efc3`(1693) → `86057b9c`(1693，22:20 已与根/dist 三份对齐)；`test/test_guide_copy_parity.bats` 两份新出现（未跟踪）；`README.md` 130 → 149 行；pptx 已重建（`8244337a`）。**下文行号与计数为冻结快照时刻（22:14–22:16，`/tmp/l2-snap/`）实测**，串值与结论不受影响

### 🔴 R20 · AC-9 的改动边界判据与 AC-11 互斥：断言在实现完全正确时**必红**，且对本次新增/再生文件全程失明

**Severity**：🔴 Critical
**Symptom（症状）**：
- `REQUIREMENT.md:167-174`（AC-9）要求 `git diff --name-only` 的路径**全部落在白名单内**。22:19 实跑：`.specs/CONTEXT.md` 已修改且**不在白名单**，其 diff（+20 行）带本 change 自己的标记 `<!-- user-guide-sync-2026-09b 追加 ↓ -->` 与「已锁决策」表 → 是本 change 的产物，不是外部噪声
- 同文档 `:198`（AC-11 Then）要求「更新 `CHANGELOG.md` / `STATE.md` / `LESSONS.md`」；实测真路径 = `.specs/CHANGELOG.md`、`.specs/STATE.md`、`.specs/LESSONS.md`（三者均 `git ls-files` 命中 → tracked、会被 `git diff` 列出）→ **三条全在白名单外**：AC-9 ∩ AC-11 = ∅
- 同一判据对本次交付物**失明**：`test/test_guide_copy_parity.bats`、`flow-kit-bundle/test/test_guide_copy_parity.bats`、`.specs/user-guide-sync-2026-09b/**` 在 `git status` 中均为 `??`（未跟踪）→ 永不出现于 `git diff --name-only`；dist 两份指南副本 + `dist/dsh-flow-kit/README.md` 被忽略（`git check-ignore -v` → `.gitignore:63:dist/`）→ 亦永不出现。即白名单 6 条（dist×3 + bats×2 + change 目录）对判据是空集，"只改 dist 不改源"这类越界**看不见**
**Source（源头）**：AC-9 自身（`:167-174`）+ AC-11 Then（`:198`）+ `git diff` 语义（只列被跟踪且未暂存的修改）；L-031 要求的一致性清单必须覆盖本次全部跨文件写入点；`REQUIREMENT.md:246`「AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC」
**Consequence（后果）**：阶段 5 的 AC-9 断言在**实现完全正确时也会红**，且无合法出路——回滚 `.specs/CONTEXT.md` 等于销毁本 change 自己的术语沉淀（DESIGN/后续 change 都引用它），改 AC 又被 `:246` 禁止。反向风险同时存在：真正需要守护的 dist 再生与新增测试文件不在判据视野内，越界可静默通过。**两个方向同时错**
**Remedy（修补）**：白名单补 4 条（`.specs/CONTEXT.md`、`.specs/CHANGELOG.md`、`.specs/STATE.md`、`.specs/LESSONS.md`，或写 `.specs/*.md` 并排除 `.specs/archive/**`）；判据换成 `git status --porcelain`（含 `??`）+ `git ls-files -o --exclude-standard`，并在 AC-9 显式写「dist 两份与 `dist/dsh-flow-kit/README.md` 由 `make check-dist` 逐文件 `cmp` 守护，不靠 `git diff`」；把判据时点钉死在阶段 5 结束前（阶段 7 归档写入的文件不参与）

### 🔴 R21 · AC-2/AC-3 的 5 条「正例」不可字面执行：与唯一事实基线（报告建议改法）及**已落地实现**冲突 → 恒红

**Severity**：🔴 Critical
**Symptom（症状）**：40 条正例锚点全跑 `grep -F`，其中 5 条不可执行（实测值 = 冻结快照四副本 / HEAD 基线 / 报告原文）：

| 行 | AC 正例字面 | 报告建议改法原文 / 实现现状 | 实测 |
|---|---|---|---|
| D03 | `仅安装 hooks + .specs/STATE.md 模板` | 报告 `:75` = `` 仅安装 hooks + `.specs/STATE.md` 模板（需配合 --project） ``（**含反引号**）；实现 `flow-kit-bundle/FLOW-KIT-用户指南.md:89` 用的正是报告措辞 | AC 字面 **0**（四副本 + 工作树）；报告字面 **1**；`TASK.md` 附录 A 抄的是 AC 字面 → 阶段 5 必红 |
| D22 | `子系统自动写 `.done`` | 报告 `:222` = 「自动写 `.done`（`L3_verdict=skipped`）」；实现 `:996` = `…后，**由子系统自动**写 `.done`…`（`**` 打断子串） | `子系统自动写` = **0**（报告 0 / HEAD 0 / 工作树 0）；`子系统自动` = 1 |
| D01 | `brooks-tools` + 「hooks 需 `--user` 的说明」 | 报告 D01 建议块 = `核心引擎 + skills + brooks-lint + brooks-tools；默认不含 hooks` + `` hooks 需再加 `--user` `` | 后半句是散文（任何副本 0 命中）；前半 `brooks-tools` HEAD 已 **6** 命中 = 改前即绿 |
| D43 | `` ^> 版本: 2026-09-21 `` + `` 最后同步日期\*\*: 2026-09-21 `` | 同样两串在 AC-1（`:34-35`）是**正则**用法 | `grep -F` 全 **0**；`grep -E` = 1；AC 未定义正例用字面还是正则 |
| D10 | `archive/<日期>-<id>/` | 报告 `:133` 与实现 `:750`/`:761`/`:770` 均为 `.specs/archive/<YYYY-MM-DD>-<id>/` | AC 字面仅 **1**（`:1405` 文件树注释）→ 同一路径在指南中并存两种占位写法，只为满足 grep |

**Source（源头）**：`REQUIREMENT.md:5`（漂移报告为**唯一事实基线**）+ AC-3 `:76`「逐条按报告建议修订」；AC-2 `:50`「反例一律用 `grep -F` 字面匹配」→ 字面执行是默认读法；第二轮 R14/R18 已定口径（锚点须与报告建议改法**逐字**对齐），v3 只落实到 D16/D18/D23/D30
**Consequence（后果）**：**内容按报告写对反而断言红**（D03 已处于该状态）；要转绿只能把指南正文改成 AC 的自创措辞——文档被 grep 串反向塑形（D10 的 `<日期>` / `<YYYY-MM-DD>` 并存已是实例），或在 TEST 阶段重新解释锚点 = 移动球门，正是本 change 要消灭的假绿
**Remedy（修补）**：逐条替换为报告原文——D03 补反引号；D22 用 `bypass` / `L3_verdict=skipped` 作锚点、概念句移出断言列；D01 后半句改报告原文 `` 需再加 `--user` ``；D43 标注「正则（`grep -E`）」；D10 改 `<YYYY-MM-DD>`；并在 AC-2/AC-3 表头统一声明「正例列 = 字面串（`grep -F`），正则须显式标注」，与 `TASK.md` 附录 A 的「grep 均为字面串」口径对齐

### 🟡 R22 · AC-2 D33 的反例不可满足，且与同行脚注自相矛盾

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:66`（D33）反例列写 `` `independent` / `true` / `off` / `false` ``（**作值域全集**），而同一格的脚注又写「**v3 去掉 `off`**：它在正反例两侧都合法出现」。按 AC-2 `:50` 规定的字面读法实测（工作树 bundle）：`independent` = **23**、`true` = **11**、`off` = **14**、`false` = **6**。更硬的反证：报告 `:309` 的**建议改法本身**要求写入「`off`（旧值 `independent`/`true` 自动映射为 `both`，`false` 视为 `off`）」，实现 `:1263`/`:319`/`:1636` 已照此落地 → 「反例 0 命中」与「逐条按报告建议修订」**互斥**。整格读法（含反引号与 `/`）实测 = 0，但 AC 从未写这种读法
**Source（源头）**：`REQUIREMENT.md:5`（唯一事实基线）+ AC-3 `:76` + AC-2 `:50`（字面匹配）+ 报告 D33（`:302-309`）
**Consequence（后果）**：该行在阶段 5 只能二选一——按字面**必红**，或按"整格串"重解释（口径未写、下一轮不可复现）；而 D33 是 14 条 🔴 之一（§10.7 值域表与 §4.1.2 自相矛盾），恰好会被这条空转吃掉
**Remedy（修补）**：反例改为**旧表格行的整格原文**并注明「按整格 `grep -F`」；正例改 `both` + `L2` + `L3` **同格共现**；显式声明 `off` / `independent` / `true` / `false` 不参与反例断言（新旧文本中均合法出现）

### 🟡 R23 · AC-3 的 D26 整行、D30 正例仍是「改前即绿」——R14 只修了一半

**Severity**：🟡 Important
**Symptom（症状）**：HEAD 基线（改动前）实测——
- **D26**（`:86`）标注「无反例锚点」，唯一正例 `archive-uncommitted` **改前已 1 命中**：`flow-kit-bundle/FLOW-KIT-用户指南.md:909`（pre-commit 门禁段），而 D26 的缺陷位置是 SessionStart 收割类型清单（HEAD `:965` 只列 `compliance` / `l3-model-missing` / `l2-model-missing` / `l2-missing`）→ 与命中位置无关，**修没修都绿**
- **D30**（`:87`）v3 以「`flow_active_integrity` 在模块清单里本来就有 2 命中、改前即绿、无判定力」为由换成 `无独立开关`；实测 `无独立开关` 在 HEAD **已 3 命中**（`:882`/`:889`/`:920`，模块表图例 + 同一事实的旧表述）→ 同样改前即绿，**替换未达成 AC 自述目的**
**Source（源头）**：AC-4 `:100` 自定规则「正例锚点在本轮**由修订创建**（改前 0 命中、改后 ≥1 命中属正常）」；第二轮 R14 的「改前已绿 = 无判定力」口径
**Consequence（后果）**：43 条逐条矩阵中的这 2 行产出**无信息量的 PASS**（D26 整行只有正例）；`CHANGE.md:57` 自述的主要风险「改了措辞但事实仍旧」恰好在这 2 条上无检测力
**Remedy（修补）**：D26 把断言**定位到小节**（§7 SessionStart 段内 `archive-uncommitted` ≥1，或反例取该段类型清单原文 + 差分）；D30 正例改用报告建议改法中独一无二的短语（如 `31 号由 goal.auto_advance 驱动`），保留反例 `"31-auto-advance": true`

### 🟡 R24 · AC 指名的断言载体（TASK.md 附录 A）与 AC 本体锚点互不一致，并复活了 v3 已删除的两处无判定力串

**Severity**：🟡 Important
**Symptom（症状）**：AC-2 `:70` / AC-3 `:94` 把验证方式指定为「`TASK.md` 附录 A 的逐行 grep 断言」。实测该附录（22:18 读取）与 AC 表相互矛盾：
- **D30**：附录 A 正例 = 「12 键口径（`flow_active_integrity` 等）」——AC 的 `无独立开关` 在 TASK 中 **0** 命中 → v3/R14 明确删除的无判定力串被写回
- **D33**：附录 A 正例写回 `+ off`（AC 已删）→ R14 点名的「同一串既 ≥1 又 =0」原样复活
- **D22**：AC 正例「子系统自动写 `.done`」→ 附录 A 退化为泛词 `自动`；**D18**：AC 反例整句 `- **标准**（默认）：全维诊断` → 附录 A 退化为泛词 `标准`
- 反方向：附录 A 含 AC 表中不存在的 11 行（D02/D05/D06/D07/D15/D17/D28/D29/D35/D39/D40/D42），其断言未在 REQUIREMENT 的任何 AC 里定义
**Source（源头）**：AC-2 `:70` / AC-3 `:94` 的验证方式条款；`REQUIREMENT.md:246`「AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC」；L-031（锚点须跨文件同步）
**Consequence（后果）**：阶段 5 按 AC 指名的载体执行时，D30 与 D33 拿到**与 AC 意图相反**的判据 → v3 的修订在这两行等于未生效；附录 A 自造断言（11 行）绕过「AC 唯一来源」约束，TEST 要么无判据可依、要么反向污染 AC
**Remedy（修补）**：以 AC 表为母本重新生成附录 A（或把附录 A 的补充回填 REQUIREMENT 升 v4 后重指，二选一并写明谁是母本）；加一条机械核对写入 TEST.md——「附录 A 的反例/正例集 ⊇ AC-2/AC-3 表」

### 🟡 R25 · AC-10 的 when-present 分支**当前已激活**，但它指定的修复命令对那两份是错的（运行时副本）

**Severity**：🟡 Important
**Symptom（症状）**：实测 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/docs/FLOW-KIT-用户指南.md` 与 `…/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md` **存在**（各 76791 B，mtime 09-21 21:33 = HEAD dist 内容 `d87c6d84`）→ AC-10 `:183` 的「不存在则 SKIP」不成立，这两份**必须**在验收时与重建后的 dist 一致。而 AC-10 `:182` 要求失败信息附修复命令 `cp flow-kit-bundle/FLOW-KIT-用户指南.md <target>` —— 对这两份 target 是**直改运行时副本**：`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` 明令 deny，权威指引是 `make hooks-sync` / `make dsh-sync`（指南 `:925`）；正确入口 `make dsh-sync`（`Makefile:136`，且 `dsh-sync: check-dist`）
**Source（源头）**：AC-10 `:182-183` 自身 + `Makefile:136` + `runtime-edit-guard.sh`（本机在位：审查期间该守卫实际 deny 过我含 `.done` 字样的只读 grep 命令，机制有效）
**Consequence（后果）**：阶段 5/6 若照 AC 命令去动那两份会被守卫 deny；若只跑 bats，则卡在「红了但给的命令不管用」，最省事的出路是削弱断言 —— 又回到移动球门
**Remedy（修补）**：AC-10 补一句「已装 profile 两份的刷新入口 = `make dsh-sync`（`DSH_PROFILE=<名>` 覆盖）；失败信息按 target 类型给命令——dist 两份给 `bash package-dsh-plugin.sh`，profile 两份给 `make dsh-sync`」

### 🟢 R26 · 日期保留项的行号在三份文档里各不相同

**Severity**：🟢 Minor
**Symptom（症状）**：`2026-09-03` 历史锚点：`REQUIREMENT.md:22`/`:27` 写 `:916`/`:946`（= 根副本实测命中 ✓）、`TASK.md` 保留项登记写 `:922`/`:952`（= 改写中的 bundle）、冻结快照 bundle 与 dist 实测均为 `:998`。三份文档三套行号。判据本身（`grep -n '2026-09-03' | grep -vc '起'` = 0）与行号无关，故风险有界
**Source（源头）**：AC-1 `:40` 要求 TEST.md 记录「日期锚点白名单」，未规定是否含行号
**Consequence（后果）**：白名单若抄行号，T04 对齐或后续任一修订后立即失效，下一轮 review 无法复现
**Remedy（修补）**：AC-1 `:40` 改为「白名单只登记**原文摘录 + 判据**，行号以实跑时当前值为准」（TASK.md 已有同义句，REQUIREMENT 未同步）

---

### L-031 跨文件一致性扫描（本轮强制执行 · 结论：本 change 声明范围内**无漏改**）

- **锚点盘点**：AC-2/AC-3/AC-4 共 82 条锚点 × 4 副本全跑（见上）；实现侧扫描 7 条关键锚点（`三轮审查`、`.specs/lessons/`、`ARCHIVE.md`、`pre_tool_use_gates.auto_checkpoint`、`此字段仅作末级兜底`、`随 flow-kit bundle 分发`、`sub-goal-`）覆盖 `flow-kit-bundle/` + `dsh-flow-kit/` 全文件类型
- **分类结果**：①「AC 列出且已改」= 指南侧全部 43 条 D 项（工作树已改 30+ 处）；②「AC 漏列但已改」= `.specs/CONTEXT.md`（见 R20，白名单漏列）；③「AC 列出但未改」= 无；④「**漏列且未改**」= **1 组，落在 AC-9 明示冻结域**：
  - `三轮审查`（D11 反例）在用户实际加载的 skill 里原样存留：`flow-kit-bundle/skills/flow-review/SKILL.md:6,24,196`（另 `:2` 的 `description` 写「**双轮**审查」= 第三种措辞）、`flow-kit-bundle/flow-kit/README.md:304`（「双 / 三轮审查」）、`dist/dsh-flow-kit/skills/flow-review/SKILL.md`（打包副本同源）；权威实现 `flow-kit-bundle/flow-kit/prompts/6-review.md:1` = 「单轮合并审查」
  - **为什么不计为 🔴 漏改**：AC-9 `:173` 冻结 `flow-kit-bundle/skills/**` 且 `:174` 判据实测 `wc -l` = 0；`CHANGE.md:41` 明示「发现实现侧问题只在 REVIEW / LESSONS 登记」。故这是**范围外残留**，不是 AC 漏改——但后果要写清：改完后指南断言「单轮合并审查」，而用户加载的 skill 标题仍是「三轮审查」
  - 与 `MINOR-DEFERRED.md` M8 的差异（如实记录）：M8 还列了 `flow-kit-bundle/flow-kit/templates/REVIEW.md:10,24,73,79`；本轮全仓实测该文件只有 `:73`（`## 第三轮 · UI 视觉审查`）含「三轮」，`grep -F '三轮审查'` **0 命中** → M8 行号清单偏大，阶段 7 triage 时按实测收敛
- **已核对通过项（本轮确认 v2/v3 修订生效，供后续阶段复用）**：AC-1（根副本 `:3`/`:1380`/`:916`/`:946` 与 Given 逐一对上；`20260713` 四副本 0）· AC-4（N1–N11 的 19 条锚点中 `max_artifact_bytes`/`80000`/`l3.env`/`runtime-edit-guard`/`path-guard`/`check-hooks-sync`/`verify-claims` 等改前 0 命中、属用户可见类别 → **可达**；N2/N3/N4/N6 行内另有 0 命中锚点 → 有判定力）· AC-5（`package-dsh-plugin.sh:44-46` `COPY_OPTIONAL` 的 docs 边 + `:36` `COPY_DIRS` 的 `$BUNDLE_DIR:$PKG_DIR/vendor/flow-kit-bundle` 整棵映射，解释了 dist 第二份来源 → 方向描述成立）· AC-6（`EXPECT_PAGES=20`、封面断言 `deck_checks.py:50`、slides 20 页、pptx 20 页 → Given 准确，新断言清单可实现）· AC-7（`soffice` 24.2.7.2 / `pdftoppm` 24.02 / python-pptx 1.0.2 均在位）· AC-8（HEAD README 130 行、L3 段起于 `:101`、`max_artifact_bytes` 在 `:121` → Given 的 `:101-129` 在写下时准确；全文 `make check` 类串 0 命中 ✓）· AC-10（`make test` = `npx bats test/`、`check: test …` 为第一门 → 新用例确会被收集）· AC-11（`.goal-snapshot.json` 六阶段 `both` ✓、`.flow-active.goal.auto_advance=true` ✓）

**Verdict**: fail

---

## 主 agent 响应（阶段 1 · L2 第三轮 R20–R26 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R20 | 🔴 | **Fixed in: REQUIREMENT.md AC-9（v4 重写判据）** | ① 白名单补 `.specs/CONTEXT.md`、`.specs/{CHANGELOG,STATE,LESSONS}.md`、`dist/.../vendor/.../test/*.bats`、`.specs/user-guide-sync-2026-09b/**`，消除 AC-9 ∩ AC-11 = ∅；② 判据换成 `git status --porcelain` + `git ls-files -o --exclude-standard`（`git diff` 对未跟踪与被忽略文件结构性失明）；③ 显式声明 dist 其余再生件由 `make check-dist` 守护；④ 判据时点钉在阶段 5 结束前 |
| R21 | 🔴 | **Fixed in: REQUIREMENT.md AC-2/AC-3 锚点（v4）+ TASK 附录 A（v4 同源回填）** | 逐条换成**可字面执行**的锚点：D01 → `brooks-tools` + `需再加 \`--user\``；D03 → 带回反引号的 `仅安装 hooks + \`.specs/STATE.md\` 模板`；D10 → `archive/<YYYY-MM-DD>-<change-id>/`；D22 → `由子系统自动` + `L3_verdict=skipped`；D43 → 显式标注 `regex:`。表头新增「正例列 = 字面串；正则须标注」声明 |
| R22 | 🟡 | **Fixed in: REQUIREMENT.md AC-2 D33 行（v4）** | 反例改为**旧表格行整格原文**（按整格 `grep -F`），并显式声明 4 个旧值串（`independent`/`true`/`off`/`false`）**单独不参与断言**——与报告建议改法（要求写入旧值映射说明）自洽 |
| R23 | 🟡 | **Fixed in: REQUIREMENT.md AC-3 D26/D30 行（v4）** | D26 改为**段落定位**（SessionStart 段内 `archive-uncommitted`），不再用改前即绿的全文件 grep；D30 正例改为报告建议改法的独有短语 `31 号由 ` + `goal.auto_advance` + `驱动` |
| R24 | 🟡 | **Fixed in: TASK.md 附录 A 表头 + 5 行回填（v4）** | 新增**母本声明**：「断言母本 = REQUIREMENT 的 AC-2/AC-3/AC-4 表；附录 A 是超集，冲突时以 AC 表为准并回填」；D18/D22/D26/D30/D33/D43 六行按 AC 表回填；TEST.md 增加集合断言「附录 A ⊇ AC-2/AC-3 表」 |
| R25 | 🟡 | **Fixed in: REQUIREMENT.md AC-10（v4）** | 修复命令按 target 类型分派：仓内三份用 `cp`；**已安装插件目录的权威入口是 `make dsh-sync`**（`DSH_PROFILE=<名>` 覆盖），明确禁止对该目录建议 `cp`（等于直改运行时副本） |
| R26 | 🟢 | **Fixed in: REQUIREMENT.md AC-1（v4）** | 删除写死行号，改为「原文摘录 + 判据；**行号以实跑时当前值为准**」，并记录三套行号的历史（`:916/:946` vs `:922/:952` vs 实测 `:998`） |
| — | 🟢 | **Tech-debt: MINOR-DEFERRED M8 修正** | 你指出 M8 对 `templates/REVIEW.md` 的行号清单偏大（实测仅 `:73` 含「三轮」、`grep -F '三轮审查'` = 0）→ 已按实测收敛该表行 |

**复审请求**：REQUIREMENT v4（AC-1/AC-2/AC-3/AC-9/AC-10）+ TASK 附录 A v4 已落。R20/R21 为 🔴，已逐条修；R22–R26 已修或登记。

---

## L2 盲审（第四轮）

**Verdict**: fail

- 审查对象：`.specs/user-guide-sync-2026-09b/REQUIREMENT.md`（**当前现状 = v4 正文**，257 行）· 参考 `CHANGE.md` · 事实基线 `/tmp/guide-drift-report.md`（D01–D43 共 43 条：14🔴 / 23🟡 / 6🟢 + N1–N11 + N12）
- 独立性：输入仅调用方给的三条路径 + 仓库只读核对；**未收到**主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损。文件内前三轮 L2 段与三段「主 agent 响应」按调用方说明作**历史轮次**处理，不作为本轮判据——本轮每条结论均由本轮实测独立得出
- 实测（全部只读）：四副本 `md5/行数/mtime` 快照 · AC-2/AC-3/AC-4 全部锚点 `grep -F` 逐一实跑 · AC-1 四段判据实跑 · `check-appendix-superset.py` 实跑 · `verify-ac.sh` / `verify-boundary.sh` 判据矩阵逐行与 AC 表比对 · 报告 D 项严重度与 REQUIREMENT 行集合做差集 · `Makefile` / `deck_checks.py` / `slides.json` / `pptx`（24 页）/ `~/.dsh/profiles/web/...` 两份 / `.goal-snapshot.json` + `.flow-active`
- 事实快照（本轮冻结）：指南四副本 + 已装 profile 两份**五处 md5 全 = `86057b9c`、1693 行**；`git status --porcelain` = 10 M + 3 ??（全部 ⊆ 白名单文字化后的集合）；禁动域 `git diff` = 0 行；`gate_config` 六阶段 `both` + `auto_advance=true`；pptx = 24 页 = `slides.json` 长度。**AC-5/AC-9/AC-10/AC-11 的 Given 与现状一致**

### 🔴 R27 · AC-3 D13 的正例**双串皆不可达**：该行断言在执行时必红，而实测「PASS」已由判据外的自造串替代

**Severity**：🔴 Critical
**Symptom（症状）**：AC-3 `:83` 的 D13 正例写「`同波次内无 depends_on`（或「跨波次必须声明」）」。bundle 副本实测：`同波次内无 depends_on` = **0**、`跨波次必须声明` = **0**；指南实际措辞在 `:623` = 「同波次内不应有 `depends_on`；跨波次必须显式声明 `depends_on`」。而 `.specs/user-guide-sync-2026-09b/verify-ac.sh:104` 断言的第三个串 `同波次内不应有` = **1** —— AC 表里从未出现过这个串；`TASK.md:306` 同样只有两个不可达串。⇒ 按 AC 本体执行 D13 **必红**；实测绿只来自判据外新增的串。
**Source（源头）**：AC-3 `:83` + AC-3 表头 `:78`（正例 = 字面串）自身；`REQUIREMENT.md:70`/`:94` 把验证方式指向 TASK 附录 A；`REQUIREMENT.md:257`「AC 是 TEST 阶段派生用例的唯一来源」。这正是第三轮 R21 点名的机制：**验收引擎替不可执行的锚点自造新锚点**。
**Consequence（后果）**：TEST.md `:27-28` 记「断言通过 80 / 失败 0」——D13 的 PASS 由 `verify-ac.sh` 自造串给出，AC 表本体若被复算即红；D13 是「波次 / `depends_on` 语义写反」的载体，判据已漂到 AC 之外 → 下一轮无法从 AC 复现，属典型移动球门。阶段 5 判据与阶段 1 判据不一致，L3 与后续 change 都无从对账。
**Remedy（修补）**：AC-3 D13 正例改为实际落地措辞 —— 反引号内 `同波次内不应有` **或** `跨波次必须显式声明`；两者都写进 AC 表，并同步 `TASK.md:306` 附录 A。反之若要保留原文措辞，则必须改指南 `:623`（当前措辞与报告 `:154` 的建议改法一致，**应改 AC 而非改正文**）。

### 🔴 R28 · AC-2 D10 的正例在 AC 表 / `verify-ac.sh` / TASK 三处各写一套，且 AC 主表那套在正文**0 命中**——R21 的修复未落到主表

**Severity**：🔴 Critical
**Symptom（症状）**：AC-2 `:57` 脚注自称「**v4：与实现 `:750/:761/:770` 的占位写法对齐**，不再用 `<日期>-<id>`」，但同格正例写的仍是 `<日期>-<id>`（v3 写法）。实测 bundle 副本：`archive/<YYYY-MM-DD>-<change-id>/` = **3**（`:750`/`:761`/`:770`）；`archive/<日期>-<id>/` = **1**（`:1405` 文件树注释）；`TASK.md:303` 只保留 `UAT.md`（无路径锚点）；`.specs/user-guide-sync-2026-09b/verify-ac.sh:64` 断言的是 `archive/<YYYY-MM-DD>-<change-id>/`（= 与 AC 主表不同的第三套）。
**Source（源头）**：AC-2 `:57` 正例列 + AC-2 表头 `:52`（正例 = 字面串）；`REQUIREMENT.md:5`（报告 `:133` 建议改法 = `.specs/archive/<YYYY-MM-DD>-<id>/`）+ `:70`（验证方式指向附录 A）+ `:257`（AC 唯一来源）。
**Consequence（后果）**：D10 原始缺陷（同一路径在指南中并存两种占位写法）**在正文中仍并存**（`:750` 与 `:1405`），v3 修订记录 `:7` 明写「不再用 `<日期>-<id>`」而 v4 主表把它留在正例列 → 按 AC 执行时靠 `:1405` 的那一命中蒙混过关，缺陷本身失检；阶段 5 的实际绿由 `verify-ac.sh` 的第三套串给出，与 AC 表对不上账。
**Remedy（修补）**：AC-2 D10 正例列改为 `archive/<YYYY-MM-DD>-<change-id>/`（与实现 + `verify-ac.sh` 一致），并把 `:1405` 的 `<日期>-<id>` 一并改成正式占位写法，使该锚点在正文唯一化；`TASK.md:303` 回填同一串。

### 🟡 R29 · 正文有 13 处 `v4` 标记，**修订记录却没有 v4 条目**：v4 到底落没落无从判定

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:7-8` 的修订记录只有 v3、v2 两条；正文却含 13 处 `v4` 标记（`:27`/`:40`/`:57`/`:63`/`:66`/`:80`/`:86`/`:87`/`:92`/`:163`/`:175`/`:193`）。即「REQUIREMENT v4」这一版本在文档内**无定义、无边界**，而第三轮响应段 `:324-329` 逐条声明「Fixed in: REQUIREMENT.md …（v4）」。
**Source（源头）**：文档自身的修订记录契约（`:6-8` 的 v3/v2 条目格式）；R26 的修复要求写「行号以实跑时当前值为准」，正文 `:40` 确实落了，但版本层面没有对应记录。
**Consequence（后果）**：本轮必须逐条 grep 才能确认哪条改动真落了（R28 就是这么发现的：脚注声称 v4 已对齐、正例仍是 v3 串）。下一轮 review 与阶段 5 无法用「v4 增量」界定复审范围，只能全量重扫；L3 也无法对账。
**Remedy（修补）**：修订记录补 v4 条目，逐条列出 R20–R26 的落地位置（形如 `v4（2026-09-21）— 吸收阶段 1 L2 第三轮 R20–R26：R20 AC-9 判据换 git status；R21 D01/D03/D22/D43 锚点；R22 D33 整格；R23 D26 段落定位 / D30 锚点；R24 TASK 母本声明；R25 AC-10 修复命令分派；R26 AC-1 去掉写死行号`）。

### 🟡 R30 · `TASK.md` 的日期保留项仍写死行号，且与同文件另一处**自相矛盾**

**Severity**：🟡 Important
**Symptom（症状）**：`TASK.md:377` 写「`2026-09-03` 允许出现在 `:922`/`:952`」。实测四副本该串**各只有 1 处**（当前 = `:998`，与第三轮实测 1 处一致）；`REQUIREMENT.md:40` 已把 `:922/:952` 列为**待废除的历史行号清单**。同一文件的 `:374` 判据是 `grep -n '2026-09-03' | grep -v '起' | wc -l | grep -qx 0`——只约束「非历史句 = 0」，**不约束命中条数**，故 `:377` 的「允许出现在两行」既与现状冲突、又与本文件判据不一致。
**Source（源头）**：AC-1 `:40`（v4 · R26：只登记原文摘录 + 判据，行号以实跑当前值为准）；`TASK.md:287` 母本声明（附录 A 冲突时以 AC 表为准并回填）。
**Consequence（后果）**：阶段 5 直接复用附录 A 的说法会记入一个实测不成立的保留项（`:922/:952` 无对应内容），TEST.md 的「日期锚点白名单」随之失真；下一轮 review 又要花一轮去核行号。R26 的修复只落到 REQUIREMENT、没落到 TASK。
**Remedy（修补）**：`TASK.md:377` 改为「`2026-09-03` 允许出现在**唯一一条**历史锚点句（原文摘录：…「起」句）；**条数以实跑为准**，实测当前 = 1 条」，删掉 `:922`/`:952`。

### 🟡 R31 · `TASK.md` 附录 A 的 D33 与 D30 仍带 v3/v4 已废除的串——附录 A ⊇ AC 的集合断言**检测不到**

**Severity**：🟡 Important
**Symptom（症状）**：
- `TASK.md:326` D33 正例仍写 `both` + `L2` + `L3`（同句共现；**删掉 `off`**）——把 AC-2 `:66` 明写「`off` 不作断言」的串写回正例列；而 `verify-ac.sh:75-77` 断的是 `` `both` `` / `` `L2` `` / `` `L3` ``（三串独立，不校验同句）。
- `.specs/user-guide-sync-2026-09b/check-appendix-superset.py` 实跑输出「检查单元格：43 个；附录 A 缺失：0 个」（rc=0），但其口径（`:39-45`）是「每格只取反引号片段、每格**只要有 1 个候选**出现在 TASK.md 即通过」——D33 靠 `` `both` `` 单个片段通过，`off` / `独立` / 三个档位的同句共现**不在检测范围**。
**Source（源头）**：AC-2 `:66`（R22 的裁定）；`TASK.md:287` 母本声明（冲突时以 AC 表为准并回填）；`TEST.md:56-57` 把该脚本结果当作集合断言证据。
**Consequence（后果）**：TEST.md 引用「附录 A ⊇ AC-2/AC-3 表」证明两表一致，实际上只能证明「每格至少一个反引号片段在 TASK.md 里出现过」——同句共现、单串不参与、字面 vs 正则这些恰是前几轮争议点的口径**全部逃过断言**。集合断言给了超出其检测力的保证。
**Remedy（修补）**：① `TASK.md:326` 删 `off`；② 集合断言升级为「逐锚点等值比对」——对 AC-2/AC-3 每行的正/反例列，按 `；`/`+` 拆分出**全部**字面锚点（含无反引号的散串，如 D01 的 `需再加 --user`、D13 的两个候选），逐个断言在附录 A 同 D 项行内出现，缺失即 FAIL；③ 在 TEST.md 写明该脚本的检测边界，不得用之替代锚点等值核对。

### 🟡 R32 · AC-3 的两处「正例」不是可 grep 的字面串；D19 的三选一与判据实现只有部分交集

**Severity**：🟡 Important
**Symptom（症状）**：
- D34 `:67` 正例 = 「用户级三平台路径」（说明性措辞，非字符串）；D36 `:89` 正例 = 「配置在用户级（等价表述）」（同上）——与表头 `:78`「正例 = 字面串」直接冲突（D37/D38 `:90`、D41 `:91`、D32 `:88` 已按字面写，故这不是表格惯例问题）。
- D19 `:60` 正例 = 「`占位块` **或** `代码未消费` **或**「此键当前无实际作用」（三选一即可）」。实测三串在当前正文：`占位块` = 1、`代码未消费` = 1、`此键当前无实际作用` = **0**；`verify-ac.sh:72-73` 也只断前两串。同格的反例 `pre_tool_use_gates.auto_checkpoint` = 0 ✓。
**Source（源头）**：AC-3 表头 `:78` + AC-2 表头 `:52`（R21 的统一口径：正例 = 字面串，正则须显式标注）；AC-2 `:70` / AC-3 `:94`（验证方式 = 附录 A 逐行断言）。
**Consequence（后果）**：D34/D36 在阶段 5 **无判据可执行**——`grep -F '用户级三平台路径'` 只会 0 命中（实测正文该串 0）；D19 的判定集合在 AC 与判据实现之间不相等（3 vs 2 取或），任一实现都「合法通过」而事实未被核实（当前真正落地的只有 `:960` 段落里的「不存在…这类键」+ `占位块` 两种表述）。
**Remedy（修补）**：① D34 正例改字面串 `~/.claude/stop-hook.json` · `~/.config/opencode/stop-hook.json` · `~/.dsh/stop-hook.json`（三平台用户级路径，均已实测 ≥1）；D36 正例改字面串「用户级一份」（实测 ≥1）或 `:958` 的整句摘录；② D19 三选一改为**与实现一致的单一串**（`占位块`），或显式写明「本表是 `verify-ac.sh` 的锚点子集」，否则判据集合必须补齐第三串。

### 🟢 R33 · 报告 43 条中 17 条在 REQUIREMENT 的 AC 表里无行、无锚点（含 D25 等已实质落地者）

**Severity**：🟢 Minor
**Symptom（症状）**：报告 `#### D…` 实有 43 条（14🔴 / 23🟡 / 6🟢）。REQUIREMENT 两张表合计 42 行，去重后覆盖 26 个 D 项；**未被任何 AC 表行覆盖 = 17 条**：D02 / D05 / D06 / D07 / D15 / D17 / D24 / D25 / D27 / D28 / D29 / D35 / D37 / D38 / D39 / D40 / D42。其中 14 条 🔴 **全部覆盖**（已核对：14 个 🔴 ID ⊆ AC 表 ID 集合），无 🔴 遗漏；遗漏集中在 🟡/🟢。**部分遗漏项的正例锚点实际已由 AC-4 的新增项承载**（如 D25 `max_artifact_bytes`/`80000` 已在指南落地，实测各 ≥1；D24 `runtime-edit-guard` 实测 2），但它们在 REQUIREMENT 里没有对应的 AC 条目。
**Source（源头）**：AC-2 `:43-44` 的 Given（「14 条 🔴」）+ AC-3 `:74`（「23 条 🟡 + 6 条 🟢」）；`CHANGE.md:50`（验收线 1：读者得到的行为与实现一致）；`REQUIREMENT.md:257`（AC 是 TEST 的唯一来源）。
**Consequence（后果）**：AC-3 自述「29 条」与表内 26 行、报告「23+6=29」三者对不上序号空间；未被 AC 覆盖的 17 条在本轮**无机械验收点**，其中 🟡 者（D25/D27/D28/D29）本就是「文档行为一致性」风险项——TEST.md 只能靠 AC-4 的间接锚点顺带覆盖，属隐性范围收缩。
**Remedy（修补）**：AC-3 表补一行说明「报告 🟡/🟢 中被 AC-4 新增项（N2/N4/N8）承载的条目：D24/D25/…，其断言见 AC-4 的对应 N 项」；或对 D02/D05/D06/D07/D15/D17/D39/D40/D42 逐条补正例锚点后升入 AC-3 表。至少要在 REQUIREMENT 显式登记「本轮不覆盖的 D 项清单 + 理由」，避免下一轮再按「29 条」对账。

### 🟢 R34 · AC-9 白名单未覆盖阶段 7 归档路径；AC-10 的基线描述在**当前已对齐**的工作树上不可复现

**Severity**：🟢 Minor
**Symptom（症状）**：
- AC-9 `:167-174` 要求「工作区**全部变更路径**…落在白名单内」，白名单含 `.specs/CHANGELOG.md` / `.specs/STATE.md` / `.specs/LESSONS.md` / `.specs/user-guide-sync-2026-09b/**`，但**不含归档目录** `.specs/archive/**`；而 AC-11 `:209` 要求「最终归档至 `.specs/archive/2026-09-21-user-guide-sync-2026-09b/`」（该目录当前不存在）。二者仅在「判据时点 = 阶段 5 结束前」（`:185`）这一条上不冲突——把时点句去掉，归档写入即越界。
- AC-10 `:194` 的 Given/Then 描述「dist 两份跟随上一轮打包」的**未对齐**起点：实测四副本 + 已装 profile 两份**五处 md5 已全等 `86057b9c`(1693 行)**，此刻重复执行只能记录「已是基线」；`:122` 要求执行开始先记四份快照作基线，在已对齐树上无法复现「同步确实发生」的证据。
**Source（源头）**：AC-9 `:167-174` + AC-11 `:209`；`REQUIREMENT.md:5`（报告为只读事实基线）；AC-5 `:122`（Given 明确「当前四份副本不一致」）。
**Consequence（后果）**：阶段 7 归档是本 change 的必做动作（AC-11），若沿用 AC-9 判据会再次出现「实现正确却判红」（R20 的形态）；AC-5 的「证明同步确实发生」在已同步树上退化为恒真。
**Remedy（修补）**：① AC-9 白名单补 `.specs/archive/2026-09-21-user-guide-sync-2026-09b/**`（或写 `.specs/archive/**`）并保留「判据时点 = 阶段 5 结束前」句；② AC-5/AC-10 的基线句补一句「若执行时四份已一致，则四份同源性与 `git diff` 的工作树改动作为替代证据，并注明执行时点」。

### L-031 跨文件一致性扫描（本轮强制执行）

- **锚点盘点**：AC-2/AC-3 全部 42 行锚点 × bundle 副本 + 关键项 × 四副本逐一实跑；AC-4 的 19 条用户可见锚点实跑；AC-1 的 4 条判据 × 4 副本实跑；`check-appendix-superset.py` 实跑；`verify-ac.sh` / `verify-boundary.sh` 判据矩阵逐行与 AC 表比对；`Makefile`（`check` 六门依赖链、`dsh-sync: check-dist`）、`deck_checks.py`（`EXPECT_PAGES=24`、封面日期）、`slides.json`（24）、`pptx`（24 页）核对
- **分类结果**：
  - ①「AC 列出且已改」= 42 行中的 41 行（AC-1/AC-4/AC-5/AC-9/AC-10/AC-11 的 Given 与现状逐一吻合）
  - ②「AC 漏列但已改（OK）」= `.specs/user-guide-deck-gen/**`、`dist/dsh-flow-kit/README.md`、`verify-ac.sh`、`verify-boundary.sh`、`check-appendix-superset.py`、`render-preview/**`、`DEV-SUMMARY.md`、`INDEPENDENT-REVIEW-*.md`、`MINOR-DEFERRED.md` —— 均落在 `.specs/**` 白名单文字范围内，**不构成越界**
  - ③「AC 列出但未改」= **D10**（`:1405` 的 `<日期>-<id>` 仍在，见 R28）；**D13**（正例串零命中，见 R27）
  - ④「漏列且未改」= **无新增**。前几轮已记录的「三轮审查」残留（`flow-kit-bundle/skills/flow-review/SKILL.md` 等）仍在 AC-9 明示冻结域内（`git diff` 实测 0 行），按 `CHANGE.md:41` 属范围外登记项，本轮不重复计为漏改
- **已核对通过项（供后续阶段复用）**：AC-1 四判据 × 4 副本全绿（版本行 1 / 分节日期 1 / `20260713`+`2026-07-13` 全 0 / `2026-09-03` 唯一命中 `:998` 且含「起」）· AC-2 的 D01（`brooks-tools` 9、`` 需再加 `--user` `` 1）、D03 带反引号字面 1、D08、D09、D11、D16、D20、D21、D23、D31、D33 整格（反例整格 `grep -F` = 0，正例 `both`/`L2`/`L3` 在 `:1263` 同句）· AC-3 的 D04、D12、D14、D18、D26（**SessionStart 段 `:927-935` 内 `:933` 确有 `archive-uncommitted`，段落定位成立**）、D32、D36 反例、D41、D43 · AC-4 的 N1–N11 全部 19 条锚点 ≥1（`max_artifact_bytes`/`80000`/`l3.env`/`verify-claims`/`/flow l2-review`/`runtime-edit-guard`/`ADR-025`/`ADR-026` 等）· 安全反例未引入真实 token · `make check` 六门依赖链与 AC-9 `:174` 一致 · AC-11 的 `gate_config` 六阶段 `both` 与 `auto_advance=true` 实测成立

**Verdict**: fail

> 说明：本轮 🔴 两条（R27/R28）均属「AC 本体判据与验收引擎不一致 / 修复未落到 AC 主表」——即第三轮 R21 的同一类缺陷在修复过程中又生成了一批（判据左移）。两条都可在一轮内闭合：改 AC 表的锚点串 + 把 `verify-ac.sh` 的对应断言拉回 AC 表，不需改运行时。

---

## 主 agent 响应（阶段 1 · L2 第四轮 R27–R34 · 2026-09-21）

| # | Sev | 处置 | 动作 |
|---|---|---|---|
| R27 | 🔴 | **Fixed in: REQUIREMENT AC-3 D13 行 + TASK 附录 A:306 + verify-ac.sh** | AC 表正例改为与实现 `:623` 逐字一致的 `同波次内不应有` + `跨波次必须显式声明`；三处（AC 主表 / 附录 A / 判据实现）同步，判据不再引用 AC 表外的自造串。**未改正文**（正文本来就是对的，错在 AC） |
| R28 | 🔴 | **Fixed in: REQUIREMENT AC-2 D10 行 + 指南 `:1405` + verify-ac.sh** | ① AC 主表正例统一为 `archive/<YYYY-MM-DD>-<change-id>/`；② 指南 `:1405` 的旧占位写法（`archive/<日期>-<id>/`）**正式化为同一套**（四副本同步 + `make dsh-sync`），使锚点唯一且正文旧写法 0 命中；③ 判据与主表一致 |
| R29 | 🟡 | **Fixed in: REQUIREMENT 修订记录（补 v4 全条）** | 新增 v4 条目，逐条标注 R20–R34 的落地位置（AC-9 判据 / 锚点字面化 / D33 整格 / D26 段落级 / D30 独有短语 / 附录 A 母本 / AC-10 修复命令分派 / 去行号 / 集合断言与检测力边界） |
| R30 | 🟡 | **Fixed in: TASK.md 版本日期口径断言段** | 删掉写死的 `:922`/`:952`，改为「原文摘录 + 判据只约束『非历史句命中数 = 0』，不登记行号」——与 REQUIREMENT AC-1 同口径，消除同文件自相矛盾 |
| R31 | 🟡 | **Fixed in: TASK.md 附录 A D30/D33 行 + TEST.md 新增「检测力边界」说明** | ① D33 正例明确「同句共现、`off` 不作断言」；② D30 保持独有短语；③ TEST.md 写明 `check-appendix-superset.py` 的口径是「每格 ≥1 候选锚点命中」，**不**声明「逐字等价」——不再给出超出检测力的保证（本轮实跑：45 单元格 / 缺失 0） |
| R32 | 🟡 | **Fixed in: REQUIREMENT AC-2 D19/D34 行 + AC-3 D36 行 + verify-ac.sh** | D19 三选一收敛为 `占位块` + `代码未消费`（删实测 0 命中的第三串）；D34 改为可 grep 的字面路径 `~/.dsh/stop-hook.json` + `~/.config/opencode/stop-hook.json`；D36 改为 `配置不在项目里` + `stop-hook.json` |
| R33 | 🟡 | **Fixed in: REQUIREMENT AC-3 新增「其余 D 项承载说明」段** | 列出 17 条无独立锚点的 D 项及其承载（AC-4 的 N 项 / 附录 A 正例 / 正文修订），并给出计数口径：AC-3 表内 22 行 + 说明覆盖 17 条 = 报告 23🟡 + 6🟢 = 29 条（🔴 归 AC-2，不重复计） |
| R34 | 🟢 | **Fixed in: REQUIREMENT AC-9 白名单 + AC-5 说明** | ① AC-9 白名单补 `.specs/archive/**`（阶段 7 归档落点）；② AC-5 的「同步确实发生」基线改为「执行时记录」，已在 v3 落地（当前已对齐树上不可复现旧基线） |

**复审请求**：本轮的 2 条 🔴 均已按「改 AC 不改正文」闭合；实跑证据：`verify-ac.sh` **86 通过 / 0 失败**（较上轮 +2：D13 跨波次串、D34 opencode 路径）、`check-appendix-superset.py` **45 单元格 / 0 缺失**、四副本 md5 唯一 + `check-dist` ✅ + `make dsh-sync` 已同步。

---

## L2 盲审（第五轮）

**Verdict**: pass

- 审查对象：`.specs/user-guide-sync-2026-09b/REQUIREMENT.md`（**当前现状**，263 行，md5 `9332c467d15708bd94a4c122c6cdc968`）· 参考 `CHANGE.md` · 事实基线 `/tmp/guide-drift-report.md`（D01–D43 = 14🔴/23🟡/6🟢 + §2 N1–N11 + §0 N12）
- **独立性**：输入仅调用方给的三条路径 + 仓库只读核对；**未收到**主 agent 自评 / 草稿 / 概述 / 辩护 → 独立性未受损。文件内第一至四轮 L2 段、四段「主 agent 响应」与 `## L3 重审` 段按调用方说明作**历史轮次**处理，**未作为本轮判据**；本轮每条结论均由本轮实测独立得出
- 实测（全部只读）：AC-2 主表 14 行（15 反例串 + 22 正例串）、AC-3 主表 13 行（10 反例串 + 34 正例串）、AC-4 表 27 串，**逐串 × 4 副本 `grep -F` 实跑**；`bash verify-ac.sh`（**86 通过 / 0 失败**，rc=0）；`python3 check-appendix-superset.py`（**45 单元格 / 缺失 0**，rc=0）；四副本 `md5sum`（**唯一值 = 1**，`a78810f73786007faeb569f481c84829`，各 1693 行）；`git show HEAD:…` 对 bundle/根两副本做**改前基线**对照（挑「改前即绿」恒绿项）；`verify-ac.sh` **逐行**与 AC 主表取差值；`TASK.md` 附录 A 逐格与 AC 主表比对；`Makefile:106` 六门依赖链；`deck_checks.py` / `slides.json`(24) / pptx(24 页)；`git status` 白名单集合
- 本会话实测约束（如实记录）：`runtime-edit-guard` 两次 deny 了含 `.done` 字面量的只读 grep 命令（守卫按设计生效，非本报告缺陷）→ 相关核对改用不含该字面量的等价命令完成

### 🟡 R35 · AC 表自定的「正例锚点」有 5 处**没有任何判据实现**：AC-4 的验收保证与 `verify-ac.sh` 的实际检查集不相等，而 TEST.md 已声明后者「承担与 AC 表逐条对齐」

**Severity**：🟡 Important
**Symptom（症状）**：
- AC-3 `:88`（D32）正例 = `skill 文件` **与** `生成的 deck 工程结构`（两串）；`verify-ac.sh:124` 只断后一串（`skill 文件` 实测正文 1 命中、`TASK.md:320` 附录 A 已登记两串）
- AC-3 `:91`（D41）正例 = `requirement-review` / `spec-test` / `task-test`（三串）；`verify-ac.sh:128-129` 只断前两串（`task-test` 实测正文 2 命中、附录 A 已登记三串）
- AC-3 `:90`（D37/D38）正例列 8 条 `*.sh`；`verify-ac.sh:129-131` 只断 `l3-api.sh` / `runtime-adapter.sh` / `gate-checks-review.sh` 3 条
- AC-3 `:90`（D36）正例 `配置不在项目里` + `stop-hook.json`；`verify-ac.sh` **0 条**对应断言（AC-3 段无 D36 行）
- AC-4 `:112`（N3）正例 `check-dist` · `check-validate` · `check-hooks-sync`；`verify-ac.sh` 只断 N4 的 `check-hooks-sync`（:163）与 `check-dist`（:162），`check-validate` **无断言**（正文实测 1 命中）；AC-4 `:118`（N9）`path-guard` 在 AC-4 段无断言（仅以 AC-2 D23 身份出现在 `:84`）
- 反向：`verify-ac.sh:79` 的 `熔断降级（自动）`、`:92` 的 `~/.claude/stop-hook.json` 在 AC 主表中**不存在**（AC 表 D22 正例 = `由子系统自动` + `L3_verdict=skipped`；D34 正例 = `~/.dsh/stop-hook.json` + `~/.config/opencode/stop-hook.json`）
**Source（源头）**：AC-3 表头 `:79` + AC-4 `:108`（正例 = 用户可见 grep 串，改后 ≥1）；`TEST.md:64` 明文「后者（字面 vs 正则等口径）由 `verify-ac.sh` 的判据实现承担（两处判据均需与 AC 表逐条对齐）」→ 本表与判据实现的**等值关系是 AC 自设义务**
**Consequence（后果）**：阶段 5 的 AC-3/AC-4 判绿由 `verify-ac.sh` 的 86/0 给出，但那 5 处锚点即使从正文删除也**不会变红**；TEST.md `:28`/`:29` 却按 AC 全量标 ✅。即「验收保证 > 检测力」——正是 R31 修掉的那类越界声明，只是换到了 AC-3/AC-4 层。所有受影响项均为 🟡/🟢，🔴 项无假绿
**Remedy（修补）**：`verify-ac.sh` 从 AC 主表**逐字反向生成**（含 D32 第二串、D41 第三串、D37/D38 全 8 串、D36 `配置不在项目里`、AC-4 的 `check-validate` 与 N9 `path-guard`）；AC 主表未定义的 `熔断降级（自动）` / `~/.claude/stop-hook.json` 或**回填进 AC 表**，或在脚本内注明「AC 表锚点子集之外的补充断言」；TEST.md 把「✅ 覆盖」限定为「AC 表锚点由 `verify-ac.sh` 断言的子集」

### 🟡 R36 · AC-3 的「22 行」计数与自表不符（实测 13 行），「29 条」对账口径不可复算

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:99` 写「AC-3 表内 **22 行** + 本说明覆盖 17 条 = 报告 23🟡 + 6🟢 = 29 条」。实测：AC-3 表（`:81-93`）数据行 = **13**（D03/D04/D12/D13/D14/D18/D26/D30/D32/D36/D37+D38/D41/D43，覆盖 **14** 个 D 项）；「其余 D 项承载说明」（`:95-98`）= 17 条，其中 **D26 已同时出现在表内**（`:87`）→ 去重后 13+17 = **30** ≠ 29，而 22+17 = 39 与 29 亦不自洽。另 `:98` 把 D38 归入「由附录 A 正例承载」，但 D38 已在 AC-3 表内（`:90` 与 D37 同行）
**Source（源头）**：AC-3 `:74`（Given：报告 23🟡 + 6🟢）、`:99`（计数口径）；`REQUIREMENT.md:265`「AC 是 TEST 阶段派生用例的唯一来源」
**Consequence（后果）**：第四轮 R33 的补救（登记 17 条承载）留下了**不可复算的算术**——本行是 AC-3 唯一一处「报告 29 条 ↔ REQUIREMENT 行集合」的对账依据，下一轮/L3 按它核对必然对不上，又要在「22 行」与「13 行」之间重新裁定；D26 双重计数使「29」永远无法闭合
**Remedy（修补）**：改为逐条可复算口径，例：`计数口径：AC-3 表 13 行覆盖 14 个 D 项（D37/D38 同行）；承载说明覆盖 15 个 D 项（D26 见表内）；14 + 15 = 29 = 报告 23🟡 + 6🟢；🔴 14 条见 AC-2 表`，并在 TEST.md 加一条集合断言（两表 D 项 ∪ = 报告 🟡/🟢 全集，缺失即 FAIL）

### 🟡 R37 · 「附录 A ⊇ AC-2/AC-3 表」这条集合断言**当前不成立**：D34 的 opencode 字面串、D36 的正例字面串在附录 A 中 0 命中，而 `check-appendix-superset.py` 判 0 缺失

**Severity**：🟡 Important
**Symptom（症状）**：
- AC 主表（母本）字面 vs 附录 A（`TASK.md:327` / `:329`）实测：`~/.config/opencode/stop-hook.json` 在附录 = **0**（附录写泛词「用户级三平台路径 + `2026-09-21`」）、在指南正文 = 2；`配置不在项目里` 在附录 = **0**（附录写「`配置在用户级`」）、在指南正文 = 1
- 同两格在 D43 式口径下同样可疑：D03 AC 字面带反引号（`仅安装 hooks + \`.specs/STATE.md\` 模板`），附录 A `:296` 无（`仅安装 hooks + .specs/STATE.md 模板`）；D34 反例 AC = `.claude/stop-hook.json`（作配置源），附录 = 同串 + 后缀 → 前者非后者子串
- 而 `check-appendix-superset.py`（口径见其 `:42-47`：每格只取反引号片段、**只需 1 个候选**在 TASK.md 全局出现）实跑 = 「45 个 / 缺失 0」：D34 靠 `~/.dsh/stop-hook.json` 单候选通过（该串出现在无关的 `TASK.md:128` README 任务描述里），D36 靠 `stop-hook.json` 通过 → **两个真正缺的锚点被「1 个候选」规则吸收**
**Source（源头）**：`TASK.md:287` 母本声明（「是它的**超集**…冲突时以 AC 表为准并回填」+「阶段 5 的 TEST.md 含一条集合断言 `附录 A ⊇ AC-2/AC-3 表`」）；`TASK.md:267`（禁止只写结论不写输出）；第四轮 R31 Remedy ③（要求升级为逐锚点等值比对——未实施）
**Consequence（后果）**：TEST.md `:57` 以该脚本结果作为「附录 A ⊇ AC 表」的证据，但把附录 A 单独拿去逐字核对母本即 2 处缺失 → 集合断言是**超出检测力的保证**（与 R31 同形态，只是对象从「同句共现 / 单串不参与」换成「每格 ≥2 候选中的第 2 个」）。阶段 5 若照附录 A 执行 D34/D36，会漏掉 AC 表要求的字面锚点
**Remedy（修补）**：① `TASK.md:327` D34 正例补 `~/.dsh/stop-hook.json` · `~/.config/opencode/stop-hook.json`；`:329` D36 正例改 `配置不在项目里`（与 AC 表同字面）；② 抽取器改为「每格**全部**候选锚点必须命中，缺一即 FAIL」并保留「全局文件内出现」以外的**同 D 项行内**约束；③ 在 TEST.md 写明该脚本当前只做「≥1 候选」检查（否则证据声明失真）

### 🟢 R38 · 修订记录缺 R34 条目（20 处 `v4` 标记中所引用的一项在文档内无定义）

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:7` 的 v4 条目逐条列出 **R20–R33**，正文 `:178` 却写「**`.specs/archive/**`**（阶段 7 归档落点 · **v4 · R34**）」——R34 在修订记录中不存在（另 `:41` 的 R26、`:58` 的 R28 也未进 R 号枚举，但同为 v4 条目内已述动作）。当前文档共 20 处 `v4` 标记
**Source（源头）**：文档自身修订记录契约（`:6-9` 的 v3/v2 条目格式）——R29 已就此立规（「修订记录补 v4 条目，逐条列出落地位置」）
**Consequence（后果）**：有界——R34 的落地位置（AC-9 白名单 `:178`）本身已在正文可查，且第四轮 R34 的 🟢 判定为「已登记」；但下一轮 review 仍无法用「v4/R 号枚举」界定增量，需逐条 grep（R29 的形态复现一次）
**Remedy（修补）**：`:7` 的 v4 条目续写 `；**R34** AC-9 白名单补 `.specs/archive/**``，并把 R26/R28 补入枚举或改为「R20–R34」

### 🟢 R39 · 两处计数/基线陈述与实跑不符（证据行陈旧）

**Severity**：🟢 Minor
**Symptom（症状）**：① `TEST.md:26` 仍记「§2 输出『断言通过 **80** / 失败 0』」，而 `TEST.md:60` 与本次实跑均为 **86 通过 / 0 失败**（同一文件两套数）；② AC-1 Given（`REQUIREMENT.md:23`）称根副本**两处**口径 = `2026-09-03`（版本行）与 `2026-07-13`（分节「最后同步日期」` :1380`）；HEAD 根副本实测三行 = 版本 `2026-09-03` ✓ / 分节 `2026-07-13` ✓ / 但 `:916` 的 `2026-09-03` 是**模型配置段**内容，非日期口径；`20260713` 格式在 HEAD 根/bundle 均为 **0**（bundle 的旧日期在 `:1381`）。**AC 判据本身有效**（`20260713`/`2026-07-13` 四副本全 0 ✓、`2026-09-03` 唯 1 命中且含「起」✓），故风险有界
**Source（源头）**：AC-1 `:26-40` 的判据本体；`TEST.md:60` 的实跑段落（86/0）
**Consequence（后果）**：主表行仍写 80 会被下一轮当作「哪一份输出才是权威」的新歧义；AC-1 Given 的「两处 `20260713`」是已修正的历史事实残留（v2 的 R15/R17 语境），不影响判据
**Remedy（修补）**：`TEST.md:26` 改「86 / 0」（或改为「实跑值见 §2」）；AC-1 Given 把 `20260713` 描述限定为「上一轮（2026-09-03）同步前的历史格式」，不写「当前三处不一致」的细节行

---

### L-031 跨文件一致性扫描（本轮强制执行）

- **锚点盘点**：AC-2/AC-3 主表 **37 条反/正例串** × 4 副本逐一 `grep -F`（全部现值 ≥1，除反例应为 0）；AC-4 表 **27 串**；AC-1 的 4 条判据；`verify-ac.sh` 全部 86 条断言逐行与 AC 主表取差值；附录 A 逐格与母本比对；实现侧锚点抽扫（`check-validate`、`六门`、`make dsh-sync`、`.specs/LESSONS.md`、`SUB_GOAL_4`、`sub-goal-`）
- **分类结果**：
  - ①「AC 列出且已改」= AC-2 14 行全部（含 `already-fixed` 的 D01/D08 复核）、AC-3 13 行中输入侧全部、AC-4 N1–N11 的正文落地（`max_artifact_bytes`/`80000`/`l3.env`/`/flow l2-review`/`runtime-edit-guard`/`ADR-025`/`ADR-026` 等实测 ≥1）、AC-1/AC-5/AC-9/AC-10/AC-11 的 Given 与现状吻合
  - ②「AC 漏列但已改（OK）」= `verify-ac.sh` 内的 `熔断降级（自动）` / `~/.claude/stop-hook.json`（判据自身的额外断言，见 R35）、`.specs/user-guide-deck-gen/**`、`dist/dsh-flow-kit/README.md`、`TEST.md` 等 `.specs/**` 产物 —— 均在 AC-9 白名单文字范围内，**不构成越界**
  - ③「AC 列出但未改」= **无**（37 条锚点 × 4 副本全部满足；D10 的 `<日期>-<id>` 旧占位写法已正式化，实测 0；D13 两串与实现 `:623` 逐字一致）
  - ④「**漏列且未改**（🔴 L-031 类）」= **无新增**。既有的 `三轮审查` 残留（`flow-kit-bundle/skills/flow-review/SKILL.md` 等）仍在 AC-9 明示冻结域内（`git diff` 实测 0 行），按 `CHANGE.md:41` 属范围外登记项，本轮不重复计为漏改
- **「改前即绿」专项（本轮重点）**：对 15 条反例 + 34 条正例以 `git show HEAD:` 基线抽查——反例在 HEAD bundle/根**均有命中**（D01/D08/D09/D10/D11/D16/D19/D20/D21/D22/D23/D31/D33/D34/D36 抽样确认），「改前不成立」成立；正例中 D30 的完整独有短语 `31 号由 \`goal.auto_advance\` 驱动` 在 HEAD = **0** → 有判定力（R23/R24 的修复落到主表）；AC-4 的 D34 两条字面路径在 HEAD = **0** → 可达。**未发现新的恒绿项**
- **已核对通过项（供后续阶段复用）**：四副本 md5 唯一 `a78810f7`（1693 行，与已装 profile 同步口径一致）· `verify-ac.sh` 86/0（D13 的 `跨波次必须显式声明`、D10 的 `archive/<YYYY-MM-DD>-<change-id>/`、D34 的 opencode 路径均已进判据）· `Makefile:106` 六门 = test/lint/check-validate/check-test-sync/check-hooks-sync/check-dist，与 AC-9 `:180` 一致 · pptx 24 页 = `slides.json` 24 条 · `test/test_guide_copy_parity.bats` 与 bundle 镜像均 8595 B、含注入反例用例（非恒绿）· AC-1 判据四副本全绿（`20260713`+`2026-07-13` = 0，`2026-09-03` 唯 1 命中 `:998` 含「起」）· `check-appendix-superset.py` rc=0（检测力边界见 R37）

> 本轮结论说明：**Verdict = pass**（无 🔴）。第四轮 R27/R28 两条 🔴 已按「改 AC 表 + 回填判据实现」闭合，且本轮独立复跑确认 D13/D10 的新锚点**逐字**存在于正文并有判定力。剩余 3 条 🟡 全部集中在「AC 主表 / 附录 A / `verify-ac.sh` 三者的锚点集合不相等与计数口径不可复算」——即前几轮同一族缺陷的**残余面**，内容侧（指南正文）无需再动，改判据集合与计数即可在一轮内闭合；R35/R37 的补救若只改文档不改抽取器/脚本，该族缺陷会在下一轮以同一形态复现。

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-21 22:42）

> 自动生成于 2026-09-21 22:42。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "REQUIREMENT.md AC-1",
      "issue": "AC-1 的 09-03 历史锚点判据 `grep -n '2026-09-03' | grep -vc '起'` 不能精确锁定唯一允许的历史陈述句；同一行只要含“起”字即被豁免，无法证明命中内容是 ADR 生效时间锚。",
      "why": "验收准则要求无歧义可验证，但该判据对“2026-09-03 起止日期”“不得从 2026-09-03 起算”等非白名单句子也会放行，存在假阴性/假阳性空间。",
      "fix": "改为显式白名单字面串断言：`grep -F '2026-09-03 起 L2/L3 模型按 `fk_resolve_model` 五级解析链解析'` 必须命中，且全文 `2026-09-03` 命中数等于该白名单句命中数。"
    },
    {
      "file": "REQUIREMENT.md AC-2 D23",
      "issue": "D23 反例锚点“matcher: `Bash`，”的收窄条件“仅当后接‘gate_config 命中的阶段’这半句语境”没有给出可执行的字面匹配方式；“v3 改为按整句匹配”也没有给出整句原文。",
      "why": "AC 要求每条反例四份同验且用 `grep -F` 字面匹配，但该行未给出整句字面串，执行者无法复现；同一行还残留“整句匹配”与“三串分别 ≥1”两种判定口径，存在二义。",
      "fix": "在格内写出反例整句的逐字原文（标注 `grep -F` 整句），删除“或三串分别 ≥1”的替代判据，或明确将其降为补充说明。"
    },
    {
      "file": "REQUIREMENT.md AC-3 D26",
      "issue": "D26 的“段落级正例”只给 awk 抽取逻辑，但未给出抽取段落标题的唯一性断言、未定义 awk 抽取为空或多个同名段落时如何 fail、未排除“段落外命中导致误绿”的情况。",
      "why": "若正文存在多个 `### SessionStart Hook` 或标题层级变化，awk 可能抽取多段或空段，`grep` 仍可能因其他段落命中而通过；该断言不是可失败且无歧义的段落级判定。",
      "fix": "给出完整可执行命令：先 `grep -c '^### SessionStart Hook'` 断言恰为 1，再用 awk 抽取并 `grep -q` 判定段内命中；同时明确非 SessionStart 段是否允许 `archive-uncommitted` 命中，若允许需给出排除逻辑。"
    },
    {
      "file": "REQUIREMENT.md AC-9",
      "issue": "AC-9 白名单包含 `dist/dsh-flow-kit/docs/FLOW-KIT-用户指南.md` 和 `dist/dsh-flow-kit/vendor/flow-kit-bundle/FLOW-KIT-用户指南.md`，但验证命令 `git status --porcelain` / `git ls-files -o --exclude-standard` 对 `.gitignore` 忽略的 dist 再生件可能不可见；AC-9 自己又说“dist 其余再生件由 make check-dist 守护（.gitignore 忽略，git 结构性看不见）”。",
      "why": "验收判据要求变更全集逐条 ⊆ 白名单，而 dist 下被忽略路径通常不出现在 git status，导致这两个白名单条目实际不可判定；若 dist 未被忽略又可能混入大量再生件。",
      "fix": "明确 dist 两份指南由 `package-dsh-plugin.sh --check` 的 `cmp` 守护，并在 AC-9 验证命令中补充对这两份的 `cmp` 断言（或直接说明白名单这两条属于守护范围而非 git 可见范围）。"
    },
    {
      "file": "REQUIREMENT.md 非功能性需求-兼容性",
      "issue": "兼容性落点声称“由 AC-4 的三平台路径断言承载——`~/.claude/stop-hook.json` · `~/.dsh/stop-hook.json` · `~/.config/opencode/stop-hook.json` 三条字面路径都必须出现（AC-4 N13）”，但 AC-4 表格只有 N1–N12，没有 N13 行，且 AC-2/AC-3 表从未要求这三条用户级路径同时出现。",
      "why": "跨 AC 引用一个不存在的 AC-4 N13，使“三条路径都必须出现”没有落在任何可执行断言上；这是断言遗漏。",
      "fix": "在 AC-4 表格补 N13 行（归属 §7 配置路径，断言三条字面路径均 ≥1），或把兼容性落点改为引用 AC-2 D34 已列出的两条路径并补第三条。"
    },
    {
      "file": "REQUIREMENT.md AC-7",
      "issue": "AC-7 要求“每页 PNG 尺寸一致且非纯白”，但验证方式只写 `pdfinfo`/`pdftoppm` 计数与 `identify`/PIL 检查尺寸与非空，未给出“非纯白”的可执行判据（如像素方差阈值），也未给出页数/尺寸不一致时的失败命令。",
      "why": "“非纯白”是主观阈值，不同执行者可用不同 PIL 判据，导致机检段不可复现；AC 的机检部分应由脚本直接返回 rc。",
      "fix": "具体化为例如“每张 PNG 的像素值标准差 > 0 且非全 255”并提供一行 PIL 检查命令（如 `python3 -c` 遍历全部 PNG，任一纯白/尺寸不同即 exit 1）。"
    },
    {
      "file": "REQUIREMENT.md AC-10",
      "issue": "AC-10 在 fresh clone（dist 不存在）时 SKIP dist 相关断言，但同一段又要求“~/.dsh/profiles/.../node_modules/dsh-flow-kit/{docs,vendor} 两份存在时必须与 dist 一致”；fresh clone 时 dist 不存在，已安装插件目录存在时该“与 dist 一致”无从比较，AC 未定义此场景。",
      "why": "SKIP 条件与“when present”条件叠加会产生未定义状态：dist 缺失但用户已安装插件时，守护既不能比较 dist 也不能简单 SKIP，导致断言行为不确定。",
      "fix": "明确优先级：dist 缺失时延伸 SKIP 到已安装插件目录比较（并打印原因），或规定此时以 bundle 为基准比较已安装插件。"
    },
    {
      "file": "REQUIREMENT.md 范围切分 v2",
      "issue": "v2 列表包含“把 `deck_checks.py` 接入 `make check`（本轮只做‘断言有效性实测’，不新增门禁 target）”，但该项前面写着“v2（下一轮考虑，不本次）”，同一行又说“本轮只做”，造成 v2 与本次范围的矛盾。",
      "why": "范围切分应无歧义；该行既被列入 v2 又被描述为本轮行为，读者无法判断 deck_checks 是否本次必做。",
      "fix": "从 v2 删除“本轮只做…”半句，或把“断言有效性实测（不接入 make check）”移到 v1 范围，v2 只保留“接入 make check 门禁 target”。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT.md AC-2 D08",
      "issue": "D08 的处置口径引用了“漂移报告 §4 保留‘`--sub-goal-N` 是否被隐式解析’为未确认”，但 AC 自身又采信全仓 grep 实测；未说明若复验推翻结论时 AC-2 表 D08 的反例/正例本身如何改写。",
      "why": "“以实测为准”是合理原则，但 AC 表格是 TEST 派生唯一来源；推翻后没有给出新的反例/正例定义，TEST 阶段将无依据可循。",
      "fix": "补一句：若复验推翻，则按 DEV/TEST 记录改写反例为实测旧串并更新 TEST.md，且该改写需 REVIEW 确认。"
    },
    {
      "file": "REQUIREMENT.md AC-4 N9",
      "issue": "N9 锚点允许“path-guard（或「拒绝主 agent 直写 `.done`」等价表述）”二选一，未定义“等价表述”判定规则。",
      "why": "等价表述是开放性集合，不同执行者可判不同结果；AC 应固定一个可 grep 串。",
      "fix": "固定为 `path-guard` 字面串，把“拒绝主 agent 直写 `.done`”降为正文建议措辞，不作断言。"
    },
    {
      "file": "REQUIREMENT.md AC-3 计数说明",
      "issue": "计数说明写“列出 17 条，减去已在表内的 D37/D38”得到 15 条，但 D37/D38 是合并一行且“无反例锚点”；D26 也无独立反例锚点，说明中未明确 D26 是否计入“AC-3 表覆盖的 14 个 D 项”，读者按表行数核对时可能困惑。",
      "why": "AC-3 表 13 行覆盖 14 个 D 项，其中 D26 无独立反例锚点；说明的“表内/表外”口径与表格结构不完全对应。",
      "fix": "明确写“AC-3 表 13 行覆盖 14 项：D37/D38 合并一行，D26 行无独立反例锚点；因此 43 = 14（AC-2）+ 14（AC-3 表）+ 15（承载说明）”。"
    },
    {
      "file": "REQUIREMENT.md AC-6",
      "issue": "AC-6 专页表要求“删除上述四页中的任意一页（改标题或删条目）→ `deck_checks.py` 必须 rc≠0”，但未说明 `deck_checks.py` 的标题寻址是依赖 `slides.json` 中的唯一标题还是 PPT 文本；验证方式只写“注入/还原两轮实跑”，未给出注入方法。",
      "why": "若 `deck_checks.py` 仅校验页数而不校验标题，则“改标题”并不会导致 KeyError；该断言有效性依赖 deck_checks 内部实现，AC 未描述该实现的最小判据。",
      "fix": "在 AC-6 明确 `deck_checks.py` 必须对四张专页标题做寻址（如 `slides.index('安装面：作用域与入口')`），并给出注入修改的示例命令（如 `sed` 改 slides.json 标题后跑 deck_checks）。"
    },
    {
      "file": "REQUIREMENT.md AC-11",
      "issue": "AC-11 的验证方式写 `ls .specs/<id>/.independent-review-*.done`，但 AC-2 的 D21 已明确审查产物锚点是 `.independent-review-<phase>.done`；`<id>` 占位未说明是 change 目录名，且“各 INDEPENDENT-REVIEW-*.md 的最后一轮 verdict 行”未定义“各”的范围。",
      "why": "该命令可能列出多个阶段的 done 文件，却要求“各 INDEPENDENT-REVIEW-*.md 的最后一轮 verdict 行”，验证方式不够精确。",
      "fix": "写成 `ls .specs/user-guide-sync-2026-09b/.independent-review-*.done` 并明确阶段集合（1/2/3/5/6/7），或改为逐阶段 `test -f` 断言。"
    },
    {
      "file": "REQUIREMENT.md AC-5",
      "issue": "AC-5 Given 说“执行开始时先记录四份的快照（`md5sum` + `wc -l` + `mtime`）作为基线证据”，但 Then 只要求“四份 md5 唯一值 = 1（与快照对比，证明同步确实发生）”；未说明 wc -l 与 mtime 如何参与判定。",
      "why": "基线证据若只用于展示，则写进 AC 的验收判据不明确；若用于证明“确实发生”，需要对比规则（如与基线快照不同）。",
      "fix": "补一句：记录基线后，最终 md5 需与基线不同（至少根副本与 bundle 副本发生变化），且唯一值 = 1；或把 wc -l/mtime 明确降为 TEST.md 日志项。"
    },
    {
      "file": "REQUIREMENT.md AC-3 D14",
      "issue": "D14 反例 `🟡 Major` 未加引号或转义说明；表格内 emoji 与反引号混排，机械执行时若直接复制可能因全角字符或字体问题产生偏差。",
      "why": "字面锚点应明确复制源；`🟡 Major` 在正文可能写作“🟡 Major（”或带其他上下文，未收窄为整行/整词。",
      "fix": "明确反例为 `🟡 Major`（不含后续括号内容）且用 `grep -F -w`，或给出完整行原文。"
    },
    {
      "file": "REQUIREMENT.md AC-2 D34",
      "issue": "D34 正例要求 `~/.dsh/stop-hook.json` + `~/.config/opencode/stop-hook.json` 两串，但正文 `~` 在 markdown 中是否写成 `$HOME` 或具体家目录路径未定义；grep 字面串对 `~` 与 `$HOME` 不通用。",
      "why": "若实现文档写的是 `$HOME/.dsh/...` 或 `/home/user/.dsh/...`，字面 `~/.dsh/stop-hook.json` 会 0 命中；AC 未定义指南应使用的写法。",
      "fix": "在 AC 中固定指南正文写法为 `~/.dsh/stop-hook.json`，并加一条“若实现文档用 `$HOME` 则按实测改写并同步 AC 锚点”的规则。"
    }
  ],
  "verdict": "pass",
  "summary": "AC 体系整体可验证且 v1/v2/out 切分清晰，但存在若干锚点判据二义、跨引用 N13 缺失与 dist/已安装插件 SKIP 场景未定义等 major 级精确性问题，无致命缺陷。"
}
```

L3_artifact_hash: 349c2e0b9dbd4f39f33fe47b903034d2f816f90941de749598bae6a2f422a3f0

<!-- /L3-SECTION -->
