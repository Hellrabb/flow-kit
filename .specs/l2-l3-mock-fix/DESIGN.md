# DESIGN: L2/L3 独立审查 gate 残留缺陷根治（F/H/I/J + K）

- **Change ID**: l2-l3-mock-fix
- **关联**: `@.specs/l2-l3-mock-fix/REQUIREMENT.md`、`@.specs/l2-l3-mock-fix/CHANGE.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review
- **基于**: phase 2 源码调研 + Explore agent I 根因诊断 + phase 1 双层审查反馈（R1-R6 / L3-Major1-2 / minor）

---

## 0. 技术栈选定

- **选定**：Bash（**沿用 CONTEXT 已锁栈** · 本 change 不涉栈变动）
- **运行时**：bash 4.4+（`declare -A` / `[[ =~ ]]` 正则；NFR-2 守护 pure fn 不提版本要求）
- **测试**：bats-core 1.13.0（npx）· 集成测试 payload 注入 + exit code（记忆 [[gate-orchestration-integration-test]]）
- **理由**：本 change 是 flow-kit 自身 gate hook 的 bug 修复 + 内部重构，纯 Bash，无栈变动
- **明确排除**：不引入新语言/框架

---

## 0.5 既有架构对齐（brownfield · 来自源码 grep）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 实际清单 · flow-kit-bundle/hooks/）：
- stop/lib/common.sh（D1：PHASE_GATE_KEY_MAP declare → pure fn 定义）
- pre-tool-use/independent-review-gate.sh（D1：删 declare + 2 消费者 + D2 is_git_commit）
- stop/29-independent-review.sh（D1：3 消费者 + D3 D4 提示 + 可观测性）
- stop/lib/l3-review.sh（D4 _l3_check_rerun）
- stop/26-workflow.sh（D5 G1 pipeline 模式不 advance）

新增模块：无（纯重构 + bug 修复，沿用既有文件）

禁动清单（AC-F 边界 · 不许"顺手"碰）：
- _run_review_gates 7 Gate 控制流（Gate1-7 的 transition/顺序）
- L2 子 agent 盲审逻辑（L2-blind-review.md / l2-detect.sh）
- l3_review_run 的 API 调用（l3-review.sh `_l3_call_api` **不改**；`L3_artifact_hash` 元数据行写入允许，回应 L3-task-R7）
- 其他 stop hook 模块（30-ai-analyze.sh 等）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有？路径 | 决定 |
|---|---|---|
| phase→gate_key 映射 | common.sh `declare -A PHASE_GATE_KEY_MAP`（2 处重复）| **重构 pure fn**（D1）|
| 命令类型识别 | gate.sh `is_git_commit` 正则 | **增强 quoting 感知**（D2 · 加预处理）|
| L3 重审检测 | l3-review.sh `_l3_check_rerun` mtime | **改内容标记**（D4 · 沿用函数换判定）|
| phase 推进 | 26-workflow.sh G1 `fk_auto_phase` | **pipeline 模式禁 auto-advance**（D5）|
| 6 消费者引用 | `"${PHASE_GATE_KEY_MAP[$phase]:-}"` | 改 `"$(fk_phase_gate_key "$phase")"` |
| 集成测试范式 | test/ INT-1~7（payload 注入 bash gate.sh）| **沿用**（每 AC 伴 INT）|

### 0.5.3 沿用模式 vs 引入新模式

```
- gate 数据结构：**重构 pure fn**（D1 · 消除 v1 重复 declare 的 DRY 违反，单一来源）
- 命令识别：**增强既有正则**（D2 · 加 quoting/heredoc 预处理，不换范式）
- L3 调度：**文档化既有 L2-first 契约**（D3 · 非新模式，显式化既有顺序依赖）
- L3 重审：**改判定基**（D4 · mtime → 内容标记，沿用函数签名）
- phase 推进：**加 scope 守卫**（D5 · pipeline 模式归 toll-gate，单阶段保留 auto）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | PHASE_GATE_KEY_MAP 抽 pure fn `fk_phase_gate_key`（common.sh 单一定义，内部用 `case` 非 `declare -A`）| 共享 source 文件 / 回 source common.sh / 内部 declare -A | 无 source 副作用 + 单一来源（grep `declare -A PHASE_GATE_KEY_MAP` ==0）+ 消除"须手动同步"债 | 5 执行消费者改调用 + 1 注释更新；函数调用开销（NFR-1 守护）|
| D2 | is_git_commit **+ is_gh_pr_create**（同结构）改 **结构判定**（非正则剥离 bash 词法）：含 heredoc(`<<`)/多行/写重定向 → 不 deny；否则子命令 split(`&&`/`||`/`;`/`|`)+**前两 token 序列**（token0=git ∧ token1=commit）→ deny（见 ADR-008 · 非字面 'git commit'，消除 L3 误读）| 首 token 仅 / 正则剥离（脆弱）/ 白名单（违反 AC-H (f)）| 不剥离 bash（简单稳）+ 反规避 + 根治 L2 写报告被拦 | 含 heredoc 的真实 git commit 漏拦（罕见）；sudo 前缀漏拦（风险段记录）|
| D3 | 文档化 L2-first 顺序契约 + **双管缓解**（回应 L2-R-D3-R5 + L3-major，用户定）：(a) `.flow-active.correction` hook 兜底（Stop D4 写 flag → SessionStart banner）+ (b) 29 D4 明确 deny reason + 错误日志（L3 明确性）+ 可观测性 | 仅 correction（L3 批 prompt 级）/ 仅 deny reason（L2 批不足）/ Stop 自动派 L2 | protect-the-weakest（多层）+ 明确 deny reason | L3 仍需主 agent 派 L2（框架限制）；登记 L3 'prompt 级 banner 可忽略'为已知限制 |
| D4 | _l3_check_rerun 改 `## L3` 段（regex `^## L3 (盲审\|重审)` 前缀匹配真实 token，与 l3-review.sh:461 一致 · 回应 L3-task-R1 🔴）+ artifact hash（INDEPENDENT-REVIEW-N.md 末尾 `L3_artifact_hash: <sha>` 元数据，**不触 .done**）；删 mtime case 死代码 ~22 行 | 维持 mtime / hash 存 .done（破坏 KVP，否决）/ `(盲审\|外部模型审查)$`（零匹配真实标题，否决）| 内容标记精确 + hash 捕真实变更 + 不破坏 .done | hash 开销；判定优先级=hash 变→重审/段空→重审/否则 skip |
| D5 | 26-workflow.sh G1 检测 `goal.scope=pipeline` 时不 auto-advance `.phase` | G1 同步四字段 / 删 fk_auto_phase | 最小侵入；pipeline goal 推进语义本归 toll-gate | 单阶段/双模式分支（测试覆盖两路径）|

---

## 2. 数据流 / 架构图（L2/L3 审查触发链 · gate_config=both）

```
              phase 产物完成（REQUIREMENT/DESIGN/...）
                        │
      ┌─────────────────┴──────────────────┐
      ▼                                    ▼
 PreToolUse gate                 Stop hook 链（00-gate → 29）
 (transition 时同步)                       │
      │                                    ▼
      ▼                           29 D4 L2-first 门：
 主 agent 派 L2 子 agent          ## L2 盲审 段存在？
 → 写 ## L2 盲审 段                        │
      │                          ┌─────────┴─────────┐
      └────────► 下轮 Stop ◄─────┘                   │
                  │                                  │
                  ▼（L2 段已存在）                    │
          29 D4 门通过 → l3_review_run               │
                  │                                  │
                  ▼                                  │
        L3 写 ## L3 段 + .done  ◄──────────────────┘
                  │
                  ▼
      _l3_check_rerun：## L3 段 + hash 判定重审（D4）

 关键：L3 永远等 L2 段就绪（D4 门）· Stop 不能自派 L2（框架限制）
      → 主 agent 必须主动派 L2（AC-I 文档化此契约）
```

---

## 3. 关键状态机（gate_config=both · L2-first 顺序）

```
[产物完成] → [主 agent 派 L2] → [L2 段写入 INDEPENDENT-REVIEW-N.md]
                                      │
                          ┌───────────┴────────────┐
                          ▼                        ▼
                   [Stop hook 29]          [PreToolUse gate]
                   D4 门检测 ## L2 段      transition 同步触发
                   存在 → l3_review_run    l3_review_run
                          │                        │
                          └──────────┬─────────────┘
                                     ▼
                          [L3 写 ## L3 段 + .done]
                                     │
                                     ▼
                    [幂等：.done 存在 → 后续 Stop 跳过]
                                     │
                                     ▼
                  [_l3_check_rerun：## L3 段 + hash 判定重审]（D4）
```

---

## 4. ADR 索引

- `@.specs/adr/007-phase-gate-key-pure-fn.md` — PHASE_GATE_KEY_MAP 单一来源 pure fn（D1）
- `@.specs/adr/008-is-git-commit-quoting-aware.md` — is_git_commit quoting/heredoc 感知（D2）
- `@.specs/adr/009-l2-first-ordering-contract.md` — L2-first 顺序契约（D3）
- `@.specs/adr/010-l3-check-rerun-content-marker.md` — _l3_check_rerun 内容标记 + hash 载体（D4 · 回应 L2-R-D4-1/R-D4-2/R-D4-3）
- `@.specs/adr/011-pipeline-goal-no-g1-autoadvance.md` — 26-workflow.sh G1 pipeline 模式不 auto-advance（D5 · 禁动破例）

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | D1 pure fn 破坏 v1 forward transition gate | gate 安全门失效 | 中 | INT-7 回归 + pure fn 单测逐 key + NFR-3 stderr 三要素 |
| R2 | D2 quoting 漏判真实 git commit | commit 误放行 | 中 | AC-H (d)(e) 集成测试 + 反规避 grep (f) |
| R3 | D2 quoting 误伤合法命令 | 误拦 | 中 | 等价类 (a)-(e) 全覆盖 |
| R4 | D5 改 26-workflow.sh 影响单阶段 goal | 单阶段推进失效 | 低 | 集成测试覆盖 pipeline + 单阶段两路径 |
| R5 | D3 契约下 L2 漏派导致 L3 漏跑 | 审查缺失 | 中（降：correction banner 兜底）| 29 D4 提示 + `.flow-active.correction` → SessionStart 强提示 banner + 可观测性日志（回应 L2-R-D3-R5：hook 层兜底非纯 prompt）|
| R6 | D4 hash 判定与既有 .done 幂等冲突 | 重审循环或漏审 | 低 | 集成测试：touch 不重审 + 内容变重审 |

> 含实现风险（R1-R4）/ 长期债（R5 文档契约维护）/ 上线风险（R6 既有状态兼容）

---

## 6. 不在范围

- 重写 `_run_review_gates` 7 Gate 编排架构（AC-F 边界声明）
- 改 L2 子 agent 盲审机制（L2-blind-review.md）
- flow-kit 层锁定/替换 L3 模型（跟随 ANTHROPIC_DEFAULT_HAIKU_MODEL · glm-5.1 已可靠）
- Stop hook 自动派 L2 子 agent（框架硬限制，D3 显式不追求）
- BUG-I "Stop 触发不可靠"的原假设（已由 Explore 诊断为 L2-first 契约，D3 文档化）

---

## 9. 架构沉淀建议（供 A-evolve）

### 9.1 新增可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `common.sh::fk_phase_gate_key` | phase→gate_key 单一来源 pure fn | 任何需 phase→gate_config key 查询的 hook | 以后新增 hook 用此 fn，禁止再 declare -A |

### 9.2 项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| gate 映射单一来源 | pure fn（替代重复 declare）| 所有 gate hook 消费者 | 低（回 declare 即可，但失 DRY）|
| L2-first 顺序契约 | gate_config=both 时 L2 段先于 L3 | 所有 both 阶段审查 | 中（改 29 D4 门逻辑）|

### 9.3 跨模块契约

```
- gate_config=both 阶段：主 agent 必须派 L2 子 agent + 写 ## L2 盲审 段，Stop hook 才能 L3
- 29 D4 门（29-independent-review.sh:136）是此契约的执行点
- .independent-review-<phase>.done 是幂等标志（written_by 标识触发源：pre-tool-use-gate / l3-review）
```

### 9.4 依赖变动
N/A（纯 Bash，无新增依赖）

### 9.5 禁动清单变化

```
- 新增禁动：禁止在 common.sh 之外再 declare -A PHASE_GATE_KEY_MAP（NFR-4 grep 守护，重构后 = 0 处）
- 新增禁动：is_git_commit 实现禁用字符串白/黑名单（AC-H (f) 反规避）
```

---

> 本文件不含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行（R3.1）。
