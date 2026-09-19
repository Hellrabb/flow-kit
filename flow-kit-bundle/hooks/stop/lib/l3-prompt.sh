# shellcheck shell=bash
# l3-prompt.sh — L3 审查 prompt 构造 + 格式化（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 函数:
#   _l3_format_result   — L3 反馈统一格式化
#   _l3_inject_context  — Step 0: 前次审查上下文注入
#   _l3_build_prompt    — Step 1: 按阶段收集工件 + 构造审查 prompt

# ── _l3_format_result() · L3 反馈统一格式化 ──
# 用法: _l3_format_result <verdict> <summary> <report_relative_path>
# 输出: 单行 L3_RESULT: 格式，供 F1(PreToolUse stdout) 和 F2(SessionStart banner) 共用
_l3_format_result() {
  local verdict="$1" summary="$2" report="$3"
  # 值域校验：仅允许已知 verdict 值，非法值降级为 unknown
  case "$verdict" in pass|fail|timeout|error) ;; *) verdict="unknown" ;; esac
  echo "L3_RESULT: verdict=${verdict} summary=${summary} report=${report}"
}

# ── _l3_utf8_head_bytes() · D7 字节 cap + UTF-8 边界回退（文件形 · l3-prompt-loop-fix）──
# 用法: _l3_utf8_head_bytes <max_bytes> <file>
# 输出: 文件前 max_bytes 字节内、末尾不落在 UTF-8 多字节序列中间的内容
#       文件不存在/空 → 静默（空输出，exit 0）
_l3_utf8_head_bytes() {
  local max_bytes="$1" file="$2"
  [ -f "$file" ] || return 0
  head -c "$max_bytes" "$file" | _l3_utf8_head_stream "$max_bytes"
}

# ── _l3_utf8_head_stream() · D7 字节 cap + UTF-8 边界回退（stdin 流形 · l3-prompt-loop-fix）──
# 用法: <stream> | _l3_utf8_head_stream <max_bytes>
# 尾部落在多字节序列中间时回退 ≤5 字节至上一完整字符边界（od 字节级检查续字节 0x80-0xBF）
_l3_utf8_head_stream() {
  local max_bytes="$1"
  local LC_ALL=C
  local data len i back=0 b lead expect
  data=$(head -c "$max_bytes" 2>/dev/null; echo _U8S_)
  data=${data%_U8S_}
  len=${#data}
  [ "$len" -gt 0 ] || return 0
  # 扫描尾部连续续字节（10xxxxxx = 0x80-0xBF，窗口 ≤5）
  for ((i = len - 1; i >= 0 && i >= len - 5; i--)); do
    b=$(printf '%s' "${data:i:1}" | od -An -tu1 | tr -d ' \n')
    [ "$b" -ge 128 ] && [ "$b" -le 191 ] || break
    back=$((back + 1))
  done
  # back=0 且尾字节本身是 lead（194-244）→ 其续字节被截，必不完整 → 回退 1
  if [ "$back" -eq 0 ]; then
    b=$(printf '%s' "${data:len-1:1}" | od -An -tu1 | tr -d ' \n')
    if [ "$b" -ge 194 ] && [ "$b" -le 244 ]; then
      data="${data:0:len-1}"
      printf '%s' "$data"
      return 0
    fi
    printf '%s' "$data"
    return 0
  fi
  # 续字节序列前一字节判定 lead 字节与期望序列长度
  i=$((len - back - 1))
  if [ "$i" -ge 0 ]; then
    lead=$(printf '%s' "${data:i:1}" | od -An -tu1 | tr -d ' \n')
    expect=0
    [ "$lead" -ge 194 ] && [ "$lead" -le 223 ] && expect=2
    [ "$lead" -ge 224 ] && [ "$lead" -le 239 ] && expect=3
    [ "$lead" -ge 240 ] && [ "$lead" -le 244 ] && expect=4
    if [ "$expect" -gt 0 ]; then
      if [ "$back" -lt "$((expect - 1))" ]; then
        back=$((back + 1))     # lead 本身被截 → 连 lead 一起回退
      else
        back=0                 # 序列完整（back == expect-1）→ 无需回退
      fi
    fi
    # expect=0：孤立续字节（lead 非法/ASCII）→ 维持 back 丢弃孤立续字节
  fi
  if [ "$back" -gt 0 ]; then
    [ "$back" -le "$len" ] && data="${data:0:len-back}"
  fi
  printf '%s' "$data"
}

# ── _l3_extract_prior_findings() · D2/D3 前轮发现提取（l3-prompt-loop-fix）──
# 用法: _l3_extract_prior_findings <review_md>
# 输出: severity|file|摘要 单行集（critical > major；同 severity L3 先于 L2；
#       每行 ≤200B 超长截断加 …；摘要内 | 替换为 /）
#       文件不存在 / 两类提取源皆空 → 空输出 exit 0；minor 不提取
_l3_extract_prior_findings() {
  local review_md="$1"
  local LC_ALL=C
  [ -f "$review_md" ] || return 0
  local nl=$'\n'
  local section="" line file
  local out_l3="" out_l2=""
  local in_json=0 json_buf=""
  local red_e moon_e
  red_e=$(printf '\xf0\x9f\x94\xb4')   # 🔴 lead bytes
  moon_e=$(printf '\xf0\x9f\x9f\xa1')  # 🟡 lead bytes
  local pend_sev="" pend_summ=""
  while IFS= read -r line || [ -n "$line" ]; do
    # §B2：载荷围栏内的行首 '## ' 不是标题语义 —— 若在此切段，L3 的 JSON 缓冲会被腰斩，
    # 前轮发现随之丢失。故仅在非围栏行上做段切换判定。
    if [ "$in_json" -eq 0 ]; then
      case "$line" in
        '## L2'*) section="L2" ;;
        '## L3'*) section="L3" ;;
        '## '*) section="other" ;;
      esac
    fi
    if [ "$section" = "L3" ]; then
      case "$line" in
        '```'*)
          if [ "$in_json" -eq 1 ]; then
            in_json=0
            out_l3+=$(printf '%s' "$json_buf" | jq -r '
              (.critical[]? | "critical|\(.file // "?" | gsub("\\|"; "/"))|\((.issue // "") | split("。")[0] | gsub("\\|"; "/"))"),
              (.major[]?   | "major|\(.file // "?" | gsub("\\|"; "/"))|\((.issue // "") | split("。")[0] | gsub("\\|"; "/"))")
            ' 2>/dev/null)"$nl"
            json_buf=""
          else
            in_json=1
          fi
          ;;
        *) [ "$in_json" -eq 1 ] && json_buf+="$line"$'\n' ;;
      esac
      continue
    fi
    if [ "$section" = "L2" ]; then
      case "$line" in
        "### ${red_e}"*)
          pend_sev="critical"
          pend_summ=${line#"### ${red_e}"}
          pend_summ=${pend_summ#*：}
          pend_summ=${pend_summ//'|'/'/'}
          ;;
        "### ${moon_e}"*)
          pend_sev="major"
          pend_summ=${line#"### ${moon_e}"}
          pend_summ=${pend_summ#*：}
          pend_summ=${pend_summ//'|'/'/'}
          ;;
        '**Symptom（症状）**：'*)
          if [ -n "$pend_sev" ]; then
            file=${line#'**Symptom（症状）**：'}
            file=${file%%[[:space:]]*}
            file=${file//'|'/'/'}
            out_l2+="${pend_sev}|${file}|${pend_summ}"$'\n'
            pend_sev=""
          fi
          ;;
      esac
    fi
  # 读侧消费者 #2（阶段 2 的 L3 23:46 major③）：本函数**直接消费原始文本**（不做还原）。
  # 为什么可以：它的键控是 ```` ```json ```` 围栏 + `"critical"` 等 JSON 键，而转义只作用于
  # **行首**的结构信号；被转义的围栏行会退化为普通行，最坏情况是该段 JSON 不被识别（**少提取**
  # 前轮发现，而非错提取）。补还原会改变 `_l3_inject_context` 的配额语料（实测使
  # `test_l3_pipeline_fix.bats` 的 T03/T05fix 两组配额断言失败），收益/风险不成比例 → 登记 M49。
  done < "$review_md"
  local l trimmed final=""
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    if [ "${#l}" -gt 200 ]; then
      # L2 R1（INDEPENDENT-REVIEW-6）：字节切片可切在多字节字符中间产非法 UTF-8，
      # 复用 D7 流形 helper 做边界回退（仅超长行走此路径，非热路径）
      trimmed="$(printf '%s' "$l" | _l3_utf8_head_stream 197)…"
    else
      trimmed="$l"
    fi
    final+="${trimmed}"$'\n'
  done <<EOF
$(printf '%s' "$out_l3" | grep '^critical|' 2>/dev/null)
$(printf '%s' "$out_l2" | grep '^critical|' 2>/dev/null)
$(printf '%s' "$out_l3" | grep '^major|' 2>/dev/null)
$(printf '%s' "$out_l2" | grep '^major|' 2>/dev/null)
EOF
  printf '%s' "$final"
}
# 用法: _l3_inject_context <phase> <artifacts_dir>
# 输出: context_preamble 到 stdout（四象限注入矩阵 · l3-prompt-loop-fix D2/D3/D4）
#   findings+响应 → verdict + 摘要(≤600B) + 响应要点(≤200B)
#   findings+未响应 → verdict + 摘要 + 未响应标注
#   无 findings+响应 → verdict + 响应要点
#   仅 verdict 可解析 → verdict 行
#   文件缺失/空 或 三者皆无 → 静默
_l3_inject_context() {
  local phase="$1" artifacts_dir="$2"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  [ -s "$review_md" ] || return 0
  local LC_ALL=C

  local l2_verdict l3_verdict
  l2_verdict=$(grep -m1 '^\*\*Verdict\*\*: ' "$review_md" 2>/dev/null || true)
  l3_verdict=$(grep -A1 '"verdict"' "$review_md" 2>/dev/null | grep -o '"verdict":"[^"]*"' | tail -1 | tr -d '"' || true)

  # D4 三锚响应检测：段头 / 反驳段 / 行内分类标记（不锚行首——实测 `- **R1** — Fixed in:`）
  local has_response=0
  if grep -q '^## 主 agent 响应' "$review_md" 2>/dev/null \
    || grep -q '主 agent 反驳：' "$review_md" 2>/dev/null \
    || grep -qE '(Fixed in|Tech-debt|Not-applicable):' "$review_md" 2>/dev/null; then
    has_response=1
  fi

  # D2/D3 前轮发现单行摘要（600B 配额 + (+k more) 折叠）
  local findings quota_out="" total=0 included=0 section_bytes=0 line lb
  findings=$(_l3_extract_prior_findings "$review_md")
  if [ -n "$findings" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && total=$((total + 1))
    done <<EOF
$findings
EOF
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      lb=$(printf '%s' "$line" | wc -c)
      [ $((section_bytes + lb)) -gt 600 ] && break
      quota_out+="${line}"$'\n'
      section_bytes=$((section_bytes + lb))
      included=$((included + 1))
    done <<EOF
$findings
EOF
  fi

  # 响应要点（行内分类标记行，≤200B，"；" 连接）
  local resp="" resp_bytes=0 rl rlb
  while IFS= read -r rl; do
    [ -z "$rl" ] && continue
    rlb=$(printf '%s' "$rl" | wc -c)
    [ $((resp_bytes + rlb + 3)) -gt 200 ] && break
    [ -n "$resp" ] && resp+='；'
    resp+="$rl"
    resp_bytes=$((resp_bytes + rlb))
  done < <(grep -E '(Fixed in|Tech-debt|Not-applicable):' "$review_md" 2>/dev/null | head -8)

  # 三者皆无 → 无可注入
  [ -z "$l2_verdict$l3_verdict$quota_out$resp" ] && return 0

  local nl=$'\n'
  local out=""
  out+="[前次审查上下文 · 最近一次]"$nl
  [ -n "$l2_verdict" ] && out+="- ${l2_verdict}"$nl
  [ -n "$l3_verdict" ] && out+="- L3 ${l3_verdict}"$nl
  if [ -n "$quota_out" ]; then
    out+="前轮发现摘要："$nl
    out+="$quota_out"
    [ "$included" -lt "$total" ] && out+="(+$((total - included)) more)"$nl
  fi
  if [ -n "$resp" ]; then
    out+="主 agent 响应要点：${resp}"$nl
  elif [ -n "$quota_out" ] && [ "$has_response" -eq 0 ]; then
    out+="主 agent 未响应前次发现（本次请独立复核是否仍成立）"$nl
  fi
  out+="[注意：以上为历史审查上下文，本次审查仍应基于工件本身独立判断]"$nl
  printf '%s' "$out"
}

# ── _l3_emit_prompt() · 截断可见化（用户 2026-09-18 指出的盲区）──
# 由来：阶段 2 实测 cap=20000 而完整 prompt 37005 B → **丢弃 45%**，DESIGN.md 尾部
# （§9.5 等）从未送达 L3，而 L3 的 verdict 看起来完全正常 —— 这是 §B3 同族故障在
# "审查输入"侧的复发：**静默截断**。
# 现策略：发生截断时向 stderr 告警（原始/实际字节数 + 丢弃比例），让"L3 只看到一半"
# 在日志里可见。调用方无需改动。
_l3_emit_prompt() {
  local full="$1" max_bytes="$2" out flen olen
  out=$(printf '%s' "$full" | _l3_utf8_head_stream "$max_bytes")
  flen=$(printf '%s' "$full" | wc -c)
  olen=$(printf '%s' "$out" | wc -c)
  if [ "$flen" -gt "$olen" ]; then
    echo "[l3-review] WARNING: 提示词被截断 — 完整 ${flen}B，本次仅发送 ${olen}B（丢弃 $(( (flen - olen) * 100 / flen ))%）。L3 的结论基于**部分**工件；请提高 independent_review.max_artifact_bytes（当前 ${max_bytes}）后重审。" >&2
  fi
  printf '%s' "$out"
}

# ── _l3_extra_deliverables() · 必备 6 件之外的 *.md 交付物正文（M34 · 2026-09-18）──
# 用法: _l3_extra_deliverables <artifacts_dir>   → 输出 "\n\n=== <名> ===\n<正文>" 序列
#
# 为什么要有它：旧实现对补充产物用**硬编码白名单**（INTEGRATION.md / UAT.md /
# MINOR-DEFERRED.md）。白名单漏掉了 AC-2 的交付物 `L2-EMPTY-ATTRIBUTION.md`，
# 于是 L3 如实报「工件中未提供该清单的实际内容」——对提示词为真、对仓库为假，
# 与 §B4 的 `head -30` 截断同源：**审查者只能看到我们喂进去的东西**。
# 现改为目录内全量 *.md（排除 6 件必备与 INDEPENDENT-REVIEW-*.md）。
#
# 排序：按体积升序。具体 AC 交付物多是小文件，MINOR-DEFERRED.md 这类大而次要的垫尾，
# 使调用方的 $max_bytes 尾部截断只可能切到「最不具体」的部分。
_l3_extra_deliverables() {
  local artifacts_dir="$1" _f _b
  {
    for _f in "$artifacts_dir"/*.md; do
      [ -f "$_f" ] || continue
      _b=${_f##*/}
      case "$_b" in
        CHANGE.md|REQUIREMENT.md|DESIGN.md|TASK.md|TEST.md|REVIEW.md) continue ;;
        INDEPENDENT-REVIEW-*.md) continue ;;
      esac
      # 可移植体积：GNU `stat -c%s` → BSD/macOS `stat -f%z` → 兜底 `wc -c`（M50）
      printf '%s\t%s\n' "$(stat -c%s "$_f" 2>/dev/null || stat -f%z "$_f" 2>/dev/null || wc -c < "$_f" 2>/dev/null || echo 0)" "$_b"
    done | sort -n -k1,1 -k2,2 | cut -f2
  } | while IFS= read -r _b; do
    [ -n "$_b" ] || continue
    local _sz _head
    # 可移植体积（评审 06:0x major：`stat -c%s` 是 GNU 专属，BSD/macOS 失败会静默回退 0）
    _sz=$(wc -c < "${artifacts_dir}/${_b}" 2>/dev/null || echo 0); _sz=${_sz// /}
    _head=$(_l3_utf8_head_bytes 3000 "${artifacts_dir}/${_b}" 2>/dev/null || true)
    if [ "${_sz:-0}" -gt 3000 ]; then
      # ① **整行**截断：不要把一个命令切一半（评审 05:56 critical：截断处被读成"工件命令不完整"）
      # `sed '$d'` 无条件丢掉最后一行（可能是半行）—— 比 `${_head%$'\n'*}` 更稳，
      # 后者在"裁切点无尾随换行"时不会删掉不完整行（评审 06:1x minor）
      _head=$(printf '%s' "$_head" | sed '$d')
      printf '\n\n=== %s ===\n%s\n' "$_b" "$_head"
      # ② 截断**必须留痕**（阶段 5 的 L3 04:42 critical 的根因：截断不留痕 → 被读成工件缺陷）
      printf '……（本件 %sB 超过补充产物预算 3000B，已按整行截断；完整正文见 `%s`。\n本条是**提示词预算**产物，不构成工件缺陷；本件后续小节未出现在此处属预期。）' "$_sz" "${artifacts_dir}/${_b}"
    else
      printf '\n\n=== %s ===\n%s' "$_b" "$_head"
    fi
  done
}

# ── _l3_build_prompt() · Step 1: 按阶段收集工件 + 构造审查 prompt ──
# 用法: _l3_build_prompt <phase> <artifacts_dir> <max_bytes>   # 单位=字节（§B3）
# 输出: prompt_text 到 stdout；无工件时返回 3
_l3_build_prompt() {
  local phase="$1" artifacts_dir="$2" max_bytes="$3"

  local artifact="" checklist=""
  case "$phase" in
    1)
      if [ -f "${artifacts_dir}/REQUIREMENT.md" ]; then
        artifact=$(_l3_utf8_head_bytes "$max_bytes" "${artifacts_dir}/REQUIREMENT.md" 2>/dev/null || echo "")
      fi
      # M34：CHANGE.md（本 change 的原始问题清单）是判定 AC 覆盖是否完整的前提，
      # 补充交付物（含 L2-EMPTY-ATTRIBUTION.md）是判定「AC 交付物是否存在」的证据。
      [ -f "${artifacts_dir}/CHANGE.md" ] && \
        artifact="${artifact}"$'\n\n=== CHANGE.md ===\n'"$(_l3_utf8_head_bytes 6000 "${artifacts_dir}/CHANGE.md" 2>/dev/null || true)"
      artifact="${artifact}"$'\n'"$(_l3_extra_deliverables "$artifacts_dir")"
      checklist="AC 是否每条 Given/When/Then 可验证且无歧义？v1/v2/out 范围切分是否合理？是否有范围蔓延或遗漏的非功能性需求？（判断某 AC 的交付物「是否存在」时，以本提示词中给出的 === 文件名 === 正文为准）"
      ;;
    2)
      if [ -f "${artifacts_dir}/DESIGN.md" ]; then
        artifact=$(_l3_utf8_head_bytes "$max_bytes" "${artifacts_dir}/DESIGN.md" 2>/dev/null || echo "")
      fi
      local adr_dir
      adr_dir="$(dirname "$artifacts_dir")/adr"
      if [ -d "$adr_dir" ]; then
        while IFS= read -r f; do
          [ -n "$f" ] || continue
          artifact="${artifact}"$'\n\n--- '"${f}"$' ---\n'"$(_l3_utf8_head_bytes 2000 "$f" 2>/dev/null || echo "")"
        done < <(find "$adr_dir" -type f -name '*.md' 2>/dev/null | head -3 || true)
      fi
      artifact="${artifact}"$'\n'"$(_l3_extra_deliverables "$artifacts_dir")" 
      checklist="ADR 决策是否合理且有充分理由？是否撞既有架构/跨模块契约？抽象层次是否得当（深模块 vs 浅模块）？风险段是否遗漏关键风险？"
      ;;
    3)
      if [ -f "${artifacts_dir}/TASK.md" ]; then
        artifact=$(_l3_utf8_head_bytes "$max_bytes" "${artifacts_dir}/TASK.md" 2>/dev/null || echo "")
      fi
      artifact="${artifact}"$'\n'"$(_l3_extra_deliverables "$artifacts_dir")" 
      checklist="任务拆解是否覆盖 REQUIREMENT 全 AC？depends_on 依赖是否无环？每个 task 的 verify 是否可执行且能证伪？write_files 边界是否清晰不越界？"
      ;;
    5)
      if [ -f "${artifacts_dir}/TEST.md" ]; then
        artifact=$(_l3_utf8_head_bytes "$max_bytes" "${artifacts_dir}/TEST.md" 2>/dev/null || echo "")
      fi
      artifact="${artifact}"$'\n'"$(_l3_extra_deliverables "$artifacts_dir")" 
      checklist="测试矩阵是否覆盖全 AC？覆盖率是否达标？UAT 是否可复现？是否有 mock 屏蔽真实失败？回归测试是否含？"
      ;;
    6)
      local project_root
      if [[ "$artifacts_dir" == */.specs/archive/* ]]; then
        project_root="$(dirname "$(dirname "$(dirname "$artifacts_dir")")")"
      else
        project_root="$(dirname "$(dirname "$artifacts_dir")")"
      fi
      # source common.sh for fk_estimate_tokens (fail-open)
      local _common_lib="${HOOK_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/common.sh"
      [ -f "$_common_lib" ] && source "$_common_lib" 2>/dev/null || true
      local _new_limit=$((max_bytes / 4))
      artifact=$(cd "$project_root" && {
        # 并集策略: git diff HEAD (工作区 vs HEAD) + git diff --cached (index vs HEAD)
        # 用 awk 按文件路径去重（同名文件取首次出现的更完整的 diff）
        { git diff HEAD 2>/dev/null; echo ""; git diff --cached 2>/dev/null; } | awk '
          /^diff --git/ { f=$3; if (seen[f]++) next }
          { print }
        '
        git ls-files --others --exclude-standard 2>/dev/null | grep -E '\.(sh|bats)$' | while read -r f; do
          echo ""; echo "=== NEW FILE: $f ==="
          _l3_utf8_head_bytes "$_new_limit" "$project_root/$f" 2>/dev/null || true
        done
      } | {
        if declare -f fk_estimate_tokens >/dev/null 2>&1; then
          local _raw && _raw=$(cat) && local _est && _est=$(fk_estimate_tokens "$_raw" 2>/dev/null || echo "0")
          local _max_tokens=$(( ${FK_CONTEXT_WINDOW:-100000} * 60 / 100 ))
          if [ "${_est:-0}" -le "${_max_tokens:-60000}" ] 2>/dev/null; then
            echo "$_raw"
          else
            echo "$_raw" | _l3_utf8_head_stream "$max_bytes"
          fi
        else
          _l3_utf8_head_stream "$max_bytes"
        fi
      } || true)
      if [ -f "${artifacts_dir}/REVIEW.md" ]; then
        artifact="${artifact}"$'\n\n=== 主 agent REVIEW.md ===\n'"$(_l3_utf8_head_bytes 8000 "${artifacts_dir}/REVIEW.md" 2>/dev/null || echo "")"
      fi
      artifact="${artifact}"$'\n'"$(_l3_extra_deliverables "$artifacts_dir")" 
      checklist="spec 合规（每条 AC 是否被代码覆盖）？代码质量（6 维衰退风险：认知过载/变更传播/知识重复/偶然复杂/依赖混乱/领域扭曲）？是否有 critical？"
      ;;
    7)
      local project_root
      if [[ "$artifacts_dir" == */.specs/archive/* ]]; then
        project_root="$(dirname "$(dirname "$(dirname "$artifacts_dir")")")"
      else
        project_root="$(dirname "$(dirname "$artifacts_dir")")"
      fi
      # 反馈优先：CHANGELOG/LESSONS 段置最前，承受截断的最后才是工件正文
      artifact=""
      local changelog="${project_root:-.}/.specs/CHANGELOG.md"
      if [ -f "$changelog" ]; then
        artifact="=== CHANGELOG.md ===\n$(_l3_utf8_head_bytes 3000 "$changelog" 2>/dev/null || true)"
      fi
      local lessons="${project_root:-.}/.specs/LESSONS.md"
      if [ -f "$lessons" ]; then
        [ -n "$artifact" ] && artifact+="\n\n"
        artifact+="=== LESSONS.md ===\n$(_l3_utf8_head_bytes 2000 "$lessons" 2>/dev/null || true)"
      fi
      [ -n "$artifact" ] && artifact+="\n\n"
      # §B4 修复（2026-09-18 · L3-review-defects-2026-09-17）：
      #   ① 原 `ls -la | head -30` 对顶层条目 > 28 的 change 会截掉按名序靠后的文件
      #      （实测 41 条目时 TASK.md / TEST.md / REQUIREMENT.md / REVIEW.md / UAT.md 全不可见），
      #      L3 据此报"产物缺失"并 verdict=fail —— 对提示词为真、对仓库为假。
      #      → 改为全量清单（不再按行数截断）。整体仍受 $max_bytes 约束，溢出只会切正文尾部。
      #   ② 原名序含硬编码 INTEGRATION.md，本项目阶段 7 不产出该文件（flow-integration
      #      skill 的产出是 UAT.md + CHANGELOG 更新），提示词里必然出现
      #      `=== INTEGRATION.md === MISSING` → 模型如实报为 major 缺陷。
      #      → 必备清单只留真实契约产物；INTEGRATION.md / UAT.md 改为「存在才列」。
      artifact+="=== 产物目录（全量）===\n$(ls -la "$artifacts_dir" 2>/dev/null)"
      local _req _opt
      for _req in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md; do
        if [ -f "${artifacts_dir}/${_req}" ]; then
          artifact="${artifact}\n\n=== ${_req} ===\n$(_l3_utf8_head_bytes 3000 "${artifacts_dir}/${_req}" 2>/dev/null || true)"
          # 必备件同样是 3000B **预览**预算 → 必须留痕（22:52 轮 L3 把"预览截断"读成
          # "工件正文被截断"并据此判 major；与补充产物的留痕同因同治）
          local _rsz
          _rsz=$(wc -c < "${artifacts_dir}/${_req}" 2>/dev/null || echo 0); _rsz=${_rsz// /}
          if [ "${_rsz:-0}" -gt 3000 ]; then
            artifact="${artifact}\n……（本件 ${_rsz}B 超过**必备件预览预算** 3000B，此处只示前 3000B；\n完整正文见 ${artifacts_dir}/${_req}。本条是**提示词预算**产物，不构成工件缺陷。）"
          fi
        else
          artifact="${artifact}\n\n=== ${_req} === MISSING"
        fi
      done
      #   ③（M34）必备 6 件之外的**全部** *.md 交付物都要给正文，而不是硬编码白名单。
      #      白名单漏掉了 AC-2 的交付物 `L2-EMPTY-ATTRIBUTION.md`，L3 于是如实报
      #      「工件中未提供该清单的实际内容」→ 对提示词为真、对仓库为假（与 ① 同源的
      #      第二类假阳性：审查者只能看到我们喂进去的东西）。
      #      排序：按体积升序 —— 具体 AC 交付物多为小文件，MINOR-DEFERRED.md 这类
      #      大而次要的垫尾，使 $max_bytes 截断只可能切到「最不具体」的尾部。
      #      INDEPENDENT-REVIEW-*.md 排除：本身是审查记录、体量 100KB+，且本轮正在写它。
      artifact+="$(_l3_extra_deliverables "$artifacts_dir")"
      unset _req
      artifact=$(echo -e "$artifact" | _l3_utf8_head_stream "$max_bytes")
      checklist="归档产物是否齐全（CHANGE/REQUIREMENT/DESIGN/TASK/T0x-SUMMARY（如已生成）/TEST/REVIEW）？\n注意：以「产物目录（全量）」清单为准（不再按行数截断）。除必备 6 件外的 *.md（UAT.md / MINOR-DEFERRED.md / L2-EMPTY-ATTRIBUTION.md 等）是补充产物：**未出现不构成缺陷**，一旦给出正文则须纳入审查（不得再说「未提供」）。\n项目级 .specs/CHANGELOG.md 是否更新（CHANGELOG 不入归档目录，勿因归档目录缺失报错）？archive 是否完整？\n**两点本阶段特有、必须先读**：① 本阶段的独立审查记录「INDEPENDENT-REVIEW-7.md」与其完成锚点由**审查子系统在本次审查之后**写入（锚点只在通过时产生）→ 其缺失/为空属**预期**，不得据此判缺陷；② 各必备件正文此处按 **3000B 预览预算**裁剪，凡标注「超过必备件预览预算」的即为提示词裁剪，不构成工件缺陷（完整正文在仓库中）。"
      ;;
  esac
  [ -n "$artifact" ] || { echo "[l3-review] no artifact for phase $phase" >&2; return 3; }

  # 构造 prompt (jq --arg 避免工件中反引号/$ 被 shell 解释)
  # 固定指令（含 JSON 回复契约）置于工件之前：总输出按 max_bytes 截断时只切工件尾部，不切指令
  local _full _art_file
  # ⚠️ ARG_MAX（2026-09-19 05:0x：阶段 6 实测 `jq: 参数列表过长`）：单个 argv 上限
  # MAX_ARG_STRLEN = 128 KiB，cap 已提到 200000B → 工件正文必须**落文件**后经 `--rawfile` 传入。
  _art_file=$(mktemp "${TMPDIR:-/tmp}/fk-l3-artifact.XXXXXX") || {
    echo "[l3-review] mktemp 失败：无法创建工件临时文件（TMPDIR=${TMPDIR:-/tmp}）" >&2; return 3; }
  printf '%s' "$artifact" > "$_art_file"
  _full=$(jq -nr \
    --arg checklist "$checklist" \
    --arg phase "$phase" \
    --rawfile artifact "$_art_file" \
    '"你是独立审查员，对以下 flow-kit 工件做盲审。独立性要求：禁止假设作者意图，只看工件本身；不接受也不引用任何「作者认为/主 agent 结论」类外部陈述。\n\n审查重点：" + $checklist + "\n\n请严格按 JSON 回复，不要 markdown 代码块包裹：\n{\"critical\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"major\":[{\"file\":\"\",\"issue\":\"\",\"why\":\"\",\"fix\":\"\"}],\"minor\":[...],\"verdict\":\"pass 或 fail\",\"summary\":\"一句话总评\"}\ncritical/major/minor 每项含 file/issue/why/fix 四要素。无问题给空数组。verdict=fail 当且仅当存在 critical。\n若某工件正文标注「超过补充产物预算」或提示词被截断，那是**提示词预算**造成（整行截断），不要据此判缺陷；未出现的小节属预期。\n\n工件（阶段 " + $phase + "）：\n" + $artifact'
  ) || { rm -f "$_art_file"; echo "[l3-review] jq 提示词构造失败（见上）" >&2; return 3; }
  rm -f "$_art_file"
  _l3_emit_prompt "$_full" "$max_bytes"
}
