# CHANGE: 诊断 L2/L3 独立审查机制 —— 实跑全链路暴露测试方案缺陷

- **Change ID**: l2-l3-test-defect
- **创建日期**: 2026-07-17
- **路径建议**: 完整（pipeline `--from 0 --gate-config all`）
- **状态**: draft

---

## Why（为什么做）

用户怀疑 flow-kit 的 L2/L3 独立审查机制（或其 bats 测试方案）存在缺陷，但仅靠静态审查现有测试（如 `test/test_l2_pretooluse_dispatch.bats`、`flow-kit-bundle/test/test_l2_pretooluse_dispatch.bats`）无法确认问题究竟在"测试没覆盖到"还是"机制本身行为异常"。上一个相关 change `l2-pretooluse-dispatch` 在 phase 7 被 stop，留下了未充分验证的 L2 PreToolUse dispatch 机制 + 新增的 `.specs/adr/003-l2-pretooluse-dispatch.md`。需要一次**诊断性实跑**：让一个真实 change 在全阶段 L2+L3 gate 开启下走完 0→7，把 L2（子 agent 盲审）与 L3（外部模型审查）在拦截 / `.done` 标记 / toll-gate 流转上的真实行为暴露出来，定位缺陷根因。

## What（做什么）

本 change **自身作为实验对象**，走完整 pipeline（`--from 0 --gate-config all`）。在 0→1→2→3→4→5→6→7 每个阶段触发 L2（子 agent 盲审）+ L3（外部模型）双层独立审查，实跑观察并记录：

- PreToolUse hook `independent-review-gate.sh` 的拦截时机与放行条件
- `.specs/<id>/.independent-review-<phase>.done` 标记的写入 / 读取 / 校验
- Stop hook `29-independent-review.sh` 的 L3 调度（外部模型调用 / 结果落盘）
- 各 toll-gate（`0→1` … `6→7`）的状态流转（pending → passed）

产出**诊断报告**（每阶段行为是否符合设计）。若发现缺陷，给出根因 + 修复建议；**是否当场修复**遵循"先诊断后定"原则，在报告产出后由用户决定。

## 影响面

- [x] 影响 `REQUIREMENT.md`（本次是新的诊断性需求）
- [ ] 影响 `DESIGN.md` / 引入新 ADR（先诊断；**若**诊断确认需改 hook/lib/prompt，可能回退 0.4 触及 ADR-003）
- [ ] 影响现有 AC（新 change，无既有 AC）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化（诊断性，**不预设**为 bug 修复）

## 范围排除（这次不做）

- **不预先重构** L2/L3 机制 —— 先诊断确认缺陷，再决定改不改、改哪里
- **不修改** ADR-003 —— 除非诊断确认其描述与实现行为不符
- **不扩大**到 L2/L3 之外的 hook（`26-workflow.sh` / `auto-checkpoint.sh` / `.l3-bg-*.json` 调度等）—— 聚焦 L2 PreToolUse dispatch + L3 review 调度链
- **不在诊断阶段引入新 feature**

## 验收线（粗粒度，不是 AC）

- **过程**：本 change 走完 0→7 全程，每阶段 L2/L3 行为有观察记录（拦截是否触发、`.done` 标记是否正确写入/读取、toll-gate 是否 pending→passed）
- **终态**：实跑 L2/L3 全链路（from 0 all）无异常 —— 拦截 / 标记 / gate 流转全程符合设计预期；若中途暴露异常，修复后重跑至此态

## 风险与未知

- **成本**：`--gate-config all` + `--from 0` 是最贵组合，保守 350k-650k+ tokens；若中途确认是局部问题，可 `/flow gate-config` 收窄省 30-50%
- **元回归风险**：用 flow-kit 自身的 L2/L3 审查 flow-kit 自身，若机制有 bug，审查结果本身可能不可信 → 需三路交叉验证（bats 静态测试 + 实跑观察 + `jq` 直接验证 `.flow-active` / `.done` 文件状态）
- **诊断型 change 的 TASK 适配**："先诊断后定"意味着 4-dev 阶段可能无传统功能代码可写，产物是诊断报告 + 视情况的小修；3-task 拆解需适配这种形态
- **工作区遗留**：上个 change `l2-pretooluse-dispatch`（phase 7 stop）留下一批未提交改动（`independent-review-gate.sh` / `29-independent-review.sh` / `l2-detect.sh` / `l3-review.sh` / `install_hooks.sh` 等均为 M）。本诊断实跑测的就是这批"已改未提交"的代码 —— 需在进入 1-requirement 前明确：是先提交它们再诊断，还是带着它们一起诊断（测的就是当前工作区状态）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
