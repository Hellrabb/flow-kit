# CHANGE: 修复 pipeline 诊断发现的全部问题

- **Change ID**: pipeline-fallback-fix
- **创建日期**: 2026-07-03
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: active

---

## Why（为什么做）

[DIAGNOSIS.md](./DIAGNOSIS.md) 对 flow-kit pipeline 自动推进 + 回退模式做了端到端诊断，发现 **6 个 Critical/Major 问题**：

| # | 发现 | 严重度 | 一句话 |
|---|---|---|---|
| F1 | L2+L3 异步死锁 | 🔴 Critical | L3 需 Stop hook（会话结束触发），但 transition 需 L3 完成 → 单 session 内无法推进 |
| F2 | gate_config 篡改检测死锁 | 🔴 Critical | `/flow gate-config` 只更新 `.flow-active`，不同步 `.goal-snapshot.json` → hook D8 拦截全部修改工具，不可逆 |
| F3 | Gate 拦回退 | 🔴 Critical | 独立审查 gate 不区分前进/回退 → pipeline 卡住后无法后退恢复 |
| F4 | auto_advance 纯 prompt 驱动 | 🔴 Critical | 无 hook 层兜底 → 弱模型可跳过自动推进指令 |
| F5 | Fallback 纯 prompt 驱动 | 🔴 Critical | GO.md 无 mode 特定路由，fallback 迭代完全依赖模型自觉 |
| F6 | AC-5a/hook 字段差异 | 🟡 Major | `artifacts=` 未实现；Tier1 不查 L2/L3_verdict |

这些问题不修复，任何依赖 pipeline 独立审查 gate 的 change 都会触发死锁或绕过。

## What（做什么）

**修复 DIAGNOSIS.md 列出的全部 9 项**（P0 × 3 + P1 × 3 + P2 × 2），消除死锁 + 补齐 hook 兜底 + 对齐规格。

### P0 — 阻塞性死锁（3 项）

| # | 修复项 | 方案 |
|---|---|---|
| P0-1 (F1) | L3 前置到 PreToolUse hook | 抽取 L3 API 调用为共享 lib（`hooks/stop/lib/l3-review.sh`）。`independent-review-gate.sh` 拦截 transition 时同步调 L3，完成后放行。Stop hook 29 号模块保留作兜底（处理 transition 前 session 异常终止） |
| P0-2 (F2) | `/flow gate-config` 同步快照 | `/flow gate-config` 写 `.flow-active` 的同时更新 `.specs/<id>/.goal-snapshot.json`；`/flow goal --gate-config` 同样走统一快照写入路径 |
| P0-3 (F3) | Gate 区分前进/回退 | `independent-review-gate.sh` 的 `is_phase_write` 检测到目标 phase < 当前 phase（回退）时放行，不要求 .done |

### P1 — 弱模型鲁棒性（3 项）

| # | 修复项 | 方案 |
|---|---|---|
| P1-1 (F4) | auto_advance hook 兜底 | 新增 Stop hook 模块（31-auto-advance.sh）：检测 `auto_advance=true` + PCSC 全✅ → 自动执行 transition jq |
| P1-2 (F5) | Fallback hook 兜底 | 新增 Stop hook 模块（32-fallback-guard.sh）：检测 `mode=fallback` + 条件满足 → 自动更新 `goal.status=done` |
| P1-3 | GO.md mode 路由 | GO.md 添加 mode 特定分支：fallback 时显式加载迭代逻辑段（与 4-dev.md prompt 中描述去重） |

### P2 — 规格对齐（2 项）

| # | 修复项 | 方案 |
|---|---|---|
| P2-1 (F6) | AC-5a ↔ hook 字段同步 | `.done` 必填字段统一为 6 键：`phase/change_id/written_by/L2_verdict/L3_verdict/artifacts`；`flow-kit-artifacts.sh` 的 `fk_validate_done_marker()` 补上 `artifacts=` 存在性检查 |
| P2-2 | Tier1 补 L2/L3_verdict | `fk_validate_done_marker()` Tier1 增加 L2_verdict/L3_verdict 存在性检查（当前仅 Tier2 transition 时检查） |

## 影响面

- [x] 影响 hook 脚本（`independent-review-gate.sh` / `flow-kit-artifacts.sh` / `29-independent-review.sh`；新增 `l3-review.sh` lib + `31-auto-advance.sh` + `32-fallback-guard.sh`）
- [x] 影响 skill（`/flow gate-config` / `/flow goal --gate-config` 快照同步）
- [x] 影响 prompt（`4-dev.md` auto_advance/fallback 段 + `GO.md` mode 路由）
- [x] 影响 `REQUIREMENT.md`（基于 DIAGNOSIS.md 写修复 AC）
- [x] 影响 `DESIGN.md`（先读 DESIGN-DIAGNOSIS.md，增量补修复设计）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性

## 范围排除（这次不做）

- **不新增 test/ 用例**（手工 e2e 验证修复效果；自动化测试留给后续 change）
- **不修改 `.flow-active` 数据结构**（字段不变）
- **不修改 stop-hook.json schema**
- **不修改 hook 配置开关机制**
- **不新增 L2/L3 checklist 内容**（仅动执行流程，不动审查维度）
- **不修改 gate_config 预设定义**（PRESET_MAP 不变）

## 验收线（粗粒度，不是 AC）

1. **死锁解除**：单 session 内跑完整 pipeline（开独立审查 gate 的阶段），transition 不被 L3 异步依赖阻塞
2. **gate_config 一致性**：`/flow gate-config` 操作后 `.flow-active` 与 `.goal-snapshot.json` 始终一致，hook D8 不误拦
3. **已有测试全绿**：`npx bats test/` 0 fail，无回归

## 风险与未知

- **L3 API 调用延迟**：PreToolUse hook 中同步调外部模型 API 可能需 5-15s，用户感知到 transition jq 执行变慢。方案：hook 输出进度提示（"L3 审查中..."）
- **L3 API 超时**：外部模型不可用时 PreToolUse hook 可能挂起。方案：设 30s 超时 + 超时后降级为跳过 L3（记入 `.done` 的 `L3_verdict=timeout`）
- **Stop hook 模块编号冲突**：31/32 号需确认未被占用。当前最高编号为 30（30-summarize.sh），31/32 可用
- **诊断产物保留**：原诊断 CHANGE/REQUIREMENT/DESIGN/TASK/TEST 已重命名为 `*-DIAGNOSIS.md`，修复阶段写入新文件，不覆盖

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
