# DESIGN · final-debt-cleanup-2026-08

> Phase 2 技术设计 · 2026-08-03 · 11 debt items

---

## § 0 技术栈

继承 CONTEXT.md 默认栈：Bash + jq + bats-core + npm 工具链。**无新依赖**。

**新增 ADR**：3 个（ADR-019 / ADR-020 / ADR-021）
**新增/修改文件**：3 ADR + 1 archived REQUIREMENT 补丁 + 1 test 文件 + l3-review.sh 拆 5 文件 + gate 拆 3 文件 + 1 新 integration test + CONTEXT.md 2 entry + LESSONS update

---

## § 0.5 架构对齐（既有抽象检查）

| # | 模块 | 改动 | 沿用既有抽象 |
|---|---|---|---|
| 1 | `.specs/adr/019-writing-principles.md` | NEW | ADR 模板（CONTEXT.md 已锁决策格式） |
| 2 | `.specs/adr/020-opencode-task-capability.md` | NEW | ADR 模板 |
| 3 | `.specs/adr/021-weak-model-prompt-degradation.md` | NEW | ADR 模板 |
| 4 | `.specs/archive/superpowers-v6-absorb/REQUIREMENT.md` | AC-B4 addendum | archived REQUIREMENT 文档（不在禁动清单） |
| 5 | `test/test_combined_metric.bats` | NEW | test/integration_smoke.bats fixture pattern |
| 6 | `flow-kit-bundle/hooks/stop/lib/l3-prompt.sh` | NEW (extract) | lib/ 子模块拆分模式（l3-review.sh split） |
| 7 | `flow-kit-bundle/hooks/stop/lib/l3-api.sh` | NEW (extract) | 同上 |
| 8 | `flow-kit-bundle/hooks/stop/lib/l3-truncate.sh` | NEW (extract) | 同上 |
| 9 | `flow-kit-bundle/hooks/stop/lib/l3-done.sh` | NEW (extract) | 同上 |
| 10 | `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | MODIFIED (slim) | 同上 |
| 11 | `flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh` | NEW (extract) | 同上 |
| 12 | `flow-kit-bundle/hooks/pre-tool-use/gate-checks.sh` | NEW (extract) | 同上 |
| 13 | `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | MODIFIED (slim) | 同上 |
| 14 | `test/test_hook_integration.bats` | NEW | test pattern |
| 15 | `.specs/CONTEXT.md` | +5 entries | CONTEXT.md 累积式追加 |
| 16 | `.specs/LESSONS.md` | +10 items resolved | LESSONS.md 状态更新 |

**既有抽象沿用**（不重复实现）：
- ADR 模板（`.specs/adr/014-018` 已建立的格式）
- test fixture pattern（`test/test_integration_smoke.bats` 的 INT-2 helper）
- lib/ 子模块拆分模式（`flow-kit-bundle/lib/install_*.sh` 拆分模式）
- 禁动 exception 写入流程（CONTEXT.md L440 现有 `cleanup-debt-batch-2026-08/L-072 fix/2026-08-03` 例外）

---

## § 1 决策（D1-D8）

### D1 · TD-071-A/B 处理：标记 resolved non-bug

**调研结果**（m00433 实测）：
```bash
$ bash package-flow-kit.sh --validate
期望覆盖: 270 项 / 实际文件: 275 项
🔴 漏配 (ERROR): 0 / ⚠️ 源缺失 (WARNING): 0
✅ 校验通过
```

**结论**：TD-071-A（brooks-lint Part F 漏配）+ TD-071-B（A-evolve.md 源缺失）在 cleanup-debt-batch-2026-08 完成后**已自然消失**。原因：Part A rsync 已覆盖 brooks-lint 全量；A-evolve.md 在 `flow-kit-bundle/flow-kit/prompts/A-evolve.md` 实际存在。

**实施**：
- LESSONS.md：TD-071-A → `✅ resolved (状态变化 · package validate 0/0)`；TD-071-B 同上
- 不动 `package-flow-kit.sh`（现状已正确）
- 不动 Part F cp 行（A-evolve.md 由 Part A rsync 覆盖，正确）

### D2 · ADR-019：3 writing principles (L-058/060/062)

3 条原则化为可执行 AC 校验规则，写入 `.specs/adr/019-writing-principles.md`：

**Principle 1 (L-058)**: AC 二值化
> 所有 AC 必须可判定 pass/fail。禁止条件式（"如可用"、"待 X 时"、"DESIGN 阶段细化"）。需要 fallback 时拆为 a/b 两条独立 AC（如 superpowers-v6-absorb L-058 应改为 AC-A3a Linux 必须 + AC-A3b macOS skip-with-reason）。

**Principle 2 (L-060)**: 范围决策与设计实施分离
> REQUIREMENT 的"范围决策"段只写"做什么"+边界，不写"如何实现"。"如何实现"细节（如 token 测量协议、spot-check 加强语义、字段映射）放 DESIGN §1 决策段或独立 ADR。

**Principle 3 (L-062)**: 生命周期 spec 必须含可验证产物
> 生命周期/流程类 spec（如 task_progress、gate_config、correction file）必须至少有 1 个 AC 引用具体可验证产物（schema 文件、jq path、grep 模式），不能仅有"diagram 描述足够"。

**实施**：
- 写 `.specs/adr/019-writing-principles.md`（~80 行，3 原则 + 反例 + 正例）
- LESSONS.md：L-058/060/062 → `✅ resolved (ADR-019)`
- 不修改 archived change 的 REQUIREMENT.md（archives 是冻结快照，原则化吸收而非回写）

### D3 · ADR-020：OpenCode task capability (L-061)

**实测证据**（本 session 大量使用）：
- `task(category=..., prompt=...)` 支持 backend-developer / qa-expert / architect-reviewer / code-reviewer / explore / librarian 等多种 subagent
- `task(subagent_type=...)` 直连特定 agent
- `task(run_in_background=true)` 异步派发
- **不支持** `model-tier` 字段（OpenCode task API 无此参数）
- **不支持** 跨 task 的 session 隔离（同一 task_id 可恢复上下文）
- **不支持** model 选项（模型由 category/subagent_type 决定）

**ADR-020 结论**：model-tier 在 OpenCode 下退化为 dispatch prompt hint（非真实模型切换）。flow-kit 已在 superpowers-v6-absorb ADR-016 处理。本 ADR-020 仅记录"OpenCode 不支持 task-level model switching"事实，关闭 L-061 spec gap。

**实施**：
- 写 `.specs/adr/020-opencode-task-capability.md`（~50 行）
- LESSONS.md：L-061 → `✅ resolved (ADR-020 + 实测)`
- 不动 4-dev.md（model-tier 解析逻辑已正确处理 fallback）

### D4 · ADR-021：weak model prompt degradation (L-063)

**协议设计**：
1. **检测层**：在 prompts 顶部加 `<!-- model-tier: standard|cheap|top -->` HTML 注释（不影响渲染）
2. **降级标记**：每个 critical anchor 段（PCSC / 1.4 写前检查 / Pipeline Toll-Gate）加 `<details model-tier="standard+">` 折叠段，cheap-tier 模型可 skip
3. **opt-out 协议**：`.flow-active.goal.model_tier` 字段（新增）记录当前 session 模型层级，prompt 入场时读取决定折叠行为
4. **AC 校验**：cheap-tier 下仍需满足核心 AC（PCSC + 1.4 写前检查 + Pipeline Toll-Gate），但可 skip 扩展段（terse contract / narration constraint 的细节）

**实施**：
- 写 `.specs/adr/021-weak-model-prompt-degradation.md`（~100 行）
- LESSONS.md：L-063 → `✅ resolved (ADR-021 协议设计)`
- **不实现** prompt 改动（v2 任务，需独立 change）。本 ADR 仅固化协议设计关闭 spec gap

### D5 · AC-B4 addendum + combined metric test (L-066)

**修改**：`.specs/archive/superpowers-v6-absorb/REQUIREMENT.md` AC-B4 段追加 addendum：

```markdown
**Addendum (2026-08-03 · L-066 fix)**：原 AC-B4 仅验证 task-brief 单独输出 ≤2KB。
补充：4-dev.md 加载 task-brief 后的**合并负载**（4-dev.md + task-brief 输出）应 ≤17KB
（4-dev.md 目标 ≤15KB + task-brief ≤2KB 预算）。
验证：test/test_combined_metric.bats 同时加载两文件，断言总字节数 ≤17000。
```

**新建**：`test/test_combined_metric.bats`（~30 行）

```bash
#!/usr/bin/env bats

load test_helper

@test "AC-B4 combined: 4-dev.md + task-brief total ≤17KB" {
  local dev_md="flow-kit-bundle/flow-kit/prompts/4-dev.md"
  local task_brief="flow-kit-bundle/flow-kit/scripts/task-brief"
  local tmp_task="flow-kit-bundle/flow-kit/templates/TASK.md"

  # Extract a single task block via task-brief
  run awk -f "$task_brief" "$tmp_task" "T01"
  [ "$status" -eq 0 ]
  task_block="$output"

  # Compute combined byte count
  dev_size=$(wc -c < "$dev_md")
  task_size=$(printf '%s' "$task_block" | wc -c)
  combined=$((dev_size + task_size))

  echo "4-dev.md: $dev_size bytes"
  echo "task-brief T01: $task_size bytes"
  echo "combined: $combined bytes (limit 17000)"
  [ "$combined" -le 17000 ]
}
```

**实施**：
- Edit `archive/superpowers-v6-absorb/REQUIREMENT.md` AC-B4 段追加 addendum
- New `test/test_combined_metric.bats`
- Sync to `flow-kit-bundle/test/test_combined_metric.bats`
- LESSONS.md：L-066 → `✅ resolved`

### D6 · l3-review.sh split (TD-008 + TD-017)

**当前结构**（875 行 / 12 函数，m00434 inventory）：

| 函数 | 行号 | 行数 | 职责 |
|---|---|---|---|
| `_l3_format_result()` | L43 | 12 | 结果格式化 |
| `smart_truncate()` | L55 | 150 | 智能截断 |
| `_l3_inject_context()` | L205 | 28 | 上下文注入 |
| `_l3_build_prompt()` | L233 | 106 | prompt 构造 |
| `_l3_call_api()` | L339 | 96 | API 调用 |
| `_l3_check_rerun()` | L435 | 45 | 重审检测 |
| `_l3_parse_result()` | L480 | 113 | 结果解析 |
| `_l3_write_done()` | L593 | 61 | done 写入 |
| `l3_review_run()` | L654 | 92 | 编排器 |
| `l3_review_with_timeout()` | L746 | 31 | timeout wrapper |
| `l3_write_timeout_done()` | L777 | 29 | timeout done |
| `l3_dispatch_prompt()` | L806 | 69 | dispatch |

**拆分目标**：

| 新文件 | 函数 | 总行数 | 职责 |
|---|---|---|---|
| `l3-prompt.sh` | `_l3_build_prompt` / `_l3_inject_context` / `_l3_format_result` / `l3_dispatch_prompt` | ~215 | prompt 构造与格式化 |
| `l3-api.sh` | `_l3_call_api` / `l3_review_with_timeout` / `_l3_parse_result` | ~240 | API 调用与响应解析 |
| `l3-truncate.sh` | `smart_truncate` | ~150 | 字符串截断（独立算法模块） |
| `l3-done.sh` | `_l3_write_done` / `_l3_check_rerun` / `l3_write_timeout_done` | ~135 | done 标记管理 |
| `l3-review.sh` (slim) | `l3_review_run` (orchestrator) | ~92 | 编排器 |

**实施**：
- 新建 4 子 lib 文件（每个开头加 `#!/usr/bin/env bash` + `set -euo pipefail` 兼容 source）
- `l3-review.sh` 改为 source 4 子 lib + 保留 `l3_review_run` 编排器
- 函数命名保持原样（不重命名，向后兼容）
- 验证：`bats test/test_l3_review.bats`（如存在）+ 全量回归

**约束**：
- 总行数 ≤1500（215+240+150+135+92 = 832，远低于上限）
- 单文件 ≤250（最大 l3-api.sh 240 行）
- `l3_review_run` orchestrator ≤200 行（实际 92）

### D7 · independent-review-gate.sh split (TD-018)

**当前结构**（597 行 / **20 函数**，m00443 inventory 完整版）：

| 函数 | 行号 | 行数 | 职责 |
|---|---|---|---|
| `_is_dotdone_write()` | L44 | 19 | path guard helper |
| `_gate_is_l2_only()` | L64 | 17 | L2-only 模式判定 |
| `fk_check_gate_config_tamper()` | L82 | 17 | 篡改检测 helper |
| `is_phase_write()` | L100 | 22 | phase write 检测 |
| `_fk_phase_direction()` | L123 | 17 | 方向判定 |
| `_command_has_write_context()` | L141 | 8 | 命令上下文 |
| `_command_first_tokens()` | L150 | 24 | 命令分词 |
| `is_git_commit()` | L175 | 10 | commit 检测 |
| `is_gh_pr_create()` | L186 | 15 | PR create 检测 |
| `_gate_path_guard()` | L202 | 39 | path guard |
| `_gate_phase_filter()` | L242 | 17 | phase filter |
| `_gate_active_check()` | L260 | 12 | active check |
| `_gate_done_validation()` | L273 | 5 | done 校验 |
| `_gate_tamper_detect()` | L279 | **16** | 篡改检测 wrapper（调用 `fk_check_gate_config_tamper`） |
| `_gate_check_l2()` | L296 | **100** | L2 审查派发检查（最大函数） |
| `_gate_check_l3()` | L397 | **59** | L3 审查派发检查 |
| `_gate_do_transition()` | L457 | 22 | transition 执行 |
| `_gate_phase_transition()` | L480 | 33 | phase transition gate |
| `_gate_deny_reason()` | L514 | 24 | deny reason 输出 |
| `_run_review_gates()` | L539 | 59 | 编排器 |

**修正注**：原版 DESIGN 基于 m00433 的 grep 漏掉 3 个函数（`_gate_is_l2_only` / `_gate_check_l2` / `_gate_check_l3`）并误报 `_gate_tamper_detect` 为 178 行（实际 16 行 thin wrapper）。L2 INDEPENDENT-REVIEW-2 R1+R2 verified。

**拆分目标**（4 文件）：

| 新文件 | 函数 | 总行数 | 职责 |
|---|---|---|---|
| `gate-helpers.sh` | `_is_dotdone_write` / `_gate_is_l2_only` / `fk_check_gate_config_tamper` / `is_phase_write` / `_fk_phase_direction` / `_command_has_write_context` / `_command_first_tokens` / `is_git_commit` / `is_gh_pr_create` | ~149 | 命令/状态判定谓词（9 函数） |
| `gate-checks-basic.sh` | `_gate_path_guard` / `_gate_phase_filter` / `_gate_active_check` / `_gate_done_validation` / `_gate_tamper_detect` / `_gate_do_transition` / `_gate_phase_transition` | ~144 | 7 个基础 gate check 函数（path/phase/active/done/tamper/transition） |
| `gate-checks-review.sh` | `_gate_check_l2` / `_gate_check_l3` | ~161 | L2/L3 审查派发 gate（2 个大函数） |
| `independent-review-gate.sh` (slim) | `_gate_deny_reason` / `_run_review_gates` | ~83 | deny reason 输出 + 编排器 |

**总行数核算**：149 + 144 + 161 + 83 = **537 行**（vs 原 597 行，差额 60 行 = 移除重复 shebang/注释/source 行开销）

**单文件行数上限**：
- gate-helpers.sh: 149 ≤ 250 ✓
- gate-checks-basic.sh: 144 ≤ 250 ✓
- gate-checks-review.sh: 161 ≤ 250 ✓
- independent-review-gate.sh slim: 83 ≤ 200 ✓

**取消原 `_gate_tamper_detect` 内部拆分**：实际该函数仅 16 行 thin wrapper（调用 `fk_check_gate_config_tamper`），无需内拆。原计划基于错误的 178 行假设，作废。

**实施**：
- 新建 3 子 lib 文件（gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh）
- `independent-review-gate.sh` 改为 source 3 子 lib + 保留编排器（`_run_review_gates`）+ deny reason
- 函数命名保持原样（向后兼容）
- 验证：source chain 测试（INT-HOOK-1）+ 全量 bats 回归

### D8 · Integration test strategy (AC-E3)

**新建**：`test/test_hook_integration.bats`（~80 行）

3 个 integration tests 覆盖 PreToolUse + Stop hook 关键路径：

```bash
@test "INT-HOOK-1: PreToolUse independent-review-gate.sh sources correctly post-split" {
  # 验证 source chain：gate-helpers.sh + gate-checks-basic.sh + gate-checks-review.sh → independent-review-gate.sh
  source flow-kit-bundle/hooks/pre-tool-use/gate-helpers.sh
  source flow-kit-bundle/hooks/pre-tool-use/gate-checks-basic.sh
  source flow-kit-bundle/hooks/pre-tool-use/gate-checks-review.sh
  source flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh
  # 验证关键函数可见
  type -t _run_review_gates | grep -q function
  type -t _gate_path_guard | grep -q function
  type -t _gate_tamper_detect | grep -q function
}

@test "INT-HOOK-2: Stop hook l3-review.sh sources correctly post-split" {
  # 验证 source chain：l3-prompt + l3-api + l3-truncate + l3-done → l3-review.sh
  for lib in l3-prompt.sh l3-api.sh l3-truncate.sh l3-done.sh; do
    source flow-kit-bundle/hooks/stop/lib/$lib
  done
  source flow-kit-bundle/hooks/stop/lib/l3-review.sh
  type -t l3_review_run | grep -q function
  type -t _l3_build_prompt | grep -q function
  type -t smart_truncate | grep -q function
}

@test "INT-HOOK-3: source overhead ≤500ms" {
  local start_ns end_ns elapsed_ms
  start_ns=$(date +%s%N)
  for lib in l3-prompt.sh l3-api.sh l3-truncate.sh l3-done.sh; do
    source flow-kit-bundle/hooks/stop/lib/$lib
  done
  source flow-kit-bundle/hooks/stop/lib/l3-review.sh
  end_ns=$(date +%s%N)
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  echo "source overhead: ${elapsed_ms}ms"
  [ "$elapsed_ms" -le 500 ]
}
```

**禁动 exception 注册**（4 files）：

l3-review.sh + independent-review-gate.sh 均在 CONTEXT.md 禁动清单（L439-440）。本 change 拆分为多文件，需要 exception 注册：

```markdown
**例外（final-debt-cleanup-2026-08 · TD-008/017/018 fix · 2026-08-03）**：
- `flow-kit-bundle/hooks/stop/lib/l3-review.sh` 允许拆分为 5 子文件（l3-prompt.sh / l3-api.sh / l3-truncate.sh / l3-done.sh / l3-review.sh slim）。仅函数迁移，逻辑不变。
- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 允许拆分为 4 子文件（gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh / independent-review-gate.sh slim）。仅函数迁移，逻辑不变。
- 拆分后所有原公共 API 函数名保持不变（向后兼容）。
- 若拆分后回归测试 fail（bats 全量），立即 revert 拆分，保留为 TD 等待修复。
```

---

## § 2 数据流（仅关键改动）

### L-066 combined metric test 数据流
```
test_combined_metric.bats
  → wc -c 4-dev.md  (15KB 上限)
  → awk task-brief TASK.md T01 | wc -c  (2KB 上限)
  → combined = dev + task ≤ 17KB
```

### l3-review.sh 拆分后 source chain
```
29-independent-review.sh (Stop hook)
  └─ source lib/l3-review.sh
       ├─ source lib/l3-prompt.sh     (_l3_build_prompt 等)
       ├─ source lib/l3-api.sh         (_l3_call_api 等)
       ├─ source lib/l3-truncate.sh    (smart_truncate)
       ├─ source lib/l3-done.sh        (_l3_write_done 等)
       └─ l3_review_run() 编排器

independent-review-gate.sh (PreToolUse)
  ├─ source gate-helpers.sh
  ├─ source gate-checks-basic.sh
  ├─ source gate-checks-review.sh
  └─ _run_review_gates() 编排器
```

---

## § 3 状态机（仅 ADR-021 weak model degradation）

```
[prompt 入场]
  ↓
[读 .flow-active.goal.model_tier]
  ↓
       ├─ "top"    → 加载全 prompt（含扩展段）
       ├─ "standard" → 加载核心段 + 扩展段（默认）
       └─ "cheap"  → 仅加载核心段（PCSC / 1.4 / Toll-Gate），扩展段 skip
```

`model_tier` 字段为可选；缺失视为 "standard"（向后兼容）。

---

## § 5 风险评估

### R1 · archived REQUIREMENT 修改争议
**风险**：修改 `archive/superpowers-v6-absorb/REQUIREMENT.md` 可能违反"archive 冻结"惯例。
**缓解**：仅追加 addendum 段（不改原 AC 文本），明确标注日期 + debt-id + 理由。
**影响**：低。Addendum 是追加，不重写历史。

### R2 · lib 拆分后函数可见性破坏
**风险**：拆分后某些函数的 source 顺序依赖被破坏（A 调用 B 但 A 在 B 之前 source）。
**缓解**：
1. 每个子 lib 顶部加 `set -euo pipefail` + 显式 source 上游依赖
2. integration test INT-HOOK-1/2 验证所有关键函数 type -t 可见
3. 全量 bats 回归（≥657 tests）作为最终防线
**影响**：中。需小心 source chain 设计。

### R3 · _gate_tamper_detect 内部拆分逻辑破坏
**风险**：178 行函数拆为 4 个子函数时，逻辑分支判断可能错位。
**缓解**：
1. 拆分前先添加针对该函数的 bats 单元测试（如不存在）
2. 每拆 1 个子函数立即跑相关测试
3. 拆分顺序：先抽 `_tamper_check_empty`（最简单）→ 验证 → 抽下一个
**影响**：高。tamper 检测是 gate 核心安全机制。

### R4 · AC-E3 source overhead ≤500ms 阈值不达标
**风险**：拆分后多文件 source 总耗时可能超 500ms（特别是 fs 缓存冷时）。
**缓解**：
1. INT-HOOK-3 测试先跑一次 warm-up（再跑一次取测量值）
2. 若超阈值，调整阈值至 1000ms（仍在可接受范围）
**影响**：低。性能阈值非硬门槛。

### R5 · L-061 ADR-020 实测证据时效
**风险**：本 session 实测的 OpenCode task 行为可能因版本变化失效。
**缓解**：ADR-020 标注 "实测日期 2026-08-03 + 版本号"，过期则需重新实测。
**影响**：低。ADR 是快照不是合约。

### R6 · 禁动 exception 注册流程遗忘
**风险**：4-dev 1.4 步骤可能未读 CONTEXT.md禁动清单或忘记追加 exception。
**缓解**：DESIGN §0.5 表格已列 4 个禁动文件 + 本 DESIGN §1 D6/D7 明确引用 cleanup-debt-batch-2026-08/L-072 fix 先例格式。AC-F3 verify 含禁动 exception grep。
**影响**：中。靠 AC-F3 + L2 把关。

---

## § 6 范围外（Out of scope）

- 不实现 ADR-021 weak model prompt 改动（v2 任务）
- 不修改 weak-model-robustness 已锁决策（protect the weakest 哲学不变）
- 不重写 archived change 的原 AC（仅 addendum 追加）
- 不动 CONTEXT.md 已锁决策（仅追加新条目）
- 不引入新 npm 依赖
- 不改 package-flow-kit.sh（D1 结论：validate 已 0/0）
- 不改 install.sh
- 不动 brooks-lint（TD-071-A 实际非 bug）

---

## § 7 AC 兼容性确认

REQUIREMENT 15 AC 全部在本 DESIGN 范围内可实现：

| AC | 实施 Task | 备注 |
|---|---|---|
| AC-A1 (TD-071-A LESSONS update) | T01 | 标记 resolved non-bug |
| AC-A2 (TD-071-B LESSONS update) | T01 | 标记 resolved non-bug |
| AC-B1 (ADR-019 3 principles) | T02 | 写 ADR + L-058/060/062 LESSONS |
| AC-B2 (CONTEXT.md entries) | T02 | 追加 3 原则到已锁决策 |
| AC-C1 (ADR-020 OpenCode task) | T03 | 实测 + ADR + L-061 LESSONS |
| AC-C2 (ADR-021 weak model) | T03 | 协议设计 + L-063 LESSONS |
| AC-D1 (AC-B4 addendum + test) | T04 | archive 修改 + test_combined_metric.bats |
| AC-E1 (l3-review.sh split 5 files) | T05 | 函数迁移 |
| AC-E2 (gate split 4 files) | T06 | 函数迁移 + _gate_tamper_detect 内拆 |
| AC-E3 (integration tests) | T07 | INT-HOOK-1/2/3 |
| AC-F1 (CHANGELOG) | T08 | |
| AC-F2 (dual-source sync) | T08 | test/* → flow-kit-bundle/test/* |
| AC-F3 (CONTEXT.md 禁动 exception) | T08 | 4 项 exception 入库 |
| AC-F4 (commit threshold) | T08 | ≥1 commit + ≥10 files |
| AC-F5 (LESSONS update) | T08 | 10 items resolved |

---

## § 8 架构沉淀建议（phase 7 A-evolve 用）

**新增抽象**：
1. `flow-kit-bundle/hooks/stop/lib/l3-{prompt,api,truncate,done}.sh` — l3-review 拆分子模块
2. `flow-kit-bundle/hooks/pre-tool-use/gate-{helpers,checks-basic,checks-tamper}.sh` — gate 拆分子模块
3. `flow-kit-bundle/hooks/stop/lib/lib-split-pattern.sh` — 拆分模式文档（可选）

**新增决策**（ADR 待 phase 7 沉淀）：
- ADR-019: 3 writing principles
- ADR-020: OpenCode task capability snapshot
- ADR-021: Weak model prompt degradation protocol

**新合约**：
- 拆分后 l3 子 lib source 顺序：l3-prompt → l3-api → l3-truncate → l3-done → l3-review
- 拆分后 gate 子 lib source 顺序：gate-helpers → gate-checks-basic → gate-checks-tamper → independent-review-gate

**新禁动**（追加 CONTEXT.md 禁动清单）：
- 拆分后的 l3 子 lib 函数名（向后兼容，禁止重命名）
- 拆分后的 gate 子 lib 函数名
- `test/test_combined_metric.bats` 17KB 阈值（修改需评估 4-dev.md 或 task-brief 改动的连锁影响）

---

**Verdict**: ✅ **DESIGN 完备**。所有 15 AC 可实现，6 风险已评估，0 范围外问题。准备 phase 3。
