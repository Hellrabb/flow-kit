# ADR-007: PHASE_GATE_KEY_MAP 单一来源 pure fn

## Context
`PHASE_GATE_KEY_MAP`（phase→gate_config key 映射）当前在 `common.sh:255` 与 `independent-review-gate.sh:25` **两处独立 `declare -A`**（v1 为隔离 source common.sh 的全局副作用而复制；gate.sh:21-24 注释自承"若 common.sh 增删 phase 此处须同步"）。6 消费者（29:77/117/155 + gate.sh:395/413 + common 注释）。重复定义违反 DRY，易失同步——正是 l2-l3-test-defect BUG-F 的温床。

## Decision
抽成 pure fn `fk_phase_gate_key <phase>`，定义在 common.sh（单一来源），**内部用 `case "$phase" in 1) echo "1-requirement";; 2)... esac`（非 `declare -A`）**，返回 gate_config key。5 执行消费者改 `"${PHASE_GATE_KEY_MAP[$phase]:-}"` → `"$(fk_phase_gate_key "$phase")"` + 1 处文档注释更新。删除两处 `declare -A`。

## Consequences
- ✅ 消除重复 declare（NFR-4 grep 守护：`declare -A PHASE_GATE_KEY_MAP` 从 2 处 → 0 处）
- ✅ 单一来源，新增 phase 只改一处；无 source 副作用
- ⚠️ 5 执行消费者机械改调用 + 1 注释更新；函数调用开销（NFR-1 守护 <30% wall time）
- **边界**（AC-F）：仅数据结构单一来源化，禁改 7 Gate 控制流；INT-7 回归守护 forward transition deny
