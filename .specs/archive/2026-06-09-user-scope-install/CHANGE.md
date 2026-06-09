# CHANGE: 支持 flow-kit 核心引擎 user-scope 全局安装

- **Change ID**: `user-scope-install`
- **创建日期**: 2026-06-09
- **路径建议**: 中等（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

当前 flow-kit 的 `flow-kit/` 核心引擎（prompts / templates / references）必须放在**每个项目根目录**下，导致：
- 多项目用户需要在每个项目复制一份完全相同的 `flow-kit/` 目录（~300KB，81 文件）
- 升级 flow-kit 核心时需要逐个项目更新
- 与 skills 的 user-scope 架构不一致：skills 已经是 `~/.claude/skills/` 全局共享，核心引擎却仍是项目级

目标：将核心引擎提升到 `~/.claude/flow-kit/`（用户级），项目通过 symlink 引用，实现单份安装、全局共享。

## What（做什么）

1. **install.sh 新增 `--user` 安装模式**：将 `flow-kit/` 核心安装到 `~/.claude/flow-kit/`，并在目标项目创建 symlink
2. **flow-go SKILL.md 新增回退查找逻辑**：先查项目 `flow-kit/`，不存在则回退到 `~/.claude/flow-kit/`
3. **保持向后兼容**：已有项目级 `flow-kit/` 目录不受影响，项目级优先（允许项目锁定版本）

## 影响面

- [x] 影响 `REQUIREMENT.md`（新增 `--user` 模式的安装行为规格）
- [x] 影响 `DESIGN.md`（两级查找策略 + install.sh 模式设计 + 跨平台 symlink 兼容）
- [ ] 不影响现有 AC
- [ ] 不影响数据模型 / 迁移
- [ ] 不影响外部 API 兼容性
- [ ] 非 bug 修复

## 范围排除（这次不做）

- 不把 hooks/settings 从项目级提升到 user-scope（hooks 本质是项目级行为，每个项目的 stop-hook 检查项不同）
- 不修改 15 个非入口 skill（flow-dev / flow-design / flow-test 等）——它们通过 symlink 透明解析 `flow-kit/` 路径，无需改动
- 不改变 `.specs/` 和 `.flow-active` 状态文件的存储位置（这些是项目级产物）
- 不做 `--global` flag 的完整实现（`--user` 是 `--global` 的子集，后续可扩展）

## 验收线（粗粒度，不是 AC）

1. 用户在新项目上执行 `./install.sh --user <project>` 后，`/flow-go` 可用，无需项目内有 `flow-kit/` 物理目录（仅 symlink）
2. 已有项目级 `flow-kit/` 目录的项目行为不变（向后兼容）
3. `install.sh --dry-run --user <project>` 正确展示将要创建的 symlink 路径

## 风险与未知

- **Symlink 跨平台**：Windows 上 symlink 需要管理员权限或 Developer Mode。当前 flow-kit 主要面向 Linux/macOS，暂不处理 Windows 兼容
- **Claude Code Read 工具对 symlink 的解析**：需验证 CC 的 Read/Bash/Glob 工具是否能正确跟随 symlink 解析相对路径。风险低——绝大多数 Unix 工具透明处理 symlink
- **Git 对 symlink 的行为**：Git 会追踪 symlink 本身（而非其目标内容）。项目中 `flow-kit → ~/.claude/flow-kit` 的 symlink 在不同机器上可能断链。需在安装文档中说明

---
