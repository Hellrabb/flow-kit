# 独立审查 · 阶段 1

> L2 blind review · REQUIREMENT.md · change-id: `final-debt-cleanup-2026-08`
> Reviewer: L2 independent sub-agent · 2026-08-03
> Artifacts reviewed: `.specs/final-debt-cleanup-2026-08/REQUIREMENT.md` (182 lines), cross-referenced against `CHANGE.md`, `CONTEXT.md`, `LESSONS.md`, `.specs/archive/superpowers-v6-absorb/REQUIREMENT.md`

---

## 审查汇总

| 维度 | 结果 |
|---|---|
| 5 用户故事清晰 | ✅ 4/5 完全清晰，US-5 目标可测性偏弱 |
| AC Given/When/Then 完整 | ⚠️ 15/15 GWT 完整，但 self-check 声称 16 |
| AC 可机器判定 | ⚠️ 12/15 完全可机器判定，3 条部分依赖人工 |
| 范围决策有理由 | ✅ 5/5 决策均有理由，无"等 DESIGN 细化"反模式 |
| v1/v2/out 明确 | ✅ v1=全部 10 项，v2/out=无 |
| NFR 可测 | ⚠️ Performance NFR 缺验证方式 |
| 无实现细节当 AC | ⚠️ AC-E1/E2 预设了具体函数/文件名 |
| US ↔ AC 数量匹配 | ✅ 每 US ≥1 AC |

---

## 发现

### F1 · AC 计数矛盾 🟡 Major

**Symptom** (REQUIREMENT.md:179): Self-check 行声称 "16 AC 全部 Given/When/Then 完整 ✓"，但实际 AC 数量为 15 条（A1/A2/B1/B2/C1/C2/D1/E1/E2/E3/F1/F2/F3/F4/F5）。

**Source**: 统计错误——自检时未逐条计数，猜测源自 group 数量误导（5 group 类别 ≠ AC 数量）。

**Consequence**: Self-check 是 phase 1 的最后一道质量闸，虚假声明削弱其可信度。若此错误滑入 DESIGN/TASK 阶段，会导致 task 拆分遗漏或 verify 覆盖缺口。

**Remedy**: 修正 self-check line 179 为 "15 AC"；自检时逐条计数（用 `grep -c "^\\*\\*AC-"` 或等效方法），不凭印象。

---

### F2 · AC-C1 验证方式不完全可机器判定 🟡 Major

**Symptom** (REQUIREMENT.md:63): AC-C1 验证方式为 `test -f .specs/adr/020-...` + "ADR 含实测 timestamp + verdict"，但后者无自动化 grep 断言，依赖人工阅读 ADR 内容。

**Source**: L-061 本身是行为任务（"主 agent 调用 task 工具派 subagent"），产出物是文档。`test -f` 只验证文件存在，不验证内容质量（ADR 是否真正含实测结果而非占位符）。

**Consequence**: 4-dev/TEST 阶段可能产出空壳 ADR（touch 文件）而自认为 AC 通过。类似 gate-integrity 的空 `.done` 反模式。

**Remedy**: 补充内容级验证命令——如 `grep -E "timestamp: 2026-08-0[3-9]" .specs/adr/020-*.md` + `grep -c "verdict:" .specs/adr/020-*.md` ≥ 1。或将 VERIFY 拆为两段：文件存在（机器）+ 内容质量（人工 sign-off）。

---

### F3 · AC-D1 addendum 内容验证不充分 🟡 Major

**Symptom** (REQUIREMENT.md:78): AC-D1 验证方式 `grep -A2 "Addendum 2026-08-03" ... | grep -c "AC-B4"` ≥ 1 仅验证 addendum 段**提及** AC-B4，不验证 addendum 是否真的**重写了 AC-B4 措辞为可测条件**。

**Source**: 只检查关键词存在，不检查语义质量。AC 的 Then 要求"重写 AC-B4 措辞为可测条件"，但验证方式只证实"提到了 AC-B4"。

**Consequence**: addendum 可以是 `AC-B4: 已检查，无需修改` 之类空洞语句却通过 AC。L-066 的本质问题（AC-B4 措辞模糊）未真正修复。

**Remedy**: 验证方式追加内容级检查——grep addendum 段是否含新的 Given/When/Then 模板或 `wc -c` / `≤` 等可测度量关键词。或在 AC-D1 Then 中明确 addendum 必须包含的具体元素（如"新 AC-B4 含 Given/When/Then + wc -c 断言"）。

---

### F4 · AC-E1/E2 预设实现细节为 AC 🟡 Major

**Symptom** (REQUIREMENT.md:86-98): AC-E1 Then 子句硬编码了拆分后的具体文件名（`l3-{detect,dispatch,truncate,format}.sh`），AC-E2 Then 子句硬编码了 8 个 `_gate_*` 函数名。违反 AC 应描述 "what" 而非 "how" 的原则。

**Source**: CHANGE.md §2 Group E 在设计阶段做了分解决策（"拆为 4 子库：l3-detect / l3-dispatch / l3-truncate / l3-format"），但 REQUIREMENT 将 DESIGN 级决策提升为 AC 约束。

**Consequence**: 若 DESIGN 阶段发现更优分解方案（如合并 l3-detect+l3-truncate 为 l3-prepare），AC 硬约束会迫使选次优方案或触发 requirement 修订循环。过度约束了 DESIGN 空间。

**Remedy**: AC Then 改为定性约束 + 定量边界——"拆为 ≤5 子库，每库 ≤250 行，编排层 ≤200 行，`npx bats test/` 全量 pass"。具体文件名/函数名由 DESIGN 定。若当前分解方案确认为最优，可在 CHANGE.md scope decisions 中作为建议而非 AC 硬约束。

---

### F5 · AC-F3 meta 矛盾：禁动清单修改本身是禁动 🟡 Major

**Symptom** (REQUIREMENT.md:132): AC-F3 Then 要求"禁动清单追加 l3-review.sh 拆分后 4 子库 + independent-review-gate.sh 重构后内部函数"。REQUIREMENT 未处理 meta 矛盾——CONTEXT.md 禁动清单的**更新流程本身**是否受禁动清单保护。

**Source**: CONTEXT.md § 禁动清单条目 `independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker — gate 校验核心链` 含例外声明的先例（L-072 fix 例外），但 REQUIREMENT 未明确本 change 的禁动 exception 写入流程——谁批准、写在哪里、用什么格式。

**Consequence**: 4-dev 阶段 AI 可能在未获显式 exception 的情况下修改禁动清单，触发 CONTEXT.md 禁动清单的 self-referential violation。或 AI 因过度谨慎拒绝修改导致 AC-F3 无法完成。

**Remedy**: 在 REQUIREMENT §3 范围决策中追加一条："TD-008/017/018 涉及禁动清单条目（l3-review.sh / independent-review-gate.sh / gate 校验核心链）——本次 change 的 禁动 exception 写入流程：① CHANGE.md §5 Risks 记录每项禁动条目的 exception 理由 ② 4-dev 1.4 步骤读 RISKS 中的 exception 后执行 ③ 修改后 AC-F3 更新 CONTEXT.md 禁动清单"。参照 L-072 fix 例外格式。

---

### F6 · NFR Performance 缺验证方式 🟡 Major

**Symptom** (REQUIREMENT.md:169): NFR Performance 声明"单测 ≤5s；l3-review.sh 拆分不增加 source overhead（< 50ms 增量）"，但无对应 AC 验证这些指标。

**Source**: NFR 段写了性能约束但未映射到任何 AC 的验证方式。没有 bats 测试覆盖 source overhead 测量或单测耗时断言。

**Consequence**: NFR 声明是空话——无人检查也不会被检查。若拆分后 source overhead 实际增加 200ms（10 个 lib 串行 source），不会在任何 gate 被捕获。

**Remedy**: 二选一——(a) 将 source overhead 检查作为 AC-E3 集成测试的一部分（`time bash -c "source <lib>..."` 断言）(b) 若 overhead 不重要，从 NFR 移除或降为 "best-effort"。当前形式（写了但不验）比不写更危险——制造虚假质量保证感。

---

### F7 · NFR Security 混入设计约束 🟢 Minor

**Symptom** (REQUIREMENT.md:170): "拆分后 lib 不引入新网络调用 / 不放宽 path guard"——这是设计约束而非 NFR 属性。"不引入新网络调用"由 AC-F5 全量 bats 回归间接覆盖；"不放宽 path guard"依赖 code review，不是可测量属性。

**Source**: NFR 段意图良好但措辞偏离 NFR 标准格式（NFR 应描述系统级质量属性：可靠性/安全性/可维护性的**可测量阈值**）。

**Consequence**: 低风险——拆分本身就是纯 Bash 重构，不涉及网络调用。path guard 由 gate 集成测试（AC-E3）覆盖。

**Remedy**: 将"不引入新网络调用"移至 AC-E3 集成测试 verify 中作为显式检查（`grep -r "curl\|wget\|nc " flow-kit-bundle/hooks/stop/lib/l3-*.sh` 返回空）。"不放宽 path guard"作为 code review checklist 项，不驻留在 NFR。

---

### F8 · US-3/US-5 目标陈述可测性偏弱 🟢 Minor

**Symptom**:
- REQUIREMENT.md:17: US-3 目标 "通过实测或 ADR 文档化方式**填补**"——"填补"非可测量 outcome。
- REQUIREMENT.md:22: US-5 目标 "**降低未来改动门槛**"——长期效果无法在当前 change 验证。

**Source**: 用户故事模板要求 "measurable outcome"，但 US-3/US-5 用了定性动词。

**Consequence**: 低风险——AC 提供了可测量的细化条件（C1/C2 的 ADR 存在性 + E1/E2/E3 的 wc -l + bats pass）。US 的目标陈述作为 narrative framing 可以接受。

**Remedy**: 在 editorial pass 中将 US-3 outcome 改为 "…两条 spec 缺口通过可验证的 ADR 或实测文档关闭"；US-5 outcome 改为 "…三项长函数拆分为符合行数上限的单一职责子模块"。

---

## Special attention 逐项评估

### 1. AC-B1 (ADR-019) — ADR 不存在时的 AC 可验证性 ✅

ADR-019 确实不存在于 `.specs/adr/`（glob 确认）。AC-B1 的 Then "ADR 含 3 条原则" + 验证方式 `grep -c "^## " ... ≥ 4` 是结构级断言——不依赖 ADR 具体内容，只检查文件存在 + 标题数量。这是 REQUIREMENT 阶段的合法做法。✅ **通过**。

### 2. AC-C1 (L-061 OpenCode task 工具实测) — 行为型 AC ⚠️

Given/When 是行为指令（"主 agent 调用 task 工具派 subagent"），非系统状态。这在 L-061 的文档化任务场景中可接受——AC 的真正产出是 ADR-020 文件。但验证方式不完全自动（见 F2）。⚠️ **有条件通过——需补内容级验证**。

### 3. AC-D1 addendum 模式 — 是否真修复 L-066 ⚠️

addendum 在 archived REQUIREMENT.md 末尾追加而不改原内容——保 archive 不可变惯例，方向正确。但当前验证方式仅检查 AC-B4 被提及，不检查 addendum 真的重写了措辞（见 F3）。若 addendum 写成 "AC-B4: 原措辞已足够，无需修改"，L-066 实际上未被修复。⚠️ **有条件通过——需补内容级验证**。

### 4. AC-E1/E2 行数阈值 — 合理性评估 ✅

- AC-E1: l3-review.sh 当前 875 行/12 函数 → 5 文件 ≤200+250+250+250+250=1200 行。拆分会增加总行数（source 语句/函数签名/注释），±35% overhead 合理。
- AC-E2: is_gh_pr_create 当前 290 行 → 编排器 50+100+8×60=630 行。拆分 overhead ±2x，但 `_gate_*` 函数是纯提取（不加新逻辑），单函数 ≤60 行合理。

✅ **通过**。

### 5. AC-F3 CONTEXT.md 禁动 exception meta 矛盾 ⚠️

见 **F5**。REQUIREMENT 未处理"修改禁动清单时如何获取 exception"的流程问题。⚠️ **需补充**。

### 6. TD-008/017/018 禁动 exception 写入流程 ⚠️

见 **F5**。CHANGE.md §5 Risks 提到了 R1 "需完整回归 + 禁动 exception"和 R2 "需全 gate 场景集成测试"，但 REQUIREMENT 未将 exception 流程 formalize。⚠️ **需补充**。

---

## Verdict: PASS

**条件**: 以下 Major 问题在进入 DESIGN 前须解决：

1. **F1** — Self-check AC 计数 16→15 修正
2. **F2** — AC-C1 验证方式补内容级 grep 断言
3. **F3** — AC-D1 验证方式补措辞改写检查
4. **F4** — AC-E1/E2 解耦具体文件名/函数名与定量边界
5. **F5** — 补充禁动 exception 写入流程（§3 范围决策或独立段）
6. **F6** — NFR Performance 补验证方式或移除不可验指标

**理由**: 零 🔴 Critical 发现。所有 🟡 Major 均为可修复的措辞/验证缺口，不影响需求方向正确性。5 用户故事覆盖全部 10 项债务，AC 结构完整，v1/v2/out 明确。

---

> 审查完毕 · 15 AC reviewed · 10 交叉引用点验证 · LESSONS.md L-058/060/061/062/063/066 + TD-071-A/071-B/008/017/018 全部在案

---

## 主 agent 响应

### F1 (🟡 → ✅ Fixed): Self-check AC 计数 16→15
**Fixed in**: REQUIREMENT.md §6 Self-check 行修正为 "15 AC"，列出完整 AC ID 清单。

### F2 (🟡 → ✅ Fixed): AC-C1 验证方式补内容级 grep
**Fixed in**: REQUIREMENT.md AC-C1 verify 段追加 3 条 grep 断言（timestamp + verdict + 分类词）。

### F3 (🟡 → ✅ Fixed): AC-D1 addendum 内容验证
**Fixed in**: REQUIREMENT.md AC-D1 verify 段追加 `grep -E "(Given|When|Then|wc -c|≤|byte)" | wc -l` ≥ 3。

### F4 (🟡 → ✅ Fixed): AC-E1/E2 解耦实现细节
**Fixed in**: REQUIREMENT.md AC-E1/E2 Then 改为定量边界（≤200/≤250/≤1500 总行数 / ≤50/≤100/≤60），具体文件名/函数名标注为 "由 DESIGN §1 决定"。

### F5 (🟡 → ✅ Fixed): 禁动 exception 写入流程
**Fixed in**: REQUIREMENT.md §3 范围决策追加 "禁动 exception 写入流程" 段，4 步流程 + L-072 fix 先例引用 + meta 矛盾处理说明。

### F6 (🟡 → ✅ Fixed): NFR Performance 验证
**Fixed in**: REQUIREMENT.md §5 NFR Performance 每项标注 verify 来源（AC-E3 集成测试 SECONDS 断言 + source overhead check）。

### F7 (🟢 → ✅ Fixed): NFR Security 移至 AC verify
**Fixed in**: REQUIREMENT.md §5 NFR Security "不引入新网络调用" 验证映射到 AC-E3 source overhead check 段的 no new network calls grep。

### F8 (🟢 → ✅ Fixed): US-3/US-5 outcome 可测化
**Fixed in**: REQUIREMENT.md US-3 outcome 加 "通过可验证的 ADR 或实测文档关闭"；US-5 outcome 加 "符合行数上限的单一职责子模块"。

---

**主 agent 复判 Verdict**: ✅ **PASS**（全部 6 Major + 2 Minor 修复完成）。
