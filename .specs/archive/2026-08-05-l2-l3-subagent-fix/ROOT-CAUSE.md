# ROOT-CAUSE.md — L2/L3 子 agent 拉起失败根因报告

- **change**: l2-l3-subagent-fix · 阶段 4 · T06 合成（基于 EVIDENCE-1..5）· 2026-08-05
- **goal 条件**: 调查解决 L2/L3 拉起 subagent 时，在 opencode / claude code 里因为
  agent 架构不一样、环境变量不一样导致拉不起来的问题

---

## 现象矩阵

| # | 现象 | 平台 | 触发环节 | 证据 |
|---|---|---|---|---|
| P1 | 子 agent 任务挂起至 30min 超时无产出（spawn 后无响应） | opencode | 环节③ prompt 派发段（task 路由） | EVIDENCE-3 步骤3 + 阶段 1 盲审首轮超时（30min） |
| P2 | L2 自动派发命令失败：no API credentials | opencode | 环节① l2-detect.sh 派发生成 | EVIDENCE-1（l2_dispatch_agent return 1） |
| P3 | L2/L3 模型解析为空（fk_resolve_model 返回空串）→ 两级降级 | opencode | 环节④ env 透传 + L3 API 直连 | EVIDENCE-4 步骤(a) |
| P4 | gate（PreToolUse 拦截）零触发，无任何 hook 事件记录 | opencode | 环节② PreToolUse gate 触发链路 | EVIDENCE-2（注册/运行时/平台能力三侧） |
| P5 | phase transition 命令双引号写法可绕过 gate 拦截（🟡 自身 bug） | 双平台 | 环节② gate 脚本 | EVIDENCE-2 附加发现（_fk_phase_direction 转义） |
| P6 | （无）claude code 侧四环节全通，无拉起失败现象（注：静态对照 + 架构前提，会话级 e2e 未实测 · 归 v2） | claude code | 全环节 | EVIDENCE-5 结论1 |

## 根因链

### 根因 #1 — gate 注册/触发链路在 opencode 结构性断裂（环节② · 结构性）

- **机制**：flow-kit 的 gate 只注册在 `~/.claude/settings.json` 的 PreToolUse matcher
  （`Bash|Write|Edit` → independent-review-gate.sh），该文件是 **claude code 专属**；
  opencode 不读取。opencode 1.18.9 原生 hook 事件仅 `file_edited` 与 `session_completed`
  两个（`@opencode-ai/sdk types.gen.d.ts L1170-1190`），**无 PreToolUse/Stop/SessionStart**；
  opencode.json plugin 数组无 opencode-claude-hooks 桥接插件；`.opencode/hooks/` 不存在。
  运行时日志（opencode.log）仅 permission 评估记录，零 hook 触发。
- **证据**：EVIDENCE-2（注册侧/运行时侧/平台能力侧三段实测）+ flow-kit-bundle/OPENCODE-INSTALL.md L42-43
- **影响**：opencode 下切阶段/commit/PR 的独立 review gate 完全不拦截 → 流程控制失效
  （不是「拉不起」，是「门没装」）

### 根因 #2 — L2 派发 subagent_type 路由 agent 绑定缺失（环节③ · 平台机制 · 拉起失败直接原因）

- **机制**：l2-detect.sh agent_type 映射（L61-116）：阶段 1/5 → `qa-expert`，2/3/7 →
  `architect-reviewer`，6 → `code-reviewer`。**鉴别实验（2026-08-05）**：
  `task(subagent_type=qa-expert)` 与 `task(subagent_type=architect-reviewer)`（model: inherit，
  阶段 2/3 实际成功用过的 agent）**均 30min 超时**；opencode.log 显示 subagent_type 路由创建的
  子会话 `agent=undefined model=undefined`——**与 agent 文件 model 字段值无关**（sonnet/inherit
  均失败），真实机制是本环境 task 工具的 subagent_type 路由未将 agent 定义绑定到子会话。
  对照：`task(category=unspecified-high)` → 4s 成功（Sisyphus-Junior，阶段 2/3 L2 盲审即此路径）。
- **双平台 diff（盲审发现 R2 落点）**：74 个交集 agent 中仅 qa-expert model 分歧
  （opencode: sonnet vs claude code: inherit）；opencode 175 / claude code 74 agents。
- **证据**：EVIDENCE-3 步骤3（鉴别实验）+ EVIDENCE-5 结论2 + opencode.log（agent=undefined model=undefined）
- **影响**：阶段 1（REQUIREMENT）与阶段 5（TEST）的 L2 盲审若走 subagent_type 路由在 opencode 必挂起；
  走 category 路由则正常

### 根因 #3 — L3 API 直连架构与 opencode provider 认证不兼容（环节④ · 架构性）

- **机制**：l3-api.sh（L20-21/69-89）env-var-first 直连
  `ANTHROPIC_BASE_URL/v1/messages` + `ANTHROPIC_AUTH_TOKEN`（Bearer）/ `ANTHROPIC_API_KEY`
  （x-api-key）；common.sh fk_resolve_model()（L249-264）三级链
  `ANTHROPIC_* > FLOW_KIT_* > .goal.l*_model`。opencode 运行时**不注入 ANTHROPIC_* env**
  （认证走 `auth.json` provider 配置），且本环境三级链全空 → fk_resolve_model 返回空 →
  L2 派发 write_model_missing_correction（return 3）、L3 return 3 降级。
- **证据**：EVIDENCE-4 步骤(a)（env grep NONE / fk_resolve_model 空串 / _l3_call_api dry 解析）
- **影响**：opencode 下 L2/L3 审查全部降级（不执行）

### 附加 bug — _fk_phase_direction 转义引号绕过 gate（🟡 · 双平台通用 · gate 自身）

- **机制**：gate-helpers-types.sh L67-75 `_fk_phase_direction` 用
  `current_phase[[:space:]]*=[[:space:]]*\"\K[0-7]` 提取目标 phase；命令以双引号包裹
  jq 表达式时（`jq ".goal.current_phase = \"4\""`）shell 转义 `\"` 使正则失配 → target 空 →
  返回 noop → gate-checks-review.sh `_gate_phase_transition` 提前 exit 0 放行。
- **证据**：EVIDENCE-2 附加发现（双引号 vs 单引号写法对照实测）
- **影响**：phase transition 命令双引号写法可绕过 gate（单引号写法无此问题，低利用性）

## 双平台差异矩阵

| 维度 | opencode | claude code | 差异性质 |
|---|---|---|---|
| hook 事件 | 仅 file_edited / session_completed | PreToolUse/PostToolUse/SessionStart/Stop 全 | 结构性（根因 #1） |
| gate 注册文件 | 不读 ~/.claude/settings.json | ~/.claude/settings.json | 结构性（根因 #1） |
| 子 agent 模型声明 | 175 agents 大量硬编码 sonnet/haiku | 74 agents 全部 inherit | 配置分歧（根因 #2） |
| 认证方式 | auth.json（provider 配置） | ANTHROPIC_AUTH_TOKEN env-var-first | 架构性（根因 #3） |
| 派发语法 | task(subagent_type/category) | Agent 工具 subagent_type | 语法差异（模板需翻译） |
| L2/L3 审查 | 全降级/挂起 | 全通 | 下游影响 |

## 风险分级修复方案

| 方案 | 内容 | risk | 落点 | 阶段 |
|---|---|---|---|---|
| D5-① | `/flow model l2=<model> l3=<model>` 配置持久化兜底（本环境用 deepseek-v4-flash） | risk: low | .flow-active.goal.l*_model（非禁动） | v1 ✅已实施 |
| D5-② | qa-expert.md `model: sonnet` → `inherit`（与 claude code 侧对齐，消除声明分歧） | risk: low | ~/.config/opencode/agents/qa-expert.md | v1 ✅已实施（不解决 subagent_type 路由，仅对齐） |
| D5-⑥ | L2 盲审派发改用 **category 路由**（subagent_type 路由 agent=undefined 不可用） | risk: low | l2-detect.sh 凭证缺失提示 + 派发指引（凭证缺失时提示 category= 用法） | v1 ✅已实施 |
| D5-③ | gate 注册桥接：opencode.json 加 opencode-claude-hooks 插件 + 项目级 .opencode/hooks/ | risk: high（触 gate 核心链注册面） | opencode.json / 安装链路 | v2 |
| D5-④ | L3 API 平台适配：opencode 检测 + provider 认证（auth.json）读取 | risk: high（触 l3 链禁动 l3-api.sh/l3-review.sh） | l3-api.sh / l3-review.sh | v2 |
| D5-⑤ | 修复 _fk_phase_direction 转义（正则改 `["'\\"]` 类兼容写法） | risk: high（触 gate 核心链 gate-helpers-types.sh） | gate-helpers-types.sh L67-75 | v2 |
| D5-⑦ | subagent_type 路由 agent 绑定修复（opencode 平台层，out 范围） | risk: high | opencode/task 工具层 | out |

## 受影响模块清单

| 模块 | 文件 | 影响 |
|---|---|---|
| L2 派发库 | flow-kit-bundle/hooks/stop/lib/l2-detect.sh | 根因 #2 触发点（qa-expert 映射） |
| L3 API 库 | flow-kit-bundle/hooks/stop/lib/l3-api.sh / l3-review.sh | 根因 #3 触发点（env-var-first 直连） |
| 模型解析 | flow-kit-bundle/hooks/stop/lib/common.sh（fk_resolve_model L249-264） | 根因 #3 空串来源 |
| gate 链 | gate-helpers-types.sh（_fk_phase_direction L67-75）/ gate-checks-review.sh | 附加 bug（转义绕过） |
| agent 定义 | ~/.config/opencode/agents/qa-expert.md | 根因 #2 修复点（v1） |
| 平台配置 | ~/.claude/settings.json / opencode.json / .opencode/hooks/ | 根因 #1（v2 桥接） |
| 文档 | flow-kit-bundle/OPENCODE-INSTALL.md | 已知限制记录（L42-43 / L109-114） |
