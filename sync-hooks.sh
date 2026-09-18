#!/bin/bash
# sync-hooks.sh — 把 flow-kit-bundle/hooks/（唯一维护源）镜像到各安装副本
#
# 背景（L3-review-defects-2026-09-17 §B5）：
#   同一套 hook 在机器上存在多处副本。历史上修完源、忘了同步副本，导致
#   「同一 change 换条运行路径结论不同」——Claude Code 路径跑的是旧代码。
#   2026-09-17 实测：`~/.claude/hooks` 停在 2026-09-03，缺 2026-09-11 的
#   P0-1（熔断出口）/ P0-2（artifact cap 接线）两处修复，grep 计数 0/0。
#
# 本脚本把 install_hooks.sh 的**安装文件集**原样镜像到每个已存在的副本：
#   stop/<HOOK_MODULE_NAMES>.sh · stop/lib/*.sh · pre-tool-use/*.sh
#   session-start/{flow-kit-resume,stop-report-reminder}.sh · pre-commit/pre-commit.sh
#   config/stop-hook.json（仅副本已带 config/ 时——即插件包与 dist，用户级不带）
#
# 契约：
#   - **只增改、不删除**：副本里属于别的工具的额外文件一律不动。
#   - 副本目录不存在 → 跳过（不凭空创建安装）。
#   - 幂等：源与副本已一致时不写盘。
#
# 用法:
#   ./sync-hooks.sh            # 同步所有已存在的副本
#   ./sync-hooks.sh --check    # 只比对不写盘；有漂移 exit 1（CI / make check 用）
#   ./sync-hooks.sh --list     # 列出会被处理的副本及其状态

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/flow-kit-bundle/hooks"

MODE="sync"
case "${1:-}" in
  --check) MODE="check" ;;
  --list)  MODE="list" ;;
  "")      ;;
  *) echo "用法: $0 [--check|--list]" >&2; exit 2 ;;
esac

[ -d "$SRC" ] || { echo "ERROR: 源目录不存在: $SRC" >&2; exit 2; }

# ── 副本清单（按 install_hooks.sh 的实际安装位置）──
DEST_ROOTS=(
  "$SCRIPT_DIR/.claude/hooks"                                                  # 仓库级 claude 安装
  "$HOME/.claude/hooks"                                                        # 用户级 claude 安装
  "$SCRIPT_DIR/dist/dsh-flow-kit/hooks"                                        # dsh 插件包顶层
  "$SCRIPT_DIR/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks"                 # dsh 插件包内 bundle 副本
  "$HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks"                    # dsh 运行时（已安装插件）
  "$HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks"
)

# ── 待镜像的相对路径（严格对齐 install_hooks.sh 的安装集）──
collect_rel_paths() {
  local f b
  for f in "$SRC"/stop/*.sh; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    printf 'stop/%s\n' "$b"
  done
  for f in "$SRC"/stop/lib/*.sh; do
    [ -e "$f" ] || continue
    printf 'stop/lib/%s\n' "$(basename "$f")"
  done
  for f in "$SRC"/pre-tool-use/*.sh; do
    [ -e "$f" ] || continue
    printf 'pre-tool-use/%s\n' "$(basename "$f")"
  done
  for b in flow-kit-resume stop-report-reminder; do
    [ -f "$SRC/session-start/${b}.sh" ] && printf 'session-start/%s.sh\n' "$b"
  done
  [ -f "$SRC/pre-commit/pre-commit.sh" ] && printf 'pre-commit/pre-commit.sh\n'
}
mapfile -t REL_PATHS < <(collect_rel_paths | sort -u)

drift_total=0
synced_total=0
root_fail=0
nonexec_total=0

printf '源: %s\n' "$SRC"
printf '镜像文件数: %d\n\n' "${#REL_PATHS[@]}"

for root in "${DEST_ROOTS[@]}"; do
  if [ ! -d "$root" ]; then
    [ "$MODE" = "list" ] && printf '  ⏭️  %s — 不存在，跳过\n' "$root"
    continue
  fi
  drift=0
  missing_dst=0
  nonexec=0
  for rel in "${REL_PATHS[@]}"; do
    src_f="$SRC/$rel"
    dst_f="$root/$rel"
    if [ ! -f "$dst_f" ]; then
      missing_dst=$((missing_dst + 1))
      drift=$((drift + 1))
      [ "$MODE" = "sync" ] && { mkdir -p "$(dirname "$dst_f")"; cp "$src_f" "$dst_f"; }
    elif ! cmp -s "$src_f" "$dst_f"; then
      drift=$((drift + 1))
      [ "$MODE" = "sync" ] && cp "$src_f" "$dst_f"
    fi
    # 权限位：本工具**只管内容**（B5 的缺陷是内容漂移）。可执行位归 install_hooks.sh
    # 的契约管理（它只对 stop/<module>.sh、session-start/*.sh、pre-tool-use/*.sh 做
    # chmod +x）。此处只做**只读提示**，不改动副本权限 —— 免得同步顺手改出一堆
    # 与本次修复无关的 mode 变更，把 diff 搅浑。
    case "$rel" in
      stop/lib/*) ;;
      stop/*.sh|session-start/*.sh|pre-tool-use/*.sh)
        if [ -f "$dst_f" ] && [ ! -x "$dst_f" ]; then
          nonexec=$((nonexec + 1))
          [ "$MODE" = "list" ] && printf '     ⚠️  不可执行（跑 install.sh 修）：%s\n' "$root/$rel"
        fi
        ;;
    esac
  done

  # config/stop-hook.json：仅当副本自带 config/ 目录（插件包 / dist）才镜像
  if [ -d "$root/config" ] && [ -f "$SRC/config/stop-hook.json" ]; then
    if ! cmp -s "$SRC/config/stop-hook.json" "$root/config/stop-hook.json" 2>/dev/null; then
      drift=$((drift + 1))
      [ "$MODE" = "sync" ] && cp "$SRC/config/stop-hook.json" "$root/config/stop-hook.json"
    fi
  fi

  drift_total=$((drift_total + drift))
  nonexec_total=$((nonexec_total + nonexec))
  case "$MODE" in
    list)
      if [ "$drift" -eq 0 ]; then printf '  ✅ %s\n' "$root"
      else printf '  ⚠️  %s — %d 个文件漂移（%d 个副本缺失）\n' "$root" "$drift" "$missing_dst"; fi
      ;;
    check)
      if [ "$drift" -eq 0 ]; then printf '  ✅ %s\n' "$root"
      else printf '  ❌ %s — %d 个文件与源不一致（%d 个副本缺失）\n' "$root" "$drift" "$missing_dst"; root_fail=1; fi
      ;;
    sync)
      if [ "$drift" -eq 0 ]; then printf '  ✅ %s（已一致）\n' "$root"
      else printf '  🔄 %s — 同步 %d 个文件（其中 %d 个副本缺失）\n' "$root" "$drift" "$missing_dst"; fi
      synced_total=$((synced_total + drift))
      ;;
  esac
done

[ "$nonexec_total" -gt 0 ] && \
  echo "⚠️  ${nonexec_total} 个 hook 入口缺可执行位（本工具不改权限；跑 install.sh 修）"

echo
case "$MODE" in
  check)
    if [ "$root_fail" -eq 0 ]; then
      echo "✅ hooks 副本一致（漂移 0）"
      exit 0
    fi
    echo "❌ hooks 副本存在漂移：共 ${drift_total} 个文件。跑 ./sync-hooks.sh 修（或 make hooks-sync）。" >&2
    exit 1
    ;;
  sync)
    if [ "$synced_total" -eq 0 ]; then echo "✅ 全部副本已一致，无需同步"
    else echo "✅ 已同步 ${synced_total} 个文件"; fi
    ;;
  list)
    echo "（--list 只读；跑 ./sync-hooks.sh 或 make hooks-sync 落盘）"
    ;;
esac
