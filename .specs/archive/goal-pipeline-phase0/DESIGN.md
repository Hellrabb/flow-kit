# DESIGN: Pipeline Goal 扩展到 Phase 0 起始

- **Change ID**: goal-pipeline-phase0
- **关联**: `@.specs/goal-pipeline-phase0/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 Bash 脚本 + markdown prompt 工程（CLI/分发工具），非标准技术栈项目。跳过技术栈卡片展示。

- **选定**：沿用既有栈 — Bash + jq + markdown
- **语言/运行时**: Bash（`set -euo pipefail`）
- **状态管理**: `.flow-active` JSON（`jq` 读写）
- **测试**: bats-core 1.13.0（`npx bats`）
- **关键依赖**: `jq` ≥ 1.6（JSON 处理）、`date`（GNU coreutils）
- **理由**: 纯 CLI 工具项目，零外部依赖，与已有 flow-kit 架构一致。来自 CONTEXT.md 已锁决策。
- **明确排除**: 不引入 Python/Node.js 等运行时（过度工程，jq 足以处理 JSON schema 变更）

---

## 0.5 既有架构对齐（brownfield 必填 · 来自 2-design 步骤 0.5 / B2 老项目护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/分析出来的实际清单）：
- flow-kit-bundle/skills/flow/SKILL.md（既有 · /flow goal 子命令实现 · 188 行）
- flow-kit-bundle/flow-kit/GO.md（既有 · pipeline goal 路由逻辑 · ~360 行）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（既有 · pipeline goal 入场检测 + toll-gate 协议 · 641 行）

新增 pipeline 感知（在既有文件上追加段）：
- flow-kit-bundle/flow-kit/prompts/0-change.md（追加 pipeline toll-gate 段）
- flow-kit-bundle/flow-kit/prompts/1-requirement.md（追加 pipeline toll-gate 段）
- flow-kit-bundle/flow-kit/prompts/2-design.md（追加 pipeline toll-gate 段）
- flow-kit-bundle/flow-kit/prompts/3-task.md（追加 pipeline toll-gate 段）

运行时副本（install.sh 同步）：
- ~/.claude/skills/flow/SKILL.md
- ~/.claude/flow-kit/GO.md
- ~/.claude/flow-kit/prompts/{0,1,2,3,4}-*.md

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/install.sh（安装脚本核心逻辑，与 goal pipeline 无关）
- flow-kit-bundle/lib/*（安装子模块，本次不改）
- flow-kit-bundle/hooks/*（Stop/SessionStart hooks，与 pipeline 起始阶段无关）
- .specs/CONTEXT.md 中"禁动清单"节（已在本 change 术语更新中仅追加术语，未改禁动逻辑）
- package-flow-kit.sh（打包脚本，本次不改）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| `.flow-active` JSON 读写 | `jq` + 临时文件 + `mv` 原子写 | 沿用（与现有 `/flow` skill 完全一致） |
| goal 字段结构 | `.flow-active.goal` object（8 字段） | 沿用并扩展（+1 字段 `start_phase`） |
| pipeline gates 管理 | `goal.gates` object，key 为 `"4→5"` 格式 | 沿用格式，动态生成 keys |
| toll-gate 暂停协议 | 4-dev.md 步骤 6 的 toll-gate 输出 + jq 更新 `current_phase`/`phases_done`/`gates` | 沿用协议，0-3 阶段复用相同格式 |
| condition 评估 | 当前仅简单字符串匹配（无结构化 evaluator） | 沿用简单模型，扩展为 AND 拆分 |
| phase 路由 | GO.md 路由表匹配关键词 | 沿用，新增 pipeline goal 进场时读 `start_phase` 字段 |
| `/flow goal` 子命令解析 | SKILL.md 中的 bash + jq 实现 | 沿用，新增 `--from` flag 解析 |
| 错误处理 | `set -euo pipefail` + jq 校验 | 沿用 |

### 0.5.3 沿用模式 vs 引入新模式

```
- JSON 状态管理：**沿用** jq + 临时文件 + mv 原子写入（与现有 /flow skill 100% 一致）
- Pipeline toll-gate 协议：**沿用** 4-dev.md 的 toll-gate 输出格式 + jq 状态更新
- 路由分发：**沿用** GO.md 的意图匹配表 + Artifact Preflight Gate
- Phase prompt 结构：**沿用**「角色 → 输入 → 职责 → 输出 → 约束 → 自检 → 触发下一步」7 段式
- Condition 语法：**引入新模式** AND 拆分评估（既有无结构化 condition 解析）→ 理由：需要支持跨阶段复合条件，但保持简单（仅 AND，v2 扩展 OR/NOT）
- 动态 gates 生成：**引入新模式**（既有 gates 为固定 `{"4→5":...,"5→6":...,"6→7":...}`）→ 理由：start_phase 可变导致 gates keys 动态
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | `--from <n>` 参数名 | `--start-phase` / `--begin` | `--from` 短且直观，与 Unix 惯例一致（`cut --from`、`git log --from`） | 语义精确性略低于 `--start-phase`，但上下文明确（pipeline goal 的起点） |
| D2 | gates 动态生成策略 | A) 始终生成 0→7 全量 gates，跳过的标 `skipped` / B) 仅生成 `start_phase` 到 7 的 gates | 选 B：状态更干净，`/flow goal` 输出不显示无关 gates | 旧 pipeline goal 回读时，无 `start_phase` 字段需 fallback 默认 "4"；gates keys 缺失时需容错 |
| D3 | 0-3 阶段 toll-gate 模板 | A) 与 4-7 完全一致 / B) 每阶段定制 toll-gate 提示语 | 选 A：统一模板减少维护成本；各阶段 prompt 的「触发下一步」段已提供阶段特有上下文 | phase 0 的 toll-gate 上下文（"CHANGE.md 已确认"）vs phase 4（"所有 task 完成"）语义不同，但模板统一，细节由阶段 prompt 补充 |
| D4 | 跨阶段 condition 语法 | A) `AND` 拆分 + 简单字符串匹配 / B) 完整布尔表达式解析器（AND/OR/NOT/括号） | 选 A：满足 v1 需求（CHANGE.md confirmed AND tests pass），简单可靠；B 留给 v2 | 不能表达 "A OR B"（如"测试通过 OR review 通过"），但现阶段 80% 使用场景仅需 AND |
| D5 | 旧 pipeline goal 回读兼容 | A) 读时检测缺失字段 + 隐式填充默认值 / B) 写迁移脚本批量更新所有 `.flow-active` | 选 A：非破坏性，零用户感知；`start_phase` 缺失 → 默认 "4" | jq 读取处需加 `// "4"` fallback，略增复杂度但可控 |
| D6 | `start_phase` 有效值范围 | A) 0-7 / B) 0-7 但 0-3 需要额外 flag 确认 | 选 A：不额外设限，`--from 0` 直接可用。0-3 人工决策密集由 toll-gate 解决 | 用户可能误设 `--from 0` 但实际只想跑 4-7，但 toll-gate 在每个阶段都会暂停确认，不会自动冲过去 |
| D7 | condition 子条件评估时机 | A) 仅 pipeline 终点评估 / B) 每阶段完成后分步评估，提前报告部分满足 | 选 B：跨阶段 condition 在每阶段完成后评估子条件，输出 "✅ CHANGE.md confirmed ｜ ⏳ all tests pass"，给用户进度感 | 评估器需要知道各阶段对应的子条件映射，增加约 15 行 jq 逻辑 |

---

## 2. 数据流 / 架构图

### 2.1 Pipeline Goal 生命周期（扩展后）

```
用户: /flow goal "CHANGE confirmed AND all tests pass" --pipeline --from 0
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│  /flow goal skill (SKILL.md)                                     │
│  解析 --from 0 → 校验有效值 → 动态生成 gates                     │
│  写入 .flow-active.goal:                                         │
│    start_phase: "0", current_phase: "0"                          │
│    gates: { "0→1":"pending", "1→2":"pending", ..., "6→7":"pending" } │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│  GO.md 路由层                                                    │
│  检测 goal.scope = "pipeline" 且 current_phase = "0"             │
│  → 路由到 0-change.md prompt + 注入 pipeline 横幅               │
│                                                                  │
│  🚀 Pipeline: 0🔄 → 1⏸ → 2⏸ → 3⏸ → 4⏸ → 5⏸ → 6⏸ → 7⏸         │
│  📋 Condition: CHANGE confirmed AND all tests pass               │
│  ⏳ 子条件: [⏳ CHANGE confirmed] [⏳ all tests pass]              │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│  Phase 0 (0-change.md)                                           │
│  执行: 反问 → 生成 CHANGE.md → 用户确认                          │
│  阶段完成 → toll-gate 暂停:                                      │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ 🛑 Toll-gate: Phase 0 → Phase 1                            │  │
│  │    ✅ 子条件 "CHANGE confirmed" → 已满足                    │  │
│  │    产物: CHANGE.md ✓                                        │  │
│  │                                                             │  │
│  │    是否进入 Phase 1 (需求分析)？                             │  │
│  │    1. 继续 → 下一阶段    2. 暂停    3. 跳过需求直接设计     │  │
│  └────────────────────────────────────────────────────────────┘  │
│  用户选 1 → jq 更新 current_phase="1", phases_done+=["0"]       │
│           → 加载 1-requirement.md prompt                         │
└──────────────────────────────────────────────────────────────────┘
  │
  ▼
  ... (Phase 1-3 同理，每阶段 toll-gate 暂停) ...
  │
  ▼
┌──────────────────────────────────────────────────────────────────┐
│  Phase 7 (7-integration.md)                                      │
│  全部阶段完成 → 最终评估:                                        │
│    ✅ CHANGE confirmed → true                                    │
│    ✅ all tests pass → true                                      │
│    → Condition SATISFIED → pipeline 结束                        │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 `.flow-active.goal` Schema 变更

```diff
{
  "condition": "CHANGE confirmed AND all tests pass",
  "status": "active",
  "active_since": "2026-06-20T...",
  "turns": 0,
  "mode": "pending",
  "scope": "pipeline",
+ "start_phase": "0",          // 新增：pipeline 起始阶段（默认 "4"）
  "current_phase": "0",        // 行为不变，初始值现在 = start_phase
  "phases_done": [],
- "gates": {                   // gates keys 动态生成
-   "4→5": "pending",          // 旧固定 keys（start_phase=4 时）
-   "5→6": "pending",
-   "6→7": "pending"
- },
+ "gates": {                   // 动态 keys（start_phase=0 时）
+   "0→1": "pending",
+   "1→2": "pending",
+   ...
+   "6→7": "pending"
+ },
  "gate_config": {},
  "auto_advance": false,
  "phase_sub_goals": {}
}
```

### 2.3 Condition 评估器流程

```
condition = "CHANGE confirmed AND all tests pass"
                 │
                 ▼
        split(" AND ") → ["CHANGE confirmed", "all tests pass"]
                 │
                 ▼
        ┌────────────────────────────────────┐
        │  子条件 → 阶段映射（design-time）   │
        │  "CHANGE confirmed" → phase 0     │
        │  "all tests pass"    → phase 5    │
        └────────────────────────────────────┘
                 │
                 ▼
    每阶段完成后评估:
      for each 子条件:
        if 对应阶段 in phases_done → ✅
        elif 对应阶段 == current_phase 且刚完成 → 检查
        else → ⏳
                 │
                 ▼
    所有子条件 ✅ → Condition SATISFIED → pipeline 结束
```

---

## 3. 关键状态机（condition 子条件评估）

```
状态: ⏳ pending → 🔄 evaluating → ✅ satisfied / ❌ failed

Phase N 完成
  │
  ▼
提取本阶段对应的子条件（如有）
  │
  ├── 无对应子条件 → 跳过评估，直接 toll-gate
  │
  └── 有对应子条件
        │
        ▼
      评估子条件
        │
        ├── 满足 → 标记 ✅，检查是否全部 ✅ → 是 → pipeline 完成
        │
        └── 不满足 → 标记 ❌，toll-gate 中提示"条件 X 未满足"
                      用户可选: 重试本阶段 / 跳过条件 / 放弃
```

---

## 4. ADR 索引

本 change 不引入新的不可逆架构决策。核心决策 D1-D7 已记录在 § 1 决策清单，均为可逆（改参数名、改 gates 格式均可后续调整）。

> 已锁决策延续：CONTEXT.md 中「pipeline goal 边界决策」将被本 change 更新（边界从 "4→7" 扩展到 "可配置 0→7"），但这是 scope 扩展而非推翻原决策。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | 旧 pipeline goal 状态（无 `start_phase`）在新 code path 中抛 jq 错误 | 用户看到 broken pipeline，无法恢复 | 低 | 所有 jq 读 `start_phase` 处加 `// "4"` fallback；AC-7 覆盖此场景 |
| R2 | 0-3 阶段 prompt 加入 pipeline toll-gate 后，非 pipeline 用户感到多余输出 | 信息噪音，干扰非 pipeline 用户 | 中 | toll-gate 段用条件包裹：仅当 `.flow-active.goal.scope = "pipeline"` 且 `current_phase` 匹配时才展示 |
| R3 | `--from` 参数解析与 `--pipeline` / `--gate-config` 组合爆炸 | 边界 case（如 `--from 0 --gate-config '{...}'` 中 gate keys 与 start_phase 冲突） | 低 | 校验：gate_config keys 必须在动态 gates keys 集合内，否则报错提示修正 |
| R4 | 跨阶段 condition 子条件与阶段的映射歧义 | condition 写了 "tests pass" 但无法确定对应 phase 5 还是 phase N | 中 | v1 不做自动映射——condition 中每个子条件由用户在 DESIGN 阶段显式标注对应阶段；若用户未标注则视为"最终条件"（仅 pipeline 结束时评估） |
| R5 | 实现复杂度导致 flow skill SKILL.md 膨胀 | 188 行 → ~280 行，可维护性下降 | 中 | 核心逻辑集中在新增的 `generate_gates()` 和 `evaluate_sub_conditions()` 两个函数段；用注释隔离 |

---

## 6. 不在范围

- **condition 语法自动解析**：v1 不做 "tests pass" → phase 5 的自动映射，用户需在 condition 中显式写清楚（如 "phase 5 tests pass"），或由 AI 在设定 goal 时建议映射
- **pipeline 断点恢复**：如果 pipeline 在 phase 2 中断（会话结束），下次恢复时能否自动从 phase 2 继续？属于 GO.md R1.5 恢复协议范畴，不在本次 scope
- **pipeline 可视化增强**：ASCII 进度条、颜色标记等属于 v2
- **非线性和并行阶段**：2a-ui-design 在 pipeline 中的位置（何时触发？是否并行？）不在本次 scope。当前 pipeline 默认跳过 2a（非前端项目），前端项目 pipeline 行为留待后续设计

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT 「既有抽象索引」段）

本 change 不新增独立的 `lib/` 或 `utils/` 文件。核心逻辑内联在 `/flow` skill 中（jq + bash），但以下模式有复用价值：

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/skills/flow/SKILL.md` 中的 `generate_gates()` 逻辑 | 根据 start_phase 动态生成 pipeline gates | 任何需要「动态阶段链 + 门禁」的 pipeline 类 feature | 未来若扩展更多 pipeline 类型（如 health pipeline / deploy pipeline），可提取为 `flow-kit-bundle/flow-kit/lib/pipeline-gates.jq` |
| `flow-kit-bundle/flow-kit/GO.md` 中的 condition 子条件评估逻辑 | AND 拆分 + 阶段映射 + 分步评估 | 其他需要复合条件评估的 flow-kit 功能 | 若 condition 语法在 v2 复杂化（OR/NOT），建议提取为独立 evaluator |

### 9.2 新增 / 改变的项目级技术决策（建议 append 到 CONTEXT「已锁技术决策」段 · 或将来升 ARCHITECTURE.md「ADR 列表」）

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| pipeline goal 起始阶段 | 可配置（`--from 0-7`），默认 "4" | 所有使用 pipeline goal 的 change | 低 — 参数名和默认值均可后续调整 |
| 跨阶段 condition 语法 | v1: `AND` 拆分 + 字符串匹配；v2: 扩展 OR/NOT | pipeline goal condition 评估 | 低 — 向后兼容，扩展是加法 |
| 0-3 阶段 toll-gate 协议 | 与 4-7 统一模板 + 阶段 prompt 上下文补充 | 0-change / 1-requirement / 2-design / 3-task prompts | 低 — 模板可调整 |

### 9.3 新增 / 修改的跨模块契约（API / Schema / 事件总线）

```
- .flow-active.goal 新增字段 start_phase（string, "0"-"7", 默认 "4"）— 向后兼容（缺失 → "4"）
- /flow goal --pipeline 新增可选 flag --from <n> — 不传时行为不变
- pipeline gates keys 从固定变为动态（"N→N+1" 格式不变，但 keys 集合取决于 start_phase）
```

### 9.4 新增 / 升级的依赖

无。本 change 不引入新依赖。继续仅依赖 `bash` + `jq` + `date`（GNU coreutils）。

### 9.5 禁动清单变化

```
- 新增禁动：无（本 change 不引入新的高风险模块）
- 解禁：CONTEXT.md 中"pipeline goal 边界决策"锁定可降级为软约束（start_phase 可配置后，边界不再是硬性的"仅 4-7"）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
