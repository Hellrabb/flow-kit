# ADR-022 · git hook 部署策略（symlink to .git/hooks/）

> 来自 change `archive-commit-gate` 阶段 2 DESIGN D1

## Context

flow-kit 需部署 git pre-commit hook 实现 commit 时测试门禁（闭合 LESSONS L-023「commit-time 测试门禁缺失」）。

git hook 部署位置有三选：

1. `git config core.hooksPath <dir>`（全局覆盖 · git 只读该目录的 hook）
2. 直接复制 hook 文件到 `.git/hooks/`
3. symlink `.git/hooks/<hook-name>` → 源文件

## Decision

**选方案 3：symlink `.git/hooks/pre-commit` → 已安装 hooks 目录（user: `~/.claude/hooks/pre-commit/pre-commit.sh` / project: `.claude/hooks/pre-commit/pre-commit.sh`）**（L2 v2 F4 修复：原指 `flow-kit-bundle/` 源目录，目标项目无此目录→悬空 symlink）。

每项目部署（install.sh 按项目跑时执行）。

## Consequences

### 优点

- **最小侵入**：只注入 `pre-commit` 一个文件，不碰 `.git/hooks/` 下用户既有 hook（方案 1 core.hooksPath 会全局覆盖致用户自定义全失效）
- **版本同步**：symlink 指向 flow-kit 源，版本随 flow-kit 更新自动同步（方案 2 复制需重装）
- **幂等部署**：install.sh 重复跑检测 symlink 已存在则跳过（方案 2 需 diff 比对）

### 代价

- **每项目单独部署**：install.sh 已按项目跑，成本可接受；user-scope 安装时通过 `--project <path>` 参数指定目标项目（L2 v2 F4 修复：原 `--deploy-pre-commit` install.sh 零命中）
- **Windows 兼容**：Git for Windows 下 symlink 需开发者模式或管理员权限；install.sh 检测 `$OSTYPE` 含 msys → fallback 复制方案 + 文档标注

## Alternatives Considered

### 方案 1 · core.hooksPath（否决）

`git config core.hooksPath ~/.claude/hooks/`

- ❌ 全局覆盖：用户 `.git/hooks/` 下既有 hook 全失效（破坏性）
- ❌ flow-kit 的 Stop/SessionStart hook 也在 `~/.claude/hooks/`，git 不会调它们（git 只认 pre-commit/post-commit 等固定文件名），但混放增加认知负担

### 方案 2 · 直接复制（否决）

`cp flow-kit-bundle/hooks/pre-commit/pre-commit.sh .git/hooks/pre-commit`

- ❌ 版本失同步：flow-kit 更新后需重装
- ❌ 与用户 `.git/hooks/` 文件混在一起难管理

## References

- REQUIREMENT.md AC-2（pre-commit make test 硬门禁）
- REQUIREMENT.md AC-4（install.sh 部署 + 向后兼容）
- DESIGN.md D1
