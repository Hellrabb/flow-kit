# gate-checks-review.sh — phase transition orchestrator + deny logic
# source: split from independent-review-gate.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 提供 _gate_do_transition（L3 dispatch + block）、_gate_phase_transition（方向检测 + L2/L3 编排）
# 和 _gate_deny_reason（commit/PR/phase-write 终裁 deny）。
# 被 independent-review-gate.sh 在顶层 source。
# 注意：本文件不含 shebang（作为 sourced lib 使用）。

# _gate_do_transition — L3 dispatch + block (~25 lines)
# Called when _gate_check_l3 returns 1 (L3 not done). Dispatches L3 prompt and exits 2.
_gate_do_transition() {
  local gate_val="$1" review_md="$2" phase="$3" change_id="$4" cwd="$5"

  local l3l="${HOOK_BASE_DIR}/../stop/lib/l3-review.sh"
  if [ -f "$l3l" ]; then
    source "$l3l" 2>/dev/null || true
    type l3_dispatch_prompt >/dev/null 2>&1 && l3_dispatch_prompt "$phase" "$change_id" "${cwd}/.specs/${change_id}" "${gate_val:-both}" >&2
  fi
  local l2v="skipped"
  if [[ "$gate_val" == "both" ]]; then
    l2v="$(fk_extract_l2_verdict "$review_md")"
    [ -n "$l2v" ] || l2v="fail"
  fi
  cat >&2 <<EOF
⛔ 独立 review gate：L3 外部模型审查未完成（phase ${phase}）。
   选项：① 复制上方 L3 派发命令异步执行（推荐）② 结束当前 session，Stop hook 会自动跑 L3 ③ 手动 l3_review_run
   L3 完成后重新执行 phase transition / commit 即可放行。
EOF
  exit 2
}

# _gate_phase_transition — phase-write direction detection + L2/L3 dispatch orchestrator (~45 lines)
# Detects rollback/noop/forward; delegates to _gate_check_l2 and _gate_check_l3 for forward transitions.
_gate_phase_transition() {
  local cmd="$1" phase="$2" change_id="$3" cwd="$4" flow_file="$5"

  if ! is_phase_write "$cmd"; then return 0; fi   # 修 BUG-C：非阶段写=正常返回（set -e 不再误退出），交 Gate 7 _gate_deny_reason

  local cur_phase
  cur_phase=$(jq -r '.goal.current_phase // ""' "$flow_file" 2>/dev/null || echo "")
  local dir
  dir=$(_fk_phase_direction "$cmd" "$cur_phase")
  case "$dir" in
    rollback)
      cat >&2 <<'EOF'
⏎ 独立 review gate：检测到回退操作（phase → 更早阶段），放行不要求 .done。
EOF
      exit 0 ;;
    noop) exit 0 ;;
  esac

  # ── forward transition → resolve gate_config ──
  local phase_name="$(fk_phase_gate_key "$phase")"
  local gate_val
  gate_val=$(jq -r --arg pn "$phase_name" '.goal.gate_config[$pn] // ""' "$flow_file" 2>/dev/null || echo "")
  gate_val="$(fk_normalize_gate_val "$gate_val")"

  local review_md="${cwd}/.specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
  local done_marker="${cwd}/.specs/${change_id}/.independent-review-${phase}.done"
  local skip_marker="${cwd}/.specs/${change_id}/.skip-L2-${phase}"

  _gate_check_l2 "$gate_val" "$review_md" "$skip_marker" "$phase" "$change_id" "$cwd"
  _gate_check_l3 "$gate_val" "$review_md" "$done_marker" "$phase" "$change_id" "$cwd" \
    || _gate_do_transition "$gate_val" "$review_md" "$phase" "$change_id" "$cwd"
}

# _gate_deny_reason — final deny for commit/PR/phase write without valid .done
_gate_deny_reason() {
  local cmd="$1" phase="$2" change_id="$3" cwd="$4"

  local phase_name="$(fk_phase_gate_key "$phase")"

  local deny_reason=""
  if is_phase_write "$cmd"; then deny_reason="阶段 ${phase} (${phase_name}) 切换"
  elif is_git_commit "$cmd"; then deny_reason="git commit"
  elif is_gh_pr_create "$cmd"; then deny_reason="gh pr create"
  fi

  if [ -n "$deny_reason" ]; then
    local done_marker="${cwd}/.specs/${change_id}/.independent-review-${phase}.done"
    cat >&2 <<EOF
⛔ 独立 review gate：阶段 ${phase} (${phase_name}) 独立 review 未完成，禁止 ${deny_reason}。
   需先完成 L2（盲审子 agent → INDEPENDENT-REVIEW-${phase}.md）+ L3（Stop hook 调外部模型），
   再由主 agent 写 ${done_marker} 后重试。
   如确需绕过（hotfix）：touch ${done_marker}，或 /flow gate-config ${phase_name}=off 关闭。
EOF
    return 2
  fi
  return 0
}
