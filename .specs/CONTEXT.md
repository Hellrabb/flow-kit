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
| Phase Completion Self-Check (PCSC) | 阶段完成自检 — 每个阶段 prompt 中 Pipeline Toll-Gate 之前的强制产物自检段。列出本阶段必产文件清单，逐项标记 ✅/❌。任一 ❌ → 禁止进入 toll-gate，要求先补齐。auto_advance=true 时仍执行，全 ✅ 自动 transition，有 ❌ 暂停告警 |
| Phase Completion Gate (PCG) | GO.md 路由层的独立产物检查门禁。AI 请求进入 phase N+1 时，GO.md 检查 phase N 的必须产物是否存在于磁盘。缺失 → 拒绝路由，输出缺失清单。独立于 prompt 指令，AI 无法绕过 |
| artifact verification | 产物存在性验证 — 在进入 toll-gate 或 transition 之前，检查对应阶段必须产出的文件是否已写入磁盘（如 `test -f .specs/<id>/TEST.md`）。双层防护（PCSC + PCG）的核心机制 |
| brooks-tools | brooks-lint 依赖的 4 个外部 npm 工具的统称：depcheck（未使用依赖检测）、jscpd（代码重复检测）、knip（未使用文件/导出检测）、ts-prune（未使用 TS 导出检测）。以扁平 node_modules 自包含目录形式打包，离线安装到 `~/.claude/tools/brooks-lint/` |
| npm pack | npm 原生命令，将包及其依赖打包为 .tgz。本项目中用于从 pnpm 全局安装中提取工具的完整依赖树，绕过 pnpm 虚拟存储的符号链接复杂性 |
| shim（工具适配层）| 薄 wrapper 脚本，将 `~/.claude/tools/brooks-lint/` 下的真实可执行文件映射到 PATH 可见位置（`~/.local/bin/`），使 depcheck/jscpd/knip/ts-prune 可直接调用 |
| 扁平 node_modules | 与 pnpm 虚拟存储（content-addressable store + symlink）相对的传统 npm 安装结构：所有依赖摊平在 node_modules/ 顶层。brooks-tools 打包时采用此结构以确保离线环境可独立运行，不依赖 pnpm |
| security-privacy-audit | 安全与隐私泄露全面审查——push 到公开仓库前的最后一道防线。覆盖六大风险维度：硬编码凭证、内部路径/IP 泄露、个人信息暴露、命令注入/路径遍历、第三方端点、Git 历史残留 |
| SECURITY-REPORT.md | 安全审查报告产物，汇总六维度的扫描结果，每项标记 `✅ CLEAN` 或 `🔴 FINDING`（含文件路径、行号、风险等级、修复建议）|
| 六大风险维度 | 安全审查的六个检查方向：🔑 硬编码凭证（密钥/Token/密码）、🏠 内部路径/IP（个人目录/内网地址）、📧 个人信息（邮箱/手机号）、🐚 注入风险（eval/exec/路径遍历）、🌐 第三方端点（内部 API URL）、📜 Git 历史（已删除文件的残留敏感信息）|
| 公开仓库安全标准 | Push 到 GitHub public 前的零容忍策略：任一 🔴 Critical 发现项必须在 push 前修复并重新扫描验证；所有匹配项必须有人工确认标记（`✅ CLEAN` / `✅ FALSE_POSITIVE` / `🔴 FINDING`）|
| 弱模型（weak model） | 能遵循结构化指令但易幻觉、易跳步骤的 LLM（如 minimax-m2.7 / qwen3.6-35b-a3b / deepseek-v4-pro）。与强模型相对 |
| 强模型（strong model） | 能稳定自觉遵守 RULES/prompt、低幻觉的 LLM（如 Claude 级）。flow-kit 原始设计的假设对象 |
| protect the weakest | 弱模型鲁棒性设计哲学：规则/prompt 默认按"最弱模型能扛住"写，所有人开局受保护；降级（opt-out）才需显式声明。依据是风险不对称——弱模型缺约束崩溃 ≫ 强模型多约束啰嗦 |
| 分层防御 L1/L2/L3/L4 | weak-model-robustness 的四层防幻觉/防跳步设计：L1 规则硬护栏（RULES/SYSTEM）/ L2 prompt 结构化强化（主轴）/ L3 证据链机制 / L4 伪双轨（model_tier opt-out，v2） |
| 证据链（evidence chain） | L3 机制：模型提到任何文件/API/字段前必须先 `grep`/`read` 验证其存在，把"靠模型自觉不幻觉"改成"靠工具验证兜底" |
| 自检 gate（self-check gate） | L2 机制：每个阶段 prompt 内嵌的强制产物/行为自检段，模板填空式，模型无法跳过（不填空就产不出） |
| regression-demo | 弱模型鲁棒性的验收反例载体（`flow-kit-bundle/flow-kit/regression-demos/`）：每个失败模式一个 demo，含诱导场景 + `check.sh` 验证护栏是否生效 |
| 归档双向校验（archive bidirectional check） | L-013 修复：7-integration 归档完成后的二合一自动操作——① 清理已归档 change 的 `.specs/<id>/` 工作目录；② 扫描 `.specs/` 下其他已完成但未归档的 change 并提示 |
| 打包完整性校验（package integrity validation） | L-012 修复：`package-flow-kit.sh --validate` 模式，比对 `flow-kit-bundle/` 实际目录树与 Part A~F 的 cp/rsync 指令覆盖范围，逐项对账，漏配报错 |
| 1.8 恢复验证（1.8 recovery verification） | L-010 修复：4-dev 中 1.8 破坏性变更协议触发后自动执行 `npx bats test/`，0 fail 才放行，失败则阻断流程 |
| lessons-cleanup | 2026-06-29 change：一次性消除 LESSONS.md L-010/L-012/L-013 三条活跃技术债，加自动化兜底防复发 |

| pipeline-gates.md | flow-kit/reference/ 下的 toll-gate 协议共享片段文件，prompt 和 skill 通过 @see 引用此处作为单一源 |
| check-gate-sync.sh | flow-kit/reference/ 下的协议漂移检测脚本，diff prompt 和 skill 的 toll-gate 段，不一致时报错 |
| make check | Makefile target，一键跑 test + lint + 打包校验 + test 双源 diff，pre-push hook 自动调用 |
| shellcheck | Bash 静态分析工具，make lint 集成，当前仅 error 级别（-e SC1091）|
| quality-baseline | 2026-06-29 change：质量基础设施补强 E+F+G+H+I |
| 交互式 UI（interactive UI） | Claude Code 内置的交互工具集，包括 `AskUserQuestion`（多选/单选对话框）、`EnterPlanMode`（计划模式）、Permission Prompt（权限弹窗）。flow-kit 大量依赖这些工具作为决策 gate |
| 交互 gate（interaction gate） | flow-kit prompt 中要求模型触发交互式 UI 的决策点——如"反问用户"→ 必须调 `AskUserQuestion`、"进入计划模式"→ 必须调 `EnterPlanMode`。弱模型常跳过这些 gate 直接幻觉用户回复 |
| 交互式 UI 触发护栏（interactive UI guard） | 确保弱模型实际调用交互式 UI 工具（而非幻觉已调用）的 prompt 结构化加固。三层：① 结构化自检句（"如果你还没调用 X，现在停下来调用"）② 工具调用模板（写出参数骨架）③ L3 证据链（"确认：你上一条消息是否包含工具调用？"）。每点 ≥2 层 |
| interactive-ui-guard.md | flow-kit/reference/ 下新增的共享护栏模板片段，供各 prompt 通过 `@see` 引用，统一交互式 UI 触发加固格式 |
| weak-model-interactive-ui | 2026-06-29 change：全链路扫描 + 加固 flow-kit 所有交互 gate，确保弱模型实际触发 `AskUserQuestion` / `EnterPlanMode` |
| 27-interactive-ui-check.sh | Stop hook 第 27 号模块：每次会话停止时 grep transcript 检测弱模型是否跳过了交互 gate（prompt 含"反问用户"等关键词但回复中无 AskUserQuestion/EnterPlanMode 工具调用），跳过则写入矫正文件 `.flow-active.interactive-ui-fix` |
| 矫正文件（correction file） | `.flow-active.interactive-ui-fix`（JSON，不入库）：Stop hook 检测到交互 gate 跳过时写入，含 gate_type / required_tool / retry_count。SessionStart flow-kit-resume.sh 检测到后注入矫正 banner 强制模型补调工具，retry_count ≥ 2 时停止矫正提示人工介入 |
| weak-model-compliance | Stop hook 第 28 号模块：每次会话停止时对模型回复做三层事后合规验证——L1 规则合规（禁动清单+通用规则）、L2 自检完整性（自检表无空白/跳过）、L3 证据链真实性（引用路径在工具调用历史中出现过）。检测到违规 → 写入统一矫正文件 `.flow-active.correction` |
| `.flow-active.correction` | 统一矫正文件（JSON，不入库）：用 `type` 字段区分违规类型（`compliance` / `interactive-ui`），含 `layer`（L1/L2/L3）、`violations` 数组、`written_at` 时间戳。v1 仅 `28-weak-model-compliance.sh` 写入 `compliance` 类型；`27-interactive-ui-check.sh` 暂保持旧文件，v2 迁移。SessionStart 同时处理两个矫正文件 |
| L1 hook 层规则合规检测 | Stop hook 对 transcript 中模型回复做规则合规扫描——grep 触碰 CONTEXT.md 禁动清单路径 + 违反 RULES.md/SYSTEM.md 通用禁动规则（如"禁止编造文件路径"）。属 28 号模块 L1 层 |
| L3 hook 层证据链检测 | Stop hook 验证模型回复中引用的文件路径/API 名/字段名是否在 transcript 工具调用历史中出现过——未出现则判定为幻觉引用。属 28 号模块 L3 层，是对 prompt 层 L3 护栏（grep-before-cite）的系统级兜底 |
| HOOK_MODULE_NAMES | `common.sh` 中定义的共享 hook 模块名数组（`declare -a HOOK_MODULE_NAMES=(00-gate 01-transcript-parse ... 99-report)`）。`install_hooks.sh` 和 `package-flow-kit.sh` 均引用此数组，消除两处重复维护 |
| PHASE_ARTIFACTS | `flow-kit-artifacts.sh` 中定义的关联数组（`declare -A`），将 phase 映射到其必须产物列表。`fk_artifact_check()` 据此查表驱动，替代硬编码分支判断 |
| correction-file.sh | 新建的通用 JSON correction file 管理 lib（`hooks/stop/lib/correction-file.sh`），提供 `correction_file_write()` / `correction_file_read()` / `correction_file_clear()` / `correction_file_exists()` 四个函数。`interactive-ui-check.sh` 和 `weak-model-compliance.sh` 均调用此 lib，消除结构重复 |
| sweep-fix-2026-07 | 2026-07 全量健康扫描（68/100）的修复 change，消除 1🔴 + 3🟡 + 2🟢 共 6 项技术债 |
| gate-config preset | `/flow goal --gate-config` 的预设名快捷方式（`full`/`code-only`/`design`/`requirement`/`review`/`plan`/`design-review`/`requirement-review`），替代手写完整 JSON |
| gate-config shorthand | gate-config 的数字简写方式（`1`/`2`/`6`/`1,2`/`1,6`/`2,6`/`1,2,6`），数字自动映射到对应阶段 key（1→"1-requirement"，2→"2-design"，6→"6-review"） |
| ANTHROPIC_DEFAULT_HAIKU_MODEL | 环境变量，指向 session 配置的 haiku-tier 模型 ID（如 `deepseek-v4-flash`）。L3 独立 review 和 AI 分析 hook 从此变量读取模型名，不再硬编码 |
| L3 API 直连 | 29/30 号 hook 脚本的 API 调用策略：优先直连 `$ANTHROPIC_BASE_URL`（用 `$ANTHROPIC_AUTH_TOKEN` 鉴权），onecli proxy 降级为可选（有则用，无则直连不报错） |
| env-var-first config | hook 脚本配置读取优先级：环境变量 > stop-hook.json 字段 > 硬编码默认值。当前仅应用于模型名和 API endpoint 配置 |
| gate-integrity | 本次 change：加固 toll-gate 不可绕过性 + 扩展 L2 独立审查到 3/5/7。Q1 hook 层强制 .done 真实性 + transition 前置查 gate；Q2 给 3/5/7 加 L2 |
| .done 真实性校验（.done authenticity validation）| 区别于 PCG 的"存在性"检查：校验 `.independent-review-<phase>.done` / 阶段 `.done` 是由真实 review 子进程产出，而非主 agent touch/echo 伪造。含三层：空文件拒、假内容识别、跳过子进程拦截 |
| transition 前置 gate 查（pre-transition gate check）| pipeline phase N→N+1 transition 执行前，hook 强制查 `goal.gates["N→N+1"]` 是否 passed（passed 依赖合法 .done），未 passed 拒绝推进 |
| 三种威胁模型（gate bypass）| gate-integrity 防的三种 agent 绕过方式：① 空 .done（touch 空文件）② 假内容 .done（写非真实证据）③ 跳过子进程（不派 review 直接 transition）。v1 三种全防 |
| gate-config 3-5-7 扩展 | gate-config 预设/数字映射从 {1,2,6} 扩展到 {1,2,3,5,6,7}。3→`3-task`、5→`5-test`、7→`7-integration`。默认 off：`full` 预设仍只含 1/2/6，用户显式开 3/5/7 |
| independent-review-gap | 本次 change：补齐 gate-integrity 未完成的 prompt 层 + PRESET_MAP 层 + L2 checklist 层。修复四层差异使 `all` 预设端到端可用 |
| 独立审查四层架构 | L2/L3 独立审查由四层组成：① PRESET_MAP（定义哪些阶段可开）② Prompt 模板（告知主 agent 如何调度 L2）③ Hook 层（L3 自动执行 + done 真实性校验）④ L2-blind-review.md（固化盲审指令含各阶段 checklist）。四层全对齐 = 端到端可用；任一层缺失 = pipeline 死锁 |

## 已锁决策

- `[2026-06-05]` 入场扫描完成 — 该项目为 flow-kit 分发包仓库，非传统软件项目。无源代码、无框架、无数据库。来自 `I-intel-scan`
- `[2026-06-08]` Git 仓库初始化 — `init-git-repo` CHANGE。默认分支 `main`，提交格式 [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`/`fix:`/`docs:`/`chore:`)。来自 `init-git-repo`
- `[2026-06-09]` user-scope 安装采用 symlink 方案（`~/.claude/flow-kit/` + 项目 `flow-kit → symlink`），而非改动 86 处 skill 内部路径引用。项目级优先（project-priority fallback）——已有物理 `flow-kit/` 目录的项目不受影响。来自 `user-scope-install`
- `[2026-06-16]` hooks 唯一源确定为 `flow-kit-bundle/hooks/`，`.claude/hooks/` 为 install.sh 安装的运行时副本（非维护源）。来自 `health-fix`
- `[2026-06-18]` goal 集成策略 — 优先委托 CC 原生 `/goal`（v2.1.139+），不可用时走内置 prompt 回退；goal 从 REQUIREMENT.md AC 自动提取建议，用户可修改。来自 `integrate-goal-command`
- `[2026-06-18]` pipeline goal 边界决策 — 初始仅覆盖执行链 4→5→6→7（不碰 0-3 人工决策密集阶段）；采用 toll-gate 暂停模型（非全自动）；终止条件为「顶层目标 + 关键阶段门禁」混合模型。向后兼容现有单阶段 goal（`scope: "phase"` 或无 scope 字段）。**2026-06-20 更新**：`--from 0` 扩展已将范围扩大至全链 0→7（见下条）。来自 `pipeline-goal`
- `[2026-06-22]` 说明文档同步策略 — 三个面向用户的说明文档（FLOW-KIT-用户指南.md、README.md、flow-kit-ecosystem-guide.md）在每次重大 change 归档后应同步更新。优先更新用户指南（最详细），README 和 ecosystem-guide 做一致性对齐。来自 `docs-sync`
- `[2026-06-20]` pipeline goal 起始阶段可配置 — 新增 `--from <n>` 参数（0-7，默认 4），`start_phase` 字段，动态 gates 生成，0-3 阶段 pipeline toll-gate，跨阶段 AND condition 语法。向后兼容：旧 pipeline goal 无 `start_phase` 默认 "4"。来自 `goal-pipeline-phase0`
- `[2026-06-22]` brooks-tools 离线打包策略 — 采用 `npm pack` 逐工具打包 .tgz（非 pnpm store 直接提取），原因：pnpm 虚拟存储依赖符号链接无法跨机迁移。目标环境仅解压扁平 node_modules，无需 pnpm。仅打包 linux-x64 二进制，多平台矩阵列为 v2。来自 `bundle-packaging`
- `[2026-06-25]` 弱模型鲁棒性哲学定为 **protect the weakest** — 规则/prompt 默认全含加严（按最弱模型写），降级（强模型 opt-out，`model_tier: strong`）才需显式声明。**限定**：仅加"结构刚性"护栏（强模型也受益、不啰嗦），不加"重复唠叨"（啰嗦会反噬强模型、甚至增幻觉，由 AC-7 强制约束）。**否决**"运行时模型能力自动探测"方案（弱模型会幻觉自己很强，不可靠）。本次仅做 L1+L2+L3，L4 伪双轨留 v2。来自 `weak-model-robustness`
- `[2026-06-29]` 交互式 UI 触发防护策略 — hook 脚本为主防线（Stop hook 27-interactive-ui-check.sh 系统级检测 + SessionStart 矫正注入），prompt 轻量护栏为辅（每点 ≤3 行）。GATE_MAP 集中维护 9 个交互 gate 关键词映射。矫正文件 `.flow-active.interactive-ui-fix`（不入库）跨 turn 传递矫正指令。连续跳过 ≥3 次时停止自动矫正提示人工介入。来自 `weak-model-interactive-ui`
- `[2026-06-29]` 弱模型合规检测策略 — Stop hook 28 号模块对 L1/L2/L3 三层做系统级事后验证 + 矫正注入。采用统一矫正文件 `.flow-active.correction`（`type: "compliance"`），与交互 UI 矫正文件并行存在（v1 不合并，v2 迁移 27 号模块）。L1 检测范围覆盖 CONTEXT.md 禁动清单 + RULES.md/SYSTEM.md 通用禁动规则。SessionStart 同时处理 `.flow-active.interactive-ui-fix` 和 `.flow-active.correction` 两个矫正文件。代码长度 350 行为软指标（超出人工判断）。不改动现有 prompt 护栏（hook 是第二道防线）。来自 `robustness-hook-hardening`
- `[2026-07-01]` gate-integrity v1 范围 = 三种威胁全防（空 / 假 / 跳过 .done），分层校验（存在性 + 真实性 + transition 前置查 gate）。"假内容 .done"判定算法交 DESIGN 定，REQUIREMENT 仅约束"非真实产出的 .done 必须被识别为无效"。来自 `gate-integrity`（0-change + 1-requirement）
- `[2026-07-01]` Q1 防线定在 hook 层（非 prompt 层）—— agent 无法绕过 hook。PCSC/PCG 现有防线只查"存在性"被 touch 骗过，本次升级为查"真实性"。来自 `gate-integrity`
- `[2026-07-01]` 3/5/7 L2 默认 off —— gate-config `full` 预设仍只含 1/2/6，3/5/7 由用户显式开（数字简写 `1,2,3,5,6,7` 或新预设）。理由：避免 pipeline token 成本爆炸。来自 `gate-integrity`
- `[2026-07-02]` 独立审查四层架构确认 —— L2/L3 独立审查的完整性依赖四层同步：① PRESET_MAP ② Prompt 模板 ③ Hook 层 ④ L2-blind-review.md。gate-integrity 仅完成了 Hook 层 + PRESET_MAP `all` 预设；本次 independent-review-gap 补齐剩余三层。来自 `independent-review-gap`

## 默认偏好（AI 在缺省时按此决策）

- 命名风格：Shell 脚本遵循 `kebab-case` 命名（如 `package-flow-kit.sh`、`flow-kit-ecosystem-guide.md`）
- 错误处理：Bash 脚本使用 `set -euo pipefail`（`package-flow-kit.sh:3`）
- 状态管理：无（非前端/后端项目）
- 测试策略：bats-core 1.13.0（npx）· 94 个测试（截至 2026-06-25）。weak-model-robustness change 将追加弱模型护栏结构测试（见该 change REQUIREMENT AC-1/3/5）
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
| TD-002 | 🟢 | `flow-kit-bundle/hooks/stop/` + `lib/` | **核心 hook lib 已覆盖**（`flow-kit-artifacts.sh` 由 test_flow_artifacts 12 tests 覆盖、common 由 test_common 21 tests 覆盖）；残留：stop 链主脚本（22-git/24-session/26-workflow/99-report 等协调层，逻辑薄）仍无直接 smoke test | 可选：为 stop 链主脚本加 bats smoke test（低优先）| `M-health 2026-06-20` · 校准 `M-health 2026-06-24`（测试 43→94）|
| TD-003 | ✅ | `flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md` 入场 jq | `--from 0` pipeline 扩展时，4-dev.md + GO.md 已加 `start_phase` 读取，但这三个 prompt 仍是 `current_phase // "4"`（漏改）。实际影响低（current_phase 字段在 transition 时已正确更新，fallback 不触发），但一致性应补齐 | 统一三个 prompt 入场 jq 为 `current_phase // .start_phase // "4"` | `M-health 2026-06-20`（goal-pipeline-phase0 遗留）· **已修复 `0601dda`** · bats 77/78/79 验证（`M-health 2026-06-24` 复核）|
| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 共享函数 < 3 阈值，`lib/utils.sh` 保持推迟 | 等新增 ≥ 2 个共享辅助函数时再建 | `init-git-repo` T03 · 保持 deferred |
| TD-004 | 🟡 | `flow-kit-bundle/flow-kit/prompts/*.md`（15+ 文件） | Markdown prompt 样板重复率 22%——toll-gate 流程、独立 review 调度、Pipeline 规则等共享段在多文件中逐字重复，规则变更时须手动同步 N 处 | 抽取 `_shared/` 引用片段；下次 prompt 规则变更时一并重构 | `M-health 2026-07-02` |

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
