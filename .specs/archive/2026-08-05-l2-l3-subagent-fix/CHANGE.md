# CHANGE: 调查解决 L2/L3 子 agent 在 opencode / claude code 双平台拉起失败

- **Change ID**: l2-l3-subagent-fix
- **创建日期**: 2026-08-05
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）— 调查先行，修复基于根因报告实施
- **状态**: draft

---

## Why（为什么做）

flow-kit 的 L2/L3 独立审查依赖拉起子 agent（L2 子 agent 盲审 / L3 外部模型调用）。在 **opencode** 与 **claude code** 两个运行时下：

1. **agent 架构不同**：派发命令 / task tool 参数 / 子 agent 类型名在两平台不兼容，既有派发命令在 opencode 下可能直接不可用或报错（"拉不起来"）。
2. **环境变量传递链路不同**：子 agent 进程拿不到 `ANTHROPIC_*` / `FLOW_KIT_*` 等 env var，导致模型配置解析失败 / API 鉴权失败。

用户实测：**两类现象在两个平台都出现过**，但根因从未被系统性定位。不修则 L2/L3 独立审查在 opencode 环境（本仓库当前运行环境）不可用，弱模型护栏体系在跨平台部署时断裂。

## What（做什么）

系统调查并定位 L2/L3 子 agent 在 opencode / claude code 双平台拉起失败的根本原因，交付**根因报告**（现象矩阵 + 根因链 + 双平台差异矩阵 + 修复方案），并基于报告实施修复（修复范围以报告为准，不预先承诺）。

## 视觉调性（前端项目必填，由 0-change 步骤 0.6 预选填入）

> 非前端项目（Bash 脚本 / meta-distribution），跳过 0.6。

## 影响面

- [x] 影响 `REQUIREMENT.md`（调查范围 + 根因报告产出物定义）
- [x] 影响 `DESIGN.md` / 引入新 ADR（可能更新 ADR-020 OpenCode task 能力快照，或新增双平台派发兼容设计）
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [x] 影响外部 API 兼容性（子 agent 派发接口 / task tool 调用格式 / env var 透传）
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **本次不实施大规模修复**——先交付根因报告，修复范围待报告确认后实施，避免基于猜测修改禁动清单内模块
- 不修改 L3 API 直连链（`l3-review.sh` 封装 · 禁动清单）
- 不触碰 gate 校验核心链（`independent-review-gate.sh` / `29-independent-review.sh` / `fk_validate_done_marker` · 禁动清单）——除非根因直指且经用户确认
- 不做双平台完整 e2e 自动化验收（claude code 环境在本机是否可复现未知，验收以可复现环境为准）

## 验收线（粗粒度，不是 AC）

- 根因报告交付：现象矩阵 + 根因定位（**每条根因含证据链**：命令实测输出 / 文件行号 / 复现步骤，不写猜测）+ opencode vs claude code 差异矩阵 + 修复方案（含受影响模块清单）
- 报告确认后实施的修复（如有）在 opencode 环境成功拉起一次 L2 子 agent 审查且结果回写
- claude code 侧若本机可复现，同样验证；不可复现则报告中明确标注验证缺口

## 风险与未知

- claude code 环境在本机是否可复现未知（可能需目标机器验证）
- env var 透传涉及运行时进程模型，根因可能横跨 hook 层与运行时层，调查需分层
- ADR-020 已记录「OpenCode 不支持 task-level model-tier」——若根因与派发命令相关，可能需更新该快照（属 DESIGN 决策点）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
