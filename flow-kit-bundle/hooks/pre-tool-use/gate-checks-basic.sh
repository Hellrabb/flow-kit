# shellcheck shell=bash
# gate-checks-basic.sh — L2/L3 gate check 核心函数
# source: split from independent-review-gate.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 提供 _gate_check_l2（L2 盲审完成门禁）和 _gate_check_l3（L3 外部审查完成门禁）。
# 被 independent-review-gate.sh 在顶层 source。
# 注意：本文件不含 shebang（作为 sourced lib 使用）。

# _gate_check_l2 — L2 blind review completion gate (~50 lines)
# Called by _gate_phase_transition during forward transitions.
# May exit 2 on missing L2 review, or touch skip_marker and continue.
_gate_check_l2() {
  local gate_val="$1" review_md="$2" skip_marker="$3" phase="$4" change_id="$5" cwd="$6"

  if [[ "$gate_val" != "both" && "$gate_val" != "L2" ]]; then return 0; fi  # L2 not required
  if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then return 0; fi  # L2 already done

  if [[ "${FLOW_KIT_SKIP_L2:-}" == "1" && "$gate_val" == "both" ]]; then
    touch "$skip_marker" 2>/dev/null || true
    cat >&2 <<EOF
⚠️ 独立 review gate：L2 已跳过（FLOW_KIT_SKIP_L2=1）。标记文件: ${skip_marker}。L3 继续执行。
EOF
    return 0
  elif [[ "${FLOW_KIT_SKIP_L2:-}" == "1" && "$gate_val" == "L2" ]]; then
    cat >&2 <<'EOF'
⛔ 独立 review gate：gate_config=L2（仅 L2，无 L3 兜底），不允许跳过 L2。
   FLOW_KIT_SKIP_L2=1 仅在 gate_config=both 时可用（跳过 L2 后仍有 L3）。请完成 L2 审查后重试。
EOF
    exit 2
  elif [ -f "$skip_marker" ]; then
    cat >&2 <<EOF
⚠️ 独立 review gate：L2 已跳过（${skip_marker} 存在）。L3 继续执行（若 gate_config 含 L3）。
EOF
    return 0
  fi

  # L2 not done, no skip — auto_advance 检测 + dispatch + block
  local l2_lib="${HOOK_BASE_DIR}/../stop/lib/l2-detect.sh"

  # ── auto_advance 检测（非阻塞模式）──
  local flow_file="${cwd}/.flow-active"
  local auto_advance
  auto_advance=$(jq -r '.goal.auto_advance // false' "$flow_file" 2>/dev/null || echo "false")
  if [[ "$auto_advance" == "true" ]]; then
    cat >&2 <<EOF
[l2-dispatch] auto_advance: L2 missing for phase ${phase} but not blocking in auto_advance mode
EOF
    # 异步派发 Agent（fire-and-forget），不阻塞自动推进
    if [ -f "$l2_lib" ]; then
      source "$l2_lib" 2>/dev/null || true
      type l2_dispatch_agent >/dev/null 2>&1 && l2_dispatch_agent "$phase" "$change_id" "${cwd}/.specs/${change_id}" || true
    fi
    return 0  # 放行，不 exit 2
  fi

  # ── 尝试自动派发 L2 Agent ──
  local dispatch_ok=0
  if [ -f "$l2_lib" ]; then
    source "$l2_lib" 2>/dev/null || true
    if type l2_dispatch_agent >/dev/null 2>&1; then
      if l2_dispatch_agent "$phase" "$change_id" "${cwd}/.specs/${change_id}"; then
        dispatch_ok=1
      fi
    fi
  fi

  # ── 派发成功 → 输出确认 + exit 2 ──
  if [ "$dispatch_ok" = "1" ]; then
    if [[ "$gate_val" == "L2" ]]; then
      cat >&2 <<EOF
⛔ 独立 review gate：gate_config=L2（仅 L2，无 L3 兜底）但 L2 尚未完成。
   [l2-dispatch] Agent dispatched for phase ${phase} — 等待 Agent 写入后重试 transition。
   若 dispatch 失败：手动复制上方命令或设置 FLOW_KIT_SKIP_L2=1 跳过（仅 gate_config=both 时可用）。
EOF
    else
      cat >&2 <<EOF
⛔ 独立 review gate：gate_config=both 但 L2 尚未完成。
   [l2-dispatch] Agent dispatched for phase ${phase} — 等待 Agent 写入后重试 transition。
   选项：① 等待 Agent 完成（推荐）② 跳过 L2：FLOW_KIT_SKIP_L2=1 后重试
EOF
    fi
    exit 2
  fi

  # ── 派发失败 → 降级为手动命令 ──
  if [ -f "$l2_lib" ]; then
    source "$l2_lib" 2>/dev/null || true
    type l2_dispatch_prompt >/dev/null 2>&1 && l2_dispatch_prompt "$phase" "$change_id" "${cwd}/.specs/${change_id}" >&2 2>/dev/null || true
  fi
  cat >&2 <<'EOF'
[l2-dispatch] dispatch failed, see manual command above
  若需跳过此 gate：设置 FLOW_KIT_SKIP_L2=1 后重试（仅 gate_config=both 时可用）
EOF
  if [[ "$gate_val" == "L2" ]]; then
    cat >&2 <<EOF
⛔ 独立 review gate：gate_config=L2（仅 L2，无 L3 兜底）但 L2 尚未完成。
   选项：① 复制上方 Agent 命令派 L2 子 agent（推荐）② 回退等待：完成 L2 后重新执行 transition 即可
EOF
  else
    cat >&2 <<EOF
⛔ 独立 review gate：gate_config=both 但 L2 尚未完成。
   选项：① 复制上方 Agent 命令派 L2 子 agent（推荐）② 跳过 L2：设置 FLOW_KIT_SKIP_L2=1 后重试 ③ 回退等待
   AC-5: L2 独立审查为质量门禁。跳过 L2 将仅依赖 L3 外部模型审查。
EOF
  fi
  exit 2
}

# _gate_check_l3 — L3 external review completion gate (~30 lines)
# Checks L3 done status, runs fix-compliance for phases 5/6/7, formats result.
# Returns 1 if L3 not done (caller should then call _gate_do_transition to block).
# Exits 0 if L3 not required or L3 done. Exits 2 on fix-compliance failure.
_gate_check_l3() {
  local gate_val="$1" review_md="$2" done_marker="$3" phase="$4" change_id="$5" cwd="$6"

  # ── L2 done or L3-only → determine if L3 needed ──
  if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
    # L2 已完成：仅当 gate_config 含 L3（both/L3）时才继续检查 L3
    if [[ "$gate_val" != "L3" && "$gate_val" != "both" ]]; then exit 0; fi
  elif [[ "$gate_val" == "L3" ]]; then
    :   # L3-only 模式，不需 L2，继续检查 L3
  elif [[ -z "$gate_val" ]]; then
    exit 0   # 修 BUG-D：gate_val 空（该 phase 未配 gate）→ 放行（旧 else exit 2 误拦未配 gate 的 phase）
  else
    # gate_val=both/L2 但 review_md 无 L2 段
    # AC-6: auto_advance 检测 — 不阻塞 transition（对齐 _gate_check_l2:290-302 fire-and-forget 语义）
    local flow_file="${cwd}/.flow-active"
    local auto_advance
    auto_advance=$(jq -r '.goal.auto_advance // false' "$flow_file" 2>/dev/null || echo "false")
    if [[ "$auto_advance" == "true" ]]; then
      cat >&2 <<EOF
[l3-gate] auto_advance: L2 section missing for phase ${phase} (gate_config=${gate_val}), not blocking.
   _gate_check_l2 should have intercepted this. L3 dispatch will proceed via return 1 → _gate_do_transition.
EOF
      return 1  # AC-6: 触发 || _gate_do_transition（与 line 406 return 1 合约一致）
    fi
    cat >&2 <<EOF
⛔ 独立 review gate（phase ${phase}）：状态异常 — gate_config=${gate_val} 但 ${review_md} 缺 L2 盲审段。
   _gate_check_l2 应已拦截。请检查 hook 调用顺序或 INDEPENDENT-REVIEW-${phase}.md 完整性。
EOF
    exit 2
  fi

  # ── L3 done → fix-compliance + format result ──
  if fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition" 2>/dev/null; then
    if [[ "$phase" =~ ^(5|6|7)$ ]]; then
      local fcl="${HOOK_BASE_DIR}/../stop/lib/fix-compliance.sh"
      if [ -f "$fcl" ]; then
        source "$fcl" 2>/dev/null || true
        type fk_fix_compliance_check >/dev/null 2>&1 && fk_fix_compliance_check "$phase" "$change_id" "${cwd}/.specs/${change_id}" "$cwd" || exit 2
      fi
    fi
    local dvl="${HOOK_BASE_DIR}/../stop/lib/done-validation.sh"
    local l3l="${HOOK_BASE_DIR}/../stop/lib/l3-review.sh"
    if [ -f "$dvl" ] && [ -f "$l3l" ]; then
      source "$dvl" 2>/dev/null || true; source "$l3l" 2>/dev/null || true
      if type _fk_done_kvp >/dev/null 2>&1 && type _l3_format_result >/dev/null 2>&1 && [ -f "$done_marker" ]; then
        set +e
        local l3v; l3v=$(_fk_done_kvp "$done_marker" "L3_verdict"); l3v="${l3v:-unknown}"
        local l3s; l3s=$(_fk_done_kvp "$done_marker" "L3_summary"); l3s="${l3s:-}"
        set -e
        _l3_format_result "$l3v" "$l3s" ".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
      fi
    fi
    exit 0
  fi

  return 1  # L3 not done → caller invokes _gate_do_transition
}
