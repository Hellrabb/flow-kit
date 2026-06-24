# T04-SUMMARY · 0-change + 1-requirement 反问 gate 强化（填空式）

- **task**: T04 · 反问 gate 强化
- **change**: weak-model-robustness

## 做了什么

把 0-change / 1-requirement 的反问环节强化为「反问 gate」（R3.5 落地）：
- 反问未完成（用户未回答）前禁止产出 CHANGE.md / REQUIREMENT.md
- 关键产出字段采用填空式（未填全 = 产出不全，弱模型无法跳过）
- 每轮反问 ≤ 3 个（AC-7 啰嗦约束）

## 改了哪些文件

- `flow-kit-bundle/flow-kit/prompts/0-change.md`（步骤 1 → 反问 gate）
- `flow-kit-bundle/flow-kit/prompts/1-requirement.md`（步骤 3 → 反问 gate）

## verify 输出

`grep -qE "反问 gate|填空"` → 0-change **PASS** · 1-requirement **PASS** ✅

## 沿用既有抽象 grep（R6.4）

- 两 prompt 已有反问环节（0-change 步骤 1 / 1-requirement 步骤 3）→ **沿用并强化为 gate**，不新建机制

## 6 维自查（纯文档）

无生产代码。R4 偶然复杂：填空式是刚性约束但非啰嗦（符合 AC-7）✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：`0-change.md` + `1-requirement.md`
- 实际 diff：仅这两个文件
- 越界：**0** ✅

## TDD

纯文档，跳过。

## 是否触发新 fix-plan

否。
