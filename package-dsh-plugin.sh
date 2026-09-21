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
#
# 契约：打包路径（无参数）与 `--check` **同读下方 COPY_* 三张表** —— 映射只写一份。
#   （brooks-review 2026-09-21 · 🟡 Change Propagation：原实现把同一映射写成两份，
#    且两份对"源缺失"的语义相反 —— 打包 fail-closed、检查静默跳过。）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/dsh-flow-kit"
BUNDLE_DIR="$SCRIPT_DIR/flow-kit-bundle"
DIST_DIR="$SCRIPT_DIR/dist"
PKG_DIR="$DIST_DIR/dsh-flow-kit"

# ── 拷贝映射（**单一事实源**）──────────────────────────────────────────
# 元素格式 "<源>:<目标>"。缺失语义（与打包侧一致）：
#   · 必需项（COPY_DIRS / COPY_FILES）源缺失 = 错误 —— 打包会 exit 1，检查侧不得静默跳过
#   · 可选项（COPY_OPTIONAL）源缺失 = 合法（打包侧原为 `|| true`，如用户文档未生成）
#   无论必需或可选：**源已删、dist 仍有副本** 一律报"反向残留"（重建即会消失的陈旧件）。
COPY_DIRS=(
  "$SRC_DIR/lib:$PKG_DIR/lib"                          # 插件代码
  "$BUNDLE_DIR/skills:$PKG_DIR/skills"                 # 运行内容（原样提升）
  "$BUNDLE_DIR/flow-kit:$PKG_DIR/flow-kit"
  "$BUNDLE_DIR/hooks:$PKG_DIR/hooks"
  "$BUNDLE_DIR/brooks-lint:$PKG_DIR/brooks-lint"
  "$BUNDLE_DIR:$PKG_DIR/vendor/flow-kit-bundle"        # 零丢失整棵 bundle
)
COPY_FILES=(
  "$SRC_DIR/package.json:$PKG_DIR/package.json"
  "$SRC_DIR/cordis.patch.yml:$PKG_DIR/cordis.patch.yml"
  "$SRC_DIR/README.md:$PKG_DIR/README.md"
  "$SRC_DIR/DESIGN.md:$PKG_DIR/DESIGN.md"
)
COPY_OPTIONAL=(
  "$BUNDLE_DIR/FLOW-KIT-用户指南.md:$PKG_DIR/docs/FLOW-KIT-用户指南.md"
  "$BUNDLE_DIR/OPENCODE-INSTALL.md:$PKG_DIR/docs/OPENCODE-INSTALL.md"
  "$SCRIPT_DIR/flow-kit-ecosystem-guide.md:$PKG_DIR/docs/flow-kit-ecosystem-guide.md"
)

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
  --check   只读新鲜度检查：按 COPY_DIRS/COPY_FILES/COPY_OPTIONAL 比对 dist 与源；
            **不重建、不改工作区、不调 node/npm**
            退出码：0 = 一致（dist 不存在时提示后放行）；1 = 陈旧 / 反向残留 / 必需源缺失（逐条指名）
USAGE
}

check_dist() {
  if [ ! -d "$PKG_DIR" ]; then
    # 优雅降级（与 make dup 对 jscpd 缺失的处理同款）：dist 不在 → 新鲜度无从谈起，提示后放行。
    # 但**源侧完整性仍须核**（L3 阶段6 major）：否则"dist 未构建 + 必需源已损坏"会返回 0，
    # 而随后的打包必败 —— 正是本 change 要堵的假绿形态。
    echo "⚠️  dist 不存在（$PKG_DIR）—— 请先运行: bash package-dsh-plugin.sh" >&2
    local miss=0 _rel _src _miss_list=""
    for _rel in "${COPY_DIRS[@]}"; do
      _src="${_rel%%:*}"
      [ -d "$_src" ] || { echo "❌ 必需源目录缺失: $_src（打包会失败）" >&2; miss=1; }
    done
    for _rel in "${COPY_FILES[@]}"; do
      _src="${_rel%%:*}"
      [ -f "$_src" ] || { echo "❌ 必需源文件缺失: $_src（打包会失败）" >&2; miss=1; }
    done
    [ "$miss" -eq 0 ] && return 0
    return 1
  fi

  local fail=0 rel src dst
  local -a _ds_filter=(-not -name '.DS_Store')
  # 只在**内容**层面比较 —— 故意不比 mode：
  # 打包第 5 步会有意 `chmod +x`，源与 dist 的权限位本就不等；比 mode 会制造永久假红。
  # 过滤 .DS_Store：打包会 `find … -delete` 删掉它，故它不是"应存在于 dist"的产物。
  # 若不过滤 → 源里有个 .DS_Store 就报"缺失"，而提示的"重建 dist"永远修不好它
  # （重建又会删掉）→ **永久假红**（L2 阶段6 R2-b 实测）。
  # ⚠️ 已知限制（L3 阶段6 minor · 2026-09-21）：比对只覆盖 `-type f`，**不含符号链接**
  #   （`cp -R` 会复制 symlink，而 `find -type f` 不匹配它）。当前打包域实测 symlink 数 = 0
  #   （`find dsh-flow-kit flow-kit-bundle -type l | wc -l`），故无实际盲区；
  #   若将来引入 symlink，须把下面的 find 扩为 `\( -type f -o -type l \)` 并复验。

  for rel in "${COPY_DIRS[@]}"; do
    src="${rel%%:*}"; dst="${rel##*:}"
    if [ ! -d "$src" ]; then
      # 原实现此处是 `[ -d "$src" ] || continue` —— 整对**静默跳过**（连同下方反向残留检查），
      # 于是"必需源目录被移走 + dist 仍带旧树"会报 ✅。而打包侧对同一份映射是 fail-closed
      # （cp -R 无 `|| true`）—— 两份语义相反即本行的成因（brooks-review 2026-09-21 · 🟡3）。
      echo "❌ 源目录缺失: $src（打包会失败）" >&2
      if [ -d "$dst" ]; then
        # 可观测性（L3 阶段6 minor）：报残留规模**并逐条指名**（上限 10 条 —— 与 usage 的
        # 「逐条指名」契约一致，同时避免 534 文件级别的刷屏）。
        local _residue_count _shown=0 _rf
        _residue_count=$(find "$dst" -type f "${_ds_filter[@]}" -print0 2>/dev/null | tr -dc '\0' | wc -c)
        echo "   且 dist 侧仍有旧副本: $dst（${_residue_count} 个文件 → 重建即清理）" >&2
        while IFS= read -r -d '' _rf; do
          _shown=$((_shown + 1))
          [ "$_shown" -gt 10 ] && break
          echo "      · ${_rf#"$dst"/}" >&2
        done < <(find "$dst" -type f "${_ds_filter[@]}" -print0 2>/dev/null)
        [ "$_residue_count" -gt 10 ] && echo "      · …（共 ${_residue_count} 个，仅列前 10）" >&2
      fi
      fail=1
      continue
    fi
    # 正向：源有 → dist 必须有且内容一致
    while IFS= read -r -d '' f; do
      rel="${f#"$src"/}"
      if [ ! -f "$dst/$rel" ]; then
        echo "❌ 缺失: $dst/$rel（源: $src/$rel）" >&2; fail=1
      elif ! cmp -s "$f" "$dst/$rel"; then
        echo "❌ 陈旧: $dst/$rel（内容与 $src/$rel 不一致 → 请重建 dist）" >&2; fail=1
      fi
    done < <(find "$src" -type f "${_ds_filter[@]}" -print0)
    # 反向残留：dist 有、源已无
    while IFS= read -r -d '' f; do
      rel="${f#"$dst"/}"
      if [ ! -e "$src/$rel" ]; then
        echo "❌ 反向残留: $dst/$rel（源已无 $src/$rel）" >&2; fail=1
      fi
    done < <(find "$dst" -type f "${_ds_filter[@]}" -print0 2>/dev/null)
  done

  for rel in "${COPY_FILES[@]}"; do
    src="${rel%%:*}"; dst="${rel##*:}"
    if [ ! -f "$src" ]; then
      # 必需单文件源缺失 —— 与 COPY_DIRS 同语义：**无条件 fail**（打包会 exit 1）。
      # 为什么必须无条件（L3 阶段6 critical · 2026-09-21）：原实现只在 `[ -f "$dst" ]` 时
      # 报"反向残留"并置 fail；若源与 dist **都没有**该文件，则 continue 且 fail 不置位
      # → `--check` 在"打包必败"的状态下返回 0（假绿），直接违背本文件 usage_check 写下的契约。
      echo "❌ 必需源文件缺失: $src（打包会失败）" >&2; fail=1
      # 附带信息：dist 侧是否残留旧副本（R2-a 场景），不影响上面的 fail。
      [ -f "$dst" ] && echo "   且 dist 侧仍有旧副本: $dst（请重建 dist）" >&2
      continue
    fi
    if [ ! -f "$dst" ]; then
      echo "❌ 缺失: $dst（源: $src）" >&2; fail=1
    elif ! cmp -s "$src" "$dst"; then
      echo "❌ 陈旧: $dst（内容与 $src 不一致 → 请重建 dist）" >&2; fail=1
    fi
  done

  # 可选文档：源缺失合法；但源已删而 dist 仍有副本 = 反向残留（重建即会消失的陈旧件）
  for rel in "${COPY_OPTIONAL[@]}"; do
    src="${rel%%:*}"; dst="${rel##*:}"
    if [ ! -f "$src" ]; then
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

# ── 1) 目录对（必需）——与 --check 同读 COPY_DIRS ─────────────────────
for rel in "${COPY_DIRS[@]}"; do
  src="${rel%%:*}"; dst="${rel##*:}"
  if [ ! -d "$src" ]; then
    echo "ERROR: $src missing（COPY_DIRS 必需项）" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
done

# ── 2) 顶层单文件（必需）──与 --check 同读 COPY_FILES ────────────────
for rel in "${COPY_FILES[@]}"; do
  src="${rel%%:*}"; dst="${rel##*:}"
  if [ ! -f "$src" ]; then
    echo "ERROR: $src missing（COPY_FILES 必需项）" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
done

# ── 3) 用户文档（可选：源缺失不致命）──与 --check 同读 COPY_OPTIONAL ──
for rel in "${COPY_OPTIONAL[@]}"; do
  src="${rel%%:*}"; dst="${rel##*:}"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$src" ]; then cp "$src" "$dst"; fi
done

# ── 4) 权限 + 清理杂项 ──────────────────────────────────────────────
chmod +x "$PKG_DIR"/hooks/*/*.sh "$PKG_DIR"/hooks/stop/lib/*.sh 2>/dev/null || true
chmod +x "$PKG_DIR"/hooks/pre-tool-use/*.sh 2>/dev/null || true
chmod +x "$PKG_DIR"/hooks/pre-commit/*.sh 2>/dev/null || true
find "$PKG_DIR" -name '.DS_Store' -delete 2>/dev/null || true

# ── 5) 单元测试 + 语法校验 ─────────────────────────────────────────
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

# ── 6) tarball ───────────────────────────────────────────────────────
TARBALL="$DIST_DIR/dsh-flow-kit-${VERSION}.tgz"
rm -f "$TARBALL"
tar -C "$DIST_DIR" -czf "$TARBALL" dsh-flow-kit

echo "==> done"
echo "    package dir : $PKG_DIR"
echo "    tarball     : $TARBALL"
du -sh "$PKG_DIR" "$TARBALL" | sed 's/^/    /'
