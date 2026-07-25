# 独立审查 · 阶段 2

> 盲审员：L2 独立盲审（architect-reviewer 角色）
> 工件：`.specs/l3-review-timeout-token/DESIGN.md`
> 参考：`.specs/l3-review-timeout-token/REQUIREMENT.md`、`.specs/l3-review-timeout-token/CHANGE.md`、`.specs/CONTEXT.md`、`.specs/ARCHITECTURE.md`、`flow-kit-bundle/hooks/stop/lib/l3-review.sh`
> 输入清洁度：仅收到固化指令 + 工件路径，未检测到主 agent 自评/草稿/辩护注入。

---

## L2 盲审

### 🟡 R1 · 失败机理刻画与实际代码不符：jq 三路 fallback 被忽略，"rc=3"结论未经验证

**Symptom**：`DESIGN.md` §2.1（L86-90「修改前」图）将失败路径写成 `jq select(.type=="text") 返空 → rc=3`；同一断言在 `CHANGE.md:15` 与 `CONTEXT.md:226`（域语言「L3 思考吃满预算」条）复述。但实际 `l3-review.sh:378` 的 jq 表达式是：

```
[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty
```

含 **三路 fallback**（首 text block → `content[0].thinking` → `content[0].text` → empty）。`CHANGE.md:19` 的实测仅观察到 `content[].type=thinking`（无 text），**从未核查 thinking 块的字段名**（是否含 `.thinking` / `.text`），故无法断定三路 fallback 是否全部落空。若 thinking 块带 `.thinking` 或 `.text` 字段，代码会**提取思考内容**（非空、非 rc=3），下游把思考文本当 verdict JSON 解析 → 静默错判。

**Source**：独立性硬约束「证据优先于解释」；DESIGN 阶段 checklist「风险段是否遗漏关键风险，或低估了概率/影响」。实际代码 `flow-kit-bundle/hooks/stop/lib/l3-review.sh:378`。

**Consequence**：实现者按 §2.1 理解「失败=rc=3 空响应」，真实路径可能是「思考内容被当 verdict」。更严重的是 `DESIGN.md:144` R3 把 `enabled` 仍吃满 32k 的后果写成 `→ rc=3`——若真实后果是**静默错判**（让坏 change 过 gate / 好 change 被误毙），则风险被严重低估：可见的 rc=3 至少让 pipeline 停住求助，静默错判则无声放行。

**Remedy**：4-dev 前先对 `CHANGE.md:19` 的实测响应样本（`content[].type=thinking`）执行 `jq '.content[0]'` 打印完整结构，确认三路 fallback 是否落空。据实测结果修正 `DESIGN.md` §2.1 失败机理与 §5 R3 后果：若 fallback 不落空，须把「静默错判（思考文本被当 verdict）」列为风险，并考虑 `_l3_call_api` 只接受 `.type=="text"` block（若超 scope，至少登记技术债并在 R3 注明真实后果）。

---

### 🟡 R2 · 「遵循 env-var-first 3 级链」的论证与实现不符：实际为 2 级，且越出策略明定范围

**Symptom**：`DESIGN.md` 在 D1（L67）、D6（L72）、§0.5.2（L46）、§0.5.3（L54）、§4（L134）、§9.3（L176）反复声称三个新 env var「遵循 env-var-first config 策略（env var > stop-hook.json > 硬编码）」并据此得出 D6「不新增 ADR」。但三处不实：

- (a) `CONTEXT.md:145` 明定该策略「**当前仅应用于模型名和 API endpoint 配置**」——`max_tokens` / `timeout` / `thinking` 既非模型名也非 endpoint，属 L3 调参，越出明定范围；
- (b) `DESIGN.md` §2.2（L98-100）数据流 `max_tokens = ${FLOW_KIT_L3_MAX_TOKENS:-32000}` 是 bash 惯用法，**只实现 2 级**（env var > 硬编码），跳过 `stop-hook.json` 中间级，与所声称的 3 级链不符；AC-1~AC-7 亦仅测 env var + 默认，无 stop-hook.json 用例；
- (c) D1 称「与既有 `FLOW_KIT_L2_MODEL`/`L3_MODEL` 同模式」，但后者经 `fk_resolve_model`（3 级解析器，`CONTEXT.md:81`/`:84`），新 var 用裸 `${VAR:-default}`（2 级），**并非同模式**。

**Source**：`CONTEXT.md:145`（策略定义+范围限定）、`:81`/`:84`（fk_resolve_model 3 级链）；DESIGN checklist「是否撞既有架构/跨模块契约」+「ADR 决策须有充分理由（为什么选 X 不选 Y）」。

**Consequence**：「不新增 ADR」的论证立足于对既有策略的错误刻画（范围越界 + 链级缩减）。后续 change 若按「env-var-first=3 级」假设给这些 var 补 `stop-hook.json` 支持，会发现中间级从未实现；审查者按「3 级」理解会漏掉中间级缺失。D6 的结论（不加 ADR）或可成立，但**理由须诚实**——是「小参数无需 ADR」而非「复用既有 3 级策略」。

**Remedy**：`DESIGN.md` 将措辞改为「新增 2 级配置（env var > 硬编码），借鉴 env-var-first 哲学但**不复用**其 3 级链与 stop-hook.json 中间级」，并据此重写 D6 理由；或在 4-dev 顺带补 `stop-hook.json` 中间级使其名副其实（则须同步补 AC）。

---

### 🟡 R3 · `thinking=enabled` 默认对「大产物」目标场景零证据，与 US-2 不自洽

**Symptom**：`DESIGN.md` D3（L69）默认 `thinking=enabled`，理由是「首轮 L3 verdict=fail 9 条全可核实无幻觉，证明思考有益」。但首轮是**较小产物**（思考在 8000 token 内完成，`CHANGE.md:27`）。**触发本 change 的大产物场景**（`CHANGE.md:28` 第二轮失败）从未在 `enabled + 32k` 下验证过能产出 text block。对该场景**唯一验证过的可用配置是 `disabled`**（`CHANGE.md:29`：58.4s 返 3334 token 含干净 text block）。`DESIGN.md:144` R3 把「enabled 吃满 32k」称为「极端情况」，但大产物正是本 change 的**目标场景**（`REQUIREMENT.md:11` US-2「承载大产物审查」），非极端。

**Source**：独立性硬约束「证据优先于解释」；`REQUIREMENT.md:11` US-2 要求承载大产物审查，但默认配置（enabled+32k）对该场景零证据，唯一证据（`CHANGE.md:29`）属 `disabled`。

**Consequence**：默认配置正是**未对目标场景验证**的配置。若 deepseek-v4-pro 的思考量随 `max_tokens` 正比扩张，32k 仍可能被思考吃满 → 复发失败（rc=3 或按 R1 的静默错判）。用户拿到一个声称「解套」的 change，默认却走未验证路径，与 US-2 的承诺不自洽。

**Remedy**：默认改为 `disabled`（对大产物场景唯一已验证可用的配置），`enabled` 作为 opt-in（推理质量优先、产物可控时显式开）；或 4-dev/TEST 前用真实 deepseek API 对 `enabled + 32k` + 大产物（gate-done-authorship phase 3）实测一次，确认产出 text block 后再定为默认。`AC-9` 冒烟应专门覆盖 `enabled` 默认路径而非任意配置。

---

### 🟡 R4 · R2 风险缓解立足于对第三方代理 max_tokens 上限的未验证断言

**Symptom**：`DESIGN.md` R2（L143）以「阿里云代理/Anthropic 直连均支持大 max_tokens」作为 32k 默认不致 400 的缓解。但本 change 全部实测（`CHANGE.md:19`）只跑过 `max_tokens=8000`，**从未对阿里云 deepseek 代理验证 32000**。Anthropic 直连支持大 max_tokens ≠ 阿里云 deepseek 代理支持。本 change 的存在理由正是 Path 1（阿里云 deepseek）失败（`ARCHITECTURE.md:327` `ANTHROPIC_BASE_URL` 消费方含 l3-review.sh），把 Path 1 默认提到未验证的 32k 是把缓解建立在断言上。

**Source**：DESIGN checklist「风险段是否低估概率/影响」；证据优先原则。`CHANGE.md:19` 实测仅含 8000。

**Consequence**：若阿里云 deepseek 代理 `max_tokens` 上限低于 32000（如 8192/16384），默认值在 Path 1 直接 400 → rc=3，与本 change「解套 Path 1」的目标**相反**；fail-open 哲学下用户需自行发现 400 并下调，解套体验差。

**Remedy**：4-dev 前对阿里云 deepseek 代理实测一次 `max_tokens=32000` 是否被接受（或查代理文档上限）；若不支持，Path 1 默认下调至代理上限（或 Path 1/Path 2 分别默认）。在 `DESIGN.md` R2 注明实测结果，勿留断言。

---

### 🟢 R5 · `ARCHITECTURE.md` 环境变量登记表未列入本次同步待办

**Symptom**：`ARCHITECTURE.md:326-328` 有 env var 登记表（`ANTHROPIC_DEFAULT_HAIKU_MODEL` / `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`，消费方 `l3-review.sh`）。本 change 新增 3 个 env var（`FLOW_KIT_L3_MAX_TOKENS` / `TIMEOUT` / `THINKING`），`CONTEXT.md:225-228` 已加域语言条目，但 `DESIGN.md` §9（L160-189）架构沉淀**未列**「更新 `ARCHITECTURE.md` env var 表」为待办。

**Source**：`ARCHITECTURE.md:9`「每个 change 都要对照 CONTEXT 禁动清单/既有抽象」；`ARCHITECTURE.md:326-328` env var 表。

**Consequence**：`ARCHITECTURE.md` env var 表与实际偏离，后续读架构者漏见 3 个新 var 的消费方。

**Remedy**：`DESIGN.md` §9 补一条待办「更新 `ARCHITECTURE.md` env var 登记表（加 3 个 `FLOW_KIT_L3_*` var，消费方 `l3-review.sh`）」作为 4-dev/5-test 同步项。

---

**Verdict**: pass

无 🔴 Critical。4 条 🟡 Major（R1 失败机理与代码不符、R2 env-var-first 论证与实现不符、R3 默认配置对目标场景零证据、R4 代理上限断言未验证）+ 1 条 🟢 Minor（R5 架构表同步）。按「修代码优先」协议，主 agent 须对每条 🔴/🟡 给出 `Fixed in:` / `Tech-debt:` / `Not-applicable:` 具体行动，禁止「已知/待后续」式敷衍回应。其中 R1/R3/R4 建议在 4-dev 前补一次真实 API 实测（对 `CHANGE.md:19` 样本打印 `.content[0]` 结构、对 `enabled+32k` 大产物验证、对代理 32k 验证），以证据取代断言后再定默认值。

---

## L3 盲审（deepseek-v4-pro 外部模型 · 2026-07-24 18:16）

> 自动生成于 2026-07-24 18:16。l3_review_run 超时（rc=3，curl --max-time 90 杀断于 deepseek-v4-pro 扩展思考 + 硬编码 max_tokens:8000 无 text block）后，经 thinking=disabled fallback 绕行写入（max_tokens=32000, --max-time 300；未改 l3-review.sh 源码，符合 l3-review-timeout-token change 约束 #3）。

### 审查结论

```json
{
  "critical": [
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "风险段 R2 与 R3 编号重复且逻辑混乱",
      "why": "风险清单中出现两个 R2 和两个 R3（R1b 后接 R3，然后 R2、R3 再次出现）。第一个 R2 声明\"阿里云 deepseek 代理可能超上限被拒\"但标记为\"断言修正（R4 落地）\"——R4 不存在于风险表。第二个 R3 讨论 disabled thinking 被 API 忽略。编号冲突导致风险追踪不可靠，且 R4 引用缺失使缓解措施悬空。",
      "fix": "统一编号：R1b 保留为 R2；原 R3（默认值依据不足）改为 R3；原 R2（上线风险·阿里云代理）改为 R4；原 R3（上线风险·disabled 被忽略）改为 R5；R4 引用改为 R4。重新排序确保编号连续无重复。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "D6 决策与 ADR 索引段矛盾",
      "why": "D6 明确决定\"不新增 ADR\"且\"不完整套用 env-var-first 3 级链\"，但 §4 ADR 索引段写\"三个 env var 遵循与 FLOW_KIT_L2_MODEL / FLOW_KIT_L3_MODEL 相同的 env-var-first 优先级链\"。这是直接矛盾：D6 说用 2 级（env var > 默认值），§4 说用 3 级（env var > stop-hook.json > 默认值）。调用方无法确定实际优先级链长度。",
      "fix": "§4 须与 D6 对齐。若 D6 为最终决定，§4 改为：\"三个 env var 用 2 级 env var 配置（env var > 硬编码默认值），不纳入 stop-hook.json 中间级。\""
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "R1b 揭示的静默错判风险未纳入关键缓解",
      "why": "R1b 描述了 `_l3_parse_result` fallback 链在 thinking 吃满预算时可能提取思考内容当 verdict（rc=0 假 verdict），并标注为\"比 rc=3 更危险\"。本 change 因 scope 限制不改解析逻辑，但当前缓解仅依赖 disabled thinking（escape hatch），未要求在 4-dev 实现时对此风险做强制性验证。若 enabled+32k 仍触发 fallback 静默错判，L3 将返回假 verdict 且 rc=0，gate 无感知，安全强度完全失效。",
      "fix": "在 §5 风险表新增缓解措施：4-dev 实现时必须验证 enabled+32k 场景下 thinking block 是否触发 fallback 链，若触发则强制默认值改为 disabled（或提高 max_tokens 直至 thinking block 不独占 budget）。此验证应作为 AC 或测试用例，而非仅\"建议后续 change 修\"。"
    }
  ],
  "major": [
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "D5 fail-safe 策略与 D3 默认值选择存在未声明的交互风险",
      "why": "D5 决定非法值回退默认 + 警告不崩溃。D3 默认 thinking=enabled。若用户设置 FLOW_KIT_L3_THINKING=invalid，回退到 enabled，但用户可能期望 disabled（如大产物场景）。回退到 enabled 在大产物场景可能触发 R1b 静默错判，而用户因配置\"成功\"（仅 stderr 警告）不会察觉行为差异。",
      "fix": "D5 或风险段补充声明：非法 thinking 值回退到 enabled 的安全假设是 enabled 对所有产物规模安全。若 R3（默认值依据不足）在大产物实测中不成立，则 D5 的非法值回退目标也应改为 disabled。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "§0.5.2 沿用抽象对照表与 D6 决策不一致",
      "why": "§0.5.2 第 2 行声明\"env-var-first config 策略 CONTEXT.md [2026-07-01] 已锁决策（env var > stop-hook.json > 硬编码）\"，并说三个 env var 遵循此优先级链。但 D6 明确放弃 stop-hook.json 中间级，只用 2 级。§0.5.2 未反映 D6 的修正，导致读者在文档前半部分获得错误优先级信息。",
      "fix": "§0.5.2 第 2 行改为：\"2 级 env var 配置（env var > 硬编码默认值），stop-hook.json 中间级不适用（见 D6）\"。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "D2 默认值理由未覆盖 Path 1（阿里云代理）的 token 限制",
      "why": "D2 默认值 max_tokens=32000 的理由基于\"deepseek-v4-pro 扩展思考 + 大产物\"，但未区分 Path 1（阿里云代理）和 Path 2（Anthropic 直连）。第一个 R2（编号冲突中的阿里云代理风险）指出阿里云代理从未验证 32000。D2 的默认值选择对 Path 1 是无证据的，而 Path 1 是本 change 声称解套的\"主路径\"。",
      "fix": "D2 选择理由段补充：默认值 32000 对 Path 2 有实测依据，对 Path 1 待验证（见风险 R4）。若 Path 1 不支持 32000，默认值对 Path 1 无效，需用户通过 env var 下调或依赖 Path 2 作为 fallback。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "§0.5.3 声明\"沿用 env-var-first 3 级链\"但 D6 否定此声明",
      "why": "§0.5.3 沿用模式 vs 引入新模式表中写\"注：非完整 env-var-first 3 级链（CONTEXT [2026-07-01] 该策略仅限模型名/endpoint，经 fk_resolve_model 解析器）；本 change 的调用参数用 2 级足够，不纳入 stop-hook.json 中间级（见 D6 诚实修正）\"。此处注记本身正确，但 §0.5.2 和 §4 未同步更新，导致文档内部不一致。",
      "fix": "确保 §0.5.2、§0.5.3、§4 三处对优先级链的描述一致（均为 2 级）。当前 §0.5.3 注记正确，作为锚点，修 §0.5.2 和 §4 即可。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "§2.3 jq 条件构造注释存在实现歧义",
      "why": "§2.3 提供两种实现方式：\"if 分支选 jq 表达式\"或\"jq 条件 (... | if ...)\"。前者在 bash 层面分支，后者在 jq 层面分支。两者行为等价但代码结构不同，可能在 4-dev 实现时产生选择歧义。DESIGN 阶段应定方向而非留开放选项。",
      "fix": "选定一种方式并注明理由。建议选 bash 层 if 分支（两个完整 jq 表达式），因为条件字段的 jq 内联条件写法在 thinking 未来扩展（如 budget_tokens 子字段）时更易读错。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "§9.3 新增 env var 契约未声明类型约束的严格性",
      "why": "§9.3 声明 FLOW_KIT_L3_MAX_TOKENS 和 FLOW_KIT_L3_TIMEOUT 为\"数字\"，但未说明是否接受空字符串、负数、浮点数、前导零。D5 的非法值回退逻辑依赖明确的类型边界，契约应定义这些边界。",
      "fix": "补充类型约束：数字为正整数，空字符串/非数字/负数/浮点数均视为非法值，触发回退默认 + 警告。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "§9.5 禁动清单变化引用 R5 但 R5 不存在",
      "why": "§9.5 第 4 行：\"待 A-evolve 同步（R5）：ARCHITECTURE.md §1.3 NFR 基线 + env var 登记表须补三个新 var\"。R5 在风险表编号冲突后不存在，读者无法追溯此同步要求的来源。",
      "fix": "改为引用实际风险编号（修正后应为 R4 或 R5 之一），或直接写\"待 A-evolve 同步\"不引用风险编号，或将此同步要求作为独立条目而非风险引用。"
    }
  ],
  "verdict": "fail",
  "summary": "风险编号冲突导致 R4 引用悬空、D6 与 §4/§0.5.2 的优先级链矛盾、R1b 静默错判风险未纳入强制缓解——三处 critical 使工件不可执行。"
}
```

L3_artifact_hash: 64add0e2286049b01f43e87f7a2c1800b2b1dc38f8ddf65fa3a7d789f6c05a46

---

## L3 重审（deepseek-v4-pro 外部模型 · 2026-07-24 18:39）

> 自动生成于 2026-07-24 18:39。第二轮复核（首轮 verdict=fail，3 Critical 修复后复核）。l3_review_run 再次超时（rc=3，源码尚未实施，仍硬编码 max_tokens:8000 / --max-time 90），经 thinking=disabled fallback 绕行写入（max_tokens=32000, --max-time 300；未改 l3-review.sh 源码，符合 l3-review-timeout-token change 约束 #3）。所用配置即本 change 提议的解套配置。响应 stop_reason=end_turn，content_types=["text"]（干净 text block，未触发 R1b 静默错判）。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "R2 风险：_l3_parse_result fallback 链静默错判问题未纳入本 change 范围",
      "why": "R2 明确揭示：fallback 链 `.content[0].thinking // .content[0].text` 在思考吃满预算时可能提取思考内容当作 verdict（rc=0 假 verdict），比 rc=3 更危险。本 change 提高 max_tokens 到 32k 后，thinking block 仍可能在极端情况下吃满 32k（R3 承认大产物场景 enabled+32k 从未实测），此时 fallback 链静默错判风险依然存在。设计将 fallback 修改明确标为 Out of Scope（`_l3_parse_result` 独立 scope），但提供了 C3 落地建议（4-dev 强制验证）。然而风险 R2 本身评级为\"中概率\"，且与 D3 默认 enabled 的决策直接冲突——如果 enabled+32k 对大产物仍可能触发 fallback 静默错判，则 D3 默认 enabled 的收益（推理质量）可能被 R2 的静默错判风险抵消。",
      "fix": "方案 A（推荐）：将 R2 的 fallback 修复纳入本 change 范围（修改 `_l3_parse_result` 移除 `.thinking`/`.text` fallback，仅取 `select(type==\"text\")`，无 text 则 rc=3 显式报错）。这与 D3 的 escape hatch 策略一致（disabled thinking 消除 thinking block 只是规避，修 fallback 才是根治）。方案 B：若坚持 Out of Scope，需在 D3 中诚实记录：默认 enabled 选择在大产物场景下，与 R2 静默错判风险存在已知冲突，且评估 C3 落地验证结果前，该决策的合理性存疑。同时将 R2 概率从中调高（因 enabled+32k 大产物场景未实测，无法排除 fallback 触发）。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "D3 默认 enabled 决策依据不充分，对大产物场景缺乏实证支持",
      "why": "D3 选择 enabled 默认的唯一证据是\"首轮 L3 verdict=fail 9 条全可核实无幻觉\"——但这是中等产物场景（首轮审查），不是 US-2 目标场景（大产物）。R3 明确承认：enabled+32k 对大产物从未测过，唯一验证过大产物可用的是 disabled（58.4s 干净 text block）。US-2 的目标场景正是大产物，默认走未验证路径不自洽。虽然 D3 提供了 disabled escape hatch 作为缓解，但默认值的选择应基于目标场景的实证，而非非目标场景。R3 风险评级为\"中概率\"，且提出\"若实测仍失败，默认值改 disabled\"，说明当前默认值选择是临时的。",
      "fix": "调整 D3 为：默认值暂定为 enabled（保留推理质量），但增加显式约束——4-dev 必须在大产物场景实测 enabled+32k 成功产 text block 后，该默认值才生效；若实测失败，则默认值改为 disabled 并更新本 DESIGN。当前设计可保留 enabled 作为设计意图，但需在 D3 取舍代价中诚实记录：\"默认值依赖 4-dev 大产物场景实测验证，若未通过则退化为 disabled\"。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "R4 风险缓解措施存在逻辑矛盾：要求先验证但默认值已设定为 32000",
      "why": "R4 指出：所有实测仅 max_tokens=8000，从未对阿里云 deepseek 代理验证 32000，'均支持大 max_tokens'是无证据断言。缓解措施要求 4-dev 先实测阿里云代理用 max_tokens=32000。但设计已将默认值设为 32000（D2），这意味着如果 4-dev 实测发现代理拒 32000，需要回退默认值并修改设计文档。默认值的选择应基于已验证的上限，而非未验证的假设。",
      "fix": "将 D2 默认值调整为已验证上限（如 8000），同时将 32000 作为建议值记录在 D2 取舍代价中，待 4-dev 实测阿里云代理支持 32000 后升级默认值。或者，保持 32000 默认但 D2 增加显式约束：\"该默认值依赖 4-dev 对阿里云代理的 max_tokens 上限验证，若代理拒 32000，则下调至代理上限\"。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "D6 诚实修正的表述存在歧义",
      "why": "D6 称\"不完整套用 env-var-first 3 级链\"并\"诚实修正\"为 2 级配置。但 0.5.2 沿用对照表中同样声明\"2 级 env var（env var > 默认值）\"，并在 0.5.3 中说明\"非完整 env-var-first 3 级链\"。同一个决策点在三个位置重复说明，且 D6 用\"诚实修正\"一词暗示之前的设计有误，但实际上本 change 从未声称要完整套用 3 级链，该表述可能引起混淆。",
      "fix": "将 D6 的\"诚实修正\"改为\"明确边界\"或\"范围界定\"，避免暗示此前存在错误。同时在 0.5.2、0.5.3、D6 三处统一表述，减少重复。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "2.3 jq 请求体构造 example 与 D4 决策不完全一致",
      "why": "D4 决策选择\"jq 条件构造\"，2.3 给出了两种独立 jq 表达式（enabled 不含 thinking 字段，disabled 含 thinking 字段），并说\"实现用 if 分支选 jq 表达式，或用 jq 条件\"。if 分支选表达式是两种之一，jq 条件构造是另一种实现方式。D4 的标题是\"thinking 字段用 jq 条件构造\"，但允许的两种实现方式中只有一种是真正的\"条件构造\"。",
      "fix": "将 D4 标题改为\"thinking 字段用 jq 条件构造或分支选择\"，或明确推荐 jq 条件构造作为首选、分支选择作为备选。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "R5 风险评级与缓解措施不匹配",
      "why": "R5 评级为\"低概率\"，缓解措施为\"AC-5 边界声明：只保证请求体字段正确，不保证 API 行为\"。但 L3 子 agent 实测 disabled 有效（38s 返 text block），说明该风险已部分验证为低概率。然而，disabled thinking 的 API 行为可能因模型版本/代理而异，仅靠 AC-5 边界声明不足以缓解——若 API 忽略 disabled 字段且用户依赖 disabled 作为 escape hatch，可能造成大产物场景静默失败。",
      "fix": "补充缓解措施：4-dev 在 bats 测试中增加 disabled thinking 的端到端验证（AC-5c 已覆盖请求体结构，但需补充对 API 实际行为的监控建议，如检查响应是否含 thinking block）。风险评级保持低概率，但缓解措施需更具体。"
    },
    {
      "file": "DESIGN: L3 审查工具超时/token 上限可配置化",
      "issue": "ADR-002/ADR-004/ADR-011 附录与本 DESIGN 无直接关联，未说明为何引用",
      "why": "DESIGN 末尾附带了三个 ADR 的完整内容（ADR-002 L3 前置、ADR-004 gate 返回值语义、ADR-011 pipeline 不 auto-advance），但本 DESIGN 正文未引用这些 ADR 作为决策依据或约束。ADR-002 与 L3 调用策略相关，但本 change 是 L3 调用的参数化改造，不改变调用策略；ADR-004/011 与本 change 完全无关。附录的存在可能误导审查员认为这些 ADR 是本 change 的决策依据。",
      "fix": "若这些 ADR 是作为上下文参考，需在 DESIGN 开头或相应决策点明确说明引用目的；若无关，应移除。"
    }
  ],
  "verdict": "pass",
  "summary": "设计整体合理，三个 env var 的 2 级配置策略与项目既有架构一致，但存在三个需关注的问题：fallback 链静默错判风险未纳入本 change 范围且与默认 enabled 决策冲突、默认值设定依赖未验证的实证（大产物场景 enabled+32k 和阿里云代理 32000 上限），以及附录 ADR 与正文缺少关联说明。无 critical 问题，verdict=pass。"
}
```

L3_artifact_hash: a08ab8ad459896ebf96da5d35827e8d8166c94c8d16110fa42546e84d96403bb
