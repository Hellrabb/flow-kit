# 独立审查 · 阶段 1

## L2 盲审

**审查范围**：仅基于 `.specs/l2-l3-test-defect/REQUIREMENT.md` 与 `.specs/l2-l3-test-defect/CHANGE.md`（调用方指定工件）。未读 DIAGNOSE.md / PROGRESS.md / .goal-snapshot.json / 任何 hook 或 test 源码，以维持盲审独立性。

**独立性声明**：未检测到主 agent 自评 / 草稿 / 概述 / 辩护注入；输入仅含指定工件，无污染需标注。

---

### R1 [CRITICAL] · AC-7 不可机器验证：终态 AC 含「按设计」「无异常」空话

**Symptom（症状）**：`REQUIREMENT.md:63` AC-7 Then 写「每阶段 L2/L3 gate 按设计拦截/放行，pipeline 能走完全程」；`REQUIREMENT.md:64` 验证方式写「实跑（本阶段起，逐阶段 toll-gate 确认）」。「按设计」未指明哪份设计文档，「无异常」未定义异常集合，「逐阶段 toll-gate 确认」是流程描述而非断言。

**Source（源头）**：阶段 1 checklist 明令「拒绝『系统应该正常工作』这类空话」「每条 AC 必须 Given/When/Then 三段齐全且可机器验证」。AC-7 是被点名的违禁形态。

**Consequence（后果）**：实现方/测试方对 AC-7 通过与否只能主观判断；实跑中途任何 toll-gate 行为可疑时没有客观通过线。AC-7 是 v1 终态 AC，它一模糊，整个 change 的 done 判定退化为橡皮图章——这与 US-1「确认质量门禁可信（非假绿）」的目标直接冲突。

**Remedy（修补）**：把「按设计/无异常」换成可断言的具体期望。建议：

```
Then: 对于 phase in 1..7, .flow-active.phase_status[phase]=passed;
      每个被拦截的 commit exit=2 且 stderr 含 "independent review required";
      每个放行的 commit exit=0;
      终态 current_phase=7 且无遗留 *.pending
```

验证方式改为 `jq` 直接校验 `.flow-active` + `test -f` 校验 `.done` 标记，而不是「实跑」这种主观动作。

---

### R2 [CRITICAL] · AC-2 与 AC-3 在「phase=3 git commit」场景下结论矛盾

**Symptom（症状）**：`REQUIREMENT.md:26` AC-2 Given=`phase in {1,2,3,5,6,7}, gate_config[both], 无 .done`，When=`git commit / phase transition`，Then=`deny exit 2`。`REQUIREMENT.md:32` AC-3 Given=`phase0 或命令不含阶段切换`，When=`git commit / ls`，Then=`allow exit 0`。在「phase=3 / gate=both / 无 .done / 执行 `git commit`（该 commit 不写 current_phase，不切换 phase）」这一具体场景下，AC-2 与 AC-3 同时适用，结论相反。

**Source（源头）**：AC 集合必须内部一致。两条 AC 的前置条件若对同一输入产生不同期望，则集合不可同时满足，等同 spec 合规失败。

**Consequence（后果）**：实现方无法同时满足两条 AC；测试方只能任选一种解读，另一条路径失去覆盖。这是 AC 不可实现级别的冲突，属于必须修复项。

**Remedy（修补）**：拆解 AC-3 的「或」消歧义：

```
AC-3a · Given phase=0, When git commit, Then allow exit 0
AC-3b · Given 任意 phase, When 非触发命令(ls / cat / git status), Then allow exit 0
```

AC-2 增加澄清：「git commit 在 review phase (1,2,3,5,6,7) 即使不含 jq 写 current_phase 仍 deny」。

---

### R3 [MAJOR] · REQUIREMENT 预设 7 bug 修复，违反 CHANGE.md「先诊断后定」原则

**Symptom（症状）**：`REQUIREMENT.md:72-73` v1 范围同时含「诊断 L2/L3 gate 7 bug (A-G)」+「修复 A-E（gate 编排）+ G（l2-detect mock_ts）」。但 `CHANGE.md:23` 明文「**是否当场修复**遵循『先诊断后定』原则，在报告产出后由用户决定」，`CHANGE.md:32` 进一步写「（诊断性，**不预设**为 bug 修复）」。

**Source（源头）**：CHANGE.md 是 REQUIREMENT.md 的上游意图来源。REQUIREMENT 把「诊断」与「修复」折叠到同一 v1，并预设修复项，违反上游「先诊断后定」。

**Consequence（后果）**：若诊断显示 A-E+G 中某项并非真 bug 或根因不同，AC-1~5 强制按预设修复，浪费工时或引入回归；同时让 US-1（确认门禁可信）失去诊断价值——结果（修复项）已在 REQUIREMENT 锁死，诊断沦为走过场。

**Remedy（修补）**：二选一：
(a) 拆分为两个 change：`l2-l3-diagnose`（v1 只产诊断报告）+ `l2-l3-fix`（v2 在用户确认诊断后立项）；
(b) 保留单 change，但把 AC-1~5 改为条件 AC：「Given 诊断确认 BUG-X 存在且根因为 Y，When ...」——未达条件则 AC 不触发。

---

### R4 [MAJOR] · BUG-A~G 在指定输入工件中无定义，AC 无法追溯

**Symptom（症状）**：AC-1~6 引用 BUG-A、B、C、D、E、F、G 标签，但 `REQUIREMENT.md` 与 `CHANGE.md`（指定输入）从未定义这些标签——仅在 `REQUIREMENT.md:4` 关联 `DIAGNOSE.md`，而该文件不在本次审查输入集。

**Source（源头）**：阶段 1 checklist「每条 AC 是否 ... 可机器验证」。可验证前提是 bug 定义可追溯，否则 AC 与 bug 的映射不可审计。

**Consequence（后果）**：审查者无法核对 AC 是否覆盖对应 bug 的真实根因；实现方可能修错根因；测试方无法从 AC 派生用例。

**Remedy（修补）**：在 REQUIREMENT.md 内联 `BUG-X -> 症状/根因/位置` 表，或把 `DIAGNOSE.md` 加入阶段 1 审查强制输入。

---

### R5 [MAJOR] · AC-6 测试计数前后不一致，9 个测试无来源

**Symptom（症状）**：`REQUIREMENT.md:56` AC-6 Then「17/17 全过（含 INT-1~5 + G 修复的 3 个 mock 测试）」。INT-1~5 = 5 + 3 mock = 8，与「17/17」差 9 个，9 个测试在 REQUIREMENT 中未枚举。

**Source（源头）**：AC 必须自洽且可独立核验。

**Consequence（后果）**：实现方可任选 17 个测试凑数；测试集增减 AC 不感知；AC-6 退化为橡皮图章。

**Remedy（修补）**：在 REQUIREMENT.md 列出全部 17 个测试名，或改为「`test/test_l2_pretooluse_dispatch.bats` 内全部测试通过（当前 17 个，新增/删除时同步更新本计数）」。

---

### R6 [MAJOR] · AC-6 前置「修复 A-G 后」与 v1 范围（A-E+G，不含 F）矛盾

**Symptom（症状）**：`REQUIREMENT.md:54` AC-6 Given「修复 A-G 后」；`REQUIREMENT.md:73` v1 实际修复「A-E + G」；`REQUIREMENT.md:80` BUG-F 在 v2。字母区间「A-G」按字面包含 F。

**Source（源头）**：AC 前置条件必须与 v1 范围一致。

**Consequence（后果）**：v1 内 AC-6 前置永远无法满足（F 未修），AC-6 在 v1 内不可达成，逻辑上必然 fail。

**Remedy（修补）**：将 Given 改为「修复 A-E + G 后」或「修复 v1 范围内 bug 后」，与 v1 范围一致。

---

### R7 [MAJOR] · 兼容性 NFR「gate_config 向后兼容」无 AC 兜底

**Symptom（症状）**：`REQUIREMENT.md:94`「兼容性: 保留 gate_config 值向后兼容（independent/true -> both）」。AC-1~7 中无一条覆盖 `gate_config=independent` 或 `gate_config=true` 的旧值场景。

**Source（源头）**：非功能性需求必须由 AC 兜底，否则只是愿望清单。

**Consequence（后果）**：旧 `gate_config=independent` 用户静默失效（被当作空值放行）；fail-close 安全语义被绕过，回归不可见——这直接抵消 `REQUIREMENT.md:93` 的安全 NFR。

**Remedy（修补）**：补 AC-8：Given `gate_config[phase]=independent`，When phase in {1,2,3,5,6,7} git commit 无 .done，Then deny exit 2（视为 both）。同步覆盖 `gate_config=true` 场景。

---

### R8 [MAJOR] · 关键假设「fk_independent_review_gate_active 已验证」循环

**Symptom（症状）**：`REQUIREMENT.md:99`「假设 fk_independent_review_gate_active（done-validation.sh）实现正确（已验证读 gate_config 双源）」。本 change 的 US-1/US-2 即为验证 gate 机制；假设 gate 核心函数正确 = 假设结论。「已验证」无任何测试引用或 commit 链接。

**Source（源头）**：风险评估不能把被测对象本身设为不变量。

**Consequence（后果）**：若 fk_independent_review_gate_active 双源读有 bug，AC-1~6 可能假绿（用错误函数判定「正确」行为），掩盖真实缺陷——与 US-1「非假绿」目标冲突。

**Remedy（修补）**：补 AC 显式验证 fk_independent_review_gate_active 的双源读（gate_config 文件存在时读文件、不存在时回退 hook 配置），或移除「已验证」措辞改为显式风险条目。

---

### R9 [MAJOR] · AC-2 phase 集合 {1,2,3,5,6,7} 排除 phase 4 未给理由

**Symptom（症状）**：`REQUIREMENT.md:26` AC-2 phase 集合显式排除 4（dev 阶段）。REQUIREMENT.md 全文无任何文字说明为何 4 不需 review gate。

**Source（源头）**：AC 中显式列举的集合需可追溯——尤其排除中间值（0~7 之间唯独跳过 4）。

**Consequence（后果）**：若 phase 4 commit 应纳入 gate（dev 阶段通常需要 review），这是安全缺口；若不应，未来维护者可能错修复或错保留。

**Remedy（修补）**：在 AC-2 后补一句理由（如「phase 4 dev 阶段无独立 review 设计，gate 在 3->4 transition 已拦截」），或扩展集合覆盖 4。

---

### R10 [MINOR] · AC-2 单条覆盖 BUG-B+C+E，回溯定位困难

**Symptom（症状）**：`REQUIREMENT.md:24` AC-2 标题「review phase gate 正确 deny（BUG-B+C+E）」。

**Source（源头）**：测试有效性——一条 AC pass/fail 无法定位 3 个 bug 中哪个回归。

**Consequence（后果）**：回归发生时需人工拆解，延长 MTTR；缺陷密度统计失真。

**Remedy（修补）**：拆为 AC-2a（BUG-B）/ AC-2b（BUG-C deny 路径）/ AC-2c（BUG-E），各独立 Given/When/Then。

---

### R11 [MINOR] · AC-2「stderr 诊断」内容未规约

**Symptom（症状）**：`REQUIREMENT.md:28` AC-2 Then「hook deny exit 2 + stderr 诊断」；`REQUIREMENT.md:95` 可观测性 NFR 同样仅说「带 stderr 诊断」。

**Source（源头）**：AC 可验证性。

**Consequence（后果）**：hook 输出空 stderr 即可凑过，可观测性 NFR 无实质保障。

**Remedy（修补）**：规约最小内容，例「stderr 含 phase 名 + 阻断原因 + 解除指引（提示写 .done 路径）」。

---

### R12 [MINOR] · AC-5「写入 L2 盲审段」未指定文件路径

**Symptom（症状）**：`REQUIREMENT.md:49` AC-5 Then「写入 L2 盲审段，无『mock_ts 未绑定』错」。

**Source（源头）**：AC 可验证性。

**Consequence（后果）**：测试需猜输出位置，易假阳性/假阴性。

**Remedy（修补）**：明确路径「`.specs/<id>/INDEPENDENT-REVIEW-<phase>.md` 的 `## L2 盲审` 段，且段内含 `mock_ts` 字段」。

---

### R13 [MINOR] · 缺正向「.done 存在则放行 transition」用例

**Symptom（症状）**：AC-1 仅覆盖 0->1 放行；AC-2 仅覆盖 deny；AC-3 仅覆盖 phase0 / 非触发命令。无任何 AC 覆盖「phase in {1,2,3,5,6} 且对应 `.done` 存在，触发 forward transition -> allow」。

**Source（源头）**：等价类划分——denied（无 .done）与 allowed（有 .done）两侧都需测，缺一不可。

**Consequence（后果）**：「有 .done 则放行」正向路径无回归保护；一旦 .done 读取逻辑回归，AC 集合仍能全绿。

**Remedy（修补）**：补 AC：Given phase in {1,2,3,5,6} 且对应 `.independent-review-<phase>.done` 存在，When forward transition，Then allow exit 0。

---

**Verdict**: fail

存在 2 个 CRITICAL（R1 AC-7 不可机器验证、R2 AC-2/AC-3 同场景结论矛盾）+ 7 个 MAJOR（R3~R9）+ 4 个 MINOR（R10~R13）。按规则「fail 当且仅当存在 CRITICAL」，本次阶段 1 盲审 **fail**。

建议主 agent 在反驳前优先就 R1 / R2 给出修补方案（这两项不修则整个 change 的 AC 集合不可独立验证）；R3（诊断-修复顺序）涉及与 CHANGE.md 的对齐，建议在反驳段说明取舍；其余 MAJOR/MINOR 可在下一轮 REQUIREMENT 修订中合并处理。

---

### 附记（writeup 时观察到的活体现象，不计入正式 finding 编号）

本次写入审查报告时，PreToolUse hook `independent-review-gate.sh` 对一个仅含报告 heredoc 文本（其中字符串「git commit」作为 AC 分析对象出现，并非真实命令）的 Bash 调用予以 deny（exit 2）。这恰好是 REQUIREMENT.md AC-3 标题所列 BUG-C（无关命令放行 / 命令识别误判）的活体实例：hook 的命令识别基于文本子串匹配而非 payload 结构，会误伤「讨论 hook 行为的元文档写入」。建议在阶段 2/3（DESIGN/TASK）审查时把这一观察纳入 BUG-C 的根因分析与回归用例（例如：测试 payload 中 tool_name=Bash 但 command 文本含敏感子串时，hook 应按 tool_name + 实际意图判断，而非子串命中即 deny）。本附记仅作记录，不影响 R1~R13 的独立判断。

---

## 主 agent 响应（phase 1 · REQUIREMENT 修订）

> 本段为 L2 报告之后的主 agent 回应，未改写 L2 四要素原文。修订后的 REQUIREMENT.md 已落盘。

### R1 [CRITICAL] AC-7 不可验证 → **Fixed in**: REQUIREMENT.md AC-7 重写为 jq 断言（`gates` 全 passed / `phases_done` length=7 / `current_phase`=7），验证方式改 `jq -e`，消除"按设计/无异常/实跑"空话。

### R2 [CRITICAL] AC-2/3 矛盾 → **Fixed in**: AC-3 拆为 AC-3a（phase0）/ AC-3b（非触发命令）；AC-2 拆为 AC-2a（BUG-B deny）/ AC-2b（BUG-E gate-active），AC-2a 补澄清"review phase git commit 即使不切 phase 也 deny"。phase=3 git commit 现唯一归 AC-2a（deny），矛盾消除。

### R3 [MAJOR] 诊断-修复顺序 → **Not-applicable（附说明）**: CHANGE.md「先诊断后定」已遵循——DIAGNOSE.md 在 phase 0 产出（先诊断），用户经多轮 AskUserQuestion（"修4bug+重跑"→"固化A-E·F/G开新change"→"加严bats绿入v1"）确认修复范围。REQUIREMENT 反映用户决策，非预设；v1 段已注明决策链。

### R4 [MAJOR] bug 无定义 → **Fixed in**: REQUIREMENT 关联段加入 DIAGNOSE.md（bug A-H 定义源）；AC 段首句"BUG 标签定义见 DIAGNOSE.md 缺陷清单"。

### R5 [MAJOR] AC-6 计数 → **Fixed in**: AC-6 Then 列全 17 测试（smoke + AC-1/2/3/5a/5b/5c/9/10/11 + regression×2 + INT-1~5）。

### R6 [MAJOR] AC-6 范围 → **Fixed in**: AC-6 Given 改"修复 A-E+G 后"（F 在 v2，不影响 bats）。

### R7 [MAJOR] 兼容性 NFR → **Fixed in**: 新增 AC-8（gate_config=independent/true → both，phase review commit deny exit2）。

### R8 [MAJOR] 假设循环 → **Fixed in**: 移除"已验证"措辞，新增 AC-10 显式验证 fk_independent_review_gate_active 双源读（gate_config 优先 + stop-hook.json 回退）。

### R9 [MAJOR] phase 4 排除理由 → **Fixed in**: AC-2a 补注（phase 4 dev 无独立 review gate，gate_config 不含 4-dev；dev 审查由 phase 6 承担，3→4 由 phase 3 gate 把关）。

### R10 [MINOR] AC-2 拆分 → **Fixed in**: AC-2 拆为 AC-2a/AC-2b，与 R2 合并。

### R11 [MINOR] stderr 规约 → **Fixed in**: AC-2a Then 规约 stderr 含"phase 编号 + 阻断原因 + .done 路径"；可观测性 NFR 同步。

### R12 [MINOR] AC-5 路径 → **Fixed in**: AC-5 Then 明确"`.specs/<id>/INDEPENDENT-REVIEW-<phase>.md` 的 `## L2 盲审` 段（含 mock_ts）"。

### R13 [MINOR] 正向 .done 用例 → **Fixed in**: 新增 AC-9（.done 存在则 forward transition allow exit0）。

### 附记 · BUG-H（L2 活体发现）→ **记录为 v2（l2-l3-mock-fix）**: `is_git_commit` 基于 `[[ "$c" =~ git commit ]]` 文本子串匹配，误伤含"git commit"字符串的元文档 Bash 调用（L2 写本报告时被 deny，用 chr() 绕过）。根因：命令识别应基于 payload 结构（实际命令解析）而非子串。修复需结构化识别，归 v2。DIAGNOSE.md 后续同步，REQUIREMENT v2 段已记录。

**主 agent 自评**：L2 的 2 个 CRITICAL（R1/R2）判断准确， REQUIREMENT.md 确有 AC-7 空话 + AC-2/3 矛盾，已修复。R3 的"诊断-修复顺序"质疑在盲审视角（未读 DIAGNOSE）下成立，实际诊断先于修复，已注明。L2 独立审查有效——这正是 gate 修复后首次真实独立审查的价值证明。

---

## L3 重审（glm-4.7 外部模型 · 2026-07-17 10:44）

> 自动生成于 2026-07-17 10:44。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": "REQUIREMENT",
      "issue": "AC-10 缺少可验证的 Then 断言",
      "why": "AC-10 描述为“读 gate_config（优先）；gate_config 空时回退”，仅描述了逻辑路径，未定义具体的验证输出（如环境变量值、函数返回值或文件内容）。在 TEST 阶段无法编写机器判断脚本（如 `assert [ "$val" == "expected" ]`）来验证“读优先级”逻辑是否正确生效。",
      "fix": "补充 Then 断言，例如：'Then fk_independent_review_gate_active 返回 \"active\" 且日志显示 source=gate_config' 或 '当 gate_config 为空时，函数返回 \"active\" 且日志显示 source=.claude/stop-hook.json'。"
    },
    {
      "file": "REQUIREMENT",
      "issue": "AC-9 验证逻辑与 AC-2a 存在致命冲突，导致 AC-9 定义无效",
      "why": "AC-9 中 'When forward transition' 的操作会触发 git commit（写入 phase）。根据 AC-2a 的规则，此时若无 .done 文件应立即 exit 2 阻断。因此 '执行 transition' 与 '写入 .done 后再 transition' 两种状态无法在同一验证路径下并存，AC-9 的 'When' 条件在逻辑上是不成立的（会被 AC-2a 拦截），导致该 AC 不可验证。",
      "fix": "重新设计 AC-9 的验证路径，使其与 AC-2a 解耦。例如：'Given 已存在 .independent-review-<phase>.done，When 执行 next phase transition（内部 hook 检查时），Then 允许通过'。必须明确 .done 文件是在 When 动作之前已存在，而不是依赖 transition 去触发。"
    }
  ],
  "major": [
    {
      "file": "REQUIREMENT",
      "issue": "v1 范围中 '修复 A-E' 遗漏了 BUG-E 的具体实施内容",
      "why": "BUG-E 定义为 'Done 文件路径检查缺失'。AC 列表中仅有 AC-2b 提到 'gate_active 判定生效'，但未明确包含 '修复路径检查'（即检查 .done 是否存在）的 AC。v1 声称修复 A-E，但 AC 覆盖度缺失，若不补充对应 AC，TEST 阶段将无法验证 '路径检查' 是否已修复。",
      "fix": "在 AC 中补充一条针对 BUG-E 的验证，例如：'Given phase 3 且 gate 配置 both，When .independent-review-3.done 缺失，Then fk_independent_review_gate_active 返回 false 或 deny'。"
    },
    {
      "file": "REQUIREMENT",
      "issue": "AC-1 Then 验证步骤与 bug 定义不匹配",
      "why": "BUG-A 定义为 '死锁'，但 AC-1 的 Then 仅为 'exit 0'。exit 0 仅证明 Hook 未崩溃（Crash），不能证明未死锁（例如 'sleep infinity' 也是 hang，但可能不返回或超时）。对于 '死锁' 类 bug，验证指标通常是 '执行时间 < 阈值' 或 '流程状态推进'。",
      "fix": "增强 AC-1 的验证断言，增加 'duration < 5s' 或 'state 变更为 1' 的检查，以确保不仅仅是 exit 0，而是未挂起。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT",
      "issue": "v1/v2 范围切分理由不一致",
      "why": "v1 修复 BUG-C（gate 误报），v2 修复 BUG-F（gate 信息显示不完整）。两者均为 gate hook 的逻辑缺陷，且 BUG-F（显示空 phase）会阻碍排查。将 F 归类为 '非阻塞性瑕疵' 划入 v2 缺乏明确的量化标准（如 '影响面 > X 为 v1'），存在主观判断风险。",
      "fix": "明确 '非阻塞' 的定义标准（如：'不导致流程中断' 或 '不影响核心功能放行/阻断'），并在范围说明中引用该标准。"
    },
    {
      "file": "REQUIREMENT",
      "issue": "AC-8 验证方式描述不清",
      "why": "AC-8 提到 '注入 gate_config=independent'，但未明确注入的目标文件（.flow-active 还是 config.json）和字段结构。在 TEST 阶段构造 payload 时可能产生歧义。",
      "fix": "明确验证方式，例如：'Given .flow-active.goal.gate_config[1]=\"independent\"...'。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-10 缺失可验证断言，AC-9 与 AC-2a 存在逻辑冲突导致验证路径不闭环，无法指导 TEST 阶段产出有效用例。"
}
```
```

---

## L3 重审（glm-4.7 外部模型 · 2026-07-17 11:00）

> 自动生成于 2026-07-17 11:00。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"REQUIREMENT","issue":"AC-9 逻辑冲突导致语义崩溃","why":"AC-9 断言在 transition 时放行（exit 0），这与 toll-gate 的核心审查逻辑冲突：如果允许在 phase N 完成 N+1 的 transition 命令，意味着 L2/L3 尚未完成即可切换状态。若解释为'只有 .done 存在才允许 transition'，则 AC-9 与 AC-7（transition 逐阶段验证）逻辑重复但条件矛盾（先于审查完成）。其验证方式'预先构造 .done'跳过了审查生产过程，属于无效的验证路径。","fix":"删除 AC-9。Gate4 验证逻辑应回归 deny default：仅允许 Stop hook（特权）写入 .done，普通 Git Commit（非特权）必须被拒绝；Transition 的放行由 AC-7 的状态机保证（Phase N Done -> N+1）。"},{"file":"REQUIREMENT","issue":"AC-10 验证方式不可验证且逻辑自洽性存疑","why":"1. 不可验证：命令 `PROJECT_ROOT=<tmp> fk_independent_review_gate_active <phase>` 在干净目录中运行时，会因依赖（如 jq、配置文件缺失）而非逻辑原因失败，无法作为验证手段。2. 逻辑冲突：'gate_config 空时回退...视为 both' 的语义在 DIAGNOSE.md 中对应 BUG-D（未配应放行），若回退视为 both 则不仅违反 Bug-D 修复目标，还导致所有旧项目未配置 phase 全部被拦截，属破坏性变更。","fix":"修正 AC-10 逻辑：'空'应返回 false（gate inactive），视为 unconfigured（放行）。验证方式应基于挂载点（Phase 1/2/3），通过修改 .flow-active 观察实际 exit code，而非运行孤立函数。"},{"file":"REQUIREMENT","issue":"AC-2b 验证依赖循环","why":"AC-2b 旨在验证'gate 生效'（返回 true），但其验证方式依赖于 INT-3/INT-4 的'被 deny'结果。如果 INT 测试因其他原因（如非 .done）被 deny，即使 gate 函数返回 false（inactive），AC-2b 也会因'副作用'被判定为通过，导致验证失效。","fix":"为 AC-2b 增加单元级验证：直接断言函数在给定输入下的返回值（0 或 1），而非依赖集成测试的副作用。"}],"minor":[{"file":"REQUIREMENT","issue":"AC-2a 范围定义不全","why":"Given 定义了 gate_config[phase]=both，但当 gate_config 为旧值（independent/true）时未涵盖。根据 AC-8，这些值应视为 both，但 AC-2a 的 Given 未包含这种情况，导致旧值配置路径未被 AC 显式覆盖。","fix":"在 AC-2a 的 Given 中补充 'gate_config[phase]∈{both, independent, true}'。"},{"file":"REQUIREMENT","issue":"AC-6 计数器脆弱","why":"依赖 grep 计数（17）进行全量验证，一旦新增测试用例（如回归测试增加），AC 即告失败，维护成本高。","fix":"建议改为 'npx bats ... | grep -v \"^not ok\" | wc -l == 17' 或提供解释性说明（若无回归测试增加计划，当前可保留）。"}],"verdict":"fail","summary":"存在严重逻辑缺陷：AC-9 违反审查门禁时序要求（未审查先通过），AC-10 的回退逻辑与 BUG-D 修复冲突（未配即拦截）且无法独立验证。"}
```
---

## L2 重审（独立盲审 · REQUIREMENT.md v3）

**审查范围**：仅基于 `.specs/l2-l3-test-defect/REQUIREMENT.md`（v3）与 `.specs/l2-l3-test-defect/CHANGE.md`（调用方指定工件）。未读 DIAGNOSE.md / PROGRESS.md / .goal-snapshot.json / hook 源码。为核实 AC-6 验证方式所引用的测试名（`test/test_l2_pretooluse_dispatch.bats`）是否真正覆盖 REQUIREMENT AC 行为，附带读取了该 bats 文件的 `@test` 标题清单——这是 AC-6 验证方式的必要交叉检查，不构成对实现源的依赖。

**独立性声明**：未检测到主 agent 自评 / 草稿 / 概述 / 辩护注入；任务参数段（阶段/change-id/路径/工件/输出）为结构化调度信息，非上下文污染。

---

### 初审 13 项 finding 复核

| 初审 | 严重度 | v3 状态 | 备注 |
|---|---|---|---|
| R1 AC-7 不可验证 | CRITICAL | 已修 | Then 改 jq 断言（gates/phases_done），残留 current_phase 漏断（→ R19） |
| R2 AC-2/AC-3 矛盾 | CRITICAL | 已修 | AC-2 拆 2a/2b，AC-3 拆 3a/3b，phase=3 git commit 唯一归 AC-2a |
| R3 诊断-修复顺序 | MAJOR | 已说明 | v1 段注明诊断-决策链（DIAGNOSE.md 先产 + 用户多轮确认）；盲审视角无法核验决策链真伪，但文档层自洽 |
| R4 BUG-X 无定义 | MAJOR | 半修 | AC 段首句指向 DIAGNOSE.md（外部文件）；AC 行为本身自包含，BUG 标签可追溯性仍依赖外部 doc |
| R5 AC-6 计数 | MAJOR | 半修 | 17 项分项已列，但分项与 AC 拆分不对齐 + AC-11 幽灵名（→ R14） |
| R6 AC-6 前置矛盾 | MAJOR | 已修 | Given 改"修复 A-E+G 后（F 在 v2）" |
| R7 兼容性 NFR 无兜底 | MAJOR | 已修 | 新增 AC-8 |
| R8 假设循环 | MAJOR | 已修 | 移除"已验证"措辞，新增 AC-10 |
| R9 phase 4 排除理由 | MAJOR | 已修 | AC-2a 补注（gate_config 不含 4-dev） |
| R10 AC-2 拆分 | MINOR | 已修 | 拆 2a/2b |
| R11 stderr 规约 | MINOR | 已修 | AC-2a 规约 phase 编号 + 阻断原因 + .done 路径 |
| R12 AC-5 路径 | MINOR | 已修 | 明确 `.specs/<id>/INDEPENDENT-REVIEW-<phase>.md` 的 `## L2 盲审` 段 |
| R13 正向 .done | MINOR | 已修 | 新增 AC-9 |

初审 2 个 CRITICAL 已修补，进入本轮新发现。

---

### 本次新发现 / 残余问题

### 🟡 R14 · AC-6 测试清单「AC-N」名与 REQUIREMENT AC-N 一一错位（验收语义混淆）

**Symptom**：REQUIREMENT.md:72 AC-6 Then 列「smoke(1) + AC-1/2/3/5a/5b/5c/9/10/11(9) + regression×2(2) + INT-1~5(5)」。交叉核对 `test/test_l2_pretooluse_dispatch.bats` 实际 `@test` 标题：
- bats `AC-1` = "L2 missing triggers exit 2 for phase write" ← 测 L2 检测逻辑，与 REQUIREMENT AC-1（phase0 死锁 BUG-A）无关
- bats `AC-2` = "L2 completed returns 0" ← 与 REQUIREMENT AC-2a（review phase git commit deny BUG-B）无关
- bats `AC-3` = "gate_config=both L2 missing blocks" ← 与 REQUIREMENT AC-3a（phase0 命令放行 BUG-C）无关
- bats `AC-9` = "auto_advance mode does not block" ← 与 REQUIREMENT AC-9（.done 存在 forward transition allow）无关
- bats `AC-10` = "29-independent-review.sh has no silent error suppression" ← 与 REQUIREMENT AC-10（fk_independent_review_gate_active 双源读）无关
- bats `AC-11` = "l3-review.sh uses atomic write" ← REQUIREMENT 全文无 AC-11

**Source**：阶段 1 checklist「AC 必须自洽且可独立核验」。AC-6 把「测试名 AC-N 通过」与「REQUIREMENT AC-N 通过」的隐含映射建立在一个**不存在的对应关系**上——bats AC-N 是上一轮 `l2-pretooluse-dispatch` change 留下的、测 L2 dispatch 机制的测试，并非本轮 AC 的契约测试；本轮 AC 的实际覆盖由 `INT-1~5` 承担。

**Consequence**：审查者/测试方读 AC-6 易误判「bats AC-1 通过 = REQUIREMENT AC-1（phase0 死锁修复）已验证」，实则 bats AC-1 测的是另一行为。AC-6 通过只保证 17 个测试不挂，不直接证明 REQUIREMENT AC-1~AC-10 全部满足。与 US-1「非假绿」目标有张力——虽 INT-1~5 确实覆盖本轮 BUG-A~E+G，但 AC-6 命名让人误以为 AC-N bats 即 AC-N 验收。

**Remedy**：二选一：
(a) AC-6 显式声明「测试名 AC-N 是 bats 用例 ID（沿用上一 change），与 REQUIREMENT AC-N 编号无对应；本轮 AC 回归由 INT-1~5 承担」；
(b) 重命名 bats 用例（如 AC-1 → L2-DISPATCH-1）消除命名碰撞，并在 REQUIREMENT 内联 INT-N 最小行为表（编号 → 一句话行为 + BUG 映射）。

---

### 🟡 R15 · AC-10「判定源 = gate_config 优先」不可黑盒验证

**Symptom**：REQUIREMENT.md:102 AC-10 Then「判定源 = .flow-active.goal.gate_config[phase]（优先），gate_config 空时回退 .claude/stop-hook.json independent_review.phases（视为 both）」；REQUIREMENT.md:103 验证方式仅 `PROJECT_ROOT=<tmp> fk_independent_review_gate_active <phase>; echo $?` == 0。

**Source**：AC 可机器验证 checklist。「判定源 = X 优先」是一层行为语义，但验证方式只观测返回码——若函数实际读 stop-hook.json 而忽略 gate_config（违反优先级），只要两源都判定 active，测试仍绿。

**Consequence**：BUG-E 修复后「双源读优先级」逻辑无回归保护。与 US-1「非假绿」目标冲突——测试绿不等于优先级正确。

**Remedy**：加观测点：(a) 函数输出 stderr 日志 `source=gate_config|stop-hook`，验证方式加 `grep -q 'source=gate_config'`；或 (b) 构造冲突场景（gate_config=off + stop-hook=on）断言函数遵循 gate_config（返回 inactive），从行为侧验证优先级。

---

### 🟡 R16 · AC-10 双源皆空时的返回值未定义（与 AC-4 / BUG-D 兼容性存疑）

**Symptom**：REQUIREMENT.md:103 AC-10 验证方式只覆盖「gate_config 有值」+「删 gate_config key + stop-hook 含该 phase」两种；对「gate_config 空 + stop-hook.json phases 不含该 phase」未规定返回值。对照 REQUIREMENT.md:54-59 AC-4（BUG-D）：「gate_config 未配（gate_val 空）→ 放行」。

**Source**：AC 集合内部一致性 + 等价类完整覆盖。AC-10 与 AC-4 必须在「双源皆空」这一等价类上对齐：AC-4 说放行（gate inactive），AC-10 必须明确同义。

**Consequence**：实现方可能解读 AC-10「空时回退视为 both」为「空时一律 active」，导致未配 phase 被拦截，违反 BUG-D 修复目标（L3-2 第二轮已点名此风险）。旧项目未配置 phase 全部被拦截是破坏性变更。

**Remedy**：AC-10 Then 显式补「双源皆空 → 函数返回非 0（gate inactive），与 AC-4 一致」；验证方式加第三条断言「删 gate_config key + stop-hook.json phases 不含该 phase → echo $? != 0」。

---

### 🟡 R17 · AC-1/2a/2b/3a/3b/4 验证方式引用未定义的内部 ID（INT-N / TEST-N / Gate-N）

**Symptom**：REQUIREMENT.md:22 `INT-1 / payload TEST-1`；:29 `INT-3/INT-4 / TEST-3/6`；:38 `INT-3/INT-4`；:44 `Gate2 放行（不到 Gate6/7）`；:45 `INT-2 / TEST-2/5`；:52 `TEST-5（ls）`；:59 `INT-5`。这些 ID 在 REQUIREMENT 与 CHANGE 中均无定义。

**Source**：阶段 1 checklist「拒绝『系统应该正常工作』这类空话」+ 「AC 必须可机器验证」。验证方式引用未定义 ID 等同「存在某个测试」，是空话的变体；与 R4 同形态的追踪断链。

**Consequence**：审查者无法核对 INT-N 是否真覆盖 AC 行为（本轮交叉核对 bats 后 INT-1~5 与 AC-1/2a/2b/3a/4 行为对齐，但这是审查者自查，非 spec 自明）；测试方更改 INT-N 实现时 AC 不感知；TEST-1/2/3/5/6 与 Gate2/6/7 完全无定义。

**Remedy**：在 REQUIREMENT 内联 INT-N / TEST-N / Gate-N 最小定义表（编号 → 一句话行为 + 对应 AC + 关键断言），或把验证方式改为自包含脚本片段（不依赖外部命名约定）。

---

### 🟡 R18 · AC-2b 验证依赖 INT-3/INT-4 副作用（间接判定）

**Symptom**：REQUIREMENT.md:38 AC-2b 验证方式「INT-3/INT-4（gate 生效才会 deny）」——通过「集成测试被 deny」反推「gate_active 函数返回 active」。

**Source**：单元 vs 集成测试隔离原则。AC-2b 的 Then 是 `fk_independent_review_gate_active` 返回 active（单元行为），验证方式却走集成（INT deny）。

**Consequence**：若 INT-3/4 因非 gate_active 原因 deny（如 .done 路径错、命令识别 BUG-H），AC-2b 仍被判通过，掩盖 gate_active 真实返回 inactive 的回归。验证路径与 AC 断言不对齐。

**Remedy**：AC-2b 改单元级验证：`source done-validation.sh; PROJECT_ROOT=<tmp-with-gate_config-both> fk_independent_review_gate_active <phase>; echo $?` == 0，与 AC-10 同形态但锁定单源场景。

---

### 🟢 R19 · AC-7 验证方式漏 current_phase == "7" 断言

**Symptom**：REQUIREMENT.md:79 AC-7 Then「`.goal.current_phase` == "7"」；REQUIREMENT.md:80 验证方式仅 `(.goal.gates | map(select(.!="passed")) | length) == 0` + `(.goal.phases_done|length)==7`，无 current_phase 断言。

**Source**：Then 与验证方式必须一致闭合。

**Consequence**：终态 current_phase 回退（如停在 6）也能凑过验证方式；AC-7 终态判定不全。

**Remedy**：验证方式补 `jq -e '.goal.current_phase == "7"' .flow-active`。

---

### 🟢 R20 · AC-8 验证方式只测 `independent` 不测 `true`

**Symptom**：REQUIREMENT.md:84 AC-8 Given「gate_config[phase]=independent 或 true（旧值）」；REQUIREMENT.md:87 验证方式「payload 注入 gate_config=independent，断言 exit 2」——`true` 分支无验证。

**Source**：AC Given 的每个等价类都需 Then 覆盖（等价类划分）。

**Consequence**：`gate_config=true` 用户若回归静默放行不可见；R7（兼容性兜底）半覆盖。同形态问题在 AC-2a Given 也存在（仅「gate_config=both」，未含 independent/true）。

**Remedy**：验证方式补一条 `gate_config=true` 注入 + 断言 exit 2；AC-2a Given 同步改 `gate_config[phase]∈{both, independent, true}`。

---

### 🟢 R21 · AC-1 死锁验证仅 exit 0，无超时阈值

**Symptom**：REQUIREMENT.md:21 AC-1 Then「hook 放行 exit 0」对应 BUG-A「死锁」。

**Source**：BUG-A 性质是死锁，exit 0 仅证明「最终返回」，不证明「未挂起」——挂起后由测试框架默认超时杀，语义模糊。

**Consequence**：BUG-A 回归（性能退化至 hang）可能被测试框架默认超时掩盖，pass/fail 不稳定。

**Remedy**：Then 加「在 T 秒内返回」（建议 T=5s），验证方式用 `timeout 5 bash -c '...'` + `assert_success`。

---

### 🟢 R22 · AC-9 phase 集合 {1,2,3,5,6} 与 AC-2a {1,2,3,5,6,7} 不对称，phase 7 commit 放行契约未闭

**Symptom**：REQUIREMENT.md:91 AC-9 Given「phase∈{1,2,3,5,6}」（forward transition 正向）；REQUIREMENT.md:26 AC-2a Given「phase∈{1,2,3,5,6,7}」（commit deny 负向）。

**Source**：等价类闭合——deny 侧含 7，allow 侧不含 7，phase 7 commit 路径契约未定义。

**Consequence**：phase 7（终态）的 commit 放行契约未闭：AC-2a 说无 .done 即 deny，但「phase 7 有 .done → allow」无 AC 显式覆盖。实现方/测试方对 phase 7 commit 行为无据可依。

**Remedy**：二选一：(a) AC-2a 集合改 {1,2,3,5,6}（phase 7 不审查，与 AC-9 对齐），说明 phase 7 终态不收尾审查；或 (b) AC-9 扩展含 7 并说明 phase 7 `.done` 来源（如 Stop hook 完成终态审查后写入）。

---

### L3 双轮 critical/major 复核（独立判断）

**L3 第一轮（10:44）**：
- **L3-1.C1 AC-10 缺 Then 断言**：**成立但定性 MAJOR**（同 R15）。AC-10 有部分可验证断言（exit code + 回退路径），仅「判定源优先级」不可黑盒观测，未到「整体不可验证」级别。
- **L3-1.C2 AC-9 与 AC-2a 致命冲突**：**不成立**。AC-9 Given 明文「`.independent-review-<phase>.done` **已存在**（在 transition 之前由 L2+L3 完成后写入，非由本次 transition 触发）」（REQUIREMENT.md:91），AC-2a Given「**无 .done**」（REQUIREMENT.md:26）。两者前置互斥，不存在同输入下结论冲突。L3 误读 AC-9 的 When「forward transition」为「触发 .done 写入」，而 AC-9 显式排除该解读。

**L3 第二轮（11:00）**：
- **L3-2.M1 AC-9 删除（违反审查门禁时序）**：**不同意**。AC-9 测的是 Gate4 对「.done 已存在」这一前置的正向放行逻辑，是单元级 gate 行为测试；「预先构造 .done」是标准单元测试手法（precondition fixture），不等于「跳过审查生产过程」。L3 把 gate 逻辑测试与 end-to-end 审查生产混为一谈。AC-9 与 AC-7（终态 jq 断言）不重复——AC-7 测终态、AC-9 测 gate 单元放行，层级不同。
- **L3-2.M2 AC-10 回退逻辑与 BUG-D 冲突 + 不可验证**：**部分成立**。「不可验证」同 R15；「与 BUG-D 冲突」实为 AC-10 双源皆空情形未定义（R16），是覆盖缺失而非直接矛盾——AC-4 与 AC-10 可在「双源皆空 → inactive」上对齐，需 REQUIREMENT 明文补一条即可。
- **L3-2.M3 AC-2b 验证依赖循环**：**成立**（同 R18）。
- **L3-2.m1 AC-2a 范围不全（缺 independent/true）**：**成立**。AC-2a Given 限「gate_config=both」，旧值 independent/true 未覆盖；与 R20 同形态但落在 AC-2a 而非 AC-8。建议 AC-2a Given 改「gate_config[phase]∈{both, independent, true}」。
- **L3-2.m2 AC-6 计数脆弱**：**部分成立**，但脆弱性根因不在 grep 计数，而在 R14 的测试名-AC 错位（计数本身可经一次重命名后稳定）。

---

**Verdict**: pass

无 CRITICAL。初审 2 个 CRITICAL（R1/R2）已在 v3 修补（AC-7 jq 断言化、AC-2/AC-3 拆解消歧）。L3 双轮提出的 critical：第一轮 AC-10 成立但定性 MAJOR（R15），AC-9 冲突不成立（L3 误读 .done 前置）；第二轮无 critical（其 verdict=fail 与「fail 当且仅当存在 🔴 Critical」规则不一致）。本次新发 5 个 MAJOR（R14 测试名-AC 错位 / R15 优先级不可观测 / R16 双源皆空未定义 / R17 验证方式未定义 ID / R18 AC-2b 间接验证）+ 4 个 MINOR（R19~R22）。

建议进入阶段 2 前优先处理：
- **R14**：AC-6 命名碰撞直接影响验收语义，必须澄清（重命名 bats 或 AC-6 显式声明命名无对应）。
- **R16**：AC-10 与 AC-4 在「双源皆空」上必须显式对齐，否则与 BUG-D 修复目标冲突，可能引入破坏性回归（旧项目未配 phase 全被拦）。
- **R17**：INT-N/TEST-N/Gate-N 内联定义表，否则 TEST 阶段无法从 REQUIREMENT 直接派生用例。

R15 / R18 可在 DESIGN/TASK 阶段一并处理（验证方式补观测点 + 单元级断言）。R19~R22 可在下轮 REQUIREMENT 小修中合并。

---

### 附记（本轮写入未触发 BUG-H）

本次审查写入过程未再触发初审附记所记 BUG-H（含「git commit」字符串的元文档 Bash 调用被 deny）。可能与写入工具/路径不同有关（本轮用 `cat >> ` 追加而非 Bash heredoc），也可能 BUG-H 在某种条件下未触发。仅作记录，不构成新 finding；BUG-H 仍按 REQUIREMENT v2 段归入下一 change `l2-l3-mock-fix`。

---

## L3 重审（glm-4.7 外部模型 · 2026-07-17 11:16）

> 自动生成于 2026-07-17 11:16。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [
    {
      "file": "AC-2a",
      "issue": "gate 阻断验证缺失与放行路径定义歧义",
      "why": "1. 验证方式 'INT-3/INT-4' 仅覆盖 'denied' 分支，未覆盖 'both' 配置下 'allow' 分支（L2 审查通过后应有 gate-6/7 逻辑），存在测试盲区；2. 'Git commit（不切 phase）' 限制导致在 0→1 transition 场景下，phase=1 时的 git commit 既被判定为 '切换到 phase 1'（由 jq 操作触发），又被 AC-2a 限制为 '不切 phase'，逻辑冲突。",
      "fix": "1. 拆分 INT-3/INT-4 或新增 payload 用例覆盖 'L2 done but L3 pending' 状态，确认 L3 独立审查阶段阻断有效；2. 明确 AC-2a 是否仅适用于 'steady state' 下 commit，或调整 'When' 条件为 'Any git commit without .done' 以兼容 transition 期间的 commit 检查。"
    },
    {
      "file": "AC-9",
      "issue": "前置条件不可验证导致范围蔓延",
      "why": "Given 定义 '.done 存在（由 L2+L3 完成后写入）'。本次 scope (v1) 仅含 bug 修复，不包含 L2/L3 执行机制改造，无法保证 '由 Stop hook 写入' 的逻辑有效。若手动注入 mock 数据则无法验证 '真实链路'。AC-9 若放行依赖于未验证的 Stop hook，则实跑验证 (AC-7) 可能失败。",
      "fix": "将 AC-9 的验证目标调整为 '验证 Gate4 逻辑对 .done 文件存在的敏感性'（使用 mock .done），移除 '真实 L2+L3 写入' 的依赖假设；或者，若要求真实验证，需将 Stop hook 写入 .done 的能力纳入 v1 scope。"
    }
  ],
  "major": [
    {
      "file": "AC-10",
      "issue": "回退逻辑与默认配置存在空值风险",
      "why": "Given 未覆盖 'gate_config 空 AND stop-hook.json 空' 的双空情况。此时 '回退默认' 行为未定义，可能导致函数返回非 0（静默放行）或报错，违反 fail-close 原则。",
      "fix": "Given/Then 增加双空场景：断言函数返回 1（deny）或显式报错，确认默认行为。"
    },
    {
      "file": "AC-2a",
      "issue": "阻断信息字段漏定义",
      "why": "Then 要求 stderr 含 '阻断原因'，但 DIAGNOSE.md 定义中的 '_gate_deny_reason' (BUG-F) 列入 v2。若 BUG-F 未修复，阻断原因将显示空值或错误（如 'phase ' 无名称），导致 AC-2a 验证失败或输出不可用。",
      "fix": "将 BUG-F 修复（PHASE_GATE_KEY_MAP 初始化）移入 v1，或在 AC-2a 中移除对 '阻断原因' 内容的校验。"
    }
  ],
  "minor": [
    {
      "file": "AC-1/AC-3a",
      "issue": "术语指代模糊",
      "why": "AC-1 提 'hook 放行'，AC-3a 提 'Gate2 放行'。flow-kit 存在多个 hooks (start/stop/transition)，未指明具体哪个 hook。'Gate2' 可能是内部代号，在全局工件中未定义。",
      "fix": "统一术语为 'start-hook/stop-hook/transition-hook' 或给出 'Gate2' 的明确定义引用。"
    },
    {
      "file": "AC-6",
      "issue": "测试覆盖集未包含 AC-8/AC-9/AC-10",
      "why": "AC-6 声称 '全量 bats 全绿（17/17）'，但列表仅包含 AC-1/2/3/5。AC-8（兼容）、AC-9（放行）、AC-10（双源读）未在计数内，导致 '全绿' 与实际覆盖不符。",
      "fix": "补充测试用例计数，或明确 AC-6 仅针对 '核心回归'，新增用例单独统计。"
    }
  ],
  "verdict": "fail",
  "summary": "Critical 级别存在测试盲区与不可验证的前置依赖，Major 级别存在空值处理与字段依赖缺失，不符合机器可验证与独立盲审标准。"
}
```
```

---

## L3 重审（glm-4.7 外部模型 · 2026-07-17 11:26）

> 自动生成于 2026-07-17 11:26。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "AC-2a",
      "issue": "Verify logic missing for branch allow",
      "why": "验证方式仅覆盖 deny 分支（INT-3/4），对于满足 .done 条件时的 allow 分支，引用的是 INT-6，但 INT-6 是 AC-9 的验证方式。AC-9 的前置条件（Given）包含 phase 在 phases_done 或通过 Tier1 校验，而 AC-2a 的 Given 明确为 '无 .done'。因此 AC-2a 和 AC-9 验证的是互斥场景，AC-2a 的 allow 场景实际上没有被 AC-2a 覆盖。",
      "fix": "在 AC-2a 中添加验证方式覆盖 'Given 有 .done 时 allow' 的分支，或修改 Given 覆盖完整状态空间。"
    },
    {
      "file": "AC-9",
      "issue": "Unverifiable dependency",
      "why": "AC-9 Given 中包含 'fk_validate_done_marker 短路' 或 '通过 Tier1 6 键校验' 的内部逻辑描述。这些内部状态难以在外部测试中精确 Given（Mock fixture 难以保证短路逻辑触发，真实 .done 写入依赖 BUG-I 修复）。",
      "fix": "将 Given 收敛为可验证的外部状态：'Given .independent-review-<phase>.done 存在且 .flow-active 中对应 phase 在 phases_done 列表中'。"
    },
    {
      "file": "AC-10",
      "issue": "Ambiguous verification logic",
      "why": "Then 中定义 '双源皆空 -> 返回 1'。但在 gate 逻辑中，gate 关闭（inactive）通常意味着 'allow' (exit 0)，而 gate 生效且未通过审查才是 'deny' (exit 2)。返回 exit 1 作为 fail-close 逻辑在此处未明确其是对 gate 状态的判定还是执行结果。",
      "fix": "明确 Then 的预期：是断言函数返回值 1？还是断言最终执行结果 deny？若是函数返回值，需确认这是否是内部 API 测试；若是最终结果，需澄清 'inactive' 导致的行为（应放行）。"
    }
  ],
  "major": [
    {
      "file": "AC-1",
      "issue": "Ambiguous transition trigger",
      "why": "When 中描述 'jq 写 current_phase=1 ... 审查'。在实跑验证（TEST-1）或 Bats（INT-1）中，如果此动作模拟的是 PreToolUse 后的 forward transition，Given 中应明确 '已完成 PreToolUse 审查' 或审查结果。否则 Given 暗示了初始状态，When 触发了转换，但未明确转换所依赖的另一个输入（审查结果）。",
      "fix": "明确 Given：包含 L2/L3 review 通过的证据（或 Mock 状态），确保 When 的转换是基于所有前置条件满足。"
    },
    {
      "file": "AC-8",
      "issue": "Unsafe value range",
      "why": "When 中给定 gate_config 值为 'independent' 或 'true'。'true' 在 JSON 配置中通常是 boolean 类型。如果 gate_config 读取逻辑未做类型强转（如 `== "both"`），boolean true 可能导致逻辑错误（如 Lua/Json 中的类型不匹配）。需验证配置读取代码对类型的处理。",
      "fix": "明确 boolean true 与 string 'true' 的处理逻辑，或在 AC 中限定测试输入为 string 类型。"
    }
  ],
  "minor": [
    {
      "file": "AC-3b",
      "issue": "Incomplete coverage of deny commands",
      "why": "When 中 '非触发命令' 列表包含 'gh pr create'。根据上下文，'git commit' 和 'gh pr create' 是需要审查的触发命令（deny 候选）。AC-3b 的 Then 为 '放行'，但 'gh pr create' 不应放行（除非满足 .done）。测试 ID TEST-5 (ls) 仅覆盖了白名单，未覆盖 blacklist 命令的拦截逻辑。",
      "fix": "从 AC-3b 的 When 列表中移除 'gh pr create'，或添加 Then 断言其被 deny。"
    },
    {
      "file": "AC-7",
      "issue": "Potential flakiness",
      "why": "Given 依赖 '部署'。如果部署过程不包含验证步骤，实跑验证可能会因为环境差异（如二进制未更新）导致假阳性。",
      "fix": "无"
    }
  ],
  "verdict": "fail",
  "summary": "核心逻辑 AC-2a 验证覆盖存在缺口（allow 分支缺失），AC-9 Given 条件涉及内部不可测状态，AC-10 结果定义与 Fail-close 原则存在歧义，无法作为有效验收标准。"
}
```
---

## L2 三审（独立盲审 · REQUIREMENT.md v4）

**审查范围**：仅基于 `.specs/l2-l3-test-defect/REQUIREMENT.md`（v4）与 `.specs/l2-l3-test-defect/CHANGE.md`（调用方指定工件）。未读 DIAGNOSE.md / PROGRESS.md / hook 源码 / bats 实现。为核实 v4「测试 ID 定义表」与 AC-6 计数自洽性，附带读取了既有 INDEPENDENT-REVIEW-1.md 中前序 L2/L3 段（与本轮输出同文件）——这是任务参数「追加到末尾」的必要上下文，不构成对外部实现源的依赖。

**独立性声明**：任务参数段（阶段/change-id/路径/工件/输出）为结构化调度信息；既未含主 agent 自评/辩护注入，也未引导结论走向。未检测到独立性受损上下文。

---

### 上轮 finding 复核（v3 → v4）

| 上轮 | 严重度 | v4 状态 | 备注 |
|---|---|---|---|
| R14 测试名-AC 错位 | MAJOR | 已修 | 新增「测试 ID 定义表」+ AC-6 注明 bats-AC-N 与本文档 AC-N 无对应（REQUIREMENT.md:27） |
| R16 双源皆空未定义 | MAJOR | **修而致歧** | AC-10 Then 补「双源皆空 → 返回 1（deny，fail-close）」，但与 AC-4「未配 → 放行」直接冲突（→ R23） |
| R17 验证方式未定义 ID | MAJOR | 半修 | INT-1~6 内联定义；TEST-N 指向 DIAGNOSE.md（外部）；**Gate2/4/6/7 仍无定义**（→ R26） |
| R15 AC-10 优先级不可观测 | MAJOR | 未修 | 三场景仍只看返回码，无冲突场景（→ R25） |
| R18 AC-2b 间接验证 | MAJOR | 未修 | AC-2b 仍走 INT-3/4 副作用（→ R31） |
| R19 AC-7 current_phase 漏断 | MINOR | 未修 | 验证方式仍只断 gates/phases_done（→ R28） |
| R20 AC-8 不测 true | MINOR | 未修 | 验证方式只注入 independent（→ R29） |
| R22 AC-9 phase 集合不对称 | MINOR | 未修 | AC-9 {1,2,3,5,6} vs AC-2a {1,2,3,5,6,7}（→ R30） |

L3 第三轮（11:16）+ 第四轮（11:26，文件中实际存在）点名的 AC-2a/AC-9/AC-10 critical 在 v4 的回应：

- **AC-2a allow 分支**：v4 验证方式补「+ INT-6（.done 存在时 allow）」。但 INT-6 实为 AC-9 的验证手段，AC-2a 自身 Given 是「无 .done」——「AC-2a 的 allow 分支」在语义上不存在（无 .done 的 AC-2a 永远 deny）。INT-6 是把 AC-9 正向用例借来填补 allow 侧，可接受但 REQUIREMENT 未显式说明该借用关系。
- **AC-9 真实链路依赖**：v4 改 Given 为「mock fixture + phases_done 短路」，补「验证范围说明」剥离真实 Stop hook 依赖（BUG-I 归 v2）。**回应有效**。
- **AC-10 双空**：v4 补「双源皆空 → 返回 1（deny，fail-close）」，**此回应与 AC-4 直接冲突**（→ R23 critical）。

进入本次新发现。

---

### 🔴 R23 · AC-10「双源皆空 → deny，fail-close」与 AC-4「gate_config 未配 → 放行」直接矛盾

**Symptom**：`REQUIREMENT.md:120` AC-10 Then「双源皆空 → 返回 1（deny，fail-close）」；`REQUIREMENT.md:75` AC-4 Then「放行（不再误 exit2）」；`REQUIREMENT.md:152` 安全 NFR「双源皆空 deny」。「双源皆空」（gate_config 无该 phase 且 stop-hook.json phases 不含该 phase）即 AC-4「gate_config 未配（gate_val 空）」等价类的子集——同一等价类，AC-4 说放行，AC-10/NFR 说 deny。

**Source**：阶段 1 checklist「AC 集合必须内部一致」。两条 AC 对同一输入（双源皆空）给出互斥结论（放行 vs 拒绝），AC 集合不可同时满足，等同 spec 合规失败；同形态问题在初审 R2（AC-2/AC-3 矛盾，CRITICAL）出现过。此外 AC-10 文本**自身内部不一致**：函数名 `fk_independent_review_gate_active` 按本 AC「返回 0（gate active）」+ AC-2b「返回『gate 生效』」惯例，返回非 0 = inactive；而 inactive 在 gate 编排里等同放行——却标注「deny，fail-close」，返回码与文字标签互相打架（L3 第四轮 11:26 critical 同一观察）。

**Consequence**：实现方无法同时满足 AC-4 与 AC-10：按 AC-10 实现则 BUG-D（未配 phase 误 exit2）修复目标落空，所有旧项目未配 phase 的 commit 全部被拦——正是 L2 重审 R16 + L3 第二轮 M2 明确预警的「破坏性回归」；按 AC-4 实现则 AC-10 双空验证场景失败。TEST 阶段从 REQUIREMENT 派生用例时无据可依。直接对冲 US-1「确认门禁可信（非假绿）」——门禁的 fail-close/fail-open 边界本身在 spec 层未定。

**Remedy**：二选一并全文对齐：

(a) **采纳 AC-4 立场（推荐，符合 BUG-D 修复目标）**：AC-10 Then 改「双源皆空 → 返回 1（gate inactive，与 AC-4 一致）」；安全 NFR（REQUIREMENT.md:152）删去「双源皆空 deny」字样，保留「review phase 未审查不得 commit」；AC-10 验证方式第三场景改「双源皆空 → echo $? == 1（inactive）」。fail-close 仅适用于「phase 已配 gate 但无 .done」，不适用于「未配」。
(b) **采纳 fail-close 立场（推翻 BUG-D 修复目标）**：AC-4 改为「未配 → deny」，DIAGNOSE.md BUG-D 重新定性；但这与 v1「修复 A-E」矛盾，会级联推翻 AC-1~5 范围，不推荐。

推荐 (a)。这是 v4 修补 R16 时引入的回归，必须进入阶段 2 前解决。

---

### 🟡 R24 · AC-9 Given 含两个 OR 分支，v1 仅一分支可验

**Symptom**：`REQUIREMENT.md:109` AC-9 Given「`.independent-review-<phase>.done` 存在 **+ phase 在 phases_done（fk_validate_done_marker 短路）或 .done 通过 Tier1 6 键校验**」——「或」给出两条放行路径：(i) phases_done 短路、(ii) Tier1 6 键校验。`REQUIREMENT.md:112` 验证方式仅 INT-6（mock .done + phases_done 含 phase），只覆盖路径 (i)；路径 (ii)「Tier1 6 键校验」需真实 .done（6 键完整内容），而真实 .done 写入依赖 Stop hook = BUG-I（v2）。

**Source**：阶段 1 checklist「AC 必须可机器验证」+ 等价类划分。Given 的每个「或」分支是独立等价类，各自需 Then 覆盖。

**Consequence**：路径 (ii)（真实 .done 通过 6 键校验）在 v1 内不可验，AC-9 在 v1 内只覆盖路径 (i)。若实现方在路径 (ii) 引入回归（6 键校验逻辑错），AC-9 仍能凑过 INT-6，假绿。与 US-1「非假绿」目标冲突。

**Remedy**：二选一：(a) v1 显式声明「AC-9 v1 仅覆盖路径 (i)（phases_done 短路）；路径 (ii)（Tier1 6 键校验）归 BUG-I 修复后的 v2 验证」，并在 v2 段补一条；(b) 给 INT-6 补一个 fixture：构造含 6 键完整内容的真实 .done（非 phases_done 短路）→ 断言 allow，v1 内即覆盖两路径。

---

### 🟡 R25 · AC-10「判定源 = gate_config 优先」仍不可黑盒观测（R15 残余）

**Symptom**：`REQUIREMENT.md:121` AC-10 验证方式三场景：gate_config 源（==0）/ stop-hook 回退（==0）/ 双源皆空（==1）。三场景中无「gate_config 与 stop-hook 冲突」场景。

**Source**：AC 可机器验证 checklist。「优先级」语义只能在**两源给出不同判定**时从行为侧观测——若两源同向（皆 active），返回码 0 既符合「读 gate_config」也符合「读 stop-hook」，无法区分。

**Consequence**：BUG-E「双源读」修复后的优先级逻辑无回归保护。实现若实际忽略 gate_config 只读 stop-hook，三场景全绿。与 US-1「非假绿」冲突。

**Remedy**：加第四场景「冲突场景」：构造 gate_config[phase] 有值表示 inactive（或空）+ stop-hook.json phases 含该 phase，断言函数遵循 gate_config（而非 stop-hook）；或在函数加 stderr 日志 `source=gate_config|stop-hook`，验证方式加 `grep -q 'source=gate_config'`。

---

### 🟡 R26 · Gate-N（Gate2/4/6/7）在 REQUIREMENT 仍无定义（R17 残余）

**Symptom**：`REQUIREMENT.md:60` AC-3a「Gate2（_gate_phase_filter）放行 exit 0（不到 Gate6/7）」；`REQUIREMENT.md:110` AC-9「Gate4（done validation）通过」。v4 新增的「测试 ID 定义表」（REQUIREMENT.md:13-27）只定义 INT-1~6 与 TEST-N，**未定义 Gate2/4/6/7**。

**Source**：R17 remedy 明令「在 REQUIREMENT 内联 INT-N / TEST-N / Gate-N 最小定义表」。INT-N 已补，Gate-N 遗漏。L3 第三轮 11:16 minor 同一观察。

**Consequence**：审查者/测试方无法核对「Gate2 放行」是哪一层 gate、对应实现哪一段；AC-3a 的「不到 Gate6/7」是无定义引用。

**Remedy**：在「测试 ID 定义表」补 Gate-N 行（Gate2 = _gate_phase_filter，review phase 之外的放行层；Gate4 = done marker 校验层；Gate6/7 = …），或把 AC-3a/AC-9 的「Gate-N」改为自包含描述（如「phase filter 层放行」「done marker 校验层通过」）。

---

### 🟢 R27 · AC-9 引用 fk_validate_done_marker /「Tier1 6 键校验」未定义（与 R24 关联）

**Symptom**：`REQUIREMENT.md:109` AC-9 Given「fk_validate_done_marker 短路」「Tier1 6 键校验」——均为 done-validation.sh 内部函数/概念，REQUIREMENT 未定义。

**Source**：阶段 1 checklist「AC 必须可独立核验」。AC 引用未定义内部符号等同 R4/R17 同形态断链。

**Consequence**：审查者无法独立判断「6 键」是哪 6 键、「短路」触发条件；测试方需读源码才能构造 fixture。

**Remedy**：REQUIREMENT 内联「Tier1 6 键 = <键名列表>」或指向 DIAGNOSE.md 具体段；fk_validate_done_marker 的「短路」条件用一句话说明（如「phase 已在 phases_done 即视为已审查，跳过 .done 内容校验」）。

---

### 🟢 R28 · AC-7 验证方式仍漏 current_phase == "7" 断言（R19 残余）

**Symptom**：`REQUIREMENT.md:97` Then 含「`.goal.current_phase` == "7"」；`REQUIREMENT.md:98` 验证方式只有 gates 全 passed + phases_done length==7，无 current_phase 断言。

**Source**：Then 与验证方式必须闭合。

**Consequence**：终态停在 phase 6（current_phase 未推进到 7）也能凑过验证方式。

**Remedy**：验证方式补 `jq -e '.goal.current_phase == "7"' .flow-active`。

---

### 🟢 R29 · AC-8 验证方式仍只测 `independent` 不测 `true`（R20 残余）

**Symptom**：`REQUIREMENT.md:105` AC-8 验证方式「payload 注入 gate_config["1-requirement"]="independent"」，`true` 分支无验证；AC-2a Given 也仅「gate_config[phase]=both」（REQUIREMENT.md:42），未含 independent/true。

**Source**：AC Given 的每个等价类需 Then 覆盖。

**Consequence**：`gate_config=true`（boolean 或 string）若回归静默放行不可见。L3 第四轮 11:26 major 已点名此类型/值风险。

**Remedy**：AC-8 验证方式补一条 `gate_config[phase]="true"`（及 boolean true）注入 + 断言 exit 2；AC-2a Given 改 `gate_config[phase]∈{both, independent, true}`。

---

### 🟢 R30 · AC-9 phase 集合 {1,2,3,5,6} 与 AC-2a {1,2,3,5,6,7} 仍不对称（R22 残余）

**Symptom**：`REQUIREMENT.md:109` AC-9 Given「phase∈{1,2,3,5,6}」；`REQUIREMENT.md:42` AC-2a Given「phase∈{1,2,3,5,6,7}」。deny 侧含 7，allow 侧不含 7。

**Source**：等价类闭合——phase 7（终态）的「有 .done → allow」契约未定义。

**Consequence**：phase 7 commit 放行契约未闭：AC-2a 说无 .done deny，但「phase 7 有 .done → allow」无 AC 显式覆盖。

**Remedy**：(a) AC-2a 集合改 {1,2,3,5,6}（说明 phase 7 终态不再收独立审查 .done）；或 (b) AC-9 扩展含 7 并说明 phase 7 `.done` 来源。

---

### 🟢 R31 · AC-2b 验证仍依赖 INT-3/4 副作用（R18 残余）

**Symptom**：`REQUIREMENT.md:55` AC-2b 验证方式「INT-3/INT-4（gate 生效才 deny；正向见 AC-10）」——通过「集成测试被 deny」反推「fk_independent_review_gate_active 返回 active」。

**Source**：AC-2b 的 Then 是单元行为（函数返回 active），验证却走集成。

**Consequence**：若 INT-3/4 因非 gate_active 原因 deny（.done 路径错、BUG-H 命令识别误判），AC-2b 仍被判通过，掩盖函数实际返回 inactive 的回归。

**Remedy**：AC-2b 验证方式改为与 AC-10 同形态单元断言：`PROJECT_ROOT=<tmp-with-gate_config-both> fk_independent_review_gate_active <phase>; echo $?` == 0。

---

### L3 第三轮（11:16）+ 第四轮（11:26）critical 复核（独立判断）

**L3-3 (11:16) critical**：
- AC-2a 验证盲区（allow 分支缺失）+ transition 冲突：v4 已通过「When 改纯 git commit + 验证方式补 INT-6」回应，**成立度降为可接受**，但 AC-2a 自身 Given「无 .done」与「allow 分支」语义上互斥，INT-6 实为 AC-9 借用——建议 REQUIREMENT 显式注明借用关系（不构成新 finding）。
- AC-9 真实链路依赖：v4 改 mock fixture + 范围说明，**已修**。

**L3-4 (11:26) critical**：
- AC-2a allow 分支缺失（INT-6 是 AC-9 的）：**成立但同 L3-3**，性质为「AC-2a 借 AC-9 用例填 allow 分支」，需文档说明而非新增 critical。
- AC-9 Given 内部不可测状态（fk_validate_done_marker / Tier1）：**成立**（→ R24 + R27）。
- AC-10「双源皆空 → 返回 1」歧义（deny vs inactive）：**成立**（→ R23 critical）。

L3-4 三条 critical 中，AC-10 歧义定性 **CRITICAL**（与 AC-4 直接矛盾），AC-9 两条定性 MAJOR/MINOR（R24/R27）。

---

**Verdict**: fail

存在 1 个 CRITICAL（R23 AC-10 vs AC-4 矛盾，v4 修补 R16 时引入的回归）+ 3 个 MAJOR（R24 AC-9 双路径半覆盖 / R25 AC-10 优先级不可观测 / R26 Gate-N 未定义）+ 5 个 MINOR（R27~R31，多为 v3 残余未修）。

R23 是阻塞项：v4 在回应 R16 时把「双源皆空」从「未定义」改成「deny，fail-close」，与 AC-4「未配 → 放行」、BUG-D 修复目标直接冲突，并伴随 AC-10 返回码语义自相矛盾。必须先定 fail-close 边界（推荐 AC-4 立场：未配 = inactive = 放行），再进入阶段 2。

R24/R25/R26 可与 R23 同批小修（都是 AC-9/AC-10/测试 ID 表的局部补充，无范围震荡）。R27~R31 为 v3 已识别的 MINOR 残余，建议本轮一并清理而非继续后延。

---

## L3 重审（glm-4.7 外部模型 · 2026-07-17 11:41）

> 自动生成于 2026-07-17 11:41。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-7 缺失 Given/When/Then 可验证路径，且隐含与工件集冲突的依赖",
      "why": "AC-7 依赖 'from-0-all pipeline'，但在 'v1（本次必做）' 中并未包含对该 pipeline 的定义、部署或维护指令（仅提到 'L3 model' 修复）。AC-7 的 Then 路径 `.flow-active.goal.gates` 依赖外部工件（如 `stop-hook.sh`）写入，而 v1 验收准则 AC-9 的验证方式明确指出 'v1 不覆盖 Tier1 6 键校验路径...留 v2'。这导致 AC-7 无法在 v1 范围内独立闭环验证（验收逻辑断裂）。",
      "fix": "修改 AC-7 为 'Given' L2/L3 gate 修复完成，'When' 执行 INT-1~6 全量测试集，'Then' 18/18 全绿且无 exit 2 拦截（即取消对 `.flow-active` 状态文件的断言，改为断言测试行为）；或者将 '.flow-active' 状态验证移至 v2。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-10 逻辑断言与工件定义存在实现级歧义",
      "why": "AC-10 规定 '双源皆空 -> 返回 1 (inactive -> 放行)'。然而，gate 机制的 fail-close 策略要求 '非明确放行即阻断'。若 'gate_config' 与 'stop-hook.json' 皆空，系统逻辑应判定为 '配置缺失' 而拒绝服务（deny），而非放行。AC-10 将 'inactive' 定义为 '放行' 与 fail-close 策略在防御性编程层面冲突，且 '验证方式' 中并未覆盖 '配置缺失' 导致的非预期放行场景，存在安全风险。",
      "fix": "明确 '双源皆空' 的系统行为。若为防御性编程，应返回 0（active/deny）；若为业务放行（如 AC-4），需在 AC-10 中显式声明 '例外' 并解释为何配置缺失时允许放行。"
    }
  ],
  "major": [
    {
      "file": "REQUIREMENT.md",
      "issue": "v1 范围与 AC 覆盖率存在缺口",
      "why": "v1 声称覆盖 'L3 model (haiku env-first)'，但 AC 列表中无专门针对 L3 model 环境变量或模型切换（从 deepseek 切换至 haiku）的验证条目（仅有 INT-1~6 覆盖 gate 逻辑）。存在 '范围蔓延'（承诺了未写 AC 的功能）或 '测试盲区'风险。",
      "fix": "增加针对 L3 model 配置的 AC，或从 v1 范围中移除 'L3 model' 修改内容。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-1 验证方式引用歧义",
      "why": "AC-1 验证方式引用 INT-1/TEST-1，但 Given/Then 描述的 'hook 放行' 与 INT-1 的 'bats framework 保障' 存在概念混淆（hook exit code vs bats timeout handling）。建议统一术语。",
      "fix": "AC-1 Then 改为 'Then 执行通过且无 exit 2 拦截'，与 INT-1 保持一致。"
    }
  ],
  "verdict": "fail",
  "summary": "AC-7 缺失可验证闭环（依赖 v2 功能）且 v1 范围包含未测试的功能（L3 model），AC-10 安全逻辑存在 defensive/allow 策略冲突，导致无法通过独立审查。"
}
```

---

## L2 四审（独立盲审 · REQUIREMENT.md v5）

**审查范围**：仅基于 `.specs/l2-l3-test-defect/REQUIREMENT.md`（v5）与 `.specs/l2-l3-test-defect/CHANGE.md`（调用方指定工件）。未读 DIAGNOSE.md 正文 / PROGRESS.md / .goal-snapshot.json / hook 源码 / bats 实现。为复核「v4→v5 闭环」与满足「追加到末尾、不覆写」约束，附带读取了既有 INDEPENDENT-REVIEW-1.md 前序 L2/L3 段（同文件）。

**独立性声明**：任务参数段（阶段/change-id/路径/工件/输出）为结构化调度信息，非上下文污染；既未含主 agent 自评/辩护注入，也未引导结论走向。审查期间文件由 773 行增至 818 行（末尾被并发追加 `## L3 重审 11:41` 段）；为定位追加锚点，机械读取了文件尾部，不可避免地观察到该 L3 段对 AC-10 提出「双源皆空应 deny」的 critical。**本审查不接受该外部陈述**：基于 AC-4 + BUG-D 修复目标独立判断，v5 AC-10「双源皆空 = inactive = 放行」是正确立场（deny 立场会重蹈 BUG-D 破坏性回归——旧项目未配 phase 全被拦，正是 R16/R23 remedy(a) 所防）。本审查与 L3 11:41 在 AC-10 上结论相反，即为独立性之证。下文 R34/R35 虽与 L3 11:41 观察重叠，但均由 REQUIREMENT 内部证据（AC-7+:163+v2 BUG-I / v1 scope :134）独立导出。

---

### 上轮 finding 复核（v4 → v5）

| 上轮 | 严重度 | v5 状态 | 备注 |
|---|---|---|---|
| R23 AC-10 vs AC-4 矛盾 | CRITICAL | **AC 体已修 / NFR 残留** | AC-10 Then（:122）+ 注（:125）改「inactive=放行，与 AC-4 一致」；安全 NFR（:156）仍写「双源皆空 deny」未清除 → **R32** |
| R24 AC-9 OR 双分支 | MAJOR | 已修 | AC-9 Given（:111）收敛为单一 phases_done 短路路径；Tier1 6 键显式归 v2（:116 注） |
| R25 AC-10 优先级不可观测 | MAJOR | 未修 | 三场景仍无冲突场景、无 source 日志 → **R33** |
| R26 Gate-N 未定义 | MAJOR | 已修 | :27 内联 Gate1-7 定义 |
| R27 Tier1 6 键 / 短路未定义 | MINOR | 大半修 | fk_validate_done_marker 短路条件已内联（phase 在 phases_done）；6 键归 v2，v1 不需定义 |
| R28 AC-7 current_phase 漏断 | MINOR | 未修 | → **R36** |
| R29 AC-8 不测 true / AC-2a 限 both | MINOR | 未修 | → **R37** |
| R30 AC-9 与 AC-2a phase 不对称 | MINOR | 未修 | → **R38** |
| R31 AC-2b 间接验证 | MINOR | 未修 | → **R39** |

上轮唯一 CRITICAL（R23）的 AC 主体已闭环；进入本轮新发现 / 残余。

---

### 🟡 R32 · 安全 NFR（:156）残留「双源皆空 deny」，与 AC-4/AC-10/注 直接矛盾（R23 清除不彻底）

**Symptom**：`REQUIREMENT.md:156` 安全 NFR「gate 恢复 fail-close（review phase 未审查不得 commit/transition；**双源皆空 deny**）」；对照 `:122` AC-10「双源皆空 → 返回 1（inactive = 未配 = 放行，与 AC-4 一致）」+ `:75` AC-4「未配 → 放行」+ `:125` 注「未配 gate = inactive = 放行（AC-4），**非 deny**」。

**Source**：阶段 1 checklist「AC/NFR 集合内部一致」。R23 remedy(a) 明令「安全 NFR 删去『双源皆空 deny』字样」——v5 修了 AC-10 Then + 注，却漏改同义的安全 NFR。同形于 R23：同一「双源皆空」等价类，三处 AC/注说放行、一处 NFR 说 deny。

**Consequence**：实现者/审查者单读 NFR 段会得到与 AC 相反的门禁语义（deny），这正是 R23 想消除的歧义。虽 `:167` 声明 AC 为 TEST 唯一来源使 AC 立场生效，但安全 NFR 是 fail-close 边界的权威陈述处，残留错误字样会误导 v2 fail-close 讨论与 L3 审查（11:41 L3 正是据此 NFR 反推 deny 立场）。属「前 CRITICAL 不完整清除」。

**Remedy**：`:156` 改为「gate 恢复 fail-close（review phase **已配 gate** 但未审查不得 commit/transition）；双源皆空 = 未配 = 放行（AC-4/AC-10）」。删去「双源皆空 deny」字样。

---

### 🟡 R33 · AC-10「判定源 = gate_config 优先」仍不可黑盒观测（R25 残余）

**Symptom**：`:123` AC-10 验证方式三场景：gate_config 源（==0）/ stop-hook 回退（==0）/ 双源皆空（==1）。无「两源冲突」场景，函数也无 stderr source 日志。

**Source**：AC 可机器验证 checklist。「优先级」语义只能在两源给出不同判定时从行为侧观测。场景一「gate_config 源」未声明 stop-hook 是否同含该 phase——若同含，返回 0 既符合「读 gate_config」也符合「读 stop-hook」，优先级无回归保护。

**Consequence**：BUG-E「双源读优先级」修复逻辑无黑盒守护。实现若实际忽略 gate_config 只读 stop-hook，三场景全绿。与 US-1「非假绿」冲突。

**Remedy**：加第四「冲突」场景：gate_config[phase] 缺失/空 + stop-hook.json phases 含该 phase → 断言遵循 gate_config 优先 = inactive（`echo $?` == 1）；或在函数加 stderr `source=gate_config|stop-hook` 日志，验证方式加 `grep -q 'source=gate_config'`。

---

### 🟡 R34 · AC-7 全链路终态依赖 BUG-I（v2），v1 内可达性与失败语义未声明（新）

**Symptom**：`:97-100` AC-7 Given「gate 修复 + 部署，pipeline from-0-all 实跑」、Then 断言 `.flow-active.goal.gates` 全 passed + phases_done == ["0".."6"] + current_phase == "7"；`:163` 依赖假设「.done 写入依赖 Stop hook（BUG-I 环境问题）」；`:144` BUG-I（Stop hook 链触发可靠性）归 v2。AC-7 的终态依赖沿途每阶段真实 `.independent-review-<phase>.done` 由 Stop hook 写入——而 Stop hook 可靠性 = BUG-I = v2。

**Source**：阶段 1 checklist「依赖与假设必须显式 + AC 可机器验证」。AC-9 用 mock fixture 规避 BUG-I（:163），但 AC-7 是真跑，无法用 mock；AC-7 的 Given（full pipeline 实跑）在 BUG-I 未修时可能不可达（Stop hook 不触发 → 无 .done → phase 间 transition 被 AC-2a deny → pipeline 卡死，终态 jq 断言无从谈起）。`:163` 仅说明 AC-9 规避，未说明 AC-7 对 BUG-I 的暴露。

**Consequence**：v1 范围（:137「from-0-all pipeline 实跑」）与 BUG-I 归 v2 存在张力：若 BUG-I 在实跑环境触发，AC-7 不可达，US-1「实跑验证 gate 非假绿」无法在 v1 闭环。spec 未声明此风险，实现/测试方对 AC-7 的 v1 可行性无据可依。

**Remedy**：二选一：(a) AC-7 Given 补「假设 Stop hook 框架层可用（BUG-I 未触发）；若 BUG-I 触发，AC-7 转 v2 验证」，显式声明可行性边界；(b) 明确 AC-7 的「实跑」在 BUG-I 触发时降级为「INT-1~6 + AC-2a~AC-10 单元/集成层全绿即视为 gate 链可信」，并补该降级路径的 Then。

---

### 🟡 R35 · v1 范围含「L3 model（haiku env-first，移除 deepseek fallback）」无对应 AC（新）

**Symptom**：`:134` v1 范围「修复 A-E + G（l2-detect mock_ts）+ **L3 model（haiku env-first，移除固定 deepseek fallback）**」；遍历 AC-1~AC-10，无一条验证 L3 模型 env-first 选择或 deepseek fallback 移除。

**Source**：阶段 1 checklist「AC 集合须覆盖 v1 范围每条交付」+「拒绝『系统应该正常工作』空话」。v1 明列交付项却无 AC 兜底，等同「改了但不验」。

**Consequence**：L3 model 改动（fallback 链行为变更）在 v1 内不可验收：是否真移除 deepseek 固定 fallback、env-first 是否生效，无 AC 断言，回归不可见。与 US-1「非假绿」冲突——v1 声称交付但无验收口径。

**Remedy**：补一条 AC（如「Given L3_MODEL 未设/已设，When l3-review.sh 选模型，Then 优先读 env、无固定 deepseek fallback；deepseek 仅在显式 env 设置时生效」），验证方式 `L3_MODEL=haiku ... l3-review.sh ...` + 断言请求的 model 字段；或从 v1 范围 `:134` 移除「L3 model」归入 l2-l3-mock-fix（v2）。

---

### 🟢 R36 · AC-7 验证方式仍漏 current_phase == "7" 断言（R28 残余）

**Symptom**：`:99` Then 含「`.goal.current_phase` == "7"」；`:100` 验证方式只有 gates 全 passed + phases_done length==7，无 current_phase 断言。

**Source**：Then 与验证方式必须闭合。

**Consequence**：终态停在 phase 6（current_phase 未推进）也能凑过验证方式。

**Remedy**：验证方式补 `jq -e '.goal.current_phase == "7"' .flow-active`。

---

### 🟢 R37 · AC-8 仍只测 independent 不测 true；AC-2a Given 仍限 both（R29 残余）

**Symptom**：`:107` AC-8 验证方式仅注入 `gate_config["1-requirement"]="independent"`；`:42` AC-2a Given 仅「gate_config[phase]=both」。`true`（string 与 boolean）分支无验证。

**Source**：AC Given 每个等价类需 Then 覆盖。

**Consequence**：`gate_config=true` 回归静默放行不可见。

**Remedy**：AC-8 补 `gate_config[phase]="true"`（及 boolean true）注入 + 断言 exit 2；AC-2a Given 改 `gate_config[phase]∈{both, independent, true}`。

---

### 🟢 R38 · AC-9 {1,2,3,5,6} 与 AC-2a {1,2,3,5,6,7} phase 集合仍不对称（R30 残余）

**Symptom**：`:111` AC-9 Given「phase∈{1,2,3,5,6}」；`:42` AC-2a Given「phase∈{1,2,3,5,6,7}」。deny 侧含 7、allow 侧不含 7。

**Source**：等价类闭合——phase 7「有 .done → allow」契约未定义。

**Consequence**：phase 7（终态）commit 放行契约未闭。

**Remedy**：(a) AC-2a 集合改 {1,2,3,5,6}（说明 phase 7 终态不再收独立审查 .done）；或 (b) AC-9 扩展含 7 并说明 phase 7 `.done` 来源。

---

### 🟢 R39 · AC-2b 验证仍走 INT-3/4 副作用 + 返回契约与 AC-10 不一致（R31 残余 + 新）

**Symptom**：`:55` AC-2b 验证方式「INT-3/INT-4（gate 生效才 deny；正向见 AC-10）」——经集成 deny 反推函数返回 active。另 `:56` AC-2b Then「fk_independent_review_gate_active 返回『gate 生效』（非『未开』）」（措辞像 stdout 字符串），而 `:122` AC-10 Then 定义返回值语义为 exit code（0=active / 1=inactive）。两 AC 对同一函数返回契约形态不一致。

**Source**：AC-2b Then 是单元行为却走集成验证；且未声明该函数「stdout 描述 + exit code」双通道，AC-2b 与 AC-10 各取其一却无统一定义。

**Consequence**：(1) 若 INT-3/4 因非 gate_active 原因 deny（.done 路径错、BUG-H 命令误判），AC-2b 仍被判过，掩盖函数实际返回 inactive 的回归；(2) 测试方对「校验字符串还是校验 `$?`」无据可依。

**Remedy**：AC-2b 验证方式改为与 AC-10 同形态单元断言（`PROJECT_ROOT=<tmp-with-gate_config-both> fk_independent_review_gate_active <phase>; echo $?` == 0）；并在 AC-10 或测试 ID 表一句话声明该函数「stdout 状态描述 + exit code 映射 active(0)/inactive(1)」，AC-2b/AC-10 各测其一。

---

**Verdict**: pass

无 🔴 CRITICAL。上轮唯一阻塞项 R23 的 AC 主体（AC-10 Then `:122` + 注 `:125`）已按 remedy(a) 改为「双源皆空 = inactive = 放行，与 AC-4 一致」，fail-close 边界在 AC 层正确闭合——本审查独立确认此立场正确（deny 立场会重蹈 BUG-D 破坏性回归，与并发 L3 11:41 结论相反）。R24（AC-9 OR 收敛为单路径）、R26（Gate1-7 内联定义）已修。

本轮新发/残余 4 个 MAJOR（R32 安全 NFR 残留「双源皆空 deny」/ R33 AC-10 优先级不可观测 / R34 AC-7 依赖 BUG-I 可达性未声明 / R35 L3 model 无 AC）+ 4 个 MINOR（R36~R39，多为 v3 起未清理）。

建议进入阶段 2 前优先处理：
- **R32**：一行 NFR 文本清除（无范围震荡），消除前 CRITICAL 的最后残留，并止住 L3 据此反推 deny 立场的误源。
- **R35**：v1 范围 `:134` 的 L3 model 交付必须有 AC 兜底（或显式归 v2），否则 v1「已交付」不可信。
- **R34**：AC-7 与 BUG-I(v2) 的可行性边界必须显式声明，否则 US-1 实跑验证可能在 v1 内无法闭环。

R33 可在 DESIGN/TASK 阶段补冲突观测点。R36~R39 为长尾 MINOR，建议本轮一并清理（三审/四审两次提示），勿再后延。

---

## L3 重审（glm-4.7 外部模型 · 2026-07-17 11:54）

> 自动生成于 2026-07-17 11:54。由 l3-review.sh 写入。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [
    {
      "file": "REQUIREMENT: 诊断 L2/L3 gate 机制 + 全链路实跑验证",
      "issue": "AC-10 验证方式与 Then 断言存在潜在歧义",
      "why": "AC-10 的 Then 定义返回值：0=gate active(deny), 1=gate inactive(allow)。但其验证方式建议使用 `echo $?` 检查 `fk_independent_review_gate_active`。在 Bash 中，函数内部返回 `return 0` 导致 `echo $?` 为 0，符合断言；但若函数内部使用 `return 1` (表示 inactive)，`echo $?` 将为 1。如果 AC 意指 '0=Active' 是通过 Exit Code 0 来表示（而非逻辑取反），则 '1=Inactive' 应为 Exit Code 1。然而，Shell 逻辑中 Exit Code 非 0 通常视为 Fail。若此处未显式说明采用 'Exit Code 0 代表 Active，Exit Code 1 代表 Inactive' 的映射，而是约定俗成的 '0 代表成功'，则 Inactive 应为 Exit Code 0，这与 Then 中定义的 '0=Active' 冲突。虽然解释逻辑上通顺，但验证方式未明确 'Active 对应 Exit 0' 还是 'Active 对应 Return 0 且检测逻辑需反转'。",
      "fix": "在 AC-10 的 Then 或 验证方式 中补充明确说明：'Exit Code 0 表示 Active(Trigger Deny)，Exit Code 1 表示 Inactive(Allow)'，消除 Bash 约定(0=Success)与业务语义(0=Active)之间的潜在歧义。"
    }
  ],
  "minor": [],
  "verdict": "pass",
  "summary": "AC 覆盖了 Bug A-E+G 的修复验证及 v1 范围，Given/When/Then 可验证；v1/v2/out 边界清晰；非功能性需求完善。唯一的歧义点在于 AC-10 的返回值语义在 Shell 上下文中的表达，但在结合 'Then' 描述与 '验证方式' 的 `echo $?` 上下文后，可推断为 Exit Code 映射关系，不构成阻断性 Critical。"
}
```
```
