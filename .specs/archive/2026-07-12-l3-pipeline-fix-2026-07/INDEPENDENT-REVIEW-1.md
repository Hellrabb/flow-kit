# 独立审查 · 阶段 1

## L2 盲审

### 🟡 R1 · AC-6 可验证性：基线悬空导致 AC 形同虚设

**Symptom（症状）**：REQUIREMENT.md:56-59 — AC-6 的 Given 段写「当前 Stop hook 链基线执行时间（待测量）」，Then 段写「降低 ≥ 30%」，但基线值在需求文档中未承诺、未指定。验证方式写「优化前后各测 3 次取中位数」——若基线本身在实施后首次测量，则「30% 降幅」是循环论证：无法排除基线被人为选在「优化前的最慢一次运行」。

**Source（源头）**：验收准则的可验证性原则——Given 必须是可复现的确定状态，不能是「待测量」。若基线未在 REQUIREMENT 阶段固化为一个具体数值，则 Then 的「降低 ≥ 30%」无法在验收时被客观判定。

**Consequence（后果）**：实施完成后，任何一方可以任意选择基线测量值来主张「达标」或「未达标」，AC 失去 gate 作用。

**Remedy（修补）**：在 REQUIREMENT.md 中补充基线具体数值和测量条件。例：
```
- **Given** Stop hook 链基线 wall-clock 时间 = X.Xs（在干净 flow-kit 环境、无 L3 API 缓存预热、
  三次运行取中位数，测量命令：`time bash flow-kit-bundle/hooks/stop/00-gate.sh`）
- **When** 性能优化实施完成后，相同条件触发
- **Then** 中位数 wall-clock ≤ X.X × 0.7s
```

---

### 🟡 R2 · AC-1 策略二选一：AC 内嵌「或」导致验收标准分裂

**Symptom（症状）**：REQUIREMENT.md:23 — Then 段写「≥ 50000 字符（或按 token 估算的智能上限）」。括号内是一个完全不同的替代策略。当前写法让实施者可以自由选择「静态 50000 字符上限」或「动态 token 截断」，但验收标准只写了 grep 检查旧上限是否移除，无法区分实施者选择了哪种策略。

**Source（源头）**：验收准则设计原则——一条 AC 描述一个可判定结果。若存在两种可接受的实现路径，应拆分为 AC-1a 和 AC-1b，各自有独立 Then 和验证方式。

**Consequence（后果）**：Review 阶段无法判定 AC-1 是否真正「通过」——实施者可能选了一种策略但验证方式只覆盖另一种。

**Remedy（修补）**：二选一：(A) 拆分 AC-1a（静态上限 ≥50000）+ AC-1b（动态 token 截断）；(B) 选定一项，删除「或」分支。

---

### 🟡 R3 · AC-1~AC-5 验证方式统一依赖 grep 模式匹配，缺少行为级验证

**Symptom（症状）**：REQUIREMENT.md:24,31,38,45,52 — AC-1 到 AC-5 的验证方式全部以 `grep -c` 或 `grep -E` 为核心手段。grep 只能确认代码中出现了特定字符串模式，无法验证截断逻辑在边界条件下的行为正确性、diff 收集是否实际包含 untracked 文件内容、积压扫描在多个 phase 组合场景下的触发/不触发行为。

**Source（源头）**：验收准则的「可机器验证」原则——验证方式必须能客观判定 AC 的 Then 条件是否成立，而非仅判定代码中是否出现了相关关键词。grep 是存活性检查，不是正确性检查。

**Consequence（后果）**：所有 AC-1~AC-5 在形式上「可验证」实则不具备行为级验收能力。可能在 grep 通过但实际行为错误的情况下错误放行。

**Remedy（修补）**：为每条 AC 的验证方式补充一个 bats 测试用例引用或定义具体的 bash 一行测试，描述如何调用函数并断言输出。

---

### 🟢 R4 · AC-4 的 gate_config 值 "both" 未在需求文档中定义

**Symptom（症状）**：REQUIREMENT.md:42 — AC-4 Given 段引用 `gate_config["5-test"]="both"`。值 `"both"` 的语义在 REQUIREMENT.md 中未定义，读者只能从上下文推断。

**Source（源头）**：需求文档自包含原则——AC 中引用的领域术语必须在同一文档或其显式引用的文档中有定义。

**Consequence（后果）**：实施者可能对 `"both"` 语义做出错误假设，导致积压扫描触发条件实现偏离意图。

**Remedy（修补）**：在 REQUIREMENT.md 依赖段或 AC-4 下方加脚注说明 gate_config 取值（L2/L3/both）。

---

### 🟢 R5 · 可观测性标记为「可选」削弱 AC-6 长期有效性

**Symptom（症状）**：REQUIREMENT.md:104 — 可观测性中的耗时统计标记为「可选，不强制」。对于以「30% 性能提升」为关键 AC 的 change，将分模块耗时统计标记为可选意味着未来性能回退时无法定位瓶颈。

**Source（源头）**：性能关键型变更的可观测性实践——分模块耗时数据是性能 AC 可维护性的基础设施。

**Consequence（后果）**：中长期性能回退时诊断成本显著增加，无法区分「L3 API 变慢」还是「hook 链加载变慢」。

**Remedy（修补）**：将轻量耗时统计（如 `[perf] module_timings: gate=XXms l3=XXms total=XXms`）从可选提升为 v1 交付物，实现成本极低。

---

### 🟢 R6 · 缺少 L3 API 不可用时的降级行为定义

**Symptom（症状）**：REQUIREMENT.md 全文均未描述 L3 API 调用失败（网络超时/5xx/鉴权失败）时的预期行为。

**Source（源头）**：非功能性需求—可靠性。对外部 API 依赖的变更必须定义 failure mode。

**Consequence（后果）**：L3 API 不可用时 pipeline 行为未定义，可能导致 hook 链卡死或静默跳过。

**Remedy（修补）**：补充降级行为：API 失败 → 标记 `skipped` 写入 INDEPENDENT-REVIEW-{N}.md，pipeline 不阻塞。

---

**Verdict**: pass（无 🔴 Critical）

---

## 主 agent 响应

### R1（AC-6 基线悬空）

**Not-applicable**: 基线必须在真实环境中测量——本次 change 的第一步（DESIGN 阶段）就是测量当前 Stop hook 基线耗时。基线数据将在 DESIGN.md 中回填到 REQUIREMENT.md AC-6 的 Given 段。验收时用相同环境复测，确保对比公平。

### R2（AC-1 策略「或」）

**Fixed in**: REQUIREMENT.md — 选定动态 token 估算策略（非静态上限 50000），删除括号内的「或」分支。动态策略更灵活且不会在超大 diff 时仍截断。

### R3（grep-only 验证）

**Fixed in**: REQUIREMENT.md — AC-1~AC-5 的验证方式补充行为级 bats 测试引用。每条 AC 的「验证方式」段追加一个具体测试用例描述，由 5-test 阶段生成对应 bats 用例。

### R4（"both" 未定义）

**Fixed in**: REQUIREMENT.md — 依赖段追加 gate_config 取值说明脚注（L2/L3/both 三值定义）。

### R5（可观测性可选）

**Tech-debt**: 分模块耗时统计列为 v2 范围。理由：性能优化的第一步是定位瓶颈（测量），第二步才是加持续监控（可观测性）。v1 优先完成瓶颈定位和优化本身；耗时统计基础设施在 DESIGN 阶段设计好接口，v2 实现。

### R6（L3 API 降级缺失）

**Fixed in**: REQUIREMENT.md — 补充 AC-8（L3 API 降级行为），作为边界 AC 加入 v1 范围。当前 `l3_review_run()` 已对超时做 `verdict=timeout` 降级（不阻塞 pipeline），本次明确文档化此行为并扩展到所有 HTTP 错误码。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 18:12）

> 自动生成于 2026-07-11 18:12。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[{"file":"工件全局（AC-1）","issue":"AC-1 的 Then 中“模型上下文窗口的 60%”未定义具体值或引用源，导致验收标准不可直接验证","why":"工件没有指定所使用模型的上下文窗口大小（例如 100K tokens），也未说明从配置文件或环境变量读取。作为独立验收依据，审查者无法确定该上限，无法独立判断动态截断是否正确。","fix":"在 AC-1 的 Then 或验证方式中明确模型上下文窗口大小（如 100K tokens），或说明从 `CLAUDE_CONTEXT_WINDOW` 等配置获取，并确保测试用例中使用相同值。"}],"major":[{"file":"工件全局（AC-5）","issue":"AC-5 的验证方式未完全覆盖 Then 要求的“L2 verdict 上下文”","why":"AC-5 的 Then 要求 prompt 包含前次审查的 verdict + 主 agent 反驳摘要 + L2 verdict 上下文，但验证方式仅断言包含 verdict 和反驳文本，未检查 L2 verdict 上下文，可能导致实现遗漏。","fix":"在验证方式中明确增加对 L2 verdict 上下文的断言，例如验证 prompt 中包含“L2 Verdict:”标记或具体 L2 结论文本。"}],"minor":[{"file":"工件全局（AC-3）","issue":"AC-3 的 Given 中“超出 L3 prompt 单文件长度限制”未定义具体限制值","why":"“单文件长度限制”没有数值或引用，验证方式中硬编码了 6000 字符作为头/尾分界，但该值可能与实际限制不符，导致测试可能不反映真实场景。","fix":"在 AC-3 的 Given 或验证方式中明确单文件长度限制（如 12000 字符），或说明从配置中获取。"}],"verdict":"fail","summary":"AC-1 因模型上下文窗口未定义导致不可验证，属于关键障碍；AC-5 验证方式覆盖不足，AC-3 存在模糊性，整体需修正后才能判定为可接受。"}
```

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-11 18:17）

> 自动生成于 2026-07-11 18:17。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[{"file":"l3-review.sh","issue":"AC-1中估算token的具体算法未在需求中明确","why":"不同估算方法可能导致测试结果不一致","fix":"在AC-1或验证方式中补充估算token的规则，例如使用字符数除以4作为近似，或引用具体tokenizer"},{"file":"flow-kit-bundle/hooks/stop","issue":"AC-6中'代表性hook脚本'表述模糊","why":"可能导致验证时选择不同的脚本，影响基线测量的一致性","fix":"明确指定为`time bash flow-kit-bundle/hooks/stop/00-gate.sh`"},{"file":"工件整体","issue":"'依赖与假设'中引用了具体行号（l3-review.sh:204），属于实现细节","why":"需求文档应独立于实现，行号可能变更","fix":"改为描述性定位，例如'当前硬编码位置在l3-review.sh中函数xxxx内'"}],"verdict":"pass","summary":"所有验收准则均为可验证的Given/When/Then格式，覆盖全部用户故事；v1/v2/out范围切分合理，无范围蔓延或遗漏非功能性需求。存在几个微小的表述不精确问题，但不足以导致失败。"}
```
