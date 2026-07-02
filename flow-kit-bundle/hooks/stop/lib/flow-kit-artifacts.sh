#!/bin/bash
# flow-kit-artifacts.sh — flow-kit 产物验证函数库
# Source from stop hook modules or SessionStart hooks.
#
# Requires: PROJECT_ROOT, jq
# Provides: fk_artifact_check, fk_auto_phase, fk_validate_flow, fk_boundary_check

# NOTE: Does NOT set -euo pipefail — this is a library, sourced by callers.
# Callers (26-workflow.sh, etc.) are responsible for shell flags.

readonly MIN_MEANINGFUL_LINES=3   # 阈值:<3行的文件视为空壳(常见于仅shebang+空行的空模板/占位文件);≥3行才开始内容检验

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
# Independent review gate (L2/L3 独立 review)
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_independent_review_gate_active <phase>
# Returns: 0 (true) = gate 生效（应阻止阶段推进）；1 (false) = 放行
# gate 生效当且仅当：phase∈{1,2,6} 且 gate 开启 且 .specs/<id>/.independent-review-<phase>.done 不存在。
# gate 开启的双源：.flow-active.goal.gate_config[<阶段名>] ∈ {independent,true} 优先，
#                 回退 .claude/stop-hook.json 的 independent_review.phases 数组含该阶段名。
fk_independent_review_gate_active() {
  local phase="$1"
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 1
  [[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || return 1

  local change_id
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  [[ "$change_id" != "none" && "$change_id" != "null" ]] || return 1

  local phase_name
  case "$phase" in
    1) phase_name="1-requirement" ;;
    2) phase_name="2-design" ;;
    3) phase_name="3-task" ;;
    5) phase_name="5-test" ;;
    6) phase_name="6-review" ;;
    7) phase_name="7-integration" ;;
    *) return 1 ;;
  esac

  # 双源读 gate
  local gate_on=""
  gate_on=$(jq -r --arg pn "$phase_name" \
    '.goal.gate_config[$pn] // empty' "$flow_file" 2>/dev/null || echo "")
  if [[ "$gate_on" != "independent" && "$gate_on" != "true" ]]; then
    local cfg="${PROJECT_ROOT}/.claude/stop-hook.json"
    if [[ -f "$cfg" ]] && jq -e --arg pn "$phase_name" \
        '.independent_review.phases // [] | index($pn)' "$cfg" >/dev/null 2>&1; then
      gate_on="independent"
    fi
  fi
  [[ "$gate_on" == "independent" || "$gate_on" == "true" ]] || return 1

  # gate 开启：done 标志存在则放行（return 1），不存在则 gate 生效（return 0）
  local done_marker="${PROJECT_ROOT}/.specs/${change_id}/.independent-review-${phase}.done"
  [[ ! -f "$done_marker" ]]
}

# ═══════════════════════════════════════════════════════════════════════
# .done authenticity validation (AC-1 · D1/D5/G1 · 两层时机)
# ═══════════════════════════════════════════════════════════════════════

# Helper: 提取 .done 的 KVP 值（key=value，值可含 =）。未找到 → 空。
# Usage: _fk_done_kvp <path> <key>
_fk_done_kvp() {
  local path="$1" key="$2"
  [[ -f "$path" ]] || { echo ""; return; }
  grep -E "^${key}=" "$path" 2>/dev/null | head -1 | sed "s/^${key}=//"
}

# Usage: fk_validate_done_marker <done_path> <phase> <change_id> <tier>
#   tier = write (Tier 1 元数据快校验) | transition (Tier 1 + Tier 2 后置)
# Returns: 0 = .done 有效（放行）; 2 = 无效 deny（对齐 DESIGN §3 "deny exit 2" + forged-done check.sh rc=2）
# fail-close（D9）: jq 不可用 / 解析异常 / 畸形输入 → return 2（deny，agent 不能靠制造 hook 内部错误放行）
# phases_done 短路（D1/R11）: phase ∈ goal.phases_done → 直接有效（历史 .done 兜底）
fk_validate_done_marker() {
  local done_path="$1" phase="$2" change_id="$3" tier="${4:-write}"
  local flow_file="${PROJECT_ROOT:-}/.flow-active"

  [[ -f "$done_path" ]] || return 2

  # phases_done 短路（历史 .done · written_by=main-agent 不触发回头校验）
  if [[ -f "$flow_file" ]]; then
    local in_done
    in_done=$(jq -r --arg p "$phase" \
      '.goal.phases_done // [] | map(select(. == $p)) | length' \
      "$flow_file" 2>/dev/null || echo "0")
    [[ "$in_done" != "0" ]] && return 0
  fi

  # ── Tier 1 · 元数据快校验（不依赖下游产物）──
  [[ -s "$done_path" ]] || return 2                        # T1 非空（挡威胁① touch 空文件）
  local dlines
  dlines=$(wc -l < "$done_path" 2>/dev/null | tr -dc '0-9')
  [[ "${dlines:-0}" -ge "$MIN_MEANINGFUL_LINES" ]] || return 2

  local k_phase k_cid k_wby                                # T2 KVP（挡威胁② 伪造）
  k_phase=$(_fk_done_kvp "$done_path" "phase")
  k_cid=$(_fk_done_kvp "$done_path" "change_id")
  k_wby=$(_fk_done_kvp "$done_path" "written_by")
  [[ "$k_phase" == "$phase" ]] || return 2
  [[ "$k_cid" == "$change_id" ]] || return 2
  [[ -n "$k_wby" ]] || return 2

  [[ "$tier" == "transition" ]] || return 0                # tier=write 到此为止

  # ── Tier 2 · transition 后置（产物已齐）──
  # T3 D7 握手锚点（挡威胁③ + ⑤-L3 常见路径）
  local hs_path="${flow_file}.independent-review"
  [[ -f "$hs_path" ]] || return 2
  local hs_wby hs_phase hs_verdict
  hs_wby=$(jq -r '.written_by // ""' "$hs_path" 2>/dev/null || echo "")
  hs_phase=$(jq -r '.phase // ""' "$hs_path" 2>/dev/null || echo "")
  hs_verdict=$(jq -r '.verdict // ""' "$hs_path" 2>/dev/null || echo "")
  [[ "$hs_wby" == "stop-hook-29" ]] || return 2
  [[ "$hs_phase" == "$phase" ]] || return 2
  local l3v
  l3v=$(_fk_done_kvp "$done_path" "L3_verdict")
  [[ -n "$l3v" && "$hs_verdict" == "$l3v" ]] || return 2

  # T3b SESSION_ID 跨会话锚点（挡威胁④ 移花接木）
  local cur_sid done_sid
  cur_sid="${CLAUDE_CODE_SESSION_ID:-}"
  done_sid=$(_fk_done_kvp "$done_path" "session_id")
  if [[ -n "$cur_sid" && -n "$done_sid" ]]; then
    [[ "$done_sid" == "$cur_sid" ]] || return 2
  fi
  # cur_sid / done_sid 缺失 → best-effort 不挡（跨会话合法推进由 phases_done 短路兜底）

  # T4 L2_verdict 与 INDEPENDENT-REVIEW-<phase>.md 比对（挡威胁⑤-L2 · v1 best-effort 提高成本）
  local l2v md_path md_v
  l2v=$(_fk_done_kvp "$done_path" "L2_verdict")
  md_path="${PROJECT_ROOT:-}/.specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
  if [[ -n "$l2v" && -f "$md_path" ]]; then
    md_v=$(grep -iE 'verdict[^a-z]*[:：]' "$md_path" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
    [[ -z "$md_v" || "$md_v" == "$l2v" ]] || return 2     # 提取不到 verdict 不挡（best-effort）
  fi

  return 0
}

# ═══════════════════════════════════════════════════════════════════════
# Auto phase transition detection
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_auto_phase <change_id> <current_phase>
# Outputs: suggested next phase (e.g. "4") if auto-advance possible, else empty
fk_auto_phase() {
  local change_id="$1" phase="$2"
  local spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

  # 独立 review gate：本阶段开启独立 review 且未完成 → echo 空，阻断 check_g1 自动推进
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
  changed=$(cd "$PROJECT_ROOT" && git diff --name-only HEAD 2>/dev/null | grep -v '^.specs/' | grep -v '^.claude/' || true)
  if [[ -z "$changed" ]]; then
    # No uncommitted changes — check staged + unstaged
    changed=$(cd "$PROJECT_ROOT" && git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null | sort -u | grep -v '^.specs/' | grep -v '^.claude/' || true)
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
