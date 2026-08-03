# lib/install_skills.sh — flow-* 技能包装器安装
# shellcheck shell=bash
# 由 install.sh source，不可独立执行
# 依赖：lib/paths.sh（resolve_paths 已设置 USER_SKILLS_DIR, PLATFORM）
#
# 平台行为：
#   claude   → 安装到 ~/.claude/skills/flow-*
#   opencode → 安装到 ~/.config/opencode/skills/flow-*（opencode 原生路径）
# 注：opencode 也原生读 ~/.claude/skills，但显式装到平台规范路径更清晰

install_skills() {
  echo ""
  echo "═══ 安装 flow-* 技能包装器 [${PLATFORM}] ═══"

  local dst_base="$USER_SKILLS_DIR"
  local count=0

  for skill_dir in "$SCRIPT_DIR/skills/flow-"*/ "$SCRIPT_DIR/skills/flow/"; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    install_file "$skill_dir/SKILL.md" "$dst_base/${skill_name}/SKILL.md"
    ((count++)) || true
  done
  echo "   ✅ ${count} 个技能已安装到 $dst_base"
}
