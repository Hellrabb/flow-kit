# REQUIREMENT: 修复 2026-07-01 全量健康扫描发现的 6 项技术债

- **Change ID**: sweep-fix-2026-07
- **关联**: `@.specs/sweep-fix-2026-07/CHANGE.md`、`@.specs/CONTEXT.md`

---

## 用户故事

- **US-1**：作为 flow-kit 维护者，我想 hook 模块名列表只在一处定义，以便新增 hook 模块时不会因漏改某处而导致静默缺失。
- **US-2**：作为 flow-kit 维护者，我想 `fk_artifact_check()` 的 phase 产物规则以查表方式定义，以便为新 phase 添加检查规则时只需加一行数据而非修改控制流。
- **US-3**：作为 flow-kit 维护者，我想 correction file 的读写清逻辑只在一个 lib 中实现，以便修改 JSON 格式时只需改一处、两个消费者自动同步。
- **US-4**：作为 flow-kit 维护者，我想 `bats` 可执行且 SessionStart hooks 有测试覆盖，以便 hook 变更能被自动化回归捕获。
- **US-5**：作为 flow-kit 维护者，我想所有 hook 输出通过统一的 `module_output()` 调用，以便 `99-report.sh` 消费者仅需处理一种格式。
- **US-6**：作为 flow-kit 维护者，我想 `MIN_MEANINGFUL_LINES=3` 有注释说明阈值依据，以便未来维护者理解其含义。

## 验收准则（AC）

### AC-1 · Hook 模块名列表单一定义

- **Given** `common.sh` 已定义 `HOOK_MODULE_NAMES` 数组（或独立配置文件）
- **When** 在 `install_hooks.sh` 和 `package-flow-kit.sh` 中遍历 hook 模块名
- **Then** 两处均引用同一来源，不存在重复硬编码的模块名列表
- **验证方式**: `grep -c "00-gate.*01-transcript.*99-report" flow-kit-bundle/lib/install_hooks.sh package-flow-kit.sh` 返回 0（无硬编码列表）；`grep -l "HOOK_MODULE_NAMES"` 在 install_hooks.sh 和 package-flow-kit.sh 中均命中

### AC-2 · `fk_artifact_check()` 查表驱动

- **Given** `flow-kit-artifacts.sh` 已定义 `declare -A PHASE_ARTIFACTS` 关联数组
- **When** 调用 `fk_artifact_check <change_id> <phase>`
- **Then** 行为和返回值与改造前一致，所有现有 bats 测试（`test_flow_artifacts.bats`）全部通过
- **验证方式**: `bash -n flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh` 通过；`declare -A PHASE_ARTIFACTS` 可被 grep 命中

### AC-3 · Correction file 统一

- **Given** 已新建 `lib/correction-file.sh` 提供通用 `correction_file_write()` / `correction_file_read()` / `correction_file_clear()` / `correction_file_exists()`
- **When** `interactive-ui-check.sh` 和 `weak-model-compliance.sh` 调用这些通用函数
- **Then** 两个 lib 不再各自实现 JSON merge-write 逻辑；`flow-kit-resume.sh` 对两种 correction 的读取行为不变
- **验证方式**: `bash -n` 全部受影响文件通过；`grep -c "jq.*correction.*tmp" lib/interactive-ui-check.sh lib/weak-model-compliance.sh` 降为 0

### AC-4 · bats 安装 + SessionStart 测试

- **Given** 系统已安装 `bats`（`which bats` 成功）
- **When** 运行 `bats test/test_flow_kit_resume.bats test/test_stop_report_reminder.bats`
- **Then** 所有用例通过，且现有 17 个 bats 文件的 176 个断言无回归
- **验证方式**: `bats --version` 成功；`bats test/` 全部通过

### AC-5 · 输出格式审计

- **Given** 所有 stop hook 脚本均 source `common.sh`
- **When** 排查每个 hook 中的直接 `echo` 警告/错误
- **Then** 所有 findings 输出均通过 `module_output()` 调用，无裸 `echo "warning|..."`
- **验证方式**: `grep -rL "module_output" flow-kit-bundle/hooks/stop/[0-9]*.sh | wc -l` 返回 0（每个 hook 都调用了 module_output）

### AC-6 · 魔法数字注释

- **Given** `flow-kit-artifacts.sh` 第 6 行定义了 `readonly MIN_MEANINGFUL_LINES=3`
- **When** 读取该行上下文
- **Then** 该行附近有注释说明"为什么是 3"
- **验证方式**: `grep -A1 "MIN_MEANINGFUL_LINES" flow-kit-bundle/hooks/stop/lib/flow-kit-artifacts.sh | grep -c "#"` ≥ 1

---

## 范围切分

### v1（本次必做）

- AC-1: Hook 模块名列表单一定义（🔴 Critical）
- AC-2: `fk_artifact_check()` 查表驱动（🟡 Warning）
- AC-3: Correction file 统一（🟡 Warning）
- AC-4: bats 安装 + SessionStart 测试（🟡 Warning）
- AC-5: 输出格式审计（🟢 Suggestion）
- AC-6: 魔法数字注释（🟢 Suggestion）

### v2（下一轮考虑，不本次）

- `package-flow-kit.sh` 完整模块化拆分（589 行→多文件）
- `lib/weak-model-compliance.sh` L2 状态机改写为更清晰的实现
- 引入 `.brooks-lint.yaml` 配置，锁定项目特定规则

### out（永远不做）

- 换用其他 shell（zsh/fish）—— Bash 是项目锁定语言
- 将 hook 系统迁移到 Python/Node.js —— 性能无瓶颈，shell 实现刚好
- 引入第三方 JSON 处理库替代 `jq` —— jq 是唯一外部依赖，够用

---

## 非功能性需求

- **性能**: 无（hook 执行时间不因此 change 增加）
- **可访问性**: 无
- **安全**: 所有 `.sh` 脚本持续通过 `bash -n` 语法检查；`correction-file.sh` 的输出文件权限依赖调用方设定，不引入新的可写路径
- **兼容性**: Bash ≥ 4.0（关联数组 `declare -A` 的最低版本）；bats-core ≥ 1.0
- **可观测性**: 无

## 依赖与假设

- **依赖**: `jq` 已安装（项目已有依赖）；`bats` 可通过 dnf 或 npm 安装
- **假设**: 现有 17 个 bats 文件（176 断言）的测试环境与本次修改的目标文件一致（即 `flow-kit-bundle/hooks/` 和 `flow-kit-bundle/test/` 在同一仓库根下）
- **假设**: `interactive-ui-check.sh` 和 `weak-model-compliance.sh` 的 correction file 管理在语义上可合并——两者使用相同的 JSON merge-write 模式，仅路径和字段名不同
