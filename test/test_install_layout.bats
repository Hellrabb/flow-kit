#!/usr/bin/env bats
# test_install_layout.bats — 安装形态下隐私检查器可达性常设网（T-FIX-14 · R5-18/19/24）
#
# 为什么存在（R5-18 🔴）：
#   安装器把检查器装到 <proj>/.claude/reference，而 hook 装到
#   <proj>/.claude/hooks/pre-push/pre-push.sh（比旧注释假设的层级深一层）。
#   旧候选表三条全 miss ⇒ pre-push 经 .git/hooks/pre-push symlink 调用时，
#   HOOK_DIR 解析成 .git/hooks（symlink 本体而非真实脚本），同样全 miss ⇒
#   门禁打印「未找到可用的路径隐私检查器」并 rc=0 放行，消费者双侧门禁静默失效。
#
#   本常设网用**真实 install.sh** 部署到临时 HOME + 临时 project（mktemp -d），
#   断言「检查器已装时必须被找到并使用」（不得静默跳过）。
#
# 三态语义边界（T-FIX-13 不得回退）：
#   ① 检查器缺失 ⇒ rc=0 + 逐字「ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描」
#   ② 检查器在 + allowlist 缺 ⇒ pre-push exit 2 / pre-commit exit 1（具名指清单路径）
#   ③ 两者皆在 ⇒ 干净 rc=0；泄漏 rc≠0 + 具名归因
#   本文件只锁腿①（真缺失态必须保持 rc=0 + 该措辞），不得把它改成 fail-closed。
#
# 脱敏（L-129/137）：泄漏探针以拼接构造，文件内不出现真实账号字面。

bats_require_minimum_version 1.5.0

setup() {
  # 向上找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  FK_ROOT="$d"
  INSTALL_SH="$FK_ROOT/flow-kit-bundle/install.sh"

  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-install-layout.XXXXXX")"
  HOME_DIR="$TEST_TMPDIR/home"
  PROJ="$TEST_TMPDIR/proj"
  mkdir -p "$HOME_DIR" "$PROJ"
  export HOME="$HOME_DIR"
  export FLOW_KIT_YES=1

  # 固定桩 git 身份（夹具仓内 commit 用）
  export GIT_AUTHOR_NAME="fixture"
  export GIT_AUTHOR_EMAIL="fixture@example.invalid"
  export GIT_COMMITTER_NAME="fixture"
  export GIT_COMMITTER_EMAIL="fixture@example.invalid"

  # 泄漏探针拼接构造（L-137）：本文件内不出现真实账号字面
  PROBE_LEAK="/home/""zz-tfix14-probe""/secret"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── 辅助：在夹具 project 里装 hooks（真实 install.sh · project scope · claude）──
deploy_install() {
  run bash "$INSTALL_SH" --platform claude --project "$PROJ" --hooks-only
}

# ── 辅助：在夹具 project 里建一个含泄漏的 commit，返回其 sha ──
make_leaky_commit() {
  cd "$PROJ"
  git init -q
  printf 'SECRET=%s\n' "$PROBE_LEAK" > leaky.txt
  : > path-privacy-allowlist.txt
  git add leaky.txt path-privacy-allowlist.txt
  git commit -q -m "leaky fixture" >/dev/null 2>&1 || true
  LEAKY_SHA=$(git rev-parse HEAD)
  cd - >/dev/null
}

# ── 辅助：构造 pre-push stdin 一行 ──
#   格式: <local ref> <local sha> <remote ref> <remote sha>
#   remote sha 全 0 ⇒ 模拟新建分支推送
make_prepush_stdin() {
  local sha="$1"
  printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$sha"
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ①：symlink 形态 + 泄漏 ⇒ rc≠0 且报文含「🔴 拒绝推送」+ 被拒 ref 名
# ═══════════════════════════════════════════════════════════════════════
@test "symlink form: leaky ref rejected (rc!=0 + 拒绝推送 + ref name)" {
  deploy_install
  [ "$status" -eq 0 ]
  make_leaky_commit
  # 重新装一次（make_leaky_commit 已 git init，现在 .git 存在 ⇒ 第二次 install 会建 symlink）
  deploy_install
  [ "$status" -eq 0 ]
  # 断言 symlink 落地
  [ -L "$PROJ/.git/hooks/pre-push" ]
  [ -f "$PROJ/.claude/hooks/pre-push/pre-push.sh" ]
  [ -f "$PROJ/.claude/reference/check-path-privacy.sh" ]

  cd "$PROJ"
  run bash "$PROJ/.git/hooks/pre-push" <<<"$(make_prepush_stdin "$LEAKY_SHA")"
  cd - >/dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 拒绝推送"* ]]
  [[ "$output" == *"refs/heads/main"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ②：真实脚本路径形态 + 泄漏 ⇒ 同腿 ①（不经 symlink 直接调真实脚本）
# ═══════════════════════════════════════════════════════════════════════
@test "real-script form: leaky ref rejected (rc!=0 + 拒绝推送)" {
  deploy_install
  [ "$status" -eq 0 ]
  make_leaky_commit
  deploy_install
  [ "$status" -eq 0 ]

  cd "$PROJ"
  run bash "$PROJ/.claude/hooks/pre-push/pre-push.sh" <<<"$(make_prepush_stdin "$LEAKY_SHA")"
  cd - >/dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 拒绝推送"* ]]
  [[ "$output" == *"refs/heads/main"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ③：干净 ref ⇒ rc=0（检查器在 + 无泄漏 ⇒ 放行）
#   用独立 fixture：只建一个无泄漏 commit，确保该 ref 树内无泄漏文件
#   （若复用 make_leaky_commit 的 fixture，干净 commit 的树仍含 leaky.txt ⇒ 误红）。
# ═══════════════════════════════════════════════════════════════════════
@test "clean ref: rc=0 (checker found, no leak)" {
  # 独立 project（不污染 make_leaky_commit 的 fixture）
  local clean_proj="$TEST_TMPDIR/clean_proj"
  mkdir -p "$clean_proj"
  git -C "$clean_proj" init -q
  printf 'hello\n' > "$clean_proj/clean.txt"
  : > "$clean_proj/path-privacy-allowlist.txt"
  git -C "$clean_proj" add clean.txt path-privacy-allowlist.txt
  git -C "$clean_proj" commit -q -m "clean file" >/dev/null 2>&1 || true
  CLEAN_SHA=$(git -C "$clean_proj" rev-parse HEAD)
  # 装到这个 clean project（project scope，claude）
  run bash "$INSTALL_SH" --platform claude --project "$clean_proj" --hooks-only
  [ "$status" -eq 0 ]
  [ -f "$clean_proj/.claude/reference/check-path-privacy.sh" ]

  cd "$clean_proj"
  run bash "$clean_proj/.git/hooks/pre-push" <<<"$(make_prepush_stdin "$CLEAN_SHA")"
  cd - >/dev/null
  [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ④：检查器与 allowlist 均就位（安装产物落地断言）
# ═══════════════════════════════════════════════════════════════════════
@test "install deploys check-path-privacy.sh + allowlist at <proj>/.claude/reference" {
  deploy_install
  [ "$status" -eq 0 ]
  [ -f "$PROJ/.claude/reference/check-path-privacy.sh" ]
  [ -f "$PROJ/.claude/reference/path-privacy-allowlist.txt" ]
  # 检查器可执行
  [ -x "$PROJ/.claude/reference/check-path-privacy.sh" ]
  # hook 源文件就位
  [ -f "$PROJ/.claude/hooks/pre-push/pre-push.sh" ]
  [ -f "$PROJ/.claude/hooks/pre-commit/pre-commit.sh" ]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ⑤：真缺失态回归腿（T-FIX-13 三态语义①不得回退）
#   把安装位的 check-path-privacy.sh 与 path-privacy-allowlist.txt **同时**移走
#   ⇒ 必须保持 rc=0 + 逐字「ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描」
# ═══════════════════════════════════════════════════════════════════════
@test "real-missing state: rc=0 + exact skip message (T-FIX-13 tri-state ① preserved)" {
  deploy_install
  [ "$status" -eq 0 ]
  make_leaky_commit
  deploy_install
  [ "$status" -eq 0 ]
  # 同时移走检查器与 allowlist（模拟「检查器真缺失」）
  mv "$PROJ/.claude/reference/check-path-privacy.sh" "$TEST_TMPDIR/checker.stash"
  mv "$PROJ/.claude/reference/path-privacy-allowlist.txt" "$TEST_TMPDIR/allowlist.stash"

  cd "$PROJ"
  run bash "$PROJ/.git/hooks/pre-push" <<<"$(make_prepush_stdin "$LEAKY_SHA")"
  cd - >/dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描"* ]]
  # 不得误报为泄漏（不得 fail-closed）
  [[ "$output" != *"🔴 拒绝推送"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ⑥（反向控制 · 判据有牙）：临时把候选表还原为旧三条 ⇒ 腿①必须转红
#   本腿用 sed 临时改 pre-push.sh 候选行，跑完还原。
# ═══════════════════════════════════════════════════════════════════════
@test "reverse-control: reverting candidates to old-three turns leg ① red" {
  deploy_install
  [ "$status" -eq 0 ]
  make_leaky_commit
  deploy_install
  [ "$status" -eq 0 ]

  # 临时把已安装 pre-push.sh 的 resolve_reference_dir 还原成旧三条候选
  # （只删 $HOOK_DIR/../../reference 一条，保留 for...done 结构完整）。
  local installed_hook="$PROJ/.claude/hooks/pre-push/pre-push.sh"
  cp "$installed_hook" "$TEST_TMPDIR/pre-push.sh.orig"
  # 用 awk 原地替换 for 循环行：把四候选改回旧三候选（去掉 ../../reference）
  awk '
    /^  for d in "\$HOOK_DIR\/\.\.\/flow-kit\/reference"/ {
      sub(/ "\$HOOK_DIR\/\.\.\/\.\.\/reference"/, "")
    }
    { print }
  ' "$installed_hook" > "$TEST_TMPDIR/pre-push.sh.old3"
  # 校验改造成功：新候选不再出现
  ! grep -q '\$HOOK_DIR/\.\./\.\./reference"' "$TEST_TMPDIR/pre-push.sh.old3"
  cp "$TEST_TMPDIR/pre-push.sh.old3" "$installed_hook"
  # 语法仍合法
  bash -n "$installed_hook"

  cd "$PROJ"
  run bash "$PROJ/.git/hooks/pre-push" <<<"$(make_prepush_stdin "$LEAKY_SHA")"
  cd - >/dev/null
  # 旧三条 ⇒ 找不到检查器 ⇒ rc=0 + skip message ⇒ 反向转红
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描"* ]]
  [[ "$output" != *"🔴 拒绝推送"* ]]

  # 还原（保证后续用例干净）
  cp "$TEST_TMPDIR/pre-push.sh.orig" "$installed_hook"
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ⑦：pre-commit 隐私块前置（R5-19）—— 无 Makefile 沙箱项目里泄漏 ⇒ rc≠0
#   旧实现：no Makefile 早退 exit 0 ⇒ 隐私块永远跑不到。修复后隐私块在前。
# ═══════════════════════════════════════════════════════════════════════
@test "pre-commit: no Makefile + leaky commit rejected (privacy block runs before early-exit)" {
  deploy_install
  [ "$status" -eq 0 ]
  make_leaky_commit
  deploy_install
  [ "$status" -eq 0 ]
  # 项目无 Makefile（make_leaky_commit 没建 Makefile）⇒ 旧实现会早退 exit 0

  cd "$PROJ"
  # pre-commit 不吃 stdin，直接跑（CHECK_REV 默认扫工作树/index）
  run bash "$PROJ/.claude/hooks/pre-commit/pre-commit.sh"
  cd - >/dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"path-privacy check failed"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ⑧：pre-commit 无 Makefile + 干净 ⇒ rc=0（隐私块前置不破坏放行语义）
# ═══════════════════════════════════════════════════════════════════════
@test "pre-commit: no Makefile + clean commit rc=0" {
  deploy_install
  [ "$status" -eq 0 ]
  # 干净 commit（无泄漏）
  cd "$PROJ"
  git init -q
  printf 'hello\n' > clean.txt
  git add clean.txt
  git commit -q -m "clean" >/dev/null 2>&1 || true
  cd - >/dev/null
  deploy_install
  [ "$status" -eq 0 ]

  cd "$PROJ"
  run bash "$PROJ/.claude/hooks/pre-commit/pre-commit.sh"
  cd - >/dev/null
  [ "$status" -eq 0 ]
}
