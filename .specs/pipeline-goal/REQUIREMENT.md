# REQUIREMENT: Goal 从单阶段自循环扩展到跨阶段 Pipeline

- **Change ID**: pipeline-goal
- **关联**: `@.specs/pipeline-goal/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为开发者，我想设定一个 pipeline goal（如 "feature X 从实现到上线"），以便 AI 自主推进 4→5→6→7 整个执行链，只在关键节点暂停等待我确认。
- **US-2**：作为开发者，我想在关键门禁失败时（如 6-review 发现 Critical 问题）pipeline 自动暂停，以便我保持对质量的最终控制。
- **US-3**：作为开发者，我想现有的 phase-4 单阶段 goal 完全不受影响，以便已有工作流不被破坏。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 设定 Pipeline Goal

- **Given** `.flow-active` 存在且 `phase` 为 `"4"`（准备进入 dev），CC 版本 ≥ 2.1.139
- **When** 用户执行 `/flow goal "pnpm test passes and lint is clean" --pipeline`
- **Then** `.flow-active.goal` 包含：
  - `condition`: `"pnpm test passes and lint is clean"`
  - `scope`: `"pipeline"`
  - `status`: `"active"`
  - `current_phase`: `"4"`
  - `phases_done`: `[]`
  - `gates`: `{"4→5": "pending", "5→6": "pending", "6→7": "pending"}`
  - `mode`: `"native"`（或 `"fallback"` 当 CC < 2.1.139）
- **验证方式**: `jq -r '.goal.scope' .flow-active` 输出 `"pipeline"`

### AC-2 · 4→5 Toll-gate 暂停

- **Given** Pipeline goal 激活，`current_phase = "4"`，TASK.md 中所有 task 标记 done，所有 `*-SUMMARY.md` 的 verify 通过
- **When** AI 完成 phase 4 最后一个 task
- **Then** AI 输出 toll-gate 提示：
  ```
  🚦 Toll-gate 4→5：所有 dev task 已完成。
  是否进入测试阶段（5-test）？
    1. 继续 → 进入 5-test
    2. 暂停 → 保留当前状态，稍后恢复
    3. 跳过测试 → 直接进入 6-review（不推荐）
  ```
  并等待用户回复，不自动继续。
- **验证方式**: 人工验收 — 完成所有 task 后观察 AI 是否暂停并等待确认

### AC-3 · 5→6 Toll-gate 暂停

- **Given** Pipeline goal 激活，`current_phase = "5"`，TEST.md 已生成，所有测试轮次通过
- **When** AI 完成 5-test
- **Then** AI 输出 toll-gate 提示（同 AC-2 格式，阶段改为 5→6），等待用户确认后才进入 6-review
- **验证方式**: 人工验收 — 测试完成后观察 AI 是否暂停

### AC-4 · 6→7 Toll-gate 暂停

- **Given** Pipeline goal 激活，`current_phase = "6"`，REVIEW.md 已生成，无 🔴 Critical 问题
- **When** AI 完成 6-review
- **Then** AI 输出 toll-gate 提示（同 AC-2 格式，阶段改为 6→7），等待用户确认后才进入 7-integration
- **验证方式**: 人工验收 — review 完成后观察 AI 是否暂停

### AC-5 · 关键门禁失败暂停 Pipeline

- **Given** Pipeline goal 激活，`current_phase = "6"`，brooks-review 发现 ≥ 1 个 🔴 Critical
- **When** AI 运行 6-review 自查
- **Then** AI 输出：
  ```
  ⛔ Pipeline 暂停：6-review 检测到 1 个 Critical 问题
    - [Critical] src/foo.ts:34 — <问题描述>
  
  请选择：
    1. 修复后继续（我会回到 4-dev 处理该问题）
    2. 接受风险继续（Critical 降级为 Known，继续 6→7）
    3. 放弃本次 pipeline（goal.status = "aborted"）
  ```
  等待用户回复，不自动继续。
- **验证方式**: 人工验收 — 模拟 review 发现 Critical 时观察 AI 行为

### AC-6 · 向后兼容（单阶段 Goal 不受影响）

- **Given** `.flow-active.goal` 的 `scope` 为 `"phase"` 或字段不存在（旧格式）
- **When** AI 进入 4-dev
- **Then** 行为与现有 phase-4 单阶段 goal 完全一致：
  - Native 模式走 CC `/goal`
  - Fallback 模式走内置循环（每 turn 自检，最多 20 turns）
  - 不触发 toll-gate、不自动切换 phase
- **验证方式**: `jq -r '.goal.scope // "phase"' .flow-active` 输出 `"phase"`；进入 4-dev 后观察无 toll-gate 行为

### AC-7 · Pipeline 状态跨会话恢复

- **Given** Pipeline goal 激活，`phases_done = ["4", "5"]`，`current_phase = "6"`，然后会话因 compaction 中断
- **When** 新会话启动，SessionStart hook 检测到 `.flow-active.interrupt` 非空（含 `active_file` + `last_action` + `checkpoint_at`），AI 读回 `.flow-active.goal`
- **Then** AI 识别当前为 pipeline goal + `current_phase = "6"`，从 6-review 入场恢复点继续，而非从 phase 0 重新开始
- **验证方式**: 人工验收 — 中断后重启观察 AI 是否从 phase 6 继续

### AC-8 · Pipeline 完成

- **Given** Pipeline goal 激活，`phases_done = ["4", "5", "6"]`，`current_phase = "7"`
- **When** 7-integration 完成（CHANGELOG 更新 + archive 目录完整 + git tag 已打）
- **Then** AI 输出：
  ```
  🎯 Pipeline Goal 完成：pnpm test passes and lint is clean
     经过阶段：4 → 5 → 6 → 7
     总 turns：12
     设定于：2026-06-18T15:00:00+08:00
  ```
  且 `.flow-active.goal.status` = `"done"`，`.flow-active.goal.phases_done` = `["4", "5", "6", "7"]`
- **验证方式**: `jq -r '.goal.status' .flow-active` 输出 `"done"`；`jq -r '.goal.phases_done | length' .flow-active` 输出 `4`

### AC-9 · 动态门禁配置

- **Given** Pipeline goal 激活，用户想在 6-review 阶段将特定检查降级为 warning（不阻塞 pipeline）
- **When** 用户设定 goal 时附加门禁配置：`/flow goal "feature X shipped" --pipeline --gate-config '{"6-review": {"lint-warnings": "warn", "perf-regression": "critical"}}'`
- **Then** `.flow-active.goal.gate_config` 包含用户自定义的门禁映射；6-review 执行时，`lint-warnings` 不阻塞 pipeline（仅记录），`perf-regression` 仍为 hard stop
- **验证方式**: `jq -r '.goal.gate_config["6-review"].perf-regression' .flow-active` 输出 `"critical"`；未配置的检查使用默认门禁级别

### AC-10 · Phase 回退

- **Given** Pipeline goal 激活，`current_phase = "6"`，6-review 发现需要回 4-dev 修复 bug
- **When** 用户在 toll-gate 暂停点选择"回退到 4-dev 修复"
- **Then** `.flow-active.goal.current_phase` 更新为 `"4"`；`.flow-active.goal.phases_done` 中移除 `"5"` 和 `"6"`（因为需要重新测试和 review）；AI 重新加载 4-dev prompt，从 TASK.md 中定位需修复的 task
- **验证方式**: `jq -r '.goal.current_phase' .flow-active` 输出 `"4"`；`jq -r '.goal.phases_done' .flow-active` 不含 `"5"` 和 `"6"`

### AC-11 · Toll-gate 批量确认

- **Given** Pipeline goal 激活，`current_phase = "4"`，用户信任后续流程
- **When** 用户在第一个 toll-gate（4→5）选择"全自动推进，只在门禁失败时停"
- **Then** `.flow-active.goal.auto_advance` 设为 `true`；后续 5→6 和 6→7 的 toll-gate 不再暂停，AI 自动推进。但如果任何门禁失败（AC-5），pipeline 仍然暂停等待用户决策
- **验证方式**: `jq -r '.goal.auto_advance' .flow-active` 输出 `"true"`；5-test 完成后观察 AI 是否自动进入 6-review 而不暂停

### AC-12 · 各阶段 Sub-goal 自动提取

- **Given** REQUIREMENT.md 中有多条 AC，每条含 Given/When/Then
- **When** 用户设定 pipeline goal 时未手动指定各阶段 sub-goal
- **Then** AI 自动从 REQUIREMENT.md 提取并建议各阶段条件：
  - 4-dev：提取所有 AC 的 Then 条件拼接（如 "AC-1~AC-8 全部满足"）
  - 5-test：提取 AC 中涉及测试覆盖率的条件
  - 6-review：提取 AC 中涉及代码质量的 non-functional 条件
  - 7-integration：提取 AC 中涉及部署/归档的条件
  建议文本在 goal 设定时展示，用户可确认或修改。
- **验证方式**: 人工验收 — 设定 pipeline goal 后观察 AI 是否输出各阶段 sub-goal 建议

---

## 范围切分

### v1（本次必做 · 已合并原 v2）

- `.flow-active` schema 扩展：`goal` 新增 `scope` / `current_phase` / `phases_done` / `gates` / `gate_config` / `auto_advance` / `phase_sub_goals` 字段
- `/flow goal` CLI 扩展：`--pipeline` flag + `--gate-config` 可选参数
- `GO.md` 第四步：pipeline goal 注入路由声明（含 `auto_advance` / `current_phase` / gate 状态展示）
- `4-dev.md`：入场检测 pipeline goal + phase transition 逻辑（4→5）+ toll-gate 批量确认入口
- `5-test.md`：入场检测 pipeline goal + toll-gate 暂停/自动推进 + phase transition 逻辑（5→6）
- `6-review.md`：入场检测 pipeline goal + 动态门禁判定 + 门禁失败暂停 + phase 回退入口 + phase transition 逻辑（6→7）
- `7-integration.md`：入场检测 pipeline goal + pipeline 完成标记
- **Phase 回退机制**：用户可在任何 toll-gate 选择回退到 4-dev 修复，`phases_done` 清除回退阶段
- **Toll-gate 批量确认**：用户在首个 toll-gate 可选择"全自动推进，只在门禁失败时停"
- **动态门禁配置**：用户可自定义每个阶段各检查项的级别（critical/warn/ignore）
- **Sub-goal 自动提取**：从 REQUIREMENT.md 的 AC 自动生成各阶段 sub-goal 条件建议
- 向后兼容：单阶段 goal（`scope: "phase"` 或无 scope 字段）行为不变

### out（永远不做）

- **覆盖 0-3 阶段**：0-change / 1-requirement / 2-design / 2a-ui-design / 3-task 阶段的核心工作靠人的判断力（反问澄清、技术选型、美学决策），不适合自动化 pipeline
- **全自动模式（无 toll-gate）**：人不参与决策的 pipeline 会在错误方向上狂奔——toll-gate 是安全底线，不可移除
- **跨 change pipeline**：一个 goal 跨越多个 change（如 "完成所有 tech-debt 修复" 涉及多个独立 change-id）。这是 project-level 的编排能力，不是单个 change 的 pipeline

---

## 非功能性需求

- **性能**: 无（纯流程编排，不涉及计算/IO 密集操作）
- **可访问性**: 无（非 UI 项目）
- **安全**: 无
- **兼容性**: 向后兼容现有 `.flow-active` 格式（无 `scope` 字段的旧 goal 视为 `scope: "phase"`）；向前兼容未来 CC 原生 `/goal` 功能演进
- **可观测性**: pipeline 每次 phase transition 写入 `.flow-active.updated_at`；toll-gate 决策写入 `.specs/pipeline-goal/` 下的对应 SUMMARY

## 依赖与假设

- **依赖**：CC 原生 `/goal`（v2.1.139+）用于 native 模式的单阶段迭代；回退模式不依赖
- **依赖**：现有 flow-kit hook 系统（Stop Hook G1 写 `.flow-active` 的 `interrupt` 字段）
- **假设**：用户理解 toll-gate 机制并会在暂停点回复确认
- **假设**：Pipeline goal 只用于 4→5→6→7 执行链，用户已在 0-3 阶段完成需求和设计

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
