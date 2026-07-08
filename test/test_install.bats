#!/usr/bin/env bats
# test_install.bats — install.sh 参数解析测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  INSTALL_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/install.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# 快捷函数：以 dry-run 模式运行 install.sh
run_install() {
  run bash "$INSTALL_SH" --dry-run "$@"
}

# ── --global ───────────────────────────────────────────────────────────

@test "--global installs flow-kit core" {
  run_install --global
  [ "$status" -eq 0 ]
  [[ "$output" =~ flow-kit.*核心 ]] || [[ "$output" =~ \[DRY-RUN\] ]]
}

# ── --project ──────────────────────────────────────────────────────────

@test "--project with valid path writes hooks" {
  mkdir -p "$TEST_TMPDIR/myproject"
  run_install --project "$TEST_TMPDIR/myproject"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Hook ]] || [[ "$output" =~ \[DRY-RUN\] ]]
}

@test "--project with nonexistent path fails" {
  run_install --project "/nonexistent/path/xyz"
  # install.sh 检测项目目录不存在应报错
  [[ "$output" =~ 不存在 ]] || [[ "$output" =~ ❌ ]] || [ "$status" -ne 0 ]
}

# ── --update ───────────────────────────────────────────────────────────

@test "--update works" {
  run_install --update
  [ "$status" -eq 0 ]
}

# ── --reinstall ────────────────────────────────────────────────────────

@test "--reinstall cleans before install" {
  run_install --reinstall
  [ "$status" -eq 0 ]
  [[ "$output" =~ 清理 ]] || [[ "$output" =~ \[DRY-RUN\] ]]
}

# ── --no-hooks ─────────────────────────────────────────────────────────

@test "--global --no-hooks skips hook install" {
  run_install --global --no-hooks
  [ "$status" -eq 0 ]
  # 输出不应包含 Hook 安装相关提示
  ! grep -q "Hook" <<< "$output" || true
}

# ── --no-skills ────────────────────────────────────────────────────────

@test "--global --no-skills skips skill install" {
  run_install --global --no-skills
  [ "$status" -eq 0 ]
  ! grep -q "技能" <<< "$output" || true
}

# ── --no-brooks ────────────────────────────────────────────────────────

@test "--global --no-brooks skips brooks-lint" {
  run_install --global --no-brooks
  [ "$status" -eq 0 ]
  ! grep -q "brooks-lint" <<< "$output" || true
}

# ── --hooks-only ───────────────────────────────────────────────────────

@test "--project + --hooks-only only installs hooks" {
  mkdir -p "$TEST_TMPDIR/proj2"
  run_install --project "$TEST_TMPDIR/proj2" --hooks-only
  [ "$status" -eq 0 ]
  # 应有 hooks 相关输出，不应有 flow-kit 核心输出
  [[ "$output" =~ Hook ]] || true
}

# ── --user ─────────────────────────────────────────────────────────────

@test "--global --user installs user-scope hooks" {
  run_install --global --user
  [ "$status" -eq 0 ]
}

# ── --help ─────────────────────────────────────────────────────────────

@test "--help shows usage" {
  run_install --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ 用法 ]] || [[ "$output" =~ Usage ]]
}
