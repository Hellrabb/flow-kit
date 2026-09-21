# REQUIREMENT: 清理仓库中的本机绝对路径与不该入库的缓存/备份文件

- **Change ID**: privacy-path-scrub-2026-09
- **关联**: `@.specs/privacy-path-scrub-2026-09/CHANGE.md`
- **上游事实基线**: 本 change 的现场实测（`git grep` / `git ls-files` / `git log origin/develop..HEAD`），非推测

## 用户故事

- **US-1**：作为仓库所有者，我不想让本机用户名与本地目录布局随仓库公开，以便推送后不被指纹化。
- **US-2**：作为维护者，我不想让 `.pyc`/`.bak` 这类缓存与备份长期占用仓库并被搜索引擎索引。
- **US-3**：作为审计者，我希望脱敏后仍能复算「做过什么、影响了哪些哈希」，以便不牺牲可追溯性。

## 验收准则（AC）

### AC-1 · 工作区零命中（本机路径）
- **Given** 工作区当前有 49 个已跟踪文件含 `~`（91 处）
- **When** 执行文本脱敏
- **Then** `git grep -lE '~'`（工作区）**0 命中**；通用占位符（`/home/...`、`/home/user`、`/home/ubuntu`）保持不变
- **验证方式**: `git grep -cE '~' -- . | wc -l` = 0

### AC-2 · 缓存/备份不再跟踪
- **Given** 6 个 `.pyc` + 1 个 `.bak` 被跟踪
- **When** `git rm --cached` + 补 `.gitignore`
- **Then** `git ls-files | grep -E '\.pyc$|\.bak$'` = 0；`git check-ignore` 对工作区同类文件返回「已忽略」
- **验证方式**: 上述两条命令实跑

### AC-3 · 历史零命中（可达提交）
- **Given** 未推送的 37 个提交（`origin/develop..develop`）中含同样字面量
- **When** `git filter-branch` 重写该区间并清理 `refs/original`/reflog/gc
- **Then** `git log --all -S '~' --oneline` = 0；`git rev-list --all --objects | ...` 抽取的 blob 中 0 命中
- **验证方式**: pickaxe 全历史扫描 + 备份移除后的对象级复核

### AC-4 · 门禁不退化
- **Given** 仓库既有 6 门门禁
- **When** 脱敏 + 历史重写完成
- **Then** `make check` 六门全绿（rc=0）；本 change 前的 `verify-ac.sh`（归档内）仍 128/0
- **验证方式**: `make check`；`bash .specs/archive/2026-09-21-user-guide-sync-2026-09b/verify-ac.sh`

### AC-5 · 可追溯性与安全网处置
- **Given** 历史重写使 37 个哈希失效
- **When** 收尾
- **Then** 产出 `history-rewrite-map.txt`（old→new）+ `IMPACTED-REFS.md`（哪些文档引用失效）；安全网（tag/bundle）在验证通过后**删除**，并复核删除后本机不可再取到旧对象
- **验证方式**: 文件存在 + `git rev-list --all | wc -l` 复核 + 旧对象 `git cat-file -e` 失败

## 范围切分

### v1（本次必做）
- AC-1 ~ AC-5 全部（含历史重写与安全网清理）

### v2（下一轮考虑，不本次）
- 给仓库加一条**机械门禁**：`git grep -lE '/home/[a-z]'` 命中即失败（防复发），挂进 `make check`
- 把 `.specs/**` 的绝对路径硬编码改为 `$REPO_ROOT`/`~` 风格（本 change 只做字面脱敏，不重构脚本逻辑）

### out（永远不做）
- 改写**已推送**的历史（需要强推，且会影响他人克隆）
- 清理 vendor 目录里上游作者的公开邮箱（判为误报）

## 非功能性需求

- **性能**: 全量 `git grep` + `filter-branch` 在本地 37 提交规模下 ≤ 5 分钟；`make check` 不回退。
- **可访问性**: 无。
- **安全**: 重写后必须清 `refs/original` + reflog + `gc --prune=now`，否则「隐私清理」不成立；备份 bundle 验证后删除。
- **兼容性**: 仅重写 `develop` 的未推送区间；`origin/develop` 及更早历史不动。
- **可观测性**: 产出 old→new 映射与被影响引用清单。

## 依赖与假设

- 依赖：`git filter-branch`（内建，实测可用；`git filter-repo` 未安装）
- 假设：用户 2026-09-21 已拍板「同时清历史」，并知悉提交哈希会变、且仓库禁止对 main 强推（本次不推送）
