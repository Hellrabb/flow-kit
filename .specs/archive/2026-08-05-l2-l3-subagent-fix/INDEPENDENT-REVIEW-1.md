# 独立审查 · 阶段 1

## L2 盲审

**审查阶段**: 1-requirement · **Change**: l2-l3-subagent-fix · **工件**: REQUIREMENT.md（参考 CHANGE.md）

**结论先行**: 5 条 AC 均 Given/When/Then 三段齐全、指向具体可查交付物（ROOT-CAUSE.md / DEV-SUMMARY.md），无 🔴 Critical。核心问题集中在**机器验证方式与 Then 断言不对齐**（AC-1/3/5）与**证据要求 vs 安全约束的矛盾未显式处理**（AC-2 vs 安全 NFR）。Verdict: **pass**（无 Critical），4 🟡 建议在 fix loop 内修 REQUIREMENT，3 🟢 入 MINOR-DEFERRED。

---

### 🔴/🟡 R1 · AC-1 验证不覆盖核心断言「四环节每环节实测结论」：五段齐全即可通过，四环节覆盖零检查
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:21-22 — Then 要求「对全链四环节……每一环节均给出实测结论」，但 验证方式（:22）只 grep 5 个 `^##` 段头（≥ 5）。四环节（`l2-detect.sh` / `independent-review-gate.sh` / prompt 派发段 / env 透传 + `l3-review.sh`）在验证命令中无任何锚点。
**Source（源头）**：ADR-019 写作原则 ①「AC 必须确定性（条件 AC 拆 hard+soft）」；阶段 1 checklist「拒绝空话、必须可机器验证」。
**Consequence（后果）**：报告可五段标题齐全但四环节全部没写实测结论（或只写一段复用），gate 照常放行——调查型 change 的核心交付物空转，AC-1 的实质要求形同虚设。
**Remedy（修补）**：验证命令追加四环节锚点 grep，如 `grep -cE 'l2-detect|independent-review-gate|prompt 派发段|env var 透传|l3-review' ROOT-CAUSE.md` 输出 ≥ 4；或要求报告每环节固定一行 `## 环节N结论: 实测/未复现` 标注，验证该行存在。

### 🔴/🟡 R2 · AC-2 证据要求与安全 NFR 矛盾：实测命令输出可含 env var 值，无脱敏规则
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:28 — Then 要求每条根因附「实测的命令输出」；而调查对象恰是 `ANTHROPIC_*` / `FLOW_KIT_*` 透传链（:21 环节④）。:80 安全 NFR 要求「不得泄露本机路径 / 凭证 / 内部端点」。两个要求直接冲突，REQUIREMENT 未定义证据中的 env var 值如何处理。
**Source（源头）**：CONTEXT.md security-privacy-audit 六大风险维度（🔑 硬编码凭证）；本仓库公开仓库安全标准（零容忍）。
**Consequence（后果）**：照字面执行会把 `ANTHROPIC_AUTH_TOKEN` 等值写进 ROOT-CAUSE.md → 入库进 git 历史 → push 前才发现返工，或泄露不可逆。
**Remedy（修补）**：AC-2 Then 追加一句「证据中 env var 只显示变量名 + set/unset 状态，值一律脱敏为 `***`」；或安全 NFR 明确「实测输出经脱敏后入报告」。

### 🔴/🟡 R3 · AC-4「同参数 mock 复现均可」逃生门定义含糊：可能绕过真实派发路径，对核心目标零证明力
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:42 — Then 允许「阶段产物实测**或同参数 mock 复现均可**」，未定义 mock 的边界。本次 change 的目标恰是 opencode「拉不起来」（CHANGE.md:12-17），若 mock 不经过真实运行时派发（真实 dispatch 命令 + 真实 PreToolUse gate + 真实 env 透传），验收证明不了修复有效。
**Source（源头）**：ADR-019 原则 ①；本仓库既有教训 l2-l3-test-defect BUG-G「假绿」（测试失败却声明通过）。
**Consequence（后果）**：mock 全绿 → change 宣告成功 → 真实 opencode 环境仍拉不起 → 独立审查机制在 opencode 继续断裂，问题复发后才暴露。
**Remedy（修补）**：限定 mock 语义——「派发机制必须走真实运行时（真实 task tool / hook 路径），仅 L2 审查内容本身可 mock；若真实派发不可行，在 DEV-SUMMARY.md 记录不可行原因」。

### 🔴/🟡 R4 · AC-5 基线 662/662 无来源 +「pre-existing 不算」逃生门：0 新增 fail 无任何机器比对
**Severity**：🟡 Important
**Symptom（症状）**：REQUIREMENT.md:48-50 — Then 要求「0 新增 fail（与归档基线 662/662 一致）」，但：① 基线数字无出处（实测当前 `test/*.bats` 共 710 条 @test；CONTEXT.md TD-002 记录的最近归档基数是 688/688，两处均 ≠ 662）；② 验证方式仅「输出记录在 DEV-SUMMARY.md」，无基线 diff 命令；③ 「pre-existing 项不算本次引入」无判定标准，可吞掉任何回归。
**Source（源头）**：ADR-019 原则 ①（确定性）；l2-l3-test-defect BUG-G 假绿教训；CONTEXT.md 技术债表 TD-012「bats|tail 管道吃 exit code 误判全绿」。
**Consequence（后果）**：任一 fail 都可被声明 pre-existing 且无对账，AC-5 降级为自我声明，回归静默漏网。
**Remedy（修补）**：① 写明 662/662 的来源（哪个归档 change / 日期），或改用当前实测基线；② 验证方式改为机器比对：`npx bats test/ 2>&1 | grep -c '^not ok'` 与基线 fail 数比对，新增 fail = 超出部分，逐条列出。

### 🔴/🟡 R5 · AC-3「每条修复方案标 risk」被 `grep ≥ 1` 验证：一条达标即可放行其余未标条目
**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:35-36 — Then 要求「每条修复方案标注 risk 级别……并标注是否触碰禁动清单条目」，验证仅 `grep -cE 'risk: (low|high)' ≥ 1`。
**Source（源头）**：ADR-019 原则 ①。
**Consequence（后果）**：报告里 1 条标了 risk、其余方案全未标，AC-3 仍通过；high 风险方案可能被 v1 误实施。
**Remedy（修补）**：验证改为「方案条目数与 risk 标注数相等」（如 `grep -cE '^### .*方案'` = `grep -cE 'risk: (low|high)'`），或要求每方案条目行内固定 `risk: low|high` 字段。

### 🔴/🟡 R6 · v1 范围「CONTEXT.md 术语沉淀」无 AC 覆盖：范围项不可验证
**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:61 — v1 范围含「CONTEXT.md 术语沉淀（双平台派发兼容相关新术语）」，但 5 条 AC 均无对应验证（注：CONTEXT.md 术语表已见 `l2-l3-subagent-fix` 追加块，疑似已由 intel-scan 沉淀——需确认是否仍算本次工作项）。
**Source（源头）**：阶段 1 checklist「范围切分合理性」。
**Consequence（后果）**：术语沉淀项做没做、由谁做无验收口径。
**Remedy（修补）**：加 AC-6（`grep -c '双平台派发兼容' .specs/CONTEXT.md ≥ 1`）或从 v1 范围删除该行并注明已沉淀。

### 🔴/🟡 R7 · AC-4/AC-5 为条件 AC 但无「条件不成立」分支声明：用户否掉全部 low 修复时空洞通过
**Severity**：🟢 Minor
**Symptom（症状）**：REQUIREMENT.md:40,47 — AC-4/AC-5 的 Given 是「用户已确认 low 风险修复清单」；若用户确认的清单为空（或全部 high），两个 AC 无验证对象，但 REQUIREMENT 未声明该分支下「根因报告即为唯一交付物」。
**Source（源头）**：ADR-019 原则 ①（条件 AC 拆 hard+soft，需显式声明分支）。
**Consequence（后果）**：边界场景下 AC-4/5 以「无内容」通过，change 验收口径模糊。
**Remedy（修补）**：REQUIREMENT 加一句「若用户未确认任何 low 风险修复，AC-4/AC-5 不适用，交付物仅为 ROOT-CAUSE.md」。

---

**Verdict**: pass
