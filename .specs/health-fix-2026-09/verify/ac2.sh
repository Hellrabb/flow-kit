#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-2 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
# 前置：确认 dist 与源一致（Given 的机器化）
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null \
  || { echo "❌ 前置不满足：dist 与源不一致，请先 bash package-dsh-plugin.sh"; exit 1; }
make check >$TMPD/ac2.log 2>&1 || { echo "❌ FAIL: make check 非零退出"; tail -20 $TMPD/ac2.log; exit 1; }
grep -qiE 'check-dist.*(pass|一致|✅|通过)' $TMPD/ac2.log \
  || { echo "❌ FAIL: 未见 check-dist 通过标记"; grep -i 'check-dist' $TMPD/ac2.log; exit 1; }
echo "✅ AC-2 PASS"

