#!/bin/bash
# reproduce-phase-gate.sh — DSH 阶段门（PreToolUse independent-review-gate.sh）的可构造复现
#
# 用法: bash .specs/health-fix-2026-09b/reproduce-phase-gate.sh
#       FK_PHASEGATE_KEEP=1 bash …   # 保留沙箱目录以便事后勘查
#
# 目的（L3 第 3 轮 major 3 响应）：把「阶段门在真实使用路径上拦截 git commit」从**不可逆历史事件**
# 变成**可构造、可断言、可重复**的沙箱夹逼 —— 同一 change、同一 `git commit` 命令，只改沙箱状态：
#   A  阶段 5 已开双审（gate_config["5-test"]="both"）且**无** .done ⇒ 期望 rc=2 + 拒绝报文 + HEAD 不变
#   B  同一 change 改为只开 L2 + 合格 6 键 .done（健康态）          ⇒ 期望 rc=0 放行，且真 commit 成功（HEAD 前进）
#   B2 .done 内容与审查档不一致（pass vs fail）                     ⇒ 期望 rc=2（Tier-2 T4 口径比对）
#   B3 .done 被 touch 成 0 字节（存在但空）                          ⇒ 期望 rc=2（Tier-1 非空校验）
#   B4 .done 缺 L3_verdict 键（5 行 < MIN_MEANINGFUL_LINES=6）        ⇒ 期望 rc=2（Tier-1 键集/行数）
#   C  沙箱无 .flow-active（门不适用）                              ⇒ 期望 rc=0（fail-open 对照）
# 判别子：门禁外直连 git commit 可用 ⇒ 证明拦截来自门禁判定，而非命令形态或仓库损坏。
# B2/B3/B4 的历史（存档）：ADR-029（T-FIX-02）之前，门禁以「.done 是否存在」为界 ⇒ 这三态
# 一律 rc=0（TD-059 缺口实证）；修复后它们是**期望的健康行为**（存在 ≠ 有效）：阶段门在 commit
# 路径上必须跑完 Tier-1 元数据 + Tier-2 一致性校验才放行。
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SELF_DIR}/../.." && pwd)"
HOOK="${ROOT}/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh"
HOOK_BASE="${ROOT}/flow-kit-bundle/hooks"

[ -f "$HOOK" ] || { echo "🔴 未找到阶段门脚本: $HOOK" >&2; exit 3; }

SBX="$(mktemp -d "${TMPDIR:-/tmp}/fk-phasegate-XXXXXX")" || exit 3
CHANGE_ID="sbx-phase-gate"
CMD="git commit -m probe -- .specs/${CHANGE_ID}/TEST.md"
FAILED=0

cleanup() { [ "${FK_PHASEGATE_KEEP:-}" = "1" ] || rm -rf "$SBX"; }
trap cleanup EXIT

echo "== 沙箱 = ${SBX}"
echo "== 门禁 = ${HOOK}"

# ── 夹具底座：一个真 git 仓库（证明「门禁外 commit 可用」）+ 一个 change 目录 ──
git -C "$SBX" init -q
git -C "$SBX" -c user.email=sbx@example.invalid -c user.name=sbx commit -q --allow-empty -m seed
SEED_SHA="$(git -C "$SBX" rev-parse HEAD)"
mkdir -p "${SBX}/.specs/${CHANGE_ID}"
printf '# 沙箱阶段 5 工件\n' > "${SBX}/.specs/${CHANGE_ID}/TEST.md"
printf '## L2 盲审（沙箱夹具）\n\n**Verdict**: pass\n' > "${SBX}/.specs/${CHANGE_ID}/INDEPENDENT-REVIEW-5.md"

write_flow() { # $1 = gate 值
  cat > "${SBX}/.flow-active" <<EOF
{
  "change_id": "${CHANGE_ID}",
  "phase": "5",
  "goal": {
    "current_phase": "5",
    "auto_advance": false,
    "gate_config": { "5-test": "$1" },
    "phases_done": ["0", "1", "2", "3", "4"]
  }
}
EOF
}

run_gate() { # 在沙箱 cwd 下驱动门禁；输出写 $SBX/gate.out，rc 由全局 RC 带回
  local json
  json=$(printf '{"hook_event_name":"PreToolUse","session_id":"sbx","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$SBX" "$CMD")
  # 不覆盖 HOOK_BASE_DIR：本 hook 的默认值是「自己的目录」(…/hooks/pre-tool-use)，再 source ../stop/lib/common.sh。
  # 若误用 Stop 侧的 HOOK_BASE_DIR=…/hooks 约定，会解析到不存在的 …/stop/lib/common.sh 并 fail-close（见 TD-058）。
  printf '%s' "$json" | bash "$HOOK" > "${SBX}/gate.out" 2>&1
  RC=$?
}

check() { # $1 = 描述, $2 = 期望, $3 = 实际
  if [ "$2" = "$3" ]; then
    echo "  ✅ $1（$3）"
  else
    echo "  🔴 $1：期望 $2，实际 $3"
    FAILED=1
  fi
}

grep_out() { # $1 = 期望出现在门禁输出里的字面串
  if grep -qF -- "$1" "${SBX}/gate.out"; then
    echo "  ✅ 报文含「$1」"
  else
    echo "  🔴 报文缺「$1」；实际输出："
    sed 's/^/      | /' "${SBX}/gate.out"
    FAILED=1
  fi
}

echo
echo "── 对照 0：门禁外直连 ${CMD%% *} …（证明仓库本身可提交，拦截不是命令形态问题）"
git -C "$SBX" add -A >/dev/null 2>&1
( cd "$SBX" && git -c user.email=sbx@example.invalid -c user.name=sbx commit -q --allow-empty -m direct ) >/dev/null 2>&1
DIRECT_SHA="$(git -C "$SBX" rev-parse HEAD)"
check "门禁外直连 commit 成功（HEAD 前进）" "yes" "$([ "$DIRECT_SHA" != "$SEED_SHA" ] && echo yes || echo no)"
git -C "$SBX" reset -q --mixed "$SEED_SHA"   # 只回退 HEAD（--mixed 保留工作树，夹具文件不被删除）

echo
echo "── 状态 A：gate_config[\"5-test\"]=both 且无 .done（历史事件 ③ 的等价形态）"
write_flow "both"
rm -f "${SBX}/.specs/${CHANGE_ID}/.independent-review-5.done"
BEFORE_A="$(git -C "$SBX" rev-parse HEAD)"
run_gate
check "门禁 rc（拒绝）" "2" "$RC"
grep_out "⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。"
check "HEAD 未变" "$BEFORE_A" "$(git -C "$SBX" rev-parse HEAD)"

echo
echo "── 状态 B：gate_config[\"5-test\"]=L2 + 合格 .done（6 键 KVP · 阶段 5 健康态）── 同一命令应放行"
write_flow "L2"
cat > "${SBX}/.specs/${CHANGE_ID}/.independent-review-5.done" <<'DONE'
phase=5
change_id=sbx-phase-gate
written_by=sandbox-fixture
L2_verdict=pass
L3_verdict=skipped
artifacts=TEST.md,INDEPENDENT-REVIEW-5.md
DONE
run_gate
check "门禁 rc（放行）" "0" "$RC"
git -C "$SBX" add -A >/dev/null 2>&1
( cd "$SBX" && git -c user.email=sbx@example.invalid -c user.name=sbx commit -q -m after-gate ) >/dev/null 2>&1
check "放行后真 commit 生效（HEAD 前进）" "yes" "$([ "$(git -C "$SBX" rev-parse HEAD)" != "$SEED_SHA" ] && echo yes || echo no)"
git -C "$SBX" reset -q --mixed "$SEED_SHA"   # 只回退 HEAD，保留工作树夹具（供状态 B2 继续使用）

echo
echo "── 状态 B2：.done 记 pass 而审查档记 fail（口径不一致 · Tier-2 T4 一致性）⇒ 期望 rc=2（存在 ≠ 有效 · ADR-029）"
# 可移植改档：不用 `sed -i`（GNU-only；macOS BSD sed 需 `-i ''`）⇒ 走临时文件 + mv
sed 's/^\*\*Verdict\*\*: pass$/**Verdict**: fail/' "${SBX}/.specs/${CHANGE_ID}/INDEPENDENT-REVIEW-5.md" > "${SBX}/md.tmp" && mv "${SBX}/md.tmp" "${SBX}/.specs/${CHANGE_ID}/INDEPENDENT-REVIEW-5.md"
run_gate
check "口径不一致（标记记 pass / 审查档记 fail）被拒" "2" "$RC"
grep_out "禁止 git commit。"
sed 's/^\*\*Verdict\*\*: fail$/**Verdict**: pass/' "${SBX}/.specs/${CHANGE_ID}/INDEPENDENT-REVIEW-5.md" > "${SBX}/md.tmp" && mv "${SBX}/md.tmp" "${SBX}/.specs/${CHANGE_ID}/INDEPENDENT-REVIEW-5.md"

echo
echo "── 状态 B3：.done 被 touch 成 0 字节（存在但空 · Tier-1 非空校验）⇒ 期望 rc=2（修复前：rc=0 缺口）"
DONE_FILE="${SBX}/.specs/${CHANGE_ID}/.independent-review-5.done"
cp "$DONE_FILE" "${DONE_FILE}.bak"
: > "$DONE_FILE"
run_gate
check "空标记（touch 0 字节）被拒" "2" "$RC"
grep_out "禁止 git commit。"
cp "${DONE_FILE}.bak" "$DONE_FILE"

echo
echo "── 状态 B4：.done 缺 L3_verdict 键（5 行 < MIN_MEANINGFUL_LINES=6 · Tier-1 键集/行数）⇒ 期望 rc=2（修复前：rc=0 缺口）"
grep -v '^L3_verdict=' "$DONE_FILE" > "${DONE_FILE}.tmp" && mv "${DONE_FILE}.tmp" "$DONE_FILE"
run_gate
check "残缺标记（删 L3_verdict 键 · 5 行 < 6 行下限）被拒" "2" "$RC"
printf 'L3_verdict=skipped\n' >> "$DONE_FILE"

echo
echo "── 状态 C：沙箱无 .flow-active（门不适用 ⇒ fail-open 对照）"
rm -f "${SBX}/.flow-active"
run_gate
check "门禁 rc（不适用）" "0" "$RC"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "✅ 阶段门复现：健康层全绿 —— A 拒绝且 HEAD 不变 · B 放行且 commit 真的生效 · B2/B3/B4 无效标记一律拒绝（存在 ≠ 有效 · ADR-029）· C 门不适用放行；判别子：门禁外直连 commit 可用 ⇒ 拦截确由门禁判定产生。"
  echo "ℹ️ 历史对照（TD-059 缺口实证）：修复前 B2（口径相悖）/ B3（空标记）/ B4（缺键）均是「存在即放行」的 rc=0；现收敛为 rc=2。"
  exit 0
fi
echo "🔴 阶段门复现失败（见上）" >&2
exit 1
