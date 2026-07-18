# ADR-011: 26-workflow.sh G1 pipeline 模式不 auto-advance（禁动破例）

## Context
`26-workflow.sh` G1（line 74-95）用 `fk_auto_phase` 检测推进 → 写 `.phase=N+1`（line 90）。fk_auto_phase 有 gate_active 保护（flow-kit-artifacts.sh:111），但 **pipeline goal + review 未开阶段**仍 advance → 绕 toll-gate，制造 phase/current_phase 不一致（本 change 每轮 Stop 复现，AC-K）。`fk_auto_phase` 是 CONTEXT 禁动清单条目（gate 检查段，修改需理解三道防线）。

## Decision
26-workflow.sh G1 检测 `goal.scope=pipeline` 时，**不调 fk_auto_phase 写 .phase**（推进权归 toll-gate 人工 / 31-auto-advance.sh 完整 transition）。单阶段 goal（scope=phase 或无）保留原 auto-advance。

**否决备选 (ii) G1 保留 auto-advance + 同步四字段**（AC-K 允许）：违反 **transition 单一写入点原则**——26-workflow.sh 与 31-auto-advance.sh 两处都写 transition，易失同步（正是本 change 修的 bug 同型，回应 L2-R-D5-ACK）。（iii）删 fk_auto_phase：影响单阶段 goal，过激。

## Consequences
- ✅ pipeline goal 推进归 toll-gate（单一写入点 = 31-auto-advance）
- ✅ 消除 phase/current_phase 不一致（AC-K）
- ⚠️ 单阶段/双模式分支（集成测试覆盖两路径，R4）
- ⚠️ 触 fk_auto_phase 禁动（本 ADR 破例记录 · ARCHITECTURE §2.2）
- 注：fk_auto_phase 函数本身不改（保留单阶段 goal 用途），仅 26-workflow.sh G1 调用方加 scope 守卫
