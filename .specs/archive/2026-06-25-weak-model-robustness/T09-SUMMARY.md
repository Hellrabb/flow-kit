# T09-SUMMARY · regression-demo（strong-model-verbosity · AC-7 静态版）

- **task**: T09 · 强模型啰嗦度 demo
- **change**: weak-model-robustness

## 做了什么

新建 `strong-model-verbosity/` demo（AC-7 静态检查版，D4 脚本模拟）：
- `scenario.md`：说明啰嗦反噬强模型的风险 + 检查项 + 定量阈值留 v2
- `check.sh`：① 加固有意识限定触发点（4-dev「非每操作」/ GO「仅入场」）② gate 填空式 ③ 反向：不得有「每步复述 goal / 每次操作 checkpoint」无条件唠叨

**AC-7 验证方式细化**：原 DESIGN 写"对比加固前后输出快照"，但本次 demo 脚本模拟无法真跑模型 → 改为静态检查（加固设计是非啰嗦的）。定量 token/turn < 20% 留 v2 自动化。TASK.md 已注明。

## 改了哪些文件

- `flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/{check.sh,scenario.md}`

## verify 输出

`strong-model-verbosity/check.sh` → **PASS**（结构刚性 + 填空式 gate + 无重复唠叨）✅

## 沿用既有抽象 grep（R6.4）

- 同 T08，引入 check.sh 范式

## 6 维自查

shell 脚本。反向 grep（检测唠叨词）逻辑正确：命中「每步复述 goal / 每次操作 checkpoint」=FAIL，而「非每操作」「仅入场」是限定词不触发 ✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：2 文件
- 实际 diff：仅这 2 个新文件
- 越界：**0** ✅

## TDD

check.sh 是验收脚本。先写→跑→PASS。

## 是否触发新 fix-plan

否。
