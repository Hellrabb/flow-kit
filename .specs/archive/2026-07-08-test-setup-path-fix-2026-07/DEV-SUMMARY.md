# DEV-SUMMARY: test-setup-path-fix-2026-07 · 4-dev 执行记录

> TD-012 修复完成。Wave 1 + Wave 2 全部 verify 通过。goal 条件达成。

## Wave 1 · 13 文件 setup 路径修复（4 Agent 并行）

| Agent | 文件 | 测试 | BW01 |
|---|---|---|---|
| T01 | 5（correction_file/flow_active_integrity/l2_l3_fix_compliance/l3_async_dispatch/setup_integrity）| 65 pass | 0 |
| T02 | 4（done-skip/l2-detect/l3-truncation/phase-resolution）| 18 pass | 0 |
| T03 | 2（l2_l3_granular_gate/dual_review_merge）| 19 pass | 0 |
| T04 | 2（checkpoint/smoke_syntax）| 12 pass | 0 |

修法：位置无关（向上查找 `flow-kit-bundle/hooks`），参照 `test_package_flow_kit.bats` 已验证模式。双源同步。

## Wave 2 · 诊断 + 修剩余 fail（98→42→0）

Wave 1 后跑全量：**98 fail + 39 BW01**（修复不完整，TD-012 文件列表不全）。

逐文件定位（后台 bats 统计）→ 7 文件漏修/测试体内路径：
- **5 漏修文件**（test_common/test_l3_review/test_weak_model_compliance/test_interactive_ui_check/test_gate_integrity）：Agent 修 setup，~94 测试转绿
- **4 漏修文件**（test_install 11 BW01 / test_install_brooks_tools / test_flow_artifacts / test_flow_kit_resume）：Agent 修 setup，全绿
- **3 文件**（test_stop_report_reminder / test_quality_baseline / test_dual_review_merge 测试体内路径）：Agent 修

**test_quality_baseline 的 1 fail 是非路径 bug**：`grep -c "error" || echo 0` 重复打印 0（grep -c 无匹配已打印 0 + exit 1，`|| echo 0` 再打印 0 → "0\n0" ≠ "0"）。改 `echo 0`→`true`，断言意图不变（0 shellcheck error）。

## 最终验证

| 验证 | 结果 |
|---|---|
| `npx bats test/` | exit 0, **407 pass, 0 fail, 0 BW01** |
| `make check` | ✅ 全部通过（test + lint + validate + sync）|
| `make check-test-sync` | ✅ 双源一致 |
| health-fix-2026-07-08 "169→0" | 现在才真可信（之前 bats\|tail 假绿）|

## 偏差

1. **TD-012 影响范围比最初判断大**：最初 grep 13 文件，实际 ~18 文件（test_common/test_install/test_flow_artifacts 等漏修）。逐文件 bats 统计定位 + 迭代修
2. **test_quality_baseline 断言 bug**（非路径）：`grep -c || echo 0` 重复打印，顺手修
3. **TD-011 gate:68 未暴露**：test_l2_l3_granular_gate 12/12 pass（gate 函数定义了，但测试没覆盖 `&&` 路径，或 SC2157 "always true" 让断言碰巧 pass）。TD-011 仍是真 bug，待 `refactor-independent-review-gate`

## 修法一致性

所有文件统一位置无关模式（向上查找 `flow-kit-bundle/hooks`），双源 test/ + flow-kit-bundle/test/ 都正确。L-025 同源问题彻底根治。
