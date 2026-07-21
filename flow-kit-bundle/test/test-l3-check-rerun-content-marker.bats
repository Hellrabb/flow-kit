#!/usr/bin/env bats
# test-l3-check-rerun-content-marker.bats — AC-J: _l3_check_rerun 内容标记 + artifact hash（ADR-010 / D4·J）
#
# 覆盖 AC-J（mtime → 内容标记 + hash）：
#   - regex `^## L3 (盲审|重审)` 匹配真实段（前缀匹配 token · 回应 L3-task-R1 🔴）
#   - 首次（无 review_md）→ 重审 return 0
#   - ## L3 段 + hash 记录 == 当前 sha → skip return 2（touch 不触发）
#   - artifact 内容改（hash 变）→ 重审 return 0
#   - ## L3 段缺失 → 重审 return 0
#   - L3_artifact_hash 行缺失/提取失败 → 重审 return 0（保守）
#
# 关联：ADR-010 / REQUIREMENT AC-J / DESIGN D4

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  local d="$TEST_ROOT"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  REAL_PROJECT_ROOT="$d"
  L3_REVIEW="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop/lib/l3-review.sh"
  TMP_DIR="$BATS_TMPDIR/l3-rerun-test-$$"
  mkdir -p "$TMP_DIR/.specs/c"
}

teardown() {
  rm -rf "$TMP_DIR"
}

_load_l3() {
  # shellcheck source=/dev/null
  source "$L3_REVIEW" 2>/dev/null
}

# ══ regex 前缀匹配真实 token（回应 L3-task-R1：原 (盲审|外部模型审查)$ 零匹配）══

@test "AC-J: regex ^## L3 (盲审|重审) 匹配真实段（printf fixture · 重审/盲审/timeout）" {
  printf '## L3 重审（test · 2026）\n## L3 盲审（timeout · 2026）\n' | grep -qE '^## L3 (盲审|重审)'
}

# ══ _l3_check_rerun 判定 ══

@test "AC-J: 首次（无 review_md）→ 重审 return 0" {
  _load_l3
  rm -f "$TMP_DIR/.specs/c/INDEPENDENT-REVIEW-1.md"
  run _l3_check_rerun 1 "$TMP_DIR/.specs/c"
  [ "$status" -eq 0 ]
}

@test "AC-J: ## L3 段 + hash 记录 == 当前 sha → skip return 2（touch 不触发）" {
  _load_l3
  echo "requirement content" > "$TMP_DIR/.specs/c/REQUIREMENT.md"
  local sha
  sha=$(sha256sum "$TMP_DIR/.specs/c/REQUIREMENT.md" | awk '{print $1}')
  printf '## L3 盲审（glm-5.1 · 2026）\n\nverdict: pass\n\nL3_artifact_hash: %s\n' "$sha" \
    > "$TMP_DIR/.specs/c/INDEPENDENT-REVIEW-1.md"
  # touch artifact（mtime 变，内容/hash 不变）→ 仍 skip
  touch "$TMP_DIR/.specs/c/REQUIREMENT.md"
  run _l3_check_rerun 1 "$TMP_DIR/.specs/c"
  [ "$status" -eq 2 ]
}

@test "AC-J: artifact 内容改（hash 变）→ 重审 return 0" {
  _load_l3
  echo "old content" > "$TMP_DIR/.specs/c/REQUIREMENT.md"
  local sha
  sha=$(sha256sum "$TMP_DIR/.specs/c/REQUIREMENT.md" | awk '{print $1}')
  printf '## L3 重审（glm-5.1 · 2026）\n\nL3_artifact_hash: %s\n' "$sha" \
    > "$TMP_DIR/.specs/c/INDEPENDENT-REVIEW-1.md"
  echo "new changed content" > "$TMP_DIR/.specs/c/REQUIREMENT.md"  # 内容改 → hash 变
  run _l3_check_rerun 1 "$TMP_DIR/.specs/c"
  [ "$status" -eq 0 ]
}

@test "AC-J: ## L3 段缺失 → 重审 return 0" {
  _load_l3
  echo "req" > "$TMP_DIR/.specs/c/REQUIREMENT.md"
  local sha
  sha=$(sha256sum "$TMP_DIR/.specs/c/REQUIREMENT.md" | awk '{print $1}')
  printf 'some content without L3 section\n\nL3_artifact_hash: %s\n' "$sha" \
    > "$TMP_DIR/.specs/c/INDEPENDENT-REVIEW-1.md"
  run _l3_check_rerun 1 "$TMP_DIR/.specs/c"
  [ "$status" -eq 0 ]
}

@test "AC-J: L3_artifact_hash 行缺失 → 重审 return 0（保守降级）" {
  _load_l3
  echo "req" > "$TMP_DIR/.specs/c/REQUIREMENT.md"
  printf '## L3 盲审（glm-5.1 · 2026）\n\nverdict: pass\n' \
    > "$TMP_DIR/.specs/c/INDEPENDENT-REVIEW-1.md"
  run _l3_check_rerun 1 "$TMP_DIR/.specs/c"
  [ "$status" -eq 0 ]
}
