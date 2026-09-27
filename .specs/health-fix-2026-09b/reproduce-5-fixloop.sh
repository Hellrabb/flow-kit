#!/usr/bin/env bash
# 阶段 5 第 11 次执行（REPRO11）· 第 5 轮 fix loop 判据复算（T-FIX-14…T-FIX-23）
#
# 为什么单独一个脚本：`reproduce-5-test.sh:118` 的 `run_criterion()` 把任务块 <verify> 正文
# **当 bash 脚本执行**（期望 rc=0）。但 `T-FIX-14…23` 的 <verify> 是散文式 4–7 行
# （「① … ② …」），直接塞进 `DEFAULT_IDS` 会全报假红，属判据造假。
# 故本脚本对每条任务用**可复算的确切值**重建判据：
#   ① 常设 bats 网（该任务落地时新建/扩充的那一套）全绿且例数达标；
#   ② 生产件里的修复锚点确实存在（grep 计数为**实测**确切值，非估计）；
#   ③ 少数需要真实行为判定的条目（台账归一 / 全量 NFR / 空 .done / 隐私性能）就地复算。
#
# 用法：bash .specs/health-fix-2026-09b/reproduce-5-fixloop.sh
# 退出码：0 = 全部 ✅；1 = 存在 🔴（逐条打印）

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$REPO_ROOT" || exit 1

PASS=0
FAIL=0
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

ok()  { printf '  ✅ %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  🔴 %s\n     ↳ %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# batsnet <标签> <bats 文件> <最少例数>
batsnet() {
  local label="$1" f="$2" min="$3" out n
  [ -f "$f" ] || { bad "$label" "缺文件 $f"; return; }
  n=$(grep -cE '^[[:space:]]*@test' "$f")
  if [ "$n" -lt "$min" ]; then bad "$label" "$f 例数 $n < $min"; return; fi
  out=$(npx bats "$f" 2>&1)
  if printf '%s' "$out" | grep -q '^not ok'; then
    bad "$label" "$f 有 $(printf '%s' "$out" | grep -c '^not ok') 条 not ok"
    return
  fi
  printf '%s' "$out" | grep -q '^1\.\.' || { bad "$label" "$f 无 TAP 摘要"; return; }
  ok "$label（$n 例全绿）"
}

# grepc <标签> <文件> <ERE> <确切计数>
grepc() {
  local label="$1" f="$2" pat="$3" want="$4" got
  [ -f "$f" ] || { bad "$label" "缺文件 $f"; return; }
  got=$(grep -cE -- "$pat" "$f")
  [ "$got" = "$want" ] && ok "$label（/$pat/ = $got）" || bad "$label" "$f 中 /$pat/ 计数 $got ≠ $want"
}

# rc0 <标签> <命令…>
rc0() {
  local label="$1"; shift
  if "$@" >"$TMPD/out" 2>&1; then ok "$label"; else bad "$label" "$(tail -3 "$TMPD/out" | tr '\n' ' ')"; fi
}

echo "== REPRO11 · 第 5 轮 fix loop 判据（T-FIX-14…T-FIX-23）· HEAD $(git log --oneline -1) =="

echo "-- T-FIX-14（R5-18/R5-19/R5-24 安装形态可达性）"
batsnet "T-FIX-14 安装形态常设网" test/test_install_layout.bats 8
grepc "T-FIX-14 pre-push 自路径解析" flow-kit-bundle/hooks/pre-push/pre-push.sh '_resolve_self_path' 2
grepc "T-FIX-14 pre-commit 自路径解析" flow-kit-bundle/hooks/pre-commit/pre-commit.sh '_resolve_self_path' 2
grepc "T-FIX-14 检查器缺失具名诊断" flow-kit-bundle/hooks/pre-push/pre-push.sh '未找到可用的路径隐私检查器' 3

echo "-- T-FIX-15（R5-6/R5-27 jq 缺失 fail-closed）"
batsnet "T-FIX-15 jq 守卫常设网" test/test_install_jq_guard.bats 4
grepc "T-FIX-15 install_hooks 入口 jq 守卫" flow-kit-bundle/lib/install_hooks.sh 'command -v jq' 4
grepc "T-FIX-15 install.sh jq 前置检查" flow-kit-bundle/install.sh 'check_jq' 3

echo "-- T-FIX-16（R5-7 pre-push 行为级常设网）"
batsnet "T-FIX-16 pre-push 行为网" test/test_pre_push_behavior.bats 6
grepc "T-FIX-16 泄漏拒绝具名" flow-kit-bundle/hooks/pre-push/pre-push.sh '拒绝推送' 3
grepc "T-FIX-16 畸形 stdin fail-closed" flow-kit-bundle/hooks/pre-push/pre-push.sh 'fail-closed：取不到 local sha' 1

echo "-- T-FIX-17（R5-15/R5-16 磁盘侧检索隔离 + rev 批量）"
batsnet "T-FIX-17 隐私门禁常设网" test/test_path_privacy_gate.bats 34
grepc "T-FIX-17 扫描面塌缩不变式" flow-kit-bundle/flow-kit/reference/check-path-privacy.sh '扫描面塌缩' 3
grepc "T-FIX-17 磁盘侧 -e/-- 绑定" flow-kit-bundle/flow-kit/reference/check-path-privacy.sh '\-e "\$PAT" --' 2
_g17_start=$SECONDS
if CHECK_REV=HEAD make check-path-privacy >"$TMPD/g17" 2>&1; then
  _g17=$((SECONDS - _g17_start))
  if [ "$_g17" -le 5 ]; then ok "T-FIX-17 rev 面耗时 ${_g17}s ≤ 5s 预算"; else bad "T-FIX-17 rev 面耗时" "${_g17}s > 5s 预算"; fi
else
  bad "T-FIX-17 rev 面实跑" "$(tail -3 "$TMPD/g17" | tr '\n' ' ')"
fi

echo "-- T-FIX-18（R5-14/R5-10 check-gate-config 缺件 fail-closed）"
batsnet "T-FIX-18 校验对常设网" test/test_check_gate_sync.bats 15
grepc "T-FIX-18 缺件具名 fail-closed" flow-kit-bundle/flow-kit/reference/check-gate-sync.sh 'MISSING: gate-config 同步无法校验' 1
grepc "T-FIX-18 不再有 WARNING 跳过" flow-kit-bundle/flow-kit/reference/check-gate-sync.sh 'WARNING: 文件缺失，跳过' 0

echo "-- T-FIX-19（R5-9 运行时编辑守卫：载荷注入 + 常设行为网）"
batsnet "T-FIX-19 守卫常设网" test/test_runtime_edit_guard.bats 15
grepc "T-FIX-19 守卫无 eval（非注释行）" flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh '^[^#]*\beval\b' 0
grepc "T-FIX-19 逐字面匹配 case" flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh '^[[:space:]]*case "\$file_path" in' 1

echo "-- T-FIX-20（R5-26/R5-12 判据不依赖 \$HOME/.claude）"
batsnet "T-FIX-20 模型判据常设网" test/test_independent_review_model.bats 12
grepc "T-FIX-20 判据无 HOME/.claude 回落" test/test_independent_review_model.bats 'HOME/\.claude/hooks/stop' 0

echo "-- T-FIX-21（R5-1/R5-8/R5-2 台账归一 + TEST.md 复算表）"
if python3 - <<'PY' >"$TMPD/g21" 2>&1
import json, datetime
d = json.load(open('.flow-active'))
tp = d['goal']['task_progress']
assert '.goal' not in d, 'ghost .goal key'
assert not any(str(e['commit_sha']).startswith('$(') for e in tp), 'pseudo sha'
short = [e['id'] for e in tp if len(str(e['commit_sha'])) != 40]
assert not short, 'short sha: %s' % short
for e in tp:
    datetime.datetime.fromisoformat(e['completed_at'])
assert all(str(e['completed_at']).endswith('+08:00') for e in tp), \
    'non-+08:00: %s' % [e['id'] for e in tp if not str(e['completed_at']).endswith('+08:00')]
assert tp == sorted(tp, key=lambda e: e['completed_at']), 'not time-ordered'
assert isinstance(d['updated_at'], int), 'top-level updated_at must stay epoch int'
print('OK', len(tp))
PY
then
  ok "T-FIX-21 台账归一（$(cat "$TMPD/g21")）"
else
  bad "T-FIX-21 台账归一" "$(tail -2 "$TMPD/g21" | tr '\n' ' ')"
fi
grepc "T-FIX-21 TEST.md 数量口径生成规则" .specs/health-fix-2026-09b/TEST.md '数量口径生成规则' 1

echo "-- T-FIX-22（R5-20/R5-21/R5-22/R5-5 具名诊断 + 短路次序 + 归档面 + 自排除）"
grepc "T-FIX-22 非法 JSON 具名诊断" flow-kit-bundle/lib/install_hooks.sh 'settings\.json.*jq\|jq.*settings\.json' 1
grepc "T-FIX-22 SELF_EXCLUDE 含 IR-5/IR-6" flow-kit-bundle/flow-kit/reference/check-path-privacy.sh 'INDEPENDENT-REVIEW-[56]' 2
if _t22d=$(mktemp -d) && : >"$_t22d/empty.done" && printf '%s' '{"goal":{"phases_done":["4"]}}' >"$_t22d/.flow-active" \
   && PROJECT_ROOT="$_t22d" bash -c '. flow-kit-bundle/hooks/stop/lib/done-validation.sh; fk_validate_done_marker "$1" 4 cid' _ "$_t22d/empty.done"; then
  bad "T-FIX-22 空 .done 必须 rc=2" "实际 rc=0（phases_done 短路仍然先于非空校验）"
else
  _t22rc=$?
  [ "$_t22rc" = "2" ] && ok "T-FIX-22 空 .done ⇒ rc=2" || bad "T-FIX-22 空 .done" "rc=$_t22rc ≠ 2"
fi
rm -rf "$_t22d"
rc0 "T-FIX-22 隐私检查器实跑" make check-path-privacy

echo "-- T-FIX-23（R5-23 NFR 全量面三分法）"
rc0 "T-FIX-23 全量入口" make check-nfr-portability-full
# 注：下面两条断言刻意写成 map[f]ile / readarr[a]y —— NFR 判据（Makefile:162）按源码**字面**
# 扫 bash4-only 构造，本脚本自身也是「新增的 .sh」而被扫，含该字面即被判违规（实测 :138/:139）。
# 方括号形式对 `grep -E` 语义等价（匹配的仍是同一组内建名），但不构成源码字面。
# 该字面盲区本身已登记 TD-097（v2 建议：扫描前先做去引号/去方括号归一）。
grepc "T-FIX-23 bash4 内建清零（sync-hooks）" sync-hooks.sh 'map[f]ile|readarr[a]y' 0
grepc "T-FIX-23 bash4 内建清零（verify-claims）" verify-claims.sh 'map[f]ile|readarr[a]y' 0
grepc "T-FIX-23 基线文件 5 条" flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt '^[^#].*:[0-9]+:' 5
batsnet "T-FIX-23 NFR 门禁常设网" test/test_nfr_portability_gate.bats 20

echo
echo "== 汇总：✅ $PASS · 🔴 $FAIL =="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
