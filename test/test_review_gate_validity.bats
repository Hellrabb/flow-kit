#!/usr/bin/env bats
# test_review_gate_validity.bats — 阶段门标记有效性常设判据（TD-059 收敛 · ADR-029）
#
# 为什么存在（TD-059）：阶段门的 Gate3 曾以**文件存在性**判定「独立审查已完成」
#   ⇒ `touch` 出的空标记 / 缺键标记 / 与审查档口径相悖的标记都能放行 commit，而
#   Gate4 的 Tier-1/Tier-2 校验（`fk_validate_done_marker … transition`）在 commit
#   路径上不可达。本文件把「存在 ≠ 有效」固化为常设双态判据：同一夹具、同一命令，
#   只改标记/审查档状态，看门禁放行还是拒绝。
#
# 活性（为什么不是假绿）：夹具**以真实路径直接驱动**仓内生产件
#   `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（它按自身位置
#   source `../stop/lib/common.sh`、同目录 `gate-*.sh` 与 `stop/lib/done-validation.sh`，
#   故驱动的就是仓内单一来源的真实现件）。谁把判定改回 `[[ -f ]]`、或把
#   done-validation.sh 打桩成恒真，B2/B3/B4/B5 与函数级三例会转红。
#
# 夹具隔离：沙箱是 ${TMPDIR:-/tmp} 下 mktemp -d 的独立仓（含 git init），teardown 清理；
#   不触碰工作树。夹具文件名一律经变量拼接（含 $PHASE），本文件不含真实账号路径形态。
#
# 断言约定（沿用 test_l3_review_defects_2026_09.bats 的 L3 04:42 教训：`run` 默认把
#   stderr 合进 $output 会造成假绿）：全文件 `run --separate-stderr`，并**分通道**断言 ——
#   拒绝报文只认 stderr（$stderr），放行态额外断言 stderr 为空。
#   该 flag 需要 bats ≥ 1.5，故下一行声明最低版本。
bats_require_minimum_version 1.5.0

setup() {
  # 仓根：从 test/ 向上找含 flow-kit-bundle/hooks 的目录（兼容 test/ 与 bundle 内镜像）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do d="$(dirname "$d")"; done
  GATE_HOOK="$d/flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh"
  DONE_VALIDATION_LIB="$d/flow-kit-bundle/hooks/stop/lib/done-validation.sh"
  COMMON_LIB="$d/flow-kit-bundle/hooks/stop/lib/common.sh"

  # 环境洁净：hook 的 HOOK_BASE_DIR 须回落到「自身目录」，PROJECT_ROOT 由 hook 自设
  unset HOOK_BASE_DIR PROJECT_ROOT

  SBX="$(mktemp -d "${TMPDIR:-/tmp}/fk-gate-validity.XXXXXX")"
  CID="fix2-change"
  PHASE="5"
  SPECS_DIR="$SBX/.specs/$CID"
  MARK="$SPECS_DIR/.independent-review-${PHASE}.done"
  REVIEW_MD="$SPECS_DIR/INDEPENDENT-REVIEW-${PHASE}.md"
  CMD="git commit -m probe -- .specs/${CID}/TEST.md"
  EVENT_JSON="$SBX/event.json"

  mkdir -p "$SPECS_DIR"
  printf 'fixture\n' > "$SPECS_DIR/TEST.md"
  git -C "$SBX" init -q 2>/dev/null || true
  git -C "$SBX" config user.email fixture@example.invalid 2>/dev/null || true
  git -C "$SBX" config user.name fixture 2>/dev/null || true
}

teardown() {
  rm -rf "$SBX"
}

# ── 夹具写入器 ────────────────────────────────────────────────────────

write_flow_active() { # $1 = gate_config["5-test"] 的值；空串 ⇒ gate 未开
  printf '{"change_id":"%s","phase":"%s","goal":{"current_phase":"%s","phases_done":[],"gate_config":{"5-test":"%s"},"auto_advance":false}}\n' \
    "$CID" "$PHASE" "$PHASE" "$1" > "$SBX/.flow-active"
}

write_review_md() { # $1 = 审查档里的 **Verdict**
  { printf '# 独立审查 · 阶段 %s\n\n' "$PHASE"
    printf '## L2 盲审（第 1 轮）\n\n**Verdict**: %s\n' "$1"; } > "$REVIEW_MD"
}

write_marker() { # $1 = L2_verdict；$2 = L3_verdict（空串 ⇒ 该键整行不写）
  { printf 'phase=%s\nchange_id=%s\nwritten_by=fixture\n' "$PHASE" "$CID"
    printf 'L2_verdict=%s\n' "$1"
    if [ -n "$2" ]; then printf 'L3_verdict=%s\n' "$2"; fi
    printf 'artifacts=TEST.md,TASK.md\n'; } > "$MARK"
}

# ── 驱动器：真实 hook（PreToolUse stdin JSON）────────────────────────
# 断言口径：$status = hook 退出码（2 = deny / 0 = 放行），$stderr = 拒绝报文。
probe_gate() {
  printf '{"hook_event_name":"PreToolUse","session_id":"fixture","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' \
    "$SBX" "$CMD" > "$EVENT_JSON"
  run --separate-stderr bash "$GATE_HOOK" < "$EVENT_JSON"
}

# ══ 真实 hook 级：五态 + 两反面对照 ══════════════════════════════════

@test "A 无标记：commit 被拒（rc=2 · 拒绝报文在 stderr）" {
  write_flow_active both
  write_review_md pass
  rm -f "$MARK"
  probe_gate
  [ "$status" -eq 2 ]
  [ -z "$output" ]                                   # 报文只走 stderr（通道纪律）
  [[ "$stderr" == *"独立 review gate"* ]]
  [[ "$stderr" == *"禁止 git commit"* ]]
}

@test "B 6 键有效标记（与审查档一致）：commit 放行（rc=0 · stderr 空）" {
  write_flow_active both
  write_review_md pass
  write_marker pass pass
  probe_gate
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "B2 标记记 pass 而审查档记 fail：commit 被拒（rc=2 · Tier-2 口径比对）" {
  write_flow_active both
  write_review_md fail
  write_marker pass pass
  probe_gate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"禁止 git commit"* ]]
}

@test "B3 touch 空标记：commit 被拒（rc=2 · 「存在」不再等于「有效」）" {
  write_flow_active both
  write_review_md pass
  : > "$MARK"
  probe_gate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"禁止 git commit"* ]]
}

@test "B4 缺 L3_verdict（5 行 < 6 行下限）：commit 被拒（rc=2 · Tier-1 缺键）" {
  write_flow_active both
  write_review_md pass
  write_marker pass ""
  probe_gate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"禁止 git commit"* ]]
}

@test "B5 L2_verdict 值域非法：commit 被拒（rc=2 · Tier-1 值域校验）" {
  write_flow_active both
  write_review_md pass
  write_marker INVALID_VALUE pass
  probe_gate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"禁止 git commit"* ]]
}

@test "C 无 .flow-active：commit 放行（rc=0 · 门不适用 fail-open 对照）" {
  rm -f "$SBX/.flow-active"
  write_review_md pass
  : > "$MARK"
  probe_gate
  [ "$status" -eq 0 ]
}

@test "反面对照：gate 未开（gate_config 无 5-test）+ 无效标记 ⇒ 放行（rc=0）" {
  write_flow_active ""
  write_review_md pass
  write_marker pass ""
  probe_gate
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

# ══ 函数级契约：fk_independent_review_gate_active（真实 lib）═════════

source_dv_lib() {
  # shellcheck source=/dev/null
  source "$COMMON_LIB" 2>/dev/null || true
  # shellcheck source=/dev/null
  source "$DONE_VALIDATION_LIB" 2>/dev/null || true
}

@test "函数级：标记存在但无效（touch 空）⇒ 门仍生效（rc=0）" {
  write_flow_active both
  write_review_md pass
  : > "$MARK"
  source_dv_lib
  export PROJECT_ROOT="$SBX"
  run fk_independent_review_gate_active "$PHASE"
  [ "$status" -eq 0 ]
}

@test "函数级：标记存在且有效 ⇒ 放行（rc=1）" {
  write_flow_active both
  write_review_md pass
  write_marker pass pass
  source_dv_lib
  export PROJECT_ROOT="$SBX"
  run fk_independent_review_gate_active "$PHASE"
  [ "$status" -eq 1 ]
}

@test "函数级：phases_done 短路保持（历史阶段 + 无效标记 ⇒ 不追溯，rc=1）" {
  # phase 5 已归档（phases_done 含 5），残留的空标记不得让已完成的阶段回头变红
  printf '{"change_id":"%s","phase":"6","goal":{"current_phase":"6","phases_done":["4","5"],"gate_config":{"5-test":"both"},"auto_advance":false}}\n' \
    "$CID" > "$SBX/.flow-active"
  : > "$MARK"
  source_dv_lib
  export PROJECT_ROOT="$SBX"
  run fk_independent_review_gate_active "$PHASE"
  [ "$status" -eq 1 ]
}
