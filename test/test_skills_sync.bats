#!/usr/bin/env bats
# test_skills_sync.bats — check-skills-sync.sh（C13/AC-11 · T12b）
# 校验 skill 薄壳 ↔ prompt 权威载体同步：①覆盖（SKILL.md + 权威载体 + @see 配对，
# 阈值 100%）②不复制（D7 归一化行集 comm=0）③@see 锚可解析（路径存在 + § 小节
# 标题命中权威载体）。
# T12b 迁移注记：原 test_check_gate_sync.bats 的 PCSC 内容比对腿（R3-18A/18B
# 单侧具名、R5-10 ③ 同行数改内容、F6 缺一对 skill）语义由本文件 ②不复制/①覆盖
# 判据承接 —— T12a 薄壳化后 skill = frontmatter + 薄壳声明 + @see，不再是 prompt
# 副本，「逐行 diff 一致」判据失效，改为「归一化公共行必须为 0」。
# 沙箱范式沿 test_check_gate_sync.bats T03 FXC1：mktemp -d 唯一夹具复制生产件，
# 篡改只落夹具副本（tracked 文件零接触）；每腿断言 $status（不只 grep 报文）。
# bats set -e 纪律：期望非零的直跑命令用 rc=0; cmd || rc=$? 捕获，不用 ! 前缀。

SCRIPT="flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
SKILL_REL="flow-kit-bundle/skills/flow-test/SKILL.md"   # 受辖薄壳对样本（简单形 @see :8）

setup() {
  # 回归安全网（同 t02 范式）：本文件所有篡改只落沙箱副本，不应直写 tracked
  # SKILL.md；若未来某腿退化直写，teardown 仍能还原（mktemp 唯一路径防并发互踩）。
  TSY_BAK=$(mktemp "${TMPDIR:-/tmp}/tsy-skill-bak.XXXXXX")
  cp "$SKILL_REL" "$TSY_BAK"
}

teardown() {
  if [[ -f "$TSY_BAK" ]]; then
    mv -f "$TSY_BAK" "$SKILL_REL"
  fi
}

# FXS 沙箱：check-skills-sync 需要受辖对全景（skills 全树 + flow-kit 全树——
# prompts/GO.md/reference/@see 目标/templates 都在读取面），整树复制进 mktemp -d。
FXS() {
  SBX=$(mktemp -d "${TMPDIR:-/tmp}/tsy-XXXXXX")
  mkdir -p "$SBX/fk/flow-kit-bundle/flow-kit" "$SBX/fk/flow-kit-bundle/skills"
  cp -r flow-kit-bundle/flow-kit/. "$SBX/fk/flow-kit-bundle/flow-kit/"
  cp -r flow-kit-bundle/skills/. "$SBX/fk/flow-kit-bundle/skills/"
  echo "[fixture] $SBX/fk (pid $$)"
}

@test "T12b: check-skills-sync.sh 存在且可执行" {
  run test -x "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "T12b 基线: 真实树 → rc=0 + 覆盖 15/15 + 不复制 comm=0 + @see 全可解析" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"覆盖度: 15/15（阈值 100%；白名单映射 1 · 清单外豁免 1 · 未登记 0）"* ]]
  [[ "$output" == *"不复制: 14/14 对 comm=0（豁免 1 对: flow-dev）"* ]]
  [[ "$output" == *"@see 锚: 19/19 锚行可解析"* ]]
  [[ "$output" == *"✅ skill 薄壳 ↔ prompt 权威载体同步校验通过"* ]]
}

@test "T12b 沙箱基线: 完整夹具 → rc=0（判据有牙，非恒红）" {
  FXS
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅"* ]]
  [[ "$output" != *"🔴"* ]]
  rm -rf "$SBX"
}

@test "T12b ①覆盖反向: 删受辖 skill（flow-test/SKILL.md）→ rc≠0 + 🔴 MISSING 具名" {
  FXS
  rm -f "$SBX/fk/$SKILL_REL"
  [ ! -f "$SBX/fk/$SKILL_REL" ]
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 MISSING"* ]]
  [[ "$output" == *"skills/flow-test/SKILL.md"* ]]      # 具名路径（不得泛化「文件缺失」）
  [[ "$output" != *"覆盖度: 15/15"* ]]                  # 覆盖不足 15/15（AC-11：覆盖不足必红）
  rm -rf "$SBX"
}

@test "T12b ②不复制反向: SKILL.md 抄入 prompt 正文行 → rc≠0 + 🔴 DUP 具名" {
  FXS
  # 从权威载体 5-test.md 抄一行标题正文进 skill 薄壳（非空行/非 ---/非 ``` 栅栏，
  # 必然通过 D7 归一化进入行集）⇒ 归一化公共行 > 0 必须判红
  stolen=$(grep -m1 '^## ' "$SBX/fk/flow-kit-bundle/flow-kit/prompts/5-test.md")
  [ -n "$stolen" ]
  printf '\n%s\n' "$stolen" >> "$SBX/fk/$SKILL_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 DUP"* ]]
  [[ "$output" == *"flow-test"* ]]                      # 具名对（不张冠李戴）
  rm -rf "$SBX"
}

@test "T12b ②不复制反向: 同行数改内容不短路（R5-10 ③ 迁移承接腿）" {
  FXS
  # PCSC 迁移承接：旧「仅改一行内容（行数不变）必须判红」的判别形态在本门禁的
  # 等价形态 = 薄壳正文行被替换为 prompt 正文行（行数不变，内容撞车）
  local f="$SBX/fk/$SKILL_REL"
  local nlines
  nlines=$(wc -l < "$f")
  stolen=$(grep -m1 '^## ' "$SBX/fk/flow-kit-bundle/flow-kit/prompts/5-test.md")
  [ -n "$stolen" ]
  sed "\$s/.*/$stolen/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  [ "$(wc -l < "$f")" -eq "$nlines" ]                   # 前提：行数未变
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 DUP"* ]]
  rm -rf "$SBX"
}

@test "T12b ③@see 反向: @see 指向不存在文件 → rc≠0 + 🔴 SEE 具名（行号）" {
  FXS
  # AC-11 反向腿 1：锚行指向不存在目标 ⇒ 必红（fail-closed，不得静默放行）
  sed -i 's|flow-kit/prompts/5-test.md|flow-kit/prompts/5-test-ghost.md|' "$SBX/fk/$SKILL_REL"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 SEE"* ]]
  [[ "$output" == *"skills/flow-test/SKILL.md:"* ]]     # 具名文件+行号
  [[ "$output" == *"5-test-ghost.md"* ]]                # 具名幽灵目标
  rm -rf "$SBX"
}

@test "T12b ③@see 反向: § 小节指向不存在标题 → rc≠0 + 🔴 SEE（任务块原文腿）" {
  FXS
  # AC-11 反向腿 2（任务块 verify 原文「改 @see 指向不存在小节必红」）：
  # flow-dev :377 小节形锚 §「4. 提交前 self-review」→ 幽灵小节
  sed -i 's|§「4. 提交前 self-review」|§「9. 幽灵小节不存在」|' "$SBX/fk/flow-kit-bundle/skills/flow-dev/SKILL.md"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 SEE"* ]]
  [[ "$output" == *"幽灵小节不存在"* ]]                  # 具名幽灵小节
  [[ "$output" != *"@see 锚: 19/19 锚行可解析"* ]]
  rm -rf "$SBX"
}

@test "T12b 豁免面: 未登记 flow-* 目录（flow-foo）→ rc≠0 + 🔴 UNREGISTERED（白名单外不得静默）" {
  FXS
  # 白名单三席（flow-go→GO.md / flow-kit-install / skills-flow）为封闭清单：
  # 新出现的 flow-* skill 若未登记进 GOVERNED_PAIRS/白名单 ⇒ 必须红（防裸奔）
  mkdir -p "$SBX/fk/flow-kit-bundle/skills/flow-foo"
  printf -- '---\nname: flow-foo\ndescription: unregistered probe\n---\n\n薄壳\n' > "$SBX/fk/flow-kit-bundle/skills/flow-foo/SKILL.md"
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 UNREGISTERED"* ]]
  [[ "$output" == *"flow-foo"* ]]
  rm -rf "$SBX"
}

@test "T12b ①覆盖反向: 删权威载体 prompt 小节必红的实现面（prompt 文件缺失 → MISSING 具名）" {
  FXS
  # AC-11「删 prompt 小节必红」在实现层的可达形态之一：权威载体整个缺失 ⇒ ①覆盖
  # 判据转红（小节级删改由 ③@see § 锚命中承接——小节没了 ⇒ 标题 grep 落空 ⇒ SEE 红）
  rm -f "$SBX/fk/flow-kit-bundle/flow-kit/prompts/5-test.md"
  [ ! -f "$SBX/fk/flow-kit-bundle/flow-kit/prompts/5-test.md" ]
  run bash -c "cd '$SBX/fk' && bash flow-kit-bundle/flow-kit/reference/check-skills-sync.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"🔴 MISSING"* ]]
  [[ "$output" == *"flow-kit/prompts/5-test.md"* ]]
  rm -rf "$SBX"
}
