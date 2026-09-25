#!/bin/bash
# ============================================================================
# check-gate-sync.sh — 校验 prompt↔skill toll-gate 协议一致性
# 防止双入口漂移：prompt 改了但 skill 没改（或反之）
# exit: 0=一致, 1=发现漂移, 2=脚本错误
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ERRORS=0
COMPARED=0    # 实际参与内容比对的 PCSC 对数（两侧文件均在才算；缺失对不计）

# ============================================================================
# 边界声明（DESIGN D5 / AC-4 · 必须随本文件维护）
# ----------------------------------------------------------------------------
# 本门禁只校验 PCSC（prompt↔skill 一致性校验对）判据，判据为「比内容」：
#   比较对 = 内容本应一致、仅平台 front-matter（SKILL 独有的 YAML 头）不同的
#   prompt↔skill 载体对。v1 覆盖 3/PAIRS_TOTAL 对（实测 diff 恒为 6 行 = front-matter）。
# 边界（DESIGN D5）：
#   - 只改 PCSC 判据；**不碰**同文件 check_gate_config_sync() 的值比较逻辑
#     （TD-033/TC1、TD-034/TC2 属 v2，本 change 不收）。
#   - 排除 PCSC 表本身：reference/phase-prompt-template.md:144 明写其属
#     「结构性文档化（不抽取）」，逐 phase 本就不应相同 —— 不纳入本门禁比较。
#   - 排除 hooks 镜像面：已有 check-hooks-sync 专职守护，纳入属重复覆盖（L2 N2）。
# 全量同步策略属 v2/TD-025；本 v1 必须打印覆盖度「校验对 N/PAIRS_TOTAL」，
#   其中 N 为实际比对对数（COMPARED），防汇总行「✅ … 一致」被误读成全量全绿。
#   任一校验对缺 prompt/skill 文件 ⇒ 计入错误（F6 收敛：不得裸 return + ✅ 全绿）。
# ============================================================================

echo "🔍 check-gate-sync: 校验 prompt↔skill 内容一致性..."
echo ""

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

# ── 校验对 2: gate-config 预设名同步（SKILL.md PRESET_MAP ↔ bats 镜像）──
# G4 ADR: 语义 set-diff（非文本段 marker）。防"SKILL.md 加预设但 bats 镜像没跟"的漂移。
# 提取两侧预设名集合做 diff；集合不等 → exit 1（计入 ERRORS）。
# 【DESIGN D5 边界】本函数的值比较逻辑属 TC1/TC2（TD-033/TD-034），v2 范围，本 task 不改。
check_gate_config_sync() {
  local skill_file="$BUNDLE_ROOT/skills/flow/SKILL.md"
  local bats_file="$BUNDLE_ROOT/test/test_gate_config_presets.bats"

  echo "   校验: gate-config 预设名同步 (SKILL.md PRESET_MAP ↔ bats resolve_gate_config)"
  echo "     skill:  $skill_file"
  echo "     bats:   $bats_file"

  if [ ! -f "$skill_file" ] || [ ! -f "$bats_file" ]; then
    echo "   ⚠️  WARNING: 文件缺失，跳过 gate-config 同步校验"
    echo ""
    return
  fi

  # 提取 SKILL.md PRESET_MAP 段预设名集合
  # 段标记：「预设名映射表（PRESET_MAP）」→「数字映射：」；每行格式 `# <name> → {...}`
  # grep 必须含 → 约束：只认 `# name →` 格式，忽略段内英文注释（防误报）；行有前导空格故
  # 允许 ^[[:space:]]*#（L-014：避免 \] 字符类陷阱，用 [a-z0-9-] + [[:space:]] POSIX 类）
  # R3-19 收敛：grep 在空集合（如 SKILL.md 被清空）时 rc=1，set -e 下会中止脚本。
  # 故 `|| true` 兜底 rc，空集合合法得到空串，交由后续 fail-closed 分支判定。
  local skill_presets
  skill_presets=$(sed -n '/预设名映射表（PRESET_MAP）/,/数字映射：/p' "$skill_file" \
    | grep -E '^[[:space:]]*#[[:space:]]*[a-z][a-z0-9-]*[[:space:]]+→' \
    | sed -E 's/^[[:space:]]*#[[:space:]]*([a-z0-9-]+).*/\1/' \
    | sort -u || true)

  # 提取 bats resolve_gate_config 的 case 分支预设名集合
  # 分支格式：`    full)` 或 `    code-only|review)`（| 分隔别名）
  # R3-19 收敛：同上，grep 空集合 rc=1 ⇒ `|| true` 兜底（bats 文件被清空时走到这里）。
  local bats_presets
  bats_presets=$(sed -n '/^  case "$value" in/,/^  esac/p' "$bats_file" \
    | grep -E '^    [a-z]' \
    | sed -E 's/^[[:space:]]+//; s/\).*//' \
    | tr '|' '\n' \
    | sed 's/^[[:space:]]*//' \
    | sort -u || true)

  # 语义 set-diff（集合不等即漂移）
  # R3-20 收敛：gate-config 的 diff 同样保留 rc，rc≥2 = 机械故障 ⇒ 具名 🔴 + ERRORS。
  # 同上：set -e 下 diff rc=1 会触发中止，故 set +e … set -e 包裹（bash 3.2 兼容）。
  local diff_out diff_rc
  set +e
  diff_out=$(diff <(printf '%s\n' "$skill_presets") <(printf '%s\n' "$bats_presets") 2>/dev/null); diff_rc=$?
  set -e
  if [ "$diff_rc" -ge 2 ]; then
    echo "   🔴 MECHANICAL: gate-config diff 返回 rc=$diff_rc（机械故障，非内容判定）"
    ERRORS=$((ERRORS + 1))
    echo ""
    return
  fi

  if [ -n "$diff_out" ]; then
    echo "   🔴 DRIFT: gate-config 预设名集合不一致！"
    echo "$diff_out" | sed 's/^/     /'
    ERRORS=$((ERRORS + 1))
  else
    # R3-19 收敛：两侧预设集合同时为空时，`grep -c .` 在 set -e 下 rc=1 ⇒ 静默中止。
    # 修法：`|| true` 兜底 rc，并断言空集合 ⇒ fail-closed（未验证 ≠ 通过）。
    # 任一侧预设集合为空 ⇒ 具名 🔴 + ERRORS，不得静默继续、不得打印 ✅ 一致。
    local preset_count
    preset_count=$(printf '%s\n' "$skill_presets" | grep -c . || true)
    local bats_count
    bats_count=$(printf '%s\n' "$bats_presets" | grep -c . || true)
    if [ "$preset_count" -eq 0 ] || [ "$bats_count" -eq 0 ]; then
      echo "   🔴 预设集合为空（skill 侧 ${preset_count} 个 / bats 侧 ${bats_count} 个）：无法判定一致性（未验证 ≠ 通过）"
      ERRORS=$((ERRORS + 1))
    else
      echo "   ✅ 预设名集合一致 ($preset_count 个预设)"
    fi
  fi
  echo ""
}

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
