# T02-SUMMARY: 删除 .claude/hooks/ 目录

- **Task ID**: T02
- **状态**: done
- **完成时间**: 2026-06-16

## 做了什么

1. grep 全仓引用 `.claude/hooks/`，确认无脚本以此为源路径
2. 确认 `install.sh` 和 `package-flow-kit.sh` 均从 `flow-kit-bundle/hooks/` 读取
3. 删除 `.claude/hooks/` 目录（16 个文件）

## 改了哪些文件

| 文件 | 操作 |
|------|------|
| `.claude/hooks/stop/00-gate.sh` ~ `99-report.sh` (11 files) | 删除 |
| `.claude/hooks/stop/lib/common.sh` etc (3 files) | 删除 |
| `.claude/hooks/session-start/flow-kit-resume.sh` etc (2 files) | 删除 |

## verify 输出

```
test ! -d .claude/hooks && echo "PASS"
PASS
```

## 破坏性变更（1.8）

- **删除 16 个文件**：确认无脚本引用 repo 内 `.claude/hooks/` 为源路径
- **影响**：本项目的 `.claude/settings.local.json` 引用 `${CLAUDE_PROJECT_DIR}/.claude/hooks/stop/00-gate.sh`，删除后本项目 Stop hook 失效
- **恢复**（2026-06-16 补充）：`bash flow-kit-bundle/install.sh --project . --hooks-only` 已执行，hooks 从 bundle 重装回 `.claude/hooks/`

## 越界检查（R6.5）

```
✅ TASK write_files：.claude/hooks/ 下 16 个文件（删除）
✅ 实际 diff 涉及：16 deletions
✅ 越界：0
```
