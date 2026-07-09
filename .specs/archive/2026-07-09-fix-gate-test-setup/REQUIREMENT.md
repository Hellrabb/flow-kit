# REQUIREMENT: 修 TD-013 · test_gate_integrity.bats 多重假绿修复

- **Change ID**: fix-gate-test-setup
- **关联**: `@.specs/fix-gate-test-setup/CHANGE.md`、`@.specs/CONTEXT.md`（TD-013/016）
- **修订**: v4 · 合并 L2 两轮 + L3 全部发现。降挡（无 L2/L3，主 agent 直接实施 + make test 把关）。
- **真实图景**（L2/L3 查清）：test_gate_integrity.bats 是**多重假绿灾区**——① TD-013 set+e ② #8 helper 缺 artifacts= ③ TD-016 断言债（#11/#12/#23 断言实现不存在的内容）④ #19/#20 is_phase_write bug（TD-014 out）。本 change 修 ①② + setup HOOK_BASE_DIR + 测试体 run，③④ skip 归因。

---

## 用户故事

- **US-1**：修掉 setup `set +e` 假绿（TD-013），恢复断言可信度。
- **US-2**：补 setup `HOOK_BASE_DIR`（让 `fk_validate_done_marker` 加载，否则去 set+e 后 127 崩溃）。
- **US-3**：修 helper `write_valid_done` 补 `artifacts=` KVP（#8 · done-validation 强制校验）。
- **US-4**：作为 `fix-gate-phase-detection`（TD-014）前置——恢复 test_gate_integrity 可信（v1 范围内），③④ skip 归因待 TD-014/016。

## 验收准则（AC）

### AC-1 · setup 清除 set+e（两副本 · 与 AC-2/AC-5 原子合入）
- **Given** `test/` + `flow-kit-bundle/test/` 两副本 setup 已去 `set +e`（**必须与 AC-2 测试体改写 + AC-5 HOOK_BASE_DIR 原子合入**，否则单独去 set+e 致全红 · L3 原子性）
- **When** grep set+e 两副本
- **Then** 两副本均无匹配
- **验证方式**: `! grep 'set +e' test/test_gate_integrity.bats && ! grep 'set +e' flow-kit-bundle/test/test_gate_integrity.bats`

### AC-2 · 测试体强制 run+$status（禁 if!fn · L2 F1）
- **Given** 期望非零测试体改 `run fn; [ "$status" -eq N ]`（强制 · L2 F1 实测可用）或等价 `set +e; fn; rc=$?; set -e; [ "$rc" -eq N ]` / `rc=0; fn || rc=$?; [ "$rc" -eq N ]`
- **When** bats 跑
- **Then** fn 返回值正确反映；**禁用** `if ! fn; then rc=$?`（`!` 反转 $? 致假阴/假绿 · L2 F1 实测）
- **验证方式**: `! grep -E 'if ! .*; then.*rc=\$\?' test/test_gate_integrity.bats`（禁坏模式）+ `grep -cE 'run .+|rc=\$\?;.*-eq' test/test_gate_integrity.bats`（改写模式 ≥9 · 含 `$?` 分支 · L3）

### AC-3 · make test 全绿（v1 范围内 · 范围外 skip · L2 轮2 F1）
- **Given** v1 修复合入 + 范围外条目（#11/#12/#23 断言债 · #19/#20 is_phase_write）`skip` + 归因注释
- **When** `make test`
- **Then** **v1 范围内全绿**（非假绿 · 断言真生效）；范围外条目 skip
- **验证方式**: `make test`（exit 0）+ `grep -cE 'skip' test/test_gate_integrity.bats`（skip ≥5 · 含 `# TD-014`/`# TD-016` 注释）

### AC-4 · 反向断言（防假绿守门员失效）
- **Given** 临时注入 `false` 到测试套件
- **When** `make test`
- **Then** non-zero exit（证明断言检测有效）
- **验证方式**: 注入 false → make test（non-zero）→ 还原

### AC-5 · setup 补 HOOK_BASE_DIR + 函数加载验证（L2 F2 + L3 调用验证）
- **Given** setup 加 `export HOOK_BASE_DIR="$BUNDLE_ROOT/hooks/stop"`（在 source ARTIFACTS_LIB **之前** · L2 F6 顺序敏感）
- **When** setup source 后
- **Then** `fk_validate_done_marker` **已定义** + **可调用无错**（非仅 type 存在 · L3）
- **验证方式**: bats setup 后 `type fk_validate_done_marker` + 一个无害调用（如 `fk_validate_done_marker <valid_done> 2>/dev/null; rc=$?; [ $rc -eq 0 ]`）无 127/运行错

### AC-6 · 6 条残余逐条归属 + #8 helper 修入 v1（L2 轮2 + L3 scope/可验证）
- **Given** 去 set+e 实测 6 条残余 not ok（#8/#11/#12/#19/#20/#23）
- **When** 4-dev 逐条处置
- **Then** 每条明确（**可验证归因** · L3）：
  - **#8**（fk_validate_done_marker return 2）→ **v1 修**：helper `write_valid_done` 补 `artifacts=test-change,REQUIREMENT.md`（done-validation 强制 `k_artifacts` 含逗号）· **v1 范围已含此源码修**（L3 scope creep 修正）
  - **#19/#20**（is_phase_write 拦 phase-write）→ **skip + 注释 `# TD-014 is_phase_write regex bug`**
  - **#11/#12**（断言 artifacts.sh 含 phase 正则/case · 实测不含）→ **skip + 注释 `# TD-016 测试断言债`**
  - **#23**（断言 F29 含 sha256sum · 实测不含）→ **skip + 注释 `# TD-016 测试断言债`**
- **验证方式**: `grep -cE '# TD-014|# TD-016' test/test_gate_integrity.bats`（归因注释 ≥5 · L3 可验证）+ #8 helper 含 `artifacts=` KVP（`grep 'artifacts=' test_gate_integrity.bats`）

### AC-7 · TD-013 标 resolved
- **Given** AC-1~6 全过（7-integration）
- **When** 更新 CONTEXT
- **Then** TD-013 标 ✅ resolved（含证据：L2/L3 实测 + 反向断言 + v1 内全绿）
- **验证方式**: `grep 'TD-013' .specs/CONTEXT.md`（含 resolved）

---

## 范围切分

### v1（本次必做 · 含 helper 源码修 · L3 scope 修正）
- setup 去 set+e（AC-1 · 两副本 · 原子）
- setup 补 HOOK_BASE_DIR（AC-5）
- **helper write_valid_done 补 artifacts= KVP**（AC-6 #8 · 源码修）
- 测试体强制 run+$status（AC-2 · 禁 if!fn）
- 范围外 skip + 归因注释（#19/#20 TD-014 / #11/#12/#23 TD-016 · AC-3/AC-6）
- make test v1 内全绿（AC-3）+ 反向断言（AC-4）
- TD-013 resolved（AC-7）

### v2（下一轮）
- TD-016 断言债重新裁定（修实现/修断言/删过时测试）
- 共享测试 setup lib 抽取（TD-004/005）
- Makefile test target 管道 exit code 加固（TD-012 遗留）

### out（永远不做）
- 碰 gate 逻辑 is_phase_write（TD-014 · #19/#20 skip 归因）
- 其他测试文件 set+e（grep 确认仅 test_gate_integrity）
- 基线 warning（SC1090/SC2034）

---

## 非功能性需求
- **性能**：无 · **可访问性**：无 · **安全**：无新增风险（提升测试可信间接提升 gate 安全）
- **兼容性**：bats-core 1.13.0 + bash 5（CI）
- **可观测性**：测试失败清晰报错（去 set+e 后 bats 报 not ok + 行号）

## 依赖与假设
- **依赖**：TD-012（GATE_SH 路径修复）—— v4 修正：TD-012 没碰 HOOK_BASE_DIR，本 change AC-5 自行补
- **假设**：补 HOOK_BASE_DIR 后 done-validation.sh 加载（实测 ✓）
- **战略**：TD-014 前置

---

> AC 是 TEST 派生唯一来源。v4 已合并 L2 两轮 + L3 全部发现，降挡直接实施。
