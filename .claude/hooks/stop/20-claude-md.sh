#!/bin/bash
# Module A — CLAUDE.md Intelligent Management
# Checks: A1 (new commands), A2 (gotcha capture), A3 (new file tracking), A6 (staleness)

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# Skip if module disabled
module_enabled "claude-md" || exit 0
[[ -f "$CLAWDE_MD" ]] || exit 0

# ═══════════════════════════════════════════════════════════════════
# A1: New command / workflow discovery
# ═══════════════════════════════════════════════════════════════════
check_a1() {
  check_enabled "claude-md" "A1" || return 0

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
      module_output "suggestion" "A1" "未记录的命令: \`$cmd\` — 建议加入 CLAUDE.md"
    fi
  done <<< "$new_cmds"
}

# ═══════════════════════════════════════════════════════════════════
# A2: Gotcha auto-capture
# ═══════════════════════════════════════════════════════════════════
check_a2() {
  check_enabled "claude-md" "A2" || return 0

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
    module_output "info" "A2" "本 session 检测到 $significant 条 gotcha 信号，建议 review 是否需更新 CLAUDE.md"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# A3: New file tracking — cross-ref with CLAUDE.md Key Files table
# ═══════════════════════════════════════════════════════════════════
check_a3() {
  check_enabled "claude-md" "A3" || return 0

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
      module_output "suggestion" "A3" "新文件未在 CLAUDE.md 中记录: \`$f\`"
    fi
  done <<< "$src_files"
}

# ═══════════════════════════════════════════════════════════════════
# A6: CLAUDE.md staleness check
# ═══════════════════════════════════════════════════════════════════
check_a6() {
  check_enabled "claude-md" "A6" || return 0

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
      module_output "warning" "A6" "CLAUDE.md 上次修改距今 ${diff_days} 天，本 session 有源码变更，建议 review"
    fi
  fi
}

# ── Run all checks ──────────────────────────────────────────────────
check_a1
check_a2
check_a3
check_a6
