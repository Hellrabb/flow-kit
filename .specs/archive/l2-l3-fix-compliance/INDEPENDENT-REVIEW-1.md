# 独立审查 · 阶段 1

## L2 盲审

### 🔴 R1 · 源码级发现分类触发机制未定义：AC-2 门控逻辑的核心判据模糊

**Symptom（症状）**：`REQUIREMENT.md:31` AC-2 Given 条件写 "INDEPENDENT-REVIEW-<N>.md 包含 ≥1 条标记为'源码问题'的发现"，使用 "标记为" 一词，强烈暗示 review 文件中有显式 tag 字段标识每条发现是否为源码级问题。但当前 L2-blind-review.md 的 review 输出格式（四要素：Symptom/Source/Consequence/Remedy + 严重度标记）不包含 "源码问题/文档问题" 分类字段。`CONTEXT.md:160` 将 "源码级发现" 定义为 "INDEPENDENT-REVIEW-<N>.md 中指向源码文件（非 .md 文档）问题的发现条目"——即通过 Symptom 中引用的文件路径隐式推导，而非显式标记。

**Source（源头）**：独立审查四层次架构（CONTEXT.md:134）的 L2-blind-review.md 产物格式从未包含发现类型分类字段；AC-2 引入了 hook 需解析 review 产物内容的需求，但未指定 hook 如何判定 "源码问题" vs "文档问题"。这是 prompt 产物格式与 hook 消费者之间的契约缺口。

**Consequence（后果）**：hook 实现者面临三种歧义路径：(a) 解析 Symptom 字段中的文件路径，按扩展名判定 → 实现复杂且易误判（如 `.md` 文件中讨论代码问题）；(b) 要求 L2/L3 审查员在每条发现前加显式 tag（如 `[SRC]` / `[DOC]`）→ 需修改独立审查产物的输出格式，影响范围超出本次 change 的 out 范围（out: "不改动 L2/L3 审查内容生成逻辑"）；(c) 将所有发现默认为源码问题 → 假阳性导致 phase 1/2 被误阻断。不解决此歧义，AC-2 hook 实现无法开始编码。

**Remedy（修补）**：补一条 AC（AC-2a）明确定义分类机制。建议方案 A（推荐，零格式变更）：

```
### AC-2a · 源码级发现判定规则

- **Given** INDEPENDENT-REVIEW-<N>.md 包含若干发现条目
- **When** hook 需要判定触发条件
- **Then** 按以下规则判定为"源码级发现"：
  - 发现的 Symptom 字段中引用的文件路径扩展名不在 `.md` 白名单内（`.md`, `.markdown`, `.MD`）
  - 或发现的 Source 字段引用了非文档型 ADR/规格（如引用代码文件路径、函数名、API 签名）
- **验证方式**: `npx bats test/test_l2_l3_fix_compliance.bats`（测试用例：发现引用 .sh 文件 → 判定源码级；发现引用 .md 文件 → 不触发）
```

---

### 🟡 R2 · AC-1/AC-4 验证方式完全依赖人工审查，无自动化测试路径

**Symptom（症状）**：`REQUIREMENT.md:26` AC-1 验证方式为 "人工审查 5/6/7 prompt 文本是否含上述强制协议；人工构造'文档敷衍'场景确认 agent 不再仅产出 .md 修改"。`REQUIREMENT.md:52` AC-4 验证方式为 "人工审查 prompt 是否含此约束；构造 ≥4 条发现场景确认 agent 输出说明"。两条 AC 的验证方式均以 "人工审查" 开头，未指定任何可机器执行的验证路径。

**Source（源头）**：AC-1 和 AC-4 验证的是 prompt 文本内容合规性和 agent 行为合规性——前者可用 grep 自动化，后者可用 bats 集成测试（构造 mock 场景 + 检查 git diff）自动化。当前将两者均标为 "人工审查" 是验证策略设计不足。

**Consequence（后果）**：在 flow-kit 的自动化 pipeline 上下文中（gate-integrity、PCG、PCSC 均依赖可机器执行的检查），两条 AC 的验证落在 CI/CD 测试覆盖之外，成为事实上的 "不可验证需求"——每次 release 都需人工介入，且人工审查成本随 change 数量线性增长。

**Remedy（修补）**：将 AC-1 和 AC-4 的验证方式升级为可机器执行路径。

AC-1 修改后：
```
- **验证方式**: 
  - bash: `grep -q '修代码优先' flow-kit-bundle/flow-kit/prompts/5-test.md && grep -q '修代码优先' flow-kit-bundle/flow-kit/prompts/6-review.md && grep -q '修代码优先' flow-kit-bundle/flow-kit/prompts/7-integration.md && grep -q '修代码优先' flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md`（确认协议已写入四个 prompt 文件）
  - bats: `test/test_l2_l3_fix_compliance.bats` 新增集成测试：构造包含源码级发现的 INDEPENDENT-REVIEW-N.md → 运行 agent 处理 → 断言 git diff 含非 .md 变更或技术债登记条目
```

AC-4 修改后：
```
- **验证方式**:
  - bash: `grep -q '半数以上' flow-kit-bundle/flow-kit/prompts/5-test.md`（或其他承载 AC-4 约束的 prompt 文件）确认滥用防护约束已写入
  - bats: `test/test_l2_l3_fix_compliance.bats` 构造场景：INDEPENDENT-REVIEW 含 ≥4 条源码级发现、agent 将其中 ≥50% 登记为技术债 → 断言 agent 输出中必须含显式说明段
```

---

### 🟡 R3 · 缺失非功能性需求：门控机制的故障容错策略未定义

**Symptom（症状）**：`REQUIREMENT.md:92-96` 非功能性需求段仅覆盖性能（<1s）、兼容性、可观测性。未涉及门控 hook 在异常情况下的行为策略。具体缺失场景：(a) `git diff` 命令执行失败（如仓库损坏、不在 git 目录内）；(b) hook 内 jq 解析 `.flow-active` 失败；(c) `independent-review-gate.sh` 自身脚本 bug 导致非零退出。

**Source（源头）**：gate-integrity（CONTEXT.md:128-131）已锁定 "三层防线不可绕过" 的设计决策，但未规定这条防线自身的故障模式。任何安全门控机制必须在 fail-open（故障时放行）和 fail-closed（故障时阻断）之间做明确选择——选择前者的风险是绕过门控，选择后者的风险是 pipeline 死锁。当前 REQUIREMENT 未提及此决策。

**Consequence（后果）**：实现者可能做出不一致的选择——部分故障路径放行、部分阻断——导致行为不可预测。在生产环境中，一个简单的 git 仓库异常可能使整个 pipeline goal 卡死且无法恢复（如果是 fail-closed），或静默放行未经审查的代码（如果是 fail-open）。

**Remedy（修补）**：在非功能性需求段追加一条 `fault-tolerance` 条目：

```
- **容错**: hook 执行异常时采用 fail-closed 策略（阻断 transition），同时输出明确错误信息含故障原因 + 恢复指引（如"git diff 失败：请确认当前目录为 git 仓库且 git 可用"），并写入 hook log。**不静默放行**（防止故障窗口绕过门控）。
```

---

### 🟡 R4 · CHANGE.md 承诺的文件级校验未在 AC 中落地

**Symptom（症状）**：`CHANGE.md:27` 写 "Hook 层：gate hook 增强实效性校验——检测'纯文档响应'（发现 >0 但 diff 只含 .md）、校验'已修复'声明对应的源文件确实被修改"。后半句 "校验'已修复'声明对应的源文件确实被修改" 要求 hook 验证 review 发现中宣称已修复的**具体源文件**确实出现在 git diff 中，而非仅检查 diff 中是否有**任意**源码文件变更。但 `REQUIREMENT.md:33` AC-2 Then 子句仅检查 "diff 中含源码文件变更 → 放行"——不区分具体文件。AC-2 自身注释也写 "(不做变更内容的语义校验，那是 AC-3 的范围)"，但 AC-3（REQUIREMENT.md:37-45）是关于两层校验共存，与文件级或语义级验证完全无关。

**Source（源头）**：CHANGE.md 的验收线是为粗粒度方向性描述（如其自身标注 "粗粒度，不是 AC"），但 REQUIREMENT 的 AC 在细化过程中丢失了文件级检查维度，且未在 v2 范围中显式承接。v2 第一条写 "语义级 diff 校验：不仅检查'有没有改源码文件'，还检查修改内容是否真的对应发现描述"——这是**内容级**匹配，比 CHANGE.md 承诺的**文件级**匹配更进一步。文件级匹配（检查具体文件是否被修改）实际上落在 AC-2 当前行为（任意源码文件）和 v2 语义级之间，成为一个无人认领的精度层级。

**Consequence（后果）**：用户（或后续 reviewer）在 CHANGE.md 验收线中期待文件级校验，但审查 AC 时发现 v1 只做到 "有没有改任意源码文件" 级别。如果这个精度差是有意裁剪，需要在 REQUIREMENT 中显式记录裁剪理由；如果是遗漏，则是 AC 覆盖不全。

**Remedy（修补）**：在 AC-2 Then 子句后追加注释：

```
（注：v1 仅检测"是否存在源码变更"（粗粒度），具体文件级对应校验列入 v2。这是有意裁剪——v1 先解决最恶劣的纯文档敷衍模式，文件精度留给 v2 语义级校验一起做。）
```

---

### 🟡 R5 · 分类权限缺口：agent 自分类发现类型可绕过代码修复强制

**Symptom（症状）**：`REQUIREMENT.md:22` AC-1 Given 条件 "其中包含 ≥1 条源码级发现（非纯文档问题）"——agent 需要自行判定哪些发现是 "源码级" 哪些是 "文档问题"。AC-1 没有约束 agent 的分类行为：agent 可以将一个指向 `hooks/stop/independent-review-gate.sh` 的发现标记为 "文档问题"（声称 "这是 review 流程文档层面的建议"），从而绕过代码修复强制。

**Source（源头）**：AC-1 的 "修代码优先" 强制协议将分类权限完全交给被约束方（agent），形成自我监督的闭环。在 gate-integrity 的设计中，".done 真实性校验" 成功的关键在于 hook 层独立于 agent 做校验——agent 无法伪造 hook 的判定。但 AC-1 的分类步骤发生在 prompt 层，hook 层无法介入。

**Consequence（后果）**：中等风险的弱化——agent（尤其是弱模型）可通过 "重新分类" 绕过协议。这不是零日漏洞（AC-2 hook 层的纯文档检测仍会触发——如果 agent 把所有发现都标为文档问题且在 prompt 阶段不做代码变更，hook 仍会因 "diff 仅含 .md" 而阻断），但会削弱 prompt 层的约束效果：agent 可能选择性修复少数发现，将其余重新分类以降低认知负担。

**Remedy（修补）**：在 AC-1 的 Given/When/Then 中追加一条子句：

```
### AC-1a · 分类约束

- **Given** INDEPENDENT-REVIEW-<N>.md 发现条目中 Symptom 字段引用的文件路径扩展名为非 .md（如 .sh / .bats / .json）
- **When** agent 对该发现进行分类
- **Then** 该发现必须被视为"源码级发现"，agent 不得将其重新分类为"文档问题"。
- **验证方式**: `npx bats test/test_l2_l3_fix_compliance.bats`（构造发现引用 .sh 文件 → agent 将其标记为文档问题 → 违规断言）
```

---

### 🟢 R7 · AC-2 交叉引用错误

**Symptom（症状）**：`REQUIREMENT.md:33` AC-2 Then 子句末尾括号注释写 "(不做变更内容的语义校验，那是 AC-3 的范围)"。但 AC-3（REQUIREMENT.md:37-45）是关于 "实效性校验与现有真实性校验共存"——即两层 gate 校验的执行顺序和独立性——与语义校验完全无关。正确的引用目标应为 v2 范围中的 "语义级 diff 校验" 条目。

**Source（源头）**：AC 编号在编辑过程中可能调整过（AC-3 最初可能是语义校验相关，后来被替换为共存性校验），但括号注释未同步更新。这是典型的文档漂移。

**Consequence（后果）**：后续读者（DESIGN 阶段、实现者）按注释追踪到 AC-3 时会发现内容不匹配，产生困惑或误判覆盖完整性。

**Remedy（修补）**：将括号注释改为 `（不做变更内容的语义校验，参见 v2 范围第一条「语义级 diff 校验」）`。

---

### 🟢 R8 · AC-4 阈值边界条件未说明

**Symptom（症状）**：`REQUIREMENT.md:49` AC-4 Given 条件写 "某阶段 L2/L3 发现 ≥4 条源码级问题"，When 条件写 "主 agent 将其中 ≥50% 标记为'技术债登记'"。组合阈值的边界效应：3 条发现中 2 条技术债（66.7%）→ 不触发（不足 ≥4 条门槛）；4 条发现中 2 条技术债（50%）→ 触发。前者的逃避比例更高但被数量门槛豁免。

**Source（源头）**：双阈值（数量 + 比例）组合产生边界不连续。门槛设计可能是为了避免低发现数场景的噪音（1-3 条发现高频触发说明），但设计理由未在 AC 注释或非功能性需求中说明。

**Consequence（后果）**：轻微——agent 在 3 条发现的低量场景中以高比例技术债绕过防护。实际风险低（3 条发现的总修复量小），但会留下一个已知的检测盲区。

**Remedy（修补）**：在 AC-4 末尾追加设计理由注释：

```
（设计理由：≥4 条门槛避免低发现量场景高频触发说明的噪音——1~3 条发现时，每条的修复成本低，技术债登记本身可能比直接修复更耗时。阈值可在 v2 根据实际使用数据调整。）
```

---

**Verdict**: fail

> 存在 1 条 🔴 Critical 发现（R1），必须修复后方可通过本阶段审查。R1 是阻塞性问题——"源码级发现"的分类机制不定义，AC-2 hook 实现无法开始编码。其余 5 条 🟡 Major 和 2 条 🟢 Minor 建议在进入 DESIGN 前修正或记录为已知限制。

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-07 14:47）

> 自动生成于 2026-07-07 14:47。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[{"file":"工件（阶段1）","issue":"AC-1 的 Given 中“源码级发现”定义不明确，未引用 AC-2a 判定规则，且验证方式包含不可自动化的人工端到端验收","why":"AC-1 的 Given 依赖于“源码级发现”概念，但没有明确其判定标准，造成歧义；验证方式中的“人工构造…端到端验收”不可重复验证，且 grep 仅验证 prompt 内容而非 AC 逻辑本身","fix":"在 AC-1 Given 中明确“根据 AC-2a 规则判定为源码级发现”；将人工端到端验收替换为自动化 bats 测试；将验证方式重写为直接验证 agent 行为（可由 AC-2 测试间接覆盖）或明确 prompt 内容验证仅为边界条件"},{"file":"工件（阶段1）","issue":"AC-2b 的 Given 假设 agent 会以“Fixed in code: <file>”格式标记，但 AC-1 未要求 agent 输出此格式","why":"AC-2b 的 Then 依赖从 agent 声明中提取文件路径，但前面没有定义 agent 必须提供该标记格式，可能导致实际输出不一致，无法可靠提取目标文件","fix":"在 AC-1 Then 中要求 agent 对每条代码修复必须标注“Fixed in code: <file>”，或统一标记格式；或者 AC-2b 改为从 git diff 中推断修复目标，不依赖 agent 声明"}],"minor":[],"verdict":"pass","summary":"工件整体设计合理，范围切分清晰，非功能性需求覆盖全面。但存在两条 major 问题：AC-1 的“源码级发现”定义不明确且验证方式不可靠；AC-2b 的标记格式缺失前置定义，影响可验证性。"}
```
