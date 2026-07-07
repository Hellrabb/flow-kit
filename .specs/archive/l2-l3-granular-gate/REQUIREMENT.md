# REQUIREMENT: L2/L3 独立审查开关拆分

- **Change ID**: `l2-l3-granular-gate`
- **关联**: `@.specs/l2-l3-granular-gate/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，在慢系统上我只想跑 L2（同会话子 agent 盲审，零额外耗时），跳过 L3（外部 API 调用），以加速 pipeline 迭代。
- **US-2**：作为 flow-kit 用户，我只想跑 L3（外部模型盲审，不同视角交叉验证），跳过 L2（不额外消耗子 agent token）。
- **US-3**：作为 flow-kit 维护者，已有的 `"independent"` 值和 `--gate-config review` 预设行为不能变（向后兼容）。

## 验收准则（AC）

### AC-1 · L2-only 模式

- **Given** `.flow-active.goal.gate_config["6-review"] = "L2"`
- **When** 主 AI 在 6-review 阶段读取 gate_config 并判定 L2 开关
- **Then** L2 子 agent 盲审正常调度；L3（29 号 Stop hook）检测到只开了 L2，跳过不跑
- **验证方式**: 单元测试——`fk_independent_review_gate_active "6" "L2"` 返回 0（L2 gate 生效）；`fk_independent_review_gate_active "6" "L3"` 返回 1（L3 gate 未开启）

### AC-2 · L3-only 模式

- **Given** `.flow-active.goal.gate_config["6-review"] = "L3"`
- **When** 主 AI 进入 6-review 阶段
- **Then** L2 调度段检测到仅 L3 开启，跳过子 agent spawn；29 号 Stop hook 检测到 L3 开启，正常跑外部模型盲审
- **验证方式**: 单元测试——`fk_independent_review_gate_active "6" "L3"` 返回 0；`fk_independent_review_gate_active "6" "L2"` 返回 1

### AC-3 · both 模式（向后兼容）

- **Given** `gate_config["6-review"]` = `"both"` 或 `"independent"` 或 `"true"`
- **When** 主 AI 和 29 号 hook 分别检测
- **Then** L2 和 L3 均正常执行（与当前行为一致）
- **验证方式**: `"independent"` 和 `"true"` 在 `fk_independent_review_gate_active` 中被映射为 both；现有 309 bats 无回归

### AC-4 · flow skill 预设兼容

- **Given** 用户执行 `/flow goal "test" --pipeline --gate-config review`
- **When** flow skill 解析 `review` 预设名
- **Then** `gate_config["6-review"]` 写入 `"both"`（非 `"independent"`）；老预设名（review/full/all/code-only 等）行为不变
- **验证方式**: `.flow-active` 中 `gate_config["6-review"]` 值为 `"both"`

### AC-5 · 新 flag 支持

- **Given** 用户执行 `/flow goal "test" --pipeline --gate-config review --l2-only`
- **When** flow skill 处理
- **Then** `gate_config["6-review"]` = `"L2"`（覆盖预设的 both）
- **验证方式**: `.flow-active` 中 gate_config 值为 `"L2"`

### AC-6 · 29 号 hook L3 开关检测

- **Given** `gate_config["6-review"] = "L2"`（仅 L2 开）
- **When** Stop 事件触发 29 号 hook
- **Then** 29 号检测到 L3 未开启，跳过外部模型调用，不写 INDEPENDENT-REVIEW L3 段
- **验证方式**: bats 测试——模拟 29 号 hook 执行，验证 L3 段未写入

### AC-7 · gate 拦截 done 判定适配

- **Given** `gate_config["6-review"] = "L2"`（仅 L2）
- **When** PreToolUse hook 检查 done 标志
- **Then** 仅检查 L2 done（INDEPENDENT-REVIEW-6.md 含 L2 段），不要求 L3 done
- **验证方式**: `independent-review-gate.sh` 的 done 检查逻辑按 tier 判定

### AC-8 · 全链路无回归

- **Given** 所有改动完成
- **When** 运行 `make test`
- **Then** 全部 bats 测试通过（≥309 tests），新增 L2/L3 开关相关测试覆盖三种模式
- **验证方式**: `make test`

---

## 范围切分

### v1（本次必做）

- `done-validation.sh`：`fk_independent_review_gate_active()` 新增 tier 参数（`"L2"`/`"L3"`），`"independent"`/`"true"` → both 映射
- `29-independent-review.sh`：读取 gate_config 判定 L3 是否开启
- `independent-review-gate.sh`：done 检查按 tier 判定（L2-only 只要求 L2 done）
- `flow` skill（`/flow goal --gate-config`）：新增 `--l2-only` / `--l3-only` flag，预设默认写 `"both"`，三值校验
- 6 个阶段 prompt 的「独立 review 调度」段：L2 开关判定逻辑更新
- bats 测试：覆盖 L2-only / L3-only / both 三种模式

### v2（下一轮考虑）

- `stop-hook.json` 持久化配置也支持 `"L2"` / `"L3"` 值（当前仅改 gate_config 运行时值）
- `/flow gate-config` 子命令支持 `--l2-only` / `--l3-only`

### out（永远不做）

- 改变 L2 盲审 prompt 内容（`L2-blind-review.md` 不变）
- 改变 L3 外部模型选择逻辑（模型配置不变）
- 改变 done 标志文件格式（KVP 不变）

---

## 非功能性需求

- **性能**: L2-only 模式不应触发外部 API 调用（零额外网络延迟）
- **兼容性**: `"independent"` / `"true"` 值完全向后兼容，已有 `.flow-active` 文件无需迁移
- **安全**: 无新增安全面
- **可观测性**: 29 号 hook 日志中注明"L3 skipped (gate_config=L2)"或"L3 running"

## 依赖与假设

- **依赖**: `done-validation.sh`（已拆分）、`29-independent-review.sh`、`independent-review-gate.sh`、`flow` skill
- **假设**: gate_config 值仅在 `.flow-active` 中设置（不涉及 `stop-hook.json` 格式变更，v1 范围）
- **假设**: prompt L2 调度段读取 gate_config 的方式与 `fk_independent_review_gate_active` 一致
