# CHANGE: 收口 13 个 🔴（测试非封闭致源文件被静默改写 / 隐私门禁假绿 / mock 自证与契约值漂移 / 5 项存量未修）

- **Change ID**: `health-fix-2026-09c`
- **创建日期**: 2026-09-29
- **来源**: `/flow-health 全量扫描`（`.specs/health/2026-09-29-HEALTH.md`，55/100 · 13🔴 / 24🟡 / 11🟢）
- **路径建议**: 完整（0 → 1 → 2 → 3 → 4 → 5 → 6 → 7）—— 理由见文末「路径理由」
- **状态**: draft
- **上一轮**: `health-fix-2026-09b`（2026-09-28 归档至 `.specs/archive/2026-09-28-health-fix-2026-09b/`）

---

## Why（为什么做）

2026-09-29 全量五维巡检给出 **55/100**（09-22 为 56/100，同轴 **−1，持平**）。09-22 的 13 个 🔴 中 **7 个已修、1 个部分修、5 个未修**，且**无一项比 09-22 更差**——但本轮出现了 **09-22 不存在的两类 🔴**，其中一类**已在巡检过程中造成真实数据丢失**。

因此本 change 的核心不是「继续还旧债」，而是 **先止血新增的两类 🔴，再收口 5 项存量未修**。按 skill 约束「所有 Critical 合并成 1 个 health-fix change，避免 PR 爆炸」，以下 13 项全部并入本 change。

---

### 1. 🔴 C1 · 测试套件非封闭 —— 已造成真实源文件损坏（**本次巡检实测发生**）

**这是本轮唯一「已发生损害」的项，也是最高优先级。**

`test/test_check_gate_sync.bats`（与 `flow-kit-bundle/test/test_check_gate_sync.bats` **逐字节相同**，md5 均为 `73a5245e862b53add21cbeb000610713`）对 **tracked 源文件**做就地改写：

```bash
:15  SKILL="flow-kit-bundle/skills/flow/SKILL.md"                    # ← 真实 tracked 路径，非夹具
:17  setup() {
:19    cp "$SKILL" "$SKILL.t02-bak"                                  # ← 固定共享备份路径
:20  }
:22  teardown() {
:23    [[ -f "$SKILL.t02-bak" ]] && mv -f "$SKILL.t02-bak" "$SKILL" || true   # ← 还原失败被静默吞掉
:24  }
:39    sed -i '/# review[[:space:]]*→/a\     # fake-preset  → {"6-review":"independent"}' "$SKILL"
:46    sed -i '/# design[[:space:]]*→.*2-design/d' "$SKILL"
:52    sed -i '/预设名映射表（PRESET_MAP）/a\     # note: explanatory comment without arrow' "$SKILL"
```

**竞争时序（并发才固化破坏）**：

1. A 进程 `setup` 备份干净版 → A 进程 `sed -i` 损坏源文件
2. **B 进程 `setup` 把「已损坏版」覆盖进同一个 `$SKILL.t02-bak`**
3. A 进程 `teardown` 把这份**坏的** `mv` 回去 ⇒ **破坏被"正式还原"固化**
4. B 进程 `teardown` 因 bak 已被移走而走 `|| true` **静默跳过**

**签名指纹**：`$SKILL.t02-bak` 不存在，而 `SKILL.md` 保持损坏。

**本次实测后果**（巡检期间同一 worktree 上并发跑了 3 个 `make check`，各自 fork `npx bats test/`）：

- `git status --porcelain` → ` M flow-kit-bundle/skills/flow/SKILL.md`
- `git diff` 恰好 1 行删除：`-     # design             → {"2-design":"both"}`
- HEAD blob `9f861d9`（20344B）→ 工作树 `de75f05`（20294B）
- **次生连锁**：`make check-gate-sync` rc=2（`🔴 DRIFT: gate-config 预设名集合不一致！` + `2a3` / `> design`）、`make check-dist` rc=2 ⇒ **门禁被它自己的测试弄红，`make check` 全绿不可达**
- `.git/hooks/pre-push` 内容就是裸 `make check` ⇒ **每次并发 push 检查都会再犯**
- `test/` 与 `flow-kit-bundle/test/` 是**双源同内容** ⇒ 该破坏性测试**同时分发给所有安装方**

**横向普查（破坏面已精确限定）**：`grep -rn 'sed -i' test/*.bats` = **18 位点 / 5 文件**，其中

- **真·写 tracked 源文件 = 3 个位点，全部在本文件**（`:39`/`:46`/`:52`，目标 `$SKILL`）—— **唯一元凶**
- 7 位点是**断言里的字符串字面量**，不落盘（`test/test_gate_integrity.bats:80,81,82,202,203`；`test/test_nfr_portability_gate.bats:94,95,100,111,112,150`）
- 4 位点在 `mktemp -d` 沙箱内（`test/test_flow_active_integrity.bats:44`，目标 `$FLOW_ACTIVE="${TEST_TMP}/.flow-active"`；`test/test_l3_review_defects_2026_09.bats:492,501,1793`，目标 `$mutant="$TEST_TMP/ac12-mutant"`）

⇒ **1 / 80 个 bats 文件（1.25%）违规**。

**修法无需新造范式**：同一文件 `:58-110` 的 **T-FIX-04 F6 段已经是正确写法**（文件头 `:20-22` 注释即述「T-FIX-04（F6 收敛）：…复制真实生产件进 `mktemp -d` 夹具（禁止抄正文进 bats）」）：

```bash
:62  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix04-ok-XXXXXX")
:63  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" …
:66  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
:67  cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/"
:81  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
```

且 `:244-247` 连「就地改一行」都在沙箱里做（`f="$SBX/fk/flow-kit-bundle/skills/flow-evolve/SKILL.md"`；`sed '…' "$f" > "$f.tmp" && mv "$f.tmp" "$f"`）。同族范式另见 `FXB10()` `:100-110`、`FXB25()` `:162`、`FXB18()` `:203-213`。

---

### 2. 🔴 C2 · 前向隐私门禁结构性失明 —— `rc=0` 是假绿（**比没有门禁更危险**）

`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:72`：

```bash
PAT='/home/[a-z_][a-z0-9_-]*/'      # ← 强制尾斜杠
```

**该 ERE 与真实泄漏形态不交集**：

| 形态 | 出现次数 |
|---|---|
| `/home/<acct>/`（带尾斜杠） | **0** |
| `/home/<acct>[^/]`（不带尾斜杠） | **33** |

⇒ 门禁报「清单外命中 **0** 条 ✅」并已接入 `make check`（`Makefile:106` / `:125`），而同一时刻 `git grep -nE '/home/<acct>'` 有 **30 行 / 6 文件**。**门禁对全部真实泄漏 0 捕获。**

三探针实测（`/tmp` 内，仓未动）：

| 探针内容 | 结果 |
|---|---|
| `/home/<acct>`（裸） | **NO MATCH** ❌ |
| `` `/home/<acct>` ``（反引号包裹） | **NO MATCH** ❌ |
| `/home/<acct>/x` | MATCH ✅ |

唯一会被 PAT 捕获的 tracked 命中是脚本自身 `:23` 的注释自引用，且已在 `SELF_EXCLUDE` 内。

**为什么是 🔴 而不是 🟡**：09-22 记录的对应项是「**无隐私门禁**」（坦白承认无守护）；本周期门禁上线并接入 `make check` ⇒ 状态从「可见的无守护」变成「**有门禁但说谎**」。它会让「绿」被当作证据，任何以裸形式写下的泄漏可无限期进入仓库而不被拦。

**同族反例（测试复刻了门禁盲区）**：`test/test_path_privacy_gate.bats:35` 的探针

```bash
PROBE="/home/""zz-path-pr""obe/"        # ← 自带尾斜杠，恰好复刻门禁盲区
```

⇒ **测试全绿也证明不了拦得住**。注意该文件另有 `:26-27` 的**正确范式**（`TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/fk-pp-gate.XXXXXX")` / `FIXTURE="$TEST_TMPDIR/repo"`）与 `:47` `cp -- "$SUT_SRC" "$FIXTURE/$SUT_REL"`。

**门禁自身防御质量其实很高**（因此**不需要重写，只需修一处正则**）：T22 空基线双态自检 · T-FIX-03 F1~F5 把 `mktemp`/`cp`/枚举/检索 `rc` 全部断言 · 候选数 `N=0` ⇒ fail-closed · `grep -aE` 二进制策略 + line 字段 `^[0-9]+$` 断言 · T-FIX-06 F19/F20 · **6 条精确 `SELF_EXCLUDE`** 且注释明示禁用 `reference/*`/`skills/*`/`.specs/*` 宽通配（理由是「会吞掉 31 处 `<acct>` 字样含 10+ 处真实账号路径，且永久无界」）。

---

### 3. 🔴 C3 · 真实账号名仍在 tracked 面与全历史中，且孤儿 `main` 使其永久可达

**现状（30 行 / 6 文件）**：

| 文件 | 命中行 |
|---|---|
| `.specs/health/2026-09-22-FULL-SWEEP.md` | 11 |
| `.specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-2.md` | 9 |
| `.specs/archive/2026-09-28-health-fix-2026-09b/INDEPENDENT-REVIEW-1.md` | 6 |
| `.specs/STATE.md` | 2 |
| `.specs/LESSONS.md` | 1 |
| `.specs/CONTEXT.md` | 1 |

**全历史**：`git rev-list --all --objects`（6568）+ 逐 blob `git cat-file` ⇒ **86 个泄漏 blob**；旁证 `git log -p --all | grep -cE` = **127** 行。

**孤儿 `main` 是保持可达的路径**：

- `git merge-base main develop` → **rc=1（无共同祖先）**；`refs/heads/main` @ `47d80f6`（2026-06-14）
- `refs/heads/main` tip 树仍含 **6 行 / 2 文件**（`.specs/CONTEXT.md` ×1 + `.specs/archive/2026-06-09-user-scope-install/TASK.md` ×5）—— **与 09-22 完全相同，未变坏，只是未修**
- 逐 ref 扫描：`develop` **30 行/6 文件** · `main` **6 行/2 文件** · `origin/develop` 0 · `origin/main` 0 · `v0.3.0-gate-integrity` 0
- 86 个 blob 全部**保持可达** ⇒ `gc --prune=now` 无法回收

**分发面干净（当前最大缓冲，须保持）**：`grep -rlE '/home/<acct>' flow-kit-bundle/` = **0** · `test/` = **0** · `dsh-flow-kit/` = **0** · `tar -xzOf flow-kit-bundle.tar.gz | grep -acE` = **0** · 凭证模式（`AKIA` / `ghp_` / `sk-` / `BEGIN … PRIVATE KEY` / `xox[baprs]-` / `AIza`）tracked 面 **0 命中** · **未跟踪未忽略档 0**（12 IGNORED + 6 TRACKED + 0 UNTRACKED_UNIGNORED）。`dist/` 有 2 处（`dist/.l3run.sh:11`、`dist/.l3run2.sh:10` 的 `export PROJECT_ROOT="/home/…"`），但 `dist/` 完全 untracked（`git ls-files dist/ | wc -l` = 0）且被 `.gitignore:63` 忽略 ⇒ **不随 clone 传播**。

**泄漏引入时间线（关键）**：`7d9a086`（2026-09-23）subject = `fix(health-fix-2026-09b): T13 AC-6 前置工件脱敏（真实账号路径 → /home/<acct>/）`。该提交在**同一提交内**删除了 `health-fix-2026-09b/{DESIGN,T04-SUMMARY,T11-SUMMARY,TASK}.md` 的 9 行真名（diff 的 `-` 行），**同时新增** `.specs/health/2026-09-22-FULL-SWEEP.md`（948 行）且 **11 行真名原样进入**。⇒ **脱敏动作跨过了它正在提交的那个文件**。26/30 行落在最近两个巡检工件内部，全部写于 09-22「测得 0」之后 ⇒ **09-22 的「前向脱敏 = 0 · 闭环」不可复现**。

---

### 4. 🔴 C4 · 失败守卫恒真 —— `|| true` 吃掉 `$?`（**一行改动，优先级最高**）

`flow-kit-bundle/hooks/stop/29-independent-review.sh:200-201`：

```bash
:200    l3_review_run … $L3_BG_FLAG || true
:201    local bl_rc=$?                                        # ← 恒为 0
:203    module_output "warning" "IR" "backlog L3 failed for phase ${pn} (rc=${bl_rc})——see hooks.log"
```

`:200` 的 `|| true` 使 `:201` 捕获的 `$?` **恒为 0** ⇒ `:203` 的告警**永不打印**。积压翻查 `_l3_scan_backlog()`（34 行，`:175-208`）的 L3 失败**全静默**。**改 3 个字符。**

---

### 5. 🔴 C5 · mock 自证 + 契约值漂移扩大（测试成为错误的权威）

`test/test_gate_config_presets.bats`（390 行 / 34 `@test`）：

```bash
:27   # Simulates the resolve_gate_config() logic from /flow skill
:31   resolve_gate_config() {          # ← 定义在测试文件内部
```

**证据一 · 整子系统级自证**：`grep -rn 'resolve_gate_config'`（排除 `dist/`）显示它**没有任何可 source 的生产实现** —— 所谓「生产实现」是 `flow-kit-bundle/skills/flow/SKILL.md:136` 的**自然语言散文**（由 LLM 执行），mock 是这个架构逼出来的。

**证据二 · 隔离实验（可复现）**：

```bash
cp test/test_gate_config_presets.bats /tmp/tq/iso/ && cd /tmp/tq/iso && npx bats --tap
# → 34 ok / 0 not ok     ← 离仓仍全绿
cp test/test_correction_hygiene.bats /tmp/tq/iso/ && npx bats --tap
# → exit 127 (Command not found)   ← 对照组证明「离仓」确实切断生产依赖
```

⇒ 删掉整个 `flow-kit-bundle/` 该测试仍全绿。它占本仓第 7 大测试文件（34 例，3.0%）。

**证据三 · 断言改造前旧语义且漂移扩大**：

| 位置 | 语义 |
|---|---|
| mock（测试内） | `"independent"` × **92** 处 · `"both"` × **0** 处 |
| 生产契约 `flow-kit-bundle/hooks/stop/lib/common.sh:408` | `independent\|true) echo "both" ;;` / `L2\|L3\|both) echo "$raw" ;;` |
| 文档 `flow-kit-bundle/flow-kit/reference/goal-parsing.md:23` | `"gate_config": { "1-requirement": "both", … }` |

**09-22 测得 72 处 → 2026-09-29 复测仍 72 处（引号口径 `grep -c '"independent"'`，无再扩大；原记「现 92 处/漂移扩大 20 处」系口径误计——L3 重审 r3 m3 修订）**。后果：测试固化了改造前语义，**任何按文档改成 `"both"` 的人会被测试误导回旧值 —— 测试成为错误的权威**。

**同批必改 · 门禁侧只比名字不比值**：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:225-232` 提取 bats 侧预设时

```bash
sed -E 's/^[[:space:]]+//; s/\).*//'      # ← 从右括号起全部截掉，只留预设名
```

⇒ `"independent"` vs `"both"` 的漂移**能存活整轮而不被发现**。`:189` 自认：`# 【DESIGN D5 边界】本函数的值比较逻辑属 TC1/TC2（TD-033/TD-034），v2 范围，本 task 不改。` —— **从「静默失明」变「已登记的失明」是 09b 的真实进步，但失明本身仍在**，且它正是 C5 漂移无法被机器发现的原因。**C5 两侧必须同批修**，否则修完测试仍无门禁守护。

---

### 6. 🔴 C6 · 32 处断言生产源码文本而非行为（双向失真）

分布：`test/test_l3_review_defects_2026_09.bats` **18** · `test/test_fix_l3_gate.bats` **6** · `test/test_l2_pretooluse_dispatch.bats` **4** · `test/test_dual_review_merge.bats` **3** · `test/test_l3_lifecycle_wiring.bats` **1**。

典型（`test_l3_review_defects_2026_09.bats:723-732`，用例 `B2-R8: 转义是契约 —— 两个载荷写入方都必须走 _l3_escape_payload`）全文为：

```bash
grep -q '^_l3_escape_payload() {' "$sec"
grep -q '_l3_escape_payload "\$content"' "$L3_API_LIB"
grep -q '_l3_escape_payload "\$content"' "$L2_LIB"
[ "$(grep -c 's~^(## ' "$L3_API_LIB")" -eq 0 ]
[ "$(grep -c 's~^(## ' "$L2_LIB")" -eq 0 ]
```

**双向失真**：

- 重命名 `$content` → `$payload`（**行为完全不变**）会让这 32 处**全红**
- 而函数**运行时彻底失效**、只要那两行字面文本还在源码里，`B2-R8` **依然绿灯**

紧邻的 `B2-R9` 用例名明写「（行为断言）」—— **作者知道该弱点并配了兜底，但仍不完整**。

---

### 7. 🔴 C7 · `make test` 把全套件跑两遍（浪费 + 放大 C1 污染窗口）

`Makefile:11-12`：

```make
:11    npx bats test/ --formatter tap 2>&1 | tail -3
:12    npx bats test/ > /dev/null 2>&1 && echo "✅ bats: all tests passed" || { echo "❌ bats: some tests failed"; exit 1; }
```

三重后果：

1. **一次 `make test` = 2 × 1116 例**；`:11` 的输出除末 3 行全被丢弃（纯浪费）
2. `:11` 的**退出码被管道吞掉**（无 `pipefail`）⇒ 该行只起展示作用
3. **使 C1 的污染窗口翻倍** —— 单次 `make check` 内就有**两次**机会触发 `test_check_gate_sync.bats` 的原地改写

---

### 8. 🔴 C8 · 5 项 09-22 存量 🔴 未修

| 09-22 # | 项 | 位置 | 本次实测 |
|---|---|---|---|
| #10 | **伪单一源**：`pipeline-gates.md` 被 `@see` 为源却已分叉 | `flow-kit-bundle/flow-kit/reference/pipeline-gates.md:13-19` ↔ `flow-kit-bundle/flow-kit/prompts/4-dev.md:99-106`（`:6` `@see … — toll-gate 协议单一源`） | `pipeline-gates.md` = **7 行**表；`4-dev.md` = **8 行**（多 `#7` bats + `#8` `.flow-active` jq），缩进与措辞亦分叉 ⇒ `:6` 的 `@see … 单一源` 是**假陈述**。分叉规模与 09-22 记录的「7 vs 8」一致 |
| #12 | **静默内联零署名** | `flow-kit-bundle/skills/flow-dev/SKILL.md`（549 行） | `commit-protocol.md`（141 行）中 **13 处 ≥20 字符长行**逐字出现；`grep -nE 'commit-protocol\|pipeline-gates\|artifact-protocol'` **只命中 `:6` 的 pipeline-gates** ⇒ commit-protocol 内联**零署名** |
| #13 | **第三载体**：163 行逐字复制且无内容校验 | `flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md:36-198` ↔ `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md:1-163` | `diff <(sed -n '36,198p' l2-reviewer.md) <(sed -n '1,163p' L2-blind-review.md)` → **完全相同**（后者恰 163 行） |
| #7(PC7) | **L2-first 动作链逐字复制两份（含同一报文）** | `29-independent-review.sh:136-140` ↔ `:238-244` | 快路径前置 `[ ! -f "$review_md" ] \|\| ! grep -q "^## L2 盲审"`；D4 深检路径前置 `l2_detect_missing`。两者报文**逐字相同**（`module_output "warning" "IR" "L3 跳过（L2 not yet complete, gate_config=both · deny reason: L2-first 契约未满足）——主 agent 请派 L2 子 agent 并写入 ## L2 盲审 段后重试（见 .flow-active.correction）"`），各配 `_write_l2_missing_correction` + `exit 0` |
| — | **A6 门禁不随 clone 传播** | `.git/hooks/pre-commit`（**符号链接** → 仓外 `~/.claude/hooks/pre-commit/pre-commit.sh`，6443B）· `.git/hooks/pre-push`（**普通文件** 373B，内容仅 `make check`） | `pre-commit` 是符号链接 ⇒ **新克隆者没有 pre-commit 门禁**，且链目标本身含真实账号名；`flow-kit-bundle/hooks/pre-commit/pre-commit.sh`（6443B，mtime 09-28 00:15）与链目标（mtime 09-29 02:02）**不同源**、各自维护；`pre-push` 是**裸 `make check`** ⇒ 与 C7 叠加后**每次并发 push 检查都会触发 C1 污染**（拦截图 `flow-kit-bundle/hooks/pre-push/pre-push.sh:69`/`:89`/`:95` 会在被推送 ref 上跑 path-privacy 评估、有 `flow-kit-bundle/test/test_pre_push_behavior.bats` 覆盖，但**没装上**） |

---

### 9. 🔴 C9 · 复杂度：4 项结构性超限（P2 层，可在本 change 内分期）

| 项 | 位置 | 实测 |
|---|---|---|
| **无 `main()`**：~270 行顶层直线代码，5 个 Gate 靠 `exit 0` 串联 | `flow-kit-bundle/hooks/stop/29-independent-review.sh:13` | `set -euo pipefail`；总 336 行，**函数体仅 66 行**（`_write_l2_missing_correction` 32 行 `:24-55`、`_l3_scan_backlog` 34 行 `:175-208`）；`grep -c '^main()'` = **0**；`:131` `phase_name="$(fk_phase_gate_key "$phase")"` 在**列 0** 夹在两个 Gate 之间 ⇒ **无法单独测试任一 Gate** |
| **超长函数** `_l3_build_prompt()` **201 行** | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:322-522` | 6 个 case 分支：1(`:327-337`)/2(`:338-391`)/3(`:392-398`)/5(`:399-405`)/6(`:406-446`)/7(`:447-502`)。同文件邻居 `_l3_extract_prior_findings` 90 行、`_l3_inject_context` 71 行 |
| **Makefile 内嵌 203 行 bash** | `Makefile:162-365` | `:162` `check-nfr-portability-internals:` recipe 实测 **203 行**；`:163` `@bash -euo pipefail -c ' \`；`:292` `BAN="declare[[:space:]]+-A\|mapfile\|…"`。`$$` 转义使变量形如 `$$NFR_RC_FILE` ⇒ **无法 shellcheck、无法单测** |
| **1051 行门禁脚本**：46.1% 注释、`scan_file()` 121 行、6 个手维护计数器 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:613-733` | 全文件 1051 行中纯注释 **484 行 = 46.1%**（`:9-63` 共 55 行是 T22/T-FIX-03/T-FIX-06 三轮修复变更史）；计数器 `CANDIDATE_COUNT`/`SCANNED_COUNT`/`SKIPPED_COUNT`/`UNREADABLE_COUNT`/`INDEX_SIDE_COUNT`/`UNATTRIBUTABLE_HITS`；`:882` 断言 `if [ "$CANDIDATE_COUNT" -ne $((SCANNED_COUNT + SKIPPED_COUNT)) ]; then` **只兜「候选数塌缩」，兜不住「三路命中口径不一致 ⇒ 漏报」** |

---

### 10. ⚠️ C10 · lint 判据失真（**严重度在报告内部有争议，本 change 按「并入但不作 P0」处理**）

`Makefile:34` / `:46` / `:47`：

```make
:34      🔍 make lint: shellcheck (error level only)...
:46      OUT=$$(shellcheck -e SC1091 "$$f" 2>&1) || true;      # ← 默认严重度，无 -S error
:47      ERRS=$$(echo "$$OUT" | grep -ci "error" || true);     # ← 文本近似代替语义
```

**三组对照探针实测**（`/tmp/hprobe/`）：

| 组 | 样本 | ShellCheck 输出 | `grep -ci error` | 判定 |
|---|---|---|---|---|
| A | 仅 warning + 路径**不含** `error` | 2 条 `(warning)`（SC2034/SC2154） | **0** | ✅ 正确 |
| B | 仅 warning + 路径**恰含** `error`（`/tmp/hprobe/with_error_dir/s1.sh`） | 2 条 `(warning)`，header 行 `In <file> line N:` 自带该词 | **2** | ❌ **假阳性** |
| C | 真 error 级（`if [ x = y ; then` → SC1009 info + SC1073/SC1072 error） | 3 条 | **4** | ✅ 正确，**无假阴性** |

⇒ **该判据只过宽、不遗漏**：会因 warn-only 文件**误红**，但**不会把真 error 放过去**。因此报告 `:155` 明确修正措辞：**「严重度应定性为 🟡 判据失真，而非 🔴 静默放行」**。

**本 change 的处理**：修法（改 `shellcheck -S error -f gcc` 按 `rc` 判红 + 缺工具时由 fail-open 改 fail-closed）**正确且廉价，故并入**；但**不作为 P0，也不以「静默放行」为由升格**。配套：`Makefile:38-41` 缺 shellcheck 时 `echo "   Skipping lint (non-blocking)."` 属 **fail-open**，与 `check-path-privacy.sh` 的 **fail-closed** 语义相反 —— 同一份 `make check` 里两种安全哲学。

> 附：`Makefile:28-31` 的 `SCAN_EXCLUDES` 已改用 `find` 驱动（含 `-not -path '*/brooks-lint/*'`、`*/.claude/*`、`*/.specs/*`、`*/test/*` 等）⇒ **2026-09-20 LESSONS 记的「4 个生产脚本漏在门口」已修复** ✅，本 change 不再处理。

---

### 11. 🔴 C11 · **跨层闭环**：门禁拿「已漂移的 mock」当真相，再只比名字 —— 漂移被盖章为「一致」

> **来源**：报告新增 §附录 D-4（brooks-lint 标准化路径四技能重跑补测）。**本条与既有 C5 是同一件事的两侧，必须同批修。**

本 change 的 C5 原本只写了「mock 自证 + 契约值漂移」的**测试侧**。补测把三段代码接成了一条**通路**：

| 环节 | 位置 | 代码 |
|---|---|---|
| 侧 A（文档） | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:191` | `local skill_file="$BUNDLE_ROOT/skills/flow/SKILL.md"` |
| 侧 B（**取自 mock**） | 同上 `:192` | `local bats_file="$BUNDLE_ROOT/test/test_gate_config_presets.bats"` |
| 侧 B 取法（**现解析 mock 的 `case` 块**） | 同上 `:229-234` | `sed -n '/^  case "$value" in/,/^  esac/p' "$bats_file"` |
| **只比名、丢弃值** | 同上 `:231` | `sed -E 's/^[[:space:]]+//; s/\).*//'` ← 从 `)` 起全部截掉 |
| 自认边界 | 同上 `:189` | `# 【DESIGN D5 边界】本函数的值比较逻辑属 TC1/TC2（TD-033/TD-034），v2 范围，本 task 不改。` |

**实测**：`grep -rn 'resolve_gate_config' --include='*.sh' . | grep -v dist/` 只返回 `check-gate-sync.sh:194,225` 两条**注释** ⇒ **生产侧不存在可 source 的实现**；mock 输出 `"independent"`（72 处，2026-09-29 复测引号口径）而生产 `hooks/stop/lib/common.sh:408` 输出 `both`（0 处）。⇒ **门禁的「bats 侧真相」就是那个已漂移的 mock，而门禁只比名不比值，因此给漂移盖上了「一致」章。** 删除整个 `flow-kit-bundle/` 它仍全绿 —— 而它是 `make check` 的先决条件。

**为何单列而不并入 C5**：**失效模式是「更绿」而非「更红」** —— 缺陷存在时所有可观测信号与健康态**完全同形**，没有负向信号可触发警觉。这也解释了报告为何把 T6 打成 8.0「无发现」。

**修法（与 C5 同批）**：①把预设名/值解析**提到生产 `.sh`**，测试与门禁**双双 source 它**（根治，也是②不复发的前提）②mock 72 处（2026-09-29 复测口径，r3 m3 修订）值改 `both` ③`check-gate-sync.sh` 的提取器保留 `{...}` 值部分，**比对键值对集合而非名字集合** ④**加反向控制**（把 `common.sh:408` 的 `both` 改回 `independent`，门禁**必须转红**）。

---

### 12. 🔴 C12 · 门禁依赖策略**安装期 fail-closed、运行期 fail-open**（安全向，独立可修）

> **来源**：报告新增 §附录 D-4（brooks-review F2，主 agent 已直接读源码复核）。**本条可独立于 C11 修。**

| 位置 | 代码 | 语义 |
|---|---|---|
| `flow-kit-bundle/lib/install_hooks.sh:189-192` | `if ! command -v jq >/dev/null 2>&1; then echo "   ❌ 缺少依赖 jq…已中止（尚未做任何写盘）" >&2; return 1; fi` | **安装期 fail-closed** ✅ |
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:114` | `command -v jq >/dev/null 2>&1 \|\| exit 0` | ❌ **运行期 fail-open** —— PreToolUse 下 `exit 0` = **放行**，缺 jq 则**整流门禁静默放行** |
| 同上 `:65` | `jq empty "$flow_file" 2>/dev/null \|\| exit 0` | ❌ `.flow-active` 非法 JSON 时同样**放行** |
| 同上 `:32-37` | `source "$COMMON_LIB" 2>/dev/null \|\| true` 后有 `declare -f fk_phase_gate_key` 断言 → `exit 2` | ✅ **确有** fail-close 守卫（T-FIX-02 成果） |
| 同上 `:42-46` | `source "${SCRIPT_DIR}/gate-helpers.sh"` / `gate-checks-basic.sh` / `gate-checks-review.sh` | ❌ **三个子库均无同等断言** ⇒ `set -e` 下 `:104` 调用未定义函数 rc=127≠2，被宿主当作**非阻塞错误** ⇒ 门禁静默失效 |

**为何是 🔴**：该文件**头部自述 fail-close**，而代码在两条路径上是 fail-open —— **文档说 A、代码做 B**；且这类门禁的失效方向是**放行篡改**而非误拦。**已修复的范围**反而证明了修法可行：`common.sh` 那一个库有断言，另三个没有。

**修法**：三个子库各补一条与 `:32-37` 同族的存在性断言；jq 缺失与 `.flow-active` 非法 JSON 均改 **fail-closed（exit 2 + 具名报文）**；并补 bats 反向控制（删掉 `gate-helpers.sh` 后门禁必须转红）。

---

### 13. 🔴 C13 · **14 对阶段载体手工双写、11 对已分叉，而门禁只覆盖 3/14（21%）**

> **来源**：报告新增 §附录 D-4（brooks-audit 🔴1）。**需 DESIGN 决策，不建议走快路径。**

| 事实 | 实测 |
|---|---|
| 真 0 差异的载体对 | **仅 3 / 14** |
| 最大差异 | `4-dev` **175%**（545 vs 352 行）· `6-review` 112% · `7-integration` 81% |
| 独有小节 | **95 个 prompt 独有** vs **52 个 skill 独有**（双向各持对方没有的强制条款） |
| 门禁覆盖 | `check-gate-sync.sh:37-44` 只列 **3 对**，且**自己把「仅覆盖 3 对」打印在输出里却仍 rc=0** |
| 演化性质 | `git log --name-only -400` 聚合：prompts-only **16** 次 / skills-only **9** 次 / 同改 **2** 次 ⇒ **持续机制，非一次事故** |

**反向缺失同样致命**（本轮实例）：`### 步骤 2.6 · 全量 bash -n 语法门禁` **只存在于 skill 载体**。走 prompts 路径的 agent 做 flow-health 巡检时**不会看到步骤 2.6**，即**会跳过全量语法门禁**。本轮巡检走的是 skill 载体（已执行），属**侥幸而非结构保证**。

**后果**：**同一阶段的强制门禁集合取决于模型从哪条路径装载** —— Claude 侧装 `SKILL.md`（`lib/install_skills.sh:18-22`），而 hooks 链与 80 个 bats 以 `prompts` 为权威（`31-auto-advance.sh:41-44`、`32-fallback-guard.sh:47`、`lib/l2-detect.sh:285`）⇒ **行为不可复现，而 rc=0 让 `make check` 掩盖此分叉**。

**修法**：定**单一权威载体**（建议 prompts，回归面最大），skills 降级为生成物或「分叉必须登记」白名单；**覆盖率低于阈值时门禁必须 rc≠0**（把「信息可见」升级为「失败条件」）。

**T12a 处置回填（2026-09 · 步骤 ① 弃用登记）**：按 D7 归一化段集 diff 实测，16 载体中 8 个净对无独有条款，6 个分叉载体共 25 条处置（并入 14 / 弃用 11），逐条对账见 TASK.md「C13 skill-独有条款处置清单」。弃用 11 条登记如下（每条一句理由）：

1. flow-change「每轮最多 3 个问题，等用户回答再继续」——弃用：0-change.md 反问 gate（R3.5）已是强化版（≤3 问 + AC-7 理由 + 反问未完成禁产出 CHANGE.md 硬 gate）。
2. flow-requirement「不能一句话验证的 AC 必须停下反问」——弃用：1-requirement.md 反问 gate 已有同款强化版（含 ❌/✅ 判例）。
3. flow-integration 5.0.x 清理旧措辞——弃用：prompt 5.0.1/5.0.2/5.0.3 强化版已覆盖同语义。
4. flow-integration 孤儿扫描 / L2 归档变体措辞——弃用：prompt 同节强化版覆盖，skill 侧为旧措辞残段。
5. flow-review §4.2 跨模型 spot-check（旧版）——弃用：6-review.md ADR-014 Critical-Triggered 版取代，调度细节由 INDEPENDENT-REVIEW-6.md 承载。
6. flow-review 三轮+第四轮轮次架构正文——弃用：prompt 单轮合并审查（A/B/C/D）语义全覆盖，轮次编排差异非条款。
7. flow-go 查 reference 实际动作示例——弃用：loading-artifacts.md §3 已有同款示例。
8. flow-go 用户视角的取舍表——弃用：GO.md 预算估算挡位菜单（完整/极简/单点/不走）已覆盖同款映射。
9. flow-go 3.3「为什么这步重要」——弃用：说明性文字非强制条款，GO.md 3.x 各节自带判定。
10. flow-go 典型 token 成本表明细——弃用：GO.md 保留摘要，明细委托 README「Token 成本表」段承载。
11. flow-go 路由表/极少数情况/自检措辞变体——弃用：GO.md 已有对应节且含新增演进（Phase Completion Gate / Fallback 路由 / Goal 检测），以 GO.md 为准。

另：flow-go→GO.md（D5 豁免映射特例，5 条独有条款已并入 GO.md）、flow-kit-install 豁免（安装器自包含，无对应 prompt 载体）、skills/flow 不辖（D5 glob 豁免）——三者为登记性豁免，非弃用条款。

---

### 14. 🟡 C14 · 其余补测新增项（择要，按可修性排序）

| # | 项 | 位置 | 实测 |
|---|---|---|---|
| a | **死代码 7 处**（其中 `jq_atomic_write` 自 2026-07-21 登记至今未收口） | 见报告附录 D-3 表 | 生产侧 **7 / 285**；**6 个全仓零引用、仅被测试调用**；`smart_truncate()` **146 行** · `validate_staging_coverage()` **138 行** **双双是 R1 复杂度 Top10 却生产零调用** ⇒ 判复杂度前须先剔死代码 |
| b | **`gate_config` 领域模型 3 语言 4 载体，只有 1 对受门禁** | `dsh-flow-kit/lib/flow-state.js:16,20-44,332` · `l2-review.js:19-26,96` · `common.sh:380-411` · `gate-helpers.sh:26` | JS 侧 17 预设名与 SKILL 侧**今天一致但无门禁守护**；两条路径服务同一份 `.flow-active` ⇒ **同一 change 换路径得不同门禁判定** |
| c | **测试「读」开发者机器安装态**（原报告只记了「写」） | `test/test_l3_pipeline_fix.bats:561-564` 等 **11 个文件** | `[ ! -f "$HOME/.claude/…" ] \|\| cmp -s …` ⇒ 文件不存在时**整体不执行且记 ok**；存在时拿**本机陈旧安装**当基准 ⇒ **同提交异机绿/红不同，且无法从输出区分「真过」与「静默跳过」** |
| d | `Makefile:76` 与 `:84` 口径不一致 | `Makefile:76` = `cp test/*.bats`（**仅顶层**）vs `:84` = `diff -rq`（**递归**） | **门禁红了，但它提示的修复命令修不好子目录漂移** |
| e | **1200 行 JS + 4 个 `*.test.mjs` 不在 `make check` 内** | `package-dsh-plugin.sh:183` 的 `--check` 在 `:232-236` 的 `node --test` **之前 `exit`** | 守卫本身 fail-closed（非 fail-open），问题**只在覆盖** |
| f | 生产门禁**写死了本仓自己的战役目录**，而它会被装进用户项目 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:102` 与 `:90-96` 指向**已归档**的 `.specs/health-fix-2026-09b/`；`install_hooks.sh:291-301` 会安装该脚本 | 用户项目里该判据无意义 |
| g | `.flow-active` 格式知识泄漏 **28 个文件**，`Makefile:251` **手搓解析**同一份 JSON | `Makefile:251` | 格式一变即静默取错值 |
| h | 7 处降级 skip · 1 处硬编码历史 SHA | `test/test_hook_integration.bats:20,21,22,34,35,36,37` · `test/test_l3_review_defects_2026_09.bats:88`（`be138c0`） | 降级 skip 使失败静默转绿 |
| i | 根目录 **2 份陈旧 tarball** | 仓根 | 27.6 MB + 25.7 MB |

---

## What（做什么）

### 止血层（P0 · 必须先做，且 C3 依赖 C2）

0. **C12 门禁 fail-open 修复**（**新增 P0，安全向、独立可修、改动小**）— `independent-review-gate.sh:42-46` 三个子库各补 `declare -f` 存在性断言；`:114` 与 `:65` 的 `|| exit 0` 改 **fail-closed（exit 2 + 具名报文）**；补 bats 反向控制（**ADR-032 越域注明 · L3 阶段 3 m3 修订 2026-09-29**：stop/lib l3-* 三库的 jq 断言为纵深加固，**超出 AC-8 字面范围**——按 ADR-032:17 要求在此显式登记，验收对账时「超出 AC 的改动」以此条为出处，避免无据越域）
0b. **C11 跨层闭环**（**与 C5 同批，不可拆**）— 把预设名/值解析提到生产 `.sh` 并双侧 source；mock 值改 `both`；`check-gate-sync.sh:225-232` 提取器保留值、**比对键值对集合**；加反向控制（`both`→`independent` 必须转红）

1. **C1 沙箱化** — `test/test_check_gate_sync.bats:15` 的 `SKILL` 改为相对路径常量（如 `SKILL_REL`），三个 T02 用例内落到 `$SBX/fk/flow-kit-bundle/skills/flow/SKILL.md`，**照搬同文件 F6 范式**；`teardown` 去掉 `|| true`（还原失败必须报警）；备份路径带 `$$`/`mktemp` 避免共享；**同一改动同步 `flow-kit-bundle/test/` 镜像**（`make test-sync` 或双改 + `make check-test-sync` 验证）
2. **C1 加固** — `Makefile:11` 的 `test` 目标加并发闸（`flock`）；`.git/hooks/pre-push` 改为调用 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（C8 的 A6 项）
3. **C2 正则修复** — `check-path-privacy.sh:72` 的 `PAT` 从「必须尾斜杠」放宽为「路径段边界」，例如 `PAT='/home/[a-z_][a-z0-9_-]*([/"'"' ]|$)'`；**或**保留原口径同时新增一条无尾斜杠的辅助判据，并用既有 `PLACEHOLDER_NAMES` 白名单过滤；**必须补一条 bats 用例钉住「裸 `/home/<realname>`（无尾斜杠）必须命中」**（同时修正 `test/test_path_privacy_gate.bats:35` 探针自带尾斜杠的问题）
4. **C3 短期脱敏** — 6 个 tracked 文件的 30 行真名 → 既有脱敏定式 `/home/<acct>`（**必须在 C2 完成之后做**，否则新泄漏仍拦不住）
5. **C4 删 `|| true`** — `29-independent-review.sh:200`。**3 个字符**，恢复积压 L3 失败告警

### 收口层（P1）

6. **C3 中期** — `git filter-repo` 对 `develop` **与孤儿 `main` 分别**重写（`main` 无共同祖先，常规单线口径会漏掉它）；随后 `gc --prune=now`；复核「对象库任何对象都不再含该串」这一**仓库级**判据
7. **C5 双侧同批修** — mock 契约值改 `"both"`（对齐 `common.sh:408` 与 `goal-parsing.md:23`）；`check-gate-sync.sh:225-232` 的提取器保留 `{...}` 值部分，**比对键值对集合而非名字集合**
8. **C6** — 32 处源码文本断言改行为断言（建议先做 `test_l3_review_defects_2026_09.bats` 的 18 处，该文件同时是 C1 外的高 churn 文件）
9. **C7** — `Makefile:11-12` 合并为一次运行（`--formatter tap | tee /tmp/bats.tap` 或 `--reporters`），用 `${PIPESTATUS[0]}` 取 `rc` 判红
10. **C10** — `shellcheck -S error -f gcc` 按 `rc` 判红；缺工具时 fail-closed
10b. **C14-c 测试读机器安装态** — **11 个文件**的 `[ ! -f "$HOME/.claude/…" ] \|\| …` 软跳过改为**显式 `skip`（须打印原因）或硬失败**；至少先修 `test/test_l3_pipeline_fix.bats:561-564`（当前**真空通过**且**异机结果不同**）
    - **C14-c 实测对账（T05 · 2026-09-29 · 权威表 = TASK.md「C14-c 权威名单」节）**：严格谓词四变体 + 逐文件内容判读重扫 `test/*.bats`（镜像 `flow-kit-bundle/test/` 11 个种子文件 `cmp` 逐字节一致、探针命中同集）——**权威名单 = 5 文件**：`test/test_l3_pipeline_fix.bats:561-563`（变体① 软跳过，本条原文位点证实）· `test/test_independent_review_model.bats:172-183`（变体① 安装态读 + 已显式 skip，合规形态但读机器态）· `test/test_guide_copy_parity.bats:182-195`（变体④+②：`inst="$HOME/.dsh/…"` 赋值 → `[ -d "$inst" ] \|\| skip`）· `test/test_l3_review_defects_2026_09.bats:972-981`（变体④+② 同形，T05 任务块点名示例）· `test/test_flow_active_integrity.bats:60-70`（`~/.claude/flow-kit/…` tilde 展开读安装态——字面探针不辖、内容判读辖，边界判定已标注可复核）。**种子 11 → 实测 5 偏差登记**：(a) 种子误报 6 文件出局——`test_install_jq_guard.bats` / `test_install_layout.bats` / `test_runtime_edit_guard.bats`（HOME 夹具自包含豁免，变体③：`export HOME="$HOME_DIR"` 后全走夹具）、`test_l3_lifecycle_wiring.bats` / `test_stop_report_reminder.bats`（fake-home hermetic 设计，种子命中仅为注释 `~/` 字面）、`test_install_dsh_platform.bats`（`$HOME/.dsh` 仅作输出断言期望串，无安装态文件读/无跳过）；(b) 种子宽口径 grep 把夹具 `$HOME_DIR` **子串**与注释 tilde 一并计入，故 11 ≠ 实测——「11 个文件」字面以本对账为准；(c) 字面探针 B（`[ -d "$HOME`）实测 **0 命中**，`[ -d` 安装态探测真实位点全在变体④ 间接形态（guide_copy_parity:185 / l3_review_defects:974）——印证 L3 重审 r2 m3；(d) 探针 D（`HOME夹具自包含` 终态锚）T05 时点 0 命中属预期（T15 落盘注释后才有）；(e) 漏报侧：探针并集 ⊆ 种子集，无种子外新命中；(f) 下游影响：实测名单含 `test_guide_copy_parity.bats` / `test_flow_active_integrity.bats`（均不在 T15 write_files 现集），`test_runtime_edit_guard.bats` 豁免后无 C14-c 修复面——T15 执行时按权威名单修订文件集（修订属 T15 边界）。本对账为追加登记，不改动上文明文。
10c. **C14-d 门禁与修复命令口径一致** — `Makefile:76` 的 `test-sync` 由 `cp test/*.bats` 改**递归**（或与 `:84` 的 `diff -rq` 口径对齐），使门禁提示的修复命令**真的能修好它报的错**
10d. **C14-e 把 JS 单测纳入 `make check`** — `package-dsh-plugin.sh:183` 的 `--check` 分支移到 `:232-236` 的 `node --test` **之后**再 `exit`（当前 1200 行 JS + 4 个 `*.test.mjs` 完全不在门禁内）

### 结构层（P2 · 可在本 change 内分期，也可显式挂 v2）

11. **C8-①/②** — `prompts/4-dev.md:99-106` 改回纯 `@see pipeline-gates.md`（删内联表）；`skills/flow-dev/SKILL.md` 的 13 处 commit-protocol 内联改为引用 + 在 SKILL 头部写明「本文件是 X 的薄壳」
12. **C8-③** — `l2-reviewer.md:36-198` 与 `L2-blind-review.md` 二选一为源，另一份改为引用（或加内容校验门禁）
13. **C8-④/PC7** — 抽 `_l2_first_deny()`，消除 L2-first 动作链的两份逐字复制
14. **C9** — `29-independent-review.sh` 抽 `main()`；`_l3_build_prompt()` 按阶段拆；`Makefile:162-365` 的 203 行 bash 落成 `tools/check-nfr-portability.sh`；`check-path-privacy.sh` 的 6 个计数器收敛为 1 个 struct 式输出
14b. **C13 载体分叉**（**需 DESIGN 决策，勿走快路径**）— 定单一权威载体（建议 prompts，回归面最大）；skills 降级为生成物或「分叉必须登记」白名单；**把「覆盖率 3/14」从打印信息升级为失败条件**（覆盖率低于阈值即 rc≠0）。反例提示：C2 修好后 `check-path-privacy` 会**由绿转红**，同样地 C13 修好后 `check-gate-sync` 会因覆盖不足而红 —— **是预期行为不是回归**
14c. **C14-a 死代码** — 直接删 `jq_atomic_write`（`common.sh:192`，**唯一彻底死代码**，自 2026-07-21 登记至今未收口）；其余 6 个先**判定「测试专用」是否为设计意图**再决定删或登记。⚠️ **连带**：`smart_truncate()`（146 行）与 `validate_staging_coverage()`（138 行）是 R1 复杂度 Top10 却生产零调用 ⇒ **判复杂度前须先剔死代码**
14d. **C14-f/g** — `check-path-privacy.sh:102` 与 `:90-96` 去掉对**本仓已归档战役目录** `.specs/health-fix-2026-09b/` 的硬编码（该脚本会被 `install_hooks.sh:291-301` 装进**用户项目**）；`.flow-active` 解析收敛到单点，消除 `Makefile:251` 的手搓解析与 28 个文件的格式知识泄漏
14e. **C14-h/i** — 7 处降级 skip 改显式 skip；`test_l3_review_defects_2026_09.bats:88` 的硬编码 SHA `be138c0` 改为从 git 动态取或删断言；清理仓根 2 份陈旧 tarball（27.6 MB + 25.7 MB）
14f. **C14-b `gate_config` 4 载体** — 抽机器可读的单一事实源（平台差异只在派发机制上是正当权衡）；在 `check-gate-sync.sh` 增加 **SKILL ↔ bats ↔ `flow-state.js` 三重预设名比对**

### 反哺层（P0 附带，本 change 的验收前提）

15. `.specs/CONTEXT.md` 技术债段已追加 **TD-115…TD-132**（18 条 🟡）；`.specs/LESSONS.md` M-health 观察段已追加 **2026-09-29 观察块**（9 条）—— 本 change 的 TASK 规划须**读这两处**避免与已登记项重复
16. 补测后追加：`.specs/CONTEXT.md` 已登记 **TD-134**（跨层闭环 = C11/D4-1）、**TD-135**（门禁 fail-open = C12/D4-4）、**TD-136**（14 对载体分叉 = C13/D4-2，需 DESIGN）、**TD-137**（gate_config 3 语言 4 载体 = C14-b/D4-3）、**TD-138**（死代码 7 处 = C14-a）；`.specs/LESSONS.md` 已追加 **L-185**（口径盲区双向性：宽口径→假发现、窄口径→真漏判，零引用函数 0/286 vs 7/285 为证）。C11–C14 与 What 层新增项（0/0b、10b–10d、14b–14f）均须对照上述 TD/L 编号回查，禁止重复立项。

---

## 视觉调性

无 UI 变更。本 change 全部是 shell / Makefile / bats / 文档层改造，**不涉前端**。

---

## 影响面

### 直接改动面

| 路径 | 类型 | 说明 |
|---|---|---|
| `test/test_check_gate_sync.bats` | **双源** | C1 主战场 |
| `flow-kit-bundle/test/test_check_gate_sync.bats` | **镜像** | 必须与上者逐字节一致（`make check-test-sync` 门禁） |
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | **源** | C2 / C9 |
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | **源** | C4 / C8-④ / C9 |
| `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | **源** | C9 |
| `flow-kit-bundle/hooks/stop/lib/common.sh` | **源** | C5（`:408` 生产契约，**只读参照，原则上不改**） |
| `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` | **源** | C5 |
| `Makefile` | **源** | C1 加固 / C7 / C10 |
| `test/test_gate_config_presets.bats` | **双源** | C5 |
| `test/test_path_privacy_gate.bats` | **双源** | C2（补用例 + 修探针） |
| `test/test_l3_review_defects_2026_09.bats` 等 5 文件 | **双源** | C6 |
| `flow-kit-bundle/flow-kit/prompts/4-dev.md` · `flow-kit-bundle/skills/flow-dev/SKILL.md` | **源** | C8-①/② |
| `flow-kit-bundle/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md` · `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md` | **源** | C8-③ |
| `tools/check-nfr-portability.sh` | **新增** | C9 |
| `.specs/CONTEXT.md` · `.specs/LESSONS.md` | 文档 | 已在巡检阶段追加（TD-115…TD-132 / 2026-09-29 观察块） |

### 传播面（**改了源不改这些，门禁会红**）

| 镜像 / 部署 | 同步机制 | 门禁 |
|---|---|---|
| `test/` ↔ `flow-kit-bundle/test/` | `make test-sync`（`cp test/*.bats flow-kit-bundle/test/`，方向 test/ → bundle） | `make check-test-sync`（`diff -rq`） |
| `flow-kit-bundle/hooks/` ↔ `.claude/hooks/` | — | **该镜像对已不存在**（`test -d .claude/hooks` → ABSENT；历史提交 `3e4be39`、`6eba3eb` 已删除）⇒ 本 change **无此同步负担** ✅ |
| `flow-kit-bundle/hooks/` ↔ 6 个部署根 | `sync-hooks.sh` / `install_hooks.sh` | `make check-hooks-sync`（本次实测 6 个部署根**全 ✅**：`~/.claude/hooks`、`dist/dsh-flow-kit/hooks`、`dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks`、`~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks`、`~/.dsh/…/vendor/flow-kit-bundle/hooks`、`~/.config/opencode/hooks`；镜像 48 文件、漂移 0） |
| `dist/` | `package-dsh-plugin.sh` | `make check-dist`（**事后检测**；`dist/` 被 `.gitignore:63` 忽略、`git ls-files dist/ \| wc -l` = 0 ⇒ 不随 clone 传播、无法在 CI 持续断言，见 TD-124/TD-131） |
| `flow-kit-bundle.tar.gz` | 打包产物 | 无门禁；**已陈旧约 3 个月**（mtime 2026-06-22 14:33，12302 条目，见 TD-125） |
| `flow-kit-bundle/` ↔ `dist/dsh-flow-kit/vendor/flow-kit-bundle/` | **第三份完整拷贝**（326 文件） | `make check-dist` 的间接覆盖 |

### 门禁影响

`make check` 现有 9 项先决条件（`Makefile:106`）：`test lint check-validate check-test-sync check-hooks-sync check-dist check-gate-sync check-path-privacy check-nfr-portability`。本 change 会**新增/收紧**其中至少 3 项：

- `test` — C1（沙箱化后应仍全绿，且**并发下也全绿**：这是 C1 的关键验收）
- `check-path-privacy` — C2（收紧后会**由绿转红**，直到 C3 脱敏完成。**这是预期行为，不是回归**）
- `check-gate-sync` — C5（值比较上线后可能暴露新的漂移）

⇒ **`health-fix-2026-09c` 执行期间 `make check` 会有一段「合法红」窗口**，须在 TASK 里显式排序（C2 → C3），避免误判。

---

## 范围排除（这次不做）

| 排除项 | 理由 |
|---|---|
| **抽 `prompts/*.md` ↔ `skills/*/SKILL.md` 的公共门禁到 14/14**（TD-129 / 09-22 #11 残留） | 09b 已把覆盖推到 **3/14** 且**汇总行自曝覆盖度**（诚实处置，不构成假绿）。剩余 11 对是**实质分叉**，需「门禁 vs 显式声明差异」的路线决策，属 **🟡 Scheduled**（TD-129） |
| **8 组 ≤12 行 shell 字面重复的抽取** | shipped-only shell 重复率 **0.487%**（09-22：0.453%，持平），8 组全部 ≤12L ⇒ 按 2.5.5 边界属**提示级**，抽取成本 > 收益且会引入跨文件耦合。已在 LESSONS.md 登记「已评估不处置」 |
| **T3 结构重复 51.3% 的表驱动化**（TD-122） · **T1 smoke 型断言 ~114 位点的清理**（TD-123） | 均属 🟡，且 T1 的 `bash -n`/shellcheck 收敛依赖先确立「lint 与 test 的职责边界」，宜在 C10 落地后再做 |
| **`test/done-validation.bats` 条件 skip 转红**（TD-121） | 🟡；当前不触发（实测 11 ok / 0 skip），属潜伏风险而非现网故障 |
| **`dsh-flow-kit/lib/l2-review.js` ↔ `l2-detect.sh` 跨语言契约测试**（TD-126） | 🟡；「两份实现」是注释明载的**已知权衡**（同族重复已被治理过一次，`gate-helpers-types.sh::_gate_l3_decode_payload` 被写成「委托入口」） |
| **`dist/` 三/四份副本的 CI required 化**（TD-124/TD-131） | 🟡；本仓**无 CI/CD**（`.specs/CONTEXT.md:30` §技术栈），「设 required」需先有 CI，属基础设施决策 |
| **未用依赖清理** | **N/A** — 仓库根无任何清单文件；`dsh-flow-kit/package.json` 无 `dependencies`/`devDependencies`（仅 1 个 `peerDependencies`），无可清理项（TD-132） |
| **`flow-kit-bundle.tar.gz` 清理**（TD-125） | 🟡；但若 C9 触及 `Makefile`，顺手加 `check-tarball-freshness` 属低成本，**待 2-design 决定** |

---

## 验收线（粗粒度，不是 AC）

1. **`make check` 全绿且 `MAKE_CHECK_RC=0`** —— 基线：本次无竞争实跑 **rc=0 · 9/9 全绿 · bats 1116 ok / 0 not ok**
2. **并发安全**：同 worktree 上**同时跑 2 个 `make check`**，结束后 `git status --porcelain` **必须为空**（C1 的核心验收 —— 这是 09b 无法通过的新判据）
3. **C1 回归网**：构造「`teardown` 前 kill」场景，断言源文件**不残留修改**且测试**转红报警**（而非静默）
4. **C2 判据复现**：裸 `/home/<realname>`（**无尾斜杠**）探针**必须命中**且 `rc≠0`；同时既有 `PLACEHOLDER_NAMES` 白名单与 6 条 `SELF_EXCLUDE` **不误伤**（`/home/<acct>/` 占位符仍须放过）
5. **C3 到位**：`git grep -cE '/home/<acct>' -- .` = **0**（tracked 面）；`git rev-list --all --objects` 逐 blob 扫描 = **0**（对象库面，**含 `main` 与所有 refs**）
6. **C4 生效**：注入一个 L3 失败，断言 `module_output "warning" "IR" "backlog L3 failed for phase …"` **实际打印**（当前永不打印）
7. **C5 双侧一致**：mock 的 `"both"` 计数 > 0 且 `"independent"` 归零（或与生产契约显式对齐）；**并构造一次 `"independent"` vs `"both"` 的漂移，断言 `check-gate-sync` 转红**（当前会静默通过 —— 这是 C5 的核心验收）
8. **C6 双向**：重命名 `$content` → `$payload`（行为不变）后断言**不红**；把 `_l3_escape_payload` 的调用点删掉（行为破坏）后断言**转红**
9. **C7 单跑**：`make test` 只运行一次 bats（可用运行时长或 `npx bats` 调用计数验证），且失败时 `rc≠0`
10. **bats 用例数不减**：起点 **1116**；C1/C2/C5/C6 会**净增**用例（≥ 1116，不应减少 —— 任何减少须逐条说明）
11. **镜像零漂移**：`make check-test-sync` / `check-hooks-sync` / `check-dist` 全绿
12. **反哺闭环**：`.specs/health/2026-09-29-HEALTH.md` 的 13 个 🔴 **逐条销账**，且**新增本 change 自己的 🔴 为 0**（09b 的教训：它声称修 4 个 🔴，但执行期间新增了 53 条 TD）

---

## 风险与未知

| 风险 | 说明 | 缓解 |
|---|---|---|
| **C2 → C3 排序错则治标不治本** | C2 修好前做 C3，新泄漏仍拦不住 | **强制顺序 C2 → C3**，并在 TASK 里设为依赖；C3 完成后立即 `make check-path-privacy` 复核 |
| **C2 收紧后 `make check` 会「合法红」** | 30 行真名会被新判据抓到 | TASK 显式标注红窗期；C3 完成后转绿 |
| **C2 宽通配会误伤占位符** | 门禁自身注释已明示禁用 `reference/*`/`skills/*`/`.specs/*` 宽通配（理由：会吞掉 31 处 `<acct>` 字样含 10+ 处真实账号路径，且永久无界） | 放宽 ERE 的同时**必须**保留 `PLACEHOLDER_NAMES` 白名单与 6 条精确 `SELF_EXCLUDE`；新判据上线前先跑「占位符不得命中」负对照 |
| **C1 修法把测试改「软」** | 沙箱化后若不慎把断言也搬进沙箱，可能失去对真实源文件的覆盖 | 照搬同文件 F6 范式即可（它 `cp -r flow-kit-bundle/skills/.` 正是**复制真实生产件**进夹具，覆盖强度不变）；**不要新造写法** |
| **C3 重写历史影响所有协作者** | `develop` 已推送（`origin/develop`）；`main` 是孤儿 | 遵循既有 `privacy-path-scrub-2026-09` 的流程；**必须对 `main` 单独重写**；改写后全量复核 + 通知；本地 `.git/hooks/pre-commit` 的符号链接指向需一并处理（C8/A6） |
| **C5 改 mock 值可能连带真红** | 34 个用例的语义建立在旧值上 | 先改 `check-gate-sync` 值比较（让它能发现漂移），**再**改 mock；每步跑 `make test` |
| **C9 结构改造面大** | 涉及 1051 行门禁脚本 + 336 行 hook + Makefile 内嵌 203 行 bash | 本 change 内**分期**（P2 层），且每步后 `make check` 必须绿；若工期不足可显式挂 v2（须在 STATE.md 登记） |
| **无 CI/CD** | `.specs/CONTEXT.md:30` §技术栈确认本仓**无 CI/CD** | 全部门禁靠本地 `make check`；本 change 不引入 CI（属基础设施决策，超范围） |
| **未知：并发 `make check` 的其他写面** | 本次只普查了 `sed -i`（18 位点）。其他写命令（`> file`、`cp`、`mv`、`rm`、`touch`）对 tracked 路径的写入**未做同等普查** | TASK 阶段补一条普查：`grep -rnE '(>|>>|cp|mv|rm|touch|tee)[[:space:]]+.*flow-kit-bundle/' test/*.bats` 逐条溯源（本次已顺带查过 `> flow-kit-bundle/` / `cp … flow-kit-bundle/` / `mv … flow-kit-bundle/`，**只有沙箱方向的 `cp -r flow-kit-bundle/… "$SBX/…"`，即对源只读** ✅，但口径不完整） |

---

## 路径理由

**建议完整路径 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7**，理由：

1. **触及安全边界（C2/C3）** ⇒ 必须有 1-requirement 把「门禁判据形态」与「历史重写范围」写清，否则 2-design 无法判定边界；C3 涉及**不可逆**操作（重写已推送历史），需要 0-change 的显式确认
2. **触及公共契约（C5/C6）** ⇒ `common.sh:408` 的 `gate_config` 语义、`_l3_escape_payload` 的调用契约，均属跨模块契约，需 2-design 的 § 0.5「既有架构对齐」
3. **触及发布面（C9 的 `Makefile` / `tools/`）** ⇒ TASK 阶段须显式规划镜像同步顺序（`test/` → `flow-kit-bundle/test/` → 6 个部署根 → `dist/`），否则 `make check` 必红
4. **C1 的核心验收（并发安全）无法用单点测试证明** ⇒ 需要 5-test + 6-review 的独立复核（09b 的 `T-FIX-04 F6` 范式即由 L3 审查逼出）
5. **C9 是结构级改造** ⇒ 需要 2-design 的抽象决策（`main()` 拆分边界、计数器收敛形态），不能边写边定
6. **09b 的前例**：同类 health-fix change 走完整 7 阶段，产出 1116 测试 / 21 ✅ 门禁 / 73 条 LESSONS —— **本 change 的规模不低于 09b**（09b 修 4 个 🔴，本 change 要动 13 个）

**不建议走快路径（0→3→4→5）** 的具体反例：C2 单点看是「改一个正则」，但它牵动 `PLACEHOLDER_NAMES` 白名单、6 条 `SELF_EXCLUDE`、`test_path_privacy_gate.bats` 探针形态、以及 C3 的脱敏顺序 —— **四个面的耦合在 0-change 阶段就可见，跳过 1/2 会在 4-dev 时才发现顺序错**。

---

## 附：本 change 与 09b 的关系

| | `health-fix-2026-09b` | `health-fix-2026-09c` |
|---|---|---|
| 日期 | 2026-09-22 创建 → 2026-09-28 归档 | 2026-09-29 创建 |
| 输入 | 09-22 巡检 **56/100 · 13🔴** | 09-29 巡检 **55/100 · 13🔴** |
| 收口 | 4 个 🔴 + 3 组同根因 | 13 个 🔴（含 5 项 09b 未修存量） |
| 产出 | bats 976 → **1116** · `make check` **21 ✅ / 0 ❌** · 新增 **53 条 TD**（TD-062…TD-114）+ **73 条 LESSONS** | 待定 |
| 遗留给 09c | ✅ #6 部分修（值比较失明）· ❌ #3 孤儿 `main`（tip 树 6 行未变）· ❌ #5 mock 自证（漂移 72→92 **扩大**）· ❌ #10 伪单一源 · ❌ #12 flow-dev 内联 · ❌ #13 第三载体 · ⚠️ **AC-8 有条件通过（TD-055）** | **本 change 全数承接** |

> **给本 change 执行者的警告**：09b 声称修 4 个 🔴，但执行期间**新增了 53 条 TD 与 73 条 LESSONS**——即修复动作本身是技术债的主要生产者。本 change 动 13 个 🔴、面更宽，**新增 TD 必须逐条登记且不得与 TD-115…TD-132 重复**。报告中「A1 已造成真实数据丢失」这一条应作为**流程警钟**：本轮巡检是**并行**跑的（3 个子代理 + 3 个 `make check`），**并发度本身就是破坏因子**（见附录 A）。
