#!/usr/bin/env bats
# test_flow_active_integrity.bats — Tests for 33-flow-active-integrity.sh
# Covers AC-2 ~ AC-6 + NFR reliability scenarios

setup() {
  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录
  # （双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确 · L-025 同源路径问题根治）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks/stop" ]; do
    d="$(dirname "$d")"
  done
  HOOK_BASE_DIR="$d/flow-kit-bundle/hooks/stop"

  TEST_TMP=$(mktemp -d)

  # Create minimal .flow-active fixture
  FLOW_ACTIVE="${TEST_TMP}/.flow-active"
  SPECS_DIR="${TEST_TMP}/.specs"
  CORRECTION_FILE="${TEST_TMP}/.flow-active.correction"
  TRANSCRIPT_FILE="${TEST_TMP}/transcript.txt"

  mkdir -p "$SPECS_DIR"

  # Default: valid .flow-active
  cat > "$FLOW_ACTIVE" << 'EOF'
{
  "change_id": "test-change",
  "phase": "1",
  "goal": {
    "scope": "phase",
    "current_phase": "1",
    "phases_done": ["0"],
    "gates": {"0→1": "passed"}
  },
  "token_spent": 100,
  "updated_at": REPLACE_TS
}
EOF

  # Replace timestamp placeholder with current time
  local now
  now=$(date +%s)
  sed -i "s/REPLACE_TS/$now/" "$FLOW_ACTIVE"

  # Create test-change directory with REQUREMENT.md
  mkdir -p "${SPECS_DIR}/test-change"
  echo "# REQUIREMENT" > "${SPECS_DIR}/test-change/REQUIREMENT.md"

  # Source the module
  source "${HOOK_BASE_DIR}/33-flow-active-integrity.sh" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── AC-1: L2 PCSC self-check anchor text ─────────────────────────────

@test "AC-1: all user-scope prompts contain PCSC anchor text" {
  local anchor='.flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘'
  local count=0
  local f=""
  for f in ~/.claude/flow-kit/prompts/{0-change,1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md ~/.claude/flow-kit/GO.md; do
    if grep -qF "$anchor" "$f" 2>/dev/null; then
      count=$((count + 1))
    fi
  done
  [[ $count -eq 9 ]]
}

@test "AC-1: all bundle prompts contain PCSC anchor text" {
  local anchor='.flow-active 关键字段（phase/task_id/change_id/updated_at）已通过 jq 写入磁盘'
  local count=0
  local f=""
  for f in flow-kit-bundle/flow-kit/prompts/{0-change,1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md flow-kit-bundle/flow-kit/GO.md; do
    if grep -qF "$anchor" "$f" 2>/dev/null; then
      count=$((count + 1))
    fi
  done
  [[ $count -eq 9 ]]
}

# ── AC-2: phase-artifact alignment ──────────────────────────────────

@test "AC-2: detects missing artifact for current phase" {
  # phase=2, change_id=test-change, but no DESIGN.md
  jq '.phase = "2"' "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "phase_artifact_missing") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"DESIGN.md"* ]]
}

@test "AC-2: no violation when all artifacts present" {
  # phase=1, REQUIREMENT.md exists
  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  # Should not have phase_artifact_missing
  if [[ -f "$CORRECTION_FILE" ]]; then
    run jq -r '[.violations[] | select(.check == "phase_artifact_missing")] | length' "$CORRECTION_FILE"
    [[ "$output" == "0" ]]
  fi
}

# ── AC-3: change_id consistency ─────────────────────────────────────

@test "AC-3: detects dangling change_id" {
  jq '.change_id = "ghost"' "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "change_id_dangling") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"ghost"* ]]
}

@test "AC-3: detects null change_id with active directories" {
  jq '.change_id = null' "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "change_id_null_with_dirs") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"test-change"* ]]
}

# ── AC-4: pipeline goal field cross-validation ────────────────────────

@test "AC-4: detects phases_done artifact missing" {
  # Pipeline mode, phases_done=["0","1"] but missing DESIGN.md for phase 2
  jq '.goal.scope = "pipeline" | .goal.phases_done = ["0","1","2"] | .goal.gates["1→2"] = "passed" | .goal.gates["2→3"] = "pending" | .goal.current_phase = "3"' \
    "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '[.violations[] | select(.check == "pipeline_phase_artifact_missing")] | length' "$CORRECTION_FILE"
  [[ "$output" != "0" ]]
}

@test "AC-4: detects gate passed but phase not in phases_done" {
  jq '.goal.scope = "pipeline" | .goal.phases_done = ["0"] | .goal.gates["0→1"] = "passed" | .goal.gates["1→2"] = "passed" | .goal.current_phase = "2"' \
    "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "pipeline_gate_phase_mismatch") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"1"* ]]
}

@test "AC-4: detects current_phase gate not passed (R7 fix)" {
  jq '.goal.scope = "pipeline" | .goal.phases_done = ["0","1"] | .goal.gates["0→1"] = "passed" | .goal.gates["1→2"] = "pending" | .goal.current_phase = "2"' \
    "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "pipeline_gate_not_passed") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"1→2"* ]]
}

@test "AC-4: no violation when pipeline fields are consistent" {
  jq '.goal.scope = "pipeline" | .goal.phases_done = ["0"] | .goal.gates["0→1"] = "passed" | .goal.current_phase = "1"' \
    "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  # Should not have pipeline_* violations
  if [[ -f "$CORRECTION_FILE" ]]; then
    run jq -r '[.violations[] | select(.check | startswith("pipeline_"))] | length' "$CORRECTION_FILE"
    [[ "$output" == "0" ]]
  fi
}

# ── AC-5: updated_at staleness detection ────────────────────────────

@test "AC-5: detects stale updated_at (>24h)" {
  local stale_ts
  stale_ts=$(date -d '25 hours ago' +%s 2>/dev/null || echo $(( $(date +%s) - 90000 )))
  jq --arg ts "$stale_ts" '.updated_at = ($ts | tonumber)' "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  FLOW_ACTIVE_STALE_HOURS=24 _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "stale_updated_at") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"old"* || "$output" == *"25h"* || "$output" == *"stale"* ]]
}

@test "AC-5: no violation for fresh updated_at" {
  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  if [[ -f "$CORRECTION_FILE" ]]; then
    run jq -r '[.violations[] | select(.check == "stale_updated_at")] | length' "$CORRECTION_FILE"
    [[ "$output" == "0" ]]
  fi
}

# ── AC-6: token_spent unmaintained detection ────────────────────────

@test "AC-6: detects token_spent=0 with .flow-active writes in transcript" {
  jq '.token_spent = 0' "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  # Create transcript with jq .flow-active write operations
  echo "jq '.phase = \"2\"' .flow-active > .flow-active.tmp" > "$TRANSCRIPT_FILE"
  echo "mv .flow-active.tmp .flow-active" >> "$TRANSCRIPT_FILE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" "$TRANSCRIPT_FILE"

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "token_spent_unmaintained") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"token_spent"* ]]
}

@test "AC-6: no violation when token_spent > 0" {
  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" "$TRANSCRIPT_FILE"

  if [[ -f "$CORRECTION_FILE" ]]; then
    run jq -r '[.violations[] | select(.check == "token_spent_unmaintained")] | length' "$CORRECTION_FILE"
    [[ "$output" == "0" ]]
  fi
}

# ── NFR Reliability ──────────────────────────────────────────────────

@test "NFR: handles missing jq gracefully" {
  # Simulate jq unavailable by removing PATH (module checks command -v jq)
  # The module exits early with return 0
  PATH="/nonexistent" run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""
  # Should not crash
  [[ "$status" -eq 0 ]]
}

@test "NFR: handles corrupt JSON .flow-active" {
  echo 'not valid json {{{' > "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  [[ -f "$CORRECTION_FILE" ]]
  run jq -r '.violations[] | select(.check == "corrupt_json") | .message' "$CORRECTION_FILE"
  [[ "$output" == *"not valid JSON"* ]]
}

@test "NFR: handles unreadable .specs/ directory" {
  mkdir -p "${SPECS_DIR}/test-change"
  chmod 000 "$SPECS_DIR" 2>/dev/null || true

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""
  # Should not crash — returns 0
  [[ "$status" -eq 0 ]]

  chmod 755 "$SPECS_DIR" 2>/dev/null || true
}

@test "NFR: built-in PHASE_ARTIFACTS fallback works" {
  # Ensure PHASE_ARTIFACTS is not declared (fresh env)
  unset PHASE_ARTIFACTS 2>/dev/null || true

  local result
  result=$(_fai_get_phase_artifacts "1")
  [[ "$result" == "REQUIREMENT.md" ]]

  result=$(_fai_get_phase_artifacts "2")
  [[ "$result" == "DESIGN.md" ]]

  result=$(_fai_get_phase_artifacts "99")
  [[ "$result" == "" ]]
}

@test "NFR: read-merge-write preserves existing violations" {
  # Write an initial correction file with a compliance violation
  jq -n '{type: "compliance", violations: [{"check": "existing","message": "old"}], written_at: "2026-01-01"}' > "$CORRECTION_FILE"

  # Trigger a state-integrity violation
  jq '.change_id = "ghost"' "$FLOW_ACTIVE" > "${FLOW_ACTIVE}.tmp" && mv "${FLOW_ACTIVE}.tmp" "$FLOW_ACTIVE"

  run _flow_active_integrity_main "$FLOW_ACTIVE" "$SPECS_DIR" "$CORRECTION_FILE" ""

  # Should have both violations
  local count
  count=$(jq -r '.violations | length' "$CORRECTION_FILE")
  [[ $count -ge 2 ]]

  # Old violation should still exist
  run jq -r '.violations[] | select(.check == "existing") | .message' "$CORRECTION_FILE"
  [[ "$output" == "old" ]]
}
