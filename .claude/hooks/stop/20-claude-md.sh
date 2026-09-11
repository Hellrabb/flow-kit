#!/bin/bash
# Module A — CLAUDE.md Intelligent Management
# Checks: A1 (new commands), A2 (gotcha capture), A3 (new file tracking), A6 (staleness)

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "20" || true

# Skip if module disabled
module_enabled "claude-md" || exit 0
[[ -f "$CLAWDE_MD" ]] || exit 0

# Runtime-aware label: AGENTS.md on dsh, CLAUDE.md on claude/opencode.
MD_NAME="$(basename "$CLAWDE_MD")"

# ═══════════════════════════════════════════════════════════════════
# A1: New command / workflow discovery
# ═══════════════════════════════════════════════════════════════════
check_a1_body() {

  local cmds_file="$HOOK_TMP_DIR/bash-commands.txt"
  [[ -f "$cmds_file" && -s "$cmds_file" ]] || return 0

  # Extract project-relevant commands
  local new_cmds
  new_cmds=$(get_project_commands 2>/dev/null || true)
  [[ -n "$new_cmds" ]] || return 0

  # For each command found in transcript, check if documented in CLAUDE.md
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    # Strip args, keep the base command pattern
    local base_cmd
    base_cmd=$(echo "$cmd" | grep -oE '^[a-z./-]+ [a-z./-]+' || echo "$cmd")
    if ! grep -qF "$base_cmd" "$CLAWDE_MD" 2>/dev/null; then
      module_output "suggestion" "A1" "未记录的命令: \`$cmd\` — 建议加入 ${MD_NAME}"
    fi
  done <<< "$new_cmds"
}
check_a1() { run_check "claude-md" "A1" "" check_a1_body; }

# ═══════════════════════════════════════════════════════════════════
# A2: Gotcha auto-capture
# ═══════════════════════════════════════════════════════════════════
check_a2_body() {

  local gotcha_file="$HOOK_TMP_DIR/gotcha-matches.txt"
  [[ -f "$gotcha_file" && -s "$gotcha_file" ]] || return 0

  # Count significant gotcha signals (non-empty, not just section headers)
  local significant
  significant=$(grep -civE '^(===|$)' "$gotcha_file" 2>/dev/null || true)

  if [[ "${significant:-0}" -gt 0 ]]; then
    # Extract first few gotcha contexts (max 3 to avoid noise)
    grep -ivE '^(===|$)' "$gotcha_file" 2>/dev/null | head -12 | while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # Truncate long lines
      local snippet="${line:0:200}"
      module_output "suggestion" "A2" "潜在 gotcha: ...${snippet}..."
      break  # One aggregated suggestion is clearer
    done
    module_output "info" "A2" "本 session 检测到 $significant 条 gotcha 信号，建议 review 是否需更新 ${MD_NAME}"
  fi
}
check_a2() { run_check "claude-md" "A2" "" check_a2_body; }

# ═══════════════════════════════════════════════════════════════════
# A3: New file tracking — cross-ref with CLAUDE.md Key Files table
# ═══════════════════════════════════════════════════════════════════
check_a3_body() {

  local touched="$HOOK_TMP_DIR/all-touched-files.txt"
  [[ -f "$touched" && -s "$touched" ]] || return 0

  # Only check source files (not temp/plan files)
  local src_files
  src_files=$(get_touched_source_files 2>/dev/null || true)
  [[ -n "$src_files" ]] || return 0

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # Is this file path mentioned in CLAUDE.md?
    local fname
    fname=$(basename "$f")
    if ! grep -qF "$fname" "$CLAWDE_MD" 2>/dev/null; then
      module_output "suggestion" "A3" "新文件未在 ${MD_NAME} 中记录: \`$f\`"
    fi
  done <<< "$src_files"
}
check_a3() { run_check "claude-md" "A3" "" check_a3_body; }

# ═══════════════════════════════════════════════════════════════════
# A6: CLAUDE.md staleness check
# ═══════════════════════════════════════════════════════════════════
check_a6_body() {

  local stale_days
  stale_days=$(config_get '.thresholds.claude_md_stale_days' "7")

  local now then diff_days
  now=$(date +%s)
  then=$(stat -c %Y "$CLAWDE_MD" 2>/dev/null || stat -f %m "$CLAWDE_MD" 2>/dev/null || echo "$now")
  diff_days=$(( (now - then) / 86400 ))

  if [[ "$diff_days" -ge "$stale_days" ]]; then
    # Only flag if this session had substantive changes
    local src_files
    src_files=$(get_touched_source_files 2>/dev/null || true)
    if [[ -n "$src_files" ]]; then
      module_output "warning" "A6" "${MD_NAME} 上次修改距今 ${diff_days} 天，本 session 有源码变更，建议 review"
    fi
  fi
}
check_a6() { run_check "claude-md" "A6" "" check_a6_body; }

# ── Run all checks ──────────────────────────────────────────────────
check_a1
check_a2
check_a3
check_a6

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "20" || true
