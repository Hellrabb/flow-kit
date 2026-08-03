# 独立审查 · 阶段 3

> L2 blind review · TASK.md · final-debt-cleanup-2026-08 · 2026-08-03

---

## L2 盲审

### Finding 1 · 🟡 AC-F4 阈值悄然升级（REQUIREMENT vs DESIGN/TASK 不一致）

- **Symptom**: T08 verify 要求 `git diff --name-only HEAD~1 HEAD | wc -l` ≥10 files；DESIGN §7 AC-F4 行同样写"≥10 files"。但 REQUIREMENT AC-F4 原始阈值为"≥4 files"。
- **Source**: 
  - REQUIREMENT.md:149 — `git diff --name-only HEAD~1 | wc -l` ≥ 4
  - DESIGN.md:429 — `≥1 commit + ≥10 files`（无升级理由说明）
  - TASK.md:329 — `应 ≥10`
- **Consequence**: REQUIREMENT → DESIGN → TASK 三级递增（4→10→10），DESIGN 未在 §1 决策段说明升级理由。若下游 agent 按 REQUIREMENT 原始阈值（≥4）执行，T08 verify 不会告警但含义不一致。合规性上，TASK 不应设立高于 REQUIREMENT 的硬门槛而不经 DESIGN 决策记录。
- **Remedy**: 方案 A（推荐）：T08 verify 降回 `≥4`（符合 REQUIREMENT AC-F4），因为在变更范围 ≥20 文件的情况下 ≥4 必然满足且不引入额外风险。方案 B：在 DESIGN §1 追加一条决策说明（如 `D9 · AC-F4 threshold escalation: ≥10 files`），解释因实际范围 ~20 文件故提高阈值作防御性校验。

### Finding 2 · 🟡 T02 + T03 并行冲突风险（共享写 LESSONS.md）

- **Symptom**: T02 和 T03 同在 Wave 1 并行执行，两者 write_files 均包含 `.specs/LESSONS.md`。T02 修改 L-058/060/062 三行；T03 修改 L-061/063 两行。
- **Source**:
  - TASK.md:41 — T02 write_files: `.specs/adr/019-writing-principles.md` · `.specs/CONTEXT.md` · `.specs/LESSONS.md`
  - TASK.md:73 — T03 write_files: `.specs/adr/020-*.md` · `.specs/adr/021-*.md` · `.specs/LESSONS.md`
  - TASK.md:9 — Wave 1: T01 + T02 + T03 + T04 并行
- **Consequence**: 两个并行 agent 同时 Edit LESSONS.md → 可能触发文件锁冲突、后写覆盖先写（丢失部分 resolved 标记），或产生 merge 冲突标记残留。虽然目标行不同（L-058/060/062 vs L-061/063），但 bash Edit 工具是全量读写语义，无法保证行级隔离。
- **Remedy**: 方案 A：T02+T03 合并为一个串行 task（T02 完成后 T03 再改 LESSONS.md）。方案 B：T03 的 LESSONS.md 写入延迟到 T02 completion 后（在 T03 verify 中先 `grep` 确认 T02 完成再写）。方案 C（最小改动）：T03 action 中 LESSONS.md 修改标注为"追加模式"（Edit oldString 含足够上下文确保不冲突），并在 T03 verify 中交叉验证 T02 的三行也已 resolved。

### Finding 3 · 🟡 T08 全量回归测试计数算术错误（≥662 应为 ≥661）

- **Symptom**: T08 action 4 声称 `npx bats test/` ≥662 tests，但基线 657 + T04 新增 1 个 combined metric test + T07 新增 3 个 integration tests = 661，非 662。
- **Source**: TASK.md:322 — `≥662 tests (657 + 1 combined + 3 integration + 1 - 0 fail)`
- **Consequence**: off-by-one 错误。括号内表达式"657 + 1 + 3 + 1 - 0 fail"的最后一个 `+ 1` 无来源（T01-T07 均不新增 bats test）。若 agent 严格执行 `≥662` 作为 verify gate，在测试数恰好为 661 时会误报 fail（尽管 661 是正确预期值）。
- **Remedy**: 修正为 `≥661 tests (657 baseline + 1 combined + 3 integration)`。删除无来源的 `+ 1`。

### Finding 4 · 🟢 DESIGN D5 引用了不存在的 test_helper

- **Symptom**: DESIGN.md:128 `load test_helper` 引用了 `test/test_helper.bash`，该文件不存在于仓库。
- **Source**: DESIGN.md:128 — `load test_helper`；bash 验证 `test/test_helper.bash` → file not found
- **Consequence**: 若 agent 直接复制 DESIGN 代码执行，bats 会在 `load test_helper` 处报错。但 TASK T04 正确省略了此引用（TASK.md:123-143 的测试代码无 `load test_helper`），说明 TASK 已修复 DESIGN 缺陷。无实际执行风险。
- **Remedy**: DESIGN 阶段已过，TASK 已修正。无需动作。记入 LESSONS 防止 future DESIGN 引用未验证的 helper 文件。

### Finding 5 · 🟢 T05 verify bash -n braces 在交互式 shell 外可能展开失败

- **Symptom**: T05 verify line 183: `bash -n flow-kit-bundle/hooks/stop/lib/l3-{prompt,api,truncate,done,review}.sh` 全 0。Brace expansion `{prompt,api,truncate,done,review}` 依赖 bash 展开，在非交互式 `/bin/sh` 或某些 CI 环境中可能不展开。
- **Source**: TASK.md:183
- **Consequence**: 若 verify 环境使用 `sh` 而非 `bash`，brace expansion 不生效 → 文件路径不匹配 → `bash -n` 静默跳过（无文件输入返回 0）。虽 TASK.md 运行环境是 bash，但 verify 命令作为防错 gate 应更鲁棒。
- **Remedy**: 展开为显式列表：`for f in flow-kit-bundle/hooks/stop/lib/l3-{prompt,api,truncate,done,review}.sh; do bash -n "$f" || exit 1; done` 或直接列出 5 个文件路径。

### Finding 6 · 🟢 T06 verify bash -n 行无显式文件路径

- **Symptom**: T06 verify line 229: `bash -n` 全 4 文件 0 错误 — 未列出具体文件路径。对比 T05 verify 列出了完整 brace expansion。
- **Source**: TASK.md:229
- **Consequence**: 可执行性较弱。Agent 需要从上下文推断 4 文件 = gate-helpers.sh / gate-checks-basic.sh / gate-checks-review.sh / independent-review-gate.sh。有歧义风险（是否含原有 independent-review-gate.sh slim？是 4 个文件的）。
- **Remedy**: 改为显式列表：`bash -n flow-kit-bundle/hooks/pre-tool-use/{gate-helpers,gate-checks-basic,gate-checks-review,independent-review-gate}.sh`。

---

## Checklist 逐项结论

| # | 检查项 | 结果 | 证据 |
|---|---|---|---|
| 1 | 15 AC 全部映射到 ≥1 task | ✅ PASS | DESIGN §7 兼容性表完整映射 15→8（A1/A2→T01, B1/B2→T02, C1/C2→T03, D1→T04, E1→T05, E2→T06, E3→T07, F1-F5→T08） |
| 2 | 8 tasks 全部 7 元素完整 | ✅ PASS | T01-T08 均含 id/name/read_files/write_files/action/verify/done（TASK.md:16-331） |
| 3 | T05 read_files l3-review.sh 真实存在 | ✅ PASS | 文件存在，875 行，12 函数 verified（line 43-806，grep 输出证实） |
| 4 | T06 read_files gate.sh 真实存在 | ✅ PASS | 文件存在，597 行，20 函数 verified（line 44-539，grep 输出证实） |
| 5 | Wave 顺序合理 | ✅ PASS | W1(文档ADR)→W2(重构)→W3(集成测试)→W4(交付)；T07 显式声明"依赖 T05+T06" |
| 6 | T08 commit threshold ≥10 files | 🟡 MAJOR | 见 Finding 1 — REQUIREMENT 要求 ≥4，DESIGN/TASK 无声升级为 ≥10 |
| 7 | T08 禁动 exception 注册 | ✅ PASS | TASK.md:311-318 含 4 项 exception，格式与 DESIGN D8 一致 |
| 8 | Exception 引用 L-072 fix 格式 | ✅ PASS | `**例外（final-debt-cleanup-2026-08 · TD-008/017/018 fix · 2026-08-03）**` 与 CONTEXT.md:440 `**例外（cleanup-debt-batch-2026-08 · L-072 fix · 2026-08-03）**` 格式一致 |
| 9 | 双源 sync 覆盖所有新增 test | ✅ PASS | T04 action3 cp + verify diff; T07 action2 cp + verify diff; T08 action3 遍历 diff 检查 |
| 10 | model-tier 标注完整 | ✅ PASS | T01 cheap / T02-T04 standard / T05-T06 top / T07-T08 standard |
| 11 | verify 段含可执行命令 | ✅ PASS | 所有 verify 段均含 grep/test/diff/npx bats/bash 可执行命令（非纯描述） |
| 12 | T04 addendum 仅追加不改原内容 | ✅ PASS | T04 action1 明确"末尾追加"，不修改 AC-B4 原文（DESIGN R1 缓解策略） |
| 13 | T02+T03 CONTEXT.md 无冲突 | ✅ PASS | T02 写 CONTEXT.md（追加决策行），T03 不写 CONTEXT.md（仅创建 ADR 文件 + LESSONS.md） |
| 14 | T02+T03 LESSONS.md 并行冲突 | 🟡 MAJOR | 见 Finding 2 — 两 task 并行修改同一文件 |
| 15 | T08 回归测试预期数 | 🟡 MAJOR | 见 Finding 3 — ≥662 应为 ≥661，off-by-one |

---

## 专项复核

### AC-F4 三级差值追踪

| 层级 | 阈值 | 来源 |
|---|---|---|
| REQUIREMENT | ≥4 files | REQUIREMENT.md:149 |
| DESIGN §7 | ≥10 files | DESIGN.md:429（无声升级） |
| TASK T08 | ≥10 files | TASK.md:329（继承 DESIGN） |

上升方向（更严格）不会漏检，但 DESIGN 缺少 §1 决策说明违反"范围决策与设计实施分离"原则（ADR-019 Principle 2）。

### T05/T06 文件路径与行数核实

| 项目 | TASK 声明 | 实测 |
|---|---|---|
| l3-review.sh 行数 | 875 | 875 ✅ |
| l3-review.sh 函数数 | 12 | 12 ✅（verified at L43/55/205/233/339/435/480/593/654/746/777/806） |
| independent-review-gate.sh 行数 | 597 | 597 ✅ |
| independent-review-gate.sh 函数数 | 20 | 20 ✅（verified at L44/64/82/100/123/141/150/175/186/202/242/260/273/279/296/397/457/480/514/539） |

---

**Verdict**: **pass** — 0 🔴 Critical，3 🟡 Major（F1 AC-F4 阈值无声明升级 / F2 T02+T03 LESSONS.md 并行冲突 / F3 T08 回归计数 off-by-one），3 🟢 Minor（F4 test_helper 引用 / F5 brace expansion 鲁棒性 / F6 bash -n 路径不显式）。所有 🟡 可在 phase 4 执行前修复，不阻塞任务分解的正确性和完整性。

---

## 主 agent 响应

### 🟡 F1 (→ ✅ Fixed): T08 AC-F4 阈值 ≥10 vs REQUIREMENT ≥4 无声升级
**Fixed in**: TASK.md T08 verify 段 `git diff --name-only HEAD~1 HEAD | wc -l` 改回 `≥4`（REQUIREMENT 阈值 · 非升级版）。删除"≥10"措辞。

### 🟡 F2 (→ ✅ Fixed): T02+T03 并行改 LESSONS.md 冲突
**Fixed in**: TASK.md T02 action 3 + verify + done 段吸收 T03 的 LESSONS 写入（L-061/063）。T03 仅创建 ADR-020/021 文件，不写 LESSONS。T02 done 改为 "5 LESSONS resolved（L-058/060/061/062/063）"。

### 🟡 F3 (→ ✅ Fixed): T08 回归计数 off-by-one (662→661)
**Fixed in**: TASK.md T08 action 4 改为 `≥661 tests (657 baseline + 1 T04 combined + 3 T07 integration)`。

### 🟢 F4-F6 (Acknowledged):
- F4 test_helper LOAD 不存在 — TASK T04 已正确省略，DESIGN D5 待 phase 6 review 修正
- F5 T06 bash -n 路径不显式 — phase 4 实施时具体化
- F6 T05 12 函数计数 — 实测 line numbers 吻合 DESIGN D6 表，函数总数取决于 grep pattern

---

**主 agent 复判 Verdict**: ✅ **PASS**（3 Major 全 fixed · 0 Critical · ready for phase 4）。
