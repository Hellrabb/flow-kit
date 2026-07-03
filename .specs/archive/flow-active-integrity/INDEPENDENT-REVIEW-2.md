# 独立审查 · 阶段 2

## L2 盲审

> 审查日期：2026-07-03
> 审查工件：DESIGN.md（参考 REQUIREMENT.md、CONTEXT.md；ARCHITECTURE.md 不存在已跳过）
> 独立审查员：L2 盲审（未检测到主 agent 上下文注入）

---

### 审查范围

针对 `.specs/flow-active-integrity/DESIGN.md` 做阶段 2 设计审查，checklist：
- 每个 ADR 决策是否合理且有充分理由（不止「选了 X」，要「为什么选 X 不选 Y」）
- 是否撞既有架构 / 跨模块契约（对照 CONTEXT.md 的禁动清单与已锁决策）
- 抽象层次是否得当——深模块（接口窄、实现深）vs 浅模块（接口宽、实现浅）
- 风险段是否遗漏关键风险，或低估了概率 / 影响

---

### 发现

#### 🟡 R1 · correction_file_write 覆写冲突：33 号模块将销毁同 session 的合规违规记录

**Symptom**：DESIGN.md 第 96 行数据流 "correction-file.sh ── 写入 .flow-active.correction" + 第 151 行 "矫正文件新增 type='state-integrity'，与现有 'compliance'/'interactive-ui' 并列" 隐含同一文件共存。但 `correction_file_write()`（correction-file.sh:40-53）是原子覆写策略（write tmp → mv overwrite），不读旧文件、不合并不追加。模块 28（weak-model-compliance）使用自己的 `write_compliance_correction()`（weak-model-compliance.sh:70-112）读取旧 violations → 合并去重 → 覆写全量，先将 L1/L2/L3 违规写入 `.flow-active.correction`（type=compliance）。33 号在 hook 链的 28 号之后运行（00 → ... → 28 → ... → 32 → 33），若直接调用 `correction_file_write` 覆写同一文件，将完全销毁 28 号刚写入的 compliance 违规记录。

**Source**：单一写入者 / 合并策略原则——当多个模块共享同一持久化文件时，必须明确合并策略（read-modify-write 或分文件），否则后写入者静默覆盖先写入者，导致数据丢失。本设计声称 "并列" 共存但在设计层未给合并契约。

**Consequence**：同 session 内若同时存在合规违规（L1/L2/L3）和状态完整性违规（AC-2~6），合规违规将静默丢失。SessionStart hook（flow-kit-resume.sh）无法注入合规矫正 banner，弱模型跳过的规则违反/自检缺失/幻觉引用不被矫正。在一个同时触发两类违规的 session 中（如弱模型跳步骤导致 state drift + 同时触碰禁动文件），用户只能看到 state-integrity 矫正，看不到 compliance 矫正。破坏防御纵深。

**Remedy**：设计阶段明确合并策略，二选一：

方案 A（推荐——沿用 28 的 read-merge-write 模式）：33 号模块在写入前先读 `.flow-active.correction` 现有内容，将自己检测到的 state-integrity violations 与已有的 compliance violations 合并后覆写同一文件。需在 DESIGN.md 补充合并伪代码：

```
# 33 号写入前
existing=$(correction_file_read "$CORRECTION_FILE")
merged_violations=$(jq -n --argjson old "$existing" --argjson new "$state_violations" \
  '{violations: (($old.violations // []) + $new)}')
correction_file_write "$CORRECTION_FILE" "$merged_violations"
```

方案 B：33 号写独立的矫正文件（如 `.flow-active.state-integrity-fix`），SessionStart 同步处理两个文件。需在 DESIGN.md 更新数据流图 + SessionStart 影响面。代价是 SessionStart 需增加一个文件处理分支。

无论选哪种，DESIGN.md 的 9.3 跨模块契约应补充合并策略的具体语义。

---

#### 🟡 R2 · PHASE_ARTIFACTS 回退映射未定义——实现将面对空白契约

**Symptom**：REQUIREMENT.md 第 112 行 NFR "PHASE_ARTIFACTS 未加载（回退到内置最小映射）" 定义了可靠性要求，但 DESIGN.md 未在任何位置（数据流、决策清单、风险段）具体说明 "内置最小映射" 的内容。`PHASE_ARTIFACTS` 当前覆盖 phase 1/2/2a/3/4/5/6/7（flow-kit-artifacts.sh:47-55），若该文件未 source 成功，33 号模块需要一份硬编码的回退映射才能继续交叉验证。

**Source**：设计完备性原则——NFR 可靠性要求依赖于设计阶段明确的降级契约。未定义降级映射 = 未验证 NFR 可达性。

**Consequence**：4-dev 实现阶段将遇到未定义契约，实现者需自行猜测回退映射内容（可能选错 phase→产物对应关系，如回退映射只含 1-7 但漏了 2a）。后续若 `PHASE_ARTIFACTS` 主定义变更，回退映射可能不同步。测试无法验证 "回退行为正确" 因为不知道什么是正确。

**Remedy**：在 DESIGN.md 补充回退映射定义。建议直接引用主定义的子集（保守策略——只验证最关键的 phase）：

```
# 内置最小回退映射（当 PHASE_ARTIFACTS 未 source 时启用）
declare -A FALLBACK_PHASE_ARTIFACTS=(
  ["1"]="CHANGE.md"
  ["2"]="REQUIREMENT.md DESIGN.md"
  ["3"]="DESIGN.md TASK.md"
  ["4"]="TASK.md"
  ["5"]="TEST.md"
  ["6"]="TEST.md"
  ["7"]="REVIEW.md"
)
```

同时补充：回退映射与主 `PHASE_ARTIFACTS` 的一致性应纳入 `make check` 校验（或至少 bats 测试验证二者 key 集合一致）。

---

#### 🟡 R3 · AC-6 token_spent grep 模式设计未收敛：认了问题但没给答案

**Symptom**：AC-6 指定验证模式为 `grep 'jq.*\.flow-active'`。DESIGN.md 风险 R2（第 118 行）承认此模式会匹配读操作导致假阳性，并提议细化为 `jq '.*=' .flow-active` 或 `jq.*>.*\.flow-active` 两个候选模式——但未在 D4 决策或任何其他位置收敛到最终选定的模式。设计阶段的职责是选定方案，不应把 "A 或 B" 的未决议题抛给实现阶段。

**Source**：设计决策必须收敛——设计方案不应包含未解决的二选一。若需实验验证，应在设计阶段标注 "实现时实验确定" 并给出实验标准（假阳性率阈值、测试数据集），而非只列两个候选。

**Consequence**：实现者可能直接用 AC-6 的宽松模式（产生假阳性警告——token_spent 实际已维护但仍报警），或随意选一个细化模式（可能矫枉过正——漏检真正的未维护）。两种都导致 AC-6 的检测质量不可预测。bats 测试只能验证 "能检测" 或 "能不误报"，但不知道以哪个模式为基准。

**Remedy**：在 DESIGN.md D4 决策段补充最终选定的 grep 模式，并给出选定理由（权衡假阳性率 vs 假阴性率）。建议：

```
选定模式：grep -E 'jq[^|]*\|.*\.flow-active|jq.*>.*\.flow-active' transcript
理由：匹配管道写入（jq ... | ... .flow-active）和重定向写入（jq ... > .flow-active），
排除纯读取（jq '.phase' .flow-active 无管道/重定向后缀）。
假阳性率估计：< 5%（仅 .flow-active 很少作为管道中间环节读取）
```

---

#### 🟡 R4 · NFR 安全与兼容性要求未在设计层显式映射——依赖隐式行为

**Symptom**：REQUIREMENT.md 定义了两条 NFR 但 DESIGN.md 未显式回应：

(a) 安全（第 114 行）："矫正文件内容不暴露敏感路径（仅记录 change_id / phase，不记录绝对路径）"。但交叉验证的违规消息可能自然包含路径信息（如 "missing .specs/foo/DESIGN.md" 是相对路径，但若检测逻辑使用了 `$PROJECT_ROOT/.specs/...` 绝对路径拼接，消息将泄露文件系统布局）。设计未定义违规消息的内容契约（格式模板、禁止字段）。

(b) 兼容性（第 115 行）："向后兼容——.flow-active 缺少新增字段时跳过对应检查，不报错"。设计隐含依赖 `jq` 对缺失字段返回 `null` 的自然行为，但未显式说明哪些检查在字段缺失时应跳过（如 `token_spent` 缺失时 AC-6 应跳过还是报 "token_spent 字段不存在"？`gates` 缺失时 AC-4 pipeline 交叉验证是全跳还是只跳过 gate 子检查？）。

**Source**：NFR 可追溯性——每条 NFR 应在设计阶段有对应的实现策略。隐式依赖实现细节（jq 的行为）不等同于显式设计。

**Consequence**：(a) 若实现时违规消息使用绝对路径，矫正文件将泄露内部目录结构（与 security-privacy-audit 的安全标准冲突）；(b) 若兼容性策略未显式定义，对 `token_spent` 缺失等场景的行为将取决于实现者的临时判断，测试覆盖可能遗漏边界 case。

**Remedy**：
- (a) 在 DESIGN.md 数据流或 9.3 跨模块契约补充违规消息格式规范——明确使用相对路径（相对于 `$PROJECT_ROOT`），不拼接绝对路径。
- (b) 在 DESIGN.md 每个检测函数说明中补充 "缺失字段行为"——如 `check_token` 在 `token_spent` 字段不存在时跳过而非报错；`check_pipeline` 在 `gates` 缺失时跳过 gate 交叉验证只做 phases_done↔产物检查。这些行为应与 AC 要求对齐（AC-6 触发条件是 token_spent=0 且 transcript 含写入，字段不存在不属于此条件故应跳过）。

---

#### 🟢 R5 · 风险段 R4 事实错误：phase 2a 映射声明与代码不符

**Symptom**：DESIGN.md 风险 R4（第 120 行）声称 "phase=2a 在 PHASE_ARTIFACTS 中无直接映射"，但 `flow-kit-artifacts.sh:50` 证实 2a 有显式映射 (`["2a"]="CHANGE.md REQUIREMENT.md"`)。声明与既有代码矛盾。

**Source**：设计文档准确性——风险分析依赖的既有代码状态必须准确。错误的 "无映射" 假设会误导读者认为 2a 的交叉验证完全跳过（实则会检查 CHANGE.md + REQUIREMENT.md 的存在性）。

**Consequence**：功能影响轻微——2a 有映射比无映射更安全，交叉验证能正常执行。但文档错误可能让后续维护者误以为 2a 漏检，试图 "修复" 实则引入回归。不影响 pass/fail 判定。

**Remedy**：修正 R4 为 "phase=0 无映射（需 info 日志跳过）；phase=2a 有映射但仅含 CHANGE.md + REQUIREMENT.md，不含 DESIGN.md（因 2a 为设计前置阶段，符合预期）"。

---

#### 🟢 R6 · change_id 特殊字符未讨论——路径拼接存在注入面

**Symptom**：33 号模块的 `check_change_id` 和 `check_phase` 涉及 `test -d .specs/<change_id>/` 和 `test -f .specs/<change_id>/<artifact>` 路径拼接。若 `.flow-active.change_id` 包含空格、斜杠或 shell 元字符（如 `foo; rm -rf /`），裸拼接到路径中将导致行为不可预测（从误报/漏报到潜在的路径遍历）。DESIGN.md 未讨论 change_id 的输入校验或 sanitization 策略。

**Source**：防御性设计——任何从外部可控输入（JSON 文件内容视为外部输入）拼接为 shell 路径/命令时，必须考虑输入合法性校验。`fk_flow_field()` 仅做 jq 提取不做校验。

**Consequence**：change_id 由 AI（通过 jq 写入）和用户（手动编辑）共同控制。正常情况下 change_id 应为 slug 格式（如 `flow-active-integrity`），但不排除异常情况（AI 幻觉/用户误操作）写入含特殊字符的值。一旦发生，33 号模块的 `test -d`/`test -f` 路径拼接可能产生错误判断（如路径中的空格导致 word splitting），极端情况下可能路径遍历。概率低，但防御成本也低。

**Remedy**：在 DESIGN.md 数据流或 check_change_id 伪代码中补充 change_id 合法性校验——`change_id` 必须匹配 `^[a-zA-Z0-9][-a-zA-Z0-9_]*$`（slug 模式），不匹配则跳过该检测写 info 日志（不报警）。此校验已由 CONTEXT.md 命名约定隐含（kebab-case），显式化即可。

---

#### 🟢 R7 · 矫正文件幂等性未讨论——hook 重入时的行为未定义

**Symptom**：DESIGN.md 未讨论 Stop hook 异常重入场景下 33 号模块的幂等性。若 `correction_file_write` 以 overwrite 策略直接覆写，重入时旧违规记录被新记录替换（不会出现重复 violations），这是可接受的幂等行为。但若采用 R1 推荐的 read-merge-write 策略，重入时可能出现同一 violation 被重复追加——需合并去重。

**Source**：容错设计——NFR 要求 "不崩溃、不阻断 Stop hook 链"，但未覆盖重入场景的语义正确性（重复 violations 虽不崩溃，但影响矫正文件质量）。

**Consequence**：用户在一次 session 中看到重复的矫正条目，降低信任度。概率低（hook 重入属异常场景），影响轻微。

**Remedy**：在 DESIGN.md 实现注意事项中补充：合并策略需对 (check_type, change_id, phase) 组合去重（类似 28 号模块的 `unique_by({layer, rule, location})` 去重策略），确保重入安全。

---

### 总评

所有 6 条 AC 在设计中均有对应覆盖，6 个设计决策（D1-D6）均有替代方案对比和取舍说明，符合 "不止选 X，要为什么选 X 不选 Y" 的标准。设计未触碰 CONTEXT.md 禁动清单和已锁决策。模块抽象层次得当——33 号模块接口窄（读 .flow-active + PHASE_ARTIFACTS → 写矫正文件）而实现深（5 类交叉验证），是深模块设计。

主要设计缺口集中在跨模块集成（R1 覆写冲突）和未收敛的设计决策（R2 回退映射、R3 grep 模式）。这三个问题应在进入 3-task 阶段前在设计文档中闭环。

**Verdict**: pass

---


---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-03 21:57）

> 自动生成于 2026-07-03 21:57。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [],
  "minor": [
    {
      "file": "整体设计文档",
      "issue": "风险段未覆盖 .flow-active 文件缺失或格式错误的情况",
      "why": "33号模块依赖 .flow-active 文件存在且格式正确，若文件缺失或 JSON 解析失败，当前容错处理（set -euo pipefail + 不阻断 hook 链）可能未明确说明；此风险可能导致模块异常退出或产生未定义行为",
      "fix": "在风险段添加相应条目（概率低但影响中），并明确容错策略：例如文件不存在时直接跳过检查，解析失败时写入 correction 并继续"
    },
    {
      "file": "决策 D4",
      "issue": "token_spent 检测的 grep 模式未在决策中明确定义",
      "why": "决策描述为 'transcript grep'，但未给出具体匹配模式；风险 R2 虽提出细化建议，但决策本身缺乏精确约定，可能导致实现歧义",
      "fix": "在 D4 中直接写明 grep 模式，例如 `grep -E 'jq.*[=:].*\\.flow-active'` 或采纳 R2 的细化 `jq.*>.*\\.flow-active`"
    },
    {
      "file": "整体设计文档",
      "issue": "缺少对引用需求文件的必要摘要，审查者无法验证设计是否完全覆盖需求",
      "why": "工件关联了 `@.specs/flow-active-integrity/REQUIREMENT.md`，但未摘要关键 AC，独立审查难以判断设计决策是否满足所有要求",
      "fix": "在文档开头列出核心需求（如 AC 列表），或明确每个决策所回应的需求编号"
    }
  ],
  "verdict": "pass",
  "summary": "设计文档架构决策合理、与既有模块契约对齐良好、抽象层次得当；风险段较全面，但遗漏 .flow-active 文件缺失风险等 minor 问题，整体质量可接受。"
}
```
