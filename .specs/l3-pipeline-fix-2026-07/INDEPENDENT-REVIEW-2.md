# 独立审查 · 阶段 2

## L2 盲审

> 审查员：L2 子 agent（固化指令驱动）
> 审查日期：2026-07-11
> 工件：`.specs/l3-pipeline-fix-2026-07/DESIGN.md`
> 参考：REQUIREMENT.md、CHANGE.md、CONTEXT.md、ARCHITECTURE.md
> 源码验证：`l3-review.sh`（625 行）、`29-independent-review.sh`（153 行）、`common.sh`（263 行）

---

### 🟡 R1 · D1 git diff 策略：切换到 `--cached` 将丢失 unstaged 工作区变更，且既有行为描述不准确

**Symptom（症状）**：
- DESIGN.md D1 行 79-80 声称当前 `git diff HEAD`（`l3-review.sh:201`）"仅含 tracked 工作区变更，**不含 staged 变更**"。此描述不准确——`git diff HEAD` 对比的是工作区 vs HEAD，已 staged 且工作区未再修改的文件**仍会出现在 diff 中**（工作区内容与 index 一致，与 HEAD 不同）。
- DESIGN.md D1 行 83 决定"改为 `git diff --cached HEAD`"。`--cached` 仅对比 index vs HEAD，**不包含工作区中未 staged 的修改**。若 agent 在 stage 后又做了额外编辑（未再次 `git add`），这些 unstaged 变更将从 L3 prompt 中**消失**。这是收窄，非纯扩展。
- 源码验证：`l3-review.sh:200-206` 确认当前使用 `git diff HEAD`。

**Source（源头）**：Git 文档 — `git diff HEAD` 对比 working tree vs HEAD；`git diff --cached HEAD` 对比 index vs HEAD。两者覆盖不同集合，union 才等于全量变更。

**Consequence（后果）**：
- 若 agent 在 `git add` 后又编辑了文件但未再次 stage，L3 审查将基于**不完整的 diff**（缺少最新未 staged 修改），导致假阴性（遗漏真实问题）。
- 典型场景：agent 先 stage 一批修复，接着微调了某文件没 stage → L3 看不到微调部分。
- 概率：中等（agent 在提交前做多轮修改是常见模式）。

**Remedy（修补）**：
- 方案 A（推荐）：同时使用 `git diff HEAD` **和** `git diff --cached HEAD`，对重叠部分去重。这覆盖全量变更（工作区 + 仅 index 中存在的新文件）。
- 方案 B：保持 `git diff HEAD` 作为主 diff 来源，额外对 `git diff --cached`（不带 HEAD）判断 index 中是否有工作区没有的差异（即仅 index 独有的新文件块），追加到 diff 末尾。
- 至少：在 DESIGN.md D1 中明确记录此 trade-off（`git diff HEAD` → `--cached` 是取舍非纯收益），并给出典型 workflow 下 unstaged 变更不存在的假设前提。

---

### 🟡 R2 · AC-6 性能优化：DESIGN 仅提供测量框架，未承诺任何具体优化策略

**Symptom（症状）**：
- DESIGN.md D5（行 137-146）描述了 Phase 1（测量基线）、Phase 2（定位瓶颈）、Phase 3（根据瓶颈类型选择策略）。
- Phase 3 的策略选择用了"根据瓶颈类型选择"——这是一个**条件分支描述**，不是具体设计。DESIGN 没有选择"L3 API 异步化"、"lib 并行加载"、"独立模块后台跑"中的任何一个作为 v1 的实施策略。
- 对比 REQUIREMENT.md AC-6（行 56-59）：要求"Stop hook 链总执行时间降低 ≥ 30%"，属于 v1 必做范围。
- D5 行 146 明确承认"优化阶段 3 的改动量取决于瓶颈类型，当前无法承诺具体行数"——这承认了 DESIGN 对 AC-6 的核心部分没有做出设计决策。

**Source（源头）**：REQUIREMENT.md "范围切分" — AC-6 列为 v1（本次必做）。设计规范 — DESIGN 应对每个 v1 AC 提供实现方案，不能仅提供"如何发现方案"的流程。

**Consequence（后果）**：
- DESIGN 与 REQUIREMENT 之间存在 gap：REQUIREMENT 承诺了 ≥30% 的性能提升，但 DESIGN 只承诺了"先测量再说"。
- 最坏情况：Phase 1 测量后发现所有瓶颈都是结构性限制（如 L3 API 同步等待 30s）且快速优化空间不足，则 AC-6 无法在当前 change 范围内满足。此时 DESIGN 没有备选方案。
- 下游 TASK 阶段无法为 AC-6 拆解出具体实施任务。

**Remedy（修补）**：
- 选项 A：在 DESIGN 中明确 v1 的优化策略至少包含一项可独立验证的优化（如"l3_review_run() 支持 `--background` flag，L3 调用从 Stop hook 同步路径中移除"），使 AC-6 有具体锚点。
- 选项 B：将 AC-6 降级为 v2 范围，v1 仅承诺 Phase 1+2（测量 + 定位），Phase 3 优化实施移到独立 change。
- 选项 C：在 §6"不在范围"中明确 AC-6 的 Phase 3 优化策略选择依赖 Phase 1 测量结果——如果测量后无法在 v1 范围内达到 30%，则 AC-6 以"已建立基线 + 输出瓶颈报告"为验收条件，实际优化延迟到 v2。

---

### 🟡 R3 · 禁动清单异常未声明：`29-independent-review.sh` 在 CONTEXT.md 禁动清单中但 DESIGN 未提供异常理由

**Symptom（症状）**：
- CONTEXT.md 第 383 行禁动清单条目：`independent-review-gate.sh` + `29-independent-review.sh` + `fk_validate_done_marker` — gate 校验核心链。
- DESIGN.md §0.5.1（行 36-42）的禁动清单仅列出 `independent-review-gate.sh`，**排除了 `29-independent-review.sh`**，且未声明任何异常理由。
- DESIGN 在"触碰模块"中列出 `29-independent-review.sh`（行 30），在"沿袭说明"中说明积压扫描在此文件（行 56），但**未解释为何允许触碰禁动清单中列出的文件**。

**Source（源头）**：CONTEXT.md 禁动清单（行 383）— `29-independent-review.sh` 属 gate 校验核心链。DESIGN 规范 — §0.5.1 若触碰禁动清单中的文件，必须显式声明异常理由。

**Consequence（后果）**：
- 禁动清单的可信度被削弱——若任何 change 可以通过"在本地禁动清单中排除该条目"来绕过全局禁动清单，则禁动清单形同虚设。
- `29-independent-review.sh` 属于 gate 校验核心链，修改出错可导致 L3 审查调度失效或 pipeline 死锁。
- 当前修改意图（积压扫描）是合理的，但缺少书面记录意味着后续审查者无法追溯"为何这个禁动被豁免"。

**Remedy（修补）**：
- 在 DESIGN.md §0.5.1 或 §0.5.3 中添加一段明确声明：
  ```
  > 禁动清单异常声明：CONTEXT.md 禁动清单将 `29-independent-review.sh` 列为 core chain。
  > 本次修改理由：积压扫描（D3）必须注入 29 号 hook 入口（L3 补跑的唯一调度点），
  > 且改动最小（仅在入口处添加 `_l3_scan_backlog()` 调用，不修改 L3 派发核心逻辑）。
  > 触碰范围限定：仅在 `fk_independent_review_run()` 入口添加扫描调用 + 新增 `_l3_scan_backlog()` 函数定义。
  ```

---

### 🟡 R4 · D6 HTTP 状态码处理不可实现：`_l3_call_api()` 未捕获 HTTP 状态码

**Symptom（症状）**：
- DESIGN.md D6（行 153-158）提出在 `_l3_parse_result()` 中扩展 HTTP 状态码处理：200 → 正常，4xx → `verdict=error`，5xx → `verdict=error`。
- 源码验证：`l3-review.sh:254` — `curl -s --max-time 90 ...` **仅使用 `-s`（silent）标志**，未使用 `-w '%{http_code}'` 或其他方式捕获 HTTP 状态码。`-s` 抑制进度条但**不输出状态码**。
- 函数的返回值判断依赖 `jq -r '.content[]...'` 是否能提取到文本内容（`l3-review.sh:272`），完全不检查 HTTP 状态。
- 4xx/5xx 响应通常也包含 JSON body（如 `{"error": {...}}`），jq 提取可能意外成功，导致 `verdict` 被误解析。

**Source（源头）**：bash/curl 手册 — HTTP 状态码需显式捕获（`-w '%{http_code}'` 或 `--write-out`），curl 不会自动将其暴露给管道。

**Consequence（后果）**：
- D6 的设计提案在当前代码基础上**无法实现**——`_l3_parse_result()` 收不到 HTTP 状态码，无从区分 200/4xx/5xx。
- 若强行实现（仅靠检测 response body 中的 error 字段），将产生误判：合法 JSON 响应中的 `"error"` 关键词可能被误认为 API 错误。
- 当前已将 curl timeout 设为 90s（与 `l3_review_with_timeout` 的 30s 不一致），但 DESIGN 未提及此差异。

**Remedy（修补）**：
- 在 D6 设计中明确第一步：修改 `_l3_call_api()` 使其输出 HTTP 状态码（如添加 `-w '\n%{http_code}'` 然后用 `tail -1` 提取状态码、其余行作为 body）。
- 或在 `_l3_call_api()` 与 `_l3_parse_result()` 之间新增接口约定：`_l3_call_api()` 输出格式改为 `<http_code>\n<response_body>`，`_l3_parse_result()` 按此解析。
- 同步检查：`_l3_call_api()` 内部 timeout 90s 与 `l3_review_with_timeout()` 的 30s wrapper 超时之间的关系需在 DESIGN 中说明（当前 wrapper timeout 会先触发，但若 wrapper 被绕过直接调用 `l3_review_run()`，则 90s 生效）。

---

### 🟡 R5 · 上下文注入（D4）与 ADR-005 "独立视角" 存在哲学冲突，未讨论

**Symptom（症状）**：
- DESIGN.md D4（行 119-133）提出在 L3 prompt 中注入前次审查上下文（verdict + 主 agent 反驳 + L2 verdict）。
- ARCHITECTURE.md ADR-005（行 174-183）定义 L3 为提供"跨模型独立视角"（`跨模型独立视角，互补防遗漏`）。
- D4 将 L3 从"独立盲审"转变为"带上下文的历史感知审查"。这改变了 L3 的审查性质——外部模型不再仅基于工件本身做判断，而是受前次审查结论的影响。
- DESIGN 未讨论此哲学冲突，也未讨论注入上下文是否会引入**锚定效应**（外部模型看到前次审查的结论后，倾向于认同而非独立判断）。

**Source（源头）**：ADR-005 — L3 定位为提供独立视角。D4 引入上下文注入与 ADR-005 的"独立"假设存在张力。

**Consequence（后果）**：
- 外部模型可能被前次审查结论锚定（尤其当 verdict=pass 时，后续审查倾向于也 pass），削弱 L3 的独立检查价值。
- 若前次审查有误（假阳性 verdict=fail），注入的上下文可能使新审查延续该错误判断。
- 长期来看，L3 的"独立"性逐渐弱化，"上下文感知"性增强，ADR-005 可能需要更新以反映实际行为。

**Remedy（修补）**：
- 在 DESIGN.md D4 或 §5 风险表中增加一个条目，讨论上下文注入对审查独立性的影响及缓解措施。
- 至少在本 change 的上下文中明确：上下文注入是**缓解已知问题（假阳性反复出现）**的工程权衡，不同于改变 ADR-005 的架构意图。
- 考虑在注入格式中增加免责声明（如 `[注意：以上为历史审查上下文，本次审查仍应基于工件本身独立判断]`）。

---

### 🟡 R6 · 风险 R1 缓解措施引用未设计的功能（按文件拆分）

**Symptom（症状）**：
- DESIGN.md §5 风险表 R1（行 232）缓解措施："对超大 diff 按文件拆分（先截断变更最大的文件）"。
- 但在 D1 决策（行 76-88）和整个 §2 数据流图中，**没有任何地方描述或规定了"按文件拆分"的机制**。
- D1 仅提到 `_estimate_tokens()` 截断 + `--cached` 策略，未提及按文件优先级拆分。

**Source（源头）**：设计完整性原则 — 风险缓解措施若引用未在设计其他部分定义的机制，则缓解措施不可操作。

**Consequence（后果）**：
- R1 的缓解措施是虚设——当超大 diff 触发 token 估算截断时，实现者不知道"按文件拆分"的具体算法（如何排序文件大小？拆分后每个文件保留多少？），无法实施。
- 下游 TASK/DEV 阶段会在此处产生实现歧义。

**Remedy（修补）**：
- 选项 A：在 D1 决策中补充"按文件拆分"的子策略——如何排序（`git diff --stat` 取 Top-N 大文件）、每个文件保留行数上限、与 `_estimate_tokens()` 的集成点。
- 选项 B：从 R1 缓解措施中移除"按文件拆分"，改为仅依赖 `_estimate_tokens()` 的保守上限（context_window × 60%），并承认超大 diff 场景下可能出现截断遗漏（作为已知限制记录在案）。

---

### 🟡 R7 · D3 积压扫描限流（≤3 phase/次）仅在风险表中提及，未纳入接口设计

**Symptom（症状）**：
- DESIGN.md §5 风险表 R2（行 233）缓解措施："补跑队列限制 ≤ 3 个 phase/次；超过则推迟到下次 Stop hook"。
- D3 决策（行 105-115）的算法描述仅列出扫描→检查→补跑的逻辑，**未包含限流控制**。
- §2.1 数据流图（行 181-185）的积压扫描段也**未显示限流逻辑**。

**Source（源头）**：设计文档内部一致性 — 风险缓解措施若不在主决策描述中体现，则实现阶段可能遗漏。

**Consequence（后果）**：
- 实现者可能按 D3 的算法描述实现（无限制补跑），忽略风险表中提到的限流要求。
- 若实现遗漏限流，则 R2 风险未得到实际缓解。

**Remedy（修补）**：
- 在 D3 算法描述中添加限流步骤："扫描结果按 phase 排序，取前 3 个缺失 .done 的 phase；超出部分记录到 hook 日志并推迟到下次 Stop hook"。
- 在 §2.1 数据流图中标注"max 3 phases per run"。

---

### 🟡 R8 · D2 尾部锚点关键词硬编码，缺乏维护策略

**Symptom（症状）**：
- DESIGN.md D2（行 97-98）尾部锚点关键词：`## 5. 风险`、`## 风险`、`ADR-`、`已锁决策`。
- 这些是精确字符串匹配。若未来 DESIGN.md 模板的章节编号调整（如 `## 5. 风险` → `## 6. 风险`），或 CONTEXT.md 的"已锁决策"段重命名，锚点匹配将**静默失效**——smart_truncate 退化回旧行为，且不产生任何错误或警告。
- 关键词不覆盖非标准命名的风险/决策段（如 `## Risk Analysis`、`## Trade-offs`）。

**Source（源头）**：软件维护性 — 基于字符串匹配的启发式逻辑需明确的维护契约或失效检测机制。

**Consequence（后果）**：
- 模板格式变更时截断行为退化，尾部关键段被丢弃，L3 审查可能遗漏风险/决策信息。
- 退化是静默的（smart_truncate 不会报错"尾部锚点未匹配"），难以发现。

**Remedy（修补）**：
- 在 D2 设计中添加匹配失败的 fallback 行为：若尾部扫描未匹配到任何锚点关键词 → 回退到截取最后 N chars（如 `max_chars / 4` 的尾部保留）。
- 或在 smart_truncate 输出中增加元信息标签：`[尾部保留: 3 段 (风险, ADR-001, ADR-002)]`，若为 0 段则标注 `[尾部保留: 0 段 — 未匹配到已知锚点，尾部可能不完整]`。
- 长期：在 `.specs/ARCHITECTURE.md` 或 `reference/` 中定义标准章节命名约定，smart_truncate 引用该约定而非硬编码关键词。

---

### 🟢 R9 · 新增函数命名不符合 CONTEXT.md 既有前缀约定

**Symptom（症状）**：
- CONTEXT.md 命名约定（行 343-353）：跨文件可调用的公共 API 使用 `fk_` 前缀；模块内部使用 `_<module>_` 前缀。
- DESIGN.md §0.5.2 和 §9.1 提出以下新函数放入 `common.sh`：
  - `_estimate_tokens()` — 无模块前缀，但定位为"任何需要估算 prompt token 数的 hook/lib"均可调用（跨模块公共 API），应使用 `fk_estimate_tokens()`。
  - `_perf_timing_start()` / `_perf_timing_end()` — 同上，跨模块公共 API，应使用 `fk_perf_timing_start()` / `fk_perf_timing_end()`。
- 对比 `common.sh` 中已有的公共 API：`fk_resolve_phase()`（行 215）正确使用了 `fk_` 前缀。

**Source（源头）**：CONTEXT.md § 命名约定 — `fk_` prefix = flow-kit 公共 API，跨文件可调用。

**Consequence（后果）**：
- 命名不一致增加认知负荷——开发者看到 `_estimate_tokens()` 无法从名称判断它是文件内私有函数还是跨模块公共 API。
- 若未来有人误将 `_estimate_tokens()` 当作私有函数并修改其签名，可能破坏多个调用方。

**Remedy（修补）**：
- 将 `_estimate_tokens()` 改为 `fk_estimate_tokens()`，`_perf_timing_start()` / `_perf_timing_end()` 改为 `fk_perf_timing_start()` / `fk_perf_timing_end()`。
- 在 DESIGN.md §9.1 的复用建议表格中使用修正后的名称。

---

### 🟢 R10 · DESIGN 中对既有源码的行数/行号引用有小幅偏差

**Symptom（症状）**：
- DESIGN.md §0.5.1（行 29）：`l3-review.sh（624 行）`。实际文件为 625 行。
- DESIGN.md D1（行 79）：`Line 201: git diff HEAD`。源码实际为 `l3-review.sh:201`（正确）。
- DESIGN.md D1（行 81）：`Line 206: 整体 diff 再用 head -c "$max_chars" 硬截断`。源码实际为 `l3-review.sh:206` — 此处是 `} | head -c "$max_chars" || true`，对整体管道输出做截断（正确）。

**Source（源头）**：精确度 — 行数/行号引用偏差小，不造成设计偏差。

**Consequence（后果）**：无实际影响。仅影响后续引用者的信任度。

**Remedy（修补）**：修正行数 624→625。可忽略不修。

---

### 🟢 R11 · DESIGN §0.5.1 "会新增"段与 D5 测量代码的矛盾

**Symptom（症状）**：
- DESIGN.md §0.5.1（行 35）："无新模块（仅在既有文件中添加函数）"。
- D5（行 143）描述在 14 个 hook 模块入口/出口插入 `_perf_timing_start()` / `_perf_timing_end()` 调用。
- "仅在既有文件中添加函数"在技术上是正确的（没有新文件），但"无新模块"掩盖了 D5 将修改 **14 个既有模块文件** 的事实。这不是零文件新增，而是宽范围的既有文件修改。

**Source（源头）**：影响面评估完整性 — "无新模块"正确但不够充分，缺失"将修改 14 个既有模块"的说明。

**Consequence（后果）**：
- 下游阶段可能低估 D5 的代码变更范围。
- 若 Phase 3 优化策略需要对多个模块做实际逻辑修改（而非仅添加测量探针），变更范围将进一步扩大。

**Remedy（修补）**：
- 将 "无新模块（仅在既有文件中添加函数）" 改为 "无新模块；将修改 common.sh + l3-review.sh + 29-independent-review.sh（核心逻辑）+ 最多 14 个 hook 模块（测量探针）"。

---

**Verdict**: pass

---

## 主 agent 响应

### R1（git diff 策略收窄）

**Fixed in**: DESIGN.md D1 — 改为并集策略：同时使用 `git diff HEAD`（保留）AND `git diff --cached`（新增），取并集对重叠文件去重。纠正了对 `git diff HEAD` 行为的错误描述。

### R2（AC-6 无具体优化策略）

**Tech-debt**: D5 的测量优先策略是刻意的——性能优化不应猜测瓶颈。v1 交付 Phase 1+2（测量基线 + 定位 Top 3 瓶颈）+ 瓶颈报告中含至少一项可实施的优化建议。若测量确认瓶颈可通过 D5 Phase 3 策略实现 ≥30% 提升，则在本次 change 内实施；若需结构性改造（如全链路异步化），则拆为独立 change。AC-6 的 30% 目标在测量后重新评估可行性。

### R3（禁动清单异常未声明）

**Fixed in**: DESIGN.md §0.5.1 — 添加禁动清单异常声明：触碰 `29-independent-review.sh` 的理由（积压扫描的唯一调度点）+ 触碰范围限定（仅入口加 `_l3_scan_backlog()` 调用）。

### R4（HTTP 状态码不可实现）

**Fixed in**: DESIGN.md D6 — 补充 `_l3_call_api()` 修改：curl 添加 `-w '\n%{http_code}'`，接口约定改为 `<body>\n<http_code>`。`_l3_parse_result()` 用 `tail -1` 提取状态码。补充了 90s 内部 timeout 与 30s wrapper timeout 的关系说明。

### R5（上下文注入与 ADR-005 张力）

**Fixed in**: DESIGN.md D4 — 取舍代价段增加与 ADR-005 的张力讨论：D4 是针对 L-040 限制⑤的工程权衡，非改变 ADR-005 架构意图。注入的 preamble 含免责声明。

### R6（风险缓解引用未设计功能）

**Fixed in**: DESIGN.md §5 R1 — 移除"按文件拆分"缓解措施，改为 `fk_estimate_tokens()` + `smart_truncate()` 尾部锚点兜底。

### R7（D3 限流未纳入算法）

**Fixed in**: DESIGN.md D3 — 算法步骤新增第 5 步限流：取队列前 3 个 phase，超出部分记录 hook 日志并推迟到下次 Stop hook。每次 Stop hook 最多触发 3 次 L3 API 调用。

### R8（尾部锚点硬编码）

**Fixed in**: DESIGN.md D2 — 取舍代价段新增 fallback：尾部扫描未匹配到任何锚点 → 回退到保留最后 `max_chars/4` 字符，并在截断元信息中标注未匹配状态。

### R9（函数命名不符合前缀约定）

**Fixed in**: DESIGN.md 全文 — `_estimate_tokens()` → `fk_estimate_tokens()`，`_perf_timing_start()` / `_perf_timing_end()` → `fk_perf_timing_start()` / `fk_perf_timing_end()`。

### R10（行数引用偏差）

**Not-applicable**: 行数偏差 ≤1 行，不影响设计决策。已修正为 625/153/263。

### R11（影响面评估不充分）

**Fixed in**: DESIGN.md §0.5.1 — "无新模块" 改为 "无新文件模块；将修改 common.sh + l3-review.sh + 29-independent-review.sh（核心逻辑）+ 最多 14 个 hook 模块（测量探针）"。
