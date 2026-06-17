#!/bin/bash
# ============================================================================
# flow-kit 完整打包脚本
# 将 ~/nanoclaw 中用到的全套 flow-kit 生态打包为可迁移的 tarball
# ============================================================================
set -euo pipefail

OUTPUT_DIR="${1:-$HOME/flow-kit-export}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="flow-kit-full-${TIMESTAMP}"
STAGING="${OUTPUT_DIR}/${PACKAGE_NAME}"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        flow-kit 完整生态打包工具                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ── 清理旧临时目录 ──────────────────────────────────────────────────
[[ -n "$STAGING" && "$STAGING" != "/" ]] || { echo "FATAL: STAGING is empty or root"; exit 1; }
rm -rf "$STAGING"
mkdir -p "$STAGING"/{flow-kit,skills,hooks/config,hooks/stop,hooks/session-start,specs-template,brooks-lint/plugin}

# ═══════════════════════════════════════════════════════════════════════
# Part A: flow-kit 核心引擎 (~/.claude/flow-kit/)
# ═══════════════════════════════════════════════════════════════════════
echo "📦 Part A: 打包 flow-kit 核心引擎..."

# 优先本地 bundle 副本，再回退到外部 ~/.claude/flow-kit
if [ -f "$SCRIPT_DIR/flow-kit-bundle/flow-kit/GO.md" ]; then
  echo "   ℹ️  使用本地副本: flow-kit-bundle/flow-kit/"
  rsync -a --exclude='.git' "$SCRIPT_DIR/flow-kit-bundle/flow-kit/" "$STAGING/flow-kit/"
  echo "   ✅ flow-kit 本地副本打包完成"
elif git -C "$HOME/.claude/flow-kit" rev-parse HEAD >/dev/null 2>&1; then
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

# 优先本地 bundle 副本，再回退到外部 ~/.claude/skills/
if ls "$SCRIPT_DIR/flow-kit-bundle/skills/flow-"*/SKILL.md >/dev/null 2>&1; then
  echo "   ℹ️  使用本地副本: flow-kit-bundle/skills/"
  for skill_dir in "$SCRIPT_DIR/flow-kit-bundle/skills/flow-"*/ "$SCRIPT_DIR/flow-kit-bundle/skills/flow/"; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    mkdir -p "$STAGING/skills/${skill_name}"
    cp "${skill_dir}SKILL.md" "$STAGING/skills/${skill_name}/"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  done
else
  for skill_dir in "$HOME/.claude/skills/flow-"*/ "$HOME/.claude/skills/flow/"; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    mkdir -p "$STAGING/skills/${skill_name}"
    cp "${skill_dir}SKILL.md" "$STAGING/skills/${skill_name}/"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  done
fi
echo "   ✅ ${SKILL_COUNT} 个 flow 技能已打包"

# ═══════════════════════════════════════════════════════════════════════
# Part C: Stop Hook 系统 (~/nanoclaw/.claude/hooks/)
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part C: 打包 Stop Hook 系统..."

HOOK_SRC="$SCRIPT_DIR/flow-kit-bundle/hooks"

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

# settings.json 模板 — 从 bundle 复制（单一源，避免 heredoc 重复维护）
cp "$SCRIPT_DIR/flow-kit-bundle/hooks/config/settings.json" "$STAGING/hooks/config/"

# stop-hook.json 模板
cp "$SCRIPT_DIR/flow-kit-bundle/hooks/config/stop-hook.json" "$STAGING/hooks/config/stop-hook.json"

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

# ── 安装脚本 ──
cp "$SCRIPT_DIR/flow-kit-bundle/install.sh" "$STAGING/install.sh"
echo "   ✅ install.sh 已打包 (from flow-kit-bundle/)"

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

# F1: 命令入口文件已废弃 —— brooks-lint v1.3.0+ 插件 skills 自带 namespace 前缀
#     (brooks-lint:brooks-review 等)，不再需要无前缀的 commands stub。
#     旧版 commands stub 会导致 /brooks-review 和 /brooks-lint:brooks-review 重复注册。
BROOKS_CMD_COUNT=0
echo "   ℹ️  brooks-lint 命令入口已废弃，仅保留插件主体（skills 自带 brooks-lint: 命名空间）"

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
  rsync -a --exclude='.git' --exclude='commands' "$brooks_src/" "$STAGING/brooks-lint/plugin/"
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
elif [ -d "$SCRIPT_DIR/flow-kit-bundle/brooks-lint/plugin" ]; then
  echo "   ℹ️  使用本地副本: flow-kit-bundle/brooks-lint/plugin/"
  rsync -a --exclude='.git' --exclude='commands' "$SCRIPT_DIR/flow-kit-bundle/brooks-lint/plugin/" "$STAGING/brooks-lint/plugin/"
  echo "   ✅ brooks-lint 本地副本打包完成"
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
echo "║    🔍 brooks-lint 插件 v1.3.0（skills 命名空间 brooks-lint:）         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
