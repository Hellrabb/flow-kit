# CHANGE: 补齐 L2/L3 独立审查 3/5/7 缺失 + PRESET_MAP 全量补全 + 全链路一致性

## Why（为什么现在做）

`gate-integrity` change（2026-07-02）将 L2/L3 独立审查机制从 {1,2,6} 扩展到 3/5/7，但只完成了 **hook 层**（`fk_independent_review_gate_active` 正则扩展、artifact case 扩展）和 **PRESET_MAP `all` 预设**。以下三层实际未交付：

1. **Prompt 模板缺失**：`3-task.md` / `5-test.md` / `7-integration.md` 中没有「独立 review 调度」段，主 agent 在对应阶段不知道该调 L2 子 agent 和写 `.done` 文件。若用户用 `--gate-config all`，hook 层会拦 transition 等 `.done`，但没人写——**pipeline 死锁**。
2. **PRESET_MAP 不完整**：缺少单阶段预设（`task`/`test`/`integration`）和多个组合预设（`task-review`/`test-review`/`task-test`/`task-test-review`/`plan-test`），用户只能用 `all` 或手写 JSON。
3. **L2-blind-review.md checklist 缺 3/5/7**：固化盲审指令中只有阶段 1/2/6 的审查 checklist，3/5/7 无条目——即使 prompt 补了调度段，L2 子 agent 也不知道该查什么。
4. **全链路不一致**：`pipeline-gates.md` 说明、`/flow gate-config` 合法值列表、数字映射注释等多处仍写 {1,2,6}，与 `all` 预设声称的 {1,2,3,5,6,7} 矛盾。

## What（范围摘要）

补齐上述四层差异，使 gate-config 的 `all` 预设端到端可用。

### 修复清单

| # | 层 | 项目 | 当前状态 | 目标状态 |
|---|---|---|---|---|
| 1 | Prompt | `3-task.md` | 无「独立 review 调度」段 | 复制 1/2/6 模式加段 |
| 2 | Prompt | `5-test.md` | 无「独立 review 调度」段 | 复制 1/2/6 模式加段 |
| 3 | Prompt | `7-integration.md` | 仅有"L2 自检 gate"内联行 | 加完整「独立 review 调度」段 |
| 4 | PRESET_MAP | 单阶段预设 | 缺 `task`/`test`/`integration` | 补全三个单阶段预设 |
| 5 | PRESET_MAP | 组合预设 | 缺 `task-review`/`test-review`/`task-test`/`task-test-review`/`plan-test` | 补全五个组合预设 |
| 6 | L2 checklist | `L2-blind-review.md` | 仅有阶段 1/2/6 | 新增阶段 3/5/7 审查条目 |
| 7 | 全链路 | 数字映射注释/合法值列表/pipeline-gates 说明 | 多处以 {1,2,6} 为范围 | 全链路扫描 + 同步更新 |

## 影响面

- [x] 影响 REQUIREMENT.md（新增 AC）
- [x] 影响 DESIGN.md（PRESET_MAP 设计决策 + 组合预设的命名约定）
- [ ] 影响 UI-DESIGN.md
- [ ] 新增/变更 ADR
- [ ] 涉及破坏性变更

## 范围排除（本次不做）

- 不给 4-dev 加独立审查段（4-dev 是执行阶段，审查发生在 6-review；4-dev 已有 1.8 自检 gate）
- 不改变现有 1/2/6 的独立审查机制
- 不修改 hook 层（hook 层已在 gate-integrity 中完成 3/5/7 扩展）
- 不给 3/5/7 创建新的独立 prompt 文件（复用现有 `L2-blind-review.md` 扩展即可）

## 验收线

1. `all` 预设端到端可用：`--gate-config all --from 0` 的 pipeline 在阶段 3/5/7 不因 `.done` 文件缺失而死锁
2. 所有 8 个现有 PRESET_MAP 预设名 + 新增预设名在 `check-gate-sync.sh` 的 set-diff 校验中一致
3. `L2-blind-review.md` 含阶段 3/5/7 的审查 checklist
4. 全链路扫描报告中所有引用 gate_config/L2/L3 阶段的文件已同步至 {1,2,3,5,6,7}

## 路径建议

完整：`REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION`

理由：涉及 PRESET_MAP 设计决策（命名约定、组合预设的边界）和多文件批量修改，需要 DESIGN 定案 + TASK 拆解 + 测试验证 + 审查兜底。
