#!/bin/bash
# Module D — Code Quality Guards
# Checks: D1 (test discipline), D2 (type check), D3 (build verify), D4 (lint)
#
# Detects when code changes weren't accompanied by appropriate quality
# checks (tests, typecheck, build, lint). All checks are non-blocking.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

module_enabled "quality" || exit 0

# ── Helpers ───────────────────────────────────────────────────────────

# Check if any source files under the given prefix were touched
src_touched() {
  local prefix="$1"
  [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]] || return 1
  grep -qE "^${prefix}" "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null
}

# Check if a command matching a pattern was run this session
cmd_ran() {
  local pattern="$1"
  [[ -f "$HOOK_TMP_DIR/bash-commands.txt" ]] || return 1
  grep -qiE "$pattern" "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null
}

# Count total changed lines (staged + unstaged) from git diff
count_changed_lines() {
  local total=0
  if git_safe rev-parse --git-dir >/dev/null 2>&1; then
    local n
    n=$(git_safe diff --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    total=$((total + n))
    n=$(git_safe diff --cached --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    total=$((total + n))
  fi
  echo "$total"
}

# ═══════════════════════════════════════════════════════════════════════
# D1: Test discipline — src changed but no test commands ran
# ═══════════════════════════════════════════════════════════════════════
check_d1() {
  check_enabled "quality" "D1" || return 0

  # Only flag if source files changed
  if ! src_touched "src/"; then
    return 0
  fi

  # Check if any test command was run
  local test_patterns=(
    'pnpm test\|pnpm exec vitest'
    'bun test\|bun:test'
    'vitest\|jest\|mocha'
    'pytest\|python.*test'
    'go test'
    'cargo test'
  )
  local ran=false
  for pat in "${test_patterns[@]}"; do
    if cmd_ran "$pat"; then
      ran=true
      break
    fi
  done

  if ! $ran; then
    local changed_src
    changed_src=$(grep -E '^src/' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null | head -5 | tr '\n' ' ')
    module_output "warning" "D1" "src/ 文件变更但未检测到测试执行。请运行 \`pnpm test\` 验证。
变更: ${changed_src}"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# D2: Type check reminder — .ts files changed but no typecheck
# ═══════════════════════════════════════════════════════════════════════
check_d2() {
  check_enabled "quality" "D2" || return 0

  # Check if TypeScript files changed
  local ts_changed=false
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    grep -qE '\.ts$' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null && ts_changed=true
  fi

  if ! $ts_changed; then
    return 0
  fi

  # Determine which typecheck command to suggest
  local tsc_cmd=""
  if src_touched "src/"; then
    tsc_cmd="pnpm exec tsc --noEmit"
  elif src_touched "container/agent-runner/src/"; then
    tsc_cmd="cd container/agent-runner && bun run typecheck"
  fi

  if [[ -z "$tsc_cmd" ]] || cmd_ran "tsc\|typecheck"; then
    return 0
  fi

  module_output "suggestion" "D2" "TypeScript 文件变更但未运行类型检查。建议: \`${tsc_cmd}\`"
}

# ═══════════════════════════════════════════════════════════════════════
# D3: Build verification — key files changed but no build
# ═══════════════════════════════════════════════════════════════════════
check_d3() {
  check_enabled "quality" "D3" || return 0

  # Key files that warrant a build check
  local key_patterns=(
    'Dockerfile'
    'package.json'
    'src/index.ts'
    'src/container-runner.ts'
    'container/agent-runner/src/index.ts'
  )

  local needs_build=false
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    for pat in "${key_patterns[@]}"; do
      if grep -qF "$pat" "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null; then
        needs_build=true
        break
      fi
    done
  fi

  if ! $needs_build; then
    return 0
  fi

  # Check if build was already run
  if grep -qiE '(pnpm build|pnpm run build|./container/build.sh)' "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null; then
    return 0
  fi

  # Determine correct build command
  local build_cmd="pnpm run build"
  if grep -qF 'container/' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null; then
    build_cmd+=" && ./container/build.sh"
  fi

  module_output "warning" "D3" "关键文件变更但未构建。建议: \`${build_cmd}\`"
}

# ═══════════════════════════════════════════════════════════════════════
# D4: Lint detection — lots of code changes but no lint
# ═══════════════════════════════════════════════════════════════════════
check_d4() {
  check_enabled "quality" "D4" || return 0

  local changed_lines
  changed_lines=$(count_changed_lines)

  # Threshold: only flag if >50 lines changed
  if [[ "$changed_lines" -lt 50 ]]; then
    return 0
  fi

  # Check if lint/prettier was run
  if cmd_ran "lint\|prettier\|eslint\|biome check\|biome lint"; then
    return 0
  fi

  module_output "suggestion" "D4" "大量代码变更 (${changed_lines}+ 行) 未运行 lint。建议: \`pnpm exec prettier --check .\` 或 \`pnpm lint\`"
}

# ── Run all checks ──────────────────────────────────────────────────
check_d1
check_d2
check_d3
check_d4
