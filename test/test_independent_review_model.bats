#!/usr/bin/env bats
# test_independent_review_model.bats — env-var-first 模型 + API 直连测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # Save original env for restoration
  SAVED_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
  SAVED_BASE_URL="${ANTHROPIC_BASE_URL:-}"
  SAVED_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-}"
  # l2-l3-model-config: AC-1/AC-3 改读源码树（对齐 test_common.bats 向上查找），
  # 避免依赖陈旧的 $HOME/.claude/hooks/ 安装副本（L2 R3'）。
  local d="${BATS_TEST_DIRNAME:-.}"
  while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/hooks/stop/29-independent-review.sh" ]; do
    d="$(dirname "$d")"
  done
  FK_SRC_29="$d/flow-kit-bundle/hooks/stop/29-independent-review.sh"
  [ -f "$FK_SRC_29" ] || FK_SRC_29="$HOME/.claude/hooks/stop/29-independent-review.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  # Restore original env
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${SAVED_HAIKU_MODEL}"
  export ANTHROPIC_BASE_URL="${SAVED_BASE_URL}"
  export ANTHROPIC_AUTH_TOKEN="${SAVED_AUTH_TOKEN}"
}

# ── AC-1: 29号脚本用 fk_resolve_model 三级链（l2-l3-model-config ADR-012）──

@test "AC-1: 29-independent-review.sh uses fk_resolve_model (l2-l3-model-config ADR-012)" {
  run grep -c 'fk_resolve_model' "$FK_SRC_29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-2: 30号脚本同样读环境变量 ──────────────────────────────────────

@test "AC-2: 30-ai-analyze.sh references ANTHROPIC_DEFAULT_HAIKU_MODEL" {
  run grep -c 'ANTHROPIC_DEFAULT_HAIKU_MODEL' "$HOME/.claude/hooks/stop/30-ai-analyze.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-2: 30-ai-analyze.sh references ANTHROPIC_BASE_URL" {
  run grep -c 'ANTHROPIC_BASE_URL' "$HOME/.claude/hooks/stop/30-ai-analyze.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-3: 模型解析 — 29 用 fk_resolve_model, 30 保持 env-var-first ──

@test "AC-3: 29 用 fk_resolve_model 三级链, 30 保持 env-var-first :- (l2-l3-model-config)" {
  # 29 (ADR-012): fk_resolve_model "L3" 三级链替代 :?
  run grep -c 'fk_resolve_model "L3"' "$FK_SRC_29"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]

  # 30 (未改，env-var-first 保持)：ANTHROPIC_DEFAULT_HAIKU_MODEL:- pattern
  run grep -cE 'ANTHROPIC_DEFAULT_HAIKU_MODEL:[-?]' "$HOME/.claude/hooks/stop/30-ai-analyze.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-4: API 直连 ────────────────────────────────────────────────────

@test "AC-4: l3-review.sh uses ANTHROPIC_BASE_URL for direct API (pipeline-fallback-fix: 迁移到共享lib)" {
  run grep -c 'ANTHROPIC_BASE_URL' "$HOME/.claude/hooks/stop/lib/l3-review.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-4: l3-review.sh uses ANTHROPIC_AUTH_TOKEN for auth header (pipeline-fallback-fix: 迁移到共享lib)" {
  run grep -c 'ANTHROPIC_AUTH_TOKEN' "$HOME/.claude/hooks/stop/lib/l3-review.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── AC-9: token 不泄露到日志 ──────────────────────────────────────────

@test "AC-9: AUTH_TOKEN only in assignment and curl header, not in echo/module_output" {
  # 29号脚本
  run bash -c "grep -n 'ANTHROPIC_AUTH_TOKEN' \"$HOME/.claude/hooks/stop/29-independent-review.sh\" | grep -v 'auth_token=' | grep -v 'Bearer' | grep -v '^[0-9]*: *#' "
  [ "$status" -ne 0 ]  # No matches outside assignment/header/comment

  # 30号脚本
  run bash -c "grep -n 'ANTHROPIC_AUTH_TOKEN' \"$HOME/.claude/hooks/stop/30-ai-analyze.sh\" | grep -v 'auth_token=' | grep -v 'Bearer' | grep -v '^[0-9]*: *#' "
  [ "$status" -ne 0 ]
}

# ── API 路径优先级 smoke test ─────────────────────────────────────────

@test "API path: direct curl before legacy key in l3-review.sh (pipeline-fallback-fix: 迁移到共享lib)" {
  # 直连代码块应该在 legacy API key 之前出现
  script="$HOME/.claude/hooks/stop/lib/l3-review.sh"
  direct_line=$(grep -n 'env-var-first 直连' "$script" | head -1 | cut -d: -f1)
  legacy_line=$(grep -n 'Path 2.*Legacy' "$script" | head -1 | cut -d: -f1)
  [ -n "$direct_line" ]
  [ -n "$legacy_line" ]
  [ "$direct_line" -lt "$legacy_line" ]
}

@test "API path: direct curl before onecli in 30 script" {
  script="$HOME/.claude/hooks/stop/30-ai-analyze.sh"
  direct_line=$(grep -n 'Path 1.*Direct API' "$script" | head -1 | cut -d: -f1)
  onecli_line=$(grep -n 'Path 2.*onecli' "$script" | head -1 | cut -d: -f1)
  [ -n "$direct_line" ]
  [ -n "$onecli_line" ]
  [ "$direct_line" -lt "$onecli_line" ]
}

# ── onecli 保留为 fallback ────────────────────────────────────────────

@test "API fallback: 29 script sources l3-review.sh shared lib (pipeline-fallback-fix: 迁移到共享lib)" {
  run grep -c 'l3-review.sh' "$HOME/.claude/hooks/stop/29-independent-review.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "onecli fallback: 30 script still references onecli" {
  run grep -c 'onecli' "$HOME/.claude/hooks/stop/30-ai-analyze.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── stop-hook.json 未被修改（D5 决策） ─────────────────────────────────

@test "stop-hook.json still has plain model string (not env var placeholder)" {
  model_val=$(jq -r '.ai.model' "$HOME/.claude/stop-hook.json")
  # Should be a plain string like "deepseek-v4-flash", not an env var ref like "${...}"
  run bash -c "echo '$model_val' | grep -c '^\\\$'"
  [ "$status" -ne 0 ]
}
