# TEST: 修复 2026-07-01 全量健康扫描发现的 6 项技术债

- **Change ID**: sweep-fix-2026-07
- **测试日期**: 2026-07-01
- **关联**: `@.specs/sweep-fix-2026-07/REQUIREMENT.md`、`@.specs/sweep-fix-2026-07/TASK.md`

---

## 本次测试范围声明

| 轮次 | 状态 | 范围 | 跳过理由 |
|------|------|------|----------|
| 第 1 轮 · 功能 | ✅ 必跑 | 全部 6 AC + bash -n 全量语法 + bats 单元测试 | — |
| 第 2 轮 · 性能 | ❌ 跳过 | — | Bash 脚本维护性重构，无性能预算定义，无运行时热点 |
| 第 3 轮 · 安全 | ❌ 跳过 | — | 无新增依赖/秘钥；不改外部 API/网络边界；shell 脚本非网络服务 |
| 第 4 轮 · 兼容 | ❌ 跳过 | — | 非 Web 项目；无 schema/data 变更；无跨版本 API |
| 第 5 轮 · 可观测 | ❌ 跳过 | — | Shell 脚本无运行时，无日志/指标/告警需求 |

---

## 第 1 轮 · 功能测试

### 1.1 测试矩阵

| AC | 类型 | 用例文件 / 验证命令 | 状态 |
|----|------|---------------------|------|
| AC-1 | unit | `bash -n` + `grep -c "HOOK_MODULE_NAMES" install_hooks.sh package-flow-kit.sh` | ✅ |
| AC-2 | unit | `bash -n flow-kit-artifacts.sh` + `grep -c "PHASE_ARTIFACTS"` | ✅ |
| AC-3 | unit | `test_correction_file.bats` (10 tests) | ✅ 10/10 |
| AC-4 | integration | `bats --version` + `test -f test_flow_kit_resume.bats test_stop_report_reminder.bats` | ✅ |
| AC-5 | unit | `grep -c "module_output" hooks/stop/[0-9][0-9]-*.sh` — 11/11 findings hooks | ✅ |
| AC-6 | unit | `grep -A1 "MIN_MEANINGFUL_LINES" flow-kit-artifacts.sh \| grep "#"` | ✅ |

### 1.2 语法门禁（bash -n 全量）

```
✅ 35 个 .sh 文件全部通过 bash -n（0 错误）
```

### 1.3 bats 单元测试

```
$ bats test/test_correction_file.bats
1..10
ok 1 correction_file_exists returns 1 for missing file
ok 2 correction_file_exists returns 0 for valid JSON file
ok 3 correction_file_exists returns 1 for invalid JSON
ok 4 correction_file_read returns {} for missing file
ok 5 correction_file_read returns file content for existing file
ok 6 correction_file_write with overwrite strategy writes file
ok 7 correction_file_write overwrite replaces previous content
ok 8 correction_file_write with merge strategy deduplicates by fields
ok 9 correction_file_clear removes file
ok 10 round-trip: write → read → clear → exists

10 tests, 0 failures
```

### 1.4 测试质量自检 · 6 维测试衰退风险

路径 B（内置清单）— brooks-lint brooks-test skill 可用但本 change 为非 Web 脚本项目，手动逐维检查：

| 维度 | 检查项 | 状态 |
|------|--------|------|
| T1 | 测试名清楚表达场景（如 `correction_file_exists returns 1 for missing file`） | ✅ |
| T2 | 测试验证行为而非实现细节（assert JSON values via jq -r, not string comparison） | ✅ |
| T3 | 测试无重复场景——每条覆盖不同行为（exists/write/overwrite/merge/clear/read/roundtrip） | ✅ |
| T4 | 无 mock 使用——直接操作文件系统（shell 测试天然集成） | ✅ |
| T5 | 每条测试有真实断言（status check + output verification, 非空断言） | ✅ |
| T6 | 测试层级合理——单元测试覆盖 lib 函数（非 e2e 验证 shell 函数） | ✅ |

**测试质量结论**: ✅ 0 命中。10 条测试覆盖 correction file lib 的全部 4 个函数 + 边界条件（空文件/无效 JSON/merge dedup/roundtrip）。

---

## 回归测试登记

| 测试文件 | 类型 | 覆盖范围 | 状态 |
|----------|------|----------|------|
| `test/test_correction_file.bats` | 新增 unit | correction-file.sh 全部 4 函数 | ✅ 10/10 |
| `test/test_flow_kit_resume.bats` | 新增 unit | flow-kit-resume.sh 关键分支 | ✅ 已创建 |
| `test/test_stop_report_reminder.bats` | 新增 unit | stop-report-reminder.sh 关键分支 | ✅ 已创建 |
| `test/test_smoke_syntax.bats` | 现有 | 全量 bash -n 语法 | ✅ 35/35 |
| 全量 bash -n | 现有门禁 | 所有 .sh 文件 | ✅ 0 错误 |
