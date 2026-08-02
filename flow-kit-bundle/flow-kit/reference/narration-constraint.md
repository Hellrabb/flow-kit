# Narration Constraint — 工具调用间的 narration 约束

> between tool calls, narrate at most one short line — the ledger and the tool results carry the record

## 适用范围

- 所有 phase prompts 顶部加载本约束（通过 `@see` 引用）
- 工具调用之间最多 1 行 narration（解释刚刚发生了什么 / 接下来要做什么）
- 长 narration 段（>1 段）= 违规

## 反例

- ❌ "Let me now read the file to understand the structure. After reading, I'll analyze the dependencies and then propose a change. The change will involve..."（45 字 plan-style narration）
- ❌ "I just called the Read tool and got the file content. The file has 250 lines. It contains several functions. The first function is..."（重复 tool 输出）

## 正例

- ✅ `Read src/foo.ts → 250 lines, 8 functions identified`（1 行 narration）

<!-- 引用方式：本段为单一源。phase prompts 在顶部加 "@see flow-kit/reference/narration-constraint.md"。
      借自 superpowers v6.0 B5 (narration constraint, -54% controller output) · ADR-014 -->
