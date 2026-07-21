#!/bin/bash
# done-validation.sh — .done marker authenticity validation
# Source via flow-kit-artifacts.sh (aggregate entry point).
# Direct sourcing is supported but not recommended — use the aggregate entry
# to ensure consistency with other flow-kit-artifacts functions.
#
# Requires: PROJECT_ROOT, jq
# Provides: fk_independent_review_gate_active, _fk_done_kvp, fk_validate_done_marker

# NOTE: Does NOT set -euo pipefail — this is a library, sourced by callers.

# Source l2-detect.sh for fk_extract_l2_verdict（gate-review-fix: Tier4 cross-reference）
local _dv_dir
_dv_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_dv_dir/l2-detect.sh" ] && source "$_dv_dir/l2-detect.sh" 2>/dev/null || true
# Callers are responsible for shell flags.

: "${MIN_MEANINGFUL_LINES:=6}"   # 阈值: 6 键 .done (phase/change_id/written_by/L2_verdict/L3_verdict/artifacts) 至少 6 行

# ═══════════════════════════════════════════════════════════════════════
# Independent review gate check
# ═══════════════════════════════════════════════════════════════════════

# Usage: fk_independent_review_gate_active <phase> [tier]
#   tier ∈ {""(default), "L2", "L3"}
#   tier="" → returns 0 if any tier is active (backward compat)
#   tier="L2" → returns 0 only if L2 (sub-agent blind review) is active
#   tier="L3" → returns 0 only if L3 (external model review) is active
# Returns: 0 (true) = gate 生效（应阻止阶段推进）；1 (false) = 放行
# gate 生效当且仅当：phase∈{1,2,3,5,6,7} 且 gate 开启 且 .specs/<id>/.independent-review-<phase>.done 不存在。
# gate 开启的双源：.flow-active.goal.gate_config[<阶段名>] ∈ {L2,L3,both} 优先，
#                 回退 .claude/stop-hook.json 的 independent_review.phases 数组含该阶段名（视为 both）。
# 向后兼容：gate_config 值 "independent" / "true" 自动映射为 "both"。
fk_independent_review_gate_active() {
  local phase="$1" tier="${2:-}"
  local flow_file="${PROJECT_ROOT}/.flow-active"
  [[ -f "$flow_file" ]] || return 1
  [[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || return 1

  local change_id
  change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
  [[ "$change_id" != "none" && "$change_id" != "null" ]] || return 1
  # Security: reject change_ids with path traversal chars (only kebab-case allowed)
  [[ "$change_id" =~ ^[a-z0-9][-a-z0-9]+$ ]] || return 1

  # AC-9: 使用 fk_phase_gate_key() 替代内联 case（common.sh 由 caller 在调用前 source）
  local phase_name
  phase_name="$(fk_phase_gate_key "$phase")"
  [ -n "$phase_name" ] || return 1

  # 双源读 gate_config 原始值
  local gate_val=""
  gate_val=$(jq -r --arg pn "$phase_name" \
    '.goal.gate_config[$pn] // empty' "$flow_file" 2>/dev/null || echo "")
  if [[ -z "$gate_val" ]]; then
    local cfg="${PROJECT_ROOT}/.claude/stop-hook.json"
    if [[ -f "$cfg" ]] && jq -e --arg pn "$phase_name" \
        '.independent_review.phases // [] | index($pn)' "$cfg" >/dev/null 2>&1; then
      gate_val="both"  # stop-hook.json 配置视为 both（向后兼容）
    fi
  fi

  gate_val="$(fk_normalize_gate_val "$gate_val")"

  [[ -n "$gate_val" ]] || return 1

  # Tier 判定
  case "$tier" in
    L2) [[ "$gate_val" == "L2" || "$gate_val" == "both" ]] || return 1 ;;
    L3) [[ "$gate_val" == "L3" || "$gate_val" == "both" ]] || return 1 ;;
    *) ;;  # tier="" → 任一层开启即通过
  esac

  # gate 开启：done 标志存在则放行（return 1），不存在则 gate 生效（return 0）
  local done_marker="${PROJECT_ROOT}/.specs/${change_id}/.independent-review-${phase}.done"
  [[ ! -f "$done_marker" ]]
}

# ═══════════════════════════════════════════════════════════════════════
# .done authenticity validation (AC-1 · D1/D5/G1 · 两层时机)
# ═══════════════════════════════════════════════════════════════════════

# Helper: 提取 .done 的 KVP 值（key=value，值可含 =）。未找到 → 空。
# Usage: _fk_done_kvp <path> <key>
_fk_done_kvp() {
  local path="$1" key="$2"
  [[ -f "$path" ]] || { echo ""; return; }
  grep -E "^${key}=" "$path" 2>/dev/null | head -1 | sed "s/^${key}=//"
}

# Usage: fk_validate_done_marker <done_path> <phase> <change_id> <tier>
#   tier = write (Tier 1 元数据快校验) | transition (Tier 1 + Tier 2 后置)
# Returns: 0 = .done 有效（放行）; 2 = 无效 deny（对齐 DESIGN §3 "deny exit 2" + forged-done check.sh rc=2）
# fail-close（D9）: jq 不可用 / 解析异常 / 畸形输入 → return 2（deny，agent 不能靠制造 hook 内部错误放行）
# phases_done 短路（D1/R11）: phase ∈ goal.phases_done → 直接有效（历史 .done 兜底）
fk_validate_done_marker() {
  local done_path="$1" phase="$2" change_id="$3" tier="${4:-write}"
  local flow_file="${PROJECT_ROOT:-}/.flow-active"

  [[ -f "$done_path" ]] || return 2

  # phases_done 短路（历史 .done · written_by=main-agent 不触发回头校验）
  if [[ -f "$flow_file" ]]; then
    local in_done
    in_done=$(jq -r --arg p "$phase" \
      '.goal.phases_done // [] | map(select(. == $p)) | length' \
      "$flow_file" 2>/dev/null || echo "0")
    [[ "$in_done" != "0" ]] && return 0
  fi

  # ── Tier 1 · 元数据快校验（不依赖下游产物）──
  [[ -s "$done_path" ]] || return 2                        # T1 非空（挡威胁① touch 空文件）
  local dlines
  dlines=$(wc -l < "$done_path" 2>/dev/null | tr -dc '0-9')
  [[ "${dlines:-0}" -ge "$MIN_MEANINGFUL_LINES" ]] || return 2

  local k_phase k_cid k_wby                                # T2 KVP（挡威胁② 伪造）
  k_phase=$(_fk_done_kvp "$done_path" "phase")
  k_cid=$(_fk_done_kvp "$done_path" "change_id")
  k_wby=$(_fk_done_kvp "$done_path" "written_by")
  [[ "$k_phase" == "$phase" ]] || return 2
  [[ "$k_cid" == "$change_id" ]] || return 2
  [[ -n "$k_wby" ]] || return 2

  # T5 Tier1 补 L2_verdict / L3_verdict / artifacts 存在性 + 值合法性检查 (pipeline-fallback-fix P2-1/P2-2)
  local k_l2v k_l3v k_artifacts
  k_l2v=$(_fk_done_kvp "$done_path" "L2_verdict")
  k_l3v=$(_fk_done_kvp "$done_path" "L3_verdict")
  k_artifacts=$(_fk_done_kvp "$done_path" "artifacts")
  [[ -n "$k_l2v" ]] || return 2          # 缺 L2_verdict → deny
  [[ "$k_l2v" =~ ^(pass|fail|skipped)$ ]] || return 2  # L2_verdict 值域校验 (含 skipped 用于 L3-only 模式)
  [[ -n "$k_l3v" ]] || return 2          # 缺 L3_verdict → deny
  [[ "$k_l3v" =~ ^(pass|fail|timeout|error|skipped)$ ]] || return 2  # L3_verdict 值域校验 (含 skipped 用于 L2-only 模式)
  [[ -n "$k_artifacts" ]] || return 2     # 缺 artifacts → deny
  [[ "$k_artifacts" =~ , ]] || return 2   # artifacts 至少含 1 个逗号分隔文件名 (最低: "x,y")

  [[ "$tier" == "transition" ]] || return 0                # tier=write 到此为止

  # ── Tier 2 · transition 后置（产物已齐）──
  # T3 D7 握手锚点（挡威胁③ + ⑤-L3 常见路径）
  local hs_path="${flow_file}.independent-review"
  [[ -f "$hs_path" ]] || return 2
  local hs_wby hs_verdict
  hs_wby=$(jq -r --arg p "$phase" '.[$p].written_by // ""' "$hs_path" 2>/dev/null || echo "")
  hs_verdict=$(jq -r --arg p "$phase" '.[$p].verdict // ""' "$hs_path" 2>/dev/null || echo "")
  [[ "$hs_wby" == "stop-hook-29" ]] || return 2
  local l3v
  l3v=$(_fk_done_kvp "$done_path" "L3_verdict")
  [[ -n "$l3v" && "$hs_verdict" == "$l3v" ]] || return 2

  # T3b SESSION_ID 跨会话锚点（挡威胁④ 移花接木）
  local cur_sid done_sid
  cur_sid="${CLAUDE_CODE_SESSION_ID:-}"
  done_sid=$(_fk_done_kvp "$done_path" "session_id")
  if [[ -n "$cur_sid" && -n "$done_sid" ]]; then
    [[ "$done_sid" == "$cur_sid" ]] || return 2
  fi
  # cur_sid / done_sid 缺失 → best-effort 不挡（跨会话合法推进由 phases_done 短路兜底）

  # T4 L2_verdict 与 INDEPENDENT-REVIEW-<phase>.md 比对（挡威胁⑤-L2 · v1 best-effort 提高成本）
  local l2v md_path md_v
  l2v=$(_fk_done_kvp "$done_path" "L2_verdict")
  md_path="${PROJECT_ROOT:-}/.specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md"
  if [[ -n "$l2v" && -f "$md_path" ]]; then
    md_v="$(fk_extract_l2_verdict "$md_path")"
    [[ -z "$md_v" || "$md_v" == "$l2v" ]] || return 2     # 提取不到 verdict 不挡（best-effort）
  fi

  return 0
}
