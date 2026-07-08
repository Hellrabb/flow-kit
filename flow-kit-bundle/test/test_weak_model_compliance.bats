#!/usr/bin/env bats
# test_weak_model_compliance.bats — tests for weak model compliance scanning
#
# Covers: L1 rule compliance (forbidden files + rule patterns),
#         L2 self-check completeness (PCSC table validation),
#         L3 evidence chain (path citation vs tool call history),
#         correction file management (write/merge/clear).

# Source the library once at file level (bats runs tests in the same shell)
LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../hooks/stop/lib"
export HOOK_BASE_DIR="${LIB_DIR}/.."  # correction-file.sh 依赖 HOOK_BASE_DIR 定位 lib/
LIB_PATH="${LIB_DIR}/weak-model-compliance.sh"
if [[ -f "$LIB_PATH" ]]; then
  source "$LIB_PATH"
fi

setup() {
  TEST_TMPDIR=$(mktemp -d "/tmp/bats-compliance-XXXXXX")
  export HOOK_TMP_DIR="${TEST_TMPDIR}/hook-tmp"
  mkdir -p "$HOOK_TMP_DIR"

  # Init correction path
  init_compliance_correction_path "$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Helper: create mock transcript-parser output files ──────────────────

write_mock_tool_files() {
  # written-files.txt
  printf '%s\n' "$@" > "$HOOK_TMP_DIR/written-files.txt"
  # edited-files.txt — only create if arg provided
  touch "$HOOK_TMP_DIR/edited-files.txt"
  touch "$HOOK_TMP_DIR/all-touched-files.txt"
  touch "$HOOK_TMP_DIR/bash-commands.txt"
  # Combine for all-touched
  cat "$HOOK_TMP_DIR/written-files.txt" "$HOOK_TMP_DIR/edited-files.txt" 2>/dev/null | sort -u > "$HOOK_TMP_DIR/all-touched-files.txt"
}

write_mock_messages() {
  printf '%s\n' "$@" > "$HOOK_TMP_DIR/messages.txt"
}

# ── L1: read_forbidden_list tests ─────────────────────────────────────

@test "L1-01: read_forbidden_list extracts paths from CONTEXT.md" {
  local ctx="${TEST_TMPDIR}/CONTEXT.md"
  cat > "$ctx" << 'EOF'
### 禁动清单（AI 不许"顺手"碰）

- `package-flow-kit.sh`（打包脚本核心逻辑，改动影响分发流程）
- `flow-kit-bundle.tar.gz`（已生成的分发包）
- `.gitignore`（手动维护）
EOF

  run read_forbidden_list "$ctx"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "package-flow-kit.sh" ]]
  [[ "$output" =~ "flow-kit-bundle.tar.gz" ]]
  [[ "$output" =~ ".gitignore" ]]
}

@test "L1-02: scan_l1_rules detects forbidden file write" {
  local ctx="${TEST_TMPDIR}/CONTEXT.md"
  cat > "$ctx" << 'EOF'
### 禁动清单

- `package-flow-kit.sh`（核心）
- `.gitignore`（手动维护）
EOF

  # Mock: model wrote package-flow-kit.sh
  echo "package-flow-kit.sh" > "$HOOK_TMP_DIR/written-files.txt"
  touch "$HOOK_TMP_DIR/edited-files.txt"
  touch "$HOOK_TMP_DIR/messages.txt"
  cat "$HOOK_TMP_DIR/written-files.txt" "$HOOK_TMP_DIR/edited-files.txt" | sort -u > "$HOOK_TMP_DIR/all-touched-files.txt"

  run scan_l1_rules "$HOOK_TMP_DIR" "$ctx"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -ge 1 ]]
  [[ "$output" =~ "触碰禁动文件" ]]
  [[ "$output" =~ "package-flow-kit.sh" ]]
}

@test "L1-03: scan_l1_rules returns empty when no forbidden files touched" {
  local ctx="${TEST_TMPDIR}/CONTEXT.md"
  cat > "$ctx" << 'EOF'
### 禁动清单

- `package-flow-kit.sh`（核心）
EOF

  # Mock: model wrote only allowed files
  echo "flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh" > "$HOOK_TMP_DIR/written-files.txt"
  touch "$HOOK_TMP_DIR/edited-files.txt"
  touch "$HOOK_TMP_DIR/messages.txt"
  cat "$HOOK_TMP_DIR/written-files.txt" "$HOOK_TMP_DIR/edited-files.txt" | sort -u > "$HOOK_TMP_DIR/all-touched-files.txt"

  run scan_l1_rules "$HOOK_TMP_DIR" "$ctx"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -eq 0 ]]
}

@test "L1-04: scan_l1_rules detects generic rule-violation pattern in messages" {
  local ctx="${TEST_TMPDIR}/CONTEXT.md"
  echo "### 禁动清单" > "$ctx"  # minimal, no forbidden files

  touch "$HOOK_TMP_DIR/written-files.txt"
  touch "$HOOK_TMP_DIR/edited-files.txt"
  cat "$HOOK_TMP_DIR/written-files.txt" "$HOOK_TMP_DIR/edited-files.txt" | sort -u > "$HOOK_TMP_DIR/all-touched-files.txt"

  # Message with rule violation pattern
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
I'll just skip the self-check for now since the changes are trivial.
禁止跳过 AskUserQuestion but I'll proceed without it.
EOF

  run scan_l1_rules "$HOOK_TMP_DIR" "$ctx"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -ge 1 ]]
  [[ "$output" =~ "违反通用禁动规则" ]]
}

# ── L2: scan_l2_selfcheck tests ──────────────────────────────────────

@test "L2-01: scan_l2_selfcheck detects blank row in PCSC table" {
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
## 阶段完成自检（Phase Completion Self-Check）

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | REQUIREMENT.md | test -f | ✅ |
| 2 | CONTEXT.md | 人工确认 | ✅ / ❌ |
| 3 | AC Given/When/Then | 人工确认 |   |
EOF

  run scan_l2_selfcheck "$HOOK_TMP_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -ge 1 ]]
  [[ "$output" =~ "未填标记" ]]
}

@test "L2-02: scan_l2_selfcheck passes when all rows filled" {
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
## 阶段完成自检（Phase Completion Self-Check）

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | REQUIREMENT.md | test -f | ✅ |
| 2 | CONTEXT.md | 人工确认 | ✅ |
| 3 | AC Given/When/Then | 人工确认 | ✅ |
EOF

  run scan_l2_selfcheck "$HOOK_TMP_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -eq 0 ]]
}

@test "L2-03: scan_l2_selfcheck returns empty when no table found" {
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
This is a normal response without any self-check tables.
The implementation is complete and all tests pass.
EOF

  run scan_l2_selfcheck "$HOOK_TMP_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -eq 0 ]]
}

@test "L2-04: scan_l2_selfcheck detects multiple blank rows" {
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
## 阶段完成自检（Phase 2）

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | DESIGN.md | test -f | ✅ |
| 2 | 技术栈 | 人工确认 | ✅ / ❌ |
| 3 | 架构对齐 | 人工确认 |   |
| 4 | 决策清单 | 人工确认 | ✅ / ❌ |
| 5 | 架构图 | 人工确认 |   |
EOF

  run scan_l2_selfcheck "$HOOK_TMP_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -eq 2 ]]
}

# ── L3: scan_l3_evidence tests ───────────────────────────────────────

@test "L3-01: scan_l3_evidence detects hallucinated path" {
  # Mock: model cites a path not in any tool call evidence
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
According to flow-kit/prompts/4-dev.md line 150, we should run the tests.
EOF

  # Tool evidence is empty — model never read this file
  touch "$HOOK_TMP_DIR/written-files.txt"
  touch "$HOOK_TMP_DIR/edited-files.txt"
  touch "$HOOK_TMP_DIR/bash-commands.txt"
  cat "$HOOK_TMP_DIR/written-files.txt" "$HOOK_TMP_DIR/edited-files.txt" | sort -u > "$HOOK_TMP_DIR/all-touched-files.txt"

  run scan_l3_evidence "$HOOK_TMP_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -ge 1 ]]
  [[ "$output" =~ "flow-kit/prompts/4-dev.md" ]]
}

@test "L3-02: scan_l3_evidence passes when path in tool call history" {
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
As we can see in .specs/CONTEXT.md, the forbidden list is clear.
EOF

  # Mock: model did read this file — path must match exactly
  echo '.specs/CONTEXT.md' > "$HOOK_TMP_DIR/written-files.txt"
  touch "$HOOK_TMP_DIR/edited-files.txt"
  echo '.specs/CONTEXT.md' > "$HOOK_TMP_DIR/all-touched-files.txt"
  touch "$HOOK_TMP_DIR/bash-commands.txt"

  run scan_l3_evidence "$HOOK_TMP_DIR"
  echo "DBG output=$output" >&2
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  [[ "$count" -eq 0 ]]
}

@test "L3-03: scan_l3_evidence handles mixed real and hallucinated paths" {
  cat > "$HOOK_TMP_DIR/messages.txt" << 'EOF'
The state is in .specs/STATE.md and we should check flow-kit/reference/nonexistent.md.
Also consider hooks/lib/utils.sh for the helper function.
EOF

  # Only .specs/STATE.md was actually read
  echo ".specs/STATE.md" > "$HOOK_TMP_DIR/written-files.txt"
  touch "$HOOK_TMP_DIR/edited-files.txt"
  echo ".specs/STATE.md" > "$HOOK_TMP_DIR/all-touched-files.txt"
  touch "$HOOK_TMP_DIR/bash-commands.txt"

  run scan_l3_evidence "$HOOK_TMP_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | jq 'length')
  # flow-kit/reference/nonexistent.md and hooks/lib/utils.sh are hallucinated
  [[ "$count" -ge 1 ]]
  [[ "$output" =~ "nonexistent" ]] || [[ "$output" =~ "utils.sh" ]]
  # .specs/STATE.md should NOT be in violations
  ! echo "$output" | grep -q "STATE.md"
}

# ── Correction file tests ────────────────────────────────────────────

@test "CF-01: write_compliance_correction creates valid JSON with all fields" {
  local violations='[{"rule":"L1: test","location":"test.bats:1","fix":"do X"}]'

  run write_compliance_correction "L1" "$violations" "2026-06-29T00:00:00+08:00"
  [[ "$status" -eq 0 ]]

  # Verify file exists and is valid JSON
  [[ -f "$COMPLIANCE_CORRECTION_FILE" ]]
  jq empty "$COMPLIANCE_CORRECTION_FILE"

  # Check all required fields
  local t l c
  t=$(jq -r '.type' "$COMPLIANCE_CORRECTION_FILE")
  l=$(jq -r '.violations[0].layer' "$COMPLIANCE_CORRECTION_FILE")
  c=$(jq -r '.violations | length' "$COMPLIANCE_CORRECTION_FILE")

  [[ "$t" == "compliance" ]]
  [[ "$l" == "L1" ]]
  [[ "$c" -eq 1 ]]
}

@test "CF-02: write_compliance_correction merges with existing + dedup" {
  # Write first violation
  local v1='[{"rule":"L1: forbidden","location":"file1.sh","fix":"undo"}]'
  write_compliance_correction "L1" "$v1" "2026-06-29T00:00:00+08:00"

  # Write second violation (different)
  local v2='[{"rule":"L2: blank row","location":"messages.txt:5","fix":"fill row"}]'
  write_compliance_correction "L2" "$v2" "2026-06-29T00:00:01+08:00"

  local count
  count=$(jq -r '.violations | length' "$COMPLIANCE_CORRECTION_FILE")
  [[ "$count" -eq 2 ]]

  # Write same L1 violation again — should be deduped
  write_compliance_correction "L1" "$v1" "2026-06-29T00:00:02+08:00"

  count=$(jq -r '.violations | length' "$COMPLIANCE_CORRECTION_FILE")
  [[ "$count" -eq 2 ]]  # still 2, dedup worked
}

@test "CF-03: clear_compliance_correction removes the file" {
  local violations='[{"rule":"test","location":"x","fix":"y"}]'
  write_compliance_correction "L1" "$violations"
  [[ -f "$COMPLIANCE_CORRECTION_FILE" ]]

  run clear_compliance_correction
  [[ "$status" -eq 0 ]]
  [[ ! -f "$COMPLIANCE_CORRECTION_FILE" ]]
}
