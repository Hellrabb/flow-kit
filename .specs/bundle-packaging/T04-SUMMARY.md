# T04-SUMMARY: bats 测试

- **Task**: T04 — bats 测试：install_brooks_tools.sh 单元测试 + 回归
- **Status**: done

## 做了什么

新建 `test/test_install_brooks_tools.bats`（5 个测试用例）：
1. 语法检查通过
2. DRY_RUN 模式输出预期内容
3. Node.js 检测输出版本号
4. DRY_RUN 列出 4 个工具 shim
5. 源目录缺失时跳过

## 改动文件

- `test/test_install_brooks_tools.bats`（新建）

## verify 输出

```
1..5 — all ok
Regression: 1..94 — all ok
```

## 6 维自查

- R1: 每个测试 ≤ 15 行，清晰易懂 ✅
- R2-R6: 纯测试文件，无生产代码改动 ✅

## 越界检查

- TASK write_files: test/test_install_brooks_tools.bats
- 实际 diff: 同上
- 越界: 0 ✅
