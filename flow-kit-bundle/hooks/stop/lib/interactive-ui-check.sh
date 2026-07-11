#!/bin/bash
# interactive-ui-check — shared library for detecting weak model interaction gate skips
# Source this file: source "${HOOK_BASE_DIR}/lib/interactive-ui-check.sh"
#
# Provides functions to check whether the model skipped AskUserQuestion / EnterPlanMode
# when the prompt explicitly required it. Used by 27-interactive-ui-check.sh Stop hook
# and SessionStart flow-kit-resume.sh for correction injection.

# NOTE: intentionally NOT using 'set -euo pipefail' here.
# This is a sourced library — the calling script sets its own flags.
# 'set -e' interacts badly with for-loops over associative arrays
# when grep -q returns non-zero inside an if-condition (pipefail kills the loop).

# shellcheck source=/dev/null
source "${HOOK_BASE_DIR}/lib/correction-types.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "${HOOK_BASE_DIR}/lib/correction-file.sh" 2>/dev/null || true

# ── Correction file path ──────────────────────────────────────────────
# Default: <project>/.flow-active.interactive-ui-fix (JSON, gitignored)
: "${CORRECTION_FILE:=}"

# ── GATE_MAP: prompt keyword → required tool ──────────────────────────
# When a prompt contains one of these keywords, the model MUST invoke the
# corresponding tool in its response. If it doesn't, it skipped the gate.
# Format: declare -A GATE_MAP=(["keyword"]="ToolName")
declare -gA GATE_MAP=(
  ["反问用户"]="AskUserQuestion"
  ["反问 gate"]="AskUserQuestion"
  ["进入计划模式"]="EnterPlanMode"
  ["停下来反问"]="AskUserQuestion"
  ["停下来。禁止自动"]="AskUserQuestion"
  ["等用户选定"]="AskUserQuestion"
  ["必须等待用户回复"]="AskUserQuestion"
  ["归档操作必须用户确认"]="AskUserQuestion"
  ["先出计划"]="EnterPlanMode"
)

# ── Transcript helpers ────────────────────────────────────────────────

# Extract the last assistant message from a transcript JSONL file
# Returns the raw text of the most recent assistant turn
get_last_assistant_message() {
  local transcript="$1"
  if [[ ! -f "$transcript" ]]; then
    echo ""
    return 1
  fi
  # Transcript is JSONL: one JSON object per line.
  # Find lines where role="assistant", take the last one, extract content text.
  # Falls back to reading the whole file if jq fails.
  if command -v jq &>/dev/null; then
    jq -r 'select(.role == "assistant") | .content // empty' "$transcript" 2>/dev/null | tail -1 || true
  else
    tail -50 "$transcript" 2>/dev/null || true
  fi
}

# Extract the last user/system message (the prompt) from a transcript
get_last_prompt_message() {
  local transcript="$1"
  if [[ ! -f "$transcript" ]]; then
    echo ""
    return 1
  fi
  if command -v jq &>/dev/null; then
    jq -r 'select(.role == "user" or .role == "system") | .content // empty' "$transcript" 2>/dev/null | tail -1 || true
  else
    tail -100 "$transcript" 2>/dev/null || true
  fi
}

# ── Detection functions ────────────────────────────────────────────────

# Check if the prompt contains any interaction gate keyword.
# Returns: 0 if gate found (echoes the gate type + required tool), 1 if no gate.
check_interaction_gate() {
  local prompt_text="$1"
  local found_gate=""
  local found_tool=""

  for keyword in "${!GATE_MAP[@]}"; do
    if echo "$prompt_text" | grep -qF "$keyword" 2>/dev/null; then
      found_gate="$keyword"
      found_tool="${GATE_MAP[$keyword]}"
      break
    fi
  done

  if [[ -n "$found_gate" ]]; then
    echo "GATE_FOUND|${found_gate}|${found_tool}"
    return 0
  fi
  return 1
}

# Check if the model's response contains a tool call for the given tool.
# We look for telltale signs of tool invocation in the transcript:
#   - For AskUserQuestion: "ask_user_question" or "AskUserQuestion" or tool_use blocks
#   - For EnterPlanMode: "enter_plan_mode" or "EnterPlanMode" or tool_use blocks
# Returns: 0 if tool was called, 1 if not.
check_tool_invocation() {
  local response_text="$1"
  local required_tool="$2"

  case "$required_tool" in
    AskUserQuestion)
      echo "$response_text" | grep -qiE "AskUserQuestion|ask_user_question|askuserquestion" 2>/dev/null && return 0
      ;;
    EnterPlanMode)
      echo "$response_text" | grep -qiE "EnterPlanMode|enter_plan_mode|enterplanmode" 2>/dev/null && return 0
      ;;
    *)
      return 1
      ;;
  esac
  return 1
}

# Full detection: prompt has gate AND model didn't call tool → skip detected.
# Returns: 0 = skip detected (writes correction needed), 1 = no skip.
detect_interaction_skip() {
  local transcript="$1"
  local prompt_text response_text

  prompt_text=$(get_last_prompt_message "$transcript" 2>/dev/null || true)
  response_text=$(get_last_assistant_message "$transcript" 2>/dev/null || true)

  if [[ -z "$prompt_text" || -z "$response_text" ]]; then
    return 1
  fi

  local gate_result
  gate_result=$(check_interaction_gate "$prompt_text" 2>/dev/null) || return 1

  local gate_keyword tool_name
  gate_keyword=$(echo "$gate_result" | cut -d'|' -f2)
  tool_name=$(echo "$gate_result" | cut -d'|' -f3)

  if check_tool_invocation "$response_text" "$tool_name"; then
    # Tool was called — no skip
    return 1
  fi

  # Gate found but tool not called → skip detected
  echo "SKIP_DETECTED|${gate_keyword}|${tool_name}"
  return 0
}

# ── Correction file management ─────────────────────────────────────────
# Delegates to correction-file.sh for JSON read/write/clear/exists.
# Business logic (retry_count tracking) stays here.

# Set the correction file path (call before write/read/clear)
# Defaults to PROJECT_ROOT/.flow-active.interactive-ui-fix
init_correction_path() {
  local project_root="${1:-$PWD}"
  CORRECTION_FILE="${project_root}/.flow-active.interactive-ui-fix"
  export CORRECTION_FILE
}

# Write correction file when a skip is detected
write_correction_file() {
  local gate_type="$1"    # e.g. "反问 gate"
  local required_tool="$2" # e.g. "AskUserQuestion"
  local timestamp="${3:-$(date -Iseconds)}"

  if [[ -z "${CORRECTION_FILE:-}" ]]; then
    echo "[interactive-ui-check] ERROR: CORRECTION_FILE not set. Call init_correction_path first." >&2
    return 1
  fi

  # Read existing retry_count (increment if file exists)
  local retry_count=0
  if correction_file_exists "$CORRECTION_FILE"; then
    retry_count=$(jq -r '.retry_count // 0' "$CORRECTION_FILE" 2>/dev/null || echo "0")
    retry_count=$((retry_count + 1))
  fi

  # Build JSON with backward-compatible top-level fields + violations for merge
  local json
  json=$(jq -n \
    --arg gate_type "$gate_type" \
    --arg required_tool "$required_tool" \
    --arg timestamp "$timestamp" \
    --argjson retry_count "$retry_count" \
    '{
      gate_type: $gate_type,
      required_tool: $required_tool,
      retry_count: $retry_count,
      timestamp: $timestamp,
      violations: [{gate_type: $gate_type, tool: $required_tool, retry_count: $retry_count, timestamp: $timestamp}]
    }')
  correction_file_write "$CORRECTION_FILE" "$json" "merge" || return 1

  echo "[interactive-ui-check] Correction file written: gate=${gate_type} tool=${required_tool} retry=${retry_count}"
  return 0
}


# Clear correction file (delegates to correction-file.sh)
clear_correction_file() {
  if [[ -z "${CORRECTION_FILE:-}" ]]; then
    return 1
  fi
  correction_file_clear "$CORRECTION_FILE"
}

# Check if correction file exists and is valid JSON (delegates to correction-file.sh)
has_correction_file() {
  if [[ -z "${CORRECTION_FILE:-}" ]]; then
    return 1
  fi
  correction_file_exists "$CORRECTION_FILE"
}

# Get the retry count from an existing correction file
get_retry_count() {
  if [[ -z "${CORRECTION_FILE:-}" || ! -f "$CORRECTION_FILE" ]]; then
    echo "0"
    return
  fi
  jq -r '.retry_count // 0' "$CORRECTION_FILE" 2>/dev/null || echo "0"
}

# ── Continuous skip protection ─────────────────────────────────────────
# Returns: 0 = should inject correction, 1 = exceeded retry limit (needs human)
should_inject_correction() {
  local retry_count
  retry_count=$(get_retry_count)

  if [[ "$retry_count" -ge 2 ]]; then
    echo "STOP_CORRECTION|retry_count=${retry_count}|连续跳过交互 gate 3 次，需人工介入"
    return 1
  fi
  return 0
}
