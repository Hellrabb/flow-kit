#!/bin/bash
# probe32.sh — 在任意 bash（含 3.2）+ 任意 sed/awk（含 busybox）下验证四组关键行为。
# 用途：M50「跨目标环境未实测」的**真机证据**（不依赖 bats —— bats 1.13 在 bash 3.2 下
# 无法派发含中文的用例名）。
# 用法: bash probe32.sh [仓库根]
set -u
ROOT="${1:-.}"
cd "$ROOT" || exit 2
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }

printf '=== 环境 ===\n'
bash --version | head -1
printf 'awk: '; awk 'BEGIN{print "ok"}' 2>&1 | head -1
printf 'sed: '; echo x | sed 's/x/y/' 2>&1 | head -1
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT

L3SEC=flow-kit-bundle/hooks/stop/lib/l3-section.sh
L2DET=flow-kit-bundle/hooks/stop/lib/l2-detect.sh
L3PROMPT=flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
GATE=flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh

# ── B8：连续行首反斜杠 n=1..4 → 编码 n+1 → 解码 n（往返恒等，**真为多行载荷**）──
n_ok=0; n_bad=0
i=1
while [ "$i" -le 4 ]; do
  for sfx in '## 标题' '普通文本'; do
    tag="${i}_$(printf '%s' "$sfx" | tr -c 'a-zA-Z0-9' '_')"
    f="$T/in_$tag.md"; e="$T/enc_$tag.md"; s="$T/s.md"; b="$T/back_$tag.md"
    bs=$(printf '\\%.0s' $(seq 1 "$i"))
    printf -- '%s%s\n尾行\n' "$bs" "$sfx" > "$f"
    bash -c "source '$L3SEC' 2>/dev/null; _l3_escape_payload \"\$(cat '$f')\" > '$e'" 2>/dev/null
    printf '%s\n' '<!-- L2-PAYLOAD-ENCODED -->' > "$s"
    bash -c "source '$GATE' 2>/dev/null; cat '$s' '$e' | _gate_l3_decode_payload | sed '1d'" > "$b" 2>/dev/null
    if diff -q "$b" "$f" >/dev/null 2>&1; then
      n_ok=$((n_ok+1))
    else
      n_bad=$((n_bad+1))
      printf '  （n=%s sfx=%s 不一致）\n' "$i" "$sfx"
      diff "$b" "$f" 2>&1 | head -4 | sed 's/^/     /'
    fi
  done
  i=$((i+1))
done
[ "$n_bad" -eq 0 ] && ok "B8 往返恒等 n=1..4 × 2 后缀（$n_ok 组）" || bad "B8 往返恒等：$n_bad 组不一致"

# ── B10：结构自检三类形态 ──
printf -- '---\n\n## L3 盲审（m）\n\n正文\n\n## L2 盲审\n\n**Verdict**: pass\n' > "$T/damaged.md"
rc=0; out=$(bash -c "source '$L3SEC' 2>/dev/null; _l3_verify_review_structure '$T/damaged.md'" 2>&1) || rc=$?
{ [ "$rc" -eq 1 ] && case "$out" in *段尾*) true;; *) false;; esac; } \
  && ok "B10 段尾缺标记 → rc=1 + 诊断" || bad "B10 段尾检查（rc=$rc）"

{ printf -- '---\n\n## L2 盲审\n\n<!-- L2-PAYLOAD-ENCODED -->\n'; printf -- '\\\\## 编码内\n\n'; \
  printf -- '## L2 重审\n\n'; printf -- '\\## 区间外引用\n\n'; \
  printf -- '---\n\n## L3 盲审（m）\n\n<!-- /L3-SECTION -->\n'; } > "$T/mixed.md"
rc=0; out=$(bash -c "source '$L3SEC' 2>/dev/null; _l3_verify_review_structure '$T/mixed.md'" 2>&1) || rc=$?
{ [ "$rc" -eq 1 ] && case "$out" in *未绑定*) true;; *) false;; esac; } \
  && ok "B10 签名与转义行未绑定 → fail-closed" || bad "B10 绑定检查（rc=$rc）"

{ printf -- '---\n\n## L2 盲审\n\n\\## 纯引用\n\n'; printf -- '---\n\n## L3 盲审（m）\n\n<!-- /L3-SECTION -->\n'; } > "$T/unsigned.md"
rc=0; out=$(bash -c "source '$L3SEC' 2>/dev/null; _l3_verify_review_structure '$T/unsigned.md'" 2>&1) || rc=$?
{ [ "$rc" -eq 0 ] && case "$out" in *NOTE*) true;; *) false;; esac; } \
  && ok "B10 无签名 → advisory（rc=0 + NOTE）" || bad "B10 advisory 分支（rc=$rc）"

# ── B9：守卫三形态 ──
mk(){ printf '%s' "$2" > "$T/g.md"; }
mk x "$(printf -- '---\n\n## L3 盲审（m）\n')"
rc=0; bash -c "source '$GATE' 2>/dev/null; _gate_path_guard Write '$T/INDEPENDENT-REVIEW-1.md' '' \"\$(cat '$T/g.md')\"" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok "B9 未转义「--- + ## L3」→ 拒绝 rc=2" || bad "B9 拒绝分支（rc=$rc）"

mk x "$(printf -- '\\## L3 盲审（m）\n')"
rc=0; bash -c "source '$GATE' 2>/dev/null; _gate_path_guard Write '$T/INDEPENDENT-REVIEW-1.md' '' \"\$(cat '$T/g.md')\"" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 0 ] && ok "B9 无签名纯引用 → 放行 rc=0" || bad "B9 放行分支（rc=$rc）"

printf -- '<!-- L2-PAYLOAD-ENCODED -->\n\n---\n\n\\## L3 盲审（m）\n' > "$T/signed.md"
rc=0; bash -c "source '$GATE' 2>/dev/null; _gate_path_guard Write '$T/INDEPENDENT-REVIEW-1.md' '' \"\$(cat '$T/signed.md')\"" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok "B9 带签名解码后成段 → 拒绝 rc=2（双形态判据）" || bad "B9 双形态判据（rc=$rc）"

# ── B11：大 diff 的提示词构造（ARG_MAX 修法）+ 截断留痕 ──
R="$T/repo"; mkdir -p "$R/.specs/fake"
( cd "$R" && git init -q . && printf 'base\n' > big.txt && git add big.txt \
  && git -c user.email=t@e.com -c user.name=t commit -qm base \
  && j=1 && while [ "$j" -le 3000 ]; do echo "+ 填充行 $j：跨过单个 argv 上限 131072B"; j=$((j+1)); done > big.txt ) >/dev/null 2>&1
sz=$(bash -c "source '$L3PROMPT' 2>/dev/null; _l3_build_prompt 6 '$R/.specs/fake' 400000 2>/dev/null | wc -c" 2>/dev/null)
[ "${sz:-0}" -gt 131072 ] && ok "B11 大提示词构造成功（${sz}B > 128KiB，无 ARG_MAX 报错）" || bad "B11 大提示词构造（${sz:-未产出}B）"

mkdir -p "$T/extra"
{ echo '# UAT'; j=1; while [ "$j" -le 400 ]; do echo "- UAT 步骤 $j：这条足够长以跨过 3000B 的补充产物预算"; j=$((j+1)); done; } > "$T/extra/UAT.md"
printf '# CHANGE\n- 一条\n' > "$T/extra/CHANGE.md"
out=$(bash -c "source '$L3PROMPT' 2>/dev/null; _l3_extra_deliverables '$T/extra'" 2>/dev/null)
case "$out" in *补充产物预算*) ok "B11 截断留痕（含预算说明）";; *) bad "B11 截断留痕";; esac

printf '\n=== 结果：%s ok / %s fail ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
