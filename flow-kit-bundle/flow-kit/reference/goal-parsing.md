# Pipeline Goal jq 解析参考（DRY 单一源）

> **DRY 策略**：本文件是 goal 字段结构与 jq 查询的**唯一定义源**。
> 6-review.md / 7-integration.md 中所有 goal 相关 jq 命令（transition、rollback、字段读取）
> 均引用本文件定义的字段名和查询模式，不在各 prompt 中重复描述字段含义。
> 新增 prompt 需要 goal 解析时，通过 `@see flow-kit/reference/goal-parsing.md` 引用此处。
> 此模式与 `pipeline-gates.md`（toll-gate 协议单一源）一致。

## goal 字段结构（`.flow-active.goal`）

```json
{
  "condition": "完成条件文本",
  "status": "active | done | aborted",
  "active_since": "ISO8601",
  "turns": 0,
  "mode": "pending | native | fallback",
  "scope": "phase | pipeline",
  "start_phase": "0-7",
  "current_phase": "0-7",
  "phases_done": ["0", "1", ...],
  "gates": { "0→1": "passed", ... },
  "gate_config": { "1-requirement": "both", ... },
  "auto_advance": false,
  "phase_sub_goals": { "4": "...", "5": "...", "6": "...", "7": "..." }
}
```

## 常用 jq 查询

```bash
# 读取 pipeline scope
jq -r '.goal.scope // "phase"' .flow-active

# 读取当前阶段（pipeline-aware）
jq -r '.goal.current_phase // ""' .flow-active

# 读取起始阶段
jq -r '.goal.start_phase // "4"' .flow-active

# 读取已完成阶段列表
jq -c '.goal.phases_done // []' .flow-active

# 读取 gate 状态
jq -r '.goal.gates["4→5"] // "pending"' .flow-active

# 读取 gate_config
jq -r '.goal.gate_config // {}' .flow-active

# 检查 auto_advance
jq -r '.goal.auto_advance // false' .flow-active
```

## Transition jq 模板

```bash
# 标准 transition（原子更新 4 字段）
jq --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = "<N>" | .phase = "<N>" | .goal.phases_done += ["<N-1>"] | .goal.gates["<N-1>→<N>"] = "passed" | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active

# Pipeline 回退（移除失败阶段及之后的所有 phases_done）
jq --arg target "4" --arg ts "$(date -Iseconds)" \
  '(.goal.phases_done | index($target)) as $idx |
   .goal.current_phase = $target | .phase = $target |
   .goal.phases_done = (if $idx then .goal.phases_done[:$idx] else .goal.phases_done end) |
   .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
