#!/bin/bash
# runtime-adapter.sh — flow-kit runtime/platform decoupling layer.
#
# One source of truth for "which platform are the hooks running under".
# The shell hook chain itself stays unchanged; this file only decides where
# project/user config, memory and the project markdown file live.
#
# Detection order (first hit wins):
#   1. FLOW_KIT_RUNTIME explicitly set by the host (dsh plugin sets "dsh";
#      opencode-claude-hooks may set "opencode")
#   2. OPENCODE_BIN / OPENCODE non-empty  → opencode
#   3. default                            → claude (legacy, zero-regression)
#
# Exposed functions (all pure queries, no side effects):
#   fk_runtime_detect                      prints dsh|opencode|claude
#   fk_platform_is_dsh                     rc 0 = dsh
#   fk_platform_is_opencode                rc 0 = opencode
#   fk_platform_prefers_flowkit_credentials rc 0 = dsh|opencode (FLOW_KIT_L3_* first)
#   fk_runtime_config_dir                  prints .flow-kit (dsh) | .claude (legacy)
#   fk_runtime_home_dir                    prints $HOME/.dsh (dsh) | $HOME/.claude (legacy)
#   fk_runtime_md_file                     prints AGENTS.md (dsh) | CLAUDE.md (legacy)
#   fk_runtime_memory_dir <project_root>   prints memory dir for the active runtime
#
# All functions are `set -u` safe and tolerate being sourced multiple times.

set -euo pipefail

fk_runtime_detect() {
  case "${FLOW_KIT_RUNTIME:-}" in
    dsh|opencode|claude) echo "$FLOW_KIT_RUNTIME" ;;
    *)
      if [ -n "${OPENCODE_BIN:-}" ] || [ -n "${OPENCODE:-}" ]; then
        echo "opencode"
      else
        echo "claude"
      fi
      ;;
  esac
}

fk_platform_is_dsh() {
  [ "$(fk_runtime_detect)" = "dsh" ]
}

# Kept for backward compatibility with the l2l3-cross-platform change: the
# opencode branch keeps its exact semantics (OPENCODE_BIN / OPENCODE signals).
fk_platform_is_opencode() {
  [ "$(fk_runtime_detect)" = "opencode" ]
}

# dsh and opencode both prefer the FLOW_KIT_L3_* first-class path over the
# Claude-native ANTHROPIC_* path; claude keeps Path1 first (zero regression).
fk_platform_prefers_flowkit_credentials() {
  fk_platform_is_dsh || fk_platform_is_opencode
}

fk_runtime_config_dir() {
  if fk_platform_is_dsh; then
    echo ".flow-kit"
  else
    echo ".claude"
  fi
}

fk_runtime_home_dir() {
  if fk_platform_is_dsh; then
    echo "${HOME}/.dsh"
  else
    echo "${HOME}/.claude"
  fi
}

fk_runtime_md_file() {
  if fk_platform_is_dsh; then
    echo "AGENTS.md"
  else
    echo "CLAUDE.md"
  fi
}

# Memory dir: Claude Code convention is $HOME/.claude/projects<slug>/memory.
# dsh keeps the same layout under $HOME/.dsh/projects<slug>/memory.
fk_runtime_memory_dir() {
  local project_root="${1:-$PWD}"
  local slug
  slug=$(echo "${project_root}" | tr '/' '-')
  echo "$(fk_runtime_home_dir)/projects${slug}/memory"
}
