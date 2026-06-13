# CHANGE: brooks-lint SessionStart hook 空 commands 目录导致启动报错

- **Change ID**: `brooks-lint-hook-fix`
- **创建日期**: 2026-06-14
- **路径建议**: 最短（bugfix，修复已实施 + 验证）
- **状态**: archived

---

## Why（为什么做）

brooks-lint 插件每次 session 启动时 SessionStart hook 报错（exit 1），原因是 `package-flow-kit.sh` 安装时排除 `commands/` 目录（第 438 行 `--exclude='commands'`），但 hook 脚本 `session-start:22` 仍尝试执行：

```bash
cp "$plugin_dir"/commands/brooks-*.md "$cmd_dir/"
```

在 `set -euo pipefail` 下，glob 空匹配 → cp 收到字面量路径 `brooks-*.md` → "No such file or directory" → exit 1 → Claude Code 报告 SessionStart hook error。

## What（做什么）

1. 修补已安装的 brooks-lint hook：`cp` 裸 glob → `for f in ...; do [ -f "$f" ] && cp` 保护，空 commands 目录时优雅跳过
2. `package-flow-kit.sh` 新增安装后自动修补 hook 脚本的步骤，下次重装不复发

## 影响面

- [ ] 影响 `REQUIREMENT.md`
- [ ] 影响 `DESIGN.md` / 引入新 ADR
- [ ] 影响现有 AC
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [x] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- 不恢复 commands/ 目录的安装（命令入口 stub 由 brooks-lint plugin 自身 Skill 注册，namespaced：`brooks-lint:brooks-review`，module-less stub 会导致重复 skill 注册）
- 不在 brooks-lint 上游 repo 修（这是 flow-kit 分发侧兼容性问题）
- 不引入 bats-core 测试（测试框架见 LESSONS.md L-003，本次手动验证）

## 验收线（粗粒度，不是 AC）

- brooks-lint SessionStart hook 在空 commands/ 目录下 exit 0，输出正确 JSON
- `package-flow-kit.sh` 下次安装后自动修补 hook，`bash -n` 语法检查通过
- 用户下次 session 启动不再看到 brooks-lint hook error

## 风险与未知

- 无。修复是本地化保护逻辑，不改变 hook 的正常行为（有 commands 文件时仍正常复制）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
