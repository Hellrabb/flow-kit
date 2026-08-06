# CHANGE: pre-commit-user-scope

> **change-id**: `pre-commit-user-scope`
> **created**: 2026-08-06
> **type**: 修复（既有 change archive-commit-gate 的 deploy_pre_commit 设计缺陷）
> **scope**: 1 处 edit（install_hooks.sh deploy_pre_commit guard 位置修正）

## 背景

archive-commit-gate 交付的 `deploy_pre_commit()` 函数（`flow-kit-bundle/lib/install_hooks.sh:38-58`）存在设计缺陷：

```bash
deploy_pre_commit() {
  [[ -d "${project}/.git" ]] || return 0   # ← guard 在函数最前面

  mkdir -p "${project}/.git/hooks" "$hook_dst/pre-commit"
  install_file ... "$hook_dst/pre-commit/pre-commit.sh"   # ← 源文件安装被 guard 一起挡了
  ...
  ln -sf ... "$target"   # ← 只有 symlink 创建真的需要项目级 guard
}
```

**问题**：guard 在函数最前面，把「源文件安装」（L43）和「symlink 创建」（L56）一起挡了。`install.sh --global --user` 时 project=$HOME 无 .git → 整个函数 return 0 → **pre-commit.sh 源文件未装到 `~/.claude/hooks/pre-commit/`**。

**实证**：archive-commit-gate 归档后执行 `install.sh --platform claude --global --user` → `~/.claude/hooks/pre-commit/` 不存在（m00815 验证）。

## 修复方案

两段式拆分：

1. **源文件安装**——无条件执行（装到 `$hook_dst/pre-commit/pre-commit.sh`，user scope 和 project scope 都装）
2. **symlink 创建**——只在有 `.git` 时执行（项目级 `.git/hooks/pre-commit` → 指向已装源文件）

```bash
deploy_pre_commit() {
  # 1. 无条件装源文件（user scope + project scope 都装）
  mkdir -p "$hook_dst/pre-commit"
  install_file "$SCRIPT_DIR/hooks/pre-commit/pre-commit.sh" "$hook_dst/pre-commit/pre-commit.sh"

  # 2. 项目级才创建 symlink（user scope 无 .git → 只装源文件）
  [[ -d "${project}/.git" ]] || return 0
  local target="${project}/.git/hooks/pre-commit"
  mkdir -p "${project}/.git/hooks"
  ...（冲突检测 + ln -sf 不变）
}
```

## 影响范围

- **触碰文件**：`flow-kit-bundle/lib/install_hooks.sh`（deploy_pre_commit 函数，~6 行调整）
- **禁动碰撞**：无（install_hooks.sh 不在禁动清单 Part A-E/G）
- **既有行为**：项目级 symlink 行为不变（guard 后移到源文件安装之后，symlink 逻辑完全保留）

## v1 范围

- 修复 deploy_pre_commit guard 位置
- 更新 bats 测试（如覆盖 user scope 源文件安装）
- 归档

## v2 / out

- 无（纯 bugfix）
