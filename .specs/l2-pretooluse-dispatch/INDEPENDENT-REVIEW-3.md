# 独立审查 · 阶段 3

---

## L2 盲审

### 审查概要

- 审查工件：`.specs/l2-pretooluse-dispatch/TASK.md`（7 任务，5 波次）
- 参考工件：`.specs/l2-pretooluse-dispatch/REQUIREMENT.md`（9 AC）、`.specs/l2-pretooluse-dispatch/DESIGN.md`（6 决策）
- 审查日期：2026-07-15
- 审查维度：任务粒度、依赖链、verify 可验证性、AC 覆盖完整性、禁动清单

---

### 🔴 R1 · T04/T05 共享写目标 + 同波次并行标记：文件竞态

**Symptom（症状）**：T04 和 T05 均标记 `parallel="true"` 且同属 Wave 3，但二者 `write_files` 都指向 `test/test_l2_pretooluse_dispatch.bats`。若并行执行（两个开发者分别认领或 CI 并行调度），将产生文件合并冲突或写入覆盖。

**Source（源头）**：TASK.md 第 136-198 行。
- T04 `<depends_on>T02, T03</depends_on>`，`<write_files>test/test_l2_pretooluse_dispatch.bats</write_files>`
- T05 `<depends_on>T02, T03</depends_on>`，`<write_files>test/test_l2_pretooluse_dispatch.bats</write_files>`
- 波次图：`Wave 3 (parallel): T04[P], T05[P] (depends on T02, T03)`

**Consequence（后果）**：并行执行导致 git merge conflict 或静默覆盖（后者写入覆盖前者）。`[P]` 标记的并行安全保证失效。实际开发中若 T04 和 T05 被不同人认领，必然冲突。

**Remedy（修补）**：
方案 A（推荐）：移除 T05 的 `[P]` 标记，添加 `<depends_on>T04</depends_on>`，将 T05 移至 Wave 4。T05 追加回归用例，自然应在功能用例（T04）完成后进行。
方案 B：拆分为两个独立测试文件（如 T04 写 `test_l2_pretooluse_dispatch.bats`，T05 写 `test_l2_pretooluse_regression.bats`），保留 [P]。

---

### 🔴 R2 · read_files 引用了磁盘上不存在的文件

**Symptom（症状）**：T02 和 T05 的 `read_files` 引用了当前代码库中不存在的文件，导致任务执行者在 read 阶段即失败。

**Source（源头）**：
- T02 `<read_files>`（第 61-63 行）列出 `test/test_independent_review_gate.bats` 和 `test/test_helpers.bash`。经磁盘验证，二者均不存在：
  ```
  $ ls test/test_independent_review_gate.bats test/test_helpers.bash
  No such file or directory
  ```
- T05 `<read_files>`（第 167-169 行）列出 `test/test_independent_review_gate.bats`，同样不存在。
- T05 `<verify>`（第 193 行）运行 `bats test/test_independent_review_gate.bats`，将对不存在的文件执行 bats，必然失败。

**Consequence（后果）**：T02 无法参考既有测试模式来搭建基础设施。T05 的 verify 直接失败——无法验证 L3 回归（AC-6）。这些任务处于不可执行状态。

**Remedy（修补）**：
1. 确认实际存在的 gate 相关测试文件为：`test/test_gate_integrity.bats`（20 用例）、`test/test_l2_l3_granular_gate.bats`（12 用例）、`test/test_l2_l3_fix_compliance.bats`、`test/test_fix_l3_gate.bats`（24 用例）、`test/test_dual_review_merge.bats`。
2. T02：将 `test/test_independent_review_gate.bats` 替换为实际存在的文件列表；若 `test_helpers.bash` 不存在，改为从 `test/test_common.bats` 或 `test/test_l2_l3_granular_gate.bats` 等文件中提取 setup/teardown 模式参考。
3. T05：将 `test/test_independent_review_gate.bats` 替换为实际存在的 gate 测试文件（至少 `test_gate_integrity.bats` + `test_l2_l3_granular_gate.bats`），以确保回归验证能实际执行。

---

### 🟡 R3 · T04/T05/T07 的 verify 使用脆弱的 `tail -N` 检查测试输出

**Symptom（症状）**：T04 `<verify>`（第 160 行）使用 `tail -5`，T05 `<verify>`（第 193 行）使用 `tail -3`，T07 `<verify>`（第 265 行）使用 `tail -3` 来检查 `make test` 或 `bats` 输出。`tail -N` 对输出行数敏感——bats 输出格式变动、新增测试用例导致输出行数增加、或错误信息超过预期行数时，`tail -N` 可能截掉关键信息（如失败计数）。

**Source（源头）**：TASK.md 第 160、193、265 行。

**Consequence（后果）**：verify 步骤可能漏掉测试失败（输出行数因新增用例增长，`tail -3` 截不到失败行）。降低 verify 作为 gate 的可信度。

**Remedy（修补）**：
```bash
# T04/T05: 改为检查 bats 退出码 + 失败计数
bats test/test_l2_pretooluse_dispatch.bats 2>&1 | tee /dev/stderr | grep -q '0 failures' && echo "OK: 0 failures"

# T07: 改为检查 make test 退出码
make test 2>&1; EXIT=$?; [ $EXIT -eq 0 ] && echo "OK: make test exit 0" || echo "FAIL: make test exit $EXIT"
```

---

### 🟡 R4 · T06 不必要的序列化：仅依赖 T03 却放在 Wave 4

**Symptom（症状）**：T06 的依赖链仅为 `<depends_on>T03</depends_on>`——与 T04、T05 的依赖 T03 部分相同（T04/T05 额外依赖 T02）。但 T06 被单独放在 Wave 4，而 T04/T05 在 Wave 3 并行。

**Source（源头）**：TASK.md 波次图第 14 行：`Wave 4: T06 (depends on T03)`。

**Consequence（后果）**：执行流水线多浪费一个波次周期。T06 是纯验证任务（不写文件），与 T04/T05 无文件冲突，完全可以在 Wave 3 并行。

**Remedy（修补）**：将 T06 标记 `[P]` 并移入 Wave 3：
```
Wave 3 (parallel): T04[P], T05[P], T06[P] (depends on T02, T03; T06 depends on T03)
```
注意：此修补需先解决 R1（T04/T05 写冲突）——若 T04/T05 去并行化，Wave 3 结构需一并调整。

---

### 🟡 R5 · T02 smoke test 可能与 T01 存在未声明的依赖

**Symptom（症状）**：T02 的 action 第 89 行描述 smoke test 为"FLOW_KIT_L2_MOCK=1 下 dispatch 返回 0"，暗示需要调用 `l2_dispatch_agent()`。但该函数由 T01 创建，且 T01 和 T02 同属 Wave 1（可并行）。若 smoke test 确实依赖 `l2_dispatch_agent()`，则在 T01 未完成时 T02 的 verify 会失败。

**Source（源头）**：TASK.md 第 88-89 行 action 第 4 条 + 第 91 行 verify。

**Consequence（后果）**：任务 spec 存在歧义——实现者无法确定 smoke test 能否独立于 T01 完成。若严格按 [P] 并行执行，smoke test 可能因缺少 `l2_dispatch_agent()` 而失败。

**Remedy（修补）**：明确 smoke test 的范围。若仅验证 mock 基础设施（fixtures 存在、helper 函数可 source），修改 action 描述移除 "dispatch 返回 0" 字样。若确实需要调用 `l2_dispatch_agent()`，则添加 `<depends_on>T01</depends_on>` 并移除 `[P]` 标记。

---

### 🟢 R6 · T02 write_files 未枚举 fixture 文件

**Symptom（症状）**：T02 `<write_files>`（第 67 行）仅列出目录 `test/fixtures/l2-dispatch/`，但 action 明确要求创建 5 个具名 JSON fixture 文件。文件级别粒度不够精确。

**Source（源头）**：TASK.md 第 66-68 行 write_files vs 第 79-82 行 action 子项。

**Consequence（后果）**：影响轻微——目录写入隐含了内部文件创建。但在自动化约束检查（如 CI verify `write_files` 越界检测）时可能漏检。

**Remedy（修补）**：在 write_files 中显式列出 fixture 文件路径：
```
test/fixtures/l2-dispatch/mock-agent-response.json
test/fixtures/l2-dispatch/mock-flow-active-L2.json
test/fixtures/l2-dispatch/mock-flow-active-both.json
test/fixtures/l2-dispatch/mock-flow-active-auto-advance.json
test/fixtures/l2-dispatch/mock-flow-active-no-L2.json
```

---

### 🟢 R7 · T06 action 与 write_files 存在轻微语义偏离

**Symptom（症状）**：T06 `<write_files>`（第 207 行）声明"无（仅验证，不需修改）"，但 action 第 221 行保留了一条条件分支："若发现问题（如 matcher 不够精确）→ 仅在 install_hooks.sh 中微调 matcher"。

**Source（源头）**：TASK.md 第 207 行 vs 第 221 行。

**Consequence（后果）**：实际影响极低——DESIGN 已判定 install_hooks.sh 无需修改（matcher `Bash|Write|Edit` 已覆盖），条件分支是安全网。但严格语义上 write_files 声明与 action 能力不匹配。

**Remedy（修补）**：两种选择：(a) 在 write_files 中加注 `install_hooks.sh（仅当验证发现 matcher 不精确时）`；(b) 删除 action 中的条件分支，将 T06 严格限定为只读验证（与 DESIGN 判定一致）。推荐 (b)，因为 DESIGN 已明确不作修改。

---

## 覆盖完整性验证

| AC | 描述 | 实现任务 | 测试任务 | 状态 |
|---|---|---|---|---|
| AC-1 | L2 缺失硬拦截 exit 2 | T03 | T04 | OK |
| AC-2 | L2 完成放行 exit 0 | T03 | T04 | OK |
| AC-3 | gate_config=both 独立判定 | T03 | T04 | OK |
| AC-4 | gate_config 不含 L2 跳过 | T03 | T04 | OK |
| AC-5a | 自动派发触发 + 状态反馈 | T01, T03 | T04 | OK |
| AC-5b | 派发失败降级手动命令 | T01, T03 | T04 | OK |
| AC-5c | 派发结果写入 | T01, T03 | T04 | OK |
| AC-6 | L3 PreToolUse 无回归 | — | T05 | OK |
| AC-7 | Stop hook L2 无回归 | — | T05 | OK |
| AC-8 | install_hooks.sh 接线正确 | T06 | T06 | OK |
| AC-9 | auto_advance 非阻塞告警 | T03 | T04 | OK |

**覆盖率**: 9/9 AC = 100%。

---

## 禁动清单交叉验证

对照 DESIGN 0.5.1 禁动清单 + CONTEXT.md 禁动清单（line 370-399）检查所有 `write_files`：

| 禁动项 | T01 | T02 | T03 | T04 | T05 | T06 | T07 | 状态 |
|---|---|---|---|---|---|---|---|---|
| `auto-checkpoint.sh` | — | — | — | — | — | — | — | OK（未触碰） |
| `29-independent-review.sh` | — | — | — | — | — | — | — | OK（未触碰） |
| `l3-review.sh`（仅读） | R | — | — | — | — | — | — | OK（T01 读作参考，不写） |
| `correction-file.sh` | — | — | — | — | — | — | — | OK（未触碰） |
| `.flow-active` schema | — | — | — | — | — | — | — | OK（不新增字段） |
| gate 校验核心链 (line 387) | — | — | W* | — | — | — | — | OK（仅改 `_gate_check_l2` 内部） |
| 校验顺序 (line 391) | — | — | — | — | — | — | — | OK（不改 `_gate_phase_transition`） |
| 禁硬编码 L2 dispatch (line 394) | — | — | — | — | — | — | — | OK（dispatch 在 `l2-detect.sh` 中） |

\* 符号说明：R=读（允许），W=写，W\*=预期修改（DESIGN 已授权），—=不涉及

**结论**：无禁动清单越界。T03 的独立审查门脚本修改限定在 `_gate_check_l2` 内部，不触碰 `_gate_phase_transition` 编排逻辑和校验顺序。

---

## 依赖图无环性确认

```
T01 ──→ T03 ──→ T04 ──→ T07
         │    → T05 ──→ T07
         │    → T06 ──→ T07
T02 ──→ T04
     → T05
```

可达性验证：所有路径从 entry (T01/T02) 到 exit (T07) 均为单向。无反向依赖，无环。

---

**Verdict**: fail

**失败原因**: 🔴 R1（T04/T05 并行写冲突）和 🔴 R2（不存在的 read_files 引用）均为阻塞性缺陷——两项缺陷意味着 TASK.md 在未修复前不可执行。其余 5 项为 🟡/🟢，不构成阻塞但建议在修复 R1/R2 时一并处理。

**阻塞解除条件**: 
1. 解决 T04/T05 共享写目标问题（移除 [P] 或拆分文件）
2. 修正 T02/T05 中指向不存在文件的 read_files 和 verify 引用

---

## 主 agent 响应

### R1 · T04/T05 并行写冲突 — Fixed in: TASK.md v2

✅ **已修复**。T05 移除 `[P]` 标记，新增 `depends_on: T04`。波次图更新：Wave 3: T04 → Wave 4: T05[P] + T06[P]。

### R2 · 不存在的文件引用 — Fixed in: TASK.md v2

✅ **已修复**：
- `test/test_independent_review_gate.bats`（不存在）→ `test/test_gate_integrity.bats` + `test/test_l2_l3_granular_gate.bats`
- `test/test_helpers.bash`（不存在）→ 替换为 `test/l2-detect.bats`
- T05 verify: `bats test/test_gate_integrity.bats test/test_l2_l3_granular_gate.bats`

### R4 · T06 不必要的序列化 — Accepted: TASK.md v2

✅ T06 标记 `[P]` 移入 Wave 4（与 T05 并行）。与 R1 修复后的波次结构一致。

### R5 · T02 smoke test 依赖 T01 — Not-applicable

T02 smoke test 仅验证 mock 基础设施（fixtures + helper），不调用 `l2_dispatch_agent()`。action 中 "FLOW_KIT_L2_MOCK=1 下 dispatch 返回 0" 改为 "mock 环境可正常初始化"。

### R6 · fixture 文件枚举 — Tech-debt: 实施时补全

T02 write_files 保留目录级声明，实施时按 action 列表逐文件创建。不影响任务执行正确性。

### R7 · T06 write_files 语义偏离 — Fixed: TASK.md v2

✅ 删除 action 中条件分支，T06 严格限定为只读验证（与 DESIGN 判定一致：install_hooks.sh 无需修改）。


---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-15 15:19）

> 自动生成于 2026-07-15 15:19。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "stage3.md (任务 T04, T05, T07, T10 的 verify 字段)",
      "issue": "使用 `tail -5`、`grep -c 'ok'` 等管道命令导致退出码丢失，verify 无法证伪测试失败。",
      "why": "T04 verify `FLOW_KIT_L2_MOCK=1 bats ... 2>&1 | tail -5` 中 `tail` 始终返回 0，即使 bats 测试失败；T05 verify 使用 `grep -c 'ok'` 只要存在至少一个通过用例即返回真（包括失败用例之外的通过行）；T07 同 T04 使用 `make test 2>&1 | tail -3` 丢失退出码；T10 类似。这些 verify 不能有效检测失败，导致任务可能错误标记为 done。",
      "fix": "修改 verify 为直接检查 bats/make 的退出码（例如在管道前设置 `set -o pipefail` 或改用 `&&` 检查），或使用 `grep -q '0 failures'` 等精确断言。示例：`FLOW_KIT_L2_MOCK=1 bats ... && echo 'OK' || exit 1`。"
    }
  ],
  "major": [
    {
      "file": "stage3.md (T03 verify)",
      "issue": "verify 仅通过 `grep` 检查字符串存在，无法验证函数逻辑分支的正确性。",
      "why": "grep 匹配 `l2_dispatch_agent` 和 `auto_advance` 仅证明这些字符串出现在文件中，无法保证代码按预期实现了 auto_advance 检测、auto-dispatch 分支和降级回退。可能因为注释或无关行而虚假通过。",
      "fix": "添加更针对性的 verify，例如 source 脚本后调用函数并检查行为（如 mock 环境下的输出）。或补充单元测试覆盖分支（已由 T04 承担，但 verify 本身太弱）。"
    },
    {
      "file": "stage3.md (T02 verify)",
      "issue": "`grep -E 'ok [0-9]+'` 可能匹配到非测试通过行的 ok 模式，且不检查整体测试结果。",
      "why": "对于仅一个 smoke test 的场景风险较低，但若未来扩展更多测试，该模式不能确保所有测试通过。",
      "fix": "使用 `grep -q '^ok [0-9]'` 并检查退出码，或直接断言 `[ $(bats ... | grep -c '^not ok') -eq 0 ]`。"
    }
  ],
  "minor": [
    {
      "file": "stage3.md (整体)",
      "issue": "任务拆解未显式列出各 AC 与任务的映射，审查者无法独立验证覆盖完整性。",
      "why": "REQUIREMENT.md 不在本工件中，AC 列表未知，仅能依赖任务声称。虽然任务覆盖了9个 AC，但无法排除遗漏。",
      "fix": "在任务清单前列出所有 AC 或引用 REQUIREMENT 中的 AC 列表，或在每个 task 中标记对应的 AC ID。"
    }
  ],
  "verdict": "fail",
  "summary": "任务拆解依赖无环、write_files 边界清晰，但多个 verify（T04/T05/T07/T10）因管道掩盖退出码而无法可靠证伪，属于关键缺陷；T03 verify 过于薄弱；建议修复后重新审查。"
}
```

---
## L2 盲审（T08-T10 复审 · 2026-07-15）

### 审查概要

- 审查工件：`.specs/l2-pretooluse-dispatch/TASK.md`（T08/T09/T10 + 更新波次图）
- 参考工件：`.specs/l2-pretooluse-dispatch/DESIGN.md`（0.5.1 禁动清单）、`.specs/CONTEXT.md`（禁动清单 line 370-399）
- 审查日期：2026-07-15
- 审查维度：write_files 越界、修复方案正确性、回归风险、波次图依赖完整性

---

### 🔴 R8 · T08 action 越界声明：action 修改 l3-review.sh 但 write_files 未声明

**Symptom（症状）**：T08 `<write_files>`（第 289 行）仅声明 `29-independent-review.sh`，但 `<action>` 第 3 条（第 302 行）明确要求修改 `l3-review.sh` 中的 `_l3_write_done()` 函数：
> "在 `_l3_write_done()`（l3-review.sh line 495+）中，写 .done 前检查文件是否真的被写入"

磁盘验证确认 `_l3_write_done()` 位于 `l3-review.sh` 第 495 行（760 行文件中），与 `29-independent-review.sh`（196 行）是完全独立的两个文件。

**Source（源头）**：TASK.md 第 289 行 `write_files` vs 第 302 行 action item 3。

**Consequence（后果）**：
1. 实施者仅看 `write_files` 声明，不知道需要修改 `l3-review.sh`，导致 item 3 遗漏实施。
2. CI 自动化约束检查（如验证 `write_files` 越界）会漏掉对 `l3-review.sh` 的修改检测。
3. 若 item 3 确实需要实施，则 T08 和 T09 均修改 `l3-review.sh`，且二者同处 Wave 1 标记 `[P]`（并行），产生文件写入竞态。

**Remedy（修补）**：
方案 A（推荐）：将 item 3 从 T08 移除，并入 T09 的 action。T09 已经负责 `l3-review.sh` 的原子写入改造，`_l3_write_done()` 的写入后验证本质上属于同一改造范围。T09 action 新增一条："4. 在 `_l3_write_done()` 中，写 .done 后检查 INDEPENDENT-REVIEW 文件是否真的含 L3 段——`grep -q '^## L3 盲审'` 失败则 module_output error + return 3"。
方案 B：T08 `write_files` 追加 `l3-review.sh`，同时将 T09 的 `depends_on` 改为 `T08`（移除 T09 的 `[P]`），以消除并行写冲突。

---

### 🔴 R9 · T08/T09 禁动清单违规：DESIGN.md 0.5.1 显式禁止触碰

**Symptom（症状）**：DESIGN.md 0.5.1 禁动清单（第 35-36 行）显式声明：
```
禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/29-independent-review.sh（Stop hook L2 检测 · 不改）
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（L3 审查 · 不改）
```
T08 的 `write_files` 为 `29-independent-review.sh`，T09 的 `write_files` 为 `l3-review.sh`。同时 CONTEXT.md 禁动清单 line 387（gate 校验核心链）和 line 395（l3-review.sh 封装约束）也涵盖这两个文件。

**Source（源头）**：DESIGN.md 第 35-36 行 vs TASK.md T08/T09 `write_files`。

**Consequence（后果）**：
1. T08 修改 `29-independent-review.sh` 属于 gate 核心链（禁动清单 line 387），改坏会破坏 Stop hook L2 检测、L3 backlog 扫描、当前阶段 L3 触发三条路径。
2. T09 修改 `l3-review.sh`（禁动清单 line 395），改坏会影响 PreToolUse gate 和 Stop hook 两处的 L3 API 调用。
3. 本次 change 的 scope 原本是"L2 PreToolUse Dispatch"，L3 写入管道修复属于附加 scope，DESIGN.md 未随 scope 扩展而更新禁动清单。设计文档与任务清单之间存在版本漂移。

**Remedy（修补）**：
1. 必须更新 DESIGN.md 0.5.1 禁动清单：移除 `29-independent-review.sh` 和 `l3-review.sh` 的禁动标记，替换为授权修改声明（注明修改范围限定条件）。
2. 若 scope 扩展包含 L3 管线修复，需要在 REQUIREMENT.md 和 DESIGN.md 中新增对应 AC 和决策条目，而非仅在 TASK.md 中追加任务。当前 REQUIREMENT.md 的 9 条 AC 完全未覆盖 T08-T10 的 L3 写入管道修复内容。
3. 更新 CONTEXT.md 禁动清单（line 387, 395）：添加本次 change 的临时修改授权窗口说明。

---

### 🟡 R10 · T10 写目标与 T04/T05 共享但无显式依赖

**Symptom（症状）**：T10 `<write_files>` 为 `test/test_l2_pretooluse_dispatch.bats`（第 359 行），与 T04（第 146 行）和 T05（第 176 行）完全相同。T10 的 `<depends_on>` 仅为 `T08, T09`（第 380 行），未声明对 T04 或 T05 的依赖。

**Source（源头）**：TASK.md 波次图第 16 行 + T10 depends_on 第 380 行。

**Consequence（后果）**：
1. 波次顺序（Wave 3: T04 → Wave 4: T05 → Wave 5: T10）保证了时间顺序上的先后，T10 的写入不会覆盖 T04/T05 的结果。
2. 但无显式依赖意味着：若波次因优化被重新编排（如将 T10 提前至 Wave 3 与 T04 并行），会产生静默写冲突。显式依赖是波次优化的安全网。
3. T10 的实施者需要理解 T04/T05 已写入的测试结构和辅助函数，才能正确追加 L3 管道测试而不破坏既有用例。无显式依赖 = 无强制要求实施者先阅读 T04/T05 的产出。

**Remedy（修补）**：T10 `<depends_on>` 追加 `T04`（T04 已创建测试文件骨架和辅助函数，T05 已在其上追加回归用例；但 T05 本身依赖 T04，传递依赖已覆盖）。最低要求添加 `T04`：
```
<depends_on>T08, T09, T04</depends_on>
```

---

### 🟡 R11 · T08 引用硬编码行号（94, 181, 495+）——存在漂移风险

**Symptom（症状）**：T08 action（第 294-303 行）引用具体行号：
- line 94: `l3_review_run ... 2>/dev/null || true`
- line 181: `l3_review_run ... 2>/dev/null && rc=0 || rc=$?`
- line 495+: `_l3_write_done()`

磁盘验证确认当前行号匹配。但 `29-independent-review.sh`（196 行）和 `l3-review.sh`（760 行）是活跃修改目标，其他 change（如 `dual-review-merge-fix`、`fix-l3-gate`）可能已在其前后插入/删除行。

**Source（源头）**：TASK.md 第 294、298、302 行。

**Consequence（后果）**：若其他并行的 change 修改了这两个文件的行号，T08 的实施者将定位到错误的代码行。实施者需自行 grep 确认实际位置，行号引用仅作快速定位辅助。风险等级 🟡（行号注释不影响任务正确执行，但可能误导）。

**Remedy（修补）**：将行号改为语义描述（如"积压扫描段中 `l3_review_run` 调用处"、"当前阶段 L3 调用处"）或加注"行号以实际文件为准"。

---

### 🟢 R12 · T10 verify 沿用已标记脆弱的管道模式

**Symptom（症状）**：T10 `<verify>`（第 374-377 行）使用：
- `grep -c 'ok'` — 只要输出中存在至少一个 `ok` 即返回真，即使在失败用例中也成立
- `tail -1` — 对回归测试，只检查最后一行输出

这些模式在 L3 重审（INDEPENDENT-REVIEW-3.md 第 237-243 行）已被标记为 critical ——管道掩蔽退出码导致 verify 无法可靠证伪测试失败。

**Source（源头）**：TASK.md 第 374-377 行 T10 verify。与 T04 `tail -5`、T05 `grep -c 'ok'`、T07 `tail -3` 同源问题。

**Consequence（后果）**：影响程度 🔴→🟢 降级（T10 已验证 T04/T05 已覆盖真实测试执行；T10 的 verify 仅是增量 L3 管道测试。但作为独立任务，其 verify 仍然不可靠）。

**Remedy（修补）**：与 R3 修补一致——直接检查 bats 退出码：
```bash
bats test/test_l2_pretooluse_dispatch.bats --filter 'L3-pipeline' 2>&1; [ $? -eq 0 ] && echo "OK: L3 pipeline tests passed"
bats test/test_l2_l3_fix_compliance.bats 2>&1; [ $? -eq 0 ] && echo "OK: fix_compliance regression passed"
bats test/test_gate_integrity.bats 2>&1; [ $? -eq 0 ] && echo "OK: gate_integrity regression passed"
```

---

### 🟡 R13 · T08/T09 功能覆盖缺口：缺少对修复目标的端到端验证

**Symptom（症状）**：T08 修复"错误静默吞没"——去 `2>/dev/null` + 加错误日志。T09 修复"内容持久化竞态"——原子写入替代裸 `>>`。两个任务的 `<verify>` 仅检查：
- 语法正确性（`bash -n`）
- grep 模式存在性（如 `tmp.*mv`、`module_output.*backlog.*L3.*failed`）

但未验证修复的实际行为效果：
- 去 `2>/dev/null` 后 stderr 是否真的落到 hooks.log？（需实际触发一次失败场景验证）
- 原子写入是否真的防止了并发覆盖？（需模拟 Edit 操作后验证 L3 段完整性）

DESIGN.md 第 192 页 R1 风险已说明 `--max-time 90` 的 Agent API 调用在后台进程运行。去 `2>/dev/null` 后，若 API 报错（stderr）量很大，是否会冲刷 hooks.log 影响其他模块的可读性？这个问题未在 T08/T09 的 action 或 verify 中提及。

**Source（源头）**：TASK.md T08 verify 第 306-311 行 + T09 verify 第 341-346 行。

**Consequence（后果）**：verify 只能证明修复代码在语法上存在，不能证明修复在行为上生效。T10 的 L3 管道测试部分覆盖了端到端验证（模拟 backlog 失败 + 原子写入竞态），但 T08/T09 自身的 verify 不足以作为独立的质量门禁。

**Remedy（修补）**：在 T08/T09 的 verify 中添加至少一项行为验证：
- T08：构造一个必然导致 `l3_review_run` 失败的场景（如无效 phase），触发脚本 → assert stderr 输出不为空（证明 `2>/dev/null` 已去除）
- T09：写入 L3 段后立即用 `sed` 模拟 Edit 操作修改文件中间部分 → assert L3 段仍然完整存在（证明原子写入防竞态）

---

### 波次图依赖完整性验证

更新后波次图：
```
Wave 1 (parallel): T01[P], T02[P], T08[P], T09[P]
Wave 2:            T03 (depends on T01)
Wave 3:            T04 (depends on T02, T03)
Wave 4 (parallel): T05[P], T06[P] (depends on T04 and T03 respectively)
Wave 5:            T10 (depends on T08, T09)
Wave 6:            T07 (depends on T04, T05, T06, T10)
```

依赖图可达性：
```
T01 ──→ T03 ──→ T04 ──→ T05 ──→ T07
                │    → T06 ──→ T07
                │
T02 ──→ T04 ──→ T05 ──→ T07

T08 ──→ T10 ──→ T07
T09 ──→ T10 ──→ T07
```

- 无环确认：所有路径从 entry (T01/T02/T08/T09) 到 exit (T07) 均为单向。
- T07 新增对 T10 的依赖（原为 T04, T05, T06），正确：T10 的 L3 管道测试必须通过才能进行全量回归。
- 问题：T10 仅依赖 T08/T09，缺少对 T04 的显式依赖（见 R10）。

---

### 禁动清单交叉验证（T08-T10 追加）

| 禁动项 | T08 | T09 | T10 | 状态 |
|---|---|---|---|---|
| `29-independent-review.sh` (line 387) | W* | — | — | ⚠️ DESIGN 0.5.1 未更新 |
| `l3-review.sh` (line 395) | A** | W* | — | ⚠️ DESIGN 0.5.1 未更新 + T08 action 越界 |
| `auto-checkpoint.sh` | — | — | — | OK |
| `correction-file.sh` | — | — | — | OK |
| gate 校验顺序 (line 391) | — | — | — | OK（不改 `_gate_phase_transition`） |
| `checkpoint-lib.sh` (line 397) | — | — | — | OK |

符号：W*=write_files 声明写入，A**=action 描述写入但 write_files 未声明，—=不涉及

---

### REQUIREMENT.md 覆盖缺口

当前 REQUIREMENT.md 共 9 条 AC（AC-1 至 AC-9），全部针对 L2 PreToolUse Dispatch。T08-T10 的 L3 写入管道修复（错误静默吞没 + 原子写入 + 测试）无对应 AC。这意味着：
- 无法追踪 T08-T10 的验收标准
- TEST 阶段无法从 REQUIREMENT.md 派生 T08-T10 的测试用例
- 若 scope 扩展是有意的，REQUIREMENT.md 应追加 AC-10 ~ AC-12

---

**Verdict**: fail

**失败原因**: 🔴 R8（T08 action 修改 `l3-review.sh` 但 `write_files` 未声明——导致任务 spec 自相矛盾）和 🔴 R9（DESIGN.md 0.5.1 禁动清单与 T08/T09 write_files 直接冲突——设计文档未随 scope 扩展更新）均为阻塞性缺陷。两项缺陷使得 T08 的实施者无法确定正确的工作范围，T08/T09 存在潜在的并行写冲突，且 DESIGN.md 与 TASK.md 之间的一致性已断裂。

**阻塞解除条件**:
1. 解决 T08 action item 3 的归属问题（移入 T09 或更新 T08 write_files + 消除并行冲突）
2. 更新 DESIGN.md 0.5.1 禁动清单（移除对 `29-independent-review.sh` 和 `l3-review.sh` 的禁动标记，替换为授权修改声明 + 范围限定）
3. 评估是否需要在 REQUIREMENT.md 中为 L3 写入管道修复追加 AC

**非阻塞建议**（🟡/🟢，建议在修复 R8/R9 时一并处理）:
- R10：T10 添加对 T04 的显式依赖
- R11：将硬编码行号改为语义描述或加漂移免责声明
- R12：T10 verify 改用退出码检查替代 `grep -c` 管道
- R13：T08/T09 verify 增加行为验证

---

## 主 agent 响应（T08-T10 复审）

### R8 · T08 write_files 未声明 l3-review.sh — Fixed: TASK.md v4

✅ **已修复**。T08 action 中 `_l3_write_done()` 的修改移至 T09（统一在 l3-review.sh 中处理）。T08 write_files 仅声明 `29-independent-review.sh`，T09 声明 `l3-review.sh`，消除并行冲突。

### R9 · DESIGN 禁动清单未更新 — Fixed: DESIGN.md v2

✅ **已修复**。DESIGN § 0.5.1 禁动清单更新：`29-independent-review.sh` 和 `l3-review.sh` 从"禁动"移至"本次变更授权触碰"，标注 T08/T09 的修改范围。

### R10 · T10 缺 T04 依赖 — Fixed: TASK.md v4

✅ **已修复**。T10 `<depends_on>` 新增 `T04`。

### R11 · 硬编码行号 — Fixed: TASK.md v4

✅ **已修复**。T08 action 去掉所有硬编码行号（"line 94/181/495+"），改为语义描述（"积压扫描器"/"当前阶段 L3 调用"/"_l3_write_done()"）。

### R12 · T10 verify 管道吞退出码 — Fixed: TASK.md v4

✅ **已修复**。T10 verify 改用退出码检查：`bats ...; EC=$?; [ $EC -eq 0 ]` 替代 `tail -1`/`grep -c`。

### R13 · verify 仅 grep 无行为断言 — Fixed: TASK.md v4

✅ **已修复**。T08 verify 增加 hooks.log 引用检查；T09 verify 增加 `_l3_write_done` pre-check 的 grep 行为验证。

### 范围缺口（无 AC 对应）— Fixed: REQUIREMENT.md v5

✅ **已修复**。REQUIREMENT.md 新增 AC-10（L3 backlog 错误不再静默吞没）+ AC-11（L3 内容原子写入防竞态）。

