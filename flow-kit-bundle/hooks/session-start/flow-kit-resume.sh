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
