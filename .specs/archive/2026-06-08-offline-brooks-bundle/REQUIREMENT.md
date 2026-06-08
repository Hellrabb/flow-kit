# REQUIREMENT: 打包脚本离线化 brooks-lint 分发

- **Change ID**: `offline-brooks-bundle`
- **关联**: `@.specs/offline-brooks-bundle/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为打包脚本使用者，我想在离线环境（无 git / 无 npm）下打包 brooks-lint，以便在任何机器上都能生成完整 bundle。
- **US-2**：作为打包脚本使用者，我想在本地缓存不可用时自动回退到原始 git archive 方式，以便换新机器后仍能正常打包。
- **US-3**：作为打包脚本使用者，我想通过 `--brooks-src` 指定自定义 brooks-lint 源路径，以便用自己维护的版本打包。

## 验收准则（AC）

### AC-1 · rsync 离线打包 brooks-lint

- **Given** 本地缓存 `~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/1.3.0/` 存在且含完整文件（skills/hooks/commands/plugin config）
- **When** 运行 `package-flow-kit.sh`（无网络，无 git）
- **Then** bundle 中 `brooks-lint/commands/brooks-*.md` ≥ 6 个文件；`brooks-lint/plugin/` 含完整的 skills/hooks/commands 子目录
- **验证方式**: `tar -tzf flow-kit-bundle.tar.gz | grep "brooks-lint/commands/brooks-" | wc -l` ≥ 6

### AC-2 · --brooks-src 参数

- **Given** 用户有一个自定义的 brooks-lint 源目录 `/tmp/custom-brooks/`（结构与缓存目录一致）
- **When** 运行 `package-flow-kit.sh --brooks-src /tmp/custom-brooks/`
- **Then** 打包使用指定的源路径而非本地缓存；bundle 中 brooks-lint 内容来自该路径
- **验证方式**: `grep "brooks-lint" <bundle>/README.md` 确认源路径记录

### AC-3 · 缓存不可用时 fallback 到 git archive

- **Given** 本地缓存目录不存在（`~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/` 为空或缺失），且 marketplace git repo（`~/.claude/plugins/marketplaces/brooks-lint-marketplace/`）可用
- **When** 运行 `package-flow-kit.sh`
- **Then** 自动回退到原有 `git archive` 方式，打印一条 warn：「⚠️ 本地缓存不可用，回退到 git archive 方式」
- **验证方式**: `STDERR/STDOUT` 含 `git archive` 或回退提示

### AC-4 · 版本自动选择

- **Given** 本地缓存下存在多个版本子目录（如 `1.2.0/` + `1.3.0/`）
- **When** 运行 `package-flow-kit.sh`（不指定 `--brooks-version`）
- **Then** 自动选择 semver 最高的版本（1.3.0）
- **验证方式**: 打包日志含 `使用 brooks-lint v1.3.0 (本地缓存)`

### AC-5 · 离线安装兼容性

- **Given** 由新打包脚本生成的 bundle
- **When** 在无网络目标机上运行 `install.sh --global`
- **Then** brooks-lint 成功安装：`/brooks-review` 等 6 个命令在 Claude Code 中可调用
- **验证方式**: `ls ~/.claude/commands/brooks-*.md | wc -l` ≥ 6

---

## 范围切分

### v1（本次必做）

- Part F 打包逻辑：rsync 替代 git archive（默认从本地缓存取）
- `--brooks-src <path>` CLI 参数
- 缓存不可用时 fallback 到 git archive
- 多版本时自动选最新
- 打包日志输出 brooks-lint 版本和来源

### v2（下一轮考虑，不本次）

- `--brooks-version <ver>` 显式指定版本号（当前自动选最新已够用）
- semver 严格解析（当前用简单排序即可，版本号极少）
- 打包前校验 brooks-lint 缓存完整性（skills 文件数/hooks 存在性/plugin.json 格式）

### out（永远不做）

- 嵌入 Node.js 运行时（已验证 brooks-lint 终端用户不需要）
- 预装 npm 依赖（同上）
- 修改 `install_brooks_lint()` 安装逻辑（当前已是纯文件复制，离线兼容）
- 多平台 Node.js 二进制支持

---

## 非功能性需求

- **性能**: 打包时间与当前 git archive 方式持平（rsync 本地文件拷贝，无网络 I/O）
- **可访问性**: 无（非 Web 项目）
- **安全**: rsync 源路径不能为 `/` 或空字符串（防误删）；`--brooks-src` 参数值需校验目录存在
- **兼容性**: 向后兼容 — 不传 `--brooks-src` 且本地缓存不存在时，行为与旧版完全一致（fallback git archive）
- **可观测性**: 打包日志明确输出 brooks-lint 来源（`本地缓存 vX.Y.Z` / `git archive（fallback）` / `--brooks-src <path>`）

## 依赖与假设

- **假设**：打包机上已安装 brooks-lint（v1.3.0，通过 marketplace），缓存路径 `~/.claude/plugins/cache/brooks-lint-marketplace/brooks-lint/` 存在
- **假设**：打包机上有 `rsync` 命令（Linux 标配）
- **依赖**：无外部服务、无第三方库。fallback 路径依赖 marketplace git repo 可用
- **关联 LESSONS**：L-002（硬编码路径）— 本次通过 `--brooks-src` 参数缓解，但默认缓存路径仍硬编码

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
