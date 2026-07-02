# 独立审查 · 阶段 1

## L2 盲审

### 🔴 R1 · AC-7 验证覆盖不完整：Then 承诺三项行为，验证仅检查 .done 文件

**Symptom（症状）**：AC-7（`REQUIREMENT.md:70-73`）的 Then 子句要求主 agent "(1) 调 L2 子 agent、(2) 产出 INDEPENDENT-REVIEW-{3,5,7}.md 的 L2 段、(3) 写 .done 标记"，但 验证 仅检查 `.independent-review-3.done` 等 done 文件是否可合法写入。验证未覆盖行为(1)和(2)。

**Source（源头）**：审查 checklist 第一条——"每条 AC 是否 Given/When/Then 三段齐全且可机器验证"；要求验证与 Then 承诺的行为一一对应，不可缩水。

**Consequence（后果）**：实现者可以满足验证（只写 .done 空文件）而标记 AC-7 通过，但实际 L2 独立审查从未运行，pipeline 不会死锁但审查形同虚设——安全假象。一旦上线，所有 3/5/7 阶段的独立审查均为空气。

**Remedy（修补）**：验证改为最少两项：(a) 验证 `INDEPENDENT-REVIEW-{3,5,7}.md` 文件存在且包含 L2 盲审段内容；(b) 验证 `.independent-review-{3,5,7}.done` 文件存在。建议：
```
**验证**: (1) `test -f .specs/<change-id>/INDEPENDENT-REVIEW-3.md` && grep -q "Verdict" .specs/<change-id>/INDEPENDENT-REVIEW-3.md; (2) `test -f .independent-review-3.done`。5/7 同理。
```

---

### 🔴 R2 · AC-7 验证方法不可机器化：手工模拟作为唯一验证手段

**Symptom（症状）**：AC-7（`REQUIREMENT.md:73`）验证写为 "手工模拟验证（脚本辅助），检查...可被合法写入"。短语 "手工模拟验证" 明确表达该 AC 无法自动化。

**Source（源头）**：审查 checklist 第一条——AC 必须 "可机器验证"（拒绝空话）。"手工模拟" 等于承认该 AC 没有客观的、可重复的 pass/fail 标准。

**Consequence（后果）**：CI/CD 流水线永远无法自动验证 AC-7。每次发版需人工介入模拟，耗时且不可靠。随着变更叠加，人工模拟成本线性增长，最终被跳过，形成回归盲区。

**Remedy（修补）**：将验证提炼为可脚本化的端到端测试。例如：bats 测试用例在 dry-run fixture 中模拟 pipeline 推进经过 3/5/7，然后用文件存在性断言和内容断言替换 "手工模拟"。设计参考 AC-6 的 bats 验证模式。

---

### 🟡 R3 · AC-4 验证仅检查标题数量，不检查内容质量

**Symptom（症状）**：AC-4（`REQUIREMENT.md:50`）Then 子句要求阶段 3 审查 "任务粒度/依赖/verify 可验证性"，阶段 5 审查 "测试矩阵完整性/覆盖率/5 轮金字塔"，阶段 7 审查 "归档完整性/LESSONS 同步/CHANGELOG 更新"，但验证仅做 `grep -c "### 阶段 [357]" ...` = 3，即只数标题。

**Source（源头）**：审查 checklist 第一条——验证必须对应 AC 的实质要求，不能降级为表面文本匹配。

**Consequence（后果）**：实现者写三个空标题即可通过验证。L2 子 agent 被调用时拿到空 checklist，审查无实质内容，等于没审。

**Remedy（修补）**：改造验证为内容存在性检查，例如：
```bash
for phase in 3 5 7; do
  section=$(sed -n "/### 阶段 $phase/,/### 阶段/p" L2-blind-review.md)
  [ $(echo "$section" | grep -c "^- \*\*" ) -ge 3 ] || fail "阶段 $phase checklist 条目不足"
done
```
至少确保每个阶段有 >=3 条具体审查条目。

---

### 🟡 R4 · AC-1 验证与 Then 行为不对应

**Symptom（症状）**：AC-1（`REQUIREMENT.md:13-18`）Then 子句描述主 agent 运行时的 4 种行为（检测 gate_config、调度 L2、L3 自动处理、写 done 标记），但验证仅做文件级 grep 检查 prompt 模板中包含 "独立 review 调度" 字符串。

**Source（源头）**：审查 checklist 第一条——验证应对应 AC 声明的行为（behavioral assertion），而非实现细节（file content assertion）。

**Consequence（后果）**：真正的行为缺陷（prompt 有调度段但主 agent 忽略了、L2 子 agent 调了但参数错误、done 文件路径不对）无法被 AC 验证捕获。验证通过不代表功能正确。

**Remedy（修补）**：拆分验证：(a) 静态检查——prompt 文件含必需段落（保留现有 grep）；(b) 行为检查——dry-run 模拟验证主 agent 在执行阶段时确实触发了 L2 调度流程。或降低 AC-1 的 Then 承诺范围，使之与验证对齐。

---

### 🟡 R5 · 安全 NFR 标注 "无" 但场景涉及文件写入

**Symptom（症状）**：非功能性需求（`REQUIREMENT.md:101`）安全性条目写 "无"。

**Source（源头）**：NFR 审查要求——涉及文件系统写入和进程调度的变更，安全性评估为必要项，不能跳票。

**Consequence（后果）**：以下安全面被忽略：
- `.done` 文件的写入路径可能被符号链接攻击指向任意位置
- `L2-blind-review.md` 子 agent 指令注入风险（prompt 拼接时是否做了 escaping？）
- 子 agent 调用的进程隔离边界（子 agent 能否访问父 agent 的文件系统上下文？）

**Remedy（修补）**：替换 "无" 为具体安全评估，至少覆盖上述三点，并标记 "本次变更不引入新的攻击面" 或 "风险已由 hook 层沙箱覆盖" 等具体结论，而非空手跳过。

---

### 🟡 R6 · 缺失错误处理/容错 NFR

**Symptom（症状）**：REQUIREMENT.md 未定义以下失败场景的预期行为：
- L2 子 agent 调用失败（超时 / API error / 返回空内容）时，.done 文件是否仍写入？
- .done 文件写入失败（磁盘满 / 权限不足）时，pipeline 行为是什么？
- 独立审查结果为 fail 时，pipeline 是否应该阻塞？

**Source（源头）**：NFR 审查——错误处理语义是任何一个涉及多步骤自动化流程的基本 NFR。

**Consequence（后果）**：实现者对失败场景各自按直觉处理，行为不一致。最坏情况：L2 审查失败但仍写 .done 文件，带着已知缺陷通过 gate，独立审查失去 gate 作用。

**Remedy（修补）**：新增一条 NFR 或 AC 定义 "独立审查失败语义"：明确 L2 审查 verdict=fail 的 gate 行为、子 agent 调用失败的退避/重试策略、.done 写入失败的错误传播路径。最小方案：至少写 "L2 审查 verdict=fail 时 .done 不写入，pipeline 在对应阶段阻塞"。

---

### 🟡 R7 · 缺失可观测性 NFR

**Symptom（症状）**：REQUIREMENT.md 未定义 pipeline 在阶段 3/5/7 独立审查环节的日志/追踪要求。当 pipeline 卡在某个阶段时，用户如何判断是 "正在等 L2 审查" 还是 "L2 审查已失败但未传播" 还是 "hook 层在等一个永远写不出的 done"？

**Source（源头）**：NFR 审查——可观测性是生产级 pipeline 的基础要求，尤其涉及异步子进程调用时。

**Consequence（后果）**：pipeline 死锁后用户盲目排查，只能靠猜。运维成本转移到用户侧。

**Remedy（修补）**：新增 NFR："主 agent 在进入独立审查阶段时应在日志中输出 `[gate] waiting for L2 independent review (phase <N>)`；L2 完成后输出 `[gate] L2 verdict: pass|fail`；.done 写入后输出 `[gate] gate cleared, advancing`"。

---

### 🟢 R8 · AC-2 验证部分依赖人工判断

**Symptom（症状）**：AC-2（`REQUIREMENT.md:28`）验证写 "grep ... 命中且映射正确"。grep 可验证"命中"（机器化），"映射正确"（JSON 值一致性）需要人工比对，未机器化。

**Source（源头）**：审查 checklist 第一条——验证必须可机器化。

**Consequence（后果）**：轻度——AC-2 的映射正确性已被 AC-3 的 `check-gate-sync.sh` 间接覆盖，但单独执行 AC-2 验证时仍需要人工确认。

**Remedy（修补）**：将 AC-2 的验证统一引用 `check-gate-sync.sh set-diff`（与 AC-3 一致），或追加一个 jq 对比检查。

---

### 🟢 R9 · AC-3 `plan-test` 命名有歧义

**Symptom（症状）**：AC-3（`REQUIREMENT.md:39`）`plan-test` 预设映射为 `{"1-requirement":"independent","2-design":"independent","5-test":"independent"}`。"plan-test" 可被解读为 "规划测试（plan the testing）" 而非 "(需求+设计规划) + 测试"。

**Source（源头）**：需求的歧义性原则——名称应自解释，避免多义。

**Consequence（后果）**：用户可能误以为 `plan-test` 仅影响测试阶段的规划，而不知道它也开启了 1-requirement 和 2-design 的独立审查。轻度风险——文档说明可弥补。

**Remedy（修补）**：考虑重命名为 `spec-test` 或 `plan-and-test`，更准确反映其覆盖的阶段集合。若保持当前名称，至少在 PRESET_MAP 注释中加一行说明。

---

### 🟢 R10 · 用户故事提及 L3 行为但无对应 AC

**Symptom（症状）**：用户故事（`REQUIREMENT.md:5`）描述 "L3 Stop hook 自动执行"，但 7 条 AC 中唯有 AC-1 在 Then 里顺带提到 "L3 由 Stop hook 自动处理"，没有专门的 AC 验证 L3 在阶段 3/5/7 的正确性。

**Source（源头）**：需求完备性原则——用户故事中的关键行为应有对应 AC。

**Consequence（后果）**：CHANGE.md 注明 "hook 层已在 gate-integrity 中完成 3/5/7 扩展"，若确实已在上一层完成，则本 spec 不应在用户故事中承诺 L3 行为；若未完成，则 AC 有缺口。无论哪种情况，用户故事与实际 AC 范围不一致。

**Remedy（修补）**：二选一：
- 若 L3 已由 gate-integrity 覆盖：用户故事中删除 "L3 Stop hook 自动执行" 或在范围切分中明确声明 "L3 不在本次变更范围内（已在 gate-integrity 中交付）"。
- 若 L3 仍有缺口：新增 AC 覆盖 L3 在阶段 3/5/7 的验证。

---

### 🟢 R11 · 性能 NFR 自相矛盾

**Symptom（症状）**：性能条目（`REQUIREMENT.md:102`）标注 "无"，但同一行写 "prompt 文本增加 < 200 行/文件"。描述了一个变更（文本量增加），却声称无性能影响。

**Source（源头）**：NFR 审查——表述应自洽。prompt 文本增加意味着更多 token 消耗，LLM 推理时间上升，这是可测量的性能影响。

**Consequence（后果）**：轻度——<200 行对现代模型的延迟影响通常在毫秒级，但 "无" 这个断言未经分析，不严谨。

**Remedy（修补）**：改为 "性能：prompt 文本增加 < 200 行/文件，预计单次推理延迟增加 < 5%，在可接受范围内" 或类似有数据的表述。

---

**Verdict**: fail（存在 2 项 🔴 Critical：R1 AC-7 验证覆盖不完整 + R2 AC-7 验证不可机器化）
