# CHANGE: L2/L3 模型配置解耦（跨平台兼容）

- **Change ID**: l2-l3-model-config
- **创建日期**: 2026-07-22
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

L2/L3 独立审查的模型选择硬依赖 Claude Code 专属环境变量：

- L3：`${ANTHROPIC_DEFAULT_HAIKU_MODEL:?}` — 变量未设时脚本直接终止（`:?` 语法）
- L2：`${ANTHROPIC_L2_MODEL:-claude-sonnet-5}` — 有 fallback，但 fallback 值在其他平台/第三方 API 上不存在

OpenCode、Codex CLI、Gemini CLI 等非 Claude Code 平台上，L2/L3 审查完全不可用。

## What（做什么）

将 L2/L3 模型配置从 Claude Code 环境变量解耦为**三级优先级链**，提供跨平台一致的配置方式：

1. 新增 `fk_resolve_model` 公共函数（`hooks/stop/lib/common.sh`）
2. 替换 3 个调用点的硬编码模型解析（`l3-review.sh` / `l2-detect.sh` / `29-independent-review.sh`）
3. 新增 `/flow model` 配置命令（skill + 路由）
4. 扩展 `.flow-active` schema（`goal.l2_model` / `goal.l3_model` 可选字段）
5. 全部未配置时优雅降级输出提示，而非崩溃

详见 `.specs/l2-l3-model-config/DESIGN.md`（已就绪）。

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR（ADR-011）
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不修改 `install.sh`（安装流程不变）
- 不新增 bats 测试用例（仅确保现有 407 tests 不回归）
- 不维护模型名白名单（值域不校验，由用户/供应商决定）
- 不修改 `package-flow-kit.sh`（打包流程不变）

## 验收线（粗粒度，不是 AC）

- 现有 407 bats tests 全绿，无回归
- `fk_resolve_model "L3"` 按优先级链正确解析：`ANTHROPIC_DEFAULT_HAIKU_MODEL` > `FLOW_KIT_L3_MODEL` > `.flow-active.goal.l3_model` > 空
- 全部未配置时不崩溃，输出清晰配置提示

## 风险与未知

- 修改 `common.sh` 会影响所有 source 该文件的 Stop hook 模块（全局影响），需确认 `fk_resolve_model` 函数名不与现有函数冲突
- 非 Claude Code 环境的手动验证依赖用户提供环境，flow-kit CI 不覆盖

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
