#!/usr/bin/env bats
# ============================================================================
# quality-baseline — stop 链主脚本 smoke test
# 覆盖: 22-git / 24-session / 26-workflow / 99-report
# 级别: smoke — 语法检查 + 文件完整性 + 关键模式存在
# 注: 这些脚本依赖 Claude Code 运行时环境（lib/common.sh 路径由 hook 注入），
#     无法在 bats 中直接 source。采用语法检查 + grep 关键函数名验证。
# ============================================================================

STOP_DIR="flow-kit-bundle/hooks/stop"

# ── 22-git.sh ──

@test "smoke: 22-git.sh 语法正确" {
  run bash -n "$STOP_DIR/22-git.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 22-git.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/22-git.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 22-git.sh 含初始化和状态变量" {
  run grep -q "git\|commit\|branch\|FLOW_ACTIVE" "$STOP_DIR/22-git.sh"
  [ "$status" -eq 0 ]
}

# ── 24-session.sh ──

@test "smoke: 24-session.sh 语法正确" {
  run bash -n "$STOP_DIR/24-session.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 24-session.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/24-session.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 24-session.sh 含 main 函数定义" {
  run grep -q "format_duration\|main()" "$STOP_DIR/24-session.sh"
  [ "$status" -eq 0 ]
}

# ── 26-workflow.sh ──

@test "smoke: 26-workflow.sh 语法正确" {
  run bash -n "$STOP_DIR/26-workflow.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 26-workflow.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/26-workflow.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 26-workflow.sh 含 get_workflow_state 函数定义" {
  run grep -q "_fk_file_age_days\|_fk_check_g1_body" "$STOP_DIR/26-workflow.sh"
  [ "$status" -eq 0 ]
}

# ── 99-report.sh ──

@test "smoke: 99-report.sh 语法正确" {
  run bash -n "$STOP_DIR/99-report.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 99-report.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/99-report.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 99-report.sh 含 generate_report 函数定义" {
  run grep -q "build_summary\|generate_report()" "$STOP_DIR/99-report.sh"
  [ "$status" -eq 0 ]
}

# ── 00-gate.sh 调度列表完整性 (gate-integrity / AC-6 dogfood) ──────────
# 修复：00-gate 必须调度 27/28/29（否则 L3/合规/交互UI 三模块从不自动跑）

@test "smoke: 00-gate.sh 调度列表含 27/28/29（L3 自动跑前提）" {
  run grep -c "run_module.*27-interactive-ui-check\|run_module.*28-weak-model-compliance\|run_module.*29-independent-review" "$STOP_DIR/00-gate.sh"
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

# ── 23-quality.sh（Module D · TD-002 AC-3 补 smoke）──────────────────────

@test "smoke: 23-quality.sh 语法正确" {
  run bash -n "$STOP_DIR/23-quality.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 23-quality.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/23-quality.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 23-quality.sh 含代码质量检查函数" {
  run grep -q "src_touched\|cmd_ran\|count_changed_lines" "$STOP_DIR/23-quality.sh"
  [ "$status" -eq 0 ]
}

# ── 27-interactive-ui-check.sh（Module I）─────────────────────────────────

@test "smoke: 27-interactive-ui-check.sh 语法正确" {
  run bash -n "$STOP_DIR/27-interactive-ui-check.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 27-interactive-ui-check.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/27-interactive-ui-check.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 27-interactive-ui-check.sh 含交互 UI 检查函数" {
  run grep -q "check_i1\|interactive.ui" "$STOP_DIR/27-interactive-ui-check.sh"
  [ "$status" -eq 0 ]
}

# ── 28-weak-model-compliance.sh（Module 28）───────────────────────────────

@test "smoke: 28-weak-model-compliance.sh 语法正确" {
  run bash -n "$STOP_DIR/28-weak-model-compliance.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 28-weak-model-compliance.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/28-weak-model-compliance.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 28-weak-model-compliance.sh 含合规检查函数" {
  run grep -q "check_compliance\|compliance" "$STOP_DIR/28-weak-model-compliance.sh"
  [ "$status" -eq 0 ]
}

# ── 29-independent-review.sh（L3 审查入口）───────────────────────────────

@test "smoke: 29-independent-review.sh 语法正确" {
  run bash -n "$STOP_DIR/29-independent-review.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 29-independent-review.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/29-independent-review.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 29-independent-review.sh 含 L3 审查调度" {
  run grep -q "l3.review\|l3_review\|independent.review" "$STOP_DIR/29-independent-review.sh"
  [ "$status" -eq 0 ]
}

# ── 30-ai-analyze.sh（AI 分析）────────────────────────────────────────────

@test "smoke: 30-ai-analyze.sh 语法正确" {
  run bash -n "$STOP_DIR/30-ai-analyze.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 30-ai-analyze.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/30-ai-analyze.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 30-ai-analyze.sh 含分析/API 模式" {
  run grep -q "analyze\|API\|onecli" "$STOP_DIR/30-ai-analyze.sh"
  [ "$status" -eq 0 ]
}

# ── 33-flow-active-integrity.sh ───────────────────────────────────────────

@test "smoke: 33-flow-active-integrity.sh 语法正确" {
  run bash -n "$STOP_DIR/33-flow-active-integrity.sh"
  [ "$status" -eq 0 ]
}

@test "smoke: 33-flow-active-integrity.sh 非空且含 shebang" {
  run head -1 "$STOP_DIR/33-flow-active-integrity.sh"
  [[ "$output" =~ ^#!/bin/bash ]]
}

@test "smoke: 33-flow-active-integrity.sh 含完整性检查函数" {
  run grep -q "_flow_active_integrity_main\|_fai_check" "$STOP_DIR/33-flow-active-integrity.sh"
  [ "$status" -eq 0 ]
}
