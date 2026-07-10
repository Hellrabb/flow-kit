#!/bin/bash
# banner.sh — Resume banner builder (sourceable lib)
# Provides build_resume_banner() for SessionStart hook and bats tests.
# Source from: flow-kit-resume.sh or test files.
#
# Usage:
#   source hooks/stop/lib/banner.sh
#   build_resume_banner "/path/to/.flow-active"

set -euo pipefail

readonly STALE_SESSION_HOURS=72   # sessions older than this are marked stale

# ── Phase label helper ────────────────────────────────────────────────
_phase_label() {
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

# ── build_resume_banner() ─────────────────────────────────────────────
# Reads .flow-active JSON and outputs an ASCII art status banner to stdout.
# On error (missing file / invalid JSON), outputs error to stderr and returns 1.
build_resume_banner() {
  local flow_file="${1:-}"

  # ── Input validation ──────────────────────────────────────────────────
  if [[ -z "$flow_file" ]]; then
    echo "[banner] ERROR: flow_file path is required" >&2
    return 1
  fi

  if [[ ! -f "$flow_file" ]]; then
    echo "[banner] ERROR: flow_file not found: $flow_file" >&2
    return 1
  fi

  if ! jq empty "$flow_file" 2>/dev/null; then
    echo "[banner] ERROR: flow_file is not valid JSON: $flow_file" >&2
    return 1
  fi

  # ── Read fields ──────────────────────────────────────────────────────
  local change_id phase task_id token_spent
  local int_file int_action
  local goal_cond goal_status goal_turns goal_mode

  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null)
  phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null)
  task_id=$(jq -r '.task_id // "none"' "$flow_file" 2>/dev/null)
  token_spent=$(jq -r '.token_spent // 0' "$flow_file" 2>/dev/null)
  int_file=$(jq -r '.interrupt.active_file // ""' "$flow_file" 2>/dev/null)
  int_action=$(jq -r '.interrupt.last_action // ""' "$flow_file" 2>/dev/null)
  goal_cond=$(jq -r '.goal.condition // ""' "$flow_file" 2>/dev/null)
  goal_status=$(jq -r '.goal.status // ""' "$flow_file" 2>/dev/null)
  goal_turns=$(jq -r '.goal.turns // 0' "$flow_file" 2>/dev/null)
  goal_mode=$(jq -r '.goal.mode // ""' "$flow_file" 2>/dev/null)

  # ── Compute staleness ────────────────────────────────────────────────
  local now f_ts age_hours
  now=$(date +%s)
  f_ts=$(stat -c %Y "$flow_file" 2>/dev/null || stat -f %m "$flow_file" 2>/dev/null || echo "$now")
  age_hours=$(((now - f_ts) / 3600))

  # ── Phase label ──────────────────────────────────────────────────────
  local p_label
  p_label=$(_phase_label "$phase")

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

  # goal line (if active)
  if [[ -n "$goal_cond" && "$goal_cond" != "null" && "$goal_status" == "active" ]]; then
    local mode_label="回退"
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
    local tk_k=$((token_spent / 1000))
    printf "║  token  : ~%dk 已消耗                              ║\n" "$tk_k"
  fi

  # staleness warning
  if [[ "$age_hours" -gt $STALE_SESSION_HOURS ]]; then
    local days=$((age_hours / 24))
    printf "║  ⚠️  %d 天未活动                                      ║\n" "$days"
  fi

  echo "║                                                      ║"
  echo "║  /flow-go 继续    /flow 状态    /flow stop            ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
}
