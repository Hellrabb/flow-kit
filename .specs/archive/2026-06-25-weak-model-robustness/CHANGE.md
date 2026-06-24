# CHANGE: 提升 flow-kit 在弱模型（幻觉多）下的鲁棒性

- **Change ID**: weak-model-robustness
- **创建日期**: 2026-06-25
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

flow-kit 当前的规则（`RULES.md`/`SYSTEM.md`）与各阶段 prompt 是按强模型（Claude 级）设计的，大量依赖模型"自觉遵守"：自觉反问、自觉读 RULES、自觉不幻觉、自觉守 checkpoint。

换用能力略弱、幻觉偏多的模型（用户实测：`minimax-m2.7` / `qwen3.6-35b-a3b` / `deepseek-v4-pro`）时，这种"靠自觉"的假设全面失效，观察到全套失败模式：

- 跳过反问直接写代码 / 跳过 checkpoint
- 幻觉不存在的 API、文件、字段
- 不读 RULES、不守 token 预算、整读 reference
- 把"本次不做"当成要做（范围漂移）
- 中途漂移、忘记 goal 条件

这些模型并非不能遵循结构化指令，而是"易幻觉、易跳步骤"。问题不在模型，在于 flow-kit 把可靠性押在了模型自觉上。

## What（做什么）

给 flow-kit 引擎加 **三层弱模型鲁棒性防御**（本次 L1+L2+L3，不含 L4）：

- **L1 规则层**：`RULES.md` / `SYSTEM.md` 加硬护栏（禁跳反问、禁凭空假设文件/API/字段、强制 checkpoint、强制"动手前先复述任务与 read/write 边界"）。
- **L2 prompt 层（主轴）**：各阶段 prompt 加结构化强化（更密集检查清单、刚性填空式产出模板、每步带自检 gate）。
- **L3 机制层**：把易幻觉操作改成强制证据链（提到任何文件/API/字段前必须先 `grep`/`read` 验证存在）+ 关键决策交叉校验。

**核心原则**：把"靠模型自觉"改成"靠结构/工具兜底"——弱模型没法跳过一个必须填空的模板，也没法幻觉一个刚被 `grep` 验证过的字段。

**作用对象**：`flow-kit-bundle/flow-kit/` 下的 `RULES.md` / `SYSTEM.md` / `prompts/*` /（可能新增）`reference/*`。

## 视觉调性

N/A — 非前端项目（flow-kit 引擎鲁棒性增强）。

## 影响面

- [x] 影响 `REQUIREMENT.md`（需定义弱模型鲁棒性需求 + 每个失败模式的验收准则）
- [x] 影响 `DESIGN.md` / 可能引入新 ADR（DESIGN 统一三层落地；"protect the weakest / 默认全含加严"方法论决策可能记 1 条 ADR）
- [ ] 影响现有 AC（无业务 AC 直接受影响）
- [ ] 影响数据模型 / 迁移（N/A，无数据模型）
- [x] 影响外部 API 兼容性（`RULES`/prompt 是所有使用者依赖的契约；本次为 **向后兼容增强**，非破坏性——强模型多几条约束不影响正确性）
- [ ] 仅修复 bug（这是增强，非 bugfix）

## 范围排除（这次不做）

- **L4 伪双轨**（`model_tier` 分级标记 + opt-out 降级）—— 留后续 change，等 L1-L3 地基定下再做开关
- **运行时模型能力自动探测** —— 已论证不可靠（弱模型会幻觉自己很强），永不做
- **改 flow-kit 阶段划分**（0→7 流程不变），只增强各阶段内容的鲁棒性
- **针对某一款具体模型特化**（不做 minimax/qwen/deepseek 专用补丁，做通用弱模型鲁棒性）
- **改 skill/hook 加载机制**（真双轨需要，本次不碰）
- **改 `.flow-active` 状态机结构**（pipeline 字段不动）

## 验收线（粗粒度，不是 AC）

1. **每个失败模式都有防御 + 反例**：跳反问 / 幻觉 API·字段 / 不读 RULES / 范围漂移 / 中途漂移，各自有 `regression-demos/` 反例（弱模型跑该 demo 时，不该跳的步骤跳了 = fail）。
2. **bats 结构测试**：校验 RULES/prompt 结构完整性（如"每个阶段 prompt 必须含自检 gate 段"、"RULES 必须含禁跳反问硬约束"），纳入现有 94 个 bats 测试。
3. **加固不破坏强模型路径**：现有 regression-demos 在强模型下仍全绿（加固是叠加，不是替换）。

## 风险与未知

- **"弱模型"边界模糊**：到底多弱算弱？验收实测用哪款模型？（未知，DESIGN 阶段定）
- **regression-demo 怎么"用弱模型跑"**：flow-kit 无自动跑模型的能力，demo 可能需人工跑或脚本模拟（未知，DESIGN/TEST 阶段定）
- **L3 证据链可能拖慢执行**：每次 `grep`/`read` 验证有成本，需平衡（DESIGN 定哪些操作强制证据链）
- **加固让强模型变啰嗦**：本次接受（风险不对称：弱模型崩溃代价 ≫ 强模型啰嗦），L4 后续缓解
- **RULES/prompt 体量增长**：RULES 现 184 行，加固后会涨，需控制不失控（DESIGN 定结构）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
