#!/bin/bash
# checkpoint-lib.sh — auto-checkpoint 共享函数
# 由 PreToolUse hook + prompt 层 auto-checkpoint 指令调用
# 用法: source checkpoint-lib.sh && checkpoint_write "file" "desc" ["failing_check"]
#
# DESIGN D1: prompt 层 + hook 层双层防护
# DESIGN D2: PreToolUse hook 为兜底拦截点
# DESIGN D5: active_file=相对路径, last_action≤200chars, checkpoint_at=ISO8601
# DESIGN D2: 不启用去重（auto-checkpoint-hook change 移除 · 每次调用必定更新）
# DESIGN D6: ref → hooks/stop/lib/checkpoint-lib.sh（本文件 · 禁动清单）

set -euo pipefail

# ── 配置 ──
FLOW_ACTIVE="${FLOW_ACTIVE:-.flow-active}"

# ── checkpoint_write ────────────────────────────────────────────
# 参数: $1 = file (项目根相对路径), $2 = action (≤200 字符), $3 = failing_check (可选)
# 原子写入 .flow-active.interrupt, 失败保留旧值
checkpoint_write() {
  local file="${1:-}"
  local action="${2:-}"
  local failing_check="${3:-}"
  local ts
  ts=$(date -Iseconds)

  # 截断 action 到 200 字符
  if [[ "${#action}" -gt 200 ]]; then
    action="${action:0:197}..."
  fi

  # 原子写入
  if ! jq --arg file "$file" --arg action "$action" --arg ts "$ts" --arg fc "$failing_check" \
    '.interrupt = {
       active_file: $file,
       last_action: $action,
       failing_check: $fc,
       checkpoint_at: $ts
     } | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" 2>/dev/null; then
    echo "[checkpoint] WARNING: jq write failed, keeping old checkpoint value" >&2
    rm -f "${FLOW_ACTIVE}.tmp"
    return 1
  fi

  # JSON 合法性校验
  if ! checkpoint_validate "${FLOW_ACTIVE}.tmp"; then
    echo "[checkpoint] WARNING: JSON validation failed after write, discarding" >&2
    rm -f "${FLOW_ACTIVE}.tmp"
    return 1
  fi

  mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"
  return 0
}

# ── checkpoint_validate ─────────────────────────────────────────
# 参数: $1 = 文件路径
# 返回 0 = 合法 JSON, 返回 1 = 非法
checkpoint_validate() {
  local file="$1"
  if ! jq empty "$file" 2>/dev/null; then
    return 1
  fi
  return 0
}

# ── checkpoint_clear ────────────────────────────────────────────
# 清除 interrupt 字段（change 归档或手动 /flow stop 时用）
checkpoint_clear() {
  local ts
  ts=$(date -Iseconds)

  jq --arg ts "$ts" \
    '.interrupt = null | .updated_at = $ts' \
    "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" 2>/dev/null || {
    rm -f "${FLOW_ACTIVE}.tmp"
    return 1
  }

  mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"
  return 0
}
