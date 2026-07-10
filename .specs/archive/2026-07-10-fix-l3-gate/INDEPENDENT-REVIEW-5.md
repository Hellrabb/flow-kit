# 独立审查 · 阶段 5

## L2 盲审

### 🔴 R1 · AC-4 未完整实现：5-test / 6-review prompt 的 transition jq 缺失 `.phase` 同步

**Symptom（症状）**：
`flow-kit-bundle/flow-kit/prompts/5-test.md` L151 的 transition jq 为：
```
.goal.current_phase = "6" | .goal.phases_done += ["5"] | .goal.gates["5→6"] = "passed" | .updated_at = $ts
```
缺少 `.phase = "6"`。同理 `6-review.md` L202 缺少 `.phase = "7"`。

而 `1-requirement.md`、`2-design.md`、`3-task.md` 均已正确加入 `.phase = "N"`（`"2"`、`"3"`、`"4"`），唯独 stage 5→6 和 6→7 的模板缺失。

**Source（源头）**：
T03 任务（TASK.md）要求在所有 6 个 prompt 文件的 transition jq 模板中加入 `.phase` 同步。1-3 阶段完成了，但 5-test.md 和 6-review.md 被遗漏。同时测试文件 `test/test_fix_l3_gate.bats` 仅覆盖了 0-change.md、1-requirement.md、2-design.md、3-task.md —— 没有针对 5-test.md、6-review.md、GO.md 的 `.phase` 断言。

**Consequence（后果）**：
当 pipeline 从 phase 5 推进到 phase 6（或 6→7）时，LLM agent 按 prompt 模板执行 transition jq，`.flow-active` 的顶层 `.phase` 字段不会被更新为 `"6"`/`"7"`，而 `.goal.current_phase` 会更新。这将导致 `.phase != .goal.current_phase` —— 直接违反 AC-4 的"四个字段全部一致"要求。后果是 pipeline 状态字段不一致，可能影响后续 hook 的 phase 判定逻辑（多处代码按 `scope` 选择读 `.phase` 或 `.goal.current_phase`）。

**Remedy（修补）**：
1. 在 5-test.md L151 的 jq 表达式中增加 `| .phase = "6"`，在 6-review.md L202 增加 `| .phase = "7"`。
2. 在 `test/test_fix_l3_gate.bats` 中新增 3 条测试：5-test.md `.phase = "6"`、6-review.md `.phase = "7"`、GO.md `.phase = "1"`（或确认 GO.md 无 transition jq 后记录为 N/A）。
3. 重跑 `npx bats test/test_fix_l3_gate.bats` + `npx bats test/` 回归。

---

### 🔴 R2 · 测试覆盖缺口：T03 要求的 5-test / 6-review / GO.md 的 `.phase` 同步无测试

**Symptom（症状）**：
`test/test_fix_l3_gate.bats` 的 prompt 测试仅覆盖 0-change.md、1-requirement.md、2-design.md、3-task.md（4 个文件）。而 TASK.md T03 明确要求修改 6 个文件 + GO.md，共计 7 个目标。5-test.md、6-review.md、GO.md 在测试文件中完全没有对应断言。

**Source（源头）**：
T04 任务设计意图是覆盖所有 AC，但 prompt transition jq 的测试用例仅编写了 4 条（覆盖 0-change ~ 3-task），遗漏了后续阶段。

**Consequence（后果）**：
测试套件的 20 条测试虽然全部通过（exit 0），但不能检测到 AC-4 的实现缺失（R1 所指问题）。测试覆盖率虽然在数量上声称 100% AC 覆盖，但实际上 AC-4 的完整性并未被验证。假绿风险——测试通过与否不能反映 AC 满足度。

**Remedy（修补）**：
同 R1 的 remedy 第 2 条。此外建议将 prompt 文件列表维护为变量，循环遍历以确保新增 prompt 文件不会被遗漏。

---

### 🟡 R3 · 测试性质薄弱：多数测试为 grep-on-source 静态检查，非运行时行为验证

**Symptom（症状）**：
20 条测试中：
- 6 条为 grep 静态文本（L237-306，检验源码中存在某字符串）
- 2 条为手动构造 .done 文件后 source（L115-148，不经过 hook 脚本）
- 4 条为独立 jq 模拟（L154-207，不调用 31-auto-advance.sh）
- 2 条为纯数值比较（L213-231，不涉及任何 hook 逻辑）
- 仅 4 条涉及实际文件系统操作（L51-89 的 stat mtime 比较，L95-102 的文件不存在检测）

**Source（源头）**：
T04 设计说明中承认"若 fixture 机制不可行，则至少覆盖不依赖 L3 API 的纯文件系统/逻辑测试"。实际实现确实放弃了 API fixture 方案，退化为源码级 grep 检查。

**Consequence（后果）**：
- **UAT 可执行性弱**：虽然 tests 是可脚本化的 bats，但它们不执行真实的 hook 脚本。测试通过仅证明"代码中存在某些字符串"，而非"代码在运行时正确工作"。
- **回归安全性低**：若未来有人重构 l3-review.sh（保持功能不变但改变变量命名/日志措辞），grep 测试会假阳性失败。同时，若有人引入运行时 bug（如条件分支错误），grep 测试不能捕获。
- **无法验证 end-to-end 流程**：没有测试能证明"L3 fail → gate deny → pipeline 暂停"这个完整链路。

**Remedy（修补）**：
至少增加 2 条端到端集成测试（可通过 BATS `setup` 模拟最小环境）：
1. 构造 .done 文件含 L3_verdict=fail → source independent-review-gate.sh → 验证 exit code = 2
2. 构造 .done 文件含 L3_verdict=pass → source gate.sh → 验证 exit code = 0

---

### 🟡 R4 · 回归测试声明缺乏物证

**Symptom（症状）**：
TEST.md 声称 `npx bats test/ → 439 ok / 0 fail / exit 0` 但无任何原始输出粘贴、无时间戳、无运行环境记录。本次审查中实际执行 `npx bats test/` 得到 439 tests 全通过，但 TEST.md 中的声明与本次执行之间没有可追溯的关联。

**Source（源头）**：
TEST.md 模板可能未要求粘贴原始输出。

**Consequence（后果）**：
缺乏审计可追溯性——无法确认 TEST.md 编写时的回归结果与当前代码状态一致。若未来有人质疑"TEST.md 中的回归声明是否真实执行过"，无法证实。

**Remedy（修补）**：
在 TEST.md 中添加 `npx bats test/ --formatter tap 2>&1 | tail -5` 的实际粘贴输出和时间戳。

---

### 🟢 R5 · 测试计数偏差：源码级验证声明 7 条，实际 9 条

**Symptom（症状）**：
TEST.md §1.1 测试矩阵中"源码级验证"声明 7 tests，但实际 test 文件该类别有 9 条（L237-306：append mode、.done conditional、file size warning、31-auto-advance、l3_write_timeout_done、0-change、1-requirement、2-design、3-task）。

**Source（源头）**：
计数时可能未将 0-change.md 和 l3_write_timeout_done 计入"源码级验证"类。

**Consequence（后果）**：
轻微——不影响测试有效性，但降低文档准确性，可能导致后续审计时对覆盖度产生疑问。

**Remedy（修补）**：
将 §1.1 中"7"更新为实际值（9），或重新分类。考虑到 R2 还需要新增 2-3 条，最终数字会变化。

---

### 🟢 R6 · 第 2-4 轮测试无 bats 可执行物

**Symptom（症状）**：
TEST.md 声明第 2 轮（性能）、第 3 轮（安全）、第 4 轮（兼容）状态为"⚠️ 部分"，但：
- 第 2 轮：无任何可执行的性能测试（仅文字声明 mtime stat O(1)）
- 第 3 轮：`bash -n` + `shellcheck` 作为命令行调用被记录，但不在 bats 测试矩阵内
- 第 4 轮：stat fallback 描述存在但无实际测试（无 macOS/BSD 环境下的验证）

虽然 Bash hook 脚本项目确实不需要传统性能/安全/兼容的全量测试，但每轮至少应有 1 条可脚本化的验证用例（即使仅记录 "N/A — 已论证"），以确保金字塔各轮不会在后续迭代中退化。

**Source（源头）**：
TEST.md 模板可能未强制要求每轮至少 1 条可执行测试。

**Consequence（后果）**：
若后续有人新增依赖（如加入网络调用），可能突破当前"无安全风险/无性能问题"的假设，但不会被测试捕获。

**Remedy（修补）**：
建议在第 2 轮加入 `time stat ...` 基准（验证 < 10ms），第 3 轮将 shellcheck 集成到 bats `@test` 中，第 4 轮加入 stat fallback 的便携性测试（在 Linux 上验证 `stat -f %m` 不可用时 fallback 到 `date -r`）。

---

**Verdict**: fail

---

# 独立审查 · 阶段 5（第二轮 · 2026-07-10）

## R1 / R2 修复验证

### ✅ R1 已解决 · AC-4 5-test / 6-review prompt transition jq 已加入 `.phase` 同步

**验证结果**：
- `5-test.md` L151：transition jq 现含 `.phase = "6"` -- 与 `.goal.current_phase = "6"` 一致
- `6-review.md` L202：transition jq 现含 `.phase = "7"` -- 与 `.goal.current_phase = "7"` 一致
- `GO.md`：经全文检索，该文件不含 transition jq 模板（仅有 `.flow-active` 的读取逻辑，无写入）。原 R1 remedy 建议"确认 GO.md 无 transition jq 后记录为 N/A" -- 确认为 N/A

**证据**：全部 7 个目标文件 (.phase= grep)：
```
0-change.md:       .phase = "1"  ✅
1-requirement.md:  .phase = "2"  ✅
2-design.md:       .phase = "3"  ✅
3-task.md:         .phase = "4"  ✅
5-test.md:         .phase = "6"  ✅ (本轮修复)
6-review.md:       .phase = "7"  ✅ (本轮修复)
GO.md:             无 transition jq → N/A ✅
```

### ✅ R2 已解决 · 5-test / 6-review prompt `.phase` 同步已有测试覆盖

**验证结果**：
- `test_fix_l3_gate.bats` L308-310：`@test "prompt transition jq: .phase sync in 5-test.md"` -- grep 验证 `.phase = "6"`
- `test_fix_l3_gate.bats` L313-315：`@test "prompt transition jq: .phase sync in 6-review.md"` -- grep 验证 `.phase = "7"`
- GO.md：无 transition jq，无需测试（N/A）
- 全部 6 个 prompt 文件 transition jq 的 `.phase` 同步均已由测试覆盖（L288-316，共 6 tests）

**测试执行**：`npx bats test/test_fix_l3_gate.bats` → **22 ok / 0 fail / exit 0**

---

## 本轮新增发现

### 🟡 R7 · TEST.md 指标陈旧：测试计数与实际不符

**Symptom（症状）**：
TEST.md §1.1 测试矩阵声明：
- 总测试数：**20**（实际 **22**）
- 源码级验证：**7**（实际 **11**；上一轮 R5 指出 7→9，本轮新增 5-test/6-review 后变为 11）
- 全量回归：**439**（实际 **441**；`npx bats test/ --count` 输出 441）

具体差异：

| 指标 | TEST.md 声明 | 实际值 | 偏差 |
|------|-------------|--------|------|
| 总 bats tests | 20 | 22 | -2 |
| 源码级验证 | 7 | 11 | -4 |
| test/ 全量 | 439 | 441 | -2 |

**Source（源头）**：
TEST.md 编写于第一轮审查之前，之后修复 R1/R2 新增了 2 条 prompt 测试（5-test.md、6-review.md），但 §1.1 矩阵表未同步更新。另外源码级验证从原 7 条（实际 9 条，已由 R5 指出）变为 11 条，也未更新。

**Consequence（后果）**：
审计读者看到 TEST.md 声称 20 tests 会与 bats 实际执行结果（22 ok）产生认知不一致。若基于过时的计数做覆盖率判断（如"20 tests 覆盖 5 AC = 100%"），实际额外 2 条测试的存在不会推翻结论，但降低文档可信度。

**Remedy（修补）**：
更新 TEST.md §1.1：
- 总测试数：20 → 22
- 源码级验证：7 → 11
- 全量回归：439 → 441

---

## 历史风险再评估（R3-R6 本轮状态）

### 🟡 R3（测试性质薄弱）：仍然成立

本轮新增的 2 条 prompt 测试（5-test.md、6-review.md）均为 grep-on-source 静态检查，非运行时行为验证。R3 的 critique 在量级上未恶化（新增测试的类型与已有测试一致），但也未改善。原始 remedy 建议的端到端集成测试（source gate.sh + 验证 exit code）仍未实施。

### 🟡 R4（回归测试缺乏物证）：仍然成立

TEST.md 仍未添加 `npx bats test/ --formatter tap` 的原始输出粘贴和时间戳。

### 🟢 R5（测试计数偏差）：缺口扩大，仍为 Minor

原偏差为 7→9（差 2），现偏差为 7→11（差 4）。不影响测试有效性本身，但说明文档维护滞后。建议与 R7 一并修复。

### 🟢 R6（第 2-4 轮无 bats 可执行物）：仍然成立

第二轮审查未在第 2-4 轮中新增可执行测试。

---

## AC 覆盖完整性（本轮验证）

| AC | 测试数（本轮）| 覆盖方式 | 状态 |
|----|------------|---------|------|
| AC-1 L3 重审触发 | 4 (2 fs + 2 grep) | mtime 比较 + 源码级验证 | ✅ |
| AC-2 fail 不写 .done | 2 | 文件系统 + GATE_DENY 格式 | ✅ |
| AC-3 pass 写 .done | 2 | KVP source + fail .done 无效 | ✅ |
| AC-4 phase 四字段同步 | 9 (3 jq + 6 prompt grep) | transition jq 模拟 + 全部 prompt .phase 断言 | ✅ |
| AC-5 回退放行 | 2 | 方向判定逻辑 | ✅ |

**AC 覆盖率**：5/5 (100%)

---

**Verdict**: pass
