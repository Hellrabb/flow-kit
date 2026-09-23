# T03-SUMMARY — ADR-022 追加 `Superseded-by`（**部分**：新增 `pre-push` 注入）

- **Change**: `health-fix-2026-09b` · **任务**: T03（Wave 1，`parallel="true"`，`model-tier="cheap"`）
- **状态**: DONE
- **commit sha**: 见 `.flow-active` 的 `goal.task_progress[]` 中 `id="T03"` 的 `commit_sha`（**权威源**）。本文件被包含在该次提交内 ⇒ 按 **L-126 ③**「提交内容不可能写下自己的最终 sha」不在此处写死自身 sha。

## 任务目标

`ADR-022` 的原始 Decision 承诺「**最小侵入**：只注入 `pre-commit` 一个文件，**不碰 `.git/hooks/` 下用户既有 hook**」（`022-git-hook-deployment.md:25`，`### 优点` 小节首条）。本 change 的 **AC-3** 要求**推送拦截** ⇒ 必须新增 `pre-push` 注入面 ⇒ 该优点被**部分**削弱。本任务在 ADR 层**显式声明**这一偏离：在 ADR-022 **文末追加**一条 `Superseded-by`（**部分**），写清理由（AC-3）· 范围（仅扩展注入面）· 代价（备份 + 告知备份路径 + 可回滚），并**一字不动**原正文。

**依据**：`.specs/health-fix-2026-09b/DESIGN.md` 的 **D3 item 3**（「显式声明对 `ADR-022` 的部分 supersede」· 声明口径与代价）· `.specs/health-fix-2026-09b/REQUIREMENT.md` 的 **AC-3**（含 **R5 订正段**：初版禁令句与 `ADR-022` 冲突已纠正）· `.specs/health-fix-2026-09b/DESIGN.md` 的 **D3** 决策行与 **D3 item 6**（`pre-push` 沿用 symlink → 已安装 hooks 目录）。

## 改动文件

| 文件 | 性质 | 说明 |
|---|---|---|
| `.specs/adr/022-git-hook-deployment.md` | 修改（**write_files 声明项** · **只追加**） | 54 行 → **129 行**（`+75`），文末追加 `## Superseded-by（部分 · 2026-09-23 · change \`health-fix-2026-09b\`）` 段。`git diff --numstat` = `75	0`（**0 删除行**） |
| `.specs/health-fix-2026-09b/TASK.md` | 修改（流程性产物） | T03 的 `status="pending"` → `status="done"`（commit-protocol「标记完成」） |
| `.specs/health-fix-2026-09b/T03-SUMMARY.md` | 新增（流程性产物） | 本文件（commit-protocol「写 SUMMARY」） |
| `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` | 修改（流程性产物） | 追加「阶段 4 · T03」🟢 登记（本任务指令「🟢 入 MINOR-DEFERRED.md」的直接要求） |

**未改动**：`REQUIREMENT.md` / `DESIGN.md`（R3.2）；**未触碰其它任何 ADR**（`git status --porcelain -- .specs/adr/` 中除本文件外唯一条目 `?? .specs/adr/028-gate-baseline-allowlist.md` 是本任务开工**之前**既有的未跟踪文件）；未 `git add -A/-u/-a`；工作区既有的 `.specs/CONTEXT.md` / `.specs/STATE.md` / `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` 三处改动**未被本任务触碰、也未被暂存**（非本任务范围）。

## `<verify>` 命令与真实输出（逐字实跑）

### 前置态（修复前）—— 复现 `<done>` 所称「修复前实测：`Superseded-by` 命中 0」

对 **HEAD 版**的 ADR-022（`git show HEAD:…` 导出的同内容副本，54 行）逐字跑**同一条**判据：

```bash
$ git show HEAD:.specs/adr/022-git-hook-deployment.md > /tmp/t03base/022.md
$ A=/tmp/t03base/022.md;
  grep -qE 'Superseded-by' "$A" || { echo "🔴 未追加 Superseded-by"; exit 1; };
  grep -q 'pre-push' "$A" || { echo "🔴 未限定部分 supersede 的范围（pre-push）"; exit 1; };
  grep -qi 'symlink' "$A" || { echo "🔴 原决策正文疑似被改动（symlink 载体句丢失）"; exit 1; }
```

```
🔴 未追加 Superseded-by
[exit code: 1]
```

**同一事实在真实文件（未修改前）上的独立取证**（`grep` 无匹配自身 rc=1 ⇒ 该处 `||` 分支被正确触发）：

```
$ grep -c 'Superseded-by' .specs/adr/022-git-hook-deployment.md
0
[exit code: 1]        ← 命中 0 且 rc=1 ⇒ 判据落 `||` 分支，前置态确为失败态
```

### 后置态（追加完成）—— `A=… ` 三行 grep **逐字原样实跑**

```bash
$ A=.specs/adr/022-git-hook-deployment.md;
  grep -qE 'Superseded-by' "$A" || { echo "🔴 未追加 Superseded-by"; exit 1; };
  grep -q 'pre-push' "$A" || { echo "🔴 未限定部分 supersede 的范围（pre-push）"; exit 1; };
  grep -qi 'symlink' "$A" || { echo "🔴 原决策正文疑似被改动（symlink 载体句丢失）"; exit 1; }
```

```
A: PASS rc=0
```

**复跑两次确认无 flake**（L-119 ①：改写判据后立即逐字实跑并记录实测值）：

```
run1 rc=0
run2 rc=0
```

**逐条带自证输出复跑**（L-121 ①：成功态判据静默 ⇒ 逐条加可观测证据，命令与原判据逐字同构）：

```
✅ A1 grep -qE 'Superseded-by' "$A" ⇒ rc=0（命中）
✅ A2 grep -q     'pre-push'     "$A" ⇒ rc=0（命中）
✅ A3 grep -qi    'symlink'      "$A" ⇒ rc=0（命中）
```

> 判据形态说明（L-120 ④「自检本身也是判据」· L-121 ①「每个校验命令自带失败分支」）：三行**各带独立失败分支**，不依赖块末统一判断 ⇒ 后一行的成功**不会**掩盖前一行的失败。原判据的 `exit 1` 保证 `grep` 失败时整块 rc=1（实测前置态即此，`[exit code: 1]`）；成功态块末无 `exit` ⇒ rc 由最后一个短路 `||` 表达式的右操作数决定（短路后无命令执行 ⇒ `0`），实测 `rc=0`。

## TDD 适用性说明（本任务为何不适用）

本任务是**纯文档追加**：唯一产物是 `.specs/adr/022-git-hook-deployment.md` 末尾的 75 行 Markdown 散文（声明段），**不新增/修改任何可执行代码**（无 `.sh` / `.bats` / `Makefile` / `.js`）⇒ **没有可被测试驱动的行为**，「先写会失败的测试、再让它通过」在本任务中无对应物。故 TDD 不适用，**而非跳过**。

替代证明手段（比测试更贴合本任务的不变量）：

| 本任务真实需要保证的不变量 | 替代证明 |
|---|---|
| 「修复前判据确实失败」 | 对 HEAD 版 ADR 跑同一判据 ⇒ `🔴 未追加 Superseded-by` + `[exit code: 1]`（见上） |
| 「修复后判据确实通过」 | `rc=0` × 3 次（1 次主跑 + 2 次复跑） |
| **「原正文未被动」**（本任务的核心不变量） | ① `git diff --numstat` = `75	0`（删除行 **0**）② 前 54 行 `sha256sum` 与 HEAD 版**完全相同** ③ 逐字落点核对（见下节） |
| 「不越界改其它 ADR」 | `git status --porcelain -- .specs/adr/` |

## 「原正文未被动」的证据（三重独立取证）

### 证据 1 · `git diff` 只新增行，删除行为 0

```bash
$ git diff --stat -- .specs/adr/022-git-hook-deployment.md
 .specs/adr/022-git-hook-deployment.md | 75 +++++++++++++++++++++++++++++++++++
 1 file changed, 75 insertions(+)

$ git diff --numstat -- .specs/adr/022-git-hook-deployment.md
75	0	.specs/adr/022-git-hook-deployment.md
```

⇒ `--stat` 只报 `insertions(+)`（**无 `deletions(-)`**）；`--numstat` 的**第二列 = `0`** ⇒ **一条原行都没有被删改**。逐行统计删除行：

```bash
$ git diff -U0 -- .specs/adr/022-git-hook-deployment.md | grep -c '^-[^-]'
0
```

（`^-[^-]` 排除 diff 头 `--- a/…` 行；计数 **0** ⇒ 无删除行。注：`grep -c` 此处输出 `0` 即结论，不以其 rc 当结论 —— 对齐 L-121 ②「空集是一等失败态」。）

### 证据 2 · 原 54 行逐字节未变（与 HEAD 版 sha256 相同）

```bash
$ git show HEAD:.specs/adr/022-git-hook-deployment.md | sha256sum
467ea01e2d315a87cbaeaddf78083c6ce8d62f38e2afd2351bc7979e363ed34f  -
$ head -54 .specs/adr/022-git-hook-deployment.md | sha256sum
467ea01e2d315a87cbaeaddf78083c6ce8d62f38e2afd2351bc7979e363ed34f  -
```

```bash
$ git show HEAD:.specs/adr/022-git-hook-deployment.md | diff - <(head -54 .specs/adr/022-git-hook-deployment.md)
（无输出）
✅ 前 54 行逐字一致
```

⇒ 修改后的文件**前 54 行 = HEAD 版全文**，逐字节相同（空格、缩进、标点、emoji 全保留）。

### 证据 3 · 指定「必须原样保留」的句子与接缝落点实测

```bash
$ grep -n '只注入 `pre-commit` 一个文件' .specs/adr/022-git-hook-deployment.md
25:- **最小侵入**：只注入 `pre-commit` 一个文件，不碰 `.git/hooks/` 下用户既有 hook（方案 1 core.hooksPath 会全局覆盖致用户自定义全失效）
```

原 Decision 的「只注入 `pre-commit` 一个文件」句**保留原样**（行号仍是 `:25` —— 未发生任何行位移，本身就是「只追加、不重排」的直接证据），由追加段 §① 说明「注入面被**部分**扩展」。`symlink` 载体句（`:17`）与幂等句（`:27`）同样逐字仍在：`grep -n '幂等部署'` ⇒ `:27`（原文）+ `:67`/`:96`（追加段引用）。

**接缝落点**（`sed -n '53,58p' … | cat -A` ⇒ 原文件以 `- DESIGN.md D1<EOL>` 收尾，第 55 行 `—` 分隔线起始为追加内容）：

```
- REQUIREMENT.md AC-4（install.sh 部署 + 向后兼容）<EOL>
- DESIGN.md D1<EOL>          ← 原第 54 行（原文最后一行），位置与内容均未变
<EOL>
---<EOL>                      ← 以下均为追加行（第 55 行起）
<EOL>
## Superseded-by（部分 · 2026-09-23 · change `health-fix-2026-09b`）<EOL>
```

### 行号核实（任务形态要求：行号必须与内容锚点成对）

追加段中引用的两个行号已**实测核对**（`awk 'NR==N{…}'` 逐行打印，行号与内容成对）：

```
17: **选方案 3：symlink `.git/hooks/pre-commit` → 已安装 hook…     ← `## Decision` 内的 symlink 载体句 ✅
25: - **最小侵入**：只注入 `pre-commit` 一个文件，不碰 `.git/hooks/` 下用户既有 hook ← `### 优点` 首条 ✅
```

**未核实的行号一律不写**：段内指称其它位置时只用**小节名 + 文件路径**（`## Context` / `## Decision` / `## Consequences` / `### 优点` / `### 代价` / `## Alternatives Considered`）。另：段内已显式标注**本段自身的行号会随追加而漂移** ⇒ 引用 `:17`/`:25` 时一律带小节名，成对可核。

## 追加段形态核对（与任务 XML ① ② ③ 的逐项对应）

| 任务 XML 要求 | 追加段落点 | 实测 |
|---|---|---|
| 标题形态 `## Superseded-by（部分 · <日期> · change \`health-fix-2026-09b\`）` | 追加段起始（实测**当前**位于 `:58`，**该行号随追加漂移、不作为锚点**） | ✅ 逐字命中 `grep -n '^## Superseded-by' .specs/adr/022-git-hook-deployment.md` ⇒ `58:## Superseded-by（部分 · 2026-09-23 · change \`health-fix-2026-09b\`）` |
| ① 理由 = AC-3 要求推送拦截 | §① 「理由 · AC-3 要求推送拦截」 | ✅ 含 AC-3 的四种 push 形态 + 「仅 `pre-commit` 无法满足」的因果 + 「不得默默发生」 |
| ② 范围 = **仅**扩展注入面；`symlink` 载体与幂等语义**不变** | §② 「范围 · 仅扩展「注入面」」+ 5 行对照表 | ✅ 逐条列明不变项（symlink 载体 / 版本同步 / 幂等部署 / Windows fallback / 不采用方案 1·2） |
| ③ 代价 = 触碰 `.git/hooks/` 既有 hook ⇒ 先备份 + 告知备份路径 + 可回滚 | §③ 「代价 · 必然触碰…」 | ✅ 含 `cp <hook> <hook>.bak.<ts>`、`echo` 告知、回滚路径，并标注**代价是必然的**（附本仓活例） |
| 标注依据（DESIGN D3 · REQUIREMENT AC-3） | 段首判据出处 + 文末「依据与核对」 | ✅ 两处各列 `DESIGN.md` D3 item 3 / `REQUIREMENT.md` AC-3 |
| **不得**删除/改写/重排原决策正文 | 全文 | ✅ 三重取证见上（`75	0` / sha256 相同 / `:25` 行号未位移） |
| 参考 ADR-014..021 的 `**Superseded by**:` 字段约定，但**不**给其它 ADR 加字段 | 段内 `- **Superseded by**: **部分** —— …` | ✅ 采用同形字段**在追加段内**；`git status --porcelain -- .specs/adr/` 证明**未改动任何其它 ADR** |

## 特殊约束核实：本仓活例（`.git/hooks/pre-push` 已存在）

§③ 的「代价是必然的」以本仓为活例，实测值（本任务只读核对，未部署、未触碰 `.git/hooks/`）：

```bash
$ ls -l .git/hooks/pre-push
-rwxrwxr-x 1 hellrabbit hellrabbit 373  6月 29 14:36 .git/hooks/pre-push
$ grep -c 'pre-push' flow-kit-bundle/lib/install_hooks.sh
0        # rc=1 ⇒ 该安装器对 pre-push 零命中（与 DESIGN D3 item 6「0/0/0」一致）
$ ls -l flow-kit-bundle/hooks/pre-push/
（不存在）  # 新增产物尚未落地 —— 属后续 task（DESIGN D3 item 4/6）
```

⇒ `.git/hooks/pre-push` 是 **373 B 普通文件、非 symlink**（内容为 `make check`），与本段 §③ 的描述一致；本任务**未触碰** `.git/hooks/`（`git status --porcelain` 不含该路径，且 `.git/` 不受版本控制）。

## 6 维自查结果（内置 R1~R6 快查 · brooks-lint 未安装）

| 维度 | 结论 | 依据 |
|---|---|---|
| R1 认知过载 | 🟡 → 已缓解 | ADR-022 由 54 行增至 129 行（+75）；追加段含 2 张表 + 3 个编号小节。缓解：三段以 `①/②/③` 显式对应任务 XML 的三个必答项 + 段首「本段为追加」边界声明 + 文末「依据与核对」，读者可只看 §① 就抓住理由。**结构必要**（任务 XML 强制三项齐全 + 声明口径 + 行号核实），非冗余堆砌。残余可读性成本已登记 `MINOR-DEFERRED.md`（**G-T03-1**：ADR-022 的 supersede 语义落在文末小节而非头部字段，与 ADR-014..021 的头部约定不同形） |
| R2 变更传播 | 🟢 | 仅 4 个文件（1 声明 + 3 流程性）；**未触碰**工作区既有 3 处未提交改动；未触碰其它 ADR；未触碰 `.git/hooks/` |
| R3 知识重复 | 🟡 → 已缓解 | 追加段**引用**（而非复制）AC-3 / D3 的内容；不可避免的原文短引（`:25` 的「最小侵入」句 + `:17` 的 symlink 句）**带行号 + 小节名**，是「行号必须与内容锚点成对」所要求的锚点形态，非知识重复。未复制任何判据实现/代码 |
| R4 偶然复杂 | 🟢 | 未引入新抽象 / 脚本 / Makefile 目标 / 配置项；产物是纯 Markdown 追加 |
| R5 依赖混乱 | 🟢 | 无 import / 依赖变更；未新增外部依赖；未改 `install_hooks.sh`（实现属后续 task） |
| R6 领域扭曲 | 🟢 | 术语沿用既有 ADR 词汇（`Superseded by` / supersede / symlink 载体 / 幂等部署 / 备份回滚）；未自造词。**沿用既有抽象 grep（R6.4）**：`Superseded by` 字段约定命中 `.specs/adr/014~021`（头部 `**Superseded by**: 无`）+ `.specs/adr/006`（`- **Status**: Superseded by …（2026-07-23 · …）`）；`## Superseded-by（` **小节**形态在追加前命中 **0**（`git grep -n '^## Superseded-by' HEAD -- .specs/` ⇒ 0）⇒ 本形态系**首次使用**，未与既有约定冲突（ADR-022 头部无 `Status`/`Superseded by` **字段行**，回头改写头部会违反「只追加」⇒ 以文末小节承载语义是唯一不违约的载体） |

**计数：🔴 0 · 🟡 2（均已缓解 + 已登记）· 🟢 4。** 处置：🔴 无；🟡 两条均为「任务形态强制的结构成本」，已就地缓解并写入 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` 的「阶段 4 · T03」段（**G-T03-1** 头部字段约定不同形 / **G-T03-2** 追加段的行号引用会随追加漂移）；🟢 4 条为「无代码改动」的必然结果，无待办动作。

### 沿用既有抽象 grep（R6.4 · 强制作证）

```
✅ 沿用既有抽象 grep（R6.4）：
- 「Superseded by」**头部字段**约定：`.specs/adr/014`~`021` 均为 `**Superseded by**: 无`（值 ∈ {无, 链接+日期+理由}）；
  `.specs/adr/006` 为 `- **Status**: Superseded by [ADR-012](…)（2026-07-23 · 理由）`。
  ⇒ 本任务采用同形字段「`- **Superseded by**: **部分** —— change `health-fix-2026-09b` · 2026-09-23 · 理由：…」，
    **值的形态沿用既有约定**（「部分」= 对「无」与「全量链接」之间的第三态显式命名，因 ADR-022 只被单维度 supersede）。
- 「`## Superseded-by（…）` **文末小节**」形态：追加前全仓命中 **0**（新引入的**承载位置**，非新语义）；
  载体选择理由 = ADR-022 头部**原本没有** `**Status**` / `**Superseded by**` **字段行**
  （实测：ADR-014..021 各有 `**Status**:` 与 `**Superseded by**:` 两行；而 `grep -n 'Status' .specs/adr/022-…md`
   在**追加前**命中 0 —— 当前该计数为 **1**，且唯一命中在**追加段的正文散文里**（引用 ADR-006 的字段形态），
   不是字段行）
  ⇒ 回头改写头部即违反任务 XML 的「只追加」硬约束 ⇒ 唯一不违约载体是文末小节（追加段首已显式声明此事）。
- 「`## Superseded-by（` 小节形态」前无先例的取证（实测）：`git grep -n '^## Superseded-by' HEAD -- .specs/` ⇒ **0 命中**。
- 日期/理由/链接三元组格式沿用 `.specs/adr/006` 的 `（<日期> · <理由>）` 口径。
```

## 越界检查（R6.5）

```
✅ 越界检查（R6.5）：
  - TASK write_files 声明：1 项（.specs/adr/022-git-hook-deployment.md）
  - 实际 diff 涉及：4 项
      1. .specs/adr/022-git-hook-deployment.md          ← write_files 内（本任务唯一实质产物）
      2. .specs/health-fix-2026-09b/TASK.md             ← commit-protocol「标记完成」强制
      3. .specs/health-fix-2026-09b/T03-SUMMARY.md      ← commit-protocol「写 SUMMARY」强制
      4. .specs/health-fix-2026-09b/MINOR-DEFERRED.md   ← 本任务指令「🟢 入 MINOR-DEFERRED.md」强制
  - 越界：0（后 3 项均为流程性产物，与 T01/T02 同形先例）
  - 工作区其它未提交改动：.specs/CONTEXT.md / .specs/STATE.md / flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    ⇒ 未触碰、未暂存、保持原样
  - 其它 ADR：未改动（仅本文件 M；?? .specs/adr/028-gate-baseline-allowlist.md 为开工前既有未跟踪文件）
```

## 提交路径与门禁

按 `flow-kit-bundle/flow-kit/reference/commit-protocol.md` 提交：显式路径 `git add`（**未**用 `-A/-u/-a`）· 中文 message · 前缀 `docs(health-fix-2026-09b): T03 …`。

**未使用 `git commit --no-verify` 或任何绕过门禁的写法**（`LESSONS.md` **L-126 ②** 明令禁止 —— 该条正源于 T01 的一次真实绕过）；pre-commit（`flow-kit-bundle/hooks/pre-commit/pre-commit.sh` 跑 `make test`，bats 约 1–2 分钟）**真跑并等待**。门禁若失败 ⇒ 捕获完整输出并以 `STATUS: BLOCKED` 上报，不绕过、不改测试（见本文件「门禁实跑结果」段）。

### 门禁实跑结果（未绕过）

```bash
$ git add .specs/adr/022-git-hook-deployment.md .specs/health-fix-2026-09b/TASK.md \
        .specs/health-fix-2026-09b/T03-SUMMARY.md .specs/health-fix-2026-09b/MINOR-DEFERRED.md
$ git commit -m 'docs(health-fix-2026-09b): T03 ADR-022 追加部分 Superseded-by（新增 pre-push 注入面 · 原正文只追加不改写）'
```

```
🧪 make test: running bats...
ok 971 CF-01: write_compliance_correction creates valid JSON with all fields
ok 972 CF-02: write_compliance_correction merges with existing + dedup
ok 973 CF-03: clear_compliance_correction removes the file
✅ bats: all tests passed
[develop c23213e] docs(health-fix-2026-09b): T03 ADR-022 追加部分 Superseded-by（新增 pre-push 注入面 · 原正文只追加不改写）
 4 files changed, 330 insertions(+), 1 deletion(-)
 create mode 100644 .specs/health-fix-2026-09b/T03-SUMMARY.md
=== COMMIT_RC=0 ===
```

- **`make test` 真跑并全绿**（`bats` 末条 `ok 973` + `✅ bats: all tests passed`），**未使用 `--no-verify`**、未绕过任何门禁、未改测试（L-126 ②）。
- `4 files changed, 330 insertions(+), 1 deletion(-)` —— 那个 `1 deletion` 位于 `TASK.md` 的 T03 头行（`status="pending"` → `status="done"`），**不在 ADR-022**（ADR-022 自身为 `75	0`，见上「证据 1」）。
- commit sha `c23213e` 为**落档引用**（权威源仍是 `.flow-active.goal.task_progress[]`）；按 **L-126 ③**「提交内容不可能写下自己的最终 sha」，本行是提交**之后**的补记。
