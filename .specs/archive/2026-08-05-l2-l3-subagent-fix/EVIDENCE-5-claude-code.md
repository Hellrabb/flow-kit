# EVIDENCE-5 — claude code 侧四环节实测 + 双平台 agent 定义 diff

- **change**: l2-l3-subagent-fix · 阶段 4 · T05 · 2026-08-05
- **read_files**: l2-detect.sh / common.sh / l3-api.sh + 双平台 6 agents

## 实测步骤

### (a) claude code 侧四环节可达性（CLI 2.1.71）

| 依赖 | claude code 运行时 | 实测 |
|---|---|---|
| claude CLI | 2.1.71 | ✅ /usr/local/bin/claude |
| jq | 必需（.flow-active 操作） | ✅ /usr/bin/jq |
| curl | 必需（L2/L3 API 直连） | ✅ /usr/bin/curl |
| subagent_type 原生支持 | Agent 工具 | ✅ 原生（l2_dispatch_prompt 模板即为此语法） |
| ANTHROPIC_AUTH_TOKEN | 天然环境 | claude code 会话运行时注入（宿主 shell 无，hook 子进程继承会话 env） |
| hook 层 Bash 子进程 env | PreToolUse/Stop hook | claude code 子进程继承会话 env（含 ANTHROPIC_*）——env-var-first 架构成立 |

说明：宿主 shell 无 ANTHROPIC_*（本会话为 opencode 环境），但 claude code 自己的
hook 执行环境会注入其会话凭证——这正是 l3-api.sh / l2-dispatch_agent 设计所依赖的前提。
claude code 侧四环节链路：注册（~/.claude/settings.json）→ 触发（PreToolUse/Stop
hook 原生）→ 派发（Agent 工具原生 + env-var-first API 直连）→ 凭证（ANTHROPIC_* 注入）——
**全通（限定：静态对照 + 架构前提推断；claude code 会话级 e2e 未实测，归 v2）**。

### (b) 双平台 agent 定义 diff（盲审发现 R2 · 逐 agent 完整 frontmatter）

| agent | opencode model | claude code model | 分歧 | opencode tools | claude code tools |
|---|---|---|---|---|---|
| qa-expert | **sonnet** | **inherit** | ⚠️ **是** | （未限） | Read, Grep, Glob, Bash |
| architect-reviewer | inherit | inherit | 否 | （未限） | Read, Write, Edit, Bash, Glob, Grep |
| code-reviewer | inherit | inherit | 否 | （未限） | Read, Write, Edit, Bash, Glob, Grep |

- 双平台 agent 数量：opencode 175 个 / claude code 74 个（opencode 侧多出 100+ 个
  claude code 没有的 agent 定义；74 个交集 agent 中仅 qa-expert 有 model 分歧）
- **关键关联**：qa-expert 是 l2-detect.sh agent_type 映射的 **阶段 1/5 目标**
  （`1|5 → qa-expert`）——即 REQUIREMENT 阶段（阶段 1）与 TEST 阶段（阶段 5）的
  L2 盲审会派发到 qa-expert；该 agent 在 opencode 下 `model: sonnet` 不可解析 → 拉起失败。
  architect-reviewer（2/3/7 目标）与 code-reviewer（6 目标）双平台均 inherit → 无此问题。

## 现象

- 阶段 1（REQUIREMENT）L2 盲审首轮超时（qa-expert · opencode · 30min 无产出）——
  与「唯一 model 分歧 agent」精确对应，非随机。
- 阶段 2/3（architect-reviewer · inherit）L2 盲审正常完成（3m25s / 1m16s）——
  **澄清**：阶段 2/3 派发实际走 `category=unspecified-high` 路由（非 subagent_type），见
  EVIDENCE-3 步骤3 鉴别实验 + DEV-SUMMARY.md。`inherit` 并非 subagent_type 路由可拉起的机制。

## 结论（T05）

1. **claude code 侧四环节全通（静态对照 + 架构前提）**：CLI 2.1.71 + jq + curl + 原生 Agent 工具 +
   ANTHROPIC_* env 注入——flow-kit 的 L2/L3 派发设计在 claude code 原生环境成立；
   claude code 会话级 e2e 未实测（需 claude code 运行时 + 凭证，归 v2）。
2. **根因 #2 闭环（唯一分歧点）**：双平台 74 个交集 agent 中仅 qa-expert 的 model 字段分歧
   （sonnet vs inherit），且该 agent 恰为阶段 1/5 L2 盲审的派发目标 →
   opencode 下 `model: sonnet` 无 provider 可解析 → 拉起失败挂起。
   **重要修订（阶段 6 L2 盲审发现#4）**：`D5 候选②（sonnet→inherit）`仅对齐双平台声明分歧，
   **不解决 subagent_type 路由拉起问题**——鉴别实验（EVIDENCE-3 步骤3 + DEV-SUMMARY.md
   鉴别实验段）实测 `task(subagent_type=architect-reviewer)`（inherit）同样 30min 超时、
   opencode.log 子会话 `agent=undefined model=undefined`。即 subagent_type 路由创建的子会话
   无 agent/model 绑定，与 agent 文件 model 字段值无关；阶段 2/3 成功实为 category 路由派发。
   opencode 下「拉得起」的正确路径是 `category=` 派发（D5 候选⑥），而非 subagent_type。
   D5 候选②保留（双平台声明对齐无害），但其修复价值仅限声明层。
3. claude code 侧无需修复（双平台兼容以 opencode 侧适配为准）；qa-expert tools
   限制差异（claude code 侧仅 4 工具）为次要差异，不影响派发拉起。
