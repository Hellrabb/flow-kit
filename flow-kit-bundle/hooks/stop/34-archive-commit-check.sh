#!/bin/bash
# 34-archive-commit-check.sh — 归档后未 commit 检测（D3）
#
# 双模式检测归档流程完成后是否还有未 commit 的变更：
#   pipeline 模式：goal.scope=pipeline + goal.status=done + .specs/archive/ 存在
#   单阶段模式：最近归档目录 mtime > 最近 commit 时间戳（git log %ct 锚点）
#
# 检测到未 commit 变更 → 写 correction；已 commit → type-guarded clear。
# 对应 AC-3。骨架对齐 28-weak-model-compliance（module_enabled guard）+
# 32-fallback-guard（PROJECT_ROOT + jq 条件分支）先例。

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "${HOOK_BASE_DIR}/lib/common.sh"
source "${HOOK_BASE_DIR}/lib/correction-file.sh"
source "${HOOK_BASE_DIR}/lib/correction-types.sh"

# l3-pipeline-fix perf probe
declare -f fk_perf_timing_start >/dev/null 2>&1 && fk_perf_timing_start "34" || true

# ── Gate 1: 模块启用 ──
module_enabled "archive_commit_check" || exit 0

# ── Gate 2: flow-kit 活跃 ──
flow_file="${PROJECT_ROOT:-}/.flow-active"
[ -f "$flow_file" ] || exit 0
jq empty "$flow_file" 2>/dev/null || exit 0

# ── correction path ──
correction_path="${PROJECT_ROOT:-}/.flow-active.correction"

# ── Check body: 双模式归档未 commit 检测 ──
_check_archive_commit_body() {
  local scope status arch_dir arch_mtime last_commit_ts uncommitted

  scope=$(jq -r '.goal.scope // ""' "$flow_file" 2>/dev/null || echo "")
  status=$(jq -r '.goal.status // ""' "$flow_file" 2>/dev/null || echo "")

  # pipeline 分支：scope=pipeline + status=done + archive 目录存在
  if [[ "$scope" == "pipeline" && "$status" == "done" ]]; then
    [[ -d "${PROJECT_ROOT:-}/.specs/archive" ]] || return 0
  else
    # 单阶段分支：最近归档 mtime > 最近 commit %ct
    arch_dir=$(ls -t "${PROJECT_ROOT:-}/.specs/archive/" 2>/dev/null | head -1)
    [[ -n "$arch_dir" ]] || return 0
    arch_mtime=$(stat -c %Y "${PROJECT_ROOT:-}/.specs/archive/$arch_dir" 2>/dev/null || echo 0)
    last_commit_ts=$(cd "${PROJECT_ROOT:-}" && git log -1 --format=%ct 2>/dev/null || echo 0)
    [[ "$arch_mtime" -gt "$last_commit_ts" ]] || return 0
  fi

  # 归档未 commit 检测到
  uncommitted=$(cd "${PROJECT_ROOT:-}" && git status --porcelain 2>/dev/null || echo "")
  if [[ -n "$uncommitted" ]]; then
    # 写 correction（type-guarded · 对齐 write_model_missing_correction 先例）
    local json
    json=$(jq -n \
      --arg type "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" \
      --arg ts "$(date -Iseconds)" \
      '{type: $type, message: "archive completed but uncommitted changes remain", written_at: $ts, violations: []}')
    correction_file_write "$correction_path" "$json"
  else
    # 干净 → type-guarded clear（对齐 write_model_missing_clear:132-152 先例）
    [[ -f "$correction_path" ]] || return 0
    local cur_type
    cur_type=$(jq -r '.type // ""' "$correction_path" 2>/dev/null || echo "")
    [[ "$cur_type" == "$CORRECTION_TYPE_ARCHIVE_UNCOMMITTED" ]] && rm -f "$correction_path"
  fi
}

run_check "archive_commit_check" "AC3" "" _check_archive_commit_body
