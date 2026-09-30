#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# health-fix-2026-09c · T16 · C3 历史重写执行留痕（AC-5 · 不可逆）
# ───────────────────────────────────────────────────────────────────────
# 历史留痕，含 ⓪-⑦ 步序（实际执行于 2026-10-01，重写后首提交入库）。
# 本脚本以 $HOME 引用形态书写，不含任何真名字面量；
# 可重放审计用（重放前提：工作树净 + 备份 bundle 已另存仓外）。
#
# 重写前 SHA（bundle 备份锚点）：
#   本地 develop=98cfd44  本地 main=47d80f6（孤儿分支）
#   远端 develop=534e3e8  远端 main=9b5dda7
# 重写后 SHA（远端已验证）：
#   develop=d6ca423  main=4c81c66
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── ⓪ 保存 remote URL + 仓外组装字面量集（两种形态：裸 / 尾斜杠）──
git remote get-url origin > ../push-url-pre-scrub.tmp
umask 077
{
  printf '%s==>%s\n'  "$HOME" '/home/<redacted>'
  printf '%s/==>%s\n' "$HOME" '/home/<redacted>'
} > ../scrub-literals.tmp
chmod 600 ../scrub-literals.tmp

# ── ⓪a 工作树净断言（不净即中止，防重写吞掉未提交改动）──
test -z "$(git status --porcelain)"

# ── ① 全量 bundle 备份 + verify（rc=0 才准继续）──
git bundle create ../backup-pre-scrub-20260929.bundle --all
git bundle verify ../backup-pre-scrub-20260929.bundle

# ── ② filter-repo 历史净化（默认处理全部 refs——develop 与孤儿 main 均被改写）──
~/.local/bin/git-filter-repo --force --replace-text ../scrub-literals.tmp

# ── ③ 清 reflog + 剪旧对象 ──
git reflog expire --expire=now --all
git gc --prune=now

# ── ④ 重加 remote（filter-repo 默认移除 origin）──
git remote add origin "$(cat ../push-url-pre-scrub.tmp)"

# ── ⑤ force push 双分支 + 全新 clone（禁 --single-branch）逐 blob 机检 = 0 ──
git push --force origin develop main
scan_dir=$(mktemp -d /tmp/t16-clone-scan.XXXXXX)
git clone "$(git remote get-url origin)" "$scan_dir/flow-kit"
( cd "$scan_dir/flow-kit" \
  && test "$(git grep -F "$HOME" $(git rev-list --all) 2>/dev/null | wc -l)" -eq 0 )
rm -rf "$scan_dir"

# ── ⑥ 清理仓外临时文件（用毕即删）──
rm -f ../scrub-literals.tmp ../push-url-pre-scrub.tmp

# ── ⑦ AC-13 回归批：hooks-sync 兜底 + 全量 check + 用例计数对账 ──
make hooks-sync
make check
test "$(grep -h '^@test' test/*.bats | wc -l)" -ge 1116
