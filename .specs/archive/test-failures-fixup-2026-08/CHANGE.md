# CHANGE · test-failures-fixup-2026-08

> Phase 0 变更提案 · 2026-08-03

---

## § 1 为什么做（动机）

`final-debt-cleanup-2026-08` 归档后剩余 5 个 pre-existing bats fail（250 / 507 / 509 / 515 / 577）。虽非本 change 引入，但每次 pipeline 都需在 TEST.md 中显式标注 "pre-existing"，影响测试基线可信度。

本 change 一次性清理全部 5 个 fail，恢复 0 fail 基线。

## § 2 做什么（具体改动）

### 2.1 Test 250 — gate.sh regex 含 3/5/7

**根因**: `cleanup-debt-batch-2026-08` T06 把 `independent-review-gate.sh` 拆为 4 文件后，phase 匹配 regex `^(1|2|3|5|6|7)$` 分散到 sub-libs，原 test 只 grep 单文件失败。

**修复**: 更新 `test/test_gate_integrity.bats:148-156` 的 grep 范围为 `independent-review-gate.sh + gate-checks-basic.sh + gate-checks-review.sh + gate-helpers.sh`。

### 2.2 Test 507/509/515 — 4-dev.md §1.8.4 内容缺失

**根因**: `cleanup-debt-batch-2026-08` L-068 把 4-dev.md 从 781→352 行压缩时，把 §1.8.4（bats 自动执行 + 失败阻断）抽到 `reference/tdd-workflow.md`。3 个 test 仍 grep 4-dev.md 单文件。

**修复**: 更新 `test/test_lessons_cleanup.bats` 中 3 个 test 的 grep 范围为 `4-dev.md + reference/tdd-workflow.md`（双文件任一命中即 pass）。

### 2.3 Test 577 — make lint shellcheck SC2148

**根因**: `final-debt-cleanup-2026-08` T05+T06 新建 7 个 hook lib 文件（l3-prompt/api/truncate/done + gate-helpers/checks-basic/checks-review）作为 sourced lib，无 shebang。shellcheck 默认报 SC2148。

**修复**: 在 7 个文件首行添加 `# shellcheck shell=bash`（不需 shebang，因为这些是 sourced 不是 executed）。

## § 3 风险

- **R1 (低)**: 测试 grep 范围扩大可能掩盖未来 4-dev.md/gate.sh 内容回退。**缓解**: 在 test 注释中显式说明"内容可能在 reference/ 或 sub-libs"。
- **R2 (低)**: `# shellcheck shell=bash` 指令不会影响运行时行为（仅 lint 提示）。**缓解**: 仅 sourced lib 用此指令；entry-point 脚本仍用 `#!/bin/bash`。

## § 4 影响面

- `test/test_gate_integrity.bats` (1 test 修改)
- `test/test_lessons_cleanup.bats` (3 tests 修改)
- `flow-kit-bundle/test/` 同步（双源）
- 7 个 hook lib 文件首行加 `# shellcheck shell=bash`
- 无 prompt / hook 逻辑变更
- 无新依赖
- 无破坏性变更

## § 5 v1 / v2 / out

- **v1**: 5 个 pre-existing fail 全部修复
- **v2**: 无
- **out**: 无

---

**Verdict**: ✅ 准备 phase 1 REQUIREMENT。
