# l3-truncate.sh — L3 重审检测/跳过逻辑（分拆自 l3-review.sh）
#
# 来源: split from l3-review.sh
# change: final-debt-cleanup-2026-08
# date: 2026-08-03
#
# 函数:
#   _l3_check_rerun — 重审检测（hash 标记 + ## L3 段检测）

# ── _l3_check_rerun() · 重审检测：比较工件 hash 与记录 hash ──
# 用法: _l3_check_rerun <phase> <artifacts_dir>
# 返回: 0=需重审(工件更新或首次), 2=跳过(工件未变)
_l3_check_rerun() {
  local phase="$1" artifacts_dir="$2"
  local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
  [ -f "$review_md" ] || return 0  # 无现有审查 → 首次运行

  # ADR-010 D4·J：判定基从 mtime 改内容标记（## L3 段 regex + artifact hash）。
  # 判定优先级：hash 变→重审 / ## L3 段缺失或空→重审 / hash 提取失败→重审+警告 / 否则 skip。
  # ① ## L3 段检测（^## L3 (盲审|重审) 前缀匹配真实 token · 与 _l3_parse_result section_title 一致）
  if ! grep -qE '^## L3 (盲审|重审)' "$review_md" 2>/dev/null; then
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
