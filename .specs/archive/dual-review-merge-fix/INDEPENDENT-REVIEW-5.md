# 独立审查 · 阶段 5

## L2 盲审

### 🟡 R1 · 测试方法论：14 条测试中 10 条为源码字符串存在性检查，非行为验证
**Symptom（症状）**：`test/test_dual_review_merge.bats` 中 AC-1（line 153-166）、AC-2（line 183-193）、AC-3（line 228-231）、AC-4（line 29-49）、AC-5（line 237-247）、AC-7（line 172-177）共 10 条 @test 均使用 `grep -q "<expected_string>" <source_file>` 作为唯一验证手段。
**Source（源头）**：TEST.md line 14 声称覆盖 AC-1~AC-8，但测试实际验证的是"源码中是否写入预期指令/日志字符串"而非"运行时代码行为是否正确"。
**Consequence（后果）**：
- 误报风险：字符串可存在于注释、死代码、或错误上下文中，test 仍通过。
- 漏报风险：真正的行为缺陷（如 L2-wait 检查位置错误、`.done` 写入时序错误）不会被捕获。
- 重构脆弱性：日志消息措辞变更会破坏测试，即使行为正确。
**Remedy（修补）**：
1. 对 AC-1（L2-wait gating）：mock `fk_independent_review_gate_active()` 返回 `both`，构造无 L2 段的 review 文件，调用 hook 29 的 L3 前置逻辑段，断言 `l3_review_run` 未被调用且 exit code 为 0。
2. 对 AC-2/AC-3（append+preserve）：在 fixture 目录创建含 `## L3 盲审` 段的 review 文件，运行追加逻辑，`grep -c` 验证 L3 段数量未变。
3. 对 AC-4（.done deferred）：mock gate_config=both + L2 未完成，调用 `l3_review_run`，断言 `.done` 文件不存在。
4. 对 AC-5（跨阶段一致性）：将 AC-1~AC-4 的 mock 测试对 {1,2,3,5,6,7} 逐阶段参数化执行（当前仅检查 `phase_name` 字符串存在于 `done-validation.sh` 中，未验证行为一致性）。

---

### 🟡 R2 · AC-3 测试过于宽泛：`>>` 匹配任何重定向，非特指 L3 追加写入
**Symptom（症状）**：`test/test_dual_review_merge.bats` line 228-231：
```bats
@test "AC-3: l3-review.sh preserves >> append logic" {
  run grep -q '>>' "$L3_LIB" 2>/dev/null
  [ "$status" -eq 0 ]
}
```
**Source（源头）**：`grep -q '>>'` 匹配文件中**任何**出现的 `>>`——包括 `>&2` stderr 重定向、条件表达式 `$? >>`、heredoc 定界符注释等。不特指追加写入 review 文件的 `>>` 操作。
**Consequence（后果）**：若 L3 追加逻辑被意外改为 `>`（覆写），但文件中保留了任意其他 `>>`（如 `echo ... >> "$log"`），测试仍通过——形成虚假安全感。
**Remedy（修补）**：将 grep 模式收紧为特指 review 文件追加的上下文，例如 `grep -q '>> "$review_md"'` 或 `grep -q '>>.*INDEPENDENT-REVIEW'`。更佳方案：行为测试——构造已有 L2 段的 review 文件，运行 L3 追加，断言文件行数增加且 L2 段内容未变。

---

### 🟢 R3 · AC-1 PreToolUse 与 Stop hook 使用不同搜索字符串，暗示逻辑可能不一致
**Symptom（症状）**：
- AC-1 Stop hook 测试（line 157）：`grep -q "L2 not yet complete" "$hook29"`
- AC-1 PreToolUse 测试（line 164）：`grep -q "L2 尚未完成" "$gate_script"`
**Source（源头）**：两个执行点使用了不同的日志消息（英文 vs 中文）。TEST.md 声称 AC-1 覆盖"双路径 L2-wait"，但两处检查用不同字符串，无法保证逻辑等价。
**Consequence（后果）**：若其中一个执行点的 L2-wait 逻辑存在缺陷（如检查条件不同、仅在特定分支触发），另一个测试仍会通过。两套独立搜索字符串降低了交叉验证能力。
**Remedy（修补）**：统一日志消息语言（建议英文，与 `[independent-review]` 前缀风格一致）。或在测试中同时检查两个文件的关键保护逻辑结构（不仅检查日志字符串，更检查 `gate_config="both"` 判定 + L2 段缺失检测的条件分支）。

---

### 🟢 R4 · AC-5 跨阶段一致性仅验证字符串存在，未验证行为等价
**Symptom（症状）**：`test/test_dual_review_merge.bats` line 237-247 仅检查 `done-validation.sh` 中是否包含 6 个 `phase_name` 字符串。
**Source（源头）**：AC-5 要求"AC-1~AC-4 的行为在所有阶段完全一致"，但测试仅验证了 `phase_name` case 分支的存在性，未对任何阶段执行 AC-1~AC-4 的行为级验证。
**Consequence（后果）**：若某个阶段（如 phase 5）的 AC-1~AC-4 行为因配置差异而偏离，该测试无法发现——它只证明了 case 语句存在，不证明 case 内逻辑一致。
**Remedy（修补）**：将 R1 建议的 mock 行为测试参数化到全部 6 个阶段，确保每个阶段的 L2-wait、append、`.done` deferred 逻辑可重复验证。

---

### 🟡 R5 · TEST.md 与 TASK.md 回归测试数量不一致（346 vs 213）
**Symptom（症状）**：
- TEST.md line 15：`| 全量回归 | test/ 全部 bats | 346 | ✅ 全部通过`
- TASK.md line 227：`确保无回归（213 tests 全部通过）`
**Source（源头）**：TASK.md 的 T07 verify 段写死了 213 这个过期数字，而 TEST.md 引用了实际 bats count 结果（346）。经实际执行 `npx bats test/ --count` 确认当前全量测试数为 346。
**Consequence（后果）**：虽然 TEST.md 的数字（346）与当前实际测试数一致，但 TASK.md 中的 213 可能在 CI 验证脚本中被引用，导致自动化检查对不上实际计数。这本身是 TASK.md 的缺陷，但 TEST.md 作为测试报告应标注此差异而非忽略。
**Remedy（修补）**：TEST.md 中增加一行注释说明基线变更：`<!-- 注：TASK.md T07 仍引用旧基线 213，实际全量回归已增长至 346，本 TEST 以实际 bats --count 为准 -->`。同时建议修复 TASK.md 的 T07.verify 为动态计数（`npx bats test/ --count`）而非硬编码。

---

**Verdict**: pass

（无 Critical 发现。所有 8 条 AC 均有至少 1 条对应测试用例；新增 14 条测试聚焦于双路径 L2-wait、KVP 值域、append 约束三个核心变更面；全量 346 条回归无退化。上述中等风险（R1/R2/R5）为测试方法学深度问题——grep 字符串检查替代了行为 mock 验证——在 shell hook 测试环境 mock 成本高的约束下属于务实权衡，但应在后续迭代中补充行为级测试。）
