# T03-SUMMARY · 29 号改造：l2-missing 退场前置 + 写入 compliance-priority 条件写

> change-id: correction-hygiene-state-guard · task T03（Wave 1 并行）· 2026-09-01 · 执行者：Dev

## 做了什么

对 `flow-kit-bundle/hooks/stop/29-independent-review.sh`（Stop hook 模块 · 唯一维护源 · 其余段落禁动）做 3 处改造：

1. **M0 l2-missing 退场检测块（盲审 R2 · D4 · AC-4）** — 插入在 Gate 3（L3 激活判定）**之前**，与 L3 激活解耦：
   - 前置条件：`.flow-active.correction` 存在且 `.type` 经 `jq -e '.type // "" | test("l2-missing")'` 命中（合并标签 `l2-missing+state-integrity` 同样命中，R7，禁止精确相等）。
   - 触发条件：对应 `INDEPENDENT-REVIEW-<phase>.md` 已含 `## L2 盲审` 段 **或** gate_config ≠ both（经既有 `fk_phase_gate_key` + `fk_normalize_gate_val` helper 读取）。
   - 动作双态（D4）：纯 type `l2-missing` → 文件级 `rm`（对齐 `write_model_missing_clear` 范式）；合并标签 → 内联 jq 剥离 `l2-missing` 段（`split("+") | map(select(. != $seg)) | join("+")`，type 改回 `state-integrity`），violations[] 原样保留，mktemp 原子写。
   - stderr 审计行在清除**之前**输出：`[29-l2-retire] clearing l2-missing (was: <old type>)`。
   - 未触发（gate=both 且 IR 无 L2 段）→ 块内不动作，落入既有 D4 门 l2-missing 写入逻辑（保持）。
2. **L38 yield 显式化（盲审 R2/N2）** — `jq empty ... || exit 0` 行为零改动，其上加注释「外来/损坏 .flow-active 让位由 33 号承担（F2 单一 actor），29 号此处静默让位」，消除 DESIGN 0.5.1/CHANGE.md 例外登记与 diff 的对账歧义。
3. **写入保护（D8 · 盲审 R1）** — `_write_l2_missing_correction` 由 `jq -n > file` 整文件覆写改为 compliance-priority 条件写：逐字对齐 `write_model_missing_correction`（correction-file.sh:116-123）的单步 jq `if .type=="compliance" and ((.violations // []) | length > 0) then . else $new end` + mktemp 原子写。correction 已有 compliance 条目（28 号写入，ADR-024/ADR-013）时不覆盖。fail-open：任一步失败静默返回 0，不断 Stop 链。

## 改动文件

| 文件 | 改动 |
|---|---|
| `flow-kit-bundle/hooks/stop/29-independent-review.sh` | +67 / -3，仅此 1 文件（write_files 约束满足） |

`flow-kit-bundle/hooks/stop/lib/correction-file.sh`（T01 文件）与其余文件零改动。T01 的 `correction_file_strip_type()` 共享抽象按指令只在本文件注释中引用（M0 块注释说明 T02/T04 后续统一切换），运行时不调用（T01 未落地前不存在）。

## verify 真实输出

```
$ bash -n flow-kit-bundle/hooks/stop/29-independent-review.sh && shellcheck -e SC1091 -S error flow-kit-bundle/hooks/stop/29-independent-review.sh
SYNTAX OK
SHELLCHECK OK

$ ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_stop_chain.bats test/test_independent_review_model.bats
55 ok / 0 not ok / BATS RC=0（本 npx 包装不打印 summary 行，exit code 权威）

$ ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test-l2-first-correction.bats test/test_dual_review_merge.bats   # 额外回归：重写函数端到端路径
19 ok / 0 not ok / RC=0
```

### 功能 smoke（/tmp/t03-smoke · 直接执行完整脚本 · 受控 env：PROJECT_ROOT+HOOK_BASE_DIR+HOOK_TMP_DIR+CONFIG_FILE）

- **Smoke A（合并标签剥离）**：correction type=`l2-missing+state-integrity` + 2 条 violations + IR 含 `## L2 盲审` + gate_config=L2 →
  stderr `[29-l2-retire] clearing l2-missing (was: l2-missing+state-integrity)`；终态 correction `{"type":"state-integrity", ..., violations:[2 条原样]}`；rc=0。
- **Smoke B（纯 type rm）**：correction type=`l2-missing` + IR 含 `## L2 盲审` + gate=L2 → stderr `(was: l2-missing)`；文件被 rm；rc=0。
- **Smoke C（未触发）**：gate=both + IR 无 L2 段 → 退场不触发，既有 D4 门重写 l2-missing（type 仍 l2-missing）；rc=0。
- **Smoke D（compliance 保护）**：correction type=`compliance` + 2 条 violations + gate=both + IR 无 L2 → 跑 `_write_l2_missing_correction` 后 `diff` 与前置文件**零差异**（compliance 原样保留）；rc=0。
- 全部路径 rc=0 → **fail-open 保持**（内部错误不破坏 Stop 链）。

## 破坏性变更检查（1.8）

改动的 3 处均为**函数内部/新增块**，不改变任何既有函数签名、gate 语义、exit code 语义、模块开关。`_write_l2_missing_correction` 引用图（全仓 grep）：

```
./flow-kit-bundle/hooks/stop/29-independent-review.sh:24:  _write_l2_missing_correction() {          # 定义（本任务改写函数体，签名 <phase> <change_id> 不变）
./flow-kit-bundle/hooks/stop/29-independent-review.sh:134:  _write_l2_missing_correction "$phase" "$change_id"    # 调用点 1（L2-first quick gate，L-072）
./flow-kit-bundle/hooks/stop/29-independent-review.sh:226:  _write_l2_missing_correction "$phase" "$change_id"    # 调用点 2（D4 L2 检测门 fallback）
./flow-kit-bundle/hooks/session-start/flow-kit-resume.sh:165:  # 注释引用（非调用）
（.claude/hooks/、dist/dsh-flow-kit/ 为运行时副本/分发拷贝，非维护源，未触碰）
```

两处调用点均为既有路径（gate=both + L2 缺失时写 flag），新函数体行为向后兼容：无 compliance 时写 l2-missing（AC-I b 实测通过），有 compliance 时保留（Smoke D）。

## 6 维自查

1. **功能正确性**：M0 双态清除、触发条件、审计行、未触发保活均经 4 组 smoke 实测；D8 compliance 保护经 diff 零差异验证。
2. **既有抽象复用**：gate_config 读取沿用 `fk_phase_gate_key`/`fk_normalize_gate_val`；IR 定位沿用 `INDEPENDENT-REVIEW-${phase}.md` 既有路径；写入范式逐字对齐 `write_model_missing_correction`（R6.4，见下）。
3. **命名/风格**：注释用既有模块中文注释风格；变量 kebab 路径、snake_case 局部变量与文件内一致；`test("l2-missing")` 用 jq 内建正则无 bash 内联 regex 风险。
4. **禁动清单/范围**：write_files 仅 29 号；correction-file.sh（T01）、gate 核心链、L3 流程段、l2-missing 检测触发段零改动；`.claude/hooks/` 运行时副本未触碰（非维护源）。
5. **fail-open/错误处理**：所有新路径 `|| { ...; return 0; }` / `|| rm -f tmp` / `|| true` 兜底，`set -euo pipefail` 下 jq/mktemp 失败不退出非零；4 组 smoke 全 rc=0。
6. **测试覆盖**：必测 test_stop_chain + test_independent_review_model 55 全绿；额外 test-l2-first-correction（重写函数实跑路径）+ test_dual_review_merge 19 全绿；T04 将补 test_correction_hygiene.bats 的 AC-4 双态 + R1 用例。

## 越界检查

```
$ git diff --name-only
.specs/CONTEXT.md                       ← 主 agent phase 3 fix loop 既改（本任务未触碰）
Makefile                                ← 主 agent phase 3 fix loop 既改（check-validate 权威直判行，T04 核验）
README.md                               ← 既有 test 标记改动（本任务未触碰）
flow-kit-bundle/hooks/stop/29-independent-review.sh   ← 本任务唯一改动（+67/-3）
flow-kit-bundle/hooks/stop/lib/correction-file.sh     ← T01 并行改动（本任务未触碰）
```

**本任务 write_files 实际改动 = 1 文件**（`flow-kit-bundle/hooks/stop/29-independent-review.sh`）；其余为并行任务（T01 / 主 agent）在本次会话开始前已存在的 working-tree 改动，与 T03 无关。

## 既有抽象 grep（R6.4 沿用确认）

```
$ grep -n "write_model_missing_clear" flow-kit-bundle/hooks/stop/29-independent-review.sh flow-kit-bundle/hooks/stop/lib/correction-file.sh
flow-kit-bundle/hooks/stop/29-independent-review.sh:145: write_model_missing_clear "L3"     # 既有调用（正常路径清 model-missing，未改动）
flow-kit-bundle/hooks/stop/29-independent-review.sh:77:  # 动作双态（D4）：纯 type l2-missing → 文件级 rm（对齐 write_model_missing_clear
flow-kit-bundle/hooks/stop/lib/correction-file.sh:129:  # write_model_missing_clear <layer> — clear the model-missing correction ...
flow-kit-bundle/hooks/stop/lib/correction-file.sh:132: write_model_missing_clear() {          # 定义（type 精确匹配 + rm 的退场范式）
```

M0 退场纯 type 分支沿用 `write_model_missing_clear` 的文件级 rm 范式（精神沿用，匹配放宽为 `contains()` 语义 —— R7 合并标签破坏精确匹配，DESIGN D4）。
