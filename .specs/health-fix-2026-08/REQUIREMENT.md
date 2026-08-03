# REQUIREMENT · health-fix-2026-08

> **来源**: M-health 2026-08-03 Full Sweep（`.specs/health/2026-08-03-FULL-SWEEP.md`）
> **评分趋势**: 98 → 89（↓9 · 单源退化 · 本 change 目标恢复至 ≥98）
> **根因 commit**: `0c79f1c feat(platform): claude/opencode 双平台兼容安装器`

---

## 用户故事

### US-1 · user-scope 安装链恢复（功能正确性）
作为 flow-kit 用户，我希望 `install.sh --user` 能正常完成安装，这样我可以在 user-scope 模式下使用 flow-kit（而非遇到 `PROJECT_DIR_NAME: 未绑定的变量` 退出）。

### US-2 · 测试基线恢复（无回归）
作为项目维护者，我希望 `make test` 恢复 0 fail（从当前 687/4 fail 恢复到 691/0），这样 CI 门禁不会阻断。

### US-3 · runtime-edit-guard.sh 安装解锁（下游修复）
作为 flow-kit 用户，我希望 0c79f1c 新增的 runtime-edit-guard.sh hook 能在 project-scope 安装时正常部署，这样该 hook 能实际生效（当前因 L97 exit 1 阻断 L177-183 的安装路径）。

### US-4 · 防回归（未来保护）
作为项目维护者，我希望补一条显式 bats 测试断言 user-scope install **正确写入** `~/.claude/stop-hook.json`（运行时 `common.sh:107-108` 的 user-scope 回退依赖此文件），这样未来如果有人误删此安装行会被测试捕获。

> **注**: 原 US-4 设想"user-scope 不写 stop-hook.json"，经 DESIGN L2 审查 (FINDING-1) 发现与运行时 `common.sh:103-110` 矛盾——stop-hook.json 在 user-scope 是 `module_enabled` 回退依赖，不可移除。US-4 已据此修正。

---

## 验收准则（AC）

### 类别 A · 功能正确性（硬门槛）

#### AC-A1 · make test exit 0（全量测试恢复）
`Given` 修复已应用到 `flow-kit-bundle/lib/install_hooks.sh`
`When` 执行 `make test`（不接管道，直接取 `$?` — 避 TD-012 `bats|tail` 吃 exit code 反模式）
`Then` exit code = 0，stdout 含 `✅ bats: all tests passed`，stdout 不含 `not ok`
`验证方式`: `make test; echo "exit=$?"`（Makefile 第二行 `npx bats test/ > /dev/null 2>&1 && echo ✅ || exit 1` 是真实 exit gate）

#### AC-A2 · 修复前失败的 4 个测试 case 全部 pass
`Given` 修复已应用
`When` 分两文件执行（各自取 exit code + 全量日志）：
- `npx bats test/test_install_coverage.bats` → exit code + 全量输出
- `npx bats test/test_install_dry_run.bats` → exit code + 全量输出
`Then` 两文件 exit code 均 = 0，各自全量输出中无 `not ok`
`验证方式`: 全量日志 grep case 标题为唯一锚点（行号标注仅供参考，文件可能漂移）：
- `test_install_coverage.bats` L98: `"install_hooks DRY_RUN user scope: exit 0 and output contains [DRY-RUN]"`
- `test_install_coverage.bats` L110: `"install_hooks DRY_RUN user scope: mentions .claude/hooks"`（注：非 L105，实测在 L110）
- `test_install_dry_run.bats` L20: `"install_hooks DRY_RUN: no settings.json mutation"`
- `test_install_dry_run.bats` L43: `"install_hooks DRY_RUN: output contains [DRY-RUN] messages"`

### 类别 B · 手动验证（硬门槛）

#### AC-B1 · user-scope dry-run exit 0
`Given` 修复已应用 + 临时 HOME 目录
`When` 执行：
```bash
DRY_RUN=true SCRIPT_DIR=$(pwd)/flow-kit-bundle HOME=$(mktemp -d) \
  bash -c "source flow-kit-bundle/lib/install_hooks.sh; install_hooks \$(mktemp -d) user"
```
`Then` exit code = 0，stdout 含 `[DRY-RUN]`，stderr 不含 `PROJECT_DIR_NAME: 未绑定的变量`
`验证方式`: 手动 shell 命令 + exit code 断言

#### AC-B2 · project-scope dry-run 仍写 stop-hook.json（无功能退化）
`Given` 修复已应用
`When` 执行：
```bash
DRY_RUN=true SCRIPT_DIR=$(pwd)/flow-kit-bundle \
  bash -c "source flow-kit-bundle/lib/install_hooks.sh; install_hooks \$(mktemp -d) project"
```
`Then` stdout 含 `[DRY-RUN] cp .../stop-hook.json -> .../.claude/stop-hook.json`
`验证方式`: 手动 shell 命令 + grep `stop-hook.json`

#### AC-B3 · runtime-edit-guard.sh 安装恢复（下游解锁）
`Given` 修复已应用（L97 不再 exit 1）
`When` 执行 AC-B2 的 project-scope dry-run 命令
`Then` stdout 含 `[DRY-RUN] cp .../runtime-edit-guard.sh -> .../pre-tool-use/runtime-edit-guard.sh`
`验证方式`: 手动 shell 命令 + grep `runtime-edit-guard.sh`

### 类别 C · 防回归（软门槛 · 建议但不卡门禁）

#### AC-C1 · 补 bats 测试：user-scope install 正确写入 stop-hook.json（防回归）
`Given` 新 case `"install_hooks DRY_RUN user scope: writes stop-hook.json to user config dir"` 已写入 `test/test_install_coverage.bats`（+ `flow-kit-bundle/test/` 双源同步）
`When` 执行 `npx bats test/test_install_coverage.bats --filter "writes stop-hook.json"`
`Then` exit code = 0，输出含 `ok` 且不含 `not ok`（断言 user-scope dry-run 输出**含** `stop-hook.json` —— 保护运行时 `common.sh:107-108` 的 user-scope 回退依赖）
`验证方式`: bats --filter 单 case 执行

> **注**: 原 AC-C1 断言"user-scope 不写 stop-hook.json"。经 DESIGN L2 FINDING-1 发现 stop-hook.json 在 user-scope 是运行时回退依赖（`common.sh:103-110`），移除会导致 module_enabled 恒 false。AC-C1 已反向修正。

#### AC-C2 · 补 install_hooks.sh 文件头注释（边界文档化）
`Given` 注释已加到 `flow-kit-bundle/lib/install_hooks.sh` 文件头
`When` 执行 `head -20 flow-kit-bundle/lib/install_hooks.sh`
`Then` 含说明：依赖 `lib/paths.sh`（PROJECT_DIR_NAME）· user-scope 路径不依赖此变量
`验证方式`: head + grep

### 类别 D · 代码质量（硬门槛）

#### AC-D1 · bash -n 语法检查通过
`Given` 修复已应用
`When` 执行 `bash -n flow-kit-bundle/lib/install_hooks.sh`
`Then` exit code = 0
`验证方式`: bash -n

#### AC-D2 · shellcheck 0 error
`Given` shellcheck 已安装（`command -v shellcheck` exit 0 — 排除 Makefile lint target 非阻塞 skip 的真空通过）
`When` 执行 `make lint`（不接管道）
`Then` exit code = 0，stdout 不含 `Skipping lint`（确认实际执行了 lint），stderr 无 shellcheck `error` 级别输出
`验证方式`: `make lint; echo "exit=$?"`

#### AC-D3 · 双源测试同步
`Given` 测试修改（如 AC-C1）写入 `test/`
`When` 执行 `diff test/test_install_coverage.bats flow-kit-bundle/test/test_install_coverage.bats`
`Then` exit code = 0（两源完全一致）
`验证方式`: diff 或 `make check`（含双源 diff 检测）

---

## 范围

### In scope

- `flow-kit-bundle/lib/install_hooks.sh` — 行为约束：被 `source` 直接加载时（测试 / 独立调用）不因 paths.sh 变量未绑定而崩溃（PROJECT_DIR_NAME / settings_file_for 等）。**不做 scope guard**（stop-hook.json 在 user-scope 是运行时回退依赖 · 详见 US-4 注）。精确实现方式由 DESIGN 决定
- `test/test_install_coverage.bats` + `flow-kit-bundle/test/test_install_coverage.bats`（双源同步）— AC-C1 防回归测试（断言 user-scope **正确写** stop-hook.json）
- `flow-kit-bundle/lib/install_hooks.sh` 文件头注释（AC-C2 · 依赖边界文档化）

### Out of scope

- `lib/paths.sh` 本身的设计审查（platform-split 是 0c79f1c 的成果，paths.sh 抽象合理）
- `lib/paths.sh` 在 CONTEXT.md「既有抽象索引」的登记 — 留下次 A-evolve 同步
- runtime-edit-guard.sh 的功能验证（修复 L97 后自动恢复安装，不需独立动作）
- 其他 R1-R6 维度（本次 sweep 全 🟢，无需动）
- 其他 install_hooks.sh 行中的 PROJECT_DIR_NAME 引用点审查（R3 风险评估：4-dev 时快速检查，但不作为本次 AC）

---

## 假设与依赖

- **A1**: baseline 测试 691/0 是正确的（M-health 2026-08-03 实测确认 687/4 fail，4 fail 全因本次回归）
- **A2**: `lib/paths.sh` 仅由 `install.sh` 主入口 source，install_hooks.sh 被单独 source 时不加载 paths.sh（0c79f1c commit 设计）
- **A3**: `runtime-edit-guard.sh` 的安装逻辑（L177-183）本身正确，仅因 L97 exit 而未执行（0c79f1c 新增）
- **A4**: user-scope 安装目标目录派生自 `$HOME`（AC-B1 的 `HOME=$(mktemp -d)` 隔离验证依赖此假设）
- **A5**: 修复核心是 install_hooks.sh 被 `source` 直接加载时自动加载 paths.sh 依赖（PROJECT_DIR_NAME / settings_file_for / PLATFORM 等）。**不涉及 scope guard**（DESIGN L2 审查确认 stop-hook.json 在 user-scope 是运行时回退依赖，移除会造成 module_enabled 恒 false 的功能回归）
