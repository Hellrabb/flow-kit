# TASK: L2/L3 子 agent 双平台拉起失败根因调查与低风险修复

- **Change ID**: l2-l3-subagent-fix
- **关联**: `@.specs/l2-l3-subagent-fix/REQUIREMENT.md`、`@.specs/l2-l3-subagent-fix/DESIGN.md`

---

## 波次划分

```
Wave 1 (parallel): T01[P], T02[P], T03[P], T04[P], T05[P]
Wave 2:            T06               (depends on T01, T02, T03, T04, T05)
Wave 3:            T07               (depends on T06 · 条件任务：用户确认修复清单后执行)
Wave 4:            T08               (depends on T07, T06)
```

> 同 wave = 可并行；跨 wave = 必须顺序执行。
> Wave 1 各任务写**独立 evidence 文件**（EVIDENCE-N-*.md），避免 ROOT-CAUSE.md 共享写冲突；T06 负责合成。

---

## 任务清单

```xml
<task id="T01" parallel="true" status="done" model-tier="standard">
  <name>opencode 环节①实测：l2-detect.sh 派发生成</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
    ~/.config/opencode/agents/qa-expert.md
    ~/.config/opencode/agents/architect-reviewer.md
    ~/.config/opencode/agents/code-reviewer.md
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/EVIDENCE-1-opencode-dispatch.md
  </write_files>
  <action>
    opencode 侧环节①实测（DESIGN D1 / 调查链①）：逐函数核实 l2_dispatch_prompt()（agent_type 映射 1/5=qa-expert, 2/3/7=architect-reviewer, 6=code-reviewer）与 l2_dispatch_agent()（curl+Anthropic API 异步派发路径）。对当前 phase=3 场景：实际运行 l2-detect.sh 的派发命令生成路径，记录 opencode 下 task() 的 subagent_type 路由行为与 l2_dispatch_agent 的 curl 直连调用结果（FLOW_KIT_L2_MOCK=1 或真实 API 二选一，真实调用注意凭证脱敏——值一律 ***，只记录变量名+set/unset 状态，见 REQUIREMENT AC-2 脱敏句）。输出：实测步骤 + 观测结果 + 现象（正常/拉起失败+报错原文脱敏）+ 结论（环节①在 opencode 是否可拉起）。写入 EVIDENCE-1。
  </verify>
    test -s .specs/l2-l3-subagent-fix/EVIDENCE-1-opencode-dispatch.md
  </verify>
  <done>EVIDENCE-1 含环节①实测结论与证据，对应 AC-1 环节①（opencode 侧）</done>
  <depends_on></depends_on>
</task>

<task id="T02" parallel="true" status="done" model-tier="standard">
  <name>opencode 环节②实测：PreToolUse gate 触发链</name>
  <read_files>
    flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-helpers-types.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
    flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/done-validation.sh
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/EVIDENCE-2-opencode-gate.md
  </write_files>
  <action>
    opencode 侧环节②实测（调查链②）：核实 independent-review-gate.sh 编排链（_run_review_gates 七 gate：path-guard → phase filter → gate active → done validation → tamper → phase transition → deny reason）在 opencode 运行时下是否正常触发 L2 派发。关键验证点：gate-checks-basic.sh L53/62-63/90 对 l2_dispatch_agent/l2_dispatch_prompt 的调用在 opencode 的 Bash PreToolUse 环境是否可达（PATH / jq / curl 可用性）；阶段切换写入 .flow-active.phase 时 gate 是否拦截/放行（TD-014 教训：jq 字段名前置问题已修）。用 Bash 直接执行 gate 脚本 + payload 注入方式实测（集成级，非单元）。输出：实测步骤 + 观测 + 现象 + 结论。凭证脱敏同 AC-2。写入 EVIDENCE-2。
  </verify>
    test -s .specs/l2-l3-subagent-fix/EVIDENCE-2-opencode-gate.md
  </verify>
  <done>EVIDENCE-2 含环节②实测结论与证据，对应 AC-1 环节②（opencode 侧）</done>
  <depends_on></depends_on>
</task>

<task id="T03" parallel="true" status="done" model-tier="standard">
  <name>opencode 环节③实测：prompt 派发段</name>
  <read_files>
    flow-kit-bundle/flow-kit/prompts/3-task.md
    flow-kit-bundle/flow-kit/prompts/1-requirement.md
    flow-kit-bundle/flow-kit/prompts/2-design.md
    flow-kit-bundle/flow-kit/prompts/5-test.md
    flow-kit-bundle/flow-kit/prompts/6-review.md
    flow-kit-bundle/flow-kit/prompts/7-integration.md
    flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    ~/.config/opencode/agents/qa-expert.md
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/EVIDENCE-3-opencode-prompt.md
  </write_files>
  <action>
    opencode 侧环节③实测（调查链③）：核实 6 个阶段 prompt 的「独立 review 调度」段的 subagent_type 模板与 l2-detect.sh agent_type 映射三方一致（prompts × l2-detect.sh × L2-blind-review.md）；在 opencode 下实测 prompt 派发段给出的 Agent tool 模板是否可被 opencode 执行（subagent_type 名在 opencode agents 中是否解析，qa-expert 声明 model: sonnet 是否可解析——第一轮 L2 盲审超时的候选根因）。输出：每 prompt 派发模板摘录 + opencode 解析实测 + 现象 + 结论。写入 EVIDENCE-3。
  </verify>
    test -s .specs/l2-l3-subagent-fix/EVIDENCE-3-opencode-prompt.md
  </verify>
  <done>EVIDENCE-3 含环节③实测结论与证据（含 qa-expert model: sonnet 解析结论），对应 AC-1 环节③（opencode 侧）</done>
  <depends_on></depends_on>
</task>

<task id="T04" parallel="true" status="done" model-tier="standard">
  <name>opencode 环节④实测：env var 透传 + L3 API 直连 + 模型绑定层（盲审发现 R1）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    flow-kit-bundle/hooks/stop/lib/l3-review.sh
    flow-kit-bundle/hooks/stop/lib/l3-prompt.sh
    flow-kit-bundle/hooks/stop/lib/l3-done.sh
    .specs/adr/020-opencode-task-capability.md
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/EVIDENCE-4-opencode-env-model.md
  </write_files>
  <action>
    opencode 侧环节④实测（调查链④ + 盲审发现 R1 修复落点）：(a) env var 透传——核实 fk_resolve_model() 三级链（ANTHROPIC_* > FLOW_KIT_* > .goal.l*_model）在 opencode 子 agent 进程中的 env 可见性：opencode task 派发的子进程是否继承宿主 shell env var；实测 l3-api.sh _l3_call_api() 的 ANTHROPIC_BASE_URL/AUTH_TOKEN 在 opencode 运行时是否可解析（值脱敏）。(b) 模型绑定层验证（盲审发现 R1）——按 ADR-020 三层模型选择（Harness 配置层 / Category 路由层 / 子 agent 覆盖层）实测 task() 路由实际落到哪个模型 ID（opencode models 列表 + agents 声明对照），差异矩阵回答"子 agent 模型由哪一层决定"。输出：env 链实测 + 模型绑定层实测 + 现象 + 结论。写入 EVIDENCE-4。
  </verify>
    test -s .specs/l2-l3-subagent-fix/EVIDENCE-4-opencode-env-model.md
  </verify>
  <done>EVIDENCE-4 含环节④ env 透传实测 + 盲审发现 R1（模型绑定层）验证结论（明确回答模型由哪一层决定），对应 AC-1 环节④ + 盲审发现 R1 修复</done>
  <depends_on></depends_on>
</task>

<task id="T05" parallel="true" status="done" model-tier="standard">
  <name>claude code 侧四环节实测 + 双平台 agent 定义 diff（盲审发现 R2）</name>
  <read_files>
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    flow-kit-bundle/hooks/stop/lib/common.sh
    flow-kit-bundle/hooks/stop/lib/l3-api.sh
    ~/.claude/agents/qa-expert.md
    ~/.claude/agents/architect-reviewer.md
    ~/.claude/agents/code-reviewer.md
    ~/.config/opencode/agents/qa-expert.md
    ~/.config/opencode/agents/architect-reviewer.md
    ~/.config/opencode/agents/code-reviewer.md
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/EVIDENCE-5-claude-code.md
  </write_files>
  <action>
    claude code 侧对照实测（DESIGN D1 双平台对照 + 盲审发现 R2 修复落点）：(a) 四环节在 claude code CLI 2.1.71 下的可达性——subagent_type 原生支持确认；l2-detect.sh / common.sh / l3-api.sh 的依赖（jq/curl/ANTHROPIC_*）在 claude code 运行时是否可用（claude code 有 ANTHROPIC_AUTH_TOKEN 的天然环境，但需实测 hook 层 Bash 子进程是否继承）。(b) 双平台 agent 定义 diff（盲审发现 R2）——逐 agent 对比 ~/.config/opencode/agents/<name>.md vs ~/.claude/agents/<name>.md 的 model 字段（已实测 qa-expert: sonnet vs inherit 分歧，需验证其余两 agent + 完整字段 diff），表格化差异。输出：claude code 四环节实测 + agent 定义 diff 表 + 结论。凭证脱敏同 AC-2。写入 EVIDENCE-5。
  </verify>
    test -s .specs/l2-l3-subagent-fix/EVIDENCE-5-claude-code.md
  </verify>
  <done>EVIDENCE-5 含 claude code 侧四环节实测 + 盲审发现 R2（双平台 agent 定义 diff）表（逐 agent），对应 AC-1（claude code 侧）+ AC-2 双平台证据 + 盲审发现 R2 修复</done>
  <depends_on></depends_on>
</task>

<task id="T06" status="done" model-tier="standard">
  <name>ROOT-CAUSE.md 五段根因报告合成 + risk 分级修复清单</name>
  <read_files>
    .specs/l2-l3-subagent-fix/EVIDENCE-1-opencode-dispatch.md
    .specs/l2-l3-subagent-fix/EVIDENCE-2-opencode-gate.md
    .specs/l2-l3-subagent-fix/EVIDENCE-3-opencode-prompt.md
    .specs/l2-l3-subagent-fix/EVIDENCE-4-opencode-env-model.md
    .specs/l2-l3-subagent-fix/EVIDENCE-5-claude-code.md
    .specs/l2-l3-subagent-fix/CHANGE.md
    .specs/l2-l3-subagent-fix/REQUIREMENT.md
    .specs/CONTEXT.md
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/ROOT-CAUSE.md
  </write_files>
  <action>
    合成五段根因报告（REQUIREMENT AC-1 结构）：① 现象矩阵（两类拉起失败现象 × 双平台）② 根因链（每根因附文件:行号 + EVIDENCE-N 引用 + 双平台实测证据）③ 双平台差异矩阵（含盲审发现 R1 模型绑定层行：子 agent 模型由哪一层决定；含盲审发现 R2 agent 定义对比行）④ 风险分级修复方案（每条 risk: low/high；high 项标注触及 gate 核心链/禁动清单 → v2 禁止 v1 实施；每条方案标 risk 等级——MINOR-DEFERRED 台账要求每条带 risk: low|high）⑤ 受影响模块清单（补入 gate-checks-review.sh——MINOR-DEFERRED 台账 R3）。每条根因必须双平台各 ≥1 次实测证据（AC-2）；不可复现的平台显式标注（AC-2 逃生口）。附修复方案清单供用户确认（T07 入口）。执行 AC-1 验证：grep -cE 'l2-detect|independent-review-gate|prompt 派发段|env var 透传|l3-review' ROOT-CAUSE.md 输出 ≥ 4（四环节锚点各至少命中一次）。
  </verify>
    [ "$(grep -cE '^## (现象矩阵|根因链|双平台差异矩阵|风险分级修复方案|受影响模块清单)' .specs/l2-l3-subagent-fix/ROOT-CAUSE.md)" -ge 5 ] && [ "$(grep -cE 'l2-detect|independent-review-gate|prompt 派发段|env var 透传|l3-review' .specs/l2-l3-subagent-fix/ROOT-CAUSE.md)" -ge 4 ]
  </verify>
  <done>ROOT-CAUSE.md 五段齐全、四环节锚点 grep ≥ 4、修复方案逐条 risk 分级，对应 AC-1/AC-2/AC-3</done>
  <depends_on>T01, T02, T03, T04, T05</depends_on>
</task>

<task id="T07" status="done" model-tier="standard">
  <name>low 风险修复实施（条件：用户确认修复清单）</name>
  <read_files>
    .specs/l2-l3-subagent-fix/ROOT-CAUSE.md
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    ~/.config/opencode/agents/qa-expert.md
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/ROOT-CAUSE.md
    .specs/l2-l3-subagent-fix/DEV-SUMMARY.md
    flow-kit-bundle/hooks/stop/lib/l2-detect.sh
    ~/.config/opencode/agents/qa-expert.md
  </write_files>
  <action>
    条件任务（REQUIREMENT AC-4 · DESIGN D4/D5）：先将 T06 的 risk:low 修复清单 batch 呈现给用户确认（plan-conflict-scan 已确认无禁动清单越界；D5 预研候选：① /flow model 配置（.flow-active，经 /flow 子命令操作不直接写文件）② qa-expert agent model: sonnet → inherit（~/.config/opencode/agents/qa-expert.md，用户 scope）③ l2_dispatch_agent 凭证缺失路径增加运行时探测提示/降级文档（l2-detect.sh，触碰模块非禁动））。用户确认后才实施；用户确认清单为空 → AC-4/AC-5 记"不适用"于 DEV-SUMMARY.md，交付物=ROOT-CAUSE.md（R7 台账空分支）。实施规则：high 项（gate 核心链/禁动清单）一律不实施归 v2；每项修复实施后立即实测验证（opencode 实测拉起 L2，mock 边界=派发机制走真实运行时、仅审查内容可 mock——REQUIREMENT AC-4 修复句）。实施记录写 DEV-SUMMARY.md（做了什么/为什么/偏离 DESIGN 哪里/不可行原因）。
  </verify>
    test -s .specs/l2-l3-subagent-fix/DEV-SUMMARY.md && (grep -qE '拉起|spawn' .specs/l2-l3-subagent-fix/DEV-SUMMARY.md || grep -q '不适用' .specs/l2-l3-subagent-fix/DEV-SUMMARY.md) && [ -z "$(git diff --stat | grep -E 'independent-review-gate|29-independent-review|l3-review|checkpoint-lib')" ]
  </verify>
  <done>用户确认的 low 修复全部实施并实测验证；空清单则 AC-4/AC-5 记不适用，对应 AC-4</done>
  <depends_on>T06</depends_on>
</task>

<task id="T08" status="done" model-tier="standard">
  <name>DEV-SUMMARY 实测记录 + 基线回归（AC-5）</name>
  <read_files>
    .specs/l2-l3-subagent-fix/DEV-SUMMARY.md
    .specs/l2-l3-subagent-fix/ROOT-CAUSE.md
    test/
    Makefile
  </read_files>
  <write_files>
    .specs/l2-l3-subagent-fix/DEV-SUMMARY.md
  </write_files>
  <action>
    收尾验证（REQUIREMENT AC-5 · 基线 662/662 出处 STATE.md test-failures-fixup-2026-08 · 2026-08-03 · 当前实测 710 @test）：执行机器比对 npx bats test/ 2>&1 | grep -c '^not ok'，输出必须为 0；非 0 时 fail 清单 + pre-existing 归因证据写入 DEV-SUMMARY.md，无法证明 pre-existing 的 fail 一律视为本次引入（AC-5 修复句）。DEV-SUMMARY.md 汇总：调查执行摘要（四环节实测路径）+ 修复实施记录（T07 产物）+ 基线比对结果 + 不可复现平台标注。确保 .flow-active 状态经 /flow 子命令维护（禁动清单）。
  </verify>
    [ "$(npx bats test/ 2>&1 | grep -c '^not ok')" = "0" ]
  </verify>
  <done>npx bats 基线回归 0 fail 且 DEV-SUMMARY.md 完整，对应 AC-5</done>
  <depends_on>T07, T06</depends_on>
</task>
```

---

## 状态字段说明

- `status="pending"` — 未开始
- `status="in_progress"` — 进行中（同时只允许一个非 [P] 任务为此状态）
- `status="done"` — 已完成（verify 通过）
- `status="blocked"` — 阻塞（必须在文件末尾「阻塞日志」记录）

---

## model-tier 字段说明（ADR-016）

- `model-tier="cheap"` — 1-2 文件 / 简单修改 / 类型 fix → flash-tier
- `model-tier="standard"` — 多文件 / 标准功能 → pro-tier
- `model-tier="top"` — 架构 / review / 复杂逻辑 → top-tier
- 缺省 → fallback `standard`

---

## 阻塞日志

| 任务 | 阻塞原因 | 待人工决策项 | 时间 |
|---|---|---|---|
|  |  |  |  |

---

## Fix 任务（来自 REVIEW / INTEGRATION）

> 此区域由 review/integration 阶段自动追加，编号 `T-FIX-XX`。

```xml
<!-- 占位 -->
```
