#!/bin/bash
# empty-done/check.sh — 威胁① 验收：空 .done 应被 T1 非空检查拒绝
# AC-1 ① · v1 立场：✅ 挡（fk_validate_done_marker Tier 1 · T1 非空）
# 依赖：flow-kit-artifacts.sh::fk_validate_done_marker（T06 实现）
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ARTIFACTS_LIB="$BUNDLE_ROOT/hooks/stop/lib/flow-kit-artifacts.sh"

# 依赖检测：fk_validate_done_marker 是否已实现（T06）
if ! grep -qE 'fk_validate_done_marker[[:space:]]*\(\)' "$ARTIFACTS_LIB" 2>/dev/null; then
  echo "⏳ PENDING: fk_validate_done_marker 未实现（T06）— 威胁① 载体就位（空 .done），待 T1 非空检查激活"
  exit 0
fi

# setup 威胁场景：空 .done（威胁①）
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
: > "$TMP/.independent-review-6.done"

source "$ARTIFACTS_LIB"
fk_validate_done_marker "$TMP/.independent-review-6.done" 6 test-change transition
rc=$?

# 断言：空 .done 应被 Tier 1 T1 非空检查拒绝（exit 2）
if [ "$rc" -eq 2 ]; then
  echo "✅ empty-done: hook 拒绝空 .done（T1 非空检查生效，威胁① 已挡）"
  exit 0
else
  echo "🔴 empty-done: hook 未拒绝空 .done（exit $rc，威胁① 漏防）"
  exit 1
fi
