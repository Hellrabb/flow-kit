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
#
# refactor: split into gate-helpers.sh + gate-checks-basic.sh + gate-checks-review.sh (change: final-debt-cleanup-2026-08, date: 2026-08-03, closes TD-018)

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

# ── source 拆分后的子库（final-debt-cleanup-2026-08 · TD-018）──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/gate-helpers.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/gate-checks-basic.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/gate-checks-review.sh"

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

# ══ _run_review_gates() · 编排器（≤40 行 · DESIGN D2）════
_run_review_gates() {
  local tool_name="$1" file_path="$2" cmd="$3" cwd="$4"

  local flow_file="${cwd}/.flow-active"
  [ -f "$flow_file" ] || exit 0
  jq empty "$flow_file" 2>/dev/null || exit 0

  # Runtime decoupling (dsh-flow-kit): PreToolUse hooks never call init_paths(),
  # so PROJECT_ROOT (used by fk_resolve_phase and the gate libs) must be pinned
  # to the cwd carried by the synthesized stdin event. Stop hooks already set it
  # via init_paths(). This also fixes the Claude Code path when the host does
  # not export PROJECT_ROOT into hook subprocesses.
  PROJECT_ROOT="$cwd"
  export PROJECT_ROOT

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
