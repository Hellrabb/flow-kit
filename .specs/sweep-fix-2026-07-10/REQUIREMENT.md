# REQUIREMENT: 2026-07-10 Full Sweep 统一清理

- **Change ID**: `sweep-fix-2026-07-10`
- **关联**: `@.specs/sweep-fix-2026-07-10/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想拆分 `l3_review_run()` 和 `is_gh_pr_create()` 两个超长函数，以便降低单函数认知负荷，任一环节变更只需理解对应子函数。
- **US-2**：作为 hook 开发者，我想用统一的 `run_check()` 包装函数替代手写 check 模板，以便新增 check 时只需一行调用，不再手工复制 30-50 行模板。
- **US-3**：作为项目维护者，我想清理 `write_failed_state` 死代码并评估 `_grep` 兼容层去留，以便减少 18 个 source 文件的认知负担。
- **US-4**：作为 flow-kit 使用者/贡献者，我想命名约定有文档可查，以便从函数名推断其模块归属和可见性（公共 API vs 私有内部函数）。
- **US-5**：作为 flow-kit 开发者，我想安装函数有 DRY_RUN 单元测试覆盖，以便修改安装逻辑时快速获得反馈。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · l3_review_run() 函数拆分

- **Given** `flow-kit-bundle/hooks/stop/lib/l3-review.sh` 中 `l3_review_run()` 为 307 行单一函数，承担 prompt 构造 + API 调用 + 结果解析 + .done 写入 + 错误降级 5 项职责
- **When** 按职责拆分为 `_l3_build_prompt()` / `_l3_call_api()` / `_l3_parse_result()` / `_l3_write_done()` 4 个子函数 + `l3_review_run()` 编排器
- **Then** 编排器 `l3_review_run()` ≤ 50 行；每个子函数 ≤ 80 行；现有 2 处调用方（`independent-review-gate.sh` + `29-independent-review.sh`）行为不变
- **验证方式**: `wc -l` 检查行数 + `npx bats test/` 全绿（回归验证）

### AC-2 · independent-review-gate.sh 主逻辑体重构

- **Given** `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 主入口逻辑块（L106-391，~285 行）含 7 个 gate 检查（path-guard / phase-filter / active-check / done-validation / tamper-detect / phase-transition / deny-reason）混合为无名代码块；`is_gh_pr_create()`（3 行谓词）、`is_phase_write()`（18 行）、`is_git_commit()`（2 行）均为简洁的单一职责函数，不参与拆分
- **When** 提取各 gate 检查为 `_gate_*` 命名函数 + 新增编排器 `_run_review_gates()`
- **Then** `_run_review_gates()` ≤ 40 行；≥ 7 个独立 `_gate_*` 函数；`is_gh_pr_create()` / `is_phase_write()` / `is_git_commit()` 保持不变；PreToolUse 关键路径行为不变（每次 tool call 触发，执行时间不增加）
- **验证方式**: `wc -l` 检查行数 + `npx bats test/` 全绿 + 新增 bats 测试验证 `_run_review_gates` 在独立审查场景返回 0、非审查场景返回非零（Given: 模拟 tool call 上下文 / When: 调用 `_run_review_gates` / Then: exit code 符合预期）

### AC-3 · check_* 统一包装函数 run_check()

- **Given** 6 个 Stop hook 模块（`21,22,23,24,25,26-*.sh`）中 `check_*` 函数模板逐字重复——每个 check 含 `check_enabled` guard → 读状态 → 检查条件 → `module_output` 四段样板，20+ 处执行模式相同仅条件表达式不同
- **When** 引入 `run_check(name, enabled_check, condition, message)` 包装函数，各模块 check_* 改为调用 `run_check()`
- **Then** 各模块手写 check 模板消除；新增 check 只需一行 `run_check()` 调用；现有 hook 行为不变；全量 bats 全绿
- **验证方式**: 各 `2*-*.sh` 中 `check_enabled` 直接调用全部消除，改为经 `run_check()` 间接调用；`grep -c "check_enabled" flow-kit-bundle/hooks/stop/2*-*.sh` 返回 ≤ 1（仅 `run_check()` 自身定义体中的调用）；`npx bats test/` 全绿 + 新增 check 去重测试 ≥ 2 条

### AC-4 · write_failed_state 死代码清理

- **Given** `flow-kit-bundle/hooks/stop/lib/common.sh:139-159` 定义 `write_failed_state()` 但全仓 0 调用（确认死代码）；CONTEXT.md 既有抽象索引已标注"待清理"
- **When** 移除 `write_failed_state` 函数定义 + 更新 CONTEXT.md TD-020 条目标记 ✅
- **Then** `grep -r "write_failed_state" flow-kit-bundle/` 无命中（除 CONTEXT.md 历史记录行）
- **验证方式**: `grep -r "write_failed_state" flow-kit-bundle/` 返回空或仅 CONTEXT.md 历史注释

### AC-5 · 命名约定文档化

- **Given** 项目存在 5 种命名前缀（`fk_` / `_fk_` / `check_` / `l2_`/`l3_` / `_fai_`）但无文档说明各自使用场景和可见性规则
- **When** 在 CONTEXT.md 补充「命名约定」段，明确每种前缀的含义、可见性（公共 API / 模块私有 / 文件私有）和使用场景
- **Then** CONTEXT.md 命名约定段完整描述 5 种前缀（`fk_` / `_fk_` / `check_` / `l2_`/`l3_` / `_fai_`）各自含义、可见性层级（公共 API / 模块私有 / 文件私有）、典型使用场景；每种前缀 ≥ 1 条说明
- **验证方式**: `grep -cE "(fk_|_fk_|check_|l2_|l3_|_fai_)" .specs/CONTEXT.md` 在命名约定段命中 ≥ 5 条说明

### AC-6 · _grep 兼容层评估

- **Given** 项目存在 `_grep` 兼容层代码（对 ugrep 的封装）
- **When** 检测当前环境 ugrep 是否已安装且功能兼容（`ugrep --version` + 关键 flag 兼容性验证）
- **Then** 输出评估结论 + 决策标注：评估结论写入 CONTEXT.md（长期文档），同时在 CHANGE.md 中标注决策概要 + 如移除则执行清理并 grep 确认无残留
- **验证方式**: 评估结论在 CONTEXT.md 中可见；`grep -r "_grep" .specs/CONTEXT.md` 命中决策标注行

### AC-7 · 安装函数 DRY_RUN 测试

- **Given** `install_brooks_lint()` 152 行 + `install_hooks()` 199 行，0 直接单元测试（仅集成覆盖）
- **When** 添加 DRY_RUN 模式 bats 测试（`test/test_install_dry_run.bats`）
- **Then** 验证 DRY_RUN=1 不产生文件系统副作用（无新文件/目录/软链）；验证 DRY_RUN 输出包含预期关键消息（如 `[DRY_RUN]` 前缀）；≥ 4 条测试
- **验证方式**: `npx bats test/test_install_dry_run.bats` 全绿

### AC-8 · 全量回归

- **Given** AC-1 ~ AC-7 所有改动完成
- **When** 运行全量 bats 测试套件
- **Then** 全量 bats 测试全绿 0 fail；`make test` exit 0
- **验证方式**: `make test` 或 `npx bats test/` 输出 `0 failures`

---

## 范围切分

### v1（本次必做）

- AC-1 `l3_review_run()` 拆分为 4 子函数 + 编排器
- AC-2 `is_gh_pr_create()` 拆分为 `_gate_*` 函数 + 重命名 `_run_review_gates()`
- AC-3 引入 `run_check()` 包装函数，消除 6 模块 check_* 模板重复
- AC-4 移除 `write_failed_state` 死代码 + 更新 CONTEXT.md
- AC-5 CONTEXT.md 补充命名约定段
- AC-6 `_grep` 兼容层评估 + 去留决策标注
- AC-7 安装函数 DRY_RUN bats 测试 ≥ 4 条
- AC-8 全量 462 bats 回归 0 fail

### v2（下一轮考虑，不本次）

- 命名约定代码落地：按 AC-5 文档规则批量重命名现有函数（如 `_fai_*` → 统一前缀）
- TD-008 `l3-review.sh` 按职责拆文件（574 行 6 函数拆为 `l3-detect.sh` / `l3-dispatch.sh` / `l3-truncate.sh`）
- DRY_RUN 测试扩展：覆盖更多安装场景（如部分安装、重复安装）

### out（永远不做）

- CONTEXT.md「既有抽象索引」全量审计——范围太大，留给周期性 A-evolve
- `install_hooks()` / `install_brooks_lint()` 函数体进一步拆分——线性安装步骤，拆分收益低
- `l3-review.sh` 拆为多文件——与 TD-008 一并在独立 change 处理

---

## 非功能性需求

- **性能**: TD-018（`is_gh_pr_create` → `_run_review_gates()`）位于 PreToolUse 关键路径（每次 tool call 触发），拆分后执行时间不得增加（允许 ±5% 误差）。验证方式：拆分前后各跑 10 次 `time bash -c 'source independent-review-gate.sh && _run_review_gates'` 取中位数对比。TD-017（`l3_review_run` 拆分）不在热路径上（仅 L3 review 阶段触发），无性能约束
- **兼容性**: `l3_review_run()` 被 2 处 source 调用（`independent-review-gate.sh` + `29-independent-review.sh`），拆分后接口签名不变；`is_gh_pr_create()` 重命名为 `_run_review_gates()`——需 `grep -r "is_gh_pr_create" flow-kit-bundle/` 确认调用方仅限于 `independent-review-gate.sh` 自身；若存在外部调用方，需保留兼容别名 `is_gh_pr_create() { _run_review_gates "$@"; }` 作为过渡；`run_check()` 包装函数向后兼容——各模块现有 check 行为不变
- **安全**: 无
- **可访问性**: 无（非 UI 项目）
- **可观测性**: 无新增日志/埋点需求

## 依赖与假设

- **依赖**: ugrep 已安装（AC-6 评估前提）；bats-core 1.13.0（AC-7/8 测试框架）；现有 462 bats 基线全绿（AC-8 回归基线）
- **假设**: `l3_review_run()` 4 子函数拆分边界按 CHANGE.md 提议（prompt 构造 / API 调用 / 结果解析 / .done 写入）；`run_check()` 包装函数签名按模块分组（各模块参数结构相同，仅条件表达式和消息不同）；DRY_RUN 由环境变量 `DRY_RUN=1` 控制（沿用现有模式）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
