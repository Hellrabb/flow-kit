# ADR-013 · model-missing correction 覆盖写策略

- **Status**: Accepted
- **Date**: 2026-07-23
- **Change**: l2-l3-model-config

## Context

ADR-012 的降级路径中，caller（l3-review / l2-detect / 29-independent-review）需写 `.flow-active.correction` 提示模型缺失。但 `.flow-active.correction` 是**单文件**，既有两类写入：

- `compliance`（`write_compliance_correction`，merge-write `.violations[]`，每轮 Stop 由 weak-model-compliance 写）
- `l2-missing`（`_write_l2_missing_correction`，`jq -n >` **覆盖写**，简单 schema）

新增 `l3-model-missing` / `l2-model-missing` 需选写入策略。两者可能并发（compliance 每轮写 + model-missing 降级时写）。

## Decision

model-missing **沿用** `_write_l2_missing_correction` 覆盖写模式（`jq -n '{type, layer, message}' > .flow-active.correction`）。

- 语义：单文件单 type，**最后写入者胜**（基础规则）
- **写入优先级（compliance > model-missing · L2 R2 缓解）**：model-missing 写入前检查当前 correction——若为 `compliance` 且 `violations[]` 非空，**不覆盖**（保留安全信息）；compliance 写入**总是覆盖**。避免非 CC 用户（目标受众）首启降级时 model-missing 持续压住 compliance 安全 banner。
- schema：`{type:"l3-model-missing"|"l2-model-missing", layer:"L3"|"L2", message:<配置提示>}`（与既有 `l2-missing` 精确等值区分，后者语义=L2 盲审段缺失）
- `flow-kit-resume.sh` 收割扩展：新增 model-missing 分支（当前 `:92-95` 仅认 `compliance`）+ `:127` `rm -f` 条件化（model-missing/l2-missing 不删，持续提示；compliance/unknown 删）

## Consequences

✅ 与既有 `l2-missing` 模式一致，改动最小
✅ resume.sh 扩展后能收割 model-missing（AC-6）
⚠️ compliance 与 model-missing 并发：已由 **compliance > model-missing 优先规则**缓解（model-missing 不覆盖在场 compliance）；优先规则靠 `write_model_missing_correction` lib 函数强制（DESIGN §4.2）
⚠️ 未来若冲突频繁，可迁移到多 type 容器 merge（列入 v2，ADR-013 可再 supersede）
