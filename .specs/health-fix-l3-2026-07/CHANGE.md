# CHANGE — L3 审计子系统健康修复

## Why

2026-07-11 L3 审计专项健康巡检评分 **72/100**，发现 3🔴 Critical + 6🟡 Warning + 3🟢 Suggestion 共 12 项风险。上次 sweep（2026-07-10）已验证拆分模式有效（`l3_review_run` 307→44 行、`is_gh_pr_create` 290→7 行），本次将相同的拆分模式应用到剩余长函数和已知技术债。

**触发来源**: `.specs/health/2026-07-11-L3-AUDIT-HEALTH.md`

## What

一次性清理 L3 审计子系统所有已知代码质量问题：

### 🔴 Critical（3 项）

1. **拆分 `_gate_phase_transition()` 122 行** (`independent-review-gate.sh:184-305`)
   - 6 职责合并 → 拆为 `_gate_check_l2()` / `_gate_check_l3()` / `_gate_do_transition()`
2. **降级 `fk_fix_compliance_check()` 126 行** (`fix-compliance.sh:178-303`)
   - 子阶段函数已存在 → 提取主流程为编排层
3. **解环 correction-file ↔ interactive-ui-check ↔ weak-model-compliance 三向依赖环** (L-021)
   - 提取 `correction-types.sh` 共享接口

### 🟡 Warning（6 项）

4. **拆分 `smart_truncate()` 112 行** (`l3-review.sh:50-161`) → 按 header/artifact/CHANGELOG/优先级拆子函数
5. **拆分 `_l3_parse_result()` 82 行** (`l3-review.sh:315-396`) → 解析/校验/归档分离
6. **拆分 `_l3_build_prompt()` 85 行** (`l3-review.sh:162-246`) → system/user/artifact 三段
7. **DRY phase_name 映射** → `common.sh` 加 `PHASE_GATE_KEY_MAP` 关联数组 (L-new-2)
8. **消除 prompt jq goal 解析重复** → 抽取 `_shared/` 片段 (TD-005)
9. **补齐 timeout 路径测试** → 添加 `test_l3_timeout.bats`

### 🟢 Suggestion（3 项）

10. **修复 `source "$0"` self-sourcing 脆弱模式** (`l3-review.sh:511`) → 使用 `$HOOK_BASE_DIR/lib/l3-review.sh` 绝对路径
11. **29-independent-review.sh 函数化** → 提取 `_check_l2_complete()` / `_resolve_gate_value()` / `_dispatch_l3_review()`
12. **清理 3 个死代码函数** → `estimate_tokens()` / `read_correction_file()` / `file_not_empty()`（已入 CONTEXT 清理窗口）

## 影响面

- [x] 需更新 REQUIREMENT.md（本次有明确验收标准）
- [x] 触及核心 hook/lib 代码，需 DESIGN.md
- [x] 改动 6 个 hook/lib 源文件 + 测试补齐
- [x] 不涉及 ADR 变更（架构不变，只重构内部实现）
- [x] 不涉及 CONTEXT.md 禁动清单条目（所有改动在禁动清单允许范围内）

**触碰模块**（仅在 `flow-kit-bundle/` 维护源上修改）：
- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`
- `flow-kit-bundle/hooks/stop/29-independent-review.sh`
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh`
- `flow-kit-bundle/hooks/stop/lib/fix-compliance.sh`
- `flow-kit-bundle/hooks/stop/lib/done-validation.sh`
- `flow-kit-bundle/hooks/stop/lib/common.sh`
- `flow-kit-bundle/hooks/stop/lib/correction-file.sh`（解环）
- `flow-kit-bundle/hooks/stop/lib/interactive-ui-check.sh`（解环）
- `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh`（解环）
- `flow-kit-bundle/hooks/stop/lib/transcript-parser.sh`（删死代码）
- `test/test_l3_timeout.bats`（新增）
- `flow-kit-bundle/flow-kit/prompts/6-review.md`（DRY jq 解析）
- `flow-kit-bundle/flow-kit/prompts/7-integration.md`（DRY jq 解析）

## 范围排除

- ❌ 不新增 hook 模块（不改变 Stop hook 编号和加载顺序）
- ❌ 不改动 gate 校验逻辑本身（只重构函数结构，行为不变）
- ❌ 不改动 PreToolUse matcher 配置
- ❌ 不修改 `.flow-active` schema
- ❌ 不修改 `package-flow-kit.sh` 打包脚本
- ❌ 不修改 `install.sh` / `install_hooks.sh`
- ❌ 不修改 `.specs/CONTEXT.md` 禁动清单（只追加清理确认）
- ❌ `fk_validate_done_marker()` 80 行和 `fk_independent_review_gate_active()` 62 行保持现状（gate 判定内聚性高，拆分增加调用复杂度）

## 验收线

1. **AC-1 长函数拆分**: 拆分后所有函数 ≤ 60 行，`_gate_phase_transition` ≤ 50 行
2. **AC-2 依赖环消除**: jscpd/circular-deps 检测不再报告 correction-file ↔ UI ↔ compliance 循环
3. **AC-3 行为零回归**: `npx bats test/` 全量通过（含新增 timeout 测试），现有 128 个 L3 测试 0 fail
4. **AC-4 bash -n 语法门禁**: 所有修改的 `.sh` 通过 `bash -n`

## 路径建议

**完整路径**: `REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION`

理由：改动涉及 10+ 源文件 + 依赖环解环 + 新增测试，需要 DESIGN 规划重构顺序和接口契约，需要 REQUIREMENT 明确每个函数的验收标准。
