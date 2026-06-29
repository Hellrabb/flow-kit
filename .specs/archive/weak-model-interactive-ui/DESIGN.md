# DESIGN: 弱模型交互式 UI 触发强化

- **Change ID**: `weak-model-interactive-ui`
- **关联**: `@.specs/weak-model-interactive-ui/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review
- **修订**: 2026-06-29 — 架构从"纯 prompt 护栏"切换为"hook 脚本为主 + prompt 护栏为辅"

---

## 0. 技术栈选定

> 本 change 为 meta 项目（flow-kit 自身），无传统技术栈。直接从 CONTEXT.md 锁定。

- **选定**: 无标准栈卡片（flow-kit = Bash 脚本 + Markdown prompts + jq + Stop Hook 系统）
- **语言**: Bash（`set -euo pipefail`）+ Markdown（prompt/reference 文件）
- **测试**: bats-core 1.13.0（`npx bats test/`）
- **构建/部署**: `package-flow-kit.sh` 打包
- **关键依赖**: `jq`（JSON 处理）、`grep`（扫描）、Stop Hook 链（既有 `26-workflow.sh` 等模块）
- **理由**: 核心逻辑是 hook 脚本（Bash）——检测模型是否跳过交互式 UI 工具，写入矫正指令。Prompt 护栏仅作第一道轻量防线
- **明确排除**: 不引入任何新工具/框架/语言；不修改 CC 原生工具行为

---

## 0.5 既有架构对齐（brownfield）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- flow-kit/GO.md（路由层 — 含 2 处"反问用户"交互 gate）
- flow-kit/prompts/0-change.md（含 反问 gate R3.5 + 架构预检 反问）
- flow-kit/prompts/1-requirement.md（含 反问 gate R3.5）
- flow-kit/prompts/2-design.md（含 0₋ 反问 + 步骤 0 等用户选定）
- flow-kit/prompts/4-dev.md（含多处"停下来反问"：1.8.3 / goal extraction 等）
- flow-kit/prompts/6-review.md（含 "停下来。禁止自动继续。" gate）
- flow-kit/prompts/7-integration.md（含归档确认交互点）
- flow-kit/prompts/A-architect.md（含 2 处"反问用户"）
- flow-kit/reference/pipeline-gates.md（含 toll-gate 停止点共享协议）
- flow-kit-bundle/hooks/stop/（Stop Hook 链 — 插入新模块 27-interactive-ui-check.sh）
- flow-kit-bundle/hooks/session-start/（SessionStart — flow-kit-resume.sh 注入矫正逻辑）

新增模块：
- flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh（交互 UI 检测 + 矫正钩子）
- flow-kit-bundle/hooks/lib/interactive-ui-check.sh（检测逻辑库，可被多个 hook 复用）
- flow-kit-bundle/flow-kit/regression-demos/weak-model-interactive-ui/（回归演示）
- flow-kit/reference/interactive-ui-guard.md（prompt 层护栏模板，辅助防线）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh（打包脚本核心逻辑）
- flow-kit-bundle/lib/install_core.sh（安装器模块）
- .claude/（Claude Code 配置）
- brooks-lint/（独立插件，不在 scope）
- 26-workflow.sh（既有 workflow hook，不改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| Stop Hook 模块注册 | `stop-hook.json` + `26-workflow.sh` 模式 | **沿用** 既有 hook 链注册模式（`XX-name.sh` 命名 + `modules.workflow.enabled` 开关） |
| Hook 共享库 | `flow-kit-bundle/hooks/lib/` 目录已建立（含多个 `*.sh`） | **沿用** lib 目录，新增 `interactive-ui-check.sh` |
| SessionStart 矫正注入 | `flow-kit-resume.sh` 已有中断恢复逻辑 | **扩展** resume hook：检测矫正文件 → 注入矫正指令 |
| 矫正文件机制 | `.flow-active` 已有 `interrupt` 字段（checkpoint 恢复） | **沿用模式**：新增 `.flow-active.interactive-ui-fix` 矫正文件（不入库） |
| L1/L2/L3 护栏框架 | weak-model-robustness 已建立 | **沿用** L1（hook 脚本硬护栏）+ L2（prompt 结构化）+ L3（证据链） |
| regression demo | `regression-demos/` 目录已建立 | **沿用**目录结构 + check.sh 模式 |
| toll-gate 协议 | `reference/pipeline-gates.md` | 引用，不改协议逻辑 |
| bats 测试 | `test/` 目录 + bats-core | **沿用**：新增 `test/test_interactive_ui_check.bats` |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook 链扩展：**沿用** 既有 XX-name.sh + stop-hook.json 注册模式
- 交互检测：**引入新模式**（27-interactive-ui-check.sh）→ 理由：此前无交互 UI 检测模块，这是首次建立
- 矫正机制：**沿用** .flow-active 中断恢复模式（interrupt 字段 → interactive-ui-fix 文件）
- Prompt 护栏：**沿用** L2 结构化自检格式（各 prompt 已有自检 gate 模板），加轻量内联句
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **Hook 脚本为主防线**：Stop hook（27-interactive-ui-check.sh）在每次模型回复后 grep 检查是否跳过了交互 gate；跳过则写入矫正文件，SessionStart 注入矫正指令强制模型补调工具 | A: 纯 prompt 护栏（靠模型自觉） / B: PreToolUse hook 拦截 | Hook 在模型之外运行，**不依赖模型自觉**——这是根本性差异。Stop hook 能读到 transcript 实际内容，可精确判断"prompt 要求反问 vs 模型实际调了工具吗"。PreToolUse 拦截时机太早（工具调用前），无法判断"该调但没调"的场景 | Hook 脚本引入约 80-120 行 Bash；依赖 Stop hook 链正常工作（已有 6 个 hook 模块在跑，基础设施已验证） |
| D2 | **矫正文件作为跨 turn 信号**：Stop hook 检测到跳过 → 写入 `.flow-active.interactive-ui-fix`（JSON：`{gate_type, prompt_context, required_tool, timestamp}`）。SessionStart 检测到 → 注入矫正指令 → 清除文件 | A: 直接修改下一轮 prompt / B: 环境变量传递 | 矫正文件的优势：① 跨 compaction 持久化（env var 会被清）；② 已有 `.flow-active` 的 interrupt 字段模式可复用；③ 可记录跳过的上下文，注入精确的矫正指令而非泛泛提醒 | `.flow-active.interactive-ui-fix` 不入库（`.gitignore` 已覆盖 `.flow-*`），但需确保 SessionStart 能读到 |
| D3 | **双层检测逻辑**：① gate 检测（prompt 中是否含"反问用户"/"进入计划模式"/"停下来"等交互 gate 关键词）；② 工具调用检测（模型回复中是否含 `AskUserQuestion` / `EnterPlanMode` 工具调用）。两者 AND → 判定"跳过" | A: 仅检测 gate 关键词 / B: 仅检测工具调用 | 单独检测 gate 关键词会产生假阳性（prompt 提到 gate 但本轮不需要触发）；单独检测工具调用无法判断"该调但没调"。AND 逻辑精确 | 关键词匹配可能漏掉语义等价但用词不同的 gate（用多关键词 + 正则覆盖降低风险） |
| D4 | **Prompt 护栏为辅**：保留轻量内联护栏（≤ 3 行/点）——① 自检句 ② 工具调用骨架。但删除 L3 证据链层（由 hook 脚本承担） | A: 3 层全量 prompt 护栏 / B: 完全删除 prompt 护栏 | Prompt 护栏是第一道防线，减少 hook 触发次数（降低矫正延迟）。精简为 2 层（去 L3）避免啰嗦——hook 会兜底，不需要 prompt 里做最重的证据链检查 | 极弱模型可能 prompt 护栏和 hook 矫正都失效（概率低但存在）——v2 考虑 PreToolUse hook 拦截方案 |
| D5 | **强模型零影响**：hook 检测到"prompt 含 gate + 模型已调工具"→ 直接跳过，不写矫正文件，不注入任何额外指令。强模型正常行为零开销 | A: 不区分强弱模型 / B: 通过 model_tier 判断 | 条件判断天然区分：强模型调了工具 → hook 跳过；弱模型没调 → hook 矫正。不需要检测模型 tier | hook 每次都运行（约 0.1s grep），但代价可忽略 |
| D6 | **交互 gate 清单集中维护**：`interactive-ui-check.sh` 内置一个关联数组 `INTERACTION_GATES`，建立"gate 关键词 → 应调用的工具"映射。所有点位从此清单派生，不散落在各 prompt | A: 清单散落在各 prompt / B: 清单在 hook 脚本中 | 集中维护 = 单一源：新增交互 gate 只需加一行映射，hook 自动检测。避免 prompt 改了但 hook 没同步的漂移 | hook 脚本 80% 的代码是清单数据（可接受） |
| D7 | **回归演示用模拟 transcript**：demo 不依赖真实弱模型运行。每个 demo 是一个模拟 transcript（`prompt.txt` + `response.txt`，其中 response 是弱模型的"跳过 UI"典型输出），`check.sh` 验证 hook 脚本正确检测并写入矫正文件 | B: 真实模型运行 | 可 CI 集成（`make check` 一键验证）；不依赖外部模型 API；场景可精确控制（模拟最坏情况） | 模拟 transcript 可能过于理想化（v2 用真实模型补充） |

---

## 2. 数据流 / 架构图

### 核心流程：Hook 检测 + 矫正

```
┌─────────────────────────────────────────────────────────┐
│                    NORMAL FLOW                           │
│                                                          │
│  Prompt 含交互 gate ("反问用户")                           │
│       │                                                  │
│       ├── 强模型: 调用了 AskUserQuestion ──┐              │
│       └── 弱模型: 跳过了，直接文本回复 ──┐  │              │
│                                          │  │              │
│  ┌───────────────────────────────────────┘  │              │
│  │                                          │              │
│  v                                          v              │
│  Stop Hook: 27-interactive-ui-check.sh      │              │
│       │                                      │              │
│       ├── grep: prompt 含 gate?              │              │
│       │   YES → 继续检查                     │              │
│       │   NO  → 跳过（本轮无交互 gate）       │              │
│       │                                      │              │
│       ├── grep: response 含工具调用?          │              │
│       │   YES → 通过 ✅（模型已正确触发 UI）   │              │
│       │   NO  → 跳过 ❌（写矫正文件）          │              │
│       │                                      │              │
│       v                                      │              │
│  写矫正文件:                                   │              │
│  .flow-active.interactive-ui-fix             │              │
│  {                                           │              │
│    "gate_type": "AskUserQuestion",           │              │
│    "prompt_context": "反问 gate (R3.5)",     │              │
│    "required_tool": "AskUserQuestion",       │              │
│    "timestamp": "2026-06-29T..."             │              │
│  }                                           │              │
│       │                                      │              │
│       v                                      │              │
│  Session 结束（下次启动时）                     │              │
│       │                                      │              │
│       v                                      │              │
│  SessionStart: flow-kit-resume.sh            │              │
│       │                                      │              │
│       ├── 检测 .flow-active.interactive-ui-fix 存在?     │
│       │   YES → 注入矫正指令                   │              │
│       │   NO  → 正常 resume                  │              │
│       │                                      │              │
│       v                                      │              │
│  注入矫正 banner:                             │              │
│  ╔══════════════════════════════════════════╗ │              │
│  ║  ⚠️ 交互 UI 矫正：上轮你跳过了            ║ │              │
│  ║     gate_type: AskUserQuestion           ║ │              │
│  ║     context: "反问 gate (R3.5)"           ║ │              │
│  ║     现在立即调用 AskUserQuestion 补上。    ║ │              │
│  ╚══════════════════════════════════════════╝ │              │
│       │                                      │              │
│       v                                      │              │
│  模型补调 AskUserQuestion ──────> 用户看到对话框             │
│       │                                      │              │
│       v                                      │              │
│  清除矫正文件 + 正常继续                        │              │
└─────────────────────────────────────────────────────────┘
```

### 双层防线协作图

```
         ┌──────────────────────────┐
         │  第一道防线：Prompt 护栏   │  ← 轻量（≤3行/点）
         │  "❌ 如果还没调X，现在调"  │    预防 ~60% 的跳过
         │  工具调用骨架               │
         └──────────┬───────────────┘
                    │ 弱模型忽略了
                    v
         ┌──────────────────────────┐
         │  第二道防线：Hook 脚本     │  ← 主力（系统级）
         │  27-interactive-ui-check │    捕获 ~95% 的跳过
         │  → 检测跳过 → 写矫正文件   │
         └──────────┬───────────────┘
                    │ 矫正文件
                    v
         ┌──────────────────────────┐
         │  SessionStart 矫正注入    │
         │  → banner 强制模型补调    │
         │  → 清除矫正文件           │
         └──────────────────────────┘
```

### 交互 gate 清单（交互 gate 清单集中维护）

```
GATE_MAP (in 27-interactive-ui-check.sh):
  "反问用户"        → AskUserQuestion
  "反问 gate"       → AskUserQuestion
  "进入计划模式"     → EnterPlanMode
  "停下来反问"       → AskUserQuestion
  "停下来。禁止自动"  → AskUserQuestion  (Critical 确认)
  "等用户选定"       → AskUserQuestion
  "必须等待用户回复"  → AskUserQuestion
  "归档操作必须用户确认" → AskUserQuestion
  "先出计划"         → EnterPlanMode
```

### Prompt 加固点位（辅助防线，轻量）

```
仅加 2 层（去 L3 证据链）：
  ① 自检句: "❌ 如果你还没调用 <ToolName>，现在停下来调用它"
  ② 工具骨架: "<ToolName>({ ... })"

点位（与 AC-1 扫描结果一致，11 个）：
  GO.md L252, L272
  0-change.md L48, L58
  1-requirement.md L33
  2-design.md L48, L69
  4-dev.md L48, L441
  6-review.md L48
  7-integration.md L274
  A-architect.md L64, L77
```

---

## 3. 关键状态机

### 矫正文件生命周期

```
                    ┌──────────┐
                    │ 不存在    │ ← 正常状态
                    └─────┬────┘
                          │ Stop hook 检测到跳过
                          v
                    ┌──────────┐
                    │ 存在      │ ← 异常状态（等待矫正）
                    │ (PENDING) │
                    └─────┬────┘
                          │ SessionStart 检测到
                          v
                    ┌──────────┐
                    │ 存在      │ ← 矫正指令已注入
                    │ (INJECTED)│    等待模型补调
                    └─────┬────┘
                          │ 模型补调了工具 / 用户手动清除
                          v
                    ┌──────────┐
                    │ 已删除    │ ← 恢复正常
                    └──────────┘
```

### 连续跳过保护（防止 hook 矫正也失效的死循环）

```
连续矫正计数器: .flow-active.interactive-ui-fix.retry_count
  - retry_count = 0: 注入标准矫正指令
  - retry_count = 1: 注入加急矫正指令（更强硬措辞）
  - retry_count ≥ 2: 停止矫正 → 输出 "🛑 交互 gate 连续跳过 3 次。请人工介入。"
                     写入 LESSONS.md 技术债记录
```

---

## 4. ADR 索引

本次无不可逆架构决策。所有决策（D1-D7）均为 hook + prompt 层面的加固策略，可随时调整，无需 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **Hook 检测漏报**：gate 用词不在 GATE_MAP 关键词列表中，hook 不触发矫正 | 中 | 低 | D6 集中维护 GATE_MAP，新增 gate 时同步加映射。`make check` 新增一致性校验（`check-gate-sync.sh` 扩展） |
| R2 | **Hook 检测误报**：用户正常聊天中出现了"反问用户"这类词但并非交互 gate，hook 错误地写矫正文件 | 低 | 低 | 检测逻辑加上下文要求：gate 关键词必须在 prompt/系统指令中出现，而非用户消息。且矫正文件需 SessionStart 才生效，用户可在中间手动删除 |
| R3 | **Hook 本身异常**：`27-interactive-ui-check.sh` 脚本报错，影响 Stop hook 链后续模块 | 高 | 低 | 脚本顶层 `set -euo pipefail` 包在 subshell 中执行，失败不影响 hook 链继续。`|| true` 兜底 |
| R4 | **矫正也失效**：注入矫正指令后弱模型仍然不调工具（连续跳过 ≥ 3 次） | 高 | 极低 | 连续跳过保护（retry_count ≥ 2 → 停止矫正 + 人工介入提示）。同时写入 LESSONS.md 记录该弱模型不可用 |
| R5 | **Transcript 不可读**：Stop hook 运行时 transcript 文件尚未落盘或格式异常 | 中 | 低 | hook 脚本检测 transcript 文件存在性 + JSON 有效性，不满足条件时跳过（不写矫正文件，避免误报） |
| R6 | **强模型体验退化**：hook 误判强模型跳过了 gate（实际强模型用等效方式满足了 gate 但没调工具） | 低 | 低 | 只在检测到明确的工具调用（AskUserQuestion/EnterPlanMode）时才放行。强模型在交互 gate 场景下本就应调这些工具 |

---

## 6. 不在范围

- 不处理 Permission Prompt（用户反馈正常）
- 不建立弱模型触发成功率的量化指标体系（v2）
- 不扩展到 brooks-lint / gateflow 插件中的交互点
- 不自动化 lint 规则（v2）
- 不修改 CC 原生工具行为
- 不使用 PreToolUse hook（时机太早，无法判断"该调但没调"）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/hooks/stop/27-interactive-ui-check.sh` | Stop hook 交互 UI 检测 + 矫正 | 任何 Stop hook 链启用的项目 | 以后新增交互 gate 只需更新 GATE_MAP |
| `flow-kit-bundle/hooks/lib/interactive-ui-check.sh` | 交互检测逻辑库（可被其他 hook 复用） | 其他 hook 模块需要检测交互 gate 时 | `source` 此库即可用 `check_interaction_gate()` 函数 |
| `flow-kit/reference/interactive-ui-guard.md` | Prompt 层护栏模板（辅助） | 任何需要确保弱模型触发 UI 的 prompt | 轻量内联引用，≤3 行/点 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 交互 UI 检测策略 | Stop hook 脚本检测 + SessionStart 矫正注入（系统级），prompt 护栏为辅 | 所有 flow-kit 交互 gate 点位 + Stop hook 链 | 低 — hook 模块可独立启停（`stop-hook.json` 开关） |
| 矫正文件格式 | `.flow-active.interactive-ui-fix`（JSON），不入库 | SessionStart flow-kit-resume.sh | 低 — 格式可随时调整 |
| GATE_MAP 集中维护 | `27-interactive-ui-check.sh` 内的关联数组 | 交互 gate 检测覆盖范围 | 低 — 数组增删改即可 |

### 9.3 新增 / 修改的跨模块契约

```
- 新增 hooks/stop/27-interactive-ui-check.sh（Stop hook 链第 27 号模块）
- 新增 hooks/lib/interactive-ui-check.sh（检测逻辑库）
- stop-hook.json 新增 modules.interactive_ui_check.enabled 开关
- SessionStart flow-kit-resume.sh 新增矫正文件检测 + 注入逻辑
- regression-demos/weak-model-interactive-ui/ 目录（模拟 transcript + check.sh）
- 各 prompt 交互 gate 段加轻量护栏（≤3 行/点）
```

### 9.4 新增 / 升级的依赖

无。本 change 不引入任何新依赖。仅使用既有 `jq`、`grep`、`bash`。

### 9.5 禁动清单变化

```
- 新增禁动：hooks/lib/interactive-ui-check.sh（检测逻辑库，hook 模块间共享接口不允许绕过）
- 新增禁动：hooks/stop/27-interactive-ui-check.sh（不允许绕过直接修改 GATE_MAP 以外的矫正逻辑）
```
