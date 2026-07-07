#!/bin/bash
# stop-hook common library — shared functions for all stop hook modules
# Source this file: source "${HOOK_BASE_DIR}/lib/common.sh"

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
# CONFIG_FILE is resolved in init_paths() because it depends on PROJECT_ROOT.
# Override via env var STOP_HOOK_CONFIG before sourcing; default: <project>/.claude/stop-hook.json
: "${CONFIG_FILE:=}"  # 仅在未设时设默认值，不覆盖调用方已设的值

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
  en=$(config_get ".modules[\"${mod}\"].enabled" "false")
  [[ "$en" == "true" ]]
}

# Check if a specific check is enabled
check_enabled() {
  local mod="$1" check="$2"
  local en
  en=$(config_get ".modules[\"${mod}\"].enabled" "false")
  [[ "$en" != "true" ]] && return 1
  # If checks array is empty or not defined, all are enabled
  local has_checks
  has_checks=$(jq -r ".modules[\"${mod}\"].checks // [] | length" "$CONFIG_FILE" 2>/dev/null || echo "0")
  if [[ "$has_checks" == "0" ]]; then return 0; fi
  jq -e ".modules[\"${mod}\"].checks | index(\"$check\")" "$CONFIG_FILE" >/dev/null 2>&1
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

  # Derive CONFIG_FILE: env override > project-level > user-scope fallback
  # (gate-integrity dogfood: 项目级缺失时回退 user-scope，否则全局 enabled=true 未被读 → module_enabled 恒 false)
  if [[ -z "${CONFIG_FILE:-}" ]]; then
    CONFIG_FILE="${STOP_HOOK_CONFIG:-${PROJECT_ROOT}/.claude/stop-hook.json}"
    if [[ ! -f "$CONFIG_FILE" && -f "${HOME}/.claude/stop-hook.json" ]]; then
      CONFIG_FILE="${HOME}/.claude/stop-hook.json"
    fi
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

# ── Independent review state helpers ─────────────────────────────────
# Write/update the L3 independent-review handshake state on failure.
# Usage: write_failed_state <state_file> <phase>
# Increments fail_count, sets status:"failed", stamps written_at.
write_failed_state() {
  local state_file="$1" phase="$2"
  local fc="0"
  if [[ -f "$state_file" ]]; then
    fc=$(jq -r --arg p "$phase" '.[$p].fail_count // 0' "$state_file" 2>/dev/null || echo "0")
  fi
  [[ "$fc" =~ ^[0-9]+$ ]] || fc="0"
  fc=$((fc + 1))
  local ts
  ts=$(date -Iseconds 2>/dev/null || echo "")
  # Per-phase merge: preserve other phases' state
  if [[ -f "$state_file" ]]; then
    jq --arg p "$phase" --argjson fc "$fc" --arg ts "$ts" \
      '.[$p] = {status:"failed", fail_count:$fc, written_at:$ts}' \
      "$state_file" > "${state_file}.tmp" 2>/dev/null && mv "${state_file}.tmp" "$state_file" || true
  else
    jq -n --arg p "$phase" --argjson fc "$fc" --arg ts "$ts" \
      '{($p): {status:"failed", fail_count:$fc, written_at:$ts}}' \
      > "$state_file" 2>/dev/null || true
  fi
}

# ── File helpers ────────────────────────────────────────────────────
# Check if file exists and is non-empty
file_not_empty() { [[ -f "$1" && -s "$1" ]]; }

# Count lines in file, 0 if missing
line_count() { wc -l < "$1" 2>/dev/null || echo "0"; }

# Atomically apply a jq filter to a JSON file (write to .tmp then mv).
# Usage: jq_atomic_write '<jq filter>' <target_file>
# Returns: 0 on success, 1 on failure (file unchanged)
jq_atomic_write() {
  local filter="$1" target="$2"
  if [[ ! -f "$target" ]]; then return 1; fi
  jq "$filter" "$target" > "${target}.tmp" 2>/dev/null && mv "${target}.tmp" "$target" || return 1
}

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

# ── fk_resolve_phase() · Pipeline-aware phase resolution ──────────────
# Resolve the active phase from .flow-active.
# Pipeline mode (goal.scope="pipeline"): use goal.current_phase
# Single-phase mode: fall back to .phase
# Outputs the resolved phase string to stdout.
# Returns 0 on success, 1 if .flow-active missing or unreadable.
fk_resolve_phase() {
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local scope phase
  scope=$(jq -r '.goal.scope // ""' "$flow_file" 2>/dev/null || echo "")

  if [[ "$scope" == "pipeline" ]]; then
    phase=$(jq -r '.goal.current_phase // ""' "$flow_file" 2>/dev/null || echo "")
    # Validate: must be a non-empty phase number (0-7)
    if [[ "$phase" =~ ^[0-7]$ ]]; then
      echo "$phase"
      return 0
    fi
    # Pipeline but current_phase invalid/empty → fall through to .phase
  fi

  # Fallback: single-phase mode or pipeline with invalid current_phase
  phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
  echo "$phase"
  return 0
}

# ── Hook module registry (single source of truth) ────────────────────
# All consumers iterate: for name in "${HOOK_MODULE_NAMES[@]}"; do ...
# Single source for install_hooks.sh, package-flow-kit.sh, and any
# future script that needs to enumerate all stop hook modules.
declare -a HOOK_MODULE_NAMES=(
  00-gate 01-transcript-parse
  20-claude-md 21-memory 22-git 23-quality 24-session 25-project
  26-workflow 27-interactive-ui-check 28-weak-model-compliance
  29-independent-review 30-ai-analyze 31-auto-advance 32-fallback-guard 33-flow-active-integrity 99-report
)
