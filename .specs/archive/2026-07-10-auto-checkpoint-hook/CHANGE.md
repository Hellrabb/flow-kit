# CHANGE: 自动 checkpoint hook — Write/Edit 前自动保存中断恢复上下文

- **Change ID**: `auto-checkpoint-hook`
- **创建日期**: 2026-07-10
- **路径建议**: 最短（REQUIREMENT 增量 → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

当前 checkpoint 机制依赖 AI **主动调用** `/flow checkpoint`。但弱模型（以及高负载场景下的强模型）经常忘记调用，导致：

- 会话异常中断后，`.flow-active` 的 `interrupt` 字段为空或过时
- 恢复时 AI 不知道上次在编辑哪个文件、做到哪一步
- 用户需要手动描述"上次我们做到 X"，费 token 且容易遗漏

**核心痛点**：checkpoint 纪律是给人写的，但执行者是 AI——而 AI 会忘。

## What（做什么）

新增一个 **PreToolUse hook**，在 Write/Edit 工具调用前自动更新 `.flow-active` 的 `interrupt` 字段（`active_file` + `last_action` + `checkpoint_at`）。不需要 AI 记得——hook 在工具调用层拦截，**100% 覆盖**。

核心行为：
- **Pre-tool 记录**：Write/Edit 执行前，先写 interrupt（即使编辑中途崩溃也能恢复）
- **全阶段启用**：phase 0~7，只要有活跃 change 就自动 checkpoint
- **不去抖**：每次 Write/Edit 都更新，简单可靠（jq 写 .flow-active < 10ms）
- **手动 `/flow checkpoint` 不受影响**：自动 hook 是补充，不是替代

## 影响面

- [x] 影响 `REQUIREMENT.md`（增量：新增 AC）
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC（写出哪些）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不做** Post-tool 二次确认（Pre-tool 已足够覆盖崩溃场景）
- **不做** debounce/去抖逻辑（每次更新，简单可靠）
- **不做** 非 Write/Edit 工具的 checkpoint（如 Bash/Read——那些不需要恢复定位）
- **不做** 替换 Stop hook G5 PROGRESS 日志（那是会话级日志，这是文件级 checkpoint，互补）
- **不做** 跨 session 的 checkpoint 历史回溯（那是 PROGRESS.md 的职责）

## 验收线（粗粒度，不是 AC）

- 任意阶段（0~7）有活跃 change 时，AI 调用 Write/Edit → `.flow-active` 的 `interrupt` 被自动更新
- 无活跃 change 时，hook 不写 interrupt（不产生垃圾数据）
- 恢复时 AI 从 `interrupt.active_file` + `last_action` 能精准定位
- 不增加用户可感知的延迟（jq 更新 < 10ms）

## 风险与未知

- **风险**：PreToolUse hook 在每个 Write/Edit 前都跑 jq，高频编辑场景（如同一文件连续 Edit）可能产生微小 I/O 开销。缓解：jq 更新 200 字节 JSON 极快，实测 < 10ms，不影响体验。
- **风险**：hook 脚本自身的 bug 可能阻断 Write/Edit 调用。缓解：hook 内部 fail-open——出错时静默跳过，不拦工具调用。
- **未知**：是否需要为 `interrupt` 字段增加 `tool_name`（区分 Write vs Edit）以提供更丰富的恢复上下文？暂不加，先跑起来看反馈。

---

> 后续 AC 与实现细节进入 `REQUIREMENT.md`，本文件不再扩展。
