# T02-SUMMARY · SYSTEM.md 加「弱模型鲁棒性原则」节

- **task**: T02 · SYSTEM.md 加弱模型鲁棒性原则节
- **change**: weak-model-robustness

## 做了什么

在 SYSTEM.md（RULES 的精简注入版）R8 段后加独立节「弱模型鲁棒性原则（protect the weakest）」：
- 声明 protect-the-weakest 哲学（默认全含加严 + 仅结构刚性）
- 指向完整规则 RULES.md R3.5/R6.1/R7.4 + ADR-001
- 不逐条同步 RULES 增强（SYSTEM 是精简版，避免膨胀）

## 改了哪些文件

- `flow-kit-bundle/flow-kit/SYSTEM.md`（+1 节）

## verify 输出

`grep -q "弱模型鲁棒性" && grep -q "protect the weakest\|ADR-001"` → **PASS** ✅

## 沿用既有抽象 grep（R6.4）

- `grep "R8\|语言" SYSTEM.md` → R8 段已存在 → 在其后插入新节（沿用结构）
- 哲学决策不重复写 → 指向 ADR-001（单一源）

## 6 维自查（纯文档）

无生产代码。R3 知识重复：与 RULES.md 完整版关系明确（精简版声明 + 指向完整版，非重复逐条）✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/flow-kit/SYSTEM.md`
- 实际 diff：仅 `SYSTEM.md`
- 越界：**0** ✅

## TDD

纯文档任务，跳过 TDD。

## 是否触发新 fix-plan

否。
