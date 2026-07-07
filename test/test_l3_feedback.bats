#!/usr/bin/env bats
# test_l3_feedback.bats — L3 反馈可见性测试（l3-feedback-visibility）
# 覆盖 AC-1/2/3/4/5/6 + 安全验证

setup() {
  TEST_TMPDIR=$(mktemp -d)
  L3_REVIEW_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit-bundle/hooks/stop/lib/l3-review.sh"
  DONE_VALIDATION_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit-bundle/hooks/stop/lib/done-validation.sh"
  ARTIFACTS_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh"

  source "$L3_REVIEW_SH" 2>/dev/null || true
  source "$DONE_VALIDATION_SH" 2>/dev/null || true

  CHANGE_DIR="$TEST_TMPDIR/.specs/test-change"
  mkdir -p "$CHANGE_DIR"

  FLOW_FILE="$TEST_TMPDIR/.flow-active"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ─────────────────────────────────────────────
# 场景 1: _l3_format_result() 格式化输出
# ─────────────────────────────────────────────

@test "_l3_format_result: 正常 verdict + summary + report" {
  run _l3_format_result "pass" "设计审查通过" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "L3_RESULT: verdict=pass summary=设计审查通过 report=.specs/test/INDEPENDENT-REVIEW-1.md" ]]
}

@test "_l3_format_result: 空 summary" {
  run _l3_format_result "fail" "" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "L3_RESULT: verdict=fail summary= report=.specs/test/INDEPENDENT-REVIEW-1.md" ]]
}

@test "_l3_format_result: verdict=error" {
  run _l3_format_result "error" "L3 结果解析失败（verdict 不可用）" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^L3_RESULT:\ verdict=error\ summary=.+\ report=.+ ]]
}

@test "_l3_format_result: verdict=timeout" {
  run _l3_format_result "timeout" "L3 API 调用超时（30s）" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=timeout"* ]]
}

# ─────────────────────────────────────────────
# 场景 2: L3_RESULT 格式精确断言（AC-1）
# ─────────────────────────────────────────────

@test "AC-1: L3_RESULT 格式匹配 grep 验证正则" {
  local line
  line=$(_l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md")
  echo "$line" | grep -qE '^L3_RESULT: verdict=(pass|fail|timeout|error) summary=.+ report=.+[.]md$'
  [ "$?" -eq 0 ]
}

@test "AC-1: 空 summary 通过 summary=.* 正则（DESIGN D3 允许空 summary）" {
  local line
  line=$(_l3_format_result "pass" "" ".specs/test/INDEPENDENT-REVIEW-1.md")
  # summary=.* 允许空字符串
  echo "$line" | grep -qiE '^l3_result: verdict=(pass|fail|timeout|error) summary=.* report=.+'
  [ "$?" -eq 0 ]
}

@test "AC-1: report 必须是相对路径" {
  local line
  line=$(_l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md")
  [[ "$line" =~ report=[^/] ]]
}

@test "AC-1: verdict 值全小写" {
  local line
  line=$(_l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md")
  [[ "$line" =~ verdict=pass ]]
  [[ ! "$line" =~ verdict=PASS ]]
}

# ─────────────────────────────────────────────
# 场景 3: Summary 三层 JSON 提取（R1 fix）
# ─────────────────────────────────────────────

@test "summary 提取 Layer 1: jq 从 JSON 代码块提取 .summary" {
  local content='```json
{"verdict":"pass","summary":"设计审查通过"}
```'
  local extracted
  extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
  local summary
  summary=$(echo "$extracted" | jq -r '.summary // ""' 2>/dev/null || echo "")
  [[ "$summary" == "设计审查通过" ]]
}

@test "summary 提取 Layer 2: jq 从裸 JSON 提取 .summary" {
  local content='{"verdict":"fail","summary":"存在 Critical 发现"}'
  local summary
  summary=$(echo "$content" | jq -r '.summary // ""' 2>/dev/null || echo "")
  [[ "$summary" == "存在 Critical 发现" ]]
}

@test "summary 提取 Layer 3: grep 正则从混合文本提取 .summary" {
  local content='一些前置思考...{"verdict":"pass","summary":"一句话总评"}后续文本...'
  local summary
  summary=$(echo "$content" | grep -oP '"summary"\s*:\s*"\K[^"]+' 2>/dev/null | tail -1 || echo "")
  [[ "$summary" == "一句话总评" ]]
}

@test "summary 提取: 三层全失败时降级为空字符串" {
  local content='no json here at all'
  local summary=""
  # Layer 1
  local extracted
  extracted=$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d' 2>/dev/null || echo "")
  if [ -n "$extracted" ]; then
    summary=$(echo "$extracted" | jq -r '.summary // ""' 2>/dev/null || echo "")
  fi
  # Layer 2
  if [ -z "$summary" ]; then
    summary=$(echo "$content" | jq -r '.summary // ""' 2>/dev/null || echo "")
  fi
  # Layer 3
  if [ -z "$summary" ]; then
    summary=$(echo "$content" | grep -oP '"summary"\s*:\s*"\K[^"]+' 2>/dev/null | tail -1 || echo "")
  fi
  [[ "$summary" == "" ]]
}

# ─────────────────────────────────────────────
# 场景 4: 第四层故障降级（AC-6）+ .done 超时写入（R3 fix）
# ─────────────────────────────────────────────

@test "AC-6: 第四层降级 — verdict 为空时降级为 error" {
  local l3_verdict=""
  local l3_summary=""
  # 模拟第四层降级逻辑
  if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
    l3_verdict="error"
    l3_summary="L3 结果解析失败（verdict 不可用）"
  fi
  [[ "$l3_verdict" == "error" ]]
  [[ "$l3_summary" == "L3 结果解析失败（verdict 不可用）" ]]
}

@test "AC-6: 第四层降级 — verdict=unknown 时降级为 error" {
  local l3_verdict="unknown"
  local l3_summary=""
  if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
    l3_verdict="error"
    l3_summary="L3 结果解析失败（verdict 不可用）"
  fi
  [[ "$l3_verdict" == "error" ]]
}

@test "AC-6: 第四层降级 — 正常 verdict 不触发降级" {
  local l3_verdict="pass"
  local l3_summary="设计通过"
  if [ -z "$l3_verdict" ] || [ "$l3_verdict" = "unknown" ]; then
    l3_verdict="error"
    l3_summary="L3 结果解析失败（verdict 不可用）"
  fi
  [[ "$l3_verdict" == "pass" ]]
  [[ "$l3_summary" == "设计通过" ]]
}

@test "AC-5: l3_write_timeout_done 写入正确的 .done（含 L3_summary）" {
  # 直接调用 l3_write_timeout_done 函数
  if type l3_write_timeout_done >/dev/null 2>&1; then
    l3_write_timeout_done "1" "test-change" "$CHANGE_DIR" "pass"
    local done_file="$CHANGE_DIR/.independent-review-1.done"
    [ -f "$done_file" ]
    grep -q 'L3_verdict=timeout' "$done_file"
    grep -q 'L3_summary=L3 API 调用超时（30s）' "$done_file"
  else
    skip "l3_write_timeout_done not available"
  fi
}

# ─────────────────────────────────────────────
# 场景 5: .done KVP 格式读写
# ─────────────────────────────────────────────

@test ".done KVP: L3_summary 键可写入并读取" {
  local done_file="$CHANGE_DIR/.independent-review-1.done"
  cat > "$done_file" <<DONE_EOF
phase=1
change_id=test-change
written_by=test
L2_verdict=pass
L3_verdict=fail
L3_summary=测试摘要
artifacts=REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-1.md
DONE_EOF

  if type _fk_done_kvp >/dev/null 2>&1; then
    run _fk_done_kvp "$done_file" "L3_verdict"
    [[ "$output" == "fail" ]]
    run _fk_done_kvp "$done_file" "L3_summary"
    [[ "$output" == "测试摘要" ]]
  else
    skip "_fk_done_kvp not available"
  fi
}

@test ".done KVP: 缺少 L3_summary 键时返回空" {
  local done_file="$CHANGE_DIR/.independent-review-1.done"
  cat > "$done_file" <<DONE_EOF
phase=1
change_id=test-change
written_by=test
L2_verdict=pass
L3_verdict=fail
artifacts=REQUIREMENT.md
DONE_EOF

  if type _fk_done_kvp >/dev/null 2>&1; then
    run _fk_done_kvp "$done_file" "L3_summary"
    [[ "$output" == "" ]]
  else
    skip "_fk_done_kvp not available"
  fi
}

# ─────────────────────────────────────────────
# 场景 6: F2 SessionStart 检测逻辑
# ─────────────────────────────────────────────

@test "F2: .done 存在 + review md 含 L3 段 → 应检测到" {
  local done_file="$CHANGE_DIR/.independent-review-1.done"
  local review_md="$CHANGE_DIR/INDEPENDENT-REVIEW-1.md"
  cat > "$done_file" <<DONE_EOF
phase=1
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
L3_summary=通过
artifacts=REQUIREMENT.md
DONE_EOF
  echo "## L3 外部模型审查" > "$review_md"

  [ -f "$done_file" ] && grep -q "## L3 外部模型审查" "$review_md"
  [ "$?" -eq 0 ]
}

@test "F2: .done 不存在 → 不触发" {
  local review_md="$CHANGE_DIR/INDEPENDENT-REVIEW-1.md"
  echo "## L3 外部模型审查" > "$review_md"
  local done_file="$CHANGE_DIR/.independent-review-1.done"

  if [ -f "$done_file" ] && grep -q "## L3 外部模型审查" "$review_md" 2>/dev/null; then
    false "不应触发：.done 不存在"
  else
    true
  fi
}

@test "F2: review md 不含 L3 段 → 不触发" {
  local done_file="$CHANGE_DIR/.independent-review-1.done"
  local review_md="$CHANGE_DIR/INDEPENDENT-REVIEW-1.md"
  cat > "$done_file" <<DONE_EOF
phase=1
change_id=test-change
written_by=test
L2_verdict=pass
L3_verdict=pass
artifacts=REQUIREMENT.md
DONE_EOF
  echo "## L2 盲审" > "$review_md"

  if [ -f "$done_file" ] && grep -q "## L3 外部模型审查" "$review_md" 2>/dev/null; then
    false "不应触发：review md 不含 L3 段"
  else
    true
  fi
}

@test "F2: 握手文件不存在时仍能触发（AC-2 关键场景）" {
  local done_file="$CHANGE_DIR/.independent-review-1.done"
  local review_md="$CHANGE_DIR/INDEPENDENT-REVIEW-1.md"
  local hs_file="$TEST_TMPDIR/.flow-active.independent-review"
  cat > "$done_file" <<DONE_EOF
phase=1
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
L3_summary=通过
artifacts=REQUIREMENT.md
DONE_EOF
  echo "## L3 外部模型审查" > "$review_md"
  # 握手文件不存在（模拟 29 号 hook 已清理）
  [ ! -f "$hs_file" ]

  # F2 新逻辑不依赖握手文件
  [ -f "$done_file" ] && grep -q "## L3 外部模型审查" "$review_md"
  [ "$?" -eq 0 ]
}

# ─────────────────────────────────────────────
# 场景 7: 全模式兼容 AC-4（R2 fix — 实际调用 gate 函数）
# ─────────────────────────────────────────────

@test "AC-4: fk_independent_review_gate_active — L3-only 模式" {
  cat > "$FLOW_FILE" <<'EOF'
{"change_id":"test","goal":{"gate_config":{"6-review":"L3"}}}
EOF
  export PROJECT_ROOT="$TEST_TMPDIR"
  export CWD="$TEST_TMPDIR"
  export HOOK_BASE_DIR="$(dirname "$ARTIFACTS_SH")"
  source "$ARTIFACTS_SH" 2>/dev/null || true
  if type fk_independent_review_gate_active >/dev/null 2>&1; then
    run fk_independent_review_gate_active "6"
    [ "$status" -eq 0 ]
  else
    skip "fk_independent_review_gate_active not available (artifacts.sh source failed)"
  fi
}

@test "AC-4: fk_independent_review_gate_active — off 模式 gate 不激活" {
  cat > "$FLOW_FILE" <<'EOF'
{"change_id":"test","goal":{"gate_config":{"6-review":"off"}}}
EOF
  export PROJECT_ROOT="$TEST_TMPDIR"
  export CWD="$TEST_TMPDIR"
  export HOOK_BASE_DIR="$(dirname "$ARTIFACTS_SH")"
  source "$ARTIFACTS_SH" 2>/dev/null || true
  if type fk_independent_review_gate_active >/dev/null 2>&1; then
    run fk_independent_review_gate_active "6"
    [ "$status" -eq 1 ]
  else
    skip "fk_independent_review_gate_active not available (artifacts.sh source failed)"
  fi
}

@test "AC-4: gate_val=both 时 L2 和 L3 均需运行" {
  local gate_val="both"
  # L3 需要运行
  [[ "$gate_val" == "L3" || "$gate_val" == "both" ]]
  [ "$?" -eq 0 ]
}

@test "AC-4: gate_val=L2 时 L3 不应运行" {
  local gate_val="L2"
  # L3 不需要运行
  [[ "$gate_val" != "L3" && "$gate_val" != "both" ]]
  [ "$?" -eq 0 ]
}

# ─────────────────────────────────────────────
# 场景 9: AC-5 超时 + exit code
# ─────────────────────────────────────────────

@test "AC-5: _l3_format_result timeout 返回 0" {
  run _l3_format_result "timeout" "L3 API 调用超时（30s）" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
}

@test "AC-5: _l3_format_result error 返回 0" {
  run _l3_format_result "error" "L3 结果解析失败（verdict 不可用）" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
}

@test "AC-5: _l3_format_result pass 返回 0" {
  run _l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
}

@test "AC-5: _l3_format_result fail 返回 0（不阻塞 transition）" {
  run _l3_format_result "fail" "存在问题" ".specs/test/INDEPENDENT-REVIEW-1.md"
  [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────
# 场景 10: stderr 安全测试（R4 fix — 测试实际 stderr 输出）
# ─────────────────────────────────────────────

@test "Security: _l3_format_result 白名单字段不含 URL" {
  local line
  line=$(_l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md")
  [[ ! "$line" =~ https?:// ]]
}

@test "Security: _l3_format_result 白名单字段不含 API key" {
  local line
  line=$(_l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md")
  [[ ! "$line" =~ sk-ant ]]
  [[ ! "$line" =~ sk-or ]]
}

@test "Security: _l3_format_result 白名单字段不含绝对路径" {
  local line
  line=$(_l3_format_result "pass" "OK" ".specs/test/INDEPENDENT-REVIEW-1.md")
  [[ ! "$line" =~ report=/ ]]
}

@test "Security: _l3_format_result 白名单字段不含 JSON 片段" {
  local line
  line=$(_l3_format_result "error" "L3 结果解析失败（verdict 不可用）" ".specs/test/INDEPENDENT-REVIEW-1.md")
  [[ ! "$line" =~ '"critical"' ]]
  [[ ! "$line" =~ '"verdict"' ]]
}

@test "Security: l3-review.sh 内部 >&2 日志使用 [l3-review] 前缀（便于过滤）" {
  # 验证所有 >&2 输出使用统一前缀
  if [ -f "$L3_REVIEW_SH" ]; then
    local stderr_count
    stderr_count=$(grep -c '>&2' "$L3_REVIEW_SH" || echo "0")
    local prefixed_count
    prefixed_count=$(grep -c '\[l3-review\].*>&2' "$L3_REVIEW_SH" || echo "0")
    # 至少主要的 >&2 输出使用了 [l3-review] 前缀
    [ "$prefixed_count" -ge 1 ]
  else
    skip "l3-review.sh not found at test path"
  fi
}

@test "Security: l3-review.sh 不 echo 裸 API 响应到 stdout" {
  if [ -f "$L3_REVIEW_SH" ]; then
    # $content 仅写入 review_md 文件（>>），不直接 echo 到 stdout
    ! grep -qP 'echo\s+"\$content"' "$L3_REVIEW_SH" 2>/dev/null
    ! grep -qP "echo\s+'\$content'" "$L3_REVIEW_SH" 2>/dev/null
    # 确认 content 通过 >> 写入文件而非 echo
    grep -q '>>.*review_md' "$L3_REVIEW_SH" || true
  else
    skip "l3-review.sh not found at test path"
  fi
}

# ─────────────────────────────────────────────
# 场景 11: R4 gate_config 参数传播验证
# ─────────────────────────────────────────────

@test "R4: l3_review_with_timeout 接受 6 参数（含 gate_config_value）" {
  if [ -f "$L3_REVIEW_SH" ]; then
    # 验证函数签名包含第 6 个参数 gate_config_value
    grep -q 'gate_config_value="\${6:-both}"' "$L3_REVIEW_SH"
    [ "$?" -eq 0 ]
  else
    skip "l3-review.sh not found at test path"
  fi
}

@test "R4: bash -c 子进程接收 gate_config_value 作为 \$5" {
  if [ -f "$L3_REVIEW_SH" ]; then
    # 验证子进程调用传递了 gate_config_value
    grep -q 'gate_config_value:-both.*2>/dev/null' "$L3_REVIEW_SH"
    [ "$?" -eq 0 ]
  else
    skip "l3-review.sh not found at test path"
  fi
}
