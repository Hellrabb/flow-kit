# shellcheck shell=bash
# l3-section.sh — L3 段契约：结束标记 + 段删除（分拆自 l3-api.sh · 2026-09-18）
#
# 来源: L3-review-defects-2026-09-17 §B2 修复
# 背景: 原实现以「碰到下一个 '^## ' 二级标题」当 L3 段的结束条件，没有显式结束标记。
#       L3 载荷里一旦出现行首 '## '（模型返回多行 markdown 时很常见），截断点错位：
#       旧段尾（闭合围栏 / L3_artifact_hash / 载荷尾巴）残留下来，且逐轮累积，工件被静默污染。
# 现契约: 所有写入方在段尾落 `<!-- /L3-SECTION -->`；删除方按该标记精确切分。
#
# ── 载荷转义：段边界的**收敛点**（§B2/§B1 共同依赖 · 2026-09-18）────────────────
# 本 change 的段边界规则被模型载荷穿透了**三代**（每一代都由 L2 盲审在生产写入路径
# 上实测复现）：
#   G1 形态免疫  —— 只排除「引号开头的行」→ 载荷里一行非围栏 `Verdict:` 即穿透
#   G2 边界免疫  —— 改按「L3 段区间」排除 → 载荷里行首 `## ` 让区间提前收口
#   G3 双标题空洞 —— 改「取范围内最后一个标记」→ 载荷里 `## X` + 伪 `## L3 ` 造出空洞
# 结论：**任何「猜哪一行是真标题」的读侧启发式都能被载荷再次伪造**。唯一收敛解是让
# 不可信内容在结构上不可能伪造边界 —— 写入侧对载荷里行首的 `## ` 与标记字面量做转义
# （`_l3_escape_payload` 的 sed）。**代价须如实说明**：载荷位于 ```json 围栏内，
# 而 markdown 不在围栏内解释转义 —— 故 `\##` 对读者**可见**（不会渲染回 `##`）。
# 即落盘载荷与模型原文有一处可见差异；这是本 ADR 的实质代价，不是"零成本"。
# 另注：`**Verdict**:` **不在**转义集内（它是内容不是结构信号，且 L2 报告末尾就是它），
# 故"顺带让载荷里的 Verdict 行失效"这一说法**不成立**（设计期 L2 三审 R2 更正）。
# 读侧的区间规则（_l3_section_spans 取范围内**最后一个**标记）保留为纵深防御，
# 并负责历史工件（无标记）与转义前写入的旧文件的兼容。
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
# 载荷编码签名（M43 · 2026-09-18）：写侧落下本行表示「本文件含经 `_l3_escape_payload` 编码的载荷」；
# 读侧**只有见到签名才解码** —— 历史工件（未经编码）原样保留，避免被误吃一个反斜杠。
L3_PAYLOAD_ENCODED_MARK='<!-- L2-PAYLOAD-ENCODED -->'

# ── _l3_l3_marker() · 取标记字面量 ──
# 输出: 标记字符串
# 说明: 写入方统一走本函数，避免把字面量散到多个文件；本文件被 source 时
#       ${L3_SECTION_END_MARKER} 已定义，内联兜底只服务于异常路径。
_l3_l3_marker() {
  printf '%s' "${L3_SECTION_END_MARKER:-<!-- /L3-SECTION -->}"
}

# ── _l3_strip_sections() · 移除既有 L3 段（B2 修复 · 显式结束标记）──
# ── _l3_escape_payload() · 载荷转义（**唯一入口** · ADR-026）──
# 用法: _l3_escape_payload "<模型原文>"   → stdout（可直接 >> 工件）
#
# 把不可信载荷里**行首**的 `## `、结束标记字面量与围栏行（\`\`\`）前插一个反斜杠，
# 使其在结构上不可能伪造段边界**或破坏围栏配对**。
# **代价如实说明**：载荷位于 ```json 围栏内，而 markdown 不在围栏内解释转义 ——
# 故 `\##` 对读者**可见**（**不会**渲染回 `##`）。这是 ADR-026 的实质代价，不是零成本。
# 围栏为何也要转义（设计期 L2 盲审 R2）：`_l3_extract_prior_findings` 靠 ``` 切换 in_json，
# 载荷里一个多余的 ``` 会让围栏失同步，把其后的 L2 段误判为"仍在 JSON 内"→ 前轮发现提取退化；
# 同时会让工件的 markdown 渲染错乱。
#
# 为什么必须走这个函数而不是各处内联 sed（1-requirement/2-design 的 L2 盲审 R1）：
# 本项目有**两个**把模型原文写进 INDEPENDENT-REVIEW 的写入方 ——
#   ① l3-api.sh::_l3_parse_result（L3 载荷）
#   ② l2-detect.sh::l2_dispatch_agent（**L2 载荷**，PreToolUse 生产路径）
# 只转义 ① 时，② 的载荷里一行 `## L3 盲审（引用…）` 会被判为 L3 段起点，
# 随后 _l3_strip_sections 把该行到真标记之间的 **L2 报告正文一并切除** —— 静默数据损坏。
# 故转义是**契约**：凡把模型/外部内容写进工件的写入方都必须调用本函数。
# 回归守护：test_l3_review_defects_2026_09.bats 的 B2-R8（跨文件断言）。
_l3_escape_payload() {
  # 单射编码（M38 · 2026-09-18）：先给**行首反斜杠**加倍，再给结构性行首加一个反斜杠。
  # 为什么需要第一步：旧实现下"载荷原文本来就以 `\## ` 开头"与"写侧转义出的 `\## `"
  # 编码完全相同 → 读侧还原（去掉一个反斜杠）会把前者误改成 `## `（**改写审查员原文**）。
  # 加倍后两类可区分：`\## `=原文自带（还原回 `\## `）、`\## `=写侧转义（还原回 `## `）。
  printf '%s\n' "$1" | sed -E -e 's~^\\~\\\\~' -e 's~^(## |<!-- /L3-SECTION -->|```)~\\\1~'
}

# ── _l3_section_spans() · L3 段的行区间（**边界判定的唯一来源**）──
# 用法: _l3_section_spans <review_md>   → 每行输出 "<start> <end>"（1-based，含端点）
#
# 判定规则（_l3_strip_sections 与 l2-detect.sh::_fk_l2_scope 都消费本函数的输出，
# 保证"L3 段到哪结束"在**读侧与写侧只有一个判断**——避免同一契约两处不同实现，
# 见 1-requirement 的 L2 盲审 R1 与 L-031）：
#   ① 段起点：`^## L3 (盲审|重审)` **且上方最近非空行为 `---`**（写入方 preamble 契约 ·
#      设计期 L2 复审 N1）—— 三个写入方总是输出「空行 + --- + 空行 + 标题」，
#      语料实测全部满足（口径与数字以 `bash corpus-count.sh` 现算为准 —— 数字随语料
#      增长而漂移，写死快照会过期）；该判据挡掉**主 agent 贴入路径**里
#      引用的 `## L3 …` 句子（其上方通常没有 ---），否则那些正文会在 L3 写入时被切除
#   ② 段终点：段内**最后一个** `<!-- /L3-SECTION -->` 行（取首个会被载荷里的伪标记提前截断；
#      **不因载荷里的行首 '## ' 提前放弃**）
#   ③ 无标记（历史工件）→ 原标题法：到下一个 '^## ' 标题之前
#   ④ 多段：循环处理，残留多段一并给出
#   ⑤ **无兼容回退**（设计期 L2 复审 N1）：`---` preamble 自 HEAD 起就是三个写入方的
#      固定输出（`_l3_parse_result` / `l3_write_timeout_done` / `l3_write_bypass_done`
#      均为 `echo ""; echo "---"; echo ""`），语料现算 100% 满足（同口径）。加"零命中则放宽"的
#      回退会**正好在最需要判据时失效**——文件里没有真 L3 段时，贴入的伪标题就会被
#      回退路径认成真段（B2-R11 实测）。
_l3_section_spans() {
  local _spans
  _spans="$(_l3_spans_impl "$1" 1)"
  # 逐行输出（含行尾换行），与直接 awk print 的输出形态一致 —— 调用方用 $() 取值时
  # 行尾换行会被剥掉，但 `| wc -l` 这类直接消费需要它；空结果不输出任何字符。
  [ -n "$_spans" ] && printf '%s\n' "$_spans"
  return 0
}

# ── _l3_spans_impl <file> <require_sep> · 区间扫描实现（req=1 时启用 --- 判据）──
_l3_spans_impl() {
  awk -v req="${2:-0}" '
    # _sep_ok(i) — 行 i 上方最近非空行是否为 ---
    function _sep_ok(i,   k) {
      for (k = i - 1; k >= 1; k--) {
        if (line[k] ~ /^[[:space:]]*$/) continue
        return (line[k] ~ /^---[[:space:]]*$/) ? 1 : 0
      }
      return 0
    }
    { line[NR] = $0 }
    END {
      n = NR
      i = 1
      while (i <= n) {
        if (line[i] ~ /^## L3 (盲审|重审)/ && (req == 0 || _sep_ok(i))) {
          # 段终点 = 「本段起」到「下一个**满足起点判据的** L3 标题（或 EOF）」之间
          # **最后一个**标记行。
          #
          # 为什么不是「第一个」（1-requirement 的 L2 三审 R1，case 6）：
          # 模型载荷里可能原样出现标记字面量（phase 7 的 prompt 会注入前轮发现，
          # 从而把上一轮的标记回灌给模型）。取第一个会被载荷里的伪标记提前截断，
          # 其后正文（含行首 Verdict）漏出段外。取最后一个天然免疫该伪造。
          #
          # 为什么不在中途因 `^## L2 ` / `^## L3 ` 提前 break（同 R1 的 case 4/5）：
          # 这两类判定都会被**载荷内容**伪造（模型写 `## L2 结论复核` 是常见形态），
          # 提前收口同样造成泄漏。现在只在「下一个真实 L3 标题」处收拢扫描范围。
          stop = 0
          for (j = i + 1; j <= n; j++) {
            if (line[j] ~ /^<!-- \/L3-SECTION -->[[:space:]]*$/) { stop = j; continue }
            if (line[j] ~ /^## L3 (盲审|重审)/ && (req == 0 || _sep_ok(j))) break
          }
          if (stop == 0) {
            # 范围内零标记（历史工件）→ 终点收紧为「下一个**已知区段**标题」：L2 / 主 agent / L3，
            # 或 EOF。**不再**用「下一个二级标题」（2026-09-18 依设计期 L2 第八轮 critical ②）：
            # 载荷里一行 `## 附录：发现明细` 就会把段尾切在它之前，其后的 `**Verdict**: pass`
            # 漏进 L2 层 —— 正是 §B1 那族「L3 内容冒充 L2」在历史件上的复活形态。
            # 语料实测（224 份 / 128 个无标记段）：终点会因此改变的实例仅 1 个
            # （.specs/archive/l2-l3-fix-compliance/INDEPENDENT-REVIEW-6.md，其后是
            # `## 独立审查报告（盲审）`），且归档目录不参与 L3 重写。
            stop = n
            for (j = i + 1; j <= n; j++) if (line[j] ~ /^## (L2 |主 agent|L3 )/) { stop = j - 1; break }
          }
          print i " " stop
          i = stop + 1
        } else {
          i++
        }
      }
    }
  ' "$1" 2>/dev/null
}

# ── _l3_has_section() · 工件是否含**可识别**的 L3 段（判据与 _l3_section_spans 同源）──
# 用法: _l3_has_section <review_md>   → 0=有, 1=无
#
# 为什么要有这个包装（设计期 L2 三审 R6）：本 change 之前，三个调用点各自用裸正则
# `^## L3 (盲审|重审)` 判断"L3 段存在"（l3-truncate.sh / l3-api.sh / l3-done.sh）。
# 段起点判据收紧为「+ 上方最近非空行为 ---」之后，裸正则会与 _l3_section_spans 结论相反
# （贴入的伪标题：裸正则说有、spans 说没有）→ 同一契约两处不同实现（L-031）。
# 现统一走本函数。
_l3_has_section() {
  [ -n "$(_l3_section_spans "$1")" ]
}

# ── _l3_strip_sections() · 从工件中移除全部 L3 段 ──
# 用法: _l3_strip_sections <review_md> <out_file>
# 返回: 0（即使源文件不存在也会产出空 out_file）
#
# 边界判定委托 _l3_section_spans()（单一来源）。本函数只负责：
#   ④ 一并回收紧邻上方的空行 + 单个 `---`，否则逐轮重写会累积空分隔条
# ── _l3_verify_review_structure() · 评审文件结构自检（M37 的「写入后校验」半 · 2026-09-18）──
# 用法: _l3_verify_review_structure <review_md>   → 0=正常；1=异常（诊断到 stderr）
#
# 为什么需要：PreToolUse 只能拦**工具调用**；`Bash` 重定向、外部进程、编辑器直写等通道都能绕过，
# 而"写坏"的后果是**静默**的（段尾缺失 → 后续写入把正文删掉）。故在 Stop 侧对**最终文件**做
# 结构自检，与写入通道无关：① L3 段数 ≤1；② 段尾必须正好是结束标记；③ 段内围栏配平；
# ④ 转义行首与编码签名的一致性 —— **advisory only**（不改判定，见函数内说明）。
# 非阻塞：只告警（评审文件是审计凭证，损坏时应当可见，但不该阻断整条 pipeline）。
_l3_verify_review_structure() {
  local review_md="${1:-}"
  [ -f "$review_md" ] || return 0
  local spans n start end last fences issues=""
  spans="$(_l3_section_spans "$review_md")"
  n=$(printf '%s\n' "$spans" | grep -c . 2>/dev/null || true)
  [ -n "$n" ] || n=0
  [ "$n" -le 1 ] || issues+="L3 段数=${n}（应 ≤1）；"
  if [ "$n" -eq 1 ]; then
    start=$(printf '%s\n' "$spans" | head -1 | cut -d' ' -f1)
    end=$(printf '%s\n' "$spans" | head -1 | cut -d' ' -f2)
    last=$(sed -n "${end}p" "$review_md" 2>/dev/null || true)
    case "$last" in
      *"$L3_SECTION_END_MARKER"*) ;;
      *) issues+="段尾（第 ${end} 行）不是结束标记；" ;;
    esac
    fences=$(sed -n "${start},${end}p" "$review_md" 2>/dev/null | grep -c '^```' 2>/dev/null || true)
    [ -n "$fences" ] || fences=0
    [ $(( fences % 2 )) -eq 0 ] || issues+="L3 段内围栏不配平（${fences} 条）；"
  fi
  # ④ 有转义块却缺编码签名（M47 · 阶段 2 的 L3 21:59 critical③）：门控解码只在含签名的文件上生效，
  #    缺签名时转义不会被还原 —— 正文会带多余反斜杠（静默不一致，且读侧内容级消费者看不到原样）。
  # ④ 有转义块却缺编码签名 → **advisory**（不改判定）：转义行首在本项目是**常规写法**
  #    （响应段用 `\## L2 盲审（N审）` 引用标题，渲染成标题但不构成段 —— 语料实测 5 行）。
  #    这类"看起来像转义"的行并不都是载荷编码产物，故只提示、不让 `_l3_write_done` 拒绝发凭证。
  local esc sig
  esc=$(grep -cE '^\\(## |<!-- /L3-SECTION -->|```)' "$review_md" 2>/dev/null || true); esc=${esc:-0}
  if [ "$esc" -gt 0 ]; then
    sig=$(grep -cF "${L3_PAYLOAD_ENCODED_MARK:-<!-- L2-PAYLOAD-ENCODED -->}" "$review_md" 2>/dev/null || true); sig=${sig:-0}
    [ "$sig" -gt 0 ] || echo "[l3-section] NOTE: ${review_md} 含 ${esc} 行转义行首但无编码签名（若为载荷编码产物则不会被还原；常规标题引用可忽略）" >&2
  fi

  if [ -n "$issues" ]; then
    echo "[l3-section] WARNING: 评审文件结构自检未通过 — ${review_md}: ${issues}（可能由未转义贴入或外部通道写入造成；见 ADR-026）" >&2
    return 1
  fi
  return 0
}

_l3_strip_sections() {
  local review_md="$1" out_file="$2"
  if [ ! -f "$review_md" ]; then
    : > "$out_file"
    return 0
  fi
  local spans
  spans="$(_l3_section_spans "$review_md")"
  awk -v spans="$spans" '
    BEGIN {
      if (spans != "") {
        cnt = split(spans, arr, "\n")
        for (i = 1; i <= cnt; i++) {
          split(arr[i], p, " ")
          for (j = p[1]; j <= p[2]; j++) del[j] = 1
        }
      }
    }
    { line[NR] = $0 }
    END {
      # 回收紧邻段上方的空行 + 单个 ---（否则逐轮重写累积空 '---' 条 / 空行）
      for (i = 1; i <= NR; i++) {
        if (!(i in del)) continue
        if (i - 1 in del) continue
        s = i
        k = i - 1
        while (k >= 1 && line[k] ~ /^[[:space:]]*$/) k--
        if (k >= 1 && line[k] ~ /^---[[:space:]]*$/) s = k
        while (s > 1 && line[s - 1] ~ /^[[:space:]]*$/) s--
        for (j = s; j < i; j++) del[j] = 1
      }
      for (j = 1; j <= NR; j++) if (!(j in del)) print line[j]
    }
  ' "$review_md" > "$out_file" 2>/dev/null || cp "$review_md" "$out_file" 2>/dev/null || : > "$out_file"
}
