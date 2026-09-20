#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-4 验证（可复制执行 · 解析 make lint 固定输出的 SCANNED_FILES 清单，不复制枚举逻辑）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
make lint >/tmp/ac4_log 2>&1 || { echo "❌ FAIL: make lint 非零退出"; tail -20 /tmp/ac4_log; exit 1; }
grep -qE '^SCANNED_FILES:' /tmp/ac4_log || { echo "❌ FAIL: make lint 未输出 'SCANNED_FILES:' 行（F2 须固定输出该行）"; exit 1; }
# 输出契约：'./' 前缀相对路径、逐行、空行结束（见 AC-4 输出契约段）
awk '/^SCANNED_FILES:/{f=1;next} f&&/^\.\//{print;next} f&&!/^$/{exit}' /tmp/ac4_log \
  | sed 's|^\./||' | sort -u > $TMPD/ac4_in.txt
[ -s $TMPD/ac4_in.txt ] || { echo "❌ FAIL: 解析出的扫描清单为空"; exit 1; }
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/node_modules/*' \
  -not -path '*/brooks-lint/*' -not -path '*/brooks-tools/*' -not -path '*/dist/*' \
  -not -path '*/.omo/*' -not -path '*/.claude/*' -not -path '*/.specs/*' -not -path '*/test/*' \
  | sed 's|^\./||' | sort > $TMPD/ac4_all.txt
miss=$(comm -13 $TMPD/ac4_in.txt $TMPD/ac4_all.txt | wc -l)
[ "$miss" -eq 0 ] || { echo "❌ FAIL: 仍有 $miss 个漏扫"; comm -13 $TMPD/ac4_in.txt $TMPD/ac4_all.txt; exit 1; }
# 反向断言（L2 阶段5 R3 补 · DESIGN R7 的要求）：契约排除项**不得**出现在扫描清单里。
# 只验"不漏扫"是单向的 —— 实现若把排除集删空，漏扫检查照样通过，等于把第三方/派生目录
# 也扫进来（引入无关 error，污染门禁）。双向断言才闭环。
_leak=0
for pat in '/.git/' '/node_modules/' '/brooks-lint/' '/brooks-tools/' '/dist/' '/.omo/' '/.claude/' '/.specs/' '/test/'; do
  n=$(grep -c -- "$pat" $TMPD/ac4_in.txt || true)
  if [ "${n:-0}" -gt 0 ]; then echo "❌ FAIL: 排除项 $pat 泄漏进扫描清单（$n 条）"; _leak=1; fi
done
[ "$_leak" -eq 0 ] || exit 1
echo "✅ AC-4 PASS（覆盖率 100% + 排除项零泄漏）"

