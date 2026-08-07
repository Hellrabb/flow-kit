# T05-SUMMARY — transcript-parser.sh subagent 统计双模式

- **change-id**: `l2l3-cross-platform`
- **task**: T05 — transcript-parser.sh subagent 统计双模式
- **date**: 2026-08-07
- **状态**: done

## 改动概览

**唯一改动文件**: `flow-kit-bundle/hooks/stop/lib/transcript-parser.sh`

subagent-usage 检测的 jq 表达式（原 L99，现位于 "Detect subagent usage" 块）：

```
.args.subagent_type // "general-purpose"
```
→
```
.args.category // .args.subagent_type // "general-purpose"
```

- **双模式语义**：
  - opencode 下主 agent 用 `task(category=...)` 派发的 agent（含 L2 审查 agent）只记录 `.args.category`，无 `subagent_type` → 新增 category 优先归类，使其进入 `subagent-usage.txt` 统计。
  - Claude Code 的 Agent tool 记录 `.args.subagent_type`（原行为不变）。
- **纯增量回退链**：`category` 缺失 → `subagent_type` → `"general-purpose"`。
- 附注释说明双模式统计语义（task 明确要求）。

## verify 输出（真实执行）

```
$ bash -n flow-kit-bundle/hooks/stop/lib/transcript-parser.sh; echo '{"args":{"category":"unspecified-high"}}' | jq -r '.args.category // .args.subagent_type // "general-purpose"'
unspecified-high
```

- `bash -n` 无输出 → 语法检查通过。
- jq 表达式含 category 时输出 `unspecified-high` → 期望达成。

**向后兼容验证**（回退链）：

```
$ echo '{"args":{"subagent_type":"explore"}}' | jq -r '.args.category // .args.subagent_type // "general-purpose"'
explore
$ echo '{"args":{}}' | jq -r '.args.category // .args.subagent_type // "general-purpose"'
general-purpose
$ echo '{"args":{"category":"librarian","subagent_type":"explore"}}' | jq -r '.args.category // .args.subagent_type // "general-purpose"'
librarian
```

- category 缺失、subagent_type 存在 → 回退到 `explore` ✓
- 两者都缺失 → `general-purpose` ✓
- 两者都存在 → category 优先（`librarian`）✓

## 边界说明

- 未改 `.specs/` 下 REQUIREMENT / DESIGN / TASK。
- 未 commit。
- 无 unit 测试依赖旧表达式（改动为纯增量，旧语义完全保留）。
