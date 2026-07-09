# CHANGE: 修 TD-014 is_phase_write 对 jq phase-write 漏检（gate phase-transition 检测失效 · 安全隐患）

- **Change ID**: fix-gate-phase-detection
- **创建日期**: 2026-07-09
- **状态**: ✅ done（实施完成 · 归档）
- **设计授权**: `.specs/archive/2026-07-09-refactor-independent-review-gate-discovery/DESIGN.md` v4 D6 + sandbox 验证
- **关联 TD**: TD-014（🔴🔴 → ✅）

---

## Why（为什么做）

`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 的 `is_phase_write` L73-75 regex `\.flow-active.*\.phase[[:space:]]*=` 要求 `.flow-active` 出现在字段名**之前**。但真实 jq 写命令字段名在前（jq 表达式里）、`.flow-active` 是文件名在后 → regex 永不匹配 → `is_phase_write` 对所有真实 jq phase-write `return 1`（漏检）→ **gate phase-transition 检测对 jq 完全失效**，phase 切换可绕过 L2/L3 independent review。

仅 `git commit` / `gh pr create` 兜底仍在；裸 jq transition（无 `.done`）不被拦。安全隐患（禁动清单核心链）。

## What（做了什么）

1. L73-75 去掉 `.flow-active.*` 前缀（L67 `[[ "$c" == *.flow-active* ]]` 已保证命令涉及 .flow-active，L73-75 只需测 phase 字段名存在）
2. D10 两处测试去 `skip`（`test/` + `flow-kit-bundle/test/` 双源同步）—— 假绿挂起转真跑
3. 全量回归

## gate 行为改变声明

修复后 gate 恢复**设计本意**：jq phase 切换被 `is_phase_write` 检测 → 走 gate（`_fk_phase_direction` forward → 查 `.done`）。合法 transition（`.done` 已写）放行；裸 transition（无 `.done`）被拦。**不破坏合法流程**（合法 transition 必有 `.done`）。属禁动清单核心链的行为改变，有 discovery DESIGN v4 + sandbox 验证授权。

## 影响面

- [ ] 影响 `REQUIREMENT.md`（否·纯 bug 修复）
- [ ] 影响 `DESIGN.md` / 新 ADR（否·设计已在 discovery 归档）
- [ ] 影响现有 AC（否·反而激活了被 skip 的 D10 AC）
- [ ] 影响数据模型 / 迁移（否）
- [ ] 影响外部 API 兼容性（否）
- [x] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **TD-011**（L69 `&&` 被 `[[ ]]` 当逻辑与 · SC1026/2203/2157）：独立项；被 L70-71 fallback 掩盖、非致命
- **TD-015**（L30/L71 `\>[^=]`）：当前**内联**写法正常，仅"变量化"时触发 GNU 单词边界；属 D2 全文件 regex 治理范围
- 上述两项按 systematic-debugging「ONE change at a time」未顺手带入

## 验收

见 `DEV-SUMMARY.md`「最终验证」。
