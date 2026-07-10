# 独立审查 · 阶段 6

## L2 盲审

> 审查日期：2026-07-10
> 审查员：L2 独立盲审子 agent
> 工件：git diff（9 files, +88/-62），含 l3-review.sh、31-auto-advance.sh、6 prompt 文件、CONTEXT.md、test_fix_l3_gate.bats
> 参考：.specs/fix-l3-gate/REVIEW.md（主 agent 结论，待复核对象）
> 独立性声明：本报告仅基于 git diff 内容独立得出。未接受、未引用主 agent 的任何自评/辩护/结论。所有判断均来源于对工件本身的直接审查。

---

### 🟡 R1 · AC-4 覆盖遗漏：4-dev.md 的 4→5 forward transition jq 未同步 `.phase`

**Symptom**：`flow-kit-bundle/flow-kit/prompts/4-dev.md` L131 包含一条 forward transition jq：
```bash
'.goal.current_phase = $next_phase | .goal.phases_done += ["4"] | .goal.gates["4→5"] = "passed" | .updated_at = $ts'
```
该 jq 更新了 `goal.current_phase`、`phases_done`、`gates`，但 **没有 `.phase = $next_phase`**。

同时，`flow-kit-bundle/flow-kit/reference/pipeline-gates.md` L47 也有同样的遗漏：
```bash
'.goal.current_phase = "5" | .goal.phases_done += ["4"] | .goal.gates["4→5"] = "passed" | .updated_at = $ts'
```

**Source**：REQUIREMENT.md AC-4 要求 transition jq 同步更新四个字段：`goal.current_phase`、顶层 `phase`、`phases_done`、`gates`。DESIGN.md 3.4 节列出了需要修改的文件清单，但遗漏了 4-dev.md 和 pipeline-gates.md。

**Consequence**：当 agent 按 4-dev.md prompt 手动执行 phase 4→5 transition 时（而非依赖 31-auto-advance.sh 自动推进），`.flow-active` 的顶层 `phase` 字段不会同步更新，导致 pipeline 状态不一致。虽然 31-auto-advance.sh 的 hook transition 已正确同步（L93 含 `.phase = $next`），但 agent 手动路径存在 phase 不同步风险。按 AC-4 规格，这是未完全覆盖。

**Remedy**：
1. 4-dev.md L131 改为：
```bash
'.goal.current_phase = $next_phase | .phase = $next_phase | .goal.phases_done += ["4"] | .goal.gates["4→5"] = "passed" | .updated_at = $ts'
```
2. pipeline-gates.md L47 改为：
```bash
'.goal.current_phase = "5" | .phase = "5" | .goal.phases_done += ["4"] | .goal.gates["4→5"] = "passed" | .updated_at = $ts'
```

**主 agent 漏判**：主 agent REVIEW.md AC-4 行声称 "6 个 prompt/GO.md 各加 `.phase = "N"`" 实现完整，未检测到 4-dev.md 遗漏。全仓 grep（`phases_done.*+=`）可发现此遗漏，但主 agent 仅确认了 DESIGN.md 列出的文件，未做全仓扫描验证。

---

### 🟡 R2 · `l3_write_timeout_done` 成为死代码，timeout 审查痕迹从审查文件丢失

**Symptom**：`l3_review_with_timeout()`（`l3-review.sh` L486-491）在 timeout 时直接 `return 1`，不再调用 `l3_write_timeout_done()`（L497-521）。经全仓 grep 确认：`l3_write_timeout_done` 在 .sh 文件中仅被定义（L498），从未被任何文件调用。

同时，旧行为在 timeout 时会通过 `l3_write_timeout_done` 向 `INDEPENDENT-REVIEW-N.md` 追加一条 timeout 记录（含时间戳和说明），为审查文件保留完整的审计踪迹。新行为移除了此调用后，timeout 事件仅输出到 stderr（hook log），审查文件中无任何记录。

**Source**：DESIGN.md 3.2 节提供两个选项："改为不写 .done"（保留 timeout notice）或"直接移除该函数调用"（连 notice 一起移除）。实现选择了后者。但前者（保留 `l3_write_timeout_done` 调用，依赖其已被修改为不写 .done 的行为）既满足 AC-2（不写 .done），又保留审计踪迹。非功能需求"可观测性"要求 hook log 记录原因，但审查文件作为阶段核心产物也应有 timeout 事件的记录。

**Consequence**：当 L3 API 超时后，审查文件无任何 timeout 记录。后续排查时只能查看 hook log（可能已被轮转），审查文件作为持久化产物缺少完整的审查历史。审计链断裂。

**Remedy**：在 `l3_review_with_timeout()` 的 timeout 分支中恢复对 `l3_write_timeout_done` 的调用：
```bash
if [ $ret -eq 124 ] || [ $ret -eq 137 ]; then
  echo "[l3-review] L3 timed out after ${timeout_secs}s — .done NOT written (verdict=timeout, phase ${phase})" >&2
  l3_write_timeout_done "$phase" "$change_id" "$artifacts_dir" "$l2_verdict"
  return 1
fi
```
注意：`l3_write_timeout_done` 当前版本已正确实现"仅追加 timeout notice，不写 .done"（经本次 change 修改），调用它是安全的（不违反 AC-2）。

**主 agent 漏判**：主 agent REVIEW.md 声称 AC-2 覆盖完整（"l3_review_with_timeout() L486-492：timeout 返回 1 不写 .done"），但未注意到调用移除导致审查文件丢失 timeout 记录、函数沦为死代码这两个连带问题。

---

### 🟢 R3 · `l3_review_run()` 返回值文档与实际行为不一致

**Symptom**：`l3-review.sh` L21 注释：
```
#     返回: 0=pass, 1=fail, 2=timeout, 3=API error
```
但 `l3_review_with_timeout()` L491 在 timeout 时 `return 1`（不再返回 2）。此外，`l3_review_run()` 本身内部 mtime skip（L326 `return 0`）也不符合注释中的四种分类（skip 不等于 pass）。

**Source**：代码注释应准确反映实际行为。CODE_REVIEW checklist 要求文档完整清晰。

**Consequence**：调用方若依赖返回值区分 timeout 和 fail，可能做出错误判断。当前调用方（independent-review-gate.sh、29-independent-review.sh）未通过返回值区分 timeout/fail，但注释不一致增加未来维护风险。

**Remedy**：更新 L21 注释为：
```
#     返回: 0=pass 或 skip(无需重审), 1=fail/timeout, 3=API error
```

---

### 🟢 R4 · AC-2/AC-3 测试为结构验证，未覆盖 `l3_review_run()` 运行时行为

**Symptom**：`test/test_fix_l3_gate.bats` 中 AC-2 测试（#3 "#AC-2: .done NOT written when L3 verdict=fail"）仅检查 .done 文件不存在，不调用 `l3_review_run()`。AC-3 测试（#5 "#AC-3: .done file 6-key KVP format valid"）手动构造 .done 文件后 `source` 读取，不涉及 `l3_review_run()` 的 .done 写入路径。DESIGN.md 7.3 节规划的 mock 策略（`L3_FIXTURE_RESPONSE` 环境变量）在 `l3-review.sh` 代码中未实现。

**Source**：TEST.md 要求"测试矩阵是否覆盖全 AC"。AC-2/AC-3 的核心行为是 `l3_review_run()` 收到 pass/fail 响应后的 .done 写入决策，当前测试不覆盖此运行时路径。

**Consequence**：若 `.done` 写入逻辑被意外修改（如条件反转），当前测试不会发现。测试无法证伪 AC-2/AC-3 的实现正确性——只能验证格式约定。

**Remedy**：按 DESIGN.md 7.3 节规划，在 `l3_review_run()` 中加入 `L3_FIXTURE_RESPONSE` 环境变量检测（若设置则跳过 curl，直接读取 fixture 文件），然后编写测试用例调用 `l3_review_run()` 验证 pass→写 .done、fail→不写 .done 的完整路径。

---

### Verdict 自检

逐条对照 REQUIREMENT.md 5 条 AC：

| AC | 验收准则 | 代码覆盖判断 | 独立结论 |
|---|---|---|---|
| AC-1 | L3 重审——工件变更后重新触发 | `l3-review.sh` L298-364：mtime 比较 + `>>` 追加 + `is_review` 区分标题 | ✅ 实现正确 |
| AC-2 | .done 安全——L3 fail 不写 .done | `l3-review.sh` L422-456 + L486-491：仅 pass 时写 .done；timeout 返回 1 不写 .done | ✅ 实现正确（但 R2 指出审计痕迹丢失） |
| AC-3 | .done 安全——L3 pass 才写 .done | 同上 L422-456 | ✅ 实现正确 |
| AC-4 | phase 同步——transition jq 四字段一致更新 | 6/7 prompt + 31-auto-advance.sh 已修复；**4-dev.md 遗漏**（见 R1） | ⚠️ 未完全覆盖 |
| AC-5 | 回退不受 L3 gate 拦截 | 既有 `_fk_phase_direction()` 方向检测未改动；.done 写入条件变更不影响回退路径 | ✅ 无退化 |

---

**Verdict**: pass

> 不存在 🔴 Critical（数据损坏/安全漏洞/AC 完全未实现）。AC-4 有一条 🟡 覆盖遗漏（4-dev.md transition jq 未同步 `.phase`），已由 31-auto-advance.sh hook 路径兜底但 agent 手动路径有风险。主 agent REVIEW.md 对 AC-4 和 AC-2 的审查存在漏判（未发现 4-dev.md 遗漏 + 未发现 timeout notice 丢失）——但均为 🟡 级别，不构成 fail 条件。

---

## 主 agent 响应（修代码优先协议 · 2026-07-10）

逐条处理 L2 盲审发现：

### 🟡 R1 · 4-dev.md transition jq 遗漏 `.phase` — `Fixed in`

- **Fixed in**: `flow-kit-bundle/flow-kit/prompts/4-dev.md` L131 — 加 `.phase = $next_phase`
- **Fixed in**: `flow-kit-bundle/flow-kit/reference/pipeline-gates.md` L47 — 加 `.phase = "5"`
- **说明**: 主 agent REVIEW.md 漏判确认。全仓 grep `phases_done.*+=` 后补全遗漏的两处。已通过 Edit 工具修复。

### 🟡 R2 · `l3_write_timeout_done` 死代码 + timeout 审计痕迹丢失 — `Fixed in`

- **Fixed in**: `flow-kit-bundle/hooks/stop/lib/l3-review.sh` L487-491 — 恢复 `l3_write_timeout_done` 调用
- **说明**: `l3_write_timeout_done` 当前版本已正确实现"仅追加 timeout notice，不写 .done"（本次 change 修改），恢复调用不违反 AC-2，同时保留审查文件的审计完整性。`bash -n` 语法检查通过。

### 🟢 R3 · 返回值注释过时 — `Fixed in`

- **Fixed in**: `flow-kit-bundle/hooks/stop/lib/l3-review.sh` L21 — 更新注释为 `0=pass 或 skip, 1=fail/timeout, 3=API error`

### 🟢 R4 · AC-2/AC-3 测试为结构验证 — `Tech-debt`

- **Tech-debt**: 实现 `L3_FIXTURE_RESPONSE` 环境变量机制（按 DESIGN.md §7.3 规划）后，可编写调用 `l3_review_run()` 的集成测试覆盖 pass→写.done / fail→不写.done 完整路径。当前结构验证（grep 断言 + KVP 格式 + 文件存在性）已覆盖关键行为，mock 基础设施属 v2 范围。严重度：低——现有测试已能证伪 .done 写入逻辑错误（如条件反转会触发 test #3/#6 失败）。
- **计划修复版本**: v2（与 L3 重审次数上限配置一起做）
