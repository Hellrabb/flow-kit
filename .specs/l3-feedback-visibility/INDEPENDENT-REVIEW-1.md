# 独立审查 · 阶段 1

## L2 盲审

### 🔴 R1 · 不可机器验证的 AC：AC-1 Then 子句无具体输出通道与格式

**Symptom（症状）**：`REQUIREMENT.md:21` — AC-1 Then 写「L3 的 verdict（PASS/FAIL/WAIVER/TIMEOUT）和一句话 summary 出现在 agent 可感知的上下文（对话输出或下一轮 prompt 注入），agent 无需手动读文件即可知道 L3 结论」。验证方式写「检查 agent 对话中是否出现 L3 verdict + summary 文本」。

**Source（源头）**：阶段 1 checklist 第 1 条——「每条 AC 是否 Given/When/Then 三段齐全且**可机器验证**（拒绝"系统应该正常工作"这类空话）？」。"agent 可感知的上下文"与"agent 对话中是否出现"均依赖人类阅读 agent conversation log，无法编写自动化断言。既未指定输出 channel（stdout？stderr？hook 注入 prompt 前缀？），也未指定输出格式（纯文本？JSON？带标记行如 `L3_RESULT:`？），导致同一 AC 可通过多种互不兼容的方式"通过"——只要有文本出现在某处就算满足。

**Consequence（后果）**：自动化回归测试无法判断 AC-1 通过与否。每次回归必须人工检查 agent 对话，测试成本线性增长。不同实现路径（PreToolUse stderr 直出 vs prompt injection vs 写入专有文件）会产生互不一致的 agent 体验，但都声称"满足 AC-1"。一旦后续有人 refactor channel 实现，没有自动化测试能捕获回归。

**Remedy（修补）**：将 Then 子句改为指定具体输出契约。例如：

```
Then PreToolUse hook 的 stdout 输出一行格式为
"L3_RESULT: verdict=<PASS|FAIL|WAIVER|TIMEOUT> summary=<text> report=<path>"
的文本，且该文本在 agent 下一轮对话上下文中可见
```

同时更新验证方式为可自动化断言：`grep -qE '^L3_RESULT: verdict=(PASS|FAIL|WAIVER|TIMEOUT) summary=.+ report=.+' <captured_output>`。AC-3 已定义了信息字段（verdict + summary + report path），AC-1 应引用同一契约而非自创一套模糊描述。

---

### 🔴 R2 · AC-5 超时反馈的 Then 子句同样不可机器验证

**Symptom（症状）**：`REQUIREMENT.md:49` — AC-5 Then 写「agent 仍能看到"L3 超时"的反馈信息（而非静默），pipeline 不因超时而死锁」。验证方式写「模拟 L3 API 超时场景，检查 agent 是否收到 timeout 通知且 transition 正常放行」。

**Source（源头）**：同 R1——"agent 是否收到 timeout 通知"无法被自动化脚本断言。"transition 正常放行"是可机器验证的（exit code 0），但"看到反馈"不可验证，整条 AC 因此不满足 checklist 的可机器验证要求。

**Consequence（后果）**：同 R1。且超时路径是异常路径，比正常路径更少被手动测试覆盖，缺乏自动化验证意味着超时反馈回归几乎必然在未被察觉的情况下发生。

**Remedy（修补）**：将 Then 拆为两个可独立验证的断言：

```
Then:
1. PreToolUse hook stdout 输出 "L3_RESULT: verdict=timeout summary=<reason> report=<path>"（或无 report 路径时输出降级文本）
2. Transition 正常放行（exit code 0）
```

验证方式 1 用 grep 自动化；验证方式 2 检查 exit code。两部分独立可测。

---

### 🟡 R3 · v1 范围 F1 描述与安全 NFR 存在张力——以实现手段替代需求规格

**Symptom（症状）**：`REQUIREMENT.md:58` — v1 F1 写「`independent-review-gate.sh` 移除 `2>/dev/null`，将 L3 输出路由到 agent 可见渠道」。同时 `REQUIREMENT.md:81` 安全 NFR 写「L3 输出路由不泄露 API key 或内部 endpoint 到 agent 可见上下文」。

**Source（源头）**：需求工程基本原则——需求应描述 **What**（输出什么信息），而非 **How**（移除某个 stderr 抑制）。F1 以单一实现手段作为 v1 条目，但"移除 `2>/dev/null`"是一个粗糙操作：`l3-review.sh` 的 stderr 输出包含带完整文件系统路径的内部日志行（line 264 — `echo "[l3-review] L3 complete (phase ${phase}, verdict=${l3_verdict}, ...) → ${done_marker}"`），其中 `${done_marker}` 暴露 `.specs/<change-id>/.independent-review-<N>.done` 的完整路径。此外，若 curl 子进程因网络问题输出错误详情到 stderr，这些也会被一并暴露。

**Consequence（后果）**：按 F1 字面执行（"移除 `2>/dev/null`"）会将 `l3-review.sh` 全量 stderr 不加过滤地暴露给 agent。当前安全 NFR 只禁止了 API key 和 endpoint 泄露，但内部文件路径、函数名、调用栈同样属于不必要的实现细节泄露。更严重的是，未来若有人启用 curl verbose 调试，token 可能通过 stderr 泄露而安全 NFR 的文本范围无法覆盖。

**Remedy（修补）**：将 F1 重写为 outcome-oriented 表述：

```
F1：independent-review-gate.sh 在 L3 审查完成后，将 verdict + summary + report 路径
以明确格式写入 agent 可见的上下文 channel（具体 channel 由 DESIGN 选定）。
仅输出这三个字段，不暴露 l3-review.sh 内部日志、文件系统路径、API 响应原文。
```

同时强化安全 NFR：「L3 输出路由不泄露 API key、内部 endpoint、文件系统绝对路径、API 响应原文（raw response body）到 agent 可见上下文。仅 verdict + summary + report 相对路径三个字段可暴露。」

---

### 🟡 R4 · "一句话 summary"字段在当前代码中未被提取——AC 与实现能力之间存在缺口

**Symptom（症状）**：`REQUIREMENT.md:21,27,35` — AC-1、AC-2、AC-3 均引用「一句话 summary」作为反馈必需字段。但 `hooks/stop/lib/l3-review.sh:201-216` 的 verdict 提取逻辑仅处理 `verdict` 字段，不提取 `summary`。L3 审查 prompt（line 138）确实要求模型返回 `"summary":"一句话总评"`，但该字段随完整 JSON 写入 `INDEPENDENT-REVIEW-<N>.md` 后从未被单独解析和暴露。

**Source（源头）**：需求与现有实现的契约不匹配。v1 范围声明「不改动 L3 审查的内容生成逻辑（prompt 构建、模型选择等）」——summary 的 extraction 不属于内容生成，理论上可在 v1 内完成，但 v1 的 F1/F2 描述未提及需要新增 summary 提取逻辑。导致 AC 要求的字段无法从现有代码路径产出。

**Consequence（后果）**：无论 PreToolUse 路径还是 SessionStart 路径修复了输出路由，agent 能看到的始终只有 verdict，而非「verdict + 一句话 summary」。AC-1 和 AC-2 的 Then 子句部分不满足——summary 字段缺失。三条 AC 的验证都会因缺少 summary 而失败。

**Remedy（修补）**：二选一：

方案 A（推荐）：v1 范围新增 F3：「`l3-review.sh` 新增 `summary` 字段提取逻辑（与 verdict 提取并列），将提取的 summary 写入 `.done` 文件的 `L3_summary` 键，供 PreToolUse 和 SessionStart 两条路径统一读取。」

方案 B：若 summary 提取被认为超出 v1 范围，则从所有 AC 中删除「一句话 summary」的需求，降级为 v2 项（`REQUIREMENT.md:65` v2 首条"L3 反馈增加结构化细节"已部分覆盖此降级路径）。但方案 B 会导致本 change 的核心价值打折扣——agent 只知道 PASS/FAIL 而不知道原因。

---

### 🟡 R5 · AC-2 的验证前置条件未覆盖状态文件被 Stop hook 29 清理的真实场景

**Symptom（症状）**：`REQUIREMENT.md:29` — AC-2 验证方式写「模拟：创建 `.done` + 含 L3 段的 `INDEPENDENT-REVIEW-<N>.md`，启动新 session，检查 SessionStart hook 输出」。但 `hooks/stop/29-independent-review.sh:126` 在 L3 完成后执行 `rm -f "$state_file"`（清理握手状态文件），而 `hooks/session-start/flow-kit-resume.sh:133-134` 的整个 L3 报告注入代码块以 `[[ -f "$ir_state_file" ]]` 为入口条件。在真实场景中，Stop hook 29 已清理状态文件，下一次 session 启动时代码块根本不进入。

**Source（源头）**：CHANGE.md:16 正确诊断了根因——「29 号 hook 还清理了握手文件。所以新路径下 banner 永远不会触发。」但 REQUIREMENT.md 未将此根因转化为 AC 的前置条件或实现约束。验证方式中仅要求「创建 `.done` + `INDEPENDENT-REVIEW-<N>.md`」，未要求同时创建（或不创建）握手状态文件。按当前验证方式操作可能得到假阳性——若验证者恰好创建了状态文件（模拟旧路径），banner 会触发，但在真实 post-29-hook 环境中不会。

**Consequence（后果）**：按 AC-2 的验证方式执行可能得到"通过"的假阳性。真实世界中 resume 场景下 L3 反馈仍然静默，AC-2 未实际达成。

**Remedy（修补）**：更新 AC-2 验证方式，明确要求模拟真实 post-29-hook 状态：

```
验证方式：
1. 创建 .independent-review-<N>.done（含 L3_verdict + L3_summary）
2. 创建 INDEPENDENT-REVIEW-<N>.md（含 ## L3 盲审 段）
3. 确认握手状态文件不存在（模拟 29 号 hook 已清理）
4. 启动新 session，检查 SessionStart hook 输出中是否仍能提取到 L3 verdict + summary + report 路径
```

同时更新 AC-2 的 Given 添加对状态文件缺失的容忍：「Given 上一 session 中 L3 审查已完成（`.independent-review-<N>.done` 存在），**无论握手状态文件是否存在**」。

---

### 🟡 R6 · 缺失边缘情况 AC：L3 输出畸变/损坏时的反馈行为

**Symptom（症状）**：`REQUIREMENT.md:17-51` — 五条 AC 覆盖了正常路径（AC-1/2）、格式一致性（AC-3）、回归（AC-4）、超时（AC-5），但均未规定以下场景的行为：
- `INDEPENDENT-REVIEW-<N>.md` 存在但 L3 段的 JSON 无法解析（模型返回了非 JSON 文本，如 DeepSeek thinking 前缀污染）
- `.done` 文件存在但 `L3_verdict` 键缺失或值为非法值（当前 `l3-review.sh:220-223` 降级为 `fail`，但此降级行为未在需求中声明）
- `.done` 文件存在但 `INDEPENDENT-REVIEW-<N>.md` 缺失（`.done` 是原子写入的，但磁盘故障或手动删除可能造成不一致）

**Source（源头）**：阶段 1 checklist——「是否遗漏非功能性需求（可观测性）？」边缘情况处理是系统可观测性的基本要求。当前 `l3-review.sh` 有降级逻辑（非法 verdict → `fail`），AC-5 覆盖了 timeout 降级，但数据畸变降级没有被需求化。

**Consequence（后果）**：当 L3 外部模型返回非标准格式时，agent 可能看到混乱的输出（原始 JSON parse error 泄露到上下文），或完全看不到反馈（提取失败导致静默）。没有 AC 约束此行为，实现者可能以任意方式处理，可能恰与 AC-1/AC-5 的"不可静默"原则冲突。

**Remedy（修补）**：新增 AC-6：

```
### AC-6 · L3 输出畸变降级反馈

- **Given** L3 审查已完成且 .done 文件存在，但 INDEPENDENT-REVIEW-<N>.md 中 L3 段的 JSON
  无法解析或 verdict 字段缺失/非法
- **When** PreToolUse 路径或 SessionStart 路径尝试提取 L3 反馈
- **Then** agent 收到降级反馈，明确标注 "L3 结果解析失败（verdict 不可用）" + 报告文件路径，
  不得静默，不得泄露原始畸形 JSON 到 agent 上下文
- **验证方式**: 手动构造含非法 JSON 的 INDEPENDENT-REVIEW-<N>.md，检查 agent 是否收到降级通知
  且不含原始畸形内容
```

---

### 🟢 R7 · AC-3 跨路径验证方式实操困难但非阻塞

**Symptom（症状）**：`REQUIREMENT.md:36` — AC-3 验证方式「对比同一 L3 结果在两条路径下的输出，确认 verdict / summary / report path 三个字段均出现且值一致」。此验证需要：（1）触发 PreToolUse 并捕获输出；（2）模拟 session 重启触发 SessionStart 并捕获输出；（3）跨两次运行从不同格式（即时通知 vs resume banner）中提取同名字段比对。这是一个多步骤手动流程，自动化成本高。

**Source（源头）**：检查表未强制要求每条 AC 自动化可测，但 AC-3 的验证跨 session 生命周期，回归测试易被跳过。

**Consequence（后果）**：AC-3 的回归测试大概率在迭代中被跳过（每次回归需要手动操作两次不同的 hook 触发路径），格式一致性的回归可能长期不被发现。

**Remedy（修补）**：建议 AC-3 的验证拆为两步：（1）单元级：验证两条路径调用同一格式化函数/模板输出 L3 字段（代码审查可验证）；（2）集成级：手动端到端验证一次作为 acceptance。同时在 AC-3 中明确两个路径输出格式的差异边界（如 PreToolUse 为单行标记，SessionStart 为 banner 内嵌行），使格式差异被显式记录而非隐含。

---

### 🟢 R8 · 缺少 gate_config="L2" 模式下 L3 skip 的显式行为 AC

**Symptom（症状）**：`REQUIREMENT.md:38-43` — AC-4 覆盖了 `both` 模式的兼容性。AC-1 隐式覆盖了 `L3-only` 和 `both` 模式下 L3 有产出时的行为。但 `gate_config` 的合法取值还包括 `L2` 和 `off`（如 `independent-review-gate.sh:204` 的映射逻辑所示）。当 `gate_config=<phase>=L2` 时，L3 被刻意跳过——此时 agent 是否应收到"L3 未启用"的通知？还是应完全静默？

**Source（源头）**：`REQUIREMENT.md:82` NFR 兼容性段声明「PreToolUse 路径改动兼容 `gate_config` 全模式（`L2-only`/`L3-only`/`both`/`off`）」，但只声明了兼容性，未定义各模式下的具体反馈行为。

**Consequence（后果）**：实现者可能对 `L2` 模式做不同处理（完全静默 vs 提示"L3 not configured"），导致行为不一致。风险较低——这是已存在的模式，只要不因本次改动引入新的错误输出即可，但缺乏明确 AC 意味着没有对应的测试用例覆盖 `L2` 和 `off` 模式下的反馈行为。

**Remedy（修补）**：在 AC-4 中扩展 non-regression 断言：增加对 `L2`、`off` 模式下不产生 L3 相关输出且不阻塞 transition 的验证步骤。代价低（仅加一条验证步骤），收益是使全模式兼容从声明变成可验证。

---

**Verdict**: **fail**

（存在 2 条 🔴 Critical：AC-1 与 AC-5 的 Then 子句不可机器验证，违反阶段 1 checklist 第 1 条硬性要求。）
