# REQUIREMENT: L2 PreToolUse Dispatch — 阶段切换时前置触发 L2 独立审查

- **Change ID**: `l2-pretooluse-dispatch`
- **关联**: `@.specs/l2-pretooluse-dispatch/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit pipeline 使用者，当我配置了某阶段的 L2 独立审查（gate_config 为 L2 或 both），且该阶段 L2 尚未完成时，我想系统在阶段切换时硬拦截，以便我不会基于未经审查的中间产物继续推进。
- **US-2**：作为 flow-kit 使用者，当 L2 审查在阶段切换时被检测到缺失，我想系统自动派发 L2 审查 Agent，以便我不需要手动记住去触发审查。
- **US-3**：作为 flow-kit 使用者，当 L2 审查已完成（INDEPENDENT-REVIEW-<phase>.md 含 L2 段），我想阶段切换正常放行，不被误拦截。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · L2 缺失时硬拦截阶段切换

- **Given** `.flow-active.goal.gate_config["2-design"] = "L2"`（或 `"both"`），且 `.specs/<id>/INDEPENDENT-REVIEW-2.md` 不存在或不含 `## L2 盲审` 段
- **When** AI 执行写 `.flow-active.phase` 的命令（如 `jq '.phase = "2"' .flow-active`）
- **Then** PreToolUse hook 检测到 L2 缺失 → `exit 2`，命令被拒绝执行，阶段切换失败
- **验证方式**: `test/test_l2_pretooluse_dispatch.bats` — 模拟 gate_config=L2 + INDEPENDENT-REVIEW 缺失 + Bash 写 phase → assert exit 2

### AC-2 · L2 完成时放行阶段切换

- **Given** `.flow-active.goal.gate_config["2-design"] = "L2"`，且 `.specs/<id>/INDEPENDENT-REVIEW-2.md` 存在且含 `## L2 盲审` 段
- **When** AI 执行写 `.flow-active.phase` 的命令
- **Then** PreToolUse hook 检测到 L2 已完成 → `exit 0`，命令正常执行
- **验证方式**: `test/test_l2_pretooluse_dispatch.bats` — 模拟 gate_config=L2 + INDEPENDENT-REVIEW 已有 L2 段 + Bash 写 phase → assert exit 0

### AC-3 · gate_config=both 时 L2+L3 独立判定

- **Given** `.flow-active.goal.gate_config["6-review"] = "both"`，L2 缺失但 L3 已完成（即 `.independent-review-6.done` 通过 `fk_validate_done_marker` 校验，含合法 phase/change_id/timestamp/verdict KVP）
- **When** AI 执行写 `.flow-active.phase` 的命令
- **Then** PreToolUse hook 检测到 L2 缺失 → `exit 2`（L2 和 L3 独立判定，任缺其一即拦截）
- **验证方式**: 模拟 gate_config=both + L2 缺失 L3 完成（含合法 .done KVP）→ assert exit 2

### AC-4 · gate_config 不含 L2 时跳过检测

- **Given** `.flow-active.goal.gate_config["3-task"] = "L3"`（仅 L3，不含 L2）
- **When** AI 执行写 `.flow-active.phase` 的命令
- **Then** PreToolUse hook 不触发 L2 检测，L3 检测逻辑独立运行不受影响
- **验证方式**: 模拟 gate_config=L3 + Bash 写 phase → L2 检测不触发（不读 INDEPENDENT-REVIEW，不 exit 2 for L2）

### AC-5a · L2 自动派发触发 + 状态反馈

- **Given** gate_config 要求 L2，L2 缺失，阶段切换被拦截
- **When** PreToolUse hook 检测到 L2 缺失
- **Then** hook 执行以下动作（按顺序）：
  1. 异步触发 L2 审查 Agent 派发（fire-and-forget，不阻塞 hook 返回）
  2. stderr 输出 `[l2-dispatch] Agent dispatched for phase <N>`（派发成功）或 `[l2-dispatch] dispatch failed, see manual command above`（派发失败）
  3. `exit 2` 拒绝阶段切换
- **验证方式**: `test/test_l2_pretooluse_dispatch.bats` — 模拟 L2 缺失场景 → assert stderr 含 `[l2-dispatch]` 派发标记 + assert exit 2

### AC-5b · L2 派发失败降级为手动命令

- **Given** gate_config 要求 L2，L2 缺失，Agent API 不可用（超时/网络错误/凭证缺失/API 错误）
- **When** PreToolUse hook 尝试自动派发 Agent 失败
- **Then** hook 回退到生成手动派发命令：调用 `l2_dispatch_prompt <phase> <change_id>` 输出到 stderr，附带 `[l2-dispatch]` 前缀和操作指引（`请复制上方命令手动执行或设置 FLOW_KIT_SKIP_L2=1 跳过此 gate`），然后 `exit 2`
- **验证方式**: 模拟 Agent API 不可用（如设置无效 API endpoint）→ assert stderr 含 `l2_dispatch_prompt` 生成的命令文本 + `FLOW_KIT_SKIP_L2=1` 指引 + assert exit 2

### AC-5c · L2 派发结果写入（集成验证）

- **Given** gate_config 要求 L2，L2 缺失，Agent 派发成功
- **When** Agent 完成审查
- **Then** `INDEPENDENT-REVIEW-<phase>.md` 被创建/更新，含 `## L2 盲审` 段
- **验证方式**: bats 测试统一使用 `FLOW_KIT_L2_MOCK=1` mock 模式：mock Agent 即时返回固定审查结果 → poll 最多 10s → assert 文件含 `## L2 盲审` 段。真实环境（非 bats）不使用该环境变量，走实际 Agent API 调用

### AC-6 · L3 PreToolUse 行为无回归

- **Given** 现有 L3 gate_config 配置和 L3 审查流程
- **When** 任意阶段切换（L3 缺失 / L3 完成 / path-guard 触发）
- **Then** L3 相关行为与变更前完全一致（gate_config 篡改检测、握手写拦截、commit/PR 拦截、.done 写入）
- **验证方式**: `test/test_independent_review_gate.bats` 全部现有用例通过，无新增失败

### AC-7 · Stop hook L2 行为无回归

- **Given** 现有 `29-independent-review.sh` 的 L2 检测逻辑
- **When** Stop hook 在对话结束后运行
- **Then** L2 检测和提醒行为与变更前一致（PreToolUse dispatch 是前置补充，不替代 Stop hook 事后检测）
- **验证方式**: `test/test_stop_chain.bats` 中 L2 相关用例通过，无新增失败

### AC-8 · install_hooks.sh 接线正确

- **Given** 全新安装或重装 hooks
- **When** `install_hooks.sh` 执行
- **Then** PreToolUse hook 的 settings.json matcher 覆盖 L2 dispatch 所需的工具事件（Bash/Write/Edit），hook 命令路径正确
- **验证方式**: `test/test_install_hooks.bats` — 验证 settings.json 中 PreToolUse 配置含 L2 dispatch 所需 matcher

### AC-9 · auto_advance 模式下非阻塞告警

- **Given** `.flow-active.goal.auto_advance = true`，`.flow-active.goal.gate_config["2-design"] = "L2"`，L2 缺失
- **When** Stop hook 的 `31-auto-advance.sh` 触发阶段切换（写 `.flow-active.phase`）
- **Then** PreToolUse hook 检测到 L2 缺失 + auto_advance 模式 → **不执行 exit 2**（不阻断自动推进），stderr 输出 `[l2-dispatch] auto_advance: L2 missing for phase 2 but not blocking in auto_advance mode`，异步派发 Agent（fire-and-forget），exit 0 放行。Stop hook L2 检测（29 号）在后续轮次兜底提醒
- **验证方式**: `test/test_l2_pretooluse_dispatch.bats` — 模拟 auto_advance=true + gate_config=L2 + L2 缺失 + Bash 写 phase → assert exit 0 + assert stderr 含 `auto_advance: L2 missing` 警告

### AC-10 · L3 backlog 扫描错误不再静默吞没

- **Given** Stop hook 29 号模块运行，积压扫描器检测到 Phase 1 L3 缺失，但 `l3_review_run` 调用失败（API 超时/网络错误）
- **When** `_l3_scan_backlog` 调用 `l3_review_run`
- **Then** stderr 正常输出（不被 `2>/dev/null` 吞掉），`module_output "warning"` 记录 `backlog L3 failed for phase 1 (rc=<N>)——see hooks.log`
- **验证方式**: `test/test_l2_pretooluse_dispatch.bats` — 模拟 l3_review_run 失败 → assert hooks.log 含 `[backlog]` 错误日志 + `module_output` 警告

### AC-11 · L3 内容原子写入防竞态

- **Given** Stop hook L3 审查完成，准备写入 INDEPENDENT-REVIEW 文件；同时主 agent 可能在同一文件上做 Edit
- **When** `l3-review.sh` 写入 L3 段 + .done 文件
- **Then** 使用 temp-file + mv 原子写入（非裸 `>>`），写入后 grep 验证 L3 段存在；.done 同样原子化
- **验证方式**: `test/test_l2_pretooluse_dispatch.bats` — 模拟 L3 写入后立即做一次 Edit → assert L3 段仍存在（原子写入防竞态）+ .done 文件完整

---

## 范围切分

### v1（本次必做）

- `independent-review-gate.sh` 扩展：在 `is_phase_write` 命中后新增 L2 检测分支
- 调用 `l2_detect_missing()` 判定 L2 完成状态
- L2 缺失 → `exit 2` 硬拦截（fail-close），auto_advance 模式例外（非阻塞告警）
- L2 自动派发 Agent（异步 fire-and-forget），派发时序：先触发 dispatch → 再 exit 2
- L2 派发失败降级：回退到 `l2_dispatch_prompt` 生成手动命令 + `FLOW_KIT_SKIP_L2=1` 指引
- `install_hooks.sh` 兼容性验证
- **L3 写入管道修复**：`29-independent-review.sh` 去 `2>/dev/null` 错误吞没 + `l3-review.sh` 原子写入（tmp+mv）+ 写入后 grep 验证
- bats 测试覆盖 AC-1 ~ AC-11
- 全量回归：现有 L3 / commit / PR / path-guard / gate_config 篡改检测全部通过

### v2（下一轮考虑，不本次）

- L2 PreToolUse dispatch 的统计/metrics 收集（dispatch 次数、成功率、平均耗时）
- gate_config UI 优化：`/flow goal` 子命令支持 `--l2-only` / `--l3-only` 细粒度配置
- Agent 超时后的自动重试逻辑（当前 v1 仅做一次派发尝试，失败即降级）

### out（永远不做）

- 在 PreToolUse hook 中同步等待 Agent 完成再放行（PreToolUse hook 有超时限制，不可长时间阻塞工具执行）
- 用 L2 PreToolUse dispatch 替代 Stop hook L2 检测（两条路径互补，不做合并或删除任一条）
- L2 dispatch 覆盖非阶段切换场景（如 commit/PR 前的 L2 dispatch —— 那是独立的 feature，不在本次范围）

---

## 非功能性需求

- **性能**: PreToolUse hook L2 检测逻辑增量耗时 ≤ 50ms（不含 Agent dispatch，dispatch 为异步触发不阻塞 hook 返回）
- **可访问性**: 无（CLI/Shell 项目）
- **安全**:
  - Agent dispatch 使用的 API key 从环境变量读取（`ANTHROPIC_API_KEY` 或 `CLAUDE_API_KEY`），不硬编码；hook 脚本自身不暴露 key 到日志
  - **Agent 权限边界**：被派发的 L2 审查 Agent 仅读 `.specs/<id>/REQUIREMENT.md` / `DESIGN.md` / `CHANGE.md` 等阶段工件 + 已有的 `INDEPENDENT-REVIEW-<phase>.md`（追加模式），仅写 `INDEPENDENT-REVIEW-<phase>.md` 的 `## L2 盲审` 段；Agent 不可修改 `.flow-active`、`gate_config`、hook 脚本或项目源代码
  - **审计**：Agent dispatch 事件记录到 hooks.log（含触发阶段、change-id、时间戳、派发结果），`[l2-dispatch]` 前缀日志覆盖触发/成功/失败三种状态
- **兼容性**: 向后兼容 — 无 gate_config 或 gate_config 不含 L2 时行为完全不变；`.flow-active` schema 不新增字段
- **可观测性**: hook stderr 输出 `[l2-dispatch]` 前缀日志，覆盖以下事件：`detected L2 missing for phase <N>` / `Agent dispatched for phase <N>` / `dispatch failed, see manual command above` / `auto_advance: L2 missing for phase <N> but not blocking`。可通过 `hooks.log` 追踪

## 依赖与假设

- **依赖**: `l2-detect.sh` lib（`l2_detect_missing()` + `l2_dispatch_prompt()` 函数）— 已存在，本次可能扩展 `l2_detect_missing()` 返回值类型
- **依赖**: `independent-review-gate.sh` 现有架构（`is_phase_write`、gate_config 读取、fail-close 策略）— 已存在，本次在基础上扩展
- **依赖**: Anthropic API 可用（用于 Agent dispatch）— 假设运行环境已配置 `ANTHROPIC_API_KEY` 或等效凭证，curl 可用
- **假设**: PreToolUse hook 运行环境可发起 HTTP 请求（curl 可用）
- **假设**: Agent dispatch 为异步触发（后台进程/nohup），不阻塞 hook 返回；dispatch 在 exit 2 之前触发以确保代码可达
- **假设**: `FLOW_KIT_L2_MOCK=1` 环境变量可用于 bats 测试跳过真实 API 调用（使用 mock 端点即时返回固定审查结果）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
