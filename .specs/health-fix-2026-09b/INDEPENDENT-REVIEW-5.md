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

## L2 盲审（第 2 轮）

> 独立盲审 · phase 5（5-test）· change-id `health-fix-2026-09b`
> 审查模型：L2 盲审（固化指令 `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md`）
> 审查时点：2026-09-24（HEAD `ddea327` · 工作树含未提交修改）
> 主审工件：`.specs/health-fix-2026-09b/TEST.md`（846 行 · 工作树）
> 参考工件：`.specs/health-fix-2026-09b/REQUIREMENT.md`、`.specs/health-fix-2026-09b/TASK.md`、`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`（既有 L2 第 1 轮 + 主 agent 响应 + L3 重审段）

### 独立取证摘要

本盲审在仓库根 `<repo>` 实跑以下只读命令取证（禁止 `git add` / `commit` / `checkout` / 改工件）：

| 取证项 | 命令 | 结果 |
|---|---|---|
| bats 总数 | `npx bats --count test/` | **1012** ✅（与 TEST.md §1.3 一致） |
| 有效用例 | 1012 − 1（TD-033 mock） | **1011** ✅ |
| 4 新 bats 文件 | `ls test/test_{path_privacy_gate,runtime_edit_guard,nfr_portability_gate,review_gate_validity}.bats` | 均存在 · 用例数 9/9/7/11 = 25+11 ✅ |
| `make check-nfr-portability` | `make check-nfr-portability` | rc=0 ✅（Makefile 内联 recipe · **非 .sh 文件**） |
| T-FIX-01 判据抽取 | `extract_verify "T-FIX-01" TASK.md` | 36 行（首行 `rc=0;`）✅ |
| T-FIX-02 判据抽取 | `extract_verify "T-FIX-02" TASK.md` | 42 行（首行 `set -u; rc=0;`）✅ |
| 阶段门六态沙箱 | `reproduce-phase-gate.sh` | A rc=2 / B rc=0 / B2 rc=2 / B3 rc=2 / B4 rc=2 / C rc=0 · script_rc=0 ✅ |
| REPRO4 T-FIX-01 输出 | `cat /tmp/fk-reproduce-5-r4/out_T-FIX-01.txt` | `TAP: ok=25 not-ok=0 rc=0` ✅ |
| REPRO4 T-FIX-02 输出 | `cat /tmp/fk-reproduce-5-r4/out_T-FIX-02.txt` | `A=2 B=0 B2=2 B3=2 B4=2 C=0` ✅ |
| REPRO4 T29 输出 | `cat /tmp/fk-reproduce-5-r4/out_T29.txt` | `make check` 全绿 + `bats: rc=0 ok=1012 not-ok=0` ✅ |
| r4b T27/T29 地板订正 | `grep 'b_ok' /tmp/fk-reproduce-5-r4b/v_T27.sh` | `-ge 1009` + echo `1012 ok` ✅ |
| L-031 跨文件一致性 | `git diff --name-only $(.change-base)` vs DESIGN §0.5.1 | 20 路径全 listed+changed ✅ · done-validation.sh = class 2（DESIGN 漏列但 T-FIX-02 write_files 授权）· **无 class 4 漏改** ✅ |
| 分类标记计数 | `grep -c 'Fixed in:\|Tech-debt:\|Not-applicable:' TEST.md` | **53** 处 ✅ |
| 5 轮金字塔 | TEST.md §0 表 | 5 轮全声明 · 无跳过 · ⚠️ 均附理由 ✅ |

### Phase 5 核查清单

| 核查项 | 结果 | 说明 |
|---|---|---|
| AC 覆盖率（≥1 test/AC） | ✅ | 8/8 AC 有 change 期判据覆盖；TD-053 已闭合 ⇒ AC-1/AC-6/AC-8 常设 bats 覆盖补齐（25 用例） |
| 5 轮金字塔 | ✅ | 功能 ✅ 全跑 / 性能 ⚠️ 预算面全 / 安全 ⚠️ 替代面 / 兼容 ⚠️ 静态全+macOS 缺 / 可观测 ⚠️ 日志全；无跳过，⚠️ 均有理由 |
| 功能轮 100% AC 覆盖 | ✅ | §1.1 矩阵 8/8 AC 全标 ✅（change 期） |
| UAT 可执行（Given/When/Then） | ✅ | 4 条 UAT 全附可复制 bash 序列 + reproduce-phase-gate.sh 六态沙箱 |
| 回归安全（bats 不退化） | ✅ | 976→1012（+25 T-FIX-01 +11 T-FIX-02）；地板 973→1009；make check 9 门全绿 |
| 修代码优先（分类标记） | ✅ | §阶段 5 发现与处置 53 处 `Fixed in:` / `Tech-debt:` / `Not-applicable:` |
| L-031 跨文件一致性 | ✅ | 20 路径 listed+changed · 2 路径 class 2（TD-048 授权）· done-validation.sh class 2（T-FIX-02 授权）· **无 class 4 漏改** |

### 发现

### 🟡 R1 · AC-8 口径张力：✅ 标记与 macOS 实机未验证（TD-055 开放）并存

**Severity**：🟡 Important（已登记 Tech-debt，不阻塞 toll-gate）

**Symptom**：TEST.md §1.1 AC-8 行（`:47`）在「change 期判定」列标 ✅，但「长期回归保护」列同时标 ✅（常设 bats 25 用例）与 ⚠️（macOS 实机未验证 TD-055）。§1.1 覆盖判定（`:49`）声明「8/8 AC 有 change 期覆盖且无空缺」且「静态判据通过 ≠ 跨 OS 兼容性验收通过」，但主表 AC-8 的 ✅ 与 ⚠️ 并存，读者难以判断 AC-8 究竟是通过还是部分通过。L3 重审 major 1（INDEPENDENT-REVIEW-5.md `:354-358`）独立指出同一问题。

**Source**：`.specs/health-fix-2026-09b/TEST.md:47`（AC-8 行长期回归保护列 = `✅ 常设 bats 覆盖 3 件新网 … + ⚠️ macOS 实机未验证（TD-055，仍开放）`）、`:49`（覆盖判定 = `8/8 条 AC 有 change 期覆盖且无空缺`）、§4.4（`:337-347` 兼容性面 = `bash 3.2/GNU-only 静态 ✅, macOS 实机 ⚠️ TD-055`）。

**Consequence**：AC-8 的验收口径在主表与细则之间存在表述张力：✅ 标记可能被读作「AC-8 全部通过（含跨 OS）」，而实际 macOS 实机从未运行（无 macOS runner）。虽 TD-055 已登记且 §4.4 明示 ⚠️，但主表未对 AC-8 的 ✅ 加限定词，覆盖声明与实际执行范围不一致。不构成功能缺陷（AC-8 的 NFR 兼容性判据 = 静态面，静态面已通过），但属口径精度问题。

**Remedy**：在 TEST.md §1.1 AC-8 行的「change 期判定」列将 `✅` 改为 `✅（静态判据）` 或在 ✅ 后加脚注 `（macOS 实机 = TD-055 开放，见 §4.4）`，使主表与 §4.4 的 ⚠️ 口径一致；或在覆盖判定（`:49`）显式注记 `AC-8 的 ✅ 不含 macOS 实机面`。L3 重审 major 1 的 fix 建议同此。

---

### 🟡 R2 · 判据修改后回写但修改前原文未存档

**Severity**：🟡 Important（可追溯性缺口，不阻塞 toll-gate）

**Symptom**：TEST.md §1.7 判据修正台账（`:168-189`）记录 T17/T19/T-FIX-01/T-FIX-02/T27/T29 共 5 条判据在执行期间被修改并回写 TASK.md，但修改前判据的完整 `<verify>` 原文未随工件存档。REPRO4 主复跑日志（`/tmp/fk-reproduce-5-r4/`）仍用旧判据（T27/T29 地板 `-ge 973`、echo `976 ok`），r4b 补跑（`/tmp/fk-reproduce-5-r4b/`）才用订正后判据（`-ge 1009`、`1012 ok`）。外部审查者只能复现修正后的状态，无法独立确认哪些 rc=0 是原始判据通过、哪些是判据修正后通过。L3 重审 major 2（INDEPENDENT-REVIEW-5.md `:360-364`）独立指出同一问题。

**Source**：`.specs/health-fix-2026-09b/TEST.md:168-189`（§1.7 判据修正台账 5 条）、`/tmp/fk-reproduce-5-r4/out_T27.txt`（echo = `976 ok` 但实际 ok=1012）、`/tmp/fk-reproduce-5-r4b/v_T27.sh`（订正后 `-ge 1009`）、TASK.md `:1229`（T27 echo 已订正为 `1012 ok`）、`:1231`（T27 断言 `-ge 1009`）。

**Consequence**：判据修改的合理性已由 TEST.md §1.7 逐条说明（T-FIX-01 = LC_ALL=C 泄漏致既有用例假红 · T-FIX-02 = cwd 泄漏致沙箱判据假红 · T27/T29 = 地板随基线迁移），修改目的是修复判据漏洞而非「改判据直到绿」。但修改前原文未存档 ⇒ 复算只能复现修正后状态，无法对比修改前后判定力。这削弱验收证据的可追溯性，但 r4b 补跑已证明订正后判据在当前 HEAD 全绿。

**Remedy**：在 PHASE5-RECEIPTS.md 或 TASK.md 为每条被修改判据保留修改前完整 `<verify>` 原文（或对应 commit 路径），让 reproduce 脚本支持 `--base-criteria` 模式以原始判据执行对比。或在 §1.7 每条修正条目后附 `修改前 commit: <sha>` 引用。

---

### 🟡 R3 · OWASP 安全轮无独立工具面证据（TD-056 开放）

**Severity**：🟡 Important（已登记 Tech-debt，不阻塞 toll-gate）

**Symptom**：TEST.md §3.4 OWASP A01-A10 判定收紧后 ✅ 0 / ⚠️ 9（A01-A09）/ ➖ 1（A10），所有 ⚠️ 均因无独立安全工具证据（semgrep/gitleaks/trufflehog/trivy 全 MISSING，npm audit ENOLOCK）。§3.5 列出工具清单与可复现命令，但工具本身未安装运行。安全轮以「替代面」（自研门禁 + grep 模式）收尾，仍作为已执行轮次参与整体 PASS。L3 重审 major 3（INDEPENDENT-REVIEW-5.md `:366-370`）独立指出同一问题。

**Source**：`.specs/health-fix-2026-09b/TEST.md:283-302`（§3.4 OWASP 判定表 = 9 条 ⚠️）、`:304-322`（§3.5 安全面残余 + 工具清单）、TD-056（安全工具面缺失，仍开放）。

**Consequence**：安全类 AC（AC-1 eval RCE、AC-3 泄漏分支推送、AC-6 路径脱敏）的关键项（注入/越权/凭证卫生/依赖）只靠自研门禁和 grep 模式自证，无法独立发现真实漏洞。在无工具面证据的情况下把安全轮作为已执行轮次并参与整体 PASS，覆盖强度不足。但 NFR 要求（REQUIREMENT.md）未明文要求安装安全扫描工具，TD-056 已登记为开放 Tech-debt，且安全轮的替代面（shellcheck 68 文件 0 error + eval 面 0 + secrets pattern grep 0 命中）已提供基础证据。

**Remedy**：要么在交付前实际安装并运行至少一种独立安全扫描工具（semgrep/gitleaks/trivy）并附原始输出到 PHASE5-RECEIPTS.md；要么在 §3.4 与 §0 金字塔表中将安全轮明确降级为「受限/替代面」，把 A01/A03/A06/A07/A08 标为「未验证（工具缺失 · TD-056）」而非 ⚠️。

---

### 🟢 R4 · check-nfr-portability.sh 文件名引用错误

**Severity**：🟢 Minor（文档精度，不进修复循环，记入 MINOR-DEFERRED）

**Symptom**：TEST.md §1.3 可复算覆盖代理表（`:122`）引用 `flow-kit-bundle/flow-kit/reference/check-nfr-portability.sh（新增）`，但该路径下不存在 .sh 文件（`find . -name check-nfr-portability.sh` 返回空 · `git ls-files` 无记录）。实际工件是 Makefile `:247` 的内联 recipe（`make check-nfr-portability` 目标），非独立 .sh 脚本。Makefile 注释（`:132-140`）明确说明原因：判据文本含被禁原语字面（mapfile/readlink/stat -c），若落成仓内 .sh 会检到自己而永久假红（D8 F2 自排除边界）。

**Source**：`.specs/health-fix-2026-09b/TEST.md:122`（可复算覆盖代理表引用 `.sh` 路径）、Makefile `:247`（check-nfr-portability 内联 recipe）、`find . -name check-nfr-portability.sh` = 空。

**Consequence**：文档引用了不存在的文件路径，读者按此路径查找会落空。但 `make check-nfr-portability` 实跑 rc=0（已验证），功能未受影响。仅文档精度问题。

**Remedy**：在 TEST.md §1.3 可复算覆盖代理表将 `flow-kit-bundle/flow-kit/reference/check-nfr-portability.sh（新增）` 改为 `Makefile: check-nfr-portability 目标（内联 recipe · D8 F2 自排除边界）`。

---

### 🟢 R5 · REPRO4 日志 echo 描述串与实际计数不一致

**Severity**：🟢 Minor（时点差异，不进修复循环，记入 MINOR-DEFERRED）

**Symptom**：REPRO4 主复跑日志（`/tmp/fk-reproduce-5-r4/out_T27.txt` / `out_T29.txt`）中 echo 描述串仍为旧值 `基线 2026-09-24 T29 收口实测 rc=0 / 976 ok / 0 not ok`，但同一输出的实际 ok 计数为 `1012`。r4b 补跑（`/tmp/fk-reproduce-5-r4b/`）已修正 echo 为 `1012 ok`。TEST.md §1.7（`:187`）承认「第 5 次执行的主复跑（D-0..D-3）发生在该订正之前」。

**Source**：`/tmp/fk-reproduce-5-r4/out_T27.txt`（echo = `976 ok` · 实际 ok=1012）、`/tmp/fk-reproduce-5-r4b/out_T27.txt`（echo = `1012 ok`）、TEST.md `:187`（§1.7 时点说明）。

**Consequence**：REPRO4 主复跑日志的 echo 与实际计数不一致，读者可能误读为基线 976。但 r4b 补跑已修正，且 TASK.md 当前工作树的 T27/T29 判据已订正为 `-ge 1009` + `1012 ok`。仅历史日志时点差异。

**Remedy**：在 PHASE5-RECEIPTS.md 或 TEST.md 附录 D 明确标注 REPRO4 主复跑日志使用旧 echo（订正前），r4b 补跑为权威订正版。或在 REPRO4 日志目录附 README 说明时点差异。

---

### 🟢 R6 · TD-033 mock 用例仍计入 bats 总数

**Severity**：🟢 Minor（已登记 TD-033，不进修复循环，记入 MINOR-DEFERRED）

**Symptom**：TD-033（test_gate_config_presets.bats 的 mock 用例，自陈 `Simulates resolve_gate_config()`，从不 source 生产实现）仍计入 bats 总数 1012，仅被声明为「有效 1011」并排除出结论面。gate_config 语义仍无真实实现回归，AC-4 的 gate_config 依赖替代文件证明。L3 重审 minor 2（INDEPENDENT-REVIEW-5.md `:380-384`）独立指出同一问题。

**Source**：`.specs/health-fix-2026-09b/TEST.md:96-132`（§1.3 覆盖 = 1012 收集 / 1011 有效 · 1 条 TD-033 mock）、TD-033（仍开放）。

**Consequence**：mock 用例未修复或剔除，只是排除出结论面。读者可能误把 1012 当作全部真实用例通过。但报告已在 §1.3 明示「有效 1011」且 TD-033 已登记。

**Remedy**：将该 mock 文件从 bats 计数中排除（`--exclude`），或重写为 source 真实 lib 的用例，使 gate_config 语义有真实回归。

---

### 🟢 R7 · L3 重审无对应主 agent 响应段

**Severity**：🟢 Minor（流程完备性，不进修复循环，记入 MINOR-DEFERRED）

**Symptom**：INDEPENDENT-REVIEW-5.md 工作树版本（`:344-400`）含新的 L3 重审段（deepseek-v4-flash-0731 · 2026-09-24 17:42 · verdict=pass · 3 major + 3 minor），但该段之后无对应的「主 agent 响应」段。文件中最后一个主 agent 响应段（`:319`）是对 L3 第 4 轮的响应，位于 L3 重审段之前。

**Source**：`.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md:319`（主 agent 响应 L3 第 4 轮）、`:344`（L3 重审段开始）、`:400`（`<!-- /L3-SECTION -->` 文件末尾，无后续响应段）。

**Consequence**：L3 重审的 3 major + 3 minor 无对应主 agent 响应段输出分类标记（`Fixed in:` / `Tech-debt:` / `Not-applicable:`）。但 L3 verdict=pass（`critical: []`），3 major 均已映射到既有 TD（TD-055 macOS / TD-056 安全工具 / 判据可追溯性）且在 TEST.md §1.7 / §3.4 / §4.4 中已有处置记录，不构成阻塞。属流程完备性缺口，主 agent 可在后续补写响应段。

**Remedy**：在 INDEPENDENT-REVIEW-5.md 的 `<!-- /L3-SECTION -->` 之前补写「主 agent 响应（阶段 5 · L3 重审 · 2026-09-24）」段，对 3 major + 3 minor 逐条给出 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 分类标记。

---

### L-031 跨文件一致性核查

按固化指令 L68-82 要求，独立扫描全仓 grep 锚点 vs `git diff $(.change-base)` 实际变更文件，分 4 类判定：

| 类 | 判定 | 文件 | 说明 |
|---|---|---|---|
| 1（DESIGN 列出 + 已改） | ✅ | 20 路径 | runtime-edit-guard.sh / install_hooks.sh / l3-prompt.sh / check-gate-sync.sh / pre-commit.sh / Makefile / sync-hooks.sh / 7 对 bats 双源 / check-path-privacy.sh / pre-push.sh / path-privacy-allowlist.txt(2) / .change-base / 022-git-hook-deployment.md |
| 2（DESIGN 漏列 + 已改 · 授权） | ✅ | 3 路径 | `package-flow-kit.sh`（TD-048 用户裁决授权）· `validate_staging.sh`（TD-048 同源）· `done-validation.sh`（T-FIX-02 write_files 授权 · TD-059 L3 发现）|
| 3（DESIGN 列出 + 未改） | ✅ 无 | — | DESIGN §0.5.1 列出的 20 路径全部已改 |
| 4（DESIGN 漏列 + 未改 = 🔴 漏改） | ✅ 无 | — | 无漏改 |

**reproduce-5-test.sh / reproduce-phase-gate.sh**：不在 DESIGN §0.5.1，属阶段 5 产物（非 4-dev 设计产物），由 T-FIX-01/T-FIX-02 + 阶段 5 重入授权，不构成 write_files 越界。

**结论**：L-031 无 class 4 漏改，跨文件一致性通过。

---

### 总评

**Verdict**: pass

本次 L2 盲审（第 2 轮）对 change `health-fix-2026-09b` phase 5（5-test）的独立盲审结论为 **pass**。

依据：

1. **无 🔴 Critical**：独立取证未发现任何阻断 toll-gate 的 critical 缺陷。所有 7 条发现中 3 条 🟡（R1/R2/R3）均已登记为开放 Tech-debt（TD-055 macOS / TD-056 安全工具 / 判据可追溯性）或与 L3 重审 major 项重合，4 条 🟢（R4/R5/R6/R7）为文档精度与流程完备性 Minor。

2. **AC 覆盖完整**：8/8 AC 有 change 期判据覆盖（§1.1 矩阵），TD-053 已闭合 ⇒ AC-1/AC-6/AC-8 常设 bats 覆盖补齐（25 用例，T-FIX-01=5ee4ebc）。

3. **5 轮金字塔完整**：功能 ✅ 全跑 / 性能 ⚠️ 预算面全（check-path-privacy 2.8s ≤5s · 57%）/ 安全 ⚠️ 替代面 / 兼容 ⚠️ 静态全+macOS 缺（TD-055）/ 可观测 ⚠️ 日志全。无跳过轮次，⚠️ 均附理由。

4. **回归安全**：bats 976→1012（+25 T-FIX-01 +11 T-FIX-02），地板 973→1009，make check 9 门全绿。独立 `npx bats --count test/` = 1012 已验证。

5. **阶段门有效性闭合**：TD-059 已闭合（T-FIX-02=6cff7a2 + ADR-029 · done-validation.sh 由「标记存在」改为「标记存在且有效」）。六态沙箱实测 A rc=2 / B rc=0 / B2/B3/B4 rc=2 / C rc=0，独立复现 ✅。

6. **L-031 跨文件一致性通过**：20 路径 listed+changed · 3 路径 class 2 授权 · 无 class 4 漏改。

7. **修代码优先**：TEST.md §阶段 5 发现与处置 53 处 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 分类标记。

**3 条 🟡 进入修复循环（task-internal），不阻塞 toll-gate**：
- R1（AC-8 ✅ 与 macOS ⚠️ 口径张力）⇒ 建议 §1.1 主表 AC-8 行加限定词
- R2（判据修改前原文未存档）⇒ 建议 receipts 保留修改前 `<verify>` 原文
- R3（OWASP 无独立工具面证据）⇒ 建议降级安全轮为「替代面」或安装工具

**4 条 🟢 记入 MINOR-DEFERRED.md，不进修复循环**：
- R4（check-nfr-portability.sh 文件名引用错误）
- R5（REPRO4 日志 echo 时点差异）
- R6（TD-033 mock 计入总数）
- R7（L3 重审无主 agent 响应段）

---

## 主 agent 响应（阶段 5 · L3 第 7 轮重审 + L2 第 2 轮 · 2026-09-24）

> **范围**：本段同时响应 `## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-24 17:42）`（verdict=**pass** · 3 major + 3 minor）与 `## L2 盲审（第 2 轮）`（verdict=**pass** · R1–R7）。两者有 3 条相互重合（R1≈major 1 · R2≈major 2 · R3≈major 3），合并处置；**无 🔴**。

| # | 来源 | 级别 | 发现（摘要） | 处置 |
|---|---|---|---|---|
| 1 | L3 major 1 · L2 R1 | 🟡 | AC-8 的 macOS 实机面未验证（`TD-055` 开放）却在主表标 ✅ | **`Fixed in: TEST.md`** —— §1.1 AC-8 的 change 期判定列改 **⚠️ 部分通过**（静态判据 rc=0；macOS 实机未验证 · TD-055）；§0 第 5 次执行行补同款限定；§1.1「覆盖判定」新增**判定词收口**句：执行面 `14/14 rc=0` ≠ 8/8 AC 全通过 |
| 2 | L3 major 2 · L2 R2 | 🟡 | 6 条判据被回写 TASK.md，修改前 `<verify>` 原文未存档 ⇒ 无法排除「改判据直到绿」 | **`Fixed in: PHASE5-RECEIPTS.md §K`** —— 逐条内嵌**修改前 `<verify>` 原文** + 来源 commit（`T17`/`T19` = `9cbd098`；`T-FIX-02` = `0dfb08f`；`T27`/`T29` = `c50ad42`；`T-FIX-01` = 自 `0dfb08f` 入库起逐字节未变）+ 逐条执行结论 + **点次对照**（REPRO1–3 / REPRO4 / r4b 各用哪一版）⇒ 结论：**无一条属「判据判红 ⇒ 改判据至绿」**（`T-FIX-02` 修的是判据自身假红 · TD-060；`T27`/`T29` 收紧弱地板、红绿不变） |
| 3 | L3 major 3 · L2 R3 | 🟡 | 安全轮无独立工具面证据却参与整体 PASS | **`Fixed in: TEST.md`** —— §3.4 新增「**本轮判定降级**」：实现面判 **未验证（工具缺失）**、⚠️ 替代面**不计入 AC 通过面**；§0 第 3 轮行状态改 **⚠️ 受限（实现面未验证）**；工具缺失本体 = **`Tech-debt: TD-056`**（v2 = 装 `gitleaks` + `semgrep` 并接线 `make security-scan`） |
| 4 | L3 minor ① | 🟢 | UAT ③ 把「历史事件」与「沙箱等价复现」混写为同一验收面 | **`Fixed in: TEST.md §1.2 ③`** —— 新增「PASS 依据的边界」：**依据 = 沙箱六态等价复现**（可重放）；历史事件仅**旁证**，不作 PASS 依据 |
| 5 | L3 minor ② · L2 R6 | 🟢 | `TD-033` mock 用例仍计入 1012 | **`Tech-debt: TD-033`**（重写为 source 真实 lib 属 `test/**` **源面**变更，违反本 change「`T24` 后不动源面」次序约束）+ **`Fixed in: TEST.md §1.3`** 口径行显式标注**有效口径 1011** |
| 6 | L3 minor ③ | 🟢 | 历史值与当前值并列，读者需逐节核时点 | **`Fixed in: TEST.md §1.3`** —— 新增「**时点标记规则**」：未标「第 1–4 次执行」者一律为当前值（`1012` 收集 / `1011` 有效） |
| 7 | L2 R4 | 🟢 | §1.3 引用不存在的 `flow-kit-bundle/flow-kit/reference/check-nfr-portability.sh` | **`Fixed in: TEST.md §1.3`** —— 该行改 `Makefile`（`check-nfr-portability` **内联 recipe** + `check-nfr-portability-internals`；非 `.sh` 文件） |
| 8 | L2 R5 | 🟢 | REPRO4 日志 echo 描述串仍是 976 而实测 1012 | **`Fixed in: PHASE5-RECEIPTS.md §K` 点次对照**（REPRO4 = 订正前地板/描述串；r4b = 订正后）—— **不改写历史 stdout**（原始字节保留） |
| 9 | L2 R7 | 🟢 | L3 重审段无对应主 agent 响应段 | **`Fixed in: 本段`** |

**AC-4 技术债滥用防护**：本段 9 项处置 = **6 项 `Fixed in:`**（其中 3 项为工件内新增章节）+ **3 项 `Tech-debt:`**（`TD-033` / `TD-055` / `TD-056`，均为 change 前既有债或需 v2 工具面）⇒ 源码级发现被标技术债的比例**未达 50%**（分项分布见 `TEST.md`「阶段 5 发现与处置」）。

**重跑声明**：本段处置**修改了主工件 `TEST.md`**（846 → 857 行）⇒ 按 `l3-truncate.sh::_l3_check_rerun` 的 `L3_artifact_hash` 机制，旧 pass 不得充抵，主 agent **已就新工件重跑 L3 复审**（新段由 `l3-review.sh` 追加于本段之后）。


---

## 主 agent 响应（阶段 5 · L3 第 8 轮重审 · 2026-09-24）

**审查对象**：本文件 `## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-24 18:07）`（verdict 为 pass · 3 major + 4 minor · `L3_artifact_hash: 741fef0b28c0…` = 当轮 `TEST.md` 857 行版）。

**本段声明的工件版本**（终版）：`TEST.md` **1028 行** · sha256 `e84fcdb35337ca806b61516fe0925c6f3cb3d7f1e83318457fb5a1b97b1e42c2`；`PHASE5-RECEIPTS.md` **1632 行** · sha256 `e879c2d2b5f34b43dbb4d0c43fda64a6d0b2b3357fdc1a634e4c510586f6cf2a`（§0 前 2979 B ≤ 3000 B）。

| # | 来源 | 级别 | 发现（摘要） | 处置 |
|---|---|---|---|---|
| 1 | L3 第 8 轮 major 1 | 🟡 | §1.1 AC-8「长期回归保护」列仍 ✅，与 §0 / §4.4 的「部分通过」冲突 | **Fixed in: TEST.md** — `:51` 该列改「⚠️ 常设 bats 覆盖三件生产件静态面（25 例）；**macOS 实机面未验证（TD-055）⇒ 本列不得读作 AC-8 全通过**」；`:53` 覆盖判定改「8/8 中 **7 项通过、1 项部分通过（AC-8）**」；`:25`/`:27` §0 两次执行行同口径；`:353-360` §4.4 首行判定改 ⚠️ 并注明本节唯一 ✅ 属静态判据 |
| 2 | L3 第 8 轮 major 2 | 🟡 | 「所有 rc=0 均为字面执行」与 6 条判据被回写矛盾；主复跑用的是旧地板判据集 | **Fixed in: TEST.md** — `:188` 结论句改为「**除 T17/T19/T-FIX-01/T-FIX-02/T27/T29 六条在修正后重抽重跑**（修改前原文与来源 commit 见 receipts §K/§L）**外，其余判据为字面执行**」；`:676`/`:686`/`:704` 附录 D 标注判据集版本（D-0~D-3 = 修正前整轮 · D-4 = 修正后单条 · **D-5 = 修正后整轮的 rc=1 如实记录** · **D-7 = 终版整轮**） |
| 3 | L3 第 8 轮 major 3 | 🟡 | 安全轮以技术债结案，未把「实现面未验证」列为显式未覆盖项 | **Fixed in: TEST.md** — `:22` §0 第 3 轮行写明「**第 3 轮安全实现面 = 未验证（无独立安全工具），不构成 AC 通过面证据**」；`:316`/`:320` 覆盖判定单列 **安全工具面 0 / 10 未覆盖**；缺失本体 = `Tech-debt: TD-056`（v2 = gitleaks + semgrep 接线 `make security-scan`） |
| 4 | L3 第 8 轮 minor ① | 🟢 | 覆盖率段未说明工具面缺失 | **Fixed in: TEST.md** — `:106`/`:140` 明写「无 kcov/bashcov ⇒ 行/分支覆盖率**无数据**（不是 0%）」+ 新增「仅由 change 期判据覆盖的分支面清单」（`check-path-privacy.sh` fail-closed 三分支 · `runtime-edit-guard.sh` 双分支 · `Makefile` 空集守卫 rc=3）；`:170` §1.5 新增覆盖率工具面 blockquote |
| 5 | L3 第 8 轮 minor ② | 🟢 | `reproduce-phase-gate.sh` 版本口径自相矛盾（C-5「未改动」 vs T-FIX-02-SUMMARY「157→165」） | **Fixed in: TEST.md** — `:63` 明写当前版本 = `ddea327` 入库的闭合六态版（165 行 · sha256 `81700f12…` · 期望 B2/B3/B4 一律 rc=2）；`:674` 的「未改动」限定为「第 5 次执行相对其入库提交 `ddea327` **未再改动**」；`:678` 重写读法（闭合态由脚本期望值 + hook 侧 `done-validation.sh` 共同定义，不靠哈希不变）；`:811` D-3 同口径 |
| 6 | L3 第 8 轮 minor ③ | 🟢 | 第 5 次 NFR 均值与第 1–4 次并列但无负载差异分析 | **Fixed in: TEST.md** — `:226`（§2.2）/`:524`（附录 A ③）补负载差异说明：loadavg 7.91–8.12 vs 5.95–6.52 ⇒ 均值 2.895 s vs 2.851–2.858 s（+1.3%~+1.5%）；**判定不依赖负载归一化**（绝对阈值 5 s，最差 2.929 s 余量 41.4%） |
| 7 | L3 第 8 轮 minor ④ | 🟢 | §3.1「运行时依赖 = 0」表述过度简化（peer 依赖未审计） | **Fixed in: TEST.md** — `:276` 新增「peer 依赖语义」段：`flow-kit-bundle/brooks-lint/plugin/package.json` 仅 `devDependencies: {"@anthropic-ai/sdk": "^0.52.0"}`、**无 peerDependencies**；`peerDependencies: {"@deepseek-ai/cordis": "^4.0.1"}` 实测在 `dsh-flow-kit/package.json`（本项修改了 L3 原文的归属侧表述）；残余面 = peer 面宿主兼容性未审计 → `Tech-debt: TD-056` |
| 8 | 主 agent 自检（G-T04-1 / G-T04-2） | 🟡 | `l3-prompt.sh` 的 ADR 预算标记文案与行为不符（把已纳入正文的 ADR 声明为未纳入；称「整行截断」实为字节截断） | **Fixed in: `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`**（`:364` 改「工件引用的 ADR 全清单（已在上文附正文标记者即已纳入）」· `:369` 改「已按**字节**截断（UTF-8 边界安全，末行可能不完整）」）+ **静态钉住** `test/test_l3_review_defects_2026_09.bats` 的 B11-R6 内 6 条断言（不新增用例 ⇒ 计数仍 1012；单跑 124 ok / 0 not ok）+ `./sync-hooks.sh` 六副本 + dist 重建 · **零行为变更** · `commit f446617` · 处置事实见 `TEST.md` 附录 **D-6** 与发现表 **#33** |
| 9 | 过程留痕（不掩盖） | — | 中间轮 r4c 的 rc=1（`check-dist` 陈旧连带 T29 / T-FIX-01 / T-FIX-02 三条调 `make check` 的判据红） | **如实归档** `TEST.md` 附录 **D-5** —— 根因 = 主 agent 改了 `test/` 之后未按「`make test-sync` → `bash package-dsh-plugin.sh`」顺序重建 dist（Makefile 报错原文已自陈该顺序），与判据逻辑、与地板订正无关；修复后**冻结树终版整轮 r4d = rc=0**（判据 14/14 · 门禁 7/7 · receipts **§M** 内嵌原始输出），r4c 红点未被绿掩盖 |

**AC-4 技术债滥用防护**：本段 9 项中 8 项为 `Fixed in:`（在工件内或多处落地）、1 项为过程留痕；新增技术债登记仅 TD-055 / TD-056（均为 change 前既有债或需 v2 工具面）。`TEST.md` 终版技术债比 **7 / 33 ≈ 21.2%**（阈值 50%）。

**是否触发重跑**：本段处置**再次修改主工件 `TEST.md`**（857 → 1028 行）⇒ 按 `l3-truncate.sh` 的 `L3_artifact_hash` 机制，主 agent 已**重跑 L3 复审**（见下方新段），不以本轮 pass 充抵。


## 主 agent 响应（阶段 5 · L3 第 9 轮复审 · 2026-09-24）

| # | 轮次/等级 | 处置 | 落点 / 证据 |
|---|---|---|---|
| 1 | major 1 · AC-8 长期回归列 ✅ 与「部分通过」冲突 | **前轮已修，本轮补「四处口径一致性核对」**：§1.1 判定列 = ⚠️ 部分通过 · §1.1 长期列 = ⚠️（静态面 25 例常设 bats / macOS 面无机器证据）· §0 第 5·6 次执行行 = ⚠️ 部分通过 · §4.4 唯一 ✅ = **静态判据通过**（口径注明示不含 macOS 实机） | `TEST.md` §1.1 覆盖判定后（新增核对 blockquote）· `Fixed in:` 本轮编辑 |
| 2 | major 2 · 某 rc=0 属哪版判据不可判 | **新增「判据版本 × 执行轮次 × rc 对照表」**（T17 · T19 · `T-FIX-01` · `T-FIX-02` · `T27`/`T29` 六条 + 其余 8 条）+ 历史回执时点前缀规则；§2.5 加「第 1–4 次执行 · 修正前判据集」前缀；§2.4 的 976/975 标注时点 | `TEST.md` §1.7（新增表）· §2.5 · §2.4 · 修改前原文与来源 commit 见 `PHASE5-RECEIPTS.md` §K/§L |
| 3 | major 3 · 安全工具面未列为未覆盖项 | **§1.1 覆盖判定新增「安全工具面另计」**：**0 / 10 未覆盖** · 不构成 AC 通过面证据 · `Tech-debt: TD-056` = 本 change 安全验收的未覆盖项 | `TEST.md` §1.1（与 §0 第 3 轮行、§3.4 结论、§3.5 第 1 条同口径） |
| 4 | major 4 · `HEAD=ddea327` 与 `G-T04` 语义 | **澄清留痕**：r4d 执行时 = `ddea327` **+ `G-T04` 三文件的未提交工作树改动**（dist 已按该工作树重建）；该三文件随后提交为 **`f446617`**（3 files · +22/−2，提交前无进一步编辑 ⇒ 树内容 = r4d 所跑内容）；**「源面冻结」= 自 `f446617` 起不再变更源面** | `TEST.md` §D-6（新增 bullet）· §0 第 6 次执行行 · 提交 `f446617` |
| 5 | minor ① · 零 skip / mock 口径 | §1.3 第 2 条改写：**1012 收集且全部执行（零 skip）；其中 1 条 TD-033 mock ⇒ 有效 1011**；明确「零 skip ≠ 全为真实验证」；行覆盖率无数据不影响 AC 双态结论 | `TEST.md` §1.3 第 2 条（`Fixed in:` 本轮编辑） |
| 6 | minor ② · 阶段门脚本第 6 次执行哈希 | **补证**：第 6 次执行时点 = `81700f125c1c2557f4ebb468d41bbaf8aad452150b95371b4418464a8eb97337`（165 行）· 与 `ddea327` 入库版**逐字节一致**（`git show HEAD:… \| sha256sum` 同值 · `git diff --stat HEAD -- …` 空）；附三条原始命令输出 | `TEST.md` §C-5（追加小节） |
| 7 | minor ③ · §2.4 旧基线 976 | 同第 2 条：§2.4 加「第 1–4 次执行口径」前缀 + 指向当前基线 1012 / 1011 | `TEST.md` §2.4 |
| 8 | minor ④ · 附录 A ⑤ 失败根因未说明 | 补根因：判据侧脚本使用 GNU-only `sed -i` ⇒ `make check-nfr-portability` 变红 ⇒ 连带 `T29` 的 `make check` 步骤 rc=1 —— **判据/脚本侧问题，非产品缺陷**（改 BSD 安全写法后复跑 rc=0） | `TEST.md` §附录 A ⑤（`Fixed in:` 本轮编辑） |

**本轮工件状态（响应时点）**：`TEST.md` **1059 行** · sha256 `ed7fd8721913f6a5226b2b5b0a75216d0539fc52e64717e966789134be22c6bd`（1028 → 1059 行 · 9 处编辑，全部为**口径澄清/补证**，未改任何判据、未改任何 AC 判定方向）；逐条处置表与复算命令另见 `PHASE5-RECEIPTS.md` **§N**。`make check-path-privacy` rc=0（清单外命中 0 条）。

**声明**：本轮 8 条发现无一条被回避 —— 4 条 major 中 1 条（major 1）为本轮复核已修项的**再核对**并补齐一致性说明，3 条（major 2/3/4）为**新增内容**（判据版本表 · 安全工具面未覆盖项 · HEAD 语义澄清）；4 条 minor 全部就地订正。**已按流程重跑 L3 复审**（第 10 轮），不以本轮 pass 充抵。


## 主 agent 响应（阶段 5 · L3 第 10 轮复审 · 2026-09-24）

| # | 轮次/等级 | 处置 | 落点 / 证据（`Fixed in:` 本轮 14 处编辑） |
|---|---|---|---|
| 1 | major 1 · AC-8「部分通过」仍可能被读作通过 | **判定词再收紧**：AC-8 判定列改为 **⚠️「有条件通过（仅静态面）」+ 跨 OS 实机面 = 未验证 ⇒ 不构成通过**；§0 第 5/6 次执行行、§1.1 覆盖判定、§4.4 口径注四处同步改写（L3 第 10 轮原话「改为『未验证（macOS 实机）』或显式写不构成通过」）。**无 macOS runner ⇒ 不谎称已实机验证**；TD-055 保持开放 | `TEST.md` §1.1 判定列 · §1.1 覆盖判定 · §0 第 5/6 次执行行 · §4.4 口径注 |
| 2 | major 2 · 主表未标注每次执行的判据版本 | **逐行标注判据版本**：§0 第 5 次执行行 = **修正前**（旧地板 `-ge 973`）· 第 6 次执行行 = **修正后**（`-ge 1009`）+ 源面冻结，并明写「**第 6 次执行是全报告唯一『修正后判据集整轮全绿』的执行**」；§1.7 已有「判据版本 × 轮次 × rc」对照表；附录 A ② 同步标注 | `TEST.md` §0 两行 · §1.7 表 · 附录 A ② |
| 3 | major 3 · 安全工具面未作阶段级未覆盖项 | **§0 新增阶段级声明**：第 3 轮安全实现面 = 未验证（无独立安全工具）· **不构成任何 AC 的通过证据** · `TD-056` 按**阶段级未覆盖项**登记 · 安全工具面 **0 / 10**；§0 第 3 轮行 · §1.1 · §3.4 · §3.5 **四处同口径** | `TEST.md` §0 表后 blockquote（+ §1.1 本轮前已加） |
| 4 | major 4 · 未限定「第 5 次执行期间存在失败中间轮」 | **§1.2 ③ 增加「可复现性限定」**：全绿结论**仅对源面冻结后的工作树成立**；r4c rc=1（根因 = 源面在飞被改致 `check-dist` 陈旧 · 非判据/产品问题）与沙箱脚本五态→六态的事实一并写入 | `TEST.md` §1.2 ③ |
| 5 | minor ① · 1012/1011 的 mock 标注未统一 | §回归保护首行标注「**1012 收集 / 1011 有效 —— 含 1 条 TD-033 mock，不计入 AC 结论面**（所有引用 1012 的结论按此读）」；§1.1 / 附录 A ② 原已标注 | `TEST.md` §回归保护 |
| 6 | minor ② · TD-033 mock 的处置选项未说明 | §1.3 第 5 条补**三个处置选项**（① 重写为真实实现＝v2 推荐 · ② 标 `skip` 会打破「零 skip」并掩盖债 · ③ 移出收集面＝删证据）与**本 change 选「显式登记 + 全引用处标注」**的理由（`test/**` 源面自 `T24` 起冻结 · 范围由 `REQUIREMENT.md` 切分排除） | `TEST.md` §1.3 第 5 条 |
| 7 | minor ③ · 性能时点（2.895 vs 2.937） | §附录 A ③ 与 §2.2 各加**时点限定**：第 1–5 次为历史值、**终版性能基线 = 第 6 次执行 2.937 s（58.7%）**；两版均 ≤5 s ⇒ 结论不随版本变化 | `TEST.md` 附录 A ③ · §2.2 |
| 8 | minor ④ · §4.4 行级 ✅ 未标「仅 Linux」 | §4.4 的「编码/locale 矩阵」与「判据自身的地域作用域」两行判定列补注「**仅 Linux 本机实测 · macOS 未验证（TD-055）**」 | `TEST.md` §4.4 两行 |

**本轮工件状态（响应时点）**：`TEST.md` **1061 行** · sha256 `7f5a381054741353731cf493fa96b6cf2c9fc07c881522a8c4aed36ee20585b6`（1060 → 1061 行 · **14 处编辑**，全部为**口径收紧/标注补全**：未改任何判据、未改任何 AC 的判定方向、未改任何原始回执数字）。`make check-path-privacy` rc=0（清单外命中 0 条）。

**收口声明（第 10 轮）**：本轮 8 条发现**全部就地处置**（4 major + 4 minor，逐条落点见上表）；**已按流程重跑 L3（第 11 轮）以重新冻结 `L3_artifact_hash`**，不以本轮 pass 充抵。**终轮规则**：第 11 轮若 verdict = pass，则本轮之后**不再新增「口径再收紧」类编辑循环** —— 余下的表述类建议按**非阻断项**逐条落点登记（`MINOR-DEFERRED.md`）并随阶段 7 triage 处理；若第 11 轮出现 critical ⇒ 必修后再入。

## 主 agent 响应（阶段 5 · L3 第 11 轮复审 · 终轮 · 2026-09-24）

**本轮 = 终轮**（第 10 轮响应已声明规则）：verdict = pass ⇒ 不再新增「口径再收紧」类编辑循环；下列 8 条逐条处置/登记，**无 critical**。

| # | 发现 | 处置 | 落点 |
| --- | --- | --- | --- |
| M1 | AC-8 实机面无机器证据 | 主表/§0/§4.4 三处「有条件通过（仅静态面）· 不得读作 AC-8 通过」；v2 实机 | `TEST.md` §1.1 · §0 · §4.4；TD-055 |
| M2 | 判据版本标注可再收紧 | §1.7 版本×轮次×rc 对照表 + §0 两行版本标注已落；余为表述类 | `TEST.md` §1.7 · §0 · 附录 A ② |
| M3 | 安全工具面应为阶段级未覆盖项 | 已升格（§0 表后 blockquote + 覆盖判定 0/10） | `TEST.md` §0 · §1.1 · §3.4；TD-056 |
| M4 | 覆盖率无数据 / 无阈值 | **新登记 `TD-061`**（kcov/bashcov + `make coverage` 阈值 + CI 门禁） | `.specs/CONTEXT.md` · `TEST.md` §1.3/§1.5 |
| M5 | 终版轮含未提交工作树 / r4c 中间轮 | 已限定「仅对源面冻结后（自 `f446617` 起）工作树成立」+ 附录 D-5 保留 rc=1 | `TEST.md` §1.2 ③ · 附录 D-5/D-6/D-7 |
| m1 | UAT ③ 五态→六态与 T-FIX-02 时序 | 已说明版本口径与时序（C-5 sha == HEAD） | `TEST.md` §1.2 ③ · 附录 C-5 · D-5/D-6 |
| m2 | `check-nfr-portability` 无明文预算 | 已界定终版基线 2.937 s = 58.7%；预算出处 `REQUIREMENT.md ## 非功能性需求`；v2 补 Makefile 注释 | `TEST.md` §2.2 · 附录 A ③ |
| m3 | 「有条件通过」vs「未验证」措辞 | 判定列同时含两者 + 「不得读作 AC-8 通过」；三处同口径 | `TEST.md` §1.1 · §0 · §4.4 |

**本轮不存在「以 pass 换免修」**：第 9/10 轮共 17 处编辑（9 + 8/14 项收紧）均已计入 `TEST.md` 行数与哈希（`7f5a3810…`，1061 行），L3 段以本轮哈希复核；第 11 轮的 8 条按上述登记，**逐条指向文件与行级落点**，无一条以「后续处理」空转。
**余下登记项汇总入口**：`.specs/health-fix-2026-09b/MINOR-DEFERRED.md`「阶段 5 · L3 第 11 轮复审（终轮）发现登记」表 · `.specs/CONTEXT.md` `TD-061`。

## L2 盲审（第 3 轮）

**审查标识**：change-id `health-fix-2026-09b` · 阶段 5（5-test）· 独立 L2 盲审第 3 轮 · 2026-09-25 · 审查员 = 独立子 agent（本机脱敏：仓库根记 `<repo>`，本机探针路径用「`/home/` + 合成探针名 + `/`」拼接描述，绝不写出完整形态）。

**审查对象**：主审工件 = `TEST.md`（第 7 次执行 = fix 循环后重验最新数据 · HEAD `ee29a6d`）。参考工件（只读）= `REQUIREMENT.md`（AC-1..AC-8 原文）· `TASK.md`（29 + 5 条任务判据）· `PHASE5-RECEIPTS.md`（原始回执存档 §O）· `REVIEW.md`（阶段 6 审查报告 · fix 循环来源）· `INDEPENDENT-REVIEW-5.md`（本阶段历轮 L2/L3 审查档）。

**独立性声明**：本轮以独立子 agent 身份盲审，仅接受指定工件为唯一输入；未接受主 agent 自评 / 草稿 / 概述 / 辩护。审查过程为只读（除本次追加写入外未修改任何文件），未运行改动工作树的命令，未 `git add` / `git commit`。

---

### A. 阶段 5 checklist 逐项核对

| # | checklist 项 | 核对结论 | 证据定位 |
|---|---|---|---|
| C1 | AC 覆盖（每 AC ≥ 1 测试用例） | ✅ 达标 | `TEST.md` §1.1 AC 矩阵（`:45-54`）：AC-1=T05+9 bats · AC-2=T06+17 bats · AC-3=T11/T17/T19+27 bats · AC-4=T13+7 bats · AC-5=T24/T27+check-dist · AC-6=T20/T22/T23/T25/T26+20 bats · AC-7=T15/T17+4 假绿文件 · AC-8=T29+7 bats。8/8 AC 均有 change 期覆盖且无空缺。 |
| C2 | 5 轮金字塔（跳过有理由） | ✅ 达标 | `TEST.md` §0（`:23-29`）：7 次执行逐行记录，金字塔形态完整（单元 → 集成 → UAT → 安全 → 回归），每次跳过面均给出范围与理由（§0 `:33` 无声明跳过条）。 |
| C3 | 覆盖率（功能轮 100% AC） | ✅ 达标 | `TEST.md` §1.1 覆盖判定（`:56`）：8/8 AC 有 change 期覆盖。行覆盖率无数据（本机无 kcov/bashcov · `TD-061`），但 AC 功能覆盖 100%。 |
| C4 | UAT 可执行（Given/When/Then 可脚本化） | ✅ 达标 | `TEST.md` §1.2（UAT 脚本）：Given/When/Then 结构完整，含隔离 bare remote 的 pre-push 端到端（`:84-93`）。 |
| C5 | 回归安全（全量 bats 不退化） | ✅ 达标 | bats 全量 = 1025（有效 1024），基线演进 976 → 1001 → 1012 → 1023 → 1025 单调递增，无退化。`TEST.md` §0 `:29` · §1.3 `:123`。 |
| C6 | 修代码优先（主 agent 响应每条 🔴/🟡 给 Fixed in:） | ✅ 达标 | `TEST.md` §阶段 5 发现处置表 `:478-526`：#34-#40 每条发现均有 `Fixed in:` + commit sha（T-FIX-03=`6e39cfb` · T-FIX-04=`521b21c` · T-FIX-05=`6e94d60`），无空转。 |

---

### B. 数字自洽性核对（本轮重点）

| # | 核对项 | 声明值 | 实测值 | 自洽？ | 证据 |
|---|---|---|---|---|---|
| N1 | bats 全量计数 | 1025（有效 1024） | `npx bats --count test/` = **1025** | ✅ | 活体复算 `bats --count test/` = 1025；TAP 尾 `1..1025`（§O-2 `:1692-1693`）。有效 1024 = 1025 − 1（`TD-033` mock，`test/test_gate_config_presets.bats:27`「Simulates the resolve_gate_config() logic」）。 |
| N2 | 基线演进链 | 976 → 1001 → 1012 → 1023 → 1025 | 976 + 25（T-FIX-01）+ 11（T-FIX-02）+ 11（T-FIX-03: test_path_privacy_gate.bats 9→20）+ 2（T-FIX-04: test_check_gate_sync.bats 5→7）+ 0（T-FIX-05）= 1025 | ✅ | 活体验证：`test_path_privacy_gate.bats` @test 9→20（@`7dd4bd7`→@`6e39cfb`）；`test_check_gate_sync.bats` @test 5→7（@`7dd4bd7`→@`521b21c`）。25+11+11+2+0 = 49；976+49 = 1025 ✓。 |
| N3 | 判据面数量 | 17/17 rc=0 | `DEFAULT_IDS` = T05 T06 T11 T13 T17 T19 T20 T22 T24 T26 T27 T29 T-FIX-01 T-FIX-02 T-FIX-03 T-FIX-04 T-FIX-05 = **17 条** | ✅ | `reproduce-5-test.sh` DEFAULT_IDS 行实测 = 17 条；§O-1 `:1667` 逐条抽取行数 + rc 全 0。 |
| N4 | 门禁数量 | 7/7 rc=0 | bats/make check/check-path-privacy/check-gate-sync/check-dist/check-nfr-portability/package-flow-kit = 7 项 | ✅ | §O-2 `:1689-1701`：7 项门禁逐条 rc=0。 |
| N5 | NFR 计时 | 2.985–3.032s · 均值 3.011 = 预算 60.2% | 5 次 real = 2.985/3.005/3.012/3.019/3.032 · 均值 = (2.985+3.005+3.012+3.019+3.032)/5 = 3.011s · 3.011/5 = 60.2% | ✅ | §O-2 `:1697-1701` 原始计时行；算术复算 (15.053/5) = 3.0106 ≈ 3.011 ✓；60.2% ✓。loadavg=7.64/7.86/7.83 · nproc=32。 |
| N6 | 阶段门沙箱六态 | 六态全绿（A=2 · B=0 · B2/B3/B4=2 · C=0） | D-8-4 stdout 全文：对照0放行✓ · A拒绝且HEAD不变✓ · B放行且commit生效✓ · B2/B3/B4一律rc=2✓ · C无.flow-active放行rc=0✓ | ✅ | §O-4 `:1754` + D-8-4 `TEST.md` 全文。`TD-059` 闭合（B2/B3/B4 从 rc=0→rc=2）。 |
| N7 | check-path-privacy.sh 行数 | 392 → 548（T-FIX-03） | `7dd4bd7` = 392 · `6e39cfb` = 548 · current = 548 | ✅ | 活体 `git show 7dd4bd7:…check-path-privacy.sh \| wc -l` = 392；`6e39cfb` = 548；当前 = 548。 |
| N8 | Makefile wrapper/internals 行数（D-8-3） | wrapper_recipe_lines=13 · internals_recipe_lines=79 | `awk '/^check-nfr-portability:/,/^$/' Makefile \| wc -l` = 13 · `awk '/^check-nfr-portability-internals:/,/^$/' Makefile \| wc -l` = 79 | ✅ | 活体复算与 D-8-3 stdout（§O-3 `:1748`）完全一致。`<verify>` 脚本可复现。 |

**基线演进链算术复算**：976 + 25（T-FIX-01）+ 11（T-FIX-02）+ 11（T-FIX-03）+ 2（T-FIX-04）+ 0（T-FIX-05）= 976 + 49 = 1025 ✓。链自洽。

---

### C. AC 判定是否被夸大核对

| AC | 声明判定 | 夸大？ | 核对结论 |
|---|---|---|---|
| AC-1 | ✅ | 否 | T05 判据 rc=0 + 9 常设 bats（T-FIX-01 闭合 TD-053）。eval-echo 面归零。证据充分。 |
| AC-2 | ✅ | 否 | T06 判据 rc=0 + 17 bats。缺 jq 分支 fail-closed。 |
| AC-3 | ✅ | 否 | T11/T17/T19 判据 rc=0 + 27 bats。四形态 push 拦截端到端。 |
| AC-4 | ✅ | 否 | T13 判据 rc=0 + 7 bats（T-FIX-04 加严 F6/F7）。双态证据（健康态 rc=0 / 注入漂移 rc≠0 指名）。 |
| AC-5 | ✅ | 否 | T24/T27 判据 rc=0 + `make check-dist`。chisel 计数 0。 |
| AC-6 | ✅ | 否 | T20/T22/T23/T25/T26 判据 rc=0 + 20 bats（T-FIX-03 加严 F1/F2 闭合 TD-064）。探针注入 rc=1 指名 file:line。**第 7 次执行升级**：机械故障面（坏 TMPDIR / 非 git 目录 / index 空 git 仓）亦 fail-closed。判定力证据由「change 期判据」升级为「常设双态 bats（20 例含机械故障面与 0 候选面）」—— 升级有据，非夸大。 |
| AC-7 | ✅ | 否 | T15/T17 判据 rc=0 + 4 假绿文件各含注入型用例（注入失败源 ⇒ 必红）。 |
| AC-8 | ⚠️ 有条件通过（仅静态面） | 否 | **四处口径一致不读作全通过**：§1.1 change 期列 = ⚠️ · §1.1 长期列 = ⚠️ · §0 第 7 次执行行 = ⚠️ · §4.4 表内 ✅ 仅限静态判据（注明「不含 macOS 实机」）。macOS 实机未验证 = `TD-055`（仍开放）。§1.1 覆盖判定（`:56`）显式声明「判据 17/17 rc=0 · 门禁 7/7 rc=0 ≠ 8/8 AC 全部通过」。 |

**AC 判定结论**：无任何 AC 被夸大。AC-8 的 ⚠️ 有条件通过口径在四处一致，未读作全通过。AC-6 的第 7 次执行升级有常设双态 bats（20 例）实证支撑。

---

### D. fix 循环闭合可复算性核对

| fix 任务 | commit | 声明闭合 | 实测闭合 | 可复算？ |
|---|---|---|---|---|
| T-FIX-03 | `6e39cfb` | F1 机械故障 fail-open + F2 扫描面塌陷 0 候选同形 → `TD-064` 闭合 | ✅ `check-path-privacy.sh` 392→548 行（+156）；`test_path_privacy_gate.bats` 9→20 @test（+11：F1 坏态/好态 · F2 坏态①②/好态 · F3/F4/F5 坏态/好态）；`mktemp_checked()` 在 `:106-113` 失败即 exit 1；候选面 N=0 ⇒ fail-closed（`:300-303`）。D-8-3 stdout：`A=1 B=0 D=1 E=1 E2=1 F=1 traps=1` · `bats: 1025 ok / 0 not-ok`。 | ✅ `<verify>` rc=0（§O-3 `:1748`）；活性重放还原旧件恰转红。 |
| T-FIX-04 | `521b21c` | F6/F7 check-gate-sync 缺对不得报全绿 → 闭合 | ✅ `check-gate-sync.sh`：`ERRORS` 在 `:69/:76/:141/:193` 递增；`:64` 注释「覆盖度分母用实际比对对数」；`:221` ERRORS>0 时不打印 ✅。`test_check_gate_sync.bats` 5→7 @test（+2：F6 坏态/好态）。D-8-3 stdout：`real=21 full_fixture=0 missing_pair=1`。 | ✅ `<verify>` rc=0；夹具经 `TD-065` 修复脱钩。 |
| T-FIX-05 | `6e94d60` | F8 Makefile NFR 判据正文去重 → 闭合 | ✅ `Makefile` wrapper 89→13 行（awk 范围法）；internals 79 行不变；wrapper 仅保留薄壳（mktemp → export NFR_RC_FILE → `bash -c 'make … check-nfr-portability-internals'` → 三态映射 0/3/1）。`<verify>` 断言 WRAP<30（13<30 PASS）+ INNER>=40（79>=40 PASS）。D-8-3 stdout：`wrapper_recipe_lines=13 internals_recipe_lines=79`。 | ✅ `<verify>` rc=0（§O-3 `:1748`）；bats 7 例全绿（零行为变更）。 |

**阶段 6 审查 2 🔴 / 6 🟡 结案核对**：
- 🔴 F1（机械故障 fail-open）→ T-FIX-03 闭合 ✓（`TD-064`）
- 🔴 F2（扫描面塌陷 0 候选同形）→ T-FIX-03 闭合 ✓（`TD-064`）
- 🟡 F3/F4/F5 → T-FIX-03 一并闭合 ✓
- 🟡 F6/F7（check-gate-sync 缺对不得报全绿）→ T-FIX-04 闭合 ✓
- 🟡 F8（Makefile 判据正文复制两遍）→ T-FIX-05 闭合 ✓
- 🟡 TD-065（判据夹具样本脱钩）→ T-FIX-04 verify 闭合 ✓

**fix 循环闭合结论**：阶段 6 的 2 🔴 / 6 🟡 全部结案，每条均有 commit sha + `<verify>` rc=0 证据，闭合链可复算。

---

### E. L-031 跨阶段必查（fix 提交改的文件 vs 声明）

| fix 提交 | git diff-tree 实际改的文件 | TASK.md/TEST.md 声明 | 类别 | 结论 |
|---|---|---|---|---|
| T-FIX-03 (`6e39cfb`) | `.specs/CONTEXT.md` · `.specs/STATE.md` · `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` · `flow-kit-bundle/test/test_path_privacy_gate.bats` · `test/test_path_privacy_gate.bats`（5 文件） | TASK.md T-FIX-03 `<write_files>` 列出 check-path-privacy.sh + test_path_privacy_gate.bats × 2 | class 1（列且改） | ✅ 一致 |
| T-FIX-04 (`521b21c`) | `.specs/CONTEXT.md` · `.specs/STATE.md` · `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` · `flow-kit-bundle/test/test_check_gate_sync.bats` · `test/test_check_gate_sync.bats`（5 文件） | TASK.md T-FIX-04 `<write_files>` 列出 check-gate-sync.sh + test_check_gate_sync.bats × 2 | class 1 | ✅ 一致 |
| T-FIX-05 (`6e94d60`) | `Makefile` · `flow-kit-bundle/test/test_nfr_portability_gate.bats` · `test/test_nfr_portability_gate.bats`（3 文件） | TASK.md T-FIX-05 `<write_files>` 列出 Makefile + test_nfr_portability_gate.bats × 2 | class 1 | ✅ 一致 |

**L-031 结论**：3 个 fix 提交的改动文件与 TASK.md 声明完全一致，无 class 4（漏列且未改）差异。`.specs/CONTEXT.md` / `.specs/STATE.md` 为流程账本文件，属预期伴随改动。产品面总计（base..HEAD 排除 .specs）= 37 文件。

---

### F. 发现清单

#### F-1 🟡 Important — T-FIX-05「净 −42 行」数字不可复算

- **定位**：`TEST.md:29`（§0 第 7 次执行行）· `TEST.md:520`（§阶段 5 发现 #38）
- **现象**：两处均称 T-FIX-05「wrapper 88 → 13 行 · **净 −42 行**」。
- **复算**：
  - awk/sed 范围法（target 行 → 首空行）：`7dd4bd7` = **89** · current = **13** ⇒ delta = **−76**
  - numstat（整个 Makefile）：`−77/+9` = 净 **−68**
  - 配方行计数（仅 `\t` 开头）：`7dd4bd7` = 87 · current = 11 ⇒ delta = **−76**
  - **无任何计数法得出 −42**：88→13 = −75；89→13 = −76；−68（numstat 净）。
- **内部不一致**：`TEST.md:520` 同一句内先写「`:247` 起 **89** 行 wrapper」再写「wrapper **88** → 13 行」（89 vs 88 自相矛盾）。
- **影响评估**：F8 修复本身**真实且已验证**（wrapper 89/88→13 薄壳 · internals 79 不变 · `<verify>` rc=0 · bats 7 例全绿 · D-8-3 stdout `wrapper_recipe_lines=13 internals_recipe_lines=79`）。「净 −42」为叙述层算术错误，**非 AC 夸大、非 fix 循环未闭合**。原始回执（§O-3 `:1748`）不含「−42」，仅输出 `wrapper_recipe_lines=13 internals_recipe_lines=79`——故该数字无法从回执复现。
- **一句话结论**：T-FIX-05 的 wrapper 行数变化叙述为「净 −42 行」，但无论用 awk 范围法（−76）、numstat 净值（−68）还是配方行计数（−76）均无法复算出 −42，且同句内 89/88 自相矛盾；修复本身真实可复算，此为数字自洽性缺陷。

#### F-2 🟢 Minor — AC-8 ⚠️ 口径与 TD-055 开放状态在报告中未集中收口

- **定位**：`TEST.md:54`（AC-8 矩阵行）· `TEST.md:56`（覆盖判定）· `TEST.md:394`（§4.4）
- **现象**：AC-8 的 ⚠️ 有条件通过（仅静态面 · macOS 实机未验证 · `TD-055` 仍开放）在四处口径一致（未夸大），但「仍开放」的 `TD-055` 缺一条集中收口声明（如「本 change v1 范围内不闭合 · 交 v2 实机验证」的显式裁决行）。
- **影响评估**：不阻塞 release（AC-8 已明确判为 ⚠️ 部分通过 · 不读作全通过 · macOS 实机面属 v2 范围）。前两轮 L2（R1/R2）已登记同类观察，主 agent 已在 §1.1/§0/§4.4 落四处同口径。
- **一句话结论**：AC-8 ⚠️ 口径四处一致未夸大，但 TD-055（macOS 实机未验证）作为仍开放项缺一条集中收口裁决行，属表述类，不阻塞。

---

### G. 开放技术债核对（承前轮）

| TD | 状态 | 本轮核对 |
|---|---|---|
| TD-053 | ✅ 已闭合（T-FIX-01=`5ee4ebc`） | AC-1/AC-6/AC-8 三件常设 bats 网已建（36 例） |
| TD-055 | ⚠️ 仍开放 | macOS 实机未验证（v2 范围） |
| TD-056 | ⚠️ 仍开放 | 安全工具面 0/10（阶段级未覆盖项） |
| TD-059 | ✅ 已闭合（T-FIX-02=`6cff7a2`） | 阶段门 B2/B3/B4 rc=0→rc=2 |
| TD-061 | ⚠️ 仍开放 | 无 kcov/bashcov 行覆盖率 |
| TD-064 | ✅ 已闭合（T-FIX-03=`6e39cfb`） | 隐私门禁 fail-open 收敛 |
| TD-065 | ✅ 已闭合（T-FIX-04 verify） | 判据夹具样本脱钩 |

**技术债占比**：5 条已闭合 / 7 条仍开放 = 5/12 ≈ 41.7%（未达 50% 阈值，但全部仍开放项均有 v2/阶段 7 triage 归口，不阻塞 release）。

---

### H. 独立性受损检查

本轮未发现违规上下文（主 agent 未注入自评 / 草稿 / 概述 / 辩护）。审查过程为只读（除本次追加写入外）。无需在报告第一行标「⚠️ 独立性受损」。

---

### I. 本轮结论

- **checklist**：C1-C6 全部达标（AC 覆盖 · 金字塔 · 覆盖率 · UAT · 回归安全 · 修代码优先）。
- **数字自洽性**：N1-N8 全部自洽（bats 1025 / 有效 1024 · 基线链 976→1025 算术 ✓ · 判据 17/17 · 门禁 7/7 · NFR 3.011s=60.2% · 六态全绿 · check-path-privacy 392→548 · wrapper 13/internals 79）。
- **AC 判定**：无夸大（AC-8 ⚠️ 四处一致不读作全通过 · AC-6 升级有据）。
- **fix 循环闭合**：T-FIX-03/04/05 三件全部可复算（`<verify>` rc=0 · commit sha 可查 · 改动文件与声明一致）。阶段 6 的 2 🔴 / 6 🟡 全部结案。
- **L-031**：3 个 fix 提交无 class 4 差异。

**发现汇总**：🟡 × 1（F-1「净 −42」不可复算）· 🟢 × 1（F-2 TD-055 收口表述）· 🔴 × 0。

**Verdict**: pass

---

## 主 agent 响应（阶段 5 · L2 第 3 轮盲审 · 2026-09-25）

**结论**：L2 第 3 轮 `verdict = pass`（🔴 0 · 🟡 1 · 🟢 1）。两条发现**均在阶段 5 门禁之前处置完毕**，处置后以同一版本送 L3 复审。

### F-1 🟡「`T-FIX-05` 净 −42 行不可复算」 —— `Fixed in: TEST.md`（数字订正）

独立复核（主 agent 亲跑，非采信执行者叙述）：

| 计数法 | 修复前 | 修复后 | Δ |
|---|---|---|---|
| `awk '/^check-nfr-portability:/,/^$/' Makefile \| wc -l`（判据 `<verify>` 同法） | **89** | **13** | −76 |
| `awk '/^check-nfr-portability-internals:/,/^$/' Makefile \| wc -l` | 79 | 79 | 0 |
| `git show --numstat 6e94d60 -- Makefile` | — | `+9/−77` | — |
| 该提交三文件 numstat 合计 | — | `+35/−77` | **净 −42** |

**根因**：原句把**提交级净值（−42 = 三文件 `+35/−77`）**写成了 **wrapper 级变化**，且同句又写 88（实为 89 —— `awk` 范围法含末尾空行）。订正后两处（`TEST.md:29` §0 第 7 次执行行 · `TEST.md:521` 发现 #38）均改为「wrapper 配方 **89 → 13 行**（`awk` 范围法 · Δ−76 · `Makefile` numstat `+9/−77`）· 本提交 3 文件 **+35/−77 ⇒ 净 −42 行**」，与 `<verify>` 输出的 `wrapper_recipe_lines=13 internals_recipe_lines=79` 及 numstat **三源一致**。

### F-2 🟢「`TD-055` 缺集中收口裁决行」 —— `Fixed in: TEST.md`（新增唯一裁决行）

`TEST.md:60` 新增 `> **开放项集中收口（L2 第 3 轮 F-2 响应 · 2026-09-25 · 唯一裁决行）**`：把仍开放的未覆盖/未验证项（`TD-055` / `TD-056` / `TD-061` / `TD-058` / `TD-057` / `TD-060` / `TD-062` / `TD-063` / `TD-065` / `TD-049` / `TD-035`）统一归口 **阶段 7 triage**，并明示其**不改变**「AC-1..AC-7 ✅ 通过 · AC-8 ⚠️ 有条件通过（仅静态面）」的既有口径、**AC-8 的 ⚠️ 不得读作全通过**。

### 采信与分歧

L2 本轮 🔴 为 0，两条发现均属表述层，**未发现任何 AC 夸大或 fix 循环未闭合**。L2 的独立活体复算（bats 1025 / 有效 1024 · 基线链算术 · 判据 17/17 · 门禁 7/7 · NFR 均值 3.011 s = 60.2% · 阶段门六态 · `check-path-privacy.sh` 392 → 548 行）与主 agent 的 REPRO5 回执（`PHASE5-RECEIPTS.md` §O · `TEST.md` §附录 D-8）**逐项吻合**，无分歧项。

**处置后状态**：`TEST.md` **1162 行**，改动仅上述 F-1 / F-2 两处（1 行新增 + 2 处文字订正）⇒ 以该版本送 L3 第 12 轮复审。

## L2 盲审（第 4 轮 · 阶段 5 第 2 轮 fix 循环后复审）

**审查标识**：change-id `health-fix-2026-09b` · 阶段 5（5-test）· 独立 L2 盲审第 4 轮 · 第 2 轮 fix 循环后复审 · 2026-09-25 · 审查员 = 独立子 agent（本机脱敏：仓库根记 `<repo>`，本机探针路径用合成形态描述，绝不写出完整真名形态）。

**审查对象**：主审工件 = `TEST.md`（第 8 次执行 = 第 2 轮 fix 循环后重验 · HEAD `26d5d7b` · 1214 行）。参考工件（只读）= `REQUIREMENT.md`（AC-1..AC-8 原文）· `TASK.md`（29 + 5 条任务判据 + T17 夹具 + T-FIX-06 verify 块）· `PHASE5-RECEIPTS.md`（§P = 第 8 次执行原始回执 · §0 索引）· `REVIEW.md`（阶段 6 第 2 轮深审 · F-18/F-19/F-20 来源）· `MINOR-DEFERRED.md`（已缓释条目）· `INDEPENDENT-REVIEW-5.md`（本阶段历轮 L2/L3 审查档）。

**可读复跑证据路径**：`/tmp/p6b/repro7-run.txt`（第 8 次执行全量日志 · 判据 stdout 落 `/tmp/fk-reproduce-5-r7/out_<ID>.txt`）· `/tmp/p6b/repro6-run.txt`（修复前 · HEAD `2afb0e2` · 2 红：T17 rc=1 / T-FIX-06 rc=2）· `/tmp/p6b/tfix6-verify-rerun.txt`（T-FIX-06 判据独立复跑）。

**改动面**：`git diff 26d5d7b^..26d5d7b`（本轮判据/工具面订正 · 6 文件 +503/-12）· `git diff 421640a^..421640a`（T-FIX-06 生产件修复 · `check-path-privacy.sh` +64 / `test_path_privacy_gate.bats` ×2 +72）。

**独立性声明**：本轮以独立子 agent 身份盲审，仅接受指定工件为唯一输入；未接受主 agent 自评 / 草稿 / 概述 / 辩护，亦未在本轮发现任何此类注入。审查过程仓库只读（未 `git add` / `commit` / `checkout` / `stash`，未运行全量 `make check` / `npx bats test/`）；探针仅写 `/tmp/l2p5r4/`；单条判据复跑用 `bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only --only <ID>`。

---

### A. 阶段 5 checklist 逐项核对

| # | checklist 项 | 核对结论 | 证据定位 |
|---|---|---|---|
| C1 | AC 覆盖（每 AC ≥ 1 测试用例） | ✅ 达标 | `TEST.md` §1.1 AC 矩阵（`:46-56`）：AC-1=T05 · AC-2=T06 · AC-3=T11/T17/T19 · AC-4=T13 · AC-5=T24/T27+check-dist · AC-6=T20/T22/T23/T25/T26+24 bats（T-FIX-06 后） · AC-7=T15/T17+4 假绿文件 · AC-8=T29。8/8 AC 均有覆盖。 |
| C2 | 5 轮金字塔（功能/性能/安全/兼容/可观测） | ✅ 达标 | `TEST.md` §0（`:46-66`）轮次演进表第 8 行列全 5 面；§2.2 NFR 性能面（`:252-271`）；`check-path-privacy.sh` 安全面自证；§1.3 兼容性（bats 3.2/4.4 双环境）；隐私自证行 = 可观测面。 |
| C3 | 功能轮 AC 100% 覆盖 | ✅ 达标 | C1 已核 8/8 AC；本轮无新增 AC 缺口。 |
| C4 | UAT 可脚本化（Given/When/Then） | ✅ 达标 | `reproduce-5-test.sh`（206 行 · 18 判据 `DEFAULT_IDS`）= 可复算 UAT 脚本；`/tmp/p6b/repro7-run.txt` 独立复跑 REPRO7_RC=0。 |
| C5 | 回归无退化 | ✅ 达标 | bats 1029（有效 1028 · 1 TD-033 mock）≥ 第 7 次 1025 ≥ 第 6 次 1023；三件常设 bats 24+9+7=40 全在；NFR 均值 3.077s=61.5% ≤ 5s 预算。 |
| C6 | 修代码优先（主 agent 每条 🔴/🟡 给 Fixed in/Tech-debt/Not-applicable） | ✅ 达标 | `TEST.md` §阶段5发现表（`:496-548`）#41 TD-066 / #42 TD-067 均标 `Fixed in: TASK.md` / `Fixed in: reproduce-5-test.sh`，均标「非生产件回归」，经本轮 git diff 独立核验属实（见 §B-4）。 |

---

### B. 数字面自洽性核对（独立复算）

| # | 数字断言 | 主审来源 | 独立复算 | 一致 |
|---|---|---|---|---|
| N1 | 判据 18/18 rc=0 | `TEST.md` §0 行 8 · D-9-1 · §P-1 | `/tmp/p6b/repro7-run.txt`：T05..T29 + T-FIX-01..06 共 18 条 rc=0；REPRO7_RC=0 | ✅ |
| N2 | 门禁 7/7 rc=0 | `TEST.md` D-9-2 · §P-2 | `/tmp/p6b/repro7-run.txt`：bats/make-check/privacy/NFR/validate/phase-gate 六态全绿 + check-dist；§P-2 列 7 项 | ✅ |
| N3 | bats --count = 1029（有效 1028） | `TEST.md` §1.3（`:111-150`）· D-9-2 | `npx bats --count test/` → 1029；TD-033 mock 1 条 ⇒ 有效 1028 | ✅ |
| N4 | 三件常设 bats = 24+9+7=40 | `TEST.md` §1.3 | `test_path_privacy_gate.bats` 24 @test + `test_runtime_edit_guard.bats` 9 + `test_nfr_portability_gate.bats` 7 = 40 | ✅ |
| N5 | NFR 均值 3.077s = 61.5% | `TEST.md` §2.2 · D-9-2 | 5 次 3.146/3.050/3.051/3.127/3.011 → 均值 3.077s；3.077/5.0=61.5%（python3 核算） | ✅ |
| N6 | validate 期望315/实际321/漏配0/源缺失0 | `TEST.md` D-9-2 · §P-2 | `package-flow-kit.sh --validate` → 期望315/实际321/漏配0/源缺失0 | ✅ |
| N7 | T17 verify 块 = 74 行（TD-066：73→74） | `TEST.md` D-9-1 · §P-1 | `reproduce-5-test.sh --criteria-only --only T17` 抽取 = 74 行（+1 benign README.md 夹具） | ✅ |
| N8 | T-FIX-06 verify 块 = 41 行（TD-067：43→41） | `TEST.md` D-9-1 · §P-1 | 整行锚定抽取 = 41 行；旧内联子串抽取 = 47 行（`<action>` 正文含 `<verify>` 字面量致多 6 行废件）⇒ TD-067 修复属实 | ✅ |
| N9 | `check-path-privacy.sh` = 594 行（T-FIX-06 后） | `TEST.md` 阶段5发现 #34（T-FIX-03：392→548）隐含 T-FIX-06 后增长 | `wc -l` = 594；`git diff 421640a` +64 行（F-19 SCANNED + F-20 mktemp + F-18 措辞） | ✅（注：TEST.md 未显式记 594，但 D-9-1 T-FIX-06 抽取行数隐含生产件已改） |
| N10 | HEAD 26d5d7b 改动面 = 6 文件 +503/-12 | `TEST.md` D-9 前置 | `git diff 26d5d7b^..26d5d7b --stat`：CONTEXT.md/MINOR-DEFERRED.md/REVIEW.md/T-FIX-06-SUMMARY.md/TASK.md/reproduce-5-test.sh，未触生产件 ✓ | ✅ |
| N11 | T-FIX-06 = 421640a 改动面 = 4 文件 +201/-10 | `TEST.md` D-9 前置 | `git diff 421640a^..421640a --stat`：check-path-privacy.sh(+64)/test_path_privacy_gate.bats×2(+72)/STATE.md | ✅ |

---

### C. F-19/F-20 真闭合核验（T-FIX-06 = 421640a）

**F-19（自排除后候选面归零仍报 ✅）**：`check-path-privacy.sh` 在 421640a 新增 `SCANNED_COUNT`（`:376` 初始化、`:490` `scan_file` 前递增、`:496-505` `SCANNED_COUNT==0 && CANDIDATE_COUNT>0` fail-closed rc=1 且不打印 ✅）。自证行（`:566-567`）并列 `候选文件 ${CANDIDATE_COUNT} 个` + `实际扫描 ${SCANNED_COUNT} 个`。`test_path_privacy_gate.bats:318` F19 坏态（tracked 全命中 SELF_EXCLUDE ⇒ rc≠0 且自证含「实际扫描 0 个」且不打印清单外命中 0 条/✅）+ `:331` F19 好态（M≥1 ⇒ rc=0）。**闭合属实。**

**F-20（临时件不可用 ⇒ 机械故障被折成「0 命中」）**：`check-path-privacy.sh` 在 421640a 将 `mktemp_checked()` 内 `exit 1` 改 `return 1`（`:131`），4 个调用点（`:143`/`:144`/`:145`/`:516`）加 `|| exit 1`。`test_path_privacy_gate.bats:355` F20 坏态（TMPDIR 不可用 ⇒ rc≠0 且「mktemp 失败」报文恰 1 次）+ `:369` F20 好态（正常 TMPDIR ⇒ 无 mktemp 失败报文且 rc=0）。**闭合属实。**

**F-18（SCAN_SURFACE 措辞精确化 · 用户裁决 option ② 仅措辞零行为变更）**：`check-path-privacy.sh` `SCAN_SURFACE='工作树'` → `'工作树（git index：已 add / 已提交）'`（`:140`）。`test_path_privacy_gate.bats:238` 注释引证 F18 措辞精确化。**闭合属实（措辞面）。**

---

### D. TD-066/TD-067 诚实度核验

**TD-066（#41 · T17 CHECK_REV 对照夹具候选面全自排除）**：`git diff 26d5d7b` 显示 T17 `<verify>` 块在 `TASK.md` 内补 1 个 benign `README.md` 夹具文件 ⇒ tracked 不再全属 SELF_EXCLUDE ⇒ 候选 N≥1 / 实际扫描 M≥1 ⇒ T-FIX-06 fail-closed 不再误红。**判据面修复（TASK.md），非生产件回归。** 诚实度属实。

**TD-067（#42 · 抽取器未整行锚定）**：`git diff 26d5d7b` 显示 `reproduce-5-test.sh` `extract_verify()` 由内联子串匹配改为整行锚定（`:63-71`）。旧法在 T-FIX-06 `<action>` 正文（含 `<verify>` 字面量）处提前起抽 ⇒ 43 行废件 + 解析错误；新法整行锚定 ⇒ 41 行正确抽取。**工具面修复（reproduce-5-test.sh），非生产件回归。** 诚实度属实。

**修复前对照**：`/tmp/p6b/repro6-run.txt`（HEAD `2afb0e2`）确认 2 红：T17 rc=1（73 行 · 「🔴 工作树模式在干净树上未 rc=0」）+ T-FIX-06 rc=2（43 行废件 · 「未找到命令」/「</action>」解析错误）。`/tmp/p6b/repro7-run.txt`（HEAD `26d5d7b`）确认 18/18 绿。修复真实。

---

### E. AC 判定核验

AC-1..AC-7 = 通过（7 项）；AC-8 = ⚠️ 条件通过（仅静态面 · TD-055 macOS `open` 未实机验证）。`TEST.md` §1.1（`:46-56`）· §0 第 8 行 · §4.4 四处交叉引用均一致表述「7 通过 + AC-8 条件通过仅静态面」，**未将 AC-8 读成全通过**。执行面（18 判据 + 7 门禁）全绿 ≠ AC 全通过 —— 此区分在主审工件中保持准确，无夸大。

---

### F. 独立发现（4 要素 + severity）

### 🟢 R1 · 隐私自证回执与生产件不自洽：§P-3c 漏列 F-19 三行自证
**Severity**: 🟢 Minor
**Symptom**: `PHASE5-RECEIPTS.md` §P-3c（第 8 次执行回执 · `== [C] check-path-privacy 自证面 ==`）打印隐私自证 5 行：`扫描面` / `允许清单来源` / `命中合计 0 条` / `清单外命中 0 条` / `✅ 清单外命中 0 条`。但生产件 `check-path-privacy.sh:562-569`（commit `421640a`，HEAD `26d5d7b` 时未再改）在 happy path 打印 **7 行**，多出 `允许清单 ${ALLOWLIST_COUNT} 条`（`:565`）、`候选文件 ${CANDIDATE_COUNT} 个`（`:566`）、`实际扫描 ${SCANNED_COUNT} 个`（`:567`）。§P-3c 的 F-18 措辞（`工作树（git index：已 add / 已提交）`）在场，但 F-19 的三行自证缺席 —— 两者同属 commit `421640a`，回执不应割裂。`/tmp/p6b/repro7-run.txt` 同样只显示 5 行。
**Source**: 阶段 5 checklist C4（UAT 可脚本化 · 回执须忠实复现生产件输出）+ C5（回归无退化 · 回执须可独立复核）。`TEST.md` §1.1 AC-6 行（`:55`）与 §阶段5发现 #41 声称 T-FIX-06 已加「失败面自证（候选 N / 实际扫描 M / 自排除 N−M）」，但回执未展示该三数 ⇒ 回执与主审断言不自洽。
**Consequence**: 不影响生产件（`check-path-privacy.sh` 自证行正确，`make check-path-privacy` 实跑打印 7 行含 `候选文件 N 个` + `实际扫描 M 个`）。但回执失真 ⇒ 后续审查者无法据回执独立复核 F-19 闭合，须重跑生产件才能确认；回执作为「可复算证据」的可信度下降。长期：若主 agent 习惯性裁剪回执，未来 F-19 类 fail-closed 退化可能在回执层被掩盖。
**Remedy**: 重跑 `make check-path-privacy` 并将完整 7 行自证（含 `允许清单 N 条` + `候选文件 N 个` + `实际扫描 M 个`）原样贴回 §P-3c，替换现有 5 行截断版；同时在 §P-3c 标注「原始 stdout 见 `/tmp/fk-reproduce-5-r7/privacy.txt`」。或在 §P-3c 加一行说明「N/M 两行因 CANDIDATE_COUNT/SCANNED_COUNT 在该次运行的实际值见 §P-6 原文」。属 🟢 Minor，不进 fix 循环，建议记入 `MINOR-DEFERRED.md`。

---

### G. 阶段 5 checklist 总判定

- AC 覆盖 8/8（AC-8 条件通过仅静态面 · 准确表述）✅
- 5 轮金字塔全在 ✅
- 功能轮 AC 100% 覆盖 ✅
- UAT 可脚本化（`reproduce-5-test.sh` · REPRO7_RC=0）✅
- 回归无退化（1029 ≥ 1025 ≥ 1023 · NFR 61.5%）✅
- 修代码优先（#41/#42 均 Fixed in + 非生产件回归标签 · 经 git diff 核验属实）✅
- F-19/F-20/F-18 真闭合（生产件 + 24 bats 双态）✅
- TD-066/TD-067 诚实（判据/工具面 · 非生产回归）✅
- 数字面 18/18 · 7/7 · 1029 · 3.077s · 315/321 全自洽 ✅
- 唯一缺口：§P-3c 回执漏列 F-19 三行自证（🟢 Minor · 回执层 · 非生产件）

**Verdict**: pass


---

## 主 agent 响应（阶段 5 · L2 第 4 轮盲审 · 2026-09-25）

**Verdict 接受：`pass`。** 唯一发现 🟢 R1（回执 `§P-3c` 漏印 F-19 三行自证）**主 agent 坐实并当场订正**；根因比 R1 的描述更靠前一层，属**证据/工具面**缺陷而非「回执贴错」：

1. **坐实根因**：`reproduce-5-test.sh:145` 的显示正则为 `grep -E '扫描面|允许清单来源|命中合计|清单外命中'` —— 只列 4 类字段 ⇒ 门禁面 `[C]` 段**永远**只印 5 行，把 `T-FIX-06` 新增的 `允许清单 N 条` / `候选文件 N 个` / `实际扫描 M 个` 三行裁掉（与 TD-065 / TD-067 同族：**证据与工具面不得裁剪被审输出**）。
2. **原始证据完好**：`/tmp/fk-reproduce-5-r7/privacy.txt`（553 B · 第 8 次执行当次产生 · `[D]` 的 5 次计时把 stdout 丢 `/dev/null`，不覆写该文件）含完整 7 行 —— `允许清单 0 条` / `候选文件 1595 个` / `实际扫描 1589 个` 在场。`§P-3c` 已按该文件**全文重贴**并标注原始路径与产生时点，附 `TD-068` 订正说明。
3. **处置（不改判据、不改生产件 ⇒ 不进 fix 循环）**：
   - ① 复现器显示正则补入 3 字段（`:145`）——**显示面 · 不改 rc 与判定面**（`privacy.txt` 与 `emit_gate` 的 rc 串均不受影响），并同步头部第 8 次执行注记；
   - ② 登记 **`TD-068`**（`.specs/CONTEXT.md:615` · 与 TD-065 / TD-067 同族）；
   - ③ 连带订正同一根因的**描述面残留**：`TEST.md:418` 「自证行四要素」→「七要素」（并补 `扫描面: 工作树（git index：已 add / 已提交）` 的现行措辞）· `TEST.md:119` 一处陈旧计数 `1025` → `1029`（行数不变 · 无行号漂移）；
   - ④ R1 与 `TD-068` 写入 `MINOR-DEFERRED.md`（本节下方同轮记录）。
4. **对 L2 结论面有无影响**：无。订正均落在外层证据链（回执贴文 / 复现器显示过滤 / 报告描述），`TEST.md` 的判定面数字（18/18 · 7/7 · 1029/1028 · NFR 3.077 = 61.5% · validate 315/321）与 `REPRO7_RC=0` 未变；订正后 `bash -n` 复检通过。

**L3 处置**：L2 第 4 轮 = `pass` ⇒ 按门禁顺序进入 **L3 第 13 轮**（外部模型复审第 8 次执行证据面 + 判据哈希）。

---

## 主 agent 响应（阶段 5 · L3 第 13 轮 · 2026-09-25）

**L3 第 13 轮 = pass**（判定体 `"critical":[]`）。三条 major / 三条 minor **全部命中本 change 已登记并留待阶段 7 闭环的既有技术债**，无新增发现：

| L3 判定 | 既有登记 | 处置 |
| --- | --- | --- |
| major 1 = 行/分支覆盖率无任何数据 | `TD-061`（`.specs/CONTEXT.md`） | 已登记 · 阶段 7 triage |
| major 2 = 独立安全工具面 0/10 | `TD-056` | 已登记 · 阶段 7 triage |
| major 3 = macOS 实机未验证（AC-8 仅静态面） | `TD-055` | 已登记 · 阶段 7 triage |
| minor 1 = 1 条 mock 用例（有效 1028 / 收集 1029） | `TD-033` | 已登记 |
| minor 2 = 无 CI 常设触发 | `TD-053` 家族 | 已登记 |
| minor 3 = 判据/工具在测试执行期内被修改 | `TD-066` / `TD-067`（同轮内**已披露**：`TASK.md` T17 夹具订正 + 抽取器整行锚定 + `TEST.md` 附录 D-9） | 已登记 |

**信封字节账**：`完整 303899 B → 实送 299999 B（丢弃 1%）`。丢弃的是**尾部** = `=== T-FIX-05-SUMMARY.md ===` 段末约 900 B + 整段 `=== T-FIX-06-SUMMARY.md ===`（补充产物各 3000 B 预算叠加后超出总量上限）；**主审面 `TEST.md`（181036 B）完整送达**，`T01…T29` / `T-FIX-01…04` 摘要亦完整 ⇒ 判定面不受影响。上限来源 = 主 agent 侧 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES=300000`（工具默认 80000）。

**提高上限重审被守卫跳过**：`bash /tmp/p6b/l3-run-14.sh pass`（上限 400000）⇒ `[l3-review] skipping L3 for phase 5 (artifact hash 不变 + ## L3 段非空)`。**不为此改动 `TEST.md`** —— 为过审而人为改工件哈希等于制造「倒因为果」的伪证据；改为在工件内如实披露（本节 + `PHASE5-RECEIPTS.md` §Q）+ 登记 **`TD-069`**（上限提升不能触发重审 · 截断仅 stderr 告警 · 无补救路径）。

**握手件核验**：`.specs/health-fix-2026-09b/.independent-review-5.done` = 7 行 / 379 B（`phase=5` · `change_id=health-fix-2026-09b` · `written_by=pre-tool-use-gate` · `L2_verdict=pass` · `L3_verdict=pass` · `L3_summary=…` · `artifacts=TEST.md,TASK.md,REQUIREMENT.md,INDEPENDENT-REVIEW-5.md`）⇒ Tier-1 ✅（≥6 行 · 6 键齐 · 值域合法 · `artifacts` 含逗号）；Tier-2 ✅（`fk_extract_l2_verdict` 在**L2 层**取最后一次 `Verdict:` = 第 4 轮 `pass`，与标记一致 ⇒ 门禁判「门已开**且有效**」）。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-25 04:40）

> 自动生成于 2026-09-25 04:40。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"TEST.md §1.3 / §回归保护 / TD-061","issue":"行/分支覆盖率没有任何数据：工件明确写“本机无 kcov/bashcov ⇒ 行覆盖率 / 分支覆盖率无任何数据”，并以“AC 覆盖数 + bats 收集数”替代；TD-061 仍开放。","why":"覆盖率是否达标无法从工件验证；报告自己也承认不是 0% 而是“无测量工具”。在验收要求关注覆盖率时，这属于未验证项，不能作为覆盖达标证据。","fix":"安装并接线 kcov/bashcov，实跑并附行/分支覆盖率原始回执；或在需求/验收文件中明确 bash/bats 项目不要求行覆盖率，并给出可复算的等价覆盖门槛。"},{"file":"TEST.md §3.4 / §3.5 / TD-056","issue":"独立安全工具面 0/10：semgrep、gitleaks、trufflehog、trivy、codeql 均 MISSING，npm audit 因 ENOLOCK 不可用；工件声明“第 3 轮安全实现面 = 未验证（无独立安全工具），不构成 AC 通过面证据”。","why":"工具级安全扫描完全缺失，OWASP/依赖/秘钥等安全面只能依赖 grep、shellcheck 和自研门禁的“替代面”，无法证明无独立安全工具可发现的问题。","fix":"在具备工具的环境补跑 gitleaks/semgrep/trivy/codeql 与 npm audit（先引入 lockfile），附原始输出；或将该安全工具验收面正式移出本 change 范围并由需求方/阶段 7 裁决。"},{"file":"TEST.md §1.1 / §4.4 / TD-055","issue":"AC-8 的 macOS 实机兼容性未验证：只有 Linux 静态判据 make check-nfr-portability，工件将 AC-8 判定为“有条件通过（仅静态面）”，TD-055 仍开放。","why":"bash 3.2/macOS 的 locale、iconv、内建命令差异无法仅靠静态判据证明；跨 OS 兼容性验收缺少实机证据，不能读作 AC-8 全通过。","fix":"在 macOS 实机或 runner 上运行 make check、npx bats、check-nfr-portability 并附 TAP/回执；若本 change 不覆盖，需显式将 AC-8 拆为“Linux 通过 + macOS 未验收”并交由阶段 7 闭环。"}],"minor":[{"file":"TEST.md §1.3 / §1.5 / TD-033","issue":"仍存在 1 条 mock 用例：test_gate_config_presets.bats 自陈模拟 resolve_gate_config()，从不 source 生产实现；报告因此将有效用例计为 1028 而非 1029。","why":"该 mock 若被后续作为 gate_config 语义回归证据会掩盖真实实现变化；当前报告已将其排除出 AC 结论面，风险可控但债仍在。","fix":"将 mock 重写为 source 真实生产实现的回归用例，并重新确认 AC-4 证据面。"},{"file":"TEST.md §回归保护 / §0","issue":"无 CI：所有门禁与 bats 均为本机手工/脚本执行，常设回归保护没有服务器端自动触发。","why":"本机执行结果可重复性强，但缺少 CI 后“提交即跑”的长期保护，未来变更可能绕过门禁。","fix":"增加 CI workflow，至少运行 make check 与 reproduce-5-test.sh，并保留原始日志作为验收证据。"},{"file":"TEST.md §1.7 / 附录 D-9","issue":"最终 18/18 rc=0 是在第 8 次执行中修正 T17 夹具（TD-066）与抽取器（TD-067）之后取得的；判据/工具在测试执行期间有修改。","why":"修改判据或工具后再复跑全绿，存在“测到绿”而非“产品绿”的外部核验风险；工件已披露，但独立复核仍需要原始红因输出。","fix":"将 TD-066/TD-067 修改前的红态 stdout 与产品缺陷归因完整附入可见工件，并保留冻结判据版本的整轮复跑记录供复核。"}],"verdict":"pass","summary":"测试矩阵、UAT 可复现性与回归测试面较扎实，但覆盖率无数据、安全工具面 0/10、macOS 实机未验证仍是开放 major，须交阶段 7 闭环；无 critical，故判 pass。"}
```

L3_artifact_hash: 0db9f23df9c9be71044e954a88568cceb35ed87e585871841f2f278551d2819a

<!-- /L3-SECTION -->
