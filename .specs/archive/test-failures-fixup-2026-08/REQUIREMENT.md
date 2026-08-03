# REQUIREMENT · test-failures-fixup-2026-08

> Phase 1 需求文档 · 2026-08-03

---

## § 1 用户故事

### US-1 · 测试基线 0 fail 恢复
作为 flow-kit 维护者，我希望 5 个 pre-existing bats fail（250 / 507 / 509 / 515 / 577）被修复，使 `npx bats test/` 输出 0 fail。后续 pipeline 不再需要在 TEST.md 中显式标注 "pre-existing"。

### US-2 · Split-aware test 设计
作为 flow-kit 测试者，我希望 split 后的 hook lib 测试能跨 sub-libs grep（反映实际代码组织），而非死板指向单一文件。

### US-3 · Reference-aware test 设计
作为 flow-kit 测试者，我希望 prompt 压缩后的内容测试能跨 4-dev.md + reference/*.md grep，反映 L-068 后的 prompt 组织模式。

---

## § 2 AC（验收准则）

### 类别 A — gate regex test 修复

**AC-A1**: `Given` test_gate_integrity.bats:148-156 → `When` 运行 → `Then` exit=0
- 验证：测试 assertion 重写为「grep 4 文件并断言恰好 1 处命中」（既能确认存在，又能检测 DRY 重复）
- 验证：regex `^(1|2|3|5|6|7)$` 当前实际位置 `gate-helpers.sh:212`，test 应钉到此文件或断言 count=1 跨 4 文件

### 类别 B — 4-dev.md §1.8.4 test 修复（assertion 重写，不只是范围扩大）

**AC-B1**: `Given` test_lessons_cleanup.bats:144-158 (AC-5 npx bats 指令) → `When` 运行 → `Then` exit=0
- 验证：测试 assertion 重写为「逐子断言 OR 双文件」语义——3 个子断言 (`npx bats test/` + `npx bats --version` + `0 failures`) 每个分别在 4-dev.md **或** reference/tdd-workflow.md 命中（per-sub-assertion OR）
- 内容可满足性已确认：tdd-workflow.md:185 (`npx bats --version`) + :188 (`npx bats test/`) + :195 (`0 failures`)

**AC-B2**: `Given` test_lessons_cleanup.bats:174-184 (AC-6 失败阻断) → `When` 运行 → `Then` exit=0
- 验证：测试 assertion 重写——第一子断言关键词 `阻断|暂停流程|禁止进入` 在 4-dev.md 或 tdd-workflow.md 命中（已确认 tdd-workflow.md:196 含全 3 词）；第二子断言原 pattern `修复.*测试失败|重跑.*bats` 在两文件均 0 命中（L-068 后被压缩），改为 `阻断.*toll-gate|禁止进入.*toll-gate` 反映实际 tdd-workflow.md:196 文本
- 范围决策（assertion 重写而非内容补回）：理由是 tdd-workflow.md:196 已用更精确的 "暂停流程，禁止进入 toll-gate" 表达相同语义；旧 pattern 是 L-068 前的 4-dev.md 行文，无需恢复

**AC-B3**: `Given` test_lessons_cleanup.bats:230-236 (子段编号正确) → `When` 运行 → `Then` exit=0
- 验证：测试 assertion 重写——原 pattern `1\.8\.4\.[1-4]` ≥4 在 4-dev.md 和 tdd-workflow.md **均不存在**（L-068 压缩 + 重命名标题）。改为 grep tdd-workflow.md 的实际子段标题：`#### 自动 bats 执行` + `#### 结果判定` + `#### 结果写入 SUMMARY` + `#### L2 自检 gate 填空` 共 4 个 `#### ` 级别标题
- 注：本 AC 引用的原行号 :175-185 错误，实际测试在 :230-236

### 类别 C — shellcheck SC2148 修复

**AC-C1**: `Given` make lint → `When` shellcheck 检查 7 个新 hook lib 文件 → `Then` exit=0（无 SC2148 error）
- 7 文件：l3-prompt.sh / l3-api.sh / l3-truncate.sh / l3-done.sh / gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh
- 修复方式：首行加 `# shellcheck shell=bash` 指令（非 shebang）
- 验证（避免假绿）：除 `make lint` 外，逐文件 `shellcheck -e SC1091 <file>` 必须返 0（shellcheck 缺失时 bats 测试应 skip 而非误判 pass）

### 类别 D — 双源 sync + 回归

**AC-D1**: `Given` 修复完成 → `When` 运行 `diff -r test flow-kit-bundle/test` → `Then` 输出为空（双源一致）
- 注：原写法 `diff test/test_*.bats flow-kit-bundle/test/test_*.bats` 在 globs 展开后语法错（"extra operand"），改用 `diff -r`

**AC-D2**: `Given` 修复完成 → `When` 运行 `npx bats test/` → `Then` **0 fail**（基线恢复；当前 662 tests / 657 ok / 5 fail → 修复后 662/0）

### 类别 E — Delivery meta

**AC-E1**: `Given` 修复完成 → `When` 检查 git → `Then` ≥1 commit + ≥4 files touched（flow-kit 通用 commit 阈值；本 change 预计触及 ~11 files：4 test + 7 lib）

**AC-E2**: `Given` 修复完成 → `When` 检查 .specs → `Then` CONTEXT.md 含本 change-id 引用 + CHANGELOG.md 含 entry + LESSONS.md 同步

---

## § 3 范围决策

- **测试 grep 范围扩大策略**：选择"双文件任一命中即 pass"而非"必须双文件都含"。理由：避免在 4-dev.md 中重复 tdd-workflow.md 内容（违反 DRY）；同时确保至少一个文件含所需内容（防止内容意外删除）。
- **shellcheck 指令选择**：用 `# shellcheck shell=bash` 而非 `#!/bin/bash`。理由：sourced lib 不应被直接执行（添加 shebang 会误导），shellcheck 指令仅影响 lint 行为。

---

## § 4 v1 / v2 / out

- **v1**: 5 个 test fail 全部修复（AC-A1/B1/B2/B3/C1）+ sync + 回归（D1/D2）+ delivery（E1/E2）
- **v2**: 无
- **out**: 无（所有 5 fail 在 v1 一次性清理）

---

## § 5 NFR

- **Performance**: 单测 ≤5s（已有性能）
- **Security**: 无新外部输入 / 无新网络调用
- **Maintainability**: 测试 grep 范围扩大有注释说明理由
- **Testability**: AC 全部 bats 可验证

---

## § 6 Self-check

- [ ] 3 用户故事清晰且不重叠 ✓
- [ ] 9 AC 全部 Given/When/Then 完整 ✓ (A1/B1/B2/B3/C1/D1/D2/E1/E2)
- [ ] 范围决策有理由 ✓
- [ ] NFR 可测 ✓
- [ ] v1/v2/out 明确 ✓

---

**Verdict**: ✅ 准备 L2 审查。
