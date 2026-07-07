# REQUIREMENT: L3 独立审查全面修复

- **Change ID**: l3-comprehensive-fix
- **关联**: `@.specs/l3-comprehensive-fix/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在每次新 session 启动时自动看到 L3 审查结果摘要，以便无需手动查找就知道 L3 说了什么。
- **US-2**：作为 flow-kit 用户，我想 L3 审查基于完整工件内容（不被截断），以便减少假阳性，信任审查结果。
- **US-3**：作为 flow-kit 用户，我想 `.done` 写入后 Stop hook 不再重复触发 L3，以便 phase 完成后的讨论不被不必要的审查打断。
- **US-4**：作为 flow-kit 用户，我想 Phase 5/6/7 的 L2 子 agent 审查能像 L3 一样可靠自动触发（不需手动补跑），以便独立审查门禁真正"自动"。

## 验收准则（AC）

### AC-1 · L3 结果自动注入 SessionStart

- **Given** 上一轮 session 结束时 Stop hook 或 PreToolUse gate 已完成 L3 审查（`.independent-review-<N>.done` 存在，且 `INDEPENDENT-REVIEW-<N>.md` 含 L3 段）
- **When** 新 session 启动，SessionStart hook `flow-kit-resume.sh` 运行
- **Then** 终端输出 L3 审查结果，格式遵循 CONTEXT.md 定义的 `L3_RESULT:` 标准行（`L3_RESULT: verdict=<pass|fail|timeout|error> summary=<一句话> report=<报告相对路径>`），无需用户手动触发
- **验证方式**: 模拟完成 Phase 6 L3 审查 → 结束 session → 新 session 启动 → 检查 stdout 含 `L3_RESULT:` 标准格式行，且 verdict/summary/report 三字段均非空

### AC-2 · L3 工件截断可控（减少假阳性）

- **Given** 阶段产物（如 REVIEW.md + git diff）总大小可能超过当前 `max_artifact_chars`（默认 20000）
- **When** L3 审查收集工件时
- **Then** 智能截断而非简单 `head -c` 硬截断：
  - 硬约束 (a)：所有 Markdown `##`/`###` 标题行必须保留
  - 硬约束 (b)：AC-1~AC-7 的 Given/When/Then 行必须完整保留
  - L3 模型被告知截断上下文：(a) 原始大小 vs 截断后大小；(b) 被截去的章节列表
- **验证方式**: 使用 `test/fixtures/l3-truncation-30k.md`（预置 30KB REVIEW.md，含 3 个故意植入的缺陷：缺失 AC 验证 + 错误文件路径 + scope 不一致），3 轮 L3 调用的 critical 均值 ≤ 4（3 真实 + 1 容忍假阳性）

### AC-3 · .done 阻止重复触发（pipeline 模式）

- **Given** Phase 7 独立审查已完成（`.independent-review-7.done` 存在且有效），pipeline 或 phase 仍在 7
- **When** 用户与 agent 讨论后续方案后结束 session，Stop hook `29-independent-review.sh` 触发
- **Then** hook 检测到 `.done` 存在 → 输出 skip 日志行（含 "skipped" 及 done 文件路径）→ 跳过 L3（exit 0），不重复调用 API，不覆盖已有审查结果
- **验证方式**: 手动创建 `.independent-review-7.done` → 设置 phase=7 → 触发 stop hook → 确认输出含 "skipped" 或直接 exit 0，无 API 调用

### AC-4 · Phase 5/6/7 L2 被动触发机制

- **Given** Phase 5/6/7 的 `gate_config` 含 L2（`both` 或 `L2`），且阶段产物已生成（如 TEST.md / REVIEW.md）
- **When** 主 agent 即将切阶段（PreToolUse gate 触发）或 session 结束（Stop hook 触发）
- **Then** 系统自动检测 L2 未完成状态并在 PreToolUse gate 或 Stop hook 中输出明确提示（含一键派 agent 命令模板），不依赖主 agent 主动读 prompt。v1 不自动派 agent（全自动触发留 v2）
- **验证方式**: 模拟 Phase 5 完成 TEST.md → 尝试切 phase → PreToolUse hook 检测到 L2 未完成 → stderr 输出含 "请派 L2 子 agent" 及可复制的 Agent 命令模板

### AC-5 · L2 子 agent 触发选项可见

- **Given** Phase 5/6/7 L2 未完成，主 agent 未主动派 L2
- **When** 用户执行切阶段操作（`/flow phase 6` 或 pipeline transition）
- **Then** PreToolUse gate 拦截并给出清晰选项：① 现在派 L2 子 agent（提供一键命令）② 跳过 L2（需显式确认风险）③ 回退等待
- **验证方式**: 在 Phase 5 尝试切到 Phase 6 → gate deny → stderr 输出含 3 个选项的提示

### AC-6 · .done 6 键 KVP 完整性校验

- **Given** `.independent-review-<N>.done` 文件存在
- **When** PreToolUse gate 或 SessionStart hook 读取该文件
- **Then** 按 Shell source 格式（`KEY="value"`，即 `bash -c "source <file> && echo \$KEY"` 可解析）校验 6 个 key 全部存在且非空（`phase` / `change_id` / `written_by` / `L2_verdict` / `L3_verdict` / `artifacts`），缺任何一键 → 视为无效 done → gate 不放行
- **验证方式**: 创建缺 `L3_summary`（非 6 键之一）的 done 文件 → gate 仍放行；创建缺 `L3_verdict` 的 done 文件 → gate deny

### AC-7 · Pipeline 模式下 phase 字段一致性

- **Given** Pipeline goal 处于 Phase 5（`.goal.current_phase = "5"`）
- **When** Stop hook `29-independent-review.sh` 读取 phase 判断是否触发 L3
- **Then** pipeline 模式（`.goal.scope = "pipeline"` 且 `.goal.current_phase` 非空且 ∈ {1,2,3,5,6,7}）→ 仅用 `current_phase`；否则 → 降级用 `.phase`。禁止取二者最大值，避免过期 `.phase` 值污染 pipeline 判断
- **验证方式**: 设置 pipeline mode + current_phase=5 + .phase=6（模拟过期残留）→ 触发 stop hook → hook 使用 current_phase=5 判断触发范围，不因 .phase=6 而对已完成阶段 6 误触发

---

## 范围切分

### v1（本次必做）

- AC-1: 修复 L3 header 不匹配，确保 SessionStart 正确注入 L3 结果
- AC-3: 修复 `.done` 重复触发（含 AC-7 phase 字段一致性修复）
- AC-4: Phase 5/6/7 L2 被动触发机制（Stop hook 或 PreToolUse 自动检测 + 提示）
- AC-5: L2 触发选项的用户可见交互
- AC-6: `.done` 6 键 KVP 完整性校验
- AC-2: L3 工件截断优化（智能截断 + 告知模型）

### v2（下一轮考虑，不本次）

- L2 全自动触发（Stop hook 直接派子 agent，类似 L3 的全自动模式，无需用户确认）
- L3 模型切换策略（根据阶段特性选择不同模型，如 review 用强模型、test 用快模型）
- L2/L3 审查结果的结构化 diff（对比 L2 vs L3 发现的分歧点，高亮需要人工裁决的）
- L3 API 调用的重试 + 指数退避（当前无重试，一次失败即降级）

### out（永远不做）

- Phase 4 引入 L2/L3 独立审查（保持 Phase 4 不触发这一设计决策）
- L2/L3 审查内容/标准变更（如新增安全性审查维度）——本次只修执行机制
- 用非 Anthropic-compatible API 做 L3（保持单一直连协议）

---

## 非功能性需求

- **性能**: L3 API 调用 timeout 保持 90s（curl）或 30s（PreToolUse sync wrapper）；L2 子 agent 派发为异步提示（PreToolUse hook 输出提示即返回，不等待子 agent 完成），故不设硬时延上限
- **可访问性**: 无
- **安全**: `.done` 文件不能被主 agent 直接 Write/Edit（PreToolUse path-guard D7 已覆盖）；L3 API key 仅通过环境变量传入，不落盘
- **韧性**: L3 API 超时/不可用时降级为 `L3_verdict=timeout`，gate 仍放行（不阻塞 pipeline），输出 warning 日志含降级原因；L2 子 agent 派发失败时输出 error 日志但不阻塞（L2 失败 ≠ gate 失败，除非 gate_config 为 `L2-only`）
- **兼容性**: 向后兼容——未开启 gate_config 的阶段行为不变；旧版 `.done` 文件（缺 L3_summary key）仍被识别为有效
- **可观测性**: 每次 L2/L3 触发/跳过均输出 `module_output` 日志行（含 phase / verdict / skip_reason）；SessionStart 注入失败时输出 warning 而非静默跳过

## 依赖与假设

- **假设**: Anthropic API 兼容端点持续可用（`ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`），L3 依赖此外部服务
- **假设**: `jq` 在所有 hook 运行环境中可用（现有代码已依赖）
- **假设**: `.flow-active` 的 `goal.scope = "pipeline"` 时 `goal.current_phase` 为权威 phase 来源
- **依赖**: `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（L3 共享 lib）、`flow-kit-bundle/hooks/stop/lib/done-validation.sh`（done 校验 lib）、`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（PreToolUse gate）
- **依赖**: 各阶段 prompt 中的「独立 review 调度」段（1-requirement.md / 2-design.md / 3-task.md / 5-test.md / 6-review.md / 7-integration.md）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
