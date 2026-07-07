
---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 10:28）

> 自动生成于 2026-07-07 10:28。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [
    {
      "file": "（整个工件）",
      "issue": "缺少 hook 层实现脚本（如 29-independent-review.sh、l3-review.sh、auto-checkpoint 的 PreToolUse/Stop hook 逻辑），导致 spec 中定义的 L2-first gating（L3 等待 L2 写 .done）、auto-checkpoint 兜底、append-write 语义的 hook 层防护均无代码覆盖。",
      "why": "spec 要求三层防护（prompt + hook），但工件仅修改了文档和 prompt 模板，未包含任何 hook 脚本变更。pipeline 运行时将缺乏实际保障机制，关键功能不可执行。",
      "fix": "补充实现对应 hook 脚本，并在 diff 中包含这些变更；确保 transition 前置 gate 检查、auto-checkpoint 自动写入等逻辑真正可运行。"
    }
  ],
  "major": [],
  "minor": [
    {
      "file": "FLOW-KIT-用户指南.md",
      "issue": "auto-checkpoint 触发条件表中“阶段切换”的 active_file 列为 `.flow-active`，但其他场景（如编辑文件）使用具体路径，此处描述不一致，可能引起混淆。",
      "why": "active_file 应为实际路径或在阶段切换时为空串，`.flow-active` 作为路径名不准确。",
      "fix": "将阶段切换的 active_file 调整为空串或明确说明记录为 `.flow-active` 路径。"
    }
  ],
  "verdict": "fail",
  "summary": "工件因缺少 hook 层核心实现，导致 spec 要求的 auto-checkpoint 兜底、L2-first gating、append-write 保护等功能无法在运行时生效，存在关键实现缺失。"
}
```

---

## L2 盲审

> 独立审查。未经主 agent 预览或修改。审查日期：2026-07-07。

### 🔴 R1 · 缺失调用方集成：l3_review_run gate_config_value 参数未传递，L3-only 模式 .done 永不写入（AC-7 失效）

**Symptom（症状）**：`l3-review.sh:41` 定义了 `local gate_config_value="${5:-both}"` 以接收第 5 个参数。但所有 3 个调用方均未传递此参数：
- `29-independent-review.sh:117` — `l3_review_run "$phase" "$change_id" "$spec_dir" "$l2_verdict"`（仅 4 个参数，`$gate_val` 在第 89 行已解析但未传递）
- `independent-review-gate.sh:228` — `l3_review_with_timeout "$phase" "$change_id" "$spec_dir" "$l2v" 30`（仅 5 个参数给 wrapper，wrapper 在 `l3-review.sh:291` 调用 `l3_review_run "$1" "$2" "$3" "$4"` 仅 4 个参数）
- `l3-review.sh:291`（l3_review_with_timeout 内）— 仅传递 4 个位置参数给 l3_review_run

结果：`gate_config_value` 始终默认 `"both"`。D3 门控（`l3-review.sh:227-233`）在 gate_config="L3"（仅 L3 模式）时错误触发延迟——L2 段不存在 → `return 0` → `.done` 永不写入。

**Source（源头）**：`.specs/dual-review-merge-fix/REQUIREMENT.md` AC-7 要求 gate_config="L3" 时 L3 正常运行并写入 `.done`（L2_verdict=skipped）。`.specs/dual-review-merge-fix/TASK.md` T02 描述了第 5 个参数但未规定调用方更新。`.specs/dual-review-merge-fix/DESIGN.md` D3 指定了 gate_config_value 参数，但数据流图未标注 29-hook 需要传递该值。

**Consequence（后果）**：L3-only 模式在两种执行路径下均彻底失效。Stop hook 29 虽然设置了 `l2_verdict="skipped"`（正确），但 `l3_review_run` 由于默认 gate_config_value="both" 触发 D3 延迟，导致 `.done` 永不写入。用户因缺少 `.done` 标记而无法通过 PreToolUse transition 切阶段，形成永久阻塞。这是一个可复现的功能破坏性缺陷，影响所有使用 L3-only 模式的用户。此处在主 agent 的 REVIEW.md 中未被检测到——**主 agent 漏判：REVIEW.md AC-7 行判定为"已覆盖"，但调用方未传递 gate_config_value 导致实际执行路径无法满足 AC-7**。

**Remedy（修补）**：三个调用点均需传递 gate_config_value：

1. `29-independent-review.sh:117`（`$gate_val` 在第 89 行已可用）：
```bash
# Before:
l3_review_run "$phase" "$change_id" "$spec_dir" "$l2_verdict"
# After:
l3_review_run "$phase" "$change_id" "$spec_dir" "$l2_verdict" "$gate_val"
```

2. `l3-review.sh:291`（l3_review_with_timeout 内）需新增第 6 个参数 gate_config_value 并向下传递：
```bash
# Before:
l3_review_with_timeout() {
  local phase="$1" ...; local timeout_secs="${5:-30}"
  ...
  l3_review_run "$1" "$2" "$3" "$4"
# After:
l3_review_with_timeout() {
  local phase="$1" ...; local timeout_secs="${5:-30}"; local gate_cfg="${6:-both}"
  ...
  l3_review_run "$1" "$2" "$3" "$4" "$gate_cfg"
```

3. `independent-review-gate.sh:228`（`$gate_val` 在第 204 行已可用）：
```bash
# Before:
l3_review_with_timeout "$phase" "$change_id" "$spec_dir" "$l2v" 30
# After:
l3_review_with_timeout "$phase" "$change_id" "$spec_dir" "$l2v" 30 "$gate_val"
```

---

### 🟡 R2 · PreToolUse forward 分支 L3-only 路径永远跳过 L3 前置（既有缺陷，本次未修复）

**Symptom（症状）**：`independent-review-gate.sh:215` 的 L3 前置调用由以下条件门控：`if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" ...`。该检查不区分 gate_val 模式——即使 gate_config="L3"（仅 L3 模式），若 L2 段不存在则跳过 L3 前置。

**Source（源头）**：`.specs/dual-review-merge-fix/REQUIREMENT.md` AC-7 规定 L3-only 模式的 PreToolUse 路径应调用 `l3_review_run()`。DESIGN.md 的 L3-only 数据流图仅显示 Stop hook 路径，未覆盖 PreToolUse 场景。

**Consequence（后果）**：L3-only 模式下通过 PreToolUse 的 L3 前置永远被跳过；用户完全依赖 Stop hook 29 执行 L3（目前也因 R1 而失效）。与 R1 组合后，L3-only 模式在两个路径下均无法写入 `.done`。

**Remedy（修补）**：`independent-review-gate.sh:215` 的条件应区分模式：
```bash
# Before:
if [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; then
# After:
if [[ "$gate_val" == "L3" ]] || { [ -f "$review_md" ] && grep -q "^## L2 盲审" "$review_md" 2>/dev/null; }; then
```
并在 `gate_val == "L3"` 时设置 `l2v="skipped"` 而非从文件提取。

---

### 🟡 R3 · l2_verdict 提取逻辑在文件含两端时可能误取 L3 结论（R1 认知过载）

**Symptom（症状）**：`29-independent-review.sh:100` 的提取逻辑为：
```bash
l2v_extracted=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" | tail -1 | grep -ioE 'pass|fail' | tail -1)
```
该 grep 对整个文件全文扫描。L3 段的 JSON 中 `"verdict":"pass"` 或 `"verdict":"fail"` 同样匹配此模式。使用 `tail -1` 会偏向选取文件末尾匹配项（即 L3 段 verdict）。

**Source（源头）**：正则表达式被设计为从 L2 段的 `**Verdict**: pass|fail` 格式提取，但 L3 JSON 中的 `"verdict":"fail"` 也匹配同一模式。两者间无锚点区分，导致歧义匹配。

**Consequence（后果）**：正常流程下（L2 先写入，29-hook 在 L3 之前运行），文件仅有 L2 段，提取正确。但在重跑/恢复场景中（文件同时存在 L2 和 L3 段），`l2_verdict` 会被错误设置为 L3 的结论（如 L3 说 fail 但 L2 实际说 pass）。`.done` 文件中的 `L2_verdict` 值将不正确。此问题在**主 agent 的 REVIEW.md 中未被检测到**（REVIEW.md 中声称"l2v_extracted 逻辑无误"，但未考虑文件含两端时 `tail -1` 的行为）。

**Remedy（修补）**：将 grep 范围限制在 L2 段内：
```bash
# Before:
l2v_extracted=$(grep -iE 'verdict[^a-z]*[:：]' "$review_md" | tail -1 | ...)
# After:
l2v_extracted=$(sed -n '/^## L2 盲审/,/^## L3 盲审/p' "$review_md" | grep -iE 'verdict[^a-z]*[:：]' | tail -1 | ...)
```

---

### 🟡 R4 · D3 延迟使用 return 0 重载"pass"返回值，调用方记录误导性日志（R6 领域扭曲）

**Symptom（症状）**：`l3-review.sh:231` 中 D3 门控触发延迟时执行 `return 0`。`l3_review_run` 的契约文档（`l3-review.sh:21`）规定返回值含义为：`0=pass, 1=fail, 2=timeout, 3=API error`。延迟并非审查通过，但返回 0 使调用方 `29-independent-review.sh:120` 落入 `case $rc in 0)` 分支，输出 `"verdict=pass"`——此日志具有误导性。

**Source（源头）**：返回值语义被过载。`return 0` 同时表示"审查通过（verdict=pass）"和"审查延迟（.done postponed）"两种完全不同的语义。《Code Complete》第 7 章："函数返回码应单一、明确地区分所有可能结果"。

**Consequence（后果）**：日志与系统实际状态不一致——操作者看到"L3 独立 review 完成... verdict=pass"以为审查通过，实际仅表示延迟。在故障排查场景中增加误导风险。**主 agent 的 REVIEW.md 已识别此问题（Q2）但标记为 🟢 Minor**；本审查独立评估为 🟡 Major，原因有三：(1) 违反了 l3-review.sh 自身函数文档声明的契约；(2) 误导性日志在故障排查时有实际危害；(3) 设计文档 D3 未明确 return 0 的"延迟"语义是刻意设计还是疏忽。

**Remedy（修补）**：引入专用返回值或使用不同返回值区分延迟：
```bash
# Option A: 用 return 4 表示"延迟"（不冲突于 0-3 现有语义）
return 4  # deferred, .done not written
```
同时在 `29-independent-review.sh:119-123` 的 case 语句中新增 `4)` 分支：
```bash
case $rc in
  4) module_output "info" "IR" "L3 content appended, .done deferred (L2 pending, gate_config=both)" ;;
  ...
```

---

### 🟡 R5 · phase_name 映射三段重复（R3 知识重复 + R2 变更传播）

**Symptom（症状）**：同一 phase_name case 映射出现在三个不同文件中，全部独立维护：
- `29-independent-review.sh:81-88`
- `independent-review-gate.sh:194-201`
- `done-validation.sh`（经 bat 测试 `test_dual_review_merge.bats:240-246` 确认存在）

**Source（源头）**：《程序员修炼之道》DRY 原则——"每一个知识点在系统中应当有单一、明确、权威的表述"。若需新增 phase 8，3 处均需手动同步更新。

**Consequence（后果）**：未来新增阶段时高度可能遗漏一处，导致该阶段在某个执行路径下静默失效。**主 agent 的 REVIEW.md Q1 将其标记为 🟢 Minor 且仅识别了 2 处重复（漏了 done-validation.sh）**。本审查独立评估为 🟡 Major：跨 hook 层 + gate 层 + validation 层的三段重复构成经典 Shotgun Surgery 风险。

**Remedy（修补）**：提取至共享 lib（如 `hooks/stop/lib/common.sh`）作为单一函数：
```bash
# 新增到 common.sh
fk_phase_name() {
  local phase="$1"
  case "$phase" in
    1) echo "1-requirement" ;;  2) echo "2-design" ;;
    3) echo "3-task" ;;         5) echo "5-test" ;;
    6) echo "6-review" ;;       7) echo "7-integration" ;;
    *) echo "" ;;
  esac
}
```
但 v1 可推迟——参见 DESIGN.md §6 不在范围："本 change 无新增可复用抽象"。此项可列入 v2 技术债。

---

### 🟢 R6 · l3-review.sh:228 重复声明 local review_md（冗余）

**Symptom（症状）**：`l3-review.sh:228` 在 D3 门控检查代码块内重新声明了 `local review_md`，但该变量已在 `l3-review.sh:175` 声明为同函数的 local 变量。两个赋值表达式相同，因此无功能影响。

**Source（源头）**：Clean Code 第 3 章：变量声明应靠近首次使用处，但不应重复声明。此处暗示 D3 段可能是复制粘贴的产物。

**Consequence（后果）**：无功能影响。但如果未来有人修改其中一个赋值表达式而未同步另一个，可能导致不一致。

**Remedy（修补）**：删除 `l3-review.sh:228` 的重复声明，直接使用 line 175 已声明的 `$review_md`：
```bash
# Before (line 227-229):
if [[ "$gate_config_value" == "both" ]]; then
    local review_md="${artifacts_dir}/INDEPENDENT-REVIEW-${phase}.md"
# After:
if [[ "$gate_config_value" == "both" ]]; then
    # review_md already declared at line 175
```

---

### 主 agent REVIEW.md 差异对照

以下为主 agent 的 `.specs/dual-review-merge-fix/REVIEW.md` 与本独立审查的差异分析（独立结论，非抄录）：

| 主 agent 判定 | 本审查判定 | 差异说明 |
|---|---|---|
| AC-7 ✅ 已覆盖 | 🔴 未实际覆盖 | 主 agent 漏判：调用方未传递 gate_config_value，D3 默认"both"导致 L3-only 模式 .done 永不写入 |
| Q2 🟢 Minor：return 0 语义 | 🟡 Major R4：函数契约破坏 + 误导日志 | 主 agent 低估严重度。独立结论：违反函数文档自身声明的契约，且影响故障排查 |
| Q1 🟢 Minor：2 处 gate_val 重复 | 🟡 Major R5：3 处知识重复 | 主 agent 遗漏 done-validation.sh 的映射，低估了重复范围和 Shotgun Surgery 风险 |
| 无提及 | 🟡 R2：PreToolUse L3-only 路径被跳过 | 主 agent 漏判：既有设计缺陷未在本次修复 |
| 无提及 | 🟡 R3：grep verdict `tail -1` 可能取 L3 结论 | 主 agent 漏判：边界条件下提取错误 |
| 无提及 | 🟢 R6：重复 local 声明 | 次要发现，不影响判定 |

---

**Verdict**: fail
