# 独立审查 · 阶段 1

## L2 盲审

> 固化盲审子 agent（qa-expert）原样产出，主 agent 未改一字。

## L2 盲审 · 阶段 1（需求审查）

**change-id**: refactor-independent-review-gate
**审查对象**: `.specs/refactor-independent-review-gate/REQUIREMENT.md`（参考 `CHANGE.md`）
**独立性声明**: 未检测到主 agent 上下文注入；以下结论均经独立核验工件内的事实声明（line 号、regex 计数、shellcheck 实测、CONTEXT.md 引用）得出，不依赖任何作者解释。

---

### 🔴 R1 · AC-4 验证方式不可证伪（vacuously satisfiable）

**Symptom（症状）**: `REQUIREMENT.md:41` AC-4 验证方式为 `shellcheck independent-review-gate.sh`（exit 0）。但实测当前未修复状态下，该文件已有 6 条 warning（1× SC2034 + 5× SC1090），shellcheck **exit 0**。即"修复前 exit 0、修复后 exit 0、 hypothetically 只删 disable 不改 line 69 也 exit 0"——验证方式对三种状态完全无区分能力。

**Source（源头）**: shellcheck 语义——warning 级 SC 码默认不抬高 exit code（仅 style/error 影响 exit）。L2 checklist 要求 AC"可机器验证"，而可机器验证的前提是"通过/失败状态对实现质量敏感"。

**Consequence（后果）**: 团队可以"删掉 line 68 disable 标注、不真正改 line 69 regex"就让 AC-4 的 exit 0 通过——此时 shellcheck 会冒出 SC1026/2203/2157 三条新 warning，但 exit 仍为 0，AC-4 照样绿。gate 形同虚设，TD-011 假修复可直接放行。本次禁动清单核心链改动，不可接受这种盲点。

**Remedy（修补）**: 验证方式改为显式 grep 目标 SC 码：
```bash
# before
shellcheck independent-review-gate.sh  # exit 0（vacuous）

# after
! shellcheck independent-review-gate.sh 2>&1 | grep -E 'SC1026|SC2203|SC2157'
# 或
shellcheck --severity=warning independent-review-gate.sh 2>&1 | grep -cE 'SC[0-9]+' | grep -q '^0$'
```
后者还能顺带把"无新 warning 引入"做硬约束。

---

### 🔴 R2 · AC-4 "Then 0 warning" 内部矛盾（按字面不可实现）

**Symptom（症状）**: `REQUIREMENT.md:40` AC-4 Then = "0 warning（SC1026/2203/2157 消失，无新 warning 引入）"。实测独立于本 change 的 6 条 warning（SC2034 `PROJECT_ROOT appears unused` + 5× SC1090 `can't follow non-constant source`）已存在且本 change 范围内**不会**被消除（它们不在 v1 任务清单里）。

**Source（源头）**: AC Then 与 v1 范围（`REQUIREMENT.md:61-68`）矛盾——v1 不处理 SC2034/SC1090，但 Then 字面要求 "0 warning"。两义性：①读作"字面 0 warning"→AC 不可实现；②读作"仅 SC1026/2203/2157 消失"→ Then 措辞误导，且与 R1 叠加使验证失效。

**Consequence（后果）**: 6-review / L3 阶段对"0 warning"产生解释分歧：按字面判 AC-4 fail（必须先修无关 warning），按意图判 pass——任一解释都会引发 spec 合规争议。在禁动清单核心链改动上，这种含糊是高风险。

**Remedy（修补）**: Then 改写为可验证且范围自洽：
```
Then: shellcheck 输出中 SC1026/SC2203/SC2157 出现次数 = 0；
      且与修复前相比不引入新 SC 码（diff warning 集合为空）
```
明确基线（"修复前 warning 集合 = {SC2034, SC1090×5}"）让"无新 warning"可机器对照。

---

### 🟡 R3 · Regex 计数 off-by-one（19 处声明 vs 18 处实存）

**Symptom（症状）**: `REQUIREMENT.md` 多处声明"全部 19 处 `[[ =~ ]]`"（AC-3 Given line 31、US-2 line 11、范围 v1 line 64）、"18 处无 bug 的 regex"（AC-3 Then line 33）；`CHANGE.md:23` 同。实测 `grep -nE '\[\[ .* =~ ' independent-review-gate.sh` = **18 行**，line 69 是 bug 行，所以"无 bug"实际 = **17 处**。

**Source（源头）**: 工件事实声明需与代码现实一致；off-by-one 在"全文件治理 + 行为等价对照"语境下直接污染 AC-3 的成功判据。

**Consequence（后果）**: AC-3 Then 写"18 处无 bug 的 regex 治理前后 100% 一致"——若 4/5 阶段按"18 处"写对照脚本，会漏算或重算 1 处（最可能把 line 69 bug 行算进"无 bug"组，或把某行重复计入）。证据链失真，6-review 难判"是否全覆盖"。

**Remedy（修补）**: 全文 19→18、18→17。AC-3 Given/Then 显式枚举 17 行行号清单作为对照范围：
```
Given: 治理范围 = {L30,31,32,33,34,35,36,37,70,71,73,74,75,92,95,143,292}（17 处，排除 L69）
When:  对每行跑治理前/后代表性输入对照
Then:  17 处匹配结果 100% 一致；L69 按 AC-1 改变
```

---

### 🟡 R4 · AC-2 不可机器验证（违反 L2 checklist）

**Symptom（症状）**: `REQUIREMENT.md:24-27` AC-2 Then = "注释明确标注「修复前该输入误报 MATCH.../ 修复后正确 no-match」"，验证方式 = "人工确认注释存在 + bats pass"。bats pass 只能证明代码行为正确，无法证明注释文本存在或措辞合规——后者是人工视觉检查。

**Source（源头）**: L2 固化指令 checklist 第 1 条："每条 AC 是否 Given/When/Then 三段齐全且**可机器验证**（拒绝「系统应该正常工作」这类空话）？" 注释存在性属于此类"应该有文档"的空话型 AC。

**Consequence（后续）**: AC-2 可被"代码改对、注释随便写一句话"满足，违背其"回归证据可追溯"本意。证据链薄弱，6-review 与 L3 难以一致判定。

**Remedy（修补）**: 把"证据"从注释搬到可 grep 的硬产物：
```
Then: test_l2_l3_granular_gate.bats 存在 @regress-TD011 标记的测试用例，
      且该用例包含对修复前预期（MATCH）与修复后预期（no-match）的双向断言
验证方式: grep -q '@regress-TD011' test/.../test_l2_l3_granular_gate.bats \
          && bats --filter TD011 ... （pass）
```

---

### 🟡 R5 · 命名 6-review 风险无对应 AC（关键风险遗漏）

**Symptom（症状）**: `CHANGE.md:59` 风险段明确列出"line 69 修复会改变 gate 对 atomic-write 的实际判定……需在 6-review 确认没有上游逻辑**依赖**这个误报行为（理论上是 bug 不应有依赖，但需查证 line 175/366 调用链下游）"。`REQUIREMENT.md:94` 假设段也复述此假设。但 AC-1~AC-6 **无一条**把这个查证固化为可验证 AC。

**Source（源头）**: 假设必须由 AC 兜底——"假设 X 不成立时要有 AC 报警"是 spec-driven 项目的基本要求。否则假设沦为"希望"。

**Consequence（后续）**: 若某处下游（line 175 或 366 的 `is_phase_write` 调用方）实际依赖"误报 MATCH"（例如某测试或某 gate 分支恰好靠误报通过），修复后产生隐性回归，且 AC-5 `make test` 不一定能覆盖到（测试覆盖率历史就有盲点，TD-012 即是 30+ 假绿）。

**Remedy（修补）**: 新增 AC-7（或合并入 AC-5）：
```
AC-7 · 调用链下游无依赖误报行为
Given: is_phase_write 在 line 175 / 366 的两个调用点
When:  grep -rn 'is_phase_write' flow-kit-bundle/（含测试）
Then:  无任何调用点的预期输出依赖"含 .tmp 但无 &&mv 的命令被判 MATCH"
验证方式: 静态调用图 + 调用点预期审计（人工或脚本）
```

---

### 🟡 R6 · CONTEXT.md 行号引用三处不一致（禁动清单合规风险）

**Symptom（症状）**: 三处对禁动清单行号引用互相矛盾且都与实际不符：
- `CHANGE.md:39` 声明禁动清单 line **321/325**
- `REQUIREMENT.md:54` AC-6 声明禁动清单 line **349/353**
- `CONTEXT.md:363` TD-011 行又自声明"禁动清单 line **349/353**"
- 实测：`independent-review-gate.sh` 在禁动清单实际位于 line **326**（核心链）+ line **330**（校验顺序）；line 349/353 实际是"只记 🟡"说明 + TD-002 行；line 321/325 是 HOOK_MODULE_NAMES + 33-flow-active-integrity。

**Source（源头）**: L1 hook 合规层若按 CHANGE.md 的"321/325"或 AC-6 的"349/353"去核对禁动清单授权，会指向错误行号——禁动清单授权失效或误报。

**Consequence（后续）**: 本次 change 的存在意义之一（CONTEXT.md line 39："L1 hook 合规层应识别此 spec 依据"）落空——授权引用指错行，L1 层无法可信放行。AC-6 的 `grep 'TD-011' .specs/CONTEXT.md` 验证也会因引用错误而"标 resolved 但证据链断裂"。

**Remedy（修补）**: 全文统一禁动清单行号为 326/330；并在 AC-6 增加一条验证：
```
Then: 禁动清单 line 326/330 的 independent-review-gate.sh 条目
      追加"已授权 refactor-independent-review-gate 修改"注脚
验证方式: sed -n '326p;330p' .specs/CONTEXT.md | grep refactor-independent-review-gate
```

---

### 🟡 R7 · CONTEXT.md 决策日志已用过去时记述未实现的 refactor

**Symptom（症状）**: `CONTEXT.md:222-224` 已存在 `[2026-07-08]` 决策日志：**"independent-review-gate.sh 所有 `[[ =~ ]]` 改用 `local re='...'; [[ "$x" =~ $re ]]`，杜绝 regex 内 `&&`..."**——过去时/既成事实叙述。但实测代码 line 69 仍是内联 regex（bug 未修）、TD-011 仍 🔴。同样的既成叙述出现在 line 170（术语表）+ line 233（默认偏好）。

**Source（源头）**: spec 工作流要求文档与代码状态一致；阶段 1（需求）尚未实现代码，决策日志不应使用"已改用"过去时。需确认这是 0-change 阶段的"政策宣示"还是过早纪实。（独立审查员不猜测作者意图——标"需确认"。）

**Consequence（后续）**: 若 4-dev 实现偏离已写入的"所有 `[[ =~ ]]` 改用"叙述（例如 R3 发现只有 18 处而非"所有"按 19 理解），证据链与决策日志矛盾，6-review / L3 难判"是 doc 错还是 code 错"。在禁动清单核心链上这种 doc/code 漂移成本极高。

**Remedy（修补）**: 决策日志改用将来时或加状态标注，例如：
```
- [2026-07-08] gate regex 统一"变量存 regex"风格（计划中 · refactor-independent-review-gate）
  independent-review-gate.sh 所有 [[ =~ ]] 将改用 ... 待 7-integration 完成后标 ✅
```
或保持现状但在 REQUIREMENT.md 的 AC-6 显式纳入"将 CONTEXT.md L222-224 / L170 / L233 的状态从'计划'转'已实施'"作为可验证产出。

---

### 🟢 R8 · AC-1 把实现细节焊进 Given（风格 / 测试路径歧义）

**Symptom（症状）**: `REQUIREMENT.md:17` AC-1 Given 直接内嵌修复实现 `local re='\.tmp[[:space:]]*&&[[:space:]]*mv'; [[ "$c" =~ $re ]]`。另：AC-1 验证方式只写 `bats test_l2_l3_granular_gate.bats`，但项目里该文件存在于两个路径——`test/test_l2_l3_granular_gate.bats` 和 `flow-kit-bundle/test/test_l2_l3_granular_gate.bats`——未指明改哪个（或同步改）。

**Source（源头）**: AC 应描述行为而非实现（实现归 DESIGN.md）。路径歧义在多副本测试布局下会导致改了一个忘了另一个。

**Consequence（后续）**: 轻微——本 change DESIGN 已定实现，焊死影响小；但测试路径歧义可能让 make test 在某一份副本上未跑新增 case（与 TD-012 假绿教训同型风险）。

**Remedy（修补）**: AC-1 Given 改为"已用变量存 regex 风格修复（实现见 DESIGN.md）"；验证方式补全路径或注明"两副本同步"。

---

### 🟢 R9 · AC-3 等价性方法论未规约（"100% 一致"如何证明）

**Symptom（症状）**: `REQUIREMENT.md:32-34` AC-3 要求"治理前后匹配结果 100% 一致"，验证方式 = "sandbox 对照脚本输出"——但脚本输入集、每行 regex 的代表性 case 数量、对照方法（diff? 表格?）均未规约。

**Source（源头）**: "等价"证明需定义等价类（输入空间采样策略）；空泛的"跑一组代表性输入"不可重复。

**Consequence（后续）**: 4/5 阶段可写一个 3 条输入的玩具脚本声称"100% 一致"通过；6-review 难判采样是否充分。R3（计数错）与之叠加放大风险。

**Remedy（修补）**: 规约每行至少 3 类输入（正匹配 / 负匹配 / 边界），输出格式定死（如 TSV：行号 × 输入 × 治理前结果 × 治理后结果 × diff flag）。

---

**Verdict**: fail

存在 2 条 🔴 Critical（R1 AC-4 验证不可证伪、R2 AC-4 Then 内部矛盾），按本固化指令"fail 当且仅当存在 🔴 Critical"——判 fail。R1/R2 必须在切阶段前修订 AC-4 的 Then 措辞与验证命令（建议合并为单一可 grep 的硬验证）。R3~R7 为关键风险遗漏与事实错误，强烈建议同批修订。R8/R9 可选改进。

补充（不参与 Verdict，仅记录）：本次审查独立核验过程中发现工件对代码事实的声明误差率偏高（regex 计数、行号引用、决策日志时态共 4 类事实问题），提示 0-change 阶段的事实采集环节存在系统性偏差，建议主 agent 在切阶段前不只是回应本报告的逐条 Remedy，而是回溯核验 CHANGE.md / REQUIREMENT.md 中所有"line N""N 处"类数值声明。

---

## 主 agent 回应（L2 后修订 · receiving-code-review 技术核验）

> 本轮回应基于对 L2 每条事实声明的**独立 shell 实测核验**（非盲接受，非盲拒）。

### 事实核验 · 反驳 L2 两处事实错误

L2 R1/R2 称「shellcheck exit 0」「6 条 warning」「warning 不抬高 exit code」。**独立实测反驳**：

```
shellcheck independent-review-gate.sh → exit code = 1（非 0）
warning 实测 = 8 条（SC1090×6 + SC2034×2，非 L2 称的 6 条）
shellcheck warning 确实抬高 exit code 至 1（L2 Source「warning 不抬高 exit」错误）
```

此事实纠正**不改变** R1/R2 的结论方向（AC-4 验证方式确有硬伤），但纠正了 L2 的推理依据。按 receiving-code-review 原则记录在案。

### 逐条处置（Fixed in: / Tech-debt: / Not-applicable:）

| # | 严重度 | 处置 |
|---|---|---|
| R1 | 🔴 | **Fixed in: REQUIREMENT.md AC-4** — 验证改 `! shellcheck \| grep -E 'SC1026\|SC2203\|SC2157'` + 基线对照。附记 L2 事实错误（exit 1 非 0） |
| R2 | 🔴 | **Fixed in: REQUIREMENT.md AC-4** — Then 改"SC1026/2203/2157=0 + 新集合⊆基线{SC1090,SC2034}"。基线实测 8 条（非 6） |
| R3 | 🟡 | **Fixed in: REQUIREMENT.md + CHANGE.md** — 全文 19→18，无 bug 17 处，AC-3 给 17 行行号清单 |
| R4 | 🟡 | **Fixed in: REQUIREMENT.md AC-2** — 改 `@regress-TD011` grep 标记 + 双向断言（grep + bats --filter）|
| R5 | 🟡 | **Fixed in: REQUIREMENT.md AC-7（新增）** — 调用链下游审计（line 175/366）|
| R6 | 🟡 | **Fixed in: REQUIREMENT.md AC-6 + CHANGE.md + CONTEXT.md** — 全改内容锚定（行号随编辑漂移，L2 已证）。补充：L2 称实测 326/330 是 0-change 域语言追加 +5 行后的当前号；原 321/325 是最初 grep 旧号；349/353 是 TD-011 自声明的历史错误（health-cleanup-2026-07-08 引入）|
| R7 | 🟡 | **Fixed in: CONTEXT.md** — 决策加"(本次 change 实施中 · 待 7-integration 标 ✅)"将来态标注 |
| R8 | 🟢 | **Fixed in: REQUIREMENT.md AC-1** — Given 改行为描述（不焊实现）；验证补两副本同步（test/ + flow-kit-bundle/test/）|
| R9 | 🟢 | **Fixed in: REQUIREMENT.md AC-3** — 规约 ≥3 类输入（正/负/边界）+ TSV 输出格式 |

**结论**：2 🔴 + 5 🟡 + 2 🟢 共 9 条，**全部 Fixed in**（spec 已修订），无 Tech-debt / Not-applicable。2 条含对 L2 事实错误的反驳（已记录）。

### L2 系统性建议 · 已采纳

L2 末尾建议"回溯核验所有 line N / N 处类数值声明"。**已采纳**：本轮重核 regex 计数（18 ✓）、warning 计数（8 ✓）、禁动清单行号（改内容锚定），均修正。后续阶段（4-dev/5-test）的事实声明将逐条 shell 实测核验。

---

## L2 盲审（第二轮 · 复审 v2）

> 独立盲审子 agent（qa-expert）复审 v2，原样产出。未读 INDEPENDENT-REVIEW-1.md 既有内容（任务参数未列入工件范围），独立性保持。

**Verdict**: pass（无 🔴 Critical）

实证核验：核心事实声明 **13/13 准确**（18 处 regex ✓、17 行号清单逐行匹配 ✓、shellcheck 基线 8 条 ✓、bug `set -x` 实锤 ✓、make test 407 全绿 ✓、调用点 175/366 ✓、两副本 diff identical ✓、报错文案 223/246/256 ✓）。技术根因分析（`&&` 被 `[[ ]]` 当逻辑与劈半、SC2157 恒真、修复手法正确）经 sandbox 复现全部属实。

发现（pass 之上的改进建议）：
- 🟡 F1: AC-6 ③ "修正 349/353" 的对象已不存在（上一轮已清 CONTEXT.md）
- 🟡 F2: AC-6 验证 `grep 'TD-011'` 在**未修复状态**就 pass（4 处匹配），验证方法形同虚设 → 收紧为 ✅ resolved
- 🟡 F3: AC-3 硬编码行号 vs AC-6 自己承认"行号漂移"自相矛盾 → 改动态 grep + 内容指纹
- 🟡 F4: AC-2 "双向断言" 语义混淆（post-fix 用例无法同次断言修复前 MATCH）→ 改负匹配断言 + 注释文档化
- 🟡 F5: AC-7 Then 本质人工判断非机器验证 → 拆可验证（判定表）+ checklist
- 🟢 F6: is_phase_write 现有测试在 `test_gate_integrity.bats` L209-226（D10 调用栈），非 granular_gate
- 🟢 F7: bash 3.2 兼容性无 AC 持续验证
- 🟢 F8: AC-1 Given 前向引用不存在的 DESIGN.md（2-design 才产出）

L2 结论："准予进入 2-design 阶段，F1-F5 修订建议在派生 TEST 用例前落实"。

## 主 agent 回应（第二轮 · v3 修订）

全部接受 F1-F8，应用到 REQUIREMENT v3：

| # | 严重度 | 处置 |
|---|---|---|
| F1 | 🟡 | **Fixed in: AC-6 ③** — 改负向断言 `! grep -E '禁动清单 line [0-9]'`（防回退）|
| F2 | 🟡 | **Fixed in: AC-6 验证** — 收紧 `grep -E 'TD-011.*✅.*resolved'`（避免未修复空 pass）|
| F3 | 🟡 | **Fixed in: AC-3** — 范围改动态 `grep '\[\[ .* =~ '` + 内容指纹，行号仅 @快照参考 |
| F4 | 🟡 | **Fixed in: AC-2** — Then 改负匹配断言 no-match + 注释记录修复前 bug 行为 |
| F5 | 🟡 | **Fixed in: AC-7** — 拆可验证（判定表入 DEV-SUMMARY）+ checklist 降级 |
| F6 | 🟢 | **记 3-task** — is_phase_write 测试落点优先 `test_gate_integrity.bats`（D10 调用栈），granular_gate 备选 |
| F7 | 🟢 | **Fixed in: 非功能性兼容性** — 收窄为"Linux bash 5 已验证；3.2 理论兼容"，持续保障列 v2 |
| F8 | 🟢 | **Fixed in: AC-1 Given** — 时态改"已按 DESIGN.md 修复且合入" |

**结论**：L2 pass + 8 条全 Fixed in。AC 验证链闭合（F1-F4 解决验证空洞化，F5 降级合理，F6-F8 记录/收窄）。REQUIREMENT v3 进 2-design。

---

## L3 盲审（glm-4.7 外部模型 · 2026-07-08 21:56）

> 自动生成于 2026-07-08 21:56。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [
    {
      "file": "AC-3",
      "issue": "AC-3 验证指令依赖硬编码行号快照，与 AC 文本中'动态发现'逻辑相悖",
      "why": "AC-3 Given/Then 强调使用 'grep -nE' 动态发现并建立指纹，且 L2 F3 明确禁止硬编码行号。但验证方式中列出了具体行号快照（如 L30,31...），若工件以此快照为验收基准，则违背了 Given 中 '行号随编辑漂移' 的自适应逻辑，导致脚本变更后行号变动即触发验证失败（误报），或验证通过但逻辑未覆盖（漏报）。",
      "fix": "将验证方式中的行号快照列表修改为 '使用 grep 输出集合作为基准'，或明确指出该快照列表仅供 Code Review 参考，实际验证必须基于动态 grep 结果的 diff 比对。"
    },
    {
      "file": "AC-6",
      "issue": "CONTEXT.md 文件状态回退检查存在逻辑漏洞",
      "why": "AC-6 Given 提及 'L2 F1：上轮已清 349/353'，表明文件之前存在硬编码行号。当前的验证方式 `! grep -E '禁动清单 line [0-9]'` 仅检查 'line X' 格式。若因修复导致格式略有偏差（如 'line:X' 或 '行X'），正则可能无法匹配，从而无法检测到回退。且作为回归性审查，应使用显式的负向断言检查被清除的特定行号（如 349, 353），而非通用的格式检查。",
      "fix": "在验证方式中补充针对已知删除内容的显式检查，确保不再出现（如 `! grep '349' CONTEXT.md`），并强化正则以覆盖不同变体。"
    }
  ],
  "minor": [
    {
      "file": "AC-1",
      "issue": "测试用例落点描述存在歧义",
      "why": "验证方式提及'落点优先 `test_gate_integrity.bats`'，同时提及'granular_gate 备选'。'优先'一词表明执行顺序或偏好，但在自动化测试验收中应具有唯一确定性。若两个文件均可落点且逻辑互通，需明确是否为'必须落点 A 或 B'，或者'落点 A，B 同步'。当前描述可能导致提交者仅落点 granular_gate 而未同步 test_gate_integrity.bats，违背'两副本同步'要求。",
      "fix": "将'落点优先'修改为'必须落点 `test_gate_integrity.bats`，并同步更新 `granular_gate`'，或明确允许的唯一落点。"
    },
    {
      "file": "AC-4",
      "issue": "Shellcheck 验证方式中缺少 CI 基线定义",
      "why": "AC-4 定义了基线 `{SC1090, SC2034}`，但验证方式仅验证'无输出'或'排序唯一'。若提交者在不匹配的环境运行或 shellcheck 版本不同，可能产生不在集合内的 warning，从而导致测试通过但质量不达标。AC 验证应包含环境一致性检查或 CI 跑步指令。",
      "fix": "在验证方式中明确指定 shellcheck 版本或使用 CI 环境执行命令（如 `make lint` 或 `ci_env_shellcheck`）。"
    }
  ],
  "verdict": "pass",
  "summary": "AC 结构完整，逻辑闭环。v1/v2/out 切分清晰，无范围蔓延。存在 Major 级别的验证指令与 AC 文本描述不完全一致（AC-3 快照依赖 vs 动态发现，AC-6 格式检查 vs 显式回溯）的问题，需修正验证指令以确保严格符合'动态/无歧义'要求，但不至于阻碍盲审通过。"
}
```
```
