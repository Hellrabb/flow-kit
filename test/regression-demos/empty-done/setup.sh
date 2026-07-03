#!/bin/bash
# empty-done/setup.sh — 生成威胁① 场景（空 .done）到指定目录
# 用法: setup.sh <target_dir> [phase]
set -uo pipefail
TARGET="${1:?usage: setup.sh <target_dir> [phase]}"
PHASE="${2:-6}"
mkdir -p "$TARGET"
# 威胁①：空文件（touch，无任何内容）—— 绕过纯 [ -f ] 检查
: > "$TARGET/.independent-review-${PHASE}.done"
echo "$TARGET/.independent-review-${PHASE}.done"
