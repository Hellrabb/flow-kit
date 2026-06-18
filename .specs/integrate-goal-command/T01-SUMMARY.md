# T01-SUMMARY: .flow-active schema 扩展

- **Task ID**: T01
- **日期**: 2026-06-18

## 做了什么

在 flow SKILL.md 的 `.flow-active` JSON schema 定义中新增 `goal` 可选字段（condition/status/active_since/turns/mode），更新 `/flow start` 初始化 JSON 为含 `goal: null`，更新 `/flow doctor` 诊断 goal 字段结构。

## 改动的文件

- `~/.claude/skills/flow/SKILL.md`（3 处编辑：schema 定义 + /flow start 初始化 + /flow doctor）

## verify 输出

```
$ jq -n '{goal: {condition: "test", status: "active", active_since: "2026-01-01T00:00:00Z", turns: 0, mode: "fallback"}}' | jq '.goal.condition'
"test"
```

## 6 维自查

本任务为纯文档/schema 变更，无生产代码，跳过 TDD 和 6 维自查。

## 越界检查

✅ TASK write_files：1 项（flow SKILL.md），实际 diff：1 项，越界：0
