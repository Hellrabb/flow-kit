#!/bin/bash
# ============================================================================
# check-path-privacy.sh — 前向脱敏有机器门禁（AC-6）
# 扫描 tracked 文件内容中的本机绝对路径前缀（v1 第 1 类）。
# 设计依据：DESIGN D1 / D8 / D10 / D10′ / R8；REQUIREMENT AC-6；ADR-027 / ADR-028。
# exit: 0=通过（清单外命中 0 条）, 1=失败（fail-closed / 清单外命中 ≠0）
#       二值，无 SKIP 态（DESIGN §3 / ADR-028 决策 3）
# ============================================================================
# 空基线双态自检（T22 · L3 #4 major② fix · health-fix-2026-09b · 2026-09-23）
# ----------------------------------------------------------------------------
# 本门禁在「允许清单基线条目数 = 0」（D10 三态实测 + 排除通用占位符后）的
# 合法空基线态下，行为由以下两条固化的断言约束（INDEPENDENT-REVIEW-2 末段
# L3 #4 major② fix 原文）：
#
#   (a) 空清单 ⇒ 合法且 rc=0：自证行打印「允许清单 0 条」与「清单外命中 0 条」。
#       空清单既不得被当作错误（rc≠0 ⇒ 永久红），也不得静默跳过扫描
#       （否则泄漏在空清单下永远绿 ⇒ 假绿）。空基线之所以合法，前提是工件已脱敏
#       （D10′① 脱敏先于冻结 · T13），而不是靠放宽判据。
#   (b) 任何清单外命中 ⇒ rc=1：扫描面与允许清单的集合差非空即阻塞，与清单
#       是否为空无关；命中行必须以 `file:line` 归因（NFR 可观测性）。
#
# 双态判别力（T22 verify 固化）：拼接构造的畸形探针（与既有占位符不同形，
#   形如 /home/zz-path-probe/）⇒ 必须 rc=1；`/home/<user>/` 占位符形态
#   （`<` 不在字符类内 ⇒ 不命中 PAT）⇒ 必须 rc=0。
# ============================================================================
# T-FIX-03 fail-open 收敛（阶段 6 REVIEW §B F1~F5 · 2026-09-24）：
# ----------------------------------------------------------------------------
# 「未能检查」与「检查通过」必须在退出码与报文上分开。本脚本在此前版本里把
# 机械故障（mktemp 失败 / cp 失败 / 候选枚举失败 / 检索出错）折算成「0 命中 ⇒
# ✅ rc=0」，并让 0 候选面与「全部干净」同形 —— 隐私门禁被静默旁路。本轮按
# REVIEW F1~F5 收敛：
#   F1：mktemp / cp / 候选枚举 / 逐文件检索的 rc 与 stderr 一律不再丢弃，
#       任一失败 ⇒ `🔴 无法完成扫描：<原因>（<file:line>）` + exit 1。
#       `|| true` 与 `2>/dev/null` 只出现在已断言 rc 之后的位置。
#   F2：自证行含「候选文件 N 个」并与 git ls-files 计数一致；N=0 ⇒
#       fail-closed exit 1 + `🔴 候选面为空，无法判定`（两型：非 git 目录 ·
#       git 仓但 index 为空 —— 后者 git ls-files rc=0 但输出 0 行，rc 断言
#       抓不到，只能靠候选数断言兜住）。
#   F3：两模式（工作树 / CHECK_REV）统一显式二进制策略 —— grep -aE 把二进制
#       当文本匹配并按行归因；命中记录读取端新增「line 字段必须匹配 ^[0-9]+$」
#       断言，不匹配 ⇒ 按不可归因命中单列并 fail-closed。
#   F4：注释口径单点 —— 「什么算注释行」抽成同一 ERE，校验器与计数器共用。
#   F5：临时文件单点 —— 全脚本只剩一个 EXIT trap，统一 TMP_FILES 清单。
# 规范环境行为零变更（干净 rc=0 / 命中 rc=1 归因 file:line:content）。
# ============================================================================
# T-FIX-06 深审 🟡 收敛（阶段 6 REVIEW §0′.4 F-19/F-20 · 2026-09-25）：
# ----------------------------------------------------------------------------
# F19：自证行原本只报候选枚举计数 N（自排除前）；若 tracked 全部落在 SELF_EXCLUDE
#   6 条内，scan_file 实际调用 0 次却仍打印「清单外命中 0 条」+ ✅ + rc=0（0 实际扫描
#   与干净同形 · ADR-027 ②③ fail-closed）。fix：新增 SCANNED_COUNT（scan_file 真实
#   调用次数），自证行并列两个数 —— 「候选文件 N 个」（枚举 · 不变 · #14 断言它与
#   git ls-files 一致）+「实际扫描 M 个」（自排除后）；M=0 && N>0 ⇒ fail-closed rc=1
#   且不打印「清单外命中 0 条」/「✅」。
# F20：mktemp_checked() 内 exit 1 位于命令替换中 ⇒ 只退子 shell、脚本继续（变量退化
#   为空串，产生 3 条冗余 🔴 mktemp 报文）。fix：函数改 return 1（stderr 报文原样
#   保留），4 个调用点（3 初始化 + 1 汇总段 TMP_ALLOWLIST_KEYS）改 `|| exit 1`
#   ⇒ 坏 TMPDIR 下恰 1 条 mktemp 报文且立即 exit 1。
# F18（用户裁决 option ② 仅措辞 · 零行为变更）：SCAN_SURFACE 旧值「工作树」误导读者
#   以为未 add 的未忽略文件也在扫描面内（态 G2：`git rm --cached` 后文件仍在磁盘、
#   untracked ⇒ rc=0 是措辞误导，非拦截链断 —— 提交动作必然把文件带进 index ⇒
#   拦截面 = 被拦截对象 ADR-027）。fix：措辞精确化为「工作树（git index：已 add /
#   已提交）」，5 处打印共用单变量 ⇒ 单点改动，不给 git ls-files 加 --others。
# ============================================================================
set -uo pipefail

# ----------------------------------------------------------------------------
# 常量
# ----------------------------------------------------------------------------
# PAT（D10 定稿）：本机绝对路径前缀 `/home/<username>/`。
# `<username>` = 首字符 [a-z_]，后续 [a-z0-9_-]，末尾必须含 `/`。
# 通用占位符 `/home/user/` 会命中本 PAT ⇒ 必须叠加占位符排除表（D10 实测）。
PAT='/home/[a-z_][a-z0-9_-]*/'

# 通用占位符排除表（D10）：按「被匹配到的用户名成分」排除，不按整行排除。
# 同一行同时含占位符与真实路径时，按行排除会漏报真实路径。
# 列出可能作为占位符出现的用户名成分；命中则跳过该条 PAT 匹配。
PLACEHOLDER_NAMES='user ubuntu acct yourname foo bar someone'

# 自排除清单（D8 / D10′② · 强制 · 逐条精确路径，禁宽通配）。
# 这些文件本身必然含 PAT 字面（脚本自我引用、允许清单格式说明、审查档讨论），
# 必须从扫描面排除 —— 否则门禁会被自己的工件击穿。
# 禁用 reference/* / skills/* / .specs/* 之类宽通配（D10′② 实测：通配会吞掉
# 31 处 <acct> 字样含 10+ 处真实账号路径，且永久无界）。
# 后续阶段新增审查档时必须**显式追加精确路径**到本清单（不得改宽通配）。
SELF_EXCLUDE='
flow-kit-bundle/flow-kit/reference/check-path-privacy.sh
flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt
.specs/health-fix-2026-09b/path-privacy-allowlist.txt
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-1.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-2.md
.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-3.md
'

# 允许清单读序（R8 定级裁决 · 强制 · fail-closed）：
#   常设路径 > change 副本 > 两者皆缺 ⇒ exit 1 并指名缺失路径（不得当空清单放行）。
# 常设路径不受 change 目录归档影响（ADR-028 决策 1）。
ALLOWLIST_PERSISTENT='flow-kit-bundle/flow-kit/reference/path-privacy-allowlist.txt'
ALLOWLIST_CHANGE='.specs/health-fix-2026-09b/path-privacy-allowlist.txt'

# ----------------------------------------------------------------------------
# 临时文件与清理（F5 · 单一事实源 · DESIGN 0.5.2 原子写范式 · bash 3.2 兼容）
# ----------------------------------------------------------------------------
# 全脚本只剩一个 EXIT trap（F5 fix）：TMP_FILES 是临时文件的唯一登记表，
# 新增临时文件只登记进本变量，早期退出路径也由同一个 trap 覆盖。
TMP_ALLOWLIST=''
TMP_CANDIDATES=''
TMP_HITS=''
TMP_ALLOWLIST_KEYS=''
# R3-4 fix：清理清单改普通数组 + "${TMP_FILES[@]}"（bash 3.2 兼容，禁 mapfile/nameref），
# TMPDIR 含空格时 cleanup 不再词分裂残留。
TMP_FILES=()
cleanup() {
  local f
  for f in "${TMP_FILES[@]}"; do
    [ -n "$f" ] && rm -f "$f" 2>/dev/null
  done
}
trap cleanup EXIT
# R3-5 fix：register_tmp 将临时文件登记进清理清单数组；所有 mktemp 站点（含
# 早期失败路径）均经此登记，避免早期 mktemp 成功而后继失败时已建件未清理。
register_tmp() {
  TMP_FILES+=("$1")
}

# ----------------------------------------------------------------------------
# F1 · mktemp rc 断言（机械故障 ⇒ 必须非 0）
# ----------------------------------------------------------------------------
# 旧实现 `TMP_X=$(mktemp)` 不校验 rc —— 坏 TMPDIR 链路上 mktemp 失败、其后
# 重定向全失败，仓内真泄漏仍打印「清单外命中 0 条 ✅」且 rc=0（fail-open）。
# fix：mktemp 失败 ⇒ 立即 fail-closed exit 1 + 指名原因。
mktemp_checked() {
  local out
  out=$(mktemp 2>/dev/null)
  local rc=$?
  if [ $rc -ne 0 ] || [ -z "$out" ]; then
    echo "🔴 无法完成扫描：mktemp 失败（TMPDIR=${TMPDIR:-未设置}）" >&2
    echo "   位置: check-path-privacy.sh:mktemp_checked（候选枚举/命中暂存）" >&2
    return 1
  fi
  printf '%s\n' "$out"
}
# F20 fix（阶段 6 深审）：mktemp_checked 在命令替换中被调用，旧版内 `exit 1`
# 只退子 shell、脚本继续（变量退化为空串，产生 3 条冗余 🔴 mktemp 报文）。
# 改为 `return 1` 后调用点须显式 `|| exit 1` 以立即终止主脚本（bash 3.2 兼容，
# 不用 local -n / nameref）。三处初始化调用点 + 汇总段 TMP_ALLOWLIST_KEYS 共 4 处。
# R3-5 fix：每个 mktemp 成功后立即登记进清理清单（而非末尾批量赋值），
# 早期 mktemp 失败路径上已建件也会被同一 EXIT trap 清理。
TMP_ALLOWLIST=$(mktemp_checked) || exit 1
register_tmp "$TMP_ALLOWLIST"
TMP_CANDIDATES=$(mktemp_checked) || exit 1
register_tmp "$TMP_CANDIDATES"
TMP_HITS=$(mktemp_checked) || exit 1
register_tmp "$TMP_HITS"
# R3-2 fix：index ∪ 磁盘并集去重表（record_hit 用）。
TMP_HITS_DEDUP=$(mktemp_checked) || exit 1
register_tmp "$TMP_HITS_DEDUP"
# R3-30/R3-7/R3-2 fix：git grep --null 原始输出捕获临时文件。
# bash 命令替换 `$(...)` 会剥离 NUL 字节 ⇒ git grep --null 输出必须落临时文件，
# 不能用 `$(git grep --null ...)`（否则 NUL 丢失 ⇒ 无法解析）。
TMP_GREP_RAW=$(mktemp_checked) || exit 1
register_tmp "$TMP_GREP_RAW"

# ----------------------------------------------------------------------------
# 评估面选择：CHECK_REV 外部指定（L-131 · ADR-027 拦截面 = 被拦截对象）
# ----------------------------------------------------------------------------
# 缺省（CHECK_REV 空）⇒ 扫本地工作树内 git index（已 add / 已提交）的 tracked 文件
# （git ls-files = index + 已提交，不含未 add 的未忽略文件；grep 工作树内容）。
# CHECK_REV 非空 ⇒ 评估面切换为该 rev 的树。
#   pre-push 的拦截对象是「被推送的 ref 树」，不是本地工作树 —— 工作树干净时
#   泄漏提交会被整批放行（L-131）。CHECK_REV 可能是**注解 tag 对象**的 sha
#   （pre-push 对 tag 推送给的是 tag 对象 sha），故先解析为 commit 再用。
SCAN_SURFACE='工作树（git index：已 add / 已提交）'
RESOLVED_REV=''

if [ -n "${CHECK_REV:-}" ]; then
  # 先解析为 commit（fail-closed：rev 不存在 / 非 commit-ish ⇒ exit 1）
  RESOLVED_REV=$(git rev-parse --verify --quiet "${CHECK_REV}^{commit}" 2>/dev/null || true)
  if [ -z "$RESOLVED_REV" ]; then
    echo "🔴 CHECK_REV 无法解析为 commit（fail-closed）：${CHECK_REV}"
    echo "   git rev-parse --verify --quiet '${CHECK_REV}^{commit}' 失败"
    echo "   扫描面: ${CHECK_REV}（未解析）"
    exit 1
  fi
  SCAN_SURFACE="$RESOLVED_REV"
fi

# ----------------------------------------------------------------------------
# 读允许清单（R8 读序 · fail-closed · F1 · cp rc 断言）
# ----------------------------------------------------------------------------
# 常设路径优先；常设缺则读 change 副本；两者皆缺 ⇒ exit 1 并指名（不得放行）。
# F1 fix：`cp -- … "$TMP_ALLOWLIST"` 必须断言 rc —— 坏 TMPDIR 链路上 cp 先于
# mktemp 报错被吞（mktemp 成功但 cp 写入失败 ⇒ 清单副本为空 ⇒ 后续校验全假绿）。
# R3-14 (c)① 允许清单来源覆盖旋钮（ADR-022 消费者项目随包解析）：
#   FLOW_KIT_PRIVACY_ALLOWLIST 非空 ⇒ 读该路径（优先级最高，覆盖常设/change 读序）；
#   文件不存在 / 不可读 ⇒ fail-closed exit 1 并指名路径（不得当空清单放行）。
#   未设置（空）⇒ 现有读序逐字不变（常设 > change > 缺失 ⇒ exit 1）。
#   设计目的：hook 回退调用随包检查器时，由 hook 自身位置推导出随包
#   reference/path-privacy-allowlist.txt 并导出此变量，使消费者项目（常设/change
#   皆无）也能用随包清单完成内容扫描，CWD 保持项目根。
ALLOWLIST_SOURCE=''
if [ -n "${FLOW_KIT_PRIVACY_ALLOWLIST:-}" ]; then
  if [ ! -f "$FLOW_KIT_PRIVACY_ALLOWLIST" ]; then
    echo "🔴 允许清单缺失（fail-closed，FLOW_KIT_PRIVACY_ALLOWLIST 指定的路径不存在）："
    echo "   覆盖路径: ${FLOW_KIT_PRIVACY_ALLOWLIST}"
    echo "   扫描面: ${SCAN_SURFACE}"
    exit 1
  fi
  if ! cp -- "$FLOW_KIT_PRIVACY_ALLOWLIST" "$TMP_ALLOWLIST" 2>/dev/null; then
    echo "🔴 无法完成扫描：cp 写入允许清单副本失败（FLOW_KIT_PRIVACY_ALLOWLIST）" >&2
    echo "   位置: check-path-privacy.sh:cp-allowlist-override" >&2
    echo "   来源: ${FLOW_KIT_PRIVACY_ALLOWLIST}" >&2
    exit 1
  fi
  ALLOWLIST_SOURCE="$FLOW_KIT_PRIVACY_ALLOWLIST"
elif [ -f "$ALLOWLIST_PERSISTENT" ]; then
  if ! cp -- "$ALLOWLIST_PERSISTENT" "$TMP_ALLOWLIST" 2>/dev/null; then
    echo "🔴 无法完成扫描：cp 写入允许清单副本失败（常设路径）" >&2
    echo "   位置: check-path-privacy.sh:cp-allowlist-persistent" >&2
    echo "   来源: ${ALLOWLIST_PERSISTENT}" >&2
    exit 1
  fi
  ALLOWLIST_SOURCE="$ALLOWLIST_PERSISTENT"
elif [ -f "$ALLOWLIST_CHANGE" ]; then
  if ! cp -- "$ALLOWLIST_CHANGE" "$TMP_ALLOWLIST" 2>/dev/null; then
    echo "🔴 无法完成扫描：cp 写入允许清单副本失败（change 副本）" >&2
    echo "   位置: check-path-privacy.sh:cp-allowlist-change" >&2
    echo "   来源: ${ALLOWLIST_CHANGE}" >&2
    exit 1
  fi
  ALLOWLIST_SOURCE="$ALLOWLIST_CHANGE"
else
  echo "🔴 允许清单缺失（fail-closed，不得当空清单放行）："
  echo "   常设路径: ${ALLOWLIST_PERSISTENT}"
  echo "   change 副本: ${ALLOWLIST_CHANGE}"
  echo "   扫描面: ${SCAN_SURFACE}"
  exit 1
fi

# ----------------------------------------------------------------------------
# 常设清单自校验 · 格式校验（T23 · L3 #4 major③ fix · ADR-028 规则 ①）
# ----------------------------------------------------------------------------
# 每一非注释、非空行必须匹配 `file:token` 语法（对 check-path-privacy =
# `<路径>:<行号>`，可附 ` # 理由` 尾随注释）。违者 ⇒ rc=1 并在报文里指名
# ① 清单路径（path-privacy-allowlist.txt）② 违例行号与违例内容。
# 理由：允许清单是门禁信任根；格式违例 = 清单**本身**失真（非扫描内容泄漏），
# 必须在读取阶段就拦截 —— 否则畸形行被静默吞掉、ALLOWLIST_COUNT 把它计成
# 有效条目 ⇒ 信任根静默失效（fail-open）。双态判别力（T23 verify 固化）：
#   畸形行（如 `ZZ-BAD-LINE-NO-COLON`，无冒号）⇒ rc=1 指名 file:line:content；
#   合法 `file:line` + 理由注释 / 整行注释 / 空行 ⇒ 不触发。
#
# F4 fix：注释口径单点 —— 「什么算注释行」抽成同一 ERE（IS_COMMENT_OR_BLANK），
# 校验器与计数器共用，使仅含 `<!-- … -->` 或 `#` 注释的清单在自证行里口径一致。
# 旧实现校验器 `:144-147` 同时认 `#` 与 `<!--`，计数器 `:198`/`:341` 只认 `#` ⇒
# `<!-- … -->` 行被计为有效条目，自证行「允许清单 N 条」虚高。
#
# R3-8 fix（阶段 6 第 3 轮）：尾随 `<!-- … -->` 注释口径统一。
# 旧 ERE `^[[:space:]]*(#|<!--|$)` 只认「整行以 # 或 <!-- 开头」的注释行；
# 但 `core=${line%%#*}` 只剥首个 # 尾随注释，不剥 `<!-- … -->` 尾随注释 ⇒
# `file:line <!-- 理由 -->` 行 core 残留 `file:line <!-- 理由 -->` ⇒ after
# 非纯数字 ⇒ 格式违例假红。fix：注释口径统一到同一 ERE —— 前导 `#`/`<!--`/
# 空行（整行注释）由 IS_COMMENT_OR_BLANK_RE 判定；尾随注释（# 或 <!--…-->）
# 在 core 剥离阶段一并剥除（见 validate_allowlist_format 与键提取两处）。
IS_COMMENT_OR_BLANK_RE='^[[:space:]]*(#|<!--|$)'

validate_allowlist_format() {
  local al_path="$1"       # 常设 / change 路径名（用于报文归因）
  local al_file="$2"       # 实际读取的清单内容（临时文件）
  local lineno=0 line core before after stripped
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    # 跳过空行 / 纯空白行 —— 不计入格式校验
    stripped=$line
    stripped=${stripped//[[:space:]]/}
    [ -z "$stripped" ] && continue
    # F4：注释口径单点 —— 整行注释（# 或 <!-- 开头）用同一 ERE 判定
    if printf '%s\n' "$line" | grep -qE "$IS_COMMENT_OR_BLANK_RE"; then
      continue
    fi
    # 剥尾随理由注释：先剥 `<!-- … -->`（整段含尖括号），再剥首个 # 起，再去前后空白
    # R3-8 fix：尾随 `<!-- … -->` 注释与 `#` 注释口径统一（避免 `file:line <!-- 理由 -->` 被判违例）
    core=${line%%#*}
    # 剥尾随 `<!-- … -->`：若 core 仍含 `<!--`，截到 `<!--` 之前
    case "$core" in
      *'<!--'*) core="${core%%<!--*}" ;;
    esac
    core=${core%"${core##*[![:space:]]}"}  # 去尾随空白
    core=${core#"${core%%[![:space:]]*}"}   # 去前导空白
    # core 现应为 `<路径>:<行号>`：含冒号、冒号后纯数字、冒号前非空
    before=${core%%:*}
    after=${core#*:}
    case "$core" in
      *:*) ;;                               # 含冒号 ⇒ 继续判行号段
      *)
        echo "🔴 允许清单格式违例（ADR-028 规则 ① · file:token 语法）："
        echo "   清单: ${al_path}"
        echo "   ${lineno}: ${line}"
        return 1
        ;;
    esac
    case "$after" in
      ''|*[!0-9]*)
        echo "🔴 允许清单格式违例（ADR-028 规则 ① · file:token 语法）："
        echo "   清单: ${al_path}"
        echo "   ${lineno}: ${line}"
        return 1
        ;;
    esac
    if [ -z "$before" ]; then
      echo "🔴 允许清单格式违例（ADR-028 规则 ① · file:token 语法）："
      echo "   清单: ${al_path}"
      echo "   ${lineno}: ${line}"
      return 1
    fi
  done < "$al_file"
  return 0
}

# 在 ALLOWLIST_COUNT 之前做格式校验 —— 畸形行必须先被拦截，否则会被计入有效条目。
if ! validate_allowlist_format "$ALLOWLIST_SOURCE" "$TMP_ALLOWLIST"; then
  echo "   扫描面: ${SCAN_SURFACE}"
  exit 1
fi

# 统计允许清单有效条目数（每行一条 file:line + 可选理由注释；剥整行注释与空行）。
# 注：允许清单格式 = `file:line` 每行一条 + 理由注释（ADR-028 决策 1）。
# grep -c 计数为 0 时退出码为 1（仍打印 "0"）；写成 `$(grep -c … || printf '0')`
# 会把 '0' 打成两行 ⇒ 自证行在零计数态被折断（L-133 修复轮 2 · 2026-09-23）。
# 惯用法：命令替换成功后变量已持 '0'；`||` 只兜非零退出码 ⇒ 恒为单行。
#
# F4 fix：计数器与校验器共用同一注释口径 ERE（IS_COMMENT_OR_BLANK_RE），
# `<!-- … -->` 行不再被计为有效条目。
#
# 空基线双态自检 (a) 固化点（T22 · L3 #4 major② fix）：
# 此处 ALLOWLIST_COUNT=0 = 文件**存在**但有效条目为 0（合法的空基线态），
# 与上方 `exit 1` 的「文件缺失（fail-closed）」严格区分：缺失 ⇒ rc=1，
# 空基线 ⇒ 继续扫描、不跳过、不报错；0 条不阻塞扫描（见下方自证行与 exit 0）。
# R3-6 fix：grep -c rc=2（机械出错）不得折算成 0（否则清单键集空 ⇒ 假红）。
# rc=0 ⇒ 正常计数；rc=1 ⇒ 0 匹配（打印 0）；rc≥2 ⇒ fail-closed exit 1。
ALLOWLIST_COUNT=$(grep -cvE "$IS_COMMENT_OR_BLANK_RE" "$TMP_ALLOWLIST" 2>/dev/null)
case $? in
  0) ;;
  1) ALLOWLIST_COUNT=0 ;;
  *)
    echo "🔴 无法完成扫描：grep 统计清单条目失败（清单机械出错 · rc≥2）" >&2
    echo "   位置: check-path-privacy.sh:allowlist-count" >&2
    exit 1
    ;;
esac

# ----------------------------------------------------------------------------
# 枚举候选文件（扫描面 = git ls-files，不扫 .git 内部 · F1 · rc 断言）
# ----------------------------------------------------------------------------
# F1 fix：候选枚举（git ls-tree / git ls-files）的 rc 必须断言 —— 失败 ⇒
# fail-closed exit 1。注意 git ls-files 在「git 仓但 index 为空」时 rc=0 只是
# 输出 0 行 ⇒ rc 断言抓不到这一型，只能靠下方 F2 的候选数断言兜住。
if [ -n "$RESOLVED_REV" ]; then
  # rev 模式：候选 = 该 rev 树的全部文件
  # R3-1/R3-30 fix：git ls-tree -z 输出 NUL 分隔路径，避免 core.quotePath=true
  # 时非 ASCII / 含 "/\ 字符的路径被 C 引号化 ⇒ 下方 read -r -d '' 逐条取原样。
  if ! git ls-tree -r -z --name-only "$RESOLVED_REV" -- > "$TMP_CANDIDATES" 2>/dev/null; then
    echo "🔴 无法完成扫描：git ls-tree 失败（rev=${RESOLVED_REV}）" >&2
    echo "   位置: check-path-privacy.sh:ls-tree" >&2
    exit 1
  fi
else
  # 工作树模式：候选 = tracked 文件（git ls-files = index + 已提交，不含未 add 的未忽略文件；不含 .git 内部）
  # 非 git 目录时 git ls-files rc≠0 ⇒ 此处直接 fail-closed（F2 第一型）
  # R3-1 fix：git ls-files -z 输出 NUL 分隔路径，避免 core.quotePath 引号化。
  if ! git ls-files -z -- > "$TMP_CANDIDATES" 2>/dev/null; then
    echo "🔴 无法完成扫描：git ls-files 失败（非 git 目录或 git 不可用）" >&2
    echo "   位置: check-path-privacy.sh:ls-files" >&2
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# F2 · 候选文件数自证 + 0 候选面 fail-closed
# ----------------------------------------------------------------------------
# 旧实现候选枚举产物从未被断言非空 —— 0 候选面（非 git 目录 / 空 index / 损坏
# index / 空 rev）与「全部干净」同形（都输出「命中合计 0 条 ✅」⇒ rc=0）。
# fix：自证行含「候选文件 N 个」并与 git ls-files 计数一致；N=0 ⇒
# fail-closed exit 1 + `🔴 候选面为空，无法判定`。
# R3-1/R3-30 fix：候选数改按 NUL 计数（git ls-files -z / ls-tree -z 输出），
# 与 git ls-files 计数一致（#14 断言口径不变，改用 NUL 计数比较）。
CANDIDATE_COUNT=0
while IFS= read -r -d '' f; do
  CANDIDATE_COUNT=$((CANDIDATE_COUNT + 1))
done < "$TMP_CANDIDATES"
if [ "$CANDIDATE_COUNT" -eq 0 ]; then
  echo "🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=${PAT}）"
  echo "   扫描面: ${SCAN_SURFACE}"
  echo "   允许清单来源: ${ALLOWLIST_SOURCE}"
  echo "   允许清单 ${ALLOWLIST_COUNT} 条"
  echo "   候选文件 0 个"
  echo "🔴 候选面为空，无法判定（0 候选 ≠ 干净 · ADR-027 ②③ fail-closed）"
  exit 1
fi

# ----------------------------------------------------------------------------
# 占位符排除判定（按用户名成分，不按整行）
# ----------------------------------------------------------------------------
# 给定一个「用户名成分」，若它在占位符表内则返回 0（是占位符，跳过）。
# 用 case 做 POSIX 兼容匹配（bash 3.2 无关联数组）。
is_placeholder_name() {
  local name="$1"
  local ph
  for ph in $PLACEHOLDER_NAMES; do
    [ "$name" = "$ph" ] && return 0
  done
  return 1
}

# ----------------------------------------------------------------------------
# 自排除判定（逐条精确路径）
# ----------------------------------------------------------------------------
is_self_exclude() {
  local path="$1"
  local se
  for se in $SELF_EXCLUDE; do
    [ "$path" = "$se" ] && return 0
  done
  return 1
}

# ----------------------------------------------------------------------------
# 主扫描（F1 · 检索 rc 断言 · F3 · 二进制策略单点）
# ----------------------------------------------------------------------------
# 对每个候选文件，取其 PAT 命中行；逐行判定：
#   1. 提取该行命中的用户名成分（PAT 第 1 捕获组等价）；
#   2. 若用户名成分属占位符表 ⇒ 跳过该条命中（不按整行跳过）；
#   3. 若文件属自排除清单 ⇒ 整文件跳过；
#   4. 其余命中 ⇒ 记入 TMP_HITS，格式 `file:line:content`。
#
# F3 fix：两模式（工作树 / CHECK_REV）统一显式二进制策略 —— grep -aE 把二进制
# 当文本匹配并按行归因（旧实现工作树模式 `grep -nE` 对二进制静默丢弃 ⇒ 假绿；
# rev 模式 `git grep` 把 `Binary file … matches` 当命中解析 ⇒ 假红且不可归因）。
# 命中记录读取端新增「line 字段必须匹配 ^[0-9]+$」断言（见下方汇总段）。
#
# F1 fix：逐文件检索区分 grep rc=1（无匹配）与 rc≥2（出错）—— rc≥2 ⇒
# fail-closed exit 1。`2>/dev/null` 只出现在已断言 rc 之后的位置。
#
# bash 3.2 兼容：不用 mapfile / declare -A；用 while read + 子 shell。
HITS_OUT_OF_ALLOWLIST=0
HITS_TOTAL=0
# F19 fix（阶段 6 深审）：实际扫描计数 = scan_file 真实调用次数（自排除后）。
# 旧版自证行只报候选枚举计数 N（自排除前）；若 tracked 全部命中 SELF_EXCLUDE，
# scan_file 实际调用 0 次却仍打印「清单外命中 0 条」+ ✅ + rc=0（0 实际扫描 ≠ 干净）。
# R3-31 fix（阶段 6 第 3 轮）：SCANNED_COUNT 改在 scan_file 内部成功读取后才计数；
# 另增 UNREADABLE_COUNT（缺失/不可读候选）与 INDEX_SIDE_COUNT（index 侧命中条数），
# 自证行并列四数（候选 N / 实际扫描 M / index 侧 I / 不可读 U）。
SCANNED_COUNT=0
UNREADABLE_COUNT=0
INDEX_SIDE_COUNT=0
UNREADABLE_DETAILS=''

# 逐命中占位符判定（L-133 修复 · 2026-09-23 主 agent 探针发现漏报）：
# 一行可能含多个 `/home/<name>/` 命中；旧实现 `extract_username` 用贪婪 sed 只取
# 最后一个，再据此单一成分决定是否整行 `continue` ⇒ 「真名在前、占位在后」同行被
# 整行放过（D10′② 漏报类）。正解：取该行**全部**命中，**仅当全部命中都是占位符**
# 才跳过该行；否则按 `file:line` 记命中（归因不变）。
# 返回 0 = 该行可整行跳过（全部命中皆占位符）；返回 1 = 该行含至少 1 个真名 ⇒ 记命中。
line_all_hits_placeholder() {
  local content="$1"
  local hits any_real=0
  # grep -oE 输出每个 `/home/<name>/` 命中，每行一个（bash 3.2 的 grep -oE 支持）
  hits=$(printf '%s\n' "$content" | grep -oE "$PAT" 2>/dev/null || true)
  [ -z "$hits" ] && return 1   # 无命中（不应发生，调用方已筛选）⇒ 不跳过
  local h uname
  while IFS= read -r h; do
    [ -z "$h" ] && continue
    # 从单个命中 `/home/<name>/` 抠 <name>
    uname=$(printf '%s\n' "$h" | sed -nE 's#^/home/([a-z_][a-z0-9_-]*)/$#\1#p')
    if [ -z "$uname" ] || ! is_placeholder_name "$uname"; then
      any_real=1
      break
    fi
  done <<EOF
$hits
EOF
  [ "$any_real" -eq 0 ]
}

# 记命中到 TMP_HITS 的辅助：归一化为 NUL 分隔的三段 `<path>\0<line>\0<content>\0`，
# 避免含 : 文件名被汇总循环的 `IFS=:` 切坏（R3-7）。
# 同一 file:line:content 在 index∪磁盘并集时只记一次（去重）。
record_hit() {
  local path="$1" line="$2" content="$3"
  # F3：line 字段必须匹配 ^[0-9]+$，否则按不可归因命中单列并 fail-closed
  case "$line" in
    ''|*[!0-9]*)
      printf '%s\0?\0%s\0' "$path" "$content" >> "$TMP_HITS"
      return
      ;;
  esac
  # 逐命中占位符判定（L-133）：仅当该行**全部**命中都是占位符才跳过
  if line_all_hits_placeholder "$content"; then
    return
  fi
  # R3-2 去重：index 侧与磁盘侧同一 file:line:content 只记一次。
  # 用临时去重表（已记 key 集合）。为避免重复扫，先查 grep -qxF。
  if ! grep -qxF "${path}:${line}$(printf '\t')${content}" "$TMP_HITS_DEDUP" 2>/dev/null; then
    printf '%s\t%s\n' "${path}:${line}" "$content" >> "$TMP_HITS_DEDUP"
    printf '%s\0%s\0%s\0' "$path" "$line" "$content" >> "$TMP_HITS"
  fi
}

# R3-7/R3-30 fix：解析 git grep --null 输出（从临时文件读取，保留 NUL）。
# git grep --null 格式：`<path>\0<line>\0<content>\n`（每条命中三段，NUL 分隔 path/line，
# 换行分隔不同命中）。rev 模式前缀为 `<rev>:<path>`，--cached 模式仅为 `<path>`。
# 按 NUL 取 path → line → content，避免含 : 文件名被裸 : 切坏（R3-7）。
# $1 = 输入文件路径；$2 = rev 前缀（可为空，--cached 模式）。
parse_grep_null() {
  local infile="$1" rev_prefix="$2"
  local prefix path line content
  while IFS= read -r -d '' prefix; do
    # 剥 <rev>: 前缀（rev 模式），--cached 模式 rev_prefix 为空 ⇒ 无操作
    [ -n "$rev_prefix" ] && prefix="${prefix#"${rev_prefix}:"}"
    path="$prefix"
    IFS= read -r -d '' line || line=''
    IFS= read -r content || content=''
    record_hit "$path" "$line" "$content"
  done < "$infile"
}

scan_file() {
  local file="$1"
  local lineno line uname
  if [ -n "$RESOLVED_REV" ]; then
    # rev 模式：git grep 在该 rev 树检索（读 blob 内容，对磁盘态免疫 · INDEPENDENT-REVIEW-6 ③）。
    # R3-30/R3-7 fix：git grep --null 输出落临时文件（bash `$(...)` 剥 NUL ⇒ 不能用命令替换），
    # 格式 `<rev>:<path>\0<line>\0<content>\n`，按 NUL 取 path → line → content ⇒
    # 含 : 的文件名不会被裸 : 切坏（R3-7），引号化路径不再被当 pathspec 字面量（R3-30）。
    # F3：统一 -a（把二进制当文本匹配 + 按行归因）。
    # F1：git grep rc≠0 且有 stderr ⇒ fail-closed；rc=1（无匹配）⇒ 静默跳过。
    local ggrc
    : > "$TMP_GREP_RAW"
    git grep -naE --null "$PAT" "$RESOLVED_REV" -- "$file" > "$TMP_GREP_RAW" 2>/dev/null
    ggrc=$?
    if [ "$ggrc" -ge 2 ]; then
      echo "🔴 无法完成扫描：git grep 失败（rev=${RESOLVED_REV} file=${file}）" >&2
      echo "   位置: check-path-privacy.sh:git-grep" >&2
      exit 1
    fi
    # R3-31：成功读取 ⇒ 计入 SCANNED_COUNT（先增后扫改为成功读取后才计数）。
    SCANNED_COUNT=$((SCANNED_COUNT + 1))
    [ ! -s "$TMP_GREP_RAW" ] && return 0
    parse_grep_null "$TMP_GREP_RAW" "$RESOLVED_REV"
  else
    # 工作树模式：R3-2 fix —— 内容面 = index ∪ 磁盘并集（去重）。
    # 旧实现只读磁盘 ⇒ staged 泄漏 + 工作树改干净 ⇒ rc=0 假绿（index 仍含泄漏）。
    # 正解：index 侧 git grep --cached + 磁盘侧 grep，两者命中并集（同一 file:line:content 去重）。
    # 文件缺失（deleted tracked）⇒ 不可读候选，计数 UNREADABLE_COUNT（动作③，不再静默跳过）。
    local raw_disk grc_disk grc_index
    # 磁盘侧
    raw_disk=''
    if [ -f "$file" ]; then
      raw_disk=$(grep -naE "$PAT" "$file" 2>/dev/null)
      grc_disk=$?
      if [ "$grc_disk" -ge 2 ]; then
        echo "🔴 无法完成扫描：grep 检索失败（file=${file}）" >&2
        echo "   位置: check-path-privacy.sh:grep-worktree-disk" >&2
        exit 1
      fi
    else
      # 动作③：缺失/不可读候选不再静默 return 0 ⇒ 计数 UNREADABLE_COUNT + fail-closed
      UNREADABLE_COUNT=$((UNREADABLE_COUNT + 1))
      UNREADABLE_DETAILS="${UNREADABLE_DETAILS}${file}
"
    fi
    # index 侧（git grep --cached --null，--cached 必须在首个非选项参数前；
    # --null 输出含 NUL ⇒ 落临时文件而非命令替换）
    : > "$TMP_GREP_RAW"
    git grep --cached -naE --null "$PAT" -- "$file" > "$TMP_GREP_RAW" 2>/dev/null
    grc_index=$?
    if [ "$grc_index" -ge 2 ]; then
      echo "🔴 无法完成扫描：git grep --cached 失败（file=${file}）" >&2
      echo "   位置: check-path-privacy.sh:grep-worktree-index" >&2
      exit 1
    fi
    # R3-31：成功读取（磁盘或 index 任一可读）⇒ 计入 SCANNED_COUNT
    SCANNED_COUNT=$((SCANNED_COUNT + 1))
    # 磁盘侧命中（grep -naE 输出 `line:content`，路径用 $file）
    local hitline l c
    if [ -n "$raw_disk" ]; then
      printf '%s\n' "$raw_disk" | while IFS= read -r hitline; do
        l="${hitline%%:*}"
        c="${hitline#*:}"
        record_hit "$file" "$l" "$c"
      done
    fi
    # index 侧命中（git grep --cached --null 输出 `<path>\0<line>\0<content>\n`）
    if [ -s "$TMP_GREP_RAW" ]; then
      INDEX_SIDE_COUNT=$((INDEX_SIDE_COUNT + 1))
      parse_grep_null "$TMP_GREP_RAW" ''
    fi
  fi
}

# 逐候选文件扫描（跳过自排除清单）
# F19：在自排除判定之后、scan_file 之前递增 SCANNED_COUNT，以记录实际扫描次数。
# R3-1/R3-30 fix：read -r -d '' 逐条取 NUL 分隔路径（git ls-files -z / ls-tree -z）。
# R3-31 fix：SCANNED_COUNT 改在 scan_file 内部成功读取后才计数（此处不再预增）。
while IFS= read -r -d '' f; do
  [ -z "$f" ] && continue
  is_self_exclude "$f" && continue
  scan_file "$f"
done < "$TMP_CANDIDATES"

# F19（阶段 6 深审）：0 实际扫描 ≠ 干净 —— 候选面经自排除后为空（N>0 但 M=0）
# 时不得打印「清单外命中 0 条」/「✅」+ rc=0（假绿），须 fail-closed。
# R3-31 fix：实际扫描 M 由 scan_file 内部成功读取后计数；M=0 && N>0 仍 fail-closed
# （T-FIX-06 F-19 语义不回退）。
if [ "$SCANNED_COUNT" -eq 0 ] && [ "$CANDIDATE_COUNT" -gt 0 ]; then
  echo "🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=${PAT}）"
  echo "   扫描面: ${SCAN_SURFACE}"
  echo "   允许清单来源: ${ALLOWLIST_SOURCE}"
  echo "   允许清单 ${ALLOWLIST_COUNT} 条"
  echo "   候选文件 ${CANDIDATE_COUNT} 个"
  echo "   实际扫描 ${SCANNED_COUNT} 个"
  echo "   不可读候选 ${UNREADABLE_COUNT} 个"
  echo "🔴 候选面经自排除后为空，无法判定（0 实际扫描 ≠ 干净 · ADR-027 ②③ fail-closed）"
  exit 1
fi

# R3-2 动作③：不可读候选（缺失/不可读）>0 ⇒ fail-closed（不得把「读不到」折算成「干净」）。
# 旧实现 :450 静默 `return 0` 把 deleted tracked 当干净跳过 ⇒ 假绿。
if [ "$UNREADABLE_COUNT" -gt 0 ]; then
  echo "🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=${PAT}）"
  echo "   扫描面: ${SCAN_SURFACE}"
  echo "   允许清单来源: ${ALLOWLIST_SOURCE}"
  echo "   允许清单 ${ALLOWLIST_COUNT} 条"
  echo "   候选文件 ${CANDIDATE_COUNT} 个"
  echo "   实际扫描 ${SCANNED_COUNT} 个"
  echo "   不可读候选 ${UNREADABLE_COUNT} 个"
  echo "🔴 不可读候选 ${UNREADABLE_COUNT} 个（缺失/不可读 ⇒ fail-closed，不得折算为干净）"
  printf '%s' "$UNREADABLE_DETAILS" | sed 's/^/   /'
  exit 1
fi

# ----------------------------------------------------------------------------
# 汇总：允许清单内 vs 清单外（F3 · line 字段数字断言 · F5 · TMP_FILES 单点 · R3-7 NUL 解析）
# ----------------------------------------------------------------------------
# 允许清单每行 `file:line`（可能带 ` # 理由`）；取 `file:line` 前缀做集合比对。
# 命中行的归因 = `file:line`；查它是否在允许清单内。
# R3-7 fix：TMP_HITS 改 NUL 分隔三段 `<path>\0<line>\0<content>\0`，汇总循环
# 用 `read -r -d ''` 按 NUL 取字段，避免含 : 文件名被 `IFS=:` 切坏。
HITS_TOTAL=0
while IFS= read -r -d '' _hit_f; do
  HITS_TOTAL=$((HITS_TOTAL + 1))
  IFS= read -r -d '' _hit_l || _hit_l=''
  IFS= read -r -d '' _hit_c || _hit_c=''
done < "$TMP_HITS"

# 允许清单条目集（剥注释 → 只留 file:line 前缀）存临时文件
# F5：TMP_ALLOWLIST_KEYS 登记进 TMP_FILES（单一 EXIT trap 覆盖）
TMP_ALLOWLIST_KEYS=$(mktemp_checked) || exit 1
register_tmp "$TMP_ALLOWLIST_KEYS"
# R3-3 fix：键提取与校验器共用同一剥空白口径 —— 校验器（:233-234）去前导空白，
# 键提取旧实现只剥尾随空白（不剥前导）⇒ 缩进条目键带前导空格 ⇒ 精确匹配失败 ⇒ 假红。
# fix：键提取管道末尾加 `sed -E 's/^[[:space:]]+//'` 去前导空白，与校验器一致。
# R3-6 fix：管道 rc 断言 —— grep -vE rc=2 折算空集 ⇒ 假红；管道出错 ⇒ fail-closed。
# R3-8 fix：注释剥除口径统一 —— 先剥 `<!-- … -->`（尾随整段），再剥 `#`，再去尾随/前导空白。
if ! grep -vE "$IS_COMMENT_OR_BLANK_RE" "$TMP_ALLOWLIST" 2>/dev/null \
     | sed -E 's/<!--[^>]*>//g' \
     | sed -E 's/[[:space:]]*#.*$//' \
     | sed -E 's/[[:space:]]+$//' \
     | sed -E 's/^[[:space:]]+//' \
     > "$TMP_ALLOWLIST_KEYS" 2>/dev/null; then
  rc_keys=${PIPESTATUS[0]}
  if [ "$rc_keys" -ge 2 ]; then
    echo "🔴 无法完成扫描：grep 提取清单键失败（rc≥2）" >&2
    echo "   位置: check-path-privacy.sh:allowlist-keys" >&2
    exit 1
  fi
fi

count_in_allowlist() {
  local key="$1"
  # 精确匹配 file:line
  grep -qxF "$key" "$TMP_ALLOWLIST_KEYS" 2>/dev/null && return 0
  return 1
}

OUT_OF_ALLOWLIST_DETAILS=''
UNATTRIBUTABLE_HITS=0
UNATTRIBUTABLE_DETAILS=''
# R3-7 fix：汇总循环用 NUL 分隔读 TMP_HITS 三段（path/line/content），
# 避免含 : 文件名被 `IFS=:` 切坏。
while IFS= read -r -d '' f; do
  IFS= read -r -d '' l || l=''
  IFS= read -r -d '' c || c=''
  [ -z "$f" ] && continue
  # F3：line 字段必须匹配 ^[0-9]+$；不匹配（二进制告警行 / 不可归因命中）⇒
  # 按不可归因命中单列并 fail-closed
  case "$l" in
    ''|*[!0-9]*)
      UNATTRIBUTABLE_HITS=$((UNATTRIBUTABLE_HITS + 1))
      UNATTRIBUTABLE_DETAILS="${UNATTRIBUTABLE_DETAILS}${f}: ${c}
"
      continue
      ;;
  esac
  key="${f}:${l}"
  if count_in_allowlist "$key"; then
    : # 清单内 ⇒ 只暴露不阻塞（ADR-027 ② / ADR-028 决策 2）
  else
    HITS_OUT_OF_ALLOWLIST=$((HITS_OUT_OF_ALLOWLIST + 1))
    OUT_OF_ALLOWLIST_DETAILS="${OUT_OF_ALLOWLIST_DETAILS}${f}:${l}: ${c}
"
  fi
done < "$TMP_HITS"

# ----------------------------------------------------------------------------
# 自证输出（AC-6 · 自证式：打印条数 + file:line 归因 · F2 · 候选文件数 · F19 · 实际扫描数）
# ----------------------------------------------------------------------------
# R3-31 fix（阶段 6 第 3 轮）：自证行改四数 —— 候选 N（枚举·自排除前）/ 实际扫描 M
# （scan_file 内部成功读取后才计数·自排除后）/ index 侧 I（git grep --cached 命中条数）/
# 不可读 U（缺失/不可读候选）。M=0 && N>0 仍 fail-closed（T-FIX-06 F-19 语义不回退）。
# F19：自证含两个计数 —— 「候选文件 N 个」（枚举 · 自排除前）与「实际扫描 M 个」
# （scan_file 真实调用次数 · 自排除后）。两者差值 = 自排除命中的候选数；
# M=0 且 N>0 时由上方 fail-closed 分支拦截（不得走到此处）。
echo "🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=${PAT}）"
echo "   扫描面: ${SCAN_SURFACE}"
echo "   允许清单来源: ${ALLOWLIST_SOURCE}"
echo "   允许清单 ${ALLOWLIST_COUNT} 条"
echo "   候选文件 ${CANDIDATE_COUNT} 个"
echo "   实际扫描 ${SCANNED_COUNT} 个"
echo "   index 侧 ${INDEX_SIDE_COUNT} 条"
echo "   不可读候选 ${UNREADABLE_COUNT} 个"
echo "   命中合计 ${HITS_TOTAL} 条（含占位符排除后）"
echo "   清单外命中 ${HITS_OUT_OF_ALLOWLIST} 条"
if [ "$HITS_OUT_OF_ALLOWLIST" -gt 0 ]; then
  echo "   ── 清单外命中归因（file:line）──"
  printf '%s' "$OUT_OF_ALLOWLIST_DETAILS" | sed 's/^/   /'
fi

# F3：不可归因命中 ⇒ fail-closed（二进制告警行 / 解析失败）
if [ "$UNATTRIBUTABLE_HITS" -gt 0 ]; then
  echo "🔴 不可归因命中 ${UNATTRIBUTABLE_HITS} 条（line 字段非数字 · 二进制告警行 / 解析失败）"
  printf '%s' "$UNATTRIBUTABLE_DETAILS" | sed 's/^/   /'
  exit 1
fi

if [ "$HITS_OUT_OF_ALLOWLIST" -ne 0 ]; then
  echo "🔴 清单外命中 ${HITS_OUT_OF_ALLOWLIST} 条（非允许清单命中 ⇒ 阻塞，ADR-027 ②③ / ADR-028 决策 2）"
  exit 1
fi

# 空基线双态自检 (b) 固化点（T22 · L3 #4 major② fix）：
# 任何清单外命中 ⇒ rc=1（与清单是否为空无关）；上面 `exit 1` 分支即此态的出口。
# 空基线双态自检 (a) 固化点（T22 · L3 #4 major② fix）：
# 清单外命中 = 0（含空清单 0 条）⇒ 合法且 rc=0；自证行「允许清单 N 条」「清单外命中 0 条」
# 必须在此路径打印（N 可为 0）。空清单不得被当错误、也不得静默跳过扫描 ——
# 前者 ⇒ 永久红，后者 ⇒ 空清单下泄漏永远绿（假绿）。
echo "✅ 清单外命中 0 条（允许清单内残留只暴露不阻塞）"
exit 0
