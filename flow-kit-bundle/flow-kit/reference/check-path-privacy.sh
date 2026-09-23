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
# 临时文件与清理（DESIGN 0.5.2 原子写范式 · bash 3.2 兼容）
# ----------------------------------------------------------------------------
TMP_ALLOWLIST=''
TMP_CANDIDATES=''
TMP_HITS=''
cleanup() {
  [ -n "$TMP_ALLOWLIST" ] && rm -f "$TMP_ALLOWLIST" 2>/dev/null
  [ -n "$TMP_CANDIDATES" ] && rm -f "$TMP_CANDIDATES" 2>/dev/null
  [ -n "$TMP_HITS" ] && rm -f "$TMP_HITS" 2>/dev/null
}
trap cleanup EXIT

TMP_ALLOWLIST=$(mktemp)
TMP_CANDIDATES=$(mktemp)
TMP_HITS=$(mktemp)

# ----------------------------------------------------------------------------
# 评估面选择：CHECK_REV 外部指定（L-131 · ADR-027 拦截面 = 被拦截对象）
# ----------------------------------------------------------------------------
# 缺省（CHECK_REV 空）⇒ 扫本地工作树（git ls-files / grep 工作树内容）。
# CHECK_REV 非空 ⇒ 评估面切换为该 rev 的树。
#   pre-push 的拦截对象是「被推送的 ref 树」，不是本地工作树 —— 工作树干净时
#   泄漏提交会被整批放行（L-131）。CHECK_REV 可能是**注解 tag 对象**的 sha
#   （pre-push 对 tag 推送给的是 tag 对象 sha），故先解析为 commit 再用。
SCAN_SURFACE='工作树'
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
# 读允许清单（R8 读序 · fail-closed）
# ----------------------------------------------------------------------------
# 常设路径优先；常设缺则读 change 副本；两者皆缺 ⇒ exit 1 并指名（不得放行）。
ALLOWLIST_SOURCE=''
if [ -f "$ALLOWLIST_PERSISTENT" ]; then
  cp -- "$ALLOWLIST_PERSISTENT" "$TMP_ALLOWLIST"
  ALLOWLIST_SOURCE="$ALLOWLIST_PERSISTENT"
elif [ -f "$ALLOWLIST_CHANGE" ]; then
  cp -- "$ALLOWLIST_CHANGE" "$TMP_ALLOWLIST"
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
    # 跳过整行注释（首非空字符为 #）与 HTML 注释标记 <!--（探针/标记行，非有效条目）
    core=${line#"${line%%[![:space:]]*}"}   # 去前导空白
    case "$core" in
      '#'*) continue ;;                    # 整行注释 ⇒ 跳过
      '<!--'*) continue ;;                  # HTML 注释 / 探针标记 ⇒ 跳过（非 file:line 条目）
    esac
    # 剥尾随理由注释（首个 # 起，含前导空格）再判 `file:line`
    core=${line%%#*}
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
# 空基线双态自检 (a) 固化点（T22 · L3 #4 major② fix）：
# 此处 ALLOWLIST_COUNT=0 = 文件**存在**但有效条目为 0（合法的空基线态），
# 与上方 `exit 1` 的「文件缺失（fail-closed）」严格区分：缺失 ⇒ rc=1，
# 空基线 ⇒ 继续扫描、不跳过、不报错；0 条不阻塞扫描（见下方自证行与 exit 0）。
ALLOWLIST_COUNT=$(grep -cvE '^[[:space:]]*(#|$)' "$TMP_ALLOWLIST" 2>/dev/null) || ALLOWLIST_COUNT=0

# ----------------------------------------------------------------------------
# 枚举候选文件（扫描面 = git ls-files，不扫 .git 内部）
# ----------------------------------------------------------------------------
if [ -n "$RESOLVED_REV" ]; then
  # rev 模式：候选 = 该 rev 树的全部文件
  git ls-tree -r --name-only "$RESOLVED_REV" -- > "$TMP_CANDIDATES" 2>/dev/null
else
  # 工作树模式：候选 = tracked 文件（git ls-files，不含 .git 内部）
  git ls-files -- > "$TMP_CANDIDATES" 2>/dev/null
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
# 主扫描
# ----------------------------------------------------------------------------
# 对每个候选文件，取其 PAT 命中行；逐行判定：
#   1. 提取该行命中的用户名成分（PAT 第 1 捕获组等价）；
#   2. 若用户名成分属占位符表 ⇒ 跳过该条命中（不按整行跳过）；
#   3. 若文件属自排除清单 ⇒ 整文件跳过；
#   4. 其余命中 ⇒ 记入 TMP_HITS，格式 `file:line:content`。
#
# bash 3.2 兼容：不用 mapfile / declare -A；用 while read + 子 shell。
HITS_OUT_OF_ALLOWLIST=0
HITS_TOTAL=0

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

scan_file() {
  local file="$1"
  local lineno line uname
  # rev 模式：用 git grep -nE 在该 rev 树检索；工作树模式：读文件内容 grep。
  if [ -n "$RESOLVED_REV" ]; then
    # git grep 输出前缀 = `<rev>:<path>:<line>:<content>`；剥 <rev>: 前缀再归因。
    # 这里按文件逐个检索（候选已由 ls-tree 给出），用 -E PAT。
    local raw
    raw=$(git grep -nE "$PAT" "$RESOLVED_REV" -- "$file" 2>/dev/null || true)
    [ -z "$raw" ] && return 0
    printf '%s\n' "$raw" | while IFS= read -r hitline; do
      # 剥 <rev>: 前缀 → 形如 `<path>:<line>:<content>`
      local stripped
      stripped="${hitline#"${RESOLVED_REV}:"}"
      # 拆 path:line:content
      local p l c
      p="${stripped%%:*}"
      local rest="${stripped#*:}"
      l="${rest%%:*}"
      c="${rest#*:}"
      # 逐命中占位符判定（L-133）：仅当该行**全部**命中都是占位符才跳过
      if line_all_hits_placeholder "$c"; then
        continue
      fi
      # 记命中（外部文件写入需在子 shell 外可见 ⇒ 用追加到 TMP_HITS）
      printf '%s:%s:%s\n' "$p" "$l" "$c" >> "$TMP_HITS"
    done
  else
    # 工作树模式：文件可能不存在（deleted）⇒ 跳过
    [ -f "$file" ] || return 0
    # grep -nE 输出 `line:content`；逐行处理
    local raw
    raw=$(grep -nE "$PAT" "$file" 2>/dev/null || true)
    [ -z "$raw" ] && return 0
    printf '%s\n' "$raw" | while IFS= read -r hitline; do
      local l c
      l="${hitline%%:*}"
      c="${hitline#*:}"
      # 逐命中占位符判定（L-133）：仅当该行**全部**命中都是占位符才跳过
      if line_all_hits_placeholder "$c"; then
        continue
      fi
      printf '%s:%s:%s\n' "$file" "$l" "$c" >> "$TMP_HITS"
    done
  fi
}

# 逐候选文件扫描（跳过自排除清单）
while IFS= read -r f; do
  [ -z "$f" ] && continue
  is_self_exclude "$f" && continue
  scan_file "$f"
done < "$TMP_CANDIDATES"

# ----------------------------------------------------------------------------
# 汇总：允许清单内 vs 清单外
# ----------------------------------------------------------------------------
# 允许清单每行 `file:line`（可能带 ` # 理由`）；取 `file:line` 前缀做集合比对。
# 命中行的归因 = `file:line`；查它是否在允许清单内。
HITS_TOTAL=$(grep -c . "$TMP_HITS" 2>/dev/null) || HITS_TOTAL=0

# 允许清单条目集（剥注释 → 只留 file:line 前缀）存临时文件
TMP_ALLOWLIST_KEYS=$(mktemp)
trap 'rm -f "$TMP_ALLOWLIST" "$TMP_CANDIDATES" "$TMP_HITS" "$TMP_ALLOWLIST_KEYS"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$TMP_ALLOWLIST" 2>/dev/null \
  | sed -E 's/[[:space:]]*#.*$//' \
  | sed -E 's/[[:space:]]*$//' \
  > "$TMP_ALLOWLIST_KEYS"

count_in_allowlist() {
  local key="$1"
  # 精确匹配 file:line
  grep -qxF "$key" "$TMP_ALLOWLIST_KEYS" 2>/dev/null && return 0
  return 1
}

OUT_OF_ALLOWLIST_DETAILS=''
while IFS=: read -r f l c; do
  [ -z "$f" ] && continue
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
# 自证输出（AC-6 · 自证式：打印条数 + file:line 归因）
# ----------------------------------------------------------------------------
echo "🔍 check-path-privacy: 扫描本机绝对路径前缀泄漏（PAT=${PAT}）"
echo "   扫描面: ${SCAN_SURFACE}"
echo "   允许清单来源: ${ALLOWLIST_SOURCE}"
echo "   允许清单 ${ALLOWLIST_COUNT} 条"
echo "   命中合计 ${HITS_TOTAL} 条（含占位符排除后）"
echo "   清单外命中 ${HITS_OUT_OF_ALLOWLIST} 条"
if [ "$HITS_OUT_OF_ALLOWLIST" -gt 0 ]; then
  echo "   ── 清单外命中归因（file:line）──"
  printf '%s' "$OUT_OF_ALLOWLIST_DETAILS" | sed 's/^/   /'
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
