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
   快照 phase key 值被篡改（合法值: L2/L3/both/independent/true）。
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

        # 读 gate_config 当前阶段值（D1: both 模式 L2-wait）
        phase_name=""
        case "$phase" in
          1) phase_name="1-requirement" ;;
          2) phase_name="2-design" ;;
          3) phase_name="3-task" ;;
          5) phase_name="5-test" ;;
          6) phase_name="6-review" ;;
          7) phase_name="7-integration" ;;
        esac
        gate_val=$(jq -r --arg pn "$phase_name" \
          '.goal.gate_config[$pn] // ""' "$flow_file" 2>/dev/null || echo "")
        case "$gate_val" in independent|true) gate_val="both" ;; L2|L3|both) ;; *) gate_val="" ;; esac

        # 检查 L2 是否已完成
        review_md="${cwd}/.specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
        skip_marker="${cwd}/.specs/${change_id}/.skip-L2-${phase}"

        if [[ "$gate_val" == "both" ]] && { [ ! -f "$review_md" ] || ! grep -q "^## L2 盲审" "$review_md" 2>/dev/null; }; then
          # AC-5 option ②: FLOW_KIT_SKIP_L2 env var → write skip marker + allow
          if [[ "${FLOW_KIT_SKIP_L2:-}" == "1" ]]; then
            touch "$skip_marker" 2>/dev/null || true
            cat >&2 <<EOF
⚠️ 独立 review gate：L2 已跳过（FLOW_KIT_SKIP_L2=1）。
   标记文件: ${skip_marker}
   L3 继续执行（若 gate_config 含 L3）。
EOF
            # Continue to L3 below (don't exit)
          elif [ -f "$skip_marker" ]; then
            # Skip marker from previous attempt → allow
            cat >&2 <<EOF
⚠️ 独立 review gate：L2 已跳过（${skip_marker} 存在）。
   L3 继续执行（若 gate_config 含 L3）。
EOF
            # Continue to L3 below
          else
            # AC-5 option ①: output dispatch prompt + option ②③ hints
            l2_lib="${HOOK_BASE_DIR}/../stop/lib/l2-detect.sh"
            if [ -f "$l2_lib" ]; then
              source "$l2_lib" 2>/dev/null || true
              if type l2_dispatch_prompt >/dev/null 2>&1; then
                l2_dispatch_prompt "$phase" "$change_id" "${cwd}/.specs/${change_id}" >&2 2>/dev/null || true
              fi
            fi
            cat >&2 <<EOF
⛔ 独立 review gate：gate_config=both 但 L2 尚未完成。

   选项：
   ① 复制上方 Agent 命令派 L2 子 agent（推荐）
   ② 跳过 L2：设置 FLOW_KIT_SKIP_L2=1 后重试（需显式确认风险）
   ③ 回退等待：完成 L2 后重新执行 transition 即可

   AC-5: L2 独立审查为质量门禁。跳过 L2 将仅依赖 L3 外部模型审查。
EOF
            exit 2
          fi
        fi
        if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
          # L2 已完成 — 检查是否需要 L3
          if [[ "$gate_val" != "L3" && "$gate_val" != "both" ]]; then
            # L2-only 模式：L2 已完成，不跑 L3，直接放行
            exit 0
          fi
          # L3 needed (both mode with L2 done) — fall through to async dispatch below
        elif [[ "$gate_val" == "L3" ]]; then
          # L3-only 模式，无需 L2 前置 — fall through to async dispatch below
          :
        else
          # 无 L3 需求 — 继续 deny（L2 未完成且非 L3-only）
          exit 2
        fi

        # ══ L3 异步派发（共享 both+L3-only 路径）════
        # 不再同步调 l3_review_with_timeout(30s)——外部模型 API 响应远超 30s，
        # 超时写 verdict=timeout 假放行等于 L3 没跑。
        # 改为 L2 同款异步模式：检查 .done → 派发提示 → 拦截 → agent 异步跑 L3 → 重试放行

        # 先检查 L3 是否已由 Stop hook 或手动派发完成
        if fk_validate_done_marker "$done_marker" "$phase" "$change_id" "transition" 2>/dev/null; then
          # L3 已完成 → 实效性校验（仅 phase 5/6/7）+ 放行
          if [[ "$phase" =~ ^(5|6|7)$ ]]; then
            fix_compliance_lib="${HOOK_BASE_DIR}/../stop/lib/fix-compliance.sh"
            if [ -f "$fix_compliance_lib" ]; then
              source "$fix_compliance_lib" 2>/dev/null || true
              if type fk_fix_compliance_check >/dev/null 2>&1; then
                fk_fix_compliance_check "$phase" "$change_id" "${cwd}/.specs/${change_id}" "$cwd" || exit 2
              fi
            fi
          fi

          # F1: 输出 L3_RESULT 到 stdout（agent 可见）
          done_validation_lib="${HOOK_BASE_DIR}/../stop/lib/done-validation.sh"
          l3_lib="${HOOK_BASE_DIR}/../stop/lib/l3-review.sh"
          if [ -f "$done_validation_lib" ] && [ -f "$l3_lib" ]; then
            source "$done_validation_lib" 2>/dev/null || true
            source "$l3_lib" 2>/dev/null || true
            if type _fk_done_kvp >/dev/null 2>&1 && type _l3_format_result >/dev/null 2>&1 && [ -f "$done_marker" ]; then
              set +e
              l3v=$(_fk_done_kvp "$done_marker" "L3_verdict")
              l3v="${l3v:-unknown}"
              l3s=$(_fk_done_kvp "$done_marker" "L3_summary")
              l3s="${l3s:-}"
              set -e
              report=".specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
              _l3_format_result "$l3v" "$l3s" "$report"
            fi
          fi
          exit 0
        fi

        # L3 未完成 → 输出派发提示 + 拦截（异步模式）
        l3_lib="${HOOK_BASE_DIR}/../stop/lib/l3-review.sh"
        if [ -f "$l3_lib" ]; then
          source "$l3_lib" 2>/dev/null || true
          if type l3_dispatch_prompt >/dev/null 2>&1; then
            l3_dispatch_prompt "$phase" "$change_id" "${cwd}/.specs/${change_id}" "${gate_val:-both}" >&2
          fi
        fi

        # 确定 L2_verdict 用于派发提示中的参数
        l2v="skipped"
        if [[ "$gate_val" == "both" ]]; then
          l2v=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
          [ -n "$l2v" ] || l2v="fail"
        fi

        cat >&2 <<EOF
⛔ 独立 review gate：L3 外部模型审查未完成（phase ${phase}）。

   选项：
   ① 复制上方 L3 派发命令异步执行（推荐——外部模型需足够响应时间）
   ② 结束当前 session，Stop hook 会自动跑 L3（无 30s 超时压力）
   ③ 手动运行:
      source flow-kit-bundle/hooks/stop/lib/l3-review.sh && \\
      l3_review_run ${phase} ${change_id} .specs/${change_id} ${l2v} ${gate_val:-both}

   L3 完成后重新执行 phase transition / commit 即可放行。
EOF
        exit 2
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
