# REQUIREMENT: 修 10+ 测试 setup 路径 + Makefile test 管道漏洞（让 30+ 假绿测试真绿）

- **Change ID**: test-setup-path-fix-2026-07
- **关联**: `@.specs/test-setup-path-fix-2026-07/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想让测试套件**真绿**（非 `bats|tail` 管道掩盖的假绿），以便测试能真正捕获回归
- **US-2**：作为 flow-kit 维护者，我想让 `make test` / `make check` 判定可信（bats exit code 不被管道吃掉），以便质量门禁有效

## 验收准则（AC）

### AC-1 · 10+ 测试 setup 路径位置无关化

- **Given** test/ 下 10+ 测试文件 setup 用 `$(dirname "$BATS_TEST_FILENAME")/../hooks/...`（缺 `flow-kit-bundle/` 层，指向不存在的 `<repo>/hooks/`）
- **When** 改用位置无关（向上查找目标 lib，参照 health-cleanup T01 的 `test_package_flow_kit.bats` 根治模式）
- **Then** `source` 成功，被测函数（fk_validate_done_marker / fk_independent_review_gate_active 等）定义，`run` 不再 exit 127
- **验证方式**: `npx bats test/test_l2_l3_granular_gate.bats` 无 BW01 + `type fk_validate_done_marker` 函数定义检查

### AC-2 · make test 全绿无 BW01

- **Given** AC-1 满足
- **When** `make test`
- **Then** 414 测试 pass，**0 个 BW01 exit 127**
- **验证方式**: `make test && echo PASS`（exit 0）

### AC-3 · make check 全门禁通过

- **Given** AC-1/2 满足
- **When** `make check`
- **Then** test + lint + validate + sync 全过
- **验证方式**: `make check`（exit 0）

### AC-4 · check-test-sync 双源一致

- **Given** 修路径同步到 `test/` 与 `flow-kit-bundle/test/` 双源
- **When** `make check-test-sync`
- **Then** 双源 diff 一致
- **验证方式**: `make check-test-sync`

### AC-5 · Makefile test target 不用管道吃 exit code

- **Given** make test 判定行直接用 bats exit（line 13 已正确）；展示行 line 12 `| tail -3` 不影响判定
- **When** 故意引入一个 fail 测试，跑 `make test`
- **Then** make test 报 fail（不被 tail exit 0 掩盖）
- **验证方式**: 临时注入 fail → `make test` exit 1 → 还原

## 范围切分

### v1（本次必做）

- 修 10+ 测试 setup 路径（位置无关）
- 修 Makefile test target 管道漏洞（AC-5）
- 让 30+ 假绿测试真绿
- 复核 health-fix-2026-07-08 实际通过率

### v2（下一轮考虑，不本次）

- shellcheck 117 warning/info 清理
- TD-004/005 prompt/jq 重复重构

### out（永远不做）

- TD-011 gate:68 真 bug（独立 change `refactor-independent-review-gate`，依赖本 change 让测试真绿后验证）
- TD-008 l3-review 574 行拆分（暂不做）

---

## 非功能性需求

- **性能**: 无（测试基础设施，bats 执行时间可接受）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: bats-core 1.13.0 / bash
- **可观测性**: 测试输出清晰（BW01 消失，pass/fail 明确）

## 依赖与假设

- **依赖**: bats-core 1.13.0（已装）/ 双源 test/ + flow-kit-bundle/test/（check-test-sync 强制一致）
- **假设**: 修路径后大部分测试会真绿（source 成功 → 函数定义 → 已有 assertion 通过）；**可能暴露被假绿掩盖的真 fail**（如 fk_validate_done_marker 逻辑 bug）——若暴露，在 4-dev/5-test 迭代修，或记 TD
