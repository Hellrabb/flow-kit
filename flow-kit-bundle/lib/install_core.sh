# lib/install_core.sh — flow-kit 核心引擎安装
# 由 install.sh source，不可独立执行

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

  # Sanity check: 关键文件存在性校验
  local missing=0
  for f in "GO.md" "prompts/1-requirement.md" "prompts/4-dev.md" "prompts/7-integration.md"; do
    if [[ ! -f "$dst/$f" ]]; then
      echo "   ⚠️  MISSING: $dst/$f"
      missing=$((missing + 1))
    fi
  done
  if [[ $missing -gt 0 ]]; then
    echo "   ❌ $missing 个关键文件缺失，安装可能不完整"
    return 1
  fi
  echo "   ✅ 关键文件校验通过"
}
