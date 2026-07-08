#!/usr/bin/env bats

# health-fix-2026-07 — package-flow-kit.sh 回归测试
# 对应 AC：AC-1（语法合法）/ AC-2（末尾无孤儿 fi·无假校验通过残留）/ AC-3（--validate 可用）
#
# 来由：2026-07-01 健康巡检发现 package-flow-kit.sh 末尾残留孤儿 fi（581-587 行），
#       导致 bash -n 失败、正常打包退出码非 0。本测试永久防止此类回归。

setup() {
  # 位置无关：向上查找含 package-flow-kit.sh 的目录
  # （双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确 · L-025 同源路径问题根治）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -f "$d/package-flow-kit.sh" ]; do
    d="$(dirname "$d")"
  done
  REPO_ROOT="$d"
  PKG_SCRIPT="$REPO_ROOT/package-flow-kit.sh"
}

@test "AC-1: bash -n package-flow-kit.sh 语法合法" {
  run bash -n "$PKG_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "AC-2: 文件末尾 12 行无孤儿 fi / } 残留碎片" {
  # 修复后末尾应是 banner 正常结尾；不应出现孤立的 "  fi" 或顶格 "}"
  run bash -c "tail -n 12 '$PKG_SCRIPT' | grep -cE '^  fi$|^}\$'"
  [ "$output" -eq 0 ]
}

@test "AC-2: 假「校验通过：所有文件均被 Part A~G」仅命中 1 次（lib/validate_staging.sh 函数内）" {
  # validate_staging_coverage() 已拆到 flow-kit-bundle/lib/validate_staging.sh
  run grep -c '✅ 校验通过：所有文件均被 Part A~G' flow-kit-bundle/lib/validate_staging.sh
  [ "$output" -eq 1 ]
}

@test "AC-3: --validate 退出码非 2（0=通过 / 1=发现漏配，均正常；2=脚本自身错误）" {
  run bash "$PKG_SCRIPT" --validate
  [ "$status" -ne 2 ]
}
