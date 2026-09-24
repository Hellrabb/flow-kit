# T-FIX-05-SUMMARY — Makefile NFR 判据去重（F8）

## 1. 任务与判据引用

- 任务：`.specs/health-fix-2026-09b/TASK.md:1776-1828`（`<task id="T-FIX-05">`）。
- 判据：`<verify>` 锚定区间 `TASK.md:1798-1825`（锚定行抽取，规避 L-153 `<done>` 内 `<verify>` 字面量陷阱）。
- 触发源：阶段 6 审查 🟡 F8（`REVIEW.md` §B）—— `Makefile` 的 NFR 判据正文（76 条语句）在 `check-nfr-portability`（wrapper）与 `check-nfr-portability-internals` 两处逐字重复，存在分叉风险。
- `<write_files>`：`Makefile`、`test/test_nfr_portability_gate.bats` + `flow-kit-bundle/test/test_nfr_portability_gate.bats`（`make test-sync`）、`dist/`（重建，gitignored）。
- 收尾顺序（硬契约）：`make test-sync` → `bash package-dsh-plugin.sh` → `check-hooks-sync check-test-sync check-dist` → `make check`。

## 2. 变更清单

### `Makefile`（净 −42 行：+9/−77 on internals 注释 + wrapper 薄壳）
- `check-nfr-portability`（`:247`，原 88 行 wrapper recipe）改为**薄壳 13 行**：
  1. `@echo "🔍 ..."`（自证行，stdout）
  2. `mktemp` ×2（`NFR_OUT` / `NFR_RC`）+ `export NFR_RC_FILE="$$NFR_RC"`
  3. `bash -c 'make --no-print-directory check-nfr-portability-internals >"$$NFR_OUT" 2>&1 || true'`
  4. `rc=$(cat "$$NFR_RC" 2>/dev/null || echo 2)` → `case` 三态映射（0→透出 stdout；3→透出 stdout + exit 0；1/*→透出 stderr + exit 1）
- `check-nfr-portability-internals`（`:162`，79 行）**不变**：唯一判据正文（`_write_rc`/`_report_viol`/awk `BEGIN{c=0;found=0}`/`BAN=`/`TMOUT=`/`_write_rc 0|1|3`），rc∈{0,1,3} 经 `$NFR_RC_FILE` 回传。
- 删除：wrapper 内重复的 76 条判据语句（`_write_rc`/`_report_viol` 整体函数 + BASE 探测 + ADDED/NEWF + BAN/TMOUT 扫描 + CHK 语法门禁）。
- 注释：薄壳段补「为什么不复发」「为什么用 `bash -c 'make ...'` 而非 `$(MAKE)`」（后者触发 GNU make `-n` 特例，见 §5）。

### `test/test_nfr_portability_gate.bats`（+13 行，既有用例内追加，计数不变 1025）
- 在 `@test "包装层把内部 rc=3 映射为 exit 0..."` 内追加两条**钉住断言**（TDD 红转绿锚）：
  1. `_report_viol() {` 在整份 `Makefile` 中 `grep -c` == **1**（判据正文唯一源）；复制回 wrapper ⇒ 立即转红。
  2. wrapper recipe 行数（verify 口径 `awk '/^check-nfr-portability:/,/^$/'`）< **30**（薄壳）；判据未删 ⇒ 立即转红。
- 镜像：`flow-kit-bundle/test/test_nfr_portability_gate.bats` 同步（`make test-sync`）。

## 3. 判别式证据（TDD：先红后绿）

### 3.1 修复前红（钉住断言 + 原始红输出原文）
在改 `Makefile` **之前**，仅追加钉住断言并同步到 bundle，跑 `npx bats test/test_nfr_portability_gate.bats`：

```
1..7
ok 1 空变更集（base=HEAD，无 .sh 改动/新增）⇒ 内部 rc=3 且 stdout 含 SKIP:（未验证 ≠ 通过）
ok 2 新增行含 sed -i ⇒ 内部 rc=1 且 stderr 归因到 file:line
ok 3 合规惯用法 stat -c … || stat -f … ⇒ 不误报（内部 rc=0）
ok 4 整行注释里的 sed -i ⇒ 不误报（内部 rc=0）
ok 5 未跟踪新增 .sh 含 GNU-only 构造 ⇒ 内部 rc=1（NEWF 面）
not ok 6 包装层把内部 rc=3 映射为 exit 0 且 stdout 保留 SKIP:（SKIP ≠ PASS）
# (in test file test/test_nfr_portability_gate.bats, line 123)
#   `{ echo "🔴 F8：_report_viol() { 在 Makefile 中出现 $_viol_cnt 次（预期 1，判据正文已复制回 wrapper）"; false; }' failed
# 🔴 F8：_report_viol() { 在 Makefile 中出现 2 次（预期 1，判据正文已复制回 wrapper）
ok 7 违规变更集上包装层不放过：make 非零退出且 stderr 保留 file:line 归因
```
test 6 转 red（`_report_viol() {` 出现 2 次），判据正文复制回 wrapper 已被钉住。修复前 baseline 计数仍 1025（断言追加进既有用例，未新增用例）。

### 3.2 修复后绿
改 `Makefile` 为薄壳后，跑 `npx bats test/test_nfr_portability_gate.bats`：

```
1..7
ok 1 空变更集（base=HEAD，无 .sh 改动/新增）⇒ 内部 rc=3 且 stdout 含 SKIP:（未验证 ≠ 通过）
ok 2 新增行含 sed -i ⇒ 内部 rc=1 且 stderr 归因到 file:line
ok 3 合规惯用法 stat -c … || stat -f … ⇒ 不误报（内部 rc=0）
ok 4 整行注释里的 sed -i ⇒ 不误报（内部 rc=0）
ok 5 未跟踪新增 .sh 含 GNU-only 构造 ⇒ 内部 rc=1（NEWF 面）
ok 6 包装层把内部 rc=3 映射为 exit 0 且 stdout 保留 SKIP:（SKIP ≠ PASS）
ok 7 违规变更集上包装层不放过：make 非零退出且 stderr 保留 file:line 归因
```
7/7 全绿。钉住断言（test 6）转绿：`_report_viol() {` 现出现 1 次、wrapper recipe 13 行（<30）。F3 现有 7 例零行为变更全绿（三态映射 · `SKIP:` 保留 · `file:line` 保留 · 空变更集 rc=3 语义）。

## 4. `<verify>` 原样复跑输出尾部 + rc

逐字复跑 `TASK.md:1798-1825` 的 `<verify>` 块（`bash /tmp/tfix5-verify.sh`）：

```
wrapper_recipe_lines=13 internals_recipe_lines=79
npm notice run npx
npm notice run 'bats' --count test/
bats: 1025 ok / 0 not-ok / count=1025
VERIFY rc=0
```

- `make -n check-nfr-portability` rc=0（可解析）
- `WRAP=13 < 30` ✓ · `INNER=79 ≥ 40` ✓
- `npx bats test/test_nfr_portability_gate.bats` rc=0（7 ok）
- `npx bats test/` rc=0（1025 ok / 0 not-ok / count=1025）
- 真实仓 `make check-nfr-portability` rc=0（输出 `✅ NFR 兼容性判据通过`）
- `make check-hooks-sync` rc=0 · `make check-test-sync` rc=0 · `make check-dist` rc=0
- `make check` rc=0（尾部 `✅ make check: 全部通过`）

## 5. 设计要点：为什么用 `bash -c 'make ...'` 而非 `$(MAKE)`（本任务踩到的坑）

初版薄壳用 `$(MAKE) --no-print-directory check-nfr-portability-internals`，`make -n check-nfr-portability` 返回 **rc=2**（`<verify>` 的 `make -n ... || 🔴 无法解析` 直接判红）：

- GNU make 的 `-n` 特例：配方行若以 `make` 开头、或含 `$(MAKE)`/`${MAKE}` 宏，**即使在 `-n` 模式也会实际执行**。
- `$(MAKE)` 展开 = `make` ⇒ 触发特例 ⇒ 递归子 make 实际跑。
- 子 make 也带 `-n`（`MAKEFLAGS` 下传）⇒ internals 的 `@bash -c` 只打印不执行 ⇒ `NFR_RC_FILE` 从未被写 ⇒ wrapper `cat "$$NFR_RC"` 返回空 ⇒ `echo 2` ⇒ `case *) exit 1` ⇒ make 报 `Error 1` ⇒ rc=2。
- 旧内联版无此问题：配方行以 `@NFR_OUT=$(mktemp)` 开头（非 make）⇒ `-n` 模式整行只打印不执行 ⇒ rc=0。

**收敛**：薄壳的递归调用经 `bash -c 'make ...'` 包裹——配方行以 `bash` 开头且**不含** `$(MAKE)`/`${MAKE}` 字面 ⇒ 不触发 `-n` 特例 ⇒ `-n` 模式只打印不执行 ⇒ rc=0（判据可解析）；真实运行时 `bash -c` 执行子 make，make 变量（`FLOW_KIT_CHANGE_BASE`）由命令行/环境自动下传，`export NFR_RC_FILE` 下传到 internals 的 bash -c，三态映射语义等价。已用最小复现 Makefile（`/tmp/test-n2-makefile`，已删）验证此行为。

## 6. 门禁 rc 一览

| 门禁 | rc | 备注 |
|---|---|---|
| `make -n check-nfr-portability` | 0 | 可解析（`bash -c` 包裹规避 `-n` 特例） |
| `npx bats test/test_nfr_portability_gate.bats` | 0 | 7/7 ok（钉住断言转绿） |
| `npx bats test/` | 0 | 1025 ok / 0 not-ok |
| `make check-nfr-portability`（真实仓） | 0 | `✅ NFR 兼容性判据通过` |
| `make check-hooks-sync` | 0 | 副本一致 |
| `make check-test-sync` | 0 | 双源一致 |
| `make check-dist` | 0 | dist 已重建 |
| `make check` | 0 | 尾部 `✅ make check: 全部通过` |
| `<verify>` 整块 | 0 | 逐字复跑 rc=0 |

## 7. 越界检查（R6.5）

- TASK `<write_files>`：`Makefile`、`test/test_nfr_portability_gate.bats`、`flow-kit-bundle/test/test_nfr_portability_gate.bats`、`dist/`（gitignored）。
- 实际 diff 涉及：`Makefile`、`test/test_nfr_portability_gate.bats`、`flow-kit-bundle/test/test_nfr_portability_gate.bats`。
- 越界：**0** ✅（`.specs/**` housekeeping 文件为主 agent 暂存/未跟踪，未纳入本提交）。

## 8. 沿用既有抽象 grep（R6.4）

- NFR 判据正文：已在 `Makefile:162` `check-nfr-portability-internals` 存在 ⇒ **沿用为唯一源**，未另起。
- 三态 rc 回传通道 `$NFR_RC_FILE`：既有机制（`_write_rc`）⇒ 沿用，未改。
- 薄壳 `case` 三态映射：沿用旧 wrapper 的映射分支（0→stdout、3→stdout+exit 0、1/*→stderr+exit 1），仅把判据正文换成递归调用。
- 参考先例：`flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`、`check-path-privacy.sh`（T17/T08 定稿的薄壳接线模式）⇒ 本任务 wrapper 薄壳与其同构（接线 + 暴露 rc），但判据正文因 D8 F2 自排除边界仍留 Makefile recipe（不落 .sh）。

## 9. 6 维自查（内置快查 · 本任务无生产代码逻辑新增）

- **R1 认知过载**：wrapper recipe 13 行，internals 不变（79 行）⇒ 无。
- **R2 变更传播**：仅 `<write_files>` 声明文件被改 ⇒ 无越界。
- **R3 知识重复**：本任务**正是收敛重复**（76 条 ×2 → ×1）。
- **R4 偶然复杂**：`bash -c 'make ...'` 非冗余——是规避 GNU make `-n` 特例的最小手段，注释已说明；无「以后可能用到」的扩展点。
- **R5 依赖混乱**：N/A（Makefile recipe）。
- **R6 领域扭曲**：变量名沿用（`NFR_OUT`/`NFR_RC`/`NFR_RC_FILE`/`_write_rc`/`_report_viol`）。

## 10. 破坏性变更评估（R4.6）

- 删除既有代码 ≥ 5 行：**是**（wrapper 删 76 条判据语句）。
- 但所删为**逐字重复的判据副本**，唯一源仍存于 `check-nfr-portability-internals`（未删一行）。
- 引用图：`check-nfr-portability` 被 `check:` 先决条件（`Makefile:106`）+ bats 7 例 + `<verify>` 引用；薄壳保持对外 rc∈{0,1} 契约不变（三态映射语义等价，F3 7 例全绿为证）。
- 回归覆盖：F3 常设网 7 例（三态 + 包装映射 + file:line + SKIP）+ 全量 1025 例全绿 ⇒ 删除有测试覆盖。

## 11. 遗留与未坐实项

- **无遗留**：F8 已收敛，`<verify>` 全绿，三一致性 + `make check` 全绿。
- 钉住断言已固化为常设判据（test 6 内），复发（判据正文复制回 wrapper）会被 CI 立即转红。
- `deferred`：`[]`（无延期项）。

## 12. 你没有做的事

- 未改 `check-nfr-portability-internals` 判据正文一行（唯一源，保持不变）。
- 未改 `<verify>` / `<action>` / `<done>` 契约（仅执行）。
- 未碰冻结件（`CHANGE.md`/`INDEPENDENT-REVIEW-1~3.md`/`REQUIREMENT.md` —— `A ` 暂存态属主 agent housekeeping；`MINOR-DEFERRED.md`/`REVIEW.md`/`INDEPENDENT-REVIEW-6.md`/`T-FIX-0*-SUMMARY.md`/`TASK.md`/`.flow-active`）。
- 未改 `.specs/STATE.md` 基线计数（本任务未新增用例，计数仍 1025，无变更需要）。
- 未声称「提交通过 git hook 门禁」——本仓 `git config core.hooksPath` 为空串，hook 未生效；门禁由我**手动**执行并汇报 rc（见 §6）。

## 13. 台账五字段（`.flow-active` `goal.task_progress`）

```json
{
  "id": "T-FIX-05",
  "commit_sha": "6e94d60e1dec618936d7e960035d03a1a1811fb5",
  "fix_rounds": 0,
  "deferred": [],
  "completed_at": "2026-09-25T00:08:38+08:00"
}
```
- commit `cI` = `2026-09-25T00:08:24+08:00`
- ledger `completed_at` = `2026-09-25T00:08:38+08:00`
- **Δ = 14 s**（≤ 120 s ✓，台账时点规则 9 合规）
