# 独立审查 · 阶段 1

---

## L2 盲审

**审查对象**：`.specs/health-fix-2026-09/REQUIREMENT.md`（阶段 1 · change-id `health-fix-2026-09`）
**可参考**：`CHANGE.md`、`.specs/CONTEXT.md`、`.specs/health/2026-09-20-HEALTH.md`
**独立性声明**：本报告只依据上述工件与仓库实测（read/grep/bash）。未收到、也未采信任何主 agent 自评、辩护、草稿或此前审查结论（`PROGRESS.md`、`.goal-snapshot.json` 等未经指定的一律未读）。故无需触发「独立性受损」标注。所有探针均在 `/tmp` 隔离副本上执行并 `trap` 还原；执行前后 `git status --porcelain` 自证无残留（`dsh-flow-kit/README.md` md5 前后一致；两个 exec 位探针文件权限位复原为 775/755）。

---

### 事实抽验（预检表逐行独立复算）

| 预检行 | 工件断言 | 我的实测（命令 → 结果） | 判定 |
|---|---|---|---|
| AC-1 | 改 `dsh-flow-kit/README.md` 后 `make check` 绿、日志中 `README` 出现 0 次 | 追加探针行后 `make check` → **exit 0**；`grep -n README` 命中 **0 行**；还原后 md5 一致 | ✅ 属实 |
| AC-3 | `make lint` 绿、`install.sh` 出现 0 次；单跑 `shellcheck flow-kit-bundle/install.sh` 报 3 处 error（SC1073/SC1050/SC1072） | `make lint` → exit 0，`grep -c 'install\.sh'` = **0**；注入副本 `shellcheck -e SC1091` → **恰好 3 条 (error)：SC1073/SC1050/SC1072**，且 AC-3 的正则 `SC10[0-9]+.*error` 命中 | ✅ 属实 |
| AC-5 | 输出 `⚠️ 5 个 hook 入口缺可执行位`、退出码 0 | 逐字一致（1 处告警，exit 0） | ✅ 属实 |
| AC-6 | 摘掉源真入口 exec 位后：exit 0 · 文件名 0 次 · 计数仍 5 | 逐字一致（见 R1 实测输出） | ✅ 属实（但**成因判断不完整** → R1） |
| AC-2 | dist 当前与源一致（09-20 重建过），基线成立 | `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` → **1 个文件不同**（源 10:15 已修、dist 09:56 构建） | ❌ **不实** → R2 |
| AC-7 | `make verify-claims` 13 ✅ / 0 ❌ | `bash verify-claims.sh` → **exit 1，复验结果: ✅ 11 ❌ 2**（§8 与 §0.5.1 两项因引用已归档路径失败） | ❌ **不实** → R3 |
| AC-7 | `make test` 950 ok / 0 not ok / 1 skip；lint error 0；check-validate 漏配/源缺失 0；test 双源一致；7 镜像根漂移 0 | 全部复算一致（`npx bats test/ --formatter tap` → 950/0/1，exit 0；其余逐条实测字面一致） | ✅ 属实 |

**结论**：6 条关键预检行中 **2 条不实**（AC-2、AC-7）。其余属实，AC-1/AC-3/AC-5/AC-6 的判据本身有真实证明力。

---

### 🔴 R1 · AC-6 是本次自述的「承重性证明」，但它的探针打在**判据域之外**，按 v1/F3 范围必然失败

**Severity**：🔴 Critical
**Symptom（症状）**：`REQUIREMENT.md:90-118`（AC-6 的 Given/验证脚本固定 chmod `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`，即**源** bundle）与 `sync-hooks.sh:47-55`（`DEST_ROOTS` 只含 7 个**镜像根**，源不是其中之一）、`sync-hooks.sh:180-183`（漂移比对是 `cmp -s`，**只比内容不看 mode**）、`sync-hooks.sh:188-196`（exec 判据只作用于 `$dst_f`）冲突。实测两组对照：
```
# ① 照 AC-6 打「源」（requirement 指定的文件）
F=flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
cp -p "$F" /tmp/bak; chmod -x "$F"; make check-hooks-sync; echo exit=$?
→ exit=0；grep -c independent-review-gate = 0；仍打印「⚠️ 5 个 hook 入口缺可执行位」
# ② 改打「镜像副本」
G=dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh
cp -p "$G" /tmp/bak2; chmod -x "$G"; make check-hooks-sync
→ 「⚠️ 6 个 hook 入口缺可执行位」（计数 5→6，判据确实看得见），但文件名出现次数 **仍为 0**
```
**Source（源头）**：判据域必须与被判据对象同域 —— `sync-hooks.sh:2-13` 自述本工具治理的是「唯一维护源 → N 个安装副本」的**副本**；源侧权限位归 `install_hooks.sh`（`:134-141` 对所有 pre-tool-use 部署副本 `chmod +x`）。AC-6 却拿源文件当探针。另：`sync-hooks.sh:193` 的文件名打印**只在 `--list` 模式**（实测 `bash sync-hooks.sh --list` 已能逐条列出那 5 个路径），所以「无文件名」只是 `--check` 的打印差异，不是能力缺失。
**Consequence（后果）**：AC-6 被本工件自述为「本次最关键的承重性证明」（`REQUIREMENT.md:95`），但它按 F3「只收窄判据 + 逐条指名」+ DESIGN D4/D5/D6 的实现**永远不可能通过**：源 exec 位丢失在检查器里是**不可观测事件**（连计数都不动）。TEST 阶段会卡在这条 AC 上；若实现者为过 AC 偷偷把判据域扩到源 bundle，那是未声明的范围扩张（DESIGN §0.5.1 只列 `Makefile` / `sync-hooks.sh` / `package-dsh-plugin.sh` / `common.sh`）。`REQUIREMENT.md:97-101` 与 `:157` 把根因写成「只有聚合计数、无文件名」——这只解释了**镜像侧**的一半，掩盖了域错位。
**Remedy（修补）**：三选一并写进工件（DESIGN 需定案，AC-6 的 Given/脚本随之改写）：
(a) 探针改打**镜像副本**（如 `dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh`），"指名"要求照旧 —— 这是最小改动，实测计数会 5→6，加"逐条指名"后即可通过；
(b) 若坚持用源文件做探针，则 F3 必须显式扩域：「exec 判据同时作用于源 `flow-kit-bundle/hooks/` 与 7 个镜像根」，并把该扩域登记为范围项与风险；
(c) 明确 AC-6 只验镜像侧，源侧权限另立 AC（源侧才是 install 契约的输入）。

---

### 🔴 R2 · 预检表 AC-2 行与实测相反：dist **当前已经陈旧**；且 AC-2 的 Given 用「git 干净」代理 dist 新鲜 —— 这正是本 change 要堵的盲区

**Severity**：🔴 Critical
**Symptom（症状）**：`REQUIREMENT.md:154`（「AC-2 | dist 当前与源一致（09-20 重建过），`make check` 绿 | 基线成立」）与 `REQUIREMENT.md:50`（Given：「dist 由当前源正常重建过（**工作区 `git status --porcelain` 干净**）」）。实测：
```
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle
→ 文件 flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
  和 dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_l3_review_defects_2026_09.bats 不同
stat → 源 2026-09-20 10:15:58 ／ dist 副本 2026-09-20 09:56:31（diff 15 行：源侧已改成「live 优先 → archive 回退」）
git status --porcelain → 非空（.specs/CONTEXT.md、.specs/LESSONS.md 等）
```
**Source（源头）**：`REQUIREMENT.md:196` 假设 A1「dist 是纯派生产物」成立，但「派生产物新鲜」不能用 VCS 状态证明 —— `.gitignore:63` 明确忽略 `dist/`，git 对 dist 陈旧**结构性失明**（这正是 `CHANGE.md:14` 列的第 1 条绕过路径）。CHANGE.md 把「vendor 是否纳入比对」列为「未知」、DESIGN D3 定案「**vendor 的比对包含 `test/`**」—— 在该定案下，上面这个差异就是 check-dist 的**红**信号，故基线不成立。
**Consequence（后果）**：AC-2 是防「门禁永远红」的反例保护 AC，其 Given 现在字面不成立、其引用的一致性基线已被证伪。TEST 阶段照抄该 Given 直接开跑会得到与断言相反的结果（要么误判门禁坏了，要么被迫补一步未写进 AC 的「重建 dist」前置动作）。更糟的是它把「git 干净」当作 dist 新鲜的代理，等于在需求里复刻了本 change 要消灭的那条假安全感。
**Remedy（修补）**：① 删除括号里的 `git status --porcelain` 代理，Given 改为「已执行 `make test-sync` 后 `bash package-dsh-plugin.sh` 重建 dist（工作区代码文件无未提交改动）」；② 预检行按实测改写：「dist 顶层 5 个目录 0 差异；`vendor/flow-kit-bundle/test/` 有 1 文件陈旧（源 10:15 已改，dist 09:56 构建）→ check-dist 落地后该状态应为红，重建后转绿」——这恰好可以作为 AC-1/AC-2 的**真实反例样本**（比 README 探针更强的证据，因为它现在就是红的）。

---

### 🔴 R3 · 预检表 AC-7 行不实（实测 11 ✅ / 2 ❌）；`verify-claims.sh` 又不在依赖/触碰清单里 → AC-7（F4 全量回归绿）按现范围不可达

**Severity**：🔴 Critical
**Symptom（症状）**：`REQUIREMENT.md:130`（「`make verify-claims`：**13 ✅ / 0 ❌**」）与 `REQUIREMENT.md:195`（依赖清单只有 Makefile / sync-hooks.sh / package-dsh-plugin.sh / shellcheck / bats，**无 verify-claims.sh**）。实测 `bash verify-claims.sh`：
```
❌ §5 R: （应 ）|§2.x: |§2.4 引用= 定义=            ← 第 8 项「DESIGN 结构自洽」
❌ §0.5.1 未列: … Makefile package-flow-kit.sh sync-hooks.sh … verify-claims.sh
复验结果: ✅ 11  ❌ 2        exit=1
```
根因：`verify-claims.sh:123`（`D=".specs/l3-review-defects-2026-09/DESIGN.md"`）、`:137`（`M=.specs/l3-review-defects-2026-09/MINOR-DEFERRED.md`）、`:158`（逐文件 `grep -qF` 进同一缺失路径）引用的是**已归档**的 live 路径（实测 `ls -d .specs/l3-review-defects-2026-09` → 不存在；该目录由 `e5fca58` 于 **2026-09-20 10:19:01** 归档），而 `REQUIREMENT.md` 成文于 **11:38:43** —— 该失败在写需求**之前 79 分钟**就已存在，属「未预检即断言」。另 `verify-claims.sh:165` 硬编码文案 `make check 五门全绿`，加入第 6 门后即成假陈述（正是该脚本 §6/§10b 在治理的「陈旧计数」类）。
**Source（源头）**：`REQUIREMENT.md:202`「AC 是 TEST 阶段派生用例的唯一来源」+ `:145-146` 自述预检存在的理由（「AC 若在修复前就已通过，它就没有证明力」）—— 反向同理：**期望值本身不可达的 AC 同样没有证明力**。仓库既有先例：`ac47f85` 为同一类「归档打断 live 路径引用」修过 bats（见 `LESSONS.md:34` 2026-09-20c），verify-claims 的同类引用被漏掉。
**Consequence（后果）**：F4「AC-7 全量回归绿」在现范围下**不可能达成**：要让它绿，必须改 `verify-claims.sh`（§8/§0.5.1 走 live→archive 回退、文案去「五门」），而该文件既不在 v1 的 F1–F5、也不在 DESIGN §0.5.1 触碰清单、也没被登记为 out/v2。若不改，change 会卡在自己的回归 AC 上；若改，就是未登记的范围扩张（且该文件的 basename 早已在 §0.5.1 的变更集里，改它只会让这条检查继续红）。
**Remedy（修补）**：① 把 `verify-claims.sh` 写入依赖与 DESIGN §0.5.1 触碰清单；② §8/§9/§10c 的载体路径改「**live 优先 → archive 回退 → 两者皆无则显式失败**」（与 `ac47f85` 对 bats 的修法同款，禁止静默通过）；③ `:165` 文案去掉「五门」或改为动态计数；④ AC-7 的期望值先跑一次基线再写死（当前应为 `11 ✅ / 2 ❌`，修复后按实测填）。

---

### 🟡 R4 · AC-2 / AC-4 未给可复制命令与期望输出，违背工件自述的「全部为机械可验」；AC-4 的文件计数 4 与实测 7 不符

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:27` 声明「**全部为机械可验**：每条给出一条可复制粘贴的命令 + 期望输出」；但 `:53`（AC-2）只有「make check 退出码 0 + 输出含 check-dist 通过标记」（"通过标记"字样未定义，无命令）；`:76-81`（AC-4）写「验证方式：列出扫描清单并逐一断言（实现方式由 DESIGN 定，验证以"文件被扫到"为准，不以"用什么命令枚举"为准）」——**没有命令、没有期望输出**，而"列出扫描清单"只能靠读 `make lint` 的实现（白盒），对 `find` 实现恒真。另 `:80`「**4 个文件**全部在 `make lint` 的实际扫描清单内」与实际不符：
```
Makefile:23 现 glob 覆盖 60 个 .sh；仓库 .sh 共 130 个；未覆盖的生产脚本实为 7 个：
flow-kit-bundle/install.sh · hooks/pre-commit/pre-commit.sh ·
flow-kit/reference/check-gate-sync.sh ·
flow-kit/regression-demos/{hallucination-guard,scope-drift-guard,strong-model-verbosity,weak-model-interactive-ui}/check.sh
```
（`regression-demos/*/check.sh` 这一个 glob 展开就是 4 个文件；未覆盖合计 **7**，不是「4 个文件」。预检/CHANGE.md 说的「5 处 warning」我逐文件复算属实：`install.sh` SC2034×2 + `check-gate-sync.sh` SC2034×2 + `weak-model-interactive-ui/check.sh` SC1090×1。）
**Source（源头）**：`REQUIREMENT.md:143-146` 的预检哲学（AC 必须可复算）+ `:202`（TEST 只能派生自 AC）—— 不可执行的 AC 在 TEST 阶段必然被"翻译"成实现相关的断言，等于把验收权让给实现。
**Consequence（后果）**：AC-4 极可能被写成「grep Makefile 源码里有 `find`」这类恒真断言；「4 个」的计数会让 TEST 少断言 3 个 regression-demo（真实盲区残留），而 F2 的目标恰是"全部生产脚本"。
**Remedy（修补）**：① AC-2 补命令，例如 `bash package-dsh-plugin.sh --check; echo $?` + 期望 `0` 且输出含 `check-dist` 通过行；② AC-4 改为行为化断言：对 7 个文件逐个注入 `if [ 1 -eq 1 ]`（不闭合）后 `make lint` 必须非零且输出指名该文件（复用 AC-3 的写法），并把「4 个文件」改为「7 个文件」；③ 若要保留"清单快照"式断言，必须同时给出「如何在不读实现的前提下导出该清单」的命令（例如让 lint 支持 `DRY_RUN=1` 打印清单）。

---

### 🟡 R5 · v1 的 F5（判据理由注释 / US-4）没有任何 AC 覆盖 → 不可验收

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:169`（F5「门禁判据的**理由注释**（为什么这样判、依据哪份报告）写进 Makefile / sync-hooks.sh —— 让 US-4 成立」）在 AC-1…AC-8（`:30-139`）中**无对应用例**；AC 只覆盖 F1（AC-1/2）、F2（AC-3/4）、F3（AC-5/6）、F4（AC-7）。另 F5 点名的载体是 `Makefile / sync-hooks.sh`，而 DESIGN D2 把 check-dist 落在 `package-dsh-plugin.sh`（其 §0.5.3 还自设了"必须写模式为何不比"的注释要求），F5 未涵盖该文件。
**Source（源头）**：`REQUIREMENT.md:202`「AC 是 TEST 阶段派生用例的唯一来源」—— 无 AC 的 feature 在 5-test 阶段无人验；US-4 是四条用户故事之一，属可交付内容。
**Consequence（后果）**：「门禁为什么这样判」这条交付物落空不会被任何门禁或 TEST 发现，F5 实际降级为"希望实现者记得写注释"。下一轮巡检仍会重复同一个盲区讨论。
**Remedy（修补）**：补一条可机械验证的 AC（如：断言 `Makefile` 的 `check-dist` target、`sync-hooks.sh` 的 exec 判据块、`package-dsh-plugin.sh --check` 分支**各自**存在指向 `.specs/health/2026-09-20-HEALTH.md` 或具体条目的注释引用，用 `grep -c` 计期望值），并把 F5 的载体清单补上 `package-dsh-plugin.sh`。

---

### 🟡 R6 · check-dist 的比对域未在需求里定案并落成判据（vendor/含 test/、tarball、docs/）→ 头号目标「dist 陈旧」在 AC 层无法被证明闭合

**Severity**：🟡 Important
**Symptom（症状）**：AC-1 的探针只覆盖包顶层 `dsh-flow-kit/README.md`（`:33`、`:40-44`）；AC-2 只说"与源一致"；`REQUIREMENT.md:195` 的依赖只提「package-dsh-plugin.sh（dist 重建，仅被 AC 的"还原"步骤间接用到）」。而「比什么、不比什么」被 `CHANGE.md:63,66` 明确列为**开放问题**（「需明确比什么、不比什么」；「未知：是否需要覆盖 vendor… 不覆盖则 vendor 陈旧（本次即发生）不可见」），只有在 DESIGN D3 才定案「vendor 的比对**包含** `test/`」。
**Source（源头）**：需求侧应锁定可验收的判据域（否则 F1「dist 新鲜度门禁」的覆盖面不可判定）；实测反例：`dist/dsh-flow-kit/vendor/flow-kit-bundle/test/test_l3_review_defects_2026_09.bats` **现在就是陈旧的**（见 R2 证据），README 探针永远照不到它。
**Consequence（后果）**：若实现只按 AC-1 的 README 形状做顶层比对，本 change 交付后「vendor 陈旧」这条**已经发生过的**盲区原样保留，而 AC-1/AC-2/AC-7 全绿 → 又是一次"假安全感"（正是本 change 的立论）。同时 tarball（`dist/dsh-flow-kit-0.2.0.tgz`）、`docs/`、`brooks-lint/` 是否纳入也无 AC 约束。
**Remedy（修补）**：把判据域写进 AC 文本（例如 AC-1 增补一列：`lib/`、4 个顶层文件、`skills/`、`flow-kit/`、`hooks/`、`brooks-lint/`、`docs/`、`vendor/flow-kit-bundle/`（含 `test/`）、排除 `*.tgz`），并把 R2 发现的既有陈旧文件作为 AC-1 的第二个探针样本（它现在就该红）。

---

### 🟡 R7 · 「dist 缺失」这一分支没有任何 AC / NFR 覆盖，而它恰恰是**除本机以外所有环境**的默认状态

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:190` 的兼容性只讲「未安装可选**工具**时优雅降级」；AC-1/AC-2 都假设 dist 存在。DESIGN 已定案该分支（`DESIGN.md:136`「dist 不存在 → 提示「请先跑 package-dsh-plugin.sh」→ exit 0（优雅降级）」、`:230` 同），但需求侧既未写该分支，也没有 AC 覆盖它。
**Source（源头）**：`.gitignore:63` `dist/` —— dist 是不入库的本地构建产物；`.git/hooks/pre-push` = `make check`（`test_quality_baseline.bats:82-83` 还断言了这条）。故新克隆、他人机器、任何清洁环境都命中「dist 缺失」分支。
**Consequence（后果）**：两种默认实现各有代价，而需求没有拍板：非零退出 → 新克隆/pre-push 立刻红（噪声化，违反 AC-2 的立意）；静默 exit 0 → 该门禁在最需要它的环境里恒为空转，AC-1 的红/绿语义在别人机器上无法复现（AC-8 的"可复算"承诺也随之打折）。TEST 阶段无判据可依。
**Remedy（修补）**：把 DESIGN 的定案回写到需求侧：NFR「兼容性」补一句「dist 缺失 → 打印跳过原因 + exit 0（沿用 `make dup` 的 jscpd 惯例）」，并新增/扩展一条 AC 断言该分支的输出与退出码（否则这条分支永远无人验）。

---

### 🟡 R8 · NFR「不调用 npm/node」与既定落点冲突：`package-dsh-plugin.sh` 顶层无条件执行 `node -p`

**Severity**：🟡 Important
**Symptom（症状）**：`REQUIREMENT.md:187` 明令新门禁「纯内容比对、不重建、**不调用 npm/node**」；而 DESIGN D2（`DESIGN.md:96`）选择把 `--check` 加进 `package-dsh-plugin.sh`，该脚本 `:19` 在任何分支之前就执行 `VERSION="$(node -p "require('$SRC_DIR/package.json').version" …)"`，且当前**全文没有任何参数解析**（`:20-25` 直接就是 `PKG_DIR` + `rm -rf`）。DESIGN 的取舍表与风险表（R1–R7）都没有处理这条冲突。
**Source（源头）**：需求 NFR 是可验收约束（`REQUIREMENT.md:185-191`），实现载体必须能同时满足；DESIGN §0.5.2「沿用 dist ↔ 源映射表」与 NFR 的"不调用 node"在这条路径上直接对撞。
**Consequence（后果）**：按 D2 直改，`make check-dist` 会（哪怕失败降级）在每次 `make check` 里 fork 一次 node；在无 node 的环境里还会把 `2>/dev/null` 掩盖的噪声带进日志。若为此改成"新建 check-dist.sh"，又违反 D2 的单一事实源理由 —— 冲突必须在设计里显式消解，否则实现阶段才暴露。
**Remedy（修补）**：需求侧把该 NFR 写得更可判（例如「`--check` 分支必须早于任何 `node`/`npm` 调用，可用 `strace`/`PATH` 屏蔽 node 的后置条件验证」），并点名 DESIGN 给出落点（`--check` 分支置于 `:19` 之前，且 `--check` 路径禁用 `rm -rf`/`cp`）。建议把该 NFR 提升为一条 AC（例如「`PATH` 中屏蔽 node 后 `make check-dist` 仍可运行」）。

---

### 🟢 R9 · NFR 性能的理由取证错位：`make check` 由 **pre-push** hook 调用，pre-commit 只跑 `make test`

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:187`「理由：`make check` 被 **pre-commit hook** 调用…」（`CHANGE.md:64`、`DESIGN.md:163/195` 同）。实测：`.claude/hooks/pre-commit/pre-commit.sh:26-27` 只执行 `make test`（`.git/hooks/pre-commit` 是指向它的 symlink），`.git/hooks/pre-push` 才是 `make check`。
**Source（源头）**：`REQUIREMENT.md:145-146` 要求预检/依据可复算 —— 结论正确但依据文件写错，属取证不实。
**Consequence（后果）**：不影响 ≤2s 门槛的成立，但后续若有人据此调整触发场景（例如"反正 pre-commit 会跑全量"）会误判代价。
**Remedy（修补）**：改为「`make check` 由 pre-push hook 调用；pre-commit hook 只跑 `make test`（约 60–120s）」。

---

### 🟢 R10 · AC-5 的 Given 对「5 个告警」的成因描述不完整（实测 = vendor 4 + `.claude/hooks` 1）

**Severity**：🟢 Minor
**Symptom（症状）**：`REQUIREMENT.md:85`（Given「`pre-tool-use/` 下 **4 个**只被 `source` 的库无 exec 位」）与 `:152`（预检「⚠️ **5 个** hook 入口缺可执行位」）不自洽。实测构成（`bash sync-hooks.sh --list | grep 不可执行` 逐条可复算）：
```
1 个：.claude/hooks/pre-tool-use/gate-checks-review.sh
4 个：dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-tool-use/{gate-checks-basic,gate-checks-review,gate-helpers,gate-helpers-types}.sh
```
后 4 个源于 `package-dsh-plugin.sh:54` 的 `chmod +x "$PKG_DIR"/hooks/pre-tool-use/*.sh` **只作用于包顶层**、不管 `vendor/`（与 `LESSONS.md:31`(2026-09-20b)、`HEALTH.md:262` 一致）。
**Source（源头）**：Given 描述的是**源**的健康状态，而门禁判据域是**7 个镜像根**（`sync-hooks.sh:47-55`）—— 同一个域错位的轻微形态（同 R1 根因）。
**Consequence（后果）**：不影响 AC-5 通过（收窄为"仅真入口"后两类都不再计；实测 8 个位置的 pre-commit 与全部真入口均为可执行，AC-5 可达），但实现者按"4 个"理解会漏掉 vendor 侧成因，误判"收窄后仍剩 1 条告警"。
**Remedy（修补）**：Given 补一句「门禁按 7 个镜像根聚合，当前计数 5 = vendor 4（打包 chmod 未覆盖 vendor，见 package-dsh-plugin.sh:54）+ .claude/hooks 1」，并把 vendor 那条登记为已知成因（可选择顺手修打包脚本，或登记 TD）。

---

### 附带核实（已排查、**不构成**发现的锚点）

- **bats 现有断言不会因本次门禁改动而红**：`test/test_quality_baseline.bats:44-71`（只断言 `test:`/`lint:`/`check:` target 存在 + `make lint` 绿）、`test/test_l3_review_defects_2026_09.bats:954-967`（B5-R1 断言 sync-hooks.sh **不含** `chmod` 调用）、B5-R4（用假根 + `sed` 改写，只要求漂移 > 0）—— 逐条读过，均对 F1/F3 的改法不敏感。**但没有任何 bat 断言"lint 扫到了哪些文件"**，故 R4 不能靠现有测试兜底。
- **没有用户文档枚举 `make check` 的门数**：`grep -rn 'check-hooks-sync|check-test-sync|check-validate'`（排除 dist/.specs）只命中 `Makefile` / `sync-hooks.sh` / `verify-claims.sh:165` / bats —— 前两者按 F5 本来就要改，第三者见 R3。
- **AC-7 的其余五个期望值逐条实测属实**：`npx bats test/ --formatter tap` → 950 ok / 0 not ok / 1 skip（exit 0）；`make lint` → error 0；`package-flow-kit.sh --validate` → 「🔴 漏配 (ERROR): 0 / ⚠️ 源缺失 (WARNING): 0」；`make check-test-sync` → 双源一致；`make check-hooks-sync` → 7 个镜像根 ✅、漂移 0。
- **AC-3 的注入判据可复算**：`install.sh` 注入 `if [ 1 -eq 1 ]` 后 `shellcheck -e SC1091` 输出正是 SC1073/SC1050/SC1072 三条 (error)，且 Makefile lint recipe 的 `grep -i error` 会打印 `SC10xx (error)` 行 → AC-3 的正则命中（非恒真）。
- **AC-1 验证脚本的卫生性成立**：探针前后 `dsh-flow-kit/README.md` md5 一致（`bbe391470892c3740487b2d407756d36`），`git status --porcelain` 无新增改动；AC-6 脚本 `cp -p` 复原后权限位回到 775。AC-8 的立意可达成（但 AC-8 自身没有断言"还原后权限位"这一细节，属可接受）。

---

**总体评价**：三条主线（dist 新鲜度 / lint 文件域 / exec 判据）方向明确，5 条预检行属实说明作者确实跑了实验 —— 判据有真实证明力。但**承重的 AC-6 落在判据域之外（不可通过）**，**预检表里 2 行（AC-2、AC-7）与实测相反**，且 AC-7 的期望值需要一处未登记的范围扩张才能达成。这三点都属于「验收线本身站不住」，必须在进入 DESIGN/TEST 前回到阶段 1 修工件（R1–R3 的修补量都不大：改探针/改 Given/改期望值 + 把 verify-claims.sh 纳入范围）。

**Verdict**: fail

---

## 主 agent 响应 · 阶段 1（2026-09-20）

> 主 agent 手写段（协议允许；不转义、不落签名）。对每条 🔴/🟡 给出具体行动。
> 全部 3 条 🔴 经**独立复验成立**，已当场修复。

### 对 🔴 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R1** · AC-6 探针落在判据域之外 | `Fixed in:` REQUIREMENT.md AC-6 / DESIGN.md §5 R9 | ① AC-6 探针改打**镜像副本** `dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh`（复验：打镜像副本计数 5→6，判据**确实看得见**；打源则纹丝不动——你的成因判断正确）；② F3 范围**收敛**为「收窄判据域 + 检出时逐条指名」，**不扩张判据域到源 bundle**（那属未登记的范围扩张）。DESIGN §6 登记该遗留。 |
| **R2** · AC-2 断言 dist 与源一致不实 + 用 git 代理新鲜度（循环论证） | `Fixed in:` REQUIREMENT.md AC-2 / DESIGN.md §5 R11 ＋ 已重建 dist | ① Given 去掉 `git status --porcelain` 代理（你的判断成立：git 对 dist 结构性失明 = 本 change 要堵的盲区，属循环论证）；② **已重建 dist**，复验 `vendor ↔ bundle` **差异 = 0**，Given 现真实成立；③ 该陈旧印证 check-dist 的价值——这是第 2 个独立实例（第 1 个是 README）。 |
| **R3** · verify-claims 基线不实 + 与本 change 强耦合 | `Fixed in:` verify-claims.sh ＋ REQUIREMENT.md AC-7 / v1 **F6** ＋ DESIGN.md §0.5.1/§5 R8 | ① 三处硬编码（`:123` D= / `:137` M= / `:158`）改 `resolve_spec_artifact()`（live 优先 → archive 回退，两者皆无则显式失败）；② `:165`「make check 五门全绿」改为从 `Makefile` 的 `check:` 依赖**动态推导门数**；③ 实测 `bash verify-claims.sh` → **exit 0 · ✅ 13 / ❌ 0**，第 10 项输出「make check 5 门全绿」（F1 加门后自动变 6）。**基线与期望值定稿 13/0**（你抓出的 11/2 属实；我先前推测的"15"是错的）。 |

### 对 🟡 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **R4** · AC-2/AC-4 无命令与期望输出；「4 个」实为 **7** | `Fixed in:` REQUIREMENT.md AC-4 ＋ CHANGE.md 4 处 | ① AC-4 补可执行验证脚本 + **路径级集合差**（显式注释"不得 basename 去重"）；② 枚举表列出**7 个**脚本全路径；③ 复验：66 生产脚本 − 59 已扫 = **7**，与你的计数一致；④ CHANGE.md「漏 4 个」等 4 处已同步为 7。 |
| **R5** · F5（理由注释 / US-4）无 AC 覆盖；F5 漏 `package-dsh-plugin.sh` | `Fixed in:` REQUIREMENT.md v1 F5 | F5 补上 `package-dsh-plugin.sh`（DESIGN D2 的实际载体）；F5 的输出质量由 AC-1/AC-2/AC-6 的**失败信息可定位性**间接覆盖。 |
| **R6** · check-dist 比对域未在需求定案 | `Not-applicable:`（有意分层） | 比对域属**设计层**决策，已由 DESIGN **D3** 定案（含 `vendor/test/`）；需求侧经 AC-1「任一**进入 dist 的**源文件」泛化覆盖，不逐目录列举。 |
| **R7** · 「dist 缺失」分支无 AC/NFR 覆盖 | `Fixed in:` REQUIREMENT.md NFR 兼容性 | 已明确「dist 不存在 → 提示先跑 `package-dsh-plugin.sh` → exit 0 优雅降级」，与既有工具缺失惯例一致。 |
| **R8** · NFR「不调用 npm/node」与 D2 落点冲突 | `Tech-debt:`（约束已收窄，实现待验证） | 约束表述收窄为「`--check` **模式**内不调用」；`package-dsh-plugin.sh:19` 的顶层 `node -p` 需在 `--check` 分流**之前**不进（实现时落实）。已在 §6 登记，TEST 阶段实测确认。 |

### 对 🟢 的响应

- **R9**（NFR 取证错位：`make check` 由 pre-push 而非 pre-commit 调用）→ 已登记 `MINOR-DEFERRED.md` M1。
- **R10**（AC-5 的"5 个告警"成因不完整：vendor 4 + `.claude/hooks` 1）→ 已登记 `MINOR-DEFERRED.md` M2。

### 补充说明

- 你指出的「6 行抽验中 2 行不实」我**全部复验成立**，无异议。
- 你抽验属实的 4 行（AC-1 / AC-3 / AC-5 / AC-6 观察）与 AC-7 其余五项，我也独立复算一致。
- 本响应未改动你的原文判断。

---

## 主 agent 响应 · 阶段 1（对 L3 重审 · 2026-09-20）

> 主 agent 手写段（不转义、不落签名）。L3 的 1 条 Critical + 3 条 Major + 3 条 Minor **全部复验成立**，已逐条修复。

### 对 Critical 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3-C1** · AC-4 验证脚本未含 `pre-commit/*.sh`，且**未实际调用 `make lint`**，而是手工 `ls` 枚举；合法实现会被误判 FAIL，错误实现可能被误判 PASS | `Fixed in:` REQUIREMENT.md AC-4 | **复验成立，且比指控更严重**：我的脚本**照抄了 `Makefile:23` 的 6 条 glob** —— 即**把实现当判据**。两边同样漏 `pre-commit`，`comm -13` 结果为 0，**即使一行不改也会通过**，零证明力。已重构为：① 实现须让 `make lint` 提供机器可读出口（`--list-files` 或 `SCANNED_FILES:` 行）；② 验收命令**只解析该输出**，不复制枚举逻辑。这同时消除 R10 同类风险（计数一律从实现对外的单一出口读）。 |

### 对 Major 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3-M1** · AC-5 未检查退出码 0，且管道掩盖 `make` 的返回码 → 非零退出但无该告警时**假通过** | `Fixed in:` REQUIREMENT.md AC-5 | 改为先落盘再分别断言：`make check-hooks-sync >/tmp/ac5.log 2>&1; rc=$?`，先断 `rc=0`，再断告警计数为 0。 |
| **L3-M2** · AC-2 无可复制命令（仅文字描述），Given 未给"如何确认 dist 已重建" | `Fixed in:` REQUIREMENT.md AC-2 | 补完整脚本：先 `diff -rq` 断言 Given（dist 与源一致），再 `make check` 断退出码 0 与 check-dist 通过标记。 |
| **L3-M3** · F5 在 v1 必做清单却**无对应 AC**，交付物不可验收 | `Fixed in:` REQUIREMENT.md **新增 AC-9** | 新增 AC-9：用本 change 独有的锚点 `health-fix-2026-09` 断言三载体（`Makefile` / `sync-hooks.sh` / `package-dsh-plugin.sh`）均含**可追溯的理由注释**。用 change-id 作锚优于数注释条数（既有文件已含大量注释），且天然满足"指向具体判据来源"。 |

### 对 Minor 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3-m1** · AC-1/AC-3/AC-6 脚本未断言 Given 前置 | `Fixed in:` REQUIREMENT.md 三个脚本 | 各加前置断言：AC-1 先断基线 `make check` 全绿；AC-3 先断基线 `make lint` 全绿；AC-6 先断基线无 exec 告警（即 AC-5 已达成）。 |
| **L3-m2** · AC-8 未定义"执行哪些 AC 脚本" | `Fixed in:` REQUIREMENT.md AC-8 | 明确为：依次执行 **AC-1 / AC-3 / AC-4 / AC-5 / AC-6**（注入类）后断言工作区干净；AC-2 / AC-7 为只读命令，不注入改动。 |
| **L3-m3** · NFR 性能缺测量方法与环境基线 | `Fixed in:` REQUIREMENT.md NFR 性能 | 补：`time make check-dist` 取 3 次中位数；夹具与环境基线明确；参考实测 13ms。**并更正取证错位** —— `make check` 由 pre-push 而非 pre-commit 调用（M1 登记）。 |

### 补充说明

- 本轮 AC 从 8 条增至 **9 条**（新增 AC-9）；7 个内嵌验证脚本经 `bash -n` 全部通过。
- 我未改动 L2 与 L3 的原文判断。

---

## 主 agent 响应 · 阶段 1（对 L3 重审二轮 · 2026-09-20）

> 主 agent 手写段。L3 二轮的 3 Major + 4 Minor **全部复验成立**，已逐条修复。**其中 M1 是我上一轮修复时新引入的缺陷** —— 如实记录。

### 对 Major 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3B-M1** · `make lint --list-files` **不是合法 make 调用**（会被当作 target 名）；且与正文出口描述二义 | `Fixed in:` REQUIREMENT.md AC-4 | 复验成立，**且这是我在上一轮"修 AC-4"时新引入的**：为消除"复制实现"，我写死了一个跑不通的命令。**已定案方案 (b)**：`make lint` 正常运行即固定输出 `SCANNED_FILES: <n>` + 逐行路径，**不新增独立 target**；AC-4 脚本改 `make lint` + `grep '^SCANNED_FILES:'`，并在正文显式加"不得使用 `--list-files` 形式"的禁止说明。全文已无 `--list-files` 残留。 |
| **L3B-M2** · AC-6 前置未确认 dist 新鲜 / 镜像副本存在 → 承重性证明不可信 | `Fixed in:` REQUIREMENT.md AC-6 | 前置补两条：① `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle` 断 dist 与源一致；② `[ -f "$F" ]` 断镜像副本存在。这样能区分"检测力缺失"与"dist 陈旧/文件不存在"。 |
| **L3B-M3** · AC-7 断言无命令、未说明精确相等还是下限；hooks-sync 的"漂移 0"缺断言写法 | `Fixed in:` REQUIREMENT.md AC-7 | 补完整脚本：bats 用 `grep -cE '^ok '` 等**精确相等**断言（950/0/1）；validate 断 `漏配 (ERROR): 0` 与 `源缺失 (WARNING): 0`；hooks-sync 断 `漂移 0`；verify-claims 断 `复验结果: ✅ 13  ❌ 0`。并**显式声明基线为精确相等**，TEST 阶段合法增删用例须回写本 AC。 |

### 对 Minor 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3B-m1** · AC-3 断言过度绑定 shellcheck 诊断码（`SC10xx`） | `Fixed in:` REQUIREMENT.md AC-3 | 放宽为 `grep -qiE 'error'`（保留 `install.sh` 文件名断言），并注明"不绑定特定 SC 码 —— 版本升级/注入形态变化不应使 AC 误红"。 |
| **L3B-m2** · AC-4 未定义「生产 `.sh`」集合规则，排除列表即判据却无理由 | `Fixed in:` REQUIREMENT.md **新增 AC-4b** | 新增 AC-4b：把 6 类排除项（`.git`/`node_modules`/第三方 / `dist` / `.omo`·`.claude` / `.specs` / `test`）逐条给出理由，并**声明该列表是契约**（实现者不得自行增删以"凑绿"）。 |
| **L3B-m3** · AC-8 未界定副作用来源；`cp -p` 还原不保证权限/mtime | `Fixed in:` REQUIREMENT.md AC-8 + AC-1/3/6 脚本 | ① AC-8 改为**执行前先记基线、执行后逐行 diff**（不只看"最终是否干净"）；② AC-1/3/6 的还原由 `cp` 备份**统一改为 `git checkout -- <file>`**（内容与权限一并复原）；③ 要求验证脚本落到 `.specs/<id>/verify/acN.sh`。 |
| **L3B-m4** · CHANGE.md 验收线"改一处源"与 AC-1 口径不一致 | `Fixed in:` CHANGE.md 验收线 1 | 改为「改任一**进入 dist 的源文件**（以 `package-dsh-plugin.sh` 实际打包域为准，至少含 `dsh-flow-kit/README.md`）」，并指向 AC-1。 |

### 补充说明

- AC 由 9 条增至 **10 条**（新增 AC-4b）；9 个内嵌验证脚本经 `bash -n` 全部通过。
- **自我批评**：上一轮我"修 AC-4"时引入了 M1（不可执行的 make 调用）。根因是**只想着消除"复制实现"，没有实际跑一遍那条命令**。教训已记入 LESSONS：*AC 脚本在写进需求前必须真跑一次* —— 与本 change 已有的"AC 预检"纪律同源，但我这次只预检了旧脚本、没预检新写的。
- 我未改动 L2 与 L3 的原文判断。

---

## L3 重审（deepseek-v4-flash-0731 外部模型 · 2026-09-20 20:39）

> 自动生成于 2026-09-20 20:39。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "REQUIREMENT.md AC-4 验证脚本",
      "issue": "AC-4 的验证脚本在基准侧使用 find 构造『全部生产 .sh』集合，但 AC-4b 声明该 find 排除列表是契约；若实现为凑绿而扩展排除项（例如新增 -not -path '*/legacy/*'），AC-4 验证仍会通过，且没有任何机制强制实现必须回到 AC-4b 修改。",
      "why": "验收脚本与契约表之间没有绑定的单一事实源。AC-4b 说『不得在实现中静默调整』，但脚本本身只核对排除项是否与当前 find 一致，无法检测实现是否在 find 之外新增了其他绕过方式；更关键的是，脚本的 find 排除列表同时出现在判据和被测实现中，验证者无法区分『扫描面扩大』与『排除项被静默扩大』。这不是纯逻辑缺陷，但它是本 AC 验证力度的空白。",
      "fix": "在 AC-4 验证脚本中，将 find 的排除列表提取为固定字符串，与 AC-4b 表格逐项比对，并在脚本注释中声明『本排除列表是契约，任何增删必须回到 REQUIREMENT.md 修改』；同时增加一条断言：make lint 输出的 SCANNED_FILES 中不得包含任何被排除的路径（防止实现用排除路径规避清单）。"
    }
  ],
  "major": [
    {
      "file": "REQUIREMENT.md AC-1 验证脚本",
      "issue": "AC-1 的 Given 要求『make check 全绿』，但 AC-1 验证脚本没有先确认 AC-2 的 Given（dist 与源一致）成立；若 dist 已经陈旧，基线 make check 可能已经通过（因为 check-dist 尚未实现），导致 AC-1 验证在错误的前置下执行。",
      "why": "AC-1 验证脚本以『make check 全绿』为前置，但当前 make check 并不包含 check-dist，因此即使 dist 陈旧，make check 也可能绿。AC-1 的 Then 要求在修改源文件后 make check 非零，但若 dist 已经陈旧且 check-dist 尚未加入，则基线本来就该红，验证结果无法区分『门禁生效』与『基线已红』。这削弱了 AC-1 的证明力。",
      "fix": "在 AC-1 验证脚本的前置中增加 `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null` 确认 dist 与源一致，否则提示先重建 dist；或者将前置改为『AC-2 的前置已满足』，并在脚本中实际执行该检查。"
    },
    {
      "file": "REQUIREMENT.md AC-7 验证脚本 ⑥",
      "issue": "AC-7 的 verify-claims 断言使用精确字符串『复验结果: ✅ 13  ❌ 0』，但 AC-7 修正记录中已说明 F6 将 make check 门数从『5 门』改为动态推导，且 F1 会新增 check-dist 使门数变为 6。脚本第⑥条没有验证输出中的门数是否为动态推导值，也没有验证 verify-claims.sh 自身是否已修复。",
      "why": "AC-7 是 F4 的验收，若 verify-claims.sh 未修复（仍硬编码 5 门），但输出恰巧包含『✅ 13 ❌ 0』（例如修复了路径但未改门数断言），则 AC-7 会通过而 F6(b) 未完成。精确字符串只验证了计数，未验证修复内容。",
      "fix": "在 AC-7 ⑥ 中增加断言：输出中不包含『5 门』字样，或包含『6 门』字样（根据 F1 加门后动态推导的结果）；或者直接检查 verify-claims.sh 中不存在硬编码的『5 门』字符串。"
    },
    {
      "file": "REQUIREMENT.md AC-6 验证脚本 trap",
      "issue": "AC-6 验证脚本对镜像副本执行 `trap 'git checkout -- \"$F\"' EXIT`，但镜像副本位于 dist/ 下，而 dist/ 被 .gitignore 忽略（AC-2 修正记录已指出 git 对 dist 结构性失明）。git checkout 无法还原 dist/ 下被忽略文件的权限位。",
      "why": "AC-6 的 trap 依赖 git checkout 还原权限，但被 gitignore 的文件不在 Git 跟踪范围内，git checkout 对它们无效。若验证中途失败（例如 grep 失败退出），镜像副本的 exec 位将被永久移除，违反 AC-8 要求，并可能污染后续验证。",
      "fix": "改用显式保存和恢复权限：验证前 `orig_mode=$(stat -c %a \"$F\")`，EXIT 时 `chmod \"$orig_mode\" \"$F\"`；或者将镜像副本排除在 gitignore 之外（不现实），或在验证脚本中先备份整个 dist 目录。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT.md AC-5 验证脚本",
      "issue": "AC-5 验证脚本断言『不含缺可执行位告警』，但 M2 指出基线告警含 .claude/hooks 1 个；AC-5 的 Given 只描述 pre-tool-use 下的 4 个库与 3 个入口，未涵盖 .claude/hooks 的来源。",
      "why": "若修复后 .claude/hooks 的告警仍存在（它不在 pre-tool-use 判据域内），AC-5 会失败，但这不是本 change 要修的判据过宽问题；验证脚本没有区分这两类来源，可能导致实现被迫扩张范围才能让 AC-5 通过。",
      "fix": "在 AC-5 验证脚本中将告警来源限定为 pre-tool-use（如只统计含 pre-tool-use 的告警行），或明确 AC-5 的 Then 只针对 pre-tool-use 判据域内的告警。"
    },
    {
      "file": "REQUIREMENT.md AC-7 验证脚本 ⑤",
      "issue": "AC-7 ⑤ 用 `grep -qE '漂移 0'` 断言 check-hooks-sync 漂移为 0，但 AC-5/AC-6 的修复涉及 exec 告警，check-hooks-sync 的输出格式可能不止包含『漂移 0』，还可能有 exec 告警行。",
      "why": "若 F3 实施后 check-hooks-sync 在漂移为 0 但仍有其他告警（如 advisory exec 告警）时退出 0，AC-7 ⑤ 的 grep 仍然通过，未验证 exec 告警是否已按 AC-5 归零；但 AC-7 是 F4 全量回归，应确保 F3 的最终状态也符合 AC-5/AC-6。",
      "fix": "在 AC-7 ⑤ 中同时断言输出中不含 exec 相关告警（或增加对 AC-5 输出格式的检查），避免 F4 只验证漂移而漏掉 F3 的副作用。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-4 验证脚本的 find 排除列表与 AC-4b 契约之间缺乏绑定，实现可通过静默扩排除项使集合差恒为 0；AC-1 前置未验证 dist 一致性、AC-6 的 git checkout 对被 gitignore 的 dist 镜像副本无效，这两条直接削弱承重性 AC 的可验证性；须修正后在 v1 范围内重新审查。"
}
```

L3_artifact_hash: 7c4f0c1576a528b89c0c9d9ce8be625fc0084f5cd27437cb4e07d6e8fcb1aa7a

<!-- /L3-SECTION -->

---

## 主 agent 响应 · 阶段 1（对 L3 重审三轮 · 2026-09-20）

> 主 agent 手写段。L3 三轮的 1 Critical + 3 Major + 2 Minor **全部复验成立**，已逐条修复。

### 对 Critical 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3C-C1** · AC-4 的 `find` 排除列表与 AC-4b 契约**缺乏绑定** —— 实现可静默扩排除项（如加 `-not -path '*/legacy/*'`）使集合差恒为 0，判据被架空 | `Fixed in:` REQUIREMENT.md **新增 AC-4c** | 复验成立：我只把列表**声明**为契约，**无任何强制机制**。新增 AC-4c 用恒等式补强：**`扫描集 ∪ 契约排除集 == 全仓可发现 .sh 集`** —— 实现若偷加排除项，那些文件会**同时缺席**两者 → 并集出现缺口 → 立即失败。这是 AC-4 单独做不到的检测。 |

### 对 Major 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3C-M1** · AC-1 前置未确认 dist 与源一致（若 dist 陈旧，基线 `make check` 仍可能通过） | `Fixed in:` REQUIREMENT.md AC-1 | 前置补 `diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle`，与 AC-2 的 Given 对齐后再断 `make check` 全绿。 |
| **L3C-M2** · AC-7 ⑥ 未验证 `verify-claims.sh` 自身是否已修复、也未验门数是否动态推导 | `Fixed in:` REQUIREMENT.md AC-7 ⑥ | 补三条断言：① 不应再出现 `§0.5.1 未列`（证 F6(a) 生效）；② 须出现 `make check [0-9]+ 门全绿`（证 F6(b) 动态推导生效）；③ **不得**再出现写死的「五门」。 |
| **L3C-M3** · AC-6 用 `git checkout` 还原 `dist/` 下副本 —— **dist 被 gitignore，git checkout 无效** | `Fixed in:` REQUIREMENT.md AC-6 | **已实测确认你的判断**：`git checkout -- dist/...` 报 `路径规格未匹配任何 git 已知文件`，且**权限位未还原**（仍 `-rw-r--r--`）。已改为 `trap 'chmod +x "$F"' EXIT`。并把三类还原点按目标是否被跟踪做了区分（AC-1/AC-3 目标被跟踪 → `git checkout`；AC-6 目标被忽略 → `chmod`）。 |

### 对 Minor 的响应

| Finding | 分类 | 具体行动 |
|---|---|---|
| **L3C-m1** · AC-5 的 Given 未涵盖 `.claude/hooks` 那 1 个告警来源 | `Fixed in:` REQUIREMENT.md AC-5 | Given 明确"基线共 **5** 处告警 = `pre-tool-use/` 4 个库 + `.claude/hooks` 1 个"，并要求**全部 5 处归零**（而非只管 `pre-tool-use/`）。 |
| **L3C-m2** · AC-7 ⑤ 的 `grep -qE '漂移 0'` 可能不足以区分漂移行与 exec 告警行 | `Accepted-risk:`（保持现状，理由如下） | `check-hooks-sync` 的漂移行与 exec 告警行**格式不同**（前者 `✅ ... hooks 副本一致（漂移 0）`，后者 `⚠️ N 个 hook 入口缺可执行位`）。AC-5 已独立断言 exec 告警归零；AC-7 ⑤ 只断漂移。若 TEST 阶段实测输出格式有歧义，再收紧为行首锚定断言并回写本 AC。 |

### 补充说明

- AC 由 10 条增至 **11 条**（新增 AC-4c）；10 个内嵌验证脚本经 `bash -n` 全部通过。
- **轨迹自评（供人工判断是否继续迭代）**：三轮 L3 的发现数 8 → 7 → 6，**趋势趋于收敛但不单调下降**（三轮各出现 1 条 Critical/Major 级别的新面）。但发现对象已从"工件本身"（一轮：AC 探针域、基线不实）转向"**验证脚本的元缺陷**"（二轮：命令不合法；三轮：契约未绑定、还原方式失效）。
- 我认为这三轮的收获是真实的（尤其三轮的 AC-4c：它补上了一个"看起来验了、实际没验"的结构性漏洞），但也如实指出：**继续让 L3 审"验证脚本的验证"存在边际递减风险**——若人工判断已足够，可清理 `.l3-attempts-1` 回到 `.done` 产出路径，或直接进入阶段 3。
- 我未改动 L2 与 L3 的原文判断。

---

## L3 重审（bypass · 2026-09-20 20:48）

> **熔断触发**：本阶段外部模型 L3 已连续 3 次返回 fail 且未收敛
> （阈值来源：stop-hook.json 的 independent_review.max_failures_before_bypass）。
> 按 ADR-005 降级路径结案：写入 .done 且 L3_verdict=skipped，pipeline 继续推进。
> 本段即审计痕迹——不伪装 L3 pass，人工可据此复核。
> 清理计数：删除 `.l3-attempts-1` 即可重新尝试 L3。

<!-- /L3-SECTION -->