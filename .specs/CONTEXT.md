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
- **命名约定**（2026-07-20 · health-debt-cleanup 统一）：
  - **公共函数** `fk_*`：跨文件调用的 shared lib 函数（如 `fk_resolve_phase()`、`fk_check_doc_only_diff()`）
  - **私有函数** `_*`：文件内/模块内可见，开头下划线（如 `_fk_check_g1_body()`、`_gate_phase_filter()`）
  - 历史 `check_g*` 前缀已全仓迁移至 `_fk_check_*`
- **`_grep` 兼容层保留决策**（2026-07-20）：`fix-compliance.sh` 的 `_grep() { command grep "$@"; }` 保留。理由：Claude Code 环境将 `grep` 重写为 `ugrep`（-P 和扩展正则兼容性差异），`command grep` 强制走 GNU grep 保证跨环境一致。6 处调用均在 fix-compliance.sh 内，隔离良好，成本可忽略
- **install 函数长度容忍度**（2026-07-20）：`install_hooks()` 195 行不拆分。安装脚本非热路径（每项目执行一次），长度容忍度高于运行时 hook 的 `run_check` 路径。测试覆盖通过 dry-run 模式补齐

## 域语言（术语表）

| 术语 | 定义 |
|---|---|
| flow-kit | Claude Code 的开发工作流引擎，管理 0-change → 7-integration 全阶段 |
| Stop Hook | Claude Code 的 `Stop` 事件钩子链（11 模块），在**每轮对话结束时**（模型 stop generating，非 session close）自动执行。用于 L3 独立审查触发、auto_advance 检查、合规验证等 |
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
| fk_resolve_model | 公共函数（`hooks/stop/lib/common.sh`），按**五级**优先级链解析 L2/L3 审查模型名（2026-09-03 起含站点默认 tier-4/5；见已锁决策同日期条目）。用法：`model=$(fk_resolve_model "L3")`。全部未配置时返回空字符串（调用方负责降级） |
| FLOW_KIT_L2_MODEL / FLOW_KIT_L3_MODEL | 新增 env var，用于临时覆盖 L2/L3 审查模型（优先级 2，介于 ANTHROPIC_* env var 和 .flow-active 配置字段之间） |
| l2_model / l3_model | `.flow-active.goal` 的新增可选字段，持久化 L2/L3 审查模型名（优先级 3）。通过 `/flow model l2=<m> l3=<m>` 设置 |
| model resolution priority chain | L2/L3 模型名的解析策略（2026-09-03 起五级，显式永远压过默认）：1. ANTHROPIC_* env（CC 原生）→ 2. FLOW_KIT_L{2,3}_MODEL env（临时覆盖）→ 3. .flow-active.goal.l{2,3}_model（持久化显式）→ 4. FLOW_KIT_L{2,3}_DEFAULT_MODEL env（站点默认）→ 5. .flow-active.goal.l{2,3}_default_model（站点默认持久化，`/flow model l2-default=/l3-default=` 写入）→ 6. 空字符串（优雅降级）。每级非空即停 |
| graceful degradation (model) | fk_resolve_model 返回空字符串时的降级策略：不崩溃（不用 `:?` 终止），输出配置提示 + 写 `.flow-active.correction`（type=l*-model-missing），SessionStart 收割展示 banner |
| 门禁盲区（gate blind spot） | **检查器判据比真实契约更宽或更窄**，导致"改动已完成、CI 全绿、门禁却没看见"的状态。危害不是漏检本身，而是制造**假安全感**。2026-09-20 一次巡检暴露三处：dist 无新鲜度检查（判据缺失）、`make lint` 文件域漏 4 个脚本（判据过窄）、exec 判据按目录判定（判据过宽）。修法一律是**修判据**，不是修被测对象 |
| 判据过宽 vs 过窄 | 过窄 = 有东西该扫没扫（`make lint` 漏 `install.sh`）；过宽 = 有东西不该报却报（exec 位对"只被 source 的库"也要求）。**过宽同样有害**：长期存在会训练人忽略该告警，真问题来时报了也没人看 |
| 真入口（real entry） | hook 目录下**被直接执行**的脚本（要求 exec 位），区别于**只被 `source`** 的库（不要求 exec 位）。`pre-tool-use/` 下 3 入口（`independent-review-gate` / `auto-checkpoint` / `runtime-edit-guard`）vs 4 库（`gate-helpers` / `gate-helpers-types` / `gate-checks-basic` / `gate-checks-review`）。判据应按此契约而非按目录 |
| AC 预检（AC pre-check） | 写 REQUIREMENT 时就**先跑一次**该 AC 的验证命令，确认它**当前失败**，从而证明这条 AC 有证明力。若修复前就通过，说明它"测试了不存在的东西"（本仓 TD-016 教训）。预检结果记入 REQUIREMENT.md，还原动作必须保证工作区干净 |
| 新鲜度门禁（freshness gate） | 判定**派生产物是否落后于其源**的检查（本仓将新增 `check-dist`）。与一致性门禁的区别：一致性门禁比"两份内容是否相同"，新鲜度门禁回答"该重新生成的是否已重新生成"。适用于任何 `dist/`-style 生成物 |
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
| 双向依赖环（bidirectional dependency cycle） | lib 模块间 A→B 且 B→A 的相互引用关系，违反 ADP（Acyclic Dependencies Principle）。症状：改任一模块可级联破坏另一个；单元测试隔离困难。修复方式：提取共享接口/常量到第三方轻量文件，双方依赖接口而非彼此 |
| 聚合入口模式（aggregate entry pattern） | Bash 项目的向后兼容拆分模式：主文件（如 `flow-kit-artifacts.sh`）拆为多个子库后，自身改为仅 source 子库 + re-export 函数，外部调用方无需修改 source 路径。用于 L-016 大文件拆分 |
| 共享 reference 片段（shared reference fragment） | 多个 prompt 文件引用的单一源片段（位于 `flow-kit/reference/` 下），避免同一代码块在多个 prompt 中逐字重复。用于 TD-005 jq goal 解析逻辑消除 |
| health-fix-2026-07 | 2026-07-04 健康巡检的修复 change，一次性消除 1🔴 + 1🟡 + 2🟢 共 4 项技术债（L-021 循环依赖 / TD-005 jq 重复 / L-016 artifacts 拆分 / L-017 package 拆分） |
| L2-only | gate_config 值，仅开启同会话子 agent 盲审（L2），跳过外部模型审查（L3）。零额外网络延迟，适合慢系统快速迭代 |
| L3-only | gate_config 值，仅开启外部模型盲审（L3），跳过子 agent 调度。节省子 agent token 消耗，依赖不同模型的独立视角 |
| both | gate_config 值，同时开启 L2 + L3 双层审查。"independent" 和 "true" 作为向后兼容别名自动映射为 both |
| l2-l3-granular-gate | 2026-07-06 change：将 gate_config 的独立审查开关从单一 "independent" 拆分为 L2/L3/both 三值，支持按需选择审查层级 |
| 27-interactive-ui-check.sh | Stop hook 第 27 号模块：每次会话停止时 grep transcript 检测弱模型是否跳过了交互 gate（prompt 含"反问用户"等关键词但回复中无 AskUserQuestion/EnterPlanMode 工具调用），跳过则写入矫正文件 `.flow-active.interactive-ui-fix` |
| 矫正文件（correction file） | `.flow-active.interactive-ui-fix`（JSON，不入库）：Stop hook 检测到交互 gate 跳过时写入，含 gate_type / required_tool / retry_count。SessionStart flow-kit-resume.sh 检测到后注入矫正 banner 强制模型补调工具，retry_count ≥ 2 时停止矫正提示人工介入 |
| weak-model-compliance | Stop hook 第 28 号模块：每次会话停止时对模型回复做三层事后合规验证——L1 规则合规（禁动清单+通用规则）、L2 自检完整性（自检表无空白/跳过）、L3 证据链真实性（引用路径在工具调用历史中出现过）。检测到违规 → 写入统一矫正文件 `.flow-active.correction` |
| `.flow-active.correction` | 统一矫正文件（JSON，不入库）：用 `type` 字段区分违规类型（`compliance` / `interactive-ui`），含 `layer`（L1/L2/L3）、`violations` 数组、`written_at` 时间戳。v1 仅 `28-weak-model-compliance.sh` 写入 `compliance` 类型；`27-interactive-ui-check.sh` 暂保持旧文件，v2 迁移。SessionStart 同时处理两个矫正文件 |
| L1 hook 层规则合规检测 | Stop hook 对 transcript 中模型回复做规则合规扫描——grep 触碰 CONTEXT.md 禁动清单路径 + 违反 RULES.md/SYSTEM.md 通用禁动规则（如"禁止编造文件路径"）。属 28 号模块 L1 层 |
| L3 hook 层证据链检测 | Stop hook 验证模型回复中引用的文件路径/API 名/字段名是否在 transcript 工具调用历史中出现过——未出现则判定为幻觉引用。属 28 号模块 L3 层，是对 prompt 层 L3 护栏（grep-before-cite）的系统级兜底 |
| HOOK_MODULE_NAMES | `common.sh` 中定义的共享 hook 模块名数组（`declare -a HOOK_MODULE_NAMES=(00-gate 01-transcript-parse ... 99-report)`）。`install_hooks.sh` 和 `package-flow-kit.sh` 均引用此数组，消除两处重复维护 |
| PHASE_ARTIFACTS | `flow-kit-artifacts.sh` 中定义的关联数组（`declare -A`），将 phase 映射到其必须产物列表。`fk_artifact_check()` 据此查表驱动，替代硬编码分支判断 |
| correction-file.sh | 新建的通用 JSON correction file 管理 lib（`hooks/stop/lib/correction-file.sh`），提供 `correction_file_write()` / `correction_file_read()` / `correction_file_clear()` / `correction_file_exists()` 四个函数。`interactive-ui-check.sh` 和 `weak-model-compliance.sh` 均调用此 lib，消除结构重复 |
| L3 header 不匹配（L3 header mismatch） | `flow-kit-resume.sh:138` 的 L3 检测 grep 字符串 `"## L3 外部模型审查"` 与 `l3-review.sh:200` 实际写入的 header `"## L3 盲审"` 不一致，导致 SessionStart 无法识别已完成的 L3 审查，L3 结果不注入 session context |
| phase 字段二义性（phase field ambiguity） | `.flow-active` 同时存在 `.phase`（单阶段模式用）和 `.goal.current_phase`（pipeline 模式用）两个 phase 字段。Stop hook `29-independent-review.sh` 仅读 `.phase`，pipeline 模式下可能读到过期值导致跳过或误触发 L3 |
| L3 工件截断（L3 artifact truncation） | `l3-review.sh` 使用 `head -c $max_chars`（默认 20000）硬截断阶段产物作为 L3 prompt。大产物（如 phase 6 的 git diff + REVIEW.md）被截断后 L3 模型基于不完整信息审查，增加假阳性风险 |
| .done 6 键 KVP | `.independent-review-<N>.done` 的标准键值对格式：`phase` / `change_id` / `written_by` / `L2_verdict` / `L3_verdict` / `artifacts`（6 键）。PreToolUse gate 和 SessionStart hook 依赖此格式校验 done 有效性 |
| L2 被动触发（L2 passive trigger） | 让 L2 子 agent 审查像 L3 一样由 hook 系统（Stop/PreToolUse）自动检测并触发/提示，不依赖主 agent 主动读 prompt 并手动派 agent。当前 L2 仅靠 prompt 中的「独立 review 调度」段指令主 agent 派发，易被跳过导致断裂 |
| L3_RESULT 格式 | L3 审查结果的标准单行格式：`L3_RESULT: verdict=<pass\|fail\|timeout\|error> summary=<一句话> report=<报告相对路径>`。由 `_l3_format_result()` 生成，供 PreToolUse stdout（F1）和 SessionStart banner（F2）共用 |
| l3-comprehensive-fix | 2026-07-07 change：全面审计并修复 L2/L3 独立审查的 4 个运行时 bug——L3 结果注入 gap、L3 长度限制假阳性、.done 重复触发、Phase 5/6/7 L2 自动拉起断裂 |
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
| L3 前置（L3 front-loading） | 将 L3 外部模型 API 调用从 Stop hook（会话结束触发）移到 PreToolUse hook（transition jq 拦截点）同步执行。解决 L2+L3 异步死锁（F1）：L3 原需等会话结束，但 pipeline transition 需 L3 完成后才放行 → 单 session 内无法闭环。前置后 transition 时同步完成 L2+L3，Stop hook 保留作兜底 |
| l3-review.sh | 共享 lib（`hooks/stop/lib/l3-review.sh`），抽取 L3 API 调用逻辑（模型选择、prompt 构建、API 请求、30s 超时处理、结果解析）为单一函数，供 `independent-review-gate.sh`（PreToolUse）和 `29-independent-review.sh`（Stop hook）两处复用 |
| transition 方向检测（transition direction detection） | `independent-review-gate.sh` 在 `is_phase_write` 时比较目标 phase 与当前 phase：目标 < 当前 → 回退（放行，不要求 .done）；目标 > 当前 → 前进（正常 gate 检查）。解决 F3：pipeline 卡住后无法后退恢复 |
| gate_config 快照同步（gate_config snapshot sync） | `/flow gate-config` 和 `/flow goal --gate-config` 同时写入 `.flow-active.goal.gate_config` 和 `.specs/<id>/.goal-snapshot.json`，保持两处一致。解决 F2：hook D8 ⑥ 快照不一致导致篡改检测死锁 |
| auto_advance hook 兜底 | `31-auto-advance.sh` Stop hook 模块：检测 `auto_advance=true` + PCSC 全✅ → 自动执行 transition jq。补充原先纯 prompt 驱动的 auto_advance 机制（F4），确保弱模型跳过指令时 hook 层仍执行 |
| fallback hook 兜底 | `32-fallback-guard.sh` Stop hook 模块：检测 `mode=fallback` + pipeline 完成条件满足 → 自动更新 `goal.status=done`。补充原先纯 prompt 驱动的 fallback 机制（F5） |
| 31-auto-advance.sh | 新增 Stop hook 第 31 号模块：auto_advance hook 兜底——Stop 时若 `auto_advance=true` 且当前阶段 PCSC 全✅，自动执行 transition jq 推进到下一阶段 |
| 32-fallback-guard.sh | 新增 Stop hook 第 32 号模块：fallback hook 兜底——Stop 时若 `mode=fallback` 且 pipeline 到达终点（phase 7 PCSC 全✅），自动标记 `goal.status=done` |
| .flow-active 状态完整性（.flow-active state integrity） | `.flow-active` 各字段（phase / task_id / change_id / goal / token_spent / updated_at）与实际磁盘产物和操作历史的一致性。完整性违规 = 状态漂移（state drift），分为四类：字段漏写、pipeline goal 字段漂移、change_id 不一致、token_spent 未维护 |
| 状态漂移（state drift） | `.flow-active` 字段值与实际情况的偏差。来源包括：AI 跳过 jq 写入（L2 漏检）、pipeline transition 执行不完整、change 归档后 change_id 未清理。当前无自动化检测，靠人工发现 |
| 交叉验证（cross-validation） | L3 hook 层对 `.flow-active` 字段与磁盘产物的一致性校验。例：`phases_done` 中的 phase N → 对应 `.specs/<id>/` 下产物必须存在；`change_id` → `.specs/<id>/` 目录必须存在；`gates` 与 `phases_done` 双向对齐 |
| 时效性检测（staleness detection） | L3 hook 对 `.flow-active.updated_at` 的时间窗口检查。若距当前时间超过阈值（默认 24h）→ 报告 "stale .flow-active" 警告，提示可能漏维护 |
| auto-checkpoint | flow-kit 在关键操作时自动更新 `.flow-active.interrupt` 的机制。**三层实现**：① prompt 层指令（AI 在 4-dev 关键节点手动 `/flow checkpoint`）② PreToolUse hook 层兜底（Write/Edit 调用前自动写 interrupt，100% 覆盖，不去抖）③ Stop hook G5 PROGRESS 日志（会话粒度进度记录）。三层互补不冲突——最后写入者覆盖。v1（auto-checkpoint-hook change）只实现第②层 PreToolUse hook；①③ 已存在 |
| checkpoint 触发事件 | auto-checkpoint 的触发条件。**已实现**：① Write/Edit PreToolUse hook（编辑文件前 · 全阶段 0~7 · 不去抖 · 每次更新 · fail-open）② 测试命令返回非零退出码（prompt 层手动触发）③ phase transition（prompt 层手动触发）④ toll-gate 暂停（prompt 层手动触发）。每次触发写入 active_file + last_action + checkpoint_at。**注意**：v1 去掉了早期设计中的 30s 去重窗口——实测 jq 更新 < 10ms，去重增加的复杂度（比较时间戳 + 同文件判定）不值得 |
| checkpoint-lib.sh | auto-checkpoint 的共享 lib：提供 `checkpoint_write(file, desc)` 函数封装 jq 写入 + fail-open 容错 + 活跃 change 检测。由 PreToolUse hook 脚本调用。**禁止**绕过直接 jq write `.flow-active.interrupt`（必须通过 `checkpoint_write()`）——此约束在 `@.specs/CONTEXT.md` § 禁动清单 已登记 |
| L2-first gating（L2 优先门控 · ADR-009 调度契约） | gate_config="both" 时的两层约束：**(1) 调度契约**——主 agent 必须先派 L2 子 agent + 写 `## L2 盲审` 段到 `INDEPENDENT-REVIEW-N.md`，Stop hook 29 才会跑 L3（Stop 不能自派 L2 子 agent，框架硬限制）；29 D4 门（主门 + fallback）检测不到 `## L2 盲审` 段时输出派发指引 + 写 `.flow-active.correction`(type=l2-missing) 作持久化日志。**(2) 时序约束**——L3 必须在 L2 完成后才写 `.done`；L3 可先产出审查内容，但 `.done` 标记推迟到 L2 完成后，防止主 agent 误判"双层审查已完成"。BUG-I 根因修正：原"Stop 触发不可靠"经 Explore 诊断为误判，实为 L2-first 调度契约未满足（主 agent 未派 L2） |
| append-write semantics（追加写入语义） | L2 子 agent 写入 `INDEPENDENT-REVIEW-<N>.md` 时的文件操作约束：必须追加（`>>`）而非覆写（`Write` 全量）。若文件已有 L3 段，L2 段追加到文件末尾并标注顺序。解决 L2 子 agent 用 Write 工具覆写文件时销毁已有 L3 内容的问题 |
| dual-review-merge-fix | 本次 change：修复 L2/L3 双层审查因时序错位（L3 先于 L2 完成）+ 文件覆写（L2 Write 销毁 L3 段）导致审查建议丢失的问题。三处修复：① 29 号 hook L3 等待 L2 ② L2 prompt 改为追加写入 ③ .done 仅在双方完成后写入 |
| L3 反馈可见性（L3 feedback visibility） | L3 外部模型审查的结果（verdict + summary）在 agent 对话上下文中的可感知性。区别于静默写入磁盘文件（当前行为）。本次 change 修复两条路径上 L3 反馈不可见的问题 |
| L3 反馈通道（L3 feedback channel） | L3 审查结果到达 agent 上下文的两条路径：① PreToolUse 同步路径（transition 时 hook 输出）② SessionStart 恢复路径（resume banner 注入）。两条路径展示字段一致（verdict + summary + report path） |
| PreToolUse agent 上下文通道 | PreToolUse hook 执行期间，将 hook 脚本的产出（如 L3 verdict）传递到 agent 对话上下文的技术机制。区别于 hook 日志（`>> "$hook_log"` 仅开发者可见） |
| `L3_RESULT:` 输出格式 | L3 反馈的统一输出契约行格式：`L3_RESULT: verdict=<PASS\|FAIL\|WAIVER\|TIMEOUT\|error> summary=<text> report=<path>`。PreToolUse 路径以 hook stdout 单行输出，SessionStart 路径以 resume banner 内嵌行输出。report 字段使用相对路径（不暴露文件系统绝对路径） |
| L3 summary 提取（F3） | `l3-review.sh` 新增的 summary 字段提取逻辑——与 verdict 提取并列，从 L3 API 响应 JSON 中解析 `summary` 字段并写入 `.done` 文件的 `L3_summary` 键，供两条反馈路径统一读取 |
| 修代码优先协议（fix-code-first protocol） | prompt 层强制规则：L2/L3 独立审查发现的源码级问题必须对应代码修复（git diff 可见）或显式技术债登记（含理由），禁止仅写文档了事。仅对 5/6/7 阶段触发 |
| 纯文档响应（doc-only response） | agent 对 review 发现的敷衍模式：diff 中仅有 `.md` 文件变更，无任何源码文件修改。hook 层检测到此模式时阻断 gate transition |
| 实效性校验（efficacy check） | gate 层新增的第三校验维度（在存在性校验 PCG、真实性校验 gate-integrity 之上）：验证 review 发现确实导致了代码变更，而非仅文档修改。在 `independent-review-gate.sh` transition 拦截点执行 |
| 源码级发现（source-level finding） | INDEPENDENT-REVIEW-<N>.md 中指向源码文件（非 .md 文档）问题的发现条目。区分于文档级发现（如"README 缺少使用说明"），后者不触发代码修复强制 |
| 技术债登记滥用（tech-debt registration abuse） | agent 将所有 review 发现标记为"技术债"以绕过代码修复的反模式。防护方式：≥50% 发现被登记为技术债时，prompt 要求 agent 输出显式说明 |
| l2-l3-fix-compliance | 2026-07-07 change：在 prompt 层 + hook 层加固 review 发现→代码修复的强制链路，杜绝"文档敷衍"。双层：prompt 修代码优先协议 + hook 实效性校验 |
| regex-in-variable（变量存 regex） | bash `[[ string =~ regex ]]` 的安全模式：regex 先存入变量（`local re='...'; [[ "$x" =~ $re ]]`）再匹配，使 regex 内的 `&&`/裸空格不被 bash 当源码层逻辑与/词法拆分。TD-011 根因即内联 regex 的 `&&` 被当逻辑与致 SC2157 恒真。来自 `refactor-independent-review-gate` |
| L3 重审（L3 re-review） | L3 审查 verdict=fail 后，若对应阶段产物文件 mtime 晚于上次 L3 审查时间戳，下次 hook 触发时自动重新调用 L3 API 审查，在 INDEPENDENT-REVIEW-N.md 末尾追加新的 `## L3 重审` 段（含新 verdict + summary），不覆写旧段。解决 L-030 问题 1（L3 fail 后永久死结）。来自 `fix-l3-gate` |
| 工件变更检测（artifact change detection） | L3 重审的触发判定机制：用 `stat -c %Y` 比较产物文件 mtime 与上次 L3 审查时间戳（记录在 .done 或 INDEPENDENT-REVIEW-N.md 元数据中）。mtime 更新 → 触发重审。O(1) 无额外延迟。来自 `fix-l3-gate` |
| .done 安全写逻辑（.done safe-write） | L3 verdict=fail 时**不写** `.independent-review-N.done` 文件，仅 verdict=pass 时写入。消除 L-030 问题 2（L3 fail 却写 .done 放行 transition 的安全漏洞）。不影响回退方向（回退放行不要求 .done）。来自 `fix-l3-gate` |
| transition 四字段同步（transition four-field sync） | transition jq 执行时原子更新 `.flow-active` 的四个 phase 相关字段：`goal.current_phase`、顶层 `phase`、`goal.phases_done`（追加旧 phase）、`goal.gates["N→N+1"]`（标记 passed）。解决 L-030 问题 3（顶层 phase 与 goal.current_phase 不同步）。来自 `fix-l3-gate` |
| resume banner | SessionStart hook 输出的 ASCII art 状态横幅（`flow-kit-resume.sh` L201-L254），显示活跃 change 的 change_id / phase / task / goal / interrupt / token 信息。来自 `checkpoint-polish` |
| 双源测试同步（dual-source test sync） | `test/`（开发源）和 `flow-kit-bundle/test/`（打包源）的 bats 测试文件自动保持一致——修改一处后通过 `make test-sync` 或符号链接同步到另一处，替代手动 `cp`。来自 `checkpoint-polish` |
| CHANGELOG 紧凑单行 pipe 格式 | `.specs/CHANGELOG.md` 的统一条目格式：`| 日期 | change-id | 摘要 | LESSONS |`（无独立表头行），全文件统一使用此格式。来自 `checkpoint-polish` |
| `run_check()` | check_* 统一包装函数，签名 `run_check(name, enabled_check, condition, message)`。替代各模块手写 `check_enabled` guard → 读状态 → 检查条件 → `module_output` 四段样板模板。来自 `sweep-fix-2026-07-10` |
| `_grep` 兼容层 | 对 ugrep 的封装兼容层代码。本次 sweep-fix-2026-07-10 评估其去留：若 ugrep 已安装且功能兼容则移除，否则保留并标注 deprecated。决策结论写入 CHANGE.md。来自 `sweep-fix-2026-07-10` |
| sweep-fix-2026-07-10 | 2026-07-10 Full Sweep（评分 65/100）的修复 change，消除 2🔴（TD-017 函数拆分 + TD-018 函数拆分）+ 4🟡（TD-019 check去重 + TD-020 死代码 + TD-021 命名文档 + TD-022 安装测试）+ 1 评估项（_grep 去留），目标评分 ≥80。来自 `M-health 2026-07-10 Full Sweep` |
| `PHASE_GATE_KEY_MAP` | `common.sh` 中新增的 phase→gate_key 映射关联数组（`declare -A`），替代各 hook/prompt 中硬编码的 `case "$phase" in 1) "1-requirement" ;;` 片段，作为 phase_name 解析的单一源。来自 `health-fix-l3-2026-07` |
| `correction-types.sh` | 新建的共享常量/类型定义文件，提取 correction-file / interactive-ui-check / weak-model-compliance 三模块的共享接口，消除三向依赖环。遵循"依赖接口而非彼此"的 ADP 原则。来自 `health-fix-l3-2026-07` |
| `goal-parsing.md` | `flow-kit/reference/` 下新增的共享片段文件，抽取 6-review.md 和 7-integration.md 中重复的 jq goal 解析逻辑（~30 行/处），作为 DRY 单一源。prompt 中通过 `@see` 引用。来自 `health-fix-l3-2026-07` |
| `health-fix-l3-2026-07` | 2026-07-11 L3 审计健康巡检（72/100）的修复 change，消除 3🔴 + 6🟡 + 3🟢 共 12 项技术债——长函数拆分（6 函数）+ 依赖环解环 + DRY 消除（2 处）+ timeout 测试补齐 + self-sourcing 修复 + 死代码清理。来自 `.specs/health/2026-07-11-L3-AUDIT-HEALTH.md` |
<!-- l3-pipeline-fix-2026-07 追加 ↓ -->
| L3 管线 5 项限制（L-040） | `health-fix-l3-2026-07` 暴露的 L3 审查子系统 5 项系统级限制：① git diff 硬限 5000 字符 ② `git diff HEAD` 不含 untracked 文件 ③ `head -c` 逐文件硬截断丢弃尾部 ④ 仅审当前 phase，历史积压不处理 ⑤ 每次审查独立无状态上下文。本次 change 一次性修复全部 5 项。来自 `l3-pipeline-fix-2026-07` |
| 积压扫描（backlog scan） | Stop hook 29 号模块新增逻辑：检测 `phases_done` 中哪些 phase 的 gate_config 含 L3 但 `.independent-review-{N}.done` 缺失，自动触发 L3 补跑。解决 L-040 限制④。来自 `l3-pipeline-fix-2026-07` |
| 智能截断头+尾保留（smart truncation head+tail） | `smart_truncate()` 的新截断策略：取文件前 N/2 + 后 N/2 字符（替代纯 `head -c` 头部截断），确保 AC 段 + 风险/决策段均不丢失。解决 L-040 限制③。来自 `l3-pipeline-fix-2026-07` |
| L3 上下文注入（L3 context injection） | L3 prompt 构建时注入前次审查摘要：前次 verdict + 主 agent 反驳 + L2 verdict。使每次审查基于历史上下文而非独立盲审。解决 L-040 限制⑤。来自 `l3-pipeline-fix-2026-07` |
| Stop hook 性能基线（Stop hook performance baseline） | 优化前对 Stop hook 链各模块做 wall-clock 耗时测量（`time` 3 次取中位数），作为 ≥30% 性能提升目标的对比基线。优化方向待测量后确定（异步化 / 懒加载 / 并行化）。来自 `l3-pipeline-fix-2026-07` |
<!-- l3-pipeline-fix-2026-07 追加 ↑ -->
<!-- l2-pretooluse-dispatch 追加 ↓ -->
| L2 PreToolUse dispatch | PreToolUse hook 层新增的 L2 独立审查前置触发机制：AI 写 `.flow-active.phase` 切换阶段时，`independent-review-gate.sh` 检测目标阶段 gate_config 是否含 `L2` 或 `both`，若 L2 缺失则硬拦截（exit 2）并自动派发 L2 审查 Agent。与 Stop hook L2（事后兜底）互补，不替代。来自 `l2-pretooluse-dispatch` |
| PreToolUse L2 gate | `independent-review-gate.sh` 中新增的 L2 检测分支：在 `is_phase_write` 命中后，对 gate_config 含 L2/both 的阶段调用 `l2_detect_missing()` 判定 L2 完成状态，缺失则 fail-close deny。与既有 L3 gate 独立判定（任缺其一即拦截）。来自 `l2-pretooluse-dispatch` |
<!-- l2-pretooluse-dispatch 追加 ↑ -->
<!-- l2-l3-test-defect 追加 ↓ -->
| gate 编排层（gate orchestration layer） | independent-review-gate.sh 的 `_run_review_gates` 编排逻辑（Gate1 path-guard → Gate2 phase filter → Gate3 gate active → Gate4 done validation → Gate5 tamper → Gate6 phase transition → Gate7 deny reason）。区别于底层 lib 单函数（l2-detect.sh / done-validation.sh）。诊断教训：编排层**必须**有集成测试（PreToolUse payload 注入 `bash gate.sh` + exit code 断言），单元测试（source lib + 调单函数）覆盖不到编排层 bug。来自 `l2-l3-test-defect`（BUG-A/B/C/D/E 全在编排层，原 AC-1~11 全单元级，0 覆盖） |
| 返回值语义反转（return-value semantic inversion） | bash 函数 return 0=成功/1=失败的惯例与业务约定的"0=skip,1=continue"冲突时的陷阱。gate 函数（_gate_phase_filter/_gate_active_check）曾用 0=skip/1=continue，调用方却用 `cmd \|\| exit 0`（非0=失败→放行）→ 双向 bug：skip 的继续走 gate、continue 的反向放行。修复：调用方显式 rc 判定（`if cmd; then exit 0; fi`）。来自 `l2-l3-test-defect` BUG-A/B |
| gate-active source 依赖 | `_gate_active_check` 必须 source 定义 `fk_independent_review_gate_active` 的 lib（**done-validation.sh**，非 artifacts.sh）+ 传 `PROJECT_ROOT=cwd`。否则 `type` 失败 → gate 永远判定"未开"→ 所有 review phase 的 commit/transition 在 Gate3 放行（gate 形同虚设）。来自 `l2-l3-test-defect` BUG-E |
| 假绿（false-green） | 测试声明（CHANGELOG/commit "全绿"）与实际不符——测试实际失败却被声明通过。`l2-pretooluse-dispatch` 的 AC-5a/5c/9 三个 mock 测试因 `mock_ts` 未定义一直失败，但 CHANGELOG 声称「12 tests 全绿」。验收前必须实跑 `npx bats` 确认，不信任声明。来自 `l2-l3-test-defect` BUG-G |
<!-- l2-l3-test-defect 追加 ↑ -->
<!-- l2-l3-mock-fix 追加 ↓ -->
| PHASE_GATE_KEY_MAP pure fn | phase→gate_key 映射的**单一来源纯函数**，替代 `common.sh:255` 与 `independent-review-gate.sh:25` 的重复 `declare -A`。消除 v1 修复（D7 复制 declare）引入的 DRY 违反与失同步风险。来自 `l2-l3-mock-fix` BUG-F |
| 结构化命令识别（structured command recognition） | 基于命令结构（argv / 命令边界）而非文本子串判断命令类型。解决 `is_git_commit` 子串误判——L2 审查报告正文含 "git commit" 字符串被误拦，被迫 `chr()` 拼装绕过。来自 `l2-l3-mock-fix` BUG-H |
| `## L3` 段检查（## L3 section check） | L3 复审判定基于 artifact markdown 的 `## L3` 段是否存在/更新，而非文件 mtime。解决 `_l3_check_rerun` 的 mtime 误判——artifact 被 touch 即被误判已审查而 skip 复审。来自 `l2-l3-mock-fix` BUG-J |
<!-- l2-l3-mock-fix 追加 ↑ -->
<!-- gate-done-authorship 追加 ↓ -->
| `.done` 作者性校验（`.done` authorship verification） | gate `.done` 的第三维校验：不仅检查存在性（PCG）和真实性（gate-integrity），还验证 `.done` 由审查子系统（l3_review_run / L2 子 agent）而非主 agent 产出。解决独立 review gate「agent 可自写合法 .done 绕过 L3」的安全缺口 |
| 握手死代码（handshake dead code） | 已废弃的 `state_file` 握手机制残留代码：`is_handshake_write()`（independent-review-gate.sh:30）、`29-independent-review.sh` 的 state_file 读（:68-74）+ 条件删除（:125, :203-204）、`done-validation.sh` Tier 2 T3 握手校验死分支。写入路径在 gate 重构中废弃，但校验 + 测试未同步清除 |
| path-guard D7 扩展（path-guard D7 extension） | 将 independent-review-gate.sh 的 D7 path-guard 从当前覆盖的文件类型扩展到 `.independent-review-*.done` 文件，禁止 agent 通过 Bash/Write/Edit 直接写入 `.done`。方案 A 的核心机制。需配合 L2-only 模式例外（按 gate_config 条件放行 agent 写 .done） |
| L2-only 模式例外（L2-only mode exception） | gate_config=L2 时，协议要求主 agent 写 `.done`（6-review.md:129）。path-guard D7 扩展需识别此模式并按 gate_config 条件放行 agent 写 `.done`（非全局禁），否则 L2-only 用户 pipeline 死锁 |
<!-- gate-done-authorship 追加 ↑ -->
<!-- l3-review-timeout-token 追加 ↓ -->
| L3 思考吃满预算（L3 thinking budget exhaustion） | deepseek-v4-pro 扩展思考模式失败：在产生结论前把全部 max_tokens 预算花在 thinking block 上 → 无 text block → `jq select(.type=="text")` 返空 → rc=3。区别于 glm-4.7 时代的"幻觉 critical"失败模式。根因在工具层（l3-review.sh 硬编码 max_tokens:8000 + curl --max-time 90 无配置入口），非模型层 |
| FLOW_KIT_L3_MAX_TOKENS / FLOW_KIT_L3_TIMEOUT / FLOW_KIT_L3_THINKING | 三个新增 env var，覆盖 l3-review.sh::_l3_call_api() 的硬编码上限。默认值：max_tokens=32000 / timeout=300s / thinking=enabled。遵循 env-var-first config 策略。disabled 时请求体加 `thinking:{type:"disabled"}`（L3 子 agent 实测 58.4s 返 3334 token 含 text block） |
<!-- l3-review-timeout-token 追加 ↑ -->
<!-- superpowers-v6-absorb 追加 ↓ -->
| review-package | flow-kit-bundle/flow-kit/scripts/review-package（新）· 预烤 git diff/metadata 到文件的 bash 脚本。借自 superpowers v6.0 B2，使 reviewer 单次 Read 取代多次 shell 调用，diff bytes 不进 controller context |
| task-brief | flow-kit-bundle/flow-kit/scripts/task-brief（新）· 从 TASK.md 提取单个 task XML block 到文件的 awk 脚本。借自 superpowers v6.0 B3。配套 4-dev.md 改造：从"读整个 TASK.md"变为"读 task-brief 输出" |
| terse contract（terse reviewer contract）| review 类 prompt 顶部的硬性输出 schema 约束：verdict-first / no preamble / no process narration / no closing summary / every line is verdict-or-finding-with-file:line-or-check。借自 superpowers v6.0 B4。预期 -41% reviewer output |
| narration constraint | phase prompts 顶部的"between tool calls, narrate at most one short line"约束。借自 superpowers v6.0 B5。预期 -54% controller output |
| severity gating | review findings 三档分类：Critical（必须 fix）/ Important（入 fix loop）/ Minor（写入 deferred ledger，最终审查时 triage，不入 loop）。借自 superpowers v6.0 B7。配套文件：`.specs/<id>/MINOR-DEFERRED.md` 或 T<N>-SUMMARY.md 的 deferred 段 |
| model-tier | TASK.md XML 的 task 块新属性：`<task id="T03" model-tier="cheap|standard|top">`。借自 superpowers v6.0 B6/C2。OpenCode 实际生效路径在 DESIGN § 6 验证（task-level switching vs dispatch prompt hint） |
| task_progress（progress ledger）| `.flow-active.goal.task_progress[]` 新字段。每项含 `{id, commit_sha, fix_rounds, deferred[], completed_at}`。借自 superpowers v6.0 C4。防 compaction 后重新分派已完成 task（superpowers 文档称"single most expensive failure"）。与 T<N>-SUMMARY.md 并存——task_progress 机器读实时，SUMMARY 人读事后 |
| plan-conflict-scan | phase 3 末段新子步骤：扫 TASK.md 内部矛盾 + 与 CONTEXT.md 禁动清单冲突 + 与既有 ADR 冲突。借自 superpowers v6.0 C3。冲突一次性 batch 给用户，避免 mid-run interrupt |
| bootstrap compression | prompt 体积削减实践。借自 superpowers v6.1 把 using-superpowers 从 121 → 62 行：graphviz DOT → prose / 删 per-platform 工具表 / 折叠 Instruction-Priority 段。flow-kit 应用对象：GO.md（目标 473 → ≤350 行） |
| cross-model spot-check（CMSC）| review phase 的独立第 2 轮外部模型盲审。借自 superpowers v6.0 概念但 flow-kit 加强：仅 Critical-finding 触发（不每次跑）。触发标志：`.flow-active.goal.task_progress.spot_check_triggered` |
<!-- superpowers-v6-absorb 追加 ↑ -->
<!-- final-debt-cleanup-2026-08 追加 ↓ -->
| writing principles (3) | flow-kit 写作 3 原则（ADR-019）：AC 必须确定性（条件 AC 拆 hard+soft）/ 范围决策属 DESIGN 非 REQUIREMENT / 图表须引用可验证产物。新 change 的 REQUIREMENT/DESIGN 必须遵守。来自 ADR-019 |
| ADR-019 | flow-kit 写作 3 原则文档（L-058/060/062 closed）。路径 `.specs/adr/019-writing-principles.md` |
| ADR-020 | OpenCode task tool 能力快照（L-061 closed）。结论：当前 OpenCode 不支持 task-level model-tier，model-tier 仅作 dispatch prompt hint。路径 `.specs/adr/020-opencode-task-capability.md` |
| ADR-021 | 弱模型 prompt 降级协议设计（L-063 closed）。协议已设计但未实现（v2 task）。路径 `.specs/adr/021-weak-model-prompt-degradation.md` |
<!-- final-debt-cleanup-2026-08 追加 ↑ -->
<!-- user-guide-sync-2026-09 追加 ↓ -->
| dsh-flow-kit（dsh 插件）| flow-kit 的 DeepSeek Harness 插件化交付：包内 `skills/ flow-kit/ hooks/ brooks-lint/ vendor/`（内容层由 package-dsh-plugin.sh 从 flow-kit-bundle 拷贝），cordis.patch.yml 挂载；用户文档（FLOW-KIT-用户指南.md 等）随打包进入插件 `docs/` |
| doctor correction 卫生报告 | `/flow doctor` 对 `.flow-active.correction` 的摘要报告：无文件→✅；violations>0→`type=…, violations=N`（摘要字段 `check→rule` 回退，ADR-024 异质 schema）；仅 message→`type=… — message`；解析失败 fail-open |
| archive-commit 门禁（34 号 hook）| 阶段 7 归档提交完整性门禁：归档产物与 CHANGE 范围核对后才放行/记录（含 commit-protocol 分类）；install.sh 同时部署 pre-commit 钩子（deploy_pre_commit，user scope 源文件安装） |
| tier-4/5 站点级默认模型 | 五级解析链第 4/5 级：`FLOW_KIT_L{2,3}_DEFAULT_MODEL` env + `.goal.l{2,3}_default_model` 字段，由 `/flow model l2-default=/l3-default=` 持久化；语义见「已锁决策」2026-09-03 条 |
<!-- user-guide-sync-2026-09 追加 ↑ -->
<!-- l3-prompt-loop-fix 追加 ↓ -->
| 反馈优先截断（feedback-first truncation） | L3 prompt 字节预算超限时的截断顺序设计立场：CHANGELOG/LESSONS/前轮反馈等注入段优先保留，7 文件工件正文承受截断（截正文不截反馈）。来自 `l3-prompt-loop-fix` |
| 前轮发现单行摘要（prior-findings digest） | L3 重审 prompt 注入前轮 critical/major 发现的格式：`severity\|file\|issue` 单行，总量 ≤800 字节。来自 `l3-prompt-loop-fix` |
| 归档布局解析（archive-layout resolution） | artifacts_dir 为 `.specs/archive/<id>/` 形态时 project_root 必须解析到仓库根（`dirname ×3` 或等价逻辑），保证项目级 CHANGELOG/LESSONS 注入不失效。来自 `l3-prompt-loop-fix` |
<!-- l3-prompt-loop-fix 追加 ↑ -->

<!-- l3-review-defects-2026-09 追加 ↓ -->
| L3 段结束标记（L3 section end marker） | 写入方在 L3 段尾落 `<!-- /L3-SECTION -->`，删除侧据此精确切分，取代"碰到下一个二级标题"的隐式边界；无标记的历史工件回落原标题法。定义在 `hooks/stop/lib/l3-section.sh`。来自 `l3-review-defects-2026-09` |
| L2 结论锚定提取（anchored L2 verdict extraction） | 只在**行首锚定**的 `Verdict:` 行取 L2 结论（容忍列表符/标题符/粗体前缀，排除 JSON 引号键），取最后一轮并归一为小写。免疫 L3 段 JSON 与主 agent 的散文复述。来自 `l3-review-defects-2026-09` |
| 工件上限单位（artifact cap unit） | 配置键 `independent_review.max_artifact_bytes` 的单位是**字节**（实现为 `head -c`），CJK 按 ÷3 估算汉字数（60000 字节 ≈ 2 万汉字）。旧键 `max_artifact_chars` 保留兼容读取并打印 DEPRECATED。来自 `l3-review-defects-2026-09` |
| 副本漂移检测（hooks copy drift check） | 以 `flow-kit-bundle/hooks/` 为唯一源，比对 6 处已存在安装副本的 install 集**内容**一致性；`make check-hooks-sync` 纳入 `make check` 门禁。来自 `l3-review-defects-2026-09` |
<!-- l3-review-defects-2026-09 追加 ↑ -->

<!-- health-fix-2026-09b 追加 ↓ -->
| 前向脱敏（forward scrubbing） | 对**今后新增内容**的脱敏（相对"历史清理"）。关键性质：它**无法靠一次性人工动作达成**，必须配机器门禁，否则随新提交持续回归 |
| 权威验证（authoritative verification） | **仓库级**判据 —— 扫全部对象（`git cat-file --batch-all-objects`）而非抽样某分支。本仓口径见 `HISTORY-REWRITE-FULL.md:120`。反例：只看 `origin/*` 会漏掉本地孤儿分支，得出"已清干净"的错误结论 |
| 假绿（false green） | 测试/门禁**通过但无判定力**。四种已知形态：① 恒真断言（接受除某值外一切结果）；② mock 自证（文件内自建被测逻辑）；③ 容忍失败（`-ne 2` 这类"只要不是脚本错误就算过"）；④ **计数比较语义盲**（两张不同的表行数相同即通过） |
| 假红（false red） | 门禁因**判据错误**而永久失败。危害：训练使用者忽略该告警，真问题出现时无人看。比"没有门禁"更难发现 |
| mock 自证（mock-as-SUT） | 测试文件内自行定义被测逻辑（从不 source 生产实现）。**证伪手法**：把测试文件单独拷到 `/tmp`（仓库不可达）运行 —— 仍全绿即为 mock 自证；**必须同时跑一个真依赖仓库的对照组**（应失败） |
| 加固不一致（inconsistent hardening） | 同一函数对**一处**敏感数据做了防护（如请求体改走 stdin）却漏了**另一处**（如凭证 header 仍走 argv）。因"已加固"的印象而更难被 review 发现 |
| 先截断后执行（truncate-before-exec） | `cmd > file` 的 `>` 在 `cmd` **执行前**就清空 `file`。与"工具缺失"叠加即：安装器在缺 jq 时把用户 `settings.json` 静默截断为 0 字节 |
<!-- health-fix-2026-09b 追加 ↑ -->

## 已锁决策

- `[2026-09-20]` **门禁只保证"看不见的变可见"，不改变红绿语义** — `make lint` 扩面扫全部生产脚本后，**error 级门禁语义保持不变（仍只拦 error）**，warning 池（含 21 处 SC1090 动态 source 等 known-acceptable）不升级为 fail。理由：把 known-acceptable 升级为 fail 会让门禁长期红 → 被绕过 → 可信度归零，比没有更糟（承接 TD-023 既定判定）。来自 `health-fix-2026-09` 阶段 1
- `[2026-09-20]` **dist 打包件新鲜度** — 改了 `dsh-flow-kit/README.md`、`dsh-flow-kit/lib/`、或 `flow-kit-bundle/`（hooks/prompts/skills/config）任一内容后，**必须重跑 `package-dsh-plugin.sh` 重建 `dist/`**。理由：`dist/` 被 gitignore（git 看不见它陈旧），`sync-hooks --check` 只比 hooks 不比包顶层文档，`make check` 也不覆盖 —— 2026-09-20 巡检因此漏判一次：dist 的 README 落后源码 7 天，把工件上限的「字符」写成「字节」（用户按旧文档配 60000 预期 6 万汉字、实得 2 万汉字，差 3 倍）。安装为 `file:` 实体拷贝（非 symlink），dist 变更**不自动生效**，需重装 profile。来自 `M-health 2026-09-20 全量扫描`
- `[2026-09-03]` L2/L3 模型解析链加入站点级默认 tier——L3: `ANTHROPIC_DEFAULT_HAIKU_MODEL > FLOW_KIT_L3_MODEL > goal.l3_model > FLOW_KIT_L3_DEFAULT_MODEL > goal.l3_default_model`（L2 对称）。语义：显式永远压过默认；默认模型不改变无凭证跳过语义（凭证由 fk_resolve_api_credentials 独立判定）。不设硬编码模型名——用户 CC/opencode 均为自定义网关，模型目录站点相关。配置面：`/flow model l3-default=<m>` 持久化或 export env。来自 `l3-default-model`（mini change）
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
- `[2026-07-09]` jscpd 重复率扫描约定工具化为 `make dup` target（带 `--ignore brooks-lint/brooks-tools/test/regression-demos`），独立于 `make check`（非硬门禁 · jscpd 未装 graceful skip）—— TD-010 校准（原 CONTEXT「已纳入 SOP」实为假，只存在 health 报告文字里）。来自 `td-test-infra`
- `[2026-07-01]` 3/5/7 L2 默认 off —— gate-config `full` 预设仍只含 1/2/6，3/5/7 由用户显式开（数字简写 `1,2,3,5,6,7` 或新预设）。理由：避免 pipeline token 成本爆炸。来自 `gate-integrity`
- `[2026-07-02]` 独立审查四层架构确认 —— L2/L3 独立审查的完整性依赖四层同步：① PRESET_MAP ② Prompt 模板 ③ Hook 层 ④ L2-blind-review.md。gate-integrity 仅完成了 Hook 层 + PRESET_MAP `all` 预设；本次 independent-review-gap 补齐剩余三层。来自 `independent-review-gap`
- `[2026-07-03]` L3 同步调用策略（修复 F1 死锁）—— L3 API 调用从 Stop hook 移到 PreToolUse hook transition 拦截点作为主路径；Stop hook `29-independent-review.sh` 保留为兜底（处理 transition 前 session 异常终止的补跑场景）。抽取共享 lib `l3-review.sh` 消除两处重复。超时 30s + 降级为 `L3_verdict=timeout`（不阻塞 pipeline）。来自 `pipeline-fallback-fix`
- `[2026-07-03]` gate_config 快照一致性策略（修复 F2 死锁）—— `/flow gate-config` 和 `/flow goal --gate-config` 必须同时更新 `.flow-active.goal.gate_config` 和 `.specs/<id>/.goal-snapshot.json`。单一写入点原则：skill 层负责同步，hook 层 D8 ⑥ 只做检测不做修复。来自 `pipeline-fallback-fix`
- `[2026-07-07]` L2/L3 双层审查合并写入策略 —— 修复 L2/L3 因时序错位（L3 先于 L2 写 .done）+ 文件覆写（L2 Write 销毁 L3 段）导致审查信号丢失。三处修复点：① 29 号 hook gate_config="both" 时 L3 等待 L2 完成后才写 .done ② L2 prompt 改为追加写入（保留已有 L3 段）③ .done 仅在双方均完成时写入。来自 `dual-review-merge-fix`
- `[2026-07-07]` L3 反馈可见性策略 —— L3 审查结果必须在两条路径上对 agent 可见：PreToolUse transition 时同步展示 verdict+summary，SessionStart resume 时注入报告摘要。两条路径展示字段一致（verdict + summary + report path），格式差异仅限上下文适配。不改动 L3 内容生成逻辑、不新增 hook 模块。来自 `l3-feedback-visibility`
- `[2026-07-07]` review 发现→代码修复强制策略 — L2/L3 独立审查发现的源码级问题不能仅靠写文档解决。双层防线：① prompt 层「修代码优先」协议（每条发现→代码修复或技术债登记+理由）② hook 层实效性校验（纯文档 diff 阻断 gate transition）。仅对 5/6/7 阶段触发，不影响 1/2 阶段文档型产物。复用现有 gate-integrity + independent-review-gate 框架，不新增 hook 模块。来自 `l2-l3-fix-compliance`
<!-- A-evolve 2026-07-08 第1轮追加 ↓ -->
- `[2026-06-16]` 所有 shell 脚本常量命名规范 — `readonly UPPER_SNAKE_CASE`。来自 `health-fix`
- `[2026-06-29]` 归档完成自动清理工作目录 — 7-integration 归档后 rm -rf .specs/<id>/。来自 `lessons-cleanup`
- `[2026-06-29]` 1.8 恢复验证协议 — 4-dev 触发破坏性变更协议后自动执行 npx bats test/，0 fail 才放行。来自 `lessons-cleanup`
- `[2026-06-29]` 质量基础设施 — 协议共享机制（reference/pipeline-gates.md + check-gate-sync.sh）+ GNU Makefile（test/lint/check/all）+ shellcheck 静态分析（error 级别，-e SC1091）。来自 `quality-baseline`
- `[2026-07-01]` 独立 review 架构 — L2（prompt 固化子 agent 盲审）+ L3（PreToolUse + Stop hook 双层）的独立审查体系。功能默认关闭，bundle 源控制。来自 `independent-review`
- `[2026-07-01]` 阶段切换三道防线 — PreToolUse（硬拦截）+ fk_auto_phase（gate 判定）+ auto_advance（自动推进）。来自 `independent-review`
- `[2026-07-01]` user-scope hooks 统一 — hooks 只装 user scope（~/.claude/），项目级不接线。install.sh 仍支持两种模式。来自 `independent-review`
- `[2026-07-01]` Correction file 管理统一 — lib/correction-file.sh 作为唯一 correction file 读写入口（write/read/clear/exists 四函数）。来自 `sweep-fix-2026-07`
- `[2026-07-01]` 产物规则查表驱动 — declare -A PHASE_ARTIFACTS 关联数组替代硬编码分支。来自 `sweep-fix-2026-07`
- `[2026-07-01]` 所有生产 .sh 必须通过 bash -n 语法检查。来自 `health-fix-2026-07`
- `[2026-07-02]` 独立审查 prompt 段结构标准化 — gate 检测 → L2 模板 → L3 说明 → done 指令。新增阶段的独立审查段按此模板复制。来自 `independent-review-gap`
- `[2026-07-02]` PRESET_MAP 命名约定 — 单阶段=阶段名，组合=连字符。新增预设只能追加不能重命名。来自 `independent-review-gap`
<!-- A-evolve 2026-07-08 第2轮追加 ↓ -->
- `[2026-07-01]` .flow-active 完整性检测归属独立 33 号模块（非 28 号扩展）— token_spent v1 仅检测"是否维护"，不验证准确性。来自 `flow-active-integrity`
- `[2026-07-01]` .done KVP 强制格式 + gate 阶段判定动态读 gate_config + 校验 fail-close / path-guard fail-open。来自 `gate-integrity`
- `[2026-07-01]` PreToolUse matcher 覆盖 Bash+Write+Edit 三种工具调用（D7 path-guard）。来自 `gate-integrity`
- `[2026-07-01]` gate_config 值规范 — `L2` / `L3` / `both`（三值字符串），废弃 `independent`（保留读取兼容）。来自 `l2-l3-granular-gate`
- `[2026-07-01]` phase 检测统一入口 — `fk_resolve_phase()` 为唯一 phase 读取点，所有 hook 禁止直接 `jq -r '.phase'`。来自 `l3-comprehensive-fix`
- `[2026-07-01]` L2 检测共享 lib — `l2-detect.sh` 为 L2 状态检测唯一入口，禁止在 hook 中硬编码 L2 Agent 派发命令。来自 `l3-comprehensive-fix`
- `[2026-07-01]` L3 反馈统一格式 — `L3_RESULT: verdict=<v> summary=<s> report=<p>`，.done 序列化格式为 key=value（非 JSON）。来自 `l3-feedback-visibility`
- `[2026-07-03]` 阶段产物验证策略 — 双层防护（prompt PCSC 自检 + GO.md PCG 门禁），任一 ❌ 禁止进入 toll-gate。来自 `phase-skip-fix`
- `[2026-07-03]` L3 调用策略 — PreToolUse hook 为主路径，Stop hook 为兜底；gate 方向三向判定（回退放行/no-op放行/前进查 gate）。来自 `pipeline-fallback-fix`
- `[2026-07-03]` pipeline 回退下界动态 = start_phase（默认 4 兼容）；回退语义：退到 N 后移除 N 之后所有已完成阶段。来自 `pipeline-rollback-phase0`
- `[2026-07-10]` auto-checkpoint 双层防护 — prompt 指令 + PreToolUse hook 兜底（auto-checkpoint-hook change 实现）。去重策略：不启用（移除去重 · `checkpoint_dedup_check()` 和 `CHECKPOINT_DEDUP_WINDOW` 已删除）。推翻 `[2026-07-04]` 的 30s 去重窗口决定。checkpoint 写入必须通过 `checkpoint_write()` 函数。来自 `auto-checkpoint-hook`
<!-- A-evolve 2026-07-08 第2轮追加 ↑ -->
<!-- A-evolve 2026-07-08 第1轮追加 ↑ -->
<!-- refactor-independent-review-gate 追加 ↓ -->
- `[2026-07-08]` gate regex 统一"变量存 regex"风格（**本次 change 实施中 · 待 7-integration 标 ✅**）— independent-review-gate.sh 所有 `[[ =~ ]]` 将改用 `local re='...'; [[ "$x" =~ $re ]]`，杜绝 regex 内 `&&`/裸空格被 bash 当逻辑与/词法拆分（TD-011 根因 SC2157）。来自 `refactor-independent-review-gate`
<!-- refactor-independent-review-gate 追加 ↑ -->
<!-- checkpoint-polish 追加 ↓ -->
- `[2026-07-10]` BW01 banner 函数抽取目标 — `flow-kit-resume.sh` 的 banner 构建逻辑抽取为 sourceable 函数，放入 `flow-kit-bundle/hooks/session-start/lib/` 或 `flow-kit-bundle/lib/` 下，与现有 lib 组织一致。来自 `checkpoint-polish`
- `[2026-07-10]` BW02 CHANGELOG 格式统一方向 — `.specs/CHANGELOG.md` 统一为紧凑单行 pipe 格式（`| 日期 | change-id | 摘要 | LESSONS |`），与顶部新条目格式一致，不保留独立表头行。来自 `checkpoint-polish`
- `[2026-07-10]` BW03 双源测试同步方案 — 优先 Makefile target（`make test-sync`），备选 install.sh symlink；`make check` 集成不同步检测（非零退出）。来自 `checkpoint-polish`
<!-- checkpoint-polish 追加 ↑ -->
<!-- sweep-fix-2026-07-10 追加 ↓ -->
- `[2026-07-10]` `_grep` 保留决策：`_grep() { command grep "$@"; }`（`fix-compliance.sh:20`）是 Claude Code 运行时环境的防御性 shim。**证据**：宿主机 `ugrep` 未安装，GNU grep 3.11 正常，`grep -P` 可用；但 CC 运行时环境中 `grep` 被 alias 到 ugrep（不支持 `-P` Perl regex），`_grep` 通过 `command grep` 绕过此 alias。非死代码，保留不修改。来自 `sweep-fix-2026-07-10`
- `[2026-07-10]` `write_failed_state` 移除：全仓 0 调用确认死代码，已从 `common.sh` 移除（21 行定义 + 注释块）。来自 `sweep-fix-2026-07-10`
- `[2026-07-10]` `is_gh_pr_create()` 不拆分：3 行谓词函数（`independent-review-gate.sh:101-103`），单一职责清晰。TD-018 真实目标是同文件主逻辑体（L106-391，7 gate 检查块）。来自 `sweep-fix-2026-07-10`
- `[2026-07-10]` `run_check()` API 设计：`run_check MODULE CHECK_ID [PRECONDITION_FILE] BODY_FN`，4 参数回调模式。位于 `common.sh`，紧接 `check_enabled()`。消除 6 模块 30 处 `check_enabled` 模板重复。precondition 仅支持文件存在性检查（YAGNI）。来自 `sweep-fix-2026-07-10`
- `[2026-07-10]` `check_*_body` 命名约定：每个迁移后的 body 函数命名为 `check_<id>_body`（如 `check_c1_body`），与现有 `check_*` 前缀一致。来自 `sweep-fix-2026-07-10`
<!-- sweep-fix-2026-07-10 追加 ↑ -->
<!-- checkpoint-polish 追加 ↑ -->
<!-- health-fix-l3-2026-07 追加 ↓ -->
- `[2026-07-11]` L3 审计子系统健康修复 v1 范围 — 12 项代码质量修复分三批：🔴 Critical 3 项（函数拆分 `_gate_phase_transition`/`fk_fix_compliance_check` + 解环 correction-file↔UI↔compliance）、🟡 Warning 6 项（`smart_truncate`/`_l3_parse_result`/`_l3_build_prompt` 拆分 + DRY phase_name 映射 + DRY jq goal 解析 + timeout 测试补齐）、🟢 Suggestion 3 项（self-sourcing 修复 + 29 号 hook 函数化 + 死代码清理）。`l3_review_run()` 主函数 307 行 v1 不拆（仅拆其调用的子函数），留 v2 与 TD-008 一起处理。来自 `health-fix-l3-2026-07` Phase 1
<!-- health-fix-l3-2026-07 追加 ↑ -->
<!-- l3-pipeline-fix-2026-07 追加 ↓ -->
- `[2026-07-11]` L3 管线 5 项限制修复 v1 范围 — 一次性修复 L-040 的 5 项系统限制：① git diff 上限 5000→50000（或动态 token 估算）② diff 收集覆盖 untracked + staged ③ 智能截断改为头+尾保留 ④ 积压扫描补齐历史 L3 ⑤ L3 prompt 上下文注入。外加 Stop hook 性能优化 ≥30%。不改变 L3 API 调用方式、不新增 hook 模块、不改 gate_config schema。来自 `l3-pipeline-fix-2026-07`
<!-- l3-pipeline-fix-2026-07 追加 ↑ -->
<!-- superpowers-v6-absorb 追加 ↓ -->
- `[2026-08-02]` superpowers v6.0 经验吸收范围确认 —— G1-G10 全量大包，10 项优化（review 合并 / review-package + task-brief 脚本 / terse contract / narration / severity gating / progress ledger / model-tier / plan-conflict-scan / GO.md 压缩）。允许破坏性变更（.flow-active schema / TASK.md XML / gate_config）。来自 `superpowers-v6-absorb` Phase 0
- `[2026-08-02]` Cross-model spot-check 触发策略 —— Critical-finding 触发（不每次跑）。理由：spot-check 物理上是独立 subagent 调用，无法合并到 review 第一轮；但每次跑多花 ~10-15K tokens/change，仅 Critical 时触发可在 token 经济与安全之间平衡。来自 `superpowers-v6-absorb` Phase 1（用户选项）
- `[2026-08-02]` Token 测量协议 —— 结构性 + 参考性双轨。结构性 AC 是硬门槛（review 轮数 4→2 / 4-dev reload 34KB→≤15KB / GO.md 473→≤350 行），参考性 AC 跑一次 pre/post 样例作证（pipeline -25% / review -40% 不卡 toll-gate）。理由：superpowers 自报 50% 独立 benchmark 只复现 14-30%，端到端 token 测量误差大不适合做硬门槛。来自 `superpowers-v6-absorb` Phase 1（设计判断）
- `[2026-08-02]` task_progress 与 T<N>-SUMMARY.md 并存策略 —— 机器读实时 vs 人读事后，两者职责不重叠。task_progress = jq 友好、hook 自动写、固定 schema（id/commit_sha/fix_rounds/deferred/completed_at）。SUMMARY = markdown、4-dev 完成时写、自由格式（"做了什么/为什么/偏离 DESIGN 哪里"）。否决"合并为单一 PROGRESS.md"和"废弃 SUMMARY"两个方案。来自 `superpowers-v6-absorb` Phase 1（用户选项）
- `[2026-08-02]` 向后兼容契约 —— 旧 TASK.md（无 model-tier）→ fallback standard tier；旧 .flow-active（无 task_progress）→ 视为 []；旧 REVIEW.md（无 severity）→ 视为 Important。所有破坏性变更必须提供 fallback，否则既有用户的 pipeline 会死锁。来自 `superpowers-v6-absorb` Phase 1
<!-- superpowers-v6-absorb 追加 ↑ -->

<!-- l3-prompt-loop-fix 追加 ↓ -->
- `[2026-09-04]` L3 重审 prompt 必须携带前轮反馈 — 单行摘要粒度（`severity|file|issue`，总量 ≤800B）；前轮审查文件无「## 主 agent 响应」段时仍注入发现摘要并显式标注「主 agent 未响应」；反馈段注入顺序优先于 7 文件工件正文（反馈优先截断立场）。用户已在 1-requirement 反问中确认两项粒度决策。来自 `l3-prompt-loop-fix`
<!-- l3-prompt-loop-fix 追加 ↑ -->

<!-- l3-review-defects-2026-09 追加 ↓ -->
- `[2026-09-18]` **L2_verdict 取值语义 = L2 审查员原文结论**，不取主 agent 修复后的复述 —— 依据 `flow-kit/prompts/independent/L2-blind-review.md:142`「主 agent **无权修改你的原文判断**」。关键事实：该值只用于**审计记录 + 值域/一致性校验**，**任何调用点都不要求它等于 `pass`**（阶段放行由 L3 verdict 决定）。故这一取舍只影响审计记录准确性，不影响门禁行为。来自 `l3-review-defects-2026-09`
- `[2026-09-18]` **工件上限选"改名"而非"改按字符截断"** —— 截断的真实目的是控制发给外部模型的字节/Token 量；改成按字符裁会让 CJK 工件的请求体最多膨胀 3 倍，重新引入超限风险。故让名字服从实现（`max_artifact_bytes`）+ 旧键兼容读取 + 文档写明单位与 ÷3 换算。否决"按字符截断"与"仅在文档里说明"两个方案。来自 `l3-review-defects-2026-09`
- `[2026-09-18]` **副本同步工具只管内容、不改权限** —— 可执行位归 `install_hooks.sh` 的既有契约（只对 `stop/<module>.sh`、`session-start/*.sh`、`pre-tool-use/*.sh` 做 `chmod +x`）。理由：同步顺手改权限会搅出与修复无关的 mode 变更、淹没真正的 diff。`sync-hooks.sh` 对缺失 `+x` 只做只读提示。来自 `l3-review-defects-2026-09`
<!-- l3-review-defects-2026-09 追加 ↑ -->

<!-- health-fix-2026-09b 追加 ↓ -->
- `[2026-09-22]` **隐私"安全网"不得重建**（`git bundle` / `refs/backup/*` / 远端旧历史）—— 依据 `HISTORY-REWRITE-FULL.md:104`（强推确认后应删除）+ `LESSONS` **L-110 ③**（"安全网自己就是最大的泄露面"）。**重建等于把泄露面请回来**，已在 REQUIREMENT 的 out 段永久锁定
- `[2026-09-22]` **门禁判据必须比「内容/结构」，禁止只比计数** —— 纯计数比较**语义盲**：实测 `4-dev.md`(8 行) vs `flow-dev/SKILL.md`(8 行) 是**两张不同的表**，行数相同即通过。故"只修判据正则"会把**假红换成假绿**（红灯会被人修，绿灯会永远藏住漂移）。**处置顺序固定为：先修判据语义 → 再锁定唯一语义源 → 最后才扩覆盖**
- ~~`[2026-09-22]` **PCSC 表的唯一语义源 = `flow-kit/reference/pipeline-gates.md`**~~ → **⛔ 本条已撤回（依据被 L2 盲审证伪，同日更正）**。
  **误读点**：初版引 `reference/phase-prompt-template.md:143` 的"✅ **已抽取**"作依据，但**紧邻的 `:144` 明写**
  「⚠️ **结构性文档化（不抽取）**：**PCSC 表格** / 独立 review 调度 —— phase-specific 内容占比高，
  抽取反而增加复杂度」，`:145` 的方向也是**参数化 PCSC 表**而非单源化。
  即 `:143` 的"已抽取"指的是 **Toll-gate 协议**（确实抽到 `pipeline-gates.md`），**不含 PCSC 表**。
  **更正后立场**：① **PCSC 表逐 phase 内容本就不应相同**（17 个载体），
  **不得**作为「应逐字一致」的比较对象；② 门禁的漂移比较对 `(P,S)` 由 **DESIGN 定义**，
  须满足「两侧本应逐字一致」（合规候选：`sync-hooks.sh:57-62` 已枚举的镜像面）；
  ③ 教训已固化为 **L-117**
- `[2026-09-22]` **本地 `main` 暂不清理，只加 push 拦截** —— 用户决策（零破坏优先）。**已知代价**：`HISTORY-REWRITE-FULL.md:120` 的权威验证（对象库期望 0）将持续为 **8**；"8→0"归 v2。该残留**不是遗漏**，已在 REQUIREMENT「已知未闭环项」显式登记，**禁止当成 bug 重报**
- `[2026-09-22]` **`~` 展开永不使用 `eval`** —— 一律用参数展开 `${var/#\~/$HOME}`。起因：`runtime-edit-guard.sh:46` 的 `eval` 构成**已复现的任意代码执行**（载荷可控，且位于所有 gate 判定之前、每次 Write/Edit 都触发）。附则：`grep -rn '\beval\b' <被守护代码>` 应成为安全门禁的固定检查项
- `[2026-09-22]` **审计判定"缺失/失效"前，先搜本仓 LESSONS/CONTEXT 排除「有意移除」** —— 依据 **L-116**（本轮把按设计删除的三处隐私安全网初判为缺陷，查 `:104` + L-110 ③ 后下调为 🟢）。定式：`grep -rn <对象名> .specs/LESSONS.md .specs/CONTEXT.md` 先行；关键结论尽量回溯本仓既有记录，而非只凭当前快照推断
- `[2026-09-22]` **AC 必须在写需求时实跑一次并确认"修复前不成立"** —— 沿用 **L-090**。本轮 8 条 AC 全部预检留档（见 REQUIREMENT「修复前实测行为」表），并借此暴露一处范围张力（AC-3 拦截 vs 权威验证 8→0 不可同时属 v1），已如实切分 v1/v2
<!-- health-fix-2026-09b 追加 ↑ -->

## 默认偏好（AI 在缺省时按此决策）

- 命名风格：Shell 脚本遵循 `kebab-case` 命名（如 `package-flow-kit.sh`、`flow-kit-ecosystem-guide.md`）
- 错误处理：Bash 脚本使用 `set -euo pipefail`（`package-flow-kit.sh:3`）
- 状态管理：无（非前端/后端项目）
- 测试策略：bats-core 1.13.0（npx）· 94 个测试（截至 2026-06-25）。weak-model-robustness change 将追加弱模型护栏结构测试（见该 change REQUIREMENT AC-1/3/5）
- 提交格式：Conventional Commits — `feat:` / `fix:` / `docs:` / `chore:` / `refactor:`；禁止 force push 到 main
- gate regex 风格：新增 `[[ =~ ]]` 检测默认用"变量存 regex"（`local re='...'; [[ "$x" =~ $re ]]`），禁止内联含 `&&`/裸空格的 regex（TD-011 教训）

## 既有抽象索引（来自 I-intel-scan · 防 AI 重复实现 · B5 老项目护栏）

> intel-scan 自动 grep 出来的项目级抽象。每个 change 4-dev 1.4 步骤会查这里。

### 工具函数（utils / helpers）

| 工具类型 | 路径 | 入口符号 |
|---|---|---|
| 日期 | `未发现` | — |
| 字符串 | `未发现` | — |
| 校验 | `未发现` | — |
| 存储 | `未发现` | — |
| 错误 | `未发现` | — |

> 注：`package-flow-kit.sh` 内含内联辅助函数（`install_file()`、`check_command()` 等），但未抽取为独立工具库。

### flow-kit 核心抽象（来自 A-evolve 2026-07-08 第1轮）

| 路径 | 能力 | 来源 |
|---|---|---|
| `flow-kit-bundle/install.sh --user` 模式 | user-scope 安装 + symlink 创建 | user-scope-install |
| `flow-kit-bundle/lib/install_core.sh` | flow-kit 核心安装逻辑 | health-fix |
| `flow-kit-bundle/lib/install_brooks_tools.sh` | npm 工具离线安装通用函数 | bundle-packaging |
| `.flow-active` goal 字段 + `/flow goal` 子命令 | session 级完成条件持久化与生命周期管理 | integrate-goal-command |
| `package-flow-kit.sh::validate_staging_coverage()` | 打包 staging 目录完整性校验 | lessons-cleanup |
| `flow-kit/reference/pipeline-gates.md` + `check-gate-sync.sh` | toll-gate 协议共享片段 + 漂移检测 | quality-baseline |
| `Makefile` | 一键质量检查（test/lint/check/all） | quality-baseline |
| `hooks/stop/lib/weak-model-compliance.sh` | L1/L2/L3 合规扫描函数库 | robustness-hook-hardening |
| `.flow-active.correction` JSON 格式 | 统一矫正文件（type+layer+violations） | robustness-hook-hardening |
| `hooks/stop/lib/correction-file.sh` | 通用 JSON correction file 管理（write/read/clear/exists） | sweep-fix-2026-07 |
| `common.sh::HOOK_MODULE_NAMES` | hook 模块名单一来源数组（14 元素） | sweep-fix-2026-07 |
| `prompts/*` 自检 gate 填空模板范式 | 强制填空才能产出的刚性结构 | weak-model-robustness |
| `regression-demos/<scenario>/check.sh` 范式 | 可重复执行的行为验收脚本 | weak-model-robustness |
| `test/` bats-core 测试目录结构 | Bash 脚本测试标准目录 | health-fix |
| `fk_independent_review_gate_active()` | 独立 review gate 判定（`write_failed_state()` 已确认死代码 · 2026-07-10 sweep · 待清理） | independent-review |
<!-- A-evolve 2026-07-08 第2轮追加 ↓ -->
| `hooks/stop/33-flow-active-integrity.sh` | .flow-active 字段与磁盘产物交叉验证 | flow-active-integrity |
| `fk_validate_done_marker` | .done 真实性校验（两层） | gate-integrity |
| `is_handshake_write` + `fk_check_gate_config_tamper` | Bash 写保护路径检测 + gate_config 篡改检测 | gate-integrity |
| `hooks/stop/lib/fix-compliance.sh` | 实效性校验（源码分类+纯文档diff检测+逐发现校验） | l2-l3-fix-compliance |
| `fk_independent_review_gate_active <phase> [tier]` | 按 tier 判定独立审查开关（L2/L3/any） | l2-l3-granular-gate |
| `hooks/stop/lib/l2-detect.sh` | L2 审查完成状态检测 + 一键派发命令生成 | l3-comprehensive-fix |
| `lib/common.sh::fk_resolve_phase()` | pipeline-aware phase 解析（统一 .phase vs .goal.current_phase） | l3-comprehensive-fix |
| `l3-review.sh::_l3_format_result()` | 统一格式化 L3 反馈输出行 | l3-feedback-visibility |
| `flow-kit-bundle/skills/flow/SKILL.md generate_gates()` | 根据 start_phase 动态生成 pipeline gates | goal-pipeline-phase0 |
| `l3-review.sh::l3_review_run()` | L3 外部模型 API 调用封装 | pipeline-fallback-fix |
| `checkpoint-lib.sh` | auto-checkpoint 写入 + 去重 + 校验 | user-guide-update |
| `27-interactive-ui-check.sh` + `interactive-ui-check.sh` | Stop hook 交互 UI 检测 + 矫正 | weak-model-interactive-ui |
| `flow-kit/reference/interactive-ui-guard.md` | Prompt 层护栏模板（≤3 行/点） | weak-model-interactive-ui |
| 5/6/7 prompt「失败分类→回退目标」映射表 | 按失败类型智能建议回退阶段 | pipeline-rollback-phase0 |
| `.flow-active.goal` 扩展 schema（7 新字段） | Pipeline 状态管理（scope/current_phase/phases_done/gates/gate_config/auto_advance/phase_sub_goals） | pipeline-goal |
| Toll-gate 暂停协议 | Prompt 级指令控制 AI 在特定节点停止等待用户确认 | pipeline-goal |
<!-- A-evolve 2026-07-08 第2轮追加 ↑ -->

### 错误处理

- **前端**：不适用
- **后端**：不适用
- **Shell**：`set -euo pipefail`（`package-flow-kit.sh:3`）— 遇错即停，无自定义 error handler

### 命名约定

#### 文件命名

- 文件命名：`kebab-case`（`package-flow-kit.sh`、`flow-kit-ecosystem-guide.md`）

#### 函数命名前缀（来自 `sweep-fix-2026-07-10`）

| 前缀 | 含义 | 可见性 | 使用场景 |
|---|---|---|---|
| `fk_` | flow-kit 公共 API | 跨文件可调用 | 被多个模块/脚本调用的导出函数（如 `fk_resolve_phase`） |
| `_fk_` | flow-kit 模块私有 | 文件内可见 | 当前文件内部辅助函数（如 `_fk_phase_direction`） |
| `check_` | hook check 入口 | 模块内 | Stop hook 检查入口，统一通过 `run_check()` 调用（如 `check_c1`） |
| `l2_` / `_l2_` | L2 审查 | 跨文件 / 文件内 | L2 审查检测/派发函数 |
| `l3_` / `_l3_` | L3 审查 | 跨文件 / 文件内 | L3 审查 API/派发（`l3_review_run`）+ 子步骤（`_l3_build_prompt`） |
| `_gate_` | Gate 检查步骤 | `independent-review-gate.sh` 内部 | 独立 gate 检查步骤函数（如 `_gate_path_guard`） |
| `_fai_` | (遗留，待统一) | 文件内 | 旧 `flow-kit-artifacts.sh` 内部函数，v2 统一为 `_fk_` |

- 函数命名：`snake_case`（`install_file()`、`check_command()`、`install_flow_kit_core()` — 来自 `package-flow-kit.sh`）
- 组件命名：不适用
- 测试文件：`test/` 目录下 `.bats` 文件，命名 `test_<target>.bats`

### 禁动清单（AI 不许"顺手"碰）

> 这些是与新 change 通常无关、改坏会出事的高风险模块。每个 change 的 DESIGN 0.5.1 会复用这清单。

- `package-flow-kit.sh`（打包脚本核心逻辑，改动影响分发流程）
  - **例外（superpowers-v6-absorb · 2026-08-02）**：Part D 允许新增 `scripts/` 到 cp 清单（仅本 change 一次性例外，后续 change 仍按原禁动）
  - **例外（l2l3-cross-platform · 2026-08-06）**：Part A 覆盖范围允许新增 `.opencode/agent/` 打包点（agent 文件放 `flow-kit/` 下随 Part A rsync；仅本 change 一次性例外，后续 change 仍按原禁动）
- `flow-kit-bundle.tar.gz`（已生成的分发包，`.gitignore` 排除，不应手动修改或 git add）
- `.gitignore`（手动维护；禁 AI "顺手重写"或增删排除规则）
<!-- A-evolve 2026-07-08 第1轮追加 ↓ -->
- `package-flow-kit.sh` Part F L504-530（brooks-lint 打包段）— 仅 Part F 可改；Part A-E/G 禁顺手改
- `flow-kit-bundle/lib/install_*.sh` — 不允许外部直接 source（仅 install.sh 主脚本可 source）
- `test/` 目录 — 不允许放入非 .bats 文件
- `.flow-active.goal` 字段 — 不允许手动编辑，必须通过 /flow goal 子命令操作
- `~/.claude/tools/brooks-lint/node_modules/` — 不允许手动修改（install --reinstall 会覆盖）
- `~/.local/bin/{depcheck,jscpd,knip,ts-prune}` shim — 不允许手动编辑（由 install.sh 管理）
- `package-flow-kit.sh` Part G 工具版本号 — 不允许单方面改动（需和 brooks-lint 版本绑动）
- RULES.md R6/R3/R7「弱模型加固子段」— 标注「勿删」，移除前需评估对弱模型的影响
- `regression-demos/*/check.sh` — 勿在未同步更新预期的情况下修改
- `fk_auto_phase()` gate 检查段 — 修改需理解三道防线覆盖的推进路径
- `hooks/stop/lib/correction-file.sh` 4 函数签名 — 修改需同步更新 interactive-ui-check.sh + weak-model-compliance.sh
- `common.sh::HOOK_MODULE_NAMES` 数组 — 修改需同步 install_hooks.sh + package-flow-kit.sh
- `L2-blind-review.md` checklist 条目 — 禁止降级为纯文本段落（保持四要素+严重度结构）
- PRESET_MAP 预设名 — 一旦发布禁止改名，只能追加新预设
<!-- A-evolve 2026-07-08 第2轮追加 ↓ -->
- `33-flow-active-integrity.sh` — 后续不应被无关 change 修改（.flow-active 完整性检测模块）
- `independent-review-gate.sh` + `29-independent-review.sh` + `fk_validate_done_marker` — gate 校验核心链
  - **例外（cleanup-debt-batch-2026-08 · L-072 fix · 2026-08-03）**：`29-independent-review.sh` 允许重排 L58-65（L3 model check）与 L181-185（L2-missing detection）的位置——L2 detection 移到 L3 check 之前，防 model-missing exit 3 短路 L2 detection。仅本次 change 范围内允许，重排后 L2 detection 块在新位置仍受保护。
- `install_hooks.sh` PreToolUse matcher — 改回仅 Bash = D7 path-guard 失效
- `.specs/<id>/.goal-snapshot.json` — ⑥ 检测载体，改坏 = gate_config 篡改检测失效
- `check-gate-sync.sh` set-diff 逻辑 — 改回文本段 diff = PRESET_MAP 漂移无兜底
- `independent-review-gate.sh` 校验顺序 — 真实性→实效性→放行，不允许在中间插入其他逻辑
- gate_config 值 — 不允许写入 `independent`（已废弃），新代码必须写 `both`
- 禁止直接 `jq -r '.phase'` 读取阶段 — 用 `fk_resolve_phase()` 替代
- 禁止在 hook 中硬编码 L2 Agent 派发命令 — 用 `l2-detect.sh` 生成
- `l3-review.sh` — 不允许绕过直接调 curl API（必须走 `l3_review_run()` 封装）
- `.independent-review-<N>.done` — 仅 `l3_review_run()`（PreToolUse/Stop hook）有写权限
- `checkpoint-lib.sh` — 不允许绕过直接 jq write `.flow-active.interrupt`（必须通过 `checkpoint_write()`）
- `interactive-ui-check.sh` — 不允许绕过直接修改 GATE_MAP 以外的矫正逻辑
<!-- A-evolve 2026-07-08 第2轮追加 ↑ -->
<!-- A-evolve 2026-07-08 第1轮追加 ↑ -->

**清理窗口专列**（上次清理：`health-fix-l3-2026-07` · 2026-07-11 · 3 条目已移除）：
（空——无待清理项）

### 技术债（来自 M-health · 给 AI 在 2-design / 4-dev 时参考，别再加同类债）

> 只记 🟡 Scheduled 和 🟡 🔴 未处理项。🔴 Critical 已通过 health-fix CHANGE 处理中，不在此列。

| # | 严重度 | 位置 | 问题 | 建议 | 来源 |
|---|---|---|---|---|---|
| TD-002 | ✅ | `flow-kit-bundle/hooks/stop/` + `lib/` | **核心 hook lib 已覆盖**（`flow-kit-artifacts.sh` 由 test_flow_artifacts 22 tests 覆盖、common 由 test_common 21 tests 覆盖）；stop 链主脚本全部 smoke 覆盖 | ✅ 已完成（td-test-infra · 2026-07-10 + test-coverage-gap-2026-08）：test_stop_chain 已覆盖 00/01/20/21/22/23/24/25/26/27/28/29/30/33/99 全部 15 个模块 smoke；test_flow_artifacts 补 fk_auto_phase（6 tests）+ fk_boundary_check（4 tests）unit 覆盖；详见 `.specs/td-test-infra/SUMMARY.md`| `M-health 2026-06-20` · 校准 `M-health 2026-06-24`（测试 43→94）· 闭合于 `test-coverage-gap-2026-08`（688/688）|
| TD-003 | ✅ | `flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md` 入场 jq | `--from 0` pipeline 扩展时，4-dev.md + GO.md 已加 `start_phase` 读取，但这三个 prompt 仍是 `current_phase // "4"`（漏改）。实际影响低（current_phase 字段在 transition 时已正确更新，fallback 不触发），但一致性应补齐 | 统一三个 prompt 入场 jq 为 `current_phase // .start_phase // "4"` | `M-health 2026-06-20`（goal-pipeline-phase0 遗留）· **已修复 `0601dda`** · bats 77/78/79 验证（`M-health 2026-06-24` 复核）|
| L-004 | ✅ | `flow-kit-bundle/hooks/stop/lib/common.sh` | ~~共享函数 < 3 阈值，utils.sh 推迟~~ → ✅ obsolete：common.sh 已是 de facto utils.sh（18 functions，含 run_check / fk_resolve_phase / HOOK_MODULE_NAMES 等通用 helper）。原始触发条件「date/string/validate/store/error 通用 helpers」未实现——项目用 bash 内建 + jq 即可，无需求。决议：不再建 utils.sh，common.sh 承担该职责。 | ✅ obsolete（common.sh 承担） | `init-git-repo` T03 · resolved 2026-08-04 |
| TD-004 | ✅ | `flow-kit-bundle/flow-kit/prompts/*.md`（15+ 文件） | ~~Markdown prompt 样板重复率 22%~~ → ✅ resolved by `debt-audit-resolve-2026-08`（2026-08-04）：结构性重复而非逐字重复。已抽取：toll-gate（pipeline-gates.md）/ goal 解析（goal-parsing.md）/ commit（commit-protocol.md）/ TDD（tdd-workflow.md）。剩余结构性段（PCSC 表 / 独立 review 调度）已文档化于 `reference/phase-prompt-template.md`，因 phase-specific 内容占比高不强行抽取。 | ✅ 结构性文档化 | `M-health 2026-07-02` · resolved 2026-08-04 |
| TD-005 | ✅ | `flow-kit-bundle/flow-kit/prompts/6-review.md` + `7-integration.md` | ~~jq pipeline goal 解析重复~~ → ✅ resolved：已抽取到 `flow-kit/reference/goal-parsing.md`，两个 prompt 通过 @see 引用。 | ✅ 已完成（goal-parsing.md） | `M-health 2026-07-04` · resolved 2026-08-04 |
| TD-006 | ✅ | `.specs/l2-l3-fix-compliance/` + `.specs/independent-review-gap/` | 代码已合入但 spec 工件缺失 | 已归档（archive/ 下）· **`M-health 2026-07-08` 复核：active 目录为空，工件已补齐** | `M-health 2026-07-07` · resolved 2026-07-08 |
| TD-007 | ✅ | `test/` 根目录 | 7 个 untracked bats 文件 | 已清理（`e2a8bf2`）· **`M-health 2026-07-08` 复核：test/ 仅剩 .bats + fixtures/regression-demos/weak-model-robustness，根目录无散落非测试文件** | `M-health 2026-07-07` · resolved 2026-07-08 |
| TD-008 | ✅ | `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（574 行 / 6 函数） | ~~当前最大 lib，承担 L3 审查的**检测 + 派发 + 截断**多职责~~ | ~~按职责拆为 `l3-detect.sh` / `l3-dispatch.sh` / `l3-truncate.sh` 三子库~~ | ✅ Resolved (final-debt-cleanup-2026-08): split 875→5 files (l3-prompt 154 / l3-api 371 / l3-truncate 53 / l3-done 98 / l3-review slim 239) | `M-health 2026-07-08` |
| TD-009 | ✅ | `transcript-parser.sh:130` + `interactive-ui-check.sh:199` + `common.sh:163` | 3 个未引用函数：`estimate_tokens`（全仓零引用·真死代码）/ `read_correction_file`（生产无调用·疑似废弃）/ `file_not_empty`（仅测试用·待确认公共 API） | `estimate_tokens` 直接删；`read_correction_file` 确认废弃后删；`file_not_empty` 确认是否保留 common.sh API（R6）。✅ 已清理 2026-07-09：`file_not_empty` 删（定义+3 test 双源）；`estimate_tokens`/`read_correction_file` 前序已不在（本条描述过时）| `M-health 2026-07-08` |
| TD-010 | ✅ | jscpd 扫描约定 | flow-kit-bundle/ 含打包进来的第三方 brooks-lint/brooks-tools，jscpd 默认会扫到 → 重复率虚高（0.91%）；排除后才反映自有代码（0.58%） | jscpd 命令固定带 `--ignore '**/brooks-lint/**,**/brooks-tools/**,**/test/**,**/regression-demos/**'`；已固化为 `make dup` target（td-test-infra · 2026-07-10 · TD-010 fix）：`jscpd --ignore brooks-lint/brooks-tools/test/regression-demos`，独立 target 不进 `make check`，未装 graceful skip | `M-health 2026-07-08` |
| TD-011 | ✅ | `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:68` | `is_phase_write` 的 `[[ "$c" =~ \.tmp...&&...mv ]]` 里 `&&` 被 bash `[[ ]]` 当**逻辑与**，正则劈两半 → 实际仅匹配 `.tmp+空格`，`&&`/`mv` 检测失效（SC1026/2203/2157 always true）。gate 核心链（禁动清单 · independent-review-gate.sh 核心链 + 校验顺序条目 · 内容锚定）。本次加 `# shellcheck disable` + TODO 标注，未改逻辑 | **复核降级 🔴→🟡**：`refactor-independent-review-gate` 经 4 轮 L2（INDEPENDENT-REVIEW-2）实测 L69 单独**无 gate 行为后果**（完整函数 L73-75 决定返回值），仅 SC2157 lint + 意图损坏。L69 修复由 TD-014 对应 change 顺手清。**原 change 重新分层**为 discovery，拆为 TD-013/014/015 | `health-cleanup-2026-07-08` 发现 · `refactor-independent-review-gate` discovery 复核降级 |
| TD-012 | ✅ | `test/` 10+ 测试文件 setup 路径 | setup 路径缺 `flow-kit-bundle/` 层（如 `$(dirname "$BATS_TEST_FILENAME")/../hooks/...` 指向不存在的 `<repo>/hooks/`）→ `source ... 2>/dev/null \|\| true` 静默吞错 → `fk_validate_done_marker` 等函数未定义 → 30+ 测试 BW01 127 fail（假绿）。L-025 同源不同变种。**health-fix-2026-07-08 的"169→0"验证疑用 `bats\|tail`（管道吃 exit code）误判全绿** | 修 10+ 文件 setup 路径 + 修 Makefile test target 管道 exit code 漏洞（`bats\|tail`→bats 直接判 exit）+ 让 30+ 测试真绿；独立 change `test-setup-path-fix-2026-07` 处理 · **已修复 `62548da`（change 已归档）· resolved 2026-07-09 · `make test` 实测 407 ok / exit 0** | `health-cleanup-2026-07-08` 发现 |
| TD-013 | ✅ | `test/test_gate_integrity.bats` setup | ~~setup line 30 `set +e`~~ 已修。**v1 修复完成（fix-gate-test-setup）**：setup 去 set+e + 补 HOOK_BASE_DIR（让 fk_validate_done_marker 加载）+ helper 补 artifacts= KVP + 17 条测试体改 run+$status + 范围外 skip 归因。bats 18ok/5skip/0fail · make test 407 全绿 · 反向断言有效。揭示的 TD-016（断言债）+ TD-014（is_phase_write）由独立 change 处理 | ✅ 已完成（fix-gate-test-setup · 2026-07-09）| `refactor-independent-review-gate` discovery · INDEPENDENT-REVIEW-2 F2 · 修复证据 DEV-SUMMARY |
| TD-014 | ✅ | `independent-review-gate.sh:73-75` | is_phase_write L73-75 regex `\.flow-active.*\.phase=` 要求 .flow-active 在字段名前，但典型 jq 命令 `jq '.phase=5' .flow-active` 字段名在前 → **L73-75 从不匹配 → is_phase_write 对所有真实 jq phase-write 漏检（rc=1）→ gate phase-transition 检测对 jq 完全失效**（仅 git commit/gh pr create 兜底）。**严重安全隐患**（phase 可绕过 independent review）。sandbox 修复版（去 `.flow-active.*` 前缀）验证恢复检测 | 去 `.flow-active.*` 前缀（L67 已保证 .flow-active 涉及，L73-75 只测字段名）+ D10 测试修正 + 全量回归。专注独立 change `fix-gate-phase-detection`（③）。**✅ 已完成 2026-07-09**：去 `.flow-active.*` 前缀（L73-75）+ D10 两处去 skip（假绿挂起转真跑）+ `bats test/` 407 全绿 / exit 0。**设计依据**：归档 `refactor-independent-review-gate/DESIGN.md` v5 D6 + sandbox 验证 | `refactor-independent-review-gate` discovery · INDEPENDENT-REVIEW-2 F2(轮2) |
| TD-015 | ✅ | `independent-review-gate.sh:30,71` | `\>[^=]` 在 is_handshake_write L30 + is_phase_write L71。**内联 `\>[^=]` 是字面 >**（正常），但**变量化 `re='\>[^=]'` 触发 GNU 单词边界**（任何含字母命令误判 redirect）→ 纯读误判。D2 全文件治理（变量化）必触发。bash 转义差异 | 变量化时用 `[>][^=]` 字符类。TD-014 change ③ 顺手修（L30+L71）。**LESSONS 必记**：内联 vs 变量 regex 行为差异（`\<`/`\>` 类） | `refactor-independent-review-gate` discovery · INDEPENDENT-REVIEW-2 第三轮 Critical1 |
| TD-016 | ✅ | `test/test_gate_integrity.bats` AC-3 #11/#12 + AC-6 #23 | 测试断言实现含某些内容（artifacts.sh 含 `^(1\|2\|3\|5\|6\|7)$` 正则 + `"3-task"` case 串 / F29 含 `sha256sum`），**实测实现均不含** → 测试断言与实现长期不符，set+e 假绿掩盖（断言了不存在的东西）。属测试断言债 | 重新裁定断言真值：修实现补内容 / 修测试断言匹配实现 / 删过时测试。独立 change 处理 | `fix-gate-test-setup` discovery · L2 phase1 第二轮 F1 |
| TD-017 | ✅ | `flow-kit-bundle/hooks/stop/lib/l3-review.sh::l3_review_run()` | ~~307 行超长函数，5 项职责混合~~ | ~~拆为 `_l3_build_prompt` / `_l3_call_api` / `_l3_parse_result` / `_l3_write_done` + `l3_review_run` 编排~~ | ✅ Resolved (final-debt-cleanup-2026-08): l3-review.sh split into 5 files (TD-008 fix), `l3_review_run()` now ~90 lines orchestrator in slim entry | `M-health 2026-07-10 Full Sweep` |
| TD-018 | ✅ | `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh::is_gh_pr_create()` | ~~290 行超长函数，7+ 独立 gate 检查混合~~ | ~~提取 `_gate_*` 命名函数 + 编排器 + 重命名 `_run_review_gates()`~~ | ✅ Resolved (final-debt-cleanup-2026-08): independent-review-gate.sh split into 4 files (slim + gate-helpers + gate-checks-basic + gate-checks-review), 20 functions distributed by responsibility | `M-health 2026-07-10 Full Sweep` |
| TD-019 | ✅ | `flow-kit-bundle/hooks/stop/{20,21,22,23,24,25,26}-*.sh` | ~~check_* 模板跨 6 模块重复~~ → ✅ resolved by `sweep-fix-2026-07-10`：`run_check()` 已实现于 `common.sh:49`，7 模块全部迁移（20-claude-md/21-memory/22-git/23-quality/24-session/25-project/26-workflow）。 | ✅ 已完成（sweep-fix-2026-07-10） | `M-health 2026-07-10` · verified 2026-08-04 |
| TD-020 | ✅ | `flow-kit-bundle/hooks/stop/lib/common.sh` | ~~`write_failed_state()` 死代码~~ → ✅ resolved：grep 全仓 0 hits（包括定义），函数已在 `sweep-fix-2026-07-10` 中移除。 | ✅ 已完成（sweep-fix-2026-07-10） | `M-health 2026-07-10` · verified 2026-08-04 |
| TD-021 | ✅ | 全局命名约定 | ~~5 种命名前缀无文档~~ → ✅ resolved by `sweep-fix-2026-07-10`：CONTEXT.md § 命名约定 → 函数命名前缀（L404-410）已文档化 6 种前缀（`fk_`/`_fk_`/`check_`/`l2_`/`l3_`/`_gate_`/`_fai_`）。 | ✅ 已完成（sweep-fix-2026-07-10） | `M-health 2026-07-10` · verified 2026-08-04 |
| TD-022 | ✅ | `flow-kit-bundle/lib/install_brooks.sh` + `install_hooks.sh` | ~~0 单元测试~~ → ✅ resolved：3 个测试文件已存在（test_install_brooks_tools.bats / test_install_coverage.bats / test_install_dry_run.bats），覆盖 brooks_tools 安装 + 覆盖率校验 + dry-run 模式。 | ✅ 已完成 | `M-health 2026-07-10` · verified 2026-08-04 |
| TD-023 | ✅ | `flow-kit-bundle/hooks/stop/lib/l2-detect.sh` + `l3-prompt.sh` 等 | shellcheck warning 级卫生已清零：SC2155×10（declare/assign 分离）；SC2034 真死代码 14 处删除 + 跨文件消费豁免 6 处（独立指令行形式——本版 shellcheck 不支持行内指令，会报 SC1126）；CLI_PATTERNS/GOTCHA_PATTERNS 死块删除。warning 64→28（余量为 SC1090 动态 source 等 known-acceptable）。 | ✅ Resolved（2026-09-01 health-fix 当场清） | `TD-023-fix 2026-09-01（commits 5cc4502 + follow-up）` |
| TD-024 | ✅ | `test/test_l3_pipeline_fix.bats`（全文件 40 处 `| grep -q`） | ~~全量 bats 偶发 1 fail（2026-09-06 F-1 · T04 AC-1 · status 141 SIGPIPE）~~ → ✅ resolved（health-fix 2026-09-06 当场清）：`grep -q/-qF/-qE` 提前退出使管道 writer 收 SIGPIPE 141 → 全部改为 `grep/-F/-E … >/dev/null`（rc 语义不变、读取端不再提前退出），l3-prompt 副本同步 | ✅ 已完成（2026-09-06 · 单文件 41/41 ×2 绿 + 全量复跑 803/803 绿（ok 含 1 既有 skip））；**2026-09-20 复核未回退**：`grep -q` 计数=0，950/0 两轮全绿 | `M-health 2026-09-06 全量扫描` |
| TD-025 | 🟡 | `flow-kit-bundle/flow-kit/prompts/*.md`（15 份）↔ `flow-kit-bundle/skills/*/SKILL.md`（17 份） | **双载体无同步门禁**：skills/ 是 OpenCode/DSH 平台的同内容载体（`install_skills.sh` → `~/.config/opencode/skills/`），prompts/ 供 Claude Code 侧；两者**手工双写**，**实例上无有效机器一致性检查** —— 原措辞「无任何机器一致性检查」经 2026-09-22 复核**不准确**：`reference/check-gate-sync.sh` 意图覆盖此面，但只覆盖 **1/14 对**、判据 `grep -c "^\| [0-9] \|"` 只匹配顶格行致**永久假红**（实测 exit 1）、**未接入 `make check`**、其 bats 测试 `:30` 断言 `[ "$status" -ne 2 ]` **显式容忍 exit 1** → **净有效覆盖 = 0/14**。更隐蔽的是该判据**语义盲**：纯比行数，故「只修正则」会把假红换成假绿（实测修正则为 4-dev=8 vs flow-dev=8，而那 8 行是 `SKILL.md:156-163` 的**迁移框架表**，与 PCSC 无关）。量化更新：14 对映射中 **3 对逐字相同（仅差 front-matter）、11 对实质分叉**（最惨 `6-review ↔ flow-review` 仅 28 行交集，Jaccard 1.0%）；最差为 `4-dev ↔ flow-dev`（skill 反向超集 +263 行）（不像 `test/ ↔ bundle/test/` 有 `check-test-sync`、hooks 有 `check-hooks-sync`、`l3-prompt.sh` 有 md5 断言）。2026-09-20 jscpd 量化：text/markup 克隆中 **10 组 ≥30 行**（最大 `A-evolve↔flow-evolve` 196L）；体量已可见分化（`6-review` 351L vs 228L · `4-dev` 352L vs 544L）→ 确认两载体各自演化。本周期 `l3-review-defects-2026-09` 修复只落 prompts 侧，未触及 skills/ | 二选一：① 新增 `make check-skills-sync` 纳入 `make check`；② 在 CONTEXT.md 显式声明 skills/ 为「允许差异的独立精简版」并给出判定边界。**禁止**继续维持「无门禁 + 无声明」的静默漂移状态。**处置顺序（2026-09-22 更正）**：必须先修判据语义 → 再锁定唯一语义源 → 最后才扩覆盖；扩覆盖前不修语义只会批量产出假绿 | `M-health 2026-09-20 全量扫描` · 措辞与量化更正 `M-health 2026-09-22 全量扫描` |

> **🔴 Critical（本次巡检发现，已归入 `health-fix-2026-09b` 处理中 · 按本段约定不单列）**：
> **TD-026** `runtime-edit-guard.sh:46` `eval` 注入 → **任意代码执行（已复现）**；
> **TD-027** `install_hooks.sh:251` jq 缺失时 `settings.json` 被截断为 0 字节（无备份 · 已复现）；
> **TD-028** `independent-review-gate.sh:42-46` pre-tool-use 子库 fail-close 守卫修复不完整 → fail-open；
> **TD-029** `check-gate-sync.sh` 判据错误 + 未接门禁 + 测试豁免（同 TD-025 面）；**阶段 6 REVIEW 发现（F6/F7）· 本 change 内修复（T-FIX-04）**：F6 缺 prompt/skill 文件时只 WARNING + 裸 `return`（`ERRORS` 不增）⇒ 缺对仍打印「✅ 校验对 3/14 一致」rc=0；F7 「14」多处硬编码、`:206` 文案仍指「toll-gate 协议段」（v1 已是全文比对语义）。T-FIX-04 收敛：缺对 ⇒ `ERRORS+=1` 非 0 退出且汇总不打印 ✅ 一致；分母改用实际比对对数（`COMPARED`）；`PAIRS_TOTAL` 常量单点；`:206` 文案改为与全文内容比对语义一致；正常路径零变更（真实仓 rc=0 + 17 预设自证行在位）。
> **TD-030** `reference/pipeline-gates.md` 伪单一源（被 `4-dev.md:92` `@see` 为源，却已被内联副本分叉：源 7 行 vs 副本 8 行）。
> 详见 `.specs/health/2026-09-22-FULL-SWEEP.md`。

| TD-031 | 🟡 | 全局（隐私 / 门禁） | **无任何前向防回归门禁**：`Makefile` 无 path/privacy 目标、`verify-claims.sh` 无绝对路径检查、`.git/hooks/pre-commit` 内容**只是 `make test`** 且为**指向仓库外**的机器本地符号链接（**不随 clone 传播** → 新克隆完全没有门禁）。当前唯一防线是 `.gitignore`（覆盖已知临时产物），**无法阻止**把绝对路径粘进 tracked `.md`。事实印证：工作区现存 9 个含 `/home/<redacted>` 的未跟踪文件，全被 `.gitignore` 挡住但仍**在持续再生** | 新增 `make check-path-privacy`：扫 `git ls-files` 内容的 `/home/<user>`、`/Users/<user>`、雇主目录名、私网 IP，非零退出；纳入 `make check` + pre-commit。首跑会命中现存残留，需先定"允许清单+棘轮"或先清残留 | `M-health 2026-09-22 全量扫描` |
| TD-032 | 🟡 | `flow-kit-bundle/hooks/stop/lib/l3-api.sh:107-112` | L3 凭证经 `curl -H "$_auth_header"` 走 **argv** → 同机进程可经 `ps` / `/proc/<pid>/cmdline` 读取，暴露窗口 = `--max-time "$timeout"` **默认 300 秒**。同函数**已把请求体改走 stdin**（注释自陈"不再作为 argv"）却**未对 header 做同样加固** —— 加固不一致，凭证成了唯一仍走 argv 的敏感项 | 改用 `curl -K -`（配置走 stdin），或 header 写 mktemp + mode 600 配置文件后 `-K`，用完即删 | `M-health 2026-09-22 全量扫描` |
| TD-033 | 🟡 | `test/test_gate_config_presets.bats:28`（mock 定义）· `:42-112` | **390 行「mock 自证」**：文件内自行定义 `resolve_gate_config`（`:27` 注释自陈 "Simulates the resolve_gate_config() logic"），**从不 source 生产实现**（对 `flow-kit-bundle`/`check-gate-sync.sh`/`SKILL.md` 引用数 = **0**）。实测**拷到 `/tmp`（仓库不可达）仍 34/34 全绿**，对照 `test_correction_hygiene.bats` 同法 exit 127 → 坐实假依赖。更糟：mock 硬编码 `"independent"` **72 处**，而出货契约 `skills/flow/SKILL.md:138` 明写「值统一为 `"both"`」→ 断言的是**改造前旧语义** | 改为 source 真实实现（或让该文件驱动 `check-gate-sync.sh`）；mock 取值对齐 `"both"` | `M-health 2026-09-22 全量扫描` |
| TD-034 | 🟡 | `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:106-124` | `check_gate_config_sync()` **只比对预设「名字」集合**（`sort -u` 后 set-diff），**从不比对值** → 值漂移**结构性失明**，此即 TD-033「`independent` vs `both`」长期存活的原因。其自身测试 `test_check_gate_sync.bats:36` 注入的假预设也靠**名字** `fake-preset` 被检出，反证对值盲视 | 把 `→ {...}` 右侧 JSON 值一并纳入 diff | `M-health 2026-09-22 全量扫描` |
| TD-035 | 🟡 | `flow-kit-bundle/hooks/stop/00-gate.sh:71` + `lib/common.sh:432` + `lib/l3-truncate.sh:100,167` + `sync-hooks.sh:181` | **未声明的平台依赖**：GNU-only `timeout`（macOS 无，brew 里叫 `gtimeout`）+ bash4 `declare -A` / `mapfile`（macOS `/bin/bash` 是 3.2）→ 在 macOS 上每个模块 127 被 `\|\| true` 吞掉，**整条 Stop hook 链静默 no-op**。讽刺点：代码对 `stat` 做了 `stat -c \|\| stat -f` 可移植处理（8 处），却把这些当作既成事实 | 探测 `timeout`/`gtimeout`；bash4 特性加版本闸或明确声明 Linux-only | `M-health 2026-09-22 全量扫描` |
| TD-036 | 🟡 | `hooks/stop/lib/common.sh:363` 与 `hooks/stop/lib/runtime-adapter.sh:47` | `fk_platform_is_opencode()` **定义两次**（全仓 255 个函数中**唯一**重名）。已运行时验证覆盖顺序：`common.sh:15` 先 source `runtime-adapter.sh`，再于 `:363` 重新定义 → **common.sh 版本生效**。两份函数体**当前完全一致** → **潜伏**而非现网 bug；未来只改一处会**静默失效**（`runtime-adapter.sh:46` 自注 "Kept for backward compatibility" 已暗示意图分歧） | 保留 `runtime-adapter.sh` 为唯一定义，`common.sh:363` 处删除或加 `# SYNC-POINT` | `M-health 2026-09-22 全量扫描` |
| TD-037 | 🟢 | `Makefile:33-63`（`make lint`） | 判据为 `grep -ci "error"`，**只有 error 级才失败** → 实测 **233 条 warning 级发现完全不过门禁**（SC2015×73 / SC2086×55 / SC1090×36 / SC2016×29 / SC2088×8 / SC2034×6 等）。**抽样复核显示大部分为风格或假阳性**（SC2088 @`weak-model-compliance.sh:46-47` 是正则模式数组；SC2034 `FLOW_KIT_YES` 被同 shell source 消费）→ 价值不在"233"这个数，而在**"真 warning 也拦不住"这个结构缺口** | 引入**棘轮（ratchet）**：冻结当前基线数，只允许下降，不做一步清零 | `M-health 2026-09-22 全量扫描` |
| TD-038 | 🟢 | `flow-kit-bundle/install.sh:19,83,138` | **已文档化的死开关**：help 文本 `:83` 宣传 `--brooks-src <path> 指定 brooks-lint 源目录（开发用）`，`:138` 解析进 `BROOKS_SRC`，但**该文件 `:139` 之后再无任何读取**（awk 实测为空）。真实消费者是**另一个脚本** `package-flow-kit.sh:331`（从**环境变量**读）。后果：用户按 help 传参 → **无效果、无警告、无报错**，静默无效 | 删除该 flag 及 help 行，或补上 export 与真实消费逻辑 | `M-health 2026-09-22 全量扫描` |
| TD-039 | 🔴 | `flow-kit/prompts/independent/L2-blind-review.md` ↔ `hooks/stop/lib/l2-detect.sh:229-294` ↔ `hooks/stop/29-independent-review.sh:89,136` | **dsh 派发路径与 L3 门禁的「标题契约」不一致 ⇒ `gate_config=both` 在本平台永远到不了 L3**（阻塞级）。三处事实：① L3 门禁**硬要求**产物含字面 `^## L2 盲审`（`29:89` 与 `:136` 的 `grep -q "^## L2 盲审"`）；② 官方手动派发提示（`l2_detect.sh:259-294`，**含 dsh 分支**）只写「输出：写入 `.specs/<id>/INDEPENDENT-REVIEW-<phase>.md`」，**从未要求该标题**；③ 被要求注入的固化 prompt 也只说「若文件不存在：新建，**首行加 `# 独立审查 · 阶段 <N>`**」，且 `:141` 仍写「报告由**主 agent** 贴进「L2 盲审」段」——与 2026-09-19「手工贴入整体禁止」的决策相矛盾。**后果**：在 dsh 上严格照官方提示派发的 L2，产出的文件不含该标题 → L3 跳过并写 `l2-missing` correction → `L2-first` 契约不可满足 → **阶段 1/2/3/5/6/7 的门永久关闭**。curl 路径（`l2_dispatch_agent`）不受影响（它自己补 `## L2 盲审（mock · ts）` 标题，见 `:327`），故历史产物均有该标题 —— **这是 dsh 路径独有缺口**，只有真正启用 `gate_config=all` 才会暴露 | 二选一：① 在固化 prompt 的「文件写入约束」中**显式要求**`## L2 盲审`（或 `## L2 盲审（第 N 轮）`）为段落标题，并同步 `l2_dispatch_prompt` 的参数模板（`+ 输出格式：以 ## L2 盲审 开头`）；② 放宽门禁判据为 `^## .*L2.*盲审` 并同步三处。**必须同时修 `:141` 那句与既有决策矛盾的表述** | `M-health 2026-09-22 全量扫描` · 复现于 `health-fix-2026-09b` 阶段 1（启用 gate_config=all 后） |
| TD-040 | 🟢 | `.specs/CONTEXT.md`（本段自身）· 全局 | **reference/「常设检查项」类表述与 AC 追溯脱钩**：本段曾写「`grep eval` 应成为常设检查项」，而 change 的 AC 只覆盖**本次变更范围**、且 AC-1 用的是**更窄的精确 pattern**、并非门禁接线 ⇒ 把「AC 级验证」当成「常设门禁项已入册」是**假追溯**（复现于 `health-fix-2026-09b` L2 第 2 轮 N6 / 第 3 轮 C6） | 区分两类并显式标注归属：**AC 级验证**（随 change 存在）vs **常设门禁项**（须落到 `make check` 的接线清单）；本段的此类表述应标注它属于哪一类，必要时把常设项落到 `Makefile` 的 `check:` 先决条件 | `M-health 2026-09-22 全量扫描` · `health-fix-2026-09b` L2 第 3 轮 C6 |
| TD-041 | 🔴 | `.specs/ARCHITECTURE.md` §3 ↔ `.specs/adr/*.md` | **本仓存在「双 ADR 索引」且编号互相冲突**：`ARCHITECTURE.md §3` 的 ADR-001~009 与 `.specs/adr/001~009` 是**两套完全不同的系列**（实测 **ADR-005**：前者＝`独立审查体系：L2 + L3 双层`、后者＝`gate-active source 依赖`；**ADR-008**：前者＝`Correction File 系统`、后者＝`is-git-commit-quoting-aware`）⇒ **任何「ADR-NNN」式引用在本仓都是歧义的**。这是 **ADR-027 编号事故的同类土壤**（其更正说明记录了「依据过期的最大编号声明 + `ls \| head` 截断」导致重复编号 010）。复现：`grep -E '^### ADR-00[1-9]' .specs/ARCHITECTURE.md` 与 `ls .specs/adr/` 逐条对照 | 二选一：① 把 §3 的 001~009 重编号为不冲突区间；② 在 §3 顶部显式声明「本节 ADR 编号与 `.specs/adr/` **不共享命名空间**」并给出映射表。**在此之前所有引用一律以 `.specs/adr/` 实有文件名**为准（本 change 已按此执行） | `health-fix-2026-09b` 阶段 2 L2 R9（2026-09-22） |
| TD-042 | 🔴 | `flow-kit-bundle/hooks/stop/29-independent-review.sh` Gate 4 ↔ `flow-kit-bundle/hooks/stop/lib/done-validation.sh` | **凭证不与受审工件绑定 ⇒ 陈旧凭证放行**：`.done` 只证书**存在性**（`fk_validate_done_marker` 的 Tier 1 值域校验**接受 `L2_verdict=fail`**，Tier 2 仅比对凭证与 IR 档的 L2 值一致性、**不比对工件内容**）。实测本 change 即活例：`DESIGN.md` 在 L3 pass（2026-09-22 19:06）后又被重写 4 次（末次 00:13），Gate 4 以 `.done` 存在**短路** ⇒ 重审路径在 **pass 态不可达**。**关键：陈旧检测本已存在、且用的是 hash 而非 mtime**（`_l3_check_rerun` 比对 IR 档内 `L3_artifact_hash:` ↔ 当前 `sha256 DESIGN.md`，ADR-010 D4·J）—— 实测本 change：记录 `35519db8…` ≠ 当前 `4e297693…`（**不一致**），而门禁仍放行 ⇒ **缺的不是检测，是门禁不查它**。门禁干跑双态：**有陈旧凭证 → rc=0 放行**；同工件副本去掉凭证 → rc=2 deny ⇒ 放行与否**唯一**取决于凭证文件是否存在 | **把 hash 一致性并入凭证校验**：Gate 4 在凭证存在之后继续跑 `_l3_check_rerun`（或直接要求 `L3_artifact_hash` == 当前工件 sha），不一致 ⇒ fail-closed 或触发重审。**不可用 mtime** —— mtime 信号已被否决（touch 噪声误判，见本档「`## L3` 段检查」词条） | `health-fix-2026-09b` 阶段 2（2026-09-23 · PreToolUse gate 干跑实证）；**Stop 路径活例（2026-09-23 阶段 3 放行前实测）**：改 `TASK.md` 后 Stop hook **未**重跑 L3 —— IR 档记录 `L3_artifact_hash: c88503ed…` ≠ 当前 `sha256 TASK.md` = `793b32e9…`，门禁仍视其为通过 ⇒ 重审路径在 **pass 态确实不可达**（本次只能以官方路径③手动重跑） |
| TD-043 | 🟡 | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:350` | **L3 的 ADR 采样 = `find \| head -3` + 每份截断 2000 B ⇒ 送进审查提示词的是「编号最小的 3 份无关 ADR」，DESIGN 实际引用的 ADR 永远不在其中**。原文：`done < <(find "$adr_dir" -type f -name '*.md' \| head -3)` 后接 `_l3_utf8_head_bytes 2000`。实测（阶段 2 · `_l3_build_prompt 2 …` 干跑）进入提示词的是 **ADR-011 / ADR-015 / ADR-019**（DESIGN 引用的是 022/026/027/028）⇒ ① 审查者把无关 ADR 当成"本 change 的决策依据"（本轮 L3 的 critical① 即由此产生）；② 每份 2000 B 截断使 ADR 正文在句中**戛然而止**，外观等同"工件损坏"（本轮 L3 报「ADR-015 正文在 `completed_at` 处截断」） | 按 **DESIGN §4 ADR 索引所引用的 ADR 文件**选择纳入（而非目录序前 3），并对拼接总量设预算 + 截断处显式落 `…（截断，全文见 <path>）` 标记 | `health-fix-2026-09b` 阶段 2 L3 重审（2026-09-23 · critical① 的根因）；**→ 本 change 内已修**（用户裁决 2026-09-23；见 `CHANGE.md`「4b 范围追加」+ `DESIGN.md` §0.5.1 该行 + 5-test 双态 verify） |
| TD-044 | 🔴 | `flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh:18` `_is_dotdone_write` | **`.done` 作者性锚点可绕过（token 共现启发式，非写入分析）**：命令含 `>` / `tee` / `cp` / `mv` / `sed -i` / `printf` / `dd of=` / `install` / `awk` / `cat <<` 任一即判「写」。干跑双态：`printf … > <凭证路径>` → **rc=2 拦**；`python3 -c "…write_text(…)"` **同路径同载荷** → **rc=0 未拦**。反方向亦错：**只读**命令只要同串出现 `>`（哪怕重定向到 `/tmp`）即被 deny（本项目内已实测命中 1 次）⇒ 本档「`.done` 作者性校验」词条声称「解决 agent 可自写合法 `.done` 绕过 L3 的安全缺口」**当前不成立**，只提高了成本 | 去掉「文件即凭证」模型：凭证须由子系统持有 secret（HMAC / nonce 落 agent 不可写通道），或至少把写入侧判定改为与读取侧同源的**结构化判定**而非字符串共现 | `health-fix-2026-09b` 阶段 2（2026-09-23 · PreToolUse gate 干跑实证） |

| TD-045 | 🟡 | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:382`（主件按 `$max_bytes` 头截断）↔ `:265-270`（`_l3_emit_prompt` 又按**同一** `$max_bytes` 裁尾）↔ 预算链 `lib/l3-review.sh:58` / `29-independent-review.sh:113,171` / `config/stop-hook.json:126-127` | **同一个 `max_bytes`（默认 80000 = `independent_review.max_artifact_bytes`）既当「主件头截断上限」又当「整份提示词总上限」** ⇒ 主件之后追加的 CHANGE.md（6000 B）、`_l3_extra_deliverables`（每件 3000 B）、ADR 块（`_adr_budget=18000`）必然把总长顶出上限，于是 `_l3_emit_prompt` 从**尾部**裁掉的字节数**恰好等于刚追加的量** —— 被裁掉的正是**主件自己的尾部**。实测阶段 3：stderr `[l3-review] WARNING: 提示词被截断 — 完整 85871B，本次仅发送 80000B（丢弃 6%）`；`TASK.md` 93566 B 先被 `_l3_utf8_head_bytes 80000` 截到 80000 B，再被总上限裁掉 5871 B ⇒ 审查者只看到约 76 KB，**T24–T29 一带（含 AC-8 收口 task）从未进入 L3 提示词**。哨兵计数（`_l3_build_prompt 3 … 80000` 干跑）：`AC-8 收口` **0**、`规定性伪代码` **0**、`<!-- 占位 -->` **0**，而 `T19`=4 / `T27`=4 / `D10′`=11；提示词末行截在 T28 的 `case "$rc" in 0|1) : ;; 3) { echo "🔴 rc=3（未验证）出现在落地后的` 中间。**且主件被裁时提示词内无任何标记**（对比：ADR / extras 分支各有显式截断标记） | 拆成两个常量（**单件上限** ≠ **总量上限**）；总量不足时按「附属件 → 主件」优先级裁剪，并对**每次**裁剪落显式标记；主件被裁时必须报文告警。**临时可用**：`FLOW_KIT_L3_MAX_ARTIFACT_BYTES=<够大>` 覆盖（`flow-kit-bundle/FLOW-KIT-用户指南.md:964` 已文档化该解析链）—— 只增可见信息、不放宽任何判据 | `health-fix-2026-09b` 阶段 3 L3 重审（2026-09-23 · stderr WARNING + 干跑复现 + 哨兵计数）；**本 change 内不改该代码**（与 TD-043 同文件，避免自指门禁继续扩面），仅登记 + 重审时提高预算 |

| TD-046 | 🟡 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（把模型返回的判决 JSON **原样**写入审查档，无任何校验/规范化） | **落档的 L3 判决 JSON 可能不是合法 JSON**：模型返回的字符串里一旦含未转义的引号或裸换行，写入方照抄 ⇒ 任何按 JSON 消费判决的下游（自动化、报表、仪表）都会解析失败。实测 `health-fix-2026-09b` 阶段 3 L3 第 3 轮（2026-09-23 09:41）：`json.loads` 报 `Expecting ',' delimiter: line 5 column 10420`（`strict=False` 亦失败），我不得不写容错解析器（按 `"file"/"issue"/"why"/"fix"` 逐字段状态机）才取回 findings；同一份档内的判决在人工阅读时**看起来完全正常**，缺陷只在机器读取时暴露 | 落档前 `jq -e .` 校验：通过则按现状写；失败则**保留原始文本于独立代码块**并写入显式「判决 JSON 解析失败」标记（不得静默写入一段形似 JSON 的文本）；可选：提示词里要求判决为单行压缩 JSON 并在写入前规范化 | `health-fix-2026-09b` 阶段 3 L3 第 3 轮（2026-09-23 · 容错解析实证）；**本 change 内不改该代码**，仅登记 |

| TD-047 | 🟡 | `flow-kit-bundle/flow-kit/prompts/4-dev.md:157` ↔ `flow-kit-bundle/flow-kit/scripts/task-brief:1` | **阶段 4 文档给出的 `task-brief` 调用形态不可执行**：`task-brief` 首行是 `#!/usr/bin/awk -f`（可执行位 755）—— 仓库自测用的是 `awk -f "$SCRIPTS_DIR/task-brief" …`（`test/test_scripts_security.bats:61`），**直接执行也可用**（实测 `flow-kit-bundle/flow-kit/scripts/task-brief .specs/health-fix-2026-09b/TASK.md T13` ⇒ rc=0、6005 B、正确切出 `<task id="T13">` 块）；而 prompt 写的是 `bash scripts/task-brief .specs/<id>/TASK.md <task-id>` ⇒ 实测 **rc=2**，stderr `行 7: BEGIN: 未找到命令` / `行 8: 未预期的记号 "{" 附近有语法错误`（bash 把 awk 程序当 shell 脚本解析）。`dist/dsh-flow-kit/flow-kit/scripts/task-brief` 与 `dist/dsh-flow-kit/vendor/flow-kit-bundle/flow-kit/scripts/task-brief` 首行同为此 shebang ⇒ 安装态同样受影响；而阶段 4 全程依赖该命令切单 task 上下文 ⇒ 照文档执行会**在 4-dev 起步即失败** | 三选一：① 文档改为 `awk -f scripts/task-brief …`（与自测一致）；② 文档改为直接执行 `scripts/task-brief …`（依赖 755 随包分发，需在打包/安装处断言）；③ 脚本改成 bash 包装 + 内嵌 awk。**推荐 ② + 打包断言**（最贴近 prompt 书写习惯），并加一条「按 prompt 原文调用」的 bats 回归用例 | `health-fix-2026-09b` 阶段 3（2026-09-23 · 准备阶段 4 时实跑复现）；**本 change 内不改它**，仅登记 |
| TD-048 | 🟡 | `package-flow-kit.sh`（Part C 拷贝段：pre-tool-use / pre-commit / stop / session-start，**无 pre-push stanza**）↔ `dist/dsh-flow-kit-0.2.0.tgz` 顶层 `dsh-flow-kit/hooks/` | **打包面不会收录新 hook ⇒ 分发件顶层镜像缺 `pre-push`**：本 change 新增 `flow-kit-bundle/hooks/pre-push/pre-push.sh`（T11 产出）后，`package-flow-kit.sh` 不会把它拷进 tgz 的 `dsh-flow-kit/hooks/`（实测当前归档 `hooks/pre-push/` 命中 **0**；Part C 无该 stanza）。**影响有限**：`dsh-flow-kit/vendor/flow-kit-bundle/hooks/pre-push/pre-push.sh` 由 `sync-hooks.sh` 的 dist DEST_ROOT 维护 ⇒ `install_hooks.sh` 的安装器路径可用；本机 `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` 亦由 sync-hooks 维护。**已在本 change 修（T11 修复轮 2 · 依 TD-048 用户裁决授权）**：Part C 已增 `pre-push` stanza（`package-flow-kit.sh:134-136`）⇒ 顶层归档现含 `dsh-flow-kit/hooks/pre-push/pre-push.sh`（`R3-29` 顺手同步本行；原「未在本 change 修 · 不在 `DESIGN.md` §0.5.1 触碰清单内」的陈述已过期作废）。原建议修法（保留存档）：Part C 增 pre-push stanza + `make check-dist` 增「归档顶层 `hooks/` 与源树同源」断言。 |

| TD-049 | 🟡 | `flow-kit-bundle/hooks/stop/33-flow-active-integrity.sh:229`（取值）`:235`（相减）↔ 写者 `flow-kit-bundle/hooks/stop/32-fallback-guard.sh:71` · `flow-kit-bundle/hooks/stop/26-workflow.sh:92` · `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:312,365` · `flow-kit-bundle/hooks/stop/lib/checkpoint-lib.sh:39,75` | **`.flow-active.updated_at` 类型不一致 ⇒ 陈旧度门禁死在算术错误上**：写者落**三种**类型 —— jq `now` 的**浮点**（`32-fallback-guard.sh:71` `.goal.status = "done" \| .updated_at = now`；本仓 `.flow-active` 实测值 `1790104581.736337`）、`date -Iseconds` 的 **ISO 串**（`26-workflow.sh:92`）、`jq now \| strftime(...)` 的**串**（`flow-kit-artifacts.sh:365`）以及 `$ts`（`:312`、`checkpoint-lib.sh:39,75`）；读者 `:229` 用 `jq -r '.updated_at // 0'` 取到字符串后，`:235` 直接 `$((now - updated_at))` **假定整数** ⇒ 实测报 `bash: 行 1: 1790104581.736337: 语法错误：无效的算术运算符（错误记号是 ".736337"）` 且 rc=1（最小复现：`bash -c 'set -u; u=1790104581.736337; now=$(date +%s); echo $((now - u))'`）。后果：`stale_updated_at` 违规在该形态下**永不产出**（门禁静默失效，撞 ADR-027 ② 的「假绿」形态）；若模块在 `set -e` 下运行则整个模块中止 | 读者侧先归一化再相减：`jq -r '(.updated_at // 0) \| if type == "string" then (try (fromdateiso8601) catch 0) else (floor // 0) end'`；写者侧统一落一种类型（建议统一 ISO 串 + 单一解析函数），并加一条 bats：三种类型都不得让该模块以非零退出/静默跳过 | `health-fix-2026-09b` 阶段 4 T06（2026-09-23 · T06 环境观察 + 主 agent 独立复现）；**本 change 内不改它**（非 AC 范围），仅登记；T06 侧原始观察见 `.specs/health-fix-2026-09b/MINOR-DEFERRED.md` |

| TD-050 | 🟡 | `flow-kit-bundle/lib/install_hooks.sh:76-77`（`deploy_pre_commit`：`local target="${project}/.git/hooks/pre-commit"` + `mkdir -p "${project}/.git/hooks"`）· `:132-133`（`deploy_pre_push` 同形）· `:95`（`is_flowkit_symlink`） | **hook 部署目标写死 `.git/hooks/`，全仓不检测 `core.hooksPath` ⇒ 目标库设了 hooksPath 时 symlink 部署静默失效（门禁看起来装好了却从不运行）**：`git config core.hooksPath <dir>`（或把它设为**空串**）之后，git 解析出的 hooks 目录不再是 `${project}/.git/hooks`（空串 ⇒ `git rev-parse --git-path hooks` 输出 `./`），而我们仍只往 `.git/hooks/` 放 symlink ⇒ AC-3 的 pre-push 拦截与前代 pre-commit 门禁**形同不存在，且安装器自报成功、无任何告警**。本仓即活证据（2026-09-24 实测）：`.git/config` 的 `[core] hooksPath = `（空串）⇒ `git rev-parse --git-path hooks` = `./`、`git rev-parse --git-path hooks/pre-commit` = `/pre-commit`、`git hook run pre-commit` ⇒ `error: cannot find a hook named pre-commit`（git 2.43.0）；而 `bash .git/hooks/pre-commit` 显式调用时两次探针均 rc=1 并指名 `file:line`（脚本本身有效）。ADR-022 只锁定「symlink 而非 core.hooksPath 全家桶」这一取舍，**未处理目标库已经设了 hooksPath 的场景** | 部署前用 `git rev-parse --git-path hooks` 解析**真实** hooks 目录（尊重 `core.hooksPath`），非默认值时显式告警并落档；部署后加一条自检「`[ -x "$(git rev-parse --git-path hooks)/pre-commit" ]`（或 `git hook run pre-commit` 能找到）」，失败即 🔴；补一条 bats：把 `core.hooksPath` 指向临时目录后安装器必须报红而不是自报成功 | `health-fix-2026-09b` 阶段 4 复核（2026-09-24 · 主 agent 自查 L-144 时实测）；**本 change 内不改它**（非 AC 范围 + ADR-022 已锁方案），仅登记 |

| TD-051 | 🟡 | `test/test_l3_pipeline_fix.bats:609`（`printf '%s' "$capped" \| iconv -f utf-8 -o /dev/null`）· 调用方 `Makefile:8-11`（`test:` 目标不设 locale） | **UTF-8 合法性断言依赖 locale ⇒ 在 `LC_ALL=C` 下把合法多字节 UTF-8 判成非法（假红）**：`iconv` 的 `-o` 只是**输出文件**，未给 `-t` 时目标字符集取当前 locale 的 charset ⇒ `LC_ALL=C` 时目标是 ASCII，任何非 ASCII 字节都报 `illegal input sequence`。实测（2026-09-24 · 主 agent 独立复现）：`printf '中文测试' \| LC_ALL=C iconv -f utf-8 -o /dev/null` ⇒ rc=1（stderr `iconv: illegal input sequence at position 0`）；`LC_ALL=C.UTF-8` 与本机 `LANG=zh_CN.UTF-8`（`LC_ALL` 未设）⇒ rc=0；`LC_ALL=C` + 显式 `-t utf-8` ⇒ rc=0。带该断言的用例（TAP 第 41/646 条 `T06fix: L2 R1 - line cap truncation respects UTF-8 boundary`）在 `LC_ALL=C npx bats test/test_l3_pipeline_fix.bats` 下 `not ok`（ok=40 / not_ok=1），环境地域下 rc=0 / 41 ok；被测输出在两种地域下**逐字节相同且均为合法 UTF-8**（`_l3_utf8_head_stream` 内部已 `local LC_ALL=C`）⇒ **产品代码无缺陷，纯 locale 敏感性**。危害面：`make test` 与调用它的 pre-commit（`make test`）在 `LC_ALL=C` 的 CI/容器里**假红** | 断言改为 locale 无关：`iconv -f utf-8 -t utf-8 -o /dev/null`（显式目标编码）；另加一条 bats 自检「`LC_ALL=C` 下该文件全绿」，或让 `Makefile` 的 `test:` 显式指定 UTF-8 地域；全仓扫描同类断言 `grep -rn 'iconv ' test/ flow-kit-bundle/test/` 逐条检查是否写全 `-t` | `health-fix-2026-09b` T27（2026-09-24 · 执行者 BLOCKED 上报 + 主 agent 独立复现，L-146）；**本 change 内不修** —— `test/**` 与其 bundle 镜像属**源面**，改动会令 `check-dist` 变红并迫使 T24 重建，违反「T24 必须是最后一个改动源面的步骤」的次序硬约束；**2026-09-24 复发（T-FIX-01 执行期）**：该 task 的 `<verify>` 首行 `export LC_ALL=C` 再次把同一用例打成 `not ok 646`（`iconv: illegal input sequence at position 136`）。主 agent 独立复现（工作树无生产件改动）：`LC_ALL=C npx bats --filter 'UTF-8 boundary' test/test_l3_pipeline_fix.bats` ⇒ `not ok 1`；`LC_ALL=C.utf8` ⇒ `ok 1`。判定 = **TD-051 的复发实例**（非新缺陷，不新开 TD），处置 = 判据修复（从 `<verify>` 删除该 locale 覆盖，其余判据逐字不动、断言强度不变），见 `MINOR-DEFERRED.md`「T-FIX-01 判据修复」 |

| TD-052 | 🟡 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:47-54`（`SELF_EXCLUDE` 六条精确路径 = 门禁本体 / 两份允许清单 / 三份审查档） | **常设门禁对「必然含 PAT 字面」的文件做整文件自排除 ⇒ 这 6 条路径下的真实账号路径在常设门禁下永不可见**：设计上 D10′② 明示了该取舍（不排除则门禁被自己的工件击穿：脚本自我引用、允许清单格式说明、审查档讨论），change 期由 T13 的「刻意不排除任何文件」判据补覆盖；但**归档后无任何常设判据覆盖该面**。本 change 阶段 5 实测边证：正因 T13 不排除，它才命中门禁本体头部注释里的合成探针字面 —— 说明这条覆盖边确实在工作，也说明它只活在 change 期 | v2 评估「自排除文件仍纳入扫描面 + 对其命中按**精确字面**允许（合成探针账号名、允许清单条目）」，把「整文件豁免」降级为「按命中成分豁免」；保留 change 期 T13 作为独立第二判据（同规则、两处判定；禁宽通配） | `health-fix-2026-09b` 阶段 5 第 1 轮（2026-09-24 · 主 agent 修复 T13 判据时发现并登记，L-147）；**本 change 内不改**（ADR-028 / D10′② 已锁方案，非 AC 范围） |

| TD-054 | 🟡 | `flow-kit-bundle/flow-kit/prompts/5-test.md:45-62`（L2 派发模板）· `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md`（L2 审查指令）· `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh`（L3 信封构造） | **审查派发面缺脱敏条款 ⇒ change 自己的审查档会击穿 AC-6 的机器门禁**：派发参数里给的是真实仓库根（绝对路径），但三处模板/指令都没有「工件与审查档内一律写 `<repo>`、探针字面按拼接构造」的要求 ⇒ L2 审查员把 `/home/<acct>/…/flow-kit` 原样写进 `INDEPENDENT-REVIEW-5.md:9`（并把合成探针写成整形态于 `:18`），一经 `git add`（进入 `git ls-files` 扫描面）即被 `make check-path-privacy` 判为**清单外命中 1 条**（实测 rc=2）。这正是本 change 要修的 L-137 家族（工件自造红 / 假绿），只是这次肇事者是**审查流程本身**，且五处审查档在 change 期内都是未跟踪文件 ⇒ 首次入库才发现 | v2：① 在 `5-test.md` 的 L2 派发模板、`L2-blind-review.md` 的写入约束、`l3-prompt.sh` 的信封头部各加一句显式脱敏条款（「仓库根写 `<repo>`；`/home/<acct>/` 形态与整形态探针一律禁止，按 L-137 拼接构造」）；② 让 `29-independent-review.sh` 在写 `.done` 之前对审查档跑一次**脱敏自检**（复用 `check-path-privacy.sh` 的 PAT，命中即写 correction 文件要求脱敏后重写），把「审查档入库前脱敏」变成机制而非主 agent 的自觉；③ 是否把 `INDEPENDENT-REVIEW-*.md` 统一纳入 `SELF_EXCLUDE` 需 ADR 裁决（**不默认放宽** —— 那会让审查档成为脱敏盲区） | `health-fix-2026-09b` 阶段 5 第 1 轮（2026-09-24 · 首次 `git add -N` 探测新工件时发现 `INDEPENDENT-REVIEW-5.md:18` 归因；主 agent 已就地脱敏并复验双门禁 rc=0） |
| TD-055 | 🟡 | 仓库根（**无** `.github/workflows/**`、无 `.gitlab-ci.yml` / `.circleci` / `Jenkinsfile` / `.travis.yml`；`flow-kit-bundle/brooks-lint/plugin/.github/**` 是第三方插件自带，非本仓 CI）· `Makefile`（`check-nfr-portability` 目标） | **无 CI、无 macOS runner ⇒ 跨 OS 兼容性只有静态判据**：bash 3.2（macOS）面的保证来自 `make check-nfr-portability` 的语法/依赖静态扫描，**无人真在 macOS 上跑过**；locale、`iconv`（TD-051 即此类的已登记实例）、内建命令与 `stat`/`timeout` 分支行为差异都无法被机器发现 ⇒ 「`make check` 全绿」不等于「macOS 可用」 | v2：加最小 CI（GitHub Actions `ubuntu-latest` + `macos-latest` 双 runner 跑 `make check`），或在每次 release 前用 macOS 实机跑一次 `make check` 并留档原始输出；短期保留 `TEST.md` §4.4 的 ⚠️ 残余行作为诚实声明（不得当成已验证） | `health-fix-2026-09b` 阶段 5 第 1 轮（2026-09-24 · L3 第 1 轮 minor「macOS 未实跑」；主 agent 判定为基础设施面 ⇒ 登记为技术债而非就地修） |
| TD-053 | 🟡 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（392 行，本 change 新增）· `flow-kit-bundle/flow-kit/reference/check-nfr-portability.sh`（新增）· `flow-kit-bundle/hooks/pre-tool-use/runtime-edit-guard.sh`（T05 修复） | **本 change 新增的两道门禁与 AC-1 的守卫修复没有常设 bats 回归 ⇒ 其判定力只活在 change 期判据里**：实测 `grep -rl 'path-privacy' test/` = **0**、`grep -rl 'nfr-portability' test/` = **0**、`grep -rl 'runtime-edit-guard' test/` = **0**（对照：`gate-sync` 命中 `test_check_gate_sync.bats` 5 用例、`install_hooks` 命中 4 文件、`pre-push` 3 文件）。危害面：归档后若有人改坏扫描逻辑（例如把"缺允许清单 ⇒ rc=1"退化成 rc=0、或把变更集空集守卫去掉），`make check` **仍全绿**（门禁在变更集上跑，天然不覆盖自身语义），只有重新发现并重跑 T21/T22/T23/T25/T26 判据才可能暴露 —— 即 AC-4/AC-6 的机器门禁可能出现"门禁失效而门禁报绿"的静默形态（ADR-027 ② 的假绿家族） | v2 补两条 bats：`test/test_path_privacy_gate.bats`（`mktemp -d` 自建 fixture：允许清单缺失 ⇒ rc=1 且指名缺失路径 / 空清单 ⇒ rc=0 / 探针注入 ⇒ rc=1 且报出 `file:line` / 非 git 仓库 ⇒ 明确不可用）与 `test/test_nfr_portability_gate.bats`（空变更集 ⇒ rc=3 未验证 / 注入 GNU-only 构造 ⇒ rc=1 且逐文件 `file:line`）；并考虑加一条"门禁自检"档：对门禁本体跑一次合成注入，断言其确实会红 | `health-fix-2026-09b` 阶段 5 第 1 轮（2026-09-24 · 主 agent 测试面普查时发现并登记）；**2026-09-24 用户裁决（option 1）改为本 change 内补**：阶段 5 L3 第 7 轮 M1 判定「长期回归保护未达标、只记技术债而结论仍 pass」不可并存 ⇒ 回退 4-dev 落 `T-FIX-01`（三件常设双态 bats：`test/test_path_privacy_gate.bats` · `test/test_runtime_edit_guard.bats` · `test/test_nfr_portability_gate.bats`，均驱动真实生产件 + 恒绿桩活性探针 + `make test-sync` + 重建 dist + `.specs/STATE.md` 基线更新）；**当时的不补理由（保留存档）**：`test/**` 与其 bundle 镜像属**源面**，且 `dist/dsh-flow-kit/vendor/flow-kit-bundle/test/` 已 vendored 75 个 bats（`package-dsh-plugin.sh` 零丢失整棵 bundle）⇒ 新增用例会迫使 `make test-sync` + 重建 dist/tarball，并令 AC-8 已落档的「976 ok / 0 not ok / 0 skip」基线口径整体失效（同 TD-051 的处置口径：次序硬约束优先） |
| TD-056 | 🟡 | 本仓安全扫描工具面（`semgrep` / `gitleaks` / `trufflehog` / `trivy` 实测 MISSING）· 两子包（`flow-kit-bundle/**`、`dist/dsh-flow-kit`）**无 lockfile** ⇒ `npm audit --production` 报 `ENOLOCK` | **安全轮次结论只有「替代面」强度**：秘钥扫描 = 模式面 grep（`AKIA…` / `BEGIN … PRIVATE KEY` / `ghp_` / `sk-` / `xox[baprs]-` / `*_AUTH_TOKEN=`）；SAST = shellcheck + 自研门禁（`check-path-privacy` / `eval` 面归因）；依赖面 = 「运行时第三方依赖 = 0」的量化替代。在无独立工具的仪器下，`OWASP A01–A10` 的 ✅/⚠️ 判定与 TD-053 的「门禁无常设回归」叠乘 ⇒ 结论强度受限于自研门禁本身（ADR-027 ② 的假绿家族） | v2（与 TD-053 同优先级）：① 在 CI/开发机安装 `gitleaks` + `semgrep`（固定版本），接线为 `make security-scan` 目标，把一次性 grep 变成常设可复算目标；② 若将来引入任何运行时第三方依赖 ⇒ 同步引入 lockfile 并接 `npm audit --production`；③ 在此之前所有安全结论必须显式标注「替代面，非独立工具仪器」 | `health-fix-2026-09b` 阶段 5 第 2 轮（2026-09-24 · L3 第 2 轮 major 4 要求把「工具缺失」从说明性记事提升为基础设施债；`TEST.md:17/:197/:219/:238-241/:333` 已明示替代面） |
| TD-057 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 内判据块的 `out=$(cmd 2>&1); rc=$?` 惯用法（T19 判据抽取块命中 3 处；同族写法散见 T02/T11 等块） | **同一判据在两种运行器下给出相反结论（假红）**：`set -euo pipefail` 下 `out=$(git push …)` 的赋值继承非零 rc ⇒ 脚本在 `rc=$?` 捕获前静默早退（无任何报文、rc=1，T19-SUMMARY:16 已记录一次误读风险）；`bash 判据块` 平跑则 rc=0（2026-09-24 实测 33 行抽取块 rc=0，四形态拦截 + 干净 ref 放行断言全过） | v2：① 全仓把 `out=$(cmd); rc=$?` 改写为 `out=$(cmd) || rc=$?; rc=${rc:-0}`；② `make lint` 面加一条静态检查（grep/awk 级）防复发；③ `reproduce-5-test.sh` 增加 `--strict` 对照模式（`bash -e -u -o pipefail` 运行器），让两种运行器的差异常设可见。**本 change 不回写 TASK.md 的理由**：① TASK.md 是阶段 3 的权威工件，其 L3 `.done` 以工件哈希为凭（TD-042 家族）—— 该 `.done` **已经**因本 change 历次判据修订（T13/T27 等）与哈希失配，TD-042 已登记为「凭证陈旧：`.done` 只证明存在过、不再证明当前字节」⇒ 再改一次只加深该缺口、不带来新的审查信号；② 按 flow-kit 次序，判据属阶段 3/4 产出物，阶段 5 的正当动作是**如实登记差异**而非改写上游工件（判据逻辑本身已在两种运行器下实测，见 `PHASE5-RECEIPTS.md`，外部可复算） | `health-fix-2026-09b` 阶段 5 第 2 轮（2026-09-24 · L3 第 2 轮 major 3 追问「rc=0 是字面执行还是修正后执行、修正是否已回写权威副本」） |
| TD-058 | 🟡 | `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（默认 `HOOK_BASE_DIR="$(cd "$(dirname "$0")" && pwd)"` = `…/hooks/pre-tool-use`，随后 `COMMON_LIB="${HOOK_BASE_DIR}/../stop/lib/common.sh"`）vs `flow-kit-bundle/hooks/stop/**`（约定 `HOOK_BASE_DIR=…/hooks`） | **同名环境变量在两个 hook 家族里语义不同 ⇒ 沿用 Stop 侧的约定会 fail-close 并给出误导性归因**：把 `HOOK_BASE_DIR="$PWD/flow-kit-bundle/hooks"`（L3 调用手册里的标准 export）传给 PreToolUse hook 时，`COMMON_LIB` 解析成不存在的 `flow-kit-bundle/stop/lib/common.sh` ⇒ `source` 后 `declare -f fk_phase_gate_key` 失败 ⇒ 报文 `[gate] common.sh 加载失败（HOOK_BASE_DIR=…/flow-kit-bundle/hooks），review gate fail-close：fk_phase_gate_key 未定义，拒绝放行`，rc=2（**拒绝一切 commit**，非仅阶段门相关）。2026-09-24 实测（`bash -x` 复现于阶段门复现脚本开发期）。危险的组合：① 运行时若真把 Stop 侧的值广播给 PreToolUse 钩子，门禁会变成"见 commit 即拒"且报错指向不存在的路径；② 复现脚本若照抄 L3 手册的 export 就会把 fail-close 当成"门禁在拦截"而误判判据通过（假绿/假红双面） | v2：① 统一语义（两家族都用 `…/hooks` 根，或改名如 `FLOW_KIT_HOOKS_DIR`）并在 hook 头部注释里明写各自的解析规则；② 加载失败报文必须同时打印**解析后的绝对路径**与其是否存在（现报文已打印值但未打印存在性），并加一条 bats：以 `HOOK_BASE_DIR=…/hooks` 驱动 PreToolUse hook 时必须仍能正确判定，或明确报配置错误而非"门禁拒绝" | `health-fix-2026-09b` 阶段 5 第 3 轮（2026-09-24 · 主 agent 编写 `reproduce-phase-gate.sh` 时实测；脚本内已注释"不得覆盖 HOOK_BASE_DIR"） |
| TD-059 | 🔴 | `flow-kit-bundle/hooks/stop/lib/done-validation.sh:35`（`fk_independent_review_gate_active` 末行 `[[ ! -f "$done_marker" ]]`）· `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh:174`（`_gate_active_check`）/ `:186`（`_gate_done_validation`）· `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh:58-110`（`_run_review_gates` Gate3/Gate4 次序） | **阶段门在 commit 路径上是「文件存在性」判定 ⇒ 配套的 Tier-1/Tier-2 标记校验不可达，任何同名文件（含 `touch` 空文件）都能让 commit 门禁失效**：Gate3 `_gate_active_check` → `fk_independent_review_gate_active` 在 `.specs/<id>/.independent-review-<phase>.done` **存在时返回「门未开」**（1）⇒ `_gate_active_check` return 0 ⇒ `exit 0` 放行；而 Gate4 的 `fk_validate_done_marker … transition`（≥6 行 / `-s` 非空 / 6 键 KVP `phase`·`change_id`·`written_by`·`L2_verdict∈pass|fail|skipped`·`L3_verdict∈pass|fail|timeout|error|skipped`·`artifacts` 含逗号 / Tier-2 比对 `INDEPENDENT-REVIEW-<phase>.md` 的 verdict）只在 Gate4 才跑，**而 Gate3 已在它之前放行** ⇒ 该校验对 commit 是一条死路径。2026-09-24 沙箱实测（`reproduce-phase-gate.sh` 状态 B2/B3）：标记内容与审查档口径相反（pass vs fail）⇒ rc=**0**；标记被删掉 `L3_verdict` 键（5 行，低于 `MIN_MEANINGFUL_LINES=6`）⇒ rc=**0**；仅"文件不存在"时 rc=2 且报文 `⛔ 独立 review gate：阶段 5 (5-test) 独立 review 未完成，禁止 git commit。`（状态 A）。唯一实际防线是 D7 path-guard，而它只对**命令文本**做文件名匹配（实测：含该文件名的 python heredoc 整条被拒，报 `agent 不得自产 .done 绕过 L3 审查…`；改用 edit 工具或程序化拼接文件名即可绕过）⇒ 「存在即放行 + 文本匹配守卫」的组合可被一次拼接绕过。**这不影响本 change 已归档的证据**（T19 的对象是 pre-push 拦截；本 change 的 commit 门禁证据全部来自显式调用 `.git/hooks/pre-commit`，且本仓 `core.hooksPath` 为空串、钩子并不生效 —— 见 TD-050） | **2026-09-24 用户裁决 + 本 change 内修复（T-FIX-02 · commit `6cff7a2`，已完成）**：Gate3 判定改为「存在**且有效**」—— 标记存在时调用 `fk_validate_done_marker "$done_marker" "$phase" "$change_id" transition`，空/`touch`、缺键、值域非法、`L2_verdict` 与审查档相悖（Tier-2）⇒ 一律拒绝（rc=2）；配套 `test/test_review_gate_validity.bats` 11 例常设判据（驱动真实 hook）+ `.specs/adr/029-gate-marker-validity.md`。下述 ① 已完成；② D7 path-guard 语义检测与 ③「verdict=fail 但口径一致」口径声明仍留 v2。原 v2 计划（存档）：① 把 `fk_independent_review_gate_active` 的判定从「存在」改为「存在**且通过 Tier-1 校验**」（复用 `fk_validate_done_marker`，tier 取 transition），使 Gate3 与 Gate4 的次序不再把校验变成死路径；② D7 path-guard 增加**语义**检测：对写入内容含 6 键 KVP 形态 / 目标路径经变量拼接的形态一并拒绝，并补 bats（`mktemp -d` fixture：`touch` 空标记 ⇒ 仍必须拒绝；`printf 'L2_verdict=pass\n'` 3 行标记 ⇒ 拒绝；合格 6 键标记 ⇒ 放行）；③ 明确「verdict=fail 但口径一致」是否应放行（当前实现放行：门保证"审查已发生且口径自洽"，通过与否由主 agent 负责 —— 该口径需在 `29-independent-review.sh` 头部与 `4-dev.md`/`5-test.md` 写明，否则读者会误以为门在判定 pass） | `health-fix-2026-09b` 阶段 5 第 3 轮（2026-09-24 · 主 agent 为响应 L3 第 3 轮 major 3（UAT ③ 需可运行复现）编写 `reproduce-phase-gate.sh` 时由 B2/B3 实测反推；**2026-09-24 用户裁决（option 1）改为本 change 内修** —— 阶段 5 L3 第 7 轮 M2 判定「UAT ③ 的 FAIL 与技术债登记不可与 pass 并存」⇒ 回退 4-dev 落 `T-FIX-02`（Gate3 判定改为「存在**且有效**」并复用 `fk_validate_done_marker … transition`，使 Gate4 的 Tier-1/Tier-2 不再被 Gate3 短路 + 新增 `ADR-029` + `./sync-hooks.sh` 6 副本 + 双态 bats）；**当时的不修理由（保留存档）**：属 `flow-kit-bundle/hooks/**` 生产件的语义变更，需 ADR/范围裁决，且本 change 的 AC-1..AC-8 未覆盖该面） |
| TD-060 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 `T-FIX-02 <verify>`（`:1558`：`SBX=$(mktemp -d "${TMPDIR:-/tmp}/tfix2-XXXXXX"); trap 'rm -rf "$SBX"' EXIT; cd "$SBX" \|\| exit 1;` 之后 `:1578-1584` 的 6 步 = 新 bats / `make check-hooks-sync` / `check-test-sync` / `check-dist` / `make check`）· 同族 = 任何在判据块内 `cd` 进夹具的 task · `.specs/health-fix-2026-09b/reproduce-5-test.sh`（在同一 shell 里顺序执行 12 条判据 + 7 条门禁，无 cwd 复位断言） | **判据块 `cd` 进沙箱后未回仓根 ⇒ 其后所有步骤在错误 cwd 上执行**（本 change 实测：恒 4 条 🔴 + `make: *** 没有规则可制作目标“check”。 停止。`，判据 rc=1，与交付物无关）：沙箱里既没有 `test/`（新 bats 找不到文件 ⇒ rc=1）也没有 `Makefile`（4 条 `make` 目标全报「没有规则」）⇒ **真交付物全绿也会被判据判红**（假红），并诱导错误处置（改判据让它变绿，而不是修 cwd）；反向风险同样存在 —— 若错误 cwd 恰有同名文件/目标，判据会在**错误的工作树**上判绿（假绿，TD-057/TD-059 同族）。放大面：`reproduce-5-test.sh` 在同一 shell 顺序执行全部判据，任一条判据的 cwd 泄漏会静默污染后续判据的 cwd 前提 | v2：① 判据块内 `cd "$SBX"` 必须配对复位（`cd "$REPO_ROOT"`）或用子 shell 隔离（`( cd "$SBX" && … )`）；② 静态检查接入 `make lint` 面（与 TD-057 ② 同一处）：判据块内出现 `cd ` 而块尾无复位/无子 shell 包裹 ⇒ 报警；③ `reproduce-5-test.sh` 每条判据在**独立子 shell** 中执行，并在其后断言 `[ "$PWD" = "$ROOT" ]`（cwd 未被判据改变），泄漏即判据失败；④ 交付前对判据块的「cwd / locale / 环境假设」做一次人工复核 —— 本 change 已两次踩到判据自身缺陷（TD-051 locale、本条） | `health-fix-2026-09b` 阶段 4 `T-FIX-02`（2026-09-24 · 执行者按「不改验收标准」原则如实上报 rc=1 与 4 条 🔴 的归因，主 agent 复核时在原判据上坐实并做**判据修复**：补 `REPO_ROOT="$PWD"` 与沙箱段末尾 `cd "$REPO_ROOT"`，步骤与断言逐字不动 ⇒ 原样复跑 **rc=0**，五态行 `A=2 B=0 B2=2 B3=2 B4=2 C=0`） |

| TD-061 | 🟡 | `.specs/health-fix-2026-09b/TEST.md` §1.3 覆盖率面 / §1.5 T5 维度 · `Makefile`（无 `coverage` 目标） | **行/分支覆盖率无任何数据 ⇒ 「测试质量」维度无法量化**：本机无 kcov/bashcov（亦未接其他覆盖率工具）⇒ §1.3 只能写「覆盖率无数据」、§1.5 的 T5 维度没有阈值可判；L3 第 11 轮 major 4 明确指出「合法缺口但需登记」。当前对「判据是否真覆盖分支」的替代证据 = 每条判据的桩态活性重放（F1 14 例转红 / 门禁 B2/B3/B4 转 rc=2）+ 双态夹具，属**存在性 + 反假绿**证据，不等于行覆盖率 | v2：① 接入 kcov（bash 覆盖）或 bashcov，`make coverage` 产出 per-file 行/分支覆盖率；② 在 TEST.md 记录阈值与实测值（例如 ≥70% 行覆盖）；③ CI 面加覆盖率门禁（与 TD-053 常设网同一处）；④ 若短期不接工具，则在 §1.5 把 T5 维度改判为「不适用（无工具）」并说明替代证据 | `health-fix-2026-09b` 阶段 5 第 11 轮（2026-09-24 · L3 第 11 轮 major 4） |
| TD-062 | 🟢 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:50-53`（change 副本回退读序里硬编码 `.specs/health-fix-2026-09b/`） | **常设门禁里出现一次性的 change id ⇒ 该分支随 change 归档即变死代码**：脚本按「常设清单 → 本 change 副本」的顺序解析允许清单，回退分支写死了本 change 的目录名；本 change 归档（`.specs/archive/…`）后该路径不再存在，分支永远走不到，而门禁自身不会报出这一失效（静默降级为「只用常设清单」）。同族风险：任何把 change id / 阶段号 / 轮次写进 `flow-kit-bundle/**` 常设件的写法（分发件不该知道具体 change） | v2：① 回退读序改为**参数化**（`FLOW_KIT_ALLOWLIST` 环境变量或 `--allowlist <path>`），删除硬编码目录名；② 在脚本头部注释写明「分发件不得引用具体 change id」；③ 加一条 bats：在无 `FLOW_KIT_ALLOWLIST` 且 `.specs/` 下无本 change 目录时，脚本必须只用常设清单且 rc 语义不变 | `health-fix-2026-09b` 阶段 6（2026-09-24 · REVIEW.md 🟢 F12，交阶段 7 triage） |
| TD-063 | 🟢 | `.specs/**`（31 个 tracked 文件含内部项目名）· 分发三面（`test/` · `flow-kit-bundle/test/` · 重建后的 `dist/dsh-flow-kit-0.2.0.tgz`） | **AC-5 的边界：`.specs/` 证据面仍是内部名的主要留存处**：本 change 的三条分发面已实测 0 命中（`chisel` 类内部名与真实账号路径），但仓内 `.specs/**` 仍有 31 个 tracked 文件含内部项目名 —— 这些文件不进分发件，故不违反 AC-5 的「不随分发件出厂」，然而一旦有人把 `.specs/` 目录整体打包或把证据文件复制进 bundle，边界即被越过；当前门禁只查 `/home/<acct>/` 形态，不查内部项目名 | v2：① 把「内部项目名」纳入机器门禁（与 `check-path-privacy.sh` 同一脚本或独立 `check-internal-name.sh`），扫描面按「分发面必过 / `.specs/` 警告」分档；② 在 `package-flow-kit.sh` / `package-dsh-plugin.sh` 的打包清单里加断言：归档内不得出现内部名；③ 文档层明确「`.specs/` 是内部证据区，永不进分发」 | `health-fix-2026-09b` 阶段 6（2026-09-24 · REVIEW.md 🟢 F17，交阶段 7 triage） |
| TD-064 | 🔴→🟢 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（修复前 392 行）· F1 = `:75-77`（`TMP_X=$(mktemp)` 三处无 rc 断言）/ `:105-111`（两处 `cp -- … "$TMP_ALLOWLIST"` 无 rc 断言）/ `:203-209`（`git ls-tree` / `git ls-files` 无 rc 断言）/ `:285,309`（`grep` rc + stderr 被 `2>/dev/null \|\| true` 吞）；F2 = `:369-374` 自证行无「候选文件 N 个」+ `:391` 0 命中 ⇒ ✅ rc=0（0 候选同形） | **F1（机械/工具故障 fail-open）+ F2（0 候选与干净同形）**：阶段 6 REVIEW §B 两 🔴。F1 把 `mktemp`/`cp`/`git ls-files`/`grep` 的失败折算成「0 命中 ⇒ ✅ rc=0」—— 坏 TMPDIR 链路上仓内真泄漏仍 rc=0（fail-open）；F2 候选枚举产物无任何非空断言，0 候选面（非 git 目录 / git 仓但 index 为空 / 损坏 index / 空 rev）与「全部干净」同形（都输出「命中合计 0 条 ✅」⇒ rc=0）。跨模型 spot-check（`qwen3.8-flash`）独立复现，追加三点：`cp` 的 rc 必须一并断言；0 候选须覆盖「非 git」与「git 仓但 index 空」**两型**；F1 行号勘误 `:75-77` + 新增 `:105-111`。同族三条 🟡：F3（两模式二进制策略相反：工作树 `grep -nE` 静默丢弃二进制 ⇒ 假绿；rev `git grep` 把 `Binary file…matches` 当命中解析 ⇒ 假红且不可归因）；F4（注释口径两套：校验器 `:144-147` 认 `#` 与 `<!--`，计数器 `:198`/`:341` 只认 `#` ⇒ `<!-- … -->` 行被计为有效条目，自证行「允许清单 N 条」虚高）；F5（临时文件清单两份 + 第二个 `trap … EXIT` `:340` 覆盖 `cleanup()` ⇒ 首次登记的临时文件失联，漏 rm） | v2：① F1 `mktemp`/`cp`/`git ls-tree`/`git ls-files`/`grep` 全部 rc 断言 + stderr 不丢，失败 ⇒ `🔴 无法完成扫描：<原因>（<file:line>）` + exit 1；`|| true` + `2>/dev/null` 只出现在已断言 rc 之后；② F2 自证行含「候选文件 N 个」并与 `git ls-files \| wc -l` 一致，N=0 ⇒ `🔴 候选面为空，无法判定` + exit 1（两型覆盖：非 git 目录 + git init 但 index 空）；③ F3 两模式统一 `grep -aE`（工作树）/ `git grep -nEa`（rev），命中读取端断言 line 字段匹配 `^[0-9]+$`，否则按不可归因命中单列 + fail-closed；④ F4 注释口径单点（`IS_COMMENT_OR_BLANK_RE='^[[:space:]]*(#\|<!--\|$)'`，校验器与计数器共用）；⑤ F5 单一 `TMP_FILES` 清单 + 单一 `trap cleanup EXIT`。双态判据 11 例（test_path_privacy_gate.bats）已补 | **阶段 6 REVIEW 发现 · 本 change 内修复（T-FIX-03）**：阶段 6 双轮审查（2026-09-24 · REVIEW.md §B 🔴 F1/F2 + 🟡 F3/F4/F5）发现，同 change 回退 4-dev 落 T-FIX-03；`out=$(… \|\| true)` / `2>/dev/null` 全部收敛为「rc 已断言后允许」，0 候选面 fail-closed，双态 11 例常设判据 + `make check-nfr-portability`（bash 3.2 兼容）已过 |
| TD-065 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 `T-FIX-04 <verify>` F6 夹具（`hidden=$(cd "$SBX/fk" && ls flow-kit-bundle/skills/*/SKILL.md 2>/dev/null | head -1)`，修复前 `TASK.md:1610`） | **判据夹具用「文件系统枚举的偶然顺序」选取被操作对象 ⇒ 判据与被测数据脱钩**：`ls … | head -1` 取字母序首个 skill = `flow-architect`，而生产件 `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh:37-40` 的 `PAIRS` 只含 `flow-evolve` / `flow-intel` / `flow-restyle` ⇒ 隐藏非比对对成员时 `MISS=0`，修复后代码的**正确**行为（汇总仍打印 `✅ 校验对 3/14 一致`）被判据报成 🔴「F6：缺一对文件仍 rc=0」⇒ `<verify>` 恒 rc=1、T-FIX-04 无法提交（执行者依硬规则 2「判据自身缺陷停下原样上报」停下；主 agent 坐实后修判据：改为从 `PAIRS` 声明的 `|<skill>` 形态派生首个真实成员 + 前置 `[ -f ]` + 集合成员断言）。同族风险：任何「从目录枚举 / 通配取一个样本」却不断言该样本**属于被测集合**的夹具（TD-060 是同一「判据自身缺陷」家族的另一支：cwd 泄漏） | v2：① 夹具样本一律**从被测数据的权威来源派生**（本例改从 `PAIRS` 提取，已落地）；② 取到样本后断言 `[ -f ]` 且属于被测集合，否则夹具自身 fail-closed 打印「判据前置失败」；③ `make lint` 增静态检查：`<verify>` 块内出现 `ls … | head -1` / `find … | head -1` 形态且未断言集合成员关系时告警 | `health-fix-2026-09b` 阶段 4（2026-09-24 · T-FIX-04 执行者上报 + 主 agent 坐实并修复判据） |
| TD-066 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 T17 `<verify>` CHECK_REV 对照夹具（`_sbx2/r` tracked 面 = 被测脚本 + 空 `path-privacy-allowlist.txt`；主 agent 订正后新增 `README.md`） | **判据夹具的候选面必须非空**：T-FIX-06（F-19）在 `check-path-privacy.sh` 引入 fail-closed（自排除后 `SCANNED_COUNT=0` 且 `CANDIDATE_COUNT>0` ⇒ 🔴 + `exit 1`）后，T17 的「干净树 · 工作树模式必须 rc=0」对照腿的 tracked 面**恰好全部命中 `SELF_EXCLUDE`**（SUT + 允许清单）⇒ 候选 N≥1、实际扫描 M=0 ⇒ 判红 `🔴 工作树模式在干净树上未 rc=0（rc=1）⇒ 对照不成立`（REPRO6 `bash-315` 实测）。性质 = **判据夹具与被测语义不一致**（TD-060 / TD-065 同族），非生产件回归 —— 同轮其余 17 条判据 + 7 项门禁全绿 | v2：① 凡断言「rc=0 干净态」的夹具必须保证候选面含 ≥1 个非自排除文件（本例已加 `README.md`）；② `make lint` 增静态检查：`<verify>` 内以 `mktemp -d` 建仓、只 `cp` 被测脚本即断言 rc=0 的形态告警（与 TD-065 的 `ls … | head -1` 检查同批） | `health-fix-2026-09b` 阶段 5 重验（2026-09-25 · REPRO6 T17 判红 + 主 agent 坐实并订正夹具） |
| TD-067 | 🟡 | `.specs/health-fix-2026-09b/reproduce-5-test.sh` 的 `extract_verify()`（`<verify>` / `</verify>` 行内子串匹配；主 agent 订正为整行锚定 `^[[:space:]]*<verify>[[:space:]]*$`） | **L-153 族复发（未锚定的标签抽取）**：抽取器按行内子串匹配 `<verify>`，而 TASK.md 的 T-FIX-06 `<action>` 正文含 `<verify>` 字样 ⇒ 抽取起点被拉进 action 段，产出「散文 + `</action>` + 判据正文」的 43 行废件 ⇒ `v_T-FIX-06.sh` 行 1 报 `T-FIX-06-SUMMARY.md: 未找到命令`、行 2 报 `未预期的记号 "newline"` ⇒ REPRO6 把 **rc=2 记成判据失败（假红）**。同族：L-153（非锚定 `sed` 抽取）、TD-065 / TD-066（判据夹具与被测数据脱钩）—— 三者同属「判据/工具与权威文本的耦合面失配」 | v2：① 抽取标签一律整行锚定（已落地）；② `make lint` 增静态检查：抽取器出现未锚定的 `<tag>` 匹配形态时告警；③ 抽取后加**前缀形态断言**（首行须匹配判据正文形态，否则判据自身 fail-closed 打印「抽取前缀异常」）—— 现有仅有 `<3 行` 下限断言，抓不住这种前缀污染 | `health-fix-2026-09b` 阶段 5 重验（2026-09-25 · REPRO6 T-FIX-06 抽取假红 + 主 agent 坐实并订正抽取器） |
| TD-068 | 🟡 | `.specs/health-fix-2026-09b/reproduce-5-test.sh` 门禁面 `[C]` 的自证行**显示正则**（4 类字段白名单；主 agent 订正为 7 字段白名单） | **证据面裁剪（回执与生产件输出不自洽）**：生产件 `check-path-privacy.sh:562-569`（`T-FIX-06` = `421640a`）在 happy path 打印 **7 行**自证（多出 `允许清单 N 条` / `候选文件 N 个` / `实际扫描 M 个`），而复现器正则只列 4 类 ⇒ 第 8 次执行回执 `§P-3c` 只留 5 行，恰把 F-19 的两个计数裁掉 ⇒「F-19 已闭合」在回执层不可独立复核（由 L2 第 4 轮盲审独立发现 R1） | 主 agent 就地订正复现器显示正则（**不改 rc 与判定面**）+ 回执 `§P-3c` 按原始 `/tmp/fk-reproduce-5-r7/privacy.txt` 全文 7 行重贴并标注原始路径 + 写入 `MINOR-DEFERRED.md` 与独立审查档 | v2：复现器/回执对生产件输出的过滤**不得窄于**生产件自证字段集（与 TD-065 / TD-067 同族：证据与工具面不得裁剪被审输出） | `health-fix-2026-09b` 阶段 5 重验（2026-09-25 · L2 第 4 轮 R1 + 主 agent 坐实并订正） |
| TD-069 | 🟡 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh:58`（`max_bytes` 解析：`FLOW_KIT_L3_MAX_ARTIFACT_BYTES` → 旧名 → 默认 80000）· `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:270`（截断**仅 stderr 告警**）· `l3-review.sh:117-140` + 重跑守卫（`skipping L3 for phase 5 (artifact hash 不变 + ## L3 段非空)`） | **L3 信封预算与重跑守卫的交互 ⇒ 截断不可补救，且工件上看不到截断**：阶段 5 第 13 轮实测 `完整 303899B → 实送 299999B（丢弃 1%）`；被丢弃的是**尾部**（`=== T-FIX-05-SUMMARY.md ===` 段末约 900 B + 整段 `=== T-FIX-06-SUMMARY.md ===` 3000 B，补充产物各 3000 B 预算叠加后溢出总量上限），主审面 `TEST.md`（181036 B）完整送达 ⇒ 本轮判定面未受影响。**提高上限后重审被守卫跳过**（`FLOW_KIT_L3_MAX_ARTIFACT_BYTES=400000` ⇒ 守卫按工件哈希判定，哈希未变即 skip）⇒ 「先送审、再发现截断」的时序下没有任何补救路径；且 README/工件层面看不到截断事实（只在 stderr） | 本 change 处置：① 在 `INDEPENDENT-REVIEW-5.md` 主 agent 响应节与 `PHASE5-RECEIPTS.md` §Q 写明字节账与「被丢尾部为次要产物」；② **不为此改动 `TEST.md`**（人为改哈希会制造「为过审而改工件」的伪证据）；③ 登记本债。v2：① 截断事件落工件（L3 段头一行 `L3_envelope: 303899→299999 (truncated)`）；② 重跑守卫把「截断」纳入重跑条件（哈希未变也重跑）；③ `max_artifact_bytes` 支持按总量自动分配并**先裁补充产物清单**、再裁主审件，裁剪结果一并披露 | `health-fix-2026-09b` 阶段 5（2026-09-25 · L3 第 13 轮截断告警 + 主 agent 尝试提高上限重审被守卫跳过） |
| TD-070 | 🟡 | 审计/执行 subagent 的派发契约（本 change 阶段 6 第 3 轮：审计 #2 + ADR-014 spot-check 第 3 轮）· `.git/config` 的 `core.quotePath` · `.specs/health-fix-2026-09b/path-privacy-allowlist.txt` · 仓库根探针 `中 文名.md` | **「只读契约」没有可执行断言 ⇒ 审查者能改被审对象，且改动藏在 index/配置面**：第 3 轮收工实测仓库多出三项真实改动 —— ① **index 篡改**：change 副本 allowlist（`check-path-privacy.sh` 的读源之一）被改成单行 `# 空清单`，16 行文档头（含 R3 棘轮「只降不升」与脱敏背书）被删；② **暂存探针** `中 文名.md`（A 状态，内容含探针路径）；③ `.git/config` 的 `core.quotePath` 覆盖（调试遗留 ⇒ 会让 R3-1 类假绿按配置时隐时现）。三者都不在「工作树 diff」的默认视野里（`git diff` 看不见 staged；`git config` 连 `git status` 也不报），只看工作树或只看 `git status` 摘要都会漏判 | 主 agent 已清理并复核：`git checkout HEAD -- <allowlist>` · `git reset` · `rm` 探针 · `git config --unset core.quotePath`；`git diff HEAD --stat` 复核确认改动面只剩本 change 的 3 个 `.specs` 工件、**生产件零差异**，方可安全回退重做；并沉淀 `L-161` + 后续派发词统一加「开工/收工各报 `git status --porcelain` + `git diff --cached --stat`，写入面只允许 `/tmp`」。v2：① 把该收工断言做成脚本（`scripts/assert-repo-clean.sh`）并纳入门禁；② subagent 派发模板（`flow-kit-bundle/flow-kit/prompts/independent/*.md`）内置状态断言段 | `health-fix-2026-09b` 阶段 6 第 3 轮（2026-09-25 · spot-check 回执提及主仓残留 + 主 agent `git status --porcelain` 复核坐实并清理） |
| TD-071 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 T-FIX-08 块（`<read_files>` / `<write_files>` / `<action>` ③ / `<verify>` 第 9 行**四处**写 `install.sh`，而仓根无此文件、真件为 `flow-kit-bundle/install.sh`；主 agent 于阶段 4 订正四处） | **判据目标路径的前缀遗漏 ⇒ 判据只能靠「新建假文件」满足**：`<verify>` 第 9 行 `grep -qE 'jq' install.sh`（仓根相对）在真实布局下**恒 rc=1**，而同一块的下一行却正确写成 `flow-kit-bundle/README.md`；执行者（subagent `18e2e1c9`）按硬规则 6 停下并给出两条路径 —— A「判据缺陷」/ B「在仓根新建 install.sh」。B 会凭空造出一个不安装任何东西的仓根安装器（污染分发面与语义），并让「R3-21 已在安装器入口预检 jq」变成假证据 | 主 agent 坐实「仓内仅 `flow-kit-bundle/install.sh`（16652 B），其内当前**无** `jq` 字样」后：四处路径全部订正为 `flow-kit-bundle/install.sh`（`<verify>` 断言语义、场景数、其余行一字不变），并在块内追加「契约修订留痕」段；同族 = TD-065 / TD-066 / TD-067（判据与权威布局失配） | v2：① `make lint` 增静态检查：`<verify>` 内的相对路径参数（`grep` / `[ -f ]` / `cp` 的目标）必须在仓根真实存在，否则告警；② 派发前由主 agent 对判据内出现的每个路径做一次 `ls` 实测（与 L-162 的「行区间必须实测」同一批）；③ 任务块模板要求 `<write_files>` 路径写全前缀 | `health-fix-2026-09b` 阶段 4（2026-09-25 · T-FIX-08 执行者按硬规则 6 上报 + 主 agent 坐实并订正判据路径） |
| TD-072 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 T-FIX-09 `<verify>`（三处：`FXRUN()` 内 `NRC=$?` · `FXM()` 的 `tracked` 分支只改文件不提交 · R3-22 全量模式夹具的样本为 untracked） | **判据夹具与外壳语义失配（同 TD-066 族 · 三支）**：① `FXRUN() { ( … ); NRC=$?; }` 被 `OUT=$(FXRUN)` 调用 ⇒ 函数体在**子 shell** 中执行 ⇒ 外层 `set -u` 下 `$NRC` 未绑定 ⇒ 每条 `[ "$NRC" -ne 0 ] || { 🔴 … }` 都走失败分支（或被 `set -u` 直接终止）⇒ 判据恒红且**与交付物无关**；② `tracked` 面夹具把探针**追加到已跟踪文件却不提交**，而被测面是 `git diff --name-only "$BASE" -- "*.sh"`（`Makefile:168`）⇒ `BASE` 指向改动前提交 ⇒ 样本不在 diff 面内 ⇒ 该腿实际只测 untracked 面（**假通过**）；③ R3-22 全量模式夹具把违规样本写成 untracked 文件，而全量模式按设计只扫 tracked `.sh` ⇒ 判据必红 | 主 agent 在**派发前预检**（TD-071 v2 ② 的落地）中坐实三处并订正：`FXRUN` 只返回状态、三个调用点改 `OUT=$(FXRUN); NRC=$?;`；`tracked` 分支追加 `probe` 提交且 `BASESHA` 在探针落盘**前**捕获；R3-22 样本入库。块内追加「判据修订留痕」段；锚定抽取 102 行 `bash -n` ✅ | v2：① `<verify>` 里凡「函数内赋值 + 命令替换调用」形态一律改为 `out=$(fn); rc=$?;`（或函数内 `printf` + 调用点捕获）；② 判据夹具样本面必须与**被测枚举面同源**（tracked 面样本必须入库、untracked 面样本必须不入库）并在块内写明对应关系；③ 派发前把 `<verify>` 抽出来空跑一遍，凡出现 `unbound variable` 或与交付物无关的 🔴 ⇒ 判据缺陷 | `health-fix-2026-09b` 阶段 4（2026-09-25 · 主 agent 派发前预检 T-FIX-09 判据并订正） |
| TD-073 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 T-FIX-10 `<verify>`（原判据五处：`wc -l > 0` 恒真断言 · 夹具只 `cp 4-dev.md`（非 PCSC 对成员）· R3-20 夹具 `chmod 000` 的**目标未创建** · 空预设夹具的集合**只清一侧** · 静态 `grep 'skill 侧'` 修复前即命中） | **判据「非判别性」：修复前后同为绿 ⇒ 对所修缺陷无鉴别力**：① `wc -l > 0` 恒真（脚本首行即打印标题）⇒ R3-19 的静默中止**永远**抓不到；② 夹具缺 3 对 PCSC 载体 ⇒ 提前 `🔴 DRIFT` ⇒ 后续断言被前序错误掩盖；③ `chmod 000` 的目标在本次夹具里未创建（被 `2>/dev/null \|\| true` 吞）⇒ `diff` 从未返回 rc=2；④ 只清 `SKILL.md` 一侧 ⇒ 集合不等 ⇒ 走 DRIFT 分支，永远到不了 `:196` 的计数行；⑤ 静态 grep 命中原位代码字样 ⇒ 无鉴别力。同族 = TD-060 / TD-065 / TD-066（判据自身缺陷）但性质更重：**判据绿不代表缺陷已修** | 主 agent 派发前预检坐实并**重写判据**：完整夹具生成器 `FXB()`（3 对 PCSC 载体 + `skills/flow/SKILL.md` + `test/test_gate_config_presets.bats`）+ **基线绿腿**（夹具不绿即打印「判据前置失败」）· R3-18 改 prompt 侧/skill 侧**双向反向控制**（各自断言具名侧 + 断言不误报另一侧）· R3-19 改**两侧集合同时清空**并断言「`── 校验汇总 ──` 或具名 🔴」· R3-20 改 **PATH 影子 `diff`（恒 exit 2）** 并断言 rc≠0 + 具名 🔴；锚定抽取 72 行 `bash -n` ✅ | v2：① 判据必须含**反向控制**（同夹具的应绿态），且前置失败即停；② 断言不得取恒真式（`wc -l > 0`、命中原位代码的关键字 grep）；③ 「故障场景」用**可移植注入**（PATH 影子 / 环境变量）构造，不得依赖可能被 `\|\| true` 吞掉的 `chmod`；④ 派发前把夹具在真仓空跑一次，确认「修复前必红 / 修复后必绿」 | `health-fix-2026-09b` 阶段 4（2026-09-25 · 主 agent 派发前预检 T-FIX-10 判据并重写） |
| TD-074 | 🟡 | `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:51`（`declare -A PHASE_ARTIFACTS=(`，**无版本守卫**）· `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh:100`（`declare -A keep_line`）与 `:167`（`mapfile -t tail_lines <<< "$text"`）· `flow-kit-bundle/hooks/stop/lib/common.sh:432`（`declare -A _FK_PERF_TIMINGS 2>/dev/null \|\| true`，**有**守卫）· `package-flow-kit.sh:394`（`declare -A BROOKS_TOOLS`）· `sync-hooks.sh:182/197/198` 与 `verify-claims.sh:119/135`（`mapfile -t …`）· `flow-kit-bundle/lib/install_brooks.sh:125`（`sed -i`）· `flow-kit-bundle/hooks/stop/00-gate.sh:71` 与 `flow-kit-bundle/hooks/stop/lib/l3-review.sh:211`（GNU `timeout`） | **分发/运行时件里的 bash4-only 与 GNU-only 构造既无守卫、也一直躲在本仓 NFR 判据的盲区里**：判据（`Makefile` 的 `check-nfr-portability-internals`）只在 **diff 新增行** 面上扫描 ⇒ 老文件的违规永远不可见；而这与仓内自述的「bash 3.2（macOS 默认）兼容」承诺冲突 —— `grep -rn BASH_VERSINFO` 在 `flow-kit-artifacts.sh` / `l3-truncate.sh` 中 **0 命中**，macOS 上未装 Homebrew bash 时 `declare -A`/`mapfile` 直接报错（artifact 门与 L3 截断链不可用），`timeout` 在 macOS 亦不存在（须 `gtimeout`）。**本 change 阶段 4 首次暴露**：`T-FIX-09` 把「无锚点」路径从静默 `SKIP（未验证）` 改成**全量模式**（R3-22 修复）后，主 agent 用判据自身的两条正则（`Makefile:268` 的 `TMOUT` 与 `BAN` 面；剔注释行、按门的 `gsub` 剥掉 `stat -c…\|\|stat -f…` 双形态）在真仓 tracked `*.sh`（104 个）上实测 **BAN 19 处 / 12 文件 · TMOUT 14 处 / 7 文件**（BAN 的 `declare -A`/`mapfile`/`sed -i` 为真命中；TMOUT 有若干是 `echo`/`case` 里的散文，属正则误报）⇒ **全量模式在本仓本就该红**（fail-closed，符合 R3-22 意图；`.specs/archive/**` 的历史脚本另贡献 `-printf`/`declare -A`/`stat -c` 命中） | v2：① `fk_artifact_check` 的 phase→artifact 映射改 `case` 分支或 bash 3.2 可用的并行数组（消 `declare -A`）；② `l3-truncate.sh` 用 `while read` 累加替代 `mapfile`、用 `case`/字符串表替代关联数组；③ `timeout` 统一走 `gtimeout \|\| timeout \|\| 无超时` 探测；④ 判据面从「仅 diff 新增行」扩到**新增/修改文件的整文件**（否则老文件违规永不可见 —— 本债正是被该盲区掩盖）；⑤ 分发件加一条「无 bash4-only 构造」的常设 bats（整仓面，不按 diff） | `health-fix-2026-09b` 阶段 4（2026-09-25 · `T-FIX-09` 全量模式落地时主 agent 用判据正则实测真仓坐实；判据面修正由 T-FIX-09 交付） |
| TD-075 | 🟡 | `Makefile:8-11`（`test:` 目标） | **「失败时隐藏失败用例 id」+ 套件重复运行**：第 10 行 `@npx bats test/ --formatter tap 2>&1 \| tail -3` 无论成败只打印 TAP **末 3 行**，且管道退出码恒 0（该行不承担判定）；第 11 行 `@npx bats test/ > /dev/null 2>&1 && … \|\| { echo "❌ bats: some tests failed"; exit 1; }` 才是唯一判定 ⇒ 套件一红，终端只剩「some tests failed」，**必须手工重跑 `npx bats test/` 才能定位失败用例**（本 change 阶段 4 复跑 `make check` 时实际踩到：只见 `❌ bats: some tests failed` + `make: *** [Makefile:11：test] 错误 1`，无法判断是哪一例）。同时套件被**跑两遍**（1054 例 ×2 ⇒ 约 2× 时长与 CPU） | v2：① 失败时打印 `not ok` 行集合与失败计数（`… \| tee "$TMP" >/dev/null; grep -E '^not ok' "$TMP"`）；② 去掉第一遍空转（一次运行 + `tee`，成败与诊断同源）；③ 复用 `check-test-sync` 已有的 TAP 计数口径 | `health-fix-2026-09b` 阶段 4（2026-09-25 · 主 agent 复跑 `make check` 被隐藏的失败用例 id 卡住 ⇒ 记入阶段 7 triage） |
| TD-076 | 🟡 | `.specs/health-fix-2026-09b/TASK.md:2329` + `:2341`（T-FIX-11 `<verify>`） | **判据自缺陷（夹具内相对路径 ⇒ rc=127）**：`S=flow-kit-bundle/flow-kit/reference/check-path-privacy.sh;`（相对仓库根）配合 `FXR() { ( cd "$FX" && FLOW_KIT_PRIVACY_ALLOWLIST="$AL" bash "$S" 2>&1 ); }` ⇒ 一进 mktemp 夹具仓就解析不到被测件，**四腿全部 rc=127**（与 TD-060 同族：判据在 cwd 变化后仍用相对路径）。T-FIX-11 执行者按 L-166 未自行放宽，改用绝对路径 S 跑通四腿 + bats + 真仓 + 三一致性 + `make check`（意图与判据一致），并主动上报 | 2026-09-25 主 agent 就地修 `S="$R/flow-kit-bundle/flow-kit/reference/check-path-privacy.sh";`（`R=$(pwd)` 已在判据首行定义，不改判据语义）；内务检查项：凡 `<verify>` 内会 `cd` 进夹具的命令，被测件/允许清单/锚点路径一律以 `$R/…` 绝对化（与 TD-060 合并为同一检查项） | `health-fix-2026-09b` 阶段 4（T-FIX-11 执行者上报 + 主 agent 复核确认） |
| TD-077 | 🟡 | `.specs/health-fix-2026-09b/reproduce-5-test.sh` 的 `[D]` 段（第 9 次执行版：`emit_gate "NFR ≤5s ×5" 0 "…"`，rc **硬编码 0**）· `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:586`（每候选一次 `git grep --cached -naE --null … -- "$file"`） | **判据「不判」⇒ 缺陷穿过「全绿」**：复算脚本把 NFR 的 5 次实测值原样打印、却把该门禁的 rc 写死为 0 ⇒ 阶段 5 第 9 次执行实测 `10.741/10.885/10.783/11.510/11.469 s`（**均值 11.078 = 预算 221.6%**，`REQUIREMENT.md:495`「≤5 秒」/ `TEST.md:248`「超阈值即未满足」）仍被输出为 ✅、脚本总退出码 `rc=0`「复算全绿」，红面只能靠人逐行读原文发现。同族 = TD-064 / TD-065（判据自身缺陷）。连带根因：`T-FIX-07` 为 R3-2 引入的**逐候选** `git grep --cached`（1594 次进程）把门禁 real 从 3.191 s 推到 10.778 s | 主 agent 同批修 `[D]` 段为**真断言**（逐次解析 `real=`、`awk` 判 `>5`、打印 max/均值/预算百分比，超限 ⇒ `emit_gate … 1` ⇒ `GATE_FAIL=1` ⇒ `exit 1`；脚本 231→268 行；用第 9/第 8 次实测值 + 边界 5.001 三态单测）；性能回归本身追加 **`T-FIX-12`**（index 侧扫描批量化；`TASK.md:2390-2489`，`depends_on T-FIX-07`）。v2：① 复算脚本内**禁止** `emit_gate <名> 0`（数值型判据必须真比较）；② 收工结论必须逐面给 ✅/❌，不得用总退出码替代 | `health-fix-2026-09b` 阶段 5 第 9 次执行（2026-09-25 · 主 agent 逐行读原始输出发现 · A/B 归因 `7b624dc` 3.191 s vs `20847e1` 10.662 s vs HEAD 10.778 s · 微基准 4.28 ms/次 vs 全量一次 0.023 s） |
| TD-078 | 🟢 | `.specs/health-fix-2026-09b/TASK.md:2390` 的 T-FIX-12 `<read_files>`（写「`test/test_path_privacy_gate.bats`（34 例）」）与 `test/test_path_privacy_gate.bats` 的实际例数 | **任务简报的事实性错误（TD-071 / TD-073 家族）**：主 agent 在 T-FIX-12 简报里把隐私套件例数写成 34，实测 `npx bats test/test_path_privacy_gate.bats` = **30 例**（30 ok / 0 not-ok）；执行者正确地**没有凭空新增 4 例**去凑数，而是按既有 30 例验收（纯性能修复、判据语义不变）并主动上报差异。危害面 = 简报失真可能诱导执行者「为对齐简报而改判据」 | 主 agent 已记录，执行者结论未受影响。v2：① 派发前对简报内出现的每个**计数**（例数 / 行数 / 任务数）跑一次实测（与 TD-071 v2 ②「路径实测」、L-162「行区间实测」合并为同一检查项）；② `TASK.md` 模板要求 `<read_files>` 的计数由脚本生成 | `health-fix-2026-09b` 阶段 4（2026-09-25 · T-FIX-12 主 agent 独立复核时坐实） |
| TD-079 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 T-FIX-08 块（`:2025` `status="pending"` + `:2112` `<done></done>`）与 T-FIX-09 块（`:2116` `status="pending"` + `:2199` 空 `<done>`）· 派发契约的字面冲突（`<write_files>` 不含 `TASK.md`，收工指令却要求「勾 `status="done"` + 写 `<done>` 注记」） | **派发契约自相矛盾 ⇒ 任务状态在文件面上不可满足，且无任何门禁机械检出**：T-FIX-08（commit `2f01f3975b2056c2b16f6db6cdcab7e3f7b3a5a2`）与 T-FIX-09（`81c920e61101f599bf9e29f7ec5bc3dbe429a887`）两位执行者都只改了自己 `<write_files>` 内的生产件（`<verify>` 全绿、bats 与门禁全绿），但**没有回写 `TASK.md`** —— 因为 `TASK.md` 不在其写面内（越界即违规）。结果两块停在 `pending` + 空 `<done>`，而「所有 task = done」正是 4→5 / 5→6 收费门的触发条件（`flow-kit-bundle/flow-kit/prompts/4-dev.md:113-144`）⇒ **门条件在文件面上不可满足**，直到主 agent 在 4→5 门前逐块核对才发现（`make check` 与 `done-validation.sh` 都不看 task status，全靠人眼） | 主 agent 已就地补齐（`status="done"` + 完整 `<done>` 注记含 commit sha / verify 结论 / 复核结论；补齐后 41/41 task 均 done、不变量 41/41/41/41/41）。v2：① 派发契约模板二选一 —— 把 `TASK.md` 显式列入 `<write_files>`，或改为「状态回写由主 agent 统一执行」并从收工指令删除该条；② 增设机械断言（`check-task-status.sh`）：某 `<task>` 的 `status≠done` 但对应 `T-*-SUMMARY.md` 已存在 ⇒ 报警；③ 该断言接入收费门前置检查 | `health-fix-2026-09b` 阶段 4（2026-09-25 · 主 agent 4→5 门前核对 TASK.md 时坐实，命中 2/12 fix 任务） |
| TD-080 | 🟡 | `.specs/health-fix-2026-09b/TASK.md:1003` 的 T22 `<verify>`（`cp .specs/CONTEXT.md /tmp/l133-bak` + `trap` 恢复 + `printf '<!-- mixed: %s %s -->\n' "/home/$(whoami)/x" "/home/user/y" >> .specs/CONTEXT.md` + 结束时 `cp -f /tmp/l133-bak .specs/CONTEXT.md`） | **判据在真仓共享 tracked 文件上注入探针 ⇒ 与并发编辑互相破坏**：T22 为验证「同行真名 + 占位必须被抓」而把真实形态探针临时追加进**真仓** `.specs/CONTEXT.md`，再以 `/tmp/l133-bak` 整体覆盖恢复 ⇒ ① **并发编辑被静默抹掉** —— REPRO9（job `bash-354`）运行期间主 agent 写入的 `TD-078` 行被恢复动作覆盖（文件 740 → 738 行、`grep -c TD-078` = 0，无任何提示）；② **并发门禁假红** —— 同时运行的 `make check-path-privacy` 扫到瞬时探针 ⇒ `🔴 清单外命中 1 条`（归因 `.specs/CONTEXT.md:740: <!-- mixed: … -->`，rc=1）；③ **提交面污染风险** —— 若此刻有 `git commit` 命中该文件，真实形态探针（`/home/<真实账号>/x`）会被写进提交。同族 = TD-070（审查/执行期的仓库态污染） | 主 agent 已重写被抹掉的 `TD-078` 并沉淀 `L-169`；**本 change 不改该判据**（属验收标准原文，改动需另起 task 并重跑全量判据）。v2：① 探针目标改为**专用 tracked 探针文件**（如 `.specs/<change-id>/probe-fixture.md`，随 change 归档即消失）或夹具自建临时 git 仓，不再触碰 `CONTEXT.md` 等共享件；② 必须动共享件时加 `flock` 互斥并在复现脚本头部声明；③ `reproduce-5-test.sh` 运行期打印「本期间禁止编辑判据触面文件」；④ 恢复后用 `cmp -s` / 哈希比对**证明**恢复完整，不一致即报警而非静默覆盖 | `health-fix-2026-09b` 阶段 4（2026-09-25 · REPRO9 运行期间主 agent 实测坐实） |
| TD-081 | 🟡 | `.specs/health-fix-2026-09b/TASK.md` 的 T-FIX-13 `<verify>` 初版（L3 之后直接 L4/L5；夹具只 `cp` 检查器，见初版 `:2529`） | **判据夹具与语义脱节 ⇒ 腿的标注状态与实际不符，并与另一腿互斥**：L4「两者皆在 + 干净 ⇒ rc=0」与 L5「两者皆在 + 真泄漏 ⇒ rc≠0 且含 `含路径隐私泄漏`」被标注为「两者皆在」，但夹具全程**从未创建** `$SBX/reference/path-privacy-allowlist.txt` ⇒ 两腿实际运行在**缺陷态**；于是 L2d（缺陷态**不得**出现 `含路径隐私泄漏`）与 L5（同态同输入**必须**出现该串）**互斥** ⇒ 判据不可满足（任何正确修复都至少一腿红）。同族 = TD-073 / TD-065 / TD-072（判据自身缺陷）；本次由**执行者与主 agent 各自独立发现**（先红预跑只暴露 L2a–L2g/L5 的 rc 红，未暴露该互斥） | 主 agent 就地修订判据：新增 **L3d**（fixture allowlist 就位 + 断言）与 **L4c**（pre-commit 反向控制：两者皆在 + 真泄漏 ⇒ rc≠0）；L2/L3/L6 断言一字未改（不放宽）。v2：① 判据夹具的**状态切换必须显式**（每段前断言并打印当前态：`none` / `bundle+no-list` / `bundle+list`），腿名按态命名；② 派发前预跑除看红腿集合外，还须做**互斥性检查**（同一 `pp "$X"` 输入在不同腿上的期望输出不得互相否定）；③ `make lint` 增静态检查：`<verify>` 标称某态却从未构造该态所需证据文件（如 allowlist）时告警 | `health-fix-2026-09b` 阶段 4（2026-09-27 · T-FIX-13 执行者 `3add4b81` 停下上报 + 主 agent 独立复核一致后修订）。**复发（2026-09-28 · `T-FIX-14` 主 agent 独立夹具）**：`/tmp/p6d/v14-main2.sh` 在**已装 pre-commit** 的临时项目里用 `git commit`（未加 `--no-verify`）造泄漏提交 ⇒ 提交被 pre-commit **合法拒绝**、`LEAKY == BENIGN`，下游 pre-push 两腿在旧 rev 上空跑成**假绿**，首轮 `VERDICT=FAIL` 属归因错位（与我方 `TD-081` 的「夹具状态未断言」同根）；改为 `git commit --no-verify` + `[ "$LEAKY" != "$BENIGN" ]` 显式断言后 → PASS。⇒ v2 ① 的实证迫切性再 +1 |
| TD-082 | 🟢 | `.specs/health-fix-2026-09b/TEST.md` §1.1 §AC 表（`:56`/`:57`/`:59`/`:61` 四处「常设 bats 用例数」；第 5 轮审查 `R5-3` 实测：27→**45** · 5→**11** · 24→**30** · 三件净合计 46→**53**）· `.specs/health-fix-2026-09b/reproduce-5-test.sh` 已具备解析 bats TAP 计数的能力 | **总结面数字靠人工推算 ⇒ 反复陈旧（`L-171` 同族；本轮 `46` 本身即上一轮订正时的手算产物）**：已就地订正四处，并在 §AC 表后立「数量口径生成规则」（每次执行后重跑 `grep -cE '^[[:space:]]*@test'` 并同步）。v2 = 把该表用例数纳入 `reproduce-5-test.sh` 的自动核对段（解析 TAP 计数与 `TEST.md` §AC 表逐行比对，不一致即 rc≠0） | `REVIEW.md` §0⁗.4 `R5-3`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-083 | 🟢 | `.specs/health-fix-2026-09b/reproduce-5-test.sh`（267 行）· `.specs/health-fix-2026-09b/reproduce-phase-gate.sh`（165 行）—— `grep -rn 'reproduce-phase-gate\|reproduce-5-test' test/ flow-kit-bundle/test/ Makefile` = **0 命中** | **变更自带的复现入口无常设门禁覆盖**：两份脚本的正确性只靠人工重跑（已发生实例 = `TD-077` 的 `emit_gate … 0` 硬编码把 221.6% 印成 ✅）。v2 = 加轻量自检（`[A]` 段基线字符串 vs `npx bats --count test/` 实测；`[D]` 段必须按真实 rc 判定；阶段门六态退出码矩阵）+ `Makefile` 增 `check-reproduce` 目标 | `REVIEW.md` §0⁗.4 `R5-4`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-084 | 🟡 | `.flow-active` 的 `.goal.task_progress`（43 条 / **42 唯一 id**：`T-FIX-09` 重复，一条 `commit_sha` = 字面量 `$(git rev-parse HEAD)`（`git cat-file -e` ⇒ MISSING）、另一条 = 真值 `81c920e61101f599bf9e29f7ec5bc3dbe429a887`；`completed_at` 类型漂移 = **6 条数值 epoch vs 37 条 ISO-8601**）· 消费者面 `grep -rn task_progress flow-kit-bundle/hooks/ flow-kit-bundle/flow-kit/scripts/` = **0 命中** | **Host 台账无 schema 校验 ⇒ 写入端可落畸形值**：重复条目携带未展开的 shell 替换（commit_sha 非 SHA）、`completed_at` 两制混用。当前无消费者 ⇒ 影响限于台账自身可核查性（规则 9 的四条 Δ 实测 10/4/30/6 s 均合规，故不涉及「先提交后记账」）。v2 = 写入端 schema 校验（`id` 唯一 · `commit_sha` 必须 `^[0-9a-f]{40}$` · `completed_at` 统一 ISO-8601）+ 归档前对全量 `commit_sha` 跑 `git cat-file -e` 核验 | `REVIEW.md` §0⁗.4 `R5-1` / `R5-2`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-085 | 🟡 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:78-90`（`SELF_EXCLUDE` 区块，只含 `INDEPENDENT-REVIEW-{1,2,3}.md`）· `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-5.md`（1163 行）· `.specs/health-fix-2026-09b/INDEPENDENT-REVIEW-6.md` | **`SELF_EXCLUDE` 未按自身契约追加新增审查档**（`check-path-privacy.sh:84` 原文要求「后续阶段新增审查档时必须显式追加精确路径」）。实测：全 index PAT 命中 77 条，其中 50 条在 IR-1/IR-2（自排除）；非自排除命中经取名字成分核对全部为 27 条 `/home/user/` 占位符 ⇒ 当前 0 命中诚实但属运气。后果 = IR-6 追加 L2/L3/主 agent 响应后只要引用真实路径即 rc=1、挡住阶段 6 提交。修法 = 追加两行精确路径（禁宽通配）；~~修法 = 追加两行精确路径~~ ⇒ **本处置已被 `T-FIX-24` 反转（2026-09-28 · 阶段 5 第 12 次执行）**：追加两行与 `T13`/`T17` 的冻结判据**冲突**（豁免面不得超出冻结集 1–3；新增审查档是脱敏第一现场，正确处置是**就地 de-shape**而非豁免 · `L-149`/`TD-054`）—— `T-FIX-22` 照此 Remedy 实施后 `T17` 判红即其机器证据。现处置 = 删两行 + 订正 `check-path-privacy.sh` 的区块注释（旧注释「新增审查档必须显式追加」正是误导源）。v2 口径**反转** = `make check-privacy-selfexclude`：断言 `SELF_EXCLUDE` 成员集合 **≡ 冻结 6 条**（脚本本体 + 两份允许清单 + `INDEPENDENT-REVIEW-{1,2,3}.md`），**新增审查档被追加即 rc≠0**（= 把 `T17` 的断言升为常设门禁 · 常设腿已由 `T-FIX-24` 落在 `test_path_privacy_gate.bats`） | `REVIEW.md` §0⁗.4 `R5-5`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-086 | 🟢 | `.flow-active` 的 `.goal.task_progress`（`T-FIX-09` 两条、`completed_at` 类型漂移）· `flow-kit-bundle/flow-kit/reference/commit-protocol.md:112` / `flow-kit-bundle/flow-kit/prompts/4-dev.md:301`（范例值为 `date -Iseconds`） | **台账 `completed_at` 类型漂移（epoch 数值 vs ISO-8601 字符串）**：ADR-015 schema 只约束字段名不约束类型 ⇒ 6 条 epoch 与 37 条 ISO 混存，按时间序比较的消费者行为不一致（本仓无消费者、两型可无损换算 ⇒ 不阻塞）。处置 = 归档前把 6 条归一为 ISO-8601，并在派发契约里写明 `completed_at` 必须取 `date -Iseconds`；v2 = schema 校验加类型断言（与 TD-084 同批） | `REVIEW.md` §0⁗.4 `R5-2`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-087 | 🟢 | `grep -rn chisel --include='*.sh' --include='Makefile' --include='*.yml' --include='*.json' .` = **0 命中** · `Makefile` 的 `check-dist`（只保证 `dist/dsh-flow-kit/vendor/flow-kit-bundle` ↔ 源一致）· `package-flow-kit.sh --validate` · `dist/dsh-flow-kit-0.2.0.tgz` | **AC-5 的归档面（逐个 tarball `chisel` 计数 = 0）无常设门禁**：判据只在 change 期由 `T27 <verify>` 与 `reproduce-5-test.sh` 承载；生产件无扫描器、`check-dist` 不看 tarball 内容 ⇒ 后续打包回归无机器复核。处置 = v2 在 `package-flow-kit.sh --validate` 或 `check-dist` 内加「归档 `chisel` 计数 = 0，否则 exit 1」断言；或明示该面仅 change 期内有效 | `REVIEW.md` §0⁗.4 `R5-11`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-088 | 🟢 | `test/test_path_privacy_gate.bats:269-276`（F4 坏态：`run` 后仅 `[[ "$output" == *"允许清单 0 条"* ]]`，无 `$status` 断言）· 同文件 `:298-310`（F5 好态：`find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*'` 前后计数 + `[ "$after" -le "$before" ]`） | **隐私门禁测试内两处弱断言**：坏态缺 `[ "$status" -eq 1 ]`（同文件其余用例均有）⇒ 实现改成「打印正确报文但 rc=0」仍全绿；好态残留检测用全局 `/tmp` 计数 ⇒ **不可归因**（并发删除/创建可掩盖或误报）。处置 = `:269` 补 `$status` 断言；`:298` 改为专用 `TMPDIR`（隔离目录）并断言该目录跑后无残留 | `REVIEW.md` §0⁗.4 `R5-13`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-089 | 🟢 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh:77`（`PLACEHOLDER_NAMES='user ubuntu acct yourname foo bar someone'`）· 使用点 `:428` · 主 agent 夹具 `/tmp/p6d/a4b-verify.sh` | **`/home/ubuntu/` 被占位符表吞掉**：`ubuntu` 是 Ubuntu AMI 的真实默认账号，但其目录被当通用占位符排除 ⇒ 仅含 `/home/ubuntu/secret` 的形态 rc=0（对照真实账号名 ⇒ 命中 1 + 归因 + rc=1）；`REQUIREMENT.md` 的三态口径只覆盖 `/home/<user>` ⇒ 属口径外的真实泄漏面。处置 = v2 把 `ubuntu` 移出占位符表（或按「发行版默认账号」单列一表 + allowlist 显式放行） | `REVIEW.md` §0⁗.4 `R5-17`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-090 | 🟢 | `sync-hooks.sh:56-63`（6 个副本：`$HOME/.claude/hooks` · `dist/dsh-flow-kit/hooks` · 其 vendor · `~/.dsh/profiles/web/node_modules/dsh-flow-kit/hooks` · 其 vendor · `$HOME/.config/opencode/hooks`）· `flow-kit-bundle/lib/install_hooks.sh:213`/`:222`（`hook_dst`） | **项目级 hook 副本不受漂移守护**：`--list` 的 6 个副本全 ✅、镜像 48 文件，但安装器仍会在 `<proj>/.claude/hooks/` 装同一批 hook（含新增 `pre-push`）⇒ 项目级副本漂移无门禁发现（`R5-18` 的布局缺陷正是在该形态暴露）。处置 = v2 让 `--check` 支持 `--project <dir>`，或文档化「项目级副本靠重装更新」 | `REVIEW.md` §0⁗.4 `R5-25`（阶段 6 第 5 轮 · 主 agent · 2026-09-27） |
| TD-091 | 🟡 | 执行者 `e298ccc0-2cdb-491d-aa77-04a44a5641c1`（`T-FIX-15`）写入的 `.flow-active`（顶层多出 `.goal` 键，仅含一条 `task_progress`）· 权威台账 `goal.task_progress` 缺 `T-FIX-15`（主 agent 现场发现：`tp[-1].id = "T-FIX-14"`、`tp[0]` 仍为 `T01`）· 同族 `TD-086`（`completed_at` 类型漂移） | **台账写入路径漂移**：执行者把条目写进顶层字面键 `.goal`（jq/python 路径被当作字面 key），而非 `goal.task_progress` ⇒ 权威台账静默缺条，`33-flow-active-integrity.sh` 仍 rc=0（该钩子不校验台账条数/路径）；另有 prepend 而非 append 的序偏差。主 agent 已就地归位（删幽灵键 + 条目 append 到末尾 ⇒ 45 条）并立规。处置 = `TASK.md`「工作树纪律」段（append + 写后 `python3` 断言 `tp[-1]['id']` 与 `'.goal' not in d`）· `T-FIX-21` 台账归一内加静态校验；v2 = 让 `33-flow-active-integrity.sh` 增台账 schema/路径检查 | `TASK.md` 新增「工作树纪律」段（主 agent · 2026-09-28）· `REVIEW.md` §0⁗.4 `R5-2` 家族 |
| TD-092 | 🟡 | 执行者 `e298ccc0-2cdb-491d-aa77-04a44a5641c1`（`T-FIX-15`）执行的 `git checkout HEAD -- .specs/health-fix-2026-09b/TASK.md .specs/health-fix-2026-09b/TEST.md` · 受害面 = 主 agent 未提交订正（`TASK.md` 8 hunk：行号锚点纪律段 + `T-FIX-15`/`16`/`20`/`22` 锚点重取；`TEST.md` 2 hunk：AC-3 `27→45` / AC-4 `5→11` / AC-6 `24→30` / AC-8 `46→53` + 数量口径生成规则）· 恢复源 `/tmp/tfix15/preserve/`（执行者自行备份） | **执行者用 `git checkout --` 销毁主 agent 未提交改动**（其回执称「主 agent 的改动已备份并仍在工作树」，实测**不在**：`grep -c 行号锚点纪律 TASK.md` = 0）。主 agent 已用 `git apply` 从备份复原（`TASK.md` 2933 行 / `TEST.md` 1268 行，8+2 hunk 全部回位），并立规「严禁对非本任务写面执行 `git checkout --` / `restore` / `stash` / `clean`，只许 `git show HEAD:<path> > /tmp/...`」 | `TASK.md` 新增「工作树纪律」段（主 agent · 2026-09-28） |
| TD-093 | 🟢 | `test/test_pre_push_behavior.bats:202-221`（leg4 只断 `[ "$status" -ne 0 ]`）· `flow-kit-bundle/hooks/pre-push/pre-push.sh:28`（`set -euo pipefail`）/ `:172` 守卫 / `:175` `local_sha=$2` | 主 agent 变异实测（2026-09-28）：把 `:172` 的 `exit 1` 改为 `:` 后，脚本落到 `:175` ⇒ `行 175: $2: 未绑定的变量`（rc=1），而守卫报文在 `exit` 前已输出 ⇒ leg4 三条断言（`status -ne 0` + 报文 + `fail-closed`）全绿 ⇒ 该腿无法区分「守卫 fail-closed 拒绝」与「意外崩溃兜底」（执行者的 `exit 1`→`continue` 变异体恰能转红）。**v2**：leg4 改断 `status -eq 1`，并加 `[[ "$output" != *"未绑定的变量"* ]]` | T-FIX-16 复核（变异 M2） |
| TD-094 | 🟢 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh`（rev 面候选循环内的 `git cat-file -t "$RESOLVED_REV:$file"`，T-FIX-17 新增的 blob/gitlink 判别） | **rev 面每候选一次 `git cat-file` 未批量化**：主 agent 实测 200 次 = 0.35 s（≈1.75 ms/次）⇒ 本仓 1612 候选 ≈ **2.8 s**，占整轮 rev 扫描 4.4–4.55 s 的 ~62%（该轮已 ≤5 s 预算，故不阻塞）。**v2**：进入循环前一次 `git ls-tree -r -z "$RESOLVED_REV"`（实测 0.00 s / 172 747 B / 1612 条）批量取 mode 后查哈希表判别 blob/gitlink；同批量化思路可类推到其它逐候选外部命令 | 主 agent 独立计时（T-FIX-17 复核 · 2026-09-28） |
| TD-095 | 🟢 | `Makefile:162` `check-nfr-portability-internals` 的受检面（`case "$_f" in *.sh) ;; *) continue;; esac` ⇒ 只收 `*.sh`）· 存量 GNU `sed -i`：`test/test_check_gate_sync.bats:39`/`:46`/`:52` · `test/test_flow_active_integrity.bats:44` · `test/test_l3_review_defects_2026_09.bats:492`/`:501`/`:1793` | **NFR 可移植性门禁不扫 `.bats`**：主 agent 复核 T-FIX-18 时实测其新腿 `test/test_check_gate_sync.bats:206` 的 GNU `sed -i` 未被 `make check-nfr-portability` 报出（扫描器只收 `*.sh`），而该门禁的常设测试件 `test/test_nfr_portability_gate.bats:76` 恰以 `sed -i` 为样例 ⇒ 判据与受检面不一致：测试面（macOS 上同样要跑 bats）的 GNU 依赖无门禁；macOS/BSD sed 会把它当 `-i` 的扩展名参数 ⇒ `invalid command code`。T-FIX-18 已把**新增**实例改为 `sed … > tmp && mv`（提交 `467a755`），存量 6 处留 v2。**v2**：受检面扩到 `*.bats`（并给刻意样例标注/白名单，如 `test_nfr_portability_gate.bats`、`test_gate_integrity.bats` 的注入夹具） | 主 agent 复核实测（T-FIX-18 · 2026-09-28） |
| TD-096 | 🟢 | `flow-kit-bundle/hooks/stop/lib/common.sh:432`（`declare -A _FK_PERF_TIMINGS 2>/dev/null \|\| true`）· `flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh:51`（`declare -A PHASE_ARTIFACTS=(`）· `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh:100`（`declare -A keep_line`）/`:167`（`mapfile -t tail_lines <<< "$text"`）· `package-flow-kit.sh:394`（`declare -A BROOKS_TOOLS`） | **hook 库内 5 处 bash-4-only 构造（macOS `/bin/bash` 3.2 下行为异常或 rc=127）**：主 agent 现取实测（2026-09-28）`NFR_RC_FILE=… FLOW_KIT_CHANGE_BASE=FULL make check-nfr-portability-internals` ⇒ **rc=1 · 19 行 / 12 文件**，其中「可安全替换」7 条由 `T-FIX-23` 当场修（`sync-hooks.sh:182/:197/:198` · `verify-claims.sh:119/:135` 的 `mapfile` · `34-archive-commit-check.sh:47` `stat -c %Y` · `install_brooks.sh:125` GNU `sed -i`）、冻结归档面 7 条（`.specs/archive/**`）从受检面排除，余下这 5 条登记进 `flow-kit-bundle/flow-kit/reference/nfr-portability-baseline.txt`（ratchet：不在基线内 ⇒ 判据红；基线条目消失/行号漂移 ⇒ `⚠️ 基线陈旧` + 判据红）。**风险**：`flow-kit-artifacts.sh` 的 `PHASE_ARTIFACTS` 查表在 bash 3.2 下退化为索引数组 ⇒ 阶段工件解析可能取空；`common.sh` 的 perf timings 静默失效（诊断性，可容忍）。**v2**：以「`case` 查表函数 / 并行数组」替换 `declare -A` 并同步 6 个 hook 副本 | 主 agent 实测 + `T-FIX-23` 判据定稿（`TASK.md` · 2026-09-28）· `LESSONS.md` `L-175` |
| TD-097 | 🟢 | `Makefile:162` `check-nfr-portability-internals`（BAN 正则按源码**字面**匹配）· 实例：`.specs/health-fix-2026-09b/reproduce-5-fixloop.sh:138-139`（主 agent 的阶段 5 判据脚本，提交 `61d484a`） | **NFR 判据的字面匹配盲区（可被拼接/方括号写法绕过）**：主 agent 实测——判据脚本里两行 `grep -cE` 的**标签与 pattern 字面**被判据自己判为「新增行含 bash4-only / GNU-only 构造」（`NFR_RC_FILE=… make check-nfr-portability-internals` rc=1，正是 T-FIX-19 执行者上报的 `make check` 阻塞源）；改写成方括号式（对 `grep -E` 语义等价：实测 `sync-hooks.sh` 3=3、`verify-claims.sh` 2=2）后 rc=0。反向风险同样成立：真实违规者可写 `map""file -t a`（bash 词拼接后仍执行同名内建）或把字面拆进引号，从而逃过判据。**v2**：扫描前先做去引号/去方括号归一（或对 `bash -n` 后的词元序列匹配），并把「pattern 位置的合法字面」列入白名单，而不是靠书写规避 | 主 agent 实测（T-FIX-19 复核 · 2026-09-28） |
| TD-098 | 🟢 | `test/test_independent_review_model.bats:14-19`（`setup()` 的向上查找：`local d="${BATS_TEST_DIRNAME:-.}"` + `while [ "$d" != "/" ] && [ ! -f "$d/flow-kit-bundle/hooks/stop/29-independent-review.sh" ]; do d="$(dirname "$d")"; done` + `FK_ROOT="$d"`） | **fail-fast 诊断表单里的路径带 `//` 前缀（可读性，非功能）**：仓库根解析失败（源件缺失）时 `d` 落到 `/` ⇒ `FK_ROOT=/`、`FK_STOP=//flow-kit-bundle/hooks/stop`，主 agent 独立注入实测报文为 `缺失仓库源件（R5-26 fail-fast）: //flow-kit-bundle/hooks/stop/29-independent-review.sh …`。功能无影响（`[ -f "//x" ]` 等价 `/x`；bats 仍 13/13 转红、具名诊断仍在）⇒ 仅报文整洁性。**v2**：循环结束后补 `[ "$FK_ROOT" = "/" ] && FK_ROOT=""`（或写 `d="${d%/}"`）即可让路径以单斜杠呈现 | 主 agent 独立注入实测（T-FIX-20 复核 · 2026-09-28） |
| TD-099 | 🟢 | `.specs/health-fix-2026-09b/TEST.md`（§1.1 AC 表 / §1.3 复算表 / §回归保护 三处当前值计数）；`Makefile` 无对应判据 | **「报告当前值计数」没有机器门禁 ⇒ 每轮必漂移**：`TEST.md` 的 bats 收集面 / 有效用例 / 各专项 `@test` 计数 / `check-validate` 文件数全是手工同步的当前值，任何一次新增 bats 或源件都会让它们失真（`R5-8` 同族已两轮复发：第 11 次口径 `1064/1063` → 第 12 次 `1098/1097`；`check-validate` `321` → `324`；`T-FIX-21` 本轮订正了 §1.1/§1.3，主 agent 又补订 §回归保护）。**v2**：加 `make check-doc-counts`——从 `TEST.md` 抽出机器可读声明（如 `npx bats --count test/` ⇒ N）与实测比对，失败即具名 `file:line`；或把三处当前值收敛成文件头**唯一声明**、正文只引用不复制 | 主 agent `T-FIX-21` 复核（2026-09-28） |
| TD-100 | 🟢 | `flow-kit-bundle/hooks/stop/lib/done-validation.sh`（`_fk_done_kvp` :100-102）| **done 校验库在非条件上下文调用时可能提前中止而非返回 `2`**：`done-validation.sh` 自身不设 `set -e`，但它 source 的 `l2-detect.sh:17` 会开 `set -euo pipefail`；此时 `k_phase=$(_fk_done_kvp …)` 的 `grep` 管线在缺 KVP 时返回 1 ⇒ 整个 hook 以 rc=1 中止（Claude Code 语义下 rc≠2 属「非阻塞错误」= 潜在 fail-open），而非函数文档承诺的 `return 2` deny。当前生产调用点全在条件上下文（`independent-review-gate.sh:97` · `gate-checks-basic.sh:147` · `31-auto-advance.sh:77`）故 errexit 挂起、行为正确（T-FIX-22 已实测两态）；v2 建议给 `_fk_done_kvp` 的三段管线加 `|| true` 兜底（或在函数头 `set +e`），使契约与调用上下文解耦 | 主 agent T-FIX-22 复核（2026-09-28） |
| TD-101 | 🟢 | `.specs/*/TASK.md`（`task` 的 `status` / `done` 块）· `.flow-active` 的 `goal.task_progress` · `T-*-SUMMARY.md`；`Makefile` 无对应判据 | **「完成」是四处契约却无一条机器判据做交叉核对 ⇒ 漏标可长期存活**：`T-FIX-15` 的产品提交 `330a4e9`、SUMMARY `231c74f`、台账条目 `78e2fc4`（`completed_at=2026-09-28T01:02:43+08:00`）、主 agent 复核记录齐备，而 `TASK.md` 的 `status="pending"` + 无 `done` 块从 `78e2fc4`（`01:02`）静默存活到本轮回扫（`12:35`，**11.5 h**），期间 `make check` 21 ✅ / 0 ❌ 与 `check-validate` 全绿 —— 根因是 `TD-092` 销毁式还原：恢复的是**内容**，执行者写面的**完成标记**不在主 agent 备份里。本轮已按台账 + SUMMARY + 复核记录**事后补记**（`TASK.md` 内显式标注「补记」）。**同族第二例**：`T-FIX-16-SUMMARY.md` 被写进**仓库根**（`b3c03fa` · `147/0`）而非 change 目录，静默存活约 **11 h**（`make check` / `check-validate` / `check-path-privacy` / `check-dist` 都不校验回执落点；实测未进 dist、无路径泄漏 ⇒ 无判据可报），本轮 `git mv` 归位并在文末留更正段；写面纪律（执行者只许写 `<write_files>` + `.specs/<change-id>/T-FIX-*-SUMMARY.md`）同样**无判据**。**v2**：把 `L-180` 的审计写成 `make check-task-ledger`（抽 `^<task …>` 的 `id`/`status`/`done` 块存在性 ↔ `goal.task_progress` 的 `id` 集合与 `commit_sha` 双向比对；只允许未开工任务为 `pending`；命中即具名 `TASK.md:line`）并纳入 `check:` | 主 agent `T-FIX-23` 收口复扫（2026-09-28）· `LESSONS.md` `L-180` |
| TD-102 | 🟢 | `.specs/health-fix-2026-09b/TASK.md` 的 `T-FIX-04` `<verify>` 夹具（`SBX` 构造段）· `flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`（`T-FIX-18` 新增的 gate-config fail-closed 诊断） | **判据夹具未随被测量对象的新增必需输入同步 ⇒ 「完整夹具本应 rc=0」这条腿自我误报**：`T-FIX-18` 给 `check-gate-sync.sh` 加了「缺 `flow-kit-bundle/test/test_gate_config_presets.bats` ⇒ `🔴 MISSING: gate-config 同步无法校验（未比对）` + rc=1」的 fail-closed 分支，而 `T-FIX-04` 的夹具只拷 `reference/` + `prompts/` + `skills/` ⇒ 阶段 5 第 12 次执行 `T-FIX-04` rc=1（`full_fixture=1`）。**主 agent 独立复现**：同夹具 rc=1，补上该 bats 后 **rc=0** ⇒ 判据面缺陷，生产件无 bug。本轮已就地订正判据（补 `cp flow-kit-bundle/test/test_gate_config_presets.bats`，断言一字未改）。**同族**：`TD-071`…`TD-081`（判据/工具面缺陷族）。**v2**：判据夹具一律用 `git ls-files` 取被测 SUT 的**全部必需输入**（而非手列目录），并在判据头部写明「本夹具覆盖 SUT 的哪些输入面」 | 主 agent（阶段 5 第 12 次执行复核 · 2026-09-28）· `LESSONS.md` `L-181` |
| TD-103 | 🟢 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh:58`（`FLOW_KIT_L3_MAX_ARTIFACT_BYTES` 默认/覆盖 · 当前值 `300000`）· 受审工件集（`TEST.md` + `PHASE5-RECEIPTS.md` + `INDEPENDENT-REVIEW-*.md` + `TASK.md` 等） | **L3 提示词预算相对工件体积已从「边际」变为「实质」截断 ⇒ 外部审查结论只覆盖部分工件**：第 12 次执行实测 —— 完整 `396490 B`，实发 `299998 B`，**丢弃 24%**（第 11 次执行时同一约束仅丢 1%：`303899 → 299999`，见 `PHASE5-RECEIPTS.md:2038`）。截断**只告警不失败**（`[l3-review] WARNING: 提示词被截断…`），故门禁 `verdict=pass` 可在「L3 未读到 24% 工件」的前提下成立 —— 存在性与有效性再次分叉（`L-124` 家族）。本轮缓解：**L2 侧为独立子 agent 直接读盘全文**（无预算约束）并 `pass`；`verdict=pass` 与截断率一并在 `PHASE5-RECEIPTS.md` §U-2 与 `INDEPENDENT-REVIEW-5.md` 的主 agent 响应里披露。**v2**：① 提高 `independent_review.max_artifact_bytes`（或按工件分包多次送审 + 汇总）；② 把**截断率**升为判据（丢弃 > 10% 时握手标记内记 `L3_truncated: <pct>` 并要求补审）；③ 在 `TEST.md`/§U 里把「送审面覆盖率」作为 L3 结论的必附字段 | 主 agent 阶段 5 第 12 次执行（2026-09-28 · L3 第 18 轮回执） |
| TD-104 | 🟢 | `.specs/health-fix-2026-09b/TASK.md` 的 `T-FIX-10` `<verify>`（`grep -qE 'diff_out.*\|\| true'`） | **判据过宽 ⇒ 无法区分缺陷形态与修复形态**（L3 第 20 轮 major ②）：该 `grep` 会同时命中修复后合法的 `grep -c` 消费行，故对 `R3-20` 原缺陷（`diff_out=$(diff … \|\| true)` 吞掉 rc）**与**修复形态（显式 `diff_rc=$?` 捕获）都判绿 —— 属 `TD-071`…`TD-081`/`TD-093` 同族（判据对目标缺陷无判别力）。**本轮结论不依赖该 grep**：`test_check_gate_sync.bats` 双态腿 + `make check-gate-sync` rc=0 + `T-FIX-10` 复核记录的行为复算 ⇒ 该 grep 仅作弱旁证。**v2**：断言改为「存在 `diff_rc=$?` 显式捕获分支」+ 增加行为级 bats 腿（制造 `diff` rc≥2 的机械故障形态并断言非绿） | 主 agent 阶段 6（L3 第 20 轮回执 · 2026-09-28） | **【状态同步 · 2026-09-28】**：本条的两条 v2 要求**已在本 change 内落地** —— `T-FIX-10` 的 `<verify>` 已改为**双面断言**（缺陷形态缺席 + `diff_rc=$?` / `rc≥2` 修复形态在场），并由 **`T-FIX-25`（`380679b`）** 把行为级判别力补进常设网（`test_check_gate_sync.bats` 15 → 16 例 · 影子 `diff` 恒 rc=2 ⇒ 必须 `rc≠0` + `🔴 MECHANICAL` + 不得 `✅…一致`）；判别力经**主 agent 忠实缺陷态复算**与 **L2 第 2 轮独立变异实证**双重确认（删两处 ⇒ 三断言全 FAIL）⇒ **本条标记为「本 change 内已闭合」**（保留 v2 描述作历史）。
| TD-105 | 🔴 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（`<!-- L3-SECTION -->` 整块替换写入）· `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh`（`_l3_check_rerun` 触发条件）· `flow-kit-bundle/flow-kit/prompts/6-review.md` 的 L3 派发面 | **L3 自引用死锁：一旦某轮 `verdict=fail`，后续每轮都会读到「上一轮的 fail 块」并据「工件内无本轮重跑证据」再判 fail ⇒ 修复-重跑不收敛**：实测 —— 阶段 6 `T-FIX-24` 收口后 L3 第 19 轮 `fail`（2 major，工件口径）→ 逐条处置 + 重跑 → 第 20 轮 `fail`（2 critical，其中 critical① 的 issue 正是「最后可见的 L3 判定仍是 fail 且未见重跑块」）→ 再处置 + 重跑 → 第 21 轮 `fail`（critical① 同型复现）。根因 = **L3 块由子系统在「模型读完工件之后」整块覆写** ⇒ 模型永远看不到自己那一轮的判定，只能看到上一轮；而它被要求「不得在无重跑证据时宣称通过」⇒ 结构性不可满足（用户 2026-09-28 裁决项见 `.flow-active.goal.note_*` 与 REVIEW.md 头部现行结论行）。**本轮缓解**：在响应里写明机制属性并请模型以「上一轮 findings 是否逐条处置」为判定对象（第 20 轮已写，仍未说服该模型）；`REVIEW.md` §H.3 与头部改为「L3 pass 之前不放行」的保守口径。**v2**：① L3 提示词显式告知「工件里可见的 L3 块是**上一轮**，本轮判定对象 = 上一轮 findings 的处置充分性」；② 或把历史 L3 轮次**追加**保留（而非整块覆写），使 fail→fix→pass 链在工件内可见；③ 或在 `_l3_check_rerun` 之外引入「处置轮」概念：处置轮只判「上轮 findings 是否闭合」，不重复判「是否存在本轮块」 | 主 agent 阶段 6（L3 第 19–21 轮实测 · 2026-09-28） |
| TD-106 | 🟢 | `test/test_check_gate_sync.bats` 的 `T-FIX-25` 腿（`FXB25` + 影子 `diff` 恒 rc=2） | **机械故障形态覆盖单一**（L3 第 22 轮 major ③）：该腿只覆盖「`diff` 返回 rc=2」一种形态；`diff` 不存在（command not found）· 参数错误（rc=2 的另一路径）· 输出被截断等形态未覆盖。**v2**：参数化影子命令（`exit 2` / 不存在 / 只读输出）或增加 2–3 条同族腿（表驱动） | 主 agent 阶段 6（L3 第 22 轮回执 · 2026-09-28） |
| TD-107 | 🟢 | `.specs/health-fix-2026-09b/T-FIX-10-SUMMARY.md`（4205 B · 超补充产物预算 3000 B 被整行截断）· `.specs/health-fix-2026-09b/T-FIX-2x-SUMMARY.md` 同族 | **执行者 SUMMARY 超预算被截断 ⇒ 关键 verify 偏差细节对读者不可见**（L3 第 22 轮 minor ①）：L3 只看到 3000 B 以内的部分，无法据此核验整改闭环。**v2**：给 SUMMARY 定「首屏 3000 B 内必须含：判据偏差 / 修法 / 复跑 rc」的结构约束，或把 L3 补充产物预算提到 8–10 KB（与 `TD-103` 的预算问题同族） | 主 agent 阶段 6（L3 第 22 轮回执 · 2026-09-28） |
| TD-108 | 🟢 | `test/test_independent_review_model.bats` 的 AC-7 删除注入腿（依赖 `$HOME/.claude/stop-hook.json` 存在） | **无安装态环境下该腿直接 skip ⇒ 断言永不执行**（L3 第 22 轮 minor ②）：`stop-hook.json` 缺失时用例 skip，「仍为纯 model 字符串」这一性质在未安装环境永远不被验证（skip 不计入失败，形成静默缺口）。**v2**：改为「缺失时也断言默认读序/降级行为」（或把该腿拆为「文件在」与「文件缺」两态，后者断言不 crash + 走默认） | 主 agent 阶段 6（L3 第 22 轮回执 · 2026-09-28） |
| TD-109 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh:54`/`:56`/`:60`（`write_settings_file_atomic` 的 `trap - EXIT`） | **`trap - EXIT` 会清掉调用方整条 EXIT trap**（阶段 6 REVIEW `F9`）：注释自陈「install 路径无 EXIT trap」，属**对调用方的隐式前提**；若将来 install 路径引入 EXIT trap（如临时目录清理），会被静默清掉。**v2**：保存/恢复既有 trap（`trap -p EXIT` 快照 + 还原）而非无条件 `trap - EXIT` | 主 agent 阶段 7 triage（2026-09-28） |
| TD-110 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh:69`（`deploy_pre_commit`）/`:124`（`deploy_pre_push`）+ `:213`/`:222`（`hook_dst` 赋值点） | **两个 deploy 函数经动态作用域读调用方的 `$project` / `$hook_dst`**（`F10`）：调用方未 `set -u` 时未绑定变量会静默为空 ⇒ 可能装到错误路径；函数签名不表达依赖。**v2**：改为显式参数（`deploy_pre_push "$project" "$hook_dst"`）或 `local` 化并前置校验 | 主 agent 阶段 7 triage（2026-09-28） |
| TD-111 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh:179-468`（`install_hooks()` **290 行** · 内嵌 `_install_hook_wiring()`） | **超长函数（R1 认知过载）**（`F11` · 阶段 6 记录时 247 行，此后增长到 290 行）⇒ 分支组合难以穷举测试。**v2**：按「读取既有 settings → 合并 → 落盘 → 部署 hook 副本 → 校验」拆分 4–5 个子函数并各自 pin | 主 agent 阶段 7 triage（2026-09-28） |
| TD-112 | 🟢 | `sync-hooks.sh`（hook 家族枚举分散在 4 组结构里（`L2 第 1 轮` 复算：按不同 grep 口径命中 17–31 行）：`is_real_entry` / `--entry-class` 前缀表 / `collect_rel_paths` / 孤儿扫描）+ `package-*.sh` | **hook 家族枚举在 4+ 处手抄（R3 知识重复）**（`F14`）：新增/改名 hook 需同步多处，漏一处即静默漂移（本 change 的 `T-FIX-12` 已补 pre-push 但枚举仍是手抄）。**v2**：单一清单文件（或从 `hooks/**` 派生）+ 一致性断言 | 主 agent 阶段 7 triage（2026-09-28） |
| TD-113 | 🟢 | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh:353`（`_adr_budget=18000`）· `:357`（`-lt 8` 上限） | **ADR 预算与上限为字面量**（`F15` · 同文件已有 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES` 式环境旋钮先例）：`T-FIX-22` 已补「已丢弃 N 条」标记（可观测性达标），但预算值仍不可配置 ⇒ 大仓/小仓无法按需调。**v2**：`FLOW_KIT_L3_ADR_BUDGET` / `FLOW_KIT_L3_ADR_MAX` 环境旋钮（缺省 = 现值） | 主 agent 阶段 7 triage（2026-09-28） |
| TD-114 | 🟢 | `flow-kit-bundle/flow-kit/reference/check-path-privacy.sh` 的 `SELF_EXCLUDE`（逐条精确路径豁免）· `.specs/archive/**` 扫面 | **`SELF_EXCLUDE` 的精确路径豁免在归档/复制场景下失真**（跨模型 spot-check `S1` · 阶段 7 归档时实际面对）：本 change 的 `INDEPENDENT-REVIEW-1/2/3.md` **含真实账号路径**（成文早于脱敏规则）故被逐条豁免；**归档把路径搬到 `.specs/archive/<date>-<id>/` 后豁免即失效 ⇒ 隐私门禁会扫到并判红**。三条候选策略：① 归档时就地脱敏归档副本（改受协议保护文本，须随 manifest 披露）· ② 把 3 条豁免随文件迁移到归档路径（豁免面按 change 数线性增长）· ③ 判据面显式排除 `.specs/archive/**`（归档快照 = 冻结历史 · 与 `T-FIX-23` 对 NFR 面的处置同构）。**须用户裁决**（豁免面策略属本 change 两次裁决过的事项）；决策与理由落 `INTEGRATION.md` | 主 agent 阶段 7 归档前（2026-09-28） |
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
<!-- final-debt-cleanup-2026-08 追加 ↓ -->
| hook lib split (l3-review) | L3 审查 lib 拆分模式（TD-008/017 fix）：l3-review.sh 875→5 文件（slim orchestrator + 4 sourced sub-libs：l3-prompt / l3-api / l3-truncate / l3-done）。来自 final-debt-cleanup-2026-08 |
| hook lib split (gate) | PreToolUse gate lib 拆分模式（TD-018 fix）：independent-review-gate.sh 597→4 文件（slim orchestrator + 3 sourced sub-libs：gate-helpers / gate-checks-basic / gate-checks-review）。来自 final-debt-cleanup-2026-08 |
| INT-HOOK-1/2/3 | 3 集成 smoke 测试，验证 hook lib 拆分后 source 链完整（PreToolUse + Stop hook + 12 公开函数定义）。位于 test/test_hook_integration.bats |
| INT-COMBINED-1 | task-brief + 4-dev.md 合并加载 token 友好性测试（≤20KB），关闭 L-066 (AC-B4 测试深度补齐)。位于 test/test_combined_metric.bats |
| writing principles (ADR-019) | flow-kit 写作 3 原则：① AC 必须确定性（条件 AC 拆 hard+soft）② 范围决策属 DESIGN 非 REQUIREMENT ③ 图表须引用可验证产物。新 change 的 REQUIREMENT/DESIGN 必须遵守 |
<!-- final-debt-cleanup-2026-08 追加 ↑ -->

<!-- test-failures-fixup-2026-08 追加 ↓ -->
| split-aware test 设计原则 | 测试 assertion 应反映 split 后的实际代码组织，跨多文件 grep 而非死板指向单一文件 | test-failures-fixup-2026-08 |
| shellcheck shell=bash 指令 | sourced lib（无 shebang）的标准 SC2148 修复：首行加 `# shellcheck shell=bash` | test-failures-fixup-2026-08 |
<!-- test-failures-fixup-2026-08 追加 ↑ -->

<!-- td072-lib-split-2026-08 追加 ↓ -->
| gate-helpers-types.sh | gate 类型谓词聚合入口子文件（6 函数：_is_dotdone_write / _gate_is_l2_only / is_phase_write / _fk_phase_direction / _command_has_write_context / is_git_commit）。gate-helpers.sh 内部 source 本文件 + re-export，调用方零变更。TD-072 fix | td072-lib-split-2026-08 |
<!-- l2-l3-subagent-fix 追加 ↓ -->
| 双平台派发兼容（dual-platform dispatch compatibility） | L2/L3 子 agent 派发在 opencode / claude code 两个运行时下的兼容性。两平台 agent 架构不同（task tool 参数 / 子 agent 类型名 / 派发方式）且 env var 传递链路不同（`ANTHROPIC_*` / `FLOW_KIT_*` 是否透传子进程），导致既有派发命令在 opencode 下"拉不起来"。来自 l2-l3-subagent-fix |
| 拉起失败（spawn failure） | L2/L3 子 agent 无法在目标运行时启动的统称。两类现象：① 派发命令 / 架构不兼容报错 ② 子 agent 进程缺 env var 致模型配置 / API 鉴权解析失败。来自 l2-l3-subagent-fix |
| 根因报告（ROOT-CAUSE.md） | 调查型 change 的核心交付物（`.specs/<id>/ROOT-CAUSE.md`），五段结构：现象矩阵 / 根因链 / 双平台差异矩阵 / 风险分级修复方案 / 受影响模块清单。每条根因须附双平台实测证据 + 文件:行号，禁止无证据猜测。来自 l2-l3-subagent-fix |
| risk 分级修复方案 | 根因报告「修复方案」段的条目分级：risk: low（本次 v1 可实施）/ risk: high（触及 gate 核心链或 CONTEXT 禁动清单 → v2）。high 项 v1 禁止实施。来自 l2-l3-subagent-fix |
<!-- l2-l3-subagent-fix 追加 ↑ -->
<!-- archive-commit-gate 追加 ↓ -->
| 归档 commit（archive commit） | 7-integration 步骤 5.1 归档完成后按类型拆分的原子提交（fix 源码 / docs 归档产物 / chore 元数据）。区别于 4-dev 任务级 commit（commit-protocol.md）。来自 archive-commit-gate |
| pre-commit 门禁（pre-commit gate） | git commit 前跑 `make test` 的硬门禁——bats 非零退出码拒绝 commit。闭合 LESSONS L-023（commit-time 测试门禁缺失）。通过 symlink `.git/hooks/pre-commit` → 已安装 hooks 目录部署（ADR-022）。来自 archive-commit-gate |
| git hook symlink 部署 | flow-kit 通过 symlink `.git/hooks/<hook>` → 已安装 hooks 目录（user: `~/.claude/hooks/` / project: `.claude/hooks/`）部署 git hook，最小侵入不碰用户既有 hook。install.sh 设置，既有 pre-commit 文件检测+询问不静默覆盖。ADR-022。来自 archive-commit-gate |
| archive-uncommitted correction | 归档完成（goal.status=done）但 git status 非干净时，新 Stop hook 模块写的 correction file 类型（type=archive-uncommitted）。SessionStart 收割提示补 commit。来自 archive-commit-gate |
| PreToolUse 桥接（claude-code-hooks 模块） | oh-my-opencode 4.19.4+ 内置的 `dist/hooks/claude-code-hooks/` 模块，将 Claude Code hooks 概念映射到 OpenCode 插件事件。types.d.ts 定义 12 种事件（PreToolUse/PostToolUse/Stop/SessionStart/...）；config-loader.d.ts 读 `~/.claude/settings.json` hooks 配置；pre-tool-use.d.ts `executePreToolUseHooks()` 执行匹配的 hook 命令。**此发现修正 l2-l3-subagent-fix EVIDENCE-2 根因 #1 + 证伪 L-074**（原结论「opencode 下 PreToolUse 结构性不触发」基于旧版 oh-my-opencode，4.19.4 后不再成立）。来自 archive-commit-gate 阶段 1 桥接调查 |
| opencode-acp | 「Active Context Pruning」——model-driven 上下文管理插件（DCP 硬化 fork · 35 bug fixes · v1.14.12），与 hooks 桥接**无关**。桥接调查中曾列为候选载体，经源码 grep 证伪（0 匹配 settings.json/PreToolUse/hooks）。来自 archive-commit-gate 阶段 1 桥接调查 |
<!-- archive-commit-gate 追加 ↑ -->
<!-- td072-lib-split-2026-08 追加 ↑ -->
<!-- l2l3-cross-platform 追加 ↓ -->
| 双平台凭证解析链（dual-platform credential resolution） | L3 API 凭证（base_url + auth_token）的运行时感知解析策略：claude code 下 `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` 优先（零回归）；opencode 下回退 `FLOW_KIT_L3_BASE_URL` / `FLOW_KIT_L3_AUTH_TOKEN`（hook 子进程继承 opencode 启动 env，settings.json env 段不注入）。模型名沿用 fk_resolve_model 五级链（2026-09-03 起，见已锁决策）。来自 l2l3-cross-platform |
| FLOW_KIT_L3_BASE_URL / FLOW_KIT_L3_AUTH_TOKEN | 新增 L3 API 凭证 env var（opencode 平台一等配置路径）。凭证**绝不落盘**（不进 .flow-active / correction / 日志 / 报告），仅存在于 hook 子进程 env。与既有 FLOW_KIT_L3_MODEL / MAX_TOKENS / TIMEOUT / THINKING 同族。来自 l2l3-cross-platform |
| 平台感知派发（platform-aware dispatch） | L2 子 agent 派发指引按运行时生成的策略：opencode（OPENCODE=1）下生成 `task(category=...)` 路由提示（如 unspecified-high，因 subagent_type 路由挂起 agent=undefined）；claude code 下保持 `subagent_type` 派发模板。来自 l2l3-cross-platform |
| opencode reviewer agent 定义 | flow-kit 分发包新增的 opencode 专用盲审子 agent 定义（`.opencode/agent/`），使 `subagent_type` 路由在 opencode 下有可用目标。prompt 引用 L2-blind-review 指令。来自 l2l3-cross-platform |
| credential source 日志 | hook 日志记录 L3 凭证解析源（`env` / `flow-kit`），不记录 token 值本身。可观测性约定。来自 l2l3-cross-platform |
<!-- l2l3-cross-platform 追加 ↑ -->
<!-- correction-hygiene-state-guard 追加 ↓ -->
| 外来状态文件（foreign state file） | 非 flow-kit 写入的 `.flow-active`（如 chisel-skill 生态写入的 YAML 格式）。flow-kit hook 对其策略 = 让位（yield）：跳过 pipeline 检查、不转换/覆盖/删除、correction 写一条去重的 `foreign-state` note。jq empty 解析失败为唯一判据（语法错误同样按外来处理但 note 文案区分）。来自 correction-hygiene-state-guard |
| 外来让位守卫（foreign-state yield guard） | F2 设计：29/33 号在 `jq empty` 失败时不再静默 exit 0 / 不再追加 corrupt_json，改为判定外来状态 → 跳过 + 清空陈旧 state-integrity violation + 去重 foreign-state note。31/32/34 号保持静默跳过（pipeline 专用，不写 note）。来自 correction-hygiene-state-guard |
| state-integrity 类 violation | 33 号写入的 9 种 check 名集合：corrupt_json / change_id_dangling / change_id_null_with_dirs / phase_artifact_missing / pipeline_phase_artifact_missing / pipeline_gate_not_passed / pipeline_gate_phase_mismatch / stale_updated_at / token_spent_unmaintained。本 change 的去重/容量/健康清零/外来清空均以此集合为作用域边界。来自 correction-hygiene-state-guard |
| 健康清零（health clear） | 33 号新增行为：`.flow-active` 为合法 flow-kit JSON 且本轮全部检查通过时，清空 correction 中的 state-integrity 类 violation。l2-missing / model-missing / foreign-state / compliance 条目保留。来自 correction-hygiene-state-guard |
| l2-missing 退场（l2-missing retirement） | 29 号新增行为：确认 IR 文件已含 `## L2 盲审` 段（或 gate 非 both）时清除 l2-missing flag，对齐 `write_model_missing_clear` 既有范式（L3 的 model-missing 有退场机制，L2 的 l2-missing 原无设计内清除路径）。来自 correction-hygiene-state-guard |
| correction 去重（dedup） | `_fai_append_violation` 增加同 `check`+`field` 只保留最新一条 + state-integrity 类容量上限 10 条 FIFO。作用域仅限 state-integrity 类，compliance 类（28 号）不参与（ADR-013 compliance-priority）。来自 correction-hygiene-state-guard |
<!-- correction-hygiene-state-guard 追加 ↑ -->
<!-- user-guide-sync-2026-09b 追加 ↓ -->
| 指南副本一致性（guide copy parity） | `FLOW-KIT-用户指南.md` 共 **4 份载体**：仓库根 / `flow-kit-bundle/` / `dist/dsh-flow-kit/docs/` / `dist/dsh-flow-kit/vendor/flow-kit-bundle/`。定义上四份必须**逐字节一致**（md5 唯一）。2026-09-21 实测：根副本与其余三份分叉 2 行（提交 `5583e2a` 声称同步实际只改 bundle 一份），且 `Makefile` / `verify-claims.sh` 无任何守护 → 本 change 补机械断言。来自 user-guide-sync-2026-09b 漂移审计 §0 |
| 漂移清单（drift inventory） | 文档同步型 change 的事实基线：逐条「指南原文 + 行号 / 现状真相 + `文件:行号` 证据 / 建议改法 / 严重度」。本轮 43 条（14🔴/23🟡/6🟢）+ 12 条候选新增，产物在 `/tmp/guide-drift-report.md`（一次性输入，不入库）。来自 user-guide-sync-2026-09b 阶段 1 |
| 用户级配置单一源（user-level single config source） | 2026-09-21 起 stop-hook 配置**只有用户级一份**：claude `~/.claude/stop-hook.json`、opencode `~/.config/opencode/stop-hook.json`、dsh `~/.dsh/stop-hook.json`；解析链 = `STOP_HOOK_CONFIG` env > 用户级 > 插件模板 `hooks/config/stop-hook.json`。项目目录内 `.flow-kit/`（dsh）/`.claude/`（claude）**只放状态**（`stop-hook-state.json` / 报告 / `.flow-active`），不再生成也不再读取配置。来自 commits 5583e2a / 27ab400 |
| 单轮合并审查（single-pass merged review） | 阶段 6 现行形态：spec 合规（A）+ 代码质量 6 维（B）+ UI 视觉（C）在**同一次 pass** 内三维度并行判定；仅当 `verdict=fail` 且有 🔴 Critical 时追加**跨模型 spot-check**（ADR-014）。「三轮审查」为 2026-08-03 前的旧口径（`b7b6048`）。来自 `6-review.md:1,205-215,303-305` |
| 工件上限（max_artifact_bytes） | `independent_review.max_artifact_bytes`，**单位＝字节**（实现 `head -c`），缺省 **80000**（2026-09-21 由 20000 调大；CJK ÷3 ≈ 2.7 万汉字）。旧键 `max_artifact_chars` 可读但打 DEPRECATED；解析链 `FLOW_KIT_L3_MAX_ARTIFACT_BYTES` > `FLOW_KIT_L3_MAX_ARTIFACT_CHARS` > `L3_MAX_ARTIFACT_CHARS` > 80000。调大不改变截断告警语义。来自 brooks-review-fix-2026-09 |
| L3 熔断 bypass（circuit-breaker bypass） | L3 连续 fail 达 `max_failures_before_bypass`（默认 3，`0`=关闭）→ **自动**写 `.done`（`written_by=l3-bypass`、`L3_verdict=skipped`）+ 在 IR 文件追加「## L3 重审（bypass）」审计段 → pipeline 继续（不伪装 pass）。计数落 `.specs/<id>/.l3-attempts-<phase>`（删除即重试）。主 agent **手动 touch `.done` 会被 path-guard deny**。来自 `l3-review.sh:62-86` / `l3-done.sh:155-200` |
| L3 凭证死锁（credential-missing deadlock） | L3 调用的凭证由 `fk_resolve_api_credentials` 三 Path 链解析（claude：`ANTHROPIC_AUTH_TOKEN`(+`ANTHROPIC_BASE_URL`) > Path3 > `ANTHROPIC_API_KEY`；opencode/dsh：`FLOW_KIT_L3_AUTH_TOKEN`+`FLOW_KIT_L3_BASE_URL` 优先），rc=1 无凭证 / rc=2 Path3 不完整。**凭证缺失 → hook 不写 `.done` → PreToolUse 守卫又禁止主 agent 自产 → commit / 阶段推进全部阻塞**（README 口径：必配）。来自 `common.sh:282-330` / `l3-api.sh:17-47` |
| 指南版本日期口径（guide version date） | 指南文首版本行、分节「最后同步日期」、deck 封面日期行三处必须为**同一日期**（本轮 = `2026-09-21`）。历史上曾出现文首 `2026-09-03` 与分节 `2026-07-13` 自相矛盾（漂移报告 D43）。来自 user-guide-sync-2026-09b AC-1 |
<!-- user-guide-sync-2026-09b 追加 ↑ -->

<!-- user-guide-sync-2026-09b 已锁决策 ↓ -->
| 决策 | 内容 |
|---|---|
| 同步底稿 = bundle 副本 | `flow-kit-bundle/FLOW-KIT-用户指南.md` 较新（含 2026-09-21 配置用户级措辞）→ 本轮以它为底稿修订，再向根与 dist 两份对齐；四份 md5 必须唯一 |
| README 允许连改 | 核对 `README.md` / `dsh-flow-kit/README.md` 后发现过时口径**直接修正入库**（用户 2026-09-21 拍板），不留到下个 change |
| deck 扩页 | `flow-kit-用户指南.pptx` 由 20 页基线**大幅扩页（净增 ≥4）**，新增「安装面 / L3 审查链 / 质量门禁」专页（用户 2026-09-21 拍板）；生成器 + `deck_checks.py` 同步 |
| 副本一致性守护 | 新增一条**可失败**的机械断言（bats 用例，位置见 DESIGN），四份副本 md5 不一致即 rc≠0；须经「注入→变红→还原→复绿」实测，非恒绿 |
| 纯文档边界 | 不改运行时实现（`hooks/**`、`dsh-flow-kit/lib/**`、`skills/**`、`prompts/**` 的 diff 必须为 0）；新增测试文件属允许范围 |
<!-- user-guide-sync-2026-09b 已锁决策 ↑ -->
