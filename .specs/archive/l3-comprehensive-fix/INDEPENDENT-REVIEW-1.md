# 独立审查 · 阶段 1

## L2 盲审

> 审查日期: 2026-07-07 | 审查员: L2 独立盲审 agent | 工件: REQUIREMENT.md (参考 CHANGE.md, CONTEXT.md)

---

### 🟡 R1 · L2 触发行为歧义：AC-4 「提示」与「触发」未区分

**Symptom（症状）**：REQUIREMENT.md:42 AC-4 Then 子句写「系统自动提示或触发 L2 子 agent 审查」，用「或」连接两种根本不同的行为（仅提示用户 vs 系统自动派子 agent）。验证方式同样写「输出明确提示…或自动触发 L2」，未收敛到单一预期行为。

**Source（源头）**：v1 范围切分（REQUIREMENT.md:76）将 AC-4 定性为「Stop hook 或 PreToolUse 自动检测 + 提示」，明确排除了「全自动触发」（后者在 v2 行 81）。但 AC 正文未体现此限定，读者仅读 AC 将无法区分 v1 的「检测+提示」与 v2 的「全自动触发」。

**Consequence（后果）**：DESIGN 和 DEV 阶段若仅读 AC-4 不读 v1/v2 范围切分，可能误实现为全自动派 agent（v2 行为），导致 v1 scope 蔓延、增加不必要的 token 消耗和子 agent 调度复杂性。测试用例也将因预期行为不单一而难以编写。

**Remedy（修补）**：将 AC-4 Then 子句从二选一收敛到 v1 实际范围。
```diff
- **Then** 系统自动提示或触发 L2 子 agent 审查（类比 L3 的被动触发），不依赖主 agent 主动读 prompt + 手动派 agent
+ **Then** 系统自动检测 L2 未完成状态并输出明确提示（含一键派 agent 命令），不依赖主 agent 主动读 prompt；v1 不自动派 agent，全自动触发留 v2
```

---

### 🟡 R2 · AC-6 KVP 文件格式未定义

**Symptom（症状）**：REQUIREMENT.md:52-57 AC-6 列出 `.done` 文件必须包含的 6 个 key（`phase` / `change_id` / `written_by` / `L2_verdict` / `L3_verdict` / `artifacts`），但未指定文件格式——是 `key=value` 行、Shell `source` 格式、JSON 还是其他？验证方式提到「创建缺某 key 的 done 文件」但同样未说明用什么格式创建。

**Source（源头）**：CONTEXT.md:125 将 `.done 6 键 KVP` 定义为术语但只说「键值对格式」而未规定编码格式。AC-6 直接继承此术语而未补充格式约束。

**Consequence（后果）**：不同模块（PreToolUse gate、SessionStart hook、Stop hook）可能各自按不同格式写入/解析 `.done`，导致格式不一致的 done 文件被误判为「键缺失」而 fail（假阴性），或不同格式都能解析但数据结构含义不同（静默 bug）。实现完成后再统一格式 = 修改多处消费方 = 高回归风险。

**Remedy（修补）**：在 AC-6 Then 子句中明确格式。需 DESIGN 阶段确认现有代码中最常用的格式后填入（候选：Shell source 格式 `KEY="value"`）。
```diff
- **Then** 校验 6 个 key 全部存在且非空（`phase` / `change_id` / `written_by` / `L2_verdict` / `L3_verdict` / `artifacts`），缺任何一键 → 视为无效 done → gate 不放行
+ **Then** 按 [格式待 DESIGN 确认，候选 Shell source: KEY="value"] 校验 6 个 key 全部存在且非空（`phase` / `change_id` / `written_by` / `L2_verdict` / `L3_verdict` / `artifacts`），缺任何一键 → 视为无效 done → gate 不放行
```

---

### 🟡 R3 · AC-7 「取有效最大值」在 `.phase` 过期时误判

**Symptom（症状）**：REQUIREMENT.md:63 AC-7 Then 子句写「两者取有效的最大值」。若 pipeline 模式 `current_phase=5` 但 `.phase=6`（例如上一次单阶段模式残留的过期值），max(5,6) = 6，Stop hook 将基于 phase 6 判断是否触发 L3，可能对当前阶段 5 漏触发或对已完成的阶段 6 误触发。

**Source（源头）**：AC-7 设计意图是解决 pipeline 模式下仅读 `.phase` 可能读到 0 而漏触发的问题，但 max-of-both 策略将另一个潜在过期源（残留的 `.phase`）引入判断，违背了 Given 子句「Pipeline goal 处于 Phase 5 时优先读 `current_phase`」的优先级设计。

**Consequence（后果）**：若 `.phase` 在 pipeline 会话前残留了高于 `current_phase` 的旧值，Stop hook 将基于错误的 phase 判断触发范围——可能对已完成阶段重复触发 L3（浪费 API token + 延迟），也可能在应触发时因 phase 匹配逻辑边界而跳过。

**Remedy（修补）**：去掉「取最大值」策略，改为分模式优先级选择：
```diff
- **Then** 优先读 `.goal.current_phase`（pipeline 模式）或 `.phase`（单阶段模式），两者取有效的最大值，避免读到过期 phase 导致漏触发或误触发
+ **Then** pipeline 模式（`.goal.scope = "pipeline"` 且 `.goal.current_phase` 非空非零）→ 仅用 `current_phase`；否则 → 降级用 `.phase`。禁止取二者最大值，避免过期 `.phase` 值污染 pipeline 判断
```

---

### 🟡 R4 · AC-2 截断算法完全未约束，验证依赖未定义的测试夹具

**Symptom（症状）**：REQUIREMENT.md:28 AC-2 Then 子句提供的是方向性描述（「优先保留结构性信息（章节标题、AC 列表、diff 关键段）」）而非可验证约束。何谓「结构性信息」？以什么规则判定？「diff 关键段」定义是什么——变更的函数签名？完整 hunk？基于行数截断？全部未定义。

**Source（源头）**：CHANGE.md:55 将 L3 长度限制识别为风险（「可能是 Anthropic API 层面的 token 限制，不一定能在 flow-kit 侧彻底解决」），但 REQUIREMENT.md 未将此风险转化为对截断算法的具体约束（如「所有 Markdown `##`/`###` 标题行必须保留」「AC 行完整保留」「diff hunk 头部完整保留，内容按 token 余量填充」）。

**Consequence（后果）**：DESIGN 阶段将无约束地自由发挥截断算法。如果实现过于简单（如仅改 `head -c` 为 `head -n`），假阳性问题不会实质改善。验证依赖的「模拟场景实际缺陷数」在 AC 中未定义——30KB 产物含几个故意植入的缺陷？谁构造此场景？可复现吗？验证本身不可验证。

**Remedy（修补）**：AC-2 增加 2 条硬约束 + 明确测试夹具定义。
```diff
  - **Then** 优先保留结构性信息（章节标题、AC 列表、diff 关键段），而非简单 `head -c` 硬截断；L3 模型被告知"以下为截断摘要"以避免基于不完整信息误判
+   -  硬约束：(a) 所有 Markdown `##`/`###` 标题行必须保留；(b) AC-1~AC-7 的 Given/When/Then 行必须完整保留
+   -  告知模型的截断提示必须包含：(a) 原始大小 vs 截断后大小；(b) 被截去的章节列表
  - **验证方式**: 构造一个 30KB 的阶段产物，触发 L3 → 检查 prompt 中是否包含"以下为摘要/截断"提示，且 critical 条数 ≤ 模拟场景实际缺陷数 + 1（容忍 1 条假阳性）
+   -  **测试夹具**：使用 `test/fixtures/` 下的预置 30KB REVIEW.md（含 3 个故意植入的缺陷：1 个缺失 AC 验证、1 个错误文件路径、1 个 scope 不一致），3 轮 L3 调用的 critical 均值 ≤ 4（3 真实 + 1 容忍）
```

---

### 🟡 R5 · L3 API 不可用时的降级策略缺失

**Symptom（症状）**：REQUIREMENT.md 非功能性需求段（行 96-100）仅定义了 timeout 值（90s curl / 30s PreToolUse），但未定义 L3 API 完全不可用时的行为——网络不通、API key 过期、服务端 5xx 等场景下，gate 放行还是阻塞？pipeline 继续还是暂停？

**Source（源头）**：CONTEXT.md:189 记录了已锁决策「超时 30s + 降级为 `L3_verdict=timeout`（不阻塞 pipeline）」。但 REQUIREMENT.md 未将该决策转化为显式 AC 或非功能性条目。依赖段落（REQUIREMENT.md:102-108）声明了「Anthropic API 兼容端点持续可用」的假设，但未定义该假设不成立时的降级路径。

**Consequence（后果）**：若 API 不可用而无降级策略，pipeline transition 可能在 PreToolUse gate 处永久阻塞（等待 L3 timeout 30s 后仍未得到如何处理），或在 L3 error 时行为未定义（panic？skip？retry？）。这直接影响 pipeline 的可用性——一个外部依赖故障不应阻断整个工作流。

**Remedy（修补）**：在非功能性需求段明确降级策略，将 CONTEXT.md 的已锁决策提升为 AC 级约束：
```diff
  - **安全**: `.done` 文件不能被主 agent 直接 Write/Edit（PreToolUse path-guard D7 已覆盖）；L3 API key 仅通过环境变量传入，不落盘
+ - **韧性**: L3 API 超时/不可用时降级为 `L3_verdict=timeout`，gate 仍放行（不阻塞 pipeline），输出 warning 日志含降级原因；L2 子 agent 派发失败时输出 error 日志但不阻塞（L2 失败 ≠ gate 失败，除非 gate_config 为 `L2-only`）
  - **兼容性**: 向后兼容——未开启 gate_config 的阶段行为不变；旧版 `.done` 文件（缺 L3_summary key）仍被识别为有效
```

---

### 🟡 R6 · AC-1 「L3 banner」格式与 CONTEXT.md 定义的 L3_RESULT 标准格式未对齐

**Symptom（症状）**：REQUIREMENT.md:21 AC-1 Then 子句写「终端输出 L3 审查 banner（含 verdict、summary、report 路径）」，验证方式写「检查 stdout 含 `L3_RESULT:` 或 L3 banner」。但 AC 正文并未引用或定义「L3_RESULT」的具体格式，也未指向 CONTEXT.md:127 已定义的 `L3_RESULT` 标准格式（`L3_RESULT: verdict=<pass|fail|timeout|error> summary=<一句话> report=<报告相对路径>`）。

**Source（源头）**：CONTEXT.md:127 已将 `L3_RESULT 格式` 作为术语固化，且此格式是先前 change `l3-feedback-visibility` 的产物。AC-1 应直接引用此标准格式而非重新定义「banner」。

**Consequence（后果）**：SessionStart hook 实现者可能创造一个新的「banner」格式与 PreToolUse gate 输出的 `L3_RESULT` 格式不一致，导致同样的 L3 审查结果以两种不同格式呈现，用户困惑。或者，实现者可能输出 `L3_RESULT` 行但不含 CONTEXT.md 定义的必须字段（如 `report` 相对路径），破坏下游解析。

**Remedy（修补）**：AC-1 Then 子句直接引用 CONTEXT.md 的 L3_RESULT 格式：
```diff
- **Then** 终端输出 L3 审查 banner（含 verdict、summary、report 路径），无需用户手动触发
+ **Then** 终端输出 L3 审查结果，格式遵循 CONTEXT.md 定义的 `L3_RESULT:` 标准行（`L3_RESULT: verdict=<pass|fail|timeout|error> summary=<一句话> report=<报告相对路径>`），无需用户手动触发
- **验证方式**: 模拟完成 Phase 6 L3 审查 → 结束 session → 新 session 启动 → 检查 stdout 含 `L3_RESULT:` 或 L3 banner
+ **验证方式**: 模拟完成 Phase 6 L3 审查 → 结束 session → 新 session 启动 → 检查 stdout 含 `L3_RESULT:` 标准格式行，且 verdict/summary/report 三字段均非空
```

---

### 🟢 R7 · AC-3 验证方式的「skipped」字符串未在 AC Then 子句中定义

**Symptom（症状）**：REQUIREMENT.md:36 AC-3 验证方式写「确认输出含 "skipped" 或直接 exit 0」，但 AC Then 子句仅说「跳过 L3（exit 0），不重复调用 API，不覆盖已有审查结果」，并未要求输出 "skipped" 字符串。

**Source（源头）**：验证方式补充了一个 AC 正文未声明的具体行为（输出 "skipped"），属于验证契约漂移——测试将检查一个 AC 未承诺的行为。

**Consequence（后果）**：实现者可能正确跳过 L3（exit 0）但不输出 "skipped"，导致测试 fail 而实际功能正确——浪费时间排查假阳性测试失败。

**Remedy（修补）**：在 AC Then 子句中补上日志输出要求，或验证方式去掉 "skipped" 仅检查 exit code：
```diff
- **Then** hook 检测到 `.done` 存在 → 跳过 L3（exit 0），不重复调用 API，不覆盖已有审查结果
+ **Then** hook 检测到 `.done` 存在 → 输出 skip 日志行（含 "skipped" 及 done 文件路径）→ 跳过 L3（exit 0），不重复调用 API，不覆盖已有审查结果
```

---

### 🟢 R8 · L2 子 agent 派发 ≤ 5s 的时延约束缺乏依据

**Symptom（症状）**：REQUIREMENT.md:96 非功能性需求行写「L2 子 agent 派发 ≤ 5s」。子 agent 派发涉及模型加载、prompt 注入、上下文初始化，在 CC 架构中 5 秒的时延承诺缺乏可测量的基准和可行性论证。

**Source（源头）**：无。此数值在 CHANGE.md 或 CONTEXT.md 中均无出处，是凭空给出的硬约束。

**Consequence（后果）**：若实际派发通常为 8-15 秒（取决于模型、token 上下文大小、CC 调度延迟），此约束要么被无视（形同虚设），要么被当作 bug 去"优化"一个不可优化的延迟（浪费工程资源）。

**Remedy（修补）**：改为定性约束或给出基于实测的合理值：
```diff
- - **性能**: L3 API 调用 timeout 保持 90s（curl）或 30s（PreToolUse sync wrapper）；L2 子 agent 派发 ≤ 5s
+ - **性能**: L3 API 调用 timeout 保持 90s（curl）或 30s（PreToolUse sync wrapper）；L2 子 agent 派发为异步提示（PreToolUse hook 输出提示即返回，不等待子 agent 完成），故不设硬时延上限
```

---

### 审查总结

| # | 严重度 | 发现 | 影响阶段 |
|---|--------|------|----------|
| R1 | 🟡 | AC-4 「提示或触发」二选一歧义，v1 scope 仅检测+提示 | DESIGN, DEV |
| R2 | 🟡 | AC-6 KVP 文件格式未定义（Shell source? JSON?） | DESIGN, DEV, TEST |
| R3 | 🟡 | AC-7 「取有效最大值」可能在 `.phase` 过期时误判 | DEV, TEST |
| R4 | 🟡 | AC-2 截断算法零约束 + 验证依赖未定义的测试夹具 | DESIGN, TEST |
| R5 | 🟡 | L3 API 不可用时降级策略缺失（CONTEXT.md 有但 AC 无） | DESIGN, DEV |
| R6 | 🟡 | AC-1 banner 格式与 CONTEXT.md L3_RESULT 标准未对齐 | DEV, TEST |
| R7 | 🟢 | AC-3 验证的 "skipped" 字符串未在 AC Then 中定义 | TEST |
| R8 | 🟢 | L2 派发 ≤ 5s 时延约束无依据 | DEV |

**正面发现**：
- 7 条 AC 全部 Given/When/Then 三段齐全，每条均有明确的验证方式。
- v1/v2/out 范围切分清晰，Phase 4 显式排除有据可查，v2 留项合理。
- AC-6 的正/反向验证设计优秀——同时测试缺失非必需键（放行）和缺失必需键（拒绝）。
- 非功能性需求覆盖了性能、安全、兼容性、可观测性四个维度，且兼容性条款明确了旧 `.done` 文件（缺 L3_summary）仍有效。
- AC-3 将 AC-7 的 phase 一致性修复纳入 scope，体现了对依赖关系的理解。

**Verdict**: pass

> 无 🔴 Critical 发现。6 条 🟡 Major 建议在进入 DESIGN 阶段前修正，其中 R1（AC-4 行为歧义）、R2（KVP 格式）、R3（AC-7 逻辑缺陷）为最高优先级——这三条若不在 REQUIREMENT 阶段收敛，将导致 DESIGN 阶段产生不可逆的实现分歧。

---

## 主 agent 回应

| Ref | 判定 | 行动 |
|-----|------|------|
| R1 | ✅ 采纳 | AC-4 Then 收敛为 v1 scope "检测 + 提示"，全自动触发明确留 v2 |
| R2 | ✅ 采纳 | AC-6 Then 明确 Shell source 格式（`KEY="value"`），与 `l3-review.sh:282-290` 实际格式一致 |
| R3 | ✅ 采纳 | AC-7 Then 改为优先级选择（pipeline → current_phase；否则 → .phase），禁止取 max |
| R4 | ✅ 采纳 | AC-2 增加 2 条硬约束（标题行保留 + AC 行完整保留）+ 测试夹具定义（`test/fixtures/l3-truncation-30k.md`，3 个植入缺陷） |
| R5 | ✅ 采纳 | 非功能性新增"韧性"条目：L3 API 不可用降级为 timeout（gate 放行）；L2 失败不阻塞（L2-only 除外） |
| R6 | ✅ 采纳 | AC-1 Then 直接引用 CONTEXT.md 的 `L3_RESULT:` 标准格式，去掉模糊的"banner"措辞 |
| R7 | ✅ 采纳 | AC-3 Then 补上 "skipped" 日志输出 + done 文件路径 |
| R8 | ✅ 采纳 | 性能条目改为定性约束：L2 派发为异步提示，不设硬时延上限 |

**L2 Verdict**: pass（无 🔴 Critical）  
**主 agent 确认**: 全部 8 条发现已修复入 REQUIREMENT.md。
