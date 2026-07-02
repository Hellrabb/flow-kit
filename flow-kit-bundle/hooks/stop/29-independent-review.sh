#!/bin/bash
# 29-independent-review.sh — 独立 review L3（外部模型强制审查）
#
# 当某 change 在阶段 1/2/6 开启了独立 review（gate_config 或 stop-hook.json），
# 用外部模型（默认 deepseek-v4-flash）对该阶段产物做盲审，产出
# .specs/<id>/INDEPENDENT-REVIEW-<phase>.md，并写 .flow-active.independent-review
# 握手文件供 SessionStart 注入 + 主 agent 判 done。
#
# 与 30-ai-analyze.sh 的区别：
#   - 不走频率门控（独立质量门不能被随机跳过），用幂等（本阶段已成功跑过则跳过）防重复。
#   - 工件是代码/设计文档，含反引号/$，必须用 jq --arg 构造 prompt（不能用 heredoc 插值）。
# 任何路径都 exit 0，不断 Stop 链。

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"
[ -f "${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh" ] && source "${HOOK_BASE_DIR}/lib/flow-kit-artifacts.sh"

# ── Gate 1: 模块启用 ──
module_enabled "independent_review" || exit 0

# ── Gate 2: flow-kit 活跃且合法 ──
flow_file="${PROJECT_ROOT}/.flow-active"
[ -f "$flow_file" ] || exit 0
jq empty "$flow_file" 2>/dev/null || exit 0

phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
change_id=$(jq -r '.change_id // "none"' "$flow_file" 2>/dev/null || echo "none")
{ [ "$change_id" != "none" ] && [ "$change_id" != "null" ]; } || exit 0

# ── Gate 3: 阶段 ∈ {1,2,3,5,6,7} 且独立 review gate 开启 ──
[[ "$phase" =~ ^(1|2|3|5|6|7)$ ]] || exit 0
fk_independent_review_gate_active "$phase" || exit 0

# ── 数值配置 sanitize（防 set -u/-e 下非数字炸）──
max_chars=$(config_get '.independent_review.max_artifact_chars' "20000")
[[ "$max_chars" =~ ^[0-9]+$ ]] || max_chars=20000
max_fail=$(config_get '.independent_review.max_failures_before_bypass' "3")
[[ "$max_fail" =~ ^[0-9]+$ ]] || max_fail=3
# Model: env var (ANTHROPIC_DEFAULT_HAIKU_MODEL) > config > hardcoded default
default_model=$(config_get '.ai.model' "deepseek-v4-flash")
configured_model=$(config_get '.independent_review.model' "$default_model")
model="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-$configured_model}"
[ -n "$model" ] || model="deepseek-v4-flash"

# ── Gate 4: 幂等——本阶段 L3 已成功就跳过 ──
state_file="${PROJECT_ROOT}/.flow-active.independent-review"
if [ -f "$state_file" ]; then
  prev_phase=$(jq -r '.phase // "?"' "$state_file" 2>/dev/null || echo "?")
  prev_status=$(jq -r '.status // ""' "$state_file" 2>/dev/null || echo "")
  if [[ "$prev_phase" == "$phase" && "$prev_status" == "done" ]]; then
    exit 0
  fi
fi

spec_dir="${PROJECT_ROOT}/.specs/${change_id}"

# ── Gate 5: done 标志已写（主 agent 收齐了）→ 清理握手文件 ──
done_marker="${spec_dir}/.independent-review-${phase}.done"
if [ -f "$done_marker" ]; then
  rm -f "$state_file"
  exit 0
fi

# ── 防线 2：pipeline 模式强制 auto_advance=false ──
if jq -e '.goal.scope // "" | . == "pipeline"' "$flow_file" >/dev/null 2>&1; then
  tmp_flow="${flow_file}.tmp"
  if jq '.goal.auto_advance = false | .updated_at = now' "$flow_file" > "$tmp_flow" 2>/dev/null; then
    mv "$tmp_flow" "$flow_file" 2>/dev/null || true
  fi
fi

# ── 按阶段拼工件 ──
artifact=""
checklist=""
case "$phase" in
  1)
    if [ -f "${spec_dir}/REQUIREMENT.md" ]; then
      artifact=$(head -c "$max_chars" "${spec_dir}/REQUIREMENT.md" 2>/dev/null || echo "")
    fi
    checklist="AC 是否每条 Given/When/Then 可验证且无歧义？v1/v2/out 范围切分是否合理？是否有范围蔓延或遗漏的非功能性需求？"
    ;;
  2)
    if [ -f "${spec_dir}/DESIGN.md" ]; then
      artifact=$(head -c "$max_chars" "${spec_dir}/DESIGN.md" 2>/dev/null || echo "")
    fi
    adr_files=$(find "$spec_dir" -type f -name '*.md' -path '*adr*' 2>/dev/null | head -3 || true)
    if [ -n "$adr_files" ]; then
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        artifact="${artifact}"$'\n\n--- '"${f}"$' ---\n'"$(head -c 2000 "$f" 2>/dev/null || echo "")"
      done <<< "$adr_files"
    fi
    checklist="ADR 决策是否合理且有充分理由？是否撞既有架构/跨模块契约？抽象层次是否得当（深模块 vs 浅模块）？风险段是否遗漏关键风险？"
    ;;
  6)
    artifact=$(cd "$PROJECT_ROOT" && git diff HEAD 2>/dev/null | head -c "$max_chars" || true)
    if [ -f "${spec_dir}/REVIEW.md" ]; then
      artifact="${artifact}"$'\n\n=== 主 agent REVIEW.md ===\n'"$(head -c 8000 "${spec_dir}/REVIEW.md" 2>/dev/null || echo "")"
    fi
    checklist="spec 合规（每条 AC 是否被代码覆盖）？代码质量（6 维衰退风险：认知过载/变更传播/知识重复/偶然复杂/依赖混乱/领域扭曲）？是否有 critical？"
    ;;
  3)
    if [ -f "${spec_dir}/TASK.md" ]; then
      artifact=$(head -c "$max_chars" "${spec_dir}/TASK.md" 2>/dev/null || echo "")
    fi
    checklist="任务拆解是否覆盖 REQUIREMENT 全 AC？depends_on 依赖是否无环？每个 task 的 verify 是否可执行且能证伪？write_files 边界是否清晰不越界？"
    ;;
  5)
    if [ -f "${spec_dir}/TEST.md" ]; then
      artifact=$(head -c "$max_chars" "${spec_dir}/TEST.md" 2>/dev/null || echo "")
    fi
    checklist="测试矩阵是否覆盖全 AC？覆盖率是否达标？UAT 是否可复现？是否有 mock 屏蔽真实失败（R5.2）？回归测试是否含？"
    ;;
  7)
    if [ -f "${spec_dir}/REVIEW.md" ]; then
      artifact=$(head -c "$max_chars" "${spec_dir}/REVIEW.md" 2>/dev/null || echo "")
    fi
    if [ -f "${PROJECT_ROOT}/CHANGELOG.md" ]; then
      artifact="${artifact}"$'\n\n=== CHANGELOG.md ===\n'"$(head -c 4000 "${PROJECT_ROOT}/CHANGELOG.md" 2>/dev/null || echo "")"
    fi
    checklist="归档产物是否齐全（CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY/TEST/REVIEW）？CHANGELOG 是否更新且 Conventional Commits 语义正确？archive 是否完整？"
    ;;
esac
[ -n "$artifact" ] || exit 0

# ── 构造 prompt（用 jq --arg，避免工件里的反引号/$ 被 shell 解释）──
prompt_text=$(jq -nr \
  --arg checklist "$checklist" \
  --arg phase "$phase" \
  --arg artifact "$artifact" \
  '"你是独立审查员，对以下 flow-kit 工件做盲审。独立性要求：禁止假设作者意图，只看工件本身；不接受也不引用任何「作者认为/主 agent 结论」类外部陈述。\n\n审查重点：" + $checklist + "\n\n工件（阶段 " + $phase + "）：\n" + $artifact + "\n\n请严格按 JSON 回复，不要 markdown 代码块包裹：\n{\"critical\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"major\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"minor\":[...],\"verdict\":\"pass 或 fail\",\"summary\":\"一句话总评\"}\ncritical/major/minor 每项含 file/issue/why/fix 四要素。无问题给空数组。verdict=fail 当且仅当存在 critical。"')

# ── 调外部模型（env-var-first 直连 · ANTHROPIC_AUTH_TOKEN 优先 · API_KEY 向后兼容）──
ai_response=""
base_url="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
auth_token="${ANTHROPIC_AUTH_TOKEN:-}"

# Path 1: Direct API call (env-var-first — uses user's configured endpoint)
if [ -n "$auth_token" ]; then
  ai_response=$(curl -s "${base_url}/v1/messages" \
    -H "Authorization: Bearer ${auth_token}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg m "$model" --arg p "$prompt_text" \
      '{model:$m, max_tokens:2000, messages:[{role:"user", content:$p}]}')" 2>/dev/null || true)
fi

# Path 2: Legacy ANTHROPIC_API_KEY direct (backward compat)
if [ -z "$ai_response" ] && [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  ai_response=$(curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg m "$model" --arg p "$prompt_text" \
      '{model:$m, max_tokens:2000, messages:[{role:"user", content:$p}]}')" 2>/dev/null || true)
fi

# ── 解析 + 落盘 ──
content=""
if [ -n "$ai_response" ]; then
  content=$(echo "$ai_response" | jq -r '.content[0].text // empty' 2>/dev/null || echo "")
fi

if [ -n "$content" ]; then
  mkdir -p "$spec_dir"
  review_md="${spec_dir}/INDEPENDENT-REVIEW-${phase}.md"
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")
  # 追加（非覆盖）—— 保留 L2 段（AC-6 T02 修复：原 `>` 覆盖毁 L2 审计链）
  {
    echo ""
    echo "---"
    echo ""
    echo "## L3 盲审（${model} 外部模型 · ${ts}）"
    echo ""
    echo "> 自动生成于 ${ts}。由 Stop hook 29-independent-review.sh **追加**（非覆盖，AC-6 T02）。"
    echo ""
    echo "### 审查结论"
    echo ""
    echo '```json'
    echo "$content"
    echo '```'
  } >> "$review_md"

  # 提取 verdict（content 可能裸 JSON 或被 markdown 包裹）
  extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
  [ -n "$extracted" ] || extracted="$content"
  verdict=$(echo "$extracted" | jq -r '.verdict // "unknown"' 2>/dev/null || echo "unknown")
  # L2-R1 修复：verdict 值域校验，非法值（如 unknown/不可解析）→ 失败降级，防 L3 门禁静默退化（L2 Major #1）
  case "$verdict" in pass|fail) ;; *)
    module_output "warning" "IR" "L3 verdict 值域非法（${verdict}），归入失败降级重试"
    write_failed_state "$state_file" "$phase"
    exit 0
    ;;
  esac

  ts_iso=$(date -Iseconds 2>/dev/null || echo "")
  fc_l3=0; [ "$verdict" = "fail" ] && fc_l3=1  # AC-6 T02 修复：fail_count 随 verdict（原硬编码 0）
  l3_token=$(printf '%s' "$content" | sha256sum 2>/dev/null | cut -d' ' -f1)
  [ -n "$l3_token" ] || l3_token="unknown"
  jq -n --arg p "$phase" --arg ts "$ts_iso" --arg rf "INDEPENDENT-REVIEW-${phase}.md" --argjson fc "$fc_l3" \
    --arg wby "stop-hook-29" --arg tok "$l3_token" \
    '{phase:$p, status:"done", fail_count:$fc, written_at:$ts, report_file:$rf, written_by:$wby, l3_token:$tok}' \
    > "$state_file" 2>/dev/null || true

  module_output "info" "IR" "独立 review L3 完成（阶段 ${phase}, verdict=${verdict}）→ INDEPENDENT-REVIEW-${phase}.md"
  exit 0
fi

# ── 失败降级（不卡死）──
write_failed_state "$state_file" "$phase"
fc=$(jq -r '.fail_count // 0' "$state_file" 2>/dev/null || echo "0")
[[ "$fc" =~ ^[0-9]+$ ]] || fc=0
if [ "$fc" -ge "$max_fail" ]; then
  module_output "error" "IR" "L3 独立 review 连续失败 ${fc} 次（≥${max_fail}），允许手动绕过：touch ${done_marker}"
else
  module_output "warning" "IR" "L3 独立 review 外部模型调用失败（第 ${fc}/${max_fail} 次）"
fi
exit 0
