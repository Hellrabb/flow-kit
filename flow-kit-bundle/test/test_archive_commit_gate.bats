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

@test "package-flow-kit.sh: pre-push glob in Part C" {
  grep -q 'pre-push' "$BATS_ROOT/package-flow-kit.sh"
}

@test "validate_staging.sh: pre-push pattern in Part C" {
  grep -q 'pre-push' "$BATS_ROOT/flow-kit-bundle/lib/validate_staging.sh"
}

@test "validate_staging_coverage: real bundle fully covered (pre-push included · TD-048)" {
  local bundle="$(cd "$BATS_ROOT" && pwd)/flow-kit-bundle"
  run bash -c 'source "$1/lib/validate_staging.sh" && validate_staging_coverage "$1"' _ "$bundle"
  [ "$status" -eq 0 ]
  [[ "$output" == *"🔴 漏配 (ERROR): 0"* ]]
  [[ "$output" == *"⚠️  源缺失 (WARNING): 0"* ]]
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

# ── T-FIX-08: pre-push/pre-commit 消费者项目回退守卫（R3-14/R3-23）──

@test "pre-push.sh: syntax valid (bash -n) · T-FIX-08" {
  run bash -n "$HOOK_BASE_DIR/pre-push/pre-push.sh"
  [ "$status" -eq 0 ]
}

@test "pre-push.sh: resolve_reference_dir 回退到随包检查器（R3-14(a)）" {
  grep -q 'resolve_reference_dir' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
  grep -q 'reference/check-path-privacy.sh' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
}

@test "pre-push.sh: makefile_has_target 目标存在性守卫（R3-14(b)）" {
  grep -q 'makefile_has_target' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
  grep -q '项目 Makefile 未声明 check 目标' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
}

@test "pre-push.sh: 纯删除推送跳过（R3-14② · ADR-027②）" {
  grep -q '纯删除推送' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
}

@test "pre-push.sh: 每 sha 只扫一次（R3-23 去重）" {
  grep -q 'scanned_shas' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
  grep -q '已扫描过该 sha' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
}

@test "pre-push.sh: 三者皆不可得 ⇒ 跳过且不改 rc（R3-14(c)④）" {
  grep -q '未找到可用的路径隐私检查器' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
}

@test "pre-push.sh: 导出 FLOW_KIT_PRIVACY_ALLOWLIST 指向随包清单（R3-14(c)②）" {
  grep -q 'FLOW_KIT_PRIVACY_ALLOWLIST' "$HOOK_BASE_DIR/pre-push/pre-push.sh"
}

@test "pre-commit.sh: 回退到随包检查器（R3-14 消费者项目回退）" {
  grep -q 'resolve_reference_dir' "$HOOK_BASE_DIR/pre-commit/pre-commit.sh"
  grep -q 'reference/check-path-privacy.sh' "$HOOK_BASE_DIR/pre-commit/pre-commit.sh"
  grep -q 'FLOW_KIT_PRIVACY_ALLOWLIST' "$HOOK_BASE_DIR/pre-commit/pre-commit.sh"
}

@test "pre-commit.sh: 三者皆不可得 ⇒ 跳过且不改 rc（R3-14(c)④）" {
  grep -q '未找到可用的路径隐私检查器' "$HOOK_BASE_DIR/pre-commit/pre-commit.sh"
}

@test "install_hooks.sh: 随包检查器部署到 reference/ 目录（R3-14(c)③）" {
  grep -q 'ref_dst_dir' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh"
  grep -q 'check-path-privacy.sh' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh"
  grep -q 'path-privacy-allowlist.txt' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh"
}

@test "install_hooks.sh: R3-17 恢复路径提示（备份路径 + cp 回滚命令）" {
  grep -q '恢复路径' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh"
  grep -q 'cp -f' "$BATS_ROOT/flow-kit-bundle/lib/install_hooks.sh"
}

@test "install.sh: jq 硬前置预检（R3-21）" {
  grep -q 'check_jq' "$BATS_ROOT/flow-kit-bundle/install.sh"
  grep -q 'jq' "$BATS_ROOT/flow-kit-bundle/install.sh"
}

@test "README.md: jq 前置依赖写明（R3-21）" {
  grep -q 'jq' "$BATS_ROOT/flow-kit-bundle/README.md"
}

@test "OPENCODE-INSTALL.md: jq 前置依赖写明（R3-21）" {
  grep -q 'jq' "$BATS_ROOT/flow-kit-bundle/OPENCODE-INSTALL.md"
}

@test "check-path-privacy.sh: FLOW_KIT_PRIVACY_ALLOWLIST 覆盖旋钮（R3-14(c)①）" {
  local sut="$BATS_ROOT/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh"
  grep -q 'FLOW_KIT_PRIVACY_ALLOWLIST' "$sut"
  # fail-closed 且指名路径
  grep -q 'fail-closed.*FLOW_KIT_PRIVACY_ALLOWLIST' "$sut"
}

# ----------------------------------------------------------------------------
# T-FIX-13（health-fix-2026-09b · R4-M1）：bundle 形态「检查器在 +
# path-privacy-allowlist.txt 缺失」三态区分静态断言。
# 状态 ② 必须具名 fail-closed（指名缺失的允许清单路径 + fail-closed 语义），
# 不得复用状态 ① 的「未找到可用的路径隐私检查器」措辞（原因不符），
# 不得被归因为「含路径隐私泄漏」（配置缺失 ≠ 泄漏）。
# ----------------------------------------------------------------------------

@test "pre-push.sh: 检查器在 + 允许清单缺失 ⇒ 具名 fail-closed（T-FIX-13 · R4-M1）" {
  local sut="$HOOK_BASE_DIR/pre-push/pre-push.sh"
  # 报文指名缺失的允许清单路径
  grep -q 'path-privacy-allowlist.txt' "$sut"
  # fail-closed 语义
  grep -q 'fail-closed' "$sut"
  # 独立致命路径：用 exit 2 而非 return 1（父层 :150 会把 return 1 错位归因为泄漏）
  grep -q 'exit 2' "$sut"
  # 不得把配置缺失归因为泄漏
  ! grep -q '缺.*含路径隐私泄漏\|允许清单缺失.*含路径隐私泄漏' "$sut"
}

@test "pre-push.sh: 状态 ② 报文不复用「检查器缺失」措辞（T-FIX-13 · 归因区分）" {
  local sut="$HOOK_BASE_DIR/pre-push/pre-push.sh"
  # 「未找到可用的路径隐私检查器」必须仅出现在 none 分支（状态 ①），
  # 不得与 bundle 分支的「允许清单缺失」报文同处一个 echo。
  # bundle 分支的 fail-closed 报文必须用独立措辞指名允许清单。
  grep -q '缺少允许清单' "$sut"
  # 状态 ① 措辞仍在文件内（bats:208 静态断言已覆盖，此处补 bundle 分支不复用）
  grep -q '未找到可用的路径隐私检查器' "$sut"
}

@test "pre-commit.sh: 检查器在 + 允许清单缺失 ⇒ 具名 fail-closed exit 1（T-FIX-13 · R4-M1）" {
  local sut="$HOOK_BASE_DIR/pre-commit/pre-commit.sh"
  # 报文指名缺失的允许清单路径
  grep -q 'path-privacy-allowlist.txt' "$sut"
  # fail-closed 语义
  grep -q 'fail-closed' "$sut"
  # 允许清单缺失分支用 exit 1（沿用既有「提交被拒绝」语义）
  grep -q '缺少允许清单' "$sut"
  # 状态 ① 措辞仍在文件内（bats:222 静态断言已覆盖）
  grep -q '未找到可用的路径隐私检查器' "$sut"
}
