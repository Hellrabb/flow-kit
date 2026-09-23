# T18-SUMMARY · AC-6 接入 `Makefile` 目标 `check-path-privacy` + 纳入 `check:` 先决条件

> 变更 `health-fix-2026-09b` 阶段 4（DEV）· Wave 3 · 2026-09-23
> 产物：`Makefile`（产品件）+ `TASK.md`（仅 T18 状态 `pending`→`done`）
> 依 L-129：本 SUMMARY 所有本机绝对路径已 de-shape 为 `<repo>` / `$HOME` / `/home/<acct>/` 形态；rc、命令、输出文本与数字保持原样。

## 1 任务理解

T18 = 把 AC-6 的 `check-path-privacy.sh`（T17 产物）接入 `Makefile`：
1. 新增 `check-path-privacy` 目标（薄壳：`@echo` 说明 + `@bash .../check-path-privacy.sh`），紧邻 `check-gate-sync`。
2. 追加为 `check:` 先决条件（在既有条目之后，保持顺序不变）。
3. `.PHONY:` 行同步登记。
4. **不得**写 `|| true`、**不得**引入 `rc=3`（ADR-027②：make 对非零一律判失败 ⇒ 长期红）。
5. 边界：NFR 可移植性判据另立 `check-nfr-portability`（T28），不得混入本目标（DESIGN §1 D8 F2）。

## 2 边界复述

- 只改 `Makefile` 产品件 ＋ `TASK.md`（仅 T18 状态行）＋ 新建 `T18-SUMMARY.md`。
- **不创建** `path-privacy-allowlist.txt`（T21 职责，fall-fail-closed 期间预期红）。
- **不改** `check-dist`（T24 收口）、不改 `check:` 既有条目顺序、不引入 `rc=3` / `|| true`。
- **不做** NFR 可移植性判据（T28）。
- 提交 = 显式路径；冻结集 6 文件（`.specs/adr/028*`、`.specs/health-fix-2026-09b/{CHANGE,REQUIREMENT,INDEPENDENT-REVIEW-1/2/3}.md`）不得夹带、不 reset/restore/stash。

## 3 改动（Makefile:行号 前后对照）

### ① `.PHONY:` 行（Makefile:5）
```
前: .PHONY: ... verify-claims check-dist check-gate-sync dsh-sync
后: .PHONY: ... verify-claims check-dist check-gate-sync check-path-privacy dsh-sync
```

### ② `check:` 先决条件行（Makefile:106）
```
前: check: test lint check-validate check-test-sync check-hooks-sync check-dist check-gate-sync
后: check: test lint check-validate check-test-sync check-hooks-sync check-dist check-gate-sync check-path-privacy
```

### ③ 新增目标（Makefile:120-127，紧邻 check-gate-sync 之后、check-dist 之前）
```
# ── check-path-privacy: 路径隐私门禁（health-fix-2026-09b · AC-6）──
# 薄壳：判据由 flow-kit-bundle/flow-kit/reference/check-path-privacy.sh（T17 定稿）承载，
#   target 只负责接线进 check: 先决条件并暴露失败 rc。
# 二值退出（0=通过 / 1=清单外命中≠0 或 fail-closed）；常设允许清单 T21 落档前预期 rc=1。
# 边界（T18 / DESIGN §1 D8 F2）：NFR 可移植性判据另立 check-nfr-portability（T28），不在此。
check-path-privacy:
	@echo "🔍 make check-path-privacy: 路径隐私（允许清单外命中 / fail-closed）检查 ..."
	@bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
```

**改动行号**（diff 后实测）：`.PHONY` @5、`check:` @106、新目标 @120-127。`git diff --stat -- Makefile` = `1 file changed, 11 insertions(+), 2 deletions(-)`。

## 4 判别力·真实输出

### 判别力 A（删 `.PHONY` 登记 → 断言变红 → 复原）
```
===== DISCRIMINATOR A: remove check-path-privacy from .PHONY =====
🔴 .PHONY 未登记 check-path-privacy（预期变红）
--- restoring ---
✅ restored
```

### 判别力 B（删 `check:` 先决条件 → 断言变红 → 复原）
```
===== DISCRIMINATOR B: remove check-path-privacy from check: line =====
🔴 未接入 make check（预期变红）
--- restoring ---
✅ restored
```

### 判别力 C（反掩蔽 · 临时注入 `|| true` → 新第 3 条判别必须变红 → 复原）
```
===== DISCRIMINATOR C: inject || true into recipe (anti-masking) =====
127:	@bash flow-kit-bundle/flow-kit/reference/check-path-privacy.sh || true
make rc=0 (script exits 1, || true masks → expect 0)
script rc=1
🔴 脚本失败但 make 返回 0 ⇒ 接线掩盖了失败（禁 || true）——反掩蔽判别变红 ✓
--- 复原后 make -n check-path-privacy / make -n check 均 rc=0 ---
```

复原后 `git diff -- Makefile` 只剩正式改动（`.PHONY` / `check:` / 新目标 三处），无 `|| true` 残留，无备份文件残留。

## 5 验证判据（原样抽取自 TASK.md · 15 行）

> 注：原 6 行判据因「GNU make 对任何失败 recipe 恒返回 rc=2」与实际不符（原判据末条 `case "$_rc" in 0|1)` 不可满足）。主 agent 已复核并重写为**分层断言 15 行**，登记 L-135（详见 §6）。本 SECTION 为对新 15 行判据的原样执行。

```
$ bash /tmp/t18v.sh   # 15 行（wc -l = 15，bash -n 通过）
rc=0
```

判据覆盖：目标存在 / 接入 `make check` / Makefile 登记 / 干跑含脚本路径 / `.PHONY` 登记 / 脚本直接调用断言 `0|1` / make 目标断言 `0|2` / 反掩蔽（脚本非 0 ⇒ make 不得为 0）。

## 6 裁决记录（本次 task 的关键发现 · 对应主 agent L-135）

五组 GNU make 退出码实验（`<repo>` 下的 `/tmp` 沙箱内，配方 `@exit N` / `@false` / `@bash -c 'exit N'`）：

| 配方内退出码 | 脚本实退 | make 实返 |
|---|---|---|
| `@exit 1` | — | **2** |
| `@exit 2`～`5` | — | **2** |
| `bash .../check-path-privacy.sh`（脚本 exit 1，fail-closed） | 1 | **2** |
| `@bash -c "exit 1"` | — | **2** |
| `exit 0`（成功场景） | 0 | 0 |

**结论（L-135）**：GNU make 4.3 对**任何**失败 recipe **恒返回 rc=2**，绝不传播配方内脚本的 `rc=1`。因此：
- 「二值退出」是 **`check-path-privacy.sh` 脚本**契约（0=通过 / 1=fail-closed 或清单外命中），不是 make 目标的退出码。
- 原 T18 判据末条 `case "$_rc" in 0|1)` 对**失败中的目标**（今天 T21 未落标 ⇒ fail-closed ⇒ make rc=2）不可满足，属判据语义缺陷。
- 修正为分层断言：**脚本**限 `0|1`（禁 SKIP/rc=3）；**make 目标**限 `0|2`（0=成功 / 2=recipe 失败）；**反掩蔽**：脚本非 0 时 make 不得为 0（防 `|| true` 掩盖失败）。

## 7 门禁真实输出

| 门禁 | 结果 | rc |
|---|---|---|
| `make test` | **973 ok / 0 not ok** | **0** |
| `make lint` | `✅ shellcheck: no errors found`（SCANNED_FILES 全量扫描） | **0** |
| `make check-hooks-sync` | `✅ hooks 副本一致（漂移 0）` | **0** |
| `bash sync-hooks.sh --check` | `✅ hooks 副本一致（漂移 0）` | **0** |
| `make check-path-privacy` | `🔴 允许清单缺失（fail-closed）`（脚本 rc=1 / make rc=2） | 2（预期红）|
| `make check-dist` | 未跑精华（预期红） | 2（预期红 / T24 收口）|
| `make check` | 聚合（test/lint/… 绿 + check-path-privacy 与 check-dist 红） | 预期红（T21+T24）|

> `make check` 与 `make check-dist` 预期红属 T21（允许清单未落档）与 T24（check-dist 收口）职责，**按 §4要求不修、不据此判失败**，如实记录 rc=2 及原因。

## 8 6 维自查

- **R1 认知过载**：`check-path-privacy` 目标 2 行 recipe，无复杂逻辑；判据薄壳化（判据在脚本内）✅
- **R2 变更传播**：`git diff -- Makefile` 仅 3 处（`.PHONY` / `check:` / 新目标）；`TASK.md` diff 仅 1 行（T18 status）；无越界文件 ✅
- **R3 知识重复**：目标照抄 `check-gate-sync` 薄壳风格（`@echo` + `@bash <脚本>`），与既有 5 个 `check-*` 目标一致，不重复实现逻辑 ✅
- **R4 偶然复杂**：未引入任何扩展点 / `rc=3` / 聚合新目标（DESIGN D5）；薄壳只接线、不承载判据 ✅
- **R5 依赖混乱**：make 目标只调用脚本，无反向依赖 ✅
- **R6 领域扭曲**：目标名 `check-path-privacy` 命名一致（沿用 `check-*` 前缀约定）✅

**破坏性变更**：本任务为新增目标 + 先决条件追加，无删除、无公共接口签名变更、无文件删除 ⇒ 不触发 1.8 破坏性变更协议。

**沿用既有抽象 grep（R6.4）**：grep `flow-kit-bundle/flow-kit/reference/*.sh` → 既有 `check-gate-sync.sh`（T08）为同款薄壳判据脚本先行者 ⇒ 沿用同址 + 同接线风格，不另起炉灶。

## 9 TDD 声明

本任务为**纯接线/纯配置目标**（新增 make 目标 + 先决条件 + `.PHONY` 登记），无业务逻辑代码；判据由既有 `check-path-privacy.sh`（T17 已 TDD）承载，目标本身无独立可测逻辑。依 4-dev TDD 例外「纯文档/纯配置任务可跳过 TDD」，本次不写 RED 单元测试；以 `make -n`（干跑）断言 + 三条判别力注入（判别力即本任务的 RED/GREEN 验证）替代。

## 10 遗留

- `make check-path-privacy` 预期红（rc=2：脚本 rc=1 fail-closed 映射到 make rc=2）——常设允许清单 `path-privacy-allowlist.txt` 于 **T21** 落档后转绿。
- `make check` / `make check-dist` 预期红——分别由 T21 / T24 收口。
- 无其它遗留；本 task 不需要 PROGRESS.md（无中途断点）。