# CONTEXT — 项目共享上下文

> 本文件**跨 change 长期累积**。每个 change 在 REQUIREMENT 阶段会向这里追加术语和决策。
> 目标：为 AI 提供项目级的「域语言 + 默认偏好」，省去重复解释。

---

## 源文档

> 步骤 0 既有文档探测结果。

- **探测命中**：无（分支 C — 未发现任何 AI 上下文文档或项目级文档）
- **用户选择**：选项 1 — 纯从代码扫描生成 CONTEXT.md
- **决策**：生成 `.specs/CONTEXT.md`
- **引用源**：无

---

## 项目概要

flow-kit 分发包仓库。将 flow-kit 完整生态（核心引擎 + 15 个阶段 prompts + 13 个 templates + 7 个 reference + flow-* skills + Stop Hook 系统 + SessionStart hooks + brooks-lint 插件）打包为可迁移的 `flow-kit-bundle.tar.gz`，供目标环境通过 `install.sh` 一键安装。

**目标用户**：需要在多台机器 / 项目间部署 flow-kit 开发工作流的工程师。

**核心产物**：
- `flow-kit-bundle.tar.gz` — 完整分发包（`package-flow-kit.sh` 生成）
- `flow-kit-ecosystem-guide.md` — 生态组件清单与架构文档
- `package-flow-kit.sh` — 一站式打包脚本（含安装器生成）

## 技术栈（团队级默认 / 已锁定）

> 这里写**全项目共用**的栈。每次 CHANGE 的 `DESIGN.md ## 0` 会读此处作为默认；如果某次 CHANGE 用了不同的栈（例如临时加个 Python 服务），那次 DESIGN.md ## 0 会显式覆盖。

- **语言/运行时**: Bash（`package-flow-kit.sh:1` — `#!/bin/bash`，`set -euo pipefail`）
- **前端框架**: 无（非 Web 项目）
- **后端框架**: 无
- **数据库**: 无
- **测试**: 未发现测试框架
- **构建/部署**: 纯 Shell 脚本打包（tar + gzip），无 CI/CD 检测到
- **栈卡片编号**: 不适用（非标准技术栈项目）

## 域语言（术语表）

| 术语 | 定义 |
|---|---|
| flow-kit | Claude Code 的开发工作流引擎，管理 0-change → 7-integration 全阶段 |
| Stop Hook | Claude Code Stop 事件触发的钩子链（11 模块），在每次会话结束时自动执行 |
| SessionStart Hook | 会话启动时触发的钩子（resume + report-reminder） |
| brooks-lint | 代码审查插件，基于 12 本经典工程书籍，提供 review/audit/debt/test/health/sweep |
| intel-scan | flow-kit 入场扫描命令，首次使用 flow-kit 时自动生成 CONTEXT.md |
| CHANGE | flow-kit 中的一次变更单元，有唯一 change-id，走 0→1→2→3→4→5→6→7 阶段 |
| .specs/ | 项目级规格文件目录（CONTEXT.md / STATE.md / 各 CHANGE 子目录） |
| gateflow | SystemVerilog/RTL 开发助手插件（本环境已安装） |
| LESSONS.md | 项目级经验教训与技术债记录文件，M-health 巡检结果写入此处 |
| TECH-DEBT.md | 技术债专用清单，brooks-lint 扫描结果与人工标注的合并输出 |

> 加新术语时只在右列写定义，不解释来历。

## 已锁决策

- `[2026-06-05]` 入场扫描完成 — 该项目为 flow-kit 分发包仓库，非传统软件项目。无源代码、无框架、无数据库。来自 `I-intel-scan`
- `[2026-06-08]` Git 仓库初始化 — `init-git-repo` CHANGE。默认分支 `main`，提交格式 [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`/`fix:`/`docs:`/`chore:`)。来自 `init-git-repo`

## 默认偏好（AI 在缺省时按此决策）

- 命名风格：Shell 脚本遵循 `kebab-case` 命名（如 `package-flow-kit.sh`、`flow-kit-ecosystem-guide.md`）
- 错误处理：Bash 脚本使用 `set -euo pipefail`（`package-flow-kit.sh:3`）
- 状态管理：无（非前端/后端项目）
- 测试策略：未引入测试框架
- 提交格式：Conventional Commits — `feat:` / `fix:` / `docs:` / `chore:` / `refactor:`；禁止 force push 到 main

## 既有抽象索引（来自 I-intel-scan · 防 AI 重复实现 · B5 老项目护栏）

> intel-scan 自动 grep 出来的项目级抽象。每个 change 4-dev 1.4 步骤会查这里。

### HTTP 客户端

- **路径**：`未发现`
- **入口符号**：无
- **使用方式**：无

### 数据库访问

- **模式**：未发现
- **路径**：未发现
- **示例**：无

### 状态管理

- **库**：未发现
- **路径**：未发现
- **示例**：无

### 工具函数（utils / helpers）

| 工具类型 | 路径 | 入口符号 |
|---|---|---|
| 日期 | `未发现` | — |
| 字符串 | `未发现` | — |
| 校验 | `未发现` | — |
| 存储 | `未发现` | — |
| 错误 | `未发现` | — |

> 注：`package-flow-kit.sh` 内含内联辅助函数（`install_file()`、`check_command()` 等），但未抽取为独立工具库。

### 自定义 hooks（前端）

不适用（非前端项目）。

### 错误处理

- **前端**：不适用
- **后端**：不适用
- **Shell**：`set -euo pipefail`（`package-flow-kit.sh:3`）— 遇错即停，无自定义 error handler

### Schema / 迁移

- **工具**：未引入
- **路径**：未发现
- **建议**：不适用（非数据库项目）

### 命名约定

- 文件命名：`kebab-case`（`package-flow-kit.sh`、`flow-kit-ecosystem-guide.md`）
- 函数命名：`snake_case`（`install_file()`、`check_command()`、`install_flow_kit_core()` — 来自 `package-flow-kit.sh`）
- 组件命名：不适用
- 测试文件：未发现测试文件

### 禁动清单（AI 不许"顺手"碰）

> 这些是与新 change 通常无关、改坏会出事的高风险模块。每个 change 的 DESIGN 0.5.1 会复用这清单。

- `package-flow-kit.sh`（打包脚本核心逻辑，改动影响分发流程）
- `flow-kit-bundle.tar.gz`（已生成的分发包，`.gitignore` 排除，不应手动修改或 git add）
- `.gitignore`（手动维护；禁 AI "顺手重写"或增删排除规则）

**清理窗口专列**（来自 `M-health` 步骤 2.5 冗余巡检 · 下次清理窗口一起 remove）：

- _暂无_（尚未运行 health 巡检）

### 技术债（来自 M-health · 给 AI 在 2-design / 4-dev 时参考，别再加同类债）

> 只记 🟡 Scheduled 和 🟡 🔴 未处理项。🔴 Critical 已通过 health-fix CHANGE 处理中，不在此列。

_详见 `.specs/LESSONS.md`（2026-06-08 基线：1🔴 + 3🟡 + 1🟢）_

---

## 项目结构（当前）

```
/home/hellrabbit/unisoc/flow-kit/
├── .git/                             # Git 仓库（2026-06-08 初始化）
├── .gitignore                        # 排除规则（bundle / secrets / IDE / temp）
├── README.md                         # 仓库说明（用途 + 目录 + 规范）
├── .specs/                           # flow-kit 规格目录
│   ├── CONTEXT.md                    # 项目共享上下文
│   ├── STATE.md                      # 项目状态
│   ├── LESSONS.md                    # 技术债与经验教训（2026-06-08 基线）
│   └── init-git-repo/                # 当前活跃 change
│       ├── CHANGE.md
│       ├── REQUIREMENT.md
│       ├── DESIGN.md
│       └── TASK.md
├── flow-kit-bundle.tar.gz            # 分发包（253KB · .gitignore 排除）
├── flow-kit-ecosystem-guide.md       # 生态组件清单文档（8.7KB）
├── flow-kit-bundle/                  # 分发包源码
└── package-flow-kit.sh               # 打包 + 安装脚本（28KB）
```

---

## intel-scan 元数据

- **last_intel_scan**: `2026-06-05`
- **scanner**: `prompts/I-intel-scan.md`
- **下次重扫建议**: `项目结构有大变化时（如新增源代码模块 / 引入框架 / 建立 git 仓库）或 > 90 天`

---

> 此文件长度建议 ≤ 300 行（含 intel-scan 自动填的字段）；超出时把陈旧条目归档到 `.specs/archive/CONTEXT-history.md`。
