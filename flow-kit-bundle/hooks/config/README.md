# hooks/config — 各承载面的 hook 配置

> **配置层级（2026-09-21 统一）**：配置文件**只有用户级一份**，项目级副本既不生成也不读取。
> 解析链：`STOP_HOOK_CONFIG` env > 用户级 `<用户 runtime 目录>/stop-hook.json`（claude `~/.claude` ·
> opencode `~/.config/opencode` · dsh `~/.dsh`）> 插件模板 `<hooks>/config/stop-hook.json`（全新机器的兜底）。
> 项目目录下仍会有 `.flow-kit/`（dsh）/`.claude/`（claude），但其中只放**状态**（`stop-hook-state.json`、
> `stop-hook-report.md`、`.flow-active` 等），不放配置。

| 承载面 | 配置文件 | 说明 |
|---|---|---|
| claude code | **用户级** `~/.claude/stop-hook.json` + `~/.claude/settings.json`（hook 接线） | `install.sh --global` 生成 |
| opencode | **用户级** `~/.config/opencode/stop-hook.json`（settings.json 由 opencode-claude-hooks 桥接） | `install.sh --global --platform opencode` 生成 |
| dsh | **用户级** `~/.dsh/stop-hook.json`（hooks 开关由 `dsh-flow-kit` 的 `cordis.patch.yml` config 段控制） | 插件 `hook-bridge.js` 监听 dsh 事件自动触发，缺失时物化模板 |

`settings.json` 里的 `${CLAUDE_PROJECT_DIR}` 是 claude/opencode 承载面的
命令占位符；dsh 运行时完全不读此文件，项目根由 `FLOW_KIT_PROJECT_DIR`
或 session.cwd 提供。
