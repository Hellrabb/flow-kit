#!/usr/bin/env bash
# run-l3.sh <phase> [l2_verdict] [gate] — 手工触发某阶段的 L3 外部模型审查
#
# 背景：正常路径是 Stop hook 模块 29 在会话结束时自动跑 L3；本 change 采用「连续推进」节奏，
#   需要在阶段内同步拿到 L3 结果，故用同一实现（l3_review_run）手工触发——**不绕过封装**，
#   `.done` 仍由 l3_review_run 自己写（CONTEXT 禁动清单：主 agent 不得直写 `.done`）。
#
# 用法：bash .specs/user-guide-sync-2026-09b/run-l3.sh 1
set -uo pipefail
# 仓库根解析（v4.7）：逐级上溯找 package-dsh-plugin.sh —— 兼容 .specs/<id>/ 与 .specs/archive/<date>-<id>/ 两种落点
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/package-dsh-plugin.sh" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
[ -f "$ROOT_DIR/package-dsh-plugin.sh" ] || { echo "❌ 未能定位仓库根（脚本：${BASH_SOURCE[0]}）" >&2; exit 2; }
cd "$ROOT_DIR" || exit 2

PHASE="${1:?用法: run-l3.sh <phase> [l2_verdict] [gate]}"
L2V="${2:-pass}"
GATE="${3:-both}"

# 凭证：用户级 l3.env（模板见 .claude/l3.env.example）；凭证绝不落盘到仓库
if [ -f "$HOME/.config/flow-kit/l3.env" ]; then
  set -a; . "$HOME/.config/flow-kit/l3.env"; set +a
fi

# 与 Stop 模块 29 同源的初始化：HOOK_BASE_DIR 决定 l3-review.sh 能否 source 到
# correction-file.sh（write_model_missing_clear / fk_resolve_model 的依赖链）
export HOOK_BASE_DIR="$PWD/flow-kit-bundle/hooks/stop"
source "$HOOK_BASE_DIR/lib/common.sh" 2>/dev/null || true
source "$HOOK_BASE_DIR/lib/correction-file.sh" 2>/dev/null || true
[ -f "$HOOK_BASE_DIR/lib/flow-kit-artifacts.sh" ] && source "$HOOK_BASE_DIR/lib/flow-kit-artifacts.sh" 2>/dev/null || true
fk_resolve_api_credentials || { echo "❌ L3 凭证不可用（rc=$?）"; exit 3; }
echo "✓ 凭证就绪（scheme=$FK_API_AUTH_SCHEME, base=${FK_API_BASE_URL%%/*}//…）"

source "$HOOK_BASE_DIR/lib/l3-review.sh" 

echo "▶ L3 审查：phase=$PHASE change=user-guide-sync-2026-09b l2_verdict=$L2V gate=$GATE"
l3_review_run "$PHASE" "user-guide-sync-2026-09b" ".specs/user-guide-sync-2026-09b" "$L2V" "$GATE"
rc=$?
echo "◀ L3 返回 rc=$rc（0=pass / 1=fail / 其它=调用失败）"
exit "$rc"
