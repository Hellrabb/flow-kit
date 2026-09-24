# T-FIX-03 收口摘要

> **任务**：`T-FIX-03` 隐私门禁 fail-open 收敛（F1~F5）
> **change**：`health-fix-2026-09b`
> **阶段**：4-dev（阶段 6 REVIEW §B 发现，同 change 回退）
> **提交**：`6e39cfb` — `fix(health-fix-2026-09b): T-FIX-03 隐私门禁 fail-open 收敛（F1~F5）`
> **时点**：2026-09-24（T-FIX-03 执行者）
> **状态**：✅ 全绿收口

---

## 1. 目标

阶段 6 双轮审查（`REVIEW.md` §B）发现本 change 新建的隐私门禁
`flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 有两条 🔴 fail-open 缺陷
与三条 🟡 口径/清理缺陷：

| 编号 | 级别 | 缺陷 | 收敛方向 |
|------|------|------|----------|
| F1 | 🔴 | `mktemp` / `cp` / `git ls-files` / `git ls-tree` / `grep` 的 rc 与 stderr 被吞 ⇒ 机械故障折算成「0 命中 ⇒ ✅ rc=0」（fail-open） | rc + stderr 一律不丢；任一失败 ⇒ `🔴 无法完成扫描` + exit 1；`|| true` / `2>/dev/null` 只出现在 rc 已断言之后 |
| F2 | 🔴 | 候选枚举产物无任何非空断言 ⇒ 0 候选面（非 git 目录 / 空 index / 空 rev）与「全部干净」同形 | 自证行含「候选文件 N 个」并与 `git ls-files` 计数一致；N=0 ⇒ `🔴 候选面为空，无法判定` + exit 1 |
| F3 | 🟡 | 两模式二进制策略相反：工作树 `grep -nE` 静默丢弃二进制 ⇒ 假绿；rev `git grep` 把 `Binary file…matches` 当命中解析 ⇒ 假红且不可归因 | 统一 `grep -aE` / `git grep -nEa`；命中读取端断言 line 字段匹配 `^[0-9]+$`，否则按不可归因命中单列 + fail-closed |
| F4 | 🟡 | 注释口径两套：校验器认 `#` 与 `<!--`，计数器只认 `#` ⇒ `<!-- … -->` 行被计为有效条目，自证行虚高 | 注释口径单点（`IS_COMMENT_OR_BLANK_RE`），校验器与计数器共用 |
| F5 | 🟡 | 临时文件清单两份 + 第二个 `trap … EXIT` 覆盖 `cleanup()` ⇒ 首次登记的临时文件失联，漏 rm | 单一 `TMP_FILES` 清单 + 单一 `trap cleanup EXIT` |

跨模型 spot-check（`qwen3.8-flash`）独立复现后判定一致，并追加三点：
`cp` 的 rc 必须一并断言；0 候选面须覆盖「非 git 目录」与「git 仓但 index 为空」**两型**；
F1 行号勘误 `:75-77` + 新增 `:105-111`（两处 `cp -- … "$TMP_ALLOWLIST"` 不校验 rc）。

## 2. 改动逐文件

| 文件 | 改动 | 行数（+/-） |
|------|------|-------------|
| `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` | 全脚本重写（F1~F5 收敛） | +200 / -44 |
| `test/test_path_privacy_gate.bats` | 新增 11 例双态判据（F1~F5 各两条态 + F5 静态 1） | +143 / 0 |
| `flow-kit-bundle/test/test_path_privacy_gate.bats` | `make test-sync` 镜像 | +143 / 0 |
| `.specs/STATE.md` | 基线 1012 → 1023（+11 双态用例）+ 基线演进行 | +2 / -1 |
| `.specs/CONTEXT.md` | 新增 TD-064 行（F1/F2 + F3/F4/F5 登记 + 「本 change 内修复（T-FIX-03）」标注） | +3 / 0 |

### `check-path-privacy.sh` 关键改动点

- **F1**：新增 `mktemp_checked()` 函数 —— 包裹 `mktemp`，rc≠0 或空输出 ⇒
  `🔴 无法完成扫描：mktemp 失败` + exit 1。`TMP_ALLOWLIST`/`TMP_CANDIDATES`/`TMP_HITS`
  三处均经 `mktemp_checked`。`cp -- "$ALLOWLIST_*" "$TMP_ALLOWLIST"` 两处均加
  `if ! cp …; then 🔴 + exit 1`。`git ls-tree`/`git ls-files` 均加 `if ! …; then 🔴 + exit 1`。
  `grep` rc：捕获 `grc`，`grc ≥ 2` ⇒ exit 1；`grc = 1` 且 `raw` 为空 ⇒ return 0（无匹配）。
  `2>/dev/null` 只出现在已断言 rc 之后的位置。
- **F2**：`CANDIDATE_COUNT=$(grep -c . "$TMP_CANDIDATES")`；`if [ 0 -eq … ]; then`
  打印自证行 + `🔴 候选面为空，无法判定` + exit 1。自证行新增「候选文件 ${CANDIDATE_COUNT} 个」。
  两型覆盖：非 git 目录（`git ls-files` rc≠0 ⇒ F1 抓）/ git 仓但 index 空（`git ls-files`
  rc=0 输出 0 行 ⇒ F2 候选数断言兜住）。
- **F3**：工作树模式 `grep -naE`（`-a` 把二进制当文本匹配 + 按行归因）；
  rev 模式 `git grep -nEa`。两模式同一策略。命中读取端：`case "$l" in ''|*[!0-9]*)`
  ⇒ 写 `file:?:content` 到 `TMP_HITS` 作不可归因命中；不可归因计数 > 0 ⇒
  `🔴 不可归因命中 N 条` + exit 1。
- **F4**：`IS_COMMENT_OR_BLANK_RE='^[[:space:]]*(#|<!--|$)'` 单点定义，
  `validate_allowlist_format`（`grep -qE`）/ `ALLOWLIST_COUNT`（`grep -cvE`）/
  `TMP_ALLOWLIST_KEYS`（`grep -vE`）三处共用。
- **F5**：`TMP_FILES` 变量是临时文件唯一登记表；`TMP_ALLOWLIST_KEYS` 也登记进
  `TMP_FILES`。全脚本只剩一个 `trap cleanup EXIT`（第 98 行）。`cleanup()` 遍历
  `$TMP_FILES` 逐个 `rm -f`。

## 3. TDD 双态证据

### 修复前转红（RED）— 在未修复的原脚本上跑新用例

RED 阶段沙箱实测（复现 verify mkfix 范式）：

| 用例 | 态 | 修复前实测 | 判定 |
|------|----|------------|------|
| F1 坏（TMPDIR 不可用 + 真泄漏） | 坏 | rc=0 +「清单外命中 0 条 ✅」 | ❌ fail-open |
| F1 好（TMPDIR 可用 + 真泄漏） | 好 | rc=1 + probe.txt:1 | ✅（不依赖 fix） |
| F2 坏①（non-git + leak） | 坏 | rc=0（同 clean） | ❌ 同形 |
| F2 坏②（empty-index + leak） | 坏 | rc=0 | ❌ 同形 |
| F2 好（候选文件数自证 + 计数一致） | 好 | 无「候选文件 N 个」行 | ❌ 缺自证 |
| F3 坏（tracked binary + probe） | 坏 | rc=0（silent drop） | ❌ 假绿 |
| F3 好（clean binary） | 好 | rc=0 | ✅（不依赖 fix） |
| F4 坏（HTML-only allowlist） | 坏 | 「允许清单 1 条」（应 0） | ❌ 口径虚高 |
| F4 好（valid file:line + # comment） | 好 | 「允许清单 1 条」+ rc=0 | ✅（不依赖 fix） |
| F5 静态（trap EXIT 计数） | 坏 | 2 个 EXIT trap | ❌ 覆盖 |
| F5 好（temp files cleaned） | 好 | cleaned | ✅（不依赖 fix） |

RED 确认：依赖 fix 的 7 例（F1 坏 / F2 坏① / F2 坏② / F2 好 / F3 坏 / F4 坏 / F5 静态）
全转红；不依赖 fix 的 4 例（F1 好 / F3 好 / F4 好 / F5 好）保持绿（判别式确认）。

### 修复后全绿（GREEN）

```
npx bats test/test_path_privacy_gate.bats
# 20 tests, 0 failures（9 既有 + 11 新增双态）
```

全量基线：

```
npx bats test/
# 1023 ok / 0 not-ok / count=1023
```

## 4. 判据原文与 rc

### `<verify>` 十组断言

`<verify>` 块（`TASK.md` T-FIX-03 块内，`awk '/<task id="T-FIX-03"/,/<\/task>/'` 抽取）
含十组断言 A/B/C/D/E/E2/F/G/H/I/J（B/C/G/H/I 为静态/计数/门禁断言，本摘要聚焦
A/D/E/E2/F/traps 汇总行 + bats 计数行）。

### 原样跑 `<verify>` 的完整原始输出（尾部）

```
A=1 B=0 D=1 E=1 E2=1 F=1 traps=1
bats: 1023 ok / 0 not-ok / count=1023
```

- **rc=0**（全绿收口）
- 行展开：
  - `A=1`（F0 leak：rc=1 + leak.txt:1，probe 探针命中且归因 file:line）
  - `B=0`（F0 clean：rc=0，干净工作树放行）
  - `D=1`（F2 候选文件数自证：自证行含「候选文件 N 个」且与 `git ls-files | wc -l` 一致）
  - `E=1`（F1 TMPDIR-bad：rc≠0 且无「清单外命中 0 条 ✅」—— fail-closed）
  - `E2=1`（F2 non-git：rc≠0 + F2 empty-index：rc≠0 —— 两型 0 候选都 fail-closed）
  - `F=1`（F3 binary+probe：rc≠0 + `bin.dat:[0-9]+:` 归因 —— 二进制不再静默丢弃）
  - `traps=1`（F5：`grep -cE '^[[:space:]]*trap .*EXIT'` = 1 —— 单一 EXIT trap）
- bats 计数行：`1023 ok / 0 not-ok / count=1023`（全量 `npx bats test/` + `--count`）

## 5. 门禁 rc 一览

| 门禁 | rc | 说明 |
|------|----|------|
| `make check` | 0 | 全量门禁（含 check-path-privacy / check-nfr-portability / check-hooks-sync / check-test-sync / check-dist 等）全部通过 |
| `make check-path-privacy`（真实仓） | 0 | 候选文件 1589 个，0 清单外命中，无假红 |
| `make check-nfr-portability` | 0 | bash 3.2 兼容（无 `declare -A` / `mapfile` / `sed -i` / GNU-only） |
| `make check-hooks-sync` | 0 | hooks 副本一致漂移 0 |
| `make check-test-sync` | 0 | test 双源（`test/` ↔ `flow-kit-bundle/test/`）一致 |
| `make check-dist` | 0 | dist 与源一致（`package-dsh-plugin.sh` 重建后） |
| `npx bats test/test_path_privacy_gate.bats` | 0 | 20/20 ok（9 既有 + 11 双态） |
| `npx bats test/`（全量） | 0 | 1023 ok / 0 not-ok |
| `npx bats --count test/` | 0 | count=1023 |

收尾顺序敏感（L-154）：`make test-sync` → `bash package-dsh-plugin.sh` →
`make check-hooks-sync check-test-sync check-dist` → `make check`，均按序通过。

## 6. 遗留与未坐实项

- **无遗留缺陷**：F1~F5 全部收敛，双态判据 11 例常设化，全量基线 1023 ok / 0 not-ok。
- **`deferred` = `[]`**（task_progress 五字段条目）。
- **`fix_rounds` = 0**（一轮收敛，无返工）。
- **未提交的 housekeeping**（留主 agent）：
  - `TASK.md` 勾 `status="done"` + `<done>` 末尾追加「时点实测（T-FIX-03 执行者 2026-09-24）」注记
  - `.flow-active` 的 `.goal.task_progress` 追加五字段条目
  - 本 `T-FIX-03-SUMMARY.md`（不提交）
- **TD-062 / TD-063**（🟢 REVIEW F12 / F17，交阶段 7 triage）不在本任务范围，未动。

## 7. 没有做的事（边界声明）

1. **未改判据**：`<verify>` 与既有断言逐字保留；未放宽/删除断言让它变绿。
2. **未动冻结件**：5 个冻结文件（`CHANGE.md` / `REQUIREMENT.md` /
   `INDEPENDENT-REVIEW-1/2/3.md`）处于暂存态（`A `）但**未进入本提交**
   （`git commit -- <explicit paths>` 路径限定）；`path-privacy-allowlist.txt` 内容未动；
   `TASK.md` / `REVIEW.md` / `TEST.md` / `INDEPENDENT-REVIEW-*.md` 既有内容未改。
3. **未用禁用提交手法**：无 `git add .` / `-A` / `--no-verify` / `git stash`。
4. **未声称提交通过门禁**：本仓 `core.hooksPath` 为空串 ⇒ git hooks 未生效；
   门禁证据只来自显式运行 `make check` 等命令的 rc。
5. **未引入 bash4/GNU-only 构造**：无 `declare -A` / `mapfile` / `sed -i`；
   `make check-nfr-portability` 通过。
6. **未把脚本正文抄进 bats**：夹具运行时 `cp` 真实生产件进 `mktemp -d` 夹具。
7. **探针字面量脱敏**：所有探针用拼接构造（如 `'/home/''zz-f3-pro''be/'`），
   未出现真实账号路径形态。

## 补记（主 agent · 阶段 4 完成自检 · 2026-09-25）

> 本任务经 fix 循环派发，SUMMARY 按 fix 派发契约结构（§1–§7）。以下三项由主 agent 在阶段 4 完成自检（6.0 八项）时补齐证据。

- **越界检查（R6.5）**：`git show --numstat 6e39cfb` = 5 文件 **+491/−45**，全部落在任务块 `<write_files>` 面内；未触碰源面以外文件。`.specs/CONTEXT.md` +3 行是**主 agent 派发前**登记的 TD-062 / TD-063（路径限定提交的正常结果）。
- **沿用既有抽象 grep（R6.4）**：① 判据侧新增 `mktemp_checked()`，与本文件既有 `mktemp` 用法族一致，未引入新依赖（纯 bash 3.2 + POSIX/coreutils）；② 测试复用 `test/test_path_privacy_gate.bats` 既有骨架（`run --separate-stderr` + 运行时复制真实生产件 + `PROBE` 字符串拼接脱敏）；③ 沿用既有常设清单读取顺序语义（change 副本 → 常设）。复核命令：`grep -n 'mktemp_checked\|PROBE=' flow-kit-bundle/flow-kit/reference/check-path-privacy.sh test/test_path_privacy_gate.bats | head`。
- **6 维快查（测试衰退风险）**：① 断言强度 ✅（坏态断言 rc≠0 且报文指名原因；好态断言 rc=0 且命中归因 `file:line`）；② 覆盖 ✅（F1~F5 每面各「坏态 + 好态」两用例，共 +11）；③ 双态真实 ✅（活性重放：还原旧件 ⇒ 恰 7 例转红）；④ 独立性 ✅（各用例自建 `mktemp -d` 夹具，不依赖执行顺序）；⑤ 可复现 ✅（`<verify>` 由主 agent 独立复跑 rc=0；bats 与 `.specs/STATE.md` 基线同步）；⑥ 计数同步 ✅（1012 → 1023）。
