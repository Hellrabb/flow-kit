# 独立审查 · 阶段 3

---

## L2 盲审

> **审查参数**：变更 `health-fix-2026-09b` · 阶段 3（3-task）· 轮次 1 · 受审工件 `TASK.md`（全文必读）· 参考 `REQUIREMENT.md` / `DESIGN.md` / `CHANGE.md` / `MINOR-DEFERRED.md`（只读按需取用）。
>
> **独立性声明**：本审查仅依据指定工件裁决，默认质疑主 agent 结论；不臆测作者意图；证据优于解释。未在 `TASK.md` 中检测到主 agent 自评 / 草稿 / 概述 / 辩护注入 —— `TASK.md` 作为受审工件本身（非主 agent 响应段），其自检区（§自检 7 项 / §状态字段）属工件固有组成，不计为上下文注入。
>
> **裁决方法**：对 `TASK.md` 全 29 条（T01–T29）逐条核对 7 字段（name/action/read_files/write_files/depends_on/parallel/verify），并对 `DESIGN §0.5.1` 触碰模块清单做 L-031 跨阶段 grep 锚点全仓复扫（不信任 DESIGN 列表），核验「DESIGN-listed-and-will-change」/「DESIGN-listed-new」/「DESIGN-missing-and-unchanged（🔴 漏改）」三态。

### 🟡 R1 · write_files 开放式条目：T13 item ④「其余复扫命中的 tracked 文件」非逐条枚举

**Severity**：🟡 Important（fix loop · task-internal）

**Symptom（症状）**：`TASK.md:455`（T13 write_files）第 ④ 项为 `<其余复扫命中的 tracked 文本（以复扫输出为准，逐文件就地脱敏）>` —— 这是一个**开放式 / 非枚举**的 write_files 条目，其确切落点在 task 定稿时未知，依赖 4-dev 实跑复扫输出才能确定。Phase-3 checklist 的「write_files 约束到位」要求逐条精确路径，而非"以复扫输出为准"的延后枚举。

**Source（源头）**：固化指令 Phase-3 checklist「read_files/write_files 约束到位」+ `DESIGN.md:248` D10′③「git add 全部未 tracked 扫描恒 0」要求脱敏在冻结前闭合，但未要求 write_files 本身闭合 —— 二者标准不同。`MINOR-DEFERRED.md` G1 条同款"行号漂移 / 悬空自指"失效原始证据问题。`TASK.md:1086` 自检项 3「无禁动清单文件」✅，但自检项 2「write_files 在 §0.5.1 范围」对 item ④ 的开放性未作判定。

**Consequence（后果）**：4-dev 执行时，T13 的实际 write 面由复扫输出动态决定 —— 若复扫命中 `unisoc` 88 行/34 文件存量（`DESIGN.md:429` §9.1 明示须先处理否则首跑大面积命中），或命中其他未预料的 tracked 文本，write_files 范围将超出 §0.5.1 触碰清单的静态边界。这使「禁动清单」校验在 T13 上**不可静态完成**，只能靠 4-dev 实跑后回溯。若复扫命中 `flow-kit-bundle/skills/**` 或 `INDEPENDENT-REVIEW-*.md`（禁动），item ④ 的开放性将掩盖越界写入。

**Remedy（修补）**：
- before：`<其余复扫命中的 tracked 文本（以复扫输出为准，逐文件就地脱敏）>`
- after：改为封闭式枚举 + 失败兜底 —— `④ 若复扫命中 §0.5.1 触碰清单外的 tracked 文件 ⇒ 停止并升级为新 task（不得在 T13 内就地脱敏禁动清单文件）；T13 的 write_files 范围 = ① ② ③ 三条精确路径 + 「复扫命中且属 §0.5.1 触碰清单内 tracked 文件」的动态子集（每次就地脱敏须在 4-dev 日志留命中 file:line + 脱敏前后对照）`。并在 verify 段补一条：`git ls-files -z | xargs -0 grep -nE "$PAT" | grep -vE 'INDEPENDENT-REVIEW-[0-9]+\.md' | grep -vE '/home/(user|ubuntu|…)/' | grep -vE '^\S+:(skills/|brooks-lint/|hooks/stop/|pipeline-gates\.md)' | wc -l` —— 即显式排除禁动清单路径，确保任何禁动文件命中即被 verify 拦截。

### 🟢 R2 · T29 收口 task verify 粒度偏重：单 task 承载全量门禁 + bats + 三道副本一致性

**Severity**：🟢 Minor（naming/style · 不入 fix loop · 登记入 MINOR-DEFERRED.md）

**Symptom（症状）**：`TASK.md:987`（T29）`parallel="false"` serial 收口，`depends_on` 含 T19,T20,T22,T23,T25,T26,T27,T28 共 8 条；verify 段同时断言：① `make check` 全绿 ② `npx bats test/` ≥973 ok / 0 not ok ③ 三道副本一致性 0 漂移 ④ 变更集非空守卫（`.change-base` 锚点）。单 task verify 负载显著高于其余 28 条。

**Source（源头）**：`REQUIREMENT.md` AC-8「无退化」Given/When/Then 本身即全量门禁断言；`CHANGE.md` 验收线第 6 条 P6 粗粒度化。固化指令 Phase-3 checklist「task 粒度 ≤200 lines / wave clear」未规定单 task verify 段行数上限。

**Consequence（后果）**：T29 作为收口 task 承载全量回归，粒度偏重但属 AC-8 性质使然 —— 拆分会割裂「无退化」的整体语义。无数据完整性 / 安全 / AC 未实现风险。verify 可机器执行（`make check` / `npx bats` / `diff` 均可跑）。

**Remedy（修补）**：无需 fix loop。建议在 `MINOR-DEFERRED.md` 登记一条：T29 verify 段可考虑拆为 T29a（make check 全绿 + 三道副本一致性）与 T29b（bats ≥973 + 变更集非空守卫）两条 serial 子 task，以降低单 verify 失败时的定位成本。当前不拆不影响通过性。

### L-031 跨阶段 grep 锚点全仓复扫结论

| # | 锚点 | DESIGN 列表状态 | 实际仓库状态（本审查实测） | 裁决 |
|---|------|----------------|--------------------------|------|
| 1 | `eval echo` RCE（PC1） | `runtime-edit-guard.sh:46` 列为 PC1 触碰 | `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh:46` 命中 1 处 `real_path=$(eval echo "$file_path" 2>/dev/null)` | ✅ DESIGN-listed-and-T05-will-change |
| 2 | `check-path-privacy`（AC-6 门禁） | DESIGN §0.5.1 / §9.1 列为新增产物 | 实际 `Makefile` / `flow-kit-bundle/flow-kit/reference/` 0 命中（不存在） | ✅ DESIGN-listed-new · pre-dev 正确 |
| 3 | `check-gate-sync`（AR2） | `check-gate-sync.sh` 159L 列为 AR2 触碰 | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:3` 存在；`Makefile:16` 仅注释命中（非先决条件） | ✅ DESIGN-listed-and-T08/T14-will-change |
| 4 | `deploy_pre_push`（AC-3c） | DESIGN D3 列为 `install_hooks.sh` 新增函数 | `flow-kit-bundle/lib/install_hooks.sh` 0 命中（不存在） | ✅ DESIGN-listed-new · T16-will-create |
| 5 | `pre-push` 注册（sync-hooks.sh 四处） | DESIGN D3 列 `sync-hooks.sh` :79/:95/:97/:110/:283+:289 四处登记 | `sync-hooks.sh` `grep -cE 'pre-push'` = 0（entry-class 白名单 :97 仅 `stop/·session-start/·pre-commit/·pre-tool-use/`） | ✅ DESIGN-listed-and-T12-will-change |
| 6 | `chisel`（AC-5） | DESIGN D9 列 `test/` + `flow-kit-bundle/test/` 双源 | 命中 `test/test_correction_hygiene.bats` + `test/test_l3_review_defects_2026_09.bats` + 双源镜像 = 4 文件 12 行 | ✅ DESIGN-listed-and-T07-will-change |
| 7 | `-ne 2`（AC-4 断言） | DESIGN D5 列 `test_check_gate_sync.bats:30` | `test/test_check_gate_sync.bats:30` + `flow-kit-bundle/test/test_check_gate_sync.bats:30` 均命中 `[ "$status" -ne 2 ]` | ✅ DESIGN-listed-and-T15-will-change |
| 8 | `skip`（AC-7b lessons_cleanup） | DESIGN 列 `test_lessons_cleanup.bats` 去 skip | `test/test_lessons_cleanup.bats:137` 命中 `skip "AC-4 需要全量覆盖环境…"` | ✅ DESIGN-listed-and-T10-will-change |
| 9 | `path-privacy-allowlist`（AC-6 基线） | DESIGN D10′ / R8 列为新增产物（常设 + change 副本） | `flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt` 与 `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` 均不存在 | ✅ DESIGN-listed-new · T21-will-create |
| 10 | `check-nfr-portability`（NFR） | DESIGN D8 / §9.3 列为 Makefile 新增目标 | 实际 `Makefile` 0 命中 | ✅ DESIGN-listed-new · T28-will-create |

**L-031 总裁决**：10 锚点全部为「DESIGN-listed-and-will-change」或「DESIGN-listed-new」，**无 🔴 漏改**（DESIGN-missing-and-unchanged = 0），无 DESIGN-listed-but-unchanged（即 DESIGN 列了但 TASK 不改的假声明）。TASK 与 DESIGN 触碰面一致。

### Phase-3（3-task）checklist 逐项裁决

| # | checklist 项 | 裁决 | 依据 |
|---|-------------|------|------|
| 1 | task 粒度（≤200 lines / wave clear） | ✅ | 各 task verify 段可执行，无超长单 task；W1–W7 波次划分清晰（W1 定稿后置 / W2 源修复 / W3 判据收紧+部署+门禁实现 / W4 接线与拦截实跑 / W5 基线冻结+自校验 / W6 复扫+端到端 / W7 收口） |
| 2 | 依赖图无环 + parallel marked `[P]` | ✅ | 27 `parallel="true"` + 2 `parallel="false"`（T23 W5 serial、T29 W7 serial）= 29 tasks；依赖链 T01→T13→T17→T18→T20→T29 等均前向无环；冲突 ①-1（T22+T23 同写 `check-path-privacy.sh`）由 T23 `depends_on T21,T22` + `parallel="false"` 正确消解 |
| 3 | verify 可机器执行（无 manual 确认空话） | ✅ | 29 条 verify 全为 shell 命令（`grep`/`make -n`/`stat`/`bash -n`/`npx bats`/`diff`/`xargs -0`），均含失败分支（`|| { echo "🔴 …"; exit 1; }`）；无「人工确认」「目视检查」空话 |
| 4 | 覆盖完整性（all AC have task） | ✅ | AC-1→T05,T25,T27；AC-2→T06；AC-3→T11,T12,T16,T19；AC-4→T08,T14,T15；AC-5→T07,T24,T27；AC-6→T13,T17,T18,T20,T21,T22,T23,T26；AC-7→T09,T10；AC-8→T28,T29 —— 全 8 AC 有 task 覆盖，无 AC 落空 |
| 5 | read_files / write_files 约束到位 | 🟡 | write_files 逐条精确路径，**除 T13 item ④ 开放式条目外**均到位（见 R1）；read_files 含失败基线锚点（`.change-base` 缺失 / `Superseded-by`=0 / `eval-echo`=1 等 17 条原语已实跑留档） |
| 6 | 禁动清单（write_files 不碰 DESIGN/CONTEXT forbidden files） | ✅ | `TASK.md:1086` 自检 + 本审查 grep 复扫：`hooks/stop/**`（除 `stop/lib/l3-prompt.sh` 由 CHANGE §4b 用户裁决放行）、`brooks-lint/**`、`pipeline-gates.md`、`skills/**`、`INDEPENDENT-REVIEW-*.md`、`package-flow-kit.sh`、`.gitignore`、`.flow-active` 均不在任何 write_files；冲突 ②-1（形式：`stop/**` 禁动 vs T04 改 `l3-prompt.sh`）已由 DESIGN §0.5.1 + CHANGE §4b 显式裁决 |

### 补充核验（非 checklist 项，但影响裁决完整性）

1. **冲突 ①-1（实质）消解验证**：`check-path-privacy.sh` 被 T17（W3，新建 PAT+排除表+fail-closed）、T22（W5，固化空基线分支）、T23（W5 serial，补清单格式校验+ADR-028+棘轮）三度写入。T22 与 T23 同属 W5，T23 `parallel="false"` + `depends_on T21,T22` ⇒ T22 写完 → T23 才写，无并发写竞态。✅ 正确消解。

2. **冲突 ②-1（形式）消解验证**：`stop/**` 禁动 vs T04 改 `stop/lib/l3-prompt.sh`。`DESIGN §0.5.1` 明示「`hooks/stop/**`（除 `l3-prompt.sh`）」+ `CHANGE §4b` 用户裁决（2026-09-23：phase2 ADR 纳入由 `find|head-3` 改为按频次+逐份/总量预算+截断/未纳入落显式标记，TD-043 由缺陷转已修）。T04 write_files = `hooks/stop/lib/l3-prompt.sh`，精确到单文件，非 `stop/**` 通配。✅ 正确消解。

3. **AC-3 pre-push 载体既有态验证**：`.git/hooks/pre-push` 当前存在（373B，executable，6月 29，内容 = `make check` per DESIGN D3 实测）。T19 verify（AC-3 端到端四形态 push）须处理此既有非 flow-kit hook —— DESIGN D3 `is_flowkit_symlink()` 判据按载体语义（`[ -L ]` + 裸 `readlink`，禁 `readlink -f` GNU-only）⇒ 既有普通文件走备份+覆盖分支。T19 `depends_on T11,T12,T16`，T16（`deploy_pre_push`）在 T19 前完成部署。✅ 既有态已被 DESIGN D3 覆盖。

4. **T11 `pre-push.sh` exec 权限验证**：T11 verify（`TASK.md:403-410`）含 `[ -f ]` + `[ -x ]` + `stat -c '%a'`（Linux）/ `stat -f '%Lp'`（BSD）跨平台权限断言 + `grep 'make check'` + `bash -n` + bash3.2/GNU 兼容原语排除（`mapfile|declare -A|readlink -[fe]|sed -i` 不得命中）。DESIGN D3「源文件 100755 入仓」要求在 verify 中**显式编码**。✅ 无 exec 权限 gap。

5. **T13 工件脱敏 verify 实测**：当前 pre-dev 状态跑 T13 verify（`PAT='/home/[a-z_][a-z0-9_-]*/'` + `git ls-files -z | xargs -0 grep -nE` + 排除 `INDEPENDENT-REVIEW-[12].md` + 排除 `/home/(user|ubuntu|…)/`）⇒ `n=1`，命中 = `DESIGN.md:246` `HOME=/home/⟨test⟩`（fixture 自造字面）。T13 action ② 显式针对此（改不命中形态 `$HOME/x.sh`，禁把 `test` 加排除表）。✅ verify 正确标记 must-fix，sound 且 machine-executable。

### Verdict

**Verdict**: pass

**裁决理由**：本审查在 `TASK.md` 全 29 条逐条 7 字段核对 + L-031 跨阶段 grep 锚点全仓复扫 + Phase-3 checklist 六项逐条裁决后，**未发现 🔴 Critical** 级别问题（无数据损坏 / 无安全 RCE 残留 / 无 AC 未实现 / 无 spec compliance failure / 无 🔴 漏改）。

发现 1 条 🟡 Important（R1：T13 write_files item ④ 开放式条目非逐条枚举，须 fix loop · task-internal 闭环）+ 1 条 🟢 Minor（R2：T29 收口 task verify 粒度偏重，登记入 MINOR-DEFERRED.md，不入 fix loop）。

依赖图无环、parallel 标记正确、冲突 ①-1/②-1 均正确消解、verify 全可机器执行、AC↔task 覆盖完整、禁动清单无越界、L-031 锚点全复扫无漏改。TASK.md 满足 Phase-3（3-task）toll-gate 通过条件。

R1 须在 4-dev 开工前或开工首轮闭环（将 T13 item ④ 改为封闭式枚举 + 禁动清单路径显式排除 verify），不阻塞 toll-gate 但阻塞 T13 自身执行可靠性。

---

## 主 agent 响应（阶段 3 · L2 第 1 轮）

- **R1（🟡 Important）→ Fixed in（本轮内闭环，不等 4-dev）**：
  1. `TASK.md` T13 `write_files` 第 ④ 项由「其余复扫命中的 tracked 文本（以复扫输出为准）」改为**封闭式边界**：静态范围 = ①②③ 三条精确路径；运行时额外命中「§0.5.1 触碰清单**内**」的 tracked 文件 ⇒ 允许就地脱敏，但须在 4-dev 日志留 `file:line` + 脱敏前后对照；命中「清单**外**或禁动清单内」⇒ **停止并升级为新 task**，禁止在 T13 内就地脱敏禁动文件（已写死为硬约束，不再依赖运行时判断）。
  2. T13 `verify` 新增**禁动面守卫**（审查员 Remedy 的第二半）：`git grep -nE "$PAT" | cut -d: -f1 | sort -u | grep -E "$FOB" | grep -vE '^flow-kit-bundle/hooks/stop/lib/l3-prompt\.sh$'` 非空即 `exit 1`。
  3. 顺手补上审查员 Remedy 未覆盖的一处：**④ 的实测基线数**写进 `write_files` 并注明「由 verify 首条断言复核」——今日占位符排除后整仓命中仅 `DESIGN.md:246` 一行（属 ① 路径）⇒ **今日无需新增路径**，避免「以复扫输出为准」在 4-dev 变成新的漂移源。
- **实跑证据（L-119）**：改后重新提取 T13 `verify` 全文（10 行）→ `bash -n` 通过 → 整段跑 `rc=1` + `🔴 清单外命中=1（脱敏未完成，禁止冻结基线）`（＝修复前应有的红，与审查员第 5 条补充核验一致）；去掉 `n` 断言单独跑守卫 ⇒ `rc=0`。守卫判别力**分部实跑**：合成正例 `flow-kit-bundle/skills/…` 与 `hooks/stop/lib/timer.sh` 各命中 **1**（抓得住）；授权放行的 `stop/lib/l3-prompt.sh` ⇒ **0**（不误伤）。
- **R2（🟢 Minor）→ Deferred（已登记）**：见 `MINOR-DEFERRED.md`「阶段 3 · 新增未处置项」R2 行（拆分动议 + 触发条件）。不入 fix loop。
- **R3（主 agent 复核 R1 时自查发现 · 已登记 🟢）**：自排除边界按「逐条精确路径」枚举审查档，而审查档按阶段递增。实测 `INDEPENDENT-REVIEW-1.md` 非占位符 PAT 命中 **22** 行、`-2.md` **18** 行、`-3.md` **0** 行 ⇒ 若阶段 5/6/7 的审查档出现命中而未被追加进排除表，AC-6 门禁会在收口时以「清单外命中 ≠ 0」变红（ADR-027②「长期红门禁」形态）。**不改成通配**（违反 D8 行「自排除边界（强制）」③「只允许逐条精确路径」，且 D10′② 实测通配会吞掉 31 处 `<acct>` 字样）。修补：`TASK.md` T17 action 已写死「当前逐条枚举 `-1/-2/-3`」+「后续审查档**只有在实际出现非占位符命中时**才以**显式动作**追加，且登记于响应段」。
- **本轮未改动的工件**：`REQUIREMENT.md` / `DESIGN.md` / `CHANGE.md`（阶段 2 工件保持 L3 #4 放行时的内容）；流程状态未动；未写任何握手凭证（由子系统在 L3 通过后写）。

## 主 agent 响应（阶段 3 · L3 第 1 轮 · 三条 minor 处置）

**前置事实**：本轮修改了 `TASK.md` ⇒ 记录在案的 `L3_artifact_hash` 随之失效（`flow-kit-bundle/hooks/stop/lib/l3-truncate.sh:22 _l3_check_rerun` 在 phase 3 取 `TASK.md` 的 sha256 比对），Stop hook 将自动作废本段并重审。本响应只登记处置，不替代重审。

### m1（T13 边界混合表述）— Fixed in
采用 L3 建议的**第一形态（显式枚举）**并补一条机器断言：
1. `write_files` ④ 由「运行时可就地脱敏（以复扫输出为准）」改为**显式枚举 §0.5.1 编辑面**共 14 类（`Makefile`、`sync-hooks.sh`、9 个 bundle 脚本、`test/*.bats` 与 `flow-kit-bundle/test/*.bats`、`.specs/health-fix-2026-09b/{DESIGN,REQUIREMENT,CHANGE,MINOR-DEFERRED,TASK}.md`、`.specs/health/*.md`、`.specs/adr/*.md`），并写明「命中该面之外（含禁动清单内）⇒ 停止并升级为新 task」。
2. `verify` 新增 `$AUTH` **正名单**断言：经排除表口径过滤后的残余命中，其文件必须全部落在授权面内，否则打印越界文件并 `exit 1`；残余命中逐条以 `file:line` 打印（L3 要求的可见性）。
3. **替换而非叠加**：原先的 `$FOB`（禁动面黑名单）已删除 —— `$AUTH` 正名单**严格覆盖**它（`skills/`、`stop/`（`l3-prompt.sh` 除外）、`pipeline-gates.md`、`package-flow-kit.sh`、`.gitignore`、`.flow-active` 均不在 `$AUTH` 内）。单条判据优于黑白名单双轨。

**实跑证据**：从 TASK.md 提取该 verify（18 行）→ `bash -n` 通过；**脱敏前态**整段跑 `rc=1`，逐条打印 `.specs/health-fix-2026-09b/DESIGN.md:246: …` 并给出 `🔴 清单外命中=1（脱敏未完成，禁止冻结基线）`；把计数断言中和后 `rc=0`（证明 `$AUTH` 断言在当前态通过、非恒红）。**判别力实测**（`$AUTH` 直接提取自 verify 原文，非另抄）：必须拦 **6/6** —— `flow-kit-bundle/skills/flow/SKILL.md`、`flow-kit-bundle/hooks/stop/lib/timer.sh`、`flow-kit-bundle/flow-kit/reference/pipeline-gates.md`、`package-flow-kit.sh`、`.flow-active`、`flow-kit-bundle/hooks/stop/lib/l3-review.sh`；必须放行 **5/5** —— `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`、`Makefile`、`.specs/health-fix-2026-09b/DESIGN.md`、`.specs/adr/028-gate-baseline-allowlist.md`、`test/test_x.bats`。

**诚实边界**：脱敏完成后 `$hits` 为空 ⇒ `$AUTH` 断言在**终态**退化为恒真；其判别力已在前态与合成例上实证（如上）。该断言的本意是「写面不越界」不变量，而非「有命中」检测。

### m2（T13 重复计数）— Fixed in
两分支输出先 `sort -u` 再计数，并在命令内加注释说明「分支 2 = **刻意**补扫尚未 tracked 的三份工件，与分支 1 可能命中同一行」。**实跑证据**：同一行经两分支各出现一次 ⇒ 无 `sort -u` 时 `n=2`、有 `sort -u` 时 `n=1`。

### m3（T27 bats 无断言）— Fixed in，且同缺陷在 T29 更重（自审发现）
1. `T27.verify` 末行 `npx bats test/ | tail -3` → 固定 `--formatter tap` + 落临时文件 + 三条可失败断言（`b_rc=0` ∧ `^not ok` 计数 = 0 ∧ `^ok` 计数 ≥ 973），并打印失败行 `head -5`。
2. **自审发现（同一缺陷类，比 T27 更重）**：`T29.verify` 原用 `grep -qE '[0-9]+ ok'` 与 `grep -qE '0 not ok'` 断言 —— 断言的是**摘要行**，而本环境 bats 的 TAP 输出**没有摘要行**：实测 `grep -cE '[0-9]+ ok'` = **0**、`grep -cE '0 not ok'` = **0**、`grep -cE 'ok [0-9]+'` = 973（末行为 `ok 973 CF-03: …`）。⇒ 原判据**恒红**（T29 永远无法 done），已改写为与 T27 同一形态。

**实跑证据**：`npx bats test/ --formatter tap` 全量跑 → `rc=0 ok=973 not-ok=0`（skip 计入 `ok` 行）；按新形态重写的断言块实跑 `rc=0`；反向探针（令 `b_ok=1`）→ `🔴 bats 回归（rc=0 not-ok=0 ok=1）`，判据可失败。T29 与 T27 的 bats 块 `diff` 仅余注释标点与行尾分号差异（操作行逐字相同）⇒ 同一次实跑同时构成两者的证据。

### 顺带自查修正（不计入 L3 findings）
`T13.done` 原写「审查档 **39** 处按精确路径豁免」；实测非占位符命中 = IR-1 **22** + IR-2 **18** = **40** 处（raw 分别 22 / 28；IR-3 = 0，已被 `(1|2|3)` 逐条枚举覆盖）⇒ 已按实测数改写。

### 未改动
三条 minor 均属**判据/边界表述**层：未触任何 AC 语义、门禁行为与仓内 write_files 路径；实测数字除上述 39→40 的订正外未改。请外部模型就本段所述改动复裁。

---

## 主 agent 响应（阶段 3 · L3 第 2 轮 · 8 条 findings 处置）

**判决**：fail（2 critical / 4 major / 2 minor）。逐条处置如下；定位一律用**内容锚点**（行号随编辑漂移，不作文档间引用）。

### C1（critical）· T19 夹具在空仓中无法让 pre-push 通过 ⇒ 恒红
- 已修：`<action>` 增「夹具前提（缺一则本 task 恒红）」；verify 整段重写：
  - 沙箱内提供 **Makefile 桩**（`check` → `check-path-privacy`）+ 复制的**真实** `check-path-privacy.sh`（T17 产物）+ **已冻结**的权威清单（T21 产物）；
  - `develop` 先建（干净）→ `main` 用 `git checkout --orphan` + `git checkout -q develop -- Makefile flow-kit-bundle` 形成**无共同祖先**的泄漏分支（原写法 develop 从 main 分出 ⇒ develop 自身也含泄漏，语义自相矛盾）；
  - **夹具自检**：干净态 `make check-path-privacy` 必绿、泄漏态必红（夹具本身失效则整条判据无意义）；
  - **归因对照**：摘掉 `.git/hooks/pre-push` 后，同一泄漏 push **必须成功**（rc=0），随后 `update-ref -d refs/heads/main` 清理；
  - `depends_on` 追加 `T17, T21`（真实门禁脚本与权威清单的产出者）。
- 证据（本轮实跑，桩门禁 + 真实 git 拓扑）：干净态 rc=0 ✅；泄漏态 rc≠0 ✅；`git merge-base main develop` 输出**空** ✅；`main` 树含 `Makefile flow-kit-bundle/…/check-path-privacy.sh leak.txt`、`develop` 树含 `Makefile clean.txt flow-kit-bundle/…` ✅；无 hook 时泄漏 push 成功 ✅（归因对照前提成立）。
- 诚实边界：`check-path-privacy.sh`（T17）/ Makefile 目标（T18）/ 两份清单（T21）/ pre-push（T11）在阶段 3 尚未生成 ⇒ **整段端到端首跑只能在 4-dev**；本轮能证的是夹具机制与断言逻辑（以桩门禁替代）。

### C2（critical）· `--tags` 形态不断言 rc、不断言 ref 指名
- 已修：`--tags` 断言 rc≠0 且报文命中 `v1`；①②③ 三形态同样断言 rc≠0 且报文**指名 `main`**（正则 `(^|[^[:alnum:]_])main([^[:alnum:]_]|$)`）。
- 附带修 T11 `<action>` **次序语义**：① 先逐条评估 stdin 的 `<local ref> <local sha> <remote ref> <remote sha>`，对含泄漏的 ref 输出可读原因**并指名该 ref**；② 全部 ref 干净后才跑 `make check`（次序反了则 `make` 的通用错误先失败、报文无法指名 ref ⇒ C2 的断言不可满足）。
- 证据：合成报文双态 —— `refs/heads/main 含路径隐私泄漏` 命中 ✅ / `push rejected: leak detected` **不**命中 ✅ / `refs/tags/v1 …` 命中 ✅。

### M1（major）· T13 补扫面漏 TASK.md / MINOR-DEFERRED.md
- 已修：分支 2 由三份扩到**五份**（DESIGN / REQUIREMENT / CHANGE / **TASK** / **MINOR-DEFERRED**）；`<done>` 同步。
- 证据：修后实跑 `rc=1`，逐条打印 **3 行** —— `.specs/health-fix-2026-09b/DESIGN.md:246`、`.specs/health-fix-2026-09b/TASK.md:464`、`.specs/health-fix-2026-09b/TASK.md:472`（后两处为 T13 自身对 fixture 字面的描述）⇒ 补扫生效，原先不可见的两处已进入视野。

### M2（major）· T26 差分探针追加到 change 副本 ⇒ 与读序矛盾（恒红）
- 已修：`<action>` ④ 改为**读序双态** —— ④a 追加到**权威**清单（`flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt`）并断言自报条数**增大**；④b **移走权威**、change 副本在位 ⇒ 必须 rc=0（否则「两份皆缺 ⇒ rc=1」无判别力）；verify 中 `AL2`/`AL` 的定义**提前到 trap 之前**，trap 同时恢复三者（CONTEXT.md 探针 / 权威 / 副本）。
- 证据：模拟 ④b 失败（rc≠0）路径 ⇒ 走恢复分支后权威清单存在且内容完好 ✅。

### M3（major）· T28 把 rc=1（失败）与 rc=0 并列当通过
- 已修：`case "$rc" in 0) : ;; 1) { head -20 "$NFR_OUT"; … exit 1; } ;; 3) …红 ;; *) …红 ;; esac`。
- 证据：从 `TASK.md` 抽出该 `case` 块，以 `make(){ return $R; }` 桩实跑 —— `rc=0 ⇒ 块 rc=0` ✅；`rc=1/3/9 ⇒ 块 rc=1`，三行报文各异 ✅。

### M4（major）· T13 `write_files` 混入叙述与通配，与「封闭/精确」声明不一致
- 已修：`write_files` 只留 ① ② ③ 三条**精确路径** + 一行 ④「运行时授权面（条件写面 · 闭集）」**声明**（唯一权威定义 = verify 的 `$AUTH` 正则所列 14 类精确路径；此处不重复枚举以免漂移），并注明本 task 静态写面 = ①②③；原枚举叙述移入 `<action>` ⑥。

### m1（minor）· T06 只断言非空与 permissions.allow
- 已修：加 `cp` 原样副本 + `cmp -s`（入口校验在任何写盘之前 ⇒ 应**逐字节相同**）+ `jq -e '.permissions.allow | index("Bash(ls:*)")'` + `jq -e '.hooks.Stop[0].hooks[0].command == "true"'` + `[ "$(jq -c 'keys' "$SET")" = '["hooks","permissions"]' ]`。
- 证据：完整态四项全过 ✅；`jq 'del(.hooks)'` 后 `cmp` / hooks / keys 三条断言**均抓住** ✅；整段 verify 实跑 `rc=1`、末行 `🔴 settings.json 被截断为空`（触达缺陷现场）✅。

### m2（minor）· T07 只跑两个 bats 文件、无计数断言（删测试仍绿）
- 已修：`npx bats <两文件> --formatter tap` + TAP 计数断言（`rc=0`、`^not ok` = 0、`^ok` ≥ 134）。
- 证据：实跑 `rc=0 / ok=134 / not-ok=0` ✅；反向探针（注入合成 `not ok`）⇒ 红 ✅。

### 附：同批自审发现并处置的缺陷
- **T29 死判据**：原 verify 用 `grep -qE '[0-9]+ ok'` / `'0 not ok'` 断言**摘要行**，而 TAP 输出**无摘要行**（实测 `[0-9]+ ok`=0、`0 not ok`=0、`ok [0-9]+`=973）⇒ 该判据**永不可能通过**。已改为与 T27 同形态的 TAP 计数块。
- **T13 `<done>` 计数**：「审查档 39 处」→ 实测 **40**（IR-1 22 + IR-2 18；raw 22 / 28；IR-3 = 0）。
- **T11 次序语义**（见 C2 附带）。
- 全部 29 个 `<verify>` 抽出后过 `bash -n`（无语法错）；7 字段计数 = 29。

### 提示词预算披露（影响上一轮重审的可见性）
- 上一轮重审时 L3 提示词被**尾部裁剪**：stderr `WARNING: 提示词被截断 — 完整 85871B，本次仅发送 80000B（丢弃 6%）`。干跑 `_l3_build_prompt 3 .specs/health-fix-2026-09b 80000` 复现：`TASK.md` 93566 B 先被 `_l3_utf8_head_bytes 80000` 截到 80000 B，再被**同一常量**当总量上限裁掉 5871 B ⇒ 审查者只看到约 76 KB，**T24–T29 一带（含 AC-8 收口 task）从未进入提示词**；哨兵 `AC-8 收口` / `规定性伪代码` / `<!-- 占位 -->` 均 0 命中，末行截在 T28 的 `case` 中间。
- 处置：① 登记 **TD-045**（🟡：同一 `max_bytes` 既当单件上限又当总量上限，主件尾部被静默裁剪且无提示词内标记；建议拆两个常量 + 按「附属件 → 主件」优先级裁剪并逐次落标记）；② **本 change 内不改该代码**（与 TD-043 同文件，避免自指门禁继续扩面）；③ 本轮重审以 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES` 提高预算运行 —— 只**增加**可见信息、**不放宽**任何判据。
- 由此声明：上一轮判决中凡涉及 T24–T29 的判断，都是在**部分工件**上作出的；本轮请在完整工件上复核。

### 本轮改动对复核的影响
- `TASK.md` 已按上述逐条修订；工件内容变更使在案的 `L3_artifact_hash` 失效 ⇒ 依设计应触发重审（上一轮重审即由该机制触发）。
- 未触任何 AC 语义、常量口径与门禁行为；除上述条目外未改其它判据。

---

## 主 agent 响应（阶段 3 · L3 第 3 轮 · 9 条 findings 处置）

**判决**：fail（1 critical / 4 major / 4 minor）。本轮**首次在完整工件上复核**：提示词 `105894 B`、无截断警告，哨兵 `AC-8 收口` / `<!-- 占位 -->` / `git checkout -q --orphan main` 均命中（TASK.md 全文可见）；上一轮被判的 8 条未再复现。逐条处置如下。

### critical（T19 · 与 major③ 同源）· `--tags` 失败分支不打印实际报文
- 已修：四形态的**两个**失败分支（rc 断言 / ref 指名断言）均加 `printf '%s\n' "$out"`，rc 断言报文补 `（rc=$rc）`。
- 证据（实跑：从 `TASK.md` 抽出该 `for` 循环，以 `git` 桩三态驱动）—— 报文指名 `main` ⇒ rc=0 ✅；报文不含 ref 名 ⇒ rc=**1 且打印实际报文** ✅；rc=0 ⇒ rc=**1 且打印实际报文** ✅。

### major
- **T15**：负向断言由单一 `-ne 2` 模式改为**穷举** `grep -nE '\[ "\$status" -ne [0-9]+ \]'`（命中即失败），保留 `-eq 0` 正向断言。证据：当前 `test/test_check_gate_sync.bats` 实测命中 **1** 处（`:30`）⇒ 修复前应有的红 ✅。
- **T10**：加**存在性断言**（`sed` 段内必须先命中 `AC-4`）再做 skip 检查。证据：当前文件存在性 ✅（若删除/改名，`sed` 无匹配 ⇒ `grep -q` 退出 1 被 `||` 捕获转红）。
- **T28**：`make -n check | grep -q 'check-nfr-portability' || echo "ℹ️ …"` 改为硬失败 `|| { echo "🔴 check-nfr-portability 未接入 make check"; exit 1; }`。证据（`make` 桩双态）：未接入 ⇒ rc=1 且报文指名 ✅；已接入 ⇒ rc=0 ✅。
- **T19**（诊断，同 critical）：见上。

### minor
- **T13**：verify 开头加 `git rev-parse --git-dir >/dev/null 2>&1 || { echo "🔴 非 git 仓库…"; exit 1; }`。证据：`/tmp`（非仓）⇒ rc=1 ✅；仓内 ⇒ rc=0 ✅。
- **T22**：末行 `cp …; ex=$?; exit $ex`（`ex` 恒 0）改为 `cp … || { echo "🔴 探针恢复失败（tracked 文件残留）"; exit 1; }`。
- **T23**：畸形清单行测试改为捕获 `out`/`rc`，并**断言报文指名**清单路径 `path-privacy-allowlist.txt` **且**含行号或违规内容（`:[0-9]+:` / `N 行` / `ZZ-BAD-LINE-NO-COLON`）。证据（合成报文双态）：含路径+行号 ⇒ 通过 ✅；仅「格式错误」⇒ rc=1 且打印实际报文 ✅。
- **T26**：删除 `make --help | grep -qw -- '--list'` 守卫（与 T26 判据无关，`make --list` 只是 DESIGN 选型前提；原判据会在支持 `--list` 的环境无关假红）。保留 `--always-make` 正例自检（实测 ✅）。

### 同步项
- `<done>` 三处同步：T10（先断言测试段存在）、T15（任何 `-ne N` 形态均判失败）、T19（失败分支打印实际报文）。
- 全部 29 个 `<verify>` 重新抽取并过 `bash -n`：**全部通过**；`<task id=` 计数 29；7 字段各 29。

### 另：判决 JSON 不可解析（本轮实测，登记为 TD-046）
- 本轮落档的判决 JSON **不是合法 JSON**：`json.loads` 失败于 `Expecting ',' delimiter: line 5 column 10420`（`strict=False` 亦失败）—— 模型返回的字符串含未转义引号/裸换行，写入方未校验即照抄；人工阅读正常，机器读取失败。我以容错解析器（按 `"file"/"issue"/"why"/"fix"` 逐字段状态机）取回 findings 完成处置。
- 已登记 `.specs/CONTEXT.md` **TD-046**（🟡：判决是门禁的机器可读接口；建议落档前 `jq -e .` 校验，失败时保留原文并落显式「解析失败」标记）；**本 change 内不改该代码**。

### 本轮改动的边界
- 只改判据的**可诊断性/穷举性**与一处无关守卫，未触任何 AC 语义、常量口径、读序与门禁行为。
- T19/T22/T23 的**整段**端到端首跑仍在 4-dev（依赖 T11/T16/T17/T18/T21 产物）；本轮可证的是语法、断言判别力与失败分支报文（以桩驱动）。

---

## 主 agent 响应（阶段 3 · L3 第 4 轮 · 3 major + 1 minor 处置）

判决：**pass**（0 critical / 3 major / 1 minor）。以下逐条处置 + 实跑证据。

### major① · T09 沙箱未声明 + T26 对 T21 冻结产物的临时改写缺纪律
- **T09**：`write_files` 新增显式条目「仓库外临时沙箱（`td2=$(mktemp -d)`）：注入夹具 `$td2/tmp.zz-inject` 的创建与清理；**不入库**，写面仅限该沙箱」；`<action>` 新增 ③「**夹具协议**」——以 `TMPDIR="$td2"` 驱动 bats、用例结束 `rm -rf "$TD" "$td2"`、**仓库内不得留注入残留**。
- **T26**：`write_files` 的权威清单条目注明这是对 **T21 冻结产物**的**受控改写**（先备份 → 失败分支亦恢复 → 恢复后须与备份**逐字节一致** → 恢复失败即中止并升级）；`<action>` 的 D4 句末补同义要求；`<verify>` 在 `mv -f /tmp/al2-moved "$AL2"` 之后插入三条断言：`cmp -s "$AL2" /tmp/al2-bak` / `cmp -s "$AL" /tmp/al-bak` / `cmp -s .specs/CONTEXT.md /tmp/probe-bak`（各带 🔴 报文）。
- 理由：T26 的 ④a/④b 为验证**读序**必须临时改写权威清单 —— 若无「逐字节恢复」断言，一次失败会把**常设基线**污染成「探针残留」，而此后所有门禁都会以被污染的基线为准（L-124 同族：基线/凭证必须对当前对象有效）。

### major② · 波次图未显式禁止 T23 与 T22 并行
- `TASK.md:36` 的 Wave 5 行改为：`T21[P], T22[P], T24[P]；串行: T23（depends_on T21, T22；与 T22 同写 flow-kit-bundle/flow-kit/reference/check-path-privacy.sh ⇒ **必须等 T22 落定后才可开工，禁止与 T22 并行**）`。

### major③ · T28 的非空守卫与 T29 的 AC-8 全局守卫职责重叠
- 非空守卫**降级为诊断提示**：`[ -n "$ADDED$NEWF" ] || echo "ℹ️ 变更集为空…⇒ 判据将在空集上恒真并返回 rc=3；本处**不判失败**（AC-8 全局非空守卫在 T29），由下方 rc 分支裁决（SKIP ≠ PASS）"`；`3)` 臂报文补「变更集为空（判据在空集上恒真）或锚点缺失 ⇒ SKIP ≠ PASS …阶段 3 L3 major③」；`<done>` 同步为「**rc=0 才通过**（rc=1 违规；rc=3 未验证/空集 ⇒ 非零退出）；空集诊断由 ℹ️ 提示 + rc=3 分支承担，**不另设非空守卫**」。
- 理由：删掉守卫**不改变判定结果**（rc=3 臂同样红），只消除与 T29 的职责重叠并保留信息量。

### minor · T13 扫 `TASK.md` 时其自身 fixture 字面会造成假红
- `TASK.md:464` / `:472` 的字面 de-shape 为 `` `/home/<acct>/test` 形态 ``；`<action>` ⑥ 补「`TASK.md` 在授权面内（`$AUTH` 第 5 类），当前 PAT 命中 **0 处**；若复扫再现命中 ⇒ 就地 de-shape，**不**把计划档排除出扫描面」。
- 实跑：`LC_ALL=C grep -nE '/home/[a-z_][a-z0-9_-]*/' .specs/health-fix-2026-09b/TASK.md | grep -vE '/home/(user|ubuntu|\.\.\.)/'` ⇒ **0 行**。
- 不采用「把 TASK.md 排除出扫描面」的理由：该档正是 T13 这一列要保护的对象之一，排除会让**冻结前的基线**失去对计划档自身的覆盖。

### 另 · 本轮两个自发现（已登记；本 change 内不改被发现的代码）
1. **判据抽取工具必须锚定行级标签** → `.specs/LESSONS.md` **L-125**：T13 正文里的**行内** `` `<verify>` `` 字样让裸的非贪婪匹配抽错区间并报出**假语法错误**；改用 `\n  <verify>\n(.*?)\n  </verify>` 锚定后 **29/29** 抽取、`bash -n` 失败 **0**。对照：`task-brief` 是 awk **按行状态机**，不受同形字样影响（同一工件、两种解析器、两种结果）。已把正文两处改为「verify 段」，此后 `grep -c '<verify>' TASK.md` = **29**（全为真标签）。
2. **阶段 4 文档的 `task-brief` 调用形态不可执行** → `.specs/CONTEXT.md` **TD-047**：`flow-kit-bundle/flow-kit/prompts/4-dev.md:157` 写 `bash scripts/task-brief …`，而脚本首行是 `#!/usr/bin/awk -f` ⇒ 实测 **rc=2**（`行 7: BEGIN: 未找到命令` / `行 8: 未预期的记号 "{" 附近有语法错误`）；**直接执行可用**（rc=0、6005 B、正确切出 `<task id="T13">` 块）。阶段 4 全程依赖该命令切单 task 上下文 ⇒ 照文档执行会在 4-dev 起步即失败。**本 change 内不改它**，仅登记。

### 终态与边界
- `TASK.md` **1224 行** / `<task id=` **29** / 7 字段各 29 / `parallel="true"` 27（T23、T29 串行）/ `model-tier` 29（8 cheap / 13 standard / 11 top）；29 份 verify 行级抽取后 `bash -n` **失败 0**。
- 本轮改动只落在**判据纪律与写面声明**：未改任何 AC 语义、常量口径、ADR 决策、读序与门禁行为。
- T09/T26/T28 的**整段**端到端首跑仍在 4-dev（依赖 T11/T16/T17/T18/T21 产物）；本轮已证的是改后判据的语法、抽取完整性、PAT 复扫为 0 与授权面/黑名单面的一次性核验。
- 未写任何握手凭证（由子系统在 L3 通过后写）。

---

---

## 主 agent 响应（阶段 3 · L3 第 5 轮 · 12 条 findings 处置）

> 本轮判决：`L3 verdict=fail`（3 critical / 5 major / 4 minor，`L3_artifact_hash: 862e592be587…`）。
> 12 条中 **11 条 Fix**（逐条给出实跑证据），**1 条（m9）以工件原文反驳**（finding 与工件不符，按 ADR-027 不得把已知可接受项升级为 fail）。
> 应用记录的机械细节：`/tmp/fix_r5.py`，**26 处替换**，每处先断言 `count==1`（chisel 两处按 `count==2`），**原子**（任一不符即不写入任何改动）；应用后再补 1 处（T13 action ⑥ 的 `$AUTH` → `$FACE`）。

### C1 · T09（critical）— 注入点与 SUT 扫描根同源

**Fix。** 复核确认 finding 属实，且比 finding 描述的更严重：`test/test_combined_metric.bats:30-31` 原本扫的是**裸 `/tmp/tmp.*`**（`run ls /tmp/tmp.*`），与 `TMPDIR` 无关 ⇒ 我原判据的注入点（`$td2/tmp.zz-inject` + `TMPDIR="$td2"`）**根本触达不了 SUT 的判据**（L-122 类）。

- `<action>` ① 改写为：**扫描根 = `${TMPDIR:-/tmp}` 的单层 `tmp.*`，且必须排除用例自身的 `$TEST_TMPDIR`**；给出目标形态 `run bash -c 'ls -d "${TMPDIR:-/tmp}"/tmp.* 2>/dev/null | grep -vF "$TEST_TMPDIR"'` + 断言 `[ "$status" -ne 0 ]`（无残留 ⇒ grep 无命中 ⇒ 非零 ⇒ 绿；有残留 ⇒ 零 ⇒ 红）；并写明「**扫描根与 verify 的注入点必须同一（`TMPDIR`）**：健康态/注入态共用同一 `TMPDIR` ⇒ 两态仅差一个残留文件，红/绿差异不可归因于环境差异」。
- `<verify>` 增三条机器断言：SUT 必含 `${TMPDIR…`、**禁**裸 `ls /tmp/tmp.*`、必含 `TEST_TMPDIR`（三条均为 `grep` 级断言，不依赖 4-dev 产物即可运行）。

### C2 · T13（critical）— 条件写面收窄

**Fix。** 原 `$AUTH` 含 Makefile / `sync-hooks.sh` / 9 个 bundle 脚本 / 全部 bats ⇒ 等价于「T13 可改整个 change 写面」，越界判定形同虚设。收窄为：

```
FACE='^(\.specs/health-fix-2026-09b/(DESIGN|REQUIREMENT|CHANGE|MINOR-DEFERRED|TASK)\.md|\.specs/health/[^/]+\.md|\.specs/adr/[^/]+\.md)$'
```

面外（代码 / 测试 / 门禁本体）一律「**停止并升级为新 task**」。同步改动：`write_files` ④ 的 `$AUTH` 字样、`<action>` ⑥ 的两处 `$AUTH` 字样全部改为 `$FACE`。**实测**：T13 段（`:469-523`）内 `AUTH` 残留 = **0**。

### C3 · T29（critical）— 门禁接线依赖

**Fix。** `depends_on` 增列 **T08, T14, T15**；`<verify>` 首部增两条前置断言：`make -n check | grep -q 'check-gate-sync'` 与 `make -n check | grep -q 'check-path-privacy'`（未接线即红，报文指名未完成的 task）。这样 AC-8 的「无退化」不再可能在**旧门禁集**上全绿。

### M4 · T23（major）— 临时写入的边界与时点

**Fix（两处）。** ① `write_files` 补两条**受控临时写入**条目（常设权威清单 `path-privacy-allowlist.txt`；`.specs/CONTEXT.md`），写明「先备份 → `trap … EXIT` 恢复 → 末段 `cmp -s` 逐字节断言；常设基线不得留残留」。② `<verify>` 把 `cp … /tmp/al-probe-bak` + `trap … EXIT` **提前到首次写入之前**（原写法在首次写入之后才安装 trap ⇒ 中途失败会留下污染），删除原后置 trap 行，末段新增两条断言：`cmp -s "$A" /tmp/al-fmt-bak`、`cmp -s .specs/CONTEXT.md /tmp/al-probe-bak`（各自独立 🔴 报文）。

### M5 · T19（major）— 跨 wave 依赖与夹具时点

**Fix。** T19 由 W4 **移入 W6 串行**（`parallel="false"`），`depends_on` 增列 T22, T23, T26；波次图 W4 改为 `T18[P], T20[P]`，W6 改为「并行 4 + 串行 1」并注明移入理由（夹具复制的是**终稿**门禁脚本与**已冻结**清单，而脚本在 T22/T23 之后才定稿、清单在 T26 期间会被临时移走）；自检表第 5 行 27 → **26**；Plan-Conflict Scan 的说明行补记 T19 变化。

### M6 · T25（major）— 哨兵测试必须自证「守卫真的跑了」

**Fix。** `<verify>` 增三条前置：`$HOME/.claude/hooks` 必须出现在 `sync-hooks.sh --list` 的 DEST_ROOT 枚举内（**实测确认它是第 1 条 ✅**）、`$GUARD` 文件必须存在、捕获 `grc` 并断言 `grc ∈ {0,2}`（0=放行 / 2=拒绝契约）；原 `|| true` 保留在管线上但不再能吞掉「守卫根本没跑」。`write_files` 补「哨兵测试的执行对象 = 本机部署副本」说明。

### M7 · T28（major）— 与 DESIGN §9.3 的三态包装对齐

**Fix。** 澄清职责：DESIGN §9.3 的**包装**对内部 `3` 的处理是「打印 `SKIP: …` 后 `exit 0`」（在 `make check` 里非阻塞但**必须可见**）；而 T28 的判据**已先自证**锚点在位、变更集非空。因此：

- `<verify>` 的 case 改为 `0) : ;; 1) 红 ;; *) 红（rc=3 泄漏 = 实现偏离设计）`；
- 新增 `grep -q 'SKIP:' "$NFR_OUT" && { 判红 }`（此时 SKIP 只可能来自实现缺陷，判红是判据的正确行为）；
- `<action>` 与 `<done>` 同步写明「**rc=0 且输出不含 `SKIP:` 才通过**」及与 T29 的分工（T28 目标级 / T29 AC-8 全局，判据同源同向）。

### M8 · T13↔T17 排除表同源（major）

**Fix。** T13 `<action>` ⑥ 补「审查档排除面与 T17 门禁排除表同源 + 完备性由 T17 判定」；T17 `<verify>` 增完备性断言：枚举 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-*.md` 的**实际存在**文件，逐个 `grep -qF` 于门禁脚本 `$S`，缺一即红；并断言枚举数 ≥ 1（防空转）。

### m9 · T04（minor）— **finding 与工件不符（反驳，不修改）**

finding 称「T04 verify 首行未 `export LC_ALL=C`」。**实测工件原文**（`TASK.md`，T04 `<verify>` 段第 1 行）：

```
    export LC_ALL=C;
```

该行自 T04 定稿起即在首行，未在任何轮次被删除。按 **ADR-027**（已知可接受项不得升级为 fail；应在信息面上澄清），此处以原文 + 行号反驳，不做修改；若审查者所指为「应断言 `LC_ALL` 生效」而非「未 export」，则属新诉求，请在第 6 轮明确指出目标断言形态。

### m10 · T24（minor）— 归档内容同源断言

**Fix。** `<verify>` 增：`pre=$(tar tzf … | grep -E '(^|/)hooks/pre-push/pre-push\.sh$')`；**必须**含 `dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh`（缺则红）；顶层 `dsh-flow-kit/hooks/pre-push/pre-push.sh` 缺失只打 **ℹ️** —— 理由是 `package-flow-kit.sh` 的 Part C **没有 pre-push stanza**，而该脚本**不在本 change 的写面**（`DESIGN.md` §0.5.1），改它属范围扩张；该缺口已登记为 **TD-048**（见下）。另对归档内每个 pre-push 成员断言：内容含 `make check`、`tar tvzf` 模式为 `-rwxr-x---`/`-rwxr-xr-x`。

**TD-048（本轮新增登记）**：`package-flow-kit.sh` Part C 仅有 pre-tool-use / pre-commit / stop / session-start 拷贝段，**无 pre-push stanza**；且 `dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/` 由 `sync-hooks.sh` 的 dist DEST_ROOT 维护 ⇒ 安装器路径不受影响（`install_hooks.sh` 的 `HOOK_SRC` 指向 vendor 树）。本 change 内**不修**（越写面），已写入 `.specs/CONTEXT.md`。

### m11 · chisel 残留无定位（minor）— **两处一起修**

**Fix。** 复核发现同一形态在 **T10（`TASK.md:269`）与 T27（`:1009`）各有一处**（finding 只点了 T27）⇒ 两处一起改为：

```
    hits=$(grep -rn chisel test/ flow-kit-bundle/test/ 2>/dev/null || true);
    [ -z "$hits" ] || { printf '%s\n' "$hits" | head -10; echo "🔴 源测试仍含 chisel（命中如上，file:line —— 阶段 3 L3 m11：原写法只报一句、不给定位）"; exit 1; };
```

（`count==2` 断言下整体替换，避免只修被点名的一处。）

### m12 · T08（minor）— 漂移夹具的残留防护

**Fix。** 加 `trap 'cp -f /tmp/gs-bak "$F" 2>/dev/null' EXIT`（中途被 kill 也不留漂移），并在恢复后加 `cmp -s "$F" /tmp/gs-bak` 断言（未逐字节恢复即红）。

### 机械执行与验证（全部实跑，非「应该可以」）

| 检查 | 结果 |
| --- | --- |
| `/tmp/fix_r5.py` | 首跑 2 处锚点不符（#5 前缀、#25 count=2）⇒ **未写入任何改动**（原子性生效）；修正锚点后 `applied 26 replacements` |
| `TASK.md` 规模 | **1270 行** / `<task id=` **29** / `<verify>` **29** |
| 29 份 `<verify>` 抽取 + `bash -n` | 行级锚定正则抽到 `/tmp/tv6/T01.sh…T29.sh`；**失败 0** |
| `parallel` 计数 | 行内 `true` **26** / `false` **3**（T19、T23、T29），与自检表第 5 行一致 |
| PAT 复扫 `TASK.md` | `LC_ALL=C grep -nE '/home/[a-z_][a-z0-9_-]*/'` − 通用占位符 ⇒ **0 行** |
| T13 段 `$AUTH` 残留 | **0**（写面权威已统一为 `$FACE`） |
| 归档实测 | `dist/dsh-flow-kit-0.2.0.tgz` 当前含 `hooks/pre-tool-use/runtime-edit-guard.sh`（顶层 + vendored，模式 `-rwxr-xr-x`），`hooks/pre-push/` 命中 0（源文件由 T11 产出）⇒ 故 T24 的断言写成「vendored 必须有、顶层缺则 ℹ️ + TD-048」 |

### 边界（诚实声明）

- 依赖 4-dev 产物的**整段首跑**仍待阶段 4：T09（需 T10 的 SUT 改写）、T19（需 T11/T16/T17/T18/T21/T22/T23/T26 产物）、T26/T28（需 T21/T22/T23 与 Makefile 接线）。本轮可证的是：抽取完整性、`bash -n`、PAT 复扫、`$FACE` 残留、计数与依赖关系一致性、以及各判据的内部分支语义。
- 未写任何握手凭证（由子系统在 L3 通过后写）。

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-23 09:49）

> 自动生成于 2026-09-23 09:49。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "TASK.md",
      "issue": "T09 的 verify 用 `touch \"$td2/tmp.zz-inject\"` 注入残留并以 `TMPDIR=\"$td2\"` 驱动 bats，但 write_files 只声明 4 个 bats 文件与仓库外沙箱，未定义 test_combined_metric.bats 的 SUT 扫描面；注入态与健康态共用同一 TMPDIR 面，无法证明「注入残留 ⇒ 必红」是由 SUT 对残留敏感而非环境差异造成，且未声明对 bats 内部扫描逻辑的具体改动边界。",
      "why": "AC-7 判据要求「注入失败源 ⇒ 必须变红、无残留 ⇒ 必须绿」两态可区分；若 SUT 扫描面就是 ${TMPDIR:-/tmp}，则注入残留同时存在于注入态与健康态所在的同一面，两态区分不成立；write_files 也未覆盖为实现该判据所需的对 bats 扫描逻辑的改动。",
      "fix": "在 T09 中显式声明 test_combined_metric.bats 的扫描面与 SUT 实际读取的临时区一致，verify 注入夹具必须落在该区内且健康态/注入态使用同一 TMPDIR；或将扫描面改为 SUT 可配置的独立目录，并在 write_files 中明确该 bats 内扫描逻辑的改动边界。"
    },
    {
      "file": "TASK.md",
      "issue": "T13 的 verify 用 `$AUTH` 正则作为 T13 条件写面的「唯一权威定义」，但 `$AUTH` 几乎涵盖所有后续 task 的写面（Makefile、sync-hooks.sh、check-path-privacy.sh、所有 bats、health 档等），使 T13 实际可写范围 = 整个 change 的写面；同时 T13 的 write_files 只声明 3 个静态路径 + 条件写面，verify 授权与 write_files 边界不一致，越界判定形同虚设。",
      "why": "write_files 应明确每个 task 可写的具体文件；T13 用 verify 段正则动态定义授权面，等于允许 T13 替所有 task 就地改件，task 边界消失，4-dev 无法按 write_files 判断越界。",
      "fix": "将 T13 条件写面收窄为「仅 DESIGN.md/REQUIREMENT.md/.specs/health/*.md + TASK.md 自身 de-shape」等明文路径；残余命中落在任何其他文件 ⇒ 一律升级为新 task，不允许 T13 就地修改；$AUTH 仅用于校验 change 全局授权面，不作为 T13 自身写权限。"
    },
    {
      "file": "TASK.md",
      "issue": "T29 的 depends_on 未显式包含 T08/T14/T15（check-gate-sync 修复与接线、bats 断言收紧），而 T29 verify 仅跑 `make check` 全绿；若 T14 未接线，`make check` 不含 check-gate-sync，T29 可在旧门禁集上全绿，AC-8 的「无退化」判据被架空。",
      "why": "AC-8 要求最终 `make check` 的组成包含所有修复后的门禁；T29 依赖链虽可经 T20/T25/T26/T28 间接回溯到 T08/T14/T15，但 plan 层面未显式保证，执行器只按字面 depends_on 执行时可能跳过这些 task。",
      "fix": "在 T29 的 depends_on 中显式增列 T08、T14、T15，或在 T29 verify 中先断言 `make -n check` 同时含 'check-gate-sync' 与 'check-path-privacy' 再跑 `make check` 全绿。"
    }
  ],
  "major": [
    {
      "file": "TASK.md",
      "issue": "T23 的 verify 直接向常设权威清单 path-privacy-allowlist.txt 追加畸形行与探针行，但 write_files 只声明 .specs/adr/028 与 check-path-privacy.sh，未声明对该清单的临时写面；且恢复后未做 `cmp -s` 逐字节一致性断言，trap 保护不完整。",
      "why": "权威清单是 T21 冻结产物，T23 同 T26 一样属于受控临时改写，但没有同等协议；若中途 kill 或恢复失败，常设基线被污染且不会被发现。",
      "fix": "在 T23 write_files 中显式声明对 path-privacy-allowlist.txt 的受控临时写入（先备份、失败分支恢复、恢复后 cmp -s 断言），或在 verify 末段补 `cmp -s \"$A\" /tmp/al-fmt-bak` 与 CONTEXT.md 的一致性断言。"
    },
    {
      "file": "TASK.md",
      "issue": "T19 的 verify 夹具复制「已冻结权威清单」与 check-path-privacy.sh，但 T19 depends_on 只到 T21，不含 T22/T23；T22/T23 会继续修改 check-path-privacy.sh 的空基线分支与格式校验，T19 验证的是中间态门禁，与最终门禁脱节。",
      "why": "AC-3 端到端拦截应建立在最终门禁上；T22/T23 若改变脚本行为或引入回归，T19 不会重跑，导致 AC-3 判据假绿或假红且不被发现。",
      "fix": "将 T19 的 depends_on 增列 T22、T23（或将 T19 移入 T22/T23 之后的 wave），确保夹具复制的是最终定稿脚本与清单；或在 T29 中重跑四形态拦截。"
    },
    {
      "file": "TASK.md",
      "issue": "T25 的 verify 假设 `~/.claude/hooks/pre-tool-use/runtime-edit-guard.sh` 是本机实际执行的一份且由 sync-hooks.sh 覆盖，但 T25 write_files 未声明该路径的同步动作，也未断言 `~/.claude/hooks` 在 6 个 DEST_ROOT 中；哨兵测试的 `|| true` 吞掉 hook 非零退出，可能造成假绿。",
      "why": "AC-1 要求「本机实际执行的那一份」无 RCE；若 ~/.claude/hooks 不在同步面或同步失败，哨兵测试跑的是旧版/未更新 hook，verify 仍可能通过。",
      "fix": "在 T25 action/write_files 中显式声明 `~/.claude/hooks` 由 sync-hooks.sh 覆盖且属于 6 面之一，或在 verify 哨兵测试前 `bash sync-hooks.sh --list | grep -q \"$HOME/.claude/hooks\"`，并去掉 `|| true` 改为同时断言 hook rc 与哨兵不存在。"
    },
    {
      "file": "TASK.md",
      "issue": "T28 的 action 声明 rc=3 为 SKIP 只提示不阻塞（if 包装接入 make check），但 verify 把落地态 rc=3 判为失败（exit 1）；若合法变更没有新增 .sh 行（如只改 bats），T28 verify 必红，产生假失败，且与「变更集非空守卫在 T29」的职责划分矛盾。",
      "why": "action 与 verify 的退出码语义冲突：同一 rc=3 在 make check 中应提示、在 T28 verify 中却失败，执行器无法一致执行。",
      "fix": "统一语义：T28 verify 对 rc=3 分支改为提示并 pass，由 T29 的变更集非空守卫兜底；或把「变更集非空」作为 T28 的前置条件并在 verify 中显式声明。"
    },
    {
      "file": "TASK.md",
      "issue": "T13 的 verify 排除审查档只列 INDEPENDENT-REVIEW-(1|2|3).md，与 T17 门禁的排除表口径未绑定；若存在其他编号审查档或后续新增审查档，T13 复扫与门禁排除表会漂移。",
      "why": "AC-6 前置扫描与门禁排除表必须一致；两处分别枚举易漏，且 T17 已声明「后续阶段新增审查档逐条追加」，T13 未声明同样机制。",
      "fix": "让 T13 verify 读取 T17 门禁的排除表作为唯一来源，或显式声明与 T17 相同的逐条追加规则。"
    }
  ],
  "minor": [
    {
      "file": "TASK.md",
      "issue": "T04 verify 未 export LC_ALL=C，与其他 task 风格不一致。",
      "why": "grep 正则受 locale 影响，可执行性在不同环境可能不一致。",
      "fix": "在 T04 verify 首行补 `export LC_ALL=C`。"
    },
    {
      "file": "TASK.md",
      "issue": "T24 verify 只断言归档内 eval-echo/chisel 计数为 0，未验证归档内容与修复后源树同源（如 pre-push.sh 存在、含 make check、755 位）。",
      "why": "若 0.2.0.tgz 是手工构造的干净归档或旧源打包，计数为 0 也会通过，AC-5 同源要求未闭环。",
      "fix": "在 T24 verify 中增加对归档内 hooks/pre-push/pre-push.sh 存在且含 make check、runtime-edit-guard.sh 无 eval 的具体文件断言，或对比归档内文件与源树哈希。"
    },
    {
      "file": "TASK.md",
      "issue": "T27 verify 在 `grep -rq chisel` 失败分支只报「源测试仍含 chisel」，未输出命中 file:line。",
      "why": "无命中路径指引会降低可执行性，且与 AC-4 要求漂移指名 file:line 的风格不一致。",
      "fix": "将 `grep -rq` 改为 `grep -rn` 输出命中列表后再 exit 1。"
    },
    {
      "file": "TASK.md",
      "issue": "T08 verify 修改 A-evolve.md 制造漂移后 `cp /tmp/gs-bak \"$F\"` 恢复，但没有 trap 保护，若中途被 kill 会残留漂移，后续 task 全部假红。",
      "why": "D4 要求探针/夹具先备份且失败分支亦恢复；T08 未用 trap 或恢复后 cmp 断言。",
      "fix": "在 T08 verify 加 `trap 'cp -f /tmp/gs-bak \"$F\"' EXIT` 并在末段 `cmp -s \"$F\" /tmp/gs-bak` 断言恢复。"
    }
  ],
  "verdict": "fail",
  "summary": "任务拆解覆盖 AC 且依赖基本无环，但 T13 条件写面与全局授权面混同、T09 注入判据与 SUT 扫描面对应关系未定义、T29 未显式依赖门禁接线 task，以及 T19/T23/T25/T28 存在夹具时点、临写边界或退出码语义缺口，write_files 边界与 verify 授权多处不一致，按盲审标准不通过。"
}
```

L3_artifact_hash: 862e592be58724441a50917bc8cd1c17621c8e7abe66848c8ac76e2717c34207

<!-- /L3-SECTION -->

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-23 09:54）

> 自动生成于 2026-09-23 09:54。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [],
  "minor": [
    {
      "file": "TASK.md",
      "issue": "T19 的 verify 中 `git push origin main` 可能因 remote 已有 main 而报 non-fast-forward，从而在 hook 未拦截时也非零退出；虽然随后 `mv .git/hooks/pre-push` 的归因对照可以区分，但四形态断言先于归因对照执行，可能产生误报或掩盖真实拦截失败原因。",
      "why": "前置断言 `[ \"$rc\" -ne 0 ]` 会把任何 git 错误都当成拦截成功，只有后续归因对照才排除该混淆；若 remote 状态或夹具顺序导致 fast-forward 拒绝，四形态的「被拦截」断言可能假绿。",
      "fix": "在四形态断言前先确保 remote 无 main（或先 push 一次并 reset），或在每形态失败后校验 stderr 含泄漏 ref 指名而非 generic git 错误；或将归因对照提前到四形态之前。"
    },
    {
      "file": "TASK.md",
      "issue": "T22 verify 中探针恢复依赖 `cp -f`，但未对恢复结果做 `cmp -s` 逐字节断言；若探针写入同时污染了其它内容或恢复源本身已损坏，残留可能静默通过。",
      "why": "T22 自身要求「失败分支亦先恢复」和 D4 纪律，但 verify 只检查 make 命令结果，未验证 tracked 文件恢复后的完整性；T23/T26 有 `cmp -s`，T22 缺少同等强度。",
      "fix": "在 T22 verify 末段对 `.specs/CONTEXT.md` 增加 `cmp -s` 逐字节恢复断言，并在 trap 中同样确保恢复。"
    },
    {
      "file": "TASK.md",
      "issue": "T23 write_files 列出 `.specs/adr/028-gate-baseline-allowlist.md`，但 AC↔task 映射表中未单列该文件对应的 AC 判据，仅通过 done 描述覆盖；边界归属表也未将该路径列入显式例外表。",
      "why": "该路径不属于 DESIGN §0.5.1 字面条目，虽在 Plan-Conflict Scan 的显式例外表中提及，但 write_files 边界归属表中缺失该行，可能造成 4-dev 步骤 5 越界校验误判或后续审查遗漏。",
      "fix": "在「write_files 边界归属」显式例外表中补列 `.specs/adr/028-gate-baseline-allowlist.md` 及其授权来源。"
    }
  ],
  "verdict": "pass",
  "summary": "任务拆解完整覆盖 REQUIREMENT 全 AC，depends_on 无环且波次自洽，verify 均可执行可证伪，write_files 边界清晰且逐条归属 DESIGN 触碰面；仅存少量可改进的 verify 细节。"
}
```

L3_artifact_hash: e2e35c410437ec8365db4d8f8d08de74bba584e7f65b03394b4dc52f3072b57c

<!-- /L3-SECTION -->
