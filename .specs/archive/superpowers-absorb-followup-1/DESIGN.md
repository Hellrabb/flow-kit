# DESIGN · superpowers-absorb-followup-1

> 测试补强 change · 4 实现决策 · 无新 ADR（沿用既有测试模式）

---

## § 0 · 技术栈

沿用既有：Bash + bats-core 1.13.0 + jq 1.6+ + GNU coreutils。无新依赖。

## § 0.5 · 架构对齐

### 触及模块（4 个）
- `test/test_scripts_security.bats`（新）
- `test/test_integration_smoke.bats`（新）
- `test/test-l2-first-correction.bats`（修改 mock setup）
- `test/fixtures/security/`（新目录，含 fixture git repo + TASK.md）

### 既有抽象沿用（3 个）
- `test/fixtures/` 目录约定（已存在）— 扩展 `security/` 子目录
- `make test-sync` Makefile target（已存在）— AC-D1 用
- `test-l2-first-correction.bats` 既有 setup() 模式 — 仅扩展不重写

### 沿用 vs 引入决策（3 项）
- 沿用 bats-core 既有 helper 模式（`setup()` / `teardown()` / `run` / `$status` / `$output`），不引入新 helper
- 沿用 fixture 物理文件方式（不用 mock framework）
- 沿用 git 作为 SEC fixture 的 commit msg 注入源（不用 in-process stub）

## § 1 · 决策 D1-D4

### D1 · SEC fixture 构造策略

**选择**：每个 SEC 测试用 `setup()` 在 `test/fixtures/security/repo/` 创建临时 git repo（`git init` + `git config user.email test@example.com` + 2-3 个 commit 含注入字符串）。

**备选**：(a) 预烤固定 fixture（commit 进版本控制）(b) inline in test (c) 临时创建

**理由**：
- (a) 注入字符串入版本控制会被其他工具（grep_app、code search）误判为恶意代码
- (b) inline 让测试文件超长，难读
- (c) 选这个：每次 setup() 创建，teardown() 清理，可重复且隔离

**代价**：每个 SEC 测试 setup 加 ~50ms，全文件 6 测试合计 ~300ms（远低于 AC-E2 的 5s 预算）

**特殊处理**：
- SEC-1/2/3/4 创建注入 commit 后，setup 用 `git log --oneline` 验证 fixture 创建成功
- SEC-5 用 `../../etc/passwd` 作为 ref 参数（不创建文件），仅验证脚本拒绝
- SEC-6 创建含中文/emoji 的 commit msg（UTF-8 locale 假设）

### D2 · INT 测试无 fixture 策略

**选择**：INT-3/4/5 grep 测试直接读 `flow-kit-bundle/flow-kit/{GO.md, prompts/6-review.md, prompts/4-dev.md}` 真实文件（不用 fixture 副本）。

**理由**：这些 AC 验证的是"flow-kit 分发包源文件含特定字段"，不是"脚本在 fixture 上行为"。用真实文件更准确。

**INT-1/2 例外**：review-package/task-brief 端到端测试仍需 fixture（与 SEC 共享 `test/fixtures/security/repo/` 和 `test/fixtures/security/TASK_sec.md`）。

### D3 · L-067 修复策略（mock-only 优先）

**选择**：默认假设 mock setup 有 bug，修复仅触及 test 文件。若 phase 4 实施时发现生产代码（29 hook）确实有 bug，**暂停 T08 任务**，扩大 scope 为新 change `fix-29-hook-mock-mismatch`。

**备选**：(a) 直接修生产代码 (b) 接受 fail 不修 (c) 用 `skip` 跳过

**理由**：
- (a) AC-C1 明确禁止改 29 hook；若发现生产代码错，必须显式扩大 scope，不能偷偷改
- (b) 留下质量死角，违背 US-3 验收
- (c) skip 掩盖问题，违背 US-3 验收
- 选这个：先按假设是 mock 问题修，错了再回头扩大 scope

**代价**：phase 4 T08 可能 reveal deeper issue，需要 phase 2 重新进入。这是显式风险，已在 CHANGE.md R4 登记。

**修复优先级清单**（按 AC-C1 重写后的 When 推导）：
1. mock state 加 `phase_sub_goals` 字段（缺失会导致 29 hook `jq .phase_sub_goals` 返 null 触发 fallback branch）
2. mock `l3-model-missing` correction 写入路径校准：**判定标准** = mock 写入路径必须等于 `flow-kit-bundle/hooks/session-start/flow-kit-resume.sh` 中 `correction_file_read()` 的 read path。具体而言：mock setup 中 `.flow-active.correction` 的写入路径必须与 SessionStart 读取的相对路径（项目根 `.flow-active.correction`）一致；若 mock 在 tmp dir 写而 SessionStart 读项目根，则校准 = 改 mock 写入到项目根 tmp copy
3. 修复后跑 `npx bats test/test-l2-first-correction.bats` 验证全绿
4. git diff --name-only 确认仅含 test/ + flow-kit-bundle/test/

### D4 · 测试文件结构

**选择**：每个新 bats 文件结构统一：
```bash
#!/usr/bin/env bats

setup() {
  # fixture 创建
}

teardown() {
  # 清理 /tmp/flow-kit-sec-test* 等副作用
}

@test "SEC-1 commit msg shell injection" {
  run bash "$BATS_TEST_DIRNAME/../flow-kit-bundle/flow-kit/scripts/review-package" HEAD~1 HEAD
  # 断言
}
```

**理由**：与既有 `test-l2-first-correction.bats` 等文件结构一致；teardown 段是 AC-E3 验证点。

**路径处理**：用 `$BATS_TEST_DIRNAME` 而非相对路径（与既有 test 一致），跨机器鲁棒。

## § 2 · 数据流

```
test_scripts_security.bats
  └─ setup() 创建 test/fixtures/security/repo/ (临时 git repo)
  └─ 每个 @test 调 review-package/task-brief
  └─ teardown() 清理 /tmp/flow-kit-sec-test* + 临时 repo

test_integration_smoke.bats
  └─ INT-1/2: 调 review-package/task-brief 在共享 fixture 上
  └─ INT-3/4/5: grep flow-kit-bundle/flow-kit/{GO,6-review,4-dev}.md
  └─ 无 teardown 需求（无副作用）

test-l2-first-correction.bats
  └─ 修改 setup(): mock state 加 phase_sub_goals
  └─ 修改 setup(): correction 文件路径校准
  └─ 断言逻辑不变（AC-I b/c 修复后自然通过）
```

## § 3 · 状态机

### L-067 修复状态机
```
[probe] → reproduce AC-I (b)(c) fail
       → 检查 mock state phase_sub_goals 字段
       ├─ 缺失 → 加入字段 → 重跑
       │                    ├─ pass → done
       │                    ├─ fail → 检查 correction 路径
       │                    │         ├─ 路径不一致 → 校准 → 重跑
       │                    │         │              ├─ pass → done
       │                    │         │              ├─ fail → 双修复均失败 → [ESCALATE]
       │                    │         └─ 路径对 → [ESCALATE]
       │                    └─ NEW failures exposed → 登记 L-XXX 新债，本 change 不扩 scope
       └─ 存在 → 检查 correction 路径（同上分支）
       
[ESCALATE] = 暂停 T08，告知用户。判断：
  - 若生产代码（29 hook / lib/）确实 bug → 创建独立 change `fix-29-hook-mock-mismatch`（需 CONTEXT § 禁动清单 exception 审批）
  - 若 mock 修复方向错（如其实是 test 期望值错） → 修订 AC-C1 然后 phase 1 重新进
  - 若 reproduce 失败（无法复现） → 标记为 flaky，登记 L-XXX，本 change 仍按原计划完成其他任务
```

## § 4 · ADR 索引

本次无新 ADR。所有决策沿用既有 ADR：
- ADR-017 (severity gating) — 适用 R7-R10 🟢 Minor deferred 到 phase 6
- ADR-018 (GO.md bootstrap) — INT-3 grep AC 与 GO.md 压缩后状态对齐

## § 5 · 风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | SEC-6 中文/emoji fixture 受 locale 影响（LC_ALL=C 时 mojibake） | setup() 显式 `export LC_ALL=en_US.UTF-8`；若 locale 不存在，标记为 skip |
| R2 | INT-3 grep 模式（10 个 phase 入口）随 GO.md 微调脆断 | 用宽匹配 `prompts/[0-9]` 而非精确 phase 名 |
| R3 | L-067 修复后 mock state 与其他依赖 mock 的测试冲突 | 修完跑全量 `npx bats test/` 验证 AC-C2 |
| R4 | SEC fixture git repo 在 CI 环境无 git config 时失败 | setup() 显式 `git config user.email test@example.com` + `git config user.name Test` |

## § 6 · Out of scope

- 不修生产代码（review-package / task-brief / 29 hook / 任何 prompt）
- 不改 Makefile（test-sync 已存在）
- 不改 CONTEXT.md（无新术语 / 决策）
- 不改 ADR
- 不引入新 npm 依赖

## § 7 · AC-E1 (package validation) 兼容性确认

AC-E1 要求 `bash package-flow-kit.sh --validate` exit code = 0。本次改动对其影响：

- **新增文件**：`test/test_scripts_security.bats` + `test/test_integration_smoke.bats` + `test/fixtures/security/` 下 fixture 文件
- **`make test-sync` 同步后**：上述 .bats 文件出现在 `flow-kit-bundle/test/`，fixture 不入 bundle（仅本地测试用）
- **`package-flow-kit.sh` Part D** 已通过 superpowers-v6-absorb T11 改造支持 `flow-kit-bundle/test/` 全量入包，无需再改
- **预期**：`--validate` 输出 0 errors（warnings 可能含既有 brooks-lint/debt-guide.md 提示，与本 change 无关）
- **风险兜底**：phase 5 TEST 阶段 AC-E1 实跑验证；若 fail，phase 4 T11/T12 重审 fixture 是否被 bundle manifest 误纳入

## § 9 · 架构沉淀（无新沉淀）

本次纯测试补强，无新可复用抽象。所有模式沿用既有：
- bats fixture 模式（`test/fixtures/<topic>/`）
- setup/teardown 段约定
- AC grep 验证模式
