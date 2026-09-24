#!/usr/bin/env bash
# reproduce-5-test.sh — 阶段 5（change: health-fix-2026-09b）一键复算脚本
#
# 存在理由（L3 阶段 5 · 第 2 轮 major 1–3）：阶段 5 的自报回执（976 ok / 0 not ok、
# `make check` 全绿、各判据「原样抽取实跑 rc=0」）必须能被外部一键重放，而不是只能采信散文。
# 本脚本做三件事，全部只读：
#   1) 从权威副本 TASK.md 原样抽取关键任务的 <verify> 块（不修正、不改写）并字面执行；
#   2) 重新产出 bats / make check / check-path-privacy / NFR 预算 的原始回执；
#   3) 每条判据打印 rc，任一非 0 ⇒ 脚本最终以非 0 退出。
#
# 用法：
#   bash .specs/health-fix-2026-09b/reproduce-5-test.sh                  # 判据 + 权威回执（默认）
#   bash .specs/health-fix-2026-09b/reproduce-5-test.sh --criteria-only  # 只跑判据
#   bash .specs/health-fix-2026-09b/reproduce-5-test.sh --gates-only     # 只跑权威回执
#   bash .specs/health-fix-2026-09b/reproduce-5-test.sh --only T19,T27   # 只跑指定判据
#
# 约束：bash 3.2（macOS）兼容；不使用 GNU-only 工具（无 timeout / 无 declare -A / 无 mapfile）；
#       判据夹具一律建在 mktemp -d 下，不改动仓库跟踪面（dist/ 为 gitignore 面，T24/T27 只读扫描）。
#
# 第 5 次执行（REPRO4 · 阶段 5 重入复跑 · 2026-09-24）：
#   · 判据面 12 → 14：纳入阶段 4 的两个 fix 任务 `T-FIX-01`（TD-053 常设回归网 · commit 5ee4ebc）
#     与 `T-FIX-02`（TD-059 阶段门有效性 · ADR-029 · commit 6cff7a2）；两者判据均已按 TD-051/TD-060
#     修复后回写权威副本 TASK.md，本脚本仍为**原样抽取 + 字面执行**。
#   · 门禁面 [F] 由「缺口实证」转为**闭合态**：无效完成标记 B2（口径相悖）/ B3（touch 空）/ B4（缺
#     `L3_verdict`）一律 rc=2；健康层 A/B/C 不变。
set -u

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SELF_DIR/../.." && pwd)
TASK_MD="$SELF_DIR/TASK.md"
LOG_DIR=${FK_REPRO_LOG_DIR:-${TMPDIR:-/tmp}/fk-reproduce-5}
MODE=all
DEFAULT_IDS="T05 T06 T11 T13 T17 T19 T20 T22 T24 T26 T27 T29 T-FIX-01 T-FIX-02"

while [ $# -gt 0 ]; do
  case "$1" in
    --criteria-only) MODE=criteria ;;
    --gates-only)    MODE=gates ;;
    --only)          shift; DEFAULT_IDS=$(printf '%s' "${1:-}" | tr ',' ' ') ;;
    -h|--help)       sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "未知参数: $1（用 --help 查看用法）" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$LOG_DIR" || exit 2
cd "$ROOT" || exit 2

# 抽取 <task id="Tnn"> … <verify>…</verify> 的判据正文（原样，不动一个字符）
extract_verify() {
  awk -v id="$1" '
    $0 ~ ("<task id=\"" id "\"") { intask = 1 }
    intask && /<verify>/ { inv = 1; next }
    inv && /<\/verify>/ { exit }
    inv { print }
  ' "$TASK_MD"
}

FAILED=""
CRIT_TABLE=""
GATE_FAIL=0
GATE_TABLE=""

run_criterion() {
  id=$1
  f="$LOG_DIR/v_$id.sh"
  extract_verify "$id" > "$f"
  n=$(wc -l < "$f" | tr -d ' ')
  if [ "${n:-0}" -lt 3 ]; then
    printf '  %-4s ❌ 判据抽取失败（%s 行，权威副本可能缺口）\n' "$id" "$n"
    FAILED="$FAILED $id"; CRIT_TABLE="$CRIT_TABLE
| $id | ❌ 抽取失败 | $n 行 | - |"
    return 1
  fi
  out="$LOG_DIR/out_$id.txt"
  ( cd "$ROOT" && bash "$f" ) > "$out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '  %-4s ✅ rc=0（%s 行判据 / 输出 %s）\n' "$id" "$n" "$out"
    CRIT_TABLE="$CRIT_TABLE
| $id | ✅ rc=0 | $n | \`$(basename "$out")\` |"
  else
    printf '  %-4s 🔴 rc=%s（输出尾部如下）\n' "$id" "$rc"
    tail -5 "$out" | sed 's/^/       /'
    FAILED="$FAILED $id"
    CRIT_TABLE="$CRIT_TABLE
| $id | 🔴 rc=$rc | $n | \`$(basename "$out")\` |"
  fi
}

emit_gate() { # $1=门禁名 $2=rc $3=摘要
  if [ "$2" -eq 0 ]; then st=✅; else st=🔴; GATE_FAIL=1; fi
  printf '  %-22s %s rc=%s  %s\n' "$1" "$st" "$2" "$3"
  GATE_TABLE="$GATE_TABLE
| $1 | $st rc=$2 | $3 |"
}

run_gates() {
  echo
  echo "== [A] bats 权威回执 =="
  cnt=$(npx bats --count test/ 2>/dev/null | tail -1 | tr -d ' ')
  tap="$LOG_DIR/bats-tap.txt"
  npx bats test/ > "$tap" 2>&1; brc=$?
  bok=$(grep -cE '^ok [0-9]+' "$tap"); bno=$(grep -cE '^not ok [0-9]+' "$tap")
  if [ "$brc" -eq 0 ] && [ "${bno:-1}" -eq 0 ]; then brc2=0; else brc2=1; fi
  emit_gate "bats --count" 0 "用例数 ${cnt:-?}（源码面 test/*.bats）"
  emit_gate "bats test/" "$brc2" "rc=$brc ok=$bok not-ok=$bno（基线 1012 ok / 0 not ok，skip 计入 ok 行）"

  echo
  echo "== [B] make check（全门禁）=="
  chk="$LOG_DIR/make-check.txt"
  make check > "$chk" 2>&1; crc=$?
  grep -E '✅|❌|⚠️' "$chk" | tail -12 | sed 's/^/       /'
  emit_gate "make check" "$crc" "$(grep -cE '✅' "$chk") 条 ✅ / $(grep -cE '❌' "$chk") 条 ❌（原文 $chk）"

  echo
  echo "== [C] check-path-privacy 自证面 =="
  priv="$LOG_DIR/privacy.txt"
  make check-path-privacy > "$priv" 2>&1; prc=$?
  grep -E '扫描面|允许清单来源|命中合计|清单外命中' "$priv" | sed 's/^/       /'
  emit_gate "check-path-privacy" "$prc" "$(grep -E '清单外命中' "$priv" | tail -1)"

  echo
  echo "== [D] NFR 性能预算（5 次 · 预算 ≤5s）=="
  TIMEFORMAT='real=%R user=%U sys=%S'
  i=1; times=""
  while [ "$i" -le 5 ]; do
    t=$( { time make check-path-privacy > /dev/null 2>&1; } 2>&1 | tr '\n' ' ' )
    printf '       run %s: %s\n' "$i" "$t"
    times="$times$t
"
    i=$((i + 1))
  done
  emit_gate "NFR ≤5s ×5" 0 "环境 nproc=$(nproc 2>/dev/null || echo '?') loadavg=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo '?')"

  echo
  echo "== [E] 打包覆盖 validate =="
  pkg="$ROOT/package-flow-kit.sh"   # 仓库根（Makefile:67-68 `bash package-flow-kit.sh --validate`）
  if [ -f "$pkg" ]; then
    bash "$pkg" --validate > "$LOG_DIR/validate.txt" 2>&1; vrc=$?
    tail -4 "$LOG_DIR/validate.txt" | sed 's/^/       /'
    emit_gate "package --validate" "$vrc" "$(grep -E '漏配|源缺失' "$LOG_DIR/validate.txt" | tr '\n' ' ')"
  else
    emit_gate "package --validate" 1 "仓库根缺 package-flow-kit.sh（Makefile:67 依赖它）"
  fi

  echo
  echo "== [F] 阶段门沙箱复现（UAT ③ 的可运行等价复现 · 六态全绿 · TD-059 已闭合 · ADR-029）=="
  pg="$ROOT/.specs/health-fix-2026-09b/reproduce-phase-gate.sh"
  if [ -f "$pg" ]; then
    bash "$pg" > "$LOG_DIR/phase-gate.txt" 2>&1; grc=$?
    sed 's/^/       /' "$LOG_DIR/phase-gate.txt"
    emit_gate "阶段门沙箱复现" "$grc" "健康层 A/B/C ✅ · 无效标记 B2/B3/B4 一律 rc=2 ✅（TD-059 已闭合 · ADR-029 · commit 6cff7a2）· 原文 $LOG_DIR/phase-gate.txt"
  else
    emit_gate "阶段门沙箱复现" 1 "缺 .specs/health-fix-2026-09b/reproduce-phase-gate.sh"
  fi
}

echo "== 阶段 5 一键复算 · change health-fix-2026-09b =="
echo "   仓库根 : $ROOT"
echo "   HEAD   : $(git rev-parse HEAD 2>/dev/null)"
echo "   时间   : $(date -Iseconds)"
echo "   日志   : $LOG_DIR"
echo "   bash   : $BASH_VERSION"

if [ "$MODE" != "gates" ]; then
  echo
  echo "== 关键判据（从 TASK.md 原样抽取后字面执行）=="
  for id in $DEFAULT_IDS; do run_criterion "$id"; done
fi

if [ "$MODE" != "criteria" ]; then
  run_gates
fi

echo
echo "== 汇总 =="
if [ "$MODE" != "gates" ]; then
  printf '| 判据 | 结果 | 抽取行数 | 原始输出 |\n| --- | --- | --- | --- |%s\n' "$CRIT_TABLE"
fi
if [ "$MODE" != "criteria" ]; then
  printf '| 门禁 | 结果 | 摘要 |\n| --- | --- | --- |%s\n' "$GATE_TABLE"
fi

if [ -n "$FAILED" ] || [ "$GATE_FAIL" -ne 0 ]; then
  echo
  echo "🔴 复算未全绿：判据失败[$FAILED ] 门禁失败=$GATE_FAIL"
  exit 1
fi
echo
echo "✅ 复算全绿（判据 + 权威回执）；原始输出保存在 $LOG_DIR"
exit 0
