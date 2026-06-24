#!/usr/bin/env bash
# AC-7 · 强模型不过度啰嗦（防加固反噬 · D4 脚本模拟 · 静态检查）
# 验证：加固为结构刚性（限定触发点 + 填空式 gate），且无重复唠叨措辞
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENGINE="$ROOT/flow-kit-bundle/flow-kit"

fail=0
# 1. 加固有意识地限定触发点（非唠叨）：4-dev「非每操作」，GO「仅入场」
grep -q "非每操作" "$ENGINE/prompts/4-dev.md" || { echo "FAIL: 4-dev 缺「非每操作」限定"; fail=1; }
grep -q "仅入场" "$ENGINE/GO.md" || { echo "FAIL: GO.md 缺「仅入场」限定"; fail=1; }
# 2. gate 是填空式（非冗长自由清单）
grep -q "填空" "$ENGINE/prompts/0-change.md" || { echo "FAIL: 0-change 缺填空式 gate"; fail=1; }
grep -q "填空" "$ENGINE/prompts/1-requirement.md" || { echo "FAIL: 1-requirement 缺填空式 gate"; fail=1; }
# 3. 反向：加固段不应有无条件唠叨（每步复述 goal / 每次操作 checkpoint）
if grep -qE "每步.*复述.*goal|每次操作.*checkpoint" "$ENGINE/prompts/4-dev.md" "$ENGINE/GO.md" 2>/dev/null; then
  echo "FAIL: 检测到无条件唠叨措辞（每步复述 goal / 每次操作 checkpoint）"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: 加固为结构刚性（限定触发点 + 填空式 gate），无重复唠叨"
  echo "  定量阈值（输出 token/turn 增量 < 20%）需 v2 真跑强模型；本次靠静态检查 + 人工定性"
  exit 0
else
  exit 1
fi
