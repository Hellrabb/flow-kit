#!/bin/bash
# ============================================================================
# flow-kit 完整打包脚本
# 将 ~/nanoclaw 中用到的全套 flow-kit 生态打包为可迁移的 tarball
# ============================================================================
set -euo pipefail

OUTPUT_DIR="${1:-$HOME/flow-kit-export}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="flow-kit-full-${TIMESTAMP}"
STAGING="${OUTPUT_DIR}/${PACKAGE_NAME}"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        flow-kit 完整生态打包工具                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ── 清理旧临时目录 ──────────────────────────────────────────────────
rm -rf "$STAGING"
mkdir -p "$STAGING"/{flow-kit,skills,hooks/config,hooks/stop,hooks/session-start,specs-template,brooks-lint/commands,brooks-lint/plugin}

# ═══════════════════════════════════════════════════════════════════════
# Part A: flow-kit 核心引擎 (~/.claude/flow-kit/)
# ═══════════════════════════════════════════════════════════════════════
echo "📦 Part A: 打包 flow-kit 核心引擎..."

# 从 git repo 直接用 git archive（最干净，不含 .git）
if git -C "$HOME/.claude/flow-kit" rev-parse HEAD >/dev/null 2>&1; then
  git -C "$HOME/.claude/flow-kit" archive \
    --format=tar \
    --prefix="flow-kit/" \
    HEAD \
    | tar -xC "$STAGING/"
  echo "   ✅ flow-kit git archive 完成 (from $(git -C "$HOME/.claude/flow-kit" remote get-url origin))"
else
  # 回退：直接复制（排除 .git）
  rsync -a --exclude='.git' "$HOME/.claude/flow-kit/" "$STAGING/flow-kit/"
  echo "   ⚠️  非 git repo，使用 rsync 回退"
fi

# ═══════════════════════════════════════════════════════════════════════
# Part B: flow-kit 技能包装器 (~/.claude/skills/flow-*/)
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part B: 打包 flow-* 技能包装器..."

SKILL_COUNT=0
for skill_dir in "$HOME/.claude/skills/flow-"*/ "$HOME/.claude/skills/flow/"; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  mkdir -p "$STAGING/skills/${skill_name}"
  cp "${skill_dir}SKILL.md" "$STAGING/skills/${skill_name}/"
  SKILL_COUNT=$((SKILL_COUNT + 1))
done
echo "   ✅ ${SKILL_COUNT} 个 flow 技能已打包"

# ═══════════════════════════════════════════════════════════════════════
# Part C: Stop Hook 系统 (~/nanoclaw/.claude/hooks/)
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part C: 打包 Stop Hook 系统..."

HOOK_SRC="$HOME/nanoclaw/.claude/hooks"

# Stop hook 模块脚本
cp "$HOOK_SRC/stop/00-gate.sh"            "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/01-transcript-parse.sh" "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/20-claude-md.sh"       "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/21-memory.sh"          "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/22-git.sh"             "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/23-quality.sh"         "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/24-session.sh"          "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/25-project.sh"         "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/26-workflow.sh"        "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/30-ai-analyze.sh"      "$STAGING/hooks/stop/"
cp "$HOOK_SRC/stop/99-report.sh"          "$STAGING/hooks/stop/"

# Stop hook 库文件
mkdir -p "$STAGING/hooks/stop/lib"
cp "$HOOK_SRC/stop/lib/common.sh"              "$STAGING/hooks/stop/lib/"
cp "$HOOK_SRC/stop/lib/flow-kit-artifacts.sh"   "$STAGING/hooks/stop/lib/"
cp "$HOOK_SRC/stop/lib/transcript-parser.sh"    "$STAGING/hooks/stop/lib/"

# SessionStart hook 脚本
cp "$HOOK_SRC/session-start/flow-kit-resume.sh"       "$STAGING/hooks/session-start/"
cp "$HOOK_SRC/session-start/stop-report-reminder.sh"   "$STAGING/hooks/session-start/"

# 模块设计文档
if [ -f "$HOOK_SRC/MODULE_IDEAS.md" ]; then
  cp "$HOOK_SRC/MODULE_IDEAS.md" "$STAGING/hooks/"
fi

HOOK_FILE_COUNT=$(find "$STAGING/hooks" -type f 2>/dev/null | wc -l)
echo "   ✅ ${HOOK_FILE_COUNT} 个 hook 文件已打包"

# ═══════════════════════════════════════════════════════════════════════
# Part D: 配置文件模板
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part D: 生成配置文件模板..."

# settings.json 模板（hook 绑定）
cat > "$STAGING/hooks/config/settings.json" << 'SETEOF'
{
  "sandbox": {
    "enabled": false
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/stop/00-gate.sh\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start/stop-report-reminder.sh\""
          }
        ]
      },
      {
        "matcher": "startup|clear",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start/flow-kit-resume.sh\""
          }
        ]
      }
    ]
  }
}
SETEOF

# stop-hook.json 模板
cp "$HOME/nanoclaw/.claude/stop-hook.json" "$STAGING/hooks/config/stop-hook.json"

# .specs/STATE.md 模板
cp "$HOME/.claude/flow-kit/templates/STATE.md" "$STAGING/specs-template/STATE.md"

echo "   ✅ 配置文件模板已生成"

# ═══════════════════════════════════════════════════════════════════════
# Part E: 安装脚本 + README
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part E: 生成安装脚本和 README..."

# ── README ────────────────────────────────────────────────────────────
cat > "$STAGING/README.md" << 'READEOF'
# flow-kit 完整迁移包

## 包含内容

| 组件 | 路径 | 说明 |
|---|---|---|
| flow-kit 核心引擎 | `flow-kit/` | GO.md, prompts/, templates/, reference/, RULES.md, SYSTEM.md |
| flow-* 技能包装器 | `skills/flow-*/` | 16 个 Claude Code skill，委托到 flow-kit 核心 |
| Stop Hook 系统 | `hooks/stop/` | 11 个模块化后处理脚本 + 3 个库文件 |
| SessionStart Hook | `hooks/session-start/` | flow-kit-resume + stop-report-reminder |
| 配置文件 | `hooks/config/` | settings.json 模板 + stop-hook.json 模板 |
| SPEC 模板 | `specs-template/` | STATE.md 模板 |
| brooks-lint 插件 | `brooks-lint/` | 6 个代码审查 skill（review/audit/debt/test/health/sweep） |
| 安装脚本 | `install.sh` | 自动安装到目标环境 |

## 源信息

- flow-kit 核心来自: https://github.com/rihebty/flow-kit
- Stop hook 系统来自: ~/nanoclaw/.claude/hooks/ (NanoClaw 项目定制)
- 技能包装器来自: ~/.claude/skills/flow-*/
- brooks-lint 插件来自: https://github.com/hyhmrright/brooks-lint (v1.3.0)

## 安装

```bash
# 首次安装 / 全新安装
./install.sh --global

# 智能更新（仅当 bundle 版本 > 已装版本时执行）
./install.sh --update

# 彻底重装（清空既有安装后全新安装）
./install.sh --reinstall

# 项目级安装（hooks 仅对当前项目生效）
./install.sh --project /path/to/your-project

# 用户级 hooks（所有项目共用）
./install.sh --project ~ --hooks-only      # 等同 --user
./install.sh --global --user               # 全局 + 用户级 hooks

# 精细控制
./install.sh --global --no-hooks        # 不装 stop hook
./install.sh --global --no-skills       # 不装 skills
./install.sh --global --no-brooks       # 不装 brooks-lint
./install.sh --project . --hooks-only   # 仅装 stop hook
```

## 更新 / 重装

拿到新版 bundle 后：

```bash
# 推荐：智能更新（自动版本比对）
./install.sh --update

# 如果出问题：彻底重装
./install.sh --reinstall
```

> ⚠️ 不要在 `~/.claude/flow-kit/` 里手动 git pull — bundle 版本管理走 `.flow-kit-version` 版本标记。
```
READEOF

# ── 安装脚本 ──────────────────────────────────────────────────────────
cat > "$STAGING/install.sh" << 'INSTEOF'
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
    echo "   [DRY-RUN] rm -rf ~/.claude/flow-kit ~/.claude/skills/flow-* ~/.claude/plugins/cache/brooks-lint-marketplace ~/.claude/plugins/marketplaces/brooks-lint-marketplace ~/.claude/commands/brooks-*.md + jq del from installed_plugins.json + known_marketplaces.json"
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

  local cmd_src="$SCRIPT_DIR/brooks-lint/commands"
  local cmd_dst="$HOME/.claude/commands"
  local plugin_src="$SCRIPT_DIR/brooks-lint/plugin"
  local plugin_dst="$HOME/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/1.3.0"

  if [ ! -d "$cmd_src" ]; then
    echo "   ⚠️  brooks-lint 命令源目录不存在，跳过"
    return
  fi

  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] cp $cmd_src/brooks-*.md -> $cmd_dst/"
    echo "   [DRY-RUN] rsync $plugin_src/ -> $plugin_dst/"
    return
  fi

  # F1: 命令入口文件
  mkdir -p "$cmd_dst"
  local cmd_count=0
  for f in "$cmd_src"/brooks-*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$cmd_dst/"
    ((cmd_count++)) || true
  done
  # 版本标记
  cp "$cmd_src"/.brooks-lint-v* "$cmd_dst/" 2>/dev/null || true
  echo "   ✅ ${cmd_count} 个 brooks-lint 命令已安装到 $cmd_dst"

  # F2: 插件主体 → cache/（CC 运行时加载 + /plugin 列表识别）
  #     同时写一份到 marketplaces/（marketplace 源目录，备查 / 手工重装 / 未来 CC 可能支持同步）
  if [ -d "$plugin_src" ]; then
    mkdir -p "$plugin_dst"
    rsync -a --exclude='.git' "$plugin_src/" "$plugin_dst/"
    echo "   ✅ brooks-lint 插件已安装到 $plugin_dst"

    local mkt_dst="$HOME/.claude/plugins/marketplaces/brooks-lint-marketplace"
    mkdir -p "$mkt_dst"
    rsync -a --exclude='.git' "$plugin_src/" "$mkt_dst/"
    echo "   ✅ brooks-lint 已同步到 $mkt_dst（marketplace 源副本）"
  fi

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

  # ═══ 生成 settings.json 合并片段（根据 scope 使用不同路径） ═══
  echo ""
  echo "   📋 settings.json 合并片段（粘贴到 ~/.claude/settings.json 的 \"hooks\" 段）:"
  echo ""
  cat << SETEOF
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "bash \"${settings_hook_path}/stop/00-gate.sh\""
        }
      ]
    }
  ],
  "SessionStart": [
    {
      "matcher": "startup",
      "hooks": [
        {
          "type": "command",
          "command": "bash \"${settings_hook_path}/session-start/stop-report-reminder.sh\""
        }
      ]
    },
    {
      "matcher": "startup|clear|compact",
      "hooks": [
        {
          "type": "command",
          "command": "bash \"${settings_hook_path}/session-start/flow-kit-resume.sh\""
        }
      ]
    }
  ]
SETEOF
  echo ""
  echo "   ⚠️  上述片段需手动合并到 ~/.claude/settings.json"
  echo "   如果是 user scope，路径使用 \${HOME}/.claude/hooks/..."
  echo "   如果是 project scope，路径使用 \${CLAUDE_PROJECT_DIR}/.claude/hooks/..."
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
echo "║  1. 合并 settings.json 中的 hooks 配置                       ║"
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
INSTEOF

chmod +x "$STAGING/install.sh"

# 版本标记文件（供 --update 版本比对 + 离线机上识别 bundle 版本）
echo "${TIMESTAMP}" > "$STAGING/.flow-kit-version"
echo "   ✅ README.md + install.sh + .flow-kit-version 已生成 (${TIMESTAMP})"

# ═══════════════════════════════════════════════════════════════════════
# Part F: brooks-lint 代码审查插件（离线优先：本地缓存 → git archive fallback）
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part F: 打包 brooks-lint 代码审查插件..."

BROOKS_COMMAND_SRC="$HOME/.claude/commands"
BROOKS_CACHE="$HOME/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint"
BROOKS_PLUGIN_SRC="$HOME/.claude/plugins/marketplaces/brooks-lint-marketplace"

# F1: 命令入口文件（6 个 skill 入口 + 版本标记 · 不变）
if [ -d "$BROOKS_COMMAND_SRC" ]; then
  cp "$BROOKS_COMMAND_SRC"/brooks-audit.md   "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  cp "$BROOKS_COMMAND_SRC"/brooks-debt.md    "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  cp "$BROOKS_COMMAND_SRC"/brooks-health.md  "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  cp "$BROOKS_COMMAND_SRC"/brooks-review.md  "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  cp "$BROOKS_COMMAND_SRC"/brooks-sweep.md   "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  cp "$BROOKS_COMMAND_SRC"/brooks-test.md    "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  cp "$BROOKS_COMMAND_SRC"/.brooks-lint-v*   "$STAGING/brooks-lint/commands/" 2>/dev/null || true
  BROOKS_CMD_COUNT=$(find "$STAGING/brooks-lint/commands" -name 'brooks-*.md' 2>/dev/null | wc -l)
  echo "   ✅ ${BROOKS_CMD_COUNT} 个 brooks-lint 命令已打包"
else
  echo "   ⚠️  brooks-lint 命令目录不存在，跳过"
fi

# F2: 插件主体（优先级：--brooks-src > 本地缓存 > git archive fallback）
brooks_src=""
brooks_label=""

if [ -n "${BROOKS_SRC:-}" ] && [ -d "$BROOKS_SRC" ]; then
  # 用户指定源
  brooks_src="$BROOKS_SRC"
  brooks_label="--brooks-src $BROOKS_SRC"
elif [ -d "$BROOKS_CACHE" ] && [ -n "$(ls -A "$BROOKS_CACHE" 2>/dev/null)" ]; then
  # 本地缓存存在 → 自动选最新版本
  BROOKS_VER=$(ls -1 "$BROOKS_CACHE" 2>/dev/null | sort -V | tail -1)
  if [ -n "$BROOKS_VER" ] && [ -d "$BROOKS_CACHE/$BROOKS_VER" ]; then
    brooks_src="$BROOKS_CACHE/$BROOKS_VER"
    brooks_label="本地缓存 v${BROOKS_VER}"
  fi
fi

if [ -n "$brooks_src" ]; then
  # 首选：rsync 离线打包
  rsync -a --exclude='.git' "$brooks_src/" "$STAGING/brooks-lint/plugin/"
  echo "   ✅ brooks-lint 插件主体已打包（${brooks_label}）"
elif [ -d "$BROOKS_PLUGIN_SRC" ]; then
  # Fallback：git archive（原有逻辑）
  echo "   ⚠️  本地缓存不可用，回退到 git archive 方式"
  if git -C "$BROOKS_PLUGIN_SRC" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$BROOKS_PLUGIN_SRC" archive \
      --format=tar \
      --prefix="brooks-lint/plugin/" \
      HEAD \
      | tar -xC "$STAGING/"
    # 补充 git-archive 未包含的非追踪文件
    for extra in commands hooks/hooks.json .claude-plugin .brooks-lint.example.yaml AGENTS.md CLAUDE.md CHANGELOG.md CONTRIBUTING.md README.md; do
      if [ -f "$BROOKS_PLUGIN_SRC/$extra" ]; then
        mkdir -p "$(dirname "$STAGING/brooks-lint/plugin/$extra")"
        cp "$BROOKS_PLUGIN_SRC/$extra" "$STAGING/brooks-lint/plugin/$extra"
      fi
    done
    echo "   ✅ brooks-lint 插件主体 git archive 完成 ($(git -C "$BROOKS_PLUGIN_SRC" describe --always --tags 2>/dev/null || echo 'HEAD'))"
  else
    rsync -a --exclude='.git' --exclude='assets' --exclude='docs' \
      "$BROOKS_PLUGIN_SRC/" "$STAGING/brooks-lint/plugin/"
    echo "   ⚠️  非 git repo，使用 rsync 回退"
  fi
else
  echo "   ⚠️  brooks-lint 插件目录不存在，跳过"
fi

BROOKS_FILE_COUNT=$(find "$STAGING/brooks-lint" -type f 2>/dev/null | wc -l)
echo "   ✅ ${BROOKS_FILE_COUNT} 个 brooks-lint 文件已打包"

# ═══════════════════════════════════════════════════════════════════════
# 打包
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 正在打包为 ${PACKAGE_NAME}.tar.gz ..."

cd "$OUTPUT_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

PACKAGE_SIZE=$(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ 打包完成!                                                ║"
echo "║                                                              ║"
echo "║  📁 ${PACKAGE_NAME}.tar.gz (${PACKAGE_SIZE})"
echo "║  📂 解压后: ${STAGING}/"
echo "║                                                              ║"
echo "║  迁移到目标环境:                                              ║"
echo "║    scp ${PACKAGE_NAME}.tar.gz user@target:~/""
echo "║                                                              ║"
echo "║  目标环境安装:                                                ║"
echo "║    tar xzf ${PACKAGE_NAME}.tar.gz                           ║"
echo "║    cd ${PACKAGE_NAME}                                       ║"
echo "║    ./install.sh --global  # 全局安装                         ║"
echo "║    ./install.sh --project /path/to/project --hooks-only      ║"
echo "║                                                              ║"
echo "║  内容清单:                                                    ║"
echo "║    🧠 flow-kit 核心 (GO.md + prompts + templates + ref)     ║"
echo "║    🎯 ${SKILL_COUNT} 个 flow skills                                     ║"
echo "║    🪝 Stop Hook 系统 (11 模块 + 3 库)                       ║"
echo "║    🚀 SessionStart hooks (resume + report-reminder)          ║"
echo "║    ⚙️  配置模板 (settings.json + stop-hook.json)             ║"
echo "║    📋 SPEC 模板 (STATE.md)                                   ║"
echo "║    🔍 brooks-lint 插件 (${BROOKS_CMD_COUNT} 命令 + 插件主体)              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
