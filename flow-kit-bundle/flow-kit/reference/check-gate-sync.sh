#!/bin/bash
# ============================================================================
# check-gate-sync.sh — 校验 gate-config 预设键值对同步（SKILL.md PRESET_MAP ↔ bats 镜像）
# 防止 gate-config 契约漂移：生产 PRESET_MAP 改了但 bats mock 没改（或反之）
# exit: 0=一致, 1=发现漂移, 2=脚本错误
# T12b（health-fix-2026-09c · C13/AC-11 · L2 r2 R2 修订 2026-09-29）：PCSC「剥
# front-matter 逐行 diff」内容一致性判据整体迁出至 reference/check-skills-sync.sh
# （T12a 薄壳化后 skill 不再复制 prompt 正文，旧判据必红且语义失效）；本文件保留
# gate-config 键值对同步判据 + 提取器 resolve_gate_config（T07 · D1/AC-7/ADR-030）。
# T17（health-fix-2026-09c · C14-b/AC-12-b · 2026-09-29）：追加五载体预设名集合
# 对账段 check_gate_config_carriers（SKILL/bats/flow-state.js[权威]/gate-helpers 值域/
# 用户指南折算表）——T07 键值对面字节不动，仅追加独立判据块；非仓内上下文显式跳过。
# ============================================================================
# health-fix-2026-09c T07（DESIGN D1 / AC-7 / ADR-030）：本文件同时是**提取器宿主**。
# gate-config 契约的「预设名/值解析」上提到本 .sh —— bats 测试 source 本文件获得
# 与检查器**同一**提取器 resolve_gate_config（AC-7 Given：双侧读同一生产实现；
# 测试 source 的是检查器自身，非生产 hook lib）。被 source 时只定义函数、不注入
# shell 严格选项、不执行主流程；仅作为主程序执行时才启用严格模式并跑校验。
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail          # 主程序：严格模式（被 source 时不得污染调用方 shell 选项）
  FK_CGS_MAIN=1
else
  FK_CGS_MAIN=0              # 被 source：函数定义即止（提取器供 bats 双侧同源使用）
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ERRORS=0
# T17 五载体段状态：1=未运行/跳过（非仓内上下文），0=已运行（汇总覆盖度计 2/2）
CARRIERS_SKIPPED=1

# ============================================================================
# 边界声明（DESIGN D5 / AC-4 · 必须随本文件维护 · T12b 修订 2026-09-29）
# ----------------------------------------------------------------------------
# 本门禁只校验 gate-config 键值对同步判据（T07 · D1/AC-7）：双侧经同一提取器
# resolve_gate_config 读生产文本（skills/flow/SKILL.md PRESET_MAP ↔
# test/test_gate_config_presets.bats mock case 块），比**键值对集合**——任一
# 键/值漂移（如 both→independent 回退）即转红，解析失败 fail-closed 转红。
# PCSC 内容一致性判据（v1 曾辖 3 对「剥 front-matter 逐行 diff」）已于 T12b 整体
# 迁移至 reference/check-skills-sync.sh（skill 薄壳 ↔ prompt 权威载体同步，
# C13/AC-11）——T12a 薄壳化后 skill = frontmatter + 薄壳声明 + @see，不再是
# prompt 副本，旧判据必红且语义失效。历史边界沿用：phase-prompt-template.md
# PCSC 表属「结构性文档化（不抽取）」；hooks 镜像面由 check-hooks-sync 专职
# （不重复覆盖，L2 N2）；缺 skill/bats 文件 ⇒ 计入错误（F6 收敛）。
# ============================================================================

# ── 提取器：resolve_gate_config（health-fix-2026-09c T07 · D1/AC-7/ADR-030）──
# 从「生产文本」提取 gate-config 契约键值对集合（预设 → 各 phase 键=值）。
# 双侧（skills/flow/SKILL.md PRESET_MAP ↔ test/test_gate_config_presets.bats
# mock case 块）共用本提取器 —— bats 测试 source 本文件即获得与检查器同一实现
# （AC-7 Given 字面：「预设名/值解析已提到生产 .sh，测试与 check-gate-sync.sh
# 双侧 source 同一实现」；本文件即该 .sh）。
#
# ADR-030 豁免依据：本检查器位于 reference/（§2.2 纯文档目录），豁免条件之一是
# 「只把生产代码/文档当作数据（文本）读取」—— 本提取器用 grep/sed/awk 逐行
# 文本定位 + 锚点提取（ADR-030 决策 2「数据化解析」边界），**不 source、不
# eval** 被检生产 hook/skill 代码；reference→生产 仅为文本依赖。
#
# 用法:  resolve_gate_config <skill|bats> <file>
#   skill —— 读 skills/flow/SKILL.md：段锚点「预设名映射表（PRESET_MAP）」→
#            「数字映射：」；行形如 `# <name> → {...}`（首 {...} 之后可带尾注，
#            如 ⚠️ tokens 提示，提取时丢弃）。
#   bats  —— 读 test_gate_config_presets.bats：段锚点 `case "$value" in` →
#            `esac`；分支行（`full)` / `code-only|review)`，| 为别名）与其紧随
#            `echo '{...}'` 值行配对。
# 输出:  每行一个键值对，规范形 `<preset> <phase-key>=<value>`（sort -u）。
#        {...} 值**完整展开**参与比对——旧判据 sed s/\).*// 在 `)` 截断、值
#        从不参与比对（C5/C11 病灶），本提取器就此消除。
# rc:    0=提取成功；1=参数错/文件不可读；2=格式漂移（段锚点缺失或零预设行）
#        —— fail-closed：解析失败 ≠ 通过，格式漂移必须转红不得误绿（D1 取舍）。

# _rgc_expand_json — '{"k":"v",...}' → 每行 `k=v`（私有辅助；值域为
# both/L2/L3/independent 等简单词，无嵌套无逗号，可安全按 "," 切分）
_rgc_expand_json() {
  printf '%s\n' "$1" \
    | sed -e 's/^{//' -e 's/}$//' -e 's/","/"\n"/g' \
    | sed -e 's/^"//' -e 's/"$//' -e 's/":"/=/' \
    | { grep -v '^$' || true; }
}

resolve_gate_config() {
  local side="${1:-}" file="${2:-}"
  if [ -z "$side" ] || [ -z "$file" ]; then
    echo "resolve_gate_config: 用法: resolve_gate_config <skill|bats> <file>" >&2
    return 1
  fi
  if [ ! -f "$file" ]; then
    echo "resolve_gate_config: 文件不存在: $file" >&2
    return 1
  fi

  # ① 段提取（锚点定位，ADR-030 数据化解析；锚点未命中 ⇒ 空段 ⇒ 走 rc=2 fail-closed）
  local section=""
  case "$side" in
    skill)
      section=$(sed -n '/预设名映射表（PRESET_MAP）/,/数字映射：/p' "$file") || return 1
      ;;
    bats)
      section=$(sed -n '/^  case "$value" in/,/^  esac/p' "$file") || return 1
      ;;
    *)
      echo "resolve_gate_config: 未知侧别 '$side'（应为 skill|bats）" >&2
      return 1
      ;;
  esac

  # ② 预设行 → `<name>\t{json}` 标记流（awk 纯文本提取，不执行被检文件任何代码）
  local tagged=""
  if [ "$side" = "skill" ]; then
    tagged=$(printf '%s\n' "$section" | awk '
      /^[[:space:]]*#[[:space:]]*[a-z][a-z0-9-]*[[:space:]]+→[[:space:]]*\{/ {
        n = $0
        sub(/^[[:space:]]*#[[:space:]]*/, "", n)
        sub(/[[:space:]]+→.*/, "", n)
        j = $0
        sub(/^[^{]*/, "", j)
        sub(/\}.*/, "", j)
        print n "\t" j
      }
    ') || tagged=""
  else
    tagged=$(printf '%s\n' "$section" | awk '
      /^[[:space:]]+[a-z][a-z0-9-]*([|][a-z][a-z0-9-]*)*\)[[:space:]]*$/ {
        pend = $0
        sub(/^[[:space:]]+/, "", pend)
        sub(/\)[[:space:]]*$/, "", pend)
        next
      }
      /^[[:space:]]*\*/ || /;;/ { pend = ""; next }
      pend != "" && /echo/ && /\{/ {
        j = $0
        sub(/^[^{]*/, "", j)
        sub(/\}.*/, "", j)
        gsub(/[[:space:]]/, "", pend)
        nb = split(pend, ns, /[|]/)
        for (i = 1; i <= nb; i++) print ns[i] "\t" j
        pend = ""
      }
    ') || tagged=""
  fi
  if [ -z "$tagged" ]; then
    echo "resolve_gate_config: [$side] 段内零预设行（段锚点缺失或格式漂移）: $file" >&2
    return 2
  fi

  # ③ {...} 展开为键值对 + 预设名前缀（别名分支已拆行）+ 集合规范化
  printf '%s\n' "$tagged" \
    | while IFS=$'\t' read -r gc_name gc_json; do
        [ -n "$gc_name" ] || continue
        _rgc_expand_json "$gc_json" | sed "s/^/$gc_name /"
      done \
    | sort -u
}

# ── 校验对 2: gate-config 预设键值对同步（SKILL.md PRESET_MAP ↔ bats 镜像）──
# health-fix-2026-09c T07（D1/AC-7，取代 G4 旧判据）：旧判据只比「预设名集合」，
# 且 bats 侧 sed 在 `)` 截断（s/\).*//）——值从不参与比对，「双侧比对」实为
# 名字比对：mock 契约值漂移（生产已迁 both、mock 仍 independent）对门禁不可见
# （更绿不更红，C5/C11 病灶）。新判据：双侧经同一提取器读生产文本、比键值对
# 集合、任一键/值漂移（如 both→independent 回退）即转红、解析失败 fail-closed。
check_gate_config_sync() {
  local skill_file="$BUNDLE_ROOT/skills/flow/SKILL.md"
  local bats_file="$BUNDLE_ROOT/test/test_gate_config_presets.bats"

  echo "   校验: gate-config 预设键值对同步 (SKILL.md PRESET_MAP ↔ bats 镜像 · 提取器 resolve_gate_config)"
  echo "     skill:  $skill_file"
  echo "     bats:   $bats_file"

  # F6/R5-14 收敛：缺 skill/bats 文件 ⇒ 计入错误（不再裸 return + ✅ 全绿）。
  # 措辞与 check_pair 的 MISSING 分支同族（T-FIX-04 先例），但必须打印 gate-config 侧自身名号。
  # 具名文件路径（不得只含泛化措辞「文件缺失」）。
  local missing=0
  [ ! -f "$skill_file" ] && missing=1
  [ ! -f "$bats_file" ] && missing=$((missing + 2))
  if [ "$missing" -ne 0 ]; then
    echo "   🔴 MISSING: gate-config 同步无法校验（未比对）"
    [ $((missing & 1)) -ne 0 ] && echo "       skill: $skill_file"
    [ $((missing & 2)) -ne 0 ] && echo "       bats:  $bats_file"
    echo ""
    ERRORS=$((ERRORS + 1))
    return
  fi

  # 双侧提取：同一提取器 resolve_gate_config 读生产文本（不 source 被检文件）
  # `|| rc=$?` 捕获：set -e 下提取器失败不中止，转具名 🔴 PARSE（fail-closed）。
  local skill_pairs bats_pairs skill_rc bats_rc
  skill_rc=0; skill_pairs=$(resolve_gate_config skill "$skill_file") || skill_rc=$?
  bats_rc=0;  bats_pairs=$(resolve_gate_config bats "$bats_file")  || bats_rc=$?
  if [ "$skill_rc" -ne 0 ] || [ "$bats_rc" -ne 0 ]; then
    echo "   🔴 PARSE: gate-config 提取器解析生产文本失败（skill rc=$skill_rc / bats rc=$bats_rc；rc=2=段锚点缺失或零预设行）——格式漂移 fail-closed 转红（ADR-030：解析失败 ≠ 通过）"
    ERRORS=$((ERRORS + 1))
    echo ""
    return
  fi

  # 键值对集合比对（提取器内已 sort -u；diff rc≥2 = 机械故障 ⇒ 具名 🔴，不折算一致）
  local diff_out diff_rc
  if diff_out=$(diff <(printf '%s\n' "$skill_pairs") <(printf '%s\n' "$bats_pairs") 2>/dev/null); then
    diff_rc=0
  else
    diff_rc=$?
  fi
  if [ "$diff_rc" -ge 2 ]; then
    echo "   🔴 MECHANICAL: gate-config diff 返回 rc=$diff_rc（机械故障，非内容判定）"
    ERRORS=$((ERRORS + 1))
    echo ""
    return
  fi

  if [ -n "$diff_out" ]; then
    echo "   🔴 DRIFT: gate-config 预设名集合不一致（键值对集合比对：名字或值漂移——任一侧 both↔independent/L2/L3 值变动即红，旧名比对对此不可见）"
    echo "$diff_out" | sed 's/^/     /'
    ERRORS=$((ERRORS + 1))
  else
    # 集合空 fail-closed（防御纵深：提取器 rc=0 但零对的兜底；未验证 ≠ 通过）
    local pair_count preset_count
    pair_count=$(printf '%s\n' "$skill_pairs" | grep -c . || true)
    preset_count=$(printf '%s\n' "$skill_pairs" | awk '{print $1}' | sort -u | grep -c . || true)
    if [ "$pair_count" -eq 0 ]; then
      echo "   🔴 键值对集合为空（skill 侧 0 对）：无法判定一致性（未验证 ≠ 通过）"
      ERRORS=$((ERRORS + 1))
    else
      echo "   ✅ 预设名集合一致 ($preset_count 个预设) — 键值对集合比对通过 ($pair_count 对，双侧同一提取器 resolve_gate_config 读生产文本)"
    fi
  fi
  echo ""
}

# ── 校验对 3: gate-config 五载体预设名集合对账（T17 · C14-b/AC-12-b）──
# 权威全集 = 载体③ dsh-flow-kit/lib/flow-state.js PRESET_MAP（17 键，:20 一带），
# 文本解析读生产 JS——D1 哲学：读生产真源文本而非 source（ADR-030 豁免，同 T07 段）。
#   ① skills/flow/SKILL.md PRESET_MAP —— 经 T07 提取器 resolve_gate_config 读名集
#   ② test/test_gate_config_presets.bats mock case 块 —— 同一提取器（双侧同源）
#   ③ flow-state.js PRESET_MAP —— 权威真源（见上）
#   ④ hooks/pre-tool-use/gate-helpers.sh fk_check_gate_config_tamper 内联值域 ——
#      jq select 与 case 双处内联须自一致，且 ⊇ bash 侧预设使用值
#   ⑤ FLOW-KIT-用户指南.md 预设名表（只读对账，无写权）—— 别名折算后须 ⊇ ③键集
#      且无未知预设名（不要求严格相等；折算表 GC5_GUIDE_ALIAS_FOLD 内置于此，
#      随 test_gate_config_carriers.bats 注入篡改用例钉住）
# 反向控制（AC-12-b）：任一载体增删预设名不同步 ⇒ rc≠0。
# 非仓内上下文（安装态副本：$BUNDLE_ROOT/.. 无 dsh-flow-kit/lib/flow-state.js）⇒
# 载体③⑤不适用，本段**显式跳过**不计错——①②键值对主判据（T07）仍辖；仓内运行
# 必须打印五载体健康行由 bats 正向腿钉住，跳过不得静默退化为仓内逃逸口。

# _gc5_js_preset_keys <flow-state.js> — 文本解析 PRESET_MAP 键集（载体③，权威）
# 段锚点 `^const PRESET_MAP = {` → `^};`；键行 = 行含 `{` 且形如 `  full: {…}` /
# `  "code-only": {…}`（内层 phase 键行不含 `{` 且以数字开头，双条件排除）。
# rc: 0=成功；2=段锚点缺失或零键（fail-closed，语义同 resolve_gate_config）
_gc5_js_preset_keys() {
  local file="$1"
  local keys
  keys=$(sed -n '/^const PRESET_MAP = {/,/^};/p' "$file" 2>/dev/null | awk '
    /\{/ && /^[[:space:]]*"?[a-z][a-z0-9-]*"?[[:space:]]*:/ {
      line = $0
      sub(/^[[:space:]]*"/, "", line)
      sub(/^[[:space:]]*/, "", line)
      sub(/".*/, "", line)
      sub(/:.*/, "", line)
      print line
    }' | sort -u) || keys=""
  if [ -z "$keys" ]; then
    echo "_gc5_js_preset_keys: PRESET_MAP 段锚点缺失或零键: $file" >&2
    return 2
  fi
  printf '%s\n' "$keys"
}

# _gc5_gate_helpers_domains <gate-helpers.sh> — 提取载体④双处内联值域
# 输出两行：第 1 行 = jq select 值域（`.value == "X"` 枚举），第 2 行 = case 值域
# （`X|Y|Z) ;;` 行；`*)` 默认分支因首字符 * 不在提取字符类而排除）。
# rc: 0=成功；2=函数体缺失或任一值域提取为空（fail-closed）
_gc5_gate_helpers_domains() {
  local file="$1"
  local body dom_jq dom_case
  body=$(awk '/^fk_check_gate_config_tamper\(\) \{/{f=1;next} f && /^\}/{f=0} f' "$file" 2>/dev/null) || body=""
  if [ -z "$body" ]; then
    echo "_gc5_gate_helpers_domains: 未定位 fk_check_gate_config_tamper 函数体: $file" >&2
    return 2
  fi
  dom_jq=$(printf '%s\n' "$body" | grep -o '\.value == "[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/' | sort -u) || dom_jq=""
  dom_case=$(printf '%s\n' "$body" | grep -oE '^[[:space:]]*[a-zA-Z0-9|]+[[:space:]]*\)[[:space:]]*;;' | sed 's/^[[:space:]]*//;s/[[:space:]]*)[[:space:]]*;;$//' | tr '|' '\n' | sort -u) || dom_case=""
  if [ -z "$dom_jq" ] || [ -z "$dom_case" ]; then
    echo "_gc5_gate_helpers_domains: 内联值域提取为空（jq 域长度 ${#dom_jq}/case 域长度 ${#dom_case}）: $file" >&2
    return 2
  fi
  printf '%s\n' "$dom_jq" | tr '\n' ' '
  echo
  printf '%s\n' "$dom_case" | tr '\n' ' '
}

# 载体⑤别名折算表（T17 任务块：「折算表内置于 check-gate-sync 并随测试钉住」）。
# 每行 `呈现名 规范名`；指南表内出现但未登记的呈现名 = 未知预设名 ⇒ 红。
# 当前登记 0 条**改写级**别名：指南唯一复合形 = 「`code-only` / `review`（别名）」，
# 两名均为 PRESET_MAP 真键，由机械拆分规则处理（单元格内每个反引号 token 各记
# 一名）；指南若引入新呈现名（≠ PRESET_MAP 键），必须在此登记，否则转红。
GC5_GUIDE_ALIAS_FOLD=""

# _gc5_guide_fold_name <name> — 查折算表；未登记则原样返回（identity 折算）
_gc5_guide_fold_name() {
  local n="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ "$n" = "${line%% *}" ]; then
      printf '%s' "${line#* }"
      return 0
    fi
  done < <(printf '%s\n' "$GC5_GUIDE_ALIAS_FOLD")
  printf '%s' "$n"
}

# _gc5_guide_names <指南.md> — 载体⑤：预设名表第一列反引号 token 全集 + 别名折算
# 段锚点 `^### gate_config 预设名` → `^### 数字简写`；仅取 `|` 表行的第一列，
# 列内每个反引号 token 各折算一名（斜杠并列别名行自动拆分）。表头/分隔行第一列
# 无反引号自然滤除；段外 blockquote 非 `|` 行不辖。
# rc: 0=成功；2=段锚点缺失或零名（fail-closed）
_gc5_guide_names() {
  local file="$1"
  local names n folded out=""
  names=$(sed -n '/^### gate_config 预设名/,/^### 数字简写/p' "$file" 2>/dev/null | grep '^|' | awk -F'|' '{print $2}' | grep -o '`[^`]*`' | tr -d '`' | sort -u) || names=""
  if [ -z "$names" ]; then
    echo "_gc5_guide_names: 预设名表段锚点缺失或零名: $file" >&2
    return 2
  fi
  for n in $names; do
    folded=$(_gc5_guide_fold_name "$n")
    out="$out$folded"$'\n'
  done
  printf '%s' "$out" | sort -u
}

check_gate_config_carriers() {
  local repo_root js_file helpers_file guide_file
  repo_root="$(cd "$BUNDLE_ROOT/.." 2>/dev/null && pwd)" || repo_root=""
  js_file="$repo_root/dsh-flow-kit/lib/flow-state.js"
  helpers_file="$BUNDLE_ROOT/hooks/pre-tool-use/gate-helpers.sh"
  guide_file="$repo_root/FLOW-KIT-用户指南.md"

  echo "   校验: gate-config 五载体预设名集合对账 (①SKILL ②bats ③flow-state.js=权威 ④gate-helpers值域 ⑤用户指南 · T17/C14-b)"
  echo "     ③js:     $js_file"
  echo "     ④helpers: $helpers_file"
  echo "     ⑤guide:  $guide_file"
  CARRIERS_SKIPPED=0

  # 仓内上下文门：③为仓级文件（bundle 外）。安装态副本（无 ../dsh-flow-kit）不具
  # 备仓内上下文 ⇒ 本段显式跳过不计错（①②键值对主判据仍辖；见上方注释）。
  if [ ! -f "$js_file" ]; then
    echo "   ⏭️  五载体段跳过: 非仓内上下文（未见 dsh-flow-kit/lib/flow-state.js——安装态副本无载体③⑤；①②键值对判据不受影响）"
    echo ""
    CARRIERS_SKIPPED=1
    return
  fi

  # 仓内上下文 fail-closed：④⑤缺件具名计错（③已由上文判过）
  local missing=0
  [ -f "$helpers_file" ] || missing=$((missing + 1))
  [ -f "$guide_file" ] || missing=$((missing + 2))
  if [ "$missing" -ne 0 ]; then
    echo "   🔴 CARRIER-MISSING: 五载体对账无法完成（仓内上下文但载体缺失）"
    [ $((missing & 1)) -ne 0 ] && echo "       ④gate-helpers: $helpers_file"
    [ $((missing & 2)) -ne 0 ] && echo "       ⑤guide:        $guide_file"
    echo ""
    ERRORS=$((ERRORS + 1))
    return
  fi

  # 五载体提取（③文本解析 / ①②复用 T07 同源提取器 / ④值域 / ⑤折算）
  local js_keys js_rc=0
  js_keys=$(_gc5_js_preset_keys "$js_file") || js_rc=$?
  local skill_pairs2 s2_rc=0
  skill_pairs2=$(resolve_gate_config skill "$BUNDLE_ROOT/skills/flow/SKILL.md") || s2_rc=$?
  local bats_pairs2 b2_rc=0
  bats_pairs2=$(resolve_gate_config bats "$BUNDLE_ROOT/test/test_gate_config_presets.bats") || b2_rc=$?
  local doms d_rc=0
  doms=$(_gc5_gate_helpers_domains "$helpers_file") || d_rc=$?
  local gnames g_rc=0
  gnames=$(_gc5_guide_names "$guide_file") || g_rc=$?

  if [ "$js_rc" -ne 0 ] || [ "$s2_rc" -ne 0 ] || [ "$b2_rc" -ne 0 ] || [ "$d_rc" -ne 0 ] || [ "$g_rc" -ne 0 ]; then
    echo "   🔴 CARRIER-PARSE: 五载体提取失败（格式漂移 fail-closed；③js rc=$js_rc / ①skill rc=$s2_rc / ②bats rc=$b2_rc / ④值域 rc=$d_rc / ⑤指南 rc=$g_rc）——解析失败 ≠ 通过（①②与键值对面共用提取器，若彼处已计错此处为同源复报）"
    ERRORS=$((ERRORS + 1))
    echo ""
    return
  fi

  # 名集整理（①②从键值对首列取名；③已 sort -u；⑤已折算 sort -u）
  local s_names b_names
  s_names=$(printf '%s\n' "$skill_pairs2" | awk '{print $1}' | sort -u)
  b_names=$(printf '%s\n' "$bats_pairs2" | awk '{print $1}' | sort -u)
  local dom_jq dom_case used_vals
  dom_jq=$(printf '%s\n' "$doms" | sed -n '1p' | sed 's/ $//')
  dom_case=$(printf '%s\n' "$doms" | sed -n '2p' | sed 's/ $//')
  used_vals=$(printf '%s\n' "$skill_pairs2" | awk '{print $2}' | cut -d= -f2 | sort -u | tr '\n' ' ' | sed 's/ $//')

  # 集合比对（双向具名；comm 需同序输入——两侧均 sort -u）
  local drift=0 only_s only_js only_b only_jsb only_g_known only_g_miss
  only_s=$(comm -23 <(printf '%s\n' "$s_names") <(printf '%s\n' "$js_keys") | tr '\n' ' ')
  only_js=$(comm -13 <(printf '%s\n' "$s_names") <(printf '%s\n' "$js_keys") | tr '\n' ' ')
  only_b=$(comm -23 <(printf '%s\n' "$b_names") <(printf '%s\n' "$js_keys") | tr '\n' ' ')
  only_jsb=$(comm -13 <(printf '%s\n' "$b_names") <(printf '%s\n' "$js_keys") | tr '\n' ' ')
  only_g_known=$(comm -23 <(printf '%s\n' "$gnames") <(printf '%s\n' "$js_keys") | tr '\n' ' ')
  only_g_miss=$(comm -13 <(printf '%s\n' "$gnames") <(printf '%s\n' "$js_keys") | tr '\n' ' ')

  if [ -n "$only_s" ] || [ -n "$only_js" ] || [ -n "$only_b" ] || [ -n "$only_jsb" ]; then
    echo "   🔴 CARRIER-DRIFT: 五载体名集对③权威键集漂移（③=flow-state.js PRESET_MAP）"
    [ -n "$only_s" ] && echo "       ①skill 多出（不在③js 键集）: $only_s"
    [ -n "$only_js" ] && echo "       ①skill 缺失（③js 有而①无）: $only_js"
    [ -n "$only_b" ] && echo "       ②bats 多出（不在③js 键集）: $only_b"
    [ -n "$only_jsb" ] && echo "       ②bats 缺失（③js 有而②无）: $only_jsb"
    drift=1
  fi
  if [ -n "$only_g_known" ] || [ -n "$only_g_miss" ]; then
    echo "   🔴 CARRIER-DRIFT: ⑤用户指南 折算后名集与③权威键集不符（要求：折算后 ⊇ ③键集 且无未知预设名；指南无写权，红时只报不代修）"
    [ -n "$only_g_known" ] && echo "       ⑤指南折算后含未知预设名（不在③js 键集；如为新呈现名请在 GC5_GUIDE_ALIAS_FOLD 登记）: $only_g_known"
    [ -n "$only_g_miss" ] && echo "       ⑤指南折算后未覆盖（③js 有而⑤指南无）: $only_g_miss"
    drift=1
  fi
  if [ "$dom_jq" != "$dom_case" ]; then
    echo "   🔴 CARRIER-DRIFT: ④gate-helpers 双处内联值域不一致（jq select 域: $dom_jq / case 域: $dom_case）"
    drift=1
  fi
  local uncovered=""
  uncovered=$(printf '%s\n' "$used_vals" | tr ' ' '\n' | grep -vxF -f <(printf '%s\n' "$dom_jq" | tr ' ' '\n') || true)
  if [ -n "$(printf '%s' "$uncovered" | tr -d '[:space:]')" ]; then
    echo "   🔴 CARRIER-DRIFT: ④gate-helpers 值域未覆盖 bash 侧使用值（未覆盖: $(printf '%s' "$uncovered" | tr '\n' ' '))——预设使用值不在 gate-helpers 内联合法域内"
    drift=1
  fi

  if [ "$drift" -eq 1 ]; then
    ERRORS=$((ERRORS + 1))
    echo ""
    return
  fi

  # 健康行（计数动态计算；T07 健康行「✅ 预设名集合一致 (17 个预设)」与此行并存不互扰）
  local n_s n_b n_js n_g
  n_s=$(printf '%s\n' "$s_names" | grep -c . || true)
  n_b=$(printf '%s\n' "$b_names" | grep -c . || true)
  n_js=$(printf '%s\n' "$js_keys" | grep -c . || true)
  n_g=$(printf '%s\n' "$gnames" | grep -c . || true)
  echo "   ✅ 五载体预设名集合一致 (①skill $n_s ②bats $n_b ③js $n_js=权威 ⑤指南折算 $n_g；④值域 $dom_jq ⊇ 使用值 $used_vals 且 jq/case 双处内联一致) — C14-b/AC-12-b"
  echo ""
}

# ── 主流程（source 时不执行：bats 测试 source 本文件取 resolve_gate_config，──
#    仅直接运行时做 gate-config 键值对同步校验；PCSC 巡检已迁移 check-skills-sync.sh）
if [[ "${FK_CGS_MAIN:-0}" -eq 1 ]]; then
echo "🔍 check-gate-sync: 校验 gate-config 预设键值对同步 + 五载体集合对账..."
echo ""

check_gate_config_sync
check_gate_config_carriers

# ── 汇总 ──
echo "   ── 校验汇总 ──"
if [ "${CARRIERS_SKIPPED:-1}" -eq 1 ]; then
  echo "   覆盖度: gate-config 校验面 1/1（PCSC 判据已迁移 check-skills-sync.sh · T12b；五载体对账未运行=非仓内上下文 · T17）"
else
  echo "   覆盖度: gate-config 校验面 2/2（①②键值对集合 + 五载体预设名/值域对账 · T17/C14-b/AC-12-b）"
fi
if [ "$ERRORS" -gt 0 ]; then
  echo "   🔴 发现 $ERRORS 处问题（漂移/缺件/解析失败）。请同步 skills/flow/SKILL.md PRESET_MAP 与 test/test_gate_config_presets.bats 的键值对集合（五载体面另见上方具名 🔴：flow-state.js / gate-helpers.sh / 用户指南 预设名表）。"
  exit 1
else
  if [ "${CARRIERS_SKIPPED:-1}" -eq 1 ]; then
    echo "   ✅ 校验对 1/1 一致（gate-config 键值对集合比对通过；五载体段安装态跳过；仅覆盖本校验面）"
  else
    echo "   ✅ 校验对 2/2 一致（键值对集合 + 五载体名集/值域对账；仅覆盖本校验面）"
  fi
  exit 0
fi
fi
