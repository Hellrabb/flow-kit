# T09-SUMMARY — install_hooks.sh 新增 opencode agent 安装段

## 改动摘要

只改 `flow-kit-bundle/lib/install_hooks.sh`（无越界文件，无 commit）：

1. **函数头平台行为注释（L9-19）同步补 agent 目录说明**
   - claude 段新增：agent 不装（CC 用 subagent_type 原生派发 L2 审查）
   - opencode 段新增：agent (flow-kit-l2-reviewer) 装到 `~/.config/opencode/agent/` (user) 或 `$project/.opencode/agent/` (project)

2. **install_hooks() 内新增 agent 安装段（L145-168）**，位置在 `deploy_pre_commit`（L140）之后、配置文件段（stop-hook.json）之前：
   - `PLATFORM=opencode` 时才执行（claude 平台不装）
   - 源：`$SCRIPT_DIR/flow-kit/.opencode/agent/flow-kit-l2-reviewer.md`
   - user scope → `${PLATFORM_CONFIG_DIR}/agent/flow-kit-l2-reviewer.md`（= `~/.config/opencode/agent/`）
   - project scope → `${project}/${PROJECT_DIR_NAME}/agent/flow-kit-l2-reviewer.md`（= `$project/.opencode/agent/`）
   - 冲突检测：目标已存在且 `FLOW_KIT_YES != 1` → `read -p` 覆盖确认（仿 deploy_pre_commit L48-57）；`y` 覆盖 / 其他跳过 / `FLOW_KIT_YES=1` 静默覆盖
   - 复用 `install_file()`；安装完成 echo `✅` 一行（DRY_RUN 下仅打印不复制，既有语义未动）

## 设计说明（与既有抽象对齐）

- `SCRIPT_DIR` 变量名以 install_hooks.sh 既有代码为准（L40/109/114 同款引用）
- paths.sh 无 agent 目录变量 → 直接用 `${PLATFORM_CONFIG_DIR}/agent` 与 `${project}/${PROJECT_DIR_NAME}/agent` 拼接
- 与 deploy_pre_commit 的差异点（有意为之）：冲突跳过用 `agent_skip` 标志而非 `return 0` —— `return 0` 会退出整个 install_hooks()，跳过后续配置文件段与 settings 接线；agent 段只需跳过自身安装

## Verify 真实输出

任务 verify（opencode + user scope dry-run）：

```
   [DRY-RUN] cp /flow-kit/.opencode/agent/flow-kit-l2-reviewer.md -> /home/hellrabbit/.config/opencode/agent/flow-kit-l2-reviewer.md
   ✅ flow-kit-l2-reviewer agent → /home/hellrabbit/.config/opencode/agent/flow-kit-l2-reviewer.md
```

> 注：dry-run 中 src 显示 `/flow-kit/...` 是因为 verify 独立 source 时 SCRIPT_DIR 未设置（install.sh 正常流程会设置）；实际路径由 SCRIPT_DIR 注入，已在冲突测试中用 `SCRIPT_DIR=$PWD/flow-kit-bundle` 证实。

## 补充验证

- **project scope**（dry-run）：`[DRY-RUN] cp ... -> /tmp/opencode/t09-proj/.opencode/agent/flow-kit-l2-reviewer.md` ✓
- **claude 平台负向**：`FLOW_KIT_PLATFORM=claude` dry-run 全输出 grep -ci "agent|l2-reviewer" = `0`（grep 退出码 1，无 agent 行）✓
- **冲突分支**（真实执行 + SCRIPT_DIR 注入）：
  - 已有文件 + 回答 `n` → `[flow-kit-l2-reviewer] 已存在，skipped:` 且文件内容未变 ✓
  - 已有文件 + 回答 `y` → 覆盖成功（13955 字节 = 源文件大小）✓
  - 已有文件 + `FLOW_KIT_YES=1` → 无提示直接覆盖（13955 字节）✓
- **DRY_RUN 语义**：dry-run 全程仅打印 `[DRY-RUN]` 行，未产生任何真实文件 ✓
- `bash -n flow-kit-bundle/lib/install_hooks.sh` → SYNTAX OK ✓

## 关键行号（install_hooks.sh）

| 位置 | 行号 |
|---|---|
| 函数头 agent 注释（opencode） | 21-22（claude 注释 5） |
| agent 安装段开始 | 145 |
| src / user dst / project dst | 148 / 151 / 153 |
| 冲突检测 + read -p | 157-161 |
| skip 分支 / 安装分支 | 163-167 |

## 6 维自查

| 维度 | 结果 |
|---|---|
| 复用既有抽象 | ✅ install_file() / PLATFORM / resolve_paths 变量 / deploy_pre_commit 冲突模式 |
| 不做破坏性变更 | ✅ 既有函数与行为零改动，仅新增段 + 注释 |
| DRY_RUN 语义 | ✅ 未触碰 install_file()，dry-run 只打印 |
| 平台隔离 | ✅ 仅 opencode 触发，claude 负向验证 0 匹配 |
| 错误处理 | ✅ 语法过 bash -n；project 目录不存在仍走既有 L94-97 检查 |
| 范围约束 | ✅ 只改 install_hooks.sh；未动 REQUIREMENT/DESIGN/TASK/package-flow-kit.sh；未 commit |
