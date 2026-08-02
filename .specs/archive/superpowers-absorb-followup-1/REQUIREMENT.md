# REQUIREMENT · superpowers-absorb-followup-1

> 测试补强 change · 3 用户故事 + 5 类 ACs · gate_config=L2

---

## 用户故事

### US-1 · 安全注入测试覆盖（L-064）
作为 flow-kit 维护者，我希望 review-package 和 task-brief 脚本的注入向量（commit msg / TASK.md 内容 / 路径参数）有自动化 bats 测试覆盖，以便未来改脚本时能立即捕获注入漏洞回归。

**Traceability**：本故事由 AC-A1/A2/A3/A4/A5/A6（6 个 SEC 测试）共同支撑。

### US-2 · 集成测试自动化（L-065）
作为 flow-kit 维护者，我希望 review-package + task-brief + GO.md routing + 6-review 改造 + 4-dev 改造之间有端到端 smoke 测试，以便改任一环时快速验证 routing/integration 不退化。

**Traceability**：本故事由 AC-B1/B2/B3/B4/B5（5 个 INT 测试）共同支撑。

### US-3 · Pre-existing 测试 fail 修复（L-067）
作为 flow-kit 维护者，我希望 `test-l2-first-correction.bats` 的 AC-I (b)(c) 两个 fail 被修复，以便全量 bats 跑到 0 fail，避免"通过率"持续低于 100% 影响质量信号。

**Traceability**：本故事由 AC-C1（root cause + 修复）+ AC-C2（无回归）共同支撑。

---

## 验收准则（Given/When/Then）

### 类别 A · 安全注入测试（SEC-1 ~ SEC-6）· 对应 US-1

#### AC-A1（SEC-1）· commit msg shell injection
- **Given** 一个 fixture git repo，最新 commit msg 含 `;rm -rf /tmp/flow-kit-sec-test`
- **When** 执行 `bash scripts/review-package HEAD~1 HEAD > /tmp/out.md`
- **Then** (1) `/tmp/flow-kit-sec-test` 不存在（命令未执行）(2) `/tmp/out.md` 含 `;rm -rf /tmp/flow-kit-sec-test` 字面字符串（被正确引用为 data）
- **验证方式**: bats + test -f /tmp/flow-kit-sec-test 反向断言

#### AC-A2（SEC-2）· TASK.md task name subshell injection
- **Given** 一个 fixture TASK.md，T01 task 块 name 含 `$(touch /tmp/flow-kit-sec-test-2)`
- **When** 执行 `awk -f scripts/task-brief fixtures/TASK_sec.md T01 > /tmp/out.txt`
- **Then** (1) `/tmp/flow-kit-sec-test-2` 不存在 (2) `/tmp/out.txt` 含 `$(touch /tmp/flow-kit-sec-test-2)` 字面字符串
- **验证方式**: bats + test -f 反向断言

#### AC-A3（SEC-3）· commit msg backtick + IFS injection
- **Given** fixture git repo，commit msg 含 `` `echo hijacked` `` 和 `${IFS}`
- **When** 执行 `bash scripts/review-package HEAD~1 HEAD > /tmp/out.md`
- **Then** (1) `/tmp/out.md` 不含 "hijacked" 字符串（backtick 未展开）(2) `/tmp/out.md` 含 `` `echo hijacked` `` 字面字符串
- **验证方式**: bats + grep 反向断言

#### AC-A4（SEC-4）· TASK.md flag injection
- **Given** fixture TASK.md，T01 task 块 name 含换行 + `--output=/tmp/flow-kit-hijacked`
- **When** 执行 task-brief
- **Then** (1) `/tmp/flow-kit-hijacked` 不存在 (2) `/tmp/out.txt` 输出只含一个 task 块（不被 flag 劫持为写到其他位置）
- **验证方式**: bats + test -f 反向断言

#### AC-A5（SEC-5）· 路径遍历防护
- **Given** 当前在 fixture git repo 内
- **When** 执行 `bash scripts/review-package ../../etc/passwd HEAD 2>/tmp/err.log`
- **Then** (1) exit code ≠ 0 (2) `/tmp/err.log` 含 identifiable error message（如 "invalid ref" 或 "unknown revision"）(3) `/tmp/out.md` 不存在或为空（脚本拒绝产出，未尝试读取 fixture 路径）
- **验证方式**: bats + exit code 断言 + grep stderr + test ! -s /tmp/out.md

#### AC-A6（SEC-6）· 非 ASCII（中文/emoji）转义
- **Given** fixture git repo，commit msg 含中文 "修复 bug" + emoji "🚀"
- **When** 执行 review-package
- **Then** (1) `/tmp/out.md` 含 "修复 bug" 原 UTF-8 字节（非 mojibake）(2) `/tmp/out.md` 含 "🚀" 原 UTF-8 字节
- **验证方式**: bats + grep UTF-8 字符串

### 类别 B · 集成测试（INT-1 ~ INT-5）· 对应 US-2

#### AC-B1（INT-1）· review-package 端到端
- **Given** 一个完整 fixture git repo（含 2 个 commits + 1 个 file change）
- **When** 执行 `bash scripts/review-package HEAD~1 HEAD`
- **Then** 输出 markdown 含三段 headers：`## Commits`、`## Files changed`、`## Diff`
- **验证方式**: bats + grep 三个 headers

#### AC-B2（INT-2）· task-brief 端到端
- **Given** 一个完整 fixture TASK.md（含 3 个 task 块 T01/T02/T03）
- **When** 执行 `awk -f scripts/task-brief fixtures/TASK_integration.md T02`
- **Then** (1) 输出只含 T02 块（不含 T01/T03）(2) 输出含 task 块所有字段（id/name/action/verify 等）
- **验证方式**: bats + grep

#### AC-B3（INT-3）· GO.md routing 完整性
- **Given** flow-kit-bundle/flow-kit/GO.md 当前版本
- **When** 执行 `grep -E 'prompts/[0-9]' GO.md`
- **Then** 输出含所有 10 个 phase 入口（0-change / 1-requirement / 2-design / 2a-ui-design / 3-task / 4-dev / 5-test / 6-review / 7-integration + 至少一个 L/A/I/M 横向）
- **验证方式**: bats + grep -c ≥ 10

#### AC-B4（INT-4）· 6-review.md 不再有 Round 1/2/3 字符串
- **Given** flow-kit-bundle/flow-kit/prompts/6-review.md 当前版本
- **When** 执行 `grep -E 'Round [123]' 6-review.md`
- **Then** exit code = 1（无匹配，已彻底移除）
- **验证方式**: bats + grep 反向断言

#### AC-B5（INT-5）· 4-dev.md 三段完整性
- **Given** flow-kit-bundle/flow-kit/prompts/4-dev.md 当前版本
- **When** 执行三个 grep：`task-brief`、`model-tier`、`task_progress`
- **Then** 三个 grep 都至少有 1 个匹配（三段都存在）
- **验证方式**: bats + grep -c ≥ 1 各

### 类别 C · Pre-existing fail 修复（L-067）· 对应 US-3

#### AC-C1 · AC-I (b)(c) root cause + 修复
- **Given** 当前 `test/test-l2-first-correction.bats` 中 AC-I (b) 和 (c) 两个测试 fail
- **When** AC-C1 fix applied: mock setup 含 phase_sub_goals 字段且 correction 路径与 SessionStart 一致
- **Then** (1) `npx bats test/test-l2-first-correction.bats` 全绿 (2) git diff 仅含 `test/*.bats` + `flow-kit-bundle/test/*.bats`，**不含** `flow-kit-bundle/hooks/stop/29-independent-review.sh` 及 `flow-kit-bundle/hooks/stop/lib/` 改动
- **验证方式**: bats + git diff --name-only 检查

#### AC-C2 · 无回归
- **Given** AC-C1 修复后
- **When** 执行 `npx bats test/`
- **Then** 全量 0 fail（之前 643/645，目标 ≥656/656）
- **验证方式**: bats 全量 + exit code = 0

### 类别 D · 双源同步（向 flow-kit-bundle/test/ 复制）· 跨 US

#### AC-D1 · 双源同步
- **Given** 新建/修改的 3 个 bats 文件（test_scripts_security.bats / test_integration_smoke.bats / test-l2-first-correction.bats）
- **When** 执行 `make test-sync`（Makefile target，已存在）
- **Then** `flow-kit-bundle/test/` 下对应文件存在且内容一致（diff 0 行差异）
- **验证方式**: bats + diff

### 类别 E · 打包验证 · 跨 US

#### AC-E1 · package-flow-kit.sh --validate
- **Given** 类别 A/B/C/D 所有 AC 通过后
- **When** 执行 `bash package-flow-kit.sh --validate`
- **Then** exit code = 0（warnings 允许，errors 不允许）
- **验证方式**: bash + exit code 断言

#### AC-E2 · 新增测试性能不退化
- **Given** 类别 A 和 B 的新增 bats 文件已写入 test/ + flow-kit-bundle/test/
- **When** 执行 `time npx bats test/test_scripts_security.bats test/test_integration_smoke.bats`
- **Then** wall-clock 时间 ≤ 5s（单个 SEC/INT 测试 ≤1s，全文件合计 ≤5s）
- **验证方式**: bats runner + `time` 输出断言（或 bash 内 `[ "$SECONDS" -le 5 ]`）

#### AC-E3 · SEC 测试副作用清理
- **Given** SEC-1~SEC-4 测试创建临时文件（如 `/tmp/flow-kit-sec-test*`）
- **When** 整个 `test_scripts_security.bats` 文件跑完（含 teardown）
- **Then** `/tmp/flow-kit-sec-test*` glob 匹配 0 文件（teardown 段已清理）
- **验证方式**: bats + `compgen -G "/tmp/flow-kit-sec-test*"` 反向断言

---

## 范围决策

无设计决策延后到 DESIGN（本次纯测试补强，无新设计）。所有 AC 现在就可验证。

## v1 / v2 / out

### v1（本次完成）
- L-064（SEC 6 测试）
- L-065（INT 5 测试）
- L-067（AC-I b/c 修复）

### v2（不在本次）
- L-061（ADR-016 探测路径验证）— 需 OpenCode task tool live test

### out（永久不做或不做本次）
- L-063（D5/D6 弱模型场景）— 需弱模型实测数据，单独 change
- L-066（AC-B4 测试深度）— 需 AC 措辞澄清，单独 change
- L-068（4-dev.md 体积压缩）— 大改造，独立 `compress-4-dev-prompt` change

---

## 非功能性需求

### 性能
- 新增测试不显著拖慢全量 bats 运行（目标：单文件 ≤5s，全量增量 ≤30s）

### 安全
- SEC 测试本身不能在生产环境留下副作用（`/tmp/flow-kit-sec-test-*` 文件测试后清理，teardown 段保证）

### 兼容性
- 不改 bats-core 版本依赖（保持 1.13.0）
- 不引入新 npm 依赖

### 依赖与假设
- 假设 29 hook 生产代码正确（已被多个 change 验证）
- 假设现有 `test/fixtures/` 目录可扩展（不破坏其他测试对它的依赖）
