# T01-SUMMARY: weak-model-compliance.sh 扫描逻辑库

## 做了什么

实现了 `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh`（330 行 / 224 行净逻辑），提供弱模型合规扫描函数库。

## 改动文件

- `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh`（新建）

## verify 输出

```
bash -n → SYNTAX_OK
npx bats test/test_weak_model_compliance.bats → 14 tests / 0 failures
```

## 6 维自查

- R1 认知过载：scan_l1/l2/l3 三函数独立，单函数 ≤ 80 行
- R2 变更传播：仅写入 lib 文件，未触碰禁动清单
- R3 知识重复：矫正文件管理与 interactive-ui-check 格式不同（type/layer/violations[]），合理独立实现
- R4 偶然复杂：无过度抽象，三扫描层各自独立可组合
- R5 依赖方向：仅依赖 common.sh 框架 + transcript-parser 中间文件，无反向依赖
- R6 领域命名：函数命名使用 domain 术语（L1_rules / L2_selfcheck / L3_evidence）

## 沿用既有抽象 grep

- common.sh（hook 框架）：沿用 `module_output` / `module_enabled` 模式
- transcript-parser.sh：沿用 `$HOOK_TMP_DIR/messages.txt` / `tool-calls.txt` 等中间文件
- interactive-ui-check.sh：参考矫正文件管理模式，但格式独立（统一 type/layer 结构）

## 越界检查

- TASK write_files: `flow-kit-bundle/hooks/stop/lib/weak-model-compliance.sh`
- 实际 diff: 同上
- 越界: 0 ✅
