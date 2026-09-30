#!/bin/bash
# ============================================================================
# check-gate-sync.sh — 校验 prompt↔skill toll-gate 协议一致性
# 防止双入口漂移：prompt 改了但 skill 没改（或反之）
# exit: 0=一致, 1=发现漂移, 2=脚本错误
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
COMPARED=0    # 实际参与内容比对的 PCSC 对数（两侧文件均在才算；缺失对不计）

# ============================================================================
# 边界声明（DESIGN D5 / AC-4 · 必须随本文件维护）
# ----------------------------------------------------------------------------
# 本门禁只校验 PCSC（prompt↔skill 一致性校验对）判据，判据为「比内容」：
#   比较对 = 内容本应一致、仅平台 front-matter（SKILL 独有的 YAML 头）不同的
#   prompt↔skill 载体对。v1 覆盖 3/PAIRS_TOTAL 对（实测 diff 恒为 6 行 = front-matter）。
# 边界（DESIGN D5；health-fix-2026-09c T07 修订）：
#   - PCSC 判据维持「比内容」；gate-config 值比较已由 health-fix-2026-09c T07
#     （D1/AC-7）升级：旧「只比预设名集合」边界被取代 —— 双侧经提取器
#     resolve_gate_config 读生产文本、比**键值对集合**（值漂移可转红）。
#     TD-033/TC1、TD-034/TC2 的 PCSC 侧判据仍属 v2，本面不收。
#   - 排除 PCSC 表本身：reference/phase-prompt-template.md:144 明写其属
#     「结构性文档化（不抽取）」，逐 phase 本就不应相同 —— 不纳入本门禁比较。
#   - 排除 hooks 镜像面：已有 check-hooks-sync 专职守护，纳入属重复覆盖（L2 N2）。
# 全量同步策略属 v2/TD-025；本 v1 必须打印覆盖度「校验对 N/PAIRS_TOTAL」，
#   其中 N 为实际比对对数（COMPARED），防汇总行「✅ … 一致」被误读成全量全绿。
#   任一校验对缺 prompt/skill 文件 ⇒ 计入错误（F6 收敛：不得裸 return + ✅ 全绿）。
# ============================================================================

# PCSC 校验对清单（v1：3/PAIRS_TOTAL；其余对已实质分叉，留 v2/TD-025）
# 每项：prompt 文件名(无扩展名) ; skill 目录名
# 实测这 3 对 diff 恒为 6 行（SKILL 独有 front-matter），内容逐字一致。
PAIRS=(
  "A-evolve|flow-evolve"
  "I-intel-scan|flow-intel"
  "L-restyle|flow-restyle"
)
# 全量载体对总数（常量单点，F7 收敛）：DESIGN D2 实测分档；v1 只覆盖前 3 对。
# 其余文案一律插值引用此常量，禁止再出现裸字面量 14。
PAIRS_TOTAL=14

# ── PCSC 判据：比内容（仅允许平台 front-matter 差异，其余逐行比对）──
# 设计依据（DESIGN D2 / REQUIREMENT AC-4）：
#   - 旧判据「grep -c "^| [0-9] |" 比行数」语义盲 —— 4-dev(8 行) vs flow-dev(8 行)
#     会因行数相同而通过，但那 8 行是与 PCSC 无关的迁移框架表（Prisma/Alembic/…），
#     证明纯计数比较不可用。故改为「剥离 front-matter 后逐行 diff 内容」。
#   - front-matter = SKILL 载体独有的 YAML 头（`---\nname:\ndescription:\n---\n\n`），
#     平台差异、非内容漂移 ⇒ 允许；剥离后两侧应逐字一致。
check_pair() {
  local prompt_file="$1"
  local skill_file="$2"

  local pair_label="$3"   # 仅用于显示，形如 "A-evolve ↔ flow-evolve"

  echo "   校验: $pair_label"
  echo "     prompt: $prompt_file"
  echo "     skill:  $skill_file"

  # F6 收敛：缺 prompt/skill 文件 ⇒ 计入错误（不再裸 return + ✅ 全绿）。
  # 覆盖度分母用实际比对对数（COMPARED），缺失对既不计入「已比对」也不得让汇总打印 ✅ 一致。
  if [ ! -f "$prompt_file" ]; then
    echo "   🔴 MISSING: prompt 文件不存在（校验对未比对）"
    echo "       prompt: $prompt_file"
    echo ""
    ERRORS=$((ERRORS + 1))
    return
  fi
  if [ ! -f "$skill_file" ]; then
    echo "   🔴 MISSING: skill 文件不存在（校验对未比对）"
    echo "       skill:  $skill_file"
    echo ""
    ERRORS=$((ERRORS + 1))
    return
  fi

  COMPARED=$((COMPARED + 1))

  # 剥离 YAML front-matter（若存在）：首个 ^---$ 到第二个 ^---$（含）+ 紧随的 1 个空行
  # 两侧对称剥离 —— prompt 通常无 front-matter，剥后不变；skill 剥去独有的平台头。
  # 这样「仅差 front-matter」的对内容 diff 为空；任何真实内容漂移会留下 diff。
  # 反向对照：仅 front-matter 差异（无内容漂移）→ diff 为空 → 放行（不误报）。
  # 注意（L-123）：blank_after_fm 的跳过必须仅在「确实出现过 front-matter」时生效，
  # 否则会吃掉无 front-matter 文件的首个空行（误删内容）。
  strip_front_matter() {
    awk '
      BEGIN { fm=0; saw_fm=0; blank_after_fm=0 }
      NR==1 && /^---[[:space:]]*$/ { fm=1; saw_fm=1; next }      # 首行是 --- 进入 front-matter
      fm && /^---[[:space:]]*$/ { fm=0; next }                    # 第二个 --- 关闭
      fm { next }                                                 # front-matter 内行一律丢弃
      saw_fm && !blank_after_fm && /^[[:space:]]*$/ { blank_after_fm=1; next }  # 仅当见过 fm 才跳首个空行
      { print }
    ' "$1"
  }

  local prompt_body skill_body
  prompt_body=$(strip_front_matter "$prompt_file")
  skill_body=$(strip_front_matter "$skill_file")

  # 逐行内容比对（mktemp + trap 清理，沿用 DESIGN 0.5.2 原子写范式）
  local tmp_p tmp_s
  tmp_p=$(mktemp)
  tmp_s=$(mktemp)
  trap 'rm -f "$tmp_p" "$tmp_s"' RETURN
  printf '%s\n' "$prompt_body" > "$tmp_p"
  printf '%s\n' "$skill_body" > "$tmp_s"

  # R3-20 收敛：保留 diff 的 rc，rc≥2 = 机械故障（文件不可读/参数错等），
  # 不得被 || true 折算为「无差异 ⇒ 一致」。fail-closed：具名 🔴 + ERRORS，不打印 ✅。
  # 注意：set -euo pipefail 下 `x=$(diff …)` 遇 rc=1（有差异）会触发 set -e 而中止，
  # 故先 `set +e` 取 rc 再 `set -e` 恢复（bash 3.2 兼容；rc=1 是合法「有差异」语义）。
  local diff_out diff_rc
  set +e
  diff_out=$(diff "$tmp_p" "$tmp_s" 2>/dev/null); diff_rc=$?
  set -e
  if [ "$diff_rc" -ge 2 ]; then
    echo "   🔴 MECHANICAL: diff 返回 rc=$diff_rc（机械故障：临时件不可读或参数错误，非内容判定）"
    ERRORS=$((ERRORS + 1))
    echo ""
    return
  fi

  if [ -n "$diff_out" ]; then
    # R3-18 收敛：逐侧判定并具名，不再按 hunk 行号恒打印双侧。
    # diff 输出含 `< ` 行 = 仅 prompt 侧有该内容（prompt 侧变动）；
    #            `> ` 行 = 仅 skill 侧有该内容（skill 侧变动）。
    # 据此判 prompt/skill/both，格式固定：
    #   🔴 漂移 <pair>：<prompt|skill|both> 侧内容不一致（prompt <n> 行 vs skill <m> 行）
    local prompt_only skill_only drift_side prompt_lines skill_lines
    # 注意：grep -c 在 0 匹配时 rc=1，set -e 下会中止脚本；
    # 用 count_lines 辅助函数隔离 rc（不在 diff_out 同行写 rc 兜底符，免被静态判据误判 R3-20）。
    count_lines() { local pat="$1" data="$2"; set +e; printf '%s\n' "$data" | grep -cE "$pat"; set -e; }
    prompt_only=$(count_lines '^< ' "$diff_out")
    skill_only=$(count_lines '^> ' "$diff_out")
    prompt_lines=$(count_lines '.' "$prompt_body")
    skill_lines=$(count_lines '.' "$skill_body")
    if [ "$prompt_only" -gt 0 ] && [ "$skill_only" -gt 0 ]; then
      drift_side="both"
    elif [ "$prompt_only" -gt 0 ]; then
      drift_side="prompt"
    else
      drift_side="skill"
    fi
    echo "   🔴 漂移 ${prompt_name} ↔ ${skill_name}：${drift_side} 侧内容不一致（prompt ${prompt_lines} 行 vs skill ${skill_lines} 行）"
    # 漂移报文必须含「文件:行号」定位（AC-4 Then② / NFR 失败指名口径）。
    # 规范定位串形如 `prompts/<name>.md:N` 或 `skills/<name>/SKILL.md:N`，
    # 必须同时含目录前缀 + 行号 —— 满足下游 grep -E '(prompts|skills)/[^ :]+:[0-9]+'。
    # diff hunk header 形如 `NaM,N`（删 prompt 第 N 行 + 增 skill 第 M 行）；
    # 仅对实际变动侧报定位行（drift_side 决定），避免张冠李戴（R3-18）。
    local first_hunk left_num right_num
    set +e
    first_hunk=$(printf '%s\n' "$diff_out" | grep -m1 -E '^[0-9]+(,[0-9]+)?[acd][0-9]+(,[0-9]+)?')
    set -e
    if [ -n "$first_hunk" ]; then
      left_num=$(printf '%s' "$first_hunk" | sed -E 's/^([0-9]+).*/\1/')
      right_num=$(printf '%s' "$first_hunk" \
        | sed -E 's/^[0-9]+(,[0-9]+)?[acd]([0-9]+).*/\2/')
      # 相对 BUNDLE_ROOT 的受检路径（保留 prompts/ skills/ 前缀）
      local prompt_rel skill_rel
      prompt_rel=${prompt_file#$BUNDLE_ROOT/flow-kit/}
      skill_rel=${skill_file#$BUNDLE_ROOT/}
      # 仅对实际变动侧报定位（drift_side ∈ {prompt, both} 报 prompt 侧；{skill, both} 报 skill 侧）
      if [ "$drift_side" = "prompt" ] || [ "$drift_side" = "both" ]; then
        if [ -n "$left_num" ] && [ "$left_num" -gt 0 ] 2>/dev/null; then
          echo "     定位: prompts/${prompt_rel#prompts/}:$left_num（prompt 侧内容漂移）"
        fi
      fi
      if [ "$drift_side" = "skill" ] || [ "$drift_side" = "both" ]; then
        if [ -n "$right_num" ] && [ "$right_num" -gt 0 ] 2>/dev/null; then
          echo "     定位: skills/${skill_rel#skills/}:$right_num（skill 侧内容漂移）"
        fi
      fi
    fi
    # 附 diff 摘要（前 8 行，避免刷屏）
    printf '%s\n' "$diff_out" | head -8 | sed 's/^/     /'
    ERRORS=$((ERRORS + 1))
  else
    echo "   ✅ 内容一致（已剥离 front-matter；diff 内容 = 0 行）"
  fi
  echo ""
}

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
#    仅直接运行时做 prompt↔skill 一致性巡检 + gate-config 键值对同步校验）
if [[ "${FK_CGS_MAIN:-0}" -eq 1 ]]; then
echo "🔍 check-gate-sync: 校验 prompt↔skill 内容一致性..."
echo ""

# ── 执行 PCSC 校验对（v1：3/PAIRS_TOTAL）──
for pair in "${PAIRS[@]}"; do
  prompt_name="${pair%%|*}"
  skill_name="${pair##*|}"
  check_pair \
    "$BUNDLE_ROOT/flow-kit/prompts/${prompt_name}.md" \
    "$BUNDLE_ROOT/skills/${skill_name}/SKILL.md" \
    "${prompt_name} ↔ ${skill_name}"
done

check_gate_config_sync

# ── 汇总 ──
echo "   ── 校验汇总 ──"
echo "   覆盖度: 实际比对 ${COMPARED}/${PAIRS_TOTAL}（v1 仅覆盖内容本应一致、仅差 front-matter 的对；其余 $((PAIRS_TOTAL - ${#PAIRS[@]})) 对已实质分叉，留 v2/TD-025；另有 $((${#PAIRS[@]} - COMPARED)) 对因文件缺失未比对）"
if [ "$ERRORS" -gt 0 ]; then
  echo "   🔴 发现 $ERRORS 处问题（漂移或文件缺失）。请同步 prompt 和 skill 的全文内容（剥离平台 front-matter 后逐行比对一致）。"
  exit 1
else
  echo "   ✅ 校验对 ${COMPARED}/${PAIRS_TOTAL} 一致（仅覆盖上述 ${COMPARED} 对，非全量 ${PAIRS_TOTAL} 对全绿）。"
  exit 0
fi
fi
