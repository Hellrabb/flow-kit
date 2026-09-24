# ADR-029 · 阶段门标记有效性（「存在」≠「有效」）

- **Status**: Accepted
- **Date**: 2026-09-24
- **Change**: health-fix-2026-09b（T-FIX-02 · 收敛 TD-059）

## Context

阶段门（PreToolUse `independent-review-gate.sh`）判定「独立审查是否完成」的唯一依据曾是**文件存在性**：

```bash
[[ ! -f "$done_marker" ]]      # done-validation.sh:79（HEAD 旧实现）
```

即 `.specs/<id>/.independent-review-<phase>.done` **存在** ⇒ `fk_independent_review_gate_active` 返回 1（读作「门未开」）⇒ Gate3 `_gate_active_check`（`gate-helpers.sh:174`）返回 0 ⇒ `_run_review_gates` 直接 `exit 0` 放行。后果：Gate4 的 `_gate_done_validation`（`gate-helpers.sh:186` → `fk_validate_done_marker … transition`）**在 commit 路径上永远不可达** —— 而 Tier-1（≥6 行 / 非空 / 6 键 KVP / 值域）与 Tier-2（`L2_verdict` ↔ `INDEPENDENT-REVIEW-<phase>.md`）正是为「标记是否可信」而写的校验。

沙箱实测（`reproduce-phase-gate.sh` 状态 B2/B3 · 2026-09-24）：

- `touch` 出的空标记 ⇒ rc=**0**（放行）
- 标记写 `L2_verdict=pass` 而审查档写 `**Verdict**: fail` ⇒ rc=**0**（放行）

唯一实际防线是 D7 path-guard，而它只对**命令文本**做文件名匹配（程序化拼接文件名即可绕过）⇒「存在即放行 + 文本匹配守卫」的组合可被一次拼接绕过。

## Decision

`fk_independent_review_gate_active` 在标记**存在**时必须校验其有效性：

```bash
local done_marker="${PROJECT_ROOT}/.specs/${change_id}/.independent-review-${phase}.done"
[[ -f "$done_marker" ]] || return 0                                                   # 不存在 ⇒ 门生效
fk_validate_done_marker "$done_marker" "$phase" "$change_id" transition || return 0    # 无效 ⇒ 门仍生效
return 1                                                                              # 存在且有效 ⇒ 放行
```

- **必须用 `transition` 而非 `write`**：只用 Tier-1 时「6 键齐但 `L2_verdict` 与审查档 verdict 相悖」会被误判有效 ⇒ Gate3 直接 `exit 0` 放行；`transition` 让该态落到 Gate4 被 Tier-2 拦下（Gate4 本就在同进程用 `transition`，`fk_extract_l2_verdict` 可用性已由它验证）。
- **返回码语义不变**（ADR-004）：0 = 门生效（拒绝），1 = 放行。调用方无需改动 —— Gate3 `if _gate_active_check; then exit 0; fi`、`29-independent-review.sh:104`、`31-auto-advance.sh:73-74`、`lib/flow-kit-artifacts.sh:111` 都按同一契约消费。
- **`phases_done` 短路保持**（`done-validation.sh:116-123` 内，先于 Tier-1）：历史阶段 `.done` 不因本变更被追溯校验。
- **Gate7 拒绝报文不变**（`gate-checks-review.sh:72`）：无效标记走 Gate4 失败 → Gate5/6 无操作 → Gate7 `return 2`，报文与「无标记」态逐字一致。
- `done-validation.sh:24-38` 的契约注释与标记判定处的行内注释同步改为「存在**且有效**」。

### 新语义下被拒的标记类别

| 类别 | 形态 | 拦截点 |
| --- | --- | --- |
| 空文件 | `touch` 出的 0 字节标记 | Tier-1 `[[ -s ]]` |
| 缺键 | 6 键不全（如缺 `L3_verdict`）/ 行数 < `MIN_MEANINGFUL_LINES=6` | Tier-1 行数 + KVP |
| 值域非法 | `L2_verdict=INVALID_VALUE` 等不在 `pass\|fail\|skipped` / `pass\|fail\|timeout\|error\|skipped` | Tier-1 正则 |
| 口径相悖 | 6 键齐且值域合法，但 `L2_verdict` ≠ 审查档 `**Verdict**:` | Tier-2 T4（仅 `transition`） |

## Consequences

- ✅ commit / `gh pr create` / 阶段切换路径上，Tier-1 + Tier-2 不再被 Gate3 短路（TD-059 收敛）；`reproduce-phase-gate.sh` 的 B2/B3 由「缺口实证（期望 rc=0）」改判为「期望 rc=2」，并新增 B4（缺 `L3_verdict` ⇒ rc=2）。
- ✅ 返回码与调用点契约不变、`phases_done` 兜底不变 ⇒ 历史 change 的归档路径不受影响。
- ✅ 常设判据 `test/test_review_gate_validity.bats`（双态：无标记 / 6 键有效 / `touch` 空 / 缺键 / 口径相悖）驱动**真实** hook，防回归。
- ⚠️ 门保证的是「审查已发生且凭证自洽」，**不**保证 verdict=pass：`L2_verdict=fail` 且与审查档一致时仍放行（通过与否由主 agent 负责，见 TD-059 处置项 ③）。
- ⚠️ **已知残余（留 v2）**：Tier-1 只验元数据，**不验** `L3_artifact_hash` 是否对应当前工件 ⇒ 陈旧凭证仍可放行。与 TD-042 / TD-045 同源 —— 检测本已存在（`_l3_check_rerun` 比对 IR 档内 `L3_artifact_hash:` ↔ 当前 `sha256`，ADR-010 D4·J），缺的是**门禁不查它**。本变更不扩面。
- ⚠️ Gate3 与 Gate4 现在各跑一次 `fk_validate_done_marker … transition`（同进程两次）；代价是一次 grep/jq 级读取，换来「Gate3 不再持有独立判据」的单一来源。

## 参考

- ADR-004（gate 返回值语义）· ADR-005（gate-active source 依赖）· ADR-010（D4·J 工件哈希）
- `flow-kit-bundle/hooks/stop/lib/done-validation.sh:24-90` · `gate-helpers.sh:174,186` · `independent-review-gate.sh:89-97`
- `test/test_review_gate_validity.bats` · `.specs/health-fix-2026-09b/reproduce-phase-gate.sh`（A/B/B2/B3/B4/C 六态）
