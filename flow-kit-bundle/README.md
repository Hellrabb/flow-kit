# flow-kit 完整迁移包

## 包含内容

| 组件 | 路径 | 说明 |
|---|---|---|
| flow-kit 核心引擎 | `flow-kit/` | GO.md, prompts/, templates/, reference/, RULES.md, SYSTEM.md |
| flow-* 技能包装器 | `skills/flow-*/` | 16 个 Claude Code skill，委托到 flow-kit 核心 |
| Stop Hook 系统 | `hooks/stop/` | 11 个模块化后处理脚本 + 3 个库文件 |
| SessionStart Hook | `hooks/session-start/` | flow-kit-resume + stop-report-reminder |
| 配置文件 | `hooks/config/` | settings.json 模板 + stop-hook.json 模板 |
| SPEC 模板 | `specs-template/` | STATE.md 模板 |
| brooks-lint 插件 | `brooks-lint/` | 6 个代码审查 skill（review/audit/debt/test/health/sweep） |
| 安装脚本 | `install.sh` | 自动安装到目标环境 |

## 源信息

- flow-kit 核心来自: https://github.com/rihebty/flow-kit
- Stop hook 系统来自: ~/nanoclaw/.claude/hooks/ (NanoClaw 项目定制)
- 技能包装器来自: ~/.claude/skills/flow-*/
- brooks-lint 插件来自: https://github.com/hyhmrright/brooks-lint (v1.3.0)

## 安装

```bash
# 首次安装 / 全新安装
./install.sh --global

# 智能更新（仅当 bundle 版本 > 已装版本时执行）
./install.sh --update

# 彻底重装（清空既有安装后全新安装）
./install.sh --reinstall

# 项目级安装（hooks 仅对当前项目生效）
./install.sh --project /path/to/your-project

# 用户级 hooks（所有项目共用）
./install.sh --project ~ --hooks-only      # 等同 --user
./install.sh --global --user               # 全局 + 用户级 hooks

# 精细控制
./install.sh --global --no-hooks        # 不装 stop hook
./install.sh --global --no-skills       # 不装 skills
./install.sh --global --no-brooks       # 不装 brooks-lint
./install.sh --project . --hooks-only   # 仅装 stop hook
```

## 更新 / 重装

拿到新版 bundle 后：

```bash
# 推荐：智能更新（自动版本比对）
./install.sh --update

# 如果出问题：彻底重装
./install.sh --reinstall
```

> ⚠️ 不要在 `~/.claude/flow-kit/` 里手动 git pull — bundle 版本管理走 `.flow-kit-version` 版本标记。
```
