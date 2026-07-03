# 独立审查 · 阶段 2

## L2 盲审

### 🔴 R1 · ADR编号引用错误：DESIGN指向不存在的文档
**Symptom（症状）**：DESIGN.md:324 行 `ADR-001 · L3 独立审查调用策略` 指向错误的 ADR 编号。实际 L3 前置决策的 ADR 文件为 `.specs/adr/002-l3-frontloading.md`（文件头 `# ADR-002`）。而 `.specs/adr/001-protect-the-weakest.md` 已存在且内容为弱模型鲁棒性哲学——与 L3 调用策略完全无关。
**Source（源头）**：ADR 编号唯一性原则。CONTEXT.md 已锁决策 `[2026-07-03] L3 同步调用策略...` 紧邻 `[2026-07-03] gate_config 快照一致性策略`，但 DESIGN 未将 ADR 编号与实际文件系统中的 ADR-002 对齐。编号 001 已被占用，002 是该决策的正确编号。
**Consequence（后果）**：实现者按 DESIGN 指引查找 ADR-001 会读到"弱模型鲁棒性哲学"，完全无法获得 L3 前置策略的决策上下文与取舍分析。若实现者未发现错误而是采纳 ADR-001 的"protect the weakest"框架套用到 L3 设计，会产生架构偏差。
**Remedy（修补）**：将 DESIGN.md:324 行 `ADR-001` 改为 `ADR-002`。同时检查全文是否有其他 ADR-001 引用指向 L3 前置：
```
- - **ADR-001 · L3 独立审查调用策略**：将 L3 外部模型 API 调用从 Stop hook...
+ - **ADR-002 · L3 独立审查调用策略**：将 L3 外部模型 API 调用从 Stop hook...
```

---

### 🔴 R2 · 31-auto-advance.sh 缺失独立审查 gate 意识，存在 gate bypass 路径
**Symptom（症状）**：DESIGN.md:262-273（§2.4 auto_advance 数据流）中 `31-auto-advance.sh` 仅在 PCSC 全✅ 时执行 transition jq，完全不检查 `.independent-review-<N>.done` 是否存在。若当前 phase N 开启了 gate（`gate_config["N-xxx"]="independent"`），且弱模型完成了 PCSC 产物但跳过了 L2 审查调度，31 号 hook 会直接推进到 N+1，绕过独立审查 gate。
**Source（源头）**：gate-integrity 分层防御原则（CONTEXT.md 已锁决策 `[2026-07-01]`）："Q1 防线定在 hook 层（非 prompt 层）—— agent 无法绕过 hook。" 31 号 hook 的 transition jq 由 Stop hook 内部直接执行，不经过 PreToolUse hook 的 `independent-review-gate.sh` 拦截——这意味着 31 号 hook 的 transition 是 gate 检测链上的盲区。单一防御依赖 `29-independent-review.sh` 在 31 之前补跑 L3 并写 `.done`（编号 29 < 31，顺序正确），但若 29 被禁用或 L2 本身未完成（29 仅在 L2 已完成时才补跑 L3，见 AC-1b），gate 即被绕过。
**Consequence（后果）**：弱模型场景下（auto_advance 的主要使用场景），若 agent 跳过了 L2 审查调度但完成了产物（PCSC 全✅），31 号 hook 会将 pipeline 推进到下一阶段——独立审查 gate 被静默绕过，后续阶段在无审查的产物基础上继续，违反 gate-integrity 的核心 invariant（"没有真实 .done 不能 transition"）。
**Remedy（修补）**：在 `31-auto-advance.sh` 的 transition 前置条件中增加 gate 意识——检查当前 phase 对应的 `.independent-review-<N>.done` 是否存在且有效。伪代码：
```bash
# 在 "PCSC 全✅" 检查之后，"执行 transition jq" 之前，增加：
if fk_validate_done_marker ".specs/${change_id}/.independent-review-${current_phase}.done"; then
  # .done 有效，执行 transition
else
  # .done 缺失/无效，输出告警，不 transition
  echo "auto_advance: phase ${current_phase} gate requires valid .done, skipping transition"
  return 0
fi
```
同时建议在 29 号 hook 中增加对 "L2 未完成" 场景的处理（当前 AC-1b 仅覆盖 "L2 已完成 + L3 缺失"）。

---

### 🟡 R3 · .done 文件的 L2_verdict 字段写入责任未在设计中分配
**Symptom（症状）**：AC-7（REQUIREMENT.md:167-178）要求 `.done` 文件含 6 键，其中包括 `L2_verdict=pass|fail`。DESIGN.md:85-96 的 `l3_review_run()` 函数签名与 §2.1 数据流图（:206-219）均未说明谁负责从 `INDEPENDENT-REVIEW-<N>.md` 中解析 L2 段并提取 verdict 填入 `.done` 文件。旧 Stop hook `29-independent-review.sh` 原本负责写入完整 `.done`（含 L2_verdict），但新流程中 PreToolUse hook 调用 `l3_review_run()` 写 L3 段 + 握手文件时，L2_verdict 的写入未分配。
**Source（源头）**：单一职责与接口契约。`l3_review_run()` 的函数签名（:85-96）声称负责"L3 段写入"和"handshake 文件写入"，参数仅含 phase/change_id/artifacts_dir，不接收 L2_verdict 参数。且其 handshake 写入目标为 `.flow-active.independent-review`（:91），而非 `.independent-review-<N>.done`（AC-1 明确定义的握手文件）。调用方 `independent-review-gate.sh` 在调用 `l3_review_run()` 前后的职责边界模糊。
**Consequence（后果）**：实现阶段产生协议歧义——开发者在 `independent-review-gate.sh` 和 `l3-review.sh` 之间反复推诿 L2_verdict 写入责任，最坏情况：`.done` 文件缺失 `L2_verdict=` 键，导致 Tier1 校验失败（AC-8 要求检查），gate 永远无法放行。
**Remedy（修补）**：明确分配职责。推荐方案：
- `l3_review_run()` 扩展为接收 L2_verdict 参数（`$4`），负责写入完整的 6 键 `.done` 文件
- 或：`l3_review_run()` 仅写 L3 段 + 返回 verdict，由调用方 `independent-review-gate.sh` 负责组装并写入完整 6 键 `.done`
- 无论哪种方案，均需在 DESIGN §1 D2 的函数签名中更新参数列表，并在 §3 状态机中标注 `.done` 写入点

---

### 🟡 R4 · l3_review_run 函数签名中的 'handshake 文件' 与 AC-1 定义的握手文件为不同路径
**Symptom（症状）**：DESIGN.md:90-91 函数签名注释写 `handshake 文件写入 .flow-active.independent-review`，但 AC-1（REQUIREMENT.md:25）定义握手文件为 `.independent-review-<N>.done`（即 6 键 done 标记文件）。DESIGN.md:383-384 又将 `.flow-active.independent-review` 列为新增禁动文件，称其作用为"握手文件"——且声称"已有 D7 path-guard，不变"，但 D7 path-guard 保护的是 `.independent-review-<N>.done` 路径，与 `.flow-active.independent-review` 是不同的文件系统路径。
**Source（源头）**：单一术语映射原则。DESIGN 引入了两个握手概念（.done 文件 vs .flow-active.independent-review），但仅 AC-1 定义了 `.done` 文件的握手语义。`.flow-active.independent-review` 未在任何 AC 中定义其格式/内容/生命周期，也未在 REQUIREMENT 中作为非功能性需求声明。
**Consequence（后果）**：实现者面对两个"握手文件"时不知道哪个才是 AC-1 要求的 proof-of-review 标记。若 `l3_review_run()` 仅写 `.flow-active.independent-review` 而不写 `.done`，gate 检测 `.done` 时发现缺失 → L3 被错误判定为"未完成" → pipeline 死锁重现。若同时写两个文件则引入不必要的状态冗余。
**Remedy（修补）**：统一握手文件概念。两种路径：
- 若 `.flow-active.independent-review` 有独立用途（如并发控制/跨 hook 信令），需在 DESIGN 中明确定义其格式/语义，并区分命名避免与 `.done` 混淆（如改名为 `.flow-active.l3-lock`）
- 若仅用于标记 L3 完成状态，则应废弃该文件，`l3_review_run()` 的 handshake 输出直接使用 `.independent-review-<N>.done`，与 AC-1 一致

---

### 🟡 R5 · is_phase_write() 对不包含 current_phase 的命令行为未定义
**Symptom（症状）**：DESIGN.md:126-127 伪代码：
```bash
local target_phase=$(echo "$command" | grep -oP 'current_phase\s*=\s*"\K[0-7]')
```
若 agent 执行的 jq 仅修改 `gates`、`phases_done` 等字段而不含 `current_phase = "N"` 模式，`grep` 返回空字符串。后续 `[[ "" < "$current_phase" ]]` 在 Bash 中字符串比较结果为真（空字符串字典序小于任何非空字符串），函数错误返回 0（回退放行），触发错误的放行语义。
**Source（源头）**：防御式编程中的边界条件处理。AC-3b（REQUIREMENT.md:93-98）明确定义了 no-op 场景（target==current 放行），但未覆盖"命令中不包含 current_phase 赋值"的场景。DESIGN 实现了三向判定却遗漏了"无目标"的第四种情况。
**Consequence（后果）**：非 phase-write 命令（如仅修改 `gates` 字段的 jq）被错误分类为"回退"并放行——虽然放行结果恰好正确（这些命令确实不应被拦截），但语义错误（不是回退而是无关命令）会导致：(a) 日志/调试信息输出误导性"回退放行"消息；(b) 未来若"回退放行"路径增加附加逻辑（如记录回退审计日志），会污染非回退命令的日志。
**Remedy（修补）**：增加空值守卫：
```bash
local target_phase=$(echo "$command" | grep -oP 'current_phase\s*=\s*"\K[0-7]')
if [[ -z "$target_phase" ]]; then
  return 0  # 非 phase-write 命令，放行（不干扰）
fi
if [[ "$target_phase" < "$current_phase" ]]; then return 0; fi  # 回退放行
if [[ "$target_phase" == "$current_phase" ]]; then return 0; fi # no-op放行
# target > current: 前进，继续检查 gate
```

---

### 🟡 R6 · 独立审查 verdict（pass/fail）不阻塞 transition 的设计决策未显式声明
**Symptom（症状）**：DESIGN.md §2.1 数据流图 :207-208："`.done` 有效? → 是 → 放行"；:219："L3 完成 → 放行 transition jq"。两处放行条件均为"L3 执行完毕 + .done 有效"，不依赖 L2_verdict 或 L3_verdict 的实际值（pass/fail）。AC-7 定义的 `.done` 文件包含 `L2_verdict=pass|fail` 和 `L3_verdict=pass|fail|timeout`，但 DESIGN 未说明 verdict=fail 是否应阻塞 pipeline。gate-integrity 的原始设计目标（CONTEXT.md 已锁决策 `[2026-07-01]`）聚焦于"审查是否真实发生"（反空/假/跳过），而非"审查是否通过"——这是一个重大的架构选择，但 DESIGN 中无任何决策条目或风险段讨论此设计。
**Source（源头）**：显式优于隐式（ADR 书写原则）。gate 的行为语义（existence-gate vs quality-gate）决定了 pipeline 的行为边界——若 L2/L3 均 fail 仍可 transition，则独立审查的角色是"必读的建议"而非"必过的门禁"。此语义直接影响用户对 pipeline 行为的预期和后续依赖方对 .done 文件的解读。
**Consequence（后果）**：(a) 用户可能误以为独立审查 fail 会阻塞 pipeline，实际不会——当发现 pipeline 在 L2=fail 后仍推进时感到困惑；(b) 若未来有人基于"L2_verdict=pass 是 transition 前提"的误解构建下游工具（如 CI 集成、PR 门禁），会出错；(c) 当前 gate-integrity 体系有演化压力——v2 可能需要将 verdict 纳入 gate 条件，届时需评估兼容性。
**Remedy（修补）**：在 DESIGN §1 增加一条决策条目明确此设计选择：
```markdown
| D13 | 独立审查为 existence-gate（不阻塞 fail verdict） | A. verdict=fail 阻塞 transition B. verdict 仅记录不阻塞（选定） | B: gate-integrity v1 的目标是确保审查真实发生（反伪造），不是确保审查通过。verdict=fail 由人工评估后决定是否重做/跳过。与 CONTEXT `[2026-07-01]` gate-integrity v1 范围一致 | v2 若需将 verdict 纳入 gate 条件，需新增 .done 语义版本号以区分新旧行为 |
```
同时在 §5 风险表中增加对应条目：若弱模型产出的 L2 审查质量低下（大量 false-positive fail），用户可能在不知情的情况下重复遇到 fail→transition→fail 循环。

---

### 🟢 R7 · R4 硬编码清单缺少与 prompt PCSC 段的交叉引用锚点
**Symptom（症状）**：DESIGN.md:147-152 `PHASE_PRODUCTS` 硬编码了各 phase 的产物，§5 风险 R4 标注了"硬编码 PCSC 产物清单与 prompt 漂移"风险，缓解措施为"hook 文件顶部注释标注同步要求"。但 DESIGN 未列出各 phase prompt 中 PCSC 段的具体路径，维护者无法直接从 DESIGN 找到需要同步的参照源。
**Source（源头）**：可维护性设计——风险缓解措施应具体到可执行步骤。如果缓解措施是"在 hook 顶部注释"，DESIGN 应给出注释模板包括具体的参照路径列表。
**Consequence（后果）**：prompt PCSC 段变更时，维护者需自行 grep 各 prompt 文件定位 PCSC 段，增加遗漏概率。虽然非阻塞性问题（hook 错误跳过 transition 时会被发现），但增加了调试成本。
**Remedy（修补）**：在 DESIGN §5 R4 缓解列或 `31-auto-advance.sh` 伪代码注释中列出参照路径：
```
# 此清单需与以下 prompt PCSC 段保持同步：
#   flow-kit-bundle/flow-kit/prompts/4-dev.md § "Pipeline Toll-Gate" PCSC 表
#   flow-kit-bundle/flow-kit/prompts/5-test.md § "Pipeline Toll-Gate" PCSC 表
#   flow-kit-bundle/flow-kit/prompts/6-review.md § "Pipeline Toll-Gate" PCSC 表
#   flow-kit-bundle/flow-kit/prompts/7-integration.md § "Pipeline Toll-Gate" PCSC 表
```

---

### 🟢 R8 · D8 ⑥ snapshot 一致性检查在核心数据流图中缺失
**Symptom（症状）**：DESIGN §2 四张数据流图中，仅 §2.2 单独展示了 gate_config 快照同步的写入路径，但 §2.1（L3 前置调用链）在 gate_config 判定步骤（:203）后未展示 D8 ⑥ snapshot 一致性检查的执行节点。读者无法从主数据流图理解 snapshot 检查在 gate 判定链中的精确定位（是在"gate_config 开启? → 是"之前还是之后？是独立检查还是会合？）。
**Source（源头）**：完整性与可追溯性——数据流图应反映 hook 的实际执行顺序。REQUIREMENT AC-2b 要求"hook D8 ⑥ 快照一致性检查 → hook 检测一致 → 放行操作"，但主数据流图遗漏了此步骤。
**Consequence（后果）**：低——gate_config 的 snapshot 检查默认与"gate_config 是否开启"判定在同一代码路径中，实现者参照既有 `independent-review-gate.sh` 即可。但未来维护者仅读 §2.1 数据流图可能遗漏 snapshot 检查维护。
**Remedy（修补）**：在 §2.1 数据流图 :203 "gate_config["N-xxxx"] = 'independent'?" 之后插入：
```
├─ D8 ⑥ snapshot 一致性检查 (gate_config vs .goal-snapshot.json)
│   └─ 不一致 → 拦截: "gate_config 可能被篡改"
```

---

### 🟢 R9 · Stop hook 模块 29→31→32 的执行顺序依赖未显式文档化
**Symptom（症状）**：DESIGN §2.4（:260-280）展示了 31 和 32 号模块的独立执行流，但未说明编号依赖（29 在 31 之前执行是 gate 完整性的前提——29 补写 .done 后 31 的 auto_advance transition 才有 gate 合规的基础）。§0.5.1 禁动清单仅标注编号不冲突，未标注执行顺序的架构依赖。
**Source（源头）**：模块间隐式契约应显式化。ADL 原则要求跨模块依赖（即使是"靠编号排序"的隐式依赖）在设计文档中明确记录，避免未来编号调整（如插入 30.5 模块）时破坏时序假设。
**Consequence（后果）**：低——当前编号体系（29 < 31 < 32）天然满足顺序要求，且 hook 模块编号调整在 flow-kit 项目中极少发生。但若未来某 change 需要在 29 和 31 之间插入新模块，且插入了会重置 L3 状态的操作，可能破坏 31 的 gate 合规前提。
**Remedy（修补）**：在 DESIGN §0.5.1 或 §2.4 增加注释：
```
# 执行顺序依赖：29 (L3 fallback) → 31 (auto_advance) → 32 (fallback guard)
# 31 依赖 29 确保 .done 已写入后方可执行 transition
```

---

**Verdict**: fail
