# INTEGRATION — L3 独立审查异步化

- **Change ID**: l3-async-dispatch
- **完成日期**: 2026-07-07

---

## 产物完整性

| 产物 | 状态 |
|---|---|
| CHANGE.md | ✅ |
| REQUIREMENT.md | ✅ |
| DESIGN.md | ✅ |
| TASK.md | ✅ |
| TEST.md | ✅ |
| REVIEW.md | ✅ |
| INTEGRATION.md | ✅ |

## CHANGELOG 更新

待 commit 时一并在 commit message 中记录。建议条目：
```
2026-07-07 | l3-async-dispatch | L3 异步化：PreToolUse gate 移除 30s 同步 L3 调用，改为 L2 同款异步派发模式 · 9 new bats · bash -n 全过
```

## 改动清单

| 文件 | 操作 |
|---|---|
| `flow-kit-bundle/hooks/stop/lib/l3-review.sh` | +75 行（l3_dispatch_prompt 函数） |
| `flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` | +68 / -99 行（同步 L3 → 异步派发） |
| `flow-kit-bundle/test/test_l3_async_dispatch.bats` | 新文件（9 tests） |
| `.specs/l3-async-dispatch/` | 7 个 spec 工件 |

## 验收确认

- [x] PreToolUse gate 不再调用 `l3_review_with_timeout`（AC-1）
- [x] `.done` 存在时放行 + F1 注入（AC-2）
- [x] `.done` 不存在时派发 + 拦截（AC-3）
- [x] `l3_dispatch_prompt()` 格式与 L2 一致（AC-4）
- [x] `l3_review_run()` 不受影响（AC-5）
- [x] bash -n 全过（AC-6）
- [x] 9/9 新测试 + L3 现有测试全绿（AC-7）
