# TEST — health-fix-2026-09b 测试报告（阶段 5 · 5-test）

> 判据正文形态见 `.specs/health-fix-2026-09b/TASK.md` 各 task 的 `<verify>` 段（**唯一权威副本**）；
> 本文只记录「**实跑过的证据 + 判定**」，不复制判据源码。
> 运行环境：Linux（`/usr/bin/{bash,git,jq,node,npm,npx,shellcheck,iconv,tar,gzip}`）· 仓库根 = `<repo>`（本机绝对路径按 L-129 去形，不落真实账号路径）·
> 变更锚点 `.specs/health-fix-2026-09b/.change-base` = `534e3e842fc900045f39492badc66eabe3ffd4c4`。
> 实跑时间：2026-09-24（阶段 5 第 1–3 轮；第 2/3 轮补强见 §1.7 与各节的「L3 第 N 轮响应」标注）。
> **第 5 次执行（REPRO4 重入复跑）= 2026-09-24 16:56–17:22**（HEAD = `ddea327`；TD-053/TD-059 闭合 + 两条判据修复后重入：判据面 **12 → 14**、七项门禁 7/7、阶段门沙箱**六态全绿**，结论见 §0 第 6 行、原始证据内嵌见 §附录 D）。
> **第 11 次执行（REPRO10 · 2026-09-27 · HEAD = `551e846`）= 当前权威全脸**：判据面 **25/25 rc=0**、七项门禁 **7/7 rc=0**、bats **1064**（= 1061 + `T-FIX-13` 3 例）、NFR **max 3.666 s / 均值 3.609 s = 预算 72.2%**、阶段门沙箱六态全绿 ⇒ **阶段 5 判定 ✅ 通过 —— 该「通过」仅指判据面 + 门禁面的执行结论**；**AC 面另计：7 项 ✅ 通过 + AC-8 ⚠️ 有条件通过（跨 OS 实机面未验证 · `TD-055` 仍开放）⇒ 不得读作 8/8 AC 全部通过**（L3 第 15 轮 major 4 收口）；判据面 24 → 25（纳入 `T-FIX-13` 的 bundle 形态三态反向控制）。其前序两次执行：**第 9 次执行（REPRO8 · `bf3763f`）判定 ❌**（唯一红面 = NFR 均值 11.078 s = 预算 221.6% ⇒ `TD-077` + `T-FIX-12`）、**第 10 次执行（REPRO9 · `280ffdc`）24 条全绿但证据面早于 `T-FIX-13` ⇒ 中间态**。三次执行的原始回执 = `PHASE5-RECEIPTS.md` **§R / §S / §T**；本报告回执内嵌 §附录 **D-10 / D-11 / D-12**。
> **前序权威（第 8 次执行 · 第 2 轮 fix 循环后重验 · 2026-09-25 · HEAD = `26d5d7b`）留档**：判据面 **18/18 rc=0**、七项门禁 **7/7 rc=0**、bats **1029**（有效 1028）、阶段门沙箱六态全绿；该轮另有两条**判据/工具面**缺陷（`TD-066` = `T17` 对照夹具候选面全自排除 · `TD-067` = 抽取器未整行锚定）在复跑中暴露并当场订正，如实记录于 §1.7 与 §附录 **D-9**、发现表 #41/#42。
> **一键复算**（两条独立入口，均自包含、可重复、不触碰工作树）：
> ① `bash .specs/health-fix-2026-09b/reproduce-5-test.sh` —— 判据从 `TASK.md` 权威副本 **awk 原样抽取**（不做任何修正）后逐条实跑并记 rc，随后跑**七项门禁**（含 [F] 阶段门沙箱复现）；**第 8 次执行起判据面 = 18 条**（第 5 次执行起 14 条 = 原 12 条 + `T-FIX-01`/`T-FIX-02`；第 7 次执行 17 条 = +`T-FIX-03`/`T-FIX-04`/`T-FIX-05`；第 8 次执行 18 条 = +`T-FIX-06`）；支持 `--criteria-only` / `--gates-only` / `--only T19,T27`；逐条原始输出保存在 `${TMPDIR:-/tmp}/fk-repro-*`（可用 `FK_REPRO_LOG_DIR` 指定），其中 `v_<Tnn>.sh` 与 `TASK.md` 的判据块**逐字节同源**（可直接 `diff`）。
> ② `bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh` —— 沙箱复现**阶段门拦截 `git commit`**（UAT ③ 的可构造等价物；**六态 A/B/B2/B3/B4/C**，见 §1.2 ③）。
> **原始输出存档**：`.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md` —— **§0 是最小复算证据（保证落在 L3 补充产物预算 3000 B 内，见 L-151 与 L3 第 3 轮 major 1）** · §A 12 条判据 rc + 原始 stdout · §B 六项门禁回执（含完整 TAP）· §C 三条零引用判据 · §D 判据修正台账 · §E 性能测量环境 · §F 973→976 归因 · §G 复算入口与失败语义 · §H 阶段门沙箱复现原文（第 [F] 项 · **已按第 5 次执行刷新为闭合六态**）· §I 处置后复算全绿回执（rc=0，含 T19 回写后的 36 行抽取）· **§J 第 5 次执行（REPRO4）原始回执（14 条判据 + 7 项门禁 + 权威输出原文 · 2026-09-24）** · **§K/§L 判据修正前原文与逐条结论** · **§M 第 6 次执行（终版）原始回执** · **§N 第 7 次执行（REPRO5 · fix 循环后重验）原始回执** · **§O 第 7 次执行权威行与六态** · **§P 第 8 次执行（REPRO7 · 第 2 轮 fix 循环后重验 · 18 条判据 + 7 项门禁）原始回执（2026-09-25）**。

## 0. 本次测试范围声明（5 轮金字塔 + 第 5 次执行重入复跑 + 第 6 次执行终版复跑 + 第 7 次执行 fix 循环后重验 + 第 8 次执行 第 2 轮 fix 循环后重验 + 第 9 次执行（NFR ❌） + 第 10 次执行（`T-FIX-12` 收口） + 第 11 次执行（`T-FIX-13` 收口 · 当前权威））

产品类型裁剪依据：`flow-kit-bundle/flow-kit/reference/test-pyramid.md` 的适用矩阵 —— 本仓是**纯 Bash/Markdown 分发件 + git hook/安装器**（CLI 工具形态，无前端、无服务端、无数据库），故按「CLI 工具 / 内部工具」两行取并集裁剪。

| 轮次 | 状态 | 本次范围 | 跳过/裁剪理由 |
|---|---|---|---|
| 第 1 轮 · 功能 | ✅ 必跑（全跑） | AC-1..AC-8 全覆盖；bats 全量 976 用例；change 期判据 19 条；双态注入 | — |
| 第 2 轮 · 性能 | ⚠️ 部分 | NFR 明文预算的**全部三条**：`check-path-privacy` ≤5s、`check-gate-sync` 秒级、新增 `check-nfr-portability` 耗时 | 无前端（Lighthouse N/A）、无服务端接口与 DB（k6/locust p95/p99、N+1 N/A） |
| 第 3 轮 · 安全 | ⚠️ 受限（实现面未验证） | 依赖面（无 lockfile ⇒ audit 不可用，量化替代）、秘钥扫描（模式面 + 自研门禁）、SAST（shellcheck + 构造扫描 + eval 面）、OWASP Top 10 逐项 | 无容器镜像（trivy N/A）；`semgrep`/`gitleaks`/`trufflehog` 本机未安装（工具缺失面已明示，见 §3.5）；**独立安全工具面全缺失 ⇒ 第 3 轮安全实现面 = 未验证（无独立安全工具），不构成 AC 通过面证据**；该项以 **`Tech-debt: TD-056`（本 change 安全验收的未覆盖项 · v2 = 安装 `gitleaks` + `semgrep` 并接线 `make security-scan`）** 登记，替代面证据**不计入 AC 通过面**（L3 第 7 轮 major 3 / L2 R3 + 第 8 轮 major 3 响应） |
| 第 4 轮 · 兼容 | 静态判据通过 / ⚠️ macOS 实机未验证 | bash 3.2（macOS）/bash 4+ 语法与 GNU-only 构造（**变更集口径**，静态判据 `make check-nfr-portability`）、locale/编码 4 态矩阵、六镜像 hook 同步、test 双源一致 | 4.1 跨浏览器 / 4.2 视口 N/A（无 UI）；4.3 数据迁移 N/A（无 schema）；**实机面**：无 macOS runner（L3 第 3 轮 minor ④ ⇒ 不得据此判 AC-8 的跨 OS 面为「已验证」，见 **`Tech-debt: TD-055`** 与 §4.4 的 ⚠️ 残余行） |
| 第 5 轮 · 可观测 | ⚠️ 部分 | 门禁自证行、失败归因 `file:line`、日志不含凭证值/PII | 5.2 指标与链路追踪 N/A（无长驻进程/无服务端）；5.3 无外部告警通道（明确不在范围） |
| **第 5 次执行** · REPRO4 重入复跑（2026-09-24 16:56–17:22 · HEAD `ddea327`） | ✅ **全跑（判据 14/14 rc=0 · 门禁 7/7 rc=0 · 脚本总 rc=0）** · ⚠️ **AC-8 = 有条件通过（仅静态面；跨 OS 实机面未验证）** · **判据版本 = 修正前**（`T-FIX-01`/`T-FIX-02` 已修，`T27`/`T29` 仍为旧地板 `-ge 973`；修正后地板的 T27/T29 复跑见 §D-4，**修正后判据集的整轮全绿 = 第 6 次执行**） | 阶段 4 的两个 fix 交付后重入（`T-FIX-01` = `5ee4ebc` / `T-FIX-02` = `6cff7a2` ⇒ **TD-053 / TD-059 闭合**）：判据面 **12 → 14**（新增两条 fix 判据）逐条 awk 原样抽取实跑；七项门禁全跑；**bats 全量 1012（有效 1011）**；阶段门沙箱 **六态全绿**（对照 0 可提交 · A rc=2 且 HEAD 不变 · B rc=0 且 commit 真生效 · **B2/B3/B4 一律 rc=2** · C rc=0）。原始证据内嵌于 §附录 D | 未覆盖面与第 4 轮相同，**本轮未新增覆盖缺口**：**macOS 真机 = TD-055**（仅静态代理判据 `make check-nfr-portability`；`TD-055` 仍开放）；无 `kcov`/`bashcov` 行覆盖率；无 CI（本机门禁） |

| **第 6 次执行** · 终版复跑（2026-09-24 18:26:52 → 18:52:27 · HEAD `ddea327`） | ✅ **全跑（判据 14/14 rc=0 · 门禁 7/7 rc=0 · `R4D_RC=0`）** · ⚠️ **AC-8 = 有条件通过（仅静态面；跨 OS 实机面未验证）** · **判据版本 = 修正后（`-ge 1009`）+ 源面冻结 ⇒ 本轮是全报告唯一「修正后判据集整轮全绿」的执行** | **源面冻结后**的终版口径：主 agent 的 `G-T04-1`/`G-T04-2` 前置修复（`l3-prompt.sh` 两处纯文案 · `test_l3_review_defects_2026_09.bats` 的 `B11-R6` 内六条静态断言 · `sync-hooks.sh` 六副本 · dist 重建）+ 判据地板订正（`T27`/`T29` `-ge 973` → `-ge 1009`）均落树 ⇒ 整轮 14 条判据 + 7 项门禁重跑：bats **1012**（有效 1011）· NFR 均值 **2.937 s = 预算 58.7%** · 阶段门六态全绿。原始回执内嵌 §附录 **D-7**（处置事实 §D-6 · 完整原文 `PHASE5-RECEIPTS.md` **§M**） | 与第 5 次执行同口径，**未新增覆盖缺口**：**macOS 真机 = `TD-055`**（仍开放）· 无 `kcov`/`bashcov` · 无 CI。另有中间轮 r4c（18:09:29 → 18:25:42）**rc=1**，根因 = **源面在飞行中被改**致 `check-dist` 陈旧（**非判据问题**，已修复并冻结）—— 如实内嵌 §附录 **D-5**；**执行时 HEAD = `ddea327` + `G-T04` 三文件的未提交工作树改动**（该批改动随后提交为 **`f446617`**，与其内容逐字节一致 · 见 §D-6） |

| **第 7 次执行** · fix 循环后重验（2026-09-25 00:26 → · HEAD `ee29a6d`） | ✅ **全跑（判据 17/17 rc=0 · 门禁 7/7 rc=0 · `REPRO5_RC=0`）** · ⚠️ **AC-8 = 有条件通过（仅静态面；跨 OS 实机面未验证 · `TD-055` 仍开放）** · **判据面 14 → 17**（纳入 `T-FIX-03` / `T-FIX-04` / `T-FIX-05` 三条 fix 判据） | 阶段 6 审查 `verdict=fail`（2 🔴 F1/F2 + 6 🟡）⇒ 用户裁决回退 4-dev 执行 fix 循环：`T-FIX-03` = `6e39cfb`（隐私门禁 fail-open 收敛 F1~F5 · 392 → 548 行 · +11 双态用例）· `T-FIX-04` = `521b21c`（`check-gate-sync` 缺对不得报全绿 F6/F7 · +2 用例）· `T-FIX-05` = `6e94d60`（`Makefile` NFR 判据正文去重 F8 · wrapper 配方 **89 → 13 行**（`awk` 范围法 · Δ−76）· 本提交 3 文件 **+35/−77 ⇒ 净 −42 行**）；**bats 全量 1025（有效 1024）**（基线演进 1012 → 1023 → 1025）· 三件 fix 均经主 agent 十项复核 + 活性重放（还原旧件各自恰转红）。原始回执内嵌 §附录 **D-8**（完整原文 `PHASE5-RECEIPTS.md` **§O**） | 未覆盖面与前几轮相同：**macOS 真机 = `TD-055`** · 无 `kcov`/`bashcov`（`TD-061`）· 无 CI；安全工具面仍 0/10（`TD-056`）；**本轮未新增覆盖缺口** |

| **第 8 次执行** · 第 2 轮 fix 循环后重验（2026-09-25 · HEAD `26d5d7b`） | ✅ **全跑（判据 18/18 rc=0 · 门禁 7/7 rc=0 · `REPRO7_RC=0`）** · ⚠️ **AC-8 = 有条件通过（仅静态面；跨 OS 实机面未验证 · `TD-055` 仍开放）** · **判据面 17 → 18**（纳入 `T-FIX-06` 判据） | 阶段 6 第 2 轮只读深审的 3 条 🟡 中 F-19（自排除后候选面归零仍报 ✅）与 F-20（临时件/工具不可用时机械故障被折成「0 命中」）经用户裁决**本 change 内修** ⇒ `T-FIX-06` = `421640a`（`check-path-privacy.sh`：`mktemp_checked` 收敛 + 失败面自证 + 「自排除后 0 实际扫描」fail-closed 早退 · 常设双态 bats **+4**）；F-18（`SCAN_SURFACE` 措辞把 index 面称「工作树」）按用户裁决 ② **仅订正措辞**（同一提交内落地）；**bats 全量 1029（有效 1028）**（基线演进 1012 → 1023 → 1025 → **1029**）。本轮复跑另暴露并订正两条**判据/工具面**缺陷（`TD-066` = `T17` 对照夹具候选面全自排除 · `TD-067` = 抽取器未整行锚定），两条均非生产件回归；原始回执内嵌 §附录 **D-9**（完整原文 `PHASE5-RECEIPTS.md` **§P**） | 未覆盖面与前几轮相同：**macOS 真机 = `TD-055`** · 无 `kcov`/`bashcov`（`TD-061`）· 无 CI；安全工具面仍 0/10（`TD-056`）；**本轮未新增覆盖缺口**（`TD-066`/`TD-067` 属判据与工具面自身缺陷，非产品缺口） |
| **第 9 次执行** · 阶段 6 第 3 轮裁决回退 4-dev 后重验（2026-09-25 · HEAD `bf3763f`） | ❌ **未通过（判据 23/23 rc=0 · 门禁 6/7 ❌）**：唯一红面 = **NFR 均值 11.078 s = 预算 221.6%**（`REQUIREMENT.md:495` ≤5 s · `TEST.md:265` 不做负载折算）；判据面 18 → 23（纳入 `T-FIX-07`…`T-FIX-11`） | 阶段 6 第 3 轮 4 🔴 + 13 🟡 经用户裁决「回退 4-dev（`T-FIX-07`…`T-FIX-10`）」后重验；**复算脚本自身缺陷当场暴露**：`[D]` 段 `emit_gate "NFR ≤5s ×5" 0 "…"` 把 rc **硬编码 0** ⇒ 221.6% 被打印成 ✅ 且总 rc=0（`TD-077`；主 agent 同批改为真断言：逐次解析 `real=`、打印 max/均值/预算百分比，超限即 `emit_gate … 1` ⇒ 退出 1；假值单测 10.741–11.469 ⇒ 🔴 / 3.011–3.146 ⇒ ✅ / 边界 5.001 ⇒ 🔴）；A/B 归因（`git show <rev>:…check-path-privacy.sh` 取旧版副本实测）：`7b624dc`（594 行）**3.191 s** → `20847e1`（`T-FIX-07` · 692 行）**10.662 s** → HEAD `bf3763f`（769 行）**10.778 s**（sys 2.120 → 11.186）；机制 = `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:586` 对每个候选调一次 `git grep --cached`（1594 次进程 · 微基准 4.28 ms/次 ≈ 6.8 s vs 一次全 index 扫描 0.023 s）⇒ `T-FIX-12`；原始回执 `PHASE5-RECEIPTS.md` **§R** | 未覆盖面同前四项（`TD-055` · `TD-061` · 无 CI · `TD-056`）；**本轮的缺口不在覆盖面而在判据运输面**（`TD-077`）—— 已由第 11 次执行的真断言覆盖 |
| **第 10 次执行** · `T-FIX-12`（NFR 批量化）后重验（2026-09-25 · HEAD `280ffdc`） | ✅ **全跑（判据 24/24 rc=0 · 门禁 7/7 rc=0）** · **中间态**（证据面早于 `T-FIX-13` ⇒ 不作权威判定面） | 判据面 23 → 24（纳入 `T-FIX-12`）· bats **1061** · **NFR = 3.813 / 3.656 / 3.730 / 3.752 / 3.630 s（max 3.813 · 均值 3.716 = 预算 74.3%）**（对照第 9 次的 221.6%）· 隐私门禁 候选 1601 / 扫描 1595 / 清单外 0 · 包校验 漏配 0 / 源缺失 0 · 六态 ✅；主 agent 独立计时 3.56 / 3.47 / 3.47 s（rc=0）并亲验「全 index 批量扫描与候选面（`git ls-files -z --` 无 pathspec）同集合、无扫面扩大」「rev 模式提前 `return 0` ⇒ 空磁盘缺失表无害」；原始回执 **§S** | 同前四项缺口；**该次全绿后用户裁定 `R4-M1`「本 change 内修」⇒ 证据面顺延至第 11 次** |
| **第 11 次执行** · `T-FIX-13`（R4-M1 fail-open）后重验（2026-09-27 · HEAD `551e846`）= **当前权威全脸** | ✅ **全跑（判据 25/25 rc=0 · 门禁 7/7 rc=0 · 脚本 rc=0）· 阶段 5 判定 ✅ 通过（执行面口径；AC 面 = 7 ✅ + AC-8 ⚠️ 有条件通过（仅静态面 · `TD-055`）⇒ **不得读作 8/8 AC 全通过**）** | 判据面 24 → 25（纳入 `T-FIX-13`，53 行：三态反向控制 + 具名 fail-closed 断言）· bats **1064**（+3 静态断言）· **NFR = 3.489 / 3.666 / 3.660 / 3.613 / 3.615 s（max 3.666 · 均值 3.609 = 预算 72.2%；`loadavg` 6.73 / 7.38 / 7.86）** · 隐私门禁 候选 1602 / 扫描 1596 / 清单外 0 · `make check` 21 ✅ / 0 ❌ · 包校验 漏配 0 / 源缺失 0 · 六态 ✅；本轮另有判据面缺陷 **`TD-081`**（`T-FIX-13` 初版 `<verify>` 夹具从未创建 `path-privacy-allowlist.txt` ⇒ 标注「两者皆在」的 L4/L5 实跑在缺陷态、与 L2d 对同一输入互斥 ⇒ **判据不可满足**；执行者与主 agent **各自独立发现**，主 agent 就地在 L3 后插入 **L3d** + 新增 **L4c** 把夹具切到真「两者皆在」态，L2/L3/L6 断言**一字未改**）；原始回执 **§T** | 未覆盖面同前四项：`TD-055`（macOS 真机）· `TD-061`（无行覆盖率）· 无 CI · `TD-056`（安全工具面 0/10）；**本轮未新增覆盖缺口**（`TD-081` 属判据面自身缺陷） |

> **判据修改前原文存档（L3 第 7 轮 major 2 / L2 R2 响应）**：6 条被回写判据（`T17` · `T19` · `T-FIX-01` · `T-FIX-02` · `T27` · `T29`）的**修改前 `<verify>` 原文 + 来源 commit + 逐条执行结论**见 `PHASE5-RECEIPTS.md` **§K**/**§L**；结论 = **无一条属「判据判红 ⇒ 改判据至绿」**。

> **无声明跳过**：上表每一条 ⚠️/❌ 都给出了范围与理由（R5.4）；本阶段**实际执行**的轮次 = 1（全）、2（预算面全）、3（可用工具面 + 逐项判定）、4（静态面全）、5（日志面全）。
> **第 3 轮安全实现面 = 未验证（无独立安全工具），不构成任何 AC 的通过证据**（L3 第 10 轮 major 3 收口）：`Tech-debt: TD-056` 按**阶段级未覆盖项**登记（不是「已用替代面覆盖」的普通债）；**安全工具面覆盖 = 0 / 10** —— §0 第 3 轮行 · §1.1 覆盖判定 · §3.4 结论 · §3.5 第 1 条**四处同口径**。

> **阶段门有效性（UAT ③ 面 · L3 第 4/5/6 轮响应 → 第 5 次执行闭合）**：**已通过（PASS · 第 5 次执行实测）** —— 健康层（无完成标记 ⇒ 拒绝）与**无效标记层**（口径相悖 B2 / 空标记 B3 / 缺 `L3_verdict` 键 B4）经沙箱实测**一律 rc=2 拒绝**，健康态 B 放行且 `git commit` 真生效 ⇒ **`Tech-debt: TD-059` 已闭合**（修复 = `T-FIX-02` · commit `6cff7a2` · ADR-029；`flow-kit-bundle/hooks/stop/lib/done-validation.sh` 由「标记**存在**」改为「标记**存在且有效**」，接 `fk_validate_done_marker … transition`）。
> **历史对照（不得抹除）**：第 1–4 次执行时本条判为 **未通过（FAIL）** —— 当时完成标记**存在但口径相反 / 残缺**时门禁 **rc=0 放行**（B2/B3），即 `Tech-debt: TD-059` 的缺口实证；用户据此回退 4-dev 产出 `T-FIX-02`，修复后重入本阶段。当时的 FAIL 判定与缺口实证保留在本节下方 §1.2 ③ 的历史行、§阶段 5 发现 #17 与 `PHASE5-RECEIPTS.md` §H 的原始 stdout 中。

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵（AC → 用例/判据 → 结果）

| AC | 主证据（本次实跑） | change 期判定 | 长期回归保护 |
|---|---|---|---|
| **AC-1** 安全守卫不再求值载荷（PC1） | 判据 `T05 <verify>` 原样抽取实跑 **rc=0**；静态面 `grep -rnE '\beval\b' --include='*.sh'` 全仓命中 **1** 且为**注释**（`flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh:50` 的修复说明）⇒ 活体 eval 面 = 0（**仅 change 期判据覆盖，无常设 bats 回归 · TD-053**） | ✅ | ✅ **常设 bats**（`test/test_runtime_edit_guard.bats` 9 用例 · `T-FIX-01` = `5ee4ebc` ⇒ **TD-053 已闭合**，第 5 次执行订正） |
| **AC-2** 缺 jq 时既有配置不被破坏（PC2） | 判据 `T06 <verify>` 原样抽取实跑 **rc=0**（缺 jq 分支：settings.json 未被截断为空 + permissions.allow 与既有 hook 存活（**非字节相等**——对照态安装器合法追加 hooks 会增大文件）+ fail-closed）；`test_install_coverage.bats`（17 用例）/ `test_install_dry_run.bats` 在 976 全量中通过 | ✅ | ✅ 常设 bats（`test_install_jq_guard.bats` 4 用例 · R5-6 落地 · 含变异反向控制腿） |
| **AC-3** 泄漏分支无法被误推（P1） | 判据 `T11` / `T17` / `T19` 实跑 **rc=0**（T19 = 隔离 bare remote 的**四形态 push 拦截 + 干净 ref 放行**端到端）；报文含 ref 与原因（`flow-kit-bundle/hooks/pre-push/pre-push.sh:30` 畸形 stdin fail-closed、`:49` 泄漏 ref 拒绝）；`test_archive_commit_gate.bats`（27 用例，本 change +16 行） | ✅ | ✅ 常设 bats（`test_archive_commit_gate.bats` 27 用例） |
| **AC-4** 门禁看得见「内容漂移」 | 判据 `T13`（修复后，见 §阶段 5 发现 #2）实跑 **rc=0**；`make check-gate-sync` rc=0（3/14 对一致 / 17 预设）；`test_check_gate_sync.bats`（5 用例，本 change +7/−6）与 `test_quality_baseline.bats` 的 AC-2/AC-3 断言。**Then 第二分支（漂移 ⇒ 非零 + 指名）的独立双态证据**：`test/test_check_gate_sync.bats:29-31`（健康态基线 ⇒ `[ "$status" -eq 0 ]` 且无 gate-config 漂移报告）、`:36`（向 `SKILL.md` 注入假预设 `fake-preset` ⇒ gate-config 段**报漂移并列出该名**）、`:43`（删除真预设 `design` ⇒ 报漂移）、反向对照 `:49`（注入无 `→` 的英文注释 ⇒ **不误报**）；断言由 `-ne 2` 容忍式收紧为 `-eq 0` 精确式（T15 判据 `TASK.md` T15 `<verify>` 实跑 rc=0） | ✅ | ✅ 常设 bats（`test_check_gate_sync.bats` 5 用例） |
| **AC-5** 内部项目名不随分发件出厂 | 判据 `T24` / `T27` 实跑 **rc=0**（dist 0.2.0 重建 + 归档重扫）；`make check-dist` rc=0（`dist/dsh-flow-kit/vendor/flow-kit-bundle` 与源一致） | ✅ | ✅ 常设门禁 `make check-dist` |
| **AC-6** 前向脱敏有机器门禁 | 判据 `T20` / `T22` / `T23` / `T25` / `T26` 实跑 **rc=0**；`make check-path-privacy` rc=0（**清单外命中 0 条**；自证行四要素齐全）；**探针注入 ⇒ rc=1 并指名 `file:line`**（T26 判据内固化 + 本次 T13 判别力注入复证）（**仅 change 期判据覆盖，无常设 bats 回归 · TD-053**；**第 7 次执行加严**：机械/工具故障面亦 fail-closed —— 坏 `TMPDIR` ⇒ rc≠0 且报文归因、非 git 目录 / index 为空的 git 仓 ⇒ 候选面 N=0 ⇒ rc≠0，修复 = `T-FIX-03` = `6e39cfb` · F1/F2 闭合 · `TD-064`；**第 8 次执行加严**：候选面经自排除后归零（`SCANNED_COUNT=0` 且 `CANDIDATE_COUNT>0`）⇒ rc≠0 + 失败面自证（候选 N / 实际扫描 M / 自排除 N−M）· 临时件不可写 ⇒ rc≠0 且报文归因，修复 = `T-FIX-06` = `421640a` · F-19/F-20 闭合） | ✅ | ✅ **常设 bats**（`test/test_path_privacy_gate.bats` **24** 用例 · `T-FIX-01` = `5ee4ebc` + `T-FIX-03` = `6e39cfb` + **`T-FIX-06` = `421640a`（第 8 次执行）** ⇒ **TD-053 / TD-064 已闭合**） |
| **AC-7** 四处假绿测试不再假绿 | 四条「**注入失败源 ⇒ 必须变红**」证据（AC-7 原文形态 `REQUIREMENT.md:406-428`）：`test_combined_metric.bats`（注入残留文件 ⇒ 红）/ `test_auto_checkpoint.bats`（让 SUT 失败 ⇒ 红）/ `test_independent_review_model.bats`（删除被断言文件 ⇒ 红）/ `test_lessons_cleanup.bats`（移除过期 skip 并断言 `exit 0`）；四文件差异见 `git diff 534e3e8..HEAD -- test/`，判据 `T15` / `T17` rc=0 | ✅ | ✅ 常设 bats（四个假绿文件各含注入型用例） |
| **AC-8** 无退化 | 判据 `T29 <verify>` 原样抽取实跑 **rc=0**：`make check` 全绿 + `npx bats test/` **976 收集 / 975 有效 · ok=976 / not ok=0 / skip=0**（**第 5 次执行实测订正：1012 收集 / 有效 1011 · ok=1012 / not ok=0 / skip=0，见 §1.3 第 2/5 条**；**第 7 次执行实测：1025 收集 / 有效 1024 · ok=1025 / not ok=0 / skip=0**；**第 8 次执行实测：1029 收集 / 有效 1028 · ok=1029 / not ok=0 / skip=0**）（1 条 TD-033 mock 不计入结论面，见 §1.3 第 5 条）+ 三道副本一致性门禁（test/hooks/dist）0 漂移；**活性探针**：`FLOW_KIT_CHANGE_BASE=HEAD` ⇒ **rc=1** + `🔴 AC-8 时点变更集为空（相对锚点 HEAD）⇒ 兼容性判据 rc=3（未验证），不得当作通过`（非空守卫非恒绿）（**长期回归保护：第 5 次执行起已补三件常设 bats 网，第 7 次执行扩到 36 例 · TD-053 已闭合**；**macOS 实机未验证 · 仅静态判据 TD-055**） | ⚠️ **有条件通过（仅静态面）** —— change 期静态判据 rc=0；**跨 OS 实机面 = 未验证（macOS 无任何机器证据 · `Tech-debt: TD-055`）**，不得读作 AC-8 通过（L3 第 10 轮 major 1 收紧） | ⚠️ **常设 bats 覆盖三件生产件静态面**（`test_path_privacy_gate.bats` **30**（**第 11 次执行** · 第 8 次执行时为 24）+ `test_runtime_edit_guard.bats` 9 + `test_nfr_portability_gate.bats` 7 = **46 用例** · `T-FIX-01` = `5ee4ebc` + `T-FIX-03` = `6e39cfb` + `T-FIX-06` = `421640a` + `T-FIX-08`/`T-FIX-11`/`T-FIX-12`/`T-FIX-13`）+ 全量 `npx bats test/` = **1064 收集 / 1063 有效**（**第 11 次执行实测** · L3 第 16 轮 minor ① 收口；`T-FIX-02` = `6cff7a2` 收口时第 8 次执行实测 1029 / 1028）⇒ **TD-053 已闭合**；**macOS 实机面未验证（TD-055，仍开放）** ⇒ 本列**不得读作 AC-8 全通过**（L3 第 8 轮 major 1 收紧） |

**覆盖判定（第 5 次执行订正 · L3 第 8 轮 major 1 收紧）**：**8/8 条 AC 有 change 期覆盖且无空缺 —— 其中 7 项通过、1 项「有条件通过（仅静态面）」**（**AC-8**：Linux 本机静态判据 rc=0；**跨 OS 实机面 = 未验证 ⇒ 不构成通过** · `Tech-debt: TD-055` · L3 第 10 轮 major 1 收紧）；原判定的「3/8（AC-1 / AC-6 / AC-8）无常设回归保护」缺口**已由 `T-FIX-01`（commit `5ee4ebc`）闭合** —— 三件生产件现有常设 bats 网（`test_path_privacy_gate.bats` **20**（第 7 次执行起 · 含机械故障面）· `test_runtime_edit_guard.bats` 9 · `test_nfr_portability_gate.bats` 7 = **36 用例**，本次实测全绿）。**历史记录（不抹除）**：第 1–4 次执行时该判定为「**8/8 仅有 change 期覆盖，其中 3/8 无常设回归保护**（`Tech-debt: TD-053`）」。**静态判据通过 ≠ 跨 OS 兼容性验收通过**（AC-8 的 macOS 面 = `Tech-debt: TD-055`，**仍开放**，见 §4.4）。**判定词收口（L3 第 7 轮 major 1 / L2 R1 响应 · 2026-09-24）**：**AC-8 的 change 期判定 = ⚠️ 部分通过**（静态判据通过；macOS 实机面未验证 · TD-055），其余 7 条 = ✅ 通过；**「判据 14/14 rc=0 · 门禁 7/7 rc=0」是执行面口径，不等于 8/8 AC 全部通过**。 **第 7 次执行补记（fix 循环后）**：判据面 **17/17 rc=0 · 门禁 7/7 rc=0**；阶段 6 审查的两条 🔴（F1 机械故障 fail-open · F2 扫描面塌陷 0 候选同形）已由 `T-FIX-03`（`6e39cfb`）闭合 —— AC-6 的判定力证据由「change 期判据」升级为「**常设双态 bats（20 例，含机械故障面与 0 候选面）**」；🟡 F6/F7（`T-FIX-04` = `521b21c`）与 F8（`T-FIX-05` = `6e94d60`）同属「门禁自称一致却不一致」家族，一并闭合 ⇒ 阶段 6 的 **2 🔴 / 6 🟡 全部结案**（详 §阶段 5 发现 #34–#40）。 **第 8 次执行补记（第 2 轮 fix 循环后 · HEAD `26d5d7b`）**：判据面 **18/18 rc=0 · 门禁 7/7 rc=0**；阶段 6 第 2 轮只读深审登记的 🟡 F-19（自排除后候选面归零仍报 ✅）/ F-20（临时件不可用 ⇒ 机械故障被折成「0 命中」）已由 `T-FIX-06`（`421640a`）闭合 —— AC-6 的失败面证据再升级为「**常设双态 bats（24 例，含机械故障面 · 0 候选面 · 自排除后归零面）**」；F-18（`SCAN_SURFACE` 措辞）按用户裁决 ② 仅订正措辞（同一提交内落地）；**其余 7 条 AC 判定不变**，AC-8 仍为「⚠️ 有条件通过（仅静态面 · `TD-055` 开放）」。 **第 11 次执行补记（`T-FIX-13` 收口后 · L2 第 5 轮 🟡-3 响应 · 2026-09-27）**：AC-6 常设隐私 bats 用例数由 **24 → 30**（`T-FIX-08` 读序 4 例 + `T-FIX-11` R4-1 三腿 3 例 + `T-FIX-12` / `T-FIX-13` 静态断言 3 例），实证 = `grep -cE '^[[:space:]]*@test' test/test_path_privacy_gate.bats` ⇒ **30**；前文「24 例」为第 8 次执行**时点值**（保留不抹除），简报误差登记 **`TD-078`**（`T-FIX-12-SUMMARY.md:76`）并在本行订正。判别力不受影响（30 例覆盖 F1/F2/F3/F4/F5/F19/F20 双态 + 读序 + R4-1 三腿）。

> **安全工具面另计（L3 第 9 轮 major 3 响应）**：**安全工具面 = 0 / 10 未覆盖**（`A01–A10` 无任一条目具备独立安全工具证据）· **`Tech-debt: TD-056` = 本 change 安全验收的未覆盖项** ⇒ 该面**不构成 AC 通过面证据**；`AC-1..AC-8` 无「安全工具面」类验收项，注入面由 `AC-1` 的双态注入实证承载（详见 §3.4 结论与 §3.5 第 1 条）。
> **AC-8 四处口径一致性核对（L3 第 9 轮 major 1 响应）**：`§1.1` change 期判定列 = **⚠️ 部分通过** · `§1.1` 长期回归列 = **⚠️**（静态面有 25 例常设 bats，macOS 面无机器证据） · `§0` 第 5/6 次执行行 = **⚠️ 部分通过** · `§4.4` 表内唯一 ✅ = **静态判据通过**（其口径注明示「不含 macOS 实机」）—— 四处**无一处**把 AC-8 读作全通过；**macOS 面无机器证据 = `Tech-debt: TD-055`（仍开放）**。
> **开放项集中收口（L2 第 3 轮 F-2 响应 · 2026-09-25 · 唯一裁决行）**：本轮仍开放的未覆盖/未验证项统一归口 **阶段 7 triage**，均**不改变**「AC-1..AC-7 = ✅ 通过 · AC-8 = ⚠️ 有条件通过（仅静态面）」的既有口径，**AC-8 的 ⚠️ 一律不得读作全通过**。清单：`TD-055`（macOS 实机面 0 机器证据 · AC-8 的 ⚠️ 唯一成因）· `TD-056`（安全工具面 0/10）· `TD-061`（无 `kcov`/`bashcov` 覆盖率数据）· `TD-058`（`HOOK_BASE_DIR` 两族语义分歧）· `TD-057` / `TD-060` / `TD-062` / `TD-063` / `TD-065`（判据/工具自身缺陷族）· `TD-049`（`.flow-active` 时间戳类型不一致）· `TD-035`（既有 bash4/GNU-only 构造，非本次引入）。

> **结论口径声明（L3 第 4 轮 major 1 响应）**：本表「✅」一律指 **change 期（本次变更集）覆盖** —— 证据 = `TASK.md` 判据**原样抽取实跑** + 双态注入 + 全量回归，逐项可复算（§附录 A）。其中 **3 件生产件（`runtime-edit-guard.sh` / `check-path-privacy.sh` / `check-nfr-portability.sh`）在 `test/` 树 0 引用**（§可复算覆盖代理表）⇒ 本报告**不宣称**它们具备**长期回归保护**：归档后其判定力只由 change 期判据承载（`Tech-debt: TD-053`，已写入 §回归保护，并交**阶段 7 triage**）—— **第 5 次执行订正（`T-FIX-01` = `5ee4ebc`）：上述 0 引用缺口已补齐，三件现有常设 bats 网（25 用例）⇒ 该段的后半句（「不宣称长期回归保护」）自本次执行起不再适用，`TD-053` 已闭合**。同理 §1.2 的 UAT ③ —— 第 1–4 次执行时 **判为「未通过（FAIL）」，失败分支即 B2/B3（完成标记口径相反 / 残缺时门禁放行，`Tech-debt: TD-059`）**；**第 5 次执行起订正为「已通过（PASS）」**：无效标记 B2/B3/B4 **一律 rc=2**（修复 = `T-FIX-02` = `6cff7a2` · ADR-029 ⇒ **TD-059 已闭合**）。历史 FAIL 判定与缺口实证见该条历史行、§阶段 5 发现 #17、§0 阶段门有效性声明的历史对照行。

### 1.2 UAT（验收面端到端）

本 change 无 GUI/服务端 ⇒ UAT 面 = **分发与门禁的真实运行路径**，四条均为端到端实跑：

1. **隔离 bare remote 的 pre-push 拦截**（T19 判据）：四形态泄漏 push 全部被拒、干净 ref 放行 ⇒ rc=0。
2. **pre-commit 门禁显式调用两态**：`bash .git/hooks/pre-commit` 两次探针 ⇒ **rc=1** 并指名 `.zz-probe1.txt:1`、`README.md:151`，报文 `[archive-commit-gate] path-privacy check failed, commit rejected`。
3. **DSH 装载面的阶段门真实拦截**（历史事件 + **可构造等价复现**）：本次阶段 5 提交修复时被 `gate-checks-review.sh` 拒绝 —— `⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit`（L2+L3 未完成前不放行）⇒ 门禁在**真实使用路径**上生效，而非只在单测里成立。原证据依赖「L2/L3 未完成」这一**不可逆时点**，故按 L3 第 3 轮 major 3 的要求改为可运行脚本：**`.specs/health-fix-2026-09b/reproduce-phase-gate.sh`**（`mktemp -d` 沙箱 + `git init` + 空 seed 提交；以 stdin JSON 驱动 `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`；夹具 = `.flow-active` + `.specs/<id>/TEST.md` + `INDEPENDENT-REVIEW-5.md`），原始输出存档 `PHASE5-RECEIPTS.md` §H（**第 5 次执行起为闭合六态 stdout**）与 §J。**版本口径（L3 第 8 轮 minor ② 响应）**：`reproduce-phase-gate.sh` 的**当前版本 = `ddea327` 入库的「闭合六态」版**（165 行 · sha256 `81700f125c1c2557f4ebb468d41bbaf8aad452150b95371b4418464a8eb97337`；`git log -- .specs/health-fix-2026-09b/reproduce-phase-gate.sh` 显示其**唯一提交 = `ddea327`**，即 `T-FIX-02`（`6cff7a2` · ADR-029）之后的第一批留痕；期望 **B2 口径相悖 / B3 `touch` 空 / B4 缺 `L3_verdict` 一律 rc=2**）—— **第 5 次执行期间本脚本未被改动**（工作树值 = 入库值）。同一 change、同一条 `git commit` 命令，只改沙箱状态：
   - **A** 阶段 5 开双审（`gate_config["5-test"]="both"`）且**无**完成标记 ⇒ 实测 **rc=2** + 报文字面命中 + **HEAD 不变**；
   - **B** 同一 change 改为只开 L2 + 合格完成标记（健康态）⇒ 实测 **rc=0** 放行，且放行后 `git commit` **真的生效**（HEAD 前进）；
   - **C** 沙箱无 `.flow-active`（门不适用）⇒ 实测 rc=0（fail-open 对照）；
   - **B2/B3 = 缺口实证（不是健康行为，不得读作通过）**：标记内容与审查档口径**相反**（标记记 pass、审查档记 fail）⇒ rc=**0**；标记**残缺**（删掉 `L3_verdict` 键、5 行低于 6 行下限）⇒ rc=**0** ⇒ **🔴 `Tech-debt: TD-059`**（阶段门在 commit 路径上是「**文件存在性**」判定：`flow-kit-bundle/hooks/stop/lib/done-validation.sh:35` 的 `fk_independent_review_gate_active` 在标记存在时即返回「门未开」，使 Gate4 的 6 键 / Tier-2 校验不可达；唯一实际防线 D7 path-guard 只对**命令文本**做文件名匹配）；
   - **判别子**：门禁外直连 `git commit` 可用 ⇒ 拦截来自门禁判定，而非命令形态或仓库损坏；**旁证**：`🟡 Tech-debt: TD-058`（沿用 Stop 侧惯例的 `HOOK_BASE_DIR=…/hooks` 会让该 hook fail-close 成「拒绝一切 commit」并给出误导性归因 —— 复现脚本因此**不覆盖**该变量）。
   - **B4（键集 / 行数面 · 第 5 次执行观测的第三类无效标记）**：标记缺 `L3_verdict` 键（5 行 < `MIN_MEANINGFUL_LINES=6`）⇒ 期望 rc=**2**（与 B2/B3 同属「无效标记」层）。
   - **第 5 次执行（REPRO4 · 闭合态 · 2026-09-24 17:22）实测**：对照 0 门禁外直连 commit 成功（HEAD 前进）· **A rc=2 且 HEAD 不变**（`e2c73dd…`）· **B rc=0 且放行后 commit 真生效** · **B2 rc=2**（口径相悖被拒）· **B3 rc=2**（`touch` 空标记被拒）· **B4 rc=2**（缺 `L3_verdict` 被拒）· **C rc=0**（门不适用）⇒ **UAT ③ 第 5 次执行判定 = 通过（PASS）**，`Tech-debt: TD-059` 已闭合（修复 = `T-FIX-02` = `6cff7a2` · ADR-029）。原始 stdout 见 `PHASE5-RECEIPTS.md` §H 与本文 §附录 D。
   - **PASS 依据的边界（L3 第 7 轮 minor ① 响应）**：本条 PASS 的**依据 = 沙箱六态等价复现**（`reproduce-phase-gate.sh`，可重放、可复算、含判别子）；**历史事件**（本次阶段 5 真实被拦，触发条件是**不可逆时点**）仅作**旁证**，**不作为 PASS 依据**；两者不得混写为同一验收面。**可复现性限定（L3 第 10 轮 major 4 响应）**：本条的**全绿结论仅对源面冻结后的工作树成立** —— 第 5 次执行期间存在一次中间轮 **r4c rc=1**（根因 = 源面在飞行中被改致 `check-dist` 陈旧，**非判据/产品问题**；完整回执见附录 **D-5**），且沙箱脚本自身在该期间由五态改为闭合六态（§C-5）。
   - **本条验收面结论（L3 第 4 轮 major 2 响应 · 第 1–4 次执行的历史结论，保留不抹除）**：既有拦截**只在「无完成标记」时成立**（状态 A，rc=2）；标记**存在但口径相反 / 残缺**时门禁**放行**（B2/B3 = TD-059）⇒ **UAT ③ 当时判为「未通过（FAIL）」**（**失败分支 = B2/B3 两条放行路径**），B2/B3 是该条的**未通过分支**（不是被覆盖的健康行为）；历史事件（本次阶段 5 真实被拦）同样只由「标记缺失」触发。该缺口的处置 = **显式缺口实证 + `Tech-debt: TD-059`**（本 change 不修，理由见 §阶段 5 发现 #17）。**⇒ 第 5 次执行订正**：该缺口已由 `T-FIX-02`（`6cff7a2` · ADR-029）修复闭合，**UAT ③ 现为通过（PASS）**（六态全绿，实测见上一条）。
4. **安装器覆盖完整性**：`bash package-flow-kit.sh --validate` ⇒ **本次实测**（阶段 5 第 1 轮）期望覆盖 **311** 项 / 实际文件 **317** 项 / 漏配 ERROR=**0** / 源缺失 WARNING=**0** / rc=0（计数随 HEAD 文件数变动，判据是「漏配 = 0 且源缺失 = 0」，已由 `test_archive_commit_gate.bats` 的 `validate_staging_coverage` 用例固化）。**第 5 次执行实测 = 期望覆盖 315 项 / 实际文件 321 项 / 漏配 0 / 源缺失 0 / rc=0**（两侧各 +4 = `T-FIX-01`/`T-FIX-02` 新增的 4 个 `flow-kit-bundle/test/` 镜像 ⇒ 计数增量与件数增量一致）。

**可复制复现序列（L3 第 1 轮 minor「UAT 未附命令与原始输出」的响应 · 命令 + 期望/实际 rc）**：

```bash
# ① T19 端到端 push 拦截（自建隔离 bare remote：四形态泄漏 + 干净 ref）
sed -n '/<task id="T19"[^>]*>/,/<\/task>/p' .specs/health-fix-2026-09b/TASK.md \
  | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d' > /tmp/v_T19.sh && bash /tmp/v_T19.sh; echo "rc=$?"
#   期望：四形态 push 全拒（拒绝报文含 ref 名与原因）+ 干净 ref 放行 ⇒ rc=0；实际：rc=0

# ② pre-commit 门禁的显式真实调用（不依赖 git 是否加载 hook —— 本仓 git hook 路径为空，见 L-144）
printf 'x\n' > .zz-probe1.txt && git add -f .zz-probe1.txt && bash .git/hooks/pre-commit; echo "rc=$?"
#   期望：rc≠0 且报文 [archive-commit-gate] path-privacy check failed, commit rejected（指名 file:line）；实际：rc=1，指名 .zz-probe1.txt:1
git rm -q --cached .zz-probe1.txt && rm -f .zz-probe1.txt && bash .git/hooks/pre-commit; echo "rc=$?"
#   期望：干净树放行 rc=0；实际：rc=0（第二形态探针 README.md:151 见 T20 复核记录）

# ③ DSH 装载面的阶段门拦截（可构造等价复现：沙箱内自建 change + 缺完成标记；UAT ③ 的可重放入口）
bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh; echo "rc=$?"
#   期望（第 5 次执行 · 闭合态）：对照 0 rc=0（门禁外直连 commit 成功）· A rc=2 + 报文命中 + HEAD 不变 ·
#        B rc=0 且 commit 真的生效 · B2/B3/B4 一律 rc=2（口径相悖 / touch 空 / 缺 L3_verdict 键）· C rc=0（门不适用）⇒ 脚本 rc=0
#   历史对照（TD-059 缺口实证）：修复前 B2/B3/B4 均为「存在即放行」的 rc=0；脚本自带该 ℹ️ 历史对照行

# ④ 安装器覆盖完整性
bash package-flow-kit.sh --validate | tail -4; echo "rc=$?"
#   期望：漏配 ERROR=0 且 源缺失 WARNING=0 ⇒ rc=0；第 1 轮实际：期望覆盖 311 / 实际文件 317 / 漏配 0 / 源缺失 0 / rc=0
#   第 5 次执行实际：期望覆盖 315 / 实际文件 321 / 漏配 0 / 源缺失 0 / rc=0（两侧各 +4 = 4 个新增 bundle 测试镜像）
```

### 1.3 覆盖率（Coverage · 如适用）

> **时点标记规则（L3 第 7 轮 minor ③ 响应 · 第 14 轮 minor ② 订正）**：本节数字**未标历史轮次者一律为当前值 = 第 11 次执行（`1064` 收集 / `1063` 有效 · REPRO10 权威）**；历史值一律显式前缀。**订正留痕**：原标记停留在第 8 次执行（`1029` / `1028`），与 §0 执行表第 11 次行及附录 D-12 的权威基线冲突（L3 第 14 轮 minor ②：同一工件内两个「当前值」并存易误读）⇒ 就地统一为第 11 次口径；第 8 次及更早的值（含 1029 / 1028、976 / 975）一律按历史值读，**不得当作当前基线**。
> **TD-033 mock 计数口径（L3 第 7 轮 minor ② / L2 R6 响应）**：该 1 条 mock 仍在 `npx bats --count` 总数内 ⇒ **有效口径 = 1011**；把它重写为 source 真实 lib 属 `test/**` **源面**变更（本 change 明令 `T24` 之后不动源面）⇒ 记 **`Tech-debt: TD-033`**（v2 重写为真实实现回归）。

**Coverage（行覆盖）**：本仓为 bash + bats —— **本机无 `kcov` / `bashcov` ⇒ 行覆盖率 / 分支覆盖率「无任何数据」（不是「0%」，是「无测量工具」；L3 第 8 轮 minor ① 明写）**，故按「等价强度」的三条替代口径：

1. **AC 覆盖**：8/8 全覆盖（§1.1），且每条 AC 都有**双态**证据（健康 ⇒ 绿 / 注入缺陷 ⇒ 红），不是「跑一次看绿」。
2. **收集面 = 执行面**：`npx bats --count test/` = **1064**（**有效用例 1063**，见第 5 条 —— **第 11 次执行实测（REPRO10 权威）**；第 8 次执行时为 1029 / 1028，第 7 次为 1025 / 1024，第 1–4 次执行时该值为 976 / 975，第 5/6 次执行时为 1012 / 1011，构成见第 4 条的历史归因），直跑实测 `ok=1064 / not ok=0 / skip=0` ⇒ **1064 条被收集且全部执行（零 skip）**；其中 **1 条为 TD-033 mock**（见第 5 条）⇒ **有效验证用例 = 1063**；**「零 skip」只表示无静默跳过，不等于 1029 条全为真实验证**（L3 第 9 轮 minor ① 收口）；**行覆盖率无数据不影响 AC 双态证据的结论** —— AC 判定依据是「判据原样实跑 + 双态注入」（§附录 A），不是行覆盖率。原始 TAP 全文（1064 行逐条 `ok`/`not ok` 与显式 skip 计数命令）见 `PHASE5-RECEIPTS.md` **§T-2**（第 11 次权威）/ §P-2（第 8 次）/ §B-2 / §J / §O-2；**判据原文关键行已按 L-151 内嵌于本文 §附录 D**（避免补充产物被截断）。
3. **关键判定路径的专项用例数**：`test_archive_commit_gate.bats` 27（pre-commit/pre-push 接线）、`test_gate_config_presets.bats` 34、`test_install_coverage.bats` 17、`test_lessons_cleanup.bats` 16、`test_check_gate_sync.bats` **7**、`test_combined_metric.bats` 2（+1 见 AC-7 修正）。**第 5 次执行新增的四个文件**：`test_path_privacy_gate.bats` **9**、`test_runtime_edit_guard.bats` **9**、`test_nfr_portability_gate.bats` **7**（`T-FIX-01` = `5ee4ebc` ⇒ TD-053 常设回归网，本 change 合计 25 例）、`test_review_gate_validity.bats` **11**（`T-FIX-02` = `6cff7a2` ⇒ TD-059 阶段门标记有效性，合计 11 例）。四个文件均为 `test/` ↔ `flow-kit-bundle/test/` **双源同步**（`make check-test-sync` rc=0）。**第 7 次执行加严（fix 循环）**：`test_path_privacy_gate.bats` **9 → 20** 例（`T-FIX-03` = `6e39cfb`：F1~F5 各双态）· `test_check_gate_sync.bats` **5 → 7** 例（`T-FIX-04` = `521b21c`：完整夹具 + 缺对双态）；`T-FIX-05` = `6e94d60` 以钉住断言改写既有用例（`Makefile` 判据正文唯一性）⇒ **计数 +0**。**第 8 次执行加严（第 2 轮 fix 循环）**：`test_path_privacy_gate.bats` **20 → 24** 例（`T-FIX-06` = `421640a`：F-19「自排除后候选面归零」与 F-20「临时件不可写」各**坏/好双态**；F-18 的错因归属断言追加进既有用例 ⇒ **计数 +0**）；`test_check_gate_sync.bats` 仍 7 例（`T-FIX-04` 后无变化）。
4. **976（有效 975）的构成 · 973 → 976 的逐项归因**（L3 第 2 轮 minor ④ 响应）：`git diff --stat 534e3e8..HEAD -- test/` = **8 文件 +84/−28**；逐文件 `@test` 计数**唯一变化** = `test/test_archive_commit_gate.bats` **24 → 27（+3）**，其余 7 个文件计数不变（`test_auto_checkpoint.bats` 13 · `test_check_gate_sync.bats` 5 · `test_combined_metric.bats` 2 · `test_correction_hygiene.bats` 10 · `test_independent_review_model.bats` 12 · `test_l3_review_defects_2026_09.bats` 124 · `test_lessons_cleanup.bats` 16）⇒ **973 + 3 = 976**，无计数口径漂移。历史 SUMMARY 中的「973 ok / **1 skip**」是**变更前基线**（阶段 1 记录）；那 1 个 skip 来自 `test_lessons_cleanup.bats` 的过期 skip，已由 AC-7 移除并改为机器可验证断言（见 §新增测试登记）⇒ 阶段 4 起实测基线统一为 **976 ok / 0 not ok / 0 skip**。复算命令：
   ```bash
   for f in $(git diff --name-only 534e3e8..HEAD -- test/); do
     printf '%s  base=%s  head=%s\n' "$f" "$(git show 534e3e8:"$f" | grep -c '@test')" "$(grep -c '@test' "$f")"
   done
   ```
   **基线演进（第 5 次执行补记 · 与 `.specs/STATE.md:48-51` 同源）**：**976 → 1001 → 1012** —— `976`（T29 时点收口）· `1001` = 976 + **25**（`T-FIX-01` = `5ee4ebc`：`test_path_privacy_gate.bats` 9 + `test_runtime_edit_guard.bats` 9 + `test_nfr_portability_gate.bats` 7）· **`1012` = 1001 + 11**（`T-FIX-02` = `6cff7a2`：`test_review_gate_validity.bats` 11 例 = A 无标记 / B 6 键有效 / B2 口径相悖 / B3 `touch` 空 / B4 缺 `L3_verdict` / B5 值域非法 / C 无 `.flow-active` / gate 未开反面对照 / 函数级三例）· **`1023` = 1012 + 11**（`T-FIX-03` = `6e39cfb`：`test_path_privacy_gate.bats` 9 → 20）· **`1025` = 1023 + 2**（`T-FIX-04` = `521b21c`：`test_check_gate_sync.bats` 5 → 7；`T-FIX-05` = `6e94d60` 计数 +0）· **`1029` = 1025 + 4**（`T-FIX-06` = `421640a`：`test_path_privacy_gate.bats` **20 → 24**，F-19/F-20 各坏/好双态；F-18 错因归属断言并入既有用例 ⇒ +0）。四个新文件行数 = 163 / 113 / 127 / 197，`@test` 计数 = 9 / 9 / 7 / 11（`grep -c '@test'`）。**第 7 次执行实测**：`npx bats --count test/` = **1025**、`npx bats test/` = **ok=1025 / not ok=0 / skip=0**（TAP `1..1025`）；**第 8 次执行实测**：`npx bats --count test/` = **1029**、`npx bats test/` = **ok=1029 / not ok=0 / skip=0**（TAP `1..1029`）。

5. **有效用例口径**（L3 第 3 轮 minor ③ 响应 · 第 5 次执行数值订正）：**1064** 条中有 **1 条是 TD-033 记录的 mock 用例**（`test/test_gate_config_presets.bats:27-28` 自陈 `Simulates the resolve_gate_config() logic`，从不 source 生产实现）⇒ **有效用例 = 1063**（**第 11 次执行**；历史：第 1–4 次执行 976 / 975，第 5/6 次执行 1012 / 1011，第 7 次执行 1025 / 1024，第 8 次执行 1029 / 1028）；该条**不计入** AC-7「不再假绿」的结论面（§1.6 ② 已把 AC-4 的证据整体迁到 `test/test_check_gate_sync.bats` 的 5 个双态用例），本 change 不修它（TD-033 属 change 前既有债、已由 `REQUIREMENT.md` 范围切分排除）。**处置选项（L3 第 10 轮 minor ② 响应）**：① 重写为 source 真实实现（**v2 推荐** · 消除 mock）· ② 标 `skip`（会打破「零 skip」宣称且掩盖债）· ③ 移出收集面（等同删证据）—— 本 change 选**显式登记 + 在所有引用处标注「含 1 条 mock ⇒ 有效 1028」**（`test/**` 源面自 `T24` 起冻结 · 该债由 `REQUIREMENT.md` 范围切分排除）。

**可复算覆盖代理表（L3 第 1 轮 minor「覆盖率无量化数据」的响应 · 已覆盖 / 未覆盖清单）**：

| 变更的生产件 | `test/` 常设断言面（引用文件数） | change 期判据 | 双态注入（红/绿两侧） |
|---|---|---|---|
| `flow-kit-bundle/hooks/pre-commit/pre-commit.sh` | 1 | T19 / T20 | 泄漏探针 ⇒ rc=1；撤销 ⇒ rc=0 |
| `flow-kit-bundle/hooks/pre-push/pre-push.sh` | 3 | T19 / T20 | 四形态 push 全拒 + 干净 ref 放行 |
| `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh` | **9 ✅**（`test_runtime_edit_guard.bats` · 第 5 次执行起） | T05 / **T-FIX-01** | 相对路径 ⇒ rc=2；绝对路径 ⇒ rc=0 |
| `flow-kit-bundle/lib/install_hooks.sh` | 4 | T06 / T18 | 缺依赖 ⇒ fail-closed 且不破坏既有配置 |
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | **9 → 24 ✅**（`test_path_privacy_gate.bats` · 第 7/8 次执行起含机械故障面与 0 候选面/自排除归零面） | T21 / T22 / T23 / T13 / **T-FIX-01** / **T-FIX-03** / **T-FIX-06** | 探针注入 ⇒ rc=1 指名；空清单 ⇒ rc=0；缺清单 ⇒ rc=1；**坏 `TMPDIR` ⇒ rc≠0（fail-closed）**；**0 候选（非 git / index 空）⇒ rc≠0**；**自排除后 0 实际扫描 ⇒ rc≠0 + 失败面自证（候选 N / 实际扫描 M / 自排除 N−M）** |
| `Makefile`（`check-nfr-portability` **内联 recipe** + 内部判据 `check-nfr-portability-internals`；**非 `.sh` 文件** · L2 R4 订正） | **7 ✅**（`test_nfr_portability_gate.bats` · 第 5 次执行起） | T24 / T27 / T28 / **T-FIX-01** | 空变更集 ⇒ rc=3；GNU-only 注入 ⇒ rc≠0 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | 6 | T04 | ADR 引用频次采样差异两态 |
| `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（新增） | 2 | T13 / T15 | 注入假预设 / 删真预设 ⇒ 报漂移；无 `→` 注释 ⇒ 不误报 |
| `package-flow-kit.sh` | 5 | T10 / T11 | 漏配 ⇒ ERROR；源缺失 ⇒ WARNING |
| `flow-kit-bundle/lib/validate_staging.sh` | 3 | T10 / T11 | 同上（覆盖清单缺项 ⇒ 报） |
| `sync-hooks.sh` | 2 | T05 | 镜像漂移注入 ⇒ 非零；`./sync-hooks.sh` 后 ⇒ 0 |

- **已覆盖（有常设断言面）**：**11 / 11 件**（第 5 次执行订正：第 1–4 次执行为 8 / 11；缺的 3 件由 `T-FIX-01` = `5ee4ebc` 补齐 ⇒ **`Tech-debt: TD-053` 已闭合**）。
- **未覆盖（历史口径 · 第 1–4 次执行）**：3 件 —— `runtime-edit-guard.sh`、`check-path-privacy.sh`、`check-nfr-portability.sh` 在 `test/` 树内 **0 引用**，判定力仅由 change 期判据承载 ⇒ 当时记 **`Tech-debt: TD-053`**（§回归保护 + §阶段 5 发现 #1）。**⇒ 第 5 次执行订正：3 件均已补常设 bats 网（9 / 9 / 7 用例，本轮全绿），未覆盖面 = 0 / 11**，该缺口不再存在。
- **可复算命令**：`for n in <件名…>; do printf '%s %s\n' "$n" "$(grep -rl "$n" test/ | wc -l)"; done`（上表第 2 列）；双态注入密度 = **13 / 29** 条 task 判据含注入/探针（`awk '/<task id=/{inv=0} /注入|探针|probe/{inv=1} /<\/task>/{if(inv) c++} END{print c}' .specs/health-fix-2026-09b/TASK.md` ⇒ `13`）。
- **量化上限（工具面诚实声明 · L3 第 8 轮 minor ① 扩充）**：本机**无** `kcov` / `bashcov` ⇒ **行/分支覆盖率无任何数据**（不是「0%」而是「无测量工具」）；上表以「常设断言面 + change 期双态判据」作可复算代理。**仅由 change 期判据覆盖（2026-09-24 前无常设 bats、现由 `T-FIX-01` 补齐）的分支面清单**：① `check-path-privacy.sh` 的 fail-closed 读序三分支 —— 清单缺失 ⇒ rc=1 指名（`T21`/`T23`）/ 空清单 ⇒ rc=0 合法基线（`T22`）/ 探针注入 ⇒ rc=1 + `file:line`（`T26`，含面内面外两支）；② `runtime-edit-guard.sh` 的相对路径 ⇒ rc=2 / 绝对路径 ⇒ rc=0 双分支（`T05`）；③ `Makefile` 的 `check-nfr-portability` 空变更集守卫 ⇒ rc=3「未验证」（`T24`，`T29` 活性探针复证）。**复算入口**：逐条判据的抽取行数 + rc + 原始输出见 §附录 A ① / §附录 D-1、`PHASE5-RECEIPTS.md` 判据清单 §A 与 **§J**；**各判据的修改前原文与来源 commit 见 `PHASE5-RECEIPTS.md` §K**（逐条「原文字面执行为何红/绿」与执行结论见 **§L**）。工具面补齐（`kcov`/`bashcov` + 分支覆盖）与 `TD-053` 同源，属 v2。

边界值与错误路径：见 §1.4（7 条，均 ≥3）。

### 1.4 边界 / 错误路径

| # | 场景 | 证据（判据/用例） | 期望 | 实测 |
|---|---|---|---|---|
| 1 | 允许清单**缺失**（常设与 change 副本皆无） | `T21`/`T23` 判据（自建 both-missing fixture） | rc=1 且**指名缺失路径**（fail-closed，不得当空清单放行） | ✅ 与期望一致 |
| 2 | 允许清单**存在但为空** | `T22` 判据 | **rc=0 合法空基线**（也不得静默跳过扫描） | ✅ |
| 3 | 变更集**为空**（锚点 = HEAD） | `T29` 活性探针（本次亲跑） | rc=1 + `rc=3（未验证）` 明示，不得当绿灯 | ✅ |
| 4 | pre-push stdin **畸形**（缺 local sha） | `pre-push.sh:30` + `T11` 判据 | fail-closed 拒绝并给原因 | ✅ |
| 5 | 目标库**缺 jq** | `T06` 判据 | 既有配置**字节不变**（不得截断为 0）、安装 fail-closed | ✅ |
| 6 | **非 git 仓库** 下跑扫描判据 | `T13 <verify>` 的第 2 行守卫 | 明确 `🔴 非 git 仓库…判据不可用` 且 exit 1（不得静默绿） | ✅ |
| 7 | 路径隐私**探针注入**（合成账号名，拼接构造） | `T26` 判据 + 本次 `T13` 注入（非面文件 `sync-hooks.sh:382` / 面内 `T13-SUMMARY.md`） | rc=1 + `file:line` 归因；面内/面外走不同分支 | ✅ 两分支均命中 |
| 8 | locale = `C` 且 `iconv` 未写 `-t` | §4.4 矩阵 | 记录为**已知缺陷形态**（TD-051），产品代码无缺陷 | ⚠️ 已登记（非本次范围） |

### 1.5 测试质量自检（6 维测试衰退风险）

| 维度 | 检查内容（路径 B：内置清单） | 判定 | 依据 |
|---|---|---|---|
| T1 Test Obscurity | 用例名是否描述行为、断言是否可读 | ✅ 无命中 | 本 change 改动的 8 个文件均为具名断言（如 `AC-2: check-gate-sync.sh 运行无脚本错误`） |
| T2 Brittleness | 是否依赖易变细节（行号、计数、时序） | ✅ 无命中 | AC-7 订正**删除了行号引用**（`AC-7` 原文：改按测试名 + 断言内容引用）；T15 把 `-ne 2` 容忍式断言改为 `exit 0` 精确断言 |
| T3 Duplication | 重复用例/重复实现 | ✅ 无命中 | `test/` ↔ `flow-kit-bundle/test/` 的镜像由 `make check-test-sync`（`diff -rq`）强制一致；hook 六镜像由 `check-hooks-sync` 强制一致 —— 属**受门禁约束的有意副本**，非漂移式重复 |
| T4 Mock Abuse | 是否有文件内自建被测逻辑（从不 source 生产实现） | ⚠️ **命中 1** | `test/test_gate_config_presets.bats:27-28` 仍自陈 `Simulates the resolve_gate_config() logic`、硬编码 `"independent"` ⇒ **TD-033（既有登记，本 change 未纳入范围）** |
| T5 Coverage Illusion | 是否存在"绿而无效"的通过面 | ✅ 无命中 | 计数一律直跑 `npx bats`（`make test` 的 stdout 是装饰性截断，L-140）；`skip=0`；本 change 移除了 `test_lessons_cleanup.bats` 的过期 skip |
| T6 Architecture Mismatch | 用例是否在测真实架构（分发出的脚本），而非替身 | ✅ 无命中（除 T4） | 抽查离仓对照：把 `test_check_gate_sync.bats` 单独拷到 `/tmp` 运行 ⇒ **setup 即失败**（`cp … flow-kit-bundle/skills/flow/SKILL.md 没有那个文件或目录`）⇒ 真依赖仓库（与 L-115 的 mock 自证形态相反） |

**命中数 = 1**（T4：TD-033）⇒ 按 `5-test.md` 规则「命中 ≥1 记技术债；≥3 本次 release 前必修」：**只记技术债，不阻塞 release**；TD-033 属 change 前既有债、本次未纳入范围的判定见 `REQUIREMENT.md` 范围切分。

> **覆盖率工具面（L3 第 8 轮 minor ① 响应 · 与 §1.3 同源）**：本机**无** `kcov` / `bashcov` ⇒ 行/分支覆盖率**无数据**（不是 0%）；本节的 T5「Coverage Illusion」维度因此**不依据覆盖率数字**判定，而依据「收集面 = 执行面（`npx bats --count` = 直跑 `ok` 数）+ `skip=0` + 每条 AC 的双态注入（健康 ⇒ 绿 / 注入缺陷 ⇒ 红）」。仅由 change 期判据覆盖的分支面清单与复算入口见 §1.3「量化上限」段。

### 1.6 测试质量记事

1. **新门禁没有常设 bats 回归**（本次新增发现 ⇒ TD-053）：`grep -rln 'path-privacy' test/` 与 `grep -rln 'nfr-portability' test/` **均 0 命中**；`runtime-edit-guard` 同样在 `test/` 树内 0 命中。⇒ `check-path-privacy.sh`（392 行）/ `check-nfr-portability.sh` / AC-1 的守卫修复，其**判定力目前只由 change 期判据承载**，归档后无常设回归网。处置：记 **TD-053**（`Tech-debt:`），理由见 §阶段 5 发现 #1。**⇒ 第 5 次执行订正（`T-FIX-01` = `5ee4ebc`）**：同样三条 `grep -rln` 现在分别命中 `test/test_path_privacy_gate.bats` / `test/test_nfr_portability_gate.bats` / `test/test_runtime_edit_guard.bats`（9 / 7 / 9 用例，本轮实测全绿）⇒ **TD-053 已闭合**，本条自本次执行起转为历史记录。
2. **mock 自证存量**（TD-033）仍在盘：`test_gate_config_presets.bats` 的 mock 硬编码旧语义 `"independent"`，与出货契约 `skills/flow/SKILL.md` 的 `"both"` 不一致 ⇒ 该文件**不能**作为 gate_config 语义的回归证据（本次 §1.1 中 AC-4 的证据**未**采信该文件）。**TD-033 不影响 AC-4 的证据面**（L3 第 2 轮 minor ③ 响应）：AC-4 的证据全部采自 `test/test_check_gate_sync.bats`（5 用例 = `:24` 脚本存在且可执行 · `:29-31` 健康态 rc=0 且无漂移报告 · `:36` 注入假预设 `fake-preset` ⇒ 报漂移并列出该名 · `:43` 删真预设 `design` ⇒ 报漂移 · `:49` 注入无 `→` 的英文注释 ⇒ **不误报**），该文件 `:30/:38/:45/:51` 四处均 `run bash "$SCRIPT"` 直接调用**真脚本**（无 mock 屏蔽），且**漂移/不误报双态齐备**。
3. **测量方法留档**（可复算）：性能单跑用 `TIMEFORMAT='real=%R user=%U sys=%S'`；TAP 计数用 `grep -cE '^ok '` / `^not ok `；bats 收集数用 `npx bats --count test/`。

### 1.7 判据修正台账（字面执行 vs 修正后执行 · 回写权威副本的决定）

L3 第 2 轮 major 3 问：本报告的 `rc=0` 是**字面执行**还是**修正后执行**？修正是否已回写权威副本 `TASK.md`？逐条回答：

| task | 本轮执行方式 | 本轮 rc | 修正是否回写 `TASK.md` |
|---|---|---|---|
| T05 / T06 / T11 / T13 / T20 / T22 / T24 / T26 / T27 / T29 | **字面抽取 + 字面执行**（`reproduce-5-test.sh` 的 `extract_verify()` 用 awk 取出 `<verify>`…`</verify>` 区间，**不做任何改写**，也不套 `set -e`） | 全部 **rc=0**（逐条行数与原始输出见 `PHASE5-RECEIPTS.md` §A） | 无需回写（**本轮未修正任何判据**） |
| T17 | 字面执行 **rc=1** ⇒ 暴露旧断言的策略错误（「集合完备」会把新审查档推向门禁豁免表 = 泄漏静默入库，见 L-150）⇒ **修正直接落在权威副本内** | 订正后 **rc=0**（73 行判据） | **已回写**：`TASK.md` 的 T17 `<verify>` 整块重写为**时间切点**策略（冻结集 1–3 唯一豁免；新增档进表即红）+ `T13` done 注记同批订正（L-150 / TD-054）⇒ 重抽即为修正后版本，两者同源 |
| T19 | 字面执行 **rc=0**（修正前 33 行 / 修正后 36 行）；L3 第 3 轮 major 4 指出 `out=$(cmd 2>&1); rc=$?` 在 `set -e` 下与真红态不可区分 ⇒ **修正直接落在权威副本内**（4 处改为「先置零再捕获」，并把严格模式约定写进块内注释） | 平跑 **rc=0**；strict 对照 `bash -e -u -o pipefail …/v_T19.sh` ⇒ **rc=0 / 37 行输出**（修正前实测：**rc=1 / 19 行前置输出 / 无任何 🔴 断言报文** ⇒ 只能靠报文与真红态区分） | **已回写**：`TASK.md` 的 T19 `<verify>` 四处（`:877` 循环内 / `:881` `--tags` / `:886` `--all` 判别子 / `:889` 摘 hook 归因对照）改为 `rc=0; out=$(cmd 2>&1) || rc=$?`（或 `rc_off=0; cmd || rc_off=$?`），块尾加注释固化约定；`reproduce-5-test.sh` 重抽后实跑 ⇒ **两种运行器同结论**。同族其余 18 处（未复算的判据块）仍留 **`Tech-debt: TD-057`**（不机械改写） |

**结论（L3 第 8 轮 major 2 收口）**：**除 `T17` / `T19` / `T-FIX-01` / `T-FIX-02` / `T-FIX-04` / `T27` / `T29` 七条（组）在修正后重抽重跑**（第 7 次执行新增 `T-FIX-04`）（修改前原文与来源 commit 见 `PHASE5-RECEIPTS.md` **§K**，逐条「原文字面执行为何红 / 为何绿」见 **§L**）**外，其余判据为字面执行** —— 被修正的判据共六条（组）—— T17 与 T19（阶段 5 第 1–4 次执行期间，见上表）· `T-FIX-01` 与 `T-FIX-02`（**第 5 次执行重入复跑期间**发现，见下表前两行）· `T27`/`T29` 的 bats 回归地板（同期间订正，见下表第三行），且六处修正**都写在权威副本 `TASK.md` 内**（重抽即得修正后版本 ⇒ 不存在「报告用修正版、仓内是旧版」的分叉）：T17 因旧策略会把新审查档推向门禁豁免表（L-150），T19 因 `set -e` 陷阱使两种运行器结论相反（L3 第 3 轮 major 4），`T-FIX-01` 因判据的 `LC_ALL=C` 泄漏进子进程（TD-051 复发 · locale 敏感性），`T-FIX-02` 因判据出沙箱后未回仓根（TD-060 · cwd 泄漏），`T27`/`T29` 因回归地板按旧基线标定而失去判定力（L-152 同族）。TD-057 的 T19 实例已闭环（两种运行器均 rc=0），同族其余 18 处仍留债。

**第 5 次执行追加的两行（重入复跑时才暴露的判据缺陷 · 均由主 agent 修正并回写 `TASK.md`）**：

| task | 原文字面执行为何红 | 修正内容（落在权威副本 `TASK.md`） | 修正前 → 修正后 rc |
|---|---|---|---|
| **`T-FIX-01`**（TD-051 复发 · locale 覆盖） | 判据首行 `export LC_ALL=C` **泄漏进它调用的 `npx bats` 子进程**，使既有用例 `test/test_l3_pipeline_fix.bats:592`（`T06fix: L2 R1 - line cap truncation respects UTF-8 boundary`）在 HEAD 即红：`:609` 断言 `printf '%s' "$capped" \| iconv -f utf-8 -o /dev/null` **未给 `-t`** ⇒ 目标字符集取自 locale ⇒ 地域 `C` 下拒绝合法 UTF-8（`iconv: illegal input sequence at position 136` / `not ok 646`）。**产品代码无回归**，红是判据自身的作用域缺陷 | 首行 `export LC_ALL=C; rc=0;` → **4 行成因注释（记 TD-051 编号与成因）+ `rc=0;`**；判据**其余 31 行逐字不动**，断言强度不变（最小偏离旁证：仅换成 `LC_ALL=C.utf8` 即 rc=0 + 九门禁全绿；判别式重放 `LC_ALL=C npx bats --filter 'UTF-8 boundary' test/test_l3_pipeline_fix.bats` ⇒ `not ok 1`，`LC_ALL=C.utf8 …` ⇒ `ok 1`） | **rc=1 → rc=0**（36 行判据；原始输出 `TAP: ok=25 not-ok=0 rc=0`） |
| **`T-FIX-02`**（TD-060 · cwd 泄漏） | 判据进 `mktemp -d` 沙箱后**未回仓根**，其后 6 步（新 bats + 4 条 `make`）全在 `${TMPDIR:-/tmp}` 里执行 ⇒ 五态行虽全对，随后四条 🔴（`新增双态判据 rc=1` / `hooks 副本未同步` / `test 双源不一致` / `dist 未重建`）+ `make: *** 没有规则可制作目标“check”` | 补 `REPO_ROOT="$PWD"`（进沙箱前记录仓根）与沙箱段末尾 `cd "$REPO_ROOT"`；**步骤与断言逐字不动**（执行者当时按「不改验收标准」原则未动判据、改以仓根 cwd 补跑同 6 行全绿并如实上报，主 agent 判定为判据缺陷后就地修复） | **rc=1 → rc=0**（42 行判据；原始输出 `A=2 B=0 B2=2 B3=2 B4=2 C=0`，其后 `make check` = `✅ make check: 全部通过`） |

| **`T27` / `T29`**（回归地板过时 · 第 5 次执行重入复核触发） | 判据的 bats 回归**地板**按旧基线标定为 `[ "$b_ok" -ge 973 ]`（= 976 − 3）；基线升到 **1012** 后，旧地板允许 **39 例静默消失** ⇒ 「回归网被削弱」**不可判失败**（判据自身不红，但判定力已被削弱，与 L-152「门禁强度 = 最早返回的检查」同族） | 断言值与描述串就地订正（落在权威副本 `TASK.md`）：`:1231`（T27 断言）/ `:1306`（T29 断言）`-ge 973` → **`-ge 1009`**（= 1012 − 3，与原 976/973 同余量）；同步 `:1229`（T27 echo 描述串）/ `:1291`（T29 `<action>` 描述串）/ `:25`（AC-8 行 `bats ≥1009`）+ 两条 `<done>` 注记。**不动断言结构、不动判据步骤**，`<verify>` 行数未变（T27 = 19 行 / T29 = 15 行） | **rc=0 → rc=0（红绿不变 · 判定面收紧）**：新地板下 `ok=1012 ≥ 1009` ⇒ 仍绿，但 `ok ≤ 1008` 自此可判失败。本行为「判据已失去判定力」的订正，**不是**红绿翻转；未新开 TD（主 agent 就地修，台账见本条） |

**第 7 次执行追加的一行（fix 循环后重验时暴露的判据缺陷 · 由主 agent 修正并回写 `TASK.md`）**：

| task | 原文字面执行为何红 | 修正内容（落在权威副本 `TASK.md`） | 修正前 → 修正后 rc |
|---|---|---|---|
| **`T-FIX-04`**（`TD-065` · 夹具样本与被测集合脱钩） | 缺对夹具用 `ls flow-kit-bundle/skills/*/SKILL.md \| head -1` 取到字母序首个 `flow-architect/SKILL.md`（**不是** `PAIRS` 成员）⇒ `MISS=0` ⇒ 修复后的**正确**行为（汇总仍打印 `✅ 校验对 3/14 一致`）被判据报成 🔴「F6：缺一对文件仍 rc=0」⇒ `<verify>` 恒 rc=1、任务无法提交 | 夹具改为**从被测数据权威来源派生**：`grep -oE '\|flow-[a-z0-9-]+' flow-kit-bundle/flow-kit/reference/check-gate-sync.sh \| head -1` ⇒ `hidden="flow-kit-bundle/skills/${pair_skill}/SKILL.md"` + `[ -f ]` 前置（失败即打印「判据前置失败」）+ 诊断行 `（诊断）verify hides: …`；**其余断言、汇总 printf、bats/门禁段逐字不动** | **rc=1 → rc=0**（44 行判据；`verify hides: flow-kit-bundle/skills/flow-evolve/SKILL.md` · `real=21 full_fixture=0 missing_pair=1`） |

**第 8 次执行追加的一行（第 2 轮 fix 循环后重验时暴露的判据缺陷 · 由主 agent 修正并回写 `TASK.md`）**：

| task | 原文字面执行为何红 | 修正内容（落在权威副本 `TASK.md`） | 修正前 → 修正后 rc |
|---|---|---|---|
| **`T17`**（`TD-066` · 对照夹具候选面全自排除） | CHECK_REV 的「干净树 » 工作树模式必须 rc=0」**对照腿**只把被测脚本 + 空 `path-privacy-allowlist.txt` 提交进夹具 ⇒ tracked 面全属 `SELF_EXCLUDE` ⇒ 候选 N≥1 / 实际扫描 M=0 ⇒ 被 `T-FIX-06` 的 fail-closed 早退判红（`🔴 工作树模式在干净树上未 rc=0（rc=1）⇒ 对照不成立`）；**性质 = 夹具与 fix 后语义不一致，非生产件回归** | 夹具补入**非自排除**的 benign tracked 文件 `README.md`（`printf … > "$_sbx2/r/README.md"` + `TD-066` 溯源注记）；**其余断言、对照腿结构、摘要 printf 逐字不动** | **rc=1 → rc=0**（73 → 74 行判据） |

> **同轮工具面订正（`TD-067`）**：`reproduce-5-test.sh` 的 `extract_verify()` 原用行内子串匹配 `<verify>`，被 `T-FIX-06 <action>` 正文里的 `<verify>` 字样带偏 ⇒ 抽出 43 行废件、被记成 `T-FIX-06 🔴 rc=2`（`行 1: T-FIX-06-SUMMARY.md: 未找到命令` / `行 2: \`</action>'`）⇒ 改为**整行锚定**后复抽 **41 行 · 首行 `set -u; rc=0;` · `bash -n` 通过**；属**抽取器**缺陷（非判据、非生产件）。

上表三行的台账归属：`T-FIX-01` 判为 **TD-051 复发**（不新开 TD，登记于 `MINOR-DEFERRED.md:906-935`）；`T-FIX-02` **新开 `Tech-debt: TD-060`**（同类性质：验收判据自身的环境假设错误，登记于 `MINOR-DEFERRED.md:945-963`）；`T27`/`T29` 为**判据强度订正**（不新开 TD，由主 agent 就地修 `TASK.md` 并于第 5 次执行复核）。三条判据修正后**原样复跑均 rc=0**，并在第 5 次执行（REPRO4）中以 14 条判据整轮重跑复证（§附录 D）。

**判据版本 × 执行轮次 × rc 对照表（L3 第 9 轮 major 2 响应 · 消除「某个 rc=0 属于哪一版判据」的歧义）**：

| 判据 | 判据版本（修改前 → 修改后） | 修改前来源 | 修改后来源 | 修改前 rc | 修改后 rc | 产生 rc=0 的执行轮次 |
|---|---|---|---|---|---|---|
| `T17` | 旧「集合完备」策略 → 时间切点策略 | `9cbd098`（仓内） | `0dfb08f` | rc=1（策略缺陷） | rc=0 | 第 5 / 6 次执行（修正后判据集） |
| `T19` | `out=$(cmd 2>&1); rc=$?` → `rc=0; … \|\| rc=$?` | `9cbd098`（仓内） | `0dfb08f` | rc=0（但 strict 下 rc=1 · 与真红态不可区分） | rc=0（strict 亦 rc=0 / 37 行） | 第 5 / 6 次执行 |
| `T-FIX-01` | `export LC_ALL=C` → 4 行成因注释 + `rc=0`（其余 31 行逐字不动） | `0dfb08f` | 工作树（第 5 次执行期间修，未提交） | rc=1（locale 泄漏 · TD-051 复发） | rc=0 | 第 5 / 6 次执行 |
| `T-FIX-02` | 缺 `REPO_ROOT` 复位 → 补 `REPO_ROOT` + 沙箱末尾 `cd`（步骤/断言逐字不动） | `0dfb08f` | `c50ad42` | rc=1（cwd 泄漏 · TD-060） | rc=0 | 第 5 / 6 次执行 |
| `T27` / `T29` | 回归地板 `-ge 973` → `-ge 1009`（= 1012 − 3） | `c50ad42` | 工作树（第 5 次执行期间修，未提交） | rc=0（但判定力被削弱：允许 39 例静默消失） | rc=0（判定面收紧） | 第 5 / 6 次执行 |
| `T-FIX-04` | 夹具 `ls … \| head -1` → 从 `PAIRS` 派生 + `[ -f ]` 前置 | 判据侧缺陷随 fix 循环暴露（生产件 `521b21c`） | 工作树（第 7 次执行前修 · 随后 housekeeping 提交） | rc=1（夹具样本脱钩 · `TD-065`） | rc=0 | 第 7 次执行 |
| `T-FIX-03` / `T-FIX-05` | 无修改（**字面执行**） | — | — | — | rc=0 | 第 7 次执行 |
| 其余 8 条（`T05` / `T06` / `T11` / `T13` / `T20` / `T22` / `T24` / `T26`） | 无修改 | — | — | — | rc=0 | 第 1–4 / 5 / 6 / 7 次执行（同一文本） |

> **历史回执的时点前缀规则（同轮 major 2 收口）**：本报告内**未标「第 1–4 次执行」前缀**的旧数字（如 §2.5 的 `ok=976`）一律读作**修正前判据集的历史回执**，仅作原始证据保留（**不为口径改写数字**）；**当时（第 6 次执行）的基线口径 = §1.3 第 2/5 条 + §0 第 6 次执行行 + 附录 D-7**（1012 / 1011 · 修正后判据集 · **历史值**）；**当前权威基线 = 第 11 次执行 1064 / 1063**（见 §1.3 第 2/5 条与 §0 第 11 次执行行 · L3 第 14 轮 minor ② 统一口径）。

---

## 第 2 轮 · 性能测试

### 2.1 预算（REQUIREMENT 非功能性需求原文口径）

| 项 | 预算 | 出处 |
|---|---|---|
| `make check-path-privacy` | 单次运行 **≤ 5 秒**（扫 `git ls-files` 内容，不扫 `.git`）；**验证手段 = `time` 实测并记入 TEST.md**，超阈值即未满足 | `REQUIREMENT.md` §非功能性需求 |
| `make check-gate-sync` | **秒级**（修复后不得引入可感知延迟） | 同上 |
| `make check-nfr-portability` | 无显式明文预算（本次新增门禁）⇒ 按同口径要求「不引入秒级以上延迟」 | 本报告补充口径（不是放宽，是补登记） |

### 2.2 实测

| 项 | 实测（3 次 / 2 次 / 1 次） | 判定 |
|---|---|---|
| `make check-path-privacy` | **real = 2.830 s / 2.868 s / 2.826 s**（user 1.212/1.165/1.175，sys 1.774/1.862/1.799） | ✅ **达标**：均值 2.841 s，为预算的 **57%**，最差单次 2.868 s 仍留 43% 余量 |
| `make check-gate-sync` | **real = 0.053 s / 0.047 s** | ✅ 达标（秒级预算的 1/20 量级） |
| `make check-nfr-portability` | **real = 0.172 s** | ✅ 秒级内 |
| 全量 `make check`（含 976 用例 bats + 9 道门禁） | 见 §2.3 回执（阶段 4/5 多次实测均一次通过，无超时） | ✅ 无退步 |

**测量环境与 5 次补测（L3 第 2 轮 minor ① 响应）**：环境 = 同一台机器 `nproc=32`、运行前 `loadavg` = `6.04 / 6.48 / 6.52`、无并发测试进程、git 索引**热态**（前序 `make check` 已扫过同一工作树，非冷缓存）；计时用 `TIMEFORMAT='real=%R user=%U sys=%S'`。**5 次** `time make check-path-privacy`：real = **2.842 / 2.847 / 2.898 / 2.836 / 2.867 s**（min 2.836 · max 2.898 · 均值 2.858 ⇒ 预算 ≤5 s 的 **57%**），与上表 3 次口径一致（极差 0.062 s，远小于预算余量的 1%）⇒ **判定不变：✅ 达标**。复算命令 = `reproduce-5-test.sh` 门禁段 [D]（内部即 `time make check-path-privacy` ×5，并打印 nproc/loadavg）。

**处置后独立复测（L3 第 3 轮响应 · receipts §I）**：同一命令、同一环境（`nproc=32`、`loadavg` = `5.95 / 6.13 / 6.25`）再测 **5 次**：real = **2.876 / 2.822 / 2.850 / 2.834 / 2.871 s**（min 2.822 · max 2.876 · 均值 **2.851** = 预算 **57%**）⇒ 两次独立实测结论一致（波动 < 0.1 s，均远低于 5 s 预算），**判定不变：✅ 达标**。原始回执见 `PHASE5-RECEIPTS.md` §E（首轮）与 §I（处置后）。**时点限定（L3 第 10 轮 minor ③ 响应）**：本节各次数值（2.826–2.898 s 区间 · 均值 2.841 / 2.858 / 2.851 s）均为**第 1–5 次执行的历史值**；**终版性能基线 = 第 6 次执行 = 均值 2.937 s（§附录 D-7 · `loadavg` 6.94/6.83/7.13）**；**第 7 次执行更新：当前基线 = 均值 3.011 s（§附录 D-8 · `loadavg` 7.64/7.86/7.83）**，全部 ≤5 s 预算 ⇒ **性能结论不依赖版本口径**。

**负载差异说明（第 5 次执行 vs 第 1–4 次执行 · L3 第 8 轮 minor ③ 响应）**：第 5 次执行时本机 `loadavg` = **7.91 / 8.12 / 7.49**，高于第 1–4 次执行的 5.95 / 6.04 / 6.13 / 6.25 / 6.48 / 6.52（各轮记于 receipts §E / §I / §J-2）；对应 5 次均值 **2.895 s**（第 5 次）vs **2.851–2.858 s**（第 1–4 次）= **+0.037 ~ +0.044 s（+1.3% ~ +1.5%）**，方向与负载升高一致，属**同量级波动**。**判定不依赖负载归一化**：预算是**绝对阈值 ≤5 s**，五次单测**全部 ≤5 s**（最差 2.929 s，仍留 41.4% 余量），故不做负载折算、也不引入「按 loadavg 折算耗时」的口径（那会掩盖真实绝对耗时）。原始计时逐行见 §附录 D-2 与 receipts §J-2。

**第 7 次执行（fix 循环后重验 · 2026-09-25）性能回执**：`loadavg` = **7.64 / 7.86 / 7.83**（`nproc=32`），5 次 `time make check-path-privacy` real = **2.985 / 3.005 / 3.012 / 3.019 / 3.032 s**（min 2.985 · max 3.032 · 均值 **3.011 s** = 预算 ≤5 s 的 **60.2%**）⇒ **判定：✅ 达标**（最差单次仍留 39.8% 余量）。与前几轮均值的差异（+0.12 s vs 第 5 次 2.895 s、+0.07 s vs 第 6 次 2.937 s）方向与负载升高一致（7.64/7.86/7.83 > 6.94/6.83/7.13 > 5.95/6.04/6.13/6.25/6.48/6.52），属**同量级波动**；预算为**绝对阈值**，不做负载折算。原始逐行见 §附录 **D-8** 与 `PHASE5-RECEIPTS.md` **§O**。

**第 8 次执行（第 2 轮 fix 循环后重验 · 2026-09-25）性能回执**：`loadavg` = **6.40 7.21 8.07**（`nproc=32`），5 次 `time make check-path-privacy` real = **3.146 / 3.050 / 3.051 / 3.127 / 3.011 s**（min 3.011 · max 3.146 · 均值 **3.077 s** = 预算 ≤5 s 的 **61.5%**）⇒ **判定：✅ 达标**（最差单次仍留 38.5% 余量）。与前几轮均值的差异方向与负载升降一致，属同量级波动；预算为**绝对阈值**，不做负载折算。原始逐行见 §附录 **D-9** 与 `PHASE5-RECEIPTS.md` **§P**。

**端到端耗时实测（L3 第 4 轮 minor ① 响应 · 2026-09-24）**：`TIMEFORMAT='real=%R user=%U sys=%S'; time npx bats test/` ⇒ **real = 121.203 s**（user 81.050 / sys 44.707，rc=0）；`time make check` ⇒ **real = 258.890 s**（user 170.315 / sys 93.520，rc=0）＝ bats 主体 121.2 s + 其余 8 道静态/一致性/新门禁合计 ≈ **137.7 s**（`shellcheck` 68 文件为大头）。**与 change 前基线的对比**：本次新增门禁对 `make check` 的增量 = `check-path-privacy` 2.8 s + `check-gate-sync` 0.05 s + `check-nfr-portability` 0.17 s ≈ **3.0 s（占 1.2%）**，未改变「分钟级主体」的量级；`npx bats` 不受新门禁影响（用例数 973 → 976，+3）。原始回执 `PHASE5-RECEIPTS.md` §I。

### 2.3 工具输出（原文）

```
=== 2) 性能（NFR：check-path-privacy ≤5s；check-gate-sync 秒级）===
check-path-privacy run1: real=2.830 user=1.212 sys=1.774
check-path-privacy run2: real=2.868 user=1.165 sys=1.862
check-path-privacy run3: real=2.826 user=1.175 sys=1.799
check-gate-sync run1: real=0.053 user=0.019 sys=0.038
check-gate-sync run2: real=0.047 user=0.020 sys=0.036
check-nfr-portability run1: real=0.172 user=0.088 sys=0.131
```

### 2.4 退步项

**无退步。** 与阶段 4 的实测口径一致（**第 1–4 次执行口径**：`make check` 全绿、bats 976 收集 / 975 有效 · 0 失败；**当时基线 = 1012 收集 / 1011 有效（第 6 次执行 · 历史值）**；**当前权威基线 = 1064 / 1063（第 11 次执行）**，见 §1.3 第 2/5 条 —— 两版口径下均为 0 失败，结论不随基线变化），且新增的三道门禁把 `check` 的端到端耗时增量控制在**秒级**（`check-path-privacy` 2.8 s + `check-gate-sync` 0.05 s + `check-nfr-portability` 0.17 s ≈ 3.0 s，相对 bats 主体的**实测 121.2 s** 可忽略；`make check` 端到端实测 **258.9 s**，见 §2.2）。

### 2.5 全量权威回执（**第 1–4 次执行 · 修正前判据集** · 阶段 5 第 1 轮 · T13 判据修复后重跑）

> **时点前缀（L3 第 9 轮 major 2 响应）**：本回执是**第 1–4 次执行**的原始输出（当时基线 976 · **T27/T29 仍为旧地板 `-ge 973`**）—— **不是**当前基线；**当时基线（1012 / 1011 · 修正后判据集）**见 §1.3、§0 第 6 次执行行与附录 **D-7**；**当前权威基线 = 1064 / 1063（第 11 次执行）**，见 §1.3 第 2/5 条与附录 **D-12**。

```
npx bats test/     ⇒ rc=0 · ok=976 / not ok=0 / skip=0 · npx bats --count test/ = 976
make check         ⇒ rc=0（全部通过）
  ✅ bats: all tests passed                ✅ shellcheck: no errors found
  ✅ validate: staging coverage OK（源缺失 WARNING: 0）
  ✅ test 双源一致                          ✅ hooks 副本一致（漂移 0 · 6 个安装镜像）
  ✅ check-dist: dist 与源一致              ✅ check-gate-sync（3/14 对一致 · 17 预设名集合一致）
  ✅ 清单外命中 0 条                        ✅ NFR 兼容性判据通过（无新增 bash4-only / GNU-only）
```

> **数字口径注（L3 第 4 轮 major 4 响应）**：以上为**原始回执原样**（`ok=976` 是套件收集数，不为口径改写数字）；其中 **1 条是 TD-033 登记的 mock 用例** ⇒ 本报告的**有效用例口径 = 975**，AC-7 / AC-8 的结论面不得引用该条（详见 §1.3 第 5 条与 §回归保护缺口 2）。

---

**第 9 次执行（REPRO8 · 2026-09-25 · HEAD `bf3763f`）性能回执 —— ❌ 未达标**：`nproc=32` · `loadavg` = **8.08 / 6.86 / 6.40**，5 次 `time make check-path-privacy` real = **10.741 / 10.885 / 10.783 / 11.510 / 11.469 s**（max 11.510 · 均值 **11.078 s = 预算 221.6%**）⇒ 违反 `REQUIREMENT.md:495`（单次 ≤5 s）；判据 `TEST.md:248`「超阈值即未满足」· `:265`「绝对阈值、不做负载折算」⇒ 该次阶段 5 判定 **❌**（`PHASE5-RECEIPTS.md` §R-5）；归因（A/B + 微基准）见 §R-3。

**第 10 次执行（REPRO9 · 2026-09-25 · HEAD `280ffdc`）性能回执**：`loadavg` = **8.72 / 9.30 / 9.36**，5 次 real = **3.813 / 3.656 / 3.730 / 3.752 / 3.630 s**（max 3.813 · 均值 **3.716 s = 预算 74.3%**）⇒ ✅ 达标（`T-FIX-12` 批量化后 sys 由 ≈11.2 s 降到 ≈2.4 s；user 1.66–1.74）。

**第 11 次执行（REPRO10 · 2026-09-27 · HEAD `551e846`）= 当前权威性能回执**：`loadavg` = **6.73 / 7.38 / 7.86**，5 次 real = **3.489 / 3.666 / 3.660 / 3.613 / 3.615 s**（max **3.666 s** · 均值 **3.609 s = 预算 72.2%**；user 1.63–1.74 · sys 2.24–2.43）⇒ ✅ 达标；与第 10 次（74.3%）同档，波动 <0.2 s 属负载差异（loadavg 6.73–7.86 vs 8.72–9.36）。

## 第 3 轮 · 安全测试

### 3.1 依赖漏洞

| 项 | 实测 | 判定 |
|---|---|---|
| 根目录依赖清单 | **无** `package.json` / `package-lock.json` ⇒ 无 npm 依赖树 | ✅ |
| 子包 1：`flow-kit-bundle/brooks-lint/plugin/package.json` | `dependencies: {}`、`devDependencies: { "@anthropic-ai/sdk": "^0.52.0" }`、`peerDependencies: {}` | ✅ 运行时依赖 = 0 |
| 子包 2：`dsh-flow-kit/package.json` | `dependencies: {}`、`devDependencies: {}`、`peerDependencies: { "@deepseek-ai/cordis": "^4.0.1" }` | ✅ 运行时依赖 = 0 |
| `npm audit --production` | 两包均报 **`ENOLOCK`：This command requires an existing lockfile**（无 lockfile ⇒ 无法审计） | ⚠️ **工具不可用** ⇒ 以「运行时第三方依赖 = 0」作**量化替代**并明示（不假装已审计） |
| `node_modules` | 仓库内不存在 ⇒ 无可执行依赖树残留 | ✅ |

**结论**：**无运行时第三方依赖**，故「已知漏洞组件」面为 0（不是"未检查"，而是"不存在可被利用的依赖项"）；审计工具缺失面已明示。

**peer 依赖语义（L3 第 8 轮 minor ④ 响应 · 与本节上表同源实测）**：`flow-kit-bundle/brooks-lint/plugin/package.json` 的 **`devDependencies`** 含 `@anthropic-ai/sdk@^0.52.0`（**dev 面**，只在开发脚本 `scripts/*.mjs` 中使用，npm 打包时**不安装、不分发** —— 该文件**无** `peerDependencies` 键）；`dsh-flow-kit/package.json` 的 **`peerDependencies`** 含 `@deepseek-ai/cordis@^4.0.1`（child 插件 `dsh-flow-kit` 由**宿主** `@deepseek-ai/cordis` 装载 ⇒ peer 语义 = **由宿主提供、本仓不安装也不打包**；本仓无 `node_modules`、无 lockfile）。⇒ 两者**均不进入分发件的运行时**，本节「运行时第三方依赖 = 0」的结论不受影响。**残余面（明示）**：**peer 依赖的宿主侧版本兼容性未审计** —— 因无 `node_modules`/无 lockfile（`npm audit` ⇒ `ENOLOCK`），无法对 peer 面的漏洞公告做机器核对；该残余与工具面同源，一并归 **`Tech-debt: TD-056`**（v2 引入 lockfile 并接线依赖审计）。**口径修正留痕**：L3 第 8 轮把 `@deepseek-ai/cordis` 记为 `brooks-lint/plugin` 的 peer 依赖，实测该键位于 **`dsh-flow-kit/package.json`**（本节以实测文件内容为准）。

### 3.2 秘钥扫描

| 检查 | 实测 | 判定 |
|---|---|---|
| 真凭证模式（`AKIA[0-9A-Z]{16}` / `-----BEGIN … PRIVATE KEY-----` / `ghp_`/`gho_` / `sk-` / `xox[baprs]-` / `*_AUTH_TOKEN=<值>`） | **命中合计 0**（扫描面排除 `.git`/`node_modules`/`dist`/`.specs`） | ✅ |
| 命中的只是**变量名 + 占位值** | `test/test_l3_credential_resolution.bats` 的 `ANTHROPIC_AUTH_TOKEN="p1-tok"`、`FLOW_KIT_L3_AUTH_TOKEN="p3-tok"`；`test/test_l2_dispatch_mode.bats:237` 的 `f3-tok` | ✅ 非真实凭证 |
| 已跟踪的可疑文件名 | `.claude/l3.env.example`（**模板**）· `.specs/adr/023-dual-platform-l3-credential.md`（ADR 文档）· `test*/test_l3_credential_resolution.bats`（测试） | ✅ 均为应有形态 |
| `.gitignore` 覆盖 | `:9-15` = `.env` / `.env.*` / `*.key` / `*.pem` / `credentials*` / `*secret*` / `*_secret*`；`:72-75` 仅反允许 `!.claude/l3.env.example`，并注明真实 `l3.env` 绝不入库（真实凭证在 `~/.config/flow-kit/l3.env`，仓库外） | ✅ |
| 机器门禁 | `make check-path-privacy` rc=0（清单外命中 0）；探针注入 ⇒ rc=1 指名 `file:line` | ✅ |

### 3.3 SAST

| 工具/判据 | 实测 | 判定 |
|---|---|---|
| `make lint`（shellcheck，**error 级**） | `✅ shellcheck: no errors found`（扫描 68 文件） | ✅ |
| 构造扫描（bash4-only / GNU-only，`make check-nfr-portability`） | 在**变更集**（10 个 `.sh`）上 rc=0；空集守卫实测 rc=1 + `rc=3（未验证）` | ✅ |
| `eval` 面（注入类风险，AC-1） | 全仓 `*.sh` 命中 1 = **注释**（`runtime-edit-guard.sh:50`）；守卫改为纯参数展开 `${var/#\~/$HOME}` | ✅ |
| 未安装工具 | `semgrep` / `gitleaks` / `trufflehog` / `trivy` 均 MISSING ⇒ 以 shellcheck + 模式面 grep + 自研门禁替代 | ⚠️ 已明示（见 §3.5） |

### 3.4 OWASP Top 10（A01–A10）

> **读法（L3 第 3 轮 minor ② + 第 5 轮 minor ② 响应）**：下表**判定列一律指「替代面」**（模式面 grep + shellcheck + 自研门禁）；**工具面证据：无**（`semgrep` / `gitleaks` / `trufflehog` / `trivy` 本机未安装，`npm audit` 因 `ENOLOCK` 不可用）⇒ 表内 ✅ **不得**读作工具级通过，见下方「结论强度限定」与 **`Tech-debt: TD-056`**。**判定收紧规则**（第 5/6 轮）：因 `semgrep` / `CodeQL` / `gitleaks` / `trufflehog` / `trivy` **全部缺失**、`npm audit` 因 `ENOLOCK` 不可用 ⇒ **A01–A10 无任何条目具备独立安全工具面证据，本节不保留 ✅**（A08 虽由门禁 rc 直接证明，仍按「无独立安全工具面」标 ⚠️ 替代面）；工具缺失清单与可复算命令见 §3.5。

| 项 | 替代面判定 | 证据等级 | 证据 |
|---|---|---|---|
| A01 Broken Access Control | ⚠️ 替代面 | 双态注入实证 | 三道门禁 fail-closed：pre-commit（`make check-path-privacy` 未过即拒）、pre-push（ref 级拦截）、阶段门（`.done` 缺失时 `is_git_commit` 直接拒绝 —— 本次阶段 5 真实被拦）。**限定 ①**：阶段门分支仅在「完成标记缺失」时生效（`Tech-debt: TD-059`，见 §1.2 ③），标记存在但无效时放行；**限定 ②**：无 `semgrep`/`CodeQL` 级工具证据（`Tech-debt: TD-056`） |
| A02 Cryptographic Failures | ⚠️ 替代面 | 模式面扫描（工具级未验证） | 仓库内无秘钥（§3.2，模式面 grep 命中 0）；凭证只经环境变量/仓库外文件注入，不入库、不落日志值。**无** `gitleaks` / `trufflehog` 级工具证据（`Tech-debt: TD-056`） |
| A03 Injection | ⚠️ 替代面 | 双态注入实证 | AC-1：守卫内 `eval` 已消除（唯一命中是注释）；命令替换载荷探针实测不再执行；钩子对畸形 stdin fail-closed。**限定**：模式面 grep + 双态注入，无 `semgrep`/`Bandit` 级工具证据（`Tech-debt: TD-056`） |
| A04 Insecure Design | ⚠️ 替代面 | 双态注入实证 | 空允许清单 = 合法 rc=0、**但扫描不跳过**；变更集为空 ⇒ **rc=3「未验证」而非绿**（不制造假绿）；缺允许清单 ⇒ rc=1 指名路径。**限定**：证据来自自研判据的 rc，非独立设计审计 |
| A05 Security Misconfiguration | ⚠️ 明示缺口 | 已登记既有项 | 本仓 `core.hooksPath` 为空串 ⇒ git 不调用任何 hook（**TD-050**，已登记、本 change 范围外）；门禁仍可显式调用并生效 |
| A06 Vulnerable Components | ⚠️ 替代面 | 清单可验（审计不可用） | §3.1：两子包运行时依赖 = 0、仓库无 `node_modules`；但**无 lockfile** ⇒ `npm audit` 报 `ENOLOCK`，**未参与**判定 |
| A07 Identification & Auth Failures | ⚠️ 替代面 | 代码可验（模式面） | L3 凭证解析 env-first + 回退，日志只打印 `credential source: env` 或 `credential source: flow-kit`（不含值）；`l3-api.sh:93` 为唯一凭证相关输出。**限定**：代码可验（非扫描面），无工具级凭证卫生证据 |
| A08 Software & Data Integrity | ⚠️ 替代面 | 门禁 rc 实证（**无独立安全工具面**） | `check-dist`（分发件新鲜度）、`check-test-sync`/`check-hooks-sync`（副本一致性）、`.change-base` 变更集锚点、双层 allowlist 读序 —— 本次全部 rc=0 |
| A09 Logging & Monitoring Failures | ⚠️ 明示缺口 | 范围外明示 | 基础日志面 ✅（§5.1）；无外部告警通道（范围外明示） |
| A10 SSRF | ➖ 不适用 | — | 无服务端入站请求面；唯一外呼是 L3 评审 API，目标 base URL 来自显式配置（env/`l3.env`），非用户输入拼接 |

**无 🔴 项**；**判定收紧后：✅ 0 条 / ⚠️ 9 条（A01–A09）/ ➖ 1 条（A10）**，⚠️ 的成因分三类：**工具面缺失**（A01–A04 · A06 · A07 · A08，`Tech-debt: TD-056`）、**已登记明示范围外**（A05 = TD-050、A09 = 无告警通道）、**口径限定**（A01 另受 TD-059 限制；A08 仅门禁 rc 实证）。

> **本轮判定降级（L3 第 7 轮 major 3 / L2 R3 + 第 8 轮 major 3 响应 · 2026-09-24）**：本机**无任何独立安全扫描工具** ⇒ **第 3 轮安全实现面 = 未验证（无独立安全工具），不构成 AC 通过面证据**：本节 ⚠️ 一律读作「**替代面已做、工具面未做**」，**不计入 AC 通过面**；`A01`/`A03`/`A06`/`A07`/`A08` 的工具级验证为 **`Tech-debt: TD-056`**（v2 = 安装 `gitleaks` + `semgrep` 并接线 `make security-scan`）。**AC 覆盖判定不受影响**：`AC-1..AC-8` 无「安全工具面」类验收项，注入面由 `AC-1` 的双态注入实证承载（§1.1）。

> **结论强度限定（L3 第 2 轮 major 4 响应）**：本节 A01–A10 的 ✅/⚠️ **只代表「模式扫描（grep 面）+ shellcheck + 自研门禁（预提交 / 预推送 / 阶段门 / 脱敏 / NFR）」这一替代面的判定强度**，**不**代表 `semgrep` / CodeQL / `gitleaks` / `trufflehog` / `trivy` 级工具面的结论；`npm audit` 因无 lockfile 不可用（`ENOLOCK`）亦**未参与**任何判定。凡无「工具面 + 双态注入」双重证据支撑的条目，一律标 ⚠️ 而非 ✅（不把替代面结论写成工具面结论）。工具缺失面已由**说明性记事升级为「本 change 安全验收的未覆盖项」**：**`Tech-debt: TD-056`（v2 = 安装 `gitleaks` + `semgrep` 并接线 `make security-scan`；引入依赖时同步引入 lockfile）** —— 该项**不是**「已用替代面覆盖」的技术债，而是**安全验收面的未覆盖项**。**覆盖判定单列**：**安全工具面 0 / 10 未覆盖**（A01–A10 无任一条目具备独立安全工具证据 —— 见本节表内「证据等级」列与 §3.3 的 `command -v` 五项 MISSING 实测）。可复算命令随 §3.1–§3.3 落档（工具面 `command -v` 实测、凭证文件名面 `git ls-files | grep -iE`、`make lint`、`make check-path-privacy` 自证行、AC-6 探针注入 ⇒ rc=1）。

### 3.5 安全面残余（记事）

1. 本机缺 `semgrep`/`gitleaks`/`trufflehog`/`trivy` ⇒ 秘钥与 SAST 以「模式面 grep + shellcheck + 自研门禁」承担；**工具升级后可复算**（扫描命令已落档于本报告 §3.2/§3.3）。**定性（L3 第 8 轮 major 3 响应）**：第 3 轮安全实现面 = **未验证（无独立安全工具）**，**不构成 AC 通过面证据**；安全工具面覆盖 = **0 / 10**，以 **`Tech-debt: TD-056`**（本 change 安全验收的未覆盖项 · v2 = 装 `gitleaks` + `semgrep` 并接线 `make security-scan`）登记。
2. `npm audit` 因缺 lockfile 不可用 ⇒ 已用「运行时依赖 = 0」量化替代；若后续引入依赖，应同时引入 lockfile 并接线审计。
3. TD-050（hooks 部署不尊重 `core.hooksPath`）仍是安装面残余，**本 change 内不改**（已登记，理由见 `CONTEXT.md`）。

**未安装工具清单与可复算命令（L3 第 5 轮 minor ② 响应）**：

```bash
# ① 工具面实况（期望：五项均 MISSING）
for t in semgrep gitleaks trufflehog trivy codeql; do printf '%-10s %s\n' "$t" "$(command -v "$t" || echo MISSING)"; done
# ② lockfile 实况（期望：无 package.json ⇒ npm audit 不适用）
ls package.json package-lock.json 2>&1; npm audit --production 2>&1 | tail -2   # 期望：ENOLOCK
# ③ 替代面（本次实际使用的全部扫描面）
make lint                                    # shellcheck（error 级）
grep -rnE '\beval\b' --include='*.sh' .      # 注入面（期望：唯一命中为 runtime-edit-guard.sh:50 注释）
git ls-files | grep -iE '\.env|secret|credential|\.pem|\.key|id_rsa'
make check-path-privacy                      # 脱敏门禁 + 自证四行
```

---

## 第 4 轮 · 兼容性测试

### 4.1 跨浏览器 —— ❌ 不适用
本仓无任何浏览器端产物（纯 Bash/Markdown 分发件 + git hook）。**理由**：零 web 运行时、零前端资源。

### 4.2 视口 —— ❌ 不适用
同上（无 UI/无 CSS）。

### 4.3 数据迁移 —— ❌ 不适用（无 schema）
替代覆盖（同类「旧数据 ↔ 新代码」风险）：**允许清单读序**的兼容与 fail-closed 三态 —— 常设路径 > change 副本 > 两者皆缺（⇒ exit 1 并指名缺失路径）；空清单 ⇒ rc=0 合法空基线（`T22`）；两者皆缺 ⇒ rc=1（`T21`/`T23`）。**实测 rc 与期望一致**。

### 4.4 跨版本 / 跨编码

| 项 | 实测 | 判定 |
|---|---|---|
| bash 3.2（macOS）与 bash 4+ 语法 / 不得新增 GNU-only、`declare -A` 依赖 | `make check-nfr-portability` 在**变更集口径**（含新增行与未跟踪文件）rc=0；豁免 `stat -c … || stat -f …` 慣用法按成分删除（不是整行豁免） | ⚠️ **仅静态面通过**（**不构成 AC-8 通过证据**）/ **macOS 实机未验证（TD-055）** |
| macOS **实机**运行 | 本机为 Linux，**未在 macOS 实跑** ⇒ 结论以静态判据为限 | ⚠️ 残余（非阻断；与 AC-8 的判据口径一致） |

> **AC-8 结果列口径（L3 第 5 轮 minor ③ + 第 8 轮 major 1 响应）**：§1.1 测试矩阵的 **AC-8 判定 = ⚠️「有条件通过（仅静态面）」**（change 期判定列与长期回归列同为 ⚠️；**跨 OS 实机面 = 未验证，不构成通过**），本节唯一 ✅ 是**静态判据通过**（`make check-nfr-portability` 在变更集口径 rc=0），**不含** macOS 实机（`Tech-debt: TD-055`，仍开放）这层含义；长期回归保护面已由 `T-FIX-01`（`5ee4ebc`）补齐（`Tech-debt: TD-053` 已闭合，见 §1.1）。
| 编码/locale 矩阵 | `LC_ALL=C` + `-t utf-8` ⇒ rc=0 · `LC_ALL=C` **无 `-t`** ⇒ rc=1（`iconv: illegal input sequence at position 0`，= **TD-051** 已登记） · `LC_ALL=C.UTF-8` ⇒ rc=0 · ambient（`LANG=zh_CN.UTF-8`）⇒ rc=0 | ✅（缺陷形态已登记）（**仅 Linux 本机实测 · macOS 未验证（`Tech-debt: TD-055`）** · L3 第 10 轮 minor ④ 响应） |
| 判据自身的地域作用域 | T27 判据在调用 `npx bats` **之前**显式 `unset LC_ALL`（`[ -n "${LANG:-}" ] \|\| export LANG=C.UTF-8`），T29 判据整体**不导出** `LC_ALL=C`（改用前缀式 `LC_ALL=C cmd …`）—— 复核实测：全 `TASK.md` 内 10 处 `export LC_ALL=C` 全部位于**不调用 bats** 的判据中（T13/T26 等只跑 grep/`make check-path-privacy`） | ✅（**仅 Linux 本机实测 · macOS 未验证（`Tech-debt: TD-055`）**） |
| 副本/镜像一致性（跨载体「版本」一致性） | `make check-test-sync`（`test/` ↔ `flow-kit-bundle/test/`）rc=0 · `make check-hooks-sync`（六安装镜像 0 漂移）rc=0 · `make check-dist`（dist 与源一致）rc=0 | ✅ |

---

## 第 5 轮 · 可观测性验证

### 5.1 日志

| 要求 | 实测 | 判定 |
|---|---|---|
| 关键路径入口/出口/异常均有输出 | `make check-path-privacy` 自证行七要素：`扫描面: 工作树（git index：已 add / 已提交）` / `允许清单来源: …/path-privacy-allowlist.txt` / `允许清单 N 条` / `候选文件 N 个` / `实际扫描 M 个` / `命中合计 N 条` / `清单外命中 N 条`；`make {check-gate-sync,check-nfr-portability}` 各有 `🔍 …` 入口行与 ✅/🔴 出口行 | ✅ |
| 失败必须可归因到 `file:line` | T28 修复后：`check-nfr-portability` 违规行逐文件 `file:line`（不再打印拼接流偏移量）；本次注入实测得到 `sync-hooks.sh:382` 精确归因；`check-path-privacy` 命中行同样 `file:line` | ✅ |
| **不含 PII / 秘钥 / token** | `flow-kit-bundle/hooks/stop/lib/l3-api.sh:93` 只打印 `[l3-review] credential source: env|flow-kit`；`common.sh:293` 注释明写「stderr 提示只含 env 变量名（不含值）」；`grep -nE 'echo|printf' l3-api.sh \| grep -E 'TOKEN\|API_KEY\|AUTH'` 命中项全部是**变量名提示文案**，无值插值 | ✅ |
| 错误日志含足够上下文 | `[archive-commit-gate] test failed, commit rejected` · `🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（make check-path-privacy 未通过）` · `🔴 脱敏越界（非本 change 工件/台账 ⇒ 停止并升级为新 task）：<files>` · `🔴 AC-8 时点变更集为空（相对锚点 HEAD）⇒ 兼容性判据 rc=3（未验证）` | ✅ |

### 5.2 指标 / 链路追踪 —— ❌ 不适用
无长驻进程、无服务端、无请求链路。替代：`make check` 的 9 道门禁 rc 作为一次性健康信号。

### 5.3 告警 / 健康检查 —— ⚠️ 部分
- ✅ 门禁 rc **fail-closed**（异常即非零，可被 CI/人工直接消费）；`check-path-privacy` 的 fail-closed 读序连"文件缺失"都不放行。
- ⚠️ 无外部告警通道（无 Slack/邮件/webhook 集成）——**明确不在本次范围**（REQUIREMENT 未要求）。

**结论**：基础日志与归因面 ✅ 达标；指标/追踪/告警按「无服务端」裁剪并逐项给出理由。

---

## 新增测试登记

本 change **未新增** bats 文件；对既有套件做了 8 处修改（`git diff --numstat 534e3e8..HEAD -- test/`）。**⇒ 第 5 次执行订正（上一行是第 1–4 次执行时点的历史事实，保留不抹除）**：阶段 4 的两个 fix 任务交付后，本 change 实际**新增 4 个 bats 文件 / 36 例**（`T-FIX-01` 25 例 + `T-FIX-02` 11 例），逐文件登记见下表「第 5 次执行新增登记」。**⇒ 第 7 次执行补记（fix 循环）**：再增 **13 例**（`T-FIX-03` = `6e39cfb` 隐私门禁 11 例 + `T-FIX-04` = `521b21c` gate-sync 2 例；`T-FIX-05` = `6e94d60` 以钉住断言改写既有用例 ⇒ **+0**），逐行见下表「第 7 次执行新增登记」。**⇒ 第 8 次执行补记（第 2 轮 fix 循环）**：再增 **4 例**（`T-FIX-06` = `421640a`：`test_path_privacy_gate.bats` **20 → 24**，F-19/F-20 各坏/好双态；F-18 的错因归属断言并入既有用例 ⇒ +0），逐行见下表「第 8 次执行新增登记」。

| 文件 | 变更 | 目的（AC） |
|---|---|---|
| `test/test_archive_commit_gate.bats` | +16 / −0 | pre-push glob 与 `validate_staging_coverage` 的接线固化（AC-3 / TD-048） |
| `test/test_auto_checkpoint.bats` | +22 / −9 | AC-7：断言对象改为 SUT（非 jq），并加「让 SUT 失败 ⇒ 必红」证据 |
| `test/test_check_gate_sync.bats` | +7 / −6 | AC-4 / T15：删除 `-ne 2` 容忍式断言，改为 `exit 0` 精确断言 |
| `test/test_combined_metric.bats` | +14 / −4 | AC-7：消除"除 1 外一切结果"恒真断言，改为注入残留文件必红 |
| `test/test_correction_hygiene.bats` | +5 / −5 | T11 相关口径与路径处理一致性 |
| `test/test_independent_review_model.bats` | +6 / −0 | AC-7：先断言文件存在，再断言内容（删文件 ⇒ 必红） |
| `test/test_l3_review_defects_2026_09.bats` | +1 / −1 | 与 L3 缺陷面口径对齐 |
| `test/test_lessons_cleanup.bats` | +13 / −3 | AC-7：移除过期 skip，断言 `exit 0`（唯一可机器验证分支） |

**第 5 次执行新增登记（本 change 的实际新增 bats · 每个文件在 `flow-kit-bundle/test/` 下都有由 `make check-test-sync` 强制一致的镜像副本）**：

| 文件 | 行数 | `@test` 例数 | 对应 task / commit | 覆盖的生产件或判定面 |
|---|---|---|---|---|
| `test/test_path_privacy_gate.bats` | 163 | **9** | `T-FIX-01` · `5ee4ebc` | `check-path-privacy.sh`（AC-6）：探针注入 ⇒ rc=1 指名 / 空清单 ⇒ rc=0 / 缺清单 ⇒ rc=1 / fail-closed 读序 / 「清单外命中」口径 —— **补齐 TD-053 的常设回归网** |
| `test/test_runtime_edit_guard.bats` | 113 | **9** | `T-FIX-01` · `5ee4ebc` | `runtime-edit-guard.sh`（AC-1）：相对路径 ⇒ rc=2 / 绝对路径 ⇒ rc=0 / 双态注入判活 —— **补齐 TD-053** |
| `test/test_nfr_portability_gate.bats` | 127 | **7** | `T-FIX-01` · `5ee4ebc` | `check-nfr-portability.sh`（AC-8 静态面）：空变更集 ⇒ rc=3 / GNU-only 构造注入 ⇒ rc≠0 / `bash -n` 面 —— **补齐 TD-053** |
| `test/test_review_gate_validity.bats` | 197 | **11** | `T-FIX-02` · `6cff7a2` | 阶段门**标记有效性**（`Tech-debt: TD-059` 闭合 · ADR-029）：A 无标记 / B 合格 6 键 / B2 口径相悖 / B3 `touch` 空 / B4 缺 `L3_verdict` / B5 值域非法 / C 无 `.flow-active` / gate 未开反面对照 / 函数级三例 —— 无效标记**一律必须拒绝** |
**第 7 次执行新增登记（fix 循环 · 每条均有 `flow-kit-bundle/test/` 下的双源镜像）**：

| 文件 | 行数 | `@test` 例数 | 对应 task / commit | 覆盖的生产件或判定面 |
|---|---|---|---|---|
| `test/test_path_privacy_gate.bats` | 306 | **20**（9 → 20） | `T-FIX-03` · `6e39cfb` | `check-path-privacy.sh`（AC-6 · **`TD-064` 闭合**）：F1 坏 `TMPDIR` ⇒ rc≠0 / F1 `cp` rc 断言 / F2 非 git 目录 ⇒ rc≠0 / F2 index 空仓 ⇒ rc≠0 / F2 自证候选数 / F3 二进制两模式统一 / F4 注释口径单点 / F5 单一 trap + 各面好态对照 —— **机械故障面与 0 候选面 fail-closed** |
| `test/test_check_gate_sync.bats` | 92 | **7**（5 → 7） | `T-FIX-04` · `521b21c` | `check-gate-sync.sh`（AC-4 · **`TD-065` 判据修复**）：缺一对 prompt/skill ⇒ rc≠0 且汇总**不打印**「✅ … 一致」（`🔴 MISSING` + 覆盖度分母 = 实际比对对数）/ 完整夹具 ⇒ rc=0 且覆盖度 = 3/14 |

**第 8 次执行新增登记（第 2 轮 fix 循环 · 每条均有 `flow-kit-bundle/test/` 下的双源镜像）**：

| 文件 | 行数 | `@test` 例数 | 对应 task / commit | 覆盖的生产件或判定面 |
|---|---|---|---|---|
| `test/test_path_privacy_gate.bats` | 394 | **24**（20 → 24） | `T-FIX-06` · `421640a` | `check-path-privacy.sh`（AC-6 · **F-19/F-20 闭合**）：自排除后候选面归零 ⇒ 坏态 rc≠0 + 失败面自证（候选 N / 实际扫描 M / 自排除 N−M）+ 好态对照 / 临时件不可写（`TMPDIR` 指向不可写路径）⇒ 坏态 rc≠0 且报文归因 + 好态对照 / F-18 错因归属断言（`SCAN_SURFACE` 口径） |

**基线演进（与 `.specs/STATE.md:48-51` 同源 · 第 5 次执行实测）**：**976**（T29 收口：`npx bats --count test/` = 976 / 有效 975）→ **1001** = 976 + **25**（`T-FIX-01` = `5ee4ebc`）→ **1012** = 1001 + **11**（`T-FIX-02` = `6cff7a2`）→ **1023** = 1012 + **11**（`T-FIX-03` = `6e39cfb`）→ **1025** = 1023 + **2**（`T-FIX-04` = `521b21c`；`T-FIX-05` = `6e94d60` +0）；**第 7 次执行（REPRO5）实测** `npx bats --count test/` = **1025**、`npx bats test/` = **ok=1025 / not ok=0 / skip=0**、有效用例 = **1024**（1 例 TD-033 mock 不计，§1.3 第 5 条）。

**新增判定力的另两种承载形式**（不属于 bats，但同属回归面）：
1. **change 期判据**：19 条（`T02/05/06/11/13/17/18/19/20/21/22/23/24/25/26/27/28/29`），原文在 `TASK.md` 各 `<verify>`，归档后仍在仓内可复算（本次全部复跑 rc=0）。
2. **常设门禁**：`make check-gate-sync` / `check-path-privacy` / `check-nfr-portability`（本次接线进 `make check`，见 §回归保护）。

---

## 回归保护

**常设（每次 `make check` / pre-push 都跑）**：`test`（**1064 收集 / 1063 有效 —— 含 1 条 TD-033 mock，不计入 AC 结论面**（L3 第 10 轮 minor ① + 第 14 轮 minor ② 收口：所有引用该数字的结论按此读）· **第 11 次执行实测**；演进 976 / 975（第 1–4 次执行）→ 1012 / 1011（第 5–6 次）→ 1025 / 1024（第 7 次）→ 1029 / 1028（第 8 次）→ **1064 / 1063**（第 11 次））· `lint`（shellcheck error 级）· `check-validate`（**321 文件 / 漏配 0 / 源缺失 0**，期望 315 · 第 5 次执行实测；第 1 轮为 317 / 311）· `check-test-sync` · `check-hooks-sync`（六镜像）· `check-dist` · `check-gate-sync` · `check-path-privacy` · `check-nfr-portability`。

**change 期（归档后按需复算）**：19 条判据 + 本文 §1.4 的 8 条边界/错误路径。

**已识别的回归保护缺口（记债，不假装覆盖）**：
1. ~~**TD-053**：`check-path-privacy.sh` / `check-nfr-portability.sh` / `runtime-edit-guard.sh` 无常设 bats 用例~~ ⇒ **已闭合（`T-FIX-01` = `5ee4ebc`）**：三件各配常设 bats（9 / 7 / 9 例，本轮实测全绿，见「新增测试登记」）。
2. **TD-033**（仍开放）：`test_gate_config_presets.bats` 的 mock 自证（旧语义 `"independent"`）⇒ 该文件不得作为 gate_config 语义的回归证据。
3. **TD-050**（仍开放）：本仓 `core.hooksPath` 为空 ⇒ git 不调用 hook（门禁需显式调用或经 DSH 装载面生效）。
4. **TD-060**（判据侧 · 已闭合）：`T-FIX-02` 判据出 `mktemp -d` 沙箱后未回仓根 ⇒ 判据自身的 cwd 假设错误（非产品缺陷），已就地修复并回写 `TASK.md`（§1.7）。

**回滚点**：`.change-base` = `534e3e842fc900045f39492badc66eabe3ffd4c4`；AC-8 的判据以「变更集」为口径 ⇒ 本 change 的基线不污染后续 change。

> **长期回归保护的判定（L3 第 4 轮 major 1/2 响应 · 第 5 次执行订正）**：本 change 的**长期回归保护在第 1–4 次执行判为「未达标」**（历史记录，保留不抹除：① 3 件生产件（`check-path-privacy.sh` / `check-nfr-portability.sh` / `runtime-edit-guard.sh`）在 `test/` 树 0 引用，归档后其判定力只由 change 期判据承载（`Tech-debt: TD-053`）；② 阶段门的「拒绝」在 commit 路径上只在**完成标记缺失**时成立（`Tech-debt: TD-059`））。**⇒ 第 5 次执行（REPRO4）订正为「达标」**：① `T-FIX-01` = `5ee4ebc` 为三件生产件补齐常设 bats（9 / 7 / 9 例，本轮实测全绿）⇒ **`Tech-debt: TD-053` 已闭合**；② `T-FIX-02` = `6cff7a2` 把阶段门的判定由「标记**存在**」改为「标记存在**且有效**」（ADR-029）⇒ **`Tech-debt: TD-059` 已闭合**，沙箱六态实测 A rc=2 / B rc=0 且 commit 真生效 / **B2·B3·B4 一律 rc=2** / C rc=0（§1.2 ③）。常设 bats 的活性**不是自证**：`T-FIX-01` 判据在本轮把两件生产件临时替换为 `exit 0` 恒绿桩 ⇒ 12 例当场转红（含 `^not ok` 行），`cp -f` 还原 + `cmp -s` 逐字节一致后回绿（附录 D 判据步骤 7）。仍开放的基础设施面债：**TD-055**（无 macOS 实机）· **TD-033**（mock 自证）· **TD-050**（`core.hooksPath`）。

---

## 阶段 5 发现与处置（修代码优先协议）

| # | 严重度 | 发现 | 处置 |
|---|---|---|---|
| 1 | 🟡 | **新门禁与 AC-1 守卫无常设 bats 回归**：`grep -rln 'path-privacy' test/` = 0、`grep -rln 'nfr-portability' test/` = 0、`runtime-edit-guard` 在 `test/` 树 0 命中 ⇒ 其判定力只由 change 期判据承载 | **`Tech-debt: TD-053`**。不就地补测试的理由：`test/**` 属**源面**且 `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/**` 整棵入分发件（`package-dsh-plugin.sh`「零丢失整棵 bundle」）⇒ 新增用例会迫使重跑 `make test-sync` + 重建 dist/tarball，并令 AC-8 已落档的 976 基线口径整体失效（违反本 change「T24 之后不再改动源面」的次序硬约束，同 TD-051 的处置口径）。缓解事实：两道新门禁已**接线进 `make check`**（"坏成红"会立刻暴露），且 T21/T22/T23/T25/T26 判据已用双态注入验证过判定力 |
| 2 | 🟡 | **T13 判据「自造红」**：产品门禁本体头部注释（T22 追加）含拼接探针字面，产品按 `SELF_EXCLUDE` 整文件排除自己，而 T13 判据刻意不排除任何文件 ⇒ 复跑 rc=1 报「脱敏越界」 | **`Fixed in: .specs/health-fix-2026-09b/TASK.md`**（T13 `<verify>`：按**逐条精确字面**豁免该合成探针账号名，**不**抄产品整文件 `SELF_EXCLUDE`）+ 双分支注入复证判别力仍在 + `L-147` / `TD-052` 登记 + `MINOR-DEFERRED.md` 复核记录 |
| 3 | ℹ️ | 本机缺 `semgrep`/`gitleaks`/`trufflehog`/`trivy`；两子包无 lockfile ⇒ `npm audit` 不可用 | **明示 + 量化替代**（§3.1/§3.5）：运行时依赖 = 0；扫描命令落档可复算。不记为缺陷 |
| 4 | ℹ️ | TD-033（mock 自证）、TD-050（hooks 不尊重 `core.hooksPath`）在本次测试面复现 | **`Not-applicable`（本 change 范围外，已登记）**；§1.1 的证据链已避开这两个不可信面 |
| 5 | 🟡 | **L2 审查档自带脱敏越界（本阶段自造红）**：`INDEPENDENT-REVIEW-5.md:9` 把仓库根写成真实账号路径、`:18` 的合成探针写成整形态 ⇒ 一旦 `git add`（进入 `git ls-files` 扫描面）即令 `make check-path-privacy` 报**清单外命中 1 条**（实测 rc=2，归因 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md:18`） | **`Fixed in: .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`**（`:9` → `<repo>`；`:18` → 按 **L-137** 拼接形态「`/home/` + `zz-path-probe` + `/`」，判定与四要素未改动）；复验：T13 判据 rc=0（`✅ 脱敏完成：授权面外命中 = 0`）+ `make check-path-privacy` 清单外命中 **0** rc=0。根因（派发面缺脱敏条款）登记 **`TD-054`** + **`L-149`** |
| 6 | ℹ️ | **无 CI / 无 macOS runner**：跨 OS 兼容性只有静态判据（`make check-nfr-portability`），macOS 实机行为（locale / `iconv` / 内建命令差异）未被机器验证 | **`Tech-debt: TD-055`**（基础设施面，v2）；本 change 以 §4.4 的 ⚠️ 残余行显式承认，不伪装成已验证 |
| 7 | 🟡 | **L3 第 2 轮 major 1/2：回执数字与 change 期判据不可从工件内部复算**（「976 / `make check` 全绿」只有汇总数字；三条 0 引用的生产件只给 task id，判据是否恒绿/漂移无从确认） | **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh`**（新增·可执行：awk **原样抽取** TASK.md 判据后逐条实跑记 rc，含 `--criteria-only` / `--gates-only` / `--only`）+ **`Fixed in: .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`**（原始输出存档：12 条判据 rc + stdout + 门禁回执 + 抽取命令；第 3 轮补 §0/§H/§I）。判别力实证：T17 于本轮**确实转过红**（新审查档触发旧断言）⇒ 非恒绿；注入 `SELF_EXCLUDE` ⇒ rc=1 指名该档，还原 ⇒ rc=0；第 3 轮新增工件里的 `sed -i` 又被 T29 与 `check-nfr-portability` 当场判红指名（§I）⇒ 判据对**新代码**同样有效。TD-053（常设 bats 缺失）仍按 `Tech-debt` 保留 |
| 8 | 🟡 | **L3 第 2 轮 major 3：`rc=0` 是字面执行还是修正后执行？修正是否回写权威副本？** | **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §1.7**（判据修正台账）+ **T17 的修正已回写 `TASK.md`**（时间切点策略，重建后 rc=0 73 行）；T19 的 `set -e` 陷阱用 strict 对照实验量化（rc=1 / 19 行 / 无 🔴 报文）⇒ 不回写、升 **`Tech-debt: TD-057`** |
| 9 | 🟡 | **L3 第 2 轮 major 4：安全轮次结论循环论证**（工具缺失面下仍给 OWASP ✅/⚠️） | **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §3.4**（加「结论强度限定」：✅/⚠️ 仅代表**替代面**，工具面结论一律不下）+ **`Tech-debt: TD-056`**（工具缺失面由记事升为基础设施债，与 TD-053 同优先级） |
| 10 | ℹ️ | **L3 第 2 轮 minor ①–⑤**（性能测量条件与 5 次统计 / UAT ③ 依赖不可逆历史态 / TD-033 与 AC-4 证据面 / 973→976 逐项归因 / L 编号无出处） | **`Fixed in: TEST.md`**：§2.2（环境 + 5 次统计）· §1.2 ③（标注历史记录 + 可构造等价复现）· §1.6 ②（TD-033 不影响 AC-4 的 5 用例双态）· §1.3 ④（973 → 976 逐项归因 + 复算命令）· 文末「L 条目索引」 |

| 11 | 🟡 | **L3 第 3 轮 major 1：核心数字仍不可从工件内复算**（审查信封只把补充产物**前 3000 B** 送进提示词 ⇒ 写在 `PHASE5-RECEIPTS.md` 第 100 行之后的原始 stdout 对审查者不可见，被判「回执是截断件」） | **`Fixed in: .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`**（新增 **§0「最小复算证据（索引与结论）」**：结论 + 两条一键复算命令 + 逐面结果表，落在 3000 B 预算内；§A/§B 原始存档保留在后）+ **`Fixed in: TEST.md`**（头部两条复算入口 + 本节）+ **`L-151`** 登记（给外部审查者的证据必须「倒置金字塔」） |
| 12 | 🟡 | **L3 第 3 轮 major 2：三个生产件（`check-path-privacy.sh` / `check-nfr-portability.sh` / `runtime-edit-guard.sh`）在 `test/` 树 0 引用 ⇒ 常设回归网缺失** | **`Tech-debt: TD-053`**（与 #1 同源，L3 给出「补 bats」或「明确把长期回归保护判为未达标」两条路）⇒ 本 change 走第二条：**显式声明「长期回归保护未达标」**，并把这句连同 TD-053 一并交 **阶段 7（integration）triage**，不得在归档后遗忘。§C 已给出三条 0 引用的可复算证据与不补测试的次序理由 |
| 13 | 🟡 | **L3 第 3 轮 major 3：UAT ③（DSH 阶段门真实拦截）依赖不可逆历史事件，等价复现「无脚本、无命令」** | **`Fixed in: .specs/health-fix-2026-09b/reproduce-phase-gate.sh`**（新增·可执行：沙箱 `mktemp -d` + `git init` + 夹具，用 stdin JSON 真实调用 PreToolUse 门禁；五层状态 A/B/B2/B3/C + 判别子）+ **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh`**（新增 **[F] 阶段门沙箱复现** 步）+ **`Fixed in: PHASE5-RECEIPTS.md §H`**（原始输出存档）+ **`Fixed in: TEST.md §1.2 ③`**（改为「运行脚本即可复现」）。副产品：本轮实测反推出 **TD-058 / TD-059** 两个新缺陷（见 #16/#17） |
| 14 | 🟡 | **L3 第 3 轮 major 4：T19 判据 `set -e` 陷阱**（`out=$(cmd 2>&1); rc=$?` 在 `set -e` 下命令失败即退出 ⇒ 真红态与早退态同码 rc=1，只能靠有无 `🔴` 报文区分） | **`Fixed in: .specs/health-fix-2026-09b/TASK.md`**（T19 `<verify>` **4 处**改为「先置零再捕获」`rc=0; out=$(…) || rc=$?`，块尾加严格模式约定注释）⇒ 修正后 strict 运行 rc=0 / 37 行（修正前 rc=1 / 19 行 / 无 `🔴` 报文）；§1.7 台账 T19 行由「不回写」改为「**已回写**」 |
| 15 | 🟡 | **L3 第 3 轮 minor ①：`npx bats` 原始 TAP 未附 + `T27-SUMMARY.md` 陈旧「973 ok」口径交错** | **`Fixed in: PHASE5-RECEIPTS.md §B-2`**（TAP 逐项计数命令与结果 `^ok` 976 / `^not ok` 0 / 显式 skip 0）+ **`Fixed in: TEST.md §1.3`**（第 2 条指向 §B-2、第 5 条给出 973→976 逐项归因）+ 交叉引用 `.specs/health-fix-2026-09b/T27-SUMMARY.md:22/:25/:76` 与 `T26-SUMMARY.md:152/:154` **既有的口径注记**（973 = 变更前基线 / 各任务执行期的实测值，非篡改，无需改写文档） |
| 16 | 🔴 | **L3 第 3 轮实测副产品 · TD-058：`HOOK_BASE_DIR` 语义在两家族间不一致** ⇒ PreToolUse 侧解析到不存在的 `…/stop/lib/common.sh` 时 **fail-close 拒绝一切 commit**，且外观与「门禁严格」不可区分 | **`Tech-debt: TD-058`**（本 change 不修：`flow-kit-bundle/hooks/**` 语义变更需 ADR，且 AC-1..AC-8 未覆盖）；已登记 `.specs/CONTEXT.md`；复现脚本内注释固化「不得覆盖 `HOOK_BASE_DIR`」 |
| 17 | 🔴 | **L3 第 3 轮实测副产品 · TD-059：阶段门在 commit 路径上是「完成标记是否存在」的判定** ⇒ 标记**一旦存在**，6 键 KVP 值域校验、`MIN_MEANINGFUL_LINES=6`、Tier-2（标记口径 vs 审查档口径）**全部不可达**；`touch` 空文件即可放行；唯一防线只做**命令文本**匹配（拼接写法/非 bash 工具可绕过） | **`Tech-debt: TD-059`**（🔴 最高优先级技术债；v2 修法 = Gate3 复用 Tier-1 校验，把「存在但无效」并入同一拒绝分支 + `touch`/残缺标记必须仍拒绝的 bats）；已登记 `.specs/CONTEXT.md` + `L-152`；本 change 的处置 = **显式缺口实证**（`reproduce-phase-gate.sh` 的 B2/B3 用 `check_gap()` 记录，⚠️ 标注，**不得读作通过**） |
| 18 | 🟡 | **L3 第 3 轮 minor ②③④：§3.4 的 ✅ 可能被读成工具级通过 / TD-033 mock 计入 976 / 第 4 轮标「✅ 必跑」而 macOS 未实跑** | **`Fixed in: TEST.md`**：§3.4（表头改「替代面判定」+ 明示「工具面证据：无」）· §1.3 第 5 条（**有效用例 = 975**，1 条 TD-033 mock 不计入 AC-7 结论面）· §0 第 4 轮行（改「✅ 静态面必跑 / ⚠️ macOS 实机未验证（TD-055）」） |

| 19 | 🟡 | **L3 第 4 轮 major 1：AC 覆盖 8/8 与「3 件生产件 0 引用」并存 ⇒ 结论可能被读作长期回归保障** | **`Fixed in: TEST.md`**：§1.1 新增「**结论口径声明**」（本表 ✅ = **change 期覆盖**，不宣称长期回归保护）+ §回归保护 新增「**长期回归保护的判定：未达标**」显式声明并**交阶段 7 triage**；`Tech-debt: TD-053` 保持 |
| 20 | 🟡 | **L3 第 4 轮 major 2：UAT ③ 称「真实拦截」而 B2/B3 实得放行（TD-059）** | **`Fixed in: TEST.md §1.2 ③`**：新增「**本条验收面结论**」—— 拦截只在**无完成标记**时成立 ⇒ **UAT ③ 判为「部分通过」**，B2/B3 列为该条的**未覆盖分支**；`Tech-debt: TD-059` 保持 |
| 21 | 🟡 | **L3 第 4 轮 major 3：核心数字仍在可见工件之外**（审查信封只送补充产物前 3000 B ⇒ §B/§I 对审查者不可见） | **`Fixed in: TEST.md` 附录 A「最小复算存档」**（12 条判据 rc · bats 收集/有效计数 · `make check` 九门禁摘要 · 性能与端到端样本 · 阶段门五层结果，全部落在正文可见区）+ 附录 B（T17/T19 回写回执） |
| 22 | 🟡 | **L3 第 4 轮 major 4 + minor ①–⑤**（976 与 TD-033 mock 并存 / 无端到端耗时 / OWASP 可能被读成工具级 / 第 4 轮 macOS 措辞 / L 条目无内容 / T17·T19 原文未附） | **`Fixed in: TEST.md`**：§1.3 第 2/4 条与 §2.4/§2.5/§回归保护 统一「**975 有效**」口径（原始回执数字不改写）+ §2.2 新增**端到端耗时**（bats **121.203 s** / `make check` **258.890 s**）+ §3.4 增「**证据等级**」列并把 A02/A06 降为 ⚠️（**✅ 5 / ⚠️ 4 / ➖ 1**）+ §4.4 第 4 轮行改「✅ 静态面通过 / ⚠️ macOS 实机未验证（TD-055）」+ L 索引各行已含一句话内容（编号检索为补充）+ 附录 B 给出 T17/T19 抽取与复算脚本落盘副本的 `diff rc=0` 回执 |
| 23 | 🟡 | **L3 第 5 轮 major 1：AC-1/AC-6/AC-8 行与「覆盖判定 8/8」仍可能被读作长期回归保障** | **`Fixed in: TEST.md`**：§1.1 **AC-1 / AC-6 行各标注**「（仅 change 期判据覆盖，无常设 bats 回归 · TD-053）」；**AC-8 行**结果列改为「✅ change 期 / ⚠️ 长期回归 + macOS 实机」；**覆盖判定**改为「8/8 有 change 期机器可验证据；其中 **3/8 缺少常设 bats 回归**」 |
| 24 | 🟡 | **L3 第 5 轮 major 2：UAT ③ 需显式列为「未通过分支 + 声明行」** | **`Fixed in: TEST.md`**：§0 范围声明后新增「**阶段门有效性（UAT ③ 面）：部分通过 —— 未通过分支 = B2/B3 放行（TD-059 未修复）**」；§1.2 ③ 结论行把 B2/B3 明写为「**未通过分支**」；§1.1 结论口径声明同步该措辞 |
| 25 | 🟡 | **L3 第 5 轮 major 3 + minor ①②③：核心输出仍在被截断的 receipts 内 / A01·A03·A04 仍标 ✅ / §4.4 与 AC-8 需明示 macOS 未验证** | **`Fixed in: TEST.md`**：新增 **附录 C「关键数字的原始输出」**（bats `--count` 与 TAP 计数原文 · `make check` 尾部原文含 privacy 自证四行与结尾框 · 一键复算脚本尾部原文含判据/门禁两表 + `REPRO rc=0`）+ §3.4 **判定收紧**（A01/A03/A04/A07 由 ✅ 改 **⚠️ 替代面**并补限定）+ §3.5 新增**未安装工具清单与可复算命令**代码块 + §4.4 新增「**AC-8 结果列口径**」注（静态判据为限，TD-055 / TD-053 两层含义不含） |
| 26 | 🔴 | **L3 第 6 轮 major 1（verdict=fail）：§1.1 主表仍以 ✅ 结尾 ⇒ 「8/8 全覆盖通过」可被误读为长期回归保障** | **`Fixed in: TEST.md §1.1`** —— 表结构改为 **4 列**（`AC` / 主证据 / **change 期判定** / **长期回归保护**）：AC-1、AC-6、AC-8 的长期回归列 = **❌ 无常设 bats 回归（TD-053）**，其余 5 条 = ✅ 常设 bats/门禁；**覆盖判定**改为「**8/8 仅有 change 期覆盖；3/8 无常设回归保护**」+ 新增「**静态判据通过 ≠ 跨 OS 兼容性验收通过**」 |
| 27 | 🔴 | **L3 第 6 轮 major 2：B2/B3 的 rc=0 被写入复现序列的固定预期 ⇒ UAT ③ 应判未通过** | **`Fixed in: TEST.md`** —— §0 阶段门有效性声明由「部分通过」改为「**未通过（FAIL）**」并明写「B2/B3 是**验收失败分支**」；§1.2 ③ 结论行改「**UAT ③ 判为「未通过（FAIL）」，失败分支 = B2/B3**」；§1.1 结论口径声明同步 |
| 28 | 🟡 | **L3 第 6 轮 major 3 + minor ①②：核心数字仍缺计时原文与脚本可验证性 / AC-8 与第 4 轮仍带 ✅ 前缀 / A08 仍标 ✅** | **`Fixed in: TEST.md`** —— 附录 C 新增 **C-4「计时命令与原始输出」**（bats 121.203 s、`make check` 258.890 s、NFR 5 次 2.822–2.876 s 的 `TIMEFORMAT` 原文 + 可复制命令）与 **C-5「复算脚本的可验证校验和」**（两件脚本 + receipts 的 `sha256sum`，附不内嵌全文的理由）；§0 第 4 轮行去 ✅ 前缀（改「静态判据通过 / ⚠️ macOS 实机未验证」）；§3.4 **A08 降为 ⚠️（无独立安全工具面）** ⇒ **✅ 0 / ⚠️ 9 / ➖ 1**，读法行同步「本节不保留 ✅」 |
| 29 | 🟡 | **阶段 5 重入复跑（REPRO4）确认两个 fix 任务的缺口已闭合**：`T-FIX-01`（TD-053 常设回归网）与 `T-FIX-02`（TD-059 阶段门有效性）均已交付并通过复核；本轮 14 条判据 + 7 项门禁全绿 | **`Fixed in: test/**` + `flow-kit-bundle/test/**`（`5ee4ebc`：3 个新 bats 25 例）· **`Fixed in: flow-kit-bundle/hooks/stop/lib/done-validation.sh` + `.specs/adr/029-gate-marker-validity.md`**（`6cff7a2`：1 个新 bats 11 例）⇒ 原 #1/#12 的 `TD-053`、原 #17/#20/#24/#26/#27 的 `TD-059` **状态改为「已闭合」**（证据见 §1.1 · §1.3 · §回归保护 · §附录 D） |
| 30 | 🟡 | **`T-FIX-01` 判据的 locale 泄漏（`TD-051` 复发）**：判据首行 `export LC_ALL=C` 泄漏进它调用的 `npx bats` 子进程 ⇒ 既有用例 `test/test_l3_pipeline_fix.bats:592` 在 HEAD 即红（`:609` 的 `iconv -f utf-8 -o /dev/null` 未给 `-t` ⇒ 地域 `C` 下拒绝合法 UTF-8） | **判据最小修（已回写 `TASK.md`）**：首行 `export LC_ALL=C; rc=0;` → 4 行成因注释 + `rc=0;`，其余 **31 行逐字不动**、断言强度不变 ⇒ rc=1 → **rc=0**；`Tech-debt: TD-051` 复发（不新开 TD）· §1.7 台账 |
| 31 | 🟡 | **`T-FIX-02` 判据的 cwd 泄漏（新登记 `TD-060`）**：判据出 `mktemp -d` 沙箱后未回仓根 ⇒ 其后 6 步全在 `${TMPDIR:-/tmp}` 执行（4 条 🔴 + `make: *** 没有规则可制作目标“check”`） | **判据最小修（已回写 `TASK.md`）**：补 `REPO_ROOT="$PWD"` + 沙箱段末尾 `cd "$REPO_ROOT"`，**步骤与断言逐字不动** ⇒ rc=1 → **rc=0**；新登记 **`Tech-debt: TD-060`**（判据侧 · 已闭合）· §1.7 台账 |
| 32 | 🟡 | **`T27`/`T29` 判据的 bats 回归地板按旧基线标定**：断言 `[ "$b_ok" -ge 973 ]`（= 976 − 3），而基线已升到 **1012** ⇒ 旧地板可容忍 **39 例静默消失**（回归网被静默削弱；与 L-152「门禁强度 = 最早返回的检查」同族） | **判据地板订正（主 agent 就地修 `TASK.md` · 阶段 5 重入）**：`TASK.md:1231`（T27 断言）/ `:1306`（T29 断言）`-ge 973` → **`-ge 1009`**（= 1012 − 3，与原 976/973 同余量）；同步 `:1229`（T27 echo 描述串）/ `:1291`（T29 `<action>` 描述串）/ `:25`（AC-8 行 `bats ≥1009`）与两条 `<done>` 注记；**`<verify>` 行数未变**（T27 = 19 行 / T29 = 15 行）⇒ 本轮判据抽取口径不受影响；实测 `ok=1012 ≥ 1009` ⇒ 两条判据在新地板下 **rc=0**（§1.7 台账第 5–6 行 · §附录 D） |

| 33 | 🟡 | **`G-T04-1`/`G-T04-2` 前置修复（主 agent 自定的阶段 5 门禁前置项 · **非判据失败**）在飞行中改动源面 ⇒ 中间轮 r4c 的 `make check` 因 `check-dist` 陈旧转红**（`T29` / `T-FIX-01` / `T-FIX-02` 三条判据的 `<verify>` 均以 `make check` 为必经步骤，故同一根因连带三红） | **`Fixed in: flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:364` / `:369`（两处纯文案 · **零行为变更**）+ `test/test_l3_review_defects_2026_09.bats` 的 `B11-R6` 内 **6 条静态断言**（不新增用例 ⇒ 计数仍 **1012**）+ `./sync-hooks.sh` 六副本 + `bash package-dsh-plugin.sh`（dist 重建 · gitignored）** ⇒ `make check-dist` = ✅ dist 与源一致 · `make check-hooks-sync check-test-sync` = ✅ 漂移 0 / ✅ 双源一致；源面随后**冻结**，终版整轮复跑（第 6 次执行 · `R4D_RC=0`）判据 **14/14** + 门禁 **7/7** 全绿。中间轮的 rc=1 与根因**如实保留**在 §附录 **D-5**；处置事实见 §附录 **D-6**、终版回执见 §附录 **D-7** 与 `PHASE5-RECEIPTS.md` **§M** |
| 34 | 🔴 | **隐私门禁 F1（机械/工具故障 fail-open）**：`check-path-privacy.sh` 把 `mktemp`（`:75-77`）/ `cp`（`:105-111`）/ `git ls-tree`/`git ls-files`（`:203-209`）的失败与 `grep` 的 rc/stderr（`:285`/`:309` 的 `2>/dev/null || true`）折算成「0 命中 ⇒ ✅ rc=0」⇒ 坏 `TMPDIR` 下仓内**真泄漏仍 rc=0**（主 agent 四态复现 + 跨模型 spot-check `qwen3.8-flash` 独立复现，逐字节稳定） | **`Fixed in: flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（`T-FIX-03` = `6e39cfb` · 392 → 548 行）**：`mktemp_checked()` `:106-115` · `cp` rc `:153`/`:161` · `git ls-tree`/`git ls-files` rc `:271`/`:279` · `git grep`/`grep` rc≥2 `:385-395`/`:425-435`（**rc=1 无命中仍放行 ⇒ 无假红**）；`|| true` 仅存 2 处且均在 rc 已断言后 ⇒ **`Tech-debt: TD-064` 已闭合** |
| 35 | 🔴 | **隐私门禁 F2（扫描面塌陷 · 0 候选与干净同形）**：自证行（`:369-374`）无「候选文件 N 个」，非 git 目录 / git 仓但 index 为空 ⇒ 候选 0 ⇒ 输出「命中合计 0 条 ✅」rc=0，与「全部干净」不可区分（跨模型 spot-check 另发现「`git init` 未 `add`」变体：`git ls-files` rc=0 只是输出 0 行，F1 的 rc 断言抓不到） | **`Fixed in: 同上`**：自证行含候选数（`:296-300`）+ `N=0 ⇒ 🔴 候选面为空` fail-closed（`:300-303`）+ 常设双态 bats 同时覆盖「非 git 目录」与「git 仓 0 tracked」两型 ⇒ **`TD-064` 已闭合** |
| 36 | 🟡 | **隐私门禁 F3/F4/F5**：F3 两模式二进制策略相反（工作树 `grep -nE` 静默丢弃 ⇒ 假绿；rev `git grep` 把 `Binary file … matches` 当命中 ⇒ 不可归因假红且白名单永不生效）· F4 注释口径两套（校验器认 `#` 与 `<!--`，计数器只认 `#` ⇒ 自证行「允许清单 N 条」虚高）· F5 临时文件清单两份 + 第二个 `trap … EXIT` 覆盖 `cleanup()` ⇒ 首次登记的临时文件失联 | **`Fixed in: 同上`（`T-FIX-03`）**：F3 两模式统一 `-a` + 命中读取端断言 line 字段 `^[0-9]+$`；F4 `IS_COMMENT_OR_BLANK_RE`（`:192`）校验器 `:205` 与计数器 `:261` 共用；F5 唯一 `trap cleanup EXIT`（`:98`）+ 单一 `TMP_FILES`（`:120`/`:475`） |
| 37 | 🟡 | **`check-gate-sync.sh` F6/F7（门禁自称一致却不一致）**：缺一对 prompt/skill 文件时只打 `⚠️ WARNING` + 裸 `return`（`ERRORS` 不增）⇒ 沙箱实测缺 1 对仍打印 `✅ 校验对 3/14 一致` rc=0；「14」在 `:25`/`:32`/`:40`/`:204`/`:209` 硬编码 + `:206` 文案陈旧 | **`Fixed in: flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（`T-FIX-04` = `521b21c`）**：缺对 ⇒ `🔴 MISSING` + `ERRORS+1`；新增 `COMPARED` 计数器，汇总分母 `${COMPARED}/${PAIRS_TOTAL}` 并单列未比对对数，`✅` 行改用 `${COMPARED}` ⇒ 缺对时必走 🔴 分支；`PAIRS_TOTAL=14` 常量单点 + 全集插值；常设 bats 5 → **7** 例 |
| 38 | 🟡 | **`Makefile` F8（判据正文复制两遍）**：`check-nfr-portability`（`:247` 起 89 行 wrapper）与 `check-nfr-portability-internals`（`:162` 起 78 行正文）有 **76 条语句逐字重复** ⇒ 双份维护、改一处即漂移 | **`Fixed in: Makefile`（`T-FIX-05` = `6e94d60`）**：wrapper 配方 **89 → 13 行薄壳**（`awk` 范围法 · Δ−76 · 本提交 `Makefile` numstat `+9/−77`）（`mktemp` 两临时件 → `export NFR_RC_FILE` → `bash -c 'make --no-print-directory check-nfr-portability-internals'` → 三态映射 0/3/1），判据正文唯一留存 internals（范围法 79 行不变）· 本提交 3 文件 **+35 / −77 ⇒ 净 −42 行**；钉住断言（`_report_viol() {` 唯一 + wrapper recipe < 30 行）**改写既有用例**（计数 +0）；**零行为变更**（F3 既有 7 例全绿）。张力点：薄壳用 `bash -c 'make …'` 而非 `$(MAKE)`（GNU make `-n` 特例与 `make -n` 可解析性断言互斥）⇒ 主 agent 裁定**接受**（`<action>` ② 允许等价递归形态 · **L-156**） |
| 39 | 🟡 | **判据夹具自身缺陷（`TD-065`）**：`T-FIX-04 <verify>` 的缺对夹具用 `ls flow-kit-bundle/skills/*/SKILL.md | head -1` 取字母序首个 `flow-architect`，而生产件 `PAIRS` 只含 `flow-evolve`/`flow-intel`/`flow-restyle` ⇒ `MISS=0` ⇒ 修复后的**正确**行为被判据报成 🔴 ⇒ `<verify>` 恒 rc=1（执行者依硬规则 2 停下原样上报，**未自行改判据**） | **`Fixed in: .specs/health-fix-2026-09b/TASK.md` 的 `T-FIX-04 <verify>`**（夹具改为从 `PAIRS` 声明的 `|flow-<name>` 形态派生 + `[ -f ]` 前置 + 诊断行）⇒ 原样复跑 **rc=0**（`verify hides: flow-kit-bundle/skills/flow-evolve/SKILL.md` · `real=21 full_fixture=0 missing_pair=1`）；**`Tech-debt: TD-065` 已闭合（v2 = `make lint` 静态检查 `ls … | head -1` 形态）** |
| 40 | ℹ️ | **阶段 6 审查另登记的三条开放债**：`TD-061`（行/分支覆盖率无数据 · 本机无 `kcov`/`bashcov`）· `TD-062`（`check-path-privacy.sh:50-53` 回退读序硬编码本 change id ⇒ 归档后成死代码）· `TD-063`（`.specs/**` 31 个 tracked 文件仍含内部项目名 · 不在分发面故不违反 AC-5 的「不随分发件出厂」） | **`Tech-debt:` 结案（交阶段 7 triage）**；三条均为 v2 面，不阻塞本 change（`TD-062`/`TD-063` 由 `REVIEW.md` 🟢 F12/F17 登记 · `TD-061` 由 L3 第 11 轮 major 4 登记） |
| 41 | 🟡 | **判据对照夹具候选面全自排除（`TD-066` · 第 8 次执行复跑暴露）**：`T17 <verify>` 的 CHECK_REV「干净树上工作树模式必须 rc=0」对照夹具 `_sbx2/r` 只提交被测脚本 + **空** `path-privacy-allowlist.txt` ⇒ tracked 面**全部命中 `SELF_EXCLUDE`** ⇒ 候选 N≥1、实际扫描 M=0 ⇒ 被 `T-FIX-06` 新引入的 fail-closed 早退判红（`🔴 工作树模式在干净树上未 rc=0（rc=1）⇒ 对照不成立`） | **`Fixed in: .specs/health-fix-2026-09b/TASK.md` 的 `T17 <verify>`（`:761` 一带）** —— 夹具补入**非自排除**的 benign tracked 文件 `README.md`（附 `TD-066` 溯源注记）；`--criteria-only --only T17` 复跑 **rc=1 → rc=0**（73 → 74 行判据）· 同族：`TD-060`（cwd 泄漏）· `TD-065`（样本脱钩） |
| 42 | 🟡 | **判据抽取器未整行锚定（`TD-067` · L-153 族复发）**：`reproduce-5-test.sh` 的 `extract_verify()` 用**行内子串**匹配 `<verify>`，而 `T-FIX-06 <action>` 正文含 `<verify>` 字样 ⇒ 抽取起点落进 action 段，产出「散文 + `</action>` + 判据正文」的 43 行废件 ⇒ 被记成 `T-FIX-06 🔴 rc=2`（`v_T-FIX-06.sh: 行 1: T-FIX-06-SUMMARY.md: 未找到命令` · `行 2: \`</action>'`） | **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh:63-71`** —— 标签匹配改**整行锚定**（`^[[:space:]]*<verify>[[:space:]]*$` / `^[[:space:]]*</verify>[[:space:]]*$`）⇒ 复抽 **41 行 · 首行 `set -u; rc=0;` · `bash -n` 通过**；v2 = `make lint` 静态检查抽取器标签匹配形态 |
| 43 | 🟡 | **`R4-1`（判据过严 ⇒ 假红 · 第 4 轮输入面）**：`T-FIX-11` 一度过度收紧 —— 候选在 index 侧可读（`git cat-file -t ":$file"` = `blob`）但工作树缺失时被判「不可读」⇒ **门禁对合法状态报红** | **`Fixed in: flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（`T-FIX-11` = `38f3a38` · 双源 `test/test_path_privacy_gate.bats` 各 +56 行）** —— 不可读判定与 index 内容面口径分离；修复前夹具 10 PASS / 5 FAIL（`/tmp/p6c/tfix11-pre-fix.txt`）· 主 agent 16 腿夹具 16/16 · 执行者四腿（过严红 / index 侧泄漏被检出 / gitlink fail-closed）+ `bats` 1061 ok ⇒ 第 11 次执行判据 25/25 全绿 |
| 44 | 🔴 | **`R4-2`（性能回归 · NFR 判据 ❌ · 第 9 次执行）**：`check-path-privacy.sh:586` **每个候选调一次 `git grep --cached`**（实测 1594 次进程 · 微基准 4.28 ms/次）⇒ 5 次实测 **10.741 / 10.885 / 10.783 / 11.510 / 11.469 s（均值 11.078 s = 预算 221.6% · `sys` 11.186）**，违反 `REQUIREMENT.md:495`「单次运行 ≤5 秒」（`TEST.md:248`「超阈值即未满足」· `:265` 不做负载折算）· A/B：`7b624dc`（594 行）**3.191 s** → `20847e1`（`T-FIX-07`，692 行）**10.662 s** → `bf3763f`（769 行）**10.778 s** | **`Fixed in: check-path-privacy.sh`（`T-FIX-12` = `c177fba` · `+172/−18` · 769 → 923 行）** —— 整 index **一次** `git grep --cached`（`TMP_INDEX_CACHE_RAW` + `TMP_INDEX_SEEN` 去重）+ **一次** `git cat-file --batch-check`（磁盘缺失查表，FD 3/4 成对）；批量化面 = `git ls-files -z --`（无 pathspec）**与候选面同集合、不扩大**；fail-closed 保留（批量 `git grep` rc≥2 ⇒ exit 1）；`sys` 11.186 → ~2.4（**−78.6%**）⇒ 第 11 次执行 **3.489 / 3.666 / 3.660 / 3.613 / 3.615 s（max 3.666 · 均值 3.609 = 72.2%）**。**判据运输面（`TD-077`）同批改为真判后，第 9 次的 ❌ 由脚本自行判出**，原文留档 `PHASE5-RECEIPTS.md` §R-2/§R-3 与附录 **D-10**（**不追溯改判**） |
| 45 | 🟡 | **`R4-M1`（bundle 形态 fail-open · 主 agent 第 4 轮复核 · 用户裁决「本 change 内修」）**：`resolve_checker()` 只在 `[ -f "$ref_dir/path-privacy-allowlist.txt" ]` 时设 `RESOLVED_ALLOWLIST` ⇒ 「检查器在 `reference/` 内、但清单缺失」（旧版安装器 / 手工 symlink / 半拷贝目录）时，`pre-push` 与 `pre-commit` 都打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描`（**成因不符**）且 **rc=0 放行** ⇒ 含真实形态探针的推送/提交被静默放过（缺陷态夹具 `pre-push rc=0` + `pre-commit rc=0`） | **`Fixed in: flow-kit-bundle/hooks/pre-push/pre-push.sh`（`+22/−2`）与 `flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（`+9/−1`）（`T-FIX-13` = `ee0df5c` · 双源 `test/test_archive_commit_gate.bats` 各 +42 行静态断言）** —— 状态② 走**独立致命路径**（pre-push `exit 2` / pre-commit `exit 1`）并**指名** `path-privacy-allowlist.txt`，**避开**父层 `pre-push.sh:150` 的泄漏归因；状态①（检查器缺失 ⇒ rc=0 消费者兼容语义）与状态③ 逐字不变 ⇒ 三态在**常设 bats** 与**主 agent 独立夹具**（`/tmp/p6d/tfix13-main-verify.sh` rc=0）双面复现；判据夹具缺陷 **`TD-081`** 同批修订（见 #48） |
| 46 | 🟡 | **`TD-077`（判据运输面硬编码 ⇒ 红面被判成绿 · 第 9 次执行暴露）**：`reproduce-5-test.sh` 的 `[D]` 段 `emit_gate "NFR ≤5s ×5" 0 …` **恒 rc=0** ⇒ 均值 221.6% 仍被打印成 ✅ ⇒ 判据「自称通过」而**不自证** | **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh`（第 10 次执行起 · `[D]` 段真断言）** —— 逐次解析 `real=` ⇒ `awk` 判 `>5` ⇒ 累计 max/sum ⇒ 预算百分比 ⇒ 超限 `emit_gate … 1` ⇒ 整体 `exit 1`；边界自检（5.001 ⇒ 🔴 / 3.0xx ⇒ ✅ 均值 61.5%）；`L200-202` 注释**诚实披露**第 9 次的硬编码历史 |
| 47 | 🟢 | **`TD-078`（AC-6 用例数简报误差 · 第 5 轮 L2 独立复核 🟡-3）**：`TEST.md` §1.1 声明常设隐私 bats **24 例**，实证 `grep -cE '^[[:space:]]*@test' test/test_path_privacy_gate.bats` = **30 例** | **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §1.1「第 11 次执行补记」（本行同批落地）** —— 24 → 30 + `TD-078` 溯源；历史值保留不抹除；判别力判定不变（30 例覆盖更充分） |
| 48 | 🟡 | **`TD-081`（判据夹具与语义脱节 ⇒ 两腿互斥 · 第 11 次执行）**：`T-FIX-13 <verify>` **初版**只 `cp` 检查器、**从不创建 `$SBX/reference/path-privacy-allowlist.txt`** ⇒ 被标注「两者皆在」的 L4/L5 实际运行在**缺陷态**，与 L2d（缺陷态不得出现「含路径隐私泄漏」）对**同一输入**构成**互斥断言** ⇒ 判据不可满足（执行者 `3add4b81` 按硬规则**停下原样上报**，主 agent 独立复核一致；同族 `TD-073`/`TD-065`/`TD-072`） | **`Fixed in: TASK.md` 的 `T-FIX-13 <verify>`（主 agent 就地修订）** —— 新增 **`L3d`**（夹具切到真「两者皆在」态 + 就位断言）与 **`L4c`**（pre-commit 反向控制：两者皆在 + 真泄漏 ⇒ rc≠0）；`L2a–L2g`/`L3a–L3c`/`L6a–L6c` **一字未改**（**不放宽**）；块内留「判据修订留痕」+ `MINOR-DEFERRED.md` R4-M1 修订段；修订后先红预跑 rc=1 且红腿恰 **6** 条（`/tmp/p6d/verify-tfix13.sh` sha256 `242fa9c4…`）⇒ 第 11 次执行该判据 **53 行 · rc=0** |
| 49 | ℹ️ | **本 change 在第 9–11 次执行 / 阶段 6 第 3–4 轮期间**另**新登记技术债 14 条**：`TD-068`…`TD-081`（判据 / 夹具 / 工具 / 流程 / 源码混族；**无一属「改判据掩盖生产件回归」**，其中 `TD-076` 还记录了主 agent 自伤后**回退撤回误登记**的过程） | **`Tech-debt:` / `Fixed in:` 逐条见 `.specs/CONTEXT.md:615-628`**（本表 1–42 为第 1–8 次执行台账 · **历史条目保留不抹除**；新条目不复述全文以免双份维护）· 处置位置索引见下条 |


> **修改前判据原文存档（L3 第 7 轮 major 2 / L2 R2 响应）**：6 条被回写判据（`T17` · `T19` · `T-FIX-01` · `T-FIX-02` · `T27` · `T29`）的**修改前 `<verify>` 原文 + 来源 commit + 逐条执行结论**见 `PHASE5-RECEIPTS.md` **§K**/**§L**；结论 = **无一条属「判据判红 ⇒ 改判据至绿」**（`T-FIX-02` 修的是判据自身假红 · TD-060；`T27`/`T29` 收紧弱地板且红绿不变）。

> **审查发现处置位置索引**：L2 第 1 轮 3 条 🟡（R8/R9/R10）与 L3 第 1–4 轮全部 major/minor 的逐条分类（`Fixed in:` / `Tech-debt:` / `Not-applicable:`）见 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` 的六段「主 agent 响应」；本节 **1–28** 为第 1–4 次执行的处置索引（历史记录，保留不抹除），**29–32** 为第 5 次执行（REPRO4 重入复跑）的追加条目，**33** 为第 6 次执行（终版 · `G-T04-1`/`G-T04-2` 修复与源面冻结）的追加条目。**独立技术债条目 = 14**（TD-053 常设回归网 · **TD-055** macOS 实机 · **TD-056** 安全工具面 · **TD-057** 判据 `rc=$?` 惯用法 · **TD-058** `HOOK_BASE_DIR` 语义 · TD-059 阶段门存在性判定 · **TD-060** 判据 cwd 泄漏 · **TD-061** 覆盖率无数据 · **TD-062** 常设件硬编码 change id · **TD-063** `.specs/**` 内部名留存 · **TD-064** 隐私门禁 fail-open / 扫描面塌陷 · **TD-065** 判据夹具样本脱钩 · **TD-066** 判据对照夹具候选面全自排除 · **TD-067** 抽取器未整行锚定），均为 `Tech-debt:` 结案；其中 **7 条已在本 change 内闭合**（TD-053 = `5ee4ebc` · TD-059 / TD-060 = `6cff7a2` · TD-064 = `6e39cfb` · TD-065 = `T-FIX-04` 判据修复 · **TD-066 / TD-067 = `26d5d7b` 判据与工具面订正**），**7 条仍开放**（TD-055 / TD-056 / TD-057 / TD-058 / TD-061 / TD-062 / TD-063，交阶段 7 triage），**技术债 / 处置发现 = 14 / 42 = 33.3%，未达 `5-test.md` 的 50% 阈值**；其中 **TD-058 / TD-059 为阶段 5 实测新发现的产品缺陷**，各附 v2 修法与非本 change 范围内的次序理由。 **第 11 次执行订正（L2 第 5 轮 🟡-2 响应 · 2026-09-27）**：本节另新登记技术债 **14** 条（`TD-068`…`TD-081`，见发现表 **#43–#49**）⇒ **独立技术债条目合计 = 14 + 14 = 28**；其中属**源码级**发现者 **3** 条（`TD-069`（`l3-review.sh:58` `max_bytes` 解析链 / `l3-prompt.sh:270` 截断仅 stderr 告警）· `TD-074`（`flow-kit-artifacts.sh:51` `declare -A` 无版本守卫；`l3-truncate.sh:100`/`:167`）· `TD-075`（`Makefile:8-11` `test:` 目标隐藏失败用例 id）），其余 11 条为**判据 / 夹具 / 工具 / 流程面**（不进入 `5-test.md:103`「源码级发现」分母）⇒ **AC-4 技术债滥用防护（≥50% 源码级发现标 `Tech-debt:`）未触发**；上句 **33.3%** 为第 1–8 次执行**时点口径**（保留不抹除）。

---

## L 条目索引（本文引用的经验条目 · L3 第 2 轮 minor ⑤ 响应）

| 编号 | 含义（本文引用它的场景） | 出处（`.specs/LESSONS.md`，2026-09-24 落档行号） |
|---|---|---|
| L-129 | 绝对路径入档前必须 de-shape（机器路径同时污染基线与 git 历史）⇒ 本文头部写「仓库根 = `<repo>`」 | `grep -n '^### L-129' .specs/LESSONS.md` |
| L-137 | 「扫描面的判据」必须在 `git add` 新产物**之后**运行（提交那一刻扫描面才扩大）；探针字面须拼接构造 | `grep -n '^### L-137' .specs/LESSONS.md` |
| L-146 | 判据里的 `export LC_ALL=C` 会泄漏进它调用的测试套件；`iconv -f utf-8 -o f` 的目标字符集取自 locale ⇒ 地域 C 下拒绝合法 UTF-8（假红） | `grep -n '^### L-146' .specs/LESSONS.md` |
| L-147 | 产品件自证用的合成探针若要被 change 期判据复核，必须**逐条精确字面**豁免，不能抄产品整文件排除（否则判据自造红） | `grep -n '^### L-147' .specs/LESSONS.md` |
| L-148 | PreToolUse 门禁按**命令文本**匹配握手文件名 ⇒ 只读勘查也要用不含文件名的形式（`ls -a` / `git ls-files`） | `grep -n '^### L-148' .specs/LESSONS.md` |
| L-149 | 审查派发面必须显式要求脱敏：L2/L3 会把真实仓库根原样写进审查档，**入库瞬间**击穿 AC-6 门禁（本文 §阶段 5 发现 #5 的根因） | `grep -n '^### L-149' .specs/LESSONS.md` |
| L-150 | 「完备性」判据会把新产品件自动推向豁免面：判据必须编码**策略**（时间切点），不能编码**集合快照**（本文 §1.7 / T17 改判的依据） | `grep -n '^### L-150' .specs/LESSONS.md` |
| L-151 | 审查信封对**补充产物**只取前 3000 B（`l3-prompt.sh:286/304`）⇒ 给外部审查者的证据必须「倒置金字塔」：结论与复算入口放文件头（本文 #11 的依据） | `grep -n '^### L-151' .specs/LESSONS.md` |
| L-152 | 门禁的强度等于它**最早返回**的那个判定：以「文件存在」为界 ⇒ 配套内容校验成为不可达装饰；只匹配命令文本的守卫可被拼接绕过（本文 #16/#17 · TD-058/TD-059 的依据） | `grep -n '^### L-152' .specs/LESSONS.md` |

> 出处列给出**编号检索命令**而非固定行号：`LESSONS.md` 的新条目插在 `<!-- health-fix-2026-09b 追加 ↑ -->` 之后按编号**倒序**排列，行号会随新增漂移（本表原先的落档行号已因 L-151/L-152 插入而下移，故改为编号检索）。

---

## 附录 A · 最小复算存档（正文可见区 · L3 第 4 轮 major 3 响应）

本附录把全部核心数字**落在本工件正文**，不依赖外部文件即可逐项核对；完整原始 stdout 仍存档于 `.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`（§A 判据 12 条 · 第 1–4 次执行 / **§J 判据 14 条 + 7 项门禁 + 权威回执 · 第 5 次执行** / §B 门禁 / §D 判据修正台账 / §E · §I 性能 / §H 阶段门沙箱六态）。**本附录数值已按第 5 次执行（REPRO4）订正**（括号内保留历史值；**当前权威值以 §0 第 11 次执行行与附录 D-12 为准**），括号内保留历史值，便于逐轮对照。**一键复算**：

> **数值时点说明（第 6 次执行终版）**：本附录 ①–⑤ 为**第 5 次执行**实测存档（历史对照）；**终版（源面冻结 + 地板订正后）数值见 §附录 D-7** —— 判据 14/14 · 门禁 7/7 · `R4D_RC=0` · NFR 均值 **2.937 s = 预算 58.7%** · 六态全绿。

```bash
bash .specs/health-fix-2026-09b/reproduce-5-test.sh       # 14 条判据 + 7 道门禁（含 [F] 阶段门沙箱复现）
bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh   # 阶段门六态 A/B/B2/B3/B4/C + 判别子
```

**① change 期判据 14/14 ✅ rc=0**（从 `TASK.md` 各 `<verify>` **原样抽取**、**字面执行**，零改写；第 1–4 次执行为 12/12）：

| 判据 | T05 | T06 | T11 | T13 | T17 | T19 | T20 | T22 | T24 | T26 | T27 | T29 | T-FIX-01 | T-FIX-02 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| rc | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | **0** | **0** |
| 抽取行数 | 12 | 22 | 7 | 34 | 73 | **36** | 3 | 20 | 18 | 30 | 19 | 15 | **36** | **42** |

**② `make check` 门禁 9/9 + 复现门禁 7/7 ✅（第 5 次执行实测值 · **判据版本 = 修正前**（`T27`/`T29` 旧地板）；括号内为第 1–4 次执行。**修正后判据集的整轮全绿 = 第 6 次执行，见 §D-7**）**：`npx bats --count test/` = **1012**（976）· `npx bats test/` rc=0 **ok=1012 / not ok=0 / skip=0**（976 / 0 / 0）· 有效用例 = **1011**（975）· `make check` rc=0（✅ bats / ✅ shellcheck 68 文件 / ✅ validate 漏配 0 源缺失 0（期望 **315** / 实际 **321**；第 1 轮 311 / 317） / ✅ test 双源一致 / ✅ hooks 六镜像 0 漂移 / ✅ check-dist / ✅ check-gate-sync 3/14 对 + 17 预设 / ✅ 清单外命中 0 / ✅ NFR 兼容性判据）· `make check-path-privacy` rc=0 · `package-flow-kit.sh --validate` rc=0 · 阶段门沙箱复现 rc=0（六态全绿）。

**③ 性能（预算 ≤5 s）与端到端耗时**：**第 5 次执行**：`make check-path-privacy` 五次 **2.881 / 2.889 / 2.892 / 2.929 / 2.885 s**，均值 **2.895 s = 预算 57.9%**（`nproc=32`，`loadavg` 7.91 8.12 7.49）。历史：三次 2.830 / 2.868 / 2.826 s（首轮）、五次 2.842 / 2.847 / 2.898 / 2.836 / 2.867 s（第 2 轮补测，均值 2.858）、五次 2.876 / 2.822 / 2.850 / 2.834 / 2.871 s（处置后复测，均值 **2.851** = 预算 **57%**，`loadavg` 5.95–6.52）；`check-gate-sync` 0.047–0.053 s；`check-nfr-portability` 0.172 s；**端到端**：`npx bats test/` real **121.203 s** · `make check` real **258.890 s**（§2.2）。**负载说明（L3 第 8 轮 minor ③）**：第 5 次 `loadavg` 7.91–8.12 高于第 1–4 次 5.95–6.52，均值相应 +0.04 s（+1.4%）；预算为**绝对阈值**，五次单测均 ≤5 s ⇒ **判定不依赖负载归一化**（详见 §2.2）。**时点限定（L3 第 10 轮 minor ③ 响应）**：本条 2.895 s 为**第 5 次执行的历史值**；**终版性能基线 = 第 6 次执行（§附录 D-7）= 均值 2.937 s（预算 58.7%）** —— 两版均 ≤5 s，判定不随基线版本变化。

**④ 阶段门沙箱复现（`reproduce-phase-gate.sh` · 六态 · 第 5 次执行实测）**：`A`（gate=both 且无标记）⇒ **rc=2** + 报文 `⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。` + **HEAD 不变**（`e2c73dd8607c3060d491fd006ff2e125af2803bb`）；`B`（gate=L2 + 合格 6 键标记）⇒ **rc=0** 放行且放行后 `git commit` **真的生效**；`C`（无 `.flow-active`）⇒ rc=0（门不适用）；**`B2`（标记 pass ↔ 审查档 fail 口径相悖）/ `B3`（`touch` 成 0 字节）/ `B4`（缺 `L3_verdict` 键 · 5 行 < `MIN_MEANINGFUL_LINES=6`）⇒ 一律 rc=2**（**存在 ≠ 有效** · ADR-029 · commit `6cff7a2`）；**判别子**（门禁外直连 commit 成功）✅。**历史对照（保留）**：修复前 `B2`/`B3` 为 **rc=0 = 缺口实证（TD-059）**，脚本自带 `ℹ️ 历史对照` 行。

**⑤ 失败语义**：任一判据非 0 ⇒ 脚本 rc=1 并打印失败清单（实测 `REPRO2 rc=1 判据失败[ T29 ] 门禁失败=1`，见 §附录 A ④ 与 receipts §I）。 **该次失败的根因（L3 第 9 轮 minor ④ 响应 · 与判据修正历史区分开）**：判据侧脚本 `reproduce-phase-gate.sh` 当时在标记改写处使用了 GNU-only `sed -i` ⇒ `make check-nfr-portability` 命中「新增行含 GNU-only 构造」变红 ⇒ 连带 `T29` 的 `make check` 步骤 rc=1 —— **判据/脚本侧问题，不是产品缺陷**（已改为 BSD 安全写法 `sed … > tmp && mv` 后 `make check-nfr-portability` 与 T29 复跑均 rc=0）；该项与 L-150 同族，记于 §1.7 台账与 `MINOR-DEFERRED.md`。

---

## 附录 B · T17 / T19 回写回执（L3 第 4 轮 minor ⑤ 响应）

本附录记录**第 1–4 次执行**期间的判据修正（T17 / T19）—— **历史记录，保留不抹除**；第 5 次执行（REPRO4）追加的 `T-FIX-01` / `T-FIX-02` / `T27`·`T29` 回归地板三条修正见 §1.7 与 §附录 D。**全部五处（组）修正都写在权威副本** `TASK.md` 内 ⇒ 重抽即得修正后版本；抽取结果与复算脚本落盘副本**逐字节相同**：

```bash
for t in T17 T19; do
  ext=$(mktemp)
  sed -n "/<task id=\"$t\"[^>]*>/,/<\/task>/p" .specs/health-fix-2026-09b/TASK.md \
    | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d' > "$ext"
  cmp -s "$ext" "/tmp/fk-reproduce-5/v_$t.sh" && echo "$t: diff rc=0 行数=$(wc -l < "$ext")"
done
# 实测：T17: diff rc=0 行数=73    T19: diff rc=0 行数=36
```

**T19 回写内容（L3 第 3 轮 major 4 · 四行 + 三行约定注释）**：`:877` 循环内 `rc=0; out=$(git $form 2>&1) || rc=$?` · `:881` `rc=0; out=$(git push origin --tags 2>&1) || rc=$?` · `:886` `rc=0; out=$(git push --all 2>&1) || rc=$?` · `:889` `rc_off=0; git push origin main >/dev/null 2>&1 || rc_off=$?` · `:895` 块尾约定注释（以「先置零再捕获」形式捕获，**禁止** `out=$(cmd); rc=$?`）。

| 运行器（回写前后对照） | 回写前 | 回写后 |
|---|---|---|
| 平跑 `bash v_T19.sh` | rc=0（19 行前置输出） | rc=0（37 行输出） |
| strict `bash -e -u -o pipefail v_T19.sh` | **rc=1 / 无任何 🔴 报文**（与真红态不可区分） | **rc=0 / 无 🔴 报文** |

原始输出：`/tmp/p5/m4.out`（平跑）与 `/tmp/p5/m4-strict.out`（strict）；同批记录见 receipts §D 台账。

**T17 回写内容（阶段 5 第 2 轮 · L-150）**：豁免面由「集合完备」改判为**时间切点**（冻结的 1–3 为唯一豁免集；此后新增审查档一律不豁免、必须被双面扫过）⇒ 回写后抽取 **73 行**、rc=0；依据与实证见 §1.7 与 `L-150`（`.specs/LESSONS.md`）。

---

## 附录 C · 关键数字的原始输出（L3 第 5 轮 major 3 响应 · 可在本工件内直接核对）

> 说明：本节把「核心数字」的**原始输出**（而非仅汇总表）附在**可见工件正文内** —— 因为 `PHASE5-RECEIPTS.md` 超出补充产物 3000 B 预算（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:286` / `:304`，L-151），外部审查者只能看到其头部。绝对路径按 L-129 去形为 `<repo>/`。
>
> **第 5 次执行（REPRO4）说明**：C-1–C-5 记录的是**第 1–4 次执行**的原始输出（历史记录，保留不抹除，数字不改写）；**当前（第 5 次执行）的同类原始输出全文见 §附录 D** —— 含 14 条判据的「抽取行数 + rc」、bats TAP 与 `make check` 的计数行、privacy 自证行、NFR 五次计时与均值占预算比、`package-flow-kit.sh --validate` 摘要、以及阶段门沙箱**六态 stdout 全文**。

### C-1 bats 用例数与 TAP 计数

```text
$ npx bats --count test/
976
$ grep -c '^ok ' /tmp/p5/bats-e2e.out      # 全量 TAP 回执（作业 bash-209）
976
$ grep -c '^not ok ' /tmp/p5/bats-e2e.out
0
```

端到端耗时（同机同环境）：`real 121.203 s`（user 81.050 / sys 44.707，rc=0）。

### C-2 `make check` 尾部原始输出

```text
   ✅ 预设名集合一致 (17 个预设)

   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
```

端到端耗时：`real 258.890 s`（user 170.315 / sys 93.520，rc=0）⇒ bats 主体 121.2 s，其余 8 道门禁合计 ≈137.7 s，本 change 新增三门禁（privacy / NFR / 阶段门复现）增量 ≈3.0 s = `make check` 的 1.2%。

### C-3 一键复算脚本在 HEAD 的完整运行回执（尾部原文）

```text
（判据表）T05 12 行 · T06 22 · T11 7 · T13 34 · T17 73 · T19 36 · T20 3 · T22 20 · T24 18 · T26 30 · T27 19 · T29 15（全部 ✅ rc=0）

== 汇总 ==
| 判据 | 结果 | 抽取行数 | 原始输出 |
| T05 | ✅ rc=0 | 12 | `out_T05.txt` |  … （12 条同列，逐条 rc=0）
| 门禁 | 结果 | 摘要 |
| bats --count | ✅ rc=0 | 用例数 976（源码面 test/*.bats） |
| bats test/ | ✅ rc=0 | rc=0 ok=976 not-ok=0（基线 976 ok / 0 not ok，skip 计入 ok 行） |
| make check | ✅ rc=0 | 21 条 ✅ / 0 条 ❌（原文 /tmp/fk-reproduce-5/make-check.txt） |
| check-path-privacy | ✅ rc=0 | ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞） |
| NFR ≤5s ×5 | ✅ rc=0 | 环境 nproc=32 loadavg=5.95 6.13 6.25 |
| package --validate | ✅ rc=0 |    🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0  |
| 阶段门沙箱复现 | ✅ rc=0 | 健康层 A/B/C ✅ · 缺口层 B2/B3 ⚠️（TD-059，非通过项）· 原文 /tmp/fk-reproduce-5/phase-gate.txt |

✅ 复算全绿（判据 + 权威回执）；原始输出保存在 /tmp/fk-reproduce-5
```

脚本退出码 **REPRO rc=0**；完整原文见 `.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md` §A/§B/§I（同一次运行的落档副本）。

### C-4 计时命令与原始输出（未删改）

```text
== time npx bats test/ ==
real=121.203 user=81.050 sys=44.707
bats rc=0
== time make check ==
real=258.890 user=170.315 sys=93.520
check rc=0

== [D] NFR 性能预算（5 次 · 预算 ≤5s）==   # 来自 reproduce-5-test.sh 本次运行
       run 1: real=2.876 user=1.147 sys=1.892
       run 2: real=2.822 user=1.162 sys=1.808
       run 3: real=2.850 user=1.149 sys=1.855
       run 4: real=2.834 user=1.147 sys=1.851
       run 5: real=2.871 user=1.184 sys=1.848
  NFR ≤5s ×5          ✅ rc=0  环境 nproc=32 loadavg=5.95 6.13 6.25
```

计时命令（可直接复制执行）：

```bash
TIMEFORMAT='real=%R user=%U sys=%S'; time npx bats test/; time make check
for i in 1 2 3 4 5; do time make check-path-privacy >/dev/null; done
```

### C-5 复算脚本的可验证校验和（L3 第 6 轮 major 3 响应）

两件复算脚本是本 change 的**已提交工件**（非临时文件），可用校验和核对内容未被篡改；`TEST.md` 自身的哈希由每轮 L3 记录在 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` 的 `L3_artifact_hash:` 行（审查时冻结值）。

```text
$ sha256sum .specs/health-fix-2026-09b/reproduce-5-test.sh \
            .specs/health-fix-2026-09b/reproduce-phase-gate.sh \
            .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md
6c73c93af696d816f87d8d2b8e5ce1f0c31dd9cbfb649654433f6125fdfa8a6e  reproduce-5-test.sh      (185 行)
4ddeb72662187c9d138c9b77358da094432855c0f6fb4f315b7ead5445bf8ec9  reproduce-phase-gate.sh  (165 行)
f7464625fb54e765f1214794c57171e007c3a8d0f92be662b7b37e2f877fdb2e  PHASE5-RECEIPTS.md
```

> **说明（为何正文不内嵌脚本全文）**：两件脚本合计 350 行，内嵌会使本报告体积翻倍且与已提交工件重复；`5-test.md` 未要求报告自身承载脚本副本，而 L3 第 6 轮 major 3 给出的可接受形态包含「**可验证的校验和**」⇒ 本节采用 `sha256sum` + 可复制命令。脚本的**运行输出**（判据 / 门禁 / 性能 / 阶段门）已在本附录 C-1–C-4 逐段给出原文，`PHASE5-RECEIPTS.md` §A–§I 为同一次运行的完整落档。

**第 5 次执行（REPRO4）时点的工作树值**（**未提交**；上表三行为第 1–4 次执行时点的历史值，保留不抹除）：

```text
$ sha256sum .specs/health-fix-2026-09b/reproduce-5-test.sh \
            .specs/health-fix-2026-09b/reproduce-phase-gate.sh \
            .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md
1d6082892d2a6f1504977a167259a628d532f1bdda1ed90182cff04f57f20b53  reproduce-5-test.sh      (192 行 · 本次改动后：判据 12 → 14、[F] 转闭合态)
81700f125c1c2557f4ebb468d41bbaf8aad452150b95371b4418464a8eb97337  reproduce-phase-gate.sh  (165 行 · **「闭合六态」版** · 第 5 次执行相对其入库提交 `ddea327` **未再改动**（工作树值 = 入库值）；第 1–4 次执行时点记录的 `4ddeb726…` 是**当时尚未入库的工作树版本** ⇒ C-5 行的「未改动」限定为「第 5 次执行相对 `T-FIX-02` 提交后未再改动」，**不**表示相对第 1 次执行未改)
a19b53b5bce4299d14769058d08e1cbc7323e786a12035aadbead892b5219806  PHASE5-RECEIPTS.md       (1043 行 · 本次刷新 §0/§H + 新增 §J)
```

> 读法（L3 第 8 轮 minor ② 统一口径）：`reproduce-phase-gate.sh` 的**最新版本 = `ddea327` 入库的闭合六态版**（165 行 · `81700f12…`，期望 B2/B3/B4 一律 rc=2）—— **「闭合态」是该脚本的期望值 + hook 侧 `done-validation.sh` 的「存在 ⇒ 存在且有效」改动（`T-FIX-02` = `6cff7a2`）共同定义的**，不靠「脚本哈希不变」保证；早先第 1–4 次执行时点记录的 `4ddeb726…` 是当时**尚未入库**的工作树版本。另两件因本次刷新而变化，提交后由主 agent 在 `INDEPENDENT-REVIEW-5.md` 的 `L3_artifact_hash:` 行记录新值（本报告不预言未提交状态的最终哈希）。`reproduce-5-test.sh` 的语法检查：`bash -n` **rc=0**；`make check-nfr-portability` **rc=0**（无 GNU-only / bash4-only 构造，bash 3.2 兼容）。

**第 6 次执行（终版 r4d）时点的脚本哈希（L3 第 9 轮 minor ② 响应 · 补证）**：

```text
$ sha256sum .specs/health-fix-2026-09b/reproduce-phase-gate.sh     # 第 6 次执行时点（工作树）
81700f125c1c2557f4ebb468d41bbaf8aad452150b95371b4418464a8eb97337  reproduce-phase-gate.sh  (165 行)
$ git show HEAD:.specs/health-fix-2026-09b/reproduce-phase-gate.sh | sha256sum
81700f125c1c2557f4ebb468d41bbaf8aad452150b95371b4418464a8eb97337  -
$ git diff --stat HEAD -- .specs/health-fix-2026-09b/reproduce-phase-gate.sh   # 空输出 ⇒ 工作树 == 入库版
```

> 结论（L3 第 9 轮 minor ② 收口）：**第 6 次执行所跑的阶段门沙箱脚本 = `81700f12…`（165 行 · 与 `ddea327` 入库版逐字节一致 · 该轮未改动）**，故六态全绿的结论对应的脚本版本无歧义；`4ddeb726…` 仅见于第 1–4 次执行时点（当时尚未入库的工作树版本）。

---

## 附录 D · 第 5 次执行（REPRO4 重入复跑）原始回执内嵌（L3 第 7 轮 major 3 / L-151 响应）

> **为何内嵌**：外部审查信封只把**补充产物前 3000 B** 送进提示词（`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:286` / `:304`，`L-151`）⇒ 决定性证据必须落在**本工件正文**内才可见。本节把第 5 次执行的关键原始行**原样粘贴**，仅按 `L-129` 把仓库根去形为 `<repo>`，**数字一字未改**；完整 stdout 存档 `/tmp/fk-reproduce-5-r4/repro4-full.log`（80859 B）与 `.specs/health-fix-2026-09b/PHASE5-RECEIPTS.md` **§J**。**判据集版本（L3 第 8 轮 major 2 响应）**：`D-0` ~ `D-3` = **修正前**判据集（`T27`/`T29` 旧地板 `-ge 973`）的整轮 14 条复跑；`D-4` = **修正后**地板版（`-ge 1009`，`T27`/`T29` 单条复跑 rc=0）；**`D-5` = 修正后判据集整轮（r4c）· 诚实记录 rc=1**（根因 = 源面在飞行中被改致 `check-dist` 陈旧，**非判据问题**）；**`D-6` = `G-T04-1`/`G-T04-2` 前置修复的处置事实**；**`D-7` = 第 6 次执行（终版 · 源面冻结 + 地板订正后）整轮 14 条判据 + 7 项门禁回执（`R4D_RC=0`）**。

### D-0 运行标识与总退出码

```text
命令：FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r4 bash .specs/health-fix-2026-09b/reproduce-5-test.sh

== 阶段 5 一键复算 · change health-fix-2026-09b ==
   仓库根 : <repo>
   HEAD   : ddea327d826b3182f68ebc4b000c3a4ab95da8dc
   时间   : 2026-09-24T16:56:45+08:00
   日志   : /tmp/fk-reproduce-5-r4
   bash   : 5.2.21(1)-release
...
✅ 复算全绿（判据 + 权威回执）；原始输出保存在 /tmp/fk-reproduce-5-r4
REPRO4_RC=0
```

**总退出码 = 0**（14 条判据 + 7 项门禁全绿；上一轮 REPRO2 的失败态 `REPRO2 rc=1 判据失败[ T29 ] 门禁失败=1` 保留在 §附录 A ⑤ 作为失败语义实证）。

**判据集版本标注（L3 第 8 轮 major 2 响应 · 必读）**：**D-0 ~ D-3 的整轮主复跑（REPRO4）用的是「修正前」判据集中的 `T27` / `T29`** —— 地板 `[ "$b_ok" -ge 973 ]`（= 976 − 3）、echo 描述串仍写「976 ok」；该轮 14 条判据的抽取件与**当时的** `TASK.md` 逐字节相同（这正是「字面执行」的含义：脚本只 `awk` 抽取、不改写任何一行）。**`D-4` = 修正后（`-ge 1009` = 1012 − 3）地板版**（`T27`/`T29` 单条复跑）；**`D-5` = 修正后判据集整轮（r4c）的 rc=1 诚实记录**（三条红 T29/T-FIX-01/T-FIX-02 均因源面在飞行中被改致 `check-dist` 陈旧，**非判据**）；**最终口径 = 第 6 次执行（`D-7` · 源面冻结后 `R4D_RC=0`）**。六条被修正判据的「修改前原文 + 来源 commit + 逐条执行结论」见 `PHASE5-RECEIPTS.md` **§K**（来源表 + 六份原文）与 **§L**（逐条机制与未入库首版的如实标注）。

### D-1 14 条判据的「抽取行数 + rc」（脚本逐条输出原文 + 汇总表原文）

```text
  T05  ✅ rc=0（12 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T05.txt）
  T06  ✅ rc=0（22 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T06.txt）
  T11  ✅ rc=0（7 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T11.txt）
  T13  ✅ rc=0（34 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T13.txt）
  T17  ✅ rc=0（73 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T17.txt）
  T19  ✅ rc=0（36 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T19.txt）
  T20  ✅ rc=0（3 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T20.txt）
  T22  ✅ rc=0（20 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T22.txt）
  T24  ✅ rc=0（18 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T24.txt）
  T26  ✅ rc=0（30 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T26.txt）
  T27  ✅ rc=0（19 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T27.txt）
  T29  ✅ rc=0（15 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T29.txt）
  T-FIX-01 ✅ rc=0（36 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T-FIX-01.txt）
  T-FIX-02 ✅ rc=0（42 行判据 / 输出 /tmp/fk-reproduce-5-r4/out_T-FIX-02.txt）

== 汇总 ==
| 判据 | 结果 | 抽取行数 | 原始输出 |
| --- | --- | --- | --- |
| T05 | ✅ rc=0 | 12 | `out_T05.txt` |
| T06 | ✅ rc=0 | 22 | `out_T06.txt` |
| T11 | ✅ rc=0 | 7 | `out_T11.txt` |
| T13 | ✅ rc=0 | 34 | `out_T13.txt` |
| T17 | ✅ rc=0 | 73 | `out_T17.txt` |
| T19 | ✅ rc=0 | 36 | `out_T19.txt` |
| T20 | ✅ rc=0 | 3 | `out_T20.txt` |
| T22 | ✅ rc=0 | 20 | `out_T22.txt` |
| T24 | ✅ rc=0 | 18 | `out_T24.txt` |
| T26 | ✅ rc=0 | 30 | `out_T26.txt` |
| T27 | ✅ rc=0 | 19 | `out_T27.txt` |
| T29 | ✅ rc=0 | 15 | `out_T29.txt` |
| T-FIX-01 | ✅ rc=0 | 36 | `out_T-FIX-01.txt` |
| T-FIX-02 | ✅ rc=0 | 42 | `out_T-FIX-02.txt` |
| 门禁 | 结果 | 摘要 |
| --- | --- | --- |
| bats --count | ✅ rc=0 | 用例数 1012（源码面 test/*.bats） |
| bats test/ | ✅ rc=0 | rc=0 ok=1012 not-ok=0（基线 1012 ok / 0 not ok，skip 计入 ok 行） |
| make check | ✅ rc=0 | 21 条 ✅ / 0 条 ❌（原文 /tmp/fk-reproduce-5-r4/make-check.txt） |
| check-path-privacy | ✅ rc=0 | ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞） |
| NFR ≤5s ×5 | ✅ rc=0 | 环境 nproc=32 loadavg=7.91 8.12 7.49 |
| package --validate | ✅ rc=0 |    🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0  |
| 阶段门沙箱复现 | ✅ rc=0 | 健康层 A/B/C ✅ · 无效标记 B2/B3/B4 一律 rc=2 ✅（TD-059 已闭合 · ADR-029 · commit 6cff7a2）· 原文 /tmp/fk-reproduce-5-r4/phase-gate.txt |
```

**抽取行数由脚本 `wc -l` 现场统计**（≠ 判据语义行数，含空行与注释）：与第 1–4 次执行逐一相同（T05 12 / T06 22 / T11 7 / T13 34 / T17 73 / T19 36 / T20 3 / T22 20 / T24 18 / T26 30 / T27 19 / T29 15），新增两条为 `T-FIX-01` **36 行** · `T-FIX-02` **42 行**。

**新增两条判据的完整 stdout**（各 1 行，逐字节原文）：

```text
[T-FIX-01] TAP: ok=25 not-ok=0 rc=0        # 25 例 = path_privacy 9 + runtime_edit_guard 9 + nfr_portability 7；含恒绿桩注入 ⇒ 12 例转红 ⇒ 还原 cmp 一致后回绿
[T-FIX-02] A=2 B=0 B2=2 B3=2 B4=2 C=0      # 阶段门六态自检（修复前 B2/B3 为 0）
```

### D-2 权威回执原文关键行（bats TAP · `make check` · privacy · NFR 计时 · validate）

```text
== bats 权威回执 ==
bats --count：1012（源码面 test/*.bats）
npx bats test/ ：ok 行 1012 条 · not ok 行 0 条 · 显式 skip 0 条（TAP plan 1..1012）
   计数命令：grep -c '^ok ' /tmp/fk-reproduce-5-r4/bats-tap.txt ⇒ 1012
             grep -c '^not ok ' /tmp/fk-reproduce-5-r4/bats-tap.txt ⇒ 0
   有效用例 = 1011（1 例 TD-033 mock 不计，§1.3 第 5 条）

== make check（21 条 ✅ / 0 条 ❌）尾部原文 ==
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=/home/[a-z_][a-z0-9_-]*/）
   扫描面: 工作树
   允许清单来源: flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
   允许清单 0 条
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
🔍 make check-nfr-portability: NFR 兼容性判据（bash 3.2/macOS 可移植 · 三态包装）...
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝

== check-path-privacy 自证面 ==
  check-path-privacy     ✅ rc=0  ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）

== [D] NFR 性能预算（5 次 · 预算 ≤5s）==
       run 1: real=2.881 user=1.195 sys=1.850
       run 2: real=2.889 user=1.190 sys=1.857
       run 3: real=2.892 user=1.223 sys=1.819
       run 4: real=2.929 user=1.177 sys=1.909
       run 5: real=2.885 user=1.218 sys=1.825
  NFR ≤5s ×5          ✅ rc=0  环境 nproc=32 loadavg=7.91 8.12 7.49
   均值 = (2.881+2.889+2.892+2.929+2.885)/5 = 14.476/5 = 2.895 s
   占 5 s 预算 = 57.9%（预算口径：`make check-path-privacy` 单次 real ≤ 5 s）

== [E] 打包覆盖 validate ==
   期望覆盖: 315 项
   实际文件: 321 项
   🔴 漏配 (ERROR): 0
   ⚠️  源缺失 (WARNING): 0
   ✅ 校验通过：所有文件均被 Part A~G 覆盖。
  package --validate     ✅ rc=0     🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0
```

### D-3 阶段门沙箱六态 stdout 全文（`/tmp/fk-reproduce-5-r4/phase-gate.txt` · 仅仓库根去形）

> **脚本版本口径（L3 第 8 轮 minor ②）**：以下 stdout 由 `reproduce-phase-gate.sh` 的**闭合六态版**产生 = **165 行 · sha256 `81700f125c1c2557f4ebb468d41bbaf8aad452150b95371b4418464a8eb97337`**（入库于 `ddea327`；期望 B2/B3/B4 一律 rc=2，与 `T-FIX-02` = `6cff7a2` 的 hook 侧修复同批落地）；第 1–4 次执行时点的 `4ddeb726…` 为未入库的旧工作树版本（其五态 stdout 见 `PHASE5-RECEIPTS.md` §H 的历史对照）。

```text
== 沙箱 = /tmp/fk-phasegate-MWcd5D
== 门禁 = <repo>/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh

── 对照 0：门禁外直连 git …（证明仓库本身可提交，拦截不是命令形态问题）
  ✅ 门禁外直连 commit 成功（HEAD 前进）（yes）

── 状态 A：gate_config["5-test"]=both 且无 .done（历史事件 ③ 的等价形态）
  ✅ 门禁 rc（拒绝）（2）
  ✅ 报文含「⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。」
  ✅ HEAD 未变（e2c73dd8607c3060d491fd006ff2e125af2803bb）

── 状态 B：gate_config["5-test"]=L2 + 合格 .done（6 键 KVP · 阶段 5 健康态）── 同一命令应放行
  ✅ 门禁 rc（放行）（0）
  ✅ 放行后真 commit 生效（HEAD 前进）（yes）

── 状态 B2：.done 记 pass 而审查档记 fail（口径不一致 · Tier-2 T4 一致性）⇒ 期望 rc=2（存在 ≠ 有效 · ADR-029）
  ✅ 口径不一致（标记记 pass / 审查档记 fail）被拒（2）
  ✅ 报文含「禁止 git commit。」

── 状态 B3：.done 被 touch 成 0 字节（存在但空 · Tier-1 非空校验）⇒ 期望 rc=2（修复前：rc=0 缺口）
  ✅ 空标记（touch 0 字节）被拒（2）
  ✅ 报文含「禁止 git commit。」

── 状态 B4：.done 缺 L3_verdict 键（5 行 < MIN_MEANINGFUL_LINES=6 · Tier-1 键集/行数）⇒ 期望 rc=2（修复前：rc=0 缺口）
  ✅ 残缺标记（删 L3_verdict 键 · 5 行 < 6 行下限）被拒（2）

── 状态 C：沙箱无 .flow-active（门不适用 ⇒ fail-open 对照）
  ✅ 门禁 rc（不适用）（0）

✅ 阶段门复现：健康层全绿 —— A 拒绝且 HEAD 不变 · B 放行且 commit 真的生效 · B2/B3/B4 无效标记一律拒绝（存在 ≠ 有效 · ADR-029）· C 门不适用放行；判别子：门禁外直连 commit 可用 ⇒ 拦截确由门禁判定产生。
ℹ️ 历史对照（TD-059 缺口实证）：修复前 B2（口径相悖）/ B3（空标记）/ B4（缺键）均是「存在即放行」的 rc=0；现收敛为 rc=2。
```

**判读要点**：`A` 的 HEAD 不变（`e2c73dd…`）证明拒绝确实发生在 commit 之前；`B` 的「放行后真 commit 生效（HEAD 前进）」证明 rc=0 不是空放行；`B2/B3/B4` 三态覆盖了 Tier-2 口径一致性与 Tier-1 非空/键集/行数下限；`C` 是 fail-open 反面对照（门不适用时应放行）⇒ 拦截不是「一律拒绝」的伪阳性。

> **本轮实测的两处「看不到就不要说」**：① 本节所有数字**未做任何人工归一化**（如 `user`/`sys` 秒数、`loadavg` 三位小数均原样）；② `T-FIX-01`/`T-FIX-02` 的判据文本已在 `TASK.md` 内（权威副本），本节只给**运行结果**，判据原文由 `reproduce-5-test.sh` 每次**重新 awk 抽取**（不落档副本 ⇒ 不会与 `TASK.md` 分叉）。

### D-4 `T27`/`T29` 回归地板订正后的复跑（§1.7 台账第三行 · 第 5 次执行期间由主 agent 就地修 `TASK.md`）

`T27`/`T29` 的 bats 回归**地板**原按 976 基线标定（`-ge 973` = 976 − 3）；报告 §1.7 复核发现基线升到 1012 后旧地板允许 **39 例静默消失** ⇒ 主 agent 就地修 `TASK.md`（`:1231` / `:1306` 断言 → `-ge 1009` = 1012 − 3，并同步 `:1229` / `:1291` / `:25` 描述串与两条 `<done>` 注记；`<verify>` 行数未变）。**修正后原样重跑两条判据（抽取件由脚本重新 awk 生成）**：

```text
命令：FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r4b bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only --only T27,T29
  T27  ✅ rc=0（19 行判据 / 输出 /tmp/fk-reproduce-5-r4b/out_T27.txt）
  T29  ✅ rc=0（15 行判据 / 输出 /tmp/fk-reproduce-5-r4b/out_T29.txt）
✅ 复算全绿（判据 + 权威回执）；原始输出保存在 /tmp/fk-reproduce-5-r4b
T27T29_RC=0

抽取件断言行（逐字节原文；路径 = 抽取件:行号）
  修正前（/tmp/fk-reproduce-5-r4/v_T27.sh:19 · /tmp/fk-reproduce-5-r4/v_T29.sh:10）：
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 973 ]; } || { echo "🔴 bats 回归（rc=$b_rc not-ok=$b_no ok=$b_ok）"; exit 1; }
  修正后（/tmp/fk-reproduce-5-r4b/v_T27.sh:19 · /tmp/fk-reproduce-5-r4b/v_T29.sh:10）：
    { [ "$b_rc" -eq 0 ] && [ "$b_no" -eq 0 ] && [ "$b_ok" -ge 1009 ]; } || { echo "🔴 bats 回归（rc=$b_rc not-ok=$b_no ok=$b_ok）"; exit 1; }

T27 复跑 stdout 末行（新描述串已生效）：
    bats: rc=0 ok=1012 not-ok=0（当前基线 2026-09-24 T-FIX-02 收口实测 rc=0 / 1012 ok / 0 not ok，skip 计入 ok 行；地板 = 基线 − 3）
```

**判定**：新地板下 `ok=1012 ≥ 1009` ⇒ 两条判据仍 **rc=0**（红绿不变），但判定面已收紧 —— `ok ≤ 1008` 自此可判失败，旧地板下的 39 例静默缺口不再可能。注意第 5 次执行的主复跑（D-0..D-3）发生在该订正**之前**，故主复跑记录的是旧地板 `-ge 973` 下的 rc=0；本小节是对**同一 HEAD + 订正后 `TASK.md`** 的补跑，两者结论一致（rc=0）。

### D-5 修正后判据集（`-ge 1009`）整轮 14 条复跑 · **未全绿（rc=1）** 与根因（L3 第 8 轮 major 2 收口 · 诚实记录）

- **命令**：`FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r4c bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only`
- **运行时点 / 环境**：2026-09-24 **18:09:29 → 18:25:42**（**晚于** `D-0` ~ `D-3` 的主复跑 16:56–17:22）· HEAD `ddea327d826b3182f68ebc4b000c3a4ab95da8dc` · 日志 `/tmp/fk-reproduce-5-r4c/r4c-full.log`（58 行）
- **总退出码**：**`R4C_RC=1`** —— 末行原文：`🔴 复算未全绿：判据失败[ T29 T-FIX-01 T-FIX-02 ] 门禁失败=0`

| 判据 | r4c 结果 | 抽取行数 | 与 `D-1`（r4）的抽取件比对 |
| --- | --- | --- | --- |
| `T05` | ✅ rc=0 | 12 | 逐字节相同 |
| `T06` | ✅ rc=0 | 22 | 逐字节相同 |
| `T11` | ✅ rc=0 | 7 | 逐字节相同 |
| `T13` | ✅ rc=0 | 34 | 逐字节相同 |
| `T17` | ✅ rc=0 | 73 | 逐字节相同 |
| `T19` | ✅ rc=0 | 36 | 逐字节相同 |
| `T20` | ✅ rc=0 | 3 | 逐字节相同 |
| `T22` | ✅ rc=0 | 20 | 逐字节相同 |
| `T24` | ✅ rc=0 | 18 | 逐字节相同 |
| `T26` | ✅ rc=0 | 30 | 逐字节相同 |
| `T27` | ✅ rc=0 | 19 | **仅 2 行不同**（地板 `-ge 973` → `-ge 1009` · echo 串 976 → 1012） |
| `T29` | 🔴 rc=1 | 15 | **仅 2 行不同**（同上） |
| `T-FIX-01` | 🔴 rc=1 | 36 | 判据文本未变（失败因 `make check`） |
| `T-FIX-02` | 🔴 rc=1 | 42 | 判据文本未变（失败因 `make check`） |

**根因（已定位到唯一原因 · 与地板订正、与本产物均无关）**：复跑期间**工作树被并行修改了源面**（不是本产物所为 —— 我只改 `.specs/health-fix-2026-09b/` 下的 `TEST.md` / `PHASE5-RECEIPTS.md`），`git status --porcelain` 当时含三个 ` M` 源面文件：

```text
 M flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
 M flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
 M test/test_l3_review_defects_2026_09.bats
```

⇒ `make check` 的**打包件新鲜度门禁**报（原文，去形后）：

```text
📦 make check-dist: 打包件新鲜度检查 ...
❌ 陈旧: <repo>/dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_l3_review_defects_2026_09.bats（内容与 <repo>/flow-kit-bundle/test/test_l3_review_defects_2026_09.bats 不一致 → 请重建 dist）

→ 修复: bash package-dsh-plugin.sh
  注意顺序: 若改过 test/，先 make test-sync，再重建 dist
make: *** [Makefile:348：check-dist] 错误 1
```

**为何恰好是这三条红**：`T29` / `T-FIX-01` / `T-FIX-02` 的 `<verify>` 都以 `make check`（内含 `check-dist`）为**必经步骤** —— `T29` 的顺序是 `make check` 在前、`npx bats` 在后，故它在 bats 之前就 `exit 1`；`T-FIX-01`/`T-FIX-02` 同样把 `check-dist` 列为硬断言（`out_T-FIX-01.txt:2` = `🔴 dist 未重建（check-dist 失败）`）。**新地板本身在 r4c 中已跑通**：`out_T27.txt:3` = `bats: rc=0 ok=1012 not-ok=0（当前基线 2026-09-24 T-FIX-02 收口实测 rc=0 / 1012 ok / 0 not ok，skip 计入 ok 行；地板 = 基线 − 3）`；`T27` 的 `-ge 1009` 断言随 rc=0 通过。

**未采取的动作（有意）**：`make test-sync` / `bash package-dsh-plugin.sh` 均属**源面/构建面**，不在本执行者的授权范围内（派单要求「不要改源面」），且那三个文件的改动**不是本执行者的在制品**，故**未**代为同步或重建 —— 这属于「受限时应把限制写进回复交上级处理」。

**对既有一致性的影响（如实声明）**：`D-0` ~ `D-3` 的绿色主复跑**时序早于**上述并发改动，其 rc=0 与 bats `ok=1012` 结论**不受影响**，但**不能**用它宣称「当前工作树 `make check` 全绿」—— 当前工作树的 `check-dist` 是红的，直到那批源面改动落定并按其提示顺序（`make test-sync` → `bash package-dsh-plugin.sh`）重建 dist 后，需**再跑一次整轮**才能给出修正后判据集的全绿终版回执。`T27`/`T29` 两条的**修正后单条复跑**（不涉 `make check` 的 `T27`、以及以 bats 地板为主要断言面的路径）在 `D-4`（`T27T29_RC=0`）中已绿。

### D-6 `G-T04-1` / `G-T04-2` 前置修复的处置事实（源面冻结前 · 零行为变更 · 计数不变）

**性质**：这是**主 agent 在阶段 5 门禁之前必须完成的前置修复**（`MINOR-DEFERRED.md` 自定），**不是**阶段 5 判据面的失败；它**先于**下面 `D-7` 记录的终版整轮复跑（第 6 次执行）落树，并在落树后**冻结**。

| 项 | 改动点 | before → after（关键句） |
| --- | --- | --- |
| `G-T04-1` | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:364`（ADR 预算用尽标记） | `以下被工件引用的 ADR **未纳入**` → `以下为**工件引用的 ADR 全清单**（其中已在上文附 \`--- … ---\` 正文标记者即为**已纳入**，其余为**未纳入**）` |
| `G-T04-2` | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:369`（补充产物截断标记） | `已按整行**截断**` → `已按**字节**截断（仅保证 UTF-8 码点边界安全，末行可能不完整）` |

- **`G-T04-2` 的口径依据**：该路径**没有** `sed '$d'`（只有 ADR 路径有整行截断）⇒ 原「已按整行截断」文案与实现行为不符；按 `MINOR-DEFERRED.md` 的裁定取**「文案对齐实现」**路线（不改实现，只改文案）。
- **静态钉住（防回潮）**：`test/test_l3_review_defects_2026_09.bats` 的 **`B11-R6` 用例内部追加 6 条静态断言**（`工件引用的 ADR 全清单` 在位 · 旧「未纳入」措辞不存在 · `已按**字节**截断` 在位 · 旧「整行**截断**」措辞不存在 · `sed '$d'` 仍在位 · 补充产物路径仍为真整行截断）—— **不新增用例**，故 bats 收集计数**仍为 1012**（`npx bats --count test/` 实测 = `1012`）。
- **副本与构建面同步**：`./sync-hooks.sh` 同步 **6 个文件**（5 个仓外副本 + bundle 内）· `bash package-dsh-plugin.sh` **rc=0** · `make check-dist` = **✅ dist 与源一致**（此前 `r4c` 的 `❌ 陈旧` 即由该批改动的 dist 未重建引起）· `make check-hooks-sync check-test-sync` = **✅ 漂移 0 · ✅ test 双源一致**。
- **行为面**：两处均为**纯文案**（零行为变更）；新增 6 条断言为**静态文本断言**（不引入新行为路径）。改后该文件单独跑 `npx bats test/test_l3_review_defects_2026_09.bats` = **124 ok / 0 not ok**。
- **与阶段 5 结论的关系**：该修复**不改变**任何 AC 的判定，也**不新增**任何 AC 证据面；它的作用是把「主 agent 自定的前置修复」与「阶段 5 判据面」分离，使终版整轮复跑（`D-7`，见下）能在**源面冻结**的树上取得 rc=0。
- **与终版复跑 HEAD 的关系（L3 第 9 轮 major 4 响应 · 关键澄清）**：`D-7` 的运行标识 `HEAD = ddea327` 指的是**提交 HEAD**；该次复跑（18:26:52 → 18:52:27）执行时，上述 `G-T04-1` / `G-T04-2` 改动**尚未提交**，位于**工作树**（且 `make test-sync` + `bash package-dsh-plugin.sh` 已按该工作树重建 dist）⇒ **r4d 实际运行的内容 = `ddea327` 的提交内容 + 该三文件的工作树改动**。此后主 agent 在阶段 5 门禁前把该三文件提交为 **`f446617`**（3 files · +22/−2；提交前对该三文件**无任何进一步编辑** ⇒ **`f446617` 的树内容 = r4d 执行时的工作树内容**）。**「源面冻结」的准确含义 = 自 `f446617` 起不再变更源面**（本 change 后续只剩文档/工件提交）；故「冻结」与「r4d 时点未提交」**不矛盾** —— 冻结的是**内容**，提交发生在复跑之后。

### D-7 第 6 次执行（终版 · 源面冻结 + 地板订正后）整轮 14 条判据 + 7 项门禁回执

- **命令**：`FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r4d bash .specs/health-fix-2026-09b/reproduce-5-test.sh`（判据 + 七项门禁全跑）
- **运行标识**：2026-09-24 **18:26:52 → 18:52:27** · HEAD `ddea327d826b3182f68ebc4b000c3a4ab95da8dc` · bash 5.2.21 · 日志 `/tmp/fk-reproduce-5-r4d/r4d-full.log`
- **总退出码**：**`0`**（末两行原文见下）

```text
✅ 复算全绿（判据 + 权威回执）；原始输出保存在 /tmp/fk-reproduce-5-r4d
R4D_RC=0
```

**判据 14 条（逐条 rc + 抽取行数）**

```text
| 判据 | 结果 | 抽取行数 | 原始输出 |
| --- | --- | --- | --- |
| T05 | ✅ rc=0 | 12 | `out_T05.txt` |
| T06 | ✅ rc=0 | 22 | `out_T06.txt` |
| T11 | ✅ rc=0 | 7 | `out_T11.txt` |
| T13 | ✅ rc=0 | 34 | `out_T13.txt` |
| T17 | ✅ rc=0 | 73 | `out_T17.txt` |
| T19 | ✅ rc=0 | 36 | `out_T19.txt` |
| T20 | ✅ rc=0 | 3 | `out_T20.txt` |
| T22 | ✅ rc=0 | 20 | `out_T22.txt` |
| T24 | ✅ rc=0 | 18 | `out_T24.txt` |
| T26 | ✅ rc=0 | 30 | `out_T26.txt` |
| T27 | ✅ rc=0 | 19 | `out_T27.txt` |
| T29 | ✅ rc=0 | 15 | `out_T29.txt` |
| T-FIX-01 | ✅ rc=0 | 36 | `out_T-FIX-01.txt` |
| T-FIX-02 | ✅ rc=0 | 42 | `out_T-FIX-02.txt` |
```

**门禁 7 项**

```text
| 门禁 | 结果 | 摘要 |
| --- | --- | --- |
| bats --count | ✅ rc=0 | 用例数 1012（源码面 test/*.bats） |
| bats test/ | ✅ rc=0 | rc=0 ok=1012 not-ok=0（基线 1012 ok / 0 not ok，skip 计入 ok 行） |
| make check | ✅ rc=0 | 21 条 ✅ / 0 条 ❌（原文 /tmp/fk-reproduce-5-r4d/make-check.txt） |
| check-path-privacy | ✅ rc=0 | ✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞） |
| NFR ≤5s ×5 | ✅ rc=0 | 环境 nproc=32 loadavg=6.94 6.83 7.13 |
| package --validate | ✅ rc=0 |    🔴 漏配 (ERROR): 0    ⚠️  源缺失 (WARNING): 0  |
| 阶段门沙箱复现 | ✅ rc=0 | 健康层 A/B/C ✅ · 无效标记 B2/B3/B4 一律 rc=2 ✅（TD-059 已闭合 · ADR-029 · commit 6cff7a2）· 原文 /tmp/fk-reproduce-5-r4d/phase-gate.txt |

```

**权威回执关键行（原文 · 数字未改写）**

```text
  bats --count           ✅ rc=0  用例数 1012（源码面 test/*.bats）
  bats test/             ✅ rc=0  rc=0 ok=1012 not-ok=0（基线 1012 ok / 0 not ok，skip 计入 ok 行）
-- make check 尾框 --
✅ NFR 兼容性判据通过：无新增 bash4-only / GNU-only 构造，语法检查通过

╔════════════════════════════════════════════════════╗
║  ✅ make check: 全部通过                           ║
╚════════════════════════════════════════════════════╝
-- check-path-privacy（清单外命中）--
🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ...
   命中合计 0 条（含占位符排除后）
   清单外命中 0 条
✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）
-- NFR 性能预算 5 次（预算 ≤5 s；均值 = 2.937 s = 58.7%）--
       run 1: real=2.965 user=1.205 sys=1.915 
       run 2: real=2.932 user=1.196 sys=1.902 
       run 3: real=2.940 user=1.203 sys=1.901 
       run 4: real=2.936 user=1.183 sys=1.915 
       run 5: real=2.912 user=1.231 sys=1.834 
-- package-flow-kit.sh --validate --
   扫描 flow-kit-bundle/ 实际文件...
   期望覆盖: 315 项
   实际文件: 321 项
   🔴 漏配 (ERROR): 0
   ⚠️  源缺失 (WARNING): 0
-- 阶段门沙箱六态（摘要 6 行 + 历史对照）--
── 状态 A：gate_config["5-test"]=both 且无 .done（历史事件 ③ 的等价形态）
  ✅ 门禁 rc（拒绝）（2）
── 状态 B：gate_config["5-test"]=L2 + 合格 .done（6 键 KVP · 阶段 5 健康态）── 同一命令应放行
  ✅ 门禁 rc（放行）（0）
── 状态 B2：.done 记 pass 而审查档记 fail（口径不一致 · Tier-2 T4 一致性）⇒ 期望 rc=2（存在 ≠ 有效 · ADR-029）
  ✅ 口径不一致（标记记 pass / 审查档记 fail）被拒（2）
── 状态 B3：.done 被 touch 成 0 字节（存在但空 · Tier-1 非空校验）⇒ 期望 rc=2（修复前：rc=0 缺口）
  ✅ 空标记（touch 0 字节）被拒（2）
── 状态 B4：.done 缺 L3_verdict 键（5 行 < MIN_MEANINGFUL_LINES=6 · Tier-1 键集/行数）⇒ 期望 rc=2（修复前：rc=0 缺口）
  ✅ 残缺标记（删 L3_verdict 键 · 5 行 < 6 行下限）被拒（2）
── 状态 C：沙箱无 .flow-active（门不适用 ⇒ fail-open 对照）
  ✅ 门禁 rc（不适用）（0）
ℹ️ 历史对照（TD-059 缺口实证）：修复前 B2（口径相悖）/ B3（空标记）/ B4（缺键）均是「存在即放行」的 rc=0；现收敛为 rc=2。
```

> **读法**：本小节 = 终版（源面冻结 + 地板订正后）的**整轮**回执摘要，完整原文见 `PHASE5-RECEIPTS.md` **§M**（§M-1 判据 · §M-2 门禁 · §M-3 权威行 · §M-4 六态全文）；`D-0` ~ `D-3` 为**修正前**判据集的整轮（rc=0），`D-4` 为修正后地板版单条（rc=0），**`D-5` 为中间轮（r4c）的 rc=1 诚实记录**（根因 = 源面在飞行中被改致 `check-dist` 陈旧，非判据问题；`D-6` 记该批修复的处置事实）。

### D-9 第 8 次执行（第 2 轮 fix 循环后重验 · 18 条判据 + 7 项门禁）原始回执内嵌

**运行标识**：`FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r7 bash .specs/health-fix-2026-09b/reproduce-5-test.sh` ⇒ **`REPRO7_RC=0`**；HEAD = `26d5d7b`；起始 **2026-09-25T03:31:23+08:00**；`bash 5.2.21(1)-release`；脚本 = `reproduce-5-test.sh`（206 行 · `DEFAULT_IDS` 18 条）。

**D-9-1 判据（18/18 rc=0 · `抽取行数` = 判据块有效命令/断言行数）**

| # | 判据 | 抽取行数 | rc | 原始输出 |
|---|---|---|---|---|
| 1 | T05 | 12 | 0 | §P-1 |
| 2 | T06 | 22 | 0 | §P-1 |
| 3 | T11 | 7 | 0 | §P-1 |
| 4 | T13 | 34 | 0 | §P-1 |
| 5 | T17 | **74**（TD-066 订正后 +1） | 0 | §P-1 |
| 6 | T19 | 36 | 0 | §P-1 |
| 7 | T20 | 3 | 0 | §P-1 |
| 8 | T22 | 20 | 0 | §P-1 |
| 9 | T24 | 18 | 0 | §P-1 |
| 10 | T26 | 30 | 0 | §P-1 |
| 11 | T27 | 19 | 0 | §P-1 |
| 12 | T29 | 15 | 0 | §P-1 |
| 13 | T-FIX-01 | 36 | 0 | §P-1 |
| 14 | T-FIX-02 | 42 | 0 | §P-1 |
| 15 | T-FIX-03 | 78 | 0 | §P-1 |
| 16 | T-FIX-04 | 44 | 0 | §P-1 |
| 17 | T-FIX-05 | 26 | 0 | §P-1 |
| 18 | T-FIX-06 | **41**（TD-067 订正后 · 原 43 行废件） | 0 | §P-1 |

**D-9-2 门禁（7/7 rc=0）**：bats `--count` = **1029** · `npx bats test/` = ok **1029** / not ok **0**（TAP `1..1029`）· `make check` = 21 ✅ / 0 ❌ · `check-path-privacy` = 清单外命中 **0**（自证行含候选/实际扫描/自排除三数）· NFR ×5 = 3.146 / 3.050 / 3.051 / 3.127 / 3.011 s（均值 **3.077 s = 61.5%** · `loadavg` 6.40 7.21 8.07 · `nproc=32`）· `package-flow-kit.sh --validate` = 期望 315 / 实际 321 / 漏配 **0** / 源缺失 **0** · 阶段门沙箱六态 = 对照 0 · A rc=2（HEAD `65343b0000ba762ba6ebf2d80c36c9caaf5fa312` 未变）· B rc=0（commit 真生效）· B2/B3/B4 一律 rc=2 · C rc=0（完整原文 `PHASE5-RECEIPTS.md` **§P-3/§P-4**）。

**D-9-3 本轮暴露并订正的两条判据/工具面缺陷**：（见 §1.7 第 8 次执行行与发现表 #41/#42 · `TD-066` = `T17` 对照夹具候选面全自排除 · `TD-067` = 抽取器未整行锚定）——**均非生产件回归**，订正后本轮的 18 条判据与 7 项门禁按**订正后**的判据集/工具复跑取全绿。

### D-10 第 9 次执行（阶段 6 第 3 轮裁决回退 4-dev 后的重验 · 判据面 23 条）原始回执内嵌 —— **本轮 NFR 判据 ❌（诚实记录）**

**运行标识**：`FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r8 bash .specs/health-fix-2026-09b/reproduce-5-test.sh`（HEAD = `bf3763f`）⇒ **脚本总退出码 `rc=0`**，但当时脚本把 NFR 门禁的 rc **硬编码为 0**（`emit_gate "NFR ≤5s ×5" 0 "…"`）⇒ 该「全绿」不可作为判定依据（`TD-077`）。原始日志 `/tmp/p6c/repro8.out` · 逐条输出 `/tmp/fk-reproduce-5-r8/out_<ID>.txt` · 全文回执见 `PHASE5-RECEIPTS.md §R`。

**D-10-1 判据（23/23 rc=0 · 数字 = 抽取行数）**：T05 12 · T06 22 · T11 7 · T13 34 · T17 74 · T19 36 · T20 3 · T22 20 · T24 18 · T26 30 · T27 19 · T29 15 · T-FIX-01 36 · T-FIX-02 42 · T-FIX-03 78 · T-FIX-04 44 · T-FIX-05 26 · T-FIX-06 41 · T-FIX-07 87 · T-FIX-08 56 · T-FIX-09 58 · T-FIX-10 72 · T-FIX-11 58。

**D-10-2 门禁（7 项 · 1 项 ❌）**：bats `--count` = **1061** · `npx bats test/` = ok **1061** / not ok **0** · `make check` = **21 ✅ / 0 ❌** · `check-path-privacy` 候选 1600 / 实际扫描 1594 / index 侧 13 / 不可读 0 / 命中 0 / 清单外 0 ✅ · `package-flow-kit.sh --validate` 漏配 0 / 源缺失 0 ✅ · 阶段门沙箱六态（A rc=2 · B rc=0 · B2/B3/B4 rc=2 · C rc=0）✅ · **NFR ❌** = `time make check-path-privacy` ×5 的 `real`：`10.741 / 10.885 / 10.783 / 11.510 / 11.469 s`（max 11.510 · 均值 **11.078 s = 预算 221.6%**；判据 `REQUIREMENT.md:495`「单次运行 ≤5 秒」· 本节 `:248`「超阈值即未满足」· `:265`「绝对阈值、不做负载折算」；环境 nproc=32 · loadavg 8.08 / 6.86 / 6.40）。⇒ **阶段 5 判定 ❌ 未通过**（不得据此过 4→5 门）。

**D-10-3 根因与闭合**：`T-FIX-07`（R3-2 修复）在 `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 内为**每个候选各起一次** `git grep --cached -naE --null … -- "$file"`（1594 次进程）⇒ A/B 实测 `7b624dc`（594 行）= 3.191 s · `20847e1`（T-FIX-07 · 692 行）= 10.662 s · `bf3763f`（769 行）= 10.778 s；微基准 = 每文件一次 4.28 ms（150 次 0.642 s）vs 全 index 一次 0.023 s（≈290×）。处置：`TD-077`（`reproduce-5-test.sh` 的 `[D]` 段改**真断言**：逐次解析 `real=`、`awk` 判 `>5`、打印 max/均值/预算百分比、超限即 `emit_gate … 1` ⇒ 脚本 `exit 1`）＋ **`T-FIX-12`**（index 侧批量预扫描 + 一次 `git cat-file --batch-check` 处理磁盘缺失候选；commit `c177fbac8ffe8c24a989fa5d6bb9ac9574fb2fa3`）⇒ 修复后同机 5 次 `3.722 / 3.562 / 3.489 / 3.664 / 3.581 s`（均值 3.604 = 预算 72.1%），第 10 次执行复审见 `D-11`。

### D-8 第 7 次执行（fix 循环后重验 · 17 条判据 + 7 项门禁）原始回执内嵌

**运行标识**：`FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r5 bash .specs/health-fix-2026-09b/reproduce-5-test.sh` ⇒ **`REPRO5_RC=0`**；HEAD = `ee29a6d`；起始 **2026-09-25T00:26:42+08:00**；`bash 5.2.21(1)-release`；脚本 = `reproduce-5-test.sh`（198 行 · `DEFAULT_IDS` 17 条）。

**D-8-1 判据（17/17 rc=0 · `抽取行数` = 判据块有效命令/断言行数）**

| 判据 | 结果 | 抽取行数 | 原始输出 |
|---|---|---|---|
| T05 | ✅ rc=0 | 12 | `out_T05.txt` |
| T06 | ✅ rc=0 | 22 | `out_T06.txt` |
| T11 | ✅ rc=0 | 7 | `out_T11.txt` |
| T13 | ✅ rc=0 | 34 | `out_T13.txt` |
| T17 | ✅ rc=0 | 73 | `out_T17.txt` |
| T19 | ✅ rc=0 | 36 | `out_T19.txt` |
| T20 | ✅ rc=0 | 3 | `out_T20.txt` |
| T22 | ✅ rc=0 | 20 | `out_T22.txt` |
| T24 | ✅ rc=0 | 18 | `out_T24.txt` |
| T26 | ✅ rc=0 | 30 | `out_T26.txt` |
| T27 | ✅ rc=0 | 19 | `out_T27.txt` |
| T29 | ✅ rc=0 | 15 | `out_T29.txt` |
| **T-FIX-01** | ✅ rc=0 | 36 | `out_T-FIX-01.txt` |
| **T-FIX-02** | ✅ rc=0 | 42 | `out_T-FIX-02.txt` |
| **T-FIX-03**（新增纳入） | ✅ rc=0 | 78 | `out_T-FIX-03.txt` |
| **T-FIX-04**（新增纳入 · 判据经 `TD-065` 修复） | ✅ rc=0 | 44 | `out_T-FIX-04.txt` |
| **T-FIX-05**（新增纳入） | ✅ rc=0 | 26 | `out_T-FIX-05.txt` |

**D-8-2 门禁（7/7 rc=0）**

| 门禁 | 结果 | 摘要（原文） |
|---|---|---|
| `npx bats --count test/` | ✅ rc=0 | `用例数 1025（源码面 test/*.bats）` |
| `npx bats test/` | ✅ rc=0 | `rc=0 ok=1025 not-ok=0（基线 1025 ok / 0 not ok，skip 计入 ok 行）` |
| `make check` | ✅ rc=0 | `21 条 ✅ / 0 条 ❌`（尾框 `✅ make check: 全部通过`） |
| `make check-path-privacy` | ✅ rc=0 | `扫描面: 工作树` · `允许清单 0 条` · `命中合计 0 条（含占位符排除后）` · `清单外命中 0 条` |
| NFR ≤5 s ×5 | ✅ rc=0 | `nproc=32 loadavg=7.64 7.86 7.83`；real = 2.985 / 3.005 / 3.012 / 3.019 / 3.032 ⇒ 均值 **3.011 s = 60.2%** |
| `bash package-flow-kit.sh --validate` | ✅ rc=0 | `期望覆盖: 315 项` · `实际文件: 321 项` · `🔴 漏配 (ERROR): 0` · `⚠️ 源缺失 (WARNING): 0` |
| 阶段门沙箱复现（六态） | ✅ rc=0 | 见 D-8-4 |

**D-8-3 三条 fix 判据的 stdout 关键行（原文）**

```text
-- T-FIX-03（隐私门禁 fail-open 收敛 · F1~F5）--
A=1 B=0 D=1 E=1 E2=1 F=1 traps=1
bats: 1025 ok / 0 not-ok / count=1025
-- T-FIX-04（check-gate-sync 缺对不得报全绿 · F6/F7 · 夹具经 TD-065 修复）--
   （诊断）verify hides: flow-kit-bundle/skills/flow-evolve/SKILL.md
real=21 full_fixture=0 missing_pair=1
-- T-FIX-05（Makefile NFR 判据去重 · F8）--
wrapper_recipe_lines=13 internals_recipe_lines=79
bats: 1025 ok / 0 not-ok / count=1025
```

**D-8-4 阶段门沙箱六态（stdout 摘要 · 全文 `/tmp/fk-reproduce-5-r5/phase-gate.txt`）**

```text
── 对照 0：门禁外直连 git …（证明仓库本身可提交，拦截不是命令形态问题）
  ✅ 门禁外直连 commit 成功（HEAD 前进）（yes）
── 状态 A：gate_config["5-test"]=both 且无 .done
  ✅ 门禁 rc（拒绝）（2）· ✅ 报文含「⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。」
  ✅ HEAD 未变（0b62276435d0ba0fe4af8a553e22d5b906b3d963）
── 状态 B：合格 .done（6 键 KVP · 阶段 5 健康态）⇒ 同一命令应放行
  ✅ 门禁 rc（放行）（0）· ✅ 放行后真 commit 生效（HEAD 前进）（yes）
── 状态 B2：.done 记 pass 而审查档记 fail ⇒ 期望 rc=2
  ✅ 口径不一致（标记记 pass / 审查档记 fail）被拒（2）· ✅ 报文含「禁止 git commit。」
── 状态 B3：.done 被 touch 成 0 字节 ⇒ 期望 rc=2
  ✅ 空标记（touch 0 字节）被拒（2）· ✅ 报文含「禁止 git commit。」
── 状态 B4：.done 缺 L3_verdict 键（5 行 < MIN_MEANINGFUL_LINES=6）⇒ 期望 rc=2
  ✅ 残缺标记（删 L3_verdict 键 · 5 行 < 6 行下限）被拒（2）
── 状态 C：沙箱无 .flow-active（门不适用 ⇒ fail-open 对照）
  ✅ 门禁 rc（不适用）（0）
✅ 阶段门复现：健康层全绿 —— A 拒绝且 HEAD 不变 · B 放行且 commit 真的生效 · B2/B3/B4 无效标记一律拒绝（存在 ≠ 有效 · ADR-029）· C 门不适用放行；判别子：门禁外直连 commit 可用 ⇒ 拦截确由门禁判定产生。
ℹ️ 历史对照（TD-059 缺口实证）：修复前 B2（口径相悖）/ B3（空标记）/ B4（缺键）均是「存在即放行」的 rc=0；现收敛为 rc=2。
```

> **读法**：本小节 = **第 7 次执行（fix 循环后 · 判据面 17 条）** 的整轮回执摘要，完整原文见 `PHASE5-RECEIPTS.md` **§O**（§O-1 判据 · §O-2 门禁 · §O-3 三条新判据 stdout · §O-4 六态全文）。与 D-7 的差异 = 判据面 14 → 17（新增 `T-FIX-03`/`T-FIX-04`/`T-FIX-05`）+ bats 1012 → **1025** + 三件 fix 提交（`6e39cfb` / `521b21c` / `6e94d60`）落地后重跑。

### D-11 第 10 次执行（REPRO9 · `T-FIX-12` NFR 批量化后重验 · 判据面 24 条 · 中间态）

**执行**：`bash .specs/health-fix-2026-09b/reproduce-5-test.sh`（起始 `2026-09-25T20:37` 本机时区；日志 `/tmp/p6c/repro9.out`；逐条输出 `/tmp/fk-reproduce-5-r9/`；HEAD `280ffdc`）—— 脚本 rc=0，汇总行 `✅ 复算全绿（判据 + 权威回执）`。

**D-11-1 判据面（24/24 ✅ rc=0）**：T05 12 · T06 22 · T11 7 · T13 34 · T17 74 · T19 36 · T20 3 · T22 20 · T24 18 · T26 30 · T27 19 · T29 15 · `T-FIX-01` 36 · `T-FIX-02` 42 · `T-FIX-03` 78 · `T-FIX-04` 44 · `T-FIX-05` 26 · `T-FIX-06` 41 · `T-FIX-07` 87 · `T-FIX-08` 56 · `T-FIX-09` 58 · `T-FIX-10` 72 · `T-FIX-11` 58 · `T-FIX-12` 70（新增 `T-FIX-12` = NFR 预算回归修复）。

**D-11-2 门禁面（7/7 ✅ rc=0）**：`npx bats --count test/` = **1061** · `npx bats test/` = ok=**1061** / not-ok=0 · `make check` = **21 条 ✅ / 0 条 ❌** · `make check-path-privacy` = 候选 **1601** / 实际扫描 **1595** / 命中合计 0 / 清单外命中 0 · **NFR = 3.813 / 3.656 / 3.730 / 3.752 / 3.630 s（max 3.813 · 均值 3.716 = 预算 74.3%；`loadavg` 8.72 9.30 9.36）** · `package-flow-kit.sh --validate` = 漏配 0 / 源缺失 0 · 阶段门沙箱六态 ✅（A 拒绝且 HEAD 不变 · B 放行且 commit 真生效 · B2/B3/B4 一律 rc=2 · C 门不适用放行）。

**D-11-3 处置与性质**：本轮把 `TD-077`（判据运输面：复算脚本 NFR 段曾硬编码 `rc=0`）从「假绿」拉回真断言后首次实跑 ⇒ NFR 由第 9 次的 **221.6%** 落到 **74.3%**；该次全绿后用户就 `R4-M1` 裁决「本 change 内修」⇒ 追加 `T-FIX-13`（改 `pre-push.sh` / `pre-commit.sh` 两个生产件）⇒ 其证据面对当前 HEAD **不再权威**，仅作**中间态留档**（完整回执 `PHASE5-RECEIPTS.md` **§S**）。

---

### D-12 第 11 次执行（REPRO10 · `T-FIX-13` 收口后重验 · 判据面 25 条）= **当前权威判定面**

**执行**：`FK_REPRO_LOG_DIR=/tmp/fk-reproduce-5-r10 bash .specs/health-fix-2026-09b/reproduce-5-test.sh`（起始 `2026-09-27T19:20:28+08:00`，历时 ≈1 h 43 min；日志 `/tmp/p6d/repro10.out`，mtime `21:03:38`；HEAD `551e84615bb74e21b2b49ab6d4f6f4294d753862`）—— 脚本 rc=0，汇总行 `✅ 复算全绿（判据 + 权威回执）`。

**D-12-1 判据面（25/25 ✅ rc=0）**：D-11-1 的 24 条 + **`T-FIX-13` 53 行**（三态反向控制：状态② 检查器在 + 清单缺 ⇒ 具名 fail-closed（pre-push `rc=2` 独立致命路径 / pre-commit `rc=1`）、状态① 检查器缺失 ⇒ `rc=0` + 旧措辞逐字保留、状态③ 两者皆在 ⇒ 干净 `rc=0` / 真泄漏 `rc≠0` 且归因「含路径隐私泄漏」）。逐条原文 `/tmp/fk-reproduce-5-r10/out_<ID>.txt`。

**D-12-2 门禁面（7/7 ✅ rc=0）**：`npx bats --count test/` = **1064** · `npx bats test/` = ok=**1064** / not-ok=**0**（基线 1064 = 1061 + `T-FIX-13` 3 例）· `make check` = **21 条 ✅ / 0 条 ❌** · `make check-path-privacy` = 候选 **1602** / 实际扫描 **1596** / 命中合计 0 / 清单外命中 0 · **NFR = 3.489 / 3.666 / 3.660 / 3.613 / 3.615 s（max 3.666 · 均值 3.609 = 预算 72.2%；`nproc=32` · `loadavg` 6.73 7.38 7.86）** · `package-flow-kit.sh --validate` = 漏配 0 / 源缺失 0 · 阶段门沙箱六态 ✅。

**D-12-3 本轮判据面缺陷与处置（`TD-081`）**：`T-FIX-13` 初版 `<verify>` 的夹具只把 `check-path-privacy.sh` 拷进沙箱 `reference/`，**从未创建 `path-privacy-allowlist.txt`** ⇒ 标注为「两者皆在」的 L4/L5 实际运行在**缺陷态**，与 L2d（缺陷态报文**不得**含「含路径隐私泄漏」）对同一输入构成**互斥断言** ⇒ **任何正确修复都无法同时满足**。执行者 `3add4b81` 在判据校验阶段即停下原样上报（`fix_rounds=0`、未触碰任何 `write_files`、未提交），主 agent 独立复核结论一致 ⇒ 就地在 L3 之后新增 **L3d**（显式把夹具切到「两者皆在」态 + 就位断言）与 **L4c**（两者皆在 + 真泄漏 ⇒ pre-commit 必须 `rc≠0`），L2/L3/L6 断言**一字未改**（不放宽）；修订后先红预跑 = rc=1、红腿恰好 6 条（L2a/b/c/e/f/g），修复后 rc=0。登记 `TD-081`（同族 `TD-073`/`TD-065`/`TD-072`）。

**D-12-4 判定**：**阶段 5 ✅ 通过**（判据 25/25 + 门禁 7/7；NFR 72.2% ≤ 100%）⇒ 据此过 4→5 门。完整回执 `PHASE5-RECEIPTS.md` **§T**。
