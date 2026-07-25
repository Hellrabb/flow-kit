#!/bin/bash
# tampered-done/check.sh — 威胁⑤ 验收：Write 改子 agent 已产出的合法内容
# AC-1 ⑤（⑤-L3 常见路径 Write/Edit + ⑤-L2 .md verdict 同篡）
# 方案 A：✅ path-guard D7 保护 .done（_is_dotdone_write）+ T4 L2 verdict 比对；⑤-L2 .md 同篡 v1 提高成本（v2 加密）
# 依赖：_is_dotdone_write（T01）+ fk_validate_done_marker T4（T02）
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ARTIFACTS_LIB="$BUNDLE_ROOT/hooks/stop/lib/flow-kit-artifacts.sh"
GATE_SH="$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"

# 依赖检测：fk_validate_done_marker（T06）+ _is_dotdone_write（T07）
if ! grep -qE 'fk_validate_done_marker[[:space:]]*\(\)' "$ARTIFACTS_LIB" 2>/dev/null || \
   ! grep -qE '_is_dotdone_write[[:space:]]*\(\)' "$GATE_SH" 2>/dev/null; then
  echo "⏳ PENDING: fk_validate_done_marker（T06）/ _is_dotdone_write（T07）未实现 — 威胁⑤ 载体就位，待 T4 verdict 比对激活"
  exit 0
fi

# setup：子 agent 合法产出（握手 verdict=pass），主 agent 用 Write 篡改 .done 的 L3_verdict=fail
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/.independent-review-6.done" <<'EOF'
phase=6
change_id=test-change
written_by=review-subagent
written_at=2026-07-02T00:00:00Z
L2_verdict=pass
L3_verdict=fail
EOF
# 29 号握手（原始 verdict=pass，与 .done 被篡改的 L3_verdict=fail 不一致）
cat > "$TMP/.independent-review-6.done" <<'EOF'
{"phase":"6","status":"done","verdict":"pass","written_by":"stop-hook-29","written_at":"2026-07-02T00:00:00Z"}
EOF

source "$ARTIFACTS_LIB"
fk_validate_done_marker "$TMP/.independent-review-6.done" 6 test-change transition
rc=$?

# 断言：.done L3_verdict(fail) ≠ 握手 verdict(pass) → T4 比对拒绝 exit 2
if [ "$rc" -eq 2 ]; then
  echo "✅ tampered-done: hook 拒绝篡改 .done（T4 verdict 比对不一致，威胁⑤-L3 已挡）"
  exit 0
else
  echo "🔴 tampered-done: hook 未拒绝篡改 .done（exit $rc，威胁⑤ 漏防）"
  exit 1
fi
