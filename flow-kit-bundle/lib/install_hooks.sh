# lib/install_hooks.sh — Stop Hook + SessionStart 安装 + .specs 模板
# shellcheck shell=bash
# 由 install.sh source，不可独立执行
# 依赖：lib/paths.sh（PLATFORM, USER_HOOKS_DIR, PROJECT_DIR_NAME, HOOKS_PROJECT_VAR_REF,
#                     HOOKS_USER_VAR_REF, USER_HOOKS_DIR, settings_file_for）
# 自加载：被直接 source 时（测试 / 独立调用）install_hooks() 内部自动 source paths.sh
# 环境变量 FLOW_KIT_PLATFORM 可覆盖平台（claude|opencode · 非法值→claude 默认）
#
# 平台行为：
#   claude
#     - hooks 装到 ~/.claude/hooks (user) 或 $project/.claude/hooks (project)
#     - settings 写 ~/.claude/settings.json (user) 或 $project/.claude/settings.local.json
#     - hook 命令引用 ${CLAUDE_PROJECT_DIR} (Claude Code 原生 env)
#   opencode
#     - hooks 装到 ~/.config/opencode/hooks (user) 或 $project/.opencode/hooks (project)
#     - settings 写 ~/.claude/settings.json (user) 或 $project/.claude/settings.local.json
#       ↑ opencode 不读 settings.json，但 opencode-claude-hooks 桥接插件读
#         保持 Claude 格式让用户安装桥接插件即可启用
#     - hook 命令仍引用 ${CLAUDE_PROJECT_DIR}（桥接插件会注入此 env）

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
# deploy_pre_commit — pre-commit symlink 部署（archive-commit-gate）
# 必须定义在 install_hooks() 之前：install_hooks() 体内调用此函数
# 依赖 $project / $hook_dst（bash 动态作用域：从 install_hooks() 内调用时可见）
# ═══════════════════════════════════════════════════════════════════════
deploy_pre_commit() {
  [[ -d "${project}/.git" ]] || return 0

  local target="${project}/.git/hooks/pre-commit"
  mkdir -p "${project}/.git/hooks" "$hook_dst/pre-commit"
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"

  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ "${FLOW_KIT_YES:-0}" == "1" ]]; then
      echo "   [archive-commit-gate] existing pre-commit: $target, skipped"
      return 0
    fi
    local ans
    read -p "flow-kit: 既有 pre-commit 存在，覆盖？(y/N) " ans
    [[ "$ans" == "y" ]] || { echo "   skipped"; return 0; }
    rm -f "$target"
  fi

  ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"
  echo "   ✅ pre-commit symlink → $target"
}

# ═══════════════════════════════════════════════════════════════════════
# install_hooks — Stop Hook + SessionStart → user or project scope
# ═══════════════════════════════════════════════════════════════════════
install_hooks() {
  local project="$1"
  local scope="${2:-project}"   # "user" or "project"

  # ── 依赖自加载 ──────────────────────────────────────────────
  # install.sh 调用: resolve_paths 已在 install.sh:153 执行 → 此块 no-op
  # 直接 source（测试/独立）: paths.sh 未加载 → 自动加载
  if [ -z "${PROJECT_DIR_NAME:-}" ] && [ -n "${SCRIPT_DIR:-}" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/lib/paths.sh"
    case "${FLOW_KIT_PLATFORM:-claude}" in
      claude|opencode) resolve_paths "${FLOW_KIT_PLATFORM:-claude}" ;;
      *) resolve_paths claude ;;
    esac
  fi

  echo ""
  echo "═══ 安装 Hook 系统 [${PLATFORM}/${scope}] ═══"

  local hook_dst          # 实际安装目录（绝对路径）
  local settings_hook_path  # settings.json 命令字符串中的路径引用

  if [ "$scope" = "user" ]; then
    hook_dst="$USER_HOOKS_DIR"
    # ~/.claude/hooks → ${HOME}/.claude/hooks
    # ~/.config/opencode/hooks → ${HOME}/.config/opencode/hooks
    settings_hook_path="${HOOKS_USER_VAR_REF}${USER_HOOKS_DIR#"$HOME"}"
  else
    if [ ! -d "$project" ]; then
      echo "   ❌ 项目目录不存在: $project"
      return 1
    fi
    hook_dst="${project}/${PROJECT_DIR_NAME}/hooks"
    # $project/.claude/hooks → ${CLAUDE_PROJECT_DIR}/.claude/hooks
    # $project/.opencode/hooks → ${CLAUDE_PROJECT_DIR}/.opencode/hooks
    settings_hook_path="${HOOKS_PROJECT_VAR_REF}/${PROJECT_DIR_NAME}/hooks"
  fi

  echo "   安装到: $hook_dst"
  echo "   settings.json 命令路径: ${settings_hook_path}/stop/00-gate.sh"

  # Stop hook 模块（来源: common.sh::HOOK_MODULE_NAMES — 单一来源）
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/hooks/stop/lib/common.sh" 2>/dev/null || {
    echo "   ⚠️  common.sh 不可用，使用回退列表"
    HOOK_MODULE_NAMES=(00-gate 01-transcript-parse 20-claude-md 21-memory 22-git 23-quality 24-session 25-project 26-workflow 27-interactive-ui-check 28-weak-model-compliance 29-independent-review 30-ai-analyze 31-auto-advance 32-fallback-guard 33-flow-active-integrity 99-report)
  }
  for script in "${HOOK_MODULE_NAMES[@]}"; do
    install_file "$SCRIPT_DIR/hooks/stop/${script}.sh" "$hook_dst/stop/${script}.sh"
    chmod +x "$hook_dst/stop/${script}.sh" 2>/dev/null || true
  done
  unset HOOK_MODULE_NAMES

  # Stop hook 库文件（通配符自动包含全部 .sh，防止新增 lib 时漏加）
  for lib_sh in "$SCRIPT_DIR/hooks/stop/lib/"*.sh; do
    install_file "$lib_sh" "$hook_dst/stop/lib/$(basename "$lib_sh")"
  done

  # SessionStart hooks
  for script in flow-kit-resume stop-report-reminder; do
    install_file "$SCRIPT_DIR/hooks/session-start/${script}.sh" "$hook_dst/session-start/${script}.sh"
    chmod +x "$hook_dst/session-start/${script}.sh" 2>/dev/null || true
  done

  # PreToolUse hooks + lib 子库（独立 review gate · 硬拦截 commit/PR/阶段切换）
  # 部署 pre-tool-use/ 下所有 .sh 文件（主 hook + 拆分后的 gate-helpers*.sh 子库）
  mkdir -p "$hook_dst/pre-tool-use"
  while IFS= read -r ptu_script; do
    local ptu_base
    ptu_base=$(basename "$ptu_script")
    install_file "$ptu_script" "$hook_dst/pre-tool-use/${ptu_base}"
    chmod +x "$hook_dst/pre-tool-use/${ptu_base}" 2>/dev/null || true
  done < <(ls "$SCRIPT_DIR/hooks/pre-tool-use"/*.sh 2>/dev/null)

  deploy_pre_commit

  # 配置文件（项目级 stop-hook.json 开关）
  install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "${project}/${PROJECT_DIR_NAME}/stop-hook.json"

  # ═══ 自动写入 hook 接线 ═══
  local settings_target
  settings_target=$(settings_file_for "$scope" "$project")
  echo ""
  echo "   settings 文件: $settings_target"

  # ── 通用接线函数：往 settings_target 写入一个 hook ──────────────
  # 参数: event  matcher  cmd  label
  # -------------------------------------------------------------------
  _install_hook_wiring() {
    local event="$1"
    local matcher="$2"
    local cmd="$3"
    local label="$4"

    if [ "${DRY_RUN:-false}" = true ]; then
      echo "   [DRY-RUN] 写入 ${event} hook (${label}) 到 ${settings_target}: command=${cmd}"
      return
    fi

    if [ -f "$settings_target" ] && command -v jq &>/dev/null; then
      # 已存在 → 检查是否已有此 hook，没有则追加
      if jq -e --arg cmd "$cmd" \
          --arg event "$event" \
          '(.hooks[$event] // []) | any(.[].hooks[].command; . == $cmd)' \
          "$settings_target" >/dev/null 2>&1; then
        echo "   ✅ ${event} hook (${label}) 已存在于 ${settings_target}，跳过"
        return
      fi
      local merged
      merged=$(jq --arg event "$event" \
                  --arg matcher "$matcher" \
                  --arg cmd "$cmd" '
        .hooks[$event] = (.hooks[$event] // []) + [{
          "matcher": $matcher,
          "hooks": [{
            "type": "command",
            "command": $cmd
          }]
        }]
      ' "$settings_target" 2>/dev/null)
      if [ -n "$merged" ]; then
        echo "$merged" > "$settings_target"
        echo "   ✅ ${settings_target} 已追加 ${event} hook (${label})"
      else
        echo "   ⚠️  ${settings_target} ${event} (${label}) 合并失败，请手动检查"
      fi
    else
      # 新建
      mkdir -p "$(dirname "$settings_target")"
      jq -n --arg event "$event" \
            --arg matcher "$matcher" \
            --arg cmd "$cmd" '
        { hooks: { ($event): [{
          "matcher": $matcher,
          "hooks": [{
            "type": "command",
            "command": $cmd
          }]
        }] } }
      ' > "$settings_target" 2>/dev/null
      echo "   ✅ ${settings_target} 已写入 ${event} hook (${label})"
  fi
}


  # ── Stop hook ──────────────────────────────────────────────────
  local stop_cmd="bash \"${settings_hook_path}/stop/00-gate.sh\""
  _install_hook_wiring "Stop" "" "$stop_cmd" "00-gate"

  # ── PreToolUse independent-review-gate ─────────────────────────
  local gate_cmd="bash \"${settings_hook_path}/pre-tool-use/independent-review-gate.sh\""
  _install_hook_wiring "PreToolUse" "Bash|Write|Edit" "$gate_cmd" "independent-review-gate"

  # ── PreToolUse auto-checkpoint ─────────────────────────────────
  local ck_cmd="bash \"${settings_hook_path}/pre-tool-use/auto-checkpoint.sh\""
  _install_hook_wiring "PreToolUse" "Write|Edit" "$ck_cmd" "auto-checkpoint"

  # ── PreToolUse runtime-edit-guard (L-015) ─────────────────────
  # 文件部署已在 PreToolUse 目录循环中完成（L100-110），此处仅写 settings.json matcher
  local reg_cmd="bash \"${settings_hook_path}/pre-tool-use/runtime-edit-guard.sh\""
  _install_hook_wiring "PreToolUse" "Write|Edit" "$reg_cmd" "runtime-edit-guard"

  # SessionStart hooks 由全局 ~/.claude/settings.json 管理（--global 安装时已写入），
  # 此处不再重复写入，避免同一 hook 触发两次。
  echo "   ℹ️  SessionStart hooks 由全局配置管理，无需项目级重复接线"

  # ── opencode 桥接提示 ──────────────────────────────────────────
  if [ "$PLATFORM" = "opencode" ]; then
    echo ""
    echo "   ⚠️  [opencode] settings.json 桥接提示:"
    echo "       opencode 不原生读 ~/.claude/settings.json，hooks 默认不触发。"
    echo "       启用方式（任选其一）:"
    echo "         (A) npm install -g opencode-claude-hooks  # 自动桥接 .claude/settings.json"
    echo "         (B) 在 ~/.config/opencode/opencode.json plugin 数组加入 'opencode-claude-hooks'"
    echo "       详见 OPENCODE-INSTALL.md"
  fi
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
