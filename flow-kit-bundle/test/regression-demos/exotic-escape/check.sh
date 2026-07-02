#!/bin/bash
# exotic-escape/check.sh — exotic Bash 逃逸验收（v1 不挡 · 文档化）
# 威胁③ exotic 向量：python-c / base64 / 变量间接 / dd 写握手（绕过常见 > >> tee cp mv sed 模式）
# v1 立场：⚠️ 不挡（best-effort · is_handshake_write 只挡常见写向量；完全挡留 v2 加密签名 · R12）
# 依赖：is_handshake_write（T07）
#
# 本 demo 特殊：无论 v1 挡/不挡都 exit 0（文档化 v1 best-effort 边界，非 pass/fail 断言）
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
GATE_SH="$BUNDLE_ROOT/hooks/pre-tool-use/independent-review-gate.sh"

# 依赖检测：is_handshake_write（T07）
if ! grep -qE 'is_handshake_write[[:space:]]*\(\)' "$GATE_SH" 2>/dev/null; then
  echo "⏳ PENDING: is_handshake_write 未实现（T07）— exotic 向量载体就位，待激活（v1 预期不挡）"
  exit 0
fi

source "$GATE_SH"

# exotic 向量：python -c 写握手（绕过常见重定向/cp/mv/sed/tee 模式匹配）
EXOTIC_CMD='python3 -c "open(\".flow-active.independent-review\",\"w\").write(\"forged-handshake\")"'

# is_handshake_write 对 exotic 命令的预期：v1 不挡（返回 false → 放行）
if is_handshake_write "$EXOTIC_CMD" 2>/dev/null; then
  echo "ℹ️ exotic-escape: is_handshake_write 挡住了 exotic 向量（超出 v1 best-effort 预期，可能是 v1.5/v2 强化版提前实现）"
  exit 0
else
  echo "⚠️ exotic-escape: is_handshake_write 未挡 exotic 向量（python-c）— 符合 v1 best-effort 立场"
  echo "   完全挡 exotic（python-c/base64/变量间接/dd）留 v2 加密签名（DESIGN §6 · R12）"
  exit 0  # v1 不挡 exotic 是预期边界，非 fail
fi
