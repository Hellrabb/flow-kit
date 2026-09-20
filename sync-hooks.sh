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
#   ./sync-hooks.sh --check --strict-orphans   # 反向残留（源已删、副本仍在）也计为失败
#   ./sync-hooks.sh --list     # 列出会被处理的副本及其状态

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/flow-kit-bundle/hooks"

MODE="sync"
STRICT_ORPHANS=0
# 逐参数解析（原实现只看 $1，`--check --strict-orphans` 的第二个参数会被静默忽略 —— B5-R5 抓到）
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --list)  MODE="list" ;;
    --strict-orphans) STRICT_ORPHANS=1 ;;
    *) echo "用法: $0 [--check|--list] [--strict-orphans]" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$SRC" ] || { echo "ERROR: 源目录不存在: $SRC" >&2; exit 2; }

# ── 副本清单（按 install_hooks.sh 的实际安装位置）──
DEST_ROOTS=(
  "$SCRIPT_DIR/.claude/hooks"                                                  # 仓库级 claude 安装
  "$HOME/.claude/hooks"                                                        # 用户级 claude 安装
  "$SCRIPT_DIR/dist/dsh-flow-kit/hooks"                                        # dsh 插件包顶层
  "$SCRIPT_DIR/dist/dsh-flow-kit/vendor/flow-kit-bundle/hooks"                 # dsh 插件包内 bundle 副本
  "$HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks"                    # dsh 运行时（已安装插件）
  "$HOME/.dsh/profiles/web/node_modules/dsh-flow-kit/vendor/flow-kit-bundle/hooks"
  "$HOME/.config/opencode/hooks"                                               # opencode 平台安装
)

# ── 待镜像的相对路径 ──
# stop 模块**与 install_hooks.sh 同源**（common.sh::HOOK_MODULE_NAMES），而不是目录通配：
# 通配会把安装器根本不会安装的脚本也纳入比对（草稿 / 实验脚本 / 已移除模块的遗留），
# 产生假漂移噪音，最终把门禁磨成橡皮章（1-requirement 的 L2 盲审 R4）。
collect_rel_paths() {
  local f b name
  local names
  names="$(bash -c "source '$SRC/stop/lib/common.sh' 2>/dev/null; printf '%s\n' \"\${HOOK_MODULE_NAMES[@]}\"" 2>/dev/null)"
  if [ -n "$names" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] && printf 'stop/%s.sh\n' "$name"
    done <<< "$names"
  else
    # 兜底：common.sh 取不到清单时退回通配（宁可多比对，不可漏比对）
    for f in "$SRC"/stop/*.sh; do
      [ -e "$f" ] || continue
      printf 'stop/%s\n' "$(basename "$f")"
    done
  fi
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

# ── flow-kit/prompts 树（固化指令载体 · 2-design 期 L2 五审 R1/R2 补）──
# 为什么 hooks 之外还要镜像 prompts：L2 固化指令 `L2-blind-review.md` 是**行为契约**
# （本 change 在其中新增了"贴入前必须转义"第 4 条）。它同样存在 7~8 份安装副本，
# 且此前**完全不在任何漂移门禁内** —— 上一轮主 agent 只手工同步了 2 处就宣称"已安装副本
# clause4=1/1"，被 L2 盲审实测证伪（实际有 7 份，4 份陈旧）。
# 镜像范围：<pkgroot>/flow-kit/prompts/** ↔ 源的 flow-kit-bundle/flow-kit/prompts/**
PROMPT_SRC="$SCRIPT_DIR/flow-kit-bundle/flow-kit/prompts"

# ── L2 reviewer agent（复合载体：头部 + L2 固化指令**全文拷贝**）──
# `flow-kit/.opencode/agent/flow-kit-l2-reviewer.md` 自声明「本段是 L2-blind-review.md 的
# 全文拷贝，必须与源文件保持一致（L-031 锚点）」。它是**复合**文件（yaml 头 + 角色 + 拷贝段），
# 故不能用通用镜像 —— 这里按「保留头部、重放拷贝段」重新生成，保同步为机械动作。
AGENT_REL=".opencode/agent/flow-kit-l2-reviewer.md"
AGENT_SRC="$SCRIPT_DIR/flow-kit-bundle/flow-kit/$AGENT_REL"
AGENT_MARK='# L2 独立盲审员 · 固化指令'

regen_l2_agent() {
  local head_tmp new_tmp
  [ -f "$AGENT_SRC" ] || return 0
  [ -f "$PROMPT_SRC/independent/L2-blind-review.md" ] || return 0
  head_tmp="$(mktemp)" || return 0
  # 头部 = 到拷贝段起点之前（含来源/同步要求说明）
  awk -v m="$AGENT_MARK" 'index($0,m)==1{exit} {print}' "$AGENT_SRC" > "$head_tmp"
  new_tmp="$(mktemp)" || { rm -f "$head_tmp"; return 0; }
  cat "$head_tmp" "$PROMPT_SRC/independent/L2-blind-review.md" > "$new_tmp"
  # **只读语义**（七审 R3）：--check/--list 绝不落盘。早先版本在脚本加载时无条件重放拷贝段，
  # 导致"只读检查"改写仓库文件，且使复合载体的漂移**永远无法被报告**（先修好再比对，自然一致）。
  if ! cmp -s "$new_tmp" "$AGENT_SRC" 2>/dev/null; then
    AGENT_REGEN_NEEDED=1
    [ "${MODE:-}" = "sync" ] && { cp "$new_tmp" "$AGENT_SRC"; AGENT_REGEN_NEEDED=0; }
  fi
  rm -f "$head_tmp" "$new_tmp"
}
AGENT_REGEN_NEEDED=0
regen_l2_agent
collect_prompt_paths() {
  local rel
  [ -d "$PROMPT_SRC" ] || return 0
  (cd "$PROMPT_SRC" && find . -type f | sed 's|^\./||' | sort)
  # 复合载体：L2 reviewer agent（其拷贝段由 regen_l2_agent 保证与源一致）
  [ -f "$SCRIPT_DIR/flow-kit-bundle/flow-kit/$AGENT_REL" ] && printf '%s\n' "$AGENT_REL"
}
mapfile -t PROMPT_PATHS < <(collect_prompt_paths)


# 反向告警：stop/ 下存在但不在 HOOK_MODULE_NAMES 里的脚本 —— 安装器不会安装它们，
# 也就永远不会被同步/漂移检测覆盖。这是"安装集本身漂移"的信号，必须可见。
collect_stop_extras() {
  local names f b
  names="$(bash -c "source '$SRC/stop/lib/common.sh' 2>/dev/null; printf '%s.sh\n' \"\${HOOK_MODULE_NAMES[@]}\"" 2>/dev/null)" || return 0
  [ -n "$names" ] || return 0
  for f in "$SRC"/stop/*.sh; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    printf '%s\n' "$names" | grep -qxF "$b" || printf '%s\n' "$b"
  done
}
mapfile -t REL_PATHS < <(collect_rel_paths | sort -u)
mapfile -t STOP_EXTRAS < <(collect_stop_extras | sort -u)

drift_total=0
orphan_total=0
synced_total=0
root_fail=0
nonexec_total=0

printf '源: %s\n' "$SRC"
printf '镜像文件数: %d（stop 模块与 install_hooks.sh 同源计数）\n' "${#REL_PATHS[@]}"
if [ "${#STOP_EXTRAS[@]}" -gt 0 ]; then
  printf '⚠️  stop/ 下有 %d 个脚本不在 HOOK_MODULE_NAMES 中（安装器不会安装，故不纳入镜像/漂移检测）:\n' "${#STOP_EXTRAS[@]}"
  printf '     %s\n' "${STOP_EXTRAS[@]}"
fi
printf '\n' 

for root in "${DEST_ROOTS[@]}"; do
  if [ ! -d "$root" ]; then
    [ "$MODE" = "list" ] && printf '  ⏭️  %s — 不存在，跳过\n' "$root"
    continue
  fi
  drift=0
  missing_dst=0
  nonexec=0
  miss_prompt=0
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
    # 的契约管理。此处只做**只读提示**，不改动副本权限 —— 免得同步顺手改出一堆
    # 与本次修复无关的 mode 变更，把 diff 搅浑。
    #
    # ── 判据收窄为「仅真入口」（health-fix-2026-09 · T03 / DESIGN D4）──
    # **理由**：原按目录判定会把只被 source 的库也要求 -x，产出 5 处假告警、把 warn 训练成噪声
    # 原判据 `stop/*.sh|session-start/*.sh|pre-tool-use/*.sh` 按**目录**判定，
    # 把 pre-tool-use/ 下 4 个「只被 source、从不被直接执行」的库也要求 -x
    # （gate-helpers / gate-helpers-types / gate-checks-basic / gate-checks-review）。
    # 实测这 4 个库零直接调用点（全仓 grep `bash <file>` / `./<file>` 均无命中），
    # 且 install_hooks.sh 会对所有部署副本统一 chmod +x → 源侧无 exec 位**零功能影响**。
    # 原判据长期产出 5 处假告警（.claude/hooks 1 + dist vendor 4），会把这条 warn
    # 训练成噪声 —— 真入口丢 exec 位时反而没人看。
    # 判据现在表达真实契约：**只有真入口需要 exec 位**。
    #
    # ⚠️ 真入口白名单维护：**新增 pre-tool-use 入口必须登记此处**（DESIGN R4/R6 的缓解）。
    # pre-tool-use/ 下当前 3 个真入口（被 settings.json / hook-bridge 直接 bash 调用）：
    PTU_ENTRIES="pre-tool-use/independent-review-gate.sh pre-tool-use/auto-checkpoint.sh pre-tool-use/runtime-edit-guard.sh"
    is_real_entry() {
      # ⚠️ bash glob 的 `*` **会跨 `/`** —— 故必须先排除 stop/lib/，否则
      # `stop/*.sh` 会把 stop/lib/common.sh 也匹配成入口（实测：该顺序错误导致
      # 108 处误报，全部被当成"入口"）。目录层级必须显式区分。
      case "$1" in
        */*/*) return 1 ;;                            # 三层以上（stop/lib/*、*/*/*）一律是库
        stop/*.sh|session-start/*.sh|pre-commit/*.sh) return 0 ;;
      esac
      case " $PTU_ENTRIES " in *" $1 "*) return 0 ;; esac
      return 1
    }
    if [ -f "$dst_f" ] && [ ! -x "$dst_f" ] && is_real_entry "$rel"; then
      nonexec=$((nonexec + 1))
      # 指名：**所有模式**都打印具体路径 —— 原实现只在 MODE=list 打印，
      # `--check` 只给聚合计数，维护者拿到"有 N 个入口缺 exec 位"却无法定位（T03 的核心缺口）。
      printf '     ⚠️  不可执行（跑 install.sh 修）：%s\n' "$root/$rel"
    fi
  done

  # ── prompts 树镜像（<pkgroot>/flow-kit/prompts）──
  # pkgroot = 该 hooks 目录的父目录；仅当副本已带 flow-kit/prompts 时才镜像（不凭空创建安装）
  pkgroot="$(dirname "$root")"
  prompt_dst="$pkgroot/flow-kit/prompts"
  if [ -d "$prompt_dst" ] && [ "${#PROMPT_PATHS[@]}" -gt 0 ]; then
    for rel in "${PROMPT_PATHS[@]}"; do
      # 复合载体（L2 reviewer agent）不在 prompts/ 下，而在 <pkgroot>/flow-kit/<AGENT_REL>
      # 复合载体：源在 <pkgroot>/flow-kit/<AGENT_REL>，目的同构（**不在 prompts/ 之下**）
      if [ "$rel" = "$AGENT_REL" ]; then
        src_f="$AGENT_SRC"; dst_f="$pkgroot/flow-kit/$rel"
      else
        src_f="$PROMPT_SRC/$rel"; dst_f="$prompt_dst/$rel"
      fi
      if [ ! -f "$dst_f" ]; then
        drift=$((drift + 1)); miss_prompt=$((miss_prompt + 1))
        [ "$MODE" = "sync" ] && { mkdir -p "$(dirname "$dst_f")"; cp "$src_f" "$dst_f"; }
      elif ! cmp -s "$src_f" "$dst_f"; then
        drift=$((drift + 1))
        [ "$MODE" = "sync" ] && cp "$src_f" "$dst_f"
      fi
    done
    [ "$MODE" = "list" ] && printf '     ↳ prompts 树已纳入镜像: %s\n' "$prompt_dst"
  fi

  # config/stop-hook.json：仅当副本自带 config/ 目录（插件包 / dist）才镜像
  if [ -d "$root/config" ] && [ -f "$SRC/config/stop-hook.json" ]; then
    if ! cmp -s "$SRC/config/stop-hook.json" "$root/config/stop-hook.json" 2>/dev/null; then
      drift=$((drift + 1))
      [ "$MODE" = "sync" ] && cp "$SRC/config/stop-hook.json" "$root/config/stop-hook.json"
    fi
  fi

  # ── 反向残留（orphan）：副本里有、源里没有的 hook 文件 ──
  # 为什么必须看反向（阶段 2 的 L3 19:15 major②）：同步契约是「只增改不删除」，源里删掉/改名的
  # hook 会**永久残留**在副本里继续被加载执行（旧逻辑 = 潜在的行为回归，且正向比对永远发现不了）。
  # 默认 advisory（`~/.claude/hooks` 可能含第三方工具的 hook，误报会拦住正常安装）；
  # `--strict-orphans` 时计入失败（CI 想强约束时用）。
  orphans=""
  for _d in stop stop/lib pre-tool-use pre-commit; do
    [ -d "$root/$_d" ] || continue
    for _f in "$root/$_d"/*; do
      [ -f "$_f" ] || continue
      _rel="${_d}/$(basename "$_f")"
      case "$_rel" in
        stop/*.sh|stop/lib/*.sh|pre-tool-use/*.sh|pre-commit/*.sh) ;;
        *) continue ;;
      esac
      [ -f "$SRC/$_rel" ] && continue          # 源里在 → 不是残留
      case " ${REL_PATHS[*]} " in *" $_rel "*) continue ;; esac   # 源里在（镜像清单）→ 跳过
      orphans+="$_rel "
    done
  done
  if [ -n "$orphans" ]; then
    _n=$(printf '%s' "$orphans" | wc -w)
    orphan_total=$((orphan_total + _n))
    case "$MODE" in
      check)
        if [ "$STRICT_ORPHANS" = "1" ]; then
          printf '  ❌ %s — 反向残留 %d 个（源已删/改名，副本仍在跑）: %s\n' "$root" "$_n" "$orphans"; root_fail=1
        else
          printf '  ⚠️  %s — 反向残留 %d 个（advisory；--strict-orphans 可升级为失败）: %s\n' "$root" "$_n" "$orphans"
        fi ;;
      list) printf '     ↳ 反向残留: %s\n' "$orphans" ;;
    esac
  fi
  unset _d _f _rel orphans _n

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

# ── 平台级 agent 目的路径（opencode 把 agent 装在 <PLATFORM_CONFIG_DIR>/agent/）──
# install_hooks.sh:151 的等价位置；不在任何 flow-kit 子树下，故单列。
# （2-design 期 L2 五审 R1/R2：这个载体此前完全不在漂移门禁内，是"已安装副本 clause4"被
#   实测证伪的直接原因 —— 7 份 prompt 副本 + 1 份 agent 复合载体，此前只有 2 份被手工同步。）
_agent_dst="$HOME/.config/opencode/agent/flow-kit-l2-reviewer.md"
if [ -f "$_agent_dst" ] && ! cmp -s "$AGENT_SRC" "$_agent_dst" 2>/dev/null; then
  drift_total=$((drift_total + 1))
  case "$MODE" in
    sync)  cp "$AGENT_SRC" "$_agent_dst"; printf '  🔄 同步平台级 agent: %s\n' "$_agent_dst" ;;
    check) printf '  ❌ 平台级 agent 与源不一致: %s\n' "$_agent_dst"; root_fail=1 ;;
    list)  printf '  ⚠️  平台级 agent 漂移: %s\n' "$_agent_dst" ;;
  esac
fi
unset _agent_dst

[ "$nonexec_total" -gt 0 ] && \
  echo "⚠️  ${nonexec_total} 个 hook 入口缺可执行位（本工具不改权限；跑 install.sh 修）"

if [ "${AGENT_REGEN_NEEDED:-0}" = "1" ]; then
  drift_total=$((drift_total + 1))
  case "$MODE" in
    check) printf '  ❌ 复合载体拷贝段与源不一致（需重放）: %s\n' "$AGENT_SRC"; root_fail=1 ;;
    list)  printf '  ⚠️  复合载体拷贝段需重放: %s\n' "$AGENT_SRC" ;;
  esac
fi

echo
case "$MODE" in
  check)
    # 源侧安装集漂移（stop/ 下有脚本不在 HOOK_MODULE_NAMES）→ 必须失败，不能只告警：
    # 否则"安装集收缩"这类治理动作在 make check 上表现为全绿（1-requirement 的 L2 盲审 R6）。
    if [ "${#STOP_EXTRAS[@]}" -gt 0 ]; then
      echo "❌ 源侧安装集漂移：stop/ 下有 ${#STOP_EXTRAS[@]} 个脚本不在 HOOK_MODULE_NAMES 中（安装器不会安装它们）" >&2
      root_fail=1
    fi
    if [ "$root_fail" -eq 0 ]; then
      echo "✅ hooks 副本一致（漂移 0）"
      exit 0
    fi
    echo "❌ hooks 门禁失败（漂移 ${drift_total} 个文件 / 安装集漂移 ${#STOP_EXTRAS[@]} 项）。跑 ./sync-hooks.sh 或修 HOOK_MODULE_NAMES。" >&2
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
