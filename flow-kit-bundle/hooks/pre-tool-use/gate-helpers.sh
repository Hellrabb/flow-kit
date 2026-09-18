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
  local tool_name="$1" file_path="$2" cmd="$3" content="${4:-}" old_str="${5:-}"
  if [[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]]; then
    # ── ADR-026 载荷守卫（阶段 2 的 L3 critical ① · 23:23 加固）────────────────
    # 两道判据，任一命中即拒绝：
    #   ① **原文**是否构成段起点（`---` + 行首 `## L3 …`）；
    #   ② **解码后形态**是否构成段起点 —— 单射编码只保护写侧自动路径，校验不了手动贴入内容：
    #      「`---` + `\## L3 …` + 编码签名」会被 ① 放行，但读侧解码会把 `\## L3` 还原成 `## L3`
    #      → 真的形成 L3 段边界。
    # ② 只在内容**自带签名**时做（与读侧段级门控同门控）；无签名的纯引用（`\## L3 …`、无 `---`）
    # 读侧不会解码，也就不会成段 —— 保持放行（B9-R14）。
    if [[ "$file_path" == *INDEPENDENT-REVIEW-*.md ]]; then
      # Edit 组合绕过（阶段 2 的 L3 23:46 major②）：Edit 只给 old/new 片段，而「`---`」可能在
      # **文件现有内容**里、片段只插入标题行 —— 只查片段会漏。故先把 old→new 合成到现有内容上。
      # Bash 通道无法合成 → 该通道由 D14 的写入后自检兜底（文档已如实降级声明，不再宣称可拦）。
      local _probe="$content"
      if [[ "$tool_name" == "Edit" && -n "${5:-}" && -f "$file_path" ]]; then
        local _cur
        _cur=$(cat "$file_path" 2>/dev/null || true)
        case "$_cur" in
          *"${5}"*) _probe="${_cur/"${5}"/"$content"}" ;;
        esac
      fi
      local _deny_l3=0
      _gate_is_unescaped_l3_paste "$_probe" && _deny_l3=1
      if [ "$_deny_l3" -eq 0 ] && [[ "$_probe" == *"<!-- L2-PAYLOAD-ENCODED -->"* ]]; then
        # 内容自带签名 → 必须能验证**解码后**形态；解码器不可用时 fail-closed（04:46 critical②）
        local _dec _drc=0
        _dec=$(printf '%s\n' "$_probe" | _gate_l3_decode_payload) || _drc=$?
        if [ "$_drc" -ne 0 ]; then
          _deny_l3=3
        elif _gate_is_unescaped_l3_paste "$_dec"; then
          _deny_l3=2
        fi
      fi
      if [ "$_deny_l3" -eq 3 ]; then
        cat >&2 <<'GUARD_EOF'
⛔ L3 载荷守卫（ADR-026）：内容自带编码签名，但**解码器不可用**，无法验证「解码后形态」→ 按 fail-closed 拒绝。
   修法：`./sync-hooks.sh` 同步副本，或 `/flow doctor` 诊断；确认 `stop/lib/l2-detect.sh` 可被 source。
GUARD_EOF
        return 2
      fi
      if [ "$_deny_l3" -ne 0 ]; then
        cat >&2 <<'GUARD_EOF'
⛔ L3 载荷守卫（ADR-026）：禁止把会形成 L3 段起点的内容写入 INDEPENDENT-REVIEW-*.md。
   命中的形态（原文或**解码后**）：「`---` + 行首 `## L3 …`」。
   该形态会被判为 L3 段起点，后续 L3 写入会把它之后的正文静默删除（§B2 缺陷的成因）。
   注意：`\## L3 …` 只有在**没有编码签名**时才是安全引用 —— 带签名时读侧会把它解码回 `## L3`。
   处置（D11 #3 决策 b · 2026-09-19：**手动贴入已禁止**）：
     · L3 段只允许审查子系统写入：`l3_review_run` / `l2_dispatch_agent` 会自动转义后落盘；
     · 仍需引用 L3 标题时：**不要**带 `---` 前导，也**不要**带编码签名（纯引用形态放行）；
     · API 不可用时用子系统写出的 timeout / bypass 锚点，不要手写 L3 段。
   注：原第 ② 条"贴入前先过 `_l3_escape_payload`"已随决策 b 废止（它正是 03:36 critical① 的
   漏洞本体：带签名的转义块会被解码后判为真段起点）。
GUARD_EOF
        return 2
      fi
    fi
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
    # Bash 通道同判据（M37 · 阶段 2 的 L3 critical① 的通道覆盖）：命令文本里既**提及**评审文件、
    # 又含未转义的「--- + ## L3 …」块（heredoc / printf / cat 追加的正文都在命令文本里）→ 拒绝。
    if [[ "$cmd" == *INDEPENDENT-REVIEW-*.md* ]] && _gate_is_unescaped_l3_paste "$cmd"; then
      cat >&2 <<'GUARD_EOF'
⛔ L3 载荷守卫（ADR-026 · Bash 通道）：该命令同时提及 INDEPENDENT-REVIEW-*.md 与未转义的
   「`---` + 行首 `## L3 …`」块。此类写入会伪造 L3 段起点，后续 L3 写入将静默删除其后正文。
   处置：走审查子系统写入，或贴入前先过 `_l3_escape_payload`（引用时用 `\## L3 …`）。
GUARD_EOF
      return 2
    fi
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

