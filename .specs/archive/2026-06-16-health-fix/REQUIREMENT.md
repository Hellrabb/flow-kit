# REQUIREMENT: 健康巡检修复 — 消除技术债 + 引入测试

- **Change ID**: `health-fix`
- **关联**: `@.specs/health-fix/CHANGE.md`、`@.specs/CONTEXT.md`、`@.specs/health/2026-06-16-HEALTH.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想在修改 shell 脚本后运行 `bats test/` 验证行为不变，以便放心重构而不引入回归。
- **US-2**：作为 flow-kit 打包者，我想 hooks 脚本只有一处维护源（`flow-kit-bundle/hooks/`），以便修改 hook 时无需手动同步两份副本。
- **US-3**：作为 flow-kit 开发者，我想 `install.sh` 拆分为独立模块，以便修改某一类安装逻辑时只需读对应文件而非 517 行。
- **US-4**：作为 flow-kit 开发者，我想脚本中的阈值（超时、行数限制等）以命名常量表达，以便一眼看懂含义而无须 grep 代码。
- **US-5**：作为 flow-kit 打包者，我想 `package-flow-kit.sh` 在没有 `~/.claude/flow-kit/` 的机器上仍可正常打包，以便真正支持离线迁移。
- **US-6**：作为 flow-kit 维护者，我想 `settings.json` 模板只在一处维护，以便改 hook 接线时不会遗漏同步。
- **US-7**：作为 flow-kit 维护者，我想 brooks-lint 版本号从 `plugin.json` 动态读取，以便升级 brooks-lint 时无需手动改 install.sh。

## 验收准则（AC）

### AC-1 · bats 测试框架就绪

- **Given** 项目根目录存在 `test/` 目录，内含 `test_common.bats` 和 `test_install.bats`
- **When** 执行 `bats test/`
- **Then** 所有测试用例通过（含 skip 的兼容），输出显示测试数、通过数、失败数
- **验证方式**: `bats test/ 2>&1 | grep -E '^[0-9]+ tests' `

### AC-2 · common.sh 核心函数有测试覆盖

- **Given** `test/test_common.bats` 存在
- **When** 运行 `bats test/test_common.bats`
- **Then** 至少覆盖 `config_get`、`module_enabled`、`check_enabled`、`is_subagent`、`file_not_empty`、`line_count` 6 个函数，每个至少 1 个 happy-path + 1 个边界用例
- **验证方式**: `bats test/test_common.bats --formatter tap | grep -c '^ok '`

### AC-3 · install.sh 参数解析有测试覆盖

- **Given** `test/test_install.bats` 存在
- **When** 运行 `bats test/test_install.bats`
- **Then** 验证 `--global`、`--project`、`--update`、`--reinstall`、`--dry-run`、`--no-hooks`、`--no-skills`、`--no-brooks`、`--hooks-only`、`--user` 共 10 个参数的行为（dry-run 模式不写入文件，正常模式输出预期文本）
- **验证方式**: `bats test/test_install.bats --formatter tap | grep -c '^ok '`

### AC-4 · hooks 脚本只有一处维护源

- **Given** `flow-kit-bundle/hooks/` 保留为唯一源
- **When** 检查 `.claude/hooks/` 目录
- **Then** `.claude/hooks/` 已被删除（仓库内无此目录）；`package-flow-kit.sh` 的 Part C 从 `$SCRIPT_DIR/flow-kit-bundle/hooks` 读取（已是现状 line 64，确认无需改动）
- **验证方式**: `test ! -d .claude/hooks && echo "PASS"`

### AC-5 · install.sh 拆分为 ≤ 5 个文件

- **Given** `flow-kit-bundle/install.sh` 主脚本 + `flow-kit-bundle/lib/install_*.sh` 模块文件存在
- **When** 检查文件行数
- **Then** 主脚本 ≤ 150 行（仅 CLI 解析 + 调度）；每个 `lib/install_*.sh` ≤ 200 行；功能与拆分前等价（`--dry-run` 输出不变）
- **验证方式**: `wc -l flow-kit-bundle/install.sh flow-kit-bundle/lib/install_*.sh`

### AC-6 · 魔法数字替换为命名常量

- **Given** 目标文件已添加 `readonly` 常量定义
- **When** 检查以下文件的关键行
- **Then** `24-session.sh`: `60`→`SECS_PER_MIN` / `3600`→`SECS_PER_HOUR` / `7200`→`LONG_SESSION_SECS` / `100000`→`TOKEN_WARNING_THRESHOLD`；`flow-kit-resume.sh`: `72`→`STALE_SESSION_HOURS`；`flow-kit-artifacts.sh`: `3`→`MIN_MEANINGFUL_LINES`；`23-quality.sh`: `50`→`TRIVIAL_CHANGE_LINES`
- **验证方式**: `grep -c 'readonly' <每个文件>`

### AC-7 · 外部路径本地 fallback

- **Given** `package-flow-kit.sh` 的 Part A 逻辑已修改
- **When** `~/.claude/flow-kit/` 不存在时执行 Part A
- **Then** 自动回退到 `$SCRIPT_DIR/flow-kit-bundle/flow-kit/` 本地副本；Part B（skills）和 Part F（brooks-lint）具有同等 fallback 逻辑
- **验证方式**: `mv ~/.claude/flow-kit ~/.claude/flow-kit.bak; bash package-flow-kit.sh /tmp/test-export 2>&1 | grep -E 'fallback|本地副本|rsync'; mv ~/.claude/flow-kit.bak ~/.claude/flow-kit`

### AC-8 · settings.json 模板去重

- **Given** `package-flow-kit.sh` Part D 已修改
- **When** 检查打包结果
- **Then** `$STAGING/hooks/config/settings.json` 来自 `cp "$SCRIPT_DIR/flow-kit-bundle/hooks/config/settings.json"`，不存在 heredoc 内联模板
- **验证方式**: `grep -c 'cat > "\$STAGING/hooks/config/settings.json"' package-flow-kit.sh` 返回 0

### AC-9 · brooks-lint 版本号动态读取

- **Given** `install.sh` 的 `install_brooks_lint()` 函数已修改
- **When** brooks-lint plugin.json 版本字段为 `"1.3.0"`
- **Then** install 目标路径自动拼接为 `brooks-lint/<version>`；升级 brooks-lint 后只需更新 `plugin.json` 无需改动 install.sh
- **验证方式**: `grep -c '1\.3\.0' flow-kit-bundle/install.sh` 返回 0

---

## 范围切分

### v1（本次必做）

- AC-1 ~ AC-9 全部
- bats 测试覆盖 `common.sh` + `install.sh`
- hooks 去重（删 `.claude/hooks/`）
- install.sh 拆分
- 魔法数字 → 命名常量
- 外部路径 fallback
- settings.json 模板去重
- brooks-lint 版本号动态读取

### v2（下一轮考虑，不本次）

- 为 `package-flow-kit.sh` 的 Part B/C/D/E/F 编写完整测试
- 为 stop hook 各模块（20-26, 30, 99）编写集成测试
- CI/CD 集成（GitHub Actions 自动跑 bats）
- `flow-kit-bundle/flow-kit/` 作为 git submodule 引入以消除 vendor 副本

### out（永远不做）

- 修改 brooks-lint 插件自身源码（上游仓库的事）
- 修改 flow-kit 核心引擎 prompts/templates（上游仓库的事）
- 引入除 bats 以外的测试框架（保持工具链最小）
- 将 `.claude/hooks/` 改为 symlink（增加复杂度无实际收益）

---

## 非功能性需求

- **性能**: 无（shell 脚本，非性能敏感）
- **可访问性**: 无（CLI/后端工具）
- **安全**: 路径拼接使用 `$SCRIPT_DIR` 基准，禁止 `rm -rf` 作用于未经验证的变量（延续 LESSONS.md L-005 的防护）
- **兼容性**: `install.sh --dry-run` 输出格式不变（下游脚本可能依赖）；`bats` ≥ 1.10.0（Ubuntu 22.04 apt 默认版本）
- **可观测性**: 每个拆分后的模块函数使用 `set -euo pipefail`（继承现有约定）；bats 测试失败时输出 TAP 格式便于定位

## 依赖与假设

- **bats-core** 可通过 `apt install bats` 安装（Ubuntu/Debian），或 `npm install -g bats`，或 bundle 自带静态二进制
- `flow-kit-bundle/hooks/` 是运行时 `.claude/hooks/` 的**唯一源**（install.sh 从 `$SCRIPT_DIR/hooks/` 即 bundle 内目录读取）
- 当前 `.claude/hooks/` 文件与 `flow-kit-bundle/hooks/` 完全相同（已验证 diff 无输出），删除无数据丢失
- `flow-kit-bundle/flow-kit/` 本地副本存在且完整（与 `~/.claude/flow-kit/` 来自同一 git repo）
- jq 在目标环境已安装或非必需（install.sh 已有 fallback 逻辑）
