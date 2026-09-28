# T14-SUMMARY — AC-4 接线：`check-gate-sync` 纳入 `make check` 先决条件

- **状态**：DONE（Makefile 三处接线完成；判据双态实测 rc=1 → rc=0 + 反向对照 rc=0→1→0；门禁全绿）
- **产品件**：`Makefile`（唯一产品变更，+10/-2）
- **协议产物**：`T14-SUMMARY.md`（本文）、`TASK.md`（T14 `status="done"`）、`.flow-active`（T14 五字段台账）

## 一、任务理解

T14 属 AC-4「门禁能看见内容漂移而非只数行数」的**接线①**：让 `make check` 的先决条件真正跑到 T08 已定稿的健康门禁脚本 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`。
主 agent 2026-09-23 实测订正了原稿假设：`grep -n 'check-gate-sync' Makefile` 只命中 `:16` 的**注释**，`check-gate-sync` 目标当前**并不存在** ⇒ 接线三件（只改 `Makefile`）：

1. 新建薄壳目标 `check-gate-sync:`（与既有 `check-dist` 同形，recipe 含脚本路径字面，禁 `|| true` / `&& true` 吞失败 —— L-121）。
2. 追加为 `check:`（`Makefile:106`）先决条件。
3. `.PHONY`（`Makefile:5`）追加 `check-gate-sync`。

## 二、边界复述

- 只改 `Makefile`；不新建聚合目标，沿用既有 `check-*` 接入点。
- `check-path-privacy` 的接线是 T18 的活，**本 task 未提前接入**（`Makefile` 现有 grid 无 `check-path-privacy` 目标，未触碰）。
- `make check` 因 `check-dist` 未收口（T24）仍为红 ⇒ 本 task **未试图让它整体变绿**（红是 T24 预期态，非本 task 失败）。
- **F3 接线断言用干跑**（`make -n check`）而非 `grep Makefile`：`Makefile:16` 存在同名注释，`grep` 会命中注释而恒真（REQUIREMENT AC-4 · L2 R1 证伪过初版判据）。
- 未触碰 `.specs/CONTEXT.md` / `.specs/LESSONS.md` / `.specs/STATE.md` / 冻结 staged 集。

## 三、改动清单（file:line → 前后对照；只改 `Makefile`）

| 位置 | 改前 | 改后 |
|---|---|---|
| `Makefile:5` (.PHONY) | `… check-dist dsh-sync` | `… check-dist check-gate-sync dsh-sync` |
| `Makefile:106` (check: 先决) | `check: test lint check-validate check-test-sync check-hooks-sync check-dist` | `check: test lint check-validate check-test-sync check-hooks-sync check-dist check-gate-sync` |
| `Makefile:112-118` (新目标) | （无） | `check-gate-sync:` 薄壳 + 横幅 echo + `@bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（recipe 含脚本路径；无 `|| true` / `&& true`） |

## 四、修复前基线（改 `Makefile` 之前实测）

```
$ make -n check | grep -q 'check-gate-sync'; echo "pre_rc=$?"
pre_rc=1
$ make -n check | wc -l
48
```

## 五、判据双态与反向对照真实输出（判据从工件 `TASK.md` T14 原样抽取 · L-128；路径已按 L-129 de-shape）

执行方式（判据抽取管道）：`task-brief TASK.md T14 | awk '/^  <verify>$/{f=1} … </verify>' > /tmp/t14v-artifact.sh && bash -n && bash`

### 修复前（预检 · 工件 rc=1）
`make -n check | grep -q 'check-gate-sync'` 在不同 `Makefile` 下：
- 改前目标不存在 ⇒ `pre_rc=1`（见「四」）。

### 修复后（判据 rc=0）
三态逐一被工件判据断言，最终 rc=0：
- `.PHONY` 已登记 `check-gate-sync`（断言 1 通过）。
- `make -n check` 干跑含 `check-gate-sync`（断言 2 通过 ⇒ 先决条件接线成立）。
- `make -n check-gate-sync` 干跑含 `check-gate-sync.sh`（断言 3 通过 ⇒ 目标 recipe 调用了脚本路径）。
- `bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh` 健康态门禁 `exit 0`（断言 4 通过）。

判据执行真实输出（结尾 + 汇总节；`<repo>` = 仓库根，原为逐字 `/home/<acct>/…/flow-kit` 形态，按 L-129 de-shape）：
```
🔍 check-gate-sync: 校验 prompt↔skill toll-gate 协议一致性...

   校验: A-evolve ↔ flow-evolve
     prompt: <repo>/flow-kit-bundle/flow-kit/prompts/A-evolve.md
     skill:  <repo>/flow-kit-bundle/skills/flow-evolve/SKILL.md
   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）
   （I-intel-scan ↔ flow-intel、L-restyle ↔ flow-restyle 同形 ✅）
   校验: gate-config 预设名同步 (…17 个预设 ✅)

   ── 校验汇总 ──
   覆盖度: 校验对 3/14（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 11 对已实质分叉，留 v2/TD-025）
   ✅ 校验对 3/14 一致（仅覆盖上述对，非全量 14 对全绿）。
rc=0
```

### 反向对照（L-123，必做：删先决 → 同一判据 r=1 → 恢复 → rc=0）
临时删 `check:` 先决（`sed 's/check-dist check-gate-sync$/check-dist/'`）后**原判据**重跑：
```
=== reverse control: prereq removed ===
🔴 check-gate-sync 未接入 make check
rc=1
```
恢复（`cp` 备份回写）后重跑 ⇒ rc=0（输出同上）。恢复后 `git diff` 只剩预期改动（见「三」）。反向对照证明判据对「接线/未接线」有区分力。

## 六、门禁输出（真实执行）

| 门禁 | 结果 |
|---|---|
| `make test` | 973 ok / 0 not ok / `✅ bats: all tests passed` / rc=0 |
| `make check-test-sync` | `✅ test 双源一致` / rc=0 |
| `make check-hooks-sync` | `✅ hooks 副本一致（漂移 0）` / rc=0 |
| `make lint` | `✅ shellcheck: no errors found` / rc=0 |

`make check` / `make check-dist`：**预期红**（T24 未收口），未修、未据此判失败。**未使用** `--no-verify`（L-126）。

## 七、6 维自查（本 task 为纯 `Makefile` 接线，走内置快查）

- **R1 认知过载**：情绪目标 ≤3 行 + 薄壳 recipe，无函数体 ⇒ 不适用 ✅
- **R2 变更传播**：只动 `Makefile` 三处，未触碰 `.flow-active` 之外的在途文件；无越界 ✅
- **R3 知识重复**：reuse 既有 `check-dist` 薄壳形态（同一接线模式），未拷贝重复逻辑 ✅
- **R4 偶然复杂**：未新建聚合目标（遵循 action「不新建聚合目标」），无超前抽象 ✅
- **R5 依赖混乱**：`check-gate-sync:` recipe 直调 `@bash …/check-gate-sync.sh`（业务门禁 → 判据脚本），与既有 `check-*` 同向，无反向依赖 ✅
- **R6 领域扭曲**：目标名 `check-gate-sync` 为已登记的领域词（与 T08 脚本同名、AC-4 措辞），无技术词 ✅

**沿用既有抽象 grep（R6.4）**：接线复用既有 `check-*` 目标形态（`check-validate` / `check-hooks-sync` / `check-dist`），recipe 直接调用 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（T08 已定稿判据），未新造判据脚本 ✅

## 八、TDD 声明

本 task 是**纯 `Makefile` 接线**（薄壳目标 + 先决条件 + .PHONY），无测试面可写：
- 判据验证走 `make -n` 干跑（'check-gate-sync'、'check-gate-sync.sh' 路径断言）—— 属 **make 接线断言**，非函数/模块可不套 RED-GREEN。
- 行为/门禁语义测试由 **T15**（AC-4 漂移场景 bats，含 `test_lessons_cleanup.bats` 相关）与 **T29**（收口/交叉校验）承担。
- 已实测：健康态 `bash check-gate-sync.sh` rc=0（第五节），接线后 `make -n check` 与 `make -n check-gate-sync` 均能检出脚本路径 —— 接线行为真实可观测，非"应该可以工作"（R6.3）。

## 九、遗留

- `check-path-privacy` 接线属 **T18**，未提前接入（符合边界）。
- `make check` 整体仍红，因 `check-dist` 未收口（**T24**），本 task 不处理。
- 漂移场景的正向测试（内容漂移必须报红并指名位置，REQUIREMENT AC-4 Then②）由 T15 覆盖，本 task 不做注入式漂移实测。