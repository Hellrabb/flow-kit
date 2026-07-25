# REQUIREMENT: 独立 review gate `.done` 作者性校验缺口修复

- **Change ID**: gate-done-authorship
- **关联**: `@.specs/gate-done-authorship/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想让独立 review gate 校验 `.done` 标记由审查子系统（而非主 agent）产出，以便 L3 外部模型审查不被 agent 伪造 `.done` 绕过。
- **US-2**：作为 flow-kit 维护者，我想清理已废弃的握手机制死代码（`state_file` 读写 + Tier 2 T3 校验死分支），以便代码库不包含误导性安全假设、降低后续维护认知负荷。
- **US-3**：作为使用 `gate_config=L2`（仅 L2 审查）的用户，我想在 path-guard 禁 agent 写 `.done` 的机制下仍能正常完成 pipeline transition，以便 L2-only 模式不被作者性校验误杀。

---

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · agent 伪造 `.done` 被 gate 拦截

- **Given** gate_config 对某阶段开启了 L3 或 both（即要求独立审查），且该阶段的 `.independent-review-<N>.done` 不存在
- **When** 主 agent 尝试通过 Bash/Write/Edit 工具直接写入一个结构合法的 `.independent-review-<N>.done` 文件（含 6 键 KVP）
- **Then** PreToolUse hook（independent-review-gate.sh）的 path-guard 拦截该写入操作（exit 2 deny），并输出拒绝原因（含被拦截的路径 + 阶段号）
- **验证方式**: `npx bats test/test_gate_integrity.bats` — 对应 AC 测试用例（DESIGN 阶段确定具体测试编号和语义）

### AC-2 · 合法 `.done`（由审查子系统产出）被 gate 放行

- **Given** gate_config 对某阶段开启了 L3 或 both，且 L3 审查已完成（l3_review_run 调用外部模型 API 拿到 verdict=pass 后写入 `.done`）
- **When** 主 agent 发起 pipeline transition（即将通过 jq 写入 `.flow-active.phase`），PreToolUse hook 触发 done-validation
- **Then** independent-review-gate.sh 的 done-validation 校验通过，transition 放行（exit 0）
- **验证方式**: `npx bats test/test_gate_integrity.bats` — D9 正向测试（DESIGN 确定改写后的测试编号）

### AC-3 · 握手死代码全部清理

- **Given** CHANGE.md 证据链中列出的死代码位置
- **When** 执行死代码清理验证（`grep -rE "is_handshake_write|state_file|written_by=stop-hook-29|T3.*handshake|T3b.*SESSION|握手" flow-kit-bundle/hooks/`）
- **Then** 以下死代码已从生产代码中移除：
  - `done-validation.sh` Tier 2 T3 握手校验段（`[[ "$tier" == "transition" ]]` 死分支）— 删
  - `29-independent-review.sh` 的 `state_file` 读取（:68-74）+ 条件删除（:125, :203-204）— 删
  - `independent-review-gate.sh` 的 `is_handshake_write`（L30）— 删（方案 A：彻底废弃握手，改为 path-guard D7 扩展作为作者性锚点）
  - 全仓 `written_by=stop-hook-29` 作为写入值的引用（仅测试 fixture 中出现时一并清理）
- **验证方式**: `grep -rE "is_handshake_write|state_file|written_by=stop-hook-29|T3.*handshake|T3b.*SESSION|握手" flow-kit-bundle/hooks/` 在生产代码中无匹配（含中文"握手"注释；测试文件除外，由 AC-5 单独验证）

### AC-4 · L2-only 模式下 agent 写 `.done` 不被拦截

- **Given** gate_config 对某阶段设置为 `L2`（仅 L2，不含 L3 或 both），L2 审查已完成（主 agent 派 L2 子 agent + 写 INDEPENDENT-REVIEW-N.md L2 段）
- **When** 主 agent 按协议写入 `.independent-review-<N>.done`（6 键 KVP，`written_by=main-agent`、`L3_verdict=skipped`）
- **Then** path-guard **放行**该写入（识别 L2-only 模式例外，不拦截 agent 写 .done）
- **验证方式**: `npx bats test/test_gate_integrity.bats` — L2-only 例外测试用例（DESIGN 确定具体编号）

### AC-5 · 既有握手测试全部改写或删除

- **Given** `test_gate_integrity.bats` 中 4 个握手相关测试（AC-1 ②③ forged-done / ④ hijack / ⑤ tampered / D9 正向）+ `test/regression-demos/tampered-done/` + `exotic-escape/` 握手 demo
- **When** 执行既有握手测试（`npx bats test/test_gate_integrity.bats` 中对应的握手测试用例）
- **Then** 所有握手相关测试已改写为新语义（`.done` 作者性）或删除（若 DESIGN 判定无对应新语义）。改写后的测试全部通过（0 fail）
- **验证方式**: `npx bats test/test_gate_integrity.bats` — 握手相关测试不再引用 `written_by=stop-hook-29` 或 `is_handshake_write`；改写后的测试 exit 0

### AC-6 · agent 伪造 `.done` 的集成测试（payload 注入）

- **Given** gate_config 对 phase 6（review）设置为 `both`
- **When** 模拟 agent 通过 Bash 工具 `cat > .specs/<id>/.independent-review-6.done <<'EOF' ... EOF` 写入伪造 .done，然后尝试 jq transition phase 6→7
- **Then** PreToolUse hook 在 path-guard 拦截伪造写入（exit 2）；若绕过写入直接 transition，done-validation Gate 4 拦截（exit 4）
- **验证方式**: `npx bats test/test_gate_integrity.bats` — 新增 payload 注入式集成测试（对应记忆 [[gate-orchestration-integration-test]]）

### AC-7 · 全量 bats 回归 0 fail

- **Given** 本 change 所有代码修改完成
- **When** 执行 `make test`（或 `npx bats test/`）
- **Then** 全部测试通过，0 fail，exit code 0
- **验证方式**: `make test` 或 `npx bats test/`，输出 `N ok, 0 fail`

---

## 范围切分

### v1（本次必做）

- `.done` 作者性安全缺陷修复——agent 无法伪造 `.done` 绕过独立 review gate（锁定方案 A：彻底废弃握手，path-guard D7 扩展 + L2-only 条件放行）
- 握手死代码全部清理（`is_handshake_write` / `state_file` / `written_by=stop-hook-29` / Tier 2 T3 死分支）
- L2-only 模式 agent 写 `.done` 例外处理（path-guard 按 gate_config 条件放行）
- 既有 4 个握手测试改写为新语义或删除（具体由 DESIGN 定）
- `test/regression-demos/tampered-done/` + `exotic-escape/` 握手 demo 清理
- 新增 agent 伪造 `.done` payload 注入式集成测试
- 全量 bats 回归 0 fail

### v2（下一轮考虑，不本次）

- `correction_file_write` 同款 fixed-tmp race 全 lib 一致性修复（预存代码，非本 change 引入）
- done-validation.sh 其他死分支的全面审计与清理（如有）
- path-guard D7 扩展至其他敏感文件类型（如 `.flow-active` 敏感字段写入保护）

### out（永远不做）

- 不改 L2/L3 模型解析逻辑（那是 `l2-l3-model-config` 的 scope）
- 不改 `gate_config` 三值（`L2`/`L3`/`both`）语义
- 不触碰 `gate-review-fix` 的 13 条缺陷（独立 scope，可并行）
- 不改 `fk_resolve_model` 三级优先级链

---

## 非功能性需求

- **性能**: path-guard 新增检查延迟 < 5ms（wall-clock，典型 Linux 环境单次 jq 调用计），不对 PreToolUse hook 整体执行时间产生 > 5% 的回归
- **可访问性**: 无（非 UI 项目）
- **安全**: 
  - 核心安全需求已在 AC-1/AC-4/AC-6 中覆盖——`.done` 作者性校验必须基于机制保证（path-guard + done-validation），**不可依赖 agent 自律**
  - **Fail-safe**: path-guard 和 done-validation 的任何非预期错误（jq 解析失败、文件不可读、未知 gate_config 值）均导致 deny（exit 非零），不得 fall through 到放行。具体错误码由 DESIGN 分配
- **兼容性**: 
  - 向后兼容：已有合法 `.done` 文件（由 l3_review_run 写入）不受影响
  - gate_config 既有值（L2/L3/both）行为不变
  - L2-only 模式用户：path-guard 条件放行确保不破坏现有工作流
- **可观测性**: path-guard 拦截日志写入 hook log（`>> "$hook_log"`），含被拦截路径 + 阶段号 + 拒绝原因；`.flow-active.correction` 写入 type=done-forgery 供 SessionStart banner 展示

---

## 依赖与假设

- **依赖**：
  - `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh`（path-guard D7 + Gate 1/3/4/5/6/7）
  - `flow-kit-bundle/hooks/stop/lib/done-validation.sh`（Tier 2 校验，需删 T3 握手段）
  - `flow-kit-bundle/hooks/stop/29-independent-review.sh`（state_file 生命周期，需删读/删逻辑）
  - `flow-kit-bundle/hooks/stop/lib/l3-review.sh`（`_l3_write_done`，方案 A 下不涉及握手写入，仅保留 .done 写入逻辑）
  - `test/test_gate_integrity.bats`（4 个握手测试需重写）
  - `test/regression-demos/tampered-done/` + `exotic-escape/`（握手 demo 需清理）
- **假设**：
  - `.done` 6 键 KVP 格式不变（`phase`/`change_id`/`written_by`/`L2_verdict`/`L3_verdict`/`artifacts`）
  - gate_config 快照同步机制（`.flow-active.goal.gate_config` ↔ `.goal-snapshot.json`）不变
  - PreToolUse hook matcher 覆盖 Bash + Write + Edit 三种工具调用（D7 path-guard 基座）不变
  - 锁定方案 A（彻底废弃握手，path-guard D7 扩展 + L2-only 条件放行）。若 DESIGN 发现方案 A 不可行需回退方案 B，须更新本 REQUIREMENT 的 AC-3/AC-4

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
