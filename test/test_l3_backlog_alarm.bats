#!/usr/bin/env bats
# test_l3_backlog_alarm.bats — AC-6 · C4 积压 L3 失败告警恢复（health-fix-2026-09c T02 / DESIGN D6）
#
# 覆盖 AC-6（D6 前置捕获语义，非裸删 || true）：
#   1. 注入 backlog l3_review_run 失败 → module_output "warning" "IR" "backlog L3 failed …"
#      实际写入（修复前 || true 吞 rc，该分支恒死码）+ 失败 rc 透传到脚本退出码
#      （Stop 链兜底 = 00-gate.sh:71 run_module … || true，模块 rc 非致命）
#   2. 反向控制：backlog 成功 → 无 backlog warning 且 rc 0，主路径正常走完
#   3. 多积压相位：首个失败不阻断后续扫描（逐相位 warning），首个失败 rc 透传
#   4. 积压选择门完好：gate 未开启 L3 的相位不入积压 → 无 backlog 告警、rc 0
#
# 注入方式：函数覆写——沙箱 HOOK_BASE_DIR 复制生产 hooks/stop/lib/ 后替换
# lib/l3-review.sh 为假 l3_review_run（rc 经 FAKE_L3_RC / FAKE_L3_RC_<phase> 注入）。
# 镜像：flow-kit-bundle/test/test_l3_backlog_alarm.bats 内容逐字节相同（手动双写，不跑 make test-sync）。

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  local d="$TEST_ROOT"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  REAL_ROOT="$d"
  HOOK_29="$REAL_ROOT/flow-kit-bundle/hooks/stop/29-independent-review.sh"
  REAL_LIB="$REAL_ROOT/flow-kit-bundle/hooks/stop/lib"
  TMP_DIR="$BATS_TMPDIR/l3-backlog-alarm-$$"
  mkdir -p "$TMP_DIR"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# _gate_key <phase> — 复刻 done-validation.sh fk_phase_gate_key 的阶段名映射（测试侧只
# 覆盖本文件用到的相位；两处若漂移，用例 4 会先红）。
_gate_key() {
  case "$1" in
    1) echo "1-requirement" ;;
    2) echo "2-design" ;;
    3) echo "3-task" ;;
    5) echo "5-test" ;;
    6) echo "6-review" ;;
    7) echo "7-integration" ;;
    *) echo "" ;;
  esac
}

# _mk_sandbox <current_phase> <backlog_phases_csv> <gate_for_backlog> [gate_for_current=L3]
# 构造可直达 29 号 _l3_scan_backlog 的最小运行环境：
#   SB/hooks/lib    = 生产 lib 副本 + 假 l3-review.sh（l3_review_run 函数覆写）
#   SB/project/.flow-active / SB/config.json / SB/spec（.specs/t02-alarm-fix，无任何 .done）
_mk_sandbox() {
  local cur_phase="$1" backlog_csv="$2" bl_gate="$3" cur_gate="${4:-L3}"
  SB="$TMP_DIR/sb-cur${cur_phase}-bl${backlog_csv}-g${bl_gate}"
  HOOKS="$SB/hooks"
  PROJ="$SB/project"
  SPEC="$PROJ/.specs/t02-alarm-fix"
  mkdir -p "$HOOKS/lib" "$SPEC" "$SB/hook-tmp"
  cp -R "$REAL_LIB/." "$HOOKS/lib/"
  cat > "$HOOKS/lib/l3-review.sh" <<'FAKE'
# T02 测试替身（AC-6）——覆写生产 l3-review.sh：l3_review_run 不发 API，
# rc 注入：FAKE_L3_RC_<phase> 优先，回落 FAKE_L3_RC（默认 0）。
l3_review_run() {
  local pn="$1" var="FAKE_L3_RC_${pn}" rc
  rc="${!var:-${FAKE_L3_RC:-0}}"
  echo "[fake-l3] l3_review_run invoked phase=${pn} rc=${rc}" >&2
  return "$rc"
}
FAKE
  # .flow-active fixture：goal.scope 省略 → fk_resolve_phase 走 .phase 单相模式；
  # gate_config 键 = fk_phase_gate_key 阶段名；phases_done = backlog_csv（不含当前相位）。
  local pd="[]" pn gc="{}" k
  [ -n "$backlog_csv" ] && pd=$(printf '%s' "$backlog_csv" | jq -R 'split(",")')
  while IFS= read -r pn; do
    [ -n "$pn" ] || continue
    k="$(_gate_key "$pn")"
    gc=$(echo "$gc" | jq --arg k "$k" --arg v "$bl_gate" '. + {($k): $v}')
  done < <(printf '%s\n' "$backlog_csv" | tr ',' '\n')
  k="$(_gate_key "$cur_phase")"
  gc=$(echo "$gc" | jq --arg k "$k" --arg v "$cur_gate" '. + {($k): $v}')
  jq -n --argjson gc "$gc" --argjson pd "$pd" --arg phase "$cur_phase" \
    '{change_id: "t02-alarm-fix", phase: $phase, goal: {gate_config: $gc, phases_done: $pd}}' \
    > "$PROJ/.flow-active"
  jq -n '{modules: {independent_review: {enabled: true}}}' > "$SB/config.json"
}

# _run_29 — 实跑生产 29 脚本（沙箱 HOOK_BASE_DIR + 假 lib）；bats run 捕获 status/output。
_run_29() {
  PROJECT_ROOT="$PROJ" \
  HOOK_BASE_DIR="$HOOKS" \
  HOOK_TMP_DIR="$SB/hook-tmp" \
  CONFIG_FILE="$SB/config.json" \
  FLOW_KIT_L3_MODEL=fake-l3-model \
  FAKE_L3_RC="${FAKE_L3_RC:-0}" \
  bash "$HOOK_29"
}

@test "AC-6: backlog L3 失败 → warning 实际写入 + rc 透传（D6 前置捕获，非裸删）" {
  _mk_sandbox 5 "1" L3
  FAKE_L3_RC=7 run _run_29
  [ "$status" -eq 7 ]
  grep -q 'warning|IR|backlog L3 failed for phase 1 (rc=7)' "$SB/hook-tmp/independent-review.txt"
}

@test "AC-6 反向控制: backlog 成功 → 无 backlog warning 且 rc 0（主路径正常走完）" {
  _mk_sandbox 5 "1" L3
  FAKE_L3_RC=0 run _run_29
  [ "$status" -eq 0 ]
  ! grep -q 'backlog L3 failed' "$SB/hook-tmp/independent-review.txt"
  grep -q 'info|IR|L3 独立 review 完成' "$SB/hook-tmp/independent-review.txt"
}

@test "AC-6: 多积压相位逐个告警（首败不中止扫描），首个失败 rc 透传" {
  _mk_sandbox 5 "1,2" L3
  FAKE_L3_RC=9 run _run_29
  [ "$status" -eq 9 ]
  local n
  n=$(grep -c 'backlog L3 failed for phase' "$SB/hook-tmp/independent-review.txt")
  [ "$n" -eq 2 ]
  grep -q 'backlog L3 failed for phase 1 (rc=9)' "$SB/hook-tmp/independent-review.txt"
  grep -q 'backlog L3 failed for phase 2 (rc=9)' "$SB/hook-tmp/independent-review.txt"
}

@test "AC-6: gate 未开启 L3 的相位不入积压 → 无 backlog 告警、rc 0（主路径失败仍 exit 0 属既有语义）" {
  _mk_sandbox 5 "3" L2
  FAKE_L3_RC=7 run _run_29
  [ "$status" -eq 0 ]
  ! grep -q 'backlog L3 failed' "$SB/hook-tmp/independent-review.txt"
  # 假函数未被积压路径调用（phase=3 无 l3_review_run 调用痕迹），主路径 phase 5 正常告警
  ! grep -q 'phase=3' <<<"$output"
  grep -q 'L3 独立 review 调用失败（阶段 5, rc=7）' "$SB/hook-tmp/independent-review.txt"
}
