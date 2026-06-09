# CHANGE: Hook 系统 user scope 支持 + 全组件审计

- **Change ID**: `hook-user-scope`
- **创建日期**: 2026-06-09
- **状态**: archived

---

## Why

- 用户安装到 user scope (`~/.claude/`) 后，打开其他项目时 hook 报 "stophook no such file"
- 根因：settings.json 模板用 `${CLAUDE_PROJECT_DIR}/.claude/hooks/...` 路径，换项目后找不到装在 `~/.claude/hooks/` 的脚本
- 后续审计发现 `common.sh` 的 `CONFIG_FILE` 解析同样有 project 硬编码问题

## What

1. **install.sh 添加 --user flag**：hook 安装到 `~/.claude/hooks/`，settings 片段用 `${HOME}/.claude/hooks/...`
2. **common.sh init_paths() 修复**：`CONFIG_FILE` 优先查 `~/.claude/stop-hook.json`（user scope），fallback `${PROJECT_ROOT}/.claude/stop-hook.json`
3. **全组件审计**：逐组件扫描 user/project scope 兼容性，确认 0 阻塞问题
4. **bundle README 更新**：醒目标注 `--update` / `--reinstall` / `--user` 用法

## 影响面

- `install_hooks()` 重写为接受 scope 参数
- `common.sh` init_paths() CONFIG_FILE 优先级调整
- bundle README 安装段重写

## 范围排除

- 不修改 hook 模块的业务逻辑
- 不改变 project scope 的默认行为
