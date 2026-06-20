# REQUIREMENT: 修复 pipeline toll-gate 阶段跳过漏洞

- **Change ID**: phase-skip-fix
- **关联**: `@.specs/phase-skip-fix/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit pipeline 用户，我想让系统在推进到下一阶段前强制验证当前阶段产物已产出，以便 pipeline 不会静默跳过未完成的工作。
- **US-2**：作为 flow-kit 维护者，我想在 GO.md 路由层有一道独立的产物检查门禁，以便即使 prompt 指令被 AI 忽略，路由层仍能拦截未完成的状态转移。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 所有阶段 prompt 包含完成自检段

- **Given** flow-kit 已安装，各阶段 prompt 文件存在
- **When** 检查 `flow-kit/prompts/{1-requirement,2-design,3-task,4-dev,5-test,6-review,7-integration}.md`
- **Then** 每个文件在 Pipeline Toll-Gate 段之前包含「阶段完成自检（Phase Completion Self-Check）」标题
- **Then** 每个自检段包含：产物清单表格（文件名 + ✅/❌ 标记）、阻断规则（任一 ❌ → 禁止进入 toll-gate）、auto_advance 分支（auto_advance=true 时仍跑自检；全 ✅ 自动 transition；有 ❌ 则暂停告警）
- **验证方式**: `grep -c "Phase Completion Self-Check" flow-kit/prompts/*.md` 返回 ≥ 7

### AC-2 · 自检段阻断规则明确

- **Given** 任一阶段 prompt 的自检段
- **When** 自检结果中存在 ❌ 项
- **Then** AI 被明确指令「禁止进入 toll-gate」并要求「先完成缺失项后重新自检」
- **验证方式**: `grep -l "禁止进入 toll-gate\|禁止.*toll-gate\|DO NOT proceed to toll-gate" flow-kit/prompts/*.md` 覆盖全部 7 个 prompt

### AC-3 · auto_advance 模式下自检仍执行

- **Given** `.flow-active.goal.auto_advance = true`，当前阶段为 5-test
- **When** AI 完成测试工作后，在执行 transition jq 之前
- **Then** 必须先跑产物自检：全 ✅ → 自动执行 transition（跳过人工确认）；有 ❌ → 暂停 pipeline，输出缺失清单，等待用户决定
- **验证方式**: `grep "auto_advance" flow-kit/prompts/5-test.md` 的输出包含自检相关逻辑；`grep "auto_advance" flow-kit/prompts/6-review.md` 同理

### AC-4 · GO.md 包含 Phase Completion Gate

- **Given** flow-kit GO.md 已更新
- **When** AI 请求路由到 phase N+1（N ∈ {0,1,2,3,4,5,6}），且当前 `.flow-active.goal.scope = "pipeline"`
- **Then** GO.md 在加载下一阶段 prompt 之前，检查 phase N 的必须产物是否存在于 `.specs/<change-id>/` 目录
- **Then** 产物完整 → 放行，加载下一阶段 prompt
- **Then** 产物缺失 → 拒绝路由，输出缺失清单 + 「请回 phase N 补齐」提示
- **验证方式**: `grep -c "Phase Completion Gate" GO.md` 返回 ≥ 1；GO.md 中 Phase Completion Gate 段包含各阶段必须产物的清单表

### AC-5 · Phase Completion Gate 产物清单与 prompt 自检段一致

- **Given** GO.md Phase Completion Gate 和 prompt 自检段
- **When** 对比同一阶段的产物清单
- **Then** 两份清单必须一致（同一阶段不能出现 GO.md 要求 A 但 prompt 自检段列 B 的情况）
- **验证方式**: 人工 review + bats 测试验证 GO.md 产物清单中的每个阶段至少包含关键产物文件名

### AC-6 · TD-003 修复：5/6/7 入场 jq 补全 start_phase

- **Given** 5-test.md / 6-review.md / 7-integration.md 的 Pipeline Goal 入场检测段
- **When** 读取入场 jq 命令
- **Then** 包含 `start_phase // "4"` fallback（与 GO.md 和 4-dev.md 保持一致）
- **验证方式**: `grep "start_phase" flow-kit/prompts/5-test.md flow-kit/prompts/6-review.md flow-kit/prompts/7-integration.md` 均返回匹配

### AC-7 · 全量 bats 测试通过

- **Given** 新增测试已写入 `test/` 目录
- **When** 执行 `npx bats test/`
- **Then** 退出码为 0，所有测试通过（含新增的 toll-gate 自检段测试 + GO.md Phase Completion Gate 测试）
- **验证方式**: `npx bats test/`

---

## 范围切分

### v1（本次必做）

- 为 7 个阶段 prompt（1~7）添加 Phase Completion Self-Check 段
- GO.md 添加 Phase Completion Gate（路由层产物检查）
- auto_advance 模式下保留自检逻辑
- TD-003 修复（5/6/7 入场 jq 补 start_phase）
- CONTEXT.md 术语更新
- 新增 bats 测试（≥ 5 个新 test case）
- 全量测试通过 + 重新打包 + 提交归档

### v2（下一轮考虑，不本次）

- 外部 Stop Hook / SessionStart Hook 做三层防线（hook 脚本级产物检查）—— 当前双层防护已足够
- 产物完整性 hash 校验（防止 AI 创建空文件绕过检查）
- 跨 change 的 pipeline 统计面板（展示各阶段跳过率 / 回退率）

### out（永远不做）

- 全自动 CI/CD 流水线集成（flow-kit 是 prompt 驱动工具，不适配 CI runner）
- 阶段执行时间限制（timeout）—— prompt 层无法实现精确计时

---

## 非功能性需求

- **性能**: 无（纯 prompt 文本修改 + bats 测试，无运行时性能影响）
- **可访问性**: 无
- **安全**: 无
- **兼容性**: 向后兼容——旧 pipeline goal（无 start_phase / 无 auto_advance）行为不变；新增自检段不影响非 pipeline 模式
- **可观测性**: 自检段输出包含 ✅/❌ 表格，GO.md Phase Completion Gate 输出缺失产物清单，均为人类可读

## 依赖与假设

- **依赖**: `jq` ≥ 1.6（已在用）、`bats-core` 1.13.0（已安装）
- **假设**: 各阶段产物文件名和路径约定不变（如 `.specs/<id>/TEST.md`）
- **假设**: GO.md 路由时 `.flow-active` 的 `change_id` 已正确设置（非 null）
- **假设**: `--from 0` pipeline 的 1/2/3 阶段 prompt 已有 toll-gate 段（已确认存在），只需在其之前插入自检段

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
