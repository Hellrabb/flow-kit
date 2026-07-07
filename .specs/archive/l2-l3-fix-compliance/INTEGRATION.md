# INTEGRATION: L2/L3 review 发现强制代码修复

- **Change ID**: l2-l3-fix-compliance
- **归档日期**: 2026-07-07
- **关联**: 全部 `.specs/l2-l3-fix-compliance/` 产物

---

## 产物清单

| 文件 | 大小 | 状态 |
|---|---|---|
| CHANGE.md | 3.4K | ✅ |
| REQUIREMENT.md | 9.1K | ✅ |
| DESIGN.md | 19.3K | ✅ |
| TASK.md | 11.8K | ✅ |
| TEST.md | 4.7K | ✅ |
| REVIEW.md | 3.7K | ✅ |
| INDEPENDENT-REVIEW-{1,2,3,5,6}.md | — | ✅ 5/5 |
| .independent-review-{1,2,3,5,6}.done | — | ✅ 5/5 |

## 变更摘要

**2 新文件**:
- `flow-kit-bundle/hooks/stop/lib/fix-compliance.sh` — 实效性校验 lib（298 行）
- `flow-kit-bundle/test/test_l2_l3_fix_compliance.bats` — 26 bats tests

**5 修改文件**:
- `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` — +24 行（实效性校验插入点）
- `flow-kit-bundle/flow-kit/prompts/5-test.md` — +18 行（修代码优先协议）
- `flow-kit-bundle/flow-kit/prompts/6-review.md` — +19 行
- `flow-kit-bundle/flow-kit/prompts/7-integration.md` — +20 行
- `flow-kit-bundle/flow-kit/prompts/independent/L2-blind-review.md` — +9 行

**上下文更新**:
- `.specs/CONTEXT.md` — +6 术语 +1 决策

## AC 验收

| AC | 状态 |
|---|---|
| AC-1 Prompt 协议 | ✅ 4/4 文件含 `Fixed in:` |
| AC-2 纯文档检测 | ✅ 26 bats pass |
| AC-2a 源码发现分类 | ✅ 三级判定规则实现 |
| AC-2b 逐发现文件校验 | ✅ ≥50% MISSING→阻断 |
| AC-3 双层共存 | ✅ 现有 gate tests 34/34 pass |
| AC-4 技术债滥用防护 | ✅ 50% 阈值在 prompt 中 |
| AC-5 阶段限定 | ✅ 仅 5/6/7 触发 |

## L2/L3 审查历史

| Phase | L2 | L3 |
|---|---|---|
| 1 | fail→修复 | pass |
| 2 | pass→修复 | fail→CRITICAL 修复 |
| 3 | pass→修复 | pass |
| 5 | pass→修复 | N/A |
| 6 | fail→修复 (R1-R3) | 噪音干扰 |

## 已知限制

- Phase 6 L3 因工作区噪音无法准确评估（非本 change 的 10+ 文件修改在 diff 中）
- L3 API 30s 超时对大型 diff 偏短（Phase 2/6 均遇到，已用 60-90s 补跑）
- 源码扩展名白名单为硬编码 + env var 模式，新增语言需手动更新
