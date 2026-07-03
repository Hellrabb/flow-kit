# ADR-002 · L3 独立审查调用策略

- **日期**: 2026-07-03
- **Change**: pipeline-fallback-fix
- **状态**: proposed
- **影响范围**: 所有开启独立审查 gate 的 pipeline 阶段

---

## Context

### 问题

当前 flow-kit 的独立审查 gate 需要 L2（子 agent 盲审）+ L3（外部模型审查）两层均完成后才能写 `.done` 并推进 pipeline transition。

**L3 调用当前位于 Stop hook `29-independent-review.sh`**，即仅在会话结束时触发。这造成 **L2+L3 异步死锁**（DIAGNOSIS.md F1）：

1. Pipeline transition N→N+1 需要 `.independent-review-N.done`（L2+L3 均完成）
2. L3 仅在会话结束时触发（Stop hook `29-independent-review.sh`）
3. 单 session 内：L2 完成 → transition 被 hook 拦截 → 等待 L3 → L3 需要会话结束 → **无法完成** → pipeline 卡死

### 约束

- 不影响 L2/L3 的独立性（仍为独立子 agent + 独立外部模型）
- 不削弱 gate 的安全强度（不能降级为"建议"或"警告"）
- 不引入新外部依赖（沿用已有 `$ANTHROPIC_BASE_URL` + `$ANTHROPIC_AUTH_TOKEN` 鉴权）
- 保持与 Stop hook 兜底的兼容性

### 备选方案

| 方案 | 核心思路 | 优点 | 缺点 |
|---|---|---|---|
| **A. L3 前置到 PreToolUse（选定）** | L3 API 调用从 Stop hook 搬到 PreToolUse hook transition 拦截点同步执行；Stop hook 保留作兜底 | gate 逻辑不变；L2+L3 单 session 内闭环；改动最小（抽取 lib） | PreToolUse hook 增加 5-15s API 延迟 |
| B. L3 后置到下一阶段入口 | Transition 仅要求 L2 完成；L3 推迟到 N+1 SessionStart 检查并补跑 | 彻底解耦；pipeline 不阻塞 | L3 发现问题时已进入下一阶段需回退 |
| C. L2 即 gate, L3 改审计 | Transition 仅要求 L2；L3 为纯事后审计，累积拦截 | pipeline 流畅 | 与当前 AC 设计差异最大；L3 反馈延迟可能跨多个阶段 |

---

## Decision

**选择方案 A：L3 前置到 PreToolUse hook**

### 核心设计

1. **主路径（PreToolUse hook）**: `independent-review-gate.sh` 在拦截 transition jq 时，检测到 L2 已完成但 L3 未完成 → source 共享 lib `l3-review.sh` → 同步调用 L3 API → L3 结果写入 `INDEPENDENT-REVIEW-<N>.md` 的 L3 段 + 握手文件 → 放行 transition
2. **兜底路径（Stop hook）**: `29-independent-review.sh` 保留 L3 调用逻辑（改为 source 同一 lib），处理"session 在 transition 前异常终止"的补跑场景
3. **超时降级**: L3 API 调用超过 30s → 写入 `L3_verdict=timeout` → 放行 transition（不阻塞 pipeline）
4. **代码去重**: L3 API 调用逻辑抽取为共享 lib `l3-review.sh`，两处调用同一函数 `l3_review_run()`

### 调用链变化

```
[旧] L2完成 → transition被拦 → 等session结束 → Stop hook 29 → L3
     → 下个session写.done → transition

[新] L2完成 → transition被拦 → PreToolUse hook → l3-review.sh
     → L3完成 → 放行transition
          └─超时(30s)→L3_verdict=timeout→降级放行
     Stop hook 29 → 检测L3缺失→补跑（兜底，仅session异常终止时触发）
```

---

## Consequences

### 正面

- **死锁解除**：单 session 内可完成 L2+L3 闭环并推进 transition（DIAGNOSIS F1 修复）
- **代码去重**：l3-review.sh 消除 `29-independent-review.sh` 与 `independent-review-gate.sh` 之间的 L3 API 调用重复
- **降级鲁棒**：L3 API 不可用时 pipeline 不阻塞（超时降级为 timeout）
- **兜底保留**：Stop hook 仍可在异常终止时补跑 L3

### 负面

- **Transition 延迟增加**：PreToolUse hook 同步调 L3 API 需 5-15s（原 <100ms）
- **超时降级的滥用风险**：若 API 长期不可用，L3 将大面积降级为 timeout，形同虚设（缓解：timeout 明确标注，后续 session 可手动重跑）
- **PreToolUse hook 复杂度增加**：从"检查文件是否存在"升级为"检查 + 调用外部 API + 超时处理"

### 后续需关注

- L3 API 调用频率监控：若 pipeline 推进频繁，L3 调用次数将显著增加（每阶段 transition 一次）
- 可考虑 v2 加 `--skip-l3` flag 允许用户显式跳过 L3（如快速 hotfix 场景）
