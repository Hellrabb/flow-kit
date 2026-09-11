#!/bin/bash
# runtime-edit-guard.sh — PreToolUse 拦截 AI 改运行时副本（L-015 闭合 · 平台解耦）
#
# settings.json matcher: ["Write","Edit"]。
# claude/opencode：拦 Write/Edit 到 ~/.claude/hooks/ 或 ~/.claude/skills/ 下的文件。
# dsh：拦 Write/Edit 到 ~/.dsh/skills/ 或任意 */node_modules/dsh-flow-kit/ 下的文件。
# 当对应维护源（flow-kit-bundle/hooks|skills/...）存在时，redirect AI 改源不改运行时。
#
# 触发条件（全部满足才 deny）：
#   1. tool_name ∈ {Write, Edit}
#   2. tool_input.file_path 命中 ~/.claude/{hooks,skills}/
#   3. 对应 flow-kit-bundle/ 维护源存在（否则放行——可能是不属于 flow-kit 的 user-level 配置）
#
# fail 策略：fail-open（拦不住不卡 agent 工具流）
#
# PreToolUse stdin: {hook_event_name, tool_name, tool_input:{file_path}, ...}
# exit 2 = deny（agent 看得到 stderr 引导消息）
# exit 0 = 放行
#
# change: debt-audit-resolve-2026-08 (2026-08-04), closes L-015

set -euo pipefail

# ── fail-open wrapper ─────────────────────────────────────────────────────
# 任何意外错误（jq 不可用 / stdin 解析失败 / 路径计算错误）→ 放行，不阻塞 agent。
main() {
  local stdin_data
  stdin_data=$(cat 2>/dev/null) || return 0

  # 提取 tool_name + file_path
  local tool_name file_path
  tool_name=$(echo "$stdin_data" | jq -r '.tool_name // empty' 2>/dev/null) || return 0
  file_path=$(echo "$stdin_data" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || return 0

  # 仅 Write/Edit 触发
  case "$tool_name" in
    Write|Edit) ;;
    *) return 0 ;;
  esac

  # 路径必须非空
  [[ -n "$file_path" ]] || return 0

  # 规范化路径（展开 ~ + 相对路径转绝对）
  local real_path
  real_path=$(eval echo "$file_path" 2>/dev/null) || real_path="$file_path"

  # ── 平台感知的运行时副本判定（dsh-flow-kit 解耦）──
  local runtime_kind=""
  local rel_to_runtime=""
  if [ "${FLOW_KIT_RUNTIME:-}" = "dsh" ]; then
    if [[ "$real_path" =~ ^$HOME/\.dsh/skills/ ]]; then
      runtime_kind="dsh-home"
      rel_to_runtime="${real_path#$HOME/.dsh/}"
    elif [[ "$real_path" == */node_modules/dsh-flow-kit/* ]]; then
      runtime_kind="dsh-node-modules"
      rel_to_runtime="${real_path#*/node_modules/dsh-flow-kit/}"
    fi
  else
    if [[ "$real_path" =~ ^$HOME/\.claude/(hooks|skills)/ ]]; then
      runtime_kind="claude"
      rel_to_runtime="${real_path#$HOME/.claude/}"
    fi
  fi
  [[ -n "$runtime_kind" ]] || return 0

  # 找对应 flow-kit-bundle/ 维护源
  # 策略：从 cwd 向上查找含 flow-kit-bundle/ 的目录（项目根）
  local project_root="$PWD"
  while [[ "$project_root" != "/" && ! -d "$project_root/flow-kit-bundle" ]]; do
    project_root=$(dirname "$project_root")
  done
  [[ -d "$project_root/flow-kit-bundle" ]] || return 0  # 项目外，放行

  # 从运行时路径推导维护源路径：
  #   ~/.claude/hooks/stop/X.sh         → flow-kit-bundle/hooks/stop/X.sh
  #   ~/.claude/skills/flow/X           → flow-kit-bundle/skills/X
  #   */node_modules/dsh-flow-kit/X     → flow-kit-bundle/X
  local source_path="$project_root/flow-kit-bundle/$rel_to_runtime"

  # 维护源存在 → deny + redirect
  if [[ -f "$source_path" ]]; then
    cat >&2 <<EOF
⛔ runtime-edit-guard: 检测到改运行时副本（${runtime_kind}）

你正在编辑: $real_path
维护源在:   $source_path

按 CONTEXT.md 禁动清单约定：该文件是安装/打包部署的运行时副本，
改它会在下次 install.sh / package-dsh-plugin.sh 时被覆盖。
请改 flow-kit-bundle/ 下的源文件，然后重新安装/打包部署。

如果你确实要改这个 user-level 文件（非 flow-kit 管理），请在路径前加 /tmp/ 绕过本 guard
（不推荐——通常说明你的改动应该归到 flow-kit-bundle/ 维护源）。
EOF
    return 2
  fi

  # 维护源不存在 → 放行（user-level 配置，与 flow-kit 无关）
  return 0
}

main "$@"
