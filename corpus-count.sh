#!/bin/bash
# corpus-count.sh — 现场复算语料口径（供 verify-claims.sh / 响应段引用）
#
# 存在的理由：2-design 期 L2 盲审 连续指出"计数式声明不可复算"——
# 响应里写的数字是**快照**，随本 change 自身新增的审查文件漂移（130→129、223→224）。
# 本脚本让每次复验都现算，输出可直接贴进响应。
#
# 输出（单行，空格分隔）: <总份数> <含L3标题份数> <L3标题总数> <上方为--的标题数> <空值数> <非枚举数>

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2

awk_prog='NR<n && $0 !~ /^[[:space:]]*$/ {last=$0} END{print last}'

files=0; tot=0; sep=0; empty=0; nonenum=0; n=0
verdicts=""
while IFS= read -r f; do
  n=$((n + 1))
  c=$(grep -cE '^## L3 (盲审|重审)' "$f" 2>/dev/null); c=${c:-0}
  if [ "$c" -gt 0 ]; then
    files=$((files + 1)); tot=$((tot + c))
    while IFS=: read -r ln _; do
      prev=$(awk -v n="$ln" "$awk_prog" "$f")
      [ "$prev" = "---" ] && sep=$((sep + 1))
    done < <(grep -nE '^## L3 (盲审|重审)' "$f")
  fi
done < <(find .specs -name 'INDEPENDENT-REVIEW-*.md' | sort)

# 结论提取（单独一次，需 source l2-detect.sh）
verdicts=$(bash -c '
set +e
cd "'"$(pwd)"'" || exit 2
source flow-kit-bundle/hooks/stop/lib/l2-detect.sh 2>/dev/null
e=0; ne=0
while IFS= read -r f; do
  v=$(fk_extract_l2_verdict "$f" 2>/dev/null) || true
  if [ -z "$v" ]; then e=$((e+1)); fi
  case "$v" in ""|pass|fail) ;; *) ne=$((ne+1));; esac
done < <(find .specs -name "INDEPENDENT-REVIEW-*.md" | sort)
echo "$e $ne"')
empty=${verdicts%% *}
nonenum=${verdicts##* }

printf '%s %s %s %s %s %s\n' "$n" "$files" "$tot" "$sep" "$empty" "$nonenum"
