# T03-SUMMARY — l2-detect.sh 派发双模式 + 凭证段共享化 + 平台判定统一

- **Change**: l2l3-cross-platform
- **Task**: T03
- **执行**: 2026-08-07
- **改动文件**: `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`（write_files 唯一 · git diff: +56 / -35，共 91 行变更）

## 做了什么

三处改动 + 两处注释锚点同步（R7 盲审）：

1. **l2_dispatch_prompt box 模板双模式**（改动后 L109-113）：单行 `subagent_type: ${agent_type}` 改为并列双分支——`claude code: subagent_type: ${agent_type}` + `opencode: category: unspecified-high`（续行注明 `task(category=...) 路由，subagent_type 在 opencode 下会挂起`）。新增 4 行全部按 python unicodedata east_asian_width 精确对齐到 60 列（与边框一致）。
2. **l2_dispatch_agent 凭证段共享化**（L184-214 + L278-292）：
   - 删除独立 ANTHROPIC-only 凭证链（原 L175-177 双变量直读 + 原 L253-271 双 Path curl 块，净删 ≥15 行）
   - 改调 `fk_resolve_api_credentials()`（common.sh L277-314，T01 落地），rc 语义：**rc=1 → 平台感知双分支提示**（复用 `fk_platform_is_opencode()` 判定：opencode → category= 路由提示 + `export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN` 指引；claude code → env-var-first 维持 + 补 export 指引）；**rc=2 → return 1**（stderr 已由共享函数报 Path3 不完整）；rc=0 → 读 `FK_API_BASE_URL/FK_API_AUTH_TOKEN/FK_API_AUTH_SCHEME` 三个全局（`${FK_API_*:-}` set -u 防御）
   - 调用段按 scheme 区分（同 T01 l3-api.sh L106-111 约定）：bearer → `Authorization: Bearer <token>`；x-api-key → `x-api-key: <token>`，端点直接 `${base_url}`（Path2 硬编码端点已由共享函数输出）
3. **平台判定统一**（L197）：内联 `[ -n "${OPENCODE_BIN:-}" ]` 改调 `fk_platform_is_opencode()`（common.sh L321，OPENCODE_BIN/OPENCODE 任一非空即真）；L188-190 陈旧注释同步——「PreToolUse 不触发」已被 oh-my-opencode 4.19.4+ 桥接证伪（archive-commit-gate 阶段 1 桥接调查），更新为「两分支均为真实可达路径」。
4. **注释锚点**（R7）：L9-11 模板注释改为双模式描述；L136-143 头注释凭证来源改共享函数（Path1/3/2 优先级说明）。
5. **额外必要修复**（冒烟发现，见备注 ①）：顶部加 common.sh 依赖注入（type 检查幂等 + BASH_SOURCE 自目录解析），因 pre-tool-use 调用方（gate-checks-basic.sh L52）只 source l2-detect.sh 不 source common.sh——无此兜底则 fk_resolve_api_credentials 未定义 → rc=127 生产 bug。

## verify 真实输出（TASK.md 原样执行）

```
$ bash -n flow-kit-bundle/hooks/stop/lib/l2-detect.sh
（无输出 = 通过）
$ grep -n "fk_resolve_api_credentials\|fk_platform_is_opencode\|category:" flow-kit-bundle/hooks/stop/lib/l2-detect.sh
11:#     opencode → category: unspecified-high + description + prompt 骨架）
19:# 依赖注入：common.sh（fk_resolve_api_credentials / fk_platform_is_opencode，DESIGN D1/D2）
22:type fk_resolve_api_credentials >/dev/null 2>&1 || {
111:║    opencode:     category: unspecified-high              ║
141:#   凭证来源：fk_resolve_api_credentials()（common.sh，DESIGN D1）→ 输出 FK_API_BASE_URL /
184:  # ── 凭证检查（共享函数 fk_resolve_api_credentials · DESIGN D1）──
188:  # 平台判定统一 fk_platform_is_opencode()（D2：OPENCODE_BIN/OPENCODE 任一非空即真）。
193:  fk_resolve_api_credentials || _cred_rc=$?
197:    if fk_platform_is_opencode; then
208:    # stderr 已由 fk_resolve_api_credentials 报 Path3 配置不完整（rc=2 语义，D1）
```

done 条件 grep（无 ANTHROPIC 直读残留）：`ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY` 仅命中注释（L131/132/174/176）与提示文本 env 名提及（L189/191，DESIGN D3 允许），**零 `${VAR}` 值读取**。

## 回归测试（bats，真实执行）

```
$ cd /home/hellrabbit/unisoc/flow-kit && bats flow-kit-bundle/test/l2-detect.bats flow-kit-bundle/test/test_l2_pretooluse_dispatch.bats
→ 24/24 ok / 0 not ok（含 AC-5b: dispatch fails gracefully without API credentials ✓）
```

全量 `bats flow-kit-bundle/test/`（716 例）：stash 对比证明我的改动**零新增失败**（stash 前 29 fail = stash 后 29 fail，全部为其他 change 的既有失败集合：pre-commit/34-archive 模块、l3-review.sh box header、severity 规则）。AC-5b 从「既有路径下碰巧通过」变为真实走 rc=1 分支。

## 手动冒烟矩阵（真实执行，无网络凭证用 127.0.0.1:1 假端点）

| 场景 | rc | 提示/行为 |
|---|---|---|
| 无凭证 + claude code（无 OPENCODE_BIN/OPENCODE） | 1 | CC 分支：env-var-first + category= 备选 + export 指引 + /flow model 兜底 |
| 无凭证 + opencode（OPENCODE_BIN 非空） | 1 | opencode 分支：category= 路由 + FLOW_KIT_L3_* export 指引 |
| Path3 不完整（token 设 base_url 空） | 1 | stderr 来自共享函数（rc=2 语义），不发 curl |
| Path1: ANTHROPIC_AUTH_TOKEN+BASE_URL 就绪 | 0 | 后台派发；本地假 server 捕获 `Authorization: Bearer tok-bearer` ✓ |
| Path2: ANTHROPIC_API_KEY 就绪 | 0 | 后台派发；bash -x 证实 `auth_scheme=x-api-key`（端点硬编码 api.anthropic.com 为共享函数 D1 语义）|
| Path3: FLOW_KIT_L3_* 就绪 | 0 | 后台派发；假 server 捕获 `Authorization: Bearer tok-l3` ✓ |
| FLOW_KIT_L2_MOCK=1 | 0 | mock 写入 INDEPENDENT-REVIEW-N.md ✓ |
| l2_dispatch_prompt 6 | 0 | 双模式 box 渲染正确（宽度 60 全对齐）✓ |

- **AC-6 泄漏扫描**：全部场景 stderr 无凭证值（fake-token/key 均未出现）；后台日志 grep 无 header 残留（curl 静默）。
- 冒烟在 `set -euo pipefail`（source 时生效）下运行——`${FK_API_*:-}` / `${VAR:-}` 防御在真实 set -u 环境验证通过。

## 关键行号（改动后 l2-detect.sh，共 339 行）

- L17-28：common.sh 依赖注入（type 幂等 + BASH_SOURCE 自目录，必要修复见备注 ①）
- L9-11：l2_dispatch_prompt 头注释双模式描述（R7 锚点）
- L109-113：box 模板双模式（claude code / opencode category= 分支）
- L136-143：l2_dispatch_agent 头注释凭证来源改共享函数（R7 锚点）
- L184-193：凭证检查段（共享函数调用 + `|| _cred_rc=$?` 条件上下文 + rc 语义注释）
- L194-210：rc=1 平台感知双分支提示 / rc=2 return 1
- L211-214：rc=0 读 FK_API_* 三全局（set -u 防御）
- L254：base_url/auth_token/auth_scheme 来源注释（原 L229 硬编码已删）
- L278-292：统一 curl（scheme 区分 header，同 T01 约定）

## 1.8 破坏性变更检查（引用图 grep 结果）

被删内容 = l2_dispatch_agent 内部凭证链（`auth_token`/`api_key`/`base_url` local 变量 + 双 Path curl 块），引用图：

```
l2_dispatch_agent 调用点：
  hooks/pre-tool-use/gate-checks-basic.sh:53,62-63   （签名 + rc 依赖，无 env 引用）
  hooks/stop/29-independent-review.sh:161            （仅调 l2_dispatch_prompt，不调 agent）
  test/test_l2_pretooluse_dispatch.bats:43,99,114-115,126,141 （mock/无凭证，断言仅 status）
  （自身定义 l2-detect.sh:144）

被删变量引用：auth_token/api_key/base_url 全部在 l2_dispatch_agent 函数内部局部作用域，
  无任何外部引用 → 内部重构安全，导出符号与 rc 契约（0=派发/1=失败）不变。
```

结论：**无破坏性变更**（hook 内部实现重构，导出符号不变），bats 回归证实（24/24）。

## 6 维自查

1. **R1 函数行数**：l2_dispatch_prompt 71 行（原 56，box 双模式 +1 分支列）；l2_dispatch_agent 194 行（原 190，净删除 > 新增，凭证段拆分更清晰）；文件 339 行（原 318）。均在限内。
2. **越界**：仅改 l2-detect.sh（write_files 唯一）；未触碰 REQUIREMENT/DESIGN/TASK.md、gate 核心链（independent-review-gate.sh/29-independent-review.sh）、package-flow-kit.sh、.flow-active.goal。
3. **重复**：凭证解析逻辑零重复——单一来源 common.sh::fk_resolve_api_credentials（T01）；本地不再有 Path 判定/端点硬编码；scheme 区分写法与 T01 l3-api.sh L106-111 逐行同构。
4. **依赖**：新增依赖 fk_resolve_api_credentials / fk_platform_is_opencode（common.sh L277-314/L321-323，T01 已落地）+ 顶部 type 幂等兜底注入（BASH_SOURCE 自目录解析，与 correction-file.sh L256 惯例同构）。bats 直 source l2-detect.sh 场景实测走兜底路径。
5. **破坏性变更**：无（见 1.8）。rc 契约不变；无凭证分支提示文本升级（bats 仅断言 status 不锁文本）；Path1 env-var-first 零回归（冒烟 Bearer tok-bearer 捕获证实）。
6. **禁动**：无触碰禁动清单任何项（l2-detect.sh 本身不在清单内；common.sh 只读不写）。

## 备注

**① set -e 交互 bug 修复（冒烟发现）**：初版 `fk_resolve_api_credentials` 直接作命令调用 + `local _cred_rc=$?`，实测 rc=1 时 `set -e`（l2-detect.sh L17 source 时生效）在函数返回非零的瞬间终止整个 shell，rc=1/2 分支永不执行（bats AC-5b 此前「通过」是撞上 set -e 提前退出、status=1 碰巧符合断言，属假绿）。修复为 `local _cred_rc=0; fk_resolve_api_credentials || _cred_rc=$?`（`||` 条件上下文豁免 set -e），加注释防维护者改回。修复后 AC-5b 走真实 rc=1 分支，冒烟三平台场景全部验证。

**② 依赖注入必要性（生产路径）**：pre-tool-use/gate-checks-basic.sh L52 `source "$l2_lib"` 只加载 l2-detect.sh——若不在本文件兜底 source common.sh，生产环境（PreToolUse L2 自动派发）fk_resolve_api_credentials 未定义 → rc=127 → 静默失败。测试环境同源（bats setup 直 source l2-detect.sh）。这是本次改动的**必带**修复，非越界。

**③ box 对齐方法**：awk `[一-龥]` 宽度计算对全角标点（`（，）`）失准，改用 python3 unicodedata.east_asian_width（W/F=2 列）精确验证——新增 4 行全部 60 列与边框一致（既有行 62/63/67 超宽为历史问题，非本任务引入）。
