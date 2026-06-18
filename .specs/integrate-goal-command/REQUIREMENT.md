# REQUIREMENT: 整合 CC /goal 到 flow-kit

- **Change ID**: integrate-goal-command
- **关联**: `@.specs/integrate-goal-command/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 4-dev 阶段的开发者，我想通过 `/flow goal "<条件>"` 设定完成条件，让 Claude 自主跨 turn 迭代直到条件满足，以便我不需要逐 turn 手动提示"继续"。
- **US-2**：作为 4-dev 阶段的开发者，我想在进入 task 执行时自动看到从 REQUIREMENT.md AC 提取的 goal 建议，以便一键确认或修改后启动自主迭代。
- **US-3**：作为任何阶段的用户，我想在 GO.md 路由声明中看到当前 goal 状态，以便 compaction 或恢复后不丢失方向。
- **US-4**：作为使用旧版 CC 的用户，我想 flow-kit 自动回退到内置迭代模式，以便 /goal 功能在所有 CC 版本上都可用。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 设定 goal

- **Given** 当前有活跃 flow（`.flow-active` 存在，phase=4），CC 版本 ≥ v2.1.139
- **When** 用户执行 `/flow goal "pnpm test passes and lint is clean"`
- **Then** `.flow-active` 的 `goal.condition` 字段写入该条件，`goal.active_since` 为当前时间，`goal.status` 为 `active`；CC 原生 `/goal` 被调用
- **验证方式**: `jq '.goal.condition' .flow-active` 返回 `"pnpm test passes and lint is clean"`

### AC-2 · 查看 goal 状态

- **Given** goal 已设定（`.flow-active` goal.status=active）
- **When** 用户执行 `/flow goal`（无参数）
- **Then** 输出当前条件、运行时长、turns 计数、status
- **验证方式**: `/flow goal` 输出含 `condition:` + `status: active` + `active_since:`

### AC-3 · 清除 goal

- **Given** goal 已设定
- **When** 用户执行 `/flow goal clear`
- **Then** `.flow-active` 的 `goal` 字段置为 `null`；CC 原生 `/goal clear` 被调用
- **验证方式**: `jq '.goal' .flow-active` 返回 `null`

### AC-4 · 内置回退（CC < v2.1.139）

- **Given** CC 版本 < v2.1.139（无原生 `/goal`），goal 已设定
- **When** 用户进入 4-dev 且有 active goal
- **Then** flow-kit 使用内置 prompt 驱动的迭代循环：每个 turn 结束后检查条件是否满足，满足则清除 goal 并停止，否则继续下一 turn
- **验证方式**: 在无原生 /goal 环境设定 goal，验证 AI 能自主完成 ≥2 个 turn 直到条件满足

### AC-5 · 自动提取 goal 建议

- **Given** `.specs/<id>/REQUIREMENT.md` 有至少 1 条 Given/When/Then AC
- **When** 用户进入 4-dev 阶段且当前无 active goal
- **Then** 系统自动读取 REQUIREMENT.md 的 AC 生成 1 条 goal 建议文本，展示给用户确认或修改
- **验证方式**: 进入 4-dev 时输出含 `建议 goal：` + 从 AC 提取的条件

### AC-6 · Goal 在路由声明可见

- **Given** goal 已设定
- **When** 任何 flow-kit 阶段的路由声明被输出
- **Then** 路由声明包含 `✅ Goal: <condition> (active, <N> turns)`
- **验证方式**: 阶段路由输出含 `✅ Goal:`

### AC-7 · Goal 恢复时存活

- **Given** goal 已设定，session 被 compaction 或重启
- **When** SessionStart hook 触发 flow-kit-resume
- **Then** 恢复横幅输出当前 goal 条件
- **验证方式**: `--resume` 或 `--continue` 后，hook 横幅含 goal 条件

---

## 范围切分

### v1（本次必做）

- `.flow-active` schema 扩展（`goal` 字段）
- `flow` skill 新增 `/flow goal` 子命令（set / status / clear）
- CC 原生 `/goal` 委托（v2.1.139+）
- 内置回退迭代循环（< v2.1.139）
- GO.md 路由声明展示 goal
- `4-dev.md` 入场自动提取 goal 建议
- `flow-kit-resume.sh` 恢复时输出 goal
- 更新 CONTEXT.md 术语表

### v2（下一轮考虑，不本次）

- Goal 模板库/预设（常见条件模板，如 "所有测试通过"、"lint 干净"）
- Goal 执行历史持久化（`.specs/` 下记录历史 goal 及结果）
- 多 goal 并行（一个 session 多个活跃 goal 分派到不同 task）
- 在 5-test / 6-review 阶段也支持 goal 自主迭代
- 自定义 evaluator 模型（不用 Haiku，用用户指定的模型做条件判断）

### out（永远不做）

- 独立的 evaluator API 调用（内置回退只用 prompt 文本检查，不调外部 API 做判断）
- Goal 与 Managed Agents CMA Outcome 的双向同步（两套系统有本质不同的生命周期）
- Goal 条件编辑器 GUI（CLI 纯文本交互）

---

## 非功能性需求

- **性能**: Goal 状态读写 ≤ 50ms（jq 单字段操作），不影响阶段路由延迟
- **可访问性**: 无（CLI 工具）
- **安全**: 无新增安全面（仅操作本地 `.flow-active` 文件）
- **兼容性**: CC ≥ v2.1.71（低于此版本无法检测原生 /goal 能力，直接走内置回退）；`.flow-active` 增加可选字段 `goal`，旧版 flow-kit 忽略未知字段 → 向前兼容
- **可观测性**: 每次 goal 状态变更记录 `updated_at` 时间戳

## 依赖与假设

- **依赖**: CC 原生 `/goal` 命令（v2.1.139+），通过 `claude --help` 或尝试调用来检测可用性
- **依赖**: jq（已有，flow skill 已依赖）
- **假设**: REQUIREMENT.md 的 AC 使用 Given/When/Then 格式，goal 提取逻辑依赖此格式
- **假设**: 内置回退的迭代循环在 4-dev 阶段内运行，用户可 Ctrl+C 中断
- **假设**: 1 个 session 同时只有 1 个 active goal

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
