#!/bin/bash
#
# pre-push.sh — flow-kit 推送门禁（AC-3 推送拦截器）
#
# 变更：health-fix-2026-09b · T11（AC-3(a)）
#
# 行为（次序是硬契约，IR-3 C2 定稿，T19 端到端依赖）：
#   1. 逐行读取 stdin 的「<local ref> <local sha> <remote ref> <remote sha>」；
#      对每个被推送的 ref 调用 check-path-privacy 目标做路径隐私泄漏评估。
#      - 命中泄漏的 ref，在报文里【指名该 ref】（形如 refs/heads/main、refs/tags/v1）
#        并以非零退出拒绝推送；
#      - 干净 ref 放行。
#   2. 只有全部 ref 都干净之后，才执行 make check（保留既有“推送前跑 make check”语义）。
#
# 兼容性：bash 3.2（macOS 默认），不使用 mapfile / declare -A / readlink -f / sed -i。
# 部署：install_hooks.sh deploy_pre_push() 以 symlink 使 .git/hooks/pre-push 指向本文件。

set -euo pipefail

leaky_ref=""

while IFS= read -r line || [ -n "$line" ]; do
    # 逐字段展开，兼容 bash 3.2（不用 mapfile / 关联数组）
    set -- $line
    [ "$#" -ge 1 ] && [ -n "$1" ] || continue
    local_ref=$1

    # 泄漏评估：调用 CheckPathPrivacy 目标（DESIGN §2.1），0=干净 / 非 0=含泄漏。
    # CHECK_REF 仅作归因提示传入（真实目标忽略之；影子测试 stub 用它区分各 ref）。
    if ! CHECK_REF="$local_ref" make check-path-privacy; then
        echo "🔴 拒绝推送 $local_ref：该 ref 含路径隐私泄漏（make check-path-privacy 未通过）" >&2
        leaky_ref="$local_ref"
        break
    fi
done

# 任一 ref 泄漏 → 已在报文指名该 ref，拒绝整次推送
[ -z "$leaky_ref" ] || exit 1

# 全部 ref 干净 → 推送前跑 make check（保留既有语义）
make check
