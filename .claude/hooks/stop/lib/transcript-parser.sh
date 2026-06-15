#!/bin/bash
# transcript-parser.sh — parse Claude Code transcript JSONL into structured data
# Source after common.sh. Requires TRANSCRIPT_PATH and HOOK_TMP_DIR to be set.

set -euo pipefail

# ── Parse transcript and write structured extracts to HOOK_TMP_DIR ──

parse_transcript() {
  local tpath="$TRANSCRIPT_PATH"
  if [[ -z "$tpath" || ! -f "$tpath" ]]; then
    echo "WARN: transcript not found at $tpath" >&2
    touch "$HOOK_TMP_DIR/transcript-missing"
    return 1
  fi

  # Extract tool calls: tool_name|args_summary
  jq -r '
    select(.type == "tool_use") |
    "\(.tool // "unknown")|\(.args // {} | tostring)"
  ' "$tpath" 2>/dev/null > "$HOOK_TMP_DIR/tool-calls.txt" || true

  # Extract CLI commands from Bash tool calls
  jq -r '
    select(.type == "tool_use" and .tool == "Bash") |
    .args.command // empty
  ' "$tpath" 2>/dev/null > "$HOOK_TMP_DIR/bash-commands.txt" || true

  # Extract Write tool file paths
  jq -r '
    select(.type == "tool_use" and .tool == "Write") |
    .args.file_path // empty
  ' "$tpath" 2>/dev/null > "$HOOK_TMP_DIR/written-files.txt" || true

  # Extract Edit tool file paths
  jq -r '
    select(.type == "tool_use" and .tool == "Edit") |
    .args.file_path // empty
  ' "$tpath" 2>/dev/null > "$HOOK_TMP_DIR/edited-files.txt" || true

  # Extract all unique file paths touched
  cat "$HOOK_TMP_DIR/written-files.txt" "$HOOK_TMP_DIR/edited-files.txt" 2>/dev/null \
    | sort -u > "$HOOK_TMP_DIR/all-touched-files.txt" || true

  # Extract user + assistant messages for content analysis
  jq -r '
    select(.type == "user" or .type == "assistant") |
    .message // empty
  ' "$tpath" 2>/dev/null > "$HOOK_TMP_DIR/messages.txt" || true

  # Extract tool results for success/failure analysis
  jq -r '
    select(.type == "tool_result") |
    .tool // "unknown"
  ' "$tpath" 2>/dev/null > "$HOOK_TMP_DIR/tool-results.txt" || true

  # Count tool calls by type
  jq -r '
    select(.type == "tool_use") | .tool // "unknown"
  ' "$tpath" 2>/dev/null | sort | uniq -c | sort -rn > "$HOOK_TMP_DIR/tool-counts.txt" || true

  # Check if tests were run
  grep -qiE '(pnpm test|bun test|vitest|jest|pytest|go test|cargo test)' "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null \
    && echo "true" > "$HOOK_TMP_DIR/tests-ran" || echo "false" > "$HOOK_TMP_DIR/tests-ran"

  # Check if builds were run
  grep -qiE '(pnpm run build|pnpm build|./container/build.sh|tsc|bun run typecheck)' "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null \
    && echo "true" > "$HOOK_TMP_DIR/builds-ran" || echo "false" > "$HOOK_TMP_DIR/builds-ran"

  # Extract gotcha-relevant messages
  {
    echo "=== gotcha-keywords ==="
    grep -inE '(gotcha|GOTCHA|注意|小心|陷阱|坑|教训|经验教训)' "$HOOK_TMP_DIR/messages.txt" 2>/dev/null || true
    echo "=== warning-symbols ==="
    grep -inE '(⚠️|🚨|❗|❌|💀)' "$HOOK_TMP_DIR/messages.txt" 2>/dev/null || true
    echo "=== never-do ==="
    grep -inE "(never do|don't ever|avoid|禁止|严禁)" "$HOOK_TMP_DIR/messages.txt" 2>/dev/null || true
    echo "=== remember ==="
    grep -inE '(下次一定|以后要|以后不|记住|记下来|教训)' "$HOOK_TMP_DIR/messages.txt" 2>/dev/null || true
    echo "=== silently ==="
    grep -inE '(这不工作|不生效|silently|悄无声息|意外|出乎意料|没想到)' "$HOOK_TMP_DIR/messages.txt" 2>/dev/null || true
  } > "$HOOK_TMP_DIR/gotcha-matches.txt" 2>/dev/null || true

  # Session duration estimation (first and last message timestamps)
  local first_ts last_ts
  first_ts=$(jq -r '.timestamp // empty' "$tpath" 2>/dev/null | head -1)
  last_ts=$(jq -r '.timestamp // empty' "$tpath" 2>/dev/null | tail -1)
  echo "$first_ts" > "$HOOK_TMP_DIR/session-start-time"
  echo "$last_ts" > "$HOOK_TMP_DIR/session-end-time"

  # Count message rounds (user messages as proxy)
  local rounds
  rounds=$(jq -r 'select(.type == "user") | "x"' "$tpath" 2>/dev/null | wc -l)
  echo "$rounds" > "$HOOK_TMP_DIR/message-rounds"

  # Detect subagent usage
  jq -r '
    select(.type == "tool_use" and .tool == "Agent") |
    .args.subagent_type // "general-purpose"
  ' "$tpath" 2>/dev/null | sort | uniq -c | sort -rn > "$HOOK_TMP_DIR/subagent-usage.txt" || true

  return 0
}

# ── Higher-level queries on parsed data ─────────────────────────────

# Get list of CLI commands that look like project-specific ones
get_project_commands() {
  if [[ ! -f "$HOOK_TMP_DIR/bash-commands.txt" ]]; then return 1; fi
  grep -oE '(pnpm [a-z-]+|bun [a-z-]+|npm [a-z-]+|ncl [a-z-]+|onecli [a-z-]+|docker [a-z-]+|systemctl[^ ]* [a-z-]+|launchctl [a-z-]+|./container/[a-z./-]+)' \
    "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null | sort -u || true
}

# Get list of source files (under src/ or container/) that were touched
get_touched_source_files() {
  if [[ ! -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then return 1; fi
  grep -E '(^src/|^container/agent-runner/src/)' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null || true
}

# Get tool call summary as human-readable string
get_tool_summary() {
  if [[ ! -f "$HOOK_TMP_DIR/tool-counts.txt" ]]; then echo "no data"; return; fi
  head -10 "$HOOK_TMP_DIR/tool-counts.txt" | while read -r count tool; do
    printf "%s:%s " "$tool" "$count"
  done
  echo
}

# Estimate token usage (rough: 1 token ≈ 4 chars)
estimate_tokens() {
  local chars
  chars=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
  echo $((chars / 4))
}
