# DESIGN: 补齐 L2/L3 独立审查 3/5/7 缺失

## 0. 技术栈选定

**已锁定**（来自 CONTEXT.md）：Bash 脚本项目，无传统技术栈。修改对象为 markdown prompt 文件 + Bash hook lib + bats 测试。

- 语言：Bash（`set -euo pipefail`）
- 测试：bats-core 1.13.0（`npx bats`）
- 静态验证：`check-gate-sync.sh`（SKILL.md ↔ bats 一致性）

## 0.5 既有架构对齐

### 0.5.1 本次 change 触碰的既有模块

```
会修改：
- ~/.claude/flow-kit/prompts/3-task.md          （新增「独立 review 调度」段）
- ~/.claude/flow-kit/prompts/5-test.md          （新增「独立 review 调度」段）
- ~/.claude/flow-kit/prompts/7-integration.md   （新增「独立 review 调度」段）
- ~/.claude/flow-kit/prompts/independent/L2-blind-review.md  （扩展 3/5/7 checklist）
- flow-kit-bundle/skills/flow/SKILL.md           （PRESET_MAP + gate-config 合法值）
- ~/.claude/flow-kit/reference/pipeline-gates.md （说明文字同步）
- flow-kit-bundle/test/test_gate_config_presets.bats （新预设测试用例）

不应触碰：
- flow-kit-bundle/hooks/stop/29-independent-review.sh （gate-integrity 已完成）
- flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh （gate-integrity 已完成，case 已含 3/5/7）
- ~/.claude/flow-kit/prompts/1-requirement.md   （现有 1/2/6 机制不变）
- ~/.claude/flow-kit/prompts/2-design.md         （现有 1/2/6 机制不变）
- ~/.claude/flow-kit/prompts/6-review.md         （现有 1/2/6 机制不变）
- package-flow-kit.sh                             （禁动清单 · 打包核心逻辑）
```

### 0.5.2 对齐既有抽象

| 本次需要 | 既有有没有？ | 决定 |
|---|---|---|
| 独立审查调度段模板 | 1-requirement/2-design/6-review 已有完整模板 | 沿用：复制结构，替换阶段参数（阶段号、subagent_type、输出文件名） |
| L2 盲审 checklist | L2-blind-review.md 已有 1/2/6 checklist | 沿用格式：`### 阶段 N · <名称>（<phase-key>）` + 条目用 `- **<维度>**：<说明>` |
| PRESET_MAP 预设名 | SKILL.md 已有 8 个预设名 + 数字映射 | 沿用命名约定：单阶段=阶段名，组合=`阶段1-阶段2` 连字符 |
| gate_config 值解析 | SKILL.md 已有三段式 auto-detect | 不改动解析逻辑，只扩展 PRESET_MAP 表 |
| bats 测试模式 | test_gate_config_presets.bats 已有 resolve_gate_config 测试 | 沿用：每个预设一个 test case，验证 JSON 输出 |

### 0.5.3 沿用模式 vs 引入新模式

- **Prompt 段结构**：**沿用** 1/2/6 的「独立 review 调度」段格式（gate 检测 → L2 模板 → L3 说明 → done 指令）
- **PRESET_MAP 命名**：**沿用** 现有命名约定（kebab-case，阶段名连字符）
- **L2 checklist 格式**：**沿用** 现有四要素 + 严重度格式
- **验证方式**：**沿用** check-gate-sync.sh set-diff + bats 模式
- **无引入新模式**：所有修改都在既有框架内

## 1. 技术决策

### D1 · PRESET_MAP 命名约定

**决策**：新增预设名遵循以下约定：
- 单阶段：用阶段英文名（`task` / `test` / `integration`），与现有 `design` / `requirement` / `review` 一致
- 两阶段组合：`<阶段1>-<阶段2>`（如 `task-review`、`test-review`、`task-test`）
- 三阶段组合：`<阶段1>-<阶段2>-<阶段3>`（如 `task-test-review`）
- 特殊：`spec-test` = 1-requirement + 2-design + 5-test（原名 `plan-test`，因歧义改名——"plan test" 容易被理解为"规划测试"而非"规划阶段+测试阶段"）

**备选**：
- `plan-and-test`：排除——"plan" 语义过宽，用户可能理解为"先规划后测试"的工作流指令而非阶段集合名
- `req-design-test`：排除——三个单词过长，与现有单/双词预设名（`full`/`code-only`/`design-review`）风格不一致
- `full-plus-test`：排除——"full" 暗示覆盖所有阶段（类似 `all`），但实际上只有 1+2+5，名不副实

**选择理由**：`spec-test` 简洁（两词）、与 `spec` 语义一致（specification = requirement + design），且与现有 `code-only` 风格统一
**取舍代价**：用户首次见到 `spec-test` 需查文档才能理解其覆盖范围；但 PRESET_MAP 注释会写明映射关系 `# spec-test → {"1-requirement":"independent","2-design":"independent","5-test":"independent"}`

### D2 · Prompt 段结构复用策略

**决策**：3/5/7 的「独立 review 调度」段从 1/2/6 完整复制结构，仅替换以下参数：

| 参数 | 阶段 3 | 阶段 5 | 阶段 7 |
|---|---|---|---|
| subagent_type | `architect-reviewer` | `qa-expert` | `architect-reviewer` |
| 审查工件 | TASK.md | TEST.md | 归档完整性（全部产物） |
| 输出文件 | INDEPENDENT-REVIEW-3.md | INDEPENDENT-REVIEW-5.md | INDEPENDENT-REVIEW-7.md |
| done 标记 | .independent-review-3.done | .independent-review-5.done | .independent-review-7.done |
| L3 审查对象 | TASK.md | TEST.md + bats 结果 | 全部产物 + LESSONS.md |

**备选**：为 3/5/7 新写独立的 prompt 文件
**选择理由**：1/2/6 的段结构已经过 L2 盲审 + gate-integrity dogfood 验证，成熟可靠。复制是 DRY 的反面但在此场景下是最安全的策略——每阶段独立维护、修改不会级联影响
**取舍代价**：prompt 样板重复率上升（TD-004 技术债），但独立审查段本身 ~30 行，增量有限

**错误处理指令设计**（对齐 REQUIREMENT.md 错误处理 NFR）：

prompt 段中 L2 调度指令的尾部追加以下错误处理指令：
- 若 L2 子 agent 调用失败（超时 / API error / 返回空内容）→ 输出 `❌ L2 审查失败：<原因>，pipeline 暂停`，**不写 .done**
- 若 L2 返回 verdict=fail → 输出 `⛔ L2 审查 verdict: fail，pipeline 暂停`，**不写 .done**
- 若 L2 返回 verdict=pass → 输出 `✅ L2 审查通过`，继续写 .done

这 3 条指令写入 3/5/7 各 prompt 段的「写 done」部分之前，确保主 agent 在失败场景不静默跳过。

### D3 · L2-blind-review.md 3/5/7 checklist 结构

**决策**：每个阶段 checklist 包含以下维度：

**阶段 3（任务拆解审查）**：
- 任务粒度 — 单 task ≤ 200 行变更、波次划分清晰
- 依赖链 — 无环、可并行部分已标注
- verify 可验证性 — 每条 verify 可机器执行（非"人工确认"空话）
- 覆盖完整性 — 所有 AC 有对应 task、read_files/write_files 约束到位

**阶段 5（测试审查）**：
- AC 覆盖 — 测试矩阵覆盖所有 AC（每条 AC ≥ 1 测试用例）
- 5 轮金字塔 — 功能/性能/安全/兼容/可观测逐轮填写、跳过的有理由
- 覆盖率达标 — 功能 100% AC 覆盖
- UAT 可执行 — Given/When/Then 可脚本化

**阶段 7（集成审查）**：
- 产物齐全 — CHANGE/REQUIREMENT/DESIGN/TASK/SUMMARY×N/TEST/REVIEW 全部存在
- LESSONS 同步 — 从 REVIEW 提取了新教训
- CHANGELOG 更新 — 本次 change 条目已追加
- 归档清洁 — 无残留临时文件

**备选**：用通用段覆盖 3/5/7（不写阶段专属 checklist）
**选择理由**：3/5/7 的审查对象差异大（TASK vs TEST vs 归档），通用段会漏抓阶段特有问题
**取舍代价**：L2-blind-review.md 从 ~75 行增至 ~120 行，token 略有增加

### D4 · gate-config 合法值列表扩展

**决策**：`/flow gate-config` 子命令的合法值列表从 `1-requirement / 2-design / 6-review` 扩展为全 6 个阶段名。但 `/flow gate-config` 作为手动 patch 工具，**不受 PRESET_MAP 预设名限制**——用户传入任意合法阶段名 + `independent`/`off` 即可生效。

**备选**：仅限 PRESET_MAP 中已有预设覆盖的阶段
**选择理由**：`/flow gate-config` 是手动 patch 工具，不是预设选择器。用户可能想单独开关某个阶段（如只开 5-test 的独立审查），不应被预设覆盖范围限制
**取舍代价**：用户可能对未补 prompt 的阶段开启 gate-config，造成 pipeline 死锁。在 SKILL.md 加提示"开启前确认对应阶段 prompt 已含独立审查段"

### D5 · 单阶段 3/5/7 gate-config 的合法化

**决策**：将 `3-task` / `5-test` / `7-integration` 加入 `/flow gate-config` 子命令的合法 `<phase>` 值列表，接受 `independent` / `off` 两种值。

**验证**：`pipeline-gates.md` L75 加注 "3/5/7 prompt 层支持由 `independent-review-gap` change 补齐"，消除 "default off but not implemented" 的误导。

## 2. 架构图

```
┌─ PRESET_MAP (SKILL.md) ───────────────────────────────────┐
│ 预设名 ──resolve_gate_config()──→ gate_config JSON         │
│                                                             │
│ full     → {"1-requirement":"independent",                  │
│             "2-design":"independent",                       │
│             "6-review":"independent"}                       │
│                                                             │
│ all      → + "3-task":"independent",                        │
│             "5-test":"independent",                         │
│             "7-integration":"independent"                   │
│                                                             │
│ [新增] task / test / integration / task-review /            │
│        test-review / task-test / task-test-review /         │
│        spec-test                                            │
└─────────────────────────────────────────────────────────────┘
        │
        │ gate_config[phase] = "independent"
        ▼
┌─ Prompt 层（主 agent 调度 L2）────────────────────────────┐
│                                                             │
│ 1-requirement.md ── 独立 review 调度段 ✅ (已有)            │
│ 2-design.md      ── 独立 review 调度段 ✅ (已有)            │
│ 3-task.md        ── 独立 review 调度段 ❌ → ✅ (本次补)     │
│ 5-test.md        ── 独立 review 调度段 ❌ → ✅ (本次补)     │
│ 6-review.md      ── 独立 review 调度段 ✅ (已有)            │
│ 7-integration.md ── 独立 review 调度段 ❌ → ✅ (本次补)     │
│                                                             │
│ 每段含: gate检测 → L2模板 → L3说明 → done指令               │
└─────────────────────────────────────────────────────────────┘
        │
        │ 主 agent 派 L2 子 agent（原样注入 L2-blind-review.md）
        ▼
┌─ L2-blind-review.md（固化盲审指令）───────────────────────┐
│                                                             │
│ 阶段 1 checklist ✅  阶段 3 checklist ❌ → ✅ (本次补)      │
│ 阶段 2 checklist ✅  阶段 5 checklist ❌ → ✅ (本次补)      │
│ 阶段 6 checklist ✅  阶段 7 checklist ❌ → ✅ (本次补)      │
└─────────────────────────────────────────────────────────────┘
        │
        │ L2 写完 INDEPENDENT-REVIEW-{N}.md L2 段
        ▼
┌─ Hook 层（Stop hook · gate-integrity 已完成）─────────────┐
│                                                             │
│ 29-independent-review.sh → L3 外部模型盲审                  │
│ flow-kit-artifacts.sh → fk_independent_review_gate_active   │
│   case 1/2/3/5/6/7 ✅ (gate-integrity 已扩)                 │
│ PreToolUse hook → 拦 commit/PR/transition 直到 .done 存在   │
└─────────────────────────────────────────────────────────────┘
```

**数据流**：
1. 用户 `/flow goal --gate-config <preset>` → SKILL.md resolve_gate_config() → gate_config JSON
2. Pipeline 推进到阶段 N → 主 agent 读 prompt → 检测 gate_config["<phase>"] = "independent" → 派 L2 子 agent
3. L2 子 agent 原样注入 L2-blind-review.md → 查对应阶段 checklist → 写 INDEPENDENT-REVIEW-{N}.md L2 段
4. 本轮结束 → Stop hook 29 号跑 L3 外部模型盲审 → 写 INDEPENDENT-REVIEW-{N}.md L3 段
5. 下一轮 SessionStart → 主 agent 确认 L2+L3 齐全 → touch .done → transition 放行

## 3. 详细设计 — Prompt 段模板

以阶段 3（3-task）为例，完整的「独立 review 调度」段模板如下。阶段 5/7 的参数替换见 D2 表。

```markdown
## 独立 review 调度（仅当本阶段 gate 开启时执行）

> **检测**：`.flow-active.goal.gate_config["3-task"]` ∈ {`independent`,`true`}，或 `.claude/stop-hook.json` 的 `independent_review.phases` 含 `"3-task"`。未开启 → 跳过本段，直接进「阶段完成自检」。

本阶段产物必须通过两层独立 review 才能切阶段 / commit / 开 PR。开启时这三项操作被 PreToolUse hook 硬拦，直到你写 done 标志。

### L2 · 独立子 agent 盲审（你负责调度）

派一个**固化盲审子 agent**。**强制独立性**：prompt 字段 = 原样注入 `@flow-kit/prompts/independent/L2-blind-review.md` 全文 + 末尾的本次审查参数；**禁止**附加你的自评 / 草稿 / 概述 / "我觉得没问题"——违反 = L2 独立性失效 = 等同没做。

调用模板（仅替换 `<change-id>`，其余原样）：

    Agent tool:
      subagent_type: architect-reviewer
      description: "L2 blind review phase 3"
      prompt: |
        <原样粘贴 @flow-kit/prompts/independent/L2-blind-review.md 的完整内容>

        ## 本次审查参数
        - 阶段：3
        - change-id：<change-id>
        - 工件：读 .specs/<change-id>/TASK.md（参考 .specs/<change-id>/REQUIREMENT.md、.specs/<change-id>/DESIGN.md）
        - 输出：写入 .specs/<change-id>/INDEPENDENT-REVIEW-3.md 的「## L2 盲审」段（若文件不存在则新建，首行加 `# 独立审查 · 阶段 3`）

### L3 · 外部模型审查（Stop hook 自动跑 · 你不用调度）

你本轮结束后，Stop hook 的 `29-independent-review.sh` 自动用外部模型盲审 TASK.md，写 `INDEPENDENT-REVIEW-3.md` 的 L3 段 + `.flow-active.independent-review` 握手。下一轮 SessionStart 会注入报告摘要。

### 错误处理

- 若 L2 子 agent 调用失败（超时 / API error / 返回空内容）→ 输出 `❌ L2 审查失败：<原因>，pipeline 暂停，等待人工介入`，**不写 .done**
- 若 L2 返回 verdict=fail → 输出 `⛔ L2 审查 verdict: fail，pipeline 暂停`，**不写 .done**
- 若 L2 返回 verdict=pass → 输出 `✅ L2 审查通过`，继续

### 写 done（L2 + L3 都完成后）

确认 `INDEPENDENT-REVIEW-3.md` 同时含 L2 段 + L3 段后执行：

    touch .specs/<change-id>/.independent-review-3.done

写完才能切阶段 / commit / 开 PR。L3 连续失败 ≥3 次时，可凭提示手动 touch 继续，不强制卡死。
```

**阶段 5/7 差异**：将 `3-task` → `5-test` / `7-integration`、`TASK.md` → `TEST.md` / `归档完整性`、`architect-reviewer` → `qa-expert` / `architect-reviewer`、输出文件名 `3` → `5` / `7`（完整参数映射见 D2 表）。

## 4. 风险

### R1 · 实现风险：prompt 段复制时参数替换遗漏

**概率**：中。3 个 prompt 文件 + L2-blind-review.md 涉及约 15 处阶段号/文件名替换，人工逐文件编辑容易漏。
**影响**：主 agent 在阶段 N 读 prompt 时被引导到错误的输出文件或子 agent 类型，独立审查写错位置。
**缓解**：
- 实施时用 grep 逐项验证（AC-1 的 bash 脚本做静态检查）
- L2 盲审在设计阶段就对照检查参数替换
- 事后用 AC-7 端到端验证脚本确认

### R2 · 上线风险：用户误用 `all` 预设导致 token 成本骤增

**概率**：中。`all` 预设名自带"全选"暗示，用户可能低估成本直接选用。CONTEXT.md 锁决策 `[2026-07-01]` 已将 3/5/7 默认关闭——正是因为此风险不可忽略。
**影响**：若用户选 `all`，每次 pipeline 推进多 3 次 L2 盲审 + 3 次 L3 Stop hook 调用，token 成本增加约 30k-75k。
**缓解**：
- SKILL.md PRESET_MAP 注释中 `all` 行追加 `⚠️ 预计增加 30k-75k tokens/pipeline run`
- `/flow goal --gate-config all` 首次使用时，若检测到 gate_config 含 ≥ 4 个 independent 阶段，输出 token 成本警告
- 保持 `full` 预设为默认推荐（仅 1/2/6）

### R3 · 长期债务：prompt 样板重复率上升

**概率**：确认。3 个新 prompt 段的增加使「独立 review 调度」段在 6 个文件中逐字重复。
**影响**：未来若修改独立审查机制（如 L2 调用参数变更），需同步 6 处而非 3 处。这是 TD-004 技术债的延续。
**缓解**：
- 在 DESIGN § 9.2 标注"下次独立审查机制变更时，优先抽取共享 `_shared/independent-review.md` 引用片段"
- 当前不抽取——6 处仍在可控范围内，且 check-gate-sync.sh 可检测漂移

### R4 · 上线风险：gate-config 开启但 prompt 未补全导致死锁

**概率**：低。本次 change 就是补 prompt，正常安装流程二者同步；但部分升级场景（只更新 SKILL.md 未更新 prompt 文件）可能触发。
**影响**：若用户对 3/5/7 开启 gate-config 但对应 prompt 未含独立审查段，主 agent 不知道该调 L2 和写 done → hook 层拦 transition → pipeline 死锁。
**缓解**：
- `package-flow-kit.sh` 打包时确保 prompt + SKILL.md 同捆（同一 tarball，不会部分安装）
- `pipeline-gates.md` L75 加注 "3/5/7 prompt 层支持由 `independent-review-gap` change 补齐"
- AC-7 端到端验证脚本可检测此故障模式（模拟环境下若 prompt 缺失则 INDEPENDENT-REVIEW 文件不会被产出）

## 5. 不在范围内

- 4-dev 独立审查段（执行阶段审查由 6-review 覆盖，4-dev 已有 1.8 自检 gate）
- Hook 层修改（gate-integrity 已完成）
- 自动检测 prompt 是否有独立审查段（当前依赖人工 + check-gate-sync.sh）
- 为 PRESET_MAP 预设名提供 `--help` 或 tab-completion

## 6. NFR 设计验证

逐条对照 REQUIREMENT.md 的非功能性需求，确认设计满足：

| NFR | REQUIREMENT 要求 | 设计确认 |
|---|---|---|
| 兼容性 | 1/2/6 行为不变、8 个预设解析不变 | D2 明确"复制结构不改变原有文件"；PRESET_MAP 仅追加新行 |
| 可维护性 | 新增段与 1/2/6 模式一致 | D2 参数替换表 + §3 完整模板示例，实施者直接复制 |
| 测试 | bats 不退化（≥216 pass） | §8 测试策略：unit + integration + regression |
| 安全性 | done 路径限定/无注入/子 agent 隔离 | .done 路径限定 `.specs/<id>/` 内（与 1/2/6 同目录同权限）；L2 指令为固化模板无用户拼接；子 agent 隔离由 Claude Code Agent 沙箱保证 |
| 性能 | prompt 增量 <200 行/文件，延迟增加可接受 | §3 模板 ~45 行（含错误处理），3 文件共 ~135 行增量，单次推理 token 增量约 1.5k-2.5k，延迟影响 <3% |
| 可观测性 | 3 条日志输出约定 | 已写入 §3 prompt 模板中的「错误处理」段（调 L2/失败/完成 均有输出） |
| 错误处理 | L2 失败/done 写失败/verdict=fail 各场景行为 | D2 错误处理指令设计 + §3 模板"错误处理"段，3 条指令明确 |

## 8. 测试策略

| 层级 | 覆盖范围 | 验证方式 | 对应 AC |
|---|---|---|---|
| Unit | PRESET_MAP 新预设解析正确性 | `npx bats test/test_gate_config_presets.bats --filter "preset"` | AC-2, AC-3, AC-6 |
| Static | Prompt 文件结构完整性 | AC-1 bash 验证脚本（4 项 grep） | AC-1 |
| Static | L2-blind-review.md checklist 内容质量 | AC-4 bash 验证脚本（≥3 条目/阶段） | AC-4 |
| Integration | 端到端：prompt 含段 + done 可写入 | AC-7 bash 验证脚本（fixture 模拟） | AC-7 |
| Regression | 现有功能不退化 | `npx bats test/` 全量（目标 ≥216 pass） | AC-6 |
| Sync | SKILL.md ↔ bats 预设名一致 | `check-gate-sync.sh` set-diff | AC-3 |

## 9. 架构沉淀建议

### 9.1 新增可复用抽象

无。本次是 prompt 模板补全 + 配置表扩展，不引入新的可复用抽象。

### 9.2 项目级技术决策

- `[2026-07-02]` PRESET_MAP 命名约定已锁定：单阶段=阶段名，组合=阶段名连字符。新增预设必须遵循此约定。来自 `independent-review-gap` D1
- `[2026-07-02]` 独立审查 prompt 段结构已标准化：gate 检测 → L2 模板（含 subagent_type/审查工件/输出路径）→ L3 说明 → done 指令。未来新增阶段的独立审查段按此模板复制。来自 `independent-review-gap` D2
- `[2026-07-02]` 独立审查四层架构确认：PRESET_MAP → Prompt 模板 → Hook 层 → L2-blind-review.md。任一层变更需检查其余三层是否同步。来自 `independent-review-gap`

### 9.3 跨模块契约

无。本次变更不改动 hook 层 API 或 prompt 间调用接口。

### 9.4 依赖变动

无。本次不涉及外部依赖。

### 9.5 禁动清单变动

- 新增禁动：`~/.claude/flow-kit/prompts/independent/L2-blind-review.md` 的 checklist 条目格式应保持「四要素 + 严重度」结构，禁止降级为纯文本段落
- 新增禁动：PRESET_MAP 预设名一旦发布，禁止改名（会破坏已有用户配置）。新增预设只能追加，不能重命名已有预设
