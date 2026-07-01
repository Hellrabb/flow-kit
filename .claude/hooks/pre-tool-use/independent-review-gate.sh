#!/bin/bash
# independent-review-gate.sh — PreToolUse 硬拦截（独立 review gate）
#
# settings.json matcher: "Bash"。拦 git commit / gh pr create / 改 .flow-active 阶段的 jq。
# 当某 change 在阶段 1/2/6 开启了独立 review（gate_config 或 stop-hook.json phases）
# 且未完成（无 .specs/<id>/.independent-review-<phase>.done），命中上述命令 → exit 2 deny
# （stderr 反馈主 agent）；其余放行。
#
# PreToolUse stdin: {hook_event_name, session_id, cwd, tool_name, tool_input:{command}, ...}
#
# fail-open 原则：任何不确定（非 Bash、无 .flow-active、阶段非 1/2/6、gate 未开、
# lib 加载失败、jq 不可用）→ exit 0 放行。硬拦截宁可漏拦也不能卡死用户。

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# jq 不可用 → fail-open
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)

# 只拦 Bash 工具
tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
[ "$tool_name" = "Bash" ] || exit 0

cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
[ -n "$cmd" ] || exit 0

cwd=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$cwd" ] || cwd="$PWD"

flow_file="${cwd}/.flow-active"
[ -f "$flow_file" ] || exit 0
jq empty "$flow_file" 2>/dev/null || exit 0

phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
[[ "$phase" =~ ^(1|2|6)$ ]] || exit 0
{ [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0

# gate 判断：复用 fk_independent_review_gate_active（source lib），source 失败 → fail-open
PROJECT_ROOT="$cwd"
artifacts_lib="${HOOK_BASE_DIR}/../stop/lib/flow-kit-artifacts.sh"
[ -f "$artifacts_lib" ] || exit 0
# shellcheck source=/dev/null
source "$artifacts_lib" 2>/dev/null || exit 0
type fk_independent_review_gate_active >/dev/null 2>&1 || exit 0
# gate 未生效（返回 1）→ 放行；gate 生效（返回 0）→ 进入命令匹配
fk_independent_review_gate_active "$phase" 2>/dev/null || exit 0

# done 标志存在 → 放行
done_marker="${cwd}/.specs/${change_id}/.independent-review-${phase}.done"
[ -f "$done_marker" ] && exit 0

phase_name=""
case "$phase" in
  1) phase_name="1-requirement" ;;
  2) phase_name="2-design" ;;
  6) phase_name="6-review" ;;
esac

# ── 命令分类匹配（写信号必须同时存在，防纯读 jq 误伤）──
is_phase_write() {
  local c="$1"
  [[ "$c" == *.flow-active* ]] || return 1
  # 写信号之一：.tmp && mv / tee .flow-active / > 重定向（排除 >=）
  if [[ "$c" =~ \.tmp[[:space:]]*&&[[:space:]]*mv ]]; then :;
  elif [[ "$c" =~ tee[[:space:]]+\.flow-active ]]; then :;
  elif [[ "$c" =~ \>[^=] ]]; then :;
  else return 1; fi
  # jq 表达式改阶段字段（.phase = 或 .goal.current_phase =，空格可选）
  [[ "$c" =~ \.phase[[:space:]]*= ]] && return 0
  [[ "$c" =~ \.goal\.current_phase[[:space:]]*= ]] && return 0
  return 1
}
is_git_commit() {
  [[ "$1" =~ (^|[[:space:]])git[[:space:]]+commit([[:space:]]|$) ]]
}
is_gh_pr_create() {
  [[ "$1" =~ (^|[[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$) ]]
}

deny_reason=""
if is_phase_write "$cmd"; then
  deny_reason="阶段 ${phase} (${phase_name}) 切换"
elif is_git_commit "$cmd"; then
  deny_reason="git commit"
elif is_gh_pr_create "$cmd"; then
  deny_reason="gh pr create"
fi

if [ -n "$deny_reason" ]; then
  cat >&2 <<EOF
⛔ 独立 review gate：阶段 ${phase} (${phase_name}) 独立 review 未完成，禁止 ${deny_reason}。
   需先完成 L2（盲审子 agent → INDEPENDENT-REVIEW-${phase}.md）+ L3（Stop hook 调外部模型），
   再由主 agent 写 ${done_marker} 后重试。
   如确需绕过（hotfix）：touch ${done_marker}，或 /flow gate-config ${phase_name}=off 关闭。
EOF
  exit 2
fi
exit 0
