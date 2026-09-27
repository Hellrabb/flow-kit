#!/usr/bin/env bats
# test_install_jq_guard.bats — 缺 jq 时安装必须中止且不得破坏 settings.json（T-FIX-15 · R5-6/27）
#
# 为什么存在（R5-6 🔴）：
#   AC-2「缺 jq 时安装必须中止且不得破坏 settings.json」此前没有任何常设 bats。
#   跨模型变异实证：删掉 install_hooks.sh 的两道 jq 守卫（入口 :189-192 与合并前
#   :365-368）后，缺 jq 场景下 install_hooks() 仍 rc=0 并打印 4×
#   「⚠️ …合并失败，请手动检查」（静默谎报成功）——根因是 _install_hook_wiring
#   的四次调用（install_hooks.sh:423/427/431/436）无 || 错误处理，且 install_hooks()
#   末尾无显式 return，故吞掉 _install_hook_wiring 的 return 1 后返回 0。
#
#   本常设网分两路：
#     路A（install.sh 入口前置 check_jq）：install.sh --global --no-brooks --user
#         + 影子 PATH 排 jq ⇒ 必须在触及任何 hook 部署动作前 rc≠0 且含具名依赖诊断。
#     路B（install_hooks.sh 内部两道守卫）：直接 source install_hooks.sh + 影子 PATH
#         排 jq ⇒ 必须 rc=1 + ❌缺少依赖 jq；settings.json 未被截断为空 +
#         permissions.allow 与既有 Stop hook 存活（非字节相等）；无 *.tmp 残片。
#
#   变异腿（判据边界 #2④）：删两道守卫后，路B 的 rc≠0 断言必须转 not ok
#   （变异体返回 rc=0）。变异在 /tmp 副本上做，绝不改仓库文件。
#
# 口径（R5-27 🟢）：AC-2 断言面 = 「未被截断为空 + allow/hook 存活」，明确非字节相等
#   （对照态安装器合法追加 hooks 会增大文件）。TEST.md:55 已据此订正。
#
# 脱敏（L-129/137）：本文件内不出现真实账号字面；SBX 路径由 mktemp 生成。

bats_require_minimum_version 1.5.0

# ── 双源 FK_ROOT（与 test_install_layout.bats 一致）──
setup() {
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  FK_ROOT="$d"
  INSTALL_SH="$FK_ROOT/flow-kit-bundle/install.sh"
  INSTALL_HOOKS_SH="$FK_ROOT/flow-kit-bundle/lib/install_hooks.sh"
  PATHS_SH="$FK_ROOT/flow-kit-bundle/lib/paths.sh"

  TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/fk-jq-guard.XXXXXX")"
  HOME_DIR="$TEST_TMPDIR/home"
  mkdir -p "$HOME_DIR/.claude/hooks"
  export HOME="$HOME_DIR"
  export FLOW_KIT_YES=1

  # 影子 bin：仅软链 install_hooks/write_settings_file/resolve_paths 所需命令，不含 jq。
  SHADOW_BIN="$TEST_TMPDIR/shadow"
  mkdir -p "$SHADOW_BIN"
  local c
  for c in bash sh git mktemp cp chmod mkdir cat printf sed grep ln readlink wc \
           dirname basename mv rm test find; do
    ln -sf "/usr/bin/$c" "$SHADOW_BIN/$c" 2>/dev/null || true
  done
  # 前提自检（TD-081 家族）：影子 PATH 下 jq 必须不可见，mkdir 必须可见。
  if PATH="$SHADOW_BIN" command -v jq >/dev/null 2>&1; then
    skip "影子 PATH 前提未满足：jq 仍可见"
  fi
  if ! PATH="$SHADOW_BIN" command -v mkdir >/dev/null 2>&1; then
    skip "影子 PATH 前提未满足：mkdir 不可见"
  fi
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── 辅助：写一份含 permissions.allow + 既有 Stop hook 的 settings.json ──
#   对照态（REQUIREMENT.md AC-2 验证码）：预置 allow + hook，断言安装后不被截断为空
#   且 allow/hook 存活（非字节相等——安装器合法追加 hooks 会增大文件）。
write_seed_settings() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  printf '%s' '{
  "permissions": { "allow": ["Bash(ls:*)"] },
  "hooks": { "Stop": [ { "matcher": "", "hooks": [ { "type": "command", "command": "true" } ] } ] }
}
' > "$target"
}

# ═══════════════════════════════════════════════════════════════════════
# 路A 腿①：install.sh 入口 check_jq 必须在任何 hook 部署前拦下缺 jq
#   install.sh --global --no-brooks --user + 影子 PATH 排 jq ⇒ rc≠0 + 具名依赖诊断
# ═══════════════════════════════════════════════════════════════════════
@test "路A: install.sh --global --no-brooks --user 缺 jq 时 rc≠0 且含具名依赖诊断" {
  write_seed_settings "$HOME_DIR/.claude/settings.json"
  local before_size
  before_size=$(wc -c < "$HOME_DIR/.claude/settings.json")

  # 影子 PATH 排 jq，真实 install.sh 入口
  PATH="$SHADOW_BIN" run bash "$INSTALL_SH" --global --no-brooks --user

  # 判据①：rc≠0
  [ "$status" -ne 0 ]

  # 判据②：stderr/stdout 含具名依赖诊断（install.sh:125-135 check_jq 报文）
  grep -qF '缺少依赖 jq' <<<"$output" || grep -qF '缺少依赖 jq' <<<"$stderr"

  # 判据③：settings.json 未被截断为空（[ -s ]）——check_jq 在任何写盘前退出
  [ -s "$HOME_DIR/.claude/settings.json" ]
  local after_size
  after_size=$(wc -c < "$HOME_DIR/.claude/settings.json")
  [ "$after_size" -eq "$before_size" ]

  # 判据④：permissions.allow 与既有 Stop hook 存活
  grep -qF 'Bash(ls:*)' "$HOME_DIR/.claude/settings.json"
  grep -qF '"Stop"' "$HOME_DIR/.claude/settings.json"
}

# ═══════════════════════════════════════════════════════════════════════
# 路B 腿②：install_hooks.sh 入口守卫（install_hooks.sh:189-192）缺 jq 时 rc=1
#   直接 source install_hooks.sh（绕过 install.sh 入口 check_jq），断言内部守卫有牙。
#   这一路是变异证明的锚点：删该守卫 ⇒ rc=0 ⇒ 本腿 not ok。
# ═══════════════════════════════════════════════════════════════════════
@test "路B: install_hooks.sh 入口守卫缺 jq 时 rc=1 + ❌缺少依赖 jq + settings 未被截断" {
  write_seed_settings "$HOME_DIR/.claude/settings.json"
  local before_size
  before_size=$(wc -c < "$HOME_DIR/.claude/settings.json")

  # 真实 PATH 完成 source（resolve_paths 需 HOME 已指向 SBX），仅 install_hooks 调用走影子 PATH
  run bash -c '
    source "'"$PATHS_SH"'"
    resolve_paths claude
    source "'"$INSTALL_HOOKS_SH"'"
    export PATH="'"$SHADOW_BIN"'"
    install_hooks "'"$HOME_DIR"'" user
    echo "RC=$?"
  '

  # 判据①：rc=1（install_hooks.sh:189-192 守卫 return 1）
  grep -qF 'RC=1' <<<"$output"
  # 判据②：含具名依赖诊断
  grep -qF '缺少依赖 jq' <<<"$output"
  # 判据③：settings.json 未被截断为空
  [ -s "$HOME_DIR/.claude/settings.json" ]
  local after_size
  after_size=$(wc -c < "$HOME_DIR/.claude/settings.json")
  [ "$after_size" -eq "$before_size" ]
  # 判据④：permissions.allow 与既有 Stop hook 存活
  grep -qF 'Bash(ls:*)' "$HOME_DIR/.claude/settings.json"
  grep -qF '"Stop"' "$HOME_DIR/.claude/settings.json"
  # 判据⑤：未出现静默谎报（无 ⚠️ 合并失败/写入失败）
  ! grep -qF '合并失败' <<<"$output"
  ! grep -qF '写入失败' <<<"$output"
}

# ═══════════════════════════════════════════════════════════════════════
# 路B 腿③：缺 jq 中止后无 *.tmp / *.tmp.* 残片留在目标目录
#   write_settings_file_atomic 用 mktemp "${target}.tmp.XXXXXX" + trap 兜底清理；
#   守卫在合并分支前 return 1，不应留下半写残片。
# ═══════════════════════════════════════════════════════════════════════
@test "路B: 缺 jq 中止后目标目录无 *.tmp / *.tmp.* 残片" {
  write_seed_settings "$HOME_DIR/.claude/settings.json"

  run bash -c '
    source "'"$PATHS_SH"'"
    resolve_paths claude
    source "'"$INSTALL_HOOKS_SH"'"
    export PATH="'"$SHADOW_BIN"'"
    install_hooks "'"$HOME_DIR"'" user
    echo "RC=$?"
  '
  grep -qF 'RC=1' <<<"$output"

  # 判据：目标 .claude 目录下无 *.tmp / *.tmp.* 残片
  local found
  found=$(find "$HOME_DIR/.claude" -name '*.tmp' -o -name '*.tmp.*' 2>/dev/null | head -1)
  [ -z "$found" ]
}

# ═══════════════════════════════════════════════════════════════════════
# 路B 腿④（变异反向控制）：删两道守卫后 install_hooks 必须 rc=0 + 4× ⚠️（静默谎报）
#   本腿断言「变异体确实会谎报」——证明守卫是唯一防线。
#   变异在 /tmp 副本上做（cp -a 到 mktemp -d），绝不改仓库文件。
#   若守卫被误删，路B 腿②会转 not ok（rc=0 不满足 rc=1）——本腿与之互补。
# ═══════════════════════════════════════════════════════════════════════
@test "路B 变异腿: 删两道 jq 守卫后 install_hooks rc=0 + 4× ⚠️（静默谎报成功）" {
  # 变异副本（/tmp 下，绝不改仓库文件）
  local mut
  mut="$(mktemp -d "${TMPDIR:-/tmp}/fk-jq-guard-mut.XXXXXX")"
  cp -a "$FK_ROOT/flow-kit-bundle" "$mut/flow-kit-bundle"

  # 删入口守卫（install_hooks.sh:189-192）+ 合并前守卫（:365-368）
  python3 - "$mut/flow-kit-bundle/lib/install_hooks.sh" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(
    r'  if ! command -v jq >/dev/null 2>&1; then\n'
    r'    echo "   ❌ 缺少依赖 jq：install_hooks 需要 jq 合并 settings\.json，已中止（尚未做任何写盘）" >&2\n'
    r'    return 1\n'
    r'  fi\n\n',
    '', s, count=1)
s3 = re.sub(
    r'      if ! command -v jq >/dev/null 2>&1; then\n'
    r'        echo "   ❌ jq 不可用，无法合并 \$\{settings_target\}（原文件未改动）" >&2\n'
    r'        return 1\n'
    r'      fi\n\n',
    '', s2, count=1)
open(p, 'w').write(s3)
PY

  # 断言变异真的删掉了两道守卫（TD-081：夹具状态显式断言）
  # grep -c 无匹配返回 rc=1，用 || true 转为 0 计数（ bats 不把 grep 未命中当失败）
  local guard_in guard_merge
  guard_in=$(grep -c '缺少依赖 jq' "$mut/flow-kit-bundle/lib/install_hooks.sh" || true)
  guard_merge=$(grep -c 'jq 不可用，无法合并' "$mut/flow-kit-bundle/lib/install_hooks.sh" || true)
  [ "$guard_in" -eq 0 ]
  [ "$guard_merge" -eq 0 ]

  write_seed_settings "$HOME_DIR/.claude/settings.json"
  local before_size
  before_size=$(wc -c < "$HOME_DIR/.claude/settings.json")

  # 变异体下 install_hooks 必须 rc=0 + 4× ⚠️（静默谎报）
  run bash -c '
    source "'"$mut"'/flow-kit-bundle/lib/paths.sh"
    resolve_paths claude
    source "'"$mut"'/flow-kit-bundle/lib/install_hooks.sh"
    export PATH="'"$SHADOW_BIN"'"
    install_hooks "'"$HOME_DIR"'" user
    echo "RC=$?"
  '

  # 判据①：变异体 rc=0（谎报成功——这正是守卫要拦的行为）
  grep -qF 'RC=0' <<<"$output"
  # 判据②：4× ⚠️ 合并失败（四个 hook wiring 都吞掉 return 1）
  local warn_count
  warn_count=$(grep -cF '合并失败' <<<"$output")
  [ "$warn_count" -eq 4 ]
  # 判据③：即便谎报，settings.json 仍未被截断为空（合并失败分支不写盘）
  [ -s "$HOME_DIR/.claude/settings.json" ]
  local after_size
  after_size=$(wc -c < "$HOME_DIR/.claude/settings.json")
  [ "$after_size" -eq "$before_size" ]
  # 判据④：permissions.allow 仍存活
  grep -qF 'Bash(ls:*)' "$HOME_DIR/.claude/settings.json"

  rm -rf "$mut"
}
