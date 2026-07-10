# CHANGE: 修 L3 gate 机制三连异常（L-030）

- **Change ID**: fix-l3-gate
- **创建日期**: 2026-07-10
- **状态**: draft
- **路径建议**: 完整 pipeline（0→1→2→3→4→5→6→7 · auto_advance=false · gate_config 全 L2 · L2 用 haiku）
- **设计依据**: `.specs/LESSONS.md` L-030（td-test-infra pipeline 发现 · 1-requirement / 2-design 阶段 L3 死结）

---

## Why

td-test-infra pipeline（0→7 · 2026-07-09/10）过程中 L3（glm-4.7）在 1/2 阶段连续出现三连异常，导致全程关闭 L3 改 L2 绕过。问题（L-030）：

1. **L3 fail 后不重审**：`l3-review.sh` 对已审阶段只写一次 L3 段，主 agent 修了工件也得不到 L3 重新确认 → verdict 永久死结
2. **`.done` 被 `pre-tool-use-gate` 异常写入**：`L3_verdict=fail` 却写 .done 放行 transition（违背"L3 fail 不该写 .done"设计——安全漏洞：L3 发现 critical 仍可绕过）
3. **transition 后 `goal.current_phase` 与顶层 `phase` 不同步**：hook/auto-advance 只改顶层 `phase`，未同步 `goal.current_phase`、`phases_done`、`gates`——导致 pipeline 状态不一致

这三个问题使 L3 review 在 pipeline 模式下**不可用**（fail 即死结 + .done 异常放行 + 状态混乱）。

## What

1. **`l3-review.sh`（29号 hook lib）**：支持**重审**——检测工件（REQUIREMENT/DESIGN 等）是否比上次 L3 审查时变动，变动后重新跑 L3、追加新 L3 段 + 更新 verdict（不覆写旧段，追加 `## L3 重审` 段）
2. **gate `.done` 写逻辑（`independent-review-gate.sh` + `l3-review.sh`）**：L3 fail **不写** .done；only L3 pass 时写 .done。L3 fail → gate 正确 deny transition（pipeline pause），不通过写 fail .done 放行
3. **transition 同步（`31-auto-advance.sh` + gate transition jq）**：transition jq **同时更新** `.goal.current_phase`、顶层 `phase`、`.goal.phases_done`、`.goal.gates["N→N+1"]`

## 影响面

- [x] 影响 `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（重审 + .done 写逻辑）
- [x] 影响 `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（.done 写判定）
- [x] 可能影响 `flow-kit-bundle/hooks/stop/31-auto-advance.sh`（transition 同步）
- [x] 可能影响 `flow-kit-bundle/hooks/stop/29-independent-review.sh`（L3 调用入口）
- [ ] 影响 `REQUIREMENT.md`（否·纯 bug 修复）
- [ ] 影响 ADR / 架构（否·在既有 gate 机制内修复，无新架构决策）
- [ ] 影响 L2 机制（否·L2 正常工作，td-test-infra 已验证）
- [x] 影响 `.specs/CONTEXT.md`（新增 4 个 glossary 术语：L3 重审、工件变更检测、.done 安全写逻辑、transition 四字段同步）
- [ ] 影响 L-030 本身（记 LESSONS 记录，本 change 修后 L-030 标 resolved）

## 范围排除

- L2 机制不改（正常工作，已验证）
- gate_config 默认值不改（`independent`→both=L2+L3；本 change 自身用 L2 跑 pipeline）
- L3 外部模型选择/API 配置不改
- 不引入新 gate 特性（如多轮 L3 阈值、L3 重试上限）
- 不改 1/2/3/5/6/7 阶段的 prompt（它们不涉及 gate 机制实现）

## 验收线

1. **L3 重审**：L3 fail 后工件变动 → 下次 Stop hook L3 重跑，追加新 verdict 段（不是永久死结）
2. **.done 安全**：L3 fail 时不写 .done → gate 正确 deny transition（commit/phase 切换被拦）
3. **phase 同步**：合法 transition 后 `goal.current_phase`、顶层 `phase`、`phases_done`、`gates` 全部一致

---

> 本 change 走 pipeline（gate_config 全 L2 · L2 用 haiku），不依赖 L3 自身 review。
