# 阶段 6 · REVIEW — health-fix-2026-09b

**⚠️ 现行结论（阶段 6 · 2026-09-28 · 唯一权威结论行 · L3 第 22 轮 major ① 收口）**：**阶段 6 已闭合** —— **L2 第 1/2 轮 = pass**（第 2 轮为 `T-FIX-25` 后的增量复审）· **L3 第 22 轮 = pass**（critical 0 · 3 major + 4 minor 均为「可改进项，不构成放行阻断」，逐条处置见 `INDEPENDENT-REVIEW-6.md` 的对应响应段）· 判据面/门禁面见 `PHASE5-RECEIPTS.md` §U/§U-5 ⇒ **AC-9 = ⚠️ 有条件通过**（AC-8 跨 OS 实机面未验证 · `TD-055` 开放 · 不阻塞但不得读作 AC-8 通过）。**下列历史 verdict 行按轮次读，不再是本阶段的现行结论**：

**（历史）verdict（阶段 6 第 19–21 轮 · L3 未通过时点）: fail** —— L2 第 1 轮 = `pass`；**L3 第 19/20/21 轮 = `fail`**（第 19 轮 2 major、第 20 轮 2 critical + 3 major + 3 minor、第 21 轮 1 critical + 2 major + 3 minor），逐条处置见 `INDEPENDENT-REVIEW-6.md` 的三段「主 agent 响应」与 §H.3 结论（**L3 `pass` 之前不构成 6→7 放行依据**）；L3 第 21 轮的 critical 属**机制自引用**（工件里可见的 L3 判定永远是上一轮，见 `TD-105`）⇒ 已提请用户裁决。**下列历史 verdict 行按轮次读，不得当作现行结论**：

**verdict（第 3 轮 · 历史）: fail** —— 审查面扩到「2 个独立审计 subagent 的对抗式深审 + 主 agent 逐条亲验」后，在 fix 循环后的 HEAD `7b624dc` 上共得 **5 🔴 Critical + 13 🟡 Important + 12 🟢 Minor**。五条 🔴 全部由主 agent **独立复跑夹具坐实**：R3-1/R3-2（本 change 新建的 `check-path-privacy.sh` 的 C 引号化静默跳过 + index/工作树内容面错配 ⇒ 假绿，后者直接击穿本 change 自身的 `pre-commit.sh:33 → Makefile:127` 拦截链）· R3-14（`pre-push`/`pre-commit` 在消费者项目 fail-closed ⇒ 拒一切 push/commit，且使 ADR-027② 失效）· R3-15/R3-16（NFR 门禁 `realpath` 死模式 + 未加引号 `for` 静默跳过 ⇒ 假绿）。⇒ **出口 = 回退 `4-dev`，追加 `T-FIX-07` … `T-FIX-10`**（分解见 §0″.6）；12 条 🟢 入 `MINOR-DEFERRED.md` 交阶段 7 triage。

**verdict（第 2 轮 · fix 循环后重审）: pass** —— 第 1 轮的 2 条 🔴 + 6 条 🟡 已**全部闭合并逐条活性重放**；9 条 🟢 维持 `MINOR-DEFERRED.md`；第 2 轮另增 **3 条 🟡**（F-18 扫描面标签过度声明 · F-19「0 实际扫描」仍报 ✅ · F-20 `mktemp` 立即终止未生效）——**三条均经用户裁决在本 change 内修**（F-18 = 只改措辞；F-19 + F-20 = 同批修复）⇒ 已回退 4-dev 追加 `T-FIX-06`，修后重跑 5-test → 6-review；深审 🟢 F-21（jobserver 警告）裁决 `Not-applicable` 并登记 `MINOR-DEFERRED.md`。

> **第 1 轮（历史）** = 下方 §0 … §G：`verdict: fail`（2 🔴 + 6 🟡 + 9 🟢），修复出口 `T-FIX-03`/`T-FIX-04`/`T-FIX-05` → `4-dev`。
> **第 2 轮（历史）** = §0′：`verdict: pass`（0 🔴 + 3 🟡），出口 `T-FIX-06`。
> **第 3 轮（历史）** = §0″：`verdict: fail`（5 🔴 + 13 🟡 + 12 🟢），出口 `T-FIX-07`…`T-FIX-11` → `4-dev` 修复循环。
> **第 4 轮（历史 · 已闭合）** = §0‴：`verdict: pass` —— 输入面三条全部闭合：`R4-1`（过严红）⇒ `T-FIX-11` / `38f3a38`；`R4-2`（🔴 NFR 预算回归 221.6%）⇒ `T-FIX-12` / `c177fba` + docs `280ffdc`（REPRO10 五次实测均值 **3.609 s = 72.2%**）；`R4-M1`（🟡 bundle 形态 fail-open）⇒ `T-FIX-13` / `ee0df5c`（判据 53 行 rc=0 + 常设 bats 3 例）。复核面 = 阶段 5 第 11 次执行 REPRO10（判据 25/25 + 门禁 7/7）+ L2 第 5 轮（pass）+ L3 第 14–17 轮（pass）。
> **第 5 轮（本轮 · 正式阶段 6 入场）** = §0⁗：审查面 `534e3e8…HEAD`（99 提交 / 106 文件 / +29571 −157）；审查方式 = review-package 全量 + 3 个独立只读审计 subagent + 主 agent 逐条亲验；结论见 §0⁗.6。

- **审查对象（第 2 轮）**：`534e3e842fc900045f39492badc66eabe3ffd4c4` … `HEAD`（`cb21c03`）
- **变更规模（第 2 轮）**：全量 **95 files / +24300 / −153**；fix 循环 3 提交 = `6e39cfb`（`T-FIX-03`）/ `521b21c`（`T-FIX-04`）/ `6e94d60`（`T-FIX-05`）
- **审查者**：主 agent（Reviewer）· 遵守 **R3.3 = 本次审查未修改任何代码**（仅生成本文件 + `MINOR-DEFERRED.md`）
- **动态门禁判定（AC-9）**：**✅ 通过**（0 条 🔴 Critical；🟡 F-18 按 `6-review.md:294` 非阻塞）。**注**：本判定属第 2 轮快照（HEAD `cb21c03`）；用户已裁决 F-18/F-19/F-20 在本 change 内修 ⇒ 该快照的 AC-9 结论将在 `T-FIX-06` 落地后的重审中重新出具。
- **spot-check（ADR-014）**：第 1 轮已触发并完成（`INDEPENDENT-REVIEW-6.md` 的 `## Cross-Model Spot-Check` 段）；本轮 `verdict=pass` ⇒ **无新触发条件**

---

## 0⁗. 第 5 轮审查（阶段 6 正式入场 · 单轮合并审查 · HEAD `1b5a9c3`）

> **状态**：本轮 = 阶段 5 收口（`1b5a9c3`）之后、toll-gate 6→7 之前的**正式阶段 6 审查**；审查面 = `534e3e84…HEAD` 全量（99 提交 / 106 文件 / **+29571 −157**）。

### 0⁗.1 审查面与运行标识

| 项 | 值 |
| --- | --- |
| reviewed revision | `1b5a9c39a3064ce329c10b381a82123594aad792`（= HEAD） |
| 基线 | `534e3e842fc900045f39492badc66eabe3ffd4c4`（`.specs/health-fix-2026-09b/.change-base`） |
| 变更规模 | 全量 **106 files / +29571 / −157**；生产件面（`reference/` + `hooks/` + `lib/` + `install.sh` + `sync-hooks.sh` + 打包脚本 + `Makefile`）**14 files / +1862 / −98** |
| 提交数 | **99** |
| review-package | `bash flow-kit-bundle/flow-kit/scripts/review-package 534e3e84… HEAD > /tmp/p6d/review-pkg.md`（31,984 行 · 三段 = Commits / Files changed / Diff） |
| 阶段态 | `.flow-active`：`phase=6` · `phases_done=[0..5]` · gates `0→1…5→6` 全 `passed` · `auto_advance=false` |
| 审查者 | 主 agent（Reviewer）· 遵守 **R3.3 = 本轮审查未修改任何代码**（仅写本文件 + `MINOR-DEFERRED.md`） |
| 已知未覆盖项（**不重复计为发现**） | `TD-061` 行/分支覆盖率 · `TD-055` macOS 实机 · `TD-056` 安全工具面 0/10 · `TD-033` mock 用例 · `TD-069` L3 提示词截断（仅 stderr 告警且不能强制重审） |

### 0⁗.2 第 4 轮发现闭合表（输入面 → 本轮复核）

| 第 4 轮 | 级别 | 出口 | 本轮复核证据（主 agent 亲验） |
| --- | --- | --- | --- |
| `R4-1` 过严红：候选在 index 侧可读但工作树缺失 ⇒ 被判「不可读」报红 | 过严红 | `T-FIX-11` / `38f3a38` | 主 agent 16 腿夹具 16/16 · 常设 `test_path_privacy_gate.bats`（**30 ok / 0 not-ok**）· REPRO10 隐私门禁 候选 **1602** / 实际扫描 **1596** / 命中 **0** / 清单外 **0** ✅ |
| `R4-2` **NFR 预算回归**：`make check-path-privacy` 均值 11.078 s = 预算 221.6% | 🔴 | `T-FIX-12` / `c177fba` + docs `280ffdc` | REPRO10 五次实测 **3.489 / 3.666 / 3.660 / 3.613 / 3.615 s**（max 3.666 · 均值 **3.609 s = 预算 72.2%**）✅ · 自证四数 候选 1602 / 扫描 1596 / index 侧 14 / 不可读 0 ✅ · 全 index 批量面与候选面同集合（`git ls-files -z --` 无 pathspec）· fail-closed 保留（批量 `git grep` rc≥2 ⇒ `🔴 无法完成扫描` exit 1） |
| `R4-M1` 🟡 bundle 形态 fail-open：检查器在 `reference/` 内、允许清单缺失 ⇒ 打印「未找到可用的路径隐私检查器」且 **rc=0 放行** | 🟡 | `T-FIX-13` / `ee0df5c` | **缺陷态 / 绿态并排重放**（`/tmp/p6d/r5-r4m1-replay.txt`，主 agent 于 HEAD 亲跑）：缺陷形态（检查器在、清单缺）⇒ `pre-push` **rc=2** + `🔴 …找到路径隐私检查器但缺少允许清单：<路径>（无法确定扫描基线 ⇒ fail-closed，推送被拒绝）`；`pre-commit` **rc=1** + `…提交被拒绝`；而「检查器真的不存在」形态仍为 `rc=0` + `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描`（**成因不再错位**）· REPRO10 判据 `T-FIX-13` 53 行 rc=0 · 常设双源 bats 3 例 · 判据修订留痕见 `TASK.md` 块内「判据修订留痕」与 `TD-081` |

### 0⁗.3 只读深审回执（3 个独立审计 subagent + 主 agent 逐条亲验）

#### 0⁗.3.1 主 agent 亲验（HEAD `1b5a9c3` · 全部本机实跑 · 留存 `/tmp/p6d/r5-main-findings.md`）

| 面 | 复算命令（原样） | 实测 | 目标 / 判读 |
| --- | --- | --- | --- |
| AC-1（窄 pattern） | `grep -rEn '\$\([[:space:]]*eval[[:space:]]' flow-kit-bundle/ \| wc -l` | **0** | 0 ✅ |
| AC-1（宽 pattern · 仅存证） | `grep -rn '\beval\b' flow-kit-bundle/hooks/ \| wc -l` | **1** | 唯一命中 = `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh:50` 的**注释**（修复说明）✅ |
| AC-2 | `grep -c mktemp flow-kit-bundle/lib/install_hooks.sh` · `grep -c 'command -v jq'` 同文件 | **2** · **4** | ≥1 · ≥2 ✅ |
| AC-4 | `bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` | **rc=0**（25 行 stdout） | 0 ✅ |
| AC-5 | `grep -rc chisel flow-kit-bundle/test/` | 命中文件 **0** | 0 ✅ |
| AC-6 | `grep -c 'check-path-privacy' Makefile` · `grep -cE 'path\|隐私\|leak' flow-kit-bundle/hooks/pre-commit/pre-commit.sh` | **8** · **17** | ≥1 · ≥1 ✅（**仅静态接线计数**：不证路径可达。审计 B 的 `R5-18`/`R5-19` 已证明该接线的**消费者落地形态不可达** ⇒ 本行判读降级为 ⚠️ **证据不足**，AC-6 的最终判读以 §0⁗.3.2 的端到端实测为准） |
| AC-7 | `test_combined_metric.bats` 恒真形态命中 · `test_lessons_cleanup.bats` 活动 `skip` 命中 | **0** · **0**（命中行均为注释） | 已消除 ✅ |
| AC-8（静态面） | 本机三套关键 bats（本次独立实跑，非引用 REPRO10） | `test_archive_commit_gate.bats` **45 ok / 0 not-ok** · `test_path_privacy_gate.bats` **30 ok / 0 not-ok** · `test_check_gate_sync.bats` **11 ok / 0 not-ok** | 0 not-ok ✅ |
| 冻结件面 | `git log 534e3e84..HEAD -- <冻结件>` 逐文件计数 | CHANGE 1 · REQUIREMENT 1 · IR-1 1 · IR-2 1 · IR-3 1 · DESIGN 2（`a674c56` T01 修订史搬移 / `7d9a086` T13 路径脱敏，均在阶段 4 内且有对应 task） | 阶段 5/6 **未再改动** ✅ |
| 分发面 | `git diff --name-only 534e3e84..HEAD -- dist/` | **空** | `dist/` 不入库（`make check-dist` 管）✅ |
| 台账面 | `jq -r '.goal.task_progress[]\|.commit_sha' .flow-active \| git cat-file -e` + 规则 9 计时 | 见 §0⁗.4 的 `R5-1` / `R5-2` · 规则 9（Δ ≤ 120 s）四条全合规（Δ = 10 / 4 / 30 / 6 s） | ⚠️ 两条发现 |
| 镜像一致性 | `grep -cE '^[[:space:]]*@test'` 于 `test/` vs `flow-kit-bundle/test/` | `test_archive_commit_gate` 45/45 · `test_check_gate_sync` 11/11 · `test_path_privacy_gate` 30/30 | 双源一致 ✅ |
| 修复回放（`R4-M1`） | `bash /tmp/p6d/r4m1-probe.sh` | 缺陷形态：`pre-push` **rc=2** + `🔴 …缺少允许清单…推送被拒绝`；`pre-commit` **rc=1**；对照（检查器真缺）仍 `rc=0` + `ℹ️ …跳过内容扫描` | 成因归位 ✅（存 `/tmp/p6d/r5-r4m1-replay.txt`） |
| 修复回放（`T-FIX-13`） | `bash /tmp/p6d/tfix13-main-verify.sh` | `main-agent independent verify rc=0` | ✅（存 `/tmp/p6d/r5-tfix13-replay.txt`） |

#### 0⁗.3.2 审计 A / B / C 回执（3 个只读 subagent）

**审计 C（规格合规 + 测试质量面）** — agent `8193e6bc-dac2-411f-b2ee-bb4471286d2f` · 只读 · 只写 `/tmp/audit6/C/` · 被审工件 = HEAD `1b5a9c3` ⇒ **`verdict: fail`**（2 🔴 + 4 🟡 + 3 🟢 ⇒ 见 §0⁗.4 的 `R5-6` … `R5-13`）。判定依据 = 仓库自身先例：`CHANGE.md:161-171` 已判定 TD-053（「门禁失效而 `make check` 仍绿」）**与 pass 不可并存**，而本轮的 AC-2 / AC-3 属同类缺口且 `TEST.md` 把「无覆盖」登记成 ✅。
其独立实跑（未跑全量 bats / `make check`，受审令禁止）：`npx bats --count test/` = **1064** ✓；新+改 10 件逐跑 **157 ok / 0 not ok / 0 skip**；`diff -rq test/ flow-kit-bundle/test/` 无输出（76 份两树一致）；AC-1 六面 + 源树 + `dist/dsh-flow-kit-0.2.0.tgz`（`tar xzOf | grep -acE`）全 **0**；AC-2 的 `T06` 判据抽取复跑 **rc=0**；`check-gate-sync.sh` **rc=0**（3/14 对一致 + 17 预设）；`check-path-privacy.sh` **rc=0**（候选 1602 / 扫描 1596 / 命中 0 / 清单外 0）+ `time` **3.850 s = 77%**；`sync-hooks.sh --check` **rc=0**。范围核查结论：**无未声明 scope creep**（AC 外的 `done-validation.sh` +16 与 `l3-prompt.sh` +35 已在 `CHANGE.md:160-176` / `DESIGN.md:42`/`:523` 登记；`DESIGN.md:40`/`:66`/`:74-79` 预声明全部触点）。

**审计 A（隐私 / 门禁 reference 面）** — agent `d8035b32-a45e-4bbc-9330-ee1a0f766153` · 只读 · 只写 `/tmp/audit6/A/` · 被审面 = `check-path-privacy.sh`（923 行新件）/ `check-gate-sync.sh` / 两份 allowlist / `Makefile` 的 `check*` 目标 / `package-flow-kit.sh`（+4 行）· base `534e3e84` → HEAD `1b5a9c3` ⇒ **`verdict: fail`**（2 🟡 + 1 🟢 新缺陷 ⇒ §0⁗.4 的 `R5-14`…`R5-17`，另建议一条定级上修）。主线 fail-closed 收敛**大体成立**：`F1`/`F2`/`F3`/`F5`/`F6`/`F7` 逐项实测复核**通过** · `check_pair()` 具名定位有效（prompt 尾部追加 ⇒ `定位: prompts/A-evolve.md:343`；正文中间改行 ⇒ `:40`；均 rc=1）· NFR 三态包装 rc 契约实测正确（stub 写 0⇒rc=0 · 1⇒报文透出且 make 层 rc=2 · 3⇒`SKIP: …（未验证，非通过）` rc=0 · internals 崩溃⇒rc=2 fail-closed）· 允许清单读序与 `DESIGN.md:372` 定稿一致 · gitlink 候选按设计判红。**未能证实**：bash 3.2 实机（TD-055）· 大 diff 下 SIGPIPE 早退 · 消费者 `install.sh --project` 后 SELF_EXCLUDE 前缀失配（⇒ 该面由审计 B 覆盖并命中 `R5-18`）。

**审计 B（钩子与安装器面）** — agent `2283d3f3-9d58-4d2b-bc70-e9e8c2218e90` · 只读 · 只写 `/tmp/audit6/B/` · 被审面 = `flow-kit-bundle/hooks/**` / `lib/install_hooks.sh` / `lib/validate_staging.sh` / `install.sh` / `sync-hooks.sh` · base `534e3e84` → HEAD `1b5a9c3` ⇒ **`verdict: fail`**（**1 🔴** + 5 🟡 + 2 🟢 ⇒ §0⁗.4 的 `R5-18`…`R5-25`）。其 🔴 的严重性经主 agent **扩面复核**：不止 symlink 形态，**安装后的真实脚本路径亦不可达**（详见 `R5-18` 证据）。其余 5 🟡 = `R5-19`…`R5-23`；2 🟢 = `R5-24`/`R5-25`。审计 B 的 sandbox 安装（`install.sh --platform claude --project … --hooks-only`）与 `bash -n` 13 脚本全过；探针全在 `/tmp/audit6/B/`，仓库内零写。

#### 0⁗.3.3 跨模型 spot-check 回执（ADR-014 · 第 5 轮）

**触发**：`6-review.md:298-308` —— 本轮 verdict = `fail` 且 🔴 ≥ 1（`R5-6` / `R5-7` / `R5-18`）⇒ 必须由**不同模型**重做一轮盲审，其 Critical 并入 fix loop。
**执行**：agent `8dd172a1-aef0-48dc-ade7-66909f671c8e` · provider `qwen-token-plan-cn` · model `qwen3.8-flash`（与 L2 盲审用的 `glm-5.2` 不同）· 只读 · 探针只写 `/tmp/spot6/` · 被审 HEAD = `1b5a9c3`（与三审计同一被审面）。
**结论**：**`Verdict: fail` · 🔴 2 · 🟡 1 · 🟢 1**；全文（含实跑命令与报文）见 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md` 文末 `## Cross-Model Spot-Check（第 5 轮 · 2026-09-27 · qwen3.8-flash）`。

| 该 agent 的发现 | 与本轮 `R5-*` 的关系 | 主 agent 处置 |
| --- | --- | --- |
| `F1` 🔴 AC-2 缺 jq 场景无常设 bats（`grep -rn "permissions" test/*.bats` = 0），并给出**变异实证**：删 `flow-kit-bundle/lib/install_hooks.sh:189-192` 与 `:356-359` 两道守卫后，缺 jq 下变异体 **rc=0** 且 4×`⚠️ …合并失败，请手动检查`（静默谎报成功），真实体 rc=1 + `❌ 缺少依赖 jq…已中止（尚未做任何写盘）` | = `R5-6` 的**独立确认**（同缺口 / 不同模型 / 不同判据路径），不新增编号 | 维持 🔴；`R5-6` 的 Remedy 增补「变异体必须转红」的反向控制（见该条 `跨模型确认` 行） |
| `F2` 🔴 pre-push 无常设行为级测试：变异体（`pre-push.sh:138-141` 畸形守卫 `exit 1`→`continue`、`:167-171` 泄漏拒绝→`scan_rev \|\| true`）上 `test_archive_commit_gate.bats` 的静态断言逐条重放**全绿**，而行为差分 REAL push rc=1 + `🔴 拒绝推送 refs/heads/main：该 ref 含路径隐私泄漏` vs MUTANT rc=0 | = `R5-7` 的**独立确认** | 维持 🔴；`R5-7` 增补「静态断言全绿 ≠ 行为守得住」的变异判据 |
| `F3` 🟡 AC-7 的删除注入不封闭：`test/test_independent_review_model.bats` 的 setup 存在 `FK_SRC_29="$HOME/.claude/hooks/stop/29-independent-review.sh"` 回落 ⇒ 删除 bundle 源件后 12 例仍**全绿**（只有**内容退化**注入才转红 1&4） | 新增 ⇒ `R5-26` | 入 fix loop（🟡） |
| `F4` 🟢 `TEST.md:55` 写「目标配置**字节不变**」与 `REQUIREMENT.md` AC-2 的断言面（未被截断为空 + allow 存活，「明确不是字节数不变」）冲突 | 新增 ⇒ `R5-27` | 登记技术债（🟢） |
| 自由猎取（AC-1/AC-4/AC-5/AC-6/AC-8 + 用例计数） | 复核为「真实执行 + 注入型覆盖」，声明成立；计数与 `TEST.md` 一致 | 与主 agent §0⁗.3.1 亲验一致（`R5-3` 的 4 处陈旧计数属 `TEST.md` 内部总结面，不改变该结论） |

**未验证边界（照录，不作补白）**：① 未跑全量 bats 与 `make check`；② `F1` 未复现原 PC2 的 0B 截断形态（现形态为「rc=0 + 谎报成功」）；③ 除 AC-7 外未逐文件做删除注入；④ `--all` / `--mirror` / `--tags` 三推送形态未单独驱动；⑤ 结论基于 HEAD `1b5a9c3`；⑥ 收工时 `git status --porcelain` 仅 4 个先期文档改动 ⇒ 该 agent 自身零写盘。


### 0⁗.4 第 5 轮发现（`R5-*`）

> 格式按 ADR-017：每条含 `**Severity**` + 四要素（Symptom / Source / Consequence / Remedy）。严重度行为规则见 `6-review.md:289-296`：🔴 阻塞 toll-gate · 🟡 入 fix loop 不阻塞 · 🟢 只入 `MINOR-DEFERRED.md`。

#### R5-1 · 台账重复条目携带未展开的 shell 替换（`commit_sha` 非 SHA）

**Severity**：🟡 Important
**Symptom（症状）**：`.flow-active.goal.task_progress` 共 **43 条 / 42 唯一 id**：`T-FIX-09` 出现两次，**首条** 的 `commit_sha` 是**字面量** `` `$(git rev-parse HEAD)` ``（shell 替换未展开，非任何提交对象），`completed_at=1790325853`；**次条** 才是真值 `81c920e61101f599bf9e29f7ec5bc3dbe429a887`（`completed_at=1790325860`，7 s 后）。用 `jq -r '.goal.task_progress[]|.commit_sha' | while read s; do git cat-file -e "$s^{commit}"; done` 复算时报 `MISSING: $(git rev-parse HEAD)`。
**Source（源头）**：`flow-kit-bundle/flow-kit/reference/commit-protocol.md:108-118`（ADR-015 五字段 schema：`id / commit_sha / fix_rounds / deferred / completed_at`）—— `commit_sha` 语义即提交对象 id；`4-dev.md:301-305` 同源。写入方式（单引号 heredoc 内嵌 jq 表达式）使替换未被求值。
**Consequence（后果）**：台账是本 change 的权威执行记录（`.flow-active` 不入库，只能靠条目自证）；一条映射到不存在提交的条目会让任何「台账 → 提交」复算、归档审计或后续 change 的追溯**误判**（复算工具要么报 MISSING 误以为提交丢失，要么静默跳过）。当前无 hook/script 消费 `task_progress`（`grep -rn task_progress flow-kit-bundle/hooks/ flow-kit-bundle/flow-kit/scripts/` = 0 命中）⇒ 影响限于人工/agent 审计面，不阻塞判据。
**Remedy（修补）**：删除首条伪条目，保留 `81c920e6…`；并在 fix 任务派发契约里把 `completed_at`/`commit_sha` 的取值方式固定为「先 `sha=$(git rev-parse HEAD)` 取真值，再以 `--arg` / `--argjson` 传入 jq」，禁止在 jq 程序串里写命令替换。建议 v2 在 `done-validation.sh` 增一条「台账 `commit_sha` 必须能被 `git cat-file -e` 解析」的机器校验（当前无任何校验）。

#### R5-2 · 台账 `completed_at` 类型漂移（epoch 数值 vs ISO-8601 字符串）

**Severity**：🟢 Minor
**Symptom（症状）**：同一张 `task_progress` 表内 `completed_at` 有**两种 JSON 类型**：**6 条数值 epoch**（`T-FIX-09` ×2 = `1790325853` / `1790325860`，`T-FIX-10` `1790327360`，`T-FIX-11` `1790330769`，`T-FIX-12` `1790339356`，`T-FIX-13` `1790507877`）与 **37 条 ISO-8601 字符串**（如 `2026-09-24T22:53:14+08:00`）。
**Source（源头）**：`commit-protocol.md:112` / `4-dev.md:301` 的范例值为 ISO 字符串（`completed_at: $ts`，`ts` 取自 `date -Iseconds`）；ADR-015 schema 只约束字段名，未约束类型 ⇒ 写入方各自解释。
**Consequence（后果）**：类型混合使按字典序/时间序比较的消费者行为不一致（`1790325853 < "2026-09-24T…"` 在 jq 里是类型序而非时间序）；本仓库当前无消费者，且两型可无损换算 ⇒ 不阻塞。
**Remedy（修补）**：把 6 条 epoch 归一为 ISO-8601（`date -d @<epoch> -Iseconds`），并在派发契约里写明 `completed_at` 必须是 `date -Iseconds` 输出；v2 可在 schema 校验里加类型断言。

#### R5-3 · 阶段 5 报告「总结面」的常设 bats 用例数系统性陈旧（4 处 · L-171 同族再犯）

**Severity**：🟡 Important
**Symptom（症状）**：`.specs/health-fix-2026-09b/TEST.md` §AC 覆盖表逐行声明的「常设 bats（N 用例）」在 HEAD 上与实测不符 **4 处**（实测命令 `grep -cE '^[[:space:]]*@test' <file>`）：

| 行 | 声明 | HEAD 实测 | 该声明对应的历史时点 |
| --- | --- | --- | --- |
| `TEST.md:56`（AC-3） | `test_archive_commit_gate.bats` **27 用例**（两处：证据列 + 回归列） | **45** | 27 = `88f7a0c`（T29 收口）时点值；其后 `2f01f39`（T-FIX-08）→ 42、`ee0df5c`（T-FIX-13）→ 45 |
| `TEST.md:57`（AC-4） | `test_check_gate_sync.bats` **5 用例**（两处） | **11** | 5 = `534e3e84` 基线值；`521b21c`（T-FIX-04）→ 7、`d840a12`（T-FIX-10）→ 11 |
| `TEST.md:59`（AC-6） | `test_path_privacy_gate.bats` **24 用例** | **30** | 24 = `421640a`（T-FIX-06）时点值；`T-FIX-11`/`T-FIX-12` 后 → 30 |
| `TEST.md:61`（AC-8） | 三件常设网合计 **46 用例**（30 + 9 + 7） | **53**（30 + 9 + **14**） | `test_nfr_portability_gate.bats` 已由 7 增至 14（`T-FIX-09` 等任务扩面）⇒ 该行自身的订正值即为陈旧值 |

（同表 AC-1 `test_runtime_edit_guard.bats` 9 与 AC-2 `test_install_coverage.bats` 17 实测吻合，故为**局部**陈旧而非全表失真；`test/` 与 `flow-kit-bundle/test/` 双源镜像计数一致，排除镜像漂移。）
**Source（源头）**：`flow-kit-bundle/flow-kit/prompts/6-review.md:100-107`（spec 合规判定须以工件为准）· `.specs/LESSONS.md` **L-171**「审查者读的是工件而不是历史：总结面（发现表 / 索引计数 / AC 简报数字）必须与最新一次执行同步」—— L-171 于上一提交 `1b5a9c3` 写就，而**同一文件同表**仍留有 4 处旧值（其中 AC-8 的 46 正是 L3 第 16 轮 minor ① 的订正产物）⇒ 说明「人工逐点订正」不足以维持总结面。
**Consequence（后果）**：§AC 表是本 change 对「回归保护面」的唯一汇总入口（阶段 7 triage 与后续 change 都会引用它），数字陈旧会被读成「常设网只有 27/5/24 用例」，低估回归保护、也削弱「判据可信度」这一类结论的可核查性；同类偏差已在阶段 5 被 L2 第 5 轮以 `TD-078` 记为 🟡，属**重复发生**。
**Remedy（修补）**：① 四处按 HEAD 实测订正并标注测量命令与时点（历史值保留为注释）；② 在 §AC 表表头加一行强制规则「本表的用例数一律由 `grep -cE '^[[:space:]]*@test'` 在**当次执行**生成，禁止沿用上一时点值」；③ v2 建议：把该表数字纳入 `reproduce-5-test.sh` 的自动核对段（脚本已能解析 bats TAP，成本低）。

**处置（主 agent · 2026-09-27 · `Fixed in: TEST.md`）**：四处已按 HEAD 实测订正（`TEST.md` 1266 → **1269** 行；`:56` → **45** · `:57` → **11** · `:59` → **30** · `:61` 净合计 → **53**（30 + 9 + **14**），每处保留历史时点值与演进链），并在 §AC 表后新增「**数量口径生成规则**」强制行（实测命令 + 每次执行后必须重跑 + 禁止人工推算）；v2 项（把该表数字纳入 `reproduce-5-test.sh` 的自动核对段）登记为 **`TD-082`**。
**流程披露（不掩盖）**：本次订正发生在阶段 5 冻结**之后**（`INDEPENDENT-REVIEW-5.md:1141` `L3_artifact_hash: 20cb83032a814dd769c359f23ee4d901807d273966786046b582df9172dee1f9`）⇒ 该哈希与现行 `TEST.md` 已不相等。`flow-kit-bundle/hooks/stop/29-independent-review.sh:174-201` 的 `_l3_scan_backlog` 对**已有 `.done` 标记的阶段直接跳过**（`[ -f "$dm" ] && continue`）⇒ 不会自动触发阶段 5 重审；若阶段 5 被重新进入（如用户选择回退重跑 5-test），`l3-truncate.sh:22` 的 `_l3_check_rerun` 会因哈希不符而**强制重新冻结**（设计意图如此）。


#### R5-4 · 变更自带的两份「复现脚本」无常设门禁覆盖（自身缺陷只能靠人工重跑发现）

**Severity**：🟢 Minor
**Symptom（症状）**：`.specs/health-fix-2026-09b/reproduce-5-test.sh`（267 行 · `TEST.md` / `PHASE5-RECEIPTS.md` 的「一键复算」入口）与 `.specs/health-fix-2026-09b/reproduce-phase-gate.sh`（165 行 · 阶段门六态沙箱）在 `test/`、`flow-kit-bundle/test/`、`Makefile` 中**零引用**（`grep -rn 'reproduce-phase-gate\|reproduce-5-test' test/ flow-kit-bundle/test/ Makefile` ⇒ **0 命中**）⇒ 两份脚本的正确性完全依赖人工重跑。
**Source（源头）**：`flow-kit-bundle/flow-kit/prompts/6-review.md:100-107`（证据面须可核查）。已发生的实例：**`TD-077`**（`[D]` 段 `emit_gate "NFR ≤5s ×5" 0 "…"` 把 rc 硬编码为 0 ⇒ 将 **221.6%** 的实测印成 ✅）正是「脚本自身有缺陷却无机器复核」的产物，直到阶段 5 第 11 次执行前才被人工发现。
**Consequence（后果）**：脚本若在后续 change 中被误改（或其所依赖的 `TASK.md` 判据块格式变化），本 change 唯一的复算入口会静默失真，而没有任何门禁会变红 —— 与 `L-154`（收尾顺序）声称的「可复算」不闭环。
**Remedy（修补）**：**v2 项 → `TD-083`**：给两份脚本加轻量自检（`reproduce-5-test.sh`：断言 `[A]` 段基线字符串与 `npx bats --count test/` 实测一致、`[D]` 段必须以真实 rc 判定；`reproduce-phase-gate.sh`：断言六态退出码矩阵），并在 `Makefile` 增 `check-reproduce` 目标。**本 change 内不改**（避免在阶段 6 编辑判据脚本自身）。


#### R5-5 · `SELF_EXCLUDE` 未按自身契约追加阶段 5/6 的新增审查档（`INDEPENDENT-REVIEW-5/6.md`）

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:78-90` 的 `SELF_EXCLUDE` 注释明确要求「**后续阶段新增审查档时必须显式追加精确路径到本清单**（不得改宽通配）」，但清单只含 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-{1,2,3}.md`；阶段 5 产出的 `INDEPENDENT-REVIEW-5.md`（1163 行）与阶段 6 正在产出的 `INDEPENDENT-REVIEW-6.md` **均未追加**（`grep -n 'INDEPENDENT-REVIEW' flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` ⇒ 只有 `1/2/3` 三行）。
**Source（源头）**：`check-path-privacy.sh:84`（契约原文）。实测（主 agent · 2026-09-27）：`git grep --cached -naE "$PAT"` 全 index **77 条**命中，其中 **50 条落在 IR-1（22 条）/ IR-2（28 条）** —— 「审查档必然含 PAT 字面」正是 `SELF_EXCLUDE` 存在的理由；把非自排除的其余命中按「被匹配到的用户名成分」逐条取名字后，**全部是 27 条 `/home/user/` 通用占位符**（`grep -vE '/home/(user|ubuntu|\.\.\.)/'` 后非自排除命中 = 0）⇒ 当前「命中 0 / 清单外 0」**是诚实的**，但那是运气而非契约。
**Consequence（后果）**：阶段 6 的 `INDEPENDENT-REVIEW-6.md` 还要追加 L2 盲审（`flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md` 要求逐条引用 `file:line` 证据）、L3 复审输出与主 agent 响应；其中任何一处引用真实账号路径或探针字面，`make check-path-privacy` 即 **rc=1** ⇒ 阶段 6 的文档提交被 fail-closed 挡住，而该清单本应在阶段 5/6 就把它排除。
**Remedy（修补）**：把两行精确路径追加进 `SELF_EXCLUDE` 区块（`check-path-privacy.sh:85-90`）—— `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md` 与 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md`（**禁宽通配**，契约同款）；并把「新增审查档 ⇒ 同 PR 追加 `SELF_EXCLUDE`」由注释升格为可检查断言 ⇒ **v2 项 `TD-085`**（`make check-privacy-selfexclude`：扫描 `.specs/**/INDEPENDENT-REVIEW-*.md` 与 `SELF_EXCLUDE` 条目的差集，非空即 rc≠0）。**本 change 内不改生产件**（R3.3 约束）⇒ 归 fix loop / v2。


#### R5-6 · AC-2 的「常设 bats 回归」登记不实：缺 jq 场景无任何 bats 复现（审计 C `F1`）

**Severity**：🔴 Critical
**Symptom（症状）**：`TEST.md:55` 的 AC-2 长期回归列写「✅ 常设 bats（`test_install_coverage.bats` / `test_install_dry_run.bats`）」，但**没有任何 bats 复现缺 jq 场景**。实测（审计 C 独立跑 + 主 agent 复核）：`grep -rn "permissions" test/*.bats` ⇒ **无输出**；`grep -rln "settings\.json" test/*.bats` ⇒ 仅 `test/test_install_dry_run.bats`（`:20` 为 `DRY_RUN`、`{"hooks":{}}`、project scope、**jq 在位**，且只比 `sha256sum`）；`grep -rn "no-brooks" test/*.bats` ⇒ 仅 `test/test_install.bats:83`（且**无 `--user`**，而 `REQUIREMENT.md:151-153` 指明只有 `--global --no-brooks --user` 会命中 `install_hooks.sh:251` 的截断行）；全仓无「影子 PATH 排除 jq」用例。
**Source（源头）**：AC-2 的实现位于 `flow-kit-bundle/lib/install_hooks.sh:39-49`（`mktemp` 原子写）· `:186-191`（入口级 `command -v jq` ⇒ `❌ 缺少依赖 jq：install_hooks 需要 jq 合并 settings.json，已中止（尚未做任何写盘）` + `return 1`）· `:352-358`（合并前第二道守卫）；对应判据 = change 期 `TASK.md` 的 `T06 <verify>`（本轮由审计 C 抽取复跑 ⇒ rc=0，**但它只在 change 期内有效**）。`TEST.md:55` 是唯一声称它已进常设网的地方。
**Consequence（后果）**：AC-2 修的正是「先毁数据再失败」（既有 `settings.json` 122B → 0B 后 rc=127）。入口守卫若被后续 change 删除或移位，`make check` 仍**全绿** ⇒ 与 `CHANGE.md:161-171` 对 TD-053 的判定同型（「门禁失效而 `make check` 仍绿」不可与 pass 并存）；且 `TEST.md` 把「无覆盖」写成 ✅ 属**不实登记**，直接误导阶段 7 的回归保护 triage。
**Remedy（修补）**：把 `T06` 判据固化为常设 bats（`test/test_install_coverage.bats` 或新文件）：影子 PATH 排除 `jq` + `--global --no-brooks --user` + 断言 rc≠0 + `settings.json` **逐字节不变**（`cmp -s` 前后备份）+ `permissions.allow` 与既有 hook 存活；若判定不改测试，则必须把 `TEST.md:55` 改为「无常设 bats（TD-053 未闭合）」并把 AC-2 的结论强度降级为「仅 change 期判据覆盖」。
**审计标注**：审计 C 的 `F1`（R6 Domain Model Distortion）。
**跨模型确认（ADR-014 第 5 轮 · `qwen3.8-flash` · 2026-09-27）**：spot-check agent `8dd172a1-…` 的 `F1` 独立命中同一缺口，并给出**变异实证**（删 `flow-kit-bundle/lib/install_hooks.sh:189-192` 与 `:356-359` 两道守卫 ⇒ 缺 jq 下 rc=0 且 4×`⚠️ …合并失败，请手动检查`＝静默谎报成功；真实体 rc=1 + `❌ 缺少依赖 jq…已中止（尚未做任何写盘）`）⇒ 本条的 Remedy 追加**反向控制**一条：常设 bats 必须包含「删守卫 ⇒ 转红」的变异腿（仅断言正例 rc≠0 不足以证明判据有效）。原 PC2 的 0B 截断形态在该 agent 处未复现（现形态为谎报成功），不影响定级。

#### R5-7 · AC-3 的推送拦截无行为级常设测试，报告却声称 bats 覆盖（审计 C `F2`）

**Severity**：🔴 Critical
**Symptom（症状）**：`TEST.md:56` 的 AC-3 长期回归列声称 `test_archive_commit_gate.bats` 覆盖，但该文件对 `pre-push.sh` **只做 `bash -n`（`:183`）+ 8 条文本存在性 `grep -q`**（`:188`/`:190` 断言 `resolve_reference_dir` / `reference/check-path-privacy.sh`；`:193`/`:195` 断言 `makefile_has_target` / `项目 Makefile 未声明 check 目标`；`:198`/`:199` 断言 `纯删除推送`；`:202`/`:204` 断言 `scanned_shas` / `已扫描过该 sha`；`:207` 断言三者皆不可得），**从不执行 hook**。`grep -rn "git push" test/*.bats` ⇒ 仅 `test/test-is-git-commit-structural.bats:104-106`（无关的匹配器测试）⇒ 把逻辑改坏、只保留这些字符串测试仍**全绿**。
**Source（源头）**：实现 = `flow-kit-bundle/hooks/pre-push/pre-push.sh`（185 行）：`:47-50` `makefile_has_target`、`:99` `CHECK_REV="$check_rev" make check-path-privacy`、`:107-108` 缺允许清单 ⇒ 具名 `exit 2`、**`:139` 畸形 stdin ⇒ 具名 fail-closed `exit 1`**、`:149-153` 纯删除跳过、`:157-174` sha 去重、**`:168` `🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（check-path-privacy 未通过）`**、`:177` `[ -z "$leaky_ref" ] || exit 1`、`:182` 尾随 `make check`。`TEST.md:56` 把报文位置写成 `pre-push.sh:30`/`:49`（实物 `:30` 是 reference 目录注释、`:49` 在 `makefile_has_target` 内）⇒ 失准（同 `R5-8`）。
**Consequence（后果）**：AC-3 是本 change 的**安全闸门**（泄漏 ref 不得误推），其判定力目前只由**归档进 `.specs/` 的 change 期 UAT `T19`** 承载，常设面为 0；任何后续改动都能在 `make check` 全绿的情况下让拦截失效（fail-open）。
**Remedy（修补）**：把 `T19` 收敛为常设 bats：`git init --bare` 沙箱 + 四形态 stdin（干净 ref / 泄漏 ref / 纯删除 / 畸形行）+ 断言 rc≠0 且报文含被拒 ref 名（并覆盖 `exit 2` 的缺清单态）；或在 `TEST.md:56` 如实降级并登记 tech-debt。
**审计标注**：审计 C 的 `F2`（R3 Change Propagation）。
**跨模型确认（ADR-014 第 5 轮 · `qwen3.8-flash` · 2026-09-27）**：spot-check agent `8dd172a1-…` 的 `F2` 独立命中，并给出**变异判据**：变异体（`pre-push.sh:138-141` 畸形守卫 `exit 1`→`continue`、`:167-171` 泄漏拒绝 → `scan_rev || true`）上 `test_archive_commit_gate.bats` 的全部静态断言逐条重放**仍全绿**，而行为差分 REAL push rc=1 + `🔴 拒绝推送 refs/heads/main：该 ref 含路径隐私泄漏` vs MUTANT rc=0 ⇒ Remedy 追加反向控制：「常设 bats 必须在上述两处变异体上转红」。

#### R5-8 · TEST.md 的计数与行号不能由其自带复算命令复现（审计 C `F3`）

**Severity**：🟡 Important
**Symptom（症状）**：原样重跑 `TEST.md:127-129` 的自带复算命令 ⇒ **12 个文件**（非 §1.3 第 4 条写的「8 文件 +84/−28」）：`test_archive_commit_gate.bats base=24 head=45`、`test_check_gate_sync.bats base=5 head=11`、新件 `nfr=14 / path_privacy=30 / review_gate=11 / runtime=9`；而 `TEST.md:125` 写「唯一变化 = archive 24 → **27**（+3）⇒ 973+3=976」、`:131` 写「四个新文件行数 = 163/113/127/197，`@test` = 9/9/**7**/11」，实物 `test_nfr_portability_gate.bats` = **247 行 / 14 例**；`:56`/`:57`/`:124`/`:133`/`:61` 的计数同样陈旧（与 `R5-3` 同族，但覆盖面更大）。按 `TEST.md:117` 自订规则（§1.3 内未标历史轮次者 = 当前值 = 第 11 次执行）这些数字**必须**读作当前值 ⇒ 属不实。AC-3 的报文位置引用亦失准（`TEST.md:56` 称 `:30`/`:49`，实物 `:139`/`:168`+`:177`）。
**Source（源头）**：`.specs/LESSONS.md` **L-171**（总结面必须与最新执行同步）· `6-review.md:100-107`（spec 合规判定须以工件为准）· `TEST.md:117` 自身的时点标记规则。
**Consequence（后果）**：阶段 6/7 若按报告计数核对覆盖面，会得到「AC-3 有 27 例常设网」这类错误结论（实为 45 例且**行为级覆盖仍为 0**，见 `R5-7`）⇒ 双重误导。
**Remedy（修补）**：以 HEAD 重算并就地订正（12 文件 / 45 / 11 / 14 / 30 / 11），行号改为 `:139`/`:168`/`:177`；`R5-3` 已订正 §AC 表四处，本轮续订 §1.3 第 3/4 条（**已完成**，见下方处置行）。
**审计标注**：审计 C 的 `F3`（R6）。

#### R5-9 · AC-1 的核心判据（载荷不被执行 · 6 副本 + 归档归零）无常设 bats（审计 C `F4`）

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_runtime_edit_guard.bats:57-109` 的 9 例全部是路径解析 / 维护源 / `~` 展开行为，**无一条注入 `$(eval …)` 载荷**、无哨兵文件断言、也不枚举 6 个部署副本与 `dist/` 归档面；`grep -rln "runtime-edit-guard" test/*.bats` ⇒ 仅该文件；`grep -rn "sync-hooks.sh --list\|xzOf" test/*.bats` ⇒ 无相关命中。`TEST.md:54` 一方面写「仅 change 期判据覆盖 · TD-053」，另一方面把 TD-053 记为「已闭合（9 用例）」⇒ 自相矛盾。
**Source（源头）**：AC-1 实现 = `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`；change 期判据 = `T05 <verify>`（本轮审计 C 独立复算六面 + 源树 + tarball 全 0）。
**Consequence（后果）**：若 `eval echo` 形态被回归引入，常设网 9 例仍全绿 —— 这正是 TD-053 的原始形态（判据在 change 内红过，但常设面不覆盖）。
**Remedy（修补）**：补 1 例载荷注入（拼接构造 `$(…)` 路径 + 哨兵文件不存在断言）+ 1 例 6 副本静态计数断言（`grep -cE` = 0）。
**审计标注**：审计 C 的 `F4`（R6）。

#### R5-10 · AC-4 的判别性形态未被测试触达；两条漂移用例缺 `$status` 断言（审计 C `F5`）

**Severity**：🟡 Important
**Symptom（症状）**：AC-4 的判别形态是「**行数不变、仅内容变**」；`grep -rn "行数不变\|等行数" test/*.bats` ⇒ **无命中**；`test/test_check_gate_sync.bats:114`（skill 侧）与 `:124`（prompt 侧）的 R3-18A/B 用 `printf '
X-DRIFT-SKILL-ONLY
' >>` **追加整行 ⇒ 行数改变**，旧「比行数」实现同样报红 ⇒ **不能区分新旧判据**。`check-gate-sync.sh:151` 要求的具名位置格式（`(prompts|skills)/…:NN`，AC-4 Then② 的 `grep -qE '(prompts|skills)/[^ :]+:[0-9]+'`）在 bats 中**无任何断言**（`grep -rn "(prompts\|skills)" test/*.bats` 仅命中无关的 `test/test_integration_smoke.bats:71`）。另 `test/test_check_gate_sync.bats:38-44` / `:45-48`（gate-config 漂移两例）只断言 `$output`、**未断言 `$status`**。
**Source（源头）**：实现 = `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:37`（PAIRS）/`:44`（`PAIRS_TOTAL=14`）/`:48-50`（剥离 front-matter 逐行 diff）/`:111-120`（`diff_rc≥2` ⇒ MECHANICAL）/`:147`（`<prompt|skill|both> 侧内容不一致`）/`:151`（具名位置）/`:181`（`✅ 内容一致`）；`Makefile:106` 已接线。
**Consequence（后果）**：门禁若退回「比行数」，或不再打印可被下游 grep 识别的具名位置，常设网仍全绿 —— AC-4 的核心价值（从「行数盲」升级为「内容判别」）在常设面无回归保护。
**Remedy（修补）**：把 R3-18A/B 改为**等行数改写**（如把某行内容替换为同长度异内容）并断言 rc≠0 + 具名位置正则；`:38`/`:45` 补 `[ "$status" -ne 0 ]`。
**审计标注**：审计 C 的 `F5`（R4 Accidental Complexity）。

#### R5-11 · AC-5 的归档面（逐个 tarball `chisel` 计数为 0）无常设门禁（审计 C `F6`）

**Severity**：🟢 Minor
**Symptom（症状）**：生产件里**没有任何 chisel 扫描器**（`grep -rn chisel --include='*.sh' --include='Makefile' --include='*.yml' --include='*.json' .` ⇒ 0 命中）；`make check-dist` 只保证 `dist/dsh-flow-kit/vendor/flow-kit-bundle` ↔ 源一致，**不覆盖 tarball 内容**；当前 `dist/` 仅剩 `dsh-flow-kit-0.2.0.tgz` 一个（`0.1.0` 已不存在）⇒ AC-5/T27 的「逐个归档」判据在 HEAD 只有 1 面可复现。
**Source（源头）**：AC-5 判据 = `T24`/`T27`（change 期）· `Makefile` 的 `check-dist`。
**Consequence（后果）**：若打包脚本回归带入 `chisel` 字样，常设门禁不会变红（只由 change 期判据保证）。
**Remedy（修补）**：在 `package-flow-kit.sh --validate` 或 `check-dist` 内加「归档 `chisel` 计数 = 0，否则 exit 1」断言；或明示该面仅 change 期有效。**v2 项**。
**审计标注**：审计 C 的 `F6`（R6）。

#### R5-12 · AC-7① 的替换用例不驱动被测件；该文件结尾缺换行（审计 C `F7`）

**Severity**：🟢 Minor
**Symptom（症状）**：`test/test_combined_metric.bats:28-44` 只做 `mktemp` + `rm` + `ls | grep -q .`，注释自述「复刻 INT-COMBINED-1 的建/删模式」，**全程未调用任何被测件**（强于原恒真式，但验证的是 `mktemp`+`rm` 语义）；且该文件被本 change 改后**结尾缺换行**（`tail -c1` = `}`，其余三个新文件均为 `
`，实测确认）。
**Source（源头）**：AC-7① 的原始假绿形态（恒真断言）· `git diff --shortstat 534e3e8..HEAD -- test/test_combined_metric.bats`。
**Consequence（后果）**：AC-7 的结论强度被高估（该例不构成对 SUT 的验证）；缺换行会让后续追加/`cat` 拼接产生粘连。
**Remedy（修补）**：改为驱动真实清理路径（或把用例改名为「环境自检」并把 AC-7 的对应结论降级）；补文件尾换行。
**审计标注**：审计 C 的 `F7`（R4）。

#### R5-13 · 隐私门禁测试内两处弱断言（审计 C `F8`）

**Severity**：🟢 Minor
**Symptom（症状）**：`test/test_path_privacy_gate.bats:269-276`（F4 坏态）在 `run` 之后**只有输出子串断言**（`[[ "$output" == *"允许清单 0 条"* ]]`）、**无 `$status` 断言**（同文件其余用例均有）；`:298-310`（F5 好态）用 `find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*'` 前后计数 + `[ "$after" -le "$before" ]` ⇒ **不可归因**（并发删除会漏检泄漏）。
**Source（源头）**：实现 = `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:129-181`（`mktemp_checked` 失败 ⇒ exit 1）· `:211-241`。
**Consequence（后果）**：该两例可能在「行为已坏」时仍显绿（弱断言）或误红（不可归因计数）。
**Remedy（修补）**：`:269` 补 `[ "$status" -eq 1 ]`；`:298` 改为专用 `TMPDIR`（隔离目录）+ 跑后断言该目录内无残留。
**审计标注**：审计 C 的 `F8`（R4）。

#### R5-14 · `check-gate-sync` 的 gate-config 分支缺文件仍报绿（审计 A `A1`）

**Severity**：🟡 Important
**Symptom（症状）**：`check_gate_config_sync()`（`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:190-202`）在 `skills/flow/SKILL.md` 或 `test/test_gate_config_presets.bats` 任一**缺失**时打印 `⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验` 后**裸 `return`**（`ERRORS` 不增）⇒ 主流程继续打印 `✅ 校验对 3/14 一致` 且 **rc=0**；同函数对「文件在场但内容为空」则 fail-closed（`🔴 DRIFT` + rc=1）⇒ 同一函数内两种口径分裂。
**证据（主 agent 亲验 · `/tmp/p6d/a1-verify2`，忠实复制 `flow-kit/` + `skills/` + `test/`）**：完整态 **rc=0** + `✅ 校验对 3/14 一致`；删 `test/test_gate_config_presets.bats` ⇒ **rc=0** + `⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验` + 仍打印 `✅ 校验对 3/14 一致`（`grep -c` = 1）；移走 `skills/flow/SKILL.md` ⇒ 同样 **rc=0**。`flow-kit-bundle/test/test_check_gate_sync.bats` 11 例中 `grep -n '跳过\|WARNING\|文件缺失'` **零命中** ⇒ 该分支无常设覆盖。
**Source（源头）**：`REQUIREMENT.md:516`「SKIP 以 rc=3 表达『未验证』，调用方（AC-8 / `make check`）**必须**把 3 与 0 区分」；同类先例 = 第 1 轮 `F6`（🟡 · `REVIEW.md:420`/`:616`）已由 `T-FIX-04`（`521b21c`）在 `check_pair()` 修为 `🔴 MISSING …（校验对未比对）` + `ERRORS+1`，本函数（同文件另一分支）未同步。`check-gate-sync.sh:189` 注释称本函数「值比较逻辑属 TD-033/034，v2 不改」，但 `:208-258` 的 R3-19/R3-20 收敛已落在本函数内 ⇒ 该边界声明与实现不一致，不能据此挡修。
**Consequence（后果）**：文件被删/改名或 bundle 形态变化时，gate-config 预设名同步校验**永久静默失效**而 `make check` 仍全绿 —— 正是本 change 要消灭的「未能检查却说通过」。
**Remedy（修补）**：改为具名 `🔴 MISSING …（未比对）` + `ERRORS=$((ERRORS+1))`（保留路径与「未比对」措辞），并补两条 bats 腿（分别隐藏 skill / bats ⇒ 期望 rc=1 且无 `✅` 汇总行）。
**审计标注**：审计 A `A1`（R6 Domain Model Distortion）。

#### R5-15 · 隐私门禁磁盘侧检索未隔离候选路径 ⇒ 候选名恰为 grep 选项时静默漏检（审计 A `A2`）

**Severity**：🟡 Important（方向为 **fail-open**，且会静默塌缩整个工作树侧扫描面）
**Symptom（症状）**：`check-path-privacy.sh:633` 的 `raw_disk=$(grep -naE "$PAT" "$file" 2>/dev/null)` **无 `--`**，而候选循环 `while IFS= read -r -d '' f; do … scan_file "$f"; done < "$TMP_CANDIDATES"`（`:770-774`）使循环体 stdin = 候选清单文件 ⇒ 任一候选名以 `-` 开头时该名被 grep 当选项：该文件不被检索、grep 改读候选清单、`read` 随即 EOF ⇒ **其余候选整段跳过**。
**证据（主 agent 亲验 · `/tmp/p6d/a2c-verify.sh` 三腿，检查器置于 `flow-kit-bundle/flow-kit/reference/` 以命中 SELF_EXCLUDE、避免自匹配掩盖）**：leg A（工作树 `-q` 内含真泄漏）⇒ `候选文件 5 / 实际扫描 1 / index 侧 0 / 命中合计 0` **rc=0 静默放行**；leg B（`-q` 干净、泄漏在 `zz_control.txt`）⇒ `实际扫描 1 / 命中 0` **rc=0**（塌缩吞掉**所有**其他候选，不止破折号名那个）；leg C（对照：`-q` 改名 `nq.txt`，同一泄漏）⇒ `实际扫描 3 / 命中 1` + 归因 `zz_control.txt:1: leak …` **rc=1**。审计 A 另在 `-w` 与 rev 腿复现 rc=0 漏检；其 `-v` 腿表现为「塌缩 + 虚假归因」（把候选清单当命中内容输出，报出仓库里不存在的 `file:line`）。可达性：`git ls-files -z | tr '\0' '\n' | grep -c '^-'` = **0**（本仓当前无此类候选 ⇒ 低概率 · 高后果）。
**Source（源头）**：`REQUIREMENT.md:510-520` 自陈「`$FILES` 为空时 `grep … $FILES` 会退化读 stdin（实测可被管道输入『命中』rc=0）」的同类边界在本文件仍未设防；同脚本 `:606` 的 rev 侧调用 **已带 `--`**（`git grep -naE --null "$PAT" "$RESOLVED_REV" -- "$file"`）⇒ 房内惯例已存在，`:633` 漏了。
**Consequence（后果）**：隐私门禁两向失真 —— 静默放行（有未扫描候选仍 rc=0）与虚假归因（报出仓库里不存在的 `file:line`）；自证行 `实际扫描 N 个` 与 `候选文件 M 个` 的差值不构成阻塞，故「塌缩」不可见。
**Remedy（修补）**：`:633` 改为 `grep -naE "$PAT" -- "$file"`，并对磁盘检索显式 `</dev/null`（或以 `-e "$PAT"` 传模式）断开与候选清单 fd 的耦合；再加断言 `实际扫描数 = 候选数 − 自排除数`（差值 > 0 ⇒ 🔴 fail-closed）。
**审计标注**：审计 A `A2`（R4）。

#### R5-16 · rev 模式未批量化，而它正是 pre-push 的唯一调用形态（7.1–7.5 s > 5 s 预算）（审计 A `A3`，定级上修）

**Severity**：🟡 Important（审计 A 建议由 `INDEPENDENT-REVIEW-5.md:1005-1015` 的 🟢-1 **上修**为 🟡）
**Symptom（症状）**：`T-FIX-12` 只批量化了工作树模式；`RESOLVED_REV` 非空时仍**逐候选**起一次 `git grep`（本仓 1596 候选 ⇒ 上千次 git 进程）。
**证据（双份实测）**：审计 A `time CHECK_REV=HEAD …` **7.509 s** / 工作树 3.775 s；主 agent 亲验 **7.084 s**（user 2.581 / sys 8.223）vs 工作树 **3.613 s**（1.669 / 2.395），两者 rc=0 ⇒ rev 面 **1.4× 超预算**（预算 = `REQUIREMENT.md:495`「单次运行 ≤5 秒」）。真实调用者 = `flow-kit-bundle/hooks/pre-push/pre-push.sh:99 if ! CHECK_REV="$check_rev" make check-path-privacy; then`（`:163` 用被推 ref 的 local sha），该钩子由 `lib/install_hooks.sh:118-167 deploy_pre_push()` 安装，且本 change 刚把 `hooks/pre-push/*.sh` 纳入打包（`package-flow-kit.sh:134-136`）⇒ **每次 push** 都走这条未批量化路径。
**Source（源头）**：`T-FIX-12-SUMMARY.md:120` 的理由「rev 模式未批量化……rev 模式不在 NFR 热路径」被上述接线与实测**同时反驳**；L2 已登记为 🟢-1 但其 Consequence 写「当前无性能问题」，与实测不符（已登记 ≠ 已核实）。
**Consequence（后果）**：NFR/AC-8 只在工作树模式成立；用户最可感知的 push 前路径耗时 2× 且超预算，长期会诱导 `--no-verify` 绕过（ADR-027 ② 明列的反模式）。
**Remedy（修补）**：rev 模式同样批量化为一次 `git grep -naE --null "$PAT" "$RESOLVED_REV"`（无 pathspec，复用现成的 `parse_grep_null`，其 `rev:` 前缀剥离已实现）；或把「两种扫描面都 ≤5 s」写成 AC-8 计时断言。
**审计标注**：审计 A `A3`（R4）。

#### R5-17 · `/home/ubuntu/` 被占位符表吞掉（审计 A `A4`）

**Severity**：🟢 Minor（设计权衡，建议登记残余风险）
**Symptom（症状）**：`check-path-privacy.sh:77` `PLACEHOLDER_NAMES='user ubuntu acct yourname foo bar someone'`，其中 `ubuntu` 是 Ubuntu AMI 的**真实默认账号** ⇒ 只含 `/home/ubuntu/secret` 的 tracked 文件被当占位符排除（使用点 `:428`）。
**证据（主 agent 亲验 · `/tmp/p6d/a4b-verify.sh`）**：leg A（`/home/`+`ubuntu`+`/secret`）⇒ `命中合计 0 条` **rc=0**；leg B（同位置换真实账号名）⇒ `命中合计 1 条` + `target.txt:1` 归因 **rc=1**（夹具活性已证）。
**Source（源头）**：`REQUIREMENT.md:389` 的三态实测只覆盖 `/home/<user>` 形态；`INDEPENDENT-REVIEW-2.md:635` 把 `/home/ubuntu/` 记为「须被排除表排除 ✅」。
**Consequence（后果）**：真实 CI 账号形态的泄漏不会阻塞；`.specs/CONTEXT.md` / `MINOR-DEFERRED.md` 中未见该口径的残余风险登记。
**Remedy（修补）**：登记残余风险（口径 + 复核窗口），或提供 `FLOW_KIT_PRIVACY_STRICT=1` 让消费者关闭占位符豁免。
**审计标注**：审计 A `A4`（R6）。

#### R5-18 · 【🔴】随包隐私检查器在**已安装形态**下不可达 ⇒ 消费者项目推送/提交门禁 100% 静默失效（审计 B `🔴`，主 agent 扩面确认）

**Severity**：🔴 Critical
**Symptom（症状）**：安装器把检查器装到 `ref_dst_dir="${hook_dst%/hooks}/reference"`（`flow-kit-bundle/lib/install_hooks.sh:277-292`，注释却写「hook 推导路径：HOOK_DIR/../reference/」），但 hook 自身装在**更深一层** `<hook_dst>/pre-push/pre-push.sh`（`deploy_pre_push` `:126-127`）⇒ hook 的 `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`（`pre-push.sh:31` · `pre-commit.sh:38`）在已安装形态下 = `<hook_dst>/pre-push` ⇒ 三条候选 `$HOOK_DIR/../flow-kit/reference`（=`<hook_dst>/flow-kit/reference`）· `$HOOK_DIR/../reference`（=`<hook_dst>/reference`）· `$HOOK_DIR/../../flow-kit/reference`（=`<hook_dst>/../flow-kit/reference`）**全部 miss** ⇒ `RESOLVED_KIND=none` ⇒ `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` 后 `return 0`（`pre-push.sh:116-117`）。经 `.git/hooks/pre-push` symlink 调用时 `BASH_SOURCE[0]` = `.git/hooks/pre-push` ⇒ `HOOK_DIR=<proj>/.git/hooks` ⇒ 再错一层，同样 miss。`hook_dst` 定义 = `install_hooks.sh:213`（user scope `$USER_HOOKS_DIR`）/ `:222`（project scope `${project}/${PROJECT_DIR_NAME}/hooks`）；`deploy_pre_commit`（`:75-89`）同样以 symlink 指向 `<hook_dst>/pre-commit/pre-commit.sh` ⇒ pre-commit 侧同病。
**证据（主 agent 亲验 · `/tmp/p6d/bfix-verify.sh` · 真实安装 + 真实泄漏提交）**：`bash flow-kit-bundle/install.sh --platform claude --project <proj> --hooks-only` rc=0；产物 = `<proj>/.claude/hooks/pre-push/pre-push.sh` · `<proj>/.claude/hooks/pre-commit/pre-commit.sh` · `<proj>/.claude/reference/{check-path-privacy.sh（52124 B）, path-privacy-allowlist.txt（1006 B）}` · `.git/hooks/pre-push -> <proj>/.claude/hooks/pre-push/pre-push.sh`（symlink）；目录树实证 `hooks/{pre-commit,pre-push,pre-tool-use,session-start,stop}` + `reference/`（**无** `hooks/reference`、**无** `hooks/flow-kit`）。在真泄漏提交 `4789a86`（`leaky.txt: leak /home/<真实账号>/secret`）下：**leg 1**（`.git/hooks/pre-push`，即 git 的真实调用形态）⇒ `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描` **rc=0**；**leg 2**（安装后的真实脚本路径 `<proj>/.claude/hooks/pre-push/pre-push.sh`）⇒ 同一跳过 **rc=0**；**leg 3**（源码树形态，同 cwd / 同 stdin / 同 rev）⇒ 解析成功、扫描 53 候选、归因 `leaky.txt:1` + `🔴 拒绝推送 refs/heads/main：该 ref 含路径隐私泄漏（check-path-privacy 未通过）` **rc=1** ⇒ 拒绝与放行的唯一差别是**检查器能否被解析**，而**已安装形态永远解析不到**（不止 symlink：安装位本身即错层）。审计 B 的独立复现：`printf 'refs/heads/main %s refs/heads/main %s\n' 1111… 0000… | bash .git/hooks/pre-push origin git@example.invalid:repo.git` ⇒ stdout `ℹ️ 项目 Makefile 未声明 check 目标：跳过`、stderr 跳过检查器、rc=0；源码形态对照 ⇒ `🔴 CHECK_REV 无法解析为 commit（fail-closed）：1111…` + `扫描面: 1111…（未解析）` + 拒绝，rc=1。
**Source（源头）**：`AC-6 ③` / `R3-14` / `T-FIX-08`（`2f01f39`）引入的消费者回退路径；`DESIGN.md` D3 与 `install_hooks.sh:279-282` 的注释把两种布局混为一谈（`<hook_dst>/reference` vs `HOOK_DIR/../reference`）；`T-FIX-13`（`ee0df5c`）修的是「检查器在、允许清单缺」与「检查器真缺」的**措辞与 fail-closed**，而本形态下检查器**从未被找到** ⇒ 该修复在已安装形态不可达。TD-055「独立安全工具面未验证」正是这个 seam。
**Consequence（后果）**：本 change 的主要落地场景（消费者项目）推送与提交两侧隐私门禁同时**静默失效**，泄漏可被推出去而日志只留一条 ℹ️；`scan_rev` 失败时父层（`pre-push.sh:169`）仍归因为「该 ref 含路径隐私泄漏」，报告语句亦失实。
**Remedy（修补）**：① 补一条断言「**安装后的真实形态**能找到检查器」的端到端用例（现有 bats 全为源码树形态 ⇒ 覆盖盲区，与 `R5-7` 同族）；② 修正布局：候选表至少加入 `$HOOK_DIR/../../reference`（已安装形态命中）；③ 或把 `.git/hooks/pre-push` 由 symlink 改为包装脚本（`exec bash "$hook_dst/pre-push/pre-push.sh" "$@"`）并统一相对布局；④ 顺手把全局 scope（`$HOME/.claude/hooks/pre-push/…` 与 `$HOME/.claude/reference`）纳入同一断言。
**审计标注**：审计 B `🔴 Critical`（R2 Change Propagation；主 agent 扩面：不止 symlink 形态，真实安装位亦不可达）。

#### R5-19 · pre-commit 的隐私块排在 Makefile / npx 早退之后 ⇒ 消费者项目不可达（审计 B 🟡#2）

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/hooks/pre-commit/pre-commit.sh:19-22`（`if [ ! -f Makefile ]; then echo "[archive-commit-gate] no Makefile, skipping test gate"; exit 0; fi`）与 `:25-28`（npx 早退）都排在**隐私块（`:36` 起）之前** ⇒ 项目无 Makefile / 无 npx 时隐私扫描既未执行、也未打印跳过理由。
**证据（主 agent 亲验）**：在 `R5-18` 的探针项目（无 Makefile）内 `bash .claude/hooks/pre-commit/pre-commit.sh </dev/null` ⇒ **rc=0**，stdout 仅 `[archive-commit-gate] no Makefile, skipping test gate`，无任何隐私相关输出（`<proj>/.claude/reference/{check-path-privacy.sh, path-privacy-allowlist.txt}` 双双在位）。
**Source（源头）**：`AC-6 ③` / `R3-14` 注释宣称的「消费者项目回退路径」与执行顺序矛盾（声明即被验证原则）。
**Consequence（后果）**：commit 侧隐私防护只在项目 Makefile 声明了 `check-path-privacy` 时存在；与 `R5-18` 叠加 ⇒ 消费者项目双侧门禁全灭。注意：即便把该块上移，`:38` 的 `HOOK_DIR` 推导在安装形态下仍会 miss（与 `R5-18` 同源），须一并修。
**Remedy（修补）**：把隐私块移到 `:19` 之前（它不依赖 Makefile/npx），或把两个早退改为置位 `skip_test=1` 后继续下走；与 `R5-18` 的布局修复一并落地。
**审计标注**：审计 B 🟡#2（R1 健壮性 / fail-open 早退）。

#### R5-20 · `settings.json` 非法 JSON 时安装器静默中止（rc=5，无任何诊断）（审计 B 🟡#3）

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/lib/install_hooks.sh:369-386` 的 `merged=$(jq … "$settings_target" 2>/dev/null)` 遇 jq parse error（rc=5）时在 `install.sh:7` 的 `set -euo pipefail` 下**终止整个安装**；`:384` 的具名告警成为死代码，jq 的 stderr 被 `2>/dev/null` 吞掉 ⇒ 安装中途停止且无任何原因说明。
**证据（审计 B 实测）**：把 `.claude/settings.local.json` 写成 `{ "hooks": { "Stop": [` 后重跑 ⇒ `INSTALL_RC=5`，stdout 64 行、末行 `   settings 文件: …/settings.local.json`，stderr **空**，`grep -c '⚠️\|❌\|安装完成'` = **0**，文件保持原样。对照（settings 清成 0 字节）⇒ **rc=1** + `   ⚠️  … Stop (00-gate) 合并失败，请手动检查` ⇒ 该分支本身是 fail-closed 的，非法 JSON 分支不是。
**Source（源头）**：crash early *loudly*（The Pragmatic Programmer）/ 可诊断性。
**Consequence（后果）**：用户看到安装中途停止、无原因说明，4 个 hook（Stop + 3 个 PreToolUse，含 `runtime-edit-guard` 与 `independent-review-gate`）未接线，会误以为已装好。
**Remedy（修补）**：`merged=$(jq … 2>/dev/null) || { echo "⚠️ ${settings_target} 不是合法 JSON，jq 解析失败" >&2; return 1; }`，或在 `:356-359` 的 jq 探测前加 `jq -e . "$settings_target"`。
**审计标注**：审计 B 🟡#3（R1 错误处理）。

#### R5-21 · `phases_done` 短路先于 Tier-1 ⇒ 空/垃圾 `.done` 在 `phases_done` 内仍判「有效」（审计 B 🟡#4）

**Severity**：🟡 Important
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/done-validation.sh:117-123` 的 `in_done=$(jq … '.goal.phases_done // [] | map(select(. == $p)) | length' …)`; `[[ "$in_done" != "0" ]] && return 0` 排在 `:126 [[ -s "$done_path" ]] || return 2  # T1 非空（挡威胁① touch 空文件）` **之前** ⇒ 被校验阶段号 ∈ `goal.phases_done` 时 Tier-1/Tier-2 全部跳过。
**证据（审计 B 探针 A/B/C/D · 主 agent 代码复核）**：A 空文件 + `phases_done` 含该阶段 ⇒ **rc=0**；B 空文件 + 不含 ⇒ rc=2；C 完整 6 行 KVP + 不含 ⇒ rc=0；D 单行垃圾 + 含 ⇒ **rc=0**。本仓 `.flow-active` 现为 `phase=6` / `phases_done=["0"…"5"]` ⇒ 当前门禁路径**不受影响**；审计 B **未能证实**现网可由外部触发（需被校验阶段 ∈ `phases_done`，如回退/纠正态或自改 `.flow-active`）。
**Source（源头）**：函数 docstring `:108` 自述该短路为 **D1/R11 的有意设计**（历史 `.done` 兜底），与同函数 Tier-1 注释「挡威胁① touch 空文件」口径不符（R6 Domain Model Distortion）。
**Consequence（后果）**：威胁① 只在「阶段号 ∉ `phases_done`」时真正关闭；回退/纠正态下空 marker 即可判「已审查」。
**Remedy（修补）**：把短路移到 Tier-1（非空 + 行数 + `phase`/`change_id`/`written_by`）之后，短路只豁免 Tier-2/3 的产物比对。
**审计标注**：审计 B 🟡#4（R6）。

#### R5-22 · ADR 纳入上限静默丢弃，注释却宣称会落标记（审计 B 🟡#5）

**Severity**：🟡 Important（条件性）
**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:357` `[ "$_adr_n" -lt 8 ] || break` 静默截断；预算用尽标记在 `:363-366`，**晚于**该 break ⇒ 超上限路径**无任何标记**（与注释 `:347` 自称「截断与未纳入都显式落标记」相反）。
**证据（审计 B 夹具 `/tmp/audit6/B/cap/`，`artifacts/DESIGN.md` 逐条引用 ADR-001…010）**：`bash /tmp/audit6/B/probe_l3b.sh 2 …/artifacts …/cap.out` ⇒ rc=0、提示词 2176 B，`grep -c '^--- .*adr/'` = **8**、带正文的是 010…003（`:355 sort -rn` 平局按整行倒序）、ADR-001/002 无正文；`grep -c '预算已用尽\|未纳入\|未引用任何'` = **0**。
**Source（源头）**：显式失败原则（同文件注释自定的契约）；R6。
**Consequence（后果）**：需单个工件引用 ≥9 个不同 ADR 才触发（本 change 的 DESIGN.md 只引用 6 个 ⇒ 当前不触发；本 change 归档集共引用 **23** 个 ADR ⇒ 真实项目规模可达）。触发时审查模型不知道还有 ADR 未提供，且被丢的恰是**最老**的。
**Remedy（修补）**：把 `:357` 改为与「预算用尽」同构的落标记 + break（打印未纳入清单）。
**审计标注**：审计 B 🟡#5（R6）。

#### R5-23 · NFR 可移植性判据只扫变更集新增行 ⇒ 审计面 5 处违禁构造是盲区（审计 B 🟡#6）

**Severity**：🟡 Important
**Symptom（症状）**：`Makefile:162` 的判据在**变更集模式**（锚点 `.specs/health-fix-2026-09b/.change-base`）下只扫 `git diff -U0 "$BASE"` 的新增行（`:272`）；只有全量模式（`:261`/`:269`）才扫存量。
**证据（审计 B 逐字复刻 FULL 模式 BAN + `Makefile:165` 的 awk）**：`tracked .sh 文件数=104 · 命中行数=19 · 命中文件数=12`；审计面命中 `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh:100 declare -A keep_line` · `:167 mapfile -t tail_lines <<< "$text"` · `flow-kit-bundle/hooks/stop/lib/common.sh:432 declare -A _FK_PERF_TIMINGS` · `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:51 declare -A PHASE_ARTIFACTS=(` · `sync-hooks.sh:182/197/198 mapfile`。
**Source（源头）**：ratchet 原则（门禁要么全量 + 登记基线，要么明确只对新代码生效）；实现注释与 bats R3-22 把它当全量回归网。
**Consequence（后果）**：归档后（无锚点 ⇒ `Makefile:261` 全量模式）判据会**自己翻红 `make check`**；macOS / bash 3.2 下 `sync-hooks.sh` 的 `mapfile` 会 rc=127，而它被 `make check-hooks-sync`（`Makefile:95-97`）调用 ⇒ 该缺陷要等归档后才被自己的门禁发现。补充：`l3-truncate.sh` 两处位于 `smart_truncate()`（`:69` 起），hooks 内无生产调用方、仅 bats 调用，需确认是否该删。
**Remedy（修补）**：把首次全量的 19 行登记为存量基线并让判据在非锚点模式也跑；或先给 `sync-hooks.sh` 换掉 `mapfile`。
**审计标注**：审计 B 🟡#6（R1 回归网未覆盖存量）。

#### R5-24 · `pure_delete_seen` 死变量（审计 B 🟢#1）

**Severity**：🟢 Minor
**Symptom（症状）**：`flow-kit-bundle/hooks/pre-push/pre-push.sh:129` 初始化、`:151` 赋值，**无任何读取**（`:149-153` 打印「ℹ️ 纯删除推送：跳过内容扫描」后即 `continue`）。
**Source（源头）**：2026-07-08 健康表「死代码」类目 · R6。
**Consequence（后果）**：误导后续维护者以为存在「整次推送全为删除 ⇒ 跳过 `make check`」的逻辑。
**Remedy（修补）**：删除，或补上读取逻辑并加测试。
**审计标注**：审计 B 🟢#1。

#### R5-25 · `sync-hooks.sh` 的副本清单不含项目级副本（审计 B 🟢#2）

**Severity**：🟢 Minor
**Symptom（症状）**：`sync-hooks.sh:56-63` 的 6 个副本（`$HOME/.claude/hooks` · `dist/dsh-flow-kit/hooks` · 其 vendor · `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` · 其 vendor · `$HOME/.config/opencode/hooks`）`--list` 全 ✅、镜像 48 文件；但安装器仍会在 `<proj>/.claude/hooks/` 装同一批 hook（含新增 `pre-push`）⇒ 项目级副本不受 `make check-hooks-sync` 漂移守护。
**Source（源头）**：R2 Change Propagation / R4。
**Consequence（后果）**：项目级副本与源树漂移时无门禁发现（如 `R5-18` 的布局缺陷正是在该形态暴露）。
**Remedy（修补）**：`--check` 支持 `--project <dir>`，或文档化「项目级副本靠重装更新」。
**审计标注**：审计 B 🟢#2。

#### R5-26 · AC-7 的「删除注入」不封闭：`test_independent_review_model.bats` 的 `$HOME` 回落使缺件态可被真机文件满足（spot-check `F3`）

**Severity**：🟡 Important
**Symptom（症状）**：`test/test_independent_review_model.bats` 的 setup 在定位 29 号 hook 时有 `FK_SRC_29="$HOME/.claude/hooks/stop/29-independent-review.sh"` 回落（真机 `~/.claude/hooks/stop/` 由 `sync-hooks.sh` 常驻镜像）⇒ **删除 bundle 源件**后 12 例仍**全绿**；只有**内容退化**注入（把判据逻辑改坏）才能转红 tests 1&4。spot-check agent `8dd172a1-…` 的 `F3` 独立命中（未跑全量 bats）。
**Source（源头）**：`test/test_independent_review_model.bats` setup 的候选回落链；`flow-kit-bundle/hooks/stop/29-independent-review.sh`；对照物 = AC-7 的声称面「删除注入可转红」（`TEST.md` 的 AC-7 行 + `R5-12`）。
**Consequence（后果）**：AC-7（阶段门禁的删除注入防护）在**缺失态**下不可证伪 —— 真机上任何「hook 被删/未部署」的回归都不会被发现，而这正是 AC-7 要挡的威胁；测试结果还随开发者机器状态漂移（非 hermetic）。
**Remedy（修补）**：① setup 一律指向仓库内源树（`FK_SRC_29="$REPO/flow-kit-bundle/hooks/stop/29-independent-review.sh"`，去掉 `$HOME` 回落），并把「源件不存在 ⇒ 测试 fail-fast」写成断言；② 增一例**删除注入**腿（临时改名源件 ⇒ 断言转红），补全 AC-7 的删除轴；③ 与 `R5-12`（AC-7① 不驱动被测件 + 文件尾缺换行）同批修复（同一判据族）。
**审计标注**：ADR-014 第 5 轮 spot-check `F3`（`INDEPENDENT-REVIEW-6.md` 文末）。

#### R5-27 · `TEST.md:55` 的「字节不变」措辞与 REQUIREMENT AC-2 的断言面冲突（spot-check `F4`）

**Severity**：🟢 Minor
**Symptom（症状）**：`TEST.md:55` 的 AC-2 行写「目标配置**字节不变**」，而 `REQUIREMENT.md` 的 AC-2 断言面是「既有 `settings.json` **未被截断为空** + `permissions.allow` 与既有 hook 存活」，并**明确排除**「字节数不变」（原子写会重排 JSON，字节可合法变化）。
**Source（源头）**：`REQUIREMENT.md` AC-2 条文 vs `TEST.md:55` 的判读用词；`flow-kit-bundle/lib/install_hooks.sh:39-49`（`mktemp` 原子写 ⇒ 字节可变）。
**Consequence（后果）**：判据面若照字面执行（`cmp -s` 逐字节相等）会在**正确实现**上转红 ⇒ 误导后续执行者把合法重排当回归；反之若照实现执行，则该行文字与实际断言不一致，属 L-171 同族的总结面失真。
**Remedy（修补）**：把 `TEST.md:55` 改为「既有 `settings.json` 未被截断为空 + allow/hook 存活（**非**字节相等）」，并在同一行注明 `R5-6` 常设 bats 落地后以该 bats 为准。
**审计标注**：ADR-014 第 5 轮 spot-check `F4`（`INDEPENDENT-REVIEW-6.md` 文末）。

### 0⁗.5 阶段完成自检（`6-review.md:152-166` 九项）与 AC-9 动态门禁判定

**AC-9 口径澄清（先澄清审计 C 提出的疑点）**：AC-9 **不在** `REQUIREMENT.md` 内（实测 `grep -c "AC-9" REQUIREMENT.md` = **0**，该规格全文止于 AC-8），它是**本阶段的过程门禁**，定义在 `flow-kit-bundle/flow-kit/prompts/6-review.md:25-50`：逐检查项查 `gate_config["6-review"][<check>]`，值 `"critical"` **或未配置** ⇒ 🔴 不通过即 PIPELINE PAUSE；`"warn"` ⇒ 只记 REVIEW.md；`"ignore"` ⇒ 跳过。本 change 的 `.flow-active.goal.gate_config["6-review"]` = `"both"`（字符串，非逐检查项映射）⇒ 逐检查项查表**全部落空** ⇒ 一律套用默认级别表：`brooks-review 🔴 Critical = critical` · `brooks-review 🟡 Major = warn` · **`spec 合规失败（AC 未覆盖）= critical`** · `跨模型分歧（spot-check）= warn`。

**AC-9 判定 = ❌ 不通过（PIPELINE PAUSE）** —— 本轮得 **3 条 🔴 Critical**：`R5-6`（AC-2 的常设回归登记不实）与 `R5-7`（AC-3 的行为级常设覆盖为 0）落在默认级别表的「**spec 合规失败（AC 未覆盖）⇒ critical**」一行；`R5-18`（随包隐私检查器在已安装形态下不可达 ⇒ 消费者项目双侧门禁 100% 静默失效）落在「`brooks-review 🔴 Critical = critical`」一行，且同样击穿 `AC-6 ③` 的落地声明 ⇒ **两条判据路径独立成立**，不因 `gate_config` 形态而改变结论。

| # | 检查项 | 验证方式 | 状态 |
| --- | --- | --- | --- |
| 1 | `REVIEW.md` 已写入 `.specs/<change-id>/` | `test -f .specs/health-fix-2026-09b/REVIEW.md`（本文件） | ✅ |
| 2 | Spec 合规审查已完成 | §A 第 5 轮快照 + §0⁗.3.2 三份审计回执 + §0⁗.3.3 spot-check 回执的 AC 逐条表 | **❌**（AC-2/AC-3 的常设回归声明与实物不符 ⇒ `R5-6`/`R5-7`，spot-check 的 `F1`/`F2` 独立确认；**AC-6 ③ 的消费者回退路径在已安装形态不可达 ⇒ `R5-18`**；AC-1/AC-4/AC-5/AC-7 另属**部分覆盖**，见 `R5-9`…`R5-12` 与 `R5-26`） |
| 3 | 代码质量审查（6 维衰退风险）已完成 | §B + §0⁗.3.2 三份审计回执 + 主 agent 亲验 | ✅（每条发现标 R 维度） |
| 4 | UI 视觉审查已完成（前端项目）或已声明跳过 | 非前端项目：`.specs/health-fix-2026-09b/UI-DESIGN.md` 不存在；变更面 UI 扩展名（`.css/.tsx/.vue/.html/.svelte`）计数 = **0** | ⚪ **N/A（已声明跳过）** |
| 5 | 动态门禁判定（AC-9）已通过（无 🔴，或已记录接受风险） | 见上方判定 | **❌**（**3 🔴** ⇒ PIPELINE PAUSE） |
| 6 | Gate 失败项（如有）已记录在 REVIEW.md | §0⁗.4 的 `R5-6`/`R5-7`/`R5-18`（含四要素 + Remedy）+ §0⁗.6 结论 | ✅ |
| 7 | 技术债已同步到 `CONTEXT.md` | `.specs/CONTEXT.md` 本轮新增 **TD-082…TD-090**（9 条：`R5-1`…`R5-5` 的 v2 项 + `R5-2`/`R5-11`/`R5-13`/`R5-17`/`R5-25` 五条登记债；复核命令 `grep -o '^| TD-0[0-9][0-9]' .specs/CONTEXT.md \| tail -9`） | ✅ |
| 8 | `TEST.md` 5 轮金字塔完整性已验证（功能/性能/安全/兼容/可观测） | `grep -n '^## 第 N 轮' .specs/health-fix-2026-09b/TEST.md` ⇒ §1 功能 · §2 性能 · §3 安全 · §4 兼容 · §5 可观测 | ✅ |
| 9 | `.flow-active` 关键字段（phase/task_id/change_id/updated_at）已通过 jq 落盘 | `jq -e '.phase,.task_id,.change_id,.updated_at' .flow-active` + `33-flow-active-integrity.sh` **rc=0**（带 `HOOK_BASE_DIR`/`PROJECT_ROOT`） | ✅ |

**自检结论**：第 **2**、**5** 项为 ❌ ⇒ 按 `6-review.md:163-166`（`auto_advance=false` 分支：「有 ❌ → **禁止进入 toll-gate**，补齐缺失项后重新自检」）与 `:47-56`（「检测到 ≥ 1 个 critical 问题时，停下来。**禁止自动继续**」+ 必须调用 AskUserQuestion）⇒ 本阶段**必须停下等待用户裁决**（回退目标与修复范围见 §0⁗.6）。

### 0⁗.6 第 5 轮结论与裁决（`auto_advance=false` ⇒ 已按方案 A 裁决并回退 `4-dev`）

**审查面**：`534e3e84` → HEAD `1b5a9c39a3`（99 提交 / 106 文件 / +29571 −157）· review-package 31,984 行 · **3 个独立只读审计**（A = 隐私 / 门禁 reference 面 · B = 钩子与安装器面 · C = 需求可追溯 / 交付物面；三者 `verdict` 均为 **fail**）+ 主 agent 逐条亲验（A 的 🟡×3 与 🟢×1、B 的 🔴 与 🟡×5 均由主 agent 独立夹具复现，见各条「证据」）。

**发现汇总（`R5-1`…`R5-27` = **27** 条）**：**3 🔴** + **15 🟡** + **9 🟢**（其中 `R5-26`/`R5-27` 来自 ADR-014 跨模型 spot-check，见 §0⁗.3.3）

| 级别 | 条目 | 处置口径（`6-review.md:289-296`） |
| --- | --- | --- |
| 🔴 ×3 | `R5-6`（AC-2 的常设回归登记不实）· `R5-7`（AC-3 无行为级常设覆盖）· **`R5-18`（随包隐私检查器在已安装形态下不可达 ⇒ 消费者项目推送/提交双侧门禁 100% 静默失效；主 agent 扩面确认「安装位本身即错层」，不止 symlink 形态）** —— 其中 `R5-6`/`R5-7` 另经 spot-check 的 `F1`/`F2` 独立确认（含变异实证） | 必须修 + **阻塞 toll-gate** |
| 🟡 ×15 | `R5-1`/`R5-3`/`R5-5`（台账重复条目 · 报告计数系统性陈旧 · `SELF_EXCLUDE` 未追加新审查档）· `R5-8`/`R5-9`/`R5-10`（审计 C 的 F3/F4/F5：计数不可复算 · AC-1 核心判据无 bats · AC-4 判别形态未触达）· `R5-14`（A1：缺文件仍报绿）· `R5-15`（A2：磁盘侧 grep 未隔离候选 ⇒ fail-open）· `R5-16`（A3：rev 面 7.084–7.509 s 超 5 s 预算，由 🟢 上修）· `R5-19`…`R5-23`（审计 B 五条：pre-commit 早退 · settings 非法 JSON 静默中止 · `phases_done` 短路 · ADR 上限静默丢弃 · NFR 判据只扫变更集）· **`R5-26`**（spot-check `F3`：AC-7 删除注入因 `$HOME` 回落而不封闭） | 进 fix loop（不阻塞 toll-gate）；**裁决 = 全修** |
| 🟢 ×9 | `R5-2`/`R5-4`（台账类型漂移 · 两份复现脚本无常设门禁）· `R5-11`/`R5-12`/`R5-13`（审计 C 的 F6/F7/F8）· `R5-17`（A4：`/home/ubuntu/` 被占位符表吞掉）· `R5-24`/`R5-25`（审计 B：死变量 · 项目级副本无漂移守护）· **`R5-27`**（spot-check `F4`：`TEST.md:55`「字节不变」措辞与 AC-2 断言面冲突） | 登记 `MINOR-DEFERRED.md`，不入 fix loop |

**AC-9 动态门禁判定** = **❌ 不通过（PIPELINE PAUSE）** —— 3 条 🔴（口径与九项自检见 §0⁗.5）⇒ 按 `6-review.md:47-56` 必须停下、调用 AskUserQuestion、禁止自动继续。

**关键结论**：主线 **fail-closed 收敛成立**（审计 A 复核第 1 轮的 `F1`/`F2`/`F3`/`F5`/`F6`/`F7` 逐项通过；`make check` 21 项全绿 · `bats` 1064 ok / 0 not-ok · 隐私门禁真仓命中 0）。本轮真问题集中在**「声明已接线，实际不可达 / 不可复现」**一族：`R5-6`（声称有常设回归，实测 0 例）· `R5-7`（声称 bats 覆盖推送拦截，实测只 `bash -n` + 文本 grep）· `R5-18`（声称消费者回退路径，实测已安装形态永远解析不到检查器）· `R5-19`（隐私块排在无 Makefile 早退之后）· `R5-23`（判据只有变更集模式，归档后自红）—— 与本 change 的立项目标（消灭「未能检查却说通过」）**同源**，属必须闭合的同类缺陷。

**修复范围（用户裁决 · 已生效）**：**方案 A** —— 🔴 三条 + **全部 15 🟡** 进 fix loop（新增 `T-FIX-14`…），回退 `4-dev`；🟢 **九条**登记 `MINOR-DEFERRED.md`。**时点裁决** = **「先派发修复，spot-check 回执并入同批」** ⇒ spot-check 的 `F1`/`F2`（= `R5-6`/`R5-7` 的独立确认）并入对应 fix 任务的判据要求，`F3`（⇒ `R5-26`）作为新增 🟡 并入同批，`F4`（⇒ `R5-27`）随 `TEST.md` 措辞订正顺手闭合（仍计 🟢）。备选记录：方案 B（3 🔴 + 4 条关键 🟡）与方案 C（只修 🔴）均未被采纳。理由：`R5-15`（fail-open）与 `R5-16`（静默漏检 / 超预算）与本 change 的安全与性能目标同源；`R5-18`/`R5-19` 直接击穿 `AC-6 ③`；`R5-23` 会让归档后的 `make check` 自红；且逐条 Remedy 都小（多为 1–3 行 + 1–2 条 bats 腿）。

**spot-check 回执（已回 · 2026-09-27）**：`8dd172a1-aef0-48dc-ade7-66909f671c8e` · `qwen-token-plan-cn/qwen3.8-flash` ⇒ **`Verdict: fail` · 🔴 2 · 🟡 1 · 🟢 1**，全文已追加到 `INDEPENDENT-REVIEW-6.md` 文末；其 2 条 🔴 经比对**均为 `R5-6`/`R5-7` 的独立确认**（不新增 🔴，故 AC-9 的 3 🔴 判定不变），另 2 条新增发现记为 `R5-26`（🟡）/ `R5-27`（🟢）。逐条处置表见 §0⁗.3.3。



## 0‴. 第 4 轮审查（阶段 5 第 9 次执行 → `T-FIX-12` 后重审 · **进行中**）

> **状态**：本节为第 4 轮的**输入面**（第 3 轮 `verdict=fail` 的处置闭环 + 阶段 5 第 9 次执行的新发现 + 阶段 4 复审的 `R4-M1`）。第 4 轮的 L2 / L3 / spot-check 结论将在阶段 5 判定重取（第 10 次执行 REPRO9 全绿；`R4-M1` 裁决「本 change 内修」后再取第 11 次执行 REPRO10）之后补入 `0‴.3` … `0‴.6`。

### 0‴.1 第 4 轮输入：阶段 5 第 9 次执行（REPRO8 · HEAD `bf3763f`）的新发现

| ID | 级别 | 一句话 | 关键证据 | 出口 |
| --- | --- | --- | --- | --- |
| `R4-1` | 过严红（已闭合） | `T-FIX-11` 一度过度收紧：候选在 index 侧可读（`git cat-file -t ":$file"` = `blob`）但工作树缺失时被判「不可读」⇒ 门禁对合法状态报红 | 修复前夹具 10 PASS / 5 FAIL（`/tmp/p6c/tfix11-pre-fix.txt`）· 主 agent 16 腿夹具 16/16 · 执行者四腿（过严红 / index 侧泄漏被检出 / gitlink 正确 fail-closed）+ `bats` 1061 ok | `T-FIX-11`（`38f3a38`） |
| `R4-2` | **🔴 待关闭** | **NFR 预算回归**：`make check-path-privacy` 5 次实测 `10.741/10.885/10.783/11.510/11.469 s` ⇒ **均值 11.078 s = 预算 221.6%**（判据 `REQUIREMENT.md:495`「单次运行 ≤5 秒」· `TEST.md:248`「超阈值即未满足」· `TEST.md:265` 不做负载折算） | 原始回执 `PHASE5-RECEIPTS.md` §R-2（门禁表）/ §R-3（A/B 与微基准）· A/B：`7b624dc`（594 行）**3.191 s** → `20847e1`（`T-FIX-07`，692 行）**10.662 s** → HEAD `bf3763f`（769 行）**10.778 s**（sys 2.120 → 11.186）· 机制 = `check-path-privacy.sh:586` 对每个候选调一次 `git grep --cached`（1594 次进程）· 微基准 = 4.28 ms/次（×1594 ≈ 6.8 s）vs 一次全 index 扫描 **0.023 s** | `T-FIX-12`（`TASK.md:2390-2489` · `c177fba`）⇒ 第 10 次执行取证据。**闭环状态（主 agent 独立复核 · 2026-09-25）**：✓ 修复后 3 次计时 **3.56 / 3.47 / 3.47 s**（rc=0，对照修复前均值 11.078 s = 221.6%）· ✓ 全 index 批量扫描与候选面（`git ls-files -z --` 无 pathspec）同集合、无面扩大 · ✓ fail-closed 保留（批量 `git grep` rc≥2 ⇒ exit 1）· ✓ 自证四数口径不回退（候选 1601 / 扇扫 1595 / index 侧 13 / 不可读 0）· ✓ 隐私套件 30 ok / 0 not-ok、全量 `bats` 1061 不变（见 `MINOR-DEFERRED.md` 的 T-FIX-12 复核记录） |
| `R4-M1` | 🟡（裁决：**本 change 内修**） | **bundle 形态 fail-open（R4-M1）**：检查器 `check-path-privacy.sh` 在 `reference/` 内、但 `path-privacy-allowlist.txt` 缺失时（旧版安装器 / 手工 symlink / 半拷贝目录），`pre-push` 与 `pre-commit` 都打印 `ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描`（成因不符）且 **rc=0 放行** ⇒ 含真实形态探针的推送/提交被静默放过 | 主 agent 夹具 `/tmp/p6d/r4m1-probe.sh`：缺陷态 `pre-push rc=0` + `pre-commit rc=0`，对照态（检查器同缺）措辞不可区分 · 代码点 = `flow-kit-bundle/hooks/pre-push/pre-push.sh:87-100`（`scan_rev()` 的 `bundle)` 分支）与 `flow-kit-bundle/hooks/pre-commit/pre-commit.sh:56-75` · 原文见 `MINOR-DEFERRED.md:1310` | 用户裁决 = **本 change 内修** ⇒ `T-FIX-13`（`TASK.md` 末块 · `<depends_on>T-FIX-08</depends_on>`）⇒ **REPRO10（第 11 次执行 · 25 条判据）** 取证据；先红基线 = `<verify>` 预跑 rc=1（初版 8 条红腿 → 判据夹具缺陷 **TD-081** 修订后 **6 条** · `/tmp/p6d/verify-tfix13.sh` sha256 `242fa9c4…`，新增 L3d/L4c）· 处置记录见 `MINOR-DEFERRED.md` 的 R4-M1 段 |

**第 9 次执行其余面全绿**（判据 23/23 ✅ · `bats` 1061 ok / 0 not-ok · `make check` 21 ✅ · 隐私门禁 命中 0 / 清单外 0 · 包校验 漏配 0 · 阶段门沙箱六态 ✅）⇒ 第 9 次执行**判定 ❌ 未通过**，唯一红面 = NFR 预算（见 `PHASE5-RECEIPTS.md` §R-5）。另有判据运输面缺陷 `TD-077`（复算脚本 NFR 段当时硬编码 rc=0，已同批修为真断言）。

### 0‴.2 第 4 轮待复核的闭环清单（第 3 轮 `verdict=fail`：5 🔴 + 13 🟡 + 12 🟢 · 见 §0″.6）

| 第 3 轮发现 | 处置任务 | 提交 | 复核面（第 4 轮须重放） |
| --- | --- | --- | --- |
| `R3-1`（`core.quotePath` 下非 ASCII 名整跳）· `R3-2`（index-only 泄漏不可见） | `T-FIX-07` | `20847e1` | 非 ASCII 名 + ASCII 对照夹具 · index-only 泄漏夹具 · 自证四数口径 |
| `R3-14`（消费者项目 hook 断链）· `R3-17`（无同意替换既有 pre-push）· `R3-21`（jq 缺失静默）· `R3-23` | `T-FIX-08` | `2f01f39` | pre-push 五场景（无 Makefile+干净 / 无 Makefile+泄漏 / 纯删除 / 仅 `test:`+干净 / 仅 `test:`+泄漏） |
| `R3-15`（`awk -v` 反斜杠吞噬 ⇒ realpath 检测失明）· `R3-16`（未加引号路径含空格）· `R3-22`（无锚点静默 `SKIP`） | `T-FIX-09` | `81c920e` | 21 腿夹具（含空格路径三态 · 双锚点 · 坏 id · 全量模式脏/净） |
| `R3-18`（漂移不具名侧）· `R3-19`（空集合计数静默中止）· `R3-20`（`diff` rc=2 被吞） | `T-FIX-10` | `d840a12` | 37 腿夹具（PATH 影子 `diff` 恒 rc=2 · 双侧清空 · 双向反向控制） |
| `R3-3` … `R3-8` · `R3-31` | `T-FIX-07` | `20847e1` | 同 `T-FIX-07` 面 |
| `R3-32`（审查期 index 篡改）· `R3-29`（过程面） | 过程收口（`L-161` · `TD-070`） | `bf3763f` 等 | 派发词「开工/收工各报 `git status --porcelain` + `git diff --cached --stat`」 |
| `R3-9` … `R3-13` · `R3-24` … `R3-28`（🟡/🟢 观察项） | **不修**（`MINOR-DEFERRED.md` 已登记） | — | 阶段 7 triage 面（`MINOR-DEFERRED.md` 的 R3-M / R3-24…29 表） |

> **注**：`R4-1`/`R4-2` 编号续接第 3 轮命名空间（`R3-*` = 第 3 轮 · `R4-*` = 第 4 轮新发现）；`F-*` 编号保留给第 3 轮之前的阶段 6 发现（`F-18`…`F-21`）。

---

## 0″. 第 3 轮审查（fix 循环 + 阶段 5 重验后重审 · HEAD `7b624dc`）

### 0″.1 复审面与运行标识

| 项 | 值 | 来源 |
|---|---|---|
| HEAD | `7b624dc` | `git log --oneline -1` |
| 变更集（全量） | 96 files / **+25463 / −153** | `git diff 534e3e8..HEAD --shortstat` |
| 本轮新增面 | `cb21c03..HEAD` = 14 files / +1259 / −96；其中**非 `.specs/` 只有 3 件**：`check-path-privacy.sh` + 双源 `test/test_path_privacy_gate.bats` | `git diff --name-only cb21c03..HEAD` |
| 全量测试 | `1..1029` · **ok=1029 / not ok=0**（`npx bats --count test/` = 1029） | TEST.md §D-9-2 · `/tmp/fk-reproduce-5-r7/` |
| 门禁总闸 | `make check` **rc=0** · 21 ✅ / 0 ❌ | 同上 |
| 隐私门禁 | `make check-path-privacy` **rc=0** · 候选 **1595**（= `git ls-files` 总数）− 自排除 6 = 实际扫描 **1589** · 命中合计 0 / **清单外命中 0** | §0″.4 主 agent 亲跑 |
| 复现器 | REPRO7（阶段 5 第 8 次执行）= **18/18 判据 rc=0 + 7/7 门禁 rc=0** | `PHASE5-RECEIPTS.md §P` |
| 独立面 | L2 第 4 轮 **pass**（`INDEPENDENT-REVIEW-5.md:866-961`）· L3 第 13 轮 **pass**（`L3_artifact_hash: 0db9f23df9c9…`） | 同上 §Q |
| fix 六件 | `T-FIX-01` … `T-FIX-06` 的 `<verify>` 各 **rc=0**（主 agent 逐条独立抽取后原样复跑；`T-FIX-06` 见 `MINOR-DEFERRED.md`「复核记录」） | `TASK.md` |
| 本轮纪律 | 审查未修改任何生产件；本文件与 `MINOR-DEFERRED.md` 为本轮唯二产出（R3.3） | `git status` |

### 0″.2 第 2 轮发现闭合表（逐条 + 证据）

| ID | 第 2 轮 | 症状 | 闭合提交 | 第 3 轮独立证据 | 判定 |
|---|---|---|---|---|---|
| **F-18** `REVIEW.md:61` | 🟡 | 扫描面标签「工作树」过度声明（候选面实际来自 index） | `421640a` | `SCAN_SURFACE='工作树（git index：已 add / 已提交）'`（`check-path-privacy.sh:153`；rev 模式取实际 revision `:165`）；门禁实跑自证行逐字命中该串（§0″.4） | ✅ 闭合 |
| **F-19** `REVIEW.md:88` | 🟡 | 「候选 > 0 但实际扫描 = 0」仍打印 ✅ rc=0 | `421640a` | `SCANNED_COUNT`（`:376` 初始化 · `:490` 在自排除之后/`scan_file` 之前递增 · **`:496` fail-closed**：`SCANNED_COUNT=0 && CANDIDATE_COUNT>0` ⇒ 自证块 + `🔴 候选面经自排除后为空，无法判定` + `exit 1`）· 自证行打印实际扫描（`:502`/`:567`） | ✅ 闭合 |
| **F-20** `REVIEW.md:89` | 🟡 | `mktemp_checked` 内 `exit 1` 位于命令替换 ⇒ 只退子 shell | `421640a` | 定义 `:124`（fail-closed + 位置报文 `:130`）· **4 个调用点 `:139`/`:140`/`:141`/`:516` 全部 `|| exit 1`** | ✅ 闭合 |
| **F-21** `REVIEW.md:90` | 🟢 | `make -j` jobserver 警告 | — | 用户裁决 `Not-applicable`（改用 `+$(MAKE)` 会让 `make -n` 判红，见 `TASK.md:1826` 张力点）⇒ 登记 `MINOR-DEFERRED.md` | N/A |
| 第 1 轮 8 条（F1…F8） | — | 见 §0′.2 | `6e39cfb`/`521b21c`/`6e94d60` | 第 2 轮已逐条闭合并活性重放；**本轮复核载体未回退**：`check-path-privacy.sh` 现 **594 行**（修复态 548 行之上叠加 `T-FIX-06`）· `check-gate-sync.sh` `PAIRS_TOTAL=14` 常量单点 · `Makefile` `_report_viol() {` 唯一 | ✅ 维持 |

**活性重放（`T-FIX-06` 面 · 第 2 轮执行 · 证据存档）**：生产件还原 `421640a^`（27942 B vs 31930 B）⇒ `npx bats test/test_path_privacy_gate.bats` rc=1 · ok=20 / **not ok=4**，红的恰是新行为依赖例（`not ok 14` F-18 措辞 · `not ok 21`/`22` F-19 坏/好态 · `not ok 23` F-20 坏态），而 `#24`（F-20 好态，断言「旧件也无 false-red」）保持绿 ⇒ 判别方向正确；`cp -p` 还原后 `git diff --exit-code` 干净。

### 0″.3 同夹具对照（在 `7b624dc` 上重跑 · 输出存 `/tmp/p6b/four-state-round3.txt`）

| 态 | 构造 | 第 1 轮读数 | 本轮读数（主 agent 亲跑） |
|---|---|---|---|
| A | 规范环境 + 真泄漏且已跟踪（阳性对照） | rc=1 ✅ | **rc=1** ✅（自证行 `候选文件 2 个` / `实际扫描 2 个`） |
| B | 坏 `TMPDIR`（第 1 轮 🔴 F1） | rc=0 ❌ 假绿 | **rc=1** ✅ fail-closed |
| C | 非 git 目录（第 1 轮 🔴 F2） | rc=0 ❌ 假绿 | **rc=1** ✅ fail-closed |
| E | git 仓且 index 为空（spot-check 变体） | rc=0 ❌ 假绿 | **rc=1** ✅（自证行 `候选文件 0 个` ⇒ 0 候选 ≠ 干净） |
| F | 泄漏仅在二进制载体（第 1 轮 🟡 F3） | 静默丢 ❌ | **rc=1** ✅（自证行 `候选文件 2 个` / `实际扫描 2 个`） |
| D | 控制（同 A 布局但无泄漏 · 反假红） | rc=0 ✅ | **rc=0** ✅ |

### 0″.4 只读深审回执（对抗式：2 个独立审计 subagent + 主 agent 亲验）

#### A. 隐私门禁面（`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` · 594 行）

审计 subagent `dcf10215-ce85-4f97-895b-d6fd540c92b9`（只读 · 夹具 `/tmp/sa-audit/` · 仓库零改动）+ 主 agent 独立复跑（夹具脚本 `/tmp/p6b/verify-audit-c1c2c3.sh` · 读数 `/tmp/p6b/verify-audit-c1c2c3.txt`）。

| ID | Severity | 位置 | 症状 | 主 agent 独立复现 | 判定 |
|---|---|---|---|---|---|
| **R3-1** | 🔴 Critical | `:294`/`:302`（枚举）· `:450`（`[ -f ] \|\| return 0`）· `:490`（计数）· `:562-569`（自证行） | `core.quotePath` 默认 true ⇒ `git ls-files` 对非 ASCII / 含 `"`、`\`、控制字符的路径输出 **C 引号串**，该字面名在磁盘不存在 ⇒ 整文件静默跳过，却已被计入「实际扫描」 ⇒ ①该类文件名中的任何泄漏判为干净 ②自证数虚高（`F-19` 的「实际扫描 = 0 ≠ 干净」保护被绕过） ③`is_self_exclude`（`:344-351`）同样比不中 ⇒ 既不可扫也不可豁免 | ✅ **亲验成立**：本仓 `git ls-files \| grep -c '"'` = **4**（`FLOW-KIT-用户指南.md` 根/`flow-kit-bundle/` 各一 · `flow-kit-技术设计.pptx` · `flow-kit-用户指南.pptx`），4/4 `[ -f ]` = 否 ⇒ 真实扫描 = 1595 − 6 − 4 = **1585**，自证行却称 1589；夹具（探针 `'/home/''zz-p6verify-pro''be/leaked.txt'` 写入 `docs/说明书-秘密.md` + `git add -A`）⇒ `候选文件 2 个 / 实际扫描 1 个 / 命中合计 0 条 / 清单外命中 0 条 / ✅` **rc=0**；同泄漏改 ASCII 名 `docs/plain-secret.md` ⇒ `清单外命中 1 条` **rc=1** | **confirm · 🔴**（同第 1 轮 F1/F2 类：可达的静默假绿，且直接违背本 change AC-7「消灭假绿」）· 修复方向已亲验：`git -c core.quotePath=false ls-files -z \| while IFS= read -r -d '' f` 取出 4 个真名且逐条 `[ -f ]` = OK（bash 3.2 兼容形态） |
| **R3-2** | 🔴 Critical | `:302`（候选 = index）vs `:450`/`:455`（内容 = 工作树磁盘）· 声明面 `:147-153` | 候选集来自 index、内容读工作树 ⇒ 泄漏**已 `git add`**、随后工作树改回干净（未再 add）⇒ `命中合计 0 条 / ✅ rc=0`，而 commit 仍会写入 index 里的泄漏 ⇒ 直接击穿 `hooks/pre-commit/pre-commit.sh:33 → Makefile:127` 拦截链 | ✅ **亲验成立**：夹具 `staged.md`（探针写入 → `git add` → 工作树改写为 `clean now`）⇒ `命中合计 0 条 / ✅` **rc=0**，同时 `git show :staged.md` 仍含探针；对照（泄漏同时在工作树）⇒ **rc=1**；`CHECK_REV=HEAD` 模式 ⇒ **rc=1** | **confirm · 🔴**（拦截链断在 change 的头号交付面 pre-commit 上）· 修复方向已亲验（git 2.43.0）：`git show :"$file" \| grep -naE "$PAT"` 实打 index 内容（输出 `2:see …leaked.txt here` rc=0）· `git grep --cached -naE` 同效；同夹具旧法（读磁盘）rc=1 无命中 |
| **R3-3** | 🟡 Important | `:233-234`（校验器去前导空白）vs `:519-522` + `:527`（键提取只剥 `#` 与尾随空白） | 清单条目行首带空格时被校验器接受并计入「允许清单 N 条」，但键带空格 ⇒ 精确匹配失败 ⇒ 该命中判清单外 ⇒ 假红 + 信任根失真（归因指向源码行而非清单格式） | ✅ **亲验成立**：清单行 ` docs/leak.md:1  # 理由`（`cat -A` 确认行首空格）⇒ `允许清单 1 条 … 清单外命中 1 条` **rc=1**；同行去行首空格 ⇒ `清单外命中 0 条 / ✅` **rc=0** | **confirm · 主 agent 降级 🔴→🟡**：方向为假红（无泄漏放行），按 severity 表与第 1 轮 F3/F4（同属口径不一致）判 🟡 |
| **R3-4** | 🟡 Important | `:110-115`（`:112 for f in $TMP_FILES`） | 未加引号 ⇒ `TMPDIR` 含空格时 `cleanup()` 列出的路径被拆词 ⇒ 临时件全部残留（含允许清单副本与命中缓冲 `file:line:content` 原文） | ✅ **亲验成立**：`TMPDIR='/tmp/p6b/tmp dir'`（含空格）跑门禁 ⇒ `rc=0` 且该目录残留 **4** 个 `tmp.*`；对照 `TMPDIR=/tmp/p6b/tmpdir-nospace` ⇒ 残留 **0** | accept · 🟡（违背本 change 自订 F5 清理契约；bats 第 20 例只用正常 TMPDIR ⇒ 判据不触达） |
| **R3-5** | 🟡 Important | `:139-142`（`TMP_FILES` 在三处 mktemp 之后才赋值） | 早期 `mktemp` 失败时已建临时件未登记 ⇒ 不清理；`:103-104` 的「单一 trap 覆盖全部 TMP」声明过宽 | 审计实测：PATH shim 令第 3 次 `mktemp` 失败 ⇒ `rc=1` + mktemp 报文恰 1 条（F20 行为正确）但残留 **2** 个 | accept · 🟡 |
| **R3-6** | 🟡 Important | `:519-522`（键提取管道无 rc 断言）· `:284`（`grep -c` rc=2 折算为 0） | 机械失败 ⇒ 键集空/截断 ⇒ 清单内命中被判清单外（假红，方向安全）；与 F1 自订的「机械失败必须断言 rc」规则相悖 | 静态判定 + 构造性论证（未构造器械故障复现） | accept · 🟡 |
| **R3-7** | 🟡 Important | `:426-432`（`p="${stripped%%:*}"` / `l="${rest%%:*}"`） | rev 模式按裸 `:` 切分 ⇒ 文件名含 `:` 的 tracked 文件永久假红且清单无法表达该键（pre-push 路径 `hooks/pre-push/pre-push.sh:48` 传 `CHECK_REV`） | ✅ **亲验成立**：夹具 `docs/a:b.md` 含探针（`CHECK_REV=HEAD`）⇒ `清单外命中 0 条` + `🔴 不可归因命中 1 条` **rc=1**；同泄漏改普通名 `docs/ab.md` ⇒ 正常归因 `清单外命中 1 条` | accept · 🟡 |
| **R3-8** | 🟡 Important | `:215`（`IS_COMMENT_OR_BLANK_RE`）vs `:232`（`core=${line%%#*}`） | 「注释口径单点」只覆盖整行形态：尾随 `<!-- … -->` 属 ERE 注释却让整份清单格式违例 ⇒ fail-closed 的假红 | ✅ **亲验成立**：清单行 `docs/leak.md:1 <!-- 理由注释 -->` ⇒ `🔴 允许清单格式违例` **rc=1**；对照（整行 `<!-- … -->` + 条目用 `#` 尾随注释）⇒ `允许清单 1 条 / 清单外命中 0 条 / ✅` **rc=0** | accept · 🟡 |
| **R3-9…R3-13** | 🟢 Minor | 见 `MINOR-DEFERRED.md` 第 3 轮表 | 死条件（`:421`/`:422`/`:462`/`:463`）· 无用符号（`:407 local lineno line uname`、`:372 HITS_TOTAL=0` 立即被 `:512` 覆盖）· 文档漂移（`path-privacy-allowlist.txt:8` 自述口径 ≠ `:215`）· shellcheck `SC2317` ×4（info，`cleanup()` 误报）· 自证行 `:568` 措辞易被读成「已扣占位符行」 | 静态 | → `MINOR-DEFERRED.md` |

审计**已验证无问题**（主 agent 抽验一致）：唯一 EXIT trap（`:116`）· 注释口径定义单点（`:215` 供 `:228`/`:284`/`:519`）· 坏 `TMPDIR` ⇒ rc=1 且报文恰 1 条 · 非 git 目录 / 空 index ⇒ fail-closed · F-19 现场（候选 2 全自排除 ⇒ `实际扫描 0` 且不打印 ✅）· `rev` 模式覆盖 L-131 与注解 tag 对象 sha · 占位符逐命中判定（三 locale）· 二进制载体归因正常 · 文件名含空格不触发引号化 · 无 GNU-only 构造 · `bash -n` rc=0。

#### B. 其余 12 个生产件面（hooks / 安装 / 打包 / Makefile 门禁容器）

审计 subagent `3ac72cc1-1d41-49e5-a8ce-afc6848d09ac`（6 维衰退风险 + 兼容性回归 · 只读 · 夹具 `/tmp/sb-audit/` · 报告全文见其回执，ID 对照：审计 C1→R3-14、C2→R3-15、C3→R3-16、C4→R3-17、I1–I6→R3-18…R3-23、M1–M6→R3-24…R3-29）+ 主 agent 独立复跑（夹具脚本 `/tmp/p6b/verify-audit-b.sh`、`/tmp/p6b/c2c3.sh`、`/tmp/p6b/c3.sh`、`/tmp/p6b/c3b.sh`；读数 `/tmp/p6b/verify-audit-b.txt`、`/tmp/p6b/verify-c2c3.txt`、`/tmp/p6b/verify-c3.txt`、`/tmp/p6b/verify-c3b.txt`）。

| ID | Severity | 位置 | 症状 | 主 agent 独立复现 | 判定 |
|---|---|---|---|---|---|
| **R3-14**（审计 C1） | 🔴 Critical | `hooks/pre-push/pre-push.sh:48`、`:59` · `hooks/pre-commit/pre-commit.sh:32-36` | 两个钩子直接调用**只在 flow-kit 本仓 Makefile 里存在**的 target（`make check-path-privacy` / `make check`）且无 target 存在性守卫 ⇒ 装到消费者项目后 pre-push **拒绝一切推送**（bundle 不带 Makefile），pre-commit 在**任何带 Makefile 的项目**里拒绝一切提交；`:59` 的无条件 `make check` 另使「纯删除推送不得 fail-closed」（ADR-027②）失效 | ✅ **亲验成立**（四夹具，`/tmp/p6b/verify-audit-b.txt`）：① 无 Makefile + 普通推送 ⇒ `make: *** 没有规则可制作目标"check-path-privacy"。 停止。` + `🔴 拒绝推送 refs/heads/main…` **rc=1** ② 无 Makefile + 纯删除推送（全 0 sha）⇒ `没有规则可制作目标"check"。 停止。` **rc=2** ③ 无 Makefile + 空 stdin ⇒ **rc=2** ④ 项目 Makefile 仅含 `test:` ⇒ `make test` 通过后 `[archive-commit-gate] path-privacy check failed, commit rejected` **rc=1** | **confirm · 🔴**（消费者项目是本 change 的交付面：`install.sh --project /path/to/your-project`、`flow-kit-bundle/README.md:36`）· 修复方向：沿用仓内既有「无 Makefile / 无 npx 则跳过」守卫语义加 target 探测（`make -n <target> >/dev/null 2>&1` 或 `grep -q '^<target>:' Makefile`），缺失时打印 SKIP 并**放行**；`:59` 的 `make check` 需同样守卫 |
| **R3-15**（审计 C2） | 🔴 Critical | `Makefile:217`（`BAN` 常量）· 注释 `:157` | `\brealpath\b` 经 make → bash → `awk -v` 三层转义后 `\b` 被 awk 解释为**退格 0x08** ⇒ 模式实际是 `\x08realpath\x08`，永不命中；而注释恰把 `realpath` 列为头号 GNU-only 违禁构造 ⇒ 该判据对 `realpath` **完全失明**却打印 ✅ | ✅ **亲验成立**（`/tmp/p6b/verify-c2c3.txt`）：`awk -v P='\brealpath\b' 'BEGIN{print length(P)}'` ⇒ **10**（字面量 12）且 `printf 'x=$(realpath .)' \| awk -v P=… '$0~P'` 无命中；端到端夹具（整份 Makefile 拷入临时 git 仓 + `FLOW_KIT_CHANGE_BASE`）：新增 `rp.sh` 含 `realpath .` ⇒ `✅ NFR 兼容性判据通过…` **rc=0**；同夹具正控 `mapfile` ⇒ 🔴 **rc=2**、`grep -P` ⇒ 🔴 **rc=2** | **confirm · 🔴**（新门禁的假绿：自称检查的构造之一不可达）· 修复方向：用字符类边界（`(^\|[^[:alnum:]_])realpath([^[:alnum:]_]\|$)`）替掉 `\b` |
| **R3-16**（审计 C3） | 🔴 Critical | `Makefile:168`（tracked 面）· `:187`（untracked 面）· 对照 `:229` 已用 `while IFS= read -r` | 两道禁构面都用未加引号的 `for _f in $(git …)` ⇒ 文件名含空格时按词拆分，拆分出的伪路径都不存在 ⇒ 整文件静默跳过，仍打印「✅ 无新增 bash4-only / GNU-only 构造」；同一脚本的语法面（`:229`）写法正确 ⇒ 同一判据两种正确性 | ✅ **亲验成立**（`/tmp/p6b/verify-c3.txt`、`/tmp/p6b/verify-c3b.txt`）：未跟踪 `sp ace.sh`（含 `mapfile`）⇒ **✅ rc=0**，拆分项 `sp` / `ace.sh` 均「文件不存在 ⇒ 静默跳过」；同内容改名 `mf.sh` ⇒ 🔴 **rc=2**；**已跟踪**面同证：`git diff --name-only` 确实列出 `sp ace.sh` ⇒ **✅ rc=0**，改名 `mf.sh` ⇒ 🔴 **rc=2** | **confirm · 🔴**（与 R3-15 同族：假绿型覆盖缺口）· 修复方向：两面均改 `while IFS= read -r _f; do … done <<< "$(git …)"` |
| **R3-17**（审计 C4） | 🟡 Important | `lib/install_hooks.sh:124-163`（`deploy_pre_push`）vs `:75-89`（`deploy_pre_commit`） | `deploy_pre_push` 无 `FLOW_KIT_YES` / `read -p` 同意语义即替换既有 `.git/hooks/pre-push`（husky / lefthook / 用户自写钩子）⇒ 他人钩子被静默停用；备份名带 `$$`、事后仅一行输出 | 静态读码确认：`:122-123` 注释明文「pre-push 是『备份后覆盖』…语义必须重写，**禁止照抄** deploy_pre_commit」；`DESIGN D3 item 5` / ADR-022 同口径；pre-commit 的同意门仍在（`:81-88`） | **降级 🔴→🟡 · 非本 change 缺陷**：属 DESIGN D3 / ADR-022 **有意设计**（含 `${bak}.linktarget` 回滚留痕），按 ADR-027① 不得升级为 Critical；建议 v2 补一行恢复路径提示 |
| **R3-18**（审计 I1） | 🟡 Important | `flow-kit/reference/check-gate-sync.sh:114-144` | 漂移报文把 diff hunk 的**左右行号**无条件写成「prompt 侧内容漂移」/「skill 侧内容漂移」——纯新增 hunk（`NaM,N`）的左侧当侧无改动却仍报该侧漂移 ⇒ 定位张冠李戴 | ✅ **静态证实**（读码）：`left_num` 恒取自 hunk 左侧、`>0` 即打印「prompt 侧内容漂移」，与 hunk 类型（`a`/`c`/`d`）无关；审计夹具（只给 skill 侧加 2 行）实测输出 `定位: prompts/A-evolve.md:2（prompt 侧内容漂移）` 而 prompt 侧改动数 = 0 | accept · 🟡 · 修复方向：按 hunk 类型/`<`、`>` 行决定是否打印该侧，或把措辞降为「hunk 锚点」 |
| **R3-19**（审计 I2） | 🟡 Important | `flow-kit/reference/check-gate-sync.sh:196`（`:212` 顶层裸调用 + `set -euo pipefail` `:8`） | `preset_count=$(printf '%s\n' "$skill_presets" \| grep -c .)`：两侧预设集**皆空**时 `grep -c` 打印 `0` 且 rc=1 ⇒ `set -e` 下赋值失败 ⇒ 脚本**静默中止**（无结论行、无汇总、rc=1，易被读成「发现漂移」） | ✅ **亲验成立**（机制 + 调用点读码）：`bash -c 'set -e; x=$(printf "" \| grep -c .); echo after'` ⇒ 输出为空、**rc=1**；加 `\|\| true` ⇒ 输出 `after=0`、rc=0；脚本 `:212` 为顶层裸调用 ⇒ `set -e` 在函数内有效 ⇒ 真库 17 个预设「潜伏」 | accept · 🟡 · 修复方向：`\|\| true` + 显式空集分支（判为基础设施错误） |
| **R3-20**（审计 I3） | 🟡 Important | `flow-kit/reference/check-gate-sync.sh:112` | `diff_out=$(diff "$tmp_p" "$tmp_s" 2>/dev/null \|\| true)` 把 diff 的 rc=2（临时件不可读等）当成「无差异」⇒ 走 ✅ 分支 | 静态判定（构造性论证，未造器械故障复现） | accept · 🟡 · 修复方向：接住 rc，`>1` 时 `ERRORS++` 并显式报基础设施错误（与 F1 自订规则一致） |
| **R3-21**（审计 I4） | 🟡 Important | `lib/install_hooks.sh:173-180`（jq 硬前置）· 文档面 `flow-kit-bundle/README.md` / `OPENCODE-INSTALL.md` / `flow-kit-bundle/install.sh` | 新增的 jq 硬前置本身 fail-closed 且在任何写盘之前（方向正确），但使 jq 成为**整个安装的硬依赖**（原先仅跳过 settings 合并），文档与入口预检未同步 ⇒ 无 jq 机器上安装中途 abort、无补救提示 | ✅ **亲验成立**：`grep -rn 'jq' flow-kit-bundle/README.md flow-kit-bundle/OPENCODE-INSTALL.md flow-kit-bundle/install.sh README.md` ⇒ **0 命中**；`install.sh:252/276/286` 为裸调用 + `set -euo pipefail` | accept · 🟡 · 修复方向：README / OPENCODE-INSTALL 声明 jq 前置 + `install.sh` 入口预检 |
| **R3-22**（审计 I5） | 🟡 Important | `Makefile:204`（`cat .specs/health-fix-2026-09b/.change-base`）· 包装层 `:262-264` | 一次性 change 锚点被硬编码进**永久构建文件**：该目录一旦归档/删除 ⇒ 判据退化为 SKIP，而包装层把 rc=3 映射成 `exit 0` ⇒ `make check-nfr-portability` 永久静默不验证；另有语义漂移（实际审「base 之后全部改动」而非本次变更） | ✅ **亲验成立**（读码 + 审计夹具实测）：`:204` 硬编码路径 ✓；`:206-207` SKIP + `_write_rc 3` ✓；`:263` `3) … exit 0` ✓；夹具无 `.specs/` ⇒ `SKIP: 变更起点锚点缺失…` **rc=0** | accept · 🟡 · 修复方向：锚点做成 Makefile 变量并给仓内稳定默认值；CI 下未设 `FLOW_KIT_CHANGE_BASE` 时应 rc=2 而非 SKIP |
| **R3-23**（审计 I6） | 🟡 Important | `hooks/pre-push/pre-push.sh:48` | 对每个推送 ref 各跑一次完整 `make check-path-privacy`（N ref ⇒ N 次全仓扫描），其后 `:59` 又跑 `make check` ⇒ 大仓多 ref 线性放大 | 静态判定（未做耗时实测） | accept · 🟡 · 修复方向：按 `local_sha` 去重或 `git rev-list` 求并集后只审一次（与 R3-14 的收敛可合并） |

审计**已验证无问题**（主 agent 抽验一致，共 17 项）：基线锚点 `.change-base` 与任务基线逐字一致 · 10 个 `.sh` `bash -n` 全过 · `shellcheck -S warning` 仅 4 条且全在本次未改动行（与主 agent 独立复跑一致）· 新增行无 bash4+/GNU-only 构造（命中项全是注释；`package-flow-kit.sh:394 declare -A BROOKS_TOOLS`、`sync-hooks.sh:182/197/198 mapfile` 属既有债 TD-035）· NFR 正控有效（`declare -A`/`sed -i`/`grep -P`/`timeout` 逐个命中，`stat -c … \|\| stat -f …` 合规惯用法被按成分豁免）· NFR 三态包装层 rc=0/1/3 与 rc 文件缺失 ⇒ `exit 1` fail-closed · `PAIRS_TOTAL=14` 单点化成立（仅 `:44` 一处计数语义）· 真库 `check-gate-sync.sh` 3/14 绿且**不冒充全绿** · `strip_front_matter` 的 RETURN-trap 在 bash 5.2 正确（局部变量绑定、退出后复位）· `path-privacy-allowlist.txt` 16 行全注释、无 `file:line` 条目、无本机账号路径 · pre-push 畸形输入 fail-closed rc=1 · `sync-hooks.sh --check` 六面 0 漂移 · `validate_staging.sh:54` 与 `package-flow-kit.sh:131-136` 的 pre-push 面一致 · `done-validation.sh:84-89` 新契约方向正确 · `Makefile:106` 聚合与 `:116`/`:125` 薄壳接线正确、`make -n check` 无副作用 · `l3-prompt.sh:361` 体积探测有 `${_adr_sz:-0}` 兜底（对照探针证实必要）· 只读约束遵守（未 add/commit/checkout/stash、未跑 bats/打包脚本）。

审计**未能验证**（记录为审界面边界）：bash 3.2 实机（本机仅 GNU bash 5.2.21 ⇒ 3.2 结论全为静态评估，与 `TD-055` 同面）· `check-path-privacy.sh` 不在其审计面（由 A 面审计员覆盖）· R3-17 的写盘复现（会改他人 hook，只做静态 + 对照）· `package-flow-kit.sh` 打包产物与 `dist/` 新鲜度 · 全量 `make check` / `npx bats test/`（按只读约束未跑）· R3-20 与 M1 仅静态推断。

#### C. AC-5 边界坐实（第 2 轮遗留存疑项）

`git grep -l '/home/<acct>/' HEAD` = **2** 个 tracked 文件 = `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md` / `INDEPENDENT-REVIEW-2.md`（L2/L3 回执的历史文本），被 `check-path-privacy.sh:85-93` 的 `SELF_EXCLUDE` 显式 6 条精确路径清单覆盖（注释声明禁宽通配：宽通配实测会吞 31 处 `<acct>` 形态含 10+ 处真路径）；`TD-063` 已登记 `.specs/**` 该边界。`PHASE5-RECEIPTS.md:1121-1122` 的 2 处 PAT 形态为 `/home/user/` 占位符（由 `PLACEHOLDER_NAMES` 排除）。⇒ **非缺陷**；§A 表中 AC-5 的「0 个文件」表述按此订正为「2 个历史回执文件，受显式自排除覆盖」。

#### D. 主 agent 亲验的干净面

真实仓基线（worktree 模式）：`候选文件 1595 个 / 实际扫描 1589 个 / 命中合计 0 条 / 清单外命中 0 条 / ✅ rc=0`，其中 1595 = `git ls-files | wc -l` ✓、6 条 `SELF_EXCLUDE` 经 `git ls-files --error-unmatch` 逐条确认在 index ✓（唯一失真实见 R3-1）。**R3-1 的算术与修复方向已亲验**：`git -c core.quotePath=false ls-files` 同为 1595 条，其中 4 条非 ASCII 名在真实名下 `[ -f ]` 全为 yes ⇒ 真实可扫描数 = 1595 − 6 = **1589**（引号化关闭时），当前实际只读 **1585**。`make lint`（error 级）与 warning 级 shellcheck 复跑一致：本次变更 12 个生产件 0 error。

### 0″.5 九项自检

| # | 项 | 判定 | 证据 |
|---|---|---|---|
| 1 | review-package 已生成并 Read | ✅ | `bash flow-kit-bundle/flow-kit/scripts/review-package 534e3e8 HEAD > /tmp/review-pkg.md` ⇒ 27661 行 rc=0（`## Commits` / `## Files changed` / `## Diff`）；按 `## Files changed` 面逐面核对 |
| 2 | 覆盖 spec 合规 + 6 维 + UI + verdict | ✅ | §A（AC-1..AC-8 表）· §B（R1–R6 六维）· §C（UI：非前端 ⇒ N/A）· §0″.6 verdict |
| 3 | 每条 finding 含 `**Severity**` token | ✅ | §0″.4 表内 R3-1…R3-13 全带 🔴/🟡/🟢 + Critical/Important/Minor |
| 4 | 代码质量发现含 R1–R6 编号 + 4 要素 + 书本引用 | ✅ | §B 六维编号沿用；R3-1…R3-8 各含 Severity/Symptom/Source/Consequence+Remedy 语义（表列写法） |
| 5 | 🟢 Minor 已写入 MINOR-DEFERRED.md | ✅ | 本轮表（R3-9…R3-13 = M 行）+ 既有 S1–S3 |
| 6 | spot-check 触发条件已判定 | ✅ **已触发** | verdict=fail 且 ≥2 🔴 ⇒ 已派 `qwen3.8-flash` subagent `50a7e688-268c-4e84-8d59-aa5257cdcafb` 复核（结果写入 `INDEPENDENT-REVIEW-6.md`） |
| 7 | 报告里没有自己悄悄改过的代码 | ✅ | 本轮仅改 `.specs/health-fix-2026-09b/{REVIEW.md,MINOR-DEFERRED.md}`；`git status --porcelain` 不含任何生产件/R3.3 成立 |
| 8 | Critical findings 全部入 fix loop | ✅ | 5 条 🔴（R3-1/R3-2/R3-14/R3-15/R3-16）⇒ 追加 `T-FIX-07`…`T-FIX-10`（分解见 §0″.6）；🟡 13 条同批入 fix loop（`T-FIX-07` 带 6 条 · `T-FIX-08` 带 4 条 · `T-FIX-09` 带 3 条） |
| 9 | AC-9 动态门禁逐项判定 | ❌ **不通过** | 见 §0″.6：5 条 🔴 ⇒ 动态门禁「无 Critical」项不满足（🟡 13 条按 `6-review.md:294` 非阻塞，但须在 task 内解决） |

### 0″.6 第 3 轮结论

**verdict: fail** —— 本轮把审查面扩到「2 个独立审计 subagent 的对抗式深审（隐私门禁面 + 其余 12 生产件面）+ 主 agent 逐条亲验」，在 fix 循环后的 HEAD `7b624dc` 上共得 **6 🔴 Critical + 15 🟡 Important + 12 🟢 Minor**（审计 ID 对照见 §0″.4.A/§0″.4.B；含 ADR-014 跨模型 spot-check 回执新增的 R3-30/R3-31/R3-32）。

**🔴 Critical（阻塞 toll-gate 6→7 · 必须修）**

| ID | 一句话 | 载体（本 change 新建/改动面） | 主 agent 亲验 |
|---|---|---|---|
| **R3-1** | 非 ASCII / 含 `"`、`\` 的文件名被 `git ls-files` 引号化 ⇒ 该文件静默跳过却计入「实际扫描」⇒ 这类文件里的泄漏判干净、自证数虚高、`SELF_EXCLUDE` 亦失效 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | ✅ 本仓 4 例 + 双夹具（引号名 rc=0 假绿 / ASCII 名 rc=1） |
| **R3-2** | 候选集来自 index、内容读工作树磁盘 ⇒ 泄漏**已 `git add`**、工作树改干净后不可见 ⇒ `命中合计 0 条 / ✅ rc=0`，直接击穿 `hooks/pre-commit/pre-commit.sh:33 → Makefile:127` 拦截链 | 同上 | ✅ 双夹具三态（index 含探针 + 工作树干净 ⇒ rc=0；`git show :f` 仍含探针；`CHECK_REV=HEAD` ⇒ rc=1） |
| **R3-14** | `pre-push`/`pre-commit` 直接调只在**本仓**存在的 Makefile target 且无存在性守卫 ⇒ 消费者项目**拒一切 push**（bundle 无 Makefile）、有 Makefile 的项目**拒一切 commit**；`:59` 无条件 `make check` 使 ADR-027② 失效 | `flow-kit-bundle/hooks/pre-push/pre-push.sh:48`、`:59` · `hooks/pre-commit/pre-commit.sh:32-36` | ✅ 四夹具（无 Makefile 普通推送 rc=1 / 纯删除推送 rc=2 / 空 stdin rc=2 / 项目仅 `test:` ⇒ commit 被拒 rc=1） |
| **R3-15** | `\brealpath\b` 经 make → bash → `awk -v` 变退格包裹 ⇒ 头号 GNU-only 违禁构造**完全失明**仍报 ✅ | `Makefile:217`（`BAN`） | ✅ 机制（`length=10`）+ 端到端（`realpath` ⇒ ✅ rc=0；同夹具 `mapfile`/`grep -P` ⇒ 🔴 rc=2） |
| **R3-16** | 两道禁构面用未加引号 `for _f in $(git …)` ⇒ 含空格文件名被词拆后静默跳过仍报 ✅（tracked 面 `:168` / untracked 面 `:187`；同脚本语法面 `:229` 写法正确） | `Makefile:168`、`:187` | ✅ 两面双态（`sp ace.sh` ⇒ ✅ rc=0，拆分项 `sp`/`ace.sh` 均「不存在 ⇒ 跳过」；改名 `mf.sh` ⇒ 🔴 rc=2） |
| **R3-30** | rev 模式（`CHECK_REV` / `pre-push`）同样假绿于非 ASCII 文件名：`:294 git ls-tree` 输出引号串 ⇒ `:414 git grep` 把引号串当 pathspec ⇒ rc=1 零匹配 ⇒ `:421` 静默 `return 0` ⇒ R3-1 的假绿同时击穿 `pre-commit` 与 `pre-push` **双路径**（`core.quotePath=false` 也救不了含 `"`/`\` 的名字 ⇒ 必须 NUL 安全枚举同时覆盖两模式） | `check-path-privacy.sh:294`、`:414`、`:421` | ✅ spot-check 独立复现（`CHECK_REV` ⇒ rc=0，而「不带 pathspec 的 `git grep`」能命中）+ 我的 R3-1 夹具 |

**🟡 Important（15 条 · 入 fix loop，按 `6-review.md:294` 不阻塞 toll-gate）**：R3-3…R3-8（隐私门禁：清单前导空白双口径 · 清理清单未加引号 · 早期 `mktemp` 未登记 · 键提取 rc 未断言 · 裸 `:` 切分 ⇒ 冒号名永久假红 · `<!-- -->` 尾随注释判格式违例）· R3-17（`deploy_pre_push` 无同意门 —— **DESIGN D3 / ADR-022 有意设计，按 ADR-027① 降级不升级**，采纳建议 = 补一行恢复路径提示）· R3-18…R3-20（`check-gate-sync`：漂移定位张冠李戴 · `grep -c` 空集在 `set -e` 下静默中止 · `diff` rc=2 折算为「无差异」）· R3-21（jq 硬前置未进文档与入口预检）· R3-22（`.change-base` 一次性锚点硬编码进永久 `Makefile` ⇒ 归档后退化为 SKIP 且包装层映射 `exit 0`）· R3-23（每 ref 一次全仓扫描）· **R3-31**（自证「实际扫描」先增后扫 ⇒ 无法区分「被豁免」与「被漏扫」）· **R3-32**（**审查过程完整性**，非生产件缺陷：审查期仓库残留 index 篡改 + 暂存探针，归因不确定，主 agent 已清理 ⇒ 处置 = 派发契约加固 + `L-160` + `TD-070`，与生产件 finding 分开走）。

**🟢 Minor（12 条）**：R3-9…R3-13（隐私门禁：死条件 · 无用符号 · 文档漂移 · SC2317×4 · 自证行措辞）· R3-M6（主 agent 观察：自证块 6 站点重复）· R3-24…R3-29（审计 #2：`set -- $line` 未加引号 · `strip_front_matter` 作用域 · `runtime-edit-guard` 路径语义变化 · ADR 预算魔法数 · 孤儿白名单 · 登记册 TD-048/TD-059 两行漂移）⇒ 全部写 `MINOR-DEFERRED.md`，交阶段 7 triage（`R3-29` 建议本次收口顺手更新）。

**AC 判定（第 3 轮快照 · `7b624dc`）**：AC-1 ✅ · AC-2 ✅ · AC-3 ✅ · AC-4 ✅ · AC-5 ✅ · **AC-6 ❌**（R3-1/R3-2 直接违背 AC-6 的「机械故障 fail-closed + 消灭假绿」加严口径）· AC-7 ✅ · **AC-8 ⚠️**（R3-15/R3-16/R3-22 = NFR 门禁覆盖与可达性缺口）· **AC-9 ❌**（5 🔴 ⇒ 动态门禁不通过）。

**spot-check（ADR-014 第 3 轮 · 已完成）**：`verdict=fail` 且 ≥1 🔴 ⇒ **已触发**跨模型盲审（`qwen-token-plan-cn` / `qwen3.8-flash`，subagent `50a7e688-268c-4e84-8d59-aa5257cdcafb`），回执段 `## Cross-Model Spot-Check（第 3 轮 · 2026-09-25 · qwen3.8-flash）` 追加在 `INDEPENDENT-REVIEW-6.md:119-153`。**它的结论：Verdict fail —— H1/H2/H3 三条 🔴 独立复现成立并维持定级 · `TMP_FILES` 未加引号 🟡 成立**；并出三条新发现（已并入本轮 Finding 面）：**R3-30 🔴**（rev 模式同样假绿 ⇒ R3-1 双路径击穿，见上表）· **R3-31 🟡**（自证计数语义）· **R3-32 🟡**（审查期仓库完整性：`.git/config` 的 `core.quotePath=false` 覆盖 + index 篡改 + 暂存探针，主 agent 已全部清理并复核生产件零差异）。

**出口与修复任务分解（拟 · 待用户裁决后落 `TASK.md`）**

| 任务 | 覆盖 finding | 载体 |
|---|---|---|
| `T-FIX-07` | R3-1 + R3-2 + **R3-30**（三条 🔴：隐私门禁假绿三面）+ R3-3…R3-8 + **R3-31**（🟡） | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` + `test/test_path_privacy_gate.bats`（双源） |
| `T-FIX-08` | R3-14（🔴）+ R3-17（恢复提示）+ R3-23（每 ref 去重）+ R3-21（jq 前置文档/预检） | `hooks/pre-push/pre-push.sh` · `hooks/pre-commit/pre-commit.sh` · `lib/install_hooks.sh` · `install.sh` · `flow-kit-bundle/README.md` / `OPENCODE-INSTALL.md` |
| `T-FIX-09` | R3-15 + R3-16（🔴）+ R3-22 | `Makefile` + `test/test_nfr_portability_gate.bats`（双源） |
| `T-FIX-10` | R3-18 + R3-19 + R3-20 | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` + `test/test_check_gate_sync.bats`（双源） |
| （过程收口 · 无代码任务） | **R3-32**（派发契约加固：审计/执行 subagent 开工与收工各报 `git status --porcelain` + `git diff --cached --stat`，写入面只允许 `/tmp`）+ R3-29（登记册两行漂移顺手对齐） | 派发词模板 + `.specs/CONTEXT.md`（`TD-070`）+ `.specs/LESSONS.md`（`L-160`） |

> 用户裁决（`ask_user_question` id `rollback_6to4_round3`）= **选项 1**：回退 `4-dev`，修 6 🔴 + 15 🟡（`T-FIX-07`…`T-FIX-10` + 过程收口）→ 重跑 `5-test` → `6-review`（第 4 轮重审，复审面 = 上述 fix 后的新 HEAD）。

---

## 0′. 第 2 轮审查（fix 循环后重审 · HEAD `cb21c03`）

### 0′.1 复审面与运行标识

| 项 | 值 | 来源 |
|---|---|---|
| HEAD | `cb21c03` | `git log --oneline -1` |
| 变更集 | 95 files / **+24300 / −153** | `git diff 534e3e8..HEAD --shortstat` |
| 全量测试 | `1..1025` · **ok=1025 / not ok=0**（`npx bats --count test/` = 1025） | §D-8-2 · `/tmp/p6b/` 回执 |
| 门禁总闸 | `make check` **rc=0** · 21 ✅ / 0 ❌ | 同上 |
| 隐私门禁 | `make check-path-privacy` **rc=0** · 清单外命中 **0** | 同上 |
| fix 三件判据 | `T-FIX-03` / `T-FIX-04` / `T-FIX-05` 的 `<verify>` 各 **rc=0**（主 agent 独立抽取后原样复跑） | `TASK.md:1600±` |

### 0′.2 第 1 轮发现闭合表（逐条 + 证据）

| ID | 第 1 轮 | 症状 | 闭合提交 | 第 2 轮独立证据 | 判定 |
|---|---|---|---|---|---|
| **F1** `REVIEW.md:84` | 🔴 | 机械/工具故障（坏 `TMPDIR` 等）折算成「命中合计 0 条 ✅」rc=0 | `6e39cfb` | 同夹具态 B：rc=0 → **rc=1**，报文 `🔴 无法完成扫描：mktemp 失败（TMPDIR=…）` + 位置 `check-path-privacy.sh:mktemp_checked`；活性重放（生产件还原 `6e39cfb^`）⇒ `not ok 10`（F1 坏态） | ✅ 闭合 |
| **F2** `REVIEW.md:93` | 🔴 | 扫描面塌陷：非 git / index 空 ⇒ 0 候选与「全干净」同形 rc=0 | `6e39cfb` | 态 C：rc=0 → **rc=1**（`git ls-files 失败` + `:ls-files`）；态 E（index 空）：rc=0 → **rc=1**（`候选文件 0 个` + `🔴 候选面为空，无法判定（0 候选 ≠ 干净 · ADR-027 ②③ fail-closed）`）；活性重放 `not ok 12/13/14` | ✅ 闭合 |
| **F3** `REVIEW.md:102` | 🟡 | 二进制载体：工作树模式静默丢（rc=0）、rev 模式结论相反且行号不可解析 | `6e39cfb` | 态 F（泄漏仅在二进制内）：rc=0 → **rc=1**（`候选文件 2 个` · `命中合计 1 条`）；`-a` + 行号字段 `^[0-9]+$`（`check-path-privacy.sh:425-435`）；活性重放 `not ok 15`（`F3 坏态：tracked 二进制含探针 ⇒ 工作树模式必须非 0 且归因可解析`） | ✅ 闭合 |
| **F4** `REVIEW.md:110` | 🟡 | 「什么算注释」两套口径（校验器 vs 计数器） | `6e39cfb` | `IS_COMMENT_OR_BLANK_RE`（`:192`）单点定义，校验器 `:205` 与计数器 `:261` 共用；活性重放 `not ok 17`（`F4 坏态：清单仅含 HTML 注释 ⇒ 自证须报「允许清单 0 条」`） | ✅ 闭合 |
| **F5** `REVIEW.md:118` | 🟡 | 临时文件清单两份 + 第二个 EXIT trap 覆盖 `cleanup()` | `6e39cfb` | 唯一 `trap cleanup EXIT`（`:98`）+ `TMP_FILES`（`:120`/`:475`）；活性重放 `not ok 19`（`F5 静态：全脚本只剩一个 EXIT trap`） | ✅ 闭合 |
| **F6** `REVIEW.md:126` | 🟡 | `check-gate-sync` 缺一对文件仅 WARNING，仍打印 `✅ 校验对 3/14 一致` rc=0 | `521b21c` | `<verify>` rc=0：缺对夹具 ⇒ rc=1 · `missing_pair=1` · **无 ✅ 汇总行**（缺对 ⇒ `🔴 MISSING` + `ERRORS+1`；汇总分母 `${COMPARED}/${PAIRS_TOTAL}`）；活性重放 ⇒ 恰 `not ok 7` | ✅ 闭合 |
| **F7** `REVIEW.md:134` | 🟡 | `PAIRS_TOTAL` 之外散落字面「14」+ 补救文案与判据脱节 | `521b21c` | `PAIRS_TOTAL=14` 常量单点（`:44`）；改前 `:25/:32/:40/:204/:209` 的裸字面量已全部改为插值（现行全文仅 `:44` 一处常量，`grep -n '14'` 已核）；`:218` 文案改「请同步 prompt 和 skill 的全文内容（剥离平台 front-matter 后逐行比对一致）」 | ✅ 闭合 |
| **F8** `REVIEW.md:142` | 🟡 | NFR 判据正文写两遍（wrapper 89 行 ≡ internals 76 条语句） | `6e94d60` | wrapper 配方 89 → **13 行**薄壳（`Makefile:247` 起 · `awk` 范围法 Δ−76），判据正文唯一留 internals（`:162` 起 79 行）；本提交 numstat = `Makefile +9/−77` · 3 文件合计 **+35/−77（净 −42 行）**；三态 rc 映射等价（0/3/1）；活性重放 ⇒ 恰 `not ok 6`（`_report_viol() {` 出现 2 次） | ✅ 闭合 |
| **F9–F17** | 🟢 ×9 | Minor（命名/去重/文案等） | — | 全部登记在 `MINOR-DEFERRED.md`，**不入 fix loop**（`6-review.md:295`） | ✅ 已登记 |
| **S1/S2/S3** | spot-check 补充 | S2（bats 例数 10 → 9）第 1 轮已就地订正；S1（`mktemp` 行号 off-by-4）与 S3（`AC-9` 出处）已登记 | — | `MINOR-DEFERRED.md` | ✅ 已处理 |

> 三个 fix 提交的完整十项契约复核（numstat / blob 对 HEAD / 台账 Δ / 结构不变量 / 冻结集 / 判据独立复跑 / 双源镜像 / 活性重放 / 语义核对 / 残留面）见 `MINOR-DEFERRED.md` 的三段「复核记录」。

### 0′.3 同夹具对照：第 1 轮抓到的三个 fail-open 夹具在新 HEAD 重跑

夹具 = `mktemp -d` + `cp` 真实生产件（按脚本期望的相对布局：`flow-kit-bundle/flow-kit/reference/{check-path-privacy.sh,path-privacy-allowlist.txt}`）+ 拼接探针（`'/home/'` + `'zz-p6b-pro''be'` + `'/'`，L-137 形态）+ git 仓 + **已被 git add 的**泄漏文件（阳性对照必备，TD-065 教训）。脚本：`/tmp/p6b/four-state-privacy.sh`（只读，不触碰工作树）。

| 态 | 构造 | 第 1 轮（旧生产件） | 第 2 轮（HEAD `cb21c03`） | 判定 |
|---|---|---|---|---|
| **A** | 规范环境 + 真泄漏（已跟踪） | rc=1 | rc=1（`候选文件 2 个` · `命中合计 1 条`） | 阳性对照成立 |
| **B** | `TMPDIR=/nonexistent-dir-probe` | **rc=0 假绿 🔴** | **rc=1** + `🔴 无法完成扫描：mktemp 失败` + `位置: check-path-privacy.sh:mktemp_checked` | F1 闭合 |
| **C** | 非 git 目录 | **rc=0 假绿 🔴** | **rc=1** + `🔴 git ls-files 失败（非 git 目录或 git 不可用）` + `位置: :ls-files` | F2 闭合（第一型） |
| **E** | git 仓 + index 空 | rc=0（spot-check 变体） | **rc=1** + `候选文件 0 个` + `🔴 候选面为空，无法判定（0 候选 ≠ 干净 · ADR-027 ②③ fail-closed）` | F2 闭合（第二型） |
| **F** | 泄漏仅在二进制载体（已跟踪） | **rc=0 静默丢 🔴** | **rc=1**（`候选文件 2 个` · `命中合计 1 条`） | F3 闭合 |
| **D** | 控制（同 A 布局、无泄漏） | rc=0 | rc=0（`候选文件 1 个` · `命中合计 0 条`） | 无假红 |

**新增发现（第 2 轮）**

### 🟡 F-18 · R6 Domain Model Distortion：候选面标签写「工作树」，实际面 = git index

**Severity**: 🟡 Important
**定位**（行号 @ 被审 revision `cb21c03`；该文件在 T-FIX-06 落地后行号会前移）：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:130`（`SCAN_SURFACE='工作树'`）· `:279`（候选 = `git ls-files --`）· `:518`（汇总行打印 `${SCAN_SURFACE}`）
**四要素**：
- 症状：门禁第 1 行与汇总行都打印「扫描面: 工作树」，但候选枚举是 `git ls-files`（= **git index**）。**未 `git add` 的工作树文件不在面内**：同一目录里放一个被跟踪的泄漏文件 → rc=1；把它 `git rm --cached` 变回 untracked（文件仍在磁盘上）→ **rc=0 + `候选文件 1 个` + `命中合计 0 条`**，读者会把「工作树」读成「整棵树已验干净」。
- 证据（态 G / G2，`/tmp/p6b/index-face.txt`）：`git add staged.txt` ⇒ rc=1（候选 2 · 命中 1）；`git rm --cached staged.txt` ⇒ **rc=0**（候选 1 · 命中 0）；对应 `git ls-files` 输出 `clean.txt staged.txt` vs `clean.txt`。
- 反例边界：脚本内注释 `:277` 是**准确**的（「候选 = tracked 文件」）⇒ 缺陷在**对外措辞**与「未跟踪面是否应纳入」的策略选择，不在实现的自洽性。风险面因此是「窄」的：未入库文件不进入分发面；提交时 PreToolUse/pre-commit 链路会在文件已 staged 后拦住它（态 G 已证）。
- 建议动作（二选一，用户裁决）：
  ① **补面**：`:279` 改 `git ls-files --cached --others --exclude-standard --`（未跟踪但未被 ignore 的文件一并入面）⇒ 标签与行为同时为真，并补 2 条双态用例（untracked 泄漏 ⇒ rc=1；被 ignore 的文件含泄漏 ⇒ rc=0）。
  ② **改措辞**：`SCAN_SURFACE='工作树（git index：已 add / 已提交）'`，并把边界写进 `:19-25` 的契约注释与 `docs`（零行为变更）。
- **用户裁决（2026-09-25 · question `f18_surface_label`）= ② 只改措辞（零行为变更）** ⇒ **并入 `T-FIX-06`**（与 F-19/F-20 同批；该任务已使 `.flow-active` 回退 4-dev，`.goal.rollback_2`）：常量改为 `SCAN_SURFACE='工作树（git index：已 add / 已提交）'`（5 处打印共用变量 ⇒ 单点变更）· 相邻「扫本地工作树」类注释同步对齐 · 新增钉住断言（先红后绿）；**不得**给 `git ls-files` 加 `--others`/`--exclude-standard`（用户未选 ①，扫描面保持不变）。

### 0′.4 只读深审回执（fix 循环 3 提交）

第 2 轮另派**只读**子 agent 对 `6e39cfb` / `521b21c` / `6e94d60` 三个 diff 做独立缺陷审查（bash 3.2 兼容 · fail-closed 穷举 · 新用例判别力 · 是否引入新缺陷）。其发现与主 agent 独立复现结果：

**深审结论**：verdict = **pass**（无 🔴 · 旧缺陷逐条闭合 · 未引入 fail-open 回归 · 新用例均具判别力（回退父版必红）· bash 3.2 仅静态核（`bash -n` + 违禁构造 `grep`：无 `declare -A`/`mapfile`/`readarray`/`sed -i`/`${var^^}`/`&>>`/`[[ -v ]]`/`local -n`）· 未在真机 macOS 实跑 = TD-055 同族）。子 agent 在写盘实验阶段被 phase-6 门禁拦下（要求先有 `.independent-review-6.done`），故其结论全部取自 `/tmp` 只读副本实验 —— 与「只读深审」定位一致。

**旧缺陷闭合（深审实测：父版 vs 新版）**
- **F1 ✅**：`mktemp_checked()` `:106-116` · `git rev-parse` `:135-139` · `cp` `:153`/`:161` · `git ls-tree`/`git ls-files` `:271-283` · `git grep` `:385-395` · `grep -naE` `:425-435` 全部 rc 断言（全文 12 个「失败吞噬点」逐个核）；坏 `TMPDIR` ⇒ 父版 rc=0 + `✅` / 新版 rc=1 + 多条 🔴。
- **F2 ✅**：两型 0 候选（非 git 目录 / 空 index）父版 rc=0 + `✅` / 新版 rc=1 + `🔴 候选面为空，无法判定`。
- **F6/F7 ✅**：缺 prompt/skill ⇒ 父版 rc=0 + `✅ 校验对 3/14 一致` / 新版 rc=1 + `🔴 MISSING` + `ERRORS+1` 且不再打印 ✅ 汇总；`COMPARED` 只在两文件俱在时递增（`:80`），汇总行 `:216`/`:221` 用 `COMPARED` 而非对数总数；无 tautology（用例不断言 `COMPARED` 的值）。
- **F8 ✅ 语义等价**：wrapper 13 行薄壳；判据正文唯一在 internals（`bash -euo pipefail -c`）；三态 rc 映射实测（fixture rc=3 ⇒ `SKIP:` + exit 0；违规 rc=1 ⇒ exit 1 + stderr `seed.sh:3:` 归因）；`make -n` 下 internals 仍打印完整正文；`MAKELEVEL=5` 无无限递归；`FLOW_KIT_CHANGE_BASE` 命令行/环境下传、`NFR_RC_FILE` 由 wrapper export 下传。

**深审新发现（3 条 · 主 agent 已逐条独立复核机制）**

- **F-19 · 🟡 · `check-path-privacy.sh:293`（`CANDIDATE_COUNT`）vs `:461-462`（`is_self_exclude && continue`）vs `:521`（自证行）** —— 自证行报的是**自排除前**的候选数：若 tracked 文件**全部**落在 `SELF_EXCLUDE`（`:67-74` 的 6 条 flow-kit 自身工件）内，则 `scan_file` 实际调用 **0 次**，脚本仍打印 `候选文件 N 个` + `清单外命中 0 条` + `✅` + rc=0 ⇒「0 实际扫描」与「N 个干净文件」同形（与 F2 同族：0 面 ≠ 干净 · ADR-027 ②③）。**主 agent 复核**：机制成立（`:293` 在 `:279` 枚举之后、`:461` 过滤之前计数；`:521` 打印该值）。触发面窄（需全部 tracked 文件恰为这 6 件）但可构造。**建议动作**：扫描循环内递增 `SCANNED_COUNT`，自证行报 `实际扫描 N 个`，并在 `SCANNED_COUNT=0 && CANDIDATE_COUNT>0` 时 fail-closed + 2 条双态用例。
- **F-20 · 🟡 · `check-path-privacy.sh:106-119`（`mktemp_checked()` 与其 3 个调用点）** —— 函数内 `exit 1`（`:113`）位于 `TMP_X=$(mktemp_checked)`（`:117-119`）的命令替换中 ⇒ **只退子 shell**，脚本继续（深审以 `/tmp` 最小脚本实证：`exit 1` 后仍打印后续行、rc=0）；三个变量退化为空串，最终由 `cp` 失败路径（`:153`）或 allowlist-missing 路径（`:173`）兜住 ⇒ **终态仍 rc=1 fail-closed**，但设计意图「mktemp 失败 ⇒ 立即终止」未生效，且产生 3 条冗余 `🔴 mktemp 失败` 报文。**建议动作**：调用点改 `if ! TMP_X=$(mktemp_checked); then exit 1; fi`（或函数改「回填全局变量 + 显式 rc」）。
- **F-21 · 🟢 · `Makefile:255`（`check-nfr-portability` wrapper）** —— `bash -c 'make … check-nfr-portability-internals'` 不参与 GNU make jobserver（无 `+` 前缀/`$(MAKE)`），`make -j2` 时子 make 回退 `-j1` 并打警告 `jobserver 不可用`。功能正确（internals 仍跑、rc 映射不变），且本 target 为顺序配方无并行收益。**主 agent 裁决**：`Not-applicable`（改 `+$$(MAKE)` 会让 `make -n` 下子 make 继承 `-n`、判据体不执行 ⇒ `NFR_RC_FILE` 未写 ⇒ 映射为 2 ⇒ `<verify>` 的 `make -n` 断言判红，正是 T-FIX-05 已上报并由主 agent 裁决接受的张力点，见 `TASK.md:1826`）⇒ 保留现状，警告噪声记入 `MINOR-DEFERRED.md`。

**深审自陈存疑项（未穷举 · 已如实登记）**：① `make -j2` 下违规（rc=1）路径未实测（预期同，无并行点）；② F-19 的叠加触发面（submodule / `git worktree` / `.gitignore` 全排除后 `ls-files` 非空但全被自排除）未穷举 —— 走同一条 `CANDIDATE_COUNT>0` 而 `SCANNED=0` 的路径；③ gate-sync「两侧文件俱在但内容为空」判为非 F6/F7 回归（空内容视作一致 = 既有语义），front-matter 剥离后为空的边界未穷举；④ bash 3.2 未实机（TD-055）；⑤ 全量 bats 未跑（主 agent 已补：`--count` 1025 · ok=1025 / not ok=0，见 §0′.1）。

### 0′.5 阶段完成自检（`6-review.md:152-166` 九项）

| # | 检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `REVIEW.md` 已写入 `.specs/health-fix-2026-09b/` | `test -f` | ✅ |
| 2 | Spec 合规审查已完成（AC-1..AC-9 逐条） | §A · §0′.6 | ✅ |
| 3 | 代码质量审查已完成（6 维衰退风险） | §B（17 + 1 条 finding） | ✅ |
| 4 | UI 视觉审查（前端项目）/ 已声明跳过 | §C = N/A（纯 Bash/Markdown 分发件） | ✅ N/A |
| 5 | 动态门禁判定（AC-9）已通过（无 🔴，或已记录接受风险） | §0′.6 = ✅（0 🔴） | ✅ |
| 6 | Gate 失败项（如有）已记录在 `REVIEW.md` | 第 1 轮 §0.3 + 第 2 轮 §0′.3 | ✅ |
| 7 | 技术债已同步 `CONTEXT.md` | `grep -c '^| TD-0' .specs/CONTEXT.md` = 57（TD-060..TD-065 已登记） | ✅ |
| 8 | `TEST.md` 5 轮金字塔完整性（2.0 段） | `TEST.md:14` §0 + `:20-24` 五行（功能 ✅必跑 / 性能 ⚠️部分 / 安全 ⚠️受限 / 兼容 静态+⚠️实机 / 可观测 ⚠️部分，各带未覆盖面归因） | ✅ |
| 9 | `.flow-active` 关键字段落盘 | `jq -e '.updated_at' .flow-active` rc=0 | ✅ |

### 0′.6 第 2 轮结论

- **AC 判定**：AC-1..AC-7 ✅ · AC-8 ⚠️（跨 OS 实机与安全工具面缺口 = `TD-055`/`TD-056`，维持第 1 轮口径，未夸大）· AC-9 ✅
- **verdict = pass**：0 条 🔴（第 1 轮 2 条已闭合且活性重放）· 第 2 轮新增 3 条 🟡（F-18/F-19/F-20，均非阻塞、均由用户裁决在本 change 内修）· 9 条 🟢 维持 deferred
- **出口（已发生）**：用户裁决 ① **F-19 + F-20 本 change 内修**（question `deep_review_findings_6b`）② **F-18 只改措辞**（question `f18_surface_label`）⇒ `.flow-active` 回退 **6 → 4-dev**（`.goal.rollback_2` · `2026-09-25T01:44:19+08:00` · `gates_reset=["4→5","5→6"]`），追加 **`T-FIX-06`**（`TASK.md` · `status="pending"` · `depends_on T-FIX-05`），执行者 subagent `f99aca2b`；修后须**重跑 5-test 与 6-review**（本 §0′ 结论为 `cb21c03` 快照，重审后另出）。

---

## 0. 第 1 轮审查（历史 · `verdict=fail`）—— 审查方法、门禁回执与独立复现

### 0.1 审查面
- `bash flow-kit-bundle/flow-kit/scripts/review-package 534e3e842fc900045f39492badc66eabe3ffd4c4 HEAD > /tmp/review-pkg.md`（rc=0 · 19092 行 · 85 个 `diff --git`；分段 `## Commits` `:1` / `## Files changed` `:75` / `## Diff` `:164`）——已 Read。
- 产品面 37 件逐件读 diff；其中 4 件安全/门禁件（`check-path-privacy.sh` · `check-gate-sync.sh` · `install_hooks.sh` · `Makefile`）另派**只读**子 agent 做 6 维深审，其结论逐条由主 agent **独立复现**后才纳入本节。

### 0.2 冻结树门禁回执（reviewed revision = `7dd4bd7`）
| 门禁 | 结果 |
|---|---|
| `npx bats --count test/` | **1012** |
| `npx bats test/` | rc=0 · TAP `1..1012` · ok=1012 · not ok=**0** · skip=0 |
| `make check` | rc=0 · **21 ✅ / 0 ❌**（尾框 `✅ make check: 全部通过`） |
| `make check-gate-sync` | rc=0 · 「✅ 预设名集合一致 (17 个预设)」+「✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）」 |
| AC-1 `eval` 面 | `flow-kit-bundle/**/*.sh`（排除 test）`\beval\b` 命中 **1** 处，且该处是**注释**（`runtime-edit-guard.sh:50`「纯参数展开 … 消除 eval 求值注入」）⇒ 求值载荷面 = 0 |

### 0.3 独立复现（fail-open 两态 · 主 agent 亲跑）
夹具 = `mktemp -d` + 复制**真实**生产件 `check-path-privacy.sh` + 常设清单 + 一个含探针文件的 git 仓；探针由拼接构造（`'/home/''zz-p6-pro''be/'`），本文件不复写其字面形态（L-129）。

| 态 | 环境 | 期望 | 实测 |
|---|---|---|---|
| **A** 规范 | git 仓 + 可写 TMPDIR | rc=1 且归因 | **rc=1** · `leak.txt:1: leak line: /home/<acct>/secret/` ✅ 门禁在规范环境**确实工作** |
| **B** mktemp 失败 | `TMPDIR=/nonexistent-dir-probe` | 要么 rc=1，要么显式报「无法扫描」 | **rc=0** + 「命中合计 0 条 / 清单外命中 0 条 ✅」，而该仓**确实存在真泄漏**（stderr 有 4 条 `mktemp` 失败与 4 条重定向失败，**callers 不读 stderr**） ⇒ 🔴 **假绿** |
| **C** 0 候选 | 非 git 目录（脚本 + 清单 + 泄漏文件齐备） | rc=1 或显式「候选 0 个」 | **rc=0** + 「清单外命中 0 条 ✅」 ⇒ 🔴 **假绿** |
| **D** 控制 | 规范环境 + 移除探针 | rc=0 | **rc=0** ✅（判别式成立：A↔D 只差探针、A↔B/C 只差环境） |

二进制双态（`git init` + tracked 二进制内含探针）：
- 工作树模式 ⇒ **rc=0** + 「命中合计 0 条 ✅」（`grep` 的「匹配到二进制文件」走 stderr 被 `2>/dev/null` 吞掉）⇒ 静默丢弃。
- rev 模式（`CHECK_REV=<sha>`）⇒ **rc=1**，但归因行不可解析：`Binary file <sha>:bin.dat matches: bin.dat matches`（`file` 字段 = `Binary file <sha>`、`line` 字段 = `bin.dat matches`）⇒ 白名单**永远豁免不了**，且两模式对同一文件结论相反。

---

### 0.4 跨模型 spot-check（ADR-014 · 盲审第 2 轮）

触发条件满足（`verdict=fail` 且 ≥1 🔴）⇒ 派独立 subagent `2238685b-cfb7-4c95-be4b-0a539a43146d` 做盲审第 2 轮：模型 **`qwen3.8-flash`**（与 L2 盲审所用 `glm-5.2` **不同模型族**），prompt 仅含固化指令 `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md` + `## 本次审查参数`（**无主 agent 自评注入**；该 subagent 声明"未接收主 agent 会话上下文"），报告写入 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md` 的 `## Cross-Model Spot-Check` 段（写入后实跑 `check-path-privacy.sh` rc=0 验证脱敏合规）。

| 项 | 结果 |
|---|---|
| 第 2 轮 verdict | **fail**（与本轮一致） |
| F1（fail-open） | **成立** —— 自建夹具独立复现：正常态 rc=1；`TMPDIR` 坏 ⇒ **rc=0** + 「命中合计 0 条 ✅」 |
| F2（0 候选与干净同形） | **成立** —— 非 git 目录 ⇒ rc=0 ✅ 且 **stderr 全空** |
| 是否推翻定级 / 新增 🔴 | 否 / 未发现第三条独立 🔴 |
| 增量（已并入 `TASK.md` T-FIX-03） | ① F1 行号勘误：`mktemp` 实测 `:75-77`（原引 `:79-81`，off-by-4）② `:105-111` 两处 `cp --` 不校验 rc ＝ 坏 `TMPDIR` 链路第一环 ③ F2 新变体：**git 仓但 index 为空** + 工作树真泄漏 ⇒ rc=0（`git ls-files` rc=0 只是 0 行 ⇒ 只有候选数断言能抓）⇒ 判据已加 E2 组 |
| 其新增 🟢（不阻塞） | S1 `SELF_EXCLUDE` 精确路径豁免在归档/复制场景双向失真 · S2 本文件原 `:54` 的「10 例」应为 **9 例**（已订正）· S3 「AC-9」术语出自 `flow-kit-bundle/flow-kit/prompts/6-review.md:29`，本 change `REQUIREMENT.md` 无该编号（表述已注明出处） |

> 第 2 轮的 2 条 🔴 与主 review 的 2 条 🔴 **完全重合 ⇒ 无跨模型分歧**，AC-9 判定与回退目标（4-dev）不因第 2 轮改变；处置入口 = `TASK.md:1596` 起的 T-FIX-03。

---

## A. Spec 合规（AC-1 ~ AC-8）

| AC | 实现位置 | 测试覆盖 | 判定 | 证据锚点 |
|---|---|---|---|---|
| **AC-1** 安全守卫不再求值载荷（PC1） | `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（`case` + 纯参数展开取代 `eval echo`；`[[ "$real_path" == /* ]]` 绝对路径校验；`:123 main "$@"`） | `test/test_runtime_edit_guard.bats`（9 例 · F2 常设网，运行时复制真实生产件）+ T05 判据 | ✅ | 全仓 `eval` 命中 1 处且为注释（§0.2）；F2 含「相对路径 / `~user` / 空串 ⇒ rc=2」与「非写工具 ⇒ rc=0」双态 |
| **AC-2** 缺 jq 时既有配置不被破坏（PC2） | `flow-kit-bundle/lib/install_hooks.sh:172-179`（**任何写盘之前**硬校验 `command -v jq`，fail-closed + 明确报文）· `:324-329`（合并分支二次校验，原文件未改动）· 同目录 `mktemp` + `mv` 原子写（`:44-62`） | `test/done-validation.bats` / `test_install_coverage.bats` 等 + T06 判据 | ✅ | `:40` 注释记录原缺陷（缺 jq 时既有文件 122B → 0B） |
| **AC-3** 泄漏分支无法被误推（P1 · v1 范围） | `hooks/pre-push/pre-push.sh`（新 59 行：逐行读 stdin ref、缺 local sha ⇒ fail-closed、全 0 sha 跳过、`CHECK_REV="$local_sha" make check-path-privacy` 逐 ref、报文指名 ref、全净才 `make check`）· `install_hooks.sh:95-149 deploy_pre_push`（备份既有 hook + symlink）· `sync-hooks.sh` / `package-flow-kit.sh` / `lib/validate_staging.sh:54` 三处接线 | `test/test_archive_commit_gate.bats`（pre-push glob 两断言 + 真跑 `validate_staging_coverage` 断言 `🔴 漏配: 0` / `⚠️ 源缺失: 0`）+ T19 判据（四种 push 形态端到端） | ✅ | T19 判据原文抽取实跑 rc=0（36 行）；`install.sh` 全文无 `trap`、未 source `validate_staging.sh`（AC-3 接线无隐藏耦合） |
| **AC-4** 门禁能看见内容漂移而非只数行数（AR2） | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（剥 front-matter 后逐行内容比对 + gate-config 17 预设集合一致性）· `Makefile check-gate-sync` 薄壳 | `test/test_check_gate_sync.bats`（断言由 `-ne 2` **收紧为 `-eq 0`**）+ T08/T15 判据 | ✅ | §0.2 回执：17 预设 + 3/14 校验对；`test_check_gate_sync.bats` 同步改正注释里失真的「9 预设」 |
| **AC-5** 内部项目名不再随分发件出厂（P3） | T07/T13：`chisel-*` → `sample-proj-*` 等中性占位；审查档/工件脱敏 | 三面计数 0：`test/` + `flow-kit-bundle/test/` `grep -rq -i chisel` 无命中；重建归档逐个（禁通配）`tar xzOf dist/dsh-flow-kit-0.2.0.tgz \| grep -ac` = 0 | ✅（边界见 F17 + **§0″.4.C**） | 第 1 轮记「0 个文件」**口径修正**（第 3 轮实测）：`git grep -l '/home/<acct>/' HEAD` = **2 个文件**，即 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md` / `INDEPENDENT-REVIEW-2.md`，二者受 `check-path-privacy.sh:85-93` 的 `SELF_EXCLUDE`（6 条精确路径）显式豁免，且 `TD-063`（`.specs/**` 内部项目名，31 个 tracked 文件）已登记该边界；分发件面（`dist/` 归档 + 三面计数）仍 **0 命中** |
| **AC-6** 前向脱敏有机器门禁（P6） | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（第 1 轮 392 行 → 第 3 轮 **594 行**）· 常设清单 `path-privacy-allowlist.txt`（T21 冻结，16 行 / 0 有效条目）· `Makefile check-path-privacy` · `pre-commit` 在 `make test` 之后接线 · `pre-push` 按 ref 评估 | `test/test_path_privacy_gate.bats`（第 1 轮 9 例 → 第 3 轮 **20 例**：F1/F2/F3/F4/F5 + F19/F20 双态组） | **❌**（第 1 轮 F1/F2 已闭合，第 3 轮新增 🔴 R3-1/R3-2 ⇒ 见 §0″.4.A / §0″.6） | 第 1 轮两条 🔴 与 F-18/F-19/F-20 已分别由 T-FIX-03 / T-FIX-06 闭合（§0″.2）；本轮新发现：`core.quotePath` 引号化路径静默跳过（真扫描 1585 ≠ 自证 1589）· index/工作树内容源错位（staged 泄漏可穿透 pre-commit） |
| **AC-7** 四处假绿测试不再假绿（TC3/TC4/TC5） | T09 `test_combined_metric.bats`（扫描根收敛到 `$TEST_TMPDIR/scan`，脱离宿主 `/tmp` 的 149 个无关 `tmp.*`）· T10 `test_independent_review_model.bats`（+文件存在性前置断言）与 `test_lessons_cleanup.bats`（过期 `skip` → 真跑 `validate_staging_coverage`）· T15 `test_check_gate_sync.bats`（`-ne 2` → `-eq 0`）· T20 `test_auto_checkpoint.bats`（`hook_rc=$?` 立即捕获，原断言对象误为 jq） | 逐条核对 diff：**全部为收紧**，无一处放宽或删断言 | ✅ | `TASK.md:24` 明写四处归属 T09/T10/T15/T20；TEST.md 记有「注入失败 ⇒ 转红」的判别式回执 |
| **AC-8** 无退化（含 rc=3 SKIP≠PASS 与 `.change-base` 锚点守卫） | `Makefile check-nfr-portability-internals`（三态 rc∈{0,1,3}，经 `$NFR_RC_FILE` 回传；空变更集 ⇒ rc=3 + `SKIP:`）与包装层（rc∈{0,1}，3 ⇒ 0 且保留 `SKIP:`）· T29 收口（`make check` 九门禁 + bats 地板）· `.change-base` 锚点 | `test/test_nfr_portability_gate.bats`（7 例 · F3 常设网）+ T29 判据（15 行） | ⚠️ **有条件通过（仅静态面）**：change 期静态判据 rc=0；**跨 OS 实机面 = 未验证（TD-055）**，不得读作 AC-8 通过 | §0.2 回执全绿；`make check` 21✅/0❌ |

**AC-9 动态门禁判定**：见 §E —— **❌**（有 🔴 Critical）。第 1 轮 2 条 🔴 已闭合（§0″.2），**第 3 轮新增 2 条 🔴（R3-1/R3-2）** ⇒ 第 3 轮快照（被审 revision `7b624dc`）判定仍为 **❌**。

> **第 3 轮快照（`7b624dc`）AC 面复核**：AC-1 ✅ · AC-2 ✅ · AC-3 ✅ · AC-4 ✅ · AC-5 ✅（口径修正见 §0″.4.C）· **AC-6 ❌**（R3-1/R3-2）· AC-7 ✅ · AC-8 ⚠️（跨 OS 实机面未验证 = TD-055，不得读作通过）· AC-9 ❌。
> 行级证据在 `7b624dc` 维持：第 3 轮复跑 = REPRO7（起点 `26d5d7b`，生产件与 `7b624dc` 逐字节同）**18/18 判据 rc=0**（含 AC-1 T05 · AC-2 T06 · AC-3 T19 · AC-4 T08/T15 · AC-7 T09/T10/T20 判据）+ **7/7 门禁 rc=0**（bats 1029 ok / `make check` 21✅ 0❌ / 隐私清单外 0 / NFR ×5 均值 3.077 s = 61.5%）。
> 第 3 轮同夹具对照见 §0″.3；新发现的分级、机制与我方亲验见 §0″.4。

---

## B. 代码质量审查（6 维衰退风险）

> 每条四要素：`**Severity**` + `**Symptom**`（`file:line`）+ `**Source**`（书·章节）+ `**Consequence**` + `**Remedy**`。
> 行号为**修复前快照**（reviewed revision `7dd4bd7`）；跨模型 spot-check 的行号勘误已就地订正（见 §0.4）。

### 🔴 F1 · R6 Domain Model Distortion（fail-open）：机械/工具故障一律折算成「0 命中」

**Severity**: 🔴 Critical
**Symptom**: `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:75-77`（4× `TMP_X=$(mktemp)` 不校验 rc；**跨模型 spot-check 勘误：原引 `:79-81`，off-by-4**）+ `:105-111`（2× `cp -- … "$TMP_ALLOWLIST"` 不校验 rc ＝ 坏 `TMPDIR` 链路的**第一环**，先于 `mktemp` 报错被吞）+ `:203-209`（`git ls-tree` / `git ls-files` 的 rc 不校验、stderr 丢弃）+ `:285` · `:309`（检索 `|| true` + `2>/dev/null`）+ `:336` · `:198`（`|| 0` 把「读失败」与「0 条」合并）
**Source**: 《The Pragmatic Programmer》「Crash Early」；《Domain-Driven Design》Ubiquitous Language（「通过」一词的语义被实现掏空）
**Consequence**: **已复现**（§0.3 态 B）：`TMPDIR` 指向不存在目录 ⇒ 4 次 `mktemp` 失败、其后重定向全失败，**仓内存在真泄漏仍打印「清单外命中 0 条 ✅」且 rc=0**。`Makefile:121-127`、`pre-commit`、`pre-push` 只读 rc ⇒ 三处门禁同时被静默旁路；唯一线索是 stderr（无人读）。此缺陷与本 change 的立项目标（消灭"看不见的假绿"，AC-7）同族。
**Remedy**: 每个 `mktemp` / `cp ` / 候选枚举 / 检索均断言 rc，失败 ⇒ `🔴 … 无法完成扫描` + `exit 1`（与「无命中」分出口码）；`test/test_path_privacy_gate.bats` 增加「mktemp 失败 ⇒ 非 0」双态用例（哑环境 + 真探针）。
**跨模型复核**：`qwen3.8-flash` 在自建夹具独立复现（正常态 rc=1 · `TMPDIR` 坏 ⇒ rc=0 + 「命中合计 0 条 ✅」，stderr 4 条 `mktemp` 失败，逐字节稳定）⇒ **F1 成立**（§0.4）。

### 🔴 F2 · R6 Domain Model Distortion：扫描面塌陷（0 候选）与「全部干净」在本门禁里同形

**Severity**: 🔴 Critical
**Symptom**: `check-path-privacy.sh:203-209`（候选枚举产物**从未被断言非空**）+ `:369-374`（自证四行只有「扫描面 / 允许清单来源 / 允许清单 N 条 / 命中合计 N 条 / 清单外命中 N 条」，**没有候选文件数**）+ `:380-392`（0 命中 ⇒ ✅ / rc=0）
**Source**: 《A Philosophy of Software Design》第 4 章 Shallow Module（接口不暴露"看了多少"，调用者无法判断结论的适用范围）
**Consequence**: **已复现**（§0.3 态 C）：非 git 目录（脚本 + 清单 + 真泄漏文件齐备）⇒ rc=0 + 「命中合计 0 条 ✅」。即"零扫描面"与"零命中"不可区分；任何让 `git ls-files`/`git ls-tree` 失败的环境（解包分发件目录、损坏的 index、空 rev）都会把隐私门禁降级成恒绿装饰。
**Remedy**: 自证行增「候选文件 N 个」并与 `git ls-files | wc -l` 对照；`N=0` ⇒ fail-closed（rc≠0 + `🔴 候选面为空，无法判定`）；`test/test_path_privacy_gate.bats` 增「非 git / 0 候选 ⇒ 非 0」双态用例，**且须覆盖两型 0 候选面**。
**跨模型复核与增量**：第 2 轮独立复现非 git 目录 ⇒ rc=0 + 「命中合计 0 条 ✅」且 **stderr 全空**（连线索都没有）⇒ **F2 成立**；并给出**同根新变体**：git 仓但 index 为空（`git init` 后未 `add`）+ 工作树真泄漏 ⇒ 同样 rc=0 —— 此型 `git ls-files` rc=0 只是输出 0 行，**F1 的 rc 断言抓不到，只有候选数断言能抓**（已并入 T-FIX-03 判据 E2）。

### 🟡 F3 · R2 Change Propagation（信息泄漏）：命中记录协议双端持知 + 二进制两模式结论相反

**Severity**: 🟡 Important
**Symptom**: 写端 `check-path-privacy.sh:302` · `:319`（`printf '%s:%s:%s\n'`）与读端 `:354`（`while IFS=: read -r f l c`，不校验 `$l` 为数字）；rev 分支 `:285-299`（直吃 `git grep` 的 stdout 告警行）、工作树分支 `:309-310`（`grep` 的「匹配到二进制文件」告警走 stderr 被吞）
**Source**: 《A Philosophy of Software Design》第 5 章 Information Leakage（同一格式知识散落在写入端与读取端）
**Consequence**: **已复现**（§0.3 二进制双态）：工作树模式**静默丢弃**二进制命中（假绿）；rev 模式把 `Binary file <sha>:bin.dat matches` 当命中解析 ⇒ **rc=1 假红**且 `file:line` 不可归因、白名单永远豁免不了。同一仓在两种模式下结论相反。当前分发面无二进制含 PAT（无现存泄漏），故按「扫描面宣称 ≠ 实际」定级 🟡。
**Remedy**: 两模式统一显式二进制策略（如 `grep -a` 做匹配 + 显式「二进制命中」标记，或统一 `-I` 并在自证行打印「跳过二进制 N 个」）；解析前断言 `$l` 匹配 `^[0-9]+$`，否则按"不可归因命中"单列并 fail-closed；记录改用内容中不可能出现的分隔（`\t` 或 `--null`）。

### 🟡 F4 · R3 Knowledge Duplication：允许清单「什么算注释」有两套口径

**Severity**: 🟡 Important
**Symptom**: `check-path-privacy.sh:146-147`（校验器把 `#` 与 `<!--` 都当注释跳过）vs `:198` · `:341`（`grep -vE '^[[:space:]]*(#|$)'` 只认 `#`）
**Source**: 《重构》3.2 Duplicate Code（Shotgun Surgery）；《The Pragmatic Programmer》DRY
**Consequence**: 同一决定在两处表达 ⇒ 改一处即口径漂移。`<!-- … -->` 行会被计为**有效条目**，使自证行「允许清单 N 条」虚高 —— 而 AC-6 判据正用该计数（`允许清单 [1-9][0-9]* 条`）作为证据。今天清单内无 `<!--` 行（16 行全 `#`）⇒ 潜在缺陷。
**Remedy**: 抽 `is_comment_line()` 或统一为同一 ERE，供 `:146` / `:198` / `:341` 共用；并在清单首部注释与判据文案里保持同一表述。

### 🟡 F5 · R3 Knowledge Duplication：临时文件清单写了两份，第二个 EXIT trap 覆盖 cleanup()

**Severity**: 🟡 Important
**Symptom**: `check-path-privacy.sh:65-73`（`cleanup()` 列 3 个文件）+ `:77`（`trap cleanup EXIT`）vs `:339-340`（`TMP_ALLOWLIST_KEYS=$(mktemp)` + `trap 'rm -f …4 个文件名…' EXIT`）
**Source**: 《重构》3.2 Duplicate Code（霰弹式修改）
**Consequence**: 自 `:340` 起 `cleanup()` 成为**死代码**（第二个 `trap … EXIT` 覆盖第一个）。将来新增临时文件只登记其一 ⇒ 早期退出路径残留（或反之漏删）；「临时文件清单」这一知识没有单一事实源。
**Remedy**: 单一 `TMP_FILES` 变量 + 唯一 EXIT trap（`trap 'rm -f $TMP_FILES' EXIT`，或 `cleanup()` 内 `rm -f "${TMP_FILES[@]}"`）。

### 🟡 F6 · R6 Domain Model Distortion：`check-gate-sync` 校验对文件缺失只降级为 WARNING，仍 ✅ / rc=0

**Severity**: 🟡 Important
**Symptom**: `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:59-68`（缺 prompt/skill ⇒ `⚠️ WARNING … 跳过` + 裸 `return`，`ERRORS` 不增）+ `:204` · `:209`（覆盖度分母用静态 `${#PAIRS[@]}`，与实际比对对数无关）
**Source**: 《Domain-Driven Design》Ubiquitous Language（「3/14 一致」与实际比对集不符）；《The Pragmatic Programmer》Crash Early
**Consequence**: **已复现**（子 agent 沙箱：只放 2/3 个 prompt 文件）⇒ 该对打印 WARNING 后，汇总仍写「覆盖度: 校验对 3/14」+「✅ 校验对 3/14 一致」并 **rc=0**。prompt/skill 改名是常规重构动作 ⇒ 门禁静默少比一对而报全绿（与 F1/F2 同族：把"未能检查"说成"检查通过"）。
**Remedy**: 缺文件 ⇒ `ERRORS=$((ERRORS+1))`（或独立 rc=2「未验证」，调用方按非 0 处理）；覆盖度分母改用**实际比对对数**；`test/test_check_gate_sync.bats` 增「缺一对 ⇒ 非 0」双态用例。

### 🟡 F7 · R3 Knowledge Duplication：`PAIRS_TOTAL` 之外仍散落字面「14」，且补救文案与 v1 判据脱节

**Severity**: 🟡 Important
**Symptom**: `check-gate-sync.sh:25-26` · `:32`（注释）、`:40 PAIRS_TOTAL=14`、`:204`（`$((PAIRS_TOTAL - ${#PAIRS[@]}))` 已用变量 ✅）、`:209`（**字面**「非全量 14 对全绿」）、`:206`（「请同步 prompt 和 skill 的 toll-gate 协议段」——v1 已是**全文**内容比对）
**Source**: 《重构》3.2 Duplicate Code；《The Pragmatic Programmer》DRY
**Consequence**: 加第 4 对或改 `PAIRS_TOTAL` 需同步 ≥3 处，漏一处即自证说谎（`:209` 的字面 14 不随变量变）；`:206` 的指引会把人引向 v1 已不存在的"协议段"比对。
**Remedy**: 常量单点（`PAIRS_TOTAL` 由对清单/数组长度推导，或至少让文案全部插值 `$PAIRS_TOTAL`）；`:206` 改为「请同步该对 prompt/skill 的内容」。

### 🟡 F8 · R3/R2 Makefile：NFR 判据正文写了两遍，挂着 `make check` 的那份可能不是被修的那份

**Severity**: 🟡 Important
**Symptom**: `Makefile:120` 起 `check-nfr-portability-internals`（78 行 recipe / 77 条语句）vs `Makefile:200` 起 `check-nfr-portability`（88 行 wrapper）；主 agent 用 python 逐语句比对：**77 条中 76 条在 wrapper 中逐字出现**，wrapper 仅多 `NFR_OUT` / `NFR_RC` 临时文件、`case` 三态映射与 `export NFR_RC_FILE`
**Source**: 《重构》3.2 Duplicate Code；《The Pragmatic Programmer》DRY（DRY 的是知识，不是文本）
**Consequence**: 判据修一处要改两处；而 `Makefile:106 check:` 先决条件挂的是 **wrapper** ⇒ 只改 internals 时 `make check` 静默继续用旧判据（与本 change AC-4 要消灭的"看不见的漂移"同族）。当前两份逐字一致，故尚未产生错误结论。
**Remedy**: wrapper 只保留「`$(MAKE) … check-nfr-portability-internals` + 读 `$NFR_RC_FILE` 把 3 映射为 `SKIP:`+0」的薄壳，删除重复正文（单一判据源）；补一条钉住断言（如以 `BAN=` 之类特征串计数在 `Makefile` 中唯一）。

### 🟢 F9 · R5 Dependency Disorder：`write_settings_file_atomic` 用 `trap - EXIT` 清掉**调用方整条** EXIT trap

**Severity**: 🟢 Minor
**Symptom**: `flow-kit-bundle/lib/install_hooks.sh:54`（`trap "rm -f '$tmp'" EXIT`）+ `:56` · `:60`（`trap - EXIT`，注释自陈「install 路径无 EXIT trap」）
**Source**: 《Clean Architecture》依赖规则（库反向操作调用方的进程全局状态）；《重构》Inappropriate Intimacy
**Consequence**: 任何把本函数与使用 `trap … EXIT` 的脚本放进同一进程（同 bundle 的 `lib/validate_staging.sh:40` 正是该用法）都会被静默拆掉清理。已实测 `install.sh` 全文无 `trap`、未 source `validate_staging.sh` ⇒ **今天不触发**，属潜在耦合。
**Remedy**: `prev=$(trap -p EXIT)` 保存后恢复，或改为函数内局部 `rm -f`（不碰进程全局 trap）。

### 🟢 F10 · R5 Dependency Disorder：`deploy_pre_commit` / `deploy_pre_push` 经动态作用域读 `$project` / `$hook_dst`

**Severity**: 🟢 Minor
**Symptom**: `install_hooks.sh:122-130`（注释自陈依赖动态作用域；`:130` `[[ -d "${project}/.git" ]] || return 0`；`:126` 用 `$hook_dst`）
**Source**: 《Clean Architecture》依赖规则（隐式依赖不可见）；《A Philosophy of Software Design》第 5 章 Information Leakage
**Consequence**: 直接调用或将来重构时若调用方无 `set -u`，`project` 为空 ⇒ 判到 `/.git` ⇒ `return 0`，**AC-3 的 pre-push symlink 部署会静默跳过**；参数契约只存在于注释里。
**Remedy**: 显式传参（`deploy_pre_push "$project" "$hook_dst"`）或函数首行 `: "${project:?}"` 断言。

### 🟢 F11 · R1 Cognitive Overload：`install_hooks` 单函数 247 行，接线子函数嵌在其内

**Severity**: 🟢 Minor
**Symptom**: `install_hooks.sh:168-415`（其中 `:311-381` 为内嵌 `_install_hook_wiring()`，`:386` · `:390` · `:394` · `:399` 四处裸调用）
**Source**: McConnell《Code Complete》第 7 章（函数长度）；Fowler《重构》Long Method
**Consequence**: 接线逻辑无法脱离完整安装环境单测 —— 本 change 的接线判据只能经 install 端到端驱动；评审与排障需通读 247 行。
**Remedy**: `_install_hook_wiring` 提升为 top-level 函数并显式传 `settings_target`，使 bats 可直接驱动。

### 🟢 F12 · R2/R6：生产件把**本 change 的 id** 硬编码进功能分支

**Severity**: 🟢 Minor
**Symptom**: `check-path-privacy.sh:50-53`（`SELF_EXCLUDE` 含 `.specs/health-fix-2026-09b/…` 与 `INDEPENDENT-REVIEW-1/2/3.md`；`ALLOWLIST_CHANGE='.specs/health-fix-2026-09b/path-privacy-allowlist.txt'`）
**Source**: 《A Philosophy of Software Design》第 5 章 Information Leakage；《重构》Divergent Change
**Consequence**: ① change 副本回退读序（一个被实现与 bats 覆盖的机制）对**其它任何 change** 都是死分支：常设清单缺失时本应回退到 change 副本，实际直接 fail-closed；② 每个新 change 都得改生产件加自己的排除项，且本 change 归档到 `.specs/archive/<date>-…/` 后这些精确路径失效（**实测当前不产生假红**：两个审查档只剩占位符命中，全仓真实账号路径 0 命中）。
**Remedy**: 从 `.flow-active.change_id` 推导 change 目录；审查档排除按该目录内 `INDEPENDENT-REVIEW-<N>.md` 生成（仍用精确路径，禁通配）。

### 🟢 F13 · `test/test_combined_metric.bats` 尾行缺换行

**Severity**: 🟢 Minor
**Symptom**: diff 末行 `\ No newline at end of file`（`teardown` 的 `}` 后无换行）
**Source**: POSIX 文本文件定义（行以 `\n` 结尾）；仓库内其余 bats 均带尾换行
**Consequence**: `diff`/`patch` 工具链与部分编辑器会产生噪声 diff；无功能影响。
**Remedy**: 补尾换行。

### 🟢 F14 · R3：hook 家族枚举在 4+ 处手抄

**Severity**: 🟢 Minor
**Symptom**: `sync-hooks.sh:82`（`is_real_entry`）· `:95`（`--entry-class` 前缀表）· `:137`（`collect_rel_paths`）· `:284`（孤儿扫描）+ `package-flow-kit.sh` 的 pre-push cp 块 + `flow-kit-bundle/lib/validate_staging.sh:54`（Part C glob）
**Source**: 《重构》3.2 Duplicate Code（霰弹式修改）
**Consequence**: 新增一个 hook 家族要同步 6 处，漏一处即静默漂移；`make check-hooks-sync` 能抓住多数情形 ⇒ 低 severity。
**Remedy**: 家族清单收敛到一个数据源（如 `hooks/<family>/` 目录枚举 + 单一前缀表）。

### 🟢 F15 · R3：`l3-prompt.sh` 的 ADR 预算为字面量，且有一处 no-op 重定向

**Severity**: 🟢 Minor
**Symptom**: `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（`_adr_budget=18000`、单件 5000 B、`[ "$_adr_n" -lt 8 ]` 上限；`[ "$_adr_sz" -gt 5000 ] 2>/dev/null` 的重定向为 no-op）
**Source**: 《重构》3.2 Duplicate Code / Magic Number；同文件已有可配置先例（`FLOW_KIT_L3_MAX_ARTIFACT_BYTES`）
**Consequence**: 采样上限不可配（与工件上限的可配置风格不一致）；no-op 重定向是误导性装饰。
**Remedy**: 三个字面量提为环境变量（带默认值）；删除 no-op 重定向。

### 🟢 F16 · R1/R3：`runtime-edit-guard.sh` 同一函数两种拒绝惯用法

**Severity**: 🟢 Minor
**Symptom**: 新增路径用 `exit 2`（`:48` 空串、`:63-66` 非绝对路径），维护源命中路径仍用 `return 2`（`:116`）；`:113` 报文建议「在路径前加 /tmp/ 绕过本 guard」
**Source**: 《重构》Consistency；《Code Complete》第 19 章（控制流一致性）
**Consequence**: 行为等价（`:123 main "$@"` 为末句）但同一函数两套拒绝语义，读者需推演；`:113` 措辞易被误读为**官方**旁路指引。
**Remedy**: 统一为 `return 2` + 顶层 `exit`（或反之）；`:113` 改为中性表述（说明该 guard 的适用面，而非给出绕过路径）。

### 🟢 F17 · AC-5 边界：31 个 tracked 文件仍含内部项目名，全部在 `.specs/**`

**Severity**: 🟢 Minor
**Symptom**: `git grep -il chisel` ⇒ 31 个 tracked 文件（12 `.specs/archive/2026-09-01-correction-hygiene-state-guard` · 8 `.specs/health-fix-2026-09b` · 5 `.specs/archive/2026-09-18-l3-review-defects-2026-09` · 其余 6 分散于 `.specs` 与 `.specs/adr`）；`flow-kit-bundle/`（排除 test）= 0
**Source**: 威胁模型边界（分发面 vs 仓内面）
**Consequence**: 三个**分发面**（`test/`、`flow-kit-bundle/test/`、重建归档）实测 0 命中 ⇒ AC-5 达标；但若将来把 `.specs/` 纳入分发或公开归档，内部项目名会随历史工件重新出厂。
**Remedy**: v2 把 `.specs/` 显式纳入或排除出扫描面并用 ADR 固定（「`.specs/` 不可分发」），避免边界只存在于本次评审的推理里。

---

## C. UI 视觉审查

**UI: N/A（非前端项目）** —— 本 change 无 `UI-DESIGN.md`，85 个变更文件中 0 个 `.css` / `.html` / `.tsx` / `.vue` / `.svelte`；Design tokens / anti-pattern / 视觉北极星 / 无障碍四项均不适用（按 `6-review.md:265-271` 声明跳过）。

---

## D. 综合评估

**verdict: fail** —— 2 🔴 Critical · 6 🟡 Important · 9 🟢 Minor。

- **🔴 Critical（必须修复才能进 INTEGRATION）**：F1 · F2（均在 `check-path-privacy.sh`，均为 fail-open 假绿，均已由主 agent 独立复现）。
- **🟡 Important（task 内解决，不阻塞）**：F3 · F4 · F5（同文件）· F6 · F7（`check-gate-sync.sh`）· F8（`Makefile`）。
- **🟢 Minor（永不阻塞）**：F9 ~ F17 → 已写入 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md`（阶段 7 triage）。

**严重度判据说明（可审计）**：F1/F2 定 🔴 的依据不是"规范环境下会出错"（规范环境经态 A 证明**正确**，AC-6 的实现面达标），而是：本 change 的立项目标与 AC-7 明确针对「看不见的假绿」，而这两条让**隐私门禁本身**在异常环境下静默转绿，且修复面小、有双态判据可钉死。若认为应降级，需在同一份 REVIEW 里给出「接受风险」的人工确认（`6-review.md:333` R2.5）。

**修复任务**（已追加 `.specs/health-fix-2026-09b/TASK.md`，编号延续）：

| 任务 | 覆盖 | 目标文件 |
|---|---|---|
| **T-FIX-03** | F1 · F2（🔴）+ F3 · F4 · F5（🟡） | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` + `test/test_path_privacy_gate.bats` |
| **T-FIX-04** | F6 · F7（🟡） | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` + `test/test_check_gate_sync.bats` |
| **T-FIX-05** | F8（🟡） | `Makefile` + 钉住断言 |

**Cross-Model Spot-Check（ADR-014）**：触发条件满足（verdict=fail 且 ≥1 🔴）⇒ 已派**不同模型**（`qwen-token-plan-cn` / `qwen3.8-flash`；L2 盲审用的是 `glm-5.2`）做第 2 轮盲审，verdict 与 findings 写入 `INDEPENDENT-REVIEW-6.md` 的 `## Cross-Model Spot-Check` 段；其 🔴 一并纳入本次 fix loop。

---

## E. 动态门禁判定（AC-9）

| 检查项 | 级别 | 结果 | 依据 |
|---|---|---|---|
| spec 合规失败（AC 未覆盖 / 无法满足） | critical | **无** | §A：AC-1~AC-7 达标，AC-8 = 有条件通过（**仅静态面**，TD-055 macOS 实机未验证，与 TEST.md 同口径） |
| brooks-review 🔴 Critical | critical | **2 条（F1 · F2）** | ⇒ AC-9 **❌ 未通过** |
| brooks-review 🟡 Major | warn | 6 条（F3~F8） | 记录在案 + 已产 fix 任务 |
| 跨模型分歧（spot-check） | warn | **无分歧** | ADR-014：第 2 轮（`qwen3.8-flash`）独立复现 F1/F2 后同样判 **fail**，未推翻定级、未新增 🔴（§0.4） |

---

## F. 自检

- [x] review-package 已生成并 Read（§0.1）
- [x] 合并审查覆盖 spec 合规（§A）+ 代码质量 6 维（§B）+ UI（§C · N/A）+ 综合 verdict（§D）
- [x] 每条 finding 含 `**Severity**: 🔴/🟡/🟢`（17 条）
- [x] 代码质量发现含 R1~R6 编号 + 四要素 + 书本引用（F1~F16）
- [x] 🟢 Minor 已写入 `MINOR-DEFERRED.md`（F9~F17）
- [x] spot-check 触发条件已判定（触发 → 已派 subagent **并已完成**：第 2 轮 verdict = fail，与主 review 一致；增量已并入 T-FIX-03；报告见 `INDEPENDENT-REVIEW-6.md`）
- [x] 报告里没有自己悄悄改过的代码（R3.3；本次仅新增本文件 / MINOR-DEFERRED 条目 / TASK.md fix 任务块）

**技术债同步（自检项 7）**：本次触发 —— F1/F2/F6/F8 的「未能检查却说通过」族已转为 fix 任务（T-FIX-03 / T-FIX-04 / T-FIX-05），不入 TD 表；F12 / F17 两条边界问题已登记为 **TD-062**（`.specs/CONTEXT.md:609` · 常设门禁硬编码本 change id ⇒ 归档后回退分支变死代码）与 **TD-063**（`.specs/CONTEXT.md:610` · AC-5 边界：`.specs/**` 31 个 tracked 文件含内部项目名，分发三面 = 0）；F9~F17 全量条目见 `MINOR-DEFERRED.md` 的「阶段 6 · REVIEW 未处置项」表。

---

## G. 阶段完成自检（9 项 · 来源 `flow-kit-bundle/flow-kit/prompts/6-review.md:152-166`）

| # | 自检项 | 判定 | 依据 |
|---|---|---|---|
| 1 | `.specs/health-fix-2026-09b/REVIEW.md` 存在 | ✅ | 本文件 |
| 2 | Spec 合规审查已完成（AC-1~AC-8 逐条判定） | ✅ | §A（AC-1~AC-7 达标 · AC-8 = ⚠️ 有条件通过，仅静态面/TD-055） |
| 3 | 代码质量 6 维衰退风险审查已完成 | ✅ | §B（F1~F17；每条四要素 + R1~R6 编号 + 书本引用） |
| 4 | UI 视觉审查已完成或已声明跳过 | ✅ | §C（N/A：非前端项目，diff 无 UI 面） |
| 5 | 动态门禁判定（AC-9）已通过（无 🔴 Critical，或已记录接受风险） | **❌** | §E：**2 条 🔴**（F1/F2），用户未接受风险 ⇒ 按 `:154` **禁止进入 toll-gate** |
| 6 | Gate 失败项已记录在 REVIEW.md | ✅ | §E 表 + §B F1/F2 + §D 综合评估与 fix 任务表 |
| 7 | 技术债已同步到 `.specs/CONTEXT.md` | ✅ | **TD-062**（`:609`）· **TD-063**（`:610`）；F1/F2/F6/F8 转为 fix 任务（不入 TD 表） |
| 8 | TEST.md 5 轮金字塔完整性已验证 | ✅ | TEST.md §0（五轮记录）+ §1.1 AC 矩阵；本轮 AC-8 口径与 TEST.md 一致（⚠️ 仅静态面） |
| 9 | `.flow-active` 关键字段已通过 jq 写入磁盘 | ✅ | `phase` / `change_id` / `updated_at`（epoch 数值，checked by `jq -e`）在位；`task_id=null` |

**结论**：第 5 项 ❌ ⇒ 按 `:154`（任一 ❌ ⇒ 禁止进入 toll-gate）与 `:320-322`（🔴 与决定修的 🟡 ⇒ 追加 `TASK.md` + 触发回 4-dev），本阶段以 **fix loop** 收口：

1. 产出 **T-FIX-03**（🔴F1/F2 + 🟡F3/F4/F5）→ **T-FIX-04**（🟡F6/F7）→ **T-FIX-05**（🟡F8），`TASK.md:1596` 起，`status="pending"`、链式 `depends_on`；
2. 执行通用回退 jq（`$TARGET="4"`）⇒ `current_phase="4"`、`phases_done=["0","1","2","3"]`、`gates["5→6"]` 复位 `pending`；
3. 回退实况与**recipe 偏离说明**见 `.flow-active.goal.rollback`（REMOVE 取 `>= TARGET` 同时移除 `"4","5"`，避免 4→5 transition 时 `phases_done += ["4"]` 产生重复值，`4-dev.md:133`；移除 `"4"` 不影响任何检查 —— phase 4 未开门禁，3b 仅需 `gates["3→4"]="passed"`）；
4. 修完重跑 **5-test**（TEST.md 会被 fix 改动 ⇒ L3 重审由 `_l3_check_rerun` 强制触发）与 **6-review**（含 L2 + L3，`gate_config=both`）。


---

## H. 第 6 轮 fix 循环收口与 R5/AC-9 复审（阶段 6 重入 · 2026-09-28）

> ⚠️ **给 L3 审查者的判定对象说明（`TD-105` · 必读）**：本档的 L3 审查块由 `l3-review.sh` 在**模型读完工件之后**以 `<!-- L3-SECTION -->` **整块覆写**写入 ⇒ **工件里可见的 L3 判定永远是「上一轮」**。因此：① 「工件内最后一轮 L3 = fail」**不构成**本轮的新缺陷（它是上一轮的历史判定，其处置见 `INDEPENDENT-REVIEW-6.md` 的对应「主 agent 响应」段）；② **本轮的判定对象 = 上一轮 L3 findings 是否被逐条充分处置**（每条处置均给出 `Fixed in: <file>` / `Tech-debt: <TD>` / `Not-applicable:` 与可复算证据）；③ **本档不声称任何尚未落盘的 `pass`** —— `§H.3` 明确写「**L3 `pass` 之前本节不构成 6→7 放行依据**」。

> 背景：第 5 轮审查（`§0⁗`）判定 **3 🔴 + 15 🟡 + 9 🟢**（`R5-1`…`R5-27`）⇒ 用户裁决「方案 A」回退 `4-dev` ⇒ fix 循环 `T-FIX-14`…`T-FIX-24`（11 个任务 · 台账 len **53**）⇒ 阶段 5 第 12 次执行（REPRO11）重验全绿 ⇒ 本阶段重入。

### H.1 R5 findings 闭环映射（27/27 有归属）

**由 fix 任务闭合（23 条 / 11 个任务）**

| finding | 任务 | 提交 | 闭合证据 |
|---|---|---|---|
| `R5-18` | `T-FIX-14` | `775acc8` | `pre-push.sh`/`pre-commit.sh` 新增 `_resolve_self_path()`（symlink 深度解析）+ `resolve_reference_dir()` 第 4 候选；`test/test_install_layout.bats` 8 例（含反向控制） |
| `R5-19` | `T-FIX-14` | `775acc8` | `pre-commit.sh` 隐私扫描块前置于无 Makefile / npx 早退 |
| `R5-24` | `T-FIX-14` | `775acc8` | `pure_delete_seen` 死变量已删 |
| `R5-6` | `T-FIX-15` | `330a4e9` | `test/test_install_jq_guard.bats` 4 例（缺 jq 具名诊断 + `settings.json` 未被截断 + 变异腿） |
| `R5-27` | `T-FIX-15` | `330a4e9` | `TEST.md:55` AC-2 行措辞与断言面（非字节相等）对齐 |
| `R5-8` | `T-FIX-15`/`T-FIX-21` | `330a4e9`/`3129ea7` | jq 守卫 + `TEST.md` §1.1/§1.3 复算表 |
| `R5-7` | `T-FIX-16` | `b3c03fa` | `test/test_pre_push_behavior.bats` 6 例（真跑 hook；M1 变异 ⇒ 2 腿红） |
| `R5-15` | `T-FIX-17` | `60f0835` | 磁盘侧 `grep -naE -e "$PAT" -- "$file"` 隔离候选 + 「扫描面塌缩」不变式 ×3 |
| `R5-16` | `T-FIX-17` | `60f0835` | rev 面批量化（4.40–4.55 s ≤ 5 s 预算；基线 7.08–7.51 s） |
| `R5-14` | `T-FIX-18` | `4ce0d5e` | `check-gate-sync.sh` 缺件 fail-closed（`🔴 MISSING: gate-config 同步无法校验（未比对）` + 具名路径） |
| `R5-10` | `T-FIX-18` | `4ce0d5e` | 常设网腿 14（行数不变仅改内容 ⇒ 判漂移） |
| `R5-13` | `T-FIX-18` | `4ce0d5e` | `test_check_gate_sync.bats` 补 `$status` 断言 |
| `R5-9` | `T-FIX-19` | `40b909a` | AC-1 载荷注入 6 腿（含正控）+ 副本/dist 归档面；`test_runtime_edit_guard.bats` 9 → 15 |
| `R5-26` | `T-FIX-20` | `11564fb` | 删 `$HOME/.claude` 回落（`test_independent_review_model.bats` 13 例含注入腿） |
| `R5-12` | `T-FIX-20` | `11564fb` | 同上（判据自足） |
| `R5-1`/`R5-2`/`R5-3` | `T-FIX-21` | `3129ea7` | `TEST.md` §1.3 复算表 + 数量口径生成规则 + AC-3 行号现取 + 计数同步 |
| `R5-20` | `T-FIX-22` | `44eef94` | `install_hooks.sh` jq 失败三段具名诊断 + fail-closed（原文件未改动） |
| `R5-21` | `T-FIX-22` | `44eef94` | `done-validation.sh` Tier-1（非空 + 行数 + KVP）前移于 `phases_done` 短路 |
| `R5-22` | `T-FIX-22` | `44eef94` | `l3-prompt.sh` ADR 上限落「已丢弃 N 条」标记 |
| `R5-23` | `T-FIX-23` | `5bf6d29` | 存量 `mapfile`/`stat -c`/`GNU sed -i` 清零 + `.specs/archive/*` 排除 + **存量基线 ratchet**（`nfr-portability-baseline.txt` 5 条）+ 新入口 `make check-nfr-portability-full` + 常设网 14 → 20 |
| **`R5-5`** | **`T-FIX-24`**（**取代 `T-FIX-22` 的处置**） | `1900425` | **方向反转并留痕**：`R5-5` 的原始 Remedy（把 `INDEPENDENT-REVIEW-5/6.md` 追加进 `SELF_EXCLUDE`）与阶段 5 已裁决的 `T13`/`T17` **直接冲突**（豁免面冻结集 1–3；新增审查档是脱敏第一现场，须就地 de-shape）⇒ `T-FIX-22` 照原 Remedy 实施后 `T17` 于第 12 次执行首跑 **rc=1**（并致两文件移出隐私扫面 fail-open）⇒ `T-FIX-24` 恢复冻结集 6 条 + 订正契约注释 + 新增「豁免面冻结」常设腿（34 → 35）+ `TD-085` 处置反转登记 |

**登记为技术债（4 条 🟢）**：`R5-4` → `TD-083` · `R5-11` → `TD-087` · `R5-17` → `TD-089` · `R5-25` → `TD-090`。

**第 6 轮 fix 循环的追加修复（非 R5 来源 · 阶段 6 L3 驱动）**：`T-FIX-25`（`380679b`）—— L3 第 20/21 轮 major②（`TD-104`）要求真修 `T-FIX-10` 的判据并补**行为级常设腿**：`T-FIX-10 <verify>` 由单面 `grep` 改为**双面断言**（缺陷形态缺席 + `diff_rc=$?` / `rc≥2` 修复形态在场）· `test_check_gate_sync.bats` **15 → 16 例**（影子 `diff` 恒 rc=2 ⇒ 必须 `rc≠0` + `🔴 MECHANICAL` + 不得 `✅…一致`，含前置自检 rc=2 确切值）· **判别力经主 agent 忠实缺陷态复算**（删两处 rc 捕获 + 两处 `rc≥2` 分支 ⇒ 门禁 rc=0 且打印 5 处「✅…一致」、`🔴 MECHANICAL` = 0 ⇒ 新腿三断言全不成立）。⇒ **`TD-104` 本 change 内闭合**。

**第 6 轮 fix 循环新登记的债（与 R5 无关但同批产出）**：`TD-091`/`TD-092`（台账路径漂移 · 销毁式还原）· `TD-093`…`TD-100`（判据确切值 · 判据面缺陷族 · `.done` 校验库调用约定）· `TD-101`（完成契约缺交叉判据）· `TD-102`（判据夹具未随被测对象新增必需输入同步）· `TD-103`（L3 提示词截断 24%）。教训 `L-172`…`L-182`。

### H.2 AC-9 动态门禁判定（第 6 轮 · 取代 §E）

| 检查项 | 级别 | 结果 | 依据 |
|---|---|---|---|
| spec 合规失败（AC 未覆盖 / 无法满足） | critical | **无** | §A + `TEST.md` §1.1：AC-1…AC-7 达标；AC-8 = ⚠️ **有条件通过（仅静态面 · macOS 实机未验证 · `TD-055` 开放）**，四处口径一致，不得读作 8/8 |
| brooks-review 🔴 Critical | critical | **0 条** | 第 5 轮的 3 🔴（`R5-6`/`R5-7`/`R5-18`）已由 `T-FIX-15`/`T-FIX-16`/`T-FIX-14` 修复并常设化；第 12 次执行判据面 **25/25 rc=0**、门禁 **7/7 rc=0**、`make check` **21 ✅ / 0 ❌** |
| **AC-8 未完全通过** | **warn** | ⚠️ **有条件通过（仅静态面）** —— 跨 OS/macOS **实机面未验证**，`TD-055` 跨 change 开放 | `REQUIREMENT.md` AC-8（跨 OS 兼容为验收面之一）· `TEST.md` §1.1/§U-3 同口径；**不阻塞 toll-gate，但不得读作 AC-8 通过**（L2 第 1 轮 🟡 L2-6R4 收口：本行把该口径从「critical 行内的括号注释」升为**独立 warn 行**） |
| brooks-review 🟡 Major | warn | 15 条 → **全部处置**（14 修 + 1 方向反转修复） | H.1 表；`R5-5` 的处置被 `T-FIX-24` 反转（见该行） |
| 🟢 Minor | info | 9 条 → 4 条登记 `TD-083`/`TD-087`/`TD-089`/`TD-090`；其余随 fix 顺带闭合 | H.1 表 |
| 跨模型分歧（spot-check） | warn | **无分歧** | 第 5 轮 ADR-014 `qwen3.8-flash` spot-check 命中 2 条 🔴（`F1`/`F2` ⇒ 与主审一致，未推翻定级）；本轮 fix 后未再现分歧 |

**判定（L3 第 19 轮 major 1/2 收口后 · 口径下调）**：**AC-9 ⚠️ 有条件通过** —— 无 🔴 Critical，但 **AC-8 未完全通过**（跨 OS/macOS 实机面未验证 · `TD-055` 开放）按 AC-9 级别表属「**AC 未覆盖**」面，故**不再写 ✅ 通过**；该项**不阻塞 6→7** 的依据 = **用户在 5→6 Toll-gate 的显式裁决**（L3 第 20 轮 major ③ 要求附原文）：主 agent 于 2026-09-28 的 Toll-gate 5→6 提示**原文**写明「⚠️ 两项披露：① L3 提示词**截断 24%**…；② **AC-8 仍为 ⚠️ 有条件通过（仅静态面 · macOS 实机未验证 · `TD-055`）**，不得读作 8/8 AC 全通过。」；用户在四选项（**1 继续 → 6-review** / 2 暂停 / 3 回退 4-dev / 4 全自动推进）中选择 **1**。`.flow-active.goal.gates["5→6"]="passed"` 即该裁决的结果状态；`TD-055` 保留开放交阶段 7 triage。**其余任何处不得把「用户已知情」当作免检依据。****仍不得读作「AC-8 通过」或「8/8 AC 全通过」**。**但 AC-8 计为 warn**：⚠️ **未完全通过**（仅静态面 · 跨 OS 实机面未验证 · `TD-055` 跨 change 开放）⇒ **不阻塞 toll-gate，但本判定不得读作「AC-8 通过」**（L2 第 1 轮 🟡 L2-6R4 收口）。

**AC-1…AC-8 的复算入口与回执来源（L3 第 19 轮 major 1 + 第 21 轮 minor ③ 收口 · 表名已由「独立复算面」更正）**：下表给出**每条 AC 的可复算入口**（判据均为 `TASK.md` 的 `<verify>` 原文，`awk` 抽取后字面执行）。**❌ 不等于「已由外部审查者独立确认」**：L2 第 1 轮自陈 4 条未重跑（变异实证 / 端到端安装形态 / 候选塌缩夹具 / 全量门禁），这些面**依赖主 agent 回执，不构成独立确认**（详见 L2 段「未验证边界」与本阶段响应的处置）。

> **口径刷新（`T-FIX-25` 后 · 2026-09-28）**：bats 收集面 `1115 → 1116`、有效用例 `1114 → 1115`（`TEST.md` §0 已加「第 12 次执行补充」声明）；受影响面（`check-gate-sync` 系判据 `T-FIX-04`/`T-FIX-10`/`T-FIX-13`/`T17` + 七项门禁）已做**增量复验**（`PHASE5-RECEIPTS.md` **§U-5**：判据 **4/4 rc=0** · 门禁 **8/8 rc=0** · NFR max 3.869 s / 均值 3.785 = 75.7%）· 阶段 5 L3 亦已按新工件 hash 重审 = **pass**（第 22 轮）。其余判据的权威回执仍为 §U（`HEAD 77984cc` 时点）。

| AC | 判据 | 独立复算入口 | 回执来源（**显式区分「L2 亲跑」/「主 agent 回执」**） |
|---|---|---|---|
| AC-1 | `T05` | `bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only --only T05` | §U-1（rc=0 · 12 行判据）+ **主 agent**：`runtime-edit-guard.sh` 的 `eval` 面归零 + `test_runtime_edit_guard.bats` 15 例（含载荷注入 6 腿 · `T-FIX-19`）；~~L2 亲跑 `T17`（同族 eval 面）~~ **已撤**（`T17` 是隐私豁免面/冻结集判据，与 AC-1 的 eval 载荷不同族 · L3 第 20 轮 minor ② 收口） |
| AC-2 | `T06` | 同上 `--only T06` | §U-1（rc=0 · 22 行）+ `test_install_jq_guard.bats` 4 例 |
| AC-3 | `T11`/`T19`（`T17` 仅作**拒绝面**旁证） | 同上 `--only T11` / `T19` | §U-1（rc=0）；**行为级主证据 = `test/test_pre_push_behavior.bats` 6 例**（真跑 hook：干净放行 / 泄漏拒绝+指名 ref / 纯删除跳过 / 畸形 stdin fail-closed / 检查器在位+清单缺 rc=2 / 消费者形态无 Makefile 仍拒）；**L2 第 1 轮亲跑 `T17` rc=0 属「拒绝面」旁证（豁免面冻结），不构成 AC-3 四推送形态的独立确认**（L3 第 20 轮 minor ② 收口） |
| AC-4 | `T13` | 同上 `--only T13` | §U-1（rc=0 · 34 行）+ **L2 亲跑 `T13` rc=0** |
| AC-5 | `T24` | 同上 `--only T24` | §U-1（rc=0 · 18 行） |
| AC-6 | `T20`/`T22`/`T26` | 同上 `--only T20` / `T22` / `T26` | §U-1（rc=0）+ **主 agent §U-2 回执**：`make check-path-privacy` rc=0（候选 1623 / 扫描 1617 / 自排除 6 / 命中 0 · 原文 `/tmp/p6d/r12/make-check.txt`）；L2 第 1 轮的**最终回执**亦列有该命令 rc=0，但**该命令未写进 L2 段正文** ⇒ 只按回执证据读，**不构成段内独立确认**（L3 第 20 轮 critical ② 收口） |
| AC-7 | `T27`/`T29` | 同上 `--only T27` / `T29` | §U-1（rc=0）+ 4 假绿件注入型用例 |
| AC-8 | `T29` + `make check` + `make check-nfr-portability(-full)` | `--only T29`；`make check`；`make check-nfr-portability-full` | §U-1/§U-2（rc=0）；**跨 OS 实机面 = 未验证（`TD-055`）** ⇒ ⚠️ **有条件通过** |

### H.3 阶段完成自检（9 项 · 第 6 轮 · 来源 `6-review.md:152-166`）

| # | 自检项 | 判定 | 依据 |
|---|---|---|---|
| 1 | `REVIEW.md` 存在 | ✅ | 本文件（含 §0′…§0⁗ + §H） |
| 2 | Spec 合规审查已完成（AC-1~AC-8 逐条判定） | ✅ | §A + `TEST.md` §1.1（AC-8 ⚠️ 仅静态面 · `TD-055`） |
| 3 | 代码质量 6 维衰退风险审查已完成 | ✅ | §B（F1~F17）+ 第 5 轮四方独立审查（`R5-1`…`R5-27`）+ fix 后逐条闭环（H.1） |
| 4 | UI 视觉审查已完成或已声明跳过 | ✅ | §C（N/A：非前端项目） |
| 5 | 动态门禁判定（AC-9）已通过 | **⚠️ 有条件通过** | **H.2：0 🔴**（第 5 轮的 3 🔴 已闭合并经 REPRO11 复验）；**AC-8 未完全通过**（跨 OS 实机面未验证 · `TD-055` 开放）⇒ AC-9 口径下调为「有条件通过」（L3 第 19 轮 major 1/2 收口），不阻塞 6→7 的依据 = 用户在 5→6 Toll-gate 被显式告知后裁决继续 |
| 6 | Gate 失败项已记录在 REVIEW.md | ✅ | §E（第 5 轮 ❌ 的历史记录保留）+ H.2（第 6 轮 ✅） |
| 7 | 技术债已同步到 `.specs/CONTEXT.md` | ✅ | `TD-083`…`TD-105`（第 6 轮新增 15 条：`TD-091`…`TD-105`）；**其中 `TD-104` 已由 `T-FIX-25` 真修 ⇒ 本 change 内闭合**；`TD-105`（L3 自引用死锁 · 机制层）开放 |
| 8 | `TEST.md` 5 轮金字塔完整性已验证 | ✅ | `TEST.md` §0（第 1…12 次执行）+ §1.1 AC 矩阵 + §U（`PHASE5-RECEIPTS.md`）|
| 9 | `.flow-active` 关键字段已通过 jq 写入磁盘 | ✅ | **时点 = 阶段 6 第 3 次重入后（本行写入时刻）**：`phase="6"` · `phases_done=["0"…"5"]` · `gates["5→6"]="passed"` · `updated_at` = epoch int · `33-flow-active-integrity.sh` rc=0 · `task_progress` len **54**（`T-FIX-25` 入库后）。**时点对照（防误读 · L2 第 1 轮 🟢 L2-6R5 收口）**：`PHASE5-RECEIPTS.md` §U-4 第 7 项记的是**阶段 5 执行时点**（`phase="5"` · `phases_done=["0"…"4"]` · len 53）—— 两者**不矛盾，差一个 5→6 transition**。 |

**结论（L3 第 20 轮 major ① 收口 · 措辞已收紧）**：**9/9 自检项「已完成」**，但**其中第 5 项（AC-9）为 ⚠️ 有条件通过**（AC-8 跨 OS 实机面未验证 · `TD-055` 开放）—— **不得读作「9/9 全过」或「AC 全通过」**。

⇒ **进入 Toll-gate 6→7 的前提 = `gate_config["6-review"]=both` 的 L2/L3 独立审查均 `pass`**：**L2 第 1/2 轮 = pass · L3 第 22 轮 = pass ⇒ 前提已满足**（第 19/20/21 轮 fail 的处置链见下）： 本阶段 L3 第 19 轮 `fail`（2 major）与第 20 轮 `fail`（2 critical + 3 major + 3 minor）的逐条处置见 `INDEPENDENT-REVIEW-6.md` 的两段「主 agent 响应」（第 20 轮的处置含：AC 表的证据归属修正 · 「不阻塞」依据附用户裁决原文 · 本节措辞收紧 · `TD-104` 登记）。**处置后必须重跑 L3，并以 L3 给出的 `pass` 判定为放行依据；在 L3 `pass` 之前，本节不构成 6→7 的放行依据。**

⇒ 用户裁决：`auto_advance=false` ⇒ 即使 L2/L3 均 `pass`，也必须停下等用户裁决。
