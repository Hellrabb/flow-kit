# REQUIREMENT: 初始化 Git 仓库并建立脚本设计文档与技术债跟踪体系

- **Change ID**: `init-git-repo`
- **关联**: `@.specs/init-git-repo/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为仓库维护者，我想用 git 管理版本，以便追踪每次脚本变更、回滚误改。
- **US-2**：作为后续接手者，我想看到 `package-flow-kit.sh` 的设计文档，以便理解其架构和关键决策后再动手改。
- **US-3**：作为维护者，我想有一份技术债基线，以便知道哪些地方该优先修、修了没。
- **US-4**：作为首次访问者，我想看到 README，以便快速了解仓库用途、结构和规范。
- **US-5**：作为 AI 辅助开发环境，我想 CONTEXT.md 反映最新项目状态（含 git 信息），以便后续 CHANGE 的护栏生效。

## 验收准则（AC）

### AC-1 · Git 仓库初始化

- **Given** 项目目录无 `.git/`
- **When** 执行 `git init`，添加 `.gitignore`，执行首次 `git add -A && git commit`
- **Then** `git log --oneline` 输出至少 1 条 commit；`git status` 不显示 `flow-kit-bundle.tar.gz`（被 `.gitignore` 排除）
- **验证方式**: `git log --oneline | head -1 && git status --short`

### AC-2 · 脚本设计文档基线

- **Given** `package-flow-kit.sh` 已存在（28KB，无设计文档）
- **When** 分析脚本结构并生成 DESIGN.md
- **Then** DESIGN.md 至少包含以下段落：架构概览、函数/模块职责索引、关键数据流、已做出的关键决策与取舍（≥ 3 条）
- **验证方式**: `grep -c "^## " .specs/init-git-repo/DESIGN.md` ≥ 4（至少 4 个二级标题）

### AC-3 · 技术债基线

- **Given** 项目无技术债记录
- **When** 运行 brooks-lint 扫描（或手动建立基线）
- **Then** `.specs/LESSONS.md` 更新，包含至少 1 条技术债条目（含严重程度、位置、建议修复方向）。若 brooks-lint 对 Bash 项目产出为空，则手动标注≥3 条已知问题
- **验证方式**: `grep -c "🔴\|🟡\|🟢" .specs/LESSONS.md` ≥ 1

### AC-4 · README 就位

- **Given** 仓库根目录无 README.md
- **When** 编写 README.md
- **Then** README 包含：仓库用途（1 段）、目录结构（tree 或列表）、开发规范三要素（命名约定 / 提交格式 / 分支策略）
- **验证方式**: `grep -c "^## " README.md` ≥ 3

### AC-5 · CONTEXT.md 同步更新

- **Given** `.specs/CONTEXT.md` 中 `git_repo: false`、无提交规范
- **When** git 仓库初始化完成后
- **Then** CONTEXT.md 更新：`git_repo` 字段改为 `true`，新增提交格式约定、`.gitignore` 策略描述
- **验证方式**: `grep "git_repo" .specs/STATE.md | grep "true"`

---

## 范围切分

### v1（本次必做）

- git init + .gitignore + 首次 commit
- `package-flow-kit.sh` 的 DESIGN.md 基线
- 技术债基线（brooks-lint 或手动，写入 LESSONS.md）
- README.md（用途 + 目录 + 规范）
- CONTEXT.md 同步（git 状态更新）

### v2（下一轮考虑，不本次）

- 配置 pre-commit hook（如 brooks-lint 自动扫描）
- 设置分支保护规则（如有 remote）
- CI/CD pipeline 集成
- 自动生成 CHANGELOG.md（从 git log + conventional commits）
- brooks-lint 结果集成到 M-health 定期巡检

### out（永远不做）

- 修改 `package-flow-kit.sh` 代码本身（属于其他 CHANGE 的范围）
- 新增打包脚本或其他功能脚本
- 改变 `flow-kit-bundle.tar.gz` 内容
- 迁移既有历史改动到此仓库（从这次开始记）

---

## 非功能性需求

- **性能**: 无（不涉及运行时性能）
- **可访问性**: 无（非 Web 项目）
- **安全**: `.gitignore` 必须排除 `.env`、`*.key`、`credentials*` 等敏感文件模式；首次 commit 前确认无硬编码凭据
- **兼容性**: Git ≥ 2.0（`git init` 默认分支名为 `main`）
- **可观测性**: 无

## 依赖与假设

- **假设**：用户环境已安装 Git（≥ 2.0），且 `git` 在 PATH 中
- **假设**：brooks-lint 插件在当前 Claude Code 会话中可用（SessionStart hook 已确认）；若调用失败则回退到手动基线
- **假设**：用户对该仓库有完全读写权限（本地目录）
- **依赖**：无外部服务、无第三方库

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
