# REQUIREMENT · cleanup-debt-batch-2026-08

> **阶段**: 1-requirement · 2026-08-03
> **AI 版本**: GLM 5.2 (Sisyphus, OpenCode)

---

## 用户故事

### US-1 · review-package 输入安全
作为 package-flow-kit 用户，我希望 scripts/review-package 拒绝无效 git ref，以便防范路径遍历与注入风险。

### US-2 · package-flow-kit validate 可信
作为 flow-kit 发布工程师，我希望 `package-flow-kit.sh --validate` 在漏配时返回非零退出码、在无误时报 clean，以便 CI 可以信任 validate 结果。

### US-3 · 29 hook L2-first 契约完整
作为 gate_config=both 的用户，我希望 L2-missing 检测在 L3-model-missing 检测之前触发，以便 L2 子 agent 派发指引 correction 能正常生成（即使 L3 model 未配置）。

### US-4 · 4-dev.md token 经济
作为 flow-kit pipeline 用户，我希望 4-dev.md 从 781 行压缩到 ≤500 行，以减少 per-task reload 成本（当前占 pipeline 总成本 ~40%）。

### US-5 · 批量交付
作为维护者，我希望 5 项债务在一次 pipeline 内完成，避免 5 次重复 phase 0-3-7 开销。

---

## 验收准则（AC）

### 类别 A · L-071 review-package ref validation

**AC-A1** review-package 拒绝无效 ref
- **Given** 当前在 fixture git repo 内（已有 1+ commit）
- **When** 执行 `bash scripts/review-package "../../etc/passwd" HEAD 2>/tmp/err.log; echo $? > /tmp/exit.txt`
- **Then** (1) `/tmp/exit.txt` 内容 ≠ "0"（exit code ≠ 0） (2) `/tmp/err.log` 含 "invalid" 或 "unknown revision" 或 "bad revision" 字样 (3) `/tmp/out.md` 不存在或为空（脚本未输出 review 内容）
- **验证方式**: bats 测试 SEC-5b（去掉 skip） + grep stderr

**AC-A2** review-package 接受合法 ref（回归）
- **Given** fixture git repo 内
- **When** 执行 `bash scripts/review-package HEAD~1 HEAD`
- **Then** exit code = 0 + 输出含 "## Commits" / "## Files changed" / "## Diff" 三段
- **验证方式**: 既有 INT-1 测试必须仍 pass

### 类别 B · L-069 package validate M-health.md

**AC-B1** validate 报 0 ERROR
- **Given** 本仓库工作目录
- **When** 执行 `bash package-flow-kit.sh --validate`
- **Then** (1) exit code = 0 (2) stdout 不含 "🔴 ERROR" 字样
- **验证方式**: bats 测试 + grep stdout

### ~~类别 C · L-070 package validate exit code~~ （已移出范围 · INDEPENDENT-REVIEW-2 R1 验证为假前提）

> **L-070 已确认非 bug**（INDEPENDENT-REVIEW-2 R1 + 主 agent 实测）：`validate_staging_coverage()` at `flow-kit-bundle/lib/validate_staging.sh:127-131` **已经**在 ERRORS>0 时 `exit 1`，caller `package-flow-kit.sh:18-19` 通过 `exit $?` 正确传播。原 tech debt 条目记录有误，本 change 不修改 validate exit code 逻辑。原 AC-C1/AC-C2 撤销。

### 类别 D · L-072 29 hook reorder

**AC-D1** L2-missing 检测优先于 L3-model-missing
- **Given** gate_config[phase]=both + .specs/<id>/INDEPENDENT-REVIEW-N.md 不存在或不含 `## L2 盲审` 段 + 无 FLOW_KIT_L3_MODEL env var
- **When** 执行 Stop hook 29-independent-review.sh
- **Then** (1) `.flow-active.correction` 的 type 字段 = "l2-missing"（不是 "l3-model-missing"） (2) stderr 中"派 L2 子 agent"指引出现（不是"L3 模型未配置"）
- **验证方式**: bats 测试 AC-I(d) 新增（fixture 同 AC-I(b) 但去掉 FLOW_KIT_L3_MODEL）

**AC-D2** L3-model-missing 仍能触发（当 L2 段已写）
- **Given** gate_config[phase]=both + .specs/<id>/INDEPENDENT-REVIEW-N.md 含 `## L2 盲审` 段 + 无 FLOW_KIT_L3_MODEL env var
- **When** 执行 Stop hook 29
- **Then** `.flow-active.correction` 的 type 字段 = "l3-model-missing"
- **验证方式**: bats 测试 AC-I(e) 新增（既有 AC-I(b) fixture + 预先写 L2 段）

### 类别 E · L-068 4-dev.md 压缩

**AC-E1** 4-dev.md 行数 ≤500
- **Given** flow-kit-bundle/flow-kit/prompts/4-dev.md（改造后）
- **When** 执行 `wc -l flow-kit-bundle/flow-kit/prompts/4-dev.md`
- **Then** 输出 ≤500
- **验证方式**: bats 测试 grep + bash arithmetic

**AC-E2** 4-dev.md grep anchors 保留
- **Given** 改造后的 4-dev.md
- **When** 执行 grep 寻找以下 8 个 anchor（每个出现 ≥1 次）: `^### 1\.4`（TDD 入场 · h3）/ `^### 5\.`（提交协议 · h3）/ `^### 6\.`（task 完成提交 · h3）/ `^## 中途断点`（checkpoint · h2，原 `^## 8` 在 4-dev.md 中无对应内容，由 INDEPENDENT-REVIEW-2 R3/R4 修正）/ `task-brief`（task-brief 调用）/ `model-tier`（model-tier 解析）/ `task_progress`（task_progress 写入）/ `@see reference/`（reference 引用）
- **Then** 8 个 grep 全部命中（count ≥1 每个）
- **验证方式**: bats 测试，每个 anchor 一行 `grep -cE '<pattern>' flow-kit-bundle/flow-kit/prompts/4-dev.md`，断言 count ≥1

**AC-E3** reference 片段抽取正确
- **Given** 新建的 reference/tdd-workflow.md / commit-protocol.md / checkpoint-protocol.md
- **When** grep 4-dev.md 中既有段落内容（如 "grep -r" / "1.8 破坏性变更" / "5 段提交"）
- **Then** reference/*.md 中含原内容；4-dev.md 中以 `@see reference/X.md` 引用
- **验证方式**: bats 测试 + grep cross-file

### 类别 F · 整体回归

**AC-F1** 全量 bats 0 fail
- **Given** 所有改动应用
- **When** 执行 `npx bats test/`
- **Then** exit code = 0 + "0 fail" 在输出中
- **验证方式**: 直接命令

**AC-F2** dual-source sync diff = 0
- **Given** 所有改动应用
- **When** 执行 `diff -r test/ flow-kit-bundle/test/ | wc -l`
- **Then** 输出 = 0
- **验证方式**: diff 命令

**AC-F3** CONTEXT.md 禁动清单 exception 段
- **Given** 改造后
- **When** grep CONTEXT.md 禁动清单段
- **Then** 含 "29-independent-review.sh L59-185" 或 "29 hook L2/L3 检测段" 字样的 exception 说明
- **验证方式**: bats 测试 + grep

**AC-F4** US-5 批量交付验证
- **Given** change cleanup-debt-batch-2026-08 的全部任务完成后
- **When** 执行 `git log --oneline --grep="cleanup-debt-batch-2026-08" | wc -l`
- **Then** count ≥ 1（至少有一次提交对应本 change-id）
- **And** 执行 `git diff --name-only HEAD~N HEAD | sort -u | grep -cE 'scripts/review-package|package-flow-kit.sh|29-independent-review.sh|4-dev.md'`（N = 本 change commit 数）→ count ≥ 4（4 个核心模块至少各 1 个文件被触碰）
- **验证方式**: bats 测试 + git log/diff 命令

---

## v1 · v2 · out

### v1 范围（本 change）
- L-068 4-dev.md 781→≤500 行
- L-069 package validate M-health.md
- L-071 review-package ref validation
- L-072 29 hook reorder
- CONTEXT.md 禁动清单 exception 段

> **L-070 已移出 v1 范围**（INDEPENDENT-REVIEW-2 R1 验证为假前提 · validate_staging_coverage() 已正确 exit 1 · 见上文类别 C 段）

### v2 范围（延后）
- 无（剩余 debt 都明确分到 out）

### out 范围（明确不做）
- L-058/060/062: archived superpowers-v6-absorb REQUIREMENT.md 文档 lessons，不动 archive
- L-063: D5/D6 弱模型场景实测，需要弱模型 live env
- L-066: AC-B4 测试深度，需要 AC-B4 wording 重新设计
- 不改其他 hook 模块（仅 29）
- 不改 GO.md（已在 superpowers-v6-absorb 压缩）
- 不改 brooks-lint
- 不引入 superpowers 周边 scripts（review-package/task-brief 已有）

---

## 非功能性需求（NFR）

### 性能
- 新增 bats 测试 ≤5s 单测
- review-package 加 ref validation 后 happy path 延迟增加 ≤10ms（git rev-parse 单次调用）
- 4-dev.md 加载后实际有效内容（task-brief 提取后）目标 ≤15KB（继承 superpowers-v6-absorb AC-B4）

### 安全
- 无新增 shell injection surface（review-package 输入仍受 set -euo pipefail 保护）
- ref validation 用 `git rev-parse --verify`（git 内置安全 API）

### 兼容性
- bash 4.4+ / jq 1.6+（既有）
- 向后兼容：旧 .specs/<id>/REVIEW.md（无 severity 标记）→ 视为 Important（继承 superpowers-v6-absorb 契约）

### 可观测
- L-072 重排后，correction file type 字段值集合不变（仍是 {compliance, l2-missing, l3-model-missing, interactive-ui}）

---

## 依赖与假设

- 既有 review-package 35 行 bash 代码已实现 happy path（superpowers-v6-absorb T01）
- 既有 test-l2-first-correction.bats AC-I(a)(b)(c) 已 pass（superpowers-absorb-followup-1 T03）
- 既有 package-flow-kit.sh::validate_staging_coverage() 函数存在
- L-069 M-health.md 文件实际存在于 flow-kit-bundle/flow-kit/prompts/（已确认）
- 不依赖任何外部 API（与 superpowers-absorb-followup-1 不同，本 change 全部本地修改）

---

## 备注

1. **无范围决策延后到 DESIGN**: 所有 AC 均可在本阶段验证，无 "DESIGN 阶段细化" 自指涉。
2. **token 测量协议**: 继承 superpowers-v6-absorb 双轨协议（结构性 AC 硬门槛 + 参考性指标不卡 toll-gate）。
3. **gate_config=all 处理**: 用户明确要求 all。R5 已知风险：OpenCode 无 ANTHROPIC API → L3 不可用 → 预期降级为 L2-only（与 superpowers-v6-absorb 同处理方式，CHANGE.md R5 已记录）。
4. **severity gating**: 继承 ADR-017。本 change 预期 L2 findings 多为 🟡 Important（涉及禁动清单 29 hook + 大改 4-dev.md）。

---

> Phase 1 自检: ✅ 5 用户故事 · ✅ 14 AC 全部 Given/When/Then（含 R1 fix 后新增 AC-F4） · ✅ v1/v2/out 明确 · ✅ NFR · ✅ 依赖假设 · ✅ 无自指涉 AC
