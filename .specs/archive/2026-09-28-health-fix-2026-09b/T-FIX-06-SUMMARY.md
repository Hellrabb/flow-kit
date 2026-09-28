# T-FIX-06 SUMMARY — 隐私门禁「0 实际扫描」fail-closed + mktemp 立即终止 + 扫描面措辞精确化（F-19 / F-20 / F-18）

> change: `health-fix-2026-09b` · phase: 4-dev · task: T-FIX-06
> commit: `421640a4582445c5d609a7825a2d88011600e9df`
> commit `%cI`: `2026-09-25T02:11:53+08:00`
> 执行者时点: 2026-09-25

---

## 1. 任务与范围

### 原契约 finding（TASK.md T-FIX-06）

- **F-19（🟡 残余假绿）**：隐私门禁 `check-path-privacy.sh` 在所有 tracked 文件全部命中 `SELF_EXCLUDE` 时，`scan_file` 实际执行 0 次，但脚本仍打印 `✅` + `清单外命中 0 条` + rc=0 ——「0 实际扫描」的假绿。
- **F-20（🟡 mktemp 失败被吞）**：`mktemp_checked()` 内部 `exit 1` 位于命令替换 `$(mktemp_checked)` 中，只退出子 shell、脚本继续执行，变量退化为空串，产生 3 条冗余 🔴 mktemp 报文且不终止。

### 主 agent 追加 finding（m00142 · 用户裁决 option ②）

- **F-18（措辞误导 · 零行为变更）**：`SCAN_SURFACE='工作树'` 误导读者以为未 `git add` 的未忽略文件也在扫描面内。用户裁决 option ② = **仅措辞精确化、零行为变更**：`SCAN_SURFACE` → `'工作树（git index：已 add / 已提交）'`，单变量 5 处打印共用 ⇒ 单点改动，**不给 `git ls-files` 加 `--others`**（那会改变扫描面 = 行为变更，违反 option ②）。
  - **F-18 不是原契约里的条目**，是主 agent 在 T-FIX-06 执行过程中（m00142）追加的，经用户裁决后并入本任务同一提交。

### 范围声明

- 生产件：`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`
- 测试件：`test/test_path_privacy_gate.bats` + 镜像 `flow-kit-bundle/test/test_path_privacy_gate.bats`
- 台账基线：`.specs/STATE.md`（bats 计数 1025 → 1029）

---

## 2. 逐文件改动 + `git show --numstat`

```
$ git show --numstat --oneline 421640a
421640a fix(health-fix-2026-09b): T-FIX-06 隐私门禁 0 实际扫描 fail-closed + mktemp 立即终止 + 扫描面措辞精确化（F-19/F-20/F-18）
2	1	.specs/STATE.md
55	9	flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
72	0	flow-kit-bundle/test/test_path_privacy_gate.bats
72	0	test/test_path_privacy_gate.bats
```

### `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（+55 / −9）

- **F-20**：`mktemp_checked()` 函数体 `exit 1` → `return 1`（stderr 报文 `🔴 无法完成扫描：mktemp 失败` 原样保留）；4 个调用点（3 初始化 `TMP_ALLOWLIST`/`TMP_CANDIDATES`/`TMP_HITS` + 1 汇总段 `TMP_ALLOWLIST_KEYS`）改为 `$(mktemp_checked) || exit 1`。
  - **注**：契约 TASK.md `<action>` 写「三调用点」，但生产件实为 **4 处**（多一处汇总段 `TMP_ALLOWLIST_KEYS`）。执行者按 4 处全改，`<done>` 表述已修正为「4 个调用点」。
- **F-19**：扫描循环前 `SCANNED_COUNT=0` 初始化；`is_self_exclude` 检查后、`scan_file` 调用前 `SCANNED_COUNT=$((SCANNED_COUNT + 1))`；循环后 `if [ "$SCANNED_COUNT" -eq 0 ] && [ "$CANDIDATE_COUNT" -gt 0 ]` ⇒ 打印自证区（`候选文件 N 个` + `实际扫描 0 个`）+ `🔴 候选面经自排除后为空（所有候选均为自排除成员）` + `exit 1`（**不打印** `清单外命中 0 条` / `✅`）；正常汇总段在 `候选文件 N 个` 行后追加 `实际扫描 ${SCANNED_COUNT} 个`。
- **F-18**：`SCAN_SURFACE='工作树'` → `'工作树（git index：已 add / 已提交）'`（单变量，5 处打印共用）；相邻注释 `:142`「扫本地工作树」→「扫本地工作树内 git index（已 add / 已提交）的 tracked 文件」；候选枚举注释 `:295` 更新；文件头注释块追加 F-19/F-20/F-18 说明段。
- **冻结语义未动**：`SELF_EXCLUDE`（`:67-74`）6 成员不变、`PAT` 不变、允许清单读序（常设 > change 副本 > 皆缺 fail-closed）不变、`候选文件 N 个` 自证行保留（#14 断言它与 `git ls-files` 计数一致）。

### `test/test_path_privacy_gate.bats` + 镜像（各 +72 / −0）

- 新增 4 例（#21–#24，追加在既有 #20 之后）：
  - **#21 F19 坏态**：fixture 内 tracked 全为 `SELF_EXCLUDE`（stage SUT_REL + ALLOW_REL）⇒ rc≠0、output 含「实际扫描 0 个」、不含「清单外命中 0 条」/`✅`。
  - **#22 F19 好态**：干净 fixture（docs/notes.md + allowlist）⇒ rc=0、output 含「实际扫描 M 个」且 M≥1、M≤reported、reported==`git ls-files` 计数。
  - **#23 F20 坏态**：`BAD_TMPDIR`（`run_sut_env` 传入不存在的 TMPDIR）⇒ rc≠0、`$stderr` grep -c 'mktemp 失败' == 1。
  - **#24 F20 好态**：正常 TMPDIR 干净 fixture ⇒ rc=0、无 mktemp 失败报文。
- F-18 钉住断言追加进既有 #14（F2 好态）：`[[ "$output" == *"扫描面: 工作树（git index：已 add / 已提交）"* ]]`（未新增 `@test`，计数不变）。

### `.specs/STATE.md`（+2 / −1）

- 基线行：`1025 ok` → `1029 ok`；基线演进追加 `1025→1029 = +4 F19/F20 双态`。

---

## 3. 红-绿原文（TDD 判别式证据）

执行命令：`npx bats test/test_path_privacy_gate.bats`（修复前 = 红 / 修复后 = 绿）。

### 修复前（红）— `not ok` 原文

```
not ok 21 F19 坏态：tracked 全为 SELF_EXCLUDE 时 0 实际扫描 fail-closed
# (in test file test/test_path_privacy_gate.bats, line 311)
#   `[ "$status" -ne 0 ]' failed
# rc=0（fail-open，坏态仍报 ✅）

not ok 22 F19 好态：干净夹具实际扫描 M≥1 且 M≤reported
# (in test file test/test_path_privacy_gate.bats, line 326)
#   `[[ "$output" == *"实际扫描"* ]]' failed
# （字符串缺失：生产件无「实际扫描」自证行）

not ok 23 F20 坏态：坏 TMPDIR 下恰 1 条 mktemp 报文且 rc≠0
# (in test file test/test_path_privacy_gate.bats, line 345)
#   `[ "$cnt" -eq 1 ]' failed
# cnt=0（$output 无报文 —— 报文在 $stderr；修正测试 grep $stderr 后 cnt=3 = 4 调用点中 3 个初始化点各报 1 条冗余）

ok 24 F20 好态：正常 TMPDIR 无 mktemp 报文
```

### F-18 钉住断言 — 修复前（红）

执行命令：`npx bats --filter 'F2 好态' test/test_path_privacy_gate.bats`

```
not ok 1 F2 好态：候选文件数落进自证行且与 git ls-files 一致
# (in test file test/test_path_privacy_gate.bats, line 322)
#   `[[ "$output" == *"扫描面: 工作树（git index：已 add / 已提交）"* ]]' failed
# （旧措辞「工作树」未含精确化后缀）
```

### 修复后（绿）

```
ok 21 F19 坏态：tracked 全为 SELF_EXCLUDE 时 0 实际扫描 fail-closed
ok 22 F19 好态：干净夹具实际扫描 M≥1 且 M≤reported
ok 23 F20 坏态：坏 TMPDIR 下恰 1 条 mktemp 报文且 rc≠0
ok 24 F20 好态：正常 TMPDIR 无 mktemp 报文
ok 14 F2 好态：候选文件数落进自证行且与 git ls-files 一致
```

全量：`npx bats test/` → 1029 ok / 0 not-ok / count=1029 / rc=0。

### 测试判据修正说明（硬规则 2 合规）

- **F-20 坏态**：初版测试 grep `$output`（stdout），但 `run --separate-stderr` 下 mktemp 报文走 stderr ⇒ `$output` 无报文 ⇒ cnt=0。修正为 grep `$stderr`（测试判据修正，非生产件修正）。修正后诊断显示 cnt=3（未修复生产件 = 4 调用点中 3 个初始化点各报 1 条冗余），证明 F-20 确实存在。生产件修复（`return 1` + `|| exit 1`）后 cnt=1（汇总段 `TMP_ALLOWLIST_KEYS` 也被 `|| exit 1` 拦截，但它在初始化失败后不会到达 ⇒ 实际坏 TMPDIR 只触发第一个初始化点即 exit 1）。
- **F-19 好态**：初版断言 `scanned == reported`，但 SUT 自身 + allowlist 在任何 fixture 中都是 `SELF_EXCLUDE` 成员 ⇒ `SCANNED < CANDIDATE` 是正确设计（自排除 = 不扫描），不是 bug。修正为 `scanned ≥ 1 && scanned ≤ reported`。这是测试判据修正（保留生产件语义），非生产件弱化（硬规则 2 合规）。

---

## 4. `<verify>` 原样复跑 stdout + rc

逐字复跑 `TASK.md` `<verify>` 块（`set -u` 脚本）：

```
   （诊断）F-19 坏态 rc=1 追踪文件=6
   （诊断）F-20 坏态 rc=1 mktemp 报文=1 条
bats: 1029 ok / 0 not-ok / count=1029
```

- `bash -n` 语法检查通过
- `grep 'SCANNED_COUNT'` ✓ · `grep '实际扫描'` ✓ · `grep 'mktemp_checked) || exit 1'` ✓
- F-19 坏态：rc=1（6 tracked 全 SELF_EXCLUDE）、output 含「实际扫描 0 个」、不含「清单外命中 0 条」/✅
- F-20 坏态：rc=1、mktemp 报文恰 1 条
- `npx bats test/test_path_privacy_gate.bats` rc=0（无 not ok）
- `npx bats test/` rc=0（1029 ok / 0 not-ok / count=1029）
- 真实仓 `make check-path-privacy` rc=0（候选 1594 / 实际扫描 1588 / 清单外命中 0 / ✅，F-18 措辞可见）
- `make check-hooks-sync` / `check-test-sync` / `check-dist` / `make check` 全 rc=0

**verify-rc=0**

---

## 5. 设计要点

### F-19：为什么 `SCANNED_COUNT` 在 `is_self_exclude` 检查**之后**自增

`SCANNED_COUNT` 计的是「实际调用了 `scan_file` 的次数」。`is_self_exclude` 命中 ⇒ `continue`（跳过 `scan_file`）⇒ 不计入 `SCANNED_COUNT`。因此自增点必须在 `is_self_exclude` 检查通过之后、`scan_file` 调用之前。坏态（全自排除）⇒ `SCANNED_COUNT` 始终 0 + `CANDIDATE_COUNT > 0` ⇒ fail-closed。

### F-20：为什么 `return 1` 而非保留 `exit 1`

`mktemp_checked()` 被 `$(mktemp_checked)` 命令替换调用。bash 命令替换在子 shell 中执行，`exit 1` 只退出子 shell，父脚本继续（变量 = 空串）。`return 1` 同样退出函数，但配合调用点 `$(mktemp_checked) || exit 1`，`||` 捕获非零返回值 ⇒ 父脚本 `exit 1`。stderr 报文 `🔴 无法完成扫描：mktemp 失败` 在函数内 `echo >&2` 原样保留。

### F-18：为什么不给 `git ls-files` 加 `--others`

用户裁决 option ② = **仅措辞 · 零行为变更**。`git ls-files`（无 `--others`）= index + 已提交 tracked 文件。加 `--others --exclude-standard` 会把未 add 的未忽略文件也纳入扫描面 = 行为变更（扫描面扩大），违反 option ②。措辞精确化只是把已有的扫描面定义用更精确的文字标注，让读者不再误以为 untracked 也在面内。

---

## 6. 门禁 rc 一览

| 门禁 | rc | 关键输出 |
|---|---|---|
| `bash -n check-path-privacy.sh` | 0 | 语法通过 |
| `npx bats test/test_path_privacy_gate.bats` | 0 | 24/24 ok（含 #21–#24 新增 + #14 F-18 断言） |
| `npx bats test/` | 0 | 1029 ok / 0 not-ok / count=1029 |
| `npx bats --count test/` | 0 | 1029 |
| `make check-path-privacy`（真实仓） | 0 | 候选 1594 / 实际扫描 1588 / 清单外命中 0 / ✅ |
| `make check-hooks-sync` | 0 | `✅ hooks 副本一致（漂移 0）` |
| `make check-test-sync` | 0 | `✅ test 双源一致` |
| `make check-dist` | 0 | `✅ check-dist: dist 与源一致` |
| `make check` | 0 | `✅ make check: 全部通过` |
| `<verify>` 整块 | 0 | 逐字复跑 rc=0 |

---

## 7. 越界检查（R6.5）

- TASK `<write_files>` 声明面：`check-path-privacy.sh`、`test/test_path_privacy_gate.bats`、`flow-kit-bundle/test/test_path_privacy_gate.bats`、`.specs/STATE.md`（计数变化时）。
- 实际 diff（`git show --numstat 421640a`）：4 文件，+201 / −10，全在声明面内。
- 越界：**0** ✅。
- 工作树 pre-existing M（`MINOR-DEFERRED.md` / `REVIEW.md` / `TASK.md`，主 agent housekeeping）未纳入提交（显式 `git add` 4 路径）。

---

## 8. 沿用既有抽象 grep（R6.4）

- `SELF_EXCLUDE` 数组 + `is_self_exclude()`：既有机制（T17/T08 定稿），沿用，未改成员。
- `scan_file()`：既有扫描函数，沿用，未改签名/逻辑。
- `CANDIDATE_COUNT` / `git ls-files` 候选枚举：既有机制，沿用。
- `mktemp_checked()`：既有函数，仅改 `exit 1`→`return 1` + 调用点 `|| exit 1`（函数签名/报文不变）。
- `SCAN_SURFACE` 变量：既有单变量打印模式，沿用（仅改值，不改打印接线）。
- 三态汇总块（`候选文件 N 个` / `清单外命中 X 条` / `✅`/`🔴`）：既有结构，沿用（F-19 在 `候选文件` 行后追加 `实际扫描 M 个`，不删不改既有行）。

---

## 9. 6 维自查

- **R1 认知过载**：`check-path-privacy.sh` 548 → 594 行。F-19 新增逻辑集中在扫描循环（~15 行）+ 坏态分支（~10 行）；F-20 改动分散在 4 调用点（各 +`|| exit 1`）；F-18 单点。无认知过载。
- **R2 变更传播**：仅 `<write_files>` 声明文件被改 ⇒ 无越界。
- **R3 知识重复**：`SCAN_SURFACE` 单变量 5 处打印共用 ⇒ F-18 单点改动，无重复。`mktemp_checked` 函数唯一源，4 调用点统一 `|| exit 1` 模式。
- **R4 偶然复杂**：F-19 `SCANNED_COUNT` 自增点选择（`is_self_exclude` 后）是语义必须（计实际 `scan_file` 次数），非冗余。F-20 `return 1` + `|| exit 1` 是命令替换语义的最小修复，无「以后可能用到」的扩展。
- **R5 依赖混乱**：N/A（bash 脚本，无新依赖）。
- **R6 领域扭曲**：变量名沿用（`SCANNED_COUNT`/`CANDIDATE_COUNT`/`SCAN_SURFACE`/`mktemp_checked`）。

---

## 10. 破坏性变更评估（R4.6）

- 删除既有代码 ≥ 5 行：**否**（`exit 1`→`return 1` 是 1 字符级改动；`SCAN_SURFACE` 值替换）。
- 行为变更：F-19 坏态从 rc=0 变 rc=1（**故意** = 修假绿）；F-20 坏 TMPDIR 从 3 条冗余报文+继续 变 1 条报文+exit 1（**故意** = 修吞掉）；F-18 仅措辞（零行为变更，用户裁决 option ②）。
- 引用图：`check-path-privacy.sh` 被 `make check-path-privacy` + `make check`（先决条件）+ bats 24 例 + `<verify>` 引用；rc∈{0,1} 契约在好态不变（真实仓 rc=0 为证），坏态从假绿变正确 fail-closed。
- 回归覆盖：F-19 双态（#21/#22）+ F-20 双态（#23/#24）+ F-18 钉住（#14）+ 全量 1029 例全绿。

---

## 11. 遗留与未坐实项

- **契约「三调用点」 vs 生产 4 处**：TASK.md `<action>` 写「三调用点 `|| exit 1`」，但生产件 `check-path-privacy.sh` 实有 **4 处** `mktemp_checked` 调用（3 初始化 `TMP_ALLOWLIST`/`TMP_CANDIDATES`/`TMP_HITS` + 1 汇总段 `TMP_ALLOWLIST_KEYS`）。执行者按 4 处全改并加 `|| exit 1`，`<done>` 表述已修正为「4 个调用点（3 初始化 + 1 汇总段 TMP_ALLOWLIST_KEYS）」。
- **F-18 非原契约**：F-18 是主 agent 在执行过程中（m00142）追加的 finding（用户裁决 option ②），不在 TASK.md T-FIX-06 原 `<action>` 契约内。经用户裁决后并入同一提交，提交信息已含 F-18。
- `deferred`：`[]`（无延期项）。
- 无其他遗留。

---

## 12. 你没有做的事

- 未改 `SELF_EXCLUDE` 成员 / `PAT` / 允许清单读序 / `候选文件 N 个` 自证行（冻结语义）。
- 未给 `git ls-files` 加 `--others`（F-18 零行为变更，用户裁决 option ②）。
- 未改 `<verify>` / `<action>` 契约（仅执行；`<done>` 注记修正 4 调用点口径 + 追加 F-18 + 时点注记）。
- 未碰冻结件（`CHANGE.md` / `INDEPENDENT-REVIEW-1~3.md` / `REQUIREMENT.md` —— `A ` 暂存态属主 agent；`MINOR-DEFERRED.md` / `REVIEW.md` / `INDEPENDENT-REVIEW-5~6.md` / `TEST.md` / `PHASE5-RECEIPTS.md` / `T-FIX-0*-SUMMARY.md` / `TASK.md`）。
- 未声称「提交通过 git hook 门禁」——本仓 `git config core.hooksPath` 为空串，hook 未生效；门禁由执行者**手动**执行并汇报 rc（见 §6）。

---

## 13. 台账五字段（`.flow-active` `goal.task_progress`）

```json
{
  "id": "T-FIX-06",
  "commit_sha": "421640a4582445c5d609a7825a2d88011600e9df",
  "fix_rounds": 0,
  "deferred": [],
  "completed_at": "2026-09-25T02:12:13+08:00"
}
```

- commit `%cI` = `2026-09-25T02:11:53+08:00`
- ledger `completed_at` = `2026-09-25T02:12:13+08:00`
- **Δ = 20 s**（≤ 120 s ✓，台账时点规则 9 合规）
- JSON 有效（`python3 json.load` ok）
