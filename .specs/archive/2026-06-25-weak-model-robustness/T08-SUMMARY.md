# T08-SUMMARY · regression-demo（hallucination-guard + scope-drift-guard · AC-2/AC-4）

- **task**: T08 · 证据链 + 范围漂移 demo
- **change**: weak-model-robustness

## 做了什么

新建 2 个 regression-demo（D4 脚本模拟 · 静态行为特征检查）：
- `hallucination-guard/`：scenario.md（诱导引用不存在模块）+ check.sh（验 4-dev/2-design 证据链指令 + RULES R6.1）
- `scope-drift-guard/`：scenario.md（诱导越界编辑）+ check.sh（验 4-dev 复述边界 + RULES R7.4 + 范围排除）

## 改了哪些文件

- `flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/{check.sh,scenario.md}`
- `flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/{check.sh,scenario.md}`

## verify 输出

- `hallucination-guard/check.sh` → **PASS**（证据链护栏就位）✅
- `scope-drift-guard/check.sh` → **PASS**（范围漂移护栏就位）✅

## 沿用既有抽象 grep（R6.4）

- `ls regression-demos/` → 既有仅 `brooks-lint-paths.md`（无可执行 check.sh 范式）→ **引入** check.sh 范式（DESIGN 0.5.3 批准，9.1 列为可复用抽象）

## 6 维自查

shell 脚本（`set -euo pipefail`，遵循 CONTEXT 默认偏好）。R5 依赖：无外部依赖，纯 grep ✓。无 🔴/🟡。

## 越界检查（R6.5）

- TASK write_files：4 文件
- 实际 diff：仅这 4 个新文件
- 越界：**0** ✅

## TDD

check.sh 是验收脚本本身。先写→跑→PASS（被测护栏 Wave 1/2 已就位）。

## 是否触发新 fix-plan

否。
