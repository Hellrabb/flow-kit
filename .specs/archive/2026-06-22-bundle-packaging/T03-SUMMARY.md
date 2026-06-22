# T03-SUMMARY: install.sh 集成 brooks-tools

- **Task**: T03 — install.sh 集成 brooks-tools 安装
- **Status**: done

## 做了什么

修改 `flow-kit-bundle/install.sh`（+22 行）：
- 新增 `NO_BROOKS_TOOLS=false` 变量
- 新增 `check_node()` 函数
- 新增 `--no-brooks-tools` flag 解析
- source install_brooks_tools.sh
- global 模式中在 install_brooks_lint 后调用 install_brooks_tools

## 改动文件

- `flow-kit-bundle/install.sh`

## verify 输出

```
PASS: syntax OK
PASS: check_node integrated
```

## 6 维自查

- R1: check_node 6 行简洁 ✅
- R2: 仅新增代码，未改原有流程 ✅
- R3: 沿用 --no-* flag 模式和 source lib/ 模式 ✅
- R4-R6: 无问题 ✅

## 沿用既有抽象 grep

- `--no-brooks` flag 模式 → 沿用（新增 --no-brooks-tools）
- `source "$SCRIPT_DIR/lib/install_*.sh"` 模式 → 沿用

## 越界检查

- TASK write_files: flow-kit-bundle/install.sh
- 实际 diff: flow-kit-bundle/install.sh
- 越界: 0 ✅
