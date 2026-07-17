# ADR-003: L2 PreToolUse Agent 自动派发机制

- **日期**: 2026-07-15
- **Change**: `l2-pretooluse-dispatch`
- **状态**: proposed

---

## Context

L2 独立审查当前仅在 Stop hook（`29-independent-review.sh`）中触发，即在对话结束后检测 L2 缺失并提醒用户手动派发子 Agent。L3 审查已有 PreToolUse dispatch（`independent-review-gate.sh::_gate_check_l3` + `_gate_do_transition`），在阶段切换时前置拦截。L2 缺失同样的前置拦截能力。

本次 change 需要在 PreToolUse hook 中为 L2 增加自动派发能力。核心设计问题：
1. Agent 派发用什么机制？（curl API vs Claude CLI）
2. 派发是同步还是异步？
3. 派发失败时如何降级？

---

## Decision

### D1: 使用 curl + Anthropic Messages API 派发

在 `l2-detect.sh` 中新增 `l2_dispatch_agent()` 函数，通过 curl 调用 Anthropic Messages API，构造与 `L2-blind-review.md` 一致的固化 prompt。

**理由**：
- 与 L3 审查（`l3-review.sh::_l3_call_api()`）使用相同的 API 调用范式——curl + JSON payload + `--max-time 90`
- curl 在 hook shell 环境中保证可用（`set -euo pipefail` 兼容），不依赖 `claude` CLI 或 Node.js
- 超时可控（`--max-time`），不阻塞 hook 主流程

### D2: 异步 fire-and-forget

Agent 派发通过后台进程执行（`curl ... &>/dev/null & disown`），hook 主流程在触发 dispatch 后立即 exit 2（拦截阶段切换）。Agent 执行结果异步写入 `INDEPENDENT-REVIEW-<phase>.md`。

**理由**：
- PreToolUse hook 有约 5 秒执行窗口（Claude Code hook 超时限制），Agent API 调用需 15-60 秒
- 同步等待 → hook 超时被 kill → dispatch 丢失 + 工具流卡死
- 后台进程 + `disown` 脱离 hook 进程组，即使 hook 被 kill Agent 也不受影响

**代价**：
- Agent 执行结果不能在同一轮对话返回给用户——依赖 Stop hook 29 号兜底提醒 + 下一轮 SessionStart 注入报告摘要
- 若 Agent 静默失败（进程被 OOM kill、API 返回非 200 但 stderr 丢失），用户需等到 Stop hook 才知道

### D3: 派发失败降级为手动命令

`l2_dispatch_agent()` 返回 0（成功触发后台进程）或 1（curl 不可用 / API endpoint 不可达 / 凭证缺失 / JSON 构造失败）。返回 1 时，`_gate_check_l2` 回退到既有行为——调用 `l2_dispatch_prompt` 生成手动 Agent 命令文本，输出到 stderr 附带 `FLOW_KIT_SKIP_L2=1` 跳过指引。

**理由**：
- 不能因为自动派发失败就让用户无路可走（R1 风险）
- `l2_dispatch_prompt` 已实现且稳定——回退到此路径零额外开发成本
- 手动命令给用户最大控制权（可复制执行、可修改参数、可选择跳过）

### D4: auto_advance 模式下非阻塞

当 `.flow-active.goal.auto_advance = true` 时，`_gate_check_l2` 检测到 L2 缺失后不执行 exit 2（不阻断自动推进），仅输出警告 + 异步派发 Agent（fire-and-forget）。

**理由**：
- auto_advance 设计为无人值守——硬拦截会打断全部后续阶段的自动推进（R2 风险）
- 非阻塞 + 异步派发 = 自动推进不受影响 + L2 审查仍在后台进行
- Stop hook L2 检测（29 号）在后续轮次兜底提醒

---

## Consequences

### 正面

- L2/L3 在 PreToolUse 层有对称的分发模型（都支持前置拦截 + 自动派发）
- 用户不再需要手动记住触发 L2 审查——阶段切换时自动处理
- 派发失败有明确的降级路径，不会死锁

### 负面

- `_gate_check_l2` 复杂度增加（从 ~50 行到 ~80 行）——通过清晰的代码分段（检测→auto_advance→派发→降级→拦截）控制认知负荷
- 异步 Agent 的结果反馈延迟（需等到 Stop hook 或下一轮 SessionStart）——对于实时性要求不高的审查场景可接受
- 新增对 curl 的隐式依赖（此前 PreToolUse hook 不直接调 HTTP）——但 curl 已是 L3 审查的依赖，运行环境必须可用

### 未来可能推翻的场景

- 如果 Anthropic 提供官方 hook 内 Agent dispatch API（如 Claude Code plugin SDK），可以替换 curl 方案为官方 SDK 调用
- 如果 PreToolUse hook 超时限制放宽至 30s+，可考虑同步 dispatch + 结果即时返回
- 如果 auto_advance 改为全自动无 toll-gate 模式，需重新评估非阻塞策略（当前 toll-gate 暂停模型下 Agent 堆积风险可控）
