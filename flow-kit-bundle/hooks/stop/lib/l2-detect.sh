#!/bin/bash
# l2-detect.sh — L2 独立审查检测 + 派发提示生成 lib
#
# 提供两个函数:
#   l2_detect_missing <phase> <change_id> [specs_dir]
#     检查 INDEPENDENT-REVIEW-<phase>.md 是否含 L2 段
#     返回: 0 = L2 已完成, 1 = L2 缺失, 2 = 错误
#
#   l2_dispatch_prompt <phase> <change_id> [specs_dir]
#     生成一键 Agent 命令模板（双模式：claude code → subagent_type + description + prompt 骨架；
#     opencode → category: unspecified-high + description + prompt 骨架）
#     输出到 stdout，可直接复制粘贴
#
# 环境依赖:
#   PROJECT_ROOT — flow-kit 项目根目录

set -euo pipefail

# 依赖注入：common.sh（fk_resolve_api_credentials / fk_platform_is_opencode，DESIGN D1/D2）
# 调用方（pre-tool-use gate-checks-basic.sh）只 source 本文件；stop 链可能先 source
# common.sh —— type 检查保证幂等（与 correction-file.sh 注入同惯例）。
type fk_resolve_api_credentials >/dev/null 2>&1 || {
  _L2_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
  if [ -n "${_L2_LIB_DIR:-}" ] && [ -f "${_L2_LIB_DIR}/common.sh" ]; then
    source "${_L2_LIB_DIR}/common.sh"
  fi
  unset _L2_LIB_DIR
}

# fk_extract_l2_verdict — extract L2 verdict from INDEPENDENT-REVIEW-N.md（ADR-007 / D1 · gate-review-fix）
# Single source for L2 verdict extraction across 4 consumers (4 files).
# Strategy: grep verdict line → last match → case-insensitive pass|fail extraction.
# Fallback: heading-style search (grep -iA 2 '^##.*Verdict' → extract pass|fail from heading context)
# 用法: l2v="$(fk_extract_l2_verdict "$review_md")"
# 返回: "pass" | "fail" | "" (未找到)
fk_extract_l2_verdict() {
  local review_md="${1:-}"
  [ -f "$review_md" ] || { echo ""; return 1; }
  local verdict
  # Primary: grep verdict line → tail -1 → case-insensitive pass|fail
  verdict=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1)
  if [ -n "$verdict" ]; then
    echo "$verdict"
    return 0
  fi
  # Fallback: heading-style search (## Verdict / **Verdict**: pass)
  verdict=$(grep -iA 2 '^##.*Verdict' "$review_md" 2>/dev/null | grep -ioE 'pass|fail' | tail -1)
  if [ -n "$verdict" ]; then
    echo "$verdict"
    return 0
  fi
  echo ""
  return 1
}

# ── l2_detect_missing() ──────────────────────────────────────────────
l2_detect_missing() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"
  local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l2-detect] invalid phase: $phase" >&2; return 2; }
  [ -n "$change_id" ] || { echo "[l2-detect] missing change_id" >&2; return 2; }

  if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
    return 0  # L2 已完成
  fi
  return 1  # L2 缺失
}

# ── l2_dispatch_prompt() ────────────────────────────────────────────
l2_dispatch_prompt() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l2-detect] invalid phase: $phase" >&2; return 2; }
  [ -n "$change_id" ] || { echo "[l2-detect] missing change_id" >&2; return 2; }

  # 按阶段映射 agent type（与各 prompt 的独立 review 调度段一致）
  local agent_type="qa-expert"
  case "$phase" in
    1) agent_type="qa-expert" ;;
    2|3) agent_type="architect-reviewer" ;;
    5) agent_type="qa-expert" ;;
    6) agent_type="code-reviewer" ;;
    7) agent_type="architect-reviewer" ;;
  esac

  # 按阶段映射工件描述
  local artifact_desc=""
  case "$phase" in
    1) artifact_desc=".specs/${change_id}/REQUIREMENT.md（参考 CHANGE.md）" ;;
    2) artifact_desc=".specs/${change_id}/DESIGN.md（参考 adr/*.md、CONTEXT.md、ARCHITECTURE.md）" ;;
    3) artifact_desc=".specs/${change_id}/TASK.md（参考 REQUIREMENT.md、DESIGN.md）" ;;
    5) artifact_desc=".specs/${change_id}/TEST.md（参考 REQUIREMENT.md、TASK.md）" ;;
    6) artifact_desc=".specs/${change_id}/REVIEW.md + git diff（参考 REQUIREMENT.md、TASK.md、TEST.md）" ;;
    7) artifact_desc=".specs/${change_id}/ 下全部产物（参考 REVIEW.md、LESSONS.md、CHANGELOG.md）" ;;
  esac

  # 生成一键命令模板
  cat <<DISPATCH_EOF
╔══════════════════════════════════════════════════════════╗
║  ⚠️ L2 盲审未完成（阶段 ${phase} · gate_config=both）      ║
║                                                          ║
║  请复制以下命令派 L2 子 agent：                             ║
║                                                          ║
║  Agent tool:                                             ║
║    claude code:  subagent_type: ${agent_type}            ║
║    opencode:     category: unspecified-high              ║
║                 （task(category=...) 路由，subagent_type ║
║                  在 opencode 下会挂起）                  ║
║    dsh:          subagent tool（description="L2 blind   ║
║                 review phase ${phase}", prompt=注入      ║
║                 L2-blind-review.md 全文 + 审查参数）      ║
║    description: "L2 blind review phase ${phase}"                ║
║    prompt: |                                             ║
║      原样注入 flow-kit/prompts/independent/L2-blind-review.md  ║
║                                                          ║
║      ## 本次审查参数                                      ║
║      - 阶段：${phase}                                          ║
║      - change-id：${change_id}                          ║
║      - 工件：${artifact_desc}           ║
║      - 输出：写入 .specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md ║
║                                                          ║
║  > 参数如有变更，参考源文件:                                ║
║    flow-kit/prompts/independent/L2-blind-review.md        ║
║    flow-kit/prompts/${phase}-*.md（独立 review 调度段）     ║
╚══════════════════════════════════════════════════════════╝
DISPATCH_EOF

  return 0
}

# ── l2_dispatch_agent() ────────────────────────────────────────────
# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md
#
# 自动派发 L2 审查 Agent（curl + API + 异步后台进程，凭证经共享函数解析）。
# 用法: l2_dispatch_agent <phase> <change_id> [specs_dir]
# 返回: 0 = dispatch 成功触发后台进程, 1 = 失败（curl 不可用/API 不可达/凭证缺失）
# 环境变量:
#   FLOW_KIT_L2_MOCK=1 — 跳过真实 API 调用，使用 mock 响应（供 bats 测试用）
#   凭证来源：fk_resolve_api_credentials()（common.sh，DESIGN D1）→ 输出 FK_API_BASE_URL /
#     FK_API_AUTH_TOKEN / FK_API_AUTH_SCHEME 全局（Path1 ANTHROPIC_AUTH_TOKEN bearer
#     > Path3 FLOW_KIT_L3_AUTH_TOKEN+FLOW_KIT_L3_BASE_URL bearer > Path2 ANTHROPIC_API_KEY x-api-key）
l2_dispatch_agent() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"
  local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l2-dispatch] invalid phase: $phase" >&2; return 1; }
  [ -n "$change_id" ] || { echo "[l2-dispatch] missing change_id" >&2; return 1; }

  # AC-7: 确保 specs_dir 存在（防止后台 stderr redirect 因目录缺失失败）
  mkdir -p "$specs_dir" 2>/dev/null || true

  # ── Mock 模式（测试用）──────────────────────────────────────────
  if [ "${FLOW_KIT_L2_MOCK:-0}" = "1" ]; then
    local mock_tmp
    mock_tmp="$(mktemp "${review_md}.tmp.XXXXXX")"
    local mock_ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo mock)"   # 修 BUG-G：mock_ts 原未定义，set -u 下 line120 ${mock_ts} 报错
    if [ -f "$review_md" ]; then
      cat "$review_md" > "$mock_tmp" 2>/dev/null || true
    fi
    {
      echo ""
      echo "---"
      echo "## L2 盲审（mock · ${mock_ts}）"
      echo ""
      echo "> Mock L2 review — FLOW_KIT_L2_MOCK=1"
      echo ""
      echo "### 🟢 Mock Finding · Mock review for testing"
      echo "**Symptom**: Mock dispatch succeeded"
      echo "**Source**: FLOW_KIT_L2_MOCK=1"
      echo "**Consequence**: None (mock)"
      echo "**Remedy**: None (mock)"
      echo ""
      echo "**Verdict**: pass"
    } >> "$mock_tmp"
    mv "$mock_tmp" "$review_md" 2>/dev/null || true
    echo "[l2-dispatch] mock Agent wrote to ${review_md}" >&2
    return 0
  fi

  # ── 凭证检查（共享函数 fk_resolve_api_credentials · DESIGN D1）──
  # 双平台凭证解析单点（common.sh L266-314）：Path1 ANTHROPIC_AUTH_TOKEN(bearer)
  # > Path3 FLOW_KIT_L3_AUTH_TOKEN+FLOW_KIT_L3_BASE_URL(bearer, 短路 Path2)
  # > Path2 ANTHROPIC_API_KEY(x-api-key)。rc: 0=就绪 / 1=无凭证 / 2=Path3 不完整。
  # 平台判定统一 fk_platform_is_opencode()（D2：OPENCODE_BIN/OPENCODE 任一非空即真）。
  # opencode 场景生产可达：oh-my-opencode 4.19.4+ 已桥接 PreToolUse（l2-l3-subagent-fix
  # 阶段6 L2 盲审 R6 已证伪「PreToolUse 不触发」旧假设），两分支均为真实可达路径。
  # || 条件上下文：rc=1/2 不触发 set -e 提前退出（分支内显式 return）
  local _cred_rc=0
  fk_resolve_api_credentials || _cred_rc=$?
  if [ "$_cred_rc" -eq 1 ]; then
    local _model_hint="或 /flow model l2=<model> 配置持久化兜底"
    local _hint
    if fk_platform_is_dsh; then
      _hint="dsh 检测到：请用 subagent tool 派发 L2 盲审（description=L2 blind review，prompt 注入 L2-blind-review.md）；凭证请 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN；${_model_hint}"
    elif fk_platform_is_opencode; then
      _hint="opencode 检测到：子 agent 模型绑定走 category 路由，请用 category= 派发（如 unspecified-high）；凭证请 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN；${_model_hint}"
    else
      # 默认分支：claude code（生产可达主路径）+ opencode 备选
      _hint="claude code 检测到：请确认 ANTHROPIC_AUTH_TOKEN 已注入（env-var-first）；若当前为 opencode 环境，请用 category= 派发（如 unspecified-high）并 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN；${_model_hint}"
    fi
    echo "[l2-dispatch] no API credentials（ANTHROPIC_AUTH_TOKEN / FLOW_KIT_L3_AUTH_TOKEN / ANTHROPIC_API_KEY 全空）" >&2
    echo "[l2-dispatch] ${_hint}" >&2
    return 1
  fi
  if [ "$_cred_rc" -eq 2 ]; then
    # stderr 已由 fk_resolve_api_credentials 报 Path3 配置不完整（rc=2 语义，D1）
    return 1
  fi
  # rc=0：凭证就绪。读共享输出全局（AC-6 红线：凭证值绝不落盘，FK_API_* 仅内存使用）
  local auth_token="${FK_API_AUTH_TOKEN:-}"
  local base_url="${FK_API_BASE_URL:-}"
  local auth_scheme="${FK_API_AUTH_SCHEME:-bearer}"

  # ── 构造 L2 审查 prompt（与 L2-blind-review.md 一致的固化模板）──
  local prompt_text
  prompt_text=$(cat <<'L2_PROMPT_EOF'
# L2 独立盲审员 · 固化指令

你是独立审查员，对 flow-kit 阶段产物做盲审。判断必须独立、客观。

## 独立性硬约束
1. 只看指定工件，不假设外部陈述
2. 禁止证实偏差——证据优先于解释
3. 不主动假设作者意图

## 输出格式（四要素 + 严重度）
每个发现必须含：Symptom / Source / Consequence / Remedy
严重度：🔴 Critical / 🟡 Major / 🟢 Minor
报告末尾：**Verdict**: pass | fail

## 审查重点（阶段特定，由调用参数决定）
L2_PROMPT_EOF
)

  # 按阶段追加审查重点
  case "$phase" in
    1) prompt_text+=$'\n'"阶段 1 · 需求审查：AC 是否 Given/When/Then 齐全且可验证？v1/v2/out 切分合理？非功能需求是否遗漏？" ;;
    2) prompt_text+=$'\n'"阶段 2 · 设计审查：ADR 决策是否有备选+理由+代价？是否撞禁动清单？抽象层次是否得当？风险是否遗漏？" ;;
    3) prompt_text+=$'\n'"阶段 3 · 任务审查：单 task ≤200行？依赖图无环？verify 可机器执行？AC 全覆盖？write_files 禁动清单无越界？" ;;
    5) prompt_text+=$'\n'"阶段 5 · 测试审查：AC 覆盖率 100%？5 轮金字塔是否逐轮填写？UAT 可脚本化？回归全绿？" ;;
    6) prompt_text+=$'\n'"阶段 6 · 代码审查：spec 合规？代码质量 6 维衰退风险？主 agent REVIEW 漏判/误判？修代码优先？" ;;
    7) prompt_text+=$'\n'"阶段 7 · 集成审查：产物齐全？LESSONS 同步？CHANGELOG 更新？归档清洁？done 真实性？" ;;
  esac

  prompt_text+=$'\n'$'\n'"## 本次审查参数"$'\n'
  prompt_text+="- 阶段：${phase}"$'\n'
  prompt_text+="- change-id：${change_id}"$'\n'
  prompt_text+="- 工件目录：${specs_dir}"$'\n'
  prompt_text+="- 输出：追加写入 ${review_md} 的 L2 盲审段（禁止覆写已有 L3 段）"$'\n'

  # ── API 调用（异步后台进程）────────────────────────────────────
  # base_url / auth_token / auth_scheme 已在凭证段从 FK_API_* 解析（DESIGN D1）
  # 模型选择 — 三级优先级链（l2-l3-model-config ADR-012；移除既有 L2 fallback，纯跨平台）
  type write_model_missing_correction >/dev/null 2>&1 || { [ -f "${HOOK_BASE_DIR:-}/lib/correction-file.sh" ] && source "${HOOK_BASE_DIR:-}/lib/correction-file.sh"; }
  local model; model=$(fk_resolve_model "L2")
  if [[ -z "$model" ]]; then
    write_model_missing_correction "L2"
    echo "[l2-detect] L2 模型未配置（三级链全空）。设置：export FLOW_KIT_L2_MODEL=<模型> 或 /flow model l2=<模型>" >&2
    return 3   # API 调用之前 return（不发 dispatch）
  fi
  write_model_missing_clear "L2"   # 正常路径：清残留 model-missing（AC-6 退场）

  (
    local ai_response="" content="" http_code=0

    # 构造 JSON payload（jq --arg 防注入）
    local payload
    payload=$(jq -n \
      --arg m "$model" \
      --arg p "$prompt_text" \
      '{model:$m, max_tokens:4096, messages:[{role:"user", content:$p}]}' 2>/dev/null) || {
      echo "[l2-dispatch] jq payload construction failed" >&2
      exit 1
    }

    # API 调用 — 按共享解析的 scheme 区分（D1 约定：bearer | x-api-key）
    if [ -n "$auth_token" ]; then
      local _auth_header
      if [ "$auth_scheme" = "x-api-key" ]; then
        _auth_header="x-api-key: ${auth_token}"
      else
        _auth_header="Authorization: Bearer ${auth_token}"
      fi
      ai_response=$(curl -s -w '\n%{http_code}' --max-time 90 "${base_url}/v1/messages" \
        -H "$_auth_header" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null || true)
      http_code=$(echo "$ai_response" | tail -1)
      ai_response=$(echo "$ai_response" | sed '$d')
    fi

    # ── 解析响应 ─────────────────────────────────────────────────
    case "$http_code" in
      200) ;;
      *) echo "[l2-dispatch] API returned HTTP ${http_code}" >&2; exit 1 ;;
    esac

    content=$(echo "$ai_response" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].text // empty' 2>/dev/null || echo "")
    if [ -z "$content" ]; then
      echo "[l2-dispatch] API call succeeded but no content in response" >&2
      exit 1
    fi

    # ── 追加写入 INDEPENDENT-REVIEW（防 L3 覆写）─────────────────
    # ── 原子写入 L2 段（tmp + mv 防竞态，与 L3 一致）──
    local bg_tmp
    bg_tmp="$(mktemp "${review_md}.tmp.XXXXXX")"
    if [ -f "$review_md" ]; then
      cat "$review_md" > "$bg_tmp" 2>/dev/null || true
    fi
    {
      echo ""
      echo "---"
      echo "## L2 盲审"
      echo ""
      echo "> 审查日期：$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ) | 阶段：${phase} | change-id：${change_id} | 自动派发"
      echo ""
      echo "$content"
    } >> "$bg_tmp"
    mv "$bg_tmp" "$review_md" 2>/dev/null || {
      echo "[l2-dispatch] CRITICAL: atomic mv failed for ${review_md}" >&2
      exit 1
    }

    echo "[l2-dispatch] Agent completed, result written to ${review_md}" >&2
    exit 0
  ) 1>/dev/null 2>"${specs_dir}/.l2-dispatch-${phase}.log" & disown

  local bg_pid=$!
  if [ -n "$bg_pid" ] && kill -0 "$bg_pid" 2>/dev/null; then
    echo "[l2-dispatch] Agent dispatched for phase ${phase} (pid=${bg_pid})" >&2
    return 0
  else
    echo "[l2-dispatch] dispatch failed, see manual command above" >&2
    return 1
  fi
}