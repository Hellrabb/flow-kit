#!/usr/bin/env bats
# test/test_l3_adr_truncation.bats — R5-22 修正：ADR 纳入上限截断留痕测试
# 验证 _l3_build_prompt phase 2 在 ADR > 8 时：
#   1. 落标记含「已丢弃 N 条」措辞（N = 工件引用的 ADR 唯一去重总数 - 8）；
#   2. 标记在 break 之前写入（可达）；
#   3. 已纳入数恰好为 8。

setup() {
  TEST_TMPDIR=$(mktemp -d)
  # 位置无关：向上查找 flow-kit-bundle 根（双源 test/ 与 flow-kit-bundle/test/ 同源 · L-025）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
  # l3-prompt.sh 依赖 l3-truncate.sh（_l3_utf8_head_bytes 等）
  source "$FK_ROOT/flow-kit-bundle/hooks/stop/lib/l3-truncate.sh" 2>/dev/null || true
  source "$FK_ROOT/flow-kit-bundle/hooks/stop/lib/l3-prompt.sh" 2>/dev/null || true

  # 夹具：artifacts_dir = $TEST_TMPDIR/specs/health-fix，adr 在 $TEST_TMPDIR/specs/adr
  ARTIFACTS_DIR="$TEST_TMPDIR/specs/health-fix"
  ADR_DIR="$TEST_TMPDIR/specs/adr"
  mkdir -p "$ARTIFACTS_DIR" "$ADR_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# 造一个引用 N 个 ADR 的 DESIGN.md（每个引用 2 次，保证 freq 排序稳定）
make_design_with_n_adrs() {
  local n="$1"
  {
    echo "# Design"
    local i
    for i in $(seq 1 "$n"); do
      printf 'Decision ADR-%03d applies here. See ADR-%03d for rationale.\n' "$i" "$i"
      printf 'Also ADR-%03d is referenced again for emphasis.\n' "$i"
    done
  } > "$ARTIFACTS_DIR/DESIGN.md"
}

# 造 N 个 ADR 文件（3 位零填充名：001-*.md … 0NN-*.md）
make_n_adr_files() {
  local n="$1"
  local i
  for i in $(seq 1 "$n"); do
    printf '# ADR-%03d\n\nContent of ADR %03d.\n' "$i" "$i" > "$ADR_DIR/$(printf '%03d' "$i")-test.md"
  done
}

@test "R5-22: 10 ADRs referenced → exactly 8 included (--- markers)" {
  make_design_with_n_adrs 10
  make_n_adr_files 10
  if type _l3_build_prompt >/dev/null 2>&1; then
    run _l3_build_prompt 2 "$ARTIFACTS_DIR" 60000
    local _included
    _included=$(printf '%s' "$output" | grep -c '^--- .* ---$')
    [ "$_included" -eq 8 ]
  else
    skip "_l3_build_prompt not available"
  fi
}

@test "R5-22: >8 ADRs → drop marker contains '已丢弃' and count" {
  make_design_with_n_adrs 10
  make_n_adr_files 10
  if type _l3_build_prompt >/dev/null 2>&1; then
    run _l3_build_prompt 2 "$ARTIFACTS_DIR" 60000
    # 标记须含「已丢弃 N 条」
    [[ "$output" =~ "已丢弃" ]]
    # 提取丢弃计数 = 2（10 唯一引用 - 8 上限）
    local _cnt
    _cnt=$(printf '%s' "$output" | grep -oE '已丢弃 [0-9]+ 条' | grep -oE '[0-9]+' | head -1)
    [ "$_cnt" -eq 2 ]
  else
    skip "_l3_build_prompt not available"
  fi
}

@test "R5-22: 9 ADRs referenced → drop count = 1" {
  make_design_with_n_adrs 9
  make_n_adr_files 9
  if type _l3_build_prompt >/dev/null 2>&1; then
    run _l3_build_prompt 2 "$ARTIFACTS_DIR" 60000
    local _cnt
    _cnt=$(printf '%s' "$output" | grep -oE '已丢弃 [0-9]+ 条' | grep -oE '[0-9]+' | head -1)
    [ "$_cnt" -eq 1 ]
  else
    skip "_l3_build_prompt not available"
  fi
}

@test "R5-22: <=8 ADRs → no drop marker (no false positive)" {
  make_design_with_n_adrs 8
  make_n_adr_files 8
  if type _l3_build_prompt >/dev/null 2>&1; then
    run _l3_build_prompt 2 "$ARTIFACTS_DIR" 60000
    # 不应出现丢弃标记
    ! [[ "$output" =~ "已丢弃" ]]
    # 应纳入 8 份
    local _included
    _included=$(printf '%s' "$output" | grep -c '^--- .* ---$')
    [ "$_included" -eq 8 ]
  else
    skip "_l3_build_prompt not available"
  fi
}
