# 独立审查 · 阶段 5

## L2 盲审

- 阶段：5（测试审查 · 5-test）
- change-id：gate-done-authorship
- 工件：`.specs/gate-done-authorship/TEST.md`（参考 REQUIREMENT.md / TASK.md / DESIGN.md）
- 独立性声明：未在输入中检测到主 agent 自评 / 草稿 / 概述 / 辩护；以下判断仅基于 TEST.md / REQUIREMENT.md / TASK.md / DESIGN.md 及对 test/test_gate_integrity.bats（全量 249 行 22 @test）、test/regression-demos/tampered-done/check.sh、test/regression-demos/exotic-escape/check.sh 的独立核验。已执行 npx bats test/test_gate_integrity.bats（22 ok / 0 fail）和 make test（612 ok / 0 fail）确认。

---

### 🟡 R1 · T4 L2_verdict 裁决不匹配负向测试缺失——T4 拒绝路径零覆盖

**Symptom（症状）**：TEST.md 的 D9 正向测试（合法 done + L2_verdict=pass 与 INDEPENDENT-REVIEW-6.md 的 Verdict: pass 一致 -> fk_validate_done_marker tier=transition return 0）仅覆盖 T4 正向路径。T4 负向路径（done 的 L2_verdict 与 INDEPENDENT-REVIEW-N.md 的 L2 段 verdict 不一致 -> return 2 拒绝）无对应测试用例。

独立核验：test/test_gate_integrity.bats 中 fk_validate_done_marker 仅被调用 2 处——L60（AC-1 空 done，tier=write，测 Tier 1 空文件拒绝）和 L132（D9 正向，tier=transition，测 T4 一致放行）。无 tier=transition + L2_verdict 不一致 -> return 2 的测试。gate_is_l2_only 在 bats 中 0 处直接引用。

**Source（源头）**：TASK.md T04 step 5c 明确要求新增 T4 裁决不匹配测试：构造 done 的 L2_verdict 与 INDEPENDENT-REVIEW-N.md 的 L2 段 verdict 不一致 -> fk_validate_done_marker tier=transition return 2（拒绝）。覆盖 T4 拒绝路径。Phase 3 审查 RR1（Major）已先行标记 T4（done-validation L2_verdict 比对）改写后失专属单测覆盖并要求 T04 增补。TASK.md done 声明 2 新增 T4 单元（不匹配拒绝/正向通过）——实际仅实现正向通过，不匹配拒绝未实现。

**Consequence（后果）**：
- T4 拒绝代码路径零测试覆盖。DESIGN 2.2 明确 T4 是保留的 L2-first gating 调度契约——无负向测试意味着契约仅在放行方向有验证，在拒绝方向无保障。
- 后续 change 若误删/误改 T4 比对逻辑（如 fk_extract_l2_verdict 调用或 verdict 比对断言），无人拦截。
- 与 AC-6 的 bypass-transition 场景叠加（见 R2）——T4 负向是其唯一后置防线，失测即失守。

**Remedy（修补）**：在 test_gate_integrity.bats 增补 1 个 T4 裁决不匹配测试用例：构造合法格式 done（过 Tier 1）但 L2_verdict=fail 与 INDEPENDENT-REVIEW-N.md 的 Verdict=pass 不一致，断言 fk_validate_done_marker tier=transition return 2。同步更新 TEST.md D9 分类行。

---

### 🟡 R2 · AC-6 bypass-transition 场景（done-validation Gate 4 exit 4）未测试

**Symptom（症状）**：AC-6（REQUIREMENT.md:60-64）要求两阶段验证：
- (a) PreToolUse hook 在 path-guard 拦截伪造写入（exit 2）
- (b) 若绕过写入直接 transition，done-validation Gate 4 拦截（exit 4）

TEST.md AC-6 payload 测试仅覆盖 (a)：gate_config=both -> agent Bash 写 done -> path-guard deny exit 2。(b) 场景——模拟 agent 绕过 path-guard 写入（或利用 exotic 路径如 python-c 写入 done）后直接 transition，期望 done-validation Gate 4 在 T4 层拦截——无对应测试用例。

独立核验：bats 中无 AC-6 bypass/transition/done-validation exit 4/Gate 4 拦截语义的测试。AC-6 payload 测试（L195-202）仅测 gate_path_guard return 2，不测 bypass + transition 路径。

**Source（源头）**：TASK.md T04 step 6 明确要求模拟绕过写入直接 jq transition -> done-validation Gate 4 拦截。明确 step 6 覆盖 T4 裁决不匹配路径——但实现中 step 6 的 AC-6 payload 测试仅覆盖了 path-guard 层，未覆盖 done-validation 层。此缺口与 R1（T4 裁决不匹配测试缺失）同源——R1 修复后亦覆盖此场景。

**Consequence（后果）**：AC-6 仅 50% 验证（path-guard 层）。done-validation Gate 4 的 transition 拦截能力未经集成测试验证。若 path-guard 被 exotic 路径绕过（v1 已知缺口：perl -i / python-c），T4 是唯一后置防线——此防线无测试。

**Remedy（修补）**：R1 的 T4 裁决不匹配测试（done 含 L2_verdict=fail 与 INDEPENDENT-REVIEW-N.md 的 Verdict=pass 不一致 -> transition return 2）直接覆盖此场景。R1 修复后，在 TEST.md 的 AC-6 行更新验证方式以反映双路径覆盖。

---

### 🟡 R3 · L2-only fail-open 测试缺失——D3 决策关键路径零覆盖

**Symptom（症状）**：TASK.md T04 step 9 要求 L2-only fail-open 测试（m2 落地）：模拟 flow-active 缺失 gate_config key / jq 错误 -> gate_is_l2_only 返回 0（放行，D3 fail-open）。TEST.md 中无对应测试用例。

独立核验：test/test_gate_integrity.bats 中 gate_is_l2_only 引用计数为 0（grep -c gate_is_l2_only -> 0）。AC-4 L2-only 测试（L204-210）仅覆盖正常路径（flow-active 可读、gate_config key 存在、值为 L2 -> 放行 exit 0），不覆盖 fail-open 路径（flow-active 缺失 key、jq 解析失败 -> 应放行）。

**Source（源头）**：DESIGN D3 决策 gate_config 读取失败时 fail-open 放行 + 取舍论证 both/L3 模式读取失败 -> 误放为理论不可利用缺口——该决策的 fail-open 行为未通过测试验证。TASK.md T04 step 9 已要求增补，done 计数含 1 fail-open 但未实现。

**Consequence（后果）**：gate_is_l2_only 的异常路径（jq 错误、flow_file 不存在、key 缺失）无自动化验证。若函数在异常条件下行为偏离 D3 设计（如抛 unbound variable 错误而非 fail-open），无人察觉。虽 D3 论证该路径端到端不可利用，但 fail-open 决策本身应有测试兜底。

**Remedy（修补）**：在 test_gate_integrity.bats 增补 1 个测试用例：构造 flow-active 缺少 gate_config key 的场景，断言 gate_path_guard 对 Bash 写 done 仍放行 exit 0。同步 TEST.md 在 AC-4 行补充 + fail-open（gate_config 缺失 key -> 放行）。

---

### 🟡 R4 · TEST.md 覆盖声明失实——"7/7 AC 全覆盖"与"边界测试 非法值覆盖"言过其实

**Symptom（症状）**：TEST.md 测试质量自检表声明：
- AC 覆盖 | 7/7 AC 全覆盖
- 边界测试 | 双路径 + 非法值覆盖

实际验证结果：
- **AC-6**：仅覆盖 scenario (a) path-guard exit 2，scenario (b) done-validation exit 4 未覆盖（见 R2）。
- **AC-5**：bats 测试已改写（22 ok），但 regression-demos（tampered-done/check.sh + exotic-escape/check.sh）未改写——两个 check.sh 仍依赖旧函数 is_handshake_write（已由 T01 删除），因依赖检测失败而命中 PENDING 分支 exit 0，不执行任何实际断言（见 R5）。AC-5 要求所有握手相关测试已改写为新语义——regression-demos 属于握手相关测试但未改写。
- **非法值覆盖**：fk_validate_done_marker 的 KVP 伪造（缺失 key）和值域伪造（非法 verdict 值）负向路径无独立测试用例。当前仅 empty-done（空文件 -> Tier 1 拒绝）测试了 fk_validate_done_marker 的负向行为；KVP 缺失/值域非法路径未经测试触发。

**Source（源头）**：TEST.md 自检过于乐观，未逐 AC 验证覆盖完整性。

**Consequence（后果）**：QA 自检表掩盖了 3 处覆盖缺口（AC-6 bypass、AC-5 regression-demos、Tier 1 KVP/值域负向）。若维护者仅读自检表做 go/no-go 决策，可能错误放行未充分测试的变更。

**Remedy（修补）**：
1. AC 覆盖行改为 6/7 AC 全覆盖 + AC-5 regression-demos 待 T05 执行（bats 已覆盖）或 7/7 AC 覆盖（注：AC-6 bypass 场景由 T4 裁决不匹配测试覆盖，见 R1 修补）。
2. 边界测试行改 双路径覆盖 | 非法值覆盖：Tier 1 空文件通过，KVP/值域负向待补（当前 D9 正向覆盖合法值域）。
3. 或直接删非法值覆盖改为 非法值覆盖：Tier 1 空文件拒绝通过，KVP 伪造/值域非法路径待 T4 裁决不匹配测试覆盖。

---

### 🟡 R5 · T05 regression-demos 未执行——check.sh 依赖旧函数 is_handshake_write 致恒跳 PENDING

**Symptom（症状）**：TASK.md T05 action step 1 要求 tampered-done/：改写为 done 作者性语义——check.sh 验证 agent 用 sed -i 改 done 被 path-guard 拦截（移除握手引用 written_by=stop-hook-29）、step 2 要求 exotic-escape/：保留目录但更新注释标注 v2 加密签名。

独立核验两个 check.sh：
- tampered-done/check.sh：L14 依赖检测 grep is_handshake_write，因 T01 已删除 is_handshake_write，此检测始终失败 -> 命中 PENDING 分支 exit 0，后续实际测试代码（仍含.flow-active.independent-review 握手文件创建、"握手 verdict" 注释、"29 号握手" 引用）永不执行。
- exotic-escape/check.sh：L14 同款依赖检测 is_handshake_write -> 恒 PENDING exit 0；实际测试代码（含 python3 写旧握手路径、"is_handshake_write" 调用）永不执行。
- 双源（test/regression-demos/ vs flow-kit-bundle/test/regression-demos/）md5 一致——均为旧版，非同步后的新版本。

**Source（源头）**：T05 任务未执行或执行不完整。两个 check.sh 的依赖检测仍指向 T01 已删除的 is_handshake_write，内容仍为握手时代语义。

**Consequence（后果）**：
- AC-5（REQUIREMENT.md:52-57）要求所有握手相关测试已改写为新语义或删除——regression-demos 属于既有握手测试但未改写。bats 测试（22 ok）覆盖了 AC-5 的 bats 部分，regression-demos 部分裸露。
- bash check.sh 恒 exit 0（PENDING 分支），T05 verify 若基于此调用将产生假绿。
- 打包发布包含 stale regression-demos（仍引用已删除函数/旧握手文件）。

**Remedy（修补）**：执行 T05 原定 action：
1. tampered-done/check.sh：移除 is_handshake_write 依赖检测；改写实际测试段为 done 作者性语义；移除 old-handshake-file 引用和 written_by=stop-hook-29 引用。
2. exotic-escape/check.sh：移除 is_handshake_write 依赖检测；改写依赖检测为 dotdone_write 函数；更新注释标注 v1 不挡 python-c/perl-i（已知缺口留 v2）。
3. 双源同步。

---

### 🟢 R6 · TEST.md 未与 TASK.md T04 计划测试数对照——22 vs 16 差异未解释

**Symptom（症状）**：TEST.md 报告 test_gate_integrity.bats 含 22 tests。TASK.md T04 <done> 声明 16 测试全绿（4 done-validation + 2 T4 + 6 D7 + 3 集成 + 1 fail-open）。差值 6 个测试未标注来源。

独立核验：22 = 16（T04 新/改写）+ 3（D10 phases_done 预存）+ 2（AC-3 5 站点 grep 预存）+ 1（AC-6 29 号不 dump 预存）。预存的 6 个测试未在 T04 计数中但保留在文件中——属于正确行为，但 TEST.md 未声明此区别。

**Source（源头）**：TASK.md T04 仅计数本次 change 新写/改写的测试；TEST.md 报告全文件测试总数。两处口径不一致但均未说明差异。

**Consequence（后果）**：轻微——不影响测试有效性。但读者对比 TASK.md 的 16 与 TEST.md 的 22 时可能产生困惑，降低文档可信度。

**Remedy（修补）**：TEST.md 在 test_gate_integrity.bats（22 tests 全绿）后加注含 6 个预存非本 change 测试（D10 phases_done x3 + AC-3 5 站点 x2 + AC-6 29 号 x1），本 change 新写/改写 16 个。无需增删测试。

---

### 🟢 R7 · "双源同步 diff 一致"仅覆盖 bats——regression-demos 双源均为旧版

**Symptom（症状）**：TEST.md 声明双源同步 diff 一致。独立核验：
- bats：test/test_gate_integrity.bats 与 flow-kit-bundle/test/test_gate_integrity.bats 经 diff -q 确认一致。
- regression-demos：test/regression-demos/tampered-done/check.sh 与 flow-kit-bundle/test/regression-demos/tampered-done/check.sh md5 一致，但二者均为旧版（未改写）——一致是因为两处都未更新，非同步后的新版本一致。

**Source（源头）**：TEST.md 双源同步 diff 一致未限定作用域。

**Consequence（后果）**：轻微——bats 双源实际一致。regression-demos 双源均为旧版导致表述产生误导。待 R5 修复并双源同步后此问题自动消除。

**Remedy（修补）**：TEST.md 编辑为 bats 双源同步 diff 一致（regression-demos 待 T05 执行后同步）；或 R5 修复后统一验证。

---

### 🟢 R8 · TEST.md 未引用 DESIGN.md 决策点——测试设计可追溯性弱

**Symptom（症状）**：TEST.md 关联字段仅引用 REQUIREMENT.md 和 DESIGN.md 文件名，但测试分类（AC-1 ~ AC-6 / D7 / D9 / D10）未标注各测试对应的 DESIGN 决策/数据流节点。

**Source（源头）**：TEST.md 格式简洁优先，未建立测试->DESIGN 可追溯矩阵。

**Consequence（后果）**：轻微——后续维护者难以快速判断测试是否覆盖了 DESIGN 中的所有关键路径。不影响测试有效性。

**Remedy（修补）**：建议在 TEST.md 测试分类表中增 1 列 DESIGN 引用（如 D7 -> DESIGN §2.4 T1-T3、D9 正向 -> DESIGN §2.2 Tier 2 T4）。非阻塞，可选项。

---

**Verdict**: pass

22 个 bats 测试全部通过（22 ok / 0 fail），全量回归通过（612 ok / 0 fail / exit 0）。核心安全测试（path-guard D7 写向量覆盖 6 种 + exotic v1 边界、AC-6 payload path-guard exit 2、AC-4 L2-only 正常放行）就位且通过。AC-1/AC-2/AC-3/AC-4/AC-7 已验证。

存在 5 条 🟡 Major（R1-R5）：T4 裁决不匹配负向测试缺失（T4 拒绝路径零覆盖）、AC-6 bypass-transition 场景未测试（done-validation Gate 4 未验证）、L2-only fail-open 测试缺失（gate_is_l2_only 异常路径零覆盖）、TEST.md 覆盖声明失实（7/7 AC 全覆盖与非法值覆盖言过其实）、regression-demos 未改写（T05 未执行，check.sh 恒跳 PENDING）。R1 为 Phase 3 RR1 的延续——该 gap 跨阶段未修复，T4 L2-first gating 契约的拒绝方向无自动化保障。

另有 3 条 🟢 Minor（R6-R8）：测试数口径不一致、双源同步声明作用域模糊、测试可追溯性弱。

R1 修复后同时覆盖 R2（T4 裁决不匹配 = AC-6 bypass 场景的 done-validation 层），优先级最高。R5（regression-demos）为独立任务 T05 的遗留，不阻塞主测试套质量判定。无 🔴 Critical，本轮 pass。

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-25 16:09）

> 自动生成于 2026-07-25 16:09。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "工件整体（test_gate_integrity.bats 及测试声明）",
      "issue": "AC 覆盖声明与实际测试分类不匹配",
      "why": "自检声称 7/7 AC 全覆盖，但测试分类列表仅明确涉及 AC-1、AC-3、AC-4、AC-6，缺少 AC-2 和 AC-5 的对应测试描述，无法确认是否真的覆盖所有验收条件",
      "fix": "补充 AC-2 和 AC-5 的测试用例，或修正声明使其与实际覆盖一致"
    }
  ],
  "minor": [
    {
      "file": "工件整体",
      "issue": "UAT 复现步骤缺失",
      "why": "审查要求 UAT 可复现，但工件仅提及测试结果来源（T04/T06），未提供独立复现的操作步骤或脚本路径",
      "fix": "添加可执行的 UAT 流程说明，例如引用具体 bats 文件路径和运行命令"
    }
  ],
  "verdict": "pass",
  "summary": "测试矩阵基本覆盖主要 AC，回归测试齐全，但 AC 覆盖声明存在不一致（缺少 AC-2/AC-5 明确映射），且 UAT 复现性不足；无 critical 问题，判定通过"
}
```

L3_artifact_hash: 8f27517202f4bad83dcb23ee289c91f205422cf8018d0a52e18e511d79b69ff9
