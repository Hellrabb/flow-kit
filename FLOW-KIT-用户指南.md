# Flow-Kit 全包使用指南

> 版本: 20260622 | 源: https://github.com/hellrabb/flow-kit/tree/develop

---

## 目录

1. [什么是 flow-kit](#sec-1-what-is-flow-kit)
2. [安装](#sec-2-installation)
3. [核心概念](#sec-3-core-concepts)
4. [两大命令：`/flow-go` vs `/flow`](#sec-4-flow-go-vs-flow)
5. [生命周期：8 阶段流水线](#sec-5-lifecycle)
   - [阶段 0 — CHANGE（变更提案）](#sec-5-phase-0-change)
   - [阶段 1 — REQUIREMENT（需求）](#sec-5-phase-1-requirement)
   - [阶段 2 — DESIGN（技术设计）](#sec-5-phase-2-design)
   - [阶段 2a — UI-DESIGN（UI 美学设计）](#sec-5-phase-2a-ui-design)
   - [阶段 3 — TASK（任务拆解）](#sec-5-phase-3-task)
   - [阶段 4 — DEV（开发执行）](#sec-5-phase-4-dev)
   - [阶段 5 — TEST（测试）](#sec-5-phase-5-test)
   - [阶段 6 — REVIEW（审查）](#sec-5-phase-6-review)
   - [阶段 7 — INTEGRATION（集成与归档）](#sec-5-phase-7-integration)
6. [横向命令](#sec-6-lateral-commands)
   - [I-intel — 入场扫描](#sec-6-intel)
   - [M-health — 健康巡检](#sec-6-health)
   - [A-architect — 架构文档](#sec-6-architect)
   - [A-evolve — 架构沉淀同步](#sec-6-evolve)
   - [L-restyle — 视觉重构](#sec-6-restyle)
7. [Stop Hook 系统](#sec-7-stop-hook)
8. [brooks-lint 代码审查插件](#sec-8-brooks-lint)
9. [常用工作流示例](#sec-9-workflows)
10. [RULES 规则速查](#sec-10-rules)
11. [文件结构索引](#sec-11-file-structure)

---

<a id="sec-1-what-is-flow-kit"></a>
## 1. 什么是 flow-kit

flow-kit 是一套 **AI 驱动的软件开发流程框架**，为 Claude Code（也支持 Gemini CLI、Codex CLI）提供结构化的变更生命周期管理。它将一个需求从"模糊想法"到"合并到 main"拆分为 **8 个顺序阶段**，每个阶段有明确的输入、输出、门禁和自检清单。

### 核心组件

| 组件 | 说明 |
|------|------|
| **flow-kit 核心引擎** | `~/.claude/flow-kit/` — GO.md（统一入口）、RULES.md（硬规则）、SYSTEM.md（永久注入）、prompts/（各阶段详细 prompt）、reference/（参考文档）、templates/（产出模板） |
| **flow-* 技能包装器** | `~/.claude/skills/flow-*/` — Claude Code skill（17 个），委托到 flow-kit 核心 |
| **Stop Hook 系统** | `.claude/hooks/stop/` — 13 个模块化会话后处理脚本（CLAUDE.md 更新、记忆整理、Git 检查、质量诊断、工作流状态、交互 UI 检测、弱模型合规验证、AI 分析、报告生成） |
| **SessionStart Hook** | `.claude/hooks/session-start/` — 会话恢复 + Stop 报告提醒 |
| **brooks-lint 插件** | 6 个代码审查 skill：review / audit / debt / test / health / sweep |

---

<a id="sec-2-installation"></a>
## 2. 安装

### 2.1 从 bundle 安装

```bash
# 进入 bundle 目录
cd ~/flow-kit-bundle

# 全局安装（全部组件：核心引擎 + skills + brooks-lint + hooks）
./install.sh --global

# 项目级安装（hooks + settings.json + .specs 模板）
./install.sh --project /path/to/your/project

# 全局安装 + hooks 到用户目录（所有项目共用）
./install.sh --global --user
```

### 2.2 常用安装选项

| 选项 | 作用 |
|------|------|
| `--global` | 全局安装全部组件 |
| `--update` | 智能更新（版本比对，仅当 bundle > 已装版本才执行） |
| `--reinstall` | 彻底重装（先 rm -rf 既有安装 → 全新 --global） |
| `--project <path>` | 安装到指定项目 |
| `--user` | hooks 装到 `~/.claude/`（全局生效） |
| `--no-hooks` | 跳过 stop hook 安装 |
| `--no-skills` | 跳过 skills 安装 |
| `--no-brooks` | 跳过 brooks-lint 安装 |
| `--hooks-only` | 仅安装 hooks（需配合 --project） |
| `--dry-run` | 仅打印操作，不执行 |

### 2.3 更新

```bash
# 推荐：智能更新
./install.sh --update

# 强制重装
./install.sh --reinstall
```

> ⚠️ 不要在 `~/.claude/flow-kit/` 里手动 git pull — bundle 走 `.flow-kit-version` 版本管理。

---

<a id="sec-3-core-concepts"></a>
## 3. 核心概念

### 3.1 状态文件

| 文件 | 位置 | 用途 |
|------|------|------|
| `.flow-active` | 项目根目录 | 运行时工作流状态（current change_id, phase, task_id, interrupt checkpoint） |
| `.specs/STATE.md` | 项目根目录 | 跨会话项目状态（AI 上下文文档、阻塞项、决策日志、横向命令状态） |
| `.specs/<change-id>/` | 项目根目录 | 单个 change 的全部产物目录 |

### 3.2 `.flow-active` 结构

```json
{
  "change_id": "delivery-defer-backoff",
  "phase": "3",
  "task_id": "T2",
  "interrupt": {
    "active_file": "src/foo.ts",
    "last_action": "修复类型错误",
    "failing_check": "pnpm test foo.test.ts",
    "checkpoint_at": "2026-06-02T15:30:00+08:00"
  },
  "token_spent": 0,
  "updated_at": "2026-06-02T15:30:00+08:00"
}
```

### 3.3 Change-ID

- 格式：kebab-case，2~4 词（如 `add-notification-center`、`fix-login-paste`）
- **由 AI 在阶段 0 自动生成**，不需要用户提供
- 用作 `.specs/<change-id>/` 目录名

### 3.4 阶段一览

```
Phase 0: CHANGE      — 变更提案（模糊想法 → CHANGE.md）
Phase 1: REQUIREMENT — 需求文档（CHANGE.md → REQUIREMENT.md + Given/When/Then）
Phase 2: DESIGN      — 技术设计（REQUIREMENT.md → DESIGN.md + ADR）
Phase 2a: UI-DESIGN  — UI 美学设计（DESIGN.md → UI-DESIGN.md + Design Tokens）
Phase 3: TASK        — 任务拆解（DESIGN.md → TASK.md + XML 任务模板）
Phase 4: DEV         — 开发执行（单个任务 TDD 驱动）
Phase 5: TEST        — 五轮测试金字塔
Phase 6: REVIEW      — 三轮审查（spec 合规 + 代码质量 + UI）
Phase 7: INTEGRATION — 集成、合并与发布
```

### 3.5 横向命令（独立于阶段流水线）

| 命令 | 用途 |
|------|------|
| `I-intel` | 入场扫描：生成 CONTEXT.md（术语表 + 抽象索引 + 禁动清单） |
| `M-health` | 健康检查：代码库健康诊断 + 技术债盘点 |
| `A-architect` | 架构文档：生成/重构项目级 ARCHITECTURE.md + ADR |
| `A-evolve` | 架构沉淀：将 DESIGN 的架构沉淀同步到项目级文档 |
| `L-restyle` | 视觉重构：保留功能，重做 UI 视觉 |

---

<a id="sec-4-flow-go-vs-flow"></a>
## 4. 两大命令：`/flow-go` vs `/flow`

**这是最容易混淆的地方，务必理清：**

### `/flow-go` — 统一入口（自动路由）

用户通过 `/flow-go` 描述意图，AI 自动解析、路由到对应阶段。

```
/flow-go 我想给用户加一个通知中心
→ AI 自动：读状态 → 路由到阶段 0 → 生成 change-id → 输出预算估算 → 开始 CHANGE
```

**核心体验**：你只需要说出想做什么，AI 负责判断应该走哪个阶段、加载哪些文件。

以下为简化路由表（完整路由表见 GO.md 第二步，含"选技术""验收""写测试""plan tasks""redesign""技术债扫描"等更多条目）：

| 你说的关键词 | AI 自动路由到 |
|-------------|-------------|
| "做/想/加/实现/设计 + X"（新事物） | 阶段 0 CHANGE |
| "继续" / "接着上次" / "恢复" | 阶段 4 DEV（恢复中断任务） |
| "执行 T1" / "跑 T2" | 阶段 4 DEV |
| "需求" / "spec" | 阶段 1 REQUIREMENT |
| "设计" / "架构" | 阶段 2 DESIGN |
| "UI" / "视觉" / "design tokens" | 阶段 2a UI-DESIGN |
| "拆任务" / "分解" | 阶段 3 TASK |
| "测试" / "UAT" | 阶段 5 TEST |
| "审查" / "review" | 阶段 6 REVIEW |
| "上线" / "集成" / "归档" | 阶段 7 INTEGRATION |
| "扫描代码" / "intel" / "入场扫描" | I-intel |
| "健康检查" / "体检" / "技术债" | M-health |
| "换调性" / "redesign" / "换风格" | L-restyle |
| "建立架构" / "architect" | A-architect |
| "同步架构" / "沉淀架构" / "evolve" | A-evolve |

> **关键规则**：如果当前没有活跃 change，且你在描述一个新事物（"做 / 想 / 加 / 实现 / 设计 + X"），即使句子里含"设计""审查"等词，AI 也优先路由到阶段 0 CHANGE（因为必须先有 CHANGE 才能做后续阶段）。如果只是孤立的关键词（如 `/flow-go 审查代码`），则按路由表直接匹配——Preflight Gate 会在缺少工件时拦截。

### `/flow` — 状态管理（手动操作）

操作 `.flow-active` 文件，用于查看和手动调整状态。

| 子命令 | 作用 | 使用场景 |
|--------|------|---------|
| `/flow start` | 创建 `.flow-active`（phase=0） | **新项目第一步必须手动执行**——后续 checkpoint/phase/doctor 都依赖此文件 |
| `/flow stop` | 结束当前 change，清理 `.flow-active` | change 完成后收尾 |
| `/flow phase <n>` | 手动切换阶段 | 想跳转/回退到某个阶段时 |
| `/flow task <T<N>>` | 设置当前任务 ID | 手动指定要执行的任务 |
| `/flow goal <条件> [--pipeline] [--from <n>]` | 设定完成条件（Goal），支持单阶段和跨阶段 Pipeline 模式 | 想让 AI 自动跨 turn 迭代直到条件满足时 |
| `/flow goal`（无参数） | 查看当前 goal 状态 | 查看 goal 条件、进度、toll-gate 状态 |
| `/flow goal clear` | 清除当前 goal | goal 已满足或不再需要时 |
| `/flow checkpoint <file> <desc>` | 保存中断恢复点 | AI 在关键操作后自动调用 |
| `/flow`（无参数） | 查看当前状态 | 想知道现在在哪个阶段、哪个任务 |
| `/flow doctor` | 诊断配置状态 | 排查 hook 配置、产物完整性等问题 |

### 总结

```
/flow start  =  初始化 .flow-active（新项目第一步，必须手动执行一次）
/flow-go     =  "我想做 X" → AI 自动路由 + 执行
/flow        =  其他状态管理（查看/切换/诊断）
```

**典型使用顺序**：先 `/flow start` 创建状态文件，再用 `/flow-go` 描述意图让 AI 自动路由。后续的 checkpoint、phase、doctor 都依赖 `.flow-active` 存在。

### 4.1 `/flow goal` — Goal 系统与 Pipeline 执行模型

Goal 是 flow-kit 的**自动迭代引擎**——设定一个完成条件后，AI 自主跨 turn 迭代，直到条件满足。

#### 4.1.1 Goal 基础：单阶段模式

```bash
# 设定一个简单的 goal（当前阶段的完成条件）
/flow goal "pnpm test passes and lint is clean"

# 查看 goal 状态
/flow goal
# → 🎯 Goal: pnpm test passes and lint is clean
#      状态: active | 已执行: 3 turns | 模式: native

# 条件满足后清除
/flow goal clear
```

**工作原理**：AI 每 turn 结束后自动检查条件是否满足。满足则停止；不满足则继续迭代修复。CC ≥ v2.1.139 时使用原生 `/goal` 命令（更高效），旧版本使用内置 prompt 回退。

**Goal 自动提取**：进入阶段 4（DEV）时，AI 自动从 `REQUIREMENT.md` 的 Given/When/Then AC 中提取 goal 建议文本，用户可确认或修改。无需手动编写 goal 条件。

#### 4.1.2 Pipeline Goal：跨阶段自动执行

Pipeline goal 将 goal 从**单阶段自循环**扩展到**跨阶段自动推进**，覆盖完整的 0→1→2→3→4→5→6→7 执行链。

```bash
# 从阶段 4 起步（默认，向后兼容）
/flow goal "all tests pass AND review passes" --pipeline

# 从阶段 0 起步（全链路）
/flow goal "CHANGE.md confirmed AND all tests pass" --pipeline --from 0

# 自定义门禁配置（两种 key 类型可共存）
/flow goal "docs updated" --pipeline --from 0 \
  --gate-config '{"1-requirement":"independent","6-review":"independent"}'

# 同时使用两种 key 的示例：
/flow goal "..." --pipeline --from 4 \
  --gate-config '{"6-review":"independent","4→5":"warn"}'
```

**`--gate-config` 接受两类 key**：

| Key 类型 | 格式 | 示例 | 用途 | 有效值 |
|----------|------|------|------|--------|
| **阶段名 key** | `1-requirement` / `2-design` / `6-review` | `"6-review":"independent"` | 开启该阶段独立 review（L2 盲审 + L3 外部模型），阻止 commit/PR/切阶段直到 done | `independent` / `true`（开启）<br>`off` / `false`（关闭） |
| **Transition key** | `N→N+1`（如 `4→5`） | `"4→5":"critical"` | 控制阶段间 toll-gate 门禁级别 | `critical`（阻断 pipeline）<br>`warn`（提示但不阻断）<br>`ignore`（跳过该 gate） |

两类 key 可在同一个 `--gate-config` JSON 中并存，互不冲突。

**执行链**：由 `--from <n>` 决定起始阶段（0-7，默认 4），AI 在每个阶段完成后自动推进到下一阶段。

| 阶段 | 作用 | Toll-Gate |
|------|------|-----------|
| 0→1 | CHANGE → REQUIREMENT | 产物确认 |
| 1→2 | REQUIREMENT → DESIGN | AC 已切分 v1/v2/out |
| 2→3 | DESIGN → TASK | 技术栈已锁定 |
| 3→4 | TASK → DEV | 波次划分清晰 |
| 4→5 | DEV → TEST | 所有 task verify 通过 |
| 5→6 | TEST → REVIEW | 测试矩阵通过 |
| 6→7 | REVIEW → INTEGRATION | 审查无 🔴 Critical |
| 7 | INTEGRATION → 完成 | 归档产物齐全 |

##### Toll-Gate（阶段过渡暂停点）

每个阶段完成后，AI 在 toll-gate **暂停并等待用户确认**，不自动继续。这确保用户在每个关键节点有决策权。

```
🚦 Toll-gate 4→5：Phase 4 开发已完成。
✅ 产物: T1-SUMMARY.md ✓ | T2-SUMMARY.md ✓
📋 verify: T1 ✅ | T2 ✅
   子条件: "all tests pass" → ✅ 已满足

是否进入 Phase 5（测试）？
  1. 继续 → 进入 5-test
  2. 暂停 → 保留状态
  3. 跳过 → 直接进入 6-review
```

##### Auto-Advance（自动推进模式）

当 `auto_advance=true` 时，阶段完成自检（PCSC）全绿后自动 transition，不等待用户确认。适用于无人值守的批处理场景。默认 `false`。

##### 阶段子目标（phase_sub_goals）

可为每个阶段设定独立的子目标：

```bash
/flow goal "docs updated" --pipeline --from 4 \
  --sub-goal-4 "write all sections" \
  --sub-goal-5 "grep checks pass" \
  --sub-goal-6 "manual review done"
```

#### 4.1.3 PCSC/PG 双层防护

flow-kit 用**两层独立检查**确保每个阶段的产物完整性，防止 AI 跳过阶段或遗漏产物。

##### 第一层：PCSC（Phase Completion Self-Check）

**每个阶段 prompt 内置的产物自检段。** AI 在进入 toll-gate 前必须逐项自检：

```
# Phase 4 自检示例：
| # | 产物/检查项                          | 状态 |
|---|-------------------------------------|------|
| 1 | T<N>-SUMMARY.md 已写入 .specs/<id>/ | ✅   |
| 2 | verify 命令已通过                    | ✅   |
| 3 | write_files 边界未越界               | ✅   |
| 4 | TDD RED→GREEN→REFACTOR 已完成        | ✅   |
```

任一 ❌ → **禁止进入 toll-gate**，必须先补齐缺失项。

##### 第二层：PCG（Phase Completion Gate）

**GO.md 路由层的独立产物检查门禁。** 当 AI 请求进入 phase N+1 时，GO.md 检查 phase N 的必须产物是否**存在于磁盘**（`test -f`）。缺失 → 拒绝路由，输出缺失清单。

PCG 独立于 prompt 指令运行——即使 AI "忘记"跑 PCSC，PCG 也会在路由层拦截。

##### 双层防护如何协作

```
Phase N 完成
    │
    ▼
PCSC（prompt 层）— AI 自检产物清单 → 有 ❌ → 补齐
    │ 全 ✅
    ▼
Toll-Gate — 等待用户确认
    │ 确认继续
    ▼
PCG（路由层）— GO.md 检查磁盘产物 → 缺失 → 拒绝路由
    │ 存在
    ▼
Phase N+1 开始
```

这种双层设计修复了一个曾存在的**阶段跳过漏洞**：AI 可能在 PCSC 不完整的情况下直接进入 toll-gate 并 transition。PCG 作为独立于 prompt 的第二道防线，确保了无论 AI 行为如何，产物必须在磁盘上才能推进。

#### 4.1.4 Pipeline Rollback（智能回退）

当 pipeline 执行中某个阶段失败时，flow-kit 根据**失败分类表**决定回退策略：

| 失败类型 | 示例 | 回退动作 |
|---------|------|---------|
| 产物缺失 | `TEST.md` 不存在 | 回退到缺失阶段，补齐产物 |
| 门禁失败 | verify 命令报错 | 留在当前阶段，修复后重试 |
| 不可恢复 | 设计推翻 (ADR 冲突) | 回退到 DESIGN（阶段 2）重新设计 |

**动态下界**：回退不会低于 pipeline 的 `start_phase`（由 `--from <n>` 决定）。例如 `--from 4` 时，任何失败的回退最多到阶段 4，不会意外回到 0-3。

**jq 通用化**：回退操作通过 jq 更新 `.flow-active` 实现，不依赖特定工具或运行时。

---

<a id="sec-5-lifecycle"></a>
## 5. 生命周期：8 阶段流水线

### AI 内部执行流程（GO.md）

每次 `/flow-go` 调用时 AI 内部执行：

1. **第〇步**：确定 flow-kit 根目录（project-priority fallback：项目级 > user-scope）
2. **第一步**：读取 `.specs/STATE.md` + `.flow-active`（含 interrupt 恢复检测）
3. **第二步前**：Artifact Preflight Gate — 检查上游工件是否齐全，缺失则回退补齐
4. **第二步**：解析用户意图，按路由表匹配阶段
5. **第三步**：老项目入场检测（brownfield 必跑，视情况跑 intel-scan 或反问）
6. **第四步**：自动准备（加载工件，严格区分全读/查表/按需）+ Token 预算估算
7. **第五步**：显式声明路由计划（已加载/未加载/第一动作）
8. **第六步**：执行对应阶段 prompt

用户看到路由声明后可以一句话纠偏（"换 id"、"我要的是别的阶段"），AI 必须接受。

---

<a id="sec-5-phase-0-change"></a>
### 阶段 0 — CHANGE（变更提案）

**目的**：把模糊想法变成一份结构化变更提案。

**输入**：用户描述（一句话也行）

**产出**：`.specs/<change-id>/CHANGE.md`

**关键步骤**：
1. AI 自动生成 `change-id`（kebab-case，动词-名词，2~4 词）
2. AI 自动创建 `.specs/<change-id>/` 目录
3. 写 `CHANGE.md`：what / why / scope（v1 / v2 / out）/ 影响面猜测 / 风险猜测 / 视觉调性（如果是 UI 变更）

**自检清单**：
- [ ] change-id 是 kebab-case
- [ ] v1 / v2 / out 三段范围已写
- [ ] 如果涉及 UI，已选视觉调性
- [ ] CHANGE.md 已写入

**继续方式**：
- 主要：用自然语言推进 → `/flow-go 写需求` 或直接描述需求细节
- 备选：手动切换 → `/flow phase 1`

---

<a id="sec-5-phase-1-requirement"></a>
### 阶段 1 — REQUIREMENT（需求）

**目的**：把变更提案变成可执行需求，包含 Given/When/Then 验收准则。

**前置工件**（Artifact Preflight Gate）：CHANGE.md 必须存在

**产出**：`.specs/<change-id>/REQUIREMENT.md`

**关键步骤**：
1. 写需求（每条需求对应 CHANGE 的 scope）
2. 提取域语言（术语表，每个词一句话定义）
3. 反问（如果任何关键信息缺失）

**约束**：
- 每条 AC（验收准则）必须用 Given/When/Then 格式
- v1 / v2 / out 范围必须和 CHANGE.md 对齐
- 不允许在需求阶段做技术设计决策

**自检**：
- [ ] 每条需求都有 AC
- [ ] 术语表完整
- [ ] 未做技术决策（框架、库、表结构等）

**继续方式**：
- 主要：→ `/flow-go 做技术设计`
- 备选：→ `/flow phase 2`

---

<a id="sec-5-phase-2-design"></a>
### 阶段 2 — DESIGN（技术设计）

**目的**：把需求变成可执行的技术设计 + ADR。

**前置工件**：CHANGE.md + REQUIREMENT.md 必须存在

**产出**：`.specs/<change-id>/DESIGN.md` + 可选 ADR

**关键步骤**：

1. **架构级变更预检**（二次保险）：判定是否为破坏性变更
2. **技术栈预选**（独立消息，等用户选定后才继续）：
   - 例外：技术栈已在 CONTEXT 锁定 → 跳过
   - 常规：给 2-3 个选项卡片，用户选一个
3. **既有架构对齐**（brownfield 必跑）：
   - 列出会被触碰的既有模块
   - 对齐既有抽象（防重复实现）
   - 沿用模式 vs 引入新模式
4. **技术决策**（每条都要有理由）
5. **数据流/架构图**（文字版即可）
6. **ADR**（Architecture Decision Records）
7. **风险**
8. **不在范围内**
9. **架构沉淀建议**（软约束，判定有没有项目级复用价值）

**自检**：
- [ ] 技术栈已选定（或跳过理由已写）
- [ ] brownfield 项目已跑既有架构对齐
- [ ] 关键决策有 ADR
- [ ] 风险有缓解策略

**继续方式**：
- UI 项目 → `/flow-go 确定 UI 设计`
- 非 UI 项目 → `/flow-go 拆任务`

---

<a id="sec-5-phase-2a-ui-design"></a>
### 阶段 2a — UI-DESIGN（UI 美学设计）

**目的**：在动手写 UI 代码之前，把视觉方向、Design Tokens、组件规约决定清楚。

**前置工件**：CHANGE.md + REQUIREMENT.md + DESIGN.md 必须存在

**产出**：`.specs/<change-id>/UI-DESIGN.md`

**关键步骤**：

1. **判定 greenfield vs brownfield**：
   - greenfield：全新 UI → 走美学方向决策
   - brownfield：改现有 UI → 走视觉语汇对齐
2. **美学方向决策**（greenfield）：
   - 回答 4 个问题：目的、调性（从 CHANGE.md 读取，不重选）、约束、差异化
   - 任一答不出 → 停下来反问
3. **brownfield 视觉语汇对齐**：挖出现有 CSS variables / theme 文件中的颜色、字体、间距等
4. **v0 草稿确认**：贴 ASCII 布局 + 描述，用户确认后再继续
5. **Design Tokens**：OKLCH 颜色 + px/rem 间距 + 字体族 + 圆角 + 动效规范
6. **关键组件规约**（3-5 个核心组件）
7. **Do's and Don'ts**
8. **占位符策略**（反 AI 自动扣图）
9. **反 AI-slop 自检**

**外部 skill 集成**：如果装了 `ui-ux-pro-max` 或 `impeccable`，优先使用这些外部 skill。

**继续方式**：
- 主要：→ `/flow-go 拆任务`
- 备选：→ `/flow phase 3`

---

<a id="sec-5-phase-3-task"></a>
### 阶段 3 — TASK（任务拆解）

**目的**：把设计拆成可并行执行的原子任务。

**前置工件**：REQUIREMENT.md + DESIGN.md（+ UI-DESIGN.md 如有）

**产出**：`.specs/<change-id>/TASK.md`

**关键步骤**：

1. **拆解原则**：
   - 每个任务是原子的、可独立验证的
   - 一个 task ≤ 一个文件的主要变更
   - 区分 `read_files` vs `write_files`（只读 vs 写入创建）
2. **波次划分**：
   - 波次 1：基础/核心（先跑）
   - 波次 2：功能（依赖波次 1）
   - 波次 3：打磨/优化
3. **任务模板（XML 格式）**：
```xml
<task id="T1" wave="1" depends_on="">
  <title>任务标题</title>
  <description>做什么</description>
  <read_files>
    <file>src/lib/api-client.ts</file>
  </read_files>
  <write_files>
    <file>src/features/xxx.ts</file>
  </write_files>
  <done>
    <criterion>测试通过（具体命令）</criterion>
  </done>
  <verify>
    <command>pnpm test xxx.test.ts</command>
  </verify>
</task>
```

**自检**：
- [ ] 每个 task 都有 write_files + verify
- [ ] 波次依赖合理（T2 depends_on T1 只在同波次内）
- [ ] 覆盖了 v1 范围的全部需求

**继续方式**：
- 主要：→ `/flow-go 执行 T1`
- 备选：→ `/flow task T1`

---

<a id="sec-5-phase-4-dev"></a>
### 阶段 4 — DEV（开发执行）

**目的**：在 fresh context 中执行单个任务，TDD 驱动。

**前置工件**：TASK.md 中的当前 task（或用户显式提供的临时最小 TASK）

**产出**：代码 + 测试 + `<task-id>-SUMMARY.md`

**关键步骤**：

1. **读取任务**（理解要做什么）
2. **沿用既有抽象 grep**（强制）：
   - 写新代码前必须 grep 同类抽象
   - 找到 → 沿用；未找到 → 才新建
   - 结果写入 SUMMARY 的「6 维自查」段
3. **扫 LESSONS**（强制，读 `.specs/lessons/` 避免重犯已知错误）
4. **UI 任务额外检查**（如果涉及 UI）：检查既有关键组件、design tokens 对齐
5. **DB Schema 任务额外检查**（如果涉及表/字段变更）：
   - 声明 schema diff
   - 选执行机制（Prisma / Alembic / Flyway / raw SQL）
   - 生成可逆迁移
   - 检测 DB 凭据，决定是否现在执行（反问用户）
6. **破坏性变更高门槛**（强制）：
   - grep 引用图
   - 列出影响清单
   - 反问用户确认
7. **TDD 优先**（默认开启）：
   - RED → GREEN → REFACTOR
   - 纯文档/配置任务可跳过，需在 SUMMARY 说明
8. **跑 verify**
9. **提交前 self-review**（6 维自查：装了 brooks-lint 优先用 `/brooks-review`）
10. **提交前 diff 边界 verify**（强制）：比对 TASK 的 write_files，确保无越界
11. **原子提交**（R4.1）
12. **写 SUMMARY** + 标记完成

**中断恢复**：会话中途断开后，下次通过 `/flow-go 继续` 从 `.flow-active` 的 `interrupt` 字段自动恢复。

**继续方式**：
- → `/flow-go 执行 T2`（下一个任务）
- → `/flow-go 开始测试`（全部任务完成）

---

<a id="sec-5-phase-5-test"></a>
### 阶段 5 — TEST（测试）

**目的**：五轮测试金字塔。

**前置工件**：REQUIREMENT.md + DESIGN.md + TASK.md + 各 `*-SUMMARY.md`

**产出**：`.specs/<change-id>/TEST.md`

**五轮金字塔**：

| 轮次 | 内容 | 说明 |
|------|------|------|
| 1 | **功能测试** | 测试矩阵 + UAT 脚本 + 覆盖率 + 6 维测试衰退风险 |
| 2 | **性能测试** | 性能预算确认 + 前端性能（LCP/FID/CLS）+ 后端/API 性能 |
| 3 | **安全测试** | 依赖漏洞扫描 + 秘钥扫描 + SAST + OWASP Top 10 清单 |
| 4 | **兼容性测试** | 跨浏览器/跨设备 + 数据迁移测试 + 跨版本/跨编码 |
| 5 | **可观测性验证** | 日志验证 + 指标/追踪 + 告警 + 健康检查 |

**步骤 0**（强制）：先声明本次走哪几轮。

**继续方式**：
- 主要：→ `/flow-go 审查代码`
- 备选：→ `/flow phase 6`

---

<a id="sec-5-phase-6-review"></a>
### 阶段 6 — REVIEW（审查）

**目的**：三轮审查（spec 合规 + 代码质量 + UI），只产报告不直接改代码（R3.3）。

**前置工件**：REQUIREMENT.md + TASK.md + TEST.md + git diff（+ DESIGN.md / UI-DESIGN.md 如有）

**产出**：`.specs/<change-id>/REVIEW.md` + 修复任务

**三轮审查**：

1. **Spec 合规审查**：逐条对照 REQUIREMENT 的 AC，检查是否全部满足
2. **代码质量审查**（书本驱动 6 维衰退风险）：

   | 编号 | 衰退风险 | 核心问题 |
   |------|---------|---------|
   | R1 | Cognitive Overload | 理解这段代码要多少心智？ |
   | R2 | Change Propagation | 改一点会坏多少不相干的地方？ |
   | R3 | Knowledge Duplication | 同一个决定是否被表达在多处？ |
   | R4 | Accidental Complexity | 代码是否比问题本身更复杂？ |
   | R5 | Dependency Disorder | 依赖流是否一致方向？ |
   | R6 | Domain Model Distortion | 代码是否忠实反映业务领域？ |

   - **装了 brooks-lint**（首选）：调用 `/brooks-review` 或 `/brooks-audit`，输出原样贴入 REVIEW.md
   - **未装**：AI 自己逐维诊断（质量明显低于 brooks-lint，发现率 ~16% vs 100%）

3. **UI 视觉审查**（仅前端项目）：Design Tokens 一致性 + Anti-Pattern 扫描 + 视觉北极星一致性 + 无障碍快检

4. **补充审查**（可选）：
   - 技术债评估（里程碑/季度大版本触发）
   - 跨模型 spot-check（强烈建议）

**严重度分级**：🔴 Critical / 🟡 Major / 🟢 Minor

**继续方式**：
- 有阻塞问题 → 回到 `/flow-go 执行 TN` 修复
- 审查通过 → `/flow-go 集成上线`

---

<a id="sec-5-phase-7-integration"></a>
### 阶段 7 — INTEGRATION（集成与归档）

**目的**：集成验证 + UAT + 失败诊断 + 归档。

**前置工件**：`.specs/<id>/` 下全部应有产物

**产出**：`.specs/<change-id>/ARCHIVE.md` + 可选 LESSONS

**关键步骤**：

1. **跑全套自动化**（test + lint + build）
2. **引导人工 UAT**：逐条 AC 打勾
3. **失败诊断**（自动 + 人工）
4. **提名 LESSONS**（在 ARCHIVE 之前必跑）：
   - 这次踩了什么坑？
   - 下次怎么做更好？
5. **归档（ARCHIVE）**：完整的 change 追溯
6. **Git 收尾**（均需用户明示确认后分步执行）：
   - 是否合并到 main？（反问用户：选 1 合并 / 2 保留分支）
   - 是否创建 PR？（反问用户确认）

**自检**：
- [ ] 自动化全绿
- [ ] UAT 清单全部打勾
- [ ] LESSONS 已提名（至少一条）
- [ ] ARCHIVE 已写入
- [ ] Git 操作已获用户确认

**完成后**：
- 运行 `/flow stop` 清理 `.flow-active`
- 建议运行 `/flow-go 同步架构`（A-evolve）将架构沉淀同步到项目级文档

---

<a id="sec-6-lateral-commands"></a>
## 6. 横向命令

横向命令独立于阶段流水线，用 `/flow-go` + 关键词触发自动路由，也可以用 `/flow-<命令名>` 直接调用。

<a id="sec-6-intel"></a>
### I-intel — 入场扫描

**触发**：`/flow-go 扫描代码` / `/flow-intel`，或新项目首次使用 flow-kit 时自动提示。

**输出**：`.specs/CONTEXT.md` + 更新 `.specs/STATE.md`

**步骤**：
1. 既有文档探测：扫 CONTEXT.md / AGENTS.md / CLAUDE.md / Cursor rules / Windsurf rules 等
2. 包管理与运行时探测
3. 框架检测（前端 + 后端）
4. 关键约定提取（lint 配置、测试框架、命名约定）
5. 既有抽象层提取（防重复实现）：HTTP 客户端、日期处理、错误处理、状态管理等
6. 数据库 schema
7. 基础设施
8. 生成 CONTEXT.md：术语表 + 既有抽象索引 + 已锁技术决策 + 禁动清单 + 命名约定

**CONTEXT.md 有效期**：90 天。过期后 AI 会提示重新扫描。

---

<a id="sec-6-health"></a>
### M-health — 健康巡检

**触发**：`/flow-go 体检` / `/flow-health`

**模式**：
- **快速**：~5 分钟，抓关键指标
- **标准**（默认）：全维诊断
- **深度**：含建议 roadmap

**两种路径**：
- **装了 brooks-lint**（首选）：调用 `/brooks-health`，覆盖 6 维衰退风险
- **未装**：AI 内置抽样（精度低，明标）

**冗余巡检**（brooks-lint 不覆盖的维度）：
- 字面重复块（jscpd）
- 未用导出/孤立文件（knip / ts-prune / vulture）
- 未用依赖（depcheck / deptry）
- 死代码/不可达（ESLint / vulture / staticcheck）

**输出**：`.specs/health/<YYYY-MM-DD>-HEALTH.md`

---

<a id="sec-6-architect"></a>
### A-architect — 架构文档

**触发**：`/flow-go 建立架构` / `/flow-architect`

**输出**：项目根 `ARCHITECTURE.md` + `adr/` 目录

**步骤**：
1. 判定模式（首跑 vs 重构）
2. 系统概览：一句话定位 + 服务边界图 + NFR 基线
3. 模块清单 + 依赖规则（grep 出实际模块）
4. ADR 列表（从 CONTEXT「已锁技术决策」+ 代码扫描提取）
5. 跨模块契约（按需）
6. 扩展点 + 容量边界（推荐但非必填）

**与 A-evolve 的边界**：A-architect 是全库重建（大动作），A-evolve 是增量同步（每次 change 后小补丁）。

---

<a id="sec-6-evolve"></a>
### A-evolve — 架构沉淀同步

**触发**：`/flow-go 同步架构` / `/flow-evolve`，或在阶段 7 归档后被提示。

**输入**：所有已归档 DESIGN.md 的 §9 段（架构沉淀建议）

**输出**：`.specs/evolve/<YYYY-MM-DD>-EVOLVE.md` + CONTEXT.md / ARCHITECTURE.md 的 patch

**步骤**：
1. 确定扫描范围（默认：上次 evolve 以来的所有已归档 change）
2. 抽取所有 §9 段
3. 聚合分类（新增抽象 / 项目级决策 / 跨模块契约 / 依赖变动 / 禁动清单变动）
4. 逐项 review（用户参与，冲突项必须显式问）
5. 生成 patch（CONTEXT.md 必生，ARCHITECTURE.md 仅当存在时生）
6. 用户选 1（全收）/ 3（挑拣）/ 4（拒绝）
7. 写入 + 更新 STATE

---

<a id="sec-6-restyle"></a>
### L-restyle — 视觉重构

**触发**：`/flow-go 换风格` / `/flow-restyle`

**适用**：组件库迁移、品牌升级、统一设计语言
**不适用**：改功能行为、改交互流程

**关键步骤**：
1. 自动生成 change-id（格式：`restyle-<target-tone>`）
2. 识别现有调性（v1）：从 CSS variables / theme 文件反向提取
3. 调性切换确认（展示目标调性卡片）
4. 影响面扫描（列出所有被改组件 + token 影响范围）
5. 写新 UI-DESIGN.md（标 v2，含 v1→v2 视觉对照表）
6. 拆 restyle 任务（按"token 先于组件"顺序）
7. 显式风险声明（必须输出，不允许跳过）

---

<a id="sec-7-stop-hook"></a>
## 7. Stop Hook 系统

Stop Hook 在每次 Claude Code 会话结束时自动运行，包含 15 个模块化脚本，外加一个 PreToolUse hook 用于硬拦截：

### Hook 模块列表

| 编号 | 脚本 | 模块 | 检查项 |
|------|------|------|--------|
| 00 | `00-gate.sh` | 入口门禁 | 检查是否适合运行 hook |
| 01 | `01-transcript-parse.sh` | 转录解析 | 解析会话转录 |
| 20 | `20-claude-md.sh` | CLAUDE.md | A1 过时 / A2 缺失 / A3 内容质量 / A6 文件膨胀 |
| 21 | `21-memory.sh` | Memory | B1 死记忆 / B2 冲突 / B4 记忆与代码不一致 |
| 22 | `22-git.sh` | Git | C1 未跟踪文件 / C2 分支偏离 / C3 大文件 / C4 未推送提交 |
| 23 | `23-quality.sh` | 质量 | D1 测试失败 / D2 lint 警告 / D3 类型错误 / D4 覆盖率下降 |
| 24 | `24-session.sh` | 会话 | E1 清窗次数 / E2 任务完成率 / E3 中断频率 / E4 上下文利用率 / E5 工具分布 |
| 25 | `25-project.sh` | 项目 | F1 SPEC 过期 / F2 死文件 / F3 依赖过期 / F4 重复配置 / F5 文档缺口 |
| 26 | `26-workflow.sh` | 工作流 | G1 阶段门禁 / G2 产物完整性 / G3 未完成 task / G4 审查 backlog / G5 checkpoint 断层 |
| 27 | `27-interactive-ui-check.sh` | 交互 UI 检测 | I1 检测弱模型跳过 AskUserQuestion/EnterPlanMode 交互 gate → 写入矫正文件 |
| 28 | `28-weak-model-compliance.sh` | 弱模型合规 | W1 L1 规则合规（禁动清单+通用规则）/ W2 L2 自检完整性 / W3 L3 证据链真实性 → 写入统一矫正文件 |
| 29 | `29-independent-review.sh` | 独立审查 (L3) | IR 调外部模型（deepseek-v4-flash）盲审阶段 1/2/6 产物，写 .flow-active.independent-review 握手 + INDEPENDENT-REVIEW-N.md |
| 30 | `30-ai-analyze.sh` | AI 分析 | 将结构化数据提交给 AI 做深度分析（默认模型: deepseek-v4-flash） |
| 99 | `99-report.sh` | 报告 | 生成 stop-hook-report.md + stop-hook-suggestions.md |

### PreToolUse Hook（独立 Review Gate）

| 脚本 | 触发条件 | 行为 |
|------|---------|------|
| `pre-tool-use/independent-review-gate.sh` | matcher: `Bash`，当前阶段 1/2/6 且 gate 开启且 `.independent-review-<phase>.done` 不存在 | 拦截 `git commit` / `gh pr create` / 改阶段的 jq，`exit 2` deny + stderr 提示。done 存在则放行。fail-open 原则（不确定就放行） |

### SessionStart Hook

- `flow-kit-resume.sh`：检测 `.flow-active` 中的中断信息，提醒用户恢复；检测 `.flow-active.interactive-ui-fix` 和 `.flow-active.correction` 矫正文件，注入交互 UI / 合规矫正 banner 后自动清除
- `stop-report-reminder.sh`：提醒用户查看上次会话的 stop hook 报告

### 配置文件

`stop-hook.json` 控制各模块的启用/禁用、检查项、AI 分析频率（默认每 5 次会话）、各阈值和输出路径。自 v2026-07 起新增 `independent_review` 和 `pre_tool_use_gates` 两块配置：

- `independent_review.phases`: 项目级默认开启独立 review 的阶段列表（如 `["6-review"]`），非 pipeline 项目用此兜底
- `independent_review.model`: L3 调用的外部模型（默认 `deepseek-v4-flash`）
- `independent_review.max_failures_before_bypass`: L3 连续失败多少次后允许手动绕过（默认 3）
- `pre_tool_use_gates.independent_review.enabled`: 是否启用 PreToolUse 硬拦截（默认 true）

### 独立 Review 机制（L2 盲审 + L3 hook 强制）

> **默认关闭**——用户通过 `/flow gate-config` 显式开启某阶段才跑，避免每个 change 付 token 成本。

独立 review 为主 agent 的 self-review 提供**第二意见**，解决证实偏差和 sycophancy。覆盖三个阶段：

- **阶段 1（需求）**: L2 盲审 REQUIREMENT.md 的 AC 可验证性和范围切分；L3 用外部模型独立审
- **阶段 2（设计）**: L2 盲审 DESIGN.md 的 ADR 合理性和架构对齐；L3 独立审
- **阶段 6（代码审查）**: L2 盲审 git diff 的 spec 合规和 6 维衰退风险；L3 独立审

**L2（子 agent 盲审）**: 主 agent 用 Agent tool 派固化盲审子 agent（`qa-expert` / `architect-reviewer` / `code-reviewer`），prompt 原样注入 `L2-blind-review.md` 固化模板，**禁喂主 agent 自评/草稿**。子 agent 产四要素报告（Symptom/Source/Consequence/Remedy + 🔴🟡🟢）写入 `INDEPENDENT-REVIEW-<phase>.md` 的 L2 段。

**L3（hook 强制 · 三道防线）**: 
1. **PreToolUse 硬拦截**: 主 agent 尝试 git commit / gh pr / 切阶段时，若本阶段独立 review 未完成（无 `.independent-review-<phase>.done`），`exit 2` deny
2. **fk_auto_phase gate**: 阻断 Stop hook 内部自动推进（`fk_auto_phase` 返回空）
3. **pipeline auto_advance=false**: pipeline 模式强制需人工确认

L3 的外部模型审查由 Stop 模块 `29-independent-review.sh` 自动完成，用户无需手动调度。审查结果写入 `INDEPENDENT-REVIEW-<phase>.md` 的 L3 段 + `.flow-active.independent-review` 握手文件，SessionStart 自动注入摘要。

**done 标志**: L2 + L3 都完成后，主 agent 执行 `touch .specs/<id>/.independent-review-<phase>.done`，三道防线全部放行。

**降级兜底**: L3 调用连续失败 ≥ 3 次 → Stop 报告提示"允许手动绕过"，可手动 touch done 继续，不卡死流水线。

---

<a id="sec-8-brooks-lint"></a>
## 8. brooks-lint 代码审查插件

brooks-lint 提供 6 个独立的代码审查 skill，基于 12 本经典软件工程书籍。

| Skill | 用途 | 触发场景 |
|-------|------|---------|
| `/brooks-review` | PR 代码审查 | 审查 diff，发现衰退风险和设计坏味 |
| `/brooks-audit` | 架构审计 | 模块依赖图、分层完整性、循环依赖 |
| `/brooks-debt` | 技术债评估 | 分类+优先级排序，构建重构路线图 |
| `/brooks-test` | 测试质量审查 | 诊断脆性测试、mock 滥用、覆盖率幻觉 |
| `/brooks-health` | 代码库健康仪表盘 | 四维综合评分（PR/架构/技术债/测试） |
| `/brooks-sweep` | 全库清扫 | 全维分析 + 自动修复（安全变更自动应用，风险变更确认后执行） |

### 输出格式（flow-kit 下游认的标准格式）

```
### 🔴/🟡/🟢 R<x> · <风险名>：<一句话结论>
**Symptom（症状）**：<在哪个文件:行号发现的具体问题>
**Source（源头）**：<哪本书哪一节提出这个原则>
**Consequence（后果）**：<不修会怎么样，未来多久会爆>
**Remedy（修补）**：<具体怎么改，贴 before/after 代码>
```

### 8.1 brooks-tools 离线打包

brooks-lint 依赖 4 个外部 npm 工具，统称 **brooks-tools**：

| 工具 | 用途 | npm 包 |
|------|------|--------|
| `depcheck` | 未使用依赖检测 | `depcheck` |
| `jscpd` | 代码重复检测（copy-paste detector） | `jscpd` |
| `knip` | 未使用文件/导出检测 | `knip` |
| `ts-prune` | 未使用 TypeScript 导出检测 | `ts-prune` |

**为什么需要离线打包**：项目使用 pnpm 管理依赖，pnpm 的虚拟存储（content-addressable store + symlink）依赖符号链接，无法跨机迁移。因此 `package-flow-kit.sh` Part G 采用 `npm pack` 逐工具打包为 `.tgz`，解压出扁平 node_modules（所有依赖摊平在 `node_modules/` 顶层），在目标环境无需 pnpm 即可独立运行。

**安装行为**：
- `install.sh` 检测到 Node.js 可用时，自动解压 brooks-tools 到 `~/.claude/tools/brooks-lint/`
- 自动生成 shim（薄 wrapper 脚本），将 `~/.local/bin/` 映射到真实可执行文件
- 可通过 `--no-brooks-tools` flag 跳过此步骤

**当前限制**：仅打包 linux-x64 二进制。多平台矩阵（macOS arm64/x64、linux arm64）列为 v2。

---

<a id="sec-9-workflows"></a>
## 9. 常用工作流示例

### 9.1 新功能开发（完整流程）

```
步骤 0：初始化（仅首次，每个 change 一次）
  你：/flow start
  → 创建 .flow-active（phase=0），后续 checkpoint/phase/doctor 都依赖此文件

步骤 1：描述你想做什么
  你：/flow-go 我想给用户加一个通知中心，支持邮件和应用内通知
  → AI 自动：路由到阶段 0，生成 change-id（如 add-notification-center），
    输出路由声明 + Token 预算估算，写入 CHANGE.md
  → AI 反问：澄清 v1/v2/out 范围和视觉调性

步骤 2：细化需求
  你：/flow-go 把刚才的需求写详细
  → AI 路由到阶段 1，写出 REQUIREMENT.md（含 Given/When/Then AC）

步骤 3：技术设计
  你：/flow-go 做技术设计
  → AI 路由到阶段 2，技术栈预选卡片、既有架构对齐、ADR

步骤 4：UI 设计（如果是前端项目）
  你：/flow-go 确定 UI 设计
  → AI 路由到阶段 2a，美学方向决策、Design Tokens、组件规约

步骤 5：拆任务
  你：/flow-go 拆任务
  → AI 路由到阶段 3，生成 TASK.md（T1, T2, T3...）

步骤 6：逐个执行开发任务
  你：/flow-go 执行 T1
  → AI 路由到阶段 4，TDD 驱动开发 → SUMMARY.md
  你：/flow-go 执行 T2
  → ...继续下一个任务

步骤 7：测试
  你：/flow-go 开始测试
  → AI 路由到阶段 5，五轮测试金字塔 → TEST.md

步骤 8：审查
  你：/flow-go 审查代码
  → AI 路由到阶段 6，三轮审查 → REVIEW.md

步骤 9：集成上线
  你：/flow-go 集成上线
  → AI 路由到阶段 7，自动化验证 + UAT + 归档

步骤 10：收尾
  你：/flow stop
  你：/flow-go 同步架构     ← 建议：将本次架构沉淀同步到项目级文档
```

> **提示**：阶段 0→1→2→2a→3 可以在同一轮对话里连续做——每完成一个阶段，AI 会主动提示下一步，你只需回复"继续"即可。

### 9.2 压缩流程（小改动）

```
/flow start
/flow-go 修复登录页密码输入框无法粘贴的问题
→ AI 路由到阶段 0，生成 CHANGE.md
→ AI 判断改动很小，询问："这是小改动（< 50 行），是否跳过完整闭环直接修？"
→ 你选"直接修"：跳过阶段 1/2/3，进入阶段 4
→ 或者选"走闭环"：按完整流程走（阶段 0→1→3→4→5→6→7，可跳过 2/2a）
```

> GO.md 提供了「极简模式」和「单点调用」两种省 token 选项，AI 在路由声明中会列出。

### 9.3 老项目入场

```
# 首次在现有项目中使用 flow-kit
/flow-go 扫描代码
→ AI 路由到 I-intel：探测技术栈 → 提取既有抽象 → 生成 CONTEXT.md → 写 STATE.md
```

如果项目已有 CLAUDE.md / AGENTS.md 等 AI 上下文文档，AI 会反问是综合它们生成 CONTEXT.md 还是以现有文档为准。

### 9.4 中断恢复

```
# 会话被清窗或断开后重新开始
# SessionStart hook 自动检测 .flow-active 中的 interrupt 并显示横幅
你：/flow-go 继续
→ AI 从 interrupt checkpoint 恢复，加载上次的 active_file + last_action
→ 继续阶段 4（DEV）的 TDD 循环
```

### 9.5 查看状态和诊断

```
/flow                  # 查看当前状态（change-id / phase / task）
/flow doctor           # 诊断 hook 配置、产物完整性
/flow phase 3          # 手动跳转到指定阶段（需要纠偏时）
/flow stop             # 结束当前 change
```

### 9.6 单独使用 brooks-lint 审查

```
/brooks-review         # 审查当前 diff
/brooks-audit          # 架构审计
/brooks-health         # 全面健康检查
/brooks-sweep          # 全库清扫 + 自动修复
```

### 9.7 gate-config 门禁配置

`--gate-config` 接受 JSON，内含两类 key（详见 §4.1.2 Pipeline Goal 的表格）：

| Key 类型 | 键值格式 | 用途 | 有效值 |
|----------|---------|------|--------|
| 阶段名 | `1-requirement` / `2-design` / `6-review` | 开启独立 review（L2+L3） | `independent` / `true` / `off` / `false` |
| Transition | `N→N+1`（如 `4→5`） | 控制 toll-gate 门禁级别 | `critical` / `warn` / `ignore` |

#### 启用独立 Review

```
# 方式 A: 建 pipeline goal 时一次配齐三阶段
/flow goal "完成退款功能并上线" --pipeline --from 1 \
  --gate-config '{"1-requirement":"independent","2-design":"independent","6-review":"independent"}'

# 方式 B: 中途单独开启/关闭某阶段（无需重建 goal）
/flow gate-config 6-review=independent
/flow gate-config 2-design=off

# 方式 C: 非 pipeline 项目（项目级默认）
# 编辑 .claude/stop-hook.json → "independent_review": {"phases": ["6-review"]}
```

> 开启后进入该阶段 → AI 自动派 L2 盲审子 agent → Stop hook 自动跑 L3（外部模型）→ SessionStart 注入报告摘要 → 确认后写 done → 才能切阶段/commit。

#### 调整 Toll-Gate 门禁级别

```
# 将 4→5（DEV→TEST）的 gate 从默认 critical 降为 warn（提示但不阻断）
/flow goal "..." --pipeline --from 4 --gate-config '{"4→5":"warn"}'

# 跳过某个阶段的 gate（如 3→4 不设门禁）
/flow goal "..." --pipeline --from 0 --gate-config '{"3→4":"ignore"}'
```

> 默认所有 transition gate 为 `critical`（阻断 pipeline），可通过 transition key 降级。

---

<a id="sec-10-rules"></a>
## 10. RULES 规则速查

flow-kit 的核心规则（RULES.md）：

| 规则 | 名称 | 核心要求 |
|------|------|---------|
| R1 | 上下文与 Token | 用足上下文，阶段产物不重复加载，reference 禁止整读（只 grep 所需节），中断恢复用 checkpoint |
| R2 | 阶段门 | 每个阶段入口检查上游工件（Preflight Gate），缺失则回退补齐，不跳过门禁 |
| R3 | 角色红线 | 每个阶段只扮演指定角色（如 REVIEW 阶段只产报告不改代码） |
| R4 | 提交与产物 | 原子提交（1 task = 1 commit），产物写入 `.specs/<id>/`，DB 迁移生成可逆脚本 |
| R5 | 测试纪律 | TDD 默认开启（RED → GREEN → REFACTOR），不可跳过除非纯文档/配置任务 |
| R6 | 反幻觉 | 不确定就问，不猜测；grep 实际代码后再做判断；不凭空编造不存在的方法/API |
| R7 | 范围控制 | 严格按 CHANGE 的 v1/v2/out 范围执行，不擅自扩大 |
| R8 | 语言 | AI 用中文回复，技术术语保持原文 |

---

<a id="sec-11-file-structure"></a>
## 11. 文件结构索引

### 安装后的全局文件（`~/.claude/`）

```
~/.claude/
├── flow-kit/                    # 核心引擎
│   ├── GO.md                    # 统一入口 prompt
│   ├── RULES.md                 # 硬规则
│   ├── SYSTEM.md                # 永久注入版规则
│   ├── prompts/                 # 各阶段详细 prompt
│   │   ├── 0-change.md
│   │   ├── 1-requirement.md
│   │   ├── 2-design.md
│   │   ├── 2a-ui-design.md
│   │   ├── 3-task.md
│   │   ├── 4-dev.md
│   │   ├── 5-test.md
│   │   ├── 6-review.md
│   │   ├── 7-integration.md
│   │   ├── I-intel-scan.md
│   │   ├── M-health.md
│   │   ├── A-architect.md
│   │   ├── A-evolve.md
│   │   └── L-restyle.md
│   ├── reference/               # 参考文档（按需查表，禁止整读）
│   ├── templates/               # 产出模板
│   └── .flow-kit-version
├── skills/flow-*/               # flow-* 技能包装器（17 个）
│   ├── flow/SKILL.md            # /flow — 状态管理
│   ├── flow-go/SKILL.md         # /flow-go — 统一入口（自动路由）
│   ├── flow-change/SKILL.md
│   ├── flow-requirement/SKILL.md
│   ├── flow-design/SKILL.md
│   ├── flow-ui-design/SKILL.md
│   ├── flow-task/SKILL.md
│   ├── flow-dev/SKILL.md
│   ├── flow-test/SKILL.md
│   ├── flow-review/SKILL.md
│   ├── flow-integration/SKILL.md
│   ├── flow-intel/SKILL.md
│   ├── flow-health/SKILL.md
│   ├── flow-architect/SKILL.md
│   ├── flow-evolve/SKILL.md
│   ├── flow-restyle/SKILL.md
│   └── flow-kit-install/SKILL.md
└── plugins/.../brooks-lint/     # brooks-lint 插件
├── tools/brooks-lint/            # brooks-tools 离线工具（depcheck/jscpd/knip/ts-prune）
├── .local/bin/                   # brooks-tools shim wrapper（depcheck 等符号链接）
```

### 项目级文件

```
<project>/
├── .flow-active                 # 运行时工作流状态（JSON）
├── .specs/
│   ├── STATE.md                 # 跨会话项目状态
│   ├── CONTEXT.md               # 入场扫描产物（术语表 + 抽象索引）
│   ├── CHANGELOG.md             # change 历史
│   ├── LESSONS.md               # 经验教训与技术债
│   ├── health/                  # 健康检查报告
│   ├── archive/                 # 已归档 change 的副本
│   └── <change-id>/             # 单个 change 全部产物
│       ├── CHANGE.md
│       ├── REQUIREMENT.md
│       ├── DESIGN.md
│       ├── UI-DESIGN.md         # (UI 项目)
│       ├── TASK.md
│       ├── T1-SUMMARY.md
│       ├── T2-SUMMARY.md
│       ├── TEST.md
│       ├── REVIEW.md
│       └── ARCHIVE.md
├── ARCHITECTURE.md              # 项目级架构文档（A-architect 产出）
├── adr/                         # 架构决策记录
├── .claude/
│   ├── settings.json            # hook wiring
│   ├── stop-hook.json           # stop hook 配置
│   └── hooks/
│       ├── session-start/
│       │   ├── flow-kit-resume.sh
│       │   └── stop-report-reminder.sh
│       └── stop/
│           ├── 00-gate.sh
│           ├── 01-transcript-parse.sh
│           ├── 20-claude-md.sh
│           ├── 21-memory.sh
│           ├── 22-git.sh
│           ├── 23-quality.sh
│           ├── 24-session.sh
│           ├── 25-project.sh
│           ├── 26-workflow.sh
│           ├── 30-ai-analyze.sh
│           ├── 99-report.sh
│           └── lib/
│               ├── common.sh
│               ├── transcript-parser.sh
│               └── flow-kit-artifacts.sh
```

---

## 附录：Token 预算参考

flow-kit 对 token 成本透明。GO.md 要求 AI 在进入阶段前输出预算估算，并提供三个挡位：

| 你的诉求 | 选 |
|---|---|
| 全套产物（CHANGE + REQUIREMENT + DESIGN + UI-DESIGN + TASK + SUMMARY×N + TEST + REVIEW） | **完整** ~250k-530k |
| 核心产物，能少则少 | **极简** ~205k-445k（省 ~20%） |
| 只跑某一阶段 | **单点** 按需 |
| < 50 行代码 / 一次性修补 | **不走 flow-kit**，直接修 |

**成本影响因子**：前端项目 +20%，schema 变更 +5~10%，brooks-lint 已装 +10%，跨模型 spot-check +30%，task < 3 则 -30%。
