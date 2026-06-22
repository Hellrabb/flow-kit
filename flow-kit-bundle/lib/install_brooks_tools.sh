# lib/install_brooks_tools.sh — brooks-lint npm 工具离线安装
# 由 install.sh source，不可独立执行

install_brooks_tools() {
  echo ""
  echo "═══ 安装 brooks-lint npm 工具（离线） ═══"

  # ── 工具定义 ──
  local tools_src="$SCRIPT_DIR/brooks-tools"
  local tools_dst="$HOME/.claude/tools/brooks-lint"
  local bin_dst="$HOME/.local/bin"

  # ── 1. Node.js 前置检测 ──
  if ! command -v node &>/dev/null; then
    echo "   ⚠️  Node.js 未安装，跳过 brooks-lint 工具安装。"
    echo "   请先安装 Node.js ≥ 18：dnf module install nodejs:18"
    return
  fi
  echo "   ✅ Node.js $(node --version) 已检测到"

  # ── 2. 源目录检测 ──
  if [ ! -d "$tools_src" ]; then
    echo "   ⚠️  brooks-tools/ 源目录不存在，跳过（离线包未包含在此 bundle 中）"
    return
  fi

  if [ "${DRY_RUN:-false}" = true ]; then
    echo "   [DRY-RUN] rsync $tools_src/ -> $tools_dst/"
    echo "   [DRY-RUN] 生成 shim: $bin_dst/depcheck"
    echo "   [DRY-RUN] 生成 shim: $bin_dst/jscpd"
    echo "   [DRY-RUN] 生成 shim: $bin_dst/knip"
    echo "   [DRY-RUN] 生成 shim: $bin_dst/ts-prune"
    return
  fi

  # ── 3. 复制工具到 ~/.claude/tools/brooks-lint/ ──
  mkdir -p "$tools_dst"
  if command -v rsync &>/dev/null; then
    rsync -a "$tools_src/" "$tools_dst/"
  else
    cp -r "$tools_src/"* "$tools_dst/"
  fi
  # 确保 bin/ 下所有文件可执行（兜底：cp -r 不保留权限 / tar 解压丢失 x-bit）
  find "$tools_dst/bin" -type f 2>/dev/null | while read -r f; do chmod +x "$f"; done
  local tool_count
  tool_count=$(find "$tools_dst/bin" -type f 2>/dev/null | wc -l)
  echo "   ✅ brooks-tools 已安装到 $tools_dst（${tool_count} 个可执行文件）"

  # ── 4. 生成 shim → ~/.local/bin/ ──
  mkdir -p "$bin_dst"

  local shim_count=0
  for tool_name in depcheck jscpd knip ts-prune; do
    local tool_path="$tools_dst/bin/$tool_name"
    if [ -f "$tool_path" ]; then
      # 检测目标 shim 是否已存在且不是我们管理的
      if [ -f "$bin_dst/$tool_name" ] && ! grep -q "brooks-lint" "$bin_dst/$tool_name" 2>/dev/null; then
        echo "   ⚠️  $bin_dst/$tool_name 已存在（非 brooks-lint 管理），跳过（已有版本：$($bin_dst/$tool_name --version 2>/dev/null || echo 'unknown')）"
        continue
      fi
      cat > "$bin_dst/$tool_name" << SHIMEOF
#!/bin/sh
exec "$tools_dst/bin/$tool_name" "\$@"
SHIMEOF
      chmod +x "$bin_dst/$tool_name"
      echo "   ✅ shim 已创建: $bin_dst/$tool_name"
      ((shim_count++)) || true
    else
      echo "   ⚠️  工具 $tool_name 未找到于 $tools_dst/bin/，跳过 shim 生成"
    fi
  done

  # ── 5. 检测 ~/.local/bin 是否在 PATH ──
  if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$bin_dst"; then
    echo "   ⚠️  $bin_dst 不在 PATH 中。请将以下行添加到 ~/.bashrc 或 ~/.bash_profile："
    echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
  else
    echo "   ✅ $bin_dst 已在 PATH 中"
  fi

  # ── 6. 验证安装（输出版本号） ──
  echo ""
  local failed=0
  for tool_name in depcheck jscpd knip ts-prune; do
    if [ -x "$bin_dst/$tool_name" ]; then
      local ver
      ver=$("$bin_dst/$tool_name" --version 2>/dev/null | head -1) || true
      if [ -n "$ver" ]; then
        echo "   ✅ $tool_name $ver"
      else
        echo "   ⚠️  $tool_name 安装成功但无法获取版本（可能需要 Node.js ≥ 18）"
      fi
    else
      echo "   ⚠️  $tool_name shim 不可执行"
      ((failed++)) || true
    fi
  done

  if [ "$failed" -eq 0 ]; then
    echo "   ✅ brooks-lint 工具安装完成（${shim_count} 个 shim）"
  else
    echo "   ⚠️  brooks-lint 工具安装部分失败（${failed} 个失败）"
  fi
}
