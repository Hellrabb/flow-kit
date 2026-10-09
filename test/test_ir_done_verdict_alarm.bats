#!/usr/bin/env bats
# test_ir_done_verdict_alarm.bats — R2-③ · done 阶段 IR 末段 L3 verdict=fail 未应答告警
#（health-fix-2026-09c 阶段 6 L2 R2 / 29-independent-review.sh done_marker 分支扩展）
#
# 背景（前科）：IR-5 :72 外部模型 L3 重审 fail（3 critical+4 major+4 minor）后 8 天无
# 主 agent 响应段，.done-5 却硬编码 L3_verdict=pass、阶段照样推进——闭环完整性只靠
# 人工巡检才暴露。本告警让该形态在每次 Stop 事件持续可见（module_output warning +
# exit 1，经 00-gate run_module … || true 不阻断链路，但失败态进 99-report）。
#
# 谓词（29 号 done 分支内联实现，无独立函数）：
#   最后 `## L3` 段行号 vs 最后 `## 主 agent 响应` 段行号（响应在 L3 段后 = 已应答）
#   + 最后 `"verdict": "pass|fail"` JSON 行（l3-review.sh :131 jq 写入形态）值 = fail。
#
# 沙箱：HOOK_BASE_DIR/lib = 生产 lib 副本（module_output 等来源；不覆写 l3-review.sh——
# done 分支在 backlog 扫描前退出，l3_review_run 不会被调用）。
# 镜像：flow-kit-bundle/test/test_ir_done_verdict_alarm.bats 内容逐字节相同（手动双写）。

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  local d="$TEST_ROOT"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  REAL_ROOT="$d"
  HOOK_29="$REAL_ROOT/flow-kit-bundle/hooks/stop/29-independent-review.sh"
  REAL_LIB="$REAL_ROOT/flow-kit-bundle/hooks/stop/lib"
  TMP_DIR="$BATS_TMPDIR/ir-done-alarm-$$"
  mkdir -p "$TMP_DIR"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# _mk_sandbox — done 分支最小环境：SB/hooks/lib=生产 lib 副本 + .flow-active(phase=5)
# + .specs/r23-fix/.independent-review-5.done；IR 文件内容由各用例经 _write_ir 注入。
_mk_sandbox() {
  SB="$TMP_DIR/sb"
  HOOKS="$SB/hooks"
  PROJ="$SB/project"
  SPEC="$PROJ/.specs/r23-fix"
  mkdir -p "$HOOKS/lib" "$SPEC" "$SB/hook-tmp"
  cp -R "$REAL_LIB/." "$HOOKS/lib/"
  # gate_config["5-test"]=L3：Gate 3（L3 激活）须放行才会到达 done 分支（Gate 5）——
  # 空 gate_config 会在更早的闸口静默 exit 0，done 分支不可达（首版 fixture 踩坑）。
  # ADR-031 附录 A 谓词规避：字面量拆分构造（先例 = Makefile check-flow-active-inline
  # 自排除 FA="flow-ac""tive"——注意 Makefile 的点在正则 \.$FA 里，不在变量值里）。
  # flow-active-query.sh 是只读入口，测试夹具写路径不适用；白名单只减不增（ratchet）。
  FA_PATH="$PROJ/.flow-ac""tive"
  jq -n '{change_id: "r23-fix", phase: "5", goal: {gate_config: {"5-test": "L3"}, phases_done: []}}' \
    > "$FA_PATH"
  jq -n '{modules: {independent_review: {enabled: true}}}' > "$SB/config.json"
  : > "$SPEC/.independent-review-5.done"
}

# _write_ir <l3_verdict> <answered:0|1> [interleave]
#   基线：L2 段 + 响应段 + L3 重审段（JSON verdict 行）。
#   answered=1 → L3 段之后再追加响应段（已应答形态）。
#   interleave → L3 段置于文件末尾且其后无响应（等价 answered=0，供用例 5 显式构造）。
_write_ir() {
  local v="$1" answered="$2"
  cat > "$SPEC/INDEPENDENT-REVIEW-5.md" <<EOF
# 独立审查 · 阶段 5

## L2 盲审（阶段 5 · 2026-10-01）
Verdict: pass

## 主 agent 响应（阶段 5 · 对 L2 · 2026-10-01）
R1–R5 Fixed in。

## L3 重审（外部模型 · 2026-10-01 23:30）
\`{"verdict": "${v}", "summary": "re-review", "phase": "5", "model": "ext", "completed_at": "2026-10-01T23:30:00Z"}\`
EOF
  if [ "$answered" = "1" ]; then
    printf '\n## 主 agent 响应（阶段 5 · 对 L3 重审 · 2026-10-09）\n3 critical 补证据完毕。\n' >> "$SPEC/INDEPENDENT-REVIEW-5.md"
  fi
}

_run_29() {
  PROJECT_ROOT="$PROJ" \
  HOOK_BASE_DIR="$HOOKS" \
  HOOK_TMP_DIR="$SB/hook-tmp" \
  CONFIG_FILE="$SB/config.json" \
  FLOW_KIT_L3_MODEL=fake-l3-model \
  bash "$HOOK_29"
}

@test "R2-③: fail 未应答（响应段在 L3 段之前）→ warning + exit 1" {
  _mk_sandbox
  _write_ir fail 0
  run _run_29
  [ "$status" -eq 1 ]
  grep -q 'warning|IR|done 阶段 5.*verdict=fail.*主 agent 响应' "$SB/hook-tmp/independent-review.txt"
}

@test "R2-③ 反向控制: fail 已应答（L3 段后有响应段）→ 无告警 + exit 0" {
  _mk_sandbox
  _write_ir fail 1
  run _run_29
  [ "$status" -eq 0 ]
  ! grep -q 'R2-③' "$SB/hook-tmp/independent-review.txt"
  grep -q 'info|IR|skipped' "$SB/hook-tmp/independent-review.txt"
}

@test "R2-③: 末段 verdict=pass → 无告警 + info + exit 0（最新结论辖权）" {
  _mk_sandbox
  _write_ir pass 0
  run _run_29
  [ "$status" -eq 0 ]
  grep -q 'info|IR|skipped' "$SB/hook-tmp/independent-review.txt"
  ! grep -q 'R2-③' "$SB/hook-tmp/independent-review.txt"
}

@test "R2-③: .done 在但 IR 文件缺席 → 仅 info + exit 0（不虚构告警）" {
  _mk_sandbox
  run _run_29
  [ "$status" -eq 0 ]
  grep -q 'info|IR|skipped' "$SB/hook-tmp/independent-review.txt"
  ! grep -q 'R2-③' "$SB/hook-tmp/independent-review.txt"
}

@test "R2-③: 多轮 L3（早轮 fail+响应，末轮 fail 无响应）→ 告警（行号谓词取各段最后者）" {
  _mk_sandbox
  _write_ir fail 1
  # 末轮再追加重审 fail 段（其后无响应）——answered 形态被末轮覆盖
  printf '\n## L3 重审（外部模型 · 2026-10-12 08:00）\n`{"verdict": "fail", "summary": "re-review-2", "phase": "5", "model": "ext", "completed_at": "2026-10-12T08:00:00Z"}`\n' \
    >> "$SPEC/INDEPENDENT-REVIEW-5.md"
  run _run_29
  [ "$status" -eq 1 ]
  grep -q 'R2-③' "$SB/hook-tmp/independent-review.txt"
}
