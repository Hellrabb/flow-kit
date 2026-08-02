# 独立审查 · 阶段 3

> **审查对象**: `.specs/cleanup-debt-batch-2026-08/TASK.md`
> **参考工件**: REQUIREMENT.md + DESIGN.md + CONTEXT.md
> **审查日期**: 2026-08-03

---

## L2 盲审

### 🟡 M1 · REQUIREMENT.md AC-C/L-070 残留引用——已移出范围但未清理

**Severity**: 🟡
**Symptom（症状）**: REQUIREMENT.md:51-63, REQUIREMENT.md:133
**Source（源头）**:
- INDEPENDENT-REVIEW-2 R1 确认 L-070 基于虚假前提（`validate_staging_coverage()` 早已正确 `exit 1`），主 agent 响应将 L-070 移出 v1 范围。DESIGN.md D2/R3/§0.5 均已同步修正，标明"L-070 已确认非 bug，移出范围"。
- 但 REQUIREMENT.md 仍残留：
  - **L51-63**: 完整的 `类别 C · L-070 package validate exit code` 段，含 AC-C1、AC-C2 两个验收准则（Given/When/Then）
  - **L133**: v1 范围列表中含 `- L-070 package validate exit code`
- TASK.md 中无任何 task 引用 AC-C1 或 AC-C2（grep 确认 0 命中）。
**Consequence（后果）**:
1. 可追溯性矩阵断裂：AC-C1/AC-C2 在 REQUIREMENT.md v1 范围中列出，但无任何 task 声称覆盖。若读者只看 REQUIREMENT + TASK 而不读 DESIGN，会认为漏分了 task。
2. 若未来有人按 REQUIREMENT.md 重新生成 TASK.md（如 `flow-task` 自动拆分），会为 L-070 再产出一个 task——基于已被证伪的前提。
3. Special attention item 3 明确要求：`verify REQUIREMENT/DESIGN/TASK no longer reference AC-C (validate exit code). If any stale reference exists, flag as 🟡.`
**Remedy（修补）**:
1. 从 REQUIREMENT.md 移除 类别 C 段（L51-63）
2. v1 范围列表（L133）中删除 `- L-070 package validate exit code`
3. AC 编号无需重排（AC-C 作为保留空洞比全局重编号更安全——避免下游引用断裂），但需在段首加 `> **REMOVED**：L-070 经 INDEPENDENT-REVIEW-2 确认基于虚假前提，已移出本 change 范围。` 注明

---

### 🟡 M2 · T04 verify 仅检 4/8 锚点——4 个标题锚点无即时验证

**Severity**: 🟡
**Symptom（症状）**: TASK.md:176-184（T04 `<verify>`）
**Source（源头）**:
- AC-E2（REQUIREMENT.md:87-91）要求 8 个 grep anchor 全部命中（count ≥1 每个）。DESIGN D5（DESIGN.md:192）规划了专用测试文件 `test/test_4_dev_compress.bats` 覆盖 AC-E2 全量验证。
- T04 `<verify>` 中的锚点检查仅覆盖 4/8：
  ```
  ANCHORS=$(grep -cE '(task-brief|model-tier|task_progress|@see reference/)' 4-dev.md)
  [ "$ANCHORS" -ge 4 ]
  ```
  这 4 个均为"功能字段出现"锚点，但 **4 个标题锚点完全未被 T04 verify 覆盖**：
  - `^### 1\.4`（TDD 工作流入口）
  - `^### 5\.`（提交协议入口）
  - `^### 6\.`（task 完成提交入口）
  - `^## 中途断点`（checkpoint 入口）
- 标题锚点的"保留"定义在 DESIGN D4（DESIGN.md:174）为"**保持原 h3/h2 层级不变**，仅段内容改为简短 trigger + @see"。若实施时误将标题降级、删除或合并，T04 verify 无法发现——4 个 grep 模式均不匹配标题行。
**Consequence（后果）**:
1. 实施者可能在抽取 reference 时不小心删除/降级标题，T04 verify 仍报"✓ 4 anchors present"假绿。
2. T04 done 声称 "AC-E2 (8 锚点 ≥4 出现)"——该声明在 T04 verify 中部分可验证（4/8），剩余 4 个锚点需等到 T05 全量 bats 才暴露。
3. 若 T05 的 `test/test_4_dev_compress.bats` 尚未编写（DESIGN D5 中的"新"文件），则 4 个标题锚点的验证完全悬空。
**Remedy（修补）**: T04 verify 末尾追加标题锚点检查：
```bash
HEADINGS=$(grep -cE '^(### 1\.4|### 5\.|### 6\.|## 中途断点)' flow-kit-bundle/flow-kit/prompts/4-dev.md)
[ "$HEADINGS" -ge 4 ] && echo "✓ 4 heading anchors preserved (≥4)"
```
或至少一个 `grep -q '^### 1\.4'` 确保 TDD 入口锚点未消失（最关键的 1 个，涉及 1.8 破坏性变更协议入口）。

---

### 🟢 M3 · T05 write_files 列表是 make test-sync 输出的子集

**Severity**: 🟢
**Symptom（症状）**: TASK.md:201-204（T05 `<write_files>`）
**Source（源头）**:
- T05 `<action>` 步骤 1 执行 `make test-sync`，该 target 会同步 `test/` 下全部 .bats 文件到 `flow-kit-bundle/test/`（不止 2 个）。
- T05 `<write_files>` 仅列出 `test_scripts_security.bats` 和 `test-l2-first-correction.bats`，未包含其他可能被 make test-sync 触达的文件。
**Consequence（后果）**: 不影响功能正确性——write_files 为"预期触碰"声明，非精确目录清单。make test-sync 的额外输出是良性副作用。但若未来有自动化校验 `write_files ⊆ DESIGN §0.5.1`，额外写入可能触发 false-positive。
**Remedy（修补）**: 在 write_files 注释中标注 "make test-sync 实际同步 test/ → flow-kit-bundle/test/ 全部 .bats，此处仅列出本 change 涉及的差异化文件" 消除歧义。或保持现状（🟢 不阻塞）。

---

### 🟢 M4 · T05 done 中 AC-F2 "≤5s/2 文件" 与 verify 中 "$SECONDS -le 60" 不一致

**Severity**: 🟢
**Symptom（症状）**: TASK.md:224（T05 `<done>`）vs TASK.md:218-219（T05 `<verify>`）
**Source（源头）**:
- T05 `<done>` 声明 `AC-F2 (≤5s/2 文件)`。
- T05 `<action>` 步骤 5 有 `SECONDS=0; npx bats test/test_scripts_security.bats test/test_integration_smoke.bats; [ $SECONDS -le 5 ]`——此处 ≤5s。
- 但 T05 `<verify>` 使用 `SECONDS=0 && npx bats test/ 2>&1 | tail -3 && [ $SECONDS -le 60 ]`——此处分母更大（全量 bats ≥657 tests），超时阈值 60s。
- 两个检查测量不同的东西：action 测 2 文件（≤5s），verify 测全量（≤60s）。done 中的 "AC-F2 (≤5s/2 文件)" 是 action 的声明，与 verify 的全量 60s 不矛盾。
**Consequence（后果）**: 阅读混淆——done 字段引用 AC-F2 但 verify 命令的 $SECONDS 阈值是 60s 而非 5s。读者可能以为 verify 中的 60s 是笔误。
**Remedy（修补）**: done 字段改为 `AC-F2 (≤5s/2 文件 · action step 5) + 全量 ≤60s (verify)` 区分两个层次。或保持现状（🟢 不阻塞，AC-F2 实际定义在 action step 5）。

---

### 附录 · Checklist 逐项判定

| # | 检查项 | 结果 | 证据 |
|---|---|---|---|
| 1 | 每 task 7 字段完整 | ✅ | T01-T05 均含 id/name/read_files/write_files/action/verify/done |
| 2 | write_files ⊆ DESIGN §0.5.1 | ✅ | 全部 13 个 write_files 路径在 DESIGN §0.5 表格中（含 bats + reference 新文件） |
| 3 | write_files 禁动清单例外 | ✅ | T03 `29-independent-review.sh` 在禁动清单，DESIGN D3 + plan-conflict-scan 均声明例外 |
| 4 | verify 均可执行 | ✅ | 全部使用 `npx bats` / `bash script` / `wc -l` / `grep` / `diff` |
| 5 | depends_on 无环 + 引用有效 | ✅ | T01/T02/T03 empty → T04→T05，无环 |
| 6 | parallel tasks 真独立 | ✅ | T01/T02/T03 无共享 write_files，属不同模块 |
| 7 | ≥1 [P] task | ✅ | T01[P] + T02[P] + T03[P] |
| 8 | 波次与 depends_on 一致 | ✅ | Wave 1: 无依赖并行 / Wave 2: T04 依赖 Wave 1 / Wave 3: T05 依赖全部 |
| 9 | AC 全覆盖 | ⚠️ | AC-C1/AC-C2 无覆盖 — 见 M1（L-070 已移出范围，REQUIREMENT.md 未清理） |
| 10 | plan-conflict-scan 3 类 | ✅ | 内部一致性 / 禁动清单 / ADR 三类均覆盖 |
| 11 | action 含 design 交叉引用 | ✅ | T01→D1, T02→D2(隐式), T03→D3, T04→D4, T05 为 meta 任务 |

### 附录 · Special attention 逐项判定

| # | 关注项 | 结果 | 证据 |
|---|---|---|---|
| 1 | T03 禁动清单例外范围 | ✅ | action 步骤 1-3 明确仅移 L181-185 到 L58 之前，不改块内逻辑；plan-conflict-scan 行 244-245 确认限制 |
| 2 | T04 reference 文件命名 | ✅ | `tdd-workflow` / `commit-protocol` / `checkpoint-protocol` 均 kebab-case，与既有 12 个 reference/*.md 命名一致 |
| 3 | L-070/AC-C 残留引用 | 🟡 | M1 — REQUIREMENT.md:51-63,133 残留；TASK.md 0 命中 ✅；DESIGN.md 已清理 ✅ |
| 4 | AC-E2 锚点 ≥4 | ✅ | T04 verify `ANCHORS -ge 4` + done 字段声明 "≥4 出现" 一致；M2 标注剩余 4 个标题锚点的验证延迟 |

---

**Verdict**: **pass** (with 2 🟡 advisories)

🟡 M1（REQUIREMENT.md AC-C 残留）是 phase 3 外（REQUIREMENT 属 phase 1 工件），不阻塞 TASK.md 本身的正确性，但需在 phase 4 实施前清理，否则会误导 task 覆盖判断。
🟡 M2（T04 verify 标题锚点不检）为验证覆盖偏窄——不阻塞 task 执行，但增加了 T05 才发现锚点丢失的返工风险。

两项目前均不构成 🔴 Critical 阻断——depends_on 图无环、write_files 合规、verify 可执行、AC 覆盖率（已移出 L-070 后 12/14 = 86%）可接受。

---

## 主 agent 响应（2026-08-03）

### M1 🟡 — Fixed
REQUIREMENT.md L51-63 (类别 C · L-070) 已改为删除线 + 说明段（"已移出范围 · INDEPENDENT-REVIEW-2 R1 验证为假前提"），AC-C1/AC-C2 撤销。REQUIREMENT.md L120-126 v1 范围列表移除 L-070 行 + 追加澄清说明。**Fixed in**: REQUIREMENT.md:51-54, 120-127。

### M2 🟡 — Acknowledged, deferred to T05
T04 verify 现仅查 4 patterns（`task-brief|model-tier|task_progress|@see reference/`）。8-anchor 全量验证由 T05 全量 bats 回归覆盖（含 test_4_dev_compress.bats 专用测试）。T04 inline verify 为快速反馈，T05 为最终把关——分工合理，不改 T04 verify。**Accepted as-is**.

### M3 🟢 — Acknowledged
T05 write_files 仅列 2 个 explicit sync 目标，但 action 含 `make test-sync` 会同步所有 test/→bundle/。write_files 是 R6.5 边界声明的最小集，make test-sync 在 action 内部执行不算"声明外写"。**Accepted as-is**.

### M4 🟢 — Acknowledged
T05 done "≤5s/2 文件" 与 verify "≤60s 全量" 是不同测量点。done 描述单任务时长（AC-F2），verify 测全量回归时长。**Accepted as-is**.

**Pipeline 继续推进到 phase 4。**
