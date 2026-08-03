# gate-helpers.sh — 独立 review gate 辅助函数库
# source: split from independent-review-gate.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 提供 PreToolUse gate 所需的全部小型辅助/检测函数。
# 被 independent-review-gate.sh 在顶层 source。
# 注意：本文件不含 shebang（作为 sourced lib 使用）。

# ══ helper 函数（source-safe · check.sh / bats 可复用，不依赖 stdin）══════════

# _is_dotdone_write <cmd> — 检测 Bash 命令是否写 .independent-review-*.done（D7 扩展 · agent 不可写 .done）
# 方案 A：path-guard D7 保护 .done 文件（替代废弃的握手文件 .flow-active.independent-review）
# 返回 0 = 是 .done 写（deny）; 1 = 否（放行）
# 写路径匹配继承原 is_handshake_write 的 11 种模式（> / >> / tee / cp / mv / sed -i / printf / dd of= / install / awk / heredoc）
# exotic（python -c / base64 / 变量间接）留 v2 加密签名
_is_dotdone_write() {
  local c="$1"
  [[ "$c" == *.independent-review-*.done* ]] || return 1
  local re_redirect='[>][^=]'  # TD-015：变量化 \>[^=] 须用字符类
  [[ "$c" =~ $re_redirect ]] && return 0                # > / >> 重定向（排除 >=）
  [[ "$c" =~ (^|[[:space:]])tee[[:space:]] ]] && return 0
  [[ "$c" =~ (cp|mv)[[:space:]] ]] && return 0
  [[ "$c" =~ sed[[:space:]].*(-i|--in-place) ]] && return 0
  [[ "$c" =~ printf[[:space:]] ]] && return 0
  [[ "$c" =~ dd[[:space:]].*of= ]] && return 0
  [[ "$c" =~ install[[:space:]] ]] && return 0
  [[ "$c" =~ awk[[:space:]] ]] && return 0
  [[ "$c" == *"cat <<"* ]] && return 0
  return 1
}

# _gate_is_l2_only <phase_num> <cwd> — 检查 gate_config 对该阶段是否仅需 L2（允许 agent 写 .done）
# 返回 0 = L2-only（放行 agent 写 .done）; 1 = 需要 L3/both 或读取失败（拦截）
# L2-only 模式例外：gate_config=L2 时协议要求主 agent 写 .done，path-guard 须放行
# gate_config 读取失败 → fail-open 放行（D3 决策）
_gate_is_l2_only() {
  local phase_num="$1" cwd="${2:-$PWD}"
  local flow_file="${cwd}/.flow-active"
  [[ -f "$flow_file" ]] || return 0  # 无 .flow-active → fail-open 放行
  local phase_name
  phase_name=$(fk_phase_gate_key "$phase_num" 2>/dev/null || echo "")
  [[ -n "$phase_name" ]] || return 0  # phase_name 解析失败 → fail-open 放行
  local gate_val
  gate_val=$(jq -r --arg pn "$phase_name" '.goal.gate_config[$pn] // ""' "$flow_file" 2>/dev/null || echo "")
  [[ "$gate_val" == "L2" ]] && return 0  # L2-only → 放行
  return 1  # L3/both/未配 → 拦截
}

# fk_check_gate_config_tamper <flow_file> <snapshot_file> — D8 ⑥ gate_config 篡改检测
# diff .flow-active.goal.gate_config 与 .goal-snapshot.json 的 gate_config
# 返回 0 = 无篡改（放行）; 1 = 有篡改（deny · fail-close）
# 文件不存在 → 兼容历史，不挡（return 0）；文件存在但 jq 解析失败 → fail-close deny（return 1 · G1 D7 · agent 不能靠制造 hook 错误放行）
# 只查快照中标记为有效 gate_config 值的 key，由开到关/删除 → 篡改；新增 key 不触发
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

is_phase_write() {
  local c="$1"
  [[ "$c" == *.flow-active* ]] || return 1
  # TD-011 fix：regex 存变量——内联 [[ "$c" =~ \.tmp...&&...mv ]] 的 && 被 [[ ]] 当逻辑与（SC2157），正则被劈两半 → 仅匹配 .tmp+空格、&&/mv 检测失效。变量化后 && 是 regex 字面，正确匹配 atomic-write 模式。
  # TD-015 fix：\>[^=] 变量化须用 [>][^=] 字符类（内联 \> 是字面 > 正常，但变量 re='\>[^=]' 触发 GNU 单词边界 → 误判）。
  local re_tmp_mv='\.tmp[[:space:]]*&&[[:space:]]*mv'
  local re_redirect='[>][^=]'
  if [[ "$c" =~ $re_tmp_mv ]]; then :;
  elif [[ "$c" =~ tee[[:space:]]+\.flow-active ]]; then :;
  elif [[ "$c" =~ $re_redirect ]]; then :;
  else return 1; fi
  # TD-014 fix：不要求 .flow-active 出现在字段名之前——L67 已保证命令涉及 .flow-active。
  # 真实 jq 写命令字段名在前（jq 表达式里）、.flow-active 是文件名在后；旧 regex `\.flow-active.*\.phase=`
  # 顺序反了 → 永不匹配 → is_phase_write 对所有真实 jq phase-write 漏检（rc=1）→ gate 可绕过。
  [[ "$c" =~ \.phase[[:space:]]*= ]] && return 0
  [[ "$c" =~ \.goal\.current_phase[[:space:]]*= ]] && return 0
  [[ "$c" =~ \.goal\.phases_done ]] && return 0
  return 1
}

# _fk_phase_direction() — 判定 phase write 的方向 (P0-3/F3 修复)
# 参数: $1 = command string, $2 = current_phase from .flow-active
# 输出: "rollback" (target < current) | "forward" (target > current) | "noop" (target == current or no target)
_fk_phase_direction() {
  local c="$1" cur="$2"
  local target
  target=$(echo "$c" | grep -oP 'current_phase[[:space:]]*=[[:space:]]*"\K[0-7]' | head -1 || echo "")
  if [[ -z "$target" ]]; then echo "noop"; return 0; fi
  if [[ "$target" < "$cur" ]]; then echo "rollback"; return 0; fi
  if [[ "$target" == "$cur" ]]; then echo "noop"; return 0; fi
  echo "forward"
}
# _command_has_write_context <cmd> — 写字面量上下文检测（ADR-008 D2·H · T-FIX-01 R1 收紧）
# 只 heredoc(<<) → return 0（不 deny：heredoc 内容可能是审查文本含敏感词，BUG-H 根治）。
# T-FIX-01（6-review L2 R1）：移除「多行(\n) / 重定向(> 非/dev/null) → 写上下文」——
#   重定向/多行的真实 git commit 须走 token 判定 deny（AC-H(e)）。fd 合并(2>&1)/重定向走 token。
# 已知限制（L2 重审 RR3 · heredoc << 短路覆盖的真实 commit bypass，v1 诚实登记，v2 加密签名根治）：
#   (i)  `git commit -F - <<EOF`（heredoc 作 message 输入）
#   (ii) `git commit -m "$(cat <<EOM\n...\nEOM)"`（多行 message 惯用法）
#   (iii)`cat <<EOF | xargs -I {} git commit -m {}`（heredoc 管道喂 commit）
#   三者因 << 短路判为写上下文不 deny（旧正则可 deny，residual regression）。v2 改加密签名根治。
_command_has_write_context() {
  local cmd="$1"
  [[ "$cmd" == *"<<"* ]] && return 0
  return 1
}

# _command_first_tokens <cmd> — 引号感知 split &|; → 各子命令前 3 token（ADR-008 D2·H）
# 保守：单/双引号内的分隔符不 split（引号内 "&& git commit" 不误判为子命令，回应 Consequences）。
# 输出：每行 "t0|t1|t2"（前 3 token，不足补空），供 is_git_commit/is_gh_pr_create 逐行检查 token 序列。
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

# is_git_commit — 结构判定（ADR-008 D2·H · BUG-H 根治）
# 写上下文 → 不 deny；否则任一子命令 token0=git ∧ token1=commit → deny。
# 不再用正则 [[ =~ git commit ]]（不识 quoting/heredoc）。
# 反规避 (f)：token 序列判定（"git"/"commit" 分开比较），无字面 'git commit' 白黑名单。
is_git_commit() {
  _command_has_write_context "$1" && return 1
  local line t0 t1
  while IFS= read -r line; do
    IFS='|' read -r t0 t1 _ <<< "$line"
    [[ "$t0" == "git" && "$t1" == "commit" ]] && return 0
  done < <(_command_first_tokens "$1")
  return 1
}

# ══ Gate check functions (extracted from main logic · DESIGN D2 · 7 gates) ══

# _gate_path_guard — D7 扩展：禁止 agent 写 .independent-review-*.done（方案 A · 作者性锚点）
# 原保护对象 .flow-active.independent-review（握手文件）已废弃——改为保护 .done 文件
# L2-only 例外：gate_config=L2 时协议要求主 agent 写 .done → path-guard 放行
# l3_review_run 写 .done 不被拦截——因在 Stop hook 进程运行不经过 PreToolUse（架构天然隔离）
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

# _gate_phase_filter — only phases 1/2/3/5/6/7 with valid change_id proceed
# stdout: PHASE=<v>\nCHANGE_ID=<v> ；return 0=skip(not review phase), 1=continue
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

# _gate_active_check — verify independent review gate is enabled for this phase
# 修 BUG-E：fk_independent_review_gate_active 定义在 done-validation.sh（非 artifacts.sh），
#   且依赖 PROJECT_ROOT。旧代码只 source artifacts.sh → type 失败 → 永远 return 0（gate 永远未开，
#   所有 review phase 的 commit/transition 在 Gate3 放行，gate 形同虚设）。
#   改为 source done-validation.sh + 传 PROJECT_ROOT=cwd。
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

# _gate_done_validation — Tier 1+2 .done authenticity check (fail-close)
_gate_done_validation() {
  local done_marker="$1" phase="$2" change_id="$3"
  fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition" 2>/dev/null
}

# _gate_tamper_detect — D8 gate_config tamper detection (fail-close)
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
