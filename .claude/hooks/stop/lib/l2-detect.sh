#!/bin/bash
# l2-detect.sh — L2 独立审查检测 + 派发提示生成 lib
#
# 提供两个函数:
#   l2_detect_missing <phase> <change_id> [specs_dir]
#     检查 INDEPENDENT-REVIEW-<phase>.md 是否含 L2 段
#     返回: 0 = L2 已完成, 1 = L2 缺失, 2 = 错误
#
#   l2_dispatch_prompt <phase> <change_id> [specs_dir]
#     生成一键 Agent 命令模板（双模式：claude code → subagent_type + description + prompt 骨架；
#     opencode → category: unspecified-high + description + prompt 骨架）
#     输出到 stdout，可直接复制粘贴
#
# 环境依赖:
#   PROJECT_ROOT — flow-kit 项目根目录

set -euo pipefail

# 依赖注入：common.sh（fk_resolve_api_credentials / fk_platform_is_opencode，DESIGN D1/D2）
# 调用方（pre-tool-use gate-checks-basic.sh）只 source 本文件；stop 链可能先 source
# common.sh —— type 检查保证幂等（与 correction-file.sh 注入同惯例）。
type fk_resolve_api_credentials >/dev/null 2>&1 || {
  _L2_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
  if [ -n "${_L2_LIB_DIR:-}" ] && [ -f "${_L2_LIB_DIR}/common.sh" ]; then
    source "${_L2_LIB_DIR}/common.sh"
  fi
  unset _L2_LIB_DIR
}

# 依赖注入：l3-section.sh（_l3_section_spans / L3 段边界判定单一来源，见 _fk_l2_scope）
# 调用链（l3-review.sh）已 source；本文件亦被 done-validation.sh / gate-checks-review.sh
# 独立 source，故此处按同目录兜底（type 守卫保证幂等）。
type _l3_section_spans >/dev/null 2>&1 || {
  _L2_SEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
  if [ -n "${_L2_SEC_DIR:-}" ] && [ -f "${_L2_SEC_DIR}/l3-section.sh" ]; then
    source "${_L2_SEC_DIR}/l3-section.sh"
  fi
  unset _L2_SEC_DIR
}

# _fk_l2_scope — 取工件的「L2 层」文本（B1 ②层收口 · 2026-09-18）
# 用法: _fk_l2_scope <review_md>   → stdout
#
# 排除两类**非 L2 层**的块，其余（含全部 L2 轮次）原样保留：
#   ① L3 段 —— 区间由 l3-section.sh::_l3_section_spans() 给出（**边界判定的唯一来源**）
#   ② `^## 主 agent` 起，到下一个 `^## ` 标题——主 agent 的复述/反驳，按 L2 契约
#      （L2-blind-review.md:142「主 agent 无权修改你的原文判断」）不参与 L2 结论
#
# 边界判定单一来源：本函数**不得**自己按 `^## ` 复位。载荷里出现行首 `## ` 是常见形态，
# 那样会让 L3 正文回流进"L2 层"，其后的行首 `Verdict:` 顶掉 L2 结论（= §B2 已在删除侧
# 否决的启发式在读侧复活）；同理也不能「从 ^## L2 起、到下一个 ^## 止」（会腰斩含二级
# 子标题的 L2 报告与多轮 L2 交替形态）。完整论证见 DESIGN.md §D7 与 ADR-026。
_fk_l2_scope() {
  local review_md="$1"
  local spans=""
  if type _l3_section_spans >/dev/null 2>&1; then
    spans="$(_l3_section_spans "$review_md")"
  else
    # 降级路径（l3-section.sh 不可用，例如本文件被单独复制走）：
    # **绝不能 fail-open**（1-requirement 的 L2 三审 R3）——若此处什么都不排除，
    # 整个文件都会落入"L2 层"，L3 的 verdict 又会冒充 L2，等于 §B1 原样复活且零告警。
    # 故内联一份**保守**的标题法排除（旧规则）：它不抗载荷伪造，但能覆盖全部常规形态。
    spans="$(awk '
      { line[NR] = $0 }
      END {
        n = NR; i = 1
        while (i <= n) {
          if (line[i] ~ /^## L3 (盲审|重审)/) {
            stop = n
            # 终点与 _l3_spans_impl 的无标记分支同源收紧（2026-09-18）：只在**已知区段标题**
            # 处收口，避免载荷里的 `## ` 把段尾切早、让其后 Verdict 漏进 L2 层。
            for (j = i + 1; j <= n; j++) if (line[j] ~ /^## (L2 |主 agent|L3 )/) { stop = j - 1; break }
            print i " " stop
            i = stop + 1
          } else i++
        }
      }' "$review_md" 2>/dev/null)"
    echo "[l2-detect] WARNING: l3-section.sh 不可用，_fk_l2_scope 走保守降级路径（L3 段按标题法排除）" >&2
  fi
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
      skip = 0
      for (i = 1; i <= NR; i++) {
        if (line[i] ~ /^## 主 agent/) skip = 1
        else if (line[i] ~ /^## /) skip = 0
        if (!(i in del) && !skip) print line[i]
      }
    }
  ' "$review_md" 2>/dev/null | _l2_unescape_payload
}

# _l2_unescape_payload — 还原写入侧转义（ADR-026 · 设计 D13 · 阶段 2 的 L3 major ①）
# 用法: … | _l2_unescape_payload
#
# 为什么需要：`_l3_escape_payload` 为保护**结构性解析器**（段边界、标记、围栏配对）会给行首
# `## ` / `<!-- /L3-SECTION -->` / 围栏加反斜杠；而 L2 结论提取里有一条「`## Verdict` 标题 →
# 取次行」的**内容级**解析路径，它看到的是转义后的 `\## Verdict` —— 合法结论会失配成空值
# （阶段 2 的 L3 major ①）。故在**边界判定完成之后**把 L2 层文本还原为载荷原文。
#
# 安全性：还原只作用于已排除 L3 段与 `## 主 agent` 段之后的文本；段边界判定用的是**原始**
# 文本（`_l3_section_spans`），故还原不会重新引入边界。
_l2_unescape_payload() {
  # 单趟解码（M38 · 2026-09-18）：**先判两个反斜杠，再判一个反斜杠**，顺序即优先级 ——
  # 多趟 sed 会互相干扰（去掉一个后再被当成"写侧转义"吃第二次）。
  # 语义：`\\X`（两个）→ `\X`（原文自带）；`\`+结构行首 → 结构行首（写侧转义）；其余原样。
  awk '
    /^\\\\/ { print substr($0, 2); next }
    /^\\(## |<!-- \/L3-SECTION -->|```)/ { print substr($0, 2); next }
    { print }
  '
}



# fk_extract_l2_verdict — extract L2 verdict from INDEPENDENT-REVIEW-N.md（ADR-007 / D1 · gate-review-fix）
# Single source for L2 verdict extraction across 4 consumers (4 files).
#
# B1 修复（2026-09-18 · L3-review-defects-2026-09-17 §B1）：
#   修复前策略 = "整份文件里最后一处含 `verdict…:` 的行 → 抽 pass|fail"，三个缺陷：
#     ① 命中 L3 段的 JSON（`  "verdict": "fail",`）——L3 段是后追加的，于是 L2 结论被 L3 改写；
#        同一工件同一函数在不同时点给出不同结论，.done 不可复现；
#     ② 无行首锚定 —— 散文 / 表格 / 主 agent 的「**有效 Verdict: pass**」全都命中；
#     ③ `grep -o` 保留原大小写 —— 命中 `PASS` 就返回 `PASS`，调用方 ^(pass|fail|skipped)$
#        校验失败 → `l3-review.sh:61` 直接 return 3，L3 从此不再运行且工件上看不出原因。
#   现策略（**限定 L2 层** + 锚定 + 最后一次 + 大小写归一）：
#     ① 先把文本限定在 **L2 层**（`_fk_l2_scope`）——排除 L3 层块与主 agent 响应块；
#     ② 行首锚定，容忍列表符/标题符/粗体前缀；排除以引号开头的行 → 免疫 L3 段 JSON；
#     ③ 取最后一处 = 最新一轮 L2 复审结论（同一工件可含多轮 `## L2 盲审（重审）`）；
#     ④ 输出统一小写，满足调用方值域契约。
#   兜底层：标题形（`## Verdict` → 取次行值）→ 旧式非锚定搜索。三层均在 L2 层文本内执行。
#
#   ②层收口（2026-09-18 · 1-requirement 的 L2 盲审 R1）：修复前只靠「排除引号开头的行」
#   免疫 L3 段 JSON，属于**形态免疫**而非**边界免疫**——只要 L3 段里出现一行非围栏的
#   行首 `Verdict: x`（模型把 JSON 包在 ``` 里会提前闭合围栏，其后一行即落到围栏外），
#   仍会顶掉 L2 结论。现按层切分，与 l3-section.sh 的段边界处理同构。
#   实测（语料份数随本 change 自身新增的审查文件增长，用 `bash corpus-count.sh` 现算；
#   本 change 期间为 224 份）：结果变化 8 份，全部为「原本从 L3 段漏出的值」→ 变为空值，
#   即恢复了 US-1 要的"读 L2 的结论"语义；空值在下游 4 个消费点均回落 `fail`（不阻塞）。
# 用法: l2v="$(fk_extract_l2_verdict "$review_md")"
# 返回: "pass" | "fail" | "" (未找到)
fk_extract_l2_verdict() {
  local review_md="${1:-}"
  [ -f "$review_md" ] || { echo ""; return 1; }

  local l2_text
  l2_text="$(_fk_l2_scope "$review_md")"

  local verdict=""
  # ② 行内锚定形：[spaces][列表符][标题符][粗体]Verdict[粗体][:：]
  #    排除引号开头的行 → 不命中 L3 段 JSON 的 `"verdict": "..."`（缩进+引号）
  verdict=$(printf '%s\n' "$l2_text" | grep -E '^[[:space:]]*([-*+][[:space:]]+)*#*[[:space:]]*\**[[:space:]]*[Vv][Ee][Rr][Dd][Ii][Cc][Tt][[:space:]]*\**[[:space:]]*[:：]' 2>/dev/null \
    | grep -vE '^[[:space:]]*"' 2>/dev/null \
    | tail -1 | grep -ioE 'pass|fail' | tail -1) || true

  # ③ 标题形：`## Verdict` / `### 重审 Verdict` / `## Overall verdict` → 取其后首个非空行。
  #    标题正文去掉 verdict 后须很短（≤8 个字母数字），以避开正文里以 verdict 结尾的发现标题。
  if [ -z "$verdict" ]; then
    verdict=$(awk '
      /^#+[[:space:]]/ {
        t = $0; sub(/^#+[[:space:]]*/, "", t); gsub(/[*_`[:space:]]/, "", t)
        low = tolower(t)
        if (low ~ /verdict$/) {
          rest = low; sub(/verdict$/, "", rest); gsub(/[^a-z0-9]/, "", rest)
          if (length(rest) <= 8) { pend = 1; next }
        }
        pend = 0; next
      }
      pend && NF { print; pend = 0 }
    ' <(printf '%s\n' "$l2_text") 2>/dev/null | tail -1 | grep -ioE 'pass|fail' | tail -1) || true
  fi

  # ④ 兜底：旧式非锚定搜索（同样只取最后一处；大小写归一）
  if [ -z "$verdict" ]; then
    verdict=$(printf '%s\n' "$l2_text" | grep -iE 'verdict[^a-z]*[:：]' 2>/dev/null \
      | tail -1 | grep -ioE 'pass|fail' | tail -1) || true
  fi

  verdict=$(printf '%s' "$verdict" | tr 'A-Z' 'a-z')
  [ -n "$verdict" ] || { echo ""; return 1; }
  echo "$verdict"
  return 0
}

# ── l2_detect_missing() ──────────────────────────────────────────────
l2_detect_missing() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"
  local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l2-detect] invalid phase: $phase" >&2; return 2; }
  [ -n "$change_id" ] || { echo "[l2-detect] missing change_id" >&2; return 2; }

  if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
    return 0  # L2 已完成
  fi
  return 1  # L2 缺失
}

# ── l2_dispatch_prompt() ────────────────────────────────────────────
l2_dispatch_prompt() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l2-detect] invalid phase: $phase" >&2; return 2; }
  [ -n "$change_id" ] || { echo "[l2-detect] missing change_id" >&2; return 2; }

  # 按阶段映射 agent type（与各 prompt 的独立 review 调度段一致）
  local agent_type="qa-expert"
  case "$phase" in
    1) agent_type="qa-expert" ;;
    2|3) agent_type="architect-reviewer" ;;
    5) agent_type="qa-expert" ;;
    6) agent_type="code-reviewer" ;;
    7) agent_type="architect-reviewer" ;;
  esac

  # 按阶段映射工件描述
  local artifact_desc=""
  case "$phase" in
    1) artifact_desc=".specs/${change_id}/REQUIREMENT.md（参考 CHANGE.md）" ;;
    2) artifact_desc=".specs/${change_id}/DESIGN.md（参考 adr/*.md、CONTEXT.md、ARCHITECTURE.md）" ;;
    3) artifact_desc=".specs/${change_id}/TASK.md（参考 REQUIREMENT.md、DESIGN.md）" ;;
    5) artifact_desc=".specs/${change_id}/TEST.md（参考 REQUIREMENT.md、TASK.md）" ;;
    6) artifact_desc=".specs/${change_id}/REVIEW.md + git diff（参考 REQUIREMENT.md、TASK.md、TEST.md）" ;;
    7) artifact_desc=".specs/${change_id}/ 下全部产物（参考 REVIEW.md、LESSONS.md、CHANGELOG.md）" ;;
  esac

  # 生成一键命令模板
  cat <<DISPATCH_EOF
╔══════════════════════════════════════════════════════════╗
║  ⚠️ L2 盲审未完成（阶段 ${phase} · gate_config=both）      ║
║                                                          ║
║  请复制以下命令派 L2 子 agent：                             ║
║                                                          ║
║  Agent tool:                                             ║
║    claude code:  subagent_type: ${agent_type}            ║
║    opencode:     category: unspecified-high              ║
║                 （task(category=...) 路由，subagent_type ║
║                  在 opencode 下会挂起）                  ║
║    dsh:          subagent tool（description="L2 blind   ║
║                 review phase ${phase}", prompt=注入      ║
║                 L2-blind-review.md 全文 + 审查参数）      ║
║    description: "L2 blind review phase ${phase}"                ║
║    prompt: |                                             ║
║      原样注入 flow-kit/prompts/independent/L2-blind-review.md  ║
║                                                          ║
║      ## 本次审查参数                                      ║
║      - 阶段：${phase}                                          ║
║      - change-id：${change_id}                          ║
║      - 工件：${artifact_desc}           ║
║      - 输出：写入 .specs/${change_id}/INDEPENDENT-REVIEW-${phase}.md ║
║                                                          ║
║  > 参数如有变更，参考源文件:                                ║
║    flow-kit/prompts/independent/L2-blind-review.md        ║
║    flow-kit/prompts/${phase}-*.md（独立 review 调度段）     ║
╚══════════════════════════════════════════════════════════╝
DISPATCH_EOF

  return 0
}

# ── l2_dispatch_agent() ────────────────────────────────────────────
# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md
#
# 自动派发 L2 审查 Agent（curl + API + 异步后台进程，凭证经共享函数解析）。
# 用法: l2_dispatch_agent <phase> <change_id> [specs_dir]
# 返回: 0 = dispatch 成功触发后台进程, 1 = 失败（curl 不可用/API 不可达/凭证缺失）
# 环境变量:
#   FLOW_KIT_L2_MOCK=1 — 跳过真实 API 调用，使用 mock 响应（供 bats 测试用）
#   凭证来源：fk_resolve_api_credentials()（common.sh，DESIGN D1）→ 输出 FK_API_BASE_URL /
#     FK_API_AUTH_TOKEN / FK_API_AUTH_SCHEME 全局（Path1 ANTHROPIC_AUTH_TOKEN bearer
#     > Path3 FLOW_KIT_L3_AUTH_TOKEN+FLOW_KIT_L3_BASE_URL bearer > Path2 ANTHROPIC_API_KEY x-api-key）
l2_dispatch_agent() {
  local phase="$1"
  local change_id="$2"
  local specs_dir="${3:-${PROJECT_ROOT}/.specs/${change_id}}"
  local review_md="${specs_dir}/INDEPENDENT-REVIEW-${phase}.md"

  [[ "$phase" =~ ^[1-7]$ ]] || { echo "[l2-dispatch] invalid phase: $phase" >&2; return 1; }
  [ -n "$change_id" ] || { echo "[l2-dispatch] missing change_id" >&2; return 1; }

  # AC-7: 确保 specs_dir 存在（防止后台 stderr redirect 因目录缺失失败）
  mkdir -p "$specs_dir" 2>/dev/null || true

  # ── Mock 模式（测试用）──────────────────────────────────────────
  if [ "${FLOW_KIT_L2_MOCK:-0}" = "1" ]; then
    local mock_tmp
    mock_tmp="$(mktemp "${review_md}.tmp.XXXXXX")"
    local mock_ts
    mock_ts="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo mock)"   # 修 BUG-G：mock_ts 原未定义，set -u 下 line120 ${mock_ts} 报错
    if [ -f "$review_md" ]; then
      cat "$review_md" > "$mock_tmp" 2>/dev/null || true
    fi
    {
      echo ""
      echo "---"
      echo "## L2 盲审（mock · ${mock_ts}）"
      echo ""
      echo "> Mock L2 review — FLOW_KIT_L2_MOCK=1"
      echo ""
      echo "### 🟢 Mock Finding · Mock review for testing"
      echo "**Symptom**: Mock dispatch succeeded"
      echo "**Source**: FLOW_KIT_L2_MOCK=1"
      echo "**Consequence**: None (mock)"
      echo "**Remedy**: None (mock)"
      echo ""
      echo "**Verdict**: pass"
    } >> "$mock_tmp"
    mv "$mock_tmp" "$review_md" 2>/dev/null || true
    echo "[l2-dispatch] mock Agent wrote to ${review_md}" >&2
    return 0
  fi

  # ── 凭证检查（共享函数 fk_resolve_api_credentials · DESIGN D1）──
  # 双平台凭证解析单点（common.sh L266-314）：Path1 ANTHROPIC_AUTH_TOKEN(bearer)
  # > Path3 FLOW_KIT_L3_AUTH_TOKEN+FLOW_KIT_L3_BASE_URL(bearer, 短路 Path2)
  # > Path2 ANTHROPIC_API_KEY(x-api-key)。rc: 0=就绪 / 1=无凭证 / 2=Path3 不完整。
  # 平台判定统一 fk_platform_is_opencode()（D2：OPENCODE_BIN/OPENCODE 任一非空即真）。
  # opencode 场景生产可达：oh-my-opencode 4.19.4+ 已桥接 PreToolUse（l2-l3-subagent-fix
  # 阶段6 L2 盲审 R6 已证伪「PreToolUse 不触发」旧假设），两分支均为真实可达路径。
  # || 条件上下文：rc=1/2 不触发 set -e 提前退出（分支内显式 return）
  local _cred_rc=0
  fk_resolve_api_credentials || _cred_rc=$?
  if [ "$_cred_rc" -eq 1 ]; then
    local _model_hint="或 /flow model l2=<model> 配置持久化兜底"
    local _hint
    if fk_platform_is_dsh; then
      _hint="dsh 检测到：请用 subagent tool 派发 L2 盲审（description=L2 blind review，prompt 注入 L2-blind-review.md）；凭证请 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN；${_model_hint}"
    elif fk_platform_is_opencode; then
      _hint="opencode 检测到：子 agent 模型绑定走 category 路由，请用 category= 派发（如 unspecified-high）；凭证请 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN；${_model_hint}"
    else
      # 默认分支：claude code（生产可达主路径）+ opencode 备选
      _hint="claude code 检测到：请确认 ANTHROPIC_AUTH_TOKEN 已注入（env-var-first）；若当前为 opencode 环境，请用 category= 派发（如 unspecified-high）并 export FLOW_KIT_L3_BASE_URL + FLOW_KIT_L3_AUTH_TOKEN；${_model_hint}"
    fi
    echo "[l2-dispatch] no API credentials（ANTHROPIC_AUTH_TOKEN / FLOW_KIT_L3_AUTH_TOKEN / ANTHROPIC_API_KEY 全空）" >&2
    echo "[l2-dispatch] ${_hint}" >&2
    return 1
  fi
  if [ "$_cred_rc" -eq 2 ]; then
    # stderr 已由 fk_resolve_api_credentials 报 Path3 配置不完整（rc=2 语义，D1）
    return 1
  fi
  # rc=0：凭证就绪。读共享输出全局（AC-6 红线：凭证值绝不落盘，FK_API_* 仅内存使用）
  local auth_token="${FK_API_AUTH_TOKEN:-}"
  local base_url="${FK_API_BASE_URL:-}"
  local auth_scheme="${FK_API_AUTH_SCHEME:-bearer}"

  # ── 构造 L2 审查 prompt（与 L2-blind-review.md 一致的固化模板）──
  local prompt_text
  prompt_text=$(cat <<'L2_PROMPT_EOF'
# L2 独立盲审员 · 固化指令

你是独立审查员，对 flow-kit 阶段产物做盲审。判断必须独立、客观。

## 独立性硬约束
1. 只看指定工件，不假设外部陈述
2. 禁止证实偏差——证据优先于解释
3. 不主动假设作者意图

## 输出格式（四要素 + 严重度）
每个发现必须含：Symptom / Source / Consequence / Remedy
严重度：🔴 Critical / 🟡 Major / 🟢 Minor
报告末尾：**Verdict**: pass | fail

## 审查重点（阶段特定，由调用参数决定）
L2_PROMPT_EOF
)

  # 按阶段追加审查重点
  case "$phase" in
    1) prompt_text+=$'\n'"阶段 1 · 需求审查：AC 是否 Given/When/Then 齐全且可验证？v1/v2/out 切分合理？非功能需求是否遗漏？" ;;
    2) prompt_text+=$'\n'"阶段 2 · 设计审查：ADR 决策是否有备选+理由+代价？是否撞禁动清单？抽象层次是否得当？风险是否遗漏？" ;;
    3) prompt_text+=$'\n'"阶段 3 · 任务审查：单 task ≤200行？依赖图无环？verify 可机器执行？AC 全覆盖？write_files 禁动清单无越界？" ;;
    5) prompt_text+=$'\n'"阶段 5 · 测试审查：AC 覆盖率 100%？5 轮金字塔是否逐轮填写？UAT 可脚本化？回归全绿？" ;;
    6) prompt_text+=$'\n'"阶段 6 · 代码审查：spec 合规？代码质量 6 维衰退风险？主 agent REVIEW 漏判/误判？修代码优先？" ;;
    7) prompt_text+=$'\n'"阶段 7 · 集成审查：产物齐全？LESSONS 同步？CHANGELOG 更新？归档清洁？done 真实性？" ;;
  esac

  prompt_text+=$'\n'$'\n'"## 本次审查参数"$'\n'
  prompt_text+="- 阶段：${phase}"$'\n'
  prompt_text+="- change-id：${change_id}"$'\n'
  prompt_text+="- 工件目录：${specs_dir}"$'\n'
  prompt_text+="- 输出：追加写入 ${review_md} 的 L2 盲审段（禁止覆写已有 L3 段）"$'\n'

  # ── API 调用（异步后台进程）────────────────────────────────────
  # base_url / auth_token / auth_scheme 已在凭证段从 FK_API_* 解析（DESIGN D1）
  # 模型选择 — 三级优先级链（l2-l3-model-config ADR-012；移除既有 L2 fallback，纯跨平台）
  type write_model_missing_correction >/dev/null 2>&1 || { [ -f "${HOOK_BASE_DIR:-}/lib/correction-file.sh" ] && source "${HOOK_BASE_DIR:-}/lib/correction-file.sh"; }
  local model; model=$(fk_resolve_model "L2")
  if [[ -z "$model" ]]; then
    write_model_missing_correction "L2"
    echo "[l2-detect] L2 模型未配置（三级链全空）。设置：export FLOW_KIT_L2_MODEL=<模型> 或 /flow model l2=<模型>" >&2
    return 3   # API 调用之前 return（不发 dispatch）
  fi
  write_model_missing_clear "L2"   # 正常路径：清残留 model-missing（AC-6 退场）

  (
    local ai_response="" content="" http_code=0

    # 构造 JSON payload（jq --arg 防注入）
    local payload
    payload=$(jq -n \
      --arg m "$model" \
      --arg p "$prompt_text" \
      '{model:$m, max_tokens:4096, messages:[{role:"user", content:$p}]}' 2>/dev/null) || {
      echo "[l2-dispatch] jq payload construction failed" >&2
      exit 1
    }

    # API 调用 — 按共享解析的 scheme 区分（D1 约定：bearer | x-api-key）
    if [ -n "$auth_token" ]; then
      local _auth_header
      if [ "$auth_scheme" = "x-api-key" ]; then
        _auth_header="x-api-key: ${auth_token}"
      else
        _auth_header="Authorization: Bearer ${auth_token}"
      fi
      ai_response=$(curl -s -w '\n%{http_code}' --max-time 90 "${base_url}/v1/messages" \
        -H "$_auth_header" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null || true)
      http_code=$(echo "$ai_response" | tail -1)
      ai_response=$(echo "$ai_response" | sed '$d')
    fi

    # ── 解析响应 ─────────────────────────────────────────────────
    case "$http_code" in
      200) ;;
      *) echo "[l2-dispatch] API returned HTTP ${http_code}" >&2; exit 1 ;;
    esac

    content=$(echo "$ai_response" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].text // empty' 2>/dev/null || echo "")
    if [ -z "$content" ]; then
      echo "[l2-dispatch] API call succeeded but no content in response" >&2
      exit 1
    fi

    # ── 追加写入 INDEPENDENT-REVIEW（防 L3 覆写）─────────────────
    # ── 原子写入 L2 段（tmp + mv 防竞态，与 L3 一致）──
    local bg_tmp
    bg_tmp="$(mktemp "${review_md}.tmp.XXXXXX")"
    if [ -f "$review_md" ]; then
      cat "$review_md" > "$bg_tmp" 2>/dev/null || true
    fi
    # ADR-026 · 写入侧 fail-closed（设计 D7 的写入侧缺口 · 阶段 2 的 L3 critical ②）：
    # 转义函数不可用时必须**拒绝落盘**，绝不写未转义载荷。旧实现无条件直调，函数缺失
    # 时 `{ … } >> tmp` 会半途失败并把**未转义的头部与载荷**留在临时文件里——
    # 「静默损坏」换了个形态出现，仍然违反 AC-1 的 fail-closed 语义。
    if ! type _l3_escape_payload >/dev/null 2>&1; then
      echo "[l2-dispatch] CRITICAL: _l3_escape_payload 不可用（l3-section.sh 未加载）—— 拒绝写入未转义 L2 载荷（fail-closed · ADR-026）" >&2
      rm -f "$bg_tmp" 2>/dev/null || true
      exit 1
    fi
    {
      echo ""
      echo "---"
      echo "## L2 盲审"
      echo ""
      echo "> 审查日期：$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ) | 阶段：${phase} | change-id：${change_id} | 自动派发"
      echo ""
      # ADR-026：L2 载荷同样是**不可信内容**，必须转义（否则其中的行首 '## L3 …'
      # 会被判为 L3 段起点，导致本段正文在后续 L3 写入时被切除 —— 静默数据损坏）
      _l3_escape_payload "$content"
    } >> "$bg_tmp"
    mv "$bg_tmp" "$review_md" 2>/dev/null || {
      echo "[l2-dispatch] CRITICAL: atomic mv failed for ${review_md}" >&2
      exit 1
    }

    echo "[l2-dispatch] Agent completed, result written to ${review_md}" >&2
    exit 0
  ) 1>/dev/null 2>"${specs_dir}/.l2-dispatch-${phase}.log" & disown

  local bg_pid=$!
  if [ -n "$bg_pid" ] && kill -0 "$bg_pid" 2>/dev/null; then
    echo "[l2-dispatch] Agent dispatched for phase ${phase} (pid=${bg_pid})" >&2
    return 0
  else
    echo "[l2-dispatch] dispatch failed, see manual command above" >&2
    return 1
  fi
}