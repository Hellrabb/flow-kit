# lib/install_agents_md.sh — opencode AGENTS.md flow-kit 注入
# shellcheck shell=bash
# 由 install.sh source，不可独立执行
# 依赖：lib/paths.sh（PLATFORM, USER_AGENTS_MD, FLOW_KIT_HOME, USER_SKILLS_DIR）
#
# 仅 opencode 平台调用：往 ~/.config/opencode/AGENTS.md 追加 flow-kit 用法说明
# claude 平台不调用（claude 用 CLAUDE.md 但本安装器不维护该文件）

install_agents_md_injection() {
  if [ "$PLATFORM" != "opencode" ]; then
    return 0
  fi

  echo ""
  echo "═══ 注入 AGENTS.md flow-kit 说明 [opencode] ═══"

  local agents_md="$USER_AGENTS_MD"
  local marker_begin="<!-- flow-kit-injection:begin -->"
  local marker_end="<!-- flow-kit-injection:end -->"
  local flow_kit_skills=""
  local brooks_skills=""
  local d
  for d in "$USER_SKILLS_DIR"/flow-*/ "$USER_SKILLS_DIR"/flow/; do
    [ -d "$d" ] || continue
    flow_kit_skills+="${flow_kit_skills:+ }$(basename "$d")"
  done
  for d in "$USER_SKILLS_DIR"/brooks-*/; do
    [ -d "$d" ] || continue
    brooks_skills+="${brooks_skills:+ }$(basename "$d")"
  done

  local block
  block=$(cat <<AGENTSEOF
${marker_begin}
## flow-kit 工作流引擎（已安装）

flow-kit 是一套基于阶段门控的 AI 协作工作流引擎。核心引擎安装位置：
- 引擎：\`${FLOW_KIT_HOME}/GO.md\`
- skills 目录：\`${USER_SKILLS_DIR}/\`

### 可用 skills

**flow-* 工作流 skills**：${flow_kit_skills}

调用方式：在对话中直接说 "用 /flow-go 启动" 或 "/flow-requirement 创建需求"。
skill 内部会委托到 \`${FLOW_KIT_HOME}/\` 下的 prompts/templates 完成实际工作。

**brooks-* 代码审查 skills**：${brooks_skills}

调用方式："/brooks-review 审查 PR"、"brooks-health 项目健康检查" 等。

### Hook 桥接说明

opencode 不原生读 \`~/.claude/settings.json\` 的 Stop/PreToolUse hooks。
要启用 flow-kit 的 stop-hook 后处理（自动 stop-report、git 检查、QA 审查等），
需安装桥接插件（任选其一）：

- \`npm install -g opencode-claude-hooks\` 后在 \`opencode.json\` 的 \`plugin\` 数组加入 \`"opencode-claude-hooks"\`
- 或克隆 https://github.com/romain325/opencode-hooks-plugin 到 \`~/.config/opencode/plugin/\`

桥接插件会自动读取 \`~/.claude/settings.json\` 中已注册的 hooks 并在对应生命周期事件触发。
${marker_end}
AGENTSEOF
)

  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] 追加 flow-kit 块到 $agents_md"
    return
  fi

  mkdir -p "$(dirname "$agents_md")"

  if [ ! -f "$agents_md" ]; then
    echo "$block" > "$agents_md"
    echo "   ✅ 已创建 $agents_md 并写入 flow-kit 说明"
    return
  fi

  # 已有 marker → 替换；否则追加
  if grep -qF "$marker_begin" "$agents_md" 2>/dev/null; then
    # 用 awk 替换 marker 之间的内容
    local tmp="${agents_md}.tmp.$$"
    awk -v begin="$marker_begin" -v end="$marker_end" -v block="$block" '
      $0 == begin { in_block=1; print block; next }
      $0 == end   { in_block=0; next }
      !in_block   { print }
    ' "$agents_md" > "$tmp" && mv "$tmp" "$agents_md"
    echo "   ✅ $agents_md 中 flow-kit 块已更新"
  else
    printf '\n\n%s\n' "$block" >> "$agents_md"
    echo "   ✅ $agents_md 已追加 flow-kit 说明"
  fi
}
