# REQUIREMENT: 2026-07 健康修复

- **Change ID**: `health-fix-2026-07`
- **关联**: `@.specs/health-fix-2026-07/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我希望 `correction-file.sh` / `interactive-ui-check.sh` / `weak-model-compliance.sh` 之间无双向依赖，以便修改任一模块时不会级联破坏其他模块。
- **US-2**：作为 prompt 维护者，我希望 pipeline goal 解析逻辑只有一处定义，以便修改解析规则时只需改一个文件。
- **US-3**：作为 flow-kit 维护者，我希望 `flow-kit-artifacts.sh` 按职责拆分，以便定位和修改 artifact-check / auto-phase / done-validation 时互不干扰。
- **US-4**：作为打包脚本维护者，我希望 `validate_staging_coverage()` 独立于主打包流程，以便单独测试和维护校验逻辑。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 循环依赖消除 — 引用方向

- **Given** `flow-kit-bundle/hooks/stop/lib/` 下所有 `.sh` 文件
- **When** 用 grep 检查 `correction-file.sh`、`interactive-ui-check.sh`、`weak-model-compliance.sh` 之间的引用关系
- **Then** 引用方向为单向 DAG：无双向引用环（即不存在 A→B 且 B→A 的情况）
- **验证方式**: 脚本检查——对三个文件两两组合，`grep -c` 统计相互引用次数，任一组双方均 >0 则失败

### AC-2 · 循环依赖消除 — 测试无回归

- **Given** 重构后的 lib 模块
- **When** 运行 `make test`
- **Then** 全部 bats 测试通过（当前基线 53+ tests），无新增失败
- **验证方式**: `make test`

### AC-3 · jq 重复消除 — 单一来源

- **Given** 包含 pipeline goal 解析逻辑的共享 reference 文件（如 `flow-kit/reference/pipeline-goal-parser.md` 或 `.sh`）
- **When** 检查 `6-review.md` 和 `7-integration.md` 中的 goal 解析代码
- **Then** 两个 prompt 均引用同一共享文件，68 行 jq 代码块不出现在任一 prompt 正文中（引用替代逐字重复）
- **验证方式**: `grep -L "goal.*scope.*start_phase.*current_phase.*phases_done.*gates" flow-kit-bundle/flow-kit/prompts/6-review.md flow-kit-bundle/flow-kit/prompts/7-integration.md` 确认无内联 jq 块

### AC-4 · jq 重复消除 — 包完整性

- **Given** 新增的共享 reference 文件
- **When** 运行 `package-flow-kit.sh --validate`
- **Then** staging 覆盖率 100%，无漏配
- **验证方式**: `bash package-flow-kit.sh --validate`

### AC-5 · flow-kit-artifacts 拆分 — 职责分离

- **Given** 拆分后的子库（`artifact-check.sh` / `auto-phase.sh` / `done-validation.sh`）
- **When** source 这些子库并调用原有函数名
- **Then** 函数签名不变，原有调用方（29-independent-review / 00-gate / 33-flow-active-integrity）无需修改 source 路径（通过 `flow-kit-artifacts.sh` 作为聚合入口向后兼容）
- **验证方式**: `make test` 全过，且 `grep -rn "fk_artifact_check\|fk_auto_phase\|fk_validate_done_marker" flow-kit-bundle/hooks/stop/` 确认调用方代码无改动

### AC-6 · flow-kit-artifacts 拆分 — 包校验

- **Given** 新增的子库文件
- **When** 运行 `package-flow-kit.sh --validate`
- **Then** 新文件均在 staging 覆盖范围内
- **验证方式**: `bash package-flow-kit.sh --validate`

### AC-7 · package-flow-kit 拆分 — 函数独立

- **Given** 拆出的 `validate_staging_coverage()` 函数（独立文件 `flow-kit-bundle/lib/validate_staging.sh`）
- **When** 运行 `package-flow-kit.sh --validate` 和直接 source 新文件调用 `validate_staging_coverage`
- **Then** 两种方式输出一致，退出码一致
- **验证方式**: `diff <(bash package-flow-kit.sh --validate 2>&1) <(source lib/validate_staging.sh && validate_staging_coverage 2>&1)` — 无差异

### AC-8 · 全局 — 双源同步

- **Given** 所有改动在 `flow-kit-bundle/` 源文件中完成
- **When** 运行 `make check-test-sync`
- **Then** `test/` ↔ `flow-kit-bundle/test/` 一致
- **验证方式**: `make check-test-sync`

---

## 范围切分

### v1（本次必做）

- L-021：打破 correction-file / interactive-ui-check / weak-model-compliance 双向依赖（提取共享接口）
- TD-005：提取 jq pipeline goal 解析到共享 reference 文件，6-review + 7-integration 改为引用
- L-016：拆分 flow-kit-artifacts.sh 为 3 个子库（artifact-check / auto-phase / done-validation），保留聚合入口向后兼容
- L-017：从 package-flow-kit.sh 拆出 validate_staging_coverage() 为独立 lib

### v2（下一轮考虑，不本次）

- L-019：correction_file_write() 的 overwrite → merge 策略升级（已在 LESSONS.md 独立跟踪，不属本次）
- L-020：Stop hook 模块三处接线合并为单一注册源（已在 LESSONS.md 独立跟踪，不属本次）
- L-018：fk_accumulate_tokens 中 `updated_at` 双重赋值清理（顺手修，优先级低）

### out（永远不做）

- 重写整个 stop hook 执行链架构（00-gate → 99-report 编号顺序加载机制保持）
- 将 Bash 项目迁移到其他语言（如 Python/Node.js）
- 为 lib 模块引入类型系统或接口定义语言（Bash 项目，保持简洁）

---

## 非功能性需求

- **性能**: 无（lib 拆分不改变运行时路径，source 文件数量增加但均为一次性加载）
- **可访问性**: 无（非前端项目）
- **安全**: 无新增安全面
- **兼容性**: 向后兼容——所有现有调用方（stop hook 模块 27/28/29/33 号 + package-flow-kit.sh）无需修改 source 路径
- **可观测性**: 无新增日志/埋点要求

## 依赖与假设

- **依赖**: `make test` 依赖 bats-core 1.13.0（已安装）；`make check-test-sync` 依赖 diff
- **假设**: 拆分后的子库文件通过聚合入口（`flow-kit-artifacts.sh` source 子库后 re-export）保持向后兼容，调用方无需感知内部拆分
- **假设**: 循环依赖修复采用"提取共享类型/常量到新文件"模式，不改变函数的外部行为
- **假设**: `package-flow-kit.sh --validate` 的 staging 清单需随新增文件更新

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
