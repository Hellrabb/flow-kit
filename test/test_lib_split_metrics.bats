#!/usr/bin/env bats

# test_lib_split_metrics.bats — td072-lib-split-2026-08 结构性硬门槛测试
# 覆盖 AC: B1 / B2 / B3 / C2

setup() {
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  local FK_ROOT="$d"
  HOOKS_STOP_LIB="${FK_ROOT}/flow-kit-bundle/hooks/stop/lib"
  HOOKS_PRE_TOOL_USE="${FK_ROOT}/flow-kit-bundle/hooks/pre-tool-use"
}

@test "AC-B1-metric: l3-api.sh ≤ 250 行" {
  run wc -l "${HOOKS_STOP_LIB}/l3-api.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | awk '{print $1}')
  [ "$count" -le 250 ]
}

@test "AC-B2-metric: l3-truncate.sh ≤ 250 行" {
  run wc -l "${HOOKS_STOP_LIB}/l3-truncate.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | awk '{print $1}')
  [ "$count" -le 250 ]
}

@test "AC-B3-metric: 4 触碰的 lib 文件每个 ≤ 250 行" {
  files=(
    "${HOOKS_STOP_LIB}/l3-api.sh"
    "${HOOKS_STOP_LIB}/l3-truncate.sh"
    "${HOOKS_PRE_TOOL_USE}/gate-helpers.sh"
    "${HOOKS_PRE_TOOL_USE}/gate-helpers-types.sh"
  )
  for f in "${files[@]}"; do
    run wc -l "$f"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | awk '{print $1}')
    [ "$count" -le 250 ] || { echo "FAIL: $f = $count lines (>250)"; false; }
  done
}

@test "AC-C2-metric: smart_truncate 定义仅在 l3-truncate.sh" {
  run grep -c '^smart_truncate()' "${HOOKS_STOP_LIB}/l3-api.sh"
  # grep -c returns 0 with exit 1 when no match
  count="${output}"
  [ "$count" = "0" ]

  run grep -c '^smart_truncate()' "${HOOKS_STOP_LIB}/l3-truncate.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | head -1)
  [ "$count" -ge 1 ]
}
