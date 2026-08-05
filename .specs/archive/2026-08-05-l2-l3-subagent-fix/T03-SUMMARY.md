# T03-SUMMARY — opencode 环节③实测：prompt 派发段（task 路由）

- **任务**: T03 · status: done · 2026-08-05
- **verify**: `test -s EVIDENCE-3-opencode-prompt-dispatch.md` → PASS (64 lines)
- **self-review (6 维快查)**:
  - 可读性: 四段结构（步骤/观测/现象/结论）✓
  - 证据链: 每结论附路径+行号（qa-expert.md:4 / l2-detect.sh L61-116 / 双平台 agents grep 输出）✓
  - 范围: 仅写 EVIDENCE-3，未触任何代码/禁动清单 ✓
  - 脱敏: 无凭证涉及 ✓
  - 真实性: 实测——qa-expert 派发 30min 超时（真实失败）、category 派发 4s（对照）✓
  - diff 边界: 单一新文件 ✓
- **关键发现**:
  1. **根因 #2（实证，可复现）**: `task(subagent_type="qa-expert")` → model: sonnet 不可解析（无 anthropic provider）→ 30min 超时无产出；`task(category=quick)` → 4s 正常。qa-expert 是 L2 盲审阶段 1/5 的映射目标 → 拉起失败直接证据
  2. **双平台 agent 定义分歧**: opencode 侧大量 model: sonnet/haiku 硬编码，claude code 侧全部 inherit；qa-expert 双平台已分歧
  3. l2_dispatch_prompt 模板是 claude code Agent 语法，opencode 下需翻译为 task() 语义
  4. gate_config 检测链路 6 prompts 一致，无平台差异
- **deferred**: 无
- **fix_rounds**: 0
