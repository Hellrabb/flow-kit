# CONTEXT — 项目共享上下文

> 本文件**跨 change 长期累积**。每个 change 在 REQUIREMENT 阶段会向这里追加术语和决策。
> 目标：为 AI 提供项目级的「域语言 + 默认偏好」，省去重复解释。

---

## 源文档

> 步骤 0 既有文档探测结果。

- **探测命中**：`.specs/CONTEXT.md`（已有，上次 intel-scan: 2026-06-05）、`CLAUDE.md`（仓库根）
- **用户选择**：选项 1 — 综合现有文档 + 增量更新
- **决策**：更新 `.specs/CONTEXT.md`（2026-06-17 增量，同步 health-fix 变更）
- **引用源**：`.specs/CONTEXT.md`（前版）、`.specs/health/2026-06-16-HEALTH.md`（健康报告）、`.specs/archive/2026-06-16-health-fix/`（刚归档的 change）

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
- **测试**: bats-core 1.13.0（`npx bats` · 72 tests in `test/`）
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
| user-scope install | flow-kit 核心引擎安装到 `~/.claude/flow-kit/`，所有项目通过 symlink 共享（而非每项目复制一份） |
| two-level lookup | skill 文件查找策略：先查项目级 `flow-kit/`（允许项目锁定版本），未找到则回退到 `~/.claude/flow-kit/` |
| project-priority fallback | 以项目级 `flow-kit/` 为优先的查找策略，项目有实体目录就用项目的，没有才查 user-scope |
| bats / bats-core | Bash 自动化测试框架（Bash Automated Testing System），每个 .bats 文件包含一组测试用例，兼容 TAP 格式输出 |
| health-fix | 2026-06-16 健康巡检的修复 change，一次性消除 2🔴 + 4🟡 + 2🟢 共 7 项技术债 |
| `/goal` (CC 原生) | Claude Code v2.1.139+ 内置 slash command，设定完成条件后 AI 自主跨 turn 迭代直到条件满足（用 Haiku evaluator 判断）。接口：`/goal <条件>` 设、`/goal` 查、`/goal clear` 清 |
| goal（flow-kit 字段） | `.flow-active` 新增 `goal` 字段，存储当前 session 的完成条件 + 元数据（condition / active_since / turns / status），跨 compaction/恢复持久化 |
| goal auto-extraction | 4-dev 入场时自动从 REQUIREMENT.md 的 Given/When/Then AC 提取 goal 建议文本，用户可确认或修改 |
| goal fallback | 当 CC < v2.1.139（无原生 /goal）时，flow-kit 使用内置 prompt 驱动的迭代循环：每 turn 结束后检查条件是否满足，满足则停止 |
| pipeline goal | goal 的跨阶段模式（`scope: "pipeline"`）：覆盖执行链 `start_phase→...→7`，默认从 4 起步（4→5→6→7），可通过 `--from <n>` 从任意阶段（0-7）启动。AI 在每个阶段完成后自动推进到下一阶段，在 toll-gate 和门禁失败点暂停等待人工确认 |
| toll-gate | pipeline goal 的阶段过渡暂停点（4→5 / 5→6 / 6→7），AI 完成当前阶段后暂停，输出"是否进入下一阶段？"等待用户确认，不自动继续 |
| gate condition（门禁条件）| pipeline goal 中不可自动跳过的硬性检查（如 4-dev 所有 verify 通过、6-review 无 🔴 Critical）。门禁失败时 pipeline 暂停并等待用户决定（重试/跳过/放弃） |
| phase transition（阶段自动推进）| pipeline goal 中当前阶段完成后自动加载下一阶段 prompt 并更新 `.flow-active.goal.current_phase` 的过程，仅在 toll-gate 确认后执行 |
| start_phase（pipeline 起始阶段）| `.flow-active.goal.start_phase` 字段，指定 pipeline goal 从哪个阶段开始执行（0-7，默认 "4"）。gates 和 current_phase 初始值均由此字段派生 |
| `--from <n>` | `/flow goal --pipeline` 的可选参数，指定 pipeline 起始阶段。不传时默认 "4"（向后兼容）|
| cross-phase condition（跨阶段复合条件）| pipeline goal 的 condition 语法扩展，支持 `AND` 连接多个阶段子条件（如 `"CHANGE.md confirmed AND all tests pass"`），evaluator 在各阶段完成后分步评估 |

> 加新术语时只在右列写定义，不解释来历。

## 已锁决策

- `[2026-06-05]` 入场扫描完成 — 该项目为 flow-kit 分发包仓库，非传统软件项目。无源代码、无框架、无数据库。来自 `I-intel-scan`
- `[2026-06-08]` Git 仓库初始化 — `init-git-repo` CHANGE。默认分支 `main`，提交格式 [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`/`fix:`/`docs:`/`chore:`)。来自 `init-git-repo`
- `[2026-06-09]` user-scope 安装采用 symlink 方案（`~/.claude/flow-kit/` + 项目 `flow-kit → symlink`），而非改动 86 处 skill 内部路径引用。项目级优先（project-priority fallback）——已有物理 `flow-kit/` 目录的项目不受影响。来自 `user-scope-install`
- `[2026-06-16]` hooks 唯一源确定为 `flow-kit-bundle/hooks/`，`.claude/hooks/` 为 install.sh 安装的运行时副本（非维护源）。来自 `health-fix`
- `[2026-06-18]` goal 集成策略 — 优先委托 CC 原生 `/goal`（v2.1.139+），不可用时走内置 prompt 回退；goal 从 REQUIREMENT.md AC 自动提取建议，用户可修改。来自 `integrate-goal-command`
- `[2026-06-18]` pipeline goal 边界决策 — 仅覆盖执行链 4→5→6→7（不碰 0-3 人工决策密集阶段）；采用 toll-gate 暂停模型（非全自动）；终止条件为「顶层目标 + 关键阶段门禁」混合模型。向后兼容现有单阶段 goal（`scope: "phase"` 或无 scope 字段）。来自 `pipeline-goal`
- `[2026-06-20]` pipeline goal 起始阶段可配置 — 新增 `--from <n>` 参数（0-7，默认 4），`start_phase` 字段，动态 gates 生成，0-3 阶段 pipeline toll-gate，跨阶段 AND condition 语法。向后兼容：旧 pipeline goal 无 `start_phase` 默认 "4"。来自 `goal-pipeline-phase0`

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

- _暂无_（TD-001 已通过 health-fix 修复）

### 技术债（来自 M-health · 给 AI 在 2-design / 4-dev 时参考，别再加同类债）

> 只记 🟡 Scheduled 和 🟡 🔴 未处理项。🔴 Critical 已通过 health-fix CHANGE 处理中，不在此列。

| # | 严重度 | 位置 | 问题 | 建议 | 来源 |
|---|---|---|---|---|---|
| TD-002 | ✅ | `flow-kit-bundle/hooks/stop/` + `lib/`（3410 行 bash）| hooks 系统无测试覆盖。test_install.bats 只测 install.sh CLI 参数（11 tests），未覆盖 install_hooks.sh / flow-kit-artifacts.sh 等核心 hook 逻辑（上次 T5 的残留尾巴）| 为 `install_hooks.sh` / `flow-kit-artifacts.sh` 加 bats smoke test | `M-health 2026-06-20` |
| TD-003 | ✅ | `flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md` 入场 jq | `--from 0` pipeline 扩展时，4-dev.md + GO.md 已加 `start_phase` 读取，但这三个 prompt 仍是 `current_phase // "4"`（漏改）。实际影响低（current_phase 字段在 transition 时已正确更新，fallback 不触发），但一致性应补齐 | 统一三个 prompt 入场 jq 为 `current_phase // .start_phase // "4"` | `M-health 2026-06-20`（goal-pipeline-phase0 遗留）|
| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 共享函数 < 3 阈值，`lib/utils.sh` 保持推迟 | 等新增 ≥ 2 个共享辅助函数时再建 | `init-git-repo` T03 · 保持 deferred |

---

## 项目结构（当前）

```
~/unisoc/flow-kit/
├── .git/                             # Git 仓库（2026-06-08 初始化）
├── .gitignore                        # 排除规则（bundle / secrets / IDE / temp）
├── .claude/                          # Claude Code 项目配置
│   ├── stop-hook.json                # Stop hook 模块开关
│   └── settings.local.json           # Stop hook 接线
├── README.md                         # 仓库说明
├── .specs/                           # flow-kit 规格目录
│   ├── CONTEXT.md                    # 项目共享上下文（本文件）
│   ├── STATE.md                      # 项目状态
│   ├── LESSONS.md                    # 技术债与经验教训
│   ├── CHANGELOG.md                  # change 历史
│   ├── health/                       # M-health 巡检报告
│   └── archive/                      # 已归档 change
├── test/                             # bats-core 测试目录（28 tests）
│   ├── test_common.bats              # common.sh 6 函数测试（17 tests）
│   └── test_install.bats             # install.sh 参数解析测试（11 tests）
├── flow-kit-bundle/                  # 分发包源码（唯一维护源）
│   ├── install.sh                    # 安装主脚本（202行，调度 lib/）
│   ├── lib/                          # install.sh 拆分模块
│   │   ├── install_core.sh           # flow-kit 核心安装
│   │   ├── install_skills.sh         # skills 安装
│   │   ├── install_brooks.sh         # brooks-lint 安装 + 动态版本号
│   │   └── install_hooks.sh          # hooks 安装 + specs 模板
│   ├── hooks/                        # Stop/SessionStart hooks（唯一源）
│   ├── flow-kit/                     # flow-kit 核心引擎（vendor 副本）
│   ├── skills/                       # flow-* skill 包装器
│   └── brooks-lint/                  # brooks-lint 插件（vendor 副本）
├── flow-kit-bundle.tar.gz            # 分发包（.gitignore 排除）
├── FLOW-KIT-用户指南.md              # 生态组件清单
└── package-flow-kit.sh               # 打包脚本（3 级 fallback）
```

---

## intel-scan 元数据

- **last_intel_scan**: `2026-06-05`
- **scanner**: `prompts/I-intel-scan.md`
- **下次重扫建议**: `项目结构有大变化时（如新增源代码模块 / 引入框架 / 建立 git 仓库）或 > 90 天`

---

> 此文件长度建议 ≤ 300 行（含 intel-scan 自动填的字段）；超出时把陈旧条目归档到 `.specs/archive/CONTEXT-history.md`。
