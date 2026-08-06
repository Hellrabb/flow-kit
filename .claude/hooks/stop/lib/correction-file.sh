#!/bin/bash
# correction-file.sh — Generic JSON correction file management
# Source this file: source "${HOOK_BASE_DIR}/lib/correction-file.sh"
#
# Provides four functions for reading/writing/clearing/checking JSON-based
# correction files. This is a LEAF module — it depends on no other lib modules.
# Callers (interactive-ui-check.sh, weak-model-compliance.sh) source this lib
# for unified correction file I/O.
#
# NOTE: Does NOT set -euo pipefail — this is a library, sourced by callers.
# Callers are responsible for shell flags.

# Check if a correction file exists and contains valid JSON.
# Usage: correction_file_exists <path>
# Returns: 0 (file exists + valid JSON), 1 otherwise
correction_file_exists() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  [[ -f "$path" ]] && jq empty "$path" 2>/dev/null
}

# Read a correction file. Outputs JSON to stdout.
# Returns "{}" if the file doesn't exist.
# Usage: correction_file_read <path>
correction_file_read() {
  local path="$1"
  if [[ -z "$path" || ! -f "$path" ]]; then
    echo "{}"
    return 0
  fi
  cat "$path"
}

# Write a correction file atomically.
#
# Usage: correction_file_write <path> <json_data> [strategy]
#
# Strategies:
#   overwrite (default) — Replace file contents atomically (tmp + mv).
#   merge               — Read existing violations, dedupe by gate_type+tool,
#                          append new entries, write back atomically.
#                          New data must be a JSON object with a "violations"
#                          array containing objects with "gate_type" and "tool"
#                          (and optionally "required_tool").
#
# Returns: 0 on success, 1 on failure
correction_file_write() {
  local path="$1" data="$2" strategy="${3:-overwrite}"

  if [[ -z "$path" ]]; then
    echo "[correction-file] ERROR: path required" >&2
    return 1
  fi

  case "$strategy" in
    merge)
      # Merge violations: read existing, combine with new, dedupe by full object comparison.
      # Preserve all top-level fields from the new data (type, written_at, etc.).
      local existing_violations new_entries merged
      existing_violations=$(jq -c '.violations // []' "$path" 2>/dev/null || echo "[]")
      new_entries=$(echo "$data" | jq -c '.violations // []' 2>/dev/null || echo "[]")
      # Use new data as base, merge violations from both sources
      merged=$(echo "$data" | jq --argjson existing "$existing_violations" --argjson new "$new_entries" '
        .violations = ($existing + $new | unique)
      ')
      echo "$merged" | jq '.' > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path" || {
        echo "[correction-file] ERROR: merge write failed for $path" >&2
        return 1
      }
      ;;
    overwrite|*)
      # Atomic overwrite: write to tmp then mv
      echo "$data" | jq '.' > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path" || {
        echo "[correction-file] ERROR: write failed for $path" >&2
        return 1
      }
      ;;
  esac
}

# Clear (delete) a correction file.
# Usage: correction_file_clear <path>
correction_file_clear() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  rm -f "$path"
  return 0
}

# ── Model-missing correction (l2-l3-model-config, ADR-012/013) ──────────
# write_model_missing_correction <layer> — write a {type,layer,message} correction
# when L2/L3 review model is unconfigured (graceful degradation marker).
# compliance-priority (ADR-013): if current correction is `compliance` with
# violations, do NOT overwrite (preserve safety info for non-CC users).
# Atomic write: single jq conditional pass → mktemp tmp → mv. 单步 jq 消除
# Check-Then-Act TOCTOU（DESIGN §4.1）；mktemp XXXXXX 消除 fixed-tmp-name race
# （L2 phase 7 R1 修复，对齐 l2-detect.sh:143）。Schema distinct from 既有
# `l2-missing` (= L2 盲审段缺失).
write_model_missing_correction() {
  local layer="$1"
  local path="${PROJECT_ROOT:-}/.flow-active.correction"
  local mtype message new_json
  case "$layer" in
    L3) mtype="l3-model-missing"; message="L3 审查模型未配置。设置：export FLOW_KIT_L3_MODEL=<模型> 或 /flow model l3=<模型>" ;;
    L2) mtype="l2-model-missing"; message="L2 审查模型未配置。设置：export FLOW_KIT_L2_MODEL=<模型> 或 /flow model l2=<模型>" ;;
    *) echo "[correction-file] ERROR: invalid layer '$layer' (expect L2|L3)" >&2; return 1 ;;
  esac
  new_json=$(jq -nc --arg t "$mtype" --arg l "$layer" --arg m "$message" \
    '{type:$t, layer:$l, message:$m}')

  if correction_file_exists "$path"; then
    # Compliance-priority conditional write: single jq pass → mktemp tmp → mv.
    # mktemp XXXXXX 消除 fixed-tmp-name race（并发会话/--background 异步路径互覆
    # 对方半截 JSON）——对齐 l2-detect.sh:143 既有正确模式（gate-review-fix 教训）。
    local tmp; tmp=$(mktemp "${path}.tmp.XXXXXX") || { echo "[correction-file] WARN: mktemp failed for model-missing" >&2; return 1; }
    if jq --argjson new "$new_json" \
        'if .type=="compliance" and ((.violations // []) | length > 0) then . else $new end' \
        "$path" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$path"
    else
      rm -f "$tmp"
      echo "[correction-file] WARN: model-missing write failed (jq parse or IO)" >&2
    fi
  else
    correction_file_write "$path" "$new_json" overwrite
  fi
}

# write_model_missing_clear <layer> — clear the model-missing correction for a
# layer (called on normal path when model is configured, AC-6 退场). Only
# removes the file if current type matches (preserves compliance/l2-missing/other).
write_model_missing_clear() {
  local layer="$1"
  local path="${PROJECT_ROOT:-}/.flow-active.correction"
  [[ -f "$path" ]] || return 0
  local mtype cur_type
  case "$layer" in
    L3) mtype="l3-model-missing" ;;
    L2) mtype="l2-model-missing" ;;
    *) return 1 ;;
  esac
  cur_type=$(jq -r '.type // ""' "$path" 2>/dev/null || echo "")
  [[ "$cur_type" == "$mtype" ]] && rm -f "$path"
  return 0
}
