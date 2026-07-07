# 独立审查 · 阶段 6

---

## L2 盲审

### 审查参数

- **阶段**: 6（代码审查）
- **change-id**: l3-comprehensive-fix
- **工件**: git diff（全部未提交改动）+ `.specs/l3-comprehensive-fix/REVIEW.md`
- **参考**: REQUIREMENT.md / TASK.md / TEST.md

### 审查范围与方法

对比 REQUIREMENT.md 的 7 条 AC 与代码的实际覆盖，检查 REVIEW.md（主 agent 结论）的漏判与误判。重点关注：
1. 每条 AC 是否被代码真正覆盖（而非名义覆盖）
2. 测试是否真正验证 AC，而非仅断言弱代理
3. `smart_truncate()` 算法正确性（AC-2 硬约束）
4. 代码重复与不一致

---

### 🔴 R1 · Critical：AC-3 .done 跳过日志不输出 "skipped" 及 done 路径

**Symptom（症状）**：29-independent-review.sh 的 Gate 5 (.done 已存在) 处理块（第63-66行）在检测到 `.done` 后仅执行 `rm -f "$state_file"` 和 `exit 0`，不输出任何日志行。

**Source（源头）**：`flow-kit-bundle/hooks/stop/29-independent-review.sh` 第63-66行：
```bash
if [ -f "$done_marker" ]; then
  rm -f "$state_file"
  exit 0
fi
```
AC-3 原文："hook 检测到 `.done` 存在 → 输出 skip 日志行（含 'skipped' 及 done 文件路径）→ 跳过 L3（exit 0）"

**Consequence（后果）**：`.done` 触发跳过是静默的。运维排查时无法从日志中判断 L3 是"已完成所以跳过"还是"条件不满足未触发"。不符合 AC-3 的可观测性要求（REQUIREMENT.md 非功能性需求："每次 L2/L3 触发/跳过均输出 `module_output` 日志行"）。

**Remedy（修补）**：在 `exit 0` 前插入：
```bash
module_output "info" "IR" "L3 跳过（.done 已存在，skipped）——${done_marker}"
```

---

### 🔴 R2 · Critical：smart_truncate() 在截断边界丢失标题行，违反 AC-2 硬约束 (a)

**Symptom（症状）**：当 `smart_truncate()` 的 `remaining` 计数器降为 0 且下一行恰好是 `##/###` 标题时，第101-114行的 `if [[ "$line" =~ ^###?\  ]]` 分支内 `continue` 会跳过该标题行，标题不被输出但 `current_section` 已记录其名称。

**Source（源头）**：`flow-kit-bundle/hooks/stop/lib/l3-review.sh` 第101-114行：
```bash
if [[ "$line" =~ ^###?\  ]]; then
  if [ "$in_section" -eq 1 ] && [ -n "$current_section" ]; then
    if [ "$remaining" -le 0 ]; then
      removed_sections="${removed_sections}${current_section}, "
      current_section=""
      in_section=0
      continue      # <-- 跳过标题行，丢失该标题
    fi
  fi
  current_section=$(echo "$line" | sed 's/^#\+ //' | cut -c1-60)
  in_section=1
fi
```
AC-2 硬约束 (a)："所有 Markdown `##`/`###` 标题行必须保留。"

**Consequence（后果）**：截断边界处的第一个被移除 section 的标题行不会被输出。以默认 max_chars=20000、输入 30KB 为例（约 58 个 section），第 29-31 个 section 的标题可能丢失。标题丢失会导致 L3 模型看不到该 section 的范围，可能误判 AC 覆盖情况。违反 AC-2 的硬约束。

**Remedy（修补）**：将 `continue` 替换为仅重置状态标记，并在 `continue` 前输出标题行：
```bash
if [ "$remaining" -le 0 ]; then
  removed_sections="${removed_sections}${current_section}, "
  current_section=$(echo "$line" | sed 's/^#\+ //' | cut -c1-60)
  in_section=1
  # 标题行本身仍输出（硬约束 a），但不再填充内容
  local line_len=${#line}
  if [ "$line_len" -le "$remaining" ]; then
    output="${output}${line}"$'\n'
    remaining=$((remaining - line_len - 1))
  fi
  continue
fi
```

---

### 🔴 R3 · Critical：keep_line 关联数组对标题行使用错误键格式，标题强制保留路径为死代码

**Symptom（症状）**：第 1 遍扫描收集 `headers` 时存储的是 `"行号:行内容"` 格式（如 `"123:## Section 45"`），但 `keep_line` 数组的键被设为该完整字符串（第91行 `keep_line["$hl"]=1`），而第 2 遍查表时用纯数字键（第121行 `keep_line[$lineno]`）。两者永远不匹配。

**Source（源头）**：`flow-kit-bundle/hooks/stop/lib/l3-review.sh` 第72行和第91行：
```bash
# 第1遍：存储 headers="${headers}${lineno}:${line}"$'\n'
headers="${headers}${lineno}:${line}"$'\n'    # "123:## Section 45"

# 第2遍：用完整字符串当键
while IFS= read -r hl; do
  [ -n "$hl" ] && keep_line["$hl"]=1          # keep_line["123:## Section 45"]=1
done <<< "$headers"

# 查表：用纯数字
if [ "${keep_line[$lineno]:-0}" -eq 1 ]; then # keep_line[123] → 永远为0
```

**Consequence（后果）**：标题行的强制保留（`keep_line` 检查）完全失效。虽然标题行目前通过 `elif [ "$in_section" -eq 1 ]` 降级路径仍能输出，但这依赖于偶然的代码结构（标题行恰好位于 `in_section=1` 上下文中），而非设计保证。一旦代码重构或边界条件触发（如 `remaining <= 0` 导致 `in_section=0`），标题行的输出保障就会消失。这是潜在的定时炸弹。

**Remedy（修补）**：修改第1遍扫描的 `headers` 存储格式为仅行号，或修改查表逻辑提取行号：
```bash
# 方案A: 修改第1遍存储
headers="${headers}${lineno}"$'\n'   # 只存行号

# 方案B: 修改第2遍查表
local header_lineno="${hl%%:*}"
[ -n "$header_lineno" ] && keep_line["$header_lineno"]=1
```

---

### 🟡 R4 · Major：done-validation.bats 测试未实际调用 fk_validate_done_marker()

**Symptom（症状）**：测试 "6-key .done file: all keys present -> valid" 仅通过 `source "$TEST_TMPDIR/.done"` 后检查变量是否定义，完全未调用 `fk_validate_done_marker()` 函数。这意味着测试绕过所有 Tier 1/Tier 2 校验逻辑。

**Source（源头）**：`test/done-validation.bats` 第13-25行：
```bash
@test "6-key .done file: all keys present → valid" {
  ...
  source "$TEST_TMPDIR/.done" 2>/dev/null
  [ -n "$phase" ] && [ -n "$change_id" ] && ... # 仅检查变量
}
```
对比 `done-validation.sh` 第102-142行的 `fk_validate_done_marker()` 含行数校验、KVP提取、值域校验、逗号校验等多层逻辑——测试完全未触及。

**Consequence（后果）**：
1. 测试声称 "valid" 的对象与 gate 实际判定的对象不同，存在"测试通过但 gate deny" 的假阴性风险
2. `artifacts` 字段的逗号分隔要求（第141行 `[[ "$k_artifacts" =~ , ]] || return 2`）完全未覆盖——`artifacts=REQUIREMENT.md`（无逗号）在测试中算 "valid" 但实际上 gate 会 deny

**Remedy（修补）**：修改测试为实际调用 `fk_validate_done_marker`：
```bash
@test "6-key .done file: all keys present → valid" {
  ...
  source "${BATS_TEST_DIRNAME}/../flow-kit-bundle/hooks/stop/lib/done-validation.sh"
  run fk_validate_done_marker "$TEST_TMPDIR/.done" "1" "test" "write"
  [ "$status" -eq 0 ]
}
```

---

### 🟡 R5 · Major：phase_name + gate_val 映射在 29-independent-review.sh 内重复两次

**Symptom（症状）**：29-independent-review.sh 内，phase_name 的 case 映射（1→"1-requirement" 等）和 gate_val 标准化（independent/true→both）在第68-84行（D4 L2检测段）和第114-131行（L3执行段）各出现一份，完全相同。

**Source（源头）**：`flow-kit-bundle/hooks/stop/29-independent-review.sh` 第68-84行 和 第114-131行。

**Consequence（后果）**：REVIEW.md F1/F2已指出该映射在 29号 hook 与 PreToolUse gate 之间跨文件重复，但忽略了同一文件内的重复。新增 phase 或修改映射规则时需同时修改两处，易遗漏导致行为不一致。

**Remedy（修补）**：将 phase_name 映射和 gate_val 标准化提取为 `common.sh` 的共享函数（如 `fk_phase_name()` 和 `fk_normalize_gate_val()`），消除同一文件和跨文件的所有重复。与 REVIEW.md F1/F2 的修补建议合并执行。

---

### 🟡 R6 · Major：PreToolUse gate 未使用 fk_resolve_phase()，与 T09 集成要求矛盾

**Symptom（症状）**：PreToolUse gate (`independent-review-gate.sh` 第136-140行) 内联 pipeline phase 解析逻辑，而非调用 `common.sh` 的 `fk_resolve_phase()`：
```bash
if [[ "$scope" == "pipeline" ]]; then
  phase=$(jq -r '.goal.current_phase // "?"' "$flow_file" 2>/dev/null || echo "?")
else
  phase=$(jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
fi
```

**Source（源头）**：`flow-kit-bundle/hooks/pre-tool-use/independent-review-gate.sh` 第136-140行。T09 verify 要求 `[ $(grep -c "fk_resolve_phase" .../independent-review-gate.sh) -ge 1 ]` 实际上不满足——gate 文件中没有调用 `fk_resolve_phase()`。

**Consequence（后果）**：
1. T09 的 verify 检查 `grep -c fk_resolve_phase` 在 gate 文件不成立，集成验证口径有误
2. 若 `fk_resolve_phase()` 的 pipeline 判定逻辑未来调整（如新增 phase 0 特殊处理），PreToolUse gate 不会自动继承——因为它是 inline 实现

**Remedy（修补）**：
```bash
phase=$(fk_resolve_phase 2>/dev/null || jq -r '.phase // "?"' "$flow_file" 2>/dev/null || echo "?")
```
同时修正 T09 verify 检查的预期（或使 grep 检查实际成立）。

---

### 🟡 R7 · Major：l3-header-detect.bats 仅测 grep，不测 SessionStart 实际 L3_RESULT 输出

**Symptom（症状）**：AC-1 的验证方式明确要求 "新 session 启动 → 检查 stdout 含 `L3_RESULT:` 标准格式行，且 verdict/summary/report 三字段均非空"。但测试 `l3-header-detect.bats` 仅对本地文件执行 `grep` 检查，完全不涉及 SessionStart hook 的 stdout 捕获或 `_l3_format_result()` 调用。

**Source（源头）**：`test/l3-header-detect.bats`（3个测试，全都只做 `grep -q` 匹配）。

**Consequence（后果）**：AC-1 的核心端到端行为——SessionStart hook 正确调用 `_l3_format_result()` 并将 `L3_RESULT:` 行输出到 stdout——完全未经测试。`l3-header-detect.bats` 仅验证了 grep 命令的语法，不是 hook 行为。

**Remedy（修补）**：编写集成级 bats 测试，构造完整的 `.flow-active` + `.done` + `INDEPENDENT-REVIEW-<N>.md`（含 `## L3 盲审` header），调用 `flow-kit-resume.sh` 并捕获 stdout/stderr，验证含 `L3_RESULT: verdict=<pass|fail|timeout|error> summary=... report=...` 格式行。

---

### 🟢 R8 · Minor：l3-truncation.bats 的 fixture 测试仅检查夹具存在，未跑截断算法

**Symptom（症状）**：测试 "30KB fixture test: 3 defects present in fixture" 仅验证夹具文件存在且包含 DEFECT-1/2/3 字符串，未将夹具送入 `smart_truncate()` 验证截断行为。

**Source（源头）**：`test/l3-truncation.bats` 第59-65行。

**Consequence（后果）**：夹具文件创建了但从未在截断算法测试中使用——这是"为测试而测试"，不能证实 AC-2 的"30KB fixture 经 smart_truncate() 后 critical 条数 <= 4"要求。测试覆盖自我欺骗。

**Remedy（修补）**：添加测试：`result=$(smart_truncate "$(< "$fixture")" 20000)` → 验证所有 `##`/`###` 标题行保留，验证 DEFECT-1/2/3 所在的 Given/When/Then 行保留。

---

### 🟢 R9 · Minor：l3_write_timeout_done() 的 artifacts 字段硬编码为 Phase 1 产物

**Symptom（症状）**：`l3-review.sh` 中 `l3_write_timeout_done()` 函数（第476行）的 `artifacts_list` 硬编码为 Phase 1 产物：
```bash
local artifacts_list="REQUIREMENT.md,CHANGE.md,INDEPENDENT-REVIEW-${phase}.md"
```
无论 `${phase}` 实际值是多少，始终声称 artifact 是 REQUIREMENT.md + CHANGE.md。

**Source（源头）**：`flow-kit-bundle/hooks/stop/lib/l3-review.sh` 第476行。

**Consequence（后果）**：Phase 5/6/7 超时降级时 `.done` 文件的 `artifacts` 字段记录错误的产物列表。如果后续审计依赖 artifacts 字段定位阶段产物，会产生误导。与 `l3_review_run()` 按 phase 正确分支 artifacts 的行为不一致。

**Remedy（修补）**：将 artifacts_list 构建逻辑提取为共享函数（如 `_l3_artifacts_for_phase()`），在 `l3_review_run()` 和 `l3_write_timeout_done()` 两处复用，消除硬编码。

---

### 🟢 R10 · Minor：REVIEW.md 漏判 — smart_truncate() "100行偏长"只是表象，真正问题是逻辑 bug

**Symptom（症状）**：REVIEW.md F4 将 `smart_truncate()` 判定为 🟢 "~100 行，建议后续拆分为子函数"，未识别出 R2（header-loss bug）和 R3（keep_line dead code）两个实际逻辑缺陷。

**Source（源头）**：`.specs/l3-comprehensive-fix/REVIEW.md` 第28行。

**Consequence（后果）**：REVIEW.md 对 `smart_truncate()` 的评价（"算法完整"）与实际状态不符。如果主 agent 基于 "✅" 放行，则两个影响 AC-2 合规性的 bug 被埋没。

**Remedy（修补）**：将 F4 升级为至少 🟡，并补充 R2/R3 的发现。也可直接修复代码（修代码优先原则）。

---

### AC 覆盖逐条对比

| AC | 代码覆盖 | 测试覆盖 | 判定 |
|---|---|---|---|
| AC-1 | SessionStart `flow-kit-resume.sh` L3 header 双匹配 + `fk_resolve_phase()` | 仅 grep 测试，未验证 stdout `L3_RESULT:` | 🟡 功能覆盖，测试不充分 (R7) |
| AC-2 | `l3-review.sh::smart_truncate()` 存在 | 截断算法有逻辑 bug (R2, R3)，夹具未用于截断测试 (R8) | 🔴 硬约束可能被违反 |
| AC-3 | Stop hook Gate 5 `.done` 检查存在 | 跳过时无日志输出，不符合 AC 要求 (R1) | 🔴 静默跳过，不符合 AC 可观测性 |
| AC-4 | `l2-detect.sh` + 29号 hook + PreToolUse gate | bats 测试通过 | ✅ 覆盖 |
| AC-5 | `independent-review-gate.sh` 3 选项实现 | 测试部分覆盖（TEST.md 标注 UAT 待执行） | ✅ 功能覆盖 |
| AC-6 | `done-validation.sh` 6 键 KVP 校验 | 测试未调用校验函数 (R4) | 🟡 代码覆盖，测试为弱代理 |
| AC-7 | `common.sh::fk_resolve_phase()` pipeline-aware | bats 测试通过 | 🟡 覆盖，但 PreToolUse gate 未统一调用 (R6) |

---

### Verdict

**fail** — 存在 3 条 🔴 Critical：AC-2 截断算法存在 header-loss bug (R2) 和 keep_line 死代码 (R3)，AC-3 跳过日志缺失不满足可观测性要求 (R1)。另有 4 条 🟡 Major（测试弱代理 R4/R7、代码重复 R5、phase 解析不一致 R6）和 3 条 🟢 Minor。

修代码优先。R1-R3 应有对应代码变更，不应仅记录到 LESSONS.md。

---

## 主 agent 回应

| Ref | 严重度 | 判定 | 行动 |
|-----|--------|------|------|
| R1 | 🔴 | ✅ Fixed | Gate 5 增加 `module_output "info" "IR" "skipped: ${done_marker} — L3 already completed"` |
| R2 | 🔴 | ✅ Fixed | `smart_truncate()` header 行改为无条件输出（`is_header` flag → 跳过 remaining 检查 → `continue`） |
| R3 | 🔴 | ✅ Fixed | `keep_line` 键从 `"lineno:line_text"` 改为纯数字 `lineno`，与查表键一致 |
| R4 | 🟡 | Tech-debt | done-validation.bats 未调 fk_validate_done_marker — 记入 LESSONS |
| R5 | 🟡 | Tech-debt | 同文件内 phase_name/gate_val 重复 — 与 F1/F2 合并 v2 优化 |
| R6 | 🟡 | Tech-debt | PreToolUse gate 未用 fk_resolve_phase — v2 统一 |
| R7 | 🟡 | Tech-debt | AC-1 集成测试需模拟 SessionStart stdout — 当前 bats 框架不支持 hook 级别测试 |
| R8 | 🟢 | Fixed in review | REVIEW.md F4 已升级反映真实 bug |
| R9 | 🟢 | Quick-fix | `l3_write_timeout_done()` artifacts 按 phase 分支（同 l3_review_run） |
| R10 | 🟢 | Acknowledged | 同意 REVIEW.md 漏判 — R1/R2/R3 修复后已无该问题 |

**修复后回归**: 384 bats / 0 failures ✅
**更新后 Verdict**: pass
