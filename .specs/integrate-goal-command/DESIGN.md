# DESIGN: 整合 CC /goal 到 flow-kit

- **Change ID**: integrate-goal-command
- **关联**: `@.specs/integrate-goal-command/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> CONTEXT.md 已锁定：Bash + Markdown（jq 辅助 JSON 操作，bats-core 测试）。本 change 不引入新语言或依赖。

- **选定**：沿用既有 — Bash 脚本（flow skill 子命令 + hooks）+ Markdown（GO.md / prompts）+ jq（.flow-active JSON 操作）
- **关键依赖**：jq（已有）、CC `/goal`（v2.1.139+，可选）
- **理由**：flow-kit 是 Bash/Markdown 元项目，无框架。本次改动仅在既有 Bash 脚本和 Markdown prompt 上增量追加
- **明确排除**：Python / Node.js（不引入新运行时——内置回退用 Shell while 循环 + prompt 文本检查）

---

## 0.5 既有架构对齐（brownfield 必填 · 来自 2-design 步骤 0.5 / B2 老项目护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/检查结果）：
- ~/.claude/skills/flow/SKILL.md（既有 · 新增 /flow goal 子命令，104 行）
- ~/.claude/flow-kit/GO.md（既有 · 路由声明新增 goal 行，351 行）
- ~/.claude/flow-kit/prompts/4-dev.md（既有 · 入场段新增 goal 提取+迭代逻辑）
- /home/hellrabbit/flow-kit-bundle/hooks/session-start/flow-kit-resume.sh（既有维护源 · 恢复时输出 goal）
- .flow-active schema（既有 JSON schema · 新增 goal 可选字段）

新增模块：
- 无新文件（纯增量修改）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh（打包脚本，改动影响分发流程）
- flow-kit-bundle/lib/*（安装脚本，与 goal 无关）
- .gitignore（手动维护）
- path-priorities.md / module-boundaries.md（架构文档）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| JSON 状态管理 | `jq`（.flow-active 读写） | 沿用 — goal 字段追加到既有 JSON |
| 子命令路由 | flow skill `/flow <cmd>` 模式（start/stop/phase/task/checkpoint/doctor） | 沿用 — `/flow goal` 遵循既有模式 |
| Hook 恢复 | `flow-kit-resume.sh` SessionStart hook | 沿用 — 追加 goal 读取逻辑 |
| 阶段路由 | GO.md 路由表 + 路由声明模式 | 沿用 — 路由声明新增 goal 行 |
| 阶段验收准则解析 | REQUIREMENT.md Given/When/Then AC | 新建提取逻辑（首次有此需求）|

### 0.5.3 沿用模式 vs 引入新模式

```
- JSON 状态管理：**沿用** jq 读写 .flow-active（既有 flow skill 所有子命令都用 jq）
- 子命令实现：**沿用** SKILL.md 内嵌 markdown 定义的子命令表格式（start/stop/phase/task/checkpoint/doctor）
- Prompt 加载：**沿用** GO.md 的「加载工件」表格（strict 全读/查表/按需）
- Goal 迭代循环：**引入新模式** → 理由：flow-kit 此前没有内置自主迭代逻辑，CC /goal 是外部依赖
- 验收准则自动提取：**引入新模式** → 理由：flow-kit 此前不做 REQUIREMENT.md 内容提取
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | Goal 状态存储在 `.flow-active` JSON 的 `goal` 字段 | 独立 `~/.claude/.goal-state` 文件 | 复用既有状态管理基础设施（flow skill 所有子命令都操作 `.flow-active`），恢复时和 change/phase 一起被 hook 读取 | goal 字段和 flow 工作流耦合在同一文件，语义上 goal 是 session 级而非 change 级 |
| D2 | CC 原生 `/goal` 可用时**委托**，不可用时**内置回退** | 仅支持 CC 原生 /goal / 仅内置回退 | 双路径保证所有 CC 版本可用，原生路径利用 Haiku evaluator 的判断准确性，回退路径保证向前兼容 | 双路径增加了实现复杂度和测试矩阵（2 个场景各 7 条 AC） |
| D3 | 内置回退用 **Shell `while` 循环 + prompt 文本检查** | Node.js/Python 脚本发 API 调 Haiku 做 evaluation | 不引入新运行时依赖，flow-kit 纯 Bash 项目定位一致 | 文本匹配准确性不如模型判断；复杂条件可能误判，需在 prompt 中强调"用工具验证" |
| D4 | Goal auto-extraction 从 REQUIREMENT.md 解析 `### AC-N ·` 标题和 `Given/When/Then` 块 | 用户每次手动输入 / 用 AI 理解语义生成 | 确定性解析，不依赖 AI token，且 REQUIREMENT.md 已有明确的 AC 文本结构规范 | 仅匹配 Given/When/Then 格式，其他格式的 AC 无法提取 |
| D5 | Goal 在 `4-dev` 入场时**建议但不强制** | 自动设定 / 不提取 | 用户有最后控制权——AC 可能不够精确或需要调整措辞 | 用户多一步确认操作，不完全自动化 |
| D6 | Goal 生命周期：1 session 1 goal，设新 goal 替换旧 goal | 多 goal 队列 | 与 CC 原生 /goal 行为一致（1 session 1 goal），简化实现和状态管理 | 无法同时追踪多个并行目标 |

---

## 2. 数据流 / 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                        GO.md 路由层                               │
│  每个阶段路由声明展示 ───→  ✅ Goal: <condition> (active, N turns) │
│  读取 .flow-active.goal 字段                                      │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│                    4-dev.md 入场                                  │
│                                                                   │
│  1. 检查 .flow-active.goal                                        │
│     ├── active → 直接启动 /goal 模式                               │
│     └── null  → 2. 读取 REQUIREMENT.md                            │
│                     └── 解析 AC-* 块                               │
│                         └── 生成建议 goal 文本                      │
│                             └── 展示给用户确认/修改                  │
│                                                                   │
│  3. 设定 goal 后：                                                │
│     ├── CC ≥ v2.1.139 → 委托 /goal <condition> (原生 loop)         │
│     └── CC < v2.1.139 → 内置回退 while loop                       │
│         ┌──────────────────────────────────┐                      │
│         │ 内置回退逻辑：                     │                      │
│         │   while goal active:              │                      │
│         │     1. 执行当前 task action       │                      │
│         │     2. turn 结束时检查条件         │                      │
│         │     3. 条件满足 → goal.status=done │                      │
│         │        条件未满足 → 继续下一 turn  │                      │
│         └──────────────────────────────────┘                      │
└──────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│                     flow skill (/flow goal)                       │
│                                                                   │
│  /flow goal <condition>  → 写 .flow-active.goal + 委托 CC /goal   │
│  /flow goal              → 读 .flow-active.goal + CC /goal status │
│  /flow goal clear        → 清 .flow-active.goal + CC /goal clear   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│                  .flow-active (JSON)                              │
│                                                                   │
│  {                                                                │
│    "change_id": "...",                                            │
│    "phase": "4",                                                  │
│    "task_id": "T3",                                               │
│    "goal": {                          ← 新增                      │
│      "condition": "pnpm test passes",                             │
│      "status": "active" | "done",                                 │
│      "active_since": "2026-06-18T10:00:00+08:00",                │
│      "turns": 3,                                                  │
│      "mode": "native" | "fallback"                                │
│    } | null,                                                      │
│    "interrupt": {...},                                            │
│    "token_spent": 0,                                              │
│    "updated_at": "..."                                            │
│  }                                                                │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│            flow-kit-resume.sh (SessionStart hook)                 │
│                                                                   │
│  1. 读 .flow-active                                               │
│  2. 如果 .goal 非空 + status=active                               │
│     → 输出横幅： 📍 恢复目标: <condition> (已执行 N turns)         │
│     → 恢复 turns 计数归零（新 session）                            │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. 关键状态机

```
        ┌──────┐   /flow goal <cond>   ┌──────────┐
        │ null │ ────────────────────→ │ active    │
        └──────┘                       └────┬─────┘
           ↑                               │
           │  /flow goal clear             │ 条件满足 (原生 evaluator
           │  或 条件满足 (回退)             │ 或内置回退检查通过)
           │                               │
           │                          ┌────▼─────┐
           └──────────────────────────│ done      │
                                      └──────────┘
                                          │
                                          │ 下一个 task 入场
                                          ▼
                                      ┌──────┐
                                      │ null  │
                                      └──────┘

状态转换规则：
- null → active：/flow goal <cond> 设定目标
- active → done：evaluator（原生）或内置检查（回退）判定条件满足
- active → null：/flow goal clear 或 Ctrl+C 中断
- done → null：下一个 4-dev task 入场时自动清除
```

---

## 4. ADR 索引

本 change 不涉及不可逆架构决策。所有决策（D1-D6）都是 flow-kit 内部实现选择，可在后续 change 中低成本调整。

- 无新增 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | CC 原生 `/goal` API 在未来版本变化（hook 接口、参数格式） | 委托模式失效，回退走内置循环 | 低 | 内置回退提供了降级路径；CC 版本检测使用 `claude --version` 输出解析，大版本跳跃时保守回退 |
| R2 | 内置回退的条件检查不准确（prompt 文本匹配误判条件满足/未满足） | 目标过早结束（条件未真正满足）或无限循环（条件已满足但判定未通过） | 中 | 在检查 prompt 中强制"用工具验证"——如检查 `pnpm test` 退出码而非读日志文本；设置最大 turns 上限（20）防止无限循环 |
| R3 | Goal auto-extraction 解析失败（REQUIREMENT.md AC 格式不规则） | 入场时不展示 goal 建议，用户需手动输入 | 中 | 解析失败时静默跳过（goal=null），不影响正常 4-dev 流程；用户可手动 `/flow goal` 设定 |
| R4 | CC 版本检测不可靠（`claude --version` 输出格式变化或不存在） | 误判 CC 版本导致走错路径（原生模式调失败/回退模式不该走） | 低 | 先尝试调用 `/goal`，失败才回退（实际可用性检测优于版本号比较） |

---

## 6. 不在范围

- Goal 在 5-test / 6-review 阶段的自主迭代（本次仅 4-dev）
- 独立的 evaluator API 调用（回退仅用 prompt 文本检查）
- Goal 模板库/预设
- Goal 执行历史持久化到 `.specs/`

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `.flow-active` goal 字段 | session 级完成条件持久化 | 4-dev 自主迭代；resume 恢复 | 后续其他阶段若需 goal，复用同一字段和状态机 |
| `/flow goal` 子命令 | goal 生命周期管理（set/status/clear） | 用户在 4-dev 或任何阶段手动管理 goal | 沿用 flow skill 子命令模式，后续可加 `--template` 等参数 |

### 9.2 新增 / 改变的项目级技术决策（建议 append 到 CONTEXT「已锁技术决策」段）

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| Goal 双路径策略 | 优先 CC 原生 `/goal`，不可用时内置回退 | 所有 4-dev 阶段的自主迭代 | 低 — 增减路径只需改 flow skill 和 4-dev prompt |
| CC 版本检测策略 | 可用性检测（尝试调用）优于版本号比较 | CC /goal 能力判定 | 低 — 检测逻辑集中在 flow skill 一处 |

### 9.3 新增 / 修改的跨模块契约（API / Schema / 事件总线）

```
- .flow-active.goal schema 扩展（新增可选字段 goal: {condition, status, active_since, turns, mode} | null）
  - 向后兼容：旧版 flow-kit 忽略未知 goal 字段（jq 读取时 .goal 为 null 即未设定）
```

### 9.4 新增 / 升级的依赖

N/A（无新增外部依赖）

### 9.5 禁动清单变化

```
- 新增禁动：.flow-active.goal 字段不允许手动编辑（必须通过 /flow goal 子命令操作，保证状态一致性）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
