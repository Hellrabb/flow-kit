#!/bin/bash
# ============================================================================
# flow-kit 安装脚本（claude | opencode 双平台兼容）
# 用法: ./install.sh [--platform claude|opencode] [--global|--project <path>]
#                    [--no-hooks] [--no-skills] [--hooks-only]
# ============================================================================
set -euo pipefail

PLATFORM="claude"          # 默认 claude（向后兼容）
MODE=""
TARGET_PROJECT=""
NO_HOOKS=false
NO_SKILLS=false
NO_BROOKS=false
NO_BROOKS_TOOLS=false
HOOKS_ONLY=false
HOOK_SCOPE="project"
REINSTALL=false
BROOKS_SRC=""
DRY_RUN=false
SELF_TEST=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 加载 lib 模块（顺序敏感：paths.sh 必须在所有 install_*.sh 之前）────
source "$SCRIPT_DIR/lib/paths.sh"               # resolve_paths() + project_dir_for() + settings_file_for()
source "$SCRIPT_DIR/lib/install_hooks.sh"        # install_file(), install_hooks(), install_specs_template()
source "$SCRIPT_DIR/lib/install_core.sh"         # install_flow_kit_core()
source "$SCRIPT_DIR/lib/install_skills.sh"       # install_skills()
source "$SCRIPT_DIR/lib/install_brooks.sh"       # install_brooks_lint()
source "$SCRIPT_DIR/lib/install_brooks_tools.sh" # install_brooks_tools()
source "$SCRIPT_DIR/lib/install_agents_md.sh"    # install_agents_md_injection()
# NOTE: 新增 lib/ 文件时必须在此添加 source 声明，否则运行时 "command not found"

# ── auto_detect_platform ──────────────────────────────────────────────
# 启发式：~/.config/opencode/opencode.json 存在 且 ~/.claude/ 不存在 → opencode
#        否则 → claude（Claude Code 仍是默认）
# =====================================================================
auto_detect_platform() {
  if [ -f "$HOME/.config/opencode/opencode.json" ] && [ ! -d "$HOME/.claude" ]; then
    echo "opencode"
  elif [ -f "$HOME/.config/opencode/opencode.json" ] && [ -d "$HOME/.claude" ]; then
    # 两者都存在 → 优先 claude（向后兼容）；用户可用 --platform opencode 强制
    echo "claude"
  else
    echo "claude"
  fi
}

# ── usage ─────────────────────────────────────────────────────────────
usage() {
  cat << EOF
用法: $0 [选项]

平台选择:
  --platform <name>     目标平台：claude (默认) | opencode | auto
                        claude   → 安装到 ~/.claude/（Claude Code 原生）
                        opencode → 安装到 ~/.config/opencode/（opencode 原生）
                                   注：hooks 依赖桥接插件（见 OPENCODE-INSTALL.md）

模式:
  --global              全局安装（核心 + skills + brooks-lint + 可选用户级 hooks）
  --update              智能更新（版本比对 · bundle 版本 > 已装版本才执行）
  --reinstall           彻底重装（先清理 → 再全新 --global）
  --project <path>      安装到指定项目（hooks + settings + .specs 模板）
  --user                安装 hooks 到用户目录（所有项目共用）
  --hooks-only          仅安装 hooks（需配合 --project）

跳过项:
  --no-hooks            跳过 stop hook 安装
  --no-skills           跳过 skills 安装
  --no-brooks           跳过 brooks-lint 安装
  --no-brooks-tools     跳过 brooks-lint npm 工具安装

其他:
  --dry-run             仅打印将要执行的操作，不实际执行
  --self-test           安装后自动运行 bats 测试验证安装完整性
  --brooks-src <path>   指定 brooks-lint 源目录（开发用）
  -h, --help            显示本帮助

示例:
  # Claude Code（默认）
  $0 --global                              # 全局安装全部组件
  $0 --update                              # 智能更新（仅当 bundle 更新）
  $0 --reinstall                           # 彻底重装
  $0 --project /path/to/myproject          # 项目级安装
  $0 --global --no-hooks                   # 仅核心 + skills + brooks，不装 hooks
  $0 --project . --hooks-only              # 仅装 hooks 到当前项目

  # opencode
  $0 --platform opencode --global          # opencode 全局安装
  $0 --platform opencode --project .       # opencode 项目级安装
  $0 --platform opencode --global --no-brooks   # 跳过 brooks-lint

  # 自动检测平台
  $0 --platform auto --global              # 自动判断 claude/opencode
EOF
  exit 0
}

# ── check_node ─────────────────────────────────────────────────────────
check_node() {
  if command -v node &>/dev/null; then
    NODE_AVAILABLE=true
    echo "   ✅ Node.js $(node --version) 已检测到"
  else
    NODE_AVAILABLE=false
    echo "   ⚠️  Node.js 未安装，跳过 brooks-lint 工具安装。"
    echo "   请先安装 Node.js ≥ 18：dnf module install nodejs:18"
  fi
}

# ── 解析参数 ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)    PLATFORM="$2"; shift 2 ;;
    --global)      MODE="global"; shift ;;
    --project)     MODE="project"; TARGET_PROJECT="$2"; shift 2 ;;
    --no-hooks)    NO_HOOKS=true; shift ;;
    --no-skills)   NO_SKILLS=true; shift ;;
    --no-brooks)   NO_BROOKS=true; shift ;;
    --no-brooks-tools)   NO_BROOKS_TOOLS=true; shift ;;
    --hooks-only)  HOOKS_ONLY=true; shift ;;
    --update)      MODE="update"; shift ;;
    --reinstall)   REINSTALL=true; MODE="global"; shift ;;
    --user)        HOOK_SCOPE="user"; shift ;;
    --yes)         FLOW_KIT_YES=1; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --self-test)   SELF_TEST=true; shift ;;
    --brooks-src)  BROOKS_SRC="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *) echo "未知选项: $1"; usage ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "❌ 必须指定 --global 或 --project <path>"
  usage
fi

# ── 平台解析 + 路径变量初始化 ────────────────────────────────────────
if [ "$PLATFORM" = "auto" ]; then
  PLATFORM=$(auto_detect_platform)
  echo "ℹ️  自动检测平台: $PLATFORM"
fi

case "$PLATFORM" in
  claude|opencode) ;;
  *)
    echo "❌ 无效平台: $PLATFORM（应为 claude | opencode | auto）"
    exit 1
    ;;
esac

resolve_paths "$PLATFORM" || exit 1
VERSION_FILE="${PLATFORM_CONFIG_DIR}/.flow-kit-version"
BUNDLE_VERSION_FILE="$SCRIPT_DIR/.flow-kit-version"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  flow-kit 安装器 (平台: ${PLATFORM})"
echo "║  配置目录: ${PLATFORM_CONFIG_DIR}"
echo "╚═══════════════════════════════════════════════════════════════╝"

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
  echo "🧹 彻底重装：清理既有安装 [${PLATFORM}]..."
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] rm -rf $FLOW_KIT_HOME $USER_SKILLS_DIR/flow-* ${USER_PLUGINS_DIR:-/dev/null}/cache/brooks-lint-marketplace ${USER_PLUGINS_DIR:-/dev/null}/marketplaces/brooks-lint-marketplace"
  else
    rm -rf "$FLOW_KIT_HOME"
    if [ -n "$USER_PLUGINS_DIR" ]; then
      rm -rf "$USER_PLUGINS_DIR/cache/brooks-lint-marketplace"
      rm -rf "$USER_PLUGINS_DIR/marketplaces/brooks-lint-marketplace"
      rm -f "$USER_PLUGINS_DIR/installed_plugins.json" 2>/dev/null || true
    fi
    rm -f "$HOME/.claude/commands"/brooks-*.md 2>/dev/null || true
    rm -f "$HOME/.claude/commands"/.brooks-lint-v* 2>/dev/null || true
    for d in "$USER_SKILLS_DIR"/flow-* "$USER_SKILLS_DIR"/brooks-*; do
      [ -d "$d" ] && rm -rf "$d"
    done 2>/dev/null || true
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
      if [ "$NO_BROOKS_TOOLS" = false ]; then
        check_node
        if [ "$NODE_AVAILABLE" = true ]; then
          install_brooks_tools
        fi
      fi
      # opencode: 注入 AGENTS.md
      if [ "$PLATFORM" = "opencode" ]; then
        install_agents_md_injection
      fi
      # --global --user: 同时安装用户级 hooks
      if [ "$HOOK_SCOPE" = "user" ]; then
        install_hooks "$HOME" "user"
      else
        echo ""
        echo "💡 如需 hooks，请运行:"
        echo "   $0 --platform $PLATFORM --project <你的项目路径> --hooks-only        # 项目级"
        echo "   $0 --platform $PLATFORM --global --user                               # 用户级（所有项目生效）"
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
        echo "   $0 --platform $PLATFORM --global --no-hooks"
      fi
      ;;
  esac
fi

# ── --self-test: 安装后自检 ──────────────────────────────────────────
if [ "$SELF_TEST" = true ]; then
  echo ""
  echo "🧪 运行安装后自检..."
  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] npx bats test/"
  else
    # 优先用项目本地 test/；否则用 bundle 自带 test/
    if [ -d "$SCRIPT_DIR/../test" ] && [ -f "$SCRIPT_DIR/../test/test_phase_gate.bats" ]; then
      TEST_DIR="$SCRIPT_DIR/../test"
    elif [ -d "$SCRIPT_DIR/test" ] && [ -f "$SCRIPT_DIR/test/test_phase_gate.bats" ]; then
      TEST_DIR="$SCRIPT_DIR/test"
    else
      echo "   ⚠️  未找到测试目录，跳过自检"
      TEST_DIR=""
    fi
    if [ -n "$TEST_DIR" ]; then
      if command -v npx &>/dev/null; then
        npx bats "$TEST_DIR/" 2>&1 || {
          echo "   ❌ 安装后自检未通过，请检查安装"
          exit 1
        }
        echo "   ✅ 安装后自检通过"
      else
        echo "   ⚠️  npx 不可用，跳过自检（请手动运行 npx bats test/）"
      fi
    fi
  fi
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ flow-kit 安装完成! [${PLATFORM}]"
echo "║"
echo "║  下一步:"
if [ "$PLATFORM" = "claude" ]; then
  echo "║  1. 检查 ${PROJECT_DIR_NAME}/settings.local.json（hook 已自动接线）"
  echo "║  2. 根据需要调整 stop-hook.json 中的模块开关"
  echo "║  3. 在项目目录运行 /flow-go 初始化"
else
  echo "║  1. 检查 ~/.config/opencode/skills/flow-* （skills 已安装）"
  echo "║  2. 启用 hooks（详见 OPENCODE-INSTALL.md）："
  echo "║     npm install -g opencode-claude-hooks  # 桥接插件"
  echo "║  3. 重启 opencode 让 skills 生效"
  echo "║  4. 在项目目录运行 /flow-go 初始化"
fi
echo "╚═══════════════════════════════════════════════════════════════╝"

# 写入版本标记
if [ "$MODE" = "global" ] || [ "$REINSTALL" = true ]; then
  if [ -f "$BUNDLE_VERSION_FILE" ]; then
    if [ "${DRY_RUN:-false}" = true ]; then
      echo "   [DRY-RUN] cp .flow-kit-version -> $VERSION_FILE"
    else
      mkdir -p "$(dirname "$VERSION_FILE")"
      cp "$BUNDLE_VERSION_FILE" "$VERSION_FILE"
      echo "   📌 版本标记: $(cat "$VERSION_FILE")"
    fi
  fi
fi
