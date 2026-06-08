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
# 方式1: 全局安装（所有项目复用 flow-kit）
./install.sh --global

# 方式2: 安装到指定项目
./install.sh --project /path/to/your-project

# 方式3: 仅安装特定组件
./install.sh --global --no-hooks        # 不装 stop hook
./install.sh --global --no-skills       # 不装 skills
./install.sh --project . --hooks-only   # 仅装 stop hook
```

## 安装后

1. 为目标项目创建 `.specs/STATE.md`（参考 `specs-template/STATE.md`）
2. 如需入场扫描，在项目目录运行 `/flow-go` 然后选 "扫描代码"
3. 根据项目需求调整 `stop-hook.json` 中的模块开关

## 更新 flow-kit 核心

```bash
cd ~/.claude/flow-kit && git pull
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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat << EOF
用法: $0 [选项]

选项:
  --global              全局安装（~/.claude/flow-kit + ~/.claude/skills/flow-* + brooks-lint）
  --project <path>      安装到指定项目（hooks + settings.json + .specs 模板）
  --no-hooks            跳过 stop hook 安装
  --no-skills           跳过 skills 安装
  --no-brooks           跳过 brooks-lint 安装
  --hooks-only          仅安装 hooks（需配合 --project）
  --dry-run             仅打印将要执行的操作，不实际执行

示例:
  $0 --global                              # 全局安装全部组件
  $0 --project /path/to/myproject          # 项目级安装
  $0 --global --no-hooks                   # 仅全局 flow-kit + skills + brooks-lint，不装 hooks
  $0 --global --no-brooks                  # 全局安装但不装 brooks-lint
  $0 --project . --hooks-only              # 仅装 hooks 到当前项目
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
    --dry-run)     DRY_RUN=true; shift ;;
    -h|--help)     usage ;;
    *) echo "未知选项: $1"; usage ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "❌ 必须指定 --global 或 --project <path>"
  usage
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
  local plugin_dst="$HOME/.claude/plugins/marketplaces/brooks-lint-marketplace"

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

  # F2: 插件主体
  if [ -d "$plugin_src" ]; then
    mkdir -p "$plugin_dst"
    rsync -a --exclude='.git' "$plugin_src/" "$plugin_dst/"
    echo "   ✅ brooks-lint 插件已安装到 $plugin_dst"
  fi

  # F3: 注册到 installed_plugins.json（幂等合并）
  local install_json="$HOME/.claude/plugins/installed_plugins.json"
  local plugin_entry='{
    "name": "brooks-lint",
    "version": "1.3.0",
    "source": "marketplace",
    "marketplace": "brooks-lint-marketplace",
    "installed_at": "'"$(date -Iseconds)"'"
  }'

  if [ -f "$install_json" ]; then
    # 用 jq 做幂等 upsert（如果已存在同名插件则跳过）
    if command -v jq &>/dev/null; then
      local existing
      existing=$(jq -r '.plugins[]? | select(.name == "brooks-lint") | .name' "$install_json" 2>/dev/null)
      if [ -z "$existing" ]; then
        jq --argjson entry "$plugin_entry" '.plugins += [$entry]' "$install_json" > "${install_json}.tmp" \
          && mv "${install_json}.tmp" "$install_json"
        echo "   ✅ brooks-lint 已注册到 installed_plugins.json"
      else
        echo "   ℹ️  brooks-lint 已存在于 installed_plugins.json，跳过注册"
      fi
    else
      echo "   ⚠️  jq 未安装，跳过 installed_plugins.json 注册（插件仍可用）"
    fi
  else
    mkdir -p "$(dirname "$install_json")"
    echo "{\"plugins\": [$plugin_entry]}" > "$install_json"
    echo "   ✅ 已创建 installed_plugins.json 并注册 brooks-lint"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# Step 4: Stop Hook + SessionStart → <project>/.claude/hooks/
# ═══════════════════════════════════════════════════════════════════════
install_hooks() {
  local project="$1"
  echo ""
  echo "═══ 安装 Hook 系统到 $project ═══"

  if [ ! -d "$project" ]; then
    echo "   ❌ 项目目录不存在: $project"
    return 1
  fi

  local hook_dst="$project/.claude/hooks"

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

  echo ""
  echo "   ⚠️  注意: settings.json 需要手动合并！"
  echo "   参考模板: $SCRIPT_DIR/hooks/config/settings.json"
  echo "   将 hooks 段合并到 $project/.claude/settings.json"
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
  install_hooks "$TARGET_PROJECT"
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
      echo ""
      echo "💡 全局组件已安装。如需 hooks，请运行:"
      echo "   $0 --project <你的项目路径> --hooks-only"
      ;;
    project)
      if [ "$NO_HOOKS" = false ]; then
        install_hooks "$TARGET_PROJECT"
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
INSTEOF

chmod +x "$STAGING/install.sh"
echo "   ✅ README.md + install.sh 已生成"

# ═══════════════════════════════════════════════════════════════════════
# Part F: brooks-lint 代码审查插件
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part F: 打包 brooks-lint 代码审查插件..."

BROOKS_COMMAND_SRC="$HOME/.claude/commands"
BROOKS_PLUGIN_SRC="$HOME/.claude/plugins/marketplaces/brooks-lint-marketplace"

# F1: 命令入口文件（6 个 skill 入口 + 版本标记）
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

# F2: 插件主体（git archive 排除 .git + assets + docs）
if [ -d "$BROOKS_PLUGIN_SRC" ]; then
  if git -C "$BROOKS_PLUGIN_SRC" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$BROOKS_PLUGIN_SRC" archive \
      --format=tar \
      --prefix="brooks-lint/plugin/" \
      HEAD \
      | tar -xC "$STAGING/"
    # 补充 git-archive 未包含的非追踪文件（commands + hooks/hooks.json + .claude-plugin）
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
