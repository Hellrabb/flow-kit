#!/bin/bash
# auto-checkpoint.sh — PreToolUse hook: Write/Edit 前自动更新 .flow-active.interrupt
#
# matcher: "Write|Edit"（settings.json PreToolUse[]）
# 放行: exit 0（非管辖面：非 Write/Edit、无活跃 change、.flow-active 自引用、checkpoint-lib 缺失/写失败——检查点可选，辅助功能不阻断工具调用）
# 拒绝: exit 2（C12 · health-fix-2026-09c D4/AC-8：jq 缺失或 .flow-active 非法 JSON = 依赖失效面，fail-closed）
#
# PreToolUse stdin: {hook_event_name, session_id, cwd, tool_name, tool_input:{file_path}, ...}
#
# DESIGN D1: PreToolUse hook 层兜底（prompt 层手动 /flow checkpoint 的补充）
# DESIGN D3: 全阶段 0~7（有活跃 change 即生效）
# DESIGN D4（auto-checkpoint 原设计；C12/health-fix-2026-09c D4 修订）: 依赖失效（jq 缺失/解析失败）fail-closed exit 2；检查点写入失败仍 fail-open（检查点可选）
# DESIGN D6: 不去抖（每次 Write/Edit 必定更新 interrupt）

set -euo pipefail

HOOK_BASE_DIR="${HOOK_BASE_DIR:-$(cd "$(dirname "$0")" && pwd)}"

# ══ helper 函数（source-safe · 可被 bats 复用） ══════════════════

# _auto_ck_active_change — 检查是否有活跃 change
# 参数: $1 = .flow-active 文件路径
# 返回 0 = 有活跃 change; 1 = 无（合法：无文件/无 change_id）; 2 = 状态不可判（C12: jq 缺失或 .flow-active 非法 JSON）
_auto_ck_active_change() {
  local flow_file="${1:-.flow-active}"
  [[ -f "$flow_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 2
  local change_id
  change_id=$(jq -r '.change_id // ""' "$flow_file" 2>/dev/null) || return 2
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
  # C12/AC-8：jq 缺失 → exit 2 fail-closed（原 exit 0 静默放行 = 依赖失效面 fail-open）
  command -v jq >/dev/null 2>&1 || { echo "[auto-checkpoint] jq 不可用，fail-closed：无法解析 hook stdin 与 .flow-active，拒绝放行（安装 jq 或检查 PATH 后重试）" >&2; exit 2; }

  INPUT=$(cat)
  tool_name=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

  # 非 Write/Edit → 放行（AC-4）
  if ! _auto_ck_is_edit_tool "$tool_name"; then
    exit 0
  fi

  # 活跃 change 判定（AC-3 + C12 fail-closed）：rc=0 有活跃；rc=1 无（合法放行）；rc=2 状态不可判（拒绝放行）
  _auto_ck_rc=0
  _auto_ck_active_change ".flow-active" || _auto_ck_rc=$?
  if [[ "$_auto_ck_rc" -eq 1 ]]; then
    exit 0
  fi
  if [[ "$_auto_ck_rc" -ne 0 ]]; then
    echo "[auto-checkpoint] .flow-active 状态不可判（jq 缺失或非法 JSON），fail-closed：拒绝放行。状态文件可能正在写入，重试一次；持续失败请修复 .flow-active 或安装 jq" >&2
    exit 2
  fi

  # 解析文件路径
  file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

  # 空路径守卫：file_path 为空时仍写 checkpoint（active_file=""），不阻断工具
  # 极端情况：CC 协议变更导致 file_path 字段消失 → stderr 日志 + fail-open

  # 自引用守卫：跳过对 .flow-active 自身的 checkpoint 写入
  # 理由：Write/Edit .flow-active 是 agent 管理 flow 状态的合法操作，
  # checkpoint hook 不应在此期间修改同一文件（会导致竞态：hook 改 interrupt →
  # harness 检测到文件内容已变 → 拒绝 agent 的 Write/Edit）
  case "$file_path" in
    */.flow-active|.flow-active)
      exit 0 ;;
  esac

  # 加载 checkpoint-lib.sh
  CK_LIB=$(_auto_ck_resolve_lib)
  if [[ -z "$CK_LIB" ]]; then
    echo "[auto-checkpoint] WARNING: checkpoint-lib.sh not found, skipping" >&2
    exit 0  # fail-open（检查点可选：checkpoint-lib 缺失不阻断工具调用，非 C12 依赖失效面）
  fi
  source "$CK_LIB"

  # 写入 checkpoint（D5: failing_check=""）
  if ! checkpoint_write "$file_path" "编辑 $file_path" ""; then
    echo "[auto-checkpoint] WARNING: checkpoint_write failed for $file_path" >&2
  fi

  exit 0  # 正常完成（业务语义：checkpoint 写失败不阻断，见上方 WARNING）
fi
