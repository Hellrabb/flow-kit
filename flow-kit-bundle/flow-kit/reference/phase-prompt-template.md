# Phase Prompt 共享模板段

> 本文件**仅文档化** phase prompts 中复用的结构性模板段。各 prompt 仍内联自己的 phase-specific 内容（产物列、gate key、阶段名），但**段结构必须遵循本文件的格式约定**。新增 phase 或修改现有 prompt 时，对照本文件保持一致性。
>
> 设计理由：这些段在不同 phase 中内容差异（产物清单、gate 编号、阶段名）远大于结构差异，**强行抽取为参数化模板会反而增加复杂度**。文档化结构 + 内联内容是最佳平衡。

---

## 1. 阶段完成自检（Phase Completion Self-Check · PCSC）

### 标准位置

每个阶段 prompt 末段（"Pipeline Toll-Gate" 段之前）。

### 标准格式

```markdown
### 阶段完成自检（Phase Completion Self-Check）

> ⚠️ **强制**：在进入 Toll-gate [N]→[N+1] 之前，必须逐项完成以下自检。任一 ❌ → **禁止进入 toll-gate**。补齐后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `<phase-specific-artifact>` 已写入 `.specs/<change-id>/` | `test -f ...` | ✅ / ❌ |
| 2 | <phase-specific-check> | <verification> | ✅ / ❌ |
| ... | ... | ... | ... |
```

### 关键不变量

- **表格列名固定**：`#` / `产物/检查项` / `验证方式` / `状态`
- **第 1 项永远是阶段必产文件存在性检查**（`test -f`），不是抽象判断
- **状态列固定 `✅ / ❌`**（不让填"部分完成"等模糊值）
- **强制警告文字**保持统一（"任一 ❌ → 禁止进入 toll-gate"）
- **禁止省略验证方式**：每项必须有可重复执行的验证命令或明确的人工检查步骤

### Phase-specific 内容

- 产物清单（每个 phase 不同）
- gate 编号（如 6→7 / 4→5）
- 额外检查项（如 review phase 加"UI 视觉审查"）

---

## 2. 独立 Review 调度（Independent Review Dispatch）

### 标准位置

各 review-eligible phase（1/2/3/5/6/7）的 prompt 中，PCSC 段之前。

### 标准格式

```markdown
### 独立 review 调度（仅当本阶段 gate 开启时执行）

> ⚠️ L2 盲审必须在本阶段产物完成后、toll-gate 前完成。跳过 L2 = gate deny transition。
> **检测**：`.flow-active.goal.gate_config["<phase-key>"]` ∈ {`L2`,`both`}（`independent`/`true` 向后兼容映射为 `both`），或运行时 stop-hook.json（dsh：`.flow-kit/stop-hook.json`；claude/opencode：`.claude/stop-hook.json`）的 `independent_review.phases` 含 `"<phase-key>"`。未开启 → 跳过本段，直接进「阶段完成自检」。

本阶段产物必须通过两层独立 review 才能切到 <next-phase> / commit / 开 PR。开启时这三项操作被 PreToolUse hook 硬拦，直到你写 done 标志。

#### L2 盲审（必先）
...派发 oracle / code-reviewer / architect-reviewer 子 agent...

#### L3 外部模型（自动）
...Stop hook 29 + PreToolUse independent-review-gate.sh 自动执行...

#### done 标志
...写 `.specs/<change-id>/.independent-review-<phase-num>.done`...
```

### Phase-specific 内容

- phase-key（如 `"6-review"` / `"1-requirement"`）
- phase-num（如 `6` / `1`）
- next-phase 名（如 `7-integration` / `2-design`）
- L2 子 agent 类型推荐（review phase 用 code-reviewer/architect-reviewer；design phase 用 oracle）

### 关键不变量

- **L2 必先**：主 agent 必须先派 L2 子 agent + 写 `## L2 盲审` 段，Stop hook 才会跑 L3
- **gate 检测 jq 路径**固定：`.flow-active.goal.gate_config["<phase-key>"]`
- **done 文件命名**固定：`.specs/<change-id>/.independent-review-<phase-num>.done`

---

## 3. Pipeline Toll-Gate（阶段过渡暂停点）

### 标准位置

每个阶段 prompt 的最后一段（PCSC 之后）。

### 共享协议文件

详细 toll-gate 协议见 `@flow-kit/reference/pipeline-gates.md`。本段只内联 phase-specific 的暂停条件 + 用户决策选项。

### Phase-specific 内容

- gate 编号（如 `6→7`）
- 完成条件（自检全 ✅ + 独立 review pass）
- 用户决策选项（"继续/暂停/回退"）

### 关键不变量

- **永远提供 3 个选项**：继续 / 暂停 / 回退
- **回退目标**必须在 `[start_phase .. current_phase-1]` 内
- **transition jq** 必须同步 4 字段：`current_phase` / `phase` / `phases_done` / `gates["N→N+1"]`

---

## 4. 破坏性变更协议（1.8 Protocol）

### 标准位置

仅 4-dev.md 拥有此段（其他 phase 不需要）。已抽取到 `@flow-kit/reference/commit-protocol.md`。

### 抽取状态

✅ 已 DRY（4-dev.md 通过 @see 引用 commit-protocol.md，不再内联 jq 命令）。

---

## 5. Pipeline Goal jq 查询

### 共享协议文件

详细 jq 解析见 `@flow-kit/reference/goal-parsing.md`。各 prompt 通过 @see 引用，不再逐字重复 68 行 jq 命令。

### 抽取状态

✅ 已 DRY（TD-005 已闭合于 `goal-parsing.md` 抽取）。

---

## 维护规则

1. **新增 phase prompt 时**：对照本文件 5 个段，缺哪段补哪段
2. **修改共享段格式时**：本文件先改，然后批量更新所有 prompt 的对应段
3. **phase-specific 内容**：内联在 prompt 中，**不参数化**（避免过度抽象）
4. **结构性变更**（如新增列/改变段位置）：必须更新本文件 + 所有 prompts

## 抽取决策记录

- ✅ **已抽取**：破坏性变更协议（commit-protocol.md）/ Pipeline Goal jq（goal-parsing.md）/ Toll-gate 协议（pipeline-gates.md）/ TDD 流程（tdd-workflow.md）
- ⚠️ **结构性文档化（不抽取）**：PCSC 表格 / 独立 review 调度 — phase-specific 内容占比高，抽取反而增加复杂度
- 🟡 **未来如需进一步 DRY**：考虑参数化 PCSC 表（用模板填充产物清单），但当前 14 个 prompt 维护成本可接受
