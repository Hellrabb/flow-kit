#!/bin/bash
# 99-report.sh — Aggregate all module findings → terminal summary + file report
# Runs last. Reads all module output files from HOOK_TMP_DIR.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# ── Collect all findings ────────────────────────────────────────────
FINDINGS_FILE="$HOOK_TMP_DIR/all-findings.txt"
true > "$FINDINGS_FILE"

for f in "$HOOK_TMP_DIR"/*.txt; do
  [[ -f "$f" ]] || continue
  case "$(basename "$f")" in
    bash-commands.txt|written-files.txt|edited-files.txt|all-touched-files.txt|\
    messages.txt|tool-results.txt|tool-counts.txt|tool-calls.txt|\
    gotcha-matches.txt|tests-ran|builds-ran|subagent-usage.txt|\
    session-start-time|session-end-time|message-rounds|all-findings.txt|\
    ai-content.txt|ai-raw-response.txt|run.log|module-errors.log|hook-input.json|\
    transcript-missing|stop-hook-trend.json)
      continue
      ;;
  esac
  cat "$f" >> "$FINDINGS_FILE" 2>/dev/null || true
done

# ── Categorize ──────────────────────────────────────────────────────
count_type() {
  local pattern="$1" file="$2"
  local n
  n=$(grep -c "$pattern" "$file" 2>/dev/null) || n=0
  echo "${n// /}"
}
SUGGESTIONS=$(count_type '^suggestion|' "$FINDINGS_FILE")
WARNINGS=$(count_type '^warning|' "$FINDINGS_FILE")
ERRORS=$(count_type '^error|' "$FINDINGS_FILE")
INFOS=$(count_type '^info|' "$FINDINGS_FILE")
# Ensure numeric
SUGGESTIONS=$((SUGGESTIONS + 0))
WARNINGS=$((WARNINGS + 0))
ERRORS=$((ERRORS + 0))
INFOS=$((INFOS + 0))
TOTAL=$((SUGGESTIONS + WARNINGS + ERRORS + INFOS))

# ── Multiline-aware finding emitters ────────────────────────────────
# FINDINGS_FILE format: TYPE|CHECK|MESSAGE — MESSAGE may span multiple
# lines. Continuation lines lack the TYPE|CHECK| prefix. When we encounter
# a line starting with a DIFFERENT type prefix, we flush the current buffer
# to prevent entries from "leaking" into unrelated sections.

is_finding_prefix() {
  [[ "$1" =~ ^(error|warning|suggestion|info)\|[A-Z] ]]
}

# Emit findings as markdown list items (preserves multiline messages)
emit_findings_md() {
  local typ="$1" in_entry=false check="" msg="" line
  while IFS= read -r line; do
    if [[ "$line" =~ ^${typ}\|[A-Z] ]]; then
      # Same type: flush previous, start new
      if $in_entry; then
        echo "- **${check}**: ${msg}"
      fi
      check=$(echo "$line" | cut -d'|' -f2)
      msg=$(echo "$line" | cut -d'|' -f3-)
      in_entry=true
    elif is_finding_prefix "$line"; then
      # Different type prefix: flush and stop buffering
      if $in_entry; then
        echo "- **${check}**: ${msg}"
        in_entry=false
      fi
    elif $in_entry; then
      # Continuation line: append
      msg+=$'\n'"${line}"
    fi
  done < "$FINDINGS_FILE"
  if $in_entry; then
    echo "- **${check}**: ${msg}"
  fi
}

# Emit findings as single-line terminal output (first line only + "…")
emit_findings_term() {
  local typ="$1" in_entry=false check="" msg="" line first
  while IFS= read -r line; do
    if [[ "$line" =~ ^${typ}\|[A-Z] ]]; then
      # Same type: flush previous, start new
      if $in_entry; then
        first="${msg%%$'\n'*}"
        [[ "$first" != "$msg" ]] && first+="…"
        printf "║     %s: %s\n" "$check" "${first:0:60}"
      fi
      check=$(echo "$line" | cut -d'|' -f2)
      msg=$(echo "$line" | cut -d'|' -f3-)
      in_entry=true
    elif is_finding_prefix "$line"; then
      # Different type prefix: flush and stop buffering
      if $in_entry; then
        first="${msg%%$'\n'*}"
        [[ "$first" != "$msg" ]] && first+="…"
        printf "║     %s: %s\n" "$check" "${first:0:60}"
        in_entry=false
      fi
    elif $in_entry; then
      # Continuation line: append
      msg+=$'\n'"${line}"
    fi
  done < "$FINDINGS_FILE"
  if $in_entry; then
    first="${msg%%$'\n'*}"
    [[ "$first" != "$msg" ]] && first+="…"
    printf "║     %s: %s\n" "$check" "${first:0:60}"
  fi
}

# ── Determine icon ──────────────────────────────────────────────────
if [[ "$ERRORS" -gt 0 ]]; then
  ICON="🚨"
elif [[ "$WARNINGS" -gt 0 ]]; then
  ICON="⚠️"
elif [[ "$SUGGESTIONS" -gt 0 ]]; then
  ICON="📋"
else
  ICON="✅"
fi

# ── Session stats ───────────────────────────────────────────────────
ROUNDS=$(cat "$HOOK_TMP_DIR/message-rounds" 2>/dev/null || echo "?")
TOOLS=$(get_tool_summary 2>/dev/null || echo "?")
START_TS=$(cat "$HOOK_TMP_DIR/session-start-time" 2>/dev/null || echo "")
END_TS=$(cat "$HOOK_TMP_DIR/session-end-time" 2>/dev/null || echo "")

# ── Build terminal summary ─────────────────────────────────────────
MAX_LINES=$(config_get '.output.max_summary_lines' "40")
SHOW_TERMINAL=$(config_get '.output.terminal_summary' "true")

build_summary() {
  echo "╔═══════════════════════════════════════════════════╗"
  printf "║  NanoClaw Stop Hook Report — %s  ║\n" "$(date '+%Y-%m-%d %H:%M')"
  echo "╠═══════════════════════════════════════════════════╣"
  echo "║                                                   ║"

  if [[ "$TOTAL" -eq 0 ]]; then
    echo "║  ✅ 无发现问题。工作区干净。                      ║"
  else
    # Print findings grouped by type
    local line_count=4

    # Errors first
    if [[ "$ERRORS" -gt 0 ]]; then
      printf "║  🚨 错误 (%d):\n" "$ERRORS"
      emit_findings_term "error"
      line_count=$((line_count + ERRORS + 1))
    fi

    # Warnings
    if [[ "$WARNINGS" -gt 0 && "$line_count" -lt "$MAX_LINES" ]]; then
      printf "║  ⚠️ 警告 (%d):\n" "$WARNINGS"
      emit_findings_term "warning"
      line_count=$((line_count + WARNINGS + 1))
    fi

    # Suggestions
    if [[ "$SUGGESTIONS" -gt 0 && "$line_count" -lt "$MAX_LINES" ]]; then
      printf "║  📋 建议 (%d):\n" "$SUGGESTIONS"
      emit_findings_term "suggestion"
      line_count=$((line_count + SUGGESTIONS + 1))
    fi
  fi

  echo "║                                                   ║"
  echo "╠═══════════════════════════════════════════════════╣"
  printf "║  📊 Session: %s 轮 | 工具: %s\n" "$ROUNDS" "$TOOLS"

  # Show git branch if available
  local branch
  branch=$(git_safe branch --show-current 2>/dev/null || echo "?")
  printf "║  🌿 分支: %-38s ║\n" "$branch"
  echo "╚═══════════════════════════════════════════════════╝"

  if [[ "$TOTAL" -gt 0 ]]; then
    echo ""
    echo "📄 完整报告: $REPORT_FILE"
    echo "💡 下次会话用 /review-stop-report 查看"
  fi
}

# ── Write file report ───────────────────────────────────────────────
build_file_report() {
  {
    echo "# NanoClaw Stop Hook Report"
    echo ""
    echo "**时间**: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "**Session**: $SESSION_ID"
    echo "**Stop 计数**: ${STOP_COUNT:-?}"
    echo "**轮次**: $ROUNDS"
    echo "**分支**: $(git_safe branch --show-current 2>/dev/null || echo '?')"
    echo "**工具使用**: $TOOLS"
    echo ""
    echo "---"
    echo ""
    echo "## 总览"
    echo ""
    echo "| 类型 | 数量 |"
    echo "|------|------|"
    echo "| 🚨 错误 | $ERRORS |"
    echo "| ⚠️ 警告 | $WARNINGS |"
    echo "| 📋 建议 | $SUGGESTIONS |"
    echo "| ℹ️ 信息 | $INFOS |"
    echo ""

    # Errors
    if [[ "$ERRORS" -gt 0 ]]; then
      echo "## 🚨 错误"
      echo ""
      emit_findings_md "error"
      echo ""
    fi

    # Warnings
    if [[ "$WARNINGS" -gt 0 ]]; then
      echo "## ⚠️ 警告"
      echo ""
      emit_findings_md "warning"
      echo ""
    fi

    # Suggestions
    if [[ "$SUGGESTIONS" -gt 0 ]]; then
      echo "## 📋 建议"
      echo ""
      emit_findings_md "suggestion"
      echo ""
    fi

    # Info
    if [[ "$INFOS" -gt 0 ]]; then
      echo "## ℹ️ 信息"
      echo ""
      emit_findings_md "info"
      echo ""
    fi

    echo "---"
    echo ""
    echo "*由 stop-hook 自动生成 · $(date -Iseconds)*"
  } > "$REPORT_FILE"
}

# ── Execute ─────────────────────────────────────────────────────────
build_file_report

if [[ "$SHOW_TERMINAL" == "true" ]]; then
  build_summary
fi

# Always output minimal status to stderr so Claude Code shows it
echo "stop-hook: ${ICON} E:${ERRORS} W:${WARNINGS} S:${SUGGESTIONS} I:${INFOS}" >&2
