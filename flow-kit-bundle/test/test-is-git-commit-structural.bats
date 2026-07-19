#!/usr/bin/env bats
# test-is-git-commit-structural.bats — AC-H: is_git_commit/is_gh_pr_create 结构判定（ADR-008 / D2·H）
#
# 覆盖 AC-H 等价类（BUG-H 根治：旧正则不识 quoting/heredoc，写报告误拦）：
#   (a) 纯文本含敏感子串 → 不 deny（token0 非 git）
#   (b) echo "敏感子串" → 不 deny（token0=echo）
#   (c) heredoc/注释/写重定向 → 不 deny（write context / token0 非 git）
#   (d) 真实 git commit → deny（token0=git ∧ token1=commit）
#   (e) git commit + 管道/&&/||/; → deny（split 后子命令 token 序列）
#   (f) 反规避：源码无字面 'git commit'/'gh pr create' 白黑名单（grep 静态断言）
# + NFR-3 deny stderr 三要素（git commit → _gate_deny_reason，含 phase_name）
#
# 关联：ADR-008 / REQUIREMENT AC-H / DESIGN D2·R2/R3
# gate.sh 有 BASH_SOURCE guard（:475），source 不触发 main，可单元测试。

setup() {
  TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  REAL_PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
  GATE_SH="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh"
  TMP_DIR="$BATS_TMPDIR/is-git-commit-test-$$"
  mkdir -p "$TMP_DIR/.specs/test-change"
  export HOOK_BASE_DIR="$REAL_PROJECT_ROOT/flow-kit-bundle/hooks/pre-tool-use"
}

teardown() {
  rm -rf "$TMP_DIR"
}

_load_gate() {
  # shellcheck source=/dev/null
  source "$GATE_SH"
}

# ══ (a) 纯文本含敏感子串 → 不 deny ══

@test "AC-H (a): 审查报告正文含 'git commit' 子串 → not is_git_commit" {
  _load_gate
  run is_git_commit "审查报告：本次 git commit 流程符合规范"
  [ "$status" -ne 0 ]
}

@test "AC-H (a): '建议在 git commit 前跑测试' 纯文本 → not is_git_commit" {
  _load_gate
  run is_git_commit "建议在 git commit 前先跑测试"
  [ "$status" -ne 0 ]
}

# ══ (b) echo 敏感子串 → 不 deny ══

@test "AC-H (b): echo \"含 git commit 的字符串\" → not is_git_commit（token0=echo）" {
  _load_gate
  run is_git_commit 'echo "检查 git commit 步骤是否完整"'
  [ "$status" -ne 0 ]
}

# ══ (c) heredoc/注释/写重定向 → 不 deny ══

@test "AC-H (c1): heredoc 含 git commit → not is_git_commit（write context）" {
  _load_gate
  run is_git_commit $'cat > /tmp/r.md <<EOF\n含 git commit 字样\nEOF'
  [ "$status" -ne 0 ]
}

@test "AC-H (c2): 注释 '# git commit ...' → not is_git_commit（token0=#）" {
  _load_gate
  run is_git_commit "# 讨论 git commit 的注意事项"
  [ "$status" -ne 0 ]
}

@test "AC-H (c3): 写重定向 echo \"git commit\" > file → not is_git_commit（write context）" {
  _load_gate
  run is_git_commit 'echo "git commit" > /tmp/log.txt'
  [ "$status" -ne 0 ]
}

# ══ (d) 真实 git commit → deny ══

@test "AC-H (d): 真实 git commit -m → is_git_commit" {
  _load_gate
  run is_git_commit 'git commit -m "feat: add x"'
  [ "$status" -eq 0 ]
}

@test "AC-H (d): 裸 git commit → is_git_commit" {
  _load_gate
  run is_git_commit 'git commit'
  [ "$status" -eq 0 ]
}

# ══ (e) git commit + 管道/&&/; → deny（split）══

@test "AC-H (e1): echo x | git commit → is_git_commit（split |）" {
  _load_gate
  run is_git_commit 'echo x | git commit -m "y"'
  [ "$status" -eq 0 ]
}

@test "AC-H (e2): git commit && git push → is_git_commit（split &&）" {
  _load_gate
  run is_git_commit 'git commit -m "y" && git push'
  [ "$status" -eq 0 ]
}

@test "AC-H (e3): echo x ; git commit → is_git_commit（split ;）" {
  _load_gate
  run is_git_commit 'echo x ; git commit -m "y"'
  [ "$status" -eq 0 ]
}

# ══ (e) T-FIX-01 R1 补：重定向/多行真实 git commit → deny（AC-H(e) 漏拦修复回归）══
# 6-review L2 R1：原 _command_has_write_context 把重定向/多行当写上下文 → git commit 2>log 漏拦
# T-FIX-01 收紧（只 heredoc << → 写上下文），重定向/多行真实 commit 走 token 判定 deny

@test "AC-H (e4): git commit -m x 2> log → is_git_commit（stderr 重定向真实 commit · T-FIX-01）" {
  _load_gate
  run is_git_commit 'git commit -m "y" 2> /tmp/clog'
  [ "$status" -eq 0 ]
}

@test "AC-H (e5): git commit -m x > out → is_git_commit（stdout 重定向真实 commit · T-FIX-01）" {
  _load_gate
  run is_git_commit 'git commit -m "y" > /tmp/out'
  [ "$status" -eq 0 ]
}

@test "AC-H (e6): 多行 git commit → is_git_commit（T-FIX-01）" {
  _load_gate
  run is_git_commit $'echo a\ngit commit -m "y"'
  [ "$status" -eq 0 ]
}

@test "AC-H (e7-限制): git commit -F - <<EOF → not is_git_commit（heredoc message 真实 commit · 已知限制）" {
  _load_gate
  # 已知限制（T-FIX-01）：heredoc 作 commit message 的真实 commit 因 << 判为写上下文不 deny。
  # 罕见（agent 极少用 heredoc 写 commit message），v2 加密签名根治。此处锁定当前行为防回归。
  run is_git_commit $'git commit -F - <<EOF\nmsg\nEOF'
  [ "$status" -ne 0 ]
}

@test "AC-H (e8-限制): git commit -m \"$(cat <<EOM)\" → not is_git_commit（多行 message 惯用法 · RR3）" {
  _load_gate
  # RR3（L2 重审）：heredoc << 短路覆盖的 residual regression——多行 message 惯用法也漏拦。
  # 锁定当前 not-deny 行为（v2 加密签名根治）。诚实登记 residual regression。
  run is_git_commit $'git commit -m "$(cat <<EOM\nmulti-line msg\nEOM)"'
  [ "$status" -ne 0 ]
}

@test "AC-H (e9-限制): heredoc 管道喂 commit → << 短路 not is_git_commit（RR3）" {
  _load_gate
  # RR3（L2 重审）：cat <<EOF | xargs git commit 模式因 << 短路判写上下文不 deny。
  # 锁定 not-deny（residual regression，v2 加密签名根治）。
  run is_git_commit $'cat <<EOF | xargs -I {} git commit -m {}\nfeat\nEOF'
  [ "$status" -ne 0 ]
}

# ══ gh pr create 同结构 ══

@test "AC-H (d-gh): gh pr create → is_gh_pr_create" {
  _load_gate
  run is_gh_pr_create 'gh pr create --title "x"'
  [ "$status" -eq 0 ]
}

@test "AC-H (b-gh): echo \"gh pr create\" → not is_gh_pr_create" {
  _load_gate
  run is_gh_pr_create 'echo "讨论 gh pr create 流程"'
  [ "$status" -ne 0 ]
}

# ══ (f) 反规避：源码无白/黑名单字面量 ══

@test "AC-H (f): 源码不含字面 'git commit'/'gh pr create' 白黑名单（token 序列判定）" {
  # 排除 deny_reason= 标签（gate.sh 故意保留的可读标签）+ 注释行。剩余 = 白黑名单字面量（应空）
  run bash -c "grep -nE 'git[[:space:]]+commit|gh[[:space:]]+pr[[:space:]]+create' \"$GATE_SH\" | grep -vE 'deny_reason=|^[0-9]+:[[:space:]]*#'"
  [ -z "$output" ]
}

# ══ NFR-3: deny stderr 三要素（git commit → _gate_deny_reason，T02 改 is_git_commit 后回归）══

@test "NFR-3: phase1 git commit 无.done → deny exit2 + stderr 三要素（is_git_commit 结构判定回归）" {
  local specs_dir="$TMP_DIR/.specs/test-change"
  jq -n --argjson gc '{"1-requirement":"both"}' \
    '{change_id:"test-change",phase:1,goal:{scope:"pipeline",current_phase:"1",gate_config:$gc,phases_done:["0"],gates:{"0→1":"passed","1→2":"pending"},auto_advance:false}}' \
    > "$TMP_DIR/.flow-active"
  jq -n --argjson gc '{"1-requirement":"both"}' '{gate_config:$gc,created_at:"2026-07-18"}' > "$specs_dir/.goal-snapshot.json"
  rm -f "$specs_dir"/.independent-review-*.done "$specs_dir"/INDEPENDENT-REVIEW-*.md 2>/dev/null || true
  jq -n --arg c 'git commit -m test' --arg cwd "$TMP_DIR" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' > "$TMP_DIR/payload.json"
  run bash -c "PROJECT_ROOT='$TMP_DIR' bash '$GATE_SH' < '$TMP_DIR/payload.json' 2>'$TMP_DIR/stderr.log'"
  [ "$status" -eq 2 ]
  grep -q "1-requirement" "$TMP_DIR/stderr.log"
  grep -q "\.independent-review-1\.done" "$TMP_DIR/stderr.log"
  grep -q "独立 review" "$TMP_DIR/stderr.log"
}

# ══ R2 fail-close（T-FIX-02 · 6-review L2）：common.sh 加载失败 → deny exit2 ══

@test "R2 fail-close: HOOK_BASE_DIR 错（common.sh 加载失败）→ exit 2 + stderr 告警（T-FIX-02）" {
  local specs_dir="$TMP_DIR/.specs/test-change"
  jq -n --argjson gc '{"1-requirement":"both"}' \
    '{change_id:"test-change",phase:1,goal:{scope:"pipeline",current_phase:"1",gate_config:$gc,phases_done:["0"],gates:{"0→1":"passed","1→2":"pending"},auto_advance:false}}' \
    > "$TMP_DIR/.flow-active"
  jq -n --argjson gc '{"1-requirement":"both"}' '{gate_config:$gc}' > "$specs_dir/.goal-snapshot.json"
  jq -n --arg c 'git commit -m test' --arg cwd "$TMP_DIR" '{tool_name:"Bash",tool_input:{command:$c},cwd:$cwd}' > "$TMP_DIR/p.json"
  # 错 HOOK_BASE_DIR → source COMMON_LIB 失败 → fk_phase_gate_key 未定义 → fail-close exit 2（不再 fail-open exit 0）
  run bash -c "HOOK_BASE_DIR=/tmp/nonexistent-$$ PROJECT_ROOT='$TMP_DIR' bash '$GATE_SH' < '$TMP_DIR/p.json' 2>'$TMP_DIR/r2.log'"
  [ "$status" -eq 2 ]
  grep -q "fail-close" "$TMP_DIR/r2.log"
  grep -q "fk_phase_gate_key" "$TMP_DIR/r2.log"
}
