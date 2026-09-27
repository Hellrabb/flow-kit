#!/usr/bin/env bats
# test_runtime_edit_guard.bats — runtime-edit-guard.sh 常设回归网（TD-053 收敛 · AC-1）
#
# 为什么存在（TD-053）：AC-1 的守卫修复（路径解析 fail-closed、`~user`/空串拒绝、
#   维护源存在才 deny 的 fail-open 边界）此前只有 change 期判据覆盖。归档后若有人
#   把这几个态改坏（例如把相对路径重新放行、或把「维护源缺失 ⇒ 放行」去掉，
#   让非 flow-kit 的 user-level 配置被误拦），`make check` 仍可能全绿。
#   本文件把六个态固化为常设双态判据。
#
# 活性（为什么不是假绿）：setup 在**运行时**把仓内真实 hook 复制进夹具再驱动
#   ⇒ hook 被改坏、或被打成恒绿桩（exit 0）时，本文件的 exit 2 断言会转红。
#
# 夹具隔离：夹具建在 ${TMPDIR:-/tmp} 下（mktemp -d），teardown 清理；
#   不触碰工作树。**夹具自带 HOME**（`HOME=$TEST_TMPDIR/home`）⇒ 用例只引用
#   夹具内的 ~/.claude 路径，绝不读写真实家目录。维护源目录（hooks/stop、
#   skills/flow）默认**不预建**，「维护源在位」态的用例自己落地。
#
# 脱敏（L-129）：本文件不含真实账号路径形态；家目录一律以 $HOME 变量拼接。
#
# 断言约定（沿用 test_l3_review_defects_2026_09.bats 的 L3 04:42 教训：`run` 默认把
#   stderr 合进 $output 会造成假绿）：全文件统一 `run --separate-stderr`。
#   hook 的 deny 报文按契约走 stderr（exit 2 + 报文），故报文断言显式用 $stderr；
#   放行态断言两个流都不含 deny 报文。该 flag 需要 bats ≥ 1.5，故下一行声明最低版本。
bats_require_minimum_version 1.5.0

setup() {
  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-reg.XXXXXX")"
  FIXTURE="$TEST_TMPDIR/proj"
  HOME_DIR="$TEST_TMPDIR/home"
  SUT_REL="flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh"
  SRC_REL="flow-kit-bundle/hooks/stop/x.sh"
  SKILL_SRC_REL="flow-kit-bundle/skills/flow/x"

  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容 test/ 与 bundle 内镜像）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  SUT_SRC="$d/$SUT_REL"

  # 夹具项目根（含 flow-kit-bundle/ ⇒ hook 的 project_root 解析落在此）+ 夹具 HOME
  mkdir -p "$FIXTURE/$(dirname "$SUT_REL")"
  mkdir -p "$HOME_DIR/.claude/hooks/stop" "$HOME_DIR/.claude/skills/flow"
  # 运行时复制真实 hook（活性关键：恒绿桩会在此被吃到）
  cp -- "$SUT_SRC" "$FIXTURE/$SUT_REL"
  # 被编辑的运行时副本（hook 只读路径字符串，不读写它；此处仅为形态真实）
  printf '#!/bin/bash\n' > "$HOME_DIR/.claude/hooks/stop/x.sh"

  json() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
  guard() { printf '%s' "$1" | ( cd "$FIXTURE" && HOME="$HOME_DIR" bash "$SUT_REL" ); }
  mkfile() { mkdir -p "$FIXTURE/$(dirname "$1")"; printf '%b' "$2" > "$FIXTURE/$1"; }

  # ── T-FIX-19 载荷注入腿辅助 ──────────────────────────────────────────
  # 哨兵文件路径（夹具内，绝不碰真实家目录）。载荷若被执行 ⇒ 哨兵被创建。
  SENT="$HOME_DIR/sentinel_tfix19"
  # 载荷拼接构造（L-137/L-148）：源件内不得出现可直接运行的整串。
  #   payload() 输出形如 $(touch <哨兵>) —— 由 OPEN + cmd + CLOSE 三段拼成，
  #   grep 源件命中 `touch` 整串但不命中可直接运行的 $(touch ...) 字面。
  payload_open='$('
  payload_close=')'
  # payload() $1=哨兵路径 => stdout 一段 $(touch <哨兵>)（拼接，无整串字面）
  payload() { printf '%s%s%s' "$payload_open" "touch $1" "$payload_close"; }

  # 产品侧变异还原（判据③）：把 setup 复制的守卫副本里的纯参数展开 case 块
  #   还原为基线 eval 形态（change base 534e3e8 第 46 行）。变异件只落夹具，
  #   不进仓库。eval 行同样拼接构造，源件不散落 dollar-paren-eval 字面。
  #   mut_guard() $1=file_path => stdout 跑变异件的 rc（哨兵由调用方断言）。
  MUT_GUARD="$TEST_TMPDIR/mut-guard.sh"
  {
    local _o='$(' _e='eval echo "$file_path" 2>/dev/null'
    local _eval_line="  real_path=${_o}${_e}) || real_path=\"\$file_path\""
    local _skip=0 _l
    while IFS= read -r _l; do
      case "$_l" in
        '  case "$file_path" in') _skip=1; printf '%s\n' "$_eval_line"; continue ;;
        '  esac') [ "$_skip" -eq 1 ] && { _skip=0; continue; } ;;
      esac
      [ "$_skip" -eq 0 ] && printf '%s\n' "$_l"
    done < "$SUT_SRC" > "$MUT_GUARD"
  }
  mut_guard() { printf '%s' "$1" | ( cd "$FIXTURE" && HOME="$HOME_DIR" bash "$MUT_GUARD" ); }
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "Write + 相对路径 ⇒ exit 2 且报文含「无法解析为绝对路径」" {
  run --separate-stderr guard "$(json Write "hooks/stop/x.sh")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"无法解析为绝对路径"* ]]
}

@test "Write + ~user 形态 ⇒ exit 2（fail-closed，不做 passwd 查询）" {
  run --separate-stderr guard "$(json Write "~someone/x.sh")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"无法解析为绝对路径"* ]]
}

@test "Write + 空 file_path ⇒ exit 2" {
  run --separate-stderr guard "$(json Write "")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"为空串"* ]]
}

@test "非写工具 Bash ⇒ exit 0（不触发）" {
  run --separate-stderr guard "$(json Bash "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "非写工具 Read（路径命中运行时副本）⇒ exit 0" {
  run --separate-stderr guard "$(json Read "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "绝对路径命中 ~/.claude/hooks + 维护源在位 ⇒ exit 2 且报文含维护源路径" {
  mkfile "$SRC_REL" "#!/bin/bash\n"
  run --separate-stderr guard "$(json Write "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"维护源在"* ]]
  [[ "$stderr" == *"$FIXTURE/$SRC_REL"* ]]
}

@test "~/ 展开分支命中 ~/.claude/skills + 维护源在位 ⇒ exit 2" {
  mkfile "$SKILL_SRC_REL" "fixture skill\n"
  run --separate-stderr guard "$(json Write "~/.claude/skills/flow/x")"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"维护源在"* ]]
  [[ "$stderr" == *"$FIXTURE/$SKILL_SRC_REL"* ]]
}

@test "同一路径但维护源缺失 ⇒ exit 0（fail-open 边界：非 flow-kit 的 user-level 配置）" {
  run --separate-stderr guard "$(json Write "$HOME_DIR/.claude/hooks/stop/x.sh")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "~/.claude 之外的合法绝对路径 ⇒ exit 0（绝对值校验不误拒）" {
  run --separate-stderr guard "$(json Write "$FIXTURE/other/notes.md")"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

# ══════════════════════════════════════════════════════════════════════════
# T-FIX-19 · AC-1 载荷注入与 6 副本判据常设化（R5-9 🟡 闭合）
#
# 为什么存在（R5-9）：AC-1 的核心判据「载荷不被执行 · 6 副本 + 归档归零」此前只有
#   change 期一次性探针覆盖。归档后若有人把守卫改回 eval 求值形态，既有 9 例全绿
#   但载荷里的 $(touch 哨兵) 会被执行。本段把判别力固化为常设腿。
#
# 判别力在哨兵断言（主 agent 实测订正）：(a)(c) 新旧实现 rc 都是 0，
#   只有「哨兵文件不存在」能区分；(b) 现实现 rc=2 / 基线 rc=0，哨兵断言仍必要。
#
# 载荷拼接构造（L-137）：测试源件不出现可直接运行的 $(touch ...) 整串，
#   由 setup() 的 payload() 助手三段拼成。哨兵落夹具 $HOME_DIR 内，绝不碰真实家目录。
# ══════════════════════════════════════════════════════════════════════════

@test "T-FIX-19 (a) 运行面内载荷（派生维护源不存在）⇒ exit 0 + 哨兵不存在" {
  # 载荷路径 = $HOME/.claude/hooks/<$(touch 哨兵)>/x.sh —— 派生维护源不存在 ⇒ 现实现放行
  # 关键：哨兵必须不存在（证明 $(touch) 未被求值执行）
  rm -f "$SENT"
  local p; p="$(payload "$SENT")"
  run --separate-stderr guard "$(json Write "$HOME_DIR/.claude/hooks/$p/x.sh")"
  [ "$status" -eq 0 ]
  [ ! -e "$SENT" ]   # 哨兵不存在 ⇒ 载荷未被执行
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "T-FIX-19 (b) 运行面内载荷 + 字面建维护源 ⇒ exit 2 + 哨兵不存在 + 报文含 ⛔" {
  # 同 (a) 路径，但夹具里字面建出维护源（目录名 = 载荷串）⇒ 现实现 deny（rc=2）
  # 哨兵仍必须不存在（eval 形态会 rc=0 且哨兵被创建 ⇒ 本腿同时断 rc 与哨兵）
  rm -f "$SENT"
  local p; p="$(payload "$SENT")"
  mkdir -p "$FIXTURE/flow-kit-bundle/hooks/$p"
  printf '#!/bin/bash\n' > "$FIXTURE/flow-kit-bundle/hooks/$p/x.sh"
  run --separate-stderr guard "$(json Write "$HOME_DIR/.claude/hooks/$p/x.sh")"
  [ "$status" -eq 2 ]
  [ ! -e "$SENT" ]   # 哨兵不存在 ⇒ 载荷未被执行
  [[ "$stderr" == *"⛔"* ]]
}

@test "T-FIX-19 (c) 运行面外载荷 ⇒ exit 0 + 哨兵不存在" {
  # 载荷路径 = /tmp/<$(touch 哨兵)>/x —— 运行面之外，现实现放行；哨兵必须不存在
  rm -f "$SENT"
  local p; p="$(payload "$SENT")"
  run --separate-stderr guard "$(json Write "/tmp/$p/x")"
  [ "$status" -eq 0 ]
  [ ! -e "$SENT" ]
  [[ "$output$stderr" != *"维护源在"* ]]
}

@test "T-FIX-19 副本面：6 个部署副本 cmp -s 源件 + eval 形态静态计数 = 0" {
  # AC-1 Then ①：源树 + sync-hooks.sh --list 枚举的 6 个 DEST_ROOT 全部 eval-echo=0
  #   且每副本与源件逐字一致（cmp -s）。副本不存在则 skip（不因本机未安装而恒红/静默跳过）。
  local src="$SUT_SRC"
  local pat='\$\([[:space:]]*eval[[:space:]]'
  # 源件本身计数 = 0（自洽）—— grep -c 无匹配退出 1，吞掉以免触发 bats set -e
  local n; n=$(grep -cE "$pat" "$src" || true); [ "$n" -eq 0 ]
  local roots
  roots="$(bash sync-hooks.sh --list 2>/dev/null | grep '✅' | awk '{print $2}')"
  local cnt=0 d f diff
  for d in $roots; do
    f="$d/pre-tool-use/runtime-edit-guard.sh"
    if [ ! -d "$d" ]; then continue; fi   # 副本目录不存在（本机未装）⇒ 跳过该面，不计入 cnt
    [ -f "$f" ] || { echo "MISSING: $f" >&2; false; }
    cmp -s "$src" "$f"   # 逐字一致
    diff=$(grep -cE "$pat" "$f" 2>/dev/null || true); [ "$diff" -eq 0 ]
    cnt=$((cnt + 1))
  done
  [ "$cnt" -ge 1 ]   # 至少枚举到 1 个真实副本（否则枚举失效）
}

@test "T-FIX-19 dist 归档面：tarball 内 eval 形态计数 = 0" {
  # AC-1 Then ① 归档面（L2 C4）：dist/*.tgz 不得含可注入 hook。
  #   若无归档（glob 失效）则写明理由并给替代断言（对 dist/dsh-flow-kit/ 目录树计数）。
  shopt -s nullglob
  local archives=(dist/dsh-flow-kit-*.tgz)
  shopt -u nullglob
  local pat='\$\([[:space:]]*eval[[:space:]]'
  if [ "${#archives[@]}" -eq 0 ]; then
    # 替代断言（无 tarball 时）：对 dist/dsh-flow-kit/ 目录树计数 = 0
    [ -d dist/dsh-flow-kit ] || skip "无 dist 归档且无 dist/dsh-flow-kit 目录"
    local n; n=$(grep -rE "$pat" dist/dsh-flow-kit/ 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -eq 0 ]
  else
    local t n
    for t in "${archives[@]}"; do
      tar tzf "$t" >/dev/null 2>&1   # 归档可解析
      n=$(tar xzOf "$t" 2>/dev/null | grep -acE "$pat" || true)
      [ "$n" -eq 0 ]
    done
  fi
}

@test "T-FIX-19 产品侧变异腿：还原基线 eval 形态 ⇒ 哨兵被创建（not ok）" {
  # 判据③（产品侧变异，非夹具字符串形态）：setup() 的 mut_guard() 把守卫副本的
  #   纯参数展开 case 块还原为基线 eval 形态（change base 534e3e8 第 46 行）。
  #   变异件上，(a)(b)(c) 三形态的哨兵都必须被创建（载荷被执行）⇒ 本腿断言
  #   「哨兵存在」即证明 eval 求值回归。还原为现实现即转绿（上面 (a)(b)(c) 腿）。
  #   仅把夹具里的拼接改成字面一律不算通过。
  [ -f "$MUT_GUARD" ] || skip "变异件未生成"
  # 变异件静态计数 = 1（证明 eval 形态已还原）
  local pat='\$\([[:space:]]*eval[[:space:]]'
  local n; n=$(grep -cE "$pat" "$MUT_GUARD"); [ "$n" -eq 1 ]
  # (a) 运行面内载荷（维护源不存在）⇒ 变异件下哨兵必须被创建
  rm -f "$SENT"
  local p; p="$(payload "$SENT")"
  mut_guard "$(json Write "$HOME_DIR/.claude/hooks/$p/x.sh")" >/dev/null 2>&1 || true
  [ -e "$SENT" ]   # 哨兵存在 ⇒ 载荷被 eval 执行（变异态的 not ok 证据）
}
