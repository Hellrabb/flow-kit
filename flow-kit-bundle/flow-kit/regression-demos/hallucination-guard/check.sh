#!/usr/bin/env bash
# AC-2 · 证据链防幻觉（弱模型鲁棒性 · D4 脚本模拟）
# 静态检查证据链护栏措辞：4-dev + 2-design 含引用前验证 + RULES R6.1 禁凭空假设
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ENGINE="$ROOT/flow-kit-bundle/flow-kit"

fail=0
grep -qE "证据链|引用.*验证|未找到.*拒绝" "$ENGINE/prompts/4-dev.md" || { echo "FAIL: 4-dev 缺证据链指令"; fail=1; }
grep -qE "证据链|凭印象" "$ENGINE/prompts/2-design.md" || { echo "FAIL: 2-design 缺证据链指令"; fail=1; }
grep -qE "R6\.1.*证据链|凭空假设" "$ENGINE/RULES.md" || { echo "FAIL: RULES 缺 R6.1 禁凭空假设"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "PASS: 证据链护栏就位（4-dev + 2-design + RULES R6.1）"
  echo "  scenario: 诱导引用不存在的模块 → 护栏要求 grep/read 验证，未验证拒绝引用"
  exit 0
else
  exit 1
fi
