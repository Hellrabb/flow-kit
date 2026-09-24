# 阶段 6 · REVIEW — health-fix-2026-09b

**verdict: fail** —— 2 条 🔴 Critical（均在**本 change 新增**的隐私门禁里，属 fail-open 假绿）+ 6 条 🟡 Important + 9 条 🟢 Minor。

- **审查对象**：`534e3e842fc900045f39492badc66eabe3ffd4c4` … `HEAD`（`7dd4bd7`，2026-09-24T19:03:11+08:00）
- **变更规模**：全量 **85 files / +17005 / −149**；产品面（排除 `.specs/`）**37 files / +2416 / −146**
- **审查者**：主 agent（Reviewer）· 遵守 **R3.3 = 本次审查未修改任何代码**（仅生成本文件 + `MINOR-DEFERRED.md` + 追加 fix 任务）
- **动态门禁判定（AC-9）**：**❌ 未通过**（存在 🔴 Critical）⇒ 禁止进 INTEGRATION
- **修复出口**：`T-FIX-03` / `T-FIX-04` / `T-FIX-05` → `4-dev`
- **spot-check**：**触发**（verdict=fail 且 ≥1 🔴，ADR-014）→ 第 2 轮盲审结果见 `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md` 的 `## Cross-Model Spot-Check` 段

---

## 0. 审查方法、门禁回执与独立复现

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
| **AC-5** 内部项目名不再随分发件出厂（P3） | T07/T13：`chisel-*` → `sample-proj-*` 等中性占位；审查档/工件脱敏 | 三面计数 0：`test/` + `flow-kit-bundle/test/` `grep -rq -i chisel` 无命中；重建归档逐个（禁通配）`tar xzOf dist/dsh-flow-kit-0.2.0.tgz \| grep -ac` = 0 | ✅（边界见 F17） | 主 agent 独立复核：`git grep -l '/home/<acct>/' HEAD` = **0 个文件**（真实账号路径在 tracked 树 0 命中） |
| **AC-6** 前向脱敏有机器门禁（P6） | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（新 392 行）· 常设清单 `path-privacy-allowlist.txt`（T21 冻结，16 行 / 0 有效条目）· `Makefile check-path-privacy` · `pre-commit` 在 `make test` 之后接线 · `pre-push` 按 ref 评估 | `test/test_path_privacy_gate.bats`（9 例 · F1 常设网：干净 / 真名探针 / 两份清单皆缺 / 空清单（含反假绿）/ 清单内命中 / 占位形态不命中 / change 副本回退读序 / 常设优先） | ⚠️ **实现面达标但门禁可被环境静默旁路** ⇒ 见 F1/F2（🔴） | §0.3 态 A 证明规范环境正确；态 B/C 证明 fail-open |
| **AC-7** 四处假绿测试不再假绿（TC3/TC4/TC5） | T09 `test_combined_metric.bats`（扫描根收敛到 `$TEST_TMPDIR/scan`，脱离宿主 `/tmp` 的 149 个无关 `tmp.*`）· T10 `test_independent_review_model.bats`（+文件存在性前置断言）与 `test_lessons_cleanup.bats`（过期 `skip` → 真跑 `validate_staging_coverage`）· T15 `test_check_gate_sync.bats`（`-ne 2` → `-eq 0`）· T20 `test_auto_checkpoint.bats`（`hook_rc=$?` 立即捕获，原断言对象误为 jq） | 逐条核对 diff：**全部为收紧**，无一处放宽或删断言 | ✅ | `TASK.md:24` 明写四处归属 T09/T10/T15/T20；TEST.md 记有「注入失败 ⇒ 转红」的判别式回执 |
| **AC-8** 无退化（含 rc=3 SKIP≠PASS 与 `.change-base` 锚点守卫） | `Makefile check-nfr-portability-internals`（三态 rc∈{0,1,3}，经 `$NFR_RC_FILE` 回传；空变更集 ⇒ rc=3 + `SKIP:`）与包装层（rc∈{0,1}，3 ⇒ 0 且保留 `SKIP:`）· T29 收口（`make check` 九门禁 + bats 地板）· `.change-base` 锚点 | `test/test_nfr_portability_gate.bats`（7 例 · F3 常设网）+ T29 判据（15 行） | ⚠️ **有条件通过（仅静态面）**：change 期静态判据 rc=0；**跨 OS 实机面 = 未验证（TD-055）**，不得读作 AC-8 通过 | §0.2 回执全绿；`make check` 21✅/0❌ |

**AC-9 动态门禁判定**：见 §E —— **❌**（有 🔴 Critical）。

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
