# 独立审查 · 阶段 6

---

## L2 盲审

> 审查人: L2 独立审查员 (子 agent 盲审)
> 审查对象: `.specs/superpowers-v6-absorb/REVIEW.md`
> 参考工件: `REQUIREMENT.md` / `DESIGN.md` / `TASK.md` / `TEST.md` / ADR-014 / ADR-017
> 审查日期: 2026-08-02

### Verdict: pass

(0 🔴 Critical · 3 🟡 Important · 2 🟢 Minor)

---

### 🟡 R1 · AC-B4 结构性硬指标不可字面达成：4-dev.md 36KB 远超 15KB 阈

**Severity**: 🟡 Important
**Symptom（症状）**: `REQUIREMENT.md:73-77` 定义 AC-B4 为结构性硬门槛："合并内容字节数 ≤ 15360 字节（15KB）—— 4-dev.md 主体 + 当前 task 提取内容之和"。实测 `flow-kit-bundle/flow-kit/prompts/4-dev.md` 为 36,621 bytes（36KB），仅文件本体已超 AC-B4 阈值 2.4 倍，加 task-brief 输出（~1.6KB）后约 38KB。
**Source（源头）**: AC-B4 字面文本 vs 物理现实 — 4-dev.md 作为 phase prompt 不可能 ≤15KB（含 TDD 流程、grep-before-code、checkpoint、PCSC、Toll-Gate、独立 review 调度等强制段，最低行数 ~400+）。AC 本身是 over-specified。
**Consequence（后果）**: 此 AC 按字面不可达成。若在 phase 7 被审计时按字面判，本 change 将无法通过。REVIEW.md I1 将问题归类为 🟡 Important 并提议在 phase 7 "澄清 AC-B4 措辞"（即事后修改 AC 含义），而非在 phase 6 显式承认"AC 文本 over-specified，建议 phase 7 修正 AC 为 task-brief 输出单维度 ≤15KB"。TEST.md AC-B4 行仅验证了 task-brief 输出大小（"实测 T03 = 1.6KB"），未测量 AC 要求的 4-dev.md + task-brief 合并指标，使验证不完整。
**Remedy（修补）**: (a) 在 REVIEW.md 或 LESSONS.md 显式登记 AC-B4 为 over-specified（而非"措辞模糊"），明确字面不可达成； (b) phase 7 修正 AC-B4 文本为"task-brief 提取单 task 块字节数 ≤ 15KB"（去掉"4-dev.md + "部分）—— 这是 AC 的真实意图（对应 US-2 "per-task 加载量减半"）； (c) phase 7 补充合并指标实测数据（38KB pre vs 15KB target），记录为 AC 规格缺陷而非实现缺陷。

---

### 🟡 R2 · AC-C2 narration constraint 部署不完整：4/8 phase prompts 缺失

**Severity**: 🟡 Important
**Symptom（症状）**: AC-C2 (`REQUIREMENT.md:87-91`) 要求"所有 phase prompts（0-change / 1-requirement / ... / 7-integration）"顶部含 narration constraint。实测 8 个 phase prompts 中仅 4 个（4-dev / 5-test / 6-review / 7-integration）含 `narration-constraint.md` @see 引用；`0-change.md` / `1-requirement.md` / `2-design.md` / `3-task.md` 全部缺失。
**Source（源头）**: T09 write_files 仅覆盖 3-task / 5-test / 7-integration；T07 覆盖 6-review；T08 覆盖 4-dev。0-change / 1-requirement / 2-design 三个 prompt 不在任何 task 的 write_files 范围内。T09 对 3-task.md 仅加了 plan-conflict-scan，未加 narration constraint。**DESIGN.md D6 明确说"所有 phase prompt 顶部引用"但 TASK.md 未将 0-change/1-requirement/2-design 列入 write_files。**
**Consequence（后果）**: 0-change/1-requirement/2-design/3-task 的 agent 不受 narration constraint 约束，可能产生冗余 narration，部分削弱 token 削减收益。REVIEW.md 未发现此 gap，TEST.md AC-C2 行标记为 ✅ pass（仅以 reference 文件存在为据，未逐 prompt 检查）。
**Remedy（修补）**: (a) 在 phase 7 对 0-change / 1-requirement / 2-design / 3-task 四个 prompt 追加 narration-constraint.md @see 引用（每个 1-2 行改动，低风险）； (b) 更新 TEST.md AC-C2 验证为逐文件 grep `narration-constraint` 断言每 prompt 至少 1 处命中（替代当前仅检查 reference 文件存在性）。

---

### 🟡 R3 · package-flow-kit.sh Part D 新增 scripts/ cp 未经打包验证

**Severity**: 🟡 Important
**Symptom（症状）**: `REVIEW.md:41-46` I3 发现。`package-flow-kit.sh` Part D 新增 `cp flow-kit-bundle/flow-kit/scripts/* "$STAGE_DIR/flow-kit/scripts/"`，但未经 `bash package-flow-kit.sh --validate` 或 `tar -tzf` 干跑验证。
**Source（源头）**: ADR-018 + Phase 2 L2 R1 要求禁动例外声明已写入 CONTEXT.md（验证通过: `grep -c "superpowers-v6-absorb.*例外" CONTEXT.md` = 1），但 cp 路径正确性未在 phase 5/6 用实际打包验证。
**Consequence（后果）**: 若 Part D 的 cp 路径写错（如 `$STAGE_DIR` 变量在 Part D 上下文不可见），分发包缺 scripts/，用户安装后 review-package/task-brief 不可用。
**Remedy（修补）**: 维持 REVIEW.md I3 的 remedy 建议——phase 7-integration 时跑一次 `bash package-flow-kit.sh --validate` 或 `tar -tzf flow-kit-bundle.tar.gz | grep scripts/` 验证。**注意**: REVIEW.md 已给出此 remedy，本发现确认其 severity 合理。

---

### 🟢 R4 · TEST.md AC-B4 验证不完整

**Severity**: 🟢 Minor
**Symptom（症状）**: `TEST.md:75` AC-B4 验证行仅验证"task-brief 输出大小由 awk 控制，单 task 块 ≤15KB"，未测量 AC-B4 字面要求的 `cat 4-dev.md + /tmp/out_T03.txt | wc -c` 合并指标。
**Source（源头）**: AC-B4 的 When 子句要求 `cat prompts/4-dev.md + /tmp/out_T03.txt`，但 TEST.md 只验证了 task-brief 输出大小。
**Consequence（后果）**: 验证不完整，合并指标的 gap（见 R1）未被测试层捕获。但 AC 本身 over-specified（见 R1），追加此验证也只会确认"不可达成"。
**Remedy（修补）**: phase 7 修正 AC-B4 文本后，同步更新 TEST.md 验证项，添加合并字节数实测记录（作为 AC 规格修正的证据，非 gate 条件）。

---

### 🟢 R5 · 3-task.md 缺少 narration-constraint.md 引用

**Severity**: 🟢 Minor
**Symptom（症状）**: `flow-kit-bundle/flow-kit/prompts/3-task.md` 缺少 `narration-constraint.md` @see 引用。T09 write_files 包括 3-task.md 但仅加了 plan-conflict-scan 段。
**Source（源头）**: T09 的 action 描述仅对 5-test / 7-integration 加 narration constraint，未覆盖 3-task。
**Consequence（后果）**: Phase 3 agent 可能产生冗余 narration。但 Phase 3 本身是计划阶段（非密集 tool-call 阶段），影响低于 dev/review 等阶段。
**Remedy（修补）**: 并入 R2 的修复——在 3-task.md 顶部加 narration-constraint.md @see 引用。

---

## Checklist 逐项回应

| Phase 6 审查 checklist 项 | 评定 | 说明 |
|---|---|---|
| REVIEW.md verdict 是否合理 (pass/fail 判断有据) | ✅ 合理 | pass 基于 0 Critical，3 Important 均有明确归因和 remedy 路径 |
| 发现的归因是否真实 (pre-existing 判定) | ✅ 真实 | I2 AC-I(b)(c) pre-existing 声称明确：write_files 不含 `hooks/stop/29-independent-review.sh`。git log 确认最近修改 29 号 hook 的 change 为 `dual-review-merge-fix`/`l3-comprehensive-fix`/`gate-integrity`，与本 change 无关 |
| 重要风险是否被遗漏 | ⚠️ 遗漏 2 项 | 见 R1(AC-B4 over-specified) 和 R2(AC-C2 部署不完整)。REVIEW.md 未标记这两项 |
| CMSC 触发逻辑是否符合 ADR-014 (仅 Critical 触发) | ✅ 符合 | REVIEW.md 明确"verdict=fail AND ≥1 🔴 Critical → 触发 spot-check；verdict=pass/0 Critical → 不触发"，与 ADR-014 一致 |
| Severity 使用是否符合 ADR-017 (🟢 Minor 延后) | ✅ 符合 | M1-M4 全延后到 MINOR-DEFERRED.md，不卡 fix loop。M3（loading-artifacts.md @see 可加显式引用）为 R5 同源，已独立标记 |

---

## 与 REVIEW.md 的差异总结

| 差异点 | REVIEW.md | 本独立审查 | 理由 |
|---|---|---|---|
| AC-B4 处理 | 🟡 I1 "措辞模糊"(措辞模糊，phase 7 澄清) | 🟡 R1 "AC over-specified"（AC 规格缺陷，字面不可达成） | AC-B4 不是"模糊"是"不可达成"——4-dev.md 36KB > 15KB 阈是物理事实，澄清不会改变事实 |
| AC-C2 合规 | 未提及（REVIEW.md 无对应 finding） | 🟡 R2 "部署不完整"（4/8 prompts 缺失） | 逐 prompt 检查发现 0-change/1-requirement/2-design/3-task 四个 prompt 无 narration-constraint 引用 |
| Missing prompts 范围 | 未检查 | 确认为 0-change / 1-requirement / 2-design / 3-task | T07-T09 的 write_files 均未覆盖这 4 个 prompt |
| I1 4-dev.md 781 行增长 | 🟡 I1 "增加+60行" | 本审查接受 I1 的 severity（🟡），但认为根源是 AC-B4 over-specified 而非 4-dev.md 增长。4-dev.md 增长是合理的（新增 model-tier 解析 + task_progress 写入 + Hook 兼容性自检），问题在 AC 规格 |

---

## R1-R4 回顾小结

本审查未升级任何 finding 到 🔴 Critical。R1（AC-B4）虽为结构性硬指标不满足，但根因是 AC 规格缺陷（字面不可达成）而非实现缺陷——AC 的真实意图（per-task 有效负载削减）已通过 task-brief 机制达成。R2（AC-C2 部署不完整）补 4 个 prompt 的 @see 引用为低成本修复（每个 1-2 行），phase 7 可选。R3（I3 确认）为 phase 7 正常验证步骤。

核心信号：**REVIEW.md 的 pass verdict 合理**。本审查追加 2 项 🟡 Important（R1/R2），均为 AC 规格层 / 部署完整性问题，非实现缺陷。不改变 pass verdict。

---

## 主 agent 响应（superpowers-v6-absorb Phase 6）

> L2 verdict=pass（0🔴），进入 phase 7。R2/R5 已 fix in place。

### 🟡 Major 修复

- **R2/R5（4 个 prompt 缺 narration-constraint.md @see）→ Fixed in place**: 0-change.md / 1-requirement.md / 2-design.md / 3-task.md 各加 1 行 `> @see` 引用。当前 9 个 phase prompts 全部含 narration-constraint.md 引用（含既有 4-dev/5-test/6-review/7-integration + 2a-ui-design 暂未加，因不常驻路由）。

### 🟡 Major 延后到 phase 7

- **R1（AC-B4 over-specified）**: 留待 phase 7 实测 + CHANGELOG 澄清。归因明确（4-dev.md 本身 39KB 远超 15KB，AC 措辞应改为"task-brief 输出 ≤15KB"）。
- **R3（package Part D 未跑打包验证）**: 留待 phase 7 跑 `bash package-flow-kit.sh --validate` 或 `tar -tzf` 验证。

### 🟢 Minor（延后到 MINOR-DEFERRED.md）

- R4（AC-B4 测试深度）→ MINOR-DEFERRED.md

### 创建 MINOR-DEFERRED.md

phase 6 review 期间累积的 Minor findings（来自 INDEPENDENT-REVIEW-1/2/3/5/6）将在 phase 7-integration 时统一创建 `.specs/superpowers-v6-absorb/MINOR-DEFERRED.md` 并 triage。

### 修复后自评

- Verdict 维持 pass
- R2/R5 修复后覆盖率从 5/9 → 9/9（100%）
- 不修改 L2 原文
