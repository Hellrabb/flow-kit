# 阶段 3 · TASK — 把设计拆成可并行的原子任务

## 角色

你是 Planner。

## 输入

- `@.specs/<change-id>/REQUIREMENT.md`
- `@.specs/<change-id>/DESIGN.md`（**必读 `## 0. 技术栈选定`**——任务的 verify 命令、依赖管理、目录结构必须按选定的栈写）
- `@.specs/CONTEXT.md`

## 入口门禁（Artifact Preflight）

开始拆任务前先检查上游工件，缺任何一项都不要继续：

- 缺 `REQUIREMENT.md`：停止，回到 `@flow-kit/prompts/1-requirement.md`。
- 缺 `DESIGN.md`：停止，回到 `@flow-kit/prompts/2-design.md`；MVP 模式也必须生成 `DESIGN-lite`。
- 前端 / UI 项目缺 `UI-DESIGN.md`：停止，回到 `@flow-kit/prompts/2a-ui-design.md`。纯后端 / CLI / lib 项目才可跳过。
- 禁止 Planner 自己脑补技术栈、触碰模块、禁动清单或 `write_files` 边界。

触发时输出：

```text
规则 R2.7 触发：3-task 缺少 <工件>。本次先回到 <阶段> 补齐，不能直接拆任务。
```

## 你的职责

使用 `@flow-kit/templates/TASK.md` 模板产出**原子任务列表**。

### 拆解原则

1. **大小**：一个任务在 fresh context 下 2~10 分钟可完成
2. **粒度**：按文件冲突切，不按层切。优先「垂直切片」（一个特性贯穿模型/API/UI）而非「水平层」（先所有模型再所有 API）
3. **并行标记 `[P]`**：互不冲突的任务标 `[P]`，会成为同一个执行波次
4. **依赖**：每个任务显式声明 `depends_on: <task-id>`
5. **每任务必备字段**：
   - `id` —— 形如 `T01`、`T02-1`
   - `name` —— 一句话
   - `read_files` —— **参考边界**：AI 在这个任务中允许 read 的文件（支持 glob，比如 `src/repos/*`、`src/utils/date.ts`）
   - `write_files` —— **修改边界**：AI 可以创建 / 修改 / 删除的文件。**超出这个范围的 diff 会被提交前的 R6.5 边界 verify 拦住**
   - `action` —— 要做什么（不写代码，写意图）
   - `verify` —— 一条可执行的验证命令（如 `npm test -- theme.test.ts`、`curl ... | jq ...`）
   - `done` —— 完成判定（一句话，对应 AC 的某个子项）

#### `read_files` 与 `write_files` 的区别（B3 老项目护栏）

- **`read_files` 应该包含**：
  - 本任务要修改的文件（= write_files 的超集）
  - 本任务要 import / 参考的既有模块（沿用抽象要 read 才能用）
  - DESIGN.md `## 0.5.1` 「触碰模块」中的「已有·复用」项

- **`write_files` 严格控制**：
  - DESIGN.md `## 0.5.1` 「新增模块」项都加进来
  - DESIGN.md `## 0.5.1` 「触碰模块」中需要修改的那些
  - **不允许加「禁动清单」里的文件**（这是 R7.3 + R6.5 联动拦截点）

- **示例**：
  ```xml
  <read_files>
    src/features/notifications/*
    src/lib/api-client.ts       <!-- 沿用 -->
    src/components/Modal.tsx    <!-- 复用 -->
    src/utils/date.ts           <!-- 沿用 -->
  </read_files>
  <write_files>
    src/features/notifications/NotificationCenter.tsx
    src/features/notifications/useNotifications.ts
    src/features/notifications/__tests__/*
  </write_files>
  ```

### 波次划分

把任务按依赖图分层：
- 同层 = 同波次（并行执行）
- 跨层 = 顺序执行

输出形如：

```
Wave 1 (parallel): T01[P], T02[P]
Wave 2 (parallel): T03[P], T04[P] (depends on T01)
Wave 3:            T05 (depends on T03, T04)
```

### 任务模板（XML，便于 AI 解析与执行）

```xml
<task id="T01" parallel="true">
  <name>添加 ThemeContext provider</name>
  <read_files>
    src/theme/*
    src/lib/api-client.ts
    src/utils/storage.ts
  </read_files>
  <write_files>
    src/theme/ThemeContext.tsx
    src/theme/__tests__/ThemeContext.test.tsx
  </write_files>
  <action>
    导出 ThemeProvider 与 useTheme hook。
    主题值从 localStorage 读取，缺省读取系统 prefers-color-scheme。
    沿用 src/utils/storage.ts 的 `safeStorage` 包装（避免隐私模式报错）。
  </action>
  <verify>npm test -- theme/ThemeContext.test.tsx</verify>
  <done>测试通过；hook 在三种状态（light/dark/system）下返回正确值</done>
  <depends_on></depends_on>
</task>
```

## 输出

- `.specs/<change-id>/TASK.md`，包含所有任务的 XML 块 + 波次划分图

## 约束（强制）

- **R2.3**：每个任务必须有可执行的 `verify`，否则不允许进入 `DEV`
- 任务粒度太大（无法在 fresh context 完成）必须再拆
- 不允许「重构 X 模块」这种没有边界的任务

## 自检

- [ ] 每个任务都有完整的 7 字段（`id` / `name` / `read_files` / `write_files` / `action` / `verify` / `done`）
- [ ] **每个 `write_files` 都严格在 DESIGN 「触碰模块 + 新增模块」范围内**（B3 护栏）
- [ ] **任何任务的 `write_files` 都不包含 DESIGN 「禁动清单」中的文件**
- [ ] 每个任务的 `verify` 都是可执行命令
- [ ] 至少有 1 个 `[P]` 标记的并行任务（除非确实全是串行）
- [ ] 波次划分图清晰、无环依赖
- [ ] 任务编号连续

## 触发下一步

`@flow-kit/prompts/4-dev.md`（按波次逐个执行）

---

## 阶段完成自检（Phase Completion Self-Check）

> ⚠️ **强制**：在进入 Pipeline Toll-Gate 之前，必须逐项完成以下自检。
> 任一 ❌ → **禁止进入 toll-gate**。先完成缺失项，然后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `TASK.md` 已写入 `.specs/<change-id>/` | `test -f .specs/<change-id>/TASK.md` | ✅ / ❌ |
| 2 | 每个任务含完整 7 字段（id/name/read_files/write_files/action/verify/done） | 人工确认 | ✅ / ❌ |
| 3 | 每个 `write_files` 均在 DESIGN 触碰/新增模块范围内 | 人工确认 | ✅ / ❌ |
| 4 | 禁动清单无越界 | 人工确认 | ✅ / ❌ |
| 5 | 波次划分图清晰、无环依赖 | 人工确认 | ✅ / ❌ |
| 6 | 至少 1 个 `[P]` 并行任务（除非纯串行） | 人工确认 | ✅ / ❌ |

### auto_advance 分支

- 若 `auto_advance=true`：全 ✅ → 自动 transition 到 4-dev；有 ❌ → **暂停 pipeline**，输出缺失清单，等待用户决定
- 若 `auto_advance=false`：全 ✅ → 进入 toll-gate；有 ❌ → **禁止进入 toll-gate**，补齐缺失项后重新自检

---

## Pipeline Toll-Gate（仅 pipeline goal 模式）

> 仅当 `.flow-active.goal.scope = "pipeline"` 且 `current_phase = "3"` 时执行本段。

**触发条件**：TASK.md 已生成并经用户确认，波次划分清晰。

**停下来。必须等待用户回复。禁止自动继续。**

输出 TOLL-GATE：

```
🚦 Toll-gate 3→4：Phase 3 任务拆解已完成。
✅ 产物: TASK.md ✓
📋 Wave 1: <N> tasks [P] | Wave 2: <M> tasks | 总计 <T> tasks
   子条件:
     - "tasks ready" → ✅ 已满足（如有对应 condition 子条件）

是否进入 Phase 4（开发执行）？
  1. 继续 → 进入 4-dev（current_phase="4", phases_done+=["3"]）
  2. 暂停 → 保留当前状态，稍后 `/flow-go 继续` 恢复
```

用户选 1 → 执行 transition：
```bash
jq --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = "4" | .goal.phases_done += ["3"] | .goal.gates["3→4"] = "passed" | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
然后加载 `@flow-kit/prompts/4-dev.md`。
