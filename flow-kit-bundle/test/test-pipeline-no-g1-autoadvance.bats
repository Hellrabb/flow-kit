#!/usr/bin/env bats
# test-pipeline-no-g1-autoadvance.bats — T05 D5·K (ADR-011)
# AC-K: pipeline goal 模式 26-workflow G1 不 auto-advance .phase（推进归 toll-gate）；
#         单阶段 goal（scope=phase 或无 goal.scope）保留 auto-advance。
# 范式：子进程跑 26-workflow.sh（export PROJECT_ROOT/HOOK_TMP_DIR/CONFIG_FILE 让 workflow 模块 enabled），断言 .flow-active.phase。

bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 找 hooks 根（同 test_l3_pipeline_fix 模式）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d=$(dirname "$d")
  done
  HOOK_BASE_DIR="$d/flow-kit-bundle/hooks"
  WORKFLOW_SH="${HOOK_BASE_DIR}/stop/26-workflow.sh"

  PROJECT_ROOT="$TEST_TMPDIR"
  HOOK_TMP_DIR="$TEST_TMPDIR/hook-tmp"; mkdir -p "$HOOK_TMP_DIR"
  mkdir -p "$TEST_TMPDIR/.claude"
  CONFIG_FILE="$TEST_TMPDIR/.claude/stop-hook.json"
  # workflow 模块 enabled（module_enabled/check_enabled 默认 false，须显式开）
  printf '{"modules":{"workflow":{"enabled":true}}}\n' > "$CONFIG_FILE"

  export PROJECT_ROOT HOOK_TMP_DIR SESSION_ID="test-bats" CONFIG_FILE

  # spec change + REQUIREMENT（满足 fk_auto_phase phase 1→2 条件）
  SPEC_DIR="${PROJECT_ROOT}/.specs/test-change"
  mkdir -p "$SPEC_DIR"
  # REQUIREMENT ≥7 行（fk_file_nonempty 要求 lines > MIN_MEANINGFUL_LINES=6）+ 含验收准则/Given-When-Then（fk_auto_phase case 1 grep）
  printf '# 需求文档\n\n## 背景\n这是 test-change 的需求说明，用于满足 fk_auto_phase phase 1→2 的产物门槛。\n\n## 验收准则\nGiven/When/Then\n' > "$SPEC_DIR/REQUIREMENT.md"
}

teardown() { rm -rf "$TEST_TMPDIR"; }

# 写 .flow-active fixture（无 gate_config → fk_independent_review_gate_active(1)=false，不拦单阶段 advance）
write_flow_active() {
  local scope="$1" phase="$2"
  jq -n --arg s "$scope" --arg p "$phase" \
    '{change_id:"test-change", phase:$p, task_id:"none",
      goal:{scope:$s, status:"active", condition:"test"}}' \
    > "${PROJECT_ROOT}/.flow-active"
}

# ══ AC-K-1: pipeline goal 不 advance ══

@test "AC-K-1: pipeline goal (scope=pipeline) + phase 1 + REQUIREMENT → G1 不 advance .phase" {
  write_flow_active "pipeline" "1"
  run bash "$WORKFLOW_SH"
  [[ "$status" -eq 0 ]]
  # 推进权归 toll-gate：.phase 仍 1，未静默推进到 2
  [[ "$(jq -r '.phase' "${PROJECT_ROOT}/.flow-active")" == "1" ]]
}

# ══ AC-K-2: 单阶段 goal 仍 auto-advance ══

@test "AC-K-2: 单阶段 goal (scope=phase) + phase 1 → 仍 auto-advance 到 2" {
  write_flow_active "phase" "1"
  run bash "$WORKFLOW_SH"
  [[ "$status" -eq 0 ]]
  [[ "$(jq -r '.phase' "${PROJECT_ROOT}/.flow-active")" == "2" ]]
}

# ══ AC-K-3: 无 goal.scope 默认单阶段 ══

@test "AC-K-3: 无 goal.scope（默认单阶段）+ phase 1 → auto-advance 到 2" {
  jq -n '{change_id:"test-change", phase:"1", task_id:"none", goal:{status:"active", condition:"test"}}' \
    > "${PROJECT_ROOT}/.flow-active"
  run bash "$WORKFLOW_SH"
  [[ "$status" -eq 0 ]]
  [[ "$(jq -r '.phase' "${PROJECT_ROOT}/.flow-active")" == "2" ]]
}

# ══ 守卫特征：守卫须真实存在且包裹 fk_auto_phase 调用 ══

@test "守卫特征: 26-workflow.sh 含 goal_scope pipeline 守卫（非仅注释）" {
  # 守卫变量名须存在（非注释行）
  run grep -qE '^[[:space:]]*local goal_scope|goal_scope=' "$WORKFLOW_SH"
  [[ "$status" -eq 0 ]]
  # fk_auto_phase 调用须被 pipeline 守卫包裹（同块内含 pipeline 与 fk_auto_phase）
  run bash -c "awk '/goal_scope/{has_scope=1} /fk_auto_phase/{has_auto=1} END{exit !(has_scope && has_auto)}' \"$WORKFLOW_SH\""
  [[ "$status" -eq 0 ]]
}
