#!/bin/bash
# verify-claims.sh — 对「响应段里的可验证声明」做机械复验
#
# 由来（2-design 期 L2 盲审 连续四轮「声明与工件不符」）：
#   主 agent 每轮把"已修"写进响应，但复验是**手写命令**，于是反复漏载体、漏口径：
#     · 二轮：声称登记 M11~ 实际没写
#     · 三审：5 条「已修」里 4 条与工件相反
#     · 四审：§9.1/§9.5 声称已修、DESIGN 自 16:02 起未再改动
#     · 五审：声称「已安装副本 clause4=1/1」，实际 7 份 prompt + 9 份 agent 载体
#   根因不是手滑，是**复验不可复算**。本脚本把复验变成机械动作：
#   载体**动态枚举**（不写死路径/数量），计数**现场复算**（不抄快照）。
#
# 用法: bash verify-claims.sh   → 逐项 PASS/FAIL；任一 FAIL 非零退出
#       make verify-claims

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 2

PASS=0
FAIL=0
pass() { printf '  ✅ %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  ❌ %s\n' "$1"; FAIL=$((FAIL + 1)); }
hdr()  { printf '\n── %s ──\n' "$1"; }

# ── 载体动态枚举：搜索根 + 文件名 ──
# 刻意把**用户级安装目录**也纳入，避免上一轮"只核对仓库内 2 份"的重演。
CARRIER_ROOTS=(
  "$SCRIPT_DIR"
  "$HOME/.claude"
  "$HOME/.config/opencode"
  "$HOME/.dsh/profiles/web/node_modules/dsh-flow-kit"
)
enumerate() { # <basename>
  local base="$1" root
  for root in "${CARRIER_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    find "$root" -name "$base" -type f 2>/dev/null
  done | grep -v '/\.git/' | sort -u
}

# ── 1. L2 固化指令的所有载体都含契约第 4 条 ──
hdr "1. L2 固化指令载体（动态枚举）"
mapfile -t _prompts < <(enumerate 'L2-blind-review.md')
if [ "${#_prompts[@]}" -eq 0 ]; then
  fail "未找到任何 L2-blind-review.md 载体（枚举失效？）"
else
  _bad=0
  for f in "${_prompts[@]}"; do
    # clause4 的**契约本体在 2026-09-19 变更**（决策 b：手工贴入整体禁止）—— 旧文案
    # 「贴入前必须对报告原文做载荷转义」已随守卫双形态判据废止（它正是 03:36 critical① 的漏洞本体）。
    # 断言改为新契约的核心句（等价强度：必须写明谁写 + 禁止手工贴入）。
    grep -q '手工贴入整体禁止' "$f" || { _bad=$((_bad + 1)); printf '      缺 clause4(新契约): %s\n' "$f"; }
  done
  [ "$_bad" -eq 0 ] && pass "carriers=${#_prompts[@]}，全部含 clause4" || fail "carriers=${#_prompts[@]}，缺 clause4 的有 ${_bad} 份"
fi

# ── 2. L2 reviewer agent（复合载体）所有副本都含该契约 ──
hdr "2. L2 reviewer agent 复合载体（动态枚举）"
mapfile -t _agents < <(enumerate 'flow-kit-l2-reviewer.md')
if [ "${#_agents[@]}" -eq 0 ]; then
  fail "未找到任何 flow-kit-l2-reviewer.md 载体"
else
  _bad=0
  for f in "${_agents[@]}"; do
    # clause4 的**契约本体在 2026-09-19 变更**（决策 b：手工贴入整体禁止）—— 旧文案
    # 「贴入前必须对报告原文做载荷转义」已随守卫双形态判据废止（它正是 03:36 critical① 的漏洞本体）。
    # 断言改为新契约的核心句（等价强度：必须写明谁写 + 禁止手工贴入）。
    grep -q '手工贴入整体禁止' "$f" || { _bad=$((_bad + 1)); printf '      缺 clause4(新契约): %s\n' "$f"; }
  done
  [ "$_bad" -eq 0 ] && pass "carriers=${#_agents[@]}，全部含 clause4" || fail "carriers=${#_agents[@]}，缺 clause4 的有 ${_bad} 份"
fi

# ── 3. hooks / prompts 镜像无漂移 ──
hdr "3. 副本漂移（sync-hooks.sh --check）"
if bash sync-hooks.sh --check >/tmp/.vc_sync 2>&1; then
  pass "漂移 0（$(grep -c '✅' /tmp/.vc_sync) 个副本目录）"
else
  fail "存在漂移：$(tail -1 /tmp/.vc_sync)"
fi

# ── 4. 转义契约：两个载荷写入方都走唯一入口、无内联 sed 残留 ──
hdr "4. 转义契约（ADR-026）"
L3API="flow-kit-bundle/hooks/stop/lib/l3-api.sh"
L2DET="flow-kit-bundle/hooks/stop/lib/l2-detect.sh"
SEC="flow-kit-bundle/hooks/stop/lib/l3-section.sh"
_c=0
grep -q '^_l3_escape_payload() {' "$SEC" || _c=$((_c + 1))
grep -q '_l3_escape_payload "\$content"' "$L3API" || _c=$((_c + 1))
grep -q '_l3_escape_payload "\$content"' "$L2DET" || _c=$((_c + 1))
_inline=$(grep -c "s~^(## " "$L3API" "$L2DET" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
[ "$_c" -eq 0 ] && [ "$_inline" -eq 0 ] && pass "唯一入口被两个写入方调用；内联 sed=0" || fail "缺口=${_c} 内联 sed=${_inline}"

# ── 5. 「L3 段存在」判据同源：裸正则残留 = 0 ──
hdr "5. L3 段存在判据同源（L-031）"
# 七审 R1：原写法是**恒真断言**（BRE 下 `(盲审|重审)` 按字面量匹配 → 永远 0）。
# 现改为匹配"真实 grep 调用里出现字面量 ^## L3 "，并排除整行注释。
_naked=$(grep -rnE "grep +(-[a-zA-Z]+ +)*['\"]?\^## L3 " flow-kit-bundle/hooks/ 2>/dev/null \
  | grep -vE '^[^:]+:[0-9]+: *#' | wc -l)
_has=$(grep -rl '_l3_has_section' flow-kit-bundle/hooks/ 2>/dev/null | wc -l)
[ "$_naked" -eq 0 ] && [ "$_has" -ge 3 ] && pass "裸正则=0；_l3_has_section 使用点=${_has} 个文件" || fail "裸正则=${_naked}（应 0）；_l3_has_section 文件数=${_has}（应 ≥3）"

# ── 6. 陈旧计数（功能性载体中不得出现已废弃的数字） ──
hdr "6. 陈旧计数"
_stale=$(grep -rn '130/130' flow-kit-bundle/ test/ flow-kit-bundle/flow-kit/prompts/ 2>/dev/null | wc -l)
[ "$_stale" -eq 0 ] && pass "130/130 残留=0" || fail "130/130 残留=${_stale}"

# ── 7. 语料计数现场复算（不抄快照） ──
hdr "7. 语料计数（现场复算）"
_cnt="$(bash corpus-count.sh 2>/dev/null)"
read -r _n _files _tot _sep _empty _nonenum _rest <<< "$_cnt"
if [ -z "${_n:-}" ]; then
  fail "corpus-count.sh 无输出"
elif [ "$_tot" = "$_sep" ] && [ "${_nonenum:-1}" -eq 0 ] 2>/dev/null; then
  pass "语料=${_n} 份；含 L3 标题=${_files} 份 / ${_tot} 条，上方为 --- 的=${_sep}；空值=${_empty} 非枚举=0"
else
  fail "计数不一致：$_cnt（要求 标题数==上方为---数 且 非枚举==0）"
fi

# ── 8. DESIGN 结构自洽：§5 编号连续、§2.x 有序、引用不悬空 ──
hdr "8. DESIGN 结构自洽"
D=".specs/l3-review-defects-2026-09/DESIGN.md"
_risk=$(grep -oE '^\| \*\*R[0-9]+\*\*' "$D" | grep -oE '[0-9]+' | tr '\n' ' ')
_exp=$(seq 1 "$(echo "$_risk" | wc -w)" | tr '\n' ' ')
_ord=$(grep -oE '^### 2\.[0-9]+' "$D" | grep -oE '[0-9]+$' | tr '\n' ' ')
_ref24=$(grep -c '§ 2\.4' "$D")
_has24=$(grep -c '^### 2\.4' "$D")
if [ "$_risk" = "$_exp" ] && [ "$_ord" = "$(seq 1 "$(echo "$_ord" | wc -w)" | tr '\n' ' ')" ] && { [ "$_ref24" -eq 0 ] || [ "$_has24" -ge 1 ]; }; then
  pass "§5 编号 R: ${_risk}|§2.x: ${_ord}|§2.4 引用自洽"
else
  fail "§5 R: ${_risk}（应 ${_exp}）|§2.x: ${_ord}|§2.4 引用=${_ref24} 定义=${_has24}"
fi

# ── 9. MINOR-DEFERRED 的 M 编号唯一且连续 ──
hdr "9. MINOR-DEFERRED 编号"
M=".specs/l3-review-defects-2026-09/MINOR-DEFERRED.md"
_ms=$(grep -oE '^\| M[0-9]+' "$M" | grep -oE '[0-9]+' | sort -n | tr '\n' ' ')
_mc=$(echo "$_ms" | wc -w)
_uniq=$(echo "$_ms" | tr ' ' '\n' | grep -c . )
_mexp=$(seq 1 "$_mc" | tr '\n' ' ')
if [ "$_ms" = "$_mexp" ]; then pass "M 编号连续 1..${_mc}"; else fail "M 编号=${_ms}（应 ${_mexp}）"; fi

# ── 10b. 复发性声明（前三轮反复被 L2 点名，纳入机械检查） ──
hdr "10b. 复发性声明"
_false=$(grep -c '人读语义不变' flow-kit-bundle/hooks/stop/lib/l3-section.sh 2>/dev/null)
[ "$_false" = "0" ] && pass "l3-section.sh 无「人读语义不变」假陈述" || fail "假陈述残留=${_false}（应 0）"
_n223=$(grep -rn '223 份' flow-kit-bundle/hooks/ test/ 2>/dev/null | wc -l)
[ "$_n223" -eq 0 ] && pass "陈旧计数 223 份 残留=0" || fail "223 份 残留=${_n223}（应 0）"

# ── 10c. DESIGN §0.5.1 覆盖全部被改文件（六审 R4 的机械版）──
hdr "10c. §0.5.1 覆盖被改文件"
_changed=$( { git diff --name-only 19b3463 HEAD 2>/dev/null; git status --short 2>/dev/null | awk '{print $2}'; } \
  | grep -E '\.(sh|bats)$|Makefile$' | grep -vE '^\.specs/' | sort -u )
_missing=""
for f in $_changed; do
  base="$(basename "$f")"
  grep -qF "$base" .specs/l3-review-defects-2026-09/DESIGN.md || _missing="$_missing $base"
done
if [ -z "$_missing" ]; then pass "被改的 $(echo "$_changed" | wc -l) 个脚本/bats 均在 §0.5.1 出现"
else fail "§0.5.1 未列:${_missing}"; fi

# ── 10. 门禁 ──
hdr "10. 门禁"
if make check >/dev/null 2>&1; then pass "make check 五门全绿"; else fail "make check 未通过"; fi

printf '\n══════════════════════════════════════\n'
printf '  复验结果: ✅ %d  ❌ %d\n' "$PASS" "$FAIL"
printf '══════════════════════════════════════\n'
[ "$FAIL" -eq 0 ]
