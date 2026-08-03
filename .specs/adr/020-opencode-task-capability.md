# ADR-020: OpenCode Task Tool Capability Snapshot

**Status**: Accepted
**Date**: 2026-08-03
**Supersedes**: 无
**Superseded by**: 无

## Context

ADR-016 (Model-Tier Dispatch 双轨生效路径) 的 Path A/B 分叉依赖一个未验证的前提条件：OpenCode 的 task 调度工具是否支持 task-level model switching（即 `<task model-tier="cheap">` 能否实际切换到便宜模型）。

L-061（来自已归档 `superpowers-v6-absorb`）要求验证此能力。

### 验证过程

2026-08-03 在 OpenCode session 中进行了 live test：

1. 检查 `task()` tool 的完整签名——参数仅含 `subagent_type` 和 `category` 两个路由维度。
2. 无 `model-tier`、`model`、`model_name` 等任何 model 相关参数。
3. OpenCode 的模型选择发生在三层：
   - **Harness 配置层**：oh-my-openagent.json 为每个 agent type（explore/oracle/librarian/…）绑定了 model
   - **Category 路由层**：category（quick/unspecified-low/…/ultrabrain）映射到模型 tier（如本环境 `quick` → deepseek/deepseek-v4-pro）
   - **子 agent 覆盖层**：`subagent_type` 参数的显式覆盖

结论：OpenCode **不支持**通过 task 参数做 task-level model switching。

### 对 ADR-016 的影响

ADR-016 的双轨设计中，Path A（native model switching）在当前 OpenCode 版本不可用。实际生效路径为 Path B（hint）——4-dev.md 在 dispatch prompt 顶部加 `[MODEL-TIER hint]:` 文本，由子 agent 自行降级。

## Decision

### 1. model-tier 字段的定位

flow-kit TASK.md XML 的 `<task model-tier="...">` 属性是**文档/提示字段**（dispatch prompt hint），不是硬性运行时开关。

```xml
<task id="T03" model-tier="cheap" parallel="true" status="pending">
  <description>机械性 1-2 文件变更（命名重构）</description>
</task>
```

### 2. 4-dev.md 派发逻辑

4-dev.md 的 task 派发逻辑应：

- 将 `model-tier` 解释为对**主 agent 的调度指导**（"此 task 优先用便宜模型"），不调用不存在的 API 参数
- 实际路由回退到 OpenCode 的 category-based routing：`category="quick"` 映射到便宜 tier
- 不尝试传递 `model` 参数给 task()——该参数不存在，传递会导致工具调用失败

### 3. ADR-016 的修正

ADR-016 § 2 Path A（native model switching via `task({model: ...})`）在当前 OpenCode 版本**不可用**。ADR-016 的双轨设计仍然有效——Path B（hint）是当前生效路径。若未来 OpenCode 新增 task-level model 参数：

- 更新本 ADR（状态改为 Superseded）
- 启用 ADR-016 Path A
- 4-dev.md 从 hint 升级到 native dispatch

## Consequences

**正面**：
- L-061 关闭——已验证 OpenCode 无 task-level model switching
- 派发逻辑不会因调用不存在的 API 参数而崩溃
- ADR-016 双轨设计兼容当前限制（Path B 即 gating）

**负面**：
- 无法在 harness 层强制 per-task model budget cap——子 agent 实际 model 仍取决于 OpenCode 的 category→model 绑定，hint 仅作建议
- 成本控制依赖 OpenCode 的 category 配置，非 flow-kit 可强制执行

**Mitigation**：
- 通过 category 选择间接控制成本（`category="quick"` → 便宜 tier；`category="ultrabrain"` → 顶配 tier）
- 本环境实测：`category="quick"` → deepseek/deepseek-v4-pro（quick 级别已绑定）
- 更细粒度的 cost control 需 OpenCode 升级支持

**Neutral**：
- TASK.md XML schema 不变（`model-tier` 属性语义不变，仅生效路径从 native → hint）
- 4-dev.md 的 model-tier 解析逻辑不变（仍读 `model-tier` 属性，仍做 tier→hint 转换）
- `.specs/<id>/.opencode-capability.json` 调研结果固定为 `{"tier_dispatch_mode": "hint"}`（无需重复调研）

**未来升级路径**：
- OpenCode 新增 task model 参数时：ADR-016 Path A 激活，4-dev.md hint → native 升级
- 升级不破坏已有 TASK.md XML（`model-tier` 属性语义向上兼容）

**禁动约束**：
- `model-tier` hint 文本格式 `[MODEL-TIER hint]:` 锁定（与 ADR-016 § 禁动约束一致）
- task() 调用不得添加 `model` 参数（该参数不存在，会导致工具调用失败）

## Verification

Live test in this session confirmed:

- `task()` tool has no `model` or `model_tier` parameter
- Routing dimensions: `subagent_type` + `category` only
- Model selection at harness config level (oh-my-openagent.json agent→model binding)

## 触发条件

- 本 change 实施时（phase 4）：4-dev.md 确保 task 派发不传 `model` 参数，仅用 `category` + hint
- OpenCode 升级支持 task-level model switching 时：更新本 ADR + 启用 ADR-016 Path A
