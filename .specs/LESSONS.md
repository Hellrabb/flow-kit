# LESSONS — 项目经验教训与技术债

> 本文件跨 change 累积。M-health 巡检 + 各 change 的 brooks-lint 结果 + 人工标注都写入此处。
> 格式：严重程度 | 位置 | 问题 | 建议 | 状态 | 来源

---

## 技术债清单

| # | 严重程度 | 位置 | 问题 | 建议 | 状态 | 来源 |
|---|---|---|---|---|---|---|
| L-001 | 🟡 | `package-flow-kit.sh` L1-590 | **打包与安装逻辑耦合**：打包阶段（L1-226）和安装阶段（L227-498）混在同一文件。改打包逻辑有风险误伤安装逻辑，反之亦然。 | 拆分为 `build-bundle.sh`（打包）+ `install.sh`（安装，内嵌在 bundle 中）。打包脚本专注收集资源、生成 install.sh heredoc；安装脚本只做 rsync/cp/npm install。 | active | `init-git-repo` T03 手动基线 |
| L-002 | 🟡 | `package-flow-kit.sh` L56 | **硬编码 Hook 源路径**：`HOOK_SRC="$HOME/nanoclaw/.claude/hooks"` —— 这是开发机特定路径，换人/换机器打包必炸。 | 改为可配置：`HOOK_SRC="${HOOK_SRC:-$HOME/nanoclaw/.claude/hooks}"`，并在 README 或 install.sh 中说明如何覆盖。 | active | `init-git-repo` T03 手动基线 |
| L-003 | 🔴 | `package-flow-kit.sh` L1-590 | **零测试覆盖**：590 行 Bash 核心脚本无任何自动化测试。打包逻辑（tar 正确性、文件完整性）和安装逻辑（rsync 目标路径、npm install 成功/失败）全靠手动验证。 | 引入 Bash 测试框架（如 [bats](https://github.com/bats-core/bats-core)），至少覆盖：1) 打包后 tar.gz 结构正确 2) install.sh 参数解析 3) dry-run 模式不写入文件。 | active | `init-git-repo` T03 手动基线 |
| L-004 | 🟢 | `package-flow-kit.sh` L271-280 | **内联辅助函数未抽取**：`install_file()` 是通用 cp wrapper（dry-run + chmod），类似功能的 `check_command()` 等散落在脚本中，未被抽取为独立工具库。 | 若后续新增 ≥ 3 个辅助函数，建议抽到 `lib/utils.sh` 并 source。当前规模（7 函数）暂不强制。 | active | `init-git-repo` T03 手动基线 |
| L-006 | 🟡 | `package-flow-kit.sh` L438 + `brooks-lint/hooks/session-start` L22 | **安装器排除目录导致插件 hook 静默失败**：rsync `--exclude='commands'` 排除的目录在 hook 中用 `cp <glob>` 引用时，`set -euo pipefail` 下 glob 空匹配 → cp 字面量路径 → No such file → exit 1。根本原因是分发侧做了排除假设但没同步修补被安装插件的 hook 脚本。 | 分发安装流程中，若排除某插件目录，同步检查并修补该插件的 hooks 中引用该目录的路径；hook 脚本侧用 `for f in <glob>; do [ -f "$f" ] && cp` 替代裸 `cp <glob>` 以容错空目录。 | active | `brooks-lint-hook-fix` |
| L-005 | 🟡 | `package-flow-kit.sh` L19-20 | **无预检就创建 staging 目录**：`rm -rf "$STAGING" && mkdir -p "$STAGING/..."` —— STAGING 变量若因上游错误为空字符串，`rm -rf ""` 不会有问题（bash 安全），但 `rm -rf "$STAGING"` 在 STAGING 为错误路径时可能删错目录。 | 加前置校验：`[[ -n "$STAGING" && "$STAGING" != "/" ]] || { echo "FATAL: STAGING is empty or root"; exit 1; }` | active | `init-git-repo` T03 手动基线 |

---

## 已解决

> 已修复或不再适用的条目移至此段，保留溯源。

_暂无_

---

## 元数据

- **最近更新**: 2026-06-14（`brooks-lint-hook-fix`）
- **下次复查**: M-health 巡检时或下一个 change 的 4-dev 1.5 步骤
