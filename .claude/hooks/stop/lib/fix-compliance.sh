#!/bin/bash
# fix-compliance.sh — L2/L3 review 实效性校验共享 lib
#
# 提供四个函数，供 independent-review-gate.sh (PreToolUse hook) 调用：
#   fk_classify_source_files()    — 按扩展名分类文件列表（源码 vs 文档）
#   fk_check_doc_only_diff()      — 检测 diff 是否仅含文档文件（AC-2）
#   fk_verify_finding_files()     — 逐发现文件级校验（AC-2b）
#   fk_fix_compliance_check()     — 实效性校验主入口
#
# 仅对 phase 5/6/7 触发（AC-5 阶段限定）。
# 所有错误路径 fail-closed（D7）—— 出错阻断而非静默放行。
#
# 环境变量:
#   L3_FIX_SOURCE_EXTS — 冒号分隔的额外源码扩展名（覆盖/追加默认白名单）

set -euo pipefail

# ── _grep 兼容层（Claude Code 环境 _grep → ugrep wrapper，-P 和特殊正则语法不兼容）──
# 本文件所有 _grep 调用通过此函数走 GNU _grep，避免 ugrep 兼容问题
_grep() { command grep "$@"; }

# ── 默认源码扩展名白名单（D3）──
DEFAULT_SOURCE_EXTS="sh:bats:js:ts:jsx:tsx:py:go:rs:c:h:cpp:hpp:java:rb:php:swift:kt:scala:r:sql:graphql"

# ── _fk_get_source_exts() · 合并默认白名单 + env var ──
_fk_get_source_exts() {
  local exts="${DEFAULT_SOURCE_EXTS}"
  if [ -n "${L3_FIX_SOURCE_EXTS:-}" ]; then
    exts="${L3_FIX_SOURCE_EXTS}"
  fi
  echo "$exts"
}

# ── fk_classify_source_files() ──
# 输入: $1=文件列表（换行分隔）, $2=源码扩展名白名单（冒号分隔，可选；默认从 _fk_get_source_exts 读取）
# 输出: stdout: "source:<count>" 换行 "doc:<count>" 换行 逐文件 "<type>:<path>"
# 返回: 0=成功, 1=输入为空, 2=内部错误
fk_classify_source_files() {
  local file_list="$1"
  local exts="${2:-$(_fk_get_source_exts)}"

  [ -n "$file_list" ] || return 1

  # 构建 _grep -E 正则：\.(sh|bats|js|...)$
  local ext_pattern
  ext_pattern=$(echo "$exts" | tr ':' '|')
  ext_pattern="\.(${ext_pattern})$"

  local source_count=0 doc_count=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # 剥离行号后缀（:数字）
    local clean_f="${f%%:*}"
    if echo "$clean_f" | _grep -qE "$ext_pattern" 2>/dev/null; then
      echo "source:${f}"
      source_count=$((source_count + 1))
    else
      echo "doc:${f}"
      doc_count=$((doc_count + 1))
    fi
  done <<< "$file_list"

  echo "source:${source_count}"
  echo "doc:${doc_count}"
  return 0
}

# ── fk_check_doc_only_diff() ──
# 输入: $1=project_root
# 输出: stdout: "DOC_ONLY:true|false"
# 返回: 0=含源码变更（放行）, 1=仅文档变更（阻断）, 2=diff 为空（阻断）, 3=内部错误（阻断 · fail-closed）
fk_check_doc_only_diff() {
  local project_root="$1"

  [ -d "$project_root" ] || { echo "DOC_ONLY:error" >&2; return 3; }

  # 获取 diff 中的变更文件列表
  local diff_files
  diff_files=$(cd "$project_root" && git diff --name-only HEAD 2>/dev/null) || {
    echo "[fix-compliance] git diff failed" >&2
    echo "DOC_ONLY:error"
    return 3
  }

  # diff 为空 → 阻断（R3：agent 声称修复但无 diff）
  if [ -z "$diff_files" ]; then
    echo "DOC_ONLY:true(empty_diff)"
    return 2
  fi

  # 分类文件
  local classified source_count doc_count
  classified=$(fk_classify_source_files "$diff_files" "" 2>/dev/null) || {
    echo "[fix-compliance] file classification failed" >&2
    echo "DOC_ONLY:error"
    return 3
  }

  source_count=$(echo "$classified" | _grep "^source:" | tail -1 | cut -d: -f2)
  doc_count=$(echo "$classified" | _grep "^doc:" | tail -1 | cut -d: -f2)
  source_count="${source_count:-0}"
  doc_count="${doc_count:-0}"

  if [ "$source_count" -eq 0 ]; then
    echo "DOC_ONLY:true"
    return 1
  else
    echo "DOC_ONLY:false"
    return 0
  fi
}

# ── fk_verify_finding_files() ──
# 输入: $1=review_md 路径, $2=project_root
# 输出: stdout: 逐行 "<status>:<filepath>" (status=OK|MISSING|PARSE_ERROR)
# 返回: 0=全部通过或 <50% 未通过（告警但放行）, 1=≥50% 未通过（阻断）, 2=解析错误（阻断 · fail-closed）
fk_verify_finding_files() {
  local review_md="$1"
  local project_root="$2"

  [ -f "$review_md" ] || { echo "PARSE_ERROR:review_md not found" >&2; return 2; }
  [ -d "$project_root" ] || { echo "PARSE_ERROR:project_root not found" >&2; return 2; }

  # 从 review_md 解析 "Fixed in:" 声明（DESIGN §3.2 统一格式）
  local fixed_files
  fixed_files=$(_grep -oP '^Fixed in:\s+\K\S+' "$review_md" 2>/dev/null || echo "")
  if [ -z "$fixed_files" ]; then
    # 无 "Fixed in:" 声明 → 可能所有发现都是 tech-debt 或 not-applicable，放行
    echo "OK:no_fixed_claims"
    return 0
  fi

  # 获取 diff 文件列表
  local diff_files
  diff_files=$(cd "$project_root" && git diff --name-only HEAD 2>/dev/null) || {
    echo "[fix-compliance] git diff failed" >&2
    echo "PARSE_ERROR:git_diff_failed"
    return 2
  }

  local total=0 missing=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    total=$((total + 1))
    # 检查文件是否在 diff 中（支持部分路径匹配，归一化 ./ 前缀）
    f_clean="${f#./}"
    if echo "$diff_files" | _grep -qF "$f_clean" 2>/dev/null; then
      echo "OK:${f}"
    else
      echo "MISSING:${f}"
      missing=$((missing + 1))
    fi
  done <<< "$fixed_files"

  if [ "$total" -eq 0 ]; then
    echo "OK:no_fixed_claims"
    return 0
  fi

  # ≥50% 未通过 → 阻断（AC-2b）
  # 使用乘法避免整数除法截断：missing * 2 >= total 等价于 missing >= total/2（向上取整）
  if [ "$(( missing * 2 ))" -ge "$total" ] && [ "$total" -gt 0 ]; then
    echo "BLOCKED:${missing}/${total} MISSING (>=50%)"
    return 1
  fi

  # < 50% 未通过 → 告警但放行
  if [ "$missing" -gt 0 ]; then
    echo "WARNING:${missing}/${total} MISSING (<50%, pass with warning)"
  fi
  return 0
}

# ── fk_fix_compliance_check() ──
# 实效性校验主入口（被 independent-review-gate.sh 调用）
# 输入: $1=phase, $2=change_id, $3=specs_dir (.specs/<id>/), $4=project_root
# 返回: 0=通过, 1=阻断（纯文档响应）, 2=阻断（逐发现校验未通过）, 3=错误（阻断 · fail-closed）
fk_fix_compliance_check() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="$3"
  local project_root="$4"

  # ── AC-5 阶段限定：仅 5/6/7 触发 ──
  case "$phase" in
    5|6|7) ;;
    *) return 0 ;;  # 非 5/6/7 → 跳过
  esac

  # 参数校验
  [ -n "$change_id" ] || { echo "[fix-compliance] missing change_id" >&2; return 3; }
  [ -d "$specs_dir" ] || { echo "[fix-compliance] specs_dir not found: $specs_dir" >&2; return 3; }

  local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"

  # ── ① 读取 review 发现，统计源码级发现（AC-2a）──
  if [ ! -f "$review_md" ]; then
    # 无 review 文件 → 无需校验（可能 review 尚未运行）
    return 0
  fi

  # AC-2a 判定：Symptom 字段中是否引用源码文件
  local source_findings=0
  # 从 review_md 提取所有 **Symptom（症状）** 行，再从行中提取文件路径
  local symptom_lines
  symptom_lines=$(_grep -A1 '^\*\*Symptom' "$review_md" 2>/dev/null | _grep -oP '(^|\s)[a-zA-Z0-9_/.~-]+\.(sh|bats|js|ts|jsx|tsx|py|go|rs|c|h|cpp|hpp|java|rb|php|swift|kt|scala|r|sql|graphql)(\s|:|$)' 2>/dev/null || echo "")

  if [ -n "$symptom_lines" ]; then
    # 有源码文件引用 → 存在源码级发现
    source_findings=1
  else
    # 检查是否完全没有文件路径引用（AC-2a 规则 3：默认源码级）
    local any_file_ref
    any_file_ref=$(_grep -oP '(^|\s)[a-zA-Z0-9_/.~-]+\.(md|json|yaml|yml)(\s|:|$)' "$review_md" 2>/dev/null | head -1 || echo "")
    if [ -z "$any_file_ref" ] && [ -z "$symptom_lines" ]; then
      # 完全没有文件路径引用 → 默认判定为可能有源码问题（宁可多检不漏检）
      source_findings=1
    fi
  fi

  if [ "$source_findings" -eq 0 ]; then
    # 全部是文档级发现 → 跳过（AC-2a 规则 2）
    return 0
  fi

  # ── ② AC-2 纯文档响应检测 ──
  fk_check_doc_only_diff "$project_root" 2>/dev/null || {
    local ret=$?
    cat >&2 <<EOF
⛔ 独立 review 实效性校验（AC-2）：检测到纯文档响应。
   INDEPENDENT-REVIEW-${phase}.md 包含源码级发现（${source_findings} 条），
   但 git diff 中无任何源码文件变更（仅 .md 文件修改）。

   请对每条源码发现执行代码修复（Fixed in: <file>）或登记技术债（Tech-debt: <reason>），
   禁止仅通过写文档/标记"未覆盖"来回应 review 发现。
EOF
    return 1
  }

  # ── ②b 无 Fixed in 声明检测（L3 CRITICAL fix）──
  # 源码级发现 > 0 但 agent 未输出任何 Fixed in: 声明 → 阻断
  local fixed_count
  fixed_count=$(_grep -c '^Fixed in:' "$review_md" 2>/dev/null || true)
  fixed_count="${fixed_count:-0}"
  if [ "$fixed_count" -eq 0 ]; then
    # 检查是否有 Tech-debt 声明（全部登记为技术债是可接受的，但需有显式理由）
    local techdebt_count
    techdebt_count=$(_grep -c '^Tech-debt:' "$review_md" 2>/dev/null || true)
    techdebt_count="${techdebt_count:-0}"
    if [ "$techdebt_count" -eq 0 ]; then
      cat >&2 <<EOF
⛔ 独立 review 实效性校验：源码级发现未处理。
   INDEPENDENT-REVIEW-${phase}.md 包含源码级发现（≥1 条），
   但 agent 响应段无任何 Fixed in: 或 Tech-debt: 声明。

   请对每条发现输出分类标记：
   - Fixed in: <filepath>  — 已修复的代码文件
   - Tech-debt: <reason>   — 无法本次修复的技术债（含理由）
   禁止无声明直接通过 gate。
EOF
      return 2
    fi
  fi

  # ── ③ AC-2b 逐发现文件校验 ──
  local verify_result
  verify_result=$(fk_verify_finding_files "$review_md" "$project_root" 2>/dev/null) || {
    local ret=$?
    if [ "$ret" -eq 1 ]; then
      local blocked_line
      blocked_line=$(echo "$verify_result" | _grep "^BLOCKED:" | head -1)
      cat >&2 <<EOF
⛔ 独立 review 实效性校验（AC-2b）：逐发现文件校验未通过。
   ${blocked_line}
   ≥50% 的 "Fixed in:" 声明对应的文件未在 git diff 中找到。
   请确认修复已实际写入代码（不仅仅是声明），然后重试。
EOF
      return 2
    fi
    # 其他错误
    cat >&2 <<EOF
⛔ 独立 review 实效性校验（AC-2b）：解析错误。
   无法从 INDEPENDENT-REVIEW-${phase}.md 解析修复声明。
   请检查 "Fixed in:" 标记格式是否正确（DESIGN §3.2）。
EOF
    return 3
  }

  # ── 输出告警（< 50% 未通过，放行但有 hint）──
  if echo "$verify_result" | _grep -q "^WARNING:" 2>/dev/null; then
    local warn_line
    warn_line=$(echo "$verify_result" | _grep "^WARNING:" | head -1)
    cat >&2 <<EOF
⚠️  独立 review 实效性校验：${warn_line}
   部分 "Fixed in:" 声明未在 diff 中找到对应文件，但未达 50% 阈值，放行。
   建议检查：是否遗漏了文件修改或路径拼写有误。
EOF
  fi

  return 0
}
