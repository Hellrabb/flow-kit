# ADR-G2: gate 阶段判定从硬编码正则改为动态读 gate_config

- **Status**: Proposed（gate-integrity change · 2-design）
- **Date**: 2026-07-01
- **关联 AC**: AC-3（3/5/7 gate 接入）

## Context

三处硬编码 `^(1|2|6)$` 阶段判定：
- `independent-review-gate.sh:39`（PreToolUse 门禁）
- `29-independent-review.sh:33`（L3 Stop hook）
- `flow-kit-artifacts.sh:109`（`fk_independent_review_gate_active`）

要接入 3/5/7 需改三处正则为 `^(1|2|3|5|6|7)$`。但硬编码正则与 AC-4「3/5/7 默认 off」冲突——正则无视 `gate_config`，开了正则就全触发，无法按用户显式开启控制。

## Decision

1. **case 映射全 6 阶段**（1/2/3/5/6/7 → phase_name），0/4 等无独立 review 阶段 case 排除。**映射来源（多源镜像 · 见 DESIGN D6）**：case phase→phase_name 镜像在 `independent-review-gate.sh:58-60` + `flow-kit-artifacts.sh:117-119` 两处，阶段正则 `^(1|2|6)$` 镜像 3 处（`gate.sh:39` / `29号:33` / `artifacts.sh:109`）。本 change 同步扩全 6 阶段于全 5 站点，bats 断言覆盖；加阶段 = 5 站点 + bats 同步
2. **动态读 `.flow-active.goal.gate_config["<phase_name>"]`**：值为 `independent` / `true` 才进入命令匹配，否则 `exit 0` 放行
3. **每次 jq 读，不缓存**（PreToolUse 每次新进程，缓存无载体；.flow-active <2KB，jq <5ms）

## Consequences

- **正**：加新阶段只改 `gate_config` 不改正则；与 AC-4 默认 off 自洽（gate_config 不含 3-task → 放行）。**两类源区分（L2-R2 R4）**：gate_config 是**阶段开关**的单一源；phase→phase_name **映射**是多源镜像（5 站点 · 见 D6），靠 bats + check-gate-sync 兜底——两者不可混称"单一源"
- **负**：O(5ms)/次 jq 开销（可接受）；运行期灵活性换编译期确定性（阶段判定从"看正则"变"看运行时配置"）
- **后续**：0/4 等阶段若将来要加独立 review，只需扩 case + 不改正则
