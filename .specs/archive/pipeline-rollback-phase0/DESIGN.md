# DESIGN: Pipeline 回退协议扩展到 0-3 规划阶段（智能回退方案 C）

- **Change ID**: pipeline-rollback-phase0
- **关联**: `@.specs/pipeline-rollback-phase0/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

> **精简说明**：本 change 是 prompt 工程 + jq 微调，无新架构决策、无模块拆分。DESIGN 聚焦回退协议的设计决策（失败分类表 + 动态回退目标 + jq 通用化）。沿用既有 Bash + jq + bats 栈。

---

## 0. 技术栈选定

> 沿用既有栈，无变更。

- **语言**: Bash（prompt 内嵌 jq 表达式 + bats 测试）
- **测试**: bats-core 1.13.0 + jq
- **依赖**: 无新增

---

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（仅改 pipeline rollback 段 + 新增测试，不改其他逻辑）：
- flow-kit-bundle/flow-kit/prompts/5-test.md（rollback 段：toll-gate 失败 + 执行失败两处）
- flow-kit-bundle/flow-kit/prompts/6-review.md（rollback 段：Gate 失败 + toll-gate 6→7 回退两处）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（rollback 段：失败诊断回退一处）

新增模块：
- test/test_pipeline_rollback.bats（新建 · 回退逻辑测试）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/flow-kit/prompts/0-change.md / 1-requirement.md / 2-design.md / 3-task.md（4-dev 是回退终点，这些是回退目标，本身逻辑不改）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（回退终点 prompt，不改其 rollback——它没有下游回退）
- flow-kit-bundle/flow-kit/GO.md / skills/flow/SKILL.md（本次无关）
- flow-kit-bundle/hooks/*（与 pipeline rollback 无关）
- package-flow-kit.sh / install.sh / lib/*.sh（无关）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| start_phase 字段读取 | `goal-pipeline-phase0` 已交付 | **沿用** — 回退下界读 start_phase |
| AC-10 rollback jq 基础 | `fix-pipeline-rollback` 的 `current_phase = "4" \| phases_done -= [...]` | **沿用并通用化** — 接受 $TARGET 参数 |
| bats 测试 fixture pattern | `test/test_flow_goal.bats` / `test_common.bats` | **沿用** — mktemp + jq 断言 |
| 失败分类（6-review Gate 失败）| `6-review.md:43` 已有「spec 合规失败(AC 未覆盖)→critical」 | **沿用并扩展** — 升级为完整失败分类表 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 回退 jq 结构：**沿用** AC-10 的 `current_phase = X | phases_done -= [...]` 形式
- 失败分类：**引入新模式**（失败现象→建议回退阶段的映射表）→ 理由：之前是单一回退目标，扩展到多目标需要分类指引
- 动态回退目标：**引入新模式**（根据 start_phase 生成可回退列表）→ 理由：start_phase 可变，硬编码不可行
- jq 通用化：**沿用** jq --arg 传参模式（与 SKILL.md 的动态 gates 生成一致）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | 失败分类表覆盖 4 类 + 兜底 | A) 全自动分类器 / B) 4 类映射表 + 兜底 | 选 B：prompt 驱动，AI 按表判断，无需程序；4 类覆盖 90% 场景，兜底保底 | 不能处理罕见失败类型，但兜底「默认回 4」覆盖剩余 |
| D2 | 失败分类表内嵌每个 prompt（重复 3 份）vs 提取为共享 reference | A) 内嵌 / B) 提取 `reference/pipeline-rollback.md` 引用 | 选 A：保持 prompt 自包含（每个 prompt 独立可读）；3 份重复属结构性模板（health 报告已确认 markdown 模板重复可接受） | 3 份表需同步更新，但内容稳定（失败分类不常变） |
| D3 | 回退 jq 用 `$TARGET` 参数通用化 | A) 每个目标写独立 jq / B) 通用 `$TARGET` jq 模板 | 选 B：DRY，一个 jq 模板覆盖所有回退目标；与 goal-pipeline-phase0 的动态 gates 生成风格一致 | jq 表达式略复杂（需计算移除哪些 phases_done） |
| D4 | phases_done 移除逻辑：移除目标阶段之后的所有已完成阶段 | A) 仅移除当前阶段 / B) 移除 TARGET 之后所有 | 选 B：回退到 N 后，N 之后的所有阶段都作废需重跑（语义正确） | 如回退到 2，则 3/4/5/6 都需重走，但这是回退的应有语义 |
| D5 | 动态回退目标列表：[start_phase .. 当前阶段-1] | A) 列出所有 0-7 / B) 仅 [start_phase, 当前) | 选 B：只能回退到已走过的阶段（start_phase 之后到当前之前），未执行阶段不可回退 | 不能回退到 start_phase 之前（那不在本次 pipeline 范围） |
| D6 | 向后兼容：--from 4 时回退列表仅含 ["4"] | A) 特判 / B) 动态生成自然得到 | 选 B：`[start_phase=4 .. 当前-1]` 当 start_phase=4 且当前=5 时，列表=[4]，天然兼容，无需特判 | 代码更简洁 |
| D7 | 失败分类表「建议回退目标」可被用户手动覆盖 | A) 建议即强制 / B) 建议可覆盖 | 选 B：AI 给建议，用户可手动选任意可回退阶段（方案 C+B 结合） | 用户可能选错，但保留人工判断权 |

---

## 2. 数据流 / 架构图

### 2.1 智能回退决策流程

```
5/6/7 失败
  │
  ▼
读取 start_phase + current_phase + phases_done
  │
  ▼
┌──────────────────────────────────────────────────────────┐
│ ① 生成可回退目标列表                                     │
│   rollback_targets = [start_phase .. current_phase-1]    │
│   例：--from 0, current=6 → [0,1,2,3,4,5]                │
│   例：--from 4, current=5 → [4]                          │
└──────────────────────────────────────────────────────────┘
  │
  ▼
┌──────────────────────────────────────────────────────────┐
│ ② 失败分类（AI 按表判断）                                │
│   ┌──────────────────────┬──────────────┐                │
│   │ 失败现象             │ 建议回退目标 │                │
│   ├──────────────────────┼──────────────┤                │
│   │ 测试断言失败/代码 bug │ 4-dev        │                │
│   │ AC 未覆盖/无法满足    │ 1-requirement│                │
│   │ 架构决策缺陷          │ 2-design     │                │
│   │ task 拆解遗漏边界     │ 3-task       │                │
│   │ 其他/不确定          │ 4-dev (默认) │                │
│   └──────────────────────┴──────────────┘                │
└──────────────────────────────────────────────────────────┘
  │
  ▼
展示给用户：
  「根据失败现象 <X>，建议回退到 <N-阶段名>」
  「可回退目标：<rollback_targets>」
  用户确认建议 OR 手动选其他目标
  │
  ▼
┌──────────────────────────────────────────────────────────┐
│ ③ 执行通用回退 jq（$TARGET = 选定目标）                  │
│   # 移除 TARGET 之后的所有已完成阶段                      │
│   phases_to_remove = [t in phases_done | t > TARGET]      │
│   jq --arg target "$TARGET" --argjson remove "$P_REMOVE" \
│     '.goal.current_phase = $target                       │
│      | .goal.phases_done -= $remove                       │
│      | .updated_at = now' .flow-active                   │
└──────────────────────────────────────────────────────────┘
  │
  ▼
加载目标阶段 prompt
```

### 2.2 回退 jq 通用化对比

```
【改造前 — 硬编码，5-test 为例】
jq '.goal.current_phase = "4" | .goal.phases_done -= ["5"]'

【改造后 — 通用化，$TARGET 参数】
# 计算需移除的阶段：TARGET 之后到当前的所有已完成阶段
REMOVE=$(jq -n --arg target "$TARGET" --argjson done "$PHASES_DONE" \
  '[$done[] | select(. > $target | tonumber)]')
# 这里 PHASES_DONE 来自 .goal.phases_done
jq --arg target "$TARGET" --argjson remove "$REMOVE" \
  '.goal.current_phase = $target | .goal.phases_done -= $remove | .updated_at = now' .flow-active
```

注：jq 数字比较需 `tonumber`（phases_done 是字符串数组 ["4","5"]）。

---

## 3. 关键状态机

回退后的状态：
- `current_phase` = TARGET（用户选定）
- `phases_done` 移除 TARGET 之后的所有阶段
- `gates`：TARGET 之后的 gates 回到 `pending`（需重新过 toll-gate）
- 加载目标阶段 prompt，重新走 TARGET → ... → 7

---

## 4. ADR 索引

无新增独立 ADR。决策 D1-D7 均可逆（失败分类表/jq 模板均可后续调整）。延续既有决策：
- `fix-pipeline-rollback` 的 AC-10 rollback 基础（本 change 在其上扩展，不推翻）
- `goal-pipeline-phase0` 的 start_phase 字段（本 change 让回退逻辑也读它，补全对称性）

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | AI 执行通用回退 jq 时算错 phases_to_remove（数字比较）| 回退后 phases_done 残留错误阶段 | 中 | prompt 给出明确 jq 模板 + AC-5 测试覆盖多种 TARGET（4/2/1） |
| R2 | 失败分类表覆盖不全，罕见失败类型无建议 | 用户不知回退到哪 | 低 | 兜底「其他→默认回 4」覆盖剩余场景（D1） |
| R3 | 回退到规划阶段后，原产物（TEST.md/REVIEW.md）残留状态不一致 | 重新走 pipeline 时读到旧产物 | 中 | 回退只重置 phase 状态，不删产物文件；重新执行时会覆盖更新（与 fix-pipeline-rollback 一致行为） |
| R4 | --from 4 向后兼容被破坏（误改默认路径）| 老用户 pipeline 行为变化 | 低 | AC-4 专门验证；动态生成天然兼容（D6），无特判代码 |
| R5 | 3 份失败分类表不同步（改一处忘改另两处）| 分类建议不一致 | 中 | 3 份内容完全相同（D2），可在 TEST 阶段加一致性检查 |

---

## 6. 不在范围

- 程序化失败分类器（v2）
- 回退到 0-3 后规划阶段 prompt 的回退感知（v2）
- 回退次数防死循环（当前 R2.6 重试限制不含回退，v2）
- 4-dev.md 的 rollback（4 是终点，无下游）

---

## 9. 架构沉淀建议

本 change 引入一个有项目级复用价值的新模式：

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| 5/6/7 prompt 内嵌的「失败分类→回退目标」映射表 | 按失败类型智能建议回退阶段 | 任何 pipeline 类 feature 的失败处理 | 未来若有其他 pipeline（health pipeline / deploy pipeline），可复用此分类表模式 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| pipeline 回退下界 | 动态 = start_phase（默认 4 兼容） | 所有 pipeline goal 的失败回退 | 低 — jq 模板可调整 |
| 回退语义 | 退到 N 后移除 N 之后所有已完成阶段 | 回退行为 | 中 — 语义改变需同步改测试 |

### 9.3 跨模块契约

```
- 5/6/7 prompt 的回退 jq 从硬编码改为 $TARGET 参数化（接口变更）
- 回退目标范围 = [start_phase .. current_phase-1]（契约：不能回退到 start_phase 之前）
```

### 9.4 / 9.5

无新增依赖，无禁动清单变化。

---

> 本文件不包含完整代码实现。函数签名可，函数体不行。
