# CHANGE: 修复 M-health 2026-06-20 发现的 2 项 🟡 技术债

- **Change ID**: health-fix-2026-q2
- **创建日期**: 2026-06-20
- **路径建议**: 最短（REQUIREMENT 增量 → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: active

---

## Why（为什么做）

M-health 2026-06-20 巡检发现 2 项 🟡 技术债（综合分 85/100，无 🔴 Critical）：

- **TD-002**：hooks 系统（3410 行 bash）无测试覆盖。这是上次（2026-06-16）报告 T5「零测试覆盖」Critical 修复后的**残留尾巴** — 测试从 0 提升到 43，但覆盖范围偏向前端（flow skill 24 + install.sh CLI 11），`install_hooks.sh` / `flow-kit-artifacts.sh` 等核心 hook 逻辑仍是盲区。
- **TD-003**：`goal-pipeline-phase0` change 引入 `--from 0` 时，`4-dev.md` + `GO.md` 已加 `start_phase` 读取，但 `5-test.md` / `6-review.md` / `7-integration.md` 三个 prompt 入场 jq 仍是 `current_phase // "4"`（漏改）。实际影响低（current_phase 字段在 transition 时已正确更新，fallback 不触发），但一致性应补齐。

两项都是上次巡检以来积累的小债，适合合并到一个轻量 health-fix change 一次性清掉。

## What（做什么）

1. **TD-003（5 分钟一致性补齐）**：将 `5-test.md` / `6-review.md` / `7-integration.md` 的入场 jq 从 `current_phase // "4"` 统一为 `current_phase // .start_phase // "4"`，与 `4-dev.md` + `GO.md` 对齐。
2. **TD-002（hooks smoke test）**：为 hooks 系统的核心逻辑新增 bats smoke test，优先覆盖：
   - `lib/common.sh` 的 `config_get` / `module_enabled`（已部分覆盖，补全边界）
   - `lib/flow-kit-artifacts.sh` 的产物完整性检查
   - `lib/install_hooks.sh`（若 lib 已有同名函数则覆盖 install.sh 调度）
   - 不追求 100% 覆盖，目标：填补 3410 行 bash 的「完全盲区」，让关键 hook 有最低保障

## 影响面

- [ ] 影响 `REQUIREMENT.md` — 2 项 AC（TD-002 测试通过 / TD-003 一致性）
- [ ] 影响 `DESIGN.md` / 引入新 ADR — 无（jq 微调 + 测试补充，无架构决策）
- [ ] 影响现有 AC — 无
- [ ] 影响数据模型 / 迁移 — 无
- [ ] 影响外部 API 兼容性 — 无（5/6/7 prompt 内部 jq 微调）
- [x] 仅修复 bug / 补测试，无范围变化

## 范围排除（这次不做）

- **不重构 hooks 系统**（只加测试，不改逻辑）
- **不提取 markdown 共享 jq 片段**（🟢 低优先级，ROI 低）
- **不动 L-004 deferred**（魔法数字，共享函数 < 3 阈值，保持推迟）
- **不追求 hooks 100% 覆盖**（目标：从 0 到 smoke test 基线，不追求行覆盖指标）

## 验收线（粗粒度，不是 AC）

1. TD-003：5-test/6-review/7-integration 三个 prompt 入场 jq 与 4-dev.md/GO.md 完全一致（含 start_phase）
2. TD-002：新增 ≥ 3 个 bats 测试覆盖 hooks/lib 核心函数，全量测试通过（无 fail 无 skip）

## 风险与未知

- **风险**：为 hooks 加测试时可能需要 mock `.flow-active` / git / settings.json 等文件系统依赖 → 缓解：测试用 mktemp 隔离 + 构造最小 fixture（沿用 test_flow_goal.bats 的 pattern）
- **未知**：`flow-kit-artifacts.sh` 部分逻辑依赖 git 状态，单测可能需要 chdir 到临时 repo → 在 DEV 阶段确认

---

> 后续 AC 进入 `REQUIREMENT.md`，本文件不再扩展。
