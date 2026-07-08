#!/usr/bin/env bats

# health-fix-2026-07 — 全量 bash -n 语法门禁（AC-4）
#
# 来由：2026-06-30 健康报告 89/100 漏检 package-flow-kit.sh 孤儿 fi（Critical）。
#       概念级 / 字面级 / 死代码级巡检都查不出语法错误，而语法错误会让脚本静默不可用。
#       本 smoke 作为永久门禁：每次跑 bats = 跑一次全仓库 .sh 语法检查。
#
# 排除第三方目录（非本仓库维护）：brooks-lint/brooks-tools/plugins/node_modules/.git

setup() {
  # 位置无关：向上查找含 flow-kit-bundle/ 的目录（repo 根）
  # （双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确 · TD-012 路径根治）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle" ]; do
    d="$(dirname "$d")"
  done
  REPO_ROOT="$d"
}

@test "AC-4: 所有生产 .sh 脚本通过 bash -n 语法检查" {
  local failures=0
  local failed_files=""
  local total=0

  while IFS= read -r -d '' f; do
    total=$((total + 1))
    if ! err=$(bash -n "$f" 2>&1); then
      failures=$((failures + 1))
      failed_files="${failed_files}
  ✗ ${f#$REPO_ROOT/}
$(printf '%s\n' "$err" | sed 's/^/      /')"
    fi
  done < <(cd "$REPO_ROOT" && find . -name '*.sh' \
      -not -path '*/node_modules/*' \
      -not -path '*/.git/*' \
      -not -path '*/brooks-lint/plugin/*' \
      -not -path '*/brooks-tools/*' \
      -not -path '*/.claude/plugins/*' \
      -type f -print0)

  echo "已扫描 $total 个生产 .sh 脚本" >&3
  if [ "$failures" -ne 0 ]; then
    echo "bash -n 失败的脚本（$failures / $total）：" >&3
    echo -e "$failed_files" >&3
    return 1
  fi
}
