# lib/paths.sh — 平台路径抽象层（claude | opencode | dsh）
# shellcheck shell=bash
# 由 install.sh 在所有 install_*.sh 之前 source，不可独立执行
#
# 设计原则：
#   - 单一来源：所有 ~/.claude/*、~/.config/opencode/*、~/.dsh/* 路径在此文件解析
#   - 平台分支：PLATFORM=claude 走 ~/.claude/，PLATFORM=opencode 走 ~/.config/opencode/，
#     PLATFORM=dsh 走 ~/.dsh/（dsh 平台 install.sh 不落盘，仅保证路径抽象完整）
#   - 跨平台兼容：opencode 原生读取 ~/.claude/skills 但本安装器显式安装到平台规范路径
#   - 项目级路径仍按平台约定（.claude/ 或 .opencode/）
#
# 暴露变量（global scope，source 后即可使用）：
#   PLATFORM                   — 当前目标平台 (claude | opencode | dsh)
#   PLATFORM_CONFIG_DIR        — 用户级配置根 ($HOME/.claude 或 $HOME/.config/opencode)
#   FLOW_KIT_HOME              — flow-kit 核心安装目录
#   USER_SKILLS_DIR            — 用户级 skills 根目录
#   USER_HOOKS_DIR             — 用户级 hooks 根目录（user scope）
#   USER_SETTINGS_FILE         — 用户级 settings 文件路径
#   USER_SETTINGS_PROJECT_VAR  — settings 文件中用于项目路径占位的 env 变量名
#   PROJECT_DIR_NAME           — 项目内配置目录名 (.claude / .opencode / .flow-kit)
#   USER_PLUGINS_DIR           — 用户级 plugins 目录（仅 claude；opencode 为空）
#   USER_TOOLS_DIR             — 用户级 brooks-lint npm 工具目录（claude: ~/.claude/tools/brooks-lint）
#   USER_AGENTS_MD             — 用户级 AGENTS.md 路径（仅 opencode 用；claude 不写）
#   HOOKS_PROJECT_VAR_REF      — settings.json 中使用的项目目录变量引用
#                                claude: ${CLAUDE_PROJECT_DIR}
#                                opencode: ${OPENCODE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}
#   HOOKS_USER_VAR_REF         — settings.json 中使用的 user 目录变量引用
#                                claude: ${HOME}
#                                opencode: ${HOME}（opencode 无原生 user hooks，但仍走桥接）

# ── resolve_paths PLATFORM ────────────────────────────────────────────
# 根据平台设置上述所有全局变量。PLATFORM 支持 "claude"、"opencode"、"dsh"。
# =======================================================================
resolve_paths() {
  local platform="${1:-claude}"
  case "$platform" in
    claude)
      PLATFORM="claude"
      PLATFORM_CONFIG_DIR="$HOME/.claude"
      FLOW_KIT_HOME="$HOME/.claude/flow-kit"
      USER_SKILLS_DIR="$HOME/.claude/skills"
      USER_HOOKS_DIR="$HOME/.claude/hooks"
      USER_SETTINGS_FILE="$HOME/.claude/settings.json"
      PROJECT_DIR_NAME=".claude"
      USER_PLUGINS_DIR="$HOME/.claude/plugins"
      USER_TOOLS_DIR="$HOME/.claude/tools/brooks-lint"
      USER_AGENTS_MD=""  # claude 不写 AGENTS.md（用 CLAUDE.md 但本安装器不维护）
      # settings.json 中 hook 命令的项目目录变量
      HOOKS_PROJECT_VAR_REF='${CLAUDE_PROJECT_DIR}'
      HOOKS_USER_VAR_REF='${HOME}'
      ;;
    opencode)
      PLATFORM="opencode"
      PLATFORM_CONFIG_DIR="$HOME/.config/opencode"
      FLOW_KIT_HOME="$HOME/.config/opencode/flow-kit"
      USER_SKILLS_DIR="$HOME/.config/opencode/skills"
      USER_HOOKS_DIR="$HOME/.config/opencode/hooks"
      USER_SETTINGS_FILE="$HOME/.claude/settings.json"
        # ↑ opencode 不读 settings.json，但 opencode-claude-hooks 桥接插件读
        #   保留 Claude 格式让用户安装桥接插件即可启用
      PROJECT_DIR_NAME=".opencode"
      USER_PLUGINS_DIR=""  # opencode 不使用此 Claude 概念
      USER_TOOLS_DIR="$HOME/.config/opencode/tools/brooks-lint"
      USER_AGENTS_MD="$HOME/.config/opencode/AGENTS.md"
      # opencode 无 $OPENCODE_PROJECT_DIR；桥接插件注入 $CLAUDE_PROJECT_DIR
      # settings.json 命令字符串保持 Claude 兼容（桥接插件会 export CLAUDE_PROJECT_DIR）
      HOOKS_PROJECT_VAR_REF='${CLAUDE_PROJECT_DIR}'
      HOOKS_USER_VAR_REF='${HOME}'
      ;;
    dsh)
      PLATFORM="dsh"
      PLATFORM_CONFIG_DIR="$HOME/.dsh"
      FLOW_KIT_HOME=""   # dsh 核心由 dsh-flow-kit 插件包提供，无独立 HOME 安装
      USER_SKILLS_DIR="$HOME/.dsh/skills"
      USER_HOOKS_DIR="$HOME/.dsh/hooks"
      USER_SETTINGS_FILE=""   # dsh 无 Claude settings.json 承载面
      PROJECT_DIR_NAME=".flow-kit"
      USER_PLUGINS_DIR=""
      USER_TOOLS_DIR=""
      USER_AGENTS_MD="$HOME/.dsh/AGENTS.md"
      # dsh hooks 由插件 hook-bridge 监听 dsh 事件触发；无 settings.json 变量占位
      HOOKS_PROJECT_VAR_REF='${FLOW_KIT_PROJECT_DIR:-${CWD:-$PWD}}'
      HOOKS_USER_VAR_REF='${HOME}'
      ;;
    *)
      echo "❌ resolve_paths: 未知平台 '$platform'（应为 claude | opencode | dsh）" >&2
      return 1
      ;;
  esac
  export PLATFORM
  export PLATFORM_CONFIG_DIR FLOW_KIT_HOME USER_SKILLS_DIR USER_HOOKS_DIR
  export USER_SETTINGS_FILE PROJECT_DIR_NAME USER_PLUGINS_DIR USER_TOOLS_DIR USER_AGENTS_MD
  export HOOKS_PROJECT_VAR_REF HOOKS_USER_VAR_REF
}

# ── project_dir_for PROJECT_PATH ──────────────────────────────────────
# 返回项目级配置目录的绝对路径（$PROJECT/.claude 或 $PROJECT/.opencode）
# =======================================================================
project_dir_for() {
  local project="$1"
  echo "${project}/${PROJECT_DIR_NAME}"
}

# ── settings_file_for SCOPE PROJECT_PATH ──────────────────────────────
# 返回 settings 文件路径
#   user scope → $USER_SETTINGS_FILE
#   project scope → $PROJECT/$PROJECT_DIR_NAME/settings.local.json
# 注：opencode 仍写 .claude/settings.local.json，因桥接插件读此位置
# =======================================================================
settings_file_for() {
  local scope="$1"
  local project="$2"
  if [ "$scope" = "user" ]; then
    echo "$USER_SETTINGS_FILE"
  else
    echo "${project}/.claude/settings.local.json"
  fi
}
