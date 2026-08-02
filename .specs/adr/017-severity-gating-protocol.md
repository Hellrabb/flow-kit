# ADR-017: Severity Gating Protocol（标记格式 + Minor Deferred 文件路径）

**Status**: Proposed (superpowers-v6-absorb Phase 2)
**Date**: 2026-08-02
**Supersedes**: 无
**Superseded by**: 无

## Context

superpowers v6.0 SKILL.md L309-313 Severity Gating：只有 Critical / Important findings 进入 fix loop；Minor findings 记录在 ledger 中，最终审查时 triage。原文："Minor findings never enter the loop."

flow-kit 当前 review phase（6-review.md）已有 brooks-lint 的 🔴/🟡/🟢 色码概念，但：
- severity 标记格式未在 prompt 中强制
- Minor finding 也入 fix loop，单 task 被 style nit 卡住
- Minor 没有固定文件路径，散落在 REVIEW.md 或 T<N>-SUMMARY.md

L2 盲审（INDEPENDENT-REVIEW-1.md R4）要求：deferred 文件位置必须单一固定，不能"或 A 或 B"。本 ADR 锁定格式 + 路径。

## Decision

**Severity 标记格式 + Minor deferred 单一路径**：

### 1. Severity 标记格式（reviewer 输出强制）

每条 finding 必须含 markdown 行内 token：

```markdown
### 🔴 R1 · <风险名>：<一句话结论>
**Severity**: 🔴 Critical
**Symptom**: ...
**Source**: ...
**Consequence**: ...
**Remedy**: ...

### 🟡 R2 · ...

### 🟢 R3 · ...
```

格式约束：
- 标题行：`### <色码 emoji> R<x> · <风险名>：<一句话结论>`（与 L2-blind-review.md 既有格式一致）
- 正文必含 `**Severity**: 🔴/🟡/🟢 Critical/Important/Minor` 行
- 三个色码与 tier 一一对应：
  - 🔴 = Critical（必须 fix 才能进下阶段）
  - 🟡 = Important（入 fix loop，task 内解决）
  - 🟢 = Minor（不入 fix loop，写 MINOR-DEFERRED.md）

grep 校验：
- `grep -E "^\*\*Severity\*\*: (🔴 Critical|🟡 Important|🟢 Minor)" REVIEW.md`
- 命中数 = finding 数

### 2. Minor Deferred 单一固定路径

```
.specs/<id>/MINOR-DEFERRED.md
```

格式：
```markdown
# Minor Findings Deferred to Phase 7 Triage

> 本文件由 phase 6 review 写入，phase 7 integration 时 triage。
> 每条 Minor finding 含来源 task / 描述 / 建议处理方式。

| # | Task | Finding | Suggested Action |
|---|------|---------|------------------|
| M1 | T03 | src/foo.ts:42 命名 `tmp` 不够语义化 | 重命名为 `intermediateResult` |
| M2 | T03 | src/bar.ts 缺 JSDoc 注释 | 加 JSDoc |
```

写入时机：
- review phase 发现 Minor finding 时立即追加（不是事后批量）
- task_progress 数组的 `deferred` 字段记录对应 M 编号（与 ADR-015 schema 对齐）

### 3. Severity gating 行为矩阵

| Severity | 入 fix loop | 写 MINOR-DEFERRED.md | 写 task_progress.deferred | 阻塞 toll-gate |
|---|---|---|---|---|
| 🔴 Critical | 是（必须 fix 才能进下阶段） | 否（直接 fix） | 否（fix 后无 deferred） | 是（直到 fix） |
| 🟡 Important | 是（task 内解决） | 否（直接 fix） | 否（fix 后无 deferred） | 否（fix 即过） |
| 🟢 Minor | **否** | 是 | 是（记录 M 编号） | 否（永远不阻塞） |

### 4. 旧 REVIEW.md 向后兼容

旧 REVIEW.md（无 severity 标签）→ 解析器视为 Important（保守默认，AC-D3）。
此向后兼容针对：
- 既有未归档 change 的 REVIEW.md
- 第三方 brooks-lint 输出（如未升级）

## Consequences

**正面**：
- Minor 不卡 fix loop → 单 task 完成时间 -30%（实测 superpowers）
- severity 标记格式 grep 友好 → 可机械验证（bats / hook）
- 单一文件路径 → hook 层可 grep 存在性检查（未来扩展）
- 与 brooks-lint 既有色码一致 → 跨工具复用

**负面**：
- reviewer 必须严格执行 severity 标记 → 弱模型可能漏标
- Minor 不到 fix loop，可能在 phase 7 triage 时被忽视 → 重要 Minor 升级到 Important 需人工
- MINOR-DEFERRED.md 增加文件产物 → 略增管理负担

**Neutral**：
- brooks-lint 色码含义不变（🔴/🟡/🟢），仅是在 review prompt 中强制使用

**缓解**：
- ADR-001 protect-the-weakest：reviewer prompt 加 severity 标记自检 gate
- L2-blind-review.md checklist 加"每条 finding 必含 severity"
- AC-D3 向后兼容保证既有 REVIEW.md 不破坏 pipeline

**禁动约束**：
- severity 三档命名（Critical / Important / Minor）锁定，禁止扩展（如 Info / Trivial）
- 色码 emoji（🔴/🟡/🟢）锁定，禁止改其他 emoji
- MINOR-DEFERRED.md 路径锁定，禁止改路径或加等价路径（见 AC-D2）
- task_progress.deferred 字段类型锁定为字符串数组（M 编号列表），禁止改其他类型

## 触发条件

- 本 change 实施时（phase 4）：6-review.md 加 severity 强制 + Minor deferred 写入逻辑
- 本 change 实施时（phase 4）：L2-blind-review.md checklist 加 severity 校验
- 本 change 测试时（phase 5）：bats 测试 grep severity 标记 + MINOR-DEFERRED.md 存在性
- 后续 change review 重构时：必须保留 severity gating 协议
