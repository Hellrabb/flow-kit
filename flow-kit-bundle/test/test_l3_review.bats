#!/usr/bin/env bats
# test_l3_review.bats — Tests for l3-review.sh（既有：fallback/dedup/artifact · AC-1~AC-6 旧编号重命名为 legacy 避与本 change 碰撞）
# l3-review-timeout-token change 的 AC-1~AC-7（env var 可配）测试在 test_l3_review_params.bats

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

# ── l3-review-timeout-token: 旧硬编码断言已删（max_tokens:8000 / --max-time 90 被 T02 删除）──
# 原 AC-5 "max_tokens is 8000" / "curl timeout is 90s" 已删——T02 改为 env var 可配，
# 新断言在 test_l3_review_params.bats（AC-1~AC-7 stub curl 双路径）

# ── fallback 行为（AC-10 关联 · _l3_parse_result 的 content 提取 · 不改 fallback · Out of Scope）───

@test "fallback: extracts text block when thinking+text blocks present" {
  local resp='{"content":[{"type":"thinking","thinking":"reasoning..."},{"type":"text","text":"THE_VERDICT"}]}'
  local content
  content=$(echo "$resp" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty' 2>/dev/null)
  [[ "$content" == "THE_VERDICT" ]]
}

@test "fallback: falls back to thinking when no text block (AC-10 静默错判行为 · 记录非修复)" {
  # 本测试记录 fallback 链的静默错判行为（思考吃满无 text block 时取思考内容当 verdict）
  # l3-review-timeout-token change 不修 fallback（Out of Scope），仅记录行为
  local resp='{"content":[{"type":"thinking","thinking":"THINKING_ONLY"}]}'
  local content
  content=$(echo "$resp" | jq -r '[.content[] | select(.type == "text") | .text][0] // .content[0].thinking // .content[0].text // empty' 2>/dev/null)
  [[ "$content" == "THINKING_ONLY" ]]
}

# ── 3-layer verdict extraction（l3-comprehensive-fix 遗产 · 与本 change 无关）─────────

@test "verdict-extract: extracts verdict from raw JSON" {
  local content='{"critical":[],"verdict":"pass","summary":"ok"}'
  local verdict
  verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null)
  [[ -z "$verdict" ]] && verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1)
  [[ "$verdict" == "pass" ]]
}

@test "verdict-extract: extracts verdict from mixed text+JSON via regex fallback" {
  local content='Some reasoning text... {"critical":[],"verdict":"fail","summary":"bad"}'
  local verdict
  verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  [[ -z "$verdict" ]] && verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1 || echo "")
  [[ "$verdict" == "fail" ]]
}

@test "verdict-extract: returns unknown when no verdict found at all" {
  local content='Just some text, no JSON here at all'
  local verdict
  verdict=$(echo "$content" | jq -r '.verdict // ""' 2>/dev/null || echo "")
  [[ -z "$verdict" ]] && verdict=$(echo "$content" | grep -oP '"verdict"\s*:\s*"\K(pass|fail)(?=")' 2>/dev/null | tail -1 || echo "")
  [[ -z "$verdict" ]]
}

# ── L3 section dedup（l3-comprehensive-fix 遗产 · 与本 change 无关）──────────────────

@test "dedup: strips old L3 sections (盲审 + 重审) before writing new one" {
  local review_md="${ARTIFACTS_DIR}/INDEPENDENT-REVIEW-1.md"
  cat > "$review_md" << 'EOF'
# 独立审查 · 阶段 1
## L2 盲审
L2 content here

## L3 盲审（first model · old date）
old L3 content

## L3 重审（second model · older date）
old L3 re-review content
EOF

  if [ -f "$review_md" ]; then
    awk '/^## L3 (盲审|重审)/ { skip=1; next } /^## / && skip { skip=0 } !skip' "$review_md" > "${review_md}.tmp"
    mv "${review_md}.tmp" "$review_md"
  fi

  cat >> "$review_md" << 'EOF'
## L3 盲审（new model · new date）
new L3 content
EOF

  local count
  count=$(grep -c '^## L3 \(盲审\|重审\)' "$review_md")
  [[ "$count" -eq 1 ]]

  grep -q '## L2 盲审' "$review_md"
  grep -q 'L2 content here' "$review_md"
  grep -q 'new L3 content' "$review_md"
  ! grep -q 'old L3 content' "$review_md"
  ! grep -q 'old L3 re-review content' "$review_md"
  grep -q '^## L3 盲审' "$review_md"
  grep -qE '^## L3 (盲审|重审)' "$review_md"
}

# ── legacy artifact tests（l3-pipeline-fix 遗产 · 编号重命名避碰撞 · 与本 change 无关）──

@test "legacy-1: git ls-files captures new untracked .sh files" {
  cd "$TEST_TMP"
  git init -q && git config user.email "test@test" && git config user.name "Test"
  echo "tracked" > tracked.txt && git add tracked.txt && git commit -q -m "init"
  echo "new shell" > new_script.sh
  run git ls-files --others --exclude-standard
  [[ "$output" == "new_script.sh" ]]
  run bash -c 'git ls-files --others --exclude-standard | grep -E "\.(sh|bats)$"'
  [[ "$output" == "new_script.sh" ]]
}

@test "legacy-2: phase 7 artifact includes all required file names" {
  for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md INTEGRATION.md; do
    echo "# $f" > "${ARTIFACTS_DIR}/$f"
  done
  for f in CHANGE.md REQUIREMENT.md DESIGN.md TASK.md TEST.md REVIEW.md INTEGRATION.md; do
    [[ -f "${ARTIFACTS_DIR}/$f" ]]
  done
}
