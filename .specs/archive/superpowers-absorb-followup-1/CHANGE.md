# CHANGE · superpowers-absorb-followup-1

> 测试补强 followup · 2026-08-03 起 · 衔接 superpowers-v6-absorb 归档后的 L-064/065/067 三项技术债

---

## Why（为什么做）

`superpowers-v6-absorb` 归档后留下 3 项测试相关技术债：

- **L-064** · 安全注入测试缺失 — review-package / task-brief 两个新脚本暴露在用户输入（commit msg / TASK.md 内容）路径上，但 bats 测试只覆盖 happy path。REGRESSION 风险：未来改脚本时无法捕获注入漏洞回归。
- **L-065** · 集成测试无自动化 — 新脚本 + 改造后的 6-review.md / 4-dev.md / GO.md 之间无端到端 smoke。每次改其中一环，需要人工跑一遍验证 routing，容易遗漏。
- **L-067** · AC-I (b)(c) pre-existing failures — `test-l2-first-correction.bats` 中 2 个测试因 mock state 与 29 hook 真实逻辑不对齐而失败。superpowers-v6-absorb 归档时通过率 643/645，2 个 fail 不阻塞 pipeline 但留下质量死角。

这三项都是测试债，**没有功能改动**，风险低、收益清晰，适合打包为单一小 change 一次性处理。

## What（做什么 · 3 类改动）

### 1. 新增 `test/test_scripts_security.bats`（L-064）

覆盖 review-package + task-brief 的注入向量，至少 6 个测试：

| ID | 测试 | 验证向量 |
|---|---|---|
| SEC-1 | commit msg 含 `;rm -rf /` 字符 | review-package 输出未执行注入命令 |
| SEC-2 | TASK.md task name 含 `$(date)` | task-brief 输出未展开 subshell |
| SEC-3 | commit msg 含 backtick + `${IFS}` | review-package 输出未展开 |
| SEC-4 | task 块 name 含 `\n--output=/etc/passwd` | task-brief 不被 flag injection 劫持 |
| SEC-5 | 路径遍历 `../../etc/passwd` 作为 base/head | review-package 退出 ≠0 + stderr |
| SEC-6 | 非 ASCII（中文/emoji）commit msg | 输出正确转义无 mojibake |

### 2. 新增 `test/test_integration_smoke.bats`（L-065）

端到端 smoke 测试，至少 5 个测试：

| ID | 测试 | 验证 |
|---|---|---|
| INT-1 | review-package 在 fixture git repo 跑通 | 产出 markdown 三段（## Commits / Files changed / Diff） |
| INT-2 | task-brief 在 fixture TASK.md 跑通 | 产出单 task 块文本 |
| INT-3 | GO.md 含所有 10 个 phase 入口 routing | grep 验证 |
| INT-4 | 6-review.md 不再含 "Round 1/2/3" 字符串 | grep 反向验证 |
| INT-5 | 4-dev.md 含 task-brief + model-tier + task_progress 三段 | grep 验证 |

### 3. 修复 `test/test-l2-first-correction.bats` AC-I (b)(c)（L-067）

调查 + 修复 2 个 pre-existing fail：

- AC-I (b) · mock state 不含 `phase_sub_goals` 字段，真实 29 hook 读取时返空触发 fallback branch
- AC-I (c) · mock `l3-model-missing` correction 写入路径与 SessionStart 读取路径不一致

修复策略：在 mock setup 中补齐字段 + 校准路径，**不改 29 hook 生产代码**（生产代码已被多个 change 验证）。

## 影响面

- **新建**：`test/test_scripts_security.bats` + `test/test_integration_smoke.bats` + 双源同步到 `flow-kit-bundle/test/`
- **修改**：`test/test-l2-first-correction.bats`（仅 mock setup，不改断言逻辑）
- **不动**：`flow-kit-bundle/flow-kit/scripts/*` / `flow-kit-bundle/flow-kit/prompts/*` / `flow-kit-bundle/hooks/*`（本次纯测试补强）
- **不动**：CONTEXT.md（本次无新术语 / 新决策）
- **不动**：ADR（本次无新架构决策）

## 范围排除

- ❌ L-061（ADR-016 探测脚本路径）— 需 OpenCode task tool live test，不能闭门造车，留到下次有实测机会
- ❌ L-063（D5/D6 弱模型场景退化）— 需弱模型（minimax-m2.7 等）实测数据
- ❌ L-066（AC-B4 测试深度）— 需先澄清 AC-B4 措辞
- ❌ L-068（4-dev.md 体积压缩）— 大改造，独立 change `compress-4-dev-prompt`
- ❌ 不改生产脚本 / 不改 prompt / 不改 hook

## 验收线

- **新增 ≥11 个 bats 测试**（SEC 6 + INT 5）+ **修复 2 个 pre-existing fail**（L-067）
- **全量 bats 0 fail**（当前 643/645 → 目标 656+/656+）
- **双源同步**：`test/` 与 `flow-kit-bundle/test/` 一致（AC-7 dual-source test sync）
- **不改生产代码**：git diff 仅含 `test/*.bats` 文件
- **`package-flow-kit.sh --validate` 仍 ✓**

## 风险与未知

| # | 风险 | 缓解 |
|---|---|---|
| R1 | AC-I (b)(c) 修复暴露更多 pre-existing fail（连锁发现） | 控制范围：仅修 mock 不动生产；新暴露的 fail 登记为新 L-XXX，不在本 change 修 |
| R2 | SEC 测试的 fixture 需要精心构造 git repo + TASK.md | 复用 `test/fixtures/` 现有目录；新建 `test/fixtures/security/` 子目录 |
| R3 | INT-3/4/5 grep 测试可能太脆（prompt 微调就断） | 使用宽匹配（如 `task-brief` 关键词而非完整命令字符串） |
| R4 | L-067 mock 修复方向判断错误（生产代码才是错的） | phase 2 DESIGN 阶段先 reproduce + root cause；若生产代码错，扩大 scope 或拆独立 change |
