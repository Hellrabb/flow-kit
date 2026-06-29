# T04-SUMMARY: bats 测试 test_weak_model_compliance.bats

## 做了什么

编写 14 个 bats 测试用例，覆盖 AC-1 ~ AC-4：
- L1（4 个）：禁动文件路径解析 / 触碰检测 / 无违规通过 / 通用规则模式匹配
- L2（4 个）：PCSC 表空白行检测 / 全填通过 / 无表通过 / 多空白行
- L3（3 个）：幻觉路径检测 / 真实路径通过 / 混合路径
- CF（3 个）：JSON 字段完整性 / 合并去重 / 清除文件

## 改动文件

- `test/test_weak_model_compliance.bats`（新建，~260 行）
- `flow-kit-bundle/test/test_weak_model_compliance.bats`（同步副本）
- `flow-kit-bundle/test/test_interactive_ui_check.bats`（修复既有 sync gap）

## verify 输出

```
npx bats test/test_weak_model_compliance.bats → 14 tests / 0 failures
```

## 全量回归

```
npx bats test/ → 176 tests / 0 failures ✅
```
