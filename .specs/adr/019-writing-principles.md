# ADR-019: flow-kit Writing Principles（Lessons from L-058/060/062）

**Status**: Accepted
**Date**: 2026-08-03
**Supersedes**: 无（首次定义 REQUIREMENT/DESIGN 写作原则）
**Superseded by**: 无

## Context

归档 change `superpowers-v6-absorb` 的 L2 审查产生了 9 条 Minor findings（L-058 ~ L-066），其中 3 条暴露出 REQUIREMENT 和 DESIGN 文档写作的结构性问题。由于源 change 已归档，REQUIREMENT.md 冻存不可改，这些发现无法 back-apply 到既有文档。需将其抽象为**前向适用**的写作原则，供所有未来 change 遵守。

### L-058：AC 非确定性（conditional AC scope）

- **位置**：`REQUIREMENT.md` AC-A3 — "在 macOS（如可用）" 使 macOS 不可用时 AC 自动降级为 Linux-only
- **问题**：Given/When/Then 验收准则（AC）必须为**确定性断言**。"如可用"引入平台条件分支，使 AC 在不同环境下有不同 pass/fail 含义，违反 AC 设计契约
- **已措对 REQ 写法的影响**：条件 AC 削弱跨平台验收的可复现性，不同开发者的环境差异导致同一 AC 测试结果不一致

### L-060：范围决策嵌入 REQUIREMENT

- **位置**：`REQUIREMENT.md` 范围决策框 — 设计决策（双轨测量 / 加强语义 / 并存策略）出现在 what 层级文档
- **问题**：范围决策属 how 层级，混入 what 层级文档模糊了需求与设计的边界。REQUIREMENT 包含 what（AC + user story + NFR），DESIGN 包含 how（架构对抗 + 算法选择 + 范围取舍）
- **已措对 REQ 写法的影响**：what/how 边界不清导致审阅者难以判断"这需求完整吗？"（需先过滤混入的 how 决定）

### L-062：task_progress lifecycle 图细节缺失

- **位置**：`DESIGN.md` § 2 task_progress lifecycle 图 — 图未展示 skip 任务时 task-brief 是否仍需提取
- **问题**：REQUIREMENT/DESIGN 中引用的图表若缺乏**可验证产物锚点**（文件路径 + 行号 + grep 正则），L2/L3 审查无法判定图的正确性
- **已措对 REQ 写法的影响**：审查者面对无锚点图只能 pass（无法 falsify），造成审查假绿

## Decision

制定以下 3 条前向适用原则，对所有新 change 的 REQUIREMENT/DESIGN 写作生效：

### Principle 1：AC 必须确定性（Deterministic AC — from L-058）

> All AC MUST be deterministic assertions. Conditional ACs MUST be split into (a) hard gate + (b) soft gate with explicit skip condition.

- **规则**：每个 AC 必须在任何环境下有唯一的 pass/fail 结果。条件性短语（"如可用"/"如果有"/"在 X 环境下"）禁止出现在 AC 断言正文中
- **条件 AC 处理**：若某验证确实依赖平台/环境，拆为两段：
  - **(a) Hard gate**：环境无关的硬性断言（如 `grep` 到某段文案）
  - **(b) Soft gate**：平台相关的软性断言，标注 skip condition（如 `SKIP(macos)`: verify on macOS only）
- **反例**（禁止）：
  ```
  AC-A3: 在 macOS（如可用）验证打包流程通过 （❌ 不确定）
  ```
- **正例**：
  ```
  AC-A3a: grep 到 package-flow-kit.sh 含 darwin 分支 （✅ 硬门）
  AC-A3b: [SKIP(no-macos)] 在 macOS 上实测打包通过  （✅ 软门 + 显式 skip）
  ```

### Principle 2：范围决策属 DESIGN 非 REQUIREMENT（Scope decisions belong to DESIGN — from L-060）

> Scope decisions (what's in/out/v1/v2) belong to DESIGN §0.5 (architecture alignment) or CHANGE.md (acceptance line). REQUIREMENT contains only AC + user stories + NFR.

- **规则**：REQUIREMENT 只包含 what（验收准则 AC / 用户故事 / 非功能需求 NFR），不含任何 how 判定（方案选择、范围取舍、技术权衡）
- **范围决策归属**：
  - 如果决定的是 "这个 change 做不做 X"（范围线） → `CHANGE.md` 验收线段
  - 如果决定的是 "为什么选方案 A 不选 B"（技术权衡） → `DESIGN.md §0.5` 架构对齐
- **REQUIREMENT 可以包含**：
  - v1/v2/out 标记 — 仅标注**范围**（某 AC 在 v1 做 vs v2 做），不写为什么
  - 优先级 — `高/中/低`（可简写）

### Principle 3：图表须引用可验证产物（Diagrams MUST reference verifiable artifacts — from L-062）

> Every diagram referenced in REQUIREMENT/DESIGN MUST list verifiable artifact anchors: file path(s) + line range(s) + grep anchor regex(es).

- **规则**：任何流程图/时序图/状态图/lifecycle 图下方必须附带 **可验证产物清单**，使 L2/L3 审查可独立验图（不依赖作者解释）
- **可验证产物清单格式**：
  ```
  **Verifiable artifacts**:
  - `hooks/pre-tool-use/independent-review-gate.sh`:L68-L75 → `is_phase_write` (`grep -n 'is_phase_write()'`)
  - `.flow-active.goal.task_progress[].id` → `grep -c 'completed_at'`
  ```
- **每个锚点至少包含**：文件路径 + 行号范围 + grep 可验证的正则
- **反例**（禁止）：
  ```
  （lifecycle 图，无锚点）  （❌ 审查无法验证）
  ```

## Consequences

### 正面

- **审查可验证性提升**：L2/L3 审查可独立验证 AC（Principle 1）、边界（Principle 2）、图表（Principle 3），不再依赖作者解释
- **falsifiability**：Principle 3 的锚点使审查从"读图判断"变为"grep 验证"，消除审查假绿
- **边界清晰**：Principle 2 的 what/how 分离降低 REQUIREMENT 审阅认知负荷

### 负面

- **REQUIREMENT 写作成本微增**：拆条件 AC + 约束范围决策归属增加 5-10 分钟
- **DESIGN 写作成本微增**：每个图需输出可验证产物清单（~3-5 行/图）
- **既有文档不受益**：已归档 change 的 REQUIREMENT/DESIGN 冻存保留遗留格式，不回溯修改

### 向前约束

- **新 change 必须遵守**：所有后续 change（自 `final-debt-cleanup-2026-08` 起）的 REQUIREMENT 和 DESIGN 文档必须遵守以上 3 原则
- **L2 审查检查点**：L2 reviewers SHOULD flag violations of these 3 principles in their review findings
- **ADR 修订**：若实践中发现某原则不可操作或需细化，通过新 ADR 修订本 ADR（不直接修改原文）
