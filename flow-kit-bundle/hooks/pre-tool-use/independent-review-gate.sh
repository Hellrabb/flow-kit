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
# fail 策略（D9 · C12/health-fix-2026-09c 修订）：path-guard = fail-open（拦不住不卡 agent 工具流）；review gate 校验 = fail-close。
# 依赖失效面 fail-closed（C12 · AC-8）：jq 缺失、状态档非法 JSON、子库关键函数缺失 → exit 2 拒绝放行（见 :114/:65 与子库断言块）。
# 其余非管辖面仍 exit 0 放行：非 Bash/Write/Edit、无 .flow-active（= 非 flow-kit 项目）、阶段非 review gate、gate 未开。
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

# C12（health-fix-2026-09c · AC-8 第三注入面）：三子库 source 后按 :34-37 既有 declare -f 范式
# 断言关键函数在场；半安装/漂移（子库文件缺失、函数被删/改名）→ fail-close exit 2。
# 「函数被遮蔽/重定义为空体」不在断言范围——declare -f 只证存在不证行为（DESIGN D4）。
for _gate_fn in _gate_path_guard _gate_phase_filter _gate_active_check _gate_done_validation \
                _gate_tamper_detect fk_check_gate_config_tamper is_phase_write is_git_commit \
                _gate_check_l2 _gate_check_l3 \
                _gate_phase_transition _gate_do_transition _gate_deny_reason; do
  if ! declare -f "$_gate_fn" >/dev/null 2>&1; then
    echo "[gate] 子库加载失败（SCRIPT_DIR=${SCRIPT_DIR}），review gate fail-close：${_gate_fn} 未定义，拒绝放行" >&2
    exit 2
  fi
done
unset _gate_fn

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
  local tool_name="$1" file_path="$2" cmd="$3" cwd="$4" content="${5:-}" old_str="${6:-}"

  # ── 状态文件唯一解析入口（T13 / ADR-031 / AC-12-g）─────────────────────
  # 本 hook 禁止内联 jq/while-read 解析状态文件，一律经 flow-active-query.sh。
  # probe 候选 = ① bundle 内 lib/（源树 flow-kit-bundle/lib/ 与 dist/runtime 的
  # vendor/flow-kit-bundle/lib/ 同构）；② 插件包布局 vendor 副本（hooks 位于
  # <pkg>/hooks、lib 位于 <pkg>/vendor/flow-kit-bundle/lib/）；都缺 = 旧式
  # 安装（安装面尚未携带 lib/flow-active-query.sh）→ stderr 警告 + 放行（与
  # 「无状态文件 = 非管辖项目」同语义；重装 flow-kit / 源仓同步后启用解析）。
  local fa_query="" _cand
  for _cand in "${HOOK_BASE_DIR}/../../lib/flow-active-query.sh" "${HOOK_BASE_DIR}/../../vendor/flow-kit-bundle/lib/flow-active-query.sh"; do
    if [ -f "$_cand" ]; then fa_query="$_cand"; break; fi
  done
  if [ -z "$fa_query" ]; then
    echo "[gate] flow-active-query.sh 不在场（旧式安装；重装 flow-kit 或源仓 make hooks-sync 后启用状态文件解析）→ 降级放行" >&2
    exit 0
  fi
  # flow-active-query rc 语义：0=在场且合法（stdout=文件路径）；1=不在场（非管辖
  # 项目 → 放行，C12 保留语义）；2=jq 缺失 / 非法 JSON → exit 2 fail-close
  # （AC-8：不再静默放行；rc2 时 stderr 已透传 query 的具名报文）。
  local flow_file="" _fq_rc=0
  flow_file="$(bash "$fa_query" --root "$cwd" --print-file)" || _fq_rc=$?
  case "$_fq_rc" in
    0) ;;
    1) exit 0 ;;
    *) echo "[gate] review gate fail-close：.flow-active 非法 JSON 或 jq 不可用（flow-active-query rc=${_fq_rc}），拒绝放行。状态文件可能正在写入，重试一次；持续失败请修复该文件后重试" >&2; exit 2 ;;
  esac

  # Runtime decoupling (dsh-flow-kit): PreToolUse hooks never call init_paths(),
  # so PROJECT_ROOT (used by fk_resolve_phase and the gate libs) must be pinned
  # to the cwd carried by the synthesized stdin event. Stop hooks already set it
  # via init_paths(). This also fixes the Claude Code path when the host does
  # not export PROJECT_ROOT into hook subprocesses.
  PROJECT_ROOT="$cwd"
  export PROJECT_ROOT

  # Gate 1: path-guard (D7 · fail-open)
  _gate_path_guard "$tool_name" "$file_path" "$cmd" "$content" "$old_str" || exit 2

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
  # C12/AC-8：jq 缺失 → exit 2 fail-close（原 exit 0 静默放行 = C12 对照表实证的 fail-open 漏洞）
  command -v jq >/dev/null 2>&1 || { echo "[gate] jq 不可用，review gate fail-close：无法解析 hook stdin JSON，拒绝放行（安装 jq 或检查 PATH 后重试）" >&2; exit 2; }
  INPUT=$(cat)

  tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  case "$tool_name" in Bash|Write|Edit) ;; *) exit 0;; esac

  cmd=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
  cwd=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
  [ -n "$cwd" ] || cwd="$PWD"
  file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
  # Write 的 content / Edit 的 new_string —— 供 ADR-026 载荷守卫检查（缺省空串 → 不拦截）
  content=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null || echo "")
  # Edit 的 old_string —— 供守卫把 old→new 合成到现有内容上（major 2）
  old_str=$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null || echo "")

  _run_review_gates "$tool_name" "$file_path" "$cmd" "$cwd" "$content" "$old_str"
fi
