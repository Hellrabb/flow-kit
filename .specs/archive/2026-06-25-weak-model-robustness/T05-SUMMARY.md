# T05-SUMMARY · 2-design 加证据链（L3）

- **task**: T05 · 2-design 证据链
- **change**: weak-model-robustness

## 做了什么

在 2-design §0.5（既有架构对齐）「目的」后加证据链约束（L3 落地）：
- 触碰模块 / 既有抽象必须来自实际 grep/ls/read，禁止凭印象列举
- §1 决策引用文件/API/字段/抽象前必须验证存在，未验证标注「未找到，拒绝引用」

## 改了哪些文件

- `flow-kit-bundle/flow-kit/prompts/2-design.md`（§0.5 +证据链段）

## verify 输出

`grep -qE "证据链|未找到.*拒绝|凭印象"` → **PASS** ✅

## 沿用既有抽象 grep（R6.4）

- 2-design §0.5.1 已有"grep 出实际触碰模块（不是猜）"→ **沿用并升级为证据链硬约束**，覆盖引用类幻觉

## 6 维自查（纯文档）

无生产代码。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：`2-design.md`
- 实际 diff：仅 `2-design.md`
- 越界：**0** ✅

## TDD

纯文档，跳过。

## 是否触发新 fix-plan

否。
