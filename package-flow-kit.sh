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

# ═══════════════════════════════════════════════════════════════════════
# validate_staging_coverage() — L-012 打包完整性校验
# 比对 flow-kit-bundle/ 实际目录树与 Part A~G staging 覆盖范围
# exit: 0=通过, 1=有漏配, 2=脚本自身错误
# ═══════════════════════════════════════════════════════════════════════
validate_staging_coverage() {
  set +e
  local SCRIPT_DIR
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local BUNDLE_DIR="$SCRIPT_DIR/flow-kit-bundle"
  local ERRORS=0
  local WARNINGS=0

  echo "🔍 package-flow-kit.sh --validate"
  echo "   校验 flow-kit-bundle/ 目录结构与 Part A~G staging 指令覆盖范围..."
  echo ""

  if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ 错误: flow-kit-bundle/ 目录不存在: $BUNDLE_DIR"
    exit 2
  fi

  local EXPECTED

  echo "   解析 Part A (flow-kit 核心)..."
  EXPECTED=$(find "$BUNDLE_DIR/flow-kit" -type f 2>/dev/null | sort)

  echo "   解析 Part B (flow-* skills)..."
  for skill_dir in "$BUNDLE_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_dir="${skill_dir%/}"
    local skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$skill_file")
  done

  echo "   解析 Part C (Hook 系统)..."
  for pattern in "$BUNDLE_DIR/hooks/stop/"*.sh "$BUNDLE_DIR/hooks/stop/lib/"*.sh "$BUNDLE_DIR/hooks/session-start/"*.sh; do
    [ -f "$pattern" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$pattern")
  done

  echo "   解析 Part D (配置模板)..."
  for config_file in "$BUNDLE_DIR/hooks/config/"*; do
    [ -f "$config_file" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$config_file")
  done

  echo "   解析 Part E (安装脚本 + lib + specs + test)..."
  [ -f "$BUNDLE_DIR/install.sh" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$BUNDLE_DIR/install.sh")
  for lib_file in "$BUNDLE_DIR/lib/"*.sh; do
    [ -f "$lib_file" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$lib_file")
  done
  for spec_file in "$BUNDLE_DIR/specs-template/"*; do
    [ -f "$spec_file" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$spec_file")
  done
  # test/ directory is part of the bundle
  for test_file in "$BUNDLE_DIR/test/"*.bats; do
    [ -f "$test_file" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$test_file")
  done

  echo "   解析 Part F (brooks-lint 插件)..."
  local brooks_files
  brooks_files=$(find "$BUNDLE_DIR/brooks-lint" -type f 2>/dev/null | sort)
  [ -n "$brooks_files" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$brooks_files")

  echo "   解析 Part G (brooks-tools)..."
  local tools_dir="$BUNDLE_DIR/brooks-lint/plugin/scripts"
  for tgz in "$tools_dir"/*.tgz; do
    [ -f "$tgz" ] && EXPECTED=$(printf '%s\n%s' "$EXPECTED" "$tgz")
  done

  EXPECTED=$(echo "$EXPECTED" | sort -u)

  echo "   扫描 flow-kit-bundle/ 实际文件..."
  local ACTUAL
  ACTUAL=$(find "$BUNDLE_DIR" -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    2>/dev/null | sort)

  echo ""
  echo "   ── 对账结果 ──"
  echo ""

  while IFS= read -r expected_file; do
    [ -z "$expected_file" ] && continue
    if ! echo "$ACTUAL" | grep -qF "$expected_file"; then
      echo "   ⚠️  WARNING: 期望但源缺失 — $expected_file"
      WARNINGS=$((WARNINGS + 1))
    fi
  done <<< "$EXPECTED"

  # 已知非打包文件（bundle 根级别元数据，不被 Part A~G 显式覆盖）
  local KNOWN_SKIP="\.git\|node_modules\|\.DS_Store\|/\.gitignore$\|/\.flow-kit-version$\|/README\.md$\|/FLOW-KIT-用户指南\.md$\|/MODULE_IDEAS\.md$"

  while IFS= read -r actual_file; do
    [ -z "$actual_file" ] && continue
    if echo "$actual_file" | grep -qE "$KNOWN_SKIP"; then
      continue
    fi
    if ! echo "$EXPECTED" | grep -qF "$actual_file"; then
      echo "   🔴 ERROR: 漏配！实际文件未被任何 Part 覆盖 — $actual_file"
      ERRORS=$((ERRORS + 1))
    fi
  done <<< "$ACTUAL"

  echo ""
  echo "   ── 校验汇总 ──"
  echo "   期望覆盖: $(echo "$EXPECTED" | grep -c .) 项"
  echo "   实际文件: $(echo "$ACTUAL" | grep -c .) 项"
  echo "   🔴 漏配 (ERROR): $ERRORS"
  echo "   ⚠️  源缺失 (WARNING): $WARNINGS"

  if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "   ❌ 校验失败：发现 $ERRORS 个漏配项。"
    echo "      请更新 package-flow-kit.sh Part A~G 覆盖范围后重跑。"
    exit 1
  elif [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "   ⚠️  校验通过（有 $WARNINGS 个 WARNING，非阻塞）"
    exit 0
  else
    echo ""
    echo "   ✅ 校验通过：所有文件均被 Part A~G 覆盖。"
    exit 0
  fi
}

# ── --validate 入口 ──
if [ "${1:-}" = "--validate" ]; then
  validate_staging_coverage
  exit $?
fi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        flow-kit 完整生态打包工具                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ── 清理旧临时目录 ──────────────────────────────────────────────────
[[ -n "$STAGING" && "$STAGING" != "/" ]] || { echo "FATAL: STAGING is empty or root"; exit 1; }
rm -rf "$STAGING"
mkdir -p "$STAGING"/{flow-kit,skills,hooks/config,hooks/stop,hooks/session-start,specs-template,brooks-lint/plugin,brooks-tools/packs}

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
| brooks-lint 工具 | `brooks-tools/` | depcheck / jscpd / knip / ts-prune 离线可用（linux-x64） |
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
cp -r "$SCRIPT_DIR/flow-kit-bundle/lib" "$STAGING/"
echo "   ✅ install.sh + lib/ 已打包 (from flow-kit-bundle/)"

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
# Part G: brooks-lint npm 工具离线打包（depcheck / jscpd / knip / ts-prune）
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "📦 Part G: 打包 brooks-lint npm 工具（离线）..."

# ── 工具版本定义（升级时同步修改）──
declare -A BROOKS_TOOLS
BROOKS_TOOLS=(
  ["depcheck"]="1.4.7"
  ["jscpd"]="5.0.11"
  ["knip"]="6.17.1"
  ["ts-prune"]="0.10.3"
)

# ── 检测 npm 可用性 ──
if ! command -v npm &>/dev/null; then
  echo "   ⚠️  npm 未安装，跳过 Part G（brooks-lint 工具离线包）"
else
  echo "   ℹ️  npm $(npm --version) 已检测到"

  # ── 逐工具 npm pack ──
  TOOLS_PACK_DIR="$STAGING/brooks-tools/packs"
  TOOLS_EXTRACT_DIR="$STAGING/brooks-tools/extracted"
  TOOLS_BIN_DIR="$STAGING/brooks-tools/bin"
  TOOLS_NM_DIR="$STAGING/brooks-tools/node_modules"

  mkdir -p "$TOOLS_EXTRACT_DIR" "$TOOLS_BIN_DIR" "$TOOLS_NM_DIR"

  pack_ok=0; pack_fail=0
  for tool in "${!BROOKS_TOOLS[@]}"; do
    ver="${BROOKS_TOOLS[$tool]}"
    echo "   📥 npm pack ${tool}@${ver} ..."
    if npm pack "${tool}@${ver}" --pack-destination="$TOOLS_PACK_DIR" --silent 2>/dev/null; then
      echo "   ✅ ${tool}@${ver} .tgz 已下载"
      ((pack_ok++)) || true

      # 解压到 extracted/<tool>/
      tgz_file=
      tgz_file=$(ls -t "$TOOLS_PACK_DIR/${tool}-${ver}.tgz" 2>/dev/null | head -1)
      if [ -n "$tgz_file" ] && [ -f "$tgz_file" ]; then
        mkdir -p "$TOOLS_EXTRACT_DIR/$tool"
        tar xzf "$tgz_file" -C "$TOOLS_EXTRACT_DIR/$tool"

        # 安装生产依赖（npm pack 不含 node_modules；npm install 生成 .bin wrapper + 依赖树）
        echo "   📦 安装 ${tool} 依赖..."
        (cd "$TOOLS_EXTRACT_DIR/$tool/package" && npm install --omit=dev --ignore-scripts --legacy-peer-deps --silent 2>/dev/null) || true

        # 合并 node_modules
        if [ -d "$TOOLS_EXTRACT_DIR/$tool/package/node_modules" ]; then
          cp -rn "$TOOLS_EXTRACT_DIR/$tool/package/node_modules/"* "$TOOLS_NM_DIR/" 2>/dev/null || true
        fi
      fi
    else
      echo "   ⚠️  ${tool}@${ver} npm pack 失败，跳过"
      ((pack_fail++)) || true
    fi
  done

  # ── 为每个工具生成可执行 wrapper → 扁平 bin/ ──
  # npm install 安装依赖到 node_modules 但不创建包自身的 .bin 入口
  # 需解析 package.json bin 字段，创建指向 entry 的 shell wrapper
  if command -v jq &>/dev/null; then
    for tool in "${!BROOKS_TOOLS[@]}"; do
      pkg_json="$TOOLS_EXTRACT_DIR/$tool/package/package.json"
      if [ ! -f "$pkg_json" ]; then
        echo "   ⚠️  ${tool} package.json 未找到，跳过 wrapper"
        continue
      fi

      # 解析 bin 字段（用单次 jq 处理对象和字符串两种格式）
      entry=$(jq -r 'if (.bin | type) == "object" then .bin[(.bin | keys[0])] else .bin end' "$pkg_json")
      name=$(jq -r 'if (.bin | type) == "object" then (.bin | keys[0]) else "'"$tool"'" end' "$pkg_json")

      # 安全校验：name 不得含路径穿越字符（../ 或 /）
      case "$name" in
        *..*|*/*|*\\*) echo "   ⚠️  ${tool}: 不安全的 bin name '$name'，跳过 wrapper"; continue ;;
        *) ;;
      esac
      # 安全校验：entry 不得含 shell 元字符（防止注入）
      case "$entry" in
        *[{\"\'\;\&\|\`\$\(\)\<\>\#\!]*|*..*) echo "   ⚠️  ${tool}: 不安全的 bin entry '$entry'，跳过 wrapper"; continue ;;
        *) ;;
      esac

      # 计算 entry 相对路径（从 brooks-tools/ 根）
      entry_rel="extracted/${tool}/package/${entry#./}"
      entry_abs="$STAGING/brooks-tools/$entry_rel"

      if [ ! -f "$entry_abs" ]; then
        echo "   ⚠️  ${tool} entry 未找到: $entry_rel"
        continue
      fi

      # 生成 shell wrapper（用 printf 替代 heredoc 防止变量注入）
      printf '#!/bin/sh\nDIR="$(cd "$(dirname "$0")" && pwd)"\nNODE_PATH="$DIR/../node_modules" exec node "$DIR/../%s" "$@"\n' \
        "$entry_rel" > "$TOOLS_BIN_DIR/$name"
      chmod +x "$TOOLS_BIN_DIR/$name"
      echo "   🔧 bin/$name → $entry_rel"
    done
  else
    echo "   ⚠️  jq 未安装，跳过 wrapper 生成"
  fi

  # ── 生成 manifest.json ──
  cat > "$STAGING/brooks-tools/manifest.json" << MANIFESTEOF
{
  "tools": {
    "depcheck": "${BROOKS_TOOLS[depcheck]}",
    "jscpd": "${BROOKS_TOOLS[jscpd]}",
    "knip": "${BROOKS_TOOLS[knip]}",
    "ts-prune": "${BROOKS_TOOLS[ts-prune]}"
  },
  "platform": "linux-x64",
  "node_min": "18.0.0"
}
MANIFESTEOF

  TOOLS_FILE_COUNT=$(find "$STAGING/brooks-tools" -type f 2>/dev/null | wc -l)
  TOOLS_SIZE=$(du -sh "$STAGING/brooks-tools" 2>/dev/null | cut -f1)
  echo "   ✅ brooks-tools 打包完成（${pack_ok} 成功 / ${pack_fail} 失败，${TOOLS_FILE_COUNT} 文件，${TOOLS_SIZE}）"
fi

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
echo "║    🔧 brooks-tools（4 个 npm 工具离线包 · linux-x64）          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# ═══════════════════════════════════════════════════════════════════════
# validate_staging_coverage() — 校验 Part A~G staging 指令覆盖完整性
    echo ""
    echo "   ✅ 校验通过：所有文件均被 Part A~G 覆盖。"
    exit 0
  fi
}
