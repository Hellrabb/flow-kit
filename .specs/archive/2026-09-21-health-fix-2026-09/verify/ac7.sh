#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-7 验证（可复制执行）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT   # 夹具并发隔离（勿共用固定 /tmp 名）
fails=""

# ① bats：950 ok / 0 not ok / 1 skip（精确相等）
npx --yes bats@1.13.0 test/ >$TMPD/ac7_test.log 2>&1 || true
ok=$(grep -cE '^ok ' $TMPD/ac7_test.log || true)
nok=$(grep -cE '^not ok ' $TMPD/ac7_test.log || true)
sk=$(grep -c '# skip' $TMPD/ac7_test.log || true)
[ "$ok"  -eq 950 ] || fails="$fails bats_ok=$ok(期望950)"
[ "$nok" -eq 0 ]   || fails="$fails bats_notok=$nok(期望0)"
[ "$sk"  -eq 1 ]   || fails="$fails bats_skip=$sk(期望1)"

# ② lint：error 级 0
make lint >$TMPD/ac7_lint.log 2>&1 || fails="$fails lint非零退出"

# ③ check-validate：漏配 0 / 源缺失 0
make check-validate >$TMPD/ac7_val.log 2>&1 || fails="$fails validate失败"
grep -qE '漏配 \(ERROR\): 0' $TMPD/ac7_val.log || fails="$fails 漏配非0"
grep -qE '源缺失 \(WARNING\): 0' $TMPD/ac7_val.log || fails="$fails 源缺失非0"

# ④ test 双源一致
make check-test-sync >$TMPD/ac7_sync.log 2>&1 || fails="$fails 双源不一致"

# ⑤ check-hooks-sync：漂移 0
make check-hooks-sync >$TMPD/ac7_hooks.log 2>&1 || fails="$fails hooks-sync失败"
grep -qE '漂移 0' $TMPD/ac7_hooks.log || fails="$fails 漂移非0"

# ⑥ verify-claims：13 ✅ / 0 ❌ ＋ F6 的两处修复必须生效
bash verify-claims.sh >$TMPD/ac7_vc.log 2>&1 || fails="$fails verify-claims非零退出"
# 抗漂移判据（L3 阶段7 R1 修）：**不写死精确计数** —— 写死会在新增断言时必然失配
# （实测：阶段 6 新增 §10d 使计数 13→14，而此处仍写 13 → 夹具必红，且使 CHANGELOG 的
#  "11 个夹具全 PASS" 成为假陈述）。改断：❌ 必须为 0，且 ✅ 不少于下限 13。
vc=$(grep -oE '复验结果: ✅ [0-9]+  ❌ [0-9]+' $TMPD/ac7_vc.log | tail -1)
[ -n "$vc" ] || fails="$fails verify-claims无复验结果行"
vc_ok=$(printf '%s' "$vc" | grep -oE '✅ [0-9]+' | grep -oE '[0-9]+')
vc_fail=$(printf '%s' "$vc" | grep -oE '❌ [0-9]+' | grep -oE '[0-9]+')
[ "${vc_fail:-1}" -eq 0 ] || fails="$fails verify-claims有失败项($vc)"
[ "${vc_ok:-0}" -ge 13 ] || fails="$fails verify-claims通过数${vc_ok}<13"
# F6(a)：三处硬编码已改为解析器 → 不应再因归档路径失败
grep -qE '§0.5.1 未列' $TMPD/ac7_vc.log && fails="$fails F6(a)未生效(仍有§0.5.1失败)"
# F6(b)：门数须动态推导（F1 加门后应为 6，且不得再出现写死的"五门"）
grep -qE 'make check [0-9]+ 门全绿' $TMPD/ac7_vc.log || fails="$fails F6(b)未生效(门数未动态推导)"
grep -q '五门' $TMPD/ac7_vc.log && fails="$fails F6(b)未生效(仍有写死『五门』)"

[ -z "$fails" ] || { echo "❌ FAIL:$fails"; exit 1; }
echo "✅ AC-7 PASS（六项全绿）"

