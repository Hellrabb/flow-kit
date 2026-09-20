#!/bin/bash
# 由 REQUIREMENT.md 原样落盘（T04）
set -uo pipefail
# AC-6 验证（可复制执行 · 探针打在【镜像副本】上，修正自 L2 R1）
set -e; cd "$(git rev-parse --show-toplevel)"
TMPD=$(mktemp -d)   # 夹具并发隔离（清理见下方合并 trap —— EXIT trap 只能有一个）
# 前置（Given）：① 基线无 exec 告警；② dist 与源一致（否则验证打在过期副本上，结论不可信）
bash sync-hooks.sh --check 2>&1 | grep -q '缺可执行位' && { echo "❌ 前置不满足：基线已有 exec 告警（AC-5 未达成）"; exit 1; }
diff -rq flow-kit-bundle dist/dsh-flow-kit/vendor/flow-kit-bundle >/dev/null \
  || { echo "❌ 前置不满足：dist 与源不一致，请先 bash package-dsh-plugin.sh"; exit 1; }
F=dist/dsh-flow-kit/hooks/pre-tool-use/independent-review-gate.sh   # 镜像根内，属判据域
[ -f "$F" ] || { echo "❌ 前置不满足：镜像副本不存在（$F），请先 bash package-dsh-plugin.sh"; exit 1; }
# 还原必须用 chmod：$F 位于 dist/（.gitignore 忽略），git checkout 会报
# "路径规格未匹配任何 git 已知文件" 且**不还原权限位**（L3 三轮 Major 实测确认）
trap 'chmod +x '"$F"'; rm -rf "$TMPD"' EXIT
chmod -x "$F"
make check-hooks-sync >$TMPD/ac6.log 2>&1 || true
grep -q 'independent-review-gate' $TMPD/ac6.log \
  || { echo "❌ FAIL: 未指名丢失 exec 位的真入口（聚合计数不算通过）"; exit 1; }
echo "✅ AC-6 PASS（指名要求满足；退出码强度按 DESIGN D5 = advisory 另验）"

