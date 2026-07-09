# TEST: td-test-infra · 5 轮测试金字塔

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由 |
|---|---|---|---|
| 第 1 轮 功能 | ✅ 必跑 | AC-1/2/3/4（bats + make dup + grep）| — |
| 第 2 轮 性能 | ❌ 跳过 | — | Bash 脚本 + Makefile target，无性能预算（NFR 性能=无）；`make dup` 手动跑不进构建关键路径 |
| 第 3 轮 安全 | ❌ 跳过 | — | 测试/工具基础设施（NFR 安全=无）；jscpd 只读扫描；无秘钥/无新依赖（brooks-tools 已打包）|
| 第 4 轮 兼容 | ⚠️ 部分 | GNU make + jscpd 版本 | 无 schema/迁移；兼容性 = jscpd 版本漂移 warn（NFR R7 已处理）|
| 第 5 轮 可观测 | ⚠️ 部分 | make dup stdout/stderr | 无运行时 metric/告警；可观测 = dup 输出契约（NFR R7 stdout/stderr）|

## 第 1 轮 · 功能测试

### 1.1 测试矩阵

| AC | 类型 | 用例 | 状态 |
|---|---|---|---|
| AC-1 make dup | integration | `make dup; echo exit=$?` + awk 提取 dup recipe 校验 4 ignore 模式 | ✅ pass（exit 0 + brooks-lint/brooks-tools/test/regression-demos）|
| AC-2 SUMMARY 17 行 | unit | `[ "$(grep -cE '...' SUMMARY.md)" -eq 17 ]` + 唯一性 `[ "$(awk -F'\|' 'NR>2{print $2}' SUMMARY.md | sort -u | wc -l)" -eq 17 ]`（L2 R1 增强）| ✅ pass（17 行 + 17 唯一脚本名）|
| AC-3 补 smoke | unit | `bats test_stop_chain.bats`（31 测试）+ `diff -r test/ flow-kit-bundle/test/` | ✅ pass（31 全绿 + 双源一致）|
| AC-4 CONTEXT+回归 | integration | `grep TD-002\|TD-010 CONTEXT` + `bats test/`（419）| ✅ pass（TD-002/010 ✅ + 419 全绿）|

每条 AC ≥ 1 覆盖 ✅。

### 1.3 覆盖率与边界

- `bats test/` **419 全绿 exit 0**（401 基线 + T03 18 新 smoke）
- 边界：make dup 未装 jscpd → graceful skip（stderr + exit 0）；SUMMARY covered/partial/gap 三态
- **AC-3 止损判断矩阵**（L2 R2 · 明确 skip 时机）：
  - `bash -n $script` 失败（语法错）→ skip + 注"语法错误需修复脚本"（非 smoke 范围）
  - grep 关键函数失败 + 函数确实不存在 → skip + 注"函数不存在需重新设计脚本"
  - grep 关键函数失败 + 函数存在但命名不符 → **不 skip**，修正 grep 模式
  - smoke 断言返回码非 0 + 函数调用失败 → **不 skip**，修正断言
  - 本次 T03 实际：6 脚本全 pass（无 skip 触发）

### 1.4 测试质量自检 · 6 维

| 维度 | 诊断 | 命中 |
|---|---|---|
| T1 晦涩 | smoke 名清晰（"23-quality.sh 语法正确"）| ✅ 无 |
| T2 脆弱 | grep 关键函数（重构改名会坏，但 smoke 本验存在）| ⚠️ 可接受（smoke 目的=验关键函数存在）|
| T3 重复 | 6 脚本 × 3 测试（bash-n/shebang/grep）模式重复 | ⚠️ 命中（可参数化优化，但沿用 test_stop_chain 既有范式保一致）|
| T4 mock | 无 mock | ✅ 无 |
| T5 覆盖率幻觉 | grep -q 断言（验存在，非空断言）| ✅ 无 |
| T6 架构错配 | smoke 结构层（bash-n+grep）匹配主脚本（非逻辑层 · D2）| ✅ 无 |

**T3 命中 1 项** → 测试质量记事：test_stop_chain 的 6 段 smoke 可参数化（table-driven），非紧急，留 backlog。

## 第 4 轮 · 兼容（部分）

- GNU make + jscpd 5.0.11（已打包 brooks-tools）
- jscpd 版本 ≠ 5.0.11 → warn 不 fail（NFR R7）
- 无 schema/迁移

## 第 5 轮 · 可观测（部分）

- `make dup` 扫描结果走 stdout，skip/警告走 stderr（NFR R7）
- 无运行时 metric/告警（CLI/工具性质）

## 回归测试登记

**新增（T03 · stop 链 smoke）**：
- `test/test_stop_chain.bats` + `flow-kit-bundle/test/test_stop_chain.bats`：+18 smoke（23/27/28/29/30/33 × bash-n/shebang/grep）
- 总测试 401→419（+18）

**新增（TD-010 · Makefile）**：
- `Makefile` dup target（手动 `make dup` 验证，非 bats 自动化）
