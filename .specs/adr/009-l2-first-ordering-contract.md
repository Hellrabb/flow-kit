# ADR-009: L2-first 顺序契约（gate_config=both）

## Context
gate_config=both 时，`29-independent-review.sh` 的 D4 门要求 `## L2 盲审` 段先存在于 `INDEPENDENT-REVIEW-<phase>.md` 才触发 `l3_review_run`（gate.sh:136）。Stop hook 只能用 `l2_dispatch_prompt` 打印派发提示，**自己无法派 L2 子 agent**（框架硬限制——L2 是子 agent 产物）。主 agent 派 L2 + 写 L2 段前，每次 Stop 命中 D4 `exit 0`。phase 1 的 L3 实际是 PreToolUse gate 在 transition 时同步触发的（`.done` written_by=pre-tool-use-gate）。

原 REQUIREMENT/记忆把此现象误判为"BUG-I：Stop hook 触发不可靠"。**Explore agent 诊断（2026-07-18）澄清**：Stop 链没断、29 跑了、CONFIG_FILE 正确注入；L3 不产出是 D4 L2-first 门的**设计内顺序契约**，非触发故障。

## Decision
显式文档化 L2-first 顺序契约：gate_config=both 阶段，**主 agent 必须先派 L2 子 agent + 写 `## L2 盲审` 段**，Stop hook 才能 L3。29 D4 门退出提示从"L3 跳过（L2 not yet complete）"增强为含"主 agent 请派 L2 子 agent 并写入 `## L2 盲审` 段"指引 + 可观测性日志（D4 退出记录"等待 L2"状态）。**不追求** Stop 自动派 L2（框架限制）。
- **段名 regex 放宽**（回应 L3-minor）：`## L2 盲审` 段检测用前缀匹配 `^## L2 盲审`（容忍段名轻微变化如 `## L2 盲审报告`），防门检测失效。同理 `## L3` 段（见 ADR-010 regex `^## L3 (盲审|重审)`，前缀匹配真实 token · 回应 L2 复审 R1'：原 `(盲审|外部模型审查)$` 是 R1 类坏 regex 的第五散落点，已修）

## Consequences
- ✅ 显式化既有契约，消除"BUG-I 触发不可靠"误判
- ✅ 主 agent 调度责任清晰（派 L2 → Stop L3）；29 D4 提示指引 + 可观测性
- ⚠️ L3 仍依赖主 agent 先派 L2（非全自动；框架限制无法绕过）
- 同步：REQUIREMENT AC-I 重定义（"Stop 触发加固 + 兜底" → "L2-first 契约 + 提示 + 可观测性"）
- 同步：记忆 [[l3-model-unreliable]] BUG-I 描述修正
