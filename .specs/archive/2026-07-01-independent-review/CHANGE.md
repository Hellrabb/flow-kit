# CHANGE: 独立 Review Agent（L2 盲审 + L3 hook 强制）

- **Change ID**: independent-review
- **创建日期**: 2026-07-01
- **路径建议**: 完整（0→7，已有实现代码，逆向补产物）
- **状态**: active

---

## Why（为什么做）

flow-kit 的 review 当前由主 agent 自审（6-review 三轮 + 可选跨模型 spot-check），或调独立 skill（brooks-lint）。三类都有独立性缺口：主 agent 自审存在证实偏差和 sycophancy；跨模型 spot-check 只是「强烈建议」，触发权和 prompt 都在主 agent 手里，可被跳过或软化；brooks-lint prompt 固定但触发权仍在主 agent，可选择不调。

实际影响：主 agent 在 6-review 阶段可能放过自己的错误（"赶进度就放过自己"），1/2 阶段没有独立 review 机制导致需求遗漏和架构偏差难以在早期发现。

## What（做什么）

在 flow-kit 的 1-requirement / 2-design / 6-review 三阶段引入双层独立 review：

- **L2 盲审**：主 agent 用 Agent tool 派固化盲审子 agent（禁喂主 agent 自评/草稿），按阶段 checklist 审工件，产四要素报告
- **L3 hook 强制**：Stop 模块 29-independent-review.sh 调 deepseek-v4-flash 盲审 + PreToolUse hook 硬拦截 commit/PR/阶段切换（三道防线）
- **默认关闭**：用户用 `/flow gate-config` 显式开启某阶段才跑，gate_config 存 .flow-active.goal

全部改动落在 flow-kit-bundle/（产品源），12 文件（9 改 + 3 新增），1086 行新增。

## 视觉调性

非前端项目，跳过。

## 影响面

- [x] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（无）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- L2 自定义 subagent_type（固化 system prompt）—— P2 增强，本次只做 prompt 固化 + 事后检测
- 真实 L3 模型调通验证 —— 受测试环境 onecli 路由限制，降级路径已验证
- 阶段 4/5/7 的独立 review 覆盖 —— 本次只做 1/2/6
- L3 按阶段配不同 model（phase_models）—— 默认全 deepseek，后续加

## 验收线（粗粒度，不是 AC）

- 项目现有 102 个 bats tests 全部 pass，无回归
- `package-flow-kit.sh --validate` 打包完整性校验通过
- `install.sh --reinstall` + 临时项目端到端：新 install 的项目 .claude/ 含 29/pre-tool-use + settings 含 Stop/PreToolUse 双接线

## 风险与未知

- L2 独立性根本保证仍在 prompt 层（主 agent 理论上可往子 agent prompt 掺自评）
- deepseek-v4-flash 审需求/设计文档的质量未实测（擅长代码 diff）
- PreToolUse hook 与 fk_auto_phase 的三道防线覆盖全部推进路径，但任何遗漏会导致独立 review 可被绕过
