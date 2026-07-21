# CHANGE: /code-review max 报告修复 — L2 盲审确认的 13 条缺陷

- **Change ID**: gate-review-fix
- **创建日期**: 2026-07-21
- **路径建议**: 完整
- **状态**: active

---

## Why（为什么做）

`/code-review max` 对 `develop` vs `main` 全量 diff（27 文件，~2664 insertions）产出了 15 条发现。经 L2 独立盲审逐条对照源码复核后，**13 条成立**（2 条被推翻）。其中包含：

- 1 条 CRITICAL 测试覆盖盲区（`test_l3_timeout.bats` 零覆盖，虚假测试信心）
- 1 条 HIGH 核心函数零覆盖（`done-validation.bats` 从未调用 `fk_validate_done_marker`）
- 5 条 MEDIUM correctness bugs（竞态、错误吞噬、auto_advance 矛盾）
- 4 条 MEDIUM DRY 违反（多处重复的 gate_val 标准化、phase 映射、L2 section check）
- 2 条 LOW 效率/路径 bug

不修会导致：虚假的测试覆盖信心、潜在的 `.done` 写入静默失败、gate 在 auto_advance 模式下误拦、维护期 phase 映射不一致风险。

## What（做什么）

按 L2 盲审确认的 13 条发现，对 7 个源文件 + 8 个测试文件进行精确修复：

**P0 · 测试覆盖盲区**
- `test_l3_timeout.bats`: 补 `REQUIREMENT.md` fixture，使 timeout 路径真正被测试覆盖

**P1 · correctness bugs**
- `l3-review.sh`: (a) `_l3_write_done` 的 `|| true` 改为显式 rc 处理 (b) `_l3_parse_result` 追加 L3 段前先删除旧段 (c) 修正 `_l3_build_prompt` fallback 路径 double-`lib/`
- `l2-detect.sh`: `l2_dispatch_agent` 加 `mkdir -p "$specs_dir"` + `.tmp.$$` 改 `.tmp.l2bg.$$` 防竞态
- `independent-review-gate.sh`: `_gate_check_l3` else 分支感知 `auto_advance`，非阻塞

**P2 · DRY 重构**
- `common.sh`: 新增 `fk_normalize_gate_val()`、`fk_extract_l2_verdict()` 共享函数
- `done-validation.sh`: `fk_independent_review_gate_active` 改用 `fk_phase_gate_key()` 替内联 case
- `29-independent-review.sh`: 删除重复 gate_val 读取，改用共享函数
- `independent-review-gate.sh`: `_gate_phase_filter` 改用 `fk_resolve_phase()`

**P3 · 测试修正**
- `done-validation.bats`: 改写为真正 source `done-validation.sh` + 调用 `fk_validate_done_marker`
- `test_l3_review.bats`: AC-3 修正为反映实际行为（或同步改代码实现去重）
- `test_l2_l3_granular_gate.bats`: 移除 `phases_done` 短路，让值域校验真正被执行

## 视觉调性（前端项目必填，由 0-change 步骤 0.6 预选填入）

不适用（非前端项目）。

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [x] 影响 `DESIGN.md` / 引入新 ADR（DRY 重构需设计决策：共享函数签名、放置位置）
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不新增功能特性——纯缺陷修复 + 测试加固 + DRY 重构
- 不碰 L2/L3 gate 架构设计（如 L2 dispatch 是否应从 PreToolUse 移出——那是另一个 change 的决策）
- 不修复 L2 报告中被推翻的 #1（PROJECT_ROOT）和 #9（KVP 注入）——前者经 L2 验证不成立，后者已有 grep 保护
- 不修改 `flow-kit-bundle/test/` 和 `test/` 镜像副本以外的文件
- 不新增 bats 测试文件——只修复现有测试的覆盖盲区

## 验收线（粗粒度，不是 AC）

1. 全量 bats 测试通过（`npx bats flow-kit-bundle/test/ test/`），包括修复后的 `test_l3_timeout`、`done-validation`、`test_l3_review`、`test_l2_l3_granular_gate`
2. `bash package-flow-kit.sh` 打包成功，产物 `flow-kit-bundle.tar.gz` 可正常生成
3. L3 独立审查（gate_config=all 各阶段）确认所有修复正确，无新引入的 regression

## 风险与未知

- DRY 重构（提取 `fk_normalize_gate_val` 等共享函数）需确认所有 consumer 已更新——具体 consumer 列表在 DESIGN 阶段穷举
- `_l3_parse_result` 增加 L3 段去重逻辑可能改变 `INDEPENDENT-REVIEW-N.md` 文件格式——需确认下游 reader（`_l3_inject_context`、SessionStart banner）兼容
- `.tmp.$$` → `.tmp.l2bg.$$` 的竞态修复仅在 L2/L3 同时写同一 phase 时相关，实际触发概率低——修复后无法通过常规测试验证（需构造并发场景）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
