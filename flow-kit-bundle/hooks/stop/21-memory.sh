#!/bin/bash
# Module B — Memory Sync
# Checks: B1 (new discipline detection), B2 (discipline violation), B4 (duplicate detection)

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "21" || true

module_enabled "memory" || exit 0
[[ -d "$MEMORY_DIR" ]] || exit 0

# ═══════════════════════════════════════════════════════════════════
# B1: New discipline / memory detection
# ═══════════════════════════════════════════════════════════════════
check_b1_body() {

  local gotcha_file="$HOOK_TMP_DIR/gotcha-matches.txt"
  [[ -f "$gotcha_file" && -s "$gotcha_file" ]] || return 0

  # Look for "remember/记下来/教训" patterns
  local remember_lines
  remember_lines=$(grep -iE '(记住|记下来|教训|下次一定|以后要|以后不|规则)' "$gotcha_file" 2>/dev/null || true)
  [[ -n "$remember_lines" ]] || return 0

  # Check if similar memory already exists
  local count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local slug_candidate
    slug_candidate=$(echo "$line" | sed 's/^[0-9]*://' | tr -dc '[:alnum:] ' | cut -c1-60)
    [[ -z "$slug_candidate" ]] && continue

    # Check against existing memory files
    local exists
    exists=$(grep -rli "$slug_candidate" "$MEMORY_DIR"/*.md 2>/dev/null | head -1)
    if [[ -z "$exists" ]]; then
      count=$((count + 1))
      if [[ $count -le 3 ]]; then
        module_output "suggestion" "B1" "可能的新规则，建议创建 memory: \"$slug_candidate\""
      fi
    fi
  done <<< "$remember_lines"

  if [[ $count -gt 0 ]]; then
    module_output "info" "B1" "检测到 $count 条潜在新规则信号，建议 review"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# B2: Discipline violation detection
# ═══════════════════════════════════════════════════════════════════
check_b2_body() {

  # Load known discipline rules from memory files
  local violations=()

  # Rule: full test discipline — if src/*.ts changed but no tests ran
  if grep -q "全量测试" "$MEMORY_INDEX" 2>/dev/null; then
    local src_touched tests_ran
    src_touched=$(get_touched_source_files 2>/dev/null || true)
    tests_ran=$(cat "$HOOK_TMP_DIR/tests-ran" 2>/dev/null || echo "false")
    if [[ -n "$src_touched" && "$tests_ran" == "false" ]]; then
      module_output "warning" "B2" "违反纪律「全量测试」: src/*.ts 变更但未跑测试"
    fi
  fi

  # Rule: temp docs no git — check for plan/report files in git status
  if grep -q "临时文档不进 git" "$MEMORY_INDEX" 2>/dev/null; then
    if git_safe status --porcelain 2>/dev/null | grep -qE '^\?\? .*\.(patch|diff|todo)$|^\?\? .*plan.*\.md$'; then
      module_output "warning" "B2" "违反纪律「临时文档不进 git」: 检测到 plan/patch 文件未清理"
    fi
  fi

  # Rule: proposal before action — informational, can't really detect from transcript alone
  # Skipped — requires deeper semantic analysis

  # Rule: mount readonly default
  if grep -q "Mount readonly" "$MEMORY_INDEX" 2>/dev/null; then
    local mount_refs
    mount_refs=$(grep -c 'readonly\|additional_mounts\|containerPath' "$HOOK_TMP_DIR/messages.txt" 2>/dev/null || true)
    if [[ "${mount_refs:-0}" -gt 0 ]]; then
      module_output "info" "B2" "本 session 涉及 mount 配置，提醒「Mount readonly 默认值教训」: readonly 默认 true，必须显式设 false"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════
# B4: Duplicate memory detection
# ═══════════════════════════════════════════════════════════════════
check_b4_body() {

  # Check for memory files with very similar slugs
  local slugs
  slugs=$(ls "$MEMORY_DIR"/*.md 2>/dev/null | grep -v MEMORY.md | while read -r f; do
    basename "$f" .md | sed 's/^feedback_//;s/^project_//;s/^reference_//;s/^user_//' | tr '[:upper:]' '[:lower:]'
  done)

  # Simple heuristic: check for slug pairs with edit distance < 5
  # We use a simpler approach: check for common prefixes/suffixes
  local prev=""
  while IFS= read -r slug; do
    if [[ -n "$prev" ]]; then
      # Check if one contains the other or share long prefix
      if [[ "$slug" == "$prev"* || "$prev" == "$slug"* ]]; then
        module_output "suggestion" "B4" "可能的重复 memory: $prev ↔ $slug"
      fi
    fi
    prev="$slug"
  done <<< "$(echo "$slugs" | sort)"
}

check_b1() { run_check "memory" "B1" "gotcha-matches.txt" check_b1_body; }
check_b2() { run_check "memory" "B2" "" check_b2_body; }
check_b4() { run_check "memory" "B4" "" check_b4_body; }
# ── Run all checks ──────────────────────────────────────────────────
check_b1
check_b2
check_b4

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "21" || true
