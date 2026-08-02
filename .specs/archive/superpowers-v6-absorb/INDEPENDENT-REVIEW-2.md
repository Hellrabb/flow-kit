# 独立审查 · 阶段 2

---

## L2 盲审

> L2 审查人：独立盲审员（architect-reviewer 角色）
> 审查对象：`.specs/superpowers-v6-absorb/DESIGN.md`（含参考：ADR-014~018、CONTEXT.md、ARCHITECTURE.md）
> 审查日期：2026-08-02

### 🟡 R1 · 禁动清单 Part D override 无显式例外流程：DESIGN 触碰了 CONTEXT 声明为禁动的区域，但未给出例外理由

**Symptom（症状）**：DESIGN §0.5.1 在"不应该触碰但 AI 容易'顺手'碰的"段中写道 `package-flow-kit.sh（打包逻辑无关 · 但 Part D 需新增 scripts/ 到 cp 清单）`。而 CONTEXT.md §禁动清单明确登记 `package-flow-kit.sh` Part F L504-530（brooks-lint 打包段）— 仅 Part F 可改；Part A-E/G 禁顺手改`。Part D 处于 A-E 禁动范围内。

**Source（源头）**：CONTEXT.md 禁动清单（line 422）以 A-evolve 2026-07-08 第1轮追加形式锁定"Part A-E/G 禁顺手改"。该禁动条目是硬约束，DESIGN 未提供显式的例外理由文段（仅一个括号附注"但 Part D 需新增 scripts/ 到 cp 清单"）。ARCHITECTURE.md §2.2 模块依赖规则声明"If 新 change 需要破例，必须在 DESIGN §0.5 显式声明并升级 ADR"——本 DESIGN 既未显式声明破例，也未升级 ADR。

**Consequence（后果）**：Phase 4 实施时，若 4-dev 严格遵循禁动清单，会在 `package-flow-kit.sh` Part D 修改处被 hook D7 path-guard 拦截（independent-review-gate.sh 的 PreToolUse matcher 覆盖 Bash+Write+Edit 三种工具调用），导致 pipeline 死锁。即使 hook 不拦截，禁动清单条目与 DESIGN 的不一致会引入维护歧义：未来 AI 无法判断是禁动清单过时还是 DESIGN 越权。

**Remedy（修补）**：DESIGN §0.5.1 的"不应该触碰但…"段改为显式例外声明：

```
- package-flow-kit.sh Part D scripts/ cp 清单（本 change 例外）：
  理由：新增 scripts/ 目录需在打包清单中注册，否则 bundle.tar.gz 不包含 review-package / task-brief。
  范围：仅 Part D 的 scripts/ cp 行（~3 行追加），不动 Part D 其他逻辑。
  禁动清单影响：本 change 实施时，实施者（4-dev）需知晓 CONTEXT.md 禁动清单"Part A-E 禁顺手改"中的
  Part D 对本 change 解禁。
```

---

### 🟡 R2 · 33-flow-active-integrity hook 与新 task_progress 字段的前向兼容性未评估

**Symptom（症状）**：DESIGN §9.3 登记 `.flow-active.goal.task_progress[]` 为新跨模块契约，但未评估既有的 33-flow-active-integrity hook 是否对新字段敏感。ADR-015 §Consequences 仅标注"33-flow-active-integrity hook 已有 .flow-active 字段校验机制，可扩展 task_progress schema 校验（可选）"——未说明当前 hook 在不更新的情况下是否会对 task_progress 产生误报。

**Source（源头）**：ARCHITECTURE.md §2.1 模块表登记 33 号 hook 职责为".flow-active 字段与磁盘产物交叉验证"。CONTEXT.md §禁动清单登记"33-flow-active-integrity.sh — 后续不应被无关 change 修改"。本 change 新增 `.flow-active.goal.task_progress` 字段——既不是"无关 change"（本 change 直接添加 task_progress），也可能触发 33 号 hook 的 schema 校验逻辑（取决于 hook 校验策略是白名单还是黑名单）。

**Consequence（后果）**：若 33 号 hook 采用白名单策略（只允许已知字段）→ task_progress 被标记为"未知字段"→ 触发矫正文件 `.flow-active.correction` → session 启动时注入误导性 banner。若 33 号 hook 采用黑名单策略（默认放行未知字段）→ 无影响。DESIGN 未确认走哪条路径，属未知风险。出现概率中等，但误报会在 Phase 4/5/6 多个session 反复触发。

**Remedy（修补）**：
1. 在 DESIGN §0.5.1（既有架构对齐）中增加一项交叉检查：读 33-flow-active-integrity.sh 的当前 schema 校验逻辑，确认 task_progress 新字段是兼容（默认放行未知字段）还是需更新（白名单需添加 task_progress）。
2. 若需更新 hook：增加一行到 DESIGN §0.5.1 "触碰模块" 清单（当前设计将 hooks/ 整体列在"不应该触碰"段，不准确）。
3. 若兼容：在 DESIGN §5 风险段加一条 "R9: task_progress 触发 33 hook 误报" 并标注"已确认兼容"。

---

### 🟡 R3 · token 测量风险 R8 的结构性 AC 与 US-1 目标之间的因果链薄弱

**Symptom（症状）**：DESIGN §5 R8 标注概率 **HIGH**、影响 **HIGH**（"实际 token 削减不达 -25%"），缓解措施为"已用结构性 AC 作硬门槛"。但结构性 AC（review 轮数 4→2、4-dev reload 34KB→≤15KB、GO.md 473→≤350 行）与端到端 token 削减目标之间的因果链未被验证。例如：即使 GO.md 从 473→338 行且路由一致，实际 token 消耗可能因模型对压缩后 prompt 的响应变长（narration constraint 抵消压缩收益）而无净减少。

**Source（源头）**：REQUIREMENT.md §范围决策框确认"结构性 AC 是硬门槛，参考性 AC 跑一次 pre/post 样例作证不卡 toll-gate"——这是 upstream 决策，DESIGN 忠实传递。但作为 DESIGN 审查，需验证该策略的风险是否在 DESIGN 中被充分体现。当前 R8 的缓解段引用结构性 AC 作为缓解，但结构性 AC 自身并非 token 削减的充分条件——它们是 token 削减的**必要不充分代理变量**。经典工程原则"measure what matters, not what's easy"（Cem Kaner）在此适用。

**Consequence（后果）**：最坏情况：所有结构性 AC 全过（phase 5 绿），但端到端 token 仅 -8%（远低于 US-1 的 -25% 目标），用户和项目的核心价值主张未实现。由于 REQUIEMENT §范围决策已将参考性 AC 设为不卡 toll-gate，此场景下 pipeline 不会阻塞——change 可能 archivable but underwhelming。中概率高影响因"不达目标但仍能通过流程"的组合具有隐蔽性。

**Remedy（修补）**：DESIGN §5 R8 的缓解段显式记录：结构性 AC 与端到端 token 削减的关系（必要非充分代理），以及 phase 5 参考性 token 测量结果 < -15% 时触发人工 review（不卡 automated toll-gate，但作为阶段 gate 的 manual approval 点）。这不需要修改 REQUIREMENT 的范围决策，仅需在 DESIGN 风险段明确标注这个"已知薄弱环节"。

---

### 🟡 R4 · D1 决策标题"4轮→1轮"与实际 1~2 轮模型不一致，且与 AC-B2 命名冲突

**Symptom（症状）**：DESIGN §1 D1 标题"review phase 4 轮 → 1 轮（spec + quality + UI 合并）+ spot-check Critical 触发"——但 AC-B2 将 spot-check 明确定义为"**独立第 2 轮**"。决策表中备选项 (a) 为"全合并含 spot-check"，(b) 为"保持 4 轮"，(c) 为"合并但 spot-check 每次跑"——这三种方案均为 1~2 轮模型。无论选哪个，结果都不是 strict "4→1"，而是 "4→1 base + 0~1 spot-check"。

**Source（源头）**：REQUIREMENT §AC-B2 命名约定："Cross-model spot-check 保留为独立第 2 轮，Critical-finding 触发"。AC 层将 spot-check 精确描述为"第 2 轮"，D1 标题却称"1 轮"——两处的"轮"定义不同。从系统角度看，spot-check 确实是一个独立的审查轮次（调用独立 subagent、产生独立产物 INDEPENDENT-REVIEW-6.md）。将 spot-check 排除在"轮"之外会误导对 review 阶段总成本的理解（1 轮 = 必有成本；+1 轮 = Critical 时附加成本）。

**Consequence（后果）**：Phase 6 prompt 实施时，若实施者按"D1 1 轮"理解，可能将 spot-check 嵌入合并审查（而非独立 subagent）——这与 AC-B2 的"独立第 2 轮"和 ADR-014 的"cross-model spot-check"设计要求冲突。快速阅读者容易仅看标题而跳过决策详细描述，从而形成错误心智模型。

**Remedy（修补）**：
```
- 标题改为：review phase 4 轮 → 1 轮合并审查 + Critical 触发 1 轮 spot-check（1~2 轮模型）
- 或保持原标题但在第一行加注："注：以下称"1 轮"指合并审查的 base 轮，spot-check 为可选的独立附加轮，AC-B2 定义为"第 2 轮"。"
```

---

### 🟢 R5 · ADR-016 detect_opencode_tier_support 探测脚本依赖未验证的 JSON 路径

**Symptom（症状）**：ADR-016 §3 的探测伪代码 `jq -e '.task_tool_supports_model // false' ~/.config/opencode/oh-my-openagent.json` 假设 `oh-my-openagent.json` 中存在 `.task_tool_supports_model` 字段。DESIGN §5 R7 标注"OpenCode task-level model switching 能力未确认"为中等风险，但探测方案的 JSON 路径来自假设而非对实际配置文件的 grep/read 验证。

**Source（源头）**：ADR-016 §3 "detect_opencode_tier_support 实现"段。该实现为伪代码级别（DESIGN 阶段合理），但字段路径 `.task_tool_supports_model` 在真实 oh-my-openagent.json 中的存在性未被 cross-reference。CONTEXT.md 域语言段登记了 OpenCode 的 agent config（如"oh-my-openagent.json 显示 agent type 各自有 `model` 字段"），但 agent 级别的 model 字段 ≠ task tool 的 model 参数支持。这是概念混淆风险。

**Consequence（后果）**：Phase 4 实施时，若 oh-my-openagent.json 无此字段，探测逻辑永远返回 `false`（fallback 到 "hint" path B），不影响功能性正确性（fallback 是安全默认）。但探测逻辑本身失去意义——永远走 fallback 却装模作样"探测"。属于低影响但暴露设计假设未验证。

**Remedy（修补）**：在 DESIGN §5 R7 的缓解措施中追加一项："Phase 4 实施第一步：grep/read `~/.config/opencode/oh-my-openagent.json` 确认 task tool model 参数的真实字段名和存在性；若不存在则直接硬编码 fallback=hint，删除无效探测逻辑。"

---

### 🟢 R6 · task_progress lifecycle 图未展示与 task-brief 的交互路径

**Symptom（症状）**：DESIGN §2.2 task_progress lifecycle 图显示"4-dev 入场读 .flow-active.goal.task_progress → 若 T03 已在 → skip 重派；否则派"，但未展示 skip 路径下 task-brief 是否仍需提取该 XML block。当 T03 已完成（已存于 task_progress）时，task-brief 提取 T03 到 `/tmp/brief_T03.txt` 是一个 no-op（白提取）——但 DESIGN 未说明是否优化掉这一步。

**Source（源头）**：DESIGN §2.2 与 §2.1 数据流图之间存在信息差。§2.1 显示 task-brief 是 4-dev 入场的固定步骤（TASK.md → awk → /tmp/brief_T03.txt），但 §2.2 的 skip 逻辑暗示如果 task 已完成，brief 内容不需要。两图之间缺少"task_progress hit → skip task-brief extraction"的连线。

**Consequence（后果）**：Phase 4 实施时，4-dev.md prompt 可能两种实现：A) 固定跑 task-brief（即使 skip，多一次 awk 调用 0 token cost）；B) 先 check task_progress 再决定是否跑 task-brief（逻辑更紧凑但多一个分支）。两种实现都正确，但 DESIGN 未做出选择——把歧义留给了 phase 4 的实施者。影响低（awk 调用极快），但体现设计完整性 gap。

**Remedy（修补）**：DESIGN §2.2 末尾加一行：
```
注：task 在 task_progress 中已存在时，4-dev skip 派发且 skip task-brief 提取（保存一次 awk 调用）。
```
或在决策表追加 D12：task-brief skip 策略（`先 check progress 再 brief` vs `固定 brief`）。

---

### 🟢 R7 · D5/D6 terse/narration 机制在弱模型场景下的退化未被评估

**Symptom（症状）**：DESIGN §1 D5/D6 实施机制为"prompt 顶部段（grep 校验）"，代价标注为"约束靠模型自觉 + grep 兜底，非编译时强制"。DESIGN §5 R5 将此风险记录为"长期债务：D5/D6 prompt 顶部段约束靠模型自觉"，概率中。但 R5 的缓解措施引用了 ADR-001（protect-the-weakest）的"结构化自检 gate"——而 terse/narration 约束本质上不是结构性 gate（它约束的是输出格式/叙述量，不是步骤完整性），ADR-001 的 gate 填空模板模式**不直接适用**于输出风格约束。

**Source（源头）**：DESIGN §5 R5 缓解段："ADR-001 protect-the-weakest 已加结构化自检 gate"。但 ADR-001 定义的 gate 是"步骤完整性自检"（逐项 ✅/❌ 标记），与"约束输出啰嗦"是不同问题域。ADR-001 的 gate 可以检查"是否输出了 preamble"，但无法强制"叙述不超过一句"——后者是输出内容的量化约束，不是步骤 checklist。

**Consequence（后果）**：弱模型（如 deepseek-v4-pro）在违反 narration constraint 时，grep 校验（`no preamble\|verdict-first`）可以检测格式违规，但无法检测"每行都短但总行数爆炸"的啰嗦模式。最坏情况：terse contract 格式合规（grep pass）但输出依然啰嗦（token 未削减），reviewer output 的 -41% 预期从结构性担保退化为运气依赖。

**Remedy（修补）**：DESIGN §5 R5 缓解段改写：
```
缓解：D5 terse 约束——review prompt 顶部段（格式 grep 兜底）+ L2-blind-review.md 固化指令同样加 terse 约束（双重指令）
      D6 narration 约束——可靠缓解需 hook 层事后输出长度检测（v2），v1 靠 prompt 指令 + AC-C1/C2 功能性验证（bats）
```
明确 narration constraint 的 v1 缓解不是 ADR-001 gate（门不对题），而是 AC 的功能性验证。

---

**Verdict**: pass

> 共 7 项发现：0 🔴 Critical、4 🟡 Major、3 🟢 Minor。无 spec 合规失败或安全漏洞。主要关注点集中在禁动清单例外流程缺失、既有 hook 前向兼容性未评估、token 测量代理指标的有效性 gap，以及设计精度（标题/图示/风险缓解匹配）。建议在 phase 4 实施前修 R1 和 R2，phase 5 测试时针对 R3 跑参考性 token 测量辅助判断。

---

## 主 agent 响应（superpowers-v6-absorb Phase 2）

> L2 verdict=pass（0🔴），进入 phase 3。4 🟡 Major 不阻塞，但作为 phase 4 实施时的必检项登记在此。

### 🟡 Major（建议修复 · phase 4 实施时必检）

- **R1 → 留待 phase 4 实施前补充禁动例外**：DESIGN.md § 0.5.1 已写明 package-flow-kit.sh 的"Part D 需新增 scripts/ 到 cp 清单"。CONTEXT.md 禁动清单原句"Part A-E/G 禁顺手改"需在 phase 4 实施时显式登记例外："Part D 允许新增 scripts/ 文件到 cp 清单（superpowers-v6-absorb 例外）"。
- **R2 → 留待 phase 4 实施时写 hook 兼容性测试**：33-flow-active-integrity.sh 当前不校验 task_progress 字段（无此字段时返回 [] 兼容）。phase 4 实施 task_progress 写入逻辑时，bats 测试要覆盖：(a) 旧 .flow-active（无 task_progress）hook 仍正常运行；(b) 新 .flow-active（有 task_progress）hook 不误报；(c) task_progress 字段集违反 schema（如缺 id）时 hook 是否需要扩展校验（v2 留）。
- **R3 → 留待 phase 7 集成时强化因果链说明**：R8（token -25% 复现风险）的缓解"结构性 AC 作硬门槛"是必要非充分代理，因果链薄弱。phase 7-integration 时若实际复现不到 -25%，需在 CHANGELOG 中明确说明"结构性 AC 全过但端到端 token 削减未达 -25%（与 superpowers 自报/独立 benchmark 的 14-50% 区间一致）"，不视为 fail。
- **R4 → 留待 phase 4 实施时澄清命名**：D1 标题"4 轮 → 1 轮"是简称，实际模型是 1 轮合并审查 + 可选 Critical 触发 spot-check 第 2 轮。phase 4 重构 6-review.md 时，标题改为"4 轮 → 1~2 轮（合并 + Critical 触发 spot-check）"或保留简称但在段首明确定义"1 轮"="合并审查"+"spot-check"=可选第 2 轮。

### 🟢 Minor（可选改进 · 延后到 MINOR-DEFERRED.md · phase 6 创建）

- **R5/R6/R7 → Tech-debt: deferred to MINOR-DEFERRED.md**：ADR-016 探测脚本假设 / task_progress lifecycle 图细节 / D5D6 弱模型场景缓解。均为 🟢 minor，按 severity gating 契约（ADR-017）延后。

### 修复后自评

- Verdict 维持 pass（L2 已 pass，无 🔴）
- 4 🟡 全部留待 phase 4 实施时处理（必检项）
- 3 🟢 全部延后到 MINOR-DEFERRED.md
- 不修改 L2 原文
