# DESIGN: L3 审查工具超时/token 上限可配置化

- **Change ID**: l3-review-timeout-token
- **关联**: `@.specs/l3-review-timeout-token/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/ARCHITECTURE.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> Bash 脚本项目，无传统技术栈。CONTEXT.md 已锁定，跳过技术栈选型。

- **语言/运行时**: Bash（`set -euo pipefail`）
- **测试**: bats-core 1.13.0（`npx bats`）+ stub curl mock 策略
- **关键依赖**: jq（JSON 构造/解析）、curl（L3 API 调用）
- **理由**: 项目既有栈，本 change 不引入新语言/框架/依赖
- **明确排除**: 无（纯 Bash 修改，无需选栈）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- flow-kit-bundle/hooks/stop/lib/l3-review.sh（既有 · _l3_call_api() L340-374 两处路径）

新增模块：
- 无（纯修改既有函数）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/stop/lib/common.sh（fk_resolve_model 等，不涉及）
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（L2 检测，不涉及）
- flow-kit-bundle/hooks/stop/lib/done-validation.sh（gate 校验，不涉及）
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（gate 编排，不涉及）
- flow-kit-bundle/hooks/stop/29-independent-review.sh（L3 触发，不涉及）
- 其余所有 hook/lib 文件
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| env var 读取 | `${VAR:-default}` bash 惯用法 | **沿用**：`FLOW_KIT_L3_MAX_TOKENS:-32000` 等 |
| env-var-first config 策略 | CONTEXT.md `[2026-07-01]` 已锁决策（env var > stop-hook.json > 硬编码，**仅限模型名/endpoint**，经 `fk_resolve_model` 3 级解析器） | **部分沿用**：三个 L3 工具参数（max_tokens/timeout/thinking）用 2 级 env var（env var > 默认值，bash `${VAR:-default}`），**不纳入 stop-hook.json 中间级**——属调用参数配置，与模型名解析属不同配置类（见 D6） |
| jq 请求体构造 | `jq -n --arg m --arg p '{model:$m,...}'`（L349/365 既有） | **沿用**：扩展 jq 表达式加 max_tokens/thinking 参数 |
| curl --max-time | 既有 `--max-time 90`（L346/362） | **沿用参数**，改值为 env var 可配 |
| hook log 输出 | `echo "[l3-review] ..." >&2`（既有模式） | **沿用**：可观测性 AC-7 用此模式 |

### 0.5.3 沿用模式 vs 引入新模式

```
- env var 配置：**沿用** bash `${VAR:-default}` 2 级惯法（env var > 默认值）。**注**：非完整 env-var-first 3 级链（CONTEXT `[2026-07-01]` 该策略仅限模型名/endpoint，经 `fk_resolve_model` 解析器）；本 change 的调用参数用 2 级足够，不纳入 stop-hook.json 中间级（见 D6 诚实修正）
- 请求体构造：**沿用** jq -n 模式，仅扩展参数（max_tokens 变量化 + thinking 条件字段）
- curl 调用：**沿用** 两路径结构（Path 1 阿里云代理 / Path 2 Anthropic 直连），仅改 --max-time 值
- Fail-safe：**引入** 非法值回退逻辑（新增——既有无，因原硬编码无非法值可能）
- 可观测性：**引入** 配置记录行（新增——既有无配置可记）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **max_tokens/timeout/thinking 三 env var 全可配** | 仅提高硬编码默认值（不可配） | env-var-first 是项目已锁策略（CONTEXT `[2026-07-01]`）；可配让用户按模型/产物大小调，不绑死 deepseek-v4-pro | 三个 env var 增加 `fk_resolve_model` 之外的配置面，但与既有 L2/L3 model env var 一致 |
| D2 | **默认值 max_tokens=32000 / timeout=300s** | 16000/240s（节省）或 64000/600s（更保守） | L3 子 agent 实测：deepseek-v4-pro 扩展思考 + 大产物（phase 3 TASK.md ~280 行 prompt）生成 ~144s + 思考吃满 8000 token。32k 给思考+结论留余量，300s 覆盖 144s+余量。比 16k/240s 保守（防大产物复发），比 64k/600s 节省 | max_tokens 4 倍增成本（REQUIREMENT 非功能性已声明可接受 + env var 可下调） |
| D3 | **thinking 默认 enabled，可切 disabled** | 默认 disabled（禁用思考）或硬编码 disabled | enabled 保留 deepseek-v4-pro 推理质量（首轮 L3 verdict=fail 9 条全可核实无幻觉，证明思考有益）；disabled 作 escape hatch（大产物/快速审查）。L3 子 agent 实测 disabled 38s 返 3334 token 含 text block | enabled 时仍可能在大产物吃满 32k（极端情况），需用户手动切 disabled |
| D4 | **thinking 字段用 jq 条件构造** | 拼字符串 | 沿用既有 jq -n 请求体构造模式（L349/365），thinking 作为可选字段条件加入 jq 表达式。比字符串拼接更安全（防 JSON 注入/转义问题） | jq 表达式稍复杂（条件字段），但与既有模式一致 |
| D5 | **Fail-safe：非法值回退默认 + 警告，不崩溃** | 非法值 exit 非零（fail-close） | env var 来自用户配置，非法值不应让 L3 工具崩溃（L3 是审查工具，非安全关键路径）。回退默认 + 警告让用户发现问题后修正，不阻塞 pipeline | 非法值静默回退可能掩盖配置错误——缓解：stderr 警告（AC-6/AC-7）让用户可见 |
| D6 | **不新增 ADR** | 新增 ADR（L3 工具可配置化） | 本 change 的 env var 读取用 bash 惯法 `${VAR:-default}`（2 级：env var > 硬编码默认），**不完整套用** env-var-first 3 级链（CONTEXT `[2026-07-01]` 该策略仅限模型名/endpoint，经 `fk_resolve_model` 3 级解析器）。三个 L3 工具参数（max_tokens/timeout/thinking）属调用参数配置，与模型名解析属不同配置类，直接 2 级 env var 足够，不需 stop-hook.json 中间级。故不新增 ADR，但**诚实修正**：不称"遵循 env-var-first 3 级链"，而是"2 级 env var 配置（env var > 默认值）" | 若后续 L3 工具参数需纳入 stop-hook.json 统一管理，届时可升级为 3 级 + 新 ADR |

---

## 2. 数据流 / 架构图

### 2.1 修改前（硬编码 · 失败）

```
l3_review_run
  └─> _l3_call_api(prompt, model)
        ├─ Path 1: curl --max-time 90 ... -d '{model, max_tokens:8000, messages}'
        └─ Path 2: curl --max-time 90 ... -d '{model, max_tokens:8000, messages}'
        
deepseek-v4-pro 扩展思考:
  ├─ thinking block 吃满 8000 token → 无 text block
  ├─ jq select(.type=="text") 返空 → rc=3
  └─ 生成 144s > 90s → curl 杀断 → HTTP 000 空响应 → rc=3
```

### 2.2 修改后（可配 · 可承载）

```
l3_review_run
  └─> _l3_call_api(prompt, model)
        ├─ 读 env var:
        │   max_tokens = ${FLOW_KIT_L3_MAX_TOKENS:-32000}  (非法→默认+警告)
        │   timeout    = ${FLOW_KIT_L3_TIMEOUT:-300}        (非法→默认+警告)
        │   thinking   = ${FLOW_KIT_L3_THINKING:-enabled}   (非法→enabled+警告)
        ├─ stderr: [l3-review] using max_tokens=X timeout=Y thinking=Z  (AC-7)
        ├─ Path 1: curl --max-time $timeout ... -d (jq -n 构造含 max_tokens + 条件 thinking)
        └─ Path 2: curl --max-time $timeout ... -d (同上)
        
deepseek-v4-pro:
  ├─ enabled: 32k 预算承载思考+结论 → text block 产出 → verdict 提取成功
  └─ disabled: 请求体含 thinking:{type:disabled} → 38s 返 text block → verdict 提取成功
```

### 2.3 jq 请求体构造（条件 thinking 字段）

```
# enabled（默认）——不含 thinking 字段
jq -n --arg m "$model" --arg p "$prompt_text" --argjson mt "$max_tokens" \
  '{model:$m, max_tokens:$mt, messages:[{role:"user", content:$p}]}'

# disabled——含 thinking:{type:disabled}
jq -n --arg m "$model" --arg p "$prompt_text" --argjson mt "$max_tokens" \
  '{model:$m, max_tokens:$mt, thinking:{type:"disabled"}, messages:[{role:"user", content:$p}]}'
```

> 实现用 if 分支选 jq 表达式（thinking=disabled 时用含 thinking 的表达式），或用 jq 条件 `(... | if $thinking=="disabled" then .thinking={type:"disabled"} else . end)`。DESIGN 定方向，具体语法 4-dev 实现。

---

## 3. 关键状态机

无。本 change 是纯参数化改造，不涉及状态流转。env var 读取 → 请求体构造 → curl 调用，无状态机。

---

## 4. ADR 索引

本 change 不新增 ADR。三个 env var（FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING）用 bash 2 级配置（env var > 默认值，`${VAR:-default}`），**不完整套用** env-var-first 3 级链（CONTEXT.md `[2026-07-01]` 该策略仅限模型名/endpoint，经 `fk_resolve_model` 解析器）。L3 工具参数属调用参数配置，2 级 env var 足够，不需 stop-hook.json 中间级（详见 D6 诚实修正）。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **实现风险**：thinking 字段 jq 条件构造语法错误 | 请求体 JSON 畸形 → API 400 → rc=3 | 低 | 4-dev 用 jq -n 本地验证请求体 JSON 合法；bats stub curl 断言请求体结构（AC-5a/5b/5c） |
| R2 | **更深的根因（L2 R1 揭示 · C3 落地）**：`_l3_parse_result` 的 fallback 链（l3-review.sh:378 `[.content[]|select(.type=="text")|.text][0] // .content[0].thinking // .content[0].text // empty`）在思考吃满预算无 text block 时，**可能提取思考内容当 verdict（静默错判，rc=0 假 verdict）**——比 rc=3 更危险。本 change 不改解析（Out of Scope），但说明 disabled thinking 的额外价值：消除 thinking block → fallback 链不触发 → 无静默错判风险 | 即使提高 max_tokens 到 32k，若思考仍偶尔吃满预算，fallback 链静默错判 | 中 | **本 change 不改 fallback**（属 `_l3_parse_result` scope，Out of Scope）。缓解：① disabled thinking 消除 thinking block（D3 escape hatch）② 建议后续 change 修 fallback：移除 `.thinking`/`.text` fallback，仅取 `select(.type=="text")`，无 text 则 rc=3 显式报错（不静默）。③ **4-dev 强制验证（C3 落地）**：enabled+32k 对大产物跑一次，打印 `.content[0]` 结构确认 thinking block 字段名 + 是否触发 fallback 静默错判——作为 AC/测试用例（见 REQUIREMENT AC-10），非"建议后续" |
| R3 | **默认值依据不足（L2 R3）**：thinking=enabled 默认对**大产物**零证据。唯一验证过大产物可用的是 disabled（58.4s 干净 text block）；enabled+32k 对大产物（如 phase 3 TASK.md ~280 行 prompt）从未测过。US-2 的目标场景正是大产物，默认走未验证路径不自洽 | 大产物场景 enabled+32k 仍可能思考吃满 → rc=3 或静默错判（R2） | 中 | 4-dev 须实测：enabled+32k 对大产物 prompt 跑一次，确认产出 text block。若仍失败，默认值改 disabled（牺牲推理质量换可用性）或进一步提高 max_tokens。**当前默认 enabled 保留**（首轮 L3 verdict=fail 9 条可核实无幻觉，证明思考对中等产物质量有益），但风险记录在案，实测后可调 |
| R4 | **上线风险**：32k max_tokens 在阿里云 deepseek 代理可能超上限被拒（400） | L3 调用 Path 1（阿里云代理，本 change 解套主路径）400 → rc=3 | 中 | **断言修正**：此前所有实测仅 max_tokens=8000，从未对阿里云 deepseek 代理验证 32000——"均支持大 max_tokens"是无证据断言。4-dev 须先实测：`curl` 阿里云代理用 max_tokens=32000 打一个最小 prompt，确认 HTTP 200 + text block。若代理拒，默认值下调至代理上限或改用 disabled thinking（thinking block 不占 token 预算）。env var 可下调作 escape hatch |
| R5 | **上线风险**：disabled thinking 被 API 忽略（仍扩展思考） | 大产物仍吃满 32k → rc=3 | 低 | AC-5 边界声明：只保证请求体字段正确，不保证 API 行为。L3 子 agent 实测 disabled 有效（38s 返 text block），但属 API 侧行为 |
| R6 | **长期债务**：env var 非法值回退可能掩盖配置错误 | 用户配错未察觉，L3 行为异常 | 低 | stderr 警告（AC-6/AC-7）让配置错误可见；可观测性 AC-7 记录实际使用值 |

---

## 6. 不在范围

- TD-008：l3-review.sh 574 行拆分（v2）
- thinking budget 精细化（`thinking:{type:"enabled", budget_tokens:N}`，依赖 API 支持，v2）
- L3 模型自动探测 + 非 thinking 模型推荐（v2）
- L3 prompt 构建优化（`_l3_build_prompt`，独立 scope）
- L3 结果解析优化（`_l3_parse_result`，独立 scope）
- L3 重审/积压扫描（`_l3_check_rerun`/`_l3_scan_backlog`，独立 scope）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

本 change 不新增 lib 级抽象。env var 读取用 bash 惯法（`${VAR:-default}`），无跨模块复用价值。

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L3 工具参数可配 | 三个 env var 覆盖 max_tokens/timeout/thinking | 所有 L3 审查调用（PreToolUse + Stop hook 两路径） | 低（删 env var 读取回退硬编码即可） |

### 9.3 新增 / 修改的跨模块契约

```
- l3-review.sh::_l3_call_api() 请求体 schema 扩展：max_tokens 可变 + 可选 thinking 字段
- 新增三个 env var 契约：FLOW_KIT_L3_MAX_TOKENS（数字）/ FLOW_KIT_L3_TIMEOUT（数字）/ FLOW_KIT_L3_THINKING（enabled|disabled）
```

### 9.4 新增 / 升级的依赖

无。

### 9.5 禁动清单变化

```
- 新增禁动：l3-review.sh::_l3_call_api() 的两路径结构（Path 1 阿里云代理 / Path 2 Anthropic 直连）
  后续 change 修改此函数须同步更新 test_l3_review.bats 的双路径 stub 测试
- 解禁：无
- 待 A-evolve 同步（R5）：ARCHITECTURE.md §1.3 NFR 基线 + env var 登记表须补三个新 var
  （FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING），由 A-evolve 批量同步
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
