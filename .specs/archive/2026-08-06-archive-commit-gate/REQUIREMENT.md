# REQUIREMENT: archive-commit-gate

- **Change ID**: archive-commit-gate
- **阶段**: 1-requirement
- **创建日期**: 2026-08-05
- **修订**: 2026-08-05（L2 盲审 R1-R10 处置后）

---

## 背景摘要

7-integration.md 归档步骤（步骤 5）完成后无 git commit 指令；commit-protocol.md 仅覆盖 4-dev 任务级提交。实证（l2-l3-subagent-fix 归档后 6 文件未提交）。三层加固：prompt（7-integration 步骤 5.1）+ 门禁（pre-commit hook make test）+ Hook 兜底（新 Stop hook 模块 34-archive-commit-check.sh）。详见 CHANGE.md。

## 用户决策（0-change 反问确认）

1. **范围**：commit + pre-commit 门禁（闭合 LESSONS L-023）
2. **粒度**：按类型拆分（fix 源码修复 / docs 归档产物 / chore 元数据同步）
3. **强制度**：Hook 兜底（PCSC 硬检查「git status 干净」+ Stop hook 检测归档后未 commit 写 correction）

---

## 验收准则（Acceptance Criteria）

### AC-1：归档后自动 commit（按类型拆分）

**Given** 7-integration 步骤 5（归档 mv + CHANGELOG + STATE + L-013 清理）已完成，记录归档起点 `ARCHIVE_BASE_SHA=$(git rev-parse HEAD)`

**When** AI 执行步骤 5.1「归档 commit」

**Then**
- 按文件类型拆分为 ≤3 个原子提交（commit-protocol.md 归档级扩展格式）：
  - `fix(<change-id>): <源码修复摘要>` — 源码文件（`.sh` / `.py` / `.ts` 等非 `.md` 非产物）
  - `docs(<change-id>): <归档产物摘要>` — `.specs/archive/<date>-<id>/` 下归档产物 + 非 `.specs` 的 `.md`（prompts/templates/reference · L2 v2 F5 修复：R11 半程 D6 扩 docs 定义但 AC-1 未同步）
  - `chore(<change-id>): <元数据摘要>` — `.specs/CHANGELOG.md` / `.specs/STATE.md` / `.specs/CONTEXT.md` / `.specs/LESSONS.md`
- 每个提交遵循 commit-protocol.md 原子原则（单一意图、可独立 revert）
- 提交后 `git status` 输出 `nothing to commit, working tree clean`（仅含 `.gitignore` 排除项）

**验证方式**（锚定归档起点，区分归档 commit 与 4-dev 任务级 commit）：
```bash
# 归档完成后记录起点（7-integration 步骤 5 末尾执行）
ARCHIVE_BASE_SHA=$(git rev-parse HEAD)
# ... 步骤 5.1 归档 commit 执行后 ...
# 仅统计归档起点之后的提交，且 commit message 含本 change-id
COMMIT_COUNT=$(git log --oneline ${ARCHIVE_BASE_SHA}..HEAD | grep -cE '^[0-9a-f]+ (fix|docs|chore)\(<change-id>\)')
[ "$COMMIT_COUNT" -ge 1 ] && [ "$COMMIT_COUNT" -le 3 ]   # 归档 commit 1-3 个
# working tree 干净（.flow-active* 已在 .gitignore）
[ -z "$(git status --porcelain)" ]   # 输出空 = 干净
```

### AC-2：pre-commit hook 跑 `make test` 硬门禁

**Given** 用户（或 AI 通过 git CLI）执行 `git commit`，且目标项目根目录存在 `Makefile` 且 `make` / `npx` 在 PATH 可见

**When** pre-commit hook 触发

**Then**
- hook 执行 `make test`（全量 bats，不跑增量——DESIGN 阶段不再重新评估）
- bats 非零退出码 → hook 拒绝 commit（exit 非 0）+ stderr 输出 `[archive-commit-gate] test failed, commit rejected`
- bats 零退出码 → hook 放行 commit（exit 0）
- hook 经 install.sh 部署，不直接写 `.git/hooks/`（不入仓库）；**具体部署机制（core.hooksPath / symlink / 其他）属 DESIGN 决策**，REQUIREMENT 不锁定

**空分支声明（no-Makefile / no-npx 场景）**：
- 目标项目无 `Makefile` → hook 输出 `[archive-commit-gate] no Makefile, skipping test gate` 并放行（exit 0），不 fail-close 死锁
- `make` / `npx` 不在 hook 环境 PATH → hook 尝试 source 用户 profile（`~/.bashrc` / `~/.profile`）补 PATH；仍不可见则输出 warn 并放行（exit 0）

**验证方式**（子目录隔离，避免污染主仓库 git 状态）：
```bash
# 在临时 git repo 中测试，避免污染主仓库
TEST_REPO=$(mktemp -d) && cd "$TEST_REPO" && git init && cp <主仓库>/Makefile .
# 制造 fail 场景
mkdir test && echo '@test "temp-fail" { false; }' > test/temp-fail.bats
git add . && git commit -m "test reject" 2>&1 | grep -q 'commit rejected'   # exit 1 预期
# 正常场景（清理 fail test 后）
rm test/temp-fail.bats && git add -A && git commit -m "test: pre-commit allow"   # exit 0 预期
# 清理临时 repo（主仓库 git 状态不受影响）
cd <主仓库> && rm -rf "$TEST_REPO"
# 无 Makefile 空分支
TEST_REPO2=$(mktemp -d) && cd "$TEST_REPO2" && git init
git commit --allow-empty -m "test no-makefile" 2>&1 | grep -q 'no Makefile, skipping'   # 放行
cd <主仓库> && rm -rf "$TEST_REPO2"
```

### AC-3：Stop hook 检测归档后未 commit → correction file

**Given** 归档完成——单一硬条件检测：`.specs/archive/` 下存在归档目录（任一子目录），且当前模式为 pipeline（`.flow-active.goal.scope == "pipeline"` 且 `.flow-active.goal.status == "done"`）或单阶段（`.flow-active.goal` 为 null 但 `.specs/archive/` 有新归档目录，mtime 在当前会话 active_since 之后）

**When** 会话停止触发 Stop hook，且 `git status --porcelain` 非空（有未提交变更）

**Then**
- 新 Stop hook 模块（**编号锁定 34** · `34-archive-commit-check.sh`）写 correction file：
  - 文件：`.flow-active.correction`（复用 correction-file.sh lib）
  - type：`archive-uncommitted`（新增常量 `CORRECTION_TYPE_ARCHIVE_UNCOMMITTED`，登记到 `correction-types.sh`）
  - violations 数组：`[{ files: <git status --porcelain 行数>, hint: "归档后存在未提交变更，请执行步骤 5.1 归档 commit" }]`
- hook 在 `git status` 干净时**自动清除** type=`archive-uncommitted` 的 correction（调用 `correction_file_clear()`）——不依赖 AI 手动清除
- 下一会话 SessionStart（flow-kit-resume.sh）检测到 correction type=`archive-uncommitted` → banner 注入「⚠️ 归档后有 N 个未提交文件，请补 commit」（**需在 flow-kit-resume.sh type-dispatch 新增 elif 分支**，现有分支仅覆盖 compliance / l3-model-missing / l2-model-missing）

**空分支声明（单阶段模式无归档目录）**：
- `.specs/archive/` 无新归档目录（mtime 早于 active_since）→ hook 不触发（noop），属不适用分支

**验证方式**（副本模拟，不手编 .flow-active 主文件——遵循禁动清单）：
```bash
# 复制 .flow-active 到临时文件改 status，喂给 hook（不修改主 .flow-active）
cp .flow-active /tmp/test-flow-active
jq '.goal.status = "done" | .goal.scope = "pipeline"' /tmp/test-flow-active > /tmp/test-flow-active.tmp && mv /tmp/test-flow-active.tmp /tmp/test-flow-active
# 模拟归档目录存在
mkdir -p .specs/archive/test-archive && touch .specs/archive/test-archive/marker.md
# 制造未提交变更
echo "uncommitted" > .specs/temp-test.md
# 用正确的 env 变量跑 hook（CONFIG_FILE + STOP_HOOK_CONFIG 让 module_enabled=true）
CONFIG_FILE=.claude/stop-hook.json STOP_HOOK_CONFIG='{"modules":{"workflow":{"enabled":true}}}' PROJECT_ROOT=$(pwd) bash flow-kit-bundle/hooks/stop/34-archive-commit-check.sh 2>&1
# 验证 correction 写入
test -f .flow-active.correction && jq -r '.type' .flow-active.correction
test -f .flow-active.correction && jq -r '.type' .flow-active.correction   # archive-uncommitted
# hook 自清除测试：git status 干净时
rm .specs/temp-test.md .specs/archive/test-archive/marker.md && rmdir .specs/archive/test-archive
PROJECT_ROOT=$(pwd) FLOW_ACTIVE=/tmp/test-flow-active bash flow-kit-bundle/hooks/stop/34-archive-commit-check.sh 2>&1
# correction 已清除（correction_file_clear 调用）
# 清理
rm /tmp/test-flow-active
```

### AC-4：install.sh 部署 + 向后兼容

**Given** 全新安装（install.sh --user 或项目级）或既有项目升级

**When** install.sh 执行

**Then**
- 部署 pre-commit hook 脚本（具体机制 core.hooksPath / symlink / 其他 **属 DESIGN 决策**，REQUIREMENT 不锁定）
- 注册新 Stop hook 模块 34 到 HOOK_MODULE_NAMES（common.sh）+ install_hooks.sh + package-flow-kit.sh（**L-020 三处接线**，package-flow-kit.sh 属禁动清单，声明例外参照 superpowers-v6-absorb 先例）+ `.claude/settings.json` Stop 数组 + stop-hook.json modules 开关
- **向后兼容**：既有项目升级时，若 `.git/hooks/pre-commit` 已存在（非 flow-kit symlink），install.sh 检测到 → 询问用户（交互式）或跳过并输出确切提示 `[archive-commit-gate] existing pre-commit: <path>, skipped`（非交互式 `--yes`），不静默覆盖
- **向后兼容**：既有 Stop hook 链（00-33 + 99）不被破坏，新模块 34 追加到 33 之后、99 之前

**验证方式**（trap 恢复 + 子目录隔离）：
```bash
# 用 trap 保存恢复 pre-commit 文件，避免污染主仓库
OLD_PRECOMMIT=""
[ -f .git/hooks/pre-commit ] && OLD_PRECOMMIT=$(cat .git/hooks/pre-commit)
trap '[ -n "$OLD_PRECOMMIT" ] && printf "%s" "$OLD_PRECOMMIT" > .git/hooks/pre-commit || rm -f .git/hooks/pre-commit' EXIT
# install 后 hook 部署（机制无关断言：git commit 行为可触发 pre-commit）
git commit --allow-empty -m "test deploy" 2>&1   # pre-commit 应被触发
# Stop hook 注册（三处接线 + settings）
grep -q '34-archive-commit-check' flow-kit-bundle/hooks/stop/lib/common.sh   # HOOK_MODULE_NAMES
grep -q '34-archive-commit-check' flow-kit-bundle/lib/install_hooks.sh       # install 接线（fallback list + deploy_pre_commit）
# 既有 pre-commit 文件检测（精确文案）
echo '# user custom pre-commit' > .git/hooks/pre-commit
install.sh --yes 2>&1 | grep -qF '[archive-commit-gate] existing pre-commit: .git/hooks/pre-commit, skipped'
# trap 恢复 hooksPath
```

### AC-5：bats 回归 0 新增 fail（基线 692/692）

**Given** 本次 change 修改的文件（完整影响面清单）：
- `flow-kit-bundle/flow-kit/prompts/7-integration.md`（步骤 5.1 + PCSC）
- `flow-kit-bundle/flow-kit/reference/commit-protocol.md`（归档级 commit 协议扩展段）
- `flow-kit-bundle/hooks/stop/34-archive-commit-check.sh`（新 Stop hook 模块）
- `flow-kit-bundle/hooks/stop/lib/correction-types.sh`（新增 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED 常量）
- `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh`（type-dispatch 新增 archive-uncommitted elif 分支）
- `flow-kit-bundle/hooks/pre-commit` 或等效（pre-commit hook 脚本，部署位置 DESIGN 定）
- `flow-kit-bundle/hooks/stop/lib/common.sh`（HOOK_MODULE_NAMES 数组追加 34-archive-commit-check）
- `flow-kit-bundle/install.sh`（pre-commit 部署逻辑 + 既有 hooksPath 检测）
- `flow-kit-bundle/lib/install_hooks.sh`（Stop hook 注册逻辑）
- `flow-kit-bundle/package-flow-kit.sh`（**禁动例外声明**：HOOK_MODULE_NAMES 同步段，参照 superpowers-v6-absorb 先例）
- `test/` 新增测试文件（test_archive_commit_gate.bats 等）

**When** 执行 `npx bats test/`

**Then**
- 退出码 0
- `^not ok` 计数 = 0
- `^ok` 计数 ≥ 692（基线来自 l2-l3-subagent-fix 后实测 692 ok，STATE.md last_change_archived 标注）
- 新增的 pre-commit / Stop hook / correction type / resume dispatch / install 部署 相关测试全 pass

**验证方式**：
```bash
npx bats test/ 2>&1 | tee /tmp/bats-out.txt
EXIT_CODE=${PIPESTATUS[0]:-$?}
[ "$EXIT_CODE" = "0" ]   # 退出码 0
[ "$(grep -c '^not ok' /tmp/bats-out.txt)" = "0" ]   # 0 fail
[ "$(grep -c '^ok' /tmp/bats-out.txt)" -ge "692" ]   # ≥692 ok
```

---

## 范围切分

### v1（本次实施）

- AC-1 全实施：7-integration.md 步骤 5.1 + PCSC「git status 干净」+ commit-protocol.md 归档级扩展段
- AC-2 全实施：pre-commit hook（make test 硬门禁 + 无 Makefile 空分支 + PATH 兼容）
- AC-3 全实施：Stop hook 模块 34 + correction type archive-uncommitted（correction-types.sh 常量）+ flow-kit-resume.sh type-dispatch + hook 自清除
- AC-4 全实施：install.sh 部署 + HOOK_MODULE_NAMES 三处接线 + 向后兼容
- AC-5 全实施：bats 回归 + 新测试覆盖
- CONTEXT.md 术语沉淀（4 术语已追加）

### v2（后续 change）

- 自动 push（`git push` 在归档 commit 后）
- commit message lint（Conventional Commits 格式校验，commit-msg hook）
- 增量测试（按 staged files 智能选择测试子集）
- pipeline auto_advance 模式下的自动 commit（不停 toll-gate）
- pre-push hook（push 前再跑全量门禁）

### out（明确不做）

- 改 4-dev commit-protocol.md 任务级段
- 改 gate 核心链（independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker）
- 改其他 prompt 的 commit 指引（仅 7-integration 归档段）
- 集成 Forge runtime adapter
- 跨仓库 monorepo commit 策略

---

## NFR（非功能需求）

### 性能

- pre-commit hook `make test` 执行时间 ≤ 60s（基线 692 bats ≈ 30-40s）
- Stop hook 模块 34 执行时间 ≤ 100ms（仅 `git status --porcelain` + jq 写 correction，无网络/无 API）
- SessionStart banner 注入 ≤ 10ms（读 correction file + 格式化一行）

### 安全

- pre-commit hook **不接受外部输入**（无参数、无 stdin 读取）；注意：`make test` 会执行仓库测试代码（含 staged `.bats`，内可含任意 bash）——这是固有语义，非漏洞，但 DESIGN 需评估 staged 恶意测试在 commit 前执行的风险
- correction file 不泄露 commit 内容（只记文件数 + hint，不记文件名/内容）
- core.hooksPath 部署（如 DESIGN 选此方案）不引入路径遍历风险（install.sh 校验目标目录在 `~/.claude/` 或项目 `.git/` 下）

### 兼容性

- 双平台：prompt 层（7-integration）在 claude code + opencode 均生效（纯 markdown）；hook 层（pre-commit + Stop hook）在 claude code 原生触发，在 opencode 通过 **oh-my-opencode 4.19.4+ `dist/hooks/claude-code-hooks/` 模块**（config-loader 读 `~/.claude/settings.json` → `executePreToolUseHooks` 执行匹配命令）**也已触发**（2026-08-05 实证：PreToolUse path-guard 拦截 + Stop hook 508 条 log 记录）。桥接载体源码级确认见附录「调查发现」
- 既有项目升级：hooksPath 检测 + 询问/跳过（AC-4）
- 4-dev commit protocol 不变（任务级提交保持现状）
- 单阶段 + pipeline 模式均覆盖（AC-3 硬条件含两模式检测）
- **无 Makefile 项目**：pre-commit hook 跳过（warn）而非 fail-close 死锁（AC-2 空分支）
- **hook 环境 PATH**：pre-commit hook 内 source 用户 profile（`~/.bashrc` / `~/.profile`）补 PATH，确保 `make` / `npx` 可见；仍不可见则 warn 放行（AC-2 空分支）

### 可观测性

- pre-commit hook stderr 输出带 `[archive-commit-gate]` 前缀
- correction file type=`archive-uncommitted`（登记到 correction-types.sh 常量）
- Stop hook 模块日志写入 hook log（与现有模块一致）

---

## 依赖与约束

### 复用既有抽象

- `correction-file.sh`（write/read/clear/exists 四函数）— AC-3 correction 写入/清除
- `correction-types.sh`（CORRECTION_TYPE_* 常量）— **需新增 CORRECTION_TYPE_ARCHIVE_UNCOMMITTED**（AC-3）
- `commit-protocol.md`（4-dev 任务级协议）— 本 change 扩展归档级段，不改任务级段
- `install_hooks.sh` + `common.sh::HOOK_MODULE_NAMES`（hook 注册机制）— 追加模块 34
- `run_check()`（common.sh）— 新 Stop hook 模块用此模板
- `flow-kit-resume.sh`（SessionStart banner）— type-dispatch 新增 elif 分支

### 禁动清单碰撞声明

- **gate 核心链**（independent-review-gate.sh + 29-independent-review.sh + fk_validate_done_marker）— 不触碰
- **4-dev commit-protocol.md 任务级段** — 不改
- **.flow-active.goal 字段** — 不手编；Stop hook 读 `goal.status` 用直接 jq（遵循 32-fallback-guard.sh:42 先例，hook 内 jq 读不受禁动约束，禁动约束的是 AI agent 手编）
- **PRESET_MAP / gate_config schema** — 不改
- **package-flow-kit.sh**（禁动清单 Part A-E/G）— **声明例外**：HOOK_MODULE_NAMES 同步段需追加 34-archive-commit-check（参照 superpowers-v6-absorb L504-530 Part F 例外先例，仅 HOOK_MODULE_NAMES 段，不动其他 Part）

---

> 本文件定义「做什么」+「验收标准」。部署机制细节（core.hooksPath vs symlink）、hook 脚本内部实现、test 具体用例进入 DESIGN.md / 4-dev。

---

## 附录：调查发现 · PreToolUse 桥接载体确认（2026-08-05）

> 阶段 1 L2 盲审期间，`.done` 被 path-guard 拦截（gate_config=both）触发桥接调查。调查结论修正 l2-l3-subagent-fix 历史结论 + 影响本 change NFR 兼容性判定。

### 桥接载体 = oh-my-opencode 4.19.4

**证据链**：

| 检查项 | 结果 | 说明 |
|---|---|---|
| opencode-acp 源码 grep | ❌ 0 匹配 | opencode-acp 是「Active Context Pruning」（上下文管理），非 hooks 桥接 |
| oh-my-opencode `dist/hooks/claude-code-hooks/` | ✅ 命中 | 模块存在，含 config-loader + pre-tool-use + types 三文件 |
| `types.d.ts` L2-4 注释 | ✅ 映射声明 | 「Maps Claude Code hook concepts to OpenCode plugin events」 |
| `types.d.ts` L5 事件列表 | ✅ 12 种 | PreToolUse/PostToolUse/PostToolUseFailure/PermissionRequest/UserPromptSubmit/Notification/Stop/SubagentStart/SubagentStop/SessionStart/SessionEnd/PreCompact |
| `pre-tool-use.d.ts` L25 | ✅ 执行函数 | `executePreToolUseHooks(ctx, config, extendedConfig)` |
| `config-loader.d.ts` | ✅ 配置读取 | 读 ClaudeHooksConfig + DisabledHooksConfig（含 PreToolUse?: string[]）← `~/.claude/settings.json` |
| opencode.log（运行时验证） | ✅ 508 条 | Stop/00-gate/auto-advance/fallback-guard hook 触发记录 |

### 完整触发链路

```
opencode 工具调用（如 Write .done）
  → oh-my-opencode PreToolUse 事件
  → claude-code-hooks/config-loader 读 ~/.claude/settings.json
  → 匹配 matcher Bash|Write|Edit → independent-review-gate.sh
  → executePreToolUseHooks 执行 `bash independent-review-gate.sh`
  → _gate_path_guard 检测 .done 路径 → 拦截/放行
```

### 对历史结论的修正

| 维度 | l2-l3-subagent-fix EVIDENCE-2 原结论 | 修正结论 |
|---|---|---|
| opencode PreToolUse | ❌ 结构性不触发 | ✅ oh-my-opencode 4.19.4+ 触发 |
| 桥接载体 | 「无桥接插件」 | oh-my-opencode 内置 claude-code-hooks |
| 事件覆盖 | 仅 file_edited + session_completed | 12 种（PreToolUse/Stop/SessionStart/...） |

**注**：l2-l3-subagent-fix 时的旧版 oh-my-opencode 可能尚未包含 claude-code-hooks 模块（`@latest` 拉新版后引入）。L-074（LESSONS · opencode PreToolUse 不触发）**已过时/证伪**，建议后续 change 标记。

### 对本 change 的影响

- **AC-2 pre-commit**：git 层面 hook，不受 IDE 影响（不变）
- **AC-3 Stop hook 34**：✅ opencode 下**确认可达**（oh-my-opencode 支持 Stop 事件）
- **NFR 兼容性**：已修正（hook 层在 opencode 下通过 oh-my-opencode 兼容层触发）
- **gate_config=L2 主 agent 写 .done**：✅ opencode 下放行（path-guard 在兼容层工作，L2-only → `_gate_is_l2_only` 放行）
