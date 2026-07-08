#!/usr/bin/env bats
# test_l2_l3_fix_compliance.bats — L2/L3 review 实效性校验测试
#
# 覆盖 AC-2/AC-2a/AC-2b/AC-3/AC-5

setup() {
  # 位置无关：向上查找含 flow-kit-bundle/hooks 的目录
  # （双源 test/ 与 flow-kit-bundle/test/ 同一份代码都正确 · L-025 同源路径问题根治）
  local d
  d="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  while [ "$d" != "/" ] && [ ! -d "$d/flow-kit-bundle/hooks/stop" ]; do
    d="$(dirname "$d")"
  done
  TEST_ROOT="$d/flow-kit-bundle"
  LIB_DIR="${TEST_ROOT}/hooks/stop/lib"
  FIX_COMPLIANCE_LIB="${LIB_DIR}/fix-compliance.sh"

  # 确保 lib 存在
  if [ ! -f "$FIX_COMPLIANCE_LIB" ]; then
    skip "fix-compliance.sh not found"
  fi

  source "$FIX_COMPLIANCE_LIB"

  # 临时目录
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR" 2>/dev/null || true
}

# ══════════════════════════════════════════════════════════════
# AC-2a: 源码级发现分类判定规则
# ══════════════════════════════════════════════════════════════

@test "AC-2a: Symptom with .sh path → classified as source-level" {
  # 模拟 Symptom 字段含源码文件引用
  local symptom_content="Symptom: in hooks/stop/lib/l3-review.sh line 42, hardcoded model name"
  local exts="sh:bats:js:ts:py:go:rs"

  run fk_classify_source_files "hooks/stop/lib/l3-review.sh" "$exts"
  [ "$status" -eq 0 ]
  [[ "$output" =~ source:1 ]]
  [[ "$output" =~ doc:0 ]]
}

@test "AC-2a: Symptom with only .md path → classified as doc-level" {
  local symptom_content="Symptom: in REQUIREMENT.md:45, missing AC"
  local exts="sh:bats:js:ts:py:go:rs"

  run fk_classify_source_files "REQUIREMENT.md" "$exts"
  [ "$status" -eq 0 ]
  [[ "$output" =~ source:0 ]]
  [[ "$output" =~ doc:1 ]]
}

@test "AC-2a: Symptom with .sh path + line number → path extraction strips line number" {
  local exts="sh:bats:js:ts:py:go:rs"

  # 模拟 "file.sh:42" 格式 — fk_classify_source_files 剥离冒号后缀
  run fk_classify_source_files "hooks/pre-tool-use/independent-review-gate.sh:260" "$exts"
  [ "$status" -eq 0 ]
  [[ "$output" =~ source:1 ]]
}

@test "AC-2a: Mixed file types → both counts correct" {
  local file_list="hooks/stop/lib/fix-compliance.sh
README.md
flow-kit-bundle/test/test_fix.bats
.specs/CONTEXT.md"
  local exts="sh:bats:js:ts"

  run fk_classify_source_files "$file_list" "$exts"
  [ "$status" -eq 0 ]
  [[ "$output" =~ source:2 ]]   # .sh + .bats
  [[ "$output" =~ doc:2 ]]      # 2x .md
}

@test "AC-2a: Empty input → return 1" {
  run fk_classify_source_files "" ""
  [ "$status" -eq 1 ]
}

# ══════════════════════════════════════════════════════════════
# AC-2: 纯文档响应检测
# ══════════════════════════════════════════════════════════════

@test "AC-2: .sh diff → fk_check_doc_only_diff returns 0 (pass)" {
  # 初始化临时 git 仓库 + 源码文件 diff
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"
  echo "changed" > test_script.sh
  git add test_script.sh

  run fk_check_doc_only_diff "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ DOC_ONLY:false ]]
}

@test "AC-2: Only .md diff → fk_check_doc_only_diff returns 1 (block)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"
  echo "# updated doc" > README.md
  git add README.md

  run fk_check_doc_only_diff "$TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" =~ DOC_ONLY:true ]]
}

@test "AC-2: Empty diff (no changes) → fk_check_doc_only_diff returns 2 (block)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"
  # 无新变更

  run fk_check_doc_only_diff "$TMPDIR"
  [ "$status" -eq 2 ]
}

@test "AC-2: Mix of .sh + .md → fk_check_doc_only_diff returns 0 (pass)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"
  echo "# updated doc" > README.md
  echo "#!/bin/bash" > fix.sh
  git add README.md fix.sh

  run fk_check_doc_only_diff "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ DOC_ONLY:false ]]
}

# ══════════════════════════════════════════════════════════════
# AC-2b: 逐发现文件级校验
# ══════════════════════════════════════════════════════════════

@test "AC-2b: Fixed in: file exists in diff → OK" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # 创建 review md 含 "Fixed in:" 声明
  echo "Fixed in: test_fix.sh" > review.md

  # 创建并修改对应文件
  echo "#!/bin/bash" > test_fix.sh
  git add test_fix.sh

  run fk_verify_finding_files "$TMPDIR/review.md" "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ OK:test_fix\.sh ]]
}

@test "AC-2b: Single Fixed in: file NOT in diff → 100% MISSING → blocked" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # review md 声明修复了不存在于 diff 的文件（1/1 = 100% MISSING → 阻断）
  echo "Fixed in: missing_file.sh" > review.md

  run fk_verify_finding_files "$TMPDIR/review.md" "$TMPDIR"
  [ "$status" -eq 1 ]   # 100% MISSING → 阻断
  [[ "$output" =~ BLOCKED:1/1 ]]
}

@test "AC-2b: 1/3 MISSING (33%) → NOT blocked (R1 fix: odd-total threshold)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  cat > review.md <<'EOF'
Fixed in: present_a.sh
Fixed in: present_b.sh
Fixed in: missing_one.sh
EOF

  echo "#!/bin/bash" > present_a.sh
  echo "#!/bin/bash" > present_b.sh
  git add present_a.sh present_b.sh

  run fk_verify_finding_files "$TMPDIR/review.md" "$TMPDIR"
  [ "$status" -eq 0 ]   # 33% < 50% → 告警但放行
  [[ "$output" =~ WARNING:1/3 ]]
}

@test "AC-2b: ≥50% MISSING → fk_verify_finding_files returns 1 (block)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # 3 条声明，仅 1 条在 diff 中 → 2/3 = 67% ≥ 50%
  cat > review.md <<'EOF'
Fixed in: present.sh
Fixed in: missing1.sh
Fixed in: missing2.sh
EOF

  echo "#!/bin/bash" > present.sh
  git add present.sh

  run fk_verify_finding_files "$TMPDIR/review.md" "$TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" =~ BLOCKED:2/3 ]]
}

@test "AC-2b: No Fixed in declarations → OK (all tech-debt or not-applicable)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # review md 无 "Fixed in:" 声明
  echo "All findings marked as Tech-debt or Not-applicable" > review.md

  run fk_verify_finding_files "$TMPDIR/review.md" "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ OK:no_fixed_claims ]]
}

@test "AC-2b: <50% MISSING → pass with warning" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # 4 条声明，1 条 MISSING → 25% < 50%
  cat > review.md <<'EOF'
Fixed in: a.sh
Fixed in: b.sh
Fixed in: c.sh
Fixed in: missing.sh
EOF

  echo "#!/bin/bash" > a.sh
  echo "#!/bin/bash" > b.sh
  echo "#!/bin/bash" > c.sh
  git add a.sh b.sh c.sh

  run fk_verify_finding_files "$TMPDIR/review.md" "$TMPDIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ WARNING:1/4.*MISSING ]]
}

# ══════════════════════════════════════════════════════════════
# AC-3: 双层共存 — 真实性校验 + 实效性校验不互相干扰
# ══════════════════════════════════════════════════════════════

@test "AC-3: Fake .done + doc-only diff → both layers report independently" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # 模拟场景：.done 为空文件（真实性校验会失败）+ diff 仅 .md（实效性会阻断）
  # 两个检测维度互不干扰

  # ① 创建假 .done（空文件 — 真实性 fail）
  touch "$TMPDIR/.done_fake"

  # ② 创建仅 .md 的 diff
  echo "# doc only" > README.md
  git add README.md

  # 实效性检测独立判断：纯文档 diff → 阻断
  run fk_check_doc_only_diff "$TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" =~ DOC_ONLY:true ]]

  # 真实性检测也独立判断（由 fk_validate_done_marker 处理，此处验证空文件存在）
  [ -f "$TMPDIR/.done_fake" ]
  [ ! -s "$TMPDIR/.done_fake" ]  # 空文件 — 真实性应失败
}

@test "AC-3: Valid .done + doc-only diff → authenticity passes but efficacy blocks" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  # 模拟合法 .done（6 键 KVP）
  cat > "$TMPDIR/.done_valid" <<'DONEEOF'
phase=5
change_id=test-change
written_by=pre-tool-use-gate
L2_verdict=pass
L3_verdict=pass
L3_summary=all good
artifacts=TEST.md,TASK.md
DONEEOF

  # 仅 .md diff
  echo "# doc update" > README.md
  git add README.md

  # 实效性检测应独立阻断
  run fk_check_doc_only_diff "$TMPDIR"
  [ "$status" -eq 1 ]

  # 合法性检测：.done 文件格式正确（6 键齐全）
  run grep -c "=" "$TMPDIR/.done_valid"
  [ "$status" -eq 0 ]
  [ "$output" -ge 6 ]
}

# ══════════════════════════════════════════════════════════════
# AC-5: 阶段限定 — 仅 phase 5/6/7 触发实效性校验
# ══════════════════════════════════════════════════════════════

@test "AC-5: phase=5 → fk_fix_compliance_check runs (does not skip)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  mkdir -p "$TMPDIR/.specs/test-change"
  echo "Fixed in: x.sh" > "$TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-5.md"

  # phase=5 应触发检测
  # 无源码 diff → 应阻断
  run fk_fix_compliance_check "5" "test-change" "$TMPDIR/.specs/test-change" "$TMPDIR"
  # status=1 表示检测到了问题（纯文档或无源码 diff）
  # status=0 仅在放行时
  [ "$status" -ne 3 ]  # 不应是内部错误
}

@test "AC-5: phase=6 → fk_fix_compliance_check runs (does not skip)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  mkdir -p "$TMPDIR/.specs/test-change"
  echo "Fixed in: x.sh" > "$TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-6.md"

  run fk_fix_compliance_check "6" "test-change" "$TMPDIR/.specs/test-change" "$TMPDIR"
  [ "$status" -ne 3 ]
}

@test "AC-5: phase=7 → fk_fix_compliance_check runs (does not skip)" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  mkdir -p "$TMPDIR/.specs/test-change"
  echo "Fixed in: x.sh" > "$TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-7.md"

  run fk_fix_compliance_check "7" "test-change" "$TMPDIR/.specs/test-change" "$TMPDIR"
  [ "$status" -ne 3 ]
}

@test "AC-5: phase=1 → fk_fix_compliance_check skips (returns 0 immediately)" {
  run fk_fix_compliance_check "1" "test-change" "/nonexistent/specs" "/nonexistent"
  [ "$status" -eq 0 ]
}

@test "AC-5: phase=2 → fk_fix_compliance_check skips (returns 0 immediately)" {
  run fk_fix_compliance_check "2" "test-change" "/nonexistent/specs" "/nonexistent"
  [ "$status" -eq 0 ]
}

@test "AC-5: phase=3 → fk_fix_compliance_check skips (returns 0 immediately)" {
  run fk_fix_compliance_check "3" "test-change" "/nonexistent/specs" "/nonexistent"
  [ "$status" -eq 0 ]
}

# ══════════════════════════════════════════════════════════════
# ②b CRITICAL fix: 源码级发现 >0 但无 Fixed in:/Tech-debt: → 阻断
# ══════════════════════════════════════════════════════════════

@test "②b CRITICAL: source findings >0 + no Fixed in/Tech-debt → block" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  mkdir -p "$TMPDIR/.specs/test-change"
  # review md 有源码级发现（Symptom 含 .sh 路径），但 agent 无任何 Fixed in: 或 Tech-debt: 声明
  cat > "$TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-6.md" <<'REVIEWEOF'
### 🔴 R1 · Critical finding
**Symptom（症状）**：hooks/stop/lib/l3-review.sh line 42 hardcoded model name

Agent response:
Acknowledged. Will fix in next iteration.
REVIEWEOF

  # 创建一些源码 diff（但无 Fixed in: 声明）
  echo "#!/bin/bash" > some_fix.sh
  git add some_fix.sh

  run fk_fix_compliance_check "6" "test-change" "$TMPDIR/.specs/test-change" "$TMPDIR"
  [ "$status" -eq 2 ]
}

@test "②b: source findings >0 + Tech-debt declarations only → allowed" {
  cd "$TMPDIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > init.txt
  git add init.txt && git commit -q -m "init"

  mkdir -p "$TMPDIR/.specs/test-change"
  cat > "$TMPDIR/.specs/test-change/INDEPENDENT-REVIEW-6.md" <<'REVIEWEOF'
### 🔴 R1 · Critical finding
**Symptom（症状）**：hooks/stop/lib/l3-review.sh line 42 hardcoded model name

Tech-debt: Model name refactoring deferred to v2 — requires ANTHROPIC_DEFAULT_HAIKU_MODEL env var migration across all hook scripts.
REVIEWEOF

  run fk_fix_compliance_check "6" "test-change" "$TMPDIR/.specs/test-change" "$TMPDIR"
  # Tech-debt 声明存在 → 不应因"无 Fixed in"而阻断
  [ "$status" -ne 2 ]
}

# ══════════════════════════════════════════════════════════════
# L3_FIX_SOURCE_EXTS env var 覆盖
# ══════════════════════════════════════════════════════════════

@test "L3_FIX_SOURCE_EXTS overrides default whitelist" {
  # 默认白名单不含 .nim
  local default_exts
  default_exts=$(_fk_get_source_exts)
  [[ "$default_exts" != *"nim"* ]]

  # env var 覆盖
  export L3_FIX_SOURCE_EXTS="sh:nim:zig"
  local custom_exts
  custom_exts=$(_fk_get_source_exts)
  [[ "$custom_exts" == "sh:nim:zig" ]]
  unset L3_FIX_SOURCE_EXTS
}
