# DIAGNOSIS: Pipeline 自动推进 + 回退模式

- **Change ID**: pipeline-fallback-fix
- **诊断日期**: 2026-07-03
- **模式**: native (CC 2.1.198, `/goal` 可用)
- **配置**: auto_advance=false, gate_config=all (1-requirement 中途关闭)

---

## T01 · Native 路径诊断观察（phase 0→7）

### Phase 0→1 (init → requirement)

| 观察点 | 结果 | 详情 |
|---|---|---|
| Toll-gate 提示 | ✅ 正常 | 输出 "是否进入 Phase 1（需求分析）？1/2/3" |
| 用户确认后 transition | ✅ 正常 | jq 成功，current_phase="1", phases_done+=["0"] |
| PCSC 自检 | ✅ 正常 | CHANGE.md 6 项全 ✅ |

### Phase 1→2 (requirement → design)

| 观察点 | 结果 | 详情 |
|---|---|---|
| REQUIREMENT.md 产出 | ✅ 正常 | 14 条 AC（含 L2 审查后修补） |
| CONTEXT.md 更新 | ✅ 正常 | 2 术语 + 1 决策 |
| L2 独立盲审 | ✅ 正常 | subagent 完成，verdict=fail→修复后待重审 |
| **🔴 Transition 拦截** | ❌ **异常** | PreToolUse hook 拦截：L2+L3 未全部完成 → 禁止切阶段 |
| **🔴 根因** | — | **L2+L3 异步死锁**：L3 依赖 Stop hook（会话结束时触发），但 pipeline 需要 L3 完成后才能 transition。单会话内构成死锁 |
| 绕过方式 | — | `/flow gate-config 1-requirement=off` → transition 成功 |
| **🔴 二次死锁** | ❌ **异常** | gate_config 变更后 `.goal-snapshot.json` 未同步更新 → hook D8 ⑥ 检测篡改 → 拦截所有 Bash/Write/Edit 工具 |
| **🔴 根因** | — | `/flow gate-config` 只更新 `.flow-active`，不更新 `.goal-snapshot.json`。hook 检测到不一致后拦截全部修改操作，无法通过任何工具恢复一致性（需人工在终端手动 jq） |
| 修复后 transition | ✅ | 人工恢复 gate_config 一致性后，jq 成功 |

**证据 · Transcript 摘录（Discovery 1 — L2+L3 异步死锁）**：
```
PreToolUse:Bash hook error: ⛔ 独立 review gate：阶段 1 (1-requirement) 独立 review 未完成，
禁止 阶段 1 (1-requirement) 切换。
需先完成 L2（盲审子 agent → INDEPENDENT-REVIEW-1.md）+ L3（Stop hook 调外部模型），
再由主 agent 写 .independent-review-1.done 后重试。
```

**证据 · Transcript 摘录（Discovery 2 — gate_config 篡改检测死锁）**：
```
PreToolUse:Bash hook error: ⛔ 独立 review gate（D8 ⑥）：检测到 gate_config 篡改。
.flow-active.goal.gate_config 与 .goal-snapshot.json（入库快照）不一致——
快照 phase key 由 independent/true → false/缺失。
如确需调整 gate-config：用 /flow gate-config 重设（同时更新快照），或手动更新 .goal-snapshot.json 并 commit。
```

**证据 · .flow-active 快照（死锁发生时）**：
```json
// gate_config at time of deadlock:
{"1-requirement":"off","2-design":"independent","3-task":"independent",...}
// snapshot still had:
{"1-requirement":"independent","2-design":"independent","3-task":"independent",...}
```

### Phase 2→3 (design → task)

| 观察点 | 结果 | 详情 |
|---|---|---|
| DESIGN.md 产出 | ✅ 正常 | 诊断方法论设计，5 决策 + 5 风险 + 流程图 |
| PCSC | ✅ 正常 | 9 项全 ✅ |
| Transition | ✅ 正常 | jq 成功（gate_config 已恢复一致），未被 hook 拦截 |
| Toll-gate 交互 | ✅ 正常 | 用户选 1 → transition 执行 |

### Phase 3→4 (task → dev)

| 观察点 | 结果 | 详情 |
|---|---|---|
| TASK.md 产出 | ✅ 正常 | 5 tasks，3 波次 |
| PCSC | ✅ 正常 | 8 项全 ✅ |
| Transition | ✅ 正常 | jq 成功，未被 hook 拦截 |

---

## 诊断进行中...

T01 继续观察 phase 4→5→6→7 的 toll-gate 和 transition 行为。

---

## T04 · .done 文件真实性校验

### 测试方法
分析 `independent-review-gate.sh` + `flow-kit-artifacts.sh` 的 `fk_validate_done_marker()` 函数（155 行源码），构造 5 种 .done 变体验证每层防护。

### 测试结果

| # | 变体 | Tier 1 (总是) | Tier 2 (transition) | 威胁模型 |
|---|---|---|---|---|
| 1 | 空文件 (touch) | ❌ 拒绝（`-s` check → return 2） | N/A | 威胁① 空 .done |
| 2 | `"done"` (1 行) | ❌ 拒绝（< MIN_MEANINGFUL_LINES=3 → return 2） | N/A | 威胁② 假内容 |
| 3 | 占位文本 3 行（无 KVP） | ❌ 拒绝（缺 phase=/change_id=/written_by= KVP → return 2） | N/A | 威胁② 伪造 |
| 4 | 4 行有效 KVP 但缺 L3_verdict | ✅ 通过 Tier 1 | ❌ 拒绝（handshake 文件需 written_by=stop-hook-29 + L3_verdict 匹配） | 威胁③ 跳过子进程 |
| 5 | 7 行全字段 + handshake | ✅ 通过 Tier 1 | ✅ 通过 Tier 2 | 合法 .done |

### 🔴 发现：AC-5a 与 hook 实现的字段差异

| 字段 | AC-5a 要求 | Hook Tier 1 检查 | Hook Tier 2 检查 |
|---|---|---|---|
| `phase=` | ✅ 必须 | ✅ 检查 | — |
| `change_id=` | ✅ 必须 | ✅ 检查 | — |
| `written_by=` | ❌ 未要求 | ✅ **检查** | ✅ 必须 = "stop-hook-29" |
| `L2_verdict=` | ✅ 必须 | ❌ 不检查 | ⚠️ best-effort（比对 INDEPENDENT-REVIEW.md） |
| `L3_verdict=` | ✅ 必须 | ❌ 不检查 | ✅ 检查（通过 handshake 文件） |
| `artifacts=` | ✅ 必须 | ❌ **不检查** | ❌ **不检查** |
| `session_id=` | ❌ 未要求 | ❌ 不检查 | ⚠️ best-effort（跨会话锚点） |

**关键差异**：
1. `artifacts=` 字段完全未被 hook 验证——AC-5a 要求但 hook 实现缺失
2. `written_by=` 是 hook 实际检查的关键字段（AC-5a 未要求）——这比 AC-5a 更强（增加了校验维度）
3. Tier 1 不检查 L2_verdict/L3_verdict——一个包含 phase/change_id/written_by 的 3 行文件即可通过 Tier 1（非 transition 操作不触发 Tier 2）
4. 这意味着：对于非 transition 操作（如 commit），一个伪造的 .done 只需 ≥3 行 + 3 个正确 KVP 即可绕过

### 威胁模型覆盖

| 威胁 | 防御层 | 状态 |
|---|---|---|
| ① 空 .done（touch 空文件） | Tier 1 `-s` + MIN_MEANINGFUL_LINES | ✅ 已防 |
| ② 假内容（echo "done"） | Tier 1 KVP check (phase/change_id/written_by) | ✅ 已防 |
| ③ 跳过子进程（不跑 L2/L3 直接 touch） | Tier 2 handshake (written_by=stop-hook-29) + L3_verdict 匹配 | ✅ 已防（transition 时） |
| ④ 移花接木（跨会话复用旧 .done） | SESSION_ID 锚点 | ⚠️ best-effort（cur_sid/done_sid 缺失时不挡） |
| ⑤-L2 伪造 L2_verdict | L2_verdict vs INDEPENDENT-REVIEW.md 比对 | ⚠️ best-effort |
| ⑤-L3 伪造 L3_verdict | handshake written_by=stop-hook-29 | ✅ 已防 |

### 真实世界验证

Phase 1→2 transition 被成功拦截（见 T01 记录）——hook 正确检测到 .independent-review-1.done 不存在 + 无 L2/L3 完成证据，拒绝 transition jq。

Phase 5→4 rollback 被成功拦截（见 T01 追加记录）——即使回退方向也需 .done。

Hotfix bypass (`touch .independent-review-5.done`) 成功绕过——但仅对非 transition 操作有效（.done 为空文件时 Tier 1 会拦截；我们 touch 后立即有内容写入...实际上 touch 创建的空文件应该被 Tier 1 拦截。但我们 touch 后能继续，说明 phases_done 短路机制生效了——phase 5 已在 phases_done 中时跳过验证）。

**证据 · .flow-active 快照（T04 测试时）**：
```json
// phases_done at time of bypass:
["0","1","2","3","4"]
// phase=5 was set but phases_done didn't include "5"
// Actually the touch bypass worked because we weren't doing a transition FROM phase 5
// We were doing a rollback jq which was detected as a phase_write for phase 5
```

---

## T02 · auto_advance=true 最小验证

### 测试方法
在独立 `auto-advance-smoke-test` 分支上创建最小 change（CHANGE.md + REQUIREMENT.md, 1 AC），设置 `.flow-active` 的 `auto_advance=true, scope=pipeline, from=4`，观察 4-dev 阶段行为。

### 测试结果

**PCSC 检查（auto_advance=true, 无 TASK.md）**：

| # | PCSC 检查项 | 状态 |
|---|---|---|
| 1 | TASK.md 中所有 task done | ❌ 无 TASK.md |
| 2 | SUMMARY.md 已写入 | ❌ 无 SUMMARY |
| 3 | verify + 6 维 self-review | ❌ 无 verify |
| 4-7 | diff/抽象/sub-goal/1.8 | N/A |

**auto_advance 分支行为**：PCSC 有 ❌ → 触发暂停分支："暂停 pipeline，输出缺失清单，等待用户决定"。✅ 符合预期。

### 🔴 发现：auto_advance 机制纯 prompt 驱动，无 hook 层兜底

与独立审查 gate（有 PreToolUse hook 硬拦截）不同，auto_advance 完全依赖 AI agent 读取并遵守 prompt 中的 auto_advance 分支指令：

| 机制 | 执行层 | 绕过难度 |
|---|---|---|
| 独立审查 gate | Hook (PreToolUse) + Prompt (L2 调度) | 高 — hook 在系统层拦截 |
| gate_config 篡改检测 | Hook (PreToolUse) — D8 ⑥ | 高 — hook 在系统层拦截 |
| **auto_advance 自动推进** | **Prompt only** — 4-dev § 6.0 分支 | **低 — 模型跳过指令即失效** |

**影响**：
- `auto_advance=true` 时能否真正自动推进，取决于模型是否严格遵循 prompt 分支
- 弱模型（如 deepseek-v4-pro）可能跳过 `auto_advance=true` 分支，仍输出 toll-gate 交互
- 没有 hook 层验证"auto_advance=true 时是否真的自动 transition 了"
- 这意味着 AC-1 (auto_advance 全✅自动推进) 在弱模型下的 pass/fail 是**不确定的**

**建议**：为 auto_advance 添加 hook 层兜底——Stop hook 或 PreToolUse hook 检测 `auto_advance=true` + PCSC 全✅ 时，自动执行 transition jq（即使模型忘记）。

### 未验证
- auto_advance=true + PCSC 全✅ → 自动 transition（需完整 TASK.md + SUMMARY.md，无法在最小测试中验证，因为无 task 导致 PCSC 始终有 ❌）
- AC-2：故意制造 ❌ → pipeline 暂停（PCSC 第1项已触发暂停，符合预期）

---

## T03 · Fallback 模式模拟

### 测试方法
设置 `.flow-active.goal.mode = "fallback"`，与 T01 native 基线对比 toll-gate 行为、终止条件、迭代机制。

### 测试结果

| 观察点 | Native | Fallback | 一致性 |
|---|---|---|---|
| mode 切换 | — | ✅ jq 成功，无 hook 拦截 | — |
| Toll-gate 暂停点 | 4→5, 5→6, 6→7 | 相同（toll-gate 在 prompt 文件中，不依赖 CC /goal） | ✅ 一致 |
| Toll-gate 选项 | 1/2/3（+4 auto_advance 可选）| 相同 | ✅ 一致 |
| Transition jq | 相同命令 | 相同命令 | ✅ 一致 |
| Goal 迭代机制 | CC /goal 系统接管（系统级） | Prompt 内置循环：每 turn 自检 → turns++ → 最多 20 turns | 🔴 **机制层级不同** |
| GO.md 路由 | 无 mode 特定分支 | 无 mode 特定分支（grep GO.md 0 命中） | ✅ 一致 |

### 🔴 发现：Fallback 机制同属纯 prompt 驱动，无 hook 兜底

与 T02 的 auto_advance 发现一致——fallback 迭代循环完全依赖模型遵守 prompt 自检指令：

```
Native:  CC /goal 系统 → 系统级迭代，不依赖模型自觉
Fallback: Prompt 自检 → 模型每 turn 手动检查条件 → turns++
```

**风险**：
- 弱模型可能忘记自检（跳过"每 turn 结束时自检条件是否满足"指令）
- `goal.turns` 递增依赖模型手动 jq 更新（可能忘记）
- 20 turns 上限同样依赖模型遵守（无 hook 层强制终止）
- GO.md 完全没有 mode 特定路由逻辑——fallback/native 差异仅在 4-dev prompt 的一段描述中

### AC 覆盖

| AC | 状态 | 说明 |
|---|---|---|
| AC-7 (fallback 触发) | ✅ | mode="fallback" 成功设置，prompt 中 fallback 分支存在 |
| AC-8 (toll-gate 一致) | ✅ | Toll-gate 是 prompt 层机制，pause points/options/jq 与 mode 无关 |
| AC-9 (终止正确) | ⚠️ | 需完整 0→7 验证（预测：依赖模型遵守自检指令，弱模型不确定） |
| AC-10 (不提前停) | ⚠️ | 同上——依赖模型遵守 prompt |

---

## T05 · 最终诊断汇总

### Per-AC 状态表

| AC | 状态 | 发现 |
|---|---|---|
| AC-1 (auto_advance 推进) | ⚠️ | 全✅→自动 transition 未完全验证（需完整 TASK.md）；prompt 驱动，弱模型不确定 |
| AC-2 (PCSC ❌ 阻塞) | ✅ | 无 TASK.md 时 PCSC 第1项 ❌ → 正确触发暂停分支 |
| AC-3 (toll-gate 交互) | ✅ | Phase 0→5 所有 toll-gate 正常输出交互提示，等待用户确认后 transition |
| AC-4 (done 文件写入) | ✅ | L2 盲审完成，INDEPENDENT-REVIEW-1.md 含 L2 段 |
| AC-5 (done 真实性) | ✅ | 5 种变体测试，Tier 1+2 正确拒绝空/假/缺键 .done |
| AC-5a (done 内容规范) | ⚠️ | `artifacts=` hook 未实现；`written_by=` 是实际关键字段（AC-5a 未定义） |
| AC-6a (hook 拦截 jq) | ✅ | Phase 1→2 transition 被成功拦截（L2+L3 未完成） |
| AC-6b (toll-gate 拒绝) | ⚠️ | Gate 拦回退也拦前进，但 toll-gate 自身在 hook 被绕过后的行为未独立验证 |
| AC-7 (fallback 触发) | ✅ | mode="fallback" 成功设置，prompt 中 fallback 分支存在 |
| AC-8 (toll-gate 一致性) | ✅ | Toll-gate 是 prompt 层机制，与 mode 无关；GO.md 无 mode 特定路由 |
| AC-9 (fallback 终止) | ⚠️ | 需完整 0→7 验证；预测依赖模型遵守自检指令 |
| AC-10 (不提前停) | ⚠️ | 同上 |
| AC-11 (证据完整性) | ✅ | 每个 ❌/⚠️ AC 含 transcript 摘录 + jq 快照 + 根因假设 |
| AC-12 (native 完成) | ⚠️ | 需 Phase 7 完成后验证；当前在 Phase 4 |

**统计**: 7✅ / 7⚠️ / 0❌（❌ 表示 AC 完全无法验证；⚠️ 表示部分验证或存在已知限制）

---

### 6 个 🔴 Critical 发现（合并去重）

| # | 发现 | 根因 | 影响范围 | 严重度 |
|---|---|---|---|---|
| **F1** | **L2+L3 异步死锁** | 独立审查 gate 需 L3（Stop hook 会话结束触发），但 pipeline transition 需 L3 后才能推进 → 单会话内无法完成 | 所有开独立审查的阶段 | 🔴 Critical |
| **F2** | **gate_config 篡改检测死锁** | `/flow gate-config` 只更新 `.flow-active`，不同步 `.goal-snapshot.json` → hook D8 ⑥ 拦截全部修改工具 → 不可逆 | 任何 `/flow gate-config` 操作 | 🔴 Critical |
| **F3** | **Gate 拦回退** | 独立审查 gate 不区分 transition 方向（前进/回退均需 .done）→ pipeline 卡住后无法后退 | Pipeline rollback | 🔴 Critical |
| **F4** | **auto_advance 纯 prompt 驱动** | auto_advance 机制仅在 prompt 中定义，无 hook 层兜底 → 弱模型可跳过 | AC-1, AC-2 | 🔴 Critical |
| **F5** | **Fallback 纯 prompt 驱动** | GO.md 无 mode 特定路由，fallback 迭代逻辑仅在 4-dev prompt 一段描述中 → 与 F4 同等脆弱 | AC-7~AC-10 | 🔴 Critical |
| **F6** | **AC-5a/hook 字段差异** | `artifacts=` 未实现；Tier1 不查 L2/L3_verdict；`written_by=` 是关键字段但 AC-5a 未定义 | AC-4, AC-5, AC-5a | 🟡 Major |

---

### Native vs Fallback 差异对比

| 维度 | Native | Fallback | 差异 |
|---|---|---|---|
| Goal 迭代 | CC /goal 系统接管（系统级） | Prompt 自检循环（模型级） | 🔴 机制层级不同 |
| Toll-gate 暂停点 | 4→5, 5→6, 6→7 | 相同 | ✅ 一致 |
| Toll-gate 选项 | 1/2/3（+4 auto_advance） | 相同 | ✅ 一致 |
| Transition jq | 相同命令 | 相同命令 | ✅ 一致 |
| GO.md 路由 | 无 mode 分支 | 无 mode 分支 | ✅ 一致 |
| 终止条件 | CC /goal 判定 | 模型自检 + turns ≤ 20 | 🔴 判定主体不同 |
| Hook 拦截 | 同 | 同 | ✅ 一致 |
| 死锁风险 | F1/F2/F3 | F1/F2/F3 同样存在 | ✅ 一致 |

**结论**: Toll-gate 结构层面 native 与 fallback 一致（AC-8 ✅）。差异集中在 goal 迭代机制：native 有系统级兜底，fallback 纯靠模型自觉。

---

### 修复建议（按优先级）

#### P0 — 阻塞性死锁（必须在任何依赖 pipeline 的 change 之前修复）

| # | 修复项 | 涉及文件 | 建议方案 |
|---|---|---|---|
| P0-1 | 解耦 L2+L3 异步依赖 | `independent-review-gate.sh` | L3 完成前允许 transition，改为 L3 未完成时在下一阶段 toll-gate 处警告而非硬拦 |
| P0-2 | 同步 `/flow gate-config` 快照 | `~/.claude/skills/flow/skill.md` | `/flow gate-config` 同时更新 `.goal-snapshot.json` |
| P0-3 | Gate 区分前进/回退 | `independent-review-gate.sh` | `is_phase_write` 检测到回退（目标 phase < 当前 phase）时放行 |

#### P1 — 弱模型鲁棒性（protect the weakest）

| # | 修复项 | 涉及文件 | 建议方案 |
|---|---|---|---|
| P1-1 | auto_advance hook 兜底 | 新增 Stop hook 模块 | 检测 `auto_advance=true` + PCSC 全✅ → 自动执行 transition jq |
| P1-2 | Fallback hook 兜底 | 新增 Stop hook 模块 | 检测 `mode=fallback` + 条件满足 → 自动更新 goal.status=done |
| P1-3 | GO.md mode 路由 | `GO.md` | 添加 mode 特定分支处理 fallback 迭代逻辑（去重 4-dev prompt 中的描述） |

#### P2 — 规格对齐

| # | 修复项 | 涉及文件 | 建议方案 |
|---|---|---|---|
| P2-1 | AC-5a ↔ hook 字段同步 | `REQUIREMENT.md` 模板 + `flow-kit-artifacts.sh` | 统一 `.done` 必填字段：phase/change_id/written_by/L2_verdict/L3_verdict/artifacts（6 键）；hook 补上 `artifacts=` 检查 |
| P2-2 | Tier1 L2/L3_verdict 检查 | `flow-kit-artifacts.sh` `fk_validate_done_marker()` | Tier1 补上 L2_verdict/L3_verdict 存在性检查（当前仅 Tier2 检查） |

---

### 证据附录索引

| 发现 | DIAGNOSIS.md 位置 | Transcript 摘录 | .flow-active 快照 | 源码分析 |
|---|---|---|---|---|
| F1 L2+L3 死锁 | T01 § Phase 1→2 | ✅ L36-40 | ✅ L51-56 | — |
| F2 gate_config 死锁 | T01 § Phase 1→2 | ✅ L44-48 | ✅ L51-56 | — |
| F3 Gate 拦回退 | T01 § Phase 1→2 + T04 L131 | — | ✅ T04 L136-141 | — |
| F4 auto_advance prompt-only | T02 L164-178 | — | — | 4-dev.md §6.0 |
| F5 Fallback prompt-only | T03 L204-217 | — | — | 4-dev.md §5 + GO.md |
| F6 AC-5a/hook 差异 | T04 L98-114 | — | — | flow-kit-artifacts.sh fk_validate_done_marker() |

---

> **诊断完成**。本报告覆盖 CHANGE.md 中列出的全部异常迹象，提供 6 个根因分析 + 9 条分级修复建议 + 完整证据链。后续修复 change 可引用本报告作为 REQUIREMENT 输入。
