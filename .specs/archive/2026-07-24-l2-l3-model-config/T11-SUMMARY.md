# T11-SUMMARY — test_independent_review_model.bats AC-1/AC-3 更新

## 做了什么
更新 `test_independent_review_model.bats` 的 AC-1/AC-3 断言（:?/ANTHROPIC_DEFAULT_HAIKU_MODEL → fk_resolve_model 契约），setup 改读源码树。

## 改了哪些文件
- `flow-kit-bundle/test/test_independent_review_model.bats`（setup 加 FK_SRC_29 向上查找 + AC-1/AC-3 改 fk_resolve_model）

## verify 输出
```
1..12 全 ok
AC-1: 29 用 fk_resolve_model ✅（读源码，L2 R3'）
AC-3: 29 fk_resolve_model + 30 保持 :- ✅
AC-2/AC-4/AC-9/API path/onecli/stop-hook.json: 既有用例 pass（安装副本 $HOME/.claude/hooks/ 存在，本 change 不改这些）
```

## 关键改动（L2 R1'/R2'/R3'）
- AC-1：`grep ANTHROPIC_DEFAULT_HAIKU_MODEL` → `grep fk_resolve_model`（T04 清理 :57 注释后旧断言失效）
- AC-3：29 部分 `grep :?` → `grep fk_resolve_model "L3"`；30 保持 :-（本 change 不改 30）
- setup：加 FK_SRC_29 向上查找源码（对齐 test_common.bats，L2 R3'，避免陈旧安装副本）

## 越界检查（R6.5）
write_files: test_independent_review_model.bats | 实际: 同 | 越界: 0 ✅
