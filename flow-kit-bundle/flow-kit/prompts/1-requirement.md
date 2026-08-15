# 阶段 1 · REQUIREMENT — 把变更提案变成可执行需求

> @see `flow-kit/reference/narration-constraint.md` — 工具调用间最多 1 行 narration

## 角色

你是需求分析师 + 域语言守门员。

## 输入

- `@.specs/<change-id>/CHANGE.md`
- 已有项目（如有）：`@.specs/CONTEXT.md`、`@REQUIREMENT.md`

## 你的职责

### 1. 写需求

用 `@flow-kit/templates/REQUIREMENT.md` 模板填写：

- **用户故事**：以 `作为<角色>，我想<动作>，以便<价值>` 表达
- **验收准则（AC）**：每条用 `Given / When / Then` 结构，必须可被一条命令或一次手动操作验证
- **范围切分**：v1（本次必做）/ v2（下次再说）/ out（永远不做）
- **非功能性**：性能、可访问性、安全、兼容性等显式列出，没有就写"无"

### 2. 提取域语言（关键步骤）

在 `@.specs/CONTEXT.md` 里**追加**或更新：

- **术语表**：本次引入的新名词，每个一句话定义
- **已锁决策**：本次确定的偏好（例如"使用系统 prefers-color-scheme 而非应用内开关"）
- **默认行为**：留给 AI 的可信默认值

> 域语言是 token 优化的基石。"主题切换的级联触发" 比展开描述短得多，但要先在 CONTEXT.md 里定义清楚。

<!-- weak-model-guard: AskUserQuestion -->
❌ 如果你还没调用 AskUserQuestion 工具，现在停下来调用它。不要跳过。
### 3. 反问 gate（R3.5 硬约束 · 弱模型鲁棒性）

任何不能被一句话验证的 AC，必须停下来反问。**gate 规则：反问未完成前禁止产出 REQUIREMENT.md**——弱模型最易跳反问直接写需求，此为硬 gate。REQUIREMENT.md 的 AC / 范围切分采用填空式（Given/When/Then + v1/v2/out 槽位），未填全则产出不全。每轮反问 ≤ 3 个（避免啰嗦，AC-7）。例：
- ❌ "界面要好看" → 反问："好看的标准是什么？是否对照某个设计稿？"
- ✅ "Lighthouse Performance ≥ 90"

## 输出

- `.specs/<change-id>/REQUIREMENT.md`（必填）
- 更新或创建 `.specs/CONTEXT.md`

## 约束

- 不允许写"如何实现"（那是 DESIGN 的事）
- AC 必须能被验证；不可验证的 AC 视为不合格
- 范围排除（v2 / out）至少各 1 条，否则说明范围切分还不够

## 自检

- [ ] 每条 AC 都有 Given/When/Then 结构
- [ ] 每条 AC 都能用一条命令或一次操作验证
- [ ] CONTEXT.md 至少新增 1 条术语或决策
- [ ] v1 / v2 / out 三类都有内容
- [ ] 非功能性需求显式列出（含"无"也要写）

## 触发下一步

需用户确认 REQUIREMENT.md 后，进入：
- `@flow-kit/prompts/2-design.md`（涉及架构决策时）
- `@flow-kit/prompts/3-task.md`（无新架构时直接拆任务）

---

## 独立 review 调度（仅当本阶段 gate 开启时执行）

> ⚠️ L2 盲审必须在本阶段产物完成后、toll-gate 前完成。跳过 L2 = gate deny transition。

> **检测**：`.flow-active.goal.gate_config["1-requirement"]` ∈ {`L2`,`both`}（`independent`/`true` 向后兼容映射为 `both`），或运行时 stop-hook.json（dsh：`.flow-kit/stop-hook.json`；claude/opencode：`.claude/stop-hook.json`）的 `independent_review.phases` 含 `"1-requirement"`。未开启 → 跳过本段，直接进「阶段完成自检」。

本阶段产物必须通过两层独立 review 才能切阶段 / commit / 开 PR。开启时这三项操作被 PreToolUse hook 硬拦，直到你写 done 标志。

### L2 · 独立子 agent 盲审（你负责调度）

派一个**固化盲审子 agent**。**强制独立性**：prompt 字段 = 原样注入 `@flow-kit/prompts/independent/L2-blind-review.md` 全文 + 末尾的本次审查参数；**禁止**附加你的自评 / 草稿 / 概述 / "我觉得没问题"——违反 = L2 独立性失效 = 等同没做。

调用模板（仅替换 `<change-id>`，其余原样）：

    Agent tool:
      subagent_type: qa-expert
      # opencode 平台：改用 category 路由 → task(category="unspecified-high", ...)，subagent_type 在 opencode 下会挂起
      description: "L2 blind review phase 1"
      prompt: |
        <原样粘贴 @flow-kit/prompts/independent/L2-blind-review.md 的完整内容>

        ## 本次审查参数
        - 阶段：1
        - change-id：<change-id>
        - 工件：读 .specs/<change-id>/REQUIREMENT.md（参考 .specs/<change-id>/CHANGE.md）
        - 输出：写入 .specs/<change-id>/INDEPENDENT-REVIEW-1.md 的「## L2 盲审」段（若文件已存在含 L3 段，先读全文，将 L2 段追加到末尾再 Write——禁止直接覆写；若文件不存在则新建，首行加 `# 独立审查 · 阶段 1`）

### L3 · 外部模型审查（Stop hook 自动跑 · 你不用调度）

你本轮结束后，Stop hook 的 `29-independent-review.sh` 自动用外部模型盲审同一工件，写 `INDEPENDENT-REVIEW-1.md` 的 L3 段 + `.flow-active.independent-review` 握手。下一轮 SessionStart 会注入报告摘要（verdict + 报告路径）。

### 写 done（活跃 tier 都完成后）

确认 `INDEPENDENT-REVIEW-1.md` 含所需 tier 段后执行：

    - gate_config="both" 或 "L3"：`.done` 由 l3-review.sh / Stop hook 29 写入（无需主 agent 操作）
    - gate_config="L2"（仅 L2）：主 agent 写 6 键 KVP `.done`：
      ```bash
      cat > .specs/<change-id>/.independent-review-1.done <<'DONE_EOF'
      phase=1
      change_id=<change-id>
      written_by=main-agent
      L2_verdict=<pass|fail，从 INDEPENDENT-REVIEW-1.md 提取>
      L3_verdict=skipped
      artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-1.md
      DONE_EOF
      ```

写完才能切阶段

---

## 阶段完成自检（Phase Completion Self-Check）

> ⚠️ **强制**：在进入 Pipeline Toll-Gate 之前，必须逐项完成以下自检。
> 任一 ❌ → **禁止进入 toll-gate**。先完成缺失项，然后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `REQUIREMENT.md` 已写入 `.specs/<change-id>/` | `test -f .specs/<change-id>/REQUIREMENT.md` | ✅ / ❌ |
| 2 | `CONTEXT.md` 术语表已更新（本次新术语已追加） | 人工确认 | ✅ / ❌ |
| 3 | 每条 AC 均为 Given/When/Then 结构 | 人工确认 | ✅ / ❌ |
| 4 | v1 / v2 / out 三类均已切分 | 人工确认 | ✅ / ❌ |
| 5 | 非功能性需求已显式列出（含"无"） | 人工确认 | ✅ / ❌ |
| 6 | 每条 AC 都能用一条命令或一次操作验证 | 人工确认 | ✅ / ❌ |
| 7 | .flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘 | test -s .flow-active && jq -e '.updated_at' .flow-active >/dev/null | ✅ / ❌ |

### auto_advance 分支

- 若 `auto_advance=true`：全 ✅ → 自动 transition 到 2-design；有 ❌ → **暂停 pipeline**，输出缺失清单，等待用户决定
- 若 `auto_advance=false`：全 ✅ → 进入 toll-gate；有 ❌ → **禁止进入 toll-gate**，补齐缺失项后重新自检

---

## Pipeline Toll-Gate（仅 pipeline goal 模式）

> 仅当 `.flow-active.goal.scope = "pipeline"` 且 `current_phase = "1"` 时执行本段。

**触发条件**：REQUIREMENT.md 已生成并经用户确认，CONTEXT.md 术语已更新。

检查 `auto_advance`：
- 若 `true` → 已在「阶段完成自检」段处理（全 ✅ 自动 transition，有 ❌ 暂停）。**不再进入本 toll-gate 交互**。
- 若 `false` → **停下来。必须等待用户回复。禁止自动继续。**

输出 TOLL-GATE：

```
🚦 Toll-gate 1→2：Phase 1 需求分析已完成。
✅ 产物: REQUIREMENT.md ✓ | CONTEXT.md（术语更新）✓
📋 AC: <N> 条 | v1/v2/out 已切分
   子条件:
     - "REQUIREMENT confirmed" → ✅ 已满足（如有对应 condition 子条件）

是否进入 Phase 2（技术设计）？
  1. 继续 → 进入 2-design（current_phase="2", phases_done+=["1"]）
  2. 暂停 → 保留当前状态，稍后 `/flow-go 继续` 恢复
  3. 跳过设计 → 直接进入 3-task（current_phase="3", phases_done+=["1"]）
```

用户选 1 → 执行 transition：
```bash
jq --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = "2" | .phase = "2" | .goal.phases_done += ["1"] | .goal.gates["1→2"] = "passed" | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
然后加载 `@flow-kit/prompts/2-design.md`。
