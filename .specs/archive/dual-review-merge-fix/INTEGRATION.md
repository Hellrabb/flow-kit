# INTEGRATION: L2/L3 双层审查结果合并写入

- **Change ID**: `dual-review-merge-fix`
- **归档日期**: 2026-07-07
- **关联**: `@.specs/CONTEXT.md`、`@.specs/LESSONS.md`

---

## 归档摘要

修复 L2/L3 独立审查在 gate_config="both" 模式下的时序错位（L3 先于 L2 写 `.done`）+ 文件覆写（L2 Write 销毁 L3 段）导致审查信号丢失。

### 修改清单

| 文件 | 改动 | 决策 |
|---|---|---|
| `hooks/stop/29-independent-review.sh` | +28 | D1 L2-wait gating + D2 L3-only `skipped` |
| `hooks/stop/lib/l3-review.sh` | +12 | D3 both `.done` defer + `skipped` 值域 |
| `hooks/pre-tool-use/independent-review-gate.sh` | +17 | D1 PreToolUse L2-wait |
| `prompts/independent/L2-blind-review.md` | +12 | D4 append-first 文件写入约束 |
| `prompts/{1-2-3-5-6-7}/*.md` (6 files) | +15×6 | D4 追加指令 + KVP `.done` |
| `test/test_dual_review_merge.bats` | new (14 tests) | AC-1~AC-8 全覆盖 |
| `.specs/CONTEXT.md` | +6 | 术语 + 已锁决策 |

### 验证结果

- **bats**: 346/346 全部通过
- **SPEC 合规**: 8/8 AC 全覆盖
- **L2 审查**: 阶段 1-6 全部通过（含 pass 和 fail→fix→verify）

---

## 产物完整性

| 产物 | 状态 |
|---|---|
| CHANGE.md | ✅ |
| REQUIREMENT.md (8 AC) | ✅ |
| DESIGN.md (4 decisions) | ✅ |
| TASK.md (7 tasks) | ✅ |
| TEST.md (14 new + 346 reg) | ✅ |
| REVIEW.md (3 rounds) | ✅ |
| INTEGRATION.md | ✅ |
| INDEPENDENT-REVIEW-{1,2,3,5,6}.md | ✅ |
| .independent-review-{1,2,3,5,6}.done | ✅ |

---

## LESSONS 提取

| # | 教训 |
|---|---|
| L-new-1 | gate_config 的 5th parameter 传递链（29 hook → l3_review_run / gate → l3_review_with_timeout → l3_review_run）必须完整；L2 审查捕获了所有 3 处调用点遗漏（R1 Critical） |
| L-new-2 | phase_name 映射（{1,2,3,5,6,7} → {1-requirement,2-design,3-task,5-test,6-review,7-integration}）在 3 处重复（29 hook / PreToolUse gate / done-validation）——v2 考虑抽取共享函数 |

---

## 后续动作

- 运行 `make check` 确认打包完整性（测试同步到 bundle/）
- 考虑 commit: `fix: L2/L3 dual review merge — gate_config=both L3-wait + append-first + value-domain skipped`
