# CHANGE · cleanup-debt-batch-2026-08

> **变更类型**: 批量债务清理（5 项 LESSONS，4 个模块）
> **阶段**: 0-change · 2026-08-03
> **风险等级**: 🟡 中（涉及禁动清单 29 hook + 4-dev.md 大改）

---

## Why

5 项技术债积累至需独立 change 处理的临界点。它们跨 4 个模块（scripts/ + package-flow-kit.sh + hooks/ + prompts/），相互独立，但合并为一个 change 可减少 pipeline 开销：

- **L-068** 🔴: 4-dev.md 781 行 → 目标 ≤500 行。per-task reload 成本占 pipeline 总成本 ~40%（superpowers-v6-absorb 已识别），是 token 经济最大优化点。
- **L-069** 🟡: package-flow-kit.sh validate 报"M-health.md 漏配"，影响发布流程可信度。
- **L-070** 🟢: package-flow-kit.sh::validate 即使发现 error 也 exit 0，CI 假绿。
- **L-071** 🟡: scripts/review-package 不验证 git ref 合法性，"../../etc/passwd" 等输入返回空输出 + exit 0，路径遍历隐患（superpowers-absorb-followup-1 SEC-5b skip 的根因）。
- **L-072** 🟢: hooks/stop/29-independent-review.sh L3-model-missing 检测（line 59-64）短路在 L2-missing 检测（line 181-185）之前，导致 L2-only 环境下 L2-first 契约失效。

## What

### 5 个修复点

**L-071 review-package ref validation**（安全优先）:
- scripts/review-package 加 `git rev-parse --verify "<base>^{commit}"` + `git rev-parse --verify "<head>^{commit}"`
- 失败 → stderr + exit 1（与既有非 git 目录错误路径一致）
- 新 bats: test_scripts_security.bats 加 SEC-5b unsuppress（去掉 skip）+ 新增边界测试

**L-069 package validate M-health.md 漏配**:
- package-flow-kit.sh Part A-G 中找合适 Part 加 `flow-kit/prompts/M-health.md`
- 验证: `bash package-flow-kit.sh --validate` exit 0 无 ERROR

**L-070 package validate exit code**:
- validate_staging_coverage() 函数末尾：`[ "$ERROR_COUNT" -gt 0 ] && exit 1`
- 验证: 故意制造漏配 → exit 1（原为 0）

**L-072 29 hook reorder**:
- 将 L2-missing 检测段（line 181-185）移到 L3-model-missing 检测（line 59-64）**之前**
- L2-missing 检测的语义: "gate_config=both 但 ## L2 盲审段缺失" → 即使 L3 model 缺失也要先报 L2-missing
- **禁动清单 exception**: 需在 CONTEXT.md 禁动清单中为 29 hook L59-185 段加 exception 说明
- 新 bats: test-l2-first-correction.bats 补 AC-I(d) 测试 L3-model-missing 短路被 L2-missing 优先的场景

**L-068 4-dev.md 压缩**:
- 781 → ≤500 行（-36%）
- 抽取到 reference/ 的段落:
  - `reference/tdd-workflow.md`（新）: 1.4-1.7 TDD 红绿循环 + 1.8 破坏性变更 + grep-before-code
  - `reference/commit-protocol.md`（新）: 5-submit + 5 段提交协议
  - `reference/checkpoint-protocol.md`（新）: 8-checkpoint + checkpoint_write() 用法
- 4-dev.md 保留: 入场路由 + task-brief/model-tier/task_progress 调用 + 6-submit 极简版（指向 reference/）+ checkpoint 单行触发
- 向后兼容: 既有 4-dev.md 段落标题保留 grep anchor（避免既有回归测试 fail）

### 不做

- 不改 hook 链其他模块（仅 29 hook 重排）
- 不改 GO.md（已在 superpowers-v6-absorb 压缩）
- 不重写 ADR
- 不改 CONTEXT.md 禁动清单整体（仅加 exception 段）
- 不修 L-058/060/062（archived change 文档 lessons，无须改 archive）
- 不修 L-063/066（需要 live weak model data）

## 影响面

- **测试**: +3~5 新 bats 测试，1 测试 unsuppress（SEC-5b）
- **既有测试**: test_scripts_security.bats SEC-5a 保持 pass；SEC-5b 改为 active 测试
- **CONTEXT.md**: 禁动清单加 29 hook L59-185 exception 段
- **bundle 同步**: 所有改动同时反映到 flow-kit-bundle/
- **回归**: package --validate 应从 ⚠️ → ✅，全量 bats 仍 0 fail

## 范围排除

- 不动 L1-L3 review 哲学
- 不引入 superpowers 周边 scripts
- 不改 gate_config schema
- 不改 brooks-lint
- 不重写 13 既有 ADR

## 验收线

1. ✅ review-package: bad ref → exit 1 + stderr
2. ✅ package --validate: 0 errors, exit 0
3. ✅ package --validate: 故意漏配 → exit 1
4. ✅ 29 hook: L2-missing 优先于 L3-model-missing（test AC-I(d) pass）
5. ✅ 4-dev.md: ≤500 行
6. ✅ 4-dev.md: grep anchors 保留（既有测试不退化）
7. ✅ 全量 bats: 0 fail（target 660+/660+）
8. ✅ dual-source sync: 0 diff

## 风险与未知

- **R1** L-072 重排 29 hook 逻辑顺序可能触发既有未发现的边界场景（mitigation: 全量回归 + 既有 AC-I 测试覆盖）
- **R2** L-068 抽取 reference 片段若 4-dev.md 入场引用方式不当，弱模型可能跳读（mitigation: 4-dev.md 入场明确列出 `@see reference/X.md` + 片段摘要）
- **R3** L-070 validate exit code 改为非零后，既有 CI 假设（如有的话）会破坏（mitigation: 现无 CI，仅本地影响）
- **R4** L-069 M-health.md 在哪个 Part 加入有歧义（Part B prompts vs Part F health 目录），DESIGN 阶段裁定
- **R5** gate_config=all 在 OpenCode 无 ANTHROPIC API 环境下 L3 不可用，预期第一次 Stop hook 28 触发 l3-model-missing correction 后降级为 L2-only（与 superpowers-v6-absorb 同处理方式）

## 与 superpowers-v6-absorb / superpowers-absorb-followup-1 的关系

- 继承 superpowers-v6-absorb 的 4-dev.md 改造（task-brief/model-tier/task_progress）
- 修复 superpowers-absorb-followup-1 SEC-5b skip 的根因（L-071）
- 不冲突，可独立 merge

---

> Phase 0 自检：✅ 反问已通过（用户明确"全部修完"） · ✅ 影响面识别 · ✅ 范围排除 · ✅ 风险列出
