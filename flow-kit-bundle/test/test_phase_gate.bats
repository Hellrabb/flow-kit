#!/usr/bin/env bats
# test_phase_gate.bats — PCSC + PCG 双层防护测试
# bats_require_minimum_version 1.10.0

# 路径常量 — bundle 源文件（规范源）
PROMPTS_DIR="flow-kit-bundle/flow-kit/prompts"
GO_MD="flow-kit-bundle/flow-kit/GO.md"

# 阶段 prompt 文件名（按 phase 顺序）
PHASE_PROMPTS=(
  "1-requirement.md"
  "2-design.md"
  "3-task.md"
  "4-dev.md"
  "5-test.md"
  "6-review.md"
  "7-integration.md"
)

# ── AC-1: PCSC 存在性 ──────────────────────────────────────────────────

@test "AC-1: all 7 phase prompts contain Phase Completion Self-Check section" {
  local missing=0
  for f in "${PHASE_PROMPTS[@]}"; do
    if ! grep -q "阶段完成自检（Phase Completion Self-Check）" "$PROMPTS_DIR/$f"; then
      echo "MISSING: $f lacks PCSC section"
      missing=$((missing + 1))
    fi
  done
  [[ $missing -eq 0 ]]
}

@test "AC-1: PCSC section is placed before Pipeline Toll-Gate or equivalent" {
  # 验证 PCSC 段在 toll-gate 之前（行号上 PCSC < toll-gate）
  local fail=0
  for f in "${PHASE_PROMPTS[@]}"; do
    local pcsc_line toll_line
    pcsc_line=$(grep -n "阶段完成自检（Phase Completion Self-Check）" "$PROMPTS_DIR/$f" | head -1 | cut -d: -f1)
    toll_line=$(grep -n "Pipeline Toll-Gate\|Toll-gate [0-9]→[0-9]\|Pipeline 完成（AC-8）" "$PROMPTS_DIR/$f" | head -1 | cut -d: -f1)
    if [[ -z "$pcsc_line" || -z "$toll_line" ]]; then
      echo "SKIP: $f — PCSC=$pcsc_line toll=$toll_line"
      continue
    fi
    if [[ "$pcsc_line" -ge "$toll_line" ]]; then
      echo "FAIL: $f — PCSC at line $pcsc_line but toll-gate at $toll_line"
      fail=$((fail + 1))
    fi
  done
  [[ $fail -eq 0 ]]
}

# ── AC-2: 阻断规则 ─────────────────────────────────────────────────────

@test "AC-2: all 7 prompts contain blocking rule (禁止进入 toll-gate or equivalent)" {
  local missing=0
  for f in "${PHASE_PROMPTS[@]}"; do
    if ! grep -q "禁止进入 toll-gate\|禁止执行 pipeline 完成" "$PROMPTS_DIR/$f"; then
      echo "MISSING blocking rule in: $f"
      missing=$((missing + 1))
    fi
  done
  [[ $missing -eq 0 ]]
}

@test "AC-2: all 7 prompts contain '补齐缺失项后重新自检' remedy instruction" {
  local missing=0
  for f in "${PHASE_PROMPTS[@]}"; do
    if ! grep -q "补齐缺失项后重新自检" "$PROMPTS_DIR/$f"; then
      echo "MISSING remedy in: $f"
      missing=$((missing + 1))
    fi
  done
  [[ $missing -eq 0 ]]
}

# ── AC-3: auto_advance 适配 ────────────────────────────────────────────

@test "AC-3: 5-test auto_advance=true runs self-check before auto-transition" {
  # 验证 auto_advance=true 分支包含自检相关逻辑
  local section
  section=$(sed -n '/### 阶段完成自检/,/### Toll-gate 5→6/p' "$PROMPTS_DIR/5-test.md")

  # auto_advance=true 分支应提到自检
  echo "$section" | grep -q "auto_advance=true"

  # 应有全✅自动transition、有❌暂停的逻辑
  echo "$section" | grep -q "全 ✅.*自动 transition\|全 ✅.*自动"
  echo "$section" | grep -q "暂停 pipeline"
}

@test "AC-3: 6-review auto_advance=true runs self-check before auto-transition" {
  local section
  section=$(sed -n '/### 阶段完成自检/,/### Toll-gate 6→7/p' "$PROMPTS_DIR/6-review.md")

  echo "$section" | grep -q "auto_advance=true"
  echo "$section" | grep -q "全 ✅.*自动 transition\|全 ✅.*自动"
  echo "$section" | grep -q "暂停 pipeline"
}

@test "AC-3: auto_advance=false requires manual toll-gate confirmation" {
  # 验证 auto_advance=false 分支要求进入 toll-gate
  for f in "5-test.md" "6-review.md"; do
    local section
    section=$(sed -n '/### 阶段完成自检/,/### Toll-gate/p' "$PROMPTS_DIR/$f")
    if ! echo "$section" | grep -q "auto_advance=false\|进入 toll-gate"; then
      echo "FAIL: $f — missing auto_advance=false path"
      false
    fi
  done
}

# ── AC-4: GO.md Phase Completion Gate ──────────────────────────────────

@test "AC-4: GO.md contains Phase Completion Gate section" {
  grep -q "Phase Completion Gate" "$GO_MD"
}

@test "AC-4: GO.md PCG contains artifact verification table (test -s for non-empty)" {
  grep -q "test -s .specs" "$GO_MD"
}

@test "AC-4: GO.md PCG covers all 7 phases (0-6)" {
  # 验证产物清单覆盖全部退出阶段
  for phase in 0 1 2 3 4 5 6; do
    if ! grep -q "| $phase |" "$GO_MD"; then
      echo "MISSING phase $phase in GO.md PCG table"
      false
    fi
  done
  true
}

@test "AC-4: GO.md PCG includes rejection logic" {
  grep -q "拒绝路由" "$GO_MD"
  grep -q "Phase Completion Gate 拦截" "$GO_MD"
}

# ── AC-5: 产物清单一致性 ──────────────────────────────────────────────

@test "AC-5: GO.md PCG artifact paths match prompt PCSC key artifacts" {
  # GO.md PCG 中的关键产物与 prompt 自检段中的对应文件名一致
  # Phase 1 → REQUIREMENT.md
  grep -q "REQUIREMENT.md" "$GO_MD"
  grep -q "REQUIREMENT.md" "$PROMPTS_DIR/1-requirement.md"

  # Phase 2 → DESIGN.md
  grep -q "DESIGN.md" "$GO_MD"
  grep -q "DESIGN.md" "$PROMPTS_DIR/2-design.md"

  # Phase 3 → TASK.md
  grep -q "TASK.md" "$GO_MD"
  grep -q "TASK.md" "$PROMPTS_DIR/3-task.md"

  # Phase 5 → TEST.md
  grep -q "TEST.md" "$GO_MD"
  grep -q "TEST.md" "$PROMPTS_DIR/5-test.md"

  # Phase 6 → REVIEW.md
  grep -q "REVIEW.md" "$GO_MD"
  grep -q "REVIEW.md" "$PROMPTS_DIR/6-review.md"
}

# ── AC-6: TD-003 验证（start_phase 已在 5/6/7 入口 jq 中） ──────────

@test "AC-6: 5-test entry jq includes start_phase fallback" {
  grep -q 'start_phase // "4"' "$PROMPTS_DIR/5-test.md"
  grep -q 'current_phase // .start_phase // "4"' "$PROMPTS_DIR/5-test.md"
}

@test "AC-6: 6-review entry jq includes start_phase fallback" {
  grep -q 'start_phase // "4"' "$PROMPTS_DIR/6-review.md"
  grep -q 'current_phase // .start_phase // "4"' "$PROMPTS_DIR/6-review.md"
}

@test "AC-6: 7-integration entry jq includes start_phase fallback" {
  grep -q 'start_phase // "4"' "$PROMPTS_DIR/7-integration.md"
  grep -q 'current_phase // .start_phase // "4"' "$PROMPTS_DIR/7-integration.md"
}

# ── 结构完整性 ──────────────────────────────────────────────────────────

@test "PCSC auto_advance branch exists in all 7 prompts" {
  local missing=0
  for f in "${PHASE_PROMPTS[@]}"; do
    if ! grep -q "auto_advance 分支\|### auto_advance 分支" "$PROMPTS_DIR/$f"; then
      echo "MISSING auto_advance branch in: $f"
      missing=$((missing + 1))
    fi
  done
  [[ $missing -eq 0 ]]
}

@test "GO.md PCG and Artifact Preflight Gate are distinct sections" {
  grep -q "Artifact Preflight Gate" "$GO_MD"
  grep -q "Phase Completion Gate" "$GO_MD"

  # PCG 应该在 Preflight 之后
  local preflight_line pcg_line
  preflight_line=$(grep -n "Artifact Preflight Gate（强制）" "$GO_MD" | head -1 | cut -d: -f1)
  pcg_line=$(grep -n "Phase Completion Gate" "$GO_MD" | head -1 | cut -d: -f1)

  [[ "$pcg_line" -gt "$preflight_line" ]]
}
