# REQUIREMENT: Hook 系统 user scope 支持

- **Change ID**: `hook-user-scope`

---

## 用户故事

- **US-1**：作为离线机用户，我想 hooks 装在 `~/.claude/` 后所有项目共用，以便打开任意项目都能触发 stop hook。
- **US-2**：作为维护者，我想确认所有打包组件在 user scope 和 project scope 下都正常工作。

## 验收准则

### AC-1 · --user 安装 hooks
- **Given** 无既有安装
- **When** `./install.sh --global --user`
- **Then** hooks 安装到 `~/.claude/hooks/`；settings 片段使用 `${HOME}/.claude/hooks/...` 路径
- **验证方式**: `ls ~/.claude/hooks/stop/00-gate.sh` 存在

### AC-2 · user scope 换项目不报错
- **Given** hooks 在 `~/.claude/hooks/`；settings.json 使用 `${HOME}` 路径
- **When** 打开任意项目（即使该项目无 `.claude/` 目录）
- **Then** stop hook 不报 "no such file"
- **验证方式**: Claude Code 启动无 hook 报错

### AC-3 · CONFIG_FILE user scope 优先
- **Given** `~/.claude/stop-hook.json` 存在
- **When** hook 运行 init_paths()
- **Then** CONFIG_FILE = `~/.claude/stop-hook.json`
- **验证方式**: hook 日志显示从 user scope 读取配置

### AC-4 · 全组件审计
- **Given** 最新 bundle
- **When** 逐组件扫描路径依赖
- **Then** 7 个组件在 user/project scope 下均可用
- **验证方式**: 审计报告 0 阻塞项

---

## 范围切分

### v1
- install_hooks() --user 支持
- common.sh CONFIG_FILE user scope 优先
- 全组件审计
- bundle README 更新

### v2
- settings.json 自动合并（当前需手动）
- stop-hook.json 多 profile 支持

### out
- 不修改 hook 业务逻辑
- 不改变 project scope 默认行为
