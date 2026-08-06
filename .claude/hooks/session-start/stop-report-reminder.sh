#!/bin/bash
# stop-report-reminder.sh — SessionStart hook
# Reminds user about unreviewed stop hook reports and AI suggestions.

set -euo pipefail

HOOK_BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
STOP_HOOK_DIR="${HOOK_BASE_DIR}/../stop"

# Source common lib for config helpers
if [[ -f "${STOP_HOOK_DIR}/lib/common.sh" ]]; then
  source "${STOP_HOOK_DIR}/lib/common.sh"
else
  echo "stop-report-reminder: common.sh not found" >&2
  exit 0
fi

# ── Gate: Subagent isolation ────────────────────────────────────────
# Read stdin to check if this is a subagent SessionStart
HOOK_INPUT=$(cat)
if command -v jq &>/dev/null; then
  PARENT_SESSION=$(echo "$HOOK_INPUT" | jq -r '.parent_session_id // ""')
  if [[ -n "$PARENT_SESSION" ]]; then
    exit 0
  fi
fi

# ── Set CWD from hook input (needed for init_paths) ──────────────────
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "$PWD")
export CWD
init_paths  # Sets PROJECT_ROOT, CLAWDE_MD, etc. from CWD

# ── Gate: Reminder enabled? ─────────────────────────────────────────
remind_enabled=$(config_get '.session_start.remind_unreviewed' "true")
[[ "$remind_enabled" == "true" ]] || exit 0

# ── Check for stop hook report ──────────────────────────────────────
report_file="${PROJECT_ROOT}/$(config_get '.output.report_file' '.claude/stop-hook-report.md')"
suggestions_file="${PROJECT_ROOT}/$(config_get '.output.suggestions_file' '.claude/stop-hook-suggestions.md')"

has_report=false
has_suggestions=false

[[ -f "$report_file" ]] && has_report=true
[[ -f "$suggestions_file" ]] && has_suggestions=true

if ! $has_report && ! $has_suggestions; then
  exit 0
fi

# ── Check report freshness ──────────────────────────────────────────
max_age_days=$(config_get '.thresholds.report_max_age_days' "3")
max_age_sec=$((max_age_days * 86400))

check_age() {
  local file="$1"
  local now then
  now=$(date +%s)
  then=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "$now")
  local age=$((now - then))
  [[ "$age" -lt "$max_age_sec" ]]
}

# ── Count how many times we've reminded about this report ───────────
reminder_key="reminded_$(stat -c %Y "$report_file" 2>/dev/null || stat -f %m "$report_file" 2>/dev/null || echo "0")"
reminder_count=$(jq -r ".${reminder_key} // 0" "$STATE_FILE" 2>/dev/null || echo "0")
max_reminders=$(config_get '.session_start.max_reminders' "3")

if [[ "$reminder_count" -ge "$max_reminders" ]]; then
  exit 0
fi

# ── Display reminder ────────────────────────────────────────────────
if $has_report && check_age "$report_file"; then
  echo ""
  echo "╔═══════════════════════════════════════════════════╗"
  echo "║  📋 上次 Stop Hook 报告待 Review                  ║"
  echo "╠═══════════════════════════════════════════════════╣"

  # Extract actual counts from table row (not header), default to 0
  report_errors=$(sed -n 's/.*🚨 错误 *| *\([0-9]*\).*/\1/p' "$report_file" 2>/dev/null || echo "0")
  report_warnings=$(sed -n 's/.*⚠️ 警告 *| *\([0-9]*\).*/\1/p' "$report_file" 2>/dev/null || echo "0")
  report_suggestions=$(sed -n 's/.*📋 建议 *| *\([0-9]*\).*/\1/p' "$report_file" 2>/dev/null || echo "0")
  report_errors=${report_errors:-0}
  report_warnings=${report_warnings:-0}
  report_suggestions=${report_suggestions:-0}

  printf "║  🚨 %-2s  ⚠️ %-2s  📋 %-2s                            ║\n" "$report_errors" "$report_warnings" "$report_suggestions"
  echo "║                                                   ║"
  echo "║  用 /review-stop-report 查看并处理                 ║"

  if $has_suggestions && check_age "$suggestions_file"; then
    echo "║  🤖 AI 深度建议也可查看                            ║"
  fi

  echo "╚═══════════════════════════════════════════════════╝"
  echo ""
fi

# ── Update reminder count ───────────────────────────────────────────
if [[ -f "$STATE_FILE" ]]; then
  tmp_state=$(jq ".${reminder_key} = $((reminder_count + 1))" "$STATE_FILE" 2>/dev/null || echo "$STATE_FILE")
  echo "$tmp_state" > "$STATE_FILE"
fi
