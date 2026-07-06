# CHANGE: L2/L3 独立审查开关拆分

- **Change ID**: `l2-l3-granular-gate`
- **创建日期**: 2026-07-06
- **路径建议**: 完整
- **状态**: draft

---

## Why（为什么做）

当前 `gate_config[phase] = "independent"` 同时开启 L2（同会话子 agent 盲审）和 L3（Stop hook 外部模型盲审），无法单独控制。在慢系统上，L3 的外部 API 调用耗时较长，用户希望只跑 L2（零额外耗时）跳过 L3，反之亦然。

## What（做什么）

将 `gate_config` 的单值 `"independent"` 拆为三值：`"L2"` / `"L3"` / `"both"`。`"independent"` 保留作为 `"both"` 的向后兼容别名。

改动范围：
- **gate_config 解析**：`done-validation.sh` 的 `fk_independent_review_gate_active()` 支持按 tier 判定
- **prompt L2 调度段**：6 个阶段 prompt 的「独立 review 调度」段读取 L2 开关
- **L3 Stop hook**：`29-independent-review.sh` 读取 L3 开关
- **gate 拦截**：`independent-review-gate.sh` 的 done 判定逻辑适配新值
- **flow skill 预设表**：`/flow goal --gate-config` 新增 `--l2-only` / `--l3-only` flag，预设默认 `"both"`

## 影响面

- [x] 影响 `DESIGN.md` / 引入新 ADR（gate_config 数据结构变更，需 ADR 记录）
- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性（`"independent"` 保留向后兼容）
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不改变 L2 盲审 prompt 内容（`L2-blind-review.md` 不变）
- 不改变 L3 外部模型选择逻辑
- 不改变 done 标志文件格式
- 不改 `stop-hook.json` 的 `independent_review.phases` 持久化配置格式（仍用 `"independent"` 表示 both）

## 验收线（粗粒度，不是 AC）

1. `gate_config["6-review"] = "L2"` → L2 跑、L3 跳过
2. `gate_config["6-review"] = "L3"` → L2 跳过、L3 跑
3. `gate_config["6-review"] = "both"` / `"independent"` → 两层都跑（原行为不变）
4. 现有 `--gate-config review` 预设行为不变（默认 both）

## 风险与未知

- **兼容性**：已有 `.flow-active` 文件中的 `gate_config` 值为 `"independent"` 或 `"true"`，需在解析层做映射（`"independent"` / `"true"` → both）
- **gate 判定复杂度**：`independent-review-gate.sh` 的 done 检查逻辑需区分"L2 done 但 L3 没跑" vs "两层都要 done"
- **测试覆盖**：需新增 bats 测试覆盖 L2-only / L3-only / both 三种模式

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
