# REQUIREMENT: 支持 flow-kit 核心引擎 user-scope 全局安装

- **Change ID**: `user-scope-install`
- **关联**: `@.specs/user-scope-install/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 用户，我想在新项目上执行一条命令就让 `/flow-go` 可用，无需在每个项目复制 81 个核心文件，以便快速开始开发工作流。
- **US-2**：作为多项目开发者，我想升级 `~/.claude/flow-kit/` 一处就让所有项目生效，以便省去逐项目手动更新的繁琐。
- **US-3**：作为已有项目的维护者，我想项目级 `flow-kit/` 目录继续优先生效（不受 user-scope 影响），以便项目可以锁定特定版本的 flow-kit 核心。

## 验收准则（AC）

每条用 Given / When / Then，必须可验证。

### AC-1 · 首次 --user 安装

- **Given** `~/.claude/flow-kit/` 目录不存在
- **When** 用户在新项目执行 `bash install.sh --user /path/to/project`
- **Then** 
  - `~/.claude/flow-kit/` 被创建，包含完整的 prompts/、reference/、templates/ 等子目录
  - 项目根目录创建 symlink `flow-kit → ~/.claude/flow-kit`
  - skills 仍安装到 `~/.claude/skills/`（与之前一致）
  - hooks/settings 仍安装到项目 `.claude/`（与之前一致）
- **验证方式**: `ls ~/.claude/flow-kit/GO.md && ls -l /path/to/project/flow-kit | grep '^l' && grep -q '->.*\.claude/flow-kit'`

### AC-2 · 后续项目复用已有 user-scope 安装

- **Given** `~/.claude/flow-kit/` 已存在（来自之前的 `--user` 安装），且新项目无 `flow-kit/`
- **When** 用户在新项目执行 `bash install.sh --user /path/to/another-project`
- **Then**
  - `~/.claude/flow-kit/` **不被覆盖**（保留已有内容）
  - 新项目创建 symlink `flow-kit → ~/.claude/flow-kit`
  - 其他组件（skills/hooks/config）正常安装
- **验证方式**: `diff -r ~/.claude/flow-kit/ ~/.claude/flow-kit/`（安装前后一致）；`ls -l another-project/flow-kit` 显示为 symlink

### AC-3 · 项目级优先——已有 flow-kit/ 物理目录不降级

- **Given** 项目根目录存在物理 `flow-kit/` 目录（非 symlink），且 `~/.claude/flow-kit/` 也存在
- **When** AI 在该项目执行 `/flow-go` 路由到某阶段（如 2-design），skill 需要读取 `flow-kit/prompts/2-design.md`
- **Then** skill 从**项目级** `flow-kit/prompts/2-design.md` 读取（不从 `~/.claude/flow-kit/` 读取）
- **验证方式**: 在项目级 `flow-kit/prompts/2-design.md` 插入唯一标记字符串，确认 AI 读到的是项目级版本

### AC-4 · 回退到 user scope——项目无 flow-kit/ 时自动查找

- **Given** 项目根目录**不存在** `flow-kit/`（既无物理目录也无 symlink），且 `~/.claude/flow-kit/` 存在
- **When** AI 在该项目执行 `/flow-go` 路由到某阶段
- **Then** skill 从 `~/.claude/flow-kit/` 读取 prompts/references/templates
- **验证方式**: 创建无 `flow-kit/` 的测试项目，执行 `/flow-go`，确认能进入正常工作流

### AC-5 · --dry-run 正确预览 symlink 创建

- **Given** `~/.claude/flow-kit/` 已存在
- **When** 用户执行 `bash install.sh --dry-run --user /path/to/project`
- **Then** 输出包含：
  - `(dry-run) rsync flow-kit/ → ~/.claude/flow-kit/`（或提示已存在跳过）
  - `(dry-run) ln -s ~/.claude/flow-kit → /path/to/project/flow-kit`
  - 不实际创建任何文件或 symlink
- **验证方式**: `bash install.sh --dry-run --user /tmp/test-project 2>&1 | grep -c "dry-run"` ≥ 文件步骤数

### AC-6 · 向后兼容——无 --user 时保持原有行为

- **Given** 项目无 `flow-kit/` 目录，`~/.claude/flow-kit/` 可能已存在也可能不存在
- **When** 用户执行 `bash install.sh /path/to/project`（不带 `--user`）
- **Then** `flow-kit/` 仍以**物理目录**方式复制到项目根目录（与当前 `install.sh` 行为完全一致）
- **验证方式**: 不带 `--user` 安装后，`ls -l project/flow-kit` 显示为普通目录（非 symlink）

---

## 范围切分

### v1（本次必做）

- install.sh 新增 `--user` flag，将 `flow-kit/` 安装到 `~/.claude/flow-kit/` + 项目创建 symlink
- install.sh 所有模式（user / project）均支持 `--dry-run`
- flow-go SKILL.md 新增两级查找：先查项目 `flow-kit/`，不存在则回退 `~/.claude/flow-kit/`
- `--user` 模式下 `~/.claude/flow-kit/` 已存在时仅创建 symlink，不覆盖已有核心
- INSTALL.md 更新文档说明 `--user` 模式用法

### v2（下一轮考虑，不本次）

- `--update` flag：比较 bundle 版本与已装版本，仅当更新时执行
- `--reinstall` flag：清空已有安装后全新安装
- Windows 兼容：使用 NTFS Junction 替代 symlink（需检测平台自动切换）
- `install.sh --user --project ~`（一次安装所有项目生效的 user-level hooks）

### out（永远不做）

- hooks/settings 提升到 user-scope（hooks 是项目级行为，每个项目的 stop-hook 检查项不同）
- flow-kit 自动更新 daemon 或 cron job
- 包管理器集成（npm/brew/apt）—— 保持纯 bash 安装

---

## 非功能性需求

- **性能**: symlink 解析开销可忽略（< 1ms），不影响 AI 读取 `flow-kit/` 文件的响应时间
- **兼容性**: Linux/macOS symlink（`ln -s`）；Windows 不在 v1 支持范围
- **安全**: 安装到 `~/.claude/` 无需 sudo（用户自有目录），不引入新的安全边界
- **可观测性**: 安装过程终端输出清晰区分 "已存在跳过" / "新建" / "创建 symlink" 三类操作

## 依赖与假设

- **依赖**: 项目使用 Claude Code（或兼容 IDE），`~/.claude/skills/` 已配置
- **假设 1**: 用户环境 `ln -s` 可用（Linux/macOS 标准工具）
- **假设 2**: Claude Code 的 Read/Bash/Glob 工具透明跟随 symlink（需在 TEST 阶段验证）
- **假设 3**: 项目文件系统支持 symlink（非 FAT32/exFAT）

---

> AC 是 TEST 阶段派生用例的唯一来源，禁止在 TEST 阶段引入新 AC。
