# lib/install_hooks.sh — Stop Hook + SessionStart 安装 + .specs 模板
# shellcheck shell=bash
# 由 install.sh source，不可独立执行
# 依赖：lib/paths.sh（PLATFORM, USER_HOOKS_DIR, PROJECT_DIR_NAME, HOOKS_PROJECT_VAR_REF,
#                     HOOKS_USER_VAR_REF, USER_HOOKS_DIR, settings_file_for）
# 自加载：被直接 source 时（测试 / 独立调用）install_hooks() 内部自动 source paths.sh
# 环境变量 FLOW_KIT_PLATFORM 可覆盖平台（claude|opencode · 非法值→claude 默认）
#
# 平台行为：
#   claude
#     - hooks 装到 ~/.claude/hooks (user) 或 $project/.claude/hooks (project)
#     - settings 写 ~/.claude/settings.json (user) 或 $project/.claude/settings.local.json
#     - hook 命令引用 ${CLAUDE_PROJECT_DIR} (Claude Code 原生 env)
#     - agent 不装（CC 用 subagent_type 原生派发 L2 审查，无需独立 agent 文件）
#   opencode
#     - hooks 装到 ~/.config/opencode/hooks (user) 或 $project/.opencode/hooks (project)
#     - settings 写 ~/.claude/settings.json (user) 或 $project/.claude/settings.local.json
#       ↑ opencode 不读 settings.json，但 opencode-claude-hooks 桥接插件读
#         保持 Claude 格式让用户安装桥接插件即可启用
#     - hook 命令仍引用 ${CLAUDE_PROJECT_DIR}（桥接插件会注入此 env）
#     - agent (flow-kit-l2-reviewer) 装到 ~/.config/opencode/agent/ (user)
#       或 $project/.opencode/agent/ (project)

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

# ── 原子写 ────────────────────────────────────────────────────────────
# write_settings_file_atomic <target> <content>
# 为什么不能直接 `内容 > "$target"`（DESIGN D7/R4 · PC2）：重定向由 shell 在写入
# **之前**就截断目标文件，一旦后续步骤失败就留下 0 字节 / 半写的 settings.json
# （实测缺 jq 时既有文件 122B → 0B）。改为「同目录 mktemp 临时文件 + mv」：
# 同文件系统 ⇒ mv 是 rename，读者要么看到旧文件、要么看到新文件；trap 兜底清理
# 临时文件（R4 要求），失败时**目标文件保持原状**。
# 沿用仓内既有原子写范式（hooks/stop/lib/correction-file.sh:221 起）：失败 rm -f 临时文件。
write_settings_file_atomic() {
  local target="$1" content="$2"
  local tmp
  if ! tmp=$(mktemp "${target}.tmp.XXXXXX"); then
    echo "   ⚠️  无法在 $(dirname "$target") 创建临时文件，${target} 未改动" >&2
    return 1
  fi
  # SC2064：此处**有意**立即展开 $tmp —— tmp 是局部变量，函数返回后名字即失效，
  # 若写成单引号，EXIT 时展开为空串、临时文件反而漏删。
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" EXIT
  if printf '%s\n' "$content" > "$tmp" && mv "$tmp" "$target"; then
    trap - EXIT   # 成功后撤销，避免 trap 残留到后续调用/调用方（install 路径无 EXIT trap）
    return 0
  fi
  rm -f "$tmp"
  trap - EXIT
  return 1
}

# ═══════════════════════════════════════════════════════════════════════
# deploy_pre_commit — pre-commit symlink 部署（archive-commit-gate）
# 必须定义在 install_hooks() 之前：install_hooks() 体内调用此函数
# 依赖 $project / $hook_dst（bash 动态作用域：从 install_hooks() 内调用时可见）
# ═══════════════════════════════════════════════════════════════════════
deploy_pre_commit() {
  # 1. 无条件装源文件（user + project scope 都装）
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"

  # 2. 项目级才创建 symlink（user scope 无 .git → 只装源文件）
  [[ -d "${project}/.git" ]] || return 0

  local target="${project}/.git/hooks/pre-commit"
  mkdir -p "${project}/.git/hooks"

  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ "${FLOW_KIT_YES:-0}" == "1" ]]; then
      echo "   [archive-commit-gate] existing pre-commit: $target, skipped"
      return 0
    fi
    local ans
    read -p "flow-kit: 既有 pre-commit 存在，覆盖？(y/N) " ans
    [[ "$ans" == "y" ]] || { echo "   skipped"; return 0; }
    rm -f "$target"
  fi

  ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"
  echo "   ✅ pre-commit symlink → $target"
}

# ═══════════════════════════════════════════════════════════════════════
# is_flowkit_symlink — 判 .git/hooks/pre-push 是否「指向已安装 hooks 目录」的 symlink
# 幂等条件（DESIGN D3 item 0 · ADR-022）：
#   ① [ -L ] 必须是 symlink
#   ② [ -e ] 必须非悬空（裸 readlink 对悬空链接同样返回目标串 rc=0 ⇒ 会假判幂等）
#      [ -e ] 跟随 symlink，BSD/GNU 一致 —— 不用 -f（-f 跨实现语义不一）
#   ③ 裸 readlink（**禁** readlink -f —— GNU-only，macOS 报 illegal option 且 stdout 空 ⇒ 判据恒假）
#   ④ case 显式否决源树 (*/flow-kit-bundle/hooks/…) 与 dist 镜像 (*/dist/*)，只认已安装位
# 依赖 $1 = 待判目标路径
# ═══════════════════════════════════════════════════════════════════════
is_flowkit_symlink() {
  [ -L "$1" ] || return 1
  [ -e "$1" ] || return 1
  local t
  t="$(readlink "$1")" || return 1
  case "$t" in
    */flow-kit-bundle/hooks/pre-push/pre-push.sh) return 1 ;;   # 源树 —— 否决
    */dist/*)                                    return 1 ;;   # dist 镜像 —— 非安装位
    */hooks/pre-push/pre-push.sh)                return 0 ;;   # 已安装位
    *)                                           return 1 ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════
# deploy_pre_push — pre-push symlink 部署（AC-3 推送拦截器 · DESIGN D3）
# 与 deploy_pre_commit **语义相反**：pre-commit 是 skip/交互确认（既有则不动），
#   pre-push 是「备份后覆盖」（既有非 flow-kit 文件 ⇒ 先备份再覆盖）。
# 语义必须重写，**禁止照抄** deploy_pre_commit。
# 依赖 $project / $hook_dst（bash 动态作用域：从 install_hooks() 内调用时可见）
# ═══════════════════════════════════════════════════════════════════════
deploy_pre_push() {
  # 1. 无条件装源文件到已安装 hooks 目录（user + project scope 都装）
  install_file "$SCRIPT_DIR/hooks/pre-push/pre-push.sh" "$hook_dst/pre-push/pre-push.sh"
  chmod +x "$hook_dst/pre-push/pre-push.sh" 2>/dev/null || true

  # 2. 项目级才创建 symlink（user scope 无 .git → 只装源文件）
  [[ -d "${project}/.git" ]] || return 0

  local target="${project}/.git/hooks/pre-push"
  mkdir -p "${project}/.git/hooks"

  # 3. 幂等：已是指向已安装位的 symlink ⇒ 跳过
  if is_flowkit_symlink "$target"; then
    echo "   ✅ pre-push 已是 flow-kit symlink，跳过: $target"
    return 0
  fi

  # 4. 先备份既有物（普通文件 / 悬空 symlink / 错绑 symlink）
  #    备份名含 PID 避免同秒并发互相覆盖
  local bak="${target}.bak.$$"
  if [ -L "$target" ]; then
    # symlink（非已安装位 / 悬空）：记下其 linktarget 以便回滚
    local lt
    lt="$(readlink "$target" 2>/dev/null)" || lt="(unreadable)"
    printf '%s\n' "$lt" > "${bak}.linktarget" || { echo "🔴 pre-push 备份 linktarget 写入失败: ${bak}.linktarget" >&2; return 1; }
    echo "   [pre-push] 既有 symlink 备份: ${bak}.linktarget -> $lt"
  elif [ -e "$target" ]; then
    cp -p "$target" "$bak" || { echo "🔴 pre-push 备份失败: $target -> $bak" >&2; return 1; }
    echo "   [pre-push] 既有文件备份: $target -> $bak"
  fi

  # 5. 删除旧物 + 创建 symlink（唯一产物形态 · ADR-022）
  rm -f "$target" || { echo "🔴 pre-push 旧物删除失败: $target" >&2; return 1; }
  ln -s "$hook_dst/pre-push/pre-push.sh" "$target" || { echo "🔴 pre-push symlink 创建失败: $target" >&2; return 1; }
  chmod +x "$target" 2>/dev/null || true

  # 6. 部署断言（DESIGN D3 item 5）：产物可执行
  [ -x "$target" ] || { echo "🔴 pre-push 部署后不可执行: $target" >&2; return 1; }
  echo "   ✅ pre-push symlink → $target"

  # 7. 恢复路径提示（R3-17）：若备份了既有物，打印备份文件路径 + cp 回滚命令，
  #    使被覆盖的既有 hook 可原位恢复（不引入同意门，ADR-022 有意设计）。
  if [ -e "$bak" ] || [ -e "${bak}.linktarget" ]; then
    echo "   ℹ️ pre-push 恢复路径：如需回滚，执行："
    if [ -e "${bak}.linktarget" ]; then
      echo "      cp -f \"\$(cat '${bak}.linktarget')\" '$target'   # 恢复原 symlink 指向"
    elif [ -e "$bak" ]; then
      echo "      cp -f '$bak' '$target'   # 恢复既有 pre-push 内容"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# install_hooks — Stop Hook + SessionStart → user or project scope
# ═══════════════════════════════════════════════════════════════════════
install_hooks() {
  local project="$1"
  local scope="${2:-project}"   # "user" or "project"

  # ── 依赖硬校验（PC2 · AC-2 · DESIGN D7）：缺 jq → fail-closed ──────────
  # 为什么必须在**任何写盘之前**：settings 接线靠 jq 生成内容，而 shell 的 `>` 会
  # 先截断目标文件再执行命令 —— 实测（2026-09-22，`--global --no-brooks --user`）
  # 缺 jq 时既有 ~/.claude/settings.json 122B → 0B 后才 rc=127，属"先毁数据再失败"。
  # 探测原语沿用仓内既有写法（hooks/stop/lib/common.sh:226、lib/install_brooks.sh:24）：
  # `command -v jq >/dev/null 2>&1`。
  if ! command -v jq >/dev/null 2>&1; then
    echo "   ❌ 缺少依赖 jq：install_hooks 需要 jq 合并 settings.json，已中止（尚未做任何写盘）" >&2
    return 1
  fi

  # ── 依赖自加载 ──────────────────────────────────────────────
  # install.sh 调用: resolve_paths 已在 install.sh:153 执行 → 此块 no-op
  # 直接 source（测试/独立）: paths.sh 未加载 → 自动加载
  if [ -z "${PROJECT_DIR_NAME:-}" ] && [ -n "${SCRIPT_DIR:-}" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/lib/paths.sh"
    case "${FLOW_KIT_PLATFORM:-claude}" in
      claude|opencode) resolve_paths "${FLOW_KIT_PLATFORM:-claude}" ;;
      *) resolve_paths claude ;;
    esac
  fi

  echo ""
  echo "═══ 安装 Hook 系统 [${PLATFORM}/${scope}] ═══"

  local hook_dst          # 实际安装目录（绝对路径）
  local settings_hook_path  # settings.json 命令字符串中的路径引用

  if [ "$scope" = "user" ]; then
    hook_dst="$USER_HOOKS_DIR"
    # ~/.claude/hooks → ${HOME}/.claude/hooks
    # ~/.config/opencode/hooks → ${HOME}/.config/opencode/hooks
    settings_hook_path="${HOOKS_USER_VAR_REF}${USER_HOOKS_DIR#"$HOME"}"
  else
    if [ ! -d "$project" ]; then
      echo "   ❌ 项目目录不存在: $project"
      return 1
    fi
    hook_dst="${project}/${PROJECT_DIR_NAME}/hooks"
    # $project/.claude/hooks → ${CLAUDE_PROJECT_DIR}/.claude/hooks
    # $project/.opencode/hooks → ${CLAUDE_PROJECT_DIR}/.opencode/hooks
    settings_hook_path="${HOOKS_PROJECT_VAR_REF}/${PROJECT_DIR_NAME}/hooks"
  fi

  echo "   安装到: $hook_dst"
  echo "   settings.json 命令路径: ${settings_hook_path}/stop/00-gate.sh"

  # Stop hook 模块（来源: common.sh::HOOK_MODULE_NAMES — 单一来源）
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/hooks/stop/lib/common.sh" 2>/dev/null || {
    echo "   ⚠️  common.sh 不可用，使用回退列表"
    HOOK_MODULE_NAMES=(00-gate 01-transcript-parse 20-claude-md 21-memory 22-git 23-quality 24-session 25-project 26-workflow 27-interactive-ui-check 28-weak-model-compliance 29-independent-review 30-ai-analyze 31-auto-advance 32-fallback-guard 33-flow-active-integrity 34-archive-commit-check 99-report)
  }
  for script in "${HOOK_MODULE_NAMES[@]}"; do
    install_file "$SCRIPT_DIR/hooks/stop/${script}.sh" "$hook_dst/stop/${script}.sh"
    chmod +x "$hook_dst/stop/${script}.sh" 2>/dev/null || true
  done
  unset HOOK_MODULE_NAMES

  # Stop hook 库文件（通配符自动包含全部 .sh，防止新增 lib 时漏加）
  for lib_sh in "$SCRIPT_DIR/hooks/stop/lib/"*.sh; do
    install_file "$lib_sh" "$hook_dst/stop/lib/$(basename "$lib_sh")"
  done

  # SessionStart hooks
  for script in flow-kit-resume stop-report-reminder; do
    install_file "$SCRIPT_DIR/hooks/session-start/${script}.sh" "$hook_dst/session-start/${script}.sh"
    chmod +x "$hook_dst/session-start/${script}.sh" 2>/dev/null || true
  done

  # PreToolUse hooks + lib 子库（独立 review gate · 硬拦截 commit/PR/阶段切换）
  # 部署 pre-tool-use/ 下所有 .sh 文件（主 hook + 拆分后的 gate-helpers*.sh 子库）
  #
  # ⚠️ 契约说明（health-fix-2026-09 · brooks-review R2/R6 交叉引用 · 2026-09-21）：
  # 下面第 7 行对本目录**所有** .sh 一律 `chmod +x`，而"真入口"只有 3 个
  # （independent-review-gate / auto-checkpoint / runtime-edit-guard）—— 其余 4 个是
  # **只被 source 的库**（gate-helpers / gate-helpers-types / gate-checks-basic / gate-checks-review）。
  # 本处**有意**不区分：对库多给一个 exec 位是**无害冗余**（库只被 source，不需要 exec），
  # 而部署期一律可执行能避免"入口忘了 chmod 就跑不起来"的故障。
  # **真入口契约的单一事实源** = `sync-hooks.sh` 的 `PTU_ENTRIES` 白名单（exec 判据据它收窄）。
  # ⇒ **新增 pre-tool-use 入口时，必须登记 `sync-hooks.sh::PTU_ENTRIES`**，否则该入口的
  #    exec 位将不受 `check-hooks-sync` 守护（DESIGN §5 R4 的"清单漂移"风险）。
  mkdir -p "$hook_dst/pre-tool-use"
  while IFS= read -r ptu_script; do
    local ptu_base
    ptu_base=$(basename "$ptu_script")
    install_file "$ptu_script" "$hook_dst/pre-tool-use/${ptu_base}"
    chmod +x "$hook_dst/pre-tool-use/${ptu_base}" 2>/dev/null || true
  done < <(ls "$SCRIPT_DIR/hooks/pre-tool-use"/*.sh 2>/dev/null)

  deploy_pre_commit
  deploy_pre_push

  # ── 随包路径隐私检查器部署（R3-14 (c)③ · T-FIX-08）──────────────────
  # 把 flow-kit/reference/check-path-privacy.sh 与 path-privacy-allowlist.txt
  # 一并装到已安装 hooks 目录旁的 reference/（<hook_dst>/../reference/），
  # 使 pre-push/pre-commit hook「由 hook 自身位置推导」在已部署的消费者项目
  # 里也能解析到随包检查器与允许清单（hook 推导路径：HOOK_DIR/../reference/）。
  local ref_src_dir="$SCRIPT_DIR/flow-kit/reference"
  local ref_dst_dir="${hook_dst%/hooks}/reference"
  if [ -f "$ref_src_dir/check-path-privacy.sh" ]; then
    mkdir -p "$ref_dst_dir"
    install_file "$ref_src_dir/check-path-privacy.sh" "$ref_dst_dir/check-path-privacy.sh"
    chmod +x "$ref_dst_dir/check-path-privacy.sh" 2>/dev/null || true
    if [ -f "$ref_src_dir/path-privacy-allowlist.txt" ]; then
      install_file "$ref_src_dir/path-privacy-allowlist.txt" "$ref_dst_dir/path-privacy-allowlist.txt"
    fi
    echo "   ✅ 随包检查器部署 → ${ref_dst_dir}/check-path-privacy.sh"
  fi

  # ── flow-kit-l2-reviewer agent（DESIGN D6）─────────────────────────
  # 仅 opencode 平台安装：claude 平台不装（CC 用 subagent_type 原生派发 L2 审查）
  if [ "$PLATFORM" = "opencode" ]; then
    local agent_src="$SCRIPT_DIR/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md"
    local agent_dst
    if [ "$scope" = "user" ]; then
      agent_dst="${PLATFORM_CONFIG_DIR}/agent/flow-kit-l2-reviewer.md"
    else
      agent_dst="${project}/${PROJECT_DIR_NAME}/agent/flow-kit-l2-reviewer.md"
    fi

    # 冲突检测：目标已存在且未明确确认（FLOW_KIT_YES != 1）→ 询问覆盖
    local agent_skip=0
    if [ -e "$agent_dst" ] && [ "${FLOW_KIT_YES:-0}" != "1" ]; then
      local ans
      read -p "flow-kit: 既有 flow-kit-l2-reviewer.md 存在，覆盖？(y/N) " ans
      [[ "$ans" == "y" ]] || agent_skip=1
    fi
    if [ "$agent_skip" = 1 ]; then
      echo "   [flow-kit-l2-reviewer] 已存在，skipped: $agent_dst"
    else
      install_file "$agent_src" "$agent_dst"
      echo "   ✅ flow-kit-l2-reviewer agent → $agent_dst"
    fi
  fi

  # 配置文件（**仅用户级** · 2026-09-21 统一）
  # 项目级副本自 2026-09-21 起既不生成也不被读取：多项目各持一份会漂移
  # （实测同机曾并存 cap=20000/60000/120000/200000 四套值）。用户级路径 =
  # <用户 runtime 目录>/stop-hook.json（~/.claude · ~/.config/opencode · ~/.dsh）。
  if [ "$scope" = "user" ]; then
    install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "${project}/${PROJECT_DIR_NAME}/stop-hook.json"
  else
    echo "   ℹ️  配置：走用户级 $(dirname "$USER_HOOKS_DIR")/stop-hook.json（项目级副本不再生成/读取）"
  fi

  # ═══ 自动写入 hook 接线 ═══
  local settings_target
  settings_target=$(settings_file_for "$scope" "$project")
  echo ""
  echo "   settings 文件: $settings_target"

  # ── 通用接线函数：往 settings_target 写入一个 hook ──────────────
  # 参数: event  matcher  cmd  label
  # -------------------------------------------------------------------
  _install_hook_wiring() {
    local event="$1"
    local matcher="$2"
    local cmd="$3"
    local label="$4"

    if [ "${DRY_RUN:-false}" = true ]; then
      echo "   [DRY-RUN] 写入 ${event} hook (${label}) 到 ${settings_target}: command=${cmd}"
      return
    fi

    if [ -f "$settings_target" ]; then
      # 已存在 → 合并追加。判据**只看文件存在性**（DESIGN D7）：旧写法把
      # `[ -f … ] && command -v jq` 串成一个条件，jq 缺失时整体为假 → 落进下面的
      # "新建"分支，用 `>` 把既有 settings.json 截断。jq 可用性已由 install_hooks()
      # 入口硬校验保证；此处再探测一次是纵深防御（入口到此处之间还执行过多步安装），
      # 失败时**原文件保持不动**（fail-closed）。
      if ! command -v jq >/dev/null 2>&1; then
        echo "   ❌ jq 不可用，无法合并 ${settings_target}（原文件未改动）" >&2
        return 1
      fi

      # 已存在 → 检查是否已有此 hook，没有则追加
      if jq -e --arg cmd "$cmd" \
          --arg event "$event" \
          '(.hooks[$event] // []) | any(.[].hooks[].command; . == $cmd)' \
          "$settings_target" >/dev/null 2>&1; then
        echo "   ✅ ${event} hook (${label}) 已存在于 ${settings_target}，跳过"
        return
      fi
      local merged
      merged=$(jq --arg event "$event" \
                  --arg matcher "$matcher" \
                  --arg cmd "$cmd" '
        .hooks[$event] = (.hooks[$event] // []) + [{
          "matcher": $matcher,
          "hooks": [{
            "type": "command",
            "command": $cmd
          }]
        }]
      ' "$settings_target" 2>/dev/null)
      if [ -n "$merged" ] && write_settings_file_atomic "$settings_target" "$merged"; then
        echo "   ✅ ${settings_target} 已追加 ${event} hook (${label})"
      else
        echo "   ⚠️  ${settings_target} ${event} (${label}) 合并失败，请手动检查" >&2
        return 1
      fi
    else
      # 新建（jq 可用性由 install_hooks() 入口硬校验保证）
      mkdir -p "$(dirname "$settings_target")"
      local created
      created=$(jq -n --arg event "$event" \
            --arg matcher "$matcher" \
            --arg cmd "$cmd" '
        { hooks: { ($event): [{
          "matcher": $matcher,
          "hooks": [{
            "type": "command",
            "command": $cmd
          }]
        }] } }
      ' 2>/dev/null)
      if [ -n "$created" ] && write_settings_file_atomic "$settings_target" "$created"; then
        echo "   ✅ ${settings_target} 已写入 ${event} hook (${label})"
      else
        echo "   ⚠️  ${settings_target} ${event} (${label}) 写入失败" >&2
        return 1
      fi
    fi
  }


  # ── Stop hook ──────────────────────────────────────────────────
  local stop_cmd="bash \"${settings_hook_path}/stop/00-gate.sh\""
  _install_hook_wiring "Stop" "" "$stop_cmd" "00-gate"

  # ── PreToolUse independent-review-gate ─────────────────────────
  local gate_cmd="bash \"${settings_hook_path}/pre-tool-use/independent-review-gate.sh\""
  _install_hook_wiring "PreToolUse" "Bash|Write|Edit" "$gate_cmd" "independent-review-gate"

  # ── PreToolUse auto-checkpoint ─────────────────────────────────
  local ck_cmd="bash \"${settings_hook_path}/pre-tool-use/auto-checkpoint.sh\""
  _install_hook_wiring "PreToolUse" "Write|Edit" "$ck_cmd" "auto-checkpoint"

  # ── PreToolUse runtime-edit-guard (L-015) ─────────────────────
  # 文件部署已在 PreToolUse 目录循环中完成（L100-110），此处仅写 settings.json matcher
  local reg_cmd="bash \"${settings_hook_path}/pre-tool-use/runtime-edit-guard.sh\""
  _install_hook_wiring "PreToolUse" "Write|Edit" "$reg_cmd" "runtime-edit-guard"

  # SessionStart hooks 由全局 ~/.claude/settings.json 管理（--global 安装时已写入），
  # 此处不再重复写入，避免同一 hook 触发两次。
  echo "   ℹ️  SessionStart hooks 由全局配置管理，无需项目级重复接线"

  # ── opencode 桥接提示 ──────────────────────────────────────────
  if [ "$PLATFORM" = "opencode" ]; then
    echo ""
    echo "   ⚠️  [opencode] settings.json 桥接提示:"
    echo "       opencode 不原生读 ~/.claude/settings.json，hooks 默认不触发。"
    echo "       启用方式（任选其一）:"
    echo "         (A) npm install -g opencode-claude-hooks  # 自动桥接 .claude/settings.json"
    echo "         (B) 在 ~/.config/opencode/opencode.json plugin 数组加入 'opencode-claude-hooks'"
    echo "       详见 OPENCODE-INSTALL.md"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# install_specs_template — .specs/STATE.md 模板
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
