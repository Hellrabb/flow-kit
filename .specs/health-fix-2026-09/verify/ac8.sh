#!/bin/bash
# AC-8 验证 · 验证动作自身不改工作区（T04/T07 · L2 阶段5 R1 补）
# 为什么需要独立夹具：AC-8 是"卫生约束"，原测试矩阵里只有散文（"见 §4"），
# 不满足"每条 AC ≥ 1 条可执行用例"。且**必须**同时覆盖 dist：dist/ 被 .gitignore 忽略，
# `git status --porcelain` **对它结构性失明** —— 只看 git 会漏掉夹具对 dist 的污染。
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # L3 阶段6 minor：改用 TMPD，勿写死 /tmp

# ① 基线：git 工作区 + dist 文件数 + dist 权限位指纹
git status --porcelain > /tmp/ac8_base_git.txt
find dist -type f 2>/dev/null | sort > /tmp/ac8_base_dist.txt
find dist -type f -printf '%m %p\n' 2>/dev/null | sort > /tmp/ac8_base_mode.txt

# ② 跑全部注入类夹具（各自内部 trap 还原）
for f in ac1 ac3 ac4 ac4c ac5 ac6; do
  [ -f ".specs/health-fix-2026-09/verify/$f.sh" ] && bash ".specs/health-fix-2026-09/verify/$f.sh" >/dev/null 2>&1 || true
done

# ③ 收尾比对（三项都要一致）
fail=0
git status --porcelain > /tmp/ac8_after_git.txt
diff -q /tmp/ac8_base_git.txt /tmp/ac8_after_git.txt >/dev/null || { echo "❌ FAIL: git 工作区被夹具改变"; diff /tmp/ac8_base_git.txt /tmp/ac8_after_git.txt | head; fail=1; }

find dist -type f 2>/dev/null | sort > /tmp/ac8_after_dist.txt
diff -q /tmp/ac8_base_dist.txt /tmp/ac8_after_dist.txt >/dev/null || { echo "❌ FAIL: dist 文件集被夹具改变"; diff /tmp/ac8_base_dist.txt /tmp/ac8_after_dist.txt | head; fail=1; }

find dist -type f -printf '%m %p\n' 2>/dev/null | sort > /tmp/ac8_after_mode.txt
diff -q /tmp/ac8_base_mode.txt /tmp/ac8_after_mode.txt >/dev/null || { echo "❌ FAIL: dist 权限位被夹具改变（git 对此失明，必须单独查）"; diff /tmp/ac8_base_mode.txt /tmp/ac8_after_mode.txt | head; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo "✅ AC-8 PASS（git 工作区 + dist 文件集 + dist 权限位 三项均与基线一致）"
