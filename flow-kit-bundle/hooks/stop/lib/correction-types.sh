#!/bin/bash
# correction-types.sh — Shared correction type constants / type definitions
# Source this file: source "${HOOK_BASE_DIR}/lib/correction-types.sh"
#
# This file is a ZERO-DEPENDENCY leaf module — it sources no other lib files.
# It exists solely to break the bidirectional dependency cycle among:
#   correction-file.sh ↔ interactive-ui-check.sh ↔ weak-model-compliance.sh
#
# All three modules now source this file for shared constants, while continuing
# to use correction-file.sh for I/O functions (write/read/clear/exists).
#
# Phase 0（change）and Phase 4（dev）currently have no independent review gate;
# they are intentionally excluded from PHASE_GATE_KEY_MAP. If a gate is added
# in the future, all four layers must be updated: PRESET_MAP + Prompt template
# + L2-blind-review.md checklist + this MAP.
#
# NOTE: Does NOT set -euo pipefail — this is a sourced library.

# Correction file type constants
readonly CORRECTION_TYPE_COMPLIANCE="compliance"
readonly CORRECTION_TYPE_INTERACTIVE_UI="interactive-ui"
readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"

# Maximum retry count before stopping automatic correction injection
readonly CORRECTION_MAX_RETRY=2
