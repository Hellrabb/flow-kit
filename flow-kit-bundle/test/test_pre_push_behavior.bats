#!/usr/bin/env bats
# test_pre_push_behavior.bats — pre-push 拦截行为级常设网（T-FIX-16 · R5-7）
#
# 为什么存在（R5-7 🔴 · AC-3 无行为级常设覆盖）：
#   既有 test/test_archive_commit_gate.bats 对 flow-kit-bundle/hooks/pre-push/pre-push.sh
#   只做 bash -n（语法）+ 文本 grep -q（措辞存在），**从不执行 hook**。ADR-014 交叉模型
#   spot-check F2 实证：把畸形守卫 exit 1 改成 continue、把泄漏拒绝改成 scan_rev || true
#   之后，全套静态断言逐条重放仍然全绿（先红证据见 /tmp/tfix16/pre.txt · 本任务自跑），
#   而行为差分是 REAL push rc=1 + 🔴 拒绝推送 refs/heads/main vs MUTANT rc=0。
#
#   本常设网**真跑 hook**（printf … | bash <hook 路径>），锁六条推送形态的运行时 rc 与报文。
#
# 腿清单（全部源码树形态 · 直接跑仓库 flow-kit-bundle/hooks/pre-push/pre-push.sh）：
#   ① 干净 ref ⇒ rc=0
#   ② 泄漏 ref（探针拼接构造）⇒ rc≠0 且报文含「🔴 拒绝推送」+ 被拒 ref 名
#   ③ 纯删除推送（new sha = 40 个 0）⇒ rc=0 且报文含「ℹ️ 纯删除推送：跳过内容扫描」
#   ④ 畸形 stdin 行（缺 local sha）⇒ rc≠0 且报文含「pre-push stdin 行缺 local sha」
#   ⑤ 缺允许清单态（检查器在 + 清单缺）⇒ rc=2 且报文指名缺失清单路径
#   ⑥ 消费者形态（项目无 Makefile）⇒ 不因缺 Makefile 报红，但泄漏仍必须 rc≠0
#
# 分工核对（判据 ③ · 同名断言不得两处并存）：
#   T-FIX-14 的 test/test_install_layout.bats 覆盖**安装形态**（真实 install.sh 部署到
#   <proj>/.claude/hooks，经 .git/hooks/pre-push symlink 调用，腿①-⑧锁可达性与三态）。
#   本文件覆盖**源码树形态**（直接跑仓库 flow-kit-bundle/hooks/pre-push/pre-push.sh，
#   CWD = 无 Makefile 工作仓，自建沙箱 reference 目录）。两文件形态边界互斥，无重复用例：
#   `grep -c 'install_layout' test/test_pre_push_behavior.bats` = 0（本文件不含 install.sh
#   部署调用，只直接 bash 仓库本体）。
#
# 脱敏（L-129/137）：泄漏探针以片段拼接构造，文件内不出现真实账号或家目录字面整串。
#   make check-path-privacy 扫 test/** 与 flow-kit-bundle/test/**，拼接构造可绕过。

bats_require_minimum_version 1.5.0

setup() {
  # 向上找含 flow-kit-bundle/hooks 的目录（双源 test/ 与 flow-kit-bundle/test/ 都对）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  FK_ROOT="$d"
  HOOK_PATH="${T_FIX16_HOOK_PATH:-$FK_ROOT/flow-kit-bundle/hooks/pre-push/pre-push.sh}"
  REPO_CHECKER="$FK_ROOT/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh"

  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-prepush-behavior.XXXXXX")"

  # 固定桩 git 身份（夹具仓内 commit 用）
  export GIT_AUTHOR_NAME="fixture"
  export GIT_AUTHOR_EMAIL="fixture@example.invalid"
  export GIT_COMMITTER_NAME="fixture"
  export GIT_COMMITTER_EMAIL="fixture@example.invalid"
  # 禁 GPG 签名（夹具仓无配置）
  git config --global commit.gpgsign false 2>/dev/null || true

  # 泄漏探针拼接构造（L-137）：本文件内不出现真实账号字面整串
  PROBE_USER="zz-tfix16-probe"
  PROBE_LEAK="/home/""${PROBE_USER}""/secret.txt"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── 辅助：建工作仓 + 固定身份，返回工作仓路径 ──
#   不建 Makefile ⇒ bundle 形态 ⇒ hook 走随包检查器（需自建 reference 目录）
make_work_repo() {
  local sbx="$TEST_TMPDIR/work"
  mkdir -p "$sbx"
  cd "$sbx"
  git init -q
  git config user.name "fixture"
  git config user.email "fixture@example.invalid"
  git config commit.gpgsign false
  echo "$sbx"
}

# ── 辅助：在工作仓旁建沙箱 reference 目录 ──
#   从仓库拷贝 check-path-privacy.sh（逐字节一致）；allowlist 由调用方决定是否建。
#   bundle 形态下 hook 候选 ① = HOOK_DIR/../flow-kit/reference ⇒ 仓库 reference（有清单）。
#   为隔离夹具，让 HOOK_DIR 指向沙箱：用环境变量 T_FIX16_HOOK_PATH 覆盖到沙箱副本，
#   沙箱副本的 HOOK_DIR/../flow-kit/reference = 沙箱 reference（可控清单态）。
make_sandbox_hook() {
  local allowlist="$1"  # 'present' = 建注释-only 清单；'absent' = 不建
  local sbx_hook_dir="$TEST_TMPDIR/hooks/pre-push"
  mkdir -p "$sbx_hook_dir"
  # 从 HOOK_PATH（默认 = 仓库本体；变异腿用 T_FIX16_HOOK_PATH 覆盖为变异体）拷贝，
  # 保证沙箱副本与被测 hook 逐字节一致。
  cp "$HOOK_PATH" "$sbx_hook_dir/pre-push.sh"
  # 沙箱 reference 目录（HOOK_DIR = $sbx_hook_dir ⇒ .. = $TEST_TMPDIR/hooks
  # ⇒ ../flow-kit/reference = $TEST_TMPDIR/hooks/flow-kit/reference）
  local ref_dir="$TEST_TMPDIR/hooks/flow-kit/reference"
  mkdir -p "$ref_dir"
  cp "$REPO_CHECKER" "$ref_dir/check-path-privacy.sh"
  if [ "$allowlist" = "present" ]; then
    # 注释-only 清单（0 条目）合法：validate_allowlist_format 跳过 # 注释行
    printf '# fixture allowlist（0 条目）\n' > "$ref_dir/path-privacy-allowlist.txt"
  fi
  # 返回沙箱 hook 路径（HOOK_DIR 解析后指向沙箱 reference）
  echo "$sbx_hook_dir/pre-push.sh"
}

# ── 辅助：在工作仓建一个含泄漏的 commit，返回其 sha ──
make_leaky_commit() {
  local repo="$1"
  cd "$repo"
  printf 'SECRET=%s\n' "$PROBE_LEAK" > leaky.txt
  git add leaky.txt
  git commit -q -m "leaky fixture" >/dev/null 2>&1 || true
  LEAKY_SHA=$(git rev-parse HEAD)
  cd - >/dev/null
}

# ── 辅助：在工作仓建一个干净 commit，返回其 sha ──
make_clean_commit() {
  local repo="$1"
  cd "$repo"
  printf 'hello world\n' > clean.txt
  git add clean.txt
  git commit -q -m "clean fixture" >/dev/null 2>&1 || true
  CLEAN_SHA=$(git rev-parse HEAD)
  cd - >/dev/null
}

# ── 辅助：构造 pre-push stdin 一行 ──
#   格式: <local ref> <local sha> <remote ref> <remote sha>
make_prepush_stdin() {
  local ref="$1"
  local sha="$2"
  local remote_sha="${3:-0000000000000000000000000000000000000000}"
  printf 'refs/heads/%s %s refs/heads/%s %s\n' "$ref" "$sha" "$ref" "$remote_sha"
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ①：干净 ref ⇒ rc=0（检查器在 + allowlist 在 + 无泄漏）
#   前提自证：腿②会用同一夹具的泄漏探针证明检查器确会抓到泄漏，
#   避免干净腿空跑（TD-081 教训）。
# ═══════════════════════════════════════════════════════════════════════
@test "leg1: clean ref ⇒ rc=0 (checker present + allowlist present + no leak)" {
  local work
  work="$(make_work_repo)"
  local sandbox_hook
  sandbox_hook="$(make_sandbox_hook present)"
  make_clean_commit "$work"
  # 前提：断言本腿 hook 与仓库本体逐字节一致（真跑本体而非自造）
  cmp -s "$sandbox_hook" "$HOOK_PATH"

  cd "$work"
  run bash "$sandbox_hook" <<<"$(make_prepush_stdin main "$CLEAN_SHA")"
  cd - >/dev/null
  [ "$status" -eq 0 ]
  # 干净推送后 hook 跑 make check 目标；无 Makefile ⇒ 打印跳过
  [[ "$output" == *"项目 Makefile 未声明 check 目标：跳过"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ②：泄漏 ref ⇒ rc≠0 且报文含「🔴 拒绝推送」+ 被拒 ref 名
#   探针字面按 L-137 拼接构造（/home/<probe_user>/secret.txt）。
#   本腿同时承担腿①的前提自证：同一夹具下泄漏必被抓。
# ═══════════════════════════════════════════════════════════════════════
@test "leg2: leaky ref ⇒ rc≠0 + report contains 「🔴 拒绝推送」 + rejected ref name" {
  local work
  work="$(make_work_repo)"
  local sandbox_hook
  sandbox_hook="$(make_sandbox_hook present)"
  make_leaky_commit "$work"
  cmp -s "$sandbox_hook" "$HOOK_PATH"

  cd "$work"
  run bash "$sandbox_hook" <<<"$(make_prepush_stdin main "$LEAKY_SHA")"
  cd - >/dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 拒绝推送"* ]]
  # 报文含被拒 ref 名（refs/heads/main）
  [[ "$output" == *"refs/heads/main"* ]]
  # 报文含泄漏归因
  [[ "$output" == *"路径隐私泄漏"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ③：纯删除推送（new sha = 40 个 0，old sha ≠ 0）⇒ rc=0 且报文含跳过措辞
#   实现位 flow-kit-bundle/hooks/pre-push/pre-push.sh:181-182
# ═══════════════════════════════════════════════════════════════════════
@test "leg3: pure delete push (local_sha = 40 zeros) ⇒ rc=0 + skip message" {
  local work
  work="$(make_work_repo)"
  local sandbox_hook
  sandbox_hook="$(make_sandbox_hook present)"
  make_clean_commit "$work"
  cmp -s "$sandbox_hook" "$HOOK_PATH"

  cd "$work"
  # local_sha = 40 个 0 ⇒ 纯删除推送
  local zeros="0000000000000000000000000000000000000000"
  run bash "$sandbox_hook" <<<"$(make_prepush_stdin main "$zeros" "$CLEAN_SHA")"
  cd - >/dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ️ 纯删除推送：跳过内容扫描"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ④：畸形 stdin 行（缺 local sha）⇒ rc≠0 且报文含「pre-push stdin 行缺 local sha」
#   fail-closed（exit 1），不得 continue。
# ═══════════════════════════════════════════════════════════════════════
@test "leg4: malformed stdin (missing local sha) ⇒ rc≠0 + fail-closed message" {
  local work
  work="$(make_work_repo)"
  local sandbox_hook
  sandbox_hook="$(make_sandbox_hook present)"
  cmp -s "$sandbox_hook" "$HOOK_PATH"

  cd "$work"
  # 畸形行：只有 ref 名，无 local sha（字段不足）
  run bash "$sandbox_hook" <<<"refs/heads/main"
  cd - >/dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"pre-push stdin 行缺 local sha"* ]]
  # fail-closed 语义
  [[ "$output" == *"fail-closed"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ⑤：缺允许清单态（检查器在 + 清单缺）⇒ rc=2 且报文指名缺失清单路径
#   T-FIX-13 语义，具名 fail-closed（exit 2），不得回退。
# ═══════════════════════════════════════════════════════════════════════
@test "leg5: checker present + allowlist absent ⇒ rc=2 + named path-privacy-allowlist.txt" {
  local work
  work="$(make_work_repo)"
  # allowlist='absent' ⇒ 沙箱 reference 有 check-path-privacy.sh 无 allowlist
  local sandbox_hook
  sandbox_hook="$(make_sandbox_hook absent)"
  make_leaky_commit "$work"
  cmp -s "$sandbox_hook" "$HOOK_PATH"

  cd "$work"
  run bash "$sandbox_hook" <<<"$(make_prepush_stdin main "$LEAKY_SHA")"
  cd - >/dev/null
  # 状态 ②：具名 fail-closed，exit 2（不得回退到 rc=0，不得归因为泄漏）
  [ "$status" -eq 2 ]
  [[ "$output" == *"找到路径隐私检查器但缺少允许清单"* ]]
  [[ "$output" == *"path-privacy-allowlist.txt"* ]]
  [[ "$output" == *"fail-closed"* ]]
  # 不得归因为泄漏（配置缺失 ≠ 泄漏）
  [[ "$output" != *"含路径隐私泄漏"* ]]
}

# ═══════════════════════════════════════════════════════════════════════
# 腿 ⑥：消费者形态（项目无 Makefile）⇒ 不因缺 Makefile 报红，但泄漏仍必须 rc≠0
#   与 T-FIX-14 的安装形态腿同源；T-FIX-14 test_install_layout.bats 腿①-② 锁
#   安装形态（.claude/hooks + symlink）的泄漏拒绝，本腿锁源码树形态
#   （直接 bash 仓库本体 + 无 Makefile 工作仓）的同一语义，分工互斥。
# ═══════════════════════════════════════════════════════════════════════
@test "leg6: consumer form (no Makefile) ⇒ not red for missing Makefile, but leak must rc≠0" {
  local work
  work="$(make_work_repo)"
  # 工作仓无 Makefile（make_work_repo 不建）⇒ bundle 形态
  local sandbox_hook
  sandbox_hook="$(make_sandbox_hook present)"
  make_leaky_commit "$work"
  cmp -s "$sandbox_hook" "$HOOK_PATH"
  # 显式断言前提：工作仓无 Makefile
  [ ! -f "$work/Makefile" ]

  cd "$work"
  run bash "$sandbox_hook" <<<"$(make_prepush_stdin main "$LEAKY_SHA")"
  cd - >/dev/null
  # 泄漏必须拒绝（rc≠0），不得因缺 Makefile 放行
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 拒绝推送"* ]]
  # 不得打印「未找到可用的路径隐私检查器」（检查器在，不是消费者兼容跳过）
  [[ "$output" != *"未找到可用的路径隐私检查器"* ]]
}
