# flow-kit — Claude Code 开发工作流引擎

flow-kit 分发包仓库。将完整的 flow-kit 生态（核心引擎 + 15 个阶段 prompts + 13 个 templates + 7 个 reference + flow-* skills + Stop Hook 系统 + SessionStart hooks + brooks-lint 插件）打包为可迁移的 `flow-kit-bundle.tar.gz`，供目标环境通过 `install.sh` 一键安装。

## 目录结构

```
flow-kit/
├── package-flow-kit.sh              # 打包 + 安装脚本（核心）
├── flow-kit-bundle.tar.gz           # 分发包（.gitignore 排除）
├── FLOW-KIT-用户指南.md             # 完整用户指南（安装 / 命令 / 生命周期 / Goal 系统 / 工作流示例）
├── README.md                        # 本文件
├── flow-kit-ecosystem-guide.md      # 生态组件清单与架构文档
├── flow-kit-bundle/                 # 分发包源码（唯一维护源）
│   ├── flow-kit/                    # 核心引擎（GO.md / RULES.md / prompts / templates / reference）
│   ├── skills/                      # flow-* 技能定义
│   ├── hooks/                       # Stop + SessionStart 钩子系统（唯一源）
│   ├── brooks-lint/                 # 代码审查插件（12 本经典工程书籍驱动）
│   ├── lib/                         # install.sh 拆分模块
│   │   ├── install_core.sh          # flow-kit 核心安装
│   │   ├── install_skills.sh        # skills 安装
│   │   ├── install_brooks.sh        # brooks-lint 安装 + 动态版本号
│   │   └── install_hooks.sh         # hooks 安装 + specs 模板
│   └── install.sh                   # 安装主脚本（调度 lib/）
├── test/                            # bats-core 测试（72 tests）
│   ├── test_common.bats             # common.sh 函数测试
│   └── test_install.bats            # install.sh 参数解析测试
├── .specs/                          # 项目规格
│   ├── CONTEXT.md                   # 项目共享上下文（术语表 + 抽象索引 + 禁动清单）
│   ├── STATE.md                     # 项目状态
│   ├── CHANGELOG.md                 # change 历史
│   ├── LESSONS.md                   # 技术债与经验教训
│   ├── health/                      # M-health 巡检报告
│   └── archive/                     # 已归档 change
├── .gitignore
└── .claude/                         # Claude Code 项目配置
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

技术债记录在 `.specs/LESSONS.md`，由 brooks-lint 扫描 + 手动补充维护。

## 近期功能

- **gate_config L2/L3/both**：独立审查三层级开关（L2 子agent / L3 外部模型 / both 双层），支持预设名和数字简写
- **Pipeline Goal 0→7**：跨阶段全链执行，toll-gate + 门禁条件 + auto_advance/fallback
- **interrupt/checkpoint**：中断恢复机制，支持手动 `/flow checkpoint` + auto-checkpoint 自动写入（4种触发）
- **独立审查四层架构**：PRESET_MAP → Prompt → Hook → L2-blind-review 端到端
- **.done 真实性校验**：防 AI 伪造审查通过标记（三层威胁模型防护）
- **Hook 模块 31/32**：auto_advance + fallback hook 层兜底

详见 [FLOW-KIT-用户指南.md](./FLOW-KIT-用户指南.md) 的 gate_config、interrupt/checkpoint、独立审查章节。

## 快速开始

```bash
# 打包新 bundle
bash package-flow-kit.sh

# 安装到目标项目
tar xzf flow-kit-bundle.tar.gz
cd flow-kit-bundle && bash install.sh /path/to/target-project
```

## L3 外部审查凭证（必配，否则 L3 门禁死锁）

`gate_config` 含 L3 的阶段由 Stop hook 调**外部模型**产出，凭证缺失时 hook 不写 `.done`，
而 PreToolUse 守卫又禁止主 agent 自产 → commit / 阶段推进全部阻塞（工件上看不出原因）。

模板见 [`.claude/l3.env.example`](./.claude/l3.env.example)（含逐项说明）。最简 dsh 路径：

```bash
mkdir -p ~/.config/flow-kit && cp .claude/l3.env.example ~/.config/flow-kit/l3.env
chmod 600 ~/.config/flow-kit/l3.env && $EDITOR ~/.config/flow-kit/l3.env   # 填 BASE_URL / AUTH_TOKEN / 模型

# 让 dsh-web 服务加载它（否则 hook 子进程拿不到）
sudo mkdir -p /etc/systemd/system/dsh-web.service.d
printf '[Service]\nEnvironmentFile=-%s/.config/flow-kit/l3.env\n' "$HOME" \
  | sudo tee /etc/systemd/system/dsh-web.service.d/10-flow-kit-env.conf >/dev/null
sudo systemctl daemon-reload && sudo systemctl restart dsh-web
```

claude / opencode 路径：在 `~/.bashrc` 里 `set -a; . ~/.config/flow-kit/l3.env; set +a`。

**工件截断上限**（`max_artifact_chars`）不在环境变量里配 —— 它由项目级
`<项目>/.flow-kit/stop-hook.json`（dsh）或 `<项目>/.claude/stop-hook.json`（claude）读取，
缺省 20000。**大工件项目务必提高**，否则 L3 只看前 20000 字符、反复报
「NFR 缺失 / 锚点表被截断」假阳性。完整优先级链见模板文件末节。
