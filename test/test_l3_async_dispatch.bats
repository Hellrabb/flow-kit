#!/usr/bin/env bats
# test_l3_async_dispatch.bats — L3 异步派发测试
#
# 覆盖 AC-2/AC-3/AC-4

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/.."
  L3_LIB="${TEST_ROOT}/hooks/stop/lib/l3-review.sh"

  if [ ! -f "$L3_LIB" ]; then
    skip "l3-review.sh not found"
  fi

  source "$L3_LIB"

  TMPDIR=$(mktemp -d)
  SPECS_DIR="${TMPDIR}/.specs/test-change"
  mkdir -p "$SPECS_DIR"
}

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════
# AC-4: l3_dispatch_prompt() 输出格式
# ══════════════════════════════════════════════════════════════

@test "AC-4a: l3_dispatch_prompt outputs box header with phase and gate_val" {
  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"L3 外部模型审查未完成"* ]]
  [[ "$output" == *"阶段 6"* ]]
  [[ "$output" == *"gate_config=both"* ]]
}

@test "AC-4b: l3_dispatch_prompt includes sub-agent dispatch command" {
  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent({"* ]]
  [[ "$output" == *"subagent_type"* ]]
  [[ "$output" == *"l3_review_run"* ]]
}

@test "AC-4c: l3_dispatch_prompt includes manual bash fallback" {
  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"方式 2"* ]]
  [[ "$output" == *"source flow-kit-bundle/hooks/stop/lib/l3-review.sh"* ]]
}

@test "AC-4d: l3_dispatch_prompt includes parameter summary" {
  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"phase=6"* ]]
  [[ "$output" == *"change_id=test-change"* ]]
  [[ "$output" == *"L2_verdict="* ]]
}

@test "AC-4e: l3_dispatch_prompt gate_val=L3 gives L2_verdict=skipped" {
  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" L3
  [ "$status" -eq 0 ]
  [[ "$output" == *"L2_verdict=skipped"* ]]
}

# ══════════════════════════════════════════════════════════════
# 边界测试
# ══════════════════════════════════════════════════════════════

@test "AC-4f: l3_dispatch_prompt rejects invalid phase" {
  run l3_dispatch_prompt 0 test-change "${SPECS_DIR}" both
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid phase"* ]]
}

@test "AC-4g: l3_dispatch_prompt rejects empty change_id" {
  run l3_dispatch_prompt 6 "" "${SPECS_DIR}" both
  [ "$status" -eq 2 ]
}

@test "AC-4h: l3_dispatch_prompt gate_val=both extracts L2 verdict from review_md" {
  # Write a mock review_md with L2 verdict=pass
  local review_md="${SPECS_DIR}/INDEPENDENT-REVIEW-6.md"
  mkdir -p "$(dirname "$review_md")"
  cat > "$review_md" <<'REVIEW_EOF'
## L2 盲审（claude-sonnet-5 · 2026-07-07）

### 审查结论
verdict: pass

L2 review completed successfully.
REVIEW_EOF

  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"L2_verdict=pass"* ]]
}

@test "AC-4i: artifacts description varies by phase" {
  # Phase 1: REQUIREMENT
  run l3_dispatch_prompt 1 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"REQUIREMENT.md"* ]]

  # Phase 6: REVIEW + git diff
  run l3_dispatch_prompt 6 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"REVIEW.md"* ]]
  [[ "$output" == *"git diff"* ]]

  # Phase 7: 全量
  run l3_dispatch_prompt 7 test-change "${SPECS_DIR}" both
  [ "$status" -eq 0 ]
  [[ "$output" == *"全量产物"* ]]
}
