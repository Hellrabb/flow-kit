#!/bin/bash
# Module G — Workflow State
# Checks: G1 (flow-kit status + artifact验证 + 自动推进 + stale检测 + diff边界),
#         G2 (stash files), G3 (temp file cleanup),
#         G4 (PUA Loop status),
#         G5 (interrupt快照 + PROGRESS日志 + token累积)
#
# Lightweight file-system checks that surface workflow/state reminders.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "26" || true

# Source flow-kit artifacts library (provides fk_* helpers)
FK_LIB="${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh"
if [[ -f "$FK_LIB" ]]; then
  source "$FK_LIB"
fi

module_enabled "workflow" || exit 0

# ── Helpers ───────────────────────────────────────────────────────────

# File age in days
file_age_days() {
  local f="$1"
  if [[ ! -f "$f" ]]; then echo "0"; return; fi
  local now f_ts
  now=$(date +%s)
  f_ts=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$now")
  echo $(((now - f_ts) / 86400))
}

# ═══════════════════════════════════════════════════════════════════════
# G1: Flow-kit state (enhanced — artifact validation + auto phase + stale)
# ═══════════════════════════════════════════════════════════════════════
check_g1_body() {

  local flow_file="${PROJECT_ROOT}/.flow-active"
  if [[ ! -f "$flow_file" ]]; then
    return 0
  fi

  # Validate JSON
  if ! jq empty "$flow_file" 2>/dev/null; then
    module_output "warning" "G1" ".flow-active JSON 格式无效，建议手动检查"
    return 0
  fi

  local change_id phase task_id
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "?")
  phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
  task_id=$(jq -r '.task_id // "none"' "$flow_file" 2>/dev/null || echo "?")

  local status_line="flow-kit: phase=${phase}"
  [[ "$change_id" != "none" && "$change_id" != "?" ]] && status_line+=" change=${change_id}"
  [[ "$task_id" != "none" && "$task_id" != "?" ]] && status_line+=" task=${task_id}"

  # ── 1. Artifact validation (Phase B2) ──
  if [[ "$change_id" != "none" && "$change_id" != "?" ]]; then
    if command -v fk_artifact_check &>/dev/null; then
      local art_output
      art_output=$(fk_artifact_check "$change_id" "$phase" 2>&1) || true
      if [[ -n "$art_output" ]]; then
        echo "$art_output" >> "$HOOK_TMP_DIR/workflow.txt"
      fi
    fi
  fi

  # ── 2. Auto phase transition detection (Phase A2) ──
  # D5·K (ADR-011): pipeline goal 模式不 auto-advance .phase——推进权归 toll-gate
  #   （/flow 人工 + 31-auto-advance.sh 完整 transition），避免 pipeline goal 在 review 未开阶段
  #   （fk_independent_review_gate_active=false）被 G1 静默推进，造 phase/current_phase 不一致（AC-K）。
  #   单阶段 goal（scope=phase 或无 goal.scope）保留原 auto-advance。fk_auto_phase 函数不改（仅调用方加守卫）。
  local goal_scope
  goal_scope=$(jq -r '.goal.scope // "phase"' "$flow_file" 2>/dev/null || echo "phase")
  local next_phase=""
  if [[ "$change_id" != "none" && "$change_id" != "?" && "$goal_scope" != "pipeline" ]]; then
    if command -v fk_auto_phase &>/dev/null; then
      next_phase=$(fk_auto_phase "$change_id" "$phase" 2>/dev/null) || true
      # fk_auto_phase may output info messages to stderr — capture those
      local auto_hint
      auto_hint=$(fk_auto_phase "$change_id" "$phase" 2>&1 1>/dev/null) || true
    fi
  fi

  # ── 3. Phase-to-next-action mapping ──
  local hint=""
  if [[ -n "$next_phase" ]]; then
    # Auto-advance possible
    local old_phase="$phase"
    jq ".phase = \"$next_phase\" | .updated_at = \"$(date -Iseconds)\"" \
      "$flow_file" > "${flow_file}.tmp" && mv "${flow_file}.tmp" "$flow_file"
    module_output "info" "G1" "${status_line} → 自动推进到 phase ${next_phase}（检测到条件满足）"
    phase="$next_phase"  # Update for subsequent checks
    status_line="flow-kit: phase=${phase} change=${change_id}"
    [[ "$task_id" != "none" && "$task_id" != "?" ]] && status_line+=" task=${task_id}"
  else
    case "$phase" in
      0)  hint="建议 /flow-change 创建变更提案" ;;
      1)  hint="建议 /flow-design 进行技术设计" ;;
      2|2a) hint="建议 /flow-task 拆解任务" ;;
      3)  hint="建议 /flow-dev 开始开发" ;;
      4)  hint="建议 /flow-test 执行测试" ;;
      5)  hint="建议 /flow-review 代码审查" ;;
      6)  hint="建议 /flow-integration 集成发布" ;;
      7)  hint="完成！建议 /flow stop" ;;
      *)  hint="" ;;
    esac
    if [[ -n "$hint" ]]; then
      module_output "info" "G1" "${status_line} → ${hint}"
    else
      module_output "info" "G1" "${status_line}"
    fi
  fi

  # ── 4. Stale change detection (Phase C4) ──
  if command -v fk_stale_check &>/dev/null; then
    local stale_output
    stale_output=$(fk_stale_check 2>&1) || true
    if [[ -n "$stale_output" ]]; then
      echo "$stale_output" >> "$HOOK_TMP_DIR/workflow.txt"
    fi
  fi

  # ── 5. Diff boundary check (Phase C2) ──
  if [[ "$change_id" != "none" && "$change_id" != "?" ]]; then
    if command -v fk_boundary_check &>/dev/null; then
      local boundary_output
      boundary_output=$(fk_boundary_check "$change_id" "$task_id" 2>&1) || true
      if [[ -n "$boundary_output" ]]; then
        echo "$boundary_output" >> "$HOOK_TMP_DIR/workflow.txt"
      fi
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# G2: Stash / patch / todo file detection
# ═══════════════════════════════════════════════════════════════════════
check_g2_body() {

  local stash_files=()
  local patterns=("*.patch" "*.diff" "*.todo" "WIP_*" "TODO_*")

  for pat in "${patterns[@]}"; do
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      # Skip files inside node_modules or .git
      case "$f" in
        */node_modules/*|*/.git/*|*/.claude/worktrees/*) continue ;;
      esac
      stash_files+=("$f")
    done < <(find "$PROJECT_ROOT" -maxdepth 3 -name "$pat" -type f 2>/dev/null | head -10)
  done

  if [[ ${#stash_files[@]} -gt 0 ]]; then
    local file_list
    file_list=$(printf '  %s\n' "${stash_files[@]}" | sort -u)
    module_output "suggestion" "G2" "发现暂存/临时文件:
${file_list}
这些文件可能已完成使命，建议清理。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# G3: Temp file cleanup reminder
# ═══════════════════════════════════════════════════════════════════════
check_g3_body() {

  # Check for plan/report files older than 3 days
  local old_plans=()
  local max_age_days=3
  local plan_patterns=(
    "*实施计划*.md"
    "*质量报告*.md"
    "*implementation*plan*.md"
    "*review*report*.md"
  )

  for pat in "${plan_patterns[@]}"; do
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      case "$f" in
        */node_modules/*|*/.git/*|*/.claude/worktrees/*|*/ARCHITECTURE.md|*/SPEC.md) continue ;;
      esac

      local age
      age=$(file_age_days "$f")
      if [[ "$age" -gt "$max_age_days" ]]; then
        old_plans+=("$f (${age}d)")
      fi
    done < <(find "$PROJECT_ROOT" -maxdepth 3 -name "$pat" -type f 2>/dev/null | head -10)
  done

  if [[ ${#old_plans[@]} -gt 0 ]]; then
    local file_list
    file_list=$(printf '  %s\n' "${old_plans[@]}" | sort -u)
    module_output "suggestion" "G3" "发现过期临时文档 (>${max_age_days}天):
${file_list}
参考「临时文档不进 git」规则 — 这些是一次性消耗品，执行完应删除。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# G4: PUA Loop status
# ═══════════════════════════════════════════════════════════════════════
check_g4_body() {

  local pua_dir="${HOME}/.claude/pua"
  if [[ ! -d "$pua_dir" ]]; then
    return 0
  fi

  # Check for active loop files
  local loop_files
  loop_files=$(find "$pua_dir" -maxdepth 1 -name "loop-*.md" -type f 2>/dev/null || true)

  if [[ -z "$loop_files" ]]; then
    return 0
  fi

  while IFS= read -r lf; do
    [[ -z "$lf" ]] && continue
    local fname age
    fname=$(basename "$lf")
    age=$(file_age_days "$lf")

    # Check heartbeat: recently modified = active
    # Use find -mmin for recency check
    local recently_active
    recently_active=$(find "$lf" -mmin -10 2>/dev/null || echo "")

    if [[ -n "$recently_active" ]]; then
      module_output "info" "G4" "PUA Loop 活跃: ${fname} (最近 10 分钟内有活动)"
    else
      # Stale loop file
      if [[ "$age" -gt 1 ]]; then
        module_output "suggestion" "G4" "PUA Loop 文件较旧: ${fname} (${age}天)。如果不活跃，建议 /pua:reap-orphans 清理。"
      fi
    fi
  done <<< "$loop_files"
}

# ═══════════════════════════════════════════════════════════════════════
# G5: Interrupt snapshot + PROGRESS log + Token accumulation (NEW)
# ═══════════════════════════════════════════════════════════════════════
check_g5_body() {

  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 0

  local change_id phase task_id
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
  task_id=$(jq -r '.task_id // "none"' "$flow_file" 2>/dev/null || echo "none")

  [[ "$change_id" != "none" && "$change_id" != "?" ]] || return 0

  # ── 5a. Interrupt snapshot (Phase A1) ──
  if command -v fk_snapshot_interrupt &>/dev/null; then
    fk_snapshot_interrupt
  fi

  # ── 5b. Estimate tokens from this session (reuse Module E data if available) ──
  local token_est="?"
  if [[ -f "${HOOK_TMP_DIR}/token-estimate.txt" ]]; then
    token_est=$(cat "${HOOK_TMP_DIR}/token-estimate.txt" 2>/dev/null || echo "?")
  fi

  # ── 5c. PROGRESS.md logging (Phase B3) ──
  if command -v fk_log_progress &>/dev/null; then
    fk_log_progress "$change_id" "$phase" "$task_id" "$token_est" "$SESSION_ID"
  fi

  # ── 5d. Token accumulation (Phase C1) ──
  if command -v fk_accumulate_tokens &>/dev/null && [[ "$token_est" != "?" ]]; then
    fk_accumulate_tokens "$token_est"
  fi

  # Show token total if available
  local total_tokens
  total_tokens=$(jq -r '.token_spent // 0' "$flow_file" 2>/dev/null || echo "0")
  if [[ "$total_tokens" != "0" && "$total_tokens" != "null" ]]; then
    local total_k=$((total_tokens / 1000))
    module_output "info" "G5" "本次 session ~${token_est} tokens | 累计 ~${total_k}k tokens (change=${change_id})"
  fi
}

check_g1() { run_check "workflow" "G1" "" check_g1_body; }
check_g2() { run_check "workflow" "G2" "" check_g2_body; }
check_g3() { run_check "workflow" "G3" "" check_g3_body; }
check_g4() { run_check "workflow" "G4" "" check_g4_body; }
check_g5() { run_check "workflow" "G5" "" check_g5_body; }
# ── Run all checks ──────────────────────────────────────────────────
check_g1
check_g2
check_g3
check_g4
check_g5

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "26" || true
