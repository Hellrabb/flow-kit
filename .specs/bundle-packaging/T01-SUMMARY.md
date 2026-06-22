# T01-SUMMARY: install_brooks_tools.sh

- **Task**: T01 — 新建 install_brooks_tools.sh 安装模块
- **Status**: done

## 做了什么

创建 `flow-kit-bundle/lib/install_brooks_tools.sh`（92 行），导出 `install_brooks_tools()` 函数。

## 改动文件

- `flow-kit-bundle/lib/install_brooks_tools.sh`（新建）

## verify 输出

```
PASS: syntax OK
```

## 6 维自查

- R1 认知过载: 函数 80 行，清晰分段（检测→复制→shim→PATH→验证），可读 ✅
- R2 变更传播: 仅新建文件，无越界 ✅
- R3 知识重复: 复用 install_brooks.sh 的输出风格和 DRY_RUN 模式 ✅
- R4 偶然复杂: 无"以后可能用到"的扩展点 ✅
- R5 依赖混乱: 函数不依赖任何外部模块 ✅
- R6 领域扭曲: 使用项目域语言（brooks-tools, shim）✅

## 沿用既有抽象 grep

- install_brooks.sh 输出风格（═══ + ✅/⚠️/ℹ️ 缩进）→ 沿用
- install_skills.sh DRY_RUN 模式 → 沿用
- install_brooks.sh 版本检测（jq + grep fallback）→ 未在本任务使用（版本在 manifest.json）

## 越界检查

- TASK write_files: 1 项 → flow-kit-bundle/lib/install_brooks_tools.sh
- 实际 diff: 1 项 → 同上
- 越界: 0 ✅
