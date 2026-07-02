#!/bin/bash
# 00-gate.sh — Subagent isolation gate + environment initialization
# Runs first in the stop hook chain. Reads stdin, gates subagents, sets up env.

set -euo pipefail

HOOK_BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HOOK_BASE_DIR}/lib/common.sh"

# ── Read stdin and initialize ───────────────────────────────────────
hook_init

# ── Initialize paths (must be after hook_init — depends on CWD) ──────
init_paths

# ── Gate: Subagent Isolation ────────────────────────────────────────
# Claude Code official: Stop hook fires for main sessions only in practice,
# but SubagentStop event exists and parent_session_id is present on subagent
# stop payloads. This gate is defensive — if future scheduling changes,
# this prevents subagent events from leaking into our stop hook logic.
if is_subagent; then
  exit 0
fi

# ── Gate: No transcript no analysis ─────────────────────────────────
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# ── Gate: Config file must exist ────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# ── Gate: Project root must be valid ────────────────────────────────
if [[ ! -d "$PROJECT_ROOT" ]]; then
  exit 0
fi

# ── Export constants for downstream scripts ─────────────────────────
export HOOK_BASE_DIR CONFIG_FILE HOOK_TMP_DIR
# PROJECT_ROOT et al. exported by init_paths()

# ── Update state counter ────────────────────────────────────────────
# Track stop count for AI frequency gating
mkdir -p "$(dirname "$STATE_FILE")"
count=0
if [[ -f "$STATE_FILE" ]]; then
  count=$(jq -r '.stop_count // 0' "$STATE_FILE" 2>/dev/null || echo "0")
fi
count=$((count + 1))
jq -n --argjson count "$count" \
  --arg last_stop "$(date -Iseconds)" \
  '{stop_count: $count, last_stop: $last_stop}' > "$STATE_FILE"

export STOP_COUNT=$count

# ── Execute downstream modules ──────────────────────────────────────
# Modules are sourced in order. Each module writes findings to HOOK_TMP_DIR.
# Exit codes from modules are non-fatal — report generation always runs.

run_module() {
  local script="$1" name="$2"
  if [[ ! -x "$script" ]]; then
    chmod +x "$script" 2>/dev/null || true
  fi
  if [[ -f "$script" ]]; then
    timeout 120 bash "$script" >> "$HOOK_TMP_DIR/module-errors.log" 2>&1 || true
  fi
}

echo "stop_hook start: count=$STOP_COUNT session=$SESSION_ID" > "$HOOK_TMP_DIR/run.log"

# 01 — Parse transcript (foundation for all modules)
run_module "${HOOK_BASE_DIR}/01-transcript-parse.sh" "transcript"

# 20 — Module A: CLAUDE.md management
run_module "${HOOK_BASE_DIR}/20-claude-md.sh" "claude-md"

# 21 — Module B: Memory sync
run_module "${HOOK_BASE_DIR}/21-memory.sh" "memory"

# 22 — Module C: Git hygiene
run_module "${HOOK_BASE_DIR}/22-git.sh" "git"

# 23 — Module D: Code quality guards
run_module "${HOOK_BASE_DIR}/23-quality.sh" "quality"

# 24 — Module E: Session analysis
run_module "${HOOK_BASE_DIR}/24-session.sh" "session"

# 25 — Module F: Project-specific guards
run_module "${HOOK_BASE_DIR}/25-project.sh" "project"

# 26 — Module G: Workflow state
run_module "${HOOK_BASE_DIR}/26-workflow.sh" "workflow"

# 27 — Module: Interactive UI check (weak-model guard)
run_module "${HOOK_BASE_DIR}/27-interactive-ui-check.sh" "interactive-ui-check"

# 28 — Module: Weak model compliance (L1/L2/L3 post-hoc verification)
run_module "${HOOK_BASE_DIR}/28-weak-model-compliance.sh" "weak-model-compliance"

# 29 — Module: Independent review L3 (external model audit)
run_module "${HOOK_BASE_DIR}/29-independent-review.sh" "independent-review"

# 30 — AI deep analysis (frequency-gated)
run_module "${HOOK_BASE_DIR}/30-ai-analyze.sh" "ai-analyze"

# 99 — Report generation
run_module "${HOOK_BASE_DIR}/99-report.sh" "report"

# ── Cleanup temp dir (keep if debug env var set) ────────────────────
if [[ -z "${STOP_HOOK_DEBUG:-}" ]]; then
  rm -rf "$HOOK_TMP_DIR"
fi

exit 0
