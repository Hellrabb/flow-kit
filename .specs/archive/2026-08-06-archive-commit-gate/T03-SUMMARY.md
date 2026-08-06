# T03-SUMMARY — CORRECTION_TYPE_ARCHIVE_UNCOMMITTED 常量

## 做了什么

在 `correction-types.sh` 常量区追加 `readonly CORRECTION_TYPE_ARCHIVE_UNCOMMITTED="archive-uncommitted"`。

## 实现

单行 readonly 常量，对齐 UPPER_SNAKE_CASE 命名约定（L2 #7 · CONTEXT 已锁）。位于 CORRECTION_TYPE_INTERACTIVE_UI 之后、CORRECTION_MAX_RETRY 之前。

## verify

```
grep -q 'CORRECTION_TYPE_ARCHIVE_UNCOMMITTED' correction-types.sh → ✅
```

## 越界检查

diff 仅 1 行追加 → 0 越界 ✅
