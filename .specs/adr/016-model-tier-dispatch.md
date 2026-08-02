# ADR-016: Model-Tier Dispatch 双轨生效路径

**Status**: Proposed (superpowers-v6-absorb Phase 2)
**Date**: 2026-08-02
**Supersedes**: 无
**Superseded by**: 无

## Context

superpowers v6.0 SKILL.md L159-188 Model Selection：v5 时代 controllers 不再命名模型 → silent inheritance of session's most expensive tier。一次实战 26 个 reviewer 全部跑在 top-tier model。v6 强制 `[MODEL — REQUIRED]` 在每个 dispatch prompt。

flow-kit TASK.md 当前 XML 格式：
```xml
<task id="T03" parallel="true" status="pending">
  <description>...</description>
</task>
```

无 model-tier 概念，4-dev 派 task 时继承 session 默认（可能是 top-tier）。

OpenCode 的 task tool 是否支持 task-level model switching 未确认：
- oh-my-openagent.json 显示 agent type 各自有 `model` 字段（如 explore → deepseek-v4-pro）
- 但 task() 调用是否支持 `model` 参数 per-call 未在文档明确

L2 盲审（INDEPENDENT-REVIEW-1.md R1）要求：AC-E3 必须在 REQUIREMENT 阶段就完整可验证，不能延后到 DESIGN。本 ADR 给出双轨设计，兼容两种 OpenCode 能力。

## Decision

**TASK.md XML 加 model-tier 属性 + 双轨生效路径**：

### 1. TASK.md schema 扩展（向后兼容）

```xml
<task id="T03" model-tier="cheap" parallel="true" status="pending">
  <description>...</description>
</task>
```

- `model-tier`：可选属性，值为 `cheap` / `standard` / `top` 三档
- 缺省时 fallback `standard`（AC-E2 向后兼容）
- tier 定义：
  - `cheap`：1-2 文件机械变更（typo / format / 命名重构）
  - `standard`：3-5 文件业务变更（新功能 / bug fix）
  - `top`：架构决策 / review / 跨模块重构

### 2. 4-dev.md 派 task 时的双轨生效

```bash
# 4-dev 入场时一次性调研（结果缓存到 .specs/<id>/.opencode-capability.json）
TIER_DISPATCH_MODE=$(detect_opencode_tier_support)
# detect_opencode_tier_support 逻辑：
#   if task() 调用支持 model 参数 → "native"
#   else → "hint"
```

#### Path A: OpenCode 支持 task-level model switching（native）

4-dev.md 派 task 时显式声明 model 字段：

```typescript
// 伪代码
const modelMap = {
  cheap: "deepseek/deepseek-v4-flash",  // 或 OpenCode 配置的最便宜 model
  standard: "deepseek/deepseek-v4-pro",
  top: "bailian/glm-5.2"
};

task({
  subagent_type: "build",
  model: modelMap[task.modelTier || "standard"],  // 显式 model
  prompt: "...",
  ...
});
```

AC-E3a 验证：mock dispatcher 断言派发参数含 cheap-tier 模型 ID。

#### Path B: OpenCode 不支持 task-level model switching（hint）

4-dev.md 派 task 时在 dispatch prompt 顶部加 hint 文本：

```
[MODEL-TIER hint]: 建议本 task 使用 cheap-tier 模型（机械性 1-2 文件变更）
─────────────────────────────────────────────────────────────
<原 dispatch prompt 内容>
```

AC-E3b 验证：`grep -E "^\[MODEL-TIER hint\]:" <dispatch-prompt-text>` 命中。

### 3. detect_opencode_tier_support 实现

4-dev.md 入场时跑一次调研脚本（伪代码）：

```bash
# 调研：4-dev 入场一次性探测，结果写入 .specs/<id>/.opencode-capability.json
detect_tier_support() {
  # 简单探测：检查 oh-my-openagent.json 是否有 task tool 的 model 参数定义
  # 或检查 OpenCode 文档（hard-coded URL）
  # 默认 fallback: hint（保守）
  if jq -e '.task_tool_supports_model // false' ~/.config/opencode/oh-my-openagent.json 2>/dev/null; then
    echo "native"
  else
    echo "hint"
  fi
}
```

调研结果写入 `.specs/<id>/.opencode-capability.json`：
```json
{"tier_dispatch_mode": "hint", "detected_at": "2026-08-02T22:18:20+08:00"}
```

后续 task 派发都读这个缓存，不重复调研。

### 4. tier → 实际 model 映射表（Path A 用）

`.specs/<id>/.opencode-capability.json` 同时存映射表：

```json
{
  "tier_dispatch_mode": "native",
  "tier_model_map": {
    "cheap": "deepseek/deepseek-v4-flash",
    "standard": "deepseek/deepseek-v4-pro",
    "top": "bailian/glm-5.2"
  }
}
```

映射表的 default 来自 OpenCode 环境（探测 oh-my-openagent.json），用户可手动覆盖。

## Consequences

**正面**：
- TASK.md 显式声明 model-tier，避免 silent 继承最贵 tier
- 双轨设计兼容 OpenCode 能力不确定性
- hint 格式 grep 可校验（AC-E3b 机械验证）
- 调研一次缓存，无每次 dispatch 开销

**负面**：
- Path B hint 是建议非强制，dispatch 实际可能仍跑 session 默认 model
- tier_model_map 依赖 OpenCode 配置，不同环境映射不同
- detect_opencode_tier_support 探测逻辑可能误判（保守 fallback 到 hint）

**Neutral**：
- TASK.md schema 向后兼容（model-tier 可选）
- 既有 TASK.md（无 model-tier）fallback standard tier
- 不影响 4-dev 主流程，仅是 dispatch 层增强

**OpenCode 能力变化时的迁移**：
- 若未来 OpenCode 确认支持 task-level model switching：删除 Path B hint 逻辑，仅保留 Path A
- 若未来 OpenCode 引入新 model：更新 tier_model_map，无需改 prompt

**禁动约束**：
- model-tier 三档命名（cheap / standard / top）锁定，禁止扩展（如 ultra-cheap / premium）
- hint 文本格式 `[MODEL-TIER hint]:` 锁定，禁止改格式（破坏 grep）
- detect_opencode_tier_support 必须缓存结果，禁止每次派 task 都调研

## 触发条件

- 本 change 实施时（phase 4）：4-dev.md 加 model-tier 解析 + 双轨派发逻辑
- 本 change 测试时（phase 5）：bats 测试 hint 格式 grep + mock dispatcher
- 后续 change 改 4-dev 时：必须保留 model-tier 解析
