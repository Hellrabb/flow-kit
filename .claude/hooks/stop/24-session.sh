#!/bin/bash
# Module E — Session Analysis
# Checks: E1 (tool stats + timing), E2 (rtk optimization), E3 (subagent),
#         E4 (session duration), E5 (context-mode trends)
#
# Provides insights about the session itself — what happened, what could
# be improved, and usage patterns over time.

set -euo pipefail

# ── 阈值常量 ──────────────────────────────────────────────────────
readonly HIGH_USAGE_COUNT=20        # 工具调用高频阈值
readonly GP_WARNING_COUNT=3         # GateFlow 调用次数警戒线
readonly LONG_SESSION_SECS=7200     # 长会话阈值（2小时·秒）
readonly TOKEN_WARNING_THRESHOLD=100000  # 单会话 token 消耗警戒
readonly WEEKLY_HEAVY_THRESHOLD=20  # 周会话数高频阈值
# 以下比较使用通用值（-gt 0/ -lt 60/ -lt 3600），非业务阈值，保留裸数字

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "24" || true

module_enabled "session" || exit 0

# ── Helpers ───────────────────────────────────────────────────────────

# Format seconds as human-readable duration
format_duration() {
  local secs="$1"
  if [[ "$secs" -lt 60 ]]; then
    echo "${secs}s"
  elif [[ "$secs" -lt 3600 ]]; then
    echo "$((secs / 60))m $((secs % 60))s"
  else
    echo "$((secs / 3600))h $(((secs % 3600) / 60))m"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# E1: Tool usage statistics with timing analysis
# ═══════════════════════════════════════════════════════════════════════
check_e1_body() {

  if [[ ! -f "$HOOK_TMP_DIR/tool-counts.txt" ]]; then
    return 0
  fi

  local top_tools
  top_tools=$(head -5 "$HOOK_TMP_DIR/tool-counts.txt" | while read -r count tool; do
    printf "%s(%s) " "$tool" "$count"
  done)

  if [[ -n "$top_tools" ]]; then
    module_output "info" "E1" "工具使用 Top 5: ${top_tools}"
  fi

  # Count total tool calls
  local total_calls
  total_calls=$(awk '{sum += $1} END {print sum}' "$HOOK_TMP_DIR/tool-counts.txt" 2>/dev/null || echo "0")
  module_output "info" "E1" "总工具调用: ${total_calls} 次"

  # Most expensive tool by count
  local most_used most_count
  most_used=$(head -1 "$HOOK_TMP_DIR/tool-counts.txt" 2>/dev/null | awk '{print $2}')
  most_count=$(head -1 "$HOOK_TMP_DIR/tool-counts.txt" 2>/dev/null | awk '{print $1}')

  if [[ -n "$most_used" && "$most_count" -gt $HIGH_USAGE_COUNT ]]; then
    case "$most_used" in
      Bash|Read|Glob|Grep)
        module_output "suggestion" "E1" "高频工具 \`${most_used}\` (${most_count}次)。检查是否有优化空间（如合并 Read、使用 Agent 代理搜索）。"
        ;;
    esac
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# E2: rtk optimization opportunities
# ═══════════════════════════════════════════════════════════════════════
check_e2_body() {

  if [[ ! -f "$HOOK_TMP_DIR/bash-commands.txt" ]]; then
    return 0
  fi

  # Commands that rtk can proxy (from RTK.md)
  local rtk_commands=(
    '^git '
    '^docker '
    '^cargo '
    '^npm '
    '^pnpm '
    '^kubectl '
    '^terraform '
    '^aws '
    '^gcloud '
  )

  local missed=0 total_bash=0
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    total_bash=$((total_bash + 1))

    # Check if already using rtk
    if echo "$cmd" | grep -q '^rtk '; then
      continue
    fi

    # Check if any rtk-able command
    for pat in "${rtk_commands[@]}"; do
      if echo "$cmd" | grep -qE "$pat"; then
        missed=$((missed + 1))
        break
      fi
    done
  done < "$HOOK_TMP_DIR/bash-commands.txt"

  if [[ "$missed" -gt 0 ]]; then
    local pct=0
    if [[ "$total_bash" -gt 0 ]]; then
      pct=$((missed * 100 / total_bash))
    fi
    module_output "suggestion" "E2" "发现 ${missed} 个可被 rtk 代理的命令 (~${pct}% Bash 调用)。预估可节省 60-90% 输出 token。
参考: RTK.md 或运行 \`rtk discover\` 查看优化机会。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# E3: Subagent efficiency analysis
# ═══════════════════════════════════════════════════════════════════════
check_e3_body() {

  if [[ ! -f "$HOOK_TMP_DIR/subagent-usage.txt" || ! -s "$HOOK_TMP_DIR/subagent-usage.txt" ]]; then
    return 0
  fi

  local summary
  summary=$(head -10 "$HOOK_TMP_DIR/subagent-usage.txt" | while read -r count agent_type; do
    printf "%s:%s " "$agent_type" "$count"
  done)

  local total_agents
  total_agents=$(awk '{sum += $1} END {print sum}' "$HOOK_TMP_DIR/subagent-usage.txt" 2>/dev/null || echo "0")

  module_output "info" "E3" "Subagent 使用: ${total_agents} 次 — ${summary}"

  # Warn if using general-purpose agent heavily (could use specialized ones)
  local gp_count
  gp_count=$(grep 'general-purpose' "$HOOK_TMP_DIR/subagent-usage.txt" 2>/dev/null | awk '{print $1}' || echo "0")
  if [[ "$gp_count" -gt $GP_WARNING_COUNT ]]; then
    module_output "suggestion" "E3" "使用了 ${gp_count} 次 general-purpose agent。考虑使用专用 agent 类型以获得更好效果。"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# E4: Session duration and token estimation
# ═══════════════════════════════════════════════════════════════════════
check_e4_body() {

  local start_ts end_ts
  start_ts=$(cat "$HOOK_TMP_DIR/session-start-time" 2>/dev/null || echo "")
  end_ts=$(cat "$HOOK_TMP_DIR/session-end-time" 2>/dev/null || echo "")

  local rounds
  rounds=$(cat "$HOOK_TMP_DIR/message-rounds" 2>/dev/null || echo "?")

  # Duration
  if [[ -n "$start_ts" && -n "$end_ts" ]]; then
    local start_epoch end_epoch
    start_epoch=$(date -d "$start_ts" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$start_ts" +%s 2>/dev/null || echo "0")
    end_epoch=$(date -d "$end_ts" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$end_ts" +%s 2>/dev/null || echo "0")

    if [[ "$start_epoch" -gt 0 && "$end_epoch" -gt 0 ]]; then
      local duration=$((end_epoch - start_epoch))
      if [[ "$duration" -gt 0 ]]; then
        local dur_str
        dur_str=$(format_duration "$duration")
        module_output "info" "E4" "Session 时长: ${dur_str} | 轮次: ${rounds}"

        # Long session reminder
        if [[ "$duration" -gt $LONG_SESSION_SECS ]]; then
          module_output "suggestion" "E4" "Session 超过 2 小时 (${dur_str})。考虑适时休息和 /compact 释放上下文。"
        fi
      fi
    fi
  fi

  # Rough token estimate from transcript size
  if [[ -f "$TRANSCRIPT_PATH" ]]; then
    local chars
    chars=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
    local est_tokens=$((chars / 4))
    if [[ "$est_tokens" -gt $TOKEN_WARNING_THRESHOLD ]]; then
      module_output "info" "E4" "估算 token 消耗: ~${est_tokens} (transcript: $(du -h "$TRANSCRIPT_PATH" 2>/dev/null | cut -f1))"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# E5: context-mode trend tracking
# ═══════════════════════════════════════════════════════════════════════
check_e5_body() {

  # Check if context-mode MCP tools are available (non-blocking)
  if ! command -v ctx-stats &>/dev/null; then
    return 0
  fi

  # Record stop count in state for trend analysis (runtime-aware · dsh-flow-kit)
  local trend_file
  trend_file="${PROJECT_ROOT}/$(fk_runtime_config_dir 2>/dev/null || echo .claude)/stop-hook-trend.json"
  local current_date
  current_date=$(date '+%Y-%m-%d')

  # Load existing trends
  local trends_json="{}"
  if [[ -f "$trend_file" ]]; then
    trends_json=$(cat "$trend_file" 2>/dev/null || echo "{}")
  fi

  # Update today's count
  local today_count
  today_count=$(echo "$trends_json" | jq -r ".[\"$current_date\"] // 0" 2>/dev/null || echo "0")
  today_count=$((today_count + 1))

  # Update trend file
  echo "$trends_json" | jq --arg date "$current_date" --argjson count "$today_count" \
    '. + {($date): $count}' > "$trend_file" 2>/dev/null || true

  # Report weekly trend
  local weekly_total=0 weekly_days=0
  for i in {0..6}; do
    local d
    d=$(date -d "$i days ago" '+%Y-%m-%d' 2>/dev/null || date -v-${i}d '+%Y-%m-%d' 2>/dev/null || echo "")
    [[ -z "$d" ]] && continue
    local n
    n=$(echo "$trends_json" | jq -r ".[\"$d\"] // 0" 2>/dev/null || echo "0")
    if [[ "$n" -gt 0 ]]; then
      weekly_total=$((weekly_total + n))
      weekly_days=$((weekly_days + 1))
    fi
  done

  if [[ "$weekly_total" -gt $WEEKLY_HEAVY_THRESHOLD ]]; then
    module_output "info" "E5" "本周 Stop 频率较高: ${weekly_total} 次 / ${weekly_days} 天。context-mode 知识库持续增长中。"
  fi
}

check_e1() { run_check "session" "E1" "" check_e1_body; }
check_e2() { run_check "session" "E2" "" check_e2_body; }
check_e3() { run_check "session" "E3" "" check_e3_body; }
check_e4() { run_check "session" "E4" "" check_e4_body; }
check_e5() { run_check "session" "E5" "" check_e5_body; }
# ── Run all checks ──────────────────────────────────────────────────
check_e1
check_e2
check_e3
check_e4
check_e5

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "24" || true
