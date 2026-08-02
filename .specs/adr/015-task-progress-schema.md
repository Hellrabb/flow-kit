# ADR-015: task_progress Schema 字段锁

**Status**: Proposed (superpowers-v6-absorb Phase 2)
**Date**: 2026-08-02
**Supersedes**: 无（首次定义 task_progress）
**Superseded by**: 无

## Context

superpowers v6.0 SKILL.md L117-141 警告："Conversation memory does not survive compaction. controllers that lost their place have re-dispatched entire completed task sequences — the single most expensive failure observed."

flow-kit .flow-active 当前无 per-task 状态记录。compaction 后 4-dev 可能重新分派已完成 task，浪费 tokens + 产生重复 commit。

本 change 引入 `.flow-active.goal.task_progress[]` 作为机器读实时 ledger。但字段集需要锁定，避免 DESIGN 阶段未约束、后续 change 随意扩展导致 schema 漂移。

L2 盲审（INDEPENDENT-REVIEW-1.md R3）指出：原 AC-F3 把字段映射延后到 DESIGN 是 self-referential 反模式。本 ADR 在 REQUIREMENT/DESIGN 阶段就锁字段集。

## Decision

**task_progress 字段集锁为 5 字段，禁止扩展（除非新 ADR 批准）**：

```json
{
  "goal": {
    "task_progress": [
      {
        "id": "T03",                    // task ID，与 TASK.md <task id="..."> 一致
        "commit_sha": "abc1234",        // 7-char short SHA（git log --format=%h）
        "fix_rounds": 2,                // 该 task 经历的 fix loop 轮数（首次完成 = 1）
        "deferred": ["M1", "M2"],       // 该 task 的 Minor finding 编号列表（对应 MINOR-DEFERRED.md）
        "completed_at": "2026-08-02T22:18:20+08:00"  // ISO8601 完成时间戳
      }
    ]
  }
}
```

字段定义约束：
- **id**：字符串，必填，与 TASK.md task 块 id 一致
- **commit_sha**：字符串，必填，7 字符 short SHA（不是 full SHA，节省空间）
- **fix_rounds**：整数 ≥ 1，必填，首次完成 = 1（不是 0）
- **deferred**：字符串数组，必填（无 deferred 时为 `[]`，不是 null）
- **completed_at**：ISO8601 字符串，必填，含时区（`+08:00`，不是 Z）

写入时机：
- 4-dev.md §6 写 T<N>-SUMMARY.md 时同步 jq append .flow-active.goal.task_progress
- jq 命令必须原子写（临时文件 + mv）
- 旧 .flow-active（无 task_progress 字段）→ hook 读时视为 `[]`（向后兼容）

读取时机：
- 4-dev 入场读 .flow-active.goal.task_progress，确认当前 task 不在数组中
- compaction 后 4-dev 重新派 task 前，先 check task_progress

## Consequences

**正面**：
- compaction survival：4-dev 不会重派已完成 task
- 5 字段最小集，jq 友好，无 schema 学习曲线
- 字段锁死防 scope creep

**负面**：
- 无法记录 retry_count、estimated_tokens、actual_tokens、model_tier_used 等可能有用的字段
- 未来扩展需新 ADR，流程略重

**Neutral**：
- 与 T<N>-SUMMARY.md 职责清晰分工：task_progress 机器读实时，SUMMARY 人读事后自由格式
- 33-flow-active-integrity hook 已有 .flow-active 字段校验机制，可扩展 task_progress schema 校验

**字段扩展门槛**：
未来如需新增字段（如 retry_count），需：
1. 写新 ADR（如 ADR-019）说明为何需要、影响哪些消费者
2. 更新 ADR-015 引用关系（supersede 部分字段集）
3. 更新 4-dev.md jq 写入逻辑
4. 更新 33-flow-active-integrity hook 校验（可选）
5. 更新 bats 测试集

**禁动约束**（同步登记到 CONTEXT.md § 9.5 禁动清单）：
- 禁止绕过 jq 直接编辑 .flow-active.goal.task_progress
- 禁止在 task_progress 数组中加非 5 字段对象
- 禁止把 task_progress 字段重命名（向后兼容破坏）

## 触发条件

- 本 change 实施时（phase 4）：4-dev.md 加 jq 写入逻辑
- 本 change 测试时（phase 5）：bats 测试覆盖字段集 + 向后兼容
- 后续 change 4-dev 重构时：必须保留 task_progress 写入
