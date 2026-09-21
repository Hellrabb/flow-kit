#!/usr/bin/env bash
# verify-boundary.sh — AC-9 改动边界判据（v4：git status --porcelain + ls-files -o）
#
# 为什么不用 git diff --name-only：它对**未跟踪新增**（bats ×2、change 目录）与被 .gitignore
#   忽略的 dist/ 结构性失明 —— 白名单会变成空集（阶段 1 L2 第三轮 R20）。
# 用法：bash .specs/user-guide-sync-2026-09b/verify-boundary.sh
set -uo pipefail
# 仓库根解析（v4.7）：逐级上溯找 package-dsh-plugin.sh —— 兼容 .specs/<id>/ 与 .specs/archive/<date>-<id>/ 两种落点
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT_DIR" != "/" ] && [ ! -f "$ROOT_DIR/package-dsh-plugin.sh" ]; do ROOT_DIR="$(dirname "$ROOT_DIR")"; done
[ -f "$ROOT_DIR/package-dsh-plugin.sh" ] || { echo "❌ 未能定位仓库根（脚本：${BASH_SOURCE[0]}）" >&2; exit 2; }
cd "$ROOT_DIR" || exit 2

WL=(
  "FLOW-KIT-用户指南.md"
  "flow-kit-bundle/FLOW-KIT-用户指南.md"
  "flow-kit-用户指南.pptx"
  "README.md"
  "dsh-flow-kit/README.md"
  ".specs/CONTEXT.md"
  ".specs/CHANGELOG.md"
  ".specs/STATE.md"
  ".specs/LESSONS.md"
  ".specs/user-guide-deck-gen/slides.json"
  ".specs/user-guide-deck-gen/deck_checks.py"
  ".specs/user-guide-deck-gen/build.py"
  ".specs/user-guide-deck-gen/layouts.py"
  ".specs/user-guide-deck-gen/README.md"
  "test/test_guide_copy_parity.bats"
  "flow-kit-bundle/test/test_guide_copy_parity.bats"
)
# 允许的前缀（change 产物目录）
# v4.7：同时允许「变更期落点」与「归档后落点」两种前缀（归档后原地可复跑）
WL_PREFIX=(".specs/user-guide-sync-2026-09b/" ".specs/archive/2026-09-21-user-guide-sync-2026-09b/")

allow() { # <path>
  local p="$1" w
  for w in "${WL[@]}"; do [ "$p" = "$w" ] && return 0; done
  for w in "${WL_PREFIX[@]}"; do case "$p" in "$w"*) return 0 ;; esac; done
  return 1
}

bad=0
# 已知瞬态夹具（其他 bats 用例运行期会创建、结束时清理；并发跑 make check 时会短暂出现）——
# 阶段 5 L2 第二轮 R1：不过滤会造成本判据假红（受控复现 22 次跑命中 4 次）。
TRANSIENT=(
  "flow-kit-bundle/TEST_GAP_DO_NOT_PACKAGE"   # test_lessons_cleanup.bats
  ".sync-hooks-orphan-test.sh"                # test_l3_review_defects_2026_09.bats
)
is_transient() { local p="$1" t; for t in "${TRANSIENT[@]}"; do [ "$p" = "$t" ] && return 0; done; return 1; }
# check-dist 点名的是**绝对路径**（且同时给出 dist 侧与源侧两条）→ 用后缀匹配归类
is_transient_path() { local p="$1" t; for t in "${TRANSIENT[@]}"; do case "$p" in *"$t") return 0 ;; esac; done; return 1; }
checked=0; ignored=0
echo "## AC-9 边界核对（git status --porcelain + 未跟踪）"
while IFS= read -r line; do
  [ -n "$line" ] || continue
  p="${line:3}"                       # 去掉 XY + 空格
  p="${p%\"}"; p="${p#\"}"            # 去引号（中文路径会被 git 加引号）
  if is_transient "$p"; then
    printf '  ⏭ 忽略瞬态: %s\n' "$p"; ignored=$((ignored+1))
  elif allow "$p"; then
    printf '  ✅ %s\n' "$p"; checked=$((checked+1))
  else
    printf '  ❌ 越界: %s\n' "$p"; bad=1
  fi
done < <(git -c core.quotepath=false status --porcelain)
echo "  （已核对 $checked 条 · 忽略瞬态 $ignored 条）"

# 未跟踪新增全集（git status --porcelain 已含 ?? 项，这里再独立核一次，与 AC-9 判据声明一致）
echo
echo "## 未跟踪新增（git ls-files -o --exclude-standard）"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if is_transient "$p"; then printf '  ⏭ 忽略瞬态: %s\n' "$p"
  elif allow "$p"; then printf '  ✅ %s\n' "$p"
  else printf '  ❌ 越界(未跟踪): %s\n' "$p"; bad=1; fi
done < <(git -c core.quotepath=false ls-files -o --exclude-standard)

echo
echo "## 禁动域 diff（必须为 0）"
n=$(git diff --name-only -- flow-kit-bundle/hooks dsh-flow-kit/lib flow-kit-bundle/skills flow-kit-bundle/flow-kit/prompts | wc -l)
echo "  禁动域改动文件数: $n"
[ "$n" = "0" ] || bad=1

echo
echo "## dist 再生件（由 make check-dist 守护，git 结构性看不见）"
# 瞬态夹具同样会污染 check-dist：它按 COPY_DIRS 直接 find 源树（阶段 5 L2 第三/四轮 R1）。
# v4.4 口径：**不做预探测**（预探测 → 检查之间存在 TOCTOU 窗口，实测 22 轮里 8 轮假红），
#   改为「先跑 → 失败后按被点名的路径归类」：仅当全部被点名路径都是瞬态夹具才降级为 ⏭ 跳过。
if out=$(bash package-dsh-plugin.sh --check 2>&1); then
  echo "  ✅ check-dist rc=0"
else
  # 只从 ❌ 行抽路径，且限定 ASCII 路径字符集（避免把「（源:」「/，先」这类片段当成路径）
  named=$(printf '%s\n' "$out" | grep '^❌' | grep -oE '/[A-Za-z0-9._/-]+' | sed "s#^$PWD/##" | sort -u)
  all_transient=1; n_named=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n_named=$((n_named+1))
    is_transient_path "$p" || all_transient=0
  done <<< "$named"
  if [ "$n_named" -gt 0 ] && [ "$all_transient" = "1" ]; then
    echo "  ⏭ 跳过 check-dist：本次失败全部由瞬态夹具引起（$named）——非 dist 陈旧，勿据此重建 dist"
  else
    printf '%s\n' "$out" | sed 's/^/    /'
    echo "  ❌ check-dist rc≠0（上方为逐条指名；仅当指名路径全部是瞬态夹具时才可降级）"
    bad=1
  fi
fi

echo
[ "$bad" = "0" ] && echo "✅ 边界核对通过" || echo "❌ 边界核对失败"
exit "$bad"
