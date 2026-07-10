#!/bin/bash
# auto-checkpoint.sh — PreToolUse hook: Write/Edit 前自动更新 .flow-active.interrupt
#
# matcher: "Write|Edit"（settings.json PreToolUse[]）
# 放行: exit 0（fail-open · checkpoint 是辅助功能，不阻断工具调用）
#
# PreToolUse stdin: {hook_event_name, session_id, cwd, tool_name, tool_input:{file_path}, ...}
#
# DESIGN D1: PreToolUse hook 层兜底（prompt 层手动 /flow checkpoint 的补充）
# DESIGN D3: 全阶段 0~7（有活跃 change 即生效）
# DESIGN D4: fail-open（异常 exit 0，stderr 日志）
# DESIGN D6: 不去抖（每次 Write/Edit 必定更新 interrupt）

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# ══ helper 函数（source-safe · 可被 bats 复用） ══════════════════

# _auto_ck_active_change — 检查是否有活跃 change
# 参数: $1 = .flow-active 文件路径
# 返回 0 = 有活跃 change; 1 = 无
_auto_ck_active_change() {
  local flow_file="${1:-.flow-active}"
  [[ -f "$flow_file" ]] || return 1
  local change_id
  change_id=$(jq -r '.change_id // ""' "$flow_file" 2>/dev/null || echo "")
  [[ -n "$change_id" && "$change_id" != "null" ]] || return 1
  return 0
}

# _auto_ck_is_edit_tool — 检查工具名是否为 Write 或 Edit
# 参数: $1 = tool_name
# 返回 0 = 是 Write/Edit; 1 = 否
_auto_ck_is_edit_tool() {
  local tool="$1"
  case "$tool" in
    Write|Edit) return 0 ;;
    *) return 1 ;;
  esac
}

# _auto_ck_resolve_lib — 解析 checkpoint-lib.sh 路径
# 输出: checkpoint-lib.sh 的绝对路径
_auto_ck_resolve_lib() {
  # 按优先级查找: 安装后路径 → 开发目录结构 → 同目录（测试 flat layout）
  local lib_paths=(
    "$HOOK_BASE_DIR/../stop/lib/checkpoint-lib.sh"
    "$HOOK_BASE_DIR/../../hooks/stop/lib/checkpoint-lib.sh"
    "$HOOK_BASE_DIR/checkpoint-lib.sh"
  )
  for p in "${lib_paths[@]}"; do
    if [[ -f "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  echo ""  # not found
  return 1
}

# ══ 主逻辑（仅直接执行时跑 · source 时只定义 helper） ═══════════
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  command -v jq >/dev/null 2>&1 || exit 0

  INPUT=$(cat)
  tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

  # 非 Write/Edit → 放行（AC-4）
  if ! _auto_ck_is_edit_tool "$tool_name"; then
    exit 0
  fi

  # 无活跃 change → 放行（AC-3）
  if ! _auto_ck_active_change ".flow-active"; then
    exit 0
  fi

  # 解析文件路径
  file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

  # 空路径守卫：file_path 为空时仍写 checkpoint（active_file=""），不阻断工具
  # 极端情况：CC 协议变更导致 file_path 字段消失 → stderr 日志 + fail-open

  # 加载 checkpoint-lib.sh
  CK_LIB=$(_auto_ck_resolve_lib)
  if [[ -z "$CK_LIB" ]]; then
    echo "[auto-checkpoint] WARNING: checkpoint-lib.sh not found, skipping" >&2
    exit 0  # fail-open（AC-5）
  fi
  source "$CK_LIB"

  # 写入 checkpoint（D5: failing_check=""）
  if ! checkpoint_write "$file_path" "编辑 $file_path" ""; then
    echo "[auto-checkpoint] WARNING: checkpoint_write failed for $file_path" >&2
  fi

  exit 0  # fail-open · 永远不阻断工具
fi
