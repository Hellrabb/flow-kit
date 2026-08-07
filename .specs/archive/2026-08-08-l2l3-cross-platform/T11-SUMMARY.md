# T11-SUMMARY · 新增 bats 测试：凭证解析矩阵 + 派发模式 + 平台提示（AC-1/2/3/4）

Change：`l2l3-cross-platform`
任务：T11（TASK.md 定义块）· 2026-08-07

## 变更内容

新增两个 bats 测试文件（仅 write_files，未触碰任何实现/既有测试）：

| 文件 | 用例数 | 覆盖 |
|---|---|---|
| `test/test_l3_credential_resolution.bats` | 17 | AC-1 / AC-2 / AC-3 / R4（fake curl header 盲审） |
| `test/test_l2_dispatch_mode.bats` | 7 | AC-4（双模式 + 结构断言）/ AC-3（correction 载体边界） |

### test_l3_credential_resolution.bats（17 用例）

- **凭证优先级矩阵（7）**：Path1>Path3（三源并存取 Path1，且断言 Path3 base 未泄漏）/ Path1>Path2 / Path3>Path2（短路 legacy key）/ 仅 Path1 / 仅 Path3 / 仅 Path2（x-api-key + 硬编码端点）/ 全空 rc=1。
- **Path3 配置不完整（1）**：token 有 base_url 空 → rc=2 + stderr 精确断言「FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空」；**同时置 ANTHROPIC_API_KEY** 证明未落 Path2（FK_API_BASE_URL 未被 Path2 硬编码端点覆盖）。
- **fk_platform_is_opencode 三态（1）**：OPENCODE=1 / OPENCODE_BIN=/usr/bin/opencode / 全空。
- **l2_dispatch_agent 同源断言 AC-1（1）**：source l2-detect.sh 后**函数替换** `fk_resolve_api_credentials`（打标记 + 注入就绪凭证 + fake curl 函数防真实网络），断言派发路径实际调用共享函数。
- **AC-3 平台提示（4）**：`_l3_call_api` rc=1 两平台（opencode → FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN export 指引；CC → ANTHROPIC_AUTH_TOKEN + env-var-first）+ `l2_dispatch_agent` rc=1 两平台（opencode → + category=；CC → ANTHROPIC_AUTH_TOKEN）。
- **scheme/header 断言 R4（3）**：PATH 前置 fake curl 脚本捕获 `-H` 参数（`CURL_ARGS:$*` 落 log + canned 200 响应）——Path2 → `x-api-key:` header 且无 `Authorization: Bearer`；Path1/Path3 → `Authorization: Bearer <token>` 且无 `x-api-key:`。AC-2 Path2 行为真实覆盖。

### test_l2_dispatch_mode.bats（7 用例）

- **l2_dispatch_prompt 双模式（4）**：OPENCODE=1 → 含 `category=` / `category: unspecified-high`；unset → 含 `subagent_type` / `subagent_type: architect-reviewer`；box 两分支共存断言；phase→agent_type 映射（1/5→qa-expert、2/3/7→architect-reviewer、6→code-reviewer）。
- **AC-4 结构断言（1）**：6 个 prompt 文件（1-requirement/2-design/3-task/5-test/6-review/7-integration）含 `subagent_type` 的必须含 `category=`（grep 循环，viol 计数 = 0）。
- **correction 载体 AC-3 边界（2）**：unit（直接调 `write_model_missing_correction` L2/L3）与 e2e（`l2_dispatch_agent` 凭证就绪 + 模型缺失 → rc=3 + type=l2-model-missing）双路径断言 message 含 `FLOW_KIT_L2/L3_MODEL` 但**不含 5 个凭证 env 完整名**（ANTHROPIC_AUTH_TOKEN / ANTHROPIC_BASE_URL / ANTHROPIC_API_KEY / FLOW_KIT_L3_AUTH_TOKEN / FLOW_KIT_L3_BASE_URL）。

## 关键实现事实锚点（测试针对真实实现）

- `common.sh` L277-314 `fk_resolve_api_credentials()`（三 Path 链 + rc 语义 0/1/2）；L321-323 `fk_platform_is_opencode()`
- `l3-api.sh` L31-37 凭证委托共享函数；L41-51 rc=1 平台感知降级提示；L107-115 统一 curl 按 FK_API_AUTH_SCHEME 选 header
- `l2-detect.sh` L17 `set -euo pipefail`；L192-210 凭证检查 + 平台感知双分支提示；L103-128 box 双模式；L256-263 model-missing correction
- `correction-file.sh` L99-127 `write_model_missing_correction`（message 只含模型 env 名）

## 环境隔离（任务环境说明落地）

- 每条用例 setup 保存 + unset 全部凭证 env（SAVED_* 风格，仿 test_independent_review_model.bats）
- 本 shell 常驻 `OPENCODE=1`——所有 CC 断言用例在 setup 显式 `unset OPENCODE OPENCODE_BIN`
- set -e trap：所有 source 后立即 `set +e`，非零返回一律 `|| _rc=$?` 条件上下文或 `run` 包装

## verify 输出（真实执行 · 2026-08-07）

```
$ npx bats test/test_l3_credential_resolution.bats test/test_l2_dispatch_mode.bats
1..24
ok 1  _test_l3_credential_path1_wins_all_three (Path1>Path3·Path3 短路 Path2·三源并存取 Path1)
ok 2  _test_l3_credential_path1_over_path2 (ANTHROPIC_AUTH_TOKEN 压制 ANTHROPIC_API_KEY)
ok 3  _test_l3_credential_path3_over_path2 (FLOW_KIT_L3_* 短路 legacy key)
ok 4  _test_l3_credential_path1_only
ok 5  _test_l3_credential_path3_only
ok 6  _test_l3_credential_path2_only (legacy x-api-key + 硬编码端点)
ok 7  _test_l3_credential_all_empty_rc1
ok 8  _test_l3_credential_path3_incomplete_rc2_no_path2 (token 有 base 空→禁止静默落 Path2)
ok 9  _test_l3_credential_platform_is_opencode_3_states
ok 10 _test_l3_credential_l2_dispatch_same_source (AC-1: l2_dispatch_agent 调用 fk_resolve_api_credentials)
ok 11 _test_l3_credential_ac3_hint_opencode_export_guidance (_l3_call_api)
ok 12 _test_l3_credential_ac3_hint_claude_code_env_var_first (_l3_call_api)
ok 13 _test_l3_credential_l2_dispatch_hint_opencode
ok 14 _test_l3_credential_l2_dispatch_hint_claude_code
ok 15 _test_l3_credential_scheme_path2_x_api_key_header (R4 fake curl)
ok 16 _test_l3_credential_scheme_path1_bearer_header (R4 fake curl)
ok 17 _test_l3_credential_scheme_path3_bearer_header (R4 fake curl)
ok 18 _test_l2_dispatch_prompt_opencode_mode_category
ok 19 _test_l2_dispatch_prompt_claude_mode_subagent_type
ok 20 _test_l2_dispatch_prompt_dual_mode_box_complete (两分支共存)
ok 21 _test_l2_dispatch_prompt_phase_agent_type_map (1/5→qa-expert 2/3/7→architect-reviewer 6→code-reviewer)
ok 22 _test_l2_dispatch_structure_6_prompts_subagent_type_have_category (AC-4)
ok 23 _test_l2_dispatch_correction_message_no_credential_env (AC-3 边界 · unit)
ok 24 _test_l2_dispatch_model_missing_correction_no_cred_env (AC-3 边界 · l2_dispatch_agent e2e)
```

**24/24 全绿（0 fail / 0 skip）**

## 回归锚点（25 用例基线，AC-7 证明无破坏）

```
$ npx bats test/test_fk_resolve_model.bats test/test_independent_review_model.bats test/test_model_degradation.bats
1..25
ok 1..25  （test_fk_resolve_model 10 + test_independent_review_model 12 + test_model_degradation 3）
```

**25/25 全绿**（输出见上方完整清单，逐条 ok）

## 6 维自检

- **R1 认知过载**：无新逻辑实现，纯测试断言——每条用例单一路径断言，helper（`_load_common` / `_load_l3_api` / `_load_l2_detect` / `_setup_fake_curl`）职责单一 ≤8 行。
- **R2 变更传播**：write_files 仅 `test/` 下两个新文件（TASK.md write_files 声明范围内）；实现零改动 → 无传播面。双源 `flow-kit-bundle/test/` 同步属 T12（depends_on 已声明），本任务不越界。
- **R3 知识重复**：三 Path 优先级 / rc 语义 / scheme 取值只从**真实实现**断言（common.sh L277-314 逐行对齐），未在测试内复制实现逻辑；矩阵值（p1-tok/p2-key/p3-tok）为测试局部 fixture，与实现无耦合。
- **R4 意外复杂度**：唯一"fake"是 R4 盲审明确要求的 PATH 前置 fake curl（`CURL_ARGS:$*` 捕获 -H 参数），且 fake curl 返回 canned 200 使 `_l3_call_api` 全链路（凭证→header→请求体→解析）真实执行；AC-1 同源断言用函数替换（任务明示二选一：bash -x 或函数替换），无多余抽象。
- **R5 依赖混淆**：所有 source 均指向 `$HOOK_BASE_DIR`（BATS_ROOT 向上查找，对齐 test_fk_resolve_model.bats），不依赖 `$HOME/.claude/hooks/` 安装副本；测试内替换的函数（`fk_resolve_api_credentials` / `curl`）只影响被测试的调用路径，不污染其他用例（bats 每用例独立子 shell）。
- **R6 域命名**：测试名遵循 `_test_l3_credential_*` / `_test_l2_dispatch_*` 前缀（TASK.md 命名规范）；文件 `test_<target>.bats`；Path1/Path2/Path3、bearer/x-api-key、FK_API_* 全局名与 CONTEXT.md/实现注释一致。

## 偏离记录

- 无偏离。`<done>` 声明「两个新文件全部用例绿」实测 24/24 达成（覆盖 AC-1/2/3/4 + R4）。
