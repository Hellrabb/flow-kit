# 独立审查 · 阶段 2

## L2 盲审

> 审查员：独立 L2 盲审员（阶段 2 · 设计审查）
> 审查日期：2026-07-01
> 工件：`.specs/improve-independent-review/DESIGN.md`（参考 `.specs/CONTEXT.md`；ARCHITECTURE.md 不存在，已忽略）
> 附加参考：`.specs/improve-independent-review/REQUIREMENT.md`（仅用于交叉校验 AC 与 DESIGN 的一致性）

---

### 🔴 R1 · D5 与 R2 相互矛盾 -- 设计文档内含相反指令

**Symptom**：DESIGN.md 第 77 行（D5 决策）要求将 `stop-hook.json` 的模型字段改为环境变量引用字符串 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}`。同一文件的第 152 行（R2 缓解措施）明确写道"建议保留硬编码值不变，只在脚本层加 env var 优先读取，避免破坏其他模块"。两条指令互斥 -- 一个要求改 config 文件格式，另一个要求不改。

**Source**：设计文档是 4-dev 实现阶段的规格说明书。规格说明书包含相互矛盾的指令即构成"规格合规失败" -- 实现者无法同时满足两条指令。此外，D1 决策（env-var-first 读取链）已在脚本层完整覆盖了 env var 优先的需求，D5 对 config 文件格式的修改是冗余操作，不提供额外功能收益。

**Consequence**：若实现者遵循 D5（literal reading of the decision table），stop-hook.json 格式变更会破坏所有读取该文件的其他模块（如 R2 正确识别的：其他 hook 脚本拿到未展开的字面字符串 `${...}` 而非实际模型名）。若实现者遵循 R2，则 D5 被实质否决，决策表与风险段不一致的设计文档持续存在，后续变更审查者会反复遇到同样的困惑。无论哪种路径，当前 DESIGN.md 不可直接用于实现。

**Remedy**：删除 D5 作为独立决策条目。理由：D1 已通过脚本层 `env var > config > hardcoded` 三级 fallback 完整实现了 env-var-first 行为，无需再改动 stop-hook.json 文件格式。修改内容如下：

```
## DESIGN.md 修改方案

1. 删除决策表第 77 行 D5 整行
2. 将 R2 状态改为 "CLOSED -- 通过 D1 脚本层 env-var-first 规避，不修改 config 文件格式"
3. 在 D1 的"取舍代价"列补充说明："明确不修改 stop-hook.json 格式，避免破坏其他消费者"
4. 更新 Section 2.1 数据流图：移除 config 文件占位符展开分支
```

---

### 🟡 R2 · AC-5 验证方式与 DESIGN 策略不一致 -- 测试规格会因实现策略不同而失败

**Symptom**：REQUIREMENT.md 第 51 行的 AC-5 验证方式要求 `jq '.ai.model' ~/.claude/stop-hook.json` 返回 `"${ANTHROPIC_DEFAULT_HAIKU_MODEL:-deepseek-v4-flash}"` 或等效环境变量引用。这条验证预设了 D5 实现（env var 字符串写入 JSON）。但 AC-5 自身的文字描述"脚本优先使用环境变量，config 文件值仅作为 fallback"描述的是 D1 的脚本层行为，与验证方式不对齐。若按 R1 结论移除 D5，此 AC-5 验证方式将必然失败。

**Source**：REQUIREMENT.md 的 AC 是 TEST 阶段的唯一用例来源（REQUIREMENT.md 第 124 行明确声明："AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC"）。AC 与 DESIGN 不一致会导致 TEST 阶段派生出的 bats 测试用例无法通过。

**Consequence**：若按 D1（仅脚本层 env-var-first）实现，AC-5 的 `jq` 验证会失败 -- stop-hook.json 中的字段仍是普通字符串 `"deepseek-v4-flash"` 而非 `${...}` 占位符。TEST 阶段 bats 测试若严格按 AC-5 编写，会报告 false positive 失败。实现者必须要么回退到有风险的 D5，要么与 AC 作者争论变更 AC -- 两者都增加不必要的摩擦。

**Remedy**：重写 AC-5 验证方式，对齐 D1 脚本层策略：

```
### AC-5 · stop-hook.json 模型配置作为 fallback

- **Given** stop-hook.json 中 `ai.model` 和 `independent_review.model` 字段存在且为有效模型标识符
- **When** hook 脚本读取配置且 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量已设置
- **Then** 脚本使用环境变量值（非 config 文件值）；config 文件仅在 env var 未设置时作为 fallback
- **验证方式**: 
  (a) `grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' 29-independent-review.sh` 返回 >=1（确认脚本读取 env var）
  (b) `jq -r '.independent_review.model' stop-hook.json` 返回简单字符串（如 "deepseek-v4-flash"），非 env var 占位符语法（确认 config 文件不存储展开逻辑）
  (c) 环境变量未设置时，脚本回退到 config 文件值（bats 测试：unset env var 后 model 变量值等于 jq 读取的 config 值）
```

---

### 🟡 R3 · 缺失安全风险 -- D5 若实施则需 eval/sed 展开，未列入风险表

**Symptom**：DESIGN.md 第 77 行在 D5 取舍代价中写道"jq 直接读会返回字面字符串（未展开）；脚本中需用 eval 或 sed 展开"。但 Section 4（风险表）未列出任何与 `eval` 使用相关的安全风险。`eval` 在 Bash 中对来自配置文件的字符串执行动态展开是经典的命令注入向量。

**Source**：Bash 安全实践（OWASP/ShellShock 等历史 CVE）-- `eval` 对非可信或半可信输入执行时构成代码注入面。即使当前场景中 stop-hook.json 被视为可信文件，在项目代码库中引入 `eval` 模式会设置危险先例，可能被复制到处理非可信输入的场景中。CONTEXT.md 安全审查维度（第 78-80 行）明确列出"命令注入/路径遍历"为六大风险维度之一。

**Consequence**：若 D5 按描述实施且使用 `eval` 展开 env var 占位符，则：
- 攻击者若能在 stop-hook.json 中注入恶意内容（如通过其他工具或配置同步机制），可通过 `${...}` 语法执行任意命令。
- 即使当前攻击面极小，该 `eval` 模式被其他开发者复制到处理用户输入或外部数据的脚本中时，构成实质性安全漏洞。
- 若改为 `sed` 展开，则 env var 值中的特殊字符（`/`, `&`, `\`) 会导致展开结果损坏，模型名错误引发静默失败。

若按 R1 结论移除 D5，本风险自然消除。

**Remedy**：若 D5 被移除（R1），关闭本条："mitigated -- D5 removed，无需 eval/sed 展开"。
若 D5 因任何原因保留，必须：
1. 在 Section 4 新增风险 R6：`eval`/动态展开的代码注入面。
2. 明确禁止使用 `eval`；改用白名单策略（如仅展开预定义的已知变量名列表 `ANTHROPIC_DEFAULT_HAIKU_MODEL|ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN`，用参数替换而非通用 eval）。
3. 将风险等级标为 🟡 Major。

---

### 🟡 R4 · Section 3 "ADR 索引" 否认跨模块契约变更 -- 掩盖 D5 对 stop-hook.json 消费者的影响

**Symptom**：DESIGN.md 第 142 行声明"无不可逆架构决策。所有决策均为 hook 脚本内部实现细节，不影响 flow-kit 外部接口契约。"但 D5 提案涉及 `stop-hook.json` 的值格式变更（模型字段从普通字符串变为 env var 占位符语法），该文件是跨模块共享的配置中心。CONTEXT.md 第 30 行将其记录为"Stop hook 配置中心"，DESIGN.md 自身的 Section 0.5.1 列出了多个依赖 stop-hook.json 的模块。

**Source**：CONTEXT.md 第 30 行的模块列表确认 `stop-hook.json` 为 11 个 hook 模块的共享配置入口。DESIGN.md 第 34-37 行确认修改范围包括 stop-hook.json。改变共享配置文件的值的语义格式（从"plain string"到"string that requires expansion"）构成接口契约变更 -- 所有消费者必须知道如何/何时展开。

**Consequence**：过于自信的"无不可逆变更"声明会：
- 使后续审查者（L2/L3）误判该 change 的风险等级。
- 若 D5 实施，未更新的消费者读取到未展开字符串时产生隐蔽故障。
- 设定错误先例：未来 change 也可能将跨模块格式变更标记为"内部细节"。

**Remedy**：替换 Section 3 的笼统声明为具体评估：

```
## 3. ADR 索引

| 决策 | 可逆性 | 影响范围 | 回滚成本 |
|------|--------|---------|---------|
| D1 三级 fallback 读取链 | 可逆 | 仅 29/30 号脚本 | 极低（修改一行参数扩展） |
| D2 直连优先 + onecli fallback | 可逆 | 仅 29/30 号脚本 | 低（恢复 onecli 优先标记） |
| D3 gate-config 三段式解析 | 可逆 | /flow skill | 低（恢复 jq-only 解析） |
| D4 预设命名（语义化英文） | 不可逆 | /flow skill + 用户记忆 | 中（预设名成为用户界面契约） |
| D5 stop-hook.json 格式变更 | 不可逆 | 所有读取 stop-hook.json 的模块 | 高（需回滚所有消费者的展开逻辑） |

> D5 已从最终设计移除（见 R1），避免跨模块契约变更。
```

---

### 🟢 R5 · R1 严重度低估 -- env var 展开嵌套场景的测试矩阵被低估

**Symptom**：DESIGN.md 第 150 行将 R1（env var 展开逻辑错误导致空模型名）的概率标为"低"。但从当前设计看，展开涉及三个层级（env var / config / hardcoded），且若 D5 实施还将引入 config 文件中的 `${...}` 占位符解析。`${VAR:-default}` 嵌套在从 JSON 读取的字符串中时，Bash 不会自动展开 -- 需要显式的二次处理，这构成了比单纯 env var 回退更复杂的测试矩阵。

**Source**：Bash 参数扩展的求值时机 -- `${VAR:-default}` 在变量赋值 `model=${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get ... "deepseek-v4-flash")}` 中正常展开。但如果 `config_get` 返回的字符串本身包含 `${...}` 语法（D5 场景），该返回字符串不会再被展开，需要额外的 `eval` 或参数替换步骤。这两层展开的交互在 Bash 中容易出错。

**Consequence**：若展开逻辑在任何一层静默失败（如 env var 未设置且 config 返回占位符字符串），模型名可能变成空字符串或字面的 `${...}` 字符串。API 调用会失败或产生不可预测的行为，用户可能在多轮会话后才注意到 L3 review 不可用。

**Remedy**：若 D5 移除（R1），本风险可保持"低"评级，因为仅剩简单的 `env var > config > hardcoded` 单链，无二次展开。若 D5 保留，升级概率至"中"，并在 bats 测试中追加以下场景：
- env var 未设置 + config 存有占位符字符串 → 必须回退到硬编码默认值
- env var 设为空字符串 → 必须回退到 config/硬编码默认值
- env var 含空格和特殊字符（如 `my model (v2)`） → 正确传入 curl 请求

---

### 🟢 R6 · 数据流图 (2.1) 缺失错误路径 -- API 完全不可用时的降级行为未定义

**Symptom**：DESIGN.md Section 2.1 的数据流图仅展示正常路径分支（onecli 存在/不存在 → 两条 Happy Path），未展示两条路径均失败时的错误处理流程。

**Source**：完整的设计文档数据流应包含异常路径。REQUIREMENT.md AC-4 仅定义了正常调用格式，未定义失败行为。非功能性需求中仅提到"onecli 存在时仍可用（降级为可选而非移除）"，未覆盖双重失败场景。

**Consequence**：若 onecli 不存在且直连 curl 失败（网络中断、endpoint URL 拼写错误、token 过期），hook 脚本可能：
- 静默退出而不写入 INDEPENDENT-REVIEW 文件，导致 independent review gate 永久卡死
- 输出含 token 的 curl 错误信息到日志（若未正确处理 stderr）
- 返回非零退出码导致 stop hook 链中断

**Remedy**：在 Section 2.1 数据流图中增加错误分支：

```
curl 失败?
  └─ yes ──> 2>&1 捕获错误但过滤 auth header → module_output "L3 API 不可用: <safe error>" → 
             写入 INDEPENDENT-REVIEW-<phase>.md 含 "⚠️ L3 review 跳过（API 不可用）" → exit 0（不阻断 gate）
```

同时在 Section 4 新增风险条目 R6："双重 API 故障时 gate 卡死"，严重度 🟡，缓解措施为上述降级写入逻辑。

---

### 补充审查：禁动清单合规性

对照 CONTEXT.md 禁动清单（第 203-207 行）和 DESIGN.md 自身禁动清单（第 39-43 行），未发现 DESIGN 触及禁动模块。`package-flow-kit.sh` 确认未被触碰。`L2-blind-review.md` 确认被列为禁动并遵守。

### 补充审查：既有架构对齐

DESIGN.md Section 0.5 的既有抽象沿用表和禁动清单与 CONTEXT.md 的既有抽象索引（第 144-213 行）一致。`config_get()`、`module_enabled()`、`fk_independent_review_gate_active()` 的沿用合理。新引入的 `resolve_gate_config()` 函数有充分理由（既无预置解析函数），引入点明确（`/flow` skill）。

### 补充审查：已锁决策冲突检查

- `[2026-06-25]` protect the weakest 决策：本 change 不涉及弱模型护栏调整，无冲突。
- `[2026-06-29]` 交互式 UI 触发防护策略：本 change 不修改 27-interactive-ui-check.sh，无冲突。
- `[2026-06-29]` 弱模型合规检测策略：本 change 不修改 28-weak-model-compliance.sh，无冲突。
- `[2026-06-18]` pipeline goal 决策：gate-config 预设扩展与 pipeline --from 参数兼容，无冲突。

---

**Verdict**: fail

**理由**：存在 1 条 🔴 Critical 发现（R1：D5 与 R2 相互矛盾，设计规格内含相反指令，不可直接用于实现）。另含 3 条 🟡 Major 发现（R2/R3/R4，均围绕 D5 决策链），2 条 🟢 Minor 发现（R5/R6）。

**核心建议**：移除 D5 决策，让 D1 的脚本层 env-var-first 三级 fallback 独立承担 env var 配置化需求。这同时解决了 R1（矛盾消除）、R2（AC-5 对齐）、R3（eval 风险消除）、R4（跨模块契约不变），并使 R5 保持低风险评级。D5 为冗余设计 -- D1 已实现相同目标而无跨模块副作用。

---

## 主 agent 反驳（L2 再审查前修复）

完全接受 L2 审查结论。以下修改已执行：

- **R1（Critical）**：D5 已移除。原 D5 "stop-hook.json 改为环境变量占位符" → 新 D5 "stop-hook.json 保留硬编码值不变"。D1 独立承担 env-var-first 职责，不再有矛盾指令。
- **R2（Major · AC-5 对齐）**：REQUIREMENT.md AC-5 已重写——从检查 config 文件格式改为 bats 集成测试验证脚本运行时优先读 env var。
- **R3（Major · eval 风险）**：随 D5 移除而消除。不再需要在脚本中展开 config 文件里的 `${...}` 占位符。
- **R4（Major · ADR 轻率）**：D5 移除后，DESIGN § 3 "无不可逆架构决策" 声明成立——所有决策均为脚本内部实现细节。
- **R5/R6（Minor）**：接受发现。R5 随 D5 移除保持低风险；R6 错误路径继承自既有脚本（29-independent-review.sh 已有 fail_count + max_failures 降级机制，设计图中无需重复）。

---

## L2 盲审（再审查）

> 审查员：独立 L2 盲审员（阶段 2 · 设计再审查）
> 审查日期：2026-07-01
> 工件：`.specs/improve-independent-review/DESIGN.md`（参考 `.specs/CONTEXT.md`）
> 前次审查：INDEPENDENT-REVIEW-2.md（1 条 🔴 Critical · D5 与 R2 矛盾）
> 再审查范围：仅验证上次 🔴 Critical 是否已修复 + 扫描是否有新引入问题

---

### 上次 🔴 Critical 修复验证：R1（D5 与 R2 矛盾）

**修复前状态**（前次审查记录）：D5 决策列写"改为环境变量占位符字符串"，R2 缓解列写"保留硬编码值不变"。两条指令互斥——一个要求改 config 文件格式，另一个要求不改。

**当前 DESIGN.md 验证**：

- **D5（第 77 行）**：当前决策列写 "stop-hook.json 保留硬编码值不变"，备选列写 "改为环境变量占位符字符串"，选择理由明确写 "脚本层 D1 已实现 env-var-first，无需改 config 文件格式。stop-hook.json 是 11 个 hook 模块的共享配置中心，改格式会造成跨模块破坏性变更（参见风险 R2）"。决策方向明确：不改 config 文件。
- **R2（第 152 行）**：缓解措施写 "stop-hook.json 保留 `deepseek-v4-flash` 硬编码值作为显式 fallback"。方向一致：不改 config 文件。
- **Section 2.1 数据流图（第 91-93 行）**：模型解析逻辑为 Bash 参数扩展单链 `${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get ... "deepseek-v4-flash")}`，无 config 文件占位符展开分支。干净。
- **Section 3 ADR（第 142 行）**："无不可逆架构决策。所有决策均为 hook 脚本内部实现细节，不影响 flow-kit 外部接口契约。" 由于 D5 不再涉及 config 文件格式变更，此声明成立。

**结论**：🔴 Critical 已修复。D5 与 R2 之间不再存在互斥指令。D1（脚本层 env-var-first）独立承担 env var 配置化职责，D5 退化为显式否决危险备选的记录性决策。

---

### 连带修复验证：前次 🟡 Major（R2/R3/R4）

由于本审查仅依据 DESIGN.md（不读 REQUIREMENT.md），以下仅验证 DESIGN 文档内部的修复一致性：

- **前次 R2（AC-5 对齐，🟡 Major）**：DESIGN.md 内部不再有 config 文件格式变更指令。D1 的取舍代价列虽未按前次建议追加"明确不修改 stop-hook.json 格式"，但 D5 本身已承担此语义，信息不丢失。无新增矛盾。
- **前次 R3（eval 风险，🟡 Major）**：D5 不再要求 config 文件中存储 `${...}` 占位符，因此脚本无需 eval/sed 展开 config 值。eval 注入面自然消除。DESIGN.md Section 4 无需新增 eval 风险条目。
- **前次 R4（ADR 轻率，🟡 Major）**：Section 3 声明"无不可逆架构决策"现准确成立。D4（预设命名）虽具用户界面契约属性，但语义化英文名可按加法扩展（新增 preset，不改已有），不构成不可逆变更。分类合理。

---

### 🟢 R7 · R5 描述含技术错误——不影响设计正确性

**Symptom**：DESIGN.md 第 157-159 行 R5 风险描述中括号注写道 "Bash 不会在 `-x` 中展开字符串内的变量，但 Header 值仍会展开——需确认"。该技术陈述不准确：Bash 的 `set -x` 确实会展开双引号字符串内的变量，`curl -H "Authorization: Bearer $TOKEN"` 在 `set -x` 下会将 token 明文打印到 stderr。

**Source**：对 Bash `set -x` 行为的误解。正确的认知是：`set -x` 会在命令执行前将所有已完成参数展开的命令行打印到 stderr，包括双引号内的变量值。

**Consequence**：技术陈述错误但不影响设计结论——R5 的缓解措施"禁止在 hook 脚本中使用 `set -x`"本身是正确的防护手段。该条目写入 DESIGN.md 若被未来读者当作 Bash 行为参考，可能传播错误认知。实际影响极低，因为项目标准是 `set -euo pipefail`（不含 `-x`），且 hook 脚本实践中几乎不会加 `-x`。

**Remedy**：修正括号注为准确表述："`set -x` 会展开并打印所有变量（包括 Header 值），因此必须禁止在含 auth token 的脚本中使用 `set -x`"。此项修正不影响任何设计决策，可在实现阶段顺手修复。

---

### 🟢 R8 · Section 2.1 数据流图缺错误路径——设计取舍，非缺陷

**Symptom**：前次审查 R6 指出数据流图仅展示正常路径，缺双重 API 故障时的降级行为。

**当前状态**：未修改。数据流图仍仅展示正常分支。

**评估**：DESIGN.md 的 Section 2.1 定位为变更带来的新数据流展示——即 env-var-first 模型解析链 + API 调用优先级调整。API 故障降级逻辑（fail_count + max_failures）是 29-independent-review.sh 的既有机制，非本次变更引入，在设计层面的数据流图中不重复展示属于合理取舍。Section 4 风险表 R1 已覆盖"API 调用静默失败"场景并给出缓解措施。Section 4 风险表 R5 已覆盖 token 泄露场景。异常路径的完整定义属于 4-dev 实现细节，不构成设计文档缺陷。

**结论**：维持前次 🟢 Minor 评级，但不视为需要修复的设计问题。

---

### 新问题扫描结果

对修改后的 DESIGN.md 逐段扫描，未发现以下类型的新引入问题：
- 决策间矛盾（所有 D1-D5 方向一致，均服务于 env-var-first 目标）
- 与 CONTEXT.md 已锁决策冲突（已逐一核对已锁决策 123-135 行，无冲突）
- 触碰禁动清单（Section 0.5.1 禁动清单明确列出禁动模块，新 D5 不涉及任何禁动项）
- 风险遗漏（Section 4 覆盖实现、上线、债务、兼容、安全五个维度）
- 跨模块契约隐性变更（D5 改为"不改 config 文件"后，stop-hook.json 消费者不受影响）

---

**Verdict**: pass

**理由**：上次审查的 1 条 🔴 Critical（D5 与 R2 矛盾）已修复——当前 DESIGN.md 中 D5 决策为"保留硬编码值不变"，与 R2 缓解措施及 D1 策略完全一致，Section 2.1 数据流图中无 config 文件占位符展开分支，不再包含互斥指令。3 条前次 🟡 Major 连带消除。新增 2 条 🟢 Minor（R7: R5 技术描述微瑕；R8: 数据流图缺错误路径属设计取舍），均不构成阻塞。该 DESIGN.md 当前状态可直接用于 4-dev 实现阶段。
