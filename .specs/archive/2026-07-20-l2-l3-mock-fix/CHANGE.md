# CHANGE: L2/L3 独立审查 gate 残留缺陷根治（F 重构 + H/I/J v2）

- **Change ID**: l2-l3-mock-fix
- **创建日期**: 2026-07-17
- **路径建议**: 完整
- **状态**: done

---

## Why（为什么做）

延续上一个 change `l2-l3-test-defect`（2026-07-17 归档）。该 change 诊断出 L2/L3 独立审查 gate 共 7 个缺陷（BUG-A~G），修了 A-F+G+D7-alt，但将 H/I/J 显式标记为 **v2 缓解**（见归档 `.specs/archive/l2-l3-test-defect/DESIGN.md §5 R1-R4` + `line 138`：BUG-H/I/J 修复 v2 归属 l2-l3-mock-fix）：

- **H**：`is_git_commit` 用文本子串匹配，导致 L2 子 agent 写审查报告时，报告正文含 "git commit" 字符串就被 gate 误拦。当前只能用 `chr()` 拼装触发词绕过——脆弱且污染审查文本。
- **I**：Stop hook 链在本环境未自动触发 L3 审查，只能手动 `l3_review_run` 兜底——自动化断裂。
- **J**：`_l3_check_rerun` 用文件 mtime 判断"是否已审查"，artifact 被 touch 即被误判已审查而 skip——L3 复审失效。

同时 **BUG-F 的 v1 修复引入新债**：v1 为让 gate 编排层拿到 `PHASE_GATE_KEY_MAP`，在 `independent-review-gate.sh` 内**复制了一份** `declare -A`（与 `common.sh:255` 重复定义，见源码 `independent-review-gate.sh:25`）——违反 DRY，两份映射易不同步，正是编排层 bug 的温床。

**L3 模型不在本 change 范围**：L3 审查模型读 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量，模型可靠性由用户自行配置（当前 glm-4.7 幻觉见记忆 [[l3-model-unreliable]]，用户可通过该环境变量切换更可靠模型）。本 change 聚焦 gate 机制**代码层**（F/H/I/J）的残留缺陷，让 gate 在任意 L3 模型配置下都正确工作。

**本次 phase 1 实跑发现 Bug 1**：`26-workflow.sh` G1 在 pipeline goal 模式下，用 `fk_auto_phase` 检测到阶段产物存在（如 REQUIREMENT.md）即**绕过 toll-gate 直接写 `.phase=N+1`**（line 90），不同步 `goal.current_phase`/`phases_done`/`gates`——单阶段 goal 时代遗留逻辑，与 pipeline goal 的 toll-gate 机制冲突，制造 phase/current_phase 不一致（本 change 每轮 Stop 复现，已纳入 AC-K）。

## What（做什么）

根治 L2/L3 gate 的 5 个残留代码缺陷：(1) 将 `PHASE_GATE_KEY_MAP` 重构为单一来源的纯函数，消除 common.sh 与 gate 文件的重复定义；(2) `is_git_commit` 改为结构化命令识别，杜绝审查文本子串误判；(3) Stop hook 触发尽力增强 + 固化手动兜底文档；(4) `_l3_check_rerun` 改为检查 artifact 的 `## L3` 段而非 mtime；(5) 26-workflow.sh G1 pipeline goal 模式 phase advance 一致性（AC-K）。每个 gate 改动伴集成测试（payload 注入 + 全链路 exit code）。**L3 审查模型跟随 `ANTHROPIC_DEFAULT_HAIKU_MODEL`，本 change 不做模型选型/切换/验证。**

## 视觉调性（前端项目必填）

N/A — Bash 脚本项目（flow-kit 分发包仓库），无 UI。

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增 F/H/I/J 的 AC + 集成测试 AC；继承上个 change H/I/J 雏形 AC）
- [x] 影响 `DESIGN.md` / 引入新 ADR（F pure fn 重构方案 + H 结构化命令识别方案 · 技术决策层，非项目级架构变更）
- [x] 影响现有 AC（上个 change REQUIREMENT line 150-153 的 H/I/J 缓解性描述升级为根治性 AC）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不重写 gate 编排层架构**：`_run_review_gates` 的 7 Gate 结构保留，仅修内部缺陷
- **不改 L2 子 agent 机制**：L2 已可靠（记忆 [[l3-model-unreliable]] 确认），本 change 不动 L2
- **不做 L3 模型选型/切换/验证**：L3 跟随 `ANTHROPIC_DEFAULT_HAIKU_MODEL`，模型可靠性由用户配置（见 Why）
- **不追求 BUG-I 的环境层根治**：Stop hook 触发受框架限制，仅尽力增强 + 文档兜底
- **不做 UI / 前端**：Bash 脚本项目
- **不重做已归档的 A-E + G 修复**：仅 F 重构（F 的 v1 修复将被 pure fn 取代）

## 验收线（粗粒度，不是 AC）

1. **gate 残留缺陷根治**：F/H/I/J 四项修复各自伴集成测试（payload 注入 `bash gate.sh` + exit code 断言，覆盖命令文本含敏感子串的误判场景），全套 bats 真绿（407+ 新增 pass，0 fail 0 BW01，无假绿）
2. **gate 行为对 L3 模型透明**：gate 在 L3 verdict=fail 时正确 deny、verdict=pass 时正确放行，L3 复审机制（## L3 段检查）不被 mtime 误判短路——不依赖具体 L3 模型好坏
3. **phase 状态一致性（AC-K）**：pipeline goal 模式下 26-workflow.sh G1 不擅自 advance `.phase`，phase/current_phase 始终一致（toll-gate / 31-auto-advance 才能推进）

## 风险与未知

- **BUG-I 环境层天花板**：Stop hook 自动触发可能受 Claude Code 框架限制，无法在本环境根治——已约定"尽力修 + 文档兜底"边界
- **F pure fn 重构的当前形态待核实**：v1 在 gate 文件内的 `declare -A`（源码 `independent-review-gate.sh:25`）与 `common.sh:255` 的关系需 DESIGN 阶段读源码确认，避免破坏 v1 已修的 forward transition gate
- **H 结构化识别的边界**：命令识别需覆盖"命令文本含敏感子串"（如审查报告引用 git commit 字符串）的误判场景（记忆 [[gate-orchestration-integration-test]] 强调），方案需在 DESIGN 定
- **L3 模型可靠性是外部因素**：本 change 不解决（用户通过 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 自行配置）；gate 代码层正确性不依赖模型好坏

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
