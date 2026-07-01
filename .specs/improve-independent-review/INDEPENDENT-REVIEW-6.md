# 独立审查 · 阶段 6

> 独立盲审，未参考主 agent 结论。仅基于附录 A-F 工件做独立判断。

---

## 审查范围

- change-id: improve-independent-review
- 工件: 29-independent-review.sh, 30-ai-analyze.sh, SKILL.md gate-config 段, 测试文件 x2, REQUIREMENT.md AC 对照
- 参考: 主 agent REVIEW.md（待复核对象，非权威）

---

## AC 合规逐条审查

### AC-1 · 29 号 hook 读环境变量模型

**代码证据**: 29-independent-review.sh L44 `model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$configured_model}"`
**测试**: test_independent_review_model.bats L23-27, grep 验证脚本含变量引用
**判断**: 代码实现正确，测试通过。但测试为静态 grep（仅验证脚本文本含变量名），未验证运行时行为（env var 值被实际传递给 curl 的 model 参数）。
**结论**: 🟢 通过（实现合规；测试弱但 AC 自身定义的验证方式也是 grep）

---

### AC-2 · 30 号 hook 同样读环境变量

**代码证据**: 30-ai-analyze.sh L89 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-...}`, L93 `${ANTHROPIC_BASE_URL:-...}`
**测试**: test_independent_review_model.bats L32-L41, 两处 grep 均 ≥1
**判断**: 代码实现正确，测试通过。

**⚠️ 独立发现 —— fallback 链不一致**: AC-2 描述"与 29 号同策略"，但实际：
- 29号 fallback 链: env → independent_review.model → ai.model → "deepseek-v4-flash"（3 层）
- 30号 fallback 链: env → ai.model → "deepseek-v4-flash"（2 层，跳过 independent_review.model）

30号是 AI 分析模块，不读取 independent_review.model 有语义合理性。但 AC-2 文字"与 29 号同策略"有歧义——用户可能期望独立 review 的 model 配置也影响 30 号。
**结论**: 🟢 通过（代码正确；差异有合理理由但文档措辞需澄清）

---

### AC-3 · 环境变量缺失时 fallback

**代码证据**: 29号 L42-L45 三级 fallback 链（env → config → hardcoded）；30号 L89 两级 fallback
**测试**: test_independent_review_model.bats L45-L54, 验证 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-` 模式存在
**判断**: 测试仅验证第一跳的 fallback 模式存在，未验证整条链最终收敛到 "deepseek-v4-flash"。
29号 L45 `[ -n "$model" ] || model="deepseek-v4-flash"` 提供了兜底保护，即使 config_get 返回空字符串也能正确回退。
**结论**: 🟢 通过（兜底行 L45 保证了最终 fallback 正确；测试偏弱但行为可静态验证）

---

### AC-4 · API 直连 ANTHROPIC_BASE_URL

**代码证据**: 29号 L116-L125, Path 1 使用 `curl -s "${base_url}/v1/messages"` + `Authorization: Bearer ${auth_token}`
**测试**: test_independent_review_model.bats L58-L68, grep 验证脚本含变量引用
**判断**: 代码实现正确；onecli 降级为可选（Path 2 仅在 Path 1 失败且 onecli 存在时触发）。
**结论**: 🟢 通过

---

### AC-5 · 脚本优先读环境变量，config 作为 fallback

**代码证据**: 29号 L44 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$configured_model}`; 30号 L89 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get ...)}`
**测试**: 无。test_independent_review_model.bats 中未包含 AC-5 对应的测试用例。

**独立审查发现**: 此 AC 的验证方式明确要求 "bats 集成测试——以不同 env var 值执行脚本，捕获实际传参，断言为 env var 值"。但测试文件中 AC-5 的 grep 命中次数为 0——没有任何测试用例覆盖此 AC。现有测试均为静态 grep（验证变量名存在），未验证运行时 env-var-over-config 优先级行为。

**主 agent REVIEW.md 误判标注**: 主 agent 将 AC-5 标记为 ✅ 覆盖，证据列"API path 优先级：direct > onecli > legacy key"。这是**错误的证据映射**——API path 优先级是关于 HTTP 传输路径选择（curl 直连 vs onecli proxy vs legacy key），而非 AC-5 要求的 model 配置优先级（env var vs stop-hook.json config）。两者是不同的关注点，主 agent 混淆了它们。

**代码正确性**: 尽管测试缺失，代码本身的 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-...}` 展开模式从静态分析角度确实实现了 env-var-first 语义。行为可通过代码审查验证。
**结论**: 🟡 通过（代码正确，但 AC 指定的验证方法未实现；主 agent 的覆盖证据不相关）

---

### AC-6 · gate-config 预设名识别

**代码证据**: SKILL.md 预设映射表（8 种预设名）；test_gate_config_presets.bats L27-L82 resolve_gate_config()
**测试**: 20 条测试全部独立验证通过（L86-L240）
**判断**: 所有 8 种预设名正确映射，alias（review↔code-only）正确处理。

**⚠️ 独立发现 —— 测试与生产代码脱节**: 测试中的 `resolve_gate_config()` 是测试文件内联定义的副本函数，不是从生产代码（SKILL.md 中的 skill 指令）source 而来。SKILL.md 描述的是 Claude Code 解释执行的 Markdown 指令，并非可直接 source 的 Bash 函数。这意味着如果 SKILL.md 中的解析逻辑与实际实现的边界条件有差异（如 `jq -e 'type == "object"'` 在特定 jq 版本的行为），测试不会发现。

**缓解**: 测试函数完整复现了 SKILL.md 中描述的逻辑，作为 specification-by-example 有效。但缺乏端到端测试（实际通过 /flow skill 执行 gate-config 解析）。
**结论**: 🟢 通过（逻辑覆盖完整；测试-生产脱节是本项目架构的内在限制）

---

### AC-7 · gate-config 数字简写

**代码证据**: SKILL.md 数字映射 1→"1-requirement", 2→"2-design", 6→"6-review"; test_gate_config_presets.bats L161-L208
**测试**: 7 种组合全部独立验证通过
**判断**: 数字拆分、逗号分隔、逐位映射、JSON 聚合均正确。
**结论**: 🟢 通过

---

### AC-8 · 向后兼容完整 JSON

**代码证据**: SKILL.md 步骤 a: `jq -e 'type == "object"'` + `type == "object"` 检测
**测试**: test_gate_config_presets.bats L212-L227, JSON passthrough 正确
**判断**: 使用 `jq -e 'type == "object"'` 而非仅 `jq empty` 是关键设计点——避免裸数字 "6"（合法 JSON number）被误当做 JSON 对象而跳过预设解析。测试覆盖了此边界。
**结论**: 🟢 通过

---

### AC-9 · API token 不泄露到日志

**代码证据**: 两个脚本中 ANTHROPIC_AUTH_TOKEN 仅出现在赋值行和 curl -H 行
**测试**: test_independent_review_model.bats L72-L80, grep 验证 token 不出现在 echo/module_output
**判断**: grep 测试通过。额外缓解：脚本使用 `set -euo pipefail` 而非 `set -x`，trace 模式不会无意暴露 token。

**⚠️ 独立发现**: 若用户调试时临时添加 `set -x`，curl 命令中的 `$ANTHROPIC_AUTH_TOKEN` 会在 trace 中展开。DESIGN.md R5 已记录此风险并建议"禁止在 hook 脚本中使用 set -x"。接受为已知风险。
**结论**: 🟢 通过

---

## 代码质量 · 6 维衰退风险

### R1 · 认知过载

**独立判断**: 🟢 无。修改集中在两个脚本的模型读取和 API 调用段落，变更范围小且明确。env var 覆盖逻辑是标准 Bash 参数扩展模式，不引入新的抽象概念。
**与主 agent 一致**: 是（独立得出）。

---

### R2 · 变更传播

**独立判断**: 🟢 无。API 调用格式不变，stop-hook.json 格式不变，gate-config JSON 输出格式不变。仅入口解析层扩展。
**与主 agent 一致**: 是（独立得出）。

---

### R3 · 知识重复

**独立判断**: 🟡 存在。

**Symptom**: 29-independent-review.sh L115-L143 与 30-ai-analyze.sh L91-L129
**Source**: DRY 原则。Path 1（direct curl + Bearer auth）/ Path 2（onecli fallback）/ Path 3（legacy API key）三级 API 调用模式在两个脚本中结构完全相同——都包含 base_url/auth_token 赋值、三种 curl 调用、`jq -n` 构造请求体。
**Consequence**: 未来若 API 调用策略变更（如新增 auth 方式、修改请求格式、调整 fallback 顺序），两个脚本必须同步修改，容易遗漏其中一个导致行为不一致。
**Remedy**: 提取共享函数到 `common.sh`（如 `call_ai_api "$prompt" "$model" "$max_tokens"`），封装 Path 1/2/3 逻辑。30号使用的 `max_tokens:1000` 与 29号使用的 `max_tokens:2000` 可通过参数化处理。

**主 agent 误判**: 主 agent 评估 R3 为 "🟢 无——29/30 号脚本的 API 调用模式一致但不重复（不同参数）"。参数不同恰恰证明了结构重复而非消除重复——结构相同、参数变化的代码正是提取抽象的最佳场景。

---

### R4 · 偶然复杂

**独立判断**: 🟡 存在。

**Symptom 1**: 29号 L42-L45 三级 fallback 链——`default_model` → `configured_model` → `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$configured_model}` + 兜底 `[ -n "$model" ] || model="deepseek-v4-flash"`。这个 4 行逻辑的实际语义是"取 env var，否则取 config，否则取硬编码默认"，但通过两个中间变量（`default_model`、`configured_model`）和一条兜底线实现，增加了理解负担。

**Symptom 2**: 两条脚本的 fallback 链深度不同（见 AC-2 下标注），读者需要理解为什么同一个 env-var-first 策略在 29 号有 3 层而在 30 号只有 2 层。
**Source**: 非必要的中间变量；配置键的层级差异未在代码注释中说明。
**Consequence**: 维护者修改时容易误解 fallback 语义，在某一层引入错误。
**Remedy**: 合并为单行表达式或提取为 `common.sh` 函数，加注释说明每层语义。30号也应注明为何跳过 independent_review.model。

**与主 agent 差异**: 主 agent 评估 R4 为"🟢 无——三级 fallback 链是 Bash 标准参数扩展模式"。我不同意——标准参数扩展模式本身不复杂，但通过两个中间变量间接跳转（config_get 的嵌套调用）超过了"直接可读"的阈值。

---

### R5 · 依赖混乱

**独立判断**: 🟢 无。onecli 降级为可选 fallback，不引入新依赖。Shell 依赖（jq、curl）与项目基线一致。
**与主 agent 一致**: 是（独立得出）。

---

### R6 · 领域扭曲

**独立判断**: 🟢 无。gate-config 预设名语义化（full/review/design 等），与其代表的独立 review 开启阶段含义一致。数字简写是便利层，不扭曲领域模型。
**与主 agent 一致**: 是（独立得出）。

---

## 其他发现

### 🟡 R7 · Shell 变量未加引号

**Symptom**: 29号 L139 `-H "x-api-key: $ANTHROPIC_API_KEY"` ; 30号 L123 同
**Source**: Shellcheck SC2086。Bash 中未加引号的变量在含空格/特殊字符时会分词。
**Consequence**: 若 ANTHROPIC_API_KEY 意外包含空格（极度罕见但非不可能），curl 的 -H 参数会收到不完整的 header。Path 3 是 legacy fallback，实际使用率低，风险极小。
**Remedy**: 改为 `-H "x-api-key: ${ANTHROPIC_API_KEY}"`（加花括号保护），或对该变量单独加引号。最低成本修复。

---

### 🟡 R8 · DESIGN.md 数据流图与实际代码不一致

**Symptom**: DESIGN.md L96-L98
```text
├─ onecli 存在? ──yes──> onecli proxy curl $base_url/v1/messages
└─ no ─────────> curl -H "Authorization: Bearer $auth" $base_url/v1/messages
```
**Source**: D2 决策明确为"API 调用路径：直连优先，onecli 可选 fallback"，但数据流图描绘了相反顺序（onecli 先于直连）。
**Consequence**: 读者看图会误以为 onecli 仍是主路径。文档与代码不一致，降低设计文档可信度。
**Remedy**: 修正数据流图为 Path 1（直连 auth token）→ Path 2（onecli fallback）→ Path 3（legacy key）的实际执行顺序。

---

### 🟢 R9 · AC-3 测试覆盖深度不足（信息性）

AC-3 验证方式描述 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}`，但 29 号的实际表达式是 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$configured_model}`，中间经过两层 config_get 才到达硬编码默认值。grep 测试仅匹配第一跳，未验证整条 fallback 链的终点。29 号 L45 的兜底线 `[ -n "$model" ] || model="deepseek-v4-flash"` 提供了补偿保护，使实际行为正确。不构成缺陷，但测试覆盖深度可改善。

---

## 主 agent REVIEW.md 复核

| 主 agent 判断 | 独立判断 | 备注 |
|---|---|---|
| AC-5: ✅ 覆盖 | 🟡 代码正确但测试缺失 | 主 agent 证据"API path 优先级"与 AC-5 要求不相关——混淆了 API 传输路径和 model 配置优先级 |
| R3: 🟢 无重复 | 🟡 存在知识重复 | 主 agent 认为参数不同即不重复，但结构相同正是提取抽象的典型场景 |
| R4: 🟢 无偶然复杂 | 🟡 存在偶然复杂 | 主 agent 高估了三级 fallback 链的简洁性 |
| R1, R2, R5, R6: 🟢 | 🟢 一致 | 独立得出相同结论 |
| 其他 AC: ✅ | ✅ 一致 | 独立验证通过 |

---

**Verdict**: pass

**理由**: 无 🔴 Critical 发现。存在 🟡 Major 项（AC-5 测试缺失、R3 知识重复、R4 偶然复杂、R7 变量未引号、R8 文档图错误），但代码核心行为正确，所有 AC 在实现层面合规。建议修复 🟡 项后合并。
