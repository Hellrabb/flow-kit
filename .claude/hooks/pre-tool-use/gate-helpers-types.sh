# shellcheck shell=bash
# gate-helpers-types.sh — gate 类型谓词（聚合入口子文件）
#
# 来源: split from gate-helpers.sh
# change: td072-lib-split-2026-08
# date: 2026-08-03
#
# 函数（6 个 type 谓词，自包含无外部依赖）:
#   _is_dotdone_write            — .done 文件写入检测
#   _gate_is_l2_only             — gate_config L2-only 模式判定
#   is_phase_write               — phase 字段写入检测
#   _fk_phase_direction          — phase 推进方向判定
#   _command_has_write_context   — 命令含写上下文检测
#   is_git_commit                — git commit 命令检测

set -euo pipefail

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

_fk_phase_direction() {
  local c="$1" cur="$2"
  local target
  target=$(echo "$c" | grep -oP 'current_phase[[:space:]]*=[[:space:]]*"\K[0-7]' | head -1 || echo "")
  if [[ -z "$target" ]]; then echo "noop"; return 0; fi
  if [[ "$target" < "$cur" ]]; then echo "rollback"; return 0; fi
  if [[ "$target" == "$cur" ]]; then echo "noop"; return 0; fi
  echo "forward"
}

_command_has_write_context() {
  local cmd="$1"
  [[ "$cmd" == *"<<"* ]] && return 0
  return 1
}

is_git_commit() {
  _command_has_write_context "$1" && return 1
  local line t0 t1
  while IFS= read -r line; do
    IFS='|' read -r t0 t1 _ <<< "$line"
    [[ "$t0" == "git" && "$t1" == "commit" ]] && return 0
  done < <(_command_first_tokens "$1")
  return 1
}

