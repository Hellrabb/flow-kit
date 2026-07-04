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
