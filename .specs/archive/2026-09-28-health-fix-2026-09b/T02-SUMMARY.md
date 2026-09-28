# T02-SUMMARY — `.change-base` 变更起点锚点落档（4-dev 首步 + 入库）

- **Change**: `health-fix-2026-09b` · **任务**: T02（Wave 1，`parallel="true"`，`model-tier="cheap"`）
- **状态**: DONE
- **commit sha**: 见 `.flow-active` 的 `goal.task_progress[]` 中 `id="T02"` 的 `commit_sha`（**权威源**）。本文件被包含在该次提交内 ⇒ 按 **L-126 ③**「提交内容不可能写下自己的最终 sha」不在此处写死自身 sha。

## 任务目标

在任何修改之前，把**本 change 的变更起点锚点**落档为 `.specs/health-fix-2026-09b/.change-base`（单行、无注释）并 `git add` 入库，作为 AC-8 / NFR 兼容性判据（`git diff <BASE> -- '*.sh'` 界定「新增行 + 新文件」）的锚点前提；渠道优先级 = `FLOW_KIT_CHANGE_BASE` > 落档文件 > fail-closed（DESIGN §9.2）。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| `.specs/health-fix-2026-09b/.change-base` | 新增（**write_files 声明项**） | 单行 `534e3e842fc900045f39492badc66eabe3ffd4c4` + 1 个尾随 `\n`，共 **41 字节**（`od -c` 实证，见下）；无注释、无尾随文本 |
| `.specs/health-fix-2026-09b/TASK.md` | 修改（流程性产物） | T02 的 `status="pending"` → `status="done"`（commit-protocol「标记完成」） |
| `.specs/health-fix-2026-09b/T02-SUMMARY.md` | 新增（流程性产物） | 本文件（commit-protocol「写 SUMMARY」） |
| `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` | 修改（流程性产物） | 追加「阶段 4 · T02」🟢 登记（本任务指令「🟢 入 MINOR-DEFERRED.md」的直接要求） |

**未改动**：`REQUIREMENT.md` / `DESIGN.md`（R3.2）；未 `git add -A/-u/-a`；工作区既有的 `.specs/CONTEXT.md` / `.specs/STATE.md` / `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` 三处改动**未被本任务触碰、也未被暂存**（非本任务范围）。

## `<verify>` 命令与真实输出（逐字实跑）

### 前置态（文件尚未创建）—— 复现 `<done>` 所称「修复前实测：文件不存在 ⇒ rc=1」

```bash
$ B=.specs/health-fix-2026-09b/.change-base;
  test -s "$B" || { echo "🔴 锚点文件缺失或为空"; exit 1; };
  git cat-file -e "$(cat "$B")^{commit}" 2>/dev/null || { echo "🔴 锚点不是有效 commit: $(cat "$B")"; exit 1; };
  git ls-files --error-unmatch "$B" >/dev/null 2>&1 || { echo "🔴 锚点未入库（未 git add）"; exit 1; }
```

```
🔴 锚点文件缺失或为空
[exit code: 1]
```

### 后置态（`.change-base` 已写入并 `git add`）—— 逐字原样实跑

```bash
$ B=.specs/health-fix-2026-09b/.change-base;
  test -s "$B" || { echo "🔴 锚点文件缺失或为空"; exit 1; };
  git cat-file -e "$(cat "$B")^{commit}" 2>/dev/null || { echo "🔴 锚点不是有效 commit: $(cat "$B")"; exit 1; };
  git ls-files --error-unmatch "$B" >/dev/null 2>&1 || { echo "🔴 锚点未入库（未 git add）"; exit 1; }
```

```
A: PASS（无失败输出 = 三条断言全过）rc=0
```

**同一判据逐条带标记复跑**（L-121 ①：成功态判据静默 ⇒ 无可观测证据；故逐条加自证输出，命令与原判据逐字同构）：

```
✅ B1 test -s "$B"      ⇒ rc=0（文件非空，41 字节）
✅ B2 git cat-file -e ⇒ rc=0（534e3e842fc900045f39492badc66eabe3ffd4c4 是有效 commit）
✅ B3 git ls-files --error-unmatch ⇒ rc=0（已入库）
```

**字节级取证**（L-120 ②「原语探测」而非文案匹配；确认无尾随文本/注释）：

```
$ od -c .specs/health-fix-2026-09b/.change-base
0000000   5   3   4   e   3   e   8   4   2   f   c   9   0   0   0   4
0000020   5   f   3   9   4   9   2   b   a   d   c   6   6   e   a   b
0000040   e   3   f   f   d   4   c   4  \n
0000051
$ wc -l -c .specs/health-fix-2026-09b/.change-base
 1 41 .specs/health-fix-2026-09b/.change-base
```

## 特别约束 1 实测：锚点取「变更前基线」而非裸 `HEAD`

**该约束与任务 XML 的 `<action>` 冲突，已按主 agent 裁定执行"取变更前基线"**，理由见「对任务 XML `<action>` 的偏离」段。

```bash
$ cat .specs/health-fix-2026-09b/.change-base
534e3e842fc900045f39492badc66eabe3ffd4c4
$ git rev-parse HEAD
ab44f36302059c54e37b61c101432ecf69b3fd93
```

```
✅ C2 落档值 == 指定基线 534e3e8…
✅ C3 落档值 ≠ HEAD（未用裸 HEAD）
✅ C4 基线是 HEAD 的祖先（rc=0）
```

基线 commit 元信息（`git log -1 534e3e8`）：`534e3e8 2026-09-22 chore(privacy-path-scrub-2026-09): develop 全历史重写（含已推送）+ 引用修复与补档`；`git rev-list --count 534e3e8..HEAD` = **2**（`a674c56` T01 正文提交、`ab44f36` T01 复核订正）。

### 选「变更前基线」的判别力取证（同代码路径、双锚点对照）

```bash
$ git -c core.quotepath=false diff -U0 <BASE> --name-only | sort   # 与 REQUIREMENT:536 / AC-8 同代码路径
$ git -c core.quotepath=false diff -U0 HEAD  --name-only | sort
```

```
BASE=534e3e842fc900045f39492badc66eabe3ffd4c4       变更文件数=9
BASE=HEAD(ab44f36)        变更文件数=4
--- 仅基线可见（HEAD 锚点漏掉的**已提交**文件）---
.specs/health-fix-2026-09b/DESIGN.md
.specs/health-fix-2026-09b/MINOR-DEFERRED.md
.specs/health-fix-2026-09b/T01-SUMMARY.md
.specs/health-fix-2026-09b/TASK.md
.specs/LESSONS.md
```

**测量边界（如实登记，不夸大）**：`<verify>`/NFR 实际过滤面是 `-- '*.sh'`，而本 change 迄今**已提交的 0 个 `.sh` 变更**（上列 5 个仅基线可见的文件全为 `.md`/归档面）。故当前时点两锚点在 `*.sh` 面上取值**相同**：

```
  BASE=534e3e842fc900045f39492badc66eabe3ffd4c4  ADDED(sh)=31 行
  BASE=HEAD                                      ADDED(sh)=31 行
```

该 31 行同源于工作区未提交的 `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` 改动 —— 无论锚点取哪个，未提交改动都计入。**「锚点取基线」的分化效应将在 T03+ 提交 `.sh` 变更后出现**：届时 `git diff HEAD -- '*.sh'` 对这些已提交改动恒空（⇒ 判据静默空转假绿），而 `git diff <基线> -- '*.sh'` 仍持有它们。上列 F1b 的 5 个文件即为该机制的**已发生实例**（T01 的两次提交对 `HEAD` 锚点已不可见，对基线锚点仍可见）。

**NFR 判据的 SKIP 分支取值**（`ADDED` 与 `NEWF` 同时为空才 `rc=3` SKIP）：

```
  ⇒ 非空 ⇒ 判据真跑（不 SKIP）：ADDED=31 行 / NEWF=0 文件
```

## 特别约束 2 实测：锚点处本 change 目录不存在

```bash
$ git cat-file -e 534e3e842fc900045f39492badc66eabe3ffd4c4^{commit}; echo "rc=$?"
$ git ls-tree -r --name-only 534e3e842fc900045f39492badc66eabe3ffd4c4 | grep -c '^\.specs/health-fix-2026-09b/'
```

```
D1 git cat-file -e 534e3e8^{commit} ⇒ rc=0（期望 0）
D2 git ls-tree -r --name-only 534e3e8 | grep -c '^\.specs/health-fix-2026-09b/' ⇒ 0（期望 0）
✅ D2 锚点处本 change 目录不存在 ⇒ 锚点确为变更前的树
```

（`grep -c` 无匹配时自身 `rc=1`，故 D2 用命令替换取值再断言 `-eq 0`，不以 `grep` 退出码当结论 —— 对齐 L-121 ②「空集是一等失败态」。）

## 补充：消费端锚点解析**三态 fixture** 实测（L-120 ①「判据必须双态可区分」，此处实测三态）

判据原文口径 = REQUIREMENT 的 `BASE="${FLOW_KIT_CHANGE_BASE:-$(cat .specs/…/.change-base 2>/dev/null || true)}"`（DESIGN §9.2 渠道优先级）：

```
--- E1 成功态·渠道1：FLOW_KIT_CHANGE_BASE 已设（须压过落档文件）---
BASE=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
✅ E1 环境变量优先
--- E2 成功态·渠道2：环境变量未设 ⇒ 读落档文件 ---
BASE=534e3e842fc900045f39492badc66eabe3ffd4c4
✅ E2 落档文件被采纳
--- E3 失败态·渠道3：两者皆缺（/tmp 空目录 + env 未设）⇒ 必须 fail-closed rc=1 ---
🔴 变更起点 SHA 未落档
E3 rc=1
```

三态**互相可区分**（渠道 1 覆盖渠道 2；渠道 3 不复用渠道 2 的值而 fail-closed），且 E3 在 `mktemp -d` 的隔离目录中执行，未触碰真实仓文件。

## 对任务 XML `<action>` 的偏离（必须披露）

- T02 的 `<action>` 原文要求：**在没有任何修改之前**执行 `git rev-parse HEAD`，把该 40 位 SHA 写入 `.change-base`。
- **实际执行**：写入的是 `534e3e842fc900045f39492badc66eabe3ffd4c4`（本 change 的变更前基线），**不是**当时的 `git rev-parse HEAD` = `ab44f36302059c54e37b61c101432ecf69b3fd93`。
- **依据与理由**（主 agent 裁定，且与 T02 自身 `<action>` 末句「**不得**用裸 `HEAD` 充当锚点」一致）：`HEAD` 在本 change 期间会随每个任务的提交前移；一旦某任务提交了 `.sh` 变更，`git diff HEAD -- '*.sh'` 对这些改动恒空 ⇒ 正是 `<action>` 自己警告的「判据静默空转」。取**变更前的树**作锚点，才能让 NFR 判据在整个 change 生命周期内持续覆盖本 change 自身的全部新增 shell 行。AC-8 的 `BASE8`（REQUIREMENT:445）与 NFR 的 `BASE`（REQUIREMENT:531）读的**同一个** `.change-base`，且 AC-8 守卫注释明确要求「**必须与 A 案同锚点**，否则……增量提交后会假红且**归因相反**」。
- **未修改 `TASK.md` 的 `<action>` 正文**（不越界改阶段 3 工件正文）；该口径不一致已登记 `MINOR-DEFERRED.md`。

## 6 维自查结果（内置 R1~R6 快查 · brooks-lint 未安装）

| 维度 | 结论 | 依据 |
|---|---|---|
| R1 认知过载 | 🟢 | 产物为 1 行 41 字节；无函数/嵌套；判据 3 条各 1 行 |
| R2 变更传播 | 🟢 | 仅 4 个文件（1 声明 + 3 流程性）；未触碰工作区既有的 3 处未提交改动 |
| R3 知识重复 | 🟢 | 未复制任何逻辑；判据文本零粘贴；锚点值只有单一源（`.change-base`），消费端只读不复制 |
| R4 偶然复杂 | 🟢 | 未引入抽象/helper/扩展点；未新增任何脚本或 Makefile 目标（`check-nfr-portability` 属后续 task） |
| R5 依赖混乱 | 🟢 | 无 import/依赖变更；未新增外部依赖 |
| R6 领域扭曲 | 🟢 | 术语沿用既有（锚点 / 变更起点 / fail-closed）；未自造词 |

**计数：🔴 0 · 🟡 0 · 🟢 6。** 处置：🔴/🟡 无；🟢 中 **2 条有记录价值的条目已写入 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` 的「阶段 4 · T02」段**（① TASK.md `<action>` 口径与 AC-8 口径不一致；② 「锚点判别力」对 `*.sh` 面在当前时点尚未分化的证据边界）。其余 4 条为「无代码改动」的必然结果，无待办动作。

### 沿用既有抽象 grep（R6.4 · 强制作证）

```
✅ 沿用既有抽象 grep（R6.4）：
- 「变更起点锚点 / FLOW_KIT_CHANGE_BASE / .change-base」在**本 change 设计工件之外**全仓命中 **0**
  （grep -rn 'FLOW_KIT_CHANGE_BASE\|\.change-base' --exclude-dir=.git --exclude-dir=node_modules . ，
   排除 .specs/health-fix-2026-09b/{DESIGN,REQUIREMENT,TASK,CHANGE,INDEPENDENT-*} 后命中数 = 0）
  ⇒ 仓内**无同类既有抽象可直接沿用**，该机制按 DESIGN §9.2 属**新引入**的项目级决策（非重复实现），
    与 O.5.2「本次需要 / 既有有没有」对照表的结论一致。
- 落档工件的**位置与形态先例**（沿用，非新起）：`.specs/<id>/` 下放点文件级过程产物 —— 既有实例
  `.specs/health-fix-2026-09b/.goal-snapshot.json`（CONTEXT.md 禁动清单亦收录该载体）、
  `.specs/<id>/.independent-review-<N>.done`、`.specs/<id>/.done`（凭证类）。
  ⇒ 本任务只新增一个同族点文件，不改变目录约定。
- 「判据读序 = 环境变量 > 落档文件 > fail-closed」：与仓内既有 `gate_config` 读取（`.flow-active` 权威 +
  snapshot 副本）同族的「落档优先、缺失即 fail-closed」口径，未自造第三种读序。
```

## 越界检查（R6.5）

```
✅ 越界检查（R6.5）：
  - TASK write_files 声明：1 项（.specs/health-fix-2026-09b/.change-base）
  - 实际 diff 涉及：4 项
      1. .specs/health-fix-2026-09b/.change-base     ← write_files 内
      2. .specs/health-fix-2026-09b/T02-SUMMARY.md   ← commit-protocol「写 SUMMARY」强制
      3. .specs/health-fix-2026-09b/TASK.md          ← commit-protocol「标记完成」强制（仅 status 字段）
      4. .specs/health-fix-2026-09b/MINOR-DEFERRED.md← 本任务指令「🟢 入 MINOR-DEFERRED.md」强制
  - 越界（业务/生产代码）：0
  - 未纳入本次提交（工作区既有、属其他任务范围）：.specs/CONTEXT.md、.specs/STATE.md、
      flow-kit-bundle/hooks/stop/lib/l3-prompt.sh、.specs/adr/028-*.md、
      .specs/health-fix-2026-09b/{CHANGE,REQUIREMENT,INDEPENDENT-REVIEW-1..3}.md、.specs/health/2026-09-22-FULL-SWEEP.md
  - 暂存面自证：git diff --cached --name-only 只列出上述 4 个文件，未使用 -A/-u/-a
```

同时**未触碰 DESIGN 0.5.1 禁动清单**中的任何路径（`flow-kit-bundle/hooks/stop/**`、`brooks-lint/**`、`pipeline-gates.md`、`INDEPENDENT-REVIEW-1.md`、`skills/**`）。注：工作区存在 `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` 的**他人未提交改动**（DESIGN 0.5.1 已登记为本 change 范围），本任务既未修改也未暂存它。

## TDD 适用性说明（显式声明理由）

**TDD 不适用 —— 纯落档类任务，无可测行为。** 理由：本任务的产物是一个**一行 SHA 文本文件**（配置/工件），不含任何可执行逻辑、分支或接口；仓内 `test/` 与 `flow-kit-bundle/test/` 对本 change 目录命中 **0**（`grep -rn 'health-fix-2026-09b' test/ flow-kit-bundle/test/` 命中 0），对 `.change-base` / `FLOW_KIT_CHANGE_BASE` 命中 **0**（`grep -rn 'change-base\|change_base\|FLOW_KIT_CHANGE_BASE' test/ flow-kit-bundle/test/ Makefile` 命中 0）⇒ 本任务尚无可挂载的 bats 载体（承载它的 `check-nfr-portability` 与对应测试属后续 task）。因此以**判据真跑替代 TDD**，并按 L-120 ① 做**双态（前置 rc=1 / 后置 rc=0）对照**与**三态 fixture**（渠道优先级 + fail-closed），而非仅「跑一次不报错」。

## 破坏性变更协议（R4.6）

不适用 —— 未删除 ≥5 行代码、未改公共接口/导出/API、未删文件；仅新增 1 个 41 字节工件 + 流程性文件状态勾选。**无需** 1.8 协议。

## 数据库 Schema / 变更（R4.5 / 1.7）

不适用 —— 无 schema、无迁移。

## 遗留 / 移交项

- **移交给后续 task（T03+）**：新增 `.sh` 文件/行后无需任何操作，`.change-base` 已就位；但**承载判据的 `check-nfr-portability` 目标与 AC-8 包装尚未存在**（`Makefile:106` 现为 `check: test lint check-validate check-test-sync check-hooks-sync check-dist`，实测无 `check-nfr-portability`）—— 落地时须遵守 REQUIREMENT 的**自命中风险**约束（判据放在不受自身扫描的位置，如 Makefile recipe）与 `rc=3` 只以 `if` 包装接入（DESIGN §9.3）。
- **移交给 7-integration（归档）**：本 change 归档后 `.change-base` 随目录迁走 ⇒ NFR 判据进入 `rc=3 SKIP` **属预期态**（DESIGN §9.3 已显式排除「对裸仓断言无 SKIP」的写法），不是缺陷。
- **移交给主 agent**：本任务 commit sha 需在提交后由 `.flow-active.goal.task_progress[]`（`id="T02"`）读取；如需写进本 SUMMARY，请按 T01 先例在后续提交中补记（L-126 ③）。
- **无代码层面遗留**；未使用「应该可以工作」表述（R6.3），未 mock 任何失败、未放宽任何断言（R5.2），未绕过任何提交门禁（L-126 ②）。
