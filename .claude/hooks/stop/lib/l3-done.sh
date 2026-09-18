# shellcheck shell=bash
# l3-done.sh — L3 .done 写入 + 超时降级（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 函数:
#   _l3_write_done        — Step 4: .done 文件写入（含 D3 both 检查）
#   l3_invalidate_done    — 非 pass 时撤销陈旧 .done 锚点（M32）
#   l3_write_timeout_done — 超时降级: 追加 timeout 段到 review 文件（不写 .done）
#   l3_write_bypass_done  — 熔断降级: 追加 bypass 段 + 写 .done（L3_verdict=skipped）
#
# §B2 契约：本文件两个「追加 L3 段」的函数必须在段尾写 L3 段结束标记。
# 标记字面量与 _l3_l3_marker() 唯一定义在 l3-section.sh（改字面量只需改那一处）；
# 调用链（l3-review.sh）已 source，独立 source 场景（bats 直调本文件）按同目录兜底。
type _l3_l3_marker >/dev/null 2>&1 || {
  _L3D_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
  [ -n "${_L3D_DIR:-}" ] && [ -f "${_L3D_DIR}/l3-section.sh" ] && source "${_L3D_DIR}/l3-section.sh"
  unset _L3D_DIR
}

# ── _l3_write_done() · Step 4: .done 文件写入（含 D3 both 检查 · 遵守 ARCHITECTURE.md §4.1 6键KVP）──
# 用法: _l3_write_done <phase> <change_id> <verdict> <summary> <l2_verdict> <artifacts_dir> <gate_config_value>
# 返回: 0=done 已写, 1=verdict 非 pass 不写, 3=写入失败
_l3_write_done() {
  local phase="$1" change_id="$2" verdict="$3" summary="$4"
  local l2_verdict="$5" artifacts_dir="$6" gate_config_value="$7"

  # D3: gate_config="both" 且 L2 段不存在 → 跳过 .done 写入
  if [[ "$gate_config_value" == "both" ]]; then
    local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
    if [ ! -f "$review_md" ] || ! grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
      echo "[l3-review] L3 content appended but .done deferred (L2 not yet complete, gate_config=both)" >&2
      return 0
    fi
  fi

  # 防御：L3 内容持久化验证（原子写入后二次确认）
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  if [ ! -f "$review_md" ] || ! _l3_has_section "$review_md"; then
    echo "[l3-review] .done deferred: L3 content not found in ${review_md} (write may have failed)" >&2
    return 3
  fi

  # .done 仅 pass 时写入 (fix-l3-gate AC-2/AC-3)
  if [ "$verdict" != "pass" ]; then
    echo "[l3-review] L3 verdict=${verdict} — .done NOT written (phase ${phase})" >&2
    return 1
  fi

  # 结构确定损坏 ⇒ 拒绝发凭证（阶段 2 的 L3 21:10 major②）：结构自检本身是非阻塞的（D14），
  # 但「非阻塞」= 不阻断流程，不等于「损坏的文件也能拿到 pass 凭证」—— 段尾缺标记的文件正是
  # 下一次写入会静默删正文的形态，给它发凭证会放大损害。
  if type _l3_verify_review_structure >/dev/null 2>&1; then
    if ! _l3_verify_review_structure "$review_md" 2>/dev/null; then
      echo "[l3-review] deferred: 评审文件结构自检未通过（见 stderr）—— 拒绝在损坏工件上写锚点" >&2
      return 1
    fi
  fi

  local done_marker="${artifacts_dir}/.independent-review-${phase}.done"
  local done_tmp="${done_marker}.tmp"
  local written_by="pre-tool-use-gate"

  # 构造 artifacts 字段 (阶段产物文件列表)
  local artifacts_list=""
  case "$phase" in
    1) artifacts_list="REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    2) artifacts_list="DESIGN.md,REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    3) artifacts_list="TASK.md,DESIGN.md,REQUIREMENT.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    5) artifacts_list="TEST.md,TASK.md,REQUIREMENT.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    6) artifacts_list="REVIEW.md,TASK.md,TEST.md,INDEPENDENT-REVIEW-${phase}.md" ;;
    7) artifacts_list="REVIEW.md,TEST.md,TASK.md,DESIGN.md,REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md" ;;
  esac

  # 6 键 KVP 格式（遵守 ARCHITECTURE.md §4.1 跨模块契约）
  cat > "$done_tmp" <<DONE_EOF
phase=${phase}
change_id=${change_id}
written_by=${written_by}
L2_verdict=${l2_verdict}
L3_verdict=${verdict}
L3_summary=${summary}
artifacts=${artifacts_list}
DONE_EOF

  mv "$done_tmp" "$done_marker" 2>/dev/null || {
    echo "[l3-review] failed to write .done marker" >&2
    return 3
  }
  echo "[l3-review] L3 pass — .done written (phase ${phase}, verdict=${verdict})" >&2
  return 0
}

# ── l3_invalidate_done() · 非 pass 时撤销陈旧锚点（M32 · 2026-09-18）──
# 用法: l3_invalidate_done <phase> <artifacts_dir>
# 返回: 恒 0（撤销失败不阻断，但要能被观测到）
#
# 为什么必须撤销：`.done` 是**门禁的唯一凭证**（gate-checks-review / done-validation 只
# 看它存在与否）。旧实现只在 pass 时写、non-pass 时「什么都不做」，于是存在这样一条
# 静默通道：某一轮在**不完整输入**下判 pass 并写下 .done → 输入修好后重审判 fail →
# 旧锚点仍在 → 门禁继续放行。本项目 phase 1 实测已发生过（`1→2` gate 被置 passed，
# 而当时最新的 L3 结论是 fail）。
#
# 语义边界：撤销只在**拿到 verdict 且非 pass** 时发生（调用点 = l3-review.sh 的
# `_write_rc=1` 分支）。timeout 不撤销——超时不携带「当前状态不通过」的信息，
# 拿它去销毁一个已挣得的 pass 锚点是另一种错误。
l3_invalidate_done() {
  local phase="$1" artifacts_dir="$2"
  local done_marker="${artifacts_dir}/.independent-review-${phase}.done"
  [ -f "$done_marker" ] || return 0
  if rm -f "$done_marker" 2>/dev/null && [ ! -f "$done_marker" ]; then
    echo "[l3-review] stale .done removed (phase ${phase}) — 上一轮 pass 的锚点在新一轮 non-pass 后失效" >&2
    return 0
  fi
  # 删除失败 / 删除后仍在 → **不能只 WARN**（04:18 critical②）：陈旧凭证会被门禁按存在性放行。
  # 再试一次并显式复核；仍失败则打印 CRITICAL 并返回非零，调用方据此落 correction。
  rm -f "$done_marker" 2>/dev/null || true
  if [ -f "$done_marker" ]; then
    echo "[l3-review] CRITICAL: 陈旧凭证无法撤销（phase ${phase}）: ${done_marker} —— 门禁可能按存在性放行，请人工处理或跑 /flow doctor" >&2
    return 1
  fi
  echo "[l3-review] stale .done removed (phase ${phase})（第二次尝试成功）" >&2
  return 0
}

# ── l3_write_timeout_done() · 超时降级: 追加 timeout 段到 review 文件（不写 .done · fix-l3-gate AC-2）──
l3_write_timeout_done() {
  local phase="$1"
  local change_id="$2"
  local artifacts_dir="$3"
  local l2_verdict="$4"

  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")

  mkdir -p "$artifacts_dir"
  {
    echo ""
    echo "---"
    echo ""
    echo "## L3 盲审（timeout · ${ts}）"
    echo ""
    echo "> L3 审查超时（30s），降级为 timeout。"
    echo "> 不写 .done——pipeline 暂停等待人工处理或重试。"
    echo "> 后续 session 可通过 Stop hook 29 号模块补跑 L3。"
    echo ""
    _l3_l3_marker
  } >> "$review_md"

  echo "[l3-review] timeout notice appended (phase ${phase}) — .done NOT written" >&2
}

# ── l3_write_bypass_done() · 熔断降级: 追加 bypass 段到 review 文件 + 写 .done（L3_verdict=skipped）──
# P0-1 修复（2026-09-11）：max_failures_before_bypass 此前被读取但全文零引用，
# L3 不通过就永不写 .done，导致"修一轮→工件 hash 变→重审→再 fail"的无界循环。
# 本函数给出有界出口：连续 N 次 fail 后按 ADR-005 降级路径结案，并留全审计痕迹。
# 用法: l3_write_bypass_done <phase> <change_id> <artifacts_dir> <l2_verdict> <gate_config_value> <max_fail>
# 返回: 0=已写 .done, 3=写入失败
l3_write_bypass_done() {
  local phase="$1" change_id="$2" artifacts_dir="$3"
  local l2_verdict="$4" gate_config_value="$5" max_fail="$6"

  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "")

  mkdir -p "$artifacts_dir"
  {
    echo ""
    echo "---"
    echo ""
    echo "## L3 重审（bypass · ${ts}）"
    echo ""
    echo "> **熔断触发**：本阶段外部模型 L3 已连续 ${max_fail} 次返回 fail 且未收敛"
    echo "> （阈值来源：stop-hook.json 的 independent_review.max_failures_before_bypass）。"
    echo "> 按 ADR-005 降级路径结案：写入 .done 且 L3_verdict=skipped，pipeline 继续推进。"
    echo "> 本段即审计痕迹——不伪装 L3 pass，人工可据此复核。"
    echo "> 清理计数：删除 \`.l3-attempts-${phase}\` 即可重新尝试 L3。"
    echo ""
    _l3_l3_marker
  } >> "$review_md"

  # D3 一致性：gate_config=both 时 L2 段仍需存在（与 _l3_write_done 同契约）
  if [[ "$gate_config_value" == "both" ]]; then
    if [ ! -f "$review_md" ] || ! grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
      echo "[l3-review] bypass .done deferred (L2 not yet complete, gate_config=both)" >&2
      return 0
    fi
  fi

  local done_marker="${artifacts_dir}/.independent-review-${phase}.done"
  local done_tmp="${done_marker}.tmp"
  cat > "$done_tmp" <<DONE_EOF
phase=${phase}
change_id=${change_id}
written_by=l3-bypass
L2_verdict=${l2_verdict}
L3_verdict=skipped
L3_summary=熔断降级：外部模型 L3 连续 ${max_fail} 次 fail 未收敛（ADR-005 路径，见 INDEPENDENT-REVIEW-${phase}.md 的 bypass 段）
artifacts=INDEPENDENT-REVIEW-${phase}.md
DONE_EOF

  mv "$done_tmp" "$done_marker" 2>/dev/null || {
    echo "[l3-review] failed to write bypass .done marker" >&2
    return 3
  }
  return 0
}
