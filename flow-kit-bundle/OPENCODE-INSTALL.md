# opencode 安装指南

本指南说明如何在 [opencode](https://opencode.ai) 环境中安装并启用 flow-kit。

## 前置条件

- opencode ≥ 1.18（已自带 skills 系统支持）
- Node.js ≥ 18（仅 brooks-lint 工具链需要）
- npm（仅安装 hooks 桥接插件时需要）

## 快速安装

```bash
# 解压 bundle
tar xzf flow-kit-full-*.tar.gz
cd flow-kit-full-*/

# 全局安装到 opencode（核心 + skills + brooks + AGENTS.md 注入）
./install.sh --platform opencode --global

# 项目级 hooks（在项目根目录运行）
./install.sh --platform opencode --project . --hooks-only
```

## 安装位置

| 组件 | 位置 |
|---|---|
| flow-kit 核心引擎 | `~/.config/opencode/flow-kit/` |
| flow-* skills | `~/.config/opencode/skills/flow-*/` |
| brooks-* skills | `~/.config/opencode/skills/brooks-*/` |
| brooks-lint npm 工具 | `~/.config/opencode/tools/brooks-lint/` |
| 全局 AGENTS.md 注入 | `~/.config/opencode/AGENTS.md` |
| 项目级 hooks 脚本 | `<project>/.opencode/hooks/` |
| 项目级 stop-hook 配置 | `<project>/.opencode/stop-hook.json` |
| 版本标记 | `~/.config/opencode/.flow-kit-version` |

> opencode 原生也读取 `~/.claude/skills/`，但本安装器显式装到 `~/.config/opencode/skills/` 以保持平台规范。

## Hooks 启用（重要）

opencode 与 Claude Code 的关键差异：**opencode 不原生读取 `~/.claude/settings.json`**。
flow-kit 的 Stop / PreToolUse hooks（自动 stop-report、git 检查、QA 审查等）默认在 opencode 中**不触发**。

要启用 hooks，需安装桥接插件（任选其一）：

### 方案 A: opencode-claude-hooks（推荐）

```bash
# 1. 全局安装桥接插件
npm install -g opencode-claude-hooks

# 2. 在 ~/.config/opencode/opencode.json 的 plugin 数组加入
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "oh-my-opencode",
    "opencode-acp@latest",
    "opencode-claude-hooks"
  ]
}

# 3. 重启 opencode
```

桥接插件会自动读取 `~/.claude/settings.json` 和 `<project>/.claude/settings.local.json`，
在 opencode 生命周期事件（`session.created`、`tool.execute.before`、`session.idle` 等）
触发 Claude 风格的 hooks，注入 `$CLAUDE_PROJECT_DIR` 环境变量，并以 Claude 格式 stdin JSON 调用
你的 hook 脚本。

### 方案 B: opencode-hooks-plugin

```bash
git clone https://github.com/romain325/opencode-hooks-plugin ~/.config/opencode/plugin/opencode-hooks
```

此插件提供相同功能，从 git 安装。

## 与 Claude Code 共存

如果同一台机器同时跑 Claude Code 和 opencode，两个平台的安装相互独立：

| 平台 | 数据目录 |
|---|---|
| Claude Code | `~/.claude/` |
| opencode | `~/.config/opencode/` |

两套安装可共存，互不污染。

## 验证安装

```bash
# 列出已装 skills
ls ~/.config/opencode/skills/ | grep -E '^(flow|brooks)'

# 验证版本标记
cat ~/.config/opencode/.flow-kit-version

# 验证 AGENTS.md 注入
grep -A 2 'flow-kit-injection:begin' ~/.config/opencode/AGENTS.md

# 验证项目级 hooks（项目目录内）
ls .opencode/hooks/stop/ .opencode/hooks/pre-tool-use/
cat .claude/settings.local.json
```

启动 opencode 后，flow-* skills 应出现在 `/` 命令补全中。

## 已知限制

1. **无原生 hooks**：opencode 没有原生 settings.json shell hooks，必须靠桥接插件。
2. **无 `$OPENCODE_PROJECT_DIR`**：opencode 不设置项目目录 env 变量；桥接插件注入 `$CLAUDE_PROJECT_DIR` 替代。
3. **brooks-lint 无插件运行时**：opencode 无 Claude Code 的 plugins/cache/marketplaces 机制，brooks-lint 仅作为普通 skills 安装。
4. **SessionStart hooks**：当前未在项目级注册（仅全局），避免重复触发。

## 卸载

```bash
# 清理 opencode 安装
rm -rf ~/.config/opencode/flow-kit
rm -rf ~/.config/opencode/skills/flow-*
rm -rf ~/.config/opencode/skills/brooks-*
rm -rf ~/.config/opencode/skills/_shared
rm -rf ~/.config/opencode/tools/brooks-lint
rm -f ~/.config/opencode/.flow-kit-version

# 移除 AGENTS.md 中的 flow-kit 注入块（手动编辑或保留）

# 项目级清理（项目目录内）
rm -rf .opencode/hooks .opencode/stop-hook.json
rm -f .claude/settings.local.json
```

## 故障排查

### skills 没出现在 / 命令补全中

1. 确认 `~/.config/opencode/skills/flow-*/SKILL.md` 文件存在
2. 确认 SKILL.md frontmatter 含 `name` 和 `description`
3. 重启 opencode（skills 在启动时扫描）
4. 检查环境变量 `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` 未设置

### hooks 不触发

1. 确认桥接插件已安装并在 `opencode.json` 的 `plugin` 数组中
2. 确认 `.claude/settings.local.json` 存在且含 hooks 配置
3. 检查 `<project>/.opencode/hooks/stop/00-gate.sh` 可执行
4. 查看 opencode 日志：`~/.local/share/opencode/log/`

### AGENTS.md 注入未生效

1. 确认 `~/.config/opencode/AGENTS.md` 含 `<!-- flow-kit-injection:begin -->` 标记
2. 重启 opencode（AGENTS.md 在启动时加载）
