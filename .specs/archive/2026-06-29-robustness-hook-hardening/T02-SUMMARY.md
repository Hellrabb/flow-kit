# T02-SUMMARY: 28-weak-model-compliance.sh + T03 SessionStart + T05 config

## 做了什么

- **T02**: 实现 Stop hook 28 号协调器（92 行 / 59 行净逻辑），调用 lib 的 L1/L2/L3 扫描，聚合违规写入矫正文件
- **T03**: 扩展 SessionStart `flow-kit-resume.sh`，追加 compliance 矫正 block（~38 行新增），解析 `.flow-active.correction` JSON 并注入矫正 banner
- **T05**: 在 `stop-hook.json` 注册 `weak_model_compliance` 模块（enabled + W1/W2/W3 checks）

## 改动文件

- `flow-kit-bundle/hooks/stop/28-weak-model-compliance.sh`（新建）
- `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`（修改，+38 行）
- `.claude/stop-hook.json`（修改，+6 行）

## verify 输出

```
T02: bash -n → SYNTAX_OK
T03: bash -n → SYNTAX_OK
T05: jq -e '.modules.weak_model_compliance.enabled == true' → CONFIG_OK
```

## 越界检查

- TASK write_files: 以上 3 个文件
- 实际 diff: 以上 3 个文件 + test/test_weak_model_compliance.bats + flow-kit-bundle/test/ + .gitignore
- .gitignore 修改为合法扩展（本 change 产物需要 gitignore 覆盖），非越界
- test/ sync 为 T04/T06 操作，非越界
