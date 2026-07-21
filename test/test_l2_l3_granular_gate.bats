#!/usr/bin/env bats
# test_l2_l3_granular_gate.bats — L2/L3 独立开关拆分测试

setup() {
  TEST_TMP=$(mktemp -d)

  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录（L-025 同源路径问题根治）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  DONE_VALIDATION_LIB="$d/flow-kit-bundle/hooks/stop/lib/done-validation.sh"
  COMMON_LIB="$d/flow-kit-bundle/hooks/stop/lib/common.sh"

  PROJECT_ROOT="$TEST_TMP"
  mkdir -p "$TEST_TMP/.specs/test-change"

  # Default .flow-active with gate_config
  FLOW_ACTIVE="$TEST_TMP/.flow-active"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Helper: write .flow-active with given gate_config value
write_flow_active() {
  local gate_val="$1"
  cat > "$FLOW_ACTIVE" << EOF
{
  "change_id": "test-change",
  "phase": "6",
  "goal": {
    "gate_config": {
      "6-review": "${gate_val}"
    }
  }
}
EOF
}

# ── 值映射测试 ──────────────────────────────────────────────────────

@test "gate_val 'independent' maps to both (backward compat)" {
  write_flow_active "independent"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  # tier="" (any): should return 0
  run fk_independent_review_gate_active "6" ""
  [[ "$status" -eq 0 ]]
  # tier="L2": should return 0 (both includes L2)
  run fk_independent_review_gate_active "6" "L2"
  [[ "$status" -eq 0 ]]
  # tier="L3": should return 0 (both includes L3)
  run fk_independent_review_gate_active "6" "L3"
  [[ "$status" -eq 0 ]]
}

@test "gate_val 'true' maps to both (backward compat)" {
  write_flow_active "true"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" "L2"
  [[ "$status" -eq 0 ]]
  run fk_independent_review_gate_active "6" "L3"
  [[ "$status" -eq 0 ]]
}

@test "gate_val 'invalid' maps to empty (gate off)" {
  write_flow_active "invalid"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" ""
  [[ "$status" -eq 1 ]]
}

# ── L2-only 测试 ─────────────────────────────────────────────────────

@test "L2-only: L2 active, L3 not" {
  write_flow_active "L2"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" "L2"
  [[ "$status" -eq 0 ]]
  run fk_independent_review_gate_active "6" "L3"
  [[ "$status" -eq 1 ]]
}

@test "L2-only: any tier (tier='') is active" {
  write_flow_active "L2"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" ""
  [[ "$status" -eq 0 ]]
}

# ── L3-only 测试 ─────────────────────────────────────────────────────

@test "L3-only: L3 active, L2 not" {
  write_flow_active "L3"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" "L3"
  [[ "$status" -eq 0 ]]
  run fk_independent_review_gate_active "6" "L2"
  [[ "$status" -eq 1 ]]
}

@test "L3-only: any tier (tier='') is active" {
  write_flow_active "L3"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" ""
  [[ "$status" -eq 0 ]]
}

# ── both 测试 ────────────────────────────────────────────────────────

@test "both: L2 and L3 both active" {
  write_flow_active "both"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" "L2"
  [[ "$status" -eq 0 ]]
  run fk_independent_review_gate_active "6" "L3"
  [[ "$status" -eq 0 ]]
}

# ── 无 gate_config 测试 ──────────────────────────────────────────────

@test "no gate_config: all tiers return 1" {
  cat > "$FLOW_ACTIVE" << 'EOF'
{
  "change_id": "test-change",
  "phase": "6",
  "goal": {}
}
EOF
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "6" ""
  [[ "$status" -eq 1 ]]
}

# ── 无效 phase 测试 ──────────────────────────────────────────────────

@test "invalid phase returns 1" {
  write_flow_active "both"
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_independent_review_gate_active "4" "L2"
  [[ "$status" -eq 1 ]]
}

# ── done verdict 'skipped' 值域测试 ──────────────────────────────────

@test "L2_verdict=skipped is accepted (L3-only mode)" {
  local done_file="$TEST_TMP/.done"
  cat > "$done_file" << 'EOF'
phase=6
change_id=test-change
written_by=main-agent
L2_verdict=skipped
L3_verdict=pass
artifacts=REVIEW.md,TEST.md
session_id=abc-123
EOF
  # AC-5: 不含 phases_done，确保值域验证不被短路
  cat > "$FLOW_ACTIVE" << 'EOF'
{"change_id":"test-change","phase":"6","goal":{"gates":{"6→7":"passed"}}}
EOF
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_validate_done_marker "$done_file" "6" "test-change" "write"
  [[ "$status" -eq 0 ]]
}

@test "L3_verdict=skipped is accepted (L2-only mode)" {
  local done_file="$TEST_TMP/.done"
  cat > "$done_file" << 'EOF'
phase=6
change_id=test-change
written_by=main-agent
L2_verdict=pass
L3_verdict=skipped
artifacts=REVIEW.md,TEST.md
session_id=abc-123
EOF
  # AC-5: 不含 phases_done，确保值域验证不被短路
  cat > "$FLOW_ACTIVE" << 'EOF'
{"change_id":"test-change","phase":"6","goal":{"gates":{"6→7":"passed"}}}
EOF
  source "$COMMON_LIB" 2>/dev/null || true
source "$DONE_VALIDATION_LIB" 2>/dev/null || true
  run fk_validate_done_marker "$done_file" "6" "test-change" "write"
  [[ "$status" -eq 0 ]]
}
