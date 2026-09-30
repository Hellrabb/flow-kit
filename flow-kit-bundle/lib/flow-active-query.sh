#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# flow-active-query.sh — .flow-active 状态文件唯一解析入口
# change: health-fix-2026-09c / T13 / ADR-031 / AC-12-g（DESIGN §9.3）
#
# 所有对 .flow-active 的读取（Makefile 校验目标、pre-tool-use hook、reference
# 检查器）一律改调本入口；仓内禁止新增内联 jq / while-read 解析（DESIGN 附录 A
# 严格谓词 + make check-flow-active-inline 白名单门禁看守；本文件路径含
# "flow-active-query"，谓词自排除，是唯一合法解析点）。
#
# CLI:
#   flow-active-query.sh [--root <dir>] [--print-file] <jq-path>
#
#   --root <dir>     项目根目录（默认 $PWD；状态文件 = <root>/.flow-active）
#   --print-file     探针模式：stdout = 状态文件路径（rc 0 = 在场且合法 JSON）
#   <jq-path>        jq 过滤表达式（如 '.change_id'、'.goal.current_phase'）
#   FLOW_ACTIVE_FILE 环境变量可直接覆盖状态文件路径（测试夹具 / 非标准布局）
#
# 退出码（ADR-031 契约）：
#   rc 0  正常：stdout = jq-path 求值结果（raw）；--print-file 时 = 文件路径
#   rc 1  状态文件不在场（静默——非管辖项目语义）/ 字段缺失或求值为
#         null/false/空串 / jq 运行错（如过滤器语法非法）
#   rc 2  依赖缺失（jq 不可用）或状态文件非法 JSON / 不可读（stderr 具名报文，
#         关键词「jq 不可用」「非法 JSON」供上游 fail-close 报文 grep）
#
# bash 3.2 兼容（无 mapfile/readarray/nameref/关联数组）；只读不写状态文件
# （R7：.flow-active 写点一律 tmp+mv，不在本入口职责内）。
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

PROG='flow-active-query'

usage() {
  cat <<'USAGE'
用法: flow-active-query.sh [--root <dir>] [--print-file] <jq-path>
  --root <dir>     项目根目录（默认 $PWD；状态文件 = <root>/.flow-active）
  --print-file     探针模式：stdout = 状态文件路径（rc 0 = 在场且合法）
  <jq-path>        jq 过滤表达式（如 '.change_id'）
环境: FLOW_ACTIVE_FILE 覆盖状态文件路径（优先于 --root 推导）
退出: 0=正常  1=不在场/字段缺失或空  2=jq 缺失/非法 JSON（stderr 具名报文）
USAGE
}

die_rc2() {
  printf '[%s] %s\n' "$PROG" "$1" >&2
  exit 2
}

# ── 参数解析 ────────────────────────────────────────────────────────────────
ROOT="$PWD"
MODE='query'
JQ_PATH=''

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || die_rc2 "--root 需要一个目录参数（用法见 --help）"
      ROOT="${2:-}"
      [ -n "$ROOT" ] || die_rc2 "--root 不接受空串（用法见 --help）"
      shift 2
      ;;
    --print-file)
      MODE='print-file'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die_rc2 "未知选项: $1（用法见 --help）"
      ;;
    *)
      if [ -z "$JQ_PATH" ]; then
        JQ_PATH="$1"
        shift
      else
        die_rc2 "多余参数: $1（只接受一个 jq-path；用法见 --help）"
      fi
      ;;
  esac
done

if [ "$MODE" = 'query' ] && [ -z "$JQ_PATH" ]; then
  die_rc2 "缺少 <jq-path> 参数（或改用 --print-file 探针；用法见 --help）"
fi

command -v jq >/dev/null 2>&1 \
  || die_rc2 'jq 不可用（PATH 中无 jq；安装后重试）——状态文件不可判读，拒绝放行语义'

# ── 状态文件定位 ────────────────────────────────────────────────────────────
if [ -n "${FLOW_ACTIVE_FILE:-}" ]; then
  STATE_FILE="$FLOW_ACTIVE_FILE"
else
  STATE_FILE="${ROOT%/}/.flow-active"
fi

# 不在场 = 非管辖项目（静默 rc 1；上游据此放行——C12 保留语义）
[ -f "$STATE_FILE" ] || exit 1

jq empty "$STATE_FILE" 2>/dev/null \
  || die_rc2 "状态文件非法 JSON（或不可读）: ${STATE_FILE} —— jq 校验失败"

# ── 输出 ────────────────────────────────────────────────────────────────────
if [ "$MODE" = 'print-file' ]; then
  printf '%s\n' "$STATE_FILE"
  exit 0
fi

_val=''
_val="$(jq -re "$JQ_PATH" "$STATE_FILE" 2>/dev/null)" || exit 1
[ -n "$_val" ] || exit 1
printf '%s\n' "$_val"
exit 0
