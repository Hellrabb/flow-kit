# DESIGN: 用户指南全量更新 + interrupt/checkpoint 自动写入

- **Change ID**: user-guide-update
- **关联**: `@.specs/user-guide-update/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 本项目为 flow-kit 分发包仓库（meta/distribution），无传统技术栈。已锁定决策见 CONTEXT.md。

- **选定**：不适用（非标准技术栈项目）
- **语言/运行时**: Bash（`set -euo pipefail`）+ jq（JSON 操作）
- **测试**: bats-core 1.13.0（npx）
- **理由**：本 change 仅修改 markdown 文档 + Bash 脚本（flow skill / prompt 文件），不引入新语言或框架
- **明确排除**：不做任何技术栈变更

---

## 0.5 既有架构对齐（brownfield · 来自 2-design 步骤 0.5 / B2 老项目护栏）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep/ls 验证的实际清单）：
- FLOW-KIT-用户指南.md（50.1K · 项目根 · 本次主更新目标）
- README.md（3.6K · 项目根 · 一致性同步）
- flow-kit-ecosystem-guide.md（10.1K · 项目根 · 一致性同步）
- ~/.claude/skills/flow/SKILL.md（15.1K · /flow skill 定义 · auto-checkpoint 触发逻辑）
- ~/.claude/flow-kit/prompts/*.md（0-change ~ 7-integration 共 15 个 prompt · PCSC/toll-gate 段加 auto-checkpoint 指令）
- ~/.claude/flow-kit/prompts/GO.md（路由入口 · interrupt 恢复逻辑）
- .specs/CONTEXT.md（术语追加 · 已在 phase 1 完成）

新增模块：
- `hooks/stop/lib/checkpoint-lib.sh`（PreToolUse hook 调用的共享 lib，~60 行 · 对应 9.1 架构沉淀）
- 各 prompt 文件 PCSC 段末尾 +3 行 auto-checkpoint 指令（15 个 prompt 各一处，非新文件）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh（打包脚本核心，改动影响分发流程）
- flow-kit-bundle.tar.gz（已生成的分发包）
- hooks/stop/lib/*.sh（hook lib 核心，如 correction-file.sh / l3-review.sh）
- flow-kit-bundle/hooks/stop/2[7-9]-*.sh / 3[0-2]-*.sh（已有合规/矫正/兜底 hook 模块）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| JSON 状态读写 | jq + `.flow-active`（`/flow` skill 已用） | **沿用** jq 原子写入模式（`.flow-active.tmp` + `mv`） |
| checkpoint 命令 | `/flow checkpoint`（`~/.claude/skills/flow/SKILL.md`） | **沿用** 现有接口，auto-checkpoint 调同一 jq 逻辑 |
| interrupt 恢复 | `GO.md` 路由表 `继续→4-dev 入场恢复` | **沿用** 现有恢复协议，auto-checkpoint 写入的字段格式兼容 |
| pipeline toll-gate | 各 prompt 的 `Pipeline Toll-Gate` 段 | **沿用** 现有 transit jq 模板，在 transition 执行前追加 auto-checkpoint |
| 文档格式 | 三份文档均为 GitHub Flavored Markdown | **沿用**，不引入新格式 |
| 原子写入 | jq 写 `.flow-active.tmp` + `mv`（`/flow` skill 全部子命令） | **沿用** 原子更新策略，auto-checkpoint 写入时同样保证 JSON 不被损坏 |

### 0.5.3 沿用模式 vs 引入新模式

```
- 状态管理：**沿用** .flow-active + jq 原子写入（既有 /flow skill 全部子命令用此模式）
- doc 同步策略：**沿用** docs-sync 三文档一致性策略（已锁决策 2026-06-22）
- checkpoint 触发：**引入新模式**（auto-checkpoint 非既有能力）→ 理由：既有 checkpoint 仅手动触发，本次新增 prompt 层自动触发 + hook 层兜底
- 双层防护：**沿用** prompt + hook 双层模式（与 auto_advance/fallback 的 prompt 指令 + 31/32 hook 兜底模式一致）
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **auto-checkpoint 双层实现**：prompt 层指令（AI 执行）+ PreToolUse hook 兜底 | 纯 prompt 层（无 hook）/ 纯 hook 层（无 prompt） | prompt 层覆盖全部 4 种触发场景；hook 层在 prompt 层漏触发时补写。与 31/32 的 prompt+hook 双层模式一致。**范围协调**：CHECK-1 (CHANGE.md "不新增 hook 模块" vs hook 层兜底)——本次仅新增 1 个 lib 文件（checkpoint-lib.sh ~60 行），无新增独立 hook 模块号（不占 33+ 号段），PreToolUse hook 内联调用 lib 函数，符合 CHANGE.md 范围约束 | 双层成本：prompt +3 行/PCSC 段，lib ~60 行 |
| D2 | **hook 层复用以 PreToolUse hook 为拦截点**，在 Write/Edit/Bash 工具调用后检测并写 checkpoint | 新增独立 Stop hook 模块 | PreToolUse 可在每次工具调用前/后检查上下文并写入；Stop hook 仅在会话结束时触发，无法覆盖"会话中间的关键操作后立即 checkpoint"。与 L3 front-loading 的 PreToolUse 策略一致 | PreToolUse hook 每次工具调用都触发（开销 < 5ms jq write），无性能问题 |
| D3 | **prompt 层 auto-checkpoint 指令嵌入 PCSC 段末尾**（每个阶段 prompt 1 处），作为强制自检项 | 在全 prompt 各处分散插入 | 集中管理、一致性高；PCSC 是每个阶段必执行的结构化自检，AI 无法跳过；若 15 个 prompt 全改，每处 ~3 行增量 | 依赖 AI 执行（弱模型可能跳过），由 hook 层兜底 |
| D4 | **文档更新策略**：以 FLOW-KIT-用户指南.md 为主稿，README.md + ecosystem-guide.md 从主稿提取摘要 | 独立编写三份文档 | 主稿详写确保完整性，摘要提取用 grep/sed 脚本化减少人工重复。与 docs-sync 策略一致（优先更新用户指南，README 和 ecosystem-guide 做一致性对齐） | 三份文档的侧重点不同（用户指南=操作手册，README=速览，ecosystem=架构清单），摘要提取不能简单复制粘贴 |
| D5 | **checkpoint 字段格式**：active_file=项目根相对路径，last_action≤200 字符，checkpoint_at=ISO8601 本地时区 | 绝对路径 / Unix timestamp | 相对路径跨环境可移植（同一 repo 不同 clone 路径不同）；ISO8601 人类可读；200 字符约束防止 AI 写冗长描述 | 相对路径依赖 CWD=项目根（flow-kit 已约定此假设） |
| D6 | **auto-checkpoint 频率控制**：同一 active_file + 同一操作类型 30s 内不重复写 | 每次操作都写 / 仅 transition 时写 | 防止编辑器 auto-save 触发频繁写入（jq write < 10ms 但 noise）；30s 窗口平衡了及时性和噪音 | 30s 窗口内如果 active_file 变了（切换到另一个文件编辑），新文件的操作仍会触发写入 |

---

## 2. 数据流 / 架构图

```
## auto-checkpoint 触发流程

┌─────────────────────────────────────────────────┐
│                 Prompt 层（AI 执行）               │
│                                                   │
│  编辑文件前 ─── Write/Edit tool call              │
│       │                                           │
│       ▼                                           │
│  PCSC 自检段末尾 ─── jq update .interrupt         │
│  (每个 phase prompt 1 处)                         │
│                                                   │
│  测试失败 ─── Bash non-zero exit                  │
│       │                                           │
│       ▼                                           │
│  toll-gate 暂停 ─── user selects option 2         │
│       │                                           │
│       ▼                                           │
│  phase transition ─── jq phase write              │
│                                                   │
└───────────────────────┬───────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│              Hook 层（PreToolUse 兜底）            │
│                                                   │
│  PreToolUse hook 检测：                           │
│  - Write/Edit → 取 file_path + description       │
│  - Bash exit≠0 → 取 command + "test failed"       │
│  - jq .goal.current_phase write → "phase trans." │
│                                                   │
│  ↓ 30s 去重检查（同 file+同 type 不重复）          │
│  ↓ jq atomic write .flow-active.interrupt         │
│  ↓ jq empty 校验 → 失败则保留旧值 + stderr warn   │
│                                                   │
└─────────────────────────────────────────────────┘

## 中断恢复流程（既有，本次不改）

  .flow-active.interrupt non-null
       │
       ▼
  /flow-go 继续 → GO.md 路由表命中 "继续"
       │
       ▼
  路由声明注入 interrupt 上下文
  (active_file + last_action + checkpoint_at)
       │
       ▼
  加载对应 phase prompt 的「入场恢复」段
```

---

## 3. 关键状态机

```
auto-checkpoint 状态（无状态机——每次触发是无状态写操作）

触发条件满足 → 去重检查(30s) → jq write → JSON 校验 → done
                                    ↓ fail
                              保留旧值 + stderr warn
```

---

## 4. ADR 索引

本次无不可逆架构决策（auto-checkpoint 为增量功能，不改变现有架构），不新增 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **弱模型跳过 prompt 层 auto-checkpoint 指令**：PCSC 段的自检项被弱模型忽略，不执行 jq write | 中断恢复时 `.flow-active.interrupt` 为旧值或空 | 中 | Hook 层 PreToolUse 兜底——检测到 Write/Edit/Bash(jq transition) 工具调用后自动写入，不依赖 AI 执行 |
| R2 | **checkpoint 频率过高导致噪音**：编辑器 auto-save 每 2s 触发 Write，频繁写 `.flow-active` | 用户查看状态时 interrupt 信息过时（30s 窗口内的旧操作），但不影响功能 | 低 | D6 的 30s 去重窗口；同一文件+同类型操作不重复写；不同文件切换时仍触发（合理） |
| R3 | **三份文档后续漂移**：本次一次性对齐后，后续 change 归档时可能忘记同步三份文档 | 用户在不同文档中看到矛盾信息 | 中 | docs-sync 已锁决策（2026-06-22）要求每次重大 change 后同步；本次在用户指南中显式标注"最后同步日期"供对照 |
| R4 | **checkpoint 写入失败静默丢弃**：磁盘满/权限变更导致 jq write 失败 | 用户误以为有 checkpoint 可用，中断后无法恢复 | 低 | D1 双层防护（prompt+hook）；hook 层写入失败时 stderr warn；JSON 合法性校验（`jq empty`）失败时保留旧值 |
| R5 | **PreToolUse hook 性能影响**：每次工具调用都触发 hook 检查 | 用户感知延迟（每次 Write/Edit/Bash 后 +5ms） | 极低 | jq write 操作 < 10ms；30s 去重窗口进一步减少写入频率；仅检测不写入时 < 1ms |
| R6 | **prompt 层 jq write 执行但静默失败**：AI 执行了 jq 命令但输出被截断或 pipefail 未生效 | 用户看到 checkpoint 写入成功，实际 `.flow-active.interrupt` 是旧值或损坏 | 低 | hook 层兜底（PreToolUse hook 独立写入，不依赖 prompt 层执行结果）；JSON 合法性校验（`jq empty`）在 hook 层强制执行 |

---

## 6. 不在范围

- checkpoint 历史记录（保留最近 N 次）→ v2
- checkpoint 自动摘要（从 transcript 提取描述）→ v2
- hook 层新模块的测试覆盖（本次 hook 改动小，测试留待 sweep-fix 后续）
- CONTEXT.md 完整 evolve（仅追加了 auto-checkpoint 术语，完整 evolve 由后续 A-evolve 处理）

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用 · 软约束）

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `~/.claude/flow-kit/hooks/stop/lib/checkpoint-lib.sh`（新增） | auto-checkpoint 写入 + 去重 + 校验的共享函数 | 任何需要自动保存中断上下文的场景 | PreToolUse hook + Stop hook 均可调用；未来若扩展 checkpoint 历史功能可在此基础上加 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| auto-checkpoint 双层防护 | prompt 指令 + PreToolUse hook 兜底 | 所有 flow-kit 阶段 prompt 的 PCSC 段 + PreToolUse hook | 低——拆除 hook 模块 + revert prompt 改动即可 |
| checkpoint 去重窗口 | 30s，同 file+同 type | PreToolUse hook | 低——改常量即可 |

### 9.3 新增 / 修改的跨模块契约

```
- .flow-active.interrupt 字段格式契约：active_file=相对路径, last_action≤200chars, checkpoint_at=ISO8601
- PreToolUse hook checkpoint-lib.sh 函数签名：checkpoint_write(file, action, [failing_check])
- /flow checkpoint 命令兼容：手动调用和自动调用共用同一 jq 写入路径
```

### 9.4 新增 / 升级的依赖

无（仅用已有 jq + Bash）。

### 9.5 禁动清单变化

```
- 新增禁动：checkpoint-lib.sh 不允许绕过直接 jq write .flow-active.interrupt（必须通过 checkpoint_write() 函数以保原子性+校验）
```
