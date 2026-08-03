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
| fk_resolve_model | 公共函数（`hooks/stop/lib/common.sh`），按三级优先级链解析 L2/L3 审查模型名。用法：`model=$(fk_resolve_model "L3")`。全部未配置时返回空字符串（调用方负责降级） |
| FLOW_KIT_L2_MODEL / FLOW_KIT_L3_MODEL | 新增 env var，用于临时覆盖 L2/L3 审查模型（优先级 2，介于 ANTHROPIC_* env var 和 .flow-active 配置字段之间） |
| l2_model / l3_model | `.flow-active.goal` 的新增可选字段，持久化 L2/L3 审查模型名（优先级 3）。通过 `/flow model l2=<m> l3=<m>` 设置 |
| model resolution priority chain | L2/L3 模型名的三级优先级解析策略：1. ANTHROPIC_* env var（CC 原生）→ 2. FLOW_KIT_* env var（临时覆盖）→ 3. .flow-active.goal.l*_model（持久化配置）→ 4. 空字符串（优雅降级）。每级取到非空值即停 |
| graceful degradation (model) | fk_resolve_model 返回空字符串时的降级策略：不崩溃（不用 `:?` 终止），输出配置提示 + 写 `.flow-active.correction`（type=l*-model-missing），SessionStart 收割展示 banner |
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
| TD-002 | ✅ | `flow-kit-bundle/hooks/stop/` + `lib/` | **核心 hook lib 已覆盖**（`flow-kit-artifacts.sh` 由 test_flow_artifacts 12 tests 覆盖、common 由 test_common 21 tests 覆盖）；残留：stop 链主脚本（22-git/24-session/26-workflow/99-report 等协调层，逻辑薄）仍无直接 smoke test | ✅ 已完成（td-test-infra · 2026-07-10）：test_stop_chain 已覆盖 00/22/24/26/99（bash-n+shebang+grep），本次补 23/27/28/29/30/33 共 6 个 [business] smoke；covered 5 + partial 12（[coord] 留 v2）；详见 `.specs/td-test-infra/SUMMARY.md`| `M-health 2026-06-20` · 校准 `M-health 2026-06-24`（测试 43→94）|
| TD-003 | ✅ | `flow-kit-bundle/flow-kit/prompts/{5-test,6-review,7-integration}.md` 入场 jq | `--from 0` pipeline 扩展时，4-dev.md + GO.md 已加 `start_phase` 读取，但这三个 prompt 仍是 `current_phase // "4"`（漏改）。实际影响低（current_phase 字段在 transition 时已正确更新，fallback 不触发），但一致性应补齐 | 统一三个 prompt 入场 jq 为 `current_phase // .start_phase // "4"` | `M-health 2026-06-20`（goal-pipeline-phase0 遗留）· **已修复 `0601dda`** · bats 77/78/79 验证（`M-health 2026-06-24` 复核）|
| L-004 | 🟢 | `flow-kit-bundle/lib/install_hooks.sh` | 共享函数 < 3 阈值，`lib/utils.sh` 保持推迟 | 等新增 ≥ 2 个共享辅助函数时再建 | `init-git-repo` T03 · 保持 deferred |
| TD-004 | 🟡 | `flow-kit-bundle/flow-kit/prompts/*.md`（15+ 文件） | Markdown prompt 样板重复率 22%——toll-gate 流程、独立 review 调度、Pipeline 规则等共享段在多文件中逐字重复，规则变更时须手动同步 N 处 | 抽取 `_shared/` 引用片段；下次 prompt 规则变更时一并重构 | `M-health 2026-07-02` |
| TD-005 | 🟡 | `flow-kit-bundle/flow-kit/prompts/6-review.md` + `7-integration.md` | jq pipeline goal 解析逻辑（68 行）在 6-review 和 7-integration 两个 prompt 中逐字重复——提取 goal.scope / start_phase / current_phase / phases_done / gates | 抽取到 `flow-kit/reference/` 共享片段；下次改 pipeline goal 解析时一并重构 | `M-health 2026-07-04` |
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
| TD-019 | 🟡 | `flow-kit-bundle/hooks/stop/{21,22,23,24,25,26}-*.sh` | check_* 函数模板在 6 模块中逐字重复（`check_enabled` guard → 读状态 → 检查条件 → `module_output`）。20+ 处执行模式相同，仅条件表达式和消息不同 | 引入声明式 check 注册或 `run_check()` 包装函数。跨 6 模块重构，需确认设计决策 | `M-health 2026-07-10 Full Sweep` |
| TD-020 | 🟡 | `flow-kit-bundle/hooks/stop/lib/common.sh:139-159` | `write_failed_state()` 定义但全仓 0 调用 → 死代码。CONTEXT.md 已标记过时。21 行浪费 + 18 个 source 文件的认知负荷 | 移除函数定义 + 更新 CONTEXT.md 条目。确认无未来使用计划后执行 | `M-health 2026-07-10 Full Sweep` |
| TD-021 | 🟡 | 全局命名约定 | 5 种命名前缀（`fk_` / `_fk_` / `check_` / `l2_`/`l3_` / `_fai_`）无文档说明各自使用场景 → 新人/AI 无法从函数名推断模块和可见性 | CONTEXT.md 加「命名约定」段，明确公共 API（`fk_`）vs 私有（`_<module>_`）规则。批量重命名延后 | `M-health 2026-07-10 Full Sweep` |
| TD-022 | 🟢 | `flow-kit-bundle/lib/install_brooks.sh` + `install_hooks.sh` | `install_brooks_lint()` 152 行 + `install_hooks()` 199 行 — 0 直接单元测试（仅集成覆盖）。修改安装逻辑时缺少快速反馈 | 补充 DRY_RUN 模式单元测试（bats）| `M-health 2026-07-10 Full Sweep` |

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
