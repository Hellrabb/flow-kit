# ADR-018: GO.md Bootstrap Compression（473→≤350 行）

**Status**: Proposed (superpowers-v6-absorb Phase 2)
**Date**: 2026-08-02
**Supersedes**: 无（首次定义 GO.md 体积约束）
**Superseded by**: 无

## Context

superpowers v6.1（2026-06-30）发布重点：bootstrap 压缩（121→62 行，-49%）。Vincent 的博客原文：[...(删)]。压缩对象主要是：
- graphviz DOT digraph（~25 行）→ prose
- per-platform "How to Access Skills" walkthrough → 删
- Instruction-Priority 独立段 → 折叠为 one-liner
- claude-code-tools.md / copilot-tools.md → 全删（无 harness-specific 内容）

flow-kit 的 GO.md（473 行 / ~30KB）是 de facto always-loaded（每次 flow-kit 调用必读）。在 pipeline 中是第 4 大 token footprint。

实际段结构（grep `^#{1,3}` 出）：
- 红线·Token 预算（必读）— 保留
- Token 预算估计 · 进阶段前必跑 — 重，可压缩
  - 典型 token 成本表 — 详细，可压缩
  - 用户首轮路由后，AI 必须输出预算估算 — 保留
  - 何时**不必**跑这段 — 简短，可压缩
  - 真实成本影响因子（让估算更准）— 描述性，重度压缩
  - 用户视角的取舍 — 描述性，重度压缩
- 第一步 · 读取项目状态（必须）— 保留
  - 可选 runtime adapter 检测 — 可压缩
- 第二步前 · Artifact Preflight Gate（强制）— 保留
- Phase Completion Gate（pipeline goal 强制）— 保留
- 第二步 · 解析用户意图，路由到阶段 — 保留（核心）
  - Fallback 路由（mode=fallback · P1-3/F5 修复）— 可压缩
- 第三步 · 老项目入场检测（brownfield 必跑）— 保留
  - 3.1 探测 AI 上下文文档 — 保留
  - 3.2 判决 — 保留
  - 3.3 为什么这步重要 — 可压缩（理由段）
- 第四步 · 自动准备 — 可重度压缩
  - 加载工件（严格区分 必读 / 按需）— 操作指令，可移到 reference/README.md
  - 查 reference 某一节的实际动作示例 — 操作指令，可移
- 第五步 · 显式声明执行计划（必须）— 保留
- 第六步 · 执行对应阶段 prompt — 保留
  - 6.0 路由到 4-dev 前强制 Goal 检测（R1.9）— 保留

## Decision

**仅删冗余，不重构核心路由**（保守路径）：

### 1. 删除段（不影响功能）

- **"真实成本影响因子（让估算更准）"**：~20 行描述性文字。现代模型已知 token 估算常识，删。
- **"用户视角的取舍"**：~15 行解释为什么估算。决策已在"红线"段说明，删。
- **"3.3 为什么这步重要"**：~10 行论证。理由简短化到一句话加入 3.2 末尾，删独立段。
- **"可选 runtime adapter 检测"**：~8 行。adapter 已废弃（OpenCode 统一），删。

预计删 ~53 行。

### 2. 压缩段（保留功能但精简文字）

- **"典型 token 成本表"**：从详细表格压缩为单行参考（"中等 change ~250-530K tokens，详细看 CHANGE.md 预算段"），保留数字但删周边说明。压缩 ~30 行。
- **"何时**不必**跑这段"**：3 行精简为 1 行。压缩 ~2 行。
- **"加载工件（严格区分 必读 / 按需）"**：操作指令（grep + read + offset/limit + 150 行 cap）移到 `flow-kit/reference/loading-artifacts.md`，GO.md 仅留 `@see reference/loading-artifacts.md`。压缩 ~25 行。
- **"查 reference 某一节的实际动作示例"**：操作示例（# ± 查行号 # 取到 line N）移到 loading-artifacts.md。压缩 ~15 行。
- **"Fallback 路由（mode=fallback · P1-3/F5 修复）"**：技术债务说明压缩到 2 行。压缩 ~10 行。

预计压缩 ~82 行。

### 3. 不动的段

- "红线·Token 预算" — 强制段
- "Token 预算估计 · 进阶段前必跑" 主段 + "用户首轮路由后必须输出预算估算" — 强制段
- "Artifact Preflight Gate" — 强制段
- "Phase Completion Gate" — 强制段
- "解析用户意图，路由到阶段" 主段 — 核心
- "老项目入场检测" 主段 + "3.1 探测" + "3.2 判决" — 强制段
- "显式声明执行计划" — 强制段
- "执行对应阶段 prompt" + "6.0 强制 Goal 检测" — 核心

### 4. 预期成果

- 473 行 → ~338 行（-28.5%，满足 AC-H1 ≤350 行）
- ~30KB → ~21KB（-30%，满足 AC-H1 ≤22KB）
- routing 逻辑零变更（AC-H2 路由测试 10 个 intent 一致）

### 5. 风险控制

- AC-H2 路由测试 10 个代表性意图，断言压缩前后路由结果一致
- 测试用例：用户说"加新功能" / "修 bug" / "重构" / "测试" / "review" / "上线" / "归档" / "继续" / "下一个 task" / "pause"
- 如压缩后路由测试失败 → 回滚到保守删段（仅删 1 类）

## Consequences

**正面**：
- GO.md 体积 -28.5%，每次 flow-kit 调用节省 ~9KB context
- routing 逻辑不变，既有用户体验一致
- 操作指令移到 reference/loading-artifacts.md 后，可被多个 prompt 复用（DRY）

**负面**：
- reference/loading-artifacts.md 是新文件，增加文件数
- "真实成本影响因子" / "用户视角的取舍" 段删除后，AI 估算 token 时少了上下文（但 modern 模型已懂）

**Neutral**：
- 与 superpowers v6.1 的 121→62 行（-49%）相比，本 change 的 -28.5% 保守。原因：flow-kit GO.md 含强制 gate 段（Artifact Preflight / Phase Completion Gate）不能删，superpowers using-superpowers 无此类硬约束

**禁动约束**：
- GO.md ≤350 行为结构性硬指标（AC-H1），后续 change 不允许超过
- routing 逻辑（用户意图 → phase 映射）不允许在压缩中变更
- reference/loading-artifacts.md 不允许被其他 reference 文件 supersede（DRY 单一源）

## 触发条件

- 本 change 实施时（phase 4）：GO.md 删 + 压缩 + 新建 reference/loading-artifacts.md
- 本 change 测试时（phase 5）：bats 测试 GO.md 行数 + routing 测试 10 intents
- 后续 change 改 GO.md 时：必须保持 ≤350 行约束
