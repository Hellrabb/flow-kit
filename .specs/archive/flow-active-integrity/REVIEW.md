# REVIEW: flow-active-integrity

- **Change ID**: flow-active-integrity
- **日期**: 2026-07-03
- **审核方式**: Self-review + L2 独立盲审（6 轮）

---

## 第一轮 · Spec 合规

| AC | 要求 | 覆盖 | 状态 |
|---|---|---|---|
| AC-1 | L2 PCSC 自检表 — 9 文件含统一锚点文本 | T02 verify + bats AC-1 ×2 | ✅ |
| AC-2 | L3 phase-artifact 对齐 | test_phase2_missing_design + test_phase1_all_present | ✅ |
| AC-3 | L3 change_id 一致性 | test_change_id_dangling + test_change_id_null_with_active_dirs | ✅ |
| AC-4 | L3 pipeline goal 字段交叉验证 | 4 test cases (含 R7 gate_not_passed) | ✅ |
| AC-5 | L3 updated_at 时效性 | test_stale_updated_at + test_fresh_updated_at | ✅ |
| AC-6 | L3 token_spent 未维护检测 | test_token_spent_zero_with_writes + test_token_spent_nonzero | ✅ |

**结论**: 6/6 AC 全部覆盖。

---

## 第二轮 · 代码质量

| 维度 | 评估 |
|---|---|
| **文件变更** | 17 files, +50/-14 lines（`git diff --stat HEAD`） |
| **本 change 新增** | `33-flow-active-integrity.sh`（280 行）, `test_flow_active_integrity.bats`（19 tests） |
| **本 change 修改** | 8 prompts + GO.md（L2 PCSC）, 00-gate.sh（33 接线）, common.sh（HOOK_MODULE_NAMES +1）, stop-hook.json（注册） |
| **顺带修复** | 00-gate.sh 同时补齐 31-auto-advance + 32-fallback-guard 的接线（此二模块自 pipeline-fallback-fix 创建以来从未在 00-gate.sh 接线，为 dead code） |
| **代码风格** | bash -n 语法通过；命名约定：00-gate.sh name 参数与 stop-hook.json key 已对齐（`flow_active_integrity`） |
| **错误处理** | 5 种异常场景容错（jq 缺失/JSON 损坏/目录不可读/PHASE_ARTIFACTS 回退/矫正文件合并）+ 矫正文件 type 合并策略（不同 type → `compliance+state-integrity`） |
| **禁动清单** | 未越界 |

---

## 第四轮 · 质量门禁

- **bats 测试**: 19/19 pass（新增 test_flow_active_integrity.bats）
- **全量回归**: 299/299 pass（280 existing + 19 new）
- **bash -n**: `33-flow-active-integrity.sh` + `00-gate.sh` 通过
- **prompt sync**: user-scope ↔ bundle 一致（18/18 文件）
- **stop-hook.json**: `flow_active_integrity` 已注册
- **L2 独立盲审**: 全 6 阶段完成（见下表）

---

## Phase 6 L2 发现修复记录

| # | 严重度 | 发现 | 修复 |
|---|---|---|---|
| R1 | 🟡 | run_module name 参数与 stop-hook.json key 不一致（`flow-active-integrity` vs `flow_active_integrity`） | ✅ 00-gate.sh name 参数改为 `flow_active_integrity` 与 stop-hook.json 对齐 |
| R2 | 🟡 | 矫正文件 type 字段跨模块合并漂移 | ✅ `_fai_append_violation` 合并时检测已有 type：不同则追加为 `compliance+state-integrity` |
| R4 | 🟡 | REVIEW.md 统计偏差（15→17 files, 46→50 ins, 210→280 lines, 17→19 tests） | ✅ 全部由 `git diff --stat` + `wc -l` + `grep -c @test` 重新提取 |
| R5 | 🟡 | 未区分"本 change 新增"与"顺带修复 31/32" | ✅ 第二轮明确标注"本 change 修改"与"顺带修复"分列 |

---

## L2 独立审查汇总

| 阶段 | 审查者 | Verdict | 关键发现 |
|---|---|---|---|
| 1-requirement | qa-expert | fail → fix | AC-1 验证锚点 / R2 PHASE_ARTIFACTS / R3 gates schema |
| 2-design | architect-reviewer | pass | R1-R4 Major 实施时处理 |
| 3-task | architect-reviewer | fail → fix | R1 stop-hook.json 路径 / R2 接线缺失 |
| 5-test | qa-expert | fail → fix | R1 AC-1 bats / R2 5轮金字塔 / R3 全量回归 |
| 6-review | code-reviewer | pass | R1-R5 🟡 已修复（见上表） |
| 7-integration | architect-reviewer | fail → fix | R1 L-019 + L-020 → LESSONS.md |
