---
name: flow-kit-l2-reviewer
description: flow-kit L2 独立盲审（gate_config both 各阶段）——按需路由命中专用，对 flow-kit 各阶段产物做独立盲审（L2-blind-review 固化指令）
mode: subagent
---

# flow-kit L2 独立盲审员 · opencode agent 定义

> **锚点声明（AC-4 / DESIGN §9.5 禁动）**：本文件是 AC-4 锚点之一。本文件修改需同步 `flow-kit-bundle/flow-kit/prompts/` 各阶段的 L2 派发映射（opencode → `task(category=...)` / CC → `subagent_type`），详见 `.specs/l2l3-cross-platform/DESIGN.md` §9.5 与 `.specs/CONTEXT.md` 禁动清单「.opencode/agent/flow-kit-l2-reviewer.md」。**禁止**在未同步 prompts 派发映射的情况下单方面修改本文件。
>
> 本文件在 opencode 平台提供 `subagent_type` 路由的可用目标（DESIGN D5）。opencode 下主路径是 category 路由 `task(category="unspecified-high", ...)`；本 agent 定义作为增强，供需要显式子 agent 目标时使用。

---

## 派发名映射说明

Claude Code 下各阶段 prompt 用 `subagent_type` 派发 L2 盲审（六个 CC 派发名）。opencode 下 `subagent_type` 路由会挂起（agent=undefined），需按下列映射改用 category 路由或直接使用本 agent 定义。

| CC 派发名（subagent_type） | opencode 对应路由建议 | 说明 |
|---|---|---|
| `qa-expert` | `task(category="unspecified-high", ...)`（主路径） | 最常用派发名，opencode 下走通用 category 路由；prompt 字段原样注入 L2-blind-review 全文 |
| `architect-reviewer` | `task(category="unspecified-high", ...)` 或 `task(subagent_type="flow-kit-l2-reviewer", ...)` | 阶段 2 设计审查（2-design）默认派发名 |
| `code-reviewer` | `task(category="unspecified-high", ...)` 或 `task(subagent_type="flow-kit-l2-reviewer", ...)` | 阶段 6 代码审查（6-review）默认派发名 |
| `oracle` | `task(category="unspecified-high", ...)` | 跨模型 spot-check / 外部盲审第 2 轮用；opencode 下与其余派发名同路由 |
| `general-purpose` | `task(category="unspecified-high", ...)` 或 `task(subagent_type="flow-kit-l2-reviewer", ...)` | 通用兜底派发名 |

> 约定：**主路径一律 `task(category="unspecified-high", ...)`**（D4：6 prompt 调度段 + l2-detect.sh + transcript-parser.sh 模板已统一此格式）。`subagent_type="flow-kit-l2-reviewer"` 仅在平台支持且用户显式指定时使用（部分 opencode 环境仍可能挂起，属平台行为，out 范围）。

---

## Prompt（L2 盲审固化指令）

> **来源（唯一权威源 · C8-②/D7 引用化，2026-09-30）**：`flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md`
> 本文件**不再复制固化指令正文**（原 :36-198 全文拷贝段已删，正文零复制）。派发装配时由调用方把**源文件全文原样注入** task 的 prompt 字段——禁止凭记忆重写、禁止增删改、禁止附加主 agent 的自评 / 草稿 / 概述 / 辩护。opencode 平台差异（category 路由 / subagent_type 装配参数）仅保留上方「派发名映射说明」段。

> @see `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md` —— L2 盲审固化指令正文本体（独立性硬约束 · 四要素 + severity 输出格式 · Severity Gating · 各阶段 checklist · 与主 agent 关系 · 文件写入约束）。
