#!/usr/bin/env bats

# AC-4 · setup source 完整性 smoke（L-025 防护落地）
#
# 来由：2026-07-08 健康巡检发现 169/414 测试因「测试 setup 路径双重前缀 +
#       source 失败被 || true 吞错 → 被测函数未定义 → run 返回 127 假失败」。
#       路径修复后测试恢复，但未来路径漂移 / lib 重命名会再触发同类静默失败。
#
# 目的：单点 smoke 守住「关键 lib 可被 source + 代表函数已定义」。
#       若某 lib 路径错或函数被重命名，本 smoke 明确失败（而非让依赖它的
#       N 个测试以 status 127 假失败）。
#
# 判据：允许 source 顶层副作用失败（|| true 吸收 set -e 副作用），但函数
#       必须定义 —— 这才是「setup 成功」的真实判据。

setup() {
  BUNDLE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export CONFIG_FILE="$(mktemp)"
  export PROJECT_ROOT="$(mktemp -d)"
  printf '{"modules":{}}' > "$CONFIG_FILE"
}

teardown() {
  rm -f "$CONFIG_FILE" 2>/dev/null
  rm -rf "$PROJECT_ROOT" 2>/dev/null
}

@test "AC-4: 关键 lib source 后代表函数已定义（防路径漂移 → 静默假失败）" {
  local lib_dir="$BUNDLE_DIR/hooks/stop/lib"
  # common.sh 是多数 lib 的依赖，先 source
  source "$lib_dir/common.sh" 2>/dev/null || true

  # 格式: <lib 文件>:<期望定义的函数>
  local checks=(
    "common.sh:config_get"
    "common.sh:module_enabled"
    "common.sh:fk_resolve_phase"
    "checkpoint-lib.sh:checkpoint_write"
    "checkpoint-lib.sh:checkpoint_validate"
    "l2-detect.sh:l2_detect_missing"
    "l2-detect.sh:l2_dispatch_prompt"
    "l3-review.sh:l3_review_run"
    "correction-file.sh:correction_file_write"
    "done-validation.sh:fk_validate_done_marker"
  )
  local missing=""
  for c in "${checks[@]}"; do
    local lib="${c%%:*}"
    local fn="${c##*:}"
    # common.sh 已 source；其余按需 source（允许顶层副作用失败）
    [ "$lib" != "common.sh" ] && source "$lib_dir/$lib" 2>/dev/null || true
    type "$fn" >/dev/null 2>&1 || missing="${missing} ${lib}::${fn}"
  done
  if [ -n "$missing" ]; then
    echo "❌ source 后未定义的函数（路径漂移或 lib 重命名？）:${missing}" >&3
    false
  fi
}
