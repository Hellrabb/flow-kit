# REQUIREMENT: brooks-lint npm 工具离线打包

- **Change ID**: `bundle-packaging`
- **关联**: `@.specs/bundle-packaging/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为**在离线 CentOS 8 上部署 flow-kit 的工程师**，我想 `./install.sh --global` 完成后 4 个 brooks-lint 工具直接可用，以便 brooks-lint 的代码审查能力完整运作，无需手动补齐依赖。
- **US-2**：作为 **flow-kit bundle 维护者**，我想 `package-flow-kit.sh` 一键打包时自动包含 npm 工具依赖树，以便每次发版不会遗漏工具。
- **US-3**：作为**在目标机器上使用 brooks-lint 的 AI**，我想 `depcheck` / `jscpd` / `knip` / `ts-prune` 在 PATH 中可被直接调用，以便按 skill prompt 指令产出结构化分析数据。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · depcheck 离线可用

- **Given** 一台离线 x86_64 Linux（CentOS 8 或等效 Docker 镜像），已安装 Node.js ≥ 18，已解压 flow-kit-bundle
- **When** 用户执行 `./install.sh --global`
- **Then** `depcheck --version` 返回 `1.4.7`，退出码 0
- **验证方式**: `depcheck --version`

### AC-2 · jscpd 离线可用

- **Given** 同 AC-1 环境
- **When** 安装完成后执行 `jscpd --version`
- **Then** 输出含 `5.0.11`，退出码 0
- **验证方式**: `jscpd --version`

### AC-3 · knip 离线可用

- **Given** 同 AC-1 环境
- **When** 安装完成后执行 `knip --version`
- **Then** 输出含 `6.17.1`，退出码 0
- **验证方式**: `knip --version`

### AC-4 · ts-prune 离线可用

- **Given** 同 AC-1 环境
- **When** 安装完成后执行 `ts-prune --version`
- **Then** 输出含 `0.10.3`，退出码 0
- **验证方式**: `ts-prune --version`

### AC-5 · 打包脚本产出 brooks-tools 目录

- **Given** 开发机上有 pnpm store 且 4 个工具已全局安装
- **When** 执行 `bash package-flow-kit.sh`
- **Then** 生成的 `flow-kit-bundle.tar.gz` 解压后包含 `brooks-tools/` 目录，内含 4 个工具的完整 node_modules 及 bin wrapper
- **验证方式**: `tar tzf flow-kit-bundle.tar.gz | grep 'brooks-tools/' | wc -l` 结果 ≥ 20

### AC-6 · Node.js 缺失时给出明确提示

- **Given** 一台未安装 Node.js 的离线 CentOS 8
- **When** 执行 `./install.sh --global`
- **Then** brooks-tools 安装步骤输出 `⚠️ Node.js 未安装，跳过 brooks-lint 工具安装。请先安装 Node.js ≥ 18：dnf module install nodejs:18`，退出码仍为 0（不阻断其他组件安装）
- **验证方式**: 手动检查安装输出含上述提示文本

### AC-7 · 现有打包不退化

- **Given** 开发机上正常执行 `bash package-flow-kit.sh`
- **When** 对比改动前后的 tarball 内容（排除新增的 brooks-tools/）
- **Then** Part A-F 的文件清单完全一致，bats 测试全通过（72 tests）
- **验证方式**: `npx bats test/` 全部 72 tests 通过

### AC-8 · 安装后的工具可被直接调用（不在 subshell 中丢 PATH）

- **Given** 安装完成后打开一个新的 bash shell
- **When** 执行 `which depcheck && which jscpd && which knip && which ts-prune`
- **Then** 四个命令均返回有效路径（非空），退出码全为 0
- **验证方式**: `which depcheck jscpd knip ts-prune`

---

## 范围切分

### v1（本次必做）

- `package-flow-kit.sh` 新增 Part G：从 pnpm store 提取 4 个工具，扁平化为自包含 `brooks-tools/` 目录
- `install_brooks.sh` 新增 `install_brooks_tools()`：解压 `brooks-tools/` → `~/.claude/tools/brooks-lint/`，创建 bin shim
- `install.sh` 新增 Node.js 前置检测（`check_node()`），缺失时提示但不阻断
- 仅打包 **linux-x64** 平台二进制
- 更新 `CONTEXT.md` 术语表（新增 brooks-tools 相关术语）

### v2（下一轮考虑，不本次）

- 多平台支持矩阵（darwin-arm64、win32-x64），根据打包机平台自动选择
- 工具版本由 brooks-lint 配置文件声明（而非硬编码在打包脚本中），支持版本自动检测
- `--update` 模式下增量更新工具（仅下载/替换版本变化的部分，不全量重新打包）
- CentOS 7 / RHEL 7 兼容性验证（glibc 2.17）

### out（永远不做）

- 在 bundle 中附带 Node.js 运行时（各目标环境 Node 版本策略不同，且体积过大）
- 修改 brooks-lint skill prompt 中的工具调用指令
- 在目标环境使用 pnpm 作为包管理器（工具以扁平 node_modules 交付，无需 pnpm）
- 支持非 npm 来源的工具（如 Go 编译的二进制、Python 包）——这些属于另外的 change

---

## 非功能性需求

- **性能**: 工具安装步骤 ≤ 30 秒（纯文件复制，不联网、不编译）。`depcheck` / `jscpd` / `knip` / `ts-prune` 首次执行启动时间 ≤ 3 秒
- **可访问性**: 无（CLI 工具）
- **安全**: 打包脚本应校验源工具路径存在性，避免空目录打入 tarball。安装脚本不应修改目标环境全局 PATH 之外的文件（仅写 `~/.claude/tools/` 和 `~/.local/bin/`）
- **兼容性**: 目标环境 CentOS 8 x86_64（glibc 2.28）、Node.js ≥ 18。打包机需有 pnpm 和 4 个工具的全局安装
- **可观测性**: 打包脚本输出工具名称、版本、文件数量。安装脚本输出每个工具的安装状态（✅/⚠️）。`--dry-run` 模式显示将安装的工具清单

## 依赖与假设

- **依赖**：pnpm store（`~/.local/share/pnpm/store/v10`）中存在 4 个工具的缓存；开发机 Node.js ≥ 18
- **假设**：目标环境已安装 Node.js ≥ 18（通过 `dnf module install nodejs:18` 或 nvm）；目标环境 `/usr/local/bin` 或 `~/.local/bin` 在 PATH 中；4 个工具在 Node 18 上可正常运行（需 DESIGN 阶段验证）；pnpm 虚拟存储的符号链接结构可以用 `npm pack` + 解压方式绕过

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
