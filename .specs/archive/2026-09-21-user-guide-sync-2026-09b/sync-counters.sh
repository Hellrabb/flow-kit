#!/usr/bin/env bash
# sync-counters.sh — 把「计数类事实」从判据脚本的实跑输出回填进产物（v4.5 · 结构性处置）
#
# 为什么需要：多轮 L2/L3 反复抓到「同一事实多套数字」（手抄漂移）。本脚本让数字只有一个来源：
#   verify-ac.sh 的分段/总数、check-appendix-superset.py 的格数、bats 用例数、pptx 页数。
# 用法：bash .specs/user-guide-sync-2026-09b/sync-counters.sh
set -uo pipefail
# 仓库根解析（v4.7）：逐级上溯找 package-dsh-plugin.sh —— 兼容 .specs/<id>/ 与 .specs/archive/<date>-<id>/ 两种落点
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/package-dsh-plugin.sh" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
[ -f "$ROOT_DIR/package-dsh-plugin.sh" ] || { echo "❌ 未能定位仓库根（脚本：${BASH_SOURCE[0]}）" >&2; exit 2; }
cd "$ROOT_DIR" || exit 2
D=".specs/user-guide-sync-2026-09b"

VA="$(bash "$D/verify-ac.sh" 2>&1)"
TOTAL="$(printf '%s\n' "$VA" | sed -n 's/^- 断言通过：//p' | tail -1)"
AC1="$(printf '%s\n' "$VA" | sed -n 's/^  AC-1   通过 \([0-9]*\).*/\1/p')"
AC2="$(printf '%s\n' "$VA" | sed -n 's/^  AC-2   通过 \([0-9]*\).*/\1/p')"
AC3="$(printf '%s\n' "$VA" | sed -n 's/^  AC-3   通过 \([0-9]*\).*/\1/p')"
AC4="$(printf '%s\n' "$VA" | sed -n 's/^  AC-4   通过 \([0-9]*\).*/\1/p')"

SUP="$(python3 "$D/check-appendix-superset.py" 2>&1)"
CELLS="$(printf '%s\n' "$SUP" | sed -n 's/检查单元格：\([0-9]*\) 个.*/\1/p')"
SKIPS="$(printf '%s\n' "$SUP" | sed -n 's/.*跳过（无可抽锚点）：\([0-9]*\) 个.*/\1/p')"
MISS="$(printf '%s\n' "$SUP" | sed -n 's/.*附录 A 缺失：\([0-9]*\) 个.*/\1/p')"

BATS_N="$(grep -c '^@test' test/test_guide_copy_parity.bats)"
PAGES="$(python3 -c "from pptx import Presentation; print(len(Presentation('flow-kit-用户指南.pptx').slides))" 2>/dev/null || echo '?')"
BATS_ALL="$(npx bats test/ --formatter tap 2>/dev/null | grep -E '^1\.\.' | tail -1 | tr -d '1..')"

echo "权威计数：verify-ac 总 $TOTAL（AC-1 $AC1 · AC-2 $AC2 · AC-3 $AC3 · AC-4 $AC4）"
echo "          集合断言 $CELLS 格 / 跳过 $SKIPS / 缺失 $MISS"
echo "          守护用例 $BATS_N · 全量 bats $BATS_ALL · pptx $PAGES 页"

# 回填（只改「数字本身」，不动语义）——用保守的字面替换，避免误伤
python3 - "$TOTAL" "$AC1" "$AC2" "$AC3" "$AC4" "$CELLS" "$SKIPS" "$MISS" "$BATS_N" "$BATS_ALL" "$PAGES" <<'PY'
import pathlib, re, sys
total, ac1, ac2, ac3, ac4, cells, skips, miss, bats_n, bats_all, pages = sys.argv[1:12]
D = pathlib.Path('.specs/user-guide-sync-2026-09b')
files = [D/'TEST.md', D/'UAT.md', D/'REVIEW.md', D/'DEV-SUMMARY.md', pathlib.Path('.specs/CHANGELOG.md')]
pat_total = re.compile(r'断言通过[： ]\*{0,2}\d+')
pat_seg = re.compile(r'AC-1 (\d+) · AC-2 (\d+) · AC-3 (\d+) · AC-4 (\d+)')
pat_cells = re.compile(r'\d+ (?:单元格|检查格|格)')
pat_bats = re.compile(r'\b\d+/8 ok\b')
n = 0
for f in files:
    if not f.exists():
        continue
    s = f.read_text(encoding='utf-8'); o = s
    s = pat_total.sub(f'断言通过：{total}', s)
    s = pat_seg.sub(f'AC-1 {ac1} · AC-2 {ac2} · AC-3 {ac3} · AC-4 {ac4}', s)
    s = pat_cells.sub(f'{cells} 检查格（跳过 {skips}）', s)
    s = pat_bats.sub(f'{bats_n}/8 ok', s)
    s = s.replace('全量 bats 972 例', f'全量 bats {bats_all} 例').replace('全量 bats 973 例', f'全量 bats {bats_all} 例')
    if s != o:
        f.write_text(s, encoding='utf-8'); n += 1
print(f'回填文件数：{n}')
PY
