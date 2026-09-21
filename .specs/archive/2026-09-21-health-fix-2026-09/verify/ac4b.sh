#!/bin/bash
# AC-4b 验证 · 排除集与契约的**结构性一致**（L3 阶段5 C2 补 · 第三版）
#
# 为何不是简单"模式字面量逐个比对"：那需要在验证侧重写 6 条模式 —— 属"把实现当判据"，
# 两边共享同一份常量，一起错就一起过（本 change 反复打击的反模式）。
#
# 为何不用"目录是否存在"/"是否命中文件"：`.git`、`.omo`、`.claude`、`.specs`、`test` 真实存在；
# 但 `node_modules`、`brooks-tools` **当前不存在却属正当的防御性排除**（第三方目录可能随时出现）
# → 存在性判据会误报它们（本夹具前两版实测踩过这两个坑）。
#
# 本版用**结构性判据**：把实现侧排除集的 (模式数, 组件名集合) 与契约表比对。
#   - 静默**新增**一条模式 → 模式数 +1 且组件集多一项 → 报 FAIL（正确）
#   - 静默**删除**一条模式 → 模式数 -1 且组件集少一项 → 报 FAIL（正确）
#   - 正当的防御性排除（目标不存在）→ 不报（正确，因为它仍在契约表内）
#
# 契约单一来源：REQUIREMENT.md 的 AC-4b 表格（本文件不复制模式字面值，只读它的**组件名**）。
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT

REQ=".specs/health-fix-2026-09/REQUIREMENT.md"
[ -f "$REQ" ] || { echo "❌ FAIL: 找不到 $REQ（契约来源）"; exit 1; }

# ── 实现侧：从 Makefile 抽取排除模式，提取组件名 ──
sed -n '/^SCAN_EXCLUDES/,/^$/p' Makefile \
  | grep -oE "\-not \-path '[^']+'" | sed "s/.*-path '//; s/'\$//" > "$TMPD/impl_pats.txt"
_impl_n=$(grep -c . "$TMPD/impl_pats.txt" || true)
: > "$TMPD/impl_comp.txt"
while IFS= read -r pat; do
  [ -n "$pat" ] || continue
  c="$pat"
  c="${c#./}"; c="${c#\*/}"; c="${c%\*}"; c="${c%\/}"
  printf '%s\n' "$c" >> "$TMPD/impl_comp.txt"
done < "$TMPD/impl_pats.txt"
sort -u "$TMPD/impl_comp.txt" -o "$TMPD/impl_comp.txt"

# ── 契约侧：从 REQUIREMENT 的 AC-4b 表格行抽取组件名（形如 `.git/`、`node_modules/`）──
awk '/^### AC-4b/,/^### AC-4c/' "$REQ" \
  | grep -oE '`[./A-Za-z0-9_-]+/`' | tr -d '`' | sed 's|/$||; s|^\./||' | sort -u > "$TMPD/contract_comp.txt"
_contract_n=$(grep -c . "$TMPD/contract_comp.txt" || true)

if [ "$_contract_n" -eq 0 ]; then
  echo "❌ FAIL: 未能从 AC-4b 契约表解析出组件名（契约表格式可能已变）"
  exit 1
fi

# ── 结构性比对 ──
_only_impl=$(comm -23 "$TMPD/impl_comp.txt" "$TMPD/contract_comp.txt")
_only_contract=$(comm -13 "$TMPD/impl_comp.txt" "$TMPD/contract_comp.txt")

fail=0
if [ -n "$_only_impl" ]; then
  echo "❌ FAIL: 实现侧多出排除组件（疑似静默扩张）: $(echo $_only_impl)"
  fail=1
fi
if [ -n "$_only_contract" ]; then
  echo "❌ FAIL: 契约要求但实现侧缺失: $(echo $_only_contract)"
  fail=1
fi
[ "$fail" -eq 0 ] || exit 1

echo "✅ AC-4b PASS（排除集 ${_impl_n} 条模式 / 组件集与契约逐项一致：$(echo $_only_impl$_only_contract | wc -w) 处偏差）"
