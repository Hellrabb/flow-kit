#!/bin/bash
# stop-hook common library — shared functions for all stop hook modules
# Source this file: source "${HOOK_BASE_DIR}/lib/common.sh"

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
# CONFIG_FILE is resolved in init_paths() because it depends on PROJECT_ROOT.
# Override via env var STOP_HOOK_CONFIG before sourcing; default: <project>/.claude/stop-hook.json
CONFIG_FILE=""

# Read a config value with jq, return default if missing
config_get() {
  local key="$1" default="${2:-}"
  if [[ ! -f "$CONFIG_FILE" ]]; then echo "$default"; return; fi
  local val
  val=$(jq -r "$key // \"$default\"" "$CONFIG_FILE" 2>/dev/null) || true
  echo "${val:-$default}"
}

# Check if a module is enabled
module_enabled() {
  local mod="$1"
  local en
  en=$(config_get ".modules.${mod}.enabled" "false")
  [[ "$en" == "true" ]]
}

# Check if a specific check is enabled
check_enabled() {
  local mod="$1" check="$2"
  local en
  en=$(config_get ".modules.${mod}.enabled" "false")
  [[ "$en" != "true" ]] && return 1
  # If checks array is empty or not defined, all are enabled
  local has_checks
  has_checks=$(jq -r ".modules.${mod}.checks // [] | length" "$CONFIG_FILE" 2>/dev/null || echo "0")
  if [[ "$has_checks" == "0" ]]; then return 0; fi
  jq -e ".modules.${mod}.checks | index(\"$check\")" "$CONFIG_FILE" >/dev/null 2>&1
}

# ── Environment (set by hook_init, inherited via export for subprocesses) ─
# Use := to only set defaults, never overwrite values exported from parent
: "${HOOK_EVENT:=}"
: "${SESSION_ID:=}"
: "${TRANSCRIPT_PATH:=}"
: "${CWD:=}"
: "${PARENT_SESSION:=}"
: "${HOOK_TMP_DIR:=}"
: "${STOP_COUNT:=0}"

# Initialize hook environment from stdin JSON
# Call once per hook run, before any module
hook_init() {
  HOOK_INPUT=$(cat)

  # Extract fields (jq not guaranteed available, use fallback)
  if command -v jq &>/dev/null; then
    HOOK_EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // ""')
    SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')
    TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // ""')
    CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""')
    PARENT_SESSION=$(echo "$HOOK_INPUT" | jq -r '.parent_session_id // ""')
  else
    HOOK_EVENT="Stop"
    SESSION_ID="unknown"
    TRANSCRIPT_PATH=""
    CWD="$PWD"
    PARENT_SESSION=""
  fi

  export HOOK_EVENT SESSION_ID TRANSCRIPT_PATH CWD PARENT_SESSION

  # Create temp dir for this run
  HOOK_TMP_DIR=$(mktemp -d "/tmp/flow-kit-stop-hook-XXXXXX")
  export HOOK_TMP_DIR

  # Store raw input for debugging
  echo "$HOOK_INPUT" > "$HOOK_TMP_DIR/hook-input.json"
}

# ── Path initialization (call after hook_init) ───────────────────────
# Paths that depend on CWD from stdin must be set after hook_init
init_paths() {
  PROJECT_ROOT="${CWD:-$PWD}"

  # Derive CONFIG_FILE: env override > default project-relative path
  if [[ -z "${CONFIG_FILE:-}" ]]; then
    CONFIG_FILE="${STOP_HOOK_CONFIG:-${PROJECT_ROOT}/.claude/stop-hook.json}"
  fi

  CLAWDE_MD="${PROJECT_ROOT}/CLAUDE.md"

  # Derive memory dir from PROJECT_ROOT (Claude Code convention: / → -)
  local project_slug
  project_slug=$(echo "${PROJECT_ROOT}" | tr '/' '-')
  MEMORY_DIR="${HOME}/.claude/projects${project_slug}/memory"
  MEMORY_INDEX="${MEMORY_DIR}/MEMORY.md"

  REPORT_FILE="${PROJECT_ROOT}/$(config_get '.output.report_file' '.claude/stop-hook-report.md')"
  SUGGESTIONS_FILE="${PROJECT_ROOT}/$(config_get '.output.suggestions_file' '.claude/stop-hook-suggestions.md')"
  STATE_FILE="${PROJECT_ROOT}/.claude/stop-hook-state.json"

  export PROJECT_ROOT CONFIG_FILE CLAWDE_MD MEMORY_DIR MEMORY_INDEX
  export REPORT_FILE SUGGESTIONS_FILE STATE_FILE
}

# ── Gate: Subagent Isolation ────────────────────────────────────────
# Stop hook fires for main sessions AND subagents (SubagentStop event).
# subagent events carry parent_session_id. Gate them out.
is_subagent() {
  [[ "$HOOK_EVENT" == "SubagentStop" ]] && return 0
  [[ -n "$PARENT_SESSION" ]] && return 0
  return 1
}

# ── Output helpers ──────────────────────────────────────────────────
# Each module writes findings to $HOOK_TMP_DIR/<module>.txt
# Format: TYPE|CHECK|MESSAGE
# TYPE = suggestion | warning | error | info
# CHECK = check code (A1, B2, C3, etc.)
# MESSAGE = human-readable message (can contain markdown)

module_output() {
  local type="$1" check="$2" message="$3"
  local mod_name
  mod_name=$(basename "$0" .sh | sed 's/^[0-9][0-9]-//')
  echo "${type}|${check}|${message}" >> "$HOOK_TMP_DIR/${mod_name}.txt"
}

# ── File helpers ────────────────────────────────────────────────────
# Check if file exists and is non-empty
file_not_empty() { [[ -f "$1" && -s "$1" ]]; }

# Count lines in file, 0 if missing
line_count() { wc -l < "$1" 2>/dev/null || echo "0"; }

# ── Git helpers ─────────────────────────────────────────────────────
# Run git command if in a git repo
git_safe() {
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git "$@"
  else
    return 1
  fi
}

# ── CLI detection patterns ──────────────────────────────────────────
# Common CLI command prefixes to detect in transcripts
CLI_PATTERNS=(
  'pnpm run \|pnpm exec \|pnpm test\|pnpm build\|pnpm dev'
  'bun run \|bun test\|bun build'
  'npm run \|npm test\|npm install\|npm ci'
  './container/build.sh\|docker build\|docker run'
  'systemctl --user\|launchctl'
  'ncl '
  'onecli '
  'rtk '
)

# ── Gotcha detection patterns ───────────────────────────────────────
GOTCHA_PATTERNS=(
  'gotcha\|GOTCHA'
  '注意\|小心\|陷阱\|坑'
  '教训\|经验\|经验教训'
  '⚠️\|🚨\|❗\|❌\|💀'
  'never do\|don'"'"'t ever\|avoid\|禁止\|严禁'
  '下次一定\|以后要\|以后不\|记住\|记下来'
  '这不工作\|不生效\|silently\|悄无声息'
  '意外\|出乎意料\|没想到'
)

# ── Project paths (set by init_paths() after hook_init) ──────────────
: "${PROJECT_ROOT:=}"
: "${CLAWDE_MD:=}"
: "${MEMORY_DIR:=}"
: "${MEMORY_INDEX:=}"
: "${REPORT_FILE:=}"
: "${SUGGESTIONS_FILE:=}"
: "${STATE_FILE:=}"
