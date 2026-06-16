# lib/install_brooks.sh — brooks-lint 代码审查插件安装
# 由 install.sh source，不可独立执行

install_brooks_lint() {
  echo ""
  echo "═══ 安装 brooks-lint 代码审查插件 ═══"

  local plugin_src="$SCRIPT_DIR/brooks-lint/plugin"

  # 动态读取 brooks-lint 版本号（D7）
  local brooks_version
  if command -v jq &>/dev/null && [ -f "$plugin_src/.claude-plugin/plugin.json" ]; then
    brooks_version=$(jq -r '.version' "$plugin_src/.claude-plugin/plugin.json" 2>/dev/null) || true
  fi
  if [ -z "${brooks_version:-}" ] && [ -f "$plugin_src/.claude-plugin/plugin.json" ]; then
    # fallback: grep + sed 提取 version 字段
    brooks_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$plugin_src/.claude-plugin/plugin.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/') || true
  fi
  brooks_version="${brooks_version:-unknown}"

  local plugin_dst="$HOME/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/${brooks_version}"

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
  #     同时写一份到 marketplaces/（marketplace 源目录，备查 / 手工重装）
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
  for hook_dir in "$plugin_dst" "$mkt_dst"; do
    local hook_file="$hook_dir/hooks/session-start"
    if [ -f "$hook_file" ]; then
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
  "version": "${brooks_version}",
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

  # F4: 注册 marketplace 到 known_marketplaces.json
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
