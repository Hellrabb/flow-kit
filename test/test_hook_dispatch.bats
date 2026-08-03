#!/usr/bin/env bats
# test_hook_dispatch.bats — L-020 闭合：Stop hook 模块调度完整性测试
# 防护「文件存在但 00-gate.sh 未调度」死代码 class
# 触发场景：新增 hook 模块时忘记在 00-gate.sh 加 run_module 调用

setup() {
  TEST_TMPDIR=$(mktemp -d)
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  FK_ROOT="$d"
  STOP_DIR="$FK_ROOT/flow-kit-bundle/hooks/stop"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "L-020: 所有 [0-9]*-*.sh 模块（除 00-gate.sh）在 00-gate.sh 中被 run_module 调度" {
  # 列出所有数字前缀模块文件
  local dead_count=0
  local dead_list=""
  while IFS= read -r f; do
    local base
    base=$(basename "$f")
    # 00-gate.sh 是调度器本身，不调度自己
    [[ "$base" == "00-gate.sh" ]] && continue
    # 检测 00-gate.sh 是否引用该文件名
    if ! grep -q "$base" "$STOP_DIR/00-gate.sh"; then
      dead_count=$((dead_count + 1))
      dead_list="${dead_list} ${base}"
    fi
  done < <(ls "$STOP_DIR"/[0-9]*-*.sh 2>/dev/null)

  [[ "$dead_count" -eq 0 ]] || {
    echo "❌ DEAD MODULES (文件存在但 00-gate.sh 未调度):${dead_list}" >&2
    echo "修复：在 00-gate.sh 加 run_module \"\${HOOK_BASE_DIR}/${dead_list## *}\" \"<module-name>\"" >&2
    false
  }
}

@test "L-020: HOOK_MODULE_NAMES 数组与磁盘模块文件同步" {
  # common.sh HOOK_MODULE_NAMES 是模块名单一源
  local common_sh="$FK_ROOT/flow-kit-bundle/hooks/stop/lib/common.sh"
  [[ -f "$common_sh" ]] || skip "common.sh not found"

  # 提取 HOOK_MODULE_NAMES 数组中的模块名（unquoted，格式如 "00-gate 01-transcript-parse"）
  local declared_count
  declared_count=$(awk '/declare -a HOOK_MODULE_NAMES=\(/,/^\)/{print}' "$common_sh" \
    | grep -oE '[0-9]+-[a-z_]+' | sort -u | wc -l)

  # 磁盘上模块文件数（除 00-gate.sh）
  local disk_count
  disk_count=$(ls "$STOP_DIR"/[0-9]*-*.sh 2>/dev/null | wc -l)

  # 数组应含所有磁盘模块（00-gate 也算）
  [[ "$declared_count" -ge "$disk_count" ]] || {
    echo "❌ HOOK_MODULE_NAMES ($declared_count) < 磁盘模块数 ($disk_count)" >&2
    false
  }
}

@test "L-020: 每个 run_module 调用的文件实际存在" {
  # 反向检测：00-gate.sh 调度的文件是否都存在（防 typo / 删除后忘清理）
  while IFS= read -r line; do
    # 提取 run_module 调用中的路径
    local path
    path=$(echo "$line" | grep -oE '"\$\{HOOK_BASE_DIR\}/[^"]+\.sh"' | tr -d '"' | sed 's|\${HOOK_BASE_DIR}|'"$STOP_DIR"'|')
    [[ -n "$path" ]] || continue
    [[ -f "$path" ]] || {
      echo "❌ $path 在 00-gate.sh 中被调度但文件不存在" >&2
      false
    }
  done < <(grep '^run_module ' "$STOP_DIR/00-gate.sh")
}
