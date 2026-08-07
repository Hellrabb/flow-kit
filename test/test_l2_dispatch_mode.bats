#!/usr/bin/env bats
# test_l2_dispatch_mode.bats — L2 派发双模式 + 结构断言 + correction 载体边界（AC-4 / AC-3）
# l2l3-cross-platform (DESIGN D3/D4 · l2-detect.sh L103-131 box 双模式 · prompts 6 文件)

setup() {
  # 向上查找 flow-kit-bundle/hooks/（对齐 test_fk_resolve_model.bats 模式）
  BATS_ROOT="${BATS_TEST_DIRNAME:-.}"
  while [ ! -f "$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/l2-detect.sh" ] && [ "$BATS_ROOT" != "/" ]; do
    BATS_ROOT="$(dirname "$BATS_ROOT")"
  done
  HOOK_BASE_DIR="$BATS_ROOT/flow-kit-bundle/hooks/stop"
  L2_DETECT_SH="$HOOK_BASE_DIR/lib/l2-detect.sh"
  CORRECTION_SH="$HOOK_BASE_DIR/lib/correction-file.sh"
  PROMPTS_DIR="$BATS_ROOT/flow-kit-bundle/flow-kit/prompts"
  [ -f "$L2_DETECT_SH" ] || { skip "l2-detect.sh not found"; }
  export HOOK_BASE_DIR
  # 每用例独立 PROJECT_ROOT（临时目录）
  export PROJECT_ROOT="$(mktemp -d)"

  # 环境隔离：本 shell 常驻 OPENCODE=1——CC 断言必须显式 unset（任务环境说明）
  SAVED_OPENCODE="${OPENCODE:-}"
  SAVED_OPENCODE_BIN="${OPENCODE_BIN:-}"
  unset OPENCODE OPENCODE_BIN FLOW_KIT_L2_MOCK
  unset FLOW_KIT_L2_MODEL ANTHROPIC_L2_MODEL
  unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL
}

teardown() {
  [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ] && rm -rf "$PROJECT_ROOT"
  export OPENCODE="${SAVED_OPENCODE}" OPENCODE_BIN="${SAVED_OPENCODE_BIN}"
}

# helper: source l2-detect.sh（内含 common.sh type-guard）+ 中和 set -euo pipefail
_load_l2() {
  source "$L2_DETECT_SH" 2>/dev/null || true
  set +e
}

# ── l2_dispatch_prompt 双模式（l2-detect.sh L103-128 box：CC→subagent_type / opencode→category）──

@test "_test_l2_dispatch_prompt_opencode_mode_category" {
  _load_l2
  export OPENCODE=1
  run l2_dispatch_prompt "2" "test-change" "$PROJECT_ROOT/.specs/test-change"
  [ "$status" -eq 0 ]
  [[ "$output" == *"category="* ]]
  [[ "$output" == *"category: unspecified-high"* ]]
}

@test "_test_l2_dispatch_prompt_claude_mode_subagent_type" {
  _load_l2
  # OPENCODE/OPENCODE_BIN 已在 setup unset → claude code 模式
  run l2_dispatch_prompt "2" "test-change" "$PROJECT_ROOT/.specs/test-change"
  [ "$status" -eq 0 ]
  [[ "$output" == *"subagent_type"* ]]
  [[ "$output" == *"subagent_type: architect-reviewer"* ]]
}

@test "_test_l2_dispatch_prompt_dual_mode_box_complete (两分支共存)" {
  _load_l2
  run l2_dispatch_prompt "1" "test-change" "$PROJECT_ROOT/.specs/test-change"
  [ "$status" -eq 0 ]
  [[ "$output" == *"subagent_type: qa-expert"* ]]
  [[ "$output" == *"category: unspecified-high"* ]]
}

@test "_test_l2_dispatch_prompt_phase_agent_type_map (1/5→qa-expert 2/3/7→architect-reviewer 6→code-reviewer)" {
  _load_l2
  local phase
  for phase in 1 5; do
    run l2_dispatch_prompt "$phase" "test-change" "$PROJECT_ROOT/.specs/test-change"
    [ "$status" -eq 0 ]
    [[ "$output" == *"subagent_type: qa-expert"* ]]
  done
  for phase in 2 3 7; do
    run l2_dispatch_prompt "$phase" "test-change" "$PROJECT_ROOT/.specs/test-change"
    [ "$status" -eq 0 ]
    [[ "$output" == *"subagent_type: architect-reviewer"* ]]
  done
  run l2_dispatch_prompt "6" "test-change" "$PROJECT_ROOT/.specs/test-change"
  [ "$status" -eq 0 ]
  [[ "$output" == *"subagent_type: code-reviewer"* ]]
}

# ── AC-4 结构断言：含 subagent_type 的 prompt 文件必须含 category=（对齐 T07 verify）──

@test "_test_l2_dispatch_structure_6_prompts_subagent_type_have_category (AC-4)" {
  local viol=0 f
  for f in 1-requirement 2-design 3-task 5-test 6-review 7-integration; do
    if grep -q "subagent_type" "$PROMPTS_DIR/$f.md"; then
      grep -q "category=" "$PROMPTS_DIR/$f.md" || viol=$((viol + 1))
    fi
  done
  [ "$viol" -eq 0 ]
}

# ── correction 载体边界（AC-3：model-missing correction message 不含凭证 env 完整名）──

@test "_test_l2_dispatch_correction_message_no_credential_env (AC-3 边界 · unit)" {
  source "$CORRECTION_SH" 2>/dev/null || true
  set +e
  write_model_missing_correction "L2"
  local msg; msg=$(jq -r '.message // ""' "$PROJECT_ROOT/.flow-active.correction")
  [[ "$msg" == *"FLOW_KIT_L2_MODEL"* ]]
  [[ "$msg" != *"ANTHROPIC_AUTH_TOKEN"* ]]
  [[ "$msg" != *"ANTHROPIC_BASE_URL"* ]]
  [[ "$msg" != *"ANTHROPIC_API_KEY"* ]]
  [[ "$msg" != *"FLOW_KIT_L3_AUTH_TOKEN"* ]]
  [[ "$msg" != *"FLOW_KIT_L3_BASE_URL"* ]]

  write_model_missing_correction "L3"
  local msg3; msg3=$(jq -r '.message // ""' "$PROJECT_ROOT/.flow-active.correction")
  [[ "$msg3" == *"FLOW_KIT_L3_MODEL"* ]]
  [[ "$msg3" != *"ANTHROPIC_AUTH_TOKEN"* ]]
  [[ "$msg3" != *"FLOW_KIT_L3_AUTH_TOKEN"* ]]
}

@test "_test_l2_dispatch_model_missing_correction_no_cred_env (AC-3 边界 · l2_dispatch_agent e2e)" {
  _load_l2
  local specs_dir="$PROJECT_ROOT/.specs/test-change"
  mkdir -p "$specs_dir"
  # 凭证就绪（Path1）→ 走到模型缺失分支（三级链全空）→ 写 l2-model-missing correction
  export FLOW_KIT_L2_MOCK=0 ANTHROPIC_AUTH_TOKEN="p1-tok"
  run l2_dispatch_agent "2" "test-change" "$specs_dir"
  [ "$status" -eq 3 ]
  [ "$(jq -r '.type // ""' "$PROJECT_ROOT/.flow-active.correction")" = "l2-model-missing" ]
  local msg; msg=$(jq -r '.message // ""' "$PROJECT_ROOT/.flow-active.correction")
  [[ "$msg" == *"FLOW_KIT_L2_MODEL"* ]]
  [[ "$msg" != *"ANTHROPIC_AUTH_TOKEN"* ]]
  [[ "$msg" != *"ANTHROPIC_BASE_URL"* ]]
  [[ "$msg" != *"ANTHROPIC_API_KEY"* ]]
  [[ "$msg" != *"FLOW_KIT_L3_AUTH_TOKEN"* ]]
  [[ "$msg" != *"FLOW_KIT_L3_BASE_URL"* ]]
}

# ── R4 修复：transcript-parser 双模式归类三态（T05 变更的回归保护）──

_load_parser() {
  source "$BATS_ROOT/flow-kit-bundle/hooks/stop/lib/transcript-parser.sh" 2>/dev/null || true
  set +e
}

@test "_test_l2_dispatch_transcript_category_first (R4: .args.category 优先)" {
  _load_parser
  export HOOK_TMP_DIR="$(mktemp -d)"
  local tpath="$PROJECT_ROOT/transcript.jsonl"
  printf '%s\n' \
    '{"type":"tool_use","tool":"Agent","args":{"category":"unspecified-high","subagent_type":"qa-expert"}}' \
    > "$tpath"
  export TRANSCRIPT_PATH="$tpath"
  parse_transcript
  run cat "$HOOK_TMP_DIR/subagent-usage.txt"
  [[ "$output" == *"unspecified-high"* ]]
  [[ "$output" != *"qa-expert"* ]]
  rm -rf "$HOOK_TMP_DIR"
}

@test "_test_l2_dispatch_transcript_subagent_fallback (R4: category 缺失→subagent_type)" {
  _load_parser
  export HOOK_TMP_DIR="$(mktemp -d)"
  local tpath="$PROJECT_ROOT/transcript.jsonl"
  printf '%s\n' \
    '{"type":"tool_use","tool":"Agent","args":{"subagent_type":"architect-reviewer"}}' \
    > "$tpath"
  export TRANSCRIPT_PATH="$tpath"
  parse_transcript
  run cat "$HOOK_TMP_DIR/subagent-usage.txt"
  [[ "$output" == *"architect-reviewer"* ]]
  rm -rf "$HOOK_TMP_DIR"
}

@test "_test_l2_dispatch_transcript_general_fallback (R4: 双空→general-purpose)" {
  _load_parser
  export HOOK_TMP_DIR="$(mktemp -d)"
  local tpath="$PROJECT_ROOT/transcript.jsonl"
  printf '%s\n' \
    '{"type":"tool_use","tool":"Agent","args":{}}' \
    > "$tpath"
  export TRANSCRIPT_PATH="$tpath"
  parse_transcript
  run cat "$HOOK_TMP_DIR/subagent-usage.txt"
  [[ "$output" == *"general-purpose"* ]]
  rm -rf "$HOOK_TMP_DIR"
}

# ── AC-4b 工具名双形状（T02-rev：jq 过滤同时匹配 CC tool_use+Agent 与 opencode tool+task）──
# opencode 形状按 .state.input.category 归类（与 AC-4 mock + AC-4b + D4 + §9.3 一致 · IR-3 R-1 修复）

@test "_test_l2_dispatch_ac4b_cc_shape_subagent_type (AC-4b: CC 形状→subagent_type 归类)" {
  _load_parser
  export HOOK_TMP_DIR="$(mktemp -d)"
  local tpath="$PROJECT_ROOT/transcript.jsonl"
  printf '%s\n' \
    '{"type":"tool_use","tool":"Agent","args":{"subagent_type":"code-reviewer"}}' \
    > "$tpath"
  export TRANSCRIPT_PATH="$tpath"
  parse_transcript
  run cat "$HOOK_TMP_DIR/subagent-usage.txt"
  [[ "$output" == *"code-reviewer"* ]]
  rm -rf "$HOOK_TMP_DIR"
}

@test "_test_l2_dispatch_ac4b_opencode_shape_state_input_category (AC-4b: opencode 形状→state.input.category 归类)" {
  _load_parser
  export HOOK_TMP_DIR="$(mktemp -d)"
  local tpath="$PROJECT_ROOT/transcript.jsonl"
  printf '%s\n' \
    '{"type":"tool","tool":"task","state":{"input":{"category":"unspecified-high"}}}' \
    > "$tpath"
  export TRANSCRIPT_PATH="$tpath"
  parse_transcript
  run cat "$HOOK_TMP_DIR/subagent-usage.txt"
  [[ "$output" == *"unspecified-high"* ]]
  rm -rf "$HOOK_TMP_DIR"
}

# ── R5 修复：credential source 日志断言（AC-6 可观测性回归保护）──

# helper: PATH 前置 fake curl（复用 test_l3_credential_resolution.bats 模式——阻止真实网络 + 捕获请求）
_setup_fake_curl2() {
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

@test "_test_l2_dispatch_cred_source_flow_kit (R5: Path3→credential source: flow-kit)" {
  _load_l2
  _setup_fake_curl2
  run bash -c 'set +e; export FLOW_KIT_L3_AUTH_TOKEN="f3-tok" FLOW_KIT_L3_BASE_URL="https://fk.example"; unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; source flow-kit-bundle/hooks/stop/lib/common.sh 2>/dev/null; fk_resolve_api_credentials >/dev/null 2>&1; rc=$?; [ $rc -eq 0 ] && echo "rc=0 base=$FK_API_BASE_URL scheme=${FK_API_AUTH_SCHEME:-none}" || echo "rc=$rc"'
  [[ "$output" == *"rc=0 base=https://fk.example scheme=bearer"* ]]
  run bash -c 'set +e; source flow-kit-bundle/hooks/stop/lib/l3-api.sh 2>/dev/null; export FLOW_KIT_L3_AUTH_TOKEN="f3-tok" FLOW_KIT_L3_BASE_URL="https://fk.example"; unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; fk_resolve_api_credentials >/dev/null 2>&1 || true; _l3_call_api "prompt" "model-x" 2>&1 | grep -o "credential source: [a-z-]*" | head -1'
  [[ "$output" == *"credential source: flow-kit"* ]]
  unset FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL
}

@test "_test_l2_dispatch_cred_source_env (R5: Path1→credential source: env)" {
  _load_l2
  _setup_fake_curl2
  run bash -c 'set +e; source flow-kit-bundle/hooks/stop/lib/l3-api.sh 2>/dev/null; export ANTHROPIC_AUTH_TOKEN="p1-tok" ANTHROPIC_BASE_URL="https://cc.example"; unset FLOW_KIT_L3_AUTH_TOKEN FLOW_KIT_L3_BASE_URL ANTHROPIC_API_KEY; fk_resolve_api_credentials >/dev/null 2>&1 || true; _l3_call_api "prompt" "model-x" 2>&1 | grep -o "credential source: [a-z-]*" | head -1'
  [[ "$output" == *"credential source: env"* ]]
  unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL
}
