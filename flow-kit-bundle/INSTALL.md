# flow-kit-bundle 安装指南

将 flow-kit 全套系统迁移到新项目/新环境的步骤。

---

## 包内容

```
flow-kit-bundle/
├── flow-kit/          # 核心：GO.md + RULES + prompts + reference + templates
├── hooks/             # Stop hook 模块链 + SessionStart hook
│   ├── session-start/ # flow-kit-resume.sh, stop-report-reminder.sh
│   └── stop/          # 00-gate → 01~99 模块链 + lib/
├── skills/            # 16 个 flow-* skill
├── config/            # stop-hook.json 模板 + settings.json hooks 配置片段
├── RTK.md             # Rust Token Killer 配置
└── INSTALL.md         # 本文件
```

---

## 安装步骤

### 1. 部署 flow-kit 核心

将 `flow-kit/` 放到**项目根目录**下：

```bash
cp -r flow-kit-bundle/flow-kit /path/to/your-project/flow-kit
```

> `flow-kit/` 是项目级目录，每个项目都需要一份。AI 在阶段执行时通过 `flow-kit/prompts/`、`flow-kit/reference/` 等路径引用。

### 2. 部署 Hook 脚本

```bash
# 创建目标目录
mkdir -p /path/to/your-project/.claude/hooks

# 复制全部 hook
cp -r flow-kit-bundle/hooks/* /path/to/your-project/.claude/hooks/
```

### 3. 部署 Skills（全局）

Skills 是用户级配置，放到全局 `~/.claude/skills/`：

```bash
mkdir -p ~/.claude/skills

for skill_dir in flow-kit-bundle/skills/*/; do
  name=$(basename "$skill_dir")
  rm -rf ~/.claude/skills/"$name"      # 覆盖旧版
  cp -r "$skill_dir" ~/.claude/skills/
done
```

### 4. 配置 settings.json Hook 接线

编辑项目 `.claude/settings.json`，合并 `config/settings-hooks.json` 中的 hooks 配置：

```bash
# 方式A：如果项目尚未配置 hooks，直接追加
jq '. + {hooks: input.hooks}' \
  /path/to/your-project/.claude/settings.json \
  flow-kit-bundle/config/settings-hooks.json \
  > tmp.json && mv tmp.json /path/to/your-project/.claude/settings.json

# 方式B：手动编辑，确保 Stop + SessionStart 都存在
```

关键 hook 接线：
- **Stop** → `bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/stop/00-gate.sh"`
- **SessionStart (startup)** → `stop-report-reminder.sh`
- **SessionStart (startup|clear)** → `flow-kit-resume.sh`

### 5. 部署 stop-hook.json 配置

```bash
cp flow-kit-bundle/config/stop-hook.json /path/to/your-project/.claude/stop-hook.json
```

按项目需要编辑模块开关。默认所有模块启用。

### 6. 部署 RTK.md（可选）

RTK 是用户级配置，参见 `~/.claude/CLAUDE.md` 的 `@RTK.md` 引用：

```bash
cp flow-kit-bundle/RTK.md ~/.claude/RTK.md
```

---

## 首次使用（新项目）

1. 在项目根启动 Claude Code
2. 输入 `/flow-go` → 自动检测新项目 → 提示运行 `intel-scan`
3. 选择跑入场扫描，生成 `.specs/CONTEXT.md`
4. 之后 `/flow-go <你的需求>` 即可进入完整开发闭环

---

## 从旧项目迁移（已使用 flow-kit）

如果你在一个已使用 flow-kit 的项目上更新 hook/技能：

```bash
# 更新 hooks（覆盖）
cp -r flow-kit-bundle/hooks/* /path/to/project/.claude/hooks/

# 更新 skills（覆盖）
for d in flow-kit-bundle/skills/*/; do
  cp -r "$d" ~/.claude/skills/$(basename "$d")/
done

# 更新 flow-kit 核心（覆盖）
rsync -a flow-kit-bundle/flow-kit/ /path/to/project/flow-kit/
```

> 不会影响 `.specs/`、`.flow-active`、`stop-hook-state.json` 等运行时状态。

---

## 依赖

- **bash** 4.0+
- **jq**（JSON 处理，hook 脚本依赖）
- **git**（可选，模块 C 依赖）

```bash
# Debian/Ubuntu
sudo apt-get install jq git

# macOS
brew install jq git
```

---

## 项目特定化说明

### 25-project.sh（模块 F）

`hooks/stop/25-project.sh` 原本包含 NanoClaw 特定的检查（容器构建缓存、pnpm 供应链等）。
这些检查在新项目中可能不适用。

**两种处理方式：**

1. **禁用整个模块**：在 `stop-hook.json` 中设置 `modules.project.enabled = false`
2. **定制检查逻辑**：修改 `25-project.sh`，替换为你的项目特定检查

### 内存目录推导

`common.sh` 中的 `MEMORY_DIR` 现在从 `PROJECT_ROOT` 动态推导，遵循 Claude Code 的约定：
`${HOME}/.claude/projects/<路径中/替换为->/memory`

无需手动配置。

---

## 验证安装

```bash
# 检查 hook 脚本可执行
ls -la /path/to/project/.claude/hooks/stop/00-gate.sh
ls -la /path/to/project/.claude/hooks/session-start/flow-kit-resume.sh

# 检查 skills 存在
ls ~/.claude/skills/flow-go/SKILL.md

# 检查 flow-kit 核心
ls /path/to/project/flow-kit/GO.md

# 检查 hook 接线
jq '.hooks' /path/to/project/.claude/settings.json
```

启动 Claude Code，SessionStart 时应看到 flow-kit-resume banner（如果 `.flow-active` 存在）。
Stop 时应看到 stop-hook 报告输出到 stderr。
