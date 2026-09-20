#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-1 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d)   # 夹具并发隔离（清理见下方合并 trap —— EXIT trap 只能有一个）
# 前置（Given · 两项）：① dist 与源一致（否则基线结论不可信）；② make check 全绿
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null \
  || { echo "❌ 前置不满足：dist 与源不一致，请先 bash package-dsh-plugin.sh"; exit 1; }
make check >/dev/null 2>&1 || { echo "❌ 前置不满足：基线 make check 未绿"; exit 1; }
# ⚠️ 只能有一个 EXIT trap（后注册会覆盖先注册）—— 故 TMPD 清理与 git 还原**合并**为一条
trap 'git checkout -- dsh-flow-kit/README.md; rm -rf "$TMPD"' EXIT
printf '\n<!-- AC1 probe -->\n' >> dsh-flow-kit/README.md
if make check >$TMPD/ac1.log 2>&1; then echo "❌ FAIL: 陈旧未被拦下"; exit 1; fi
grep -qi 'README.md' $TMPD/ac1.log || { echo "❌ FAIL: 未指名陈旧文件"; exit 1; }
echo "✅ AC-1 PASS"

