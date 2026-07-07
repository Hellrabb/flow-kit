# REQUIREMENT: L3 审查结果反馈可见性修复

- **Change ID**: `l3-feedback-visibility`
- **关联**: `@.specs/l3-feedback-visibility/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为使用 flow-kit pipeline 的开发者，我想在阶段切换时（PreToolUse 路径）看到 L3 外部模型审查的结论，以便知道独立审查是否发现了问题，而非只看到"gate 已通过"。
- **US-2**：作为在下一 session 恢复工作的开发者，我想在新 session 启动时看到上一轮 L3 审查的结果摘要，以便无需手动翻查 `INDEPENDENT-REVIEW-<N>.md` 文件就能了解审查结论。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · PreToolUse 路径 L3 反馈可见

- **Given** 当前 phase 的 `gate_config` 开启 L3（`both` 或 `L3-only`），且 transition jq 被 PreToolUse hook 拦截
- **When** `independent-review-gate.sh` 同步执行 L3 审查并产出 verdict + summary
- **Then** PreToolUse hook 的 stdout 输出一行格式为 `L3_RESULT: verdict=<pass|fail|timeout|error> summary=<text> report=<path>` 的文本（verdict 值统一小写，与既有代码库全链路一致），且该文本在 agent 下一轮对话上下文中可见
- **验证方式**: `grep -qiE '^l3_result: verdict=(pass|fail|timeout|error) summary=.* report=.+' <captured_hook_output>`

### AC-2 · SessionStart 路径 L3 报告注入恢复

- **Given** 上一 session 中 L3 审查已完成（`.independent-review-<N>.done` 存在，且 `INDEPENDENT-REVIEW-<N>.md` 含 `## L3 外部模型审查` 段），**无论握手状态文件是否存在**（29 号 hook 可能已清理）
- **When** 新 session 启动，`flow-kit-resume.sh` 执行
- **Then** agent 在 SessionStart banner 或 resume 上下文中看到一行格式为 `L3_RESULT: verdict=<pass|fail|timeout|error> summary=<text> report=<path>` 的文本（verdict 值统一小写）
- **验证方式**:
  1. 创建 `.independent-review-<N>.done`（含 `L3_verdict` + `L3_summary` 键）
  2. 创建 `INDEPENDENT-REVIEW-<N>.md`（含 `## L3 外部模型审查` 段）
  3. 确认握手状态文件**不存在**（模拟 29 号 hook 已清理的真实 post-hook 场景）
  4. 启动新 session，检查 SessionStart hook 输出中是否出现 `L3_RESULT:` 行

### AC-3 · 两条路径反馈格式一致

- **Given** 同一个 L3 审查结果
- **When** 分别通过 PreToolUse 路径（AC-1）和 SessionStart 路径（AC-2）展示
- **Then** 两条路径均输出格式为 `L3_RESULT: verdict=<value> summary=<text> report=<path>` 的行。PreToolUse 路径以 hook stdout 单行输出，SessionStart 路径以 resume banner 内嵌行输出——格式差异仅限于外层包装（单行标记 vs banner 内嵌），核心字段（verdict / summary / report path）的值和顺序一致
- **验证方式**:
  1. 单元级：代码审查验证两条路径调用同一格式化函数/模板输出 `L3_RESULT:` 行
  2. 集成级：手动触发一次端到端验证，对比两条路径的 `L3_RESULT:` 行中 verdict / summary / report 三个字段值一致

### AC-4 · 现有 L2 反馈不受影响 + 全模式兼容

- **Given** 各种 `gate_config` 模式
- **When** transition 或 session resume 执行
- **Then**:
  - `both` 模式：L2 审查结果（子 agent 直接返回对话）仍然可见，不受 L3 反馈通道改动影响；`INDEPENDENT-REVIEW-<N>.md` 中 L2 段和 L3 段均存在
  - `L3-only` 模式：仅 L3 反馈出现，无 L2 内容
  - `L2-only` 模式：仅 L2 反馈出现，**不产生** `L3_RESULT:` 行，transition 正常放行
  - `off` 模式：**不产生** `L3_RESULT:` 行，transition 正常放行
- **验证方式**:
  1. 触发 `both` 模式 transition：检查对话中 L2 结果可见 + `INDEPENDENT-REVIEW-<N>.md` 含两段
  2. 触发 `L2` 模式 transition：检查 `L3_RESULT:` 行**不出现** + transition exit code 0
  3. 触发 `off` 模式 transition：检查 `L3_RESULT:` 行**不出现** + transition exit code 0

### AC-5 · L3 超时降级不阻塞反馈

- **Given** L3 API 调用超时（30s）
- **When** `independent-review-gate.sh` 捕获超时并降级为 `L3_verdict=timeout`
- **Then**:
  1. PreToolUse hook stdout 输出 `L3_RESULT: verdict=timeout summary=<reason> report=<path>`（若无 report 路径则 summary 写明原因；verdict 值统一小写）
  2. Transition 正常放行（exit code 0）
- **验证方式**:
  1. `grep -qE '^L3_RESULT: verdict=timeout' <captured_hook_output>`
  2. 检查 transition exit code = 0

### AC-6 · L3 输出畸变降级反馈

- **Given** L3 审查已完成且 `.done` 文件存在，但 `INDEPENDENT-REVIEW-<N>.md` 中 L3 段的 JSON 无法解析，或 verdict 字段缺失/值为非法值
- **When** PreToolUse 路径或 SessionStart 路径尝试提取 L3 反馈
- **Then** agent 收到降级反馈行 `L3_RESULT: verdict=error summary=L3 结果解析失败（verdict 不可用） report=<path>`（`error` 值域已由 `done-validation.sh:139` 接受）。不得静默，不得泄露原始畸形 JSON 到 agent 上下文
- **验证方式**: 手动构造含非法 JSON 的 `INDEPENDENT-REVIEW-<N>.md`，检查 agent 是否收到 `verdict=error` 通知且输出不含原始畸形内容

---

## 范围切分

### v1（本次必做）

- **F1**：`independent-review-gate.sh` 在 L3 审查完成后，将 verdict + summary + report 路径以 `L3_RESULT:` 格式写入 stdout（agent 可见 channel）。仅输出这三个字段（verdict / summary / report 相对路径），不暴露 `l3-review.sh` 内部日志、文件系统绝对路径、API 响应原文
- **F2**：`flow-kit-resume.sh` 修复 L3 报告注入检测逻辑——从"检查握手状态文件是否存在"改为"检查 `.done` 是否存在 + `INDEPENDENT-REVIEW-<N>.md` 是否含 L3 段"，适配 `.done` 直写机制（29 号 hook 已清理状态文件的真实 post-hook 场景）
- **F3**：`l3-review.sh` 新增 `summary` 字段提取逻辑——与 verdict 提取并列，将提取的 summary 写入 `.done` 文件（如 `L3_summary` 键），供 PreToolUse 和 SessionStart 两条路径统一读取
- AC-3 格式一致性（`L3_RESULT:` 统一格式行）
- AC-5 超时反馈（已有降级逻辑，仅补 `L3_RESULT:` 输出）
- AC-6 畸变降级反馈

### v2（下一轮考虑，不本次）

- L3 反馈增加结构化细节（如具体 FAIL 条目摘要、风险等级），当前仅 verdict + 一句话 summary
- L3 审查历史面板（展示同一 change 下所有 phase 的 L3 结论汇总）

### out（永远不做）

- 不新增 hook 模块（CHANGE.md 已明确）
- 不改动 L3 API 调用的超时/重试策略
- 不改动 `.done` 文件的格式或值域
- 不改动 L3 审查的内容生成逻辑（prompt 构建、模型选择等）

---

## 非功能性需求

- **性能**: L3 反馈输出不增加 transition 耗时（已在 30s 超时内，仅改输出路由）
- **可访问性**: 无
- **安全**: L3 输出路由不泄露以下内容到 agent 可见上下文：API key、内部 endpoint、文件系统绝对路径、API 响应原文（raw response body）。仅 verdict + summary + report **相对路径** 三个字段可暴露
- **兼容性**: PreToolUse 路径改动兼容 `gate_config` 全模式（`L2-only`/`L3-only`/`both`/`off`）——`L2` 和 `off` 模式下不产生 `L3_RESULT:` 输出且不阻塞 transition；SessionStart 路径改动兼容无 L3 的 resume 场景（不产生假阳性 banner）
- **可观测性**: L3 超时/失败/畸变时输出 `L3_RESULT:` 行（非静默），便于开发者判断是否需要手动 touch `.done`

## 依赖与假设

- **依赖**: `hooks/stop/lib/l3-review.sh`（L3 API 调用共享 lib，本次加 summary 提取）; `hooks/pre-tool-use/independent-review-gate.sh`（PreToolUse 入口，本次修改输出路由）; `hooks/session-start/flow-kit-resume.sh`（SessionStart resume 逻辑，本次修改检测逻辑）
- **假设**: PreToolUse hook 的 stdout 可被 agent 感知（具体机制由 DESIGN 确定）; SessionStart banner 格式变更不影响现有 resume 逻辑的其他部分; L3 模型响应中 `summary` 字段已由 L3 prompt 要求产出，`l3-review.sh` 仅需新增提取逻辑（不改 prompt）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
