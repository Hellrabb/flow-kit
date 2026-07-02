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

# Write a correction file atomically (overwrite strategy).
#
# Usage: correction_file_write <path> <json_data> [strategy]
#
# Only "overwrite" strategy is currently supported (all callers use it).
# The strategy parameter is reserved for future use (e.g. merge-dedup).
#
# Returns: 0 on success, 1 on failure
correction_file_write() {
  local path="$1" data="$2"

  if [[ -z "$path" ]]; then
    echo "[correction-file] ERROR: path required" >&2
    return 1
  fi

  # Atomic overwrite: write to tmp then mv
  echo "$data" | jq '.' > "${path}.tmp" 2>/dev/null && mv "${path}.tmp" "$path" || {
    echo "[correction-file] ERROR: write failed for $path" >&2
    return 1
  }
}

# Clear (delete) a correction file.
# Usage: correction_file_clear <path>
correction_file_clear() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  rm -f "$path"
  return 0
}
