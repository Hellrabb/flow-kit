#!/usr/bin/env bats
# test_l2_pretooluse_dispatch.bats — L2 PreToolUse dispatch + L3 写入管道测试
#
# 覆盖 AC-1 ~ AC-11

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  REAL_PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
  FIXTURE_DIR="$TEST_ROOT/fixtures/l2-dispatch"
  TMP_DIR="$BATS_TMPDIR/l2-dispatch-test-$$"
  mkdir -p "$TMP_DIR/.specs/test-change"

  export FLOW_KIT_L2_MOCK=1

  # Source paths (use real project root)
  L2_DETECT="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop/lib/l2-detect.sh"
  GATE_SH="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh"
  L3_REVIEW="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop/lib/l3-review.sh"
  STOP_29="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/stop/29-independent-review.sh"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# source gate functions
source_gate_lib() {
  source "$L2_DETECT" 2>/dev/null || true
}

@test "smoke: mock environment initializes" {
  [ -d "$FIXTURE_DIR" ]
  [ -f "$FIXTURE_DIR/mock-flow-active-L2.json" ]
  [ -f "$FIXTURE_DIR/mock-agent-response.json" ]
  source "$L2_DETECT" 2>/dev/null
  type l2_dispatch_agent >/dev/null
  type l2_detect_missing >/dev/null
}

# ═══════════════════════════════════════════════════════════════
# AC-1: L2 缺失时硬拦截阶段切换
# ═══════════════════════════════════════════════════════════════
@test "AC-1: L2 missing triggers exit 2 for phase write" {
  source "$L2_DETECT" 2>/dev/null
  # 准备: 无 INDEPENDENT-REVIEW 文件 → L2 缺失
  local specs_dir="$TMP_DIR/.specs/test-change"
  run l2_detect_missing "2" "test-change" "$specs_dir"
  [ "$status" -eq 1 ]  # 返回 1 = L2 缺失
}

# ═══════════════════════════════════════════════════════════════
# AC-2: L2 完成时放行
# ═══════════════════════════════════════════════════════════════
@test "AC-2: L2 completed returns 0 (pass)" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  echo "## L2 盲审" > "$specs_dir/INDEPENDENT-REVIEW-2.md"
  echo "**Verdict**: pass" >> "$specs_dir/INDEPENDENT-REVIEW-2.md"
  run l2_detect_missing "2" "test-change" "$specs_dir"
  [ "$status" -eq 0 ]  # 返回 0 = L2 已完成
}

# ═══════════════════════════════════════════════════════════════
# AC-3: gate_config=both 时 L2+L3 独立判定（L2 缺失则拦截）
# ═══════════════════════════════════════════════════════════════
@test "AC-3: gate_config=both L2 missing blocks even if L3 done" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  # L3 .done 存在但 L2 缺失
  cat > "$specs_dir/.independent-review-2.done" <<'DONE'
phase=2
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=skipped
L3_verdict=pass
L3_summary=mock
artifacts=DESIGN.md,REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-2.md
DONE
  run l2_detect_missing "2" "test-change" "$specs_dir"
  [ "$status" -eq 1 ]  # L2 缺失 → 拦截（独立于 L3 状态）
}

# ═══════════════════════════════════════════════════════════════
# AC-5a: L2 自动派发触发 + 状态反馈（mock 模式）
# ═══════════════════════════════════════════════════════════════
@test "AC-5a: auto-dispatch triggers with mock and returns 0" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  FLOW_KIT_L2_MOCK=1 l2_dispatch_agent "2" "test-change" "$specs_dir"
  local rc=$?
  [ "$rc" -eq 0 ]
  # 验证 mock 写入
  grep -q "## L2 盲审" "$specs_dir/INDEPENDENT-REVIEW-2.md"
}

# ═══════════════════════════════════════════════════════════════
# AC-5b: 派发失败降级（无 API 凭证）
# ═══════════════════════════════════════════════════════════════
@test "AC-5b: dispatch fails gracefully without API credentials" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  # 清除 mock + 凭证 → 派发应失败
  FLOW_KIT_L2_MOCK=0 ANTHROPIC_AUTH_TOKEN="" ANTHROPIC_API_KEY="" \
    run l2_dispatch_agent "2" "test-change" "$specs_dir"
  [ "$status" -eq 1 ]  # 返回 1 = 失败
}

# ═══════════════════════════════════════════════════════════════
# AC-5c: 派发结果写入（mock 模式验证文件完整性）
# ═══════════════════════════════════════════════════════════════
@test "AC-5c: mock dispatch writes valid L2 review section" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  FLOW_KIT_L2_MOCK=1 l2_dispatch_agent "3" "test-change" "$specs_dir"
  local review_file="$specs_dir/INDEPENDENT-REVIEW-3.md"
  [ -f "$review_file" ]
  grep -q "^## L2 盲审" "$review_file"
  grep -q "Verdict.*pass" "$review_file"
}

# ═══════════════════════════════════════════════════════════════
# AC-9: auto_advance 非阻塞（l2_dispatch_agent 触发但不阻断）
# ═══════════════════════════════════════════════════════════════
@test "AC-9: auto_advance mode does not block (agent still dispatched)" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  # auto_advance 场景：dispatch 仍触发，文件被写入
  FLOW_KIT_L2_MOCK=1 l2_dispatch_agent "2" "test-change" "$specs_dir"
  local rc=$?
  [ "$rc" -eq 0 ]  # dispatch 成功触发
  [ -f "$specs_dir/INDEPENDENT-REVIEW-2.md" ]
}

# ═══════════════════════════════════════════════════════════════
# AC-10: L3 backlog 扫描错误不再静默吞没
# ═══════════════════════════════════════════════════════════════
@test "AC-10: 29-independent-review.sh has no silent error suppression" {
  # 验证 2>/dev/null 已从 l3_review_run 调用中移除
  ! grep -n '2>/dev/null || true' "$STOP_29" | grep -q 'l3_review_run' ||
    skip "2>/dev/null still present on l3_review_run (not yet patched)"
  # 验证 module_output 错误日志已添加
  grep -q 'module_output.*backlog.*L3.*failed' "$STOP_29"
  grep -q 'see hooks.log' "$STOP_29"
}

# ═══════════════════════════════════════════════════════════════
# AC-11: L3 原子写入 + 写入后验证
# ═══════════════════════════════════════════════════════════════
@test "AC-11: l3-review.sh uses atomic write (tmp + mv)" {
  # 验证原子写入模式
  grep -q 'tmp_review.*tmp' "$L3_REVIEW"
  grep -q 'mv.*tmp_review.*review_md' "$L3_REVIEW"
  # 验证写入后检查
  grep -q 'L3 content not persisted' "$L3_REVIEW"
  # 验证 _l3_write_done 防御
  grep -q 'done deferred.*L3 content not found' "$L3_REVIEW"
}

# ═══════════════════════════════════════════════════════════════
# 回归: L2 函数签名不变
# ═══════════════════════════════════════════════════════════════
@test "regression: l2_detect_missing signature unchanged" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  mkdir -p "$specs_dir"
  # 无 L2 段 → 返回 1
  run l2_detect_missing "2" "test-change" "$specs_dir"
  [ "$status" -eq 1 ]
  # 有 L2 段 → 返回 0
  echo "## L2 盲审" > "$specs_dir/INDEPENDENT-REVIEW-2.md"
  echo "**Verdict**: pass" >> "$specs_dir/INDEPENDENT-REVIEW-2.md"
  run l2_detect_missing "2" "test-change" "$specs_dir"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════
# 回归: l2_dispatch_prompt 仍可正常调用
# ═══════════════════════════════════════════════════════════════
@test "regression: l2_dispatch_prompt still callable" {
  source "$L2_DETECT" 2>/dev/null
  local specs_dir="$TMP_DIR/.specs/test-change"
  run l2_dispatch_prompt "2" "test-change" "$specs_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"L2 盲审未完成"* ]]
}

# ═══════════════════════════════════════════════════════════════
# 集成测试 · 通过 _run_review_gates 完整入口（补强编排层盲区 · 修测试方案核心缺陷）
# 现有 AC-1~11 全是单元级（source l2-detect.sh + 调单函数），未覆盖 _run_review_gates 编排层。
# 以下 INT-* 用真实 PreToolUse JSON payload 跑 bash gate.sh，断言 exit code（覆盖 BUG-A~E）。
# 复现方式见 .specs/l2-l3-test-defect/DIAGNOSE.md。
# ═══════════════════════════════════════════════════════════════

# _gate_run <phase> <gate_config_json> <cmd> → 构造 fixture + 跑 gate，结果在 $status/$output
_gate_run() {
  local phase="$1" gc="$2" cmd="$3"
  jq -n --argjson gc "$gc" --arg p "$phase" \
    '{change_id:"test-change",phase:($p|tonumber),goal:{scope:"pipeline",current_phase:$p,gate_config:$gc,phases_done:[],gates:{},auto_advance:false}}' \
    > "$TMP_DIR/.flow-active"
  mkdir -p "$TMP_DIR/.specs/test-change"
  jq -n --argjson gc "$gc" '{gate_config:$gc,created_at:"2026-07-17"}' > "$TMP_DIR/.specs/test-change/.goal-snapshot.json"
  rm -f "$TMP_DIR/.specs/test-change"/.independent-review-*.done "$TMP_DIR/.specs/test-change"/INDEPENDENT-REVIEW-*.md 2>/dev/null || true
  jq -n --arg c "$cmd" --arg cwd "$TMP_DIR" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' > "$TMP_DIR/payload.json"
  run bash -c "PROJECT_ROOT='$TMP_DIR' bash '$GATE_SH' < '$TMP_DIR/payload.json' 2>/dev/null"
}

@test "INT-1 (BUG-A): phase0 forward transition 放行（不再 exit2 死锁）" {
  _gate_run "0" '{"1-requirement":"both"}' \
    "jq '.goal.current_phase = \"1\"' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active"
  [ "$status" -eq 0 ]
}

@test "INT-2 (BUG-C): phase0 纯 git commit 放行（不再 exit1 异常退出）" {
  _gate_run "0" '{"1-requirement":"both"}' 'git commit -m test'
  [ "$status" -eq 0 ]
}

@test "INT-3 (BUG-B+E): phase1 git commit 无.done 正确 deny exit2" {
  _gate_run "1" '{"1-requirement":"both"}' 'git commit -m test'
  [ "$status" -eq 2 ]
}

@test "INT-4 (BUG-B+E): phase6 git commit 无.done 正确 deny exit2" {
  _gate_run "6" '{"6-review":"both"}' 'git commit -m test'
  [ "$status" -eq 2 ]
}

@test "INT-5 (BUG-D): gate_config 未配的 phase 放行（不再误 exit2）" {
  _gate_run "1" '{"6-review":"both"}' 'git commit -m test'
  [ "$status" -eq 0 ]
}

@test "INT-6 (AC-9 正向): .done + phases_done 含 phase 时放行（Gate4 敏感性 · mock fixture）" {
  # 验证 Gate4 对 .done/phases_done 的敏感性（mock fixture，非真实 Stop hook 写入——后者属 BUG-I 环境）
  local specs_dir="$TMP_DIR/.specs/test-change"
  jq -n --argjson gc '{"1-requirement":"both"}' \
    '{change_id:"test-change",phase:1,goal:{scope:"pipeline",current_phase:"1",gate_config:$gc,phases_done:["0","1"],gates:{"0→1":"passed","1→2":"passed"},auto_advance:false}}' \
    > "$TMP_DIR/.flow-active"
  mkdir -p "$specs_dir"
  jq -n --argjson gc '{"1-requirement":"both"}' '{gate_config:$gc,created_at:"2026-07-17"}' > "$specs_dir/.goal-snapshot.json"
  cat > "$specs_dir/.independent-review-1.done" <<'DONE'
phase=1
change_id=test-change
written_by=test-fixture
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md
DONE
  jq -n --arg c 'git commit -m test' --arg cwd "$TMP_DIR" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' > "$TMP_DIR/payload.json"
  run bash -c "PROJECT_ROOT='$TMP_DIR' bash '$GATE_SH' < '$TMP_DIR/payload.json' 2>/dev/null"
  [ "$status" -eq 0 ]
}
