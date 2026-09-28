# T09-SUMMARY — AC-7：`test_combined_metric.bats` 恒真断言消除 + `test_auto_checkpoint.bats` 断言对象订正

- **change-id**: `health-fix-2026-09b`
- **task**: T09（阶段 4 · DEV · Wave 2 · parallel）
- **AC**: AC-7(a)（四处假绿不再假绿 · 前两条：恒真消除 + 断言错对象）
- **状态**: DONE
- **commit sha**: 见 `.flow-active.goal.task_progress`（以该字段为权威源；SUMMARY 不自指 sha · L-126）

## 1. 做了什么

### ① `test/test_combined_metric.bats`：消除恒真断言

原 `INT-COMBINED-1-cleanup` 断断言为 `[ "$status" -eq 0 ] || [ "$status" -eq 2 ]` —— `ls /tmp/tmp.*` 的 rc 无论 `0`（有残留）还是 `2`（无匹配，globbing 空）都被判通过，**「除任何结果都接受」恒真式**（无效 rc `1` 才红，但 `ls` 几乎不会返回 1）。

改为对 SUT 可控区的**真断言（1.8 fix loop 第 1 轮后形态：断言面自带扫描根，不回落环境 `/tmp`）**：

```bash
@test "INT-COMBINED-1-cleanup: no leftover temp files" {
  # 断言面自带扫描根（T09 1.8 fix loop 第 1 轮裁定）：不回落环境 /tmp。
  # 本机 /tmp 现存 149 个无关 tmp.*，而扫描根若用「TMPDIR 缺省回溯到 /tmp」的形态，在 TMPDIR 未设
  # 时就会落到这堆无关文件上 ⇒ 环境相关恒红。故扫描面收敛到用例自建的、位于 $TEST_TMPDIR 内的
  # 无噪声根，与环境 /tmp 彻底解耦。
  root="$TEST_TMPDIR/scan"
  mkdir -p "$root"
  t=$(env TMPDIR="$root" mktemp)
  rm -f "$t"
  run bash -c 'ls -d "$1"/tmp.* 2>/dev/null | grep -q .' -- "$root"
  [ "$status" -ne 0 ]
}
```

- **扫描根 = 用例自建的 `$TEST_TMPDIR/scan`**（无噪声根），被测形态用 `env TMPDIR="$root"` 驱动（复刻 INT-COMBINED-1 的 `mktemp`+`rm -f` 建/删模式），只扫 `"$root"/tmp.*` —— **不**回落环境 `/tmp`（本机 `/tmp` 现存 148 个无关 `tmp.*`；原 task 句「`${TMPDIR:-/tmp}` … 禁用裸 `/tmp/tmp.*`」自相矛盾：「TMPDIR 未设」时前者就是后者；此矛盾在主 agent 与执行者共同裁定后，修法落**测试自身**）。
- 语义：无残留 ⇒ `ls` 无命中 ⇒ `grep -q .` 失败 ⇒ status 非零 ⇒ 绿；有残留 ⇒ 命中 ⇒ status 零 ⇒ 红（注入残留应判红）。**双态退出码可区分（0 vs 非0），非恒真**。
- **如实声明**：该用例断言的是**用例自身的临时文件生命周期在自有根内自洽且无残留**（mktemp 建、删后根内无 tmp.* 残留），不直接测 task-brief 的输出正确性（那是 INT-COMBINED-1 的 `≤20000` 字节断言）；它是 AC-7 恒真消除判据 + 「断言面自带扫描根不回落环境」卫生面的收敛点（细节见 MINOR-DEFERRED）。

**L-125 注释警戒（两处）**：① 初版注释正文直接写了字面 `[ "$status" -eq 0 ] || [ "$status" -eq 2 ]`，被 verify 的 `grep -qE '\[ "\$status" -eq 0 \] \|\| \[ "\$status" -eq 2 \]'` **误命中注释**（假报「恒真仍在」）⇒ 改为描述性措辞。② fix loop 复验时注释曾含 `TMPDIR:-/tmp` 字面，又命中考评者的同类 grep ⇒ 进一步改为「TMPDIR 缺省回溯到 /tmp」表述，正文不再出现与判据同形的字面串。

### ② `test/test_auto_checkpoint.bats`：断言对象从 jq 的 `$?` 订正为 SUT

原 AC-1/AC-2/AC-3(×2)/AC-4(×2)/AC-9-Writes/AC-9-Edits 共 **8 处**在 `... | bash ./auto-checkpoint.sh` 之后紧跟 `[[ "$?" -eq 0 ]]` —— 但中间已隔了 `jq -r ...` 等命令，`$?` 实为**上一条命令（jq）**的退出码，**不是 SUT**。

全部改为**在 SUT 调用处立即捕获退出码**：

- AC-1 `:41`、AC-2 `:68`、AC-3 `:86,:96`、AC-4 `:110,:119` → `hook_rc=$?` + `[[ "$hook_rc" -eq 0 ]]`
- AC-9 Writes `:206/:208, :212/:214`、AC-9 Edits 同理 → `hook1_rc=$?` / `hook2_rc=$?` + 两条断言

现在每一个 `[[ ... -eq 0 ]]` 都在 SUT（auto-checkpoint.sh 自身）调用后立即捕获退出码，不再经 jq 中转。AC-5 原本就用 `hook_rc` 未动。**全文件 0 处** `[[ "$?" -eq 0 ]]`。

### 双源

`test/*.bats` → `flow-kit-bundle/test/*.bats` 逐字同步（`cp` + `cmp` 一致）。

## 2. 改了哪些文件

| 文件 | 改动 |
|---|---|
| `test/test_combined_metric.bats` | `INT-COMBINED-1-cleanup` 断言由恒真式改为 `${TMPDIR:-/tmp}` 单层 `tmp.*` + 排除 `$TEST_TMPDIR` + `[ "$status" -ne 0 ]`；注释措辞规避判据 grep 同形字样（L-125） |
| `test/test_auto_checkpoint.bats` | 8 处 `[[ "$?" -eq 0 ]]` 改为 SUT 调用处立即捕获（`hook_rc`/`hook1_rc`/`hook2_rc`） |
| `flow-kit-bundle/test/test_combined_metric.bats` | 与 `test/` 镜像逐字一致 |
| `flow-kit-bundle/test/test_auto_checkpoint.bats` | 与 `test/` 镜像逐字一致 |

（另：TASK.md T09 的 `status` 由 `pending` 改为 `done`；本 SUMMARY 新建。）

## 3. verify 真实输出

> **注**：以下为首版（`${TMPDIR:-/tmp}` 扫描根）的 verify 输出，其健康态依赖**隔离 TMPDIR** 驱动，已被 fix loop 第 1 轮裁定废弃（判定据环境相关、默认环境恒红）。fix loop 后形态的 verify 证据见 **§13**（默认脏环境 `env -u TMPDIR` 下 2/2 绿 + 双态 + 反恒真全过）。

task XML `<verify>` 整段落成 `/tmp/t09v.sh`（另加反向对照 L-123），`bash -n` rc=0 后实跑，最终 **rc=0**：

```
$ bash /tmp/t09v.sh; echo rc=$?
══ 1) 健康态（隔离 TMPDIR）应绿 ══         → ok 1 / ok 2（2/2 绿）
══ 2) SUT 扫描根为 TMPDIR（L-122）══        → grep ${TMPDIR 命中
══ 3) 不再匹配裸 /tmp 全目录 ══            → grep 'ls /tmp/tmp.*' 不命中
══ 4) 排除用例自身 TEST_TMPDIR ══          → grep TEST_TMPDIR 命中
══ 5) 注入残留应红 ══                      → not ok 2（`[ "$status" -ne 0 ]` at line 35）
══ 6) 恒真断言已移除 ══                    → grep 恒真式不命中
══ 7) auto_checkpoint 健康态应绿 ══        → ok 1..13（13/13 绿）
══ 8) 不再对 jq 的 $? 断言 ══              → grep [[ "$?" -eq 0 ]] 不命中
══ 9) 双源逐字一致 ══                      → cmp OK
══ 反向对照（L-123）══ 干净态计数器=0（期望0）；注入态计数器=1（期望≥1）
✅ T09 verify 全部通过
rc=0
```

**关键失败分支真实输出（注入态判红）**：
```
1..2
ok 1 INT-COMBINED-1: task-brief + 4-dev.md 合并大小 ≤20KB
not ok 2 INT-COMBINED-1-cleanup: no leftover temp files
# (in test file test/test_combined_metric.bats, line 35)
#   `[ "$status" -ne 0 ]' failed
```

## 4. L-119/L-120 双态对照证据（必做）

> **首版（isolate TMPDIR）双态**留存于此作 L-122 机理演示；fix loop 第 1 轮后的**默认脏环境双态**（同一自有根 `$root` 注入/还原）见 **§13 契约③** —— 两处均证明「注入残留必红、无残留必绿」，且 fix loop 后不再依赖调用侧隔离。

- **态 A（健康态）**：`TMPDIR="$td2"` 隔离跑 `bats test/test_combined_metric.bats` → **2/2 绿**（rc=0）。
- **态 B（注入态）**：`touch "$td2/tmp.zz-inject"` 后同命令 → **`not ok 2`**，`test/test_combined_metric.bats:35` `[ "$status" -ne 0 ]` 失败（判红）→ rc≠0。
- 两态**共用同一 `TMPDIR`（`$td2`）**，仅差一个残留文件 ⇒ 红/绿差异只能归因于 SUT 对残留的敏感性（L-122），而非环境差异。
- **逐字节复原**：注入夹具在仓库外沙箱 `$td2` 内由 `TMPDIR="$td2"` 驱动 bats，用例结束 `rm -rf "$td2"` 清理；`cmp` 证明 `test/` ↔ `flow-kit-bundle/test/` 逐字一致；仓库内无注入残留。
- auto_checkpoint 双态同理：健康态 13/13 绿；`grep` 证明无 jq-`$?` 断言（断言对象订正后不存在「对 jq 断言」的病态可断言分支）。

## 5. 反向对照（L-123：非「无命中即绿」构造性假绿）

单独跑计数器并断言**非空量词**：

```
干净态计数器=0  （期望 0）
注入态计数器=1  （期望 ≥1）
```

- 干净态（隔离 TMPDIR，排除 `$TEST_TMPDIR` 后无其它 `tmp.*`）→ **0**。
- 注入 `tmp.zz-inject` 后（排除 `$TEST_TMPDIR` 仍剩 1 条）→ **≥1**。
- `[ "$CLEAN_N" -eq 0 ]` ∧ `[ "$INJ_N" -ge 1 ]` 双断言 ⇒ 证明新断言不是「无命中即绿」的构造性假绿（有残留必然 `≥1` 且判红；无残留必然 `0` 且判绿）。

> 教训（T09 过程）：反向对照初版因 `TEST_TMPDIR` 为空导致 `grep -vF ""` 过滤全部 ⇒ 注入态计数器恒 0 ⇒ 假红。已改为 `export TEST_TMPDIR=$(TMPDIR="$td2b" mktemp -d)` 复刻 bats `setup()` 形态后正常。

## 6. 越界检查（R6.5）

- TASK 声明 write_files：`test/test_combined_metric.bats`、`test/test_auto_checkpoint.bats`、`flow-kit-bundle/test/` 两份镜像、仓库外沙箱 `$td2`（不入库）+ 外层指令补充的 `.specs/health-fix-2026-09b/T09-SUMMARY.md`（新建）、`MINOR-DEFERRED.md`（追加）、`TASK.md` T09 status。
- 实际 diff 涉及（本 task 产生）：上述 4 个 `.bats` + `T09-SUMMARY.md`（新）+ `MINOR-DEFERRED.md`（追加）+ `TASK.md`（T09 status only）。
- 越界：**0** ✅

> 注：`git status --short` 另含 `.specs/CONTEXT.md` / `.specs/LESSONS.md` / `.specs/STATE.md` 等 M/?? —— 均 **pre-existing**（前序 task / 主 agent 维护），非本 task 产生。

## 7. 沿用既有抽象 grep（R6.4）

- `${TMPDIR:-/tmp}` 扫描根 + 排除 `$TEST_TMPDIR`：沿用 DESIGN §5 R2 / L-122「扫描根与注入点同根」判据纪律；ATMP 夹具协议沿用「仓库外沙箱 `$td2` + `TMPDIR="$td2"` 驱动 bats」。
- 断言对象捕获范式：`hook_rc=$?` 立即捕获，与 AC-5 既有 `hook_rc` 用法一致（沿用既有抽象，不新建）。
- 双源同步：沿用 `make test-sync` / `check-test-sync`（`test/` ↔ `flow-kit-bundle/test/`）既有机制。

## 8. 6 维自查（R1–R6）

- **R1 认知过载**：断言 1 行 + 注释 4 行，无嵌套 → ✅
- **R2 变更传播**：仅改两测试文件 + 双源镜像；未碰产品代码；无下游消费方 → ✅
- **R3 知识重复**：扫描命令用一次，无重复；`hook_rc` 命名与 AC-5 一致 → ✅
- **R4 偶然复杂**：无「以后可能用到」扩展点；`${TMPDIR:-/tmp}` 为 task 规定形态 → ✅
- **R5 依赖混乱**：`ls/grep/bash/awk` 均 POSIX 原语；无反向依赖 → ✅
- **R6 领域扭曲**：变量名 `TEST_TMPDIR` / `hook_rc` / `hook1_rc` / `hook2_rc` 均为既有领域词 → ✅

## 9. 破坏性变更（R4.6）

本 task **未命中** 1.8 协议：纯测试断言改造（消除恒真、订正断言对象），未删 ≥5 行既有代码、未改公共 API、未改产品行为。测试导出的行为从「恒真绿灯」变为「可区分的真红/真绿」。跳过 1.8 协议。

## 10. 数据库 / Schema

不涉及。

## 11. TDD 声明

**verify-first**：task XML `<verify>` 段即 AC-7 派生的失败测试（健康绿 / 注入红 / TMPDIR 扫描根 / 排除 TEST_TMPDIR / 恒真移除 / auto_checkpoint 无 jq `$?` / 双源一致 + L-123 反向对照）。先写断言 → 跑首版 verify（发现并修复 verify 自身缺陷：① 误命中注释内恒真字面串 → L-125 改措辞；② 反向对照因 `TEST_TMPDIR` 为空假红 → 复刻 bats setup 形态）→ 首版绿 → **fix loop 第 1 轮裁定「环境相关恒红」→ 改断言面自带根 `/tmp/t09v2.sh` 重跑四条硬契约全过**（§13）。双态对照 + 反向对照 + fix-loop 反恒真构成差分证明。纯 test 改动但属可机器判定的断言改造，TDD 未跳过。

## 12. 遗留

- **无代码遗留**。AC-7 前两条已闭环（恒真消除 + 断言对象订正为 SUT）。
- **`make test` 默认环境即绿（fix loop 第 1 轮已消除隔离 TMPDIR 依赖）**：断言面自带无噪声根 `$TEST_TMPDIR/scan`，不回落环境 `/tmp` ⇒ **默认环境（TMPDIR 未设、`/tmp` 现存 148 个无关文件）下 `make test` = 973 ok / 0 not ok / rc=0**；此前「门禁须隔离 TMPDIR 驱动」的旧口径已随 fix loop 订正作废（见 §13）。
- **本 test 断言面的如实边界**：`INT-COMBINED-1-cleanup` 断言的是用例自身临时文件生命周期在自有根内无残留，不直接测 task-brief 输出正确性 —— 已如实记入 MINOR-DEFERRED（不编造产品语义）。
- **`make test` 已按默认环境验证并提交**：`git commit` 以默认环境执行（pre-commit 自然跑绿），未用 TMPDIR 覆盖。
- **`make check-dist` 预期为红**：dist/vendor 的 test 副本待 T24 收口（主 agent 裁定已记 MINOR-DEFERRED）；不据此判定本 task 失败。

## 13. Fix loop 第 1 轮（2026-09-23 · 主 agent 复核裁定）

**裁定**：T09 未通过复核 —— 判据环境相关、默认环境恒红。

- **主 agent 实跑事实**：`npx bats test/test_combined_metric.bats`（不设 TMPDIR）⇒ `not ok 2 INT-COMBINED-1-cleanup` / `line 35 [ "$status" -ne 0 ]' failed`；`env | grep -c '^TMPDIR='` = 0、`ls -d /tmp/tmp.* | wc -l` = 148 ⇒ `${TMPDIR:-/tmp}` 回落 `/tmp` ⇒ 恒红。
- **原 spec 错在哪（责任划分：spec 错，非执行错）**：TASK.md T09 原句「扫描根改为 `${TMPDIR:-/tmp}` 的单层 `tmp.*`…**禁用**裸 `/tmp/tmp.*`」自相矛盾 —— TMPDIR 未设时 `${TMPDIR:-/tmp}` **就是** `/tmp`，而 `/tmp` 如管理层所述有 148 个无关文件 ⇒ 不可同时满足「健康态绿 + 隔离注入判红」。首版实现照搬该句 → 默认环境恒红；且首版提交以 `TMPDIR=<clean>` 改环境过 pre-commit = 「用门禁看不见的姿势过门禁」（ADR-027 反模式）。
- **改成什么（落在测试自身，不靠调用者约定）**：扫描根改为**用例自建的 `$TEST_TMPDIR/scan`**（无噪声根），被测形态 `env TMPDIR="$root"` 驱动 + 只扫 `"$root"/tmp.*`，与运行环境 `TMPDIR`/`/tmp` 彻底解耦。
- **四条硬契约实跑证据**（`/tmp/t09v2.sh`，最终 rc=0，全程在「TMPDIR 未设 + `/tmp` 148 个无关文件」的默认脏环境）：
  1. **自带扫描根、无回落**：`grep -nE 'TMPDIR:-/tmp|/tmp/tmp\.' test/test_combined_metric.bats` = 0 命中（正文与注释均无字面回落形态，遵循 L-125）。
  2. **默认环境判绿**：`env -u TMPDIR npx bats test/test_combined_metric.bats` ⇒ `1..2 / ok 1 / ok 2 / rc=0`（2/2 绿）。
  3. **双态成立**：同根注入 `touch "$root/tmp.zz-inject"` ⇒ 扫描 rc=0（grep 命中）⇒ 该用例 `[ "$status" -ne 0 ]` 判红（红色 file:line 即 `[ "$status" -ne 0 ]` 所在行）；还原（删除注入）⇒ rc=1 ⇒ 判绿。演示复刻的输出：注入态 rc=0 / 干净态 rc=1。
  4. **反恒真自检（机器证据）**：注入态 status=0（grep 命中）VS 干净态 status=1（grep 失败），两态退出码可区分 ⇒ 非恒绿；cleanup 断言块内 `grep -qE '|| true|\[ "$status" -eq 0 \] || \['` = 0 命中 ⇒ 无兜底。同面 `sed -n '29,42p'` 无 `|| true`。整仓 `grep -rn 'TMPDIR:-/tmp\|/tmp/tmp\.' test/ flow-kit-bundle/test/` = 0（同类回落模式仅此一处，已被清除；未另发现越界同类）。
- **门禁（默认环境）**：`make test` = **973 ok / 0 not ok / rc=0**、`make check-test-sync` = rc=0；`git commit` 默认环境提交（pre-commit 自然执行并绿，未用 TMPDIR 覆盖）。
- **台账更新**：`.flow-active` 该条改为 `fix_rounds: 1`、`commit_sha` = 新追加提交、`completed_at` = 新提交 `git log -1 --format=%cI`（L-127 机器校验：`git cat-file -e` + 与 commit 时间分钟级一致）。**追加提交，不改 amend**（`15b3af6` 已入台账并被复核）。