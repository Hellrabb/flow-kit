#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-9 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
miss=""
grep -q 'health-fix-2026-09' Makefile                   || miss="$miss Makefile"
grep -q 'health-fix-2026-09' sync-hooks.sh              || miss="$miss sync-hooks.sh"
grep -q 'health-fix-2026-09' package-dsh-plugin.sh      || miss="$miss package-dsh-plugin.sh"
[ -z "$miss" ] || { echo "❌ FAIL: 缺理由注释（含 change-id 锚点）:$miss"; exit 1; }
echo "✅ AC-9 PASS（三载体均有可追溯的理由注释）"

