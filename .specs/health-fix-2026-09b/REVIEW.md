# 阶段 6 · REVIEW — health-fix-2026-09b

**verdict（第 3 轮 · 本轮 · 现行结论）: fail** —— 审查面扩到「2 个独立审计 subagent 的对抗式深审 + 主 agent 逐条亲验」后，在 fix 循环后的 HEAD `7b624dc` 上共得 **5 🔴 Critical + 13 🟡 Important + 12 🟢 Minor**。五条 🔴 全部由主 agent **独立复跑夹具坐实**：R3-1/R3-2（本 change 新建的 `check-path-privacy.sh` 的 C 引号化静默跳过 + index/工作树内容面错配 ⇒ 假绿，后者直接击穿本 change 自身的 `pre-commit.sh:33 → Makefile:127` 拦截链）· R3-14（`pre-push`/`pre-commit` 在消费者项目 fail-closed ⇒ 拒一切 push/commit，且使 ADR-027② 失效）· R3-15/R3-16（NFR 门禁 `realpath` 死模式 + 未加引号 `for` 静默跳过 ⇒ 假绿）。⇒ **出口 = 回退 `4-dev`，追加 `T-FIX-07` … `T-FIX-10`**（分解见 §0″.6）；12 条 🟢 入 `MINOR-DEFERRED.md` 交阶段 7 triage。

**verdict（第 2 轮 · fix 循环后重审）: pass** —— 第 1 轮的 2 条 🔴 + 6 条 🟡 已**全部闭合并逐条活性重放**；9 条 🟢 维持 `MINOR-DEFERRED.md`；第 2 轮另增 **3 条 🟡**（F-18 扫描面标签过度声明 · F-19「0 实际扫描」仍报 ✅ · F-20 `mktemp` 立即终止未生效）——**三条均经用户裁决在本 change 内修**（F-18 = 只改措辞；F-19 + F-20 = 同批修复）⇒ 已回退 4-dev 追加 `T-FIX-06`，修后重跑 5-test → 6-review；深审 🟢 F-21（jobserver 警告）裁决 `Not-applicable` 并登记 `MINOR-DEFERRED.md`。

> **第 1 轮（历史）** = 下方 §0 … §G：`verdict: fail`（2 🔴 + 6 🟡 + 9 🟢），修复出口 `T-FIX-03`/`T-FIX-04`/`T-FIX-05` → `4-dev`。
> **第 2 轮（历史）** = §0′：`verdict: pass`（0 🔴 + 3 🟡），出口 `T-FIX-06`。
> **第 3 轮（本轮 · 现行结论）** = §0″：`verdict: fail`（5 🔴 + 13 🟡 + 12 🟢）。

- **审查对象（第 2 轮）**：`534e3e842fc900045f39492badc66eabe3ffd4c4` … `HEAD`（`cb21c03`）
- **变更规模（第 2 轮）**：全量 **95 files / +24300 / −153**；fix 循环 3 提交 = `6e39cfb`（`T-FIX-03`）/ `521b21c`（`T-FIX-04`）/ `6e94d60`（`T-FIX-05`）
- **审查者**：主 agent（Reviewer）· 遵守 **R3.3 = 本次审查未修改任何代码**（仅生成本文件 + `MINOR-DEFERRED.md`）
- **动态门禁判定（AC-9）**：**✅ 通过**（0 条 🔴 Critical；🟡 F-18 按 `6-review.md:294` 非阻塞）。**注**：本判定属第 2 轮快照（HEAD `cb21c03`）；用户已裁决 F-18/F-19/F-20 在本 change 内修 ⇒ 该快照的 AC-9 结论将在 `T-FIX-06` 落地后的重审中重新出具。
- **spot-check（ADR-014）**：第 1 轮已触发并完成（`INDEPENDENT-REVIEW-6.md` 的 `## Cross-Model Spot-Check` 段）；本轮 `verdict=pass` ⇒ **无新触发条件**

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
