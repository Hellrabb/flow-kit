#!/bin/bash
# l3-review.sh — L3 外部模型独立审查编排器（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 提供 l3_review_run() 和 l3_review_with_timeout()，供:
#   - independent-review-gate.sh (PreToolUse hook · transition 时同步触发)
#   - 29-independent-review.sh (Stop hook · session 异常终止时兜底)
# 两处复用，消除 L3 API 调用代码重复。
#
# 函数签名:
#   l3_review_run <phase> <change_id> <artifacts_dir> <L2_verdict>
#   l3_review_with_timeout <phase> <change_id> <artifacts_dir> <L2_verdict> [timeout_secs]
#   l3_dispatch_prompt <phase> <change_id> [specs_dir] [gate_val]
#
# 环境变量依赖 (沿用 CONTEXT.md 已锁决策):
#   ANTHROPIC_BASE_URL   — API endpoint (默认 https://api.anthropic.com)
#   ANTHROPIC_AUTH_TOKEN — 鉴权 token (env-var-first, 优先)
#   ANTHROPIC_API_KEY    — 鉴权 key (向后兼容)
#   ANTHROPIC_DEFAULT_HAIKU_MODEL — L3 审查模型 (默认 deepseek-v4-flash)
#   FLOW_KIT_L3_BASE_URL   — L3 API endpoint（opencode 平台路径 · hook 子进程继承启动 env）
#   FLOW_KIT_L3_AUTH_TOKEN — L3 鉴权 token（opencode 平台路径 · 凭证不落盘）
#
# 子模块（按依赖顺序 source）:
#   l3-truncate.sh  — _l3_check_rerun
#   l3-prompt.sh    — _l3_format_result, _l3_inject_context, _l3_build_prompt
#   l3-api.sh       — smart_truncate, _l3_call_api, _l3_parse_result
#   l3-done.sh      — _l3_write_done, l3_write_timeout_done

set -euo pipefail

# ── 子模块 source ──
_l3r_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$_l3r_dir/l2-detect.sh" ] && source "$_l3r_dir/l2-detect.sh" 2>/dev/null || true
source "$_l3r_dir/l3-truncate.sh"
source "$_l3r_dir/l3-prompt.sh"
source "$_l3r_dir/l3-api.sh"
source "$_l3r_dir/l3-done.sh"

unset _l3r_dir

# ── l3_review_run() · 编排器（调用 4 子函数，≤90 行）──
l3_review_run() {
  local phase="$1" change_id="$2" artifacts_dir="$3" l2_verdict="$4"
  local gate_config_value="${5:-both}"
  local max_chars="${L3_MAX_ARTIFACT_CHARS:-20000}"

  # 参数校验
  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l3-review] invalid phase: $phase" >&2; return 3; }
  [ -n "$change_id" ] || { echo "[l3-review] missing change_id" >&2; return 3; }
  [ -d "$artifacts_dir" ] || { echo "[l3-review] artifacts_dir not found: $artifacts_dir" >&2; return 3; }
  [[ "$l2_verdict" =~ ^(pass|fail|skipped)$ ]] || { echo "[l3-review] invalid L2_verdict: $l2_verdict" >&2; return 3; }

  # 模型选择 — 三级优先级链（l2-l3-model-config ADR-012, supersedes ADR-006）
  type write_model_missing_correction >/dev/null 2>&1 || { [ -f "${HOOK_BASE_DIR:-}/lib/correction-file.sh" ] && source "${HOOK_BASE_DIR:-}/lib/correction-file.sh"; }
  local model; model=$(fk_resolve_model "L3")
  if [[ -z "$model" ]]; then
    write_model_missing_correction "L3"
    echo "[l3-review] L3 模型未配置（三级链全空）。设置：export FLOW_KIT_L3_MODEL=<模型> 或 /flow model l3=<模型>" >&2
    return 3   # API 调用之前 return（降级 vs 错误区分：不发 _l3_call_api）
  fi
  write_model_missing_clear "L3"   # 正常路径：清残留 model-missing（AC-6 退场）

  # --background 模式（l3-pipeline-fix-2026-07 D5 Phase 3）
  # Stop hook 兜底路径 fire-and-forget：curl 异步，结果由 SessionStart 收割
  local bg_mode=0
  case "${6:-}" in --background) bg_mode=1 ;; esac
  case "${7:-}" in --background) bg_mode=1 ;; esac

  if [ "$bg_mode" -eq 1 ]; then
    local bg_dir="${artifacts_dir}"
    local bg_file="${bg_dir}/.l3-bg-${phase}.json"
    (
      # 子进程独立执行 L3 API 调用
      local _prompt _content _output _verdict _summary
      _prompt=$(_l3_build_prompt "$phase" "$artifacts_dir" "$max_chars" 2>/dev/null || echo "")
      if [ -n "$_prompt" ]; then
        _ctx_pre=$(_l3_inject_context "$phase" "$artifacts_dir" 2>/dev/null || echo "")
        [ -n "$_ctx_pre" ] && _prompt="${_ctx_pre}"$'\n'"${_prompt}"
        _content=$(_l3_call_api "$_prompt" "$model" 2>/dev/null || echo "")
        if [ -n "$_content" ]; then
          _output=$(_l3_parse_result "$_content" "$phase" "$artifacts_dir" "$model" 2>/dev/null || echo "")
          _verdict=$(echo "$_output" | grep "^VERDICT=" | cut -d= -f2-)
          _summary=$(echo "$_output" | grep "^SUMMARY=" | cut -d= -f2-)
          # 写入后台结果文件供 SessionStart 收割
          jq -n --arg v "${_verdict:-error}" --arg s "${_summary:-background L3 review}" \
            --arg ts "$(date -Iseconds)" --arg phase "$phase" --arg model "$model" \
            '{verdict: $v, summary: $s, phase: $phase, model: $model, completed_at: $ts}' \
            > "$bg_file" 2>/dev/null || true
        fi
      fi
    ) &
    echo "[l3-review] L3 dispatched in background (phase ${phase}, pid $!)" >&2
    return 0
  fi

  # Step 1: 构造 prompt（含前次审查上下文注入 · l3-pipeline-fix-2026-07 D4）
  local prompt_text context_preamble
  prompt_text=$(_l3_build_prompt "$phase" "$artifacts_dir" "$max_chars") || return 3
  context_preamble=$(_l3_inject_context "$phase" "$artifacts_dir" 2>/dev/null || echo "")
  [ -n "$context_preamble" ] && prompt_text="${context_preamble}"$'\n'"${prompt_text}"

  # Step 2: 调用 API
  local content
  content=$(_l3_call_api "$prompt_text" "$model") || return 3

  # Step 3: 解析结果（含重审检测 + L3 段追加 + verdict/summary 提取）
  local l3_output l3_verdict l3_summary
  l3_output=$(_l3_parse_result "$content" "$phase" "$artifacts_dir" "$model") || {
    local rc=$?; [ $rc -eq 2 ] && return 0; return $rc
  }
  l3_verdict=$(echo "$l3_output" | grep "^VERDICT=" | cut -d= -f2-)
  l3_summary=$(echo "$l3_output" | grep "^SUMMARY=" | cut -d= -f2-)

  # Step 4: 写入 .done（含 D3 both 检查）
  local _write_rc=0
  _l3_write_done "$phase" "$change_id" "$l3_verdict" "$l3_summary" \
    "$l2_verdict" "$artifacts_dir" "$gate_config_value" || _write_rc=$?
  case $_write_rc in
    0) ;;  # success — .done written
    1) echo "[l3-review] verdict non-pass, .done not written" >&2 ;;
    3) echo "[l3-review] CRITICAL: .done write failed" >&2; return 3 ;;
    *) echo "[l3-review] UNEXPECTED: _l3_write_done rc=$_write_rc" >&2; return $_write_rc ;;
  esac

  # 返回 verdict 对应的 exit code
  case "$l3_verdict" in
    pass) return 0 ;;
    fail) return 1 ;;
    *)    return 3 ;;
  esac
}

# ── l3_review_with_timeout() · 超时降级 wrapper ──
l3_review_with_timeout() {
  local phase="$1"
  local change_id="$2"
  local artifacts_dir="$3"
  local l2_verdict="$4"
  local timeout_secs="${5:-30}"
  local gate_config_value="${6:-both}"

  # Phase 值域已在上游校验（${phase} ∈ {1..7}, ${l2_verdict} ∈ {pass,fail,skipped}），
  # 仍通过环境变量传参避免 shell 插值注入风险

  echo "[l3-review] L3 review starting (phase=${phase}, timeout=${timeout_secs}s)..." >&2

  # 尝试同步调用
  local ret=0
  timeout "${timeout_secs}s" HOOK_BASE_DIR="${HOOK_BASE_DIR}" bash -c '
    source "${HOOK_BASE_DIR}/lib/l3-review.sh"
    l3_review_run "$@"' _ "${phase}" "${change_id}" "${artifacts_dir}" "${l2_verdict}" "${gate_config_value:-both}" 2>/dev/null || ret=$?

  if [ $ret -eq 124 ] || [ $ret -eq 137 ]; then
    # timeout 命令返回 124 (GNU timeout) 或进程被 kill (137=128+9)
    echo "[l3-review] L3 timed out after ${timeout_secs}s — .done NOT written (verdict=timeout, phase ${phase})" >&2
    # fix-l3-gate AC-2: timeout 不写 .done；保留审计痕迹（l3_write_timeout_done 仅追加 notice 不写 .done）
    l3_write_timeout_done "$phase" "$change_id" "$artifacts_dir" "$l2_verdict"
    return 1
  fi

  return $ret
}

# ── l3_dispatch_prompt() · L3 异步派发提示（对标 l2_dispatch_prompt）──
# 用法: l3_dispatch_prompt <phase> <change_id> [specs_dir] [gate_val]
# 输出: 一键 Agent 派发模板到 stdout（调用方重定向到 >&2）
# 返回: 0
l3_dispatch_prompt() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"
  local gate_val="${4:-both}"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l3-dispatch] invalid phase: $phase" >&2; return 2; }
  [ -n "$change_id" ] || { echo "[l3-dispatch] missing change_id" >&2; return 2; }

  # 确定 L2_verdict（用于 l3_review_run 参数）
  local l2v="skipped"
  if [[ "$gate_val" == "both" ]]; then
    local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"
    if [ -f "$review_md" ]; then
      l2v="$(fk_extract_l2_verdict "$review_md")"
      [ -n "$l2v" ] || l2v="fail"
    else
      l2v="fail"
    fi
  fi

  # 按阶段描述工件（与 l3_review_run case 一致）
  local artifact_desc=""
  case "$phase" in
    1) artifact_desc="REQUIREMENT.md（+ CHANGE.md）" ;;
    2) artifact_desc="DESIGN.md（+ REQUIREMENT.md + ADR）" ;;
    3) artifact_desc="TASK.md（+ REQUIREMENT.md + DESIGN.md）" ;;
    5) artifact_desc="TEST.md（+ REQUIREMENT.md + TASK.md + 各 SUMMARY）" ;;
    6) artifact_desc="REVIEW.md + git diff（+ REQUIREMENT + TASK + TEST）" ;;
    7) artifact_desc=".specs/${change_id}/ 全量产物（含 REVIEW/TEST/TASK/DESIGN/REQUIREMENT/CHANGE）" ;;
  esac

  # 生成派发提示
  cat <<DISPATCH_EOF
╔══════════════════════════════════════════════════════════════╗
║  ⚠️ L3 外部模型审查未完成（阶段 ${phase} · gate_config=${gate_val}） ║
║                                                              ║
║  L3 不走同步超时（30s 不够外部模型响应）。                   ║
║  请异步派发 L3 审查：                                        ║
║                                                              ║
║  方式 1 — 子 agent（推荐，非阻塞）：                         ║
║    Agent({                                                   ║
║      # claude code 平台: subagent_type 路由                  ║
║      subagent_type: "general-purpose",                       ║
║      # opencode 平台: task(category=...) 路由                ║
║      category: "unspecified-high",                           ║
║      description: "L3 external review phase ${phase}",       ║
║      prompt: "运行 L3 独立审查:                              ║
║      source flow-kit-bundle/hooks/stop/lib/l3-review.sh && \ ║
║        l3_review_run ${phase} ${change_id} ${specs_dir} \    ║
║                      ${l2v} ${gate_val}                      ║
║      返回 verdict 和 summary"                                ║
║    })                                                        ║
║                                                              ║
║  方式 2 — 直接 bash（阻塞但可控）：                          ║
║    source flow-kit-bundle/hooks/stop/lib/l3-review.sh && \   ║
║    l3_review_run ${phase} ${change_id} ${specs_dir} \        ║
║                  ${l2v} ${gate_val}                          ║
║                                                              ║
║  参数说明:                                                   ║
║    phase=${phase}   change_id=${change_id}                   ║
║    specs_dir=${specs_dir}                                    ║
║    L2_verdict=${l2v}   gate_config=${gate_val}               ║
║    artifacts: ${artifact_desc}                               ║
║                                                              ║
║  完成后写入:                                                 ║
║    .specs/${change_id}/.independent-review-${phase}.done     ║
║    INDEPENDENT-REVIEW-${phase}.md（追加 L3 段）              ║
║                                                              ║
║  重试: L3 完成后重新执行 phase transition 即可放行。         ║
╚══════════════════════════════════════════════════════════════╝
DISPATCH_EOF

  return 0
}
