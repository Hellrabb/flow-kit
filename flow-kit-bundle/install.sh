#!/bin/bash
# ============================================================================
# flow-kit 安装脚本
# 用法: ./install.sh [--global|--project <path>] [--no-hooks] [--no-skills] [--hooks-only]
# ============================================================================
set -euo pipefail

MODE=""
TARGET_PROJECT=""
NO_HOOKS=false
NO_SKILLS=false
NO_BROOKS=false
HOOKS_ONLY=false
HOOK_SCOPE="project"
REINSTALL=false
BROOKS_SRC=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$HOME/.claude/.flow-kit-version"
BUNDLE_VERSION_FILE="$SCRIPT_DIR/.flow-kit-version"

usage() {
  cat << EOF
用法: $0 [选项]

选项:
  --global              全局安装（~/.claude/flow-kit + ~/.claude/skills/flow-* + brooks-lint）
  --update              智能更新（版本比对 · bundle 版本 > 已装版本才执行）
  --reinstall           彻底重装（先 rm -rf 既有安装 → 再全新 --global）
  --project <path>      安装到指定项目（hooks + settings.json + .specs 模板）
  --user                安装 hooks 到用户目录 ~/.claude/（全局生效，所有项目共用）
  --no-hooks            跳过 stop hook 安装
  --no-skills           跳过 skills 安装
  --no-brooks           跳过 brooks-lint 安装
  --hooks-only          仅安装 hooks（需配合 --project）
  --dry-run             仅打印将要执行的操作，不实际执行

示例:
  $0 --global                              # 全局安装全部组件
  $0 --update                              # 智能更新（仅当 bundle 更新）
  $0 --reinstall                           # 彻底重装
  $0 --project /path/to/myproject          # 项目级安装
  $0 --global --no-hooks                   # 仅全局 flow-kit + skills + brooks-lint，不装 hooks
  $0 --project . --hooks-only              # 仅装 hooks 到当前项目
  $0 --global --user                       # 全局安装 + hooks 用户目录（所有项目生效）
EOF
  exit 0
}

# ── 解析参数 ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)      MODE="global"; shift ;;
    --project)     MODE="project"; TARGET_PROJECT="$2"; shift 2 ;;
    --no-hooks)    NO_HOOKS=true; shift ;;
    --no-skills)   NO_SKILLS=true; shift ;;
    --no-brooks)   NO_BROOKS=true; shift ;;
    --hooks-only)  HOOKS_ONLY=true; shift ;;
    --update)      MODE="update"; shift ;;
    --reinstall)   REINSTALL=true; MODE="global"; shift ;;
    --user)        HOOK_SCOPE="user"; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --brooks-src)  BROOKS_SRC="$2"; shift ;;
    -h|--help)     usage ;;
    *) echo "未知选项: $1"; usage ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "❌ 必须指定 --global 或 --project <path>"
  usage
fi

# ── --update: 版本比对 ───────────────────────────────────────────────
if [ "$MODE" = "update" ]; then
  BUNDLE_VER=""
  if [ -f "$BUNDLE_VERSION_FILE" ]; then
    BUNDLE_VER=$(cat "$BUNDLE_VERSION_FILE" 2>/dev/null)
  fi

  INSTALLED_VER=""
  if [ -f "$VERSION_FILE" ]; then
    INSTALLED_VER=$(cat "$VERSION_FILE" 2>/dev/null)
  fi

  if [ -n "$INSTALLED_VER" ] && [ -n "$BUNDLE_VER" ]; then
    if [ "$BUNDLE_VER" = "$INSTALLED_VER" ]; then
      echo "✅ flow-kit 已是最新版本 (${INSTALLED_VER})，无需更新"
      exit 0
    fi
    if [ "$BUNDLE_VER" \< "$INSTALLED_VER" ] || [ "$BUNDLE_VER" = "$INSTALLED_VER" ]; then
      echo "⚠️  bundle 版本 (${BUNDLE_VER}) ≤ 已安装版本 (${INSTALLED_VER})，跳过更新"
      echo "   如需强制安装，请使用 --reinstall"
      exit 0
    fi
    echo "🔧 更新 flow-kit: ${INSTALLED_VER} → ${BUNDLE_VER}"
  else
    echo "🔧 首次安装 flow-kit (bundle ${BUNDLE_VER:-未知版本})"
  fi
  MODE="global"
fi

# ── --reinstall: 清空重装 ─────────────────────────────────────────────
if [ "$REINSTALL" = true ]; then
  echo "🧹 彻底重装：清理既有安装..."
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] rm -rf ~/.claude/flow-kit ~/.claude/skills/flow-* ~/.claude/plugins/cache/brooks-lint-marketplace ~/.claude/plugins/marketplaces/brooks-lint-marketplace + jq del from installed_plugins.json + known_marketplaces.json"
  else
    rm -rf "$HOME/.claude/flow-kit"
    rm -rf "$HOME/.claude/plugins/cache/brooks-lint-marketplace"
    rm -rf "$HOME/.claude/plugins/marketplaces/brooks-lint-marketplace"
    rm -f "$HOME/.claude/commands"/brooks-*.md
    rm -f "$HOME/.claude/commands"/.brooks-lint-v*
    for d in "$HOME/.claude/skills"/flow-*; do
      [ -d "$d" ] && rm -rf "$d"
    done 2>/dev/null || true
    # 从 installed_plugins.json 中移除 brooks-lint 条目（幂等）
    INSTALL_JSON="$HOME/.claude/plugins/installed_plugins.json"
    if [ -f "$INSTALL_JSON" ] && command -v jq &>/dev/null; then
      jq 'del(.plugins["brooks-lint@brooks-lint-marketplace"])' "$INSTALL_JSON" > "${INSTALL_JSON}.tmp" 2>/dev/null && \
        mv "${INSTALL_JSON}.tmp" "$INSTALL_JSON" || true
    fi
    # 从 known_marketplaces.json 中移除 brooks-lint-marketplace（幂等）
    KNOWN_JSON="$HOME/.claude/plugins/known_marketplaces.json"
    if [ -f "$KNOWN_JSON" ] && command -v jq &>/dev/null; then
      jq 'del(.["brooks-lint-marketplace"])' "$KNOWN_JSON" > "${KNOWN_JSON}.tmp" 2>/dev/null && \
        mv "${KNOWN_JSON}.tmp" "$KNOWN_JSON" || true
    fi
    rm -f "$VERSION_FILE"
    echo "   ✅ 已清理既有安装"
  fi
fi

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
# Step 1: flow-kit 核心引擎 → ~/.claude/flow-kit/
# ═══════════════════════════════════════════════════════════════════════
install_flow_kit_core() {
  echo ""
  echo "═══ 安装 flow-kit 核心引擎 ═══"

  local dst="$HOME/.claude/flow-kit"

  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] rsync $SCRIPT_DIR/flow-kit/ -> $dst/"
    return
  fi

  if [ -d "$dst" ]; then
    echo "   ⚠️  $dst 已存在，将使用本地包覆盖更新（完全离线）..."
  fi

  rsync -a --exclude='.git' "$SCRIPT_DIR/flow-kit/" "$dst/"
  echo "   ✅ flow-kit 核心已安装到 $dst"
}

# ═══════════════════════════════════════════════════════════════════════
# Step 2: flow-* skills → ~/.claude/skills/flow-*/
# ═══════════════════════════════════════════════════════════════════════
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

# ═══════════════════════════════════════════════════════════════════════
# Step 3: brooks-lint 插件 → ~/.claude/commands/ + ~/.claude/plugins/
# ═══════════════════════════════════════════════════════════════════════
install_brooks_lint() {
  echo ""
  echo "═══ 安装 brooks-lint 代码审查插件 ═══"

  local plugin_src="$SCRIPT_DIR/brooks-lint/plugin"
  local plugin_dst="$HOME/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/1.3.0"

  if [ ! -d "$plugin_src" ]; then
    echo "   ⚠️  brooks-lint 插件源目录不存在，跳过"
    return
  fi

  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] rsync $plugin_src/ -> $plugin_dst/"
    echo "   [DRY-RUN] rsync $plugin_src/ -> $HOME/.claude/plugins/marketplaces/brooks-lint-marketplace/"
    return
  fi

  # F2: 插件主体 → cache/（CC 运行时加载 + /plugin 列表识别）
  #     同时写一份到 marketplaces/（marketplace 源目录，备查 / 手工重装 / 未来 CC 可能支持同步）
  #     注：命令入口文件（brooks-*.md → ~/.claude/commands/）由 brooks-lint 插件自身
  #         SessionStart hook 管理，不应手动安装，否则与插件 namespace 下的 skill 重复。
  if [ -d "$plugin_src" ]; then
    mkdir -p "$plugin_dst"
    rsync -a --exclude='.git' --exclude='commands' "$plugin_src/" "$plugin_dst/"
    echo "   ✅ brooks-lint 插件已安装到 $plugin_dst"

    local mkt_dst="$HOME/.claude/plugins/marketplaces/brooks-lint-marketplace"
    mkdir -p "$mkt_dst"
    rsync -a --exclude='.git' --exclude='commands' "$plugin_src/" "$mkt_dst/"
    echo "   ✅ brooks-lint 已同步到 $mkt_dst（marketplace 源副本）"
  fi

  # 清理 commands/ 目录：防止无前缀 stub 导致的重复 skill 注册
  # （brooks-lint v1.3.0+ 的 skills 自带 brooks-lint: 命名空间前缀，不需要额外 commands）
  for dir in "$plugin_dst" "$mkt_dst"; do
    if [ -d "$dir/commands" ]; then
      rm -f "$dir/commands"/brooks-*.md "$dir/commands"/.brooks-lint-v* 2>/dev/null || true
      rmdir "$dir/commands" 2>/dev/null || true
      echo "   🧹 已清理 $dir/commands/（避免重复 skill 注册）"
    fi
  done
  # 同时清理 ~/.claude/commands/ 下的旧残留
  rm -f "$HOME/.claude/commands"/brooks-*.md "$HOME/.claude/commands"/.brooks-lint-v* 2>/dev/null || true

  # 修补 brooks-lint SessionStart hook：
  #   commands/ 目录已被清理 → hook 中的 cp brooks-*.md 会因为 glob 空匹配而失败
  #   （set -euo pipefail + 非 nullglob 环境 → cp 收到字面量路径 → No such file）
  #   修复方式：用 for + [ -f ] 替换裸 cp，使空 glob 优雅跳过。
  for hook_dir in "$plugin_dst" "$mkt_dst"; do
    local hook_file="$hook_dir/hooks/session-start"
    if [ -f "$hook_file" ]; then
      # 替换: cp "$plugin_dir"/commands/brooks-*.md "$cmd_dir/"
      # 为:   for f in ...; do [ -f "$f" ] && cp "$f" ...; done
      sed -i 's|cp "\$plugin_dir"/commands/brooks-\*\.md "\$cmd_dir/"|for f in "$plugin_dir"/commands/brooks-*.md; do\n            [ -f "$f" ] \&\& cp "$f" "$cmd_dir/"\n        done|' "$hook_file"
      echo "   🔧 已修补 $hook_file（空 commands 容错）"
    fi
  done

  # F3: 注册到 installed_plugins.json（幂等合并 · Claude Code v2 格式）
  local install_json="$HOME/.claude/plugins/installed_plugins.json"
  local now_iso
  now_iso=$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
  local plugin_key="brooks-lint@brooks-lint-marketplace"
  local plugin_entry
  plugin_entry=$(cat <<EOF
{
  "scope": "user",
  "installPath": "${plugin_dst}",
  "version": "1.3.0",
  "installedAt": "${now_iso}",
  "lastUpdated": "${now_iso}"
}
EOF
)

  if [ -f "$install_json" ]; then
    if command -v jq &>/dev/null; then
      local existing
      existing=$(jq -r --arg key "$plugin_key" '.plugins[$key] // empty' "$install_json" 2>/dev/null) || true
      if [ -z "$existing" ]; then
        # 幂等写入 Claude Code v2 格式
        if jq --arg key "$plugin_key" --argjson entry "$plugin_entry" \
          'if .version then . else . + {version: 2} end
           | .plugins[$key] += [$entry]' \
          "$install_json" > "${install_json}.tmp" 2>/dev/null; then
          mv "${install_json}.tmp" "$install_json"
          echo "   ✅ brooks-lint 已注册到 installed_plugins.json"
        else
          echo "   ⚠️  brooks-lint 注册到 installed_plugins.json 失败（插件仍可用）"
        fi
      else
        echo "   ℹ️  brooks-lint 已存在于 installed_plugins.json，跳过注册"
      fi
    else
      echo "   ⚠️  jq 未安装，跳过 installed_plugins.json 注册（插件仍可用）"
    fi
  else
    mkdir -p "$(dirname "$install_json")"
    jq -n --arg key "$plugin_key" --argjson entry "$plugin_entry" \
      '{version: 2, plugins: {($key): [$entry]}}' \
      > "$install_json"
    echo "   ✅ 已创建 installed_plugins.json 并注册 brooks-lint"
  fi

  # F4: 注册 marketplace 到 known_marketplaces.json（CC 要求 marketplace 存在才认 plugin）
  local known_json="$HOME/.claude/plugins/known_marketplaces.json"
  local mkt_key="brooks-lint-marketplace"
  local mkt_entry
  mkt_entry=$(cat <<EOF
{
  "source": {
    "source": "github",
    "repo": "hyhmrright/brooks-lint"
  },
  "installLocation": "${mkt_dst}",
  "lastUpdated": "${now_iso}"
}
EOF
)

  if [ -f "$known_json" ]; then
    if command -v jq &>/dev/null; then
      local mkt_existing
      mkt_existing=$(jq -r --arg key "$mkt_key" '.[$key] // empty' "$known_json" 2>/dev/null) || true
      if [ -z "$mkt_existing" ]; then
        if jq --arg key "$mkt_key" --argjson entry "$mkt_entry" \
          '. + {($key): $entry}' \
          "$known_json" > "${known_json}.tmp" 2>/dev/null; then
          mv "${known_json}.tmp" "$known_json"
          echo "   ✅ brooks-lint-marketplace 已注册到 known_marketplaces.json"
        else
          echo "   ⚠️  known_marketplaces.json 注册失败"
        fi
      else
        echo "   ℹ️  brooks-lint-marketplace 已存在于 known_marketplaces.json，跳过"
      fi
    else
      echo "   ⚠️  jq 未安装，跳过 known_marketplaces.json 注册（插件仍可用）"
    fi
  else
    mkdir -p "$(dirname "$known_json")"
    jq -n --arg key "$mkt_key" --argjson entry "$mkt_entry" \
      '{($key): $entry}' \
      > "$known_json"
    echo "   ✅ 已创建 known_marketplaces.json 并注册 brooks-lint-marketplace"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# Step 4: Stop Hook + SessionStart → user (~/.claude/) or project
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

  # Stop hook 模块
  for script in 00-gate 01-transcript-parse 20-claude-md 21-memory 22-git \
                23-quality 24-session 25-project 26-workflow 30-ai-analyze 99-report; do
    install_file "$SCRIPT_DIR/hooks/stop/${script}.sh" "$hook_dst/stop/${script}.sh"
    chmod +x "$hook_dst/stop/${script}.sh" 2>/dev/null || true
  done

  # Stop hook 库文件
  for lib in common flow-kit-artifacts transcript-parser; do
    install_file "$SCRIPT_DIR/hooks/stop/lib/${lib}.sh" "$hook_dst/stop/lib/${lib}.sh"
  done

  # SessionStart hooks
  for script in flow-kit-resume stop-report-reminder; do
    install_file "$SCRIPT_DIR/hooks/session-start/${script}.sh" "$hook_dst/session-start/${script}.sh"
    chmod +x "$hook_dst/session-start/${script}.sh" 2>/dev/null || true
  done

  # 配置文件
  install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "$project/.claude/stop-hook.json"

  # ═══ 自动写入 settings.local.json（Stop hook 接线） ═══
  local settings_local="$project/.claude/settings.local.json"
  local stop_cmd="bash \"${settings_hook_path}/stop/00-gate.sh\""

  echo ""
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] 写入 Stop hook 到 ${settings_local}: command=${stop_cmd}"
  elif [ -f "$settings_local" ] && command -v jq &>/dev/null; then
    # 已存在 → 检查是否已有 flow-kit stop hook，没有则追加
    if jq -e --arg cmd "$stop_cmd" '(.hooks.Stop // []) | any(.[].hooks[].command; . == $cmd)' "$settings_local" >/dev/null 2>&1; then
      echo "   ✅ Stop hook 已存在于 ${settings_local}，跳过"
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
      ' "$settings_local" 2>/dev/null)
      if [ -n "$merged" ]; then
        echo "$merged" > "$settings_local"
        echo "   ✅ ${settings_local} 已追加 Stop hook 接线"
      else
        echo "   ⚠️  ${settings_local} 合并失败，请手动检查"
      fi
    fi
  else
    # 新建
    mkdir -p "$(dirname "$settings_local")"
    jq -n --arg cmd "$stop_cmd" '
      { hooks: { Stop: [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": $cmd
        }]
      }] } }
    ' > "$settings_local" 2>/dev/null
    echo "   ✅ ${settings_local} 已写入 Stop hook 接线"
  fi

  # SessionStart hooks 由全局 ~/.claude/settings.json 管理（--global 安装时已写入），
  # 此处不再重复写入，避免同一 hook 触发两次。
  echo "   ℹ️  SessionStart hooks 由全局配置管理，无需项目级重复接线"
}

# ═══════════════════════════════════════════════════════════════════════
# Step 5: .specs/STATE.md 模板
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

# ═══════════════════════════════════════════════════════════════════════
# 执行
# ═══════════════════════════════════════════════════════════════════════

if [ "$HOOKS_ONLY" = true ]; then
  install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"
  install_specs_template "$TARGET_PROJECT"
else
  case "$MODE" in
    global)
      install_flow_kit_core
      if [ "$NO_SKILLS" = false ]; then
        install_skills
      fi
      if [ "$NO_BROOKS" = false ]; then
        install_brooks_lint
      fi
      # --global --user: 同时安装用户级 hooks
      if [ "$HOOK_SCOPE" = "user" ]; then
        install_hooks "$HOME" "user"
      else
        echo ""
        echo "💡 如需 hooks，请运行:"
        echo "   $0 --project <你的项目路径> --hooks-only        # 项目级"
        echo "   $0 --global --user                               # 用户级（所有项目生效）"
      fi
      ;;
    project)
      if [ "$NO_HOOKS" = false ]; then
        install_hooks "$TARGET_PROJECT" "$HOOK_SCOPE"
      fi
      install_specs_template "$TARGET_PROJECT"
      if [ "$NO_SKILLS" = false ]; then
        echo ""
        echo "💡 Skills 需全局安装，请单独运行:"
        echo "   $0 --global --no-hooks"
      fi
      ;;
  esac
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ flow-kit 安装完成!                                       ║"
echo "║                                                              ║"
echo "║  下一步:                                                     ║"
echo "║  1. 检查 .claude/settings.local.json（Stop hook 已自动接线） ║"
echo "║  2. 根据需要调整 stop-hook.json 中的模块开关                 ║"
echo "║  3. 在项目目录运行 /flow-go 初始化                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# 写入版本标记
if [ "$MODE" = "global" ] || [ "$REINSTALL" = true ]; then
  if [ -f "$BUNDLE_VERSION_FILE" ]; then
    if [ "${DRY_RUN:-false}" = true ]; then
      echo "   [DRY-RUN] cp .flow-kit-version -> $VERSION_FILE"
    else
      cp "$BUNDLE_VERSION_FILE" "$VERSION_FILE"
      echo "   📌 版本标记: $(cat "$VERSION_FILE")"
    fi
  fi
fi
