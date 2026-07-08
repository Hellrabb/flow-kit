#!/usr/bin/env bats
# test_install_brooks_tools.bats — brooks-lint npm 工具安装测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 模拟 brooks-tools 源目录结构
  mkdir -p "$TEST_TMPDIR/brooks-tools/bin"
  for tool in depcheck jscpd knip ts-prune; do
    cat > "$TEST_TMPDIR/brooks-tools/bin/$tool" << 'TOOLEOF'
#!/bin/sh
echo "$(basename "$0") mock 1.0.0"
TOOLEOF
    chmod +x "$TEST_TMPDIR/brooks-tools/bin/$tool"
  done

  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  local FK_ROOT="$d"
  LIB_FILE="$FK_ROOT/flow-kit-bundle/lib/install_brooks_tools.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── 语法检查 ──────────────────────────────────────────────────────

@test "install_brooks_tools.sh passes syntax check" {
  run bash -n "$LIB_FILE"
  [ "$status" -eq 0 ]
}

# ── DRY_RUN 模式 ───────────────────────────────────────────────────

@test "DRY_RUN mode prints expected output" {
  SCRIPT_DIR="$TEST_TMPDIR" \
  DRY_RUN=true \
  run bash -c "source '$LIB_FILE' && install_brooks_tools"
  [ "$status" -eq 0 ]
  [[ "$output" =~ \[DRY-RUN\] ]]
}

# ── Node.js 缺失处理 ──────────────────────────────────────────────

@test "Node.js detection shows version when available" {
  SCRIPT_DIR="$TEST_TMPDIR" \
  DRY_RUN=true \
  run bash -c "source '$LIB_FILE' && install_brooks_tools"
  # Node.js 在当前环境可用 → 应输出版本号
  [[ "$output" =~ Node\.js ]]
}

# ── Shim 生成验证（DRY_RUN 模式）──────────────────────────────────

@test "DRY_RUN lists shim creation for all 4 tools" {
  SCRIPT_DIR="$TEST_TMPDIR" \
  DRY_RUN=true \
  run bash -c "source '$LIB_FILE' && install_brooks_tools"
  [ "$status" -eq 0 ]
  [[ "$output" =~ depcheck ]]
  [[ "$output" =~ jscpd ]]
  [[ "$output" =~ knip ]]
  [[ "$output" =~ ts-prune ]]
}

# ── 源目录缺失时跳过 ──────────────────────────────────────────────

@test "missing brooks-tools/ source skips install" {
  SCRIPT_DIR="$TEST_TMPDIR/no-such-dir" \
  run bash -c "source '$LIB_FILE' && install_brooks_tools"
  [ "$status" -eq 0 ]
  [[ "$output" =~ 源目录.*不存在 ]] || [[ "$output" =~ 跳过 ]]
}
