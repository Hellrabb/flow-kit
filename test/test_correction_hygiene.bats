#!/usr/bin/env bats
# test_correction_hygiene.bats — correction-hygiene-state-guard (ADR-024) 卫生机制测试
#
# 覆盖 AC-1/2/3/4/5/6/7/9/10 + R1（D8 写入保护），全部驱动真实实现：
#   - 33-flow-active-integrity.sh（_fai_append_violation / _fai_clear_whitelist /
#     _fai_append_foreign_note / 健康清零 / 外来让位）
#   - 29-independent-review.sh（M0 l2-missing 退场 + _write_l2_missing_correction）
#   - lib/correction-file.sh（dedupe / trim / strip_type）
# 被测单元无 mock；fixture 全部 mktemp 隔离 + teardown 清理。

setup() {
  # 位置无关：向上查找含 flow-kit-bundle/hooks/stop 的目录
  # （双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确 · L-025 同源路径问题根治）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks/stop" ]; do
    d="$(dirname "$d")"
  done
  HOOK_BASE_DIR="$d/flow-kit-bundle/hooks/stop"

  FIXTURE=$(mktemp -d)
  mkdir -p "$FIXTURE/.specs" "$FIXTURE/.claude" "$FIXTURE/hook-tmp"
  FLOW_ACTIVE="$FIXTURE/.flow-active"
  CORRECTION="$FIXTURE/.flow-active.correction"
  SPECS_DIR="$FIXTURE/.specs"

  # 默认：合法 flow-kit JSON，全部检查通过（change_id null + 空 .specs +
  # updated_at 0 + token_spent 1 → _FAI_APPENDED=0 → 健康清零路径）
  cat > "$FLOW_ACTIVE" <<'EOF'
{
  "change_id": null,
  "phase": "1",
  "goal": {"scope": "phase"},
  "updated_at": 0,
  "token_spent": 1
}
EOF

  # 29 号运行所需 config（independent_review 模块开启）
  cat > "$FIXTURE/.claude/stop-hook.json" <<'EOF'
{"modules": {"independent_review": {"enabled": true}}}
EOF
}

teardown() {
  rm -rf "$FIXTURE"
}

# ── helpers ──────────────────────────────────────────────────────────
# 跑 33 号主入口（真实脚本子进程，实参 = fixture 绝对路径；cd 进 fixture
# 使脚本内相对默认路径解析到 fixture 而非仓库根）
run_33() {
  run bash -c "cd '$FIXTURE' && HOOK_BASE_DIR='$HOOK_BASE_DIR' bash '$HOOK_BASE_DIR/33-flow-active-integrity.sh' '$FLOW_ACTIVE' '$SPECS_DIR' '$CORRECTION' ''"
}

# 跑 29 号主入口（M0 退场路径 fixture：phase 1 + change_id + gate_config L2）
run_29() {
  run bash -c "HOOK_BASE_DIR='$HOOK_BASE_DIR' PROJECT_ROOT='$FIXTURE' FLOW_KIT_PROJECT_DIR='$FIXTURE' CONFIG_FILE='$FIXTURE/.claude/stop-hook.json' HOOK_TMP_DIR='$FIXTURE/hook-tmp' bash '$HOOK_BASE_DIR/29-independent-review.sh'"
}

# ── AC-1 · 去重（同 check+field 收敛为最新一条）──────────────────────
@test "AC-1: 同 check+field 连写 3 条 → violations 仅剩最新 1 条" {
  run bash -c "
    cd '$FIXTURE'
    export HOOK_BASE_DIR='$HOOK_BASE_DIR'
    source '$HOOK_BASE_DIR/33-flow-active-integrity.sh'
    _fai_append_violation '$CORRECTION' 'corrupt_json' 'first' '.flow-active'
    _fai_append_violation '$CORRECTION' 'corrupt_json' 'second' '.flow-active'
    _fai_append_violation '$CORRECTION' 'corrupt_json' 'third' '.flow-active'
    echo COUNT=\$(jq -r '[.violations[] | select(.check == \"corrupt_json\")] | length' '$CORRECTION')
    echo MSG=\$(jq -r '.violations[0].message' '$CORRECTION')
    echo TYPE=\$(jq -r '.type' '$CORRECTION')
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"COUNT=1"* ]]
  [[ "$output" == *"MSG=third"* ]]
  [[ "$output" == *"TYPE=state-integrity"* ]]
}

# ── AC-2 · 容量上限（>10 FIFO · compliance 不占配额）─────────────────
@test "AC-2: 白名单 12 条不同 field → 10 条 FIFO（最旧 2 淘汰）+ compliance 保留不占配额" {
  run bash -c "
    cd '$FIXTURE'
    export HOOK_BASE_DIR='$HOOK_BASE_DIR'
    source '$HOOK_BASE_DIR/33-flow-active-integrity.sh'
    for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
      _fai_append_violation '$CORRECTION' 'corrupt_json' \"msg-\$i\" \"field_\$i\"
    done
    _fai_append_violation '$CORRECTION' 'R1' 'compliance-A' '.compliance'
    _fai_append_violation '$CORRECTION' 'R2' 'compliance-B' '.compliance'
    echo WL=\$(jq -r '[.violations[] | select(.check == \"corrupt_json\")] | length' '$CORRECTION')
    echo FIRST=\$(jq -r '.violations[] | select(.check == \"corrupt_json\") | .field' '$CORRECTION' | head -1)
    echo LAST=\$(jq -r '.violations[] | select(.check == \"corrupt_json\") | .field' '$CORRECTION' | tail -1)
    echo COMP=\$(jq -r '[.violations[] | select(.check == \"R1\" or .check == \"R2\")] | length' '$CORRECTION')
    echo TOTAL=\$(jq -r '.violations | length' '$CORRECTION')
  "
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WL=10"* ]]          # 12 → 10（FIFO 上限）
  [[ "$output" == *"FIRST=field_03"* ]] # 最旧 2 条（field_01/02）被淘汰
  [[ "$output" == *"LAST=field_12"* ]]  # 最新保留
  [[ "$output" == *"COMP=2"* ]]         # compliance 不参与去重/淘汰
  [[ "$output" == *"TOTAL=12"* ]]       # 10 白名单 + 2 compliance（不占配额）
}

# ── AC-3 · 健康清零（state-integrity 类清空）─────────────────────────
@test "AC-3: 健康清零 — 全检查通过 → 白名单清空 + l2-missing/compliance 保留 + 审计行" {
  # 预置 correction：合并标签（l2-missing 语义）+ 3 白名单 + 1 compliance
  jq -n '
    {type: "l2-missing+state-integrity",
     violations: [
       {check: "corrupt_json", message: "old-1", field: ".flow-active"},
       {check: "phase_artifact_missing", message: "old-2", field: ".flow-active.phase"},
       {check: "stale_updated_at", message: "old-3", field: ".flow-active.updated_at"},
       {check: "R1", message: "compliance-keep", field: ".compliance"}
     ],
     written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"

  run_33
  CLEAR_OUTPUT="$output"
  [[ "$status" -eq 0 ]]

  # 白名单类全部清空（corrupt_json / phase_artifact_missing / stale_updated_at）
  run jq -r '[.violations[] | select(.check == "corrupt_json" or .check == "phase_artifact_missing" or .check == "stale_updated_at")] | length' "$CORRECTION"
  [[ "$output" == "0" ]]
  # compliance 保留
  run jq -r '.violations[] | select(.check == "R1") | .message' "$CORRECTION"
  [[ "$output" == "compliance-keep" ]]
  # l2-missing 语义（type 合并标签）保留
  run jq -r '.type' "$CORRECTION"
  [[ "$output" == "l2-missing+state-integrity" ]]
  # 审计 stderr："state-integrity cleared N items"（N=3）
  [[ "$CLEAR_OUTPUT" == *"state-integrity cleared 3 items"* ]]
}

# ── AC-4 · l2-missing 退场（29 号 M0 · 双态）────────────────────────
@test "AC-4a: 退场纯 type l2-missing → 整文件 rm + 审计（gate_config=L2 无 IR → R2 插入点证明）" {
  # gate_config=L2（非 both）+ 无 IR 文件 → 退场仍触发 = M0 块在 Gate 3 之前执行
  cat > "$FLOW_ACTIVE" <<'EOF'
{"change_id": "ac4-change", "phase": "1", "goal": {"gate_config": {"1-requirement": "L2"}}}
EOF
  mkdir -p "$SPECS_DIR/ac4-change"
  jq -n '{type: "l2-missing", phase: "1", change_id: "ac4-change", violations: [{"check": "corrupt_json", "message": "stale", "field": ".flow-active"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"

  run_29
  [[ "$status" -eq 0 ]]
  [[ ! -f "$CORRECTION" ]]                                      # rm 分支
  [[ "$output" == *"[29-l2-retire] clearing l2-missing (was: l2-missing)"* ]]
}

@test "AC-4b: 退场合并标签 l2-missing+state-integrity → type 剥离为 state-integrity + violations 保留" {
  cat > "$FLOW_ACTIVE" <<'EOF'
{"change_id": "ac4-change", "phase": "1", "goal": {"gate_config": {"1-requirement": "L2"}}}
EOF
  mkdir -p "$SPECS_DIR/ac4-change"
  jq -n '{type: "l2-missing+state-integrity", violations: [{"check": "corrupt_json", "message": "v1", "field": ".flow-active"}, {"check": "R1", "message": "keep-me", "field": ".compliance"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"
  local before
  before=$(jq -c '.violations' "$CORRECTION")

  run_29
  RETIRE_OUTPUT="$output"
  [[ "$status" -eq 0 ]]
  [[ -f "$CORRECTION" ]]                                        # 非 rm 分支
  run jq -r '.type' "$CORRECTION"
  [[ "$output" == "state-integrity" ]]                          # 剥离 l2-missing 段
  run jq -c '.violations' "$CORRECTION"
  [[ "$output" == "$before" ]]                                  # violations 原样保留
  [[ "$RETIRE_OUTPUT" == *"[29-l2-retire] clearing l2-missing (was: l2-missing+state-integrity)"* ]]
}

# ── AC-5/6 · 外来状态让位 + 清空陈旧 state-integrity ────────────────
@test "AC-5/6: 外来 YAML → 无 corrupt_json 追加 + 白名单清空 + 恰 1 条 foreign_state（再跑不重复）+ type 剥离为 l2-missing + compliance 保留" {
  # 外来 .flow-active（YAML 文本）
  cat > "$FLOW_ACTIVE" <<'EOF'
change_id: "chisel-foreign"
phase: "4"
EOF
  # 陈旧 state-integrity + 合并标签 + compliance
  jq -n '{type: "l2-missing+state-integrity", violations: [{"check": "corrupt_json", "message": "old-1", "field": ".flow-active"}, {"check": "phase_artifact_missing", "message": "old-2", "field": ".flow-active.phase"}, {"check": "R1", "message": "compliance-keep", "field": ".compliance"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"

  run_33
  FOREIGN_OUTPUT="$output"
  [[ "$status" -eq 0 ]]

  # 无 corrupt_json（陈旧清空 + 不再追加）
  run jq -r '[.violations[] | select(.check == "corrupt_json")] | length' "$CORRECTION"
  [[ "$output" == "0" ]]
  # type 合并标签剥离 state-integrity 段 → l2-missing
  run jq -r '.type' "$CORRECTION"
  [[ "$output" == "l2-missing" ]]
  # 恰 1 条 foreign_state note
  run jq -r '[.violations[] | select(.check == "foreign_state")] | length' "$CORRECTION"
  [[ "$output" == "1" ]]
  # compliance 保留
  run jq -r '.violations[] | select(.check == "R1") | .message' "$CORRECTION"
  [[ "$output" == "compliance-keep" ]]
  # stop-hook-report 提示一次（stderr）
  [[ "$FOREIGN_OUTPUT" == *"外来"* ]]

  # 再跑一次 → foreign_state 仍恰 1 条（AC-5 幂等 · D6 去重键=check）
  run_33
  [[ "$status" -eq 0 ]]
  run jq -r '[.violations[] | select(.check == "foreign_state")] | length' "$CORRECTION"
  [[ "$output" == "1" ]]
}

# ── AC-9 · chisel_env 场景模拟收敛 ─────────────────────────────────
@test "AC-9: chisel_env 场景 — 50 条陈旧（43 corrupt_json + 6 artifact_missing）单轮收敛" {
  cat > "$FLOW_ACTIVE" <<'EOF'
phase: "dev"
tool: "chisel-skill"
EOF
  # 构造 50 条：43 corrupt_json + 6 phase_artifact_missing（field 全互异）+ 1 compliance
  jq -nc '
    def wl(n): [range(0; n) as $i | {check: (if $i < 43 then "corrupt_json" else "phase_artifact_missing" end), message: ("stale-" + ($i|tostring)), field: ("f" + ($i|tostring))}];
    {type: "l2-missing+state-integrity", violations: (wl(49) + [{check: "R1", message: "compliance-keep", field: ".compliance"}]), written_at: "2026-08-31T00:00:00+08:00"}
  ' > "$CORRECTION"
  [[ "$(jq -r '.violations | length' "$CORRECTION")" == "50" ]]

  run_33
  [[ "$status" -eq 0 ]]

  # 首轮收敛：state-integrity 全清（43+6 消失）→ 仅 1 foreign_state + 1 compliance
  run jq -r '.violations | length' "$CORRECTION"
  [[ "$output" == "2" ]]
  run jq -r '[.violations[] | select(.check == "foreign_state")] | length' "$CORRECTION"
  [[ "$output" == "1" ]]
  run jq -r '.type' "$CORRECTION"
  [[ "$output" == "l2-missing" ]]
  run jq -r '.violations[] | select(.check == "R1") | .message' "$CORRECTION"
  [[ "$output" == "compliance-keep" ]]

  # 后续 Stop 零新增（数组长度不变）
  run_33
  [[ "$status" -eq 0 ]]
  run jq -r '.violations | length' "$CORRECTION"
  [[ "$output" == "2" ]]
}

# ── AC-7 · 绝不转换/覆盖/删除外来文件 ───────────────────────────────
@test "AC-7: 外来 .flow-active（YAML）跑 33 号前后 sha256 + mtime 逐字节一致" {
  cat > "$FLOW_ACTIVE" <<'EOF'
change_id: "chisel-foreign"
phase: "4"
EOF
  local before_sha before_mtime
  before_sha=$(sha256sum "$FLOW_ACTIVE" | cut -d' ' -f1)
  before_mtime=$(stat -c %Y "$FLOW_ACTIVE")

  run_33
  [[ "$status" -eq 0 ]]

  local after_sha after_mtime
  after_sha=$(sha256sum "$FLOW_ACTIVE" | cut -d' ' -f1)
  after_mtime=$(stat -c %Y "$FLOW_ACTIVE")

  [[ "$after_sha" == "$before_sha" ]]
  [[ "$after_mtime" == "$before_mtime" ]]
}

# ── AC-10 · compliance 条目不受本 change 影响（逐字节不变）──────────
@test "AC-10: compliance 条目在清零/外来/退场路径后逐字节不变（jq -c 比较）" {
  # ── 路径 1: 健康清零（33 主路径）──
  cat > "$FLOW_ACTIVE" <<'EOF'
{"change_id": null, "phase": "1", "goal": {"scope": "phase"}, "updated_at": 0, "token_spent": 1}
EOF
  jq -n '{type: "l2-missing+state-integrity", violations: [{"check": "corrupt_json", "message": "old", "field": ".flow-active"}, {"check": "R1", "message": "compliance-keep", "field": ".compliance"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"
  local c1_before c1_after
  c1_before=$(jq -c '.violations[] | select(.check == "R1")' "$CORRECTION")
  run_33
  [[ "$status" -eq 0 ]]
  c1_after=$(jq -c '.violations[] | select(.check == "R1")' "$CORRECTION")
  [[ "$c1_after" == "$c1_before" ]]

  # ── 路径 2: 外来让位（33 外来分支）──
  cat > "$FLOW_ACTIVE" <<'EOF'
change_id: "foreign-yaml"
phase: "4"
EOF
  jq -n '{type: "l2-missing+state-integrity", violations: [{"check": "corrupt_json", "message": "old", "field": ".flow-active"}, {"check": "R1", "message": "compliance-keep", "field": ".compliance"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"
  local c2_before c2_after
  c2_before=$(jq -c '.violations[] | select(.check == "R1")' "$CORRECTION")
  run_33
  [[ "$status" -eq 0 ]]
  c2_after=$(jq -c '.violations[] | select(.check == "R1")' "$CORRECTION")
  [[ "$c2_after" == "$c2_before" ]]

  # ── 路径 3: l2-missing 退场（29 合并标签剥离）──
  cat > "$FLOW_ACTIVE" <<'EOF'
{"change_id": "ac4-change", "phase": "1", "goal": {"gate_config": {"1-requirement": "L2"}}}
EOF
  mkdir -p "$SPECS_DIR/ac4-change"
  jq -n '{type: "l2-missing+state-integrity", violations: [{"check": "corrupt_json", "message": "old", "field": ".flow-active"}, {"check": "R1", "message": "compliance-keep", "field": ".compliance"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"
  local c3_before c3_after
  c3_before=$(jq -c '.violations[] | select(.check == "R1")' "$CORRECTION")
  run_29
  [[ "$status" -eq 0 ]]
  c3_after=$(jq -c '.violations[] | select(.check == "R1")' "$CORRECTION")
  [[ "$c3_after" == "$c3_before" ]]
}

# ── R1 · compliance-priority 写入保护（D8 · AC-4 And）──────────────
@test "R1: 写入保护 — _write_l2_missing_correction 不覆写既有 compliance 条目" {
  jq -n '{type: "compliance", violations: [{"rule": "R1", "message": "keep-me"}], written_at: "2026-08-31T00:00:00+08:00"}' > "$CORRECTION"
  local before
  before=$(jq -c '.' "$CORRECTION")

  # 从 29 号脚本提取 _write_l2_missing_correction 真实定义（sed 抽取）+ 依赖 lib
  sed -n '/^_write_l2_missing_correction()/,/^}/p' "$HOOK_BASE_DIR/29-independent-review.sh" > "$FIXTURE/l2-missing-fn.sh"
  run bash -c "
    export PROJECT_ROOT='$FIXTURE'
    source '$HOOK_BASE_DIR/lib/correction-file.sh'
    source '$FIXTURE/l2-missing-fn.sh'
    _write_l2_missing_correction '1' 'some-change'
  "
  [[ "$status" -eq 0 ]]
  # 文件未被覆写：type 仍 compliance + 内容 jq -c 归一逐字节不变
  local after
  after=$(jq -c '.' "$CORRECTION")
  [[ "$after" == "$before" ]]
  run jq -r '.type' "$CORRECTION"
  [[ "$output" == "compliance" ]]
}
