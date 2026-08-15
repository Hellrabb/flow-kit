#!/bin/bash
# flow-kit-resume.sh — SessionStart hook
# Detects .flow-active and displays a resume banner.
# Also checks .specs/STATE.md for ai_context_doc preference.

set -euo pipefail

# ── Gate: Subagent isolation ────────────────────────────────────────
HOOK_INPUT=$(cat)
if command -v jq &>/dev/null; then
  PARENT_SESSION=$(echo "$HOOK_INPUT" | jq -r '.parent_session_id // ""')
  if [[ -n "$PARENT_SESSION" ]]; then
    exit 0
  fi
  CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "$PWD")
else
  CWD="$PWD"
fi

# ── Detect project root ─────────────────────────────────────────────
PROJECT_ROOT="$CWD"
# Walk up to find .flow-active or .specs/
while [[ "$PROJECT_ROOT" != "/" ]]; do
  if [[ -f "$PROJECT_ROOT/.flow-active" ]] || [[ -d "$PROJECT_ROOT/.specs" ]]; then
    break
  fi
  PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

flow_file="${PROJECT_ROOT}/.flow-active"

# ── No .flow-active → nothing to resume ─────────────────────────────
if [[ ! -f "$flow_file" ]]; then
  exit 0
fi

# ── Validate JSON ───────────────────────────────────────────────────
if ! jq empty "$flow_file" 2>/dev/null; then
  exit 0
fi

# ── Interactive UI correction check ──────────────────────────────────
correction_file="${PROJECT_ROOT}/.flow-active.interactive-ui-fix"
if [[ -f "$correction_file" ]] && jq empty "$correction_file" 2>/dev/null; then
  corr_gate=$(jq -r '.gate_type // "unknown"' "$correction_file" 2>/dev/null)
  corr_tool=$(jq -r '.required_tool // "unknown"' "$correction_file" 2>/dev/null)
  corr_retry=$(jq -r '.retry_count // 0' "$correction_file" 2>/dev/null)

  if [[ "$corr_retry" -ge 2 ]]; then
    # Stop correction — too many consecutive skips, need human
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  🛑 交互 gate 连续跳过 ≥3 次                          ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  gate : %-44s ║\n" "${corr_gate:0:44}"
    printf "║  tool : %-44s ║\n" "${corr_tool:0:44}"
    echo "║                                                      ║"
    echo "║  弱模型反复跳过交互式 UI，请人工介入。                 ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    rm -f "$correction_file"
  else
    # Inject correction instruction
    urgency=""
    [[ "$corr_retry" -eq 1 ]] && urgency="（第 2 次提醒，上轮你跳过了）"
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️ 交互 UI 矫正：上轮你跳过了交互 gate               ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  gate : %-44s ║\n" "${corr_gate:0:44}"
    printf "║  应调用 : %-42s ║\n" "${corr_tool:0:42}"
    echo "║                                                      ║"
    if [[ "$corr_tool" == "AskUserQuestion" ]]; then
      echo "║  现在立即调用 AskUserQuestion 工具补上。              ║"
      echo "║  AskUserQuestion({ questions: [{ question: \"...\",   ║"
      echo "║    header: \"...\", options: [...] }] })              ║"
    elif [[ "$corr_tool" == "EnterPlanMode" ]]; then
      echo "║  现在立即调用 EnterPlanMode 工具进入计划模式。        ║"
    fi
    echo "║                                                      ║"
    printf "║  %-50s ║\n" "${urgency}"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    # Don't delete correction file yet — the Stop hook will clear it
    # after the model successfully calls the tool this turn.
  fi
fi

# ── Compliance correction check ─────────────────────────────────────
compliance_correction_file="${PROJECT_ROOT}/.flow-active.correction"
if [[ -f "$compliance_correction_file" ]] && jq empty "$compliance_correction_file" 2>/dev/null; then
  corr_type=$(jq -r '.type // "unknown"' "$compliance_correction_file" 2>/dev/null)
  corr_count=$(jq -r '.violations | length // 0' "$compliance_correction_file" 2>/dev/null)

  if [[ "$corr_type" == "compliance" && "$corr_count" -gt 0 ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚠️ 合规矫正：上轮弱模型违规                          ║"
    echo "╠══════════════════════════════════════════════════════╣"

    # List violations grouped by layer
    idx=0
    while [[ "$idx" -lt "$corr_count" ]]; do
      v_layer=$(jq -r ".violations[$idx].layer // \"?\"" "$compliance_correction_file" 2>/dev/null)
      v_rule=$(jq -r ".violations[$idx].rule // \"?\"" "$compliance_correction_file" 2>/dev/null)
      v_location=$(jq -r ".violations[$idx].location // \"?\"" "$compliance_correction_file" 2>/dev/null)
      v_fix=$(jq -r ".violations[$idx].fix // \"?\"" "$compliance_correction_file" 2>/dev/null)

      printf "║  [%s] %-44s ║\n" "${v_layer:0:3}" "${v_rule:0:44}"
      printf "║  loc: %-46s ║\n" "${v_location:0:46}"
      printf "║  fix: %-46s ║\n" "${v_fix:0:46}"
      if [[ "$idx" -lt $((corr_count - 1)) ]]; then
        echo "║  ────────────────────────────────────────────────── ║"
      fi
      idx=$((idx + 1))
    done

    echo "║                                                      ║"
    echo "║  请按上述修复动作逐项执行，完成后继续任务。            ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    rm -f "$compliance_correction_file"   # compliance 读后清（一次性提示，既有语义）
  elif [[ "$corr_type" == "l3-model-missing" ]]; then
    # l2-l3-model-config (AC-6 入场)：L3 模型未配置，持续提示直到用户配置
    # T06 平台感知凭证指引（D3 载体边界：resume banner 可含 env 完整名）：
    # 平台判定单点封装 fk_platform_is_opencode()（D2 · common.sh），禁止内联
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    common_lib="${script_dir}/../stop/lib/common.sh"
    [ -f "$common_lib" ] && source "$common_lib" 2>/dev/null || true
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚙️ L3 审查模型未配置（L2/L3 配置解耦 · 降级中）       ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║  设置方式（任选其一）：                                ║"
    echo "║    export FLOW_KIT_L3_MODEL=<模型名>                  ║"
    echo "║    或 /flow model l3=<模型名>                         ║"
    if fk_platform_is_dsh; then
      echo "║                                                    ║"
      echo "║    同时确保 dsh 启动环境已 export                          ║"
      echo "║    FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN   ║"
      echo "║    （dsh 插件 hook bridge 子进程继承启动 env）             ║"
    elif fk_platform_is_opencode; then
      echo "║                                                    ║"
      echo "║    同时确保 opencode 启动环境已 export                      ║"
      echo "║    FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN   ║"
      echo "║    （hook 子进程继承启动 env）                              ║"
    fi
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    # 不 rm —— 持续提示（caller 正常路径 write_model_missing_clear 清除）
  elif [[ "$corr_type" == "l2-model-missing" ]]; then
    # l2-l3-model-config (AC-6 入场)：L2 模型未配置
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ⚙️ L2 审查模型未配置（L2/L3 配置解耦 · 降级中）       ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║  设置方式（任选其一）：                                ║"
    echo "║    export FLOW_KIT_L2_MODEL=<模型名>                  ║"
    echo "║    或 /flow model l2=<模型名>                         ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    # 不 rm —— 同 l3-model-missing
  elif [[ "$corr_type" == "l2-missing" ]]; then
    # 既有 l2-missing（gate_config=both 但 L2 盲审段缺失）。顺带修复既有 bug：
    # 原 :127 无条件 rm 删了它，与 _write_l2_missing_correction "持久化记录" 注释矛盾。
    # 现保留不删，等主 agent 派 L2 写段后由下一轮 compliance 轮换清除。
    :
  elif [[ "$corr_type" == "archive-uncommitted" ]]; then
    fc=$(jq -r '(.violations[0].files // (.violations | length) // "??")' "$compliance_correction_file" 2>/dev/null || echo "??")
    echo "⚠️ 归档后 git status 非干净（${fc} 个文件未 commit）。执行 7-integration 步骤 5.1 归档 commit。"
    rm -f "$compliance_correction_file"
  else
    # Unknown type or empty violations — warn and clean up
    echo "[flow-kit-resume] ⚠️ .flow-active.correction 格式异常（type=${corr_type} count=${corr_count}），已清除" >&2
    rm -f "$compliance_correction_file"   # unknown 异常清除
  fi
  # 原 :127 的无条件 rm -f 已移入各分支（compliance/unknown 删；model-missing/l2-missing 保留）
fi

# ── Independent review report injection (L3 feedback · F2) ──────────
ir_change=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null)
# D3 fix: pipeline-aware phase resolution
ir_phase=$(fk_resolve_phase 2>/dev/null || jq -r '.goal.current_phase // .phase // "?"' "$flow_file" 2>/dev/null || echo "?")
ir_done="${PROJECT_ROOT}/.specs/${ir_change}/.independent-review-${ir_phase}.done"
ir_review_md="${PROJECT_ROOT}/.specs/${ir_change}/INDEPENDENT-REVIEW-${ir_phase}.md"

# D1 fix: match L3 header "## L3 盲审" (primary) with backward compat for "## L3 外部模型审查"
if [[ "$ir_change" != "none" && -f "$ir_done" ]] && { grep -q "## L3 盲审" "$ir_review_md" 2>/dev/null || grep -q "## L3 外部模型审查" "$ir_review_md" 2>/dev/null; }; then
  # Source shared libs for _l3_format_result() and _fk_done_kvp()
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  l3_lib="${script_dir}/../stop/lib/l3-review.sh"
  done_validation_lib="${script_dir}/../stop/lib/done-validation.sh"
  [ -f "$l3_lib" ] && source "$l3_lib" 2>/dev/null || true
  [ -f "$done_validation_lib" ] && source "$done_validation_lib" 2>/dev/null || true

  if type _fk_done_kvp >/dev/null 2>&1 && type _l3_format_result >/dev/null 2>&1; then
    set +e
    l3v=$(_fk_done_kvp "$ir_done" "L3_verdict")
    l3v="${l3v:-unknown}"
    l3s=$(_fk_done_kvp "$ir_done" "L3_summary")
    l3s="${l3s:-}"
    set -e
    report=".specs/${ir_change}/INDEPENDENT-REVIEW-${ir_phase}.md"
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  🔎 独立 review 就绪（L3 外部模型）                  ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║  verdict : %-43s ║\n" "${l3v:0:43}"
    printf "║  summary : %-43s ║\n" "${l3s:0:43}"
    printf "║  report  : %-43s ║\n" "${report:0:43}"
    echo "║                                                      ║"
    echo "║  确认 L2 盲审段就绪后，写 done 即可切阶段/commit。    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
  fi
fi

# ── Build banner ────────────────────────────────────────────────────
script_dir="$(cd "$(dirname "$0")" && pwd)"
banner_lib="${script_dir}/../stop/lib/banner.sh"
if [[ -f "$banner_lib" ]]; then
  source "$banner_lib"
  build_resume_banner "$flow_file"
else
  echo "[flow-kit-resume] ERROR: banner.sh not found at $banner_lib" >&2
  exit 1
fi
