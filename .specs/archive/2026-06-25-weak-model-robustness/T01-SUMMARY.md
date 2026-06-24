# T01-SUMMARY · 增强 RULES.md（R3.5 / R6.1 / R7.4）

- **task**: T01 · 增强 RULES.md（R3 禁跳反问 + R6 禁凭空假设 + R7 复述边界）
- **change**: weak-model-robustness

## 做了什么

在既有 R3 / R6 / R7 段各加一条弱模型鲁棒性硬约束（**增强既有段，非新建**，符合 D1）：
- **R3.5 禁跳反问**：反问 gate 未完成禁止产出方案/进实现
- **R6.1 引用前证据链**（强化原 R6.1）：引用前必须 `grep`/`read` 验证，禁止凭空假设/凭印象
- **R7.4 动手前复述边界**：防 scope drift

## 改了哪些文件

- `flow-kit-bundle/flow-kit/RULES.md`（三段各 +1 条规则）

## verify 输出

`grep -cE "禁跳反问|凭空假设|复述.*(read_files|write_files|边界)" RULES.md` → **3** ✅

## 沿用既有抽象 grep（R6.4）

- `grep "反幻觉" RULES.md` → R6·反幻觉段已存在（:139）→ **沿用并强化 R6.1**
- `grep "角色红线" RULES.md` → R3 已存在 → **沿用，加 R3.5**
- `grep "范围控制" RULES.md` → R7 已存在 → **沿用，加 R7.4**
- 无新建独立段（D1：保持八段结构一致，避免碎片化）

## 6 维自查（内置快查 · 纯文档任务）

纯 markdown 规则增强，无生产代码。R1-R6 维度对规则文本基本 N/A；R2 变更传播：仅增强既有段，未触其他模块 ✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/flow-kit/RULES.md`
- 实际 diff：`RULES.md`（GO.md/SYSTEM.md 属 T02/T03，CONTEXT.md 属 phase 1）
- 越界：**0** ✅

## TDD

纯文档任务，跳过 TDD（4-dev 步骤 2 例外）。

## 是否触发新 fix-plan

否。
