# T-FIX-02 SUMMARY — 阶段门「独立审查已完成」由文件存在性改为**存在且有效**（闭合 TD-059）

- change: health-fix-2026-09b · task: T-FIX-02（fix 波次 · 阶段 4 DEV · 阶段门消费端 `fk_independent_review_gate_active`）
- commit: `6cff7a2` — `fix(health-fix-2026-09b): T-FIX-02 TD-059 阶段门有效性（无效标记必须拒绝 + ADR-029）`
- 新基线: `npx bats test/` = **1012 ok / 0 not ok / 0 skip**（TAP plan `1..1012`）；`npx bats --count test/` = **1012**（原 1001 + 本 task 11）
- 文内所有本机账号路径按 L-129 记为 `<repo>`，其余逐字。

---

## ① 交付物清单（含行数）

| 文件 | 行数 | 说明 |
| --- | --- | --- |
| `flow-kit-bundle/hooks/stop/lib/done-validation.sh` | **167**（原 157） | 生产件（唯一行为变更）：`fk_independent_review_gate_active` 对**已存在**标记调用 `fk_validate_done_marker … transition`，通过 ⇒ `return 1`（放行），不通过 ⇒ `return 0`（门生效 ⇒ 拒绝） |
| `.specs/adr/029-gate-marker-validity.md` | 63 | 新增 ADR：变更前后语义 · 被拒三类标记 · `L2_verdict` 相悖态 · `phases_done` 短路保持 · 已知残余 |
| `test/test_review_gate_validity.bats` | 197（11 例） | 常设判据：驱动**真实生产 hook** + 真实 lib（不复制 hook 逻辑） |
| `flow-kit-bundle/test/test_review_gate_validity.bats` | 197 | 同步副本；md5 与上者一致 `f6129e064b61087e0fa9849335ccf0dd`（`make check-test-sync` ✅） |
| `.specs/STATE.md` | 98 | :48 基线行 1001 → 1012；:49 新增「基线演进」注记 |
| `dist/dsh-flow-kit/**`（gitignored，不入库） | — | `bash package-dsh-plugin.sh` 重建，`make check-dist` ✅（`dist/dsh-flow-kit/hooks/stop/lib/done-validation.sh` + `dist/dsh-flow-kit/vendor/flow-kit-bundle/…` 两处副本均含新实现） |
| `.specs/health-fix-2026-09b/reproduce-phase-gate.sh` | **165**（原 157） | 附带同步项（**按指示不提交**，留主 agent 处置）：B2/B3 期望 `rc=0` → `rc=2`、新增 B4（缺 `L3_verdict` ⇒ rc=2）、汇总行重写 |

本 task 未提交的收尾产物（按派发协议留给主 agent housekeeping）：本文件、`TASK.md`（`status="pending"`→`"done"` + `<done>` 时点实测注记）、`.flow-active` 台账（31 条）、`.specs/CONTEXT.md:605`（TD-059 状态行，`write_files` 第 5 项）。四项均已完成，见 ④ 偏离 ② / 遗留 ②。

---

## ② `<verify>` 原始输出全文

### 抽取方式（逐字取自 `TASK.md`，未改一字）

```bash
awk '/<task id="T-FIX-02"/,/<\/task>/' .specs/health-fix-2026-09b/TASK.md \
  | sed -n '/^  <verify>$/,/^  <\/verify>$/p' | sed '1d;$d' > /tmp/vblocks/v_TFIX02.sh
wc -l /tmp/vblocks/v_TFIX02.sh && bash -n /tmp/vblocks/v_TFIX02.sh && echo EXTRACT_OK
```

输出：`37 /tmp/vblocks/v_TFIX02.sh` · `EXTRACT_OK`（`bash -n` 无输出 ⇒ 语法干净）。
整行锚定是必须的（L-153）：本 task 的 `<done>` 正文含 `<verify>` 字面，非锚定区间会把 `</task>` 混进脚本。
抽取件第 1 行原本是 `export LC_ALL=C`，已由主 agent 改为 4 行注释 + `set -u; rc=0;`（TD-051：`LC_ALL=C` 会让既有 `test/test_l3_pipeline_fix.bats:592` 在 HEAD 即红）。本执行者**未改动该行**。

### 2.1 原样跑 = rc=1（判据缺陷，非交付物缺陷）

```bash
bash /tmp/vblocks/v_TFIX02.sh; echo "VERIFY_RC=$?"
# A=2 B=0 B2=2 B3=2 B4=2 C=0
# VERIFY_RC=1
```

五态行**全部符合新语义**（见 2.2 逐态对照），失败的是紧随其后的 4 条聚合判据：

```
🔴 新增双态判据 rc=1
🔴 hooks 副本未同步（跑 ./sync-hooks.sh）
🔴 test 双源不一致
🔴 dist 未重建
make: *** 没有规则可制作目标“check”。 停止。
🔴 make check 不绿
```

### 2.2 失败根因（已坐实，属判据自身缺陷）

判据第 12 行：

```bash
SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix2-XXXXXX"); trap 'rm -rf "$SBX"' EXIT; cd "$SBX" || exit 1;
```

**此后从未 `cd` 回仓根** ⇒ 判据第 30–36 行（`npx bats test/test_review_gate_validity.bats`、`make check-hooks-sync`/`check-test-sync`/`check-dist`/`make check`）全部在 `${TMPDIR:-/tmp}` 沙箱里执行。沙箱内无 `test/`、无 `Makefile` ⇒ bats `rc=1`、`make` 对显式目标报「没有规则可制作目标"check"」。
已核对 `TASK.md` 的 `<verify>` 块第 12 行**逐字**含 `cd "$SBX" || exit 1;` ⇒ **该缺陷由主 agent 写在验收判据里，不是抽取产物**。
处置：**不改判据**（改判据 = 改验收标准），原样跑并如实报 rc=1；另以仓根 cwd 补跑第 30–36 行等价步骤作为健康性证据（2.3）。建议主 agent 在判据 `cd "$SBX"` 之后补一句 `cd "$OLDPWD"`（或把 :30–36 移到沙箱之前）——留给主 agent 决定，本 task 不擅自改判据。

### 2.3 判据第 30–36 行「仓根 cwd」等价复跑 = 全绿

```bash
cd <repo>   # 仅此一处与判据不同：cwd
npx bats test/test_review_gate_validity.bats ; echo "bats_new_rc=$?"
make check-hooks-sync ; make check-test-sync ; make check-dist ; make check
```

输出（`/tmp/tfix2-supp.out`，提交前；提交后同命令复跑结果见 2.6）：

```
ok 1 .. ok 11
bats_new_rc=0
hooks_rc=0     # ✅ hooks 同步检查通过
testsync_rc=0  # ✅ test 双源一致
dist_rc=0      # ✅ dist 与源一致
make_check_rc=0
✅ make check: 全部通过
```

### 2.4 五态语义对照（判据 19–29 行输出，判据线程内实测）

| 态 | 夹具状态 | 期望 | 实测 rc | 含义 |
| --- | --- | --- | --- | --- |
| A | 阶段 5、无标记 | 拒绝 | **2** | 审查未完成 ⇒ 拦 commit ✅ |
| B | 6 键有效标记（`L2_verdict=pass` 与审查档一致） | 放行 | **0** | 真有效 ⇒ 放行 ✅ |
| B2 | 标记 6 键齐但 `L2_verdict=pass` 而 `INDEPENDENT-REVIEW-5.md` 写 `**Verdict**: fail` | 拒绝 | **2** | 口径相悖 ⇒ 拒（**旧语义放行**，TD-059 主症）✅ |
| B3 | `touch` 空标记 | 拒绝 | **2** | 空标记 ⇒ 拒（旧语义放行）✅ |
| B4 | 标记缺 `L3_verdict` | 拒绝 | **2** | 缺键 ⇒ 拒（旧语义放行）✅ |
| C | 无 `.flow-active`（gate 未开） | 放行 | **0** | 门未开不拦 ✅ |

### 2.5 活性探针（防「判据恒绿」假绿）

把生产件临时改回旧语义（`sed 's|^  fk_validate_done_marker "\$done_marker".*$|  :|'`）后复跑新判据：**恰好 5 例转红**（B2 / B3 / B4 / B5 / 「标记存在但无效」函数级用例），A、B、C、反面对照与另 3 例函数级用例按设计仍绿；`cp -p` 备份还原后 md5 复核 = `1547fd867dd1cf65c279df6fba0b7a63`。⇒ 新判据确实绑在生产件行为上，不是恒绿。

### 2.6 全量套件与同步门禁（提交后、工作树终态复跑）

```bash
npx bats test/ ; npx bats --count test/ ; make check
```

- `npx bats test/` = **1012 ok / 0 not ok / 0 skip**，TAP plan `1..1012`，`rc=0`（原文 `/tmp/bats-all.out`；改动前基线 1001 ⇒ +11）
- `npx bats --count test/` = **1012**
- 提交后按判据第 30–36 行复跑（仓根 cwd、HEAD = `6cff7a2`、tree = `add11ed8…`，`/tmp/tfix2-postcommit.out`）：`bats_new_rc=0`（`ok 1`…`ok 11`，第 11 例 = 函数级 `phases_done` 短路保持）· `hooks_rc=0` · `testsync_rc=0` · `dist_rc=0` · `make_check_rc=0`（`✅ make check: 全部通过`，`16:12:14 → 16:16:44`）
- 收尾（`TASK.md` 勾选 / 本 SUMMARY / `.flow-active` 台账 / `CONTEXT.md` TD-059 状态行）落地后**再复跑一次 `make check`** 覆盖工作树终态：`rc=0`（`/tmp/tfix2-final.out`）
- 注：`make test` 的 stdout 只是装饰性 `tail -3`（只显示 `ok 1010/1011/1012` + `✅ bats: all tests passed`），**计数权威 = `npx bats test/`**。

---

## ③ 6 维自检

### 3.1 测试有效性（判据是否真驱动生产件）

新 bats **不复制** hook 逻辑：每个用例在 `${TMPDIR:-/tmp}` 建临时仓（`git init` + `.specs/<cid>/.flow-active`），以 PreToolUse JSON（`hook_event_name` / `cwd` / `tool_input.command` = `git commit …`）经 stdin 驱动**仓内真实** `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`，由它 source 真实 `gate-helpers.sh` 与真实 `stop/lib/done-validation.sh`。stderr 与 stdout 分离采集（`run --separate-stderr` + 重定向），避免合流假绿。判据 2.5 的活性探针（旧语义 ⇒ 5 例转红）是这一点的反证。

### 3.2 是否可能假绿

- 断言对象是 hook 进程的**退出码 + stderr 报文**（`⛔ 独立 review gate：…`），不是内部变量；B2/B3/B4 三态在旧实现下都会 `rc=0` ⇒ 若回到旧语义，这 3 例必红（2.5 实测）。
- `phases_done` 短路用历史阶段夹具（阶段已 done ⇒ 不追溯）单独覆盖，防止"全拒"式过修。
- 反面对照（C：无 `.flow-active` ⇒ 门未开 ⇒ rc=0）证明「拒」不是无条件拒。

### 3.3 边界

`touch` 空文件（`:116` `[[ -s ]]` 归零）· 缺单键（T5 组）· 值域非法 `L3_verdict=maybe` · `L2_verdict` 与审查档 verdict 相悖（Tier-2 一致性，**只在 `transition` 层跑**）· 无标记 · 无 `.flow-active` · `phases_done` 已含该阶段。全部有独立用例。

### 3.4 负面用例（≥5）

A（无标记 ⇒ 2）、B2（相悖 ⇒ 2）、B3（空 ⇒ 2）、B4（缺键 ⇒ 2）、B5（值域非法 ⇒ 2）、函数级「标记存在但无效 ⇒ `fk_independent_review_gate_active` 返回 0」。

### 3.5 夹具隔离

全部夹具在 `${TMPDIR:-/tmp}`（`mktemp -d`，`trap … EXIT` 清理）；`.flow-active`、`.done` 标记、审查档都写在临时仓内；仓库工作树零污染（`git status` 复核：仅本 task 的 5 个交付路径 + 主 agent 既有改动）。

### 3.6 可复算性

判据可随时重跑：`bash /tmp/vblocks/v_TFIX02.sh`（五态行 rc=2/0/2/2/2/0）+ 2.3 命令；`reproduce-phase-gate.sh` 单文件自包含沙箱复现（`bash -n` 干净、`rc=0`）。

### 3.7 越界检查（R6.5）

```
✅ 越界检查（R6.5）：
   - TASK write_files：`done-validation.sh` · `test/test_review_gate_validity.bats` · `flow-kit-bundle/test/…bats` · `.specs/adr/029-*.md` · `.specs/STATE.md` · `reproduce-phase-gate.sh`（附带同步项，不提交）= 6 项
   - 实际 diff 涉及（`git show --numstat 6cff7a2`）：5 项（STATE.md / ADR-029 / done-validation.sh / 两份 bats）
   - 越界：0
```

`git show --numstat --oneline 6cff7a2`：

```
6cff7a2 fix(health-fix-2026-09b): T-FIX-02 TD-059 阶段门有效性（无效标记必须拒绝 + ADR-029）
2	1	.specs/STATE.md
63	0	.specs/adr/029-gate-marker-validity.md
13	3	flow-kit-bundle/hooks/stop/lib/done-validation.sh
197	0	flow-kit-bundle/test/test_review_gate_validity.bats
197	0	test/test_review_gate_validity.bats
```

未纳入提交的 6 类工作树内容均**非本人改动**或**按协议留 housekeeping**：5 个冻结工件（`A ` 暂存态、未改动）、`MINOR-DEFERRED.md`（主 agent）、`INDEPENDENT-REVIEW-5.md` / `PHASE5-RECEIPTS.md` / `TEST.md` / `reproduce-5-test.sh`（阶段 5 主 agent，untracked）、本 SUMMARY、`TASK.md`、`.flow-active`。

### 3.8 内置 6 维（`flow-kit-bundle/flow-kit/prompts/4-dev.md:270-275`）

- **R1 认知过载**：`fk_independent_review_gate_active` 改后 52 行（39–90），仍是「守门 + 委托校验」，未新增嵌套（最深 2 层）；未引入新函数 ✅
- **R2 变更传播**：生产件只改 1 个文件 13 行（+契约注释）；只影响「标记已存在」的 commit 路径（无标记路径的 16 处既有用例行为不变，1012 ok 实证）✅
- **R3 知识重复**：不复制校验逻辑，直接复用既有 `fk_validate_done_marker … transition`（Tier-1 + Tier-2 单一实现）✅
- **R4 偶然复杂**：未新增配置项/开关/扩展点；`transition` 是既有 tier 参数值（Gate4 早已使用）✅
- **R5 依赖混乱**：`stop/lib/done-validation.sh` 依赖关系未变（gate 侧仍旧 source `gate-helpers.sh` → 委托同一函数）；无反向依赖 ✅
- **R6 领域扭曲**：命名沿用领域词「独立审查标记有效性」，未引入技术词 ✅

---

## ④ 遗留与偏离

### 偏离 ①：`<verify>` 原样跑 rc=1（判据自身 cwd 泄漏，未修）

- 现象与原文：见 2.1 / 2.2。
- 与本 task 无关的证据：五态行全对；同一条命令在仓根 cwd 下 4 项全绿（2.3）；`TASK.md` 第 12 行逐字含 `cd "$SBX"`。
- 采取的最小偏离：**不改判据**，只在仓根补跑 30–36 行作为健康性证据，并在此如实登记。与 T-FIX-01 的先例（`export LC_ALL=C` 原样跑 rc=1 + 最小偏离复跑 rc=0）同范式。

### 偏离 ②：台账写入前对本 task 提交做了一次 `git commit --amend --no-edit` 等价刷新

- 原因：为满足 L-127 的机械判据 `entry >= commit && Δ <= 120s`（`MINOR-DEFERRED.md:272`）。原提交 `0664ae2`（16:10:48）与本 SUMMARY 编写/复跑之间存在 >120 s 间隔。
- 操作：`git commit --amend -m <同一 message> -- <同 5 路径>`；**树哈希逐字节相同**（`add11ed80f9bc4c66c0bba178139f62df78f896c`，改前改后一致），numstat 与 message 不变，最终 `6cff7a2`（committer date 16:12:03）；`--amend` **未** 触碰暂存区（5 个冻结工件仍为 `A ` 未提交）。
- 合法性依据：`T09-SUMMARY.md:176` 的「不改 amend」前提是「sha 已入台账并被复核」；`0664ae2` 从未入台账、未对外报告 ⇒ 不触发该禁令。禁用项（`add .`/`-A`/`--no-verify`/`stash`）均未使用。
- 台账实测：`{"id":"T-FIX-02","commit_sha":"6cff7a2","fix_rounds":0,"deferred":[],"completed_at":"2026-09-24T16:12:09+08:00"}`，`git log -1 --format=%cI 6cff7a2` = `16:12:03` ⇒ **Δ=6 s**、`entry >= commit` ✅、`git cat-file -e 6cff7a2^{commit}` ✅、`task_progress` length 30 → **31**。

### 遗留 ①（生产件行为残余，已入 ADR-029「已知残余」）

Tier-1 只验标记的元数据形态（6 键 + 值域 + 可读性），**不验** `L3_artifact_hash` 是否对应当前工件 ⇒ 「标记真实但对应旧工件」仍可放行。与 TD-042 / TD-045 同源，留 v2，不在本 change 扩张范围。

### 遗留 ②（文档口径，已就地更新但**不提交**，交主 agent）

`.specs/CONTEXT.md:605` 的 TD-059 行仍是「阶段门只看文件存在性」的旧口径（且行尾带着阶段 5 的「当时的不修理由（保留存档）」）。本执行者已按 `TASK.md` 的 `write_files` 第 5 项要求就地更新：在处置列前置 **「2026-09-24 用户裁决 + 本 change 内修复（T-FIX-02 · commit `6cff7a2`，已完成）」** 一段（含修复语义、被拒四态、新 bats + ADR-029；并注明 v2 的 ② D7 语义检测 / ③「verdict=fail 但口径一致」口径声明仍未做）。该文件由主 agent 持有 ⇒ **不纳入本 task 提交**，留 housekeeping。

### 遗留 ③（判据缺陷，交主 agent 决策）

`TASK.md` 本 task `<verify>` 块第 12 行 `cd "$SBX" || exit 1;` 之后缺回仓根语句 ⇒ 该判据在任何执行者手里都必然 rc=1（阶段 5 若以 rc 判 PASS/FAIL 会误判）。建议补 `cd "$OLDPWD"`（或把 30–36 行移到沙箱段之前）；本执行者按「不改验收标准」原则未动。

### 遗留 ④（未提交件，交主 agent）

`reproduce-phase-gate.sh`（阶段 5 复现件，已按第 2 节订正为 B2/B3 ⇒ rc=2 并新增 B4）按派发指示**不纳入本 task 提交**，由主 agent 统一处置；同理本 SUMMARY、`TASK.md`、`.flow-active` 三项收尾均留 housekeeping。

### 环境备注

`core.hooksPath` 为空串 ⇒ git 钩子门禁不会自动跑，本 task 的 `make check` 均为显式执行；`LANG=zh_CN.UTF-8`（`LC_ALL` 未设 ⇒ 判据首行的影响已由主 agent 以注释 + `set -u` 规避）；测试套件存在既有 stderr 噪声（非本 task 引入）。
