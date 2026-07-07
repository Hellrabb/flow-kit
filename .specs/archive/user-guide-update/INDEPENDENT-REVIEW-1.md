
---

## L2 盲审（独立审查员 · 2026-07-06）

输入工件：`.specs/user-guide-update/REQUIREMENT.md`、`.specs/user-guide-update/CHANGE.md`。未收到主 agent 自评/草稿/概述/辩护——独立性确认完好。

---

### 🔴 R1 · Spec 文档矛盾：CONTEXT.md 更新范围在 CHANGE.md 与 REQUIREMENT.md 之间冲突
**Symptom（症状）**：CHANGE.md:35 明确写 "不更新 CONTEXT.md 术语表（文档更新由本次 change 覆盖，CONTEXT.md 由后续 evolve 处理）"，但 REQUIREMENT.md:79 将 "CONTEXT.md 术语追加（auto-checkpoint 相关新术语）" 列入 v1 必做范围。
**Source（源头）**：两个文档同为本次 change 的权威来源。CHANGE.md 底部声明 "后续 AC 与设计细节进入 REQUIREMENT.md / DESIGN.md，本文件不再扩展"——按此规则 REQUIREMENT.md 应继承 CHANGE.md 的范围决策，但它却添加了 CHANGE.md 明确排除的工作项。这违反单一事实来源原则（Single Source of Truth），实施者无法判断是否应该更新 CONTEXT.md。
**Consequence（后果）**：实施阶段出现二义性——实现者可能更新 CONTEXT.md（遵循 REQUIREMENT.md）或不更新（遵循 CHANGE.md），导致交付物与某一方预期不符。不修则 spec 合规性存疑，后续 evolve 阶段可能因误解而重复工作或遗漏工作。
**Remedy（修补）**：两文档择一统一。推荐对齐 CHANGE.md（不更新 CONTEXT.md），因为 CHANGE.md 已给出明确理由（"由后续 evolve 处理"），且 CONTEXT.md 更新不涉及任何 AC 的通过条件。修改 REQUIREMENT.md:79 从 v1 移除该条目，或将其降至 v2。

---

### 🔴 R2 · AC-5 验证依赖 LLM 非确定性输出，不可机器复现
**Symptom（症状）**：AC-5 的 Then 要求 "GO.md 路由声明中显式展示中断上下文…并注入到对应阶段 prompt 的恢复段"，但验证方式仅依赖 "检查 AI 回复中是否引用了 interrupt 字段内容"（REQUIREMENT.md:59）。LLM 回复受模型版本、温度、上下文窗口等因素影响，同一个 prompt 在不同时刻可能产生不同输出——今天通过明天可能失败。
**Source（源头）**：验收准则要求 "Given/When/Then 必须可验证"（REQUIREMENT.md:16）。但 AI 回复不是确定性产物，对 AI 输出的检查不构成可重复的测试。这违反测试可靠性的基本原则——测试必须对相同输入产生相同判定。
**Consequence（后果）**：AC-5 永远无法被自动化测试可靠验证。回归测试中可能出现假阴性（AI 引用正确但测试判定失败）或假阳性（AI 碰巧提到字段但实际注入逻辑有 bug）。在快速迭代中，该 AC 将被逐步忽视，中断恢复功能的回归保护形同虚设。
**Remedy（修补）**：将验证点前置到确定性产物：
```
验证方式: 模拟中断后执行 /flow-go 继续，检查以下确定性产物：
  1. GO.md 文件内容: grep -q 'active_file\|last_action\|checkpoint_at' GO.md
  2. 对应阶段 prompt 文件（如 phase-N-prompt.md）: 确认恢复段包含 interrupt 字段引用
  3. 排除对 AI 回复内容的依赖——AI 回复仅作人工辅助确认，不作为通过/失败判据
```

---

### 🟡 R3 · AC-1 Given/When/Then 逻辑不一致：Given 打开"任意一份"，Then 要求"每份"
**Symptom（症状）**：AC-1 Given 写 "用户打开 FLOW-KIT-用户指南.md、README.md、flow-kit-ecosystem-guide.md 任意一份"，但 Then 写 "每份文档中均能找到对应章节，内容一致（无矛盾）"（REQUIREMENT.md:20-22）。从 "打开任意一份" 的场景出发，无法验证 "每份文档" 和 "内容一致"——后者需要分别打开三份。
**Source（源头）**：BDD Given/When/Then 规范要求 Given 建立验证 Then 所需的全部前置条件。当前 Given 建立的前置条件不足以支撑 Then 的验证范围。
**Consequence（后果）**：测试用例设计时出现混乱——执行者可能只测一份文档就标记通过（按 Given 理解），也可能被迫测三份（按 Then 理解）。实施者可能误以为只需更新一份文档即可满足 AC。
**Remedy（修补）**：将 Given 改为 "用户分别打开 FLOW-KIT-用户指南.md、README.md、flow-kit-ecosystem-guide.md 三份文档"，或拆分为 3 个子 AC 各对应一份文档：
```
AC-1a · 用户指南覆盖全部功能 (Given 打开 FLOW-KIT-用户指南.md …)
AC-1b · README 覆盖全部功能 (Given 打开 README.md …)
AC-1c · ecosystem-guide 覆盖全部功能 (Given 打开 flow-kit-ecosystem-guide.md …)
```

---

### 🟡 R4 · 非功能性需求遗漏：auto-checkpoint 写入失败的容错策略未定义
**Symptom（症状）**：非功能性需求段（REQUIREMENT.md:97-101）对可靠性/可用性/容错全部标记为 "无" 或一笔带过。具体缺失：
- `.flow-active` 写入时磁盘满或权限不足时的行为
- jq 命令执行失败时的 fallback（如 JSON 格式损坏后的处理）
- 并发写入 `.flow-active` 的冲突策略（如两个进程同时触发 checkpoint）
- checkpoint 数据完整性校验（写入后是否验证 JSON 合法）
**Source（源头）**：checkpoint 是中断恢复机制的核心——恢复机制的可靠性不应低于其所保护的操作。若 auto-checkpoint 静默失败，用户将误以为有恢复上下文可用，实则无。这违反防御性设计原则（Defensive Design）：容错路径必须有显式的失败模式定义。
**Consequence（后果）**：生产环境中遇到磁盘满、权限变更、并发场景时，auto-checkpoint 可能静默失败，`.flow-active` 中的 interrupt 字段保持旧值或变为无效 JSON。用户会话中断后依赖一个过时/损坏的 checkpoint 恢复，丢失进度。恢复机制自身不可靠比没有恢复机制更危险（虚假安全感）。
**Remedy（修补）**：在非功能性需求中追加可靠性条目：
```
- **可靠性**: auto-checkpoint 写入失败时 MUST 保留旧 checkpoint 值不变（原子更新语义）；
  写入后 MUST 校验 JSON 合法性；若校验失败则回滚到写入前状态
- **并发**: 同一 .flow-active 的并发写入使用 flock 或 mv-atomic 策略，以最后写入者为准
- **可观测性**: 写入失败时 SHOULD 输出 stderr 警告（用户可见），而非静默丢弃
```
或至少在 CHANGE.md 风险段补充 "auto-checkpoint 写入失败时静默丢弃，用户需手动 `/flow checkpoint` 兜底" 并建立对应的 AC。

---

### 🟡 R5 · AC-3 字段级验证标准不精确：未枚举更新字段及格式约束
**Symptom（症状）**：AC-3 Then 写 "interrupt 字段被自动更新，包含当前操作的文件路径和描述，且 updated_at 刷新"（REQUIREMENT.md:45）。但未指定：
- 文件路径是绝对路径还是相对路径？
- "描述" 的格式/长度限制是什么？
- `updated_at` 的时区和精度（ISO8601? Unix timestamp?）
- `active_file`、`last_action`、`checkpoint_at` 三个字段之间的关系——全部必填还是至少一个？
**Source（源头）**：AC 要求 "必须可验证"（REQUIREMENT.md:16）。但验证需要知道 "正确值" 长什么样——不定义字段格式，验证者无法判断一个值是对是错。若格式在 DESIGN 阶段才定义，则 AC-3 当前不可独立验证。
**Consequence（后果）**：测试阶段出现 "路径对不上" 争执——实现者用相对路径、测试者预期绝对路径，无人有错但测试挂起。DESIGN 阶段可能做出与测试预期不一致的格式选择，导致 AC-3 事后被解释性修改。
**Remedy（修补）**：在 REQUIREMENT.md 的 "依赖与假设" 段追加格式约定，或 AC-3 末尾加溯源引用：
```
- active_file: 相对于项目根目录的相对路径（如 "src/main.sh"）
- last_action: 不超过 200 字符的自然语言描述
- checkpoint_at: ISO8601 UTC 时间戳（如 "2026-07-06T15:30:00Z"）
- updated_at: 与 checkpoint_at 相同格式，更新为 checkpoint 写入时刻
```
若格式细节留到 DESIGN，则 AC-3 末尾标注 "（字段具体格式见 DESIGN.md 数据模型定义）" 以建立溯源链。

---

### 🟢 R6 · AC-1 验证命令误导：grep 仅覆盖 3 个模式词，与功能清单严重不匹配
**Symptom（症状）**：AC-1 验证方式给出 `grep -c "L2\|L3\|both"` 作为可机器执行的检查（REQUIREMENT.md:23），但 When 子句列出了 11 项功能（gate_config 开关、preset/shorthand、pipeline goal 0→7、toll-gate、auto_advance+fallback、独立审查四层架构、.done 真实性校验+三种威胁模型、gate_config 快照同步、L3 front-loading、transition 方向检测、31-auto-advance/32-fallback-guard hook），该 grep 仅覆盖 "L2/L3/both" 这一项。
**Source（源头）**：给定的 grep 示例制造了 "自动化验证已完成" 的假象——执行者看到 grep 返回非零即认为验证通过，但实际只验证了 1/11 的功能覆盖。
**Consequence（后果）**：自动化检查提供虚假安全感——CI 中该 grep 通过但文档可能遗漏 10/11 的功能。功能遗漏在后续阶段（TEST 或用户反馈）才被发现，修复成本放大。
**Remedy（修补）**：移除该不完整的 grep 示例，仅保留 "人工逐项对照功能清单确认"，或提供覆盖全部功能的检查脚本。例如：
```bash
patterns=("gate_config" "preset" "pipeline.*goal" "toll-gate" "门禁" 
  "auto_advance" "fallback" "独立审查" "四层架构" "\.done.*校验"
  "威胁模型" "快照同步" "front-loading" "transition.*方向"
  "31-auto-advance" "32-fallback-guard")
for p in "${patterns[@]}"; do
  grep -q "$p" "$doc" || echo "MISSING: $p in $doc"
done
```

---

### 🟢 R7 · "假设"段承载了待 DESIGN 决议的开放问题，提前锁定实现策略
**Symptom（症状）**：REQUIREMENT.md:107 写 "auto-checkpoint 的 prompt 层指令会被 AI 执行（强模型假设）；hook 层兜底作为弱模型补充"。这实质是一个待解的 DESIGN 决策——prompt 层和 hook 层各自承担什么职责、hook 层是否需要新增/修改模块——但被表述为 "假设"。
**Source（源头）**：CHANGE.md:48 风险段明确指出 "auto-checkpoint 实现边界在 DESIGN 阶段需明确：是 prompt 层指令（依赖 AI 执行）还是 hook 层兜底（系统级保证）"。这是一个开放问题，不应在 REQUIREMENT 阶段作为 "假设" 固化。假设应陈述不可变更的外部依赖（如 jq 已安装），而非内部尚未决策的实现策略。
**Consequence（后果）**：DESIGN 阶段可能推翻 "hook 层兜底" 的假设（例如发现需要新增/修改 hook 模块，而 CHANGE.md 声明 "不新增 hook 模块"），导致 REQUIREMENT 和 DESIGN 之间出现新矛盾。把开放问题当假设提前锁定，限制了 DESIGN 的决策空间。
**Remedy（修补）**：将该条目从 "假设" 移至 CHANGE.md 风险段，或 REQUIREMENT.md 新增 "待 DESIGN 决议" 小节：
```
### 待 DESIGN 决议
- auto-checkpoint 实现边界：prompt 层指令 vs hook 层兜底 vs 混合策略。若需 hook 层兜底，
  需评估 CHANGE.md "不新增 hook 模块" 的范围约束是否允许修改现有 hook。
```

---

**Verdict**: fail

（存在 2 个 Critical：R1 spec 文档矛盾导致实施范围不明确，R2 AC-5 验证依赖 LLM 非确定性输出不可机器复现。）

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-06 15:18）

> 自动生成于 2026-07-06 15:18。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"FLOW-KIT-用户指南.md, README.md, flow-kit-ecosystem-guide.md","issue":"AC-1 的验证方式不完整，仅用 `grep -c \"L2\\|L3\\|both\"` 无法覆盖所列功能清单中的所有功能（如 pipeline_goal、toll-gate 等）。","why":"验收准则要求"每份文档中均能找到对应章节"，且人工逐项对照是主要验证手段，但给出的 grep 示例只检查了三个字符串，容易误导自动化测试无法全面验证，导致功能覆盖遗漏风险。","fix":"将验证方式中的 grep 命令改为能覆盖所有功能关键字（例如逐个功能生成 grep 列表），或移除该不完整的 grep 示例，仅保留"人工逐项对照功能清单确认"。同时考虑使用更全面的脚本化检查。"}],"minor":[{"file":"FLOW-KIT-用户指南.md, README.md, flow-kit-ecosystem-guide.md","issue":"AC-1 的 Given/When/Then 逻辑不一致：Given 是"用户打开任意一份"，但 Then 要求"每份文档中均能找到对应章节"。","why":"单一场景下只需验证打开的文档，但结论却要求三份文档全部满足，导致验证者必须分别对三份文档重复测试，表述不准确。","fix":"将 Given 改为"用户分别打开 FLOW-KIT-用户指南.md、README.md、flow-kit-ecosystem-guide.md"或"当用户查看这三份文档时"。或将 AC-1 拆分为三个子 AC 各自对应一份文档。"},{"file":"GO.md / 路由声明","issue":"AC-5 的验证方式"检查 AI 回复中是否引用了 interrupt 字段内容"不够直接，依赖模型行为而非底层文件状态。","why":"验收准则要求 GO.md 路由声明显示中断上下文并注入到阶段 prompt，但验证只检查 AI 回复，可能存在由于 prompt 处理差异导致的误判。","fix":"建议验证方式加入检查 GO.md 文件内容（如 `grep 'active_file' GO.md`）以及注入后阶段 prompt 中是否包含中断上下文，而不仅依赖 AI 回复。"},{"file":"FLOW-KIT-用户指南.md","issue":"AC-6 未明确测试环境要求（如 flow-kit 版本、依赖安装等），可能导致验证条件不统一。","why":""在安装了最新 flow-kit 的环境中执行对应命令"中"最新"定义模糊，不同时间点可能版本不同。","fix":"明确指定基线版本或 commit hash，或说明以当前 CHANGE.md 关联的版本为准。"},{"file":"非功能性需求","issue":"未涉及 auto-checkpoint 写入失败时的处理（如 jq 命令失败、文件锁定、磁盘空间等）。","why":"虽然性能声称 <10ms，但容错机制缺失可能影响中断恢复的可靠性，属于非功能性需求的合理遗漏。","fix":"在 v2 或后续版本考虑写入失败时的告警或 fallback 策略，当前可注明"忽略失败"或"记录错误日志"。"}],"verdict":"pass","summary":"工件整体结构清晰，用户故事和验收准则完整，v1/v2/out 切分合理。主要问题为 AC-1 的验证方式不全面，可能导致功能覆盖验证不足；另有少量表述逻辑一致性和验证直接性方面的 minor 问题。无 critical 项，判定为 pass。"}
```
