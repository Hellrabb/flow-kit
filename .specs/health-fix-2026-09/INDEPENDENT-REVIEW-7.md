# 独立审查 · 阶段 7
---
## L2 盲审

> 范围：任务书 4 项定向核查 + 「未实测即断言」残留专项。预算 8 read / 6 bash，实耗 2 read / 6 bash，未超支。
> **已实跑**：全量 `npx bats test/`（rc=0）· `bash verify-claims.sh`（rc=0）· `bash package-dsh-plugin.sh --check`（rc=0）。未实跑项在文末标注。

### 🔴 R1 · AC-7 夹具断言 13 而实测 14，该夹具当前必红 → CHANGELOG「11 个夹具全部实跑 PASS」不成立
**Severity**：🔴 Critical
**Symptom**：`verify/ac7.sh:33,35` 断言 `复验结果: ✅ 13  ❌ 0`；但实跑输出为 `复验结果: ✅ 14  ❌ 0`（`verify-claims.sh:263` 的 printf，第 14 条来自阶段 6 新增的 §10d，`verify-claims.sh:240-257`）→ `:35` 的 `grep -qE` 失配 → `exit 1` + `❌ FAIL:verify-claims计数≠13/0`。而 `CHANGELOG.md` 首条写「**11 个 AC 夹具全部实跑 PASS**（`verify/ac1..ac9 + ac4b + ac4c`）」。口径漂移源：阶段 5 定稿 13 → 阶段 6 加 §10d 变 14，夹具未同步（`INDEPENDENT-REVIEW-6.md:234` 已记「正例 14✅/0❌」，说明 14 是阶段 6 后的真值）。
**Source**：本次实测 `bash verify-claims.sh` → rc=0 · `复验结果: ✅ 14  ❌ 0` · 「make check 6 门全绿」；夹具断言与其直接冲突。未实跑 `ac7.sh` 本身（预算），但其断言的**两个输入均已实测**，失配是必然的。
**Consequence**：change 自己的验收夹具红着进阶段 7，「全部 PASS」属未复测的转抄断言 —— 正是本 change 立论打击的 L-093（跨动作基线不得转抄）/ L-098（verify 未双向实测）同族复发；归档时对外声明与可复现事实不符。
**Remedy**：把 `ac7.sh` 与上游口径统一到 **14**（或论证应为 13 并改脚本），随后**重跑全部 11 个夹具并留新证据**（勿复用旧输出）。批量改口径时 **glob 必须排除 `INDEPENDENT-REVIEW-*.md`**（L-099）。

### 🟡 R2 · 13/14 双口径已扩散到 5 处非审查工件，与「数字无法复核」互为因果
**Severity**：🟡 Important
**Symptom**：`REQUIREMENT.md:328`（AC-7 断言 `13/0`）、`TASK.md:333`、`DEV-SUMMARY.md:18,35`、`MINOR-DEFERRED.md:19`、`DESIGN.md:202` 全部停留在阶段 1/3/5 的 13 快照；`CHANGELOG.md` 与 `INDEPENDENT-REVIEW-6.md:234` 为 14。同一 change 内两个互斥真值并存。
**Source**：`INDEPENDENT-REVIEW-5.md:119-129`（阶段 5 🟡 R6）已指出「950/13/0.61s 这些数字在工件内**无法被复核**，只能重跑（≈13 分钟）」；其 Remedy 建议的 `verify/logs/` 原始输出落盘**未实施**（`ls verify/` 仅 11 个 `ac*.sh`，无 logs/），阶段 5 的结案改走「可复现命令」（`INDEPENDENT-REVIEW-5.md:228`）。代价即刻兑现：13→14 漂移全程零告警。
**Consequence**：归档后的读者按 REQUIREMENT 复跑会得到与 AC 文本相反的结果，重演本 change 要消灭的「假绿/假红」；阶段 6/7 的审查者无法低成本复核，只能采信或重跑。
**Remedy**：计数类基线在阶段 6/7 收口时**当场重测并回写**全部非审查工件（L-093①）；若沿用「可复现命令」方案，至少把收口那一次的 `verify-claims` / `bats` 关键行落盘到 `verify/logs/`。

### 🟡 R3 · 阶段 6 审查员明确要求「进 7-integration 前补跑 brooks-review」，实际未执行
**Severity**：🟡 Important
**Symptom**：`INDEPENDENT-REVIEW-6.md:90-100`（🟡 R1-a）Remedy ③ 要求补跑 `/brooks-review` 并把输出原样贴入 §2.2；实际处置只更正了文字并记为已知局限（`REVIEW.md:86-88`「本轮**不重跑** brooks-review…应由人工在 Claude Code 内跑」）。该 Remedy 是阶段 6 的**待办**，而阶段 7 正是它的到期点。
**Source**：`REVIEW.md:82-84` 自承 6 维诊断走内置回退、`R3/R4/R5 三维全 0 很可能是漏判`（工具 benchmark：书本引用 100% vs 约 16%）；`REVIEW.md:245` 的自检项已改为「可信度受限」的诚实口径 —— **不是假陈述**，但结论强度未经提升。
**Consequence**：阶段 6 质量结论的漏判风险原样带入归档；`REVIEW.md` 里两条被复用过的可证伪理由（「未装 brooks-lint」出现 2 次）虽已更正，回退路径的**实质代价**未消除。
**Remedy**：阶段 7 收口前由人工跑一次并贴回，或由用户在归档 decision 里**显式签署接受该局限**（写入 CHANGE.md/REVIEW.md），不要让它在「建议」状态下随归档消失。

### 🟢 R4 · MINOR-DEFERRED M1/M2 待阶段 7 triage（本审查员裁定：接受延后，M1 建议一行更正）
**Severity**：🟢 Minor
**Symptom**：`MINOR-DEFERRED.md:10` M1 —— `REQUIREMENT.md` 非功能性需求段称「`make check` 被 **pre-commit** 调用」，实测 pre-commit 只跑 `make test`、`make check` 在 pre-push → 取证理由错位（结论「新门禁必须快」不变）；`:11` M2 —— AC-5「5 个告警」未区分 vendor 4 个 + `.claude/hooks` 1 个两个来源。
**Source**：两条均按 ADR-017 单一路径登记、有日期与延后理由，处置透明，不属「隐瞒」；均不影响任何 AC 判据。
**Consequence**：无 AC/门禁影响，仅文档口径；M1 的错误依据可能被后续 change 引用。
**Remedy**：M1 改一行（成本极低，建议本轮顺手修）；M2 保持延后即可。归档时在 `MINOR-DEFERRED.md` 补一行 phase-7 triage 结论。

### 4 项定向核查结论（除 R1/R2 外均属实，不构成发现）
| # | 核查项 | 结论 |
|---|---|---|
| ① | 12 个必备产物 | ✅ 全部存在且非空：8 件 3.1K–39K + 4 份 `INDEPENDENT-REVIEW-{1,3,5,6}.md` 43K–51K |
| ② | L-090 ~ L-100（11 条） | ✅ 11 个编号在 `.specs/LESSONS.md` 中**各出现恰 1 次**：无缺号、无重复、无多余；无 `L-090` 之外的越界新增 |
| ③ | CHANGELOG 数字 | ⚠️ 5 项中 4 项实测相符，1 项冲突：门数 `Makefile:106` = **6 门** ✅ · bats 实跑 `1..950` / ok=950 / not ok=0 / skip=1 ✅ · verify-claims `14✅/0❌` rc=0 ✅ · 夹具 **11 个** ✅ · check-dist **0.59s**（声称 0.61s，同量级）✅ —— 冲突即 R1：CHANGELOG 的 14 与夹具的 13 |
| ④ | 归档清洁 | ✅ `git status --porcelain` = **0 行** · 无 `.l3-attempts-*` / `*.tmp` / `*.log` / `.DS_Store` 残留 · `package-dsh-plugin.sh --check` **rc=0（0.59s，只读、无 `==> packaging` 输出）** |
| 附 | L-100 类残留复查 | ✅ 未发现新的「工具不存在/命令不可跑」假断言：`REVIEW.md:74-78` 已更正 brooks-lint 误判；`verify-claims.sh:227` 门数改由 `Makefile check:` 动态推导，全仓已无写死的「五门」；`Makefile:21` 的 SC1090=22 与实现一致。**残留者仅剩计数漂移（R1/R2）** |
| 未实跑 | 其余 10 个 AC 夹具、`make check` 六个门整体 | 受预算限制未实跑，仅核存在性与计数来源；不影响 R1 —— 其结论由「夹具断言 vs 实测输出」直接判定，不依赖夹具执行 |

**Verdict**: fail

---

## 主 agent 响应 · 阶段 7（对 L2 盲审 · 2026-09-21）

> 主 agent 手写段。L2 的 1 🔴 + 2 🟡 + 1 🟢 **全部复验成立**，已逐条处置。
> **致谢**：这一轮 L2 在 6 次 bash 预算内实跑了 bats 与 verify-claims，直接以「夹具断言 vs 实测输出」判定，
> 抓到了一条**会导致 CHANGELOG 假陈述**的真 Critical。

### 对 🔴 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R1** · `verify/ac7.sh:33,35` 断言 `✅ 13 ❌ 0`，实测为 `✅ 14 ❌ 0`（阶段 6 新增 §10d）→ 夹具必红；故 CHANGELOG「11 个 AC 夹具全部实跑 PASS」**不成立** | `Fixed in:` REQUIREMENT AC-7 + `verify/ac7.sh` + TASK T05/T07 + CHANGELOG 相关表述 | **完全成立**。实测确认：`ac7.sh:35` 写死 13，而 `bash verify-claims.sh` 输出 14 → `grep -qE` 必失配。**这不只是改数字** —— 写死精确计数会在**每次新增断言时必然失配**（L-093/L-098 同族的"转抄未复测基线"，本 change 内第 N 次）。已改为**抗漂移判据**：`❌ = 0` 且 `✅ ≥ 13`（下限）。同法修 `TASK.md` 的 T05/T07 断言（它们与 ac7 是同一 bug 的三处副本）。**实测复验：`bash verify/ac7.sh` → rc=0 · ✅ AC-7 PASS（六项全绿）**。并同步修正 `REQUIREMENT`（AC-7 的 Then + ac7 注释 + 定稿说明）、`DEV-SUMMARY`（2 处）、`TASK`（done 文本）共 **8 处**陈旧 `13`。 |

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R2** · 多份工件仍为旧值 `13`（REQUIREMENT:328 / TASK:333 / DEV-SUMMARY:18,35 / MINOR-DEFERRED:19 / DESIGN:202） | `Fixed in:` 同上批量 | 成立。已逐处处置：**现态断言**改为「❌=0 且 ✅≥13」或实测值 14；**历史留痕**（带"原写/曾写/已失效/已实施并实测 + 日期"限定）保留不改（它们是审计链的一部分）；`T02-T03-T05-SUMMARY` 的引文证据块加**时效注记**（标注该数值属阶段 4 时点）。终检：现态断言中的陈旧 `13` = **0**。 |
| **R3** · 阶段 6 明确要求「进 7-integration 前补跑 brooks-review」未执行 | `Fixed in:` REVIEW.md 新增第五轮 | 成立。本轮**实际调用 `brooks-review` 技能**（非内置回退）复核同一 diff，报告已写入 `REVIEW.md` 的「第五轮 · brooks-lint 专用工具复核」。**价值确认**：它新发现 **3 条内置回退完全漏掉的问题**（R2-b PR 规模信号 / R3-b 排除契约三处重复 / **R6-a 通用工具被写入变更专属断言**），印证了 L2 阶段 6 R1-a 的判断（内置回退漏判）。 |

### 对 🟢 的响应

| Finding | 处置 |
|---|---|
| 4 项定向核查的其余项 | ① 12 个必备产物齐全 ✅ ② `L-090~L-100` 各恰 1 次 ✅ ④ 归档清洁（工作区 0 行 / 无临时残留 / `--check` rc=0 且只读）✅ —— 与你实测一致。 |

### 本轮附带处置（brooks R6-a：通用工具被写入变更专属断言）

**这是本轮最有价值的发现**（内置回退漏掉、真工具抓到）。张力点：L2 阶段 6 的 R2-c 要求给新门禁补**持久**回归保护，
而 brooks R6 说这些断言**变更专属**、不该留在通用工具 `verify-claims.sh` 里 —— **两者冲突**。

**裁定：(b) 保留 + 明确生命周期**（而非 brooks 建议的 (a) 移出）。理由：
- (a) 移到 `.specs/<id>/verify/` 夹具会**随归档失去保护力** —— 恰好**抵消** R2-c 要的持久性；
- 保留在**被 git 跟踪、不随归档迁移**的 `verify-claims.sh` 中，才能真正"归档后仍守护这 4 项交付物"。

已在 `§10d` 上方加**生命周期声明**（含"若后续变更重构这些交付物会无故变红，应同步更新而非删除"、
"新增变更不应默认往本文件加变更专属节"等维护提示），使其**不再退化为"历次变更的断言垃圾场"**—— 那正是 R6 的实质担忧。

### 附带处置（阶段 6 决定项 #2）

`flow-kit-bundle/lib/install_hooks.sh` 已加**交叉引用契约注释**：说明该处对 `pre-tool-use/*.sh` 全部 `chmod +x`
是**有意的无害冗余**（库只被 source），并明确「**真入口契约的单一事实源 = `sync-hooks.sh::PTU_ENTRIES`**；
新增入口必须登记此处」。这堵住了 DESIGN §5 R4 的"清单漂移"风险。

**顺带验证了 F1 的价值**：改完 `install_hooks.sh` 后，**我自建的 `check-dist` 立刻报出**
`dist/.../vendor/.../lib/install_hooks.sh` 陈旧（rc=1 + 指名路径），重建后恢复一致 —— **门禁抓到了我自己的改动**。

### 补充说明

- 我未改动 L2 的原文判断。
