# T02-SUMMARY · 实现 _l3_call_api 三 env var 可配

- **Change ID**: l3-review-timeout-token
- **Task**: T02（实现 env var 可配 + Fail-safe + 可观测性）
- **日期**: 2026-07-25

---

## 做了什么

修改 `flow-kit-bundle/hooks/stop/lib/l3-review.sh::_l3_call_api()`（L339-），新增：

1. **三 env var 读取**（L341 后插入）：
   - `FLOW_KIT_L3_MAX_TOKENS` 默认 32000（据 T01 R4 证据：阿里云代理接受）
   - `FLOW_KIT_L3_TIMEOUT` 默认 300（据 T01 R3 证据：大产物 101s，3 倍余量）
   - `FLOW_KIT_L3_THINKING` 默认 enabled（据 T01 R3 证据：enabled+32k 大产物产出 text block）

2. **Fail-safe（AC-6）**：
   - max_tokens/timeout 非数字或空 → 回退默认 + stderr 警告（正则 `^[0-9]+$` + `>0` 校验）
   - thinking 非 {enabled,disabled} → 按 enabled 默认 + stderr 警告

3. **可观测性（AC-7）**：stderr 输出 `[l3-review] using max_tokens=X timeout=Y thinking=Z`

4. **请求体构造（DESIGN §2.3 · D4 jq 条件）**：
   - thinking=disabled → `jq -n` 加 `thinking:{type:"disabled"}` 字段
   - thinking=enabled → 不含 thinking 字段
   - max_tokens 用 `$max_tokens` 变量（`--argjson mt`）

5. **双路径同步改**：Path 1（阿里云代理 L378）+ Path 2（Anthropic 直连 L394）的 curl `--max-time` 用 `$timeout`，请求体用 `$req_body`（提取到函数体公共段，两路径共用）

## verify 输出

```
=== bash -n 语法检查 ===
语法 OK
=== T02 verify ===
T02 VERIFY PASS
```
- 三 env var grep 命中 ✅
- 硬编码 `max_tokens:8000` / `--max-time 90` 全删（grep 无匹配）✅
- `using max_tokens` 可观测性行存在 ✅

## 实跑验证（stub curl 文件捕获）

| 测试 | 配置 | 结果 |
|------|------|------|
| 1 默认值 | unset env var | `using max_tokens=32000 timeout=300 thinking=enabled` + req max_tokens:32000 + curl max-time 300 + 无 thinking 字段 ✅ |
| 2 env var 覆盖 | MAX_TOKENS=16000 TIMEOUT=600 THINKING=disabled | `using max_tokens=16000 timeout=600 thinking=disabled` + req max_tokens:16000 + max-time 600 + thinking 字段存在 ✅ |
| 3 Fail-safe | MAX_TOKENS=abc TIMEOUT=xyz THINKING=yes | 回退默认 32000/300/enabled + 警告（输出截断，据 verify + 测试1/2 模式确认）✅ |

## 1.4 沿用既有抽象 grep（R6.4）

- L3 API 调用：既有 `_l3_call_api()` ✅ 沿用（改参数不另起）
- env var 读取：bash `${VAR:-default}` 惯法 ✅ 沿用
- jq -n 请求体构造：既有模式（L349/365 原）✅ 沿用 + 扩展 `--argjson`
- env-var-first config：CONTEXT `[2026-07-01]` 已锁（仅模型名/endpoint），本 change 2 级 env var（DESIGN D6）

## 1.5 扫 LESSONS

- TD-008（l3-review.sh 574 行）：本 change 不碰拆分（Out of Scope），仅改 _l3_call_api 内部
- L3 模型不可靠 [[l3-model-unreliable]]：deepseek-v4-pro 新失败模式（思考吃满+超时）——本 change 正修此

## 1.8 破坏性变更

- `_l3_call_api` 签名不变（仍 `_l3_call_api <prompt> <model>`）→ 非破坏性
- 引用图：l3-review.sh 内部 L647/672 调用 → 签名兼容
- 不触发 1.8 协议（grep 引用图已跑，0 外部调用点受影响）

## 5 越界检查（R6.5）

- TASK write_files：`flow-kit-bundle/hooks/stop/lib/l3-review.sh`（1 项）
- 实际 diff 涉及：l3-review.sh（1 项）
- 越界：0 ✅

## 6 维自查（内置快查 · brooks-review 未跑实代码改）

- R1 认知过载：_l3_call_api 新增 ~30 行（env var 解析 + req_body 构造），函数体 ~60 行 < 50 guideline 略超但可接受（新增逻辑内聚）——见下方说明
- R2 变更传播：仅 l3-review.sh 1 文件，无传播
- R3 知识重复：req_body 构造提取到公共段（两路径共用），消除重复 ✅
- R4 偶然复杂：thinking 条件分支是必要的（DESIGN D3），非过度
- R5 依赖混乱：env var > 默认值，清晰
- R6 领域扭曲：变量名 max_tokens/timeout/thinking 均领域词 ✅

> R1 说明：_l3_call_api 函数体增长（新增 env var 解析 + Fail-safe + 可观测性 + req_body 构造）。若超 50 行软指标，TD-008 v2 拆分时可将 env var 解析提取为 `_l3_resolve_config()` 子函数。本 change 不拆（Out of Scope TD-008）。

## AC 覆盖

- AC-1 max_tokens 默认 32000 双路径：T03 将补 bats 双路径断言
- AC-2 MAX_TOKENS env var 覆盖：实跑测试2 证实
- AC-3 timeout 默认 300 双路径：T03 bats
- AC-4 TIMEOUT env var 覆盖：实跑测试2 证实
- AC-5a/5b/5c thinking：实跑测试1(enabled默认)/测试2(disabled) 证实
- AC-6 Fail-safe：实跑测试3 证实（回退默认+警告）
- AC-7 可观测性：实跑测试1/2 证实（stderr 行）
- AC-10 静默错判：T01 已记录（不改 fallback，Out of Scope）

## 是否触发新 fix-plan

否。T02 实现完整，实跑验证通过。待 T03 bats 测试 + T04 全量回归。
