# DESIGN: 提升 flow-kit 在弱模型（幻觉多）下的鲁棒性

- **Change ID**: weak-model-robustness
- **关联**: `@.specs/weak-model-robustness/REQUIREMENT.md`、`@.specs/CONTEXT.md`、`@.specs/adr/001-protect-the-weakest.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 flow-kit 分发包仓库（meta / distribution），本次改 markdown 规则 + bats 测试，**无传统技术栈选型**。

- **选定**: 无（meta 项目，不适用 tech-stacks 卡片）
- **前端**: N/A
- **后端**: N/A
- **数据库**: N/A
- **部署**: N/A（产物为 markdown 规则 + bats 测试 + regression-demo 脚本）
- **关键依赖**: bats-core 1.13.0（已有，npx 调用）· Bash（check.sh）· Markdown（RULES/prompt）
- **理由**: 本次是增强 flow-kit 引擎自身的方法论鲁棒性，作用对象是 markdown 规则文件 + 测试，不引入任何运行时框架
- **明确排除**: 任何新运行时依赖（本次范围排除改 hook/执行机制，见 D2）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（既有 · 来自 grep/ls 实际清单）：
- flow-kit-bundle/flow-kit/RULES.md          （L1 · 增强 R3 角色红线 / R6 反幻觉 / R7 范围控制 三段）
- flow-kit-bundle/flow-kit/SYSTEM.md         （L1 · 加"弱模型鲁棒性原则"一节）
- flow-kit-bundle/flow-kit/GO.md             （L2 · pipeline 阶段入场 goal 锚定）
- flow-kit-bundle/flow-kit/prompts/0-change.md   （L2 · 反问 gate 强化）
- flow-kit-bundle/flow-kit/prompts/1-requirement.md （L2 · 反问 gate 强化）
- flow-kit-bundle/flow-kit/prompts/2-design.md    （L3 · 引用文件/API 前验证）
- flow-kit-bundle/flow-kit/prompts/4-dev.md       （L3 证据链 + 关键节点 checkpoint + 复述边界）

新增模块：
- flow-kit-bundle/flow-kit/regression-demos/hallucination-guard/check.sh   （AC-2）
- flow-kit-bundle/flow-kit/regression-demos/scope-drift-guard/check.sh      （AC-4）
- flow-kit-bundle/flow-kit/regression-demos/strong-model-verbosity/check.sh （AC-7）
- test/weak-model-robustness/no-skip-clarify.bats   （AC-1）
- test/weak-model-robustness/checkpoint-keynodes.bats （AC-3）
- test/weak-model-robustness/goal-anchored.bats     （AC-5）
- .specs/adr/001-protect-the-weakest.md             （D5）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/                （不改 hook 机制 · D2 排除）
- flow-kit-bundle/skills/               （flow-* skill 不改；/flow checkpoint 已存在，仅复用）
- .flow-active 状态机结构               （pipeline 字段不动）
- install.sh / package-flow-kit.sh      （除非 INTEGRATION 阶段重新打包需要）
- 阶段划分 0→7                          （流程不变，只增强各阶段内容）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 反幻觉规则 | 有 · `RULES.md` R6·反幻觉（:139） | **沿用 + 增强** |
| 禁跳反问 | 有 · `RULES.md` R3·角色红线（:86）+ 各 prompt 反问段 | **沿用 + 强化** |
| 范围控制 | 有 · `RULES.md` R7·范围控制（:167） | **沿用 + 增强** |
| checkpoint 机制 | 有 · `/flow checkpoint` 命令（flow skill） | **沿用**，强化"关键节点强制" |
| goal 锚定 | 有 · pipeline goal 机制（`.flow-active.goal`） | **沿用**，加"阶段入场锚定" |
| 自检 gate | 有 · 各 prompt 的 PCSC 段（阶段完成自检） | **沿用 + 强化**为填空式 |
| 证据链（引用前 grep/read 验证） | **无** | **引入新模式**（理由：既有无"引用前强制验证"机制，防幻觉最高频场景） |
| regression-demo 可执行验收 | 部分 · `regression-demos/` 目录存在但仅 1 个 md，无 check.sh 范式 | **引入** check.sh 范式（理由：既有无可重复执行的 demo 验收脚本） |

### 0.5.3 沿用模式 vs 引入新模式

```
- 规则层（R3/R6/R7）：**沿用**（增强内容，保持 RULES 八段结构一致 · 见 D1）
- checkpoint / goal 锚定 / 自检 gate：**沿用**既有机制（只强化触发点，不新建机制）
- 证据链 L3：**引入新模式** → 理由：既有无"引用文件/API/字段前强制验证"机制，
  而引用类幻觉是弱模型最高频失败模式（AC-2）；引入是为了把"靠模型自觉不幻觉"
  改成"靠工具验证兜底"，无法用既有抽象替代
- regression-demo check.sh 范式：**引入** → 理由：既有 demos 无可执行验收脚本，
  AC-2/AC-4/AC-7 需要可重复跑的 check.sh
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | L1 加固**增强现有 R3/R6/R7 段** | 新建独立 `R9·弱模型` 段 | 保持 RULES 八段结构一致，避免规则碎片化；R3/R6/R7 已是该约束的天然归属 | R6 段会变长（缓解：冗长示例移 `reference/`，每段净增 < 20 行） |
| D2 | 证据链用 **prompt 指令 + check.sh 验收** | hook 强制拦截（PreToolUse） | 本次范围**排除**改 hook 机制；prompt 指令 + demo 验收已能覆盖 AC-2/AC-4 | 依赖模型遵守指令（缓解：R6 硬约束 + check.sh 双重；v2 可升级 hook） |
| D3 | 自检 gate 用**填空模板** | 自由发挥 + 检查清单 | 弱模型**无法跳过填空**（不填就产不出）；强模型填空不啰嗦（AC-7 友好） | 模板略限制表达自由度（可接受） |
| D4 | regression-demo 用**脚本模拟 check.sh** | 真接弱模型 API 跑 | v1 不依赖外部 API/密钥，可重复跑；行为特征近似（验 grep/read 是否发生）足够 | 不能真实验证弱模型输出（v2 接 API 补） |
| D5 | protect-the-weakest 记 **ADR-001** | 仅记 CONTEXT 已锁决策 | 这是未来可能被重新讨论的**可逆性低**方法论决策，值得正式 ADR（§3 要求） | 多一份文档维护（值得） |
| D6 | L3 证据链触发范围限**"引用前验证"** | 全局强制每个声明都验证 | 避免啰嗦反噬强模型（AC-7）；引用类幻觉是最高频 | 非引用类幻觉（如逻辑错误）未覆盖（v2 扩展） |

---

## 2. 数据流 / 架构图

```
  弱模型请求（易幻觉 / 易跳步骤）
        │
        ▼
┌──────────────────────────────────────────────────┐
│ L1 · 规则硬护栏（RULES.md R3/R6/R7 增强）         │
│   R3 禁跳反问（反问 gate 未过 → 不许出方案）      │
│   R6 禁凭空假设（→ 触发 L3 证据链）               │
│   R7 动手前复述 read/write 边界 + 范围排除        │
└──────────────────────────────────────────────────┘
        │  （硬约束 · 所有模型必守 · 不啰嗦）
        ▼
┌──────────────────────────────────────────────────┐
│ L2 · prompt 结构化强化（各阶段 prompt）           │
│   反问 gate（0-change / 1-requirement / 2-design）│
│   自检 gate = 填空模板（无法跳过）                │
│   关键节点 checkpoint（4-dev：编辑前/失败/切task） │
│   阶段入场 goal 锚定（GO.md + 各阶段 · 仅入场一次）│
└──────────────────────────────────────────────────┘
        │  （结构刚性 · 强模型也受益 · 不唠叨）
        ▼
┌──────────────────────────────────────────────────┐
│ L3 · 证据链机制（4-dev / 2-design）               │
│   引用文件/API/字段前 → 必须 grep/read 验证存在   │
│   未验证 → 拒绝引用 / 显式标注"未找到"            │
└──────────────────────────────────────────────────┘
        │
        ▼
   可信产出
        │
        ▼
┌──────────────────────────────────────────────────┐
│ 验收层（bats 结构测试 + regression-demo check.sh）│
│   结构测试：每个 gate/约束段存在于 prompt/RULES   │
│   行为反例：诱导幻觉/漂移 → check.sh 验护栏生效   │
│   AC-7：强模型啰嗦度（token/turn 增量 < 20%）     │
└──────────────────────────────────────────────────┘
```

**关键设计原则**（贯穿三层）：把"靠模型自觉"改成"靠结构/工具兜底"——弱模型没法跳过一个必须填空的模板，也没法幻觉一个刚被 `grep` 验证过的字段。同时**只加结构刚性护栏、不加重复唠叨**（AC-7 兜底），避免反噬强模型。

## 3. 关键状态机

N/A — 本次不引入新状态机。pipeline goal 的阶段推进状态机（`.flow-active.goal.current_phase` / `phases_done` / `gates`）**沿用不变**，只在各阶段入场加"goal 锚定"步骤（只读不改状态）。

## 4. ADR 索引

- `@.specs/adr/001-protect-the-weakest.md` — 弱模型鲁棒性哲学（protect the weakest + 否决自动探测 + 结构刚性限定）

> 本项目无 ARCHITECTURE.md（从未跑 A-architect）。本 ADR 暂存 `.specs/adr/`，待将来建立 ARCHITECTURE.md 时由 `A-architect` 收录进 §3 ADR 列表。

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1（实现） | 证据链 prompt 指令被弱模型跳过 | 幻觉仍发生 | 中 | R6 硬约束 + check.sh demo 验收双重；v2 升级为 hook 强制（D2 备选） |
| R2（实现） | RULES/prompt 体量增长触发 R1 token 预算 | 加固内容膨胀拖累上下文 | 中 | 冗长示例移 `reference/`；每段净增 < 20 行；DEV 阶段监控 |
| R3（长期债） | 脚本模拟 demo 不能真实验证弱模型行为 | 验收置信度有限 | 高 | v2 接弱模型 API；本次验行为特征（grep/read 是否发生） |
| R4（上线） | 加固过度反噬强模型（啰嗦 → 增幻觉） | 强模型体验/质量下降 | 中 | AC-7 强制 token/turn 增量 < 20%；结构刚性原则；强模型回归 demo |
| R5（上线） | 双源同步：`flow-kit-bundle/flow-kit/`（源）vs `~/.claude/flow-kit/`（运行副本） | 改了源没同步到运行环境，验收时跑的是旧引擎 | 中 | DEV 完成后 INTEGRATION 阶段重新 package + 安装；记入 INTEGRATION 清单 |

> 含实现风险（R1/R2）/ 上线风险（R4/R5）/ 长期债务（R3）三类。

## 6. 不在范围

- **L4 伪双轨**（`model_tier` 分级标记 + opt-out 降级）—— v2，等 L1-L3 地基稳定
- **真接弱模型 API 的 regression-demo** —— v2（D4 取舍）
- **弱模型精确基线定义**（到底多弱算弱、用哪款模型实测）—— v2 / TEST 阶段细化
- **非引用类幻觉防御**（逻辑错误、推理谬误）—— L3 仅覆盖引用类，其余 v2（D6 取舍）
- **项目级 ARCHITECTURE.md 建立** —— 独立投资（A-architect），不属本 change
- **改 hook / 执行机制** —— 明确排除（D2）

---

## 9. 架构沉淀建议（供 `A-evolve` 同步用）

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `prompts/*` 内的**自检 gate 填空模板范式** | 把"检查清单"改成"必须填空才能产出"的刚性结构 | 任何需要防跳步的阶段 | 以后新加 prompt 阶段默认采用填空式 gate |
| `regression-demos/<scenario>/check.sh` 范式 | 可重复执行的行为验收脚本（诱导场景 + 预期行为校验） | 任何"防某类失败"的护栏验收 | 以后所有行为类护栏都用此范式挂 demo |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| 弱模型鲁棒性哲学 | protect the weakest（默认全含加严 + 仅结构刚性 + 否决自动探测） | 所有 RULES/prompt 内容编写 | 中 — 需重审 R3/R6/R7 全部加固内容（见 ADR-001） |

### 9.3 新增 / 修改的跨模块契约

```
- RULES.md R3/R6/R7 增强为"弱模型鲁棒性契约"的一部分（所有 flow-kit 使用者依赖）
- 各阶段 prompt 新增的 gate/checkpoint/锚定点成为阶段契约（4-dev/3-task 等下游必须遵守）
- 无 API / Schema / 事件总线变更（非业务项目）
```

### 9.4 新增 / 升级的依赖

N/A — 不引入任何新依赖（bats-core 已有）。

### 9.5 禁动清单变化

```
- 新增禁动：RULES.md R6·反幻觉 / R3·角色红线 / R7·范围控制 的"弱模型加固子段"
  标注「勿删 — 弱模型鲁棒性依赖，移除前需评估对弱模型的影响」
- 新增禁动：regression-demos/*/check.sh 勿在未同步更新预期的情况下修改
- 解禁：无
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
