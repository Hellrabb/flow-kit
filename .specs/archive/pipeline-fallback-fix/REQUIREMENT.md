# REQUIREMENT: 修复 pipeline 诊断发现的全部问题

- **Change ID**: pipeline-fallback-fix
- **关联**: `@.specs/pipeline-fallback-fix/CHANGE.md`、`@.specs/pipeline-fallback-fix/DIAGNOSIS.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想 L2+L3 独立审查能在单 session 内完成闭环（不等 Stop hook 会话结束），以便 pipeline 不被 L3 异步依赖死锁，transition 可正常推进。
- **US-2**：作为 flow-kit 维护者，我想 `/flow gate-config` 和 `/flow goal --gate-config` 自动同步 `.goal-snapshot.json`，以便 hook D8 ⑥ gate_config 篡改检测不误拦合法操作，不陷入不可逆死锁。
- **US-3**：作为 flow-kit 维护者，我想 pipeline 回退操作（目标 phase < 当前 phase）不被独立审查 gate 拦截，以便死锁后有恢复路径，可以后退重试。
- **US-4**：作为 flow-kit 维护者，我想 `auto_advance=true` 和 `mode=fallback` 有 hook 层兜底（不仅靠 prompt 驱动），以便弱模型下机制仍可靠，不因模型跳过指令而失效。

> **覆盖边界**: v1 的 fallback hook 兜底（AC-5/AC-5a）仅覆盖 pipeline 终点（phase 7 → done 标记）。phase 4→5→6→7 的 fallback 中间阶段推进仍依赖 GO.md prompt 路由（P1-3, AC-6）。若弱模型在中间阶段卡住，用户需手动干预。全阶段 fallback hook 推进留待 v2。

## 验收准则（AC）

### P0-1 (F1) · L3 前置到 PreToolUse hook

#### AC-1 · Transition 时 PreToolUse hook 同步触发 L3

- **Given** `gate_config["N-xxxx"] = "independent"`（如 N=1, key="1-requirement"），L2 盲审子 agent 已完成并产出 `INDEPENDENT-REVIEW-<N>.md` 的 L2 段，`.independent-review-<N>.done` 尚未写入
- **When** 主 agent 执行 transition jq（`current_phase = "N+1"`）
- **Then** `independent-review-gate.sh` 拦截该 jq → 检测 L2 已完成但 L3 未完成 → 调用共享 lib `l3-review.sh` 同步执行 L3 API 审查 → L3 结果写入 `INDEPENDENT-REVIEW-<N>.md` 的 L3 段 + 写入握手文件 `.independent-review-<N>.done`（即 AC-7 定义的 6 键 done 标记文件，其中 `written_by=pre-tool-use-gate`，`L3_verdict=<结果>`）→ 放行 transition jq
- **验证方式**: 设置 `gate_config["1-requirement"]="independent"`，L2 完成后执行 transition jq，确认 L3 被同步触发（`INDEPENDENT-REVIEW-<N>.md` 含 L3 段），transition jq 执行成功
- **注**: 本 AC 中的"握手文件"即 `.independent-review-<N>.done`，格式由 AC-7 定义。两术语指向同一文件。

#### AC-1a · L3 API 超时降级

- **Given** L3 API 调用超过 30s 未返回（外部模型不可用）
- **When** PreToolUse hook 等待 L3 完成
- **Then** hook 输出超时警告 → 在 `INDEPENDENT-REVIEW-<N>.md` 写入 `L3_verdict=timeout` → 放行 transition（不阻塞 pipeline）
- **验证方式**: 临时设 L3 API endpoint 为无效地址 → 执行 transition → 确认 30s 内超时降级 + transition 成功

#### AC-1b · Stop hook L3 兜底保留

- **Given** session 在 transition 前异常终止（PreToolUse hook 未触发 L3），L2 已完成
- **When** Stop hook `29-independent-review.sh` 执行
- **Then** 检测 L2 已完成 + L3 缺失 → 补跑 L3 → 写入 L3 段 + 握手文件（与当前行为一致）
- **验证方式**: L2 完成后直接结束 session（不跑 transition）→ 确认 Stop hook 补跑了 L3

#### AC-1c · L3 API 调用逻辑不重复（共享实现）

- **Given** `independent-review-gate.sh` 和 `29-independent-review.sh` 都需要调 L3 API（模型选择、prompt 构建、API 请求、超时处理、结果解析）
- **When** 任意一处的 L3 API 调用逻辑需要修改（如超时值、模型名、prompt 模板）
- **Then** 仅需修改一处即可同时影响两处的调用行为（即两处共享同一实现，无重复代码）
- **验证方式**: 修改共享实现中的超时值（如 30s → 15s）→ 确认两处调用的超时行为均变为 15s（非仅一处生效）

---

### P0-2 (F2) · gate_config 快照同步

#### AC-2 · `/flow gate-config` 同步更新 .goal-snapshot.json

- **Given** `.flow-active` 存在且 goal 非 null，`.specs/<id>/.goal-snapshot.json` 存在
- **When** 用户执行 `/flow gate-config 6-review=independent`
- **Then** `.flow-active.goal.gate_config["6-review"]` 更新为 `"independent"`，**同时** `.specs/<id>/.goal-snapshot.json` 的 `gate_config["6-review"]` 也更新为 `"independent"`，`.goal-snapshot.json` 的 `created_at` 更新为当前时间戳
- **验证方式**: 执行 `/flow gate-config 6-review=independent` → `diff <(jq '.goal.gate_config' .flow-active) <(jq '.gate_config' .specs/<id>/.goal-snapshot.json)` 无差异

#### AC-2a · `/flow goal --gate-config` 同样走快照写入

- **Given** 同 AC-2
- **When** 用户执行 `/flow goal "fix all" --pipeline --from 0 --gate-config all`
- **Then** gate_config 写入 `.flow-active` 的同时写入 `.goal-snapshot.json`（两处一致）
- **验证方式**: 同 AC-2 的 diff 验证

#### AC-2b · hook D8 ⑥ 快照检查保持有效

- **Given** gate_config 经 `/flow gate-config` 正常修改后，两处一致
- **When** PreToolUse hook 执行 D8 ⑥ 快照一致性检查
- **Then** hook 检测一致 → 放行操作（exit 0），不输出任何拦截或警告消息
- **验证方式**: 正常修改 gate_config 后执行任意 Bash/Write → hook 不输出篡改拦截消息

---

### P0-3 (F3) · Gate 区分前进/回退

#### AC-3 · 回退 transition 不被拦截

- **Given** `gate_config["6-review"] = "independent"`，`.independent-review-6.done` 不存在，`current_phase = "6"`
- **When** 主 agent 执行回退 transition jq（如 `current_phase = "5"`, `phases_done -= ["5"]`）
- **Then** `independent-review-gate.sh` 的 `is_phase_write` 检测到目标 phase (5) < 当前 phase (6) → 判定为回退 → **放行**，不要求 .done
- **验证方式**: 从 phase 6 回退到 phase 5 的 jq → hook 放行 → jq 执行成功

#### AC-3a · 前进 transition 仍要求 .done

- **Given** 同 AC-3 条件（`.done` 不存在），但 transition 方向为前进（目标 phase 7 > 当前 phase 6）
- **When** 主 agent 执行前进 transition jq
- **Then** hook 检测到前进方向 → **拦截**（exit 1），输出 `.done` 缺失消息
- **验证方式**: 不创建 `.done` 从 phase 6 前进到 7 的 jq → hook 拦截 → jq 被拒绝

#### AC-3b · No-op transition（target == current_phase）放行

- **Given** `gate_config["6-review"] = "independent"`，`.independent-review-6.done` 不存在，`current_phase = "6"`
- **When** 主 agent 执行 no-op transition jq（`current_phase = "6"` 不变，仅修改 `gates` 或 `phases_done` 等非推进性字段）
- **Then** `independent-review-gate.sh` 的 `is_phase_write` 检测到目标 phase (6) == 当前 phase (6) → 判定为状态维护操作 → 放行（不要求 .done）
- **验证方式**: 执行 no-op jq（不改 current_phase，只改 gates 字段）→ hook 放行 → jq 执行成功

---

### P1-1 (F4) · auto_advance hook 兜底

#### AC-4 · auto_advance=true 时 hook 自动 transition

- **Given** `goal.auto_advance = true`，`goal.current_phase = "4"`，阶段 4 的 PCSC 全部 ✅（产物均在磁盘）
- **When** 会话正常结束（Stop hook 触发）
- **Then** 新增的 `31-auto-advance.sh` hook 模块检测到条件满足 → 自动执行 transition jq（`current_phase = "5"`, `phases_done += ["4"]`, `gates["4→5"] = "passed"`）
- **验证方式**: 设 auto_advance=true, current_phase=4，阶段 4 产物齐全 → 结束 session → 检查 `.flow-active` 中 current_phase 已变为 "5"

#### AC-4a · PCSC 不全时 hook 不自动 transition

- **Given** `auto_advance = true`，`current_phase = "4"`，但 PCSC 至少 1 项 ❌（如缺少 SUMMARY.md）
- **When** Stop hook 触发
- **Then** hook 检测到 PCSC 不全 → **不执行** transition → 输出缺失清单到 transcript
- **验证方式**: 删除某产物 → 结束 session → current_phase 仍为 "4"

#### AC-4b · auto_advance=false 时 hook 不触发

- **Given** `auto_advance = false`
- **When** Stop hook 触发
- **Then** `31-auto-advance.sh` 检测到 auto_advance=false → 跳过，不执行任何 transition
- **验证方式**: auto_advance=false 时结束 session → current_phase 不变（排除 hook 干扰）

---

### P1-2 (F5) · Fallback hook 兜底

#### AC-5 · Fallback 条件满足时 hook 自动标记 done

- **Given** `goal.mode = "fallback"`，`goal.scope = "pipeline"`，`goal.current_phase = "7"`，phase 7 PCSC 全 ✅
- **When** 会话正常结束（Stop hook 触发）
- **Then** 新增的 `32-fallback-guard.sh` hook 模块检测到条件满足 → 自动更新 `goal.status = "done"`
- **验证方式**: 设 mode=fallback, current_phase=7, PCSC 全 ✅ → 结束 session → `jq '.goal.status' .flow-active` = `"done"`

#### AC-5a · Fallback 条件不满足时 hook 不标记 done

- **Given** `mode = "fallback"`，`current_phase = "4"`（pipeline 未完成）
- **When** Stop hook 触发
- **Then** hook 检测到 pipeline 未完成 → 不标记 done，goal.status 保持 "active"
- **验证方式**: fallback 模式下中途结束 session → goal.status 仍为 "active"

---

### P1-3 · GO.md mode 路由

#### AC-6 · GO.md 含 fallback 路由分支

- **Given** `goal.mode = "fallback"`
- **When** AI 加载 GO.md 进行阶段路由
- **Then** GO.md 中存在 mode 特定路由逻辑：检测 `mode=fallback` 时，在 4-dev/5-test/6-review/7-integration 阶段加载对应的 fallback 迭代指令段（从 4-dev.md prompt 中提取/去重为共享引用段）
- **验证方式**: `grep -c "fallback\|mode.*fallback" ~/.claude/flow-kit/GO.md` ≥ 3（至少 3 处 mode 路由引用）

#### AC-6a · GO.md 与 4-dev.md fallback 段去重

- **Given** GO.md 新增了 fallback 路由分支，4-dev.md prompt 原有 fallback 迭代描述
- **When** 开发者维护 fallback 逻辑
- **Then** fallback 迭代循环的核心描述在 GO.md 中（作为路由逻辑），4-dev.md 仅保留 `@see GO.md § fallback` 引用，不在两处重复
- **验证方式**: `grep -c "fallback.*迭代\|iterat.*fallback\|每个 turn.*自检" ~/.claude/flow-kit/prompts/4-dev.md` → 只出现引用（`@see`），不重复完整描述

---

### P2-1 (F6) · AC-5a ↔ hook 字段同步

#### AC-7 · .done 6 键统一规范

- **Given** 独立审查（L2+L3）均已完成
- **When** 主 agent 写入 `.independent-review-<N>.done`
- **Then** 文件包含以下 6 个键值对（每行 `key=value`）：
  ```
  phase=<N>
  change_id=<change-id>
  written_by=<stop-hook-29 | pre-tool-use-gate>
  L2_verdict=pass|fail
  L3_verdict=pass|fail|timeout
  artifacts=<逗号分隔的产物文件列表，至少 1 个>
  ```
- **验证方式**: 解析 .done 文件 → 6 键齐全 + 值有效（phase 为数字、change_id 非空、verdict ∈ {pass,fail,timeout}、artifacts 至少含 1 个文件名）

#### AC-7a · `fk_validate_done_marker()` 补 `artifacts=` 检查

- **Given** `.done` 文件包含 phase/change_id/written_by/L2_verdict/L3_verdict 但缺少 `artifacts=` 键
- **When** `fk_validate_done_marker()` Tier 1 校验执行
- **Then** 返回 2（校验失败），输出 `missing key: artifacts`
- **验证方式**: 创建缺失 `artifacts=` 的 .done → `fk_validate_done_marker` → 返回 2

---

### P2-2 · Tier1 补 L2/L3_verdict 检查

#### AC-8 · Tier1 检查 L2_verdict 和 L3_verdict 存在性

- **Given** `.done` 文件包含 phase/change_id/written_by 但缺少 `L2_verdict=` 或 `L3_verdict=`
- **When** `fk_validate_done_marker()` Tier 1 校验执行（非 transition 操作，如 commit）
- **Then** 返回 2（校验失败），输出具体缺失键名
- **验证方式**: 创建缺失 `L3_verdict=` 的 .done（但含 phase/change_id/written_by）→ `fk_validate_done_marker` Tier1 → 返回 2

#### AC-8a · Tier1 不要求 verdict 值匹配具体文件

- **Given** `.done` 文件 6 键齐全，verdict 值为合法枚举值（pass/fail/timeout）
- **When** `fk_validate_done_marker()` Tier 1 校验执行
- **Then** 返回 0（通过）——Tier1 仅检查键存在 + 值格式合法，不比对 INDEPENDENT-REVIEW.md 中的实际内容（那是 Tier2 的职责）
- **验证方式**: 完整的 6 键 .done → Tier1 返回 0

---

## 范围切分

### v1（本次必做）

- P0-1 (F1): L3 前置 PreToolUse hook — `l3-review.sh` lib + `independent-review-gate.sh` 同步 L3 + Stop hook 兜底
- P0-2 (F2): `/flow gate-config` + `/flow goal --gate-config` 同步 `.goal-snapshot.json`
- P0-3 (F3): Gate 区分前进/回退，回退放行
- P1-1 (F4): auto_advance hook 兜底（`31-auto-advance.sh`）
- P1-2 (F5): Fallback hook 兜底（`32-fallback-guard.sh`）
- P1-3: GO.md mode 路由分支 + 4-dev.md 去重
- P2-1 (F6): .done 6 键统一 + `artifacts=` 检查
- P2-2: Tier1 补 L2/L3_verdict 存在性检查

### v2（下一轮考虑，不本次）

- `auto_advance` hook 的 PCSC 自检自动化（hook 自己 grep PCSC 段判断全 ✅，而非依赖 transcript 解析）
- L3 timeout 策略细化：按模型 tier 区分超时（fast model 15s / full model 30s）
- `27-interactive-ui-check.sh` 迁移到统一矫正文件 `.flow-active.correction`（v2 迁移，与 28 号模块合并格式）
- 多阶段累积 L3 发现 → 汇总拦截（而非仅单阶段 gate）

### out（永远不做）

- **运行时模型能力自动探测**（让弱模型自评能力 → 不可靠，已否决，见 CONTEXT.md 决策 `[2026-06-25]`）
- **重写 auto_advance 为 CC 系统级机制**（CC 无对应 hook API，不可行）
- **取消 L2/L3 独立审查**（gate-integrity 核心设计，不倒退）

---

## 非功能性需求

- **性能**: L3 API 同步调用单次 ≤ 30s 超时；PreToolUse hook 其他检查（非 L3 路径）延迟 < 100ms（不增加可感知延迟）
- **兼容性**: 不改变现有 hook API 输入/输出格式；`.done` 新增 `artifacts=` 键但旧版 .done（5 键）在 Tier2（transition）仍可识别为"需重新审查"而非崩溃；`stop-hook.json` schema 不变
- **安全**: 无新增安全攻击面（L3 API 调用沿用现有鉴权方式 `$ANTHROPIC_AUTH_TOKEN` + `$ANTHROPIC_BASE_URL`，不引入新凭证）
- **可观测性**: L3 同步调用时 hook 输出进度提示（"L3 审查中..."）；超时/失败输出明确原因 + 降级路径
- **代码质量**: 新增 Shell 函数遵守 `set -euo pipefail`；函数命名 `snake_case`
- **可靠性**: L3 API 调用单次失败后不重试（直接降级为 timeout）；`.done` 文件写入使用原子操作（先写临时文件再 `mv`）；hook 模块间无共享可变状态
- **并发**: 同一 change 在同一时刻仅允许一个 session 处于 active 状态（`.flow-active` 文件自然互斥）；若检测到多 session 并发，后启动的 session 应警告用户
- **容量**: `.flow-active` 文件 < 100KB；`.goal-snapshot.json` < 50KB；单次 session 的 L3 调用次数 ≤ 阶段数（7 次）

---

## 依赖与假设

- **依赖**: `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 环境变量可用（L3 API 调用前提，已存在）；`ANTHROPIC_DEFAULT_HAIKU_MODEL` 环境变量（L3 模型选择，已存在）；`jq` 已安装（`.flow-active` 和 `.goal-snapshot.json` 操作）
- **假设**: L3 外部模型 API 大概率可用（超时降级为异常路径，非正常路径）；用户环境 CC ≥ v2.1.139（native /goal 可用）；`.specs/<id>/` 目录在 goal 设定时已存在（快照写入前提）
- **PCSC 产物清单（v1 判定方式）**: AC-4/AC-5/AC-5a 中"PCSC 全 ✅"的判定标准：对于 phase N，检查对应阶段 prompt（`~/.claude/flow-kit/prompts/<N>-*.md`）的 PCSC 表格中列出的产物文件是否均存在于 `.specs/<id>/` 磁盘上。v1 中此判定由 hook 模块内硬编码每阶段产物列表实现（从各 prompt 的 PCSC 段提取）；v2 计划自动化解析 prompt PCSC 段。若某阶段 prompt 无 PCSC 段（如 phase 0），视为始终"全 ✅"。
- **Stop hook 触发语义假设**: CC 平台在以下会话终止场景下触发 Stop hook：a) 主 agent 自然结束（发送最终响应后）；b) 用户 `/exit` 或 `exit` 指令；c) `Ctrl+C`（SIGINT → SIGTERM → Stop hook）。Stop hook **不保证**在 SIGKILL（`kill -9`）或 OS 崩溃后触发——这些场景下的 pipeline 断点恢复依赖用户手动 `/flow-go 继续`。
- **与既有实现的关系**: `29-independent-review.sh` 的 L3 API 调用代码是抽取 lib 的主要来源；`independent-review-gate.sh` 的 D8 ⑥ 快照检查逻辑不变（仅修复同步源）；`flow-kit-artifacts.sh` 的 `fk_validate_done_marker()` 签名不变（仅内部增加检查字段）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
