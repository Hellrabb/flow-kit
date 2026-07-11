#!/usr/bin/env bats
# test_common.bats — common.sh 核心函数测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对 · L-025）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  local FK_ROOT="$d"
  COMMON_SH="$FK_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh"

  # 先 source common.sh（会设 CONFIG_FILE=""），之后再用实际值覆盖
  source "$COMMON_SH" 2>/dev/null || true
  CONFIG_FILE="$TEST_TMPDIR/stop-hook.json"

  # 预置最小 stop-hook.json
  if command -v jq &>/dev/null; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "modules": {
    "claudemd":  { "enabled": true },
    "memory":    { "enabled": false },
    "git":       { "enabled": true, "checks": ["untracked", "stash"] },
    "quality":   { "enabled": true, "checks": [] },
    "session":   { "enabled": true, "checks": ["duration", "tokens"] }
  },
  "output": {
    "report_file": ".claude/stop-hook-report.md"
  }
}
EOF
  fi
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

skip_if_no_jq() {
  if ! command -v jq &>/dev/null; then
    skip "jq 未安装，无法运行 common.sh 测试"
  fi
}

# ── config_get ────────────────────────────────────────────────────────

@test "config_get returns value for existing key" {
  skip_if_no_jq
  result=$(config_get '.modules.claudemd.enabled' 'false')
  [ "$result" = "true" ]
}

@test "config_get returns default for missing key" {
  skip_if_no_jq
  result=$(config_get '.modules.nonexistent.enabled' 'false')
  [ "$result" = "false" ]
}

@test "config_get returns default when config file missing" {
  CONFIG_FILE="/nonexistent/stop-hook.json"
  result=$(config_get '.modules.claudemd.enabled' 'false')
  [ "$result" = "false" ]
}

# ── module_enabled ─────────────────────────────────────────────────────

@test "module_enabled returns true for enabled module" {
  skip_if_no_jq
  run module_enabled "claudemd"
  [ "$status" -eq 0 ]
}

@test "module_enabled returns false for disabled module" {
  skip_if_no_jq
  run module_enabled "memory"
  [ "$status" -ne 0 ]
}

@test "module_enabled returns false for nonexistent module" {
  skip_if_no_jq
  run module_enabled "nonexistent"
  [ "$status" -ne 0 ]
}

# ── check_enabled ──────────────────────────────────────────────────────

@test "check_enabled with empty checks array returns true" {
  skip_if_no_jq
  run check_enabled "quality" "lint"
  [ "$status" -eq 0 ]
}

@test "check_enabled with specified check returns true" {
  skip_if_no_jq
  run check_enabled "git" "untracked"
  [ "$status" -eq 0 ]
}

@test "check_enabled returns false for disabled module" {
  skip_if_no_jq
  run check_enabled "memory" "anything"
  [ "$status" -ne 0 ]
}

# ── is_subagent ────────────────────────────────────────────────────────

@test "is_subagent returns true for SubagentStop event" {
  export HOOK_EVENT="SubagentStop"
  export PARENT_SESSION=""
  run is_subagent
  [ "$status" -eq 0 ]
}

@test "is_subagent returns true when PARENT_SESSION is set" {
  export HOOK_EVENT="Stop"
  export PARENT_SESSION="abc-123"
  run is_subagent
  [ "$status" -eq 0 ]
}

@test "is_subagent returns false for normal Stop without parent" {
  export HOOK_EVENT="Stop"
  export PARENT_SESSION=""
  run is_subagent
  [ "$status" -ne 0 ]
}

# ── line_count ─────────────────────────────────────────────────────────

@test "line_count returns correct count for file" {
  printf "line1\nline2\nline3\n" > "$TEST_TMPDIR/three_lines.txt"
  result=$(line_count "$TEST_TMPDIR/three_lines.txt")
  [ "$result" -eq 3 ]
}

@test "line_count returns 0 for missing file" {
  result=$(line_count "$TEST_TMPDIR/nonexistent.txt")
  [ "$result" = "0" ]
}

# ── config_get 边界补全 (TD-002 / health-fix-2026-q2) ──────────────────

@test "config_get returns default when CONFIG_FILE missing" {
  skip_if_no_jq
  # 删除 CONFIG_FILE，走缺失文件分支
  rm -f "$CONFIG_FILE"
  result=$(config_get ".nonexistent_key" "my-default")
  [[ "$result" == "my-default" ]]
}

@test "config_get returns default for key not in config" {
  skip_if_no_jq
  # CONFIG_FILE 由 setup 预置，查询不存在的 key
  result=$(config_get ".nonexistent.deep.path" "fallback-val")
  [[ "$result" == "fallback-val" ]]
}

# ── check_enabled 边界补全 (TD-002 / health-fix-2026-q2) ──────────────

@test "check_enabled returns false when module disabled even with matching check" {
  skip_if_no_jq
  # memory module: enabled=false, 但假设 checks 含某项
  jq '.modules.memory.checks = ["duration"]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" \
    && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  # module disabled → 即使 checks 含 "duration" 也应返回 false
  run check_enabled "memory" "duration"
  [ "$status" -ne 0 ]
}

@test "check_enabled returns true for enabled module with empty checks array" {
  skip_if_no_jq
  # quality module: enabled=true, checks=[] (setup 预置)
  # checks 数组为空 → 所有 check 都视为 enabled
  run check_enabled "quality" "any-check-name"
  [ "$status" -eq 0 ]
}

# ── init_paths CONFIG_FILE 回退 (gate-integrity / AC-6 dogfood) ──────────
# 修复：项目级 stop-hook.json 缺失时回退 user-scope，否则全局 enabled=true 未被读

@test "init_paths falls back to user-scope stop-hook.json when project-level missing" {
  skip_if_no_jq
  local proj="$TEST_TMPDIR/proj"
  local fakehome="$TEST_TMPDIR/home"
  mkdir -p "$proj" "$fakehome/.claude"
  cat > "$fakehome/.claude/stop-hook.json" << 'EOF'
{ "modules": { "independent_review": { "enabled": true } } }
EOF
  # 项目级无 stop-hook.json，user-scope 有 → CONFIG_FILE 应回退到 user-scope
  CONFIG_FILE="" CWD="$proj" HOME="$fakehome" init_paths
  [[ "$CONFIG_FILE" == "$fakehome/.claude/stop-hook.json" ]]
}

@test "init_paths prefers project-level stop-hook.json over user-scope" {
  skip_if_no_jq
  local proj="$TEST_TMPDIR/proj"
  local fakehome="$TEST_TMPDIR/home"
  mkdir -p "$proj/.claude" "$fakehome/.claude"
  echo '{ "modules": {} }' > "$proj/.claude/stop-hook.json"
  echo '{ "modules": {} }' > "$fakehome/.claude/stop-hook.json"
  # 项目级存在 → 不回退，优先用项目级
  CONFIG_FILE="" CWD="$proj" HOME="$fakehome" init_paths
  [[ "$CONFIG_FILE" == "$proj/.claude/stop-hook.json" ]]
}

# ══ fk_estimate_tokens + fk_perf_timing 测试（l3-pipeline-fix-2026-07） ══

@test "fk_estimate_tokens: normal text (char_count / 4)" {
  source "$COMMON_SH"
  local result
  result=$(fk_estimate_tokens "hello world, this is a test")
  # "hello world, this is a test" = 27 chars → 27/2 = 13（/2 中文保守估算）
  [[ "$result" -eq 13 ]]
}

@test "fk_estimate_tokens: empty text returns 0" {
  source "$COMMON_SH"
  local result
  result=$(fk_estimate_tokens "")
  [[ "$result" -eq 0 ]]
}

@test "fk_estimate_tokens: FK_CONTEXT_WINDOW override" {
  source "$COMMON_SH"
  local result
  FK_CONTEXT_WINDOW=50000 result=$(fk_estimate_tokens "test")
  # "test" = 4 chars → 4/2 = 2 tokens (/2 保守估算)
  [[ "$result" -eq 2 ]]
}

@test "fk_perf_timing: start+end pair records elapsed seconds" {
  source "$COMMON_SH"
  fk_perf_timing_start "test_label"
  # _FK_PERF_TIMINGS should have test_label_start key
  [[ -n "${_FK_PERF_TIMINGS[test_label_start]:-}" ]]
  fk_perf_timing_end "test_label"
  # _FK_PERF_TIMINGS should have test_label key after end
  [[ -n "${_FK_PERF_TIMINGS[test_label]:-}" ]]
}

@test "fk_perf_timing: end without start warns but does not exit" {
  source "$COMMON_SH"
  run fk_perf_timing_end "no_start_label"
  # Should not fail (return 0, fail-open)
  [[ "$status" -eq 0 ]]
  # Should warn to stderr
  [[ "$output" =~ WARNING ]]
}
