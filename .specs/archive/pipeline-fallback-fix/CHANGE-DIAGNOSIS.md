# CHANGE: 诊断 pipeline 自动推进 + 回退模式问题

- **Change ID**: pipeline-fallback-fix
- **创建日期**: 2026-07-03
- **路径建议**: 中等（诊断任务，无代码变更）
- **状态**: draft

---

## Why（为什么做）

在连续合并 `gate-integrity`、`independent-review-gap`、`weak-model-robustness`、`weak-model-interactive-ui`、`robustness-hook-hardening` 等 L2/L3+hook 加固 change 之后，pipeline 全自动推进流程出现多项异常迹象：

1. **auto_advance 不生效**：设置了 `auto_advance=true` 但 pipeline 在 toll-gate 处仍然暂停
2. **PCSC → transition 链路疑似断裂**：阶段完成自检通过后未触发自动 transition
3. **L2/L3 hook 反馈未接入 pipeline 推进**：29 号独立审查 hook + 28 号合规检测 hook 的执行结果没有正确反馈到 gate 状态
4. **回退模式（fallback）路径几乎未测试**：CC native `/goal` 不可用时的 prompt 驱动迭代循环——终止条件、toll-gate 行为、与 native 路径的一致性——均缺乏验证

这些问题如果不定位清楚，后续任何依赖 pipeline 自动推进的 change 都会受影响。

## What（做什么）

**纯诊断，不修代码。** 对 flow-kit pipeline 的自动推进机制做端到端诊断：

- 在 `auto_advance=true` 条件下跑一轮完整 pipeline（0→7），记录每个 toll-gate 的实际行为
- 在 fallback 模式下跑一轮，对比 native 模式的行为差异
- 定位 PCSC / transition / gate 状态更新 / hook 反馈 各环节的具体断点
- 输出诊断报告（`.specs/pipeline-fallback-fix/DIAGNOSIS.md`），逐项标记状态 + 根因分析

## 影响面

- [x] 影响 `REQUIREMENT.md`（诊断范围与成功标准）
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不修改任何 flow-kit 源代码**（prompt / hook / skill / lib / template 均不改）
- **不修改 `.flow-active` 结构或字段**
- **不新增 test/ 用例**（诊断通过手工端到端验证，自动化测试留给后续修复 change）
- **不修改 hook 脚本逻辑**
- **不回滚或禁用任何 L2/L3 护栏**

## 验收线（粗粒度，不是 AC）

- `.specs/pipeline-fallback-fix/DIAGNOSIS.md` 产出，包含：
  - auto_advance 链路每个环节的状态（✅ 正常 / ⚠️ 异常 / ❌ 断裂）+ 根因
  - fallback vs native 差异对比表
  - 按优先级排序的修复建议清单
- 诊断覆盖完整的 0→7 链路（至少 native 路径跑通一轮端到端）
- fallback 路径至少模拟一轮端到端（即使无法完整跑通，也记录卡在哪里）

## 风险与未知

- 诊断过程本身可能被被测的 bug 阻塞（比如 pipeline 卡在某个阶段无法推进）——需要手动干预记录卡点
- fallback 路径触发条件（模拟 CC < v2.1.139）可能需要手动设置环境变量或修改版本检测逻辑（仅临时，诊断完恢复）
- gate-config all 的独立 review 开销大（+30k-75k tokens），诊断轮次可能较多
