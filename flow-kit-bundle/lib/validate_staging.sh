#!/bin/bash
# validate_staging.sh — 打包完整性校验（L-012）
# Source from package-flow-kit.sh or call standalone for validation.
#
# Provides: validate_staging_coverage()
# Usage: validate_staging_coverage [bundle_dir]
#   bundle_dir defaults to the flow-kit-bundle/ directory relative to this script.
# exit: 0=通过, 1=有漏配, 2=脚本自身错误

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# validate_staging_coverage() — L-012 打包完整性校验
# 比对 flow-kit-bundle/ 实际目录树与 Part A~G staging 覆盖范围
# exit: 0=通过, 1=有漏配, 2=脚本自身错误
# ═══════════════════════════════════════════════════════════════════════
validate_staging_coverage() {
  set +e
  local BUNDLE_DIR="${1:-}"
  if [[ -z "$BUNDLE_DIR" ]]; then
    # Auto-detect: this script lives in flow-kit-bundle/lib/, bundle root is ..
    local SELF_DIR
    SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BUNDLE_DIR="$(cd "$SELF_DIR/.." && pwd)"
  fi
  local ERRORS=0
  local WARNINGS=0

  echo "🔍 package-flow-kit.sh --validate"
  echo "   校验 flow-kit-bundle/ 目录结构与 Part A~G staging 指令覆盖范围..."
  echo ""

  if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ 错误: flow-kit-bundle/ 目录不存在: $BUNDLE_DIR"
    exit 2
  fi

  local EXPECTED_FILE_LIST
  EXPECTED_FILE_LIST=$(mktemp)
  trap 'rm -f "$EXPECTED_FILE_LIST"' EXIT

  echo "   解析 Part A (flow-kit 核心)..."
  command find "$BUNDLE_DIR/flow-kit" -type f 2>/dev/null >> "$EXPECTED_FILE_LIST"

  echo "   解析 Part B (flow-* skills)..."
  for skill_dir in "$BUNDLE_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_dir="${skill_dir%/}"
    local skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] && echo "$skill_file" >> "$EXPECTED_FILE_LIST"
  done

  echo "   解析 Part C (Hook 系统)..."
  for pattern in "$BUNDLE_DIR/hooks/stop/"*.sh "$BUNDLE_DIR/hooks/stop/lib/"*.sh "$BUNDLE_DIR/hooks/session-start/"*.sh "$BUNDLE_DIR/hooks/pre-tool-use/"*.sh; do
    [ -f "$pattern" ] && echo "$pattern" >> "$EXPECTED_FILE_LIST"
  done

  echo "   解析 Part D (配置模板)..."
  for config_file in "$BUNDLE_DIR/hooks/config/"*; do
    [ -f "$config_file" ] && echo "$config_file" >> "$EXPECTED_FILE_LIST"
  done

  echo "   解析 Part E (安装脚本 + lib + specs + test)..."
  [ -f "$BUNDLE_DIR/install.sh" ] && echo "$BUNDLE_DIR/install.sh" >> "$EXPECTED_FILE_LIST"
  for lib_file in "$BUNDLE_DIR/lib/"*.sh; do
    [ -f "$lib_file" ] && echo "$lib_file" >> "$EXPECTED_FILE_LIST"
  done
  for spec_file in "$BUNDLE_DIR/specs-template/"*; do
    [ -f "$spec_file" ] && echo "$spec_file" >> "$EXPECTED_FILE_LIST"
  done
  while IFS= read -r -d '' test_file; do
    echo "$test_file" >> "$EXPECTED_FILE_LIST"
  done < <(command find "$BUNDLE_DIR/test" -type f ! -path '*/.git/*' -print0 2>/dev/null)

  echo "   解析 Part F (brooks-lint 插件)..."
  command find "$BUNDLE_DIR/brooks-lint" -type f 2>/dev/null >> "$EXPECTED_FILE_LIST"

  echo "   解析 Part G (brooks-tools)..."
  local tools_dir="$BUNDLE_DIR/brooks-lint/plugin/scripts"
  for tgz in "$tools_dir"/*.tgz; do
    [ -f "$tgz" ] && echo "$tgz" >> "$EXPECTED_FILE_LIST"
  done

  local EXPECTED
  EXPECTED=$(sort -u "$EXPECTED_FILE_LIST")
  # comm 要求输入已排序，原地排序 EXPECTED_FILE_LIST
  sort -uo "$EXPECTED_FILE_LIST" "$EXPECTED_FILE_LIST"

  echo "   扫描 flow-kit-bundle/ 实际文件..."

  echo ""
  echo "   ── 对账结果 ──"
  echo ""

  # 用 comm 做确定性集合差异（替代 grep -qF 的非确定性匹配）
  local ACTUAL_FILE_LIST
  ACTUAL_FILE_LIST=$(mktemp)
  command find "$BUNDLE_DIR" -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    2>/dev/null | sort > "$ACTUAL_FILE_LIST"

  local ACTUAL
  ACTUAL=$(cat "$ACTUAL_FILE_LIST")

  # 期望但源缺失（EXPECTED - ACTUAL）
  local MISSING_IN_SOURCE
  MISSING_IN_SOURCE=$(comm -23 "$EXPECTED_FILE_LIST" "$ACTUAL_FILE_LIST")
  while IFS= read -r expected_file; do
    [ -z "$expected_file" ] && continue
    echo "   ⚠️  WARNING: 期望但源缺失 — $expected_file"
    WARNINGS=$((WARNINGS + 1))
  done <<< "$MISSING_IN_SOURCE"

  # 已知非打包文件（bundle 根级别元数据，不被 Part A~G 显式覆盖）
  # OPENCODE-INSTALL.md 由 Part E L266-267 条件 cp（if [-f]），validate 解析不到
  local KNOWN_SKIP="\.git\|node_modules\|\.DS_Store\|/\.gitignore$\|/\.flow-kit-version$\|/README\.md$\|/FLOW-KIT-用户指南\.md$\|/MODULE_IDEAS\.md$\|/OPENCODE-INSTALL\.md$"

  # 漏配（ACTUAL - EXPECTED - KNOWN_SKIP）
  local NOT_COVERED
  NOT_COVERED=$(comm -13 "$EXPECTED_FILE_LIST" "$ACTUAL_FILE_LIST")
  while IFS= read -r actual_file; do
    [ -z "$actual_file" ] && continue
    if echo "$actual_file" | grep -q "$KNOWN_SKIP"; then
      continue
    fi
    echo "   🔴 ERROR: 漏配！实际文件未被任何 Part 覆盖 — $actual_file"
    ERRORS=$((ERRORS + 1))
  done <<< "$NOT_COVERED"

  rm -f "$ACTUAL_FILE_LIST"

  echo ""
  echo "   ── 校验汇总 ──"
  echo "   期望覆盖: $(echo "$EXPECTED" | grep -c .) 项"
  echo "   实际文件: $(echo "$ACTUAL" | grep -c .) 项"
  echo "   🔴 漏配 (ERROR): $ERRORS"
  echo "   ⚠️  源缺失 (WARNING): $WARNINGS"

  if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "   ❌ 校验失败：发现 $ERRORS 个漏配项。"
    echo "      请更新 package-flow-kit.sh Part A~G 覆盖范围后重跑。"
    exit 1
  elif [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "   ⚠️  校验通过（有 $WARNINGS 个 WARNING，非阻塞）"
    exit 0
  else
    echo ""
    echo "   ✅ 校验通过：所有文件均被 Part A~G 覆盖。"
    exit 0
  fi
}
