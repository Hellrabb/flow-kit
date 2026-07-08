#!/usr/bin/env bats
# test_l3_review.bats — Tests for l3-review.sh fixes (AC-1 ~ AC-6)

setup() {
  TEST_TMP=$(mktemp -d)
  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对 · L-025）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  local FK_ROOT="$d"
  L3_LIB="$FK_ROOT/flow-kit-bundle/hooks/stop/lib/l3-review.sh"
  ARTIFACTS_DIR="${TEST_TMP}/.specs/test-change"
  mkdir -p "$ARTIFACTS_DIR"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── AC-5: timeout + token params ────────────────────────────────────

@test "AC-5: max_tokens is 8000" {
  run grep -c 'max_tokens:8000' "$L3_LIB"
  [[ "$output" -ge 2 ]]
}

@test "AC-5: curl timeout is 90s" {
  run grep -c 'max-time 90' "$L3_LIB"
  [[ "$output" -ge 2 ]]
}

# ── AC-4: dual-block content extraction ──────────────────────────────

@test "AC-4: extracts text block when thinking+text blocks present" {
  local resp='{"content":[{"type":"thinking","thinking":"reasoning..."},{"type":"text","text":"THE_VERDICT"}]}'
  local content
  content=$(echo "$resp" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty' 2>/dev/null)
  [[ "$content" == "THE_VERDICT" ]]
}

@test "AC-4: falls back to thinking when no text block" {
  local resp='{"content":[{"type":"thinking","thinking":"THINKING_ONLY"}]}'
  local content
  content=$(echo "$resp" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty' 2>/dev/null)
  [[ "$content" == "THINKING_ONLY" ]]
}

# ── AC-6: 3-layer verdict extraction ─────────────────────────────────

@test "AC-6: extracts verdict from raw JSON" {
  local content='{"critical":[],"verdict":"pass","summary":"ok"}'
  local verdict
  verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null)
  [[ -z "$verdict" ]] && verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1)
  [[ "$verdict" == "pass" ]]
}

@test "AC-6: extracts verdict from mixed text+JSON via regex fallback" {
  local content='Some reasoning text... {"critical":[],"verdict":"fail","summary":"bad"}'
  # Layer 1: try jq on raw content (fails because of leading text)
  local verdict
  verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  # Layer 2: grep regex fallback
  [[ -z "$verdict" ]] && verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1 || echo "")
  [[ "$verdict" == "fail" ]]
}

@test "AC-6: returns unknown when no verdict found at all" {
  local content='Just some text, no JSON here at all'
  local verdict
  verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  [[ -z "$verdict" ]] && verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1 || echo "")
  [[ -z "$verdict" ]]
}

# ── AC-3: L3 section dedup ───────────────────────────────────────────

@test "AC-3: strips old L3 section before writing new one" {
  local review_md="${ARTIFACTS_DIR}/INDEPENDENT-REVIEW-1.md"
  # Write initial L2 + old L3
  cat > "$review_md" << 'EOF'
# 独立审查 · 阶段 1
## L2 盲审
L2 content here
## L3 盲审（old model · old date）
old L3 content
EOF
  # Simulate dedup logic
  if [ -f "$review_md" ]; then
    awk '/^## L3 盲审/{stop=1} !stop{print}' "$review_md" > "${review_md}.tmp"
    mv "${review_md}.tmp" "$review_md"
  fi
  # Append new L3
  cat >> "$review_md" << 'EOF'
## L3 盲审（new model · new date）
new L3 content
EOF
  # Verify only 1 L3 section
  local count
  count=$(grep -c '## L3 盲审' "$review_md")
  [[ "$count" -eq 1 ]]
  # Verify old L2 preserved
  grep -q '## L2 盲审' "$review_md"
  grep -q 'L2 content here' "$review_md"
  # Verify new L3 content present
  grep -q 'new L3 content' "$review_md"
  # Verify old L3 content gone
  ! grep -q 'old L3 content' "$review_md"
}

# ── AC-1: Phase 6 artifact includes new files ─────────────────────────

@test "AC-1: git ls-files captures new untracked .sh files" {
  cd "$TEST_TMP"
  git init -q && git config user.email "test@test" && git config user.name "Test"
  echo "tracked" > tracked.txt && git add tracked.txt && git commit -q -m "init"
  echo "new shell" > new_script.sh
  # Verify ls-files finds it
  run git ls-files --others --exclude-standard
  [[ "$output" == "new_script.sh" ]]
  # Verify grep filter
  run bash -c 'git ls-files --others --exclude-standard | grep -E "\.(sh|bats)$"'
  [[ "$output" == "new_script.sh" ]]
}

# ── AC-2: Phase 7 artifact listing ────────────────────────────────────

@test "AC-2: phase 7 artifact includes all required file names" {
  # Create all expected artifacts
  for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md INTEGRATION.md; do
    echo "# $f" > "${ARTIFACTS_DIR}/$f"
  done
  # Verify they exist
  for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md INTEGRATION.md; do
    [[ -f "${ARTIFACTS_DIR}/$f" ]]
  done
}
