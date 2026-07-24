# T01-SUMMARY · 实测探针（L3 工具证据收集）

- **Change ID**: l3-review-timeout-token
- **Task**: T01（实测探针，不改源码）
- **日期**: 2026-07-25
- **环境**: 阿里云 deepseek 代理（ANTHROPIC_BASE_URL=token-plan.cn-beijing.maas.aliyuncs.com）+ ANTHROPIC_AUTH_TOKEN（113 字符）+ deepseek-v4-pro

---

## 实测证据

> 三次 curl 探针（不改 l3-review.sh 源码，直接 curl 阿里云代理）。对应 DESIGN R2/R3/R4 + REQUIREMENT AC-10。

### R4 · 阿里云代理 max_tokens=32000 上限验证

- **探针**：max_tokens=32000，最小 prompt（"Reply with the single word OK"）
- **结果**：HTTP 200，2.7s，stop_reason=end_turn，output_tokens=35
- **结论**：**阿里云 deepseek 代理接受 max_tokens=32000**（Path 1，本 change 解套主路径）✅
- **对 DESIGN R4**：R4 风险（代理上限可能拒 32k）**未触发**——默认值 32000 可用，无需下调

### R3 · enabled+32k 对大产物可用性验证

- **探针**：max_tokens=32000 + 无 thinking 字段（enabled 默认），大产物 prompt（gate-done-authorship TASK.md ~200 行，模拟 L3 审查 prompt）
- **结果**：HTTP 200，**101.1s**，stop_reason=end_turn，output_tokens=4872，content_types=["thinking","text"]，含 text block（431 字符 verdict JSON）
- **结论**：**enabled+32k 对大产物可用** ✅
  - 101.1s < 300s timeout（改动 2 默认值）→ 不超时
  - 4872 < 32000 max_tokens（改动 1 默认值）→ 思考 + 结论均有空间，未吃满
  - 产出含 text block → `_l3_parse_result` 的 `select(.type=="text")` 命中 → verdict 可提取
- **对 DESIGN R3**：R3 风险（enabled+32k 对大产物零证据）**已补证据**——默认 enabled 保留成立，无需改 disabled

### AC-10 · content[0] 结构 + 静默错判判定

- **探针**：打印 R3 响应的 `.content[0]` 完整结构
- **结果**：
  - `content[0].type = "thinking"`
  - `content[0]` 字段名：`["signature", "thinking", "type"]`
  - thinking block 内容字段：**`.thinking`**（10365 字符的思考过程）
- **fallback 链分析**（l3-review.sh:378 `[.content[]|select(.type=="text")|.text][0] // .content[0].thinking // .content[0].text // empty`）：
  - **有 text block 时**（如本例）：fallback 第一路 `select(.type=="text")|.text` 命中 → 取 text（431 字符 verdict JSON）→ **正确，不触发静默错判**
  - **无 text block 时**（思考吃满 32k 极端情况）：fallback 第二路 `.content[0].thinking` 命中 → 取思考内容（10365 字符）当 verdict → **静默错判**（rc=0 假 verdict）
- **静默错判触发条件**：思考吃满 32k max_tokens 且无 text block——需极端大产物 + 思考膨胀。R3 实测 4872/32000，余量充足，本 change 默认配置下不易触发
- **对 DESIGN R2（L2 R1/C3 落地）**：R2 风险（fallback 静默错判）**确认存在但需极端条件**。本 change 不改 fallback（Out of Scope）。缓解有效：① disabled thinking 消除 thinking block（fallback 不触发）② 32k 默认值给足余量（实测 4872，15% 占用）

---

## 1.4 沿用既有抽象 grep（R6.4）

- L3 API 调用：既有 `_l3_call_api()`（l3-review.sh:339）✅ 沿用（本 change 改其参数，不另起）
- env var 读取：既有 bash `${VAR:-default}` 惯法 ✅ 沿用
- env-var-first config：CONTEXT.md `[2026-07-01]` 已锁，仅限模型名/endpoint ✅ 本 change 用 2 级 env var（非 3 级链，见 DESIGN D6）

## 1.5 扫 LESSONS

- `l3-review.sh` 相关：TD-008（574 行多职责，v2 拆分）——本 change 不碰拆分（Out of Scope），仅改 `_l3_call_api` 参数
- L3 模型不可靠（记忆 [[l3-model-unreliable]]）：deepseek-v4-pro 新失败模式（思考吃满+超时）——本 change 正是修此

## 1.8 破坏性变更

- T01 无代码改动（纯探针）→ 不触发 1.8 协议

## 5 越界检查（R6.5）

- TASK write_files：`.specs/l3-review-timeout-token/T01-SUMMARY.md`（1 项）
- 实际 diff 涉及：T01-SUMMARY.md（新建）
- 越界：0 ✅

## 6 维自查

- R1 认知过载：T01 无代码，N/A
- R2 变更传播：仅写 SUMMARY，无传播
- R3 知识重复：N/A
- R4 偶然复杂：探针逻辑直接，无过度
- R5 依赖混乱：N/A
- R6 领域扭曲：N/A

---

## 给 T02 的默认值依据

据 T01 证据：
- **max_tokens 默认 32000**：R4 证实代理接受；R3 证实对大产物 4872/32000 余量充足 → **保留 32000，无需下调**
- **timeout 默认 300s**：R3 实测 101.1s，300s 留 3 倍余量 → **保留 300s**
- **thinking 默认 enabled**：R3 证实 enabled+32k 对大产物产出 text block → **保留 enabled**

三项默认值据实测证据成立，T02 据此实施（无需调整 DESIGN D2 的默认值）。
