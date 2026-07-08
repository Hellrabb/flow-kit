# TEST: test-setup-path-fix-2026-07 · AC 验证记录

- **Change ID**: test-setup-path-fix-2026-07
- **关联**: REQUIREMENT.md（5 AC）

## AC 验证结果

| AC | 验证方式 | 结果 |
|---|---|---|
| **AC-1** 10+ 测试 setup 路径位置无关 | `npx bats test/test_l2_l3_granular_gate.bats` 无 BW01 + `type fk_validate_done_marker` | ✅ 18 文件修，source 成功，函数定义，0 BW01 |
| **AC-2** make test 全绿无 BW01 | `make test` | ✅ exit 0, 407 pass, 0 fail, 0 BW01 |
| **AC-3** make check 全门禁通过 | `make check` | ✅ test + lint + validate + sync 全过 |
| **AC-4** check-test-sync 双源一致 | `make check-test-sync` | ✅ test/ ↔ flow-kit-bundle/test/ 一致 |
| **AC-5** Makefile test target 不用管道吃 exit | 临时注入 fail → make test exit 1 | ✅ line 13 直接用 bats exit（line 12 展示行不影响判定）|

## 测试矩阵

- **bats-core 1.13.0**：407 测试全 pass
- **shellcheck**（make lint）：0 error
- **package validate**（make check-validate）：262 文件 0 漏配
- **双源 sync**（make check-test-sync）：一致

## 修复统计

- 修路径文件：~18（setup + 测试体内）
- 修断言 bug：1（test_quality_baseline `grep -c || echo 0`）
- fail：98 → 0
- BW01：39 → 0

## 暴露的真 fail

- **TD-011 gate:68**：未暴露（gate 测试 pass，但 gate:68 `&&` 被 `[[ ]]` 当逻辑与的真 bug 仍在，测试没覆盖该路径）。待 `refactor-independent-review-gate`
- 无其他真 fail（所有 fail 都是路径 bug 或断言 bug）

## 结论

✅ 所有 AC 满足。goal 条件达成（make test 全绿 + make check 通过 + 30+ 测试真绿 + check-test-sync 一致）。
