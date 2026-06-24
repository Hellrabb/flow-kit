# GO — flow-kit 统一入口（每个 IDE 都用这一个）

> **用户使用方式**：`@flow-kit/GO.md` + 一句话意图
> AI 看到 `@GO.md` 就按本文件路由，自动决定阶段、自动生成 ID、自动按需加载工件，**不要等用户提供 ID 或路径**。

---

## 红线·Token 预算（走任何阶段前必读）

flow-kit 的文件分两类，**加载策略不同**：

| 类型 | 路径 | 长度 | 加载方式 |
|---|---|---|---|
| **SPEC**（项目产物）| `.specs/<id>/*.md` | 通常 < 200 行 | 整读 OK |
| **REFERENCE**（查阅型）| `flow-kit/reference/*.md` | 75~470 行 | **禁止默认整读**，只 grep / read offset 需要的那一节 |
| **TEMPLATE / PROMPT** | `flow-kit/templates|prompts/*.md` | < 150 行 | 整读 OK |

**违规示例**（AI 常犯）：

- ❌ 进入 2-design 阶段后直接 `read_file flow-kit/reference/tech-stacks.md` 整读 467 行
- ✅ 正确：`grep_search` 查 `适用矩阵` 或 `read_file offset=??? limit=80` 只读所需那节

- ❌ 进入 2a-ui-design 后同时读 `ui-aesthetics.md` 与 `ui-anti-patterns.md` 两全文
- ✅ 正确：`ui-anti-patterns.md` 75 行可整读；`ui-aesthetics.md` 只读「调性」一节

**Token 预算**：进入任何阶段的首轮消息，加载的 reference 总行数 ≤ **150 行**。超过 → 拆到后面按需拉。

---

## Token 预算估计 · 进阶段前必跑

> 上面是单阶段加载预算。本段是**整链路预算**——让用户提前知道价格，并选挡位。

### 典型 token 成本表（按一个中等规模 change，前端项目，5 个 task）

| 阶段 | 完整模式 | 极简模式（非 UI 跳 2a / 跳第四轮 / 跳跨模型）| 单点调用（仅跑选定阶段）|
|---|---|---|---|
| 0 + 1 + 2 + 2a + 3（规划链） | ~42k - 62k | ~30k - 45k | 按需，只跑你需要的那个 |
| 4 × 5 task（实施） | ~125k - 300k | ~125k - 300k | 单 task ~25k - 60k |
| 5（测试） | ~30k - 80k | ~20k - 50k | 单独 ~30k |
| 6（review） | ~25k - 50k | ~15k - 25k | 单独 ~25k |
| 7（集成归档） | ~20k - 40k | ~15k - 25k | 单独 ~20k |
| **总计** | **~250k - 530k** | **~205k - 445k** | **选什么跑什么** |

### 用户首轮路由后，AI 必须输出预算估算

在路由声明（见第四步）后追加一段：

```
✅ Token 预算估计：
   - 本次 change 规模：<small / medium / large>（依据：预估代码行数 / 任务数 / 是否前端）
   - 默认模式预估：~XXk - YYk tokens
   - 已选挡位：完整 / 极简 / 单点
✅ 是否继续？或换挡位？
   1. 完整（推荐 500+ 行 / 团队项目 / 长期维护）
   2. 极简（推荐 100~500 行 · 非 UI 项目可跳 2a / 跳第四轮 / 跳跨模型，省 ~20%；UI 项目 2a 不可跳）
   3. 单点（你只想跑某一阶段，告诉我哪一个）
   4. 不走 flow-kit（< 50 行代码 / bugfix 直接修，别走闭环）
```

### 何时**不必**跑这段

- 用户已显式指定模式（如「快速加个字段」/「极简模式跑」）
- 当前是恢复中断任务（直接走 R1.5 重启协议，不重新估）
- 用户跑横向命令（L-restyle / M-health）— 这些有自己的预算

### 真实成本影响因子（让估算更准）

把下面这些因子套进估算：

| 因子 | 影响 |
|---|---|
| 前端项目 | +20%（多 2a-ui-design 阶段 + UI 第三轮）|
| 涉及 schema 变更 | +5~10%（多 1.7 段 + 5-test 4.2 验证）|
| brooks-lint 已装 | +10%（多 4 个命令调用）|
| 跨模型 spot-check 触发 | +30%（双模型走同样 review）|
| task 数 < 3 | -30%（建议走单点调用不走闭环）|
| task 数 > 10 | +50%（建议拆 milestone）|

### 用户视角的取舍

| 你的诉求 | 选 |
|---|---|
| 想要全套产物（CHANGE / REQUIREMENT / DESIGN / UI-DESIGN（前端）/ TASK / SUMMARY × N / TEST / REVIEW） | 完整 |
| 想要核心产物但能少则少（REQUIREMENT / DESIGN / TASK / SUMMARY × N / REVIEW；UI 项目另含 UI-DESIGN） | 极简 |
| 只想跑某一阶段（如只 review / 只 design / 只 体检）| 单点 · 见 README 决策表 |
| 代码 < 50 行 · 一次性修补 · hackathon | 不走 flow-kit，走 7 个原生 skill 更划算 |

---

## 第一步 · 读取项目状态（必须，跳过即违反）

1. 尝试读 `STATE.md`（仓库根）。不存在 → 视为新项目，跳过
2. 关注字段：`活跃 Change` / `当前阶段` / `当前 Task` / `中断任务`
3. 如果存在 `中断任务` 非空 → **优先级最高**，直接走"恢复中断任务"分支（见下表）

### 可选 runtime adapter 检测

flow-kit 默认不依赖任何运行时。若项目同时存在 `.claude/hooks/forge-pretool-guard.ps1` 与 `.claude/hooks/forge-session-audit.ps1`，说明可选 Forge runtime adapter 已安装。

检测到 Forge 时，在路由声明里追加一行：

```text
Forge adapter: detected / not detected
```

若 detected，进入 `4-dev`、`5-test`、`6-review`、`7-integration` 时，可以把当前 `change-id`、阶段、task-id、风险、测试和 review 证据写入 Forge routing/state，供运行时门禁使用。Forge 缺失时不要报错，继续纯 markdown 流程。

## 第二步前 · Artifact Preflight Gate（强制）

路由到任何阶段前，先检查上游工件是否存在且足够用。**阶段可以压缩到同一轮对话里做，但关键工件不能缺席。**

| 目标阶段 | 必须已有的上游工件 | 缺失时动作 |
|---|---|---|
| `0-change` | 无 | 直接进入 |
| `1-requirement` | `.specs/<id>/CHANGE.md` | 回 `0-change` 生成 CHANGE |
| `2-design` | `.specs/<id>/CHANGE.md` + `.specs/<id>/REQUIREMENT.md` | 缺哪个回哪个阶段补齐 |
| `2a-ui-design` | `CHANGE.md` + `REQUIREMENT.md` + `DESIGN.md` | 回缺失阶段补齐；UI 项目不能用极简模式跳过 |
| `3-task` | `REQUIREMENT.md` + `DESIGN.md`；前端/UI 项目还必须有 `UI-DESIGN.md` | 回缺失阶段补齐 |
| `4-dev` | 正式 `.specs/<id>/TASK.md` 中的当前 task，或用户显式提供的临时最小 TASK | 没有就反问：回 `3-task` 生成正式 TASK，还是由用户提供临时最小 TASK |
| `5-test` | `REQUIREMENT.md` + `DESIGN.md` + `TASK.md` + 各 `*-SUMMARY.md` | 回缺失阶段补齐 |
| `6-review` | `REQUIREMENT.md` + `TASK.md` + `TEST.md` + 本次 diff；有 `DESIGN.md` / `UI-DESIGN.md` 时必须一起读 | 回缺失阶段补齐 |
| `7-integration` | `.specs/<id>/` 下本 change 的全部应有产物 | 回缺失阶段补齐 |

临时最小 TASK 不是正式 `TASK.md` 的隐式替代品。它只允许用于单点调用 `4-dev`，且必须由用户显式给出，包含 `id / name / read_files / write_files / action / verify / done`。AI 不允许为了绕过 `3-task` 自己编造临时 TASK。

Preflight 失败时，路由声明必须写明：

```text
规则 R2.7 触发：目标阶段缺少 <工件>。本次先回到 <阶段> 补齐，不能直接继续。
```

---

## Phase Completion Gate · 阶段退出检查（pipeline goal 强制）

> **仅 pipeline goal 模式触发**（`.flow-active.goal.scope = "pipeline"`）。
> 当 AI 请求从 phase N 进入 phase N+1 时（目标阶段 > current_phase），先验证 phase N 的产物已写入磁盘。
> 缺失 → **拒绝路由**，输出缺失清单，要求回 phase N 补齐。
> **独立于 prompt 指令**——AI 无法绕过此检查。

### 触发条件

1. `.flow-active.goal.scope = "pipeline"`
2. 目标阶段 > `current_phase`（AI 试图推进阶段）
3. `change_id` 非 null（否则跳过 PCG + 警告）

### 产物清单

| 退出阶段 | 必须产物（`.specs/<change-id>/` 下） | 验证命令 |
|---|---|---|
| 0 | `CHANGE.md` | `test -s .specs/$CHANGE_ID/CHANGE.md` |
| 1 | `REQUIREMENT.md` | `test -s .specs/$CHANGE_ID/REQUIREMENT.md` |
| 2 | `DESIGN.md` | `test -s .specs/$CHANGE_ID/DESIGN.md` |
| 3 | `TASK.md` | `test -s .specs/$CHANGE_ID/TASK.md` |
| 4 | `TASK.md`（含各 task 的 `*-SUMMARY.md`） | `test -s .specs/$CHANGE_ID/TASK.md && ls .specs/$CHANGE_ID/T*-SUMMARY.md >/dev/null 2>&1` |
| 5 | `TEST.md` | `test -s .specs/$CHANGE_ID/TEST.md` |
| 6 | `REVIEW.md` | `test -s .specs/$CHANGE_ID/REVIEW.md` |

### 拦截逻辑

读取 `.flow-active` 的 `change_id` 和 `goal.current_phase` → 对照上表检查当前阶段的必须产物 → 
- 产物完整 → ✅ 放行，继续路由
- 产物缺失 → ❌ 拒绝路由，输出：

```
⛔ Phase Completion Gate 拦截：Phase <N> 产物缺失
   缺失清单：
     - ❌ .specs/<change-id>/<缺失文件> — 未找到
   动作：请回到 Phase <N>，完成阶段工作并产出缺失文件后重试。
  提示：不要直接修改 .flow-active 的 phases_done 跳过此检查。
```

### 与 Artifact Preflight Gate 的区别

| | Artifact Preflight Gate（已有） | Phase Completion Gate（新增） |
|---|---|---|
| 方向 | **前向**：进入目标阶段需要什么 | **后向**：离开当前阶段产出了什么 |
| 触发时机 | 每次路由到新阶段 | pipeline 模式推进阶段时 |
| 检查对象 | 目标阶段的上游工件 | 当前阶段的应产工件 |

---

## 第二步 · 解析用户意图，路由到阶段

匹配表格前先判断是否是**新事物描述**：如果当前没有活跃 change，且用户是在说"做 / 想 / 加 / 实现 / 设计 + X"，即使句子里含有"设计 / UI / 测试 / review"等词，也优先路由到 `0-change`。只有已经存在活跃 change 且 Artifact Preflight Gate 通过时，才允许直达中间阶段。

按以下表格匹配用户输入（在上面优先级之后，**取最先命中那一条**）：

| 用户输入特征 | 路由到 | 备注 |
|---|---|---|
| `继续` / `接着上次` / `恢复` / `resume` | `prompts/4-dev.md` 的「入场恢复」段 | 先跑入场 Goal 检测，再加载 PROGRESS 恢复 |
| `执行 T<NN>` / `跑 T<NN>` / `do T<NN>` | `prompts/4-dev.md` | task-id 从用户输入提取 |
| `审查` / `review` / `检查代码` / `code review` | `prompts/6-review.md` | |
| `测试` / `写测试` / `UAT` / `test` | `prompts/5-test.md` | |
| `上线` / `集成` / `验收` / `ship` / `归档` | `prompts/7-integration.md` | |
| `拆任务` / `plan tasks` / `分解` | `prompts/3-task.md` | |
| `设计` + `<已有需求>` / `架构` / `design` | `prompts/2-design.md` | 仅当 `CHANGE.md` + `REQUIREMENT.md` 已存在；否则回缺失阶段 |
| `选技术` / `选栈` / `选框架` / `tech stack` / `用什么开发` / `迁移评估` | `prompts/2-design.md` 步骤 0 | 只需技术栈选型时入口 |
| `UI` / `视觉` / `美学` / `theme` / `design system` / `design tokens` | `prompts/2a-ui-design.md` | 前端项目，用户可见 UI；必须已有 `CHANGE.md` + `REQUIREMENT.md` + `DESIGN.md` |
| `换调性` / `改风格` / `换风格` / `redesign` / `restyle` / `重做视觉` / `换皮` | `prompts/L-restyle.md` | 已有项目换视觉，保留功能 |
| `健康检查` / `health` / `体检` / `技术债扫描` / `巡检` / `brooks-health` / `brooks-sweep` / `brooks-audit` / `brooks-debt` / `扫冗余` / `找死代码` / `找重复` / `清未用导出` / `清未用依赖` / `dedupe` / `dead code` | `prompts/M-health.md` | 代码库周期性巡检 + 冗余扫描（步骤 2.5），不属任何 change |
| `扫描代码` / `scan` / `intel` / `入场扫描` / `给项目体检` / `老项目首次访问` | `prompts/I-intel-scan.md` | 生成 / 更新 `.specs/CONTEXT.md`，brownfield 项目首次使用必跑 |
| `同步架构` / `沉淀架构` / `evolve` / `架构演进` / `同步 CONTEXT` / `整理沉淀` | `prompts/A-evolve.md` | 扫近期归档 change 的 DESIGN § 9，批量 review + patch CONTEXT.md / ARCHITECTURE.md（不属任何 change）|
| `建立架构` / `架构梳理` / `重构架构` / `architect` / `重审 ADR` / `画架构图` | `prompts/A-architect.md` | 首次 / 重构时建立 `ARCHITECTURE.md`。项目级 ADR / 模块图 / 跨模块契约（不属任何 change）|
| `需求` / `spec` / `requirement` | `prompts/1-requirement.md` | |
| 任何**新事物描述**（"做 / 想 / 加 / 实现 / 设计 + X"，且当前无活跃 change） | `prompts/0-change.md` | **自动生成 change-id**，不要问用户要 |
| 模糊不清 | 反问用户：「你想做的是新需求 / 继续上次 / 别的吗？」 | 一句话定位 |

> **架构级变更的二次拦截**：路由表只看关键词，但 0-change / 2-design 进去后会**用判断**做二次检测——如果用户描述涉及「拆模块 / 换数据库 / 换鉴权方案 / 改公共契约 / 容量边界 / 跨服务编排」这类项目级变更，会停下来反问"是否先跑 A-architect"。判定细则见 `@flow-kit/prompts/0-change.md` 步骤 0.4 / `@flow-kit/prompts/2-design.md` 步骤 0₋。
>
> **AI 的额外职责**：路由到 0-change / 2-design 时，路由声明的「第一动作」一栏应明确写"按 0.4 / 0₋ 先做架构级预检"，避免遗漏。

## 第三步 · 老项目入场检测（brownfield 必跑）

**触发**：进入 0-change 之前必跑。

### 3.1 探测 AI 上下文文档

按下面顺序 `ls` / `find` 探测：

| 文档 | 路径 | 来自哪个生态 |
|---|---|---|
| `CONTEXT.md` | 仓库根 / `.specs/` | flow-kit 自己 |
| `AGENTS.md` | 仓库根 | OpenAI Codex / 标准 agents 协议 |
| `CLAUDE.md` | 仓库根 / `.claude/` | Anthropic Claude Code |
| `.cursor/rules/*.md` | `.cursor/` | Cursor IDE |
| `.windsurf/rules/*.md` | `.windsurf/` | Windsurf IDE |
| `.github/copilot-instructions.md` | `.github/` | GitHub Copilot |
| `.clinerules` | 仓库根 | Cline |

读 `STATE.md` 的 `ai_context_doc`（用户上次指定的替代文档）和 `last_intel_scan` 字段。

### 3.2 判决

#### 情况 A · `STATE.md` 已设 `ai_context_doc`

用户上次明确指定了某文档为 AI 遵守依据。**直接读它**，不再询问。

后续阶段（2-design / 4-dev）改读 `<ai_context_doc>` 替代 `.specs/CONTEXT.md`。

#### 情况 B · 已存在 CONTEXT.md 且 `last_intel_scan` 在 90 天内

**直接读 CONTEXT.md**，跳过本步。无需打扰用户。

#### 情况 C · 已存在 CONTEXT.md 但超过 90 天

读 CONTEXT.md，**提醒用户**："上次扫描已 X 天，可重跑 intel-scan"，但**不强制**。

#### 情况 D · 未发现 CONTEXT.md，但有其他 AI 上下文文档（AGENTS / CLAUDE / Cursor / 等）

**反问用户**（**必须**等待回复才能继续）：

```
🔍 检测到本项目已有以下 AI 上下文文档：
  - <列出找到的，含路径与文件大小>

flow-kit 默认用 CONTEXT.md 作为单一源。请选择：
  1. 跑 intel-scan，综合现有文档 + 代码扫描，生成 CONTEXT.md（推荐）
  2. 以现有文档为准（告诉我哪个），跳过 intel-scan
  3. 跳过 intel-scan + 不读现有文档（不推荐 · AI 会盲飞）

请选 1/2/3。无人工确认前我不进 0-change（避免 AI 在不知项目约定下开始动手）。
```

- **选 1**：进 `prompts/I-intel-scan.md` 走分支 A
- **选 2**：在 `STATE.md` 写 `ai_context_doc: <用户指定路径>`，回到原意图（直接进 0-change）
- **选 3**：在 `STATE.md` 写 `ai_context_doc: none / skip`，回到原意图（带警告）

#### 情况 E · 未发现任何 AI 上下文文档（CONTEXT / AGENTS / CLAUDE / Cursor / Windsurf / Copilot / Cline 全无）

**反问用户**（**必须**等待回复才能继续）：

```
🔍 项目里未发现任何 AI 上下文文档。

flow-kit 后续阶段需要项目上下文给 AI 用。请选择：
  1. 现在跑入场扫描，自动生成 CONTEXT.md（~15-30k tokens · 仅首次 · 推荐）
  2. 我手动指定项目里某个文档作为开发遵守依据：<请回复路径>
  3. 跳过 intel-scan，直接进 0-change（不推荐 · AI 会"盲飞"，老项目护栏 B1-B5 全失效）

请选 1/2/3。无人工确认前我不开始扫描或进入 0-change（避免无意义消耗 token）。
```

- **选 1**：进 `prompts/I-intel-scan.md` 走分支 C
- **选 2**：在 `STATE.md` 写 `ai_context_doc: <路径>`，回到原意图
- **选 3**：在 `STATE.md` 写 `ai_context_doc: none`，回到原意图（带警告）

#### 情况 F · 是刚创新项目（无 `package.json` / `pyproject.toml` / 等代码上下文）

跳过本步。这是 greenfield 项目，CONTEXT.md 会在 0-change / 1-requirement / 2-design 过程中逐步沉淀。

### 3.3 为什么这步重要

跳过会导致：
- AI 不知项目架构 → 写出不合项目风格的代码
- AI 重复实现已有抽象 → 费 token 且产生重复代码
- 4-dev 1.7 schema 任务 / 1.8 破坏性变更检测都会不准
- 用户明明有 CLAUDE.md 写好的约定 → AI 完全不读 → 抱怨"为什么不按我说的来"

## 第四步 · 自动准备（不打扰用户）

进入对应阶段前，AI 必须自行完成：

- **Goal 注入**：进入任何阶段前，读取 `.flow-active` 的 `goal` 字段（`jq -r '.goal.condition // empty' .flow-active 2>/dev/null`），若非空则注入路由声明的 `✅ Goal` 行。
  若 `goal.scope` 为 `"pipeline"`，额外读取 pipeline 状态字段用于路由展示和阶段恢复：
  ```bash
  jq -r '.goal | "\(.scope // "phase")|\(.start_phase // "4")|\(.current_phase // .start_phase // "4")|\(.phases_done // [] | join(","))|\(.auto_advance // false)|\(.status // "active")|\(.turns // 0)"' .flow-active 2>/dev/null
  ```
  pipeline goal 注入时机：若 `current_phase` 匹配目标阶段 → 加载对应 prompt；若不匹配 → 在路由声明中提示"pipeline 当前阶段为 X，目标阶段为 Y"并询问是否调整。
  pipeline 起始阶段由 `start_phase` 字段决定（缺失默认 "4"，向后兼容）；阶段链为 `start_phase→...→7`。
- **新 CHANGE**：按 `prompts/0-change.md` 的步骤 0 自动生成 `change-id`（kebab-case，2~4 词），并在第一条回复里显式声明
- **目录不存在**：自行 `mkdir -p .specs/<id>/`，不要让用户先建
- **规则加载**：若 IDE 未注入全局规则，读 `@flow-kit/RULES.md`（精简版 `@flow-kit/SYSTEM.md` 也行）
- **检测外部扩展**（阶段 4/5/6/M 需要）：进入阶段前检查是否装了以下并在路由声明里表明走「外部路径」还是「内置回退」：
  - [`brooks-lint`](https://github.com/hyhmrright/brooks-lint)：4-dev self-review / 5-test 测试质量 / 6-review 代码质量 / M-health 巡检都会优先用
  - [`ui-ux-pro-max`](https://uupm.cc) / [`impeccable`](https://impeccable.style)：2a-ui-design / 4-dev UI 任务会优先用

### 加载工件（严格区分 必读 / 按需）

**语义约定**：
- `⚡︎ 全读` ：进阶段首轮必须 read_file 整个文件（只出现在 SPEC / TEMPLATE 上）
- `⚡︎ 查表` ：只 grep 指定节 或 read offset/limit，**禁止默认整读**（reference/* 都是这个）
- `⚡︎ 按需` ：首轮不读，里面某个决定点需要时才 grep / 读

| 阶段 | 全读（SPEC） | 查表（REFERENCE，只读指定节） | 按需 |
|---|---|---|---|
| 0 / 1 | —（新建）| `flow-kit/reference/ui-aesthetics.md` 只查「给 AI 在 0-change 阶段展示用的标准模板」一节（仅前端项目）| — |
| 2 | `<id>/CHANGE.md` + `<id>/REQUIREMENT.md` + `.specs/CONTEXT.md` + `.specs/ARCHITECTURE.md`（如存在 · brownfield 强烈推荐 · 重点读 § 2/§ 3/§ 4）| `flow-kit/reference/tech-stacks.md` 只查「适用矩阵」+ 过滤出的 5~6 张卡片 | ADR 阶段某项要深谈时再读 |
| 2a | `<id>/CHANGE.md` + `<id>/REQUIREMENT.md` + `<id>/DESIGN.md` `## 0` 段 + `.specs/CONTEXT.md` + `flow-kit/reference/ui-anti-patterns.md`（仅 75 行可全读）| `flow-kit/reference/ui-aesthetics.md` 查「5 维度」+ 「给 AI 的模板」 | uipro / impeccable 查询（装了才调）|
| 3 | `<id>/REQUIREMENT.md` + `<id>/DESIGN.md` + `<id>/UI-DESIGN.md`（前端项目）+ `.specs/CONTEXT.md` | — | 任务模板查询 |
| 4 | `<id>/TASK.md`（只读当前 task 块）+ `<id>/DESIGN.md` `## 0` 段 + `<id>/UI-DESIGN.md`（UI 任务）+ `.specs/CONTEXT.md` + `.specs/LESSONS.md` | `flow-kit/reference/ui-anti-patterns.md`（UI 任务 · 75 行可全读）| — |
| 5 | `<id>/REQUIREMENT.md` + `<id>/DESIGN.md` `## 0` 段 + `<id>/TASK.md` + 各 `*-SUMMARY.md` | `flow-kit/reference/test-pyramid.md` 只查「适用矩阵」+ 需要的那几轮详情 | — |
| 6 | `<id>/REQUIREMENT.md` + `<id>/DESIGN.md` + `<id>/TASK.md` + `<id>/TEST.md` + `git diff` | `flow-kit/reference/ui-anti-patterns.md`（前端项目第三轮 · 75 行可全读）| — |
| 7 | `.specs/<id>/` 全部产物 + `.specs/LESSONS.md` | — | — |
| **M** (health) | `.specs/CONTEXT.md` + `.specs/LESSONS.md` + 最近 1 份 `.specs/health/*.md`（如有，做对比基线）| — | 抽样 5 个最近改动频繁的 src/ 模块 + 5 个测试文件 + 最近 30 天 git log |
| **A** (evolve) | `STATE.md` + `.specs/CONTEXT.md` + `.specs/ARCHITECTURE.md`（如存在）+ 范围内每个 `.specs/archive/<change>/DESIGN.md` 的 § 9 段（仅 § 9，非整份 DESIGN）| — | 仅扫 `last_evolve_at` 之后归档的 change，禁止越界读 § 9 以外的 DESIGN 内容 |
| **A** (architect) | `.specs/CONTEXT.md` + `.specs/ARCHITECTURE.md`（如存在）+ `.specs/CHANGELOG.md` + `flow-kit/templates/ARCHITECTURE.md`（模板）| — | `src/` 顶层结构 + `package.json` / 依赖文件 + 抽样几份 `.specs/archive/*/DESIGN.md` |

### 查 reference 某一节的实际动作示例

```
# ± 查「适用矩阵」那一节的起始行
grep_search Query="适用矩阵" SearchPath="flow-kit/reference/tech-stacks.md"
# 取到 line 380 左右为起始，再：
read_file path="flow-kit/reference/tech-stacks.md" offset=380 limit=60
```

不要「为了保险」一上来就整读。不仅费 token，还让你在后面的推理中被无关节况干扰。

## 第五步 · 显式声明执行计划（必须）

进入实际工作前，AI 必须输出一段**路由声明**，**每个加载项必须标明起止行或「全读」**：

> **阶段入场 goal 锚定（弱模型鲁棒性 · 防中途漂移）**：若 `.flow-active.goal` 非空，路由声明必须含一行「🎯 本阶段锚定」——一句话说明本阶段如何服务于顶层 goal condition。**仅入场锚定一次，非每步唠叨**（避免反噬强模型）。对应 RULES R3.5 / AC-5。

```
✅ 路由：<阶段，例如 0-change>
✅ Change-ID：<id>（已自动生成 / 已恢复活跃 change：<existing-id>）
✅ Goal：<condition> (active, N turns)（仅当 .flow-active.goal 非空时显示 · 无 goal 时本行省略）
        pipeline 模式额外显示：
        ✅ Goal：[pipeline] <condition>
           起始: <start_phase> | 进度: <start>🔄 → ... → 7⏸（动态，根据 start_phase 生成）
           auto_advance: <true/false> | 门禁: <start>→<start+1> <状态> | ... | 6→7 <状态>
🎯 本阶段锚定：<一句话说明本阶段如何服务于顶层 goal · 仅入场一次>（仅 pipeline/active goal 时）
✅ 已加载：
   - <file1>（全读，N 行）
   - <file2>（全读，N 行）
   - <reference-file>（仅查「某节」，line X-Y）
✅ 未加载：<本阶段不需但后面可能用到的 reference，明说何时才拉>
✅ 第一动作：<具体下一步，例如 "按 0-change 流程反问澄清，先问 3 个问题"）
```

示例（2-design 阶段首轮）：

```
✅ 路由：2-design
✅ Change-ID：companion-platform
✅ Goal：（无 · 仅展示格式——有 goal 时如 "backend tests pass (active, 3 turns)"；pipeline 模式如 "[pipeline] feature X shipped | 起始: 4 | 进度: 4✅→5🔄→6⏸→7⏸ | auto_advance: false"）
✅ 已加载：
   - .specs/companion-platform/CHANGE.md（全读，52 行）
   - .specs/companion-platform/REQUIREMENT.md（全读，98 行）
   - .specs/CONTEXT.md（全读，41 行）
   - flow-kit/reference/tech-stacks.md（仅查「适用矩阵」，line 380-405，提取出 5 张候选卡）
✅ 未加载：ui-aesthetics.md / test-pyramid.md / ui-anti-patterns.md（后面阶段才需）
✅ 第一动作：按 2-design 步骤 0，列 5 张技术栈卡片 + 推荐 + 排除，等用户选定后才出 ADR。
```

用户看到这段后可以一句话纠偏（"换 id"、"我想要的是别的阶段"、"你加载太多了"），AI 必须接受。

## 第六步 · 执行对应阶段 prompt

### 6.0 路由到 4-dev 前强制 Goal 检测（R1.9）

> 本段是 GO.md 路由层的硬检查，优先级高于 4-dev.md 内部的「入场 Goal 检测」。
> 目的：确保"AI 跳过 prompt 中的 goal 检测直接执行 task"这个已知问题不再发生。

**当路由目标为 4-dev（含「继续」「执行 T<N>」「入场恢复」等所有入口）时：**

0. **第一动作（必须在加载 4-dev.md 或 TASK.md 之前）** 读取 `.flow-active.goal`：
   ```bash
   jq -r '.goal // "null"' .flow-active
   ```

1. 若 `goal` 为 `null` 或不存在 → **停下来。禁止加载 TASK.md。禁止直接执行 task。** 执行以下：
   a. 读取 `REQUIREMENT.md`，grep `### AC-` 块，提取 Given/When/Then
   b. 生成单阶段 goal 建议（拼接所有 AC Then 条件）
   c. 生成 Pipeline goal 建议（按阶段归类：4=实现/5=测试/6=审查/7=归档）
   d. 展示双选项：
      ```
      ╔══════════════════════════════════════════╗
      ║  检测到 4-dev 但无活跃 goal              ║
      ║  选择 goal 模式（自动从 REQUIREMENT 提取）：║
      ║                                          ║
      ║  1. 单阶段 — 仅 phase 4 dev 迭代          ║
      ║  2. Pipeline — 4→5→6→7 全执行链           ║
      ║  3. 我自定义条件                           ║
      ║  4. skip — 跳过 goal，直接执行             ║
      ╚══════════════════════════════════════════╝
      ```
   e. 用户确认 → AI 直接写 goal 到 `.flow-active`（jq 原子写入，复用 /flow skill 写法）
   f. goal 写入完成后 → 继续加载 4-dev.md

2. 若 `goal.status = "active"` → 展示横幅，继续加载 4-dev.md。

3. 若 `goal.status = "done"` → 提示 goal 已完成，询问是否 `/flow goal clear` 后重新设定。

### 6.1 加载对应阶段 prompt

加载 `prompts/<n>-*.md` 的内容并按其指令推进。所有规则（`RULES.md` / `SYSTEM.md`）继续生效。

---

## 极少数情况：用户根本没说他想做什么

例：用户只发了 `@flow-kit/GO.md`，正文空。

→ AI 必须主动反问，给出 3 个最可能的选项让用户选：
1. 我有个新想法想做
2. 继续上次的工作（如果 STATE 有活跃 change，主动列出）
3. 我要审查/测试某段已有代码

不要瞎猜路由。

---

## 自检（产出路由声明前）

- [ ] 已读 STATE.md（如果存在）
- [ ] 已按表格匹配意图，没有跳过
- [ ] 新 CHANGE 已自动生成 ID 并展示
- [ ] **Token 预算**：本轮加载的 reference/* 总行数 ≤ 150（全读仅 ui-anti-patterns 75 行 · 其他均查节）
- [ ] **未越界**：没有读上表「查表」或「按需」列中的文件为全文
- [ ] 路由声明含「已加载 / 未加载 / 起止行」三要素
- [ ] 没有要求用户提供 ID / 路径 / 阶段名（这些 AI 自己决定）
