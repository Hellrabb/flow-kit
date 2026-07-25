# 独立审查 · 阶段 1

- **Change ID**: l3-review-timeout-token
- **阶段**: 1-requirement
- **审查员**: L2 独立盲审员
- **审查日期**: 2026-07-24
- **工件**: `.specs/l3-review-timeout-token/REQUIREMENT.md`（参考 `.specs/l3-review-timeout-token/CHANGE.md`）
- **独立性声明**: 输入仅为工件文件路径，未收到主 agent 自评/草稿/概述/辩护，独立性未受损。

---

## L2 盲审

> 审查依据：阶段 1 checklist——(a) 每条 AC 是否 Given/When/Then 三段齐全且**可机器验证**；(b) v1/v2/out 范围切分是否合理，是否有范围蔓延；(c) 是否遗漏非功能性需求；(d) 需求之间是否有矛盾或歧义。

### 🔴 R1 · AC-6 不可机器验证且跨 change 耦合：端到端 AC 绑定外部 API 与另一 change 产物
**Symptom**: `REQUIREMENT.md` AC-6（L56-61）的端到端验收依赖：外部 deepseek API 实时可用 + `gate-done-authorship` change 的 `INDEPENDENT-REVIEW-3.md` 产物存在；Then（L60）要求"写入 `INDEPENDENT-REVIEW-3.md` 的 `## L3 重审` 段"；验证方式（L61）为手动 `source` + 打真实 API，断言 `rc ∈ {0,1}`。
**Source**: 阶段 1 checklist 硬要求"每条 AC 是否 Given/When/Then 三段齐全且**可机器验证**"；spec 合规要求 AC 可独立、可重复验证，验收线须由本 change 单独满足。
**Consequence**: AC-6 在离线 CI 永远不可验证；deepseek 抖动/限流/模型升级、或 `gate-done-authorship` 的 `INDEPENDENT-REVIEW-3.md` 结构/产物变动，都会令本 change 已正确实施却 AC-6 fail；把外部 API 稳定性 + 另一 change 的产物结构绑进本 change 验收线，验收线永远无法由本 change 独立满足——spec 合规失败。
**Remedy**: 拆分职责——(a) 请求体/`thinking` 字段正确性交给 AC-1~AC-5 的离线 mock 测试（见 R2）；(b) AC-6 降级为"手动冒烟"附录项，显式标注"依赖外部 API，非离线可验证，不纳入回归验收线"；(c) 若保留 AC-6 于验收线，Then 删除对 `INDEPENDENT-REVIEW-3.md` 的写入断言，收敛为"`rc ∈ {0,1}` 且 summary 非空"，并解除与 `gate-done-authorship` 产物的耦合（与 R5 一并处理）。

### 🟡 R2 · AC-1~AC-5 的 bats 验证未指定 curl mock/拦截策略，与"AC 是 TEST 唯一来源"冲突
**Symptom**: AC-1~AC-5 验证方式均为"bats source 后调用断言请求体含 `max_tokens":X` / `thinking` 字段"（L24/31/38/45/54），但 `_l3_call_api()` 实际发起 `curl` 网络请求；REQUIREMENT 全文未说明如何在不打真实 API 的情况下捕获请求体（如 stub curl 函数 / netcat 拦截 / httpbin 回放）。
**Source**: `REQUIREMENT.md` L124"AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC"；阶段 1 checklist"可机器验证"。
**Consequence**: TEST 阶段必须自行设计 mock 基础设施——这相当于在 TEST 引入 REQUIREMENT 未定义的设计决策，违反 L124；或测试只能打真实 API，使 AC-7"全量 bats 0 fail"在离线 CI 永远 fail；mock 策略缺失使 AC-1~AC-5 的"可机器验证"实质落空。
**Remedy**: 在 REQUIREMENT 增补一条 AC（或在 AC-1~AC-5 每条验证方式中）明确 mock 策略——如"bats 用函数覆盖（stub）`_l3_call_api` 内的 `curl`，捕获传入参数并断言请求体字段"，让 mock 方式成为 AC 的一部分而非 TEST 自由裁量。

### 🟡 R3 · Fail-safe 非功能性需求未转 AC，且 thinking 枚举型 env var 的非法值未覆盖
**Symptom**: 非功能性 L108"env var 值非法（非数字 / 空）→ 回退默认值 + hook log 警告（不崩溃）"——全文无对应 AC；且该描述只覆盖数字型（`max_tokens` / `timeout`），未覆盖 `FLOW_KIT_L3_THINKING` 的枚举非法值（如 `yes` / `true` / `0` / 空）。可观测性 L107"env var 覆盖值记录 hook log"同样无 AC。
**Source**: 阶段 1 checklist"是否遗漏非功能性需求"；AC 须可验证原则——非功能性需求须转 AC 才能在 TEST 验证。
**Consequence**: `max_tokens`/`timeout` 传垃圾值、`thinking` 传非 `{enabled,disabled}` 值时，实现是否回退默认 + 告警无法验证，Fail-safe 形同虚设；`thinking` 非法值可能透传给 API 导致请求失败，制造新的 rc=3（本 change 要解的病复发）。
**Remedy**: 补 AC-8（Fail-safe）：Given `FLOW_KIT_L3_MAX_TOKENS`/`FLOW_KIT_L3_TIMEOUT` 为非数字或空 → Then 回退默认 + hook log 警告；Given `FLOW_KIT_L3_THINKING` 非 `{enabled,disabled}` → Then 按 `enabled` 默认处理 + 警告。可观测性 L107 的"hook log 记录覆盖值"建议并入或单列 AC。

### 🟡 R4 · 范围 v1 要求两处路径同步改，但 AC 无分路径断言，路径2 漏改不可检出
**Symptom**: v1 范围 `REQUIREMENT.md` L79"两处请求体（路径1 阿里云代理 / 路径2 Anthropic 直连）同步改"；但 AC-1~AC-5 的 Then/验证方式均只说"请求体含 X"（L23/30/37/44/52-53），未区分路径1/路径2，未要求两条路径各跑一次断言。
**Source**: AC 须覆盖范围声明的全部行为面；等价类划分——两条代码路径（阿里云代理 vs Anthropic 直连）是独立等价类，须分别覆盖。
**Consequence**: 实现只改路径1 漏改路径2（Anthropic 直连）时，AC-1~AC-5 全 pass 但实际 L3 在路径2 仍 rc=3 超时；AC-6 手动冒烟若恰好走路径1 也不暴露——回归保护缺失。
**Remedy**: AC-1~AC-5 每条验证方式增加"分别对路径1（阿里云代理）与路径2（Anthropic 直连）各断言一次"；或新增一条 AC 专断"两处请求体同步可配置 + 默认值一致"。

### 🟡 R5 · AC-6 Then 与验证方式内部矛盾
**Symptom**: AC-6 Then（L60）要求"产出 verdict（pass 或 fail）+ summary，写入 `INDEPENDENT-REVIEW-3.md` 的 `## L3 重审` 段"；但验证方式（L61）只断言"返回 `rc=0`（pass）或 `rc=1`（fail），非 `rc=3`"。
**Source**: AC 四要素一致性——Then 断言集须与验证方式可观测项一一对应。
**Consequence**: 若实现返回 `rc=0` 但未写文件/无 summary，按 Then 应 fail，按验证方式却 pass——验收结论取决于用哪一条，产生争议；TEST 阶段无法确定以哪条派生用例。
**Remedy**: 统一一处——要么验证方式补"且 `INDEPENDENT-REVIEW-3.md` 含 `## L3 重审` 段且 summary 非空"，要么 Then 收敛为"`rc ∈ {0,1}`"删除文件写入断言（与 R1 的跨 change 耦合一并处理）。

### 🟡 R6 · CHANGE.md 声明"不需要 REQUIREMENT.md"却实际存在 REQUIREMENT.md，流程自相矛盾
**Symptom**: `CHANGE.md` L40 影响面声明"不需要新增/修改 REQUIREMENT.md：纯 bug 修复，无新需求"（且该行勾选状态为 `[ ]` 未完成）；但 `.specs/l3-review-timeout-token/REQUIREMENT.md` 实际存在（6.1K，7 条 AC + 非功能性 + 范围切分）。
**Source**: change 流程一致性——影响面声明须与实际产物一致；阶段 gate 若依 CHANGE 声明判定会与实际产物冲突。
**Consequence**: 阶段 1 审查对象本不应存在却存在，无法判断该走"跳过需求审查"还是"完整需求审查"；后续 gate 检查若依 CHANGE 声明会与实际产物冲突，影响可追溯性与 gate 判定。
**Remedy**: 二选一——(a) 修订 `CHANGE.md` 影响面声明为"需要 REQUIREMENT.md"并勾选对应项，与本次审查对齐（推荐，因 AC 已具审查价值）；(b) 若坚持纯 bug 修复路线，则删除 REQUIREMENT.md（不推荐）。

### 🟢 R7 · AC-5 把一次性实测数据当作 Then 断言
**Symptom**: AC-5 Then（L53）"disabled 时 deepseek-v4-pro 不扩展思考（58.4s 返回 3334 token 含 text block，L3 子 agent 实测）"。
**Source**: AC 应描述期望行为/不变式，非历史实测快照；TEST 派生用例须可重复。
**Consequence**: TEST 阶段若照搬 58.4s/3334 token 做断言会永远 flaky（下次跑数值不同）；把单次实验当规格会误导实现与测试。
**Remedy**: Then 改为"请求体含 `thinking:{type:"disabled"}`；响应含 `type=text` 的 content block（非仅 thinking block）"——去掉具体秒数与 token 数。

### 🟢 R8 · AC-5 Then 断言 API 侧行为超出工具可控范围
**Symptom**: AC-5 Then 断言"deepseek-v4-pro 不扩展思考"——这是 API 侧行为，工具侧只能保证请求体含 `thinking:{type:"disabled"}`，无法保证 API 不返回 thinking block（API 可能忽略该字段）。
**Source**: AC 须限定在被测系统可控边界内；工具验收断言应针对工具产出（请求体）而非第三方服务行为。
**Consequence**: API 升级忽略 `thinking:{type:"disabled"}` 时，本 change 实施正确却 AC-5 fail——产生误报，把外部服务行为计入本 change 验收。
**Remedy**: Then 收敛为"请求体含 `thinking:{type:"disabled"}`"（工具侧可控）；API 侧行为作为假设写入"依赖与假设"段，不进 Then。

---

**Verdict**: fail

存在 1 条 🔴 Critical（R1：AC-6 不可机器验证 + 跨 change 耦合，spec 合规失败）。另有 5 条 🟡 Major（R2 mock 策略缺失 / R3 Fail-safe 未转 AC / R4 两路径无分路径断言 / R5 AC-6 Then 与验证方式矛盾 / R6 CHANGE 与 REQUIREMENT 流程矛盾）与 2 条 🟢 Minor（R7 实测当断言 / R8 断言超出可控范围）。R1~R5 互相关联，建议一并重写 AC-1~AC-7 与 Fail-safe 段后再进阶段 2。

---

## L2 盲审（第二轮 · 修复后复核）

⚠️ 独立性受损：检测到主 agent 上下文注入（任务参数"注意"段枚举了主 agent 对 R1-R8 的具体 Fixed in 行动：重写 REQUIREMENT、AC-6 降级为 AC-9 手动冒烟、补 mock/Fail-safe/双路径/可观测性 AC、删实测数据、工具侧边界、CHANGE L40 修订）。按硬约束须标注于此。下文据 `.specs/l3-review-timeout-token/REQUIREMENT.md`（148 行）与 `CHANGE.md` 原文独立复核，不采信上述修复声明。

- **Change ID**: l3-review-timeout-token
- **阶段**: 1-requirement（修复后复核）
- **审查员**: L2 独立盲审员
- **审查日期**: 2026-07-24
- **工件**: `.specs/l3-review-timeout-token/REQUIREMENT.md`（参考 `.specs/l3-review-timeout-token/CHANGE.md`）
- **复核方法**: 重新通读 REQUIREMENT.md 全文 + CHANGE.md，逐条独立核验首轮 R1-R8，并扫描重写是否引入新问题或残留。

### 首轮 R1-R8 复核结论

| ID | 原严重度 | 复核结论 | 核验依据（工件原文） |
|----|----------|----------|----------------------|
| R1 | 🔴 Critical | **Fixed**（见 R10 拘留） | 端到端 AC 已降级为 AC-9（L84-90），Then 收敛为 `rc ∈ {0,1}` 且 summary 非空（L88），删除 `INDEPENDENT-REVIEW-3.md` 写入断言；降级声明（L90）"非离线可验证，不纳入回归验收线（AC-8 全量 bats 不含此项）…不影响本 change 的 spec 合规判定"。回归线 AC-1~AC-8 全部离线可验证。**但** CHANGE 验收线 #4 未同步，见 R10。 |
| R2 | 🟡 Major | **Fixed** | REQUIREMENT L17 新增"Mock 策略（R2 落地 · 贯穿 AC-1~AC-5）"块，明确 stub curl 捕获请求体、"此 mock 方式是 AC 的一部分，TEST 阶段不得自由裁量"；AC-1~AC-5 验证方式均含"stub curl"。见 R11 措辞歧义。 |
| R3 | 🟡 Major | **Fixed** | 新增 AC-6（Fail-safe，L59-68）覆盖三 env var 非法值（含 thinking 枚举非法 `yes`）+ 回退默认 + stderr 警告；新增 AC-7（可观测性，L70-75）断言 stderr 配置记录行。非功能性 Fail-safe（L130）/可观测性（L129）均有对应 AC。 |
| R4 | 🟡 Major | **Fixed**（仅 AC-1~AC-5） | AC-1~AC-5 Then 均"两条路径…"，验证方式均"双路径"/"分别路径1/路径2"（L26/33/40/47/56）。**但** 双路径断言未延伸至新增 AC-6/AC-7，见 R9。 |
| R5 | 🟡 Major | **Fixed** | AC-9 Then（L88）与验证方式（L89）一致：均断言 `rc ∈ {0,1}` + summary 非空；`INDEPENDENT-REVIEW-3.md` 写入断言已从两处删除。 |
| R6 | 🟡 Major | **Fixed** | CHANGE.md L40 已修订为 `[x] **需要新增/修改 REQUIREMENT.md**`并附理由，与实际产物一致。**但** CHANGE 验收线 #4 未同步修订，见 R10。 |
| R7 | 🟢 Minor | **Fixed** | AC-5 Then（L55）已删除 58.4s/3334 token 实测数据，改为"工具侧请求体字段正确（disabled 含字段 / enabled 不含）"；实测数据移至"依赖与假设"L141 作假设佐证 + R8 边界声明。 |
| R8 | 🟢 Minor | **Fixed** | AC-5 Then（L55）仅断言工具侧请求体字段；L57 新增"边界声明（R8 落地）：AC-5 只断言工具侧请求体字段，不断言 API 侧是否实际不扩展思考"；API 侧行为移至"依赖与假设"L141。 |

首轮 1 条 🔴 Critical（R1）已在 REQUIREMENT 层面解除（端到端降级为非 gating 手动冒烟，回归线 AC-1~AC-8 全离线可验证）。下述为重写后引入或首轮修复"未贯穿"的残留。

### 🟡 R9 · 双路径断言未延伸至新增 AC-6/AC-7：path2 Fail-safe/可观测性漏改不可检出
**Symptom**：REQUIREMENT AC-6（Fail-safe，L59-68）When/验证方式未指定路径1/路径2——其 When 列举 `FLOW_KIT_L3_MAX_TOKENS=abc → 请求体 max_tokens 回退默认 32000`、`FLOW_KIT_L3_TIMEOUT=xyz → curl --max-time 回退默认 300`（L63/65），而"请求体 max_tokens"（路径1 L350 / 路径2 L366）与"curl --max-time"（路径1 L346 / 路径2 L362）均为 per-path 构造；AC-7（可观测性，L73）When 显式"触发路径1"仅测单路径。两者均未要求双路径断言。
**Source**：R4 确立的原则——两条代码路径（阿里云代理 vs Anthropic 直连）是独立等价类，须分别覆盖；AC 须覆盖范围声明的全部行为面。AC-6 断言对象（请求体字段、curl 参数）与 AC-1~AC-5 同属 per-path 构造，应适用同一原则。
**Consequence**：实现只对路径1 加 Fail-safe 回退/告警、漏改路径2 时，AC-6 仍 pass（若仅测路径1 或未指定路径），路径2 在非法 env var 下仍透传垃圾值 → 制造新 rc=3（本 change 要解的病在路径2 复发）；AC-7 同理，路径2 的配置记录行缺失不可检出。
**Remedy**：AC-6 验证方式改为"四个非法值用例 × 双路径（stub curl 分别对路径1/路径2 断言回退 + grep stderr 警告）"；AC-7 要么补"双路径均断言 stderr 含配置记录行"，要么在 AC-7 显式声明"配置记录行在路径分支前统一发射、路径无关，故仅测路径1"（若实现确实如此）。

### 🟡 R10 · CHANGE 验收线 #4 仍列端到端为 done 准则，与 REQUIREMENT AC-9 降级声明矛盾（R1 修复未贯穿至 CHANGE）
**Symptom**：CHANGE.md L84 验收线（粗粒度 · done line）#4："**端到端**：gate-done-authorship phase 3 的 L3 第二轮复核能跑通（verdict=pass 或 fail，但不再 rc=3 超时/空响应）"——无"非 gating / 手动冒烟 / 不影响 spec 合规"任何限定；而 REQUIREMENT AC-9 降级声明（L90）称"非离线可验证，不纳入回归验收线…不影响本 change 的 spec 合规判定"。R6 修复仅改了 CHANGE L40 影响面，未同步修订验收线 #4。
**Source**：change 流程一致性——影响面/验收线声明须与 REQUIREMENT AC gating 语义一致；R1 Critical 的病根正是"把外部 API + 另一 change 产物绑进验收线，验收线离线不可满足"。
**Consequence**：若阶段 gate 依 CHANGE 验收线判定 transition，则端到端（#4）仍为 done 准则 → done 仍依赖外部 deepseek API 实时可用 + gate-done-authorship phase 3 产物 → R1 的 Critical（验收线离线不可满足）实际未解除，仅从 REQUIREMENT 转移至 CHANGE；若 gate 依 REQUIREMENT AC-9 降级声明判定，则两文档口径不一，审查员/gate 无法确定 done 是否需端到端。若确认 done-line gating，本条应升 🔴。
**Remedy**：二选一——(a) 修订 CHANGE 验收线 #4，标注"端到端为手动冒烟附录，非离线 gating，不影响 spec 合规判定"，与 AC-9 降级声明对齐（推荐）；(b) 若 done 确需端到端，则显式拆分两层语义："spec 合规（AC-1~AC-8，离线 gating）"与"解套确认（AC-9，手动，API 可用时执行）"，并在 gate 机制明确仅前者 gating。任一选须消除两文档口径冲突。

### 🟢 R11 · Mock 策略块措辞自相矛盾：stub curl vs 定义 _l3_call_api 测试替身
**Symptom**：REQUIREMENT L17"Mock 策略"块前半"bats 用函数覆盖（stub）`_l3_call_api` 内的 `curl` 命令"（stub curl，保留真实 `_l3_call_api()` 跑请求体构造），破折号后半"——定义 `_l3_call_api()` 的测试替身"（替换整个 `_l3_call_api()`）。两者是不同测试设计：前者捕获真实函数构造的请求体（断言有意义），后者由替身自造请求体（断言沦为同义反复，无法捕获 `_l3_call_api()` 未读 env var / 未应用默认值的 bug）。
**Source**：AC 须可验证且无歧义——mock 策略是 AC 的一部分（L17 自述），措辞须令 TEST 无二义派生。
**Consequence**：TEST 实施者若按后半句字面"定义 `_l3_call_api()` 测试替身"，则 AC-1~AC-5 的请求体断言对真实实现零覆盖（替身自造自验），R2 落地的 mock 有效性落空。
**Remedy**：L17 后半改为"——即定义 `curl` 的测试替身（函数覆盖），令真实 `_l3_call_api()` 调用该替身 curl，捕获其 `-d` 请求体与 `--max-time` 参数"，明确 stub 在 curl 层、`_l3_call_api()` 保持真实。

### 🟢 R12 · 空字符串非法值覆盖不全 + thinking 空串归类未指定
**Symptom**：AC-6（L62-66）显式列举 `FLOW_KIT_L3_MAX_TOKENS=`（空，L64）回退，但未列举 `FLOW_KIT_L3_TIMEOUT=`（空）与 `FLOW_KIT_L3_THINKING=`（空）；AC-5（L54）"FLOW_KIT_L3_THINKING=enabled（或未设）"未界定空串属"未设"（静默按 enabled、无警告）还是"非法"（按 enabled + stderr 警告）。
**Source**：等价类划分须显式覆盖各非法等价类代表；AC 须无歧义。bash 中 `VAR=`（空串）与 unset 语义不同。
**Consequence**：实现若对 timeout 空串不做回退（仅查非数字），或对 thinking 空串归类不一，AC 无断言则行为不可验证，可能透传空串给 API 制造请求失败。
**Remedy**：AC-6 补 `FLOW_KIT_L3_TIMEOUT=` 空串用例；AC-5/AC-6 显式声明 `FLOW_KIT_L3_THINKING=`（空串）归类（建议归"未设"→ 不含 thinking 字段、无警告，与 unset 同），并在 AC-6 列或不列该用例与之对齐。

---

**Verdict**: pass

首轮 🔴 Critical（R1）已在 REQUIREMENT 层解除（端到端降级为非 gating 手动冒烟，回归线 AC-1~AC-8 全离线可验证），本轮无 🔴 Critical。新增 2 条 🟡 Major（R9 双路径未延伸至 AC-6/AC-7 / R10 CHANGE 验收线 #4 与 AC-9 降级声明矛盾——R1 修复未贯穿至 CHANGE，若 gate 依验收线判定则 R1 Critical 复发）+ 2 条 🟢 Minor（R11 mock 措辞歧义 / R12 空串覆盖不全）。R9/R10/R11/R12 均为首轮修复"未贯穿"或重写引入的残留，建议一并处理后进阶段 2。按规则（fail 当且仅当存在 🔴 Critical），本轮 pass；但 R10 须由主 agent 确认 gate 语义——若 done-line 实际 gating，R10 升 🔴，本轮应翻 fail。

---

## L3 重审（deepseek-v4-pro 外部模型 · 2026-07-24 15:48）

> 自动生成于 2026-07-24 15:48。由 l3-review.sh 写入（手动触发 · thinking=disabled 绕过 90s 超时 + 8000 max_tokens 限制）。

### 审查结论

```json
```json
{
  "critical": [],
  "major": [
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-5 的 Given 声明 '原请求体无 thinking 字段' 为不可验证的隐含前提，且 When 中 'FLOW_KIT_L3_THINKING=enabled（或未设）→ 两条路径请求体均不含 thinking 字段' 与默认行为存在逻辑冲突：若未设 env var 时请求体本就不含 thinking 字段，则无法区分 'enabled 显式覆盖' 与 '默认 enabled 行为' 的差异，且无法验证 'enabled 显式设置' 这一路径是否正确执行。",
      "why": "Given 声明 '原请求体无 thinking 字段' 是代码修改前状态，但 AC 本身未提供验证该前置条件的方法。When 中将 'enabled' 与 '未设' 合并为同一预期结果（均不含 thinking 字段），导致两个不同输入条件产生相同输出，无法区分 'env var 被正确读取并处理' 与 'env var 未被读取而恰好默认行为一致' 两种情况。这违反了 AC 可验证性原则——无法证明 enabled 显式设置确实被执行了而非被忽略。",
      "fix": "将 AC-5 拆分为两个独立条目：AC-5a 验证 FLOW_KIT_L3_THINKING=enabled 显式设置时请求体不含 thinking 字段（以区别于未设 env var 的基线行为）；AC-5b 验证 FLOW_KIT_L3_THINKING=disabled 时请求体含 thinking:{type:disabled}。同时移除 Given 中对 '原请求体' 的依赖声明，改为 'Given bats stub curl 捕获请求体' 即可。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-6 中 FLOW_KIT_L3_THINKING=yes（非法枚举值）的预期行为 '请求体均不含 thinking 字段 + stderr 警告' 与 FLOW_KIT_L3_THINKING=空时的预期行为 '按 enabled 默认 + 警告' 使用了不同措辞描述相同结果，但未明确说明 '不含 thinking 字段' 与 '按 enabled 默认' 是否等价。若二者等价，则 wording 不一致造成歧义；若不等价，则空值的回退行为未明确定义。",
      "why": "AC-6 对 thinking 非法值的 Then 描述为 '请求体均不含 thinking 字段（按 enabled 默认）'，但对 thinking=yes 的描述为 '请求体均不含 thinking 字段'，缺少 '按 enabled 默认' 的明确声明。读者可能推断 yes 的回退行为与空值不同，但实际应一致。这种 wording 不一致影响 TEST 阶段用例派生的准确性。",
      "fix": "统一措辞：将 FLOW_KIT_L3_THINKING=yes 的 Then 改为 '两路径请求体均不含 thinking 字段（按 enabled 默认）+ stderr 警告'，与空值用例保持一致。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-9 的 When 条件中包含具体 change ID 'gate-done-authorship' 和具体路径 '.specs/gate-done-authorship'，将冒烟测试绑定到特定外部依赖，且该 change 可能不存在于其他 flow-kit 实例中，导致 AC-9 不可迁移、不可复现。",
      "why": "AC-9 声称为 '端到端冒烟' 且 '非回归验收线'，但其 When 条件硬编码了 gate-done-authorship 这一具体 change，构成对特定外部状态的依赖。若该 change 被删除、重命名或产物变更，AC-9 将无法执行。这与 AC 的 '可验证' 原则冲突——即使降级为手动附录，AC 仍应具备可复现性。",
      "fix": "将 AC-9 的 When 条件泛化为 'Given 本 change 实施完成 + deepseek-v4-pro API 可用 + 任一已完成 phase 2 的 change 存在'，或明确声明该 AC 仅适用于当前 gate-done-authorship 解套场景，且不作为通用 AC。"
    }
  ],
  "minor": [
    {
      "file": "REQUIREMENT.md",
      "issue": "范围切分 v1 中声明 'max_tokens 8000→32000，timeout 90→300'，但非功能性需求的性能部分写 '默认 timeout 提至 300s，单次 L3 审查最坏情况 ~5min'，此处 300s=5min 精确，但 max_tokens 从 8000 提升至 32000（4 倍）对 token 消耗和成本的影响未被评估或记录。",
      "why": "虽然非功能性需求中未要求成本评估，但 max_tokens 提升 4 倍可能显著增加 API 调用成本。若此为已知且可接受的风险，应在依赖与假设或非功能性需求中明确记录，以便后续审查者理解决策依据。",
      "fix": "在非功能性需求或依赖与假设中补充一条声明：'max_tokens 默认值提升至 32000 可能增加 API token 消耗成本，该成本已评估为可接受（或由用户通过 env var 自行控制）'。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-1 至 AC-7 的验证方式均写 'bats test/test_l3_review.bats'，但未声明这些测试用例是需要新增还是修改既有测试文件，也未说明测试用例命名或组织方式，可能导致 TEST 阶段自由裁量测试结构。",
      "why": "AC 的验证方式应足够明确以指导 TEST 阶段派生用例，但当前仅指向测试文件路径，未说明测试用例的预期结构（如是否新增独立 test 函数、命名约定等）。虽不构成 critical，但增加了 TEST 阶段的歧义。",
      "fix": "在验证方式中补充说明：'在 test/test_l3_review.bats 中新增测试函数（如 test_l3_max_tokens_default、test_l3_max_tokens_env_override 等），或明确声明由 TEST 阶段自行决定测试用例组织方式。'"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "Mock 策略声明 '禁止 stub 整个 _l3_call_api 函数' 属于实现约束而非需求，且该约束在 AC-1~AC-7 的 Given 中被重复引用为 'bats stub curl'。若未来重构导致 _l3_call_api 内部 curl 调用方式变更（如改用其他 HTTP 客户端），该 mock 策略可能成为技术债务。",
      "why": "需求文档中的 mock 策略约束了实现方式，但该约束属于测试设计决策而非用户需求。将其置于 AC 前置声明中可能限制实现灵活性。不过当前阶段此约束有明确合理性（保证请求体构造逻辑被测），故仅为 minor。",
      "fix": "将该 mock 策略移至独立的设计决策文档（如 DESIGN.md）或 TEST 阶段的测试策略章节，而非在需求 AC 中作为硬性约束。若保留在 AC 中，应明确声明其适用范围仅限当前实现版本。"
    },
    {
      "file": "REQUIREMENT.md",
      "issue": "AC-8 的 When 条件写 '执行 make test（或 npx bats test/）'，使用 '或' 连接两个不同命令，但未说明二者是否等价、以哪个为准。若 make test 内部调用 npx bats test/ 则等价，但 AC 未提供此保证。",
      "why": "AC 应给出明确的单一验证命令，或声明两个命令等价。当前 '或' 的措辞可能导致不同执行者使用不同命令，若二者行为不一致（如 make test 包含额外前置步骤），则 AC-8 的验证结果不可靠。",
      "fix": "明确指定单一验证命令（如 'make test'），或声明 'make test 等效于 npx bats test/'。"
    }
  ],
  "verdict": "pass",
  "summary": "AC 整体可验证且范围切分合理，但 AC-5 的 enabled/未设 合并断言存在逻辑不可区分问题、AC-9 硬编码特定 change 导致不可迁移，以及若干 wording 不一致和实现约束混入需求的问题，均为 major 或 minor，无 critical 阻塞项。"
}
```
```

L3_artifact_hash: 9c0f7a2675bea92cae5f68ce959184673d3471fee756d7e6e8f6bdb07e8b3abe
