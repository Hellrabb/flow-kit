#!/usr/bin/env bats
# test_resume_banner.bats — banner.sh build_resume_banner() 函数测试
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  local FK_ROOT="$d"
  BANNER_SH="$FK_ROOT/flow-kit-bundle/hooks/stop/lib/banner.sh"

  # Source banner.sh (fail hard if missing)
  if [[ -f "$BANNER_SH" ]]; then
    source "$BANNER_SH"
  else
    echo "FATAL: banner.sh not found at $BANNER_SH" >&2
    exit 1
  fi

  # 构造最小 .flow-active JSON
  FLOW_FILE="$TEST_TMPDIR/.flow-active"
  cat > "$FLOW_FILE" <<'JSON'
{
  "change_id": "test-change",
  "phase": "4",
  "task_id": "none",
  "token_spent": 5000,
  "interrupt": {
    "active_file": ".specs/test-change/CHANGE.md",
    "last_action": "CHANGE.md 已生成",
    "checkpoint_at": "2026-07-10T16:00:00+08:00"
  },
  "goal": {
    "condition": "all tests pass",
    "status": "active",
    "turns": 3,
    "mode": "native",
    "scope": "pipeline",
    "current_phase": "4"
  }
}
JSON
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── AC-2: banner 输出含 change_id ──────────────────────────────────
@test "banner 输出含 change_id" {
  run build_resume_banner "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test-change" ]]
}

# ── AC-2: banner 输出含 phase 编号和中文标签 ────────────────────────
@test "banner 输出含 phase 标签" {
  run build_resume_banner "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "phase  : 4" ]]
  [[ "$output" =~ "开发实施" ]]
}

# ── AC-2: banner 输出含 goal 条件 ──────────────────────────────────
@test "banner 输出含 goal 条件" {
  run build_resume_banner "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "🎯 goal" ]]
  [[ "$output" =~ "all tests pass" ]]
  [[ "$output" =~ "turns: 3" ]]
}

# ── AC-2: banner 输出含 interrupt 信息 ─────────────────────────────
@test "banner 输出含 interrupt 信息" {
  run build_resume_banner "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚡ 中断" ]]
  [[ "$output" =~ "CHANGE.md 已生成" ]]
  [[ "$output" =~ ".specs/test-change/CHANGE.md" ]]
}

# ── 健壮性 NFR: 缺失 flow_file 时输出错误 ──────────────────────────
@test "缺失 flow_file 时返回非零并报错" {
  run build_resume_banner "/nonexistent/path/.flow-active"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]] || [[ "$stderr" =~ "ERROR" ]]
}

# ── 健壮性 NFR: 空参数时输出错误 ──────────────────────────────────
@test "空参数时返回非零并报错" {
  run build_resume_banner ""
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]] || [[ "$stderr" =~ "ERROR" ]]
}

# ── 回归: banner 输出含 frame 字符 ─────────────────────────────────
@test "banner 输出含 ASCII frame 框线" {
  run build_resume_banner "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "╔══════════════════════════════════════════════════════╗" ]]
  [[ "$output" =~ "╚══════════════════════════════════════════════════════╝" ]]
  [[ "$output" =~ "/flow-go 继续" ]]
}
