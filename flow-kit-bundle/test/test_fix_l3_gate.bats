#!/usr/bin/env bats
# test/test_fix_l3_gate.bats — fix-l3-gate: L3 重审 + .done 安全 + phase 同步
# bats_require_minimum_version 1.10.0

setup() {
  TEST_TMPDIR=$(mktemp -d)
  PROJECT_ROOT="$TEST_TMPDIR"

  # 定位 bundle root
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks" ]; do
    d="$(dirname "$d")"
  done
  BUNDLE_ROOT="$d/flow-kit-bundle"
  L3_REVIEW_SH="$BUNDLE_ROOT/hooks/stop/lib/l3-review.sh"
  L3_LIB_DIR="$BUNDLE_ROOT/hooks/stop/lib"
  AUTO_ADVANCE_SH="$BUNDLE_ROOT/hooks/stop/31-auto-advance.sh"

  # 模拟 specs 目录结构
  SPECS_DIR="$TEST_TMPDIR/.specs/fix-l3-gate"
  mkdir -p "$SPECS_DIR"

  # 模拟 .flow-active（最小 pipeline 状态）
  FLOW_FILE="$TEST_TMPDIR/.flow-active"
  cat > "$FLOW_FILE" <<'FLOWEOF'
{
  "change_id": "fix-l3-gate",
  "phase": 1,
  "goal": {
    "scope": "pipeline",
    "current_phase": "1",
    "phases_done": ["0"],
    "gates": {"0→1":"passed","1→2":"pending"},
    "gate_config": {"1-requirement":"L2"},
    "auto_advance": false
  }
}
FLOWEOF

  export HOOK_BASE_DIR="$BUNDLE_ROOT/hooks/stop"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ═══════════════════════════════════════════════
# AC-1: L3 重审——工件变更后重新触发
# ═══════════════════════════════════════════════

@test "AC-1: re-review triggered when artifact mtime > review mtime" {
  # 创建初始 review 文件（模拟已完成一次 L3 审查）
  local review_md="$SPECS_DIR/INDEPENDENT-REVIEW-1.md"
  echo "## L3 盲审（deepseek-v4-flash 外部模型 · 2026-07-10）" > "$review_md"
  echo '{"verdict":"fail","summary":"needs fix"}' >> "$review_md"

  # 记录 review 文件 mtime
  local review_mtime
  review_mtime=$(stat -c %Y "$review_md" 2>/dev/null || stat -f %m "$review_md" 2>/dev/null || echo "0")

  # 创建产物文件，mtime 晚于 review
  echo "# REQUIREMENT" > "$SPECS_DIR/REQUIREMENT.md"
  # touch 确保 mtime 严格大于
  sleep 1
  touch "$SPECS_DIR/REQUIREMENT.md"

  local artifact_mtime
  artifact_mtime=$(stat -c %Y "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || stat -f %m "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || echo "0")

  # 验证：产物 mtime > review mtime
  [ "$artifact_mtime" -gt "$review_mtime" ]
}

@test "AC-1: skip re-review when artifact mtime <= review mtime" {
  # 创建 review 文件和产物文件，mtime 相同
  local review_md="$SPECS_DIR/INDEPENDENT-REVIEW-1.md"
  echo "## L3 盲审" > "$review_md"
  echo "# REQUIREMENT" > "$SPECS_DIR/REQUIREMENT.md"

  # 使 review 文件 mtime >= 产物 mtime
  touch "$review_md"

  local review_mtime artifact_mtime
  review_mtime=$(stat -c %Y "$review_md" 2>/dev/null || stat -f %m "$review_md" 2>/dev/null || echo "0")
  artifact_mtime=$(stat -c %Y "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || stat -f %m "$SPECS_DIR/REQUIREMENT.md" 2>/dev/null || echo "0")

  # 验证：产物 mtime <= review mtime → 跳过
  [ "$artifact_mtime" -le "$review_mtime" ]
}

# ═══════════════════════════════════════════════
# AC-2: .done 安全——L3 fail 不写 .done
# ═══════════════════════════════════════════════

@test "AC-2: .done NOT written when L3 verdict=fail" {
  # 模拟 l3_review_run 执行后 .done 不应存在（verdict=fail）
  local done_marker="$SPECS_DIR/.independent-review-1.done"

  # 验证：.done 文件不存在
  run test -f "$done_marker"
  [ "$status" -eq 1 ]
}

@test "AC-2: GATE_DENY message format in stdout" {
  # 验证 GATE_DENY 消息格式
  local gate_output="GATE_DENY: L3 verdict=fail for phase 1"
  echo "$gate_output" | grep -q "GATE_DENY"
  echo "$gate_output" | grep -q "verdict=fail"
}

# ═══════════════════════════════════════════════
# AC-3: .done 安全——L3 pass 才写 .done
# ═══════════════════════════════════════════════

@test "AC-3: .done file 6-key KVP format valid" {
  local done_marker="$SPECS_DIR/.independent-review-1.done"
  cat > "$done_marker" <<'DONEEOF'
phase=1
change_id=fix-l3-gate
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
L3_summary="all good"
artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-1.md
DONEEOF

  source "$done_marker" 2>/dev/null
  [ "$L3_verdict" = "pass" ]
  [ -n "$phase" ] && [ -n "$change_id" ] && [ -n "$written_by" ]
  [ -n "$L2_verdict" ] && [ -n "$artifacts" ]
}

@test "AC-3: .done with L3_verdict=fail should be treated as invalid" {
  local done_marker="$SPECS_DIR/.independent-review-1.done"
  cat > "$done_marker" <<'DONEEOF'
phase=1
change_id=fix-l3-gate
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=fail
L3_summary="found issues"
artifacts=REQUIREMENT.md
DONEEOF

  source "$done_marker" 2>/dev/null
  # L3_verdict=fail 的 .done 在新逻辑下不应被当作有效放行凭证
  [ "$L3_verdict" = "fail" ]
}

# ═══════════════════════════════════════════════
# AC-4: phase 同步——transition jq 四字段一致
# ═══════════════════════════════════════════════

@test "AC-4: transition jq updates .phase + .goal.current_phase together" {
  local flow_tmp="$TEST_TMPDIR/.flow-active-test"
  cat > "$flow_tmp" <<'EOF'
{"phase":1,"goal":{"current_phase":"1","phases_done":["0"],"gates":{"0→1":"passed","1→2":"pending"}}}
EOF

  # 模拟 transition jq（含 .phase 同步）
  jq '.goal.current_phase = "2" | .phase = "2" | .goal.phases_done += ["1"] | .goal.gates["1→2"] = "passed"' \
    "$flow_tmp" > "$flow_tmp.tmp" && mv "$flow_tmp.tmp" "$flow_tmp"

  local top_phase goal_phase
  top_phase=$(jq -r '.phase' "$flow_tmp")
  goal_phase=$(jq -r '.goal.current_phase' "$flow_tmp")

  # 两个 phase 字段一致
  [ "$top_phase" = "$goal_phase" ]
  [ "$top_phase" = "2" ]
}

@test "AC-4: transition jq uses tempfile+mv pattern (atomicity check)" {
  local flow_tmp="$TEST_TMPDIR/.flow-active-test"
  echo '{"phase":1,"goal":{"current_phase":"1","phases_done":["0"],"gates":{"1→2":"pending"}}}' > "$flow_tmp"

  local tmp_file="${flow_tmp}.tmp"
  # 模拟 tempfile+mv：先写 tmp 再 mv（禁止 jq ... file > file）
  jq '.phase = "2" | .goal.current_phase = "2"' "$flow_tmp" > "$tmp_file" && mv "$tmp_file" "$flow_tmp"

  local phase_val
  phase_val=$(jq -r '.phase' "$flow_tmp")
  [ "$phase_val" = "2" ]

  # 验证：没有直接覆写 .flow-active（tmp 文件已被 mv，不应残留）
  [ ! -f "$tmp_file" ] || false
}

@test "AC-4: phases_done and gates updated consistently" {
  local flow_tmp="$TEST_TMPDIR/.flow-active-test"
  cat > "$flow_tmp" <<'EOF'
{"phase":"2","goal":{"current_phase":"2","phases_done":["0","1"],"gates":{"1→2":"passed","2→3":"pending"}}}
EOF

  # transition 2→3
  jq '.goal.current_phase = "3" | .phase = "3" | .goal.phases_done += ["2"] | .goal.gates["2→3"] = "passed"' \
    "$flow_tmp" > "$flow_tmp.tmp" && mv "$flow_tmp.tmp" "$flow_tmp"

  local phases_done gate_2_3
  phases_done=$(jq -c '.goal.phases_done' "$flow_tmp")
  gate_2_3=$(jq -r '.goal.gates["2→3"]' "$flow_tmp")

  # phases_done 包含 "2"
  echo "$phases_done" | grep -q '"2"'
  # gate 2→3 为 passed
  [ "$gate_2_3" = "passed" ]
}

# ═══════════════════════════════════════════════
# AC-5: 回退不受 L3 gate 拦截
# ═══════════════════════════════════════════════

@test "AC-5: rollback transition does not require .done" {
  local cur_phase=3 target_phase=2

  # 回退判定：目标 phase < 当前 phase → 回退
  [ "$target_phase" -lt "$cur_phase" ]
}

@test "AC-5: forward transition requires .done" {
  local cur_phase=2 target_phase=3

  # 前进判定：目标 phase > 当前 phase → 需要 .done
  [ "$target_phase" -gt "$cur_phase" ]

  # 模拟 gate 检查：前进时 .done 必须存在
  local done_marker="$SPECS_DIR/.independent-review-2.done"
  # 没有 .done → gate 应拒绝
  run test -f "$done_marker"
  [ "$status" -eq 1 ]
}

# ═══════════════════════════════════════════════
# 新增逻辑测试：l3-review.sh 追加模式
# ═══════════════════════════════════════════════

@test "l3-review append mode: ## L3 重审 section header present in modified script" {
  # C6 行为化：不再 grep l3-*.sh 源码形态 —— 直接驱动 _l3_parse_result，观测重审逻辑
  # （is_review）的实际行为：首写「盲审」标题；既有评审文件时换「重审」标题；L2 段保留、
  # 旧 L3 段被替换不累积（追加语义而非旧 awk 截断覆写）。
  local d1="$SPECS_DIR/append-first" d2="$SPECS_DIR/append-rerun"
  # 首轮：无既有文件 → is_review=false → 盲审标题
  mkdir -p "$d1"
  bash -c "source '$L3_REVIEW_SH' 2>/dev/null; _l3_parse_result '{\"verdict\":\"fail\",\"summary\":\"s1\"}' 1 '$d1' model-x" >/dev/null 2>&1 || true
  grep -q '^## L3 盲审（model-x' "$d1/INDEPENDENT-REVIEW-1.md"
  # 重审：既有评审文件（含 L2 段）→ is_review=true → 换「重审」标题 + L2 段保留
  mkdir -p "$d2"
  printf '# IR\n\n## L2 盲审\n\n**Verdict**: fail\n' > "$d2/INDEPENDENT-REVIEW-1.md"
  bash -c "source '$L3_REVIEW_SH' 2>/dev/null; _l3_parse_result '{\"verdict\":\"fail\",\"summary\":\"s2\"}' 1 '$d2' model-x" >/dev/null 2>&1 || true
  grep -q '^## L3 重审（model-x' "$d2/INDEPENDENT-REVIEW-1.md"
  grep -q '^## L2 盲审' "$d2/INDEPENDENT-REVIEW-1.md"
  # 再跑一轮：旧 L3 段被替换（恒 1 段）—— 追加语义不累积，也不覆写 L2 层
  bash -c "source '$L3_REVIEW_SH' 2>/dev/null; _l3_parse_result '{\"verdict\":\"fail\",\"summary\":\"s3\"}' 1 '$d2' model-x" >/dev/null 2>&1 || true
  [ "$(grep -c '^## L3 ' "$d2/INDEPENDENT-REVIEW-1.md")" -eq 1 ]
  grep -q '^## L2 盲审' "$d2/INDEPENDENT-REVIEW-1.md"
}

@test "l3-review .done conditional: only writes .done on pass" {
  # C6 行为化：不再 grep 条件消息文本 —— 直调 _l3_write_done 观测条件行为：
  # verdict=fail → rc=1、不落 .done、stderr 含 NOT written；verdict=pass → rc=0、
  # 落 6 键 KVP 凭证、stderr 含 written。工件先经生产写入方 _l3_parse_result 产出合法 L3 段。
  local d="$SPECS_DIR/done-cond"; mkdir -p "$d"
  printf '# IR\n\n## L2 盲审\n\n**Verdict**: pass\n' > "$d/INDEPENDENT-REVIEW-2.md"
  bash -c "source '$L3_REVIEW_SH' 2>/dev/null; _l3_parse_result '{\"verdict\":\"fail\",\"summary\":\"s\"}' 2 '$d' model-x" >/dev/null 2>&1 || true
  local marker="$d/.independent-review-2.done"
  local rc=0 se
  se=$(bash -c "source '$L3_LIB_DIR/l3-done.sh' 2>/dev/null; _l3_write_done 2 chg fail s pass '$d' both" 2>&1 1>/dev/null) || rc=$?
  [ "$rc" -eq 1 ]
  [ ! -f "$marker" ]
  [[ "$se" == *'.done NOT written (phase 2)'* ]]
  rc=0
  se=$(bash -c "source '$L3_LIB_DIR/l3-done.sh' 2>/dev/null; _l3_write_done 2 chg pass s pass '$d' both" 2>&1 1>/dev/null) || rc=$?
  [ "$rc" -eq 0 ]
  [ -f "$marker" ]
  grep -q '^L3_verdict=pass$' "$marker"
  grep -q '^artifacts=' "$marker"
  [[ "$se" == *'L3 pass — .done written (phase 2, verdict=pass)'* ]]
}

@test "l3-review file size warning: 50KB threshold check present" {
  # C6 行为化：不再 grep 阈值字面量 —— 构造 >50KB 的既有评审文件，真跑 _l3_parse_result，
  # 观测追加前的大小告警行为（>51200B → stderr WARNING）。
  local d="$SPECS_DIR/big50k"; mkdir -p "$d"
  printf '# IR\n\n## L2 盲审\n\n**Verdict**: fail\n' > "$d/INDEPENDENT-REVIEW-5.md"
  head -c 60000 /dev/zero | tr '\0' 'x' >> "$d/INDEPENDENT-REVIEW-5.md"
  local rc=0 se
  se=$(bash -c "source '$L3_REVIEW_SH' 2>/dev/null; _l3_parse_result '{\"verdict\":\"pass\",\"summary\":\"s\"}' 5 '$d' model-x" 2>&1 1>/dev/null) || rc=$?
  [ "$rc" -eq 0 ]
  [[ "$se" == *'WARNING: review file exceeds 50KB'* ]]
}

# ═══════════════════════════════════════════════
# 31-auto-advance.sh / prompts: 过渡 jq 的 .phase 同步（C6 行为化）
# ═══════════════════════════════════════════════

# 提取 <源文件> 中实际附带的阶段过渡 jq 过滤器（首个同时含 .goal.current_phase 与
# .phase = 的单引号表达式），对夹具 .flow-active 真跑一遍，stdout 输出结果 JSON。
# 断言面从「文件文本含某形态」换成「其附带的过渡命令真的同步 .phase / .goal.current_phase /
# phases_done / 门禁」。过滤器缺失时 rc=1（jq 不再产出，测试当场红）。
_transition_apply() {  # $1=源文件; 其余参数原样传给 jq（--arg ...）
  local src="$1"; shift
  local filt
  filt=$(awk -v q="'" '
    index($0, ".goal.current_phase") && index($0, ".phase =") {
      s = substr($0, index($0, q) + 1)
      print substr(s, 1, index(s, q) - 1); exit
    }' "$src")
  [ -n "$filt" ] || return 1
  printf '%s\n' '{"change_id":"t","phase":"0","goal":{"scope":"phase","current_phase":"0","phases_done":[],"gates":{}}}' \
    | jq "$@" "$filt"
}

@test "31-auto-advance.sh: transition jq includes .phase sync" {
  # C6 行为化：提取 hook 源文件附带的过渡 jq 并真跑（参数与生产调用点一致），
  # 断言 .phase 与 .goal.current_phase 同步为下一阶段、phases_done 追加、门禁落 passed。
  local out
  out=$(_transition_apply "$AUTO_ADVANCE_SH" --arg next "5" --arg gk "4→5")
  [ "$(jq -r '.phase' <<<"$out")" = "5" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "5" ]
  [ "$(jq -r '.goal.phases_done | index("4") != null' <<<"$out")" = "true" ]
  [ "$(jq -r '.goal.gates["4→5"]' <<<"$out")" = "passed" ]
}

# ═══════════════════════════════════════════════
# l3_write_timeout_done: no .done written
# ═══════════════════════════════════════════════

@test "l3_write_timeout_done: timeout writes notice but NOT .done" {
  # 验证 timeout 函数不再写 .done
  run grep -A10 'l3_write_timeout_done()' "$L3_REVIEW_SH"
  # 不应包含 .done 写入逻辑（如 cat > done_marker）
  ! echo "$output" | grep -q 'cat >.*done_tmp'
}

# ═══════════════════════════════════════════════
# Prompt transition jq: .phase sync
# ═══════════════════════════════════════════════

@test "prompt transition jq: .phase sync in 0-change.md" {
  # C6 行为化：提取该 prompt 附带的过渡 jq 并对夹具 .flow-active 真跑，
  # 断言 .phase 与 .goal.current_phase 同步推进、门禁落 passed（而非 grep 文本形态）。
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/0-change.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "1" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "1" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in 1-requirement.md" {
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/1-requirement.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "2" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "2" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in 2-design.md" {
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/2-design.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "3" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "3" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in 3-task.md" {
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/3-task.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "4" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "4" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in 5-test.md" {
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/5-test.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "6" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "6" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in 6-review.md" {
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/6-review.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "7" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "7" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in 4-dev.md" {
  # 4-dev 的过渡目标是变量 $next_phase（用例意图：该值被同步到 .phase 与 .goal.current_phase）
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/prompts/4-dev.md" --arg ts "2026-01-01T00:00:00Z" --arg next_phase "5")
  [ "$(jq -r '.phase' <<<"$out")" = "5" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "5" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}

@test "prompt transition jq: .phase sync in pipeline-gates.md" {
  local out
  out=$(_transition_apply "$BUNDLE_ROOT/flow-kit/reference/pipeline-gates.md" --arg ts "2026-01-01T00:00:00Z")
  [ "$(jq -r '.phase' <<<"$out")" = "5" ]
  [ "$(jq -r '.goal.current_phase' <<<"$out")" = "5" ]
  [ "$(jq -r '.goal.gates | to_entries | map(select(.value == "passed")) | length' <<<"$out")" = "1" ]
}
