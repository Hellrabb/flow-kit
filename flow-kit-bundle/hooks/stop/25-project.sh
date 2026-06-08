#!/bin/bash
# Module F — Project-Specific Guards
# Checks: F1 (container build cache), F2 (package manager supply chain),
#         F3 (DB migration detection), F4 (hook conflicts), F5 (worktree residue)
#
# All checks are "detect-then-check": they first probe whether the project
# actually uses the relevant technology, and silently skip if not.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

module_enabled "project" || exit 0

# ═══════════════════════════════════════════════════════════════════════
# F1: Container build cache reminder
# Detects: container/ dir OR Dockerfile* OR docker-compose*.yml at project root
# ═══════════════════════════════════════════════════════════════════════
check_f1() {
  check_enabled "project" "F1" || return 0

  # Detect containerized project
  local has_container=false
  if [[ -d "${PROJECT_ROOT}/container" ]] ||
     compgen -G "${PROJECT_ROOT}/Dockerfile*" >/dev/null 2>&1 ||
     compgen -G "${PROJECT_ROOT}/docker-compose"* >/dev/null 2>&1; then
    has_container=true
  fi

  if ! $has_container; then
    return 0
  fi

  # Check if build-related files were touched this session
  local build_changed=false
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    if grep -qE '(^container/|Dockerfile|docker-compose)' "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null; then
      build_changed=true
    fi
  fi

  if ! $build_changed; then
    return 0
  fi

  # Check if container build was actually run
  if grep -qiE '(docker build|docker compose build|podman build|nerdctl build|./container/build)' \
       "$HOOK_TMP_DIR/bash-commands.txt" 2>/dev/null; then
    module_output "info" "F1" "Container 构建已执行 ✓"
    return 0
  fi

  module_output "warning" "F1" "容器相关文件变更但未检测到构建命令。
BuildKit 缓存可能保留过期文件。如需干净构建:
  docker builder prune -f && docker build -t <image> ."
}

# ═══════════════════════════════════════════════════════════════════════
# F2: Package manager supply chain check
# Detects: lockfile presence → infers package manager, applies relevant checks
# ═══════════════════════════════════════════════════════════════════════
check_f2() {
  check_enabled "project" "F2" || return 0

  # Detect package manager by lockfile
  local pm="" lockfile="" workspace_file=""
  if [[ -f "${PROJECT_ROOT}/pnpm-lock.yaml" ]]; then
    pm="pnpm"; lockfile="pnpm-lock.yaml"
    workspace_file="pnpm-workspace.yaml"
  elif [[ -f "${PROJECT_ROOT}/yarn.lock" ]]; then
    pm="yarn"; lockfile="yarn.lock"
  elif [[ -f "${PROJECT_ROOT}/package-lock.json" ]]; then
    pm="npm"; lockfile="package-lock.json"
  elif [[ -f "${PROJECT_ROOT}/bun.lock" ]] || [[ -f "${PROJECT_ROOT}/bun.lockb" ]]; then
    pm="bun"
    compgen -G "${PROJECT_ROOT}/bun.lock*" >/dev/null 2>&1 && lockfile="bun.lock"
  fi

  if [[ -z "$pm" ]]; then
    return 0  # No recognized JS/TS package manager
  fi

  # Check if dependency files changed
  local deps_changed=false
  if [[ -f "$HOOK_TMP_DIR/all-touched-files.txt" ]]; then
    if grep -qE "(package.json|${lockfile})" "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null; then
      deps_changed=true
    fi
    [[ -n "$workspace_file" ]] && \
      grep -q "$workspace_file" "$HOOK_TMP_DIR/all-touched-files.txt" 2>/dev/null && deps_changed=true
  fi

  if ! $deps_changed; then
    return 0
  fi

  # Generic supply-chain warning for any package manager
  local audit_cmd="${pm} audit"
  [[ "$pm" != "pnpm" ]] && audit_cmd="${pm} audit --production"

  module_output "info" "F2" "依赖文件变更 (${pm})。
请确认新增/更新的依赖来自可信来源。审计命令:
  ${audit_cmd}"

  # pnpm-specific: workspace security checks
  if [[ "$pm" = "pnpm" && -n "$workspace_file" && -f "${PROJECT_ROOT}/${workspace_file}" ]]; then
    local diff_output
    diff_output=$(git_safe diff HEAD -- "$workspace_file" 2>/dev/null || true)

    if echo "$diff_output" | grep -q 'onlyBuiltDependencies'; then
      module_output "warning" "F2" "⚠️ pnpm-workspace.yaml 中 onlyBuiltDependencies 变更。
构建脚本在 install 时执行任意代码 — 请确认每个新增条目都是可信的。"
    fi

    if echo "$diff_output" | grep -q 'minimumReleaseAgeExclude'; then
      module_output "error" "F2" "🚨 pnpm-workspace.yaml 中 minimumReleaseAgeExclude 变更。
绕过发布冷静期需明确批准。请确认此变更已获授权。"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# F3: DB migration detection
# Detects: */migrations/ OR */migrate/ directories, then checks naming conventions
# ═══════════════════════════════════════════════════════════════════════
check_f3() {
  check_enabled "project" "F3" || return 0

  if ! git_safe rev-parse --git-dir >/dev/null 2>&1; then
    return 0
  fi

  # Auto-detect migration directories (common patterns across frameworks)
  local migration_dirs
  migration_dirs=$(git_safe ls-files --cached --others --exclude-standard 2>/dev/null | \
    grep -E '(migrations?/|migrate/)' | sed 's|/[^/]*$||' | sort -u | head -5 || true)

  if [[ -z "$migration_dirs" ]]; then
    return 0
  fi

  # Detect migration file conventions from existing files
  local naming_pattern
  # Try common patterns: NNNN-name.ext, timestamp_name.ext, name.ext
  if git_safe ls-files 2>/dev/null | grep -qE 'migrations?/[0-9]{4}-.*\.(ts|js|sql|py|rb)'; then
    naming_pattern='^[0-9]{4}-.*\.(ts|js|sql|py|rb)$'
  elif git_safe ls-files 2>/dev/null | grep -qE 'migrations?/[0-9]+_.*\.(ts|js|sql|py|rb)'; then
    naming_pattern='^[0-9]+_.*\.(ts|js|sql|py|rb)$'
  else
    naming_pattern=""  # Can't determine convention, skip naming check
  fi

  # Find new migration files in this session
  local new_migrations
  new_migrations=$(git_safe diff --name-only --diff-filter=A HEAD 2>/dev/null | \
    grep -E '(migrations?/|migrate/)' || true)

  if [[ -z "$new_migrations" ]]; then
    return 0
  fi

  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    local fname
    fname=$(basename "$m")

    # Naming convention check (only if we detected a pattern)
    if [[ -n "$naming_pattern" ]]; then
      if ! echo "$fname" | grep -qE "$naming_pattern"; then
        module_output "warning" "F3" "Migration 命名可能不符合项目惯例: \`${fname}\`
检测到惯例: \`${naming_pattern}\` — 请确认命名是否符合项目规范。"
      fi
    fi

    module_output "info" "F3" "新 migration: \`${m}\` — 确保有对应测试或回滚方案"
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
