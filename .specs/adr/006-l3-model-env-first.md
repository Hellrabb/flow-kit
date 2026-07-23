# ADR-006 · L3 model env-first（ANTHROPIC_DEFAULT_HAIKU_MODEL）

- **Status**: Superseded by [ADR-012](012-l2-l3-model-config-decoupling.md)（2026-07-23 · L3 扩展为三级链 + 降级，不再 `:?` 报错）
- **Date**: 2026-07-17
- **Change**: l2-l3-test-defect（用户要求）

## Context

L3 外部模型审查（`l3_review_run` / `29-independent-review.sh`）model 选择写死 `deepseek-v4-flash`：

```bash
# l3-review.sh:587
local model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}"
[ -n "$model" ] || model="deepseek-v4-flash"

# 29 号:45/48
default_model=$(config_get '.ai.model' "deepseek-v4-flash")
[ -n "$model" ] || model="deepseek-v4-flash"

# stop-hook.json
{ "independent_review": { "model": "deepseek-v4-flash", ... } }
```

问题：
- env-first（`ANTHROPIC_DEFAULT_HAIKU_MODEL`）逻辑正确（主），但 fallback/默认全写死 deepseek
- 用户的 haiku 定义（`ANTHROPIC_DEFAULT_HAIKU_MODEL`，可能是 deepseek-v4-flash[1m] / glm-4.7 / claude-haiku）应是唯一来源
- 固定 deepseek fallback 不适配多环境（不同用户/项目用不同 haiku 映射）

## Decision

L3 model **完全由 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 定义**（用户的 haiku 配置），移除所有固定 fallback，env 未设则 `:?` 报错：

```bash
# l3-review.sh
local model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:?L3 需 ANTHROPIC_DEFAULT_HAIKU_MODEL 定义 haiku 模型}"

# 29 号（移除 default_model/configured_model 间接，直接强制 env）
model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:?L3 需 ANTHROPIC_DEFAULT_HAIKU_MODEL 定义 haiku 模型}"
```

## Consequences

✅ L3 model 跟随用户 haiku 配置（deepseek-v4-flash[1m] / glm-4.7 / claude-haiku-4-5 等）
✅ 无固定 fallback 误导（代码不写死 deepseek/claude-haiku）
⚠️ 部署必须设 `ANTHROPIC_DEFAULT_HAIKU_MODEL`，否则 L3 报错（明确报错，非静默失败）
⚠️ stop-hook.json `independent_review.model` 成死配置（29 号不再读）—— 可后续清理或保留为文档
