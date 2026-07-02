#!/usr/bin/env bats
# test_independent_review_model.bats — env-var-first 模型 + API 直连测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  BUNDLE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  F29="$BUNDLE_ROOT/hooks/stop/29-independent-review.sh"
  F30="$BUNDLE_ROOT/hooks/stop/30-ai-analyze.sh"
  # Save original env for restoration
  SAVED_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
  SAVED_BASE_URL="${ANTHROPIC_BASE_URL:-}"
  SAVED_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  # Restore original env
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${SAVED_HAIKU_MODEL}"
  export ANTHROPIC_BASE_URL="${SAVED_BASE_URL}"
  export ANTHROPIC_AUTH_TOKEN="${SAVED_AUTH_TOKEN}"
}

# ── AC-1: 29号脚本读环境变量模型 ──────────────────────────────────────

@test "AC-1: 29-independent-review.sh references ANTHROPIC_DEFAULT_HAIKU_MODEL" {
  run grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' "$F29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-2: 30号脚本同样读环境变量 ──────────────────────────────────────

@test "AC-2: 30-ai-analyze.sh references ANTHROPIC_DEFAULT_HAIKU_MODEL" {
  run grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' "$F30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-2: 30-ai-analyze.sh references ANTHROPIC_BASE_URL" {
  run grep -c 'ANTHROPIC_BASE_URL' "$F30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-3: env var 缺失时 fallback ──────────────────────────────────────

@test "AC-3: model uses env-var-first pattern with fallback" {
  # Both scripts should use ${ANTHROPIC_DEFAULT_HAIKU_MODEL:-...} pattern
  run grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL:-' "$F29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  run grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL:-' "$F30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-4: API 直连 ────────────────────────────────────────────────────

@test "AC-4: 29-independent-review.sh uses ANTHROPIC_BASE_URL for direct API" {
  run grep -c 'ANTHROPIC_BASE_URL' "$F29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-4: 29-independent-review.sh uses ANTHROPIC_AUTH_TOKEN for auth header" {
  run grep -c 'ANTHROPIC_AUTH_TOKEN' "$F29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-9: token 不泄露到日志 ──────────────────────────────────────────

@test "AC-9: AUTH_TOKEN only in assignment and curl header, not in echo/module_output" {
  # 29号脚本
  run bash -c "grep -n 'ANTHROPIC_AUTH_TOKEN' \"$F29\" | grep -v 'auth_token=' | grep -v 'Bearer' | grep -v '^[0-9]*: *#' "
  [ "$status" -ne 0 ]  # No matches outside assignment/header/comment

  # 30号脚本
  run bash -c "grep -n 'ANTHROPIC_AUTH_TOKEN' \"$F30\" | grep -v 'auth_token=' | grep -v 'Bearer' | grep -v '^[0-9]*: *#' "
  [ "$status" -ne 0 ]
}

# ── API 路径优先级 smoke test ─────────────────────────────────────────

@test "API path: direct curl before legacy key fallback in 29 script" {
  # 29 script has no onecli — Direct API (Path 1) appears before Legacy Key (Path 2)
  script="$F29"
  direct_line=$(grep -n 'Path 1.*Direct API' "$script" | head -1 | cut -d: -f1)
  legacy_line=$(grep -n 'Path 2.*Legacy ANTHROPIC_API_KEY' "$script" | head -1 | cut -d: -f1)
  [ -n "$direct_line" ]
  [ -n "$legacy_line" ]
  [ "$direct_line" -lt "$legacy_line" ]
}

@test "API path: direct curl before onecli in 30 script" {
  script="$F30"
  direct_line=$(grep -n 'Path 1.*Direct API' "$script" | head -1 | cut -d: -f1)
  onecli_line=$(grep -n 'Path 2.*onecli' "$script" | head -1 | cut -d: -f1)
  [ -n "$direct_line" ]
  [ -n "$onecli_line" ]
  [ "$direct_line" -lt "$onecli_line" ]
}

# ── onecli 保留为 fallback ────────────────────────────────────────────

@test "onecli: 29 script intentionally omits onecli (L3 gate does not depend on optional proxy)" {
  run grep -c 'onecli' "$F29"
  # grep returns 1 when no match — both 0 and 1 are valid
  [ "$output" -eq 0 ]
}

@test "onecli fallback: 30 script still references onecli" {
  run grep -c 'onecli' "$F30"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── stop-hook.json 未被修改（D5 决策） ─────────────────────────────────

@test "stop-hook.json still has plain model string (not env var placeholder)" {
  model_val=$(jq -r '.ai.model' "$BUNDLE_ROOT/hooks/config/stop-hook.json")
  # Should be a plain string like "deepseek-v4-flash", not an env var ref like "${...}"
  run bash -c "echo '$model_val' | grep -c '^\\\$'"
  [ "$status" -ne 0 ]
}
