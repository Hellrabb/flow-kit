# flow-kit — Claude Code 开发工作流引擎

flow-kit 分发包仓库。将完整的 flow-kit 生态（核心引擎 + 15 个阶段 prompts + 13 个 templates + 7 个 reference + flow-* skills + Stop Hook 系统 + SessionStart hooks + brooks-lint 插件）打包为可迁移的 `flow-kit-bundle.tar.gz`，供目标环境通过 `install.sh` 一键安装。

## 目录结构

```
flow-kit/
├── package-flow-kit.sh              # 打包 + 安装脚本（28KB · 核心）
├── flow-kit-bundle.tar.gz           # 分发包（.gitignore 排除）
├── FLOW-KIT-用户指南.md             # 完整用户指南（安装 / 命令 / 生命周期 / Goal 系统 / 工作流示例）
├── flow-kit-bundle/                 # 分发包源码
│   ├── flow-kit/                    # 核心引擎（GO.md / RULES.md / prompts / templates / reference）
│   ├── skills/                      # flow-* 技能定义
│   ├── hooks/                       # Stop + SessionStart 钩子系统
│   ├── brooks-lint/                 # 代码审查插件（12 本经典工程书籍驱动）
│   └── install.sh                   # 安装器（由 package-flow-kit.sh 生成）
├── .specs/                          # 项目规格（CONTEXT / STATE / CHANGE 子目录）
│   └── init-git-repo/               # 当前活跃 change
├── .gitignore
└── README.md                        # 本文件
```

## 开发规范

### 命名约定

| 类型 | 风格 | 示例 |
|---|---|---|
| 文件 | `kebab-case` | `package-flow-kit.sh`、`flow-kit-ecosystem-guide.md` |
| Shell 函数 | `snake_case` | `install_file()`、`check_command()` |
| Change ID | `kebab-case`（2–4 词） | `init-git-repo`、`add-dark-mode` |

### 提交格式

[Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<change-id>): <task-id> <简要描述>
```

| Type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | 修 bug |
| `docs` | 文档变更 |
| `chore` | 构建/工具/配置 |
| `refactor` | 重构（不改行为） |

### 分支策略

- **main** — 默认分支，单人维护，允许直推
- **禁止** force push 到 main
- 多人协作时再引入 feature 分支 + PR 流程

### 错误处理

所有 Shell 脚本使用 `set -euo pipefail`（遇错即停）。

### 技术债跟踪

技术债记录在 `.specs/LESSONS.md`，由 brooks-lint 扫猫 + 手动补充维护。

## 快速开始

```bash
# 打包新 bundle
bash package-flow-kit.sh

# 安装到目标项目
bash flow-kit-bundle.tar.gz  # 解压后运行 install.sh
```
