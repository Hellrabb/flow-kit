#!/bin/bash
# flow-kit-resume.sh — SessionStart hook
# Detects .flow-active and displays a resume banner.
# Also checks .specs/STATE.md for ai_context_doc preference.

set -euo pipefail

readonly STALE_SESSION_HOURS=72   # 超过此时间的会话视为过期

# ── Gate: Subagent isolation ────────────────────────────────────────
HOOK_INPUT=$(cat)
if command -v jq &>/dev/null; then
  PARENT_SESSION=$(echo "$HOOK_INPUT" | jq -r '.parent_session_id // ""')
  if [[ -n "$PARENT_SESSION" ]]; then
    exit 0
  fi
  CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "$PWD")
else
  CWD="$PWD"
fi

# ── Detect project root ─────────────────────────────────────────────
PROJECT_ROOT="$CWD"
# Walk up to find .flow-active or .specs/
while [[ "$PROJECT_ROOT" != "/" ]]; do
  if [[ -f "$PROJECT_ROOT/.flow-active" ]] || [[ -d "$PROJECT_ROOT/.specs" ]]; then
    break
  fi
  PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

flow_file="${PROJECT_ROOT}/.flow-active"

# ── No .flow-active → nothing to resume ─────────────────────────────
if [[ ! -f "$flow_file" ]]; then
  exit 0
fi

# ── Validate JSON ───────────────────────────────────────────────────
if ! jq empty "$flow_file" 2>/dev/null; then
  exit 0
fi

# ── Interactive UI correction check ──────────────────────────────────
correction_file="${PROJECT_ROOT}/.flow-active.interactive-ui-fix"
if [[ -f "$correction_file" ]] && jq empty "$correction_file" 2>/dev/null; then
  corr_gate=$(jq -r '.gate_type // "unknown"' "$correction_file" 2>/dev/null)
  corr_tool=$(jq -r '.required_tool // "unknown"' "$correction_file" 2>/dev/null)
  corr_retry=$(jq -r '.retry_count // 0' "$correction_file" 2>/dev/null)

  if [[ "$corr_retry" -ge 2 ]]; then
    # Stop correction — too many consecutive skips, need human
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  🛑 交互 gate 连续跳过 ≥3 次                          ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  gate : %-44s ║\n" "${corr_gate:0:44}"
    printf "║  tool : %-44s ║\n" "${corr_tool:0:44}"
    echo "║                                                      ║"
    echo "║  弱模型反复跳过交互式 UI，请人工介入。                 ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    rm -f "$correction_file"
  else
    # Inject correction instruction
    urgency=""
    [[ "$corr_retry" -eq 1 ]] && urgency="（第 2 次提醒，上轮你跳过了）"
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️ 交互 UI 矫正：上轮你跳过了交互 gate               ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  gate : %-44s ║\n" "${corr_gate:0:44}"
    printf "║  应调用 : %-42s ║\n" "${corr_tool:0:42}"
    echo "║                                                      ║"
    if [[ "$corr_tool" == "AskUserQuestion" ]]; then
      echo "║  现在立即调用 AskUserQuestion 工具补上。              ║"
      echo "║  AskUserQuestion({ questions: [{ question: \"...\",   ║"
      echo "║    header: \"...\", options: [...] }] })              ║"
    elif [[ "$corr_tool" == "EnterPlanMode" ]]; then
      echo "║  现在立即调用 EnterPlanMode 工具进入计划模式。        ║"
    fi
    echo "║                                                      ║"
    printf "║  %-50s ║\n" "${urgency}"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    # Don't delete correction file yet — the Stop hook will clear it
    # after the model successfully calls the tool this turn.
  fi
fi

# ── Compliance correction check ─────────────────────────────────────
compliance_correction_file="${PROJECT_ROOT}/.flow-active.correction"
if [[ -f "$compliance_correction_file" ]] && jq empty "$compliance_correction_file" 2>/dev/null; then
  corr_type=$(jq -r '.type // "unknown"' "$compliance_correction_file" 2>/dev/null)
  corr_count=$(jq -r '.violations | length // 0' "$compliance_correction_file" 2>/dev/null)

  if [[ "$corr_type" == "compliance" && "$corr_count" -gt 0 ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️ 合规矫正：上轮弱模型违规                          ║"
    echo "╠══════════════════════════════════════════════════════╣"

    # List violations grouped by layer
    idx=0
    while [[ "$idx" -lt "$corr_count" ]]; do
      v_layer=$(jq -r ".violations[$idx].layer // \"?\"" "$compliance_correction_file" 2>/dev/null)
      v_rule=$(jq -r ".violations[$idx].rule // \"?\"" "$compliance_correction_file" 2>/dev/null)
      v_location=$(jq -r ".violations[$idx].location // \"?\"" "$compliance_correction_file" 2>/dev/null)
      v_fix=$(jq -r ".violations[$idx].fix // \"?\"" "$compliance_correction_file" 2>/dev/null)

      printf "║  [%s] %-44s ║\n" "${v_layer:0:3}" "${v_rule:0:44}"
      printf "║  loc: %-46s ║\n" "${v_location:0:46}"
      printf "║  fix: %-46s ║\n" "${v_fix:0:46}"
      if [[ "$idx" -lt $((corr_count - 1)) ]]; then
        echo "║  ────────────────────────────────────────────────── ║"
      fi
      idx=$((idx + 1))
    done

    echo "║                                                      ║"
    echo "║  请按上述修复动作逐项执行，完成后继续任务。            ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
  else
    # Unknown type or empty violations — warn and clean up
    echo "[flow-kit-resume] ⚠️ .flow-active.correction 格式异常（type=${corr_type} count=${corr_count}），已清除" >&2
  fi

  rm -f "$compliance_correction_file"
fi

# ── Independent review report injection (L3 feedback · F2) ──────────
ir_change=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null)
ir_phase=$(jq -r '.goal.current_phase // .phase // "?"' "$flow_file" 2>/dev/null)
ir_done="${PROJECT_ROOT}/.specs/${ir_change}/.independent-review-${ir_phase}.done"
ir_review_md="${PROJECT_ROOT}/.specs/${ir_change}/INDEPENDENT-REVIEW-${ir_phase}.md"

if [[ "$ir_change" != "none" && -f "$ir_done" ]] && grep -q "## L3 外部模型审查" "$ir_review_md" 2>/dev/null; then
  # Source shared libs for _l3_format_result() and _fk_done_kvp()
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  l3_lib="${script_dir}/../stop/lib/l3-review.sh"
  done_validation_lib="${script_dir}/../stop/lib/done-validation.sh"
  [ -f "$l3_lib" ] && source "$l3_lib" 2>/dev/null || true
  [ -f "$done_validation_lib" ] && source "$done_validation_lib" 2>/dev/null || true

  if type _fk_done_kvp >/dev/null 2>&1 && type _l3_format_result >/dev/null 2>&1; then
    set +e
    l3v=$(_fk_done_kvp "$ir_done" "L3_verdict")
    l3v="${l3v:-unknown}"
    l3s=$(_fk_done_kvp "$ir_done" "L3_summary")
    l3s="${l3s:-}"
    set -e
    report=".specs/${ir_change}/INDEPENDENT-REVIEW-${ir_phase}.md"
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  🔎 独立 review 就绪（L3 外部模型）                  ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  verdict : %-43s ║\n" "${l3v:0:43}"
    printf "║  summary : %-43s ║\n" "${l3s:0:43}"
    printf "║  report  : %-43s ║\n" "${report:0:43}"
    echo "║                                                      ║"
    echo "║  确认 L2 盲审段就绪后，写 done 即可切阶段/commit。    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
  fi
fi

# ── Read fields ─────────────────────────────────────────────────────
change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null)
phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null)
task_id=$(jq -r '.task_id // "none"' "$flow_file" 2>/dev/null)
token_spent=$(jq -r '.token_spent // 0' "$flow_file" 2>/dev/null)
int_file=$(jq -r '.interrupt.active_file // ""' "$flow_file" 2>/dev/null)
int_action=$(jq -r '.interrupt.last_action // ""' "$flow_file" 2>/dev/null)
int_ts=$(jq -r '.interrupt.checkpoint_at // ""' "$flow_file" 2>/dev/null)

# ── Check staleness ─────────────────────────────────────────────────
now=$(date +%s)
f_ts=$(stat -c %Y "$flow_file" 2>/dev/null || stat -f %m "$flow_file" 2>/dev/null || echo "$now")
age_hours=$(((now - f_ts) / 3600))

# ── Phase label ─────────────────────────────────────────────────────
phase_label() {
  case "$1" in
    0) echo "变更提案" ;;
    1) echo "需求定义" ;;
    2|2a) echo "技术设计" ;;
    3) echo "任务拆解" ;;
    4) echo "开发实施" ;;
    5) echo "测试验证" ;;
    6) echo "代码审查" ;;
    7) echo "集成发布" ;;
    *) echo "未知" ;;
  esac
}

p_label=$(phase_label "$phase")

# ── Build banner ────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  📐 flow-kit 活跃 Change                             ║"
echo "╠══════════════════════════════════════════════════════╣"

# change_id line
printf "║  change : %-42s ║\n" "${change_id:-?}"

# phase line
printf "║  phase  : %-2s (%-34s) ║\n" "$phase" "$p_label"

# task line (if active)
if [[ "$task_id" != "none" && "$task_id" != "null" && -n "$task_id" ]]; then
  printf "║  task   : %-42s ║\n" "$task_id"
fi

goal_cond=$(jq -r '.goal.condition // ""' "$flow_file" 2>/dev/null)
goal_status=$(jq -r '.goal.status // ""' "$flow_file" 2>/dev/null)
goal_turns=$(jq -r '.goal.turns // 0' "$flow_file" 2>/dev/null)
goal_mode=$(jq -r '.goal.mode // ""' "$flow_file" 2>/dev/null)

# goal line (if active)
if [[ -n "$goal_cond" && "$goal_cond" != "null" && "$goal_status" == "active" ]]; then
  mode_label="回退"
  [[ "$goal_mode" == "native" ]] && mode_label="原生"
  printf "║  🎯 goal : %-41s ║\n" "${goal_cond:0:41}"
  printf "║        状态: active | turns: %-3s | 模式: %-8s ║\n" "$goal_turns" "$mode_label"
fi

# interrupt line (if present)
if [[ -n "$int_action" && "$int_action" != "null" ]]; then
  printf "║  ⚡ 中断 : %-40s ║\n" "${int_action:0:40}"
  if [[ -n "$int_file" && "$int_file" != "null" ]]; then
    printf "║        文件: %-37s ║\n" "${int_file:0:37}"
  fi
fi

# token line (if > 0)
if [[ "$token_spent" != "0" && "$token_spent" != "null" && -n "$token_spent" ]]; then
  tk_k=$((token_spent / 1000))
  printf "║  token  : ~%dk 已消耗                              ║\n" "$tk_k"
fi

# staleness warning
if [[ "$age_hours" -gt $STALE_SESSION_HOURS ]]; then
  days=$((age_hours / 24))
  printf "║  ⚠️  %d 天未活动                                      ║\n" "$days"
fi

echo "║                                                      ║"
echo "║  /flow-go 继续    /flow 状态    /flow stop            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
