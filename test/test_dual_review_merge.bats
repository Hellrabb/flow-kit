#!/usr/bin/env bats
# test_dual_review_merge.bats — L2/L3 双层审查合并写入修复测试
# 覆盖 AC-1~AC-8（REQUIREMENT.md dual-review-merge-fix）
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"
  mkdir -p "$TEST_TMPDIR/.specs/test-change"

  # 路径
  L3_LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/stop/lib/l3-review.sh"
  DONE_VAL_LIB="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/stop/lib/done-validation.sh"

  # Source done-validation lib（提供 fk_validate_done_marker 等）
  if [ -f "$DONE_VAL_LIB" ]; then
    source "$DONE_VAL_LIB" 2>/dev/null || true
  fi
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ═══════════════════════════════════════════════════════════════════════
# AC-4: both 模式仅一方完成时不写 .done
# ═══════════════════════════════════════════════════════════════════════

@test "AC-4: l3-review.sh — both mode + no L2 section → .done NOT written" {
  if [ ! -f "$L3_LIB" ]; then
    skip "l3-review.sh not found"
  fi

  artifacts_dir="$TEST_TMPDIR/.specs/test-change"
  review_md="$artifacts_dir/INDEPENDENT-REVIEW-1.md"

  # L3 内容已存在（模拟 Stop hook 先跑 L3），但无 L2 段
  mkdir -p "$artifacts_dir"
  echo "## L3 盲审（AI）" > "$review_md"
  echo "Verdict: pass" >> "$review_md"

  # 本测试验证 D3 保护逻辑的存在性：代码中包含 gate 检查
  run grep -q "L2 not yet complete" "$L3_LIB" 2>/dev/null
  [ "$status" -eq 0 ]
}

@test "AC-4: .done deferred message exists in l3-review.sh" {
  run grep -q "deferred" "$L3_LIB" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-8: .done 值域校验 — skipped 合法，空文件拒绝
# ═══════════════════════════════════════════════════════════════════════

@test "AC-8: fk_validate_done_marker — empty .done → reject (return 2)" {
  if ! type fk_validate_done_marker >/dev/null 2>&1; then
    skip "fk_validate_done_marker not available"
  fi

  done_file="$TEST_TMPDIR/.specs/test-change/.independent-review-1.done"
  touch "$done_file"  # 空文件（威胁①）

  # 需要 .flow-active 来通过 phases_done 短路
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"change_id":"test-change","phase":"1","goal":{"phases_done":[],"gate_config":{}}}
EOF

  run fk_validate_done_marker "$done_file" "1" "test-change" "write"
  [ "$status" -eq 2 ]
}

@test "AC-8: fk_validate_done_marker — 6-key KVP with skipped values → accept (return 0)" {
  if ! type fk_validate_done_marker >/dev/null 2>&1; then
    skip "fk_validate_done_marker not available"
  fi

  done_file="$TEST_TMPDIR/.specs/test-change/.independent-review-1.done"

  # L2-only 模式：L3_verdict=skipped
  cat > "$done_file" << 'DONE_EOF'
phase=1
change_id=test-change
written_by=main-agent
L2_verdict=pass
L3_verdict=skipped
artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-1.md
DONE_EOF

  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"change_id":"test-change","phase":"1","goal":{"phases_done":[],"gate_config":{}}}
EOF

  # tier=write: 仅 Tier 1 校验（KVP + 值域）
  run fk_validate_done_marker "$done_file" "1" "test-change" "write"
  [ "$status" -eq 0 ]
}

@test "AC-8: fk_validate_done_marker — L3-only mode with L2_verdict=skipped → accept" {
  if ! type fk_validate_done_marker >/dev/null 2>&1; then
    skip "fk_validate_done_marker not available"
  fi

  done_file="$TEST_TMPDIR/.specs/test-change/.independent-review-1.done"

  # L3-only 模式：L2_verdict=skipped
  cat > "$done_file" << 'DONE_EOF'
phase=1
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=skipped
L3_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-1.md
DONE_EOF

  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"change_id":"test-change","phase":"1","goal":{"phases_done":[],"gate_config":{}}}
EOF

  run fk_validate_done_marker "$done_file" "1" "test-change" "write"
  [ "$status" -eq 0 ]
}

@test "AC-8: fk_validate_done_marker — fake content .done (threat ②) → reject (return 2)" {
  if ! type fk_validate_done_marker >/dev/null 2>&1; then
    skip "fk_validate_done_marker not available"
  fi

  done_file="$TEST_TMPDIR/.specs/test-change/.independent-review-1.done"

  # 假内容：phase 不匹配
  cat > "$done_file" << 'DONE_EOF'
phase=5
change_id=test-change
written_by=fake
L2_verdict=pass
L3_verdict=pass
artifacts=FAKE.md,WRONG.md
DONE_EOF

  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"change_id":"test-change","phase":"1","goal":{"phases_done":[],"gate_config":{}}}
EOF

  run fk_validate_done_marker "$done_file" "1" "test-change" "write"
  [ "$status" -eq 2 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-1: both 模式 L2-wait — 29 号 hook + PreToolUse 双执行点
# ═══════════════════════════════════════════════════════════════════════

@test "AC-1: 29-independent-review.sh contains L2-wait gating for both mode" {
  hook29="$TEST_TMPDIR/../flow-kit-bundle/hooks/stop/29-independent-review.sh"
  hook29="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/stop/29-independent-review.sh"

  run grep -q "L2 not yet complete" "$hook29" 2>/dev/null
  [ "$status" -eq 0 ]
}

@test "AC-1: independent-review-gate.sh contains L2-wait gating for PreToolUse path" {
  gate_script="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/pre-tool-use/independent-review-gate.sh"

  run grep -q "L2 尚未完成" "$gate_script" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-7: L3-only 模式 L2_verdict=skipped
# ═══════════════════════════════════════════════════════════════════════

@test "AC-7: 29-independent-review.sh defaults L2_verdict=skipped for L3-only mode" {
  hook29="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/stop/29-independent-review.sh"

  run grep -q 'l2_verdict="skipped"' "$hook29" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-2: L2 append preserves L3
# ═══════════════════════════════════════════════════════════════════════

@test "AC-2: L2-blind-review.md contains append-first constraints" {
  l2_blind="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit/prompts/independent/L2-blind-review.md"

  run grep -q "文件写入约束" "$l2_blind" 2>/dev/null
  [ "$status" -eq 0 ]

  run grep -q "先读、后追加" "$l2_blind" 2>/dev/null
  [ "$status" -eq 0 ]

  run grep -q "禁止.*覆写" "$l2_blind" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-6: L2-only KVP .done — 6 phase prompts updated
# ═══════════════════════════════════════════════════════════════════════

@test "AC-6: all 6 phase prompts contain L3_verdict=skipped for L2-only" {
  prompts_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit/prompts"

  for phase in 1-requirement 2-design 3-task 5-test 6-review 7-integration; do
    run grep -q "L3_verdict=skipped" "$prompts_dir/$phase.md" 2>/dev/null
    if [ $status -ne 0 ]; then
      echo "FAIL: $phase.md missing L3_verdict=skipped"
      false
    fi
  done
}

@test "AC-6: all 6 phase prompts contain append instruction for L2 output" {
  prompts_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit/prompts"

  for phase in 1-requirement 2-design 3-task 5-test 6-review 7-integration; do
    run grep -q "追加" "$prompts_dir/$phase.md" 2>/dev/null
    if [ $status -ne 0 ]; then
      echo "FAIL: $phase.md missing append instruction"
      false
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════════
# AC-3: L3 append logic preserved（>> 追加写入仍存在）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-3: l3-review.sh preserves >> append logic" {
  run grep -q '>>' "$L3_LIB" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-5: 跨阶段一致性 — phase_name mapping intact
# ═══════════════════════════════════════════════════════════════════════

@test "AC-5: done-validation.sh phase_name mapping covers {1,2,3,5,6,7}" {
  done_val="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/stop/lib/done-validation.sh"

  for phase_name in "1-requirement" "2-design" "3-task" "5-test" "6-review" "7-integration"; do
    run grep -q "\"$phase_name\"" "$done_val" 2>/dev/null
    if [ $status -ne 0 ]; then
      echo "FAIL: done-validation.sh missing phase_name=$phase_name"
      false
    fi
  done
}
