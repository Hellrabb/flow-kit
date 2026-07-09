# DEV-SUMMARY: fix-gate-phase-detection · 实施记录

> TD-014 修复完成。systematic-debugging 四阶段全程亲自验证。无回归。

## 根因（Phase 1-2 · 亲自复现）

`is_phase_write`（`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:65-77`）：

| 行 | 作用 | 状态 |
|---|---|---|
| L67 | 保证 `$c` 含 `.flow-active` | OK |
| L69-71 | 写动作检测（`.tmp&&mv` / `tee` / `>`） | L69 TD-011 lint bug（fallback 掩盖）· L70/71 OK |
| **L73-75** | phase 字段检测 | **🔴 bug** |

L73-75 旧 regex `\.flow-active.*\.phase=` 顺序反 → 真实 jq 命令（字段在前）永不匹配。

**复现实测**（source gate 文件 + 对真实命令调 `is_phase_write`）：

| case | 命令 | 实测 rc | 期望 | 结果 |
|---|---|---|---|---|
| A | `jq '.phase = 5' .flow-active > .tmp && mv .tmp .flow-active` | 1 | 0 | ❌漏检 |
| B | `jq '.goal.phases_done += ["3"]' .flow-active > .tmp && mv ...` | 1 | 0 | ❌漏检 |
| C | `jq '.goal.current_phase = 5' .flow-active > .tmp && mv ...` | 1 | 0 | ❌漏检 |
| D | `jq '.goal.phases_done' .flow-active`（纯读） | 1 | 1 | ✅ |
| E | 写 `.interrupt`（非 phase 字段） | 1 | 1 | ✅ |
| F | 不涉 `.flow-active` | 1 | 1 | ✅ |

## 修复（Phase 3-4）

L73-75 去 `.flow-active.*` 前缀（L67 已保证涉及 .flow-active）：

```bash
# 旧（顺序反 · 永不匹配真实 jq）
[[ "$c" =~ \.flow-active.*\.phase[[:space:]]*= ]] && return 0
[[ "$c" =~ \.flow-active.*\.goal\.current_phase[[:space:]]*= ]] && return 0
[[ "$c" =~ \.flow-active.*\.goal\.phases_done ]] && return 0

# 新（只测字段名）
[[ "$c" =~ \.phase[[:space:]]*= ]] && return 0
[[ "$c" =~ \.goal\.current_phase[[:space:]]*= ]] && return 0
[[ "$c" =~ \.goal\.phases_done ]] && return 0
```

## 最终验证

| 验证 | 结果 |
|---|---|
| 修复后正向 [A/B/C] | 全 `rc=0` ✅ |
| 负向 [D/E/F] + 边界 [G/H 写 `.change_id`/`.goal.status` 等非 phase 字段] | 仍 `rc=1`（无误拦）✅ |
| `test/test_gate_integrity.bats` 单文件 | 23 全绿（D10 #19/#20 skip→真跑）|
| `bats test/` 全量 | **exit 0 · 407 全绿 · 0 fail** ✅ |
| AC-7 双源一致 | ✅（`test/` + `flow-kit-bundle/test/` 同步）|

## 偏差

1. **未走 flow-kit 完整闭环**：discovery 阶段已完成 DESIGN v4 + sandbox 验证（归档 `2026-07-09-refactor-independent-review-gate-discovery`），本次直接 TDD 实施 + 全量回归，未重走 0-change/1-requirement/2-design
2. **AC-7 首跑红**：改 `test/` 漏改 `flow-kit-bundle/test/`（双源约定），同步后转绿
3. **TD-011/TD-015 未顺手做**（见 CHANGE 范围排除）

## 改动文件

- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` L73-75（去前缀 + 注释）
- `test/test_gate_integrity.bats` D10 两处去 `skip`
- `flow-kit-bundle/test/test_gate_integrity.bats` 同步
- `.specs/CONTEXT.md` TD-014 🔴🔴 → ✅ + 证据

## 设计依据

- `.specs/archive/2026-07-09-refactor-independent-review-gate-discovery/DESIGN.md` v4 D6 + sandbox 验证（修复版端到端全 ✓ · 真 phase-write return 0 / 非 phase-write return 1）
