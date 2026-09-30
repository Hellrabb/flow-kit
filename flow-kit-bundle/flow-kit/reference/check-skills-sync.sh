#!/bin/bash
# ============================================================================
# check-skills-sync.sh — 校验 skill 薄壳 ↔ prompt 权威载体同步（C13 / AC-11）
# health-fix-2026-09c T12b（DESIGN D2/D5/D7；L2 r2 R2 / r3 R7 修订 2026-09-29）
# exit: 0=全部通过, 1=覆盖不足 / 内容重复 / @see 锚不可解析（二值 fail-closed）
# ============================================================================
# 职责边界（承接 check-gate-sync.sh 迁出的 PCSC 内容比对判据 · T12b ⑥）：
#   T12a 薄壳化（935aa3d）后 skill = frontmatter + 触发描述 + 薄壳声明 + @see，
#   旧判据「剥 front-matter 逐行 diff 一致」对薄壳载体必红且语义已失效——
#   skill 不再是 prompt 的副本，「一致性」让位于三条新判据（对偶互补）：
#   ① 覆盖（D5，阈值 100%）：受辖清单内每个 skill 必须配对权威载体，且
#      SKILL.md 存在 + 权威文件存在 + SKILL.md 有指向该权威的 @see 锚行；
#      skills/ 下匹配 flow-* 而未进清单/白名单 ⇒ 未登记 ⇒ 覆盖不足 rc≠0
#      （fail-closed：新增载体不登记即红，不得静默漏网）。
#   ② 不复制（D7）：双侧归一化行集（滤空行 / `---` / ``` 栅栏 + sort -u）后
#      comm -12 公共行必须为 0 —— 薄壳不得复制权威正文（复制 = 双源漂移温床，
#      未滤平凡行则空行/栅栏必共线 → 假红，故先归一化）。
#   ③ @see 可解析（D5 ⑦）：锚行（^>?@see 起）内 flow-kit/... 目标文件必须存在；
#      §「小节标题」必须在**就近前置目标**文件 grep 命中（行内多目标时 § 归属
#      其前最近的路径——如 commit-protocol 行内 § 属 4-dev.md）。括号注记是
#      散文摘要而非机读锚（实测逐项命中在现树必红），不入判据。
#   豁免白名单（D5 显式登记；白名单外覆盖率不足即 rc≠0）：
#     flow-go          → 权威载体 = flow-kit/GO.md（白名单映射，①②③ 全辖）
#     flow-kit-install → 安装文档型，无权威正文配对，清单外豁免（不辖）
#     skills/flow      → 非阶段 skill（PRESET_MAP 载体），不匹配 flow-* glob
#   ②重复判据豁免（T12b 偏差①，登记于 T12b-SUMMARY.md）：flow-dev 为 T12a
#     定稿的部分骨架薄壳（保留段落骨架 + 分节 @see），实测归一化公共行 63≠0；
#     ①覆盖 + ③@see 仍辖，仅 ②comm=0 豁免——显式登记，非静默。
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"   # 布局约定同 check-gate-sync.sh：其下含 flow-kit/ + skills/

ERRORS=0

# 受辖清单（单点维护）：skill 目录名 | 权威载体（相对 BUNDLE_ROOT）
GOVERNED_PAIRS=(
  "flow-change|flow-kit/prompts/0-change.md"
  "flow-requirement|flow-kit/prompts/1-requirement.md"
  "flow-ui-design|flow-kit/prompts/2a-ui-design.md"
  "flow-design|flow-kit/prompts/2-design.md"
  "flow-task|flow-kit/prompts/3-task.md"
  "flow-dev|flow-kit/prompts/4-dev.md"
  "flow-test|flow-kit/prompts/5-test.md"
  "flow-review|flow-kit/prompts/6-review.md"
  "flow-integration|flow-kit/prompts/7-integration.md"
  "flow-architect|flow-kit/prompts/A-architect.md"
  "flow-evolve|flow-kit/prompts/A-evolve.md"
  "flow-intel|flow-kit/prompts/I-intel-scan.md"
  "flow-restyle|flow-kit/prompts/L-restyle.md"
  "flow-health|flow-kit/prompts/M-health.md"
)
# 白名单映射（D5）：权威载体非 prompts/ 编号正文，①②③ 判据同样全辖
WHITELIST_PAIRS=(
  "flow-go|flow-kit/GO.md"
)
# 清单外豁免：安装文档型 skill，无权威正文配对（D5）
EXEMPT_SKILLS=( "flow-kit-install" )
# ②重复判据豁免（仅 comm=0；覆盖与 @see 仍辖）—— T12b 偏差①
DUP_EXEMPT=( "flow-dev" )

# D7 归一化：滤平凡行（空行 / `---` / 代码栅栏）后行集去重排序
normalize_line_set() {
  grep -vE '^[[:space:]]*$|^---$|^```' "$1" | sort -u
}

is_in_list() {   # is_in_list <item> <elem...> —— 纯成员判定（清单/白名单/豁免共用）
  local want="$1"; shift
  local e
  for e in "$@"; do
    if [ "$e" = "$want" ]; then return 0; fi
  done
  return 1
}

# ── ③ @see 锚可解析：token 走查（路径 | §小节），§ 归属就近前置路径 ──
# 只认锚行（行首允许多余引用符 > 与空白）：`^[[:space:]]*>?[[:space:]]*@see`——
# 薄壳声明等散文行内出现的「@see 链」字样不构成锚（实测 flow-dev:6 即散文行）。
check_see_anchors() {   # <skill_name> <skill_file>
  local skill="$1" file="$2"
  local raw lineno line cur tok title n bad
  n=0; bad=0
  while IFS= read -r raw; do
    lineno="${raw%%:*}"
    line="${raw#*:}"
    n=$((n + 1))
    cur=""
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      case "$tok" in
        '§'*)
          title="${tok#§「}"; title="${title%」}"
          if [ -z "$cur" ]; then
            echo "     🔴 SEE: skills/$skill/SKILL.md:$lineno §「$title」前无目标路径（锚行内缺 flow-kit/ 路径）"
            bad=$((bad + 1))
          elif ! grep -qF -- "$title" "$BUNDLE_ROOT/$cur"; then
            echo "     🔴 SEE: skills/$skill/SKILL.md:$lineno §「$title」未在 $cur 命中（小节锚不可解析）"
            bad=$((bad + 1))
          fi
          ;;
        flow-kit/*)
          cur="$tok"
          if [ ! -f "$BUNDLE_ROOT/$tok" ]; then
            echo "     🔴 SEE: skills/$skill/SKILL.md:$lineno @see 目标不存在: $tok"
            bad=$((bad + 1))
          fi
          ;;
      esac
    done < <(printf '%s\n' "$line" | grep -oE 'flow-kit/[A-Za-z0-9_./-]+|§「[^」]*」' || true)
  done < <(grep -nE '^[[:space:]]*>?[[:space:]]*@see' "$file" || true)
  SEE_LINES=$((SEE_LINES + n))
  if [ "$bad" -gt 0 ]; then
    SEE_BAD=$((SEE_BAD + 1))   # 按锚行计坏行（一行可含多处红）
    ERRORS=$((ERRORS + bad))
    echo "     🔴 SEE: $skill 共 $bad 处锚不可解析（见上）"
  else
    echo "     ✅ @see 锚可解析（$n 锚行）"
  fi
}

# ── 单对校验：① 覆盖 + ② 不复制 + ③ @see（对 GOVERNED 与白名单映射统一走查）──
check_pair_skills_sync() {   # <skill|target>
  local entry="$1"
  local skill="${entry%%|*}" target="${entry##*|}"
  local skill_file="$BUNDLE_ROOT/skills/$skill/SKILL.md"
  local target_file="$BUNDLE_ROOT/$target"
  local tag=""
  if is_in_list "$skill" "${WHITELIST_PAIRS[@]%%|*}"; then tag="   [白名单映射 D5]"; fi

  echo "   校验: $skill ↔ $target${tag}"
  echo "     skill:  skills/$skill/SKILL.md"
  echo "     权威:   $target"

  # ① 覆盖三条件：skill 在 + 权威在 + @see 配对（任一缺 ⇒ 覆盖 miss，ERRORS++）
  local covered=1
  if [ ! -f "$skill_file" ]; then
    echo "     🔴 MISSING: skill 载体不存在（覆盖 miss）：skills/$skill/SKILL.md"
    ERRORS=$((ERRORS + 1)); covered=0
  fi
  if [ ! -f "$target_file" ]; then
    echo "     🔴 MISSING: 权威载体不存在（覆盖 miss）：$target"
    ERRORS=$((ERRORS + 1)); covered=0
  fi
  if [ "$covered" -eq 1 ]; then
    if grep -E '^[[:space:]]*>?[[:space:]]*@see' "$skill_file" | grep -qF -- "$target"; then
      echo "     ✅ 覆盖（SKILL.md 在 + 权威载体在 + @see 已配对）"
      COVERED=$((COVERED + 1))
    else
      echo "     🔴 NO-SEE: skills/$skill/SKILL.md 无 @see 锚行指向权威载体 $target（覆盖 miss）"
      ERRORS=$((ERRORS + 1)); covered=0
    fi
  else
    echo "     🔴 覆盖 miss（缺件，@see 配对未验 ⇒ 不计入覆盖）"
  fi

  # ② 不复制（D7）：归一化行集 comm -12 = 0；DUP_EXEMPT 显式豁免（见文件头）
  if [ -f "$skill_file" ] && [ -f "$target_file" ]; then
    if is_in_list "$skill" "${DUP_EXEMPT[@]}"; then
      echo "     ⚪ 不复制豁免（T12b 偏差①：部分骨架 · T12a 定稿 · 覆盖/@see 仍辖）"
      DUP_EXEMPTED=$((DUP_EXEMPTED + 1))
    else
      local dup_lines dup_count
      dup_lines=$(comm -12 <(normalize_line_set "$skill_file") <(normalize_line_set "$target_file"))
      DUP_CHECKED=$((DUP_CHECKED + 1))
      if [ -n "$dup_lines" ]; then
        dup_count=$(printf '%s\n' "$dup_lines" | grep -c . || true)
        echo "     🔴 DUP: $skill ↔ $target 归一化公共行 $dup_count ≠ 0（薄壳复制了权威正文）"
        printf '%s\n' "$dup_lines" | awk 'NR<=3 {print "       重复行: " $0}'
        ERRORS=$((ERRORS + 1))
      else
        echo "     ✅ 不复制（归一化公共行 0 · D7）"
        DUP_OK=$((DUP_OK + 1))
      fi
    fi
  fi

  # ③ @see 锚可解析（skill 文件在场即走查——缺权威时也能暴露其余锚的问题）
  if [ -f "$skill_file" ]; then
    check_see_anchors "$skill" "$skill_file"
  fi
  echo ""
}

# ── 计数器（汇总口径：覆盖 N/总辖、不复制 OK/实检、@see 锚行可解析 N/M）──
COVERED=0
DUP_CHECKED=0
DUP_OK=0
DUP_EXEMPTED=0
SEE_LINES=0
SEE_BAD=0
UNREGISTERED=0

# ── 主流程 ──
echo "🔍 check-skills-sync: 校验 skill 薄壳 ↔ prompt 权威载体同步（C13/AC-11）..."
echo ""

for entry in "${GOVERNED_PAIRS[@]}"; do
  check_pair_skills_sync "$entry"
done

echo "   ── 白名单映射（D5）──"
for entry in "${WHITELIST_PAIRS[@]}"; do
  check_pair_skills_sync "$entry"
done
echo ""

echo "   豁免登记: ${EXEMPT_SKILLS[*]}（安装文档型，无权威正文配对，不辖）；skills/flow 不匹配 flow-* glob，不辖"

# ── 覆盖率 fail-closed：skills/ 下 flow-* 目录未登记清单/白名单 ⇒ 未登记 ⇒ 红 ──
ALL_NAMES=()
for entry in "${GOVERNED_PAIRS[@]}" "${WHITELIST_PAIRS[@]}"; do
  ALL_NAMES+=("${entry%%|*}")
done
for dir in "$BUNDLE_ROOT"/skills/flow-*/; do
  [ -d "$dir" ] || continue
  name="${dir%/}"; name="${name##*/}"
  if ! is_in_list "$name" "${ALL_NAMES[@]}" && ! is_in_list "$name" "${EXEMPT_SKILLS[@]}"; then
    echo "   🔴 UNREGISTERED: skills/$name 匹配 flow-* 但未登记受辖清单/白名单（覆盖率不足，fail-closed）"
    ERRORS=$((ERRORS + 1))
    UNREGISTERED=$((UNREGISTERED + 1))
  fi
done

TOTAL_GOVERNED=$(( ${#GOVERNED_PAIRS[@]} + ${#WHITELIST_PAIRS[@]} ))
echo ""
echo "   ── 校验汇总 ──"
echo "   覆盖度: ${COVERED}/${TOTAL_GOVERNED}（阈值 100%；白名单映射 ${#WHITELIST_PAIRS[@]} · 清单外豁免 ${#EXEMPT_SKILLS[@]} · 未登记 ${UNREGISTERED}）"
echo "   不复制: ${DUP_OK}/${DUP_CHECKED} 对 comm=0（豁免 ${DUP_EXEMPTED} 对: ${DUP_EXEMPT[*]}）"
echo "   @see 锚: $((SEE_LINES - SEE_BAD))/${SEE_LINES} 锚行可解析"
if [ "$ERRORS" -gt 0 ]; then
  echo "   🔴 发现 $ERRORS 处问题（缺件/未配对/未登记/内容重复/锚不可解析）。请按 D2 权威载体原则修复：skill 只留薄壳 + @see。"
  exit 1
fi
echo "   ✅ skill 薄壳 ↔ prompt 权威载体同步校验通过（覆盖 ${COVERED}/${TOTAL_GOVERNED} · 不复制 ${DUP_OK}/${DUP_CHECKED} · @see 全可解析）"
exit 0
