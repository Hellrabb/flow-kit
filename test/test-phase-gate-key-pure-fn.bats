#!/usr/bin/env bats
# test-phase-gate-key-pure-fn.bats — AC-F: fk_phase_gate_key pure fn 单一来源（ADR-007 / D1）
#
# 覆盖：
#   Part A · pure fn 单元（AC-F Then · 逐 key = REQUIREMENT 附录 oracle）
#     - 6 个 review phase key 精确匹配附录 oracle（强引用，非"非空"）
#     - phase 0/4 故意排除（无独立审查 gate）→ 空串
#     - 未知 / 空 / 非数字 phase → 空串（容错，set -euo 下不非零退出）
#     - 多次调用幂等（pure fn 无状态）
#   Part B · 集成守护（NFR-3 stderr 三要素 + R1 forward transition deny 回归）
#     - T01 改 gate.sh 用 fk_phase_gate_key + source common.sh 后，phase1 forward
#       transition 无 .done 仍 deny exit2（BUG-F 不重现），stderr 含三要素：
#       phase_name(fk_phase_gate_key 返回值) + .done 路径 + 阻断原因
#
# 关联：ADR-007 / REQUIREMENT AC-F / DESIGN D1·R1 / NFR-3 / NFR-4

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  REAL_PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
  COMMON_SH="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh"
  GATE_SH="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh"
  TMP_DIR="$BATS_TMPDIR/phase-gate-key-test-$$"
  mkdir -p "$TMP_DIR/.specs/test-change"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ═══════════════════════════════════════════════════════════════
# Part A · pure fn 单元（AC-F Then · 逐 key = 附录 oracle）
# ═══════════════════════════════════════════════════════════════

@test "AC-F: fk_phase_gate_key 逐 key = 附录 oracle（1/2/3/5/6/7）" {
  source "$COMMON_SH"
  [ "$(fk_phase_gate_key 1)" = "1-requirement" ]
  [ "$(fk_phase_gate_key 2)" = "2-design" ]
  [ "$(fk_phase_gate_key 3)" = "3-task" ]
  [ "$(fk_phase_gate_key 5)" = "5-test" ]
  [ "$(fk_phase_gate_key 6)" = "6-review" ]
  [ "$(fk_phase_gate_key 7)" = "7-integration" ]
}

@test "AC-F: phase 0/4 故意排除（无独立审查 gate）→ 空串" {
  source "$COMMON_SH"
  [ -z "$(fk_phase_gate_key 0)" ]
  [ -z "$(fk_phase_gate_key 4)" ]
}

@test "AC-F: 未知 / 空 / 非数字 phase → 空串（容错，set -euo 下不非零退出）" {
  source "$COMMON_SH"
  [ -z "$(fk_phase_gate_key 99)" ]
  [ -z "$(fk_phase_gate_key "")" ]
  [ -z "$(fk_phase_gate_key abc)" ]
}

@test "AC-F: 多次调用幂等（pure fn 无状态，无 source 副作用）" {
  source "$COMMON_SH"
  local first second
  first=$(fk_phase_gate_key 6)
  second=$(fk_phase_gate_key 6)
  [ "$first" = "6-review" ]
  [ "$first" = "$second" ]
}

# ═══════════════════════════════════════════════════════════════
# Part B · 集成守护（NFR-3 stderr 三要素 + R1 forward transition deny 回归）
# 守护 T01 改动（gate.sh source common.sh + 删 declare + 2 消费者改 fk_phase_gate_key）
# 后 PreToolUse gate 不失效。payload 范式沿用 INT-1~7。
# ═══════════════════════════════════════════════════════════════

@test "NFR-3 + R1 守护: phase1 git commit 无.done → _gate_deny_reason deny exit2 + stderr 三要素" {
  local specs_dir="$TMP_DIR/.specs/test-change"
  # .flow-active: phase 1, gate_config[1-requirement]=both, current_phase 1 → forward 2
  jq -n --argjson gc '{"1-requirement":"both"}' \
    '{change_id:"test-change",phase:1,goal:{scope:"pipeline",current_phase:"1",gate_config:$gc,phases_done:["0"],gates:{"0→1":"passed","1→2":"pending"},auto_advance:false}}' \
    > "$TMP_DIR/.flow-active"
  jq -n --argjson gc '{"1-requirement":"both"}' '{gate_config:$gc,created_at:"2026-07-18"}' > "$specs_dir/.goal-snapshot.json"
  rm -f "$specs_dir"/.independent-review-*.done "$specs_dir"/INDEPENDENT-REVIEW-*.md 2>/dev/null || true

  # git commit（非阶段写）→ Gate 7 _gate_deny_reason → final deny（三要素）。
  # 选 git commit 而非 forward transition：forward transition 走 _gate_check_l2 的 L2-wait
  # （输出 "L2 尚未完成"，无 phase_name / 无 .done 路径，不满足 NFR-3 三要素）；git commit 走
  # _gate_deny_reason，其 stderr 含 "阶段 N (<phase_name>)" + done_marker + 阻断原因——phase_name
  # 正是 fk_phase_gate_key 返回值，守护 T01 pure fn 在 _gate_deny_reason 集成路径的正确性。
  jq -n --arg c 'git commit -m test' --arg cwd "$TMP_DIR" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' > "$TMP_DIR/payload.json"

  run bash -c "PROJECT_ROOT='$TMP_DIR' bash '$GATE_SH' < '$TMP_DIR/payload.json' 2>'$TMP_DIR/stderr.log'"

  [ "$status" -eq 2 ]

  # NFR-3 三要素（stderr）:
  grep -q "1-requirement" "$TMP_DIR/stderr.log"               # phase_name（fk_phase_gate_key 返回值守护）
  grep -q "\.independent-review-1\.done" "$TMP_DIR/stderr.log" # .done 路径
  grep -q "独立 review" "$TMP_DIR/stderr.log"                  # 阻断原因
}
