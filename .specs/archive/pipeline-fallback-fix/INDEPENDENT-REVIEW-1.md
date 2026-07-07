# 独立审查 · 阶段 1

## L2 盲审

> 审查员：独立盲审 L2 agent（第二次审查，替换旧版）
> 审查对象：`.specs/pipeline-fallback-fix/REQUIREMENT.md`（参考 `CHANGE.md`）
> 审查日期：2026-07-03
> 备注：上一版 L2 审查（备份于 INDEPENDENT-REVIEW-1.md.bak）针对的是旧版 REQUIREMENT.md（AC 编号与内容与当前版本完全不同）。本审查是独立盲审，不参考旧版结论。

---

### 🔴 R1 · AC-4/AC-5 的 PCSC 产物清单缺失：v1 无法判定 "PCSC 全 ✅"

**Symptom（症状）**：
- AC-4（REQUIREMENT.md:96）前置条件为 "阶段 4 的 PCSC 全部 ✅（产物均在磁盘）"
- AC-5（REQUIREMENT.md:121）前置条件为 "phase 7 PCSC 全 ✅"
- 但 REQUIREMENT.md 全文中**没有任何地方定义**每个阶段的"产物清单"——哪些文件构成"全 ✅"。
- v2 范围（REQUIREMENT.md:212）更写明 "auto_advance hook 的 PCSC 自检自动化（hook 自己 grep PCSC 段判断全 ✅，而非依赖 transcript 解析）" 属于 v2，即 v1 连 PCSC 自动检测机制本身都未定稿。

**Source（源头）**：
- 验收准则可测试性原则：AC 的前置条件必须可判定。如果判定 PCSC 完备性所需的数据结构（产物清单）未在规格中定义，则 AC-4 和 AC-5 的 Given 子句不可判定，AC 不可测。
- 对比：AC-7（REQUIREMENT.md:157-168）定义了 `.done` 文件的 6 键结构，使 AC-7/AC-7a/AC-8/AC-8a 均可验证。PCSC 完备判定需要同等规格。

**Consequence（后果）**：
- AC-4 的 hook 实现者无法确定应检查哪些文件的存在性。是检查 `.specs/<id>/SUMMARY.md`？是所有阶段的产物文件列表？不同的实现者可能做出不同判断，导致 hook 行为不一致。
- AC-5 同理：fallback-guard hook 不知道"pipeline 完成"的判定标准。
- 更严重的是：AC-4a（"PCSC 不全时 hook 不自动 transition"）的验证依赖于知道什么是"全"——但如果"全"本身未定义，验证者无法构造"不全"的测试场景，只能猜。

**Remedy（修补）**：
1. 在 REQUIREMENT.md 中新增一条 AC（或追加到"依赖与假设"段），定义各阶段的产物清单来源：

```markdown
### AC-PCSC · 阶段产物清单定义

- **Given** pipeline 定义了各阶段的 PCSC（Phase Completion Success Criteria）
- **When** hook 需要判定某阶段的产物是否齐全
- **Then** hook 从以下来源之一获取产物清单（按优先级）：
  a) `.specs/<id>/DESIGN.md` 中该阶段的 "Deliverables" 段所列文件列表
  b) 若 DESIGN.md 无定义，则从 `~/.claude/flow-kit/prompts/<N>-<phase>.md` 的 PCSC 段解析产物文件名
- **验证方式**: 对每个阶段 N，`grep -oP '产物文件名模式'` 能提取到非空文件列表
```

2. 或在 v1 范围中明确声明：v1 的 PCSC 判定使用**硬编码产物清单**（列在 hook 模块内部），并附上每个阶段的产物示例列表。

---

### 🔴 R2 · AC-1 "握手文件" 术语未定义：与 AC-7 .done 文件规格的关系不明

**Symptom（症状）**：
- AC-1（REQUIREMENT.md:23）Then 子句："L3 结果写入 `INDEPENDENT-REVIEW-<N>.md` 的 L3 段 + **写握手文件**"
- AC-7（REQUIREMENT.md:157-168）定义了 `.independent-review-<N>.done` 的 6 键结构，包括 `phase`、`change_id`、`written_by`、`L2_verdict`、`L3_verdict`、`artifacts`。
- 但 "握手文件" 和 ".done 文件" 这两个术语之间的关系**从未在任何地方显式等价声明**。AC-7 从未自称 "握手文件"；AC-1 从未指明 "握手文件" 的命名规范。

**Source（源头）**：
- 规格一致性原则：同一概念在整份文档中应使用同一术语。两个术语指代同一实体却没有互引用，是规格内部不一致。
- CHANGE.md:49 在 P2-1 描述中使用了 "`.done` 必填字段统一为 6 键"——这暗示 `.done` 文件即握手文件。但 REQUIREMENT.md 作为独立可读的规格文档，不应依赖 CHANGE.md 来消歧。

**Consequence（后果）**：
- 实现者阅读 AC-1 的 Then 时，可能理解为"创建一个新文件作为握手标记"（如 `HANDSHAKE` 或 `.l3-complete`），而不是写入 `.independent-review-<N>.done`。
- 如果实现者创建了独立的握手文件但未更新 `.done`，则 gate 后续检查（依赖 `.done` 的 `L3_verdict=` 字段）将失败——尽管 L3 实际已执行。
- AC-1 的验证方式（"`INDEPENDENT-REVIEW-<N>.md` 含 L3 段"）只覆盖了 review 文件的写入，未覆盖握手文件的写入验证，使握手文件成为一个被规格引用但从未被验证的概念。

**Remedy（修补）**：
在 AC-1 的 Then 或其后追加一句显式定义：

```markdown
- **Then** ... L3 结果写入 `INDEPENDENT-REVIEW-<N>.md` 的 L3 段，随后写入握手文件
  `.independent-review-<N>.done`（即 AC-7 定义的 6 键 done 标记文件，其中 `written_by=pre-tool-use-gate`，`L3_verdict=<结果>`）。
```

同时在 AC-7 首行追加："本 AC 定义的 `.done` 文件即各 gate 流程（AC-1 / AC-1b / AC-3）中引用的握手文件。"

---

### 🟡 R3 · AC-1c 混淆实现细节与行为需求：文件路径出现在验收准则中

**Symptom（症状）**：
- AC-1c（REQUIREMENT.md:40-45）Then 子句："L3 API 调用逻辑...抽取为 `hooks/stop/lib/l3-review.sh` 共享函数，两处调用同一函数"
- 该 AC 规定了具体的文件路径（`hooks/stop/lib/l3-review.sh`）和代码组织方式（"抽取为共享函数"），而非可观测的行为。

**Source（源头）**：
- 需求工程分层原则：验收准则（AC）应描述系统**做什么**（行为），而非**怎么做**（设计）。文件路径和代码组织属于 DESIGN.md 的职责，不应作为 AC。
- 对比：AC-1、AC-1a、AC-1b 均描述了可观测的 hook 行为（拦截/超时/补跑），符合 AC 标准。AC-1c 是异类——它描述的是内部重构。

**Consequence（后果）**：
- 如果后续 DESIGN.md 发现更好的代码组织方式（如 `hooks/shared/l3-review.sh` 或内联到 `flow-kit-artifacts.sh`），则 AC-1c 会形成约束："可以改，但要改 AC"——但路径选择本应是设计决策，不应被 AC 锁定。
- 验证方式（`grep -l "source.*l3-review.sh"`）只检查了文件引用关系存在，无法验证代码去重的实际效果（两个调用点是否真的共享同一逻辑、还是分别实现了重复逻辑）。

**Remedy（修补）**：
将 AC-1c 重写为行为语义，将具体路径下沉到 DESIGN.md：

```markdown
### AC-1c · L3 API 调用逻辑不重复

- **Given** `independent-review-gate.sh` 和 `29-independent-review.sh` 都需要调 L3 API
- **When** 任意一处的 L3 API 调用逻辑需要修改
- **Then** 仅需修改一处即可同时影响两处的调用行为（即两处共享同一实现）
- **验证方式**: 修改共享实现中的超时值（如 30s → 15s）→ 确认两处调用的超时行为均变为 15s
```

---

### 🟡 R4 · AC-2b Then "不放行也不拦截" 措辞矛盾

**Symptom（症状）**：
- AC-2b（REQUIREMENT.md:67-70）Then 子句："hook 检测一致 → **不放行也不拦截**（检查通过，允许后续操作）"
- 在一个 gate/bouncer 语义框架中，"不放行" = "拒绝"，"不拦截" = "允许"。"不放行也不拦截" 是一个自相矛盾的表述——这两个词在 gate 语境下是互斥的。
- 括号中的补充（"检查通过，允许后续操作"）表明实际意图是**放行**。但主 Then 文本的措辞给出了相反的信号。

**Source（源头）**：
- 规格清晰性原则：AC 的 Then 子句必须无歧义，使得测试者可以不依赖括号补充就能确定预期行为。
- gate/bouncer hook 的标准行为模式：exit 0 = 放行，exit 1 = 拦截。AC-2b 未声明预期 exit code，也未说明 hook 是"静默通过"还是"输出通过消息"。

**Consequence（后果）**：
- 实现者可能将 "不放行也不拦截" 理解为 hook 对该操作执行 no-op（既不返回 0 也不返回 1，或简单跳过）。如果 hook 的默认行为是拦截，而此处应放行，则实现错误会导致合法操作被误拦。
- 测试者无法确定验证方式中 "hook 不输出篡改拦截消息" 是否充分——如果 hook 输出其他类型的拒绝消息（非"篡改"相关）算不算通过？

**Remedy（修补）**：
将 Then 重写为确定性的 gate 行为描述：

```markdown
- **Then** hook 检测一致 → 放行操作（exit 0），不输出任何拦截或警告消息
```

---

### 🟡 R5 · 非功能性需求缺失容量/可靠性维度

**Symptom（症状）**：
- NFR 段（REQUIREMENT.md:225-231）覆盖了性能（30s 超时、<100ms 延迟）、兼容性、安全、可观测性、代码质量。
- 但以下维度完全缺失：
  - **容量**：`.flow-active` 的最大大小？`.goal-snapshot.json` 的字段数量上限？单次 session 内最多触发多少次 L3 调用？
  - **可靠性**：hook 操作的幂等性要求（同一 transition jq 被重复拦截/放行时行为是否一致）？L3 调用失败后的重试策略（仅超时一次还是可重试）？部分写入（`.done` 文件写到一半时 crash）的恢复行为？
  - **并发**：多个 session 同时操作同一 change 的 `.flow-active` 时，hook 行为是否安全？Stop hook 与 PreToolUse hook 同时触发时是否存在竞态？

**Source（源头）**：
- 质量属性规格完整性：对于涉及文件写入、外部 API 调用、多 hook 模块协作的系统变更，容量/可靠性/并发是必须评估的非功能维度。
- CHANGE.md:77-82 风险段提到了 L3 API 延迟和超时，但未提及并发竞态或部分写入风险。NFR 段作为风险的正式规格化，应覆盖所有已知风险类别。

**Consequence（后果）**：
- 多 session 并发场景（用户在两个终端同时操作同一 change）可能导致 `.done` 文件损坏或 `.goal-snapshot.json` 不一致——当前规格未定义此场景下的预期行为。
- L3 调用失败后没有重试策略规定：实现者可能选择永不重试（丢失审查覆盖）或无限重试（阻塞 pipeline），两种极端都不可接受。

**Remedy（修补）**：
在 NFR 段追加：

```markdown
- **可靠性**: L3 API 调用单次失败后不重试（直接降级为 timeout）；`.done` 文件写入使用原子操作（先写临时文件再 `mv`）；hook 模块间无共享可变状态
- **并发**: 同一 change 在同一时刻仅允许一个 session 处于 active 状态（`.flow-active` 文件锁）；若检测到多 session 并发，后启动的 session 应警告并建议等待
- **容量**: `.flow-active` 文件 < 100KB；`.goal-snapshot.json` < 50KB；单次 session 的 L3 调用次数 ≤ 阶段数（7 次）
```

---

### 🟡 R6 · AC-3 未覆盖 no-op transition（target == current_phase）

**Symptom（症状）**：
- AC-3（REQUIREMENT.md:76-81）覆盖回退：`current_phase = "5"` 从 6 退到 5 → 放行。
- AC-3a（REQUIREMENT.md:83-88）覆盖前进：目标 phase 7 > 当前 6 → 拦截（要求 .done）。
- 但 **target == current_phase**（no-op transition jq，如 `current_phase = "6"` 不变但附带其他字段修改）的场景未被任何 AC 覆盖。`is_phase_write` 对这种 jq 的行为是未定义的。

**Source（源头）**：
- 边界值分析（BVA）：当比较逻辑涉及 `<` 和 `>` 时，`=` 是必须覆盖的第三边界。AC-3 覆盖了 `<`（回退），AC-3a 覆盖了 `>`（前进），`=` 留白。
- 实际风险：主 agent 可能执行非推进性 jq（如仅更新 `gates` 字段而不改 `current_phase`），这种 jq 目前不在任何 gate 规则的覆盖范围内。

**Consequence（后果）**：
- 如果实现者将 no-op transition 归类为"前进"（要求 .done），则合法的状态维护操作会被拦截。
- 如果归类为"回退"（放行），则攻击者可通过 no-op jq 绕过 gate（先写 `current_phase = "6"` 不变，附带修改其他 gate 相关字段）。
- 无论哪种归类，缺乏明确的 AC 意味着行为是未指定的，由实现者自行决定——这是规格漏洞。

**Remedy（修补）**：
新增一条 AC：

```markdown
### AC-3b · No-op transition（target == current_phase）行为

- **Given** `gate_config["6-review"] = "independent"`，`.independent-review-6.done` 不存在，`current_phase = "6"`
- **When** 主 agent 执行 no-op transition jq（`current_phase = "6"` 不变，但修改其他字段如 `gates` 或 `phases_done`）
- **Then** `independent-review-gate.sh` 的 `is_phase_write` 检测到目标 phase (6) == 当前 phase (6) → 判定为**状态维护操作** → 放行（不要求 .done），但仅允许修改 `gates`/`phases_done` 等非前进性字段，若检测到除 `current_phase` 外还修改了判定为前进的字段组合则拦截
- **验证方式**: 执行 no-op jq（不改 current_phase，只改 gates）→ hook 放行 → jq 成功；执行伪装 no-op jq（current_phase 不变但 phases_done 增加了新阶段）→ hook 拦截
```

> 注：若 v1 范围不接受此复杂度，替代方案是在文档中显式声明 "no-op transition 按前进处理（要求 .done）" 并给出一条 AC 覆盖。重点是**有明确的行为定义**，而非留白。

---

### 🟢 R7 · AC-4 的 When "会话正常结束" 触发边界模糊

**Symptom（症状）**：
- AC-4（REQUIREMENT.md:98）When："会话正常结束（Stop hook 触发）"
- AC-1b（REQUIREMENT.md:36）Given："session 在 transition 前异常终止（PreToolUse hook 未触发 L3）"
- "正常结束" 和 "异常终止" 的边界未被定义。Stop hook 是否在**所有**会话终止路径上触发？如果用户 `Ctrl+C` 中断，Stop hook 是否执行？如果进程被 `kill -9` 呢？

**Source（源头）**：
- 生命周期规格完整性：hook 的触发可靠性依赖于 CC 平台的 Stop hook 语义。如果 CC 平台在某些终止路径上不触发 Stop hook，则 AC-4 和 AC-1b 的兜底逻辑都不会执行——pipeline 将静默停滞。

**Consequence（后果）**：
- 如果 CC 平台在 SIGTERM 下触发 Stop hook 但在 SIGKILL 下不触发，则 `kill -9` 中断的 session 既不触发 auto_advance（AC-4）也不触发 L3 补跑（AC-1b）。这两种情况都导致 pipeline 卡住。
- 由于没有 AC 定义 "正常结束" 的精确边界，测试者无法构造边界测试用例。

**Remedy（修补）**：
在"依赖与假设"段追加：

```markdown
- **Stop hook 触发语义假设**: CC 平台在以下会话终止场景下均触发 Stop hook：
  a) 主 agent 自然结束（发送最终响应后）
  b) 用户 `/exit` 或 `exit` 指令
  c) 用户 `Ctrl+C`（SIGINT）→ CC 发送 SIGTERM 后触发 Stop hook
  Stop hook **不保证**在 SIGKILL（`kill -9`）或 OS 崩溃后触发，这些场景下的 pipeline 断点恢复依赖用户手动 intervention。
```

---

### 🟢 R8 · US-4 的 fallback 兜底范围与 v1 覆盖不对称

**Symptom（症状）**：
- US-4（REQUIREMENT.md:13）描述："我想 `mode=fallback` 有 hook 层兜底...以便弱模型下机制仍可靠"
- 但 v1 中唯一覆盖 fallback 兜底的 AC-5（REQUIREMENT.md:119-124）仅覆盖了 `mode=fallback` + `scope=pipeline` + `current_phase=7` 的场景（标记 done）。
- fallback 模式的**其他推进阶段**（phase 4/5/6 的迭代循环）的兜底完全依赖 GO.md 路由（P1-3）——即 prompt 驱动。如果弱模型忽略了 GO.md 中的 fallback 路由指令，phase 4-6 的 fallback 迭代同样会卡住，但没有任何 hook 兜底这部分的推进。

**Source（源头）**：
- US-4 的意图是 "不仅靠 prompt 驱动"，但 AC-5 只覆盖了终点（phase 7 完成标记），中间阶段（4→5→6→7 推进）仍完全依赖 GO.md prompt 路由。
- CHANGE.md F5（REQUIREMENT.md:20）描述为 "Fallback 纯 prompt 驱动"，但 v1 修复仅加了终点兜底，中间推进路径仍然是纯 prompt 驱动。

**Consequence（后果）**：
- 弱模型在 fallback 模式下可能在 phase 4 迭代循环中卡住（未遵循 GO.md 的 fallback 路由指令），但由于 phase 4 不是 endpoint，AC-5 的 fallback-guard hook 不会触发。
- US-4 声称解决的问题（"弱模型下机制仍可靠"）仅在 phase 7 终点成立，在 pipeline 中间阶段不成立。这是一种**部分覆盖**——US 的需求 > AC 的覆盖范围。

**Remedy（修补）**：
1. 若 v1 范围不允许为 phase 4/5/6 各加 fallback 推进 hook，则应在 US-4 或 AC-5 处明确注明覆盖边界：

```markdown
> **覆盖边界**: v1 的 fallback hook 兜底仅覆盖 pipeline 终点（phase 7 → done 标记）。
> phase 4→5→6→7 的 fallback 推进仍依赖 GO.md prompt 路由（P1-3）。
> 若弱模型在中间阶段卡住，用户需手动 intervention。全阶段 fallback hook 推进留待 v2。
```

2. 或在 v2 中追加 "fallback 模式中间阶段自动推进 hook（34-fallback-advance.sh）"。

---

## 总评

**Verdict**: fail

**理由**：存在 2 个 🔴 Critical 问题：
- **R1**（PCSC 产物清单缺失）使 AC-4 和 AC-5 的 Given 前置条件无法在 v1 中判定，直接导致这两个 AC 不可测试、不可实现。这是 spec 合规缺陷，因为 REQUIREMENT.md 交给了实现者一个无法回答的问题："怎样才算 PCSC 全 ✅？"
- **R2**（"握手文件" 术语未定义）使 AC-1 与 AC-7 之间存在隐式依赖，可能导致实现者将握手文件和 .done 文件视为两个独立实体，产生写入不一致的 bug。这是规格内部一致性缺陷。

4 个 🟡 Major 问题（R3: AC-1c 实现细节泄露、R4: AC-2b 措辞矛盾、R5: NFR 容量/可靠性缺失、R6: no-op transition 留白）和 2 个 🟢 Minor 问题构成第二梯队关注点。

所有问题均为**增量修复**（追加 AC、重写措辞、补充定义），不推翻现有架构。建议采纳修补后重新审查。
