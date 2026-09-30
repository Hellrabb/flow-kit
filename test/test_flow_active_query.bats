#!/usr/bin/env bats
# test_flow_active_query.bats — flow-active-query.sh 唯一解析入口回归网（T13 · AC-12-g）
#
# 为什么存在（C14-g / ADR-031）：.flow-active 的解析此前散落两处手搓实现
#   （Makefile check-nfr-portability-internals 的 while-read + independent-
#   review-gate 的 jq 内联）。T13 收敛为唯一 CLI 入口 lib/flow-active-query.sh
#   后，其 rc 契约（0=值在场 / 1=不在场·缺字段·运行错 / 2=依赖缺失·非法 JSON，
#   DESIGN §9.3）成为两个调用点的安全底座 —— 契约被改坏时调用点会静默变行为，
#   必须有常设判据就地判红。
#
# 活性：setup 在运行时复制真实 SUT 进夹具再驱动（恒绿桩在此被吃到）。
# 夹具隔离：全部建在 ${TMPDIR:-/tmp}（mktemp -d），teardown 清理，不触工作树。
#
# 断言约定：run --separate-stderr（bats ≥ 1.5）——rc1 的「静默」语义只能用
# $stderr/$output 双空断言钉住（run 默认合并会把 stderr 洗进 output 造成假绿）。
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-faq.XXXXXX")"
  FIXTURE="$TEST_TMPDIR/repo"
  SUT_REL="flow-kit-bundle/lib/flow-active-query.sh"

  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容镜像位）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  SUT_SRC="$d/$SUT_REL"

  mkdir -p "$FIXTURE"
  # jq 缺失用例需要绝对 bash（env PATH=… 下 bash 无法按名解析）
  BASH_BIN="$(command -v bash)"

  # 最小合法状态档（字段取真实 schema 子集；夹具自造，不读真实现场）
  write_state() { printf '%b' "$1" > "$FIXTURE/.flow-active"; }
  run_sut() { ( cd "$FIXTURE" && bash "$SUT_SRC" "$@" ); }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

VALID_STATE='{"change_id":"fixture-change","goal":{"status":"active","current_phase":"4"},"updated_at":"2026-01-01T00:00:00Z"}\n'

@test "rc0：合法状态档查在场字段 ⇒ stdout=值、rc=0" {
  write_state "$VALID_STATE"
  run --separate-stderr run_sut '.change_id'
  [ "$status" -eq 0 ]
  [ "$output" = "fixture-change" ]
}

@test "rc0：--print-file 在场 ⇒ stdout=状态档绝对路径" {
  write_state "$VALID_STATE"
  run --separate-stderr run_sut --print-file '.change_id'
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.flow-active" ]]
}

@test "rc1：状态档不在场 ⇒ 静默（stdout/stderr 皆空）" {
  run --separate-stderr run_sut '.change_id'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "rc1：--print-file 不在场 ⇒ 同样静默 rc=1" {
  run --separate-stderr run_sut --print-file '.change_id'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "rc1：字段缺失（jq null）⇒ 静默 rc=1" {
  write_state "$VALID_STATE"
  run --separate-stderr run_sut '.nonexistent_field'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "rc1：字段值为 false ⇒ 同 null 语义 rc=1" {
  write_state '{"change_id":false,"goal":{"current_phase":"4"}}\n'
  run --separate-stderr run_sut '.change_id'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "rc1：字段值为空串 ⇒ 同 null 语义 rc=1" {
  write_state '{"change_id":"","goal":{"current_phase":"4"}}\n'
  run --separate-stderr run_sut '.change_id'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "rc1：jq 运行错（非法路径表达式）⇒ rc=1（不升级为 2）" {
  write_state "$VALID_STATE"
  # `.change_id][` 为 jq 编译错（jq exit 3）——契约：运行/编译错归 rc1 静默，
  # 不得升级成 rc2（rc2 专属依赖缺失与非法 JSON）。
  run --separate-stderr run_sut '.change_id]['
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "rc2：非法 JSON ⇒ stderr 含「非法 JSON」" {
  printf '%b' '{"change_id": "broken"\n' > "$FIXTURE/.flow-active"
  run --separate-stderr run_sut '.change_id'
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"非法 JSON"* ]]
}

@test "rc2：jq 缺失 ⇒ stderr 含「jq 不可用」" {
  write_state "$VALID_STATE"
  # 构造无 jq 的 PATH：空目录作 PATH，bash 用绝对路径驱动（env 先改环境再按新
  # PATH 找程序 ⇒ 按名调 bash 会 127，故用 BASH_BIN）。
  local nojq_dir="$TEST_TMPDIR/nojq-bin"
  mkdir -p "$nojq_dir"
  run --separate-stderr env PATH="$nojq_dir" "$BASH_BIN" "$SUT_SRC" --root "$FIXTURE" '.change_id'
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"jq 不可用"* ]]
}

@test "rc2：非法 JSON（--print-file 探针）⇒ 同样 rc=2" {
  printf '%b' 'not json at all\n' > "$FIXTURE/.flow-active"
  run --separate-stderr run_sut --print-file '.change_id'
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"非法 JSON"* ]]
}

@test "--root <dir> 覆盖：不 cd 也能查任意目录" {
  write_state "$VALID_STATE"
  run --separate-stderr bash "$SUT_SRC" --root "$FIXTURE" '.change_id'
  [ "$status" -eq 0 ]
  [ "$output" = "fixture-change" ]
}

@test "FLOW_ACTIVE_FILE env 覆盖：指向夹具外路径" {
  local alt="$TEST_TMPDIR/alt-state.json"
  printf '%b' '{"change_id":"alt-change","goal":{"current_phase":"2"}}\n' > "$alt"
  ( cd "$FIXTURE" && FLOW_ACTIVE_FILE="$alt" bash "$SUT_SRC" '.change_id' > "$TEST_TMPDIR/out" 2>/dev/null )
  [ "$(cat "$TEST_TMPDIR/out")" = "alt-change" ]
}

@test "--root 与 FLOW_ACTIVE_FILE 同时在 ⇒ env 优先" {
  write_state "$VALID_STATE"
  local alt="$TEST_TMPDIR/alt-state2.json"
  printf '%b' '{"change_id":"env-wins","goal":{"current_phase":"1"}}\n' > "$alt"
  ( cd "$FIXTURE" && FLOW_ACTIVE_FILE="$alt" bash "$SUT_SRC" --root "$TEST_TMPDIR/empty-elsewhere" '.change_id' > "$TEST_TMPDIR/out2" 2>/dev/null ) \
    || true
  [ "$(cat "$TEST_TMPDIR/out2")" = "env-wins" ]
}
