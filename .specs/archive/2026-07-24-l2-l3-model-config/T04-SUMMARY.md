# T04-SUMMARY — 29-independent-review.sh:59 替换 :? → fk_resolve_model + 降级

## 做了什么
`29-independent-review.sh:57-59` 替换 :? + 过期注释 → `fk_resolve_model "L3"` 三级链 + 降级（顶层 exit 3）+ clear。**附带清理 :57 过期注释**（L2 R1'）。

## 改了哪些文件
- `flow-kit-bundle/hooks/stop/29-independent-review.sh`（:57-59 替换）

## verify 输出
```
T04_VERIFY_OK（fk_resolve_model "L3" + 无 :? + write_model_missing_correction/clear "L3"）
:? 残留：0 | ANTHROPIC_DEFAULT_HAIKU_MODEL 引用：0（:57 注释一并清理）
```

## 1.8 破坏性变更（移除 :? + 清理 :57 注释）
- **影响既有测试**：`test_independent_review_model.bats` AC-1 断言 `grep ANTHROPIC_DEFAULT_HAIKU_MODEL >= 1`（依赖 :57 注释）现失败 → **T11 更新**（AC-1 改 fk_resolve_model 契约，T04→T11 顺序）
- **降级 vs 错误**：顶层 exit 3（run_module || true 不影响 gate 链）；API 前退出

## 越界检查（R6.5）
write_files: 29-independent-review.sh | 实际 diff: 29-independent-review.sh | 越界: 0 ✅

## LESSONS
- L-020 不适用 | source guard（correction-file）兜底
