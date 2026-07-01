#!/bin/bash
# weak-model-compliance.sh — L1/L2/L3 compliance scanning for weak model responses
# Source this file: source "${HOOK_BASE_DIR}/lib/weak-model-compliance.sh"
#
# Provides functions to detect weak model compliance violations in session
# transcripts. Used by 28-weak-model-compliance.sh Stop hook and SessionStart
# flow-kit-resume.sh for correction injection.
#
# Layers:
#   L1 — Rule compliance: forbidden file touches + generic rule violation patterns
#   L2 — Self-check completeness: PCSC tables with blank/missing rows
#   L3 — Evidence chain: cited paths not found in tool call history

# NOTE: intentionally NOT using 'set -euo pipefail' here.
# This is a sourced library — the calling script sets its own flags.

# shellcheck source=/dev/null
source "${HOOK_BASE_DIR}/lib/correction-file.sh" 2>/dev/null || true

# ── Correction file path ──────────────────────────────────────────────
: "${COMPLIANCE_CORRECTION_FILE:=}"

# ── Pattern definitions ────────────────────────────────────────────────

# L1: Generic rule-violation keywords (from RULES.md / SYSTEM.md patterns)
# Each entry is a grep -E compatible pattern
L1_RULE_PATTERNS=(
  '禁止编造.*路径'
  '禁止跳过.*(AskUserQuestion|EnterPlanMode|反问|gate)'
  '禁止.*顺手.*(改|删|重写)'
  '不要.*(跳过|省略).*(自检|check|验证|verify)'
  '必须.*(grep|read|验证).*(存在|真实)'
)

# L2: PCSC self-check table row pattern — must match | # | ... | ✅ / ❌ |
L2_TABLE_ROW_PATTERN='^\| [0-9]+\s*\|.*\| ✅ / ❌ \|'

# L3: Known directory prefixes for path extraction (avoids false positives)
L3_PATH_PREFIXES=(
  'flow-kit/'
  'flow-kit-bundle/'
  '\.specs/'
  'test/'
  'src/'
  'lib/'
  'hooks/'
  '~/.claude/'
  '\.claude/'
)

# ── Correction file management ─────────────────────────────────────────
# Delegates to correction-file.sh for JSON read/write/clear/exists.
# Business logic (layer tagging, dedup by rule+location) stays here.

init_compliance_correction_path() {
  local project_root="${1:-$PWD}"
  COMPLIANCE_CORRECTION_FILE="${project_root}/.flow-active.correction"
  export COMPLIANCE_CORRECTION_FILE
}

has_compliance_correction() {
  if [[ -z "${COMPLIANCE_CORRECTION_FILE:-}" ]]; then
    return 1
  fi
  correction_file_exists "$COMPLIANCE_CORRECTION_FILE"
}

# Merge-write correction: read old violations, append new (dedup by layer+rule+location),
# write merged JSON with timestamp.
write_compliance_correction() {
  local layer="$1"    # L1 | L2 | L3
  local violations_json="$2"  # JSON array string: [{"rule":...,"location":...,"fix":...}]
  local timestamp="${3:-$(date -Iseconds)}"

  if [[ -z "${COMPLIANCE_CORRECTION_FILE:-}" ]]; then
    echo "[weak-model-compliance] ERROR: COMPLIANCE_CORRECTION_FILE not set. Call init_compliance_correction_path first." >&2
    return 1
  fi

  # Tag violations with layer
  local new_violations
  new_violations=$(echo "$violations_json" | jq -c --arg layer "$layer" \
    '[.[] | . + {layer: $layer}]' 2>/dev/null) || {
    echo "[weak-model-compliance] ERROR: failed to parse violations JSON" >&2
    return 1
  }

  # Read existing violations from wrapper, merge, dedup by (layer, rule, location)
  local existing_violations="[]"
  if correction_file_exists "$COMPLIANCE_CORRECTION_FILE"; then
    existing_violations=$(jq -c '.violations // []' "$COMPLIANCE_CORRECTION_FILE" 2>/dev/null || echo "[]")
  fi

  local merged_violations
  merged_violations=$(jq -nc \
    --argjson existing "$existing_violations" \
    --argjson new "$new_violations" \
    '[($existing[]?), ($new[]?)] | unique_by({layer, rule, location})' 2>/dev/null) || merged_violations="$new_violations"

  # Write wrapper object atomically (correction_file_write with overwrite)
  local wrapper_json
  wrapper_json=$(jq -n \
    --arg type "compliance" \
    --argjson violations "$merged_violations" \
    --arg timestamp "$timestamp" \
    '{type: $type, violations: $violations, written_at: $timestamp}')
  correction_file_write "$COMPLIANCE_CORRECTION_FILE" "$wrapper_json" "overwrite" || return 1

  local count
  count=$(echo "$merged_violations" | jq 'length' 2>/dev/null || echo "?")
  echo "[weak-model-compliance] Correction file written: type=compliance layer=${layer} total_violations=${count}"
  return 0
}

clear_compliance_correction() {
  if [[ -z "${COMPLIANCE_CORRECTION_FILE:-}" ]]; then
    return 1
  fi
  correction_file_clear "$COMPLIANCE_CORRECTION_FILE"
}

# ── Helper: extract forbidden paths from CONTEXT.md ────────────────────

# Parse CONTEXT.md「禁动清单」section and output one path per line.
# Output format: path|description
read_forbidden_list() {
  local context_file="$1"

  if [[ ! -f "$context_file" ]]; then
    return 1
  fi

  # Extract lines between「禁动清单」and next heading (## or ---)
  # Match lines like: - `path`（description）
  sed -n '/^### 禁动清单/,/^### /p' "$context_file" 2>/dev/null \
    | grep -oE '`[^`]+`' \
    | tr -d '`' \
    | grep -v '^$' || true
}

# ── L1: Rule compliance scan ───────────────────────────────────────────

# Check if the model's tool calls touched forbidden files.
# Uses transcript-parser's pre-parsed files: written-files.txt, edited-files.txt
# Also checks assistant messages for generic rule-violation patterns.
#
# Output: JSON array of violations (empty array if clean)
scan_l1_rules() {
  local tmp_dir="$1"       # HOOK_TMP_DIR with transcript-parser output
  local context_file="$2"  # Path to CONTEXT.md
  local violations="[]"

  # ── L1a: Forbidden file touch detection ──────────────────────────────
  local forbidden_paths
  forbidden_paths=$(read_forbidden_list "$context_file" 2>/dev/null || true)

  if [[ -n "$forbidden_paths" ]]; then
    local all_touched
    all_touched=$(cat "$tmp_dir/written-files.txt" "$tmp_dir/edited-files.txt" 2>/dev/null | sort -u || true)

    while IFS= read -r fpath; do
      [[ -z "$fpath" ]] && continue
      if echo "$all_touched" | grep -qxF "$fpath" 2>/dev/null; then
        violations=$(echo "$violations" | jq -c \
          --arg rule "L1: 触碰禁动文件" \
          --arg location "$fpath" \
          --arg fix "撤销对 ${fpath} 的修改。该文件在 CONTEXT.md 禁动清单中，AI 不允许顺手改动。若确需修改请先更新禁动清单。" \
          '. + [{rule: $rule, location: $location, fix: $fix}]')
      fi
    done <<< "$forbidden_paths"
  fi

  # ── L1b: Generic rule-violation pattern check in assistant messages ──

  if [[ -f "$tmp_dir/messages.txt" ]]; then
    for pattern in "${L1_RULE_PATTERNS[@]}"; do
      local matches
      matches=$(grep -inE "$pattern" "$tmp_dir/messages.txt" 2>/dev/null | head -5 || true)
      if [[ -n "$matches" ]]; then
        local first_line
        first_line=$(echo "$matches" | head -1 | cut -d: -f1)
        local snippet
        snippet=$(echo "$matches" | head -1 | cut -d: -f2- | cut -c1-80)
        violations=$(echo "$violations" | jq -c \
          --arg rule "L1: 违反通用禁动规则" \
          --arg location "messages.txt:${first_line}" \
          --arg fix "检测到违规模式:「${snippet}」。请对照 RULES.md/SYSTEM.md 中的对应规则，修正行为后重试。" \
          '. + [{rule: $rule, location: $location, fix: $fix}]')
      fi
    done
  fi

  echo "$violations"
}

# ── L2: Self-check completeness scan ───────────────────────────────────

# Grep assistant messages for PCSC self-check tables, verify every row
# has a non-empty ✅/❌ marker.
#
# Output: JSON array of violations (empty array if clean)
scan_l2_selfcheck() {
  local tmp_dir="$1"
  local violations="[]"

  if [[ ! -f "$tmp_dir/messages.txt" ]]; then
    echo "$violations"
    return
  fi

  # Find PCSC table blocks: lines between a header like「阶段完成自检」and an
  # empty-line-terminated table. Handles the blank line between heading and table.
  # State machine: 0=normal, 1=heading_seen (allow blank line), 2=in_table
  local state=0
  local table_start=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Detect start of PCSC table
    if [[ "$state" -eq 0 ]] && echo "$line" | grep -qE '(阶段完成自检|Phase Completion Self-Check|自检|Self-Check)'; then
      state=1  # heading seen — next line may be blank or table start
      table_start=$line_num
      continue
    fi

    # State 1: waiting for table to start (skip blank lines, detect first table row)
    if [[ "$state" -eq 1 ]]; then
      if echo "$line" | grep -qE '^\| [0-9]+\s*\|'; then
        state=2  # in table
        # Fall through to process this row
      elif [[ -z "$(echo "$line" | tr -d '[:space:]')" ]]; then
        continue  # skip blank line between heading and table
      elif echo "$line" | grep -qE '^#{1,3}\s'; then
        state=0  # new heading before table started — not a PCSC table
        continue
      else
        continue  # other content (e.g., description text before table)
      fi
    fi

    # State 2: inside table — process rows and detect end
    if [[ "$state" -eq 2 ]]; then
      # End of table: empty line or new section heading
      if [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] || echo "$line" | grep -qE '^#{1,3}\s'; then
        state=0
        continue
      fi

      # Check if this is a table row: | # | ... | marker |
      if echo "$line" | grep -qE '^\| [0-9]+\s*\|'; then
        # Extract the last column (✅/❌ marker)
        local last_col
        last_col=$(echo "$line" | awk -F'|' '{print $(NF-1)}' | tr -d '[:space:]')
        if [[ -z "$last_col" ]]; then
          violations=$(echo "$violations" | jq -c \
            --arg rule "L2: 自检表行未填标记" \
            --arg location "messages.txt:${line_num}" \
            --arg fix "自检表第 $((line_num - table_start)) 行缺少 ✅ 或 ❌ 标记。请补填该行状态后重新生成回复。" \
            '. + [{rule: $rule, location: $location, fix: $fix}]')
        fi
      fi
    fi
  done < "$tmp_dir/messages.txt"

  echo "$violations"
}

# ── L3: Evidence chain verification ────────────────────────────────────

# Extract file paths from assistant messages and cross-reference with
# tool call history. Paths not found in tool calls are hallucinated.
#
# Output: JSON array of violations (empty array if clean)
scan_l3_evidence() {
  local tmp_dir="$1"
  local violations="[]"

  if [[ ! -f "$tmp_dir/messages.txt" ]]; then
    echo "$violations"
    return
  fi

  # Build path prefix alternation pattern
  local prefix_pattern
  prefix_pattern=$(IFS='|'; echo "${L3_PATH_PREFIXES[*]}")

  # Extract candidate paths from assistant messages.
  # Use simplified character class (stop at whitespace) + sed to trim delimiters.
  local cited_paths
  cited_paths=$(grep -oE "(${prefix_pattern})[^[:space:]]*" \
    "$tmp_dir/messages.txt" 2>/dev/null \
    | sed 's/[^a-zA-Z0-9/_.-]*$//' \
    | sort -u || true)

  if [[ -z "$cited_paths" ]]; then
    echo "$violations"
    return
  fi

  # Collect all tool-call evidence: files read, written, edited, grepped
  local tool_evidence
  tool_evidence=$(cat \
    "$tmp_dir/written-files.txt" \
    "$tmp_dir/edited-files.txt" \
    "$tmp_dir/all-touched-files.txt" 2>/dev/null \
    | sort -u || true)

  # Also check bash commands for file references (grep, read, find, ls)
  local bash_evidence
  if [[ -f "$tmp_dir/bash-commands.txt" ]]; then
    bash_evidence=$(grep -oE "(${prefix_pattern})[^[:space:]]*" \
      "$tmp_dir/bash-commands.txt" 2>/dev/null \
      | sed 's/[^a-zA-Z0-9/_.-]*$//' \
      | sort -u || true)
  fi

  local all_evidence
  all_evidence=$( (echo "$tool_evidence"; echo "$bash_evidence") | sort -u)

  # Cross-reference: cited vs evidence
  while IFS= read -r cpath; do
    [[ -z "$cpath" ]] && continue

    # Check if the cited path exists in tool call evidence (exact line match)
    local found=false
    if echo "$all_evidence" | grep -qxF "$cpath" 2>/dev/null; then
      found=true
    fi

    # Fallback: check if the path exists on disk (may have been read by the
    # Read tool, which transcript-parser doesn't extract separately).
    # Only check paths that look like real filesystem paths (start with / or .)
    if [[ "$found" != "true" ]]; then
      if [[ "$cpath" =~ ^(/|\.) ]] && [[ -f "$cpath" ]]; then
        found=true
      fi
    fi

    if [[ "$found" != "true" ]]; then
      violations=$(echo "$violations" | jq -c \
        --arg rule "L3: 证据链断裂—引用路径未经验证" \
        --arg location "$cpath" \
        --arg fix "回复中引用了「${cpath}」但该路径未在工具调用历史中出现。请在引用前先 grep/read 验证路径存在，避免幻觉。" \
        '. + [{rule: $rule, location: $location, fix: $fix}]')
    fi
  done <<< "$cited_paths"

  echo "$violations"
}
