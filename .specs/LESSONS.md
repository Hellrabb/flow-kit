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
| L-007 | 🟢 | `package-flow-kit.sh` L104-143 vs `flow-kit-bundle/hooks/config/settings.json` | **settings.json 模板重复定义**：heredoc 内联模板与文件模板独立维护，修改需同步两处。 | 改为 `cp` 文件模板替代 heredoc | active | 2026-06-16 health |
| L-008 | 🟢 | `install.sh` L194 | **brooks-lint 版本号硬编码**：`brooks-lint/1.3.0` 路径写死，版本升级时需手动同步。 | 从 plugin.json 动态读取版本号 | active | 2026-06-16 health |

---

## 已解决

> 已修复或不再适用的条目移至此段，保留溯源。

| # | 原状态 | 位置 | 问题 | 修复提交 | 解决日期 |
|---|---|---|---|---|---|
| L-002 | 🟡 | `package-flow-kit.sh` L56 | 硬编码 `/home/hellrabbit` 路径 | `7b1ae91` fix(package): 用 SCRIPT_DIR 替换 | 2026-06-15 |
| L-006 | 🟡 | `install.sh` L243 + brooks-lint hooks | 空 commands 目录导致 hook exit 1 | `47d80f6` fix(brooks-lint): SessionStart hook 空 commands 容错 | 2026-06-14 |
| L-001 | 🟡 | `package-flow-kit.sh` | 打包与安装逻辑耦合 → install.sh 已拆分为独立文件 | `e1ea7b9` refactor package-flow-kit.sh | 2026-06-15 |

---

| L-009 | 🟡 | `common.sh:9` | **`CONFIG_FILE=""` 覆盖调用方变量**：`common.sh` 顶层 `CONFIG_FILE=""` 在 source 时无差别覆盖调用方已设的值。测试需在 source 之后重设 `CONFIG_FILE`。 | 改为 `: "${CONFIG_FILE:=}"`（仅在未设时设默认值） | active | 2026-06-16 health-fix |
| L-010 | 🟡 | T02 `.claude/hooks/` 删除 | **删除运行时 hook 文件后必须立即重装**：删除 `.claude/hooks/`（被 git 追踪且 settings.local.json 引用）后，Stop hook 静默失败直到发现报错。破坏性变更修复后必须立即验证恢复。 | 破坏性变更（删除被引用的文件）走 1.8 协议后，增加「恢复验证」步：跑实际调用确认恢复。 | active | 2026-06-16 health-fix |
| L-011 | 🟢 | `common.sh:22` module_enabled | **jq key 含连字符时 `.modules.${mod}` 被解析为减法**：`module_enabled "claude-md"` 内部拼接 `.modules.claude-md.enabled`，jq 解析为 `claude - md`。实际上 `.claude/stop-hook.json` 使用的 module key 含连字符（如 `claude-md`），目前靠 config_get 的 `|| true` 兜底未暴露。 | 改为 `config_get ".modules[\"${mod}\"].enabled"` 使用 bracket 引用 | active | 2026-06-16 health-fix |

## 元数据

- **最近更新**: 2026-06-16（health-fix 归档）
- **下次复查**: 2026-07-16（建议每月一次 M-health）
