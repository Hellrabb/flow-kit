# lib/install_hooks.sh — Stop Hook + SessionStart 安装 + .specs 模板
# 由 install.sh source，不可独立执行

# ── 辅助函数 ──────────────────────────────────────────────────────────
install_file() {
  local src="$1" dst="$2"
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] cp $src -> $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "   ✅ $dst"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# install_hooks — Stop Hook + SessionStart → user (~/.claude/) or project
# ═══════════════════════════════════════════════════════════════════════
install_hooks() {
  local project="$1"
  local scope="${2:-project}"   # "user" or "project"
  echo ""
  echo "═══ 安装 Hook 系统（scope: ${scope}）═══"

  local hook_dst
  local settings_hook_path   # path used in settings.json command

  if [ "$scope" = "user" ]; then
    hook_dst="$HOME/.claude/hooks"
    settings_hook_path="\${HOME}/.claude/hooks"
  else
    if [ ! -d "$project" ]; then
      echo "   ❌ 项目目录不存在: $project"
      return 1
    fi
    hook_dst="$project/.claude/hooks"
    settings_hook_path="\${CLAUDE_PROJECT_DIR}/.claude/hooks"
  fi

  echo "   安装到: $hook_dst"

  # Stop hook 模块（来源: common.sh::HOOK_MODULE_NAMES — 单一来源）
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/hooks/stop/lib/common.sh" 2>/dev/null || {
    echo "   ⚠️  common.sh 不可用，使用回退列表"
    HOOK_MODULE_NAMES=(00-gate 01-transcript-parse 20-claude-md 21-memory 22-git 23-quality 24-session 25-project 26-workflow 27-interactive-ui-check 28-weak-model-compliance 29-independent-review 30-ai-analyze 99-report)
  }
  for script in "${HOOK_MODULE_NAMES[@]}"; do
    install_file "$SCRIPT_DIR/hooks/stop/${script}.sh" "$hook_dst/stop/${script}.sh"
    chmod +x "$hook_dst/stop/${script}.sh" 2>/dev/null || true
  done
  unset HOOK_MODULE_NAMES

  # Stop hook 库文件
  for lib in common flow-kit-artifacts transcript-parser; do
    install_file "$SCRIPT_DIR/hooks/stop/lib/${lib}.sh" "$hook_dst/stop/lib/${lib}.sh"
  done

  # SessionStart hooks
  for script in flow-kit-resume stop-report-reminder; do
    install_file "$SCRIPT_DIR/hooks/session-start/${script}.sh" "$hook_dst/session-start/${script}.sh"
    chmod +x "$hook_dst/session-start/${script}.sh" 2>/dev/null || true
  done

  # PreToolUse hooks（独立 review gate · 硬拦截 commit/PR/阶段切换）
  if [ -f "$SCRIPT_DIR/hooks/pre-tool-use/independent-review-gate.sh" ]; then
    install_file "$SCRIPT_DIR/hooks/pre-tool-use/independent-review-gate.sh" "$hook_dst/pre-tool-use/independent-review-gate.sh"
    chmod +x "$hook_dst/pre-tool-use/independent-review-gate.sh" 2>/dev/null || true
  fi

  # 配置文件
  install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "$project/.claude/stop-hook.json"

  # ═══ 自动写入 Stop hook 接线 ═══
  # user scope → 写全局 ~/.claude/settings.json（所有项目共用）
  # project scope → 写项目 .claude/settings.local.json（仅当前项目）
  local settings_target
  if [ "$scope" = "user" ]; then
    settings_target="$HOME/.claude/settings.json"
  else
    settings_target="$project/.claude/settings.local.json"
  fi
  local stop_cmd="bash \"${settings_hook_path}/stop/00-gate.sh\""

  echo ""
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] 写入 Stop hook 到 ${settings_target}: command=${stop_cmd}"
  elif [ -f "$settings_target" ] && command -v jq &>/dev/null; then
    # 已存在 → 检查是否已有 flow-kit stop hook，没有则追加
    if jq -e --arg cmd "$stop_cmd" '(.hooks.Stop // []) | any(.[].hooks[].command; . == $cmd)' "$settings_target" >/dev/null 2>&1; then
      echo "   ✅ Stop hook 已存在于 ${settings_target}，跳过"
    else
      local merged
      merged=$(jq --arg cmd "$stop_cmd" '
        .hooks.Stop = (.hooks.Stop // []) + [{
          "matcher": "",
          "hooks": [{
            "type": "command",
            "command": $cmd
          }]
        }]
      ' "$settings_target" 2>/dev/null)
      if [ -n "$merged" ]; then
        echo "$merged" > "$settings_target"
        echo "   ✅ ${settings_target} 已追加 Stop hook 接线"
      else
        echo "   ⚠️  ${settings_target} 合并失败，请手动检查"
      fi
    fi
  else
    # 新建
    mkdir -p "$(dirname "$settings_target")"
    jq -n --arg cmd "$stop_cmd" '
      { hooks: { Stop: [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": $cmd
        }]
      }] } }
    ' > "$settings_target" 2>/dev/null
    echo "   ✅ ${settings_target} 已写入 Stop hook 接线"
  fi

  # ═══ 自动写入 PreToolUse hook 接线（独立 review gate）═══
  local pre_cmd="bash \"${settings_hook_path}/pre-tool-use/independent-review-gate.sh\""
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] 写入 PreToolUse hook 到 ${settings_target}: command=${pre_cmd}"
  elif [ -f "$settings_target" ] && command -v jq &>/dev/null; then
    if jq -e --arg cmd "$pre_cmd" '(.hooks.PreToolUse // []) | any(.[].hooks[].command; . == $cmd)' "$settings_target" >/dev/null 2>&1; then
      echo "   ✅ PreToolUse hook 已存在于 ${settings_target}，跳过"
    else
      local merged_pre
      merged_pre=$(jq --arg cmd "$pre_cmd" '
        .hooks.PreToolUse = (.hooks.PreToolUse // []) + [{
          "matcher": "Bash|Write|Edit",
          "hooks": [{
            "type": "command",
            "command": $cmd
          }]
        }]
      ' "$settings_target" 2>/dev/null)
      if [ -n "$merged_pre" ]; then
        echo "$merged_pre" > "$settings_target"
        echo "   ✅ ${settings_target} 已追加 PreToolUse hook 接线"
      else
        echo "   ⚠️  ${settings_target} PreToolUse 合并失败，请手动检查"
      fi
    fi
  else
    jq -n --arg cmd "$pre_cmd" '
      { hooks: { PreToolUse: [{
        "matcher": "Bash|Write|Edit",
        "hooks": [{
          "type": "command",
          "command": $cmd
        }]
      }] } }
    ' > "$settings_target" 2>/dev/null
    echo "   ✅ ${settings_target} 已写入 PreToolUse hook 接线"
  fi

  # SessionStart hooks 由全局 ~/.claude/settings.json 管理（--global 安装时已写入），
  # 此处不再重复写入，避免同一 hook 触发两次。
  echo "   ℹ️  SessionStart hooks 由全局配置管理，无需项目级重复接线"
}

# ═══════════════════════════════════════════════════════════════════════
# install_specs_template — .specs/STATE.md 模板
# ═══════════════════════════════════════════════════════════════════════
install_specs_template() {
  local project="$1"
  echo ""
  echo "═══ 安装 .specs 模板 ═══"

  if [ ! -d "$project/.specs" ]; then
    install_file "$SCRIPT_DIR/specs-template/STATE.md" "$project/.specs/STATE.md"
  else
    echo "   ⚠️  .specs/ 已存在，跳过 STATE.md 模板（避免覆盖）"
  fi
}
