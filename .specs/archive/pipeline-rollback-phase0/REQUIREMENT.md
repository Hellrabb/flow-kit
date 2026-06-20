# REQUIREMENT: Pipeline 回退协议扩展到 0-3 规划阶段（智能回退方案 C）

- **Change ID**: pipeline-rollback-phase0
- **关联**: `@.specs/pipeline-rollback-phase0/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/health/2026-06-20-HEALTH.md`

---

## 用户故事

- **US-1**：作为 `--from 0` pipeline 用户，当 5/6/7 失败时，我想看到根据失败类型智能建议的回退目标（而非一律回 4），以便根因在规划层时能正确退回需求/设计/任务阶段。
- **US-2**：作为 `--from 4` pipeline 用户（默认），我希望失败回退行为与现状完全一致（默认建议回 4），不受本次扩展影响。
- **US-3**：作为 pipeline 用户，当失败根因在规划层时，我想能手动选择回退到 0-3 的任意已完成规划阶段。
- **US-4**：作为 flow-kit 维护者，我想让 5/6/7 的回退 jq 通用化（接受目标阶段参数），以便回退逻辑不再硬编码 `"4"`。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 失败分类表（5/6/7 三 prompt 内嵌）

- **Given** `flow-kit-bundle/flow-kit/prompts/5-test.md` / `6-review.md` / `7-integration.md`
- **When** 读取 pipeline rollback 段
- **Then** 三个 prompt 均含一张「失败现象 → 建议回退阶段」映射表，覆盖至少 4 类失败：代码 bug→4 / AC 错误→1 / 架构缺陷→2 / 任务遗漏→3，外加「其他→默认 4」兜底
- **验证方式**: `grep -c '失败.*分类\|失败现象\|建议回退' <prompt>` 每个 prompt ≥ 1

### AC-2 · 动态回退目标列表（基于 start_phase）

- **Given** pipeline goal 的 `start_phase` 字段
- **When** 5/6/7 失败展示回退选项
- **Then** 可回退阶段列表从 `start_phase` 到当前阶段动态生成：`--from 4` 时仅可回退到 4；`--from 0` 时可回退到 0/1/2/3/4
- **验证方式**: 三个 prompt 均含「可回退阶段 = [start_phase .. 当前阶段-1]」的说明 + jq 模板生成范围

### AC-3 · 回退 jq 通用化

- **Given** 5/6/7 当前的硬编码回退 jq（如 `current_phase = "4" | phases_done -= ["5"]`）
- **When** 改造后
- **Then** 回退 jq 接受目标阶段参数 `$TARGET`：`current_phase = $TARGET | phases_done -= [<当前阶段..7 的已完成阶段>]`，不再硬编码 `"4"`
- **验证方式**: 模拟回退到不同目标（4/2/1）的 jq 表达式，验证 phases_done 正确移除目标之后的阶段

### AC-4 · 向后兼容（--from 4 默认回 4）

- **Given** `--from 4`（默认）启动的 pipeline
- **When** 5/6/7 失败
- **Then** 失败分类表的默认建议仍是「回退到 4-dev」，动态回退列表仅含 4，行为与改造前完全一致
- **验证方式**: 构造 start_phase=4 的 goal，验证可回退阶段仅 ["4"]

### AC-5 · 新增回退逻辑测试

- **Given** `test/test_pipeline_rollback.bats`（新增）
- **When** 运行该测试文件
- **Then** 覆盖：① 动态回退目标列表生成（--from 0/4 两种）② 通用回退 jq 对不同目标阶段的 phases_done 移除 ③ 回退到规划阶段（start_phase=0 时回退到 2）④ 向后兼容（start_phase=4 时回退下界为 4）
- **验证方式**: `npx bats test/test_pipeline_rollback.bats` 新增测试全 ok

### AC-6 · 全量回归

- **Given** 所有改动已应用
- **When** 运行 `npx bats test/`
- **Then** 0 fail，0 skip，总数 ≥ 59（在现有基础上增加）
- **验证方式**: `npx bats test/` 无 not ok

---

## 范围切分

### v1（本次必做）

- AC-1: 5/6/7 三 prompt 内嵌失败分类表
- AC-2: 动态回退目标列表（读 start_phase）
- AC-3: 回退 jq 通用化（$TARGET 参数）
- AC-4: 向后兼容（--from 4 行为不变）
- AC-5: 新增 test_pipeline_rollback.bats
- AC-6: 全量回归

### v2（下一轮考虑，不本次）

- 程序化失败分类器（脚本读测试输出/review 结果自动分类，而非 AI 按表判断）
- 回退到 0-3 后规划阶段 prompt 的「回退感知」（标注「这是 rollback 来的」）
- 回退次数限制（防回退死循环，当前 R2.6 的 3 轮重试限制仅针对重试，不含回退）

### out（永远不做）

- 不做非线性回退（不支持从 5 跳过 4 直接回 2，回退总是连续退到目标，中间阶段标记 skipped）
- 不改 toll-gate 暂停-确认模型本身
- 不改 4-dev.md 的 rollback（4 是回退终点，无下游）

---

## 非功能性需求

- **性能**: 无（prompt 内嵌表格 + jq 微调）
- **可访问性**: 无
- **安全**: 无（回退目标经 jq --arg 安全传参）
- **兼容性**:
  - `--from 4`（默认）回退行为完全不变（AC-4）
  - 旧 pipeline goal（无 start_phase）回读时，回退下界 fallback 到 "4"
  - 依赖：jq（已有）、bats（已有）
- **可观测性**: 失败分类表需明确标注「默认建议」，AI 执行时给出建议 + 允许手动覆盖

## 依赖与假设

- **依赖**: `goal-pipeline-phase0` 已交付的 `start_phase` 字段
- **依赖**: `fix-pipeline-rollback` 已建立的 AC-10 rollback 基础（本 change 在其上扩展）
- **假设**: 失败分类由 prompt 驱动的 AI 判断（读失败现象 → 查表 → 建议），不需要程序自动分类
- **假设**: 回退 jq 通用化后，AI 能正确构造 `$TARGET` 参数（prompt 给出明确 jq 模板）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
