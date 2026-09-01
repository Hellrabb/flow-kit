#!/bin/bash
# 33-flow-active-integrity.sh — .flow-active state integrity cross-validation (L3)
#
# Runs at session stop. Verifies that .flow-active fields are consistent
# with on-disk artifacts. Writes findings to .flow-active.correction
# (type=state-integrity) via correction-file.sh.
#
# Design: DESIGN.md D1-D5 | AC: REQUIREMENT.md AC-2 ~ AC-6

set -euo pipefail

_flow_active_integrity_main() {
  local flow_active="${1:-.flow-active}"
  local specs_dir="${2:-.specs}"
  local correction_file="${3:-.flow-active.correction}"
  local transcript_file="${4:-}"
  local _FAI_APPENDED=0

  # ── Guard: skip if .flow-active doesn't exist ──
  [[ -f "$flow_active" ]] || return 0

  # ── Guard: skip if jq unavailable ──
  command -v jq >/dev/null 2>&1 || return 0

  # ── Guard: validate JSON ──
  # 外来/损坏让位（AC-5/6/7 · D5/D6）：jq empty 失败 → 33 号单一 actor 让位。
  # 全程只读 .flow-active 本体（AC-7），仅操作 correction 文件；不再追加 corrupt_json。
  if ! jq empty "$flow_active" 2>/dev/null; then
    _fai_ensure_correction_lib

    # ① 清空白名单类 violation（l2-missing / model-missing / foreign_state /
    #    compliance 条目保留 — AC-6/AC-10）
    _fai_clear_whitelist "$correction_file" >/dev/null 2>&1 || true

    # ② 合并标签含 state-integrity 段时剥离（l2-missing+state-integrity → l2-missing）。
    #    纯 type（无 `+`）场景由本分支保留——correction-file.sh 边界契约：
    #    剥离仅对合并标签有意义，no-op 返回非零 rc 忽略（fail-open）。
    if type correction_file_strip_type >/dev/null 2>&1; then
      correction_file_strip_type "$correction_file" "state-integrity" || true
    fi

    # ③ 追加 1 条去重 foreign_state note（去重键=check，D6；已存在则跳过）
    local note_message
    if LC_ALL=C grep -qE '^[[:space:]]*[\[{]' "$flow_active" 2>/dev/null; then
      # 内容疑似 JSON 但 jq 解析失败 → 损坏措辞
      note_message="状态文件已损坏（非 flow-kit JSON），已让位并清除 state-integrity 状态。如果你是 flow-kit，请重新 /flow 启动。"
    else
      # 非 JSON 内容（如 YAML）→ 外来措辞
      note_message="外来的状态文件，已让位并清除 state-integrity 状态。如果你是 flow-kit，请重新 /flow 启动。"
    fi
    _fai_append_foreign_note "$correction_file" "$note_message"

    # ④ stderr 提示一次（SessionStart 可收割）
    echo "flow-active-integrity: .flow-active 非 flow-kit 状态文件（外来/损坏），已让位；foreign_state note 已写入 correction" >&2
    return 0
  fi

  # ── Source shared libs (best-effort) ──
  local hook_base="${HOOK_BASE_DIR:-${BASH_SOURCE%/*}}"
  local artifacts_lib="${hook_base}/lib/flow-kit-artifacts.sh"
  local correction_lib="${hook_base}/lib/correction-file.sh"

  [[ -f "$artifacts_lib" ]] && source "$artifacts_lib" 2>/dev/null || true
  [[ -f "$correction_lib" ]] && source "$correction_lib" 2>/dev/null || true

  local violations=()
  local change_id phase

  change_id=$(jq -r '.change_id // ""' "$flow_active")
  phase=$(jq -r '.phase // ""' "$flow_active")

  # ── 1. check_change_id ──
  _fai_check_change_id "$change_id" "$specs_dir"

  # ── 2. check_phase ──
  _fai_check_phase "$change_id" "$phase" "$specs_dir"

  # ── 3. check_pipeline ──
  _fai_check_pipeline "$flow_active" "$change_id" "$specs_dir"

  # ── 4. check_staleness ──
  _fai_check_staleness "$flow_active"

  # ── 5. check_token ──
  _fai_check_token "$flow_active" "$transcript_file"

  # ── 健康清零 (AC-3 / D3) ──
  # 触发条件：本轮全部检查通过（_FAI_APPENDED=0，9 处 check 均未置位）且
  # .flow-active 为合法 flow-kit JSON（入口 jq empty 已通过）。清空白名单类
  # violation，保留 l2-missing / model-missing / foreign_state / compliance
  # （AC-10 · ADR-024）。幂等，fail-open，不阻塞 stop 链。
  if [[ "${_FAI_APPENDED:-0}" -eq 0 ]] && [[ -f "$correction_file" ]] && \
     jq empty "$correction_file" 2>/dev/null; then
    local cleared
    cleared=$(_fai_clear_whitelist "$correction_file")
    if [[ "$cleared" -gt 0 ]]; then
      echo "state-integrity cleared ${cleared} items" >&2
    fi
  fi
}

# ── check_change_id ──────────────────────────────────────────────
_fai_check_change_id() {
  local change_id="$1" specs_dir="$2"

  if [[ -n "$change_id" && "$change_id" != "null" ]]; then
    if [[ ! -d "$specs_dir/$change_id" ]]; then
      _fai_append_violation "$correction_file" "change_id_dangling" \
        "change_id '${change_id}' has no corresponding .specs/ directory" \
        ".flow-active.change_id"
    fi
  elif [[ "$change_id" == "null" || -z "$change_id" ]]; then
    # change_id is null/empty — check for orphaned active directories
    local orphan=""
    orphan=$(find "$specs_dir" -mindepth 1 -maxdepth 1 -type d \
      ! -name 'archive' ! -name 'health' ! -name 'adr' \
      -exec basename {} \; 2>/dev/null | head -1)
    if [[ -n "$orphan" ]]; then
      _fai_append_violation "$correction_file" "change_id_null_with_dirs" \
        "change_id is null but .specs/ contains active directories (e.g. '${orphan}')" \
        ".flow-active.change_id"
    fi
  fi
}

# ── check_phase ───────────────────────────────────────────────────
_fai_check_phase() {
  local change_id="$1" phase="$2" specs_dir="$3"

  [[ -z "$change_id" || "$change_id" == "null" ]] && return 0
  [[ -z "$phase" || "$phase" == "null" ]] && return 0
  [[ ! -d "$specs_dir/$change_id" ]] && return 0

  local artifacts=""
  artifacts=$(_fai_get_phase_artifacts "$phase")

  if [[ -z "$artifacts" ]]; then
    # Phase not in PHASE_ARTIFACTS — info only, not a violation
    return 0
  fi

  local missing=()
  local art=""
  for art in $artifacts; do
    # Phase 4 artifacts use glob pattern (*-SUMMARY.md)
    if [[ "$art" == *"*"* ]]; then
      if ! compgen -G "${specs_dir}/${change_id}/${art}" >/dev/null 2>&1; then
        missing+=("$art")
      fi
    elif [[ ! -f "${specs_dir}/${change_id}/${art}" ]]; then
      missing+=("$art")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    _fai_append_violation "$correction_file" "phase_artifact_missing" \
      "phase=${phase}: missing artifacts in .specs/${change_id}/: ${missing[*]}" \
      ".flow-active.phase"
  fi
}

# ── check_pipeline ─────────────────────────────────────────────────
_fai_check_pipeline() {
  local flow_active="$1" change_id="$2" specs_dir="$3"

  local scope
  scope=$(jq -r '.goal.scope // ""' "$flow_active")
  [[ "$scope" == "pipeline" ]] || return 0

  local current_phase
  current_phase=$(jq -r '.goal.current_phase // ""' "$flow_active")

  # 3a. phases_done artifacts
  local phases_done
  phases_done=$(jq -r '.goal.phases_done // [] | .[]' "$flow_active" 2>/dev/null)
  local pd=""
  for pd in $phases_done; do
    pd="${pd//\"/}"
    local pd_artifacts=""
    pd_artifacts=$(_fai_get_phase_artifacts "$pd")
    if [[ -n "$pd_artifacts" ]]; then
      local art=""
      for art in $pd_artifacts; do
        if [[ "$art" != *"*"* ]]; then
          if [[ ! -f "${specs_dir}/${change_id}/${art}" ]]; then
            _fai_append_violation "$correction_file" "pipeline_phase_artifact_missing" \
              "phases_done includes ${pd} but ${art} is missing" \
              ".flow-active.goal.phases_done"
            break
          fi
        fi
      done
    fi
  done

  # 3b. current_phase gate N-1→N must be passed
  if [[ -n "$current_phase" && "$current_phase" != "null" && "$current_phase" != "0" ]]; then
    local prev=$((current_phase - 1))
    local gate_key="${prev}→${current_phase}"
    local gate_status
    gate_status=$(jq -r --arg gk "$gate_key" '.goal.gates[$gk] // ""' "$flow_active")
    if [[ "$gate_status" != "passed" ]]; then
      _fai_append_violation "$correction_file" "pipeline_gate_not_passed" \
        "current_phase=${current_phase} but gate '${gate_key}' is '${gate_status}' (expected 'passed')" \
        ".flow-active.goal.gates"
    fi
  fi

  # 3c. passed gates must have N in phases_done
  local gates_passed
  gates_passed=$(jq -r '.goal.gates | to_entries[] | select(.value == "passed") | .key' "$flow_active" 2>/dev/null)
  local gp=""
  for gp in $gates_passed; do
    gp="${gp//\"/}"
    local left_phase="${gp%%→*}"
    # phases_done output is jq -r (unquoted), so grep exact line match
    if ! echo "$phases_done" | grep -qFx "$left_phase"; then
      _fai_append_violation "$correction_file" "pipeline_gate_phase_mismatch" \
        "gate '${gp}' is passed but phase ${left_phase} is not in phases_done" \
        ".flow-active.goal.gates"
    fi
  done
}

# ── check_staleness ────────────────────────────────────────────────
_fai_check_staleness() {
  local flow_active="$1"

  local updated_at
  updated_at=$(jq -r '.updated_at // 0' "$flow_active")
  [[ "$updated_at" == "null" || "$updated_at" == "0" ]] && return 0

  local stale_hours="${FLOW_ACTIVE_STALE_HOURS:-24}"
  local now
  now=$(date +%s)
  local age_seconds=$((now - updated_at))
  local age_hours=$((age_seconds / 3600))

  if [[ $age_hours -gt $stale_hours ]]; then
    _fai_append_violation "$correction_file" "stale_updated_at" \
      ".flow-active.updated_at is ${age_hours}h old (threshold: ${stale_hours}h)" \
      ".flow-active.updated_at"
  fi
}

# ── check_token ────────────────────────────────────────────────────
_fai_check_token() {
  local flow_active="$1" transcript_file="$2"

  local token_spent
  token_spent=$(jq -r '.token_spent // 0' "$flow_active")
  [[ "$token_spent" != "0" ]] && return 0

  # No transcript file provided → skip
  [[ -z "$transcript_file" || ! -f "$transcript_file" ]] && return 0

  # Check if this session wrote to .flow-active but didn't update token_spent
  if grep -qE "jq.*'[.].*='.*\.flow-active|jq.*>.*\.flow-active" "$transcript_file" 2>/dev/null; then
    _fai_append_violation "$correction_file" "token_spent_unmaintained" \
      "token_spent is 0 but session transcript shows .flow-active write operations" \
      ".flow-active.token_spent"
  fi
}

# ── PHASE_ARTIFACTS resolution (with built-in fallback) ────────────
_fai_get_phase_artifacts() {
  local phase="$1"

  # Try PHASE_ARTIFACTS from flow-kit-artifacts.sh first
  if declare -p PHASE_ARTIFACTS 2>/dev/null | grep -q 'declare'; then
    echo "${PHASE_ARTIFACTS[$phase]:-}"
    return 0
  fi

  # Built-in fallback mapping (NFR reliability — R2 fix)
  case "$phase" in
    1) echo "REQUIREMENT.md" ;;
    2) echo "DESIGN.md" ;;
    3) echo "TASK.md" ;;
    4) echo "*-SUMMARY.md" ;;
    5) echo "TEST.md" ;;
    6) echo "REVIEW.md" ;;
    7) echo "REVIEW.md" ;;  # phase 7 requires full artifact set; REVIEW.md is the gate
    *) echo "" ;;
  esac
}

# ── State-integrity hygiene helpers (correction-hygiene-state-guard · ADR-024) ──

# _fai_ensure_correction_lib — best-effort source of correction-file.sh helpers.
# Idempotent (no-op when already sourced); fail-open — never breaks the stop chain.
_fai_ensure_correction_lib() {
  type correction_file_dedupe >/dev/null 2>&1 && return 0
  local hook_base="${HOOK_BASE_DIR:-${BASH_SOURCE%/*}}"
  local correction_lib="${hook_base}/lib/correction-file.sh"
  [[ -f "$correction_lib" ]] && source "$correction_lib" 2>/dev/null || true
}

# _fai_clear_whitelist <correction_file> — remove ALL whitelist-class entries
# from .violations[] (ADR-024 scope). Keeps l2-missing / model-missing /
# foreign_state / compliance entries byte-identical with their relative order.
# Idempotent; atomic (mktemp+mv); fail-open. Prints removed count to stdout
# (0 on no-op / missing file / missing lib). Used by 健康清零 (AC-3/D3) and
# 外来清空 (AC-6).
_fai_clear_whitelist() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return 0; }
  if ! type _fk_ci_whitelist_json >/dev/null 2>&1; then
    echo 0
    return 0
  fi

  local wl_json
  wl_json=$(_fk_ci_whitelist_json) || { echo 0; return 0; }

  local plan removed kept_json
  plan=$(jq -c --argjson wl "$wl_json" '
      if (.violations | type) == "array" then
        ([.violations[] | . as $e | select(
            ((($e.check? // "") == "") or (($wl | index($e.check)) | not))
         )]) as $kept |
        {removed: ((.violations | length) - ($kept | length)), kept: $kept}
      else
        {removed: 0, kept: .violations}
      end
    ' "$file" 2>/dev/null) || plan=""
  [[ -z "$plan" ]] && { echo 0; return 0; }

  removed=$(printf '%s' "$plan" | jq -r '.removed' 2>/dev/null) || removed=0
  [[ "$removed" -gt 0 ]] || { echo 0; return 0; }

  kept_json=$(printf '%s' "$plan" | jq -c '.kept' 2>/dev/null) || kept_json="[]"

  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX") || { echo "$removed"; return 0; }
  if jq --argjson kept "$kept_json" '
      if (.violations | type) == "array" then .violations = $kept else . end
    ' "$file" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
  fi
  echo "$removed"
}

# _fai_append_foreign_note <correction_file> <message> — append exactly one
# foreign_state note, deduped by check name (D6: 去重键=check; already-present →
# no-op, no rewrite → idempotent across repeated stops). Existing type/violations
# preserved (compliance included, AC-10). New file / invalid JSON → fresh
# type=state-integrity file. Fail-open; atomic (tmp+mv).
_fai_append_foreign_note() {
  local file="$1" note_message="$2"

  if [[ -f "$file" ]] && jq empty "$file" 2>/dev/null; then
    if jq -e 'any(.violations[]?; .check == "foreign_state")' "$file" >/dev/null 2>&1; then
      return 0
    fi
  fi

  local new_entry
  new_entry=$(jq -n \
    --arg msg "$note_message" \
    --arg ts "$(date -Iseconds)" \
    '{check: "foreign_state", message: $msg, field: "flow_active", detected_at: $ts}') || return 0

  local merged
  if [[ -f "$file" ]] && jq empty "$file" 2>/dev/null; then
    merged=$(jq --argjson entry "$new_entry" --arg ts "$(date -Iseconds)" \
      '.violations = ((.violations // []) + [$entry]) | .written_at = $ts' \
      "$file" 2>/dev/null)
  else
    merged=$(jq -n \
      --arg type "state-integrity" \
      --arg ts "$(date -Iseconds)" \
      --argjson entry "$new_entry" \
      '{type: $type, violations: [$entry], written_at: $ts}')
  fi

  [[ -z "$merged" ]] && return 0
  echo "$merged" | jq '.' > "${file}.tmp" 2>/dev/null && \
    mv "${file}.tmp" "$file" || true
}

# ── Correction file write (read-merge-write strategy — R1 fix) ─────
# 每次 append 后执行 AC-1 去重（同 check+field 保最新）+ AC-2 FIFO 容量 10
# （仅白名单类条目，compliance 不参与 — ADR-024）。两者 fail-open。
_fai_append_violation() {
  local correction_file="$1" check_name="$2" message="$3" field="$4"

  # D3：本轮存在违规 → 置位，抑制退出点健康清零
  _FAI_APPENDED=1

  # Build new violation entry
  local new_entry
  new_entry=$(jq -n \
    --arg check "$check_name" \
    --arg msg "$message" \
    --arg field "$field" \
    --arg ts "$(date -Iseconds)" \
    '{check: $check, message: $msg, field: $field, detected_at: $ts}')

  # Read-merge-write: preserve existing violations
  local merged
  if [[ -f "$correction_file" ]] && jq empty "$correction_file" 2>/dev/null; then
    local existing_type
    existing_type=$(jq -r '.type // ""' "$correction_file" 2>/dev/null)
    # Merge type: if existing type differs, use combined label (R2 fix)
    local new_type="state-integrity"
    if [[ -n "$existing_type" && "$existing_type" != "state-integrity" && "$existing_type" != *"state-integrity"* ]]; then
      new_type="${existing_type}+state-integrity"
    elif [[ -n "$existing_type" && "$existing_type" == "state-integrity" ]]; then
      new_type="state-integrity"
    elif [[ -n "$existing_type" ]]; then
      new_type="$existing_type"
    fi
    merged=$(jq --argjson entry "$new_entry" --arg type "$new_type" \
      '.type = $type | .violations += [$entry] | .written_at = "'"$(date -Iseconds)"'"' \
      "$correction_file" 2>/dev/null)
  else
    merged=$(jq -n \
      --arg type "state-integrity" \
      --arg ts "$(date -Iseconds)" \
      --argjson entry "$new_entry" \
      '{type: $type, violations: [$entry], written_at: $ts}')
  fi

  echo "$merged" | jq '.' > "${correction_file}.tmp" 2>/dev/null && \
    mv "${correction_file}.tmp" "$correction_file" || true

  # ── AC-1/AC-2: 去重 + 容量（append 成功后执行，fail-open）──
  _fai_ensure_correction_lib
  if type correction_file_dedupe >/dev/null 2>&1; then
    correction_file_dedupe "$correction_file" || true
    correction_file_trim "$correction_file" 10 || true
  fi
}

# ── Entry point ────────────────────────────────────────────────────
_flow_active_integrity_main "$@"
