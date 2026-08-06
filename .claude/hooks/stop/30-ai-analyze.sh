#!/bin/bash
# 30-ai-analyze.sh — AI-powered deep analysis (frequency-gated)
# Runs every N stop hooks (configurable via .ai.frequency).
# Uses a small model to analyze session transcript and suggest CLAUDE.md updates.

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"

# l3-pipeline-fix-2026-07 D5: perf timing probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "30" || true

# ── Gate: AI module enabled? ────────────────────────────────────────
ai_enabled=$(config_get '.ai.enabled' "false")
[[ "$ai_enabled" == "true" ]] || exit 0

# ── Gate: Frequency check ───────────────────────────────────────────
frequency=$(config_get '.ai.frequency' "5")
count="${STOP_COUNT:-0}"

# Run AI on stop count % frequency == 0
if [[ $((count % frequency)) -ne 0 ]]; then
  echo "AI skip: count=$count frequency=$frequency" >> "$HOOK_TMP_DIR/run.log"
  exit 0
fi

# ── Gate: Transcript must exist ─────────────────────────────────────
[[ -f "$TRANSCRIPT_PATH" ]] || exit 0

# ── Gather context ──────────────────────────────────────────────────
max_chars=$(config_get '.ai.max_context_chars' "8000")

# Build a condensed context: CLAUDE.md + session summary
context=""
context+="=== 当前 CLAUDE.md ===\n"
context+=$(head -200 "$CLAWDE_MD" 2>/dev/null || echo "(无)")
context+="\n\n=== 本 Session 摘要 ===\n"

# Tool usage summary
context+="工具使用: $(get_tool_summary 2>/dev/null || echo '无数据')\n"

# Key file changes
src_files=$(get_touched_source_files 2>/dev/null | head -10 || true)
if [[ -n "$src_files" ]]; then
  context+="变更的源文件:\n${src_files}\n"
else
  context+="无源文件变更\n"
fi

# Commands used
commands=$(get_project_commands 2>/dev/null | head -10 || true)
if [[ -n "$commands" ]]; then
  context+="使用的命令:\n${commands}\n"
fi

# Gotcha signals
gotchas=$(grep -ivE '^(===|$)' "$HOOK_TMP_DIR/gotcha-matches.txt" 2>/dev/null | head -5 || true)
if [[ -n "$gotchas" ]]; then
  context+="Gotcha 信号:\n${gotchas}\n"
fi

# Truncate to max chars
context=$(echo -e "$context" | head -c "$max_chars")

# ── Build AI prompt ─────────────────────────────────────────────────
prompt=$(cat <<PROMPT
你是 NanoClaw 项目的 CLAUDE.md 维护助手。分析以下 session 摘要，判断 CLAUDE.md 是否需要更新。

规则（来自 claude-md-improver）：
应该添加的：新命令/工作流、gotcha/非显而易见的模式、包依赖关系、有效的测试方法、配置怪异之处
不应该添加的：显而易见的代码信息、通用最佳实践、一次性修复、冗长的解释

请用 JSON 回复，格式：
{
  "needs_update": true/false,
  "suggestions": [
    {"file": "CLAUDE.md", "section": "章节名", "addition": "建议添加的内容（markdown）", "why": "添加原因"}
  ],
  "summary": "一句话总结本次 session 的关键发现"
}

如果不需要更新，返回 {"needs_update": false, "suggestions": [], "summary": "..."}

上下文：
$context
PROMPT
)

# ── Call AI model ───────────────────────────────────────────────────
# Model: env var (ANTHROPIC_DEFAULT_HAIKU_MODEL) > config > hardcoded default
model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$(config_get '.ai.model' "deepseek-v4-flash")}"

# API path: direct $ANTHROPIC_BASE_URL (primary) → onecli (optional) → legacy key (fallback)
ai_response=""
base_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
auth_token="${ANTHROPIC_AUTH_TOKEN:-}"

# Path 1: Direct API call (env-var-first — uses user's configured endpoint)
if [ -n "$auth_token" ]; then
  ai_response=$(curl -s "${base_url}/v1/messages" \
    -H "Authorization: Bearer ${auth_token}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$prompt" --arg model "$model" '{
      model: $model,
      max_tokens: 1000,
      messages: [{role: "user", content: $prompt}]
    }')" 2>/dev/null || true)
fi

# Path 2: onecli proxy fallback (optional — only if installed)
if [ -z "$ai_response" ] && command -v onecli &>/dev/null; then
  ai_response=$(onecli proxy curl -s https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$prompt" --arg model "$model" '{
      model: $model,
      max_tokens: 1000,
      messages: [{role: "user", content: $prompt}]
    }')" 2>/dev/null || true)
fi

# Path 3: Legacy ANTHROPIC_API_KEY direct (backward compat)
if [ -z "$ai_response" ] && [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  ai_response=$(curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$prompt" --arg model "$model" '{
      model: $model,
      max_tokens: 1000,
      messages: [{role: "user", content: $prompt}]
    }')" 2>/dev/null || true)
fi

# ── Parse and store response ────────────────────────────────────────
if [[ -n "$ai_response" ]]; then
  echo "$ai_response" > "$HOOK_TMP_DIR/ai-raw-response.json"

  # Try to extract content from Claude response format
  content=$(echo "$ai_response" | jq -r '.content[0].text // empty' 2>/dev/null || true)

  if [[ -n "$content" ]]; then
    echo "$content" > "$HOOK_TMP_DIR/ai-content.txt"

    # Parse the JSON from content (may be wrapped in markdown code block)
    suggestions_json=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "$content")

    needs_update=$(echo "$suggestions_json" | jq -r '.needs_update // false' 2>/dev/null || echo "false")

    if [[ "$needs_update" == "true" ]]; then
      # Write suggestions to the suggestions file
      {
        echo "# AI 深度分析建议 — $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "> 自动生成于第 ${count} 次 Stop hook。请 review 后手动应用。"
        echo ""

        summary=$(echo "$suggestions_json" | jq -r '.summary // ""' 2>/dev/null || echo "")
        [[ -n "$summary" ]] && echo "**摘要**: $summary" && echo ""

        echo "## 建议更新"
        echo ""
        echo "$suggestions_json" | jq -r '.suggestions[]? | "### \(.file) → \(.section)\n\n**Why**: \(.why)\n\n```markdown\n\(.addition)\n```\n"' 2>/dev/null || true
      } > "$SUGGESTIONS_FILE"

      module_output "suggestion" "AI" "AI 深度分析完成，${count} 条建议 → \`${SUGGESTIONS_FILE}\`"
    else
      summary=$(echo "$suggestions_json" | jq -r '.summary // "无特别发现"' 2>/dev/null || echo "无特别发现")
      module_output "info" "AI" "AI 分析: $summary"
    fi
  fi
else
  # AI call failed — not critical, just log
  echo "AI call failed (no response)" >> "$HOOK_TMP_DIR/module-errors.log"
fi

declare -f fk_perf_timing_end >/dev/null 2>&1 && fk_perf_timing_end "30" || true
