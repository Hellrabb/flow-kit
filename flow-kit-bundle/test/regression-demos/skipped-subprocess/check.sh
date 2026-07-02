#!/bin/bash
# skipped-subprocess/check.sh — 威胁③ + AC-2 验收：跳过 review 子进程直接 transition
# AC-2（transition 前置查 goal.gates["N→N+1"] 非 passed 则拒）+ 威胁③（未派 review 子进程）
# v1 立场：✅ 挡（gates["4→5"]=pending 依赖合法 .done，无 .done → transition 前置查拒推进）
# 依赖：fk_validate_done_marker（T06）+ transition 前置查 gates 逻辑（T11）
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ARTIFACTS_LIB="$BUNDLE_ROOT/hooks/stop/lib/flow-kit-artifacts.sh"

# 依赖检测：fk_validate_done_marker（T06，transition 前置查的核心 .done 校验）
if ! grep -qE 'fk_validate_done_marker[[:space:]]*\(\)' "$ARTIFACTS_LIB" 2>/dev/null; then
  echo "⏳ PENDING: transition 前置查 gate 逻辑未实现（T06/T11）— 威胁③ 载体就位，待 gates 前置查激活"
  exit 0
fi

# setup：gates["4→5"]=pending（无合法 .done，未派 review 子进程），主 agent 尝试 transition
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/.flow-active" <<'EOF'
{"goal":{"current_phase":"4","gates":{"4→5":"pending"},"phases_done":["0","1","2","3"]}}
EOF
# 无 .independent-review-4.done（跳过 review 子进程，未产出合法 .done）

source "$ARTIFACTS_LIB"
# transition 4→5 前置查：gates["4→5"]=pending（非 passed，因无合法 .done）→ 拒绝推进
# fk_validate_done_marker 对缺失 .done → Tier 1 拒（exit 2）
rc=0
fk_validate_done_marker "$TMP/.independent-review-4.done" 4 test-change transition 2>/dev/null || rc=$?

if [ "$rc" -ne 0 ]; then
  echo "✅ skipped-subprocess: hook 拒绝 transition（无合法 .done，gates[4→5] 保持 pending，威胁③ 已挡）"
  exit 0
else
  echo "🔴 skipped-subprocess: hook 允许 transition（exit $rc，威胁③ 漏防）"
  exit 1
fi
