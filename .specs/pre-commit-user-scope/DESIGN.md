# DESIGN: pre-commit-user-scope

## §0 技术栈

Bash（`set -euo pipefail`）· bats-core 1.13.0 · 无框架。遵循 CONTEXT.md 已锁决策。

## §0.5.1 触碰模块清单

| 模块 | 路径 | 改动类型 | 禁动碰撞 |
|---|---|---|---|
| install_hooks.sh | `flow-kit-bundle/lib/install_hooks.sh` L34-58 | 修改 deploy_pre_commit guard 位置 | 无（`install_*.sh` 禁外部 source 不禁编辑）|
| test_archive_commit_gate.bats | `test/test_archive_commit_gate.bats` | 新增 user scope 测试段 | 无（.bats 编辑不违反 test/ 禁动）|
| test_archive_commit_gate.bats（bundle） | `flow-kit-bundle/test/test_archive_commit_gate.bats` | `make test-sync` 自动同步 | 无（产物同步）|

**write_files**: `flow-kit-bundle/lib/install_hooks.sh`, `test/test_archive_commit_gate.bats`

## §1 问题分析

`deploy_pre_commit()` 当前结构（install_hooks.sh:34-58）：

```bash
deploy_pre_commit() {
  [[ -d "${project}/.git" ]] || return 0   # ← guard 在最前（L39）

  local target="${project}/.git/hooks/pre-commit"
  mkdir -p "${project}/.git/hooks" "$hook_dst/pre-commit"
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"  # L43 源文件安装

  if [[ -e "$target" && ! -L "$target" ]]; then
    # 冲突检测（FLOW_KIT_YES / read -p）
  fi

  ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"  # L56 symlink
}
```

**根因**：guard `[[ -d "${project}/.git" ]] || return 0` 位于 L39，在源文件安装（L43）和 symlink 创建（L56）之前。user scope（install.sh:243 `install_hooks "$HOME" "user"`）传 project=$HOME 无 .git → 整个函数 return 0 → 源文件未装到 `~/.claude/hooks/pre-commit/`。

## §2 设计决策

### D1：两段式拆分（核心决策）

将 deploy_pre_commit 拆为两段：
1. **源文件安装**（无条件）：`install_file` 先执行，装到 `$hook_dst/pre-commit/pre-commit.sh`。user scope 和 project scope 都装。
2. **symlink 创建**（guard 后移）：guard 移到源文件安装之后。user scope 无 .git → 只装源文件；project scope 有 .git → 创建 symlink。

```bash
deploy_pre_commit() {
  # 1. 无条件装源文件（user + project scope 都装）
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"

  # 2. 项目级才创建 symlink（user scope 无 .git → 只装源文件）
  [[ -d "${project}/.git" ]] || return 0

  local target="${project}/.git/hooks/pre-commit"
  mkdir -p "${project}/.git/hooks"

  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ "${FLOW_KIT_YES:-0}" == "1" ]]; then
      echo "   [archive-commit-gate] existing pre-commit: $target, skipped"
      return 0
    fi
    local ans
    read -p "flow-kit: 既有 pre-commit 存在，覆盖？(y/N) " ans
    [[ "$ans" == "y" ]] || { echo "   skipped"; return 0; }
    rm -f "$target"
  fi

  ln -sf "$hook_dst/pre-commit/pre-commit.sh" "$target"
  echo "   ✅ pre-commit symlink → $target"
}
```

**依据**：flow-kit 统一模式「user scope 装源文件、project scope 接线」。其他 hook（stop/session-start/pre-tool-use）在 user scope 都装源文件，pre-commit 不应例外。

**install_file 已含 mkdir**：`install_file()` L22-33 内部 `mkdir -p "$(dirname "$dst")"`，所以无需显式 `mkdir -p "$hook_dst/pre-commit"`。

### ADR-023: user scope pre-commit 源文件必须无条件安装

**决策**：deploy_pre_commit 的源文件安装段（`install_file`）无条件执行，不依赖 `.git` 存在性。

**理由**：user scope hooks 统一模式——所有 hook 源文件都装到 `~/.claude/hooks/`（user scope），pre-commit 不应因 guard 位置而例外。project scope 的 symlink 接线仍需 `.git` 存在。

**影响**：user scope 安装后 `~/.claude/hooks/pre-commit/pre-commit.sh` 存在，可供手动 symlink 或未来 core.hooksPath 全局配置使用。

## §3 风险评估

| 风险 | 级别 | 缓解 |
|---|---|---|
| guard 后移导致 user scope 误创建 ~/.git/ | 🟢 低 | guard 在 mkdir -p .git/hooks 之前，user scope 无 .git 时 return 0 不执行 mkdir |
| 既有 project scope symlink 行为改变 | 🟢 低 | symlink 创建逻辑完全保留（guard 后移不影响，mkdir 从合并拆为独立但语义不变） |
| $HOME 有 dotfiles repo（~/.git 存在）时 user scope 创建 symlink | 🟢 低 | 行为不变（guard 检测到 .git → 创建 symlink，与修复前一致），out of scope 声明 |
| 冗余 mkdir（install_file 已 mkdir） | 🟢 低 | 删除显式 `mkdir -p "$hook_dst/pre-commit"`，依赖 install_file 内部 mkdir |
| DRY_RUN 下 mkdir 语义微变 | 🟢 低 | 旧代码 DRY_RUN 时显式 mkdir 仍创建 `$hook_dst/pre-commit` 目录；新代码 install_file 在 DRY_RUN 下只 echo 不 mkdir → 该目录不创建。行为更正确（DRY_RUN 不应创建目录），无测试依赖此行为 |

## §4 测试策略

**test_archive_commit_gate.bats 新增 user scope + project scope 行为测试段**（现有测试仅 grep 级断言，无行为覆盖——本次补齐）：

```bash
@test "deploy_pre_commit: user scope (no .git) installs source file only" {
  # setup: HOME=$(mktemp -d) · 无 .git
  # source install_hooks.sh（SCRIPT_DIR 指向 flow-kit-bundle）
  # run deploy_pre_commit（或 install_hooks user scope 子集）
  # assert: test -f "$HOME/.claude/hooks/pre-commit/pre-commit.sh"
  # assert: test ! -d "$HOME/.git"  (负面断言 — guard 后移不误创建)
  # assert: test ! -e "$HOME/.git/hooks/pre-commit"  (负面断言)
}

@test "deploy_pre_commit: project scope (has .git) creates symlink → source" {
  # setup: tmp repo with .git · HOME 独立 temp
  # run deploy_pre_commit
  # assert: test -f "<repo>/.claude/hooks/pre-commit/pre-commit.sh"  (源文件)
  # assert: test -L "<repo>/.git/hooks/pre-commit"  (symlink)
  # assert: readlink "<repo>/.git/hooks/pre-commit" 指向已装源文件
}
```

**禁止 DRY_RUN 模式**：DRY_RUN 下 install_file 只 echo 不创建文件，正向断言 `test -f` 必然失败。测试必须真实执行（非 DRY_RUN）。

**双源同步**：修改在 dev 源 `test/`，`make test-sync` → `flow-kit-bundle/test/`。`make check` 的 `check-test-sync` 验证一致性。

## §5 既有抽象对齐

- `install_file()` L22-33 — 沿用（内部 mkdir -p + cp）
- `deploy_pre_commit()` L34-58 — 修改 guard 位置
- `install_hooks()` L100+ 的 `deploy_pre_commit` 调用 — 不变（调用点不受影响）
- `HOOK_MODULE_NAMES` — 不变（34 号模块已注册）
