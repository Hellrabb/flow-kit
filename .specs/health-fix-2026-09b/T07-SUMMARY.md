# T07-SUMMARY · health-fix-2026-09b

## 任务与契约

- **Change**: health-fix-2026-09b · **Task**: T07（阶段 4 · Wave 3 · 分发面脱敏层）
- **名称**: AC-5：`chisel-*` 中性化（双源 4 文件）+ 断言解耦
- **Write 面**（TASK.md 声明，4 项；另 3 项文档面）：
  - `test/test_correction_hygiene.bats`（chisel ×5）
  - `test/test_l3_review_defects_2026_09.bats`（chisel ×1）
  - `flow-kit-bundle/test/test_correction_hygiene.bats`（镜像）
  - `flow-kit-bundle/test/test_l3_review_defects_2026_09.bats`（镜像）
- **契约要点**（取自 task-brief T07 `/action + /verify + /done`）：
  - 先 `grep -rn chisel test/ flow-kit-bundle/test/` **枚举全部消费方**（假设 3 待验证：替换是否与其它期望字符串耦合）。
  - 再把 `chisel-*` 换成**与断言解耦**的中性占位，**双源逐字同步**（`Makefile:79` `check-test-sync` 在 `check:` 内）。
  - **不得**删除测试或用宽松断言规避（AC-5 out 段锁定）。
  - 判据：双源 4 文件 `chisel` 归零、两 bats **rc=0 且 `^ok` ≥ 134 且 `^not ok` = 0**（阶段 3 L3 m2「只跑不计数 ⇒ 删测试仍绿」）。
- **范围说明（D9 残留面）**：D9 另含「重建 `0.2.0.tgz` 并复扫」的**归档面**；T07 的 `<done>` 明确限定为「**AC-5 源侧**」，归档面归属其它 task。本任务**未**重建 `dist/*.tgz`，故 `dist/`（含 `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/`）仍含旧字面 —— 该面由 `make check-dist` / 后续 task 兜底，见「遗留」。

## 工序 1 · 消费方枚举（假设 3 验证 —— 本 task 的实质）

`grep -rn chisel test/ flow-kit-bundle/test/` 实测**命中总数 = 12**，分布 **4 文件 / 每树 6 处**：

| # | file:line（`test/` 与 `flow-kit-bundle/test/` 行号相同） | 原文 | 与其它断言字段耦合？ |
|---|---|---|---|
| 1 | `test/test_correction_hygiene.bats:174` | `change_id: "chisel-foreign"` | **否** |
| 2 | `test/test_correction_hygiene.bats:206` | 注释 `# ── AC-9 · chisel_env 场景模拟收敛` | **否** |
| 3 | `test/test_correction_hygiene.bats:207` | `@test "AC-9: chisel_env 场景 — …"` | **否** |
| 4 | `test/test_correction_hygiene.bats:210` | `tool: "chisel-skill"` | **否** |
| 5 | `test/test_correction_hygiene.bats:242` | `change_id: "chisel-foreign"` | **否** |
| 6 | `test/test_l3_review_defects_2026_09.bats:4` | 注释 `# 来源：…（chisel-skill 开发中在 chisel_env 的` | **否** |

**判定依据（逐处实证，非推断）**：

1. **#1 / #5（`change_id: "chisel-foreign"`）** —— 该串仅作为 heredoc `<<'EOF'` 写入夹具文件 `$FLOW_ACTIVE`，被测 hook **读到即视为「外来状态」**（YAML 形态、非 JSON）⇒ 触发 `foreign_state`。同用例内全部断言只检查**派生结果**：`corrupt_json` 计数 `0`（`:185-186`）、`.type == "l2-missing"`（`:188-189`）、`foreign_state` 计数 `1`（`:191-192`、`:202-203`）、`.violations[]|select(.check=="R1").message == "compliance-keep"`（`:194-195`）、stderr 含 `"外来"`（`:197`）。**无一处**把 `chisel-foreign` 作为期望值比较 ⇒ 改值安全。
2. **#4（`tool: "chisel-skill"`）** —— 仅写入 `$FLOW_ACTIVE`（`:208-211`）。同用例断言为 `violations|length == 2`（`:223-224`、`:236-237`）、`foreign_state == 1`、`.type == "l2-missing"`、`R1.message == "compliance-keep"`。`tool` 字段值不参与任何期望串 ⇒ 改值安全。
3. **#2 / #3（注释 + `@test` 标题）** —— `@test` 标题仅供人读与 bats 过滤；本仓无任何脚本按该标题过滤/匹配（实测 `grep -rn "AC-9:\|chisel_env 场景"` 在 `test/`、`flow-kit-bundle/`、`Makefile` 下**无非 bats 消费者**；同名 `AC-9` 前缀在 `test_l2_pretooluse_dispatch.bats:136`、`test_auto_checkpoint.bats:198`、`test_independent_review_model.bats:81` 各自独立存在）⇒ 改名不影响门禁。
4. **#6（文件头注释）** —— 纯文档性溯源注释，无消费者。

**结论（假设 3 的验证结果）**：**消费方枚举 12/12，与其它期望字符串耦合者 0 处**。三处 fixture 值（`chisel-foreign` / `chisel-skill`）均**只被写入、从不被断言读取**；两处测试标题/注释无外部消费者。⇒ 中性化替换**不改变任何断言语义**，无需解耦改动。

## 工序 2 · 替换与双源同步

**占位命名**（保持形态：连字符版 → 连字符版，下划线版 → 下划线版，语义位一一对应）：

| 原值 | 中性占位 | 出现处 |
|---|---|---|
| `chisel-foreign` | `sample-proj-foreign` | `:174`、`:242` |
| `chisel_env` | `sample-proj_env` | `:206`、`:207` |
| `chisel-skill` | `sample-proj-skill` | `:210`、`test_l3_review_defects_2026_09.bats:4` |

**双源方向**（本仓工艺）：`test/*.bats` 是**源**，`make test-sync`（`Makefile:71-78`）单向 `cp test/*.bats flow-kit-bundle/test/`。故**先改 `test/`，再 `make test-sync` 派生镜像**（而非手工重写镜像），以保证逐字一致。

```
🔄 make test-sync: test/ → flow-kit-bundle/test/ ...
✅ test 双源已同步            (rc=0)
🔍 make check-test-sync: test/ ↔ flow-kit-bundle/test/ ...
✅ test 双源一致              (rc=0)
```

**逐字一致的强证明（git blob 级）**：两树同文件 blob hash **完全相同**：

```
test/            test_correction_hygiene.bats = 6989616cf03cfe7ecccc0080389477e754ad71c2
                 test_l3_review_defects_2026_09.bats = affef16169fad53f70376de49704dacf114557eb
flow-kit-bundle/ 同两个文件 = 6989616cf03cfe7ecccc0080389477e754ad71c2 / affef16169fad53f70376de49704dacf114557eb
```

**替换为纯字面替换（0 逻辑改动）**：`git diff --stat` = 4 文件 **12 insertions / 12 deletions** —— 恰好 6 处 × 2 树。逐行核对：每处改动**均为同一行的同一子串**，无任何行增删、无重排。首轮曾把 `:206` 注释尾部 `─` 由 33 个改为 28 个（为对齐），**已回退为原样 33 个**以保持「纯语义替换」的可审计性（最终 diff 12/12 即证据）。

**未触碰面（out 段锁定项的自证）**：
- **断言零改动**：`:184-203`（#1/#5 用例）、`:222-237`（AC-9 用例）的 `[[ ... ]]` 全部原样；`grep -c '@test'` 用例数不变（134 ok 印证）。
- **未删除任何测试**、**未放宽任何断言**、**未新增 skip**。

## `<verify>` 逐字输出（task XML 逐字落 `/tmp/t07v.sh`）

`bash -n /tmp/t07v.sh` → `rc=0`；实跑：

```
bats(两文件): rc=0 ok=134 not-ok=0（基线 2026-09-23 实测 rc=0 / 134 ok / 0 not ok）
verify rc=0
```

（`grep -rn chisel test/ flow-kit-bundle/test/` 归零 ⇒ 首条断言通过；两条 `cmp -s` 通过 ⇒ 双源一致；`134 ok / 0 not ok / rc=0` ⇒ 与基线**逐项相等**。）

**修复前基线对照**：`grep -rn chisel test/ flow-kit-bundle/test/` = **12 命中**（`correction_hygiene` 5 处/树、`l3_review_defects` 1 处/树）；修复后 = **0**。bats 修复前实测同为 `rc=0 / 134 ok / 0 not ok` ⇒ **用例数不下降**（≥134 且 not ok=0），证明是字面替换而非删测试。

## L-120 ① 双态对照（判据必须能失败）

AC-5 的核心判据是「源树 `chisel` 归零」。**只跑一次成功态不能证明该判据有判别力**（L-119/L-120），故做双态对照：

| 态 | 操作 | 实测 |
|---|---|---|
| **失败态** | 向 `test/test_correction_hygiene.bats` **追加**探针行 `# PROBE chisel-probe-line` | `rc=1`，输出 `test/test_correction_hygiene.bats:323:# PROBE chisel-probe-line` + `🔴 源测试仍含 chisel（命中如上，file:line …）` |
| **成功态** | 还原文件后复跑 | `rc=0` |

**还原完整性**：`sha256sum` 前后**相同** = `5205c6d3b67d85c4d11189d997c1df9de0caff7830400f079aa9d428edbeab87` ⇒ 探针**未残留**，工作区无污染。

⇒ 判据对成功/失败两态给出**不同结果**（0 vs 1），且失败态**带 `file:line` 定位**（阶段 3 L3 m11 的原始诉求）。

## 全量回归（`npx bats test/ --formatter tap` + `make test`）

```
FULL_BATS rc=0 ok=973 not_ok=0
ok 971 CF-01: write_compliance_correction creates valid JSON with all fields
ok 972 CF-02: write_compliance_correction merges with existing + dedup
ok 973 CF-03: clear_compliance_correction removes the file
=== now make test ===
✅ bats: all tests passed
make test rc=0
```

- `npx bats test/ --formatter tap` = **973 ok / 0 not ok / rc=0**，`^not ok` 命中 0 条。
- `make test` = **rc=0**（末尾 `✅ bats: all tests passed`）。

**与基线比对**：基线（2026-09-23 实测）= 973 ok / 0 not ok / rc=0。本次 = **同值**，**无数字变化**，故**无需解释差异**。`make check-test-sync` rc=0（未漂移）。

## 6 维自查（R1–R6）

| 维度 | 结果 | 说明 |
|---|---|---|
| R1 认知过载 | ✅ | 仅字面替换，无新增结构/分支；`sample-proj-*` 命名自解释 |
| R2 变更传播 | ✅ | diff 恰为 write_files 的 4 项，0 越界（见下）；双源经 `make test-sync` 一致 |
| R3 知识重复 | ✅ | 未复制逻辑，仅改字面；未跨仓重复常量 |
| R4 偶然复杂 | ✅ | 无投机扩展；未借机重构测试 |
| R5 依赖混乱 | ✅ | 无新增依赖/引用 |
| R6 领域扭曲 | 🟢 轻微 · 已登记 | 中性占位 `sample-proj-skill` / `sample-proj_env` 的语义是「某个示例项目的 skill / 环境」，与原文（某内部项目的 skill 名 / 环境目录）语义位一致；但 `_env` 后缀在无原始项目名的语境下信息量降低，后续读者无法从占位串反推真实命名约定 —— 此为**脱敏本身的固有代价**（AC-5 的意图即切断该线索），非缺陷，登记于 `MINOR-DEFERRED.md` |

🔴 0 · 🟡 0 · 🟢 1（R6，已登记 MINOR-DEFERRED）。

## TDD 声明

**TDD 前置不可行（如实声明，不伪造）**：本 task 是**对既有测试文件本身**做脱敏替换，不存在「先写红灯测试再实现」的对象 —— 判据即 `grep` 归零 + 既有 134 用例保持绿。故以**等价证据链**替代：

1. **修复前实测计数**：`chisel` = 12 命中 / 4 文件（可失败态已被真实观测，非「构造性假绿」）。
2. **判据双态对照**：失败态 rc=1（含 file:line）+ 成功态 rc=0（L-120 ① 强制）。
3. **用例数守恒**：`^ok` = 134 ≥ 134 且 `^not ok` = 0 且 rc=0 —— 直接封堵「删除测试或用宽松断言规避」这条 out 段锁定的规避路径（阶段 3 L3 m2 原话：「只跑不计数 ⇒ 删测试仍绿」）。
4. **全量面**：973 ok / 0 not ok / rc=0，与基线同值。
5. **diff 纯字面性**：12/12 行、blob hash 两树相同。

以下反例形态**已实测排除**：只跑 bats 不计数（会漏判删测试）、判据无失败分支（恒绿）、双源只改一侧（`check-test-sync` 会红）。

## 越界检查（R6.5）

```
✅ 越界检查（R6.5）：
   - TASK write_files：4 项（test/ 与 flow-kit-bundle/test/ 各 2 个 .bats）
   - 实际 diff 涉及：4 项（+ 3 项文档面：T07-SUMMARY.md[新建] / MINOR-DEFERRED.md[追加] / TASK.md[仅 T07 status]）
   - 越界：0
```

**证明命令与实测**：

```
$ git diff --name-only HEAD test/ flow-kit-bundle/test/
flow-kit-bundle/test/test_correction_hygiene.bats
flow-kit-bundle/test/test_l3_review_defects_2026_09.bats
test/test_correction_hygiene.bats
test/test_l3_review_defects_2026_09.bats
```

- **产品代码零改动**（实测，命令与输出如下 —— 注：首次写成含 `install.sh` 的路径集，`git diff` 因该路径不存在而整体 `rc=128` 中止，**该次输出不可用作证据**，已改为仅列存在路径并复跑）：
  ```
  $ git diff --name-only HEAD -- flow-kit-bundle/hooks/ flow-kit-bundle/lib/ flow-kit-bundle/flow-kit/ Makefile package-flow-kit.sh
  (无输出)
  rc=0
  ```
  ⇒ 未触碰任何 hook / lib / prompt / 打包脚本 / Makefile。另实测 `install.sh` **不存在于本仓**（`absent: install.sh`），故先前那次 `rc=128` 属路径参数错误，非「有越界」。
- **CONTEXT.md 禁动清单**：`test/` 目录禁放非 `.bats` 文件 —— 本次只改既有 `.bats`，**未新增任何文件到 `test/`**，合规；`package-flow-kit.sh` / `flow-kit-bundle.tar.gz` / `.gitignore` / `.flow-active.goal` 均未触碰。
- **进入本任务前已存在的 workspace 改动（非 T07 产物，不纳入本次 `git add`）**：`.specs/CONTEXT.md`、`.specs/STATE.md`（`M`）；`.specs/adr/028-gate-baseline-allowlist.md`、`.specs/health-fix-2026-09b/{CHANGE,REQUIREMENT,INDEPENDENT-REVIEW-1,INDEPENDENT-REVIEW-2,INDEPENDENT-REVIEW-3}.md`、`.specs/health/2026-09-22-FULL-SWEEP.md`（untracked）。
- **`git add` 用显式路径**（无 `-A` / 无 `.`）：4 个 `.bats` + `TASK.md` + `T07-SUMMARY.md` + `MINOR-DEFERRED.md`。

## 门禁纪律（L-126）

- **未使用 `git commit --no-verify`**（本 change 明令禁止）。pre-commit **真跑**，结果见下节「提交」。
- 门禁若红，按 L-126 处置：复现 → 定位 → 如实报告；判定为门禁自身问题时**停下报 BLOCKED**，不绕过。

## 提交

见文末「提交与状态」段（sha 由 `.flow-active.goal.task_progress` 权威记录；L-126 ② 「提交内容不可能写下自己的 sha」，故本文件不追求自指正确）。

## 遗留 / 移交项

1. **归档面（D9 的 `0.2.0.tgz` 重建 + 复扫）** —— 本 task `<done>` 限定为「AC-5 **源侧**」，未执行。`dist/dsh-flow-kit-0.2.0.tgz` 与 `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/` 仍含旧字面（修复前实测 tgz = 6 处）。**AC-5 全量验收需要一并重建归档并逐档复扫（禁通配 —— 见 REQUIREMENT 的 L2 R2 证伪段）**，请主 agent 指派对应 task 或在阶段 5 收口。
2. **`.specs/health/2026-09-22-FULL-SWEEP.md`** 仍含大量 `chisel`（文档面，未在 T07 写面内，AC-5 判据也不扫 `.specs/`）—— 若 AC-5 的口径要覆盖文档，需另行裁定。
3. **`sample-proj_env` 命名信息量** —— 登记于 `MINOR-DEFERRED.md`（🟢 R6）。
