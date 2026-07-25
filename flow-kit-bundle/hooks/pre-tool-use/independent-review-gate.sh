#!/bin/bash
# independent-review-gate.sh — PreToolUse 硬拦截（独立 review gate）
#
# settings.json matcher: ["Bash","Write","Edit"]（D7 扩面 · T07）。
# 拦：git commit / gh pr create / 改 .flow-active 阶段的 jq（Bash）/ Write+Edit 直写握手文件。
# 当某 change 在阶段 1/2/3/5/6/7 开启了独立 review（gate_config 或 stop-hook.json phases）
# 且未完成（无 .specs/<id>/.independent-review-<phase>.done），命中 commit/PR/阶段切换 → exit 2 deny。
#
# path-guard（D7 扩展 · 方案 A）：Write/Edit/Bash 写 .independent-review-*.done → exit 2 deny（作者性锚点，
#   防 agent 伪造 .done 绕过 L3 审查）。L2-only 例外：gate_config=L2 时 agent 按协议写 .done 放行。
#   l3_review_run 写 .done 不被拦截——在 Stop hook 进程运行不经过 PreToolUse（架构天然隔离）。
#   原保护对象 .flow-active.independent-review（握手）已废弃——改为 .done 作为新作者性锚点。
#
# fail 策略（D9）：path-guard = fail-open（拦不住不卡 agent 工具流）；review gate 校验 = fail-close。
# 其余不确定（非 Bash/Write/Edit、无 .flow-active、阶段非 review gate、gate 未开、lib 失败、jq 不可用）→ exit 0 放行。
#
# PreToolUse stdin: {hook_event_name, session_id, cwd, tool_name, tool_input:{command|file_path}, ...}

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# D1（ADR-007 · l2-l3-mock-fix）：fk_phase_gate_key 定义在 common.sh（单一来源），
# gate.sh source common.sh 获取该 fn。D7 的"局部 declare 隔离 source 副作用"已废弃——
# common.sh 顶层仅函数定义 + 默认值（: "${VAR:=}"），source-safe；L3 当初担心的
# "config_get 污染 PreToolUse"是误判（函数定义 source 不执行）。29 已 source common.sh 且 work。
COMMON_LIB="${HOOK_BASE_DIR}/../stop/lib/common.sh"
# shellcheck source=/dev/null
source "$COMMON_LIB" 2>/dev/null || true
# T-FIX-02（R2 · 6-review L2）：fail-close——fk_phase_gate_key 未定义（common.sh 加载失败）→ deny exit 2
# 原 || true 后 local phase_name 得空 → gate 失效 exit 0（fail-open），与 header fail-close 矛盾
if ! declare -f fk_phase_gate_key >/dev/null 2>&1; then
  echo "[gate] common.sh 加载失败（HOOK_BASE_DIR=${HOOK_BASE_DIR}），review gate fail-close：fk_phase_gate_key 未定义，拒绝放行" >&2
  exit 2
fi

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

# is_gh_pr_create — 结构判定（ADR-008 D2·H）：同 is_git_commit，token0=gh ∧ token1=pr ∧ token2=create
is_gh_pr_create() {
  _command_has_write_context "$1" && return 1
  local line t0 t1 t2
  while IFS= read -r line; do
    IFS='|' read -r t0 t1 t2 _ <<< "$line"
    [[ "$t0" == "gh" && "$t1" == "pr" && "$t2" == "create" ]] && return 0
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

# ══ _run_review_gates() · 编排器（≤40 行 · DESIGN D2）════
_run_review_gates() {
  local tool_name="$1" file_path="$2" cmd="$3" cwd="$4"

  local flow_file="${cwd}/.flow-active"
  [ -f "$flow_file" ] || exit 0
  jq empty "$flow_file" 2>/dev/null || exit 0

  # Gate 1: path-guard (D7 · fail-open)
  _gate_path_guard "$tool_name" "$file_path" "$cmd" || exit 2

  # Gate 2: phase filter → extract phase + change_id
  # _gate_phase_filter 语义：return 0=skip(非review phase/无效change_id)，return 1=continue
  # ⚠️ 与 bash `||` 惯例（非0=失败）相反 → 用 if 显式判定（修 BUG-A/B 反转：
  #    旧 `|| exit 0` 使 review phase return1→放行(gate失效)、phase0 return0→继续(误拦)，双向错）
  local pf_output phase change_id
  if pf_output=$(_gate_phase_filter "$flow_file" 2>/dev/null); then
    exit 0   # return 0 = skip → 放行（phase 0/4、无 change_id 走这里）
  fi
  phase=$(echo "$pf_output" | grep "^PHASE=" | cut -d= -f2-)
  change_id=$(echo "$pf_output" | grep "^CHANGE_ID=" | cut -d= -f2-)

  # Gate 3: gate active check
  # _gate_active_check 语义：return 0=gate未开(skip)，return 1=gate开(continue) — 同样反向，用 if 判定
  if _gate_active_check "$phase" "$cwd" 2>/dev/null; then
    exit 0   # return 0 = gate 未开 → 放行
  fi

  # Gate 4: done validation (Tier 1+2)
  local done_marker="${cwd}/.specs/${change_id}/.independent-review-${phase}.done"
  if _gate_done_validation "$done_marker" "$phase" "$change_id"; then exit 0; fi

  # Gate 5: tamper detection (D8)
  local snapshot_file="${cwd}/.specs/${change_id}/.goal-snapshot.json"
  _gate_tamper_detect "$flow_file" "$snapshot_file" || exit 2

  # Gate 6: phase transition (L2/L3 dispatch · may exit 0 or 2 internally)
  _gate_phase_transition "$cmd" "$phase" "$change_id" "$cwd" "$flow_file"

  # Gate 7: deny reason (commit/PR/phase write)
  _gate_deny_reason "$cmd" "$phase" "$change_id" "$cwd" || exit 2

  exit 0
}

# ══ 入口（精简为 stdin 解析 + 调用 _run_review_gates · DESIGN D2）════
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT=$(cat)

  tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  case "$tool_name" in Bash|Write|Edit) ;; *) exit 0;; esac

  cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
  cwd=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
  [ -n "$cwd" ] || cwd="$PWD"
  file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

  _run_review_gates "$tool_name" "$file_path" "$cmd" "$cwd"
fi
