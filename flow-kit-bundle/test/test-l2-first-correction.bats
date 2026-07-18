#!/usr/bin/env bats
# test-l2-first-correction.bats — AC-I: L2-first 顺序契约 + 可观测性（ADR-009 / D3·I）
#
# 覆盖 AC-I（D3 双管：29 D4 提示增强 + correction flag + 日志）：
#   (a) 29 含 _write_l2_missing_correction helper + 两处 D4 门提示含派发指引（## L2 盲审 段）+ deny reason
#   (b) 实跑 29（gate_config=both + 无 L2 段）→ correction flag(type=l2-missing) 写入
#   (c) 实跑 29 → module_output 日志（independent-review.txt）含派发指引
#
# 关联：ADR-009 / REQUIREMENT AC-I / DESIGN D3
# 范式：静态 grep（沿用 test_dual_review_merge）+ 实跑 29（Stop hook 环境 + L2 mock）

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  REAL_PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
  HOOK_29="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop/29-independent-review.sh"
  TMP_DIR="$BATS_TMPDIR/l2-first-test-$$"
  mkdir -p "$TMP_DIR/.specs/test-change" "$TMP_DIR/hook-tmp" "$TMP_DIR/.claude"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# 构造 gate_config=both + 无 L2 段的 29 测试环境，跑 29
_run_29_l2_missing() {
  local specs_dir="$TMP_DIR/.specs/test-change"
  jq -n --argjson gc '{"1-requirement":"both"}' \
    '{change_id:"test-change",phase:1,goal:{scope:"pipeline",current_phase:"1",gate_config:$gc,phases_done:["0"],gates:{"0→1":"passed","1→2":"pending"},auto_advance:false}}' \
    > "$TMP_DIR/.flow-active"
  jq -n --argjson gc '{"1-requirement":"both"}' '{gate_config:$gc,created_at:"2026-07-18"}' > "$specs_dir/.goal-snapshot.json"
  rm -f "$specs_dir"/.independent-review-*.done "$specs_dir"/INDEPENDENT-REVIEW-*.md 2>/dev/null || true
  jq -n '{modules:{independent_review:{enabled:true}}}' > "$TMP_DIR/.claude/stop-hook.json"
  PROJECT_ROOT="$TMP_DIR" \
    HOOK_BASE_DIR="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop" \
    HOOK_TMP_DIR="$TMP_DIR/hook-tmp" \
    CONFIG_FILE="$TMP_DIR/.claude/stop-hook.json" \
    FLOW_KIT_L2_MOCK=1 \
    bash "$HOOK_29" >/dev/null 2>&1 || true
}

# ══ (a) 静态：helper + 两处 D4 门提示 ══

@test "AC-I (a): 29 含 _write_l2_missing_correction helper（D3 双管 a 载体）" {
  grep -q '_write_l2_missing_correction()' "$HOOK_29"
}

@test "AC-I (a): 29 两处 D4 门提示含派发指引（写入 ## L2 盲审 段）—— 主门 + fallback" {
  local count
  count=$(grep -c '主 agent 请派 L2 子 agent 并写入 ## L2 盲审 段' "$HOOK_29")
  [ "$count" -ge 2 ]
}

@test "AC-I (a): 29 D4 提示含 deny reason（L2-first 契约未满足）" {
  grep -q 'deny reason: L2-first 契约未满足' "$HOOK_29"
}

# ══ (b) 实跑 29：correction flag(type=l2-missing) 写入 ══

@test "AC-I (b): gate_config=both 无 L2 段跑 29 → 写 .flow-active.correction(type=l2-missing)" {
  _run_29_l2_missing
  [ -f "$TMP_DIR/.flow-active.correction" ]
  grep -q '"l2-missing"' "$TMP_DIR/.flow-active.correction"
}

# ══ (c) 实跑 29：module_output 日志含派发指引 ══

@test "AC-I (c): 跑 29 写 module_output 日志（independent-review.txt 含派发指引）" {
  _run_29_l2_missing
  [ -f "$TMP_DIR/hook-tmp/independent-review.txt" ]
  grep -q '## L2 盲审 段' "$TMP_DIR/hook-tmp/independent-review.txt"
}
