# T10-SUMMARY — test_flow_kit_resume.bats 扩展（AC-6）

## 做了什么
扩展 `test_flow_kit_resume.bats`，加 4 用例（AC-6 model-missing 收割 + 不删 + 回归保护）。

## 改了哪些文件
- `flow-kit-bundle/test/test_flow_kit_resume.bats`（+4 用例，11 用例总计）

## verify 输出
```
1..11 全 ok（既有 7 + 新 4）
新用例：l3-model-missing banner+不删 / l2-model-missing banner+不删 / compliance 读后删（回归）/ l2-missing 持久化（T06 bug 修复）
```

## 越界检查（R6.5）
write_files: test_flow_kit_resume.bats | 实际: 同 | 越界: 0 ✅
