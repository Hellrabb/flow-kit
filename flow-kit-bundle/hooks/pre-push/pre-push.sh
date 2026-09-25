#!/bin/bash
#
# pre-push.sh — flow-kit 推送门禁（AC-3 推送拦截器）
#
# 变更：health-fix-2026-09b · T11（AC-3(a)） · T-FIX-08（R3-14/R3-23/R3-17 配套）
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

# hook 自身位置推导随包 reference 目录（不写死绝对路径）。
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 随包 reference 目录：hook 入口在 hooks/ 下，reference 在 hooks/ 同级的
# flow-kit/reference/（部署形态：<hook_dst>/../reference/；源码形态：flow-kit-bundle/hooks/../flow-kit/reference/）。
resolve_reference_dir() {
  local d
  for d in "$HOOK_DIR/../flow-kit/reference" "$HOOK_DIR/../reference" "$HOOK_DIR/../../flow-kit/reference"; do
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
        echo "ℹ️ 未找到可用的路径隐私检查器：跳过内容扫描" >&2
        return 0
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
pure_delete_seen=0

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
        pure_delete_seen=1
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
