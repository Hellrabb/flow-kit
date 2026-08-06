# INDEPENDENT-REVIEW-5 — health-debt-cleanup

> Phase 5 (test) · L2 独立盲审

## L2 盲审

> 审查日期：2026-07-20 | 阶段：5 | change-id：health-debt-cleanup | 独立 L2 Agent

### 审查发现

| # | 维度 | 发现 | 级别 |
|---|------|------|------|
| 1 | T2/T3 | **AC-1 验收声明虚假**：TEST.md 声称 `grep -r 'check_g[0-9]\b' flow-kit-bundle/hooks/ --include='*.sh' | grep -v fk_check_gate` 返回"零命中 ✅"。实际执行返回 **11 行命中**（5 个新 thin wrapper 定义行 `_fk_check_g1() {` + 5 个调用行 `_fk_check_g1` + 1 个注释引用）。`\b` 边界正确排除了 `_fk_check_g1_body`（数字后接 `_` 为非边界），但 `_fk_check_g1() {` 中数字后接 `(` 为边界，故命中。`grep -v fk_check_gate` 过滤器匹配的是字面 `fk_check_gate`，无法过滤 `_fk_check_g1` 至 `_fk_check_g5`。重命名本身正确（旧名零残留），但 TEST.md 的验收校验编写错误。 | 🔴 Critical |
| 2 | T1/T2 | **假绿测试（fake green）**：`test_install_coverage.bats` 第 209-226 行，`install_brooks_tools DRY_RUN: PATH warning when .local/bin not in PATH` 测试用例中，唯一的非状态断言为 `true`（第 225 行）。注释写"Should mention PATH or .local/bin or continue without warning"，但实际无任何断言验证 PATH warning 行为。此测试**无条件通过**，形同虚设。 | 🔴 Critical |
| 3 | T3 | **测试矩阵数字多处不实**：TEST.md 声称总计 559 cases，实际 `test/` 目录含 585 个 `@test` 注解（`grep -ro '@test' test/ --include='*.bats' | wc -l`）。具体项：(a) `test_install_dry_run.bats` 报告 8 cases，实际 **4** cases；(b) `test_install_brooks_tools.bats` 报告 8 cases，实际 **5** cases。其余文件报告 516，实际 549。差值 26 cases，表明 TEST.md 为手写估算、未经实际执行验证。 | 🟡 Major |
| 4 | T3 | **回归安全无独立验证**：559/0（实为 585/0）声明完全基于主 agent 自评。无 CI 输出日志、无 `make test` 执行时间戳、无 bats TAP 输出附件。虽然重命名变更纯属符号替换、逻辑上不影响测试结果，但缺乏可复现的执行证据。 | 🟡 Major |
| 5 | T1 | **测试覆盖表面化（DRY_RUN 依赖过度）**：16 个新增 cases 中 14 个仅测试 DRY_RUN 模式（输出包含 `[DRY-RUN]` 即判定通过）。只有 `install_file` 的 1 个 case 测试了非 DRY_RUN 的真实安装行为（文件实际复制）。文件头部声称覆盖 `install_brooks_lint(jq fallback)`，但**零个测试涉及 jq fallback 路径**。AC-2 要求覆盖"关键路径"，当前覆盖率仅触及 dry-run echo 表层。 | 🟡 Major |
| 6 | T4 | **测试文件双副本（知识重复）**：`test_install_coverage.bats` 同时存在于 `test/` 和 `flow-kit-bundle/test/`，内容完全相同（261 行，diff 确认一致）。虽然 Makefile 有 `test-sync` 同步目标，但双副本造成维护负担：修改任一副本需手工同步，否则 `make check-test-sync` 阻断。 | 🟢 Minor |
| 7 | T5 | **AC-1 grep 过滤器 `grep -v fk_check_gate` 名不副实**：该过滤器意在排除合法的 `fk_check_gate` 引用，但实际 `check_g[0-9]\b` 命中行均不含 `fk_check_gate` 子串（含的是 `fk_check_g1`..`fk_check_g5`），过滤器形同虚设。正确的排除模式应为 `grep -vE 'fk_check_g[0-9]+'` 或直接承认新命名仍命中并说明原因。 | 🟢 Minor |
| 8 | T6 | **测试命名非严格 Given-When-Then**：测试名采用 `Function Mode: expected behavior` 格式（如 `install_flow_kit_core DRY_RUN: exit 0 and output contains [DRY-RUN]`），部分 case 更接近 GWT（如 `install_specs_template: skips when .specs/ already exists`），但整体不统一。符合 bats 社区惯例，但未达到严格 GWT 标准。 | 🟢 Minor |
| 9 | T1 | **TEST.md 与 CHANGE.md AC-1 表述不一致**：CHANGE.md AC-1 明确写"`grep -r 'check_g[0-9]' flow-kit-bundle/` 零命中（仅定义处 + bats 测试用例名保留）"，语义正确——承认新命名 `_fk_check_g*` 的**定义行**仍含子串 `check_g[0-9]`。但 TEST.md 自行添加 `\b` 边界和 `grep -v fk_check_gate` 过滤器并声称"零命中"，与 CHANGE.md 的宽松语义和实际 grep 结果均矛盾。 | 🟢 Minor |

### 额外发现（不在 6 维内，但需记录）

- **双重前缀 bug 已修复**：REVIEW.md 记录的重命名批处理引入的 `_fk__fk_file_age_days` 双重前缀问题，经全仓 grep 确认已清除（`grep -rn '_fk__fk' flow-kit-bundle/` 零命中）。
- **DRY_RUN 模式确实存在**：4 个 install lib 文件均包含 `if [ "${DRY_RUN:-false}" = true ]; then` 守卫，DRY_RUN 非测试桩虚构，是生产代码的真实行为。
- **先前的 L2 调度记录**：`.l2-dispatch-5.log` 存在（133 字节），记录"Agent completed, result written to INDEPENDENT-REVIEW-5.md"，但该文件实际不存在。疑似前次调度失败或文件被清除后重试。
- **test_install_coverage.bats 实际 261 行 vs REVIEW.md 声称 175 行**：REVIEW.md 记录"test_install_coverage.bats 新建（16 bats cases）+175"，但实际文件为 261 行。可能是初版 175 行后追加到 261 行但 REVIEW.md 未更新。

### 总结

**Verdict**: ❌ FAIL — 2 Critical / 3 Major / 4 Minor

**阻断理由**：
1. **AC-1 验收声明虚假**（Critical）：TEST.md 声称的关键验收条件（check_g* 零命中 grep）经验证不成立。虽然重命名本身正确执行，但 TEST.md 的验证方法是错误的且报告了虚假的"通过"。需修正 AC-1 的 grep 命令或如实记录 11 行命中均为新命名的合法残留（定义行 + 调用行 + 注释引用）。
2. **假绿测试**（Critical）：`install_brooks_tools PATH warning` 测试用例以 `true` 作为唯一内容断言，形同虚设。需补充实际的 PATH warning 验证逻辑（如 `[[ "$output" =~ PATH ]] || [[ "$output" =~ \.local/bin ]]`）。

**修复后可达标路径**：
- 将 Critical #1 改为如实记录：AC-1 命中 11 行均为新命名 `_fk_check_g1`..`_fk_check_g5` 的定义 + 调用，无旧名残留，验收通过（仅文档修正）。
- 将 Critical #2 的 `true` 替换为实际断言，验证 PATH 警告或 graceful continue 行为。
- 修正 TEST.md 测试矩阵数字（585 替代 559，修正各文件 cases 数）。
