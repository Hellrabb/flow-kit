# flow-kit 完整生态 · 组件清单

> 打包文件: `flow-kit-full-YYYYMMDD-HHMMSS.tar.gz` (~243K, 109 文件)
> 打包脚本: `package-flow-kit.sh`

---

## 层 1：flow-kit 核心引擎（`~/.claude/flow-kit/`）

来自 `https://github.com/rihebty/flow-kit`，是整套系统的"大脑"。

### 入口文件

| 文件 | 行数 | 作用 |
|---|---|---|
| `GO.md` | ~600 | 统一路由器——解析意图 → 分配到阶段 → 管理 token 预算 |
| `RULES.md` | — | 全局行为约束（精简版） |
| `SYSTEM.md` | — | 全局行为约束（完整版） |
| `METHODOLOGY.md` | — | 方法论说明 |

### 阶段 Prompts（15 个）— 每个阶段的具体执行指令

| 文件 | 阶段 | 说明 |
|---|---|---|
| `0-change.md` | 变更提案 | 自动生成 change-id，反问澄清需求范围 |
| `1-requirement.md` | 需求 | Given/When/Then + v1/v2/out 范围 |
| `2-design.md` | 技术设计 | ADR + 技术栈选型 + 风险 + 既有架构对齐 |
| `2a-ui-design.md` | UI 设计 | OKLCH tokens + 字体/间距/动效 + 反 AI-slop |
| `3-task.md` | 任务拆解 | XML 任务清单 + 波次 + verify + done |
| `4-dev.md` | 开发执行 | TDD + 既有抽象检查 + 破坏性变更门槛 + 中断恢复 |
| `5-test.md` | 测试 | 测试矩阵 + UAT + 覆盖率回顾 |
| `6-review.md` | 审查 | 双轮审查（spec 合规 + 代码质量 + 跨模型分歧） |
| `7-integration.md` | 集成归档 | 合并、发布检查、LESSONS.md 沉淀 |
| `I-intel-scan.md` | 入场扫描 | 生成 CONTEXT.md（术语 + 抽象索引 + 禁动清单） |
| `A-architect.md` | 架构建立 | ARCHITECTURE.md + ADR + 模块契约 |
| `A-evolve.md` | 架构演进 | 从归档 DESIGN §9 提取共识 → patch CONTEXT/ARCHITECTURE |
| `L-restyle.md` | 视觉重构 | 换肤不改功能 |
| `M-health.md` | 健康检查 | 技术债盘点 + 冗余扫描 + 改进路线图 |

### 核心机制

| 机制 | 涉及文件 | 说明 |
|------|---------|------|
| **Pipeline Goal** | `GO.md`、`4-dev.md`、`.flow-active` | 跨阶段自动推进（0→1→2→2a→3→4→5→6→7），支持 `--from <n>` 从任意阶段起步（默认 4）。Toll-gate 暂停 + auto_advance 自动推进两种模式 |
| **PCSC/PG 双层防护** | 各阶段 prompt、`GO.md` | Phase Completion Self-Check（prompt 内产物自检）+ Phase Completion Gate（GO.md 路由层磁盘存在性检查），防止产物遗漏和阶段跳过 |
| **Pipeline Rollback（智能回退）** | `GO.md`、`.flow-active` | 阶段失败时自动回退到上一个通过门禁的阶段，支持失败分类表 + 动态下界（不低于 start_phase）。用户可选择重试/跳过/放弃 |

### Templates（13 个）— 各阶段产物模板

`ARCHITECTURE` `CHANGE` `CONTEXT` `DESIGN` `LESSONS` `PROGRESS` `REQUIREMENT` `REVIEW` `STATE` `SUMMARY` `TASK` `TEST` `UI-DESIGN`

### Reference（7 个）— 按需查阅，禁止整读

| 文件 | 内容 |
|---|---|
| `tech-stacks.md` | 技术栈适用矩阵 + 卡片 |
| `test-pyramid.md` | 测试金字塔 + 各轮详情 |
| `ui-aesthetics.md` | 5 维度美学体系 + AI 模板 |
| `ui-anti-patterns.md` | 常见 AI UI 反模式（75 行，可整读） |
| `frontend-engineer-rules.md` | 前端工程师规则 |
| `runtime-adapters/forge.md` | Forge runtime 适配器说明 |
| `regression-demos/brooks-lint-paths.md` | brooks-lint 路径示例 |

---

## 层 2：flow-* Skills（`~/.claude/skills/flow-*/`）

16 个 Claude Code skill 包装器，每个是一个 `SKILL.md`，作为 `/flow-xxx` 命令的入口。实际逻辑委托给层 1 的 prompts。

| Skill | 对应命令 |
|---|---|
| `flow` | `/flow` — 状态管理（start/stop/phase/checkpoint） |
| `flow-go` | `/flow-go` — 统一入口路由器 |
| `flow-change` | 阶段 0 快捷入口 |
| `flow-requirement` | 阶段 1 快捷入口 |
| `flow-design` | 阶段 2 快捷入口 |
| `flow-ui-design` | 阶段 2a 快捷入口 |
| `flow-task` | 阶段 3 快捷入口 |
| `flow-dev` | 阶段 4 快捷入口 |
| `flow-test` | 阶段 5 快捷入口 |
| `flow-review` | 阶段 6 快捷入口 |
| `flow-integration` | 阶段 7 快捷入口 |
| `flow-architect` | A-architect 快捷入口 |
| `flow-evolve` | A-evolve 快捷入口 |
| `flow-health` | M-health 快捷入口 |
| `flow-intel` | I-intel-scan 快捷入口 |
| `flow-restyle` | L-restyle 快捷入口 |

---

## 层 3：Stop Hook 系统（`<project>/.claude/hooks/stop/`）

Claude Code 的 **Stop 事件钩子链**——每次会话结束自动触发，11 个模块按序执行：

| 序号 | 模块 | 检查项 |
|---|---|---|
| `00-gate` | 入口门禁 | 子代理隔离、必须文件存在性、环境初始化 |
| `01-transcript-parse` | 转录解析 | 解析 JSONL 对话记录 → 结构化数据供下游使用 |
| `20-claude-md` | A: CLAUDE.md 管理 | 新命令检测、gotcha 捕获、文件追踪、过期检测 |
| `21-memory` | B: Memory 同步 | 新规约检测、规约违规、重复记忆检测 |
| `22-git` | C: Git 卫生 | 状态摘要、大文件、commit 建议、secret 检测 |
| `23-quality` | D: 代码质量 | 测试纪律、类型检查、构建验证、lint |
| `24-session` | E: 会话分析 | 工具统计、RTK 优化、子代理分析、时长、context-mode 趋势 |
| `25-project` | F: 项目级门禁 | 容器构建缓存、pnpm 供应链、迁移检测、hook 冲突、worktree 残留 |
| `26-workflow` | G: 工作流状态 | flow-kit 状态、产物验证、自动推进、stale 检测、diff 边界 |
| `30-ai-analyze` | AI 深度分析 | 每 N 次触发一次，用小模型分析转录 + 建议 CLAUDE.md 更新 |
| `99-report` | 报告汇总 | 聚合所有模块输出 → 终端摘要 + `stop-hook-report.md` 文件 |

### 库文件（`lib/`）

| 文件 | 作用 |
|---|---|
| `common.sh` | 共享函数库 |
| `flow-kit-artifacts.sh` | flow-kit 产物验证函数 |
| `transcript-parser.sh` | 转录解析库 |

---

## 层 4：SessionStart Hooks + 配置

| 文件 | 作用 |
|---|---|
| `session-start/flow-kit-resume.sh` | 启动时检测 `.flow-active`，显示恢复横幅提示用户继续 |
| `session-start/stop-report-reminder.sh` | 启动时检测 3 天内的 stop-hook 报告，提醒用户查看 |
| `config/settings.json` | Claude Code hook 绑定（Stop + SessionStart 事件 → 对应脚本） |
| `config/stop-hook.json` | Stop hook 模块开关 + AI 分析频率 + 阈值配置 |

---

## 层 5：brooks-lint 代码审查插件（`~/.claude/plugins/marketplaces/brooks-lint-marketplace/`）

来自 `https://github.com/hyhmrright/brooks-lint` v1.3.0，提供 6 个独立的代码审查 skill。

### 命令入口（`~/.claude/commands/brooks-*.md`）

| 命令 | 功能 |
|---|---|
| `/brooks-review` | PR 代码审查 |
| `/brooks-audit` | 架构审计 |
| `/brooks-debt` | 技术债评估 |
| `/brooks-test` | 测试质量审查 |
| `/brooks-health` | 代码库健康仪表盘 |
| `/brooks-sweep` | 全维度扫描 + 自动修复 |

### 插件结构

| 组件 | 路径 | 说明 |
|---|---|---|
| 命令入口 | `commands/brooks-*.md` | 6 个 Claude Code 命令入口 |
| 插件配置 | `.claude-plugin/plugin.json` | 插件元数据（名称、版本、作者） |
| SessionStart Hook | `hooks/session-start` | 注入轻量上下文 + 自动安装命令 |
| Hook 配置 | `hooks/hooks.json` | Hook 事件绑定 |
| AGENTS.md | 根目录 | 插件自身开发指引 |

### brooks-lint 与 flow-kit 的集成点

- flow-kit `4-dev` 阶段的 self-review 可优先调用 brooks-lint
- flow-kit `5-test` 阶段的测试质量审查可优先调用 brooks-lint
- flow-kit `6-review` 阶段的代码质量审查可优先调用 brooks-lint
- flow-kit `M-health` 阶段的巡检可优先调用 brooks-lint
- GO.md 的 budget 估算中「brooks-lint 已装」因子 +10%

### brooks-tools 离线工具包（`~/.claude/tools/brooks-lint/`）

brooks-lint 依赖 4 个 npm 工具（depcheck / jscpd / knip / ts-prune），统称 brooks-tools。由于 pnpm 虚拟存储的符号链接无法跨机迁移，`package-flow-kit.sh` Part G 采用 `npm pack` 逐工具打包为 `.tgz`，解压为扁平 node_modules 后离线安装到 `~/.claude/tools/brooks-lint/`。

| 组件 | 路径 | 说明 |
|------|------|------|
| 工具可执行文件 | `~/.claude/tools/brooks-lint/<tool>/node_modules/.bin/` | 扁平 node_modules，无需 pnpm |
| shim（工具适配层） | `~/.local/bin/depcheck` 等 | 薄 wrapper 映射到真实可执行文件 |
| 安装控制 | `install.sh --no-brooks-tools` | 跳过 brooks-tools 安装的 flag |

当前仅打包 linux-x64 二进制，多平台矩阵列为 v2。

---

## 整体架构关系

```
用户说 /flow-go "做X"
       │
       ▼
┌──────────────────────────────────────┐
│  flow-go SKILL.md (层2)              │
│  → 加载 GO.md (层1)                  │
│  → 路由到对应阶段 prompt (层1)        │
│  → 按需查 reference (层1)            │
│  → 按模板产出 SPEC (层1 templates)   │
│  → 按需调用 brooks-lint (层5)        │
└──────────────────────────────────────┘
       │
       ▼  会话结束
┌──────────────────────────────────────┐
│  Stop Hook 链 (层3)                  │
│  00→01→20→21→22→23→24→25→26→30→99  │
│  → 检查代码质量、git 卫生、内存同步    │
│  → 验证 flow-kit 产物完整性           │
│  → 生成 stop-hook-report.md          │
│  → 23-quality 可调用 brooks-lint     │
└──────────────────────────────────────┘
       │
       ▼  下次会话启动
┌──────────────────────────────────────┐
│  SessionStart Hooks (层4)            │
│  → 检测 .flow-active → 恢复横幅      │
│  → 检测 stop-hook-report → 提醒      │
│  → brooks-lint SessionStart 注入     │
└──────────────────────────────────────┘
```
