# REQUIREMENT: 修复 gate-integrity L2/L3 code review 缺陷

## AC-1：C1 tee 行首绕过修复
**Given** `is_handshake_write` 的 tee 检测用 `[[:space:]]tee[[:space:]]`
**When** agent 执行 `tee .flow-active.independent-review <<< "x"`（行首无前导空格）
**Then** 正则不匹配 → 绕过 → 应 deny。修复为 `(^|[[:space:]])tee[[:space:]]`

## AC-2：C2 sed -E -i 绕过修复
**Given** `is_handshake_write` 的 sed 检测用 `sed[[:space:]]+(-i|--in-place)`
**When** agent 执行 `sed -E -i 's/x/y/' .flow-active.independent-review`（-E 插在中间）
**Then** 正则不匹配 → 绕过 → 应 deny。修复为 `sed[[:space:]].*(-i|--in-place)`

## AC-3：bats 不回归
**Given** test_gate_integrity.bats 23 tests
**When** 修复后重跑
**Then** 23 passed, 0 failed, 0 新增回归
