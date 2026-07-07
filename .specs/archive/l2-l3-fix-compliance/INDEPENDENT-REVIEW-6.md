# 独立审查 · 阶段 6

## L2 盲审

**审查日期**: 2026-07-07
**审查阶段**: 6 (REVIEW)
**审查工件**: git diff（未提交变更, 14 个已修改文件 + 2 个未跟踪新文件）
**参考工件**: `.specs/l2-l3-fix-compliance/REVIEW.md`, `.specs/l2-l3-fix-compliance/REQUIREMENT.md`, `.specs/l2-l3-fix-compliance/DESIGN.md`, `.specs/l2-l3-fix-compliance/TASK.md`

---

### 审查概要

- 变更范围：14 个已修改文件（462 行新增, 24 行删除）+ 2 个未跟踪新文件（fix-compliance.sh 301 行 + test_l2_l3_fix_compliance.bats 447 行）
- 核心实现：`fix-compliance.sh`（实效性校验 lib）+ `independent-review-gate.sh`（插入点）+ 4 个 prompt 文件（修代码优先协议）+ 测试
- .done 标记：不存在（`INDEPENDENT-REVIEW-6.md` 和 `.independent-review-6.done` 均未生成）
- AC 覆盖：7 条 AC 中 5 条有代码对应（AC-1/AC-3/AC-5 通过, AC-2/AC-2b 有功能缺陷, AC-2a 有边界遗漏）

---

### 发现列表

#### 🔴 R1 · AC-2b 50% 阈值计算使用整数除法导致误阻断（假阳性）

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/fix-compliance.sh:160`
```bash
local threshold=$(( total / 2 ))
if [ "$missing" -ge "$threshold" ] && [ "$total" -gt 1 ]; then
```
当 `total` 为奇数时, `total / 2` 向下取整, 导致实际通过率低于 50% 时也被阻断。

**Source（源头）**：Bash 整数运算 `/` 是 floor division, 不是浮点除法。REQUIREMENT AC-2b 要求 "≥50% 的'已修复'声明未通过文件级校验 → gate 阻断", 即 percentage >= 50%。当前实现对于 odd total 会提前触发阻断。

**Consequence（后果）**：
| total | missing | 实际百分比 | threshold | 当前结果 | 正确结果 |
|-------|---------|-----------|-----------|---------|---------|
| 3 | 1 | 33% | 1 | **阻断(错误)** | 放行 |
| 5 | 2 | 40% | 2 | **阻断(错误)** | 放行 |
| 7 | 3 | 43% | 3 | **阻断(错误)** | 放行 |

在真实场景中, 若 agent 声明修复 3 个文件, 其中 1 个路径写错导致 MISSING (33% < 50%), hook 会错误阻断 transition, 造成假阳性——这是 fail-closed 策略外的无意义阻断。

**Remedy（修补）**：
```bash
# 替换第 160-161 行的阈值计算
# Before:
local threshold=$(( total / 2 ))
if [ "$missing" -ge "$threshold" ] && [ "$total" -gt 1 ]; then

# After:
if [ $(( missing * 2 )) -ge "$total" ] && [ "$total" -gt 0 ]; then
```
同时需要移除 `total > 1` 的豁免（见 R2）, 改为 `total > 0`。

---

#### 🔴 R2 · 单条 "Fixed in:" 声明 MISSING 时不阻断（假阴性）

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/fix-compliance.sh:161`
```bash
if [ "$missing" -ge "$threshold" ] && [ "$total" -gt 1 ]; then
```
`total > 1` 守卫使得单条声明完全豁免阻断。但 1 条声明 MISSING = 100% 未通过 ≥ 50%。

**Source（源头）**：代码中的 `total > 1` 守卫在测试文件中被注释为 "仅 1 条 MISSING, 未达 50%", 但数学上 1/1 = 100% 远超过 50% 阈值。这是对百分比计算的误判。

**Consequence（后果）**：agent 可以声明 1 个 "Fixed in:" 指向不存在的文件, 绕过整个逐发现文件校验（AC-2b）。虽然 `fk_check_doc_only_diff`（AC-2 纯文档检测）仍会拦截纯文档 diff, 但若 agent 在 diff 中包含了其他源码文件修改, 单条虚假的 "Fixed in:" 声明可以骗过 AC-2b。

**Remedy（修补）**：将守卫改为 `total > 0`（与 R1 修复合并）：
```bash
if [ $(( missing * 2 )) -ge "$total" ] && [ "$total" -gt 0 ]; then
```
同时更新对应测试（`test_l2_l3_fix_compliance.bats:166-180`）：单条 MISSING 应 block (status=1), 而不是放行 (status=0)。

---

#### 🟡 R3 · fk_verify_finding_files 使用固定字符串精确匹配文件路径, 对路径变体脆弱

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/fix-compliance.sh:146`
```bash
if echo "$diff_files" | _grep -qF "$f" 2>/dev/null; then
```
`-F`（fixed string）匹配要求 `Fixed in:` 声明的路径与 `git diff --name-only` 输出完全一致。

**Source（源头）**：DESIGN §3.2 规定 "Fixed in: <relative/path/to/file>" 使用项目根相对路径, `git diff --name-only` 也应输出项目根相对路径。但没有路径规范化步骤（如去除 `./` 前缀、处理尾部 `/`、统一大小写）。

**Consequence（后果）**：以下场景会导致匹配失败（假 MISSING）：
- agent 写 `Fixed in: ./hooks/stop/lib/fix-compliance.sh`（带 `./` 前缀）
- agent 写 `Fixed in: hooks/stop/lib/fix-compliance.sh `（尾部空格）
- git diff 输出路径与 agent 声明路径大小写不一致（macOS 不区分大小写但 git 保留大小写）

**Remedy（修补）**：在匹配前对两边路径做规范化：
```bash
# 在 fk_verify_finding_files() 中, 匹配前清理路径
local normalized_f
normalized_f=$(echo "$f" | sed 's|^\./||; s|/$||')
# 然后在 diff_files 中也做同样规范化后再匹配
```
或者最低限度：在 grep 匹配前对 `$f` 做 `sed 's|^\./||'` 处理。

---

#### 🟡 R4 · REVIEW.md 对 fix-compliance.sh 和 test 文件的计数不准确

**Symptom（症状）**：REVIEW.md 变更摘要声明：
- `fix-compliance.sh` 298 行 → 实际 301 行 (误差 1%)
- `test_l2_l3_fix_compliance.bats` 268 行 → 实际 447 行 (误差 67%)
- 测试数 "25/25 new bats pass" → 实际文件含 24 个 @test 用例

**Source（源头）**：主 agent 在写 REVIEW.md 时可能使用的行数和测试数来自早期版本或缓存, 未基于最终文件内容更新。

**Consequence（后果）**：REVIEW.md 的数字失真削弱了其作为审查工件的可信度。未来的维护者可能基于错误的行数判断文件规模和复杂度。

**Remedy（修补）**：
1. 更新 REVIEW.md 变更摘要中的行数统计（301 / 447）
2. 更新测试数声明为 "24/24 tests" 或重新计数
3. 考虑在 PCSC 中追加一项 "review 产物统计数字与 diff 一致" 检查

---

#### 🟢 R5 · fk_fix_compliance_check 中 AC-2a Symptom 分类对混合文档引用场景存在盲区

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/fix-compliance.sh:205-217`
AC-2a 分类逻辑：
1. 从 `**Symptom` 行提取源码文件路径（扩展名白名单）→ 有则 source_findings=1
2. 从整个 review 文件搜索 .md/.json/.yaml 引用 → 有则 any_file_ref 非空
3. 若两者都为空 → 默认 source_findings=1（规则 3）

**Source（源头）**：AC-2a 规则 3 说 "若无法从 Symptom 字段解析出文件路径 → 默认判定为源码级"。但实现中, 步骤 2 在**整个文件**中搜索文档引用, 而非限定 Symptom 字段。若 review 文件任意位置提及 .md 文件（例如 Source 字段引用 REQUIREMENT.md）, 就阻止了默认源码级的触发。

**Consequence（后果）**：一个 review 发现可能 Symptom 描述代码逻辑问题（未指名文件路径）, 但 Source 字段引用了某 .md 文件——当前实现会将此发现分类为 "文档级", 跳过实效性校验。这是一种假阴性——代码问题被漏检。

**Remedy（修补）**：将步骤 2 的文档引用搜索也限定到 Symptom 字段内容（与步骤 1 一致）：
```bash
# 改为只从 Symptom 行搜索文档引用
local doc_ref_in_symptom
doc_ref_in_symptom=$(echo "$symptom_raw" | _grep -oP '...(\.md|\.json|\.yaml|\.yml)...' | head -1)
if [ -z "$symptom_lines" ] && [ -z "$doc_ref_in_symptom" ]; then
  source_findings=1
fi
```

---

#### 🟢 R6 · _grep 包装函数的 -P 标志依赖 GNU grep, 非 GNU 环境会静默失败

**Symptom（症状）**：`flow-kit-bundle/hooks/stop/lib/fix-compliance.sh:20`
```bash
_grep() { command grep "$@"; }
```
包装函数路径 `command grep`, 在 macOS (BSD grep) 上 `-P`（Perl regex）标志不可用, 会导致所有 `_grep -oP` 调用静默失败。

**Source（源头）**：fix-compliance.sh 多处使用 `_grep -oP`（Perl 兼容正则）提取路径和匹配模式（行 126, 146, 205, 213）。这些是 GNU grep 特有功能。

**Consequence（后果）**：在 macOS 或 BSD 环境下, 所有正则提取返回空结果, 导致 fk_fix_compliance_check 误判为 "无源码发现" 而放行——fail-open 而非 fail-closed。考虑到 flow-kit 主要运行在 Linux/CI 环境且 Claude Code 的 shell 环境默认有 GNU grep, 实际影响有限。

**Remedy（修补）**：
1. 最低限度：在文件头注释中注明 GNU grep 依赖
2. 可选：在 `_fk_get_source_exts` 或初始化处检查 `grep -P` 可用性, 不可用时输出告警

---

#### 🟢 R7 · prompt 文件修代码优先协议段存在 3 份近似重复（~15 行/份）

**Symptom（症状）**：`5-test.md`, `6-review.md`, `7-integration.md` 三个 prompt 文件的 "修代码优先协议" 段结构高度相似（协议步骤 1-5 + PCSC 追加项）, 各自仅 2-3 行阶段特异说明不同。

**Source（源头）**：DESIGN D5 明确选择了 "在各 prompt 中直接写不用统一格式", 承认 "四份文件内容有重复（~15 行/份）, 但总量小（60 行）, 不算显著技术债"。

**Consequence（后果）**：若修代码优先协议的步骤或格式需要调整, 需同步修改 3 个 prompt 文件, 遗漏风险存在。但总量确实小（~45 行业务逻辑 + ~15 行阶段特异说明）。

**Remedy（修补）**：当前暂不修复（DESIGN D5 已记录）。建议在后续 change 中将协议核心提取为 `prompts/independent/_fix-code-first-protocol.md` 引用片段, 各阶段 prompt 用 `@see` 引用 + 追加阶段特异说明。

---

### 修代码优先协议检查

| 发现 | 分类 | 代码变更 |
|------|------|---------|
| R1 | 🟡 Major (源码级) | 需修改 `fix-compliance.sh` 第 160-161 行 |
| R2 | 🟡 Major (源码级) | 需修改 `fix-compliance.sh` 第 161 行 + 测试文件 |
| R3 | 🟡 Major (源码级) | 需修改 `fix-compliance.sh` 第 146 行附近 |
| R4 | 🟢 Minor (文档级) | 需修改 `REVIEW.md` 统计数字 |
| R5 | 🟢 Minor (源码级) | 需修改 `fix-compliance.sh` 第 211-217 行 |
| R6 | 🟢 Minor (文档级) | 需在 `fix-compliance.sh` 文件头追加注释 |
| R7 | 🟢 Minor (文档级) | 技术债, 无需本次修复 |

---

### 主 agent REVIEW.md 审查

主 agent 的 REVIEW.md 存在以下漏判/误判：

1. **AC-2 合规声明（误判）**：REVIEW.md 声称 AC-2 "纯文档 diff 检测+阻断" 合规（✅）, 但 AC-2b 的 50% 阈值实现有功能缺陷（R1 + R2）, AC-2 整体不可视为完全合规。

2. **AC-2b 合规声明（误判）**：REVIEW.md 声称 "≥50% MISSING→阻断"（✅）, 但实现中存在两处偏差：整数除法的假阳性（R1）和单条豁免的假阴性（R2）。

3. **代码质量评估（漏判）**：REVIEW.md 将 R4 偶然复杂评为 🟢 低, 声称 "检测逻辑直接映射 AC 需求"。R1/R2 的功能缺陷表明直接映射中存在实现错误, 复杂度评估应更审慎。

4. **统计数字（误判）**：行数统计和测试数统计与实际不符（R4）。

5. **测试覆盖（漏判）**：测试文件未覆盖 odd-total 阈值场景（如 3 条声明 1 条 MISSING）, 也未覆盖单条声明 MISSING 的阻断场景。这些是边界值测试缺口。

---

### 代码质量 6 维评估

| 维度 | 评估 | 说明 |
|------|------|------|
| R1 认知过载 | 🟢 低 | 函数职责清晰, 命名规范。fk_fix_compliance_check 行数略多（~125 行）但逻辑线性, 可读性好 |
| R2 变更传播 | 🟢 低 | fix-compliance.sh 为独立 lib, 通过 source 调用; prompt 修改限于各阶段文件自身 |
| R3 知识重复 | 🟡 中 | 修代码优先协议在 3 个 prompt 文件中重复 ~45 行; "Fixed in:" 格式在多处引用但未中心化定义 |
| R4 偶然复杂 | 🟡 中 | AC-2a Symptom 分类逻辑（行 204-218）包含多步 fallback + regex, 边界条件处理有遗漏（R5）。`fk_fix_compliance_check` 的 ①/②/②b/③ 步骤编排有冗余（② 和 ②b 可合并） |
| R5 依赖混乱 | 🟢 低 | 单向调用链：independent-review-gate.sh → fix-compliance.sh → git/jq。lib 路径 `${HOOK_BASE_DIR}/../stop/lib/` 的 `..` 相对路径略脆弱但可接受 |
| R6 领域扭曲 | 🟢 低 | 实效性校验是 gate-integrity 框架的自然扩展（存在性→真实性→实效性）, 抽象层一致 |

---

### Verdict: fail

**理由**：AC-2b 的 50% 阈值计算存在两处功能缺陷（R1 假阳性 + R2 假阴性）, 影响核心检测逻辑的正确性。R1 会在 odd-total 场景下错误阻断合法 transition; R2 允许单条虚假声明绕过文件级校验。这两个问题必须在进入 phase 7 前修复。

修复 R1+R2 后 → **pass**（R3-R7 为 Minor 级, 可登记为技术债不在本次阻塞）。

---


---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 15:36）

> 自动生成于 2026-07-07 15:36。由 l3-review.sh 写入。

### 审查结论

```json
## 独立审查报告（盲审）

### Spec 合规审查

基于工件中的代码、prompt、hook 和测试文件，逐条检查 REVIEW.md 声明的 AC 覆盖情况：

| AC | 要求 | 实现依据 | 合规 |
|---|---|---|---|
| AC‑1 | 4 prompt 文件含修代码优先协议 | `5-test.md`、`6-review.md`、`7-integration.md`、`L2-blind-review.md` 均包含 `Fixed in:` 分类标记协议 | ✅ |
| AC‑2 | 纯文档 diff 检测 + 阻断 | `fix-compliance.sh` 中 `fk_check_doc_only_diff()` 检测 git diff 文件分类，无源码变更时返回阻断（exit 2）；hook 调用 `fk_fix_compliance_check` 后 `exit 2` | ⚠️ 见 critical |
| AC‑2a | 源码级发现三级判定规则 | 仅体现在 prompt 层（分类标记），`fix-compliance.sh` 中未发现显式的“Symptom 路径提取→分类”逻辑（`fk_fix_compliance_check` 未完整可见，但可见片段无此实现） | ❌ 未覆盖（major） |
| AC‑2b | 逐发现文件修改校验 | `fk_verify_finding_files()` 解析 `Fixed in:` 声明，检查是否在 diff 中，≥50% MISSING 阻断 | ✅ |
| AC‑3 | 双层共存（实效性在真实性之后） | hook 中调用顺序：`fk_validate_done_marker` 之后调用 `fk_fix_compliance_check` | ✅ |
| AC‑4 | 技术债滥用防护（≥50% 阈值 + 显式说明） | 仅在 prompt 层（5-test、6-review）中定义，hook 层无校验；符合 AC 描述（prompt 层规则） | ✅ |
| AC‑5 | 仅 5/6/7 触发 | `fk_fix_compliance_check` 中分支 `case 5|6|7` 执行，其他 `return 0` | ✅ |

**AC‑2 覆盖不完整**：实效性校验代码仅出现在 L3 完成后的重试分支（`independent-review-gate.sh` 两处 `if fk_validate_done_marker` 成功后的内部），对于 `gate_config="L2"`（仅 L2 审查）模式，过渡时不会进入该分支，因此实效性校验完全跳过。这导致 L2‑only 模式下纯文档 diff 可以通过 gate，违反 AC‑2 的“阻断”要求。

**AC‑2a 缺失**：`fix-compliance.sh` 中未实现“Symptom 路径提取→分类；无路径→默认源码级”的代码逻辑，仅靠 prompt 层指导。虽不直接阻断，但降低了自动化验证的可靠性。

---

### 代码质量（6 维衰退风险）

| 维度 | 评估 | 说明 |
|---|---|---|
| R1 认知过载 | 🟢 低 | 函数职责单一（classify / check / verify / orchestrate），命名清晰 |
| R2 变更传播 | 🟡 中 | `independent-review-gate.sh` 中两段实效性校验代码**完全重复**（~15 行两处），未来修改需同步两处，增加遗漏风险 |
| R3 知识重复 | 🟡 中 | 4 prompt 文件中修代码优先协议段落重复（每份 ~15 行），且与 `L2-blind-review.md` 部分重叠；`fix-compliance.sh` 部分注释与函数实现重复 |
| R4 偶然复杂 | 🟢 低 | 检测逻辑直接映射 AC 需求，无过度设计 |
| R5 依赖混乱 | 🟢 低 | 单向依赖：`fix-compliance.sh` → `independent-review-gate.sh` → transition，无循环 |
| R6 领域扭曲 | 🟢 低 | 实效性校验是 gate‑integrity 框架的自然扩展（存在性→真实性→实效性），不破坏现有抽象 |

**额外问题**：
- 新增文件 `test_checkpoint.bats` 与本次 `l2-l3-fix-compliance` 变更无关（内容为 checkpoint‑lib 单元测试），可能是误包含或工件不完整。该文件增加了维护负担（R3 知识重复 + 偶然复杂）。
- `fix-compliance.sh` 文件内容被截断（NEW FILE 显示不完整），无法全面评估完整函数实现和边界情况。

---

### Critical 问题

| 文件 | 问题 | 原因 | 修复建议 |
|---|---|---|---|
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | 实效性校验仅在 L3 完成后执行，**L2‑only 模式完全跳过** | 两段实效性校验代码均嵌入 `if fk_validate_done_marker` 成功后的内部（L3 重试分支），L2‑only 过渡时不会进入该块 | 将实效性校验提升到 L3 相关分支之外，放在 `.done` 校验通过后、`exit 0` 之前，且对 `gate_config` 所有值（L2/both/L3）均执行 |

---

### 审查结论

**Verdict: fail**

存在 **1 个 critical**（AC‑2 未覆盖 L2‑only 模式）和 **1 个 major**（AC‑2a 未实现代码级分类逻辑）。Spec 合规存在缺口，且代码中两处重复的实效性校验块（~15 行×2）增加了未来维护风险。建议修复 critical 后重新审查。
```
