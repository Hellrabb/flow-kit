#!/bin/bash
# independent-review-gate.sh — PreToolUse 硬拦截（独立 review gate）
#
# settings.json matcher: ["Bash","Write","Edit"]（D7 扩面 · T07）。
# 拦：git commit / gh pr create / 改 .flow-active 阶段的 jq（Bash）/ Write+Edit 直写握手文件。
# 当某 change 在阶段 1/2/3/5/6/7 开启了独立 review（gate_config 或 stop-hook.json phases）
# 且未完成（无 .specs/<id>/.independent-review-<phase>.done），命中 commit/PR/阶段切换 → exit 2 deny。
#
# path-guard（D7）：Write/Edit/Bash 写 .flow-active.independent-review 握手文件 → exit 2 deny（所有阶段，
#   防 agent 预备伪造 L3 证据；29号 hook 子进程直写不经 PreToolUse，独占放行）。
#
# fail 策略（D9）：path-guard = fail-open（拦不住不卡 agent 工具流）；review gate 校验 = fail-close。
# 其余不确定（非 Bash/Write/Edit、无 .flow-active、阶段非 review gate、gate 未开、lib 失败、jq 不可用）→ exit 0 放行。
#
# PreToolUse stdin: {hook_event_name, session_id, cwd, tool_name, tool_input:{command|file_path}, ...}

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# ══ helper 函数（source-safe · check.sh / bats 可复用，不依赖 stdin）══════════

# is_handshake_write <cmd> — 检测 Bash 命令是否写 .flow-active.independent-review（D7 · 29号独占写）
# 返回 0 = 是握手写（deny）; 1 = 否（放行）
# v1 非穷尽：挡常见 > / >> / tee / cp / mv / sed -i / printf / dd of= / install / awk / heredoc；
#            exotic（python-c / base64 / 变量间接）留 v2 加密签名（DESIGN §6 · R12）
is_handshake_write() {
  local c="$1"
  [[ "$c" == *.flow-active.independent-review* ]] || return 1
  [[ "$c" =~ \>[^=] ]] && return 0                      # > / >> 重定向（排除 >=）
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

# fk_check_gate_config_tamper <flow_file> <snapshot_file> — D8 ⑥ gate_config 篡改检测
# diff .flow-active.goal.gate_config 与 .goal-snapshot.json 的 gate_config
# 返回 0 = 无篡改（放行）; 1 = 有篡改（deny · fail-close）
# 文件不存在 → 兼容历史，不挡（return 0）；文件存在但 jq 解析失败 → fail-close deny（return 1 · G1 D7 · agent 不能靠制造 hook 错误放行）
# 只查快照中标记为 independent/true 的 key，由开到关/删除 → 篡改；新增 key 不触发
fk_check_gate_config_tamper() {
  local flow_file="$1" snapshot_file="$2"
  [[ -f "$flow_file" && -f "$snapshot_file" ]] || return 0
  jq empty "$flow_file" 2>/dev/null || return 1
  jq empty "$snapshot_file" 2>/dev/null || return 1
  local changed="" k cur
  local keys
  keys=$(jq -r '.gate_config | to_entries[]? | select(.value == "independent" or .value == "true") | .key' "$snapshot_file" 2>/dev/null)
  for k in $keys; do
    cur=$(jq -r --arg k "$k" '.goal.gate_config[$k] // "missing"' "$flow_file" 2>/dev/null)
    [[ "$cur" != "independent" && "$cur" != "true" ]] && { changed=1; break; }
  done
  [[ -z "$changed" ]]
}

is_phase_write() {
  local c="$1"
  [[ "$c" == *.flow-active* ]] || return 1
  if [[ "$c" =~ \.tmp[[:space:]]*&&[[:space:]]*mv ]]; then :;
  elif [[ "$c" =~ tee[[:space:]]+\.flow-active ]]; then :;
  elif [[ "$c" =~ \>[^=] ]]; then :;
  else return 1; fi
  [[ "$c" =~ \.flow-active.*\.phase[[:space:]]*= ]] && return 0
  [[ "$c" =~ \.flow-active.*\.goal\.current_phase[[:space:]]*= ]] && return 0
  [[ "$c" =~ \.flow-active.*\.goal\.phases_done ]] && return 0
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
is_git_commit() {
  [[ "$1" =~ (^|[[:space:]])git[[:space:]]+commit([[:space:]]|$) ]]
}
is_gh_pr_create() {
  [[ "$1" =~ (^|[[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$) ]]
}

# ══ 主逻辑（仅直接执行时跑 · source 时只定义 helper，不读 stdin）═══════════
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  command -v jq >/dev/null 2>&1 || exit 0
  INPUT=$(cat)

  tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  case "$tool_name" in Bash|Write|Edit) ;; *) exit 0;; esac

  cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
  cwd=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
  [ -n "$cwd" ] || cwd="$PWD"
  file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

  flow_file="${cwd}/.flow-active"
  [ -f "$flow_file" ] || exit 0
  jq empty "$flow_file" 2>/dev/null || exit 0

  # ── path-guard（D7 · fail-open）── 拦 agent 写握手文件（所有阶段，防预备伪造）──
  if [[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]]; then
    if [[ "$file_path" == *.flow-active.independent-review* ]]; then
      cat >&2 <<EOF
⛔ path-guard（D7）：禁止 ${tool_name} 直接写 .flow-active.independent-review（29号 hook 独占写）。
   agent 不得自产 L3 握手证据。如确需绕过（hotfix）：由 29号 hook 子进程写，或 /flow gate-config 关闭。
EOF
      exit 2
    fi
  elif [[ "$tool_name" == "Bash" ]]; then
    if is_handshake_write "$cmd" 2>/dev/null; then
      cat >&2 <<EOF
⛔ path-guard（D7）：禁止 Bash 直接写 .flow-active.independent-review（29号 hook 独占写）。
   agent 不得自产 L3 握手证据。如确需绕过（hotfix）：由 29号 hook 子进程写，或 /flow gate-config 关闭。
EOF
      exit 2
    fi
  fi

  # ── review gate 段（仅 1/2/3/5/6/7 阶段且 gate 开启）──
  # pipeline 模式优先读 goal.current_phase；单阶段模式读 phase（pipeline-fallback-fix UAT 发现）
  scope=$(jq -r '.goal.scope // ""' "$flow_file" 2>/dev/null || echo "")
  if [[ "$scope" == "pipeline" ]]; then
    phase=$(jq -r '.goal.current_phase // "?"' "$flow_file" 2>/dev/null || echo "?")
  else
    phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
  fi
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  [[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || exit 0
  { [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0

  PROJECT_ROOT="$cwd"
  artifacts_lib="${HOOK_BASE_DIR}/../stop/lib/flow-kit-artifacts.sh"
  [ -f "$artifacts_lib" ] || exit 0
  # shellcheck source=/dev/null
  source "$artifacts_lib" 2>/dev/null || exit 0
  type fk_independent_review_gate_active >/dev/null 2>&1 || exit 0
  fk_independent_review_gate_active "$phase" 2>/dev/null || exit 0

  done_marker="${cwd}/.specs/${change_id}/.independent-review-${phase}.done"
  # ── Tier 1+2 .done 真实性校验（D1/D5/G1 · fk_validate_done_marker · fail-close）──
  # 有效 done（return 0）→ 放行；无效（return 2）→ 继续 deny 段
  # fail-close: jq 不可用/解析异常/畸形输入 → return 2 deny（agent 不能靠制造 hook 内部错误放行）
  if fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition" 2>/dev/null; then
    exit 0
  fi

  # D8 ⑥ gate_config 篡改检测（Tier 2 · fail-close）
  snapshot_file="${cwd}/.specs/${change_id}/.goal-snapshot.json"
  if ! fk_check_gate_config_tamper "$flow_file" "$snapshot_file"; then
    cat >&2 <<EOF
⛔ 独立 review gate（D8 ⑥）：检测到 gate_config 篡改。
   .flow-active.goal.gate_config 与 .goal-snapshot.json（入库快照）不一致——
   快照 phase key 由 independent/true → false/缺失。
   如确需调整 gate-config：用 /flow gate-config 重设（同时更新快照），或手动更新 .goal-snapshot.json 并 commit。
EOF
    exit 2
  fi

  # ── P0-1/F1 · L3 前置 + P0-3/F3 · 方向判定 ──
  if is_phase_write "$cmd"; then
    cur_phase=$(jq -r '.goal.current_phase // ""' "$flow_file" 2>/dev/null || echo "")
    dir=$(_fk_phase_direction "$cmd" "$cur_phase")
    case "$dir" in
      rollback)
        # 回退放行（不要求 .done）—— AC-3
        cat >&2 <<EOF
⏎ 独立 review gate：检测到回退操作（phase ${cur_phase} → 更早阶段），放行不要求 .done。
EOF
        exit 0
        ;;
      noop)
        # no-op 放行（状态维护操作）—— AC-3b
        exit 0
        ;;
      forward)
        # 前进 → 尝试 L3 前置

        # 检查 L2 是否已完成
        review_md="${cwd}/.specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
        if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
          # L2 已完成，尝试同步 L3
          l3_lib="${HOOK_BASE_DIR}/../stop/lib/l3-review.sh"
          if [ -f "$l3_lib" ]; then
            source "$l3_lib" 2>/dev/null || true
            if type l3_review_with_timeout >/dev/null 2>&1; then
              # 从 INDEPENDENT-REVIEW-<N>.md 提取 L2 verdict
              l2v=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
              [ -n "$l2v" ] || l2v="fail"  # 无法提取时默认 fail
              spec_dir="${cwd}/.specs/${change_id}"
              cat >&2 <<EOF
⏳ L3 独立审查中（外部模型 · phase ${phase}）...
EOF
              l3_review_with_timeout "$phase" "$change_id" "$spec_dir" "$l2v" 30 2>/dev/null || true
              # L3 完成后重试 .done 校验
              if fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition" 2>/dev/null; then
                exit 0
              fi
            fi
          fi
        fi
        # L2 未完成或 L3 后仍无效 → 继续 deny
        ;;
    esac
  fi

  phase_name=""
  case "$phase" in
    1) phase_name="1-requirement" ;;
    2) phase_name="2-design" ;;
    3) phase_name="3-task" ;;
    5) phase_name="5-test" ;;
    6) phase_name="6-review" ;;
    7) phase_name="7-integration" ;;
  esac

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
fi
