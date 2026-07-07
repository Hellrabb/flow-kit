# REQUIREMENT: 用户指南全量更新 + interrupt/checkpoint 自动写入

- **Change ID**: user-guide-update
- **关联**: `@.specs/user-guide-update/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在用户指南中查到所有近期功能的用法说明，以便正确使用 gate_config L2/L3/both、pipeline goal、toll-gate、独立审查等机制。
- **US-2**：作为 flow-kit 用户，我想了解 interrupt/checkpoint 的完整用法（手动触发、字段含义、中断恢复流程），以便会话意外中断后能快速恢复上下文。
- **US-3**：作为 flow-kit 用户，我希望 flow-kit 在关键操作时自动写入 checkpoint，不再依赖我自己或 AI 记得手动调用 `/flow checkpoint`，以便中断恢复总是有最新的上下文可用。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 三份文档覆盖近期全部功能

- **Given** 用户分别打开 FLOW-KIT-用户指南.md、README.md、flow-kit-ecosystem-guide.md 三份文档
- **When** 查找以下功能：gate_config L2/L3/both 开关、gate-config preset（full/code-only/all 等）和数字简写（1,2,6 等）、pipeline goal 0→7 用法（--pipeline --from N --gate-config X）、toll-gate + 门禁条件、auto_advance + fallback 兜底、独立审查四层架构（PRESET_MAP → Prompt → Hook → L2-blind-review）、.done 真实性校验 + 三种威胁模型、gate_config 快照同步、L3 前置（front-loading）、transition 方向检测、31-auto-advance / 32-fallback-guard hook 模块
- **Then** 每份文档中均能找到对应章节，内容一致（无矛盾），且用法说明包含具体的命令示例
- **验证方式**: 对每份文档逐项运行覆盖全功能关键词的 grep 检查脚本（见 test/ 目录），或人工逐项对照功能清单确认

### AC-2 · interrupt/checkpoint 专项章节

- **Given** 用户打开 FLOW-KIT-用户指南.md 的 interrupt/checkpoint 章节
- **When** 用户阅读该章节
- **Then** 能获得以下全部信息：
  - interrupt 字段结构（active_file / last_action / failing_check / checkpoint_at）及各自含义
  - `/flow checkpoint <file> <description>` 完整用法 + 示例
  - 中断恢复流程：`.flow-active` 的 interrupt 非空时 `/flow-go 继续` 如何注入上下文
  - 手动 checkpoint 的推荐时机（开始编辑文件前、测试失败时、阶段切换前、toll-gate 暂停时）
  - `/flow` 无参数查看当前状态时 interrupt 字段的展示格式
- **验证方式**: 人工阅读确认覆盖上述 5 点

### AC-3 · auto-checkpoint 触发时机

- **Given** flow-kit 处于活跃状态（`.flow-active` 存在 + change_id 非 null）
- **When** AI 执行以下任一关键操作：
  1. 调用 Write/Edit 工具编辑文件
  2. 测试命令返回非零退出码
  3. 阶段切换（phase transition jq 执行）
  4. toll-gate 用户选择"暂停"（选项 2）
- **Then** `.flow-active` 的 `interrupt` 字段被自动更新：`active_file` 为项目根相对路径、`last_action` 为 ≤200 字符的描述、`checkpoint_at` 为 ISO8601 时间戳、`updated_at` 同步刷新
- **验证方式**: 模拟上述 4 种场景，检查 `.flow-active` 的 `interrupt.active_file`（相对路径格式）+ `interrupt.last_action`（非空≤200字符）+ `interrupt.checkpoint_at`（ISO8601 格式）是否非空

### AC-4 · auto-checkpoint 不干扰手动 checkpoint

- **Given** AI 在关键操作后自动写入了 checkpoint
- **When** 用户或 AI 随后手动调用 `/flow checkpoint <file> <description>`
- **Then** 手动 checkpoint 覆盖自动写入的值（以最后写入为准），不产生重复或冲突
- **验证方式**: 自动 checkpoint → 手动 `/flow checkpoint` → jq 读 `.flow-active.interrupt` 确认为手动值

### AC-5 · 中断恢复时上下文注入

- **Given** `.flow-active` 的 `interrupt` 非空（含 active_file、last_action、checkpoint_at）
- **When** 用户在下一会话中执行 `/flow-go 继续`
- **Then** GO.md 路由声明中显式展示中断上下文（文件 + 动作 + 时间），并注入到对应阶段 prompt 的恢复段
- **验证方式**: 模拟中断后执行 `/flow-go 继续`，检查以下确定性产物：① GO.md 路由声明文件中存在 `active_file` / `last_action` / `checkpoint_at` 字段引用（`grep -q` 确认）；② 对应阶段 prompt 文件的恢复段包含 interrupt 上下文注入逻辑；③ AI 回复仅作人工辅助确认，不作为通过/失败判据

### AC-6 · 文档与代码一致性

- **Given** FLOW-KIT-用户指南.md 中描述的每个命令/功能
- **When** 在安装了最新 flow-kit 的环境中执行对应命令
- **Then** 命令行为与文档描述一致（无过期语法、无已删除的参数、无错误的默认值）
- **验证方式**: 逐条对照用户指南中的命令示例在环境中实际执行

---

## 范围切分

### v1（本次必做）

- FLOW-KIT-用户指南.md 全量更新（覆盖 4 个 recent change 的全部用户可见功能）
- README.md + flow-kit-ecosystem-guide.md 一致性同步
- interrupt/checkpoint 专项章节（手动用法 + 中断恢复流程）
- auto-checkpoint 功能实现（prompt 层指令 + hook 层兜底）
- CONTEXT.md 术语追加（auto-checkpoint 相关新术语）

### v2（下一轮考虑，不本次）

- checkpoint 历史记录（保留最近 N 次 checkpoint 而非仅最后一次）
- checkpoint 自动摘要（从 transcript 提取上下文自动生成 description）
- 基于 interrupt 字段的跨 session 进度可视化

### out（永远不做）

- 实时协作 checkpoint（多用户共享 session 状态）
- checkpoint 内容加密/脱敏
- 基于 checkpoint 的自动回滚（恢复到 checkpoint 时刻的文件状态）

---

## 非功能性需求

- **性能**: 无（auto-checkpoint 仅 jq 写 JSON，< 10ms）
- **可访问性**: 无（非 UI 项目）
- **安全**: 无（checkpoint 不涉及凭证/敏感信息，仅存文件路径+操作描述）
- **兼容性**: auto-checkpoint 依赖 jq（已在 flow-kit 前置依赖中）；向后兼容现有 `.flow-active` 格式
- **可靠性**: auto-checkpoint 写入失败时 MUST 保留旧值不变（mv-atomic 策略）；写入后 MUST 校验 JSON 合法性（`jq empty`）；若校验失败则回滚到写入前状态
- **可观测性**: auto-checkpoint 写入失败时 SHOULD 输出 stderr 警告；静默失败为禁止行为

## 依赖与假设

- **依赖**: jq（已有）、`.flow-active` 文件（已有）
- **假设**: 
  - 四份近期 change 的 DESIGN.md / archive 产物可读取以提取功能清单
  - 三份文档当前内容以 2026-06-22 docs-sync 为基线

### 待 DESIGN 决议

- auto-checkpoint 实现边界：prompt 层指令 vs hook 层兜底 vs 混合策略。若需 hook 层兜底，需评估 CHANGE.md "不新增 hook 模块" 的范围约束是否允许修改现有 hook

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
