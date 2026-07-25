#!/usr/bin/env bats
# test_gate_integrity.bats — gate-integrity change 主测试套（AC 1~6 + D7-D10）
# bats_require_minimum_version 1.10.0
#
# 注：bats `run` 在子 shell 执行，**继承 setup source 的函数**（status 反映 fn 真实退出码）。
# 期望非零的测试用 `run fn; [ "$status" -eq N ]`（禁 `if ! fn; then rc=$?`——`!` 反转 $? 致假阴/假绿 · L2 F1）。
# grep 类测试保留 run grep + $output。range-外条目 skip + 归因（TD-014/TD-016）。

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对 · L-025）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  local FK_ROOT="$d"
  BUNDLE_ROOT="$FK_ROOT/flow-kit-bundle"
  ARTIFACTS_LIB="$BUNDLE_ROOT/hooks/stop/lib/flow-kit-artifacts.sh"
  GATE_SH="$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"
  export PROJECT_ROOT="$TEST_TMPDIR"
  # HOOK_BASE_DIR 必须在 source ARTIFACTS_LIB 之前设（L2 F2/F6：否则 done-validation.sh 加载失败 → fk_validate_done_marker 未定义 → 127）
  export HOOK_BASE_DIR="$BUNDLE_ROOT/hooks/stop"

  mkdir -p "$TEST_TMPDIR/.specs/test-change"
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"phases_done":[],"gates":{"6→7":"pending"},"gate_config":{"6-review":"independent"}}}
EOF

  source "$ARTIFACTS_LIB" 2>/dev/null || true
  source "$GATE_SH" 2>/dev/null || true
  # 不再 set +e（TD-013 假绿根因 · 改用 run+$status 模式让断言检测生效）
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# Helper: 写合法 .done（含 KVP + session_id + artifacts · #8 修复：done-validation 强制 artifacts 含逗号）
write_valid_done() {
  local path="$1" phase="${2:-6}"
  cat > "$path" << EOF
phase=${phase}
change_id=test-change
written_by=review-subagent
written_at=2026-07-02T00:00:00Z
L2_verdict=pass
L3_verdict=pass
session_id=abc-session-123
artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-6.md
EOF
}

# ═══════════════════════════════════════════════════════════════════════
# AC-1 · .done 真实性（方案 A：作者性由 path-guard D7 前置保证）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-1 ① empty-done: 空 .done → deny return 2" {
  : > "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  run fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change write
  [ "$status" -eq 2 ]
}

@test "AC-1 ②③ forged-done: agent 写 .done → path-guard 拦截（方案 A · 作者性锚点）" {
  # 方案 A：agent 通过 Bash cat heredoc 写 .independent-review-*.done → _is_dotdone_write 命中 → return 0（deny）
  run _is_dotdone_write "cat > .specs/test-change/.independent-review-6.done << 'EOF'"
  [ "$status" -eq 0 ]
  # 验证 redirect 写也拦截
  run _is_dotdone_write "echo x > .specs/test-change/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "AC-1 ④ hijack-done: agent mv 写 .done → path-guard 拦截" {
  # 方案 A：agent 在子目录写 .done 后 mv 到目标 → _is_dotdone_write 命中 mv 模式 → exit 2
  run _is_dotdone_write "mv /tmp/fake/.independent-review-6.done .specs/x/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "AC-1 ⑤ tampered-done: agent sed -i 改 .done → path-guard 拦截" {
  # 方案 A：agent 用 sed -i 原地修改 .done → _is_dotdone_write 命中 sed -i 模式 → exit 2
  run _is_dotdone_write "sed -i 's/pass/fail/' .specs/x/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "AC-1 ⑥ gate-config-tamper: independent→false → fk_check_gate_config_tamper deny return 1" {
  cat > "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json" << 'EOF'
{"gate_config":{"6-review":"independent"},"created_at":"2026-07-01T00:00:00Z"}
EOF
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"gates":{},"gate_config":{"6-review":"false"}}}
EOF
  run fk_check_gate_config_tamper \
    "$TEST_TMPDIR/.flow-active" \
    "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json"
  [ "$status" -eq 1 ]
}

@test "T4 L2 裁决不匹配: .done L2_verdict=pass 与 INDEPENDENT-REVIEW.md L2 verdict=fail → transition deny return 2（R1 补 · L2-first gating 契约负向）" {
  write_valid_done "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  cat > "$TEST_TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-6.md" << 'REOF'
## L2 盲审
**Verdict**: fail
REOF
  run fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change transition
  [ "$status" -eq 2 ]
}

@test "D9 fail-close: 畸形 snapshot（jq 解析失败）→ fk_check_gate_config_tamper deny return 1" {
  cat > "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json" << 'EOF'
{broken json
EOF
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"gate_config":{"6-review":"independent"}}}
EOF
  run fk_check_gate_config_tamper \
    "$TEST_TMPDIR/.flow-active" \
    "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json"
  [ "$status" -eq 1 ]
}

@test "D9 兼容: snapshot 不存在 → fk_check_gate_config_tamper return 0（兼容历史 goal）" {
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"gate_config":{"6-review":"independent"}}}
EOF
  run fk_check_gate_config_tamper \
    "$TEST_TMPDIR/.flow-active" \
    "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# D9 · 正向（合法 .done + 合法握手 + session 一致 → return 0 放行）
# ═══════════════════════════════════════════════════════════════════════

@test "D9 正向: 合法 .done（KVP 完整 + L2_verdict=pass 与 INDEPENDENT-REVIEW-6.md 一致）→ transition return 0（方案 A: 删 T3 握手仅保留 T4 L2 比对）" {
  write_valid_done "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  cat > "$TEST_TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-6.md" << 'REOF'
## L2 盲审
**Verdict**: pass
REOF
  run fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change transition
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-3 · 5 站点覆盖（grep · 保留 run）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-3 · 5 站点: gate.sh 正则含 3/5/7" {
  run grep -cE '\^\(1\|2\|3\|5\|6\|7\)\$' "$GATE_SH"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-3 · 5 站点: PHASE_GATE_KEY_MAP in common.sh 含 3-task/5-test/7-integration" {
  local common_sh="${HOOK_BASE_DIR}/lib/common.sh"
  cnt=$(grep -cE '"3-task"|"5-test"|"7-integration"' "$common_sh" || echo "0")
  [ "$cnt" -ge 3 ]
}

# TD-016 fixed（fix-gate-phase-detection · 2026-07-09）：删除 artifacts.sh 正则/case 断言。
# flow-kit-artifacts.sh 已改 PHASE_ARTIFACTS 查表驱动（L-016），不再用 ^(1|2|3|5|6|7)$ 正则或 "3-task" case；
# gate.sh #9/#10 已覆盖 phase 检测，artifacts 重复断言且过时。

# ═══════════════════════════════════════════════════════════════════════
# D7 · path-guard _is_dotdone_write（方案 A · .done 作者性锚点）
# ═══════════════════════════════════════════════════════════════════════

@test "D7 path-guard: Bash 重定向 > .done → block (return 0)" {
  run _is_dotdone_write "echo x > .specs/x/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "D7 path-guard: Bash 追加 >> .done → block (return 0)" {
  run _is_dotdone_write "echo x >> .specs/x/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "D7 path-guard: Bash cp .done → block (return 0)" {
  run _is_dotdone_write "cp /tmp/x .specs/x/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "D7 path-guard: Bash sed -i .done → block (return 0)" {
  run _is_dotdone_write "sed -i s/a/b/ .specs/x/.independent-review-6.done"
  [ "$status" -eq 0 ]
}

@test "D7 path-guard: Bash exotic python-c → NOT block (return 1 · v1)" {
  run _is_dotdone_write 'python3 -c "open(\".specs/x/.independent-review-6.done\",\"w\")"'
  [ "$status" -eq 1 ]
}

@test "D7 path-guard: 非 .done 路径 → NOT block (return 1)" {
  run _is_dotdone_write "jq .interrupt=x .flow-active"
  [ "$status" -eq 1 ]
}

# ═══════════════════════════════════════════════════════════════════════
# 新增 · AC-6 payload 集成 + AC-4 L2-only 例外
# ═══════════════════════════════════════════════════════════════════════

@test "AC-6 payload: gate_config=both → agent Bash 写 .done → path-guard deny exit 2" {
  local flow_file="$TEST_TMPDIR/.flow-active"
  cat > "$flow_file" << 'FEOF'
{"phase":"6","change_id":"test-change","goal":{"gate_config":{"6-review":"both"}}}
FEOF
  run _gate_path_guard "Bash" "" "cat > .specs/test-change/.independent-review-6.done << 'EOF'"
  [ "$status" -eq 2 ]
}

@test "AC-4 L2-only: gate_config=L2 → agent 写 .done → path-guard 放行 exit 0" {
  local flow_file="$TEST_TMPDIR/.flow-active"
  cat > "$flow_file" << 'FEOF'
{"phase":"6","change_id":"test-change","goal":{"gate_config":{"6-review":"L2"}}}
FEOF
  run _gate_path_guard "Bash" "" "cat > .specs/test-change/.independent-review-6.done << 'EOF'"
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# D10 · phases_done 合法写入通路（is_phase_write · run + $status）
# ═══════════════════════════════════════════════════════════════════════

@test "D10 phases_done: is_phase_write 拦 .goal.phases_done 写信号 (return 0)" {
  # TD-014 fixed（fix-gate-phase-detection）：去 .flow-active.* 前缀后，字段在前的 jq 写命令正确 return 0。
  cmd='jq ".goal.phases_done += [\"3\"]" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active'
  run is_phase_write "$cmd"
  [ "$status" -eq 0 ]
}

@test "D10 phases_done: is_phase_write 仍拦 .phase= 写 (return 0 · 不回归)" {
  # TD-014 fixed：顶层 .phase= 写正确 return 0（不回归）。
  cmd='jq ".phase = 5" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active'
  run is_phase_write "$cmd"
  [ "$status" -eq 0 ]
}

@test "D10 phases_done: 纯读 .flow-active 不拦 (return 1)" {
  cmd='jq ".goal.phases_done" .flow-active'
  run is_phase_write "$cmd"
  [ "$status" -eq 1 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-6 · L3 机制：29号 不 dump + l3_token（grep · 保留 run）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-6 · 29号 不 dump 原始 API JSON" {
  F29="$BUNDLE_ROOT/hooks/stop/29-independent-review.sh"
  run grep -cE '<details>.*原始|<details>.*API' "$F29"
  [ "$output" = "0" ]
}

# TD-016 fixed（fix-gate-phase-detection · 2026-07-09）：删除 F29 sha256sum 断言。
# l3_token/sha256 设计全仓未实现（grep 无落地），断言基于未实现设计 → 过时。
# AC-6 #22（不 dump 原始 API JSON）仍覆盖 F29 行为。
