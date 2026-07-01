#!/bin/bash
# correction-file.sh — Generic JSON correction file management
# Source this file: source "${HOOK_BASE_DIR}/lib/correction-file.sh"
#
# Provides four functions for reading/writing/clearing/checking JSON-based
# correction files. Both interactive-ui-check.sh and weak-model-compliance.sh
# source this lib instead of implementing their own correction file logic.
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

# Write/merge violations into a correction file atomically.
#
# Usage: correction_file_write <path> <json_data> <strategy>
#
# <strategy> controls dedup behavior:
#   "overwrite"            → replace entire file (for simple single-entry formats)
#   "field1,field2,..."    → merge with existing, dedup by named fields
#
# For merge mode, <json_data> must be a JSON object with the same shape as
# existing entries, or a JSON array of such objects. Dedup matches whole objects
# by the specified field subset.
#
# Returns: 0 on success, 1 on failure
correction_file_write() {
  local path="$1" data="$2" strategy="${3:-overwrite}"

  if [[ -z "$path" ]]; then
    echo "[correction-file] ERROR: path required" >&2
    return 1
  fi

  if [[ "$strategy" == "overwrite" ]]; then
    # Simple overwrite — no merge needed
    echo "$data" | jq '.' > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path" || {
      echo "[correction-file] ERROR: write failed for $path" >&2
      return 1
    }
    return 0
  fi

  # Merge mode: dedup by specified fields
  local IFS=','
  local dedup_fields
  read -ra dedup_fields <<< "$strategy"

  # Build jq filter for dedup: keep existing entries + new entry, unique by fields
  # Strategy: read existing (empty array if missing), append new, dedup
  local existing="[]"
  if [[ -f "$path" ]]; then
    existing=$(jq 'if type == "array" then . else [.] end' "$path" 2>/dev/null || echo "[]")
  fi

  # Normalize input to array
  local new_entries
  new_entries=$(echo "$data" | jq 'if type == "array" then . else [.] end' 2>/dev/null || echo "[]")

  # Merge: concatenate + unique by dedup fields
  local merged
  merged=$(jq -n --argjson existing "$existing" --argjson new "$new_entries" \
    '($existing + $new) | unique_by(.[$fields[]])' \
    --argjson fields "$(printf '[%s]' "$(IFS=,; for f in "${dedup_fields[@]}"; do echo "\"$f\""; done | tr '\n' ',' | sed 's/,$//')")" \
    2>/dev/null || echo "$existing")

  echo "$merged" | jq '.' > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path" || {
    echo "[correction-file] ERROR: merge-write failed for $path" >&2
    return 1
  }
  return 0
}

# Clear (delete) a correction file.
# Usage: correction_file_clear <path>
correction_file_clear() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  rm -f "$path"
  return 0
}
