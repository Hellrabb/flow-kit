# REQUIREMENT: Pipeline Goal 扩展到 Phase 0 起始

- **Change ID**: goal-pipeline-phase0
- **关联**: `@.specs/goal-pipeline-phase0/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在发起新 change 时用 `--from 0` 设定全链路 pipeline goal，以便从变更提案到归档（0→7）半自动推进，每阶段 toll-gate 暂停确认。
- **US-2**：作为已走完 0-2 阶段的用户，我想用 `--from 3` 从拆任务阶段启动 pipeline，以便复用已完成产物，只管道化剩余执行链。
- **US-3**：作为已有 pipeline goal 使用习惯的用户，我希望不带 `--from` 时默认仍从 phase 4 起步，以便现有工作流不受影响。
- **US-4**：作为 pipeline goal 用户，我想在 condition 中引用多阶段的完成标志（如 "CHANGE.md 已确认 + 所有测试通过"），以便一个 goal 覆盖跨阶段复合验收条件。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 默认起始阶段（向后兼容）

- **Given** `.flow-active` 已存在，goal 为 null
- **When** 用户执行 `/flow goal "pnpm test && pnpm lint" --pipeline`（无 `--from`）
- **Then** `.flow-active.goal.start_phase` = `"4"`，`current_phase` = `"4"`，gates 包含 `4→5`、`5→6`、`6→7`
- **验证方式**: `jq '.goal.start_phase' .flow-active` 返回 `"4"`

### AC-2 · 从 Phase 0 全链路启动

- **Given** `.flow-active` 已存在，goal 为 null
- **When** 用户执行 `/flow goal "需求确认 + 测试通过 + review 无 critical" --pipeline --from 0`
- **Then** `.flow-active.goal.start_phase` = `"0"`，`current_phase` = `"0"`，gates 包含 `0→1`、`1→2`、`2→3`、`3→4`、`4→5`、`5→6`、`6→7`
- **验证方式**: `jq '.goal.start_phase' .flow-active` 返回 `"0"`；`jq '.goal.current_phase' .flow-active` 返回 `"0"`

### AC-3 · 从 Phase 3 中途启动

- **Given** 用户已完成 0-2 阶段（CHANGE.md、REQUIREMENT.md、DESIGN.md 已存在）
- **When** 用户执行 `/flow goal "任务拆解完成 + 所有测试通过" --pipeline --from 3`
- **Then** pipeline gates 为 `3→4`、`4→5`、`5→6`、`6→7`（不含 0→1、1→2、2→3）
- **验证方式**: `jq '.goal.gates | keys' .flow-active` 不包含 `"0→1"`、`"1→2"`、`"2→3"`

### AC-4 · 无效起始阶段拒绝

- **Given** `.flow-active` 已存在
- **When** 用户执行 `/flow goal "xxx" --pipeline --from 8` 或 `--from -1` 或 `--from abc`
- **Then** 输出错误信息 `❌ 无效起始阶段: <输入值>。有效值: 0, 1, 2, 3, 4, 5, 6, 7`，goal 不写入
- **验证方式**: 传入 `--from 8` 后 `jq '.goal' .flow-active` 仍为 `null`

### AC-5 · 0-3 阶段 toll-gate 暂停

- **Given** pipeline goal 从 phase 0 启动，当前阶段 phase 0 刚刚完成（CHANGE.md 已生成并经用户确认）
- **When** AI 完成阶段 0 的所有产物
- **Then** AI 输出 toll-gate 提示（含"是否进入下一阶段？"），等待用户回复确认后，才加载 phase 1 prompt 并更新 `current_phase` 为 `"1"`
- **验证方式**: 在 phase 0 产出后检查 AI 是否输出 toll-gate 提示（人工 UAT）

### AC-6 · 跨阶段复合 condition

- **Given** pipeline goal 设定了 condition `"CHANGE.md confirmed AND all tests pass"`
- **When** phase 0 完成且 CHANGE.md 经用户确认，但 phase 5 尚未执行
- **Then** goal evaluator 判定 condition 未满足（`all tests pass` 尚未达成）；当 phase 5 完成且所有测试通过后，evaluator 判定 condition 满足
- **验证方式**: 模拟 pipeline 各阶段完成状态，检查 evaluator 输出（人工 UAT 或脚本验证）

### AC-7 · 旧 pipeline goal 回读兼容

- **Given** `.flow-active` 中存在一个 2026-06-18 创建的 pipeline goal（goal 对象无 `start_phase` 字段）
- **When** 读取该 goal 的状态（`/flow goal` 无参数）
- **Then** `start_phase` 隐式视为 `"4"`，pipeline 进度显示正常（4→5→6→7），不报错
- **验证方式**: 手工构造无 `start_phase` 的 pipeline goal JSON，执行 `/flow goal` 检查输出

---

## 范围切分

### v1（本次必做）

- `/flow goal --from <n>` 参数（n ∈ {0,1,2,3,4,5,6,7}），默认 4
- `.flow-active.goal` 新增 `start_phase` 字段
- `gates` 动态生成（根据 start_phase 决定包含哪些 transition）
- 0-3 阶段 prompt 末尾 pipeline toll-gate 模板（与 4-7 一致："是否进入下一阶段？"）
- condition 语法支持 `AND` 连接跨阶段子条件
- 旧 pipeline goal 回读兼容（缺失 start_phase → 默认 "4"）
- `/flow goal` 无参数输出适配：显示 start_phase 和完整的阶段进度链

### v2（下一轮考虑，不本次）

- `--auto-advance <phases>` 参数：允许用户指定某些阶段跳过 toll-gate 自动推进
- 富条件 evaluator：支持 `file:<path> exists`、`phase:<n> done` 等结构化条件谓词
- Pipeline 进度可视化增强（如 ASCII 进度条）
- `OR` / `NOT` 逻辑运算符

### out（永远不做）

- **全自动无暂停模式**：0-3 阶段人工决策密集，始终保留 toll-gate；不提供 `--no-gates` 或 `--full-auto` 选项
- **非线性 pipeline**：不支持并行阶段或条件分支（如 "if UI 项目走 2a else 跳过"），pipeline 始终是线性推进
- **跨 change pipeline**：不支持一个 goal 跨越多个 change-id

---

## 非功能性需求

- **性能**: 无（CLI 工具，jq 操作，无延迟敏感路径）
- **可访问性**: 无
- **安全**: 无新增安全面（输入校验 `--from` 参数防止注入，沿用 jq --arg 安全传参）
- **兼容性**: 
  - 旧 `.flow-active`（无 `start_phase` 字段）回读兼容，隐式视为 `"4"`
  - `/flow goal` 不带 `--from` 行为不变
  - 依赖：`jq`、`bash`、`date`（与现有 `/flow` skill 一致）
- **可观测性**: `/flow goal` 无参数输出须展示 `start_phase` + 完整阶段链进度

## 依赖与假设

- **依赖**：现有 `/flow goal --pipeline` 实现（`.claude/skills/flow/` 中的 skill 文件）
- **依赖**：`.flow-active` JSON schema（当前 `goal` 字段结构）
- **假设**：用户对 pipeline goal 的 toll-gate 模型已有基本认知（来自 `pipeline-goal` change）
- **假设**：condition 语法扩展保持简单（`AND` 连接），不引入完整的布尔表达式解析器
- **假设**：GO.md 的路由逻辑（"pipeline goal 从 phase 4 起始"）需要更新以读 `start_phase` 字段

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
