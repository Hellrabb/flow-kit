#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-3 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d)   # 夹具并发隔离（清理见下方合并 trap —— EXIT trap 只能有一个）
# 前置（Given）：仓库全绿
make lint >/dev/null 2>&1 || { echo "❌ 前置不满足：基线 make lint 未绿"; exit 1; }
F=flow-kit-bundle/install.sh
trap 'git checkout -- '"$F"'; rm -rf "$TMPD"' EXIT   # 合并：git 还原 + TMPD 清理（EXIT trap 只能一个）
printf '\nif [ 1 -eq 1 ]\n' >> "$F"
if make lint >$TMPD/ac3.log 2>&1; then echo "❌ FAIL: 漏扫文件中的语法错误未被抓到"; exit 1; fi
grep -q 'install\.sh' $TMPD/ac3.log || { echo "❌ FAIL: 未指名 install.sh"; exit 1; }
grep -qiE 'error' $TMPD/ac3.log \
  || { echo "❌ FAIL: 未输出 error 级诊断"; exit 1; }   # 放宽：不绑定特定 SC 码（版本升级/注入形态变化不应使 AC 误红）
echo "✅ AC-3 PASS"

