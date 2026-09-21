#!/usr/bin/env bash
# make-manifest.sh — 生成 ARCHIVE-MANIFEST.txt（阶段 7 归档用）
#
# 用法（v4.3 修订，修复"先 mv 再生成"的顺序矛盾 · 阶段 3 L2 R1）：
#   bash .specs/user-guide-sync-2026-09b/make-manifest.sh [<产物目录>]
#   默认 <产物目录> = 脚本所在目录；归档后从归档目录内调用同样有效（自动解析仓库根）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 仓库根解析：逐级上溯找 package-dsh-plugin.sh（兼容产物目录 / 归档目录两种位置）
ROOT="$SCRIPT_DIR"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/package-dsh-plugin.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/package-dsh-plugin.sh" ] || { echo "❌ 未能定位仓库根（脚本所在目录：$SCRIPT_DIR）" >&2; exit 2; }
cd "$ROOT"

CHANGE_ID="privacy-path-scrub-2026-09"
DEST="${1:-$SCRIPT_DIR}"
[ -d "$DEST" ] || { echo "❌ 目标目录不存在：$DEST（先创建或先 mv 产物目录，再运行本脚本）" >&2; exit 2; }

OUT="$DEST/ARCHIVE-MANIFEST.txt"
{
  echo "# 归档清单 · $CHANGE_ID"
  echo "# 生成时间: $(date -Iseconds)"
  echo "# HEAD: $(git log -1 --format='%h %s' | cut -c1-80)"
  echo "# 工作区未提交项: $(git -c core.quotepath=false status --porcelain | wc -l)"
  echo
  echo "## 文件（$(find "$DEST" -maxdepth 1 -type f ! -name 'ARCHIVE-MANIFEST.txt' | wc -l) 项）"
  find "$DEST" -maxdepth 1 -type f ! -name 'ARCHIVE-MANIFEST.txt' -printf '%f\n' | sort | while IFS= read -r f; do
    printf '%-48s %8s B  sha256:%s\n' "$f" "$(stat -c %s "$DEST/$f")" "$(sha256sum "$DEST/$f" | cut -c1-16)"
  done
} > "$OUT"

n=$(grep -c 'B  sha256:' "$OUT" || true)
echo "✅ 已生成 $OUT（条目 $n 项）"
[ "$n" -ge 5 ] || { echo "❌ 清单条目过少（$n < 10）——产物目录是否为空？" >&2; exit 1; }
