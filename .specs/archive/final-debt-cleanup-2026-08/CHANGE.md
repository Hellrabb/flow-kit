# CHANGE · final-debt-cleanup-2026-08

> Phase 0 · 2026-08-03 · 一次性清理全部 10 项活跃债务

---

## § 1 Why（动机）

cleanup-debt-batch-2026-08 完成后仍剩 10 项活跃债务（3 归档文档教训 + 3 实测缺口 + 2 pre-existing 打包 + 2 大型重构）。本 change 一次性收尾，让 LESSONS.md / CONTEXT.md 进入"零 open 🟡+ 项"状态。

**触发**：用户在 cleanup-debt-batch-2026-08 archive 后明确要求"全部清理到这 10 个内容"。

---

## § 2 What（5 组 × 10 项）

### Group A · Quick fixes (TD-071-A + TD-071-B)

**TD-071-A** 🟢 — brooks-lint Part F 漏配
- 位置: `package-flow-kit.sh` Part F (lines 504-530)
- 修复: 加 `cp "$SRC/brooks-lint/plugin/skills/{brooks-audit,brooks-test}/SKILL.md" "$STAGING/..."`
- 验证: `package-flow-kit.sh --validate` 报 0 ERROR

**TD-071-B** 🟢 — A-evolve.md 源缺失
- 位置: `flow-kit-bundle/flow-kit/prompts/A-evolve.md`
- 修复: 查 archive 一致性，要么补文件、要么从 validate 白名单移除（决策见 DESIGN D1）
- 验证: `package-flow-kit.sh --validate` 报 0 WARNING

### Group B · Archived lessons 处理 (L-058 + L-060 + L-062)

3 项均在 archived superpowers-v6-absorb REQUIREMENT.md / DESIGN.md，无法直接修改文件。策略：
- **L-058** 🟢 (AC-A3 "如可用"): LESSONS.md 状态 active → "addressed-via-ADR"
- **L-060** 🟢 (范围决策嵌入 REQUIREMENT): 同上
- **L-062** 🟢 (task_progress lifecycle 图细节): 同上

修复方式：
1. 写 **ADR-019 "REQUIREMENT/DESIGN writing principles"** 固化这 3 条教训为未来 writing 标准
2. LESSONS.md 三项状态从 `active` → `✅ addressed via ADR-019`

### Group C · Verification/Spec (L-061 + L-063)

**L-061** 🟢 — ADR-016 探测脚本路径未验证
- 本 session 实测：调用 OpenCode task 工具，记录实际行为
- 修复：更新 ADR-016 或新建 ADR-020 标注实测结果
- 若 OpenCode 不支持：调整 ADR-016 的 fallback 路径

**L-063** 🟢 — D5/D6 弱模型缓解引用 ADR-001 不适配
- 实测环境（minimax-m2.7 / qwen3.6-35b-a3b）不可用
- 修复：写 **ADR-021 "Weak model prompt degradation protocol"** 文档化缓解策略（不需实测即可 spec）
- LESSONS.md 状态 active → "addressed-via-ADR-021"

### Group D · AC-B4 redesign (L-066)

**L-066** 🟢 — task-brief 测试深度不足
- 问题: AC-B4 仅测 task-brief 输出，未测合并指标（4-dev.md + task-brief 一起加载）
- 修复:
  1. 重写 AC-B4 措辞（在 archived superpowers-v6-absorb REQUIREMENT.md 中加 addendum section）
  2. 写新 bats 测试 `test_combined_metrics.bats` 测 (4-dev.md 352 + task-brief ~3KB) ≤ 目标阈值

### Group E · Major refactors (TD-008 + TD-017 + TD-018)

**TD-008** 🟡 + **TD-017** 🔴 — l3-review.sh 875 行拆分
- 位置: `flow-kit-bundle/hooks/stop/lib/l3-review.sh`
- 当前: 875 行 / 12 函数 / 4 职责（检测 + 派发 + 截断 + 格式化）
- 目标: 拆为 4 子库
  - `lib/l3-detect.sh` — backlog scan + 重复触发判定
  - `lib/l3-dispatch.sh` — API 调用 + timeout/error 处理
  - `lib/l3-truncate.sh` — smart truncation + head/tail
  - `lib/l3-format.sh` — verdict/summary 解析 + L3_RESULT 格式
  - `lib/l3-review.sh` → 编排层（≤200 行）
- 风险: 高（lib 被 PreToolUse + Stop hook 共用，禁动清单条目）→ 需完整回归 + 禁动 exception

**TD-018** 🔴 — independent-review-gate.sh::is_gh_pr_create 290 行拆分
- 位置: `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`
- 当前: 290 行 / 7+ gate 检查混合
- 目标: 提取 `_gate_path_guard / _gate_phase_filter / _gate_active_check / _gate_done_validation / _gate_tamper_check / _gate_phase_transition / _gate_l2_check / _gate_l3_check` + 编排器 `_run_review_gates()`
- 风险: 高（PreToolUse 关键路径）→ 需全 gate 场景集成测试

---

## § 3 影响面

### 修改文件（预计 ~15）

**Group A** (TD-071):
- `package-flow-kit.sh` (Part F 加 cp)
- 可能 `flow-kit-bundle/flow-kit/prompts/A-evolve.md` 或 validate 白名单

**Group B+C** (L-058/060/062/063):
- `.specs/LESSONS.md` (4 状态更新)
- `.specs/adr/019-requirement-writing-principles.md` (NEW)
- `.specs/adr/020-opencode-task-tool-verification.md` (NEW, 取决于实测)
- `.specs/adr/021-weak-model-prompt-degradation.md` (NEW)
- 可能 `.specs/adr/016-model-tier-dispatch.md` (更新)

**Group D** (L-066):
- `.specs/archive/superpowers-v6-absorb/REQUIREMENT.md` (addendum)
- `test/test_combined_metrics.bats` (NEW) + sync to bundle

**Group E** (TD-008/017/018):
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh` (拆分瘦身)
- `flow-kit-bundle/hooks/stop/lib/{l3-detect,l3-dispatch,l3-truncate,l3-format}.sh` (NEW)
- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` (拆分)
- 可能 `flow-kit-bundle/hooks/stop/29-independent-review.sh` (source 路径更新)
- `.specs/CONTEXT.md` (既有抽象索引 + 禁动 exception)
- `test/` 现有 l3/gate 测试补充

### 不动

- `flow-kit-bundle/flow-kit/prompts/*.md` (除非 Group D addendum)
- `flow-kit-bundle/flow-kit/scripts/`
- `flow-kit-bundle/flow-kit/reference/`
- `flow-kit-bundle/flow-kit/templates/`
- `.specs/CONTEXT.md` 域语言 / 已锁决策（仅追加既有抽象 + 禁动 exception）

---

## § 4 验收线

- 全部 10 项 LESSONS / TD 状态从 active/open → resolved / addressed-via-ADR
- ADR-019, ADR-020/021（如适用）入 `.specs/adr/`
- `package-flow-kit.sh --validate` exit 0 + 0 ERROR + 0 WARNING
- 全量 bats 0 fail（target ≥657 / ≥657 pass，新增 1+ 测试）
- dual-source diff 0
- Group E 拆分后：l3-review.sh ≤200 行 / independent-review-gate.sh 主函数 ≤100 行
- CONTEXT.md 既有抽象索引追加 4 个新 lib + 7 个 _gate_* 函数

---

## § 5 Risks

- **R1** (高): TD-008/017 l3-review.sh 拆分影响 L3 hook 主路径。缓解：分阶段（先抽 l3-format + l3-truncate 简单段，再抽 l3-dispatch API 段），每抽一段跑全量回归
- **R2** (高): TD-018 gate 重构破坏 PreToolUse 拦截。缓解：写集成测试覆盖 7 gate 场景（commit / transition / phase-write / handshake / tamper / l2-missing / l3-missing）后再拆
- **R3** (中): TD-071-B A-evolve.md 源缺失若需补文件，可能在 archive 历史中找不到原版。缓解：从 .specs/archive/ 找最早版本，找不到则从 validate 白名单移除
- **R4** (中): L-061 OpenCode task 工具实测若不支持 task-level model switching，ADR-016 整体逻辑需调整。缓解：fallback 路径已在 4-dev.md prompt hint 实现，不影响功能
- **R5** (低): Group D 在 archived REQUIREMENT.md 加 addendum 不符合"archive 不可变"惯例。缓解：在文件顶部加 `> Addendum 2026-08-03` 注明，不改原内容
- **R6** (中): gate_config=all 在 OpenCode 仍会触发 L3 model missing → degrade to L2。已在 cleanup-debt-batch-2026-08 验证 degration 路径正常

---

## § 6 v1 / v2 / out

- **v1** (本 change): 全部 10 项 — 5 group 全做
- **v2**: 无（这是收尾 change）
- **out**: 无（10 项全包）
