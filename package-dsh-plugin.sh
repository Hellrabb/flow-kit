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
PKG_DIR="$DIST_DIR/dsh-flow-kit"

# ── 参数分流（必须在下面 `node -p` 之前）─────────────────────────────
# 为什么在这里：`--check` 是**只读新鲜度检查**，必须满足 NFR「不调用 npm/node」且
# **零副作用**（不重建、不改工作区）。若放在 `VERSION="$(node -p ...)"` 之后就一定会
# 调 node；若放任意位置之后又漏了提前 return，就会退化成"检查时重建被检查对象"。
# 未知参数一律 fail-closed —— 静默忽略未知选项会让 `--check` 这类"只读"契约
# 变成"照常重建并 exit 0"的假成功 —— **这就是 health-fix-2026-09 设 T01 的理由**。
usage_check() {
  cat >&2 <<'USAGE'
用法: package-dsh-plugin.sh [--check]

  无参数    打包 dsh-flow-kit 到 dist/（重建，有副作用）
  --check   只读新鲜度检查：比对 dist 与源是否一致；**不重建、不改工作区、不调 node/npm**
            退出码 0 = 一致；1 = 陈旧/反向残留（逐条指名文件）；0 = dist 不存在（提示后放行）
USAGE
}

# 比对映射：与下面第 1-5 步的 cp 一一对应（**单一事实源** —— 打包改了映射，这里必须同步）
check_dist() {
  if [ ! -d "$PKG_DIR" ]; then
    echo "⚠️  dist 不存在（$PKG_DIR）—— 请先运行: bash package-dsh-plugin.sh" >&2
    return 0   # 优雅降级：与 make dup 对 jscpd 缺失的处理同款
  fi

  local fail=0 rel src dst
  # 逐对 (源目录:dist子目录) —— 与下面第 1-5 步的 cp 一一对应（**单一事实源**）
  local pairs=(
    "$SRC_DIR/lib:$PKG_DIR/lib"                          # 第 1 步：插件代码
    "$BUNDLE_DIR/skills:$PKG_DIR/skills"                 # 第 2 步：运行内容（原样提升）
    "$BUNDLE_DIR/flow-kit:$PKG_DIR/flow-kit"
    "$BUNDLE_DIR/hooks:$PKG_DIR/hooks"
    "$BUNDLE_DIR/brooks-lint:$PKG_DIR/brooks-lint"
    "$BUNDLE_DIR:$PKG_DIR/vendor/flow-kit-bundle"        # 第 4 步：零丢失整棵 bundle
  )
  # 包顶层单文件映射
  local files=(
    "$SRC_DIR/package.json:$PKG_DIR/package.json"
    "$SRC_DIR/cordis.patch.yml:$PKG_DIR/cordis.patch.yml"
    "$SRC_DIR/README.md:$PKG_DIR/README.md"
    "$SRC_DIR/DESIGN.md:$PKG_DIR/DESIGN.md"
    "$BUNDLE_DIR/FLOW-KIT-用户指南.md:$PKG_DIR/docs/FLOW-KIT-用户指南.md"
    "$BUNDLE_DIR/OPENCODE-INSTALL.md:$PKG_DIR/docs/OPENCODE-INSTALL.md"
    "$SCRIPT_DIR/flow-kit-ecosystem-guide.md:$PKG_DIR/docs/flow-kit-ecosystem-guide.md"
  )

  # 只在**内容**层面比较 —— 故意不比 mode：
  # 打包第 5 步会有意 `chmod +x`，源与 dist 的权限位本就不等；比 mode 会制造永久假红。
  for rel in "${pairs[@]}"; do
    src="${rel%%:*}"; dst="${rel##*:}"
    [ -d "$src" ] || continue
    while IFS= read -r -d '' f; do
      rel="${f#"$src"/}"
      if [ ! -f "$dst/$rel" ]; then
        echo "❌ 缺失: $dst/$rel（源: $src/$rel）" >&2; fail=1
      elif ! cmp -s "$f" "$dst/$rel"; then
        echo "❌ 陈旧: $dst/$rel（内容与 $src/$rel 不一致 → 请重建 dist）" >&2; fail=1
      fi
    # 过滤 .DS_Store：打包第 5 步会 `find … -delete` 删掉它，故它不是"应存在于 dist"的产物。
    # 若不过滤 → 源里有个 .DS_Store 就报"缺失"，而提示的"重建 dist"永远修不好它
    # （重建又会删掉）→ **永久假红**（L2 阶段6 R2-b 实测）。下方反向 find 早已过滤，此处与之对齐。
    done < <(find "$src" -type f -not -name '.DS_Store' -print0)
    # 反向残留：dist 有、源已无
    while IFS= read -r -d '' f; do
      rel="${f#"$dst"/}"
      if [ ! -e "$src/$rel" ]; then
        echo "❌ 反向残留: $dst/$rel（源已无 $src/$rel）" >&2; fail=1
      fi
    done < <(find "$dst" -type f -not -name '.DS_Store' -print0)
  done

  for rel in "${files[@]}"; do
    src="${rel%%:*}"; dst="${rel##*:}"
    if [ ! -f "$src" ]; then
      # 反向残留（L2 阶段6 R2-a 补）：源侧已删，但 dist 侧仍留有旧副本 → **必须报**。
      # 原实现此处是 `[ -f "$src" ] || continue` —— 整条跳过，于是删掉源文件后
      # dist 仍带旧副本而门禁报"✅ 一致"（实测：rm dsh-flow-kit/DESIGN.md → rc=0）。
      # 那正是本 change 要堵的"dist 陈旧假绿"（旧文档随插件发给用户）。
      # 注意：`|| true` 之类的"源缺失"提示已由下面建 dist 的逻辑覆盖，此处只查残留。
      [ -f "$dst" ] && { echo "❌ 反向残留: $dst（源已无 $src → 请重建 dist）" >&2; fail=1; }
      continue
    fi
    if [ ! -f "$dst" ]; then
      echo "❌ 缺失: $dst（源: $src）" >&2; fail=1
    elif ! cmp -s "$src" "$dst"; then
      echo "❌ 陈旧: $dst（内容与 $src 不一致 → 请重建 dist）" >&2; fail=1
    fi
  done

  if [ "$fail" -eq 0 ]; then
    echo "✅ check-dist: dist 与源一致"
    return 0
  fi
  echo "" >&2
  echo "→ 修复: bash package-dsh-plugin.sh" >&2
  echo "  注意顺序: 若改过 test/，先 make test-sync，再重建 dist" >&2
  return 1
}

case "${1:-}" in
  --check) check_dist; exit $? ;;
  "")      ;;                                   # 正常打包路径
  -h|--help) usage_check; exit 0 ;;
  *)       echo "❌ 未知参数: $1" >&2; usage_check; exit 2 ;;
esac

VERSION="$(node -p "require('$SRC_DIR/package.json').version" 2>/dev/null || echo 0.1.0)"

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
