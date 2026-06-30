#!/usr/bin/env bats

# health-fix-2026-07 — package-flow-kit.sh 回归测试
# 对应 AC：AC-1（语法合法）/ AC-2（末尾无孤儿 fi·无假校验通过残留）/ AC-3（--validate 可用）
#
# 来由：2026-07-01 健康巡检发现 package-flow-kit.sh 末尾残留孤儿 fi（581-587 行），
#       导致 bash -n 失败、正常打包退出码非 0。本测试永久防止此类回归。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
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

@test "AC-2: 假「校验通过：所有文件均被 Part A~G」仅命中 1 次（顶部函数内，非文件尾残留）" {
  # 修复前：顶部函数体 + 文件尾残留 = 2 处；修复后：只剩顶部函数体内 1 处
  run grep -c '✅ 校验通过：所有文件均被 Part A~G' "$PKG_SCRIPT"
  [ "$output" -eq 1 ]
}

@test "AC-3: --validate 退出码非 2（0=通过 / 1=发现漏配，均正常；2=脚本自身错误）" {
  run bash "$PKG_SCRIPT" --validate
  [ "$status" -ne 2 ]
}
