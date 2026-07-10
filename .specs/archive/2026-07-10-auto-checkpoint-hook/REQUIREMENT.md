# REQUIREMENT: 自动 checkpoint hook

- **Change ID**: `auto-checkpoint-hook`
- **关联**: `@.specs/auto-checkpoint-hook/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我希望系统在 AI 每次编辑文件前**自动**保存当前编辑上下文到 `.flow-active` 的 `interrupt` 字段，以便会话异常中断后无需手动描述"上次做到哪了"就能精准恢复。
- **US-2**：作为恢复中断会话的开发者，我希望 `interrupt` 字段包含 `active_file`（正在编辑的文件路径）、`last_action`（动作描述）和 `checkpoint_at`（时间戳），以便恢复时 AI 一眼知道从哪里继续。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · Write 前自动 checkpoint（有活跃 change）

- **Given** `.flow-active` 存在且 `change_id` 非 null，`phase` 为 0~7 之一
- **When** AI 调用 Write 工具写入文件 `<filepath>`
- **Then** `.flow-active` 的 `interrupt` 字段被更新为 `{"active_file": "<filepath>", "last_action": "编辑 <filepath>", "checkpoint_at": "<ISO8601 timestamp>"}`，且 `updated_at` 同步更新
- **验证方式**: `bats test` —— 模拟 `.flow-active` 有活跃 change，触发 hook，jq 读取 `.flow-active.interrupt` 验证三字段非空且 `active_file` 匹配

### AC-2 · Edit 前自动 checkpoint（有活跃 change）

- **Given** `.flow-active` 存在且 `change_id` 非 null，`phase` 为 0~7 之一
- **When** AI 调用 Edit 工具修改文件 `<filepath>`
- **Then** 同 AC-1 —— `interrupt` 被更新，`active_file` 为被编辑的文件路径
- **验证方式**: `bats test` —— 同 AC-1，但触发 Edit 路径

### AC-3 · 无活跃 change 时静默跳过

- **Given** `.flow-active` 不存在，或存在但 `change_id` 为 null
- **When** AI 调用 Write 或 Edit 工具
- **Then** `.flow-active` 不被创建；若已存在则 `interrupt` 字段保持原值不变
- **验证方式**: `bats test` —— 删除 `.flow-active` 后触发 hook，断言 `.flow-active` 未被创建；设 `change_id=null` 后触发，断言 `interrupt` 不变

### AC-4 · 非 Write/Edit 工具不触发

- **Given** `.flow-active` 存在且 `change_id` 非 null
- **When** AI 调用 Read / Bash / Grep / Glob 或其他非 Write/Edit 工具
- **Then** `.flow-active` 的 `interrupt` 字段不变（不被覆盖）
- **验证方式**: `bats test` —— 预设 `interrupt` 值，触发 Read/Bash 路径，断言 `interrupt` 值与预设一致

### AC-5 · Fail-open：hook 异常不阻断工具调用

- **Given** `.flow-active` 存在但 JSON 格式损坏（`jq empty` 失败）
- **When** AI 调用 Write 工具写入文件 `<filepath>`，或 AI 调用 Edit 工具修改文件 `<filepath>`
- **Then** Write/Edit 操作正常执行（不被 hook 阻断）；hook 错误被重定向到 stderr 日志但不影响工具返回
- **验证方式**: `bats test` —— 写入损坏 JSON 到 `.flow-active`，分别触发 Write 和 Edit 路径：(a) Write：断言目标文件被创建 (b) Edit：断言目标文件被修改 (c) 两条路径 hook 退出码均为 0（fail-open）

### AC-6 · 恢复精度验证

- **Given** `.flow-active.interrupt` = `{"active_file": "src/hooks/checkpoint.sh", "last_action": "编辑 src/hooks/checkpoint.sh", "checkpoint_at": "2026-07-10T15:00:00+08:00"}`
- **When** 调用 SessionStart hook `flow-kit-resume.sh` 检测到 `interrupt` 非空，生成 resume banner
- **Then** resume banner stdout 包含 `active_file`（`"src/hooks/checkpoint.sh"`）、`last_action`（`"编辑 src/hooks/checkpoint.sh"`）、`checkpoint_at` 时间戳，足以让 AI 不追问用户即继续工作
- **验证方式**: `bats test` —— (a) 预设 interrupt 值到 `.flow-active`，(b) 调用 `flow-kit-resume.sh` 的 resume banner 生成函数，(c) 断言其 stdout 包含 `${active_file}` 和 `${last_action}` 和 `${checkpoint_at}` 三个字段的值

### AC-7 · 文档完整性

- **Given** PreToolUse hook 已安装
- **When** 用户查看 `flow-kit/skills/flow/SKILL.md` 的 checkpoint 段
- **Then** 文档说明：(a) PreToolUse hook 自动机制（Write/Edit 前更新 interrupt）(b) `interrupt` 三字段含义（`active_file` / `last_action` / `checkpoint_at`）(c) 如何读取 interrupt 恢复（`/flow` 无参数展示 / resume 自动注入）
- **验证方式**: `bats test` —— grep `flow-kit/skills/flow/SKILL.md` 断言包含 "PreToolUse" / "自动" / "active_file" 关键词

### AC-8 · 安装脚本集成

- **Given** 执行 `install.sh` 完成全新安装
- **When** 检查 `.claude/settings.json`
- **Then** `hooks.PreToolUse` 数组包含 auto-checkpoint hook 条目（文件路径指向 `hooks/pre-tool/auto-checkpoint.sh`）
- **验证方式**: `bats test` —— 模拟安装后 `jq '.hooks.PreToolUse[] | select(contains("auto-checkpoint"))' .claude/settings.json` 非空

### AC-9 · checkpoint-lib 去重移除（R1 决议）

- **Given** `flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh` 的 `checkpoint_write()` 函数当前内置 `checkpoint_dedup_check()`（30s 同文件+同操作类型去重窗口）
- **When** 本次 change 的 4-dev 实现修改该文件
- **Then** `checkpoint_write()` 不再调用 `checkpoint_dedup_check()`（移除去重），每次调用必定更新 `interrupt`；`checkpoint_dedup_check()` 函数和 `CHECKPOINT_DEDUP_WINDOW` 变量已删除（grep 确认零残留）
- **验证方式**: `bats test` —— (a) grep `checkpoint_write()` 函数体不包含 `checkpoint_dedup_check` 调用 (b) 两次连续 `checkpoint_write("same-file" "编辑 same-file")` 调用间隔 < 1s，两次均返回 0，interrupt 的 `checkpoint_at` 不同

---

## 范围切分

### v1（本次必做）

- PreToolUse hook 脚本（拦截 Write/Edit 前更新 `interrupt`）
- 修改 `checkpoint-lib.sh`：移除去重逻辑（AC-9）
- 全阶段启用（phase 0~7，有活跃 change 即生效）
- 无活跃 change 时静默跳过
- Fail-open 容错（hook 异常不阻断工具调用）
- 非 Write/Edit 工具不触发
- bats 测试覆盖 AC-1 至 AC-9（9 条 AC）
- 更新 `flow-kit/skills/flow/SKILL.md` 文档（AC-7）
- 安装脚本集成（`install.sh` 注册新 hook，AC-8）

### v2（下一轮考虑，不本次）

- Post-tool 二次确认（编辑完成后再次更新 interrupt，标记"已完成"）
- `interrupt` 增加 `tool_name` 字段（区分 Write vs Edit）
- 同文件连续编辑的去抖（debounce）逻辑
- 跨 session 的 checkpoint 统计面板（`/flow checkpoint --history`）

### out（永远不做）

- 非 Write/Edit 工具（Read/Bash/Grep 等）的 checkpoint —— 这些工具不需要恢复定位
- 替换手动 `/flow checkpoint` 命令 —— hook 是补充，手动命令保留
- 替换 Stop hook G5 PROGRESS 日志 —— 那是会话级日志，这是文件级 checkpoint，互补
- checkpoint 数据的远程同步 / 备份 —— 超出 flow-kit 职责范围

---

## 非功能性需求

- **性能**: hook 执行延迟 < 10ms（jq 更新 ~200 字节 JSON），不可被用户感知
- **容量**: `active_file` 最长 4096 字符（Unix 文件系统路径限制）；`last_action` 截断至 200 字符；interrupt JSON 总大小 < 1KB
- **可访问性**: 无
- **安全**: hook 脚本仅读写 `.flow-active`，不访问网络或外部资源
- **兼容性**: 兼容现有 `.flow-active` 格式（仅更新 `interrupt` 和 `updated_at`，不修改其他字段）；兼容 bash 4.0+ 和 jq 1.5+
- **可观测性**: hook 失败时输出日志到 stderr（含时间戳 + 错误原因），便于调试

## 依赖与假设

- **依赖**: `.flow-active` 文件格式保持 JSON 且含 `change_id` / `phase` / `interrupt` / `updated_at` 字段
- **依赖**: `.claude/settings.json` 的 PreToolUse hooks 机制正常工作
- **依赖**: `jq` 已在系统 PATH 中（flow-kit 安装前提）
- **依赖**: `checkpoint-lib.sh` 的 `checkpoint_write()` 函数——本次 change 将移除去重但保留其原子写入 + JSON 校验能力
- **假设**: PreToolUse hook 能获取当前工具名（Write/Edit）和目标文件路径（通过 CC hook 协议传入的 JSON 参数）
- **假设**: 每次 Write/Edit 调用前 hook 都会触发（CC hook 机制保证）
- **注意**: `checkpoint_write()` 还写入 `failing_check` 字段（仅 prompt 层手动 `/flow checkpoint` 时填充；PreToolUse hook 自动写入时为空字符串 `""`）。AC-1/AC-2 Then 中列出的三字段为核心字段，实际 interrupt 对象可包含额外字段

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
