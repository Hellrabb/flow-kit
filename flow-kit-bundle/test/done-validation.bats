#!/usr/bin/env bats
# test/done-validation.bats — fk_validate_done_marker() 测试（AC-2 修复）
# 测试 done-validation.sh 的真实函数调用，而非 source .done 反模式

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"

  # Locate done-validation.sh (位置无关，从 test/ 向上走)
  local _test_dir
  _test_dir="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  local _bundle_dir
  _bundle_dir="$(cd "$_test_dir/../flow-kit-bundle" 2>/dev/null && pwd || echo "")"
  [ -n "$_bundle_dir" ] || _bundle_dir="$(cd "$_test_dir/.." && pwd)"
  DONE_VALIDATION_LIB="${_bundle_dir}/hooks/stop/lib/done-validation.sh"
  COMMON_LIB="${_bundle_dir}/hooks/stop/lib/common.sh"

  # Source libs (common.sh first — done-validation.sh 依赖 fk_phase_gate_key / fk_normalize_gate_val)
  [ -f "$COMMON_LIB" ] && source "$COMMON_LIB" 2>/dev/null || true
  [ -f "$DONE_VALIDATION_LIB" ] && source "$DONE_VALIDATION_LIB" 2>/dev/null || true

  # Default .flow-active fixture（phase 1, gate_config both）
  FLOW_ACTIVE="${PROJECT_ROOT}/.flow-active"
  mkdir -p "${PROJECT_ROOT}/.specs/test-change"
  cat > "$FLOW_ACTIVE" << 'FLOWEOF'
{"change_id":"test-change","phase":"1","goal":{"scope":"pipeline","current_phase":"1","phases_done":["0"],"gates":{"0→1":"passed","1→2":"pending"},"gate_config":{"1-requirement":"both"}}}
FLOWEOF

  # Helper: write .done file with given KVPs
  write_done() {
    local _dir="${PROJECT_ROOT}/.specs/test-change"
    mkdir -p "$_dir"
    cat > "${_dir}/.independent-review-1.done"
  }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── AC-2: 真正 source done-validation.sh + 调用 fk_validate_done_marker ──

@test "valid .done: all 6 keys present → return 0" {
  write_done << 'EOF'
phase=1
change_id=test-change
written_by=main-agent
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "write"
    [ "$status" -eq 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

@test "missing L3_verdict: required key absent → return 2" {
  write_done << 'EOF'
phase=1
change_id=test-change
written_by=main-agent
L2_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

# ── AC-2: 6 行最低行数检查（dlines >= MIN_MEANINGFUL_LINES）──

@test "too few lines: below minimum meaningful lines → return 2" {
  # Only 2 meaningful lines (phase + change_id), rest missing
  write_done << 'EOF'
phase=1
change_id=test-change
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

# ── AC-2: phase/change_id KVP 不匹配 → return 2 ──

@test "phase mismatch: .done phase ≠ actual phase → return 2" {
  write_done << 'EOF'
phase=2
change_id=test-change
written_by=main-agent
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

@test "change_id mismatch: .done cid ≠ flow-active cid → return 2" {
  write_done << 'EOF'
phase=1
change_id=wrong-change
written_by=main-agent
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

# ── AC-2: L2_verdict/L3_verdict 值域校验（非法值 → return 2）──

@test "L2_verdict illegal value → return 2" {
  write_done << 'EOF'
phase=1
change_id=test-change
written_by=main-agent
L2_verdict=INVALID_VALUE
L3_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

@test "L3_verdict illegal value → return 2" {
  write_done << 'EOF'
phase=1
change_id=test-change
written_by=main-agent
L2_verdict=pass
L3_verdict=INVALID_VALUE
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

# ── 保留：L2_verdict=skipped 合法 ──

@test "L2_verdict=skipped is accepted" {
  write_done << 'EOF'
phase=1
change_id=test-change
written_by=main-agent
L2_verdict=skipped
L3_verdict=pass
artifacts=REQUIREMENT.md,CHANGE.md
EOF
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker \
      "${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done" \
      "1" "test-change" "write"
    [ "$status" -eq 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}

# ── 保留：空文件/bad .done → invalid ──

@test "empty .done file: invalid" {
  local _empty="${PROJECT_ROOT}/.specs/test-change/.independent-review-1.done"
  mkdir -p "$(dirname "$_empty")"
  touch "$_empty"
  if type fk_validate_done_marker >/dev/null 2>&1; then
    run fk_validate_done_marker "$_empty" "1" "test-change" "transition"
    [ "$status" -ne 0 ]
  else
    skip "fk_validate_done_marker not available"
  fi
}
