#!/usr/bin/env bats

# test_archive_commit_gate.bats — archive-commit-gate change 回归测试
# 覆盖：34-archive-commit-check.sh 骨架 + pre-commit.sh 四分支 + flow-kit-resume.sh archive-uncommitted elif

setup() {
  # 向上查找 flow-kit-bundle/hooks/（对齐 test_fk_resolve_model.bats 模式 · TD-012）
  BATS_ROOT="${BATS_TEST_DIRNAME:-.}"
  while [ ! -d "$BATS_ROOT/flow-kit-bundle/hooks" ] && [ "$BATS_ROOT" != "/" ]; do
    BATS_ROOT="$(dirname "$BATS_ROOT")"
  done
  export PROJECT_ROOT=$(mktemp -d)
  export HOOK_BASE_DIR="$BATS_ROOT/flow-kit-bundle/hooks"
}

teardown() {
  rm -rf "$PROJECT_ROOT"
}

# ── T01: pre-commit.sh 四分支 ──

@test "pre-commit.sh: no Makefile → skip message" {
  cd "$PROJECT_ROOT"
  run bash "$HOOK_BASE_DIR/pre-commit/pre-commit.sh" 2>&1 || true
  [[ "$output" == *"no Makefile"* ]]
}

@test "pre-commit.sh: make test fail → reject message" {
  cd "$PROJECT_ROOT"
  cat > Makefile <<'EOF'
test:
	@echo "test fail" >&2
	exit 1
EOF
  run bash "$HOOK_BASE_DIR/pre-commit/pre-commit.sh" 2>&1 || true
  [[ "$output" == *"test failed"* ]]
}

@test "pre-commit.sh: syntax valid (bash -n)" {
  run bash -n "$HOOK_BASE_DIR/pre-commit/pre-commit.sh"
  [ "$status" -eq 0 ]
}

# ── T02: 34-archive-commit-check.sh 骨架 ──

@test "34-archive-commit-check.sh: syntax valid (bash -n)" {
  run bash -n "$HOOK_BASE_DIR/stop/34-archive-commit-check.sh"
  [ "$status" -eq 0 ]
}

@test "34-archive-commit-check.sh: module_enabled guard present" {
  grep -q 'module_enabled.*archive_commit_check' "$HOOK_BASE_DIR/stop/34-archive-commit-check.sh"
}

@test "34-archive-commit-check.sh: run_check callback present" {
  grep -q 'run_check.*archive_commit_check.*_check_archive_commit_body' "$HOOK_BASE_DIR/stop/34-archive-commit-check.sh"
}

@test "34-archive-commit-check.sh: dual-mode detection (pipeline + single-phase)" {
  grep -q 'pipeline' "$HOOK_BASE_DIR/stop/34-archive-commit-check.sh"
  grep -q 'arch_mtime' "$HOOK_BASE_DIR/stop/34-archive-commit-check.sh"
}

@test "34-archive-commit-check.sh: type-guarded clear present" {
  grep -q 'cur_type.*CORRECTION_TYPE_ARCHIVE_UNCOMMITTED' "$HOOK_BASE_DIR/stop/34-archive-commit-check.sh"
}

# ── T03: CORRECTION_TYPE_ARCHIVE_UNCOMMITTED 常量 ──

@test "correction-types.sh: CORRECTION_TYPE_ARCHIVE_UNCOMMITTED defined" {
  grep -q 'CORRECTION_TYPE_ARCHIVE_UNCOMMITTED' "$HOOK_BASE_DIR/stop/lib/correction-types.sh"
}

# ── T04: 00-gate + stop-hook.json + HOOK_MODULE_NAMES 注册 ──

@test "00-gate.sh: module 34 registered" {
  grep -q '34-archive-commit-check' "$HOOK_BASE_DIR/stop/00-gate.sh"
}

@test "stop-hook.json: archive_commit_check module enabled" {
  grep -q 'archive_commit_check' "$HOOK_BASE_DIR/config/stop-hook.json"
}

@test "common.sh: HOOK_MODULE_NAMES includes 34" {
  grep -q '34-archive-commit-check' "$HOOK_BASE_DIR/stop/lib/common.sh"
}

# ── T06: flow-kit-resume.sh archive-uncommitted elif ──

@test "flow-kit-resume.sh: archive-uncommitted elif branch present" {
  grep -q 'archive-uncommitted' "$HOOK_BASE_DIR/session-start/flow-kit-resume.sh"
}

@test "flow-kit-resume.sh: jq 括号修复 (F6)" {
  grep -q 'violations\[0\].files.*violations.*length' "$HOOK_BASE_DIR/session-start/flow-kit-resume.sh"
}

# ── T05: install.sh deploy_pre_commit ──

@test "install.sh: --yes flag present" {
  grep -q 'FLOW_KIT_YES' "$BATS_ROOT/flow-kit-bundle/install.sh"
}

@test "install_hooks.sh: deploy_pre_commit function defined" {
  grep -q 'deploy_pre_commit' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh"
}

@test "install_hooks.sh: deploy_pre_commit called in install_hooks body" {
  sed -n '/^install_hooks()/,/^}/p' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh" | grep -q 'deploy_pre_commit'
}

@test "package-flow-kit.sh: pre-commit glob in Part C" {
  grep -q 'pre-commit' "$BATS_ROOT/package-flow-kit.sh"
}

@test "validate_staging.sh: pre-commit pattern in Part C" {
  grep -q 'pre-commit' "$BATS_ROOT/flow-kit-bundle/lib/validate_staging.sh"
}

# ── T07: 7-integration 步骤 5.1 + commit-protocol ──

@test "7-integration.md: step 5.1 archive commit present" {
  grep -q '5\.1.*归档' "$BATS_ROOT/flow-kit-bundle/flow-kit/prompts/7-integration.md"
}

@test "7-integration.md: ARCHIVE_BASE_SHA present" {
  grep -q 'ARCHIVE_BASE_SHA' "$BATS_ROOT/flow-kit-bundle/flow-kit/prompts/7-integration.md"
}

@test "commit-protocol.md: archive commit classification present" {
  grep -q '归档 commit' "$BATS_ROOT/flow-kit-bundle/flow-kit/reference/commit-protocol.md"
}

# ── T05+: deploy_pre_commit user/project scope 行为测试（pre-commit-user-scope）──

@test "deploy_pre_commit: user scope (no .git) installs source file only" {
  local tmp_home=$(mktemp -d)
  local bundle_dir="$BATS_ROOT/flow-kit-bundle"
  export SCRIPT_DIR="$bundle_dir"
  source "$bundle_dir/lib/install_hooks.sh"
  local project="$tmp_home"
  local hook_dst="$tmp_home/.claude/hooks"
  deploy_pre_commit
  [ -f "$tmp_home/.claude/hooks/pre-commit/pre-commit.sh" ]
  [ ! -d "$tmp_home/.git" ]
  [ ! -e "$tmp_home/.git/hooks/pre-commit" ]
  rm -rf "$tmp_home"
}

@test "deploy_pre_commit: project scope (has .git) creates symlink → source" {
  local tmp_repo=$(mktemp -d)
  mkdir -p "$tmp_repo/.git/hooks"
  local bundle_dir="$BATS_ROOT/flow-kit-bundle"
  export SCRIPT_DIR="$bundle_dir"
  source "$bundle_dir/lib/install_hooks.sh"
  local project="$tmp_repo"
  local hook_dst="$tmp_repo/.claude/hooks"
  deploy_pre_commit
  [ -f "$tmp_repo/.claude/hooks/pre-commit/pre-commit.sh" ]
  [ -L "$tmp_repo/.git/hooks/pre-commit" ]
  readlink "$tmp_repo/.git/hooks/pre-commit" | grep -q 'pre-commit/pre-commit.sh'
  rm -rf "$tmp_repo"
}
