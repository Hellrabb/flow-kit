# shellcheck shell=bash
# l3-section.sh — L3 段契约：结束标记 + 段删除（分拆自 l3-api.sh · 2026-09-18）
#
# 来源: L3-review-defects-2026-09-17 §B2 修复
# 背景: 原实现以「碰到下一个 '^## ' 二级标题」当 L3 段的结束条件，没有显式结束标记。
#       L3 载荷里一旦出现行首 '## '（模型返回多行 markdown 时很常见），截断点错位：
#       旧段尾（闭合围栏 / L3_artifact_hash / 载荷尾巴）残留下来，且逐轮累积，工件被静默污染。
# 现契约: 所有写入方在段尾落 `<!-- /L3-SECTION -->`；删除方按该标记精确切分。
#       历史工件没有标记 → 回落到原标题法（向后兼容）。
#
# 提供:
#   L3_SECTION_END_MARKER — 标记字面量（**唯一定义处**，改这里就等于改全部写入方）
#   _l3_l3_marker         — 取标记字面量（写入方用；未 source 本文件时内联兜底）
#   _l3_strip_sections    — 从 review 文件移除全部 L3 段（写入前去重用）
#
# 写入方（都必须落标记，否则删除侧只能走兼容路径）:
#   l3-api.sh::_l3_parse_result          — 正常 L3 审查段
#   l3-done.sh::l3_write_timeout_done    — 超时降级段
#   l3-done.sh::l3_write_bypass_done     — 熔断降级段
#
# 拆分为独立文件的原因：l3-api.sh 有 ≤250 行的结构门槛（test_lib_split_metrics.bats
# AC-B1/B3），本契约含注释约 60 行；l3-truncate.sh 余量也不足。单一职责另立文件更清晰。

# ── L3 段结束标记（跨文件契约 · §B2）──
L3_SECTION_END_MARKER='<!-- /L3-SECTION -->'

# ── _l3_l3_marker() · 取标记字面量 ──
# 输出: 标记字符串
# 说明: 写入方统一走本函数，避免把字面量散到多个文件；本文件被 source 时
#       ${L3_SECTION_END_MARKER} 已定义，内联兜底只服务于异常路径。
_l3_l3_marker() {
  printf '%s' "${L3_SECTION_END_MARKER:-<!-- /L3-SECTION -->}"
}

# ── _l3_strip_sections() · 移除既有 L3 段（B2 修复 · 显式结束标记）──
# 用法: _l3_strip_sections <review_md> <out_file>
# 返回: 0（即使源文件不存在也会产出空 out_file）
#
# 切分规则（按优先级）:
#   ① 段起点：`^## L3 (盲审|重审)` —— 与 _l3_check_rerun / l3-done.sh 的检测正则一致
#   ② 段终点：段内首个 `<!-- /L3-SECTION -->` 行（不因载荷里的行首 '## ' 提前放弃）
#      只有撞到「下一段 L3」或「回到 L2 段」才判定本段无标记 → 走 ③
#   ③ 无标记（历史工件）→ 原标题法：删到下一个 '^## ' 标题之前
#   ④ 一并回收紧邻上方的空行 + 单个 `---`，否则逐轮重写会累积空分隔条
#   ⑤ 多段：循环处理，文件中若残留多段 L3（并发写入等）一并清除
_l3_strip_sections() {
  local review_md="$1" out_file="$2"
  if [ ! -f "$review_md" ]; then
    : > "$out_file"
    return 0
  fi
  awk '
    { line[NR] = $0 }
    END {
      n = NR
      i = 1
      while (i <= n) {
        if (line[i] ~ /^## L3 (盲审|重审)/) {
          # 先在整段内找结束标记 —— 不因载荷里的行首 ## 提前放弃；
          # 只有撞到"下一段 L3 / 回到 L2 段"才判定本段无标记（历史工件）。
          stop = 0
          for (j = i + 1; j <= n; j++) {
            if (line[j] ~ /^<!-- \/L3-SECTION -->[[:space:]]*$/) { stop = j; break }
            if (line[j] ~ /^## L3 (盲审|重审)/) break
            if (line[j] ~ /^## L2 /) break
          }
          if (stop == 0) {
            # 无标记（历史工件）→ 原标题法：删到下一个二级标题之前
            stop = n
            for (j = i + 1; j <= n; j++) if (line[j] ~ /^## /) { stop = j - 1; break }
          }
          # 一并回收紧邻上方的分隔符（空行 + 单个 ---），否则逐轮重写会累积空 '---' 条；
          # 再吸收 start 上方的空行，否则每轮多留一个空行（写入方固定输出 "\n---\n\n"）。
          start = i
          k = i - 1
          while (k >= 1 && line[k] ~ /^[[:space:]]*$/) k--
          if (k >= 1 && line[k] ~ /^---[[:space:]]*$/) start = k
          while (start > 1 && line[start - 1] ~ /^[[:space:]]*$/) start--
          for (j = start; j <= stop; j++) del[j] = 1
          i = stop + 1
        } else {
          i++
        }
      }
      for (j = 1; j <= n; j++) if (!(j in del)) print line[j]
    }
  ' "$review_md" > "$out_file" 2>/dev/null || cp "$review_md" "$out_file" 2>/dev/null || : > "$out_file"
}
