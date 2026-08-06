# 独立审查 · 阶段 1

---

## L2 盲审

### 🔴 R1 · AC-8 硬编码测试数量与新增测试自相矛盾

**Symptom（症状）**：`REQUIREMENT.md:76` — AC-8 的 Then 子句写 "462 条测试全绿 0 fail"，验证方式写 "462 tests, 0 failures"。但 AC-3 要求新增 ≥ 2 条 check 去重测试（:39），AC-7 要求新增 ≥ 4 条 DRY_RUN 测试（:67）。当前基线 462 条（已验证 `npx bats test/ --count` = 462）。执行 AC-8 时实际测试数至少为 462 + 6 = **468**，不是 462。

**Source（源头）**：验收准则一致性原则——同文档内的 Then 子句不能自相矛盾。AC-8 作为全量回归兜底 AC，其预期值必须与上游 AC 的增量一致。

**Consequence（后果）**：若实现者严格按 "462" 设置断言（`expect 462 tests`），则新增测试后 CI 断言必然失败（实际 ≥468 ≠ 462）；若实现者将 AC-8 理解为"排除新增测试的原有 462 条"，则新增测试不在回归保护范围内，AC-8 的兜底语义失效。

**Remedy（修补）**：删除硬编码数字，改为：

```markdown
- **Then** 全量 bats 测试全绿 0 fail；`make test` exit 0
- **验证方式**: `make test` 或 `npx bats test/` 输出 `0 failures`
```

或若坚持保留数量断言，写入动态预期：

```markdown
- **Then** 全量 bats 测试全绿 0 fail；测试总数 ≥ 468（462 基线 + AC-3 新增 ≥2 + AC-7 新增 ≥4）
```

---

### 🔴 R2 · AC-2 验证方式含不可机器执行的手工步骤

**Symptom（症状）**：`REQUIREMENT.md:32` —— 验证方式写 "手工确认 PreToolUse gate 拦截正常"。

**Source（源头）**：Phase 1 checklist 第 1 条——"每条 AC 是否 Given/When/Then 三段齐全且**可机器验证**（拒绝「系统应该正常工作」这类空话）"。手工确认不可复现、不可自动化，与 "可机器验证" 直接冲突。

**Consequence（后果）**：CI 管道无法自动判定 AC-2 是否通过——每次必须人工介入。当 gate 逻辑被后续变更意外破坏时，无自动化保护，缺陷只能靠人工发现。与 AC 作为自动化质量闸门的定位冲突。

**Remedy（修补）**：将手工确认替换为可机器执行的 bats 测试。验证方式改为：

```markdown
- **验证方式**: `wc -l` 检查行数 + `npx bats test/` 全绿 + 新增 bats 测试验证 `_run_review_gates` 在独立审查 tool call 场景返回 0、在非独立审查场景返回非零
```

对应的 bats 用例应在 `TEST.md` 中展开为可执行脚本（Given: 模拟一次非独立审查 tool call / When: 调用 `_run_review_gates` / Then: exit code ≠ 0 且 stderr 含预期拒绝消息）。

---

### 🟡 R3 · AC-5 Then 子句含主观判断，不可客观度量

**Symptom（症状）**：`REQUIREMENT.md:52` — Then 写 "新贡献者/ AI 可从函数名推断模块归属"。

**Source（源头）**：Phase 1 checklist 第 1 条——AC 必须可机器验证。"是否能推断" 因人而异、因 AI 模型而异，无法客观判定 PASS/FAIL。

**Consequence（后果）**：若此句是 AC-5 的核心验收标准之一，则该 AC 本质不可验收。验证方式中 `grep` 命中 ≥ 5 条说明可以过关，但 Then 子句的语言暗示了一个比 grep 更宽泛的期望——文档质量是否"足够好到让人能推断"，而这无法用脚本验证。

**Remedy（修补）**：将主观判断降级为注释（不纳入 Then），或改写为可客观验证的表述：

```markdown
- **Then** CONTEXT.md 命名约定段完整描述 5 种前缀（`fk_` / `_fk_` / `check_` / `l2_`/`l3_` / `_fai_`）各自含义、可见性层级（公共 API / 模块私有 / 文件私有）、典型使用场景；每种前缀 ≥ 1 条说明
```

---

### 🟡 R4 · `is_gh_pr_create()` 重命名兼容性影响未在 NFR 段声明

**Symptom（症状）**：`REQUIREMENT.md:30` — AC-2 要求将 `is_gh_pr_create()` 重命名为 `_run_review_gates()`；但非功能性需求的兼容性段（:108-109）仅覆盖 `l3_review_run()` 签名不变，完全未提 `is_gh_pr_create` 改名的影响面。

**Source（源头）**：Phase 1 checklist 第 3 条——"是否遗漏非功能性需求（兼容性）"。函数重命名是一种接口变更（即便只是内部函数），需评估调用方的兼容性影响。

**Consequence（后果）**：若除 `independent-review-gate.sh` 自身外有其他 source 或调用方依赖 `is_gh_pr_create` 名称，重命名会导致运行时 `command not found` 错误。当前 spec 未做调用方审计，存在遗漏风险。

**Remedy（修补）**：在兼容性 NFR 段补充：

```markdown
- **兼容性**: ... `is_gh_pr_create()` 重命名为 `_run_review_gates()` 需确认调用方仅限于 `independent-review-gate.sh` 自身；若存在外部调用方，需保留别名 `is_gh_pr_create() { _run_review_gates "$@"; }` 作为过渡，或一并更新调用方
```

受影响的调用方确认可通过 `grep -r "is_gh_pr_create" flow-kit-bundle/` 完成并记录在 REQUIREMENT.md 假设段。

---

### 🟡 R5 · TD-017（l3_review_run 拆分）缺性能 NFR

**Symptom（症状）**：`REQUIREMENT.md:107` — 性能 NFR 仅覆盖 TD-018（`is_gh_pr_create` → `_run_review_gates`），未覆盖 TD-017（`l3_review_run()` 拆分为 4 子函数 + 编排器）。

**Source（源头）**：Phase 1 checklist 第 3 条——"是否遗漏非功能性需求（性能）"。函数拆分引入额外调用层级（4 次函数调用 + 传参开销），应评估是否在性能敏感路径上。

**Consequence（后果）**：拆分后 L3 review 路径多出 4 层间接调用；虽然单次开销微小（纳秒级），但若 review 流程中被多次触发，累积退化可能被忽视。无基线→无回归标准→无法客观判断。

**Remedy（修补）**：两种选择：

1. 若 L3 review 非性能敏感路径，显式声明：

```markdown
- **性能**: TD-017（`l3_review_run` 拆分）不在热路径上（仅在 review 阶段触发），无性能约束
```

2. 若需基线，补充：

```markdown
- **性能**: TD-017 拆分前后各跑 3 次完整 L3 review 流程取中位数，允许 ±10% 耗时差异
```

---

### 🟡 R6 · AC-3 验证阈值"显著下降"未量化

**Symptom（症状）**：`REQUIREMENT.md:39` — 验证方式写 `grep -c "check_enabled" flow-kit-bundle/hooks/stop/2*-*.sh` 显著下降。当前基线：`check_enabled` 在 7 个停止 hook 模块（20-26；27/28/29 无命中）中共出现 **30 次**（已实测）。"显著"是多少？降至 15？5？0？

**Source（源头）**：Phase 1 checklist 第 1 条——AC 必须可机器验证，需量化阈值。无量化 = 不可自动判定。

**Consequence（后果）**：CI 管道无法自动判定 AC-3 PASS/FAIL——不同审查者对"显著"的定义不同。实现者可能只消除一半模板就声称达标，或消除了全部但 grep 计数因遗留调用方式略有差异而被质疑。

**Remedy（修补）**：明确可量化阈值。根据当前基线（30 次出现在 7 模块），提议：

```markdown
- **验证方式**: 各 `2*-*.sh` 中 `check_enabled` 直接调用全部消除，改为经 `run_check()` 间接调用；`grep -c "check_enabled" flow-kit-bundle/hooks/stop/2*-*.sh` 返回 ≤ 1（仅 `run_check()` 的定义体中自身调用）；`npx bats test/` 全绿
```

---

### 🟢 R7 · AC-1 / AC-2 行数硬约束属于实现细节，非需求

**Symptom（症状）**：`REQUIREMENT.md:24` — "编排器 `l3_review_run()` ≤ 50 行；每个子函数 ≤ 80 行"；`:31` — "`_run_review_gates()` ≤ 40 行"。这些是实现约束（How），不是需求（What）。

**Source（源头）**：Phase 1 审查应关注需求层面的验收标准。行数上限是合理的设计护栏，但更适合放在 DESIGN.md 或 TASK.md 中作为实现约束，而非作为需求的 Then 条件。

**Consequence（后果）**：低风险。若事后发现编排器需要 55 行才能清晰表达控制流，严格按 50 行约束可能导致代码被过度压缩（可读性反而下降）。不过当前数值合理（307→50 的改善已巨大），不阻塞。

**Remedy（修补）**：考虑将具体行数约束移至 DESIGN.md 或 TASK.md，REQUIREMENT.md 保留定性描述（如 "编排器足够短，一屏可读，职责清晰可辨"）。如保留在 REQUIREMENT.md 中亦可接受——不是阻塞项。

---

### 🟢 R8 · AC-6 评估结论写入目标含"或"歧义

**Symptom（症状）**：`REQUIREMENT.md:59` — "评估结论写入 CHANGE.md 或 CONTEXT.md"。验证脚本需同时检查两个位置才能判定 AC-6 通过，或实现者任选一处写入导致验证脚本对另一处误报。

**Source（源头）**：AC 验收标准应单一明确。"或"使验收目标二元化，增加验证脚本复杂度（需检查两处，任一处命中即可）。

**Consequence（后果）**：低风险。实现者大概率写入一处，但自动化验证需处理两个可能位置，增加微小维护成本。

**Remedy（修补）**：

```markdown
- **Then** 评估结论写入 CONTEXT.md（长期文档）；同时在 CHANGE.md 中标注决策概要
```

---

**Verdict**: fail

---

## 主 agent 响应（修复记录）

| ID | 严重度 | 处置 | 修复内容 |
|----|--------|------|----------|
| R1 | 🔴 | ✅ Fixed | AC-8 删除硬编码 "462"，改为 "全量 bats 测试全绿 0 fail；`make test` exit 0"，验证方式改为 "输出 `0 failures`" |
| R2 | 🔴 | ✅ Fixed | AC-2 验证方式移除 "手工确认"，改为新增 bats 测试验证 `_run_review_gates` 在独立审查/非审查场景的正确返回值 |
| R3 | 🟡 | ✅ Fixed | AC-5 Then 子句改为主观判断→可客观验证：5 种前缀含义/可见性/场景完整描述，每种 ≥1 条 |
| R4 | 🟡 | ✅ Fixed | NFR 兼容性段补充 `is_gh_pr_create`→`_run_review_gates` 重命名的调用方审计要求 + 兼容别名方案 |
| R5 | 🟡 | ✅ Fixed | NFR 性能段补充 TD-017 不在热路径声明："仅 L3 review 阶段触发，无性能约束" |
| R6 | 🟡 | ✅ Fixed | AC-3 验证方式量化阈值：`check_enabled` 直接调用全部消除 → `grep -c` ≤ 1（仅 `run_check()` 定义体） |
| R7 | 🟢 | Noted | 行数约束保留在 REQUIREMENT.md（R7 自身标注为非阻塞项），DESIGN.md 不再重复 |
| R8 | 🟢 | ✅ Fixed | AC-6 消除 "或" 歧义：评估结论写入 CONTEXT.md（长期）+ CHANGE.md 标注概要 |

8/8 已处置。两条 🔴 阻塞项已消除。
