# hooks/config — 各承载面的 hook 配置

| 承载面 | 配置文件 | 说明 |
|---|---|---|
| claude code | `settings.json`（本目录模板）+ `.claude/stop-hook.json` | `install.sh --platform claude` 生成 |
| opencode | `settings.json`（本目录模板，由 opencode-claude-hooks 桥接）+ `.claude/stop-hook.json` | `install.sh --platform opencode` 生成 |
| dsh | 无 settings.json；`dsh-flow-kit` 的 `cordis.patch.yml` config 段控制 hooks 开关，项目内 `.flow-kit/stop-hook.json` 控制模块 | 插件 `hook-bridge.js` 监听 dsh 事件自动触发 |

`settings.json` 里的 `${CLAUDE_PROJECT_DIR}` 是 claude/opencode 承载面的
命令占位符；dsh 运行时完全不读此文件，项目根由 `FLOW_KIT_PROJECT_DIR`
或 session.cwd 提供。
