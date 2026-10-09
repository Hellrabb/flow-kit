#!/usr/bin/env bash
# write-done-5.sh — 阶段 5（5-test）.done 标记用户手写脚本
# 用法：用户在终端执行  bash .specs/health-fix-2026-09c/write-done-5.sh
# 依据 done-validation.sh fk_validate_done_marker 契约（6 KVP · Tier-1 元数据 + Tier-2 verdict 对账）
set -euo pipefail
cd "$(dirname "$0")/../.."

MARKER=".specs/health-fix-2026-09c/.independent-review-5.done"

cat > "$MARKER" <<'EOF'
phase=5
change_id=health-fix-2026-09c
written_by=<acct>（用户终端 · write-done-5.sh）
L2_verdict=pass
L3_verdict=pass
artifacts=TEST.md,INDEPENDENT-REVIEW-5.md,MINOR-DEFERRED.md,STATE.md
notes=阶段5 TEST：17 AC 证据矩阵（16✅+AC-14排程7-integration）；L2 pass 0🔴0🟡5🟢已修；L3 pass 0🔴0🟡3🟢已修；make check rc=0 全横幅 @test 1179；AC-9 双标记修复；AC-5 全对象残留收口（工作树锚定根因）；NFR 四快门+全链4m55s
EOF

echo "已写入 $MARKER"
sed -n '1,6p' "$MARKER"
