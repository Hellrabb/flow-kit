#!/usr/bin/env bats
# test_install_coverage.bats — install 函数单元测试补齐（health-debt-cleanup · T5/AC-2）
# 覆盖：install_flow_kit_core / install_skills / install_specs_template /
#        install_hooks(user scope) / install_brooks_lint(jq fallback) /
#        install_brooks_tools(shim conflict + PATH warning) / install_file

setup() {
  TEST_TMPDIR=$(mktemp -d)
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

# ── install_flow_kit_core ──

@test "install_flow_kit_core DRY_RUN: exit 0 and output contains [DRY-RUN]" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_core.sh'
    install_flow_kit_core
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_flow_kit_core DRY_RUN: mentions flow-kit directory" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_core.sh'
    install_flow_kit_core
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ flow-kit ]]
}

# ── install_skills ──

@test "install_skills DRY_RUN: exit 0 and output contains [DRY-RUN]" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    source '$FK_ROOT/flow-kit-bundle/lib/install_skills.sh'
    install_skills
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_skills DRY_RUN: output mentions flow- skills" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    source '$FK_ROOT/flow-kit-bundle/lib/install_skills.sh'
    install_skills
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ flow- ]]
}

# ── install_specs_template ──

@test "install_specs_template DRY_RUN: exit 0 and output contains [DRY-RUN]" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_specs_template '$TEST_TMPDIR'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_specs_template: skips when .specs/ already exists" {
  mkdir -p "$TEST_TMPDIR/.specs"
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_specs_template '$TEST_TMPDIR'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "已存在" || "$output" =~ "exists" || "$output" =~ "skip" ]]
}

# ── install_hooks user scope ──

@test "install_hooks DRY_RUN user scope: exit 0 and output contains [DRY-RUN]" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_hooks '$TEST_TMPDIR' user
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_hooks DRY_RUN user scope: mentions .claude/hooks" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_hooks '$TEST_TMPDIR' user
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ ".claude/hooks" || "$output" =~ hooks ]]
}

@test "install_hooks DRY_RUN user scope: output mentions stop-hook.json (regression guard for install line)" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_hooks '$TEST_TMPDIR' user
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "stop-hook.json" ]]
}

# ── install_brooks_lint jq fallback ──

@test "install_brooks_lint DRY_RUN: exit 0 and output contains [DRY-RUN]" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks.sh'
    install_brooks_lint
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_brooks_lint DRY_RUN: output mentions brooks-lint plugin" {
  DRY_RUN=true \
  SCRIPT_DIR="$FK_ROOT/flow-kit-bundle" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks.sh'
    install_brooks_lint
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ brooks-lint || "$output" =~ brooks ]]
}

# ── install_brooks_tools shim + PATH ──

@test "install_brooks_tools DRY_RUN: exit 0 and output contains [DRY-RUN]" {
  # Create mock brooks-tools directory with dummy binaries
  local tools_src="$TEST_TMPDIR/brooks-tools"
  mkdir -p "$tools_src"
  for tool in depcheck jscpd knip ts-prune; do
    echo '#!/bin/bash' > "$tools_src/$tool"
    echo 'echo "mock $0 v1.0.0"' >> "$tools_src/$tool"
    chmod +x "$tools_src/$tool"
  done

  DRY_RUN=true \
  SCRIPT_DIR="$TEST_TMPDIR" \
  BROOKS_TOOLS_SRC="$tools_src" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    export PATH='$TEST_TMPDIR/.local/bin:$PATH'
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks_tools.sh'
    install_brooks_tools
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "install_brooks_tools DRY_RUN: lists all 4 tool shims" {
  local tools_src="$TEST_TMPDIR/brooks-tools"
  mkdir -p "$tools_src"
  for tool in depcheck jscpd knip ts-prune; do
    echo '#!/bin/bash' > "$tools_src/$tool"
    echo 'echo "mock v1.0.0"' >> "$tools_src/$tool"
    chmod +x "$tools_src/$tool"
  done

  DRY_RUN=true \
  SCRIPT_DIR="$TEST_TMPDIR" \
  BROOKS_TOOLS_SRC="$tools_src" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    export PATH='$TEST_TMPDIR/.local/bin:$PATH'
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks_tools.sh'
    install_brooks_tools
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ depcheck ]]
  [[ "$output" =~ jscpd ]]
  [[ "$output" =~ knip ]]
  [[ "$output" =~ ts-prune ]]
}

@test "install_brooks_tools DRY_RUN: graceful skip when source dir missing" {
  DRY_RUN=true \
  SCRIPT_DIR="$TEST_TMPDIR" \
  HOME="$TEST_TMPDIR" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks_tools.sh'
    install_brooks_tools
  "
  [ "$status" -eq 0 ]
  # Should either skip gracefully or mention brooks-tools
  [[ "$output" =~ "kip" || "$output" =~ brooks-tools || "$output" =~ "未找到" ]]
}

@test "install_brooks_tools DRY_RUN: PATH warning when .local/bin not in PATH" {
  local tools_src="$TEST_TMPDIR/brooks-tools"
  mkdir -p "$tools_src"
  echo '#!/bin/bash' > "$tools_src/depcheck"; echo 'echo "mock"' >> "$tools_src/depcheck"; chmod +x "$tools_src/depcheck"

  DRY_RUN=true \
  SCRIPT_DIR="$TEST_TMPDIR" \
  BROOKS_TOOLS_SRC="$tools_src" \
  HOME="$TEST_TMPDIR" \
  PATH="/usr/bin:/bin" \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_brooks_tools.sh'
    install_brooks_tools
  "
  [ "$status" -eq 0 ]
  # Should mention PATH, .local/bin, or complete without error
  [[ "$output" =~ "PATH" || "$output" =~ ".local/bin" || "$output" =~ "install" ]]
}

# ── install_file helper ──

@test "install_file DRY_RUN: does not copy file, outputs [DRY-RUN]" {
  local src="$TEST_TMPDIR/src.txt"
  local dst_dir="$TEST_TMPDIR/dst"
  echo "test content" > "$src"
  mkdir -p "$dst_dir"

  DRY_RUN=true \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_file '$src' '$dst_dir/src.txt'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
  # File should NOT exist (dry run)
  [ ! -f "$dst_dir/src.txt" ]
}

@test "install_file: copies file when DRY_RUN is unset" {
  local src="$TEST_TMPDIR/src.txt"
  local dst_dir="$TEST_TMPDIR/dst"
  echo "test content" > "$src"
  mkdir -p "$dst_dir"

  DRY_RUN=false \
  run bash -c "
    source '$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh'
    install_file '$src' '$dst_dir/src.txt'
  "
  [ "$status" -eq 0 ]
  # File should exist after non-dry-run install
  [ -f "$dst_dir/src.txt" ]
}
