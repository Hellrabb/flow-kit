#!/usr/bin/env bats
# test_gate_config_carriers.bats — gate_config 五载体集合比对（T17 · C14-b/AC-12-b）
# ============================================================================
# 被测件: flow-kit-bundle/flow-kit/reference/check-gate-sync.sh 的五载体对账段
# check_gate_config_carriers（T17 追加；T07 键值对面字节不动，由
# test_check_gate_sync.bats 另辖）。五载体与权威全集（health-fix-2026-09c DESIGN）：
#   ① flow-kit-bundle/skills/flow/SKILL.md PRESET_MAP（经 T07 提取器读名集）
#   ② flow-kit-bundle/test/test_gate_config_presets.bats mock case 块（同一提取器）
#   ③ dsh-flow-kit/lib/flow-state.js PRESET_MAP —— **权威真源**（17 键，文本解析读
#      生产 JS：D1 哲学，读文本而非 source，ADR-030 豁免同 T07）
#   ④ flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh fk_check_gate_config_tamper
#      内联值域（jq select 与 case 双处）：须自一致且 ⊇ bash 侧预设使用值
#   ⑤ FLOW-KIT-用户指南.md 预设名表 —— **只读对账无写权**：别名折算后须 ⊇ ③键集
#      且无未知预设名（不要求严格相等；折算表 GC5_GUIDE_ALIAS_FOLD 内置于
#      check-gate-sync.sh 并由本文件折算机制腿钉住）
# 判据形态:
#   正向 = 真实树/沙箱五载体齐备 → rc=0 + 五载体健康行（非恒红）；
#   边界 = 非仓内上下文（无 ../dsh-flow-kit）→ 显式跳过 rc=0（安装态语义，
#          ①②键值对主判据仍辖；仓内运行打印健康行由真实树腿钉住防退化真空）；
#   反向 = 逐载体增/删预设名（或值域篡改）→ rc≠0 具名 🔴（AC-12-b 反向控制）。
# 沙箱范式沿 test_check_gate_sync.bats T03 FXC1（mktemp -d 唯一路径 + 整套复制
# 生产件；篡改只落夹具副本，tracked 文件零接触）。setup/teardown 另备份四
# tracked 载体作回归安全网（沿 t02/tsy 房风：若未来某腿退化为直写 tracked 文件，
# teardown 还原——本 wave 内四载体零同文件冲突，无互踩面）。
# bats set -e 纪律：期望非零一律 run + $status 判定（不裸跑期望失败的命令）；
# 除 grep 报文断言外必断 $status，防「只看报文不看 rc」的假绿。
# ============================================================================

SCRIPT="flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
SKILL_REL="flow-kit-bundle/skills/flow/SKILL.md"
BATS_REL="flow-kit-bundle/test/test_gate_config_presets.bats"
JS_REL="dsh-flow-kit/lib/flow-state.js"
HELPERS_REL="flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh"
GUIDE_REL="FLOW-KIT-用户指南.md"

setup() {
  # 回归安全网：备份四 tracked 载体（篡改本应只落沙箱副本；若未来腿退化直写，
  # teardown 无条件还原——沿 test_check_gate_sync.bats t02 房风）
  CARR_BAK=$(mktemp -d "${TMPDIR:-/tmp}/t17-bak-XXXXXX")
  cp "$SKILL_REL" "$CARR_BAK/SKILL.md"
  cp "$JS_REL" "$CARR_BAK/flow-state.js"
  cp "$HELPERS_REL" "$CARR_BAK/gate-helpers.sh"
  cp "$GUIDE_REL" "$CARR_BAK/guide.md"
  SBX=""
}

teardown() {
  if [[ -n "$SBX" && -d "$SBX" ]]; then
    rm -rf "$SBX"
  fi
  if [[ -d "$CARR_BAK" ]]; then
    mv -f "$CARR_BAK/SKILL.md" "$SKILL_REL"
    mv -f "$CARR_BAK/flow-state.js" "$JS_REL"
    mv -f "$CARR_BAK/gate-helpers.sh" "$HELPERS_REL"
    mv -f "$CARR_BAK/guide.md" "$GUIDE_REL"
    rm -rf "$CARR_BAK"
  fi
}

# FXC5 沙箱：五载体对账需仓形上下文（bundle 载体 ①②④ + 仓级载体 ③⑤），
# 整套复制进 mktemp -d 唯一路径。gate-helpers.sh 仅被文本解析（ADR-030），
# 不 source，故其 source 依赖（gate-helpers-types.sh）无需入夹具。
FXC5() {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/t17c-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit/reference" \
           "$SBX/fk/flow-kit-bundle/skills" \
           "$SBX/fk/flow-kit-bundle/test" \
           "$SBX/fk/flow-kit-bundle/hooks/pre-tool-use" \
           "$SBX/fk/dsh-flow-kit/lib"
  cp "$SCRIPT" "$SBX/fk/flow-kit-bundle/flow-kit/reference/"
  cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/"
  cp "$BATS_REL" "$SBX/fk/flow-kit-bundle/test/"
  cp "$HELPERS_REL" "$SBX/fk/flow-kit-bundle/hooks/pre-tool-use/"
  cp "$JS_REL" "$SBX/fk/dsh-flow-kit/lib/"
  cp "$GUIDE_REL" "$SBX/fk/"
}

@test "T17 前置: check-gate-sync.sh 存在且可执行" {
  run test -x "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "T17 基线: 真实树（仓内上下文）→ rc=0 + 五载体健康行 + T07 健康行语义保留" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"五载体预设名集合一致"* ]]        # 新判据面健康行
  [[ "$output" == *"③js 17=权威"* ]]                # 权威键集计数钉住（PRESET_MAP 17 键）
  [[ "$output" == *"预设名集合一致 (17 个预设)"* ]]  # T07 面健康行原样保留（字节不动）
  [[ "$output" == *"校验面 2/2"* ]]                  # 仓内上下文：两判据面都已运行
  [[ "$output" != *"🔴"* ]]
}

@test "T17 沙箱基线: 五载体齐备夹具 → rc=0 + 健康行（判据有牙，非恒红）" {
  FXC5
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"五载体预设名集合一致"* ]]
  [[ "$output" != *"🔴"* ]]
}

@test "T17 边界: 非仓内上下文（无 ③flow-state.js）→ 五载体段显式跳过 + rc=0" {
  # 安装态语义钉住：缺仓级载体 ⇒ 跳过必须**显式**（⏭️ 行 + 覆盖度 1/1），
  # 不得静默真空；①②键值对主判据仍辖（校验对 1/1 一致）。仓内检测面由
  # 真实树腿钉住——跳过不得成为仓内运行的逃逸口。
  FXC5
  rm -rf "$SBX/fk/dsh-flow-kit"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"五载体段跳过"* ]]
  [[ "$output" == *"校验面 1/1"* ]]
  [[ "$output" == *"✅ 校验对 1/1 一致"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]       # 跳过态不得打印健康行
}

@test "T17 缺件: 仓内上下文但 ④gate-helpers.sh 缺失 → 🔴 CARRIER-MISSING 具名转红" {
  # fail-closed：仓内时缺载体 ≠ 跳过（跳过门只认③缺席=非仓内；④缺失是仓内缺件）
  FXC5
  rm "$SBX/fk/flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-MISSING"* ]]
  [[ "$output" == *"④gate-helpers"* ]]
  [[ "$output" != *"✅ 校验对"*"一致"* ]]
}

@test "T17 解析: 载体③段锚点漂移 → 🔴 CARRIER-PARSE fail-closed（未验证 ≠ 通过）" {
  FXC5
  sed -i 's|^const PRESET_MAP = {|const PRESET_MAP_T17 = {|' "$SBX/fk/$JS_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-PARSE"* ]]
  [[ "$output" == *"③js rc=2"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ①反向: SKILL.md 增预设名 → rc≠0 + 双面具名转红（含 fake 名）" {
  FXC5
  sed -i '/# review[[:space:]]*→/a\     # t17-fake-skill         → {"6-review":"both"}' "$SBX/fk/$SKILL_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴"* ]]
  [[ "$output" == *"t17-fake-skill"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ②反向: bats mock 增预设分支 → rc≠0 + 双面具名转红（含 fake 名）" {
  FXC5
  sed -i "/^    code-only|review)\$/a\\    t17-fake-bats)\n      echo '{\"6-review\":\"both\"}'\n      ;;" "$SBX/fk/$BATS_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴"* ]]
  [[ "$output" == *"t17-fake-bats"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ③反向增: flow-state.js PRESET_MAP 增键 → 仅五载体面红（T07 面仍绿）" {
  # 关键独立性腿：①②未动 ⇒ T07 键值对面绿（17 个预设健康行仍在）；
  # ③权威键集漂移只有新判据面能看见——这正是 T17 存在的理由（AC-12-b）。
  FXC5
  sed -i 's|^  "code-only": { "6-review": "both" },|&\n  "t17-fake-js": { "6-review": "both" },|' "$SBX/fk/$JS_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-DRIFT"* ]]
  [[ "$output" == *"t17-fake-js"* ]]
  [[ "$output" == *"预设名集合一致 (17 个预设)"* ]]   # T07 面不受此篡改影响
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ③反向删: flow-state.js PRESET_MAP 删键 → 仅五载体面红" {
  FXC5
  sed -i '/^  "spec-test": /d' "$SBX/fk/$JS_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-DRIFT"* ]]
  [[ "$output" == *"spec-test"* ]]
  [[ "$output" == *"预设名集合一致 (17 个预设)"* ]]   # T07 面不受此篡改影响
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ④反向a: gate-helpers 值域内部不一致（jq/case 双处）→ rc≠0 具名" {
  FXC5
  sed -i 's|or .value == "both" or|or .value == "both-t17" or|' "$SBX/fk/$HELPERS_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-DRIFT: ④gate-helpers 双处内联值域不一致"* ]]
  [[ "$output" == *"both-t17"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ④反向b: 值域未覆盖 bash 侧使用值 → rc≠0 具名" {
  FXC5
  sed -i -e 's|or .value == "both" or|or|' \
         -e 's#^      independent|true|both|L2|L3) ;;#      independent|true|L2|L3) ;;#' "$SBX/fk/$HELPERS_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-DRIFT: ④gate-helpers 值域未覆盖 bash 侧使用值"* ]]
  [[ "$output" == *"both"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ⑤反向删: 用户指南删预设行 → 折算后未覆盖 → rc≠0（指南无写权，只报不代修）" {
  FXC5
  sed -i '/^| `spec-test` |/d' "$SBX/fk/$GUIDE_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-DRIFT: ⑤用户指南"* ]]
  [[ "$output" == *"未覆盖"* ]]
  [[ "$output" == *"spec-test"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 ⑤反向增: 用户指南增未知预设行 → 折算后含未知预设名 → rc≠0" {
  FXC5
  sed -i '/^| `spec-test` |/a\| `t17-fake-guide` | 6-review | +1k |' "$SBX/fk/$GUIDE_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 CARRIER-DRIFT: ⑤用户指南"* ]]
  [[ "$output" == *"未知预设名"* ]]
  [[ "$output" == *"t17-fake-guide"* ]]
  [[ "$output" != *"五载体预设名集合一致"* ]]
}

@test "T17 折算机制: GC5_GUIDE_ALIAS_FOLD 内置 + _gc5_guide_fold_name identity 兜底（source 模式）" {
  # 折算表内置于 check-gate-sync 并随测试钉住：当前登记 0 条改写级别名
  # （指南唯一复合形「`code-only` / `review`（别名）」两名均真键，机械拆分处理），
  # 未登记呈现名 ⇒ 原样折算 ⇒ 不在③键集 ⇒ 未知预设名转红（上腿已钉）。
  run bash -c 'source flow-kit-bundle/flow-kit/reference/check-gate-sync.sh && printf "fold=%s varlen=%s\n" "$(_gc5_guide_fold_name code-only)" "${#GC5_GUIDE_ALIAS_FOLD}"'
  [ "$status" -eq 0 ]
  [[ "$output" == "fold=code-only varlen=0"* ]]
}
