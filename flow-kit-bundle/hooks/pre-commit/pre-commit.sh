#!/bin/bash
set -euo pipefail

# pre-commit.sh — flow-kit 归档 commit 门禁
# make test 与路径隐私检查非零退出码拒绝 commit。无 Makefile / npx 不可见时跳过。
# 消费者项目兼容（R3-14 · health-fix-2026-09b T-FIX-08）：项目 Makefile 声明了
# check-path-privacy 目标则用之；无则回退到随包 reference/check-path-privacy.sh
# （路径由 hook 自身位置推导，导出 FLOW_KIT_PRIVACY_ALLOWLIST 指向随包
# path-privacy-allowlist.txt，CWD 保持项目根）。三者皆不可得 ⇒ 打印跳过理由且不改 rc。
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

# 路径隐私门禁（health-fix-2026-09b AC-6 ③ · R3-14 消费者项目回退）
# hook 自身位置推导随包 reference 目录（不写死绝对路径）。
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolve_reference_dir() {
  local d
  for d in "$HOOK_DIR/../flow-kit/reference" "$HOOK_DIR/../reference" "$HOOK_DIR/../../flow-kit/reference"; do
    if [ -f "$d/check-path-privacy.sh" ]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}
makefile_has_target() {
  local target="$1"
  [ -f Makefile ] || return 1
  grep -qE "^${target}[[:space:]]*:" Makefile
}

if makefile_has_target check-path-privacy; then
  if ! make check-path-privacy; then
    echo "[archive-commit-gate] path-privacy check failed, commit rejected" >&2
    exit 1
  fi
else
  ref_dir="$(resolve_reference_dir 2>/dev/null || true)"
  if [ -n "$ref_dir" ] && [ -f "$ref_dir/check-path-privacy.sh" ]; then
    if [ -f "$ref_dir/path-privacy-allowlist.txt" ]; then
      if ! FLOW_KIT_PRIVACY_ALLOWLIST="$ref_dir/path-privacy-allowlist.txt" \
           bash "$ref_dir/check-path-privacy.sh"; then
        echo "[archive-commit-gate] path-privacy check failed, commit rejected" >&2
        exit 1
      fi
    else
      # 状态 ②（health-fix-2026-09b · T-FIX-13 · R4-M1）：检查器在 +
      # path-privacy-allowlist.txt 缺失 ⇒ 具名 fail-closed。配置缺失不得
      # 被当成「干净」放行（含泄漏的提交会被直接放过 ⇒ fail-open），也不得
      # 复用「未找到可用的路径隐私检查器」措辞（与实际原因不符；该措辞
      # 保留给 :73 的「检查器缺失」腿，bats:222 静态断言要求其仍在文件内）。
      echo "🔴 [archive-commit-gate] 找到路径隐私检查器但缺少允许清单：$ref_dir/path-privacy-allowlist.txt（无法确定扫描基线 ⇒ fail-closed，提交被拒绝）" >&2
      exit 1
    fi
  else
    # 状态 ①：检查器缺失 ⇒ 消费者兼容语义（rc=0 + 原措辞，审计已接受）。
    echo "ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描"
  fi
fi

exit 0
