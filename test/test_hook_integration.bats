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
  # 仓库源件缺失 ⇒ 红（R5-26 fail-fast，不得 skip 回落）
  [ -f "$PRETOOLUSE_GATE" ]
  [ -f "$PRETOOLUSE_DIR/gate-helpers.sh" ]
  [ -f "$PRETOOLUSE_DIR/gate-checks-basic.sh" ]
  [ -f "$PRETOOLUSE_DIR/gate-checks-review.sh" ]
  # C6/C14-i 行为断言（T15 修）：原形为 grep 探针 || skip（source 指令缺失 ⇒ 静默跳过 =
  # 软跳过真空绿）。改为在子壳 source 编排器（入口有 BASH_SOURCE==0 main guard，source-safe），
  # 观测 3 个子库各自的哨兵函数真实被定义；编排器自带 fail-close 断言块（子库缺函数 →
  # exit 2）使「source 指令缺失/子库漂移」当场红。
  run bash -c '
    set -euo pipefail
    export HOOK_BASE_DIR="'"$PRETOOLUSE_DIR"'"
    source "'"$PRETOOLUSE_GATE"'"
    for fn in _gate_path_guard _gate_check_l2 _gate_do_transition; do
      declare -f "$fn" >/dev/null 2>&1 || { echo "MISSING: $fn"; exit 1; }
    done
    echo INT_HOOK1_SOURCED_OK
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"INT_HOOK1_SOURCED_OK"* ]]
}

@test "INT-HOOK-2: Stop hook l3-review slim orchestrator sources all 4 sub-libs" {
  # 仓库源件缺失 ⇒ 红（R5-26 fail-fast，不得 skip 回落）
  [ -f "$STOP_L3_REVIEW" ]
  [ -f "$STOP_LIB_DIR/l3-prompt.sh" ]
  [ -f "$STOP_LIB_DIR/l3-api.sh" ]
  [ -f "$STOP_LIB_DIR/l3-truncate.sh" ]
  [ -f "$STOP_LIB_DIR/l3-done.sh" ]
  # C6/C14-i 行为断言（T15 修）：原形 grep 探针 || skip = 软跳过。改为子壳 source 编排器后
  # 断言 4 个子库各自的哨兵函数真实定义（与 INT-HOOK-3 同范式；l3-review.sh 顶层仅
  # source 子库 + 函数定义，source-safe）。
  run bash -c '
    set -euo pipefail
    source "'"$STOP_L3_REVIEW"'" >/dev/null 2>&1
    for fn in _l3_build_prompt _l3_call_api smart_truncate _l3_write_done; do
      declare -f "$fn" >/dev/null 2>&1 || { echo "MISSING: $fn"; exit 1; }
    done
    echo INT_HOOK2_SOURCED_OK
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"INT_HOOK2_SOURCED_OK"* ]]
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
