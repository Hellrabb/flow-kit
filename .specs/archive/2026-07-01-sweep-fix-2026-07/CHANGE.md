# CHANGE: 修复 2026-07-01 全量健康扫描发现的 6 项技术债

- **Change ID**: sweep-fix-2026-07
- **创建日期**: 2026-07-01
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

2026-07-01 全量健康扫描（`2026-07-01-FULL-SWEEP.md`）评分 68/100，发现 1🔴 + 3🟡 + 2🟢 共 6 项代码衰减风险。其中 🔴 Critical（hook 模块名列表在两处重复维护）是典型的"改一处忘另一处"陷阱——新增 hook 模块只更新一处会导致静默遗漏。其余 🟡 Warning 涉及大文件认知负荷和跨 lib 的结构重复，🟢 Suggestion 为格式一致性和魔法数字注释缺失。自上次 Full Sweep（6/16 评分 62）以来趋势向好（+6），本次修复将进一步消除剩余风险、提升项目长期可维护性。

## What（做什么）

对 6 项健康扫描发现逐一修复：
1. 🔴 Hook 模块名列表去重：提取共享列表到 `common.sh` 或独立配置
2. 🟡 `flow-kit-artifacts.sh` 的 `fk_artifact_check()` 改为查表驱动（关联数组）
3. 🟡 Correction file 管理统一：提取 `lib/correction-file.sh`
4. 🟡 安装 bats-core + 为 SessionStart hooks 补齐测试
5. 🟢 Hook 输出格式审计：统一为 `module_output()` 调用
6. 🟢 `MIN_MEANINGFUL_LINES=3` 加注释说明阈值依据

## 影响面

- [x] 影响 `REQUIREMENT.md`（需定义验收准则）
- [x] 影响 `DESIGN.md` / 引入新 ADR（correction file API 设计、hook 列表提取模式）
- [ ] 影响现有 AC（无现有 AC 被修改）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不做 `package-flow-kit.sh` 大拆分（589 行→多文件）— 仅做 hook 列表去重，完整拆分留给后续 change
- 不做 `flow-kit-artifacts.sh` 拆分为多 lib 文件 — 仅做查表驱动改造（低风险）
- 不做 `lib/weak-model-compliance.sh` 的 L2 状态机重写 — 功能不变，仅消除 correction file 结构重复
- 不新增 brooks-lint 配置文件（`.brooks-lint.yaml`）
- 不修改已有 bats 测试的断言逻辑 — 新增覆盖，不改旧断言

## 验收线（粗粒度，不是 AC）

- `bash -n` 全部 34 个 `.sh` 文件通过，无新增语法错误
- `bats` 可执行且现有测试套件全部通过
- Hook 模块名列表仅在一处定义，`install_hooks.sh` 和 `package-flow-kit.sh` 均引用同一来源
- 新增 `test_flow_kit_resume.bats` 和 `test_stop_report_reminder.bats` 覆盖 SessionStart hooks

## 风险与未知

- Correction file 统一抽离涉及两个 lib 的 API 边界变更，需确保 `flow-kit-resume.sh`（SessionStart）对两种 correction 的读取行为不变
- bats 安装依赖系统包管理（dnf），若不可用需回退到 npm 全局安装
- 已有 17 个 bats 文件（176 断言）均依赖环境中的 hook 安装状态，修复期间需确保未破坏现有断言
