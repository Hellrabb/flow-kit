# DESIGN: 吸收 superpowers v6.0 经验到 flow-kit

- **Change ID**: superpowers-v6-absorb
- **关联**: `@.specs/superpowers-v6-absorb/REQUIREMENT.md`、`@.specs/superpowers-v6-absorb/CHANGE.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 项目栈已在 CONTEXT.md 锁定（Bash + jq + bats-core 1.13.0），本 change 不引入新栈。

- **选定**：flow-kit 既有 Bash 工具链（无栈变更）
- **新增脚本语言**：bash（review-package）+ awk（task-brief，更契合文本提取）
- **新增测试**：bats-core 扩展用例
- **理由**：本 change 全部产出都是脚本 + prompt 文档 + hook 微调，不引入运行时依赖
- **明确排除**：Python / Node（避免给 flow-kit 安装引入运行时依赖）

---

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep / ls 实际清单）：
- flow-kit-bundle/flow-kit/prompts/6-review.md（既有 · 重构 review 三轮合并）
- flow-kit-bundle/flow-kit/prompts/4-dev.md（既有 · 入场读 task-brief 输出替代全 TASK.md）
- flow-kit-bundle/flow-kit/prompts/3-task.md（既有 · 末段加 plan-conflict-scan）
- flow-kit-bundle/flow-kit/prompts/5-test.md（既有 · 顶部加 terse/narration 约束）
- flow-kit-bundle/flow-kit/prompts/7-integration.md（既有 · 顶部加 narration 约束）
- flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md（既有 · 顶部加 terse 约束）
- flow-kit-bundle/flow-kit/GO.md（既有 · 压缩 473→≤350 行）
- flow-kit-bundle/flow-kit/templates/TASK.md（既有 · XML task 块加 model-tier 属性）
- .flow-active（既有 schema · 新增 goal.task_progress[] 字段）
- .specs/<id>/REVIEW.md（既有产物 · 加 severity 标签）
- test/（既有 · 新增 review-package / task-brief / size-budget / model-tier 等 bats）

新增模块：
- flow-kit-bundle/flow-kit/scripts/review-package（新 · 46 行 bash）
- flow-kit-bundle/flow-kit/scripts/task-brief（新 · 41 行 awk）
- flow-kit-bundle/flow-kit/scripts/.gitignore（新 · 防止 scripts/ 临时输出文件入库）
- .specs/<id>/MINOR-DEFERRED.md（新产物 · phase 6 写入）
- .specs/adr/014-{...}.md ~ 018-{...}.md（5 个新 ADR）

不应该触碰但 AI 容易"顺手"碰的：
- flow-kit-bundle/hooks/（hook 行为本 change **不改**，仅 prompt 层和 script 层变动）
- flow-kit-bundle/flow-kit/RULES.md / SYSTEM.md / METHODOLOGY.md（核心规则不动）
- flow-kit-bundle/install.sh + lib/install_*.sh（安装逻辑无关）
- package-flow-kit.sh（打包逻辑无关 · 但 Part D 需新增 scripts/ 到 cp 清单）
- .specs/adr/001-013*.md（既有 ADR 不 supersede）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 跨平台 bash 脚本框架 | `package-flow-kit.sh`（既有 `set -euo pipefail` 范式） | 沿用 |
| bats 测试目录结构 | `test/` 已有 20+ bats 文件 | 沿用 `test/test_<name>.bats` 命名 |
| TASK.md XML 解析 | 4-dev.md 入场 jq 解析（既有） | 沿用 jq；新增 model-tier 字段解析 |
| 文档共享片段 | `flow-kit/reference/pipeline-gates.md` + `check-gate-sync.sh`（既有） | 沿用机制；terse / narration 约束亦抽到 reference/ |
| phase prompt 顶部强化段 | `interactive-ui-guard.md` 模式（既有） | 沿用：terse / narration 也走 reference/ 共享片段 |
| artifact 校验 | `flow-kit-artifacts.sh::PHASE_ARTIFACTS`（既有） | 扩展：phase 6 加 MINOR-DEFERRED.md（可选） |
| severity 三档语义 | brooks-lint 既有 🔴/🟡/🟢 | 沿用色码；新增 markdown 字段协议 |
| jq 临时文件 + mv 原子写 | 全 hook 既有范式 | 沿用（写 .flow-active.task_progress 时） |
| 跨平台兼容 shim | `_grep() { command grep "$@"; }`（既有） | 沿用：scripts/ 内 grep 调用包一层 _grep |

### 0.5.3 沿用模式 vs 引入新模式

```
- review phase 编排：**改造既有模式**（4 轮 → 1 轮 + 可选 spot-check）→ 理由：superpowers v6.0 验证合并可行，本 change 落地
- diff handoff：**引入新模式**（paste → file via review-package）→ 理由：第一次有此需求；cut controller context
- task text handoff：**引入新模式**（paste → file via task-brief）→ 理由：cut 4-dev reload 成本 40%
- prompt 顶部硬约束：**沿用模式**（interactive-ui-guard 已有），新增 terse / narration 复用此模式
- task_progress schema：**引入新模式**（无既有 ledger 抽象）→ 理由：compaction survival 是新需求；选 jq 友好 JSON 数组，与 .flow-active 既有风格一致
- model-tier 调度：**引入新模式**（无既有 tier 调度抽象）→ 理由：避免 silently 继承 session 最贵 tier
- severity gating：**沿用模式**（brooks-lint 已有三档色码），新增 prompt 层强制
- plan-conflict-scan：**引入新模式**（无既有预检）→ 理由：避免 mid-run interrupt
- GO.md bootstrap 压缩：**沿用模式**（superpowers v6.1 已验证：DOT→prose / 删 per-platform / 折叠），针对 flow-kit 应用
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| **D1** | review phase 4 轮 → 1 轮（spec + quality + UI 合并）+ spot-check Critical 触发 | (a) 全合并含 spot-check (b) 保持 4 轮 (c) 合并但 spot-check 每次跑 | 选合并 + Critical 触发 spot-check。理由：superpowers v6 验证 -15% tokens（合并）+ -10%（spot-check 不每次跑）；本 change 的 spot-check 是 L2 子 agent 调用，每次跑多 10-15K tokens 不划算 | 失去"每条 finding 都被 2 个模型审视"的强保证；但 Critical 触发覆盖最贵风险 |
| **D2** | scripts/review-package 用 bash（46 行） | (a) Python (b) Node | bash：无运行时依赖，与 flow-kit 工具链一致；功能简单（git log + diff + redirect）不需要 Python 表达力 | 跨平台：macOS bash 3.2 老版本需 polyfill（`set -o pipefail` 兼容）；本 change Linux-first 可接受 |
| **D3** | review-package 输出格式 = markdown 三段（## Commits / ## Files changed / ## Diff） | (a) JSON (b) 纯 diff | markdown：reviewer 直接 Read，无需解析；JSON 增加复杂度但 reviewer prompt 反而要解析；纯 diff 缺 commit context | 输出体积略大于 JSON（markdown 标题占空间），但 < 5% 可忽略 |
| **D4** | scripts/task-brief 用 awk（41 行） | (a) bash + grep/sed (b) jq + xml 解析 | awk：原生字段提取（XML block by id），bash 做需多层管道；jq 不擅长 XML；Python 过度 | awk 语法有学习曲线；但 mawk/gawk 兼容性覆盖 99% Linux；macOS BSD awk 有边缘差异，测试覆盖 |
| **D5** | terse reviewer contract 实施机制 = prompt 顶部硬约束段（grep 校验） | (a) YAML front matter + parser (b) 后处理脚本 strip 冗余段 | prompt 顶部段：与既有 interactive-ui-guard 模式一致；grep `no preamble\|verdict-first` 即校验；零运行时成本 | 约束靠模型自觉 + grep 兜底，非编译时强制；但 brooks-lint L2 blind review 已验证此模式有效 |
| **D6** | narration constraint 实施机制 = 同 D5，prompt 顶部段（"between tool calls, narrate at most one short line"） | (a) hook 层强制截断 (b) 后处理 | prompt 顶部段：与 D5 一致；hook 强制截断反而误伤合法长输出 | 同 D5：靠模型自觉 + grep |
| **D7** | severity 标记格式 = markdown 行内 token：`**Severity**: 🔴 Critical` / `🟡 Important` / `🟢 Minor` | (a) YAML 字段 (b) 自定义 fenced block | markdown 行内：reviewer 输出自然，grep 友好，与 brooks-lint 既有色码一致；YAML 字段增加解析复杂度 | 解析器需 regex 提取，比 YAML fragility 略高；但 brooks-lint L2 已用此格式 |
| **D8** | task_progress 写入时机 = 4-dev.md §6 写 SUMMARY 时 jq append .flow-active | (a) hook 自动写 (b) 4-dev 手动写 | 4-dev 手动写：与 SUMMARY 写入时机一致；hook 自动写需要监听 commit SHA 变化（复杂）；4-dev 已有 jq 调用习惯 | 依赖 4-dev prompt 遵守；漏写由 33-flow-active-integrity hook 兜底（已存在） |
| **D9** | model-tier 生效路径 = 双轨：优先 OpenCode task tool 的 model 字段；fallback dispatch prompt hint `[MODEL-TIER hint]: ...` | (a) 仅 hint (b) 仅 task tool model 字段 (c) 不分双轨 | 双轨：兼容 OpenCode 是否支持 task-level model switching；4-dev 派 task 时先尝试 model 字段，无则写 hint。设计弹性最大 | 实现复杂度略高（4-dev 要判断 OpenCode 能力）；但只在 4-dev 入场调研一次，结果缓存 |
| **D10** | plan-conflict-scan 扫描机制 = AI 判断 + grep 候选（不是纯 regex） | (a) 纯 regex (b) AI 全判断 | AI + grep 候选：grep 提供"TASK.md 引用的文件/ADR 是否在 CONTEXT 禁动清单"硬证据，AI 判断语义层冲突；纯 regex 漏语义冲突，AI 全判断无证据易幻觉 | phase 3 prompt 加 ~30 行；执行时间 +1-2K tokens；但避免 mid-run interrupt 物超所值 |
| **D11** | GO.md 压缩策略 = (a) 删 Token 预算详细段（保留红线 + 预算估算强制）(b) 删 per-platform 工具表 (c) 折叠 Instruction-Priority (d) reference 加载指令从 GO.md 移到 reference/README.md | (a) 全面重构 (b) 仅删冗余 | 选 (b) 仅删冗余：保留 GO.md 作为路由核心，删 Token 预算影响因子/取舍段（现代模型已懂）+ per-platform 段（OpenCode 已统一）；不重构核心路由逻辑 | 削减量 473→~330 行（约 -30%），保守但安全；激进重构风险高收益小 |

---

## 2. 数据流 / 架构图

### 2.1 整体数据流

```
   用户 → GO.md (route) → phase N prompt
                            │
   ┌────────────────────────┴────────────────────────┐
   │                                                  │
   ▼                                                  ▼
[phase 3 task-brief 提取]                   [phase 4 dev 派 task]
   │                                                  │
   ▼                                                  ▼
TASK.md ──awk──> /tmp/brief_T03.txt        4-dev.md + brief_T03.txt
                                                  │
                                                  ▼
                                            实际 dispatch（含 model-tier）
                                                  │
                                                  ▼
                                       .flow-active.task_progress[]
                                            (append on task done)

   ─────────────────────────────────────────────────────────────

[phase 6 review]
   │
   ▼
review-package base HEAD /tmp/diff.md  ──┐
                                         ▼
                              reviewer prompt (terse contract)
                                         │
                                         ▼
                                  REVIEW.md (severity-tagged)
                                         │
                            ┌────────────┴────────────┐
                            ▼                          ▼
                   [无 Critical]                [有 Critical]
                            │                          │
                            ▼                          ▼
                    (skip spot-check)        cross-model spot-check
                                                  (L2 subagent)
                                                  │
                                                  ▼
                                       INDEPENDENT-REVIEW-6.md
                                                  │
                                                  ▼
                                  Minor findings → MINOR-DEFERRED.md
```

### 2.2 task_progress lifecycle（compaction survival）

```
   4-dev 完成 task T03
        │
        ▼
   jq append .flow-active.goal.task_progress:
     {id:"T03", commit_sha:"abc1234", fix_rounds:2,
      deferred:["M1","M2"], completed_at:"<ISO>"}
        │
        ▼
   ─── compaction / session restart ───
        │
        ▼
   4-dev 入场读 .flow-active.goal.task_progress
        │
        ▼
   若 T03 已在 → skip 重派；否则派
```

---

## 3. 关键状态机

### 3.1 Review phase 状态机（改造后）

| 状态 | 进入条件 | 退出条件 |
|---|---|---|
| `merged_review_running` | phase 6 启动 | REVIEW.md 写入完成 |
| `evaluating_critical` | REVIEW.md 写入 | 综合评估完成 |
| `spot_check_running`（可选） | 综合评估含 ≥1 Critical | INDEPENDENT-REVIEW-6.md spot-check 段写入 |
| `minor_deferred_writing` | spot_check_running 完成或 skip | MINOR-DEFERRED.md 写入 |
| `toll_gate_6_to_7` | minor_deferred_writing 完成 | 用户确认 |

### 3.2 model-tier resolution 状态机

| 状态 | 进入条件 | 输出 |
|---|---|---|
| `parsing` | 4-dev 入场读 TASK.md | task XML 块 |
| `extract_tier` | parsing 完成 | `model-tier` 属性值（或缺省） |
| `tier_fallback` | 无 model-tier | standard |
| `dispatch_check` | extract_tier 完成 | OpenCode 支持 task-level model switching? |
| `native_dispatch`（如支持） | dispatch_check=y | task tool 调用含 model 字段 |
| `hint_dispatch`（如不支持） | dispatch_check=n | dispatch prompt 含 `[MODEL-TIER hint]: ...` |

---

## 4. ADR 索引

5 个 ADR，按可逆性低到高排序：

- `@.specs/adr/014-review-merge-and-spot-check.md` — review 4 轮 → 1 轮 + Critical 触发 spot-check（D1）
- `@.specs/adr/015-task-progress-schema.md` — task_progress 字段锁 5 字段（D8）
- `@.specs/adr/016-model-tier-dispatch.md` — 双轨 model-tier 生效路径（D9）
- `@.specs/adr/017-severity-gating-protocol.md` — severity 标记格式 + Minor deferred 文件（D7 + R4）
- `@.specs/adr/018-go-md-bootstrap-compression.md` — GO.md 473→≤350 + 不重构核心路由（D11）

详情见各 ADR 文件。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **实现风险**：4-dev.md 改造破坏既有 TDD/diff boundary 流程 | 既有 user pipeline 死锁 | 中 | bats 测试 100% 覆盖既有用例不退化（AC-I2）+ dry-run mode + 双源测试同步 |
| R2 | **实现风险**：scripts/ 跨平台差异（macOS BSD awk / bash 3.2） | macOS user scripts 失败 | 中 | 测试明确 Linux-first；macOS 用 polyfill；AC-A3 标"如可用" |
| R3 | **上线风险**：review 三轮合并丢 finding（spot-check 仅 Critical 触发） | Important finding 漏判 | 低 | AC-B1 grep `Round 1/2/3` 不再出现 + 综合评估必须覆盖 spec + quality + UI 三视角；保留 cross-model spot-check 作 Critical 兜底 |
| R4 | **上线风险**：narration constraint 太严，AI 不输出关键解释 | 决策可读性下降 | 中 | "between tool calls" 限定——tool calls 之间短叙述，最终答复可详尽；测试用例覆盖 |
| R5 | **长期债务**：D5/D6 prompt 顶部段约束靠模型自觉 | 弱模型忽略约束 | 中 | ADR-001 protect-the-weakest 已加结构化自检 gate；narration violation 由 33-flow-active-integrity 兜底（未来扩展） |
| R6 | **长期债务**：task_progress 字段锁死 5 字段，未来扩展需 ADR | 新增字段（如 retry_count）需走 ADR 流程 | 低 | 这是设计意图（防 scope creep）；ADR-015 显式记录"新增字段需 ADR"约束 |
| R7 | **OpenCode 兼容风险**：D9 OpenCode task-level model switching 能力未确认 | model-tier hint 走 fallback 但实现质量未知 | 中 | 4-dev 入场调研一次，结果缓存；fallback hint 格式严格（grep 可校验） |
| R8 | **token 测量复现风险**：superpowers 自报 -50% 独立 benchmark 只复现 -14% | 实际 token 削减不达 -25% | 高 | 已用结构性 AC 作硬门槛（review 轮数 / 4-dev reload / GO.md 行数）；端到端 token 测量作参考性 AC 不卡 toll-gate（依据 § 范围决策） |

---

## 6. 不在范围

- **hook 行为变更**：本 change 不改 hook 脚本行为，仅在 prompt 层和 scripts 层动手。hook 改造留给独立 change（如独立 fix-l3-review-sh-support-openai-api）
- **L3 API 改造支持 OpenAI 格式**：当前 l3-review.sh 写死 Anthropic Messages API，OpenCode 环境无 ANTHROPIC 配置 → 全局降级 L2-only。改造支持 OpenAI Chat Completions 留独立 change（TD-023 候选）
- **D7 path-guard 误拦 read 操作**：本次实施过程发现 path-guard D7 字符串匹配不区分 read/write（如 `test -f` 被误拦）。登记 TD-023 留独立 change
- **新 ADR 移到 ARCHITECTURE.md**：本 change 5 个新 ADR 写入 `.specs/adr/`，未来跑 A-evolve 时同步到 ARCHITECTURE.md（如已建立）
- **弱模型 narration violation hook 兜底**：本 change 加 prompt 层 narration 约束，hook 层兜底（33-flow-active-integrity 扩展）留 v2
- **review phase 4 轮外的"第四轮 补充审查"**：原 6-review.md 提到的"第四轮（可选 · 按触发条件跳）"由 spot-check 替代；本 change 不保留第四轮

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象（建议 append 到 CONTEXT 「既有抽象索引」段）

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/flow-kit/scripts/review-package` | 预烤 git diff/metadata 到文件 | 任何需要把 diff handoff 给 subagent 的场景 | 6-review.md 主用；未来 7-integration.md 跑全量 diff 时也可调 |
| `flow-kit-bundle/flow-kit/scripts/task-brief` | 从 TASK.md 提取单 task XML block 到文件 | 4-dev 入场；未来 3-task 验证 task 粒度也可调 | 4-dev.md 主用 |
| `flow-kit-bundle/flow-kit/reference/terse-contract.md`（新共享片段） | terse reviewer 输出格式约束 | 所有 review 类 prompt 顶部引用 | 6-review.md / L2-blind-review.md / independent/* 引用 |
| `flow-kit-bundle/flow-kit/reference/narration-constraint.md`（新共享片段） | controller narration 限制 | 所有 phase prompt 顶部引用 | 0-change ~ 7-integration 引用 |

### 9.2 新增 / 改变的项目级技术决策（建议 append 到 CONTEXT「已锁技术决策」段）

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| review phase 编排 | 1 轮合并 + Critical 触发 spot-check（替代 4 轮） | 6-review.md 主流程；所有 change 的 review 阶段 | 重写 6-review.md + 回退 bats 测试 |
| task_progress schema | 5 字段锁（id/commit_sha/fix_rounds/deferred/completed_at） | .flow-active.goal.task_progress | 需新 ADR 批准字段扩展 |
| severity 文件路径 | `.specs/<id>/MINOR-DEFERRED.md` 单一固定路径 | review/test/integration 阶段 | 改路径需同步 hook grep + bats 测试 |
| model-tier 双轨 | OpenCode 支持 → task tool model 字段；不支持 → prompt hint | 4-dev 派 task | 改双轨为单轨需重测 OpenCode 能力 |
| GO.md 体积上限 | ≤350 行（结构性硬指标） | 后续每次 GO.md 修改 | 重新评估可删段 |

### 9.3 新增 / 修改的跨模块契约

```
- .flow-active.goal.task_progress[]：新字段，5 字段固定 schema（见 ADR-015）
- .specs/<id>/MINOR-DEFERRED.md：新产物，phase 6 创建，phase 7 triage
- TASK.md XML：<task id="..." model-tier="cheap|standard|top" ...>，model-tier 可选属性
- REVIEW.md：finding 必含 `**Severity**: 🔴/🟡/🟢 Critical/Important/Minor` 标记
- dispatch prompt hint：`[MODEL-TIER hint]: 建议本 task 使用 <tier>-tier 模型（<reason>）`
```

### 9.4 新增 / 升级的依赖

| 包 | 版本 | 用途 | 是否替换既有 |
|---|---|---|---|
| （无新依赖） | — | — | — |

> 本 change 全部用 bash + awk + jq 既有工具链，无新增运行时依赖。

### 9.5 禁动清单变化

```
- 新增禁动：
  - flow-kit-bundle/flow-kit/scripts/review-package 的输出格式（## Commits / ## Files changed / ## Diff）不允许改
    → reviewer prompt 已 grep 这三段；改格式破坏 grep
  - flow-kit-bundle/flow-kit/scripts/task-brief 的输出文件路径（命令行第 3 参）不允许改
    → 4-dev.md 硬编码 <outfile>；改路径需同步 4-dev
  - .flow-active.goal.task_progress 的 5 字段集不允许扩展
    → 见 ADR-015；扩展需新 ADR
  - MINOR-DEFERRED.md 路径不允许改为嵌入段（如 T<N>-SUMMARY.md deferred 段）
    → 见 AC-D2 单一路径决策；hook grep 依赖固定路径

- 解禁：（无）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
