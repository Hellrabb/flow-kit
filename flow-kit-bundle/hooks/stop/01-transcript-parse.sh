#!/bin/bash
# 01-transcript-parse.sh — Parse transcript JSONL into structured data files
# Writes extracted data to $HOOK_TMP_DIR for downstream modules to consume.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "01" || true
source "${HOOK_BASE_DIR}/lib/transcript-parser.sh"

if [[ -z "${TRANSCRIPT_PATH:-}" ]]; then
  echo "SKIP: no TRANSCRIPT_PATH" >> "$HOOK_TMP_DIR/module-errors.log"
  exit 0
fi

parse_transcript || {
  echo "SKIP: transcript parse failed" >> "$HOOK_TMP_DIR/module-errors.log"
  exit 0
}

echo "transcript parsed: $(line_count "$HOOK_TMP_DIR/tool-calls.txt") tool calls" >> "$HOOK_TMP_DIR/run.log"

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "01" || true
