# DESIGN: 诊断 pipeline 自动推进 + 回退模式

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/REQUIREMENT.md`、`@.specs/CONTEXT.md`

---

## 0. 技术栈选定

**锁定**（来自 CONTEXT.md 已锁决策）：Bash — 纯脚本/CLI 项目，无框架、无 DB、无前端。

诊断过程本身不涉及任何代码变更，无需新建模块或引入新依赖。

---

## 0.5 既有架构对齐

### 本次 change 会触碰的既有模块

```
📖 只读（诊断观察对象）：
  - ~/.claude/flow-kit/prompts/0-change.md ~ 7-integration.md（8 个阶段 prompt，含 Pipeline Toll-Gate 段）
  - ~/.claude/flow-kit/GO.md（transition/PCG 路由逻辑）
  - ~/.claude/skills/flow/skill.md（pipeline goal 状态管理）
  - ~/.claude/skills/flow-go/skill.md（流程路由）

🪝 只观察行为，不修改：
  - ~/.claude/hooks/pre-tool-use/independent-review-gate.sh（PreToolUse 拦截）
  - ~/.claude/hooks/stop/27-interactive-ui-check.sh（交互 UI 矫正）
  - ~/.claude/hooks/stop/28-weak-model-compliance.sh（合规矫正）
  - ~/.claude/hooks/stop/29-independent-review.sh（L3 独立审查）

📄 会写入（诊断输出）：
  - .specs/pipeline-fallback-fix/DIAGNOSIS.md（诊断报告）
  - .specs/pipeline-fallback-fix/*.md（各阶段产物，正常 pipeline 流程）

🔒 禁动（与本次无关，禁止修改）：
  - package-flow-kit.sh
  - flow-kit-bundle.tar.gz
  - .gitignore
  - 所有 ~/.claude/flow-kit/ 下的 prompt/hook/skill 文件（只观察，不修改）
```

### 沿用模式 vs 引入新模式

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| pipeline 自动推进 | GO.md transition 逻辑 + 各 prompt Toll-Gate 段 | 沿用，只观察行为不修改 |
| gate 状态管理 | flow skill `/flow goal --pipeline` | 沿用现有 jq 命令 |
| 独立审查 gate | independent-review-gate.sh + L2-blind-review.md | 沿用，诊断自身会触发并观察 |
| fallback 模式 | GO.md 的 native/fallback 分支 | 沿用，通过 mode 字段模拟 |
| 诊断证据收集 | 无既有工具 | **新建**：手工 transcript 摘录 + jq 快照 |
| 诊断报告格式 | 无既有模板 | **新建**：DIAGNOSIS.md（自由格式，按 AC 逐项标记） |

---

## 1. 技术决策

### D1 · 诊断方法论：双路径对比法

- **决策**：在 native（CC /goal）和 fallback（prompt 迭代）两条路径上分别跑 0→7 pipeline，逐 toll-gate 对比行为
- **备选**：单路径深度排查（只查 native，逐段加 debug 日志）→ 拒绝，因为 fallback 路径完全未测试，单路径无法发现差异
- **选择理由**：CHANGE.md 列出的异常迹象同时在两条路径上出现；双路径对比能区分"通用问题"和"路径特有问题"
- **代价**：token 消耗翻倍（两条路径各跑一轮）。缓解：fallback 路径只跑关键阶段（4→5→6→7），0-3 人工决策阶段只在 native 路径跑

### D2 · fallback 模拟方式

- **决策**：直接设置 `.flow-active.goal.mode = "fallback"` 模拟
- **备选**：修改 `claude --version` 输出或临时替换 claude 二进制 → 拒绝，侵入性太强且影响其他功能
- **选择理由**：GO.md 的 mode 检测逻辑优先读 `.flow-active.goal.mode` 字段，直接设值是最干净的方式
- **代价**：不验证"版本检测触发 fallback"的完整路径。缓解：AC-7 的注释已标注此限制，v2 可补充环境变量模拟

### D3 · auto_advance=true 隔离测试

- **决策**：在独立分支上用最小 change 测试 auto_advance=true，不污染当前 change 的 pipeline 状态
- **备选**：在当前 change 上临时切换 auto_advance → 拒绝，会扰乱正在进行的诊断流程
- **选择理由**：当前 change 的 auto_advance=false（默认），诊断其 toll-gate 行为本身就是 AC-3 的验证对象
- **代价**：需要额外创建一个最小 change。缓解：最小 change 只需 CHANGE.md + REQUIREMENT.md，token 开销小

### D4 · 证据收集标准

- **决策**：对每个 ❌/⚠️ AC，收集 ≥3 行 transcript 摘录 + jq 状态快照 + 时间戳
- **备选**：描述性总结（"看起来不工作"）→ 拒绝，缺乏可复现性
- **选择理由**：AC-11 显式要求 a/b/c 三项证据，且诊断报告的后续修复 change 需要可复现的根因描述
- **代价**：手工摘录 transcript 耗时。缓解：关键 AC 只在 toll-gate 和 transition 两个关键点摘录

---

## 2. 诊断流程 / 架构图

```
┌─────────────────────────────────────────────────────────┐
│                   pipeline-fallback-fix                 │
│                    诊断执行流程                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Phase 0-3（规划链·当前 change 自身）                      │
│  ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐          │
│  │  0   │───→│  1   │───→│  2   │───→│  3   │          │
│  │CHANGE│    │ REQ  │    │DESIGN│    │ TASK │          │
│  └──────┘    └──────┘    └──────┘    └──────┘          │
│       ↓           ↓           ↓           ↓             │
│  观察 toll-  观察 L2/L3   观察 gate   观察 TASK          │
│  gate 行为   gate 行为   死锁行为    拆分行为             │
│                                                         │
│  Phase 4-7（执行链·诊断任务执行）                          │
│  ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐          │
│  │  4   │───→│  5   │───→│  6   │───→│  7   │          │
│  │ DIAG │    │VERIFY│    │REVIEW│    │ARCHIVE│          │
│  │ 执行  │    │ 报告  │    │ 报告  │    │ 报告  │          │
│  └──────┘    └──────┘    └──────┘    └──────┘          │
│       ↓           ↓           ↓           ↓             │
│  执行诊断    验证 AC     审查诊断    归档诊断             │
│  收集证据    覆盖完整性  报告质量    报告                 │
│                                                         │
│  ═══════════════════════════════════════════════════    │
│  并行·auto_advance=true 最小验证（独立分支）               │
│  ┌──────┐    ┌──────┐    ┌──────┐                      │
│  │ mini │───→│ mini │───→│ mini │  （auto_advance=true） │
│  │  0   │    │  1   │    │  4   │  观察自动推进行为       │
│  └──────┘    └──────┘    └──────┘                      │
│  ═══════════════════════════════════════════════════    │
│  并行·fallback 模式验证（mode="fallback"）                │
│  ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐          │
│  │  4   │───→│  5   │───→│  6   │───→│  7   │          │
│  │(模拟)│    │(模拟)│    │(模拟)│    │(模拟)│          │
│  └──────┘    └──────┘    └──────┘    └──────┘          │
│       ↓           ↓           ↓           ↓             │
│  对比 native  对比 native  对比 native  对比 native       │
│  路径行为    路径行为     路径行为     路径行为            │
│                                                         │
│  输出：DIAGNOSIS.md                                      │
│  ┌────────────────────────────────────────────┐         │
│  │ Per-AC status (✅/⚠️/❌) + root cause        │         │
│  │ Native vs Fallback diff table               │         │
│  │ Prioritized fix recommendations             │         │
│  │ Evidence appendix (transcript + snapshots)  │         │
│  └────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────┘
```

**关键状态机**：

```
Pipeline Turn（每个阶段）：
  ┌──────────┐    全✅    ┌──────────┐   确认    ┌────────────┐
  │ PCSC 自检 │──────────→│Toll-Gate │──────────→│ Transition │
  │          │  有❌暂停  │  交互    │  用户拒绝  │ (jq 更新)  │
  └──────────┘           └──────────┘           └────────────┘
       ↑                                              │
       └──────────────────────────────────────────────┘
                    下一阶段 PCSC

Gate 检查（独立审查开启时）：
  ┌──────────┐   .done存在+有效  ┌──────────┐
  │PreToolUse│─────────────────→│   放行   │
  │  Hook    │   .done缺失/无效  │          │
  │          │─────────────────→│  拦截❌  │
  └──────────┘                  └──────────┘
```

---

## 3. ADR

本 change 为纯诊断任务，无可逆性技术决策。不产生 ADR。

---

## 4. 风险

| # | 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|---|
| R1 | 诊断过程被被测 bug 阻塞（pipeline 卡在某个阶段无法推进） | 高 | 中 — 无法完成全链路诊断 | 记录卡点作为诊断数据；手动绕过继续下一阶段 |
| R2 | gate_config 篡改检测死锁（已遭遇一次）再次发生 | 中 | 高 — 完全阻塞 | 诊断前关闭所有独立审查 gate，避免 L2+L3 异步死锁 |
| R3 | fallback 模拟不准确（mode 字段覆盖 ≠ 真实版本检测路径） | 中 | 中 — fallback 诊断结论可能不完整 | AC-7 注释已标注此限制；DIAGNOSIS.md 中显式声明覆盖盲区 |
| R4 | token 预算超预期（gate_config all 的独立审查 + 双路径诊断） | 高 | 低 — 需要多轮会话 | 每轮会话结束后通过 Stop hook 自动记录状态，下一轮恢复 |
| R5 | 诊断过程修改全局状态（.flow-active 等）污染后续阶段 | 低 | 中 | 每步操作前 jq 快照 .flow-active；关键状态变更记录在 DIAGNOSIS.md |

---

## 5. 不在范围内

- 修改 flow-kit 源代码（prompt/hook/skill/lib/template）
- 新增 bats 自动化测试用例
- 重写或重构 pipeline 推进逻辑
- 修改 CC native `/goal` 行为
- 本次 change 的 DIAGNOSIS.md 产出后的修复工作

---

## 9. 架构沉淀建议

本 change 无架构层面沉淀建议。纯诊断任务，不引入新抽象/决策/契约/依赖/禁动清单变动。
