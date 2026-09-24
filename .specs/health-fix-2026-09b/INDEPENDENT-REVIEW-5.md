# 独立审查 · 阶段 5

## L2 盲审（第 1 轮）

> 独立性声明：本审查仅依据 `TEST.md`（主工件）与 `REQUIREMENT.md`/`TASK.md`/`DESIGN.md`（参考工件）及实跑命令复核。未引用任何主 agent 自评或外部结论。

### 实跑复核摘要（证据优先）

以下命令由本审查员在仓库根 `<repo>` 亲跑（`<repo>` = 本仓根目录，按 L-129 脱敏替代真实账号路径；本次由主 agent 就地替换，判定与四要素未改动）：

| 命令 | 结果 |
|---|---|
| `npx bats --count test/` | **976** ✅ |
| `npx bats test/ --formatter tap` | rc=0 / ok=976 / not-ok=0 / skip=0 ✅ |
| `make check` | 全绿（含 9 道门禁）✅ |
| `make -n check` | 9 道门禁全部接线（`check-gate-sync`/`check-path-privacy`/`check-nfr-portability` 在 `check:` 依赖行）✅ |
| `make check-path-privacy`（健康态） | rc=0，清单外命中 0 条 ✅ |
| `make check-path-privacy`（注入 `<!-- probe: 合成探针行（账号名按 L-137 拼接构造：/home/ + zz-path-probe + /） -->` 到 `.specs/CONTEXT.md`） | rc=1，报文 `.specs/CONTEXT.md:716: <!-- probe: 合成探针行（账号名按 L-137 拼接构造：/home/ + zz-path-probe + /） -->` ✅ 双态 |
| T13 `<verify>` 原样抽取实跑 | rc=0，授权面外命中=0 ✅ |
| T29 活性探针 `FLOW_KIT_CHANGE_BASE=HEAD` | rc=1 + `🔴 AC-8 时点变更集为空` ✅ 非恒绿 |
| `bash package-flow-kit.sh --validate` | 期望 311 / 实际 317 / 漏配 ERROR=0 / 源缺失 0 / rc=0 ✅ |
| `grep -rnE '\$\([[:space:]]*eval[[:space:]]' --include='*.sh' .`（排除 .git/node_modules/dist） | **0 命中** ✅ AC-1 |
| dist/dsh-flow-kit-0.2.0.tgz `chisel`/`eval-echo` | chisel=0 / eval-echo=0 ✅ AC-5 |
| `grep -rn chisel test/ flow-kit-bundle/test/` | 0 命中 ✅ AC-5 |
| `grep -rln 'path-privacy' test/` / `nfr-portability` / `runtime-edit-guard` | 均 rc=1（0 命中）✅ TD-053 声明属实 |

---

### 🟢 R1 · AC 覆盖：8/8 AC 均有机器可验证据

**Severity**：🟢 Minor（达标，无缺陷需修；本条为达标确认）

**Symptom**：`TEST.md:29-38` §1.1 测试矩阵列出 AC-1..AC-8 各一条主证据 + 结果。实跑复核：AC-1（eval-echo=0）、AC-3（T19 四形态端到端）、AC-5（dist chisel=0）、AC-6（探针注入 rc=1 指名 file:line）、AC-8（bats 976/0/0 + T29 活性探针 rc=1）均与报告一致。每条 AC 有双态证据（健康⇒绿 / 注入缺陷⇒红），非"跑一次看绿"。

**Source**：固化指令 L118-126「AC 覆盖：测试矩阵是否覆盖所有 AC（每条 AC ≥ 1 条测试用例对应）」「覆盖率达标：功能轮是否 100% AC 覆盖」。

**Consequence**：无（达标）。

**Remedy**：无（达标确认）。

---

### 🟢 R2 · 5 轮金字塔：逐轮填写且跳过有理由

**Severity**：🟢 Minor（达标，无缺陷需修）

**Symptom**：`TEST.md:13-19` §0 金字塔声明：第 1 轮功能✅全跑、第 2 轮性能⚠️部分（NFR 三条预算全跑）、第 3 轮安全⚠️部分（依赖面/秘钥/SAST/OWASP）、第 4 轮兼容✅（静态面全）、第 5 轮可观测⚠️部分（日志面全）。每条 ⚠️/❌ 均给出裁剪理由（无前端/无服务端/无容器镜像/无长驻进程）。`TEST.md:21` 显式声明"无声明跳过"。

**Source**：固化指令 L122「5 轮金字塔：功能/性能/安全/兼容/可观测是否逐轮填写（跳过的有理由）」。

**Consequence**：无（达标）。

**Remedy**：无。

---

### 🟢 R3 · UAT 可执行：四条端到端实跑

**Severity**：🟢 Minor（达标）

**Symptom**：`TEST.md:44-49` §1.2 四条 UAT：① 隔离 bare remote pre-push 拦截（T19）、② pre-commit 两态探针 rc=1 指名、③ DSH 装载面阶段门真实拦截（阶段 5 提交被 `gate-checks-review.sh` 拒绝——活证据）、④ 安装器覆盖 `--validate` rc=0。四条均为脚本可执行路径，非手工步骤描述。实测 UAT #4 复跑 rc=0。

**Source**：固化指令 L124「UAT 可执行：Given/When/Then 是否可脚本化」。

**Consequence**：无（达标）。

**Remedy**：无。

---

### 🟢 R4 · 回归安全：bats 976/0/0 不退化

**Severity**：🟢 Minor（达标）

**Symptom**：`TEST.md:38` AC-8 引用 T29 判据 rc=0，bats 976 ok / 0 not ok / 0 skip。实跑复核：`npx bats test/` rc=0、ok=976、not-ok=0、skip=0。三道副本一致性门禁（`check-test-sync`/`check-hooks-sync`/`check-dist`）均在 `make check` 中通过。

**Source**：固化指令 L125「回归安全：全量 bats 是否不退化」。

**Consequence**：无（达标）。

**Remedy**：无。

---

### 🟢 R5 · 修代码优先：主 agent 对🟡/🔴发现给出分类标记

**Severity**：🟢 Minor（达标）

**Symptom**：`TEST.md:285-290` §阶段 5 发现与处置 4 条：#1 🟡 TD-053 `Tech-debt:`（含理由：test/ 属源面入分发件会迫重建 dist，违反 T24 次序硬约束）；#2 🟡 `Fixed in: .specs/health-fix-2026-09b/TASK.md`（T13 判据按逐条精确字面豁免 + L-147/TD-052 登记）；#3 ℹ️ 工具缺失明示+量化替代；#4 ℹ️ TD-033/TD-050 `Not-applicable`（范围外已登记）。每条🟡/🔴发现均有 `Fixed in:`/`Tech-debt:`/`Not-applicable:` 分类标记。

**Source**：固化指令 L126「修代码优先：主 agent 响应段是否对每条 🔴/🟡 发现输出了分类标记」。

**Consequence**：无（达标）。

**Remedy**：无。

---

### 🟢 R6 · 性能预算达标：check-path-privacy ≤5s

**Severity**：🟢 Minor（达标）

**Symptom**：`TEST.md:109` 实测 3 次均值 2.841s（预算 5s 的 57%），最差单次 2.868s 留 43% 余量。`check-gate-sync` 0.05s，`check-nfr-portability` 0.172s。`TEST.md:128` 声明无退步。

**Source**：`REQUIREMENT.md` 非功能性需求「`make check-path-privacy` ≤ 5 秒，验证手段 = `time` 实测并记入 TEST.md，超阈值即未满足」。

**Consequence**：无（达标）。

**Remedy**：无。

---

### 🟢 R7 · 测试质量自检 6 维：命中 1 条 TD-033（不阻塞）

**Severity**：🟢 Minor（已按规则记技术债）

**Symptom**：`TEST.md:76-85` §1.5 测试质量自检 6 维：T4 Mock Abuse 命中 1（`test/test_gate_config_presets.bats:27-28` 自陈 `Simulates the resolve_gate_config() logic`、硬编码 `"independent"` ⇒ TD-033 既有登记，本 change 未纳入范围）。其余 5 维无命中。命中数=1 < 3 ⇒ 按规则只记技术债不阻塞 release。`TEST.md:90` 声明 AC-4 证据链已避开该不可信面。

**Source**：固化指令 L126 修代码优先协议 + 测试质量自检规则「命中 ≥1 记技术债；≥3 本次 release 前必修」。

**Consequence**：无（TD-033 不阻塞，且证据链已回避）。

**Remedy**：无。

---

### 🟡 R8 · L-031 跨文件一致性：TD-048 范围扩张未回写 write_files 边界归属表

**Severity**：🟡 Important（文档一致性缺陷，非功能阻断）

**Symptom**：`git diff 534e3e8..HEAD -- '*.sh'` 实测 `package-flow-kit.sh`（+4 行）与 `flow-kit-bundle/lib/validate_staging.sh`（+1/−1）被修改。但：
- `DESIGN.md` §0.5.1（`DESIGN.md:19-67`）触碰模块清单**未列**这两个文件；
- `TASK.md:389` T10 `<read_files>` 仍将 `package-flow-kit.sh` 声明为「**不在触碰清单，不得修改**」；
- `TASK.md:1363` 自检第 3 项仍写「`package-flow-kit.sh` —— 不在任何 write_files ✅」；
- `TASK.md:1310-1331` write_files 边界归属表**无**这两行的归属条目。

TD-048 授权仅在 `TASK.md:464`（T11 done）与 `MINOR-DEFERRED.md:349,597` 以散文记载「用户裁决授权范围扩张」。`TEST.md:253` 提及 TD-048 但仅关联 `test_archive_commit_gate.bats`，未提及实际改了 `package-flow-kit.sh:134-136` 与 `validate_staging.sh:54`。

**Source**：固化指令 L68-82 L-031 闭合「对比 git diff 实际改的文件，标记 DESIGN 列出且已改/漏列但已改(OK)/列出但未改/漏列且未改(🔴)」。此处为第 2 类（DESIGN 漏列但已改 OK）但文档一致性未闭合：边界归属表未补条目、自检结论与实际 diff 矛盾。

**Consequence**：L-031 第 2 类本身不阻断（变更有授权），但自检表写「✅ 不在任何 write_files」与实测 diff 矛盾 ⇒ 后续审查者据自检表判定会误认为越界写入，或据 diff 判定会误认为未授权改动。审计链断裂。

**Remedy**：在 `TASK.md` write_files 边界归属表的「显式例外」段补两行：
`| package-flow-kit.sh | TD-048 用户裁决「授权在本 change 内修」· T11 修复轮 2 补 pre-push stanza（:134-136） |`
`| flow-kit-bundle/lib/validate_staging.sh | TD-048 同源 · T11 修复轮 2 Part C 补 pre-push 模式（:54） |`
并订正 `TASK.md:1363` 自检第 3 项与 `TASK.md:389` read_files 声明以反映 TD-048 落地后的实际写面。

---

### 🟡 R9 · TD-053 新门禁无常设 bats 回归：判定力仅由 change 期判据承载

**Severity**：🟡 Important（回归保护缺口）

**Symptom**：`TEST.md:89,275,287` 声明 `grep -rln 'path-privacy' test/` = 0、`nfr-portability` = 0、`runtime-edit-guard` = 0。实跑复核确认三者在 `test/` 树均 0 命中。主 agent 处置为 `Tech-debt: TD-053`，理由：`test/**` 属源面且整棵入分发件，新增用例会迫重建 dist/tarball 并令 AC-8 已落档 976 基线失效。

**Source**：固化指令 L125 回归安全 + L-031 跨阶段必查项。新门禁 `check-path-privacy.sh`（392 行）、`check-nfr-portability`（Makefile 内联 recipe）、`runtime-edit-guard.sh`（AC-1 守卫）是本 change 的核心产出，其判定力目前**仅由 19 条 change 期判据承载**，归档后无常设回归网。两道新门禁已接线进 `make check`（"坏成红"会暴露），但 `runtime-edit-guard.sh` 的哨兵判定力无常设验证。

**Consequence**：归档后若有人误改 `check-path-privacy.sh` 的排除逻辑或 `runtime-edit-guard.sh` 的参数展开，`make check` 的"接线"只保证脚本被**调用**，不保证其**判定逻辑**正确（脚本内部逻辑退化不会被 bats 捕获）。缓解事实：T21/T22/T23/T25/T26 判据已用双态注入验证过判定力且可复算。

**Remedy**：本 change 内不就地补（理由合理：重建 dist 的次序约束）。建议在**下一个 change** 或 phase 7-integration 时：① 为 `check-path-privacy.sh` 增加一条 bats（注入探针断言 rc=1 + 健康态 rc=0），② 为 `runtime-edit-guard.sh` 增加哨兵断言 bats。登记 TD-053 已做，但需确保 phase 7 triage 时不被遗忘。

---

### 🟡 R10 · TEST.md §1.1 AC-4 证据链采信口径与 REQUIREMENT 不完全对齐

**Severity**：🟡 Important（证据强度风险）

**Symptom**：`TEST.md:34` AC-4 主证据写"`make check-gate-sync` rc=0（3/14 对一致 / 17 预设）"。`REQUIREMENT.md` AC-4 要求"门禁看见内容漂移"，验证方式为"3/14 对仅差 front-matter，比内容非比行数，覆盖度校验对 3/14，漂移 rc≠0 指名 file:line"。实跑 `make check-gate-sync` 输出"覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）"。TEST.md 报告了 3/14 但**未提及**"漂移 rc≠0 指名 file:line"这一关键判据的实测结果——即 AC-4 的 Then 分支（漂移被检出时 rc≠0）未在 §1.1 给出独立的双态证据。

**Source**：`REQUIREMENT.md` AC-4「门禁看见内容漂移」+ 固化指令 L121「AC 覆盖：每条 AC ≥ 1 条测试用例对应」。AC-4 的 Then 含两个分支：① 一致⇒rc=0（已证）、② 漂移⇒rc≠0指名（§1.1 未给独立证据）。

**Consequence**：AC-4 的"漂移检出"分支只在 `test_check_gate_sync.bats`（5 用例）与 T13/T15 判据中隐性覆盖，§1.1 矩阵未单独给出"注入漂移⇒rc≠0"的证据行。判定力仍在（T13 判据实测 rc=0 + T15 断言收紧），但证据矩阵的可追溯性不完整。

**Remedy**：在 `TEST.md:34` AC-4 行补一句双态证据："T13/T15 判据注入内容漂移 ⇒ rc≠0 指名 file:line（双态）"，或交叉引用 §1.4 边界 #6（非 git 仓库 fail-closed）作为错误路径佐证。

---

### 🟢 R11 · L-031 跨文件锚点扫描：无第 4 类漏改

**Severity**：🟢 Minor（达标确认）

**Symptom**：L-031 锚点扫描：
- `check-path-privacy`：命中 `pre-commit.sh:5,32,33`、`pre-push.sh:9,48,49`、`check-path-privacy.sh:3,48,124,369` —— 均已改且在 DESIGN §0.5.1 + write_files 表内 ✅
- `check-gate-sync`：命中 `check-gate-sync.sh:3,29`、`pipeline-gates.md:4`（只读引用，D2 排除）—— 已改且在 DESIGN ✅
- `check-nfr-portability`：0 命中 `flow-kit-bundle/`（设计为 Makefile 内联 recipe，不落 .sh，避免自命中——DESIGN §1 D8 + T28 action 确认）✅
- `Makefile:106` `check:` 依赖行含全部 9 道门禁 ✅

无"DESIGN 漏列且未改（🔴 漏改）"的第 4 类。唯一文档不一致见 R8（TD-048 范围扩张未回写表，属第 2 类 OK 但文档未闭合）。

**Source**：固化指令 L68-82 L-031 闭合协议。

**Consequence**：无（L-031 无第 4 类漏改）。

**Remedy**：无（R8 另行处置文档不一致）。

---

### 🟢 R12 · 测试矩阵计数可复算

**Severity**：🟢 Minor（达标确认）

**Symptom**：`TEST.md:57` §1.3 关键路径专项用例数：`test_archive_commit_gate.bats` 27、`test_gate_config_presets.bats` 34、`test_install_coverage.bats` 17、`test_lessons_cleanup.bats` 16、`test_check_gate_sync.bats` 5、`test_combined_metric.bats` 2。实跑 `grep -c '@test'` 复核：27/34/17/16/5/2 全部一致。`TEST.md:249` 声明未新增 bats 文件，8 处修改 +16/+22/+7/+14/+5/+6/+1/+13 —— 与 `git diff --numstat` 吻合。

**Source**：固化指令 L123 覆盖率达标。

**Consequence**：无（达标）。

**Remedy**：无。

---

## 总评

| 维度 | 判定 |
|---|---|
| AC 覆盖（8/8） | ✅ 达标 |
| 5 轮金字塔 | ✅ 逐轮填写，跳过有理由 |
| 覆盖率（功能轮 100% AC） | ✅ 8/8 双态证据 |
| UAT 可脚本化 | ✅ 四条端到端 |
| 回归安全（bats 不退化） | ✅ 976/0/0 |
| 修代码优先（🟡/🔴 分类标记） | ✅ 每条有 Fixed in/Tech-debt/Not-applicable |
| L-031 跨文件一致性 | ✅ 无第 4 类漏改（R8 文档不一致另记 🟡） |

**🟡 Important 发现 3 条**（R8 文档一致性 / R9 回归保护缺口 / R10 AC-4 证据链口径），均入 fix loop 但不阻塞 toll-gate。
**🔴 Critical 发现 0 条**。

**Verdict**: pass

---

## 主 agent 响应（阶段 5 · 第 1 轮 · 2026-09-24）

> 分类标记格式见 DESIGN §3.2；本节由主 agent 手写（**不转义、不落签名**，依据 `L2-blind-review.md:158-163` 的文件写入约束）。L2 原文四要素未作任何修改。

| # | 严重度 | 发现摘要 | 处置（分类标记） | 证据 |
|---|---|---|---|---|
| **R8** | 🟡 | TD-048 范围扩张改了 `package-flow-kit.sh` 与 `flow-kit-bundle/lib/validate_staging.sh`，但边界归属表/自检/`read_files` 声明未同步 ⇒ 审计链断裂 | **`Fixed in: .specs/health-fix-2026-09b/TASK.md`** | ① 「write_files 边界归属 → 显式例外」表新增两行（`package-flow-kit.sh`：TD-048 用户裁决 → T11 修复轮 2 补 Part C `pre-push` stanza `:134-136`；`flow-kit-bundle/lib/validate_staging.sh`：同源 → `:54` 补 `pre-push` 模式，+1/−1），并标注「L-031 第 2 类（DESIGN 漏列但已改，授权在先）」；② T10 `<read_files>` 旧文案「**不在触碰清单**，不得修改」已订正为「T10 自身不得修改 + 该文件在 T11 修复轮 2 依 TD-048 被写入」；③ Plan-Conflict Scan ② 的自检第 3 项同步订正并注明 R8 来源 |
| **R9** | 🟡 | `check-path-privacy.sh`(392L) / `check-nfr-portability` / `runtime-edit-guard.sh` 的判定力仅由 change 期判据承载，归档后无常设 bats 回归网 | **`Tech-debt: TD-053`**（🟡 · 计划：v2 或 phase 7 triage 后的首个 change） | 已登记 `.specs/CONTEXT.md` 的 TD-053 行（含 `grep -rl` 实测 0 命中、危害面「门禁失效而 `make check` 仍绿」、v2 修法两条 bats + 门禁自检档）；**不就地补测**的理由见 `TEST.md` §阶段 5 发现 #1（`test/**` 属源面 + `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/` 已 vendored 75 个 bats + 新增用例迫使重建 dist/tarball 并令 AC-8 已落档的 976 基线口径失效）。**针对 R9 的「phase 7 triage 不得遗忘」**：TD-053 同时落档于本 change 的 `TEST.md` §回归保护「已识别的回归保护缺口」与 §阶段 5 发现与处置 #1，共三处可见 |
| **R10** | 🟡 | `TEST.md` §1.1 的 AC-4 只给健康态（3/14 对一致 + rc=0），未给 REQUIREMENT AC-4 Then 第二分支（漂移 ⇒ rc≠0 且指名）的独立双态证据 | **`Fixed in: .specs/health-fix-2026-09b/TEST.md`** | AC-4 行已补齐逐行锚点：`test/test_check_gate_sync.bats:29-31`（健康态 `[ "$status" -eq 0 ]` + 无 gate-config 漂移报告）· `:36`（注入假预设 `fake-preset` ⇒ **报漂移并列出该名**）· `:43`（删除真预设 `design` ⇒ 报漂移）· `:49`（反向对照：注入无 `→` 英文注释 ⇒ **不误报**）；本次实跑 `npx bats test/test_check_gate_sync.bats` = TAP `1..5` / **ok 5 / not ok 0**，`make check-gate-sync` rc=0 |
| 🟢 R1–R7 / R11 / R12 | 🟢 | 9 条达标确认（无一入 fix loop） | **`Not-applicable`**（无行动项） | 其中 R7 的 T4 命中即 **TD-033**（既有登记、本 change 范围外），与 R9/TD-053 一并落档，不重复登记 |

**技术债占比（AC-4 防护 · `5-test.md:103`）**：3 条 🟡 中 1 条走 `Tech-debt:`（R9 / TD-053）= **33%**，低于 50% 阈值，无需追加说明段；另两条均已**实际改动工件**（R8 → `TASK.md` 三处；R10 → `TEST.md` §1.1），非纯文档敷衍。

**处置后门禁复核（响应写回后实测）**：`make check-path-privacy` rc=0（清单外命中 0）· `make lint` rc=0（shellcheck 0 error）· `npx bats test/test_check_gate_sync.bats` 5/5 ok。

**主 agent 判定**：接受 L2 全部 3 条 🟡 并逐条闭环；L2 的 🟢 结论与实跑证据一致（未发现需要反驳的误判）。

---

## 主 agent 响应（阶段 5 · L3 第 2 轮 · 2026-09-24）

> 依据 `flow-kit-bundle/flow-kit/prompts/5-test.md:93-106` 的修代码优先协议：逐条给出 `Fixed in:` / `Tech-debt:` / `Not-applicable:`。
> L3 第 2 轮判定 = `pass`（`critical: []`）⇒ 4 major / 5 minor 按「可补强的 major」逐条闭环，不阻断本阶段；**技术债占比 = 2/9**（TD-056 · TD-057，另有既有条目 TD-053）< 50% 阈值。
> 处置后**工件已变更**（`TEST.md` 扩写）⇒ `L3_artifact_hash` 由 `490dc83826a6…` 变为新值，已按门禁机制重跑 L3 复审（本段之后追加第 3 轮 L3 段）。

### major 1 · 自报数字不可从工件内部复算 —— `Fixed in:` 两件新工件

- **`Fixed in: .specs/health-fix-2026-09b/reproduce-5-test.sh`**（新增·可执行；`bash -n` + `shellcheck` 双绿）：判据从 `TASK.md` **权威副本**用 awk **原样抽取**（`extract_verify()`，不做任何改写）后逐条实跑并记 rc；默认集 12 条（T05 T06 T11 T13 T17 T19 T20 T22 T24 T26 T27 T29）；模式 `--criteria-only` / `--gates-only` / `--only T19,T27`；门禁段 [A] bats（`--count` + TAP 双计数）· [B] `make check` · [C] `make check-path-privacy` 自证行 · [D] NFR 预算 ×5（附 `nproc`/`loadavg`）· [E] `package-flow-kit.sh --validate`；任一非 0 ⇒ `exit 1`。
- **`Fixed in: .specs/health-fix-2026-09b/PHASE5-RECEIPTS.md`**（新增）：嵌入本次实跑的**原始输出**（12 条判据 rc + stdout · 门禁六项回执 · 抽取命令 · 性能环境），使「976 ok / 0 not ok / 0 skip」「`make check` 全绿」等每条自报数字都可被外部重放核对。
- **UAT**：`TEST.md` §1.2 的四条序列在脚本内以同一抽取路径可单独重放（`--only T19`），原始输出同档。

### major 2 · 三条 change 期判据在 `test/` 树 0 引用 —— `Fixed in:` 抽取路径 + 执行输出；判别力有实证

- 抽取路径（脚本内实现；等价手写）：`sed -n '/<task id="T17"[^>]*>/,/<\/task>/p' TASK.md | sed -n '/<verify>/,/<\/verify>/p' | sed '1d;$d'`。
- 本次执行输出：**T13** rc=0（34 行，成功行 `✅ 脱敏完成：授权面外命中 = 0（tracked + 未 tracked 两面均已扫描）`）· **T17** rc=0（73 行，重抽即修正后版本）· **NFR 兼容性判据** rc=0（空变更集 ⇒ rc=3「未验证」的反向对照见 `PHASE5-RECEIPTS.md` §C）。
- **非恒绿实证**：T17 于本轮**确实转红过**（`🔴 排除表缺 .specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`）⇒ 判据是活的；随即按 L-150 把策略由「集合完备」改判为「时间切点」，并加**双向断言**（新增档进豁免表 ⇒ 红；冻结集 1–3 不在表内 ⇒ 也红）。
- `TD-053`（常设 bats 缺失）仍按 **`Tech-debt: TD-053`**：不就地补测试的次序理由已在 `TEST.md` §回归保护 / §阶段 5 发现 #1 落档（phase 7 triage 不遗忘）；本轮把「判定力只由 task id 承载」收敛为「可一键重跑」。

### major 3 · 字面执行 vs 修正后执行 / 是否回写 TASK.md —— `Fixed in: TEST.md §1.7`

- 新增 **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §1.7「判据修正台账」**：11 条判据为**字面抽取 + 字面执行**（不套 `set -e`、零改写）⇒ rc=0；**唯一**被修正的是 T17，且修正**就写在权威副本 `TASK.md` 内**（不存在「报告用修正版、仓内是旧版」的分叉）。
- T19 的 `set -e` 陷阱已用 strict 对照实验量化：`bash -c 'set -euo pipefail; source …/v_T19.sh'` ⇒ **rc=1 / 19 行前置输出 / 无任何 🔴 断言报文**（与真红态同为 rc=1，只能靠报文区分）vs 平跑 rc=0。
- 回写决定：**不回写** `TASK.md` —— ① 该惯用法 `out=$(cmd 2>&1); rc=$?` 仅在 `set -e` 下早退，字面执行通过；② 同惯用法在 `TASK.md` 命中 **22 处**，机械改写会波及未复算的判据块；③ `TASK.md` 属阶段 3 工件、其 `.done` 已因历次订正与哈希失配（TD-042）⇒ 按次序「如实登记差异」⇒ **`Tech-debt: TD-057`**（含 v2 修法 `out=$(cmd) || rc=$?; rc=${rc:-0}`）。

### major 4 · 安全结论的循环论证 —— `Fixed in: TEST.md §3.4` + `Tech-debt: TD-056`

- **`Fixed in: .specs/health-fix-2026-09b/TEST.md` §3.4**：加「结论强度限定」—— A01–A10 的 ✅/⚠️ **只代表「模式扫描 + shellcheck + 自研门禁」替代面**的判定强度，**不**代表 `semgrep` / CodeQL / `gitleaks` / `trufflehog` / `trivy` 级工具面结论；`npm audit` 因 `ENOLOCK` **未参与**任何判定；凡无「工具面 + 双态注入」双重证据支撑者一律标 ⚠️ 而非 ✅。
- **`Tech-debt: TD-056`**（`.specs/CONTEXT.md` 已登记）：工具缺失面由**说明性记事升为基础设施债**，与 TD-053 同优先级；v2 = 安装 `gitleaks` + `semgrep` 并接线 `make security-scan`；引入依赖时同步引入 lockfile。

### minor ①–⑤ · 逐条处置（全部 `Fixed in: TEST.md`）

| minor | 处置 |
|---|---|
| ① 性能测量条件与 5 次统计 | **`Fixed in: TEST.md` §2.2**：环境（`nproc=32` · `loadavg 6.04 6.48 6.52` · 无并发 · git 索引热态）+ **5 次** real = 2.842 / 2.847 / 2.898 / 2.836 / 2.867 s（min 2.836 · max 2.898 · 均值 2.858 ⇒ 预算 57%）+ 复算命令（脚本 [D] 段） |
| ② UAT ③ 依赖不可逆历史态 | **`Fixed in: TEST.md` §1.2 ③**：显式标注为**历史事件记录**，并给出**可构造的等价复现**（在任意「尚未产出该阶段审查档」的 change 上提交该阶段工件 ⇒ 同一拒绝报文） |
| ③ TD-033 与 AC-4 证据面 | **`Fixed in: TEST.md` §1.6 ②**：说明 TD-033 **不**影响 AC-4 —— AC-4 证据全部采自 `test/test_check_gate_sync.bats` 的 5 用例（`:30/:38/:45/:51` 均 `run bash "$SCRIPT"` 直调真脚本、无 mock；漂移 / 不误报双态齐备） |
| ④ 973 → 976 口径差异 | **`Fixed in: TEST.md` §1.3 第 4 条**：`git diff --stat 534e3e8..HEAD -- test/` = 8 文件 +84/−28；`@test` 计数唯一变化 = `test_archive_commit_gate.bats` **24 → 27（+3）** ⇒ 973+3=976；历史「1 skip」是变更前基线的过期 skip（AC-7 已移除）⇒ 附逐文件复算命令 |
| ⑤ L 编号无出处 | **`Fixed in: TEST.md` 文末「L 条目索引」**：L-129 / L-137 / L-146 / L-148 / L-149 / L-150 各附「含义 + `LESSONS.md` 行号 + 编号检索命令」（行号随新增漂移，故给检索式） |

### L3 第 1 轮条目与 🟢 面

- L3 第 1 轮 1 major（TD-053）+ 4 minor 的处置已在本文件上一段「主 agent 响应（阶段 5 · 第 1 轮 · 2026-09-24）」内落档，本轮未撤销、未降级。
- 处置后门禁复核（本轮实跑原始回执）：`npx bats test/` rc=0 · **ok=976 / not ok=0 / skip=0**；`make check` rc=0；`make check-path-privacy` 清单外命中 **0**；`package-flow-kit.sh --validate` rc=0 —— 全文见 `PHASE5-RECEIPTS.md` §B。

**主 agent 判定**：接受 L3 第 2 轮全部 4 major + 5 minor 并按上表闭环；对 L3「verdict = pass」的结论无异议（`critical: []` 与实跑证据一致）。

## 主 agent 响应（阶段 5 · L3 第 3 轮 · 2026-09-24）

**L3 第 3 轮结论**：`verdict: pass`（0 critical · 4 major · 4 minor，段 `:299`–`:366`）；主 agent **接受全部 8 条**，逐条给出 `Fixed in:` / `Tech-debt:`。本轮技术债占比 = **1/8**（仅 major 2 ⇒ TD-053）；另有两条**本轮实测新发现**的产品缺陷 **TD-058 / TD-059**（由 major 3 的复现脚本逼出）按 `Tech-debt` 登记，理由与 v2 修法见 `.specs/CONTEXT.md`。

| 条目 | 判定 | 落点 |
|---|---|---|
| major 1（回执被截断 ⇒ 核心数字不可复算） | `Fixed in:` | `PHASE5-RECEIPTS.md` **§0**（≤3000 B 的最小复算证据：结论 + 两条一键命令 + 逐面结果表）+ **§I**；`TEST.md` 头部两条入口与 §1.7；`L-151` 登记 |
| major 2（三个生产件无常设回归网） | `Tech-debt: TD-053` | `TEST.md` 处置表 #12：按 L3 给出的第二条路**显式声明「长期回归保护未达标」**，并交 **阶段 7 triage**（不得归档后遗忘） |
| major 3（UAT ③ 不可构造复现） | `Fixed in:` | 新工件 `.specs/health-fix-2026-09b/reproduce-phase-gate.sh`（沙箱 + `git init` + stdin JSON 真调 PreToolUse 门禁；状态 A/B/B2/B3/C + 判别子）→ 接入 `reproduce-5-test.sh` 的 **[F]** 步 → 原文 `PHASE5-RECEIPTS.md` **§H** → `TEST.md` §1.2 ③ |
| major 4（T19 `set -e` 陷阱） | `Fixed in:` | `TASK.md` T19 `<verify>` **4 处**改为「先置零再捕获」`rc=0; out=$(…) || rc=$?` + 块尾约定注释；回写后 strict **rc=0 / 37 行**（回写前 rc=1 / 19 行 / 无 🔴 报文） ⇒ `TEST.md` §1.7 的 T19 行由「不回写」改为「**已回写**」 |
| minor ①（原始 TAP 未附 / 973 口径交错） | `Fixed in:` | `PHASE5-RECEIPTS.md` §B-2（TAP 逐项计数）+ `TEST.md` §1.3 第 2/5 条（973→976 逐项归因）+ 交叉引用 `T27-SUMMARY.md:22/:25/:76` 与 `T26-SUMMARY.md:152/:154` 的**既有**口径注记（973 = 变更前基线 / 各任务执行期实测值，非篡改） |
| minor ②（§3.4 的 ✅ 可被读成工具级通过） | `Fixed in:` | `TEST.md` §3.4：表头改「替代面判定」+ 明示「工具面证据：无」 |
| minor ③（TD-033 mock 计入 976） | `Fixed in:` | `TEST.md` §1.3 第 5 条：**有效用例 = 975**（1 条 TD-033 mock 不计入 AC-7 结论面） |
| minor ④（第 4 轮标「✅ 必跑」而 macOS 未实跑） | `Fixed in:` | `TEST.md` §0 第 4 轮行：「✅ 静态面必跑 / ⚠️ macOS 实机未验证（TD-055）」 |

**本轮判据活性的两个新证据（供下一轮优先采信）**：

1. **判据对「新代码」同样有效（非恒绿）**：新脚本里的 `sed -i`（GNU-only）被 **T29**（rc=1，报文「🔴 新增行含 bash4-only / GNU-only 构造，命中位置 `reproduce-phase-gate.sh:137` / `:140`」）与 **`make check-nfr-portability`**（`make check` rc=2）当场判红并指名 `file:line`；改为「`sed … > tmp && mv`」后双双回绿。处置后的全量复算 **rc=0**：判据 12/12 ✅（T19 回写后抽取 36 行）· 门禁 7/7 ✅（bats `--count` 976 · `npx bats` rc=0 `ok=976 / not ok=0` · `make check` rc=0 **21 ✅ / 0 ❌** · privacy 清单外命中 0 · NFR ×5 均值 **2.851 s** = 预算 57% · `--validate` 漏配 0 / 源缺失 0 · 阶段门沙箱复现 rc=0）⇒ 回执 `PHASE5-RECEIPTS.md` **§I**。
2. **缺口被封进判据，而不是藏进文档**：TD-059 的两个形态（标记口径不一致 / 标记残缺）以 `check_gap()` 记为 **⚠️ 缺口实证**（命中即打印 TD-059 归因；行为若变化只提示 ℹ️ 且不判失败）⇒ 连「缺口行为发生变化」这件事本身也被判据覆盖。

**未撤销声明**：L3 第 1/2 轮的全部处置与 `Tech-debt` 登记在本轮**未撤销**（TD-051/TD-053/TD-054/TD-055/TD-056/TD-057 逐条保持）；本轮新增 **TD-058 · TD-059 · L-151 · L-152**，并把 TD-053 的「长期回归保护未达标」结论显式写进 `TEST.md` 处置表 #12。

## 主 agent 响应（阶段 5 · L3 第 4 轮 · 2026-09-24）

**L3 第 4 轮结论**：`verdict: pass`（0 critical · 4 major · 5 minor）；主 agent **接受全部 9 条**，逐条给出 `Fixed in:`。**本轮无新增技术债**（既有 6 条 TD-053/055/056/057/058/059 保持登记）。

| 条目 | 判定 | 落点 |
|---|---|---|
| major 1（AC 覆盖 8/8 与「3 件生产件 0 引用」并存 ⇒ 可能被读作长期回归保障） | `Fixed in:` | `TEST.md` §1.1 新增「**结论口径声明**」（✅ = **change 期覆盖**）+ §回归保护 新增「**长期回归保护的判定：未达标**」显式声明并**交阶段 7 triage**；`Tech-debt: TD-053` 保持 |
| major 2（UAT ③ 称「真实拦截」而 B2/B3 放行） | `Fixed in:` | `TEST.md` §1.2 ③ 新增「**本条验收面结论**」⇒ **UAT ③ = 部分通过**，B2/B3 列为**未覆盖分支**（不再只记 Tech-debt）；`Tech-debt: TD-059` 保持 |
| major 3（核心数字在可见工件之外） | `Fixed in:` | `TEST.md` **附录 A「最小复算存档」**（正文可见区：12 条判据 rc + 抽取行数 · bats 收集/有效计数 · `make check` 九门禁摘要 · 性能 3+5+5 次与端到端样本 · 阶段门五层结果 · 失败语义）+ **附录 B**（T17/T19 回写回执）；`PHASE5-RECEIPTS.md` §0 增两行索引 |
| major 4（976 与 TD-033 mock 并存） | `Fixed in:` | 全篇统一「**975 有效**」口径：`TEST.md` §1.1 AC-8 行 · §1.3 第 2/4 条 · §2.4 · §2.5 数字口径注 · §回归保护（原始回执数字**不改写**，只加口径注） |
| minor ①（无端到端耗时） | `Fixed in:` | `TEST.md` §2.2 新增端到端实测（`npx bats test/` **121.203 s** · `make check` **258.890 s**）+ `PHASE5-RECEIPTS.md` **§I-1**（原始输出） |
| minor ②（OWASP 可能被读成工具级） | `Fixed in:` | `TEST.md` §3.4 增「**证据等级**」列并把 A02/A06 降为 ⚠️ ⇒ **✅ 5 / ⚠️ 4 / ➖ 1**，并标注工具面证据：无 |
| minor ③（第 4 轮 macOS 措辞） | `Fixed in:` | `TEST.md` §4.4 第 1 行 ⇒ 「✅ **静态面通过** / ⚠️ **macOS 实机未验证（TD-055）**」 |
| minor ④（L 条目只给检索命令） | `Fixed in:` | `TEST.md` L 索引**每行已含一句话内容**（检索命令为补充）；本轮内嵌条目含 L-150/L-151/L-152 的新增要点 |
| minor ⑤（T17/T19 原文未附） | `Fixed in:` | `TEST.md` **附录 B**：抽取与复算脚本落盘副本 `diff rc=0` 回执（T17 73 行 / T19 36 行）+ T19 四行回写的行号与前后对照 + T17 的策略改判说明 |

**两条硬声明（供后续轮次与阶段 7 直接引用，避免歧义）**：

1. **本 change 的 AC 覆盖 = change 期覆盖**；**长期回归保护判为「未达标」**（3 件生产件 `test/` 树 0 引用，`TD-053`），归档前不得当作「已有常设回归网」。
2. **UAT ③ = 部分通过**：阶段门在 commit 路径上只在**完成标记缺失**时拒绝（`TD-059`）；`B2`/`B3` 为该条的**未覆盖分支**，已由 `reproduce-phase-gate.sh` 以 `⚠️ 缺口实证` 固定（行为变化会显式提示）。

**本轮落盘**：`TEST.md`（407 → **474 行**：附录 A/B + 全局口径统一）· `PHASE5-RECEIPTS.md`（§0 索引 + §I-1，**837 行**）· 本响应段。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-24 11:52）

> 自动生成于 2026-09-24 11:52。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "TEST.md §1.1/§回归保护",
      "issue": "测试矩阵虽自述 8/8 AC 有 change 期覆盖，但 3 件生产件（runtime-edit-guard.sh、check-path-privacy.sh、check-nfr-portability.sh）在 test/ 树 0 引用，且 AC-1/AC-6/AC-8 明确无常设 bats 回归（TD-053）。报告将这些标为 Tech-debt 并声明长期回归保护未达标，但按阶段门/验收标准，长期回归保护是质量门禁的一部分，当前工件内没有常设回归网来防止这些关键安全门禁将来被破坏。",
      "why": "没有常设回归测试意味着这些关键安全行为（不 eval、路径隐私、NFR 可移植性）在 change 合并后可能被后续改动静默破坏；报告自身也承认长期回归保护未达标，却仍给出整体通过结论，验收口径不一致。",
      "fix": "要么为三个 0 引用生产件补齐常设 bats 用例并纳入 make check，要么在验收结论中明确把「长期回归保护未达标」作为阻塞性或至少 major 级未满足项，而不是仅记为 Tech-debt 后仍判通过。"
    },
    {
      "file": "TEST.md §1.2 ③/§0",
      "issue": "UAT ③（阶段门真实拦截）被判 FAIL：B2/B3 完成标记存在但口径相反或残缺时门禁 rc=0 放行（TD-059）。工件把该缺口显式登记为 Tech-debt，但验收面端到端结论仍是「未通过（FAIL）」，而总体 verdict 若仍为 pass 则与验收标准冲突。",
      "why": "阶段门是 AC-8/验收路径上的安全门禁，若标记可被 touch 或残缺内容绕过，独立审查门禁的实际拦截能力不满足验收要求；报告自己在 §0 也写「不得把阶段门拦截读作通过」。",
      "fix": "在最终 verdict 中把 UAT ③ 的 FAIL（TD-059）作为关键未满足项计入结论，或要求本 change 内修复 B2/B3 放行路径（Gate3 复用 Tier-1 校验，使存在但无效的标记也拒绝）后再判通过。"
    },
    {
      "file": "TEST.md 附录 A/C 与 PHASE5-RECEIPTS.md",
      "issue": "核心验收数字（976 ok、make check 全绿、性能 2.8s、12 判据 rc=0）虽然在本工件正文中给出汇总，但原始输出存放在 PHASE5-RECEIPTS.md，而该文件超出补充产物预算被整行截断，审查者无法从工件内部独立复算验证这些数字；reproduce 脚本虽提供一键复算入口，但本次盲审没有运行环境证据证明脚本在 HEAD 上实际可执行且输出与报告一致。",
      "why": "独立复算是 blind review 的基础；如果关键证据在可见工件之外，且 receipt 被截断，审查者只能信任报告自报数字，无法确认是否存在 mock/恒绿/选择性记录。",
      "fix": "将 12 条判据的原始 stdout、bats TAP 计数原文、make check 各门禁原文、性能计时原文直接内嵌到 TEST.md 正文（或至少保证 receipt 的关键部分在 3000B 预算内完整可见），并在工件中附上 reproduce 脚本在 HEAD 的完整可复现运行日志及校验和对应的实际输出。"
    }
  ],
  "minor": [
    {
      "file": "TEST.md §1.3",
      "issue": "976 条用例中 1 条是 TD-033 mock 用例（test_gate_config_presets.bats 自陈 Simulates resolve_gate_config()，从不 source 生产实现），报告将有效用例口径改为 975，但多处仍以 976 作为通过数字；口径混用易误导。",
      "why": "验收数字应统一且可精确复算；975 vs 976 虽然报告有解释，但读者容易把 976 ok 当作全部真实用例通过。",
      "fix": "统一所有结论面和摘要中的用例数为「976 收集 / 975 有效」，并在矩阵和摘要中避免单独使用 976 作为通过证据。"
    },
    {
      "file": "TEST.md §3.4",
      "issue": "OWASP A01–A10 在无 semgrep/gitleaks/trufflehog/trivy 且 npm audit ENOLOCK 的情况下，最终判定为 0 条 ✅、9 条 ⚠️、1 条不适用，但安全轮次结论仍可能被读作安全验收通过；报告虽加了结论强度限定，但 A09 等条目仍标 ⚠️ 而范围外。",
      "why": "工具面缺失意味着安全测试的独立证据强度不足；若验收要求包含安全扫描，当前只能算替代面检查。",
      "fix": "把安全轮次结论明确列为「替代面检查通过，工具面未验证」，并按 TD-056 将工具缺失作为 major 或至少 minor 级残余，不参与最终 pass 依据。"
    },
    {
      "file": "TEST.md §4.4",
      "issue": "macOS 实机未验证，AC-8 的跨 OS 兼容性只靠静态判据 make check-nfr-portability；报告以 TD-055 登记，但在验收矩阵中仍列为 change 期 ✅。",
      "why": "静态判据不能替代实机运行，尤其 bash 3.2/locale/iconv 差异；若验收要求跨 OS，则此处证据不足。",
      "fix": "在结论中明确 macOS 实机为未验证残余，并将 AC-8 的跨 OS 面标记为 ⚠️ 未验证，而非 change 期通过。"
    }
  ],
  "verdict": "fail",
  "summary": "测试报告自身承认长期回归保护未达标（3 件生产件 0 引用）、UAT ③ 阶段门在 B2/B3 分支放行（TD-059）、核心数字原始证据在截断 receipts 之外，且安全工具面缺失，故按验收标准不能判定通过。"
}
```

L3_artifact_hash: 634d981bb7d91d88dd32032ed9e2a2e322c2a11a62465db7733d17dfb65b0088

<!-- /L3-SECTION -->
