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
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="$HOME/.claude/.flow-kit-version"
BUNDLE_VERSION_FILE="$SCRIPT_DIR/.flow-kit-version"

# ── 加载 lib 模块 ────────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/install_hooks.sh"   # install_file(), install_hooks(), install_specs_template()
source "$SCRIPT_DIR/lib/install_core.sh"    # install_flow_kit_core()
source "$SCRIPT_DIR/lib/install_skills.sh"  # install_skills()
source "$SCRIPT_DIR/lib/install_brooks.sh"  # install_brooks_lint()
# NOTE: 新增 lib/ 文件时必须在此添加 source 声明，否则运行时 "command not found"

# ── usage ─────────────────────────────────────────────────────────────
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
    --brooks-src)  BROOKS_SRC="$2"; shift 2 ;;
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
    echo "   [DRY-RUN] rm -rf ~/.claude/flow-kit ~/.claude/skills/flow-* ~/.claude/plugins/cache/brooks-lint-marketplace ~/.claude/plugins/marketplaces/brooks-lint-marketplace"
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
