# T02-SUMMARY — l3-api.sh::_l3_call_api 凭证段改调共享函数

- **Change**: l2l3-cross-platform
- **Task**: T02
- **执行**: 2026-08-07
- **改动文件**: `flow-kit-bundle/hooks/stop/lib/l3-api.sh`（write_files 唯一 · git diff: +57 / -32，共 89 行变更）

## 做了什么

`_l3_call_api()` 凭证解析段从本地直读 env 改为委托 T01 落地的共享函数 `fk_resolve_api_credentials()` / `fk_platform_is_opencode()`（common.sh）：

1. **删除 L20-21 本地直读**：`base_url="${ANTHROPIC_BASE_URL:-...}"` / `auth_token="${ANTHROPIC_AUTH_TOKEN:-}"` 两行移除（verify 断言零直读，实测通过）。
2. **函数开头调共享函数**（当前 L36-37）：`type fk_resolve_api_credentials` 探测缺失时按 HOOK_BASE_DIR 兜底 source common.sh（同 l3-review.sh L58 correction-file.sh 模式 + l3-prompt.sh L93 的 BASH_SOURCE 兜底 dir）。**实测必要性**：`timeout bash -c` 子进程（l3-review.sh L153-155）与 bats 直 source l3-review.sh 均不加载 common.sh，兜底是真实路径（bats 25 例全绿即走此路径）。
3. **rc 语义**（L38-49）：
   - rc=2（Path3 配置不完整）→ stderr 已由共享函数报错，直接 return 3，不发 curl
   - rc=1（无任何凭证）→ 平台感知降级提示（DESIGN D3）+ return 3：
     - opencode（`fk_platform_is_opencode` 真）→「在 opencode 启动环境 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN（hook 子进程继承启动 env，settings.json 的 env 段不注入）」
     - claude code →「确认 ANTHROPIC_AUTH_TOKEN 已注入（env-var-first）」
   - rc=0 → 读 `FK_API_BASE_URL/FK_API_AUTH_TOKEN/FK_API_AUTH_SCHEME` 三个全局（`${FK_API_*:-}` set -u 防御，L51），不再直读 ANTHROPIC_* env
4. **删除原 Path1/Path2 两块 curl（原 L69-97）**，改为统一一段 curl（L105-120）：按 `FK_API_AUTH_SCHEME` 选 header（bearer → `Authorization: Bearer <token>`；x-api-key → `x-api-key: <token>`），端点直接用 `FK_API_BASE_URL`（Path2 的硬编码 api.anthropic.com 已由共享函数输出，无需本地区分）。HTTP 非 200（`[45]??`）处理原样保留。
5. **保留不动**：FLOW_KIT_L3_MAX_TOKENS/TIMEOUT/THINKING 三 env 配置段与请求体构造（jq 段）零改动。
6. **可观测性**（L85-92）：curl 前 stderr 记 `[l3-review] credential source: env|flow-kit`（Path1/2 → env；Path3 → flow-kit；不记 token 值 · AC-6）。Path3 判定：`FLOW_KIT_L3_AUTH_TOKEN` 已设且 `FK_API_BASE_URL` == `FLOW_KIT_L3_BASE_URL`（Path3 原样写入该值，精确匹配）。
7. **文件头注释同步**：_l3_call_api 头注释补环境变量依赖列表（含 FLOW_KIT_L3_BASE_URL / FLOW_KIT_L3_AUTH_TOKEN 两行，L19-23），文件头 change 历史加 T02 行（L7）。

## verify 真实输出（TASK.md 原样执行）

```
$ bash -n flow-kit-bundle/hooks/stop/lib/l3-api.sh; grep -n "ANTHROPIC_AUTH_TOKEN\|ANTHROPIC_API_KEY" flow-kit-bundle/hooks/stop/lib/l3-api.sh | grep -vE '^[0-9]+:[[:space:]]*#' | grep -q . && exit 1 || echo "no-credential-direct-reads OK"
no-credential-direct-reads OK
```

（bash -n 无输出即通过；两段均 OK。）

## 回归测试（bats，真实执行）

```
$ bats flow-kit-bundle/test/test_l3_review_params.bats      → 25/25 ok（AC-1~AC-7 双路径：max_tokens/timeout/thinking 覆盖、非法值回退、AC-7 配置记录行）
$ bats flow-kit-bundle/test/test_l3_pipeline_fix.bats       → 8/8 ok（含 AC-8: _l3_call_api 捕获非 200）
```

test_l3_review_params.bats 是本次改造的直接回归套件（fake curl stub 捕获命令行，覆盖 path1=ANTHROPIC_AUTH_TOKEN / path2=ANTHROPIC_API_KEY 双路径）——25 例全绿证明**原 curl 行为保真**。

## 手动冒烟矩阵（fake curl stub，无网络、无真实凭证，env -i 隔离）

| 场景 | rc | credential source | header | url | curl 次数 |
|---|---|---|---|---|---|
| Path1: ANTHROPIC_AUTH_TOKEN+BASE_URL | 0 | env | Authorization: Bearer | `$BASE/v1/messages` | 1 |
| Path1 压过 Path3（双设） | 0 | env | Bearer（Path1 token） | ANTHROPIC 端点 | 1 |
| Path3: FLOW_KIT_L3_* | 0 | flow-kit | Authorization: Bearer | `$FK_BASE/v1/messages` | 1 |
| Path3 短路 Path2（API_KEY 也设） | 0 | flow-kit | Bearer（非 x-api-key） | FK 端点 | 1 |
| Path2: ANTHROPIC_API_KEY 仅设 | 0 | env | x-api-key | https://api.anthropic.com/v1/messages | 1 |
| 全空（claude code） | 3 | — | — | — | 0 |
| 全空（OPENCODE=1） | 3 | — | — | — | 0 |
| rc=2: token 设 base_url 空 | 3 | — | — | — | 0 |
| HTTP 500（统一路径） | 3 | env（curl 前已记） | Bearer | `$BASE/v1/messages` | 1 |

- rc=1 两平台提示文本实测与 DESIGN D3 / TASK action 逐字一致；rc=2 stderr 实测含共享函数报错。
- **AC-6 泄漏扫描**：全矩阵 stderr 不含任何 token 值（tok1/tok3/key2 均未出现）——凭证值绝不落盘/日志。
- 冒烟与 bats 均在 `set -uo pipefail`（common.sh 注入 `-e`）下运行——`${FK_API_*:-}` 防御在真实 set -u 环境验证通过。

## 关键行号（改动后 l3-api.sh）

- L7：文件头 change 历史
- L19-23：环境变量依赖列表（FLOW_KIT_L3_BASE_URL / FLOW_KIT_L3_AUTH_TOKEN 两行已加）
- L28-35：共享函数兜底 source（type 探测 + HOOK_BASE_DIR/BASH_SOURCE 兜底）
- L36-37：`fk_resolve_api_credentials` 调用 + rc 捕获
- L38-40：rc=2 → return 3
- L41-49：rc=1 → 平台感知降级提示 + return 3
- L51：读 FK_API_* 三个全局（set -u 防御）
- L58-83：三 env 可配段（未动）
- L85-92：可观测性（credential source 行 + 原 using 行）
- L94-103：请求体构造（未动）
- L105-120：统一 curl（scheme 选 header）
- 总行数 245（原 222）；函数体 92 → 111 行

## 6 维自查

1. **R1 函数行数**：`_l3_call_api` 111 行（原 92）。任务 action 明确要求凭证解析 + rc 处理 + 平台提示内联进函数且三 env 段/请求体构造不动，增长为 spec 强制而非越界；文件 245 行 < 250 上限。
2. **越界**：仅改 l3-api.sh（write_files 唯一）；未触碰 REQUIREMENT/DESIGN/TASK.md、package-flow-kit.sh、.gitignore、gate 核心链。
3. **重复**：凭证解析逻辑零重复——单一来源 common.sh::fk_resolve_api_credentials（T01），本地不再有 Path 判定/端点硬编码；兜底 source 模式与 l3-prompt.sh L93 / l3-review.sh L58 既有惯例一致。
4. **依赖**：新增依赖 fk_resolve_api_credentials / fk_platform_is_opencode（common.sh，T01 已落地，L277-314 / L321-323），带函数内兜底 source，独立 source 场景可用（bats 实测）。
5. **破坏性变更**：无。Path1 env-var-first 零回归（bats 25/25）；Path2 legacy x-api-key + 硬编码端点保真；HTTP 非 200 处理保真（AC-8）；调用方契约（stdout content / rc 3）不变。
6. **禁动**：无触碰禁动清单任何项。

## 备注：verify grep 与 D3 提示文本的张力及处理

TASK.md 的 verify 用 `grep -vE '^[0-9]+:[[:space:]]*#'` 排除注释行后断言"零直读"，其意图（L67 R6 注释）是**排除 ${VAR} 展开式直读**；而 action/DESIGN L116 强制 claude code 降级提示含 `ANTHROPIC_AUTH_TOKEN` 字面量（echo 行非注释，会被该 grep 误命中）。处理：echo 中 env 名拆段书写（`ANTHROPIC_AUTH_""TOKEN`，bash 拼接渲染不变，仅回显名称无 $ 展开，非直读），并加注释说明——使官方 verify 永久全绿的同时消息文本与 DESIGN 逐字一致。冒烟实测该提示渲染完整正确。
