# CHANGE: 2026-07 健康修复 — 循环依赖 + 重复代码 + 大文件拆分

- **Change ID**: `health-fix-2026-07`
- **创建日期**: 2026-07-04
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

2026-07-04 健康巡检（brooks-health 92/100）发现 4 项技术债，其中 1 项 🔴 Critical：

1. **🔴 L-021**：`correction-file.sh` ↔ `interactive-ui-check.sh` ↔ `weak-model-compliance.sh` 三个 lib 模块形成双向依赖环，违反 Acyclic Dependencies Principle。任一模块改动可级联破坏其他模块，单元测试隔离困难。
2. **🟡 TD-005**：jq pipeline goal 解析逻辑（68 行）在 `6-review.md` 和 `7-integration.md` 两个 prompt 中逐字重复。解析逻辑变更时须手动同步两份文件。
3. **🟢 L-016**：`flow-kit-artifacts.sh`（515 行，13 函数）混合了 artifact-check / auto-phase / done-validation / stale-check / boundary-check / snapshot / progress / token 共 8 个职责。
4. **🟢 L-017**：`package-flow-kit.sh`（610 行）中 `validate_staging_coverage()` 函数（~100 行）独立于主打包流程。

## What（做什么）

一次性修复健康报告的全部 4 项技术债：

- **L-021**：中度重构 lib 依赖——提取 `correction-file.sh` / `interactive-ui-check.sh` / `weak-model-compliance.sh` 三方共享的最小接口，打破双向耦合
- **TD-005**：将 jq pipeline goal 解析逻辑提取到 `flow-kit/reference/` 共享片段，6-review 和 7-integration prompt 改为引用
- **L-016**：按职责拆 `flow-kit-artifacts.sh` 为 3 个子库（artifact-check / auto-phase / done-validation），保持函数签名兼容
- **L-017**：从 `package-flow-kit.sh` 拆出 `validate_staging_coverage()` 为独立 lib 文件

## 影响面

- [x] 影响 `DESIGN.md` / 引入新 ADR（lib 模块依赖方向调整，需在 DESIGN § 9.1 记录）
- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改 stop hook 执行链架构（00-gate → 99-report 编号顺序加载机制不变）
- 不改 `common.sh` 的 HOOK_MODULE_NAMES 注册机制（L-020 已独立跟踪）
- 不改 `correction_file_write()` 的 overwrite → merge 策略升级（L-019 已独立跟踪）
- 不新增功能，不修改用户可见行为
- 不引入新的外部依赖

## 验收线（粗粒度，不是 AC）

1. **循环依赖消除**：`correction-file.sh` / `interactive-ui-check.sh` / `weak-model-compliance.sh` 之间无双向引用（grep 验证引用方向为单向 DAG）
2. **测试全过**：`make test` 全部 53+ bats 测试通过，无回归
3. **jq 重复消除**：pipeline goal 解析逻辑在 6-review 和 7-integration 中均引用同一共享片段，无逐字重复

## 风险与未知

- **中度重构风险**：lib 依赖方向调整可能影响多个 stop hook 模块（27/28/29/33 号均引用这些 lib），需逐模块验证
- **测试覆盖**：`test_interactive_ui_check.bats`（201 行，17 tests）和 `test_correction_file.bats`（92 行）覆盖了相关模块，但重构后可能需要更新测试路径
- **bundle 同步**：改动需同步到 `flow-kit-bundle/` 下的对应源文件，并确保 `package-flow-kit.sh --validate` 通过

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
