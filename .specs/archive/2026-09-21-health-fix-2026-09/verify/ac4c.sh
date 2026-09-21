#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-4c 验证（可复制执行 · 独立于实现重算契约排除集，检测静默扩张）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
make lint >/tmp/ac4c_log 2>&1 || { echo "❌ FAIL: make lint 非零退出"; exit 1; }
awk '/^SCANNED_FILES:/{f=1;next} f&&/^\.\//{print;next} f&&!/^$/{exit}' /tmp/ac4c_log \
  | sed 's|^\./||' | sort -u > $TMPD/ac4c_scanned.txt

# 契约排除集：与 AC-4b 表格逐项对应（本文件的契约，非实现细节）
find . -name '*.sh' \( -path '*/.git/*' -o -path '*/node_modules/*' \
  -o -path '*/brooks-lint/*' -o -path '*/brooks-tools/*' -o -path '*/dist/*' \
  -o -path '*/.omo/*' -o -path '*/.claude/*' -o -path '*/.specs/*' -o -path '*/test/*' \) \
  | sed 's|^\./||' | sort -u > $TMPD/ac4c_excluded.txt

# 全仓可发现 .sh 集
find . -name '*.sh' -not -path '*/.git/*' | sed 's|^\./||' | sort -u > $TMPD/ac4c_all.txt

cat $TMPD/ac4c_scanned.txt $TMPD/ac4c_excluded.txt | sort -u > $TMPD/ac4c_union.txt
gap=$(comm -13 $TMPD/ac4c_union.txt $TMPD/ac4c_all.txt | wc -l)
[ "$gap" -eq 0 ] || { echo "❌ FAIL: $gap 个文件既未被扫描也未被契约排除（疑似静默扩张排除项）"; comm -13 $TMPD/ac4c_union.txt $TMPD/ac4c_all.txt; exit 1; }
echo "✅ AC-4c PASS（扫描集 ∪ 契约排除集 == 全仓 .sh 集）"

