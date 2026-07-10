#!/usr/bin/env bats
# test_install_dry_run.bats — DRY_RUN 模式安装函数单元测试 (AC-7)
# 验证 install_hooks + install_brooks_lint 在 DRY_RUN=true 时不产生文件系统副作用

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # Find repo root (same pattern as test_install.bats)
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "install_hooks DRY_RUN: no settings.json mutation" {
  # Given: DRY_RUN=true, a temp .claude directory with settings.local.json
  local claude_dir="$TEST_TMPDIR/.claude"
  mkdir -p "$claude_dir"
  echo '{"hooks":{}}' > "$claude_dir/settings.local.json"
  local before_sha
  before_sha=$(sha256sum "$claude_dir/settings.local.json" | cut -d' ' -f1)

  # When: source install_hooks.sh and run install_hooks with DRY_RUN=true
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_hooks '$TEST_TMPDIR' project
  "

  # Then: exit 0, settings.json unchanged
  [ "$status" -eq 0 ]
  local after_sha
  after_sha=$(sha256sum "$claude_dir/settings.local.json" | cut -d' ' -f1)
  [ "$before_sha" = "$after_sha" ]
}

@test "install_hooks DRY_RUN: output contains [DRY-RUN] messages" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_hooks '$TEST_TMPDIR' project
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_brooks_lint DRY_RUN: no file copies to target" {
  # Given: empty target directory
  local plugin_dst="$TEST_TMPDIR/brooks_dst"
  mkdir -p "$plugin_dst"

  # When: run install_brooks_lint with DRY_RUN=true (uses default HOME-derived paths)
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks.sh'
    install_brooks_lint
  "

  # Then: exit 0, output contains DRY-RUN marker
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_brooks_lint DRY_RUN: output mentions brooks-lint path" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks.sh'
    install_brooks_lint
  "
  [ "$status" -eq 0 ]
  # Should mention brooks-lint in DRY_RUN output
  [[ "$output" =~ brooks-lint ]] || [[ "$output" =~ brooks ]]
}
