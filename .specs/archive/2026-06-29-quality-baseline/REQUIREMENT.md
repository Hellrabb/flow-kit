# REQUIREMENT: 质量基础设施补强

- **Change ID**: `quality-baseline`
- **关联**: `@.specs/quality-baseline/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1 (E)**：作为 flow-kit 维护者，我希望 toll-gate 协议在 prompts 和 skills 之间共享一份源文件，以便改协议只需改一处，不再双入口漂移。
- **US-2 (F)**：作为 flow-kit 开发者，我希望 `make check` 一键跑完所有验证，`git push` 前自动跑 check，以便不会忘记跑测试或 lint。
- **US-3 (G)**：作为 flow-kit 维护者，我希望 stop 链主脚本有基础的 smoke test 覆盖，以便修改协调层逻辑时有测试护栏。
- **US-4 (H)**：作为 flow-kit 开发者，我希望 bash 脚本有静态分析（shellcheck error 级别），以便低级错误在编辑时就被抓到。
- **US-5 (I)**：作为 flow-kit 打包者，我希望 `make check` 自动 diff `test/` 和 `flow-kit-bundle/test/` 确认内容一致，以便不会出现两份拷贝不同步。

## 验收准则（AC）

### AC-1 · 共享片段存在且被引用

- **Given** `flow-kit/reference/pipeline-gates.md` 已创建，包含 toll-gate 协议共享内容
- **When** 执行 `grep -l "pipeline-gates" flow-kit-bundle/flow-kit/prompts/*.md flow-kit-bundle/skills/flow-*/SKILL.md`
- **Then** 至少 2 个文件包含对 pipeline-gates.md 的引用注释
- **验证方式**: `grep -c "pipeline-gates" flow-kit-bundle/flow-kit/prompts/4-dev.md flow-kit-bundle/skills/flow-dev/SKILL.md`

### AC-2 · 协议一致性校验脚本

- **Given** 存在 diff 校验脚本验证 prompt 和 skill 的 toll-gate 段一致
- **When** 运行 `bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh`
- **Then** exit code 0 表示一致，exit 1 表示发现漂移
- **验证方式**: `bash flow-kit-bundle/flow-kit/reference/check-gate-sync.sh; echo $?`

### AC-3 · Makefile targets 可用

- **Given** 项目根目录存在 `Makefile`
- **When** 依次运行 `make test`、`make lint`、`make check`
- **Then** `make test` 跑 bats 全量；`make lint` 跑 shellcheck；`make check` 跑 test+lint+打包校验+test双源diff
- **验证方式**: `make check 2>&1` → exit 0

### AC-4 · pre-push hook 生效

- **Given** `.git/hooks/pre-push` 已安装（指向 `make check`）
- **When** 模拟 `git push`（或直接运行 `bash .git/hooks/pre-push`）
- **Then** `make check` 被执行；check 失败时 push 被阻止
- **验证方式**: `test -x .git/hooks/pre-push && grep -q "make check" .git/hooks/pre-push`

### AC-5 · stop 链 smoke test 覆盖

- **Given** `test/test_stop_chain.bats` 已创建
- **When** 运行 `npx bats test/test_stop_chain.bats`
- **Then** 至少覆盖 22-git/24-session/26-workflow/99-report 的基础功能（source 不报错、关键函数存在）
- **验证方式**: `npx bats test/test_stop_chain.bats --formatter tap` → 0 failures

### AC-6 · shellcheck 无 error

- **Given** shellcheck 已安装
- **When** 运行 `shellcheck -e SC1091 *.sh flow-kit-bundle/lib/*.sh flow-kit-bundle/hooks/stop/*.sh`
- **Then** 输出中无 `error` 级别问题（`warning` 和 `style` 允许）
- **验证方式**: `shellcheck -e SC1091 *.sh 2>&1 | grep -c "error"` → 0

### AC-7 · test 双源校验

- **Given** `make check` 中包含 test 双源 diff 步骤
- **When** `test/` 与 `flow-kit-bundle/test/` 内容不一致
- **Then** `make check` 报错并列出差异文件
- **验证方式**: 临时修改 test/ 中某文件 → make check → exit ≠ 0

---

## 范围切分

### v1（本次必做）

- E: 提取 `pipeline-gates.md` + `check-gate-sync.sh` 校验脚本
- F: `Makefile` + pre-push hook
- G: stop 链 smoke test
- H: shellcheck 安装 + `make lint` 集成（仅 error 级别）
- I: `make check` 内含 test 双源 diff

### v2（下一轮考虑）

- shellcheck warning 级别逐步修复
- pre-push hook 的 install.sh 自动化安装
- 跨更多 prompt/skill 对扩展 gate sync 校验

### out（永远不做）

- 不引入 GitHub Actions 等外部 CI
- 不引入 npm/JS 工具链
- 不修改 install.sh 的核心安装逻辑（仅加 hook 安装步骤）

---

## 非功能性需求

- **性能**: 无（Makefile targets 秒级完成）
- **可访问性**: 无（CLI）
- **安全**: pre-push hook 不执行外部网络请求；shellcheck 仅本地静态分析
- **兼容性**: GNU Make 4.0+；shellcheck 0.9+；Bash 4.0+
- **可观测性**: 每个 Makefile target 输出明确的 pass/fail + exit code

## 依赖与假设

- **依赖**: make、shellcheck（需手动 `apt install` 或等效）、bats-core（npx）、diff
- **假设**: 用户环境有 `make`（Linux/macOS 标准）；shellcheck 可通过包管理器安装
- **假设**: `.git/hooks/pre-push` 不会被 git 自动同步（需 install.sh 或手动安装）
