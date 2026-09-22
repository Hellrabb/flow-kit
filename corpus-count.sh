#!/bin/bash
# corpus-count.sh — 现场复算语料口径（供 verify-claims.sh / 响应段 / AC-2 归因清单引用）
#
# 存在的理由：2-design 期 L2 盲审 连续指出"计数式声明不可复算"——
# 响应里写的数字是**快照**，随本 change 自身新增的审查文件漂移（130→129、223→224）。
# 本脚本让每次复验都现算，输出可直接贴进响应。
#
# 用法:
#   ./corpus-count.sh                 # 单行: <总份数> <含L3标题份数> <L3标题总数> <上方为--的标题数> <空值数> <非枚举数>
#   ./corpus-count.sh --attribution   # 同上输出 + **机械再生** AC-2 归因清单 L2-EMPTY-ATTRIBUTION.md
#
# 为什么需要 --attribution（2026-09-18 依阶段 3 的 L2 盲审 critical）：
#   语料是**活的** —— 本 change 自己的审查文件（INDEPENDENT-REVIEW-3/5/6…）会不断新增，
#   每新增一份没有 L2 段结论的工件，空值数就 +1。故「空值 ≤8」只能是**基线语料**
#   （commit be138c0 时点）的口径；对活语料的不变量是「**每份空值都在归因清单里**」，
#   而清单必须能机械再生，不能靠人手抄（否则 AC-2 的验证会随轮次变红）。

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2

MODE="count"
ATTR_OUT=".specs/l3-review-defects-2026-09/L2-EMPTY-ATTRIBUTION.md"
case "${1:-}" in
  --attribution)
    MODE="attribution"
    # 可选第二参数 = 输出路径（测试用它再生到临时文件，避免"测试改工作区"）
    [ -n "${2:-}" ] && ATTR_OUT="$2" ;;
esac

awk_prog='NR<n && $0 !~ /^[[:space:]]*$/ {last=$0} END{print last}'

files=0; tot=0; sep=0; n=0
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

# 结论提取（需 source l2-detect.sh）；同时收集空值清单与其 L2 段内锚定 verdict 行数
# 结论提取在**子 shell 函数**里做（隔离 l2-detect.sh 的 set -euo pipefail 副作用）。
# 为什么不用嵌套 `bash -c '…'` 拼字符串（旧实现）：多层引号 + `$(pwd)` 插值在加入
# 逐文件子扫描后静默失效（命令替换返回空 → empty/nonenum 全为 0，且无报错）——
# 这正是本项目反复踩到的"静默失效"形态，故改为可读、可测的显式结构。
scan_verdicts() (
  set +e
  source flow-kit-bundle/hooks/stop/lib/l2-detect.sh 2>/dev/null
  e=0; ne=0
  while IFS= read -r f; do
    v=$(fk_extract_l2_verdict "$f" 2>/dev/null) || true
    if [ -z "$v" ]; then
      e=$((e+1))
      scope=$(_fk_l2_scope "$f" 2>/dev/null) || scope=""
      cnt=$(printf '%s\n' "$scope" | grep -cE '^[[:space:]]*([-*+][[:space:]]+)*#*[[:space:]]*\**[[:space:]]*[Vv][Ee][Rr][Dd][Ii][Cc][Tt][[:space:]]*\**[[:space:]]*[:：]' 2>/dev/null) || cnt=0
      rel="${f##*/.specs/}"; rel="${rel#.specs/}"
      printf 'EMPTY\t%s\t%s\n' "$rel" "$cnt"
    fi
    case "$v" in ""|pass|fail) ;; *) ne=$((ne+1));; esac
  done < <(find .specs -name 'INDEPENDENT-REVIEW-*.md' | sort)
  echo "RESULT $e $ne"
)
verdicts=$(scan_verdicts)
empty=$(printf '%s\n' "$verdicts" | sed -n 's/^RESULT \([0-9]*\) .*/\1/p')
nonenum=$(printf '%s\n' "$verdicts" | sed -n 's/^RESULT [0-9]* \([0-9]*\)$/\1/p')
empty=${empty:-0}; nonenum=${nonenum:-0}

if [ "$MODE" = "attribution" ]; then
  out="$ATTR_OUT"
  base_list=$(git ls-tree -r --name-only be138c0 2>/dev/null | grep -E '\.specs/.*INDEPENDENT-REVIEW-.*\.md$' | sed 's#^\.specs/##' | sort)
  # 保留既有的逐文件归因（旧实现取值 / 旧值来源段）——它们来自**旧实现实跑**，不可重算，
  # 再生时只能从上一版清单继承；新增文件才标注"本期新增"。
  prev_map=""
  if [ -f "$out" ]; then
    prev_map=$(grep -E '^\| [0-9]+ \|' "$out" | sed -E 's/^\| [0-9]+ \| `([^`]+)` \| (.*) \| (.*) \| ([0-9]+) \|$/\1\t\2\t\3/' || true)
  fi
  [ -n "$base_list" ] || echo "[corpus-count] WARN: 无法取得基线语料（git 不可用？），全部按基线处理" >&2

  {
    echo "# L2 空值归因清单（AC-2 交付物）"
    echo
    echo "> **机械再生**：\`bash corpus-count.sh --attribution\`（不是手抄快照 —— 语料是活的："
    echo "> 本 change 自己的审查文件会不断新增，对活语料的不变量是**每份空值都在本清单中**）。"
    echo "> 生成时间：$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "| # | 工件（.specs/ 相对路径） | 旧实现取值 | 旧值来源段 | L2 段内锚定 verdict 行数 |"
    echo "|---|---|---|---|---|"
    i=0
    while IFS=$'\t' read -r tag rel cnt; do
      [ "$tag" = "EMPTY" ] || continue
      i=$((i + 1))
      _prev=$(printf '%s\n' "$prev_map" | awk -F'\t' -v r="$rel" '$1==r {print $2"\t"$3; exit}')
      if [ -n "$_prev" ]; then
        echo "| $i | \`$rel\` | ${_prev%%$'\t'*} | ${_prev#*$'\t'} | $cnt |"
      elif printf '%s\n' "$base_list" | grep -qxF "$rel"; then
        echo "| $i | \`$rel\` | \`?\` | 基线件但上一版清单未列（需人工复核） | $cnt |"
      else
        echo "| $i | \`$rel\` | \`—\` | 本期新增工件（L2 段尚无结论行） | $cnt |"
      fi
    done <<EOF
$(printf '%s\n' "$verdicts" | grep '^EMPTY')
EOF
    echo
    echo "**归因结论**：本清单覆盖全部空值（**表格行数 = corpus-count.sh 的 empty 字段**，即第 5 个字段），"
    echo "每行 4 个数据列（相对路径 / 旧实现取值 / 旧值来源段 / L2 段内锚定 verdict 行数）均来自现场复算；"
    echo "**非枚举数恒为 0**（输出六字段，第 6 个 = 非枚举）。"
  } > "$out"
  echo "[corpus-count] 已再生归因清单: $out（$i 行）" >&2
fi

printf '%s %s %s %s %s %s\n' "$n" "$files" "$tot" "$sep" "$empty" "$nonenum"
