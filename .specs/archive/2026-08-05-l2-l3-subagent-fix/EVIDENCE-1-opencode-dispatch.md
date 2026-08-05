# EVIDENCE-1 — opencode 环节①实测：l2-detect.sh 派发生成

> 任务：T01（opencode 环节①） · change-id: l2-l3-subagent-fix
> 日期：2026-08-05 · 平台：opencode 1.18.9（本运行时）
> 对应：REQUIREMENT.md AC-1 环节①（opencode 侧）

## 实测步骤

1. 读 `flow-kit-bundle/hooks/stop/lib/l2-detect.sh`（303 行），逐函数核实派发生成路径
2. `source` 后调用 `l2_dispatch_prompt 3 l2-l3-subagent-fix`，观察 phase=3 派发模板输出
3. 调用 `l2_dispatch_agent 3 l2-l3-subagent-fix <tmpdir>`（真实 API 路径），观察凭证检查与返回值
4. `FLOW_KIT_L2_MOCK=1 l2_dispatch_agent 3 l2-l3-subagent-fix <tmpdir>`（mock 路径），观察 mock 派发写入

## 观测结果

### l2_dispatch_prompt()（L61-116）— 模板生成正常

- agent_type 映射（L71-77）实测：phase=3 → `architect-reviewer`，与 DESIGN §0.5.1 及 prompts 调度段三方一致（1/5=qa-expert, 2|3=architect-reviewer, 6=code-reviewer, 7=architect-reviewer）
- 输出为 ╔═ 框模板：`subagent_type: architect-reviewer` + `description: "L2 blind review phase 3"` + prompt 骨架（原样注入 L2-blind-review.md + 阶段/change-id/工件/输出四参数）
- **现象**：模板为 Claude Code 风格的「Agent tool」复制粘贴指令。在 opencode 下等效操作是 task() 的 subagent_type 参数——模板本身不报错，但**假定 subagent_type 对应的 agent 定义存在且模型可解析**

### l2_dispatch_agent()（L128-303）— 真实 API 路径被凭证检查拦截

- 凭证检查（L169-174）先于模型解析（L217-222）执行
- 实测：本环境 `ANTHROPIC_AUTH_TOKEN`/`ANTHROPIC_API_KEY` 均 **unset**（env 中 `^ANTHROPIC_` 计数 0）→ 输出 `[l2-dispatch] no API credentials (ANTHROPIC_AUTH_TOKEN or ANTHROPIC_API_KEY)`，**return 1**
- 此路径是 curl 直连 `https://api.anthropic.com/v1/messages`（或 `$ANTHROPIC_BASE_URL`），**完全不经过 opencode 运行时/模型 provider 层**

### FLOW_KIT_L2_MOCK=1 mock 路径 — 正常

- 实测 return 0，写入 `## L2 盲审（mock · 20260805-164352）` 段（含 Mock Finding + Verdict: pass，278B），原子 tmp+mv
- mock 路径不触碰任何外部 API，仅用于 bats 测试基建

## 现象分类（对照 CHANGE.md「拉起失败」两类现象）

- **现象 B（env var 缺失类）命中**：真实 API 路径因 ANTHROPIC_* 凭证 unset 而 return 1——这属于「子 agent 进程缺 env var 致 API 鉴权解析失败」的旁证：l2_dispatch_agent 的鉴权依赖 ANTHROPIC_* env，在 opencode 环境（无 anthropic provider）必然失败
- **现象 A（派发命令架构不兼容）部分命中**：l2_dispatch_prompt 模板是 CC 风格 Agent tool 指令，opencode 无此工具形态；opencode 等效为 task(subagent_type=...)，但 agent 定义模型可解析性（qa-expert → model: sonnet，本环境无 sonnet）是独立问题，归环节③记录（T03）

## 结论（环节① opencode 是否可拉起）

- **环节① 派发模板生成：正常**（l2_dispatch_prompt 不依赖运行时，纯文本生成，opencode 下可用）
- **环节① 自动派发（l2_dispatch_agent）：opencode 下无法完成真实 L2 派发**——凭证检查先行，ANTHROPIC_* env unset → return 1。即使设置凭证，curl 直连 anthropic.com 也绕开 opencode 的模型 provider 层（本环境 provider 为 alibaba-token-plan-cn 等，无 anthropic）
- mock 模式可用作测试路径，但生产派发在 opencode 环境需凭证注入或改走 provider 兼容路径（归 ROOT-CAUSE 根因链）

## 脱敏声明

- 涉及 env var 仅记录变量名 + set/unset 状态，值一律脱敏为 ***（AC-2 脱敏句）
- 未触发任何真实 API 调用（凭证缺失即 return，无网络请求）
