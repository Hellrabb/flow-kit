# DESIGN: brooks-lint npm 工具离线打包

- **Change ID**: `bundle-packaging`
- **关联**: `@.specs/bundle-packaging/REQUIREMENT.md`、`@.specs/CONTEXT.md`
- **作者**: AI（Architect 角色）+ 人工 review

---

## 0. 技术栈选定

> 纯 Bash 脚本项目（CLI/打包工具），非 Web 项目。技术栈继承 `CONTEXT.md` 已锁决策。

- **语言/运行时**: Bash（`#!/bin/bash`，`set -euo pipefail`）
- **打包工具**: `tar` + `gzip`（沿用现有）
- **npm 工具提取**: `npm pack`（从 pnpm 全局安装中提取依赖树）+ `tar xf` 解压
- **目标环境依赖**: Node.js ≥ 18（不打包，仅做前置检测）
- **部署**: Shell 脚本（`install.sh` 调度 → `install_brooks.sh` 子模块）
- **理由**: 纯 CLI 项目，无前端/后端/数据库。技术栈已在 `CONTEXT.md` 锁定为 Bash + tar/gzip 分发模式，本次仅在该栈上新增 npm 工具提取能力
- **明确排除**: Docker 镜像分发（过度复杂，不符合 flow-kit 分发包轻量定位）；pnpm deploy（目标环境无 pnpm）

---

## 0.5 既有架构对齐（brownfield 必填）

### 0.5.1 本次 change 触碰的既有模块

```
触碰模块（grep 出来的实际清单）：
- package-flow-kit.sh（全部 319 行 · 新增 Part G + 修改 Part F 附近 mkdir 行）
- flow-kit-bundle/lib/install_brooks.sh（112 行 · 新增 install_brooks_tools() 函数）
- flow-kit-bundle/install.sh（287 行 · 新增 check_node() + --no-brooks-tools flag）

新增模块：
- flow-kit-bundle/brooks-tools/（目标 tar.gz 内的工具目录 · npm pack 提取产物）
- flow-kit-bundle/lib/install_brooks_tools.sh（新文件 · brooks-tools 安装逻辑拆分为独立模块）

禁动清单（与本次无关，AI 不许"顺手"碰）：
- package-flow-kit.sh Part A-E（flow-kit 核心引擎/技能/Stop Hook/配置/README 打包逻辑）
- install_brooks.sh install_brooks_lint() 函数（现有 brooks-lint 插件安装逻辑）
- flow-kit-bundle/hooks/（Stop/SessionStart hook 系统 · 与本次完全无关）
- flow-kit-bundle/skills/（flow-* skill 包装器 · 与本次完全无关）
- flow-kit-bundle/flow-kit/（核心引擎 · 与本次无关）
```

### 0.5.2 既有抽象沿用对照表

| 本次需要 | 既有有没有？路径 | 决定 |
|---|---|---|
| 版本号动态读取 | `install_brooks.sh` 的 jq + grep fallback 模式 | **沿用**（D7 版本检测模式） |
| 安装步骤输出格式 | `install_brooks.sh` 的 `echo "═══ ... ═══"` + `echo "   ✅/⚠️ ..."` 风格 | **沿用** |
| 打包 staging 目录管理 | `package-flow-kit.sh` 的 `$STAGING/` + `mkdir -p` 模式 | **沿用** |
| 命令行 flag 跳过组件 | `install.sh` 的 `--no-brooks` / `--no-hooks` / `--no-skills` 模式 | **沿用**（新增 `--no-brooks-tools`） |
| 工具版本检测 | `install_brooks.sh` jq 优先 + grep fallback | **沿用** |
| npm 依赖打包 | 没有 | **新建**（理由：流-kit 首次引入 npm 依赖打包需求）|

### 0.5.3 沿用模式 vs 引入新模式

```
- Shell 错误处理：**沿用** set -euo pipefail（所有脚本顶层）
- 打包 Part 结构：**沿用** Part A-G 编号 + ═══ 分隔符 + emoji 标记
- 安装函数命名：**沿用** install_<component>() 蛇形命名（既有一致）
- npm 工具离线打包：**引入新模式** → 理由：流-kit 历史上只打包静态文件，首次需从 pnpm store 提取 npm 包以支持离线环境
- 工具 shim 生成：**引入新模式** → 理由：既有无类似机制（PATH 注入），需新建
```

---

## 1. 决策清单

| # | 决策 | 备选 | 选择理由 | 取舍代价 |
|---|---|---|---|---|
| D1 | **使用 `npm pack` 逐工具打包**（非 pnpm store 直接提取） | ① 直接从 pnpm store 复制虚拟存储 → 需还原符号链接，目标环境无 pnpm 无法使用 ② `pnpm deploy` → 需要 pnpm，目标环境没有 ③ `npm pack` → 产出标准 .tgz，解压即用，无符号链接依赖 | `npm pack` 是 npm 内置命令，无需额外工具。每个工具打包为独立 .tgz，可增量更新。npm pack 自动解析依赖树并扁平化，解压后的 node_modules 可直接被 Node 加载 | 需先 `npm install -g` 再 `npm pack`（或在打包脚本中模拟 `npm pack <pkg>@<ver>` 从 npm registry 下载），离线环境不可重新打包。打包脚本需网络访问 npm registry（或本地 npm cache） |
| D2 | **安装路径 `~/.claude/tools/brooks-lint/`**（非系统路径） | ① `/usr/local/lib/brooks-tools/` → 需 sudo，侵入系统 ② `~/.claude/tools/brooks-lint/` → 用户空间，与其他 claude 组件共处同一父目录，无需 sudo | `~/.claude/` 是 flow-kit 生态的根目录（已有 `~/.claude/flow-kit/`、`~/.claude/plugins/`、`~/.claude/skills/`），将 tools 放在同级符合项目惯例 | 如果多个用户共用一台机器，每个用户需独立安装（但 flow-kit 本身就是 per-user 安装，不是系统级工具） |
| D3 | **PATH 集成用 shim 脚本**（放在 `~/.local/bin/`） | ① 修改 `~/.bashrc` 添加 PATH → 侵入用户 shell 配置，卸载难清理 ② shim 脚本 `~/.local/bin/<tool>` → 每个 shim 是 3 行 `#!/bin/sh` + exec 到真实路径，安装/卸载只需创建/删除 | shim 方案干净、可逆、不侵入 shell 配置。`~/.local/bin/` 是 systemd file-hierarchy(7) 推荐的用户可执行文件路径，多数 Linux 发行版默认在 PATH 中 | 如果用户 PATH 不含 `~/.local/bin/`，shim 不可见。安装时检测并提示用户添加 PATH |
| D4 | **工具版本硬编码**（非自动检测） | ① 硬编码版本号在 `package-flow-kit.sh` 顶部 → 简单、可复现、发版审计友好 ② 运行时 `pnpm list -g` 自动检测 → 灵活但非确定性，离线打包机可能和开发机版本不一致 | v1 选择硬编码。每次升级 brooks-lint 时需要同步更新版本号，但换来的是确定性打包和审计友好 | 升级时需手动改 2 处（打包脚本版本号 + 安装脚本版本检查）。v2 可改为从配置文件读取 |
| D5 | **`install_brooks_tools` 作为独立 lib 文件**（非内嵌在 install_brooks.sh） | ① 内嵌在 `install_brooks.sh` → 单文件膨胀（当前 112 行 → 预计 200+ 行），不符合"lib 模块拆分"设计 ② 独立 `lib/install_brooks_tools.sh` → 与现有 `install_core.sh` / `install_hooks.sh` / `install_skills.sh` 一致 | 沿用既有的 lib 拆分模式，一文件一职责。install.sh 通过 `source` 按需加载 | 多一个文件，安装时需额外 `cp` 到 bundle |
| D6 | **npm pack 从 registry 下载**（非从本地 pnpm store 提取） | ① 从 pnpm global store 提取 → 需要解析 pnpm 虚拟存储的符号链接，复杂且 fragile ② `npm pack <pkg>@<ver>` 从 registry → 确定性高，产出的 .tgz 是标准的 npm 包格式 | 打包脚本 `npm pack depcheck@1.4.7` 直接从 registry 拉取（利用本地 npm cache 加速），避免依赖 pnpm 内部实现。产出的 .tgz 通用性强 | 需要打包机有网络连接（当前 package-flow-kit.sh 不联网，这是首次引入联网步骤）。后续可加 `--offline` 模式从本地 cache 读取 |

---

## 2. 数据流 / 架构图

### 打包流程（开发机）

```
  package-flow-kit.sh
        │
        ├── Part A-E（不变 · 现有 flow-kit 核心打包）
        │     flow-kit/ + skills/ + hooks/ + config/ → $STAGING/
        │
        ├── Part F（不变 · brooks-lint 插件打包）
        │     brooks-lint/plugin/ → $STAGING/brooks-lint/plugin/
        │
        └── Part G（新增 · npm 工具离线打包）
              │
              ├── 1. 检测 npm 可用性
              │      └── command -v npm || { echo "⚠️ npm 未安装，跳过"; return; }
              │
              ├── 2. 逐工具 npm pack（利用本地 cache 加速）
              │      for tool in depcheck@1.4.7 jscpd@5.0.11 knip@6.17.1 ts-prune@0.10.3; do
              │        npm pack $tool --pack-destination=$STAGING/brooks-tools/packs/
              │      done
              │      产出: depcheck-1.4.7.tgz, jscpd-5.0.11.tgz, knip-6.17.1.tgz, ts-prune-0.10.3.tgz
              │
              ├── 3. 解压 + 合并为扁平 node_modules
              │      for tgz in brooks-tools/packs/*.tgz; do
              │        tar xzf $tgz -C $STAGING/brooks-tools/extracted/<name>/
              │      done
              │      # 合并各工具的 node_modules 到共享顶层
              │      # 合并各工具的 bin/ 到 brooks-tools/bin/
              │      产出: brooks-tools/
              │             ├── node_modules/  （所有工具共享的依赖树）
              │             ├── bin/           （所有工具的 bin 入口）
              │             └── packs/         （原始 .tgz 文件 · 备查）
              │
              └── 4. 生成 manifest.json
                     { "tools": { "depcheck": "1.4.7", ... },
                       "platform": "linux-x64",
                       "node_min": "18.0.0" }
```

### 安装流程（目标离线环境）

```
  install.sh --global
        │
        ├── check_node()                    ← 新增
        │     command -v node || echo "⚠️ Node.js 未安装..."
        │
        ├── install_core.sh                 （不变）
        ├── install_skills.sh               （不变）
        ├── install_hooks.sh                （不变）
        │
        ├── install_brooks.sh               （不变 · 安装 brooks-lint 插件主体）
        │     └── install_brooks_lint()
        │
        └── install_brooks_tools.sh         ← 新增
              └── install_brooks_tools()
                    │
                    ├── 1. 检测 Node.js
                    │     command -v node || { 提示 + return; }
                    │
                    ├── 2. 复制 brooks-tools/ → ~/.claude/tools/brooks-lint/
                    │     rsync -a $SCRIPT_DIR/brooks-tools/ ~/.claude/tools/brooks-lint/
                    │
                    ├── 3. 生成 shim → ~/.local/bin/
                    │     for tool in depcheck jscpd knip ts-prune; do
                    │       cat > ~/.local/bin/$tool << 'SHIM'
                    │         #!/bin/sh
                    │         exec ~/.claude/tools/brooks-lint/bin/$tool "$@"
                    │       SHIM
                    │       chmod +x ~/.local/bin/$tool
                    │     done
                    │
                    ├── 4. 检测 ~/.local/bin 是否在 PATH
                    │     echo "PATH" | grep -q "$HOME/.local/bin" || {
                    │       echo "⚠️ ~/.local/bin 不在 PATH 中，请添加:"
                    │       echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
                    │     }
                    │
                    └── 5. 验证安装
                          depcheck --version && jscpd --version && knip --version && ts-prune --version
```

### 目标环境目录结构

```
~/.claude/
├── flow-kit/           （已有 · 核心引擎）
├── skills/             （已有 · flow-* skills）
├── plugins/            （已有 · brooks-lint 插件）
│   └── cache/brooks-lint-marketplace/brooks-lint/<version>/
└── tools/              ← 新增
    └── brooks-lint/
        ├── bin/
        │   ├── depcheck -> ../node_modules/.bin/depcheck
        │   ├── jscpd    -> ../node_modules/.bin/jscpd
        │   ├── knip     -> ../node_modules/.bin/knip
        │   └── ts-prune -> ../node_modules/.bin/ts-prune
        ├── node_modules/
        │   ├── depcheck/
        │   ├── jscpd/
        │   ├── knip/
        │   ├── ts-prune/
        │   └── ...（共享依赖）
        └── manifest.json

~/.local/bin/
├── depcheck    → shim → exec ~/.claude/tools/brooks-lint/bin/depcheck
├── jscpd       → shim → exec ~/.claude/tools/brooks-lint/bin/jscpd
├── knip        → shim → exec ~/.claude/tools/brooks-lint/bin/knip
└── ts-prune    → shim → exec ~/.claude/tools/brooks-lint/bin/ts-prune
```

---

## 4. ADR 索引

本次无不可逆项目级决策（所有决策均为 change 级实现细节，不涉及 ARCHITECTURE 层）。本次不创建 ADR。

---

## 5. 风险

| # | 风险 | 影响 | 概率 | 缓解 |
|---|---|---|---|---|
| R1 | **Node.js 版本不兼容**：4 个工具在 Node 18（CentOS 8 dnf 默认）上报 syntax error 或运行时崩溃 | brooks-lint 工具链不可用，降级为纯 prompt 分析 | 中 | DESIGN 阶段手动验证每个工具在 Node 18 上的 `--version` 输出；若某工具不兼容 → 降级该工具版本或标注最低 Node 版本要求 |
| R2 | **glibc 不兼容**：npm 原生扩展（如 jscpd 依赖的 node_modules 中的 C++ addon）在 CentOS 8 glibc 2.28 上加载失败 | 特定工具无法启动（尤以 jscpd 风险最高——它可能依赖 tree-sitter 或其他原生模块） | 中 | 打包时记录每个工具的 node_modules 中是否含 `.node` 原生扩展；若有 → 在 Docker CentOS 8 镜像中预验证；若失败 → 尝试 `--platform=linux` npm pack 或降级到纯 JS 版本 |
| R3 | **npm pack 打包体积失控**：4 个工具各自的依赖树重叠部分少，合并后的 node_modules 超过 120 MB（AC-2 上限 100 MB 可能突破） | tarball 过大，影响传输和存储 | 中 | 打包后检测 `du -sh brooks-tools/` ；超过 100 MB → 使用 `npm dedupe` 扁平化依赖树；若仍超 → 与用户确认是否接受更大体积或精简工具集 |
| R4 | **`~/.local/bin` 不在 PATH**：部分 CentOS 8 最小化安装未在 `.bash_profile` 中加入此路径 | shim 不可见，用户执行 depcheck 报 command not found | 高 | 安装时显式检测 PATH，含 `~/.local/bin` 时静默通过；不含时输出清晰提示（含具体命令）。install.sh README 文档中也加说明 |
| R5 | **npm pack 网络依赖**：打包机无网络时 `npm pack` 从 registry 拉取失败 | 无法完成打包，Part G 跳过 | 低（打包通常在联网 CI/开发机执行） | 先检查 `npm cache` 是否有本地缓存；有缓存时 `npm pack --prefer-offline` 可离线工作；无缓存时跳过 Part G 并输出明确提示 |
| R6 | **安装脚本侵扰既有环境**：shim 覆盖用户已有的同名 `~/.local/bin/depcheck` | 用户原有 depcheck 被覆盖，可能版本不同 | 低 | 安装前检测 shim 目标路径是否已有文件；若存在 → 输出 "⚠️ ~/.local/bin/depcheck 已存在，跳过（已有版本：$(depcheck --version)）"，不覆盖 |

---

## 6. 不在范围

- 不在 bundle 中附带 Node.js 运行时（体积约 180 MB 压缩后，远超 bundle 核心大小）
- 不修改 brooks-lint skill prompt 中的工具调用方式
- 不处理 darwin-arm64 / win32-x64 平台的 npm 二进制（仅 linux-x64）
- 不做增量工具更新（每次发版全量替换 `brooks-tools/` 目录）
- 不自动安装 npm registry 或配置私有 registry mirror（目标环境完全离线）

---

## 9. 架构沉淀建议

### 9.1 新增的可复用抽象

| 路径 | 能力 | 触发场景 | 复用建议 |
|---|---|---|---|
| `flow-kit-bundle/lib/install_brooks_tools.sh` | npm 工具的离线安装通用函数（shim 生成 + PATH 检测 + 版本验证） | 将来任何需要"打包 npm 工具到离线环境"的 change | 函式 `install_brooks_tools()` 可参数化（工具列表 + 目标路径），被其他 install_*.sh 调用 |

### 9.2 新增/改变的项目级技术决策

| 决策 | 取值 | 影响范围 | 推翻代价 |
|---|---|---|---|
| npm 工具离线打包策略 | `npm pack` → 解压 → 扁平 node_modules → tar.gz | 所有依赖 npm 工具的 flow-kit 组件（当前仅 brooks-lint） | 低——改用 pnpm deploy 或 Docker 镜像只需要改打包脚本 Part G |

### 9.3 新增/修改的跨模块契约

```
- package-flow-kit.sh 新增 Part G（npm 工具打包段）→ 影响 staging 目录结构（新增 brooks-tools/）
- install.sh 新增 check_node() 前置检测 → 不影响现有安装流程，仅新增 Node.js 可用性探针
- install_brooks_tools.sh 暴露 install_brooks_tools() 函数 → 由 install.sh source 后调用
- manifest.json schema（brooks-tools 元数据）→ tools.{name}.version, platform, node_min
```

### 9.4 新增/升级的依赖

本 change 不修改 `package.json`（flow-kit-bundle 无 `package.json`）。打包脚本运行时依赖 npm CLI（开发机已具备），目标环境不新增依赖。

### 9.5 禁动清单变化

```
- 新增禁动：~/.claude/tools/brooks-lint/node_modules/ 不允许手动修改（下次 install --reinstall 会覆盖）
- 新增禁动：~/.local/bin/{depcheck,jscpd,knip,ts-prune} shim 脚本不允许手动编辑（由 install.sh 管理）
- 新增禁动：package-flow-kit.sh Part G 工具版本号不允许单方面改动（需和 brooks-lint 版本绑动，走 change 流程）
```

---

> 本文件不包含完整代码实现。函数签名、伪代码、接口定义可以；函数体不行。
