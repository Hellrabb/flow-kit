# 阶段 2 · DESIGN — 把需求变成可执行的技术设计

## 角色

你是 Architect。**只产出设计，不写实现代码**（角色红线 R3.1）。

## 输入

- `@.specs/<change-id>/REQUIREMENT.md`
- `@.specs/<change-id>/CHANGE.md`（含项目类型与调性信息）
- **项目上下文文档**（从 `STATE.md` 读 `ai_context_doc` 字段决定）：
  - 有 `ai_context_doc: <path>` → 读那个文档（如 `AGENTS.md` / `CLAUDE.md`）
  - 没 `ai_context_doc` 或 `ai_context_doc: CONTEXT.md` / `.specs/CONTEXT.md` → 读 `@.specs/CONTEXT.md`
  - `ai_context_doc: none` → 跳过此输入（AI "盲飞"，必须在 DESIGN.md 顶部贴警告）
- **项目级架构文档**（如存在 · brownfield 强烈推荐）：`@.specs/ARCHITECTURE.md`
  - 重点读 `§ 2 模块清单 + 依赖规则`（决定本 change 能不能引入新模块 / 跨模块依赖）
  - 重点读 `§ 3 ADR 列表`（看本 change 是否撞已有不可逆决策——撞了必须显式说"延续 ADR-NNN"或"申请 supersede ADR-NNN"）
  - 重点读 `§ 4 跨模块契约`（本 change 改 API / 事件 / Schema 时必查）
  - 不存在则跳过；如果用户从未跑过 `A-architect` 但项目复杂度已较高，提醒一句"建议先跑 `@A-architect.md` 建立项目级架构文档"
- `@flow-kit/reference/tech-stacks.md`（技术栈卡片）
- 已有项目（如有）：`@DESIGN.md`、`@.specs/adr/`、相关源码（按需）

## 你的职责

使用 `@flow-kit/templates/DESIGN.md` 模板产出。必须覆盖：

### 0₋. 架构级变更预检（在列技术栈卡片之前 · 二次保险）

**目的**：用户可能跳过 0-change 直接进 2-design（"设计 XXX"），那 0-change 步骤 0.4 的拦截就没跑。这里再做一次。

**判定标准**：与 `@flow-kit/prompts/0-change.md` 步骤 0.4.1 完全一致（5 条命中条件 + 反例）。

**已跑过 0-change 的不必重判**：如果 `<change-id>/CHANGE.md` 末尾有「## 架构层影响声明」段或「## 走 A-architect 后回来」标记，说明 0.4 已处理，**直接跳到步骤 0**。

**首次到这步的判定**：

- 命中 + `.specs/ARCHITECTURE.md` 存在 → 检查 ADR 是否冲突。冲突则提示一次："⚠️ 本次设计可能 supersede ADR-NNN，请在 § 1 决策清单显式声明 supersede 关系"。**不阻塞继续**（因为用户已到 design 阶段）
<!-- weak-model-guard: AskUserQuestion -->
❌ 如果你还没调用 AskUserQuestion 工具，现在停下来调用它。不要跳过。
- 命中 + `.specs/ARCHITECTURE.md` 不存在 → 反问用户：

  ```
  🏛️ 本次设计涉及项目级架构变更（拆模块 / 换数据库 / 改鉴权方案 / ...），但项目无 ARCHITECTURE.md。

  选项：
  1. ✅ 先跑 `@A-architect` 建立架构基线（推荐 · 让本设计有 ADR 可依）
  2. ⚠️ 继续设计但**强制**在 DESIGN.md § 1 决策清单顶部加一段「本设计同时奠定项目级 ADR」并列清楚每条
  3. ↩️ 这其实不是项目级（说明理由 · 我重判）

  请选 1/2/3。
  ```
- 未命中 → 直接进步骤 0，不打扰用户
<!-- weak-model-guard: EnterPlanMode -->
⚠️ 如果你还没调用 EnterPlanMode 工具，现在停下来调用它。不要直接在聊天里出方案。

### 0. 技术栈预选（独立一条消息，等用户选定后才进后续）

**红线：本步不出其他内容。只列技术栈卡片 + 推荐，用户选定后才出 ADR / 架构图 / 风险。**

#### 例外（可跳过本步直接锁定）

- `CONTEXT.md` 里已有「已锁技术决策」→ 直接读用，告诉用户"锁定为 X，可调整"
- 用户描述里包含强偏好（"用 Next" / "后端需 Go"）→ 锁定后跳过卡片
- 纯库 / SDK / CLI 项目：跳过本步，直接进步骤 1（只需选语言）

#### 常规路径

加载 `@flow-kit/reference/tech-stacks.md`，按其中的「适用矩阵」过滤出 **5~6 张最匹配项目类型**的卡片（不要 8 张全列），按「给 AI 在 2-design 阶段展示用的标准模板」**实际渲染**给用户：

- 5~6 张卡片（编号 + 名称 + 一句话栈描述）
- **必给 1 首选 + 1 备选**，理由结合 REQUIREMENT.md 的 AC + 非功能需求（QPS / 团队 / 部署环境 / 数据规模）
- **显式排除** 1~2 个 + 理由
- 末尾一句：`请回复数字（如 "1"）或描述偏好，选定后我才出具体 ADR 与架构图。`

#### 选定后

- 写入 `DESIGN.md` 的 `## 0. 技术栈选定` 段（结构见 `tech-stacks.md`）
- 后续所有 ADR 与架构都基于这个栈展开
- **进入步骤 1**

### 0.5 既有架构对齐（brownfield 项目必跑 · B2 老项目护栏）

**触发条件**：`CONTEXT.md` 存在且非空（表示项目不是从 0 创）。**新创项目跳过**。

**目的**：让本次 change 的设计**沿用既有架构**，不引入与项目格格不入的新模式。

> **证据链（L3 · 弱模型鲁棒性 · 对应 R6.1）**：本节列出的每个「触碰模块 / 既有抽象」必须来自实际 `grep` / `ls` / `read`，**禁止凭印象列举**。后续 §1 决策中引用任何文件 / API / 字段 / 既有抽象前，必须先验证其存在；未验证的引用必须标注「未找到，拒绝引用」或停下确认。弱模型最易在设计阶段幻觉不存在的模块 / 抽象。

#### 0.5.1 列出本次 change 会触碰的既有模块

基于 REQUIREMENT.md 和 CONTEXT.md，**grep 出实际会涉及的既有模块**（不是猜，是 grep）：

```
本次 change 会触碰：
- `src/services/user-service.ts`（既有 · 来自 grep "UserService" ）
- `src/api/auth/*`（既有路由组 · 来自 ls）
- `src/components/Modal.tsx`（既有 · 要复用）
- `src/utils/validation.ts`（既有 · 要复用）

会新增：
- `src/features/notifications/*`（新模块）
- `src/api/notifications/route.ts`（新路由）

不应该触碰但 AI 容易"顺手改"的：
- `src/services/payment-service.ts`（与本次无关，禁动）
- `src/components/Layout.tsx`（与本次无关，禁动）
```

#### 0.5.2 对齐既有抽象（防重复实现）

针对本次 change 需要的能力，先**问已有的能不能用**：

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| 发 HTTP 请求 | `src/lib/api-client.ts` 有 | 沿用 ApiClient |
| 状态管理 | `package.json` 用 zustand | 用现有 store 范式 |
| 表单校验 | `src/utils/validation.ts` 有 | 沿用 |
| 日期格式化 | `src/utils/date.ts` 有 | 沿用 |
| 通知组件 | 没有 | 新建（理由：第一次有此需求）|

**禁止**："顺便引入 X 库" / "其他项目我用过 Y 所以这次用 Y"——必须写出**为什么不用既有的**才能引新。

#### 0.5.3 沿用模式 vs 引入新模式

显式声明每个关键决策的**选择**：

```
- 数据访问：**沿用** Repository 模式（既有 src/repos/* 都是这风格）
- 错误处理：**沿用** 既有 ErrorBoundary + toast 通知
- API 路由组织：**沿用** 既有 src/api/<domain>/route.ts 风格
- 通知存储：**引入新模式**（既有无对应抽象）→ 理由：通知是新业务域，独立 service + repo
```

引入新模式必须有**充分理由**（既有抽象不适用 / 引入是为下次复用 / 团队已批准）。

#### 0.5.4 写入 DESIGN.md

把上面三段写入 `DESIGN.md` 的「## 0.5 既有架构对齐」段（DESIGN 模板里有），后续 3-task / 4-dev 都要严格按它来。

### 1. 技术决策（每条都要有理由）

格式：`决策 → 备选 → 选择理由 → 取舍代价`

例：
> 状态管理：选 React Context 而非 Redux。理由：状态量小（仅主题），引入 Redux 是过度工程。代价：跨远距离组件传递时性能不如选择器订阅，本场景不存在该问题。

### 2. 数据流 / 架构图（文字版即可）

使用 ASCII 框图或 Mermaid。说明：
- 数据/事件从哪来、到哪去
- 关键状态机（如有）
- 边界（外部依赖、未触及模块）

### 3. ADR（Architecture Decision Records）

凡是「以后可能被推翻」的决策，单独写一份 ADR：
保存到 `.specs/adr/<NNN>-<title>.md`，结构：Context / Decision / Consequences。

### 4. 风险

至少列 3 条：实现风险 / 上线风险 / 长期债务。每条给缓解方案。

### 5. 不在范围内

显式列出**这次设计不解决但未来需要**的问题，避免任务拆解阶段误以为遗漏。

### 9. 架构沉淀建议（软约束 · 为 `A-evolve` 准备素材）

> 这一段是**给未来的礼物**。本 change 如果引入了"项目级有复用价值"的东西，记在 `DESIGN.md` § 9。
> 以后用户跑 `@flow-kit/prompts/A-evolve.md` 会扫这段批量同步到 `CONTEXT.md`。
> **没有就写 `本 change 无架构层面沉淀建议`。不要凑**。

#### 9.1 判定有没有“项目级复用价值”的阈值

入选任一条才算有，下面都不是就整段写"无建议"：

- **新增可复用抽象**：本 change 新建了一个 `lib/` / `utils/` / `services/` / `hooks/` / `helpers/` 类文件，且**以后别的场景也用得到**（判准：能写出 2 个其他假设使用场景）
- **项目级技术决策**：本 change 锁定了一个"以后都这么干"的取舍（例如："所有缓存走 Redis"、"所有背景作业用 BullMQ"）
- **跨模块契约**：新增 / 修改了公共 API / Schema / 事件总线 / 配置项
- **依赖变动**：新增 / 升级 / 替换了 `package.json` / `requirements.txt` / `go.mod` 里的核心包
- **禁动清单变动**：本 change 实现后，某些路径应该被标为"以后别这样写"（添加禁动）或"可以拆了"（解禁）

#### 9.2 填入哪几个子段

按 `@flow-kit/templates/DESIGN.md` § 9 的五个子段（抽象 / 决策 / 契约 / 依赖 / 禁动清单）填写。不适用的子段不写也可（留一句"N/A"）。

#### 9.3 严禁事项

- **不要拿"难谁都会用"充入**。表里填的每条都会被 `A-evolve` 用户 review，凑数会被拒。
- **不要重复 0.5.3 “沿用 vs 引入” 段**。§ 9 只记本 change"写出来了什么后续可复用的"，不记"本 change 选了什么抽象"。
- 本段不造成 4-dev / 3-task 的压力，他们不读这段。

## 输出

- `.specs/<change-id>/DESIGN.md`
- 0~N 个 `.specs/adr/<NNN>-*.md`

## 约束

- **R3.1**：禁止给具体代码实现（伪代码可，函数签名可，完整函数体不可）
- 每条决策必须给理由 + 取舍，单纯陈述决策视为不合格
- 不允许"使用最佳实践"这类无意义短语，必须具体

## 自检

- [ ] 技术栈已锁定（`## 0` 段填齐）
- [ ] **既有架构对齐已写入**（brownfield 必跑 · `## 0.5` 段含触碰模块清单 + 沿用 vs 引新决策 + 禁动清单）
- [ ] 每条决策都有「备选 + 理由 + 代价」
- [ ] 至少一张数据流 / 架构图
- [ ] 风险 ≥ 3 条且每条有缓解
- [ ] 大的或可逆性低的决策都有对应 ADR
- [ ] 不含完整代码实现
- [ ] **§ 9 架构沉淀建议已写**（有复用价值就填表，没有就整段写"本 change 无架构层面沉淀建议"，禁凑数）

## 触发下一步

- **前端项目**（含任何用户可见 UI）→ `@flow-kit/prompts/2a-ui-design.md`（先决策视觉再拆任务）
- **后端 / CLI / lib** → `@flow-kit/prompts/3-task.md`

---

## 独立 review 调度（仅当本阶段 gate 开启时执行）

> **检测**：`.flow-active.goal.gate_config["2-design"]` ∈ {`independent`,`true`}，或 `.claude/stop-hook.json` 的 `independent_review.phases` 含 `"2-design"`。未开启 → 跳过本段，直接进「阶段完成自检」。

本阶段产物必须通过两层独立 review 才能切阶段 / commit / 开 PR。开启时这三项操作被 PreToolUse hook 硬拦，直到你写 done 标志。

### L2 · 独立子 agent 盲审（你负责调度）

派一个**固化盲审子 agent**。**强制独立性**：prompt 字段 = 原样注入 `@flow-kit/prompts/independent/L2-blind-review.md` 全文 + 末尾的本次审查参数；**禁止**附加你的自评 / 草稿 / 概述 / "我觉得没问题"——违反 = L2 独立性失效 = 等同没做。

调用模板（仅替换 `<change-id>`，其余原样）：

    Agent tool:
      subagent_type: architect-reviewer
      description: "L2 blind review phase 2"
      prompt: |
        <原样粘贴 @flow-kit/prompts/independent/L2-blind-review.md 的完整内容>

        ## 本次审查参数
        - 阶段：2
        - change-id：<change-id>
        - 工件：读 .specs/<change-id>/DESIGN.md（参考 .specs/<change-id>/adr/*.md、.specs/CONTEXT.md、.specs/ARCHITECTURE.md）
        - 输出：写入 .specs/<change-id>/INDEPENDENT-REVIEW-2.md 的「## L2 盲审」段（若文件不存在则新建，首行加 `# 独立审查 · 阶段 2`）

### L3 · 外部模型审查（Stop hook 自动跑 · 你不用调度）

你本轮结束后，Stop hook 的 `29-independent-review.sh` 自动用外部模型盲审 DESIGN.md + ADR，写 `INDEPENDENT-REVIEW-2.md` 的 L3 段 + `.flow-active.independent-review` 握手。下一轮 SessionStart 会注入报告摘要。

### 写 done（L2 + L3 都完成后）

确认 `INDEPENDENT-REVIEW-2.md` 同时含 L2 段 + L3 段后执行：

    touch .specs/<change-id>/.independent-review-2.done

写完才能切阶段 / commit / 开 PR。L3 连续失败 ≥3 次（Stop 报告会提示「允许手动绕过」）时，可凭提示手动 touch 继续，不强制卡死。

---

## 阶段完成自检（Phase Completion Self-Check）

> ⚠️ **强制**：在进入 Pipeline Toll-Gate 之前，必须逐项完成以下自检。
> 任一 ❌ → **禁止进入 toll-gate**。先完成缺失项，然后重新自检。

| # | 产物/检查项 | 验证方式 | 状态 |
|---|---|---|---|
| 1 | `DESIGN.md` 已写入 `.specs/<change-id>/` | `test -f .specs/<change-id>/DESIGN.md` | ✅ / ❌ |
| 2 | 技术栈已锁定（`## 0` 段填齐） | 人工确认 | ✅ / ❌ |
| 3 | 既有架构对齐已写入（`## 0.5` 段，brownfield 必跑） | 人工确认 | ✅ / ❌ |
| 4 | 每条决策含「备选 + 理由 + 代价」 | 人工确认 | ✅ / ❌ |
| 5 | 至少一张数据流/架构图 | 人工确认 | ✅ / ❌ |
| 6 | 风险 ≥ 3 条且各有缓解方案 | 人工确认 | ✅ / ❌ |
| 7 | ADR 已记录（如有不可逆决策） | `test -f .specs/adr/*.md`（如适用） | ✅ / ❌ |
| 8 | § 9 架构沉淀建议已写（或整段写"无建议"） | 人工确认 | ✅ / ❌ |
| 9 | 不含完整代码实现（R3.1 — 伪代码/函数签名可，完整函数体不可） | 人工确认 | ✅ / ❌ |

### auto_advance 分支

- 若 `auto_advance=true`：全 ✅ → 自动 transition 到 3-task；有 ❌ → **暂停 pipeline**，输出缺失清单，等待用户决定
- 若 `auto_advance=false`：全 ✅ → 进入 toll-gate；有 ❌ → **禁止进入 toll-gate**，补齐缺失项后重新自检

---

## Pipeline Toll-Gate（仅 pipeline goal 模式）

> 仅当 `.flow-active.goal.scope = "pipeline"` 且 `current_phase = "2"` 时执行本段。

**触发条件**：DESIGN.md 已生成并经用户确认，技术栈已锁定，ADR 已记录。

检查 `auto_advance`：
- 若 `true` → 已在「阶段完成自检」段处理（全 ✅ 自动 transition，有 ❌ 暂停）。**不再进入本 toll-gate 交互**。
- 若 `false` → **停下来。必须等待用户回复。禁止自动继续。**

输出 TOLL-GATE：

```
🚦 Toll-gate 2→3：Phase 2 技术设计已完成。
✅ 产物: DESIGN.md ✓ | ADR（如有）✓
📋 技术栈: <选定栈> | 决策: D1-Dn | 风险: R1-Rn
   子条件:
     - "DESIGN confirmed" → ✅ 已满足（如有对应 condition 子条件）

是否进入 Phase 3（任务拆解）？
  1. 继续 → 进入 3-task（current_phase="3", phases_done+=["2"]）
  2. 暂停 → 保留当前状态，稍后 `/flow-go 继续` 恢复
```

用户选 1 → 执行 transition：
```bash
jq --arg ts "$(date -Iseconds)" \
  '.goal.current_phase = "3" | .goal.phases_done += ["2"] | .goal.gates["2→3"] = "passed" | .updated_at = $ts' \
  .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active
```
然后加载 `@flow-kit/prompts/3-task.md`（或非前端项目时）或 `@flow-kit/prompts/2a-ui-design.md`（前端项目）。
