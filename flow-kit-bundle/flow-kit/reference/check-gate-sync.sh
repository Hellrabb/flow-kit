#!/bin/bash
# ============================================================================
# check-gate-sync.sh — 校验 prompt↔skill toll-gate 协议一致性
# 防止双入口漂移：prompt 改了但 skill 没改（或反之）
# exit: 0=一致, 1=发现漂移, 2=脚本错误
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ERRORS=0

echo "🔍 check-gate-sync: 校验 prompt↔skill toll-gate 协议一致性..."
echo ""

# ── 校验对 1: 4-dev prompt ↔ flow-dev skill ──
check_pair() {
  local label="$1"
  local prompt_file="$2"
  local skill_file="$3"
  local start_marker="$4"   # grep pattern for start of gate section
  local end_marker="$5"     # grep pattern for end of gate section

  echo "   校验: $label"
  echo "     prompt: $prompt_file"
  echo "     skill:  $skill_file"

  if [ ! -f "$prompt_file" ]; then
    echo "   ⚠️  WARNING: prompt 文件不存在，跳过"
    return
  fi
  if [ ! -f "$skill_file" ]; then
    echo "   ⚠️  WARNING: skill 文件不存在，跳过"
    return
  fi

  # 提取 prompt 中的 PCSC 行数
  local prompt_pcsc_lines
  prompt_pcsc_lines=$(grep -c "^| [0-9] |" "$prompt_file" 2>/dev/null || echo "0")

  # 提取 skill 中的 PCSC 行数（仅当 skill 有表时才比较）
  local skill_pcsc_lines
  skill_pcsc_lines=$(grep -c "^| [0-9] |" "$skill_file" 2>/dev/null || echo "0")

  if [ "$skill_pcsc_lines" -gt 0 ]; then
    if [ "$prompt_pcsc_lines" != "$skill_pcsc_lines" ]; then
      echo "   🔴 DRIFT: PCSC 自检表行数不一致！prompt=$prompt_pcsc_lines, skill=$skill_pcsc_lines"
      ERRORS=$((ERRORS + 1))
    else
      echo "   ✅ PCSC 表行数一致 ($prompt_pcsc_lines 行)"
    fi
  else
    echo "   ℹ️  skill 文件不含 PCSC 表（wrapper 模式，正常）"
  fi

  # 检查 pipeline-gates 引用
  if grep -q "pipeline-gates" "$prompt_file" 2>/dev/null && grep -q "pipeline-gates" "$skill_file" 2>/dev/null; then
    echo "   ✅ 双方均含 pipeline-gates 引用"
  else
    local p_has_ref s_has_ref
    p_has_ref=$(grep -c "pipeline-gates" "$prompt_file" 2>/dev/null || echo "0")
    s_has_ref=$(grep -c "pipeline-gates" "$skill_file" 2>/dev/null || echo "0")
    if [ "$p_has_ref" != "$s_has_ref" ]; then
      echo "   🔴 DRIFT: pipeline-gates 引用不一致！prompt=$p_has_ref, skill=$s_has_ref"
      ERRORS=$((ERRORS + 1))
    else
      echo "   ℹ️  双方均不含 pipeline-gates 引用（可能是旧版，尚未迁移）"
    fi
  fi


  # 检查关键协议关键词
  for keyword in "auto_advance" "toll-gate" "禁止自动继续" "Phase Transition"; do
    local p_count s_count
    p_count=$(grep -c "$keyword" "$prompt_file" 2>/dev/null || echo "0")
    s_count=$(grep -c "$keyword" "$skill_file" 2>/dev/null || echo "0")
    if [ "$p_count" != "$s_count" ]; then
      echo "   🟡 MINOR: '$keyword' 出现次数不一致 (prompt=$p_count, skill=$s_count)"
    fi
  done

  echo ""
}

# ── 校验对定义 ──
# 首批：4-dev prompt + flow-dev skill
check_pair \
  "4-dev ↔ flow-dev" \
  "$BUNDLE_ROOT/flow-kit/prompts/4-dev.md" \
  "$BUNDLE_ROOT/skills/flow-dev/SKILL.md" \
  "PCSC\|Phase Completion Self-Check" \
  "Phase Transition 4→5"

# 后续可按需加其他 phase 对

# ── 汇总 ──
echo "   ── 校验汇总 ──"
if [ "$ERRORS" -gt 0 ]; then
  echo "   🔴 发现 $ERRORS 处漂移。请同步 prompt 和 skill 的 toll-gate 协议段。"
  exit 1
else
  echo "   ✅ 所有校验对一致。"
  exit 0
fi
