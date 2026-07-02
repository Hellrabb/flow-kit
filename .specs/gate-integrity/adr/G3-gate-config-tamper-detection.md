# ADR-G3: ⑥ gate_config 篡改检测（v1 廉价检测 · .specs 快照 diff）

- **Status**: Proposed（gate-integrity change · 2-design · L2-R3 R2 新增）
- **Date**: 2026-07-02
- **关联 AC**: AC-1（威胁⑥ gate_config 篡改 · 新增入 AC-1 威胁清单）

## Context

ADR-G2 把 gate 开关完全绑定到 `.flow-active.goal.gate_config`（单一源）。但 `.flow-active` 是 agent 经 Bash 可写的文件（dogfood 实测），且 `.gitignore:40-41` 排除 `.flow-active*`（不入库）。故主 agent 一行 `jq '.goal.gate_config["2-design"]=false' .flow-active` 即可关闭本 change 全部防线——T1~T4 + D7 握手全失效（都读 gate_config）。

**L2-R3 R2/R6 指出**：早期 R8 称"v1 不防⑥（.flow-active 纳 git 跟踪载体不存在）"是**循环论证**——`.specs/` 并未被 .gitignore 排除，`.specs/<id>/.goal-snapshot.json` 完全可入库做廉价检测。把一个 ~5 行 jq + 1 bats 的检测推到 v1.5 是设计偷懒而非技术约束。

## Decision

**D8 ⑥ gate_config 篡改检测（v1）**：

1. **goal 创建时**（`/flow goal` skill 或 transition hook 首次写 .flow-active）写一份 gate_config 快照到 `.specs/<id>/.goal-snapshot.json`：
   ```json
   {"gate_config": {"1-requirement":"independent","2-design":"independent",...}, "created_at":"<ISO>"}
   ```
   `.specs/` 入 git 跟踪（未被 .gitignore 排除）。
2. **transition hook**（Tier 2 校验段）diff `.flow-active.goal.gate_config` 与 `.specs/<id>/.goal-snapshot.json` 的 gate_config：任何 phase key 由 `independent`/`true` → `false`/缺失 → **deny exit 2** + 可读警告"检测到 gate_config 篡改"。
3. 新增 phase（用户后续开 3/5/7）允许（independent 数量增加不触发 deny）；只 deny "由开到关/删除"。

## Consequences

- **正**：
  - 威胁⑥ v1 有**检测**（非强防）——agent 改 .flow-active gate_config 关 gate → transition 时与入库快照 diff 不符 → deny
  - 廉价：~5 行 jq + 1 bats，无加密、无外部锚点
  - agent 若同时改 `.flow-active` + `.specs/<id>/.goal-snapshot.json`，后者入 git → commit 留可观测证据（review/CI 可查）
- **负**：
  - **仅检测非强防**——agent 同时改两文件且 commit 不留痕（如未提交即 transition，或 .specs 也 gitignored 的极端配置）可绕。完全强防留 v1.5 加密签名（goal 签名）
  - 快照写时机依赖 goal 创建 hook 正确触发；若 goal 创建绕过 hook（直接手写 .flow-active），快照缺失 → transition 时 detect-and-warn（不强制 block，兼容历史 goal）
- **后续**：v1.5 goal 创建签名 + transition 验签，完全强防⑥

## 关联

- DESIGN D8 / R8 / §9.3 `.goal-snapshot.json` 契约
- REQUIREMENT AC-1 威胁⑥ + Then⑤
