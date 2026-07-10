# 独立审查 · 阶段 1

## L2 盲审

独立审查员：L2（haiku 模型 · 本地 runner）  
审查工件：`.specs/fix-l3-gate/REQUIREMENT.md`（参考 `.specs/fix-l3-gate/CHANGE.md`）  
审查阶段：阶段 1 · 需求审查  
审查日期：2026-07-10

---

### 🔴 R1 · L3 重审时间戳存储位置未定义：AC-1 不可实现
**Symptom（症状）**：REQUIREMENT.md AC-1 的 When 子句写"使其 mtime 晚于上次 L3 审查时间戳"，但全文（含依赖与假设段、CHANGE.md 影响面段）均未指定"上次 L3 审查时间戳"的存储位置和读取方式。是存在 `.independent-review-N.done` 的某个键值里？是 `INDEPENDENT-REVIEW-N.md` 里 L3 段落的文件 mtime？还是需要一个独立的 `.l3-timestamp-N` 元数据文件？
**Source（源头）**：AC 规范要求 Given/When/Then 可验证、可实施。缺失关键数据流（时间戳读写路径）意味着开发者无法从 AC 直接推导实现——不同实现者会选择不同存储策略，导致行为不一致。
**Consequence（后果）**：实现阶段必然产生歧义——开发者 A 认为读 .done 文件的 mtime，开发者 B 认为读 review markdown 的段内时间戳，开发者 C 认为需要新增元数据文件。三种策略对"是否需要重审"的判断结果可能不同（尤其在文件被 touch 但内容未变的边界情况）。这将引入回归风险或导致 L3 重审触发条件出现漏检/误检。
**Remedy（修补）**：在 REQUIREMENT.md 或 CHANGE.md 中明确指定：
- 时间戳来源（建议：`stat -c %Y .specs/<change-id>/INDEPENDENT-REVIEW-N.md` 即 review 文件自身的 mtime，因为每次 L3 审查都会 append 内容，mtime 自然更新）
- 或者显式新增键到 `.independent-review-N.done`，如 `L3_last_review_ts=<epoch>`

示例追加到 AC-1：
```
- **Given** 阶段 N 已完成一次 L3 审查，verdict=fail，`INDEPENDENT-REVIEW-N.md` 存在
  且 `L3_REVIEW_MTIME=$(stat -c %Y .specs/<id>/INDEPENDENT-REVIEW-N.md)` 已记录
- **When** 工件文件 mtime > `L3_REVIEW_MTIME`
- **Then** l3-review.sh 执行重审并追加 `## L3 重审` 段（追加动作本身更新 INDEPENDENT-REVIEW-N.md 的 mtime，形成自然防重入）
```

---

### 🟡 R2 · AC-4 "原子更新"声明与 jq 实现能力不匹配
**Symptom（症状）**：REQUIREMENT.md AC-4 标题写"transition jq 四字段原子更新"，Then 子句写"四个字段同时更新为一致值"。但 jq 对文件的写操作是 read-modify-write 模式：`jq '...' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active` 可以实现接近原子性，但 `jq '...' .flow-active` 直接重定向回原文件（`jq ... .flow-active > .flow-active`）是非原子的——可能在写入中途被其他进程读取到半截文件。
**Source（源头）**：POSIX 文件系统语义：对同一文件的 `>` 重定向会先 truncate 再写入，reader 可在 truncate 后、写入完成前读到空文件/部分文件。`mv`（同一文件系统内）是 rename(2) 系统调用，是原子操作。
**Consequence（后果）**：若现有的 transition jq 实现使用 `jq ... .flow-active > .flow-active` 而非 tempfile+mv 模式，并发读取（如并行 hook）可能读到损坏的 `.flow-active`，导致 pipeline 状态解析错误或 phase 判断异常。风险在并发 hook 场景下会实际触发。
**Remedy（修补）**：在 AC-4 验证方式中追加原子性验证步骤，或在依赖与假设段注明原子性要求：
```
- **验证方式**: transition 后执行 `jq ... .flow-active` 四个值一致 ...
  另：确认 transition jq 使用 tempfile+mv 模式（`jq ... .flow-active > .tmp && mv .tmp .flow-active`）
  或 `sponge`（moreutils），禁止直接 `jq ... file > file`
```

---

### 🟡 R3 · AC-2 pipeline 暂停的反馈机制未指定
**Symptom（症状）**：REQUIREMENT.md AC-2 Then 子句写"pipeline 暂停等待用户处理"，但未指定暂停的具体形式——是返回非零 exit code？是打印特定消息？是设置某个状态标记？开发者无法从 AC 判断"gate 正确 deny"和"脚本崩溃"的区别。
**Source（源头）**：可验证 AC 要求 Then 子句的产出可被脚本检测。若"暂停"的机制（exit code / stdout 消息 / 状态文件）未定义，验证脚本无法区分"gate 正确拦截"与"gate 异常退出"。
**Consequence（后果）**：测试阶段可能写出误报的验证脚本——例如仅检查 exit code != 0 即判定"gate 正确 deny"，但实际可能是脚本语法错误。或者，用户看到无声的 exit code 1 而不知道是 L3 fail 导致的预期拦截还是 bug。
**Remedy（修补）**：在 AC-2 Then 子句补充：
```
- **Then** gate 拒绝 transition：exit code = 2（预留：0=放行，1=脚本错误，2=gate 拦截），
  stdout 含 `GATE_DENY: L3 verdict=fail, manual intervention required`，
  不创建 `.independent-review-N.done`
```
验证方式同步更新为同时检查 exit code 和 stdout 消息。

---

### 🟢 R4 · 阶段 0 和阶段 4 排除于 L3 重审范围，未说明理由
**Symptom（症状）**：REQUIREMENT.md AC-1 Given 子句限定阶段范围为"1/2/3/5/6/7"，排除了阶段 0 和阶段 4。CHANGE.md 描述异常发生在 1-requirement 和 2-design 阶段，但未解释为什么修复只覆盖这些阶段而排除 0 和 4。如果阶段 4（test）也有独立审查（L3），为什么不受益于此修复？
**Source（源头）**：范围排除应有明确理由——要么这些阶段根本不触发 L3 审查（则无需修复），要么这些阶段的审查机制不同（则需注明差异）。
**Consequence（后果）**：低风险。若阶段 0 和阶段 4 确实不触发 L3，则本 AC 准确。但若未来阶段 4 也引入 L3 审查，遗漏可能导致同样的死结问题复发。
**Remedy（修补）**：在 REQUIREMENT.md 范围切分或依赖与假设段加一行解释：
```
- 阶段 0（上下文分析）不触发独立审查，阶段 4（测试/实现）当前无 L3 审查，
  故 AC-1 范围仅覆盖有 L3 的阶段 1/2/3/5/6/7
```
或确认这是有意设计决策并在 CHANGE.md 范围排除段注明。

---

### 🟢 R5 · 缺少错误处理相关的非功能性需求
**Symptom（症状）**：REQUIREMENT.md 非功能性需求段覆盖了性能、安全、兼容性、可观测性，但缺失：L3 API 不可达时的降级行为（当前仅 v2 提到 timeout 降级，v1 无定义）；工件 mtime 检测失败时的默认行为；重审段追加写入失败时的恢复策略。
**Source（源头）**：防御性需求工程原则——每个外部依赖（L3 API、文件系统）的故障模式都应有明确的 fallback 行为定义，否则实现者会在异常路径上作出不可预测的选择。
**Consequence（后果）**：L3 API 临时不可达时，`l3-review.sh` 是静默跳过（等同于 pass？）还是报错阻塞（等同于 fail？）——当前未定义。若实现者选择静默跳过，可能产生安全漏洞（L3 实际未审查但标记为已处理）；若选择报错阻塞，可能在网络抖动时造成不必要的 pipeline 停滞。
**Remedy（修补）**：在 REQUIREMENT.md 非功能性需求段追加：
```
- **容错**: L3 API 不可达（网络超时/HTTP 5xx）时，保留上一次 L3 verdict 不变，
  不追加新 L3 段，在 hook log 中记录 `[L3-REVIEW] API unreachable, keeping previous verdict`，
  .done 写入逻辑保持一致（上次 fail 则继续 deny，上次 pass 则继续 allow）。
  mtime stat 失败时视为"工件未变更"，跳过重审。
```
或确认 v1 沿用已有的 30s timeout → verdict=timeout 降级逻辑（若 CHANGE.md 中提到的该逻辑已存在于当前代码）。

---

### 🟢 R6 · AC 验证方式描述偏重单元检测，缺少集成场景
**Symptom（症状）**：所有 5 条 AC 的验证方式均为单点检测（grep 某文件、test -f 某文件、jq 某字段），缺少端到端场景验证。例如 AC-1+AC-2+AC-3 的联动——L3 fail → 用户修工件 → L3 重审 pass → gate 放行——这一完整闭环没有被 AC 覆盖。
**Source（源头）**：验收准则应覆盖关键用户旅程（US-1 + US-2 + US-3 的组合场景），而非仅覆盖孤立的技术验证点。孤立通过 ≠ 组合通过。
**Consequence（后果）**：可能存在"每条 AC 独立测试通过但组合后行为异常"的集成缺陷。例如 AC-1 的重审段追加成功但 AC-3 的 gate 读不到更新的 verdict（因为读的路径/timestamp 不一致），这种跨 AC 的数据流断裂不会被当前验证方式发现。
**Remedy（修补）**：建议增加一条集成 AC（AC-6）：
```
### AC-6 · 完整重审闭环
- **Given** 阶段 1 L3 fail，`.independent-review-1.done` 不存在
- **When** 修改 REQUIREMENT.md（touch）、触发 Stop hook → L3 重审 → verdict=pass →
  用户再次执行 transition → PreToolUse gate 检测 L3 pass → 写入 .done
- **Then** `.independent-review-1.done` 存在且 `grep "L3_verdict=pass"` 成功，
  transition 成功推进到阶段 2
- **验证方式**: 完整脚本模拟 touch → hook → transition 全流程
```
这是非强制建议（🟢 级别），不修改不会导致 AC 不完整，但对测试阶段设计集成测试有指导价值。

---

### 审查总结

| AC | Given/When/Then | 可机器验证 | 无歧义 | 判定 |
|----|-----------------|-----------|--------|------|
| AC-1 | 三段齐全 | 是 | **否** — 时间戳来源未定义 | 🔴 |
| AC-2 | 三段齐全 | 是 | 是（pipeline暂停机制轻微不足） | 🟡 |
| AC-3 | 三段齐全 | 是 | 是 | ✅ |
| AC-4 | 三段齐全 | 是 | 是（"原子"术语轻微夸大） | 🟡 |
| AC-5 | 三段齐全 | 是 | 是 | ✅ |

范围切分合理，v1/v2/out 边界清晰。非功能性需求覆盖面 5/7（缺错误处理、并发/可靠性）。无 AC 间矛盾，无需求间逻辑冲突。

**Verdict**: fail

> 理由：R1（🔴 Critical）——AC-1 的 L3 重审时间戳存储位置未定义，直接导致 AC 不可实现。需补充时间戳来源规范后方可放行至设计阶段。

---

## L2 盲审 · 第二轮

独立审查员：L2  
审查工件：`.specs/fix-l3-gate/REQUIREMENT.md`（参考 `.specs/fix-l3-gate/CHANGE.md`）  
审查阶段：阶段 1 · 需求审查（第二轮——验证 R1 修复 + 检查修复引入的新问题）  
审查日期：2026-07-10

---

### 上一轮发现复核

| 发现 | 严重度 | 状态 | 说明 |
|------|--------|------|------|
| R1 · L3 重审时间戳来源 | 🔴 | **已解决** | AC-1 Given 明确 `L3_REVIEW_MTIME=$(stat -c %Y ...)`，Then 解释追加更新 mtime 的自然防重入 |
| R2 · AC-4 原子性声明 | 🟡 | **已解决** | AC-4 标题改为"四字段一致"，When 明确 tempfile+mv 模式，验证方式追加原子性检查 |
| R3 · AC-2 pipeline 暂停反馈 | 🟡 | **已解决** | Then 明确 exit code=2 + `GATE_DENY` 消息，验证方式同时检查 exit code 和 stdout |
| R4 · 阶段 0/4 排除理由 | 🟢 | **已解决** | 依赖与假设段（L93）补充排除说明 |
| R5 · 容错 NFR 缺失 | 🟢 | **已解决** | 非功能性需求追加"容错"段（API 超时降级 + mtime stat 失败跳过） |
| R6 · 集成验证 AC | 🟢 | **未处理** | 上一轮已标注为"非强制建议"（🟢 级别），不修改不构成阻塞 |

---

### 🟡 N1 · 多段 verdict 决议策略未定义：AC-1 引入多 L3 段后 AC-2/AC-3 产生歧义

**Symptom（症状）**：AC-1 采用追加模式——re-review 后在 `INDEPENDENT-REVIEW-N.md` 末尾追加新的 `## L3 重审` 段，不覆写旧段。这意味着同一个 review 文件可能包含多个 L3 verdict（原始 L3 段的 verdict + 若干次 `## L3 重审` 段的 verdict）。但 AC-2（Given：`L3_verdict=fail`）和 AC-3（Given：`L3_verdict=pass`）均未说明在多段共存时，以哪个段的 verdict 为准。

具体场景：
- 原始 L3 审查 verdict=pass（文件中有 `## L3 审查` 段含 `verdict=pass`）
- 用户修改工件，触发 AC-1 重审 → 追加 `## L3 重审` 段含 `verdict=fail`
- 此时文件中有两个 verdict：一个是 pass（旧），一个是 fail（新）
- gate 应读哪个？若读第一个（旧），L3 fail 被 pass 覆盖——安全漏洞；若读最后一个（新），需要明确定义"最后一段"的解析顺序

**Source（源头）**：AC 规范要求 Given 条件明确无歧义。AC-2/AC-3 的 Given 写的 `L3_verdict=fail/pass` 隐含"只有一个 verdict"的假设，该假设被 AC-1 的追加机制打破。

**Consequence（后果）**：若 gate 实现按原始 L3 段读取（只认 `## L3 审查` 不认 `## L3 重审`），则 L3 fail 后重审结果被无视，gate 仍按旧 pass verdict 放行——等于 AC-1 的重审机制被架空，安全漏洞回归。若 gate 扫描全文件取第一个或最后一个 verdict，行为取决于实现者选择，未经规格定义则不可测试。

**Remedy（修补）**：在 AC-2 / AC-3 的 Given 子句或在依赖与假设段中明确 verdict 决议规则。建议：
```
- 多段 L3 审查（原始 + 重审段）共存时，gate 以文件中**最后出现的 verdict** 为当前生效 verdict
- 解析方式：读取 INDEPENDENT-REVIEW-N.md，按段顺序扫描，最后一个匹配 `verdict=(pass|fail)` 的行即为当前 verdict
```
或等价表述：在 AC-2/AC-3 的 Given 中补充"以 `INDEPENDENT-REVIEW-N.md` 中最后一个 L3 段的 verdict 为准"。

---

### 🟢 N2 · AC-1 工件范围使用示例性列举而非明确定义

**Symptom（症状）**：AC-1 When 子句写"主 agent 修改了阶段 N 的产物文件（如 REQUIREMENT.md / DESIGN.md / TASK.md 等）"。`等`（etc.）是开放集合，阶段 5/6/7 的具体产物文件未列出。实现者需要知道完整文件列表才能编写 mtime 检测逻辑。

**Source（源头）**：可验证 AC 要求触发条件明确——mtime 检测脚本需要知道检查哪些文件。用 `等` 留下歧义。

**Consequence（后果）**：低风险。阶段 5/6/7 的产物文件名称可从 flow-kit 的阶段定义中推导，但需求文档缺少这一映射的明确引用。最坏情况：某个阶段产物未被纳入检测范围 → 该阶段的 L3 重审失效（回归至修复前状态）。

**Remedy（修补）**：在依赖与假设段或范围切分段补充一句：
```
- AC-1 工件检测范围：阶段 1=REQUIREMENT.md, 2=DESIGN.md, 3=TASK.md, 5=REVIEW.md, 6=TEST.md, 7=DEPLOY.md（或引用 CONTEXT.md 中的阶段—产物映射表）
```
或在 AC-1 When 中改为明确枚举而非示例性列举。

---

### 审查总结

| AC | Given/When/Then | 可机器验证 | 无歧义 | 判定 |
|----|-----------------|-----------|--------|------|
| AC-1 | 三段齐全 | 是 | 是（时间戳已定义；工件范围轻微模糊） | ✅ |
| AC-2 | 三段齐全 | 是 | **否** — 多段 verdict 决议未定义 | 🟡 |
| AC-3 | 三段齐全 | 是 | **否** — 多段 verdict 决议未定义 | 🟡 |
| AC-4 | 三段齐全 | 是 | 是 | ✅ |
| AC-5 | 三段齐全 | 是 | 是 | ✅ |

上一轮 🔴 R1 已完全解决。非功能性需求覆盖从 5/7 提升至完整（性能、安全、兼容性、可观测性、容错均已覆盖）。v1/v2/out 范围切分仍然合理，无需求间矛盾。

本轮新发现的 N1（🟡 Major）涉及 AC-1 追加机制与 AC-2/AC-3 单-verdict 假设之间的交互——属于修复引入的新歧义，但不构成 🔴 Critical，因为实现者即使不读此规格也很可能自然选择"最后一个 verdict 为准"的策略。N2（🟢 Minor）属于文档完善性建议，不影响可实施性。

**Verdict**: pass

> 上一轮的 🔴 R1 已解决，本轮无新增 🔴 Critical。N1（🟡）建议在设计阶段明确 verdict 决议策略以避免实现歧义，但可在设计文档中补全而非阻塞本阶段放行。
