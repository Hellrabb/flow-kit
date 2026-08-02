# TDD 工作流 — 写前检查 · 破坏性变更协议 · 测试流程

> 本文件是 4-dev 阶段写代码前置检查的**单一源**。4-dev.md 通过 `@see reference/tdd-workflow.md` 引用此处。
> 修改这些协议时，**只改这一处**。

---

## 沿用既有抽象 grep（强制 · 对应 R6.4 / B5 老项目护栏）

> 写新代码前必须 grep 同类抽象。找到了用，找不到才另起。

### grep 检查清单

针对本任务 `action` 中提到的每个能力，执行 grep。**禁止凭印象判断"项目里没有"**。

| 任务里的能力 | grep 命令模板 | 找到了怎么办 |
|---|---|---|
| HTTP 请求 | `grep -rn "axios\|fetch\|httpClient\|apiClient" src/` | 用既有客户端，禁直接 fetch |
| 日期格式化 | `grep -rn "format.*[Dd]ate\|date.*[Ff]ormat" src/utils src/lib` | import 用 |
| 状态管理 | 看 `package.json` zustand / redux / mobx | 用现有 store 范式 |
| Repository / DAO | `grep -rn "class.*Repository\|@Entity\|@Repository" src/` | 沿用模式 |
| 错误处理 | `grep -rn "ErrorBoundary\|errorHandler\|class.*Error" src/` | 沿用 |
| 自定义 hooks | `find src -name 'use*.ts*'` | 看有没有相似的 |

### 写入 SUMMARY「6 维自查」段

每条 grep **必须**贴入 `<task-id>-SUMMARY.md` 的「6 维自查」段：

```
✅ 沿用既有抽象 grep（R6.4）：
- HTTP 请求：找到 src/lib/api-client.ts:1（统一封装 axios）→ 沿用
- 日期格式化：找到 src/utils/date.ts:8（formatDate）→ 沿用
- 通知组件：未找到 → 新建（DESIGN 0.5.3 已批准）
```

**禁止**："项目里好像没有"——必须有 grep 命令和结果作证。

---

## 扫 LESSONS（强制，对应 R1.8）

进入实现**之前**：

1. 用当前任务的 `files` 路径关键词、`action` 中的关键名词，grep `.specs/LESSONS.md`
2. 对每条命中且 `状态: active` 的 `L-NNN`，在本次执行计划里写一行：
   - 「已查阅 L-NNN，本次方案与之差异是 X」 或
   - 「已查阅 L-NNN，本次确认仍适用，所以不会重试该方案」
3. 若计划做的事与某条 active 条目完全相同 → 停下来按 R1.6 回答"本次与上次的差异是什么"，不允许盲目重试
4. 若 `.specs/LESSONS.md` 不存在 → 用 `@flow-kit/templates/LESSONS.md` 创建空骨架

---

## UI 任务额外检查（仅当任务涉及任何用户可见 UI）

判定标准：任务的 `files` 包含 `.css` / `.scss` / `.tsx` / `.vue` / `.jsx` / `.html` / `.svelte`，或 `action` 含 button / 颜色 / 字体 / 卡片 / 布局 / 动画 / 主题 等关键词。

命中时，进入实现**之前**还必须：

1. 加载 `@.specs/<id>/UI-DESIGN.md`（必须存在；不存在 → 停下来要求先跑 `@flow-kit/prompts/2a-ui-design.md`）
2. 加载 `@flow-kit/reference/ui-anti-patterns.md`，按当前任务的关键词 grep 相关章节
3. 加载 `@flow-kit/reference/frontend-engineer-rules.md`（**第 1 + 第 2 + 第 10 节必读**），其他节按输出类型按需读
4. 对每条命中的"强制禁忌"，在执行计划里**显式声明**
5. **Token 来源单一**：颜色 / 字体 / 间距 / 圆角 / 动效必须从 UI-DESIGN.md frontmatter 派生的 CSS variables / theme 文件中取
6. **React 三条硬规则马上写入计划**（仅 React 任务）：禁 `const styles` / 跨文件用 `Object.assign(window, ...)` / 禁 `scrollIntoView`
7. 实现完成后再扫一遍 anti-patterns + frontend-rules 第 10 节交付清单，写入 SUMMARY.md

> 装了 [impeccable](https://impeccable.style) 的项目可以用 `npx impeccable detect <files>` 自动化此扫描。

---

## 数据库 Schema 任务额外检查（涉及表 / 字段变更必跑 · 对应 R4.5）

> 这是 AI 开发最高频的事故源——改了 ORM model 没生迁移，跑起来报"表/字段不存在"。本段强制堵住。

**判定标准**：任务的 `action` 含「**新增表 / 加字段 / 改字段类型 / 加索引 / 加外键 / 重命名表/列 / 删表/列**」等关键词，或 `files` 涉及 ORM model / 迁移目录 / DDL。

命中时，进入实现**之前**必须：

### 声明 schema diff

在执行计划里**显式列出**：

```
## Schema Diff（本任务）
- 新增表：`<table>`（字段：col1 TYPE NOT NULL, col2 TYPE DEFAULT ...）+ 索引：...
- 改字段：`<table>.<col>` 类型 `<old>` → `<new>`，迁移策略：<是否需要 backfill / 兼容期>
- 删字段：`<table>.<col>`，迁移策略：<是否需要先双写过渡>
- 新增外键：`<table>.<col>` → `<ref-table>.<ref-col>`（ON DELETE: ...）
```

**禁止**没声明就开干。

### 选执行机制（按优先级探测项目）

按下面顺序探测，**用第一个命中的**：

| 优先级 | 检测信号 | 用什么 | 命令示例 |
|---|---|---|---|
| 1 | `prisma/schema.prisma` 存在 | Prisma | `npx prisma migrate dev --name <change-id>_<task-id>` |
| 2 | `alembic.ini` 存在 | Alembic | `alembic revision --autogenerate -m "<change-id> <task-id>"` |
| 3 | `db/migrate/` 目录（Rails） | Active Record | `rails generate migration <CamelName>` |
| 4 | `knexfile.*` 存在 | Knex | `npx knex migrate:make <change-id>_<task-id>` |
| 5 | `flyway.conf` / `flyway/sql/` 存在 | Flyway | 手写 `V<timestamp>__<change-id>_<task-id>.sql` 放进 `flyway/sql/` |
| 6 | `liquibase/changelog.xml` 存在 | Liquibase | 追加 `<changeSet>` 到 changelog |
| 7 | `migrations/` 或 `db/migrations/` 目录（无框架）| 手写 SQL | 文件名：`YYYYMMDDHHmm_<change-id>_<task-id>_<verb>.sql` |
| 8 | 全部都没有（裸项目）| **回退**：生成在 `.specs/<change-id>/migrations/` | 文件名同上，并在 SUMMARY 里登记"待用户搬到正式迁移目录" |

### 生成可逆迁移

每个迁移文件必须含 `up` 和 `down`（或对应框架的 migrate / rollback）：

```sql
-- up
ALTER TABLE users ADD COLUMN avatar_url VARCHAR(255) DEFAULT NULL;
CREATE INDEX idx_users_avatar_url ON users(avatar_url);

-- down
DROP INDEX idx_users_avatar_url ON users;
ALTER TABLE users DROP COLUMN avatar_url;
```

**禁止** down 段写 `-- 不可回滚`。即使破坏性变更（删字段），down 也要写"重建空字段 + 数据丢失警告"。

### 检测 DB 凭据 → 决定要不要现在执行

按下面顺序 grep 项目：
```
.env / .env.local / .env.development / .env.example
config/database.yml / config/database.json
application.yml / application.properties / application-*.yml
docker-compose.yml（DB 服务段）
prisma/schema.prisma 的 datasource 段
```

<!-- weak-model-guard: AskUserQuestion -->
❌ 如果你还没调用 AskUserQuestion 工具，现在停下来调用它。不要跳过。

**路径 A · 找到凭据** — 必须停下来反问用户。

**路径 B · 未找到凭据** — 直接走"只生成迁移文件"，在 `<task-id>-SUMMARY.md`「数据库迁移」段显式提醒执行命令 + 环境清单。

### 反幻觉（R6.1）

**禁止凭印象写迁移**：加字段 → 先 grep ORM model 确认；改字段类型 → 确认兼容性；加 NOT NULL → 确认有 DEFAULT 或先 backfill；加外键 → 确认引用列有索引。

### 5-test 关联

本步生成的迁移文件，5-test 第 4 轮「4.2 数据迁移测试」会再验证一次。这里生成的文件必须能被 trace（路径要写进 SUMMARY）。

---

## 破坏性变更高门槛（强制 · 对应 R4.6 / B4 老项目护栏）

> 删错代码 / 改坏公共接口是**老项目最高频真事故**。本段强制堵住。

**判定标准**：本任务 diff 命中下面**任一**条件 → 必须走本协议：

1. **删除既有代码** ≥ 5 行（不算空行 / 注释）
2. **改公共导出**：导出函数 / 类 / 接口的签名变更（参数 / 返回值 / 类型）
3. **改公共 API**：HTTP / GraphQL / gRPC 路由或 schema 变更
4. **删除文件** 或 重命名导出符号

### grep 引用图（必须）

对每个被删 / 改签名的符号，执行 grep 贴出完整结果（哪怕 0 命中也要贴 0 命中的 grep，证明你查了）。

### 列出影响清单

把 grep 结果整理成清单，**含间接影响**（子组件 / cron job / 客户端代码 / 文档）。

### 反问用户（停下来）

把 grep 结果**贴出来反问用户**，提供 4 选项（直接删除+同步改 / 留兼容期+@deprecated / 写codemod / 不删了）。无人工确认前不执行。

### 回归测试覆盖（强制 · 自动执行 · L-010）

无论选哪个方案，必须确保删除/改动的旧路径**有测试覆盖**。

#### 自动 bats 执行（强制 · L2 自检 gate）

反问用户确认后，**立即**自动执行全量测试：

```bash
# 先检查 bats 是否可用
npx bats --version 2>/dev/null || { echo "⚠️ bats 不可用，跳过自动测试（WARNING 非阻断）"; }

# 可用则跑全量
npx bats test/ --formatter tap 2>&1
```

#### 结果判定

```
bats 结果判定：
  0 failures → ✅ 输出 "bats: N tests, 0 failures" 摘要，继续
  ≥1 failure → 🔴 阻断：输出失败测试清单，暂停流程，禁止进入 toll-gate
```

#### 结果写入 SUMMARY

在 `<task-id>-SUMMARY.md`「破坏性变更」段追加 bats 结果字段：
```
| bats 结果 | N tests / M failures / N-M passed / 耗时 Xs |
```

#### L2 自检 gate 填空

```
1.8 破坏性变更 bats 自检：
  [ ] bats 已执行：npx bats test/ 已跑（或 bats 不可用已标 WARNING）
  [ ] 结果：___ tests, ___ failures, ___ passed
  [ ] 阻断判定：✅ 0 fail 继续 / 🔴 ≥1 fail 已暂停（圈选）
```

> **注意**：bats 不可用时降级为 WARNING 而非阻断（避免因环境问题误伤）。但必须显式标注"bats 不可用，跳过自动验证"。

### 写入 SUMMARY「破坏性变更」段

把以上全部内容写入 `<task-id>-SUMMARY.md` 的「破坏性变更」段。

### 何时**不必**走本协议

- 重构内部实现（导出符号不变）
- 加新参数但保持向后兼容（带默认值的可选参数）
- 删 < 5 行实现细节（无外部引用）

---

## TDD 优先（默认开启）

按 RED → GREEN → REFACTOR 顺序：

1. **RED**：先写一个失败的测试（直接派生自 AC 或 done 条件）
2. 跑测试，**确认它真的失败**（必须看到失败输出）
3. **GREEN**：写最少代码让它通过
4. 跑测试，**确认它真的通过**（必须看到通过输出）
5. **REFACTOR**：在测试保护下整理实现

> 例外：纯文档/纯配置任务可跳过 TDD，但需在 SUMMARY.md 里说明为何跳过。

---

> **协议源声明**：本文件由 `cleanup-debt-batch-2026-08` change (2026-08-03) L-068 从 `flow-kit/prompts/4-dev.md` 抽取创建。原 4-dev.md `### 1.4`-`### 1.8` + `### 2.` 段内容。
