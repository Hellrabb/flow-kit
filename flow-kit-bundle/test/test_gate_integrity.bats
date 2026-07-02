#!/usr/bin/env bats
# test_gate_integrity.bats — gate-integrity change 主测试套（AC 1~6 + D7-D10）
# bats_require_minimum_version 1.10.0
#
# 注意：bats `run` 在子 shell 执行，不继承 setup source 的函数（→ 127 Command not found）。
# 故函数测试（fk_validate_done_marker / is_handshake_write / is_phase_write /
# fk_check_gate_config_tamper）直接调用 + $? 断言；grep 类测试保留 run。

setup() {
  TEST_TMPDIR=$(mktemp -d)
  BUNDLE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  ARTIFACTS_LIB="$BUNDLE_ROOT/hooks/stop/lib/flow-kit-artifacts.sh"
  GATE_SH="$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"
  export PROJECT_ROOT="$TEST_TMPDIR"

  mkdir -p "$TEST_TMPDIR/.specs/test-change"
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"phases_done":[],"gates":{"6→7":"pending"},"gate_config":{"6-review":"independent"}}}
EOF

  source "$ARTIFACTS_LIB" 2>/dev/null || true
  source "$GATE_SH" 2>/dev/null || true
  set +e  # 函数 return 2 不触发 set -e
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# Helper: 写合法 .done（含 KVP + session_id）
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
EOF
}

# Helper: 写合法握手（per-phase 格式 · phase=6, written_by=stop-hook-29, verdict=pass）
write_valid_handshake() {
  cat > "$PROJECT_ROOT/.flow-active.independent-review" << 'EOF'
{"6":{"phase":"6","status":"done","verdict":"pass","written_by":"stop-hook-29","written_at":"2026-07-02T00:00:00Z"}}
EOF
}

# ═══════════════════════════════════════════════════════════════════════
# AC-1 · .done 真实性（6 类威胁 · fk_validate_done_marker deny=return 2）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-1 ① empty-done: 空 .done → deny return 2" {
  : > "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change write
  [ $? -eq 2 ]
}

@test "AC-1 ②③ forged-done: 伪造 KVP + 无握手 → transition deny return 2" {
  write_valid_done "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change transition
  [ $? -eq 2 ]
}

@test "AC-1 ④ hijack-done: 跨 session .done → T3b session_id 不匹配 deny" {
  write_valid_done "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  write_valid_handshake
  export CLAUDE_CODE_SESSION_ID=xyz-different-session
  fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change transition
  [ $? -eq 2 ]
}

@test "AC-1 ⑤ tampered-done: L2_verdict 与 INDEPENDENT-REVIEW.md 不一致 → T4 deny" {
  write_valid_done "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  write_valid_handshake
  export CLAUDE_CODE_SESSION_ID=abc-session-123
  cat > "$TEST_TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-6.md" << 'EOF'
## Verdict: fail
EOF
  fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change transition
  [ $? -eq 2 ]
}

@test "AC-1 ⑥ gate-config-tamper: independent→false → fk_check_gate_config_tamper deny return 1" {
  cat > "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json" << 'EOF'
{"gate_config":{"6-review":"independent"},"created_at":"2026-07-01T00:00:00Z"}
EOF
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"gates":{},"gate_config":{"6-review":"false"}}}
EOF
  fk_check_gate_config_tamper \
    "$TEST_TMPDIR/.flow-active" \
    "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json"
  [ $? -eq 1 ]
}

@test "D9 fail-close: 畸形 snapshot（jq 解析失败）→ fk_check_gate_config_tamper deny return 1" {
  # 畸形 snapshot（jq 解析失败）→ fail-close deny（G1 D7 · 不能靠制造 hook 错误放行）
  cat > "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json" << 'EOF'
{broken json
EOF
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"gate_config":{"6-review":"independent"}}}
EOF
  fk_check_gate_config_tamper \
    "$TEST_TMPDIR/.flow-active" \
    "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json"
  [ $? -eq 1 ]
}

@test "D9 兼容: snapshot 不存在 → fk_check_gate_config_tamper return 0（兼容历史 goal）" {
  # snapshot 文件不存在 → 兼容历史（G3 · return 0 放行，不 block）
  cat > "$TEST_TMPDIR/.flow-active" << 'EOF'
{"phase":"6","change_id":"test-change","goal":{"gate_config":{"6-review":"independent"}}}
EOF
  fk_check_gate_config_tamper \
    "$TEST_TMPDIR/.flow-active" \
    "$TEST_TMPDIR/.specs/test-change/.goal-snapshot.json"
  [ $? -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# D9 · 正向（合法 .done + 合法握手 + session 一致 → return 0 放行）
# ═══════════════════════════════════════════════════════════════════════

@test "D9 正向: 合法 .done + 合法握手 + session 一致 → fk_validate_done_marker return 0" {
  write_valid_done "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done"
  write_valid_handshake
  export CLAUDE_CODE_SESSION_ID=abc-session-123
  fk_validate_done_marker \
    "$TEST_TMPDIR/.specs/test-change/.independent-review-6.done" 6 test-change transition
  [ $? -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-3 · 5 站点覆盖（grep · 保留 run）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-3 · 5 站点: gate.sh 正则含 3/5/7" {
  run grep -cE '\^\(1\|2\|3\|5\|6\|7\)\$' "$GATE_SH"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-3 · 5 站点: gate.sh case 含 3-task/5-test/7-integration" {
  cnt=$(grep -cE '"3-task"|"5-test"|"7-integration"' "$GATE_SH" || echo "0")
  [ "$cnt" -ge 3 ]
}

@test "AC-3 · 5 站点: artifacts.sh 正则含 3/5/7" {
  run grep -cE '\^\(1\|2\|3\|5\|6\|7\)\$' "$ARTIFACTS_LIB"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "AC-3 · 5 站点: artifacts.sh case 含 3-task/5-test/7-integration" {
  cnt=$(grep -cE '"3-task"|"5-test"|"7-integration"' "$ARTIFACTS_LIB" || echo "0")
  [ "$cnt" -ge 3 ]
}

# ═══════════════════════════════════════════════════════════════════════
# D7 · path-guard is_handshake_write（直接调用 + $?）
# ═══════════════════════════════════════════════════════════════════════

@test "D7 path-guard: Bash 重定向 > 握手文件 → block (return 0)" {
  is_handshake_write "echo x > .flow-active.independent-review"
  [ $? -eq 0 ]
}

@test "D7 path-guard: Bash 追加 >> 握手文件 → block (return 0)" {
  is_handshake_write "echo x >> .flow-active.independent-review"
  [ $? -eq 0 ]
}

@test "D7 path-guard: Bash cp 握手文件 → block (return 0)" {
  is_handshake_write "cp /tmp/x .flow-active.independent-review"
  [ $? -eq 0 ]
}

@test "D7 path-guard: Bash sed -i 握手文件 → block (return 0)" {
  is_handshake_write "sed -i s/a/b/ .flow-active.independent-review"
  [ $? -eq 0 ]
}

@test "D7 path-guard: Bash exotic python-c → NOT block (return 1 · v1)" {
  is_handshake_write 'python3 -c "open(\".flow-active.independent-review\",\"w\")"'
  [ $? -eq 1 ]
}

@test "D7 path-guard: 非握手路径 → NOT block (return 1)" {
  is_handshake_write "jq .interrupt=x .flow-active"
  [ $? -eq 1 ]
}

# ═══════════════════════════════════════════════════════════════════════
# D10 · phases_done 合法写入通路（is_phase_write 直接调用 + $?）
# ═══════════════════════════════════════════════════════════════════════

@test "D10 phases_done: is_phase_write 拦 .goal.phases_done 写信号 (return 0)" {
  cmd='jq ".goal.phases_done += [\"3\"]" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active'
  is_phase_write "$cmd"
  [ $? -eq 0 ]
}

@test "D10 phases_done: is_phase_write 仍拦 .phase= 写 (return 0 · 不回归)" {
  cmd='jq ".phase = 5" .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active'
  is_phase_write "$cmd"
  [ $? -eq 0 ]
}

@test "D10 phases_done: 纯读 .flow-active 不拦 (return 1)" {
  cmd='jq ".goal.phases_done" .flow-active'
  is_phase_write "$cmd"
  [ $? -eq 1 ]
}

# ═══════════════════════════════════════════════════════════════════════
# AC-6 · L3 机制：29号 不 dump + l3_token（grep · 保留 run）
# ═══════════════════════════════════════════════════════════════════════

@test "AC-6 · 29号 不 dump 原始 API JSON" {
  F29="$BUNDLE_ROOT/hooks/stop/29-independent-review.sh"
  run grep -cE '<details>.*原始|<details>.*API' "$F29"
  [ "$output" = "0" ]
}

@test "AC-6 · 29号 l3_token sha256 实现" {
  F29="$BUNDLE_ROOT/hooks/stop/29-independent-review.sh"
  run grep -c 'sha256sum' "$F29"
  [ "$output" -ge 1 ]
}
