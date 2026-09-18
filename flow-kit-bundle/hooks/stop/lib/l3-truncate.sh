# shellcheck shell=bash
# l3-truncate.sh — L3 重审检测/跳过逻辑（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 函数:
#   _l3_check_rerun — 重审检测（hash 标记 + ## L3 段检测）

# 依赖注入：l3-section.sh（_l3_has_section · 段边界判定单一来源）
# l3-review.sh 的 source 顺序是 truncate → section，故运行时可用；此处兜底独立 source 场景。
type _l3_has_section >/dev/null 2>&1 || {
  _L3T_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
  [ -n "${_L3T_DIR:-}" ] && [ -f "${_L3T_DIR}/l3-section.sh" ] && source "${_L3T_DIR}/l3-section.sh"
  unset _L3T_DIR
}

# ── _l3_check_rerun() · 重审检测：比较工件 hash 与记录 hash ──
# 用法: _l3_check_rerun <phase> <artifacts_dir>
# 返回: 0=需重审(工件更新或首次), 2=跳过(工件未变)
_l3_check_rerun() {
  local phase="$1" artifacts_dir="$2"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  [ -f "$review_md" ] || return 0  # 无现有审查 → 首次运行

  # ADR-010 D4·J：判定基从 mtime 改内容标记（## L3 段 regex + artifact hash）。
  # 判定优先级：hash 变→重审 / L3 段不存在或为空→重审 / hash 提取失败→重审+警告 / 否则 skip。
  # ① L3 段检测：走 _l3_has_section（= _l3_section_spans 非空），判据与写侧同源；
  #    注：裸正则 ^## L3 (盲审|重审) 已废弃 —— 段起点判据收紧为「+ 上方最近非空行为 ---」后，
  #    裸正则会与 spans 结论相反（贴入的伪标题：裸正则有、spans 无）。与 _l3_parse_result 的
  #    section_title 仍保持一致（写入方总是带 --- preamble）。
  # 判据与 _l3_section_spans 同源（设计期 L2 三审 R6）：裸正则会把贴入的伪标题当真段
  if ! _l3_has_section "$review_md"; then
    echo "[l3-review] re-review triggered for phase ${phase} (## L3 段缺失或空)" >&2
    return 0
  fi

  # ② artifact hash：INDEPENDENT-REVIEW-N.md 末尾 L3_artifact_hash 元数据行（_l3_parse_result 审后写入）
  local recorded_hash
  recorded_hash=$(grep -E '^L3_artifact_hash:' "$review_md" 2>/dev/null | tail -1 | awk '{print $2}')
  if [ -z "$recorded_hash" ]; then
    echo "[l3-review] re-review triggered for phase ${phase} (L3_artifact_hash 缺失或提取失败 · 保守重审)" >&2
    return 0
  fi

  # ③ 当前 artifact sha（按 phase 取工件）
  local artifact_file=""
  case "$phase" in
    1) artifact_file="${artifacts_dir}/REQUIREMENT.md" ;;
    2) artifact_file="${artifacts_dir}/DESIGN.md" ;;
    3) artifact_file="${artifacts_dir}/TASK.md" ;;
    5) artifact_file="${artifacts_dir}/TEST.md" ;;
    6|7) artifact_file="${artifacts_dir}/REVIEW.md" ;;
  esac
  local current_hash=""
  [ -n "$artifact_file" ] && [ -f "$artifact_file" ] && current_hash=$(sha256sum "$artifact_file" 2>/dev/null | awk '{print $1}')

  # ④ 判定：当前 sha ≠ 记录 hash → 重审；否则 skip（touch 不触发，hash 捕内容变更）
  if [ "$current_hash" != "$recorded_hash" ]; then
    echo "[l3-review] re-review triggered for phase ${phase} (artifact hash 变更: ${recorded_hash:0:12} → ${current_hash:0:12})" >&2
    return 0
  fi
  echo "[l3-review] skipping L3 for phase ${phase} (artifact hash 不变 + ## L3 段非空)" >&2
  return 2
}

# ─── smart_truncate (moved from l3-api.sh · td072-lib-split-2026-08) ───
smart_truncate() {
  local text="$1"
  local max_chars="${2:-20000}"
  local original_size=${#text}

  # 不需要截断
  if [ "$original_size" -le "$max_chars" ]; then
    echo "$text"
    echo ""
    echo "[截断] 原始: ${original_size} chars，未超限（上限 ${max_chars} chars），完整保留"
    return 0
  fi

  # 第 1 遍: 索引收集 (header_line_numbers + AC line_numbers)
  local header_nums=""   # 仅行号，换行分隔
  local ac_nums=""       # 仅行号，换行分隔

  local lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    # 捕获 ##/### 标题行 → 仅存行号
    if [[ "$line" =~ ^###?\  ]]; then
      header_nums="${header_nums}${lineno}"$'\n'
    fi
    # 捕获 Given/When/Then AC 行 → 仅存行号
    if [[ "$line" =~ ^\*\*Given\*\*|^\*\*When\*\*|^\*\*Then\*\* ]]; then
      ac_nums="${ac_nums}${lineno}"$'\n'
    fi
  done <<< "$text"

  # 构建强制保留行号集合（仅数字键）
  declare -A keep_line
  while IFS= read -r num; do
    [ -n "$num" ] && keep_line["$num"]=1
  done <<< "$header_nums"
  while IFS= read -r num; do
    [ -n "$num" ] && keep_line["$num"]=1
  done <<< "$ac_nums"

  # 第 2 遍: 按标题段填充
  local output=""
  local remaining=$max_chars
  local removed_sections=""
  local current_section=""
  local in_section=0

  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    local is_header=0
    local line_len=${#line}

    if [[ "$line" =~ ^###?\  ]]; then
      is_header=1
      # R2 fix: always output header line even if remaining exhausted
      # (AC-2 hard constraint (a): all headers must be preserved)
      if [ "$in_section" -eq 1 ] && [ -n "$current_section" ] && [ "$remaining" -le 0 ]; then
        removed_sections="${removed_sections}${current_section}, "
      fi
      current_section=$(echo "$line" | sed 's/^#\+ //' | cut -c1-60)
      in_section=1
    fi

    # R2 fix: headers always output regardless of remaining budget
    if [ "$is_header" -eq 1 ]; then
      output="${output}${line}"$'\n'
      remaining=$((remaining - line_len - 1))
      continue
    fi

    if [ "$remaining" -le 0 ]; then
      continue
    fi

    # 强制保留: AC 行 (R3 fix: keep_line key is now numeric, matching $lineno)
    if [ "${keep_line[$lineno]:-0}" -eq 1 ]; then
      if [ "$line_len" -le "$remaining" ]; then
        output="${output}${line}"$'\n'
        remaining=$((remaining - line_len - 1))
      else
        output="${output}${line:0:$remaining}"$'\n'
        remaining=0
      fi
    elif [ "$in_section" -eq 1 ]; then
      # 标题段内的普通行，按剩余空间填充
      if [ "$line_len" -le "$remaining" ]; then
        output="${output}${line}"$'\n'
        remaining=$((remaining - line_len - 1))
      fi
    fi
  done <<< "$text"

  # 第 3 遍: 尾部锚点扫描（l3-pipeline-fix-2026-07 D2）
  # 从文件末尾向前扫描，匹配尾部关键段 header（风险/ADR/决策），确保不因头部填充被丢弃
  local tail_output=""
  local tail_matched=0
  local tail_anchors='## 5\. 风险|## 风险|ADR-|已锁决策|\| # \| 风险'
  local tail_lines=() line_rev
  mapfile -t tail_lines <<< "$text"
  local tail_total=${#tail_lines[@]}
  local tail_idx=$((tail_total - 1))
  local in_tail_section=0
  while [ "$tail_idx" -ge 0 ]; do
    line_rev="${tail_lines[$tail_idx]}"
    if [[ "$line_rev" =~ ^###?\  ]]; then
      if [[ "$line_rev" =~ $tail_anchors ]]; then
        in_tail_section=1
        tail_matched=$((tail_matched + 1))
      elif [ "$in_tail_section" -eq 1 ]; then
        break  # 遇到非锚点标题，尾部段结束
      fi
    fi
    if [ "$in_tail_section" -eq 1 ]; then
      tail_output="${line_rev}"$'\n'"${tail_output}"
    fi
    tail_idx=$((tail_idx - 1))
  done

  if [ "$tail_matched" -gt 0 ]; then
    output="${output}"$'\n'"${tail_output}"
    meta_tail="[尾部保留: ${tail_matched} 段锚点匹配]"
  else
    # fallback: 未匹配到任何锚点 → 保留最后 max_chars/4 字符
    local tail_fallback_chars=$((max_chars / 4))
    local tail_fallback="${text: -${tail_fallback_chars}}"
    output="${output}"$'\n'"${tail_fallback}"
    meta_tail="[尾部保留: 0 段锚点匹配，已回退到通用保留（最后 ${tail_fallback_chars} chars）]"
  fi

  # 构造截断元信息
  local truncated_size=${#output}
  local meta="[截断] 原始: ${original_size} chars → 截断后: ${truncated_size} chars（上限 ${max_chars}）"
  if [ -n "$removed_sections" ]; then
    removed_sections="${removed_sections%, }"
    meta="${meta} | 被截去的章节: ${removed_sections}"
  else
    meta="${meta} | 所有章节已保留（内容被压缩）"
  fi
  meta="${meta} | ${meta_tail}"
  meta="${meta}"$'\n'"[提示] 以上为截断摘要，信息不完整。请优先标记确定性问题，减少不确定环境下的武断 critical。"

  echo "$output"
  echo ""
  echo "$meta"
  return 0
}
