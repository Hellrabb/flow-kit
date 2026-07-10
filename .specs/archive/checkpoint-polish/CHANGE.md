# CHANGE: auto-checkpoint 收尾——BW01/02/03 三项品质提升

- **Change ID**: `checkpoint-polish`
- **创建日期**: 2026-07-10
- **路径建议**: 最短（REQUIREMENT 增量 → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

`auto-checkpoint-hook` change 完成后留下 4 条遗留问题（BW01-BW04），其中 BW01-BW03 适合作为下一个 change 集中处理。

## What（做什么）

三项品质提升：

1. **BW01**：抽取 `flow-kit-resume.sh` 的 interrupt banner 生成逻辑为独立 sourceable 函数，使 AC-6 测试可调用真实 banner 而非 jq 模拟提取
2. **BW02**：统一 CHANGELOG.md 格式——当前混存两种格式（顶部单行 pipe 格式 + 下部标准表头格式），统一为单一格式
3. **BW03**：`test/` ↔ `flow-kit-bundle/test/` 双源测试文件自动同步——当前靠手动 `cp`，引入 Makefile target 或 install.sh 符号链接方案

BW04（install_hooks.sh 重复代码）不纳入本次——等第三个 PreToolUse hook 出现时再一并处理。

## 影响面

- [x] 影响 `REQUIREMENT.md`（增量：新增 AC）
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不做** BW04（install_hooks.sh 去重——等第三个 PreToolUse hook 触发）
- **不做** 新功能开发——纯品质/测试/格式改进

## 验收线

- AC-2 resume banner 测试调用真实 sourceable 函数（非 jq 模拟）
- CHANGELOG.md 全文件统一格式
- `make test-sync` 自动同步双源测试文件；`make check` 检测不同步并以非零退出
- 全量 bats 不退化

## 风险与未知

- **风险**：`flow-kit-resume.sh` 重构成 sourceable 函数可能影响 SessionStart hook 行为——需回归测试覆盖
- **未知**：CHANGELOG.md 格式统一选哪种？建议统一为紧凑单行 pipe 格式（无独立表头行），与新条目格式一致
