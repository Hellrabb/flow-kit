# T07-SUMMARY · 6 个 prompt 独立 review 调度段平台感知双模式（7 处锚点）

Change：`l2l3-cross-platform`
任务：T07（TASK.md 定义块）

## 变更内容

6 个 prompt 文件的独立 review 调度段改为平台感知双模式：在每个 `subagent_type:` 行后追加统一注释行（DESIGN D4 格式）：

```
      # opencode 平台：改用 category 路由 → task(category="unspecified-high", ...)，subagent_type 在 opencode 下会挂起
```

6-review 的 Cross-Model Spot-Check 文本行（非代码块）追加「（opencode 平台改用 category 路由）」。

agent 名保持既有（qa-expert / architect-reviewer / code-reviewer / oracle），未改动其他任何内容。

## 7 处锚点清单（文件:行号，行号为修改后）

| # | 文件 | 锚点行 | 新增注释/追加行 | agent | 形态 |
|---|------|--------|-----------------|-------|------|
| 1 | flow-kit-bundle/flow-kit/prompts/1-requirement.md | 85 | 86 | qa-expert | L2 调度模板代码块（4 空格缩进块，注释对齐 6 空格） |
| 2 | flow-kit-bundle/flow-kit/prompts/2-design.md | 239 | 240 | architect-reviewer | L2 调度模板代码块 |
| 3 | flow-kit-bundle/flow-kit/prompts/3-task.md | 194 | 195 | architect-reviewer | L2 调度模板代码块 |
| 4 | flow-kit-bundle/flow-kit/prompts/5-test.md | 52 | 53 | qa-expert | L2 调度模板代码块 |
| 5 | flow-kit-bundle/flow-kit/prompts/6-review.md | 105 | 106 | code-reviewer | L2 调度模板代码块 |
| 6 | flow-kit-bundle/flow-kit/prompts/6-review.md | 302 | 302（行尾追加） | oracle | 文本行（非代码块）「派独立 subagent 用不同模型做盲审第 2 轮…」追加「（opencode 平台改用 category 路由）」 |
| 7 | flow-kit-bundle/flow-kit/prompts/7-integration.md | 55 | 56 | architect-reviewer | L2 调度模板代码块 |

## verify 输出（真实执行）

```
---
flow-kit-bundle/flow-kit/prompts/1-requirement.md:1
flow-kit-bundle/flow-kit/prompts/2-design.md:1
flow-kit-bundle/flow-kit/prompts/3-task.md:1
flow-kit-bundle/flow-kit/prompts/5-test.md:1
flow-kit-bundle/flow-kit/prompts/6-review.md:1
flow-kit-bundle/flow-kit/prompts/7-integration.md:1
```

- 第一条 `xargs grep -L "category="` 输出为空 ✅（每个含 `subagent_type` 的 prompt 文件都含 `category=`）
- 第二条各文件 `grep -c "category="` 均 ≥1 ✅

## 结构断言

- **AC-4（结构断言）通过**：每个含 `subagent_type` 的 prompt 文件（6 个）都含 `category=`。
- 7 处锚点全覆盖（6 处代码块 + 1 处文本行）。
- markdown 代码块结构未破坏：注释行与原 `subagent_type` / `description` 行同缩进（6 空格），位于 `Agent tool:` 块内。
- 未改动 .specs/ 下 REQUIREMENT / DESIGN；只改了 6 个 prompt 文件。

## 范围确认

- 修改文件：仅 `flow-kit-bundle/flow-kit/prompts/{1-requirement,2-design,3-task,5-test,6-review,7-integration}.md`
- 未 commit（按要求）。
