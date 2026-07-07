#!/bin/bash
# l2-detect.sh — L2 独立审查检测 + 派发提示生成 lib
#
# 提供两个函数:
#   l2_detect_missing <phase> <change_id> [specs_dir]
#     检查 INDEPENDENT-REVIEW-<phase>.md 是否含 L2 段
#     返回: 0 = L2 已完成, 1 = L2 缺失, 2 = 错误
#
#   l2_dispatch_prompt <phase> <change_id> [specs_dir]
#     生成一键 Agent 命令模板（含 subagent_type + description + prompt 骨架）
#     输出到 stdout，可直接复制粘贴
#
# 环境依赖:
#   PROJECT_ROOT — flow-kit 项目根目录

set -euo pipefail

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
║    subagent_type: ${agent_type}                                   ║
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