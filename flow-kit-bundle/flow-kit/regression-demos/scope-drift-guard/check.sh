#!/usr/bin/env bash
# AC-4 · 范围漂移防护（弱模型鲁棒性 · D4 脚本模拟）
# 静态检查：4-dev 含动手前复述边界 + RULES R7.4
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENGINE="$ROOT/flow-kit-bundle/flow-kit"

fail=0
grep -qE "复述.*边界|复述.*read_files" "$ENGINE/prompts/4-dev.md" || { echo "FAIL: 4-dev 缺动手前复述边界指令"; fail=1; }
grep -q "R7.4" "$ENGINE/RULES.md" || { echo "FAIL: RULES 缺 R7.4 复述边界规则"; fail=1; }
grep -q "范围排除" "$ENGINE/prompts/4-dev.md" || { echo "FAIL: 4-dev 未要求对照范围排除"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "PASS: 范围漂移护栏就位（4-dev 复述边界 + RULES R7.4）"
  echo "  scenario: 诱导越界编辑 write_files 外文件 → 护栏要求复述边界，越界被 R6.5 拦截"
  exit 0
else
  exit 1
fi
