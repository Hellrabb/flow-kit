# REQUIREMENT: 修 L3 gate 机制三连异常（L-030）

- **Change ID**: fix-l3-gate
- **关联**: `@.specs/fix-l3-gate/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 pipeline 使用者，我想 L3 审查 fail 后修改工件能触发 L3 重审，以便不被永久死结卡住。
- **US-2**：作为 pipeline 使用者，我想 L3 fail 时 gate 正确拦截 transition（不写 .done），以便不会被"L3 发现 critical 仍可绕过"的漏洞放行。
- **US-3**：作为 pipeline 使用者，我想 transition 后 `.flow-active` 的 `goal.current_phase`、顶层 `phase`、`phases_done`、`gates` 全部一致，以便 pipeline 状态不混乱。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · L3 重审——工件变更后重新触发

- **Given** 阶段 N（1/2/3/5/6/7）已完成一次 L3 审查，verdict=fail，`INDEPENDENT-REVIEW-N.md` 已存在 L3 段，且该文件的 mtime 已记录为 `L3_REVIEW_MTIME=$(stat -c %Y .specs/<id>/INDEPENDENT-REVIEW-N.md)`
- **When** 主 agent 修改了阶段 N 的产物文件（如 REQUIREMENT.md / DESIGN.md / TASK.md 等），使其 mtime 晚于 `L3_REVIEW_MTIME`
- **Then** 下次 Stop hook 或 PreToolUse hook 触发 L3 时，`l3-review.sh` 检测到 `artifact_mtime > INDEPENDENT-REVIEW-N.md 的 mtime`，重新调用 L3 API 审查，在 `INDEPENDENT-REVIEW-N.md` 末尾**追加**新的 `## L3 重审` 段（含新 verdict + summary），不覆写旧段。追加动作本身会更新 `INDEPENDENT-REVIEW-N.md` 的 mtime，形成自然防重入（同一次工件状态不会重复触发重审）
- **验证方式**: `grep -c "## L3 重审" .specs/<change-id>/INDEPENDENT-REVIEW-N.md` ≥ 1（模拟：touch 产物 → 触发 hook → 检查重审段）

### AC-2 · .done 安全——L3 fail 不写 .done

- **Given** L3 审查 verdict=fail（`L3_verdict=fail`）
- **When** PreToolUse hook `independent-review-gate.sh` 检测到 phase transition 尝试（`is_phase_write` 返回 0）
- **Then** gate **拒绝** transition：exit code = 2（0=放行，1=脚本错误，2=gate 拦截），stdout 输出 `GATE_DENY: L3 verdict=fail for phase N`，不创建/不更新 `.independent-review-N.done` 文件，pipeline 暂停等待用户处理
- **验证方式**: L3 fail 后 `test -f .specs/<change-id>/.independent-review-N.done` 返回 1（文件不存在）；PreToolUse hook exit code = 2；stdout 含 `GATE_DENY` + `verdict=fail`

### AC-3 · .done 安全——L3 pass 才写 .done

- **Given** L3 审查 verdict=pass
- **When** PreToolUse hook `independent-review-gate.sh` 检测到 phase transition 尝试
- **Then** gate **放行** transition：写入 `.independent-review-N.done`（6 键 KVP 格式，`L3_verdict=pass`）
- **验证方式**: L3 pass 后 `grep "L3_verdict=pass" .specs/<change-id>/.independent-review-N.done` 成功

### AC-4 · phase 同步——transition jq 四字段一致更新

- **Given** 当前 phase=N，所有 gate 已通过（`.done` 存在且有效）
- **When** transition jq 执行（从 phase N 推进到 N+1），使用 tempfile+mv 模式（`jq '...' .flow-active > .flow-active.tmp && mv .flow-active.tmp .flow-active`，禁止直接 `jq ... file > file`）
- **Then** `.flow-active` 中四个字段更新为一致值：`goal.current_phase = "N+1"`、顶层 `phase = "N+1"`（string 类型，与 `goal.current_phase` 统一）、`goal.phases_done` 包含 `"N"`、`goal.gates["N→N+1"] = "passed"`
- **验证方式**: transition 后执行 `jq '{top: .phase, goal: .goal.current_phase, done: .goal.phases_done[-1], gate: .goal.gates["N→N+1"]}' .flow-active`，四个值全部一致对应 N+1；另确认 transition 实现使用 tempfile+mv 模式（非直接 `> file` 原地覆写）

### AC-5 · 回退不受 L3 gate 拦截

- **Given** 当前 phase=N，用户需要回退到 phase M（M < N）
- **When** transition jq 执行回退（目标 phase < 当前 phase）
- **Then** `independent-review-gate.sh` 的 `is_phase_write` 检测到回退方向，**放行**不要求 .done（不回退被 L3 fail 卡住）
- **验证方式**: 从 phase 3 回退到 phase 2 → gate 放行（无需 .done），transition 成功

---

## 范围切分

### v1（本次必做）

- `l3-review.sh` 支持重审：检测工件 mtime > 上次 L3 审查时间 → 重新调用 L3 API → 追加 `## L3 重审` 段
- `independent-review-gate.sh` .done 写逻辑修复：`L3_verdict=fail` 时**不写** .done（仅 `pass` 时写入）
- transition jq 同步修复：同时更新 `goal.current_phase`、顶层 `phase`、`phases_done`、`gates` 四个字段
- 回退方向放行确认（已有 `transition 方向检测`，本次确保不被 .done 写逻辑改动破坏）

### v2（下一轮考虑，不本次）

- L3 重审次数上限配置（防无限重审循环 —— 当前无此风险，因为重审只在工件变更时触发）
- L3 重试超时后的自动降级策略（当前已有 30s timeout → verdict=timeout 降级，v2 可加可配置重试次数）
- L3 审查结果历史归档（多轮重审段的历史清理）

### out（永远不做）

- L3 外部模型选择/API 配置改动（当前 `ANTHROPIC_DEFAULT_HAIKU_MODEL` 机制够用）
- 引入新 gate 特性（如多轮 L3 阈值自动 pass、L3 结果机器学习评分）
- L2 审查机制改动（L2 工作正常，td-test-infra 已验证）
- gate_config 默认值改动（保持 `both`=L2+L3，用户显式切换）

---

## 非功能性需求

- **性能**: L3 重审的工件变更检测用 `stat -c %Y`（mtime 秒级比较），O(1) 无额外延迟
- **可访问性**: 无
- **安全**: .done 写逻辑修复消除 L3 fail 仍可绕过 gate 的安全漏洞（CHANGE.md 描述的第 2 条异常）
- **兼容性**: 不改动 .done 6 键 KVP 格式；不改动 `L3_RESULT:` 输出契约；不改动 `l3_review_run()` 函数签名
- **可观测性**: `l3-review.sh` 重审时在 hook log 中记录 `[L3-REVIEW] re-review triggered for phase N (artifact changed)`；.done 写入/拒绝时记录 verdict 和理由
- **容错**: L3 API 不可达（网络超时/HTTP 5xx）时沿用已有 30s timeout → verdict=timeout 降级逻辑（不阻塞 pipeline）；mtime stat 失败时视为"工件未变更"，跳过重审，在 hook log 记录 `[L3-REVIEW] stat failed, skipping re-review for phase N`

## 依赖与假设

- **依赖**: `l3-review.sh` 共享 lib（`hooks/stop/lib/l3-review.sh`）、`independent-review-gate.sh` PreToolUse hook、`31-auto-advance.sh` Stop hook（transition 同步）
- **假设**: L3 API（`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN`）可用；工件文件系统支持 mtime（秒级精度足够）；pipeline 模式下 `fk_resolve_phase()` 正常工作
- **假设**: 本 change 自身用 L2-only gate_config 跑 pipeline（不依赖 L3 review 自己，避免自举死结）
- **假设**: AC-1 的 L3 重审覆盖阶段 1/2/3/5/6/7——阶段 0（变更提案）不触发独立审查，阶段 4（开发执行）当前无 L3 审查，故排除

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
