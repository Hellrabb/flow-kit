#!/bin/bash
# flow-kit-artifacts.sh — flow-kit 产物验证函数库（聚合入口）
# Source from stop hook modules or SessionStart hooks.
#
# Sources done-validation.sh for .done marker validation functions.
# Requires: PROJECT_ROOT, jq
# Provides: fk_artifact_check, fk_auto_phase, fk_validate_flow, fk_boundary_check,
#           fk_independent_review_gate_active, fk_validate_done_marker (via done-validation.sh)

# NOTE: Does NOT set -euo pipefail — this is a library, sourced by callers.
# Callers (26-workflow.sh, etc.) are responsible for shell flags.

source "${HOOK_BASE_DIR}/lib/done-validation.sh" 2>/dev/null || true

readonly MIN_MEANINGFUL_LINES=6   # 阈值: 6 键 .done (phase/change_id/written_by/L2_verdict/L3_verdict/artifacts) 至少 6 行

# ── Helpers ───────────────────────────────────────────────────────────

# Get .flow-active field, empty string if missing
fk_flow_field() {
  local field="$1" default="${2:-}"
  local flow_file="${PROJECT_ROOT}/.flow-active"
  if [[ ! -f "$flow_file" ]]; then echo "$default"; return; fi
  jq -r ".${field} // \"$default\"" "$flow_file" 2>/dev/null || echo "$default"
}

# Check if a file exists and is non-empty (not just frontmatter)
fk_file_nonempty() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local lines
  lines=$(wc -l < "$f" 2>/dev/null || echo "0")
  [[ "$lines" -gt $MIN_MEANINGFUL_LINES ]]  # More than just frontmatter + title
}

# ═══════════════════════════════════════════════════════════════════════
# Artifact validation per phase
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_artifact_check <change_id> <phase>
# Outputs: "warning|G1|<message>" for each missing artifact
# Returns: 0 if all required artifacts present, 1 if any missing
fk_artifact_check() {
  local change_id="$1" phase="$2"
  local spec_dir="${PROJECT_ROOT}/.specs/${change_id}"
  local missing=0

  # ── Phase → required artifacts map (cumulative semantics encoded) ──
  # Each value lists files that must exist (non-empty) at that phase.
  # Adding a phase: add ONE line here — no if/elif branches to touch.
  declare -A PHASE_ARTIFACTS=(
    ["1"]="CHANGE.md"
    ["2"]="CHANGE.md REQUIREMENT.md"
    ["2a"]="CHANGE.md REQUIREMENT.md"
    ["3"]="REQUIREMENT.md DESIGN.md"
    ["4"]="REQUIREMENT.md DESIGN.md TASK.md"
    ["5"]="REQUIREMENT.md DESIGN.md TASK.md"
    ["6"]="TEST.md"
    ["7"]="REVIEW.md"
  )

  # Generic: check all table-defined required artifacts
  local files="${PHASE_ARTIFACTS[$phase]:-}"
  if [[ -n "$files" ]]; then
    for f in $files; do
      if ! fk_file_nonempty "${spec_dir}/${f}"; then
        echo "warning|G1|Phase ${phase} 但 ${f} 缺失或为空"
        missing=1
      fi
    done
  fi

  # ── Conditional checks (table can't express these) ──────────────────

  # Phase 4: check current task has SUMMARY (task_id lookup)
  if [[ "$phase" == "4" ]]; then
    local task_id
    task_id=$(fk_flow_field "task_id" "")
    if [[ -n "$task_id" && "$task_id" != "none" ]]; then
      local summary_file="${spec_dir}/${task_id}-SUMMARY.md"
      if [[ ! -f "$summary_file" ]]; then
        echo "info|G1|当前 task ${task_id} 尚无 SUMMARY.md — 开发进行中"
      fi
    fi
  fi

  # Phase 5: check for at least one SUMMARY (find + wc)
  if [[ "$phase" == "5" ]]; then
    local summary_count
    summary_count=$(find "$spec_dir" -name "*-SUMMARY.md" -type f 2>/dev/null | wc -l)
    if [[ "$summary_count" -eq 0 ]]; then
      echo "warning|G1|Phase ${phase} 但没有任何 SUMMARY.md — 回 4-dev 补齐"
      missing=1
    fi
  fi

  return $missing
}

# ═══════════════════════════════════════════════════════════════════════
# Auto phase transition detection
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_auto_phase <change_id> <current_phase>
# Outputs: suggested next phase (e.g. "4") if auto-advance possible, else empty
fk_auto_phase() {
  local change_id="$1" phase="$2"
  local spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

  # 独立 review gate：本阶段开启独立 review 且未完成 → echo 空，阻断 _fk_check_g1 自动推进
  if fk_independent_review_gate_active "$phase"; then
    return 0
  fi

  case "$phase" in
    1)
      # REQUIREMENT.md 存在且有验收标准 → 可进 2
      if fk_file_nonempty "${spec_dir}/REQUIREMENT.md"; then
        if grep -qE "验收标准|验收准则|Given/When/Then" "${spec_dir}/REQUIREMENT.md" 2>/dev/null; then
          echo "2"
        fi
      fi
      ;;
    2|2a)
      # DESIGN.md 存在且完整 → 可进 3
      if fk_file_nonempty "${spec_dir}/DESIGN.md"; then
        if grep -q "ADR\|架构决策\|设计决策" "${spec_dir}/DESIGN.md" 2>/dev/null; then
          echo "3"
        fi
      fi
      ;;
    3)
      # TASK.md 存在且有可识别的 task → 可进 4
      if fk_file_nonempty "${spec_dir}/TASK.md"; then
        # Match id="T01" pattern OR ### T01: / ## T01 pattern
        if grep -qE '(id="T[0-9]+"|^###?\s+T[0-9]+)' "${spec_dir}/TASK.md" 2>/dev/null; then
          echo "4"
        fi
      fi
      ;;
    4)
      # All TASK SUMMARY files exist → 可进 5
      if fk_file_nonempty "${spec_dir}/TASK.md"; then
        local task_ids
        task_ids=$(grep -oP 'id="([^"]+)"' "${spec_dir}/TASK.md" 2>/dev/null | sed 's/id="//;s/"//' || true)
        local all_done=true
        local missing_list=""
        for tid in $task_ids; do
          if [[ ! -f "${spec_dir}/${tid}-SUMMARY.md" ]]; then
            all_done=false
            missing_list="${missing_list} ${tid}"
          fi
        done
        if $all_done && [[ -n "$task_ids" ]]; then
          echo "5"
        elif ! $all_done; then
          echo "info|G1|尚未完成的 task:${missing_list}" >&2
        fi
      fi
      ;;
    5)
      # TEST.md 存在且结论为 pass → 可进 6
      if fk_file_nonempty "${spec_dir}/TEST.md"; then
        if grep -q "PASS\|pass\|✅.*通过\|测试通过" "${spec_dir}/TEST.md" 2>/dev/null; then
          if ! grep -q "FAIL\|fail\|❌.*失败" "${spec_dir}/TEST.md" 2>/dev/null; then
            echo "6"
          fi
        fi
      fi
      ;;
    6)
      # REVIEW.md 存在且无 blocking → 可进 7
      if fk_file_nonempty "${spec_dir}/REVIEW.md"; then
        if ! grep -q "blocking\|BLOCKING\|🔴" "${spec_dir}/REVIEW.md" 2>/dev/null; then
          echo "7"
        fi
      fi
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════
# .flow-active validation
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_validate_flow
# Returns: 0 if valid, 1 if invalid/missing
fk_validate_flow() {
  local flow_file="${PROJECT_ROOT}/.flow-active"
  if [[ ! -f "$flow_file" ]]; then
    return 1
  fi
  jq empty "$flow_file" 2>/dev/null || return 1
  return 0
}

# ═══════════════════════════════════════════════════════════════════════
# Stale change detection
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_stale_check
# Outputs: suggestion|G1|<message> if stale (7+ days) or warning (30+ days)
fk_stale_check() {
  local flow_file="${PROJECT_ROOT}/.flow-active"
  if [[ ! -f "$flow_file" ]]; then return 0; fi

  local now f_ts age_days
  now=$(date +%s)
  f_ts=$(stat -c %Y "$flow_file" 2>/dev/null || stat -f %m "$flow_file" 2>/dev/null || echo "$now")
  age_days=$(((now - f_ts) / 86400))

  local change_id
  change_id=$(fk_flow_field "change_id" "?")

  if [[ "$age_days" -ge 30 ]]; then
    echo "warning|G1|.flow-active 超过 30 天未更新 (change=${change_id}, ${age_days}天)。建议 /flow stop 或归档。"
  elif [[ "$age_days" -ge 7 ]]; then
    echo "suggestion|G1|.flow-active 已 ${age_days} 天未更新 (change=${change_id})。如不再活跃，建议 /flow stop。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# Diff boundary check (Phase C)
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_boundary_check <change_id> <task_id>
# Compares git diff files against TASK.md write_files constraint
# Outputs: suggestion|G1|<message> if files outside boundary were changed
fk_boundary_check() {
  local change_id="$1" task_id="$2"
  local spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

  # Only relevant during dev phase (4) with an active task
  local phase
  phase=$(fk_flow_field "phase" "")
  [[ "$phase" == "4" ]] || return 0
  [[ -n "$task_id" && "$task_id" != "none" ]] || return 0

  # Get changed files
  local changed
  changed=$(cd "$PROJECT_ROOT" && git diff --name-only HEAD 2>/dev/null | grep -v '^.specs/' | grep -v '^.claude/' | grep -v '^.flow-kit/' || true)
  if [[ -z "$changed" ]]; then
    # No uncommitted changes — check staged + unstaged
    changed=$(cd "$PROJECT_ROOT" && git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null | sort -u | grep -v '^.specs/' | grep -v '^.claude/' | grep -v '^.flow-kit/' || true)
  fi
  [[ -n "$changed" ]] || return 0

  # Try to extract write_files from TASK.md for this task
  local write_files=""
  if [[ -f "${spec_dir}/TASK.md" ]]; then
    # Extract the task block for this task_id and look for write_files pattern
    write_files=$(sed -n "/id=\"${task_id}\"/,/<\/task>/p" "${spec_dir}/TASK.md" 2>/dev/null | \
                  grep -oP 'write_files="([^"]+)"' 2>/dev/null | sed 's/write_files="//;s/"//' | tr ',' '\n' | sed 's/^ *//' || true)
  fi

  if [[ -z "$write_files" ]]; then
    return 0  # No write_files constraint to check against
  fi

  # Check each changed file against the boundary
  local out_of_bounds=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    local matched=false
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      if [[ "$f" == $pattern ]]; then  # glob match
        matched=true
        break
      fi
    done <<< "$write_files"
    if ! $matched; then
      out_of_bounds="${out_of_bounds}  ${f}\n"
    fi
  done <<< "$changed"

  if [[ -n "$out_of_bounds" ]]; then
    echo -e "suggestion|G1|TASK ${task_id} write_files 边界外的文件被修改:\n${out_of_bounds}请确认是否为预期改动。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# Interrupt snapshot (Phase A)
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_snapshot_interrupt
# Reads transcript-parser output to auto-fill interrupt context in .flow-active
fk_snapshot_interrupt() {
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 0

  # Get last edited source file from transcript parser output
  local last_file=""
  if [[ -f "${HOOK_TMP_DIR}/touched-source-files.txt" ]]; then
    last_file=$(tail -1 "${HOOK_TMP_DIR}/touched-source-files.txt" 2>/dev/null || echo "")
  fi

  # Get last failing command from transcript
  local last_fail=""
  if [[ -f "${HOOK_TMP_DIR}/tool-calls.txt" ]]; then
    last_fail=$(grep -i "fail\|error" "${HOOK_TMP_DIR}/tool-calls.txt" 2>/dev/null | tail -1 | head -c 120 || echo "")
  fi

  # Build interrupt JSON
  local ts
  ts=$(date -Iseconds)

  if [[ -n "$last_file" || -n "$last_fail" ]]; then
    jq --arg file "${last_file:-unknown}" \
       --arg action "${last_fail:-session ended}" \
       --arg ts "$ts" \
       '.interrupt = {active_file: $file, last_action: $action, checkpoint_at: $ts} | .updated_at = $ts' \
       "$flow_file" > "${flow_file}.tmp" && mv "${flow_file}.tmp" "$flow_file"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# PROGRESS.md logging (Phase B)
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_log_progress <change_id> <phase> <task_id> <token_estimate> <session_id>
# Appends a row to .specs/<id>/PROGRESS.md
fk_log_progress() {
  local change_id="$1" phase="$2" task_id="$3" token_est="$4" session_id="$5"
  local spec_dir="${PROJECT_ROOT}/.specs/${change_id}"
  local progress_file="${spec_dir}/PROGRESS.md"

  # Ensure directory exists
  mkdir -p "$spec_dir"

  # Create header if new file
  if [[ ! -f "$progress_file" ]]; then
    cat > "$progress_file" <<'EOF'
# PROGRESS — 跨会话进度日志

> 由 Stop Hook G5 自动追加。每行 = 一次会话。

| 时间 | Session | Phase | Task | Token |
|---|---|---|---|---|
EOF
  fi

  # Extract a summary of what was done this session from transcript
  local summary="—"
  if [[ -f "${HOOK_TMP_DIR}/tool-summary.txt" ]]; then
    summary=$(head -3 "${HOOK_TMP_DIR}/tool-summary.txt" 2>/dev/null | tr '\n' ' ' | head -c 100 | sed 's/|/;/g' || echo "—")
  fi

  local ts
  ts=$(date +"%Y-%m-%d %H:%M")

  printf "| %s | %s | %s | %s | %s |\n" \
    "$ts" "${session_id:0:12}" "$phase" "${task_id:-—}" "${token_est:-?}" \
    >> "$progress_file"
}

# ═══════════════════════════════════════════════════════════════════════
# Token accumulation (Phase C)
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_accumulate_tokens <session_token_estimate>
# Adds session tokens to .flow-active token_spent total
fk_accumulate_tokens() {
  local session_tokens="$1"
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 0

  # If session_tokens is a number, accumulate
  if [[ "$session_tokens" =~ ^[0-9]+$ ]] && [[ "$session_tokens" -gt 0 ]]; then
    jq --argjson add "$session_tokens" \
       '.token_spent = ((.token_spent // 0) + $add) | .updated_at = now | .updated_at = (now | strftime("%Y-%m-%dT%H:%M:%S%z"))' \
       "$flow_file" > "${flow_file}.tmp" 2>/dev/null && mv "${flow_file}.tmp" "$flow_file" || true
  fi
}
