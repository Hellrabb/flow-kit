#!/bin/bash
# Module F — Project-Specific Guards (NanoClaw)
# Checks: F1 (container build cache), F2 (pnpm supply chain),
#         F3 (migration detection), F4 (hook conflicts), F5 (worktree residue)
#
# NanoClaw-specific hygiene checks that depend on project structure knowledge.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

module_enabled "project" || exit 0

# ═══════════════════════════════════════════════════════════════════════
# F1: Container build cache reminder
# ═══════════════════════════════════════════════════════════════════════
check_f1() {
  check_enabled "project" "F1" || return 0

  # Check if container/ files were modified
  local container_changed=false
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    grep -qE '^container/' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null && container_changed=true
  fi

  if ! $container_changed; then
    return 0
  fi

  # Check if container build was run
  if grep -qiE './container/build.sh' "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null; then
    module_output "info" "F1" "Container 构建已执行 ✓"
    return 0
  fi

  module_output "warning" "F1" "container/ 文件变更但未重建镜像。
BuildKit 缓存可能保留过期文件。如需干净构建:
  docker builder prune -f && ./container/build.sh"
}

# ═══════════════════════════════════════════════════════════════════════
# F2: pnpm supply chain check
# ═══════════════════════════════════════════════════════════════════════
check_f2() {
  check_enabled "project" "F2" || return 0

  # Check if package.json changed
  local pkg_changed=false
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    grep -qE '(package.json|pnpm-lock.yaml|pnpm-workspace.yaml)' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null && pkg_changed=true
  fi

  if ! $pkg_changed; then
    return 0
  fi

  # Check for new onlyBuiltDependencies entries (security-sensitive)
  local diff_output
  diff_output=$(git_safe diff HEAD -- pnpm-workspace.yaml 2>/dev/null || true)

  if echo "$diff_output" | grep -q 'onlyBuiltDependencies'; then
    module_output "warning" "F2" "⚠️ pnpm-workspace.yaml 中 onlyBuiltDependencies 变更。
构建脚本在 install 时执行任意代码 — 请确认每个新增条目都是可信的。
参考 CLAUDE.md: Supply Chain Security 部分。"
  fi

  # Check for new minimumReleaseAgeExclude entries
  if echo "$diff_output" | grep -q 'minimumReleaseAgeExclude'; then
    module_output "error" "F2" "🚨 pnpm-workspace.yaml 中 minimumReleaseAgeExclude 变更。
绕过 3 天发布冷静期需人类明确批准。请确认此变更已获授权。
参考 CLAUDE.md: 不得在无人类签署下添加条目。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# F3: Migration detection
# ═══════════════════════════════════════════════════════════════════════
check_f3() {
  check_enabled "project" "F3" || return 0

  # Check for new migration files
  local new_migrations
  if ! git_safe rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi

  new_migrations=$(git_safe diff --name-only --diff-filter=A HEAD 2>/dev/null | grep 'src/db/migrations/' || true)
  if [[ -z "$new_migrations" ]]; then
    return 0
  fi

  while IFS= read -r m; do
    local fname
    fname=$(basename "$m")

    # Naming convention check: NNNN-description.ts
    if ! echo "$fname" | grep -qE '^[0-9]{4}-.*\.ts$'; then
      module_output "error" "F3" "Migration 命名不规范: \`${fname}\`
要求格式: \`NNNN-description.ts\` (例: 0007-add-foo-table.ts)"
    fi

    module_output "info" "F3" "新 migration: \`${fname}\` — 确保有对应测试"
  done <<< "$new_migrations"
}

# ═══════════════════════════════════════════════════════════════════════
# F4: Hook conflict detection
# ═══════════════════════════════════════════════════════════════════════
check_f4() {
  check_enabled "project" "F4" || return 0

  local settings_file="${PROJECT_ROOT}/.claude/settings.json"
  if [[ ! -f "$settings_file" ]]; then
    return 0
  fi

  # Check if settings.json was modified this session
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    if ! grep -q '.claude/settings.json' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null; then
      return 0
    fi
  else
    return 0
  fi

  # Check for duplicate Stop hook matchers
  local stop_count
  stop_count=$(jq '[.hooks.Stop // [][].matcher] | length' "$settings_file" 2>/dev/null || echo "0")

  if [[ "$stop_count" -gt 1 ]]; then
    module_output "warning" "F4" "检测到 ${stop_count} 个 Stop hook matcher。
多个 matcher 可能导致重复执行。检查 .claude/settings.json → hooks.Stop"
  fi

  # Check for overlapping SessionStart matchers
  local ss_count
  ss_count=$(jq '[.hooks.SessionStart // [][].matcher] | length' "$settings_file" 2>/dev/null || echo "0")
  if [[ "$ss_count" -gt 2 ]]; then
    module_output "warning" "F4" "检测到 ${ss_count} 个 SessionStart hook matcher。确认没有冲突。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# F5: Worktree residue detection
# ═══════════════════════════════════════════════════════════════════════
check_f5() {
  check_enabled "project" "F5" || return 0

  if ! git_safe rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi

  # Check .claude/worktrees/ directory
  local wt_dir="${PROJECT_ROOT}/.claude/worktrees"
  if [[ ! -d "$wt_dir" ]]; then
    return 0
  fi

  # List stale worktrees
  local stale=()
  for wt in "$wt_dir"/*/; do
    [[ -d "$wt" ]] || continue
    local wt_name
    wt_name=$(basename "$wt")

    # Check if this worktree still appears in git worktree list
    if ! git_safe worktree list 2>/dev/null | grep -q "$wt_name"; then
      stale+=("$wt_name")
    fi
  done

  if [[ ${#stale[@]} -gt 0 ]]; then
    local stale_list
    stale_list=$(printf '%s, ' "${stale[@]}" | sed 's/, $//')
    module_output "suggestion" "F5" "发现 ${#stale[@]} 个残留 worktree 目录: ${stale_list}
建议清理: \`git worktree remove <name>\` 或手动 \`rm -rf .claude/worktrees/<name>\`"
  fi

  # Also check git worktree list for stale entries
  local git_wt_count
  git_wt_count=$(git_safe worktree list 2>/dev/null | grep -c -v '(bare)' || true)
  if [[ "${git_wt_count:-0}" -gt 2 ]]; then
    module_output "info" "F5" "当前有 ${git_wt_count} 个 git worktree。考虑清理不再使用的: \`git worktree list\`"
  fi
}

# ── Run all checks ──────────────────────────────────────────────────
check_f1
check_f2
check_f3
check_f4
check_f5
