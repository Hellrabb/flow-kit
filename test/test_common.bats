#!/usr/bin/env bats
# test_common.bats — common.sh 核心函数测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  COMMON_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit-bundle/hooks/stop/lib/common.sh"

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

# ── file_not_empty ─────────────────────────────────────────────────────

@test "file_not_empty returns true for non-empty file" {
  echo "content" > "$TEST_TMPDIR/exists.txt"
  run file_not_empty "$TEST_TMPDIR/exists.txt"
  [ "$status" -eq 0 ]
}

@test "file_not_empty returns false for missing file" {
  run file_not_empty "$TEST_TMPDIR/nonexistent.txt"
  [ "$status" -ne 0 ]
}

@test "file_not_empty returns false for empty file" {
  touch "$TEST_TMPDIR/empty.txt"
  run file_not_empty "$TEST_TMPDIR/empty.txt"
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
