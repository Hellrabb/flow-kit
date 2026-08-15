#!/bin/bash
# package-dsh-plugin.sh — 组装 dsh-flow-kit npm 插件包
#
# 原则（DESIGN.md §1）：
#   1) 内容零丢失：flow-kit-bundle/ 完整复制到 dist/dsh-flow-kit/vendor/flow-kit-bundle/
#   2) 运行目录提升到包顶层：skills/ flow-kit/ hooks/ brooks-lint/
#   3) 壳层解耦：hooks 使用已注入 runtime-adapter.sh 的源码（common.sh 平台感知）
#
# 产物：
#   dist/dsh-flow-kit/            可 `dsh plugin add file:...` 的包目录
#   dist/dsh-flow-kit-<ver>.tgz   可分发 tarball

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/dsh-flow-kit"
BUNDLE_DIR="$SCRIPT_DIR/flow-kit-bundle"
DIST_DIR="$SCRIPT_DIR/dist"
VERSION="$(node -p "require('$SRC_DIR/package.json').version" 2>/dev/null || echo 0.1.0)"
PKG_DIR="$DIST_DIR/dsh-flow-kit"

echo "==> packaging dsh-flow-kit v$VERSION"

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

# ── 1) 插件代码 + 元数据 ────────────────────────────────────────────
cp -R "$SRC_DIR"/lib "$PKG_DIR/lib"
cp "$SRC_DIR/package.json" "$PKG_DIR/package.json"
cp "$SRC_DIR/cordis.patch.yml" "$PKG_DIR/cordis.patch.yml"
cp "$SRC_DIR/README.md" "$PKG_DIR/README.md"
cp "$SRC_DIR/DESIGN.md" "$PKG_DIR/DESIGN.md"

# ── 2) flow-kit 运行内容（原样提升到包顶层）────────────────────────
for sub in skills flow-kit hooks brooks-lint; do
  if [[ ! -d "$BUNDLE_DIR/$sub" ]]; then
    echo "ERROR: $BUNDLE_DIR/$sub missing" >&2
    exit 1
  fi
  cp -R "$BUNDLE_DIR/$sub" "$PKG_DIR/$sub"
done

# ── 3) 用户文档 ──────────────────────────────────────────────────────
mkdir -p "$PKG_DIR/docs"
cp "$BUNDLE_DIR/FLOW-KIT-用户指南.md" "$PKG_DIR/docs/FLOW-KIT-用户指南.md" 2>/dev/null || true
cp "$BUNDLE_DIR/OPENCODE-INSTALL.md" "$PKG_DIR/docs/OPENCODE-INSTALL.md" 2>/dev/null || true
cp "$SCRIPT_DIR/flow-kit-ecosystem-guide.md" "$PKG_DIR/docs/flow-kit-ecosystem-guide.md" 2>/dev/null || true

# ── 4) 零丢失：完整原始 bundle 进 vendor（含 install.sh/lib/test）──
mkdir -p "$PKG_DIR/vendor"
cp -R "$BUNDLE_DIR" "$PKG_DIR/vendor/flow-kit-bundle"

# ── 5) 权限 + 清理杂项 ──────────────────────────────────────────────
chmod +x "$PKG_DIR"/hooks/*/*.sh "$PKG_DIR"/hooks/stop/lib/*.sh 2>/dev/null || true
chmod +x "$PKG_DIR"/hooks/pre-tool-use/*.sh 2>/dev/null || true
chmod +x "$PKG_DIR"/hooks/pre-commit/*.sh 2>/dev/null || true
find "$PKG_DIR" -name '.DS_Store' -delete 2>/dev/null || true

# ── 6) 单元测试 + 语法校验 ─────────────────────────────────────────
echo "==> unit tests (node)"
node --test "$SRC_DIR/test"/*.test.mjs 2>&1 | grep -E "^# (tests|pass|fail)" || {
  echo "ERROR: node unit tests failed" >&2
  exit 1
}

echo "==> syntax checks"
fail=0
for js in "$PKG_DIR"/lib/*.js; do
  node --check "$js" || fail=1
done
while IFS= read -r -d '' sh; do
  bash -n "$sh" || { echo "bash -n failed: $sh" >&2; fail=1; }
done < <(find "$PKG_DIR/hooks" -name '*.sh' -print0)
while IFS= read -r -d '' sh; do
  bash -n "$sh" || { echo "bash -n failed: $sh" >&2; fail=1; }
done < <(find "$PKG_DIR/flow-kit" -name '*.sh' -print0)
[[ "$fail" -eq 0 ]] || { echo "ERROR: syntax check failed" >&2; exit 1; }

# ── 7) tarball ───────────────────────────────────────────────────────
TARBALL="$DIST_DIR/dsh-flow-kit-${VERSION}.tgz"
rm -f "$TARBALL"
tar -C "$DIST_DIR" -czf "$TARBALL" dsh-flow-kit

echo "==> done"
echo "    package dir : $PKG_DIR"
echo "    tarball     : $TARBALL"
du -sh "$PKG_DIR" "$TARBALL" | sed 's/^/    /'
