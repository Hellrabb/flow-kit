#!/bin/bash
#
# pre-push.sh — flow-kit 推送门禁（AC-3 推送拦截器）
#
# 变更：health-fix-2026-09b · T11（AC-3(a)） · T-FIX-08（R3-14/R3-23/R3-17 配套）
# 变更：health-fix-2026-09c · T09（AC-17①） · 新增 flock 并发闸（只串行化，放行语义不变）
#
# 行为（次序是硬契约，IR-3 C2 定稿，T19 端到端依赖）：
#   1. 逐行读取 stdin 的「<local ref> <local sha> <remote ref> <remote sha>」；
#      收集本次 push 涉及的全部 local_sha 去重（R3-23：不再逐 ref 全量重扫，
#      同一 sha 只扫一次），对每个唯一 sha 做一次路径隐私泄漏评估。
#      - 命中泄漏的 ref，在报文里【指名该 ref】（形如 refs/heads/main、refs/tags/v1）
#        并以非零退出拒绝推送；
#      - 干净 ref 放行。
#   2. 只有全部 ref 都干净之后，才执行项目 Makefile 声明的 check 目标
#      （R3-14(b)：项目 Makefile 未声明 check 目标 ⇒ 打印跳过理由且不改 rc）。
#
# 消费者项目兼容（R3-14(a) · (c) 随包解析）：
#   先看项目 Makefile 是否声明 check-path-privacy 目标，有则用项目目标；
#   无则回退到随包携带的 reference/check-path-privacy.sh（路径由 hook 自身位置
#   推导，不得写死绝对路径），并导出 FLOW_KIT_PRIVACY_ALLOWLIST 指向随包
#   reference/path-privacy-allowlist.txt（CWD 保持项目根）。三者皆不可得 ⇒
#   打印 ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描 且不改 rc。
#   纯删除推送（local_sha 全 0）⇒ 跳过内容扫描并打印 ℹ️ 纯删除推送：跳过内容扫描 rc=0。
#
# 兼容性：bash 3.2（macOS 默认），不使用 mapfile / declare -A / readlink -f / sed -i。
# 部署：install_hooks.sh deploy_pre_push() 以 symlink 使 .git/hooks/pre-push 指向本文件。

set -euo pipefail

# ── flock 并发闸（health-fix-2026-09c · T09 · AC-17①）──
# 目的：同一仓库并发 push 时，多个 pre-push 实例并跑内容扫描 / make check 互踩
# （C1 类污染经 push 通路放大——AC-17 要关闭的窗口）。闸只做**串行化**，
# 不改变推送判定：放行/拒绝仍由下方隐私扫描与 make check 决定。
# 锁设计（F6 范式：锁文件 + mktemp 唯一路径）：
#   - 锁文件 = <git-dir>/flow-kit-pre-push.lock——**确定性路径**、每仓一把，
#     是并发 push 共享的唯一互斥点；除此之外本 hook 不落任何共享临时产物
#     （测试/夹具侧一律 mktemp 唯一路径，同 test_check_gate_sync.bats F6 教训）。
#   - 持锁范围 = 整个 hook 生命周期：fd 9 随脚本退出自动关闭 ⇒ 锁自动释放，
#     无清理路径（kill -9 也不留死锁；锁文件残留无害——内容恒空）。
# 超时语义：flock -w 600（FLOW_KIT_PRE_PUSH_LOCK_WAIT 可覆盖，测试注入用）。
#   超时 **fail-closed** exit 1 并指名锁路径：放行等于无声重开互踩窗口；
#   600s 远大于任何合理 make check，超时即环境异常（挂死推送），应人工排查。
# 降级语义：flock 不可得（非 Linux/极简环境）、git-dir 不可定位或锁不可写 ⇒
#   打印 ⚠️ 后**放行（本次不串行化）**：闸是 best-effort 基础设施，其缺席
#   不得改变推送判定（与隐私扫描的 fail-closed 不同层——那是内容判定）。
_pre_push_gate() {
  local lock_dir lock_file wait_s
  command -v flock >/dev/null 2>&1 || {
    echo "⚠️ [pre-push] flock 不可用：跳过并发闸（本次未串行化）" >&2
    return 0
  }
  lock_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
  if [ -z "$lock_dir" ]; then
    echo "⚠️ [pre-push] 无法定位 git-dir：跳过并发闸（本次未串行化）" >&2
    return 0
  fi
  lock_file="$lock_dir/flow-kit-pre-push.lock"
  # 先探可写性再 exec 开 fd：exec 重定向失败在 bash 3.2 会直接终止 shell，
  # 预创建（: >>）把失败面收敛到可警告的分支。
  if ! : >>"$lock_file" 2>/dev/null; then
    echo "⚠️ [pre-push] 锁文件不可写（$lock_file）：跳过并发闸（本次未串行化）" >&2
    return 0
  fi
  exec 9>>"$lock_file"
  wait_s="${FLOW_KIT_PRE_PUSH_LOCK_WAIT:-600}"
  if ! flock -w "$wait_s" 9; then
    echo "🔴 [pre-push] 并发闸超时（${wait_s}s）：另一 push 仍在进行，锁=$lock_file。排查挂死推送后重试" >&2
    return 1
  fi
}
_pre_push_gate || exit 1

# hook 自身位置推导随包 reference 目录（不写死绝对路径）。
#
# T-FIX-14（R5-18 🔴）：旧实现 `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
# 在安装形态下不可达 —— .git/hooks/pre-push 是指向真实脚本的 symlink，BASH_SOURCE[0]
# 取到的是 symlink 本体，dirname 得到 .git/hooks ⇒ HOOK_DIR=.git/hooks ⇒ 三条候选
# （HOOK_DIR/../flow-kit/reference、HOOK_DIR/../reference、HOOK_DIR/../../flow-kit/reference）
# 全 miss ⇒ 门禁找不到检查器 ⇒ rc=0 放行，消费者双侧门禁静默失效。
#
# 修法（macOS bash 3.2 兼容 · 禁 readlink -f）：先用 `command -v readlink` + 循环把
# BASH_SOURCE[0] 逐级解析为真实文件（相对目标按 dirname 拼接），再 cd 到真实脚本所在
# 目录 pwd ⇒ 经 symlink 调用时 HOOK_DIR 仍是真实脚本所在目录（<proj>/.claude/hooks/pre-push）。
_resolve_self_path() {
  local self="${BASH_SOURCE[0]}"
  # macOS 无 readlink -f；裸 readlink 只解一层。逐级循环直至不再是 symlink。
  if command -v readlink >/dev/null 2>&1; then
    local depth=0
    while [ -L "$self" ] && [ "$depth" -lt 40 ]; do
      local target
      target="$(readlink "$self" 2>/dev/null)" || break
      case "$target" in
        /*) self="$target" ;;                            # 绝对目标直接用
        *)  self="$(cd "$(dirname "$self")" && pwd)/$target" ;;  # 相对目标按 dirname 拼接
      esac
      depth=$((depth + 1))
    done
  fi
  printf '%s\n' "$self"
}
HOOK_DIR="$(cd "$(dirname "$(_resolve_self_path)")" && pwd)"
# 随包 reference 目录候选（精确列表，禁止改成通配目录扫描）：
#   ① 源码树形态：HOOK_DIR/../flow-kit/reference（flow-kit-bundle/hooks/pre-push → flow-kit-bundle/flow-kit/reference）
#   ② 安装形态（user scope，旧注释假设的层级）：<hook_dst>/../reference ⇒ HOOK_DIR/../reference
#   ③ 安装形态（project scope · T-FIX-14 修复）：hook 装在 <hook_dst>/<hook-name>/（深一层），
#      reference 在 <hook_dst>/../reference ⇒ HOOK_DIR/../../reference
#      （<proj>/.claude/hooks/pre-push → <proj>/.claude/reference）
#   ④ 安装形态备选（user scope 罕见布局）：HOOK_DIR/../../flow-kit/reference
resolve_reference_dir() {
  local d
  for d in "$HOOK_DIR/../flow-kit/reference" "$HOOK_DIR/../reference" "$HOOK_DIR/../../reference" "$HOOK_DIR/../../flow-kit/reference"; do
    if [ -f "$d/check-path-privacy.sh" ]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

# 判断项目 Makefile 是否声明了给定目标（grep -qE '^<target>[[:space:]]*:'）。
makefile_has_target() {
  local target="$1"
  [ -f Makefile ] || return 1
  grep -qE "^${target}[[:space:]]*:" Makefile
}

# 解析路径隐私检查器：resolved_kind（make | bundle | none）写入全局。
RESOLVED_KIND='none'
RESOLVED_CHECKER=''
RESOLVED_ALLOWLIST=''
resolve_checker() {
  if makefile_has_target check-path-privacy; then
    RESOLVED_KIND='make'
    return 0
  fi
  local ref_dir
  ref_dir="$(resolve_reference_dir 2>/dev/null || true)"
  if [ -n "$ref_dir" ] && [ -f "$ref_dir/check-path-privacy.sh" ]; then
    RESOLVED_KIND='bundle'
    RESOLVED_CHECKER="$ref_dir/check-path-privacy.sh"
    if [ -f "$ref_dir/path-privacy-allowlist.txt" ]; then
      RESOLVED_ALLOWLIST="$ref_dir/path-privacy-allowlist.txt"
    fi
    return 0
  fi
  RESOLVED_KIND='none'
  return 1
}

# 对给定 CHECK_REV 做一次内容扫描。
# make 目标：CHECK_REV=<sha> make check-path-privacy
# 随包脚本：CHECK_REV=<sha> FLOW_KIT_PRIVACY_ALLOWLIST=<随包> bash <checker>
# 不可得：打印跳过理由且不改 rc（不静默）
#
# 三态区分（health-fix-2026-09b · T-FIX-13 · R4-M1）：
#   ① 检查器缺失（RESOLVED_KIND=none）⇒ 消费者兼容语义：打印
#      ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描 且 rc=0（审计已接受，
#      bats:208 静态断言要求该措辞仍在文件内）。
#   ② 检查器在 + path-privacy-allowlist.txt 缺失（bundle 形态半拷贝 /
#      旧版安装器 / 手工 symlink）⇒ **具名 fail-closed**：配置缺失不得被
#      当成「干净」放行（含泄漏的推送会被直接放过 ⇒ R4-M1 fail-open），
#      也不得复用 ① 的措辞（与实际原因不符）。此处用**独立致命路径**
#      `echo … >&2; exit 2` 而非 `return 1` —— 因为 scan_rev 的调用方
#      （约 :150）把任何非零返回一律归因为「该 ref 含路径隐私泄漏」，
#      配置缺失若走该路径会造成**归因错位**（把「缺清单」报成「泄漏」）。
#      exit 2 直接终止脚本，绕过父层的泄漏归因，报文明确指名缺失的
#      允许清单绝对路径与 fail-closed 语义。
#   ③ 两者皆在 ⇒ 行为逐字不变：干净 rc=0；真泄漏 rc≠0 且父层归因
#      「含路径隐私泄漏」。
scan_rev() {
  local check_rev="$1"
  case "$RESOLVED_KIND" in
    make)
      if ! CHECK_REV="$check_rev" make check-path-privacy; then
        return 1
      fi
      ;;
    bundle)
      if [ -z "$RESOLVED_ALLOWLIST" ]; then
        # 状态 ②：检查器在 + 允许清单缺失 ⇒ 具名 fail-closed。
        # 独立致命路径（exit 2），不得走 return 1（父层 :150 会错位归因为泄漏）。
        echo "🔴 [pre-push] 找到路径隐私检查器但缺少允许清单：${RESOLVED_CHECKER%/check-path-privacy.sh}/path-privacy-allowlist.txt（无法确定扫描基线 ⇒ fail-closed，推送被拒绝）" >&2
        exit 2
      fi
      if ! CHECK_REV="$check_rev" FLOW_KIT_PRIVACY_ALLOWLIST="$RESOLVED_ALLOWLIST" \
           bash "$RESOLVED_CHECKER"; then
        return 1
      fi
      ;;
    none)
      echo "ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描" >&2
      return 0
      ;;
  esac
  return 0
}

# 解析检查器（一次性，供所有 ref 共用）
resolve_checker || true

leaky_ref=""
# 本次 push 涉及的唯一 local_sha 集合（R3-23 去重：同一 sha 只扫一次）
scanned_shas=''
# T-FIX-14（R5-24 🟢）：删除死变量（全文件无读取，纯写）。

while IFS= read -r line || [ -n "$line" ]; do
    # 逐字段展开，兼容 bash 3.2（不用 mapfile / 关联数组）
    set -- $line

    # fail-closed：取不到 local sha（字段不足 / 为空）⇐ stdin 第三、四字段为 remote
    # ref/sha，第二字段才是被推送对象的 local sha。畸形行不得静默按"干净"放过；
    # 明确报文 + exit 1。
    [ "$#" -ge 2 ] && [ -n "$2" ] || {
        echo "🔴 拒绝推送 ${1:-<未知 ref>}：pre-push stdin 行缺 local sha（畸形输入），fail-closed 拒绝" >&2
        exit 1
    }
    local_ref=$1
    local_sha=$2
    remote_sha=${4:-}

    # 删除推送（git push --delete / --mirror 清理）：git 传全 0 sha
    # （0000…0000）且 local ref 为 `(delete)`，此时没有对象可扫 ⇒ 该行必须跳过，
    # 不得走到门禁触发 fail-closed（ADR-027② 防新假红）。
    if [ "$local_sha" = "0000000000000000000000000000000000000000" ]; then
        echo "ℹ️ 纯删除推送：跳过内容扫描"
        continue
    fi

    # R3-23：收集本次 push 涉及的唯一 sha（去重）。同一 sha 只在第一次出现时扫描，
    # 不再逐 ref 全量重扫。关联记录用空格分隔字符串（bash 3.2 兼容，不用关联数组）。
    case " $scanned_shas " in
      *" $local_sha "*)
        # 已扫描过该 sha ⇒ 跳过重扫（R3-23）
        ;;
      *)
        scanned_shas="$scanned_shas $local_sha"
        # 泄漏评估：CHECK_REV 设为被推送对象的 local sha（stdin 第 2 字段）——
        # 门禁据此把评估面切换到该对象树（L-131 / ADR-027 拦截面 = 被拦截对象），
        # 避免「扫本地工作树」的归因错位；注解 tag 对象的 sha 也能被门禁
        # `^{commit}` 正确解析。
        if ! scan_rev "$local_sha"; then
            echo "🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（check-path-privacy 未通过）" >&2
            leaky_ref="$local_ref"
            break
        fi
        ;;
    esac
done

# 任一 ref 泄漏 → 已在报文指名该 ref，拒绝整次推送
[ -z "$leaky_ref" ] || exit 1

# 全部 ref 干净 → 推送前跑项目 Makefile 声明的 check 目标（R3-14(b)：
# 项目 Makefile 未声明 check 目标 ⇒ 打印跳过理由且不改 rc）。
if makefile_has_target check; then
  make check
else
  echo "ℹ️ 项目 Makefile 未声明 check 目标：跳过"
fi
