# shellcheck shell=bash
# gate-helpers.sh — gate helpers 聚合入口
#
# 来源: split from initial gate-helpers.sh
# change: td072-lib-split-2026-08
# date: 2026-08-03
#
# 结构: 聚合入口模式（CONTEXT.md 既有抽象）
#   本文件 source gate-helpers-types.sh 并保留本地 helper 函数
#   外部调用方仅 source 本文件（不变更）

set -euo pipefail

# Source type predicates from sub-lib
source "$(dirname "${BASH_SOURCE[0]}")/gate-helpers-types.sh"

# ── 本地 helper 函数（active / util / check）──

fk_check_gate_config_tamper() {
  local flow_file="$1" snapshot_file="$2"
  [[ -f "$flow_file" && -f "$snapshot_file" ]] || return 0
  jq empty "$flow_file" 2>/dev/null || return 1
  jq empty "$snapshot_file" 2>/dev/null || return 1
  local changed="" k cur
  local keys
  keys=$(jq -r '.gate_config | to_entries[]? | select(.value == "independent" or .value == "true" or .value == "both" or .value == "L2" or .value == "L3") | .key' "$snapshot_file" 2>/dev/null)
  for k in $keys; do
    cur=$(jq -r --arg k "$k" '.goal.gate_config[$k] // "missing"' "$flow_file" 2>/dev/null)
    case "$cur" in
      independent|true|both|L2|L3) ;;  # 合法值，未篡改
      *) changed=1; break ;;
    esac
  done
  [[ -z "$changed" ]]
}

_command_first_tokens() {
  local cmd="$1" out="" in_s=0 in_d=0 i ch
  for ((i=0; i<${#cmd}; i++)); do
    ch="${cmd:i:1}"
    if [[ "$ch" == "'" && "$in_d" == 0 ]]; then in_s=$((1-in_s))
    elif [[ "$ch" == '"' && "$in_s" == 0 ]]; then in_d=$((1-in_d))
    elif [[ "$in_s" == 0 && "$in_d" == 0 && ("$ch" == "&" || "$ch" == "|" || "$ch" == ";") ]]; then
      out+=$'\n'
    else
      out+="$ch"
    fi
  done
  local sub t0 t1 t2
  while IFS= read -r sub; do
    sub="${sub#"${sub%%[![:space:]]*}"}"
    [ -z "$sub" ] && continue
    read -r t0 t1 t2 _ <<< "$sub"
    echo "${t0:-}|${t1:-}|${t2:-}"
  done <<< "$out"
}

_gate_path_guard() {
  local tool_name="$1" file_path="$2" cmd="$3"
  if [[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]]; then
    if [[ "$file_path" == *.independent-review-*.done* ]]; then
      # 提取阶段号 N（文件路径中 .independent-review-<N>.done）
      local phase_num
      phase_num=$(echo "$file_path" | grep -oP '\.independent-review-\K[0-9]+(?=\.done)' 2>/dev/null || echo "")
      if [[ -n "$phase_num" ]] && _gate_is_l2_only "$phase_num" "$PROJECT_ROOT"; then
        return 0  # L2-only 例外放行
      fi
      cat >&2 <<'EOF'
⛔ path-guard（D7）：禁止直接写 .independent-review-*.done（作者性锚点）。
   agent 不得自产 .done 绕过 L3 审查——.done 须由审查子系统（l3_review_run / L2 子 agent）产出。
   例外：gate_config=L2 时主 agent 按协议写 .done 放行。
   如确需绕过（hotfix）：/flow gate-config 关闭对应阶段的独立审查。
EOF
      return 2
    fi
  elif [[ "$tool_name" == "Bash" ]]; then
    if _is_dotdone_write "$cmd" 2>/dev/null; then
      # 从命令中提取阶段号 N
      local phase_num
      phase_num=$(echo "$cmd" | grep -oP '\.independent-review-\K[0-9]+(?=\.done)' 2>/dev/null | head -1 || echo "")
      if [[ -n "$phase_num" ]] && _gate_is_l2_only "$phase_num" "$PROJECT_ROOT"; then
        return 0  # L2-only 例外放行
      fi
      cat >&2 <<'EOF'
⛔ path-guard（D7）：禁止 Bash 直接写 .independent-review-*.done（作者性锚点）。
   agent 不得自产 .done 绕过 L3 审查——.done 须由审查子系统（l3_review_run / L2 子 agent）产出。
   例外：gate_config=L2 时主 agent 按协议写 .done 放行。
   如确需绕过（hotfix）：/flow gate-config 关闭对应阶段的独立审查。
EOF
      return 2
    fi
  fi
  return 0
}

_gate_phase_filter() {
  local flow_file="$1"
  local change_id phase
  # AC-10: 使用 fk_resolve_phase 替代内联 pipeline scope 检测（含 phase [0-7] 值域校验 + 无效时回退 .phase）
  phase=$(fk_resolve_phase 2>/dev/null || echo "?")
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  echo "PHASE=${phase}"
  echo "CHANGE_ID=${change_id}"
  [[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || return 0
  { [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || return 0
  return 1
}

_gate_active_check() {
  local phase="$1" cwdd="${2:-$PWD}"
  local lib_dir="${HOOK_BASE_DIR}/../stop/lib"
  local dv_lib="${lib_dir}/done-validation.sh"
  [ -f "$dv_lib" ] || return 0
  # shellcheck source=/dev/null
  PROJECT_ROOT="$cwdd" source "$dv_lib" 2>/dev/null || return 0
  type fk_independent_review_gate_active >/dev/null 2>&1 || return 0
  PROJECT_ROOT="$cwdd" fk_independent_review_gate_active "$phase" 2>/dev/null || return 0
  return 1
}

_gate_done_validation() {
  local done_marker="$1" phase="$2" change_id="$3"
  fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition" 2>/dev/null
}

_gate_tamper_detect() {
  local flow_file="$1" snapshot_file="$2"
  if ! fk_check_gate_config_tamper "$flow_file" "$snapshot_file"; then
    cat >&2 <<'EOF'
⛔ 独立 review gate（D8 ⑥）：检测到 gate_config 篡改。
   .flow-active.goal.gate_config 与 .goal-snapshot.json（入库快照）不一致——
   快照 phase key 值被篡改（合法值: L2/L3/both/independent/true）。
   如确需调整 gate-config：用 /flow gate-config 重设（同时更新快照），或手动更新 .goal-snapshot.json 并 commit。
EOF
    return 2
  fi
  return 0
}

