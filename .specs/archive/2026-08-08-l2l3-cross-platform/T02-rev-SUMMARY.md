# T02-rev SUMMARY — transcript-parser.sh 工具名双平台兼容（AC-4b · R2 修复）

- **Change**: l2l3-cross-platform
- **Task**: T02-rev（Wave 1 并行 · delta 任务）
- **执行**: 2026-08-08
- **改动文件**: `flow-kit-bundle/hooks/stop/lib/transcript-parser.sh`（write_files 唯一 · git diff: +10 / -3，subagent 检测块 L96-105 区域）

## 背景

第一轮已落地 `transcript-parser.sh` 的 CC-only jq 过滤 `select(.type == "tool_use" and .tool == "Agent")` + `.args.category // .args.subagent_type // "general-purpose"`。opencode 平台实测 part 形状为 `{"type":"tool","tool":"task","state":{"input":{"category":...}}}`（AC-4/AC-4b），单一 CC 过滤下整个统计块 0 匹配。本 delta 任务补齐 opencode `.tool=="task"` 双形状支持。

## 做了什么

**subagent 检测块（原 L96-105）jq 过滤器双形状 + 归类分流**：

1. **过滤条件合并为单条表达式**：
   ```
   select((.type == "tool_use" and .tool == "Agent") or (.type == "tool" and .tool == "task"))
   ```
   - CC 形状（`tool_use` + `Agent`）与 opencode 形状（`tool` + `task`）任中其一即收。

2. **归类按工具名分流**（`if .tool == "task"`）：
   - `.tool == "task"`（opencode 形状）→ `.state.input.category // .args.category // "general-purpose"`
     （归类字段路径定稿 `state.input.category`——与 AC-4 mock + AC-4b + DESIGN D4/§9.3 + TASK.md R-4 一致；`.args.category` 兜底兼容）
   - 否则（CC `Agent` 形状）→ `.args.category // .args.subagent_type // "general-purpose"`
     （`.args.category` 兼容前缀保持第一轮语义，`subagent_type` 主归类不变）

3. **注释更新**：块注释重写为双形状/双平台语义说明（CC 形状归类字段 / opencode 实测形状与归类字段 / 过滤条件 / 分流规则 / general-purpose 兜底），对齐 TASK.md action「注释更新说明双形状语义」。

4. **不动**：函数签名 `parse_transcript()`、输出文件路径 `subagent-usage.txt`、其余所有解析块（tool-calls / bash-commands / written-files 等）零改动。

## verify 真实输出（TASK.md 原样执行）

```
$ cd flow-kit-bundle && bash -c 'echo "{\"type\":\"tool_use\",\"tool\":\"Agent\",\"args\":{\"subagent_type\":\"qa-expert\"}}" | jq "(.type == \"tool_use\" and .tool == \"Agent\") or (.type == \"tool\" and .tool == \"task\")" && echo "{\"type\":\"tool\",\"tool\":\"task\",\"state\":{\"input\":{\"category\":\"unspecified-high\"}}}" | jq "(.type == \"tool_use\" and .tool == \"Agent\") or (.type == \"tool\" and .tool == \"task\")"' && bash -n hooks/stop/lib/transcript-parser.sh
true
true
SYNTAX_OK
```

（jq 1.7：CC 形状与 opencode 形状过滤均返回 `true`；bash -n 无错误。）

## 端到端归类验证（7 输入 mock，覆盖全部分支）

```
$ jq -r 'select((.type == "tool_use" and .tool == "Agent") or (.type == "tool" and .tool == "task")) |
  (if .tool == "task" then (.state.input.category // .args.category // "general-purpose")
   else (.args.category // .args.subagent_type // "general-purpose") end)' /tmp/t02-shapes.jsonl
      | sort | uniq -c | sort -rn
      3 general-purpose
      1 unspecified-high
      1 qa-expert
      1 architect-reviewer
```

| 输入形状 | 归类结果 | 语义 |
|---|---|---|
| `{"type":"tool_use","tool":"Agent","args":{"subagent_type":"qa-expert"}}` | `qa-expert` | CC 主路径 ✓ |
| `{"type":"tool_use","tool":"Agent","args":{"category":"architect-reviewer"}}` | `architect-reviewer` | CC `.args.category` 兼容前缀 ✓ |
| `{"type":"tool","tool":"task","state":{"input":{"category":"unspecified-high"}}}` | `unspecified-high` | opencode 实测形状 ✓（AC-4/AC-4b） |
| `{"type":"tool","tool":"task","state":{"input":{}}}` | `general-purpose` | opencode 兜底 ✓ |
| `{"type":"tool","tool":"task"}` | `general-purpose` | opencode 无 state 兜底 ✓（不崩溃） |
| `{"type":"tool_use","tool":"Bash",...}` | （过滤掉） | 非 agent 工具不收 ✓ |
| `{"type":"tool_use","tool":"Agent"}` | `general-purpose` | CC 双空兜底 ✓ |

## 回归测试（bats，真实执行 · AC-4b 验证方式）

```
$ ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats test/test_l2_dispatch_mode.bats
1..12
ok 1 _test_l2_dispatch_prompt_opencode_mode_category
ok 2 _test_l2_dispatch_prompt_claude_mode_subagent_type
ok 3 _test_l2_dispatch_prompt_dual_mode_box_complete (两分支共存)
ok 4 _test_l2_dispatch_prompt_phase_agent_type_map (1/5→qa-expert 2/3/7→architect-reviewer 6→code-reviewer)
ok 5 _test_l2_dispatch_structure_6_prompts_subagent_type_have_category (AC-4)
ok 6 _test_l2_dispatch_correction_message_no_credential_env (AC-3 边界 · unit)
ok 7 _test_l2_dispatch_model_missing_correction_no_cred_env (AC-3 边界 · l2_dispatch_agent e2e)
ok 8 _test_l2_dispatch_transcript_category_first (R4: .args.category 优先)
ok 9 _test_l2_dispatch_transcript_subagent_fallback (R4: category 缺失→subagent_type)
ok 10 _test_l2_dispatch_transcript_general_fallback (R4: 双空→general-purpose)
ok 11 _test_l2_dispatch_cred_source_flow_kit (R5: Path3→credential source: flow-kit)
ok 12 _test_l2_dispatch_cred_source_env (R5: Path1→credential source: env)
```

**12/12 全绿**。R4 三态用例（ok 8/9/10）mock CC 形状直接 source `transcript-parser.sh` 调 `parse_transcript` → CC 回归不破坏确认。opencode 形状由上方端到端 mock 覆盖（T03-rev 将补正式 bats 用例）。

## 6 维 self-review（内置快查）

| 维度 | 结论 | 证据 |
|---|---|---|
| 正确性 | ✅ | 双形状过滤 + 工具名分流归类 + 双分支兜底，7 输入 mock 全分支验证通过 |
| 回归（CC） | ✅ | test_l2_dispatch_mode.bats 12/12 全绿（R4 三态 CC 用例直接走 parse_transcript） |
| 语法 | ✅ | `bash -n` 通过（SYNTAX_OK） |
| 边界 | ✅ | `git diff` 仅 transcript-parser.sh 1 文件（+10/-3）；未改 REQUIREMENT/DESIGN/TASK；函数签名与 subagent-usage.txt 输出路径不变 |
| 安全 | ✅ | 无凭证/env 名新增；AC-6 红线扫描范围未触碰（transcript-parser 不写 .flow-active* / correction） |
| 契约 | ✅ | 归类路径 `state.input.category` 与 AC-4/AC-4b/D4/§9.3 一致；jq 表达式与 TASK.md action 字面一致 |

## diff 边界 verify

```
$ git status --short（本任务相关）
 M flow-kit-bundle/hooks/stop/lib/transcript-parser.sh   ← 本任务唯一改动
```

其余 modified/untracked 文件为本 change 并行任务（T01-rev/T03-rev/T04-rev 等）的既有工作树改动，本任务未触碰。REQUIREMENT.md / DESIGN.md / TASK.md 零改动（本任务禁止改）。

## 未做 / 交接

- T03-rev（Wave 2）将补 AC-4b 工具名双形状正式 bats 用例（opencode mock `{"type":"tool","tool":"task","state":{"input":{"category":"unspecified-high"}}}` → subagent-usage.txt 含 `unspecified-high`）——本任务已为 T03-rev 的依赖前置（jq 路径定稿 + 实现落地）。
- 不 commit（本轮任务均未 commit）。
