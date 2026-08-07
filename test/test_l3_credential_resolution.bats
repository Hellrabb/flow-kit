#!/usr/bin/env bats
# test_l3_credential_resolution.bats — L3 凭证解析优先级矩阵 + 平台提示 + scheme/header 断言
# 覆盖 AC-1（l2_dispatch_agent 同源） / AC-2（Path2 x-api-key 真实覆盖） / AC-3（平台提示） / R4（fake curl header）
# l2l3-cross-platform (DESIGN D1/D2/D3 · common.sh L277-323 · l3-api.sh · l2-detect.sh)

setup() {
  # 向上查找 flow-kit-bundle/hooks/（对齐 test_fk_resolve_model.bats 模式）
  BATS_ROOT="${BATS_TEST_DIRNAME:-.}"
  while [ ! -f "$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh" ] && [ "$BATS_ROOT" != "/" ]; do
    BATS_ROOT="$(dirname "$BATS_ROOT")"
  done
  HOOK_BASE_DIR="$BATS_ROOT/flow-kit-bundle/hooks/stop"
  COMMON_SH="$HOOK_BASE_DIR/lib/common.sh"
  L3_API_SH="$HOOK_BASE_DIR/lib/l3-api.sh"
  L2_DETECT_SH="$HOOK_BASE_DIR/lib/l2-detect.sh"
  [ -f "$COMMON_SH" ] || { skip "common.sh not found"; }
  export HOOK_BASE_DIR
  # 每用例独立 PROJECT_ROOT（临时目录）
  export PROJECT_ROOT="$(mktemp -d)"

  # 环境隔离：保存 + 清空全部凭证 env（仿 test_independent_review_model.bats SAVED 风格）
  SAVED_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
  SAVED_BASE_URL="${ANTHROPIC_BASE_URL:-}"
  SAVED_API_KEY="${ANTHROPIC_API_KEY:-}"
  SAVED_L3_TOKEN="${FLOW_KIT_L3_AUTH_TOKEN:-}"
  SAVED_L3_BASE="${FLOW_KIT_L3_BASE_URL:-}"
  SAVED_OPENCODE="${OPENCODE:-}"
  SAVED_OPENCODE_BIN="${OPENCODE_BIN:-}"
  unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_API_KEY
  unset FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL OPENCODE OPENCODE_BIN
}

teardown() {
  [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
  export ANTHROPIC_AUTH_TOKEN="${SAVED_AUTH_TOKEN}" ANTHROPIC_BASE_URL="${SAVED_BASE_URL}"
  export ANTHROPIC_API_KEY="${SAVED_API_KEY}" FLOW_KIT_L3_AUTH_TOKEN="${SAVED_L3_TOKEN}"
  export FLOW_KIT_L3_BASE_URL="${SAVED_L3_BASE}" OPENCODE="${SAVED_OPENCODE}" OPENCODE_BIN="${SAVED_OPENCODE_BIN}"
}

# helper: source common.sh + 中和 set -euo pipefail（CRITICAL set -e trap：source 后任何
# 裸非零命令会中止 shell——一律 || 条件上下文 或 set +e，且不用 local x=$(非零命令)）
_load_common() {
  source "$COMMON_SH" 2>/dev/null || true
  set +e
}

# helper: source common.sh + l3-api.sh（l3-api.sh 内 guard 幂等，不重复 source）
_load_l3_api() {
  source "$COMMON_SH" 2>/dev/null || true
  source "$L3_API_SH" 2>/dev/null || true
  set +e
}

# helper: source common.sh + l2-detect.sh（l2-detect.sh 自身 type-guard source common.sh）
_load_l2_detect() {
  source "$L2_DETECT_SH" 2>/dev/null || true
  set +e
}

# helper: PATH 前置 fake curl（R4 盲审——捕获 -H 参数到 FAKE_CURL_LOG + 返回 canned 200 响应）
_setup_fake_curl() {
  local fake_bin="$PROJECT_ROOT/fakebin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/curl" <<'CURL_EOF'
#!/bin/bash
echo "CURL_ARGS:$*" >> "$FAKE_CURL_LOG"
printf '%s\n200' '{"content":[{"type":"text","text":"fake-ok"}]}'
CURL_EOF
  chmod +x "$fake_bin/curl"
  export FAKE_CURL_LOG="$PROJECT_ROOT/fake-curl.log"
  : > "$FAKE_CURL_LOG"
  export PATH="$fake_bin:$PATH"
}

# ── fk_resolve_api_credentials 优先级矩阵（common.sh L277-314）──

@test "_test_l3_credential_path1_wins_all_three (Path1>Path3·Path3 短路 Path2·三源并存取 Path1)" {
  _load_common
  export ANTHROPIC_AUTH_TOKEN="p1-tok"
  export ANTHROPIC_BASE_URL="https://custom.anthropic.com"
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok"
  export FLOW_KIT_L3_BASE_URL="https://fk-l3.example"
  export ANTHROPIC_API_KEY="p2-key"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p1-tok" ]
  # Path1 的 base 尊重 ANTHROPIC_BASE_URL；Path3 的 base 未泄漏进来
  [ "$FK_API_BASE_URL" = "https://custom.anthropic.com" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

@test "_test_l3_credential_path1_over_path2 (ANTHROPIC_AUTH_TOKEN 压制 ANTHROPIC_API_KEY)" {
  _load_common
  export ANTHROPIC_AUTH_TOKEN="p1-tok"
  export ANTHROPIC_API_KEY="p2-key"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p1-tok" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
  [ "$FK_API_BASE_URL" = "https://api.anthropic.com" ]
}

@test "_test_l3_credential_path3_over_path2 (FLOW_KIT_L3_* 短路 legacy key)" {
  _load_common
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok"
  export FLOW_KIT_L3_BASE_URL="https://fk-l3.example"
  export ANTHROPIC_API_KEY="p2-key"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p3-tok" ]
  [ "$FK_API_BASE_URL" = "https://fk-l3.example" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

@test "_test_l3_credential_path1_only" {
  _load_common
  export ANTHROPIC_AUTH_TOKEN="p1-tok"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p1-tok" ]
  [ "$FK_API_BASE_URL" = "https://api.anthropic.com" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

@test "_test_l3_credential_path3_only" {
  _load_common
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok"
  export FLOW_KIT_L3_BASE_URL="https://fk-l3.example"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p3-tok" ]
  [ "$FK_API_BASE_URL" = "https://fk-l3.example" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

@test "_test_l3_credential_path2_only (legacy x-api-key + 硬编码端点)" {
  _load_common
  export ANTHROPIC_API_KEY="p2-key"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p2-key" ]
  [ "$FK_API_BASE_URL" = "https://api.anthropic.com" ]
  [ "$FK_API_AUTH_SCHEME" = "x-api-key" ]
}

@test "_test_l3_credential_all_empty_rc1" {
  _load_common
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 1 ]
  [ -z "$FK_API_AUTH_TOKEN" ]
  [ -z "$FK_API_BASE_URL" ]
  [ -z "$FK_API_AUTH_SCHEME" ]
}

@test "_test_l3_credential_path3_incomplete_rc2_no_path2 (token 有 base 空→禁止静默落 Path2)" {
  _load_common
  # Path2 同时就绪：若错误落 Path2，FK_API_BASE_URL 会被硬编码端点覆盖——断言未被覆盖
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok"
  export ANTHROPIC_API_KEY="p2-key"
  local _rc=0 errf="$PROJECT_ROOT/cred-stderr.txt"
  fk_resolve_api_credentials 2>"$errf" || _rc=$?
  [ "$_rc" -eq 2 ]
  [[ "$(cat "$errf")" == *"FLOW_KIT_L3_AUTH_TOKEN 已设但 FLOW_KIT_L3_BASE_URL 为空"* ]]
  [ -z "$FK_API_AUTH_TOKEN" ]
  [ -z "$FK_API_BASE_URL" ]   # 未落 Path2（Path2 硬编码端点未覆盖）
  [ -z "$FK_API_AUTH_SCHEME" ]
}

# ── AC-2 平台翻转矩阵（T01-rev：Path1/Path3 相对顺序随平台翻转 · common.sh L313-323）──
# 平台切换：opencode = export OPENCODE=1；claude code = unset（等价 env -u OPENCODE -u OPENCODE_BIN）

@test "_test_l3_credential_flip_opencode_path3_over_path1 (AC-2: opencode Path3>Path1 并存取 Path3)" {
  _load_common
  export OPENCODE=1
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok"
  export FLOW_KIT_L3_BASE_URL="https://fk-l3.example"
  export ANTHROPIC_AUTH_TOKEN="p1-tok"
  export ANTHROPIC_BASE_URL="https://custom.anthropic.com"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p3-tok" ]
  # FK_API_BASE_URL 取 FLOW_KIT_L3_BASE_URL——Path1 的 base 未泄漏进来
  [ "$FK_API_BASE_URL" = "https://fk-l3.example" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

@test "_test_l3_credential_flip_opencode_path1_fallback (AC-2: opencode Path3 缺失→Path1 兜底)" {
  _load_common
  export OPENCODE=1
  export ANTHROPIC_AUTH_TOKEN="p1-tok"
  export ANTHROPIC_BASE_URL="https://custom.anthropic.com"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p1-tok" ]
  [ "$FK_API_BASE_URL" = "https://custom.anthropic.com" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

@test "_test_l3_credential_flip_claude_path1_over_path3 (AC-2: CC Path1>Path3 并存取 Path1·零回归)" {
  _load_common
  # 翻转到 claude code 平台（setup 已 unset OPENCODE/OPENCODE_BIN，此处显式防御）
  export -n OPENCODE OPENCODE_BIN
  export ANTHROPIC_AUTH_TOKEN="p1-tok"
  export ANTHROPIC_BASE_URL="https://custom.anthropic.com"
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok"
  export FLOW_KIT_L3_BASE_URL="https://fk-l3.example"
  local _rc=0
  fk_resolve_api_credentials || _rc=$?
  [ "$_rc" -eq 0 ]
  [ "$FK_API_AUTH_TOKEN" = "p1-tok" ]
  [ "$FK_API_BASE_URL" = "https://custom.anthropic.com" ]
  [ "$FK_API_AUTH_SCHEME" = "bearer" ]
}

# ── fk_platform_is_opencode 三态（common.sh L321-323）──

@test "_test_l3_credential_platform_is_opencode_3_states" {
  _load_common
  export OPENCODE=1
  run fk_platform_is_opencode
  [ "$status" -eq 0 ]
  unset OPENCODE
  export OPENCODE_BIN="/usr/bin/opencode"
  run fk_platform_is_opencode
  [ "$status" -eq 0 ]
  unset OPENCODE_BIN
  run fk_platform_is_opencode
  [ "$status" -eq 1 ]
}

# ── l2_dispatch_agent 同源断言（AC-1：函数替换断言走共享解析）──

@test "_test_l3_credential_l2_dispatch_same_source (AC-1: l2_dispatch_agent 调用 fk_resolve_api_credentials)" {
  _load_l2_detect
  local specs_dir="$PROJECT_ROOT/.specs/test-change"
  mkdir -p "$specs_dir"
  export FLOW_KIT_L2_MOCK=0
  export ANTHROPIC_L2_MODEL="l2-mock-model"
  # fake curl：函数定义被子 shell 继承 → 后台派发子进程不发真实网络
  curl() { printf '%s\n200' '{"content":[{"type":"text","text":"mocked"}]}'; }
  # 函数替换：记录调用标记——断言 l2_dispatch_agent 走共享解析而非直读 ANTHROPIC_* env
  fk_resolve_api_credentials() {
    echo "CRED_RESOLVE_CALLED" >&2
    FK_API_AUTH_TOKEN="tok"
    FK_API_BASE_URL="https://api.anthropic.com"
    FK_API_AUTH_SCHEME="bearer"
    return 0
  }
  run l2_dispatch_agent "2" "test-change" "$specs_dir"
  # 仅断言共享函数被调用（后台派发进程存活时序不定，不断言 dispatch rc）
  [[ "$output" == *"CRED_RESOLVE_CALLED"* ]]
}

# ── AC-3 平台感知降级提示（l3-api.sh L41-51 + l2-detect.sh L194-206）──

@test "_test_l3_credential_ac3_hint_opencode_export_guidance (_l3_call_api)" {
  _load_l3_api
  export OPENCODE=1
  run _l3_call_api "prompt" "model-x"
  [ "$status" -eq 3 ]
  [[ "$output" == *"FLOW_KIT_L3_BASE_URL"* ]]
  [[ "$output" == *"FLOW_KIT_L3_AUTH_TOKEN"* ]]
  [[ "$output" == *"export"* ]]
}

@test "_test_l3_credential_ac3_hint_claude_code_env_var_first (_l3_call_api)" {
  _load_l3_api
  # OPENCODE / OPENCODE_BIN 已在 setup unset → claude code 平台
  run _l3_call_api "prompt" "model-x"
  [ "$status" -eq 3 ]
  [[ "$output" == *"ANTHROPIC_AUTH_TOKEN"* ]]
  [[ "$output" == *"env-var-first"* ]]
}

@test "_test_l3_credential_l2_dispatch_hint_opencode" {
  _load_l2_detect
  local specs_dir="$PROJECT_ROOT/.specs/test-change"
  mkdir -p "$specs_dir"
  export FLOW_KIT_L2_MOCK=0 OPENCODE=1
  run l2_dispatch_agent "2" "test-change" "$specs_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FLOW_KIT_L3_BASE_URL"* ]]
  [[ "$output" == *"FLOW_KIT_L3_AUTH_TOKEN"* ]]
  [[ "$output" == *"category="* ]]
}

@test "_test_l3_credential_l2_dispatch_hint_claude_code" {
  _load_l2_detect
  local specs_dir="$PROJECT_ROOT/.specs/test-change"
  mkdir -p "$specs_dir"
  export FLOW_KIT_L2_MOCK=0
  run l2_dispatch_agent "2" "test-change" "$specs_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ANTHROPIC_AUTH_TOKEN"* ]]
  [[ "$output" == *"env-var-first"* ]]
}

# ── scheme/header 断言（R4 盲审：PATH 前置 fake curl 捕获 -H 参数 · AC-2 Path2 真实覆盖）──

@test "_test_l3_credential_scheme_path2_x_api_key_header (R4 fake curl)" {
  _load_l3_api
  _setup_fake_curl
  export ANTHROPIC_API_KEY="p2-key-123"
  run _l3_call_api "prompt" "model-x"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-ok"* ]]
  run grep -q "x-api-key: p2-key-123" "$FAKE_CURL_LOG"
  [ "$status" -eq 0 ]
  run grep -q "Authorization: Bearer" "$FAKE_CURL_LOG"
  [ "$status" -ne 0 ]
}

@test "_test_l3_credential_scheme_path1_bearer_header (R4 fake curl)" {
  _load_l3_api
  _setup_fake_curl
  export ANTHROPIC_AUTH_TOKEN="p1-tok-abc"
  run _l3_call_api "prompt" "model-x"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-ok"* ]]
  run grep -q "Authorization: Bearer p1-tok-abc" "$FAKE_CURL_LOG"
  [ "$status" -eq 0 ]
  run grep -q "x-api-key:" "$FAKE_CURL_LOG"
  [ "$status" -ne 0 ]
}

@test "_test_l3_credential_scheme_path3_bearer_header (R4 fake curl)" {
  _load_l3_api
  _setup_fake_curl
  export FLOW_KIT_L3_AUTH_TOKEN="p3-tok-xyz"
  export FLOW_KIT_L3_BASE_URL="https://fk-l3.example"
  run _l3_call_api "prompt" "model-x"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-ok"* ]]
  run grep -q "Authorization: Bearer p3-tok-xyz" "$FAKE_CURL_LOG"
  [ "$status" -eq 0 ]
  run grep -q "x-api-key:" "$FAKE_CURL_LOG"
  [ "$status" -ne 0 ]
}

# ── AC-6 红线：运行时落盘文件不含凭证（REQUIREMENT AC-6 · R-F-A1 格式）──
# 断言格式用 `[ -z "$output" ]`（零命中语义）而非 $status——grep 缺文件 exit=2 陷阱：
# 缺失的运行时文件（如 .flow-active.interactive-ui-fix）经 2>/dev/null 静默，输出空即通过。
# 扫描范围 = 运行时状态文件 + agent 定义（R-F-A2：不含 INDEPENDENT-REVIEW-*.md——
# 审查报告由第三方 L2/L3 写入，不可约束其不写长字符串，钉进断言会假红）。

@test "AC-6 redline: no token values in runtime files" {
  run grep -rsE "=sk-[A-Za-z0-9]{8,}|=[A-Za-z0-9+/]{32,}={0,2}" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null
  [ -z "$output" ]
}

@test "AC-6 redline: no env names in runtime files" {
  run grep -rsE "FLOW_KIT_L3_AUTH_TOKEN|FLOW_KIT_L3_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY" .flow-active .flow-active.correction .flow-active.interactive-ui-fix flow-kit-bundle/flow-kit/.opencode/agent/ 2>/dev/null
  [ -z "$output" ]
}
