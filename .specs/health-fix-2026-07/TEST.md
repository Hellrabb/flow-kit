# TEST: 2026-07 健康修复

- **Change ID**: `health-fix-2026-07`
- **关联**: `@.specs/health-fix-2026-07/REQUIREMENT.md`

---

## 测试矩阵

| AC | 描述 | 验证方式 | 结果 |
|---|---|---|---|
| AC-1 | 循环依赖消除 — 引用方向 DAG | `grep` 验证 correction-file 无反引用 | ✅ 0 反向 source |
| AC-2 | 循环依赖消除 — 测试无回归 | `make test` (309 bats) | ✅ 309/309 |
| AC-3 | jq 重复消除 — 单一来源 | `grep` 确认双 prompt 无内联 jq | ✅ 0 matches |
| AC-4 | jq 重复消除 — 包完整性 | `package-flow-kit.sh --validate` | ✅ 0 漏配 0 警告 |
| AC-5 | flow-kit-artifacts 拆分 — 职责分离 | `make test` + grep 调用方无改动 | ✅ 全过 |
| AC-6 | flow-kit-artifacts 拆分 — 包校验 | `--validate` 覆盖新文件 | ✅ done-validation.sh 已覆盖 |
| AC-7 | package-flow-kit 拆分 — 函数独立 | `--validate` 输出一致 | ✅ 0 errors |
| AC-8 | 全局 — 双源同步 | `make check-test-sync` | ✅ 一致 |

---

## 测试执行

```bash
# 全量 bats 测试
$ npx bats test/
309 tests, 0 failures, 0 skipped

# bash -n 语法检查
$ find . -name '*.sh' -not -path '*/.git/*' ... -exec bash -n {} \;
57 scripts, 0 errors

# 包完整性
$ bash package-flow-kit.sh --validate
🔴 漏配 (ERROR): 0
⚠️  源缺失 (WARNING): 0
✅ 校验通过：所有文件均被 Part A~G 覆盖。

# 双源同步
$ diff -rq test/ flow-kit-bundle/test/
(no differences)
```

---

## 非功能性验证

| 维度 | 结果 |
|---|---|
| 性能 | 无变化（lib 拆分不改变运行时路径） |
| 兼容性 | 向后兼容—所有调用方 source 路径不变 |
| 安全 | 无新增安全面 |
| bash 语法 | 57 个 .sh 全过 ✅ |

---

## 测试覆盖分析

| 模块 | 测试文件 | 覆盖 |
|---|---|---|
| correction-file.sh | `test_correction_file.bats` (10 tests) | write/read/clear/exists + merge 策略 |
| interactive-ui-check.sh | `test_interactive_ui_check.bats` (17 tests) | write/read/clear/has + retry_count + should_inject |
| weak-model-compliance.sh | `test_weak_model_compliance.bats` (3 CF tests) | write_compliance_correction merge + dedup |
| flow-kit-artifacts.sh | `test_flow_artifacts.bats` + `test_gate_integrity.bats` | fk_artifact_check + fk_validate_done_marker |
| done-validation.sh (NEW) | 通过 flow-kit-artifacts 聚合入口间接覆盖 | fk_independent_review_gate_active + fk_validate_done_marker |
| validate_staging.sh (NEW) | `test_package_flow_kit.bats` + `test_lessons_cleanup.bats` | --validate entry |
| pipeline-goal-parser.md (NEW) | `test_phase_gate.bats` (AC-6) | prompt 引用验证 |
