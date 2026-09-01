# ADR-024 · correction violations 分层作用域

- **状态**：提议（2026-09-01 · correction-hygiene-state-guard）
- **决策者**：2-design（本 change）

## Context

`.flow-active.correction` 的 `violations[]` 数组由两个模块混写：

- `33-flow-active-integrity.sh`（state-integrity 类 · 9 种 check 名）
- `28-weak-model-compliance.sh`（compliance 类 · write_compliance_correction）

ADR-013（correction-overwrite-strategy）只定义了**文件级** type 覆盖优先级（compliance > model-missing——model-missing 写入不覆盖在场 compliance），**没有数组级条目保留条款**（L2 盲审 R5 全文核实）。

本 change（correction-hygiene-state-guard）引入三类数组级操作：去重（同 check+field 保最新）、容量（FIFO 上限）、清空（健康清零/外来接管清空）。这些操作若不界定作用域，会跨类型误删 compliance 条目——弱模型合规矫正信息（保护安全的数据）是 ADR-013 刻意保护的。

## Decision

**数组级操作（去重 / FIFO 容量 / 健康清零 / 外来清空）以 33 号写入的 9 种 check 名白名单为作用域边界**：

```
corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing /
pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch /
stale_updated_at / token_spent_unmaintained
```

- compliance 类条目（28 号写入，type 含 `compliance`）**不参与任何数组级操作**——原样保留
- 沿 ADR-013 的 compliance 优先精神，从「文件级 type 覆盖」升格为「数组级条目保留」显式契约
- 类型合并标签（如 `l2-missing+state-integrity`）的剥离操作只作用于 state-integrity 段，compliance 段永不剥离

## Consequences

- **正面**：compliance 安全数据永不被 correction 卫生逻辑误删；28 号写入路径零改动；AC-10 有明确设计依据
- **负面**：白名单需随 33 号新增 check 名维护（常量数组 + L-031 注释提示「新增 check 名需同步白名单」）；数组级操作与文件级 type 的交互需配套剥离语义（D4/D5）
- **替代方案被否决**：按 type 分段存储（v2 候选，需改 correction 文件 schema，破坏既有读取方）；全局去重（会跨类型误删，直接违反 ADR-013 精神）

## 关联

- 延续：ADR-013（文件级 type 覆盖优先级）
- 触发：correction-hygiene-state-guard 的 AC-10（compliance 条目不受本 change 影响）
