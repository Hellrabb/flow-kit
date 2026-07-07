# 独立审查 · 阶段 2

## L2 盲审

> 审查员：独立子 agent（盲审）· 审查参数：阶段 2（设计审查）
> 审查时间：2026-07-06
> 工件：DESIGN.md（12.5K）、CHANGE.md（3.1K）、REQUIREMENT.md（6.9K）、CONTEXT.md（37.3K）
> 参考 ADR：001-protect-the-weakest（accepted）、002-l3-frontloading（proposed）

---

### 🟡 R1 · DESIGN 内部自相矛盾：0.5.1 声明"不新增文件"与 9.1 新增 checkpoint-lib.sh 直接冲突

**Symptom（症状）**：DESIGN.md 0.5.1 新增模块段写："无（auto-checkpoint 在现有架构内实现，不新增文件）"。但同一文档 9.1 新增的可复用抽象段明确列出 `~/.claude/flow-kit/hooks/stop/lib/checkpoint-lib.sh（新增）`。两份声明在同一 DESIGN 内直接矛盾。

**Source（源头）**：设计文档内部一致性原则。设计文档是实现的唯一指引——互相矛盾的指令使实现者无法确定是否应创建 checkpoint-lib.sh 文件。CONTEXT.md 禁动清单中 `hooks/stop/lib/*.sh` 被标注为"与本次无关，AI 不许顺便碰"，但若新增文件属于本次变更范畴，则 0.5.1 的声明需相应修正。

**Consequence（后果）**：实现阶段产生混乱——遵循 0.5.1 则不创建 checkpoint-lib.sh（checkpoint 写入逻辑无处安放），遵循 9.1 则创建（但与 0.5.1 无新增的声明冲突）。若 hooks/stop/lib/ 目录有基于 glob 的自动加载机制（如 source *.sh），新增文件可能引入未预期的副作用。

**Remedy（修补）**：将 0.5.1 的"新增模块"修正为如实反映本次变更，例如：
```
新增模块：
- hooks/stop/lib/checkpoint-lib.sh（auto-checkpoint 写入/去重/校验共享函数）
```
同时补充说明：该文件属于本次变更范畴，不属于禁动清单覆盖的既有 core lib 文件（correction-file.sh / l3-review.sh），不会产生 glob 自动加载副作用。

---

### 🟡 R2 · PreToolUse hook 与 ADR-002 L3 独立审查 hook 的共存未分析——两个 hook 在同一拦截点先后写 .flow-active

**Symptom（症状）**：D2 决策选定 PreToolUse hook 作为 auto-checkpoint 兜底拦截点。但 ADR-002（2026-07-03，proposed）已将 PreToolUse hook 锁定为 L3 独立审查的主路径——`independent-review-gate.sh` 在 transition jq 拦截点同步调 L3 API 并写入审查结果到 .flow-active.gates。DESIGN 未分析两个 PreToolUse hook 的执行顺序（注册顺序？同步/异步？）、各自对 .flow-active 的写入字段是否隔离（interrupt 字段 vs gates 字段），也未评估后执行者覆盖先执行者变更的风险。

**Source（源头）**：ADR-002 已锁定 PreToolUse 为 L3 审查主路径，CONTEXT.md 术语表明确 L3 前置在 "PreToolUse hook transition jq 拦截点同步执行"。两个 hook 在同一文件 (.flow-active) 上各自执行 jq read-modify-write 循环，即使采用 `.flow-active.tmp + mv` 原子写模式，也无法防止后执行者用旧快照覆盖先执行者的字段更新（lost update）。

**Consequence（后果）**：若执行顺序为 auto-checkpoint hook 先写 interrupt → L3 review hook 后写 gates，而 L3 hook 读取的是 auto-checkpoint 写入前的 .flow-active 快照，则 interrupt 字段被回滚到旧值。反之亦然。虽然 jq 原子写保证文件永不为损坏 JSON，但不保证并发/顺序写下的字段完整性。

**Remedy（修补）**：在 DESIGN 中补充 hook 执行顺序与隔离分析，至少明确以下三点之一：
1. 两个 hook 修改 .flow-active 的不同顶层字段（interrupt vs gates），且 hook 框架保证顺序执行（后者读到前者的更新），无 lost update 风险——则声明"已验证字段无交集、顺序执行保一致性"
2. 若不保证顺序，补充基于 `flock` 的文件锁或通过 checkpoint-lib.sh 统一写入路径（单一 writer 模式）消除多 writer 冲突
3. 若上述均不可行，将 auto-checkpoint 从 PreToolUse 移到 PostToolUse hook（AD 工具调用后触发，不与 L3 审查的 PreToolUse 共用拦截点）

---

### 🟡 R3 · CHANGE.md 范围约束"不新增 hook 模块"与 DESIGN 的 hook 层兜底方案未做显式调和

**Symptom（症状）**：CHANGE.md 范围排除第一条明确写"不新增 hook 模块（auto-checkpoint 在现有 prompt/hook 架构内用 jq 实现）"。REQUIREMENT.md "待 DESIGN 决议"段将此列为待解决项："若需 hook 层兜底，需评估 CHANGE.md '不新增 hook 模块' 的范围约束是否允许修改现有 hook"。DESIGN 第 1 节 D1 选定了 prompt + hook 双层方案，0.5.3 标注了"引入新模式"，但未在任何位置显式回应 CHANGE.md 的范围排除与 REQUIREMENT 的待决议项——未论证修改现有 PreToolUse hook 行为 + 新增 checkpoint-lib.sh 是否违反或需要修订 CHANGE.md 的约束。

**Source（源头）**：规格合规要求——CHANGE.md 定义 change 的边界，DESIGN 必须在给定边界内做设计；若边界需要调整，DESIGN 应明确说明理由并建议修正 CHANGE.md。

**Consequence（后果）**：若严格按 CHANGE.md 验收，任何新增 hook 文件或对现有 hook 拦截点的新行为注入都可能被视为"新增 hook 模块"，导致验收失败。更严重的是，范围漂移未记录在案，后续 change 无法追溯为何 CHANGE.md 约束被放宽。

**Remedy（修补）**：在 DESIGN 中新增一段"CHANGE.md 范围约束调和"，明确论证二选一：
1. **约束成立**：PreToolUse 修改属"现有架构内增量改造"（非新增 hook 模块），checkpoint-lib.sh 是 lib 辅助文件（非 hook 模块），不违反 CHANGE.md 约束
2. **约束需修订**：CHANGE.md 的范围排除应修正为"不新增独立 hook 模块文件（允许修改现有 PreToolUse hook 拦截逻辑 + 新增辅助 lib）"——若选此项，同步更新 CHANGE.md

---

### 🟡 R4 · 风险表遗漏：Prompt 层 auto-checkpoint 写入静默失败——恰好违背 US-3 核心动机

**Symptom（症状）**：风险表 R4 覆盖了"磁盘满/权限变更"导致写入失败，缓解指向"hook 层 stderr warn"。但 prompt 层的 auto-checkpoint（AI 执行 jq write）在写入失败时无 stderr warn 机制——AI 可能未检查 jq 返回码或忽略错误继续执行。REQUIREMENT.md 非功能性需求明确"静默失败为禁止行为"，但 prompt 层无此保证。风险表 R1 覆盖了弱模型"跳过指令"的场景，但未覆盖"执行了指令但写入失败"的场景——后者更隐蔽：AI 认为已写 checkpoint，实际未写入。

**Source（源头）**：REQUIREMENT.md 非功能性需求段："auto-checkpoint 写入失败时 MUST 保留旧值不变"、"静默失败为禁止行为"。US-3 用户故事的核心动机是"不再依赖我自己或 AI 记得手动调用 /flow checkpoint"——若 prompt 层执行了但静默失败，用户的中断恢复信任恰被破坏。

**Consequence（后果）**：弱模型最可能掉入此陷阱——执行了 prompt 中的 jq write 指令但文件系统错误（如临时目录满）导致静默失败；用户下次中断恢复时发现 interrupt 为空或为旧值，误以为 auto-checkpoint 功能未生效，从而重新依赖手动 checkpoint（US-3 失败）。

**Remedy（修补）**：在风险表中增加 R6：
```
| R6 | Prompt 层 jq write 执行但失败（非跳过）—静默丢弃 | 用户中断后无 checkpoint 可用 | 中 | PCSC 段 auto-checkpoint 指令追加"写入后 MUST 运行 `jq empty .flow-active` 校验；若失败则向用户显式报告'checkpoint write failed'，不得静默继续" |
```
同时在 hook 层去重窗口中增加"若 interrupt 字段为空或 updated_at 超过阈值，即使去重窗口内也强制执行写入"的兜底逻辑。

---

### 🟡 R5 · D4 "脚本化摘要提取"未定义具体规则——设计决策推迟到实现阶段

**Symptom（症状）**：D4 决策理由称"摘要提取用 grep/sed 脚本化减少人工重复"，但 DESIGN 全文未给出提取规则、字段映射、或验证步骤。三份文档的定位差异已在该决策的取舍代价中承认（"摘要提取不能简单复制粘贴"），但未说明在"不能简单复制粘贴"的前提下如何实现"脚本化提取"——这两个断言互相矛盾。

**Source（源头）**：设计完整性原则——声称有自动化方案但未给出规格，等于把设计决策推给实现者。已锁 docs-sync 决策（2026-06-22，CONTEXT.md）要求"每次重大 change 后同步三份文档"，但未定义"同步"的具体操作程序。

**Consequence（后果）**：实现者面临二选一：要么手写三份文档（放弃脚本化，增加后续维护成本），要么自行发明提取启发式（可能产出不连贯内容，违背 AC-1 的内容一致性要求）。

**Remedy（修补）**：在 D4 决策后补充具体映射规则，例如：
```
文档提取映射：
- 用户指南"命令参考"段 → README "Quick Start"（仅保留最常用 5 条 + 参数列表）
- 用户指南"功能列表"段 → ecosystem-guide "组件清单"（按组件类型归类）
- 用户指南"中断恢复流程" → ecosystem-guide "状态管理"段（保留架构图）
```
或降级声明为："本次手工同步三份文档，脚本化提取方案留 v2（待 docs-sync 策略更新）"。

---

### 🟢 R6 · ADR 索引声明"无不可逆架构决策"与 9.2/9.3 实际新增的跨模块契约略有出入

**Symptom（症状）**：第 4 节声明"本次无不可逆架构决策（auto-checkpoint 为增量功能，不改变现有架构），不新增 ADR"。但 9.2 定义了两项项目级技术决策（双层防护、30s 去重窗口），9.3 定义了三项跨模块契约（.flow-active.interrupt 字段格式、checkpoint_write 函数签名、手动/自动共用写入路径），9.5 新增了禁动清单条目。这些一旦部署且有多处调用方依赖，反向修改成本显著上升——具备"软不可逆"特征。

**Source（源头）**：架构决策记录（ADR）的职责——任何影响跨模块契约、未来修改需同步多处的设计选择值得被记录，即使非"颠覆性架构重构"。CONTEXT.md 已锁决策清单中类似粒度的决策（如 gate_config 快照一致性策略、L3 同步调用策略）均有 ADR 或已锁决策条目。

**Consequence（后果）**：未来开发者修改 checkpoint 字段格式或去重策略时，可能未意识到这些是"被多处依赖的契约"而非"局部实现细节"，导致破坏性变更不被追踪。

**Remedy（修补）**：将 9.2 表格中的两条决策升级为轻量 ADR 记录（如 ADR-003-checkpoint-contract），至少含：字段格式定义、去重策略、所有读取/写入该字段的组件清单、推翻代价评估。或将第 4 节措辞从"无不可逆架构决策"调整为"本次无颠覆性架构重构，但新增需维护的软契约（详见 9.2/9.3/9.5）"。

---

**Verdict**: pass

> 本次审查在 DESIGN.md 中发现 5 个 🟡 Major 和 1 个 🟢 Minor 问题。无 🔴 Critical（数据损坏/安全漏洞/AC 未实现/spec 合规失败）。
> 核心关切集中在三处：(1) PreToolUse hook 与 ADR-002 L3 审查的共存分析缺失——这是 L3 外部审查也独立指出的问题；(2) DESIGN 内部自相矛盾（0.5.1 vs 9.1）；(3) CHANGE.md 范围约束与 hook 层兜底方案的调和未完成——REQUIREMENT 明确要求 DESIGN 回应此项。此外 prompt 层写入静默失败的风险在当前风险表中覆盖不完整，需要补充。
> 建议在进入 4-dev 前修复 R1-R5，R6 可在实现中顺带处理。

---

## L3 盲审（deepseek-v4-flash[1m] 外部模型 · 2026-07-06 16:02）

> 自动生成于 2026-07-06 16:02。由 l3-review.sh 写入。

### 审查结论

```json
{
  "critical": [],
  "major": [
    {
      "file": "DESIGN.md",
      "issue": "未分析 PreToolUse hook 与已存在的 L3 独立审查 hook（ADR-002）的共存冲突",
      "why": "设计 D2 选定 PreToolUse hook 作为自动 checkpoint 兜底，但既有 ADR-002 的 L3 审查也采用同一 PreToolUse 拦截点。两个 hook 的执行顺序、对同一工具调用的影响、以及可能的资源竞争（如同时写 .flow-active）均未评估。工件中仅提及“与 L3 front-loading 的 PreToolUse 策略一致”，但未给出共存保证或优先级设计。",
      "fix": "补充 hook 执行顺序说明（如注册顺序、冲突避免机制）或修改为不同触发点（如 PostToolUse）。"
    },
    {
      "file": "DESIGN.md",
      "issue": "风险段遗漏关键风险：多个 PreToolUse hook 触发顺序导致状态不一致",
      "why": "在 transition 或工具调用时，L3 审查 hook 和 auto-checkpoint hook 可能同时运行。若 L3 审查修改了 .flow-active（如写入评审结果），auto-checkpoint 随后写入可能导致旧数据被覆盖，或 L3 依赖的字段被篡改。工件 R1-R5 未提及此风险。",
      "fix": "在风险表中增加 R6：L3+auto-checkpoint hook 并发写 .flow-active 的时序风险，并给出缓解措施，如统一通过 checkpoint-lib.sh 的独占锁（flock）写入，或规定 L3 不写 .flow-active。"
    }
  ],
  "minor": [
    {
      "file": "DESIGN.md",
      "issue": "ADR 索引声明“本次无不可逆架构决策”，但新增了跨模块契约及禁动清单，隐含一定不可逆性",
      "why": "工件 9.3 新增了 .flow-active.interrupt 字段格式契约和 checkpoint_write 函数签名，9.5 新增禁动清单。这些变更一旦部署，后续改动需同时更新所有调用方，具备不可逆性。声明与内容有轻微矛盾，但不影响功能正确。",
      "fix": "调整描述为“本次无颠覆性架构重构，但新增了需维护的接口契约”。"
    },
    {
      "file": "DESIGN.md",
      "issue": "D4 文档更新策略的“摘要提取”未定义具体脚本化方法，可能引入人工错误",
      "why": "决策描述采用“grep/sed 脚本化”，但未提供示例或验证步骤。三份文档侧重点不同（用户指南=操作手册，README=速览，ecosystem=架构清单），简单摘录可能丢失重要信息或生成不连贯内容。",
      "fix": "补充摘要提取的规则或模板，或明确此处仅借用手工同步，文档同步策略已锁定（2026-06-22）但未在工件中展开。"
    }
  ],
  "verdict": "pass",
  "summary": "设计整体合理，决策理由充分，风险覆盖基本全面；但遗漏了 PreToolUse hook 与既有 L3 hook 的共存冲突及并发写风险，这两项为 major 问题，需在实现前补充分析或调整触发点。"
}
```
