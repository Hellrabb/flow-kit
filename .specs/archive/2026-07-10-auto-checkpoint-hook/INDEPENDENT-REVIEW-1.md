# 独立审查 · 阶段 1

## L2 盲审

> 审查日期：2026-07-10
> 审查工件：`.specs/auto-checkpoint-hook/REQUIREMENT.md`
> 参考文档：`.specs/auto-checkpoint-hook/CHANGE.md`、`.specs/CONTEXT.md`
> 审查阶段：1 · 需求审查

---

### 🔴 R1 · REQUIREMENT "不去抖" 与禁动清单强制使用的 `checkpoint_write()` 内置去重逻辑矛盾

**Symptom（症状）**：
- CHANGE.md L28 明确声明："不去抖：每次 Write/Edit 都更新，简单可靠（jq 写 .flow-active < 10ms）"
- REQUIREMENT.md AC-1 Then："AI 调用 Write 工具写入文件... interrupt 字段被更新"（隐含"每次调用必更新"）
- CONTEXT.md L155 描述："v1 去掉了早期设计中的 30s 去重窗口——实测 jq 更新 < 10ms，去重增加的复杂度不值得"
- 但 CONTEXT.md § 禁动清单 L342 强制约束："不允许绕过直接 jq write `.flow-active.interrupt`（必须通过 `checkpoint_write()`）"
- 现有的 `flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh` L32-35 在 `checkpoint_write()` 内部调用了 `checkpoint_dedup_check()`，实现 30 秒去重窗口（L63-98）：同文件+同操作类型在 30 秒内第二次 Write/Edit 会被静默跳过，**不更新 interrupt**

**Source（源头）**：需求规格的显式声明（"不去抖"/"每次都更新"）与禁动清单（CONTEXT.md）强制使用的实现路径之间存在直接矛盾。需求要求每次 Write/Edit 都更新 interrupt；禁动清单要求只能通过 `checkpoint_write()` 写 interrupt；但 `checkpoint_write()` 内部有去重逻辑会截断高频写入。三者无法同时成立。

**Consequence（后果）**：
- 若按 REQUIREMENT 实现（绕过 `checkpoint_write()` 直接 jq write）→ 违反 CONTEXT.md 禁动清单，触发 gate 层拦截
- 若按禁动清单实现（调用 `checkpoint_write()`）→ 高频编辑场景下 30 秒内连续同文件编辑仅第一次更新 interrupt，后续编辑不更新，违反 AC-1/AC-2 的"每次调用必更新"语义
- 两个路径都导致 spec 合规失败。此矛盾必须在 4-dev 之前解决，否则代码无论怎么写都会有一个约束被违反。

**Remedy（修补）**：二选一，需在 REQUIREMENT 中显式记录决策：
- **选项 A（推荐）**：更新 REQUIREMENT，接受去重行为。将 AC-1/AC-2 的 Then 改为"interrupt 字段被更新（30 秒内同文件同操作类型去重跳过）"，v1 范围中的"不去抖"改为"30s 去重窗口"。同时更新 CHANGE.md L28 和 CONTEXT.md L155 中矛盾的描述。
- **选项 B**：在本次 change 中修改 `checkpoint-lib.sh`，移除 `checkpoint_write()` 中的 `checkpoint_dedup_check()` 调用，使库行为与 REQUIREMENT "不去抖"一致。需额外测试验证去重移除后不影响其他 checkpoint 调用方（prompt 层手动 `/flow checkpoint`）。
- 无论选 A 还是 B，必须在 REQUIREMENT.md 中新增一条 AC 说明去重策略（AC-7：去重行为），或修改现有 AC-1/AC-2 的 Then 子句以涵盖去重。

---

### 🟡 R2 · AC-1 与 AC-2 的 Given 子句不一致（phase 约束）

**Symptom（症状）**：
- REQUIREMENT.md AC-1 Given L19：`phase` 为 0~7 之一
- REQUIREMENT.md AC-2 Given L26：缺少 `phase` 约束（仅写 `change_id` 非 null）

**Source（源头）**：同一功能（Write/Edit checkpoint）的两条 AC 对触发条件描述不一致。v1 范围 L65 声明"全阶段启用（phase 0~7，有活跃 change 即生效）"，AC-1 正确反映了此范围，但 AC-2 遗漏了 phase 约束。

**Consequence（后果）**：
- 实现者可能对 AC-2 做不同解读：有人会补上 phase 0~7 约束（与 AC-1 一致），有人会认为 AC-2 有意放宽（不限制 phase）。歧义导致测试覆盖不一致——AC-2 的测试可能不验证 phase 边界条件。
- 实际影响：若 `.flow-active` 有 `change_id` 非 null，它在正常情况下必有合法 phase（0~7），所以行为上难以触发差异。但 spec 的不一致性本身就是风险——未来若有人引入"change_id 非 null 但 phase 为非法值"的状态，AC-1 不触发而 AC-2 触发，行为分裂。

**Remedy（修补）**：
- 统一 AC-2 的 Given 为："Given `.flow-active` 存在且 `change_id` 非 null，`phase` 为 0~7 之一"
- 或将两条 AC 合并为一条（覆盖 Write + Edit 双路径），消除冗余和分歧

---

### 🟡 R3 · AC-5 fail-open 测试仅覆盖 Write 路径，未覆盖 Edit

**Symptom（症状）**：
- AC-5 L46-50：Given "AI 调用 Write 工具" → 仅验证 Write 路径的 fail-open
- v1 范围 L68："Fail-open 容错（hook 异常不阻断工具调用）" ——未限定仅 Write
- CHANGE.md L25："PreToolUse hook，在 Write/Edit 工具调用前自动更新" ——覆盖两种工具

**Source（源头）**：AC-5 的测试场景只设定了 Write 触发，但核心功能覆盖 Write + Edit 双工具。若 PreToolUse hook 对 Write 和 Edit 的集成方式有任何差异（如不同的工具调用参数），仅测 Write 会遗漏 Edit 的 fail-open 路径。

**Consequence（后果）**：
- 若 Edit 工具调用时 hook JSON 参数解析失败（如字段名不同），AC-5 测试全部通过（Write 路径 OK），但 Edit 路径实际可能阻断工具调用（非 fail-open）。用户编辑文件时遭遇工具调用失败。
- 概率中等——取决于 CC hook 协议对 Write 和 Edit 传递的参数结构是否一致。

**Remedy（修补）**：
- AC-5 的 Given 改为："AI 调用 Write 或 Edit 工具（分别测试）"
- 验证方式加一条："对 Edit 路径重复上述 corrupt JSON 测试，断言 Edit 目标文件被修改"
- 或将 AC-5 拆为 AC-5a（Write fail-open）和 AC-5b（Edit fail-open）

---

### 🟡 R4 · AC-6 "resume 路径" 定义模糊，测试无法可靠编写

**Symptom（症状）**：
- AC-6 L56-57 验证方式："`bats test` —— 预设 interrupt 值，模拟 resume 路径（读取 interrupt 字段），断言输出含关键字段"
- "模拟 resume 路径" 未定义具体机制。是调用 SessionStart hook `flow-kit-resume.sh`？是执行某个 CLI 命令？是直接 jq 读取 `.flow-active` 然后 grep 输出？

**Source（源头）**：AC 验证方式要求 Given/When/Then 可机器验证，但 "resume 路径" 涉及跨 session 的行为（SessionStart hook），在当前 session 内难以端到端测试。模糊的"模拟"措辞让测试用例设计者自行解释，可能导致测试只测了"jq 能读到 interrupt 字段"（与 AC-3/AC-4 的测试重叠）而没有测"恢复提示实际包含中断字段"。

**Consequence（后果）**：
- 测试实现可能退化为一层浅验证（jq `.interrupt` 非空），等价于 AC-1/AC-2 的测试，造成重复覆盖但 zero 增量价值。
- 真正的恢复精度缺陷（如 SessionStart hook 读取 interrupt 时路径错误、banner 格式不包含 checkpoint 信息）不会被 AC-6 捕获，漏到生产环境。用户中断后恢复时 AI 看不到 checkpoint 信息。

**Remedy（修补）**：
- 明确"resume 路径"的测试手段，例如：
  ```
  验证方式: bats test ——
  1. 预设 interrupt 值到 .flow-active
  2. 调用 SessionStart hook flow-kit-resume.sh（或等价脚本函数）
  3. 断言其 stdout 包含 "${active_file}" 和 "${last_action}" 和 "${checkpoint_at}"
  ```
- 若 SessionStart hook 不可直接调用，至少定义 mock 接口：注入 interrupt 数据 → 调用恢复逻辑的**可测试单元** → 断言输出格式含三字段。
- 同时确认 AC-6 的"恢复提示"具体指什么输出通道（stdout？banner？特定文件？），将其写入 When/Then 子句。

---

### 🟡 R5 · v1 范围中文档更新和安装集成项无对应 AC

**Symptom（症状）**：
- REQUIREMENT.md v1 范围 L71："更新 `flow-kit/skills/flow/SKILL.md` 文档（checkpoint 段说明自动机制）"
- REQUIREMENT.md v1 范围 L72："安装脚本集成（`install.sh` 注册新 hook 到 `.claude/settings.json`）"
- 无任何 AC 覆盖这两项。6 条 AC 全部是针对 hook 运行时行为的。

**Source（源头）**：AC 是 TEST 阶段派生用例的唯一来源（REQUIREMENT.md L108："AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC"）。这意味着文档质量和安装集成在后续阶段**没有任何可验证的接受标准**——TEST 阶段无法为它们派生测试用例。

**Consequence（后果）**：
- 4-dev 实现完成后，5-test 无法为文档更新和安装集成编写测试（没有 AC 可引用）。两个 v1 交付物可能未经测试就进入 6-review，review 也只能做主观判断。
- 安装脚本若集成错误（如 hook 注册路径错误、缺少权限、覆盖其他 hooks），到 7-integration 甚至用户实际安装时才暴露——修复成本高。
- 文档若更新不当（遗漏 checkpoint 段、描述与实际行为不符），用户体验受损但不触发任何 AC 失败。

**Remedy（修补）**：
- 新增 AC-7（文档完整性）：Given hook 已安装，When 用户查看 `flow-kit/skills/flow/SKILL.md`，Then checkpoint 段说明 PreToolUse hook 自动机制、字段含义、如何读取 interrupt 恢复。
- 新增 AC-8（安装集成）：Given 执行 `install.sh`，When 安装完成，Then `.claude/settings.json` 的 hooks.PreToolUse 数组包含 checkpoint hook 条目。
- 若认为文档/安装的测试不需要 bats 用例（更偏人工验收），至少在 v1 范围中显式标注"文档更新和安装集成由 6-review 人工检查，不走 bats 测试"，避免 5-test 阶段因缺 AC 而困惑。

---

### 🟢 R6 · `checkpoint_write()` 额外写入 `failing_check` 字段未在 AC 中声明

**Symptom（症状）**：
- `flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh` L42 中 `checkpoint_write()` 总是向 `.interrupt` 写入 `failing_check` 字段（取自 `$3` 参数，可为空字符串）
- AC-1/AC-2 Then 定义的 interrupt 仅包含三个字段：`active_file`、`last_action`、`checkpoint_at`
- REQUIREMENT 未提及 `failing_check` 字段

**Source（源头）**：lib 设计预先包含了 prompt 层手动 `/flow checkpoint` 场景下的额外字段（用于记录"触发 checkpoint 的失败检查命令"），但 REQUIREMENT 对此无声明。当 PreToolUse hook 调用 `checkpoint_write(file, desc)` 时（`$3` 为空），interrupt 仍会写入 `"failing_check": ""`。

**Consequence（后果）**：
- AC-6 恢复精度验证若用 jq 严格匹配 interrupt 结构（而非仅验证三字段存在），可能因多余字段而误判失败。
- 用户阅读 `.flow-active` 时看到未文档化的 `failing_check` 字段，可能困惑其用途。
- 实际影响低——多余字段不破坏其他功能，但 spec 完整性受损。

**Remedy（修补）**：
- 在 REQUIREMENT 的"依赖与假设"段或 AC-1 Then 中说明 `interrupt` 可能包含额外字段（如 `failing_check`），定义其语义（"仅 prompt 层手动 checkpoint 时填充；PreToolUse hook 自动写入时为空字符串"）。
- 或修改 `checkpoint_write()` 使其仅在 `$3` 非空时才写入 `failing_check`，空时省略该字段。

---

### 🟢 R7 · 非功能性需求中缺少容量限制声明

**Symptom（症状）**：
- 非功能性需求 L92-96 涵盖性能、安全、兼容性、可观测性
- 缺少容量限制：最大文件路径长度（极端深度嵌套路径可能超出 jq 或 JSON 字符串限制）、最大 interrupt JSON 尺寸、最长 `last_action` 字符串

**Source（源头）**：防御性完整度——虽然 `checkpoint-lib.sh` 实现了 200 字符截断（L28-30），但 REQUIREMENT 层面未声明此约束，导致截断行为无 spec 依据。

**Consequence（后果）**：
- 极低概率事件（文件路径 > 4096 字符或 action 描述极长），即使发生也不会造成数据损坏（最多截断），但 spec 缺省相当于隐式信任实现者的判断。
- 实际风险极低，仅作为 spec 完整性标记。

**Remedy（修补）**：
- 在非功能性需求中增加："容量：`active_file` 支持最长 4096 字符（Unix 文件系统限制）；`last_action` 截断至 200 字符；interrupt JSON 总大小 < 1KB"
- 或标注"容量限制由 `checkpoint-lib.sh` 实现层定义，本 spec 不做额外约束"

---

**Verdict**: fail

> 失败原因：🔴 R1 是 spec 层面的硬矛盾——REQUIREMENT 声明"不去抖"但禁动清单强制绑定的 `checkpoint_write()` 内置 30 秒去重逻辑。两条约束路径在 4-dev 之前必须协商一致，否则代码无论如何实现都会违反其中一条。建议优先解决 R1 后重新提交审查。
