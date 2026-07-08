# Brooks-Lint — Full Sweep Report

- **Mode**: Full Sweep
- **Scope**: ~174 files（flow-kit-bundle `.sh`/`.bats` + `prompts/templates/reference` .md，排 archive/.specs/第三方 brooks-lint/brooks-tools）
- **Config**: 无 `.brooks-lint.yaml`（默认配置）
- **日期**: 2026-07-08
- **触发**: health-cleanup-2026-07-08 归档后用户要求独立 /brooks-sweep

## Dimension Summary

| Dimension | Scanned | Safe Applied | Extended Applied | Reverted | Residual |
|-----------|---------|--------------|------------------|----------|----------|
| Review (R1–R6) | 60 .sh | 0 | 0 | 0 | 8 |
| Test (T1–T6)   | 38 .bats | 0 | 0 | 0 | 2 |
| Debt           | 全仓 | 0 | 0 | 0 | 5（已知 TD）|
| Audit          | hooks 模块 | 0 | 0 | 0 | 0（依赖单向无循环）|

## Iteration History

- **Round 1**: clean（无 Safe 修复可应用——新 findings 全 Residual：大函数拆分/抽公共需测试验证，但 `make test` 既有 fail 致 Extended-Safe 验证失效）
- **Stopped at**: clean round（fix_log 空 → 无修改 → 无 re-scan scope）

## Fix Log

**空**——0 Safe 修复应用。

原因：所有新 findings 是大函数拆分 / 抽公共代码（多文件或改核心逻辑），非单文件局部 Safe。Extended-Safe 要求 `make test` pre-fix 通过，但 TD-012 致 `make test` fail（30+ 既有 fail）→ Extended-Safe 全 revert → Residual。

## Health Score

- **Before**: ~33/100（brooks 体系估算）
- **After**: ~33/100（无修复应用，无变化）
- **扣分**: 🔴×2（TD-011/012，-30）+ 🟡×7（TD-008/004/005/L-025 + 新R1×3，-35）+ 🟢×2（新R3×2，-2）

## Residual Items（11 not applied）

### 🔴 Critical

1. **TD-012** · `test/` 10+ 文件 setup 路径缺 `flow-kit-bundle/` 层 → 30+ 测试 BW01 127 fail（T2 Test Brittleness）
   - Not applied: 跨 10+ 文件 + 需 Makefile test target 改 → Residual（已开 `test-setup-path-fix-2026-07`）
2. **TD-011** · `independent-review-gate.sh:68` `&&` 被 `[[ ]]` 当逻辑与，`is_phase_write` 检测失效（R4/R6）
   - Not applied: 禁动清单 gate 核心 + 需改逻辑重测 → Residual（已开 `refactor-independent-review-gate`）

### 🟡 Warning

3. **TD-008** · `l3-review.sh` `l3_review_run` 259行 + `smart_truncate` 107行（R1 Cognitive Overload）
   - Not applied: 重构需 DESIGN + 测试 → Residual（已开 `refactor-l3-review-split`）
4. **R1** · `fix-compliance.sh:178` `fk_fix_compliance_check` 124行（**新发现**）
   - Not applied: 实效性校验核心逻辑，拆分需测试 → Residual
5. **R1** · `transcript-parser.sh:9` `parse_transcript` 94行（**新发现**）
   - Not applied: 解析逻辑长，拆分需测试 → Residual
6. **R1** · `26-workflow.sh:38` `check_g1` 94行（**新发现**）
   - Not applied: G1 检查逻辑，拆分需测试 → Residual
7. **TD-004** · `prompts/*.md` 样板重复 22%（R3）
   - Not applied: 抽 `_shared/` 需重构 → Residual
8. **TD-005** · `6-review`/`7-integration` jq 重复 68行（R3）
   - Not applied: 抽共享片段 → Residual
9. **L-025** · test setup `|| true` 静默吞 source 失败（T6）
   - Not applied: `|| true` 是合理容错（移除破坏 27 测试），需 AC-4 函数定义断言替代 → Residual

### 🟢 Suggestion

10. **R3** · `27-interactive-ui-check.sh:23-31` ↔ `28-weak-model-compliance.sh:19-27` 9行重复（**新发现**）
    - Not applied: 抽公共 setup → Residual
11. **R3** · `l3-review.sh:386-399` ↔ `477-490` 14行重复（属 TD-008 范围）
    - Not applied: 同 TD-008 拆分 → Residual

## Summary

- Total findings detected: 11（2 Critical + 7 Warning + 2 Suggestion）
- Fixed this sweep: 0（无 Safe 修复；Extended-Safe 因 `make test` fail 失效）
- Residual (needs human review): 11
- Unresolvable (3-retry exhausted): 0

## Caveats（重要 · 解读本报告必读）

1. **bash/markdown 适配有限**：brooks 6 维（deep modules / DDD / clean architecture）面向 OOP 代码架构，对 flow-kit 的 bash hook + markdown prompt 适配性有限。R 维主要落 `.sh`，prompt 层只 R3（重复）适用。之前 M-health 报告已说明"对纯 Bash 项目，确定性工具（bash-n/jscpd/bats 实跑）比 brooks 通用 6 维更贴切"。
2. **`make test` fail 致修复失效**：TD-012 的 30+ 既有 fail 让 Extended-Safe 验证（Step 2e 跑 `make test`）失败 → 所有 Extended-Safe 修复 revert → sweep 退化为**纯诊断**（0 修复）。这是本 sweep 最大的结构性限制。
3. **Health Score 33 vs flow-kit 自评 84/96**：差异因①体系不同（brooks 严格计 Critical -15）②TD-012 刚发现（之前 health 用 `bats|tail` 误判全绿，L-027）。**不建议直接对比**两个体系的分数。
4. **多数 findings 已知**：11 个 Residual 中 6 个是已记 TD（008/011/012/004/005 + L-025），sweep 重复确认。**新发现仅 5 个**（R1×3 大函数 + R3×2 重复，均 Minor Suggestion/Warning）。
5. **建议**：先跑 `test-setup-path-fix-2026-07` 让 `make test` 真绿，再重跑 sweep——届时 Extended-Safe 修复能生效，sweep 才有真修复价值（当前 sweep = 诊断快照）。

**Mode: Full Sweep**
