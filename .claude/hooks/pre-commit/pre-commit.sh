#!/bin/bash
set -euo pipefail

# pre-commit.sh — flow-kit 归档 commit 门禁
# make test 非零退出码拒绝 commit。无 Makefile / npx 不可见时跳过。
# 部署：install_hooks.sh deploy_pre_commit() → symlink .git/hooks/pre-commit → 已安装 hooks 目录

# PATH 补齐（D2 R9 修复 · npx/node 可见性）
[ -f "$HOME/.profile" ] && { source "$HOME/.profile" 2>/dev/null || true; }
[ -n "${NVM_DIR:-}" ] && [ -f "$NVM_DIR/nvm.sh" ] && { source "$NVM_DIR/nvm.sh" 2>/dev/null || true; }
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d /usr/local/bin ] && export PATH="/usr/local/bin:$PATH"

# 无 Makefile → 跳过
if [ ! -f Makefile ]; then
  echo "[archive-commit-gate] no Makefile, skipping test gate"
  exit 0
fi

# npx 不可见 → warn + 跳过
if ! command -v npx >/dev/null 2>&1; then
  echo "[archive-commit-gate] npx not found, skipping test gate"
  exit 0
fi

# make test
if ! make test; then
  echo "[archive-commit-gate] test failed, commit rejected" >&2
  exit 1
fi

exit 0
