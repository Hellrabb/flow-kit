# DESIGN: Goal 从单阶段自循环扩展到跨阶段 Pipeline

- **Change ID**: pipeline-goal
- **关联**: `@.specs/pipeline-goal/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 flow-kit 分发包仓库（Bash 脚本项目），无传统技术栈。技术栈已在 CONTEXT.md 锁定。

- **语言/运行时**: Bash（`#!/bin/bash`，`set -euo pipefail`）+ jq（JSON 操作）
- **前端**: 无（非 Web 项目）
- **后端**: 无
- **数据库**: 无
- **部署**: 文件级 —— 修改 `~/.claude/flow-kit/prompts/*.md`、`~/.claude/skills/flow/SKILL.md`，通过 `package-flow-kit.sh` 打包分发
- **关键依赖**: jq ≥ 1.6（JSON 原子写入）、date（ISO 8601 时间戳）
- **理由**: 本次 change 是纯流程编排改造，只涉及 Markdown prompt 文件 + Shell skill 脚本 + JSON schema 扩展，无需引入任何新工具或框架
- **明确排除**: 无（无需替换任何既有依赖）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- ~/.claude/flow-kit/GO.md（goal 注入 + 路由声明，line 254, 301, 315）
- ~/.claude/flow-kit/prompts/4-dev.md（goal 入场检测 + 迭代模式，line 9-30）
- ~/.claude/skills/flow/SKILL.md（/flow goal 子命令，line 77-109）
- ~/.claude/skills/flow-go/SKILL.md（读取 .flow-active，line 132-134）

新增模块：
- ~/.claude/flow-kit/prompts/5-test.md（新增 toll-gate 段）
- ~/.claude/flow-kit/prompts/6-review.md（新增 toll-gate + 门禁段）
- ~/.claude/flow-kit/prompts/7-integration.md（新增 pipeline 完成段）
- .specs/pipeline-goal/ 目录（本次 change 产物）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- ~/.claude/flow-kit/prompts/0-change.md（goal 不覆盖 0-3 阶段）
- ~/.claude/flow-kit/prompts/1-requirement.md（同上）
- ~/.claude/flow-kit/prompts/2-design.md（同上）
- ~/.claude/flow-kit/prompts/2a-ui-design.md（同上）
- ~/.claude/flow-kit/prompts/3-task.md（同上）
- package-flow-kit.sh（打包脚本，与本次无关）
- flow-kit-bundle/（分发源码，改动应通过 hook 维护源同步）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| JSON 状态读写 | `jq` + 临时文件 + mv 原子写入 | 沿用（`/flow` skill 已建立模式） |
| CC 原生 /goal 检测 | `claude --version` 版本检测 | 沿用（`/flow goal` 已有逻辑） |
| Phase 切换 | `/flow phase <n>` 子命令 | 沿用（pipeline 自动调用同一 jq 更新逻辑） |
| 中断恢复 | `.flow-active.interrupt` + SessionStart hook | 沿用（pipeline 恢复时额外读 `current_phase`） |
| Goal 自动提取 | 4-dev AC-5 auto-extraction | 沿用并扩展（AC-12：各阶段 sub-goal 提取） |
| Toll-gate 暂停 | 无（全新概念） | 新建（理由：pipeline 特有需求） |
| 门禁判定 | 无（全新概念） | 新建（理由：需要可配置的检查级别系统） |

### 0.5.3 沿用模式 vs 引入新模式

```
- JSON 原子写入：**沿用** jq + .tmp + mv 模式（/flow skill 所有子命令都用这个）
- Prompt 入场检测：**沿用** 4-dev.md 的"入场 Goal 检测"模式，扩展到 5/6/7
- Phase 路由：**沿用** GO.md 的 prompt 加载机制（Read + 执行指令）
- 中断恢复：**沿用** interrupt 字段 + SessionStart hook 模式
- Toll-gate 暂停：**引入新模式** → 理由：pipeline 特有，需 prompt 级指令控制 AI 在特定点等待用户输入
- 门禁配置：**引入新模式** → 理由：需 JSON schema 表达"检查项 → 级别"映射，既有无此抽象
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | Pipeline 状态存储在 `.flow-active.goal` 扩展字段，而非独立文件 | 新建 `.flow-pipeline.json` | 单一状态源，复用既有 jq 读写模式，SessionStart hook 已读 `.flow-active`。独立文件增加一致性问题（两个文件可能不同步） | goal 字段膨胀（7 个新字段），但 JSON 可读性不受影响 |
| D2 | Phase transition 由 **prompt 指令驱动**，AI 完成当前阶段后自行加载下一阶段 prompt | Hook 驱动（Stop Hook 检测 phase 完成 → 下次 SessionStart 加载新 prompt） | Prompt 驱动更直接，无需 hook 改动，同一会话内可实现连续 phase transition。Hook 方案依赖会话结束/开始，无法同会话推进 | AI 可能"忘记"触发 transition（缓解：prompt 中多处 checkpoint 提醒 + toll-gate 强制暂停） |
| D3 | Toll-gate 在 **prompt 层面实现**（AI 读到 toll-gate 指令后输出确认提示并停止），而非外部状态机 | Go/TypeScript 编写独立 toll-gate 服务 | Prompt 层面实现零依赖，与 flow-kit"纯 markdown + shell"架构一致。外部状态机增加运维复杂度 | AI 可能跳过 toll-gate 继续执行（缓解：prompt 用强硬措辞"禁止继续"、"停下来"） |
| D4 | 门禁配置用 **JSON 对象**（`gate_config`），key 为阶段名，value 为 `{检查项: 级别}` 映射 | TOML / YAML 配置文件 | JSON 与 `.flow-active` 格式一致，jq 可直接操作，无需额外解析器 | JSON 嵌套层级较深时可读性下降（缓解：`/flow goal` 展示时格式化） |
| D5 | Phase 回退用 **清空 `phases_done` 中回退阶段及之后阶段**，`current_phase` 设为回退目标 | Stack 式 push/pop（`phase_stack: ["4","5","6"]` → pop 到 "4"） | 简单直接，phases_done 语义清晰（"已完成且验证通过的阶段"）。Stack 方案过度工程——pipeline 是线性的，不需要任意跳转 | 回退后无法保留"之前 5/6 跑过一次"的历史（缓解：SUMMARY 和 toll-gate 决策日志保留在 .specs/ 下） |
| D6 | 向后兼容用 `scope` 字段区分：无 scope 或 `"phase"` → 单阶段模式；`"pipeline"` → pipeline 模式 | 新增独立 `pipeline_goal` 顶级字段 | scope 字段自然扩展，不破坏旧 `.flow-active`。独立字段会导致 goal 和 pipeline_goal 两个状态源互斥管理 | 所有读 goal 的代码都需要加 scope 判断（4 处：GO.md / 4-dev.md / 5-test.md / 6-review.md / 7-integration.md） |
| D7 | Sub-goal 自动提取复用 4-dev AC-5 的 Given/When/Then 拼接逻辑，按阶段关键词过滤 | 用 LLM 自由生成 sub-goal | 规则驱动可复现，不消耗额外 token 做生成。LLM 自由生成不稳定 | 提取质量依赖 AC 文本质量；复杂 AC 可能提取不精准（缓解：提取后展示给用户确认/修改） |

---

## 2. 数据流 / 架构图

### 2.1 Pipeline Goal 生命周期

```
  用户: /flow goal "feature X shipped" --pipeline
    │
    ▼
  /flow skill ────────────────────────────────────────────
    │  写入 .flow-active.goal {scope:"pipeline", ...}
    │  检测 CC 版本 → mode: native | fallback
    ▼
  GO.md 路由 ────────────────────────────────────────────
    │  读 .flow-active.goal，注入路由声明
    │  ✅ Goal：[pipeline] feature X shipped (4→5→6→7)
    ▼
  ┌─────────────────────────────────────────────────────┐
  │ 4-dev                                              │
  │   入场检测: goal.scope = "pipeline"                  │
  │   执行 task(s)，goal 迭代模式                        │
  │   全部 task done → TOLL-GATE 4→5                   │
  │   用户确认 → jq update current_phase="5",           │
  │             phases_done+=["4"]                      │
  └───────────────────┬─────────────────────────────────┘
                      │
  ┌───────────────────▼─────────────────────────────────┐
  │ 5-test                                             │
  │   入场检测: pipeline goal + current_phase="5"        │
  │   执行测试矩阵                                       │
  │   完成 → auto_advance?                              │
  │     yes → 跳过 toll-gate，直接 transition           │
  │     no  → TOLL-GATE 5→6                            │
  │   用户确认 → jq update current_phase="6",           │
  │             phases_done+=["5"]                      │
  └───────────────────┬─────────────────────────────────┘
                      │
  ┌───────────────────▼─────────────────────────────────┐
  │ 6-review                                           │
  │   入场检测: pipeline goal + current_phase="6"        │
  │   执行双轮 review + brooks-review                   │
  │   GATE CHECK: gate_config 判定                      │
  │     🔴 Critical → ⛔ PIPELINE PAUSE                 │
  │       [修复后继续 / 接受风险 / 放弃]                  │
  │       "回退到 4-dev" → phases_done-=["5","6"],      │
  │                         current_phase="4"            │
  │     ✅ 通过 → auto_advance?                         │
  │       yes → 直接 transition                         │
  │       no  → TOLL-GATE 6→7                           │
  └───────────────────┬─────────────────────────────────┘
                      │
  ┌───────────────────▼─────────────────────────────────┐
  │ 7-integration                                      │
  │   入场检测: pipeline goal + current_phase="7"        │
  │   归档 + CHANGELOG + git tag                        │
  │   自检顶层 goal.condition                           │
  │   ✅ PIPELINE COMPLETE                              │
  │   goal.status = "done"                              │
  │   phases_done += ["7"]                              │
  └─────────────────────────────────────────────────────┘
```

### 2.2 Phase Rollback 流程

```
  6-review 发现 Critical
    │
    ▼
  ⛔ PIPELINE PAUSE
    │
    ├─[1] 修复后继续 ──→ 回 4-dev（current_phase="4"）
    │                    phases_done 清除 "5","6"
    │                    加载 4-dev prompt
    │
    ├─[2] 接受风险 ──→ Critical 降级，继续 6→7
    │
    └─[3] 放弃 ──→ goal.status = "aborted"
```

### 2.3 状态写入路径

```
  ┌──────────┐     ┌──────────────┐     ┌─────────────────┐
  │ /flow    │────→│ .flow-active │←────│ Phase prompts   │
  │ skill    │     │ (单一状态源)  │     │ (4-dev/5-test/  │
  │ (设定)   │     └──────┬───────┘     │ 6-review/7-int) │
  └──────────┘            │             │ (transition/    │
                          │             │  gate/complete) │
                          ▼             └─────────────────┘
                    GO.md 路由
                    (读取展示)
```

---

## 3. 关键状态机

### 3.1 Goal 状态

```
         ┌─────────┐
         │  null   │──── /flow goal <cond> ────→ active
         └─────────┘
              ▲
              │ /flow goal clear
              │
    ┌───── active ──────────────────────────────┐
    │                                            │
    │ 4-dev → 5-test → 6-review → 7-integration │
    │   (current_phase 推进)                      │
    │                                            │
    ├── 全部完成 ──→ done                         │
    ├── 门禁失败 + 用户放弃 ──→ aborted           │
    └── 用户中断 ──→ paused（保留状态，可恢复）    │
```

### 3.2 Toll-gate 状态

```
  pending ──→ 用户"继续" ──→ passed ──→ transition
    │
    ├── 用户"暂停" ──→ skipped（保留状态）
    │
    └── 用户"跳过" ──→ skipped ──→ transition（无该阶段产物）
```

### 3.3 Gate 级别判定

```
  检查项 (如 "brooks-review")
    │
    ▼
  查 gate_config[phase][check]
    │
    ├── "critical" ──→ 🔴 不通过 → PIPELINE PAUSE
    ├── "warn"     ──→ 🟡 记录 SUMMARY，不阻塞
    ├── "ignore"   ──→ ⚪ 跳过不查
    └── 未配置     ──→ 使用 prompt 内置默认级别
```

---

## 4. ADR 索引

本 change 没有不可逆的架构决策——所有决策（schema 扩展 + prompt 改造）都是可逆的（改 prompt 文件即可回滚）。无需单独 ADR。

如后续需要（如 pipeline 扩展到 0-3 阶段、引入外部 toll-gate 服务），届时再写 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | Prompt 驱动的 toll-gate 可能被 AI 跳过（AI "忘记"停下来） | Pipeline 在无人确认的情况下自动推进 | 中 | Prompt 用多层级强硬措辞（"停下来"、"禁止继续"、"必须等待用户回复"）；toll-gate 输出使用醒目格式（🚦+ 选项列表）；5-test / 6-review 入场时二次检查 toll-gate 是否被跳过 |
| R2 | `.flow-active` schema 向后不兼容——旧版 flow-kit 读新 schema 时 jq 查询报错 | 部署新版 flow-kit 后旧项目无法正常读取 goal | 低 | 所有新增字段对旧代码透明（旧代码只读 `condition`/`status`/`turns`/`mode`，不关心 `scope`/`phases_done` 等新字段）；`/flow doctor` 加 goal schema 验证 |
| R3 | Pipeline 中途 compaction 后恢复时 `current_phase` 与实际产物状态不一致 | AI 从错误阶段恢复，跳过必要步骤 | 中 | SessionStart resume hook 读 `interrupt` 字段（含 `checkpoint_at` + `last_action`）；恢复时先验证上游产物是否存在（Artifact Preflight Gate），缺失则回退到对应阶段 |
| R4 | Toll-gate 疲劳——用户觉得 3 个暂停点太频繁 | 用户放弃使用 pipeline goal，退回手动推进 | 中 | AC-11 批量确认机制（`auto_advance: true`），用户可一次性确认全自动推进；只有门禁失败时才暂停 |
| R5 | Phase 回退后 TASK.md 的 done 标记与实际代码状态不一致 | 回退到 4-dev 后，AI 认为 task 已完成但代码已回滚 | 低 | 回退时清除对应 SUMMARY 文件的"已通过"标记；AI 进入 4-dev 后重新跑 verify 确认代码状态 |

---

## 6. 不在范围

- **同会话内 4→5→6→7 连续执行**：每个 phase transition 跨越 prompt 加载，在 compaction 来临时可能中断。本次不解决"如何在单次无中断会话中完成全部 4 阶段"
- **Toll-gate 超时自动推进**：如果用户长时间不回复 toll-gate，pipeline 不会自动超时继续（保持 paused）。这是刻意设计——toll-gate 不是"等 N 秒后默认通过"
- **Pipeline 执行历史可视化**：不生成甘特图/时间线等可视化产物。phase 推进记录在 `.flow-active.updated_at` + 各阶段 SUMMARY 中，足够审计
- **Goal 条件的自动验证**：pipeline 完成时对顶层 `goal.condition` 的检查仍是 AI 自判（"这个条件满足了吗？"），不做程序化的条件解析和执行

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `.flow-active.goal` 扩展 schema | Pipeline 状态管理（scope / current_phase / phases_done / gates / gate_config / auto_advance / phase_sub_goals） | 任何需要跨阶段自主推进的场景 | 将来如果 flow-kit 引入"跨 change pipeline"（project-level 编排），可复用同一 schema 模式 |
| Toll-gate 暂停协议 | Prompt 级指令控制 AI 在特定节点停止并等待用户输入 | 任何需要在 AI 自动化中插入人工确认点的场景 | 模式可复用：醒目格式 + 选项列表 + "停下来"措辞 + 下一阶段入场二次校验 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| Pipeline 范围边界 | 仅执行链 4→5→6→7（不覆盖 0-3） | 所有使用 pipeline goal 的 change | 低——扩展覆盖 0-3 只需新增 prompt toll-gate 段，不改变核心机制 |
| Phase transition 驱动方式 | Prompt 指令驱动（非 hook 驱动） | 所有 phase prompt | 中——如果改为 hook 驱动需要重构 transition 逻辑，但 prompt 内容不变 |

### 9.3 新增 / 修改的跨模块契约

```
- .flow-active.goal schema: 新增 7 个字段（scope/current_phase/phases_done/gates/gate_config/auto_advance/phase_sub_goals），旧字段保留不动
- /flow goal CLI: 新增 --pipeline flag + --gate-config 可选参数；无参数时行为不变
- GO.md 路由声明: ✅ Goal 行展示格式扩展为 "[pipeline] <condition> (phase=N, done=[...])"
```

### 9.4 新增 / 升级的依赖

无（纯 Bash + jq + Markdown，不引入新依赖）。

### 9.5 禁动清单变化

```
- 新增禁动：无（本次 change 不产生需要"以后别碰"的敏感文件）
- 解禁：无
```
