# ADR-012 · L2/L3 模型配置三级优先级链

- **Status**: Accepted
- **Date**: 2026-07-23
- **Change**: l2-l3-model-config
- **Supersedes**: [ADR-006](006-l3-model-env-first.md)（l3-model-env-first）

## Context

ADR-006 确立 L3 模型「完全由 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 定义，未设 `:?` 报错」。L2 用 `${ANTHROPIC_L2_MODEL:-claude-sonnet-5}`（有 fallback）。

问题：
- 非 CC 平台（OpenCode / Codex / Gemini CLI）：L3 `:?` 报错直接终止 session；L2 fallback 值 `claude-sonnet-5` 在非 Anthropic API 不存在 → L2/L3 审查完全不可用
- 无跨平台一致的配置方式（持久化 + 临时覆盖）

## Decision

L2/L3 模型均按**三级优先级链**解析（每级取非空值即停）：

1. `ANTHROPIC_*` env var（CC 原生，优先级 1，CC 用户不变）
2. `FLOW_KIT_*` env var（新增，临时覆盖）
3. `.flow-active.goal.l*_model`（新增，持久化）
4. 空 → **优雅降级**（写 `.flow-active.correction` + stderr 提示，不崩溃、不阻塞 session）

公共函数 `fk_resolve_model <layer>`（`common.sh`）封装解析。L2 **移除** `claude-sonnet-5` fallback（纯跨平台）。

## Consequences

✅ 跨平台：非 CC 平台通过 `FLOW_KIT_*` / `.flow-active` 配置
✅ 降级不阻塞 session（对比 ADR-006 的 `:?` 报错）
✅ CC 用户设了 env var 行为不变（优先级 1 命中）
⚠️ L2 fallback 移除：未设 `ANTHROPIC_L2_MODEL` 的 CC 用户升级后 L2 降级（行为变化，CHANGELOG 标注）
⚠️ ADR-006 被 supersede（L3 不再 `:?` 报错，改降级）
⚠️ ~210 行净增（含 bats 测试）
