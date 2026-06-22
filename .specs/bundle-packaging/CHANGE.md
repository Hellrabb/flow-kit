# CHANGE: brooks-lint npm 工具离线打包

- **Change ID**: `bundle-packaging`
- **创建日期**: 2026-06-22
- **路径建议**: 完整（REQUIREMENT → DESIGN → TASK → DEV → TEST → REVIEW → INTEGRATION）
- **状态**: draft

---

## Why（为什么做）

brooks-lint 依赖 4 个外部 npm 工具（`depcheck`、`jscpd`、`knip`、`ts-prune`）进行代码分析。这些工具当前仅通过 `pnpm install -g` 在开发机上全局安装，不在 `flow-kit-bundle.tar.gz` 分发包内。

**痛点**：目标环境是离线 x86_64 Linux（CentOS 8），无法执行 `pnpm/npm install`。brooks-lint 安装后，AI 调用这些工具时会直接报 `command not found`，整套代码审查能力降级为纯 prompt 分析（缺失结构化数据输入）。

**触发原因**：flow-kit 分发包目前只包含静态文件（markdown/shell/配置），不包含 npm 工具运行时及其依赖树。

## What（做什么）

扩展 `package-flow-kit.sh` 和 `install_brooks.sh`，将 4 个 npm 工具及其完整依赖树打包进分发包，使目标离线环境安装后即可直接使用：

| 工具 | 版本 | 用途 | brooks-lint 关联 skill |
|---|---|---|---|
| `depcheck` | 1.4.7 | 检测未使用的 npm 依赖 | brooks-debt, brooks-sweep |
| `jscpd` | 5.0.11 | 检测代码重复/拷贝粘贴 | brooks-review, brooks-audit |
| `knip` | 6.17.1 | 检测未使用的文件/导出/依赖 | brooks-debt, brooks-sweep |
| `ts-prune` | 0.10.3 | 检测未使用的 TypeScript 导出 | brooks-debt, brooks-sweep |

核心工作：
1. `package-flow-kit.sh` 新增 **Part G**：从 pnpm store 提取 4 个工具的完整 npm 包（含依赖树），打包为自包含的 `brooks-tools/` 目录放入 bundle
2. `install_brooks.sh` 新增 `install_brooks_tools()`：安装时将工具解压到 `~/.claude/tools/brooks-lint/`，并创建 shim 到 `~/.local/bin/` 或写入 PATH 配置

## 影响面

- [x] 影响 `REQUIREMENT.md`（需定义离线工具安装的 Given/When/Then AC）
- [x] 影响 `DESIGN.md` / 引入新 ADR（打包策略：npm pack vs pnpm store 提取 vs tgz 缓存；shim 方案：PATH 注入 vs wrapper script）
- [ ] 影响现有 AC（不改变现有 brooks-lint 行为，仅补全缺失的工具链）
- [ ] 影响数据模型 / 迁移
- [ ] 影响外部 API 兼容性
- [ ] 仅修复 bug，无范围变化

## 范围排除（这次不做）

- **不打包 Node.js 运行时**：目标环境需自行安装 Node.js ≥ 18（CentOS 8 可用 `dnf module install nodejs:18`）。在 install.sh 中做前置检测 + 提示
- **不修改 brooks-lint 插件本身**：不改变 skill prompt 中的工具调用方式
- **不处理 pnpm 本身**：工具以 npm 扁平 node_modules 结构打包（不用 pnpm 虚拟存储），目标环境无需 pnpm
- **不覆盖 darwin/arm64/win32**：仅打包 linux-x64 二进制（CentOS 8 目标），后续可扩展多平台矩阵
- **不更新工具的 npm 版本**：锁定当前已安装版本（depcheck 1.4.7 / jscpd 5.0.11 / knip 6.17.1 / ts-prune 0.10.3）

## 验收线（粗粒度，不是 AC）

1. 在无网络连接的 CentOS 8 x86_64 环境（或 Docker 模拟）上，解压 bundle 并执行 `./install.sh --global` 后，`depcheck`、`jscpd`、`knip`、`ts-prune` 四个命令可直接在 shell 中执行
2. 打包后 `flow-kit-bundle.tar.gz` 体积增幅 ≤ 100 MB（以 4 个工具及其依赖树的典型大小为基准）
3. 现有 `package-flow-kit.sh` 的非 brooks 部分（Part A-E）行为不变，bats 测试全部通过

## 风险与未知

- **Node.js 版本兼容**：当前开发机 Node v22.22.1，CentOS 8 dnf module 默认提供 Node.js 18。需确认 4 个工具在 Node 18 上可运行
- **pnpm 虚拟存储提取**：pnpm 使用 content-addressable store（`~/.local/share/pnpm/store/v10`），直接提取 node_modules 需还原符号链接结构。改用 `npm pack` 逐工具打包 .tgz 可能是更简单的方案
- **glibc 版本**：npm 原生扩展（如 jscpd 可能依赖的 tree-sitter 等）需与 CentOS 8 的 glibc 2.28 兼容
- **bundle 体积预估**：4 个工具 + 依赖树估计 50-80 MB（含 node_modules 扁平化），打包后约 10-20 MB（.tar.gz 压缩）

---

> 后续 AC 与设计细节进入 `REQUIREMENT.md` / `DESIGN.md`，本文件不再扩展。
