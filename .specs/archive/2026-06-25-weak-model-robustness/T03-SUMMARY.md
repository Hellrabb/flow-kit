# T03-SUMMARY · GO.md 加 pipeline 阶段入场 goal 锚定

- **task**: T03 · GO.md 加 pipeline 阶段入场 goal 锚定
- **change**: weak-model-robustness

## 做了什么

在 GO.md 第五步（路由声明）加「阶段入场 goal 锚定」：
1. 第五步正文加说明段：若 `.flow-active.goal` 非空，路由声明必含「🎯 本阶段锚定」一行——一句话说明本阶段如何服务顶层 goal。**仅入场一次，非每步唠叨**（避免反噬强模型，AC-7）。
2. 路由声明模板加 `🎯 本阶段锚定：<...>` 行。

未改路由逻辑、未改状态机（R5 范围控制）。

## 改了哪些文件

- `flow-kit-bundle/flow-kit/GO.md`（+1 说明段 +1 模板行）

## verify 输出

`grep -qE "goal.*(锚定|重申)|重申.*goal|本阶段锚定" GO.md` → **PASS** ✅

## 沿用既有抽象 grep（R6.4）

- `grep "Goal\|goal" GO.md` → 第五步路由声明模板已有 Goal 行（:358）→ **沿用模板，加锚定行**，不新建机制
- pipeline 进度显示已有 → 仅追加锚定，不改既有

## 6 维自查（纯文档）

无生产代码。R4 偶然复杂：锚定是「仅入场一次」非每步，符合 AC-7 啰嗦约束 ✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/flow-kit/GO.md`
- 实际 diff：仅 `GO.md`
- 越界：**0** ✅

## TDD

纯文档任务，跳过 TDD。

## 是否触发新 fix-plan

否。
