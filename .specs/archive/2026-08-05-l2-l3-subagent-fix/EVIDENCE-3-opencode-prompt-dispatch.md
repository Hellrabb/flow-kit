# EVIDENCE-3 — opencode 环节③实测：prompt 派发段（task 路由）

- **change**: l2-l3-subagent-fix · 阶段 4 · T03 · 2026-08-05

## 实测步骤

1. **6 个阶段 prompt 调度段读取**（`~/.claude/flow-kit/prompts/{1-requirement,2-design,3-task,5-test,6-review,7-integration}.md`）：
   各 prompt 均含「独立 review 调度」段，检测逻辑一致：
   `.flow-active.goal.gate_config["N-phase"]` ∈ {`L2`,`both`} → 本阶段需 L2 盲审；
   L2-only 时主 agent 写 6 键 KVP `.done` 标志；`independent`/`true` 向后兼容映射为 `both`。

2. **l2_dispatch_prompt() 模板生成**（`flow-kit-bundle/hooks/stop/lib/l2-detect.sh` L61-116）：
   phase 3 → `subagent_type=architect-reviewer`；模板要求「原样注入 L2-blind-review.md」+
   阶段/change-id/工件/输出四参数。该模板语言是 **claude code 的 Agent 工具语法**。

3. **opencode 子 agent 路由实测（关键）**：
   - `task(category="quick", prompt="Reply READY")` → **4s 完成**，Model = `deepseek/deepseek-v4-flash (category: quick)`，
     路由到 Sisyphus-Junior。category 层模型解析正常。
   - `task(subagent_type="qa-expert", prompt="Reply READY")` → **30 分钟无产出，poll inactivity timeout**（修复 model: sonnet→inherit 后重测仍超时，ses_02e8f46b0ffeEcavAH1zWIILaF）。
   - `task(subagent_type="architect-reviewer", prompt="Reply READY")`（model: inherit，阶段 2/3 实际成功用过的 agent）→ **同样 30 分钟超时**（ses_02e737e2affeMxTSQCdVvNYbT7）。
   - **鉴别实验结论**：opencode.log 显示 subagent_type 路由创建的子会话记录 `agent=undefined model=undefined`——
     与 agent 文件 model 字段值无关（sonnet 或 inherit 均失败）。真实机制：**本环境 task 工具的
     subagent_type 路由未将 agent 定义绑定到子会话**（agent/model 均 undefined），任务挂起至超时。
     可用路径是 category 路由（阶段 2/3 L2 盲审用 category=unspecified-high 成功）。

4. **双平台 agent 定义对比**：
   - opencode 侧 `~/.config/opencode/agents/`：100+ agents，大量 `model: sonnet` / `model: haiku` 硬编码
   - claude code 侧 `~/.claude/agents/`：**全部 `model: inherit`**
   - 同一 agent（qa-expert）双平台定义已分歧。

## 观测

| 项 | opencode | claude code |
|---|---|---|
| 子 agent 模型声明 | 硬编码 sonnet/haiku/inherit | 全部 inherit |
| 派发语法 | task(subagent_type/category) | Agent 工具 subagent_type |
| model: sonnet 解析 | ❌ 无 anthropic provider，不可解析 | ✅ 有 ANTHROPIC_* 可解析 |
| qa-expert 拉起 | ⛔ 30min 超时无产出 | ✅ 正常 |

## 现象

- 现象 B（子 agent 进程缺 env var 致模型配置/API 鉴权解析失败）命中：opencode 子 agent
  进程内 `model: sonnet` 无法解析为可用 provider；**鉴别实验升级**：subagent_type 路由
  创建的子会话 agent=undefined model=undefined（与 model 字段值无关），任务挂起至超时。
- 与第一轮 L2 盲审（qa-expert 30min 超时）行为一致，可复现；architect-reviewer（inherit）
  同样超时——确认非 model 字段值问题，是 subagent_type 路由的 agent 绑定机制缺失。

## 结论（环节③）

1. **根因 #2（opencode 侧，平台机制）**：L2 派发的 `subagent_type` 路由（1/5=qa-expert）
   在本环境创建的子会话 agent=undefined model=undefined → 拉起失败挂起。
   鉴别实验证明与 model 字段值无关（sonnet/inherit 均失败）。
   → 可用路径：**category 路由**（阶段 2/3 L2 盲审 category=unspecified-high 已验证成功）。
   → D5 候选②（qa-expert.md model: sonnet → inherit）：保留（消除双平台声明分歧，与
   claude code 侧对齐，无害），但不解决 subagent_type 路由挂起——agent 绑定修复属平台层（v2/out）。
2. **prompt 模板语法**：l2_dispatch_prompt 输出 claude code Agent 工具语法模板；
   opencode 下需翻译为 `task(category=..., run_in_background=...)` 语义（category 路由可用）。
3. **gate_config 检测链路**：6 prompts 一致，无平台差异——调度指令本身双平台通用。
