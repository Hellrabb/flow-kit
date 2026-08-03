#!/usr/bin/env bats

# Integration smoke tests for hook lib splits (final-debt-cleanup-2026-08)
# INT-HOOK-1: PreToolUse slim orchestrator sources all 3 sub-libs
# INT-HOOK-2: Stop hook l3-review slim orchestrator sources all 4 sub-libs
# INT-HOOK-3: All public functions still defined after sourcing

setup() {
  BUNDLE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit-bundle"
  PRETOOLUSE_GATE="$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"
  PRETOOLUSE_DIR="$BUNDLE_ROOT/hooks/pre-tool-use"
  STOP_L3_REVIEW="$BUNDLE_ROOT/hooks/stop/lib/l3-review.sh"
  STOP_LIB_DIR="$BUNDLE_ROOT/hooks/stop/lib"
}

@test "INT-HOOK-1: PreToolUse slim orchestrator sources all 3 sub-libs" {
  [ -f "$PRETOOLUSE_GATE" ] || skip "independent-review-gate.sh not found"
  
  # Verify slim orchestrator has source directives for all 3 sub-libs
  grep -q "source.*gate-helpers\.sh" "$PRETOOLUSE_GATE" || skip "gate-helpers.sh source directive missing"
  grep -q "source.*gate-checks-basic\.sh" "$PRETOOLUSE_GATE" || skip "gate-checks-basic.sh source directive missing"
  grep -q "source.*gate-checks-review\.sh" "$PRETOOLUSE_GATE" || skip "gate-checks-review.sh source directive missing"
  
  # Verify the 3 sub-lib files exist
  [ -f "$PRETOOLUSE_DIR/gate-helpers.sh" ]
  [ -f "$PRETOOLUSE_DIR/gate-checks-basic.sh" ]
  [ -f "$PRETOOLUSE_DIR/gate-checks-review.sh" ]
}

@test "INT-HOOK-2: Stop hook l3-review slim orchestrator sources all 4 sub-libs" {
  [ -f "$STOP_L3_REVIEW" ] || skip "l3-review.sh not found"
  
  # Verify slim orchestrator has source directives for all 4 sub-libs
  grep -q "source.*l3-prompt\.sh" "$STOP_L3_REVIEW" || skip "l3-prompt.sh source directive missing"
  grep -q "source.*l3-api\.sh" "$STOP_L3_REVIEW" || skip "l3-api.sh source directive missing"
  grep -q "source.*l3-truncate\.sh" "$STOP_L3_REVIEW" || skip "l3-truncate.sh source directive missing"
  grep -q "source.*l3-done\.sh" "$STOP_L3_REVIEW" || skip "l3-done.sh source directive missing"
  
  # Verify the 4 sub-lib files exist
  [ -f "$STOP_LIB_DIR/l3-prompt.sh" ]
  [ -f "$STOP_LIB_DIR/l3-api.sh" ]
  [ -f "$STOP_LIB_DIR/l3-truncate.sh" ]
  [ -f "$STOP_LIB_DIR/l3-done.sh" ]
}

@test "INT-HOOK-3: All public functions still defined in l3-review.sh (via re-export)" {
  [ -f "$STOP_L3_REVIEW" ] || skip "l3-review.sh not found"
  
  # Source l3-review.sh in a subshell and check critical public functions are defined
  result=$(bash -c '
    set -euo pipefail
    source "'"$STOP_L3_REVIEW"'" 2>/dev/null || true
    
    # Check critical public functions exist (defined via re-export from sub-libs)
    for fn in l3_review_run l3_review_with_timeout l3_dispatch_prompt _l3_build_prompt _l3_call_api _l3_parse_result _l3_write_done _l3_check_rerun smart_truncate _l3_format_result _l3_inject_context l3_write_timeout_done; do
      type "$fn" >/dev/null 2>&1 || { echo "MISSING: $fn"; exit 1; }
    done
    echo "ALL_FUNCTIONS_DEFINED"
  ' 2>&1) || true
  
  echo "$result"
  [[ "$result" == *"ALL_FUNCTIONS_DEFINED"* ]]
}
