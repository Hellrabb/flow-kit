#!/bin/bash
# ============================================================================
# check-gate-sync.sh — 校验 gate-config 预设键值对同步（SKILL.md PRESET_MAP ↔ bats 镜像）
# 防止 gate-config 契约漂移：生产 PRESET_MAP 改了但 bats mock 没改（或反之）
# exit: 0=一致, 1=发现漂移, 2=脚本错误
# T12b（health-fix-2026-09c · C13/AC-11 · L2 r2 R2 修订 2026-09-29）：PCSC「剥
# front-matter 逐行 diff」内容一致性判据整体迁出至 reference/check-skills-sync.sh
# （T12a 薄壳化后 skill 不再复制 prompt 正文，旧判据必红且语义失效）；本文件保留
# gate-config 键值对同步判据 + 提取器 resolve_gate_config（T07 · D1/AC-7/ADR-030）。
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

# ── 主流程（source 时不执行：bats 测试 source 本文件取 resolve_gate_config，──
#    仅直接运行时做 gate-config 键值对同步校验；PCSC 巡检已迁移 check-skills-sync.sh）
if [[ "${FK_CGS_MAIN:-0}" -eq 1 ]]; then
echo "🔍 check-gate-sync: 校验 gate-config 预设键值对同步..."
echo ""

check_gate_config_sync

# ── 汇总 ──
echo "   ── 校验汇总 ──"
echo "   覆盖度: gate-config 校验面 1/1（PCSC 3 对内容比对判据已迁移 reference/check-skills-sync.sh · T12b）"
if [ "$ERRORS" -gt 0 ]; then
  echo "   🔴 发现 $ERRORS 处问题（漂移/缺件/解析失败）。请同步 skills/flow/SKILL.md PRESET_MAP 与 test/test_gate_config_presets.bats 的键值对集合。"
  exit 1
else
  echo "   ✅ 校验对 1/1 一致（gate-config 键值对集合比对通过；仅覆盖本校验面）"
  exit 0
fi
fi
