# T03-rev SUMMARY — bats 测试扩展：平台翻转矩阵 + AC-4b 工具名形状 + AC-6 断言

- **Change**: l2l3-cross-platform
- **Task**: T03-rev（Wave 2 · delta 任务 · depends_on T01-rev, T02-rev）
- **执行**: 2026-08-08
- **改动文件**（write_files 范围内，仅 2 个）:
  - `flow-kit-bundle/test/test_l3_credential_resolution.bats`（17 → 22 用例：+3 AC-2 翻转矩阵 +2 AC-6 红线）
  - `flow-kit-bundle/test/test_l2_dispatch_mode.bats`（12 → 14 用例：+2 AC-4b 工具名双形状）

## 背景

T01-rev 已落地 `common.sh::fk_resolve_api_credentials` 平台感知优先级（opencode: Path3>P1>P2 / CC: P1>P3>P2，rc 0/1/2），T02-rev 已落地 `transcript-parser.sh` 双形状 jq 过滤 + 归类分流。本任务把这两项 + AC-6 红线固化为正式 bats 断言，并显式覆盖「平台翻转」场景（既有 17 用例均为默认 CC 平台 + unset OPENCODE）。

## 做了什么

### 1. AC-2 平台翻转矩阵（test_l3_credential_resolution.bats +3 用例）

- **`_test_l3_credential_flip_opencode_path3_over_path1`** — `export OPENCODE=1` + Path3 + Path1 并存 → rc=0，`FK_API_AUTH_TOKEN=p3-tok`，**`FK_API_BASE_URL=https://fk-l3.example`（= FLOW_KIT_L3_BASE_URL，Path1 的 base 未泄漏）**，scheme=bearer
- **`_test_l3_credential_flip_opencode_path1_fallback`** — `export OPENCODE=1` + Path1 仅设（Path3 缺失）→ rc=0，`FK_API_AUTH_TOKEN=p1-tok` + base 尊重 `ANTHROPIC_BASE_URL`（CC 回归路径在 opencode 下也能走）
- **`_test_l3_credential_flip_claude_path1_over_path3`** — `export -n OPENCODE OPENCODE_BIN`（等价 `env -u OPENCODE -u OPENCODE_BIN` 平台翻转）+ Path1 + Path3 并存 → rc=0，`FK_API_AUTH_TOKEN=p1-tok`（**零回归**：CC 平台 Path1 依旧压制 Path3）

平台切换方式按 TASK.md：opencode = `OPENCODE=1`；claude code = unset（`export -n` 显式防御，setup 已 unset 兜底）。

### 2. AC-4b 工具名双形状（test_l2_dispatch_mode.bats +2 用例）

沿用既有 R4 测试模式（`_load_parser` + `HOOK_TMP_DIR` + `TRANSCRIPT_PATH` mock jsonl → `parse_transcript` → 断言 `subagent-usage.txt`）：

- **`_test_l2_dispatch_ac4b_cc_shape_subagent_type`** — mock CC 形状 `{"type":"tool_use","tool":"Agent","args":{"subagent_type":"code-reviewer"}}` → subagent-usage.txt 含 `code-reviewer`
- **`_test_l2_dispatch_ac4b_opencode_shape_state_input_category`** — mock opencode 形状 `{"type":"tool","tool":"task","state":{"input":{"category":"unspecified-high"}}}` → subagent-usage.txt 含 `unspecified-high`（**jq 路径定稿 `state.input.category`**——与 AC-4 mock + AC-4b + D4 + §9.3 一致，IR-3 R-1 修复）

### 3. AC-6 红线 bats 断言（test_l3_credential_resolution.bats +2 用例）

- `@test "AC-6 redline: no token values in runtime files"` — `run grep -rsE "=sk-[A-Za-z0-9]{8,}|=[A-Za-z0-9+/]{32,}={0,2}" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null; [ -z "$output" ]`（**R-F-A1 格式：断言输出空而非 exit code**——grep 缺文件 exit=2 陷阱，`.flow-active.interactive-ui-fix` 当前不存在即命中该路径，输出空=零命中=通过）
- `@test "AC-6 redline: no env names in runtime files"` — 同范围扫 `FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY`，`[ -z "$output" ]`
- **扫描范围不含 INDEPENDENT-REVIEW-*.md（R-F-A2 修复）**——审查文件由第三方 L2/L3 写入，不可约束其不写长字符串，钉进断言会假红；token 值红线在该文件保留 T12 verify 一次性验证

### 4. 既有用例保留

- test_l3_credential_resolution.bats 17 → 22（原 17 全部保留，零删）
- test_l2_dispatch_mode.bats 12 → 14（原 12 全部保留，零删）
- `test/` 开发源不碰（双源同步属 T04-rev · Wave 3）

## verify 真实输出（TASK.md 原样执行 · bats 二进制）

```
$ ~/.npm/_npx/cd2c4d46c11457b7/node_modules/bats/bin/bats flow-kit-bundle/test/test_l3_credential_resolution.bats flow-kit-bundle/test/test_l2_dispatch_mode.bats
1..36
ok 1 _test_l3_credential_path1_wins_all_three (Path1>Path3·Path3 短路 Path2·三源并存取 Path1)
ok 2 _test_l3_credential_path1_over_path2 (ANTHROPIC_AUTH_TOKEN 压制 ANTHROPIC_API_KEY)
ok 3 _test_l3_credential_path3_over_path2 (FLOW_KIT_L3_* 短路 legacy key)
ok 4 _test_l3_credential_path1_only
ok 5 _test_l3_credential_path3_only
ok 6 _test_l3_credential_path2_only (legacy x-api-key + 硬编码端点)
ok 7 _test_l3_credential_all_empty_rc1
ok 8 _test_l3_credential_path3_incomplete_rc2_no_path2 (token 有 base 空→禁止静默落 Path2)
ok 9 _test_l3_credential_flip_opencode_path3_over_path1 (AC-2: opencode Path3>Path1 并存取 Path3)
ok 10 _test_l3_credential_flip_opencode_path1_fallback (AC-2: opencode Path3 缺失→Path1 兜底)
ok 11 _test_l3_credential_flip_claude_path1_over_path3 (AC-2: CC Path1>Path3 并存取 Path1·零回归)
ok 12 _test_l3_credential_platform_is_opencode_3_states
ok 13 _test_l3_credential_l2_dispatch_same_source (AC-1: l2_dispatch_agent 调用 fk_resolve_api_credentials)
ok 14 _test_l3_credential_ac3_hint_opencode_export_guidance (_l3_call_api)
ok 15 _test_l3_credential_ac3_hint_claude_code_env_var_first (_l3_call_api)
ok 16 _test_l3_credential_l2_dispatch_hint_opencode
ok 17 _test_l3_credential_l2_dispatch_hint_claude_code
ok 18 _test_l3_credential_scheme_path2_x_api_key_header (R4 fake curl)
ok 19 _test_l3_credential_scheme_path1_bearer_header (R4 fake curl)
ok 20 _test_l3_credential_scheme_path3_bearer_header (R4 fake curl)
ok 21 AC-6 redline: no token values in runtime files
ok 22 AC-6 redline: no env names in runtime files
ok 23 _test_l2_dispatch_prompt_opencode_mode_category
ok 24 _test_l2_dispatch_prompt_claude_mode_subagent_type
ok 25 _test_l2_dispatch_prompt_dual_mode_box_complete (两分支共存)
ok 26 _test_l2_dispatch_prompt_phase_agent_type_map (1/5→qa-expert 2/3/7→architect-reviewer 6→code-reviewer)
ok 27 _test_l2_dispatch_structure_6_prompts_subagent_type_have_category (AC-4)
ok 28 _test_l2_dispatch_correction_message_no_credential_env (AC-3 边界 · unit)
ok 29 _test_l2_dispatch_model_missing_correction_no_cred_env (AC-3 边界 · l2_dispatch_agent e2e)
ok 30 _test_l2_dispatch_transcript_category_first (R4: .args.category 优先)
ok 31 _test_l2_dispatch_transcript_subagent_fallback (R4: category 缺失→subagent_type)
ok 32 _test_l2_dispatch_transcript_general_fallback (R4: 双空→general-purpose)
ok 33 _test_l2_dispatch_ac4b_cc_shape_subagent_type (AC-4b: CC 形状→subagent_type 归类)
ok 34 _test_l2_dispatch_ac4b_opencode_shape_state_input_category (AC-4b: opencode 形状→state.input.category 归类)
ok 35 _test_l2_dispatch_cred_source_flow_kit (R5: Path3→credential source: flow-kit)
ok 36 _test_l2_dispatch_cred_source_env (R5: Path1→credential source: env)
BATS_EXIT=0
```

**36/36 全绿 · exit 0**。新用例分布：ok 9/10/11（AC-2 翻转矩阵）、ok 21/22（AC-6 红线）、ok 33/34（AC-4b 双形状）；既有 17+12 用例零回归（ok 1-8,12-20,23-32,35-36 全部原样通过）。

## AC-6 断言前置事实（扫描目标当前状态）

```
$ grep -rsE "=sk-[A-Za-z0-9]{8,}|=[A-Za-z0-9+/]{32,}={0,2}" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null
（空输出 = 零命中 = 通过）
$ grep -rsE "FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY" <同范围> 2>/dev/null
（空输出 = 零命中 = 通过）
```

当前仓库 `.flow-active` / `.flow-active.correction` 存在、`.flow-active.interactive-ui-fix` 缺失（grep exit=2 由 `2>/dev/null` + 输出空判定吸收）、`flow-kit-bundle/flow-kit/.opencode/agent/` 含 `flow-kit-l2-reviewer.md`——两模式均零命中。

## 6 维 self-review（内置快查）

| 维度 | 结论 | 证据 |
|---|---|---|
| 正确性 | ✅ | 3 翻转用例断言与 common.sh L313-323 平台分支语义逐一对应（opencode P3 命中且 base 取 FLOW_KIT_L3_BASE_URL；P1 兜底；CC P1 压制）；2 AC-4b 用例走真实 `parse_transcript`（jq 路径 `state.input.category` 与 T02-rev 定稿一致）；AC-6 断言格式 R-F-A1（`[ -z "$output" ]`） |
| 回归（既有用例） | ✅ | 17+12 既有用例全部保留且原样通过（ok 1-8,12-20,23-32,35-36）· R5.3 禁删弱化满足 |
| 语法 | ✅ | bats 实跑 36/36 全绿（bats 自带 DSL 编译）；`.bats` 非纯 bash（`@test` DSL）——`bash -n` 对既有/新增 .bats 同样报 DSL 语法错误（已对照未改动 test_common.bats 确认属既有事实，非本任务引入） |
| 边界 | ✅ | `git diff` 仅 2 个 write_files 文件；REQUIREMENT.md / DESIGN.md 零改动；TASK.md 仅更新 T03-rev `<done>` 标记（T02-rev 同款流程）；不 commit |
| 安全 | ✅ | AC-6 两断言直接守护「凭证不进运行时落盘文件」红线；测试仅用 fake token（p1-tok/p3-tok 等既有风格）；扫描范围不含 INDEPENDENT-REVIEW-*.md（R-F-A2） |
| 契约 | ✅ | 用例名/断言与 TASK.md action 逐条对应；jq 归类路径与 AC-4 mock + AC-4b + D4 + §9.3 一致（IR-3 R-1）；平台切换 `OPENCODE=1` / unset 与 REQUIREMENT AC-2 平台翻转表一致 |

## diff 边界 verify

```
$ git status --short（本任务相关）
?? flow-kit-bundle/test/test_l2_dispatch_mode.bats   ← 本任务（untracked，T01-rev 新增）
?? flow-kit-bundle/test/test_l3_credential_resolution.bats   ← 本任务（untracked，T01-rev 新增）
```

两文件为本 change Wave 1/2 新增（未入库），本任务在其上追加用例。其余 modified/untracked 文件（prompts / hooks lib / install_hooks.sh / .specs 等）为本 change 各并行任务（T01-rev/T02-rev 及前序）的既有工作树改动，本任务未触碰。`test/` 开发源不碰（双源同步 = T04-rev · Wave 3）。

## 未做 / 交接

- **T04-rev（Wave 3）**：双源同步（`cp` 或 `make test-sync` 将本任务两个 bundle bats 同步到 `test/`）+ 全量回归 + AC-6 手动复核（INDEPENDENT-REVIEW-*.md 的 token 值红线一次性验证）+ make check + 打包源实跑。
- 不 commit（本轮任务均未 commit）。
