# REQUIREMENT: L2/L3 双层审查结果合并写入

- **Change ID**: `dual-review-merge-fix`
- **关联**: `@.specs/dual-review-merge-fix/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，当我为某阶段同时开启 L2 和 L3 独立审查（gate_config = "both"）时，我想两份审查结果完整保留在同一文件中，以便获得完整的双层审查反馈。
- **US-2**：作为 flow-kit 用户，当 L2 子 agent 在后继 session 中补跑时，我不想它覆盖掉已由 Stop hook 产出的 L3 审查结果。
- **US-3**：作为 flow-kit 用户，当 L3 在 L2 未完成时触发（Stop hook 或 PreToolUse），我不想要一份不完整的 `.done` 标记——它应该在双方都完成后才写入。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · L3 不先于 L2 运行（gate_config="both" 强制）

- **Given** 某阶段 gate_config = "both"（L2+L3 双层），且 L2 尚未完成（`INDEPENDENT-REVIEW-<N>.md` 不存在或缺少 `## L2 盲审` 段）
- **When** Stop hook `29-independent-review.sh` 或 PreToolUse `independent-review-gate.sh` 尝试触发 L3
- **Then** L3 被跳过，输出 `[independent-review] L3 skipped (L2 not yet complete, gate_config=both)`；`.done` 不被写入；pipeline transition 被阻断（若通过 PreToolUse）
- **验证方式**: `grep -q "L2 not yet complete" <transcript>` 或检查 `.done` 未提前生成

### AC-2 · L2 子 agent 追加写入，不覆写 L3

- **Given** `INDEPENDENT-REVIEW-<N>.md` 已存在且包含 `## L3 盲审` 段（场景：前次 session 异常中断 → Stop hook 已写入 L3 段 → SessionStart 恢复 → 主 agent 补派 L2 子 agent；或 gate_config ≠ "both" 时 L3 先于 L2 完成）。L2 段缺失或不完整。
- **When** 主 agent 派 L2 子 agent 写盲审结果
- **Then** L2 子 agent 将 L2 段**追加**到现有文件末尾（保留已有 L3 段），而非整文件覆写
- **验证方式**: 派 L2 前后文件行数对比——L2 追加后文件行数 ≥ L2 追加前；L3 段 `## L3 盲审` 在文件中仍存在且内容不变

### AC-3 · L3 追加写入不覆写 L2

- **Given** `INDEPENDENT-REVIEW-<N>.md` 已存在且包含 L2 段
- **When** L3（Stop hook 或 PreToolUse）调用 `l3_review_run()`
- **Then** L3 段以 `>>` 追加写入（当前行为正确，需保留），L2 段内容不被改动
- **验证方式**: `grep -c "^## L2 盲审"` 在 L3 运行前后一致；L2 段的 verdict 值不变

### AC-4 · .done 仅在双方完成后写入

- **Given** gate_config = "both" 且仅 L2 或仅 L3 完成
- **When** 任一方尝试写 `.independent-review-<N>.done`
- **Then** `.done` 不被写入
- **验证方式**: 仅 L2 完成时 `test -f .done` → false；仅 L3 完成时 `test -f .done` → false（`.done` 的不存在本身即表明审查未完成，`done-validation.sh` 的 `fk_validate_done_marker()` 以文件缺失为首层拦截）

### AC-5 · 所有阶段一致行为

- **Given** 阶段 ∈ {1, 2, 3, 5, 6, 7}（Phase 4 不在 gate_config 独立审查范围内——`done-validation.sh` 的 `phase_name` case 仅含 {1,2,3,5,6,7}，4-dev 使用 self-review + brooks-lint 不同机制），gate_config = "both"
- **When** 执行 L2 + L3 双层审查流程
- **Then** AC-1~AC-4 的行为在所有阶段完全一致
- **验证方式**: 逐阶段跑 `npx bats test/test_checkpoint.bats`（或新增专用 bats 测试），每个阶段的 L2/L3 写入均符合 AC-1~AC-4

### AC-6 · L2-only 模式：`.done` 为有效 6 键 KVP（非空 touch）

- **Given** gate_config = "L2"（仅 L2），L2 子 agent 已完成盲审并写入 `INDEPENDENT-REVIEW-<N>.md`
- **When** 主 agent 确认 L2 段存在并写 `.done` 标记
- **Then** `.done` 为有效的 6 键 KVP 文件（`phase` / `change_id` / `written_by` / `L2_verdict` / `L3_verdict` / `artifacts`），其中 `L2_verdict` 为真实 L2 审查结论（`pass` 或 `fail`，从 review 文件提取），`L3_verdict=skipped`，`written_by=main-agent`。文件行数 ≥ 6 行，通过 `fk_validate_done_marker()` 校验。
- **验证方式**: `fk_validate_done_marker .specs/<id>/.independent-review-<N>.done <N> <id> transition` 返回 0（通过）；空 `touch .done` 返回 2（拒绝）

### AC-7 · L3-only 模式：`L2_verdict=skipped`（不是 `fail`）

- **Given** gate_config = "L3"（仅 L3），L2 段不存在于 `INDEPENDENT-REVIEW-<N>.md`
- **When** L3（Stop hook `29-independent-review.sh` 或 PreToolUse `independent-review-gate.sh`）调用 `l3_review_run()`
- **Then** L3 正常运行并写入 L3 段 + `.done`，其中 `.done` 的 `L2_verdict=skipped`（不是 `fail`），`L3_verdict` 为真实 L3 审查结论（`pass` 或 `fail`），`written_by=pre-tool-use-gate`（PreToolUse 路径）或 `written_by=stop-hook-29`（Stop hook 路径）。gate_config ≠ "both" 时 AC-1 的 L2-wait 检查不生效。
- **验证方式**: gate_config="L3" 时，`.done` 中 `grep -q 'L2_verdict=skipped'` → true；`grep -q 'L2_verdict=fail'` → false

### AC-8 · .done 真实性校验仍有效（三种模式均适用）

- **Given** 修复后的 L2-only / L3-only / both 三种模式各自的 `.done` 写入流程
- **When** `done-validation.sh` 的 `fk_validate_done_marker()` 对 `.done` 做真实性校验
- **Then** 三层校验通过：① 非空（≥6 行）② KVP 完整（phase/change_id/written_by/L2_verdict/L3_verdict/artifacts 全存在且值域合法）③ `written_by` 非空。`L2_verdict` 值域扩展为 `{pass, fail, skipped}`，`L3_verdict` 值域扩展为 `{pass, fail, timeout, error, skipped}`。空文件/假内容/跳过子进程三种威胁仍被拦截。
- **验证方式**: 现有 `test/` 中 .done 校验相关 bats 测试全部通过 + 新增 `skipped` 值域测试

---

## 范围切分

### v1（本次必做）

- 修复 `29-independent-review.sh`：gate_config="both" 时 L3 必须等 L2 完成（Gate 4 之前加 L2 完成检查）；gate_config="L3" 时 `l2_verdict` 默认值从 `fail` 改为 `skipped`
- 修复 `l3-review.sh` 的 `l3_review_run()`：gate_config="both" 且 L2 未完成时，不写 `.done`（仅写 L3 段到 review 文件，不写 done marker）；`L2_verdict` 值域扩展支持 `skipped`
- 验证 `done-validation.sh` 的 `fk_validate_done_marker()`：`L2_verdict` 值域已支持 `{pass, fail, skipped}`（line 137）、`L3_verdict` 已支持 `{pass, fail, timeout, error, skipped}`（line 139）——无需代码修改，bats 测试确认即可
- 修复各阶段 prompt（1/2/3/5/6/7）的 L2 调度段：子 agent 输出指令改为"追加写入"而非覆写；L2-only 模式的"写 done"段从 `touch .done` 改为写 6 键 KVP `.done`（含 `L3_verdict=skipped`）
- 修复 `L2-blind-review.md`：明确追加写入语义 + 检测已有 L3 段时保留
- bats 测试覆盖 AC-1~AC-8（含 L2-only / L3-only / both 三种模式的完整矩阵）

### v2（下一轮考虑，不本次）

- L2 子 agent 自动检测并合并已有 L3 段的智能逻辑（v1 靠 prompt 指令约束）
- `.done` 写入的分布式锁（防极端并发场景）
- L2/L3 执行时序的可视化仪表板

### out（永远不做）

- 不改变 gate_config 的开关机制本身
- 不改变 L2/L3 审查的内容生成逻辑
- 不引入新的审查层级（L4+）
- 不改变 `.done` 的 6 键 KVP 格式

---

## 非功能性需求

- **性能**: L3 前置调用（PreToolUse）延迟绝对值 ≤ 2s（当前基线 ≤ 30s timeout，新增 AC-1 的 L2 完成检查不引入额外网络调用，仅本地 grep 文件，增量 < 50ms）；Stop hook L3 调用行为不变
- **可访问性**: 无（非 UI 项目）
- **可靠性**: L2/L3 追加写入通过时序强制序列化（主 agent 等 L2 子 agent 完成 → transition → PreToolUse L3），L2 子 agent 单次 Write 调用为全量原子写入，无并发交错风险。极端并发场景（跨 session 的 Stop hook L3 与 L2 Write 竞态）概率极低，纳入 v2 分布式锁方案。
- **安全**: 无新增安全风险——不改动 API 鉴权、文件权限模型
- **兼容性**: 现有 `.done` 格式不变；`done-validation.sh` 三层校验向后兼容；仅含 L2 或仅含 L3 的旧 `.done` 文件在非 both 模式下仍有效
- **可观测性**: L3 跳过原因写入 stderr 日志（`[independent-review] L3 skipped (L2 not yet complete, gate_config=both)`）

## 依赖与假设

- 依赖 `l3-review.sh` 共享 lib 的现有 `>>` 追加逻辑（已正确，无需改动）
- 依赖 `done-validation.sh` 的 `fk_validate_done_marker()` 三层校验（已正确，无需改动）
- 假设 L2 子 agent 能遵循 prompt 中的"追加写入"指令（不假设子 agent 有特殊 tool 能力）
- 假设主 agent 在 `.done` 不存在时会重新派 L2/L3（现有行为不变）

---
> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
