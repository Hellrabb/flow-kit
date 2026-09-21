#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-5 验证（可复制执行 · 显式捕获退出码，不走管道）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
make check-hooks-sync >$TMPD/ac5.log 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "❌ FAIL: 退出码 $rc ≠ 0"; tail -20 $TMPD/ac5.log; exit 1; }
n=$(grep -c '缺可执行位' $TMPD/ac5.log || true)
[ "$n" -eq 0 ] || { echo "❌ FAIL: 仍有 $n 处「缺可执行位」告警"; grep '缺可执行位' $TMPD/ac5.log; exit 1; }
echo "✅ AC-5 PASS（exit 0 且 0 处告警）"

