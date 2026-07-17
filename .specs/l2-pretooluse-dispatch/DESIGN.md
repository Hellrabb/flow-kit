# DESIGN: L2 PreToolUse Dispatch — 阶段切换时前置触发 L2 独立审查

- **Change ID**: `l2-pretooluse-dispatch`
- **关联**: `@.specs/l2-pretooluse-dispatch/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> CONTEXT.md 已锁定技术栈，本次直接沿用。

- **选定**：Bash（`#!/bin/bash`，`set -euo pipefail`）
- **关键依赖**：`jq`（JSON 解析）、`curl`（Agent API 调用）、`l2-detect.sh`（L2 检测 lib）、`independent-review-gate.sh`（PreToolUse gate 主脚本）
- **理由**：flow-kit 全站 Bash 项目，hook 系统全部基于 shell 脚本。本次改动在既有 Bash hook 架构内扩展，不引入新语言/运行时
- **明确排除**：不引入 Python/Node.js 做 dispatch（增加依赖栈复杂度，bash+curl 即可完成 Agent API 调用）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep + read 验证实际存在）：
- flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh（404 行 · 主 gate 脚本 · 本次扩展 _gate_check_l2）
- flow-kit-bundle/hooks/stop/lib/l2-detect.sh（89 行 · L2 检测 lib · 本次扩展返回值 + 新增 Agent dispatch 函数）
- flow-kit-bundle/lib/install_hooks.sh（PreToolUse 接线 · 本次可能微调 matcher）

新增模块：
- 无（仅在既有文件中扩展函数，不新增独立 hook 脚本）— 对应 REQUIREMENT.md out：不建新 hook 脚本

禁动清单（与本次无关，AI 不许"顺手"碰）：
- flow-kit-bundle/hooks/pre-tool-use/auto-checkpoint.sh（独立的 PreToolUse hook，不相关）
- flow-kit-bundle/hooks/stop/lib/correction-file.sh（correction 文件管理 · 不改）
- .flow-active.goal 字段 schema（不新增字段）

本次变更授权触碰（原禁动清单项，经评估后开放修改）：
- flow-kit-bundle/hooks/stop/29-independent-review.sh — T08 去 2>/dev/null 错误吞没 + 加 module_output 日志
- flow-kit-bundle/hooks/stop/lib/l3-review.sh — T09 原子写入（tmp+mv）+ 写入后验证 + _l3_write_done 防御
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| L2 完成检测 | `l2-detect.sh::l2_detect_missing()` | **沿用，不扩展**（auto_advance 检测在 `_gate_check_l2` 中独立完成，`l2_detect_missing()` 保持纯净——仅检查 INDEPENDENT-REVIEW 文件，不读 `.flow-active`，不引入 jq 依赖） |
| L2 手动派发命令生成 | `l2-detect.sh::l2_dispatch_prompt()` | 沿用，作 dispatch 失败降级回退 |
| Gate 编排 | `independent-review-gate.sh::_gate_phase_transition()` | 沿用，不改调用链 |
| L2 gate 检查 | `independent-review-gate.sh::_gate_check_l2()` | **扩展**（核心改动点） |
| L3 gate 检查 | `independent-review-gate.sh::_gate_check_l3()` | 沿用，不改 |
| Agent API 调用 | `l3-review.sh::_l3_call_api()`（curl + Anthropic API 模式） | **参考模式**（新建 `l2-detect.sh::l2_dispatch_agent()` 遵循相同 API 调用范式） |
| FLOW_KIT_SKIP_L2 跳过 | `_gate_check_l2` 已有 `FLOW_KIT_SKIP_L2=1` 逻辑 | 沿用，不修改 |
| PreToolUse matcher | `install_hooks.sh:143` matcher=`"Bash\|Write\|Edit"` | 沿用，不需修改（已覆盖 AI 写 phase 的 Bash 工具调用） |

### 0.5.3 沿用模式 vs 引入新模式

```
- Hook 函数命名：**沿用** `_gate_` 前缀（gate 检查步骤）+ `l2_` 前缀（L2 审查函数）
- API 调用：**沿用** curl + Anthropic Messages API 模式（与 l3-review.sh 一致）
- 异步 dispatch：**沿用** `&>/dev/null & disown` 后台进程模式（与 l3-review.sh 的 fire-and-forget 同，`disown` 确保脱离 hook 进程组）
- 错误处理：**沿用** fail-close（exit 2 deny）+ 降级回退（dispatch 失败 → 手动命令）
- 日志：**沿用** `[l2-dispatch]` 前缀 + stderr 输出模式
- 无引入新模式——所有改动在既有 hook 架构和 Bash 模式内完成
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **在 `_gate_check_l2` 中集成 Agent 自动派发**（扩展现有函数，加 auto-dispatch 分支） | 新建独立 `_gate_check_l2_autodispatch` 函数 | 改动最小——`_gate_check_l2` 已有 dispatch prompt 生成逻辑，加 auto-dispatch 只需要在 prompt 生成前插入 API 调用尝试 | 函数从 ~50 行增长到 ~80 行，复杂度增加；已通过清晰的代码分段（检测→派发→降级→拦截）控制认知负荷 |
| D2 | **使用 curl + Anthropic Messages API 派发 L2 Agent**（与 L3 同模式） | Claude CLI（`claude agent` 子命令） | curl+API 在 hook 环境最可靠——不依赖 `claude` CLI 安装、不依赖 Node.js、超时可控（`--max-time`）。L3 已验证此模式稳定 | Agent prompt 需手动构造 Messages API JSON（~30 行 bash heredoc），比 CLI 一行命令繁琐 |
| D3 | **异步 fire-and-forget 派发**（后台进程 `&` + `disown`） | 同步等待 Agent 完成再 exit | PreToolUse hook 有超时限制（~5s），Agent API 调用需 15-60s。同步等待 → hook 超时被 kill → dispatch 丢失 + 工具流被卡 | Agent 执行结果不能在同一轮返回给用户；依赖 Stop hook 29 号兜底提醒 + SessionStart 注入报告摘要 |
| D4 | **auto_advance 模式检测方式**：读 `.flow-active.goal.auto_advance` | 通过环境变量 `FLOW_KIT_AUTO_ADVANCE=1` 传递 | `.flow-active` 是 pipeline 状态的一来源（single source of truth），直接从 jq 读取与现有 `_gate_phase_transition` 的 phase 解析方式一致 | 增加一次 jq 调用（~5ms），性能可忽略 |
| D5 | **dispatch 失败降级策略**：API 调用失败 → 回退到 `l2_dispatch_prompt` 手动命令 | 重试 3 次后降级 / 写 correction 文件让下一轮 AI 自动执行 | 单次尝试 + 降级最简洁——PreToolUse hook 执行窗口短（~5s），重试会增加超时风险。手动命令给用户最大控制权 | Agent 临时不可用时用户需手动执行命令（已在 AC-5b 定义此行为） |
| D6 | **L2 Agent prompt 构造方式**：固化模板注入（与 L2-blind-review.md 结构一致）+ 阶段参数 | 动态生成 prompt（根据阶段选择不同 checklist） | 固化模板保证 L2 审查一致性——所有阶段的 L2 用同一套审查标准（四要素+严重度），仅阶段参数（1/2/3/5/6/7）切换 checklist 段 | 模板硬编码在 shell 函数中（~20 行 heredoc），如需改审查标准需改代码（非数据驱动）；合理——L2 审查标准不应频繁变动 |

---

## 2. 数据流 / 架构图

```
  AI (model)                                          PreToolUse Hook
  ──────────                                          ───────────────
      │                                                    │
      │  1. jq '.phase="2"' .flow-active                   │
      │──────────────────────────────────────────────────> │
      │                                                    │
      │                    ┌─ is_phase_write()? ──No──> exit 0 (放行)
      │                    │
      │                    ├─ _fk_phase_direction()
      │                    │   rollback/noop? ──Yes─> exit 0
      │                    │
      │                    ├─ gate_config[phase] 含 L2/both?
      │                    │   No ──> 跳过 L2，进 L3 检测
      │                    │
      │                    ├─ _gate_check_l2():
      │                    │   │
      │                    │   ├─ L2 已完成? (grep "## L2 盲审") ──Yes──> return 0
      │                    │   │
      │                    │   ├─ auto_advance=true? ──Yes──>
      │                    │   │   stderr: "[l2-dispatch] auto_advance: L2 missing but not blocking"
      │                    │   │   async dispatch (fire-and-forget)
      │                    │   │   return 0 (放行)
      │                    │   │
      │                    │   ├─ FLOW_KIT_SKIP_L2=1? ──Yes──> touch .skip-L2-<N> → return 0
      │                    │   │
      │                    │   ├─ 尝试 Agent auto-dispatch:
      │                    │   │   │
      │                    │   │   ├─ curl Anthropic API (async, --max-time 90)
      │                    │   │   │   后台进程: &>/dev/null & disown
      │                    │   │   │
      │                    │   │   ├─ 成功? ──>
      │                    │   │   │   stderr: "[l2-dispatch] Agent dispatched for phase <N>"
      │                    │   │   │
      │                    │   │   └─ 失败? ──>
      │                    │   │       stderr: l2_dispatch_prompt 手动命令
      │                    │   │       stderr: "[l2-dispatch] dispatch failed, see manual command above"
      │                    │   │       stderr: "FLOW_KIT_SKIP_L2=1 可跳过"
      │                    │   │
      │                    │   └─ exit 2 (deny)
      │                    │
      │                    └─ _gate_check_l3() + _gate_do_transition()
      │                        (既有逻辑，不改)
      │                                                    │
      │  2. exit 2 (or exit 0 for auto_advance/pass)       │
      │<────────────────────────────────────────────────── │
      │                                                    │
      │                                                    │  后台 Agent:
      │                                                    │  ┌─ Anthropic API
      │                                                    │  ├─ prompt: L2-blind-review 固化指令
      │                                                    │  ├─ 读: .specs/<id>/REQUIREMENT.md 等
      │                                                    │  └─ 写: INDEPENDENT-REVIEW-<N>.md
      │                                                    │
```

## 3. 关键状态机

### L2 PreToolUse Gate 状态转换

```
                 ┌──────────────┐
                 │   放行 (0)   │<──── L2 已完成 / gate_config 不含 L2 / auto_advance
                 └──────────────┘
                        ↑
    ┌───────────────────┼───────────────────┐
    │                   │                   │
    │  L2 已完成        │  auto_advance     │  gate_config
    │  (grep L2 盲审)   │  =true            │  不含 L2
    │                   │                   │
    │            ┌──────┴──────┐            │
    │            │  检测 (1)   │<───────────┘
    │            └──────┬──────┘
    │                   │ L2 缺失
    │            ┌──────┴──────┐
    │            │  派发 (2)   │──async──> Anthropic API
    │            └──────┬──────┘
    │                   │
    │         ┌─────────┼─────────┐
    │         │                   │
    │    dispatch 成功       dispatch 失败
    │         │                   │
    │    ┌────┴────┐      ┌──────┴──────┐
    │    │ 拦截(3) │      │ 降级(3')   │
    │    │ exit 2  │      │ 手动命令    │
    │    │ +Agent  │      │ +exit 2     │
    │    │ dispatched│    └─────────────┘
    │    └─────────┘
    │
    └── Agent 写入 INDEPENDENT-REVIEW → 下次 transition → 状态(0)
```

---

## 4. ADR 索引

本次涉及 1 项可逆性低的决策，单独写 ADR：

- `@.specs/adr/003-l2-pretooluse-dispatch.md` — L2 PreToolUse Agent 派发机制（API 调用方式 / 异步策略 / 降级路径）

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **Agent API 在 hook 内调用超时**：curl `--max-time 90` 在后台进程中运行，但 hook 超时（~5s）可能 kill 整个进程组 | dispatch 丢失，L2 未触发 | 中 | curl 在后台子进程（`&`）中运行，`disown` 脱离 hook 进程组；hook 自身在触发 dispatch 后立即 exit 2，不等结果。即使 hook 被 kill，Agent 进程继续运行 |
| R2 | **auto_advance + L2 dispatch 导致 Agent 堆积**：auto_advance 快速推进多阶段，每个阶段 fire-and-forget 一个 Agent | 多个 Agent 并发运行，API rate limit / token 消耗 | 中 | Anthropic API 有内置并发限制；auto_advance 本身有 toll-gate 暂停点（每阶段需人工确认才推进），实际不会无限制 fire。Stop hook 29 号模块在会话结束时聚合计数——若多个阶段 L2 未完成，输出 `[l2-detect] N phases have pending L2 reviews`，resume banner 展示待审列表 |
| R2b | **auto_advance L2 非阻塞的静默跳审累积**：用户快速确认 toll-gate 推进多阶段，stderr 警告易被淹没，多个阶段 L2 审查均未执行 | 产物已全部产出后才发现 L2 缺失，修复需回滚式修改 | 中 | Stop hook 29 号在会话结束时聚合报告所有待审阶段；resume banner 注入待审列表。DESIGN 已显式记录此风险，v2 可考虑 dispatch 去重 + 跨阶段聚合视图 |
| R3 | **gate 核心链改动引入回归**：`_gate_check_l2` 属禁动清单核心链模块（CONTEXT.md 禁动清单 § gate 校验核心链，line 387） | L3 / commit / PR / path-guard 任一 gate 失效 | 低 | 改动范围精确限定在 `_gate_check_l2` 函数内部（加 auto-dispatch 分支 + auto_advance 检测），不碰 `_gate_check_l3`、`_gate_phase_transition` 编排逻辑、`is_phase_write`、`_gate_path_guard`。全量 bats 回归覆盖所有 gate 场景 |
| R4 | **Agent prompt 注入导致审查质量不一致**：固化模板 vs 动态 prompt 的权衡 | L2 审查过于机械，漏判上下文敏感问题 | 低 | 与既有 L2-blind-review.md 模板完全一致（主 agent 调用子 agent 时也是注入同一模板）。L3（外部模型）提供第二意见兜底。v2 可考虑在 prompt 中注入前次审查摘要（类似 L3 上下文注入）。shell 函数 heredoc 加 `# SYNC-POINT: keep aligned with flow-kit/prompts/independent/L2-blind-review.md` 标记，防止人工同步漂移 |

---

## 6. 不在范围

- L3 dispatch 逻辑修改（`_gate_check_l3` / `_gate_do_transition` 不动）
- Stop hook L2 检测修改（`29-independent-review.sh` 不动）
- PreToolUse matcher 扩展（当前 `Bash|Write|Edit` 已覆盖，不需要改）
- `install_hooks.sh` 新增 hook 接线（不新增 PreToolUse hook 脚本，现有接线不变）
- L2 dispatch 覆盖非阶段切换场景（commit/PR 前 L2 dispatch 是独立 feature）

### 已知限制

- **顺序 L2→L3 检查的反馈延迟**：gate_config="both" 且 L2/L3 均缺失时，第一轮 transition 仅报告 L2 缺失（`_gate_check_l2` exit 2 后永远不到达 `_gate_check_l3`）。用户修复 L2 后需再次 transition 才能发现 L3 缺失——两轮交互。并行检查（L2+L3 同时派发 + 聚合报告）视为 v2 优化，不在本次范围。此限制不影响正确性（最终两个审查都会完成），仅影响 pipeline 吞吐。

---

## 9. 架构沉淀建议（本 change 完成后供 `A-evolve` 同步用）

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `hooks/stop/lib/l2-detect.sh::l2_dispatch_agent()`（新增函数） | L2 Agent 自动派发（curl + Anthropic API + 异步后台进程） | PreToolUse hook 中 `_gate_check_l2` 调用 | 未来若需要在 Stop hook 中也做 L2 自动派发（非仅提醒），可直接复用此函数。L3 若要从 `l3-review.sh` 迁移到统一 dispatch 模式（TD-008），可参考此实现 |

### 9.2 新增 / 改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| L2 Agent dispatch 方式 | curl + Anthropic Messages API + 异步 fire-and-forget | 所有 L2 自动派发场景 | 低——仅影响 `_gate_check_l2` 一个调用点，改为 Claude CLI 或其他 dispatch 方式只需改 `l2_dispatch_agent()` 内部实现 |

### 9.3 新增 / 修改的跨模块契约

```
- l2-detect.sh 新增函数 l2_dispatch_agent(phase, change_id, specs_dir) → 返回 0=dispatch 成功触发, 1=失败
- l2_detect_missing() 签名与返回值不变（保持无 .flow-active 依赖的纯净契约）
- _gate_check_l2() 内部新增 auto_advance 检测（独立 jq 读取 .flow-active.goal.auto_advance）+ Agent 自动派发分支
```

### 9.4 新增 / 升级的依赖

无新增外部依赖。curl/jq 已是项目运行环境的基础依赖（l3-review.sh 使用相同依赖）。

### 9.5 禁动清单变化

```
- 新增禁动：l2-detect.sh::l2_dispatch_agent() — 不允许绕过直接调用（必须通过 _gate_check_l2 的 gate_config 判定后才触发）
```
