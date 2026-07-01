# 独立审查 · 阶段 1

## L2 盲审

### 🔴 R1 · AC 覆盖缺口：30-ai-analyze.sh 的 API 直连行为无对应 AC
**Symptom**：CHANGE.md 第 20-21 行明确要求 "修改 `29-independent-review.sh` 和 `30-ai-analyze.sh`：模型名从 `$ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量读取，API 直连 `$ANTHROPIC_BASE_URL`（用 `$ANTHROPIC_AUTH_TOKEN` 鉴权）"，即 30 号脚本同样需要 API 直连改造。但 REQUIREMENT.md 中：AC-2（30 号 hook）仅覆盖模型环境变量读取；AC-4 的 Given/When/Then 全程只提及 "29 号 hook"，对 30 号脚本的 `$ANTHROPIC_BASE_URL` + `$ANTHROPIC_AUTH_TOKEN` 使用无任何验证。
**Source**：CHANGE.md 的 What 段（功能范围声明）与 REQUIREMENT.md 的 AC 覆盖范围不闭合——声明的功能范围未经 AC 完整约束。
**Consequence**：实现阶段可能仅对 29 号脚本做 API 直连改造，30 号脚本只改模型而不改 API 路径，导致 30 号脚本在新环境中仍走 onecli 或旧路径而失败。这是 spec 与实现的系统性偏差风险。
**Remedy**：新增一条 AC 或在 AC-4 中扩展 When/Then 覆盖 30 号脚本：

```
### AC-4b · 30 号 hook 同样直连 API（建议扩展现有 AC-4）

- **Given** 用户已在 `env` 中设置 `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic` 和 `ANTHROPIC_AUTH_TOKEN`
- **When** 30 号 hook（30-ai-analyze.sh）调用外部模型 API
- **Then** 请求同样发送至 `$ANTHROPIC_BASE_URL/v1/messages`，Header 为 `Authorization: Bearer $ANTHROPIC_AUTH_TOKEN`
- **验证方式**: `grep 'ANTHROPIC_BASE_URL' ~/.claude/hooks/stop/30-ai-analyze.sh` 返回 ≥1
```

---

### 🔴 R2 · 安全 NFR "token 不泄露到日志" 无对应 AC
**Symptom**：REQUIREMENT.md 第 104 行非功能性需求明确要求 "hook 脚本中 API token 不得出现在日志输出或错误信息中"，但 8 条 AC 中没有任何一条验证此安全约束。
**Source**：安全检查项不能仅靠 NFR 声明——可机器验证的 AC 是安全合规模块的必要部分。无 AC = 无强制验证 = 无合规证据。
**Consequence**：实现时可能在 `set -x` 调试、curl 错误输出或异常处理中将 `$ANTHROPIC_AUTH_TOKEN` 明文写入 stderr/stdout。若 QA/Review 阶段无对应 AC 兜底，token 泄露可能进入生产环境。
**Remedy**：新增一条 AC：

```
### AC-9 · API token 不出现在输出中

- **Given** `ANTHROPIC_AUTH_TOKEN` 已设置为有效值
- **When** 29 或 30 号 hook 脚本以任意模式执行（正常 / 失败 / 超时）
- **Then** stdout 与 stderr 中均不出现 `$ANTHROPIC_AUTH_TOKEN` 的实际值
- **验证方式**: 运行脚本并重定向输出后，`grep -c "$ANTHROPIC_AUTH_TOKEN" /tmp/hook-output.log` 返回 0
```

---

### 🔴 R3 · AC-4 验证方式不覆盖 ANTHROPIC_AUTH_TOKEN
**Symptom**：AC-4（REQUIREMENT.md 第 39-44 行）Then 子句要求 "Header 为 `Authorization: Bearer $ANTHROPIC_AUTH_TOKEN`"，但验证方式仅 `grep 'ANTHROPIC_BASE_URL'`，未检查 `ANTHROPIC_AUTH_TOKEN` 引用是否存在。
**Source**：Then 声明的行为与验证方式不闭合——AC 的 "可机器验证" 要求验证方式必须覆盖 Then 的关键断言。
**Consequence**：脚本可能引用了 `ANTHROPIC_BASE_URL` 但未在请求中携带 `ANTHROPIC_AUTH_TOKEN` Header，AC-4 仍可通过（grep 匹配 BASE_URL 即判 pass），导致 API 调用因缺少鉴权而静默失败。
**Remedy**：AC-4 验证方式增加一行：
```
验证方式:
  - `grep -c 'ANTHROPIC_BASE_URL' ~/.claude/hooks/stop/29-independent-review.sh` 返回 ≥1
  - `grep -c 'ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/29-independent-review.sh` 返回 ≥1
```
（若同时采纳 R1，则 30 号脚本同理。）

---

### 🟡 R4 · AC-5 验证方式不测试运行时优先级
**Symptom**：AC-5（REQUIREMENT.md 第 46-51 行）Then 子句要求 "脚本优先使用环境变量，config 文件值仅作为 fallback"，但验证方式仅检查 `stop-hook.json` 的静态文件内容（`jq '.ai.model'`），不验证脚本在运行时确实优先读取了环境变量。
**Source**：Given/When/Then 规约要求验证方式覆盖 Then 的核心断言，而非仅覆盖 Given 的静态配置。
**Consequence**：脚本可能在实现中硬编码读取 config 文件而忽略环境变量，AC-5 的静态验证仍可通过，但 Then 断言的实际行为未得到验证。属于 "看起来覆盖" 但未 "真正覆盖" 的模式。
**Remedy**：补充运行时验证或调整 Then 子句与验证方式对齐。建议增加一条集成验证：

```
验证方式（补充）:
  - 在 env var 已设置且 config 文件值不同的场景下执行脚本，捕获实际使用的 model 参数，断言为 env var 值
```

---

### 🟡 R5 · CHANGE.md 预设名数量描述与 REQUIREMENT.md 不一致
**Symptom**：CHANGE.md 第 23 行写 "支持 7 种预设名" 但实际列出 8 个（`full`, `code-only`, `design`, `requirement`, `review`, `plan`, `design-review`, `requirement-review`）。REQUIREMENT.md 第 83 行写 "支持 8 种预设名"，数字正确且与列表一致。
**Source**：参考文件 CHANGE.md 与工件 REQUIREMENT.md 之间的计数不一致——属于文档级歧义。
**Consequence**：REQUIREMENT.md 本身正确，但 CHANGE.md 的计数错误可能导致后续读者（设计阶段、实现阶段）对预设数量产生混淆。
**Remedy**：将 CHANGE.md 第 23 行 "7 种预设名" 修正为 "8 种预设名"。

---

### 🟢 R6 · AC-6 的 Given 与 When 边界模糊
**Symptom**：AC-6（REQUIREMENT.md 第 53-58 行）Given 子句为 "用户执行 `/flow goal "..." --pipeline --from 0 --gate-config full`"，这直接描述了用户动作，而非动作发生前的系统状态。严格 Given/When/Then 语义下，Given 应为状态（如 "gate-config 预设映射已定义"），When 应为动作（用户执行命令）。
**Source**：Given/When/Then 三段式经典定义中 Given 描述前置条件/状态，When 描述触发动作。
**Consequence**：Given 嵌入动作不会导致验证失败或实现偏差，但降低了 AC 的规范一致性和可读性。
**Remedy**：
```
- **Given** gate-config 预设 "full" 已映射为三阶段 independent review
- **When** 用户执行 `/flow goal "..." --pipeline --from 0 --gate-config full`
- **Then** ...（不变）
```

---

### 🟢 R7 · 可观测性 NFR 无对应 AC
**Symptom**：REQUIREMENT.md 第 106 行要求 "hook 脚本输出应注明实际使用的模型名和 API endpoint"，但没有 AC 验证此输出行为。
**Source**：非功能性需求的可验证性——可观测性需求同样应转化为可机器验证的 AC。
**Consequence**：实现可能遗漏日志输出，用户无法在 hook 执行日志中确认实际使用的模型和 endpoint，降低可调试性。影响较低，因为不阻断核心功能。
**Remedy**：可选新增 AC，或在不新增 AC 的情况下将此需求移至 "nice-to-have" 标注，明确其非强制性。

---

### 🟢 R8 · bats 测试范围声明无 AC 约束
**Symptom**：REQUIREMENT.md 第 84 行 v1 范围声明 "bats 测试覆盖新增解析逻辑"，但无 AC 将 bats 测试本身作为验收对象（例如：bats 测试文件存在、测试通过）。
**Source**：scope 段声明的交付物应至少有 1 条 AC 约束其存在性和基本质量。
**Consequence**：实现可能遗漏 bats 测试文件或仅写空壳，scope 声明与实际交付物脱节。
**Remedy**：新增一条 AC 或在不新增 AC 的情况下，将 bats 测试覆盖要求内嵌到 AC-6/7/8 的验证方式中（如 "验证方式：对应 bats 测试通过"）。

---

**Verdict**: fail

> fail 原因：存在 3 条 🔴 Critical：
> - R1: 30-ai-analyze.sh 的 API 直连改造缺少 AC 覆盖（spec 范围与验收不闭合）
> - R2: token 不泄露到日志的安全 NFR 无任何 AC 验证
> - R3: AC-4 验证方式不覆盖 AUTH_TOKEN 引用，Then 断言在验证层被架空

---

## 主 agent 反驳（L2 再审查前修复）

以下 3 项 🔴 + 1 项 🟡 已在 REQUIREMENT.md 中修复，请求重新审查：

- **R1**：AC-2 已扩展——Then 增加 "API 请求发送至 `$ANTHROPIC_BASE_URL`（与 29 号同策略）"，验证方式增加 `grep 'ANTHROPIC_BASE_URL' 30-ai-analyze.sh`。无需新增独立 AC，因为 30 号与 29 号的 API 直连策略完全一致，在 AC-4 明确 29 号策略 + AC-2 声明 30 号同样策略，已闭合覆盖。
- **R2**：已新增 AC-9「API token 不泄露到日志」，含 Given/When/Then + 验证方式（grep 无 echo/module_output 行含 AUTH_TOKEN）。
- **R3**：AC-4 验证方式已补充 `grep 'ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/29-independent-review.sh` 返回 ≥1。
- **R5**：CHANGE.md "7 种预设名" 已修正为 "8 种预设名"。

🟡/🟢 项（R4/R6/R7/R8）接受发现但不作为本次修复重点：
- R4（AC-5 运行时验证）：运行时优先级逻辑将在 4-dev 实现阶段通过 bats 集成测试覆盖
- R6（Given 嵌入动作）：接受，但对功能性无实质影响
- R7（可观测性 NFR 无 AC）：接受，log 输出已在 AC-9 安全约束中部分覆盖
- R8（bats 测试范围无 AC）：bats 测试文件存在性在 4-dev 阶段自检中强制验证

---

## L2 盲审（再审查）

以下基于 REQUIREMENT.md 当前内容独立重新审查，不依赖前次报告或主 agent 反驳中的任何结论。

---

### 🟡 R1 · AC-2 的 30 号脚本 AUTH_TOKEN 验证缺失：修复未完全闭合

**Symptom**：AC-2（REQUIREMENT.md 第 26-31 行）Then 子句声明 30 号脚本 "API 请求发送至 `$ANTHROPIC_BASE_URL`（与 29 号同策略）"，但验证方式仅 `grep 'ANTHROPIC_BASE_URL'` 和 `grep 'ANTHROPIC_DEFAULT_HAIKU_MODEL'`，不包含 `ANTHROPIC_AUTH_TOKEN`。对比 AC-4（29 号）的验证方式已同时检查 BASE_URL 和 AUTH_TOKEN。CHANGE.md 第 20 行明确要求两个脚本均 "用 `$ANTHROPIC_AUTH_TOKEN` 鉴权"。

**Source**：AC-2 的 Then 语义上通过 "同策略" 引用覆盖了 AUTH_TOKEN，但验证方式与 Then 不闭合——验证方式必须独立覆盖 Then 的关键断言，不能依赖跨 AC 的逻辑推断。

**Consequence**：实现 30 号脚本时可能添加了 BASE_URL 但遗漏了 Authorization header 中的 AUTH_TOKEN，AC-2 的静态 grep 验证仍可通过，导致 30 号脚本在需要鉴权的 API 端点上 401 失败。严重度从前次的 🔴（30 号 API 行为完全无覆盖）降为 🟡（主要行为已覆盖，但鉴权细节存在验证盲区）。

**Remedy**：AC-2 验证方式增加第三条检查：
```
验证方式（补充）:
  - `grep -c 'ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/30-ai-analyze.sh` 返回 >=1
```

---

### 🟡 R2 · AC-5 验证仅覆盖 `ai.model`，遗漏 `independent_review.model` 字段

**Symptom**：AC-5（REQUIREMENT.md 第 46-51 行）Given 子句明确列出两个字段——`ai.model` 和 `independent_review.model`，但验证方式仅 `jq '.ai.model' ~/.claude/stop-hook.json`，对 `independent_review.model` 是否已更新无任何检查。v1 范围声明（第 89 行）同样列出两个字段均需修改。

**Source**：Given/When/Then 规约完整性——Given 中声明的系统状态元素应在验证方式中逐个覆盖，不可部分忽略。

**Consequence**：实现可能仅更新 `ai.model` 而遗漏 `independent_review.model`，AC-5 仍可通过（jq 仅检查 ai.model）。`independent_review.model` 字段继续保持硬编码旧值，导致 independent_review gate 在读取 config fallback 时使用错误的模型。

**Remedy**：AC-5 验证方式增加第二条检查：
```
验证方式（补充）:
  - `jq '.independent_review.model' ~/.claude/stop-hook.json` 返回 "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}" 或等效的环境变量引用
```

---

### 🟡 R3 · AC-4 的 onecli 降级行为无对应验证

**Symptom**：AC-4（REQUIREMENT.md 第 39-44 行）Then 子句要求 "onecli proxy 降级为可选（有则用，无则直连不报错）"，但验证方式仅检查 BASE_URL 和 AUTH_TOKEN 引用是否存在，对 onecli 的降级/可选行为无任何验证项。CHANGE.md 第 43 行同样将此列为验收线。

**Source**：Then 声明的行为与验证方式不闭合——AC 的 "可机器验证" 要求验证方式必须覆盖 Then 中的每个关键行为断言。

**Consequence**：实现可能保留 onecli 优先路径（与 CHANGE.md 第 20 行 "移除 onecli proxy 优先路径" 矛盾），或 onecli 不可用时脚本报错退出（违反 "直连不报错" 约束）。由于 AC-4 无法检测该偏差，可能在验证阶段漏过。

**Remedy**：两种方案择一：
- 方案 A：在 AC-4 验证方式中增加逻辑检查——脚本中 `onecli` 调用路径必须在 `ANTHROPIC_BASE_URL` 直连路径之后，或 onecli 调用前有 `command -v onecli` 守卫条件。
- 方案 B：将 onecli 降级行为拆分为独立 AC，明确 Given（onecli 已安装 / 未安装）对应不同 When/Then 和验证方式。

---

### 🟡 R4 · AC-5 运行时优先级仍未验证（原 R4 延续）

**Symptom**：此发现与前次报告 R4 相同（REQUIREMENT.md 第 46-51 行）。AC-5 Then 子句要求 "脚本优先使用环境变量，config 文件值仅作为 fallback"，但验证方式仅检查 `stop-hook.json` 的静态内容（`jq '.ai.model'`），不验证脚本运行时确实优先读取了环境变量。主 agent 在反驳中表示 "运行时优先级逻辑将在 4-dev 实现阶段通过 bats 集成测试覆盖"，但 REQUIREMENT.md 作为规格文件仍未提供该行为的可验证验收项。

**Source**：Given/When/Then 规约要求验证方式覆盖 Then 的核心断言。将运行时验证推迟到实现阶段意味着该规格要求当前无可独立验证的 AC——这违反 "AC 是 TEST 阶段派生用例的唯一来源" 的 REQUIREMENT.md 末尾标注（第 124 行）。

**Consequence**：若 4-dev 阶段未按计划编写 bats 测试（原 R8 同样无 AC 约束 bats 测试交付），则环境变量优先级的运行时行为完全无自动化验证，仅靠代码审查人工确认。脚本可能在任何时候因重构而回归。

**Remedy**：在 AC-5 中增加运行时验证描述；或接受此风险但将其明确标记为 "集成测试阶段验证" 并在 scope 中声明该验证不属于单元 AC 范畴。

---

### 🟢 R5 · AC-9 验证方式非纯机器可验证，依赖人工分类

**Symptom**：AC-9（REQUIREMENT.md 第 74-79 行）验证方式为 "`grep -n 'ANTHROPIC_AUTH_TOKEN'` ... 返回的行均为赋值或 curl Header 引用，无 `echo`/`module_output` 行包含该变量"。grep 是机器可执行的，但 "均为赋值或 curl Header 引用" 的判断依赖人工逐行审查 grep 输出——脚本无法自动区分 `ANTHROPIC_AUTH_TOKEN="sk-xxx"`（赋值，安全）与 `echo "using token: $ANTHROPIC_AUTH_TOKEN"`（泄露，不安全）。

**Source**：AC 的 "可机器验证" 原则——验证方式应可通过脚本返回明确的 pass/fail 退出码，不应要求人工逐行判断。

**Consequence**：AC-9 的验证在自动化测试流水线中不可靠——grep 可能返回 0 行（无引用，pass）或返回 curl Header 行（人工判断 pass/fail）。若人工判断步骤被跳过，安全合规性无法自动化保证。

**Remedy**：将验证方式强化为更精确的 grep 模式。例如：
```
验证方式:
  - `grep -c 'ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/29-independent-review.sh ~/.claude/hooks/stop/30-ai-analyze.sh` 返回行数 >=2（每个脚本至少 1 次赋值 + 1 次 curl Header）
  - `grep -cE '(echo|module_output|printf).*ANTHROPIC_AUTH_TOKEN' ~/.claude/hooks/stop/29-independent-review.sh ~/.claude/hooks/stop/30-ai-analyze.sh` 返回 0
```
第二条为自动化安全断言——任何输出函数引用 AUTH_TOKEN 即判 fail。

---

### 🟢 R6 · AC-1 Then 硬编码 Given 中的示例值，降低通用性

**Symptom**：AC-1（REQUIREMENT.md 第 18-23 行）Given 设置 `ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash`，Then 断言 "model 参数为 `deepseek-v4-flash`（从 env var 读取）"。括号中的 "从 env var 读取" 是正确语义说明，但 Then 主体将示例值与断言值混为一体——若读者将 Given 的值改为 `claude-haiku-4-5`，Then 的 `deepseek-v4-flash` 硬编码断言将产生矛盾。

**Source**：Given 是前置条件（可变），Then 是预期结果（应由 Given 推导）。Then 不应重复 Given 的具体值，而应用变量引用。

**Consequence**：AC 的可读性轻微下降；若某天默认 haiku 模型从 `deepseek-v4-flash` 迁移为其他模型，需同步修改 Then 中的硬编码值。不影响可验证性（验证方式仅 grep 变量名，不 grep 值），但影响 AC 的语义清晰度。

**Remedy**：
```
- **Then** L3 API 调用使用的 model 参数等于 `$ANTHROPIC_DEFAULT_HAIKU_MODEL` 的值（即 Given 中设置的模型名），而非硬编码值
```

---

### 🟢 R7 · AC-6/AC-7 Given 嵌入用户动作（原 R6，未修复）

**Symptom**：与前次报告 R6 相同。AC-6（第 53 行）Given 为 "用户执行 `/flow goal "..." --pipeline --from 0 --gate-config full`"，将用户动作写入 Given 而非 When。AC-7 同理。

**Source**：Given/When/Then 经典三段式——Given 描述前置状态，When 描述触发动作。当前写法降低了 AC 的规范一致性。

**Consequence**：对验证无实质影响，仅降低 AC 的可读性与规范性。

**Remedy**：与前次报告 R6 建议相同——将命令执行移至 When，Given 改为状态描述。

---

### 🟢 R8 · 可观测性 NFR 仍无 AC 覆盖（原 R7，未修复）

**Symptom**：与前次报告 R7 相同。REQUIREMENT.md 第 113 行（非功能性需求-可观测性）要求 hook 脚本输出注明实际使用的模型名和 API endpoint，但无 AC 验证。

**Consequence**：同前次——实现可能遗漏日志输出，降低可调试性。影响较低。

---

### 🟢 R9 · bats 测试交付物仍无 AC 约束（原 R8，未修复）

**Symptom**：与前次报告 R8 相同。REQUIREMENT.md 第 91 行 v1 范围声明 "bats 测试覆盖新增解析逻辑"，但无 AC 约束 bats 测试文件的存在性和通过状态。

**Consequence**：同前次——实现可能遗漏 bats 测试。

---

**Verdict**: pass

> 上次 3 项 🔴 Critical 已全部解决：R2（token 泄露）已通过新增 AC-9 修复；R3（AC-4 缺少 AUTH_TOKEN 验证）已在验证方式中补充；R1（30 号脚本 API 行为无覆盖）已改善为 AC-2 覆盖 BASE_URL，残留的 AUTH_TOKEN 验证缺口降级为 🟡 非阻塞。
>
> 当前无 🔴 Critical 发现。存在 4 项 🟡 Major（R1 残留的 30 号 AUTH_TOKEN 验证、R2 AC-5 遗漏 independent_review.model、R3 AC-4 onecli 降级行为无验证、R4 AC-5 运行时优先级验证缺失）和 5 项 🟢 Minor，建议在进入设计阶段前修复 🟡 项。
