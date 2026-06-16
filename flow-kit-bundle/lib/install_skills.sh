# lib/install_skills.sh — flow-* 技能包装器安装
# 由 install.sh source，不可独立执行

install_skills() {
  echo ""
  echo "═══ 安装 flow-* 技能包装器 ═══"

  local dst_base="$HOME/.claude/skills"
  local count=0

  for skill_dir in "$SCRIPT_DIR/skills/flow-"*/ "$SCRIPT_DIR/skills/flow/"; do
    [ -d "$skill_dir" ] || continue
    local skill_name=$(basename "$skill_dir")
    install_file "$skill_dir/SKILL.md" "$dst_base/${skill_name}/SKILL.md"
    ((count++)) || true
  done
  echo "   ✅ ${count} 个技能已安装"
}
