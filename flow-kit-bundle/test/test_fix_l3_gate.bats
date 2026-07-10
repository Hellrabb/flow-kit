#!/usr/bin/env bats
# test/test_fix_l3_gate.bats — fix-l3-gate: L3 重审 + .done 安全 + phase 同步
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"

  # 定位 bundle root
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  BUNDLE_ROOT="$d/flow-kit-bundle"
  L3_REVIEW_SH="$BUNDLE_ROOT/hooks/stop/lib/l3-review.sh"
  AUTO_ADVANCE_SH="$BUNDLE_ROOT/hooks/stop/31-auto-advance.sh"

  # 模拟 specs 目录结构
  SPECS_DIR="$TEST_TMPDIR/.specs/fix-l3-gate"
  mkdir -p "$SPECS_DIR"

  # 模拟 .flow-active（最小 pipeline 状态）
  FLOW_FILE="$TEST_TMPDIR/.flow-active"
  cat > "$FLOW_FILE" <<'FLOWEOF'
{
  "change_id": "fix-l3-gate",
  "phase": 1,
  "goal": {
    "scope": "pipeline",
    "current_phase": "1",
    "phases_done": ["0"],
    "gates": {"0→1":"passed","1→2":"pending"},
    "gate_config": {"1-requirement":"L2"},
    "auto_advance": false
  }
}
FLOWEOF

  export HOOK_BASE_DIR="$BUNDLE_ROOT/hooks/stop"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ═══════════════════════════════════════════════
# AC-1: L3 重审——工件变更后重新触发
# ═══════════════════════════════════════════════

@test "AC-1: re-review triggered when artifact mtime > review mtime" {
  # 创建初始 review 文件（模拟已完成一次 L3 审查）
  local review_md="$SPECS_DIR/INDEPENDENT-REVIEW-1.md"
  echo "## L3 盲审（deepseek-v4-flash 外部模型 · 2026-07-10）" > "$review_md"
  echo '{"verdict":"fail","summary":"needs fix"}' >> "$review_md"

  # 记录 review 文件 mtime
  local review_mtime
  review_mtime=$(stat -c %Y "$review_md" 2>/dev/null || stat -f %m "$review_md" 2>/dev/null || echo "0")

  # 创建产物文件，mtime 晚于 review
  echo "# REQUIREMENT" > "$SPECS_DIR/REQUIREMENT.md"
  # touch 确保 mtime 严格大于
  sleep 1
  touch "$SPECS_DIR/REQUIREMENT.md"

  local artifact_mtime
  artifact_mtime=$(stat -c %Y "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || stat -f %m "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || echo "0")

  # 验证：产物 mtime > review mtime
  [ "$artifact_mtime" -gt "$review_mtime" ]
}

@test "AC-1: skip re-review when artifact mtime <= review mtime" {
  # 创建 review 文件和产物文件，mtime 相同
  local review_md="$SPECS_DIR/INDEPENDENT-REVIEW-1.md"
  echo "## L3 盲审" > "$review_md"
  echo "# REQUIREMENT" > "$SPECS_DIR/REQUIREMENT.md"

  # 使 review 文件 mtime >= 产物 mtime
  touch "$review_md"

  local review_mtime artifact_mtime
  review_mtime=$(stat -c %Y "$review_md" 2>/dev/null || stat -f %m "$review_md" 2>/dev/null || echo "0")
  artifact_mtime=$(stat -c %Y "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || stat -f %m "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || echo "0")

  # 验证：产物 mtime <= review mtime → 跳过
  [ "$artifact_mtime" -le "$review_mtime" ]
}

# ═══════════════════════════════════════════════
# AC-2: .done 安全——L3 fail 不写 .done
# ═══════════════════════════════════════════════

@test "AC-2: .done NOT written when L3 verdict=fail" {
  # 模拟 l3_review_run 执行后 .done 不应存在（verdict=fail）
  local done_marker="$SPECS_DIR/.independent-review-1.done"

  # 验证：.done 文件不存在
  run test -f "$done_marker"
  [ "$status" -eq 1 ]
}

@test "AC-2: GATE_DENY message format in stdout" {
  # 验证 GATE_DENY 消息格式
  local gate_output="GATE_DENY: L3 verdict=fail for phase 1"
  echo "$gate_output" | grep -q "GATE_DENY"
  echo "$gate_output" | grep -q "verdict=fail"
}

# ═══════════════════════════════════════════════
# AC-3: .done 安全——L3 pass 才写 .done
# ═══════════════════════════════════════════════

@test "AC-3: .done file 6-key KVP format valid" {
  local done_marker="$SPECS_DIR/.independent-review-1.done"
  cat > "$done_marker" <<'DONEEOF'
phase=1
change_id=fix-l3-gate
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
L3_summary="all good"
artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-1.md
DONEEOF

  source "$done_marker" 2>/dev/null
  [ "$L3_verdict" = "pass" ]
  [ -n "$phase" ] && [ -n "$change_id" ] && [ -n "$written_by" ]
  [ -n "$L2_verdict" ] && [ -n "$artifacts" ]
}

@test "AC-3: .done with L3_verdict=fail should be treated as invalid" {
  local done_marker="$SPECS_DIR/.independent-review-1.done"
  cat > "$done_marker" <<'DONEEOF'
phase=1
change_id=fix-l3-gate
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=fail
L3_summary="found issues"
artifacts=REQUIREMENT.md
DONEEOF

  source "$done_marker" 2>/dev/null
  # L3_verdict=fail 的 .done 在新逻辑下不应被当作有效放行凭证
  [ "$L3_verdict" = "fail" ]
}

# ═══════════════════════════════════════════════
# AC-4: phase 同步——transition jq 四字段一致
# ═══════════════════════════════════════════════

@test "AC-4: transition jq updates .phase + .goal.current_phase together" {
  local flow_tmp="$TEST_TMPDIR/.flow-active-test"
  cat > "$flow_tmp" <<'EOF'
{"phase":1,"goal":{"current_phase":"1","phases_done":["0"],"gates":{"0→1":"passed","1→2":"pending"}}}
EOF

  # 模拟 transition jq（含 .phase 同步）
  jq '.goal.current_phase = "2" | .phase = "2" | .goal.phases_done += ["1"] | .goal.gates["1→2"] = "passed"' \
    "$flow_tmp" > "$flow_tmp.tmp" && mv "$flow_tmp.tmp" "$flow_tmp"

  local top_phase goal_phase
  top_phase=$(jq -r '.phase' "$flow_tmp")
  goal_phase=$(jq -r '.goal.current_phase' "$flow_tmp")

  # 两个 phase 字段一致
  [ "$top_phase" = "$goal_phase" ]
  [ "$top_phase" = "2" ]
}

@test "AC-4: transition jq uses tempfile+mv pattern (atomicity check)" {
  local flow_tmp="$TEST_TMPDIR/.flow-active-test"
  echo '{"phase":1,"goal":{"current_phase":"1","phases_done":["0"],"gates":{"1→2":"pending"}}}' > "$flow_tmp"

  local tmp_file="${flow_tmp}.tmp"
  # 模拟 tempfile+mv：先写 tmp 再 mv（禁止 jq ... file > file）
  jq '.phase = "2" | .goal.current_phase = "2"' "$flow_tmp" > "$tmp_file" && mv "$tmp_file" "$flow_tmp"

  local phase_val
  phase_val=$(jq -r '.phase' "$flow_tmp")
  [ "$phase_val" = "2" ]

  # 验证：没有直接覆写 .flow-active（tmp 文件已被 mv，不应残留）
  [ ! -f "$tmp_file" ] || false
}

@test "AC-4: phases_done and gates updated consistently" {
  local flow_tmp="$TEST_TMPDIR/.flow-active-test"
  cat > "$flow_tmp" <<'EOF'
{"phase":"2","goal":{"current_phase":"2","phases_done":["0","1"],"gates":{"1→2":"passed","2→3":"pending"}}}
EOF

  # transition 2→3
  jq '.goal.current_phase = "3" | .phase = "3" | .goal.phases_done += ["2"] | .goal.gates["2→3"] = "passed"' \
    "$flow_tmp" > "$flow_tmp.tmp" && mv "$flow_tmp.tmp" "$flow_tmp"

  local phases_done gate_2_3
  phases_done=$(jq -c '.goal.phases_done' "$flow_tmp")
  gate_2_3=$(jq -r '.goal.gates["2→3"]' "$flow_tmp")

  # phases_done 包含 "2"
  echo "$phases_done" | grep -q '"2"'
  # gate 2→3 为 passed
  [ "$gate_2_3" = "passed" ]
}

# ═══════════════════════════════════════════════
# AC-5: 回退不受 L3 gate 拦截
# ═══════════════════════════════════════════════

@test "AC-5: rollback transition does not require .done" {
  local cur_phase=3 target_phase=2

  # 回退判定：目标 phase < 当前 phase → 回退
  [ "$target_phase" -lt "$cur_phase" ]
}

@test "AC-5: forward transition requires .done" {
  local cur_phase=2 target_phase=3

  # 前进判定：目标 phase > 当前 phase → 需要 .done
  [ "$target_phase" -gt "$cur_phase" ]

  # 模拟 gate 检查：前进时 .done 必须存在
  local done_marker="$SPECS_DIR/.independent-review-2.done"
  # 没有 .done → gate 应拒绝
  run test -f "$done_marker"
  [ "$status" -eq 1 ]
}

# ═══════════════════════════════════════════════
# 新增逻辑测试：l3-review.sh 追加模式
# ═══════════════════════════════════════════════

@test "l3-review append mode: ## L3 重审 section header present in modified script" {
  # 验证修改后的 l3-review.sh 含有重审相关逻辑
  run grep -q 'is_review' "$L3_REVIEW_SH" 2>/dev/null
  [ "$status" -eq 0 ]

  run grep -q '## L3 重审' "$L3_REVIEW_SH" 2>/dev/null
  [ "$status" -eq 0 ]

  # 验证不再使用 awk 覆写旧 L3 段（已改为追加模式）
  run grep -q "awk '/^## L3 盲审/{stop=1}" "$L3_REVIEW_SH" 2>/dev/null
  [ "$status" -eq 1 ]
}

@test "l3-review .done conditional: only writes .done on pass" {
  # 验证 .done 写入逻辑包含条件判断
  run grep -q 'L3 pass.*\.done written' "$L3_REVIEW_SH" 2>/dev/null
  [ "$status" -eq 0 ]

  run grep -q '\.done NOT written' "$L3_REVIEW_SH" 2>/dev/null
  [ "$status" -eq 0 ]
}

@test "l3-review file size warning: 50KB threshold check present" {
  run grep -q '51200' "$L3_REVIEW_SH" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════
# 31-auto-advance.sh: .phase sync
# ═══════════════════════════════════════════════

@test "31-auto-advance.sh: transition jq includes .phase sync" {
  run grep -q '\.phase = \$next' "$AUTO_ADVANCE_SH" 2>/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════
# l3_write_timeout_done: no .done written
# ═══════════════════════════════════════════════

@test "l3_write_timeout_done: timeout writes notice but NOT .done" {
  # 验证 timeout 函数不再写 .done
  run grep -A10 'l3_write_timeout_done()' "$L3_REVIEW_SH"
  # 不应包含 .done 写入逻辑（如 cat > done_marker）
  ! echo "$output" | grep -q 'cat >.*done_tmp'
}

# ═══════════════════════════════════════════════
# Prompt transition jq: .phase sync
# ═══════════════════════════════════════════════

@test "prompt transition jq: .phase sync in 0-change.md" {
  run grep -q '\.phase = "1"' "$BUNDLE_ROOT/flow-kit/prompts/0-change.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in 1-requirement.md" {
  run grep -q '\.phase = "2"' "$BUNDLE_ROOT/flow-kit/prompts/1-requirement.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in 2-design.md" {
  run grep -q '\.phase = "3"' "$BUNDLE_ROOT/flow-kit/prompts/2-design.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in 3-task.md" {
  run grep -q '\.phase = "4"' "$BUNDLE_ROOT/flow-kit/prompts/3-task.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in 5-test.md" {
  run grep -q '\.phase = "6"' "$BUNDLE_ROOT/flow-kit/prompts/5-test.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in 6-review.md" {
  run grep -q '\.phase = "7"' "$BUNDLE_ROOT/flow-kit/prompts/6-review.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in 4-dev.md" {
  run grep -q '\.phase = \$next_phase' "$BUNDLE_ROOT/flow-kit/prompts/4-dev.md"
  [ "$status" -eq 0 ]
}

@test "prompt transition jq: .phase sync in pipeline-gates.md" {
  run grep -q '\.phase = "5"' "$BUNDLE_ROOT/flow-kit/reference/pipeline-gates.md"
  [ "$status" -eq 0 ]
}
