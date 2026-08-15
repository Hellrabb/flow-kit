---
name: flow-kit-install
description: |
  Install flow-kit from a bundle to the current project.
  Triggers: "install flow-kit", "setup flow-kit", "flow-kit-install", "安装flow-kit",
  "帮我装flow-kit", "帮我安装", "装一下flow-kit", "部署flow-kit", "/flow-kit-install",
  "set up flow-kit in this project", any request to install/setup/deploy flow-kit from a bundle.
---

# flow-kit-install — 一键安装 flow-kit 到项目

## 角色

你是 flow-kit 安装助手。用户有一个 `flow-kit-bundle` 目录，你需要帮他把 flow-kit 安装到当前项目。

## 输入

- 用户可能指定 bundle 路径，也可能不指定
- 默认按以下顺序探测：
  1. 用户指定的路径
  2. `~/flow-kit-export/flow-kit-full-*/`（最新打包导出）
  3. `./flow-kit-bundle/`（项目内）
  4. 问用户 bundle 在哪

## 安装步骤

### 步骤 0：探测 bundle

```bash
# Try common locations
ls ~/flow-kit-export/flow-kit-full-*/install.sh 2>/dev/null || ls ./flow-kit-bundle/install.sh 2>/dev/null
```

如果找不到，问用户：「flow-kit 安装包目录在哪？请提供路径。」

### 步骤 1：预览模式 (dry-run)

```bash
bash <bundle_dir>/install.sh --dry-run <project_dir>
```

向用户展示将要安装的内容，确认是否继续。

### 步骤 2：执行安装

```bash
bash <bundle_dir>/install.sh <project_dir>
```

### 步骤 3：安装后验证

安装完成后必须验证：

```bash
# 验证清单
ls <project_dir>/flow-kit/GO.md && echo "✅ flow-kit core"
ls <project_dir>/.claude/hooks/stop/00-gate.sh && echo "✅ hooks"
ls ~/.claude/skills/flow-go/SKILL.md && echo "✅ skills"
ls <project_dir>/.claude/stop-hook.json && echo "✅ stop-hook config"
jq -e '.hooks.Stop' <project_dir>/.claude/settings.json >/dev/null 2>&1 && echo "✅ hook wiring" || echo "⚠️ hook wiring not found in settings.json"
```

### 步骤 4：入场引导

安装完成后，告诉用户：

```
✅ flow-kit 安装完成。

下一步：
  /flow-go                    ← 首次使用，会自动提示跑 intel-scan
  /flow-go <你的新需求>       ← 开始你的第一个 change
```

## 安装到 dsh（DeepSeek Harness）——推荐 dsh 用户优先走此路径

dsh 环境不需要 `install.sh`，flow-kit 已打包为 `dsh-flow-kit` npm 插件：

```bash
# 本地构建包（在 flow-kit 仓库内）
bash package-dsh-plugin.sh

# 安装到 profile（本质是 pnpm add）
dsh plugin --profile <profile-name> add file:/path/to/dist/dsh-flow-kit
# 或 npm 发布后：
dsh plugin --profile <profile-name> add dsh-flow-kit
```

验证：

```bash
dsh --profile <profile-name> --dump-config | grep -A 7 'dsh-flow-kit'
# 期望看到 - id: flow-kit，inject: [commands, skills]
```

- dsh 下 `/flow` 命令直接可用；23 个 flow-*/brooks-* skill 由插件自动注册
- hooks 由插件内 `hook-bridge.js` 监听 `tools/pre-execute` / `agent/status` /
  `agent/created` 自动触发，**不写 `.claude/settings.json`**
- 项目内运行时配置落在 `.flow-kit/stop-hook.json`（首次运行时从包默认值落盘）
- 完整 claude/opencode 安装路径见下文

## 安装到 Claude Code / opencode（install.sh 路径）

以下步骤适用于 claude code / opencode 项目：

## 实现细节

- 安装脚本幂等：重复运行不会覆盖已有配置（settings.json hooks 除外）
- claude/opencode 的 skills 每次覆盖安装到 `~/.claude/skills/`
- dsh 的 skills 由插件 `ctx.skills.register()` 注册，无需复制到用户目录
- `25-project.sh`（模块 F）是项目特定检查模板，应根据项目需要修改或禁用
