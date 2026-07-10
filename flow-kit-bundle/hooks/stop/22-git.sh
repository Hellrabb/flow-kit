#!/bin/bash
# Module C — Git Hygiene
# Checks: C1 (status summary), C2 (large files), C3 (commit suggestion), C4 (secrets detection)

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

module_enabled "git" || exit 0

# Ensure we're in a git repo
git_safe rev-parse --git-dir >/dev/null 2>&1 || exit 0

# ═══════════════════════════════════════════════════════════════════
# C1: Git status summary
# ═══════════════════════════════════════════════════════════════════
check_c1_body() {

  local status
  status=$(git_safe status --porcelain 2>/dev/null || true)

  if [[ -z "$status" ]]; then
    module_output "info" "C1" "工作区干净 ✓"
    return 0
  fi

  # Categorize changes
  local modified=0 added=0 deleted=0 untracked=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local x="${line:0:2}"
    case "$x" in
      "??") untracked=$((untracked + 1)) ;;
      " D"|"D ") deleted=$((deleted + 1)) ;;
      "A "|"AM"|"A?") added=$((added + 1)) ;;
      *) modified=$((modified + 1)) ;;
    esac
  done <<< "$status"

  local summary="M:${modified} A:${added} D:${deleted} ?:${untracked}"
  module_output "info" "C1" "Git 状态: $summary"

  # List modified files (max 10)
  local file_list
  file_list=$(echo "$status" | grep -v '^??' | head -10 | while IFS= read -r line; do
    echo "  $(echo "$line" | cut -c4-)"
  done)
  if [[ -n "$file_list" ]]; then
    module_output "info" "C1" "变更文件:
${file_list}"
  fi

  # Untracked files (max 5)
  local untracked_list
  untracked_list=$(echo "$status" | grep '^??' | head -5 | while IFS= read -r line; do
    echo "  $(echo "$line" | cut -c4-)"
  done)
  if [[ -n "$untracked_list" ]]; then
    module_output "info" "C1" "未跟踪文件:
${untracked_list}"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# C2: Large / suspicious file warnings
# ═══════════════════════════════════════════════════════════════════
check_c2_body() {

  local max_bytes
  max_bytes=$(config_get '.thresholds.large_file_bytes' "1048576")

  local status untracked_files
  status=$(git_safe status --porcelain 2>/dev/null || true)
  untracked_files=$(echo "$status" | grep '^??' | cut -c4- || true)

  local warns=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local sz
    sz=$(stat -c %s "$PROJECT_ROOT/$f" 2>/dev/null || stat -f %z "$PROJECT_ROOT/$f" 2>/dev/null || echo "0")

    # Large file check
    if [[ "$sz" -gt "$max_bytes" ]]; then
      local sz_human
      sz_human=$(du -h "$PROJECT_ROOT/$f" 2>/dev/null | cut -f1 || echo "${sz}B")
      module_output "warning" "C2" "大文件未跟踪: \`$f\` (${sz_human})，确认不应加入 .gitignore?"
      warns=$((warns + 1))
    fi

    # Suspicious patterns (node_modules, .env, keys, etc.)
    case "$f" in
      *.env|*.key|*.pem|*.pfx|*.p12|id_rsa*|*secret*|*credential*)
        module_output "error" "C2" "🚨 敏感文件: \`$f\` — 切勿提交！加入 .gitignore"
        warns=$((warns + 1))
        ;;
      node_modules/*|*.pyc|__pycache__/*|*.log)
        module_output "warning" "C2" "应忽略的文件: \`$f\` — 建议加入 .gitignore"
        warns=$((warns + 1))
        ;;
    esac
  done <<< "$untracked_files"
}

# ═══════════════════════════════════════════════════════════════════
# C3: Auto-generate conventional commit suggestion
# ═══════════════════════════════════════════════════════════════════
check_c3_body() {

  local status
  status=$(git_safe status --porcelain 2>/dev/null || true)
  [[ -n "$status" ]] || return 0

  # Determine commit type based on changed files
  local commit_type="chore"
  local scope=""

  # Check file paths to infer type
  if echo "$status" | grep -qE '(test|spec)\.(ts|js|py)'; then
    commit_type="test"
    scope=""
  elif echo "$status" | grep -q '^ M.*\.md$'; then
    commit_type="docs"
    scope=""
  elif echo "$status" | grep -q 'src/'; then
    commit_type="feat"
    scope=""
  elif echo "$status" | grep -q 'container/'; then
    commit_type="fix"
    scope="container"
  fi

  # Determine scope from path prefix
  if echo "$status" | grep -q 'src/db/'; then
    scope="db"
  elif echo "$status" | grep -q 'src/cli/'; then
    scope="cli"
  elif echo "$status" | grep -q 'src/channels/'; then
    scope="channels"
  fi

  # Count changed files
  local file_count
  file_count=$(echo "$status" | wc -l)

  # Build suggestion
  local scope_str=""
  [[ -n "$scope" ]] && scope_str="($scope)"

  local suggestion="${commit_type}${scope_str}: "

  # Crude message from most-changed paths
  local top_files
  top_files=$(echo "$status" | head -3 | while IFS= read -r line; do
    echo "$line" | cut -c4-
  done | tr '\n' ',' | sed 's/,$//')

  suggestion="${suggestion}更新 $(echo "$top_files" | cut -d',' -f1)"

  module_output "suggestion" "C3" "建议 commit: \`${suggestion}\` (${file_count} 个文件变更)"
}

# ═══════════════════════════════════════════════════════════════════
# C4: Secrets / sensitive data detection
# ═══════════════════════════════════════════════════════════════════
check_c4_body() {

  # Check staged + unstaged changes for secret patterns
  local diff_output
  diff_output=$(git_safe diff --cached 2>/dev/null || true)
  diff_output+=$(git_safe diff 2>/dev/null || true)

  # Also check new files from transcript
  local new_files="$HOOK_TMP_DIR/written-files.txt"
  local all_content=""

  if [[ -n "$diff_output" ]]; then
    all_content+="$diff_output"
  fi

  # Scan new files for secrets
  if [[ -f "$new_files" ]]; then
    while IFS= read -r f; do
      [[ -f "$PROJECT_ROOT/$f" ]] || continue
      all_content+=$(head -50 "$PROJECT_ROOT/$f" 2>/dev/null || true)
    done < "$new_files"
  fi

  # Secret patterns
  local patterns=(
    'API[_-]?KEY\s*=\s*["'"'"'][a-zA-Z0-9_-]{20,}'
    'SECRET\s*=\s*["'"'"'][a-zA-Z0-9_-]{10,}'
    'TOKEN\s*=\s*["'"'"'][a-zA-Z0-9_.-]{20,}'
    'password\s*=\s*["'"'"'][^"'"'"']{4,}'
    'sk-[a-zA-Z0-9]{20,}'
    'AKIA[0-9A-Z]{16}'
    'ghp_[a-zA-Z0-9]{36}'
    'github_pat_[a-zA-Z0-9_]{20,}'
    'ya29\.[a-zA-Z0-9_-]{50,}'
  )

  local found=0
  for pattern in "${patterns[@]}"; do
    if echo "$all_content" | grep -qE "$pattern" 2>/dev/null; then
      found=$((found + 1))
    fi
  done

  if [[ "$found" -gt 0 ]]; then
    module_output "error" "C4" "🚨 检测到 ${found} 类疑似密钥/凭证模式！请确认未硬编码敏感信息"
  fi
}

check_c1() { run_check "git" "C1" "" check_c1_body; }
check_c2() { run_check "git" "C2" "" check_c2_body; }
check_c3() { run_check "git" "C3" "" check_c3_body; }
check_c4() { run_check "git" "C4" "" check_c4_body; }
# ── Run all checks ──────────────────────────────────────────────────
check_c1
check_c2
check_c3
check_c4
