# REQUIREMENT: pre-commit-user-scope

## 问题陈述

`deploy_pre_commit()` 的 guard `[[ -d "${project}/.git" ]] || return 0` 位于函数最前面，导致 user scope 安装时（project=$HOME 无 .git）不仅跳过 symlink 创建，还跳过了**源文件安装**（`~/.claude/hooks/pre-commit/pre-commit.sh` 未装）。这违背了 flow-kit "user scope 装源文件、project scope 接线" 的统一模式。

## 验收准则

### AC-1：deploy_pre_commit 两段式拆分

**Given** `flow-kit-bundle/lib/install_hooks.sh` 的 `deploy_pre_commit()` 函数

**When** 执行 `install.sh --platform claude --global --user`（user scope，project=$HOME 无 .git）

**Then**
1. `~/.claude/hooks/pre-commit/pre-commit.sh` **存在**（源文件无条件安装）
2. 不尝试 `mkdir -p "$HOME/.git/hooks"`（避免在 $HOME 创建无意义 .git/ 目录）
3. 不尝试创建 symlink（user scope 无 .git → 只装源文件）

**When** 执行 `install.sh --platform claude --project <repo>`（project scope，project 含 .git）

**Then**
1. `<repo>/.claude/hooks/pre-commit/pre-commit.sh` 存在（源文件安装）
2. `<repo>/.git/hooks/pre-commit` symlink 创建（指向已装源文件）
3. 冲突检测（既有非 symlink pre-commit → FLOW_KIT_YES=1 skip / read -p 交互）行为不变

### AC-2：既有项目级行为不回归（由 AC-1 项目级块覆盖 · 回归锚点）

**Given** 项目级安装（含 .git 的 repo）

**When** deploy_pre_commit 执行

**Then** 行为由 AC-1 项目级 When/Then 三条款完整覆盖（源文件装到 `<repo>/.claude/hooks/pre-commit/` + `.git/hooks/pre-commit` symlink 指向已装源文件 + 冲突检测行为不变）。本 AC 为回归锚点声明，不重复验证步骤。

### AC-3：bats 测试覆盖

**Given** test_archive_commit_gate.bats 已有测试

**When** 新增/修改测试覆盖 user scope 源文件安装

**Then**
1. `npx bats test/` 全绿（0 not ok）
2. 新增 user scope 源文件安装断言（temp HOME 下执行 install_hooks user scope 后 `test -f "$HOME/.claude/hooks/pre-commit/pre-commit.sh"`）
3. 新增 user scope 负面断言（temp HOME 下执行后 `test ! -e "$HOME/.git/hooks/pre-commit"` 且 `test ! -d "$HOME/.git"`——验证 guard 后移不误创建 .git 目录或 symlink）

## 验证方式

- AC-1 (user scope): `install.sh --global --user` 后 `test -f ~/.claude/hooks/pre-commit/pre-commit.sh` 为 true 且 `test ! -d ~/.git/hooks`
- AC-1 (project scope): `install.sh --project <repo>` 后 `test -L <repo>/.git/hooks/pre-commit` 且 readlink 指向已装源文件
- AC-2: 由 AC-1 项目级块覆盖（回归锚点声明，不重复验证）
- AC-3: `npx bats test/` exit 0 且无新增 fail（含 user scope 正负断言）

## 影响清单

- **触碰**：`flow-kit-bundle/lib/install_hooks.sh`（deploy_pre_commit ~6 行）、`test/test_archive_commit_gate.bats`（dev 源·新增 user scope 正负断言）、`flow-kit-bundle/test/test_archive_commit_gate.bats`（bundle 副本·`make test-sync` 自动同步）
- **双源同步**：修改在 dev 源 `test/`，`make test-sync` 同步到 `flow-kit-bundle/test/`；`make check` 的 `check-test-sync` diff 验证一致性
- **禁动碰撞**：无。install_hooks.sh 不在禁动清单（`flow-kit-bundle/lib/install_*.sh` 禁外部 source 不禁编辑）；`test/` 目录禁止放非 .bats 文件（本次只编辑既有 .bats，不违反）
- **既有抽象**：install_file()、deploy_pre_commit()、HOOK_MODULE_NAMES 沿用不变

## out of scope

- pre-commit.sh 内容修改（不碰）
- core.hooksPath 全局 git 配置（不碰，pre-commit 仍是项目级 symlink 模式）
- opencode 原生安装路径（仍走桥接）
- `$HOME` 已存在 dotfiles 仓库（`~/.git`）时 user scope 仍按项目级语义接线（行为不变，非本 change 引入的回归）
