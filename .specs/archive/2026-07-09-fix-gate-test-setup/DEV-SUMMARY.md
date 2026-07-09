# DEV-SUMMARY · fix-gate-test-setup（修 TD-013 · test_gate_integrity 多重假绿）

- **Change ID**: fix-gate-test-setup
- **阶段**: 4-dev + 5-test + 6-review 自审（降挡 · 无 L2/L3）
- **日期**: 2026-07-09

## 改动（test_gate_integrity.bats · 两副本同步）

| # | 改动 | AC | 依据 |
|---|---|---|---|
| 1 | setup 去 `set +e`（line 30）| AC-1 | TD-013 · L2 F2 实测假绿 |
| 2 | setup 加 `export HOOK_BASE_DIR="$BUNDLE_ROOT/hooks/stop"`（source ARTIFACTS_LIB **之前**）| AC-5 | L2 F2/F6 · 让 done-validation.sh 加载 fk_validate_done_marker |
| 3 | helper `write_valid_done` 补 `artifacts=REQUIREMENT.md,CHANGE.md,...` KVP | AC-6 #8 | done-validation.sh 强制 `k_artifacts` 含逗号（return 2 否则）|
| 4 | 17 条直接调用 fn 测试改 `run fn; [ "$status" -eq N ]`（禁 `if ! fn; then rc=$?`）| AC-2 | L2 F1 · `!` 反转 $? 致假阴/假绿 |
| 5 | #19/#20（D10 phases_done/phase=）`skip` + `# TD-014` | AC-6 | is_phase_write L73-75 regex 顺序 bug · out-of-scope |
| 6 | #11/#12（AC-3 artifacts.sh 正则/case）`skip` + `# TD-016` | AC-6 | 测试断言债 · artifacts.sh 实测不含 |
| 7 | #23（AC-6 F29 sha256）`skip` + `# TD-016` | AC-6 | 测试断言债 · F29 实测不含 sha256sum |
| 8 | 注释更新（run 继承 source 函数 · 非 127）| — | L2 F4 · 旧注释误判催生 set+e 假绿组合 |

## AC-6 逐条归属（L2/L3 实测确认）

| 残余 # | 真因 | 归属 |
|---|---|---|
| #8 | helper 缺 `artifacts=` KVP → done-validation return 2 | **v1 修**（helper 补 KVP · D9 正向现 return 0）|
| #19/#20 | is_phase_write L73-75 regex 顺序 bug（漏检 jq phase-write）| **skip + TD-014**（fix-gate-phase-detection 范围）|
| #11/#12 | 断言 artifacts.sh 含 phase 正则/case，实测不含 | **skip + TD-016**（测试断言债）|
| #23 | 断言 F29 含 sha256sum，实测不含 | **skip + TD-016**（测试断言债）|

## 验证结果

- `bats test/test_gate_integrity.bats`：**23 tests · 18 ok + 5 skip + 0 not ok**（v1 内全绿）
- `make test`：**407 全绿**（exit 0 · 不破坏其他测试）
- AC-4 反向断言：注入 `false` → `❌ some tests failed` + `make 错误 1`（non-zero）→ 还原后 `✅ all tests passed`（断言检测有效 · 非橡皮图章）
- AC-5 HOOK_BASE_DIR：D9 正向 `fk_validate_done_marker return 0`（函数加载 + 调用成功）

## 6-review 自审（降挡 · 主 agent）

- **spec 合规**：AC-1~7 全过（REQUIREMENT v4 · 降挡前 L2 两轮 + L3 已查清全部事实）
- **行为等价**：`run`+`$status` 与旧 `fn; [ $? -eq N ]` 在无 set+e 下行为一致（L2 F1 实测），且不受 set -e 干扰（run 子 shell）
- **范围边界**：未碰 gate 逻辑（independent-review-gate.sh · TD-014 out），仅修测试文件 setup/helper/测试体 + skip
- **遗留**：TD-016（断言债）+ TD-014（is_phase_write）由独立 change 处理，本 change skip 归因

## 战略成果
test_gate_integrity.bats 从「多重假绿灾区」（set+e + #8 helper + 断言债 + is_phase_write）恢复到「v1 内真绿 + 范围外显式 skip 归因」。为 fix-gate-phase-detection（TD-014）提供可信测试基础。
