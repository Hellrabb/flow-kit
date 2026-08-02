
## L2 盲审

### 🔴 Critical

**C1 · AC-A5 (SEC-5) Then (3) 根本上不可验证**
- **Symptom**: Line 57 — `Then (3) 不读取 /etc/passwd 内容`。bats 无 strace/ptrace 能力，无法断言"文件未被读取"这一否定性 OS 级行为。
- **Source**: AC 可验证性原则 — AC 必须可被自动化测试直接观察到。测试工具无法观测的 claim 是伪需求。
- **Consequence**: (a) 实施者在 phase 5 会面临不可能三角：要么 fake-verify（grep stdout 不含 /etc/passwd 片段，偷换概念），要么 skip（留缺口），要么浪费时间去实现不存在的 instrumentation。(b) 产生虚假安全信心——AC 声称验证了路径遍历防护，但关键断言无法兑现。
- **Remedy**: 移除 Then (3)，或将 Then (3) 改为可验证的代理指标——例如"stdout/stderr 不含 fixture `/etc/passwd` 的文件内容片段"（提前构造一个包含已知标记字符串的 fixture `/tmp/flow-kit-test-etc-passwd`，而非依赖真实系统文件）。

---

### 🟡 Major

**M1 · NFR 性能无对应 AC**
- **Symptom**: Line 154 — `单文件 ≤5s，全量增量 ≤30s`。全文 16 条 AC（A1–A6, B1–B5, C1–C2, D1, E1）无一条验证运行时性能。
- **Source**: NFR 原则 — 每个非功能性需求必须有至少一个 AC 做硬性验证，否则无法在 phase 5 通过/不通过判定。
- **Consequence**: 性能退化无自动化检测——某测试加了 `sleep 60` 也不会被任何 gate 拦截。
- **Remedy**: 添加 AC-E2（或其等价），形式为 `Given 全量测试完成后, When 执行 time npx bats test/test_scripts_security.bats, Then 实际耗时 ≤ 5s`。若设计判断认为该目标是参考性而非门禁级，需在 NFR 段显式标注 `(参考性，不卡 gate)`。

**M2 · NFR 安全（teardown 清理）无对应 AC**
- **Symptom**: Line 157 — `SEC 测试本身不能在生产环境留下副作用（/tmp/flow-kit-sec-test-* 文件测试后清理，teardown 段保证）`。无 AC 验证 teardown 实际执行了清理。
- **Source**: 同上 — NFR 无 AC。
- **Consequence**: 若测试的 teardown 段有 bug（如 `trap` 未注册或路径拼写错误），残留文件不会被发现。当前 SEC AC（A1–A4）只验证"注入未发生"，不验证"测试自身清理完成"。
- **Remedy**: 在 AC-A1 或独立 SEC-AC 的 Then 中追加一条 `test ! -f /tmp/flow-kit-sec-test-*`（bats `teardown` 后校验），或在 AC-E1 的 Then 追加 teardown 后无残留文件断言。

**M3 · AC-A3 When 子句缺少命令参数**
- **Symptom**: Line 44 — `When 执行 review-package`。对比 AC-A1（明确写出 `bash scripts/review-package HEAD~1 HEAD > /tmp/out.md`），A3 省略了具体命令和重定向目标。
- **Source**: AC 精确性原则 — When 必须指定完整触发命令及参数，确保实施者无歧义。
- **Consequence**: 实施者需自行推测命令参数（用 HEAD~1 HEAD？还是与 A1 不同的范围？重定向到哪个文件？）。推测错误 → 测试与意图偏离。
- **Remedy**: 将 When 改为 `bash scripts/review-package HEAD~1 HEAD > /tmp/out.md`（若 commit msg 在 HEAD 上）或明确写出 HEAD 的范围。

**M4 · AC-D1 When 子句含或关系（非确定性）**
- **Symptom**: Line 116 — `When 执行同步（cp 或 make test-sync）`。一条 AC 的 When 子句含两个不同的命令。
- **Source**: AC 确定性原则 — When 子句必须映射到单一、可重复的动作。`X 或 Y` 意味着测试文件可以走 X、也可以走 Y，两条路径行为可能不同。
- **Consequence**: (a) bats 实现时只能选一个，若选 `cp` 则 `make test-sync` 失测。(b) 反过来亦然。(c) 两条路径若行为不一致，测试抓到其中一条 → 假绿。
- **Remedy**: 选定一个命令（建议 `make test-sync`，与 CONTEXT.md `[2026-07-10]` 双源测试同步决策一致），删除备选。

**M5 · AC-E1 Given 子句模糊**
- **Symptom**: Line 123 — `Given 所有改动完成后`。未定义"所有改动"的边界。
- **Source**: AC 具体性原则 — Given 必须描述可观测的系统状态，而非模糊的阶段描述。
- **Consequence**: (a) 实施者不确定何时触发此 AC——是类别 D 完成后？所有 AC 通过后？(b) 若与其他 AC 的时序耦合，执行顺序未指定。
- **Remedy**: 改为 `Given 所有类别 A/B/C/D AC 通过后`，或 `Given git diff 仅含 test/*.bats 且 flow-kit-bundle/test/ 已同步`。

---

### 🟢 Minor

**m1 · AC-C1 When 嵌入 HOW**
- **Symptom**: Line 102 — `When 调查 root cause 并修复（mock setup 补齐 phase_sub_goals 字段 + 校准 correction 文件路径）`。When 本该是一个触发条件（如 `When mock setup 含 phase_sub_goals 字段`），却内嵌了调查过程 + 修复方案的实现细节。
- **Source**: AC 风格指南 — When 描述可观测触发条件，不描述实施步骤。
- **Consequence**: 不影响可验证性（Then 仍然可测），但降低可读性——读者分不清哪些是验收条件、哪些是实现建议。
- **Remedy**: 将 When 改为 `When mock state 含 phase_sub_goals 字段 + correction 文件路径与 SessionStart 读取路径一致`。

**m2 · NFR 兼容性无 AC**
- **Symptom**: Lines 160–161 — `不改 bats-core 版本依赖（保持 1.13.0）`、`不引入新 npm 依赖`。无 AC 验证 `package.json` / `node_modules` 未变更。
- **Source**: NFR 无 AC（轻量级——兼容性约束通常靠 code review 检查即可）。
- **Consequence**: 若实施者不小心 `npm install` 了新包，无人察觉。
- **Remedy**: 若认为风险可接受，在 NFR 段标注 `(靠 git diff review 检查，不设自动化 AC)`。否则添加 AC 检查 git diff 不含 `package.json` 变更。

**m3 · AC-B4 Then 附加主观措辞**
- **Symptom**: Line 89 — `exit code = 1（无匹配，已彻底移除）`。`已彻底移除` 是主观声明，不是可观测条件。
- **Source**: AC 客观性原则 — Then 应描述可观测结果，不加价值判断。
- **Consequence**: 无害，但混入判断性语言降低了 AC 作为"合同"的精确性。
- **Remedy**: 删除 `已彻底移除`，保留 `exit code = 1（无匹配）`。

**m4 · AC-C1 Then (2) "29 hook 生产代码" 指代模糊**
- **Symptom**: Line 103 — `不含 29 hook 生产代码改动`。29 hook 是 `29-independent-review.sh` 还是包括其 lib 依赖（`l3-review.sh` / `done-validation.sh`）？范围未定义。
- **Source**: AC 具体性原则 — 必须引用具体文件路径或 glob 模式。
- **Consequence**: 若实施者改了 `hooks/stop/lib/l3-review.sh`（29 hook 的依赖），是否算违规？AC 未说清。
- **Remedy**: 明确禁改范围，如 `不含 hooks/stop/29-independent-review.sh 及 hooks/stop/lib/*.sh 改动`，或改为 `仅含 test/*.bats 和 flow-kit-bundle/test/*.bats`。

---

### 统计

| 严重度 | 数量 |
|--------|------|
| 🔴 Critical | 1 |
| 🟡 Major | 5 |
| 🟢 Minor | 4 |

**Verdict: fail**


---

## 主 agent 响应

### 🔴 R1 (AC-A5 Then (3) 不可验证) · Fixed
- Fixed in: REQUIREMENT.md AC-A5 重写为 `test ! -s /tmp/out.md`（脚本拒绝产出验证），删除"不读取 /etc/passwd 内容"原文（承认 bats 无 OS 级 syscall trace 能力，不能验证 I/O 层未发生事件）
- 新 Then (3): "/tmp/out.md 不存在或为空（脚本拒绝产出）" — 通过 bash `test ! -s` 可直接验证
- 同时补全 When 缺失的命令参数（`bash scripts/review-package ../../etc/passwd HEAD 2>/tmp/err.log`）

### 🟡 R2 (NFR Performance 无 AC) · Fixed
- Fixed in: 新增 AC-E2（`time npx bats test/test_scripts_security.bats test/test_integration_smoke.bats` wall-clock ≤5s）

### 🟡 R3 (NFR Security teardown 无 AC) · Fixed
- Fixed in: 新增 AC-E3（teardown 后 `/tmp/flow-kit-sec-test*` glob 匹配 0 文件）

### 🟡 R4 (AC-A3 When 缺命令参数) · Fixed
- Fixed in: AC-A3 When 改为 `bash scripts/review-package HEAD~1 HEAD > /tmp/out.md`（与 AC-A1 格式对齐）

### 🟡 R5 (AC-D1 sync 命令二义性) · Fixed
- Fixed in: AC-D1 When 改为单一命令 `make test-sync`

### 🟡 R6 (AC-E1 Given 模糊) · Fixed
- Fixed in: AC-E1 Given 改为 "Given 类别 A/B/C/D 所有 AC 通过后"

### 🟢 Minor R7-R10 (4 项) · Deferred to MINOR-DEFERRED.md
- R7 (AC-C1 When embeds HOW) — 保留原 When 但补"AC-C1 fix applied"前置条件作为 Then 一部分（兼顾可读性 + 触发性）
- R8 (NFR Compatibility 无 AC) — 标记为 aspirational，不补 AC（依赖不变更由 git diff 自动保障）
- R9 (AC-B4 "已彻底移除" judgmental) — 改为 "即不再存在"
- R10 (AC-C1 Then (2) "29 hook 生产代码" 范围模糊) — 改为具体路径 `flow-kit-bundle/hooks/stop/29-independent-review.sh` 及 `flow-kit-bundle/hooks/stop/lib/`
- 已在本次修复中一并清理（R9/R10 在 AC-C1 重写时顺手修），R7/R8 留 phase 6 MINOR-DEFERRED.md

---

**Fix loop verdict**: 1🔴 + 5🟡 全部修复或转 🟢，4🟢 中 2 项顺手修，2 项留 phase 6。R1（critical 不可验证）已被具体可验证的 `test ! -s` 取代。Phase 1 可放行至 1→2 transition。
