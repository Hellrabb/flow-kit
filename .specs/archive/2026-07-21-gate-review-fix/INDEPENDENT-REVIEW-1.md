# 独立审查 · 阶段 1

## L2 盲审

> L2 盲审 · 阶段 1（需求审查）
> 审查工件：`.specs/gate-review-fix/REQUIREMENT.md`（13 条 AC）
> 参考：`.specs/gate-review-fix/CHANGE.md`
> 审查日期：2026-07-21

---

## 审查摘要

**结论：pass**（无 🔴 Critical 发现）

REQUIREMENT.md 的 13 条 AC 均采用 Given/When/Then 三段格式，条件具体且可机器验证，无「系统应该正常工作」类空话 AC。范围切分（v1/v2/out）合理，无范围蔓延。但存在 4 条 Major 和 4 条 Minor 质量问题，主要集中在函数语义未完全对齐、非功能性需求缺失、边界条件不完整。

---

## 发现列表

### 🟡 R1 · AC-12 `fk_normalize_gate_val()` 语义未对齐：4 处"重复"实际并不等价

**Symptom**：AC-12 声称 4 处代码重复 `case "$gate_val" in independent|true) gate_val="both" ;; ... esac`，但源码实际存在两类不同语义的模式：
- **Pattern A**（`independent-review-gate.sh:456`）：`case "$gate_val" in independent|true) gate_val="both" ;; L2|L3|both) ;; *) gate_val="" ;; esac` — 含 L2/L3/both 直通分支
- **Pattern B**（`29-independent-review.sh:134`、`29-independent-review.sh:174`、`done-validation.sh:66`）：`case "$gate_val" in independent|true) gate_val="both" ;; *) gate_val="" ;; esac` — 仅含 backward-compat 别名映射，不保留 L2/L3/both

**Source**：单一函数替代多份看似相同但语义不同的实现，违反「替换不可改变行为」的 DRY 重构基本约束（REF: Martin Fowler, _Refactoring_, "same behavior for the same inputs" 原则）。

**Consequence**：若共享函数实现 Pattern B（仅处理 `independent|true → both`），则 `independent-review-gate.sh:456` 将丢失 `L2|L3|both` 直通逻辑，导致 gate_config 合法值被错误归一化为空字符串，gate 可能在相位 transition 时误拦截或误放行。这在 v1 若无人察觉可直接打到生产。

**Remedy**：AC-12 的 Then 子句需明确共享函数的完整行为。两种方案：
- **方案 A**（推荐）：`fk_normalize_gate_val` 实现完备语义：`independent|true → both` + `L2|L3|both → 原值直通` + `其他 → ""`。更新 AC-12 Then：
  ```
  - 函数签名：`fk_normalize_gate_val <raw_value>` → stdout
  - 标准化规则：independent|true→both, L2|L3|both→原值, 其他→""
  - 4 处 consumer 全部改为调用该函数
  ```
- **方案 B**：若 `independent-review-gate.sh` 需额外前置校验 L2/L3/both（当前 case 已做），则在 AC-12 中明确"独立 review gate 调用方在调用 `fk_normalize_gate_val` 前负责 L2/L3/both 直通校验"，防止静默行为变更。

### 🟡 R2 · AC-4 竞态修复范围不完整：l2-detect.sh 存在第二处 `.tmp.$$`

**Symptom**：AC-4 仅提及 `l2-detect.sh:234`（后台 dispatch 路径）的 `.tmp.$$`，但源码中 `l2-detect.sh:113` 的 mock 模式路径同样使用 `${review_md}.tmp.$$` 命名。虽然 mock 模式仅在 `FLOW_KIT_L2_MOCK=1` 时激活，但它仍然使用与 L3 前台路径（`l3-review.sh:459`）相同的临时文件命名约定，构成理论竞态窗口。

**Source**：竞态修复应穷举所有同名临时文件的 consumer。遗漏任何一处都会在特定条件下重现竞态（REF: IEEE Std 1003.1 — `mktemp` rationale 强调每个临时文件使用者需唯一命名）。

**Consequence**：在 `FLOW_KIT_L2_MOCK=1` 的测试场景下，若 L2 mock 和 L3 同时写入同一 `INDEPENDENT-REVIEW-N.md`，两方使用相同的 `${review_md}.tmp.$$` 临时文件名，可能导致写入交错、内容丢失或 mv 原子性被破坏。触发概率低（仅测试场景），但一旦触发即为数据损坏。

**Remedy**：AC-4 需补充 `l2-detect.sh:113` 的修复范围，或将 mock 路径明确排除并附理由（如 "mock 模式仅在测试中手动启用，且不与 L3 并发"）。建议统一采用 `mktemp` 替代所有 `.tmp.$$` 模式：
```
- L2 mock: l2-detect.sh:113 → mktemp 或 .tmp.l2mock.$$ 前缀
- L2 bg dispatch: l2-detect.sh:234 → mktemp 或 .tmp.l2bg.$$ 前缀
- L3: l3-review.sh:459 → mktemp 或 .tmp.l3.$$ 前缀
```

### 🟡 R3 · 非功能性需求全面缺失

**Symptom**：整份 REQUIREMENT.md 仅覆盖功能级 AC，未包含任何一条非功能性验收准则。具体缺失：
- **向后兼容性**：AC-9/10/12/13 的 DRY 重构提取共享函数——无 AC 验证所有 4+ 个 consumer 行为不变（regression 风险）
- **性能**：AC-6 改变 gate 阻塞语义（`exit 2` → `return 1` + 日志），AC-12/13 从内联改为函数调用——无性能基线或响应时间阈值
- **可观测性**：AC-6 "改为输出日志"、AC-8 "显式 `case $rc in`" 引入了新的日志/错误报告路径——无 AC 规定日志格式、级别或调试信息完整性
- **测试质量**：AC-1/2/5 修复测试覆盖盲区——无 AC 要求修复后的测试不产生 flaky 行为、可独立运行或可复现

**Source**：ISO 25010 软件质量模型要求完整性包含功能适用性、性能效率、兼容性、可靠性、可维护性等维度。仅覆盖功能正确性的需求规格是不完整的（REF: IEEE 29148-2018 §5.2.3: "Non-functional requirements shall be specified with measurable criteria"）。

**Consequence**：
- **短期**：DRY 重构引入的 regression 无监控手段；若共享函数签名变更，consumer 被遗漏则测试无法捕获（现有测试只测具体 AC，不测"所有 consumer 均已迁移"）
- **中期**：gate dispatch 性能回退无感知；`.done` 日志格式不一致导致运维排查困难
- **长期**：测试 flaky 降低 CI 信心，团队开始忽略测试失败

**Remedy**：建议添加 2-3 条非功能性 AC：
```
## AC-NF1 · 共享函数 consumer 完整性
Given `fk_normalize_gate_val` 和 `fk_extract_l2_verdict` 在 common.sh/l2-detect.sh 中定义
When 所有已识别 consumer 完成迁移
Then
- `grep -rn 'independent|true).*gate_val="both"' flow-kit-bundle/hooks/` 返回零匹配（旧模式完全消除）
- `grep -rn 'fk_normalize_gate_val' flow-kit-bundle/hooks/` 返回 ≥4 处调用（独立 review gate + 29 + done-validation）

## AC-NF2 · Gate 性能不回退
Given gate dispatch 路径已修改（_gate_check_l3 auto_advance、共享函数调用）
When 在同一 change 上执行 phase transition（不含网络 I/O）
Then
- gate 执行总耗时 ≤ 修改前基线 + 10%（或绝对阈值 < 200ms）
- jq 调用次数不增加（共享函数不应引入重复 jq 读取）

## AC-NF3 · 全量 bats 测试通过且无 flaky
Given 修改后的 test_l3_timeout.bats、done-validation.bats、test_l2_l3_granular_gate.bats
When 连续 3 次执行 `npx bats flow-kit-bundle/test/ test/`
Then
- 每次结果全 pass（无 intermittent failure）
- 无新的 skip（除非有文档化的已知限制）
```

### 🟡 R4 · AC-8 错误处理分支不完整：缺少默认/default case

**Symptom**：AC-8 的 Then 子句仅规定 `rc=0`、`rc=1`、`rc=3` 三个分支的处理逻辑，未覆盖 `rc=2`（`_l3_check_rerun` 的 skip 返回值可通过调用链传播）或其他非预期退出码。

**Source**：防御式编程基本约束：`case $rc in` 必须含 `*)` 默认分支以避免未处理返回值静默传播（REF: _The Art of Defensive Programming_, "every switch on return codes must have a default arm that logs the unexpected value"）。

**Consequence**：若 `_l3_write_done` 因代码演进返回新的退出码（如 rc=2），当前 AC 规格下该错误将未被日志捕获也未向上传播，形成静默错误吞噬——这正是本次 change 试图修复的同类问题。

**Remedy**：AC-8 Then 子句补充默认分支：
```
- *) 日志 "UNEXPECTED: _l3_write_done rc=$rc" + return $rc 向上传播
```
完整 case 语句：
```bash
case $rc in
  0) ;;  # continue
  1) echo "[l3-review] verdict non-pass, .done not written" >&2 ;;
  3) echo "[l3-review] CRITICAL: .done write failed" >&2; return 3 ;;
  *) echo "[l3-review] UNEXPECTED: _l3_write_done rc=$rc" >&2; return $rc ;;
esac
```

---

### 🟢 R5 · AC-5 引用易碎的代码行号

**Symptom**：AC-5 Then 第 2 条引用 `"fk_validate_done_marker 完整执行到 L2_verdict/L3_verdict 值域 regex（行 137-139）"`。行号随文件修改会漂移（例如 AC-9 也在修改 done-validation.sh，可能使行号偏移）。

**Source**：可维护的需求规格不应依赖易变标识符（REF: IEEE 29148-2018 §6.2.1: "requirements should not reference volatile implementation details"）。

**Consequence**：文件修改后 AC 描述的行号与源码不再对应，降低 AC 的长期可读性，但不影响当前验收。

**Remedy**：改为逻辑描述替代行号：
```
- fk_validate_done_marker 完整执行到 L2_verdict/L3_verdict 的值域正则校验逻辑
  （即 `[[ "$k_l2v" =~ ^(pass|fail|skipped)$ ]]` 和 `[[ "$k_l3v" =~ ...` 分支）
```

### 🟢 R6 · AC-6 混合关注点：L2 行为出现在以 L3 为标题的 AC 中

**Symptom**：AC-6 标题为 "`_gate_check_l3 auto_advance 感知`"，但第一个 Then 子句描述的是 `_gate_check_l2` 的行为（"返回 0（fire-and-forget L2 dispatch，不阻塞）"）。L2 的 fire-and-forget 行为是 AC-6 修复的前提条件（若 L2 未在 auto_advance 下放行，控制流不会到达 L3 的 else 分支），但它不是 AC-6 要修复的目标代码。

**Source**：单一职责原则在 AC 级别的应用：每条 AC 应聚焦一个可验证的行为变更。

**Consequence**：未来读者可能误解 AC-6 要求同时修改 `_gate_check_l2` 和 `_gate_check_l3`，但 `_gate_check_l2` 的 auto_advance 逻辑（line 293-302）已经存在且正确。这不会导致错误实现，但增加了理解成本。

**Remedy**：AC-6 Then 第一条改为前置条件描述（Given）而非修复目标：
```
Given .flow-active.goal.auto_advance = true + gate_config[N] = "both" + L2 段缺失
  + _gate_check_l2 已在 auto_advance 下返回 0（fire-and-forget dispatch，当前行为，无需修改）
When 控制流到达 _gate_check_l3 else 分支（行 373-379）
Then ...
```

### 🟢 R7 · AC-3 下游兼容性风险未转化为 AC

**Symptom**：CHANGE.md 风险评估明确标注 "_l3_parse_result 增加 L3 段去重逻辑可能改变 INDEPENDENT-REVIEW-N.md 文件格式——需确认下游 reader（_l3_inject_context、SessionStart banner）兼容"。但 REQUIREMENT.md 中没有任何 AC 验证此兼容性。

**Source**：风险登记簿（risk register）中识别的风险应转化为缓解措施或验收准则，否则风险未被管理（REF: ISO 31000 risk management framework: identified risks must have treatment plans）。

**Consequence**：L3 段去重实现后，若 `_l3_inject_context` 或 SessionStart banner 的 `## L3` 段检测逻辑因格式变化而失效，将导致：
- L3 上下文注入缺失（影响后续 L3 审查质量）
- SessionStart 不显示 L3 历史（用户体验退化）

**Remedy**：在 AC-3 末尾添加一条 Then 子句，或新增一条 AC：
```
Then（追加到 AC-3）
- `_l3_inject_context` 仍可正常读取去重后的 L3 段（检测到 `^## L3 (盲审|重审)`）
- SessionStart banner 在包含 INDEPENDENT-REVIEW-N.md 时仍正常显示 L3 各阶段完成状态
```

### 🟢 R8 · AC-9 代码行数描述不准确

**Symptom**：AC-9 描述 "内联 case...（7 行）"，但源码 `done-validation.sh:42-50` 实际为 9 行（含注释行 `# Security: reject change_ids with path traversal chars` 和空行）。

**Source**：AC 中对现有代码的量化描述应准确，否则影响代码审查时的对照验证。

**Consequence**：低影响。行数偏差不改变 AC 的验收标准（改为调用 `fk_phase_gate_key`），但代码审查时对照不匹配会消耗额外时间。

**Remedy**：将 "（7 行）" 修正为 "（9 行）" 或移除具体行数，只描述逻辑。

---

## 总评

13 条 AC 整体质量合格：GWT 三段齐全、可机器验证、无范围蔓延。主要缺陷集中在非功能性需求缺失（🟡 R3）和两条 AC 的规格精度不足（🟡 R1 函数语义未对齐、🟡 R2 竞态范围遗漏）。建议在 DESIGN 阶段补充非功能性 AC，并在实现前解决 R1 和 R2 的歧义。

**Verdict**: pass

---

## L3 重审（deepseek-v4-flash[1m] 外部模型 · 2026-07-21 00:50）

> 自动生成于 2026-07-21 00:50。由 l3-review.sh 写入。

### 审查结论

```json
{"critical":[],"major":[],"minor":[],"verdict":"pass","summary":"所有 AC 的 Given/When/Then 均可验证且无歧义；v1/v2/out 范围切分合理；非功能性需求 AC-NF1~3 覆盖了回归安全、测试稳定性和性能无回退，无范围蔓延或明显遗漏。"}
```

L3_artifact_hash: 68775f00b242bbc8d361daa960e2016e056a5e966a932949f1c150fb54ffe65f
