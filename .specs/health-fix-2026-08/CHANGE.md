# CHANGE · health-fix-2026-08

> **来源**: M-health 2026-08-03 Full Sweep（`.specs/health/2026-08-03-FULL-SWEEP.md`）
> **评分趋势**: 98 → **89**（↓9 · 单源退化）
> **状态**: proposal（待用户触发 0-change 流程展开）
> **角色**: Maintenance Engineer 只产 proposal，不动代码

---

## 背景

2026-08-03 全量 Sweep 发现 1 项 🔴 Critical 回归，源自最近一次 commit `0c79f1c feat(platform): claude/opencode 双平台兼容安装器`。该 commit 引入 `lib/paths.sh` + `PROJECT_DIR_NAME` 变量以支持 opencode 平台（`.opencode/` 目录），但改写 `install_hooks.sh:97` 时遗漏 user-scope 守卫，导致：

1. **4 个 bats 测试 fail**（test_install_coverage.bats / test_install_dry_run.bats 共 4 case）
2. **`install.sh --user` 链路断**（exit 1）
3. **副作用**：runtime-edit-guard.sh 安装（line 177-183）位于 L97 之后，因 L97 exit 永远不执行 — 即使 project scope 也装不上 0c79f1c 新增的 runtime-edit-guard.sh hook

## 问题定位

**文件**: `flow-kit-bundle/lib/install_hooks.sh:97`

**Bug 代码**：
```bash
install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "${project}/${PROJECT_DIR_NAME}/stop-hook.json"
```

**根因**（git log -L 97,97 精确确认）：
- `2e745b7`（2026-06-16 health-fix）原始：`"$project/.claude/stop-hook.json"` — 硬编码 `.claude`，两种 scope 都能跑
- `0c79f1c`（2026-08-03 platform-split）改写为 `"${project}/${PROJECT_DIR_NAME}/stop-hook.json"` — 但 `PROJECT_DIR_NAME` 仅由 `lib/paths.sh` 定义（install.sh 主入口 source），以下两条调用路径不 source paths.sh：
  1. 单元测试直接 `source install_hooks.sh` → `set -u` 终止
  2. `install.sh --user` user-scope 分支（line 43-57 else 块外）从未触达 PROJECT_DIR_NAME 评估

**实测证据**（健康报告附件）：
```
[DRY-RUN] cp .../auto-checkpoint.sh -> /pre-tool-use/auto-checkpoint.sh
/home/.../install_hooks.sh: 行 97: PROJECT_DIR_NAME: 未绑定的变量
EXIT=1
```

**语义层根因**：行内注释 `# 配置文件（项目级 stop-hook.json 开关）` 表明 `stop-hook.json` 是 PROJECT-SCOPE 配置文件，本就不应在 user scope 写入。这是双平台拆分应同时加 scope 守卫的设计意图，被遗漏。

## 修复方案（推荐 · 本 proposal 不改代码）

在 `install_hooks.sh:96-97` 外加 scope 守卫：

```bash
  # 配置文件（项目级 stop-hook.json 开关）
  if [ "$scope" != "user" ]; then
    install_file "$SCRIPT_DIR/hooks/config/stop-hook.json" "${project}/${PROJECT_DIR_NAME}/stop-hook.json"
  fi
```

**2 行变更**（实际 diff：+2 行 `if`/`fi` 包裹，原 L97 缩进 +2）。

## 验收准则（AC）

### Hard AC（必须满足）

- **AC-1** `make test` exit code 0，所有 691 个 @test cases 全绿（修复前 687/4）
- **AC-2** 修复前失败的 4 个测试 case 全部 pass：
  - test_install_coverage.bats:98 `install_hooks DRY_RUN user scope: exit 0 and output contains [DRY-RUN]`
  - test_install_coverage.bats:105 `install_hooks DRY_RUN user scope: mentions .claude/hooks`
  - test_install_dry_run.bats:20 `install_hooks DRY_RUN: no settings.json mutation`
  - test_install_dry_run.bats:43 `install_hooks DRY_RUN: output contains [DRY-RUN] messages`
- **AC-3** 手动验证 user-scope dry-run exit 0：
  ```bash
  DRY_RUN=true SCRIPT_DIR=$(pwd)/flow-kit-bundle HOME=$(mktemp -d) \
    bash -c "source flow-kit-bundle/lib/install_hooks.sh; install_hooks \$(mktemp -d) user"
  # 期望: exit 0, 输出含 [DRY-RUN], 不再出现 PROJECT_DIR_NAME 错误
  ```
- **AC-4** 手动验证 project-scope dry-run 仍写 stop-hook.json：
  ```bash
  DRY_RUN=true SCRIPT_DIR=$(pwd)/flow-kit-bundle \
    bash -c "source flow-kit-bundle/lib/install_hooks.sh; install_hooks \$(mktemp -d) project"
  # 期望: 输出含 [DRY-RUN] cp .../stop-hook.json -> .../.claude/stop-hook.json
  ```
- **AC-5** runtime-edit-guard.sh 安装恢复（project scope dry-run 输出含 runtime-edit-guard.sh cp 行）— 验证 L97 修复解锁下游 L177-183

### Soft AC（建议但不卡门禁）

- **AC-6**（建议）补一条 bats 测试：显式断言 user-scope install 不写 stop-hook.json（防回归）。位置：`test/test_install_coverage.bats` 新增 case
- **AC-7**（建议）补 install_hooks.sh 文件头注释「依赖：lib/paths.sh（PROJECT_DIR_NAME）· user-scope 路径不依赖此变量」明确边界

## 范围

### In scope

- `flow-kit-bundle/lib/install_hooks.sh:96-97` — 加 `if [ "$scope" != "user" ]` 守卫
- `flow-kit-bundle/test/test_install_coverage.bats` 或 `test/test_install_dry_run.bats`（双源同步）— AC-6 防回归测试

### Out of scope

- `lib/paths.sh` 本身的设计审查（platform-split 是 0c79f1c 的成果，paths.sh 抽象合理）
- `lib/paths.sh` 在 CONTEXT.md「既有抽象索引」的登记 — 留下次 A-evolve 同步
- runtime-edit-guard.sh 的功能验证（修复 L97 后自动恢复安装，不需独立动作）
- 其他 R1-R6 维度（本次 sweep 全 🟢，无需动）

## 风险

- **R1 测试覆盖不足**：现有 4 个 fail 测试已能捕获回归，AC-6 建议补的 case 是双保险，不强求
- **R2 双源同步**：`test/` 和 `flow-kit-bundle/test/` 必须同步修改（如加 AC-6 测试），否则 `make check` 双源 diff 会 fail
- **R3 paths.sh 边界扩散**：未来若 install_hooks.sh 的更多行引入 PROJECT_DIR_NAME，需同样加 scope 守卫。建议 4-dev 时检查所有 `${PROJECT_DIR_NAME}` 引用点是否都在 project-scope 守卫内

## 预期效果

- 综合健康分 89 → 98~99（恢复 baseline 水准）
- 测试 687/4 → 691/0 全绿
- `install.sh --user` 链路恢复
- runtime-edit-guard.sh hook 恢复安装

## 触发下一步

用户选择「现在修」→ 触发 `/home/hellrabbit/.cc-switch/skills/flow-health/flow-kit/prompts/0-change.md` 正式展开本 CHANGE，进入 0→1→2→3→4→5→6→7 全流程。

或用户选择「记录待修」→ 本 proposal 归档，下次周期性 sweep 复检。
